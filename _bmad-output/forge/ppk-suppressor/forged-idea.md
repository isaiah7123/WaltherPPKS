# Forged idea: Suppressor for the Walther PPK/S

Outcome: HARDENED (2026-11-05). Change to SPEC-walther-ppk-mod.

## Locked
- **Purpose:** stealth play. The PPK/S deliberately becomes B42's only quiet gun (B42 has no vanilla suppressors).
- **Noise:** sound radius 20 with the suppressor attached (70 without; M9 is 100).
- **Limit:** rarity only. Never wears out; can't be crafted.
- **Spawns** (fixed copies of the vanilla x8 scope weights, civilian lists only): GunStoreAccessories 6, PawnShopGunsSpecial 6, GunStoreGuns 4, GarageFirearms 1, PawnShopGuns 1, FirearmWeapons_Mid 1, FirearmWeapons_Late 1. Never SWAT or army.
- **Fits** the PPK/S only.
- **Realism rule** stays ("realism decides every trade-off"), with the suppressor named as the one deliberate gameplay exception.
- **Timing:** first update after v1. v1 ships lean as specced.
- **Art:** suppressor from MihaM's "Walther PPK" model (CC BY 4.0, same credit); icon rendered from it.
- **Code:** one Lua script sets the gun's sound radius to 20 when attached and back to 70 when removed (vanilla weapon parts can't change noise).

## Rejected
- Radius 30: user chose near-silent 20.
- Wearing out: user prefers a permanent find; keeps Lua minimal.
- Half the x8 rarity: user wants exactly the x8 scope's rarity.
- SWAT/army spawns: suppressor would appear where its gun never spawns.
- "Gameplay first" rule: suppressor is the only big departure.
- Suppressor in v1: unverified Lua shouldn't block the gun's release.

## Spec changes needed
- Remove non-goals "Attachments of any kind" (for the suppressor) and "Any edge besides weight and M1911-level noise".
- Add the realism exception to Why, and the suppressor as an update-scope capability.

## Open risks
- Once found, it's permanently the best stealth gun; rarity is the only brake.
- `HandWeapon.setSoundRadius` exists and is Lua-exposed in projectzomboid.jar, but is untested in game.
- Spawn numbers won't follow if the developers retune the x8 scope; recheck after updates.
- Suppressor in MihaM's model unconfirmed; check it's a separate mesh after download.
- Gun model needs a muzzle attachment point; test for floating or clipping.
