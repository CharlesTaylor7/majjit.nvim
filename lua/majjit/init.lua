local M = {}

vim.g.majjit_ns = vim.api.nvim_create_namespace("majjit")
local Folds = require("majjit.folds")
local Utils = require("majjit.utils")

function M.setup()
  vim.g.baleia = require("baleia").setup({ async = false })
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

  local buf = vim.g.majjit_status_buf
  if not buf then
    buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, "majjit://status")
    vim.api.nvim_set_option_value("filetype", "majjit", { buf = buf })
    vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.g.majjit_status_buf = buf
  end

  -- jump to buffer
  local win = 0
  vim.api.nvim_win_set_buf(win, buf)

  -- delete folds
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
  Folds.delete_all()

  vim.keymap.set("n", "<localleader>m", M.describe, { buffer = buf, desc = "describe" })
  vim.keymap.set("n", "<localleader>a", M.abandon, { buffer = buf, desc = "abandon" })
  vim.keymap.set("n", "<localleader>s", M.squash, { buffer = buf, desc = "squash" })
  vim.keymap.set("n", "<localleader>w", M.absorb, { buffer = buf, desc = "absorb" })
  vim.keymap.set("n", "<localleader>n", M.new, { buffer = buf, desc = "new change" })
  vim.keymap.set("n", "<localleader>ds", M.diff_stat, { buffer = buf, desc = "toggle diff mode" })
  vim.keymap.set("n", "<localleader>dv", M.diff_view, { buffer = buf, desc = "toggle diff mode" })
  vim.keymap.set("n", "<localleader>de", M.diff_editor, { buffer = buf, desc = "toggle diff mode" })

  local template = "concat(change_id.short(8), ' ', coalesce(description.first_line(), '(no description)'), '\n')"
  Utils.shell({ "jj", "log", "--color", "never", "--no-pager", "--no-graph", "-T", template }, function(stdout)
    local changes = vim.split(stdout, "\n")

    -- write status
    Utils.buf_set_lines({ buf = buf, start_row = 0, end_row = -1, content = changes })

    for i, line in ipairs(changes) do
      local change = vim.split(line, " ")[1]
      if change ~= "" then
        local mark_id = vim.api.nvim_buf_set_extmark(buf, vim.g.majjit_ns, i - 1, 0, {
          strict = true,
          sign_text = "c",
          --end_col = 8,
          hl_group = "ChangeId",
          line_hl_group = "ChangeId",
        })
        M.state.changes[change] = mark_id
        M.state.changes[mark_id] = change
      end
    end
    vim.api.nvim_set_hl(vim.g.majjit_ns, "ChangeId", { bold = true, bg = "green" })
  end)
end

---@param start_row integer
---@param info string
local function set_change_info(start_row, info)
  local next_mark = vim.api.nvim_buf_get_extmarks(vim.g.majjit_status_buf, vim.g.majjit_ns, { start_row, 0 }, -1, {})[1]

  local end_row = next_mark and next_mark[2] or -1
  Utils.buf_set_lines({
    buf = vim.g.majjit_status_buf,
    start_row = start_row,
    end_row = end_row,
    baleia = true,
    content = info,
  })
end

local function get_cursor_change_id()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local marks = vim.api.nvim_buf_get_extmarks(
    vim.g.majjit_status_buf,
    vim.g.majjit_ns,
    { cursor[1] - 1, 0 },
    { cursor[1] - 1, -1 },
    {}
  )

  return M.state.changes[marks[1][1]]
end

function M.diff_stat()
  local change_id = get_cursor_change_id()
  local cursor = vim.api.nvim_win_get_cursor(0)
  Utils.shell({ "jj", "show", change_id, "--stat", "-T", "" }, function(stat)
    set_change_info(cursor[1], stat)
  end)
end

function M.diff_view()
  local change_id = get_cursor_change_id()
  local cursor = vim.api.nvim_win_get_cursor(0)
  Utils.shell({ "jj", "show", change_id, "-T", "" }, function(diff)
    set_change_info(cursor[1], diff)
  end)
end

--todo: research what jj split does for this
function M.diff_editor()
  local change_id = get_cursor_change_id()
  local cursor = vim.api.nvim_win_get_cursor(0)

  Utils.shell({ "jj", "show", change_id, "--git", "-T", "" }, function(diff)
    set_change_info(cursor[1], diff)
  end)
end

--- preserves linear history
--- inserts new change after current line
function M.new()
  local change_id = get_cursor_change_id()
  Utils.shell({ "jj", "new", "-A", change_id }, function()
    Utils.shell({ "jj", "log", "-r", "@", "--no-graph", "--color=never", "-T", "change_id.short(8)" }, function(change)
      Utils.buf_set_lines({
        buf = vim.g.majjit_status_buf,
        start_row = 0,
        end_row = 0,
        content = { change .. " (no description)" },
      })
      local mark_id = vim.api.nvim_buf_set_extmark(vim.g.majjit_status_buf, vim.g.majjit_ns, 0, 0, {
        strict = true,
        sign_text = "c",
        --end_col = 8,
        hl_group = "ChangeId",
        line_hl_group = "ChangeId",
      })
      M.state.changes[change] = mark_id
      M.state.changes[mark_id] = change
    end)
  end)
end

--- uses word under cursor as change id
function M.absorb()
  local change_id = get_cursor_change_id()

  require("coop")
    .spawn(function()
      Utils.shell_async({ "jj", "absorb", "--from", change_id })
      M.status()
    end)
    :await()
end

--- uses word under cursor as change id
function M.squash()
  local change_id = get_cursor_change_id()

  require("coop")
    .spawn(function()
      Utils.shell_async({ "jj", "squash", "--revision", change_id })
      M.status()
    end)
    :await()
end

--- uses word under cursor as change id
function M.abandon()
  local change_id = get_cursor_change_id()

  require("coop")
    .spawn(function()
      Utils.shell_async({ "jj", "abandon", change_id })
      M.status()
    end)
    :await()
end
--- uses word under cursor as change id
function M.describe()
  local change_id = get_cursor_change_id()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "majjit://describe")
  vim.api.nvim_set_option_value("filetype", "jj", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  Utils.shell(
    { "jj", "log", "-r", change_id, "--color=never", "--no-graph", "-T", "description" },
    function(description)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(description, "\n"))
      -- jump to buffer
      -- vim.api.nvim_win_set_buf(0, buf)
      local win = Utils.popup(buf)
      -- TODO: prepopulate with pre-existing commit message
      vim.api.nvim_set_option_value("winbar", "Describe: " .. change_id, { win = win })
      vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function(args)
          local message = table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, -1, true), "\n")
          Utils.shell({ "jj", "describe", "-r", change_id, "-m", message }, function()
            -- expected for the "BufWriteCmd" event
            vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
            -- return to status buffer
            vim.api.nvim_win_close(win, false)
            M.status()
          end)
        end,
      })
    end
  )
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
