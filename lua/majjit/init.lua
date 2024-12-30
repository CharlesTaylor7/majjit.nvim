local M = {}

function M.setup()
  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, "majjit://status")
  vim.api.nvim_set_option_value("filetype", "majjit", { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  vim.keymap.set("n", "<localleader>s", M.split, { buffer = bufnr, desc = "split" })
  vim.keymap.set("n", "<localleader>d", M.describe, { buffer = bufnr, desc = "describe" })

  _G.majjit_status_buffer = bufnr
end

--- uses word under cursor as change id
--- opens a terminal window for the jj split tui
function M.split()
  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, "majjit://split")
end

--- uses word under cursor as change id
function M.describe()
  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, "majjit://describe")
  vim.api.nvim_set_option_value("filetype", "jj", { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function(args)
      local message = table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, -1, true), "\n")
      vim.system({ "jj", "describe", "-r", "@", "-m", message }, {}, function()
        vim.schedule(function()
          vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
          M.status()
          vim.api.nvim_buf_delete(args.buf, {})
        end)
      end)
    end,
  })

  -- jump to buffer
  vim.api.nvim_win_set_buf(0, bufnr)
end

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
