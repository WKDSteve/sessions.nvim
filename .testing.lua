-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "sessions",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = { ["TESTS/sheets_spec.lua"] = "busted", ["*"] = "h" },
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  -- ui.nvim is declared in TESTS/minimal_init.lua only: everything here goes on the runtimepath of the specs, which
  -- stand up their own `ui.kit` doubles. The test sheets add it in their child editor.
  deps = { "lib.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next). Needed: init_spec runs setup(), a one-shot, and
  -- statusline_spec expects no active session; the old run.lua guaranteed that by file order.
  isolated = "file",
  -- Environment variables the specs read; a child editor inherits an allowlist only (never secrets).
  -- UI_NVIM_DIR: the way ui.nvim reaches the children from the worktree of `ci commit`, where it is no sibling.
  env_allow = { "LIB_NVIM_DIR", "UI_NVIM_DIR" },
  -- All test sheets run in one spec file, one child editor each: the defaults of 10 s per case and 60 s per file
  -- are reached under load (fileops, 2026-11-07).
  timeouts = { case_ms = 30000, file_ms = 300000 },
  -- Guards (docs/GUARDS.md of testing.nvim). Measured on this suite: the only finding is the file-system
  -- guard seeing the fixtures below; state, scheduled errors, prompts and deprecations are clean, so
  -- they raise instead of warn. The process/network guard is measured too.
  guards = {
    fs = "error",
    state = "error",
    scheduled_error = "error",
    prompt = "error",
    deprecation = "error",
    process_net = "error",
  },
  -- What the guards let through on purpose.
  guard_allow = {
    -- Every spec keeps its session store in a TESTS/.fixture-* directory that it creates and removes.
    fs = { "TESTS" },
    -- The branch/repo specs make throwaway git repositories (git init, symbolic-ref, rev-parse).
    spawn = {
      "git",
      -- sheets_spec.lua: every test sheet (TESTS/sheets/) runs in a child editor.
      "nvim",
    },
  },
  -- The runner counts which commands, keymaps and autocommands the specs exercise (docs/SURFACE.md of testing.nvim);
  -- `scripts/test.sh surface` compares that with surface.baseline.json (a regression gate, not a percentage).
  surface = { track = true },
  -- gated: a failed conformance check makes `scripts/test.sh conformance` exit 1 (docs/CONFORMANCE.md of testing.nvim)
  conformance = { gate = true },
  -- The pipeline is derived (`scripts/test.sh ci list`). The GitHub workflow is generated from `workflow`:
  -- `testing init --workflow=public --force` writes it (testing.nvim docs/WORKFLOW-CI.md), the step
  -- workflow-in-sync checks it.
  ci = {
    workflow = {
      name = "sessions.nvim",
      layout = "hosted",
      -- the steps that depend on the platform: the windows and macOS legs run only these
      platform = { "suite", "conformance" },
      -- more checkouts below .deps/, not on the runtimepath of the specs
      checkouts = {
        {
          repo = "WKDSteve/ui.nvim",
          ref = "ci-verified",
          why = "The corner chip, the dialogs and the kit marks menu are what the test sheets press, for real.",
        },
      },
    },
    steps = {
      ["workflow-in-sync"] = { preset = "workflow-in-sync" },
    },
  },
}
