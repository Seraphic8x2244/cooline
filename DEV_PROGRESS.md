# Development Progress

## Current
- Branch: `dev`.
- Version: `3.0.3-dev` in `Cooline.toc`.
- Current dev branch head before this status commit: `dc340c628954fe93509fdb57696f37caf0294678` (`Guard Cooline exact item cooldown transitions`). The current handoff is the commit containing this file on `dev`; verify the actual remote `dev` head before new work.
- Stable release: `2.1.2` on `main` at `d4fc1a5a0c697cdc8d7534a2942f6fa2dc94c505` (`Release Cooline 2.1.2`). Its `Cooline.lua` blob exactly matches the user-tested final native runtime.
- Permanent native preservation branch: `native-2.1` at the exact same stable commit `d4fc1a5a0c697cdc8d7534a2942f6fa2dc94c505`.
- The planned lightweight tag `v2.1.2` is not yet created because the available GitHub connector exposes branch/ref movement but not tag creation. Do not misstate it as existing.
- ClassicAPI audit source: `Seraphic8x2244/ClassicAPI` `master` at `7ab32df2aadc2171100aac859154085fcaed56b2`.
- Goal: develop `3.0.x` as a ClassicAPI-required architectural rewrite while preserving the tested renderer/UI/SavedVariables behaviour from stable native `2.1.2`.
- Current scope boundary: 2.1 is finished/released/preserved. 3.0 Stage 3 now has its first ClassicAPI-required runtime implementation through `3.0.3-dev`: exact successful-cast spellID tracking and exact item-use observation are implemented for every route proven by the audit. Native item discovery is deliberately retained only as transitional recovery / ambiguity coverage, especially for action-bar bag-instance entries whose itemID ClassicAPI still does not expose. The 3.0 runtime delta is not yet user-tested.

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
- Stable `main` is now `2.1.2` at `d4fc1a5a0c697cdc8d7534a2942f6fa2dc94c505`; the exact same commit is preserved on `native-2.1`.
- `dev` is now the ClassicAPI-required `3.0.x` line. It is not a dual-path compatibility build.
- ClassicAPI is a hard prerequisite for 3.0. Detect it via `CLASSIC_API_VERSION` and document the dependency explicitly; do not keep broad native scanning merely to support clients without the DLL.
- Every addon-affecting 3.0 development revision must bump the patch version under the rulebook. The first runtime delta correctly bumped to `3.0.1-dev`; two correctness revisions then bumped to `3.0.2-dev` and `3.0.3-dev`. Continue bumping the patch for every later addon-affecting revision.
- Preserve existing SavedVariables compatibility, filter behaviour, renderer/lifecycle improvements, visual layout, failed-cast pulse intent and user-facing options unless a ClassicAPI-driven architectural change explicitly requires otherwise.
- Do not delete the native item-discovery path until the exact use-route matrix is resolved for bag clicks, equipped items, action buttons, item bindings, ordinary macros and supported conditional/custom macro routes.
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

## ClassicAPI 3.0 Audit

Audit source: `Seraphic8x2244/ClassicAPI` `master` at `7ab32df2aadc2171100aac859154085fcaed56b2`.

