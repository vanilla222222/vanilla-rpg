-- Run from repository root: lua tests/run.lua (Lua 5.3+) or texlua tests/run.lua.
local Util = dofile('src/shared/TableUtil.lua')
local ProfileModule = dofile('src/server/Profile.lua')
local Profile = ProfileModule.create(Util)
local StarterItems = dofile('src/server/StarterItems.lua')
local Resources = dofile('src/server/Resources.lua')
local Rules = dofile('src/shared/StatRules.lua')
local Stats = dofile('src/server/Stats.lua')
local Definitions = dofile('src/shared/StatDefinitions.lua')
local SessionStore = dofile('src/server/SessionStore.lua')
local PlayerService = dofile('src/server/PlayerService.lua')
local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error('FAIL ' .. name .. ': ' .. tostring(err)) end
    passed = passed + 1; print('PASS ' .. name)
end
local function rejects(fn) assert(not pcall(fn), 'Expected rejection') end
local function equal(a, b) assert(a == b, tostring(a) .. ' ~= ' .. tostring(b)) end

test('independent defaults and copy-on-load', function()
    local a, b = Profile.prepare(nil, 100), Profile.prepare(nil, 100)
    a.storage.stacks.oak_log = 9; equal(b.storage.stacks.oak_log, nil)
    local loaded = Profile.prepare(a, 101); loaded.coins = 20
    equal(a.coins, 0)
end)
test('reconciliation preserves progress and unknown extension fields', function()
    local a = {schemaVersion = 1, currencies = {coins = 99}, extension = {flag = true}}
    local b = Profile.prepare(a, 100); equal(b.coins, 99); assert(b.extension.flag)
    equal(b.skills.mining.xp, 0); equal(a.skills, nil)
end)
test('corrupt, future and non-finite profiles fail closed', function()
    for _, raw in ipairs({{schemaVersion = 99}, {schemaVersion = 1, currencies = 'bad'},
        {schemaVersion = 1, currencies = {coins = -1}}, {schemaVersion = 1, currencies = {coins = 0/0}},
        {schemaVersion = 1, storage = {stacks = {oak_log = 1.5}}}, {schemaVersion = 1, injected = function() end}}) do
        rejects(function() Profile.prepare(raw, 100) end)
    end
end)
test('reward and spending validation; no overflow or negative spending', function()
    local p = Profile.prepare(nil, 100); Profile.addCoins(p, 20)
    assert(Profile.spendCoins(p, 5)); equal(p.coins, 15)
    assert(not Profile.spendCoins(p, 16)); equal(p.coins, 15)
    for _, amount in ipairs({-1, 0, 1.5, math.huge, 0/0}) do
        rejects(function() Profile.addCoins(p, amount) end)
        rejects(function() Profile.spendCoins(p, amount) end)
    end
    p.coins = ProfileModule.MAX_INTEGER
    rejects(function() Profile.addCoins(p, 1) end)
end)
test('stat ordering, formula, source replacement and defensive copying', function()
    local stats = Stats.new(Definitions, Util)
    local change = {Vitality = {flat = 100, percent = .5, multiplier = 2}}
    stats.set('gear', change); change.Vitality.flat = 9999
    equal(stats.calculate().Vitality, 600)
    stats.set('gear', {Vitality = {flat = 50}}); equal(stats.calculate().Vitality, 150)
    stats.set('skill', {Vitality = {percent = .2}}); equal(stats.calculate().Vitality, 180)
    stats.remove('gear'); equal(stats.calculate().Vitality, 120)
    local other = Stats.new(Definitions, Util)
    other.set('skill', {Vitality = {percent = .2}})
    equal(stats.calculate().Vitality, other.calculate().Vitality)
end)
test('stat bounds and invalid operation guards', function()
    local stats = Stats.new(Definitions, Util)
    stats.set('test', {CritChance = {flat = 200}, Speed = {flat = -100}})
    equal(stats.calculate().CritChance, 100); equal(stats.calculate().Speed, 0)
    rejects(function() stats.set('x', {Missing = {flat = 1}}) end)
    rejects(function() stats.set('x', {Vitality = {flat = math.huge}}) end)
    rejects(function() stats.set('x', {Vitality = {multiplier = -1}}) end)
    rejects(function() stats.set('x', {Vitality = {mystery = 1}}) end)
end)
local function fixture()
    local now, records, failures, calls, sleeps = 100, {}, 0, 0, 0
    local store = {}
    function store:UpdateAsync(key, callback)
        calls = calls + 1
        if failures > 0 then failures = failures - 1; error('Simulated outage') end
        local info = {GetMetadata = function() return {retained = true} end}
        -- Repeat the callback, as Roblox can do on write contention.
        callback(Util.copy(records[key]), info)
        local nextValue, users, metadata = callback(Util.copy(records[key]), info)
        if nextValue then records[key] = Util.copy(nextValue); assert(metadata.retained); equal(users[1], 1) end
        return Util.copy(nextValue)
    end
    local persistence = SessionStore.new(store, Profile, Util, {ttl = 600, clock = function() return now end,
        sleep = function() sleeps = sleeps + 1 end, onLoad = StarterItems.grant})
    return persistence, records, function(t) now = t end, function(n) failures = n end,
        function() return calls, sleeps end
