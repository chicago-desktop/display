-- Project 3D pipe walks onto a black canvas; shaded cylinders and round joints.
-- The window process draws this raster; the SDK owns controls, input and layout.
local render = {}
local COLORS: {{number}} = {{235,58,45}, {40,155,245}, {236,177,30}}
local function tint(color: any, strength: number): string
    return string.format("#%02x%02x%02x", math.floor(math.min(255,color[1]*strength)),
        math.floor(math.min(255,color[2]*strength)), math.floor(math.min(255,color[3]*strength)))
end
local function circle(raster: any, x: number, y: number, r: number, color: string)
    for row = math.floor(-r), math.ceil(r) do
        local width = math.sqrt(math.max(0, r*r-row*row))
        if width > 0 then raster:rect(math.floor(x-width), math.floor(y+row), math.ceil(width*2), 1, color) end
    end
end
local function joint(raster: any, x: number, y: number, r: number, color: any)
    circle(raster,x,y,r,tint(color,0.35))
    for band = 1, 5 do
        local fraction = band / 6
        circle(raster,x-r*0.23*fraction,y-r*0.3*fraction,r*(1-fraction*0.77),tint(color,0.48+fraction*0.82))
    end
    circle(raster,x-r*0.28,y-r*0.4,math.max(1,r*0.17),"#fff3d5")
end
local function polygon(raster: any, points: {{number}}, color: string)
    local low, high = points[1][2], points[1][2]
    for _, p in ipairs(points) do low = math.min(low,p[2]); high = math.max(high,p[2]) end
    for y = math.floor(low), math.ceil(high) do
        local hits = {}
        for i = 1, #points do
            local a, b = points[i], points[i % #points+1]
            if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
                hits[#hits+1] = a[1] + (y-a[2])*(b[1]-a[1])/(b[2]-a[2])
            end
        end
        table.sort(hits)
        if #hits >= 2 then raster:rect(math.floor(hits[1]),y,math.max(1,math.ceil((tonumber(hits[#hits]) or 0)-(tonumber(hits[1]) or 0))),1,color) end
    end
end
local function tube(raster: any, a: {x: number, y: number, z: number}, b: {x: number, y: number, z: number}, radius: number, color: any)
    local dx, dy = b.x-a.x, b.y-a.y
    local length = math.sqrt(dx*dx+dy*dy)
    if length < 0.1 then return end
    local nx, ny = -dy/length, dx/length
    local bands = {0.32,0.58,0.9,1.3,1.08,0.72,0.42}
    for i, light in ipairs(bands) do
        local lo, hi = -radius+(i-1)*radius*2/#bands, -radius+i*radius*2/#bands
        polygon(raster,{{a.x+nx*lo,a.y+ny*lo},{b.x+nx*lo,b.y+ny*lo},
            {b.x+nx*hi,b.y+ny*hi},{a.x+nx*hi,a.y+ny*hi}},tint(color,light))
    end
    joint(raster,b.x,b.y,radius,color)
end
function render.paint(raster: any, scene: any, width: number, height: number)
    raster:fill("#000000")
    local scale = math.max(1,math.min(width/17,height/15))
    local function project(p: any): {x: number, y: number, z: number}
        local px,py,pz = tonumber(p[1]) or 0,tonumber(p[2]) or 0,tonumber(p[3]) or 0
        local x,z = px*0.84+pz*0.54,-px*0.54+pz*0.84
        return {x=width/2+x*scale, y=height/2+(py*0.9-z*0.44)*scale, z=z*0.9+py*0.44}
    end
    local parts = {}
    for index, segment in ipairs(scene.segments or {}) do
        local point = {}
        for axis = 1,3 do point[axis] = segment.a[axis]+(segment.b[axis]-segment.a[axis])*segment.progress end
        local a, b = project(segment.a), project(point)
        parts[#parts+1] = {a=a,b=b,color=COLORS[math.tointeger(segment.color) or 1],depth=(a.z+b.z)/2,index=index}
    end
    table.sort(parts,function(a,b) if a.depth == b.depth then return a.index < b.index end; return a.depth < b.depth end)
    local radius = math.max(2,scale*0.18)
    for _, part in ipairs(parts) do
        if part.index <= 3 then joint(raster,tonumber(part.a.x) or 0,tonumber(part.a.y) or 0,radius,part.color) end
        tube(raster,part.a,part.b,radius,part.color)
    end
end
return render
