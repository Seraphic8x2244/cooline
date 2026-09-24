# Development Progress

## Current
- Branch: `dev`
- Version: `2.0.0-dev` in the TOC. This is still the documentation/planning state; the next runtime-development action is to bump to `2.1.0-dev` before code changes.
- Current pre-performance-roadmap head: `adb41f29d3a6bbf940e20a45565ba13a53e21873` (`Mark Cooline maintenance mode`).
- Current handoff: the roadmap commit containing this file on `dev`; verify the actual remote `dev` head before new work.
- Stable baseline: `2.0.0` at `cdd502226b3e44b27d14fa2c855f0b93ae207c09` on `main`.
- Goal: complete a native WoW 1.12.1 performance-focused `2.1.0` release first, preserve that native line, then develop `3.0.0` with ClassicAPI as a required runtime dependency.
- Current scope boundary: Stage 1 is performance-only. Preserve current Cooline behaviour, SavedVariables, UI, filters, cooldown semantics and appearance while removing avoidable background work.

## Current Design / Development Contract

### Architecture / Ownership
- Runtime structure remains intentionally compact: `Cooline.lua` is the single core runtime Lua file, supported by locale files under `locales/` and assets under `artwork/`.
- Cooldown tracking, configuration UI, font selection/preview, filtering, layout/appearance handling and cooldown-failure animation remain integrated into the Cooline core unless a future architectural need justifies a deliberate split.
- Active development belongs on `dev`; `main` remains the current stable installable baseline until a tested development build is promoted.
- `DEV_PROGRESS.md` is the sole live project-specific development/status source of truth. `dev_rulebook.md` owns the shared workflow rules.
- Do not develop 3.0 directly on `main`. Main remains the stable release line throughout development.

### Invariants
- Target remains World of Warcraft 1.12.1 with `## Interface: 11200`.
- The 2.1 line must remain native WoW 1.12.1 / Lua 5.0 compatible with no required DLL/client extension.
- The 3.0 line will require ClassicAPI and may use its API/events directly, but should still keep addon Lua syntax/tooling compatible with the project rulebook unless a deliberate exception is recorded here.
- SavedVariables names remain `CoolineDB` and `CoolineCharDB`; 2.1 and 3.0 must preserve existing SavedVariables compatibility unless explicitly changed later.
- The Qiraji-gem mid blue `#2982D1` is scoped to the `Cooline` name in the options header and addon-list TOC title; other headers retain their normal/gold colours.
- Cooldown icons render above the bar while timeline labels use a dedicated higher-strata Cooline overlay so labels remain above the icons.
- Client Default timeline font must inherit the active Blizzard GameFont. Font preview UI remains Cooline-owned and must not modify Blizzard shared `DropDownList...Button` font rows.
- Opacity values remain clamped to valid 0-100% values at their input/storage boundary.
- Locale-specific spell/item filter data must not mix localized names between client locales.
- Cooldown-failure animation must not depend on English combat-text parsing.
- Performance work must not trade correctness for lower CPU use. Event/action-driven state must still recover correctly after zoning, reloads, spellbook changes, equipment changes, cooldown resets and missed/ambiguous item-use paths.

### Protocol / Data Model
- `CoolineDB` stores account-wide configuration; `CoolineCharDB` stores per-character state/overrides.
- Appearance settings are account-wide with the established optional per-character behaviour.
- Spell/item filter state is locale-scoped so localized names remain isolated by client locale.
- Supported locale files remain `enUS`, `deDE`, `frFR`, `esES`, `koKR`, `zhCN` and `zhTW`.
- WoW 1.12.1 shared-item cooldown identification remains best-effort in the native 2.1 line where the client cannot reliably identify the exact item. Do not misrepresent that limitation as exact tracking.
- The 3.0 design should prefer stable spell/item identifiers from ClassicAPI where available and avoid carrying forward native scan-based inference solely for compatibility.

