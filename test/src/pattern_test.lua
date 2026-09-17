-- The "Pattern" dialog: what it is told, what OK and Cancel do, the preview
-- drawn to its rectangle, the layout in cells and at two pixel cells, and
-- the shots of the dialog and of the Background page it belongs to.
local test = require("test")
local pattern = require("pattern")
local model = require("model")
local display = require("display")
local ui = require("ui")
local app = require("app")
local renderer = require("renderer")
local chrome = require("chrome")
local cells_chrome = require("cells_chrome")
local rasters = require("rasters")
local gfx = require("gfx")
local fs = require("fs")
local json = require("json")

local dialog = pattern.definition

local function opened(args: any): (any, any)
    local sent: any = {}
    local state = dialog.init(args, app.context({}))
    state.send = function(to: string, value: any)
        sent[#sent + 1] = {to = to, value = value}
        return true, nil
    end
    return state, sent
end

-- The client a window entry of `width`×`height` gets from the pixel theme,
-- or from the cell theme.
local function client(width: integer, height: integer, theme: any?): (integer, integer)
    local inset: any = (theme or chrome).window_insets({})
    return math.tointeger(width - inset.left - inset.right) or 1, math.tointeger(height - inset.top - inset.bottom) or 1
end

local function no_overlaps(plan: any, width: integer, height: integer, where: string)
    for index, item in ipairs(plan.items) do
        local r = item.rect
        test.is_true(r.x >= 1 and r.y >= 1 and r.x + r.w <= width + 1 and r.y + r.h <= height + 1,
            where .. ": " .. tostring(item.node.kind) .. " " .. tostring(item.node.id or item.node.text) .. " fits the client")
        for other = index + 1, #plan.items do
            local b = plan.items[other]
            if item.node.kind ~= "group" and b.node.kind ~= "group" and r.w > 0 and r.h > 0 and b.rect.w > 0 and b.rect.h > 0 then
                test.is_true(r.x + r.w <= b.rect.x or b.rect.x + b.rect.w <= r.x
                    or r.y + r.h <= b.rect.y or b.rect.y + b.rect.h <= r.y,
                    where .. ": overlap " .. tostring(item.node.id or item.node.kind) .. "/" .. tostring(b.node.id or b.node.kind))
            end
        end
    end
end

local function define_tests()
    test.describe("Pattern dialog", function()
        test.it("starts from what Display Properties passed, as a table or as JSON", function()
            local state = opened({pattern = "Bricks", color = "#000080", notify = "pid-1"})
            test.eq(state.pattern .. "/" .. state.color .. "/" .. tostring(state.notify), "Bricks/#000080/pid-1")
            local encoded = assert(json.encode({pattern = "Weave", color = "#008000", notify = "pid-2"}))
            state = opened(encoded)
            test.eq(state.pattern .. "/" .. state.color, "Weave/#008000")
            state = opened({pattern = "Nope", color = "teal"})
            test.eq(state.pattern .. "/" .. state.color, "(None)/#008080", "what nobody can draw falls back")
            test.is_nil(state.notify)
            state = opened("{not json")
            test.eq(state.pattern, "(None)")
        end)
        test.it("Display hands the dialog and the preview their arguments as strings", function()
            local spec = assert(display.pattern_spec("Bricks", "#000080", "pid-7"))
            test.eq(spec.entry, "chicago.display:pattern")
            test.eq(type(spec.args), "string", "the compositor drops a table")
            local state = opened(spec.args)
            test.eq(state.pattern .. "/" .. state.color .. "/" .. tostring(state.notify), "Bricks/#000080/pid-7",
                "the dialog reads what Display sent")
            local preview = display.preview_spec("fast:thick:chrome")
            test.eq(preview.args, "fast:thick:chrome", "the preview's settings are a string too")
            test.eq(display.preview_spec(nil).args, "normal:normal:classic")
        end)
        test.it("OK sends the choice to the opener and closes; Cancel only closes", function()
            local state, sent = opened({pattern = "(None)", notify = "pid-1"})
            local context = app.context({})
            dialog.update(state, {type = "select", id = "patterns", index = 3, value = {id = "Buttons", text = "Buttons"}}, context)
            test.eq(state.pattern, "Buttons")
            test.is_false(context.closing, "a selection does not close")
            test.eq(#sent, 0)
            test.eq(dialog.update(state, {type = "activate", id = "edit_pattern"}, context), false)
            dialog.update(state, {type = "activate", id = "ok"}, context)
            test.eq(#sent, 1)
            test.eq(sent[1].to .. "/" .. sent[1].value.pattern, "pid-1/Buttons")
            test.is_true(context.closing)
            test.eq(model.pattern_choice(sent[1].value), "Buttons", "Display reads what OK sends")
            test.eq(model.pattern_choice({sent[1].value}), "Buttons", "also wrapped in a list")
            test.is_nil(model.pattern_choice("Buttons"))

            state, sent = opened({pattern = "Bricks", notify = "pid-1"})
            context = app.context({})
            dialog.update(state, {type = "select", id = "patterns", index = 1, value = {id = "(None)"}}, context)
            dialog.update(state, {type = "activate", id = "cancel"}, context)
            test.eq(#sent, 0, "Cancel sends nothing")
            test.is_true(context.closing)

            state, sent = opened({pattern = "Bricks", notify = "pid-1"})
            context = app.context({})
            dialog.update(state, {type = "activate", id = "patterns", index = 5, value = {id = "Circuits"}}, context)
            test.eq(sent[1].value.pattern, "Circuits", "Enter on the list is OK")
            test.is_true(context.closing)
        end)
        test.it("paints the pattern at 1:1 inside a sunken edge", function()
            local rects: any = {}
            local recorder: any = {fill = function(_, color) rects[#rects + 1] = {fill = color} end,
                rect = function(_, x, y, w, h, color) rects[#rects + 1] = {x = x, y = y, w = w, h = h, color = color} end}
            -- Cargo Net's first row is 01111000: bits 1..4 set, from x = 3.
            pattern.paint({120, 49, 19, 135, 225, 200, 140, 30}, "#008080", 20, 12, recorder)
            test.eq(rects[1].fill, "#008080", "the desktop color under the bits")
            local first: any = nil
            for _, r in ipairs(rects) do
                if r.color == "#000000" and r.y == 3 and r.h == 1 and first == nil then first = r end
            end
            test.eq(first.x .. "+" .. first.w, "4+4", "01111000 is four pixels from the second")
            for _, r in ipairs(rects) do
                if r.color == "#000000" and r.h == 1 and r.y >= 3 and r.y <= 10 then
                    test.is_true(r.x >= 3 and r.x + r.w - 1 <= 18, "the bits stay inside the edge")
                end
            end
            local edges: any = {}
            for _, r in ipairs(rects) do if r.color then edges[r.color] = (edges[r.color] or 0) + 1 end end
            test.is_true((edges["#808080"] or 0) == 2 and (edges["#ffffff"] or 0) == 2 and (edges["#c0c0c0"] or 0) == 2,
                "the sunken edge's four colors")
            rects = {}
            pattern.paint(nil, "#000080", 20, 12, recorder)
            test.eq(#rects, 9, "no pattern: the color and the edge only")
        end)
        test.it("lays out in cells and at 8×16 and 10×20 and draws the preview to its rectangle", function()
            local files = assert(fs.get("chicago.shell.theme:fonts"))
            local fonts = {face = assert(gfx.font(assert(files:readfile("LiberationSans-Regular.ttf")), {size = 13, smooth = true}))}
            local cells_state = opened({pattern = "Cargo Net"})
            local ccols, crows = client(46, 13, cells_chrome)
            local cells_context = app.context({width = ccols, height = crows})
            local cells_tree = dialog.view(cells_state, cells_context)
            test.is_nil(ui.problem(cells_tree))
            test.is_nil(cells_state.png, "no PNG in cells")
            local cells_plan = ui.plan(cells_tree, ccols, crows, ui.interaction())
            no_overlaps(cells_plan, ccols, crows, "cells")
            test.is_true(cells_plan.by_id.patterns.rect.h >= 3, "cells: the list shows patterns")
            test.not_nil(cells_plan.by_id.edit_pattern, "cells: Edit Pattern… is laid out")
            for _, cell in ipairs({{8, 16}, {10, 20}}) do
                local cw, ch = cell[1], cell[2]
                local where = cw .. "x" .. ch
                chrome.use_cell_size(cw, ch)
                local cols, rows = client(46, 13)
                local state = opened({pattern = "Cargo Net", color = "#008080"})
                local context = app.context({width = cols, height = rows, native = true, cell_w = cw, cell_h = ch})
                local tree = dialog.view(state, context)
                test.is_nil(ui.problem(tree))
                local plan = ui.plan(tree, cols, rows, context.interaction, {cell = {w = cw, h = ch}, scroll_cols = context.scroll_cols})
                no_overlaps(plan, cols, rows, where)
                local list, preview, ok = plan.by_id.patterns, plan.by_id.preview, plan.by_id.ok
                test.is_true(preview.rect.x > list.rect.x + list.rect.w - 1, where .. ": the preview right of the list")
                test.eq(preview.rect.y, list.rect.y, where .. ": level with the list")
                test.is_true(ok.rect.x > preview.rect.x + preview.rect.w - 1, where .. ": the buttons right of the preview")
                test.eq(ok.px and ok.px.w, 90, where .. ": OK is 90 px")
                test.eq(plan.by_id.edit_pattern.px.w, 90, where .. ": Edit Pattern… is as wide")
                test.is_true(plan.by_id.edit_pattern.rect.y + plan.by_id.edit_pattern.rect.h <= rows + 1, where .. ": Edit Pattern… fits")
                test.is_true(list.rect.h >= 4 and list.rect.h <= 7, where .. ": the list shows about five patterns, got " .. list.rect.h)
                test.is_true(plan.by_id.edit_pattern.node.disabled == true, where .. ": Edit Pattern… is disabled")
                test.not_nil(state.png, where .. ": the preview is drawn")
                local picture = assert(gfx.image(assert(require("base64").decode(state.png))))
                local pw, ph = picture:size()
                test.eq(pw .. "x" .. ph, (preview.rect.w * cw) .. "x" .. (preview.rect.h * ch), where .. ": exactly its rectangle")
                local drawn = state.png
                dialog.view(state, context)
                test.is_true(state.png == drawn, where .. ": an unchanged preview is not drawn again")
                dialog.update(state, {type = "select", id = "patterns", index = 2, value = {id = "Bricks"}}, context)
                tree = dialog.view(state, context)
                test.is_true(state.png ~= drawn, where .. ": a new pattern is a new preview")
                dialog.update(state, {type = "select", id = "patterns", index = 4, value = {id = "Cargo Net"}}, context)
                tree = dialog.view(state, context)
                local store = rasters.store(); store.begin()
                local image = assert(renderer.placement({id = "pattern", state_revision = 1, content_state = {sdk = 1, revision = 1, ui = tree,
                    interaction = context.interaction}}, {x = 1, y = 1, cols = cols, rows = rows}, {w = cw, h = ch}, fonts, store))
                assert(assert(fs.get("app:shots")):writefile("pattern_" .. tostring(cw) .. ".png", assert(image.raster:encode("png"))))

                -- The Background page the dialog belongs to.
                local width, height = client(54, 28)
                local page_context = app.context({width = width, height = height, native = true, cell_w = cw, cell_h = ch})
                local page_state: any = {tab = 1, chosen = "#008080", saved = "#008080", pattern = "Cargo Net", pattern_saved = "(None)",
                    wallpaper = "Sky", wallpaper_saved = "Sky", mode = "center", mode_saved = "center", info = {}}
                local page = display.definition.view(page_state, page_context)
                test.is_nil(ui.problem(page))
                local shot = assert(renderer.placement({id = "display", state_revision = 1, content_state = {sdk = 1, revision = 1, ui = page,
                    interaction = page_context.interaction}}, {x = 1, y = 1, cols = width, rows = height}, {w = cw, h = ch}, fonts, store))
                assert(assert(fs.get("app:shots")):writefile("background_" .. tostring(cw) .. ".png", assert(shot.raster:encode("png"))))
            end
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return {run = function(options) return run_cases(options) end}
