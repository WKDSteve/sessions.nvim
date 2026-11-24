-- A plain `nvim` (no argument, any directory) loads no session; only `nvim +LastSession` / `:Session load last` bring
-- the last one back. Every "start" is a second Neovim, a real process with a real exit, on the same temporary store
-- (`_G.proc`), set up with the plugin's defaults -- `autoload` is not given.
return {
  id = "sessions.bare-start",
  feature = "sessions.autoload",
  title = "sessions.nvim: a bare nvim start loads nothing, +LastSession and :Session load last still do",
  task = "sessions.nvim/nvim-startet-immer-in-der-lastsession-nur-lastsession-bzw",
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
      note = "a real session: two files in a split, quit (autosave and the last snapshot are written)",
    },
    { expect = [[_G.stored("last.vim")]], note = "the snapshot `:LastSession` loads exists" },

    {
      lua = [[_G.state = _G.proc([=[
        _G.setup()
        _G.finish()
      ]=], { cwd = _G.dir })]],
      note = "bare nvim, in the very project the session was saved in",
    },
    { expect = [[_G.state.current == vim.NIL]], note = "no session is tracked" },
    {
      expect = [[vim.deep_equal(_G.state.shown, { "" })]],
      note = "one empty window: nothing was restored",
    },

    {
      lua = [[_G.state = _G.proc([=[
        _G.setup()
        _G.finish()
      ]=], { cwd = _G.project("unrelated") })]],
      note = "bare nvim, in an unrelated directory",
    },
    { expect = [[_G.state.current == vim.NIL]] },
    { expect = [[vim.deep_equal(_G.state.shown, { "" })]], note = "same: nothing restored" },

    {
      lua = [[_G.state = _G.proc([=[
        _G.setup()
        vim.cmd.LastSession()
        _G.finish()
      ]=], { cwd = _G.project("unrelated") })]],
      note = "nvim +LastSession from the unrelated directory",
    },
    { expect = [[_G.state.current == "last"]], note = "the last session is loaded" },
    { expect = [[vim.deep_equal(_G.state.shown, { "a.txt", "b.txt" })]], note = "with its split" },

    {
      lua = [[_G.state = _G.proc([=[
        _G.setup()
        vim.cmd("Session load last")
        _G.finish()
      ]=], { cwd = _G.project("unrelated") })]],
      note = ":Session load last",
    },
    { expect = [[_G.state.current == "last"]] },
    { expect = [[vim.deep_equal(_G.state.shown, { "a.txt", "b.txt" })]] },

    {
      lua = [[_G.state = _G.proc([=[
        _G.setup()
        _G.finish()
      ]=], { cwd = _G.project("unrelated") })]],
      note = "bare nvim once more, after the explicit loads and their exit",
    },
    { expect = [[_G.state.current == vim.NIL]], note = "still nothing is restored on its own" },
  },
}
