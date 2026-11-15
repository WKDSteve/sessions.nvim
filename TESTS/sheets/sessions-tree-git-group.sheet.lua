-- Feature sessions.tree (TESTS/sheets/features.lua): a group of the view `git` closed by hand stays closed across a
-- quit. The groups of that view arrive late (with the answer of `git status`) and each says it starts open; the
-- session names what was open, and a group it does not name stays closed when it arrives
-- (filetree.nvim: "a node the list of open nodes does not name stays closed when it arrives later").
-- Acceptance: sessions.nvim/abnahme-own-tree-open-nodes-in-a-session; it replaces the hand probe
-- ("Sitzungen: offene Knoten der Ansicht git"). filetree.nvim and ui.nvim come from .deps/ (CI:
-- ci.workflow.checkouts in .testing.lua) or beside this repository; without them the sheet is a reported skip.

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
  id = "sessions.tree-git-group",
  feature = "sessions.tree",
  title = "sessions.nvim: a group of the view git closed by hand is still closed after +LastSession",
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
    { lua = [[_G.tree_on("Untracked")]], note = "into the tree, on the group of the new files" },
    { keys = "h", note = "close it" },
    { wait = [[_G.tree_line("c.txt") == nil]], note = "its file is gone from the tree" },
    { expect = [[_G.tree_line("a.txt") ~= nil]], note = "the changed file is still shown" },
    { screen = "group-closed", masks = TREE_ONLY },
    {
      lua = [[_G.kept("open", _G.tree.get_open_nodes("git")); _G.to_editor()]],
      note = "what is open is written down; back in the editor window",
    },
    {
      expect = [[_G.same(_G.kept("open"), { "git:root", "git:changes" })]],
      note = "the head and the group of the changed files",
    },
    {
      restart = true,
      args = { "+lua dofile('TESTS/sheets/_helpers.lua').tree_boot()", "+LastSession" },
      note = "quit, then nvim +LastSession",
    },
    {
      wait = [[_G.tree.is_open() and _G.tree.get_view() == "git" and _G.tree_line("Untracked") ~= nil]],
      timeout = 10000,
      note = "the tree is back on the view git, and git status answered: the groups are there",
    },
    {
      wait = [[vim.api.nvim_win_get_cursor(_G.tree.get_winid())[1] == _G.tree_line("a.txt")]],
      timeout = 5000,
      note = "the tree follows the file in the editor: its cursor line is on a.txt (it gets there a moment later)",
    },
    {
      expect = [[_G.same(_G.tree.get_open_nodes("git"), _G.kept("open"))]],
      note = "exactly the nodes that were open are open",
    },
    {
      expect = [[_G.tree_line("c.txt") == nil]],
      note = "the group closed by hand is still closed",
    },
    { screen = "group-closed-after-restart", masks = TREE_ONLY },
  },
  judge = {
    "Before the quit and after the restart the tree reads the same: Changes open with a.txt, Untracked closed",
  },
  manual = {
    "In the real config: close a group of the view git, quit, start with the session: the group is closed, the others open",
  },
}
