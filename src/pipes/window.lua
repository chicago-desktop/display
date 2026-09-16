local app = require("app")
local pipes = require("pipes")
local time = require("time")
local gfx = require("gfx")
local base64 = require("base64")
local painter = require("painter")
local definition = {interval = "200ms", close_on_escape = true}
function definition.init(): any
    return {scene = pipes.new(math.tointeger(time.now():unix_nano() % 2147483646) or 1), paused = false}
end
function definition.view(state: any, context: any): any
    if context and context.native and state.frame ~= state.scene.frame then
        state.raster = state.raster or gfx.raster(480,300)
        painter.paint(state.raster,state.scene,480,300)
        state.png = assert(base64.encode(assert(state.raster:encode("png"))))
        state.frame = state.scene.frame
    end
    return {kind = "column", children = {
        {kind = "picture", id = "canvas", png = state.png, fit = "contain", fill = true, background = "#000000",
            text = "3D Pipes preview needs pixel graphics (Kitty or Sixel)."},
        {kind = "row", size = 2, gap = 1, children = {
            {kind = "button", id = "pause", text = state.paused and "Resume" or "Pause"},
            {kind = "button", id = "new", text = "New pipes"},
            {kind = "button", id = "close", text = "Close"},
        }},
    }}
end
function definition.update(state: any, action: any, context: any): boolean
    if action.type == "tick" and not state.paused then state.scene = pipes.step(state.scene); return true end
    if action.type ~= "activate" then return false end
    if action.id == "pause" then state.paused = not state.paused
    elseif action.id == "new" then state.frame = nil; state.scene = pipes.new(math.tointeger((state.scene.seed % 2147483646) + 1) or 1)
    elseif action.id == "close" then context.close()
    else return false end
    return true
end
return {definition = definition, main = app.main(definition)}
