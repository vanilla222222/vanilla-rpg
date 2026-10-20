-- Permanent IDs. Example values are provisional; no items are automatically granted.
-- ItemCatalog fills defaults and validates these records on server/client startup.
local items = {
    oak_log={name="Oak Log",kind="material",collection="oak",tags={"wood","foraging"},description="Basic wood harvested from oak trees."},
    stone={name="Stone",kind="material",collection="stone",tags={"mining"},description="A basic building and crafting material."},
    refined_wood={name="Refined Wood",kind="craftingComponent",rarity="uncommon",tags={"wood","component"}},
    starter_axe={name="Starter Axe",kind="tool",toolType="axe",stats={AxeStrength={flat=1},Sweep={flat=1}}},
    starter_pickaxe={name="Starter Pickaxe",kind="tool",toolType="pickaxe",stats={BreakingPower={flat=1},MiningSpeed={flat=10}}},
    starter_hoe={name="Starter Hoe",kind="tool",toolType="hoe",stats={FarmingFortune={flat=5}}},
    starter_fishing_rod={name="Starter Fishing Rod",kind="tool",toolType="fishingRod",stats={MinSize={flat=1},MaxSize={flat=5}}},
    starter_sword={name="Starter Sword",kind="weapon",weaponType="lightMelee",baseDamage=5},
    starter_greatsword={name="Starter Greatsword",kind="weapon",weaponType="heavyMelee",baseDamage=8},
    starter_wand={name="Starter Wand",kind="weapon",weaponType="magic",baseDamage=4,stats={Intelligence={flat=10}}},
    starter_bow={name="Starter Bow",kind="weapon",weaponType="ranged",baseDamage=5},
    copper_ring={name="Copper Ring",kind="accessory",accessorySlot="ring",stats={Defense={flat=1}}},
    oak_talisman={name="Oak Talisman",kind="talisman",rarity="uncommon",stats={ForagingFortune={flat=5}},tags={"foraging"}},
    health_tonic={name="Health Tonic",kind="consumable",effectId="restore_health",description="Effect implementation pending."},
    sealed_letter={name="Sealed Letter",kind="questItem",description="A quest object. Quest implementation pending."},
}
for _,slot in ipairs({"helmet","chestplate","gloves","leggings","boots"}) do
    items["starter_"..slot]={name="Starter "..slot:gsub("^%l",string.upper),kind="armor",armorSlot=slot,
        stats={Vitality={flat=5},Defense={flat=1}}}
end
return items
