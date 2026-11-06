---
title: 'Walther PPK/S and .380 ACP ammo mod (Build 42)'
type: 'feature'
created: '2026-11-05'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'NO_VCS'
context:
  - '{project-root}/_bmad-output/specs/spec-walther-ppk-mod/SPEC.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Project Zomboid B42 has no civilian concealed-carry pistol; the player wants an authentic Walther PPK/S with its own scarce .380 ACP ammo, not a reskinned 9mm.

**Approach:** A standalone B42 item mod (ID `WaltherPPKS`) that registers a new .380 ammo type, defines the gun, round, box, magazine and open/pack recipes, injects them into civilian loot from the vanilla 9mm entries, and ships the CC BY 4.0 MihaM model, an icon and English translations. `SPEC.md` (context) is the canonical contract for all stats and capabilities CAP-1..CAP-9.

## Boundaries & Constraints

**Always:**
- Gun `WaltherPPKS.PPKS`: Weight 1.0, MinDamage 0.6, MaxDamage 1.0 (same as M9), MaxRange 10, SoundRadius 70, ClipSize/MaxAmmo 7; every other property and all sounds copied from vanilla `Base.Pistol` (M9), minus attachment parts.
- Ammo lives in its own script file and module-level IDs: round `WaltherPPKS.Bullets380` (0.02), box `WaltherPPKS.Bullets380Box` (0.6, 50 rounds), magazine `WaltherPPKS.PPKSClip` (7 rounds), ammo type `waltherppks:bullets_380`. IDs never contain "/" and never change after release.
- .380 round/box/magazine chance = half the matching 9mm entry (`Bullets9mm`, `Bullets9mmBox`, `9mmClip`) in each civilian list; no carton.
- Loot never added to police, military, SWAT, security, prison-guard or sheriff lists, nor to zombie outfits.
- PPK/S chance = 75% of the vanilla M9 (`Pistol`) entry in each civilian list.
- Every looted PPK/S holds one magazine.
- Model: the user downloads MihaM's FBX into `assets/source/`; the agent installs Blender (winget) and scripts the polygon reduction (target near vanilla M9's ~600–1500 verts), 256x256 texture, `.fbx` export and icon render. The pipeline script is kept in `tools/` so it can be re-run.
- .380 box art (CAP-9): new `model PPKS380Box` reusing vanilla mesh `WorldItems/HandGunAmmoBox` (scale 0.4) with a new texture edited from `WorldItems/BoxOfRounds9MM.png` (same size, label reads ".380 ACP"), used as both `StaticModel` and `WorldStaticModel`; new icon `Item_PPKS380Box` edited from vanilla `HandgunAmmoBox` icon art. Rounds and magazine reuse vanilla art (`PistolAmmo`/`9mmRounds`, `BerettaClip`/`GunMagazine`/`Gun_Pistol_Magazine`). No other new art.
- Edited vanilla art stays in this free mod that requires the base game; never sold, never reused outside Project Zomboid, mod never presented as official.
- Display names only in `Translate/EN/*.json`; gun reads "Walther PPK/S", mod listed as "Walther PPK/S".
- Credit "Walther PPK" by MihaM, CC BY 4.0, in the mod files and workshop description.

**Never:** B41 support, attachments, custom sounds, a .380 carton, edits to vanilla files or vanilla recipes, other .380 guns in the shipped mod.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Civilian list with 9mm box at 20 | e.g. `GunStoreAmmunition` | `Bullets380Box` added at 10 | N/A |
| Police/military list | e.g. `PoliceStorageAmmunition`, `ArmyLightSeatRear` | nothing added | N/A |
| Loot fill spawns PPK/S without magazine | container filled | magazine inserted | skip non-PPK/S items |
| Open box | 1 `Bullets380Box` | 50 `Bullets380` | N/A |
| Pack box | 50 `Bullets380` | 1 `Bullets380Box` | under 50: recipe unavailable |
| Throwaway test gun uses `waltherppks:bullets_380` | dev-only mod | loads and fires | no ammo edits needed |

</frozen-after-approval>

## Code Map

