- source_spec: `_bmad-output/implementation-artifacts/spec-walther-ppk-mod.md`
  summary: Confirm every PPK/S gets a magazine outside container fills (vehicle part containers, world/story spawns).
  evidence: Unverified (would be medium). Magazine guarantee hooks only OnFillContainer; settle by checking whether vehicle containers fire OnFillContainer during ItemPicker fill, e.g. find a PPK/S in a civilian glove box in game.
- source_spec: `_bmad-output/implementation-artifacts/spec-walther-ppk-mod.md`
  summary: Verify item and recipe display names (ItemName.json, Recipes.json) in game before each release.
  evidence: Dedicated server loads no mod translations, so the automated run always skips name checks; a key typo would ship raw IDs.
