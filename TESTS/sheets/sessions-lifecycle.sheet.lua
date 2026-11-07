-- Live check: section 2 of ALL/manual-test-checklists/sessions.md, the run without the chip.
return {
  id = "sessions.lifecycle",
  title = "sessions.nvim: save, list, current, load and their bare forms (no chip: the notify is the feedback)",
  task = "sessions.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      _G.setup({ chip = { enable = false } })
      vim.cmd.edit("a.txt")]],
    },
    { keys = ":Session current<CR>" },
    { expect = [[_G.noted("No session active.")]], note = "before any save or load" },

    { keys = ":Session save my-test-session<CR>" },
    { expect = [[_G.stored("my-test-session.vim") and _G.stored(".my-test-session.json")]] },
    {
      expect = [[_G.noted("saved: ") and _G.noted("my-test-session.vim")]],
      note = "no chip: the notify",
    },
    { lua = [[_G.forget()]] },
    { keys = ":Session current<CR>" },
    { expect = [[_G.noted("Current session: my-test-session")]] },

    { keys = ":Session save a-first<CR>" },
    { lua = [[_G.forget()]] },
    { keys = ":Session list<CR>" },
    {
      expect = [[_G.toasts():find("a%-first.*my%-test%-session") ~= nil]],
      note = "sorted by name, whichever was saved first",
    },

    { keys = ":Session load my-test-session<CR>" },
    {
      lua = [[_G.forget(); vim.cmd.split("b.txt"); vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })]],
    },
    { keys = ":Session load my-test-session<CR>", note = "a modified buffer in a split: no E445" },
    { expect = [[vim.v.errmsg == "" and _G.current() == "my-test-session"]] },
    { expect = [[_G.noted("hidden (unsaved): ") and _G.noted("b.txt")]] },
    { expect = [[_G.noted("loaded: ")]] },
    {
      expect = [[vim.deep_equal(_G.shown(), { "a.txt" })]],
      note = "the session's window, the modified buffer is hidden and not lost",
    },
    {
      expect = [[vim.api.nvim_buf_get_lines(vim.fn.bufnr("b.txt"), 0, -1, false)[1] == "unsaved"]],
    },
    { lua = [[vim.bo[vim.fn.bufnr("b.txt")].modified = false; _G.forget()]] },

    { keys = ":cd .<CR>", note = "DirChanged forgets the tracked session" },
    { keys = ":Session save<CR>", note = "bare, nothing tracked" },
    { expect = [[_G.current() == "myrepo_main" and _G.stored("myrepo_main.vim")]] },

    { keys = ":Session load a-first<CR>" },
    { keys = ":Session save a-first_2<CR>" },
    { lua = [[_G.write(_G.STORE .. "/a-first_2.vim", { "x" })]] },
    { keys = ":Session save<CR>", note = "bare: the tracked session" },
    { expect = [[_G.read(_G.STORE .. "/a-first_2.vim") ~= "x" and _G.current() == "a-first_2"]] },

    {
      lua = [[_G.forget()
      _G.write(_G.STORE .. "/a-first_2.vim", { "kept" })
      _G.other = _G.repo("elsewhere")]],
      note = "an unrelated directory",
    },
    { keys = ":Session current<CR>" },
    {
      expect = [[_G.noted("No session active.")]],
      note = "DirChanged forgets the tracked session",
    },
    { keys = ":Session save<CR>", note = "resolves from the new directory" },
    {
      expect = [[_G.read(_G.STORE .. "/a-first_2.vim") == "kept"]],
      note = "the previous session is not overwritten",
    },
    { expect = [[_G.current() ~= "a-first_2" and _G.current():find("elsewhere", 1, true) ~= nil]] },

    { lua = [[_G.forget()]] },
    { keys = ":Session save a-first<CR>", note = "the remembered session is now a-first" },
    {
      lua = [[_G.elsewhere = _G.project("never-saved"); vim.cmd.cd(vim.fn.fnameescape(_G.elsewhere))]],
    },
    { keys = ":Session load<CR>", note = "bare, a directory with no session of its own" },
    { expect = [[_G.current() == "a-first"]], note = "the remembered one" },
    { lua = [[vim.cmd.cd(vim.fn.fnameescape(_G.other))]] },
    { keys = ":Session load<CR>", note = "bare, in a saved project" },
    {
      expect = [[_G.current():find("elsewhere", 1, true) ~= nil]],
      note = "that project's own session",
    },
  },
}
