---@module 'sessions.treeview'
---@brief Save and restore what the file tree showed: its root, the view on screen and the open folders.
---@description
--- `:mksession` cannot carry a tree window (its buffer is `nofile`, and `sessions.core` closes it before
--- the session is written), so a restored session came back without the tree, or with a tree at the
--- working directory and every folder closed. This module writes what the tree showed to a hidden
--- `.{name}.tree.json` next to the session file (the convention of `sessions.buforder` and
--- `sessions.pins`) and puts it back after the session was sourced.
---
--- Which tree: the own tree of filetree.nvim (`adapter = "native"`), the one with views (files,
--- buffers, git, the views other plugins register). Read and written through filetree.nvim's public
--- adapter (`require("filetree").adapter()`: `is_open`, `get_root_path`, `get_expanded_paths`,
--- `set_root`, `expand_paths`, `open_cwd`) and, for the view, `adapter.get_view` / `adapter.show_view`
--- when the adapter has them, else the feature `source_switcher` (`current` / `switch`), else the
--- buffer variable `filetree_view` (read only).
---
--- One place per session: filetree.nvim's own `session` feature keeps root and open folders per
--- PROJECT and knows nothing of the view. With named sessions leave that feature off (its default), or
--- the two restore over each other.
---
--- Soft in both directions. `capture` never loads filetree.nvim (a tree that was never opened has
--- nothing to save); `restore` loads it only when the session has a tree sidecar, that is when a tree
--- was open at the time of the save. A sidecar is untrusted data: every field is checked before it
--- reaches the tree.

require("sessions.@types")

local fn = vim.fn

local M = {}

---At most this many open folders are saved and restored.
M.MAX_EXPANDED = 5000

---@class Sessions.TreeState
---@field v integer            Format version (1).
---@field adapter string       "native".
---@field root? string         The root folder of the tree.
---@field view? string         The view on screen ("files", "buffers", "git", ...).
---@field expanded string[]    The open folders of the files view.

---@internal
---@param session_path string
---@return string
local function sidecar_path(session_path)
  local dir = fn.fnamemodify(session_path, ":h")
  local base = fn.fnamemodify(session_path, ":t:r")
  return dir .. "/." .. base .. ".tree.json"
end
M.sidecar_path = sidecar_path

---@internal
---The adapter of a filetree.nvim that is set up on its own tree, or nil.
---@param filetree table|nil  the module `filetree`
---@return table|nil adapter
local function native_adapter(filetree)
  if type(filetree) ~= "table" or type(filetree.adapter) ~= "function" then
    return nil
  end
  local ok, adapter = pcall(filetree.adapter)
  if not ok or type(adapter) ~= "table" or adapter.name ~= "native" then
    return nil
  end
  return adapter
end

---@internal
---@param filetree table
---@return table|nil switcher  the feature `source_switcher`, when it is active
local function switcher_of(filetree)
  if type(filetree.feature) ~= "function" then
    return nil
  end
  local ok, feature = pcall(filetree.feature, "source_switcher")
  return ok and type(feature) == "table" and feature or nil
end

---@internal
---The view the tree shows.
---@param filetree table
---@param adapter table
---@return string|nil
local function current_view(filetree, adapter)
  local view
  if type(adapter.get_view) == "function" then
    local ok, name = pcall(adapter.get_view)
    view = ok and name or nil
  end
  if type(view) ~= "string" then
    local switcher = switcher_of(filetree)
    if switcher and type(switcher.current) == "function" then
      local ok, name = pcall(switcher.current)
      view = ok and name or nil
    end
  end
  if type(view) ~= "string" and type(adapter.get_bufnr) == "function" then
    local ok, buf = pcall(adapter.get_bufnr)
    if ok and type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      view = vim.b[buf].filetree_view
    end
  end
  return type(view) == "string" and view ~= "" and view or nil
end

