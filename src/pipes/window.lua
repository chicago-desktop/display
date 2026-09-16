local app = require("app")
local pipes = require("pipes")
local options = require("options")
local time = require("time")
local gfx = require("gfx")
local base64 = require("base64")
local painter = require("painter")
local definition = {interval = "200ms", close_on_escape = true}
function definition.init(args: any?): any
    local scene = pipes.new(math.tointeger(time.now():unix_nano() % 2147483646) or 1)
    -- Start with a few visible paths; the rest of the scene grows on screen.
    for tick=1,40 do scene=pipes.step(scene) end
    return {scene=scene,options=options.read(args)}
end
function definition.view(state: any, context: any): any
    local width,height=640,400
    if context and context.cell then
        local w=math.max(1,(tonumber(context.width) or 1)*(tonumber(context.cell.w) or 1))
        local h=math.max(1,(tonumber(context.height) or 1)*(tonumber(context.cell.h) or 1))
        local scale=math.min(1,800/w,600/h)
        width,height=math.max(1,math.floor(w*scale)),math.max(1,math.floor(h*scale))
    end
    if context and context.native and (state.frame~=state.scene.frame or state.width~=width or state.height~=height) then
        if state.width~=width or state.height~=height then state.raster=gfx.raster(width,height) end
        painter.paint(state.raster,state.scene,width,height,state.options)
        state.png=assert(base64.encode(assert(state.raster:encode("png"))))
        state.frame,state.width,state.height=state.scene.frame,width,height
    end
    return {kind="picture",id="canvas",png=state.png,fit="contain",fill=true,background="#000000",
        text="3D Pipes needs pixel graphics. Press any key to return to Display."}
end
function definition.update(state: any, action: any, context: any): boolean
    if action.type=="tick" then state.scene=pipes.step(state.scene,state.options and state.options.speed);return true end
    if action.type=="key" and action.action~="release" then context.close();return false end
    return action.type=="resize"
end
return {definition=definition,main=app.main(definition)}
