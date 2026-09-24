# Development Progress

## Current
- Branch: `dev`.
- Version: `2.1.2-dev` in `Cooline.toc`.
- Current checked product tree before this status commit: `686aecb040545252492c9da59981beb902a6e3d4`. The current handoff is the commit containing this file on `dev`; verify the actual remote `dev` head before new work.
- Current runtime delta commit: `367fe609596950a34ae8d286388c18679fac7507` (`Finish native 2.1 performance pass`). Cleanup tree `686aecb040545252492c9da59981beb902a6e3d4` is product-identical; the intervening commits only added and removed the temporary Lua 5.0.2 compiler workflow.
- Previously user-tested burst-coalescing runtime delta: `a9c53e8648c6c6d753c7b7327aab746222f0e5ec`, product-identical cleanup tree `554be40272d8a55e6a35cf5b7a1e90625fde8bbd`.
- Previously user-tested runtime implementation: `bcdd907fb9f52d8ce44cdbd2851a86469b0ba727` (`Optimize native cooldown reconciliation and rendering`), runtime-identical to checked tree `81331997c059320395838598d68adf5724ee2383`.
- Stable baseline: `2.0.0` at `cdd502226b3e44b27d14fa2c855f0b93ae207c09` on `main`.
- Goal: complete the native WoW 1.12.1 performance-focused `2.1.x` line first, release the final accepted `2.1.x` revision, preserve that native line, then develop `3.0.0` with ClassicAPI as a required runtime dependency.
- Current scope boundary: Stage 1 only. At the user's request, the three remaining native optimizations were deliberately batched into one final `2.1.2-dev` delta to avoid repeated client restarts/microtests. Implementation/static/compiler work for Stage 1 is complete; this combined delta is not yet user runtime-tested. Quantitative CPU/performance improvement remains unmeasured because the runtime environment has too many confounding variables. ClassicAPI-required 3.0 remains blocked until this final native delta passes, is promoted, tagged and preserved.

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
- The next release line is native `2.1.x`, focused only on removing unnecessary background CPU/GC/UI work while preserving native-client support and current behaviour. Each addon-affecting development revision increments the patch version (`2.1.1-dev`, `2.1.2-dev`, ...); the stable release uses the final accepted numeric `2.1.x` version without `-dev`.
- After stable 2.1 is released, preserve the exact final native revision with a matching `v2.1.x` tag and a permanent `native-2.1` branch before 3.0 replaces it on `main`. Creating the preservation branch immediately after the 2.1 release is preferred; at minimum it must exist before 3.0 promotion.
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
- `686aecb040545252492c9da59981beb902a6e3d4` — Remove temporary Lua 5.0.2 check after the final native Stage 1 delta passed.
- `8c2799c4fd6067a836cc1454aedee87a16c57c1e` — Add temporary Lua 5.0.2 compiler workflow for the final native Stage 1 delta.
- `367fe609596950a34ae8d286388c18679fac7507` — Finish native 2.1 performance pass: spellbook/filter caching, reconciliation scratch reuse/allocation cleanup, and flash-only filter-row `OnUpdate`.
- `b8fdd8d7113a9a386cdf6bf1533b03e69ae31d58` — Bump Cooline to `2.1.2-dev` before the combined final Stage 1 runtime edit.
- `2b002af395228c0440c458cd583a1ad64e8b5e0c` — Bump Cooline to `2.1.1-dev` to align the current product with the revised versioning rule; runtime Lua is unchanged from the user-passed burst-coalescing checkpoint.
- `997381465eac7c361b26a1781574d1ef1e8a9cd6` — Sync the revised canonical development rulebook from VanillaTemplate.
- Canonical VanillaTemplate rulebook revision: `b37a6c56c15a58d8001771b3e4947643e74753c1` — require a numeric version bump for every addon-affecting code/runtime/loader/metadata revision; documentation-only/status-only commits may retain the current version.
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
- TOC was originally bumped from `2.0.0-dev` to `2.1.0-dev` before the first 2.1 runtime work. After the canonical versioning rule was revised, the current metadata was advanced to `2.1.1-dev` to represent the already-landed burst-coalescing product revision. Future addon-affecting revisions must increment again before/as they land.
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
- This burst-coalescing delta is statically/compiler checked and user runtime-tested. Spell, consumable, on-use trinket, inventory/equipment burst and filter-update behaviour remained correct in the exercised paths.
- At the user's explicit request, the remaining Stage 1 candidates were batched into the final `2.1.2-dev` delta rather than validated one by one.
- Stable spellbook caching is implemented: spell names/textures/slots are cached and rebuilt on startup/world-entry and when `SPELLS_CHANGED` marks the cache dirty; ordinary cooldown reconciliation no longer rescans spell names/textures.
- Stable filter lookup caching is implemented: locale-scoped spell/item blacklist and whitelist arrays are mirrored into uppercase lookup sets, refreshed after filter mutations, so cooldown scans no longer linearly scan/uppercase the filter lists for each candidate.
- Reconciliation allocation cleanup is implemented: spell/item `seen` maps, item candidate records, and active item-signature scratch state are reused across reconciliations; item candidate records form a persistent pool while shared-cooldown lock semantics remain unchanged.
- Filter-row flash cleanup is implemented: the seven spell rows and seven item rows no longer carry permanent `OnUpdate` handlers. A row installs the shared flash driver only while its 0.55-second highlight is active and removes it when the flash ends.
- Stage 1 implementation is now complete pending the consolidated `2.1.2-dev` runtime pass.
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
- Final Stage 1 static review confirmed spellbook name/texture API scans are centralized in the cache rebuild; per-reconcile `seen` table creation and item-candidate table creation are removed; shared item-signature locking still uses the same signature/name rules; and filter-row `OnUpdate` is attached only by `FlashFilterRow`.
- GitHub Actions run `36033235221` / job `107746908050` successfully built the official Lua 5.0.2 compiler and ran `luac -p` against `Cooline.lua` and all locale Lua files for the final combined Stage 1 delta.
- The temporary compiler workflow was removed after that pass. Comparing runtime commit `367fe609596950a34ae8d286388c18679fac7507` to cleanup tree `686aecb040545252492c9da59981beb902a6e3d4` shows no product-file differences.

