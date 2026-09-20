# Development Progress

## Current
- Branch: `dev`
- Version: `1.9.18-dev`
- Goal: Validate the completed VanillaTemplate workflow migration and preserve current Cooline behaviour before resuming feature work.

## Recent Commits
- `7d2ffbc` - Migrate Cooline core to VanillaTemplate structure.
- `1d7af96` - Add zhTW locale file (final per-locale split commit).
- `0af6b47` - Add canonical enUS locale file.
- `891af80` - Add Cooline development progress.
- `e024836` - Add VanillaTemplate development guide.
- Migration base: `932921c` - Cooline 1.9.17 timeline strata fix on legacy `master`.

## Completed / Verified
- Active development now uses the `dev` branch.
- `DEV_GUIDE.md` matches VanillaTemplate.
- `DEV_PROGRESS.md` is present for handoff/status tracking.
- Dev TOC is the version source and reports `Cooline-dev` / `1.9.18-dev`.
- Addon files are normalized to `Cooline.toc` and `Cooline.lua`.
- SavedVariables remain `CoolineDB` and `CoolineCharDB`.
- Locale files are split into `locales/enUS.lua` plus deDE, frFR, esES, koKR, zhCN and zhTW overrides.
- `compat.lua`, `appearance.lua`, legacy `locales.lua`, and lowercase Lua/TOC files are removed from `dev`.
- Static audit confirms every newly created FontString in the merged core has a font/font object before text is assigned.
- Static audit confirms no writes to Blizzard shared `DropDownList...Button` font rows remain.
- Static audit confirms no post-hoc localization walker or appearance polling driver remains.
- Client Default bar-font inheritance was user-confirmed before migration.
- User reports the migrated `1.9.18-dev` build looks good in-game; full checklist items not individually confirmed remain tracked below.

## Implemented / Awaiting Test
- Options highlight text uses Qiraji-gem mid blue `#2982D1` (`0.16, 0.51, 0.82`) only for the Cooline addon name and the active page's primary header (`Appearance`, `Spells`, `Items`); section subheaders, tabs, borders and buttons retain their existing gold accents.
- Timeline labels are created directly on a dedicated HIGH-strata Cooline overlay; cooldown icons remain in the normal bar hierarchy.
- Font selection is integrated directly into `Cooline.lua` with a Cooline-owned preview popup.
- Locale-scoped spell/item filter migration is integrated into settings initialization.
- Non-English cooldown-failure matching is integrated directly into the core event path instead of wrapping bar scripts.
- Opacity SavedVariables and direct edit-box input are clamped at the source.
- Custom Cooline UI FontStrings use the active client default font unless the timeline font option explicitly selects another font.
- Full `1.9.18-dev` migration regression remains untested in-game.

## Current Issues
- No known static migration error.
- Final timeline text-above-icons behaviour is still awaiting in-game confirmation.
- Non-English client behaviour is not runtime-tested.
- No Lua 5.0 compiler/client is available in the development environment; static inspection does not count as an in-game test.

## Testing

### Last Test
- Version/commit: pre-migration 1.9.17 line.
- Passed: Client Default bar font inheritance.
- Failed: Earlier frame-level-only text layering attempts before the dedicated HIGH-strata implementation.
- Not tested: Final 1.9.17 HIGH-strata implementation and the merged 1.9.18-dev migration.

### Next Test
1. Load `1.9.18-dev` and confirm no startup Lua errors.
2. Confirm cooldown icons render above the bar but behind timeline numbers.
3. Confirm Client Default and all four selectable fonts change only Cooline timeline text.
4. Open unitframe/right-click menus and confirm Cooline never changes their fonts.
5. Check account-wide/per-character appearance switching and persistence.
6. Check horizontal, vertical and reversed layouts.
7. Check active/inactive opacity sliders and typed values, including values above 100%.
8. Check spell and item blacklist/whitelist behaviour and existing saved filters.
9. Check minimap button, lock/unlock, right-click options and Alt-drag reposition.
10. Check cooldown-failure animation.
11. Treat non-English locale behaviour as unverified unless tested on those clients.

## Planned / To-do
- Run the migration regression test above.
- After regression passes, implement the approved Spells/Items options-panel re-layout as the next normal dev task.
- Continue development on `dev` using `-dev` without numbered dev suffixes.

## Ideas / Backlog
- Approved Spells/Items page reorganization: compact Icon Size, Filter Type, Add, and expanded Filtered list sections with matching layouts.

## Deferred
- Creating/promoting stable `main` until the user explicitly approves a known-good release.
- Retiring legacy `master` until stable `main` exists.
- Promotion to 2.0.0 until the redesigned addon is stable.
- Any Debug.lua tooling until a concrete debugging need appears.

## Exact Next Step
Reload/test the new Qiraji-blue header colour on `1.9.18-dev`. If the tone is approved, continue the remaining regression checklist before beginning the Spells/Items layout work.