end
test('atomic lease excludes a second server, saves and releases', function()
    local store, records = fixture()
    local a = store.open(1, 'server-a'); Profile.addCoins(a.data, 25)
    rejects(function() store.open(1, 'server-b') end)
    equal(records.player_1.data.coins, 0)
    store.save(a, false); equal(records.player_1.data.coins, 25)
    store.save(a, true); equal(records.player_1.session, nil)
    local b = store.open(1, 'server-b'); equal(b.data.coins, 25)
    rejects(function() store.save(a, false) end)
end)
test('expired lease cannot save or overwrite a new owner', function()
    local store, records, clock = fixture(); local a = store.open(1, 'a')
    clock(700); rejects(function() store.save(a, false) end)
    local b = store.open(1, 'b'); Profile.addCoins(b.data, 10); store.save(b, false)
    rejects(function() store.save(a, true) end)
    equal(records.player_1.data.coins, 10); equal(records.player_1.session.id, 'b')
end)
test('corrupt data never becomes a blank overwrite', function()
    local store, records = fixture()
    records.player_1 = {formatVersion = 1, data = {schemaVersion = 99, coins = 987}}
    rejects(function() store.open(1, 'a') end)
    equal(records.player_1.data.coins, 987); equal(records.player_1.session, nil)
    records.player_1 = {formatVersion = 1}
    rejects(function() store.open(1, 'a') end); equal(records.player_1.data, nil)
end)
test('transient failures retry; persistent failures do not create defaults', function()
    local store, records, _, fail, metrics = fixture(); fail(2)
    store.open(1, 'a'); local calls, sleeps = metrics(); equal(calls, 3); equal(sleeps, 2)
    store.save({data = records.player_1.data, token = 'a', userId = 1}, true)
    fail(3); rejects(function() store.open(1, 'b') end); equal(records.player_1.session, nil)
end)
test('idempotent retry retains previously stored data', function()
    local store = fixture(); local a = store.open(1, 'same-token')
    Profile.addCoins(a.data, 50); store.save(a, false)
    equal(store.open(1, 'same-token').data.coins, 50)
end)
test('player snapshots are private copies and exclude profile internals', function()
    local now, changes = 100, 0
    local service = PlayerService.new(Profile, Stats, Definitions, Util, function() return now end, function() changes = changes + 1 end, Resources)
    service.attach(1, {data = Profile.prepare(nil, 100), expiresAt = 200})
    service.grantCoins(1, 10); equal(service.snapshot(1).coins, 10); equal(changes, 1)
    local snap = service.snapshot(1); snap.skills.mining.xp = 999
    equal(service.snapshot(1).skills.mining.xp, 0); equal(snap.storage, nil); equal(snap.session, nil)
    assert(service.spendCoins(1, 5)); assert(not service.spendCoins(1, 6))
    now = 200; equal(service.snapshot(1), nil)
    rejects(function() service.grantCoins(1, 1) end)
end)
test('modifier changes are transactional and closing blocks mutation', function()
    local service = PlayerService.new(Profile, Stats, Definitions, Util, function() return 100 end, function() end, Resources)
    local entry = service.attach(1, {data = Profile.prepare(nil, 100), expiresAt = 200})
    service.setModifier(1, 'gear', {Vitality = {flat = 100}})
    equal(service.snapshot(1).stats.Vitality, 200)
    rejects(function() service.setModifier(1, 'gear', {Vitality = {multiplier = math.huge}}) end)
    equal(service.snapshot(1).stats.Vitality, 200)
    service.removeModifier(1, 'gear'); equal(service.snapshot(1).stats.Vitality, 100)
    entry.closing = true; rejects(function() service.grantCoins(1, 1) end)
    service.detach(1); equal(service.get(1), nil)
end)
test('removing a modifier cannot commit an overflowing composition', function()
    local service = PlayerService.new(Profile, Stats, Definitions, Util, function() return 100 end, function() end, Resources)
    service.attach(1, {data = Profile.prepare(nil, 100), expiresAt = 200})
    service.setModifier(1, 'flat', {Vitality = {flat = 1e308}})
    service.setModifier(1, 'cancel', {Vitality = {percent = -1}})
    service.setModifier(1, 'multiply', {Vitality = {multiplier = 1e308}})
    equal(service.snapshot(1).stats.Vitality, 1)
    rejects(function() service.removeModifier(1, 'cancel') end)
    equal(service.snapshot(1).stats.Vitality, 1)
end)
test('all definitive defaults and formula-only maxima match the design', function()
    local stats = Stats.new(Definitions, Util); local s = stats.calculate()
    for _, activity in ipairs({'Combat','Farming','Fishing','Mining','Foraging'}) do
        equal(s[activity .. 'Fortune'], 100); equal(s[activity .. 'Wisdom'], 100)
    end
    for _, id in ipairs({'Vitality','Endurance','Intelligence','AbilityDamage','MiningSpread'}) do equal(s[id],100) end
    for _, id in ipairs({'HealthRegen','StaminaRegen','ManaRegen'}) do equal(s[id],5) end
    for _, id in ipairs({'Defense','BreakingPower','MiningSpeed','Pristine','Sweep','AxeStrength','MaxSize','MinSize','SeaCreatureChance','DoubleHookChance','TreasureChance'}) do equal(s[id],0) end
    equal(s.CritDamage,125);equal(s.CritChance,1);equal(s.Speed,16)
    equal(s.MaxHealth,100);equal(s.MaxStamina,100);equal(s.MaxMana,100);equal(s.SprintSpeed,24)
    stats.set('tool',{Vitality={flat=50},Endurance={flat=20},Intelligence={flat=80},Speed={flat=4}})
    s=stats.calculate();equal(s.MaxHealth,150);equal(s.MaxStamina,120);equal(s.MaxMana,180);equal(s.SprintSpeed,30)
    rejects(function() stats.set('invalid',{MaxHealth={flat=10}}) end)
end)
test('defined dependency chains, missing references and cycles', function()
    local defs={definitive={Base={base=2,min=0,max=100}},defined={
        A={dependencies={'Base'},calculate=function(s)return s.Base*2 end},
        B={dependencies={'A'},calculate=function(s)return s.A+1 end}}}
    equal(Stats.new(defs,Util).calculate().B,5)
    defs.defined.A.dependencies={'B'}; rejects(function() Stats.new(defs,Util).calculate() end)
    defs.defined.A.dependencies={'Missing'}; rejects(function() Stats.new(defs,Util).calculate() end)
end)
test('wisdom and chance stat clamps; total crit and ability multipliers', function()
    local stats=Stats.new(Definitions,Util)
    stats.set('buff',{CombatWisdom={flat=9999},MiningSpread={flat=9999},CritChance={flat=9999},Pristine={flat=9999}})
    local s=stats.calculate();equal(s.CombatWisdom,500);equal(s.MiningSpread,2500);equal(s.CritChance,100);equal(s.Pristine,100)
    equal(Rules.wisdomMultiplier(100),1);equal(Rules.wisdomMultiplier(500),5);equal(Rules.wisdomMultiplier(900),5)
    equal(Rules.critMultiplier(125),1.25);equal(Rules.abilityMultiplier(100),1)
end)
test('fortune guaranteed counts, remainder boundaries and effective cap', function()
    local low=function()return 0 end;local high=function()return .999 end
    equal(Rules.fortuneChance(60,250),150)
    equal(Rules.fortuneDrops(60,250,low),2);equal(Rules.fortuneDrops(60,250,high),1)
    equal(Rules.fortuneDrops(60,250,function()return .5 end),1)
    equal(Rules.fortuneDrops(100,999999,low),5)
    equal(Rules.fortuneDrops(1,10000,high),1) -- Fortune itself is not capped at 500.
    equal(Rules.fortuneDrops(0,100,low),0);equal(Rules.fortuneDrops(100,0,low),0)
    equal(Rules.fortuneChance(1e308,1e308),500)
    rejects(function()Rules.fortuneDrops(-1,100,low)end)
    rejects(function()Rules.fortuneDrops(50,100,function()return 1 end)end)
end)
test('mining spread is total blocks with no recursive or extra base block', function()
    equal(Rules.miningBlocks(100,function()error('No roll required')end),1)
    equal(Rules.miningBlocks(150,function()return .49 end),2)
    equal(Rules.miningBlocks(150,function()return .5 end),1)
    equal(Rules.miningBlocks(2500,function()error('No roll required')end),25)
    equal(Rules.miningBlocks(9999,function()return 0 end),25)
end)
test('resources regenerate by elapsed seconds and clamp without free healing', function()
    local values=Stats.new(Definitions,Util).calculate()
    local r=Resources.new(Definitions,Util,values)
    assert(r.consume('Mana',25));assert(r.consume('Stamina',25));r.set('Health',75,values)
    r.advance(values,2);equal(r.snapshot().Mana,85);equal(r.snapshot().Stamina,85);equal(r.snapshot().Health,85)
    local copy=r.snapshot();copy.Mana=0;equal(r.snapshot().Mana,85)
    values.MaxMana=200;r.reconcile(values);equal(r.snapshot().Mana,85)
    values.MaxMana=20;r.reconcile(values);equal(r.snapshot().Mana,20)
    assert(not r.consume('Mana',21));equal(r.snapshot().Mana,20)
    r.advance(values,1e308);equal(r.snapshot().Health,100)
    rejects(function()r.advance(values,-1)end);rejects(function()r.consume('Mana',0)end)
    rejects(function()r.set('Other',1,values)end)
end)
test('resource updates are independent of frame partition and cannot regenerate the dead', function()
    local values=Stats.new(Definitions,Util).calculate()
    local a,b=Resources.new(Definitions,Util,values),Resources.new(Definitions,Util,values)
    a.consume('Mana',80);b.consume('Mana',80)
    a.advance(values,4)
    for i=1,40 do b.advance(values,.1) end
    assert(math.abs(a.snapshot().Mana-b.snapshot().Mana)<1e-10)
    a.set('Health',0,values);a.advance(values,10);equal(a.snapshot().Health,0)
    assert(not a.consume('Mana',1));a.reset(values);equal(a.snapshot().Health,100)
end)
test('player modifiers clamp current resources; expired sessions cannot progress', function()
    local now=100
    local service=PlayerService.new(Profile,Stats,Definitions,Util,function()return now end,function()end,Resources)
    local entry=service.attach(1,{data=Profile.prepare(nil,100),expiresAt=200})
    assert(service.consumeResource(1,'Mana',25));service.advanceResources(1,1);equal(service.snapshot(1).resources.Mana,80)
    service.setModifier(1,'buff',{Intelligence={flat=100}});equal(service.snapshot(1).stats.MaxMana,200);equal(service.snapshot(1).resources.Mana,80)
    service.setModifier(1,'buff',{Intelligence={flat=-50}});equal(service.snapshot(1).resources.Mana,50)
    service.setSprinting(1,true);assert(service.snapshot(1).sprinting)
    service.resetResources(1);assert(not service.snapshot(1).sprinting)
    equal(entry.session.data.resources,nil) -- Dynamic resources are not saved.
    now=200;service.advanceResources(1,100);rejects(function()service.consumeResource(1,'Mana',1)end)
end)
test('v2 template contains requested maps, skill levels and all equipment slots', function()
    local p=Profile.prepare(nil,100)
    equal(p.schemaVersion,2);equal(p.coins,0);equal(p.bank,0);equal(p.gameXP,0)
    for _,key in ipairs({'talismans','museum','storage','equipment','inventory','quests'})do equal(type(p[key]),'table')end
    for _,key in ipairs({'heavyMelee','lightMelee','magic','ranged'})do equal(p.skills.combat[key].level,1);equal(p.skills.combat[key].xp,0)end
    for _,slot in ipairs(ProfileModule.EQUIPMENT_SLOTS)do equal(p.equipment[slot],false)end
    equal(#ProfileModule.EQUIPMENT_SLOTS,18)
end)
test('legacy migration archives unsplittable combat XP and preserves coins', function()
    local old={schemaVersion=1,currencies={coins=123},skills={combat={xp=987}},inventory={capacity=30,slots={}}}
    local p=Profile.prepare(old,100);equal(p.coins,123);equal(p.currencies,nil)
    equal(p.legacy.combat.xp,987);equal(p.skills.combat.xp,nil)
    equal(p.skills.combat.magic.xp,0);equal(old.currencies.coins,123)
    p=Profile.prepare(p,101);equal(p.coins,123);equal(p.legacy.combat.xp,987)
end)
test('missing fields repair without deleting donations, quests, equipment or balances', function()
    local p={schemaVersion=2,coins=90,bank=50,gameXP=1,equipment={helmet='item-instance-1'},
        talismans={test=true},museum={oak_log=5},quests={intro={completed=true}},skills={mining={level=4,xp=60}}}
    local repaired=Profile.prepare(p,100)
    equal(repaired.equipment.helmet,'item-instance-1');equal(repaired.equipment.weapon4,false)
    equal(repaired.skills.mining.level,4);equal(repaired.skills.mining.xp,60)
    assert(repaired.talismans.test);equal(repaired.museum.oak_log,5);assert(repaired.quests.intro.completed)
    equal(repaired.bank,50);equal(repaired.gameXP,1);equal(repaired.coins,90)
end)
test('joining immediately persists new template and migrated repairs', function()
    local store,records=fixture();local session=store.open(1,'new')
    equal(records.player_1.data.schemaVersion,2);equal(records.player_1.data.bank,0)
    store.save(session,true)
    records.player_1.data={schemaVersion=1,currencies={coins=44},skills={combat={xp=8}}}
    session=store.open(1,'next');equal(records.player_1.data.coins,44)
    equal(records.player_1.data.equipment.weapon4,false);equal(records.player_1.data.legacy.combat.xp,8)
end)
test('canonical balances take precedence over deprecated aliases without adding coins', function()
    local p=Profile.prepare({schemaVersion=2,coins=4,currencies={coins=99}},100)
    equal(p.coins,4);equal(p.legacy.currencies.coins,99);equal(p.currencies,nil)
    rejects(function()Profile.prepare({schemaVersion=2,bank=-1},100)end)
    rejects(function()Profile.prepare({schemaVersion=2,skills={combat={magic={level=0,xp=0}}}},100)end)
end)
test('private snapshot computes game level from exact integer XP', function()
    local s=PlayerService.new(Profile,Stats,Definitions,Util,function()return 100 end,function()end,Resources)
    local p=Profile.prepare(nil,100);p.gameXP=1;p.bank=99
    s.attach(1,{data=p,expiresAt=200});local snapshot=s.snapshot(1)
    equal(snapshot.gameLevel,1.01);equal(snapshot.bank,99);equal(snapshot.inventory.capacity,30)
    snapshot.equipment.helmet='fake';equal(p.equipment.helmet,false)
end)
dofile('tests/resource-nodes.lua')(test,equal)
dofile('tests/gathering.lua')(test,equal,rejects)
dofile('tests/items.lua')(test,equal,rejects)
dofile('tests/equipment.lua')(test,equal,rejects)
dofile('tests/inventory.lua')(test,equal,rejects)
dofile('tests/inventory-ui.lua')(test,equal,rejects)
dofile('tests/item-images.lua')(test,equal,rejects)
test('starter kit grants five valid unique items once and survives rejoin', function()
    local store,records=fixture();local a=store.open(1,'a')
    local catalog=dofile('src/shared/ItemCatalog.lua').create(dofile('src/shared/ItemDefinitions.lua'),dofile('src/shared/ItemTypes.lua'),Definitions,Util)
    local ids={}
    for i,id in ipairs(StarterItems.ids)do
        local item=a.data.inventory.slots[tostring(i)]
        equal(item.itemId,id);equal(item.quantity,1);equal(catalog.get(id).maxStack,1)
        assert(not ids[item.instanceId]);ids[item.instanceId]=true
    end
    assert(records.player_1.data.unlocks.starterKitV1)
    store.save(a,true);local b=store.open(1,'b')
    local count=0;for _ in pairs(b.data.inventory.slots)do count=count+1 end;equal(count,5)
    equal(b.data.inventory.slots['1'].instanceId,a.data.inventory.slots['1'].instanceId)
end)
test('starter grant preserves occupied slots and does not duplicate after item removal', function()
    local p=Profile.prepare(nil,100);p.inventory.slots['1']={itemId='stone',quantity=5}
    assert(StarterItems.grant(p,1));equal(p.inventory.slots['1'].itemId,'stone')
    equal(p.inventory.slots['2'].itemId,'starter_axe')
    p.inventory.slots['2']=nil;assert(not StarterItems.grant(p,1));equal(p.inventory.slots['2'],nil)
end)
test('starter grant defers full bags without partial edits or overwritten items', function()
    local p=Profile.prepare(nil,100)
    for i=1,27 do p.inventory.slots[tostring(i)]={itemId='stone',quantity=1}end
    assert(not StarterItems.grant(p,1));equal(p.unlocks.starterKitV1,nil);equal(p.inventory.slots['28'],nil)
    p.inventory.slots['1']=nil;p.inventory.slots['2']=nil
    assert(StarterItems.grant(p,1));equal(p.inventory.slots['3'].itemId,'stone')
    local q=Profile.prepare(nil,100);StarterItems.grant(q,2)
    assert(q.inventory.slots['1'].instanceId~=p.inventory.slots['1'].instanceId)
end)
-- Syntax-check all Roblox scripts even though engine APIs cannot run in this host.
for _, file in ipairs({'src/server/Bootstrap.server.lua', 'src/server/Config.lua', 'src/server/ResourceNodes.lua', 'src/client/Bootstrap.client.lua',
    'src/shared/ItemDefinitions.lua', 'src/character/Health.server.lua'}) do assert(loadfile(file)) end
print(string.format('%d foundation tests passed; Roblox engine integration remains unverified.', passed))
