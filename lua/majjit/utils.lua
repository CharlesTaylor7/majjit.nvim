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

function M.coop_wrap(fun)
  local cb_to_tf = require("coop.task-utils").cb_to_tf
  local shift_parameters = require("coop.functional-utils").shift_parameters

  return cb_to_tf(shift_parameters(fun))
end

---@param cmd string[]
---@param on_exit fun(string) -> nil
local function shell(cmd, on_exit)
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
M.shell = M.coop_wrap(shell)
M.sleep = require("coop.uv-utils").sleep

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

---@param buf integer
function M.popup(buf)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    border = "rounded",
    noautocmd = false,
    col = 5,
    row = 5,
    width = vim.o.columns - 10,
    height = vim.o.lines - 15,
  })
  vim.api.nvim_set_option_value("winhl", "Normal:NormalFloat", {})
  vim.api.nvim_create_autocmd("WinLeave", {
    group = vim.api.nvim_create_augroup("popup", {}),
    callback = function()
      if vim.api.nvim_get_current_win() == win then
        vim.api.nvim_win_close(win, false)
      end
    end,
  })

  return win
end

return M
