local M = {}

function M.check()
  vim.health.start("majjit")
  local jj = vim.fn.exepath("jj")
  if jj == "" then
    vim.error("jj not found on PATH")
  else
    local version = vim.health.system({ jj, "--version" })
    vim.health.ok("Jujutsu version: " .. version)
  end
end

return M
