-- Live check: section 14 of ALL/manual-test-checklists/sessions.md: what cfg.chip decides. One child editor per
-- `kit.chip` id would be slower than a remount, and the plugin mounts once per setup, so each case mounts anew.
return {
  id = "sessions.chip-config",
  feature = "sessions.chip",
  title = "sessions.nvim: anchor, shape, min_width, timeout_ms, track_mode and pulse of the chip",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.with_ui()
      vim.o.laststatus = 2
      _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      -- what the plugin hands to `ui.kit.chip`, on the way to the real thing
      local chip = require("ui.kit").chip
      local mount, pulse = chip.mount, chip.pulse
      chip.mount = function(opts) _G.mounted = opts; return mount(opts) end
      chip.pulse = function(id, opts) _G.pulsed = opts; return pulse(id, opts) end
      _G.chip_win = function()
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local cfg = vim.api.nvim_win_get_config(w)
          if cfg.relative ~= "" and _G.text(vim.api.nvim_win_get_buf(w)):find("myrepo", 1, true) then
            return w, cfg
          end
        end
      end
      _G.remount = function(opts)
        pcall(chip.unmount, "sessions")
        _G.setup({ chip = vim.tbl_extend("force", { timeout_ms = false }, opts) })
      end
      _G.remount({ anchor = "top-right" })]],
    },
    {
      expect = [[_G.mounted.shape == "rounded_chip"]],
      note = "dock_left falls back: never a backwards box",
    },
    {
      wait = [[(function()
        local w, cfg = _G.chip_win()
        if not w then
          return false
        end
        local pos = vim.api.nvim_win_get_position(w)
        return pos[1] <= 2 and pos[2] + cfg.width >= vim.o.columns - 3
      end)()]],
      note = "top right",
    },

    { lua = [[_G.remount({ anchor = "bottom-left", col_offset = 4 })]] },
    { expect = [[_G.mounted.shape == "rounded_chip"]], note = "a real col_offset falls back too" },

    { lua = [[_G.remount({ anchor = "bottom-left" })]] },
    { expect = [[_G.mounted.shape == "dock_left"]], note = "the default stays where it fits" },

    { lua = [[_G.remount({ shape = "classic" })]] },
    { wait = [[_G.chip_win() ~= nil]] },
    {
      expect = [[(function()
        local _, cfg = _G.chip_win()
        return cfg.border == nil or cfg.border == "none"
      end)()]],
      note = "shape = classic draws no box",
    },

    { lua = [[_G.remount({ min_width = 60 })]] },
    { wait = [[_G.chip_win() ~= nil]] },
    {
      expect = [[(function()
        local _, cfg = _G.chip_win()
        return cfg.width >= 60
      end)()]],
      note = "min_width widens a short chip",
    },

    { lua = [[_G.remount({ timeout_ms = false })]] },
    { wait = [[_G.chip_win() ~= nil]] },
    { settle = 500 },
    { expect = [[_G.chip_win() ~= nil]], note = "timeout_ms = false keeps it up" },

    {
      lua = [[_G.colors = 0
      _G.remount({
        track_mode = true,
        color = function()
          _G.colors = _G.colors + 1
          return vim.api.nvim_get_mode().mode == "i" and "DiagnosticOk" or "DiagnosticWarn"
        end,
      })
      _G.colors = 0]],
      note = "a color function that follows the mode",
    },
    { input = "i" },
    { wait = [[vim.api.nvim_get_mode().mode == "i"]] },
    { wait = [[_G.colors > 0]], note = "the color is asked again on the mode change" },
    { input = "<Esc>" },
    { wait = [[vim.api.nvim_get_mode().mode == "n"]] },

    { lua = [[_G.remount({ text = "classic_text" })]] },
    { keys = ":Session save myrepo-classic<CR>" },
    { wait = [[_G.chip_win() ~= nil]] },
    { lua = [[_G.chip_text = _G.text(vim.api.nvim_win_get_buf((_G.chip_win())))]] },
    { keys = ":split<CR>", note = "the dirty marker, on the structural event" },
    {
      wait = [[_G.text(vim.api.nvim_win_get_buf((_G.chip_win()))) ~= _G.chip_text]],
      note = "a visible chip with classic_text shows it too",
    },
    { keys = ":close<CR>" },

    { lua = [[_G.pulsed = nil; _G.remount({ pulse = false })]] },
    { keys = ":Session save pulse-off<CR>" },
    {
      expect = [[_G.pulsed == nil and _G.chip_win() ~= nil]],
      note = "pulse = false: no flash, still revealed",
    },

    {
      lua = [[_G.remount({ pulse = true, pulse_color = "DiagnosticOk" })]],
    },
    { lua = [[_G.pulsed = nil]] },
    { keys = ":Session chip-toggle<CR>" },
    { keys = ":Session chip-toggle<CR>" },
    { expect = [[_G.pulsed == nil]], note = "no colour pulse on a toggle" },
    { keys = ":Session save pulse-on<CR>" },
    {
      expect = [[_G.pulsed ~= nil and _G.pulsed.color == "DiagnosticOk"]],
      note = "pulse = true asks for the color",
    },
  },
  judge = { "the flash of pulse = true reads as a brief confirmation on top of the chip's colour" },
}