## Current Issues
- The first `2.1.0-dev` performance delta has passed the targeted functional runtime paths exercised so far; no runtime regression was reported in those paths.
- The burst-event coalescing delta at `a9c53e8648c6c6d753c7b7327aab746222f0e5ec` passed user runtime testing. A one-frame delay is intentional only for broad spell/item event bursts; direct recovery and world-entry paths remain immediate.
- The final combined `2.1.2-dev` Stage 1 delta at `367fe609596950a34ae8d286388c18679fac7507` is implemented and checked but not yet user runtime-tested.
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

### Last Runtime Test — Burst Coalescing
- Version/commit: `2.1.0-dev` as tested, runtime delta `a9c53e8648c6c6d753c7b7327aab746222f0e5ec`, product-identical cleanup tree `554be40272d8a55e6a35cf5b7a1e90625fde8bbd`. Current `2.1.1-dev` changes only TOC version metadata and contains the same runtime Lua.
- Passed: ordinary spell cooldown behaviour, potion/consumable cooldowns, equipped on-use trinket cooldowns, inventory/equipment changes including trinket swapping, and adding/removing filters all behaved the same as the prior tested checkpoint.
- Rapid/spam-click failure-pulse behaviour was observed to appear only after a possible GCD boundary in some attempts. This is not attributed to burst coalescing: the failed-cast pulse still routes directly from `CHAT_MSG_SPELL_FAILED_LOCALPLAYER` to `TriggerCooldownPulse` and was not queued/coalesced by this delta. Treat the exact client/event timing as an existing/uncertain Vanilla behaviour unless a separate targeted investigation proves otherwise.
- Failed: No new regression identified.
- Performance result: no reliable quantitative before/after judgment; environmental variability remains too high.

