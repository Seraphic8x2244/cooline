# Development Progress

## Current
- Branch: `dev`.
- Version: `2.1.0-dev` in `Cooline.toc`.
- Current checked product-code tree before this status commit: `554be40272d8a55e6a35cf5b7a1e90625fde8bbd`. The current handoff is the commit containing this file on `dev`; verify the actual remote `dev` head before new work.
- Current runtime delta commit: `a9c53e8648c6c6d753c7b7327aab746222f0e5ec` (`Coalesce cooldown event bursts`). The product tree at cleanup commit `554be40272d8a55e6a35cf5b7a1e90625fde8bbd` is runtime-identical to this commit; the intervening commits only added and removed the temporary Lua 5.0.2 workflow.
- Previously user-tested runtime implementation: `bcdd907fb9f52d8ce44cdbd2851a86469b0ba727` (`Optimize native cooldown reconciliation and rendering`), runtime-identical to checked tree `81331997c059320395838598d68adf5724ee2383`.
- Stable baseline: `2.0.0` at `cdd502226b3e44b27d14fa2c855f0b93ae207c09` on `main`.
- Goal: complete a native WoW 1.12.1 performance-focused `2.1.0` release first, preserve that native line, then develop `3.0.0` with ClassicAPI as a required runtime dependency.
- Current scope boundary: Stage 1 only. The first native 2.1 performance delta passed targeted user functional runtime testing. The follow-up safe burst-event coalescing delta is implemented, statically reviewed and Lua 5.0.2 compiler-checked, but has not yet been user runtime-tested. Quantitative CPU/performance improvement remains unmeasured because the runtime environment has too many confounding variables. Do not begin another Stage 1 optimization or ClassicAPI-required 3.0 work until this delta has a clear runtime result.

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
- `554be40272d8a55e6a35cf5b7a1e90625fde8bbd` — Remove temporary Lua 5.0.2 check after the burst-coalescing delta passed.
- `9a28d83f3848c1adccd5c553cee0025f259e246e` — Add temporary Lua 5.0.2 compiler workflow for the burst-coalescing delta.
- `a9c53e8648c6c6d753c7b7327aab746222f0e5ec` — Coalesce cooldown event bursts to one spell/item reconciliation per frame while preserving immediate startup/world-entry and explicit user-action paths.
- `24d76780321736a179c952f089cc3f5defc2cfa8` — Record successful instance-zoning recovery test for the first 2.1 checkpoint.
- `570ab058934a1841f5ba7c9a6a777eb35e76bb4f` — Record first 2.1 runtime checkpoint.
- `ccee0d3ecb5a4e401248e001c46a80f7045d3796` — Update Cooline 2.1 performance handoff; starting head for the first user runtime checkpoint.
- `81331997c059320395838598d68adf5724ee2383` — Remove temporary Lua 5.0.2 CI check; product tree remains identical to the runtime implementation commit.
- `8755b19a403a5708b381ca4cff528c1d8426e04a` — Fix isolated Lua 5.0.2 compiler check; successful GitHub Actions run verified and compiled the current addon with the official Lua 5.0.2 compiler.
- `bcdd907fb9f52d8ce44cdbd2851a86469b0ba727` — Optimize native cooldown reconciliation and rendering.
- `553fabbb6917e2edd1adbd82fb68825c404df8b3` — Start Cooline 2.1 development by bumping the TOC to `2.1.0-dev` before runtime edits.
- `2cb5543791ce65b039dad6005db12e6f46be6f93` — Plan Cooline 2.1 and 3.0 performance roadmap; previous handoff.
- `cdd502226b3e44b27d14fa2c855f0b93ae207c09` — Release Cooline 2.0.0 on `main`.
- Earlier migration/branding history remains in Git history rather than being duplicated here.

