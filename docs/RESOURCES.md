# Placeable resources: oak trees and raspberry bushes

## Place your trees in Studio

After pulling the repo and connecting Rojo, expand:

**Workspace → Home → ResourceInteractions → foraging → oak**

1. Put each tree **Model** inside `oak`. Model names can be anything. A single
   BasePart is also supported; folders can organize groups of trees.
2. Anchor the interaction part. Anchoring all tree parts is recommended. The
   server refuses interaction with an unanchored target.
3. Prefer a trunk BasePart named **InteractionPart**. Otherwise the controller
   uses the model's PrimaryPart or first descendant BasePart. Put the interaction
   part near the player, not high in the canopy. Nested Models count as part of
   their outer tree, so a tree gets one prompt rather than a prompt per branch.
4. Press Play, open Inventory and click the Starter Axe to equip it. Walk within
   10 studs of the trunk and hold the native **Harvest** prompt for 1 second.
   Keyboard, touch and gamepad use Roblox's standard prompt controls.
5. Open **Collections** above Inventory/Stats to see harvested totals, foraging XP
   and the Oak Talisman bag count/bonus. Harvest results appear at the top of the screen.

No extra scripts, tags or attributes are required on individual trees. Existing
models and newly inserted models bind automatically while the server runs. Empty
models bind when their first BasePart is added. Set InteractionPart/PrimaryPart
before Play; restart Play after changing a bound model's interaction-part choice.
Do not put a pre-existing Harvest prompt or a reward script inside the model.

The project creates folders for **foraging, mining, farming, fishing and combat**.
Combat also reserves **heavyMelee, lightMelee, magic and ranged** subfolders. `foraging/oak` and `foraging/raspberry` have activity definitions; other folders are placement
space for upcoming systems. Resources belong in Workspace, not ServerStorage.

These folders preserve unknown Studio instances during Rojo synchronization.
**Save the Studio place to retain your placed models.** They are not exported back
into the Git repository by Rojo, and rebuilding/opening the empty place file does
not recover models from an older saved place. Save/publish outside Play mode;
models placed during Play disappear when the play session ends.

## Raspberry bushes

Place bush Models under **Workspace → Home → ResourceInteractions → foraging → raspberry**.
Use the same anchored InteractionPart/PrimaryPart convention described above.
Press **E once nearby** to Pick; no axe, hoe or other tool is required, and no
hold is necessary. Touch and gamepad use the native prompt button.

Each successful pick independently awards **Raspberry (100%)** and rolls
**Raspberry Thorn (25%)**, before ForagingFortune. Both have separate collection
counters and enchanted item definitions. These rates are provisional because no
raspberry loot rates were specified. Each pick gives **3 base foraging XP**,
scaled by wisdom with fractional carry, using the same atomic reward/save flow
as oak. Raspberries are crafting materials; eating/healing is not implemented.

The bush replenishes after **15 seconds per player**. Attempts while it regrows
show how many seconds remain. Other players have independent harvest timers.
The bush stays visible throughout; this implements timed reward regeneration,
not a berry disappearance/growth animation. The timer is server-session state.
Timing, XP and drop chances live in `ResourceDefinitions.lua`.

Enchanted Raspberry and Enchanted Raspberry Thorn use the same provisional
160-to-1 conversion metadata as oak. Executable crafting is still pending.

Studio check: with the axe unequipped, approach a bush and tap E. Confirm a
raspberry reward, a thorn chance, collection increments and foraging XP. Tap
again to see the regrowth countdown; picking must succeed again after 15 seconds.
Also test walls, full bags and two players independently harvesting the bush.

## Oak rewards

Every successful interaction independently rolls every entry:

