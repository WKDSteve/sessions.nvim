-- Feature sessions.tree (TESTS/sheets/features.lua): "everything closed" is a state too. The own tree of
-- filetree.nvim shows the buffers with their head closed by hand, then the files; the editor is quit with the files
-- on screen and the buffers hidden. After `+LastSession` the tree is back on the files with the folder that was open,
-- and the buffers, shown again, still have everything closed (a view that is drawn for the first time opens its head).
-- Acceptance: sessions.nvim/abnahme-own-tree-open-nodes-in-a-session; it replaces the hand probe ("eine Ansicht, in der alles zugeklappt war").
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
  id = "sessions.tree-closed",
  feature = "sessions.tree",
  title = "sessions.nvim: a view of the tree with everything closed, hidden at the quit, comes back closed",
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
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").tree_boot()
      _G.repo("myrepo")
      _G.write("docs/guide.md", { "guide" })
      _G.git({ "add", "." })
      _G.git({ "commit", "-q", "-m", "docs" })
      vim.cmd.edit("a.txt")
      vim.cmd.edit("b.txt")]],
      note = "a project with a folder, two files in the editor",
    },
    { keys = ":Filetree source buffers<CR>", note = "the tree, on its view buffers" },
    {
      wait = [[_G.tree.is_open() and _G.tree_line("a.txt") ~= nil and _G.tree_line("b.txt") ~= nil]],
      timeout = 10000,
      note = "both buffers are listed below the head",
    },
    { lua = [[_G.tree_on("Buffers")]], note = "into the tree, on the head of the buffers" },
    { keys = "h", note = "close it" },
    { wait = [[_G.tree_line("a.txt") == nil]], note = "the buffers are folded away" },
    {
      expect = [[_G.same(_G.tree.get_open_nodes("buffers"), {})]],
      note = "nothing is open in the view",
    },
    { screen = "buffers-closed", masks = TREE_ONLY },
    { keys = ":Filetree source files<CR>", note = "over to the files: the buffers are hidden now" },
    { wait = [[_G.tree.get_view() == "files" and _G.tree_line("docs") ~= nil]], timeout = 10000 },
    { lua = [[_G.tree_on("docs")]] },
    { keys = "l", note = "open the folder" },
    { wait = [[_G.tree_line("guide.md") ~= nil]], timeout = 5000 },
    { lua = [[_G.to_editor()]], note = "back in the editor window" },
    {
      restart = true,
      args = { "+lua dofile('TESTS/sheets/_helpers.lua').tree_boot()", "+LastSession" },
      note = "quit, then nvim +LastSession",
    },
    {
      wait = [[_G.tree.is_open() and _G.tree.get_view() == "files" and _G.tree_line("guide.md") ~= nil]],
      timeout = 10000,
      note = "the tree is back on the files, the folder open",
    },
    {
      expect = [[_G.same(_G.tree.get_open_nodes("buffers"), {})]],
      note = "the hidden view has everything closed, as the session says",
    },
    {
      wait = [[vim.api.nvim_win_get_cursor(_G.tree.get_winid())[1] == _G.tree_line("b.txt")]],
      timeout = 5000,
      note = "the tree follows the file in the editor: its cursor line is on b.txt (it gets there a moment later)",
    },
    { screen = "files-after-restart", masks = TREE_ONLY },
    { keys = ":Filetree source buffers<CR>", note = "show the buffers again" },
    {
      wait = [[_G.tree.get_view() == "buffers" and _G.tree_line("Buffers") ~= nil]],
      timeout = 10000,
    },
    {
      wait = [[#vim.fn.getbufinfo({ buflisted = 1 }) >= 2]],
      note = "the session brought both buffers back: there is something the head could show",
    },
    { expect = [[_G.tree_line("a.txt") == nil]], note = "the head is still closed" },
    { expect = [[_G.same(_G.tree.get_open_nodes("buffers"), {})]] },
    { screen = "buffers-after-restart", masks = TREE_ONLY },
  },
  judge = {
    "The buffers read the same before the quit and after the restart: only their closed head",
    "The files after the restart show docs open with guide.md in it",
  },
  manual = {
    "In the real config: close every group of a view, switch to the files, quit, start with the session, show the view: still closed",
  },
}
