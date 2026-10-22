return function(test,equal,rejects)
    local util=dofile('src/shared/TableUtil.lua')
    local types=dofile('src/shared/ItemTypes.lua')
    local defs=dofile('src/shared/StatDefinitions.lua')
    local raw=dofile('src/shared/ItemDefinitions.lua')
    local Catalog=dofile('src/shared/ItemCatalog.lua')
    local function build(source)return Catalog.create(source,types,defs,util)end
    test('item examples cover all types and preserve permanent IDs',function()
        local catalog=build(raw);local counts={};local n=0
        for id,item in pairs(catalog.all())do counts[item.kind]=true;n=n+1;equal(item.id,id)end
        for kind in pairs(types.kinds)do assert(counts[kind],kind)end
        equal(n,33);equal(catalog.get('oak_log').name,'Oak Wood');equal(catalog.get('starter_axe').toolType,'axe')
        equal(catalog.get('missing'),nil)
    end)
    test('normalized defaults do not mutate raw or catalog state',function()
        local catalog=build(raw);equal(raw.oak_log.maxStack,nil)
        local a=catalog.get('oak_log');equal(a.maxStack,9999);equal(a.rarity,'common');assert(a.stackable)
        a.name='changed';equal(catalog.get('oak_log').name,'Oak Wood')
        a=catalog.all();a.starter_axe.stats.Sweep.flat=999
        equal(catalog.get('starter_axe').stats.Sweep.flat,1)
    end)
    test('equipment compatibility follows subtype and all four weapon slots',function()
        local c=build(raw)
        assert(c.canEquip('starter_axe','axe'));assert(not c.canEquip('starter_axe','pickaxe'))
        assert(c.canEquip('starter_helmet','helmet'));assert(not c.canEquip('starter_helmet','boots'))
        assert(c.canEquip('copper_ring','ring'))
        for i=1,4 do assert(c.canEquip('starter_bow','weapon'..i))end
        assert(not c.canEquip('starter_bow','weapon5'));assert(not c.canEquip('oak_log','helmet'))
        assert(not c.canEquip('oak_talisman','artifact'));assert(not c.canEquip('missing','axe'))
    end)
    test('unique gear, stack limits and protected quest policies',function()
        local c=build(raw);equal(c.get('starter_axe').maxStack,1);assert(not c.get('starter_axe').stackable)
        local q=c.get('sealed_letter');assert(not q.tradable and not q.droppable)
        for _,patch in ipairs({{maxStack=2},{maxStack=0},{maxStack=1.5}})do
            local a=util.copy(raw.starter_axe);for k,v in pairs(patch)do a[k]=v end
            rejects(function()build({bad_axe=a})end)
        end
        rejects(function()build({quest={name='Quest',kind='questItem',tradable=true}})end)
    end)
    test('invalid definition fields and mismatched subtypes fail early',function()
        for _,entry in ipairs({{kind='unknown'}, {kind='armor'}, {kind='tool',toolType='sword'},
            {kind='weapon',weaponType='magic'}, {kind='material',armorSlot='helmet'},
            {kind='material',maxStak=5}, {kind='material',rarity='unknown'},
            {kind='material',name=false}, {kind='material',icon='http://example.com'},
            {kind='material',tags={'ok',[3]='sparse'}}, {kind='consumable'}})do
            rejects(function()build({bad_item=entry})end)
        end
        rejects(function()build({['Bad ID']={kind='material'}})end)
    end)
    test('items can only modify definitive stats with finite supported operations',function()
        for _,stat in ipairs({'MaxHealth','Health','Missing'})do
            rejects(function()build({bad={kind='talisman',stats={[stat]={flat=1}}}})end)
        end
        rejects(function()build({bad={kind='material',stats={Vitality={flat=5}}}})end)
        rejects(function()build({bad={kind='talisman',stats={Vitality={flat=math.huge}}}})end)
        rejects(function()build({bad={kind='talisman',stats={Vitality={multiplier=-1}}}})end)
        rejects(function()build({bad={kind='talisman',stats={Vitality={bonus=1}}}})end)
    end)
    test('requirements and effect references validate without executing gameplay',function()
        local c=build({test_tool={kind='tool',toolType='axe',requirements={gameLevel=2,skills={foraging=4}},abilityIds={'sweep'}}})
        equal(c.get('test_tool').requirements.skills.foraging,4)
        rejects(function()build({bad={kind='material',requirements={skills={missing=1}}}})end)
        rejects(function()build({bad={kind='material',requirements={coins=5}}})end)
        equal(build(raw).get('health_tonic').effectId,'restore_health')
    end)
end