Confirmed capabilities:
- `UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID, spellName, rank)` provides exact successful-cast spell identity.
- `C_Spell.GetSpellCooldown(spellIdentifier)` returns direct cooldown data without a spellbook-slot scan.
- `GetItemCooldown(itemInfo)` / `C_Container.GetItemCooldown(itemID)` query an item's ON_USE spell cooldown directly by item identity; no physical bag/equipment slot is required.
- `C_Item.GetItemGUID(itemLocation)` returns a per-instance GUID stable across bag/equipment moves during the session; `C_Item.GetItemLocation(itemGUID)` resolves that same instance's current location; `C_Item.GetItemID(itemLocation)` provides the itemID.
- `C_Container.GetContainerItemID(bag, slot)` provides direct bag-slot item IDs.
- `BAG_UPDATE_DELAYED` and `PLAYER_EQUIPMENT_CHANGED(equipmentSlot, hasCurrent)` provide narrower inventory/equipment change signals.
- `hooksecurefunc` provides post-call observation without replacing the original global.
- `GetActionInfo(slot)` distinguishes action-bar spells/macros/items. Item actions stored by itemID return that ID, but item actions stored as a bag-instance currently return `"item", nil`; therefore action-slot inspection alone cannot guarantee exact identity for every item action.
- ClassicAPI exposes `C_Item.UseItemByName(itemInfo [, unit])`; it can bypass stock `UseContainerItem`, so 3.0 must account for it rather than assuming hooks on native bag/inventory use functions observe every item activation.
- ClassicAPI exposes `GetMacroSpell` for spell macros, but no equivalent `GetMacroItem` surface was found in the audited API. Item/macro identity therefore needs route-specific handling rather than a blanket macro lookup assumption.

Design implications:
- Spell tracking can become exact and cast-driven: successful player cast -> exact spellID -> direct cooldown lookup -> existing renderer.
- Item cooldown state should be keyed by stable itemID for cooldown semantics, with item GUID/location used when the exact physical instance matters for use observation across slot moves.
- Native shared-cooldown signature/name locking should be removed only after exact item-use observation is proven for all intended routes.
- The existing 2.1 renderer/lifecycle optimizations remain valuable and should be retained; the broad native discovery scans are the part intended for replacement.

### Stage 3 Item-Use Route Matrix Checkpoint
Audit completed against ClassicAPI `7ab32df2aadc2171100aac859154085fcaed56b2` plus the currently supported SuperCleveRoidMacros conditional `/use` path.

- **Stock bag use:** `UseContainerItem(bag, slot)`. The call exposes an exact physical location; ClassicAPI can resolve exact itemID/GUID from that location. Observation must preserve pre-use identity because a consumed/moved item cannot be assumed to remain in the slot after execution.
- **Stock equipped use:** `UseInventoryItem(slot)`. The inventory slot is exact; ClassicAPI can resolve the equipped instance's itemID/GUID from `{equipmentSlotIndex=slot}`.
- **ClassicAPI named/bound item use:** `C_Item.UseItemByName(itemInfo [, unit])` directly calls the engine item-use primitive after locating the first matching bag item and explicitly bypasses `UseContainerItem`. Direct `ITEM ...` bindings route through this same function, so this surface must be observed separately.
- **Action-bar item-by-ID:** `UseAction(slot)` + `GetActionInfo(slot)` returns `"item", itemID`; exact itemID cooldown observation is available without a bag/equipment scan.
- **Action-bar bag-instance item:** `UseAction(slot)` + `GetActionInfo(slot)` currently returns `"item", nil`. ClassicAPI documents that the action descriptor stores a bag-instance key whose itemID mapping is not yet exposed. Cooline therefore cannot prove exact itemID/GUID for this route with the current public API.
- **Direct item bindings:** ClassicAPI's binding dispatcher executes `ITEM <arg>` via `C_Item.UseItemByName`; covered by the named-use route above.
- **Ordinary/saved macro execution:** ClassicAPI macro execution falls back to the stock chat parser line-by-line; item-use slash handlers therefore ultimately depend on the active `SlashCmdList.USE` implementation. Cooline should observe the actual item-use APIs, not macro text, so aliases/conditionals remain transparent.
- **Supported conditional/custom `/use`:** current SuperCleveRoidMacros `DoUse` uses `UseInventoryItem` for equipped matches and `C_Item.UseItemByName` for bag matches. pfUI/SCRM macro integration replaces `SlashCmdList.USE` with the same route. These paths are therefore covered by observing those concrete use APIs.
- **ClassicAPI secure action buttons:** `type="item"` routes either to `UseContainerItem` for explicit bag/slot attributes or `C_Item.UseItemByName`; `type="action"` routes to `UseAction`; `type="macro"` runs through the same macro execution path. Unknown custom verbs may execute arbitrary addon code and are covered only when they eventually call one of the observed item-use surfaces.

