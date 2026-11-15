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
-- the save wipes the tree buffer (it is nofile) and shows the tree again, as it was
T.ok(
  "after a save in the middle of work the tree is open again",
  T.wait(function()
    return T.adapter.is_open()
  end)
)
T.eq("... in the view it showed", switcher.current(), "buffers")
T.ok(
  "... and the focus stayed in the editor",
  vim.api.nvim_get_current_win() ~= T.adapter.get_winid()
)

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

-- ── what is open in a view of other sources ──────────────────────────────────
if type(T.adapter.get_open_nodes) ~= "function" or type(T.adapter.set_open_nodes) ~= "function" then
  T.na("this filetree.nvim has no get_open_nodes / set_open_nodes: the open nodes were not run")
else
  ---Focus a window that is not the tree (the load above replaced the windows of the editor).
  local function to_editor()
    local tree_win = T.adapter.get_winid()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if
        win ~= tree_win
        and vim.api.nvim_win_get_config(win).relative == ""
        and not vim.wo[win].winfixbuf
      then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
    error("no editor window")
  end

  -- two files in the editor, so the buffers have something below their head
  to_editor()
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/lua/mod/a.lua"))
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/docs/guide.md"))
  T.ok("fixture: the tree shows the buffers", (T.adapter.show_view("buffers")))
  local open_nodes = {}
  T.ok(
    "fixture: the buffers have a node open",
    T.wait(function()
      open_nodes = T.adapter.get_open_nodes("buffers") or {}
      return #open_nodes > 0
    end)
  )
  mark = T.mark()

  -- saved with the nodes open, closed afterwards: a load opens them
  to_editor()
  T.ok("the session is saved with the nodes open", (sessions.save("nodes")))
  state =
    vim.json.decode(table.concat(vim.fn.readfile(scratch .. "/sessions/.nodes.tree.json"), "\n"))
  T.eq("the sidecar names the open nodes of the view", state.open_nodes.buffers, open_nodes)
  T.eq("... and of no view that was never shown", vim.tbl_keys(state.open_nodes), { "buffers" })
  T.ok(
    "after the save the tree is open again",
    T.wait(function()
      return T.adapter.is_open()
    end)
  )
  T.eq("... with the same nodes open", T.adapter.get_open_nodes("buffers"), open_nodes)

  T.ok("fixture: every node closed", (T.adapter.set_open_nodes("buffers", {})))
  T.eq("fixture: nothing is open", T.adapter.get_open_nodes("buffers"), {})
  -- saved once more as it is now: everything closed in the view on screen is a state too
  T.ok("the session is saved with every node closed", (sessions.save("closed")))
  T.adapter.close()

  T.ok("the session with the open nodes is loaded", (sessions.load("nodes")))
  T.ok(
    "the nodes that were open are open",
    T.wait(function()
      return T.adapter.is_open() and vim.deep_equal(T.adapter.get_open_nodes("buffers"), open_nodes)
    end)
  )
  T.eq("... in the view it showed", T.adapter.get_view(), "buffers")

  T.adapter.close()
  T.ok("the session with every node closed is loaded", (sessions.load("closed")))
  T.ok(
    "every node is closed again",
    T.wait(function()
      return T.adapter.is_open() and vim.deep_equal(T.adapter.get_open_nodes("buffers"), {})
    end)
  )
  T.eq(
    "... and stays closed after the view was drawn",
    (function()
      T.settle(200)
      return T.adapter.get_open_nodes("buffers")
    end)(),
    {}
  )
  T.eq("neither the saves nor the loads said anything at warning level", T.loud(mark), {})

  -- A tree that tells "nothing known" from "everything closed": an empty list of a view that is
  -- not on screen is kept, and so is what a session set for a view nobody registered yet.
  if type(T.adapter.knows_open_nodes) ~= "function" then
    T.na("this filetree.nvim has no knows_open_nodes: the empty list of a hidden view was not run")
  else
    mark = T.mark()
    T.ok("fixture: the files are on screen, the buffers hidden", (T.adapter.show_view("files")))
    T.eq("fixture: the hidden view has everything closed", T.adapter.get_open_nodes("buffers"), {})
    to_editor()
    T.ok("the session is saved with the files on screen", (sessions.save("hidden")))
    local hidden_json = scratch .. "/sessions/.hidden.tree.json"
    state = vim.json.decode(table.concat(vim.fn.readfile(hidden_json), "\n"))
    T.eq("the sidecar keeps the empty list of the hidden view", state.open_nodes.buffers, {})
    T.eq(
      "... and nothing for a view nothing is known of",
      vim.tbl_keys(state.open_nodes),
      { "buffers" }
    )

    -- the session as another editor wrote it, one that had a plugin with a view `later`
    state.open_nodes.later = { "x" }
    vim.fn.writefile({ vim.json.encode(state) }, hidden_json)
    T.ok("fixture: the nodes open again", (T.adapter.set_open_nodes("buffers", open_nodes)))
    T.adapter.close()
    T.ok("the session is loaded", (sessions.load("hidden")))
    T.ok(
      "the tree is open again, on the files",
      T.wait(function()
        return T.adapter.is_open() and T.adapter.get_view() == "files"
      end)
    )
    T.eq("the hidden view has everything closed again", T.adapter.get_open_nodes("buffers"), {})
    T.eq(
      "the tree keeps the ids of the view that is not there",
      T.adapter.get_open_nodes("later"),
      { "x" }
    )

    -- saved again before that plugin came: its open nodes stay in the session
    to_editor()
    T.ok("the session is saved again", (sessions.save("hidden")))
    state = vim.json.decode(table.concat(vim.fn.readfile(hidden_json), "\n"))
    T.eq("the sidecar still names the view that is not there", state.open_nodes.later, { "x" })
    T.eq("... and the hidden one", state.open_nodes.buffers, {})

    T.ok("fixture: the buffers are shown", (T.adapter.show_view("buffers")))
    T.eq(
      "... and stay closed once they are drawn",
      (function()
        T.settle(200)
        return T.adapter.get_open_nodes("buffers")
      end)(),
      {}
    )
    T.eq("neither the saves nor the load said anything at warning level", T.loud(mark), {})
  end
end

T.eq("no dialog nobody expected", T.unanswered, 0)
require("sessions.integrations.tree").unregister()
vim.fn.delete(scratch, "rf")
T.finish()
