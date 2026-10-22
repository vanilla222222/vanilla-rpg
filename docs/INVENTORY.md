# Inventory transfers and level expansion

## Player controls

Inventory keeps six columns and five rows visible. Use the page arrows for extra
slots. Level 1.00 starts with 30 slots; 1.99 still has 30; 2.00 has 31; 3.00 has 32.
The server derives the minimum capacity from `30 + floor(gameXP / 100)`. Previously
saved larger capacities and occupied high slots are preserved so no item is hidden
or removed during reconciliation. Capacity does not shrink if XP is later reduced.

Modes above the bag:

- **Equip:** click bag gear to equip; click equipped gear to unequip.
- **Move / Swap:** select the source then destination. Empty destinations receive
  the item; compatible stacks merge; different items swap whole slots.
- **Split half:** select a stack with at least two items, then an empty destination.
  Floor(quantity / 2) moves; the source keeps the remainder.
- **Merge:** select a source stack then a compatible destination stack. Transfer
  stops at the destination's stack limit, leaving excess in the source.

Click the selected source again to cancel, or choose a different mode. Source
selection can span pages. Locked squares on the last page cannot receive items.
Slots show the correct absolute index. Rarity, hover cards and equipment bonuses
continue to work independently of the selected transfer mode.

## Authority and conservation

Only the server owns items. Clients send action, source, destination, optional
quantity and the last observed inventory revision. They cannot supply item records,
choose instance IDs, grant stacks or award XP through a remote.

Each operation validates the full candidate before committing a copied profile.
A failed/full/incompatible/invalid operation leaves all records untouched. Unique
gear keeps its instance ID and cannot be split or merged. Stack metadata must match
exactly except for the top-level stack quantity; quality/binding/custom fields are
preserved on movement and splitting. Different metadata is never silently erased.

Every successful inventory or equipment transfer increments `inventory.revision`.
A stale client request is rejected with a retry message. Source selection resets
when a snapshot changes that revision. Inventory and equipment share a bounded
server request budget. This protects against stale clicks and rapid transfer abuse;
it is not a claim of comprehensive anti-cheat verification.

Join now validates known item records, stack quantities, unique IDs and equipped
references before committing the atomic load operation. Invalid saves are refused
without overwriting them. Restore missing catalog definitions or repair corrupt
records through controlled development tools; nothing is silently deleted.

## Server APIs for later activities

`PlayerService.grantStack(userId, itemId, quantity)` fills compatible default stacks
then free slots, up to one million units per call. If the complete reward cannot
fit, nothing is granted. `removeStack` similarly refuses an insufficient removal
without consuming a partial amount. Neither awards collection or skill XP.

`grantGameXP(userId, positiveInteger)` awards exact integer XP and reconciles the
new slot capacity. No gameplay XP source or client reward endpoint is added here.
`changeInventory` performs validated transfers. All mutation APIs require an active
unexpired session. General unique-item creation remains a future activity service.

Only 30 slot controls are created, irrespective of total capacity. Pages re-use
those controls; future high levels do not allocate huge GUI trees. Starter-kit
allocation also stops after finding five free slots instead of scanning the entire
capacity. Platform profile-size limits still apply despite an expanding bag.

## Verification

61 core/controller tests pass, including 1,200 seeded transfer attempts with
conservation checks after every accepted or rejected operation, metadata matching,
full bags, partial merge overflow, stale revisions and whole-level boundaries.
The real InventoryUI controller runs against GUI adapters and server services to
split across pages, merge back and move, alongside equip/unequip and hover checks.
Rojo builds/maps 22 scripts. Actual rendering, native input, server scheduling and
real DataStore persistence still require Studio testing.
