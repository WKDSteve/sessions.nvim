-- Live check: sections 2 and 14 of ALL/manual-test-checklists/sessions.md, with the real chip of ui.nvim.
return {
  id = "sessions.chip",
  title = "sessions.nvim: the chip replaces the saved/loaded notify, hides itself and toggles",
  task = "sessions.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.with_ui()
      vim.o.laststatus = 2
      _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      _G.setup({ chip = { timeout_ms = 400 } })
      -- the chip is the float whose text names the folder of the project
      _G.chip = function()
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local cfg = vim.api.nvim_win_get_config(w)
          if cfg.relative ~= "" and _G.text(vim.api.nvim_win_get_buf(w)):find("myrepo", 1, true) then
            return w, cfg
          end
        end
      end]],
    },
    { wait = [[_G.chip() ~= nil]], note = "shown at startup" },
    { wait = [[_G.chip() == nil]], note = "and hidden again after timeout_ms" },

    { keys = ":Session save chip-test<CR>" },
    { expect = [[_G.chip() ~= nil]], note = "revealed by the save" },
    {
      expect = [[(function()
        local t = _G.text(vim.api.nvim_win_get_buf((_G.chip())))
        return _G.has(t, "myrepo") and _G.has(t, "main")
      end)()]],
      note = "folder and branch (text = modern)",
    },
    { expect = [[not _G.noted("saved: ")]], note = "no saved: notify" },
    {
      expect = [[(function()
        local _, cfg = _G.chip()
        return cfg.anchor ~= nil and cfg.col == 0 and cfg.row >= vim.o.lines - vim.o.cmdheight - 4
      end)()]],
      note = "in the bottom-left corner, on the statusline row",
    },
    { wait = [[_G.chip() == nil]], note = "hides itself" },

    { keys = ":Session load chip-test<CR>" },
    { expect = [[_G.chip() ~= nil and not _G.noted("loaded: ")]], note = "same on load" },
    { wait = [[_G.chip() == nil]] },

    { keys = ":Session chip-toggle<CR>" },
    { expect = [[_G.chip() ~= nil]], note = "a hidden chip shows" },
    { keys = ":Session chip-toggle<CR>" },
    { expect = [[_G.chip() == nil]], note = "a visible one hides at once" },
    { keys = ":Session chip-toggle<CR>" },
    { expect = [[_G.chip() ~= nil]] },
    { wait = [[_G.chip() == nil]], note = "the toggle restarted the countdown" },

    { keys = ":Session load does-not-exist<CR>" },
    { expect = [[_G.noted("load failed: ")]], note = "errors stay visible with the chip" },
    {
      lua = [[_G.forget()
      _G.write("gone.txt")
      vim.cmd.edit("gone.txt")]],
    },
    { keys = ":Session save with-gone<CR>" },
    { lua = [[vim.cmd.edit("a.txt"); os.remove("gone.txt")]] },
    { keys = ":Session load with-gone<CR>", note = "the chip is visible: no E445 in v:errmsg" },
    { wait = [[_G.noted("dropped (file no longer exists): ") and _G.noted("gone.txt")]] },
    { expect = [[_G.chip() ~= nil]], note = "alongside the chip" },

    {
      lua = [[vim.cmd.split("b.txt")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
      _G.forget()]],
    },
    { keys = ":Session load chip-test<CR>" },
    {
      expect = [[_G.noted("hidden (unsaved): ") and not _G.noted("loaded: ")]],
      note = "the hidden note stays with the chip, only the loaded line is replaced",
    },
    { lua = [[vim.bo[vim.fn.bufnr("b.txt")].modified = false]] },

    {
      lua = [[_G.forget()
      require("ui.kit").chip.unmount("sessions")
      _G.setup({ autoload = true, chip = { timeout_ms = 400 } })]],
      note = "autoload, with the chip",
    },
    {
      wait = [[_G.chip() == nil]],
      timeout = 8000,
      note = "the startup flash and the toasts naming the project are over",
    },
    { lua = [[vim.api.nvim_exec_autocmds("VimEnter", {})]], note = "the start of a bare nvim" },
    { wait = [[_G.current() ~= nil and _G.chip() ~= nil]], note = "loaded and revealed" },
    { expect = [[not _G.noted("autoloaded: ")]], note = "no autoloaded: notify meanwhile" },
    { wait = [[_G.chip() == nil]], note = "hidden again after the timeout" },
  },
}
