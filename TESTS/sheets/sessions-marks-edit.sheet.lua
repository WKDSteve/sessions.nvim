-- Live check: section 16 of ALL/manual-test-checklists/sessions.md: pins, defaults and the edit menu with its question.
return {
  id = "sessions.marks-edit",
  feature = "sessions.marks",
  title = "sessions.nvim: pin, unpin, defaults sync/reset, the edit menu and its question on a pinned line",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.with_ui()
      _G.dir = _G.repo("myrepo")
      for _, name in ipairs({ "plain.md", "keep.lua", "def1.txt", "def2.txt" }) do
        _G.write(_G.dir .. "/" .. name)
      end
      _G.setup({
        chip = { enable = false },
        marks = { enable = true, defaults = { _G.dir .. "/def1.txt", _G.dir .. "/def2.txt" } },
      })
      _G.names = function()
        return vim.tbl_map(function(it)
          return vim.fs.basename(it.path)
        end, require("sessions.marks").list())
      end
      _G.dialog = function()
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_config(w).relative ~= "" then
            local t = _G.text(vim.api.nvim_win_get_buf(w))
            if t:find("about to leave", 1, true) then
              return t
            end
          end
        end
        return ""
      end
      vim.cmd.edit("plain.md")]],
    },
    { keys = ":Session marks add<CR>" },
    { lua = [[vim.cmd.edit("keep.lua")]] },
    { keys = ":Session marks pin<CR>", note = "a file not listed yet" },
    { expect = [[vim.tbl_contains(_G.names(), "keep.lua")]], note = "added and pinned" },
    { expect = [[require("sessions.marks").is_pinned(_G.dir .. "/keep.lua")]] },
    { expect = [[_G.stored("marks/pins.json")]] },

    { keys = ":Session marks menu edit<CR>" },
    { wait = [[vim.bo.filetype == "sessions-marks"]] },
    {
      expect = [[(function()
        local ns = vim.api.nvim_get_namespaces().sessions_marks_menu
        local shown = {}
        for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
          for _, chunk in ipairs(m[4].virt_text or {}) do
            shown[#shown + 1] = chunk[1]
          end
        end
        return _G.has(table.concat(shown), "pin")
      end)()]],
      note = "the pin marker on the pinned line",
    },
    { keys = "ggdd", note = "delete a plain line: no question" },
    { keys = ":w<CR>" },
    { wait = [[not vim.tbl_contains(_G.names(), "plain.md")]], note = ":w, the list follows" },
    { keys = "q" },
    { wait = [[vim.bo.filetype ~= "sessions-marks"]] },

    { keys = ":Session marks unpin<CR>" },
    { expect = [[not require("sessions.marks").is_pinned(_G.dir .. "/keep.lua")]] },
    { expect = [[vim.tbl_contains(_G.names(), "keep.lua")]], note = "the list entry stays" },
    { keys = ":Session marks pin<CR>" },

    {
      lua = [[require("sessions.marks").defaults_reset()
      vim.cmd.edit("plain.md")]],
    },
    { keys = ":Session marks add<CR>" },
    {
      lua = [[require("sessions.marks").remove(_G.dir .. "/def2.txt")]],
      note = "a default is gone",
    },
    { keys = ":Session marks defaults sync<CR>" },
    {
      expect = [[vim.deep_equal(_G.names(), { "def1.txt", "keep.lua", "plain.md", "def2.txt" })]],
      note = "sync appends what is missing, the rest stays",
    },
    { keys = ":Session marks defaults reset<CR>" },
    {
      expect = [[vim.deep_equal(_G.names(), { "def1.txt", "def2.txt", "keep.lua" })]],
      note = "reset: exactly defaults + pins, in that order; the plain mark is gone",
    },

    { keys = ":Session marks menu edit<CR>" },
    { wait = [[vim.bo.filetype == "sessions-marks"]] },
    { keys = "Gdd", note = "delete the pinned line" },
    { keys = ":w<CR>" },
    { wait = [[_G.has(_G.dialog(), "about to leave the list")]], note = "it asks" },
    {
      expect = [[_G.has(_G.dialog(), "List only") and _G.has(_G.dialog(), "Unpin too")
        and _G.has(_G.dialog(), "Keep it")]],
    },
    { keys = "k", note = "Keep it" },
    { wait = [[_G.dialog() == ""]] },
    { wait = [[vim.tbl_contains(_G.names(), "keep.lua")]] },
    { expect = [[require("sessions.marks").is_pinned(_G.dir .. "/keep.lua")]] },
    { keys = "Gdd" },
    { keys = ":w<CR>" },
    { wait = [[_G.dialog() ~= ""]] },
    { keys = "u", note = "Unpin too" },
    { wait = [[_G.dialog() == "" and not vim.tbl_contains(_G.names(), "keep.lua")]] },
    { expect = [[not require("sessions.marks").is_pinned(_G.dir .. "/keep.lua")]] },
    { keys = "q" },
    { wait = [[vim.bo.filetype ~= "sessions-marks"]] },

    {
      lua = [[local marks = require("sessions.marks")
      marks.pin(_G.dir .. "/keep.lua")]],
    },
    { keys = ":Session marks menu edit<CR>" },
    { wait = [[vim.bo.filetype == "sessions-marks"]] },
    { keys = "Gdd" },
    { keys = ":w<CR>" },
    { wait = [[_G.dialog() ~= ""]] },
    { keys = "<CR>", note = "List only: the first button" },
    { wait = [[_G.dialog() == "" and not vim.tbl_contains(_G.names(), "keep.lua")]] },
    {
      expect = [[require("sessions.marks").is_pinned(_G.dir .. "/keep.lua")]],
      note = "still pinned, back with the next sync",
    },

    { keys = "ggddGp", note = "reorder: the first line goes last" },
    { keys = "q", note = "q closes and the list follows, like :w" },
    { wait = [[vim.bo.filetype ~= "sessions-marks"]] },
    { wait = [[vim.deep_equal(_G.names(), { "def2.txt", "def1.txt" })]] },
  },
}