## Completed / User-Verified
- Stable/dev branch workflow migration is complete.
- Stable `main` is directly installable and excludes development-only status/workflow documents.
- Addon structure is normalized to `Cooline.toc`, `Cooline.lua`, `locales/` and `artwork/`.
- Client Default bar-font inheritance was user-confirmed.
- The user accepted the migrated addon state and Qiraji-blue Cooline branding as good.
- Stable release `2.0.0` was accepted as the finished functional baseline.
- First `2.1.0-dev` checkpoint user-verified on the runtime-identical product tree from `81331997c059320395838598d68adf5724ee2383` / implementation commit `bcdd907fb9f52d8ce44cdbd2851a86469b0ba727`: ordinary spell cooldowns, potion/consumable cooldown, rapid/spam-click casting, equipped on-use trinket cooldown, `/reload` recovery of an active cooldown, trinket swapping with a 30-second cooldown discovered on equip, failed-cast pulse behaviour, adding/removing filters all worked correctly, and an active cooldown survived an instance zoning/loading-screen transition.

## Implemented / Current Stage 1 State
- TOC was bumped from `2.0.0-dev` to `2.1.0-dev` in its own commit before any runtime edit.
- Removed the permanent 0.50-second full `ReconcileAllCooldowns()` poll; there is no longer an idle periodic spellbook+bag+equipment reconciliation.
- Split reconciliation into spell-only and item-only paths. Spell events/filter changes no longer trigger item scans, and bag/inventory events/filter changes no longer trigger spellbook scans.
- Full reconciliation is retained deliberately for startup and `PLAYER_ENTERING_WORLD` recovery.
- Added an active-only cooldown set. Per-frame rendering now walks only active cooldowns rather than the historical frame registry.
- The runtime `OnUpdate` is installed only while cooldown movement/pulse work is active or during the bounded item-use recovery window, and it is removed when neither is needed.
- Directly captured bag/equipped item uses start a short item-only retry window so removing the old permanent poll does not remove recovery for cooldown state that becomes visible shortly after the use call.
- Removed redundant per-frame `Show`, alpha, frame-level and size writes where state has not changed; alpha updates are now transition/settings driven while timeline position still updates as active cooldowns move.
- Existing SavedVariables names/data shape, options UI, filters, native item identity semantics, cooldown pulse behaviour and WoW 1.12.1 target remain unchanged by design.
- Follow-up burst-event coalescing is implemented in `a9c53e8648c6c6d753c7b7327aab746222f0e5ec`: repeated `SPELL_UPDATE_COOLDOWN`/`SPELLS_CHANGED` events in one frame queue one spell reconciliation, and repeated `BAG_UPDATE_COOLDOWN`/`BAG_UPDATE`/`UNIT_INVENTORY_CHANGED` events queue one item reconciliation.
- The queued work is serviced by the existing runtime driver on the next frame; there is no arbitrary timed throttle. Pending spell/item work itself keeps the driver alive until serviced.
- If an item-retry deadline and a queued item reconciliation land on the same frame, the queued scan is reused instead of performing the item reconciliation twice.
- `PLAYER_ENTERING_WORLD` still clears pending burst flags and performs the deliberate immediate full reconciliation. Startup, filter changes and direct item-use recovery remain immediate/non-coalesced as before.
- This burst-coalescing delta is statically/compiler checked but not yet user runtime-tested.
- Remaining Stage 1 candidates after this delta are stable spell/filter caching, reconciliation-allocation cleanup, and the optional filter-row flash `OnUpdate` cleanup. Do not begin one until the burst-coalescing delta receives a clear runtime result.
- Some 2.0.0 behaviour was not individually/exhaustively exercised in every path or locale before release; that historical validation debt remains release provenance rather than a standing test obligation.

