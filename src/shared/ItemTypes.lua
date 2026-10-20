-- Policies describe future inventory behavior; this module does not move/use items.
return {
    kinds = {
        tool = {stackable=false, maxStack=1, stats=true, subtype="toolType", values={hoe=true,pickaxe=true,axe=true,fishingRod=true}},
        armor = {stackable=false, maxStack=1, stats=true, subtype="armorSlot", values={helmet=true,chestplate=true,gloves=true,leggings=true,boots=true}},
        weapon = {stackable=false, maxStack=1, stats=true, subtype="weaponType", values={heavyMelee=true,lightMelee=true,magic=true,ranged=true}},
        accessory = {stackable=false, maxStack=1, stats=true, subtype="accessorySlot", values={brooch=true,artifact=true,ring=true,bracelet=true,necklace=true}},
        talisman = {stackable=false, maxStack=1, stats=true},
        material = {stackable=true, maxStack=9999},
        craftingComponent = {stackable=true, maxStack=9999},
        consumable = {stackable=true, maxStack=99},
        questItem = {stackable=true, maxStack=1, tradable=false, droppable=false},
    },
    rarities = {
        common={label="Common",color={190,202,215}}, uncommon={label="Uncommon",color={103,210,142}},
        rare={label="Rare",color={105,170,245}}, epic={label="Epic",color={191,127,245}},
        legendary={label="Legendary",color={246,188,83}}, mythic={label="Mythic",color={243,117,177}},
    },
}
