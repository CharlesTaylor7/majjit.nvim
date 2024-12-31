local M = {}

function M.setup()
  vim.keymap.set("n", "<leader>jj", M.status, {})
end

--- https://github.com/jj-vcs/jj/blob/main/docs/templates.md
--- opens status buffer
function M.status()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "majjit://status")
  vim.api.nvim_set_option_value("filetype", "majjit", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.keymap.set("n", "<localleader>d", M.describe, { buffer = buf, desc = "describe" })
  vim.keymap.set("n", "<localleader>a", M.abandon, { buffer = buf, desc = "abandon" })
  vim.keymap.set("n", "<localleader>s", M.squash, { buffer = buf, desc = "squash" })
  vim.keymap.set("n", "<localleader>w", M.absorb, { buffer = buf, desc = "absorb" })
  vim.keymap.set("n", "<localleader>n", M.new, { buffer = buf, desc = "new change" })
  vim.keymap.set("n", "<tab>", M.show_file_diff, { buffer = buf, desc = "new change" })
  -- vim.keymap.set("n", "<localleader>p", M.git_push, { buffer = buf, desc = "git push" })
  -- vim.keymap.set("n", "<localleader>ab", M.advance_bookmark, { buffer = buf, desc = "advance bookmark" })

  local template = table.concat({ "change_id.short()", "' '", "description", '"\n"', "diff.summary()", '"\n"' }, "++")
  local cmd = { "jj", "log", "--color", "never", "--no-pager", "--no-graph", "-T", template }
  local log = vim.system(cmd, {}, function(complete)
    local lines = vim.split(complete.stdout, "\n")
    vim.schedule(function()
      vim.print(complete.stderr)
      -- write status
      vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
      vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

      -- jump to buffer
      vim.api.nvim_win_set_buf(0, buf)
    end)
  end)
end

function M.show_file_diff()
  local change_id = require("majjit.utils").cursor_word()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local buf = vim.fn.bufnr()

  local diff_tool = 'ui.diff.tool=["difft", "--color=never", "$left", "$right"]'
  vim.system(
    { "jj", "show", "--config-toml", diff_tool, "--color", "never", "--no-pager", change_id, "-T", "''" },
    {},
    function(complete)
      local lines = vim.split(complete.stdout, "\n")
      vim.schedule(function()
        vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
        vim.api.nvim_buf_set_lines(buf, cursor[1], cursor[1], true, lines)

        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
      end)
    end
  )
end

--- uses word under cursor as change id
function M.new()
  local change_id = require("majjit.utils").cursor_word()
  vim.system({ "jj", "new", change_id }, {}, function()
    vim.schedule(M.status)
  end)
end

--- uses word under cursor as change id
function M.absorb()
  local change_id = require("majjit.utils").cursor_word()
  vim.system({ "jj", "absorb", "--from", change_id }, {}, function()
    vim.schedule(M.status)
  end)
end

--- uses word under cursor as change id
function M.squash()
  local change_id = require("majjit.utils").cursor_word()
  vim.system({ "jj", "squash", "--revision", change_id }, {}, function()
    vim.schedule(M.status)
  end)
end

--- uses word under cursor as change id
function M.abandon()
  local change_id = require("majjit.utils").cursor_word()
  vim.system({ "jj", "abandon", change_id }, {}, function()
    vim.schedule(M.status)
  end)
end

--- uses word under cursor as change id
function M.describe()
  local change_id = require("majjit.utils").cursor_word()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "majjit://describe")
  vim.api.nvim_set_option_value("filetype", "jj", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function(args)
      local message = table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, -1, true), "\n")
      vim.system({ "jj", "describe", "-r", change_id, "-m", message }, {}, function()
        vim.schedule(function()
          -- expected for the "BufWriteCmd" event
          vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
          -- return to status buffer
          M.status()
        end)
      end)
    end,
  })

  -- jump to buffer
  vim.api.nvim_win_set_buf(0, buf)
end

-- testing
M.setup()

return M
