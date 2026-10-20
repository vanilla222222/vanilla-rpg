return function(test,equal,rejects)
    local util=dofile('src/shared/TableUtil.lua')
    local defs=dofile('src/shared/StatDefinitions.lua')
    local raw=dofile('src/shared/ItemDefinitions.lua')
    local types=dofile('src/shared/ItemTypes.lua')
    local catalog=dofile('src/shared/ItemCatalog.lua').create(raw,types,defs,util)
    local Equipment=dofile('src/server/Equipment.lua').create(catalog,util)
    local Profile=dofile('src/server/Profile.lua').create(util)
    local Starter=dofile('src/server/StarterItems.lua')
    local Stats=dofile('src/server/Stats.lua')
    local Resources=dofile('src/server/Resources.lua')
    local Service=dofile('src/server/PlayerService.lua')
    local function player()
        local service=Service.new(Profile,Stats,defs,util,function()return 100 end,function()end,Resources,Equipment)
        local data=Profile.prepare(nil,100);Starter.grant(data,1)
        service.attach(1,{data=data,expiresAt=1000})
        return service
    end
    local function count(data)
        local ids={};local n=0
        for _,item in pairs(data.inventory.slots)do assert(not ids[item.instanceId]);ids[item.instanceId]=true;n=n+1 end
        for _,item in pairs(data.equipmentItems)do assert(not ids[item.instanceId]);ids[item.instanceId]=true;n=n+1 end
        return n
    end
    test('starter tools equip and apply their definitive stats immediately',function()
        local s=player()
        s.changeEquipment(1,'equip','1');equal(s.snapshot(1).stats.Sweep,1);equal(s.snapshot(1).stats.AxeStrength,1)
        s.changeEquipment(1,'equip','2');equal(s.snapshot(1).stats.MiningSpeed,10);equal(s.snapshot(1).stats.BreakingPower,1)
        s.changeEquipment(1,'equip','4');equal(s.snapshot(1).stats.FarmingFortune,105)
        s.changeEquipment(1,'equip','5');equal(s.snapshot(1).stats.MinSize,1);equal(s.snapshot(1).stats.MaxSize,5)
        s.changeEquipment(1,'equip','3');assert(s.snapshot(1).equipment.weapon1)
        equal(count(s.get(1).session.data),5)
    end)
    test('unequipping restores stats and returns the same unique instance',function()
        local s=player();local id=s.snapshot(1).inventory.slots['1'].instanceId
        s.changeEquipment(1,'equip','1');s.changeEquipment(1,'unequip','axe')
        equal(s.snapshot(1).stats.Sweep,0);equal(s.snapshot(1).stats.AxeStrength,0)
        equal(s.snapshot(1).inventory.slots['1'].instanceId,id);equal(s.snapshot(1).equipment.axe,false)
        equal(count(s.get(1).session.data),5)
    end)
    test('equipped items and stat bonuses reconstruct from saved profile',function()
        local s=player();s.changeEquipment(1,'equip','2')
        local data=Profile.prepare(s.get(1).session.data,101)
        local other=Service.new(Profile,Stats,defs,util,function()return 100 end,function()end,Resources,Equipment)
        other.attach(1,{data=data,expiresAt=1000})
        equal(other.snapshot(1).stats.MiningSpeed,10);assert(other.snapshot(1).equipment.pickaxe)
        equal(count(data),5)
    end)
    test('invalid slots, wrong equipment types, missing ownership and replay do not mutate',function()
        local s=player()
        rejects(function()s.changeEquipment(1,'equip','1','helmet')end)
        rejects(function()s.changeEquipment(1,'equip','999')end)
        rejects(function()s.changeEquipment(1,'equip',{})end)
        equal(s.snapshot(1).stats.Sweep,0);equal(count(s.get(1).session.data),5)
        s.changeEquipment(1,'equip','1')
        rejects(function()s.changeEquipment(1,'equip','1')end)
        rejects(function()s.changeEquipment(1,'unequip','helmet')end)
        rejects(function()s.changeEquipment(1,'grant','2')end)
        equal(count(s.get(1).session.data),5)
    end)
    test('swapping a full bag preserves the old and new equipment instances',function()
        local s=player();s.changeEquipment(1,'equip','1')
        local data=s.get(1).session.data
        data.inventory.slots['1']={itemId='starter_axe',instanceId='other_axe',quantity=1}
        for i=6,30 do data.inventory.slots[tostring(i)]={itemId='starter_axe',instanceId='copy_'..i,quantity=1}end
        local old=data.equipment.axe
        s.changeEquipment(1,'equip','1')
        local nextData=s.get(1).session.data
        equal(nextData.equipment.axe,'other_axe');equal(nextData.inventory.slots['1'].instanceId,old)
        equal(count(nextData),31)
        rejects(function()s.changeEquipment(1,'unequip','axe')end)
        equal(s.get(1).session.data.equipment.axe,'other_axe');equal(s.snapshot(1).stats.Sweep,1)
    end)
    test('multiple equipment copies do not stack the same slot source',function()
        local s=player();s.changeEquipment(1,'equip','1')
        s.get(1).session.data.inventory.slots['1']={itemId='starter_axe',instanceId='axe_two',quantity=1}
        s.changeEquipment(1,'equip','1');equal(s.snapshot(1).stats.Sweep,1)
        s.changeEquipment(1,'unequip','axe');equal(s.snapshot(1).stats.Sweep,0)
        rejects(function()s.setModifier(1,'equipment:axe',{Sweep={flat=100}})end)
        rejects(function()s.removeModifier(1,'equipment:axe')end)
    end)
    test('duplicate references and broken equipment records fail closed',function()
        local s=player();local data=s.get(1).session.data
        data.inventory.slots['6']=util.copy(data.inventory.slots['1'])
        rejects(function()s.changeEquipment(1,'equip','1')end)
        data.inventory.slots['6']=nil
        data.equipment.axe='missing'
        rejects(function()Equipment.modifiers(data)end)
    end)
    test('requirements are checked on the server and talismans cannot fill gear slots',function()
        local source=util.copy(raw)
        source.locked={name='Locked Axe',kind='tool',toolType='axe',requirements={skills={foraging=2}},stats={Sweep={flat=10}}}
        local locked=dofile('src/server/Equipment.lua').create(dofile('src/shared/ItemCatalog.lua').create(source,types,defs,util),util)
        local data=Profile.prepare(nil,100)
        data.inventory.slots['1']={itemId='locked',instanceId='locked1',quantity=1}
        rejects(function()locked.equip(data,'1')end)
        data.skills.foraging.level=2
        local equipped=locked.equip(data,'1');equal(equipped.equipment.axe,'locked1')
        data.inventory.slots['2']={itemId='oak_talisman',instanceId='talisman1',quantity=1}
        rejects(function()locked.equip(data,'2','artifact')end)
    end)
    test('equipping vitality changes maximum without healing and unequip clamps',function()
        local s=player();local data=s.get(1).session.data
        data.inventory.slots['6']={itemId='starter_helmet',instanceId='helmet1',quantity=1}
        s.changeEquipment(1,'equip','6');equal(s.snapshot(1).stats.MaxHealth,105);equal(s.snapshot(1).resources.Health,100)
        s.advanceResources(1,1);equal(s.snapshot(1).resources.Health,105)
        s.changeEquipment(1,'unequip','helmet');equal(s.snapshot(1).resources.Health,100);equal(s.snapshot(1).stats.Defense,0)
    end)
    test('equipped ownership survives SessionStore save/release and reload',function()
        local stored
        local adapter={UpdateAsync=function(_,key,transform)
            local nextValue=transform(util.copy(stored))
            if nextValue then stored=util.copy(nextValue)end
            return util.copy(nextValue)
        end}
        local persistence=dofile('src/server/SessionStore.lua').new(adapter,Profile,util,
            {ttl=600,clock=function()return 100 end,sleep=function()end,onLoad=Starter.grant})
        local s=Service.new(Profile,Stats,defs,util,function()return 100 end,function()end,Resources,Equipment)
        s.attach(1,persistence.open(1,'first'));s.changeEquipment(1,'equip','1')
        persistence.save(s.get(1).session,true)
        local second=persistence.open(1,'second')
        equal(count(second.data),5);assert(second.data.equipment.axe);equal(second.data.inventory.slots['1'],nil)
        local calc=Stats.new(defs,util)
        for id,modifier in pairs(Equipment.modifiers(second.data))do calc.set(id,modifier)end
        equal(calc.calculate().Sweep,1)
    end)
    for _,file in ipairs({'src/client/ItemIcons.lua','src/client/InventoryUI.lua','src/client/ItemTooltip.lua'})do assert(loadfile(file))end
end
