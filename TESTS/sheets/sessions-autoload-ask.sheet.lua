-- Live check: section 1 of ALL/manual-test-checklists/sessions.md, the prompt of autoload = "ask".
-- `doautocmd VimEnter` stands in for the start: the prompt is a float a headless second process has nobody to answer.
return {
  id = "sessions.autoload-ask",
  title = 'sessions.nvim: autoload = "ask" names the session; yes loads it, no leaves an empty buffer',
  task = "sessions.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      _G.proc([=[
        _G.setup({ save_last = false })
        vim.cmd.edit("a.txt")
        _G.finish()
      ]=])
      _G.ask = function()
        _G.setup({ autoload = "ask", autosave = false, save_last = false, chip = { enable = false } })
        vim.api.nvim_exec_autocmds("VimEnter", {})
      end
      _G.float_text = function()
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_config(w).relative ~= "" then
            local t = _G.text(vim.api.nvim_win_get_buf(w))
            if t:find("Restore session", 1, true) then
              return t
            end
          end
        end
        return ""
      end
      _G.ask()]],
    },
    {
      wait = [[_G.has(_G.float_text(), "Restore session 'myrepo_main'?")]],
      note = "a float, named",
    },
    { keys = "n", note = "decline" },
    { wait = [[_G.float_text() == ""]] },
    { expect = [[_G.current() == nil]], note = "nothing was loaded" },
    {
      expect = [[vim.api.nvim_buf_get_name(0) == "" and #vim.api.nvim_list_bufs() == 1]],
      note = "an empty buffer, no partial load",
    },

    { lua = [[_G.ask()]] },
    { wait = [[_G.float_text() ~= ""]] },
    { keys = "y", note = "accept" },
    { wait = [[_G.current() == "myrepo_main"]] },
    { expect = [[vim.deep_equal(_G.shown(), { "a.txt" })]] },
    { expect = [[_G.noted("autoloaded: ")]], note = "no chip: the notify" },
  },
}
