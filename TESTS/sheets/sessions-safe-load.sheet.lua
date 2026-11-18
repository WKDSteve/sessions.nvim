-- Loading a session over unsaved work: the modified buffers are hidden and named in a toast, the load does not fail
-- with E445 from the session's own `only`, and the unsaved text is still there afterwards.
return {
  id = "sessions.safe-load",
  feature = "sessions.safe-load",
  title = "sessions.nvim: a load over modified buffers hides them instead of failing",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      _G.setup({ chip = { enable = false } })]],
    },
    { keys = ":edit a.txt<CR>" },
    { keys = ":Session save base<CR>" },
    { expect = [[_G.stored("base.vim")]] },

    { keys = ":vsplit b.txt<CR>" },
    { keys = "Ounsaved line<Esc>", note = "b.txt is modified, in a split of its own" },
    { keys = ":split c.txt<CR>" },
    { keys = "Oalso unsaved<Esc>" },
    {
      expect = [[#_G.wins() == 3 and vim.bo.modified]],
      note = "three windows, two of them on unsaved buffers",
    },
    { lua = [[_G.forget()]] },
    { keys = ":Session load base<CR>", note = "no E445: an error message fails the step" },
    { expect = [[_G.current() == "base"]] },
    { expect = [[vim.deep_equal(_G.shown(), { "a.txt" })]], note = "the session's layout alone" },
    { wait = [[_G.noted("hidden (unsaved): ")]] },
    { expect = [[_G.has(_G.toasts(), "b.txt") and _G.has(_G.toasts(), "c.txt")]] },
    {
      expect = [[(function()
        local b = vim.fn.bufnr("b.txt")
        return b > 0
          and vim.bo[b].modified
          and vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] == "unsaved line"
      end)()]],
      note = "the unsaved text is kept in a hidden buffer",
    },
    { keys = ":buffer b.txt<CR>" },
    { expect = [[vim.api.nvim_get_current_line() == "unsaved line"]], note = "and can be reached" },
  },
}
