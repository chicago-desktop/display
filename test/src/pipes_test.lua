local test = require("test")
local pipes = require("pipes")
local window = require("window")
local renderer = require("renderer")
local display = require("display")
local ui = require("ui")
local app = require("app")
local rasters = require("rasters")
local gfx = require("gfx")
local fs = require("fs")
local time = require("time")
local function define_tests()
    test.describe("3D Pipes preview", function()
        test.it("grows bounded non-intersecting grid paths and resets without accumulating history", function()
            local scene = pipes.new(31415)
            local resets, previous = 0, 0
            for tick = 1, 1200 do
                scene = pipes.step(scene)
                test.is_true(#scene.segments <= pipes.LIMIT)
                if #scene.segments < previous then resets = resets+1 end
                previous = #scene.segments
                local occupied = {}
                for _, segment in ipairs(scene.segments) do
                    local delta = 0
                    for axis = 1,3 do delta = delta + math.abs(segment.a[axis]-segment.b[axis]) end
                    test.eq(delta,1)
                    test.is_true(segment.progress > 0 and segment.progress <= 1)
                    local key = table.concat(segment.b,",")
                    test.is_nil(occupied[key]); occupied[key] = true
                end
            end
            test.is_true(resets > 0)
        end)
        test.it("pauses, starts a new scene and closes on request", function()
            local state = window.definition.init()
            window.definition.update(state,{type="tick"},{})
            local frame = state.scene.frame
            window.definition.update(state,{type="activate",id="pause"},{})
            test.is_false(window.definition.update(state,{type="tick"},{}))
            test.eq(state.scene.frame,frame)
            window.definition.update(state,{type="activate",id="new"},{})
            test.eq(#state.scene.segments,0)
            local context: any = {closed=false}
            context.close = function() context.closed=true end
            window.definition.update(state,{type="activate",id="close"},context)
            test.is_true(context.closed)
        end)
        test.it("opens Preview from Display and reports launch failures", function()
            local calls: any = {count=0}
            local state: any = {preview=function() calls.count=calls.count+1; return true end}
            display.definition.update(state,{type="activate",id="preview"},{})
            test.eq(calls.count,1); test.is_nil(state.failure)
            state.preview=function() return nil,"Desktop unavailable" end
            display.definition.update(state,{type="activate",id="preview"},{})
            test.eq(state.failure,"Desktop unavailable")
        end)
        test.it("renders growing pipes and reuses an unchanged frame at different window sizes", function()
            local state: any = {scene=pipes.new(31415),paused=false}
            for i=1,160 do state.scene=pipes.step(state.scene) end
            local files=assert(fs.get("chicago.shell.theme:fonts"))
            local fonts={face=assert(gfx.font(assert(files:readfile("LiberationSans-Regular.ttf")),{size=13,smooth=true}))}
            for _, size in ipairs({{78,27},{42,16}}) do
                local context=app.context({width=size[1],height=size[2],native=true,cell_w=10,cell_h=20})
                local tree=window.definition.view(state,context)
                test.is_nil(ui.problem(tree))
                local store=rasters.store();store.begin()
                local data={id="pipes",state_revision=1,content_state={sdk=1,revision=1,ui=tree,interaction=context.interaction}}
                local inner={x=1,y=1,cols=size[1],rows=size[2]}
                local before=time.now():unix_nano()
                local image=assert(renderer.placement(data,inner,{w=10,h=20},fonts,store))
                local elapsed=(time.now():unix_nano()-before)/1000000
                assert(assert(fs.get("app:shots")):writefile("pipes_timing_" .. tostring(size[1]) .. ".txt", tostring(elapsed)))
                local revision=image.raster:version()
                local again=assert(renderer.placement(data,inner,{w=10,h=20},fonts,store))
                test.eq(again.raster:version(),revision)
                assert(assert(fs.get("app:shots")):writefile("pipes_"..tostring(size[1])..".png",assert(image.raster:encode("png"))))
                state.scene=pipes.step(state.scene)
                data.state_revision=2
                tree=window.definition.view(state,context)
                data.content_state.ui=tree
                local changed=assert(renderer.placement(data,inner,{w=10,h=20},fonts,store))
                test.is_true(changed.raster:version()>revision)
            end
        end)
    end)
end
local run_cases=test.run_cases(define_tests)
return {run=function(options) return run_cases(options) end}
