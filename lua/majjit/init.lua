local M = {}

vim.g.majjit_ns = vim.api.nvim_create_namespace("majjit")
M.Folds = require("majjit.folds")
M.Utils = require("majjit.utils")

function M.setup()
  M.Baleia = require("baleia").setup({ async = false })
  vim.keymap.set("n", "<leader>jj", M.status, {})
end

--- stat mode is historgram from --stat
--- view mode is the configured diff tool's view
--- select mode is similar to jj's inbuilt split nested checkbox hierarchy
---@alias DiffMode "none" | "stat" | "view" | "select"
---@alias ChangeId string
---@alias StatusFold { change: ChangeId, start: integer, count: integer }
--- ---@alias Folds  table<ChangeId, StatusFold>
---@alias ExtmarkId integer
---@alias State {  diff_mode_index: integer, changes: table}

--- https://github.com/jj-vcs/jj/blob/main/docs/templates.md
--- opens status buffer
function M.status()
  ---@type State
  M.state = {
    diff_mode_index = 0,
    changes = {},
  }

  local buf = vim.g.status_buf
  if not buf then
    buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, "majjit://status")
    vim.api.nvim_set_option_value("filetype", "majjit", { buf = buf })
    vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.g.status_buf = buf
  end

  -- jump to buffer
  local win = 0
  vim.api.nvim_win_set_buf(win, buf)

  -- delete folds
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
  M.Folds.delete_all()

  vim.keymap.set("n", "<localleader>m", M.describe, { buffer = buf, desc = "describe" })
  vim.keymap.set("n", "<localleader>a", M.abandon, { buffer = buf, desc = "abandon" })
  vim.keymap.set("n", "<localleader>s", M.squash, { buffer = buf, desc = "squash" })
  vim.keymap.set("n", "<localleader>w", M.absorb, { buffer = buf, desc = "absorb" })
  vim.keymap.set("n", "<localleader>n", M.new, { buffer = buf, desc = "new change" })
  vim.keymap.set("n", "<tab>", M.diff_stat, { buffer = buf, desc = "toggle diff mode" })

  require("coop").spawn(function()
    local template = "concat(change_id.short(8), ' ', coalesce(description, '(no description)\n'))"
    local stdout = M.Utils.shell({ "jj", "log", "--no-pager", "--no-graph", "-T", template })
    local changes = vim.split(stdout, "\n")

    -- write status
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    M.Baleia.buf_set_lines(buf, 0, -1, true, changes)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
    for i, line in ipairs(lines) do
      local change = vim.split(line, " ")[1]
      if change ~= "" then
        local mark_id = vim.api.nvim_buf_set_extmark(buf, vim.g.majjit_ns, i, 0, {})
        M.state.changes[change] = mark_id
        M.state.changes[mark_id] = change
      end
    end
  end)
end

function M.diff_stat()
  local change_id = M.Utils.cursor_word()
  local cursor = vim.api.nvim_win_get_cursor(0)
  require("coop").spawn(function()
    local stat = M.Utils.shell({ "jj", "show", change_id, "--stat", "-T", "" })
    local marks = vim.api.nvim_buf_get_extmarks(vim.g.status_buf, vim.g.majjit_ns, { cursor[1], 0 }, -1, {})
    vim.print(marks)
    local next_commit_line = marks[1][2]
    local start = cursor[1]
    local final = marks[1][2]
    vim.print({ start = start, final = final })

    vim.api.nvim_set_option_value("modifiable", true, { buf = vim.g.status_buf })
    M.Baleia.buf_set_lines(vim.g.status_buf, start, final, true, vim.split(stat, "\n"))
    vim.api.nvim_set_option_value("modifiable", false, { buf = vim.g.status_buf })
  end)
end

--
-- local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
-- local offset = 0
--
-- for i, line in ipairs(lines) do
--   local change_id = vim.split(line, " ")[1]
--   if change_id ~= "" and change_id ~= nil then
--     local start = i + offset + 1
--     M.state.folds[change_id] = { start = start, count = 1 }
--     offset = offset + 1
--
--     -- vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
--     -- M.Baleia.buf_set_lines(buf, start, start, true, { "placeholder" })
--     -- vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
--     -- M.Folds.create({ start = start + 1, count = 1 })
--     -- vim.tbl_count(diff)
--   end
-- end
-- require("coop.uv-utils").sleep(0)
-- M.Utils.pause()

-- vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
-- M.Baleia.buf_set_lines(buf, 1, 2, true, { "  placeholder" })
-- vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
-- for change, fold in pairs(M.state.folds) do
--   M.Baleia.buf_set_lines(buf, fold.start, fold.start, true, { "placeholder" })
--   M.Folds.create(fold)
-- end
--
--     local stdout = M.Utils.shell({ "jj", "show", "--no-pager", change_id, "-T", "''" })
--     local diff = vim.split(stdout, "\n")

--- uses word under cursor as change id
function M.new()
  local change_id = M.Utils.cursor_word()
  require("coop").spawn(function()
    M.Utils.shell({ "jj", "new", change_id })
    M.status()
  end)
end

--- uses word under cursor as change id
function M.absorb()
  local change_id = M.Utils.cursor_word()

  require("coop").spawn(function()
    M.Utils.shell({ "jj", "absorb", "--from", change_id })
    M.status()
  end)
end

--- uses word under cursor as change id
function M.squash()
  local change_id = M.Utils.cursor_word()

  require("coop").spawn(function()
    M.Utils.shell({ "jj", "squash", "--revision", change_id })
    M.status()
  end)
end

--- uses word under cursor as change id
function M.abandon()
  local change_id = M.Utils.cursor_word()

  require("coop").spawn(function()
    M.Utils.shell({ "jj", "abandon", change_id })
    M.status()
  end)
end

--- uses word under cursor as change id
function M.describe()
  local change_id = M.Utils.cursor_word()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "majjit://describe")
  vim.api.nvim_set_option_value("filetype", "jj", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function(args)
      require("coop").spawn(function()
        local message = table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, -1, true), "\n")
        local stdout = M.Utils.shell({ "jj", "describe", "-r", change_id, "-m", message })
        -- expected for the "BufWriteCmd" event
        vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
        -- return to status buffer
        M.status()
      end)
    end,
  })

  -- jump to buffer
  vim.api.nvim_win_set_buf(0, buf)
end

-- begin: testing
local function reload()
  vim.api.nvim_buf_clear_namespace(vim.g.majjit_status_buf or 0, vim.g.majjit_ns, 0, -1)
  package.loaded["majjit.utils"] = nil
  package.loaded["majjit.folds"] = nil
  package.loaded["majjit.health"] = nil
  package.loaded["majjit"] = nil
  M.setup()
end
reload()
-- end: testing

return M
