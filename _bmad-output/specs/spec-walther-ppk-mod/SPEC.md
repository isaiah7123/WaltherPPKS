---
id: SPEC-walther-ppk-mod
companions: []
sources:
  - ../../forge/walther-ppk-mod/forged-idea.md
  - ../../forge/ppk-suppressor/forged-idea.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Walther PPK/S for Project Zomboid (Build 42)

## Why

A vision to realize: add an authentic Walther PPK/S to Project Zomboid Build 42 as the civilian concealed-carry pistol a 1993 Kentucky household would own. Players get a light, realistic gun with its own scarce .380 ACP ammo, rather than a reskinned 9mm. Realism decides every trade-off, with one named exception: a rare suppressor, added in the first update, makes the PPK/S Build 42's only quiet gun for stealth play.

## Capabilities

Version 1: CAP-1 to CAP-9. First update: CAP-10 to CAP-12.

- **CAP-1**
  - **intent:** Player can find the PPK/S in civilian loot.
  - **success:** In a test world, the gun spawns in civilian containers (homes, gun stores, cars, safes) and never in police or military containers.
- **CAP-2**
  - **intent:** Player can load and fire the PPK/S using a 7-round .380 ACP magazine.
  - **success:** The magazine holds 7 rounds; the gun fires, reloads and unloads like vanilla pistols, with the stats below.
- **CAP-3**
  - **intent:** Player can find .380 ACP rounds and boxes in civilian loot, less often than 9mm, and open or pack them.
  - **success:** Each .380 spawn chance is half the matching vanilla 9mm entry; a box opens into 50 rounds and 50 rounds pack into a box.
- **CAP-4**
  - **intent:** Future .380 guns can use the same ammo without changing it.
  - **success:** A throwaway test gun that references the .380 ammo loads and fires it with no edits to the ammo definitions.
- **CAP-5**
  - **intent:** The PPK/S looks right in game.
  - **success:** The model shows in hand and on the floor at the same scale as vanilla pistols; the inventory icon is recognizable at normal size.
- **CAP-6**
  - **intent:** The mod's items show readable English names.
  - **success:** All display names come from translation files; the gun reads "Walther PPK/S".
- **CAP-7**
  - **intent:** Player can enable the mod in Build 42.
  - **success:** The mod is listed as "Walther PPK/S" with mod ID `WaltherPPKS`, and a new game loads with no mod errors in the console log.
- **CAP-8**
  - **intent:** Player can find empty .380 magazines.
  - **success:** Each PPK/S spawns with one magazine; empty magazines also spawn on their own, rarely, in civilian loot only.
- **CAP-9**
  - **intent:** Player can tell a .380 box from a 9mm box at a glance.
  - **success:** The .380 box shows its own icon in inventory and its own texture on the floor and in hand.
- **CAP-10** (first update)
  - **intent:** Player can attach and remove a suppressor on the PPK/S.
  - **success:** It attaches and detaches through the vanilla attachment menu, sits on the muzzle without floating or clipping from any angle, and fits no other gun.
- **CAP-11** (first update)
  - **intent:** Suppressed shots draw fewer zombies.
  - **success:** Sound radius is 20 while the suppressor is attached and 70 after removal, and stays correct after saving and reloading.
- **CAP-12** (first update)
  - **intent:** Player can rarely find the suppressor in civilian loot.
  - **success:** It spawns only in the civilian lists below, at those weights, and never in SWAT or army storage.

## Constraints

- Build 42 only.
- PPK/S in .380 ACP with a 7-round magazine.
- Gun stats: weight 1.0, damage 0.6–1.0 (same as the M9), max range 10, sound radius 70. Other stats follow the vanilla M9 ("Pistol").
- Edges over the M9 (weight 1.5, sound radius 100) are lower weight, M1911-level noise, and from the first update the suppressor. Unsuppressed, never quieter than the quietest vanilla pistol (radius 70).
- .380 ammo: round weight 0.02; box of 50 at weight 0.6; own open and pack recipes; no carton.
- Never spawns in police or military loot; every .380 spawn chance is half the matching 9mm one.
- Model: "Walther PPK" by MihaM (Sketchfab, CC BY 4.0). Credit author and license in the mod files and on the Workshop page. Reduce from 7.7k triangles and size textures to match vanilla pistols.
- .380 box reuses the vanilla `HandGunAmmoBox` mesh with a new .380 texture and a new icon. .380 rounds and magazine reuse vanilla art (icons `PistolAmmo` and `BerettaClip`, models `9mmRounds` and `Gun_Pistol_Magazine`), as vanilla does for .45.
- New art in version 1 is limited to the gun model, gun icon, .380 box texture and .380 box icon.
- The .380 box texture and icon are edited from the vanilla 9mm box art. Under the Project Zomboid Modding Policy, that art stays in a free mod that requires the base game: never sold, never reused outside Project Zomboid, and the mod is never presented as official.
- Suppressor: sound radius 20 while attached; never wears out; can't be crafted; fits the PPK/S only.
- Suppressor spawn weights are fixed copies of the vanilla x8 scope's, civilian lists only: GunStoreAccessories 6, PawnShopGunsSpecial 6, GunStoreGuns 4, GunStoreRifles 4, GarageFirearms 1, PawnShopGuns 1, FirearmWeapons_Mid 1, FirearmWeapons_Late 1.
- Suppressor art comes from MihaM's model (same CC BY credit), with the icon rendered from it. The gun model gets a muzzle attachment point.
- Lua is limited to changing the PPK/S sound radius when the suppressor is attached or removed.
- Display names live only in translation files. Item IDs never change after release and contain no "/".
- Ammo is defined separately from the gun so other .380 guns can share it.
- Vanilla pistol sounds only; no new sound files.

## Non-goals

- Build 41 support or a port.
- Any attachment in version 1, and any attachment other than the suppressor.
- Suppressor wear, suppressor crafting, or a suppressor for other guns.
- Suppressor spawns in SWAT or army storage.
- Custom sounds.
- Any edge besides weight, M1911-level noise and the suppressor.
- 9mm or .32 ACP chambering.
- Other .380 guns in version 1.
- A .380 carton.
- A generic, vanilla-style name.

## Success signal

- Version 1: in a new Build 42 game with only this mod enabled, a player finds a PPK/S and .380 ammo in a house, loads 7 rounds, fires using vanilla pistol sounds, sees the correct model in hand, and the console log shows no errors from the mod.
- First update: a player finds the suppressor in a gun store, attaches it, and clears a house with fewer zombies arriving than without it; removing it restores normal noise.

## Assumptions

- English is the only translation.
- Version 1 works in multiplayer as a normal item mod, with no multiplayer-specific code.
- The model is a PPK, not a PPK/S; the slightly longer PPK/S grip isn't visible at Zomboid's camera distance, so it is used as-is.
- The model's texture details aren't listed on Sketchfab; checked after download.
- MihaM's model includes a suppressor that can be split off as its own mesh; unconfirmed until download.
- `HandWeapon.setSoundRadius` is exposed to Lua (found in `projectzomboid.jar`) but untested in game.
- The fixed suppressor spawn weights won't follow future changes to the vanilla x8 scope; recheck after game updates.
- In version 1, the weight and noise edges may be too small to notice; accepted, revisit after playtesting.
- Once found, the suppressor makes the PPK/S permanently the best stealth gun; accepted, with rarity as the only limit.

## Open Questions

- In multiplayer, does a sound radius change made in Lua take effect on the server, or does it need server-side code?
