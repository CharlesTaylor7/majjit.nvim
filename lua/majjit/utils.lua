local M = {}

function M.cursor_word()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local previous_space = line:sub(0, cursor[2]):reverse():find(" ", 1, true)
  local next_space = line:find(" ", cursor[2] + 1, true)
  local word = line:sub(previous_space and (cursor[2] - previous_space + 2) or 0, next_space and next_space - 1)
  -- vim.print(word .. ":" .. word:len())
  return word
end

function M.root_dir()
  M.path = debug.getinfo(1).source:match("@?(.*/)")

  local split = vim.split(M.path, "/")
  local root_dir = table.concat(split, "/", 1, vim.tbl_count(split) - 3)
  return root_dir
end

---@param cmd string[]
---@param on_exit fun(string) -> nil
function M.shell(cmd, on_exit)
  vim.system(cmd, {}, function(args)
    vim.schedule(function()
      if args.code ~= 0 then
        ---@diagnostic disable-next-line
        args.cmd = cmd
        vim.print(args)
      else
        on_exit(args.stdout)
      end
    end)
  end)
end

---@param cmd string[]
---@return string
function M.shell_blocking(cmd)
  local result = vim.system(cmd):wait()
  if result.code ~= 0 then
    error(result.stderr)
  else
    return result.stdout
  end
end

---@param args { start: integer, count: integer, win: integer }
function M.fold(args)
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = args.win })
  local final = args.start + args.count - 1
  vim.cmd(args.start .. "," .. final .. " fold")
end

---@generic T
---@param table T[]
---@param value T
---@return integer|nil
function M.index_of(table, value)
  for i, v in ipairs(table) do
    if v == value then
      return i
    end
  end
end

return M