### Active Decisions
- Cooline 2.0.0 remains the accepted stable release until 2.1 is user-tested and promoted.
- The next release line is `2.1.0`, focused only on removing unnecessary background CPU/GC/UI work while preserving native-client support and current behaviour.
- After stable 2.1 is released, preserve the exact final native line with tag `v2.1.0` and a permanent `native-2.1` branch before 3.0 replaces it on `main`. Creating the preservation branch immediately after the 2.1 release is preferred; at minimum it must exist before 3.0 promotion.
- After the 2.1 checkpoint, `dev` becomes `3.0.0-dev` and ClassicAPI becomes a required runtime dependency.
- 3.0 is an architectural modernization, not a dual-path compatibility build. Do not retain broad native polling/scanning merely to support non-ClassicAPI clients.
- A Spells/Items options-panel re-layout remains only an optional future idea and is outside both current performance stages unless separately approved.

## Performance Audit Baseline
The 2.0.0 runtime audit found the following avoidable background work:

- `bar` has a permanent `OnUpdate`.
- Every frame calls `Render()`, including when no cooldown is active.
- Every 0.50 seconds the same `OnUpdate` calls `ReconcileAllCooldowns()`.
- `ReconcileAllCooldowns()` walks the full spellbook, every bag slot and all 20 equipment slots, then walks the cooldown registry.
- `SPELL_UPDATE_COOLDOWN`, `SPELLS_CHANGED`, `BAG_UPDATE_COOLDOWN`, `BAG_UPDATE`, `UNIT_INVENTORY_CHANGED` and `PLAYER_ENTERING_WORLD` all route to the same full reconciliation, so spell-only events trigger item scans and item/inventory events trigger spellbook scans.
- Full reconciliations allocate fresh temporary state including `seen`, item candidate tables/records, active-signature tables and cooldown-signature/key strings.
- The persistent `cooldowns` registry retains expired cooldown frames, while the per-frame renderer iterates the whole registry rather than an active-only set.
- Active icons receive repeated frame-level, size, alpha, show and anchor writes every frame even when those properties have not changed.
- `UpdateBarAlpha()` rewrites the root/background/border/label alpha state every frame instead of only on active/inactive transitions or settings changes.
- The options Spell and Item pages create seven row `OnUpdate` handlers each for short highlight flashes. These are lower priority because hidden rows do not represent the same always-on raid/runtime cost, but they should be cleaned up if doing so remains simple and behaviour-preserving.
- Non-English failed-cast fallback can scan the spellbook on a failed-cast message. This is event-bound and lower priority than the permanent/background paths.

The performance objective is not raid-specific. Raid conditions merely make cumulative addon overhead most visible. The goal is to eliminate unnecessary work in all play states, especially idle/background work that compounds with other addons.

## ClassicAPI 3.0 Opportunity
ClassicAPI currently provides capabilities that can remove much of Cooline's native inference/scanning layer:

- `UNIT_SPELLCAST_SUCCEEDED` with `unit, castGUID, spellID, spellName, rank` for successful local-player casts.
- `C_Spell.GetSpellCooldown(spellIdentifier)` for direct cooldown lookup by spell ID/name/link without requiring a spellbook-slot walk.
- `GetItemCooldown(itemInfo)` / `C_Container.GetItemCooldown` for direct item cooldown lookup by item identifier rather than physical slot.
- `BAG_UPDATE_DELAYED` to coalesce multiple bag changes into one per-frame notification.
- `PLAYER_EQUIPMENT_CHANGED(equipmentSlot, hasCurrent)` to identify the changed equipment slot directly.
- `hooksecurefunc` and richer action/macro/item APIs that may allow cleaner item-use observation than replacing global functions.

Before the 3.0 item path is designed, audit every relevant item-use route under ClassicAPI: bag clicks, equipped on-use items/trinkets, action buttons, `/use` macros, conditional macros and any supported client-specific route. Do not delete fallback discovery until exact item identity/cooldown behaviour is demonstrated for the intended routes.

## Recent Relevant Commits
- `adb41f29d3a6bbf940e20a45565ba13a53e21873` — Mark Cooline maintenance mode.
- `282caf36367fe13cb7d25d9f564eabfef6ab8e49` — Migrate development workflow to VanillaTemplate rulebook.
- `0d4f484e4396aa276c7249ab895c6dbfcf92cccc` — Mark Cooline 2.0.0 complete.
- `cdd502226b3e44b27d14fa2c855f0b93ae207c09` — Release Cooline 2.0.0 on `main`.
- Earlier migration/branding history remains in Git history rather than being duplicated here.