### Next Runtime Test
- Perform one consolidated in-game regression pass on current `2.1.2-dev`; this is the final native Stage 1 validation gate.
- In one session: verify a few ordinary spell cooldowns including rapid/spam input; use a potion/consumable; use and swap an on-use trinket; move inventory items; add/remove one spell filter and one item filter; confirm the filter-row highlight still animates and disappears normally.
- Do one `/reload` or instance/loading-screen transition with an active cooldown to cover cache rebuild/world-entry recovery.
- No quantitative CPU comparison is required; report any visible delay, missing/stale cooldown, wrong shared-item identity, filter mismatch, stuck highlight, Lua error or other behavioural regression.
- If this consolidated pass succeeds, Stage 1 is complete. Promote this exact native runtime to stable `2.1.2`, tag `v2.1.2`, preserve it on `native-2.1`, then begin the documented ClassicAPI-required `3.0.0-dev` line.
- Do not add further native optimization work unless this runtime pass exposes a concrete regression.

## Planned / Next Work

### Stage 1 — Native 2.1 performance release
1. **Implemented:** bump the TOC from `2.0.0-dev` to `2.1.0-dev` before runtime edits.
2. **Implemented:** remove the permanent 0.50-second full `ReconcileAllCooldowns()` poll.
3. **Implemented:** split spell and item reconciliation so events and filter changes refresh only the relevant domain.
4. **Implemented for the first checkpoint:** keep deliberate startup/world-entry full-sync points and add bounded item-only recovery after directly captured bag/equipped item use.
5. **Implemented for the first checkpoint:** convert rendering to active-only lifecycle management, disable the renderer when idle, iterate only active cooldowns, and avoid redundant `Show`, alpha, size and frame-level writes.
6. **Checked:** complete static review and real Lua 5.0.2 compiler pass.
7. **Passed:** targeted user runtime testing confirmed the exercised spell, potion, rapid-input, on-use trinket, reload recovery, equipment-change, failed-cast pulse and filter-update paths. Quantitative performance improvement was not measurable reliably in the user's environment.
8. **Implemented/checked/passed:** safe burst-event coalescing. Same-frame broad spell events now collapse to one spell reconciliation and same-frame broad item/inventory events to one item reconciliation; immediate recovery/world-entry/user-action paths are preserved. User testing found no new regression in the exercised spell/item/filter/equipment paths.
9. **Implemented/checked, awaiting one consolidated runtime pass:** `2.1.2-dev` batches the final three native candidates by explicit user decision: stable spellbook/filter caching, reconciliation scratch/allocation reuse, and flash-only options-row `OnUpdate`.
10. **Next:** run the single consolidated `2.1.2-dev` runtime pass above. Do not add more native optimization work unless it exposes a concrete regression.
11. After a pass, promote the exact accepted native runtime to stable `2.1.2`, tag `v2.1.2`, preserve it on `native-2.1`, then move `dev` to `3.0.0-dev` for ClassicAPI-required development.

### Stage 2 — Preserve the final native line
1. For the current final Stage 1 plan, tag the accepted native release as `v2.1.2`.
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
11. Promote accepted `3.0.0` to `main` only after confirming the final native `v2.1.x` tag and `native-2.1` branch preserve the exact stable native release.

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
- The exact stable final `2.1.x` commit must be tagged with its matching version and preserved on `native-2.1` before 3.0 replaces it on `main`.

## Exact Next Step
Runtime-test the combined final native Stage 1 `2.1.2-dev` delta using **Next Runtime Test** above. Runtime implementation commit: `367fe609596950a34ae8d286388c18679fac7507`; checked cleanup tree: `686aecb040545252492c9da59981beb902a6e3d4`, product-identical and Lua 5.0.2 compiler-passed. If the consolidated runtime pass succeeds, immediately prepare/publish stable `2.1.2`, tag `v2.1.2`, preserve the exact release on `native-2.1`, and only then begin `3.0.0-dev` ClassicAPI work.


