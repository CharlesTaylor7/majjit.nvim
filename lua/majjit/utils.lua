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

-- vim.keymap.set("n", "<localleader>cw", M.cursor_word, { desc = "cursor word" })
--
return M
