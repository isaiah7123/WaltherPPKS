---
title: 'PPK/S suppressor (first update)'
type: 'feature'
created: '2026-11-05'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '1bbeb71f33aa015a19aed4509df34cfc0a095bd8'
context:
  - '{project-root}/_bmad-output/specs/spec-walther-ppk-mod/SPEC.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-walther-ppk-mod.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** B42 has no quiet gun. SPEC CAP-10..12 add a rare suppressor that makes the PPK/S the one stealth option, as the single named exception to the realism rule.

**Approach:** Add a `WaltherPPKS.PPKSSuppressor` weapon part (barrel slot, PPK/S only) using the suppressor geometry from MihaM's model, inject it into eight civilian loot lists at the vanilla x8-scope weights, and use one shared Lua script to set the PPK/S sound radius to 20 while it is attached and 70 otherwise.

## Boundaries & Constraints

**Always:**
- Part: `PartType = Canon`, `MountOn = WaltherPPKS.PPKS` only, Weight 0.3 / WeightModifier 0.3, attaches and detaches through the vanilla menu with no tool, no condition loss, no recipe.
- Radius 20 attached, 70 detached. Reapplied after attach/detach, on equip, and at game start, because `HandWeapon` does not save `soundRadius` (resets to the script value on load). Script is shared (client fires the noise in `IsoLivingCharacter.DoAttack`, server runs the attach `complete()`).
- Loot (ProceduralDistributions only): GunStoreAccessories 6, PawnShopGunsSpecial 6, GunStoreGuns 4, GunStoreRifles 4, GarageFirearms 1, PawnShopGuns 1, FirearmWeapons_Mid 1, FirearmWeapons_Late 1. Existing fill-time strip keeps it out of police/military containers.
- Art from MihaM's model (same CC BY credit): separate suppressor mesh sharing the gun texture, icon rendered from it; gun model gains a `suppressor` attachment at the muzzle, part model has a matching rear attachment.
- Names and tooltip only in translation files.

**Never:** other attachments, other guns, wear, crafting, SWAT/army spawns, new sounds, Lua beyond the sound-radius script, changes to v1 stats or loot.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Attach | PPK/S + suppressor in inventory, use attach menu | part on gun, radius 20 | N/A |
| Detach | suppressed PPK/S, remove part | part back in inventory, radius 70 | N/A |
| Save/reload | suppressed PPK/S saved | after load and equip, radius 20 | N/A |
| Other gun | M9 + suppressor | no attach option | N/A |
| Loot | merge runs | suppressor in exactly the 8 lists at the listed weights | N/A |
| Military fill | militarylocker using GarageFirearms rolls it | removed | N/A |

</frozen-after-approval>

## Code Map

Mod root `M = workshop/WaltherPPKS/Contents/mods/WaltherPPKS/42/media`; vanilla `G = C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media`.
- `G/scripts/generated/items/weaponpart.txt` `ChokeTubeFull` -- barrel-part template (`PartType = Canon`, `MountOn`, `WorldStaticModel`); drop `CanAttach`/`CanDetach` for no tool.
- `G/scripts/generated/items/weapon.txt` Shotgun `ModelWeaponPart = ChokeTubeFull ChokeTube choketube choketube` -- format: part ID, model, gun attachment, part attachment.
- `G/lua/shared/TimedActions/ISUpgradeWeapon.lua` / `ISRemoveWeaponUpgrade.lua` -- `complete()` attaches/detaches then `syncHandWeaponFields`; wrap `complete` to reapply radius.
- `M/scripts/WaltherPPKS_gun.txt` -- add `ModelWeaponPart` line and `attachment suppressor` to `model PPKS`; keep all stats.
- `M/lua/server/WaltherPPKS_Distributions.lua` -- add the 7 fixed entries in `injectLoot`; fill-time strip already removes `WaltherPPKS.*` from denied containers.
- `tools/build_model.py` -- `strip_suppressor` (cut at `--cut-y 0.395`) currently discards the suppressor; reuse it to export the kept part with the same `normalize` transform.
- `dev/WaltherPPKS_TestGun380/.../WaltherPPKS_TestChecks.lua`, `tools/run_server_test.ps1` -- extend checks.

## Tasks & Acceptance

