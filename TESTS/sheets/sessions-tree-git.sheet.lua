-- Feature sessions.tree (TESTS/sheets/features.lua): the own tree of filetree.nvim shows the view `git` of a project
-- with a changed and a new file. The editor is quit and started again with `+LastSession`: the tree is back in that
-- view, with the same groups open, and the focus is in the editor.
-- Acceptance: sessions.nvim/abnahme-own-tree-open-nodes-in-a-session; it replaces the hand probe ("Sitzungen: offene Knoten der Ansicht git").
-- filetree.nvim and ui.nvim come from .deps/ (CI: ci.workflow.checkouts in .testing.lua) or beside this repository;
-- without them the sheet is a reported skip (n/a) on a developer's machine and red on CI.

-- A picture of the tree alone: the editor beside it shows a toast that names a temporary path, and the command line
-- what was typed last.
local TREE_ONLY = {
  { row = 1, col = 32, cols = 69, rows = 20 },
  { row = 21 },
  { row = 22 },
  { row = 23 },
  { row = 24 },
}

return {
  id = "sessions.tree-git",
  feature = "sessions.tree",
  title = "sessions.nvim: quit with the tree on the view git, +LastSession brings the tree back on it",
  task = "sessions.nvim/abnahme-own-tree-open-nodes-in-a-session",
  sizes = { { rows = 24, cols = 100 } },
  requires = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").add_deps("ui.nvim", "filetree.nvim")]],
      reason = "filetree.nvim or ui.nvim is not beside this repository",
    },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").tree_boot()]],
      note = "the editor: the own tree and sessions.nvim set up",
    },
    {
      -- a step of its own: several git processes, slow on a loaded Windows machine, and one call has 10 s
      lua = [[_G.repo("myrepo")
      _G.write("a.txt", { "a", "changed" })
      _G.write("c.txt", { "new" })
      vim.cmd.edit("a.txt")]],
      note = "a project with one changed and one new file, a.txt in the editor",
    },
    { keys = ":Filetree source git<CR>", note = "the tree, on its view git" },
    {
      wait = [[_G.tree.is_open() and _G.tree_line("Untracked") ~= nil and _G.tree_line("c.txt") ~= nil]],
      timeout = 10000,
      note = "git status answered: the groups and their files are drawn",
    },
    {
      wait = [[vim.api.nvim_win_get_cursor(_G.tree.get_winid())[1] == _G.tree_line("a.txt")]],
      timeout = 5000,
      note = "the tree follows the file in the editor: its cursor line is on a.txt (it gets there a moment later)",
    },
    { screen = "git-before-quit", masks = TREE_ONLY },
    {
      lua = [[_G.kept("open", _G.tree.get_open_nodes("git")); _G.to_editor()]],
      note = "what is open is written down; back in the editor window",
    },
    {
      expect = [[_G.same(_G.kept("open"), { "git:root", "git:changes", "git:untracked" })]],
      note = "the head and both groups",
    },
    {
      restart = true,
      args = { "+lua dofile('TESTS/sheets/_helpers.lua').tree_boot()", "+LastSession" },
      note = "quit, then nvim +LastSession",
    },
    {
      wait = [[_G.tree.is_open() and _G.tree.get_view() == "git" and _G.tree_line("c.txt") ~= nil]],
      timeout = 10000,
      note = "the tree is back, on the view git, and git status answered",
    },
    {
      expect = [[_G.same(_G.tree.get_open_nodes("git"), _G.kept("open"))]],
      note = "exactly the nodes that were open are open",
    },
    {
      expect = [[vim.api.nvim_get_current_win() ~= _G.tree.get_winid()]],
      note = "the focus is in the editor, not in the tree",
    },
    {
      wait = [[vim.api.nvim_win_get_cursor(_G.tree.get_winid())[1] == _G.tree_line("a.txt")]],
      timeout = 5000,
      note = "the tree follows the file in the editor: its cursor line is on a.txt (it gets there a moment later)",
    },
    { screen = "git-after-restart", masks = TREE_ONLY },
  },
  judge = {
    "Before the quit and after the restart the tree reads the same: Changes with a.txt, Untracked with c.txt",
  },
  manual = {
    "In the real config: quit with the tree on the view git, start with the session, the tree is back on git",
  },
}
