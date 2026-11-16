-- TESTS/sheets/_helpers.lua -- what the sessions.nvim test sheets need in their child editor. Not a sheet
-- (`testing.sheet` only reads *.sheet.lua); a sheet's first step runs it with `dofile`, the child's cwd is the
-- project root. The directory is in the spec's @cache-inputs, so a change here re-runs the sheets.
--
-- Nothing here touches a real session directory: the store and every project live below `vim.fn.tempname()`, inside
-- the sandbox of the child editor (its `stdpath` directories are sandboxed too).

local M = {}

_G.ROOT = vim.fs.normalize(vim.fn.getcwd())

-- Fixes the editor's temp directory before $TEMP goes away below.
local tmp = vim.fn.tempname()

-- config/init.lua blacklists everything below $TEMP, and the projects of the sheets live there. Without the variable
-- the temp directories stay in use and the plugin sees no temp directory to protect.
vim.env.TEMP = nil

vim.opt.shortmess:append("I")
vim.o.swapfile = false
vim.o.hidden = true
-- A long notify also echoes: without the room a hit-enter prompt blocks every later step of the sheet.
vim.o.cmdheight = 4

---A directory that really exists, spelled the way the editor reports it.
---@param path string
---@return string
local function fresh_dir(path)
  vim.fn.mkdir(path, "p")
  return vim.fs.normalize(vim.uv.fs_realpath(path))
end

_G.STORE = fresh_dir(tmp .. "/store") -- the session root of every sheet

---For a sheet with a `restart` step: the store and the projects below `stdpath("data")` instead of the temp directory.
---The editor removes its temp directory when it quits, the sandbox's `stdpath` directories stay for the next editor.
---Call it in every editor of the sheet, before `_G.setup` and `_G.repo`.
function _G.persistent()
  local base = vim.fn.stdpath("data") .. "/sheet"
  _G.STORE = fresh_dir(base .. "/store")
  function _G.project(name)
    return fresh_dir(base .. "/projects/" .. name)
  end
end

---ui.nvim on the runtimepath, for the sheets of the chip, the dialogs and the kit menu. Call before `_G.setup`; the
---sheet `requires` it (`add_deps("ui.nvim")`), so a machine without ui.nvim reports a skip, not a Lua error.
function _G.with_ui()
  assert(
    M.add_deps("ui.nvim"),
    "ui.nvim was not found (TESTS/minimal_init.lua, vim.g.sessions_sheets_ui_nvim)"
  )
end

---A new project directory below the temp directory.
---@param name string
---@return string
function _G.project(name)
  return fresh_dir(vim.fn.tempname() .. "/" .. name)
end

---Write a file (default `{ "text" }`) below the current directory, or at an absolute path.
---@param path string
---@param lines string[]|nil
---@return string path
function _G.write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines or { "text" }, path)
  return path
end

---Run git in `cwd` (default the current directory); a failure raises.
---@param args string[]
---@param cwd string|nil
---@return string stdout
function _G.git(args, cwd)
  -- A throwaway repository: no identity or signing of the machine has a say in it.
  local argv = {
    "git",
    "-c",
    "user.name=sheet",
    "-c",
    "user.email=sheet@example.invalid",
    "-c",
    "commit.gpgsign=false",
  }
  vim.list_extend(argv, args)
  local r = vim.system(argv, { cwd = cwd or vim.fn.getcwd(), text = true }):wait()
  if r.code ~= 0 then
    error(("git %s: %s"):format(table.concat(args, " "), r.stderr), 0)
  end
  return r.stdout
end

---A git repository with one commit on `main`, as a new project; the editor's current directory is moved there.
---@param name string
---@return string dir
function _G.repo(name)
  local dir = _G.project(name)
  _G.git({ "init", "-q", "-b", "main" }, dir)
  _G.write(dir .. "/a.txt", { "a" })
  _G.write(dir .. "/b.txt", { "b" })
  _G.git({ "add", "." }, dir)
  _G.git({ "commit", "-q", "-m", "first" }, dir)
  vim.cmd.cd(vim.fn.fnameescape(dir))
  return dir
end

---The options every sheet shares, under `opts`.
---@param opts table|nil
---@return table
function _G.options(opts)
  return vim.tbl_deep_extend("force", {
    root = _G.STORE,
    blacklist = { paths = {} },
    marks = { import_harpoon = false },
  }, opts or {})
end

---`require("sessions").setup` is a one-shot: forget the plugin and set it up again with `opts`.
---@param opts table|nil
function _G.setup(opts)
  for name in pairs(package.loaded) do
    if name == "sessions" or name:match("^sessions%.") then
      package.loaded[name] = nil
    end
  end
  for _, cmd in ipairs({ "Session", "LastSession", "SessionLoad" }) do
    pcall(vim.api.nvim_del_user_command, cmd)
  end
  require("sessions").setup(_G.options(opts))
end

