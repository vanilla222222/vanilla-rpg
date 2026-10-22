-- Asset-backed slot artwork only. Missing/invalid placeholders create no image.
local Images={}
function Images.assetId(value)
    if type(value)=='number' then
        if value~=value or value<1 or value>9007199254740991 or value%1~=0 then return nil end
        return 'rbxassetid://'..string.format('%.0f',value)
    end
    if type(value)~='string' then return nil end
    local digits=value:match('^rbxassetid://(%d+)$')or value:match('^(%d+)$')
    if not digits then return nil end
    digits=digits:gsub('^0+','')
    if #digits==0 or #digits>20 then return nil end
    return 'rbxassetid://'..digits
end
function Images.draw(parent,entry,make)
    local asset=type(entry)=='table' and Images.assetId(entry.decalId)or nil
    if not asset then return nil end
    return make('ImageLabel',{Name='ItemIcon',Image=asset,BackgroundTransparency=1,
        Size=UDim2.fromOffset(38,38),Position=UDim2.new(.5,-19,0,2),
        ScaleType=Enum.ScaleType.Fit,Active=false},parent)
end
return Images