## Static / Automated Checks
- Diff/static review confirmed the old `SCAN_INTERVAL` / `scanElapsed` permanent polling path is absent.
- Static review confirmed full reconciliation remains limited to startup and world-entry recovery; spell and item events route to their own domains.
- Static review confirmed `Render()` iterates `activeCooldowns`, not the persistent historical `cooldowns` registry.
- Static review confirmed the runtime driver has both explicit enable and disable paths and there is no permanent anonymous bar `OnUpdate`.
- Current top-level local declaration count remains comfortably below the Lua 5.0 compiler local limit; the real compiler check below is authoritative.
- GitHub Actions run `36008965628` / job `107664388316` successfully downloaded the official Lua 5.0.2 source archive, verified SHA-256 `a6c85d85f912e1c321723084389d63dee7660b81b8292452b190ea7190dd73bc`, built `Lua 5.0.2`, and ran `luac -p` successfully against `Cooline.lua` and all seven locale Lua files.
- The preceding temporary CI attempt failed only because that workflow could not checkout the separate VanillaTemplate repository with its token; it did not reach the compiler step and is not a code failure.
- The temporary compiler workflow was removed after the successful pass. Comparing runtime implementation `bcdd907fb9f52d8ce44cdbd2851a86469b0ba727` to checked cleanup tree `81331997c059320395838598d68adf5724ee2383` shows no product-file differences.
- The complete product-tree delta from the previous handoff `2cb5543791ce65b039dad6005db12e6f46be6f93` is limited to `Cooline.lua` plus the intended `Cooline.toc` development-version bump.
- Burst-coalescing diff/static review confirmed only `Cooline.lua` changed: two pending-domain flags, two queue helpers, next-frame servicing in the existing runtime driver, item-retry duplicate-scan avoidance, event routing to the queue helpers, and pending-flag clearing before immediate `PLAYER_ENTERING_WORLD` full reconciliation.
- GitHub Actions run `36029076224` / job `107732927209` successfully verified the official Lua 5.0.2 source archive checksum `a6c85d85f912e1c321723084389d63dee7660b81b8292452b190ea7190dd73bc`, built Lua 5.0.2, and ran `luac -p` successfully against `Cooline.lua` and all locale Lua files for the burst-coalescing delta.
- The temporary compiler workflow was removed after the pass. Comparing runtime commit `a9c53e8648c6c6d753c7b7327aab746222f0e5ec` to cleanup tree `554be40272d8a55e6a35cf5b7a1e90625fde8bbd` shows no product-file differences.

## Current Issues
- The first `2.1.0-dev` performance delta has passed the targeted functional runtime paths exercised so far; no runtime regression was reported in those paths.
- The new burst-event coalescing delta at `a9c53e8648c6c6d753c7b7327aab746222f0e5ec` is checked but not yet user runtime-tested. A one-frame delay is now intentional only for the broad spell/item event bursts; direct recovery and world-entry paths remain immediate.
- Quantitative CPU/performance improvement is not proven by user measurement because too many environmental variables make an informal before/after comparison unreliable. The architectural reductions remain statically established: no permanent 0.50-second full reconciliation, no permanent idle renderer, active-only rendering, and domain-split reconciliation.
- Zoning/world-entry recovery was subsequently user-verified: an active cooldown survived an instance swap/loading-screen transition. An explicit cooldown-reset case, spellbook-change recovery, and exhaustive shared-item cooldown identity remain untested coverage, not known failures.
- WoW 1.12.1 provides limited information for identifying some shared item cooldowns, so affected item identification remains best-effort on the native line.
- Non-English behaviour has not been exhaustively runtime-tested across every supported locale.
- No known active correctness regression exists in the stable `2.0.0` baseline or in the exercised `2.1.0-dev` checkpoint paths.

## Testing

