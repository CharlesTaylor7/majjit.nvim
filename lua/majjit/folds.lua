local M = {}

---@param args { start: integer, count: integer }
function M.create(args)
  if args.count <= 0 then
    
    return
  end
  local final = args.start + args.count - 1
  vim.cmd(args.start .. "," .. final .. " fold")
end

---@param line integer
function M.delete(line)
  vim.cmd(tostring(line) .. " normal! zD")
end

function M.delete_all()
  vim.cmd("normal! zE")
end

return M