Smallest complete strategy with the current APIs:
1. Use exact location capture for `UseContainerItem` / `UseInventoryItem`; retain GUID alongside itemID where a physical instance must be followed across moves.
2. Observe `C_Item.UseItemByName` independently; use exact itemID whenever the argument resolves directly and preserve the existing native fallback until name/instance resolution is proven for all cases.
3. Observe `UseAction`; use exact `GetActionInfo` itemID when present.
4. **Do not remove native item discovery for `UseAction` bag-instance entries while `GetActionInfo` returns nil itemID.** A truly scan-free exact implementation requires a ClassicAPI addition that exposes the action's bag-instance itemID and preferably item GUID/location.
5. Capture use identity before execution wherever consuming/moving the item can destroy the evidence. Post-hooks are acceptable only where the exact identity is guaranteed to survive the call; the current implementation therefore uses pre-call wrappers for location-backed use, `C_Item.UseItemByName`, and `UseAction`.

## Recent Relevant Commits
- `dc340c628954fe93509fdb57696f37caf0294678` — Guard exact item observation against unchanged pre-existing/shared cooldowns; preserve one legacy recovery scan only when an exact route fails to surface a new cooldown; bump to `3.0.3-dev`.
- `0063fada832d47eae5e103ce3e43c1b65e79ccf2` — Harden exact use capture: pre-capture `C_Item.UseItemByName` / `UseAction` before consumables can disappear and restrict successful spell events to strict player spellbook entries; bump to `3.0.2-dev`.
- `fc949e6791b5ac1e23f6b7d77ac39e0db922b129` — Implement the first Cooline 3.0 exact cooldown observation runtime: hard ClassicAPI dependency, exact spellID path, exact location/itemID/GUID item observation, narrow ClassicAPI events and retained ambiguous native fallback; bump to `3.0.1-dev`.
- `7efd41b9f687fdac8a380252b65ef64f16fa6b80` — Document the completed Stage 3 item-use route audit and the unresolved ClassicAPI bag-instance action identity gap.
- `225f984253a26ea95e3888021a8e05135971ac01` — Start Cooline 3.0 development; bump `dev` metadata to `3.0.0-dev` after native release/preservation.
- `d4fc1a5a0c697cdc8d7534a2942f6fa2dc94c505` — Release Cooline `2.1.2` on `main`; exact user-tested Lua runtime with stable TOC metadata. `native-2.1` points to this same commit.
- `c0b99ad8fae334ea978e669bb938e83682c94383` — Record final Cooline 2.1 runtime pass before promotion.
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
- TOC was originally bumped from `2.0.0-dev` to `2.1.0-dev` before the first 2.1 runtime work. After the canonical versioning rule was revised, burst coalescing was represented as `2.1.1-dev`; the combined final native Stage 1 runtime delta was then correctly bumped to `2.1.2-dev` before the code edit.
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
- Stage 1 implementation and consolidated `2.1.2-dev` runtime validation are complete. The user reports the final build is working very well with no new regression.
- Some 2.0.0 behaviour was not individually/exhaustively exercised in every path or locale before release; that historical validation debt remains release provenance rather than a standing test obligation.