**Execution:**
- [x] `tools/build_model.py` -- also output `M/models_X/weapons/PPKS_Suppressor.fbx`, `M/textures/Item_PPKSSuppressor.png`; print both attachment offsets.
- [x] `M/scripts/WaltherPPKS_suppressor.txt` -- part item, `model PPKSSuppressor` (+ ground model).
- [x] `M/scripts/WaltherPPKS_gun.txt` -- `ModelWeaponPart` + `suppressor` attachment.
- [x] `M/lua/shared/WaltherPPKS_Suppressor.lua` -- radius logic and hooks.
- [x] `M/lua/server/WaltherPPKS_Distributions.lua` -- 8 loot entries.
- [x] `M/lua/shared/Translate/EN/{ItemName,Tooltip}.json` -- name "Walther PPK/S Suppressor", tooltip.
- [x] Dev checks for every matrix row the server can run; credits, workshop.txt and README mention the suppressor.

**Acceptance Criteria:**
- Given the server test, when it runs, then it exits 0 with checks covering attach/detach radius, reload reapply, M9 rejection, loot weights and military strip.
- Given an in-game attach, when viewed from several angles, then the suppressor sits on the muzzle without floating or clipping (manual).

## Design Notes

Radius rule in one place: `radius = (gun:getWeaponPart("Canon") is PPKSSuppressor) and 20 or 70`, applied to `WaltherPPKS.PPKS` only. Multiplayer: applying on both sides should make server-attached state reach the client via the synced part plus the equip/start hooks; confirm in a real MP session (manual).

## Verification

**Commands:**
- `powershell -ExecutionPolicy Bypass -File tools/run_server_test.ps1` -- expected: exit 0, RESULT PASS.

**Manual checks (if no CLI):**
- In game: attach/detach via menu, fire near zombies with and without, save/reload, inspect model alignment; MP if available.

## Implementation Notes

