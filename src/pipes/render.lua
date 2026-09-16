-- Perspective pipes with continuous shaded walls and rounded elbows.
-- All drawing is local to the provider; only its encoded PNG crosses the SDK.
local render = {}
local COLORS: {{number}} = {{220,224,22},{32,238,50},{232,223,214},{235,24,18},{32,155,230}}
local CHROME = {{220,226,234},{220,226,234},{220,226,234},{220,226,234},{220,226,234}}
local NEON = {{255,40,190},{30,255,230},{165,70,255},{255,160,20},{80,240,40}}
local BANDS = {0.19,0.39,0.68,0.96,1.2,1.08,0.81,0.52,0.25}
local function tint(color: any, light: number): string
    return string.format("#%02x%02x%02x",math.floor(math.min(255,color[1]*light)),
        math.floor(math.min(255,color[2]*light)),math.floor(math.min(255,color[3]*light)))
end
local function polygon(raster: any, points: any, color: string, width: number, height: number)
    local low,high = height,1
    for _,p in ipairs(points) do low=math.min(low,tonumber(p[2]) or 0);high=math.max(high,tonumber(p[2]) or 0) end
    for y=math.max(1,math.floor(low)),math.min(height,math.ceil(high)) do
        local hits = {}
        for i=1,#points do
            local a,b=points[i],points[i%#points+1]
            if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then
                hits[#hits+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
            end
        end
        table.sort(hits)
        if #hits>=2 then
            local left=math.max(1,math.floor(tonumber(hits[1]) or 1))
            local right=math.min(width,math.ceil(tonumber(hits[#hits]) or 0))
            if right>=left then raster:rect(left,y,right-left+1,1,color) end
        end
    end
end
-- Near objects are larger; the slight yaw exposes depth without an isometric view.
function render.project(p: any, width: number, height: number): any
    local x,y,z=tonumber(p[1]) or 0,tonumber(p[2]) or 0,tonumber(p[3]) or 0
    local rx,rz=x*0.992+z*0.126,-x*0.126+z*0.992
    local depth=math.max(2.5,rz+15)
    local scale=math.max(width,height)*0.9/depth
    return {x=width*0.5+rx*scale,y=height*0.5+y*scale,z=depth,r=0.115*scale}
end
local function mix(a: any,b: any,t: number): any
    return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}
end
local function distance(a: any,b: any): number
    local x,y,z=tonumber(b[1]-a[1]) or 0,tonumber(b[2]-a[2]) or 0,tonumber(b[3]-a[3]) or 0
    return math.sqrt(x*x+y*y+z*z)
end
function render.centerline(points: any): any
    local out={points[1]}
    for i=2,#points-1 do
        local a,b,c=points[i-1],points[i],points[i+1]
        local before,after=distance(a,b),distance(b,c)
        local radius=math.min(0.3,before*0.45,after*0.45)
        if before>0 and after>0 then
            local enter,leave=mix(b,a,radius/before),mix(b,c,radius/after)
            local dot=0
            for axis=1,3 do dot=dot+(b[axis]-a[axis])*(c[axis]-b[axis]) end
            if dot>0 then out[#out+1]=b
            else
                out[#out+1]=enter
                for step=1,5 do
                    local t=step/5
                    out[#out+1]=mix(mix(enter,b,t),mix(b,leave,t),t)
                end
            end
        end
    end
    out[#out+1]=points[#points]
    return out
end
function render.paint(raster: any, scene: any, width: number, height: number, settings: any?)
    local thickness = settings and settings.thickness or "normal"
    local palette = settings and settings.palette or "classic"
    local colors = palette == "chrome" and CHROME or (palette == "neon" and NEON or COLORS)
    local factor = thickness == "thin" and 0.65 or (thickness == "thick" and 1.5 or 1)
    raster:fill("#000000")
    local paths,parts={},{}
    for _,segment in ipairs(scene.segments or {}) do
        local id=segment.pipe or segment.color
        local path=paths[id]
        if not path then path={points={segment.a},color=segment.color};paths[id]=path end
        path.points[#path.points+1]=mix(segment.a,segment.b,tonumber(segment.progress) or 0)
    end
    for id=1,8 do
        local path=paths[id]
        if path then
            local points={}
            for _,point in ipairs(render.centerline(path.points)) do points[#points+1]=render.project(point,width,height) end
            for i,p in ipairs(points) do
                p.r=p.r*factor
                local a,b=points[math.tointeger(math.max(1,i-1)) or 1],points[math.tointeger(math.min(#points,i+1)) or 1]
                local dx,dy=tonumber(b.x-a.x) or 0,tonumber(b.y-a.y) or 0
                local length=math.sqrt(dx*dx+dy*dy)
                p.nx,p.ny=length>0.001 and -dy/length or 1,length>0.001 and dx/length or 0
            end
            for i=1,#points-1 do
                local a,b=points[i],points[i+1]
                parts[#parts+1]={a=a,b=b,color=colors[math.tointeger(path.color) or 1],z=(a.z+b.z)*0.5,order=#parts+1,key=tostring(id)..":"..tostring(i)}
            end
        end
    end
    table.sort(parts,function(a,b) if a.z==b.z then return a.order<b.order end;return a.z>b.z end)
    local previous=scene.render_cache or {}
    if previous.width~=width or previous.height~=height or previous.thickness~=thickness or previous.palette~=palette then previous={} end
    local cached={width=width,height=height,thickness=thickness,palette=palette}
    local function same(a: any,b: any): boolean
        return a ~= nil and b ~= nil and a.x==b.x and a.y==b.y and a.z==b.z and a.nx==b.nx and a.ny==b.ny
    end
    for _,part in ipairs(parts) do
        local a,b=part.a,part.b
        local old=previous[part.key]
        if old and same(a,old.a) and same(b,old.b) then part.spans=old.spans
        else
            local spans={}
            local target={rect=function(_,x,y,w,h,color) spans[#spans+1]={x=x,y=y,w=w,color=color} end}
            local fog=math.max(0.48,1-((tonumber(part.z) or 5)-5)*0.019)
            for band,light in ipairs(BANDS) do
                local lo,hi=-1+2*(band-1)/#BANDS,-1+2*band/#BANDS
                polygon(target,{{a.x+a.nx*a.r*lo,a.y+a.ny*a.r*lo},{b.x+b.nx*b.r*lo,b.y+b.ny*b.r*lo},
                    {b.x+b.nx*b.r*hi,b.y+b.ny*b.r*hi},{a.x+a.nx*a.r*hi,a.y+a.ny*a.r*hi}},tint(part.color,light*fog),width,height)
            end
            part.spans=spans
        end
        for _,span in ipairs(part.spans) do raster:rect(span.x,span.y,span.w,1,span.color) end
        cached[part.key]=part
    end
    -- Keep only this scene's visible geometry, never previous frames or scenes.
    scene.render_cache=cached
end
return render
