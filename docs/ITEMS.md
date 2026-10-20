# Item definitions and types

`ItemDefinitions.lua` is the source catalog keyed by permanent snake_case IDs.
`ItemTypes.lua` defines type policies and rarity colors. `ItemCatalog.lua`
validates/normalizes definitions on server and client startup and returns defensive
copies. Items are not granted just because they are defined.

## Types

| Kind | Subtype / location | Instance policy | Default stack limit |
| --- | --- | --- | --- |
| `tool` | `toolType`: hoe, pickaxe, axe, fishingRod | Unique gear | 1 |
| `armor` | `armorSlot`: helmet, chestplate, gloves, leggings, boots | Unique gear | 1 |
| `weapon` | `weaponType`: heavyMelee, lightMelee, magic, ranged | Unique gear; weapon1–weapon4 | 1 |
| `accessory` | `accessorySlot`: brooch, artifact, ring, bracelet, necklace | Unique gear | 1 |
| `talisman` | Future unlimited talisman bag | Unique item | 1 |
| `material` | Raw gathering resource | Stack | 9999 |
| `craftingComponent` | Refined/component resource | Stack | 9999 |
| `consumable` | `effectId` reference | Stack | 99 |
| `questItem` | Future quest systems | Stack; not tradable/droppable | 1 |

These stack limits and all example gear values are provisional configurable data,
not a Minecraft-style global stack rule. The unique-instance policy describes how
future inventory records must behave; instance creation is not implemented here.

## Common properties

- `name`, `description`, `icon`: display fields; icon is blank or an `rbxassetid://`
  reference. No uploaded icon assets are included.
- `rarity`: common, uncommon, rare, epic, legendary, mythic. Inventory slots use
  the corresponding color and inspection text.
- `maxStack`: positive integer, at most 1,000,000; unique gear must stay at one.
- `tradable`, `droppable`, `storable`: booleans; default true unless type forbids
  them. A definition cannot relax a type's explicit restriction.
- `tags`: string list for future filtering.
- `collection`: optional collection ID; does not award collection credit.
- `requirements`: optional `{gameLevel = 2, skills = {foraging = 4}}`.
  Combat skill IDs here are heavyMelee/lightMelee/magic/ranged.
- `abilityIds`: optional string references; no abilities are executed or resolved.

Gear and talismans can define `stats`, keyed by definitive stat ID with existing
flat/percent/multiplier operations. Defined stats and current resources cannot be
modified directly. Weapons require nonnegative `baseDamage`. Consumables require
an `effectId`. These values do not cause damage or healing by themselves.

```lua
example_pickaxe = {
    name = "Example Pickaxe",
    kind = "tool",
    toolType = "pickaxe",
    rarity = "rare",
    requirements = {gameLevel = 2, skills = {mining = 3}},
    stats = {
        BreakingPower = {flat = 2},
        MiningSpeed = {flat = 30},
        MiningFortune = {flat = 10},
    },
    tags = {"mining", "tool"},
}
```

## Catalog queries

`get(id)` returns a normalized copy or nil. `all()` returns a copy of the whole
catalog. `canEquip(id, slot)` checks type/slot compatibility only; it does not
check player requirements, item ownership, instance state or perform equipping.

The catalog rejects unknown properties, incompatible subtypes, invalid stack
limits, unsupported stats/operations, malformed requirements and non-finite data.
Unknown item IDs already present in a saved inventory retain their fallback labels;
this change does not delete or migrate saved items.

## Scope

Twenty examples cover all nine types, all tool types, five armor slots and four
weapon types. Item moving/stack splitting, instance creation, item use, crafting,
trade enforcement, equipped stat application and acquisition are deferred.
Next inventory work should store definition IDs separately from unique instance
IDs and enforce these policies on the server.
