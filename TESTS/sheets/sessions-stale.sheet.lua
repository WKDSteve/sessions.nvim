-- Live check: section 15 of ALL/manual-test-checklists/sessions.md, on a real git repository with a deleted branch.
return {
  id = "sessions.stale",
  title = "sessions.nvim: stale means the branch is gone; one question for the batch; save-timestamp",
  task = "sessions.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.with_ui()
      _G.dir = _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      _G.setup({ chip = { enable = false } })
      _G.dialog = function()
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_config(w).relative ~= "" then
            local t = _G.text(vim.api.nvim_win_get_buf(w))
            if t:find("stale session(s)", 1, true) then
              return t
            end
          end
        end
        return ""
      end]],
    },
    { keys = ":Session stale<CR>" },
    { expect = [[_G.noted("No stale sessions.")]], note = "nothing stale yet" },

    { lua = [[_G.git({ "checkout", "-q", "-b", "stale-test" })]] },
    { keys = ":cd .<CR>" },
    { keys = ":Session save<CR>", note = "<project>_stale-test" },
    { keys = ":cd .<CR>" },
    { keys = ":Session save custom-on-branch<CR>", note = "a custom name, git-aware: a candidate" },
    { expect = [[require("sessions").metadata("myrepo_stale-test").branch == "stale-test"]] },
    {
      lua = [[-- the exit snapshot is written on the branch that goes away
      require("sessions.core").save_last()
      _G.git({ "checkout", "-q", "main" })
      _G.git({ "branch", "-q", "other-branch" })
      _G.git({ "checkout", "-q", "other-branch" })]],
    },
    { keys = ":cd .<CR>" },
    { keys = ":Session save still-there<CR>", note = "its branch exists, not checked out below" },
    {
      lua = [[_G.git({ "checkout", "-q", "main" })
      _G.setup({ chip = { enable = false }, branch_aware = false, project_aware = false })]],
    },
    { keys = ":Session save no-branch<CR>", note = "both *_aware off: no recorded branch" },
    {
      lua = [[_G.git({ "branch", "-q", "-D", "stale-test" })
      _G.setup({ chip = { enable = false } })
      _G.forget()]],
    },

    { keys = ":Session stale<CR>" },
    {
      expect = [[_G.has(_G.toasts(), "myrepo_stale-test  [stale-test]")]],
      note = "as :Session list",
    },
    { expect = [[_G.has(_G.toasts(), "custom-on-branch  [stale-test]")]] },
    { expect = [[require("sessions").metadata("last").branch == "stale-test"]] },
    {
      expect = [[not _G.toasts():find("last  [", 1, true)]],
      note = "the exit snapshot is never one",
    },
    { expect = [[not _G.noted("no-branch")]], note = "no recorded branch: never listed" },
    { expect = [[not _G.noted("still-there")]], note = "a branch not checked out is not gone" },

    { keys = ":Session delete-stale<CR>" },
    { wait = [[_G.has(_G.dialog(), "Delete 2 stale session(s)?")]], note = "once, for the batch" },
    {
      expect = [[_G.has(_G.dialog(), "myrepo_stale-test") and _G.has(_G.dialog(), "custom-on-branch")]],
    },
    { keys = "n", note = "decline" },
    { wait = [[_G.dialog() == ""]] },
    { expect = [[_G.stored("myrepo_stale-test.vim") and _G.stored("custom-on-branch.vim")]] },
    { lua = [[_G.forget()]] },
    { keys = ":Session stale<CR>" },
    {
      expect = [[_G.noted("myrepo_stale-test") and _G.noted("custom-on-branch")]],
      note = "the same",
    },

    {
      lua = [[_G.proc([=[ _G.setup(); _G.finish() ]=], { cwd = _G.dir })]],
      note = "a real restart with stale sessions present",
    },
    { expect = [[_G.stored("custom-on-branch.vim")]], note = "nothing runs automatically" },

    { keys = ":Session delete-stale<CR>" },
    { wait = [[_G.dialog() ~= ""]] },
    { keys = "y", note = "accept: the second button's hotkey" },
    { wait = [[_G.noted("deleted: ")]] },
    {
      expect = [[not _G.stored("myrepo_stale-test.vim") and not _G.stored(".myrepo_stale-test.json")]],
    },
    {
      expect = [[not _G.stored("custom-on-branch.vim") and not _G.stored(".custom-on-branch.json")]],
    },
    {
      expect = [[_G.stored("last.vim") and _G.stored("still-there.vim")]],
      note = "only those two",
    },

    { keys = ":Session save-timestamp<CR>" },
    {
      expect = [[_G.current():match("^sess%-%d%d%d%d%d%d%d%d%-%d%d%d%d%d%d$") ~= nil]],
      note = "sess-YYYYMMDD-HHMMSS, and it becomes the current session",
    },
    { expect = [[_G.stored(_G.current() .. ".vim")]] },
    { lua = [[_G.first = _G.current(); vim.uv.sleep(1100)]] },
    { keys = ":Session save-timestamp<CR>" },
    {
      expect = [[_G.current() ~= _G.first and _G.stored(_G.first .. ".vim")]],
      note = "a second file",
    },
  },
}
