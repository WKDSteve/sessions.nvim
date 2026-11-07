-- Live check: sections 10 and 11 of ALL/manual-test-checklists/sessions.md.
return {
  id = "sessions.dirty-meta",
  title = "sessions.nvim: the dirty marker follows structure, not text; the metadata companion file",
  task = "sessions.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.dir = _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      _G.setup({ chip = { enable = false } })
      _G.line = function()
        return require("sessions.statusline").component({ icon = "", dirty_icon = " DIRTY" })
      end]],
    },
    { keys = ":Session save meta-test<CR>" },
    { expect = [[_G.line() == "meta-test"]], note = "right after a save: no marker" },
    { keys = ":split<CR>", note = "WinNew" },
    { expect = [[_G.line() == "meta-test DIRTY"]] },
    { keys = ":Session save meta-test<CR>" },
    { expect = [[_G.line() == "meta-test"]], note = "a save clears it" },
    { keys = ":close<CR>", note = "WinClosed" },
    { expect = [[_G.line() == "meta-test DIRTY"]] },
    { keys = ":Session load meta-test<CR>" },
    { expect = [[_G.line() == "meta-test"]], note = "right after a load: no marker" },
    { keys = ":tabnew<CR>", note = "TabNewEntered" },
    { expect = [[_G.line() == "meta-test DIRTY"]] },
    { keys = ":Session save meta-test<CR>" },
    { keys = ":tabclose<CR>", note = "TabClosed" },
    { expect = [[_G.line() == "meta-test DIRTY"]] },
    { keys = ":Session save meta-test<CR>" },
    { keys = ":badd b.txt<CR>", note = "BufAdd" },
    { expect = [[_G.line() == "meta-test DIRTY"]] },
    { keys = ":Session save meta-test<CR>" },
    { keys = ":bdelete b.txt<CR>", note = "BufDelete" },
    { expect = [[_G.line() == "meta-test DIRTY"]] },
    { keys = ":Session save meta-test<CR>" },
    { expect = [[_G.line() == "meta-test" and not _G.noted("nothing")]] },
    { keys = "ihello<Esc>", note = "typing in the buffer" },
    { expect = [[vim.bo.modified and _G.line() == "meta-test"]], note = "text is not structure" },
    { keys = "u" },
    { lua = [[vim.bo.modified = false]] },

    {
      expect = [[(function()
        local m = require("sessions").metadata("meta-test")
        return m.saved_at:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") ~= nil
          and vim.fs.normalize(m.cwd) == _G.dir
          and m.branch == "main"
      end)()]],
      note = "saved_at, cwd, branch",
    },
    {
      expect = [[(function()
        local m = require("sessions").metadata("meta-test")
        return #m.buffers == 1 and vim.fs.normalize(m.buffers[1]) == _G.dir .. "/a.txt"
      end)()]],
      note = "the absolute paths of the loaded buffers",
    },
    { expect = [[_G.stored(".meta-test.json")]] },
    { keys = ":Session delete meta-test<CR>" },
    { expect = [[not _G.stored(".meta-test.json")]], note = "not left orphaned" },

    { lua = [[_G.setup({ chip = { enable = false }, metadata = false }); _G.forget()]] },
    { keys = ":Session save no-meta<CR>" },
    { expect = [[_G.stored("no-meta.vim") and not _G.stored(".no-meta.json")]] },
    { keys = ":Session list<CR>" },
    { expect = [[_G.has(_G.toasts(), "no-meta")]], note = "degrades: no column, no crash" },
    { expect = [[require("sessions").metadata("no-meta") == nil]] },
    {
      lua = [[package.loaded["snacks"] = { picker = { pick = function(o) _G.pick = o end } }]],
    },
    { keys = ":SessionLoad<CR>" },
    { expect = [[_G.has(_G.pick.items[1].preview.text, "(no metadata recorded")]] },
    {
      lua = [[package.loaded["snacks"] = nil
      _G.setup({ chip = { enable = false }, autosave = false })]],
    },
    { keys = ":Session save off<CR>" },
    { keys = ":split<CR>" },
    {
      expect = [[not require("sessions.core").dirty()]],
      note = "autosave = false: the marker never appears (known, CDX in bindings/autocmds)",
    },
  },
}