---What the tree shows right now, or nil when there is nothing to save: filetree.nvim was never
---loaded, it drives another tree plugin, or its tree is closed. Call it BEFORE the session's
---blacklisted buffers are wiped: the tree buffer is one of them.
---@return Sessions.TreeState|nil
function M.capture()
  -- `package.loaded`, not `require`: saving a session must not load a plugin
  local filetree = package.loaded["filetree"]
  local adapter = native_adapter(filetree)
  if not adapter or type(adapter.is_open) ~= "function" then
    return nil
  end
  local ok, open = pcall(adapter.is_open)
  if not ok or not open then
    return nil
  end
  ---@type Sessions.TreeState
  local state = { v = 1, adapter = "native", expanded = {} }
  if type(adapter.get_root_path) == "function" then
    local root_ok, root = pcall(adapter.get_root_path)
    if root_ok and type(root) == "string" and root ~= "" then
      state.root = vim.fs.normalize(root)
    end
  end
  state.view = current_view(filetree, adapter)
  if type(adapter.get_expanded_paths) == "function" then
    local exp_ok, expanded = pcall(adapter.get_expanded_paths)
    if exp_ok and type(expanded) == "table" then
      for _, path in ipairs(expanded) do
        if type(path) == "string" and #state.expanded < M.MAX_EXPANDED then
          state.expanded[#state.expanded + 1] = vim.fs.normalize(path)
        end
      end
    end
  end
  return state
end

---Write `state` to the sidecar of `session_path`; without a state the sidecar of an earlier save is
---removed (the tree was closed this time, and must not come back from an older save).
---@param session_path string
---@param state Sessions.TreeState|nil
---@return boolean wrote
---@return string|nil err  `"<sidecar path>: <reason>"` when the write failed
function M.save(session_path, state)
  local path = sidecar_path(session_path)
  if type(state) ~= "table" then
    os.remove(path)
    return false
  end
  return require("sessions.util.sidecar").write(path, state)
end

---@internal
---A sidecar as read from disk, with everything dropped that is not what `capture` writes.
---@param data any
---@return Sessions.TreeState|nil
local function checked(data)
  if type(data) ~= "table" or data.adapter ~= "native" then
    return nil
  end
  ---@type Sessions.TreeState
  local state = { v = 1, adapter = "native", expanded = {} }
  if type(data.root) == "string" and data.root ~= "" and not data.root:find("%z") then
    state.root = data.root
  end
  -- a view name is a word: it is handed to the tree as a name, never run
  if type(data.view) == "string" and data.view:match("^[%w_.:-]+$") and #data.view <= 64 then
    state.view = data.view
  end
  if type(data.expanded) == "table" then
    for _, path in ipairs(data.expanded) do
      if #state.expanded >= M.MAX_EXPANDED then
        break
      end
      if type(path) == "string" and path ~= "" and not path:find("%z") then
        state.expanded[#state.expanded + 1] = path
      end
    end
  end
  return state
end

---Show the tree again as the session saved it: open it at the saved root, open the saved folders,
---switch to the saved view. A no-op without a sidecar, without filetree.nvim, or when filetree.nvim
---is not set up on its own tree. The window that had the focus keeps it.
---@param session_path string
---@return boolean applied
function M.restore(session_path)
  local state = checked(require("lib.nvim.fs.json").read(sidecar_path(session_path)))
  if not state then
    return false
  end
  -- the session had a tree open: now filetree.nvim may be loaded
  local ok, filetree = pcall(require, "filetree")
  local adapter = ok and native_adapter(filetree) or nil
  if not adapter then
    return false
  end
  local win = vim.api.nvim_get_current_win()
  local opened = false
  if state.root and fn.isdirectory(state.root) == 1 and type(adapter.set_root) == "function" then
    pcall(adapter.set_root, state.root)
  end
  if type(adapter.open_cwd) == "function" then
    local open_ok, result = pcall(adapter.open_cwd)
    opened = open_ok and result ~= false
  end
  if not opened then
    return false
  end
  if #state.expanded > 0 and type(adapter.expand_paths) == "function" then
    pcall(adapter.expand_paths, state.expanded)
  end
  if state.view and state.view ~= "files" then
    if type(adapter.show_view) == "function" then
      pcall(adapter.show_view, state.view)
    else
      local switcher = switcher_of(filetree)
      if switcher and type(switcher.switch) == "function" then
        -- a view that no longer exists (its plugin is gone) is refused by name; the files stay
        pcall(switcher.switch, state.view, { keep_focus = true })
      end
    end
  end
  if vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_set_current_win, win)
  end
  return true
end

---Remove the sidecar for `session_path` (session deleted).
---@param session_path string
function M.delete(session_path)
  os.remove(sidecar_path(session_path))
end

---Move the sidecar alongside a renamed session file.
---@param old_path string
---@param new_path string
function M.rename(old_path, new_path)
  local old = sidecar_path(old_path)
  local content = require("lib.nvim.fs.read")(old)
  if not content then
    return
  end
  if require("lib.nvim.fs.write.to_file")(sidecar_path(new_path), content) then
    os.remove(old)
  end
end

return M
