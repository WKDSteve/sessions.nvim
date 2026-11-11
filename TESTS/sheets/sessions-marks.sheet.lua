-- Live check: section 16 of ALL/manual-test-checklists/sessions.md: the list, jumps, preview, debug and harpoon.
return {
  id = "sessions.marks",
  feature = "sessions.marks",
  title = "sessions.nvim: :Session marks add, list, remove, select, preview, debug, import-harpoon",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.dir = _G.repo("myrepo")
      local long = {}
      for i = 1, 50 do
        long[i] = "line " .. i
      end
      _G.write(_G.dir .. "/some.lua", long)
      _G.write(_G.dir .. "/other.md", long)
      _G.write(_G.dir .. "/third.txt", long)
      _G.setup({ chip = { enable = false } })
      _G.names = function()
        return vim.tbl_map(function(it)
          return vim.fs.basename(it.path)
        end, require("sessions.marks").list())
      end
      _G.here = function()
        return vim.fs.basename(vim.api.nvim_buf_get_name(0))
      end]],
      note = "marks.enable is off by default",
    },
    { keys = ":Session marks add<CR>" },
    { expect = [[_G.noted("marks are off -- set `marks = { enable = true }`")]] },
    { expect = [[not _G.noted("unknown subcommand")]] },
    { lua = [[_G.forget()]] },
    { keys = ":Session marks list<CR>" },
    { expect = [[_G.noted("marks are off")]], note = "every route says so" },

    {
      lua = [[_G.setup({
        chip = { enable = false },
        marks = { enable = true, context_debounce_ms = 0 },
      })
      vim.cmd.edit("some.lua")]],
    },
    { keys = ":Session marks add<CR>" },
    { lua = [[vim.cmd.edit("other.md")]] },
    { keys = ":Session marks add --front<CR>" },
    { expect = [[vim.deep_equal(_G.names(), { "other.md", "some.lua" })]] },
    { lua = [[_G.forget()]] },
    { keys = ":Session marks list<CR>" },
    {
      expect = [[_G.toasts():find("other%.md.*some%.lua") ~= nil]],
      note = "printed in that order",
    },

    { keys = ":Session marks remove<CR>", note = "the current file" },
    { expect = [[vim.deep_equal(_G.names(), { "some.lua" })]] },
    { keys = ":Session marks add --front<CR>" },

    { keys = ":Session marks select 2<CR>" },
    { expect = [[_G.here() == "some.lua"]] },
    { lua = [[vim.api.nvim_win_set_cursor(0, { 30, 2 })]], note = "move, leave the buffer" },
    { keys = ":Session marks select 1<CR>" },
    { expect = [[_G.here() == "other.md"]] },
    { settle = 50 },
    { keys = ":Session marks select 2<CR>", note = "back" },
    { expect = [[vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 30, 2 })]], note = "restored" },
    { keys = ":Session marks select 1<CR>" },
    {
      lua = [[_G.write(_G.dir .. "/some.lua", { "only", "three", "lines" })
      vim.cmd("bwipeout! some.lua")]],
      note = "the file shrinks below the remembered line",
    },
    { keys = ":Session marks select 2<CR>" },
    { expect = [[_G.here() == "some.lua" and vim.fn.line(".") == 3]], note = "clamped, no error" },

    { keys = ":Session marks preview 1<CR>" },
    {
      wait = [[vim.api.nvim_win_get_config(0).relative ~= ""]],
      note = "a float, with the focus",
    },
    { expect = [[_G.has(_G.text(), "line 7") and not vim.bo.modifiable]], note = "read-only" },
    { keys = "q" },
    { wait = [[vim.api.nvim_win_get_config(0).relative == ""]], note = "q closes it" },

    { keys = ":Session marks debug<CR>" },
    { expect = [[_G.has(_G.text(), "global") and _G.has(_G.text(), "marks/global.json")]] },
    { expect = [[_G.has(_G.text(), "other.md") and vim.bo.buftype == "nofile"]] },
    { keys = ":close<CR>" },

    {
      lua = [[_G.bucket = vim.fs.normalize(vim.fn.stdpath("config"))
      local data = vim.fn.stdpath("data") .. "/harpoon"
      _G.harpoon_file = data .. "/list.json"
      local entry = vim.json.encode({
        value = _G.dir .. "/third.txt",
        context = { row = 5, col = 1 },
      })
      _G.write(_G.harpoon_file, {
        vim.json.encode({ [_G.bucket] = { __harpoon_files = { entry } } }),
      })
      _G.before = _G.read(_G.harpoon_file)]],
      note = "harpoon v2 data, in the sandboxed data directory of this editor",
    },
    { keys = ":Session marks import-harpoon<CR>" },
    {
      expect = [[vim.deep_equal(_G.names(), { "third.txt", "other.md", "some.lua" })]],
      note = "harpoon's entries ahead of the current list",
    },
    {
      expect = [[_G.read(_G.harpoon_file) == _G.before]],
      note = "harpoon's own file is untouched",
    },
    { lua = [[_G.forget()]] },
    { keys = ":Session marks import-harpoon no-such-bucket<CR>" },
    { expect = [[_G.noted("marks import: no harpoon bucket for no-such-bucket")]] },
  },
}
