local ns1 = vim.api.nvim_create_namespace("1")

local ns2 = vim.api.nvim_create_namespace("2")

vim.api.nvim_buf_clear_namespace(0, ns1, 0, -1)

vim.api.nvim_buf_clear_namespace(0, ns2, 0, -1)

local n = vim.api.nvim_buf_line_count(0)
for i = 0, n - 1 do
  vim.api.nvim_buf_set_extmark(0, ns1, i, 0, {
    right_gravity = false,
    strict = true,
    virt_text = { { "l" .. tostring(i) .. " " } },
    virt_text_pos = "inline",
  })
  vim.api.nvim_buf_set_extmark(0, ns2, i, 0, {
    right_gravity = false,
  })
end
