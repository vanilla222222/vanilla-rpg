-- Pure definition validation/query layer; never trusts a client-supplied item record.
local Catalog = {}
function Catalog.create(raw, types, definitions, util)
    local catalog={}
    local allowed={name=true,kind=true,rarity=true,description=true,icon=true,maxStack=true,
        tradable=true,droppable=true,storable=true,stats=true,toolType=true,armorSlot=true,
        weaponType=true,accessorySlot=true,baseDamage=true,abilityIds=true,requirements=true,
        collection=true,tags=true,effectId=true}
    local subtypeKeys={toolType=true,armorSlot=true,weaponType=true,accessorySlot=true}
    local skills={farming=true,foraging=true,mining=true,fishing=true,heavyMelee=true,lightMelee=true,magic=true,ranged=true}
    local function id(value) return type(value)=="string" and value:match("^[a-z][a-z0-9_]*$")~=nil end
    local function list(value)
        assert(type(value)=="table","Expected string list")
        local count=0
        for key,entry in pairs(value) do
            assert(util.integer(key,1,#value) and type(entry)=="string" and #entry>0,"Invalid string list")
            count=count+1
        end
        assert(count==#value,"Sparse string list")
    end
    for itemId,source in pairs(raw) do
        assert(id(itemId),"Invalid permanent item ID: "..tostring(itemId))
        assert(type(source)=="table","Invalid item definition: "..itemId)
        for key in pairs(source) do assert(allowed[key],"Unknown item property: "..tostring(key)) end
        local rule=types.kinds[source.kind];assert(rule,"Unknown item kind: "..tostring(source.kind))
        local item=util.copy(source)
        item.id,item.stackable=itemId,rule.stackable
        if item.name==nil then item.name=itemId end;assert(type(item.name)=="string" and #item.name>0,"Invalid item name")
        if item.rarity==nil then item.rarity="common" end;assert(types.rarities[item.rarity],"Unknown rarity")
        if item.description==nil then item.description="" end;assert(type(item.description)=="string","Invalid description")
        if item.icon==nil then item.icon="" end;assert(type(item.icon)=="string" and (item.icon=="" or item.icon:match("^rbxassetid://%d+$")),"Invalid icon asset")
        if item.maxStack==nil then item.maxStack=rule.maxStack end
        assert(util.integer(item.maxStack,1,1000000),"Invalid stack limit")
        assert(rule.stackable or item.maxStack==1,"Unique gear cannot stack")
        for _,flag in ipairs({"tradable","droppable","storable"}) do
            if item[flag]==nil then item[flag]=rule[flag]~=false end
            assert(type(item[flag])=="boolean","Invalid item policy")
            assert(rule[flag]~=false or item[flag]==false,"Type policy cannot be relaxed: "..flag)
        end
        for key in pairs(subtypeKeys) do
            if rule.subtype==key then assert(rule.values[item[key]],"Invalid/missing subtype: "..key)
            else assert(item[key]==nil,"Subtype incompatible with kind: "..key) end
        end
        if source.kind=="weapon" then assert(util.finite(item.baseDamage) and item.baseDamage>=0,"Weapon requires nonnegative base damage")
        else assert(item.baseDamage==nil,"Only weapons define base damage") end
        if item.stats==nil then item.stats={} end;assert(type(item.stats)=="table","Invalid stat modifiers")
        for stat,change in pairs(item.stats) do
            assert(rule.stats and definitions.definitive[stat],"Item modifies unknown/defined/dynamic stat: "..tostring(stat))
            assert(type(change)=="table","Invalid stat modifier")
            for operation,value in pairs(change) do
                assert(operation=="flat" or operation=="percent" or operation=="multiplier","Unknown stat operation")
                assert(util.finite(value) and (operation~="multiplier" or value>=0),"Invalid stat value")
            end
        end
        if item.tags==nil then item.tags={} end;list(item.tags)
        if item.abilityIds==nil then item.abilityIds={} end;list(item.abilityIds)
        if item.collection~=nil then assert(id(item.collection),"Invalid collection ID") end
        if source.kind=="consumable" then assert(id(item.effectId),"Consumable requires effect ID")
        else assert(item.effectId==nil,"Only consumables define effect IDs") end
        if item.requirements==nil then item.requirements={} end;assert(type(item.requirements)=="table","Invalid requirements")
        for key,value in pairs(item.requirements) do
            if key=="gameLevel" then assert(util.integer(value,1,1000000),"Invalid game level requirement")
            elseif key=="skills" then
                assert(type(value)=="table","Invalid skill requirements")
                for skill,level in pairs(value) do assert(skills[skill] and util.integer(level,1,1000000),"Invalid skill requirement") end
            else error("Unknown requirement: "..tostring(key)) end
        end
        catalog[itemId]=item
    end
    local api={}
    function api.get(itemId) return util.copy(catalog[itemId]) end
    function api.all() return util.copy(catalog) end
    function api.canEquip(itemId,slot)
        local item=catalog[itemId];if not item then return false end
        if item.kind=="tool" then return slot==item.toolType end
        if item.kind=="armor" then return slot==item.armorSlot end
        if item.kind=="accessory" then return slot==item.accessorySlot end
        if item.kind=="weapon" then return type(slot)=="string" and slot:match("^weapon[1-4]$")~=nil end
        return false -- Talismans belong to their unlimited bag, not equipment slots.
    end
    return api
end
return Catalog
