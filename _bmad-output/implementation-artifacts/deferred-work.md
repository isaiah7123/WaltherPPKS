- source_spec: `_bmad-output/implementation-artifacts/spec-walther-ppk-mod.md`
  summary: Confirm every PPK/S gets a magazine outside container fills (vehicle part containers, world/story spawns).
  evidence: Unverified (would be medium). Magazine guarantee hooks only OnFillContainer; settle by checking whether vehicle containers fire OnFillContainer during ItemPicker fill, e.g. find a PPK/S in a civilian glove box in game.
- source_spec: `_bmad-output/implementation-artifacts/spec-walther-ppk-mod.md`
  summary: Verify item and recipe display names (ItemName.json, Recipes.json) in game before each release.
  evidence: Dedicated server loads no mod translations, so the automated run always skips name checks; a key typo would ship raw IDs.
- source_spec: `_bmad-output/implementation-artifacts/spec-ppk-suppressor.md`
  summary: Confirm the suppressor model renders on the PPK/S (module-qualified model name in ModelWeaponPart) and sits on the muzzle without floating or clipping.
  evidence: Unverified (would be medium). Dedicated server has no renderer; settle by attaching it in game and viewing from several angles.
- source_spec: `_bmad-output/implementation-artifacts/spec-ppk-suppressor.md`
  summary: Decide whether army surplus stores (civilian, roomType "armysurplus") should get PPK/S, .380 and suppressor loot; the "army" deny token currently strips all mod items there.
  evidence: Pre-existing v1 behaviour; Distributions.lua:3896 `armysurplus` rolls GunStoreRifles; fill-time strip matches "army". Spec says civilian only but doesn't name army surplus.