---The current session of the plugin.
---@return string|nil
function _G.current()
  return require("sessions.core").current()
end

---A file of the store exists.
---@param rel string
---@return boolean
function _G.stored(rel)
  return vim.uv.fs_stat(_G.STORE .. "/" .. rel) ~= nil
end

---Whether a toast of sessions.nvim so far holds `text` (plain), read from the history behind `:Lib notify history`.
---@param text string
---@return boolean
function _G.noted(text)
  for _, entry in ipairs(require("lib.nvim.notify.popup").history("sessions")) do
    if tostring(entry.message):find(text, 1, true) then
      return true
    end
  end
  return false
end

---The texts of the toasts so far, for a failure message.
---@return string
function _G.toasts()
  local out = {}
  for _, entry in ipairs(require("lib.nvim.notify.popup").history("sessions")) do
    out[#out + 1] = tostring(entry.message)
  end
  return table.concat(out, "\n")
end

---Forget the toasts so far.
function _G.forget()
  require("lib.nvim.notify.popup").clear("sessions")
end

---`text` holds `part` (plain), or an error that shows the text.
---@param text string
---@param part string
---@return boolean
function _G.has(text, part)
  if not tostring(text):find(part, 1, true) then
    error(("no %s in %s"):format(vim.inspect(part), vim.inspect(text)), 0)
  end
  return true
end

---The lines of a buffer (default the current one) as one string, joined by a newline.
---@param buf integer|nil
---@return string
function _G.text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false), "\n")
end

