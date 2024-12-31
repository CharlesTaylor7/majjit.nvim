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
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "majjit://status")
  vim.api.nvim_set_option_value("filetype", "majjit", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.keymap.set("n", "<localleader>m", M.describe, { buffer = buf, desc = "describe" })
  vim.keymap.set("n", "<localleader>a", M.abandon, { buffer = buf, desc = "abandon" })
  vim.keymap.set("n", "<localleader>s", M.squash, { buffer = buf, desc = "squash" })
  vim.keymap.set("n", "<localleader>w", M.absorb, { buffer = buf, desc = "absorb" })
  vim.keymap.set("n", "<localleader>n", M.new, { buffer = buf, desc = "new change" })
  -- vim.keymap.set("n", "<tab>", M.show_file_diff, { buffer = buf, desc = "new change" })
  -- vim.keymap.set("n", "<localleader>p", M.git_push, { buffer = buf, desc = "git push" })
  -- vim.keymap.set("n", "<localleader>ab", M.advance_bookmark, { buffer = buf, desc = "advance bookmark" })

  local template = "concat(change_id.short(8), ' ', coalesce(description, '(no description)\n'), diff.summary())"

  local cmd = { "jj", "log", "--no-pager", "--no-graph", "-T", template }
  local log = M.Utils.shell(cmd, function(stdout)
    local lines = vim.split(stdout, "\n")
    -- write status
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    M.Baleia.buf_set_lines(buf, 0, -1, true, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    -- jump to buffer
    vim.api.nvim_win_set_buf(0, buf)
    M.diff_view_mode()
  end)
end

---show diffs under changes
---uses the configured diff tool
---for presentation purposes not for command purposes
function M.diff_view_mode()
  local change_id = M.Utils.cursor_word()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(0)
  -- M.Utils.shell({ "jj", "log", "--no-graph", "--no-pager", "-T", "change_id.short(8)" })
  M.Utils.shell({ "jj", "show", "--no-pager", change_id, "-T", "''" }, function(stdout)
    local lines = vim.split(stdout, "\n")
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    M.Baleia.buf_set_lines(buf, cursor[1], cursor[1], true, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    M.Utils.fold({ win = win, start = cursor[1] + 1, count = vim.tbl_count(lines) })
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