## Static / Automated Checks
- 3.0 Stage 3 source audit verified the exact ClassicAPI surfaces used by the implementation: `UNIT_SPELLCAST_SUCCEEDED`, `C_Spell.GetSpellCooldown`, strict `IsSpellKnown`, `C_Item` itemID/GUID/name/icon helpers, `GetItemCooldown`, `GetActionInfo`, `BAG_UPDATE_DELAYED` and `PLAYER_EQUIPMENT_CHANGED`.
- 3.0 implementation static review verified that bag/equipped uses capture itemID+GUID before execution; `C_Item.UseItemByName` and `UseAction` are pre-captured; item-by-ID actions take the exact path; bag-instance actions explicitly retain native discovery; exact item cooldowns require a post-use cooldown-signature transition; and an unchanged pre-existing shared cooldown is not re-attributed.
- 3.0 spell static review verified successful player casts use the exact ClassicAPI spellID and direct cooldown query, while `IsSpellKnown(spellID)` preserves the old spellbook-only behaviour and avoids treating arbitrary item/proc spell events as ordinary Cooline spell entries.
- The current `Cooline.lua` has approximately 148 top-level local declarations by static count, below Lua 5.0's 200-local compiler ceiling. This is a guardrail only, not a compiler pass.
- The canonical VanillaTemplate Lua 5.0.2 checker could not be run for the current 3.0 delta because the checker source cannot be retrieved into this execution environment (the host C compiler is available, but GitHub network resolution from the execution container fails). Per the rulebook, **do not claim a Lua 5.0.2 compiler pass for `3.0.3-dev` yet**.
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
- The ClassicAPI-required `3.0.3-dev` runtime implementation is **implemented and statically reviewed but not yet user runtime-tested**.
- Current ClassicAPI still cannot expose exact itemID/GUID for a `UseAction` bag-instance action: `GetActionInfo(slot)` returns `"item", nil`. Cooline therefore intentionally retains the native item-discovery fallback for that route and for one timeout recovery pass if an otherwise exact itemID route fails to surface a new cooldown.
- The current execution environment could not retrieve/run the canonical VanillaTemplate Lua 5.0.2 checker, so the 3.0 delta has no real compiler pass yet. This is a tooling limitation, not a known Lua error.
- The first `2.1.0-dev` performance delta has passed the targeted functional runtime paths exercised so far; no runtime regression was reported in those paths.
- The burst-event coalescing delta at `a9c53e8648c6c6d753c7b7327aab746222f0e5ec` passed user runtime testing. A one-frame delay is intentional only for broad spell/item event bursts; direct recovery and world-entry paths remain immediate.
- The final combined `2.1.2-dev` Stage 1 delta at `367fe609596950a34ae8d286388c18679fac7507` is implemented, checked and user runtime-tested successfully.
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

### Last Runtime Test — Final Native Stage 1
- Version/runtime: `2.1.2-dev`, runtime implementation `367fe609596950a34ae8d286388c18679fac7507`, product-identical checked cleanup tree `686aecb040545252492c9da59981beb902a6e3d4`.
- Result: user reports the combined final native build is working very well; no Lua errors, missing/stale cooldowns, wrong item identity, filter regressions, stuck highlight or other behavioural regression were reported.
- This closes the native Stage 1 runtime-validation gate.
- Quantitative CPU/performance improvement remains unmeasured; do not convert the functional pass into a numerical performance claim.

### Next Runtime Test — ClassicAPI Stage 3
- Version/runtime: `3.0.3-dev`, implementation head before this status commit `dc340c628954fe93509fdb57696f37caf0294678`.
- Confirm the addon loads with current ClassicAPI, `/cooline` still opens the options UI, SavedVariables/options/appearance remain intact, and no Lua error occurs at login/reload.
- Spell path: cast an ordinary known spell with a cooldown >2.5 seconds; verify the correct icon/timing appears, repeated casts/failure-pulse behaviour remains sane, and `/reload` / zoning reconstructs active cooldowns.
- Exact bag/equipment item paths: use a bag consumable and an equipped on-use item/trinket; verify the correct item appears and no unrelated shared-cooldown item is substituted.
- Macro/binding path: exercise ordinary and supported conditional `/use` through the installed SCRM/pfUI path plus any direct ClassicAPI item binding in normal use; these should reach the exact `UseInventoryItem` / `C_Item.UseItemByName` observers.
- Action-bar path: test an item-by-ID action if available and a dragged bag-instance action. The bag-instance route is expected to use the retained native fallback because ClassicAPI currently reports no itemID; it must still show the correct practical result and must not regress action execution.
- Shared-cooldown safety: while an item is already locked by a shared cooldown, attempt another item in that category and verify Cooline does not relabel the existing cooldown merely because of the failed/blocked use attempt.
- No 3.0 runtime result is recorded until the user performs this test.