### Last Runtime Test
- Version/commit: `2.1.0-dev` on the runtime-identical product tree at `81331997c059320395838598d68adf5724ee2383`, implementation commit `bcdd907fb9f52d8ce44cdbd2851a86469b0ba727`; the test was conducted from handoff/status head `ccee0d3ecb5a4e401248e001c46a80f7045d3796`.
- Passed: ordinary spell cooldowns; potion/consumable cooldown; rapid/spam-click behaviour; equipped on-use trinket cooldown; `/reload` preserved/reconstructed an active cooldown; trinket swapping correctly discovered a 30-second cooldown on equip; failed-cast pulse; adding/removing filters updated the timeline correctly; active cooldown survived an instance zoning/loading-screen transition.
- Failed: No failure reported in the exercised paths.
- Performance result: no reliable quantitative before/after judgment; environmental variability is too high. Do not claim a measured CPU improvement from this test.
- Not tested in this pass: an explicit cooldown-reset case, spellbook-change recovery, exhaustive shared-item cooldown identity, exhaustive per-locale coverage.

### Next Runtime Test
- Runtime-test the burst-event coalescing delta on current `2.1.0-dev`.
- Confirm ordinary spell cooldowns still appear/update promptly, including rapid repeated/spam-click casts.
- Confirm potion/consumable and equipped on-use trinket cooldowns still appear correctly.
- Create inventory/equipment event bursts by moving items and swapping a trinket; confirm cooldown identity/state remains correct and no stale icon appears.
- Confirm adding/removing spell and item filters still takes effect immediately; these paths were deliberately not coalesced.
- A quick `/reload` or instance transition with an active cooldown is useful regression coverage but the world-entry full reconciliation itself was not changed.
- No additional Stage 1 optimization should begin until this delta has a clear runtime result.
- A true cooldown-reset case remains optional opportunistic coverage; spellbook-change recovery and exhaustive shared-item identity are also untested but are not known failures.
- 3.0 remains blocked until the final native 2.1 Stage 1 state is user-tested, promoted and preserved.

## Planned / Next Work

### Stage 1 — Native 2.1 performance release
1. **Implemented:** bump the TOC from `2.0.0-dev` to `2.1.0-dev` before runtime edits.
2. **Implemented:** remove the permanent 0.50-second full `ReconcileAllCooldowns()` poll.
3. **Implemented:** split spell and item reconciliation so events and filter changes refresh only the relevant domain.
4. **Implemented for the first checkpoint:** keep deliberate startup/world-entry full-sync points and add bounded item-only recovery after directly captured bag/equipped item use.
5. **Implemented for the first checkpoint:** convert rendering to active-only lifecycle management, disable the renderer when idle, iterate only active cooldowns, and avoid redundant `Show`, alpha, size and frame-level writes.
6. **Checked:** complete static review and real Lua 5.0.2 compiler pass.
7. **Passed:** targeted user runtime testing confirmed the exercised spell, potion, rapid-input, on-use trinket, reload recovery, equipment-change, failed-cast pulse and filter-update paths. Quantitative performance improvement was not measurable reliably in the user's environment.
8. **Implemented/checked, awaiting runtime test:** safe burst-event coalescing. Same-frame broad spell events now collapse to one spell reconciliation and same-frame broad item/inventory events to one item reconciliation; immediate recovery/world-entry/user-action paths are preserved.
9. **Next:** run the targeted burst-coalescing runtime test above. If it passes, evaluate the remaining candidates individually: stable spellbook/filter lookup caching, avoidable reconciliation garbage, and optional options-row flash `OnUpdate` cleanup. Select only another change whose expected benefit is concrete and whose correctness risk is low.
10. Re-run static/Lua 5.0.2 checks and targeted runtime validation for any additional Stage 1 delta.
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
Runtime-test the safe burst-event coalescing delta on current `2.1.0-dev`, using **Next Runtime Test** above. The runtime implementation is `a9c53e8648c6c6d753c7b7327aab746222f0e5ec`; cleanup tree `554be40272d8a55e6a35cf5b7a1e90625fde8bbd` is product-identical and has already passed static review plus the real Lua 5.0.2 compiler check. Do not begin stable spell/filter caching, reconciliation-allocation cleanup, options-row `OnUpdate` cleanup, or ClassicAPI-required 3.0 work until this burst-coalescing delta has a clear user runtime result.


