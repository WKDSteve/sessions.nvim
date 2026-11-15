-- Feature sessions.tree (TESTS/sheets/features.lua): the own tree of filetree.nvim shows the view `tests` of
-- testing.nvim, a spec file opened down to its cases. The editor is quit and started again twice:
--   1. with testing.nvim set up before the session loads: the tree is back on `tests` with the same nodes open;
--   2. with testing.nvim set up only AFTER the session loaded (a plugin a plugin manager loads late): the tree shows
--      the files meanwhile, and once the view is there and shown, the nodes the session named are open in it.
-- Acceptance: sessions.nvim/abnahme-own-tree-open-nodes-in-a-session; it replaces the hand probe ("Sitzungen: offene Knoten der Ansicht tests,
-- eine Ansicht eines Plugins, das sich verzögert anmeldet"). filetree.nvim and ui.nvim come from .deps/ (CI:
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
  id = "sessions.tree-tests",
  feature = "sessions.tree",
  title = "sessions.nvim: the open nodes of the view tests come back, also when its plugin registers after the load",
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
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").tree_boot({ tests = true })
      _G.repo("myrepo")
      _G.write("TESTS/calc_spec.lua", {
        'describe("calc", function()',
        '  it("adds", function() end)',
        '  it("subtracts", function() end)',
        "end)",
      })
      _G.write("TESTS/other_spec.lua", { 'it("stands alone", function() end)' })
      -- committed: an untracked file gets a git badge when `git status` answers, some time after the tree is drawn
      _G.git({ "add", "." })
      _G.git({ "commit", "-q", "-m", "specs" })
      vim.cmd.edit("a.txt")]],
      note = "a project with two spec files that never ran, a.txt in the editor",
    },
    { keys = ":Filetree source tests<CR>", note = "the tree, on the view tests" },
    {
      wait = [[_G.tree.is_open() and _G.tree_line("calc_spec.lua") ~= nil]],
      timeout = 10000,
      note = "the spec files are listed",
    },
    { lua = [[_G.tree_on("calc_spec.lua")]], note = "into the tree, on the first spec file" },
    { keys = "l", note = "open it" },
    {
      wait = [[_G.tree_line("subtracts") == nil and #_G.tree_lines() == 5]],
      note = "its describe is listed",
    },
    { keys = "ll", note = "down to the describe, and open that too" },
    { wait = [[_G.tree_line("adds") ~= nil]], note = "its cases are listed" },
    { screen = "tests-before-quit", masks = TREE_ONLY },
    {
      lua = [[_G.kept("open", _G.tree.get_open_nodes("tests")); _G.to_editor()]],
      note = "what is open is written down; back in the editor window",
    },
    {
      expect = [[vim.tbl_contains(_G.kept("open"), "tests:file:TESTS/calc_spec.lua")]],
      note = "the spec file is among the open nodes",
    },
    {
      restart = true,
      args = {
        "+lua dofile('TESTS/sheets/_helpers.lua').tree_boot({ tests = true })",
        "+LastSession",
      },
      note = "quit, then nvim +LastSession with testing.nvim set up as before",
    },
    {
      wait = [[_G.tree.is_open() and _G.tree.get_view() == "tests" and _G.tree_line("calc_spec.lua") ~= nil]],
      timeout = 10000,
      note = "the tree is back, on the view tests",
    },
    {
      expect = [[_G.same(_G.tree.get_open_nodes("tests"), _G.kept("open"))]],
      note = "exactly the nodes that were open are open",
    },
    {
      expect = [[vim.api.nvim_get_current_win() ~= _G.tree.get_winid()]],
      note = "the focus is in the editor, not in the tree",
    },
    { screen = "tests-after-restart", masks = TREE_ONLY },
    {
      restart = true,
      args = { "+lua dofile('TESTS/sheets/_helpers.lua').tree_boot()", "+LastSession" },
      note = "quit again; this editor loads the session before testing.nvim is set up",
    },
    {
      wait = [[_G.tree.is_open() and _G.tree_line("a.txt") ~= nil]],
      timeout = 10000,
      note = "the tree is back",
    },
    {
      expect = [[_G.same(_G.tree.get_view(), "files")]],
      note = "on the files: nobody registered a view tests yet",
    },
    {
      expect = [[_G.same(_G.tree.get_open_nodes("tests"), _G.kept("open"))]],
      note = "the tree keeps what the session named for the view that is not there",
    },
    { lua = [[_G.tests_view()]], note = "now testing.nvim is set up: its view registers" },
    { keys = ":Filetree source tests<CR>", note = "show it" },
    {
      wait = [[_G.tree.get_view() == "tests" and _G.tree_line("calc_spec.lua") ~= nil]],
      timeout = 10000,
    },
    {
      wait = [[vim.deep_equal(_G.tree.get_open_nodes("tests"), _G.kept("open"))]],
      timeout = 5000,
      note = "the nodes the session named are open in the view that came late",
    },
    { screen = "tests-registered-late", masks = TREE_ONLY },
  },
  judge = {
    "The three pictures of the tree read the same: TESTS open, calc_spec.lua open down to its cases, other_spec.lua closed",
  },
  manual = {
    "In the real config (lazy.nvim loads testing.nvim late): quit with the view tests and a spec file open, start with the session, the file is open again once the view shows",
  },
}
