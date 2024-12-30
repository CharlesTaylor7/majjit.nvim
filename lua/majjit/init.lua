local M = {}

function M.setup()
  print("majjit.setup(): TODO")
  vim.uv.fs_mkdir(".jj/majjit/", 777)
  local fd = vim.uv.fs_open(".jj/majjit/status.jj", "w")
  vim.print("fd: " .. tostring(fd))
  local stdout = vim.system({ "jj", "status", "--color", "never" }):wait(3000).stdout
  vim.uv.fs_write(fd, stdout)
  ---@cast stdout string
  local lines = vim.split(stdout, "\n", {})
  local bufnr = vim.fn.bufadd(".jj/majjit/status.jj")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  require("chuck.utils").popup(bufnr)
end

return M
