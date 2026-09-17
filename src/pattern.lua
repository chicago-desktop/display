-- "Pattern", the dialog "Pattern…" opens on "Display Properties →
-- Background", as in the original: the hint on top, the "Pattern:" list and
-- the "Preview:" box under it, OK, Cancel and "Edit Pattern…" on the right.
--
-- The dialog writes nothing. It is told the pending pattern and color and the
-- pid of the window that opened it (`args`); OK sends the choice back on
-- `model.PATTERN_TOPIC`, and Display Properties takes it as its pending
-- pattern — "Apply" there writes it, as in the original. "Edit Pattern…"
-- stays disabled: the patterns are the shell's fixed list.
--
-- The preview is the pattern over the desktop color at 1:1 inside a sunken
-- edge. It is a PNG drawn here to the exact pixel size of its rectangle,
-- which the window plans itself with the same numbers the renderer uses: an
-- SDK pane would keep its children a whole cell off the edge.
local app = require("app")
local ui = require("ui")
local json = require("json")
local gfx = require("gfx")
local base64 = require("base64")
local patterns = require("patterns")
local model = require("model")
local geometry = require("geometry")
local whole = geometry.whole

local pattern = {}

pattern.HINT = "You can choose a pattern for your desktop. The pattern is used to fill any leftover space around your wallpaper."

local definition: any = {close_on_escape = true}

-- decode(args) -> the table Display Properties passed: as given, or from its
-- JSON form.
local function decode(args: any): any
    if type(args) == "string" then
        local value, err = json.decode(args)
        if err == nil and type(value) == "table" then return value end
        return {}
    end
    return type(args) == "table" and args or {}
end

function definition.init(args: any, context: any): any
    local given: any = decode(args)
    local chosen = type(given.pattern) == "string" and patterns.find(given.pattern) ~= nil and given.pattern or patterns.NONE
    return {pattern = chosen, color = model.valid(given.color) and given.color or model.DEFAULT,
        notify = given.notify ~= nil and tostring(given.notify) or nil,
        -- The send is a field: the test substitutes its own.
        send = function(to: string, value: any): (any, any)
            return process.send(to, model.PATTERN_TOPIC, value)
        end}
end

-- paint(rows, color, w, h) -> a w×h raster: the classic sunken edge (dark
-- gray and white outside, black and face inside) around the pattern's bits,
-- black over `color`, anchored at the inner corner as the desktop's are.
-- `into` is a raster to draw on instead of a new one (the test's recorder).
function pattern.paint(rows: any, color: string, w: integer, h: integer, into: any?): any
    local raster: any = into or gfx.raster(w, h)
    raster:fill(color)
    if type(rows) == "table" and #rows == 8 then
        -- Runs of set bits per row, from the inner corner (3, 3) to the
        -- inner edge (w - 2, h - 2); x = w - 1 closes the last run.
        for y = 3, h - 2 do
            local byte = whole(rows[(y - 3) % 8 + 1])
            local run = 0
            for x = 3, w - 1 do
                if x <= w - 2 and ((byte >> (7 - (x - 3) % 8)) & 1) == 1 then
                    run = run + 1
                elseif run > 0 then
                    raster:rect(x - run, y, run, 1, "#000000")
                    run = 0
                end
            end
        end
    end
    raster:rect(1, 1, w, 1, "#808080")
    raster:rect(1, 1, 1, h, "#808080")
    raster:rect(1, h, w, 1, "#ffffff")
    raster:rect(w, 1, 1, h, "#ffffff")
    raster:rect(2, 2, w - 2, 1, "#000000")
    raster:rect(2, 2, 1, h - 2, "#000000")
    raster:rect(2, h - 1, w - 2, 1, "#c0c0c0")
    raster:rect(w - 1, 2, 1, h - 2, "#c0c0c0")
    return raster
end

-- The buttons are one width, as the original's: the width "Edit Pattern…"
-- needs in the shell's font.
local function tree(state: any): any
    local function button(id: string, text: string, extra: any): any
        local node: any = {kind = "button", id = id, text = text, size = 10, size_px = 96, width_px = 90}
        for key, value in pairs(extra or {}) do node[key] = value end
        return {kind = "row", size = 2, size_px = 30, align = "right", children = {node}}
    end
    return {kind = "row", padding = 1, padding_bottom = 0, padding_px = 7, gap = 1, gap_px = 11, children = {
        {kind = "column", gap = 0, children = {
            {kind = "label", size = 3, size_px = 50, text = pattern.HINT, wrap = true},
            {kind = "row", size = 1, size_px = 20, gap = 1, gap_px = 11, children = {
                {kind = "label", text = "Pattern:"},
                {kind = "label", size = 10, size_px = 72, text = "Preview:"},
            }},
            {kind = "row", gap = 1, gap_px = 11, children = {
                {kind = "list", id = "patterns", items = patterns.items(), selected = state.pattern},
                {kind = "picture", id = "preview", size = 10, size_px = 72, png = state.png,
                    text = state.pattern},
            }},
        }},
        {kind = "column", size = 10, size_px = 96, gap = 0, children = {
            button("ok", "OK", {default = true}),
            button("cancel", "Cancel"),
            {kind = "label", size = 1, size_px = 20, text = ""},
            button("edit_pattern", "Edit Pattern…", {disabled = true}),
        }},
    }}
end

-- preview(state, context) — the preview's PNG for the rectangle the plan
-- gives it; drawn again only when the pattern, the color or the size change.
local function preview(state: any, context: any)
    local cell: any = context.cell
    if not context.native or type(cell) ~= "table" then return end
    local plan = ui.plan(tree(state), context.width, context.height, ui.interaction(),
        {cell = cell, scroll_cols = context.scroll_cols})
    local item: any = plan.by_id.preview
    if not item then return end
    local w, h = whole(item.rect.w * cell.w), whole(item.rect.h * cell.h)
    if w < 6 or h < 6 then
        state.png = nil
        return
    end
    local key = state.pattern .. "|" .. state.color .. "|" .. w .. "x" .. h
    if state.png_key == key then return end
    local raster: any = pattern.paint(patterns.find(state.pattern), tostring(state.color), w, h)
    local bytes: any = assert(raster:encode("png"))
    state.png = base64.encode(tostring(bytes))
    state.png_key = key
end

function definition.view(state: any, context: any): any
    preview(state, context)
    return tree(state)
end

function definition.update(state: any, action: any, context: any)
    if action.id == "patterns" and (action.type == "select" or action.type == "activate") then
        local item: any = action.value
        if type(item) == "table" then
            state.pattern = patterns.find(item.id) ~= nil and item.id or patterns.NONE
        end
        -- Enter on the list is OK, as in the original.
        if action.type ~= "activate" then return end
    elseif action.id == "cancel" and action.type == "activate" then
        context.close()
        return
    elseif not (action.id == "ok" and action.type == "activate") then
        return false
    end
    -- OK: tell the window that opened the dialog, then go. A window that is
    -- gone does not care.
    if state.notify ~= nil then state.send(state.notify, {pattern = state.pattern}) end
    context.close()
end

pattern.definition = definition
pattern.main = app.main(definition)
return pattern
