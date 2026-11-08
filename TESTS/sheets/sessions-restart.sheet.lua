-- Live check: section 1 of ALL/manual-test-checklists/sessions.md, once for real: a project with splits is quit, the
-- same editor starts again with `+LastSession`, and the layout is the one it was quit with. The `restart` step of
-- testing.nvim quits the child as a person does (`:qall!`, the plugin's VimLeavePre writes the session) and starts it
-- again in the same sandbox; store and project live below its `stdpath("data")` (`_G.persistent`).

-- the window tree without window ids, each leaf with its file and size (`sizes = false`: without the sizes); both
-- editors define it, the first one's globals are gone after the restart
local SHAPE = [[
_G.shape = function(node, sizes)
  node = node or vim.fn.winlayout()
  if node[1] == "leaf" then
    local w = node[2]
    local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)), ":t")
    if sizes == false then
      return { "leaf", file }
    end
    return { "leaf", file, vim.api.nvim_win_get_width(w), vim.api.nvim_win_get_height(w) }
  end
  local kids = { node[1] }
  for _, child in ipairs(node[2]) do
    kids[#kids + 1] = _G.shape(child, sizes)
  end
  return kids
end
_G.quit_file = vim.fn.stdpath("data") .. "/sheet/quit-shape.json"
]]

return {
  id = "sessions.restart",
  title = "sessions.nvim: quit a project with splits, nvim +LastSession brings the same layout back",
  task = "sessions.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 120 } },
  steps = {
    {
      lua = SHAPE
        .. [[
      dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.persistent()
      _G.repo("myrepo")
      _G.setup({ chip = { enable = false } })
      vim.cmd.edit("a.txt")
      vim.cmd.vsplit("b.txt")
      vim.cmd.split("a.txt")
      vim.api.nvim_win_set_width(0, 40)
      vim.api.nvim_win_set_height(0, 12)
      vim.fn.writefile({ vim.json.encode({ full = _G.shape(), bare = _G.shape(nil, false) }) }, _G.quit_file)]],
      note = "a real project: three windows, row and column, sizes of their own",
    },
    {
      expect = [[_G.shape()[1] == "row" and (_G.shape()[2][1] == "col" or _G.shape()[3][1] == "col")]],
      note = "really a nested layout",
    },
    {
      restart = true,
      args = {
        "+lua dofile('TESTS/sheets/_helpers.lua'); _G.persistent(); _G.setup({ chip = { enable = false } })",
        "+LastSession",
      },
      note = "quit, then nvim +LastSession (from the repository, not the project)",
    },
    {
      lua = SHAPE .. [[
      _G.quit = vim.json.decode(vim.fn.readfile(_G.quit_file)[1])]],
    },
    { expect = [[_G.stored("last.vim")]], note = "the exit wrote last.vim" },
    {
      expect = [[vim.fn.fnamemodify(vim.fn.getcwd(), ":t") == "myrepo"]],
      note = "back in the project",
    },
    {
      expect = [[vim.deep_equal(_G.shape(nil, false), _G.quit.bare)]],
      note = "the same structure with the same files",
    },
    {
      expect = [[vim.deep_equal(_G.shape(), _G.quit.full)]],
      note = "and the same sizes",
    },
  },
}
