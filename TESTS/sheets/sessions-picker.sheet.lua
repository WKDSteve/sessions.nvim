-- Live check: section 4 of ALL/manual-test-checklists/sessions.md. Neither Snacks nor Telescope runs on CI: a stand-in
-- for Snacks.picker takes what :SessionLoad hands over and plays its actions back. The real pickers are in `manual`.
return {
  id = "sessions.picker",
  title = "sessions.nvim: :SessionLoad hands over items and previews, <CR> loads, <C-d> deletes the selection",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.with_ui()
      _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      _G.setup({ chip = { enable = false } })]],
    },
    { keys = ":SessionLoad<CR>", note = "zero sessions" },
    { expect = [[_G.noted("no sessions saved yet")]], note = "a note, no picker window" },
    {
      expect = [[#vim.tbl_filter(function(w)
        return vim.api.nvim_win_get_config(w).relative ~= "" and
          vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "prompt"
      end, vim.api.nvim_list_wins()) == 0]],
    },

    { keys = ":Session save with-meta<CR>" },
    { keys = ":Session save other<CR>" },
    { keys = ":Session save third<CR>" },
    { lua = [[os.remove(_G.STORE .. "/.other.json")]], note = "a session with no metadata" },
    { keys = ":SessionLoad<CR>", note = "no backend" },
    { expect = [[_G.noted("requires snacks.nvim (with picker) or telescope.nvim")]] },

    {
      lua = [[package.loaded["snacks"] = {
        picker = {
          pick = function(opts)
            _G.pick = opts
          end,
        },
      }
      _G.item = function(name)
        for _, it in ipairs(_G.pick.items) do
          if it.name == name then
            return it
          end
        end
      end
      _G.closed = 0
      _G.fake = {
        close = function() _G.closed = _G.closed + 1 end,
        refresh = function() _G.refreshed = true end,
        selected = function() return { _G.item("other"), _G.item("third") } end,
      }]],
    },
    { keys = ":SessionLoad<CR>", note = "the stand-in takes it" },
    { expect = [[#_G.pick.items == 3]] },
    {
      expect = [[(function()
        local p = _G.item("with-meta").preview.text
        return _G.has(p, "Saved:") and _G.has(p, "Branch: main") and _G.has(p, "Cwd:")
          and _G.has(p, "Buffers:") and _G.has(p, "a.txt")
      end)()]],
      note = "the preview: timestamp, branch, cwd, buffers",
    },
    {
      expect = [[_G.has(_G.item("other").preview.text, "(no metadata recorded")]],
      note = "no metadata says so, no blank pane",
    },
    {
      lua = [[vim.cmd.edit("b.txt")
      _G.pick.confirm(_G.fake, _G.item("with-meta"))]],
      note = "<CR> on an entry",
    },
    { expect = [[_G.current() == "with-meta" and vim.deep_equal(_G.shown(), { "a.txt" })]] },
    { expect = [[_G.closed == 1]] },

    { lua = [[_G.forget(); _G.pick.opts = _G.pick; _G.fake.opts = _G.pick]] },
    { lua = [[_G.pick.actions.sessions_delete(_G.fake)]], note = "<C-d> with two selected" },
    {
      wait = [[vim.api.nvim_get_current_win() ~= nil and
        _G.text(vim.api.nvim_win_get_buf(0)):find("Delete 2 session", 1, true) ~= nil]],
      note = "one question for both",
    },
    { keys = "y" },
    { wait = [[_G.noted("deleted: other, third")]], note = "every deleted name" },
    { expect = [[not _G.stored("other.vim") and not _G.stored("third.vim")]] },
    {
      expect = [[#_G.pick.items == 1 and _G.pick.items[1].name == "with-meta" and _G.refreshed]],
      note = "gone from the picker's own list, no re-open",
    },
  },
  manual = {
    "with real Snacks and Telescope: :SessionLoad shows the list and the preview pane, multi-select works",
  },
}
