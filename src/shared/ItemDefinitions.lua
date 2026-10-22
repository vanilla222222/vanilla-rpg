-- Permanent IDs. Example values are provisional; StarterItems grants the five-item starter kit once.
-- ItemCatalog fills defaults and validates these records on server/client startup.
local items = {
    oak_log={name="Oak Wood",kind="material",collection="oak",tags={"wood","foraging"},description="Basic wood harvested from oak trees."},
    stone={name="Stone",kind="material",collection="stone",tags={"mining"},description="A basic building and crafting material."},
    refined_wood={name="Refined Wood",kind="craftingComponent",rarity="uncommon",tags={"wood","component"}},
    starter_axe={description="A riveted iron head on a wrapped oak handle. Built for your first trees.",name="Starter Axe",kind="tool",toolType="axe",stats={AxeStrength={flat=1},Sweep={flat=1}}},
    starter_pickaxe={description="A twin-point iron pick with a reinforced socket and sturdy wooden grip.",name="Starter Pickaxe",kind="tool",toolType="pickaxe",stats={BreakingPower={flat=1},MiningSpeed={flat=10}}},
    starter_hoe={description="An angled iron blade fixed to an oak shaft. A humble start for a growing farm.",name="Starter Hoe",kind="tool",toolType="hoe",stats={FarmingFortune={flat=5}}},
    starter_fishing_rod={description="A flexible wooden rod with a brass reel, threaded line and iron hook.",name="Starter Fishing Rod",kind="tool",toolType="fishingRod",stats={MinSize={flat=1},MaxSize={flat=5}}},
    starter_sword={description="A simple iron blade with a brass guard and leather-wrapped grip.",name="Starter Sword",kind="weapon",weaponType="lightMelee",baseDamage=5},
    starter_greatsword={name="Starter Greatsword",kind="weapon",weaponType="heavyMelee",baseDamage=8},
    starter_wand={name="Starter Wand",kind="weapon",weaponType="magic",baseDamage=4,stats={Intelligence={flat=10}}},
    starter_bow={name="Starter Bow",kind="weapon",weaponType="ranged",baseDamage=5},
    copper_ring={name="Copper Ring",kind="accessory",accessorySlot="ring",stats={Defense={flat=1}}},
    oak_talisman={name="Oak Talisman",kind="talisman",rarity="uncommon",stats={ForagingFortune={flat=5}},tags={"foraging"}},
    health_tonic={name="Health Tonic",kind="consumable",effectId="restore_health",description="Effect implementation pending."},
    sealed_letter={name="Sealed Letter",kind="questItem",description="A quest object. Quest implementation pending."},
}
local oakMaterials={
    oak_log={name='Oak Wood',collection='oak',rarity='common'},
    oak_leaves={name='Oak Leaves',collection='oak_leaves',rarity='common'},
    oak_stick={name='Oak Stick',collection='oak_stick',rarity='common'},
    oak_sap={name='Oak Sap',collection='oak_sap',rarity='uncommon'},
    oak_core={name='Oak Core',collection='oak_core',rarity='rare'},
}
for id,entry in pairs(oakMaterials)do
    items[id]={name=entry.name,kind='material',collection=entry.collection,rarity=entry.rarity,
        tags={'oak','foraging'},description='Gathered from oak trees. Tracks its own collection.'}
    items['enchanted_'..id]={name='Enchanted '..entry.name,kind='craftingComponent',collection=entry.collection,
        rarity='rare',tags={'oak','foraging','enchanted'},description='An enchanted form of '..entry.name..'. Crafting integration is pending.'}
end
items.oak_talisman.description='A rare oak charm. Automatically joins the talisman bag; its foraging bonus applies once.'
for _,slot in ipairs({"helmet","chestplate","gloves","leggings","boots"}) do
    items["starter_"..slot]={name="Starter "..slot:gsub("^%l",string.upper),kind="armor",armorSlot=slot,
        stats={Vitality={flat=5},Defense={flat=1}}}
end
return items
