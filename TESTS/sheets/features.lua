-- TESTS/sheets/features.lua -- the functionalities of sessions.nvim as its user meets them; `testing sheets report`
-- says which ones have a feature sheet (`feature = "<id>"`) and in which state, and K16 warns about a sheet that names
-- an id not listed here. Data: read with an empty environment like a sheet (testing.nvim docs/SHEETS.md).
-- The list follows docs/FEATURES.md and ALL/manual-test-checklists/sessions.md.
return {
  {
    id = "sessions.naming",
    title = "The session is named after the project root and the git branch; another branch brings another session",
    docs = "docs/session-scoping.md",
  },
  {
    id = "sessions.lifecycle",
    title = ":Session save, load, list and current, with a name or bare for the session of this place",
    surface = {
      "command:Session save",
      "command:Session load",
      "command:Session list",
      "command:Session current",
    },
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.delete-rename",
    title = ":Session delete and :Session rename, with the companion file and without clobbering another session",
    surface = { "command:Session delete", "command:Session rename" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.autosave",
    title = "Leaving Neovim saves the session of the project, and :LastSession brings it back",
    surface = { "command:LastSession", "config:autosave", "config:save_last" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.autoload",
    title = 'A plain nvim start loads the session of the place, or asks first with autoload = "ask"',
    surface = { "config:autoload" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.picker",
    title = ":SessionLoad picks a session with a preview, <CR> loads it, <C-d> deletes it",
    surface = { "command:SessionLoad" },
    docs = "docs/picker.md",
  },
  {
    id = "sessions.toggle-track",
    title = ":Session toggle-track flips git skip-worktree on a session file kept in a repository",
    surface = { "command:Session toggle-track" },
    docs = "docs/git-integration.md",
  },
  {
    id = "sessions.portable",
    title = "relative_paths and root_remap make a session load on another machine or in another place",
    surface = { "config:relative_paths", "config:root_remap" },
    docs = "docs/portability.md",
  },
  {
    id = "sessions.tabs",
    title = ":Session save-tab and load-tab keep the windows of one tab as a session of their own",
    surface = { "command:Session save-tab", "command:Session load-tab" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.layout",
    title = ":Session save-layout and load-layout bring back the split structure and sizes, not the files",
    surface = { "command:Session save-layout", "command:Session load-layout" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.status",
    title = "The statusline names the session and marks it dirty after a layout change; a companion .json records it",
    docs = "docs/statusline.md",
  },
  {
    id = "sessions.keymaps",
    title = "Opt-in keymaps press the session commands, each with a description and a which-key group",
    surface = { "config:keymaps" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.chip",
    title = "A corner chip shows that a session was saved or loaded, instead of a notification",
    surface = { "command:Session chip-toggle", "config:chip" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.stale",
    title = ":Session stale lists the sessions of gone branches and delete-stale removes them after one question",
    surface = {
      "command:Session stale",
      "command:Session delete-stale",
      "command:Session save-timestamp",
    },
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.marks",
    title = ":Session marks keeps an ordered list of files to jump to by number, at the cursor position left there",
    surface = { "command:Session marks" },
    docs = "docs/marks.md",
  },
  {
    id = "sessions.clean-save",
    title = "Quickfix, scratch and temp buffers are left out of a saved session",
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.safe-load",
    title = "Loading a session with modified buffers hides them instead of failing with E445",
    docs = "docs/FEATURES.md",
  },
  {
    id = "sessions.tabline",
    title = "The order of a tabline's buffers and the pinned buffers of each tab come back with the session",
    docs = "docs/FEATURES.md",
  },
}
