return function(test,equal,rejects)
    local util=dofile('src/shared/TableUtil.lua')
    local defs=dofile('src/shared/StatDefinitions.lua')
    local catalog=dofile('src/shared/ItemCatalog.lua').create(dofile('src/shared/ItemDefinitions.lua'),dofile('src/shared/ItemTypes.lua'),defs,util)
    local profile=dofile('src/server/Profile.lua').create(util)
    local Equipment=dofile('src/server/Equipment.lua').create(catalog,util)
    local Inventory=dofile('src/server/Inventory.lua').create(catalog,util,Equipment)
    local Service=dofile('src/server/PlayerService.lua')
    local function data()
        local p=profile.prepare(nil,100);dofile('src/server/StarterItems.lua').grant(p,1);return p
    end
    local function change(p,action,from,to,amount)return Inventory.change(p,action,tostring(from),tostring(to),amount,p.inventory.revision)end
    local function digest(value)
        if type(value)~='table'then return type(value)..':'..tostring(value)end
        local keys={};for key in pairs(value)do table.insert(keys,key)end;table.sort(keys)
        local out={};for _,key in ipairs(keys)do table.insert(out,key..'='..digest(value[key]))end
        return '{'..table.concat(out,',')..'}'
    end
    local function ownership(p)
        local totals,ids={},{}
        for _,map in ipairs({p.inventory.slots,p.equipmentItems})do
            for _,item in pairs(map)do
                totals[item.itemId]=(totals[item.itemId] or 0)+item.quantity
                if item.instanceId then assert(not ids[item.instanceId]);ids[item.instanceId]=true end
            end
        end
        return digest({totals=totals,instances=ids})
    end
    local function service()
        local s=Service.new(profile,dofile('src/server/Stats.lua'),defs,util,function()return 100 end,function()end,dofile('src/server/Resources.lua'),Equipment,Inventory)
        s.attach(1,{data=data(),expiresAt=1000});return s
    end
    test('whole levels unlock one slot and preserve older larger or occupied bags',function()
        local p=data();p.gameXP=99;p=profile.prepare(p,100);equal(p.inventory.capacity,30)
        p.gameXP=100;p=profile.prepare(p,100);equal(p.inventory.capacity,31)
        p.gameXP=200;p=profile.prepare(p,100);equal(p.inventory.capacity,32)
        p.inventory.capacity=90;p.gameXP=0;p=profile.prepare(p,100);equal(p.inventory.capacity,90)
        p.inventory.capacity=30;p.inventory.slots['101']={itemId='stone',quantity=1}
        p=profile.prepare(p,100);equal(p.inventory.capacity,101);equal(p.inventory.slots['101'].quantity,1)
    end)
    test('stack rewards fill existing stacks and open slots without losing remainders',function()
        local p=data();p=Inventory.grantStack(p,'oak_log',20000)
        equal(p.inventory.slots['6'].quantity,9999);equal(p.inventory.slots['7'].quantity,9999);equal(p.inventory.slots['8'].quantity,2)
        local old=p;p=Inventory.grantStack(p,'oak_log',5);equal(p.inventory.slots['8'].quantity,7);equal(old.inventory.slots['8'].quantity,2)
        p=Inventory.removeStack(p,'oak_log',10000);equal(p.inventory.slots['6'],nil);equal(p.inventory.slots['7'].quantity,9998)
    end)
    test('move, swap, split and merge retain ownership and original records',function()
        local p=Inventory.grantStack(data(),'stone',10);local original=digest(p);local owned=ownership(p)
        local q=change(p,'split',6,7,4);equal(q.inventory.slots['6'].quantity,6);equal(q.inventory.slots['7'].quantity,4)
        equal(digest(p),original);equal(ownership(q),owned)
        q=change(q,'merge',7,6);equal(q.inventory.slots['6'].quantity,10);equal(q.inventory.slots['7'],nil)
        q=change(q,'move',1,6);equal(q.inventory.slots['6'].itemId,'starter_axe');equal(q.inventory.slots['1'].itemId,'stone')
        q=change(q,'move',6,30);equal(q.inventory.slots['6'],nil);equal(ownership(q),owned)
    end)
    test('partial merges stop at stack limits and leave excess in the source',function()
        local p=Inventory.grantStack(data(),'stone',10009)
        p=change(p,'split',6,8,5)
        equal(p.inventory.slots['6'].quantity,9994);equal(p.inventory.slots['7'].quantity,10)
        p=change(p,'merge',7,6);equal(p.inventory.slots['6'].quantity,9999);equal(p.inventory.slots['7'].quantity,5)
        local old=digest(p);rejects(function()change(p,'merge',7,6)end);equal(digest(p),old)
    end)
    test('metadata differences prevent merging including nested quantity fields',function()
        local p=data()
        p.inventory.slots['6']={itemId='stone',quantity=5,quality={quantity=2}}
        p.inventory.slots['7']={itemId='stone',quantity=4,quality={quantity=3}}
        assert(not Inventory.compatible(p.inventory.slots['6'],p.inventory.slots['7']))
        rejects(function()change(p,'merge',6,7)end)
        local q=change(p,'move',6,7);equal(q.inventory.slots['6'].quality.quantity,3)
        q=change(q,'split',6,8,1);equal(q.inventory.slots['8'].quality.quantity,3)
        q=change(q,'merge',8,6);equal(q.inventory.slots['6'].quantity,4)
    end)
    test('invalid and stale operations leave profiles unchanged',function()
        local p=Inventory.grantStack(data(),'stone',10);local old=digest(p)
        for _,amount in ipairs({0,-1,1.5,math.huge,0/0,11})do rejects(function()change(p,'split',6,7,amount)end)end
        rejects(function()change(p,'split',1,7,1)end)
        rejects(function()change(p,'move',6,1,1)end)
        rejects(function()change(p,'move',6,31)end)
        rejects(function()Inventory.change(p,'move','01','7',nil,p.inventory.revision)end)
        rejects(function()Inventory.change(p,'move','6','7',nil,p.inventory.revision-1)end)
        equal(digest(p),old)
        local q=change(p,'move',6,7)
        rejects(function()Inventory.change(q,'move','7','6',nil,p.inventory.revision)end)
        rejects(function()Equipment.equip(q,'1',nil,p.inventory.revision)end)
    end)
    test('full-bag rewards and insufficient crafting removals are atomic',function()
        local p=data()
        for i=6,30 do p.inventory.slots[tostring(i)]={itemId='stone',quantity=9999}end
        local old=digest(p)
        rejects(function()Inventory.grantStack(p,'stone',1)end)
        rejects(function()Inventory.removeStack(p,'oak_log',1)end)
        equal(digest(p),old)
    end)
    test('long deterministic operation sequences conserve item totals and unique IDs',function()
        local p=Inventory.grantStack(data(),'stone',15000);p=Inventory.grantStack(p,'oak_log',18000)
        local owned=ownership(p);math.randomseed(104729)
        for i=1,1200 do
            local from,to=tostring(math.random(1,30)),tostring(math.random(1,30))
            local actions={'move','swap','merge','split'};local action=actions[math.random(1,4)]
            local source=p.inventory.slots[from];local amount=action=='split' and source and math.floor(source.quantity/2) or nil
            local before=digest(p)
            local ok,nextData=pcall(Inventory.change,p,action,from,to,amount,p.inventory.revision)
            if ok then p=nextData;Inventory.validate(p)else equal(digest(p),before)end
            equal(ownership(p),owned)
        end
    end)
    test('server progression and inventory APIs honor session expiry and revisions',function()
        local s=service();s.grantGameXP(1,100);equal(s.snapshot(1).inventory.capacity,31)
        equal(s.snapshot(1).gameLevel,2);s.grantStack(1,'stone',10)
        local revision=s.snapshot(1).inventory.revision
        s.changeInventory(1,'split','6','31',5,revision);equal(s.snapshot(1).inventory.slots['31'].quantity,5)
        rejects(function()s.changeInventory(1,'merge','31','6',nil,revision)end)
        s.changeEquipment(1,'equip','1',nil,s.snapshot(1).inventory.revision)
        rejects(function()s.changeInventory(1,'move','6','1',nil,revision+1)end)
        s.get(1).session.expiresAt=100
        rejects(function()s.grantGameXP(1,1)end);rejects(function()s.grantStack(1,'stone',1)end)
    end)
    test('inventory transfers, expansion and revisions survive atomic save and reload',function()
        local stored
        local adapter={UpdateAsync=function(_,key,transform)
            local result=transform(util.copy(stored));if result then stored=util.copy(result)end;return util.copy(result)
        end}
        local persistence=dofile('src/server/SessionStore.lua').new(adapter,profile,util,{ttl=600,clock=function()return 100 end,sleep=function()end,
            onLoad=function(p,id)dofile('src/server/StarterItems.lua').grant(p,id);Inventory.validate(p)end})
        local s=Service.new(profile,dofile('src/server/Stats.lua'),defs,util,function()return 100 end,function()end,dofile('src/server/Resources.lua'),Equipment,Inventory)
        s.attach(1,persistence.open(1,'one'));s.grantGameXP(1,100);s.grantStack(1,'stone',10)
        s.changeInventory(1,'split','6','31',3,s.snapshot(1).inventory.revision)
        s.changeEquipment(1,'equip','1',nil,s.snapshot(1).inventory.revision)
        local before=s.get(1).session.data;local owned=ownership(before)
        persistence.save(s.get(1).session,true)
        local nextSession=persistence.open(1,'two');Inventory.validate(nextSession.data)
        equal(nextSession.data.inventory.capacity,31);equal(nextSession.data.inventory.revision,before.inventory.revision)
        equal(nextSession.data.inventory.slots['31'].quantity,3);equal(nextSession.data.inventory.slots['6'].quantity,7)
        equal(ownership(nextSession.data),owned)
    end)
    test('invalid saved stacks refuse load without persisting repairs or starter grants',function()
        local p=data();p.inventory.slots['6']={itemId='stone',quantity=10000}
        local stored={formatVersion=1,data=p};local before=digest(stored)
        local adapter={UpdateAsync=function(_,key,transform)
            local result=transform(util.copy(stored));if result then stored=util.copy(result)end;return util.copy(result)
        end}
        local persistence=dofile('src/server/SessionStore.lua').new(adapter,profile,util,{ttl=600,clock=function()return 100 end,sleep=function()end,onLoad=Inventory.validate})
        rejects(function()persistence.open(1,'bad')end);equal(digest(stored),before)
    end)
end
