return function(test,equal,rejects)
    local util=dofile('src/shared/TableUtil.lua')
    local defs=dofile('src/shared/StatDefinitions.lua')
    local catalog=dofile('src/shared/ItemCatalog.lua').create(dofile('src/shared/ItemDefinitions.lua'),dofile('src/shared/ItemTypes.lua'),defs,util)
    local equipment=dofile('src/server/Equipment.lua').create(catalog,util)
    local inventory=dofile('src/server/Inventory.lua').create(catalog,util,equipment)
    local profile=dofile('src/server/Profile.lua').create(util)
    local collections=dofile('src/shared/CollectionDefinitions.lua')
    local resources=dofile('src/shared/ResourceDefinitions.lua')
    local rules=dofile('src/shared/StatRules.lua')
    local gathering=dofile('src/server/Gathering.lua').create(resources,catalog,collections,inventory,rules,util)
    local Stats=dofile('src/server/Stats.lua')
    local function ready()
        local data=profile.prepare(nil,100);dofile('src/server/StarterItems.lua').grant(data,1)
        data=equipment.equip(data,'1')
        local stats=Stats.new(defs,util)
        for id,change in pairs(equipment.modifiers(data))do stats.set(id,change)end
        return data,stats.calculate()
    end
    test('oak defines exact independent base rates and five enchanted collection links',function()
        local expected={100,50,25,10,1,.1}
        for i,entry in ipairs(resources.oak.loot)do equal(entry.chance,expected[i])end
        local n=0
        for id,entry in pairs(collections)do
            equal(catalog.get(entry.itemId).collection,id)
            equal(catalog.get(entry.enchantedItemId).collection,id)
            assert(catalog.get(entry.enchantedItemId).stackable);n=n+1
        end
        equal(n,5);equal(catalog.get('oak_talisman').collection,nil)
        equal(catalog.get('enchanted_oak_talisman'),nil)
    end)
    test('one harvest can independently award all loot and raw collection counts',function()
        local data,stats=ready();local calls=0
        local result,reward=gathering.harvest(data,stats,'oak',function()calls=calls+1;return 0 end)
        equal(#reward.loot,6);equal(calls,5);equal(reward.xp,10)
        for id in pairs(collections)do equal(result.collections[id],1);equal(data.collections[id],nil)end
        equal(result.talismans.oak_talisman.count,1);equal(result.skills.foraging.xp,10)
        equal(data.skills.foraging.xp,0);equal(data.talismans.oak_talisman,nil)
    end)
    test('common wood guaranteed while exact rare boundaries are exclusive',function()
        local data,stats=ready()
        local _,reward=gathering.harvest(data,stats,'oak',function()return .999999 end)
        equal(#reward.loot,1);equal(reward.loot[1].itemId,'oak_log')
        local r=gathering.harvest(data,stats,'oak',function()return .001 end)
        equal(r.talismans.oak_talisman,nil);equal(r.collections.oak_core,1)
        r=gathering.harvest(data,stats,'oak',function()return .000999 end)
        equal(r.talismans.oak_talisman.count,1)
    end)
    test('fortune uses guaranteed copies and capped effective chances; wisdom carries fractions',function()
        local data,stats=ready();stats.ForagingFortune=200;stats.ForagingWisdom=500
        local result,reward=gathering.harvest(data,stats,'oak',function()return .999 end)
        equal(result.collections.oak,2);equal(result.collections.oak_leaves,1);equal(reward.xp,50)
        stats.ForagingFortune=1000000
        result=gathering.harvest(data,stats,'oak',function()return .999 end)
        for id in pairs(collections)do equal(result.collections[id],5)end
        equal(result.talismans.oak_talisman.count,5)
        stats.ForagingFortune=100;stats.ForagingWisdom=105
        result,reward=gathering.harvest(data,stats,'oak',function()return .999 end)
        equal(reward.xp,10);equal(result.skills.foraging.xpRemainder,.5)
        result,reward=gathering.harvest(result,stats,'oak',function()return .999 end)
        equal(reward.xp,11);equal(result.skills.foraging.xp,21);equal(result.skills.foraging.xpRemainder,0)
    end)
    test('full inventory and counter overflow reject before random rolls or mutation',function()
        local data,stats=ready()
        for i=1,30 do data.inventory.slots[tostring(i)]={itemId='oak_log',quantity=9999}end
        local calls=0;local function random()calls=calls+1;return 0 end
        rejects(function()gathering.harvest(data,stats,'oak',random)end)
        equal(calls,0);equal(data.skills.foraging.xp,0);equal(data.collections.oak,nil)
        data,stats=ready();data.collections.oak=9007199254740991
        rejects(function()gathering.harvest(data,stats,'oak',random)end);equal(calls,0)
        data,stats=ready();data.skills.foraging.xp=9007199254740991
        rejects(function()gathering.harvest(data,stats,'oak',random)end);equal(calls,0)
    end)
    test('missing tools and insufficient axe strength reject before random',function()
        local data,stats=ready();local calls=0
        local function random()calls=calls+1;return 0 end
        data=equipment.unequip(data,'axe')
        rejects(function()gathering.harvest(data,stats,'oak',random)end)
        data,stats=ready();stats.AxeStrength=0
        rejects(function()gathering.harvest(data,stats,'oak',random)end);equal(calls,0)
    end)
    test('passive talisman applies once across duplicates and rejoin; snapshot is private',function()
        local Service=dofile('src/server/PlayerService.lua')
        local data=ready()
        local function attach(value)
            local service=Service.new(profile,Stats,defs,util,function()return 100 end,function()end,dofile('src/server/Resources.lua'),equipment,inventory,gathering)
            service.attach(1,{data=value,expiresAt=1000});return service
        end
        local s=attach(data)
        s.harvestResource(1,'oak',function()return 0 end)
        equal(s.snapshot(1).stats.ForagingFortune,105)
        s.harvestResource(1,'oak',function()return 0 end)
        equal(s.snapshot(1).talismans.oak_talisman.count,2);equal(s.snapshot(1).stats.ForagingFortune,105)
        rejects(function()s.setModifier(1,'talisman:oak_talisman',{})end)
        local rejoined=attach(profile.prepare(s.get(1).session.data,101))
        equal(rejoined.snapshot(1).stats.ForagingFortune,105);equal(rejoined.snapshot(1).skills.foraging.xp,20)
        local snapshot=rejoined.snapshot(1);snapshot.collections.oak=999
        assert(rejoined.snapshot(1).collections.oak~=999)
        rejoined.get(1).session.expiresAt=99
        rejects(function()rejoined.harvestResource(1,'oak',function()return 0 end)end)
    end)
    test('harvest rewards persist together through atomic save and reload',function()
        local records={}
        local store={UpdateAsync=function(_,key,transform)
            local value=transform(util.copy(records[key]))
            if value~=nil then records[key]=util.copy(value)end
            return util.copy(records[key])
        end}
        local now=100
        local persistence=dofile('src/server/SessionStore.lua').new(store,profile,util,{ttl=600,clock=function()return now end,sleep=function()end})
        local session=persistence.open(1,'first')
        local data,stats=ready();data.talismans.oak_talisman={count=1,extension='preserved'}
        session.data=gathering.harvest(data,stats,'oak',function()return 0 end)
        persistence.save(session,true);now=101
        local loaded=persistence.open(1,'second').data
        equal(loaded.collections.oak,1);equal(loaded.collections.oak_sap,1)
        equal(loaded.skills.foraging.xp,10);equal(loaded.talismans.oak_talisman.count,2)
        equal(loaded.talismans.oak_talisman.extension,'preserved')
        local statsAfter=Stats.new(defs,util)
        for id,change in pairs(equipment.modifiers(loaded))do statsAfter.set(id,change)end
        equal(statsAfter.calculate().ForagingFortune,105)
        local wood=0;for _,item in pairs(loaded.inventory.slots)do if item.itemId=='oak_log'then wood=wood+item.quantity end end
        equal(wood,1)
    end)
    test('inventory grants do not create collection credit',function()
        local data=ready();data=inventory.grantStack(data,'oak_log',100)
        equal(data.collections.oak,nil)
    end)
end
