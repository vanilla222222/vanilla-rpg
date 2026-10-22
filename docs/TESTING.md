# Foundation acceptance checks

Headless core tests are necessary but do not prove Roblox integration works.
Complete the following in Studio before moving this foundation into production.

## Current UI and persistence checks

Follow [PLAYER-DATA.md](PLAYER-DATA.md) for the current UI, migration and save
acceptance checklist. The earlier Studio debug reward/drain controls were removed.

Use a separate private experience to test real DataStore round trips, contention,
failed loads, leave-during-load, autosave/leave serialization and shutdown. Confirm
temporary mode resets on Stop/Play, while persistent mode retains saved progress.
No old Studio reward/drain remote should exist in either mode.

## Known boundaries

- Up to one autosave interval of progress can be lost on server failure. Saves
  and shutdown are best effort; request retries cannot guarantee durability.
- Crashed-server leases can block a rejoin for up to ten minutes. No lock stealing
  before expiry, manual data reset command or trading is implemented.
- This initial implementation has no profile-size/sharding management. Do not
  populate unlimited unique records. Item-instance schema/validation comes next.
- Stat modifiers are server-memory derived state; equipment/skill systems must
  rebuild them from saved progression. Modifier buffs are not persisted yet.
- Currency counts use exact integers up to 2^53−1, not arbitrary precision.
- Equip/unequip and stack transfers are available; oak gathering is available; crafting is deferred.

References:
- https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing
- https://create.roblox.com/docs/cloud-services/data-stores
- https://create.roblox.com/docs/scripting/security/client-server-boundary
- https://rojo.space/docs/v7/getting-started/new-game/

## Stat categories and resources

Check all 32 definitive stats, four defined stats and three dynamic resources in
the Stats window. In Studio Server command bar use
`game.Players:GetPlayers()[1].Character.Humanoid:TakeDamage(20)` to test 5/s health
regeneration. Test respawn, Shift/touch sprint, focus release and maximum changes.
Increasing a resource maximum must not instantly refill it. No player-facing
debug reward or resource-drain buttons remain.

Probability helpers are used by oak harvesting. Other activity systems remain deferred.

## Equipment and icons

Check the five starter icons in the bag. Equip every starter item, open Stats and
verify the properties listed in EQUIPMENT.md. Unequip to remove bonuses. Repeat
with persistent test data and rejoin: equipped ownership and bonuses must survive.
Test a full bag and wrong target slot; no item should disappear or duplicate.
The sword has a damage property but does not perform attacks yet.

## Hover cards and direct equip

Hover each starter item: inspect name, description, rarity, damage/bonuses in the
small card. Check it stays on screen near every edge and hides when closing the
window. Click each bag item directly, then each equipped item directly; verify
slot movement and bonuses. Check this at a small viewport without accessing footer
buttons. Verify rapid ordinary clicks are not silently lost. If an operation fails,
copy the server-side `Equipment request failed` Output message for diagnosis.
Inspect rarity fills and the revised icons at normal and reduced UI scale.

## Inventory transfers and expansion

Use a controlled server fixture containing two material stacks and unique tools.
Test Move/Swap, Split half and Merge, including full destinations and failed requests.
Verify saved totals and instance IDs before/after, then rejoin a persistent test.
Award 100 game XP through the server API: page two should unlock slot 31. Split a
stack into that slot and merge it back onto page one. Old larger bags must not
shrink. Keep Stats and hover checks working after equipment changes. These engine
checks have not been run in this environment.

## Placeable resources

Follow [RESOURCES.md](RESOURCES.md) for placement, controls, loot rules and the
Studio acceptance checklist. Native prompts, raycasts, replication and real
DataStore persistence remain unverified in this host.
