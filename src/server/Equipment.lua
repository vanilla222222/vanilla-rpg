-- Pure, transactional equipment operations on server-owned profile copies.
local Equipment={}
function Equipment.create(catalog,util)
    local api={}
    local function record(item)
        assert(type(item)=="table" and type(item.instanceId)=="string" and #item.instanceId>0 and item.quantity==1,"Equipment requires one unique item")
        local definition=catalog.get(item.itemId);assert(definition and not definition.stackable,"Unknown or non-equippable item")
        return definition
    end
    function api.modifiers(data)
        local seen, result = {}, {}
        for _,item in pairs(data.inventory.slots)do
            if type(item)=="table" and item.instanceId then
                assert(not seen[item.instanceId],"Duplicate owned instance")
                seen[item.instanceId]=true
            end
        end
        local referenced={}
        for slot,instanceId in pairs(data.equipment)do
            if instanceId then
                assert(not seen[instanceId],"Duplicate equipped instance")
                seen[instanceId],referenced[instanceId]=true,true
                local item=data.equipmentItems[instanceId];local definition=record(item)
                assert(item.instanceId==instanceId and catalog.canEquip(item.itemId,slot),"Invalid equipped item reference or slot")
                result['equipment:'..slot]=definition.stats
            end
        end
        for instanceId in pairs(data.equipmentItems)do assert(referenced[instanceId],"Unreferenced equipment item")end
        return result
    end
    local function requirements(data,definition)
        local req=definition.requirements
        assert(not req.gameLevel or 1+data.gameXP/100>=req.gameLevel,"Game level requirement not met")
        for id,level in pairs(req.skills or {})do
            local skill=data.skills[id] or data.skills.combat[id]
            assert(skill and skill.level>=level,"Skill level requirement not met: "..id)
        end
    end
    local function revision(data,expected)
        local current=data.inventory.revision or 0
        assert(util.integer(current,0,9007199254740990),'Invalid inventory revision')
        if expected~=nil then assert(expected==current,'Inventory changed; try again')end
        return current+1
    end
    function api.equip(data,bagSlot,target,expected)
        assert(type(bagSlot)=="string" and bagSlot:match('^[1-9]%d*$') and tonumber(bagSlot)<=data.inventory.capacity,"Invalid inventory slot")
        api.modifiers(data)
        local item=data.inventory.slots[bagSlot];local definition=record(item)
        requirements(data,definition)
        if target==nil then
            target=definition.toolType or definition.armorSlot or definition.accessorySlot
            if definition.kind=='weapon' then
                target='weapon1'
                for i=1,4 do if not data.equipment['weapon'..i] then target='weapon'..i;break end end
            end
        end
        assert(catalog.canEquip(item.itemId,target),'Item does not fit this equipment slot')
        local nextData=util.copy(data)
        local previous=nextData.equipment[target]
        nextData.inventory.slots[bagSlot]=previous and nextData.equipmentItems[previous] or nil
        if previous then nextData.equipmentItems[previous]=nil end
        nextData.equipment[target]=item.instanceId
        nextData.equipmentItems[item.instanceId]=util.copy(item)
        nextData.inventory.revision=revision(data,expected)
        api.modifiers(nextData)
        return nextData
    end
    function api.unequip(data,slot,expected)
        assert(type(slot)=='string' and data.equipment[slot],"Equipment slot is empty")
        api.modifiers(data)
        local free
        for i=1,data.inventory.capacity do if data.inventory.slots[tostring(i)]==nil then free=tostring(i);break end end
        assert(free,"Inventory is full")
        local nextData=util.copy(data);local id=nextData.equipment[slot]
        nextData.inventory.slots[free]=nextData.equipmentItems[id]
        nextData.equipmentItems[id]=nil;nextData.equipment[slot]=false
        nextData.inventory.revision=revision(data,expected)
        api.modifiers(nextData)
        return nextData
    end
    return api
end
return Equipment