## Completed / User-Verified
- Stable/dev branch workflow migration is complete.
- Stable `main` is directly installable and excludes development-only status/workflow documents.
- Addon structure is normalized to `Cooline.toc`, `Cooline.lua`, `locales/` and `artwork/`.
- Client Default bar-font inheritance was user-confirmed.
- The user accepted the migrated addon state and Qiraji-blue Cooline branding as good.
- Stable release `2.0.0` was accepted as the finished functional baseline.
- The performance audit above is analysis only; no runtime delta has yet been made from the accepted 2.0.0 behaviour.

## Implemented / Awaiting Runtime Test
- None from the new 2.1/3.0 performance roadmap yet.
- Some 2.0.0 behaviour was not individually/exhaustively exercised in every path or locale before release; that historical validation debt remains release provenance rather than a standing test obligation.

## Static / Automated Checks
- Static audit confirmed every newly created FontString receives a font/font object before text is assigned.
- Static audit confirmed no writes remain to Blizzard shared `DropDownList...Button` font rows.
- At the workflow-migration baseline, `Cooline.lua`, `README.md`, `artwork/` and `locales/` had identical Git objects on `dev` and stable `main`; only expected TOC development metadata and development documentation differed.
- No new runtime code has been introduced by the roadmap/audit documentation work.

## Current Issues
- Performance architecture: 2.0.0 performs unnecessary permanent per-frame work and broad recurring/event-driven full scans as documented under Performance Audit Baseline.
- WoW 1.12.1 provides limited information for identifying some shared item cooldowns, so affected item identification remains best-effort on the native line.
- Non-English behaviour has not been exhaustively runtime-tested across every supported locale.
- No known active correctness regression in the stable 2.0.0 baseline.

## Testing

### Last Runtime Test
- Version/commit: Stable `2.0.0` at `cdd502226b3e44b27d14fa2c855f0b93ae207c09`.
- Passed: Overall addon state accepted as finished for the 2.0 functional scope; Client Default font inheritance; intended Qiraji-blue Cooline-name branding scope.
- Failed: No currently documented active failure.
- Not tested: Exhaustive per-locale coverage and individual exhaustive runtime validation of every historical 2.0 path.

### Next Runtime Test
- No runtime test is needed for this documentation-only roadmap update.
- The next runtime test belongs to the first coherent 2.1 performance delta.
- 2.1 validation must cover at minimum: startup/reload, spell cooldown start/update/expiry, cooldown resets where available, potion/consumable cooldowns, equipped on-use items/trinkets, shared item cooldown identity, rapid repeated casts, failed-cast pulse animation, zoning/world entry, spellbook changes, equipment/inventory changes, filters, and ensuring cooldowns recover after events that replace the old permanent poll.
- Performance validation should specifically confirm there is no permanent full spell+bag+equipment scan while idle and no permanent renderer when there are no active cooldowns.
- 3.0 requires a separate runtime pass after its ClassicAPI-driven architecture is implemented; successful 2.1 testing does not validate the 3.0 delta.

## Planned / Next Work

### Stage 1 — Native 2.1 performance release
1. Before runtime edits, bump the TOC from `2.0.0-dev` to `2.1.0-dev`.
2. Remove the permanent 0.50-second full `ReconcileAllCooldowns()` poll.
3. Split spell and item reconciliation so events only refresh the domain that can actually have changed.
4. Coalesce bursty/redundant event work where doing so preserves correct Vanilla behaviour.
5. Keep deliberate recovery/full-sync points for startup/world entry and any proven cases where Vanilla events are insufficient.
6. Convert rendering to active-only lifecycle management:
   - renderer enabled only while at least one cooldown needs movement/pulse work;
   - iterate active cooldowns rather than the historical registry;
   - stop the renderer when the final active cooldown expires;
   - avoid redundant `Show`, alpha, size, frame-level and anchor/state writes where possible.