- Model: source suppressor is everything in front of `--cut-y 0.395` (can from y 0.410 to 1.319 plus the barrel stub inside it). `split_suppressor` keeps that half (`clear_inner`), decimates to 399 game verts / 390 tris, applies the gun's `normalize` transform (now returned), then moves the origin to the rear centre of the bore. Printed: suppressor length 0.1028, radius 0.0088; gun attachment `suppressor` = `0.0 0.0992 -0.0228` (identical to the muzzle point, so the can starts exactly where the cut barrel ends); part attachment `suppressor` = origin; ground `world` y = 0.0514. Both attachments rotate 0 (same layout as the gun, as the M9's `laser` and Marz `canon` attachments do). Suppressor mesh shares `weapons/PPKS` (same UV atlas).
- Re-running the script rewrote `PPKS.fbx` with byte-level metadata differences only (re-imported: same 436 verts / 733 tris, max vertex diff 0.0); the committed gun FBX was restored so v1 art is unchanged. Gun texture and gun icon came out byte-identical.
- Ground model: `PPKSSuppressor_Ground`, same mesh, `world` offset `-0.0088 0.0514 0` (x mirrors how the gun's world x = -half width); untested in game.
- Part script: no `CanAttach`/`CanDetach` -> `WeaponPart.canAttach` returns true after the `MountOn` (full type) check, so no tool; `MountOn = WaltherPPKS.PPKS` rejects every other gun. `ModelWeaponPart = WaltherPPKS.PPKSSuppressor WaltherPPKS.PPKSSuppressor suppressor suppressor` (module-prefixed like Guns of Marz).
- Lua: `WaltherPPKS.Suppressor.apply(item)` is the single radius rule (`getWeaponPart("Canon")` full type == suppressor -> 20, else 70; PPK/S only). Wraps `ISUpgradeWeapon.complete` / `ISRemoveWeaponUpgrade.complete` through `S.orig` (kept across Lua reloads so wrappers never stack), `OnEquipPrimary`, `OnGameStart` (walks each local player's inventory incl. bags, plus primary hand).
- Loot: fixed entries appended to `ProceduralDistributions.list[name].items` inside `injectLoot` (after the 9mm walk; logs a warning if a list is missing). Existing fill-time strip removes it from police/military containers (all `WaltherPPKS.*`).
- Dev checks added: suppressor in exactly the 8 lists, once each, at the listed weights and nowhere else; part type/MountOn/weight/weight modifier; canAttach PPK/S true, M9 and revolver false; canDetach true; attach -> 20, detach -> 70, M9 untouched (100); wrappers installed and reapply (vanilla original stubbed, it needs a real player); reload simulated by `setSoundRadius(70)` then equip hook -> 20; `onGameStart` with no players doesn't throw; militarylocker strip removes it (x8 scope kept), civilian counter keeps it.
- Server test: `tools/run_server_test.ps1` -> RESULT PASS (5157 passed, 0 failed), exit 0, no mod ERROR/WARN, "8 suppressor entries".
- Not covered automatically (dedicated server has no renderer, no players, no mod translations): model alignment/floating/clipping, ground model pose, icon look, names/tooltip text, the real attach/detach menu flow, actual save/load of a suppressed gun, zombie draw in play, and multiplayer client radius (in MP `complete()` runs on the server; the client's radius is set by the equip / game-start hooks, so a gun suppressed while already in hand may keep 70 on the client until re-equipped — confirm in MP).

## Spec Change Log

## Review Triage Log

| # | Finding (layers) | Verdict | Evidence | Route |
|---|---|---|---|---|
| 1 | MP: attach/detach `complete()` runs on server; client copy that fires the noise keeps 70 until re-equip; server sets radius after `syncHandWeaponFields`; other paths (secondary hand, trade, late join) skip reapply (blind, edge, vgap) | high | `IsoLivingCharacter.DoAttack` reads `getSoundRadius` on the shooter; wrappers only on `complete`; `OnWeaponSwing` fires in `SwipeStatePlayer.enter`, after `addSound`, so too late. Fix: reapply to the primary-hand item in `OnPlayerUpdate` (idempotent). | patch |
| 2 | Gun `suppressor` attachment copied from muzzle, not build output (blind, edge) | false | Re-ran build: prints `ATTACH PPKS suppressor offset = 0.0000 0.0992 -0.0228`, identical to the script. | reject |
| 3 | No nil guard on captured vanilla `complete` (blind, edge) | low | Both exist in 42.21 (`ISUpgradeWeapon.lua`, `ISRemoveWeaponUpgrade.lua:38`); would need a game/mod change; adds a branch. | reject |
| 4 | Equip/game-start hooks only called directly; `applyAll` bag walk untested (vgap) | medium | Test calls `S.onEquip` directly, `onGameStart` only no-throw with no players. | patch |
| 5 | Wrapper test stubs originals and builds its own `self`; captured originals and `.weapon` field unverified (vgap) | medium | Test asserts only inequality. Vanilla `:new` sets `o.weapon` (both files) — add type and real-instance checks. | patch |
| 6 | Loot weights never checked against live x8 scope; test duplicates the literal table (blind) | low | Verified manually against 42.21 ProceduralDistributions (all 8 match). SPEC accepts fixed copies. Using the exported table is a direct change. | patch |
| 7 | Denied-container test covers only one container (blind) | low | Strip is by deny token on room/container type, already tested; more cases add little. | reject |
| 8 | Workshop credit still labelled "Gun model:"; README Credits bullet too (blind) | low | Inconsistent with "Gun and suppressor models" elsewhere. Text edit. | patch |
| 9 | Gun script header says "minus attachment parts" (blind) | low | Stale after adding the part. Text edit. | patch |
| 10 | Module-qualified model name in `ModelWeaponPart` may not resolve (blind) | maybe-false | Would be medium (suppressor invisible on the gun). `WeaponSprite = WaltherPPKS.PPKS` resolves in game; settle with the in-game look. | defer |
| 11 | Ground offset and comments hand-copied from build printout (blind) | low | Only drifts if the cut changes; adds tooling. | reject |
| 12 | Suppressor name/tooltip never checked, even in game (blind, vgap) | low | In-game `checkNames` branch covers PPK/S and box only; add suppressor name and tooltip there. | patch |
| 13 | build_model.py crashes on empty suppressor or unreachable target (edge) | low | Real source works; fixes add guards. | reject |
| 14 | GunStoreRifles also rolled by hunting and outdoor-supply rooms; README/workshop loot wording incomplete (edge) | low | Civilian, allowed by spec; wording says gun stores, pawn shops, garages, stashes only. Text edit. | patch |
| 15 | Test lacks guard if `S.apply`/`S.orig` nil (edge) | low | Dev-only; existing `try` already records a failure. | reject |
- Review fixes applied (OnPlayerUpdate reapply for MP, S.applyAll, real-event tests, credit/loot wording). Server test: RESULT PASS (5163/0), exit 0; ISUpgradeWeapon/ISRemoveWeaponUpgrade :new checks SKIP on server (need a real character).
