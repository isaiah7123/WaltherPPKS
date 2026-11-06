---
title: 'PPK/S ankle holster (unsuppressed only)'
type: 'feature'
created: '2026-11-06'
status: 'done'
route: 'inline'
baseline_commit: '88c0b83'
context:
  - '{project-root}/_bmad-output/specs/spec-walther-ppk-mod/SPEC.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-ppk-suppressor-polish.md'
---

## Intent

SPEC CAP-13. The unsuppressed PPK/S fits an ankle holster as well as normal holsters; suppressed, only normal holsters.

## How vanilla decides

`client/Hotbar/ISHotbarAttachDefinition.lua`: each holster slot maps an item's `AttachmentType` to a location. Hip (`HolsterRight`/`HolsterLeft`) and `HolsterShoulder` accept `Holster` and `HolsterSmall`; `HolsterAnkle` accepts only `HolsterSmall` (vanilla: `Revolver_Short`). `ISHotbar:update()` drops any attached item that `canBeAttached` no longer allows; the item stays in the inventory.

## Boundaries & Constraints

**Always:** gun script `AttachmentType = HolsterSmall`. One rule in `S.apply` next to radius and sound: suppressed -> `setAttachmentType("Holster")`, otherwise `"HolsterSmall"`. Reapplied wherever the radius is, plus a throttled pass over each local player's main inventory (holsterable guns must be there), so guns picked up or loaded from a save follow the rule before the hotbar menus read it.

**Never:** changes to other guns, holster definitions or the hotbar code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected |
|---|---|---|
| Unsuppressed | PPK/S, ankle holster worn | ankle slot offered; hip/shoulder too |
| Suppressed | suppressed PPK/S | only hip/shoulder slots offered |
| Attach in ankle | PPK/S in ankle holster, attach suppressor | gun leaves the ankle slot, stays in inventory |
| Detach | suppressed PPK/S in hip holster, remove suppressor | stays in hip holster; ankle offered again |
| Reload | suppressed PPK/S in hip holster, save/load | stays in hip holster; type back to Holster after the inventory pass |

## Tasks & Acceptance

- [x] `M/scripts/WaltherPPKS_gun.txt` -- `AttachmentType = HolsterSmall`.
- [x] `M/lua/shared/WaltherPPKS_Suppressor.lua` -- holster type in `S.apply`; throttled main-inventory pass in `OnPlayerUpdate`.
- [x] Dev checks: script type, type on attach/detach, M9 untouched, the vanilla slot table (ankle takes only HolsterSmall, hip/shoulder take both) when the client file is loadable, inventory pass.
- [x] README / workshop text.

**Acceptance:** `tools/run_server_test.ps1` exits 0. Manual, in game: the matrix above.

## Spec Change Log

## Implementation Notes

- Gun script `AttachmentType = HolsterSmall`; `S.apply` sets `Holster` while suppressed, `HolsterSmall` otherwise (PPK/S only).
- `S.applyMain` + `OnPlayerUpdate`: each local player's main inventory is reapplied every 500 ms (`getTimestampMs`), so guns picked up or loaded from a save get the right type before the hotbar menus read it. The vanilla radial menu reads `getAttachmentType` inline, which is why this is a pass rather than wrapping the menus.
- Suppressed gun in an ankle holster: vanilla `ISHotbar:update` sees `canBeAttached` fail and removes it from the slot; it stays in the inventory. No mod code for that.
- Dev checks: script type, type on attach/detach, M9 untouched, vanilla slot table (it loads on the server: ankle takes only HolsterSmall; hip left/right and shoulder take both), inventory pass on a loaded suppressed gun.
- Server test: RESULT PASS (5199 passed, 0 failed), exit 0.
- Not covered automatically: the real hotbar menus, the drop-out of an ankle-holstered gun when suppressed, and how the PPK/S model sits on the ankle (vanilla only puts the short revolver there).
