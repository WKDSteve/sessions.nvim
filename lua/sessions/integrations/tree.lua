---@module 'sessions.integrations.tree'
---@brief A sign in a tree view on every pinned file.
---@description
--- Registers one decorator, `pin`, at `lib.nvim.tree.registry`. A tree that reads the registry (the
--- own tree of filetree.nvim) draws its sign in the first cell of the line of every file that is a
--- default or a pin of the marks (`sessions.marks`: `marks.defaults` of the config, and the files
--- pinned with `:Session marks pin`).
---
--- The decorator's `get` is a table lookup. The table is built from `marks.defaults()` (which reads
--- the pins file) when a tree starts to listen and again whenever a pin is written
--- (`marks.on_pins_changed`); the tree is told exactly the paths that gained or lost the sign.
--- Without `marks.enable` there are no pins and the table stays empty.
---
--- Soft in both directions. The registry is lib.nvim's: without a tree that reads it the entry is never
--- looked at, and without a lib.nvim that has the registry nothing is registered.

local M = {}

M.NAME = "pin"

---@class Sessions.Tree.Opts
---@field sign? string  The sign, one cell wide (default "*").

---@type fun()|nil
local unregister = nil
---@type table<string, table>  path -> badge
local signs = {}
---@type table<integer, fun(keys?: string[])>
local listeners = {}
local next_listener = 0
---@type fun()|nil
local unhook = nil
local sign_text = "*"

---One spelling for a path, the one a tree view uses for its keys: `/`-separated, the drive letter in
---upper case, no trailing slash.
---@param path string
---@return string
function M.norm(path)
  path = path:gsub("\\", "/")
  path = path:gsub("^(%a):", function(drive)
    return drive:upper() .. ":"
  end)
  if #path > 1 and path:sub(-1) == "/" and not path:match("^%a:/$") then
    path = path:sub(1, -2)
  end
  return path
end

---Read the pins again and tell the listening trees which paths changed.
function M.refresh()
  local fresh = {}
  local cfg = require("sessions.config").cfg
  if type(cfg) == "table" and type(cfg.marks) == "table" and cfg.marks.enable then
    local ok, paths = pcall(require("sessions.marks").defaults)
    if ok and type(paths) == "table" then
      for _, path in ipairs(paths) do
        if type(path) == "string" and path ~= "" then
          fresh[M.norm(path)] = { text = sign_text, hl = "Special", status = "pinned" }
        end
      end
    end
  end
  local changed = {}
  for path in pairs(signs) do
    if not fresh[path] then
      changed[#changed + 1] = path
    end
  end
  for path in pairs(fresh) do
    if not signs[path] then
      changed[#changed + 1] = path
    end
  end
  signs = fresh
  if #changed > 0 then
    table.sort(changed)
    for _, emit in pairs(listeners) do
      pcall(emit, changed)
    end
  end
end

---Register the decorator. Without `lib.nvim.tree.registry` (an older lib.nvim) nothing happens.
---@param opts? Sessions.Tree.Opts
---@return boolean registered
function M.register(opts)
  local ok, registry = pcall(require, "lib.nvim.tree.registry")
  if not ok or type(registry.decorator) ~= "function" then
    return false
  end
  M.unregister()
  sign_text = type(opts) == "table"
      and type(opts.sign) == "string"
      and opts.sign ~= ""
      and opts.sign
    or "*"
  unregister = registry.decorator({
    name = M.NAME,
    key = "path",
    slot = "sign",
    priority = 40,
    roll_up = false,
    get = function(path)
      return signs[path]
    end,
    all = function()
      return signs
    end,
    subscribe = function(emit)
      next_listener = next_listener + 1
      local id = next_listener
      local first = next(listeners) == nil
      listeners[id] = emit
      if first then
        unhook = require("sessions.marks").on_pins_changed(M.refresh)
        -- not in this call: a tree subscribes while it opens, and the pins are a file
        vim.schedule(function()
          if next(listeners) ~= nil then
            M.refresh()
          end
        end)
      end
      return function()
        listeners[id] = nil
        if next(listeners) == nil and unhook then
          unhook()
          unhook = nil
        end
      end
    end,
  })
  return true
end

---Take the decorator out again.
function M.unregister()
  if unregister then
    unregister()
    unregister = nil
  end
  if unhook then
    unhook()
    unhook = nil
  end
  listeners = {}
  signs = {}
end

return M
