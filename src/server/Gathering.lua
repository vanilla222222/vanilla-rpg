-- Pure loot planning/application. The runtime separately validates distance, hold and cooldown.
local Gathering={}
function Gathering.create(resources,catalog,collections,Inventory,Rules,util)
    local api={};local MAX=9007199254740991
    for id,resource in pairs(resources)do
        assert(resource.skill and resource.cooldownSeconds>=1,'Invalid resource: '..id)
        assert((resource.toolSlot==nil and resource.requiredStat==nil and resource.requiredValue==nil)
            or (type(resource.toolSlot)=='string' and type(resource.requiredStat)=='string'
            and util.finite(resource.requiredValue) and resource.requiredValue>=0),'Incomplete tool requirement: '..id)
        for _,entry in ipairs(resource.loot)do
            local item=catalog.get(entry.itemId)
            assert(item and util.finite(entry.chance) and entry.chance>0 and entry.chance<=100,'Invalid resource loot')
            assert(item.stackable or item.kind=='talisman','Unsupported resource reward type')
            if item.stackable then assert(item.collection and collections[item.collection],'Resource item needs a collection')end
        end
    end
    local function add(a,b)
        assert(util.integer(a,0,MAX) and util.integer(b,0,MAX) and b<=MAX-a,'Progression counter overflow')
        return a+b
    end
    local function apply(data,resource,loot,stats)
        local result=util.copy(data)
        for _,drop in ipairs(loot)do
            if drop.quantity>0 then
                local item=catalog.get(drop.itemId)
                if item.kind=='talisman'then
                    local owned=result.talismans[drop.itemId]
                    local count=owned==true and 1 or (type(owned)=='table' and owned.count or 0)
                    local entry=type(owned)=='table' and util.copy(owned)or {}
                    entry.count=add(count,drop.quantity);result.talismans[drop.itemId]=entry
                else
                    result=Inventory.grantStack(result,drop.itemId,drop.quantity)
                    result.collections[item.collection]=add(result.collections[item.collection] or 0,drop.quantity)
                end
            end
        end
        local skill=result.skills[resource.skill];assert(skill,'Missing resource skill')
        local remainder=skill.xpRemainder or 0
        assert(util.finite(remainder) and remainder>=0 and remainder<1,'Invalid fractional XP carry')
        local xp=resource.baseXP*Rules.wisdomMultiplier(stats[resource.wisdom])+remainder
        assert(util.finite(xp) and xp>=0,'Invalid gathering XP')
        local gained=math.floor(xp)
        skill.xp=add(skill.xp,gained);skill.xpRemainder=xp-gained
        Inventory.validate(result)
        return result,gained
    end
    function api.harvest(data,stats,id,random)
        local resource=resources[id];assert(resource,'Unknown resource')
        Inventory.validate(data)
        if resource.toolSlot then
            local reference=data.equipment[resource.toolSlot]
            local tool=reference and data.equipmentItems[reference]
            assert(tool and catalog.canEquip(tool.itemId,resource.toolSlot),'Equip the required tool first')
            assert(stats[resource.requiredStat]>=resource.requiredValue,'Your tool cannot harvest this resource')
        end
        -- Reserve worst-case space before randomness so a full bag cannot reroll rare loot.
        local maximum={}
        for _,entry in ipairs(resource.loot)do
            local chance=Rules.fortuneChance(entry.chance,stats[resource.fortune])
            table.insert(maximum,{itemId=entry.itemId,quantity=math.ceil(chance/100)})
        end
        apply(data,resource,maximum,stats)
        local loot={}
        for _,entry in ipairs(resource.loot)do
            local quantity=Rules.fortuneDrops(entry.chance,stats[resource.fortune],random)
            if quantity>0 then table.insert(loot,{itemId=entry.itemId,quantity=quantity})end
        end
        local result,xp=apply(data,resource,loot,stats)
        return result,{resource=id,skill=resource.skill,xp=xp,loot=loot}
    end
    return api
end
return Gathering
