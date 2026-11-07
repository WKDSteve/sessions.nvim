---@module 'sessions.portable'
--- Cross-device/cross-OS session portability. Neovim's own `:mksession`
--- already writes buffer paths relative to `cwd` when possible (with
--- "curdir" in 'sessionoptions'), but the embedded `cd`/`lcd` line and any
--- paths outside `cwd` stay host-absolute. This module post-processes the
--- plain-text .vim file to close that gap, rather than touching
--- Neovim's own session-writing internals.
---
--- The work itself -- boundary-aware placeholder substitution, the temporary
--- copy that never touches the stored file, `root_remap` -- is
--- `lib.nvim.fs.portable`; this module only fixes the placeholder and the
--- session-specific contract (an unreadable or empty file is an error on save).

local portable = require("lib.nvim.fs.portable")

---@class SessionsPortable
local M = {}

local PLACEHOLDER = "{{SESSION_ROOT}}"

---@param cwd string
---@return Lib.Fs.Portable.Root[]
local function roots(cwd)
  return { { path = cwd, placeholder = PLACEHOLDER } }
end

---`root_remap` with each key also in the other spelling of the home directory:
---:mksession writes a path below it as `~/...`, the user writes the key as they
---know the path (and may write `~/...` for a file edited by hand).
---@param remap table<string, string>|nil
---@return table<string, string>|nil
local function with_home_spellings(remap)
  if not remap or not next(remap) then
    return remap
  end
  local home = vim.fs.normalize(vim.fn.expand("~")):gsub("/+$", "")
  local fold = vim.fn.has("win32") == 1 and string.lower or function(s)
    return s
  end
  local out = {}
  for old_root, new_root in pairs(remap) do
    out[old_root] = new_root
    if type(old_root) == "string" then
      local key = old_root:gsub("\\", "/"):gsub("/+$", "")
      local head = fold(key:sub(1, #home))
      if head == fold(home) and (#key == #home or key:sub(#home + 1, #home + 1) == "/") then
        out["~" .. key:sub(#home + 1)] = new_root
      elseif key:sub(1, 2) == "~/" then
        out[home .. key:sub(2)] = new_root
      end
    end
  end
  return out
end

---Replace every occurrence of `cwd` (in the spellings :mksession may use)
---in the saved session file with a portable placeholder, so the file no
---longer pins itself to the machine it was saved on.
---@param session_path string
---@param cwd string
---@return boolean ok
---@return string|nil err
---@see sessions.core
function M.make_relative(session_path, cwd)
  if cwd == "" then
    return false, "empty cwd: " .. session_path
  end
  local content, read_err = require("lib.nvim.fs.read")(session_path)
  if content == nil or content == "" then
    return false, read_err or ("empty session file: " .. session_path)
  end
  return portable.make_file(session_path, roots(cwd))
end

---Build a load-ready copy of `session_path` with the placeholder re-anchored
---to `cwd` and any `root_remap` prefixes translated, without mutating the
---stored file (so it stays correct for other machines/OSes that may share
---it, e.g. via `:Session toggle-track`). Returns the original path
---unchanged if no rewriting was needed.
---@param session_path string
---@param cwd string
---@param root_remap table<string, string>|nil
---@return string path_to_source
---@return boolean is_temp_copy
---@return string|nil err  Set when a read/write failure fell back to `session_path`
function M.prepare_for_load(session_path, cwd, root_remap)
  if cwd == "" then
    return session_path, false, "empty cwd"
  end
  return portable.resolve_file(session_path, roots(cwd), {
    remap = with_home_spellings(root_remap),
    suffix = ".vim",
  })
end

return M
