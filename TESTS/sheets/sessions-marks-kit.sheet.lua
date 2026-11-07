-- Live check: section 16 of ALL/manual-test-checklists/sessions.md: the kit menu of ui.nvim, for real, and the fallback
-- when a named picker is not installed. Snacks, Telescope and fzf-lua themselves are in `manual`.
return {
  id = "sessions.marks-kit",
  title = "sessions.nvim: :Session marks opens the kit menu: preview, keys, close; a missing picker falls back",
  task = "sessions.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 120 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.with_ui()
      _G.dir = _G.repo("myrepo")
      local long = {}
      for i = 1, 200 do
        long[i] = "line " .. i
      end
      _G.write(_G.dir .. "/one.txt", long)
      _G.write(_G.dir .. "/two.txt", long)
      _G.setup({
        chip = { enable = false },
        marks = { enable = true, menu = { preview_keys = { close = { "q", "<Esc>", "<C-e>" } } } },
      })
      vim.cmd.edit("a.txt")
      local marks = require("sessions.marks")
      marks.add(_G.dir .. "/one.txt")
      marks.add(_G.dir .. "/two.txt")
      _G.floats = function()
        return vim.tbl_filter(function(w)
          return vim.api.nvim_win_get_config(w).relative ~= ""
            and vim.api.nvim_win_get_config(w).focusable
        end, vim.api.nvim_list_wins())
      end
      -- the float that shows the file's lines, whichever window has the focus
      _G.preview_win = function()
        for _, w in ipairs(_G.floats()) do
          if _G.text(vim.api.nvim_win_get_buf(w)):find("line 1\n", 1, true) then
            return w
          end
        end
      end
      _G.here = function()
        return vim.fs.basename(vim.api.nvim_buf_get_name(0))
      end
      _G.reset = function()
        vim.cmd("silent! tabonly | silent! only")
        vim.cmd.edit("a.txt")
      end]],
    },
    { keys = ":Session marks<CR>" },
    { wait = [[_G.preview_win() ~= nil]], note = "the kit menu, with a preview" },
    {
      expect = [[(function()
        local p = vim.api.nvim_win_get_position(_G.preview_win())
        local l = vim.api.nvim_win_get_position(0)
        return p[1] < l[1]
      end)()]],
      note = "the preview above the list",
    },
    {
      lua = [[_G.top = function()
        return vim.fn.getwininfo(_G.preview_win())[1].topline
      end
      _G.before = _G.top()]],
    },
    { keys = "<C-f>" },
    { wait = [[_G.top() > _G.before]], note = "<C-f> scrolls the preview" },
    { keys = "<C-p>" },
    { wait = [[_G.top() == _G.before]], note = "<C-p> back" },
    { keys = "<Tab>" },
    { wait = [[vim.api.nvim_get_current_win() == _G.preview_win()]], note = "<Tab> hops into it" },
    { keys = "<Tab>" },
    { wait = [[vim.api.nvim_get_current_win() ~= _G.preview_win()]], note = "and back" },
    { keys = "<Tab>" },
    { keys = "20G<CR>", note = "<CR> in the preview" },
    {
      wait = [[_G.here() == "one.txt" and vim.fn.line(".") == 20]],
      note = "at the preview's line",
    },
    { expect = [[#_G.floats() == 0]] },

    { lua = [[_G.reset()]] },
    { keys = ":Session marks<CR>" },
    { wait = [[_G.preview_win() ~= nil]] },
    { keys = "<C-x>", note = "split" },
    { wait = [[#_G.wins() == 2 and _G.here() == "one.txt"]] },
    { expect = [[vim.fn.winlayout()[1] == "col"]] },

    { lua = [[_G.reset()]] },
    { keys = ":Session marks<CR>" },
    { wait = [[_G.preview_win() ~= nil]] },
    { keys = "<C-v>", note = "vsplit" },
    { wait = [[#_G.wins() == 2 and _G.here() == "one.txt"]] },
    { expect = [[vim.fn.winlayout()[1] == "row"]] },

    { lua = [[_G.reset()]] },
    { keys = ":Session marks<CR>" },
    { wait = [[_G.preview_win() ~= nil]] },
    { keys = "<C-t>", note = "tab" },
    { wait = [[#vim.api.nvim_list_tabpages() == 2 and _G.here() == "one.txt"]] },

    { lua = [[_G.reset()]] },
    { keys = ":Session marks<CR>" },
    { wait = [[_G.preview_win() ~= nil]] },
    { keys = "q" },
    { wait = [[#_G.floats() == 0]], note = "q closes" },
    { keys = ":Session marks<CR>" },
    { wait = [[_G.preview_win() ~= nil]] },
    { keys = "<Esc>" },
    { wait = [[#_G.floats() == 0]], note = "<Esc> closes" },
    { keys = ":Session marks<CR>" },
    { wait = [[_G.preview_win() ~= nil]] },
    { keys = "<C-e>" },
    { wait = [[#_G.floats() == 0]], note = "<C-e> closes: this machine's marks.menu.preview_keys" },
    { keys = ":Session marks<CR>" },
    { wait = [[_G.preview_win() ~= nil]] },
    {
      lua = [[vim.api.nvim_set_current_win(_G.wins()[1])]],
      note = "a click into another window moves the focus there",
    },
    { wait = [[#_G.floats() == 0]], note = "the menu closes" },

    { keys = ":Session marks menu snacks<CR>" },
    { wait = [[vim.bo.filetype == "sessions-marks"]], note = "not installed: the edit menu" },
    { expect = [[_G.noted("snacks.nvim not available -- opening the edit menu")]] },
    { keys = "q" },
    { wait = [[vim.bo.filetype ~= "sessions-marks"]] },
    { keys = ":Session marks menu telescope<CR>" },
    { wait = [[vim.bo.filetype == "sessions-marks"]] },
    { expect = [[_G.noted("telescope.nvim not available -- opening the edit menu")]] },
    { keys = "q" },
    { wait = [[vim.bo.filetype ~= "sessions-marks"]] },
    { keys = ":Session marks menu fzf<CR>" },
    { wait = [[vim.bo.filetype == "sessions-marks"]] },
    { expect = [[_G.noted("fzf-lua not available -- opening the edit menu")]] },
    { keys = "q" },
    { wait = [[vim.bo.filetype ~= "sessions-marks"]] },
  },
  judge = { "the kit menu's list and preview read well" },
  manual = {
    "with Snacks, Telescope and fzf-lua installed: :Session marks menu snacks|telescope|fzf show the list with a preview",
  },
}
