# Foundation acceptance checks

Headless core tests are necessary but do not prove Roblox integration works.
Complete the following in Studio before moving this foundation into production.

## Temporary Studio mode (default)

1. Build/open the Rojo place, connect live sync and Play. Verify a baseplate,
   humanoid with 100 health/16 walk speed, loading completion, 0 coins and all stats.
2. Click the Studio reward button: coins increase by 10. Rapid clicking must not
   exceed one accepted reward per second. Respawn: HUD must not duplicate.
3. Stop and Play: coins return to zero and the temporary mode label is visible.
4. Start a two-player Studio test. Reward player A; B must remain unchanged.
5. No script errors in Output. Resize the viewport: scroll the full stats list.

## Private test experience with persistence

1. Use a separate private experience, enable Studio API access and PersistStudio.
2. Join, grant 10 coins, Stop, then Play: coins should remain. Check save warnings.
3. Verify StudioStore and ProductionStore differ. Published-server data should
   not appear in Studio, even when API access is enabled.
4. Test two-server contention on the same profile with controlled developer
   harnesses. A second owner must fail while the lease is valid. The old owner
   must never overwrite a successor after expiry.
5. Simulate service failures in a test adapter. No failed load may attach a blank
   profile. Expired sessions must stop rewards and disconnect.
6. Leave while loading and while autosaving; ensure late loads release ownership
   and final saves serialize after in-flight saves. Close with several players.
7. Test respawn before/after profile loading and initial snapshot requests.
8. In a published test server, verify no StudioGrantCoins remote exists.

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
- The HUD is a diagnostic starting point; no inventory/crafting interfaces exist.

References:
- https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing
- https://create.roblox.com/docs/cloud-services/data-stores
- https://create.roblox.com/docs/scripting/security/client-server-boundary
- https://rojo.space/docs/v7/getting-started/new-game/
