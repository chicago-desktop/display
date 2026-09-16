local test = require("test")
local pipes = require("pipes")
local options = require("options")
local settings = require("settings")
local window = require("window")
local renderer = require("renderer")
local painter = require("painter")
local chrome = require("chrome")
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
        test.it("grows on tick, closes on keys and has no window controls", function()
            local state=window.definition.init()
            local before=state.scene.frame
            window.definition.update(state,{type="tick"},{})
            test.eq(state.scene.frame,before+1)
            local context=app.context({width=80,height=24})
            local tree=window.definition.view(state,context)
            test.eq(tree.kind,"picture");test.is_nil(tree.children);test.is_nil(tree.png)
            window.definition.update(state,{type="key",key="a"},context)
            test.is_true(context.closing)
        end)
        test.it("projects near pipes larger and rounds corners with continuous centerlines",function()
            local near=painter.project({1,1,-8},800,500)
            local far=painter.project({1,1,8},800,500)
            test.is_true(near.r>far.r*2)
            test.is_true(near.y>far.y)
            local curve=painter.centerline({{0,0,0},{1,0,0},{1,1,0}})
            test.is_true(#curve>4)
            test.is_true(curve[3][1]<1 and curve[3][2]>0)
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
        test.it("saves validated settings on OK, cancels without writing and keeps failed saves open",function()
            test.eq(options.encode("bad:thick:chrome"),"normal:thick:chrome")
            test.eq(options.encode(nil),"normal:normal:classic")
            local calls:any={writes=0,closes=0}
            local state:any={values=options.read(nil),persist=function(value)
                calls.writes=calls.writes+1;calls.value=value;return true,nil end}
            local context={close=function() calls.closes=calls.closes+1 end}
            settings.definition.update(state,{type="change",id="speed",value="fast"},context)
            settings.definition.update(state,{type="change",id="thickness",value="invalid"},context)
            settings.definition.update(state,{type="activate",id="cancel"},context)
            test.eq(calls.writes,0)
            settings.definition.update(state,{type="activate",id="ok"},context)
            test.eq(calls.value,"fast:normal:classic");test.eq(calls.closes,2)
            state.persist=function() return nil,"Database busy" end
            settings.definition.update(state,{type="activate",id="ok"},context)
            test.eq(calls.closes,2);test.eq(state.failure,"Database busy")
            local slow,fast=pipes.new(123),pipes.new(123)
            slow=pipes.step(slow,"slow");fast=pipes.step(fast,"fast")
            test.is_true(fast.segments[1].progress>slow.segments[1].progress)
            local scene=pipes.new(123)
            for i=1,40 do scene=pipes.step(scene) end
            local raster=gfx.raster(320,240)
            painter.paint(raster,scene,320,240)
            local classic=assert(raster:encode("png"))
            painter.paint(raster,scene,320,240,options.read("fast:thick:chrome"))
            local configured=assert(raster:encode("png"))
            test.is_true(classic~=configured)
            scene.render_cache=nil
            painter.paint(raster,scene,320,240,options.read("fast:thick:chrome"))
            test.eq(assert(raster:encode("png")),configured,"option changes invalidate cached colors and widths")
        end)
        test.it("renders the classic Screen Saver structure and its settings dialog",function()
            local files=assert(fs.get("chicago.shell.theme:fonts"))
            local fonts={face=assert(gfx.font(assert(files:readfile("LiberationSans-Regular.ttf")),{size=13,smooth=true}))}
            for _,cell in ipairs({{8,16},{10,20}}) do
                chrome.use_cell_size(cell[1],cell[2])
                local inset=chrome.window_insets({})
                local cols,rows=54-inset.left-inset.right,28-inset.top-inset.bottom
                local context=app.context({width=cols,height=rows,native=true,cell_w=cell[1],cell_h=cell[2]})
                local tree=display.definition.view({tab=2},context)
                test.is_nil(ui.problem(tree))
                local plan=ui.plan(tree,cols,rows,context.interaction,{cell={w=cell[1],h=cell[2]}})
                test.eq(plan.by_id.saver.rect.y,plan.by_id.preview.rect.y)
                test.eq(plan.by_id.saver.rect.y,plan.by_id.saver_settings.rect.y)
                test.is_true(plan.by_id.wait.node.disabled)
                test.is_true(plan.by_id.resume.node.disabled)
                test.is_true(plan.by_id.power.node.disabled)
                local store=rasters.store();store.begin()
                local image=assert(renderer.placement({id="display",state_revision=1,content_state={sdk=1,revision=1,ui=tree}},
                    {x=1,y=1,cols=cols,rows=rows},{w=cell[1],h=cell[2]},fonts,store))
                assert(assert(fs.get("app:shots")):writefile("screen_saver_"..tostring(cell[1])..".png",assert(image.raster:encode("png"))))
                local settings_tree=settings.definition.view({values=options.read(nil)},context)
                test.is_nil(ui.problem(settings_tree))
                local sheet=assert(renderer.placement({id="settings",state_revision=1,content_state={sdk=1,revision=1,ui=settings_tree}},
                    {x=1,y=1,cols=34,rows=16},{w=cell[1],h=cell[2]},fonts,store))
                assert(assert(fs.get("app:shots")):writefile("pipes_settings_"..tostring(cell[1])..".png",assert(sheet.raster:encode("png"))))
            end
        end)
        test.it("renders growing pipes and reuses an unchanged frame at different window sizes", function()
            local state: any = {scene=pipes.new(31415),paused=false}
            for i=1,200 do state.scene=pipes.step(state.scene) end
            local files=assert(fs.get("chicago.shell.theme:fonts"))
            local fonts={face=assert(gfx.font(assert(files:readfile("LiberationSans-Regular.ttf")),{size=13,smooth=true}))}
            for _, size in ipairs({{78,27},{42,16}}) do
                local context=app.context({width=size[1],height=size[2],native=true,cell_w=10,cell_h=20})
                local started=time.now():unix_nano()
                local tree=window.definition.view(state,context)
                local provider_ms=(time.now():unix_nano()-started)/1000000
                test.is_nil(ui.problem(tree))
                local store=rasters.store();store.begin()
                local data={id="pipes",state_revision=1,content_state={sdk=1,revision=1,ui=tree,interaction=context.interaction}}
                local inner={x=1,y=1,cols=size[1],rows=size[2]}
                local before=time.now():unix_nano()
                local image=assert(renderer.placement(data,inner,{w=10,h=20},fonts,store))
                local elapsed=(time.now():unix_nano()-before)/1000000
                assert(assert(fs.get("app:shots")):writefile("pipes_timing_" .. tostring(size[1]) .. ".txt", "provider="..tostring(provider_ms)..", compositor="..tostring(elapsed)))
                chrome.use_fonts(fonts.face,fonts.face)
                data.render="chicago.shell.sdk:render";data.content="pixels"
                local full=chrome.paint({width=size[1],height=size[2],presentation=data},10,20)
                test.eq(#full.hits.bars,0);test.eq(#full.hits.desktop,0)
                local rows=0
                for _,part in ipairs(full.placements) do
                    test.eq(part.x,1);test.eq(part.cols,size[1]);rows=rows+part.rows
                end
                test.eq(rows,size[2],"presentation covers the entire screen without a frame or taskbar")
                local revision=image.raster:version()
                local again=assert(renderer.placement(data,inner,{w=10,h=20},fonts,store))
                test.eq(again.raster:version(),revision)
                assert(assert(fs.get("app:shots")):writefile("pipes_"..tostring(size[1])..".png",assert(image.raster:encode("png"))))
                state.scene=pipes.step(state.scene)
                data.state_revision=2
                local tick_at=time.now():unix_nano()
                tree=window.definition.view(state,context)
                assert(assert(fs.get("app:shots")):writefile("pipes_tick_"..tostring(size[1])..".txt",tostring((time.now():unix_nano()-tick_at)/1000000)))
                data.content_state.ui=tree
                local changed=assert(renderer.placement(data,inner,{w=10,h=20},fonts,store))
                test.is_true(changed.raster:version()>revision)
                local expected=assert(state.raster:encode("png"))
                state.scene.render_cache=nil
                local pw,ph=tonumber(state.width) or 1,tonumber(state.height) or 1
                local fresh=gfx.raster(pw,ph)
                painter.paint(fresh,state.scene,pw,ph)
                test.eq(assert(fresh:encode("png")),expected,"cached geometry matches a fresh frame")
            end
        end)
    end)
end
local run_cases=test.run_cases(define_tests)
return {run=function(options) return run_cases(options) end}
