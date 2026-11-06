# Forged idea: Walther PPK/S for Project Zomboid

Outcome: HARDENED (2026-11-05)

## Locked
- **Build 42 only.** No B41 support or port. Accepted: B41 multiplayer servers can't use it.
- **Gun:** PPK/S in .380 ACP, 7-round magazine. Display name "Walther PPK/S" for the gun and the mod.
- **Ammo:** new .380 ACP round, box and magazine, under the mod's own namespace (e.g. `...Ammo380ACP`). Built so future .380 guns can share it.
- **Spawns:** common in civilian spots (homes, gun stores, cars, safes); never police or military. .380 scarcer than 9mm.
- **Edge over the M9:** low weight and M1911-level noise (sound radius 70 vs the M9's 100). Damage and everything else realistic. (Changed during spec, 2026-11-05: was weight only.)
- **Model:** free model whose license allows changes and redistribution (CC0/CC-BY, credit if required).
- **Names:** display names only in translation files, never in item IDs, so a rename stays cheap. IDs can't contain "/".
- **Mod ID:** `WaltherPPKS`.
- **Version 1:** gun, round, box, magazine, civilian spawns, model, icon, translations. Vanilla pistol sounds. No attachments.

## Rejected
- Reusing vanilla 9mm: unrealistic; makes it a reskinned M9.
- .32 ACP: same work as .380, weaker, rarer in the US.
- Noise below the quietest vanilla pistol: real .380 isn't meaningfully quieter. (Matching the M1911's radius of 70 was later accepted.)
- Generic vanilla-style name: undercuts the realism direction.
- Classic 6-round PPK: weaker, less true to 1993 Kentucky.
- Attachments in v1: no rail on a PPK/S; extra scope before first release.

## Open risks
- The weight edge may be too small to notice; the gun may end up as an early-game pick players replace. Check in playtesting.
- Must verify the model's license and cut its polygon count and texture size to match vanilla guns.
- Small trademark risk from the real name; a rename only touches translations and the Workshop page.
