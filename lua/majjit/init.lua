--- a magit inspired plugin for working with jujutsu via status buffer
-- type defs
---@generic T
---@class (exact) Node<T>: { next: Node<T>?, prev: Node<T>? }

--- stat mode is historgram from --stat
--- view mode is the configured diff tool's view
--- select mode is similar to jj's inbuilt split nested checkbox hierarchy
---@alias DiffMode "none" | "stat" | "view" | "select"
---@alias ChangeId string
---@alias StatusFold { change: ChangeId, start: integer, count: integer }
---@alias ExtmarkId integer
---@alias State { marks: table, messages: table<ChangeId, string> }

local M = {}

vim.g.majjit_hl_ns = vim.api.nvim_create_namespace("majjit")
vim.g.majjit_change_ns = vim.api.nvim_create_namespace("majjit")
local Folds = require("majjit.folds")
local Utils = require("majjit.utils")

function M.setup()
  vim.g.baleia = require("baleia").setup({ async = false })
  vim.keymap.set("n", "<leader>jj", M.status, {})
  vim.api.nvim_set_hl_ns(vim.g.majjit_hl_ns)
  vim.api.nvim_set_hl(vim.g.majjit_hl_ns, "ChangeId", { bold = true, fg = "grey" })
  vim.api.nvim_set_hl(vim.g.majjit_hl_ns, "CommitSymbol", { bold = true, fg = "orange" })
  vim.api.nvim_set_hl(vim.g.majjit_hl_ns, "CommitMark", { fg = "green", italic = true })
  vim.api.nvim_set_hl(vim.g.majjit_hl_ns, "CommitMarkBold", { bold = true, italic = false, link = "CommitMark" })
