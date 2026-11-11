-- Live check: section 6 of ALL/manual-test-checklists/sessions.md, on a real git repository as the session root.
return {
  id = "sessions.toggle-track",
  feature = "sessions.toggle-track",
  title = "sessions.nvim: toggle-track needs a repo, flips skip-worktree and answers asynchronously",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.dir = _G.project("work")
      vim.cmd.cd(vim.fn.fnameescape(_G.dir))
      _G.write("a.txt")
      vim.cmd.edit("a.txt")
      _G.setup({ chip = { enable = false } })]],
      note = "the store is in no repository",
    },
    { keys = ":Session save track-test<CR>" },
    { keys = ":Session toggle-track track-test<CR>", ignore_errmsg = true },
    {
      wait = [[_G.noted("session root is not inside a git repo (required for :Session toggle-track)")]],
      note = "a clear error, no raw git failure",
    },

    {
      lua = [[_G.repo_dir = _G.repo("cfg")
      _G.STORE = _G.repo_dir .. "/sessions"
      vim.fn.mkdir(_G.STORE, "p")
      vim.cmd.edit("a.txt")
      _G.setup({ chip = { enable = false } })
      _G.forget()]],
      note = "the root inside a real repository",
    },
    { keys = ":Session save track-test<CR>" },
    {
      lua = [[_G.git({ "add", "sessions" })
      _G.git({ "commit", "-q", "-m", "tracked" })
      _G.status = function()
        return _G.git({ "status", "--porcelain", "--", "sessions/track-test.vim" })
      end
      _G.forget()
      vim.cmd("Session toggle-track track-test")
      _G.at_return = _G.toasts()]],
      note = "the first toggle; the toast is read in the same tick",
    },
    { expect = [[_G.at_return == ""]], note = "the command returned before git answered" },
    { wait = [[_G.noted("marked as skip-worktree (excluded from git)")]] },
    { lua = [[vim.cmd.split("b.txt")]] },
    { keys = ":Session save track-test<CR>" },
    { expect = [[_G.status() == ""]], note = "a new save does not show as modified" },
    { lua = [[_G.forget()]] },
    { keys = ":Session toggle-track track-test<CR>" },
    { wait = [[_G.noted("is now tracked in git")]] },
    { expect = [[_G.has(_G.status(), "track-test.vim")]], note = "git status shows it again" },
  },
}
