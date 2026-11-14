-- TESTS/tree_drive.lua -- sessions.nvim with the real own tree of filetree.nvim: the pin sign on a
-- pinned file, following pin and unpin, and a session that brings the tree back in the view it showed
-- and with the folders open that it had.
--
-- Not a spec of the suite (no `_spec` in the name): filetree.nvim is no dependency of sessions.nvim,
-- and the state of a sibling checkout must not decide about this suite. `treeview_spec.lua` checks the
-- same on a fake of filetree's adapter; this is the hand run against the real one, on filetree.nvim's
-- bench `TESTS/native_drive.lua`, which sets up the editor and quits it:
--
--   FILETREE_NVIM_DIR=<checkout> nvim --clean --headless -u NONE -l TESTS/tree_drive.lua

---@diagnostic disable: need-check-nil, duplicate-set-field

local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h"):gsub("\\", "/")
local plugin = vim.fs.dirname(here)
vim.opt.rtp:prepend(plugin)

local filetree = (vim.env.FILETREE_NVIM_DIR or ""):gsub("\\", "/")
if filetree == "" or not vim.uv.fs_stat(filetree .. "/TESTS/native_drive.lua") then
  io.stdout:write("  n/a  $FILETREE_NVIM_DIR names no filetree.nvim: nothing was run\n")
  vim.cmd("cq")
  return
end
-- the bench looks for lib.nvim and ui.nvim next to filetree.nvim, or where these name them
for _, dep in ipairs({ "lib.nvim", "ui.nvim" }) do
  local var = dep:upper():gsub("%.", "_") .. "_DIR"
  local sibling = vim.fs.dirname(plugin) .. "/" .. dep
  if (vim.env[var] or "") == "" and vim.uv.fs_stat(sibling .. "/lua") then
    vim.env[var] = sibling
  end
end
-- nothing of the person's own setup: sessions, marks and state go to a temp folder
local scratch = vim.fn.tempname():gsub("\\", "/")
vim.fn.mkdir(scratch, "p")
for _, var in ipairs({ "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME" }) do
  vim.env[var] = scratch
end

local sessions
local T = dofile(filetree .. "/TESTS/native_drive.lua")({
  name = "tree_drive (sessions.nvim)",
  files = { "README.md", "docs/guide.md", "lua/init.lua", "lua/mod/a.lua", "lua/mod/b.lua" },
  before_setup = function(T)
    sessions = require("sessions")
    sessions.setup({
      root = scratch .. "/sessions",
      branch_aware = false,
      project_aware = false,
      autosave = false,
      autoload = false,
      save_last = false,
      metadata = false,
      marks = {
        enable = true,
        scope = "global",
        defaults = { T.dir .. "/docs/guide.md" },
        import_harpoon = false,
      },
    })
  end,
})

local dir = T.dir
local marks = require("sessions.marks")
local switcher = T.filetree.feature("source_switcher")

---Whether the line of `rel` carries the pin sign.
local function signed(rel)
  local drawn = T.drawn(rel)
  return drawn ~= nil and drawn.text:find("*", 1, true) ~= nil
end

-- ── the pin sign ─────────────────────────────────────────────────────────────
T.on("docs/guide.md")
T.ok(
  "a default of the marks carries the sign",
  T.wait(function()
    return signed("docs/guide.md")
  end)
)
T.on("lua/mod/a.lua")
T.ok("a file that is not pinned has none", not signed("lua/mod/a.lua"))

T.ok("fixture: pin a file", (marks.pin(dir .. "/lua/mod/a.lua", { quiet = true })))
T.ok(
  "a pin gives the sign without a refresh",
  T.wait(function()
    return signed("lua/mod/a.lua")
  end)
)
T.ok("fixture: unpin it", (marks.unpin(dir .. "/lua/mod/a.lua")))
T.ok(
  "an unpin takes it",
  T.wait(function()
    return not signed("lua/mod/a.lua")
  end)
)
T.ok("... and the default keeps its sign", signed("docs/guide.md"))

-- ── a session brings the tree back ───────────────────────────────────────────
T.ok("the source switcher is there", type(switcher) == "table")
local open_before = vim.tbl_map(T.norm, T.adapter.get_expanded_paths())
T.eq(
  "fixture: the folders that are open",
  open_before,
  { dir .. "/lua", dir .. "/docs", dir .. "/lua/mod" }
)
T.ok("fixture: the tree shows the buffers", (switcher.switch("buffers")))
T.eq("fixture: the view on screen", switcher.current(), "buffers")

vim.api.nvim_set_current_win(T.editor_win)
local mark = T.mark()
local saved, saved_path = sessions.save("drive")
T.ok("the session is saved: " .. tostring(saved_path), saved)
local state =
  vim.json.decode(table.concat(vim.fn.readfile(scratch .. "/sessions/.drive.tree.json"), "\n"))
T.eq("the sidecar names the view", state.view, "buffers")
T.eq("... the root", T.norm(state.root), dir)
T.eq("... and the open folders", vim.tbl_map(T.norm, state.expanded), open_before)
T.eq("the save closed the tree (its buffer is nofile)", T.adapter.is_open(), false)

-- another state than the saved one: the files, every folder closed, the tree closed again
T.ok("fixture: the files", (switcher.switch("files")))
T.adapter.collapse_all()
T.adapter.close()
T.eq("fixture: no folder is open", T.adapter.get_expanded_paths(), {})
T.eq("fixture: no tree", T.adapter.is_open(), false)

local loaded = sessions.load("drive")
T.ok("the session is loaded", loaded)
T.ok(
  "the tree is open again",
  T.wait(function()
    return T.adapter.is_open()
  end)
)
T.eq("... in the view it showed", switcher.current(), "buffers")
T.eq("... at its root", T.norm(T.adapter.get_root_path()), dir)
T.ok(
  "... and the focus stayed in the editor",
  vim.api.nvim_get_current_win() ~= T.adapter.get_winid()
)
T.ok("fixture: back to the files", (switcher.switch("files")))
T.ok(
  "the folders that were open are open",
  T.wait(function()
    return vim.deep_equal(vim.tbl_map(T.norm, T.adapter.get_expanded_paths()), open_before)
  end)
)
T.ok("... and their files are on screen", T.shown("lua/mod/a.lua"))
T.eq("neither the save nor the load said anything at warning level", T.loud(mark), {})

T.eq("no dialog nobody expected", T.unanswered, 0)
require("sessions.integrations.tree").unregister()
vim.fn.delete(scratch, "rf")
T.finish()
