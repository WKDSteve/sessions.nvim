-- Live check: section 3 of ALL/manual-test-checklists/sessions.md, on a real git repository.
return {
  id = "sessions.branches",
  feature = "sessions.naming",
  title = "sessions.nvim: one session per branch, no reload on checkout, branch only when git-aware",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      _G.setup({ chip = { enable = false } })
      vim.cmd.edit("a.txt")]],
    },
    { keys = ":Session save<CR>" },
    { expect = [[_G.stored("myrepo_main.vim")]] },

    { lua = [[_G.git({ "checkout", "-q", "-b", "test-branch-2" }); vim.cmd.edit("b.txt")]] },
    {
      expect = [[_G.current() == "myrepo_main" and vim.deep_equal(_G.shown(), { "b.txt" })]],
      note = "a checkout alone reloads nothing",
    },
    { keys = ":cd .<CR>", note = "forgets the tracked session" },
    { keys = ":Session save<CR>" },
    { expect = [[_G.stored("myrepo_test-branch-2.vim") and _G.stored("myrepo_main.vim")]] },
    { lua = [[_G.forget()]] },
    { keys = ":Session list<CR>" },
    { expect = [[_G.has(_G.toasts(), "myrepo_main")]] },
    { expect = [[_G.has(_G.toasts(), "[main]")]], note = "the [branch] suffix of :Session list" },
    { expect = [[_G.has(_G.toasts(), "myrepo_test-branch-2")]] },
    { expect = [[_G.has(_G.toasts(), "[test-branch-2]")]] },

    {
      lua = [[-- a stand-in that fails loudly: with both *_aware off, sessions.git must not even load
      _G.setup({ branch_aware = false, project_aware = false, chip = { enable = false } })
      package.loaded["sessions.git"] = nil
      package.preload["sessions.git"] = function()
        error("sessions.git was required", 0)
      end]],
    },
    { keys = ":Session save no-git<CR>" },
    {
      expect = [[package.loaded["sessions.git"] == nil]],
      note = "lazy: never loaded, so never shells out",
    },
    { expect = [[require("sessions").metadata("no-git").branch == nil]] },
    { expect = [[require("sessions").metadata("no-git").cwd ~= nil]] },
    { lua = [[package.preload["sessions.git"] = nil]] },
  },
}