## Planned / Next Work

### Stage 1 — Native 2.1 performance release — COMPLETE
1. **Implemented:** bump the TOC from `2.0.0-dev` to `2.1.0-dev` before runtime edits.
2. **Implemented:** remove the permanent 0.50-second full `ReconcileAllCooldowns()` poll.
3. **Implemented:** split spell and item reconciliation so events and filter changes refresh only the relevant domain.
4. **Implemented for the first checkpoint:** keep deliberate startup/world-entry full-sync points and add bounded item-only recovery after directly captured bag/equipped item use.
5. **Implemented for the first checkpoint:** convert rendering to active-only lifecycle management, disable the renderer when idle, iterate only active cooldowns, and avoid redundant `Show`, alpha, size and frame-level writes.
6. **Checked:** complete static review and real Lua 5.0.2 compiler pass.
7. **Passed:** targeted user runtime testing confirmed the exercised spell, potion, rapid-input, on-use trinket, reload recovery, equipment-change, failed-cast pulse and filter-update paths. Quantitative performance improvement was not measurable reliably in the user's environment.
8. **Implemented/checked/passed:** safe burst-event coalescing. Same-frame broad spell events now collapse to one spell reconciliation and same-frame broad item/inventory events to one item reconciliation; immediate recovery/world-entry/user-action paths are preserved. User testing found no new regression in the exercised spell/item/filter/equipment paths.
9. **Implemented/checked/passed:** `2.1.2-dev` batches the final three native candidates by explicit user decision: stable spellbook/filter caching, reconciliation scratch/allocation reuse, and flash-only options-row `OnUpdate`. The consolidated user runtime pass reported no regression.
10. **Next:** promote the exact accepted native runtime to stable `2.1.2`, tag `v2.1.2` where repository tooling permits, preserve it on `native-2.1`, then move `dev` to `3.0.0-dev` for ClassicAPI-required development.
11. Do not add further native optimization work unless a concrete stable-line regression is discovered.

### Stage 2 — Preserve the final native line — RELEASE/BRANCH COMPLETE
1. **Released:** stable `2.1.2` is on `main` at `d4fc1a5a0c697cdc8d7534a2942f6fa2dc94c505`.
2. **Preserved:** permanent `native-2.1` points to that exact same commit.
3. **Tag pending tooling:** intended tag is `v2.1.2`; the current GitHub connector does not expose tag creation, so the tag must not be claimed as present.
4. Treat `native-2.1` as the known-good no-ClassicAPI fallback/reference line. Do not merge 3.x ClassicAPI-required architecture into it.