7. Cache/reuse state that is stable between real changes, such as spellbook count/index metadata and normalized filter lookups, where this removes repeated hot-path work without complicating correctness.
8. Reduce avoidable reconciliation garbage after the architectural wins are in place; do not prioritize micro-allocation work ahead of deleting unnecessary scans.
9. Clean up the options-row flash `OnUpdate` handlers only if the change remains simple, isolated and behaviour-preserving.
10. Run static review, Lua 5.0 compatibility/compiler checks available to the project, and targeted user runtime/performance testing.
11. Promote the accepted 2.1 build to `main` as stable `2.1.0`; do not start the 3.0 runtime rewrite before 2.1 is an accepted stable checkpoint.

### Stage 2 — Preserve the final native line
1. Tag the exact stable native release as `v2.1.0`.
2. Preserve that exact native release line on permanent branch `native-2.1`.
3. The branch may be created immediately after 2.1 promotion; regardless, it must exist before 3.0 is promoted over 2.1 on `main`.
4. Treat `native-2.1` as the known-good no-ClassicAPI fallback/reference line. Do not casually merge 3.x ClassicAPI-required architecture into it.

### Stage 3 — ClassicAPI-required 3.0
1. Return to `dev` after the 2.1 release/preservation checkpoint and bump to `3.0.0-dev`.
2. Record ClassicAPI as a required runtime prerequisite in the addon metadata/user documentation and this development contract as appropriate.
3. Audit exact item-use identification across all supported use routes before deleting the native item-discovery path.
4. Replace broad spell discovery with ClassicAPI's exact successful-cast spell IDs and direct `C_Spell.GetSpellCooldown` lookups.
5. Replace physical-slot item cooldown discovery with direct item-ID cooldown lookups wherever exact item identity is available.
6. Prefer `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED` and other precise ClassicAPI events over broad Vanilla inventory notifications.
7. Use `hooksecurefunc`/ClassicAPI action-macro facilities where they provide a cleaner observation path than replacing globals.
8. Carry forward the renderer/lifecycle improvements proven in 2.1, but do not preserve the native scan architecture merely for compatibility.
9. Reassess whether any remaining polling is actually required. Any retained poll must have a documented correctness reason and the narrowest practical scope/frequency.
10. Run full static/Lua compatibility checks plus ClassicAPI-targeted runtime tests. Keep `main` on stable 2.1 until the 3.0 delta is user-tested and accepted.
11. Promote accepted `3.0.0` to `main` only after confirming `v2.1.0` and `native-2.1` preserve the final native release.

## Deferred / Out of Scope
- UI redesign or unrelated feature additions during the 2.1 performance pass.
- Spells/Items options-panel re-layout unless deliberately promoted from idea to active scope later.
- Feature changes disguised as performance work.
- Making ClassicAPI optional in 3.0; the current 3.0 plan intentionally uses it as a required platform dependency so the native compatibility architecture can be removed.
- Exhaustive non-English validation unless a changed path or concrete issue makes it relevant.
- New debug tooling unless required to validate the performance/runtime rewrite.

## Release / Promotion Notes
- Stable `main` currently remains `2.0.0`. It must not be used as the 2.1 or 3.0 development branch.
- Current main-only/release-only content: no extra main-only files. Stable `main` intentionally contains only `Cooline.lua`, stable `Cooline.toc`, `README.md`, `artwork/` and `locales/`; preserve stable TOC Title/Version metadata and do not copy development docs to `main`.
- Known 2.0 validation debt: timeline-overlay, font-preview, locale-filter migration, non-English cooldown-failure matching, opacity clamping and supported-locale behaviour were not each individually/exhaustively exercised in every path or locale before/after the accepted 2.0.0 release. This is historical release provenance, not scheduled maintenance work.
- 2.1 must remain installable without ClassicAPI or any other DLL/client extension.
- 3.0 will require ClassicAPI; that dependency is a deliberate major-version boundary.
- The exact stable 2.1 commit must be tagged/preserved before 3.0 replaces it on `main`.

## Exact Next Step
Begin Stage 1 only. Verify the actual remote `dev` head against this handoff, then bump `Cooline.toc` from `2.0.0-dev` to `2.1.0-dev` before any runtime edit. After the version bump, implement the native performance rewrite starting with removal of the permanent 0.50-second full reconciliation poll and separation of spell versus item reconciliation. Do not begin the ClassicAPI-required 3.0 rewrite until native 2.1 has passed its static/compiler checks, targeted user runtime/performance testing, and stable promotion checkpoint.