| Item | Base chance at 100 fortune | Collection | Enchanted variant |
| --- | ---: | --- | --- |
| Oak Wood | 100% | Oak Wood | Enchanted Oak Wood |
| Oak Leaves | 50% | Oak Leaves | Enchanted Oak Leaves |
| Oak Stick | 25% | Oak Stick | Enchanted Oak Stick |
| Oak Sap | 10% | Oak Sap | Enchanted Oak Sap |
| Oak Core | 1% | Oak Core | Enchanted Oak Core |
| Oak Talisman | 0.1% | None | None |

These are independent Bernoulli rolls, not a weighted table that selects one item.
An ordinary roll awards one item; fortune can guarantee multiple copies plus a
fractional extra copy. Effective chance is `baseChance × fortune / 100`, capped
at 500% **per entry**. For example, 200 fortune gives two wood, one leaf and a 50%
stick chance. The talisman also benefits from fortune. A 0.1% chance is not a
promise that every thousand trees will award one.

Raw materials go into stackable bag slots and their own lifetime collection
counters increase by the quantity actually awarded after fortune. Crafting,
transferring and ordinary server inventory grants do not add collection credit.
The permanent wood ID is still `oak_log`, with the existing `oak` collection ID;
only its display name changes to Oak Wood.

Talismans automatically enter the unlimited-slot talisman bag. Duplicate copies
are counted; the existing Oak Talisman +5 ForagingFortune bonus applies once per
player and reconstructs on rejoin. There is no talisman collection or enchanted
version. Unknown legacy talisman entries remain preserved without invented effects.

Every successful harvest gives **10 base foraging XP**, scaled by ForagingWisdom
(up to 5×). Fractional XP carries forward without rounding loss. XP is stored;
no skill level formula, collection milestones or collection rewards have been
invented. A tree has a **10-second cooldown per player**. It stays visible and
other players have their own cooldown. No chopping animation, tree destruction,
Sweep multi-tree action or temporary visual depletion is implemented yet.

Hold time, range, XP, cooldown, tool requirements and loot are editable in
`src/shared/ResourceDefinitions.lua`; these timing/XP values are provisional.
Oak requires an equipped axe and AxeStrength at least 1.

All five enchanted items are defined and linked in `CollectionDefinitions.lua`.
The provisional conversion data is 160 raw → 1 enchanted, ready for the crafting
system. **Conversion/crafting controls and recipes are not executable yet**;
enchanted variants do not randomly drop from these trees.

## Server checks and save behavior

The controller independently checks an active profile, a living character,
distance, anchored target, raycast visibility, hold elapsed time, rate limits and
per-player node cooldown. Native prompt events are treated as requests rather
than proof of valid interaction. See Roblox's [client/server security guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary).
Only trusted resource IDs and server RNG reach the reward planner; clients cannot
supply a loot table, chance, amount or XP reward.

The planner first checks room for **all possible drops**, including stack headroom,
before drawing RNG. At baseline this can require five raw-material slots if no
matching stacks exist. A full bag rejects the whole harvest: no partial rewards,
XP, collection credit or hidden rare-drop rerolls. Failure does not start cooldown.
Item rewards, counters, talisman ownership and XP commit as one in-memory profile
change only after all validation succeeds. The existing autosave/leave/shutdown
flow saves them together. Server crashes can still lose progress since the last
successful save. Cooldowns are server-session state and reset after rejoining.

## Verification

Portable Lua tests exercise the real loot planner and the real model controller
through a small instance/event adapter: model grouping, late model population,
removal, invalid holds, distance/death/visibility checks, cooldown isolation,
full-bag behavior, exact probability boundaries, fortune, fractional wisdom XP,
collection credit, duplicate talismans and profile reconstruction. This adapter
does not emulate Roblox replication, prompt event scheduling or physics.

Studio acceptance still required: place a multi-part oak near spawn; confirm one
prompt, axe requirement, 1s hold, loot messages, collections and cooldown. Test two
players, touch/controller input, walls, dead characters, full bags, model removal
and rejoin with real test persistence enabled. Verify your placed trees survive
Rojo sync and saving/reopening the Studio place.
