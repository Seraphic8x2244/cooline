# Development Progress

## Current
- Branch: `dev`
- Version: `2.0.0-dev`
- Development/runtime baseline before this documentation-only workflow migration: `0d4f484e4396aa276c7249ab895c6dbfcf92cccc` (`Mark Cooline 2.0.0 complete`).
- Current handoff: the documentation-migration commit containing this file on `dev`; verify the actual remote `dev` head before new work.
- Stable baseline: `2.0.0` at `cdd502226b3e44b27d14fa2c855f0b93ae207c09` on `main`.
- Goal: Cooline 2.0.0 is feature-complete for now; development is paused by user decision.
- Current scope boundary: No active feature work. Resume only after defining a new development version and scope.

## Current Design / Development Contract

### Architecture / Ownership
- Runtime structure is intentionally compact: `Cooline.lua` is the single core runtime Lua file, supported by locale files under `locales/` and assets under `artwork/`.
- Cooldown tracking, configuration UI, font selection/preview, filtering, layout/appearance handling and cooldown-failure animation remain integrated into the Cooline core rather than split into new runtime modules.
- Active development belongs on `dev`; `main` is the stable installable baseline.
- `DEV_PROGRESS.md` is the sole live project-specific development/status source of truth. `dev_rulebook.md` owns the shared workflow rules.

### Invariants
- Target remains World of Warcraft 1.12.1 with `## Interface: 11200` and Lua 5.0 compatibility.
- SavedVariables names remain `CoolineDB` and `CoolineCharDB`.
- The Qiraji-gem mid blue `#2982D1` is scoped to the `Cooline` name in the options header and addon-list TOC title; other headers retain their normal/gold colours.
- Cooldown icons render above the bar while timeline labels use a dedicated higher-strata Cooline overlay so labels remain above the icons.
- Client Default timeline font must inherit the active Blizzard GameFont. Font preview UI remains Cooline-owned and must not modify Blizzard shared `DropDownList...Button` font rows.
- Opacity values remain clamped to valid 0-100% values at their input/storage boundary.
- Locale-specific spell/item filter data must not mix localized names between client locales.
- Cooldown-failure animation must not depend on English combat-text parsing.

### Protocol / Data Model
- `CoolineDB` stores account-wide configuration; `CoolineCharDB` stores per-character state/overrides.
- Appearance settings are account-wide with the established optional per-character behaviour.
- Spell/item filter state is locale-scoped so localized names remain isolated by client locale.
- Supported locale files remain `enUS`, `deDE`, `frFR`, `esES`, `koKR`, `zhCN` and `zhTW`.

### Active Decisions
- Cooline 2.0.0 is accepted as the finished release for the current scope.
- No further UI redesign, feature expansion or debug tooling is active.
- A Spells/Items options-panel re-layout remains only an optional future idea.
- WoW 1.12.1 item cooldown identification remains best-effort where the client cannot reliably identify shared item cooldowns; do not misrepresent that client limitation as exact tracking.

## Recent Relevant Commits
- `0d4f484e4396aa276c7249ab895c6dbfcf92cccc` — Mark Cooline 2.0.0 complete.
- `86734514655b29a1e88ed695106352f3a302adea` — Align dev version with Cooline 2.0.0.
- `cdd502226b3e44b27d14fa2c855f0b93ae207c09` — Release Cooline 2.0.0 on `main`.
- Earlier migration/branding history is retained in Git history rather than duplicated here.

## Completed / User-Verified
- Stable/dev branch workflow migration is complete.
- Stable `main` is directly installable and excludes development-only status/workflow documents.
- Addon structure is normalized to `Cooline.toc`, `Cooline.lua`, `locales/` and `artwork/`.
- Client Default bar-font inheritance was user-confirmed.
- The user accepted the migrated addon state and Qiraji-blue Cooline branding as good.
- Stable release `2.0.0` was accepted as the finished release for the current scope.

## Implemented / Awaiting Runtime Test
The following shipped in the accepted 2.0.0 state but were not individually or exhaustively runtime-verified in every relevant path:
- Dedicated higher-strata timeline-label overlay.
- Core-integrated font selection and Cooline-owned font preview popup.
- Locale-scoped spell/item filter migration.
- Non-English cooldown-failure matching in the core event path.
- Source-level clamping for opacity SavedVariables and typed input.
- Exhaustive behaviour across all supported non-English clients/locales.

## Static / Automated Checks
- Static audit confirmed every newly created FontString receives a font/font object before text is assigned.
- Static audit confirmed no writes remain to Blizzard shared `DropDownList...Button` font rows.
- At this workflow migration baseline, `Cooline.lua`, `README.md`, `artwork/` and `locales/` have identical Git objects on `dev` and stable `main`; only expected TOC development metadata and development documentation differ.
- This workflow migration changes documentation only; addon runtime files are intentionally untouched.

## Current Issues
- No known active code issue.
- WoW 1.12.1 provides limited information for identifying some shared item cooldowns, so affected item identification remains best-effort.
- Non-English behaviour has not been exhaustively runtime-tested across every supported locale.

## Testing

### Last Runtime Test
- Version/commit: Stable `2.0.0` at `cdd502226b3e44b27d14fa2c855f0b93ae207c09`.
- Passed: Overall addon state accepted as finished for the current scope; Client Default font inheritance; intended Qiraji-blue Cooline-name branding scope.
- Failed: No currently documented active failure.
- Not tested: Exhaustive per-locale coverage and individual exhaustive runtime validation of every item listed under Implemented / Awaiting Runtime Test.

### Next Runtime Test
- None while development is paused.
- If development resumes, run a regression pass covering startup errors, timeline draw order, fonts/menu isolation, branding/appearance scope, horizontal and vertical layouts, opacity, filters, minimap/locking and cooldown animation before the next stable release.

## Planned / Next Work
- None. Development is paused.

## Deferred / Out of Scope
- Further UI redesign or feature additions.
- Spells/Items options-panel re-layout unless deliberately promoted from idea to active scope.
- Additional non-English runtime verification until development/testing resumes.
- Debug tooling unless a concrete need appears.

## Release / Promotion Notes
- Main-only or release-only content to preserve: there are currently no extra main-only files. Stable `main` intentionally contains only `Cooline.lua`, stable `Cooline.toc`, `README.md`, `artwork/` and `locales/`; preserve stable TOC Title/Version metadata and do not copy development docs to `main`.
- Known validation debt accepted for release: the items listed under Implemented / Awaiting Runtime Test were not individually/exhaustively exercised in every path or locale before/after the accepted 2.0.0 release.
- External/runtime prerequisites: WoW 1.12.1. No DLL/client extension is required for normal Cooline operation.

## Exact Next Step
None while Cooline 2.0.0 remains the finished scope. If development resumes, read `dev_rulebook.md` and this file, verify the actual remote `dev` head, choose the next development version, define the new scope, and only then change runtime code.