---A file's lines as one string.
---@param path string
---@return string
function _G.read(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

---The normal (not floating) windows of this tab.
---@return integer[]
function _G.wins()
  return vim.tbl_filter(function(w)
    return vim.api.nvim_win_get_config(w).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
end

---The base names of the buffers of the normal windows of this tab, sorted.
---@return string[]
function _G.shown()
  local out = {}
  for _, w in ipairs(_G.wins()) do
    out[#out + 1] = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)), ":t")
  end
  table.sort(out)
  return out
end

---A second Neovim: a real process with a real exit, on the same store. `src` is Lua, run through `-c` before VimEnter
---with this file's helpers loaded; it ends with `_G.finish()` (dump the state at VimEnter, then `:qa!`). The answer is
---the state `_G.finish` dumped: `shown` (see above), `current`, `tabs`, `extra` (`_G.extra` of the script).
---@param src string
---@param opts { cwd: string|nil, args: string[]|nil }|nil
---@return table state
function _G.proc(src, opts)
  opts = opts or {}
  local script = vim.fn.tempname() .. ".lua"
  local out = vim.fn.tempname() .. ".json"
  vim.fn.writefile(
    vim.list_extend({
      ("vim.g.sheet_store = %q"):format(_G.STORE),
      ("vim.g.sheet_out = %q"):format(out),
      ("local root = %q"):format(_G.ROOT),
      -- the helpers read the project root from the current directory
      "local cwd = vim.fn.getcwd()",
      "vim.cmd.cd(vim.fn.fnameescape(root))",
      'dofile(root .. "/TESTS/sheets/_helpers.lua")',
      "_G.STORE = vim.g.sheet_store",
      "vim.cmd.cd(vim.fn.fnameescape(cwd))",
    }, vim.split(src, "\n")),
    script
  )
  local argv =
    { vim.v.progpath, "-n", "-i", "NONE", "--headless", "-u", _G.ROOT .. "/TESTS/minimal_init.lua" }
  vim.list_extend(argv, opts.args or {})
  vim.list_extend(argv, { "-c", "luafile " .. vim.fn.fnameescape(script) })
  local r =
    vim.system(argv, { cwd = opts.cwd or vim.fn.getcwd(), text = true, timeout = 15000 }):wait()
  if r.code ~= 0 then
    error(("second nvim exited with %s: %s%s"):format(r.code, r.stdout, r.stderr), 0)
  end
  if vim.uv.fs_stat(out) == nil then
    error("second nvim dumped nothing: " .. r.stderr, 0)
  end
  return vim.json.decode(_G.read(out))
end

---For the script of `_G.proc`: at VimEnter, after the plugin's own handlers, write the state and quit for real (the
---plugin's VimLeavePre handlers run).
function _G.finish()
  vim.api.nvim_create_autocmd("VimEnter", {
    nested = true,
    callback = function()
      vim.fn.writefile({
        vim.json.encode({
          shown = _G.shown(),
          current = require("sessions.core").current() or vim.NIL,
          tabs = #vim.api.nvim_list_tabpages(),
          extra = _G.extra or vim.NIL,
        }),
      }, vim.g.sheet_out)
      vim.cmd("qa!")
    end,
  })
end

---Put the named sibling plugins on the runtimepath; false when one was not found. For `requires`, and again in the
---`args` of a `restart` (a new editor has a new runtimepath). Where they are is TESTS/minimal_init.lua's finding
---($<NAME>_DIR, .deps/<name> of the CI's checkouts, ../<name>, the lazy.nvim directory), left in
---`vim.g.sessions_sheets_<name>`.
---@param ... string  "ui.nvim", "filetree.nvim"
---@return boolean
function M.add_deps(...)
  for _, name in ipairs({ ... }) do
    local dir = vim.g["sessions_sheets_" .. name:gsub("%W", "_")]
    if type(dir) ~= "string" or vim.fn.isdirectory(dir .. "/lua") ~= 1 then
      return false
    end
    vim.opt.rtp:append(dir)
  end
  return true
end

---The own tree of filetree.nvim (`adapter = "native"`), set up as a person would; `_G.tree` is its adapter. Without
---icons (no Nerd Font in a snapshot) and without filetree.nvim's own per-project session store: the named session
---is the one place here.
---@param opts table|nil  merged over the setup table
function _G.tree_setup(opts)
  vim.g.have_nerd_font = false
  require("filetree").setup(vim.tbl_deep_extend("force", {
    adapter = "native",
    deps_popup = false,
    native = { width = 30 },
    features = { session = { enabled = false }, close_on_open = { enabled = false } },
  }, opts or {}))
  _G.tree = require("filetree").adapter()
end

---Every editor of a sheet about the tree in a session starts with this (the first step, and the `+lua` of a
---`restart`): ui.nvim and filetree.nvim on the runtimepath, store and projects below `stdpath("data")`, no
---statusline (it would name a temporary path), the own tree and sessions.nvim set up.
---@param opts { tests: boolean|nil }|nil  `tests`: testing.nvim registers its view `tests` (as its setup does)
function M.tree_boot(opts)
  assert(M.add_deps("ui.nvim", "filetree.nvim"), "ui.nvim or filetree.nvim is gone")
  _G.persistent()
  vim.o.laststatus = 0
  vim.o.ruler = false
  _G.tree_setup()
  if opts and opts.tests then
    _G.tests_view()
  end
  _G.setup({ chip = { enable = false } })
end

---testing.nvim registers its view `tests` at the tree, as its setup does in a real config.
function _G.tests_view()
  vim.env.TESTING_TRUST = "1"
  assert(require("testing.integrations.tree").register(), "no tree registry in lib.nvim")
end

---The lines of the tree buffer ({} without a tree window).
---@return string[]
function _G.tree_lines()
  local buf = _G.tree and _G.tree.is_open() and _G.tree.get_bufnr() or nil
  return buf and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or {}
end

---The 1-based line of the tree that holds `text` (plain), or nil.
---@param text string
---@return integer|nil
function _G.tree_line(text)
  for i, line in ipairs(_G.tree_lines()) do
    if line:find(text, 1, true) then
      return i
    end
  end
  return nil
end

---Go into the tree window, the cursor on the line that holds `text`: where a person puts it before a key.
---@param text string
function _G.tree_on(text)
  local line = _G.tree_line(text)
  if not line then
    error(
      ("the tree shows no %s: %s"):format(vim.inspect(text), table.concat(_G.tree_lines(), " | ")),
      0
    )
  end
  vim.api.nvim_set_current_win(_G.tree.get_winid())
  vim.api.nvim_win_set_cursor(0, { line, 0 })
end

---Whether the git decorator of the tree has a badge for `rel` (below the current directory): the colour of its name.
---It answers debounced, after `git status`, a moment after the rows are drawn; a snapshot waits for it.
---@param rel string
---@return boolean
function _G.git_badge(rel)
  local decorator = require("lib.nvim.tree.registry").get("decorator", "git")
  if not decorator then
    return false
  end
  local want = vim.fs.normalize(vim.fn.getcwd() .. "/" .. rel):lower()
  for path in pairs(decorator.all() or {}) do
    if vim.fs.normalize(path):lower() == want then
      return true
    end
  end
  return false
end

---Leave the tree for the first window that is not the tree's: where a person is when they quit.
function _G.to_editor()
  for _, w in ipairs(_G.wins()) do
    if w ~= _G.tree.get_winid() then
      vim.api.nvim_set_current_win(w)
      return
    end
  end
  error("no editor window", 0)
end

---`got` equals `want` (deep), or an error that shows both (the failure line of the sheet names them).
---@param got any
---@param want any
---@return boolean
function _G.same(got, want)
  if not vim.deep_equal(got, want) then
    error(("got %s, wanted %s"):format(vim.inspect(got), vim.inspect(want)), 0)
  end
  return true
end

---Keep `value` for the editor after a `restart` (below `stdpath("data")`, see `_G.persistent`), or read it back.
---@param name string
---@param value any|nil  nil: read
---@return any
function _G.kept(name, value)
  local path = vim.fn.stdpath("data") .. "/sheet/kept-" .. name .. ".json"
  if value == nil then
    return vim.json.decode(vim.fn.readfile(path)[1]).value
  end
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ vim.json.encode({ value = value }) }, path)
  return value
end

return M
