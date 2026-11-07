-- Live check: section 12 of ALL/manual-test-checklists/sessions.md. which-key is a stand-in that records the group; the
-- attach file of the machine (lua/bindings/mappings/sessions.lua) is the owner's real config and stays in `manual`.
return {
  id = "sessions.keymaps",
  title = "sessions.nvim: keymaps press their commands, a list of lhs works, a desc on each, a group label",
  task = "sessions.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.repo("myrepo")
      vim.cmd.edit("a.txt")
      vim.g.mapleader = " "
      _G.groups = {}
      package.loaded["which-key"] = {
        add = function(specs)
          for _, spec in ipairs(specs) do
            if spec.group then
              _G.groups[#_G.groups + 1] = spec[1]
            end
          end
        end,
      }
      _G.setup({
        chip = { enable = false },
        keymaps = {
          save = "<leader>ssa",
          load = "<leader>slo",
          list = { "<leader>sli", "<leader>sl2" },
        },
      })]],
    },
    { keys = " ssa", note = "<leader>ssa: :Session save" },
    { expect = [[_G.current() == "myrepo_main" and _G.stored("myrepo_main.vim")]] },
    { lua = [[vim.cmd.edit("b.txt")]] },
    { keys = " slo", note = "<leader>slo: :Session load" },
    { expect = [[vim.deep_equal(_G.shown(), { "a.txt" })]] },
    { lua = [[_G.forget()]] },
    { keys = " sli", note = "the first of a list of two" },
    { expect = [[_G.noted("myrepo_main")]] },
    { lua = [[_G.forget()]] },
    { keys = " sl2", note = "the second, on its own" },
    { expect = [[_G.noted("myrepo_main")]] },
    {
      expect = [[vim.fn.maparg("<leader>ssa", "n", false, true).desc == "Session: save"]],
      note = "a real desc",
    },
    { expect = [[vim.fn.maparg("<leader>sl2", "n", false, true).desc == "Session: list"]] },
    {
      expect = [[vim.tbl_contains(_G.groups, "<leader>s")]],
      note = "the group label on the longest shared prefix",
    },

    {
      lua = [[for _, lhs in ipairs({ "<leader>ssa", "<leader>slo", "<leader>sli", "<leader>sl2" }) do
        vim.keymap.del("n", lhs)
      end
      _G.groups = {}
      _G.setup({
        chip = { enable = false },
        keymaps = { save = "<leader>a", load = "<leader>zzz" },
      })]],
      note = "keys with no prefix in common",
    },
    {
      expect = [[vim.fn.maparg("<leader>a", "n") ~= "" and #_G.groups == 0]],
      note = "no group label rather than a wrong one",
    },
  },
  manual = {
    "the machine's own attach (lua/bindings/mappings/sessions.lua at UIReady): :map <leader>hm, <C-e>, <M-s>, <M-1>",
    "which-key itself shows the Session group on <leader>h",
  },
}
