# Equipment and starter icons

## Controls

Open Inventory and **click an owned gear item to equip it**. Click an occupied
equipment square to unequip it. No footer buttons are needed. Tools, armor and accessories choose their matching slot;
weapons choose the first empty weapon slot or swap weapon1 when all four are full.
Mouse hover and gamepad
selection show a separate name/description/rarity/stat card that follows the pointer
and stays inside the screen. Closing Inventory hides the card.

A swap returns the old item to the selected bag slot; it works even when the bag
is full. Unequipping into a full bag is refused without changing either item.
Crafting remains a placeholder. No crafting or tool/combat actions
are implied by equipping an item.

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

`ItemIcons.lua` draws five distinct stylized icons from layered local GUI geometry:
wood grain, leather wraps, bevelled metal, rivets, brass fittings and highlights.
Slots use rarity-tinted fills and stronger borders, not just colored names.
No image assets, uploads or external asset permissions are needed. Other items
keep name-based slot labels until icons are added. Inspecting an item shows its
rarity, properties and stat modifiers.

## Verification

50 portable Lua tests cover equipment stat application/removal, reconstruction,
transactional swaps, invalid/replayed requests, reserved sources, duplicate/broken
references, requirements, full bags and a fake-store save/reload round trip.
A real InventoryUI controller test drives clicks/hover through GUI adapters and
server equipment logic, including applying/removing bonuses. This is not a real
Roblox renderer or hit-test. Server request limiting now accepts a short burst
and returns an explicit message instead of silently discarding rapid actions.
Rojo builds and embeds all 21 scripts. Icon appearance, selection controls and
live Humanoid/stat updates still require Roblox Studio testing.
