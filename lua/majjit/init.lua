local M = {}

function M.setup()
  M.Utils = require("majjit.utils")
  M.Baleia = require("baleia").setup({})
  vim.keymap.set("n", "<leader>jj", M.status, {})
end

--- stat mode is historgram from --stat
--- view mode is the configured diff tool's view
--- select mode is similar to jj's inbuilt split nested checkbox hierarchy
---@alias DiffMode "stat" | "view" | "select"

--- https://github.com/jj-vcs/jj/blob/main/docs/templates.md
--- opens status buffer
function M.status()
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
  vim.api.nvim_win_set_buf(0, buf)

  vim.keymap.set("n", "<localleader>m", M.describe, { buffer = buf, desc = "describe" })
  vim.keymap.set("n", "<localleader>a", M.abandon, { buffer = buf, desc = "abandon" })
  vim.keymap.set("n", "<localleader>s", M.squash, { buffer = buf, desc = "squash" })
  vim.keymap.set("n", "<localleader>w", M.absorb, { buffer = buf, desc = "absorb" })
  vim.keymap.set("n", "<localleader>n", M.new, { buffer = buf, desc = "new change" })
  -- vim.keymap.set("n", "<tab>", M.show_file_diff, { buffer = buf, desc = "new change" })
  -- vim.keymap.set("n", "<localleader>p", M.git_push, { buffer = buf, desc = "git push" })
  -- vim.keymap.set("n", "<localleader>ab", M.advance_bookmark, { buffer = buf, desc = "advance bookmark" })
  require("coop").spawn(function()
    local template = "concat(change_id.short(8), ' ', coalesce(description, '(no description)\n'), '\n')"

    local cmd = { "jj", "log", "--no-pager", "--no-graph", "-T", template }
    local stdout = M.Utils.shell(cmd)
    local changes = vim.split(stdout, "\n")

    -- write status
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    M.Baleia.buf_set_lines(buf, 0, -1, true, changes)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

    local offset = 0
    for i, line in ipairs(lines) do
      local change_id = vim.split(line, " ")[1]
      if change_id ~= "" and change_id ~= nil then
        local stdout = M.Utils.shell({ "jj", "show", "--no-pager", change_id, "-T", "''" })
        local diff = vim.split(stdout, "\n")
        local start = i + offset + 1
        vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
        M.Baleia.buf_set_lines(buf, start, start, true, diff)
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
        M.Utils.fold({ win = 0, start = start + 1, count = vim.tbl_count(diff) - 2 })
        offset = offset + vim.tbl_count(diff)
      end
    end
  end)
end

--- uses word under cursor as change id
function M.new()
  local change_id = M.Utils.cursor_word()
  M.Utils.shell({ "jj", "new", change_id }, function()
    M.status()
  end)
end

--- uses word under cursor as change id
function M.absorb()
  local change_id = M.Utils.cursor_word()
  M.Utils.shell({ "jj", "absorb", "--from", change_id }, function()
    M.status()
  end)
end

--- uses word under cursor as change id
function M.squash()
  local change_id = M.Utils.cursor_word()
  M.Utils.shell({ "jj", "squash", "--revision", change_id }, function()
    M.status()
  end)
end

--- uses word under cursor as change id
function M.abandon()
  local change_id = M.Utils.cursor_word()
  M.Utils.shell({ "jj", "abandon", change_id }, function()
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
      local message = table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, -1, true), "\n")
      M.Utils.shell({ "jj", "describe", "-r", change_id, "-m", message }, function()
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
  package.loaded["majjit.utils"] = nil
  package.loaded["majjit.health"] = nil
  package.loaded["majjit"] = nil
  M.setup()
end
reload()
-- end: testing

return M
