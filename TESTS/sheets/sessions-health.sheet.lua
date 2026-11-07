-- Live check: Setup and section 13 of ALL/manual-test-checklists/sessions.md, the real :checkhealth report.
return {
  id = "sessions.health",
  title = "sessions.nvim: :checkhealth sessions, healthy and with the broken paths",
  task = "sessions.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      _G.setup({ chip = { enable = false } })
      _G.report = function()
        return _G.text(0)
      end
      _G.line_with = function(part)
        for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
          if line:find(part, 1, true) then
            return line
          end
        end
        error("no line with " .. part .. " in " .. _G.report(), 0)
      end]],
    },
    { keys = ":Session save one<CR>" },
    { keys = ":checkhealth sessions<CR>" },
    { wait = [[_G.report():find(":SessionLoad", 1, true) ~= nil]], note = "the report is done" },
    { expect = [[_G.line_with("Neovim >= 0.9"):find("OK", 1, true) ~= nil]] },
    { expect = [[_G.line_with("vim.json available"):find("OK", 1, true) ~= nil]] },
    { expect = [[_G.line_with("libuv available"):find("OK", 1, true) ~= nil]] },
    { expect = [[_G.line_with("vim.system available"):find("OK", 1, true) ~= nil]] },
    { expect = [[_G.line_with("plugin loaded"):find("OK", 1, true) ~= nil]] },
    { expect = [[_G.line_with("lib.nvim found"):find("OK", 1, true) ~= nil]] },
    { expect = [[_G.line_with("root: " .. _G.STORE) ~= nil]] },
    { expect = [[_G.line_with("default_name: last") and _G.line_with("branch_aware: true")]] },
    { expect = [[_G.line_with("save_last: true") and _G.line_with("1 session(s) stored")]] },
    { expect = [[_G.line_with(":LastSession registered"):find("OK", 1, true) ~= nil]] },
    { expect = [[_G.line_with(":SessionLoad registered"):find("OK", 1, true) ~= nil]] },
    { expect = [[_G.line_with("which-key not found") and _G.line_with("fzf-lua not installed")]] },
    {
      expect = [[_G.line_with("will error until"):find("WARNING", 1, true) == nil]],
      note = "no picker: info level, not a warning that overstates it",
    },
    { keys = ":tabclose<CR>" },

    {
      lua = [[_G.STORE = vim.fn.tempname() .. "/does-not-exist-yet"
      _G.setup({ chip = { enable = false } })]],
    },
    { keys = ":checkhealth sessions<CR>" },
    { wait = [[_G.report():find(":SessionLoad", 1, true) ~= nil]] },
    {
      expect = [[_G.line_with("session root does not exist yet (will be created on first save)")]],
    },
    {
      expect = [[_G.line_with("session root does not exist yet"):find("ERROR", 1, true) == nil]],
    },
    { keys = ":tabclose<CR>" },

    {
      lua = [[for _, name in ipairs({
        "lib.nvim.bindings.usercmd.composer",
        "lib.nvim.notify",
        "lib.nvim.git",
      }) do
        package.loaded[name] = nil
        package.preload[name] = function()
          error("no " .. name, 0)
        end
      end]],
      note = "lib.nvim gone, as far as the report can tell",
    },
    { keys = ":checkhealth sessions<CR>" },
    { wait = [[_G.report():find(":SessionLoad", 1, true) ~= nil]] },
    {
      expect = [[_G.line_with("lib.nvim not found"):find("ERROR", 1, true) ~= nil]],
      note = "the hard requirement is an error",
    },
    { expect = [[_G.line_with("lib.nvim.notify not found"):find("ERROR", 1, true) == nil]] },
    { expect = [[_G.line_with("lib.nvim.notify not found"):find("WARNING", 1, true) == nil]] },
    { expect = [[_G.line_with("lib.nvim.git not found"):find("ERROR", 1, true) == nil]] },
    { expect = [[_G.line_with("lib.nvim.git not found"):find("WARNING", 1, true) == nil]] },
  },
}
