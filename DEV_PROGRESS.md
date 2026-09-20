# Development Progress

## Current
- Branch: `dev`
- Version: `1.9.18-dev`
- Goal: Migrate Cooline to the VanillaTemplate development workflow without changing intended addon behaviour.

## Recent Commits
- `932921c` - Document Cooline 1.9.17 timeline strata fix (migration base on `master`)

## Completed / Verified
- Existing Cooline 1.9.x feature work up to 1.9.17 is preserved as the migration baseline.
- Client Default bar font inheritance was user-confirmed before migration.
- Cooline-owned font popup no longer intentionally styles Blizzard shared dropdown rows.

## Implemented / Awaiting Test
- Current 1.9.17 dedicated timeline text strata change still requires in-game verification.
- Migration work in this branch is not yet complete.

## Current Issues
- Workflow migration in progress.
- Recent timeline text/icon draw-order behaviour is not yet user-verified.

## Testing

### Last Test
- Version/commit: 1.9.17 / 932921c
- Passed: Client Default bar font inheritance.
- Failed: Earlier frame-level-only attempts did not keep icons behind timeline text.
- Not tested: Final 1.9.17 dedicated HIGH-strata timeline overlay.

### Next Test
- After migration completes, run the full regression pass from this file before promoting any stable release.

## Planned / To-do
- Convert active development to VanillaTemplate branch/version rules.
- Normalize addon filenames to `Cooline.toc` and `Cooline.lua`.
- Split localization into `locales/enUS.lua` plus per-locale translation files.
- Integrate `compat.lua` and `appearance.lua` into the main Lua file.
- Remove post-hoc translation/font traversal and patch-style polling where a direct implementation is available.
- Preserve all SavedVariables and migration compatibility.
- Make the TOC the only version source.
- Keep the proposed Spells/Items options-panel re-layout out of this migration.

## Ideas / Backlog
- Reorganize the Spells and Items option panels using the approved mock-up after migration regression testing.

## Deferred
- Promotion to 2.0.0.
- Stable branch release until user explicitly confirms a known-good build.

## Exact Next Step
Complete the VanillaTemplate structural/code migration on `dev`, then perform a static audit and hand the resulting `1.9.18-dev` build to the user for in-game regression testing.
