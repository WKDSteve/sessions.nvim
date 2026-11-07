-- Live check: section 7 of ALL/manual-test-checklists/sessions.md.
return {
  id = "sessions.portable",
  title = "sessions.nvim: relative_paths stores a placeholder for new saves, root_remap applies at every load",
  task = "sessions.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.dir = _G.project("one")
      _G.copy = _G.project("two")
      for _, d in ipairs({ _G.dir, _G.copy }) do
        _G.write(d .. "/a.txt")
      end
      vim.cmd.cd(vim.fn.fnameescape(_G.dir))
      vim.cmd.edit("a.txt")
      _G.vim_file = function(name)
        return _G.read(_G.STORE .. "/" .. name .. ".vim")
      end
      _G.only_a = function(dir)
        local name = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
        return name == dir .. "/a.txt"
      end
      _G.setup({ chip = { enable = false }, relative_paths = false, autosave = false })]],
    },
    { keys = ":Session save before-flag<CR>", note = "saved with relative_paths = false" },
    {
      lua = [[_G.frozen = _G.vim_file("before-flag")
      _G.setup({ chip = { enable = false }, relative_paths = true, autosave = false })]],
    },
    {
      expect = [[_G.vim_file("before-flag") == _G.frozen
        and not _G.frozen:find("{{SESSION_ROOT}}", 1, true)]],
      note = "the retroactivity trap: the old file is not magically portable",
    },
    { keys = ":Session save portable-test<CR>" },
    { expect = [[_G.has(_G.vim_file("portable-test"), "{{SESSION_ROOT}}")]] },
    {
      expect = [[not _G.vim_file("portable-test"):find(_G.dir, 1, true)]],
      note = "no absolute path of the host",
    },
    {
      lua = [[_G.stored_text = _G.vim_file("portable-test")
      vim.cmd.cd(vim.fn.fnameescape(_G.copy))]],
      note = "another copy of the project",
    },
    { keys = ":Session load portable-test<CR>" },
    { expect = [[_G.only_a(_G.copy)]], note = "the placeholder resolves to the cwd of the load" },
    {
      expect = [[_G.vim_file("portable-test") == _G.stored_text]],
      note = "the file stays as it was",
    },

    {
      lua = [[-- a session saved with the plain setup, before any remap exists
      vim.cmd("silent! %bwipeout!")
      vim.cmd.cd(vim.fn.fnameescape(_G.dir))
      _G.setup({
        chip = { enable = false },
        autosave = false,
      })
      vim.cmd.edit("a.txt")]],
    },
    { keys = ":Session save remap-test<CR>", note = "saved before any remap exists" },
    {
      lua = [[-- as saved on another machine: :mksession writes a path below $HOME with a ~, which no
      -- key of root_remap matches, so the session is spelled with a path of no home directory
      local file = _G.STORE .. "/remap-test.vim"
      local lines = vim.fn.readfile(file)
      local found = false
      for i, line in ipairs(lines) do
        if line:sub(1, 3) == "cd " then
          lines[i], found = "cd X:/old/path", true
        end
      end
      assert(found, "no cd line in the session")
      vim.fn.writefile(lines, file)
      vim.cmd("silent! %bwipeout!")
      _G.setup({
        chip = { enable = false },
        autosave = false,
        root_remap = { ["X:/old/path"] = _G.copy },
      })]],
    },
    { keys = ":Session load remap-test<CR>" },
    { expect = [[_G.only_a(_G.copy)]], note = "applies to a file saved before the remap" },
  },
}
