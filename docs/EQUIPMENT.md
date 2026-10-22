# Equipment and item images

## Controls

Open Inventory and **click an owned gear item to equip it**. Click an occupied
equipment square to unequip it. Select Equip mode first. No footer buttons are needed. Tools, armor and accessories choose their matching slot;
weapons choose the first empty weapon slot or swap weapon1 when all four are full.
Mouse hover and gamepad
selection show a separate name/description/rarity/stat card that follows the pointer
and stays inside the screen. Closing Inventory hides the card.

A swap returns the old item to the selected bag slot; it works even when the bag
is full. Unequipping into a full bag is refused without changing either item.
Crafting remains a placeholder. The axe enables [oak harvesting](RESOURCES.md); other tool/combat actions
are pending.

## Ownership and persistence

`equipment` still maps each slot to an instance ID or false. New optional
`equipmentItems` contains the full records for equipped instances, keyed by ID.
Bag records move into that map when equipped and return to the bag when unequipped;
they are never copied into multiple ownership locations. Older profiles reconcile
an empty map without changing their schema/store names. All equipment records are
saved by the existing autosave, leave and shutdown flow.

The server checks its own bag record, unique quantity/instance ID, duplicate
ownership, catalog compatibility and level/skill requirements. Clients only send
an action and slot identifiers, never item definitions or stat values. Requests
are rate-limited. Missing, duplicate or broken equipment references fail closed.
The join path releases a session and disconnects instead of hanging on an attach
failure. Unknown/corrupt data is not replaced with a new empty profile.

Each occupied equipment slot contributes a reserved `equipment:<slot>` modifier
source using the trusted item definition. The entire candidate profile and stat
composition validate before committing a swap. These sources rebuild on join and
are removed on unequip. Other modifier sources remain intact. Raising maximum
health does not instantly heal the player; removing gear clamps excess health.

All eighteen slots currently contribute their definition's stat modifiers,
including all four weapon slots. There is no active-hand weapon system yet.
Weapon base damage is an item property, displayed separately in Stats and item
inspection; it is not summed into a new global stat or used to attack anything.

## Starter equipment

| Item | Equipped properties |
| --- | --- |
| Starter Axe | AxeStrength +1; Sweep +1 |
| Starter Pickaxe | BreakingPower +1; MiningSpeed +10 |
| Starter Sword | Base damage 5, shown as a weapon property |
| Starter Hoe | FarmingFortune +5 (100 → 105) |
| Starter Fishing Rod | MinSize +1; MaxSize +5 |

Item artwork is configured in **`src/shared/ItemTextures.lua`**. It lists every
permanent item ID with a readable name and a `decalId` placeholder. `nil` is Lua's
null value: the slot shows the full item name. All entries start as `nil`.

```lua
starter_axe={name="Starter Axe",decalId=nil},
-- To assign artwork, replace nil with your image asset ID:
-- starter_axe={name="Starter Axe",decalId="rbxassetid://123456789"},
```

Use a positive image asset ID, a numeric string, or `rbxassetid://...`. For an
uploaded Decal, copy the image ID from its Texture property. The entry's `name`
is an editing label; change canonical names in `ItemDefinitions.lua`. No image
assets are uploaded, generated or assigned automatically. The old procedural
renderer has been removed. The legacy catalog `icon` field is retained for
compatibility but is not read by inventory/equipment; this central file controls
slot artwork.

`ItemImages.lua` renders configured image assets in bag and equipment slots.
Missing entries, nil/empty placeholders, zero and malformed IDs use full text
names; known item rarity colors, quantity labels and hover cards remain. An
assigned asset still needs appropriate Roblox permissions to load; the engine's
image availability is not verified by the numeric ID parser. Stop and restart
Play after editing the texture file so the required module reloads.

## Verification

Portable Lua tests cover equipment stat application/removal, reconstruction,
transactional swaps, invalid/replayed requests, reserved sources, duplicate/broken
references, requirements, full bags and a fake-store save/reload round trip.
A real InventoryUI controller test drives clicks/hover through GUI adapters and
server equipment logic, including applying/removing bonuses. This is not a real
Roblox renderer or hit-test. Server request limiting now accepts a short burst
and returns an explicit message instead of silently discarding rapid actions.
Rojo builds and embeds all source scripts. Icon appearance, selection controls and
live Humanoid/stat updates still require Roblox Studio testing.

Known talismans in the automatic bag contribute reserved `talisman:<id>` modifiers.
Copies count as ownership but do not multiply a passive bonus. These modifiers
rebuild on join alongside equipment and cannot be replaced by other sources.