### Stage 3 — ClassicAPI-required 3.0 — ACTIVE
1. **Done:** return to `dev` and start the line at `3.0.0-dev`.
2. **Done:** audit ClassicAPI spell/item/GUID/event/action/macro surfaces and document the exact item-use route matrix, including the unresolved bag-instance `UseAction` identity gap.
3. **Done:** first runtime edit bumped to `3.0.1-dev` and added the explicit `## Dependencies: !!!ClassicAPI` contract plus runtime capability validation through `CLASSIC_API_VERSION` and the required API surface.
4. **Implemented:** successful player spell casts now use `UNIT_SPELLCAST_SUCCEEDED` exact spellID -> strict `IsSpellKnown` -> `C_Spell.GetSpellCooldown`; normal cooldown-update events refresh only active exact spell IDs instead of rescanning the spellbook.
5. **Implemented:** stock bag/equipped uses capture exact itemID/GUID from ClassicAPI ItemLocations before execution. `C_Item.UseItemByName` and `UseAction` are likewise observed before execution so a consumed item/action cannot erase the evidence.
6. **Implemented:** direct itemID cooldown observation uses `GetItemCooldown(itemID)`, retains GUID alongside itemID when available, requires a cooldown-signature transition from pre-use state, and seeds the existing shared-cooldown identity lock only after an exact transition is observed.
7. **Implemented:** direct `ITEM` bindings and the supported SCRM/pfUI ordinary/conditional `/use` routes are covered through their concrete `C_Item.UseItemByName` / `UseInventoryItem` calls rather than macro-text parsing.
8. **Implemented:** item-by-ID action entries use exact identity. Bag-instance action entries still return `"item", nil`; for those, and for one exact-route timeout recovery pass, the legacy native item-discovery scan remains intentionally available.
9. **Implemented:** broad native `BAG_UPDATE` / `UNIT_INVENTORY_CHANGED` registrations were replaced on the 3.0 line with ClassicAPI `BAG_UPDATE_DELAYED` / `PLAYER_EQUIPMENT_CHANGED` while preserving startup/world-entry recovery.
10. **Current gate:** run the consolidated `3.0.3-dev` ClassicAPI runtime matrix above. A real Lua 5.0.2 compiler pass is still outstanding because the checker could not be retrieved in this execution environment.
11. **After the runtime gate:** if the implemented exact routes pass, address the remaining action-bar bag-instance gap in ClassicAPI itself (expose exact itemID and preferably GUID/location for that action descriptor), then only remove the broad native item-discovery fallback after the new route is code- and runtime-proven.
12. Keep `main` on stable `2.1.2` and `native-2.1` unchanged until the 3.0 line is explicitly accepted for promotion.

## Deferred / Out of Scope
- UI redesign or unrelated feature additions during the 2.1 performance pass.
- Spells/Items options-panel re-layout unless deliberately promoted from idea to active scope later.
- Feature changes disguised as performance work.
- Making ClassicAPI optional in 3.0; the current 3.0 plan intentionally uses it as a required platform dependency so the native compatibility architecture can be removed.
- Exhaustive non-English validation unless a changed path or concrete issue makes it relevant.
- New debug tooling unless required to validate the performance/runtime rewrite.

## Release / Promotion Notes
- Stable `main` is `2.1.2` at `d4fc1a5a0c697cdc8d7534a2942f6fa2dc94c505`; do not develop 3.0 directly on `main`.
- Current main-only/release-only content: no extra main-only files. Stable `main` intentionally contains only `Cooline.lua`, stable `Cooline.toc`, `README.md`, `artwork/` and `locales/`; preserve stable TOC Title/Version metadata and do not copy development docs to `main`.
- Known 2.0 validation debt: timeline-overlay, font-preview, locale-filter migration, non-English cooldown-failure matching, opacity clamping and supported-locale behaviour were not each individually/exhaustively exercised in every path or locale before/after the accepted 2.0.0 release. This is historical release provenance, not scheduled maintenance work.
- 2.1 must remain installable without ClassicAPI or any other DLL/client extension.
- 3.0 will require ClassicAPI; that dependency is a deliberate major-version boundary.
- The exact stable native commit is already preserved on `native-2.1`. The matching `v2.1.2` tag remains pending because tag creation is unavailable through the current connector; do not claim the tag exists.

## Exact Next Step
Runtime-test `3.0.3-dev` from this handoff with current ClassicAPI using the consolidated Stage 3 matrix above. Do not make another runtime change before interpreting that test unless a load-blocking defect is discovered. If the exact spell, bag/equipment, named/bound/macro, item-by-ID action and shared-cooldown-transition paths pass, the next development step is to extend ClassicAPI so bag-instance `UseAction` entries expose exact item identity, then bump Cooline for the corresponding runtime revision and remove native item discovery only after that final route is proven. The real VanillaTemplate Lua 5.0.2 compiler check also remains outstanding and must be run before claiming compiler-checked 3.0 status.


