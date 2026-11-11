-- Live check: section 9 of ALL/manual-test-checklists/sessions.md.
return {
  id = "sessions.layout",
  feature = "sessions.layout",
  title = "sessions.nvim: a layout snapshot brings the split structure and sizes back, not the files",
  task = "sessions.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 120 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      _G.setup({ chip = { enable = false } })
      vim.cmd.vsplit()
      vim.cmd.split()
      vim.api.nvim_win_set_width(0, 30)
      vim.api.nvim_win_set_height(0, 10)
      -- the tree without window ids, each leaf with its size
      _G.shape = function(node)
        node = node or vim.fn.winlayout()
        if node[1] == "leaf" then
          return { "leaf", vim.api.nvim_win_get_width(node[2]), vim.api.nvim_win_get_height(node[2]) }
        end
        local kids = { node[1] }
        for _, child in ipairs(node[2]) do
          kids[#kids + 1] = _G.shape(child)
        end
        return kids
      end
      _G.saved = _G.shape()]],
      note = "three windows, mixed row and column",
    },
    {
      expect = [[_G.saved[1] == "row" and _G.saved[2][1] == "col"]],
      note = "really a nested layout",
    },
    { keys = ":Session save-layout my-layout<CR>" },
    { expect = [[_G.stored("layouts/my-layout.json")]] },

    { keys = ":only<CR>" },
    { lua = [[vim.cmd.edit("b.txt")]], note = "another buffer" },
    { keys = ":Session load-layout my-layout<CR>" },
    { expect = [[#_G.wins() == 3]] },
    {
      expect = [[vim.deep_equal(_G.shape(), _G.saved)]],
      note = "the exact structure, with the saved sizes",
    },
    {
      expect = [[vim.deep_equal(_G.shown(), { "b.txt", "b.txt", "b.txt" })]],
      note = "applied to what is open: the files of the snapshot are not reopened",
    },

    { lua = [[_G.forget()]] },
    { keys = ":Session list<CR>" },
    {
      expect = [[not _G.noted("my-layout") and not _G.stored("my-layout.vim")]],
      note = "not in :Session list",
    },
  },
}
