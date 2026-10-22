return function(test,equal)
    local Images=dofile('src/client/ItemImages.lua')
    test('every catalog item has a named texture entry with optional artwork',function()
        local definitions=dofile('src/shared/ItemDefinitions.lua')
        local textures=dofile('src/shared/ItemTextures.lua')
        local count=0
        for id,item in pairs(definitions)do
            assert(type(textures[id])=='table','Missing texture placeholder: '..id)
            equal(textures[id].name,item.name)
            if textures[id].decalId~=nil then assert(Images.assetId(textures[id].decalId),'Invalid configured image: '..id)end
            count=count+1
        end
        assert(count>0,'Expected catalog entries')
        for id in pairs(textures)do assert(definitions[id],'Texture placeholder references an unknown item: '..id)end
    end)
    test('item images accept asset IDs and reject empty or malformed placeholders',function()
        equal(Images.assetId(12345),'rbxassetid://12345')
        equal(Images.assetId('12345'),'rbxassetid://12345')
        equal(Images.assetId('rbxassetid://12345'),'rbxassetid://12345')
        equal(Images.assetId(nil),nil)
        for _,value in ipairs({false,0,-1,1.5,math.huge,0/0,'','0','abc','https://example.com/image.png',
            'rbxassetid://0','rbxassetid://-1','rbxassetid://1.5',{}})do
            equal(Images.assetId(value),nil)
        end
    end)
    test('null item textures create no art while configured assets create a fitted image',function()
        local env=setmetatable({Enum={ScaleType={Fit='Fit'}},
            UDim2={fromOffset=function(x,y)return {x,y}end,new=function(...)return {...}end,fromScale=function(x,y)return {x,y}end},
            Vector2={new=function(x,y)return {x,y}end}},{__index=_G})
        local renderer=assert(loadfile('src/client/ItemImages.lua','t',env))()
        local calls=0;local parent={}
        local function make(kind,properties,owner)
            calls=calls+1;equal(kind,'ImageLabel');equal(owner,parent)
            return properties
        end
        equal(renderer.draw(parent,nil,make),nil)
        equal(renderer.draw(parent,{name='Raspberry',decalId=nil},make),nil)
        equal(renderer.draw(parent,{name='Raspberry',decalId='invalid'},make),nil)
        equal(calls,0)
        local image=renderer.draw(parent,{name='Raspberry',decalId=12345},make)
        equal(calls,1);equal(image.Name,'ItemIcon');equal(image.Image,'rbxassetid://12345')
        equal(image.BackgroundTransparency,1);equal(image.ScaleType,'Fit');equal(image.Active,false)
    end)
end
