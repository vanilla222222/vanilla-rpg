-- Studio model folders are relative to Workspace/Home/ResourceInteractions.
return {
    raspberry={name='Raspberry Bush',path={'foraging','raspberry'},skill='foraging',
        fortune='ForagingFortune',wisdom='ForagingWisdom',baseXP=3,holdSeconds=0,distance=10,cooldownSeconds=15,actionText='Pick',
        loot={{itemId='raspberry',chance=100},{itemId='raspberry_thorn',chance=25}}},
    oak={name='Oak Tree',path={'foraging','oak'},skill='foraging',toolSlot='axe',requiredStat='AxeStrength',requiredValue=1,
        fortune='ForagingFortune',wisdom='ForagingWisdom',baseXP=10,holdSeconds=1,distance=10,cooldownSeconds=10,
        loot={
            {itemId='oak_log',chance=100},
            {itemId='oak_leaves',chance=50},
            {itemId='oak_stick',chance=25},
            {itemId='oak_sap',chance=10},
            {itemId='oak_core',chance=1},
            {itemId='oak_talisman',chance=.1},
        }},
}
