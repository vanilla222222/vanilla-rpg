# Content editing guide

The development goal is **fast content updates, with most time spent on map
design**. Put routine content choices in clear definition files. Add reusable
behavior to systems when a new mechanic needs code, then let future content reuse
it. Avoid scripts copied into every tree, bush, item or island.

## Current editing points

| Change | Edit |
| --- | --- |
| Item name, description, rarity, stats, requirements | `src/shared/ItemDefinitions.lua` |
| Item image or name-only fallback | `src/shared/ItemTextures.lua` |
| Resource drops, chances, XP, required tool, range and regrowth | `src/shared/ResourceDefinitions.lua` |
| Raw collection and enchanted item associations | `src/shared/CollectionDefinitions.lua` |
| Global stat defaults, limits and derived formulas | `src/shared/StatDefinitions.lua` |
| World models and terrain | Studio; save the place |

ItemTextures lists all current items with their permanent IDs, readable names and
`decalId=nil`. Nil means no image: show the full item name. Replace just that field
when you have artwork. To introduce a new item, add its definition and matching
texture entry; keep its permanent ID stable after players acquire it.

## Reuse existing resources

Place anchored oak Models in
`Workspace/Home/ResourceInteractions/foraging/oak`, or raspberry bush Models in
`Workspace/Home/ResourceInteractions/foraging/raspberry`. Give each model a trunk
or nearby BasePart named `InteractionPart`, or set its PrimaryPart. The controller
adds the correct prompt and handles rewards automatically. No individual model
script is needed. Nested folders can organize groups of models.

Edit a resource's named definition to change its behavior everywhere that type
is used. For example, `raspberry.cooldownSeconds=15` controls its timed regrowth;
`holdSeconds=0` means tap to interact; no toolSlot/requiredStat/requiredValue means
no tool is required. Oak keeps its axe requirement and held interaction. Loot
entries roll independently and use the resource's configured fortune and wisdom.
See [resource details](RESOURCES.md) for supported fields and placement checks.

## Adding another gathering resource

1. Add its raw items in ItemDefinitions and their optional artwork placeholders
   in ItemTextures. Add corresponding collection entries; enchanted definitions
   are separate items, with executable crafting still pending.
2. Copy an existing ResourceDefinitions entry, give it a permanent ID and folder
   path, then edit its loot, skill, tool policy, timing and XP. Omit all three
   tool requirement fields for hand gathering.
3. In Studio, add the matching folder under ResourceInteractions and place models.
   The existing parent folders preserve manually placed children during Rojo
   sync. Define the folder in default.project.json as well if new empty builds
   should include it automatically; set `$ignoreUnknownInstances=true`.
4. Restart Play to load definition/module edits. Check prompts, loot, collections,
   inventory capacity and regrowth. Save your Studio place outside Play.

## Island direction

Island-specific content registries, portals and island unlocking are not yet
implemented. The intended authoring workflow is to reuse resource/item IDs and
configure island content rather than duplicate gameplay scripts. The current
resource controller discovers the folders configured at server startup; it does
not automatically scan arbitrary future island hierarchies. Island support must
preserve these authoring principles when it is implemented.

Keep balance values explicit, validate definitions before granting rewards, and
keep server authority in shared systems. Adding ordinary content should not
require editing inventory UI, persistence or loot application code.
