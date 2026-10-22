-- All operations return a validated copy. Failed operations never edit ownership.
local Inventory={}
function Inventory.create(catalog,util,Equipment)
    local api={}
    local MAX=9007199254740991
    local function equal(a,b,root)
        if type(a)~=type(b)then return false end
        if type(a)~='table'then return a==b end
        for key,value in pairs(a)do if not (root and key=='quantity') and not equal(value,b[key])then return false end end
        for key in pairs(b)do if not (root and key=='quantity') and a[key]==nil then return false end end
        return true
    end
    function api.compatible(a,b)
        if not a or not b then return false end
        local definition=catalog.get(a.itemId)
        return definition~=nil and definition.stackable and equal(a,b,true)
    end
    local function slot(data,key)
        assert(type(key)=='string' and #key<=16 and key:match('^[1-9]%d*$') and tonumber(key)<=data.inventory.capacity,'Invalid inventory slot')
    end
    function api.validate(data)
        assert(util.integer(data.inventory.capacity,30,MAX),'Invalid inventory capacity')
        assert(util.integer(data.inventory.revision,0,MAX),'Invalid inventory revision')
        for key,item in pairs(data.inventory.slots)do
            slot(data,key)
            assert(type(item)=='table','Invalid inventory item record')
            local definition=catalog.get(item.itemId);assert(definition,'Unknown inventory item')
            assert(util.integer(item.quantity,1,definition.maxStack),'Invalid item quantity')
            if definition.stackable then assert(item.instanceId==nil,'Stack cannot have a unique instance ID')
            else assert(type(item.instanceId)=='string' and #item.instanceId>0 and item.quantity==1,'Invalid unique item')end
        end
        Equipment.modifiers(data)
    end
    function api.checkRevision(data,expected)
        assert(util.integer(expected,0,MAX) and expected==data.inventory.revision,'Inventory changed; try again')
    end
    local function finish(data)
        assert(data.inventory.revision<MAX,'Inventory revision overflow')
        data.inventory.revision=data.inventory.revision+1
        api.validate(data);return data
    end
    function api.change(data,action,from,to,amount,expected)
        api.checkRevision(data,expected);api.validate(data);slot(data,from);slot(data,to)
        assert(from~=to,'Choose a different destination')
        local source,target=data.inventory.slots[from],data.inventory.slots[to]
        assert(source,'Source slot is empty')
        assert(action=='move' or action=='split' or action=='merge' or action=='swap','Unknown inventory action')
        local count=amount==nil and source.quantity or amount
        assert(util.integer(count,1,source.quantity),'Invalid transfer amount')
        if action=='split' then
            assert(catalog.get(source.itemId).stackable and count<source.quantity and target==nil,'Split requires an empty slot and part of a stack')
        elseif action=='merge' then assert(api.compatible(source,target),'Stacks are not compatible')
        elseif action=='swap' then assert(target and count==source.quantity,'Swap requires two complete items')end
        local result=util.copy(data)
        local slots=result.inventory.slots
        if not target then
            slots[to]=util.copy(source);slots[to].quantity=count
            if count==source.quantity then slots[from]=nil else slots[from].quantity=source.quantity-count end
        elseif action~='swap' and api.compatible(source,target)then
            local room=catalog.get(source.itemId).maxStack-target.quantity
            assert(room>0,'Destination stack is full')
            local moved=math.min(count,room)
            slots[to].quantity=target.quantity+moved
            if moved==source.quantity then slots[from]=nil else slots[from].quantity=source.quantity-moved end
        else
            assert(action~='split' and count==source.quantity,'Partial transfers cannot swap items')
            slots[from],slots[to]=util.copy(target),util.copy(source)
        end
        return finish(result)
    end
    function api.grantStack(data,itemId,quantity)
        api.validate(data)
        local definition=catalog.get(itemId)
        assert(definition and definition.stackable,'Grant requires a stackable definition')
        assert(util.integer(quantity,1,1000000),'Invalid grant quantity')
        local result=util.copy(data);local remaining=quantity
        local template={itemId=itemId,quantity=1}
        local keys={};for key in pairs(result.inventory.slots)do table.insert(keys,key)end
        table.sort(keys,function(a,b)return tonumber(a)<tonumber(b)end)
        for _,key in ipairs(keys)do
            local item=result.inventory.slots[key]
            if api.compatible(template,item)then
                local count=math.min(remaining,definition.maxStack-item.quantity)
                item.quantity=item.quantity+count;remaining=remaining-count
                if remaining==0 then break end
            end
        end
        local index=1
        while remaining>0 do
            while index<=result.inventory.capacity and result.inventory.slots[tostring(index)]do index=index+1 end
            assert(index<=result.inventory.capacity,'Inventory is full')
            local count=math.min(remaining,definition.maxStack)
            result.inventory.slots[tostring(index)]={itemId=itemId,quantity=count}
            remaining=remaining-count;index=index+1
        end
        return finish(result)
    end
    function api.removeStack(data,itemId,quantity)
        api.validate(data)
        local definition=catalog.get(itemId)
        assert(definition and definition.stackable and util.integer(quantity,1,1000000),'Invalid stack removal')
        local result=util.copy(data);local remaining=quantity
        local keys={};for key in pairs(result.inventory.slots)do table.insert(keys,key)end
        table.sort(keys,function(a,b)return tonumber(a)<tonumber(b)end)
        for _,key in ipairs(keys)do
            local item=result.inventory.slots[key]
            if api.compatible({itemId=itemId,quantity=1},item)then
                local count=math.min(remaining,item.quantity)
                item.quantity=item.quantity-count;remaining=remaining-count
                if item.quantity==0 then result.inventory.slots[key]=nil end
                if remaining==0 then break end
            end
        end
        assert(remaining==0,'Not enough items')
        return finish(result)
    end
    return api
end
return Inventory
