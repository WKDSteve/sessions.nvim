-- TESTS/marks_context_debounce_spec.lua — the BufLeave autocmd of
-- sessions.bindings.autocmds.enable_marks: the cursor position of a marked file
-- is remembered after a quiet period (context_debounce_ms > 0), one store
-- write for a burst, and VimLeavePre-style flushing writes what is pending.

return function(H)
  local config = require("sessions.config")
  local dir, cleanup = H.fixture("marks_ctx")
  vim.cmd("silent! %bwipeout!")

  local function file(name)
    local p = dir .. "/" .. name
    vim.fn.writefile({ "l1", "l2", "l3", "l4" }, p)
    return vim.fs.normalize(p)
  end
  local a, b = file("a.md"), file("b.md")

  config.setup({
    root = dir .. "/sroot",
    branch_aware = false,
    project_aware = false,
    marks = {
      enable = true,
      scope = "global",
      defaults = {},
      import_harpoon = false,
      context_debounce_ms = 60,
    },
  })
  local marks = H.fresh("sessions.marks")
  marks.add(a)
  marks.add(b)

  local aug = vim.api.nvim_create_augroup("sessions_marks_ctx_spec", { clear = true })
  require("sessions.bindings.autocmds").enable_marks(config.get(), aug)

  local function row_of(path)
    return marks.list()[marks.index(path)].row
  end

  -- leave a.md with the cursor on line 3: nothing is written before the quiet period ends
  vim.cmd("edit " .. vim.fn.fnameescape(a))
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  vim.cmd("edit " .. vim.fn.fnameescape(b))
  H.ok(row_of(a) ~= 3, "nothing is remembered right at BufLeave")
  vim.wait(1000, function()
    return row_of(a) == 3
  end, 10)
  H.eq(row_of(a), 3, "the position is remembered once the burst is quiet")

  -- a burst over two files costs one store write
  local json = require("lib.nvim.fs.json")
  local real_write, writes = json.write, 0
  json.write = function(...)
    writes = writes + 1
    return real_write(...)
  end
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("edit " .. vim.fn.fnameescape(a))
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  vim.cmd("edit " .. vim.fn.fnameescape(b))
  vim.wait(1000, function()
    return row_of(a) == 4
  end, 10)
  vim.wait(150)
  json.write = real_write
  H.eq(row_of(a), 4, "a's newest position wins")
  H.eq(writes, 1, "...and the burst is written once")

  pcall(vim.api.nvim_del_augroup_by_id, aug)
  cleanup()
end
