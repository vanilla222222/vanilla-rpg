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
- Inventory is read-only; item management and crafting interfaces are deferred.

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

Probability helpers remain headless-tested; their activity systems are deferred.
