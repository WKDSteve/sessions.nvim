-- Live check: section 8 of ALL/manual-test-checklists/sessions.md.
return {
  id = "sessions.tabs",
  feature = "sessions.tabs",
  title = "sessions.nvim: tab sessions live apart, open in a new tab and leave the tracked session alone",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      _G.setup({ chip = { enable = false } })]],
    },
    { keys = ":Session save x<CR>", note = "the tracked session" },
    {
      lua = [[_G.pointer = function()
        return vim.json.decode(_G.read(_G.STORE .. "/.state.json")).last_loaded
      end]],
    },
    { keys = ":tabnew<CR>" },
    { lua = [[vim.cmd.edit("b.txt")]] },
    { keys = ":Session save-tab tab-test<CR>" },
    { expect = [[_G.stored(".tabs/tab-test.vim") and not _G.stored("tab-test.vim")]] },
    { expect = [[_G.current() == "x" and _G.pointer() == "x"]], note = "tracking untouched" },
    { lua = [[_G.forget()]] },
    { keys = ":Session list<CR>" },
    { expect = [[not _G.noted("tab-test")]], note = "not in :Session list" },
    {
      lua = [[package.loaded["snacks"] = { picker = { pick = function(o) _G.pick = o end } }]],
    },
    { keys = ":SessionLoad<CR>" },
    {
      expect = [[#vim.tbl_filter(function(i)
        return i.name == "tab-test"
      end, _G.pick.items) == 0]],
      note = "not in the picker",
    },

    { keys = ":tabclose<CR>" },
    { expect = [[#vim.api.nvim_list_tabpages() == 1]] },
    { keys = ":Session load-tab tab-test<CR>" },
    { expect = [[#vim.api.nvim_list_tabpages() == 2 and vim.deep_equal(_G.shown(), { "b.txt" })]] },
    {
      expect = [[(function()
        local first = vim.api.nvim_list_tabpages()[1]
        local w = vim.api.nvim_tabpage_get_win(first)
        return vim.fs.basename(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))) == "a.txt"
      end)()]],
      note = "the other tab is untouched",
    },
    { expect = [[_G.current() == "x" and _G.pointer() == "x"]], note = "tracking still untouched" },

    { keys = ":Session save-tab<CR>", note = "bare, with session x tracked" },
    {
      expect = [[_G.stored(".tabs/myrepo_main.vim") and not _G.stored(".tabs/x.vim")]],
      note = "named from project and branch, never from the tracked session",
    },

    { lua = [[_G.forget(); _G.answer = { require("sessions.core").load_tab(nil) }]] },
    { expect = [[_G.answer[1] == false and _G.answer[2] == "tab session name required"]] },
    { lua = [[vim.o.cmdheight = 6; vim.cmd("messages clear")]], note = "room for the usage text" },
    { keys = ":Session load-tab<CR>", ignore_errmsg = true, note = "the command refuses too" },
    {
      expect = [[_G.has(vim.api.nvim_exec2("messages", { output = true }).output, "missing")]],
    },
    { expect = [[#vim.api.nvim_list_tabpages() == 2]], note = "no default, no new tab" },
  },
}
