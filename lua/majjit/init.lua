local M = {}

function M.setup()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "majjit://status")
  vim.api.nvim_set_option_value("filetype", "majjit", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
  vim.api.nvim_set_option_value("modified", false, { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.keymap.set("n", "<localleader>d", M.describe, { buffer = buf, desc = "describe" })
  vim.keymap.set("n", "<localleader>a", M.abandon, { buffer = buf, desc = "abandon" })
  -- vim.keymap.set("n", "<localleader>s", M.squash, { buffer = buf, desc = "squash" })
  -- vim.keymap.set("n", "<localleader>n", M.new_change, { buffer = buf, desc = "new change" })
  -- vim.keymap.set("n", "<localleader>p", M.git_push, { buffer = buf, desc = "git push" })
  -- vim.keymap.set("n", "<localleader>ab", M.advance_bookmark, { buffer = buf, desc = "advance bookmark" })

  _G.majjit_status_buffer = buf
end

--- uses word under cursor as change id
function M.squash()
  local change_id = require("majjit.utils").cursor_word()
  vim.system({ "jj", "squash", "-r", change_id }, {}, function()
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
--- opens a terminal window for the jj split tui
function M.split()
  local change_id = require("majjit.utils").cursor_word()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "majjit://split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.fn.termopen({ "jj", "split", "--interactive", "-r", change_id }, {
    on_exit = function()
      M.status()
    end,
  })
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
--- https://github.com/jj-vcs/jj/blob/main/docs/templates.md
--- opens status buffer
function M.status()
  local stdout = vim.system({ "jj", "status", "--color", "never" }):wait(3000).stdout
  ---@cast stdout string
  local lines = vim.split(stdout, "\n")

  -- write status
  vim.api.nvim_set_option_value("modifiable", true, { buf = _G.majjit_status_buffer })
  vim.api.nvim_buf_set_lines(_G.majjit_status_buffer, 0, -1, true, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = _G.majjit_status_buffer })

  -- jump to buffer
  vim.api.nvim_win_set_buf(0, _G.majjit_status_buffer)
end

vim.keymap.set("n", "<leader>jj", M.status, {})

return M