end
--- https://github.com/jj-vcs/jj/blob/main/docs/templates.md
--- opens status buffer
function M.status()
  ---@type State
  M.state = {
    marks = {},
  }

  if vim.g.majjit_status_buf then
    pcall(vim.api.nvim_buf_delete, vim.g.majjit_status_buf, { force = true })
  end

  local buf = vim.api.nvim_create_buf(false, false)
  vim.g.majjit_status_buf = buf
  vim.api.nvim_buf_set_name(buf, "majjit://status")
  vim.api.nvim_set_option_value("filetype", "majjit", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.keymap.set("n", "<localleader>m", M.describe, { buffer = buf, desc = "describe" })
  vim.keymap.set("n", "<localleader>a", M.abandon, { buffer = buf, desc = "abandon" })
  vim.keymap.set("n", "<localleader>s", M.squash, { buffer = buf, desc = "squash" })
  vim.keymap.set("n", "<localleader>w", M.absorb, { buffer = buf, desc = "absorb" })
  vim.keymap.set("n", "<localleader>n", M.new, { buffer = buf, desc = "new change" })
  vim.keymap.set("n", "<localleader>ds", M.diff_stat, { buffer = buf, desc = "diff stat" })
  vim.keymap.set("n", "<localleader>dv", M.diff_view, { buffer = buf, desc = "diff view" })
  vim.keymap.set("n", "<localleader>de", M.diff_editor, { buffer = buf, desc = " diff editor" })
  vim.keymap.set("n", "[c", M.navigate_prev_change, { buffer = buf, desc = "previous change" })
  vim.keymap.set("n", "]c", M.navigate_next_change, { buffer = buf, desc = "next change" })

  local template = "concat(change_id.short(8), ' ', empty, ' ', description.first_line(), '\n')"
  Utils.shell({ "jj", "log", "--color=never", "--no-pager", "-T", template }, function(stdout)
    for i, line in ipairs(vim.split(stdout, "\n")) do
      local row = vim.split(line, " ")
      local symbol = row[1]
      local change = row[3]
      local empty = row[4] == "true"
      ---@type string?
      local description = table.concat(row, " ", 5)
      if description == "" then
        description = nil
      end
      if change ~= nil and change ~= "" then
        -- write real line
        local start_row = -1
        if i == 1 then
          start_row = 0
        end

        Utils.buf_set_lines({
          buf = buf,
          start_row = start_row,
          end_row = -1,
          content = { description or " " },
        })

        local mark = vim.api.nvim_buf_set_extmark(buf, vim.g.majjit_change_ns, i - 1, 0, {
          right_gravity = false,
          strict = true,
        })
        M.state.marks[change] = mark
        M.state.marks[mark] = change

        -- begin: highlight extmarks
        vim.api.nvim_buf_set_extmark(buf, vim.g.majjit_hl_ns, i - 1, 0, {
          right_gravity = false,
          strict = true,
          virt_text = { { symbol, "CommitSymbol" }, { " " }, { change, "ChangeId" }, { " " } },
          virt_text_pos = "inline",
        })

        if empty then
          vim.api.nvim_buf_set_extmark(buf, vim.g.majjit_hl_ns, i - 1, 1, {
            right_gravity = true,
            strict = true,
            virt_text = { { "(empty) ", "CommitMark" } },
            virt_text_pos = "inline",
          })
        end

        if not description then
          vim.api.nvim_buf_set_extmark(buf, vim.g.majjit_hl_ns, i - 1, 1, {
            right_gravity = true,
            strict = true,
            virt_text = { { "(no description) ", empty and "CommitMarkBold" or "CommitMark" } },
            virt_text_pos = "inline",
          })
        end

        -- end: highlight extmarks
      end
    end

    -- jump to buffer
    local win = 0
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
  end)
end

--- mark tuple is: [extmark_id, row, col]
---@return  [integer, integer, integer]
function M.get_prev_change()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local marks = vim.api.nvim_buf_get_extmarks(
    vim.g.majjit_status_buf,
    vim.g.majjit_change_ns,
    0,
    { cursor[1] - 1, 0 },
    {}
  )
  local n = vim.tbl_count(marks)
  return vim.print(marks[n])
end

---@return  [integer, integer, integer]
function M.get_next_change()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local marks = vim.api.nvim_buf_get_extmarks(vim.g.majjit_status_buf, vim.g.majjit_change_ns, { cursor[1], 1 }, -1, {})
  vim.print(marks)
  return marks[1]
end

function M.navigate_prev_change()
  local mark = M.get_prev_change()
  table.remove(mark, 1)
  vim.api.nvim_win_set_cursor(0, mark)
end

function M.navigate_next_change()
  local mark = M.get_next_change()
  table.remove(mark, 1)
  vim.api.nvim_win_set_cursor(0, mark)
end

---@param start_row integer
---@param info string
local function set_change_info(start_row, info)
  local next_mark =
    vim.api.nvim_buf_get_extmarks(vim.g.majjit_status_buf, vim.g.majjit_change_ns, { start_row, 0 }, -1, {})[1]

  local end_row = next_mark and next_mark[2] or -1
  Utils.buf_set_lines({
    buf = vim.g.majjit_status_buf,
    start_row = start_row,
    end_row = end_row,
    baleia = true,
    content = info,
  })
end

local function get_cursor_change_id()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local marks = vim.api.nvim_buf_get_extmarks(
    vim.g.majjit_status_buf,
    vim.g.majjit_change_ns,
    { cursor[1] - 1, 0 },
    { cursor[1] - 1, -1 },
    {}
  )

  return M.state.marks[marks[1][1]]
end

function M.diff_stat()
  local change_id = get_cursor_change_id()
  local cursor = vim.api.nvim_win_get_cursor(0)
  Utils.shell({ "jj", "show", change_id, "--stat", "-T", "" }, function(stat)
    set_change_info(cursor[1], stat)
  end)
end

function M.diff_view()
  local change_id = get_cursor_change_id()
  local cursor = vim.api.nvim_win_get_cursor(0)
  Utils.shell({ "jj", "show", change_id, "-T", "" }, function(diff)
    set_change_info(cursor[1], diff)
  end)
end

--todo: research what jj split does for this
function M.diff_editor()
  local change_id = get_cursor_change_id()
  local cursor = vim.api.nvim_win_get_cursor(0)

  Utils.shell({ "jj", "show", change_id, "--git", "-T", "" }, function(diff)
    set_change_info(cursor[1], diff)
  end)
end

--- preserves linear history
--- inserts new change after current line
function M.new()
  local change_id = get_cursor_change_id()
  Utils.shell({ "jj", "new", "-A", change_id }, function()
    Utils.shell({ "jj", "log", "-r", "@", "--no-graph", "--color=never", "-T", "change_id.short(8)" }, function(change)
      Utils.buf_set_lines({
        buf = vim.g.majjit_status_buf,
        start_row = 0,
        end_row = 0,
        content = { change .. " (no description)" },
      })
      local mark_id = vim.api.nvim_buf_set_extmark(vim.g.majjit_status_buf, vim.g.majjit_hl_ns, 0, 0, {
        strict = true,
        -- sign_text = "c",
        --end_col = 8,
        hl_group = "ChangeId",
        line_hl_group = "ChangeId",

        virt_text = { { "@" .. " " } },
        virt_text_pos = "inline",
      })
      M.state.marks[change] = mark_id
      M.state.marks[mark_id] = change
    end)
  end)
end

--- uses word under cursor as change id
function M.absorb()
  local change_id = get_cursor_change_id()

  require("coop")
    .spawn(function()
      Utils.shell_async({ "jj", "absorb", "--from", change_id })
      M.status()
    end)
    :await()
end

--- uses word under cursor as change id
function M.squash()
  local change_id = get_cursor_change_id()

  require("coop")
    .spawn(function()
      Utils.shell_async({ "jj", "squash", "--revision", change_id })
      M.status()
    end)
    :await()
end

--- uses word under cursor as change id
function M.abandon()
  local change_id = get_cursor_change_id()

  require("coop")
    .spawn(function()
      Utils.shell_async({ "jj", "abandon", change_id })
      M.status()
    end)
    :await()
end
--- uses word under cursor as change id
function M.describe()
  local change_id = get_cursor_change_id()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "majjit://describe")
  vim.api.nvim_set_option_value("filetype", "jj", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  Utils.shell(
    { "jj", "log", "-r", change_id, "--color=never", "--no-graph", "-T", "description" },
    function(description)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(description, "\n"))
      -- jump to buffer
      local win = Utils.popup(buf)
      vim.api.nvim_set_option_value("winbar", "Describe: " .. change_id, { win = win })
      vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function(args)
          local message = table.concat(vim.api.nvim_buf_get_lines(args.buf, 0, -1, true), "\n")
          Utils.shell({ "jj", "describe", "-r", change_id, "-m", message }, function()
            -- expected for the "BufWriteCmd" event
            vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
            -- return to status buffer
            vim.api.nvim_win_close(win, false)
            M.status()
          end)
        end,
      })
    end
  )
end

-- begin: testing
local function reload()
  package.loaded["majjit.utils"] = nil
  package.loaded["majjit.folds"] = nil
  package.loaded["majjit.health"] = nil
  package.loaded["majjit"] = nil
  M.setup()
end
reload()
-- end: testing

return M
