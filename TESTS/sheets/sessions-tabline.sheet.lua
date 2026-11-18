-- The tabline of ui.nvim keeps its own buffer order (`vim.t.bufs`) and pins (`vim.t.ui_pinned`), which :mksession
-- does not carry. Reordered and pinned, saved, everything wiped, loaded: the bar comes back as it was left.
return {
  id = "sessions.tabline",
  feature = "sessions.tabline",
  title = "sessions.nvim: the tabline's buffer order and pins come back with the session",
  requires = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").add_deps("ui.nvim")]],
      reason = "ui.nvim is not beside this repository",
    },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.with_ui()
      _G.repo("myrepo")
      _G.write("c.txt")
      _G.tabline = require("ui.bindings.keymaps.tabufline.state")
      _G.tabline.setup()
      _G.setup({ chip = { enable = false } })
      -- the bar as base names, left to right
      _G.bar = function()
        local out = {}
        for _, b in ipairs(vim.t.bufs or {}) do
          out[#out + 1] = vim.fs.basename(vim.api.nvim_buf_get_name(b))
        end
        return out
      end
      _G.pins = function()
        local out = {}
        for _, b in ipairs(_G.tabline.pinned_bufs_for_tab(0) or {}) do
          out[#out + 1] = vim.fs.basename(vim.api.nvim_buf_get_name(b))
        end
        return out
      end]],
    },
    { keys = ":edit a.txt<CR>:edit b.txt<CR>:edit c.txt<CR>" },
    {
      expect = [[vim.deep_equal(_G.bar(), { "a.txt", "b.txt", "c.txt" })]],
      note = "opening order",
    },
    {
      lua = [[_G.tabline.move_buf(-1)]],
      note = "the tabline's move-left on c.txt, as its keymap does",
    },
    { expect = [[vim.deep_equal(_G.bar(), { "a.txt", "c.txt", "b.txt" })]] },
    { keys = ":buffer b.txt<CR>" },
    { lua = [[_G.tabline.toggle_pinned(vim.api.nvim_get_current_buf())]], note = "pin b.txt" },
    {
      expect = [[vim.deep_equal(_G.pins(), { "b.txt" }) and _G.bar()[1] == "b.txt"]],
      note = "pins go first",
    },
    { lua = [[_G.left = _G.bar()]] },
    { keys = ":Session save tl<CR>" },
    {
      expect = [[_G.stored(".tl.bufs.json") and _G.stored(".tl.pins.json")]],
      note = "the two companion files",
    },

    { keys = ":%bwipeout!<CR>", note = "every buffer gone, the bar and the pins empty" },
    { expect = [[#_G.pins() == 0]] },
    { keys = ":Session load tl<CR>" },
    { expect = [[_G.current() == "tl"]] },
    { expect = [[_G.same(_G.bar(), _G.left)]], note = "the order of the bar as it was left" },
    { expect = [[vim.deep_equal(_G.pins(), { "b.txt" })]], note = "b.txt is pinned again" },
  },
}
