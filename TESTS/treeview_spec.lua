-- Test code: a sidecar or a registry entry coming back nil here must crash and name itself.
---@diagnostic disable: need-check-nil, duplicate-set-field
-- TESTS/treeview_spec.lua — the two things sessions.nvim does with a tree view:
--   * sessions.treeview: what the file tree showed (root, the view on screen, the open folders) saved
--     to `.<name>.tree.json` and put back after a load, through `sessions.core` and on its own
--   * sessions.integrations.tree: the decorator `pin` at lib.nvim.tree.registry, a sign on every
--     default and pin of the marks
--
-- filetree.nvim is not a dependency and not installed here: `H.stub("filetree", ...)` is a small fake
-- with the functions of its public adapter that record what they are called with. That a real tree
-- draws the sign and comes back with a session is `TESTS/tree_drive.lua`, a hand run.

return function(H)
  local api = vim.api
  local config = require("sessions.config")
  local json = require("lib.nvim.fs.json")

  local dir, cleanup = H.fixture("treeview")
  local root = dir .. "/sroot"
  vim.cmd("silent! %bwipeout!")

  local function file(name)
    local p = dir .. "/" .. name
    vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
    vim.fn.writefile({ name }, p)
    return vim.fs.normalize(p)
  end
  local a = file("proj/a.md")
  local b = file("proj/lua/b.lua")
  local c = file("proj/c.txt")
  local proj = vim.fs.normalize(dir .. "/proj")

  config.setup({
    root = root,
    branch_aware = false,
    project_aware = false,
    metadata = false,
    restore_buffer_order = false,
    restore_pinned_buffers = false,
    autosave = false,
    marks = {
      enable = true,
      scope = "global",
      defaults = { a },
      import_harpoon = false,
      context_debounce_ms = 0,
    },
  })

  local treeview = H.fresh("sessions.treeview")
  local session = dir .. "/work.vim"
  local sidecar = dir .. "/.work.tree.json"
  H.eq(treeview.sidecar_path(session), sidecar, "the sidecar sits next to the session file")

  ---A fake filetree.nvim: `tree` is what its tree shows, `calls` what it was asked to do.
  ---@param extra? table  fields laid over the adapter
  ---@return table tree, string[] calls, fun() restore
  local function fake_filetree(extra)
    local tree = { name = "native", open = true, root = proj, view = "git", expanded = {} }
    local calls = {}
    local adapter = {
      is_open = function()
        return tree.open
      end,
      get_root_path = function()
        return tree.root
      end,
      get_expanded_paths = function()
        return tree.expanded
      end,
      set_root = function(path)
        calls[#calls + 1] = "set_root " .. vim.fs.normalize(path)
        tree.root = path
        return true
      end,
      open_cwd = function()
        calls[#calls + 1] = "open"
        tree.open = true
        return true
      end,
      expand_paths = function(paths)
        calls[#calls + 1] = "expand " .. table.concat(paths, ",")
        tree.expanded = paths
        return true
      end,
    }
    for key, value in pairs(extra or {}) do
      adapter[key] = value
    end
    local switcher = {
      current = function()
        return tree.view
      end,
      switch = function(name)
        calls[#calls + 1] = "switch " .. name
        tree.view = name
        return true
      end,
    }
    local restore = H.stub("filetree", {
      adapter = function()
        adapter.name = tree.name
        return adapter
      end,
      feature = function(name)
        return name == "source_switcher" and switcher or nil
      end,
    })
    return tree, calls, restore
  end

  -- capture -------------------------------------------------------------------

  do
    local restore = H.stub("filetree", false)
    H.eq(treeview.capture(), nil, "without filetree.nvim there is nothing to save")
    H.eq(package.loaded["filetree"], nil, "and capture did not try to load it")
    restore()
  end

  do
    local tree, _, restore = fake_filetree()
    tree.expanded = { proj .. "/lua", proj .. "/docs" }
    local state = treeview.capture()
    H.eq(state.adapter, "native")
    H.eq(state.root, proj, "the root of the tree")
    H.eq(state.view, "git", "the view on screen, from the source switcher")
    H.eq(table.concat(state.expanded, ","), proj .. "/lua," .. proj .. "/docs", "the open folders")

    tree.open = false
    H.eq(treeview.capture(), nil, "a closed tree is not saved")
    tree.open = true
    tree.name = "neotree"
    H.eq(treeview.capture(), nil, "another tree plugin behind filetree.nvim is not this one's job")
    restore()
  end

  do
    -- an adapter that knows its view itself is asked first
    local _, _, restore = fake_filetree({
      get_view = function()
        return "buffers"
      end,
    })
    H.eq(treeview.capture().view, "buffers", "adapter.get_view wins over the feature")
    restore()
  end

  -- save and restore ------------------------------------------------------------

  do
    local tree, calls, restore = fake_filetree()
    tree.expanded = { proj .. "/lua" }
    H.ok(treeview.save(session, treeview.capture()), "save reports it wrote a sidecar")
    local data = json.read(sidecar)
    H.eq(data.view, "git")
    H.eq(data.root, proj)

    -- a new editor: the tree is closed, at another root, on the files
    tree.open, tree.root, tree.view, tree.expanded = false, dir, "files", {}
    local win = api.nvim_get_current_win()
    H.ok(treeview.restore(session), "restore reports it applied the state")
    H.eq(
      table.concat(calls, " | "),
      ("set_root %s | open | expand %s | switch git"):format(proj, proj .. "/lua"),
      "root first, then the window, the folders, the view"
    )
    H.eq(api.nvim_get_current_win(), win, "the window that had the focus keeps it")
    restore()
  end

  do
    -- the files view needs no switch; a root that is gone is not set, the tree still opens
    local tree, calls, restore = fake_filetree()
    tree.view = "files"
    tree.root = dir .. "/gone"
    H.ok(treeview.save(session, treeview.capture()))
    tree.open = false
    H.ok(treeview.restore(session))
    H.eq(table.concat(calls, " | "), "open", "no set_root to a missing folder, no switch to files")
    restore()
  end

  do
    -- adapter.show_view is used when it is there
    local shown = {}
    local tree, calls, restore = fake_filetree({
      show_view = function(name)
        shown[#shown + 1] = name
        return true
      end,
    })
    H.ok(treeview.save(session, treeview.capture()))
    tree.open = false
    H.ok(treeview.restore(session))
    H.eq(table.concat(shown, ","), "git", "the adapter shows the view")
    H.excludes(table.concat(calls, " | "), "switch", "and the feature is not asked as well")
    restore()
  end

  do
    -- a sidecar is untrusted: only what capture writes reaches the tree
    local _, calls, restore = fake_filetree()
    json.write(sidecar, {
      adapter = "native",
      root = 42,
      view = "git | lua os.exit(1)",
      expanded = { 1, proj .. "/lua", { "x" }, "" },
    })
    H.ok(treeview.restore(session))
    H.eq(
      table.concat(calls, " | "),
      "open | expand " .. proj .. "/lua",
      "a root that is no string, a view that is no name and folders that are no strings are dropped"
    )
    restore()
  end

  do
    local _, calls, restore = fake_filetree()
    json.write(sidecar, { adapter = "neotree", root = proj, view = "git", expanded = {} })
    H.falsy(treeview.restore(session), "a sidecar of another tree is not applied")
    vim.fn.writefile({ "[1, 2" }, sidecar)
    H.falsy(treeview.restore(session), "nor is one that is no JSON")
    os.remove(sidecar)
    H.falsy(treeview.restore(session), "nor is a missing one")
    H.eq(#calls, 0, "the tree was not touched")
    restore()
  end

  do
    -- the tree is another plugin's now: nothing is applied
    local tree, calls, restore = fake_filetree()
    H.ok(treeview.save(session, treeview.capture()))
    tree.name = "neotree"
    H.falsy(treeview.restore(session))
    H.eq(#calls, 0)
    restore()
  end

  -- no state: the sidecar of an earlier save goes --------------------------------

  do
    local _, _, restore = fake_filetree()
    H.ok(treeview.save(session, treeview.capture()))
    H.eq(vim.fn.filereadable(sidecar), 1)
    H.falsy(treeview.save(session, nil), "nothing to write")
    H.eq(vim.fn.filereadable(sidecar), 0, "and the tree of an earlier save does not come back")

    H.ok(treeview.save(session, treeview.capture()))
    local renamed = dir .. "/other.vim"
    treeview.rename(session, renamed)
    H.eq(vim.fn.filereadable(sidecar), 0, "rename moves the sidecar")
    H.eq(vim.fn.filereadable(dir .. "/.other.tree.json"), 1)
    treeview.delete(renamed)
    H.eq(vim.fn.filereadable(dir .. "/.other.tree.json"), 0, "delete removes it")
    restore()
  end

  -- through sessions.core ----------------------------------------------------------

  do
    local core = require("sessions.core")
    local kept = vim.fn.bufadd(b)
    vim.fn.bufload(kept)
    vim.bo[kept].buflisted = true
    api.nvim_set_current_buf(kept)

    -- a tree window as the real one is: a `nofile` buffer in a split, which a save wipes
    vim.cmd("vsplit")
    local tree_win = api.nvim_get_current_win()
    local tree_buf = api.nvim_create_buf(false, true)
    vim.bo[tree_buf].buftype = "nofile"
    api.nvim_win_set_buf(tree_win, tree_buf)
    vim.cmd("wincmd p")

    local tree, calls, restore = fake_filetree({
      is_open = function()
        return api.nvim_buf_is_valid(tree_buf) and #vim.fn.win_findbuf(tree_buf) > 0
      end,
    })
    tree.expanded = { proj .. "/lua" }

    H.ok(core.save("withtree"))
    H.falsy(api.nvim_buf_is_valid(tree_buf), "fixture: the save wiped the tree buffer")
    local saved = json.read(root .. "/.withtree.tree.json")
    H.ok(saved, "the state was read before the wipe")
    H.eq(saved.view, "git")
    H.eq(saved.expanded[1], proj .. "/lua")

    tree.root, tree.view, tree.expanded = dir, "files", {}
    H.ok(core.load("withtree"))
    H.eq(
      table.concat(calls, " | "),
      ("set_root %s | open | expand %s | switch git"):format(proj, proj .. "/lua"),
      "a load puts the tree back"
    )

    -- saved again with the tree closed: the next load leaves the tree alone
    for i = #calls, 1, -1 do
      calls[i] = nil
    end
    H.ok(core.save("withtree"))
    H.eq(vim.fn.filereadable(root .. "/.withtree.tree.json"), 0, "no tree, no sidecar")
    H.ok(core.load("withtree"))
    H.eq(#calls, 0)

    -- rename and delete take the sidecar along
    vim.cmd("vsplit")
    tree_buf = api.nvim_create_buf(false, true)
    vim.bo[tree_buf].buftype = "nofile"
    api.nvim_win_set_buf(0, tree_buf)
    vim.cmd("wincmd p")
    H.ok(core.save("withtree"))
    H.ok(core.rename("withtree", "moved"))
    H.eq(vim.fn.filereadable(root .. "/.moved.tree.json"), 1, "core.rename moves it")
    H.ok(core.delete("moved"))
    H.eq(vim.fn.filereadable(root .. "/.moved.tree.json"), 0, "core.delete removes it")

    -- switched off: nothing is written, nothing is asked
    config.setup({
      root = root,
      branch_aware = false,
      project_aware = false,
      metadata = false,
      restore_buffer_order = false,
      restore_pinned_buffers = false,
      autosave = false,
      restore_tree = false,
      marks = { enable = true, scope = "global", defaults = { a }, import_harpoon = false },
    })
    vim.cmd("vsplit")
    tree_buf = api.nvim_create_buf(false, true)
    vim.bo[tree_buf].buftype = "nofile"
    api.nvim_win_set_buf(0, tree_buf)
    vim.cmd("wincmd p")
    H.ok(core.save("plain"))
    H.eq(
      vim.fn.filereadable(root .. "/.plain.tree.json"),
      0,
      "restore_tree = false writes no sidecar"
    )
    core.delete("plain")
    restore()
  end

  -- the pin sign -------------------------------------------------------------------

  do
    local registry = require("lib.nvim.tree.registry")
    local marks = H.fresh("sessions.marks")
    local integration = H.fresh("sessions.integrations.tree")
    local key = integration.norm

    H.ok(integration.register(), "registered")
    local decorator = registry.get("decorator", integration.NAME)
    H.ok(decorator, "the entry is at the registry")
    H.eq(decorator.key, "path")
    H.eq(decorator.slot, "sign", "drawn in the first cell of the line")

    H.eq(decorator.get(key(a)), nil, "nothing is read before a tree listens")
    local emitted = {}
    local unsubscribe = decorator.subscribe(function(keys)
      emitted[#emitted + 1] = table.concat(keys or { "all" }, ",")
    end)
    H.eq(#emitted, 0, "subscribing returns before the pins are read")
    H.ok(
      vim.wait(1000, function()
        return #emitted > 0
      end, 5),
      "the first read reports"
    )
    H.eq(emitted[1], key(a), "the config default is pinned")

    -- the lookup with every way to the disk closed
    local fs_stat, fs_open, real_read = vim.uv.fs_stat, vim.uv.fs_open, json.read
    local function closed()
      error("the lookup touched the disk")
    end
    vim.uv.fs_stat, vim.uv.fs_open, json.read = closed, closed, closed
    local looked, sign = pcall(decorator.get, key(a))
    local looked_miss, miss = pcall(decorator.get, key(c))
    local listed, all = pcall(decorator.all)
    vim.uv.fs_stat, vim.uv.fs_open, json.read = fs_stat, fs_open, real_read
    H.ok(looked and looked_miss and listed, "get and all are table lookups")
    H.eq(sign.text, "*")
    H.eq(miss, nil, "a file that is not pinned has no sign")
    H.eq(vim.tbl_count(all), 1)

    -- pin and unpin are followed, and only the path that changed is named
    emitted = {}
    H.ok(marks.pin(c, { quiet = true }))
    H.eq(table.concat(emitted, " | "), key(c), "a pin gives the sign")
    H.eq(decorator.get(key(c)).text, "*")
    emitted = {}
    H.ok(marks.unpin(c))
    H.eq(table.concat(emitted, " | "), key(c), "an unpin takes it")
    H.eq(decorator.get(key(c)), nil)
    H.ok(decorator.get(key(a)), "the default keeps its sign")

    -- nobody listens any more
    unsubscribe()
    emitted = {}
    H.ok(marks.pin(c, { quiet = true }))
    H.eq(#emitted, 0, "after the last tree left nothing is reported")
    H.eq(decorator.get(key(c)), nil, "and nothing is read")
    H.ok(marks.unpin(c))

    -- another sign; unregister
    H.ok(integration.register({ sign = "P" }))
    decorator = registry.get("decorator", integration.NAME)
    local got = false
    local unsubscribe2 = decorator.subscribe(function()
      got = true
    end)
    vim.wait(1000, function()
      return got
    end, 5)
    H.eq(decorator.get(key(a)).text, "P", "a configured sign")
    unsubscribe2()
    integration.unregister()
    H.eq(registry.get("decorator", integration.NAME), nil, "unregister takes the entry out")

    -- the option is known to the config
    H.eq(config.get().tree, true, "on by default")
    H.eq(config.get().restore_tree, false, "fixture: switched off above")
  end

  vim.cmd("silent! only")
  vim.cmd("silent! %bwipeout!")
  cleanup()
end
