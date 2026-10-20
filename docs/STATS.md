# Player stat contract

## Three categories

- **Definitive:** defaults plus equipment, skill, buff and other source modifiers.
- **Defined:** formula outputs. Direct modifiers are rejected; formula dependencies
  resolve in order, with missing references and circular dependencies rejected.
- **Dynamic:** current resource values. Session-only, bounded by defined maxima.

All quantities are server-owned. Client snapshots have schema version 3; saved profiles use version 2.
Derived/current stats are not persisted.
Farming XP is reconciled into existing profiles without resetting progress.

## Definitive defaults

| Stats | Default | Unit / limit |
| --- | --- | --- |
| Combat/Farming/Fishing/Mining/Foraging Fortune | 100 each | Percentage multiplier; resulting drop chance caps at 500% |
| Combat/Farming/Fishing/Mining/Foraging Wisdom | 100 each | XP percentage; capped at 500 = x5 |
| Vitality | 100 | Max health, 1:1; minimum 1 |
| HealthRegen | 5 | Health/second |
| Endurance | 100 | Max stamina, 1:1 |
| StaminaRegen | 5 | Stamina/second |
| Intelligence | 100 | Max mana, 1:1 |
| ManaRegen | 5 | Mana/second |
| AbilityDamage | 100 | Ability damage percentage; 100 = x1 |
| Defense | 0 | Reserved for future combat formula |
| CritDamage | 125 | Total critical-hit multiplier; 125 = x1.25 |
| CritChance | 1 | Percent; capped at 100 |
| Speed | 16 | Studs/second |
| BreakingPower | 0 | Allowed stone tier; activity integration pending |
| MiningSpeed | 0 | Mining damage/second |
| MiningSpread | 100 | Total blocks/action; capped at 2500 = 25 |
| Pristine | 0 | Quality-up chance percent; capped at 100 |
| Sweep | 0 | Tree blocks/action; activity integration pending |
| AxeStrength | 0 | Allowed tree tier; activity integration pending |
| MaxSize / MinSize | 0 each | Tool-supplied size limits; no fishing without a suitable tool |
| SeaCreatureChance / DoubleHookChance / TreasureChance | 0 each | Percent; capped at 100 |

Stats not otherwise capped have a provisional numerical ceiling of 1 billion;
all definitive stats are nonnegative. These are numeric safeguards, not finalized
balance decisions. Tier/count fields may receive fractional modifiers; the future
activity system must specify how tiers/targets are selected. Fishing size units,
quality levels and chance interactions are not yet defined.

## Rules

Each definitive stat uses:

`clamp((base + sum(flat)) * (1 + sum(percent)) * product(multiplier))`

Modifier `percent` uses fractions (`0.1` means +10%); chance and multiplier stats
use percentage points (`125` CritDamage means x1.25). Stable source IDs replace
old modifiers rather than stacking accidentally. Updates/removals validate the
whole composition before committing it.

- `MaxHealth = Vitality`
- `MaxStamina = Endurance`
- `MaxMana = Intelligence`
- `SprintSpeed = Speed * 1.5`
- `effectiveDropChance = min(500, baseChancePercent * Fortune / 100)`
- Drops: `floor(effectiveDropChance / 100)` guaranteed, then one Bernoulli roll
  for the remaining percentage. Each loot-table entry is evaluated independently;
  implementing the loot table is a later milestone.
- Wisdom multiplier: `min(Wisdom, 500) / 100`. No extra +1.
- Mining block allowance: `floor(MiningSpread / 100)` plus a remainder roll,
  capped at 25 total. Default 100 means one total block, not one additional block.
  No recursive spread. Adjacency, available blocks and tool restrictions must be
  enforced by the later mining system; the helper only returns an allowance.

Fortune itself is not capped at 500: 1000 Fortune on a 1% drop gives 10%, not 5%.
Only the final effective chance caps at 500% (five drops).

## Dynamic resources and movement

Health, Stamina and Mana start full when a session begins and on respawn. They
regenerate at their corresponding per-second rate, using actual elapsed Heartbeat
time in approximately 0.2-second updates. Regeneration stops at zero health and
never resurrects a dead character. No offline regeneration is calculated.

Raising a maximum does not refill its resource. Lowering it clamps the current
value. Failed spending leaves the resource unchanged. Current values are not
saved, and no inventory/equipment system grants modifier sources yet.

The server synchronizes health with Humanoid health. An intentionally empty
`StarterCharacterScripts/Health` Script replaces default Roblox regeneration to
avoid double healing. External server damage is reflected in the resource HUD.

Hold Shift, or tap the on-screen sprint toggle, for x1.5 Speed. No stamina drain
has been invented: a sprint stamina cost remains a future design decision.
The client requests only a boolean sprint state; the server determines speed.
This does not constitute comprehensive movement anti-cheat.

The old Studio debug reward/drain buttons and remotes have been removed. Use
server-side Humanoid damage in Studio to test health regeneration.

## Verification boundary

Portable Lua tests cover defaults, dependencies, modifier transactions, probability
boundaries, caps, regeneration, no free healing on max increases, and session
eligibility. Rojo source mapping includes the Health override. Humanoid events,
respawn, sprint input and HUD behavior still require Studio acceptance testing.
