-- Live check: section 1 of ALL/manual-test-checklists/sessions.md. Every "restart" is a second Neovim, a real process
-- with a real exit, on the same temporary store (`_G.proc`).
return {
  id = "sessions.exit",
  feature = "sessions.autosave",
  title = "sessions.nvim: the exit writes the project's session and last.vim, :LastSession brings them back",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.dir = _G.repo("myrepo")
      _G.proc([=[
        _G.setup()
        vim.cmd.edit("a.txt")
        vim.cmd.vsplit("b.txt")
        _G.finish()
      ]=])]],
      note = "a real session: two files in a split, quit",
    },
    {
      expect = [[_G.stored("myrepo_main.vim")]],
      note = "the autosave wrote the project's own session, not last",
    },
    { expect = [[_G.stored("last.vim")]], note = "the snapshot too" },

    {
      lua = [[_G.state = _G.proc([=[
        _G.setup()
        vim.cmd.LastSession()
        _G.finish()
      ]=], { cwd = _G.project("unrelated") })]],
      note = "nvim +LastSession from an unrelated directory",
    },
    {
      expect = [[vim.deep_equal(_G.state.shown, { "a.txt", "b.txt" })]],
      note = "the same buffers and the split",
    },
    { expect = [[_G.state.current == "last"]] },

    {
      lua = [[_G.state = _G.proc([=[
        _G.setup()
        vim.cmd("Session load myrepo_main")
        _G.finish()
      ]=])]],
      note = ":Session load <project>_<branch>, quit",
    },
    {
      expect = [[vim.json.decode(_G.read(_G.STORE .. "/.state.json")).last_loaded == "myrepo_main"]],
      note = "the snapshot did not move the remembered pointer",
    },

    {
      lua = [[_G.mark = function() _G.write(_G.STORE .. "/last.vim", { "sentinel" }) end
      _G.untouched = function() return _G.read(_G.STORE .. "/last.vim") == "sentinel" end
      _G.mark()
      _G.proc([=[ _G.setup(); _G.finish() ]=], { cwd = _G.project("empty") })]],
      note = "bare nvim, then quit",
    },
    { expect = [[_G.untouched()]], note = "an empty start does not erase the last session" },
    {
      lua = [[_G.proc([=[
        _G.setup()
        vim.cmd.edit(".git/COMMIT_EDITMSG")
        vim.bo.filetype = "gitcommit"
        _G.finish()
      ]=])]],
      note = "a lone commit message",
    },
    { expect = [[_G.untouched()]], note = "same for it" },

    {
      lua = [[_G.state = _G.proc([=[
        _G.setup({ save_last = false })
        vim.cmd.edit("a.txt")
        _G.finish()
      ]=])]],
    },
    { expect = [[_G.untouched()]], note = "save_last = false: last.vim is not rewritten" },
    {
      lua = [[os.remove(_G.STORE .. "/.state.json")
      _G.state = _G.proc([=[
        _G.setup({ save_last = false })
        vim.cmd.LastSession()
        _G.finish()
      ]=])]],
    },
    {
      expect = [[_G.state.current == "myrepo_main"]],
      note = ":LastSession falls back to a bare :Session load",
    },

    {
      lua = [[_G.proc([=[
        _G.setup({ autosave_name = "pinned" })
        vim.cmd.edit("a.txt")
        _G.finish()
      ]=], { cwd = _G.dir })]],
    },
    {
      expect = [[_G.stored("pinned.vim") and not _G.untouched()]],
      note = "autosave_name = pinned, last.vim too",
    },

    {
      lua = [[_G.mark()
      os.remove(_G.STORE .. "/myrepo_main.vim")
      os.remove(_G.STORE .. "/pinned.vim")
      _G.proc([=[
        _G.setup({ autosave_name = false })
        vim.cmd.edit("a.txt")
        _G.finish()
      ]=])]],
    },
    {
      expect = [[not _G.stored("myrepo_main.vim") and not _G.stored("pinned.vim") and not _G.untouched()]],
      note = "autosave_name = false: no autosave file, last.vim still written",
    },

    {
      lua = [[_G.proc([=[
        _G.setup()
        vim.cmd.edit("b.txt")
        _G.finish()
      ]=])
      _G.state = _G.proc([=[
        _G.setup({ autoload = true })
        _G.finish()
      ]=])]],
      note = "autoload = true, a bare nvim",
    },
    {
      expect = [[_G.state.current == "myrepo_main" and vim.deep_equal(_G.state.shown, { "b.txt" })]],
    },

    {
      lua = [[_G.state = _G.proc([=[
        _G.setup({ autoload = true })
        _G.finish()
      ]=], { args = { "a.txt" } })]],
      note = "nvim a.txt: an explicit file arg",
    },
    {
      expect = [[_G.state.current == vim.NIL and vim.deep_equal(_G.state.shown, { "a.txt" })]],
      note = "no autoload",
    },
  },
}
