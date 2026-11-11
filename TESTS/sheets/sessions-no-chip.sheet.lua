-- Live check: section 14 of ALL/manual-test-checklists/sessions.md: without ui.nvim on the runtimepath.
return {
  id = "sessions.no-chip",
  feature = "sessions.chip",
  title = "sessions.nvim: without ui.nvim no chip, no error, chip-toggle does nothing, the notify is back",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      _G.setup()
      _G.floats = function()
        return #vim.tbl_filter(function(w)
          return vim.api.nvim_win_get_config(w).relative ~= ""
            and _G.text(vim.api.nvim_win_get_buf(w)):find("myrepo", 1, true) ~= nil
        end, vim.api.nvim_list_wins())
      end]],
    },
    { expect = [[pcall(require, "ui.kit") == false]], note = "ui.nvim is really absent" },
    {
      expect = [[vim.v.errmsg == "" and not require("sessions.chip").is_active()]],
      note = "no error at startup",
    },
    { keys = ":Session chip-toggle<CR>", note = "a silent no-op" },
    { expect = [[_G.floats() == 0 and _G.toasts() == ""]] },
    { keys = ":Session save x<CR>" },
    { expect = [[_G.noted("saved: ")]] },
    { keys = ":Session load x<CR>" },
    { expect = [[_G.noted("loaded: ")]] },
  },
}
