# Player data, schema 2

The existing atomic UpdateAsync join operation checks for a record, creates and
saves a template if absent, or validates/migrates/reconciles and saves the repaired
record if present. Loading failure does not create a replacement blank save.
Session locking, 60-second autosaves and leave/shutdown saves remain enabled.

## Saved structure

```text
schemaVersion = 2
createdAt, updatedAt
coins = 0
bank = 0
gameXP = 0
skills
  farming, foraging, mining, fishing: { level = 1, xp = 0 }
  combat
    heavyMelee, lightMelee, magic, ranged: { level = 1, xp = 0 }
talismans = {}
museum = {}
storage = { stacks = {}, unique = {} }
equipment
  helmet, chestplate, gloves, leggings, boots
  brooch, artifact, ring, bracelet, necklace
  hoe, pickaxe, axe, fishingRod
  weapon1, weapon2, weapon3, weapon4
inventory = { capacity = 30, slots = {} }
quests = {}
collections = {}
unlocks = {}
legacy = {}
```

Each equipment slot starts as `false` (empty), so every slot survives JSON storage.
An occupied slot stores a nonempty item-instance ID. Instance definitions and
item/equipment management will be implemented in the inventory milestone.
Inventory slot keys are strings, consistent with the profile's JSON-map format.
Quests, museum donations and talisman ownership currently have empty map containers;
their individual record formats and acquisition mechanics are deliberately deferred.

Game level is derived as `1 + gameXP / 100`: 0 XP = 1.00, 1 XP = 1.01,
100 XP = 2.00. Only integer XP is saved to avoid incremental floating-point drift.
No XP reward sources, skill-level formulas, talisman auto-collection, donations,
quests, bank transactions or equipment effects were added in this milestone.

## Repair/migration policy

- Version 1 coins move from `currencies.coins` to top-level `coins`.
- Deprecated currency values are retained under `legacy.currencies`.
- A deprecated aggregate combat XP/level becomes `legacy.combat`; four new combat
  skills start at level 1 / 0 XP. There is no fair split rule yet, so progress is
  retained rather than duplicated or discarded.
- Missing current fields are copied from independent defaults. Existing progress,
  extension fields and recognized item references remain unchanged.
- Running reconciliation twice produces the same result; no repeated rewards.
- Malformed values and unsupported schema versions are refused, not silently
  replaced with zero. Future deprecations require explicit migration rules.
- Keep the current DataStore names ending in `_v1`: schema version and store name
  are separate concepts. Renaming stores would make existing profiles disappear.

## UI

The old debug panel and reward/drain remotes have been removed. Bottom-left
resource bars show health, stamina and mana, with Defense, coins, bank and game
level. A TEST DATA marker identifies temporary Studio mode.

Inventory and Stats buttons open dismissible windows. Keyboard shortcuts: I for
Inventory, C for Stats, Shift for sprint. Clicking outside or using the close
button dismisses a window. Inventory is read-only and displays 30 square slots in six columns/five rows,
a 3x3 crafting grid to the left, and all 18 equipment slots to the right.
Crafting inputs/output are placeholders; selecting any slot inspects its label.
The attached three-panel layout scales down and scrolls on narrow screens; it is not an item-management implementation. Stats lists
all definitive, defined and dynamic stats.

## Real saving in Studio

Default Studio mode still uses temporary data. To test persistent saves, use a
private published testing experience, enable Studio API services access, and set
`PersistStudio = true` in `src/server/Config.lua`. Studio and production use separate
stores. Published servers already use DataStore persistence without that switch.

## Acceptance

1. Open both windows, scroll through every stat and equipment slot, dismiss/reopen.
2. Check the bottom-left HUD at desktop and narrow/mobile viewport sizes.
3. Rejoin a private persistent test session; balances and profile maps must survive.
4. Test a version 1 record with coins and combat XP; check preservation and archive.
5. Remove a default field from a test record; joining should repair and save it.
6. Confirm no StudioGrantCoins or StudioDrainResources remote exists anymore.
7. Test regeneration using server-side Humanoid damage; no debug buttons remain.

Headless tests and Rojo mapping pass. Actual updated GUI layout, engine lifecycle
and real DataStore round trips still require Roblox Studio testing.