Vanilla (read-only), `G = C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media`:
- `G/scripts/generated/items/weapon.txt` `item Pistol` -- stat/sound template for the gun.
- `G/scripts/generated/items/normal.txt` `Bullets9mm`, `Bullets9mmBox`, `9mmClip` -- templates (icons PistolAmmo, HandgunAmmoBox, BerettaClip; box uses `DoubleClickRecipe`).
- `G/scripts/generated/recipes/recipes_ammunition.txt` `OpenBoxOfBullets50`, `place_ammo_in_box` -- recipe shape to copy into new, mod-only recipes.
- `G/scripts/generated/models_weapons.txt` `model Handgun03` -- `world` and `Bip01_Prop2` attachment offsets to start from; M9 mesh is 628 verts, texture 256x256.
- `G/lua/server/Items/{ProceduralDistributions,Distributions,Distribution_BagsAndContainers}.lua`, `G/lua/server/Vehicles/VehicleDistributions.lua` -- tables to walk; vanilla merges via `Events.OnPreDistributionMerge`.
- `G/lua/shared/Translate/EN/{ItemName,Recipes}.json` -- key format `"Module.Item"`, recipe name keys.
- Reference mod (pattern only): workshop `3722134990/.../42.16/media/registries.lua` -- `AmmoType.register("ns:id", "Module.Item")`.
- `G/scripts/generated/models_items.txt` `model HandGunAmmoBox` -- mesh `WorldItems/HandGunAmmoBox`, texture `WorldItems/BoxOfRounds9MM` (`G/textures/WorldItems/BoxOfRounds9MM.png`); vanilla .45/.38 boxes follow the same one-mesh, own-texture pattern.
- Game installed: 42.21.0.

## Tasks & Acceptance

