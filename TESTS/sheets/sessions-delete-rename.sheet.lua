-- Live check: section 5 of ALL/manual-test-checklists/sessions.md.
return {
  id = "sessions.delete-rename",
  title = "sessions.nvim: delete takes the companion, rename refuses an existing name, no keymap for either",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      -- room for the two warnings below: a hit-enter prompt would block this step
      vim.o.cmdheight = 8
      _G.setup({
        chip = { enable = false },
        keymaps = { delete = "<leader>xd", rename = "<leader>xr", save = "<leader>xs" },
      })
      vim.o.cmdheight = 1]],
    },
    { expect = [[_G.noted("keymaps.delete is not available: :Session delete requires a name")]] },
    { expect = [[_G.noted("keymaps.rename is not available: :Session rename requires")]] },
    { expect = [[_G.noted("Use keymaps.picker, or the command directly.")]] },
    { expect = [[not _G.noted("unknown keymap") and not _G.noted("no such keymap")]] },
    {
      expect = [[vim.fn.maparg("<leader>xd", "n") == "" and vim.fn.maparg("<leader>xs", "n") ~= ""]],
      note = "the others are still bound",
    },

    { keys = ":Session save delete-me<CR>" },
    { expect = [[_G.stored("delete-me.vim") and _G.stored(".delete-me.json")]] },
    { keys = ":Session delete delete-me<CR>" },
    { expect = [[not _G.stored("delete-me.vim") and not _G.stored(".delete-me.json")]] },
    { lua = [[_G.forget()]] },
    { keys = ":Session current<CR>" },
    { expect = [[_G.noted("No session active.")]], note = "the active one was deleted" },

    { keys = ":Session save taken<CR>" },
    { keys = ":Session save rename-me<CR>" },
    { keys = ":Session rename rename-me taken<CR>", ignore_errmsg = true },
    { expect = [[_G.noted("session already exists: taken")]] },
    { expect = [[_G.stored("rename-me.vim") and _G.current() == "rename-me"]] },
    { keys = ":Session rename rename-me renamed<CR>" },
    { expect = [[_G.stored("renamed.vim") and _G.stored(".renamed.json")]] },
    { expect = [[not _G.stored("rename-me.vim")]] },
    { lua = [[_G.forget()]] },
    { keys = ":Session current<CR>" },
    { expect = [[_G.noted("Current session: renamed")]], note = "without a reload" },
  },
}
