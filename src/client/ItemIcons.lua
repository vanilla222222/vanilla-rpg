-- Layered local GUI artwork: bevels, wood grain, leather wraps, rivets and highlights.
local Icons={}
function Icons.draw(parent,id,make)
    local root=make('Frame',{Name='ItemIcon',BackgroundTransparency=1,Size=UDim2.fromOffset(38,38),Position=UDim2.new(.5,-19,0,2)},parent)
    local canvas=make('Frame',{BackgroundTransparency=1,Size=UDim2.fromOffset(100,100)},root)
    make('UIScale',{Scale=.38},canvas)
    local wood=Color3.fromRGB(155,98,51)
    local grain=Color3.fromRGB(214,164,100)
    local iron=Color3.fromRGB(162,193,210)
    local edge=Color3.fromRGB(231,247,250)
    local shadow=Color3.fromRGB(58,81,102)
    local brass=Color3.fromRGB(224,169,68)
    local leather=Color3.fromRGB(93,56,42)
    local function rect(x,y,w,h,angle,tint)
        return make('Frame',{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Rotation=angle or 0,BackgroundColor3=tint,BorderSizePixel=0,Active=false},canvas)
    end
    local function line(x1,y1,x2,y2,width,tint)
        local dx,dy=x2-x1,y2-y1
        local f=rect((x1+x2)/2,(y1+y2)/2,math.sqrt(dx*dx+dy*dy),width,math.deg(math.atan2(dy,dx)),tint)
        f.AnchorPoint=Vector2.new(.5,.5);return f
    end
    local function rivet(x,y)
        local f=rect(x-3,y-3,6,6,0,shadow)
        make('UICorner',{CornerRadius=UDim.new(1,0)},f)
        rect(x-1,y-2,2,2,0,edge)
    end
    local function shaft(x1,y1,x2,y2,width)
        line(x1+2,y1+2,x2+2,y2+2,width+3,shadow)
        line(x1,y1,x2,y2,width,wood)
        line(x1-1,y1-1,x2-1,y2-1,2,grain)
        local dx,dy=x2-x1,y2-y1;local length=math.sqrt(dx*dx+dy*dy)
        for i=1,5 do
            local t=.08+i*.065;local x,y=x1+dx*t,y1+dy*t
            line(x-dy/length*width/2,y+dx/length*width/2,x+dy/length*width/2,y-dx/length*width/2,3,leather)
        end
    end
    local function steel(x1,y1,x2,y2,width)
        line(x1+2,y1+2,x2+2,y2+2,width+4,shadow)
        local f=line(x1,y1,x2,y2,width,iron)
        make('UIGradient',{Rotation=90,Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,edge),ColorSequenceKeypoint.new(.34,iron),ColorSequenceKeypoint.new(1,shadow)})},f)
        line(x1-1,y1-2,x2-1,y2-2,2,edge)
    end
    if id=='starter_axe' then
        shaft(24,89,64,15,10)
        rect(48,19,31,24,-26,shadow);rect(48,16,32,24,-26,iron)
        rect(72,10,16,39,-26,shadow);rect(73,10,10,36,-26,edge)
        line(53,23,69,16,2,edge);rivet(61,27);rivet(56,35)
        rect(50,39,14,9,-26,brass)
    elseif id=='starter_pickaxe' then
        shaft(26,91,62,25,10)
        steel(16,42,61,20,12);steel(61,20,90,43,10)
        line(14,42,23,29,3,edge);line(89,43,90,51,3,shadow)
        rect(54,20,14,18,-27,brass);rivet(61,27)
    elseif id=='starter_sword' then
        shaft(24,88,45,62,12)
        steel(45,61,81,15,17);line(43,59,78,14,3,edge)
        line(48,59,81,18,2,shadow)
        steel(29,51,60,77,8);line(29,51,60,77,4,brass)
        rect(17,81,14,12,-40,brass);rivet(24,88);rivet(43,63)
    elseif id=='starter_hoe' then
        shaft(30,90,65,19,10)
        steel(28,23,70,23,13);steel(28,23,18,49,14)
        line(13,45,25,50,3,edge);rect(57,18,15,13,-5,brass);rivet(62,24)
    elseif id=='starter_fishing_rod' then
        shaft(18,90,64,13,6)
        line(64,13,76,15,3,grain)
        for i=1,4 do local x,y=25+i*8,77-i*14;rivet(x,y)end
        line(76,15,88,57,1.7,edge);line(88,57,88,76,1.7,edge)
        line(88,76,83,84,3,iron);line(83,84,76,82,3,iron);line(76,82,75,73,3,iron)
        line(75,73,80,76,2,edge)
        local reel=rect(24,61,18,18,0,brass);make('UICorner',{CornerRadius=UDim.new(1,0)},reel)
        local center=rect(28,65,10,10,0,shadow);make('UICorner',{CornerRadius=UDim.new(1,0)},center)
        line(33,70,43,66,3,brass);rivet(43,66)
    else root:Destroy();return nil end
    return root
end
return Icons
