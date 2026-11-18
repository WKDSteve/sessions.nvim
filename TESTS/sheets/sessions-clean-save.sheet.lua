-- What a save leaves out: the quickfix list, a scratch buffer and a file below a blacklisted path are shown in splits
-- when :Session save runs; the session file names none of them, and loading it brings back the file alone.
return {
  id = "sessions.clean-save",
  feature = "sessions.clean-save",
  title = "sessions.nvim: quickfix, scratch and temp buffers stay out of a saved session",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      -- the temp directory of a person's machine, here one of the sheet's own
      local tmpzone = _G.project("tmpzone")
      _G.write(tmpzone .. "/scratchpad.txt")
      vim.g.sheet_tmp_file = tmpzone .. "/scratchpad.txt"
      _G.setup({ chip = { enable = false }, blacklist = { paths = { tmpzone .. "/" } } })]],
    },
    { keys = ":edit a.txt<CR>" },
    { keys = ":vimgrep /a/j a.txt<CR>:copen<CR>", note = "the quickfix window" },
    { keys = ":wincmd p<CR>:vnew<CR>:setlocal buftype=nofile<CR>:file notes-scratch<CR>" },
    {
      keys = ":execute 'split' fnameescape(g:sheet_tmp_file)<CR>",
      note = "a file below the temp path",
    },
    {
      expect = [[#_G.wins() == 4]],
      note = "a.txt, the quickfix list, the scratch buffer and the temp file are on screen",
    },
    { keys = ":Session save clean<CR>" },
    { expect = [[_G.stored("clean.vim")]] },
    { lua = [[_G.saved = _G.read(_G.STORE .. "/clean.vim")]] },
    { expect = [[_G.has(_G.saved, "a.txt")]] },
    {
      expect = [[not _G.saved:find("scratchpad.txt", 1, true)]],
      note = "the temp file is not in it",
    },
    {
      expect = [[not _G.saved:find("notes-scratch", 1, true)]],
      note = "the scratch buffer is not in it",
    },
    {
      expect = [[not _G.saved:find("quickfix", 1, true) and not _G.saved:find("copen", 1, true)]],
      note = "the quickfix window is not in it",
    },

    { keys = ":%bwipeout!<CR>", note = "a fresh start in the same editor" },
    { keys = ":Session load clean<CR>" },
    { expect = [[vim.deep_equal(_G.shown(), { "a.txt" })]], note = "the file alone comes back" },
  },
}
