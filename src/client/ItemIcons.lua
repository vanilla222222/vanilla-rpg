-- Local vector-style GUI icons; no external image uploads or asset IDs required.
local Icons={}
function Icons.draw(parent,id,make)
    local root=make("Frame",{Name="ItemIcon",BackgroundTransparency=1,Size=UDim2.fromOffset(36,36),Position=UDim2.new(.5,-18,0,3)},parent)
    local canvas=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(100,100)},root)
    make("UIScale",{Scale=.36},canvas)
    local wood=Color3.fromRGB(180,126,72)
    local metal=Color3.fromRGB(181,218,230)
    local dark=Color3.fromRGB(89,126,143)
    local gold=Color3.fromRGB(226,178,77)
    local function rect(x,y,w,h,rotation,tint)
        return make("Frame",{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Rotation=rotation or 0,BackgroundColor3=tint,BorderSizePixel=0},canvas)
    end
    local function line(x1,y1,x2,y2,width,tint)
        local dx,dy=x2-x1,y2-y1
        local f=rect((x1+x2)/2,(y1+y2)/2,math.sqrt(dx*dx+dy*dy),width,math.deg(math.atan2(dy,dx)),tint)
        f.AnchorPoint=Vector2.new(.5,.5)
        return f
    end
    if id=="starter_axe" then
        line(28,86,66,18,10,wood);rect(48,18,37,25,-28,metal);rect(72,13,15,37,-28,dark)
    elseif id=="starter_pickaxe" then
        line(28,88,62,27,10,wood);line(20,36,63,22,11,metal);line(63,22,89,42,9,dark)
    elseif id=="starter_sword" then
        line(26,84,45,62,12,wood);line(42,63,80,17,17,metal);line(46,56,82,15,5,Color3.fromRGB(233,247,251))
        line(29,51,58,76,9,gold);rect(19,81,14,12,-40,gold)
    elseif id=="starter_hoe" then
        line(30,88,66,20,10,wood);line(30,24,70,24,13,metal);line(30,24,21,48,12,dark)
    elseif id=="starter_fishing_rod" then
        line(20,87,66,12,7,wood);line(66,12,88,65,2,metal);line(88,65,88,80,3,metal)
        line(88,80,80,86,3,metal);line(80,86,75,78,3,metal);rect(27,65,15,12,-55,gold)
    else
        root:Destroy();return nil
    end
    return root
end
return Icons
