# Development Progress

## Current
- Branch: `dev`
- Version: `2.0.0-dev`
- Stable release: `2.0.0` on `main`
- Status: Feature-complete for now; development paused by user decision.

## Recent Commits
- Stable `main`: cdd5022 - Release Cooline 2.0.0.
- `8673451` - Align dev version with Cooline 2.0.0.
- `9fd3b04` - Add Qiraji-blue Cooline title to addon list.
- `7d2ffbc` - Migrate Cooline core to VanillaTemplate structure.
- Migration base: `932921c` - Cooline 1.9.17 timeline strata fix on legacy `master`.

## Completed / Verified
- Stable workflow migration is complete: active development uses `dev`, stable releases use `main`.
- Stable `main` contains only installable addon files; development-only docs remain on `dev`.
- Addon structure is normalized to `Cooline.toc`, `Cooline.lua`, `locales/`, and `artwork/`.
- SavedVariables remain `CoolineDB` and `CoolineCharDB`.
- Locale files are split into `enUS`, deDE, frFR, esES, koKR, zhCN and zhTW files.
- Client Default bar-font inheritance was user-confirmed.
- User accepted the migrated addon state and Qiraji-blue Cooline branding as good.
- Qiraji-gem mid blue `#2982D1` is used only for the `Cooline` addon name in the options header and addon-list TOC title.
- Stable release is now `2.0.0`.

## Implemented / Not Fully Runtime-Verified
- Timeline labels use a dedicated HIGH-strata Cooline overlay so cooldown icons remain above the bar but behind timeline text.
- Font selection is integrated directly into `Cooline.lua` with a Cooline-owned preview popup.
- Locale-scoped spell/item filter migration is integrated into settings initialization.
- Non-English cooldown-failure matching is integrated directly into the core event path.
- Opacity SavedVariables and typed input are clamped at the source.
- Static audit confirmed every newly created FontString has a font/font object before text is assigned.
- Static audit confirmed no writes to Blizzard shared `DropDownList...Button` font rows remain.
- Non-English client behaviour has not been exhaustively runtime-tested.

## Current Issues
- No known active issue.
- No known static migration error.

## Testing

### Last Accepted State
- Version: `2.0.0`
- User assessment: addon feels done for now.
- Known accepted branding: Qiraji-blue `Cooline` name only; all other headers retain gold/normal colours.

### Future Regression Check
If development resumes, re-check startup errors, timeline draw order, fonts/menu isolation, appearance scope, layouts, opacity, filters, minimap/locking and cooldown animation before the next stable release.

## Planned / To-do
- None. Development is paused.

## Ideas / Backlog
- Spells/Items options-panel re-layout remains an optional future idea, not an active task.

## Deferred
- Any further UI redesign or feature additions.
- Additional non-English runtime verification.
- Debug tooling unless a concrete need appears.

## Exact Next Step
None. Cooline 2.0.0 is the current finished release. If development resumes, start from `dev`, review this file, choose the next development version, and define the new scope before changing code.