**Execution:** (mod root `M = workshop/WaltherPPKS/Contents/mods/WaltherPPKS`)
- [x] `workshop/WaltherPPKS/workshop.txt` + `M/42/mod.info` + `M/common/` -- name "Walther PPK/S", id `WaltherPPKS`, versionMin 42.20, credit line.
- [x] `M/42/media/registries.lua` -- register `waltherppks:bullets_380` → `WaltherPPKS.Bullets380`.
- [x] `M/42/media/scripts/WaltherPPKS_ammo.txt` -- round, box, magazine, open/pack craftRecipes.
- [x] `M/42/media/scripts/WaltherPPKS_gun.txt` -- gun item and `model PPKS`.
- [x] `M/42/media/lua/server/WaltherPPKS_Distributions.lua` -- table walk with deny-list on container path; `OnFillContainer` magazine guarantee.
- [x] `M/42/media/lua/shared/Translate/EN/{ItemName,Recipes}.json` -- names.
- [x] `tools/build_model.py` (Blender headless) -> `M/42/media/models_X/weapons/PPKS.fbx`, `M/42/media/textures/weapons/PPKS.png`, `M/42/media/textures/Item_PPKS.png` -- blocked until the FBX is in `assets/source/`.
- [x] `tools/build_box_art.py` (Pillow; Blender render for the icon if the vanilla icon can't be pulled from `G/texturepacks/*.pack`) -> `M/42/media/textures/WorldItems/BoxOfRounds380ACP.png`, `M/42/media/textures/Item_PPKS380Box.png`; `model PPKS380Box` goes in `WaltherPPKS_ammo.txt`.
- [x] `dev/WaltherPPKS_TestGun380/` -- not shipped; throwaway gun requiring `WaltherPPKS` for CAP-4.
- [x] `CREDITS.md` + junction `~/Zomboid/Workshop/WaltherPPKS` → `workshop/WaltherPPKS`.

**Acceptance Criteria:**
- Given only this mod enabled, when the server/game starts, then the log shows no errors mentioning WaltherPPKS files or IDs.
- Given the distribution merge has run, when the PPK/S and .380 entries are dumped, then every civilian list with a 9mm entry has the .380 counterpart at half and no denied list has any.
- Given the dev test gun mod, when it loads and fires `Bullets380`, then no ammo file was edited.

## Spec Change Log

## Review Triage Log

| # | Finding (layers) | Verdict | Evidence | Route |
|---|---|---|---|---|
| 1 | Police/military rooms reach civilian-named proc lists by name string, so PPK/.380 injected there (blind, edge) | high | Scan of vanilla Distributions.lua: `militarylocker` (all rooms, gunstore) and `militarycrate` (gunstorestorage) use `GarageFirearms`/`GunStoreAmmunition` by name; both get injected entries. Those lists also serve civilian gun stores, so table-level deny can't fix it; strip at fill time by room/container type. | patch (fixed: fill-time strip + test; server PASS 5119/0) |
| 2 | Test loot walk omits SuburbsDistributions (blind, edge) | false | Vanilla sets `SuburbsDistributions = distributionTable` = `Distributions[1]` (Distributions.lua:22600, SuburbsDistributions.lua:137); already walked via Distributions. | reject |
| 3 | checkLoot may run before injectLoot (same event); never asserted to have run or matched anything (blind, edge, vgap) | medium | Both on OnPostDistributionMerge, order by load order only; result() never checks loot ran; zero lists = PASS. | patch |
| 4 | result() runs twice in hosted game (OnServerStarted + OnGameStart) (blind, edge) | low | Both handlers registered, no guard; double counts and two RESULT lines. One-line guard. | patch |
| 5 | run_server_test.ps1 exits 0 on FAIL/timeout/crash; ignores $log.err (blind, edge, vgap) | medium | Script has no exit code logic. | patch |
| 6 | Copies made before try; leftover copy on failure (blind, edge) | low | Copy loop precedes try/finally. Moving it is a direct correction. | patch |
| 7 | `$args` automatic variable assigned (blind, edge) | low | Line assigns `$args = @(...)`. Rename. | patch |
| 8 | Select-String throws if log not yet created (blind) | false | Start-Process with -RedirectStandardOutput creates the file before returning. | reject |
| 9 | Existing ini Mods= never refreshed (blind, edge) | low | ini written only when absent. Always rewrite = direct correction. | patch |
| 10 | Remove-Item may fail while java holds files (edge) | low | 2s sleep after Stop-Process; WaitForExit is a direct correction. | patch |
| 11 | ~/Zomboid/mods or Server dir missing (edge) | low | Unlikely on a machine that has run PZ; adds guards. | reject |
| 12 | CC BY credit lacks link to the source model (blind) | medium | CREDITS.md, CREDITS.txt, workshop.txt, mod.info name MihaM but no Sketchfab URL; CC BY 4.0 attribution asks for a URI to the material. | patch |
| 13 | Shipped CREDITS.txt lacks not-affiliated disclaimer and vanilla reuse note (blind) | low | Compared to CREDITS.md; spec constraint "never presented as official". Direct text addition. | patch |
| 14 | build_model.py crash paths: best None, no UV, no meshes, HSV socket, AO size (blind, edge) | low | Tool ran on the real source; these need other inputs; fixes add guards. | reject |
| 15 | build_model.py bakes only first material (edge) | false | Source GLB has one material (`lambert9`) and one primitive. | reject |
| 16 | build_box_art.py dead `LABEL_BLUE` (blind) | low | Unused constant; deletion. | patch |
| 17 | Font fallback silent / size loop uninitialised / box icon missing (blind, edge) | low | Windows fonts present; fixes add guards. | reject |
| 18 | Poster caption runs into box icon (blind) | low | poster.png: ".380 ACP" overlaps box icon. Move the icon/caption. | patch |
| 19 | Magazine guarantee only on OnFillContainer; vehicle/world spawns may skip it (blind, edge) | maybe-false | Would be medium. Settle: confirm whether vehicle part containers fire OnFillContainer during ItemPicker fill. | defer |
| 20 | Inserted magazine round count untested (blind) | false | Spec requires a magazine, not rounds. | reject |
| 21 | Ammo `count`, ClipSize, JamGunChance untested (blind) | low | Copied verbatim from vanilla; adding tests for unchanged values. | reject |
| 22 | `_keep.txt` says "Intentionally empty" but has text (blind) | low | Wording; direct edit. | patch |
| 23 | No repo README for build order/versions; English only (blind) | low | Not required by spec; adds new doc. English-only is a spec assumption. | reject |
| 24 | build_model.py rejects .fbx though spec says FBX (edge) | false | User directed the GLB source mid-build; Sketchfab offers no FBX. Fix would edit the spec. | reject |
| 25 | No Blender-render fallback for box icon (edge) | low | Pack read works on 42.21; fallback adds a code path. | reject |
| 26 | Display/recipe names never checked automatically (vgap) | medium | Dedicated server loads no mod translations (control item untranslated). Needs in-game check. | defer |

## Design Notes

Loot is data-driven, not a hand list: recursively walk each table; for any `items` array, scan pairs; when an item is a 9mm source, append `{target, chance/2}` (gun: `chance*0.75`). Skip when the table path matches `Police|Army|Military|SWAT|Security|PrisonGuard|Sheriff|Outfit_`. Gun-with-magazine is enforced after fill (`item:setContainsClip(true)` when missing) because the vanilla picker only adds clips randomly.

## Verification

**Commands:**
- JSON parse of every `Translate/EN/*.json` -- expected: valid.
- Headless dedicated server (`ProjectZomboidServer.bat`, test server name `waltherppks_test`, Mods=WaltherPPKS) with a temporary dump of injected entries -- expected: no mod errors; dump matches deny-list and half-chance rules.

**Manual checks (if no CLI):**
- In-game per SPEC success signal: find in a house, load 7, fire, model scale vs M9, icon readable.
- .380 box next to a 9mm box: icon, floor and in-hand texture visibly different, label readable.

## Implementation Notes

- Model source is the Sketchfab GLB (no FBX offered): `tools/build_model.py` takes `assets/source/walther_ppk.glb` (falls back to any .glb/.gltf/.dae there), strips the suppressor the source ships with (bisect at source Y 0.395), decimates to 1000 game verts / 733 tris, bakes base colour x half-strength AO with metallic areas lifted into a 256x256 diffuse, scales to 155/217 of the M9 game length, and writes the FBX in the same raw layout as Blender-made PZ pistols (Y-up file, unit scale 1, identity nodes; verified against Guns of Marz M92FS.fbx). Muzzle attachment offset printed by the script; `world` y set to the PPK lengthwise centre; `Bip01_Prop2` copied from vanilla Handgun03.
- Box art: vanilla icon pulled from `UI.pack` (parser in `tools/build_box_art.py`), red body recoloured green, ".380 ACP" lettered on front and side; listing images (icon/poster/preview) composed from the two icons.
- Recipes `WaltherPPKS_OpenBoxOfBullets380` / `WaltherPPKS_PackBullets380` live in `module Base` (new names, vanilla untouched) so `DoubleClickRecipe` resolves by plain name like vanilla.
- Deny rule is reachability-based: any table reachable from a denied key is never modified. Collateral (shared vanilla tables): `PistolCase1` (also the military pistol case) and `GloveBoxWorkJunk` (also police glove boxes) get no .380/PPK/S.
- B42.21 logs `NoSuchFileException` ERRORs for mods without `media/AnimSets` and `media/actiongroups`; placeholder `*_keep.txt` folders added in `42/` and `common/`.
- Dedicated server (`-nosteam`) does not scan `~/Zomboid/Workshop`, and junctioned mods produce NetChecksum `absPath:null` ERRORs; `tools/run_server_test.ps1` therefore runs the server against temporary real copies in `~/Zomboid/mods`. Result: 58 entries injected, 32 denied lists untouched, dev checks PASS (5106/0), no mod ERROR/WARN. Mod translations are not loaded by the dedicated server (control: dev gun also untranslated) -> display names still need the in-game check.
- Orchestrator verification (step-03): read every produced text file; added recipe I/O checks to `dev/WaltherPPKS_TestGun380/42/media/lua/server/WaltherPPKS_TestChecks.lua` (open 1 box -> 50 rounds, pack 50 rounds -> 1 box, via `getIntAmount`/`getOriginalLine` since possible-item lists resolve lazily). `tools/run_server_test.ps1` re-run: RESULT PASS (5112 passed, 0 failed); no mod ERROR/WARN. Matrix rows covered by automated checks: civilian half-chance, police/military skip, magazine guarantee, open, pack, test-gun ammo type. "Under 50 -> unavailable" follows from input amount 50; test-gun firing remains a manual in-game check.
- Post-playtest fix (2026-11-05): in-game console showed `attempted index: getItems of non-table: ItemPickerJava$ItemPickerContainer` from `giveMagazines` (30 times). Vanilla `ItemPickerJava.doRollItemInternal` fires `OnFillContainer("Container", <bag type>, ItemPickerContainer)` for bags rolled inside a container — a loot table, not an ItemContainer. Handler is now `WaltherPPKS.onFillContainer` and returns early unless `instanceof(container, "ItemContainer")`; the parent container's event still reaches nested bags. Added two dev checks (non-container and nil argument don't throw). Server test: RESULT PASS (5121/0), exit 0.
- Spec change (2026-11-05): damage 0.5-0.8 -> 0.6-1.0 (same as M9) per SPEC.md. Updated WaltherPPKS_gun.txt (MinDamage/MaxDamage + header), workshop.txt, dev damage check. Server test: RESULT PASS (5121/0), exit 0.
