-- "Display Properties", like Display Properties in the original: four tabs,
-- Background, Screen Saver, Appearance and Settings.
--
-- The classic dialog, measured on a screenshot of the real one (the
-- Settings tab, 404×448 px with its frame and title bar):
--   * the dialog's margins are 7 px; the tabs are 18 px tall, the active one
--     2 px taller; the page frame is 386×360 px;
--   * the preview monitor is 184 px wide, centred, 10 px under the page top;
--   * the groups stand 15 px inside the page frame and 11 px apart;
--   * OK, Cancel and Apply are 75×23 px, 6 px apart, their right edge on the
--     page frame's right edge, 6 px under the page and 8 px above the
--     dialog's bottom edge.
-- The tree names these numbers in pixels (`size_px`, `padding_px`, `gap_px`,
-- `width_px`). The SDK rounds them to whole cells — the mouse speaks cells —
-- and draws the buttons at their classic size inside their cells. The cell
-- numbers (`size`, `padding`, `gap`) are the same tree in character mode.
--
-- "Background" is the wallpaper, as the original's: a list of the shell's
-- pictures (`chicago.shell.display:wallpapers`) and how to show one. The
-- pattern — the classic 8×8 tiles (`chicago.shell.display:patterns`), tiled
-- by the pixel theme over the desktop color — is chosen in the "Pattern"
-- dialog (`chicago.display:pattern`), which sends the choice back to this
-- window. "Appearance" holds the desktop color, where the original kept it: the
-- color of the Desktop item. "Screen Saver" offers the manual 3D Pipes preview.
-- "Apply" and "OK" write the choice into the shell settings and ask the
-- compositor to reread the desktop (`desktop.refresh`), which repaints the
-- desktop and icons in both modes.
--
-- "Settings" is resolution and palette, read-only: the compositor knows the
-- screen and cell size (`desktop.list`), the runtime forces the palette.
local app = require("app")
local desktop = require("desktop")
local repo = require("repo")
local model = require("model")
local patterns = require("patterns")
local wallpapers = require("wallpapers")
local geometry = require("geometry")
local options = require("options")
local whole = geometry.whole

local definition: any = {}

local function screen_info(): any
    local answer, err = desktop.list({timeout = "300ms"})
    if type(answer) ~= "table" then return {failure = err and tostring(err) or nil} end
    return {screen = answer.screen, cell = answer.cell, pixels = answer.pixels == true}
end

-- A stored pattern name, or "(None)" for one nobody can draw.
local function pattern_of(stored: any): string
    if type(stored) == "string" and patterns.find(stored) ~= nil then return stored end
    return patterns.NONE
end

-- A stored wallpaper name, or "(None)"; the picture's file of a name, or nil.
local function wallpaper_of(stored: any): string
    if type(stored) == "string" and wallpapers.find(stored) ~= nil then return stored end
    return wallpapers.NONE
end
local function wallpaper_file(name: any): any
    local entry: any = wallpapers.find(name)
    return entry and entry.file or nil
end

function definition.init(args: any, context: any): any
    -- The logged-on person's settings: another person's desktop keeps its own.
    local store: any = repo.of(repo.person())
    local stored, err = store.setting("desktop_color")
    local chosen = model.valid(stored) and stored or model.DEFAULT
    local stored_pattern, perr = store.setting("desktop_pattern")
    local pattern = pattern_of(stored_pattern)
    local stored_wallpaper, werr = store.setting("desktop_wallpaper")
    local stored_mode, merr = store.setting("wallpaper_mode")
    local wallpaper = wallpaper_of(stored_wallpaper)
    local entry: any = wallpapers.find(wallpaper)
    local mode = (stored_mode == "tile" or stored_mode == "center") and stored_mode or (entry and entry.mode or "center")
    local failure = err or perr or werr or merr
    -- The Pattern dialog answers on its topic; the loop hands the message to
    -- `update` as a `channel` action.
    local answers = process.listen(model.PATTERN_TOPIC)
    if answers then context.watch(answers) end
    return {tab = 1, chosen = chosen, saved = chosen, pattern = pattern, pattern_saved = pattern,
        wallpaper = wallpaper, wallpaper_saved = wallpaper, mode = mode, mode_saved = mode,
        info = screen_info(),
        saver = "pipes",
        preview = function()
            local saved, read_err = store.setting(options.KEY)
            if read_err then return nil, tostring(read_err) end
            return desktop.open({entry = "chicago.display.pipes:window", title = "3D Pipes - Preview", args = options.read(saved)})
        end,
        saver_settings = function() return desktop.dialog({entry = "chicago.display.pipes:settings"}) end,
        -- "Pattern…": the dialog is told the pending pattern and color and
        -- where to send the choice.
        pattern_dialog = function(pending: any, color: any)
            return desktop.dialog({entry = model.PATTERN_ENTRY,
                args = {pattern = pending, color = color, notify = tostring(process.pid())}})
        end,
        failure = failure and ("settings not read: " .. tostring(failure)) or nil,
        -- The write and the request to the compositor are moved into a
        -- field: the test substitutes its own and checks that "Apply" calls
        -- them, without a database. `changes` names only what changed.
        persist = function(changes: any)
            for _, key in ipairs({"desktop_color", "desktop_pattern", "desktop_wallpaper", "wallpaper_mode"}) do
                if changes[key] ~= nil then
                    local _, werr = store.set_setting(key, changes[key])
                    if werr then return nil, tostring(werr) end
                end
            end
            local _, rerr = desktop.request("desktop.refresh", {})
            if rerr then return nil, "desktop not refreshed: " .. tostring(rerr) end
            return true, nil
        end}
end

local function changed(state: any): boolean
    return state.chosen ~= state.saved or state.pattern ~= state.pattern_saved
        or state.wallpaper ~= state.wallpaper_saved or state.mode ~= state.mode_saved
end

-- The preview monitor: the desktop as it will be, pattern and wallpaper
-- included. Four rows in cells, where the page is short.
local function monitor(color: any, pattern: any, wallpaper: any, mode: any): any
    return {kind = "monitor", size = 4, size_px = 150, color = color, pattern = patterns.find(pattern),
        wallpaper = wallpaper_file(wallpaper), wallpaper_mode = mode}
end

-- The Wallpaper list: a picture before every name, as the original's; the
-- "(None)" row has a blank one, so its caption stands in line with the rest.
local PICTURE, BLANK = "chicago.display:images/picture", "chicago.display:images/blank"
local function wallpaper_rows(): any
    local rows: any = {}
    for _, item in ipairs(wallpapers.items()) do
        local none = item.id == wallpapers.NONE
        rows[#rows + 1] = {id = item.id, cells = {{text = item.text, image = none and BLANK or PICTURE,
            icon = none and " " or "▪"}}}
    end
    return rows
end

-- A button of the Wallpaper group's right column: 75×23 px at the column's
-- right edge, the column as wide as a dialog button's cells.
local function side_button(id: string, text: string, extra: any): any
    local node: any = {kind = "button", id = id, text = text, size = 10, size_px = 81, width_px = 75}
    for key, value in pairs(extra or {}) do node[key] = value end
    return {kind = "row", size = 2, size_px = 30, align = "right", children = {node}}
end

-- Background, as the original's (the Windows 95 Plus!/IE4 dialog): the
-- monitor, and under it one Wallpaper group — the caption, the list of
-- pictures on the left; "Browse…", "Pattern…" and the "Display:" drop-down
-- on the right. The pattern has its own dialog ("Pattern…"). "Browse…"
-- waits for a file dialog; the drop-down is disabled without a wallpaper.
local function background(state: any): any
    local none = state.wallpaper == wallpapers.NONE
    local page: any = {kind = "column", gap = 0, children = {
        {kind = "monitor", color = state.chosen, pattern = patterns.find(state.pattern),
            wallpaper = wallpaper_file(state.wallpaper), wallpaper_mode = state.mode},
        -- Nine rows in both modes: the caption and the right column — two
        -- buttons of two rows, "Display:" and the drop-down of one.
        {kind = "group", title = "Wallpaper", size = 9, children = {
            {kind = "label", size = 1, size_px = 20, text = "Select a picture:"},
            {kind = "row", gap = 1, gap_px = 11, children = {
                {kind = "table", id = "wallpapers", header = false, columns = {{title = "Name", weight = 1}},
                    rows = wallpaper_rows(), selected = state.wallpaper},
                {kind = "column", size = 10, size_px = 81, gap = 0, children = {
                    side_button("browse", "Browse…", {disabled = true}),
                    side_button("pattern", "Pattern…"),
                    {kind = "label", size = 1, size_px = 20, text = "Display:"},
                    {kind = "select", id = "mode", size = 1, size_px = 22, value = state.mode,
                        options = model.WALLPAPER_MODES, disabled = none},
                }},
            }},
        }},
    }}
    -- A failure to read or write the settings: under the group, in red.
    if state.failure then page.children[#page.children + 1] = {kind = "label", size = 1, text = state.failure, alert = true} end
    return page
end

local function screen_saver(state: any): any
    return {kind = "column", gap = 0, children = {
        -- A static monitor, as on the other pages. Animation belongs to Preview.
        {kind = "monitor", color = "#000000"},
        {kind = "group", title = "Screen saver", size = 7, size_px = 140, children = {
            {kind = "row", size = 2, size_px = 30, gap = 1, gap_px = 6, children = {
                {kind = "select", id = "saver", value = state.saver or "pipes",
                    options = {{value = "pipes", label = "3D Pipes"}}},
                {kind = "button", id = "saver_settings", size = 10, size_px = 81, width_px = 75, text = "Settings…"},
                {kind = "button", id = "preview", size = 10, size_px = 81, width_px = 75, text = "Preview"},
            }},
            {kind = "row", size = 1, size_px = 22, gap = 1, gap_px = 6, children = {
                {kind = "label", size = 5, size_px = 38, text = "Wait:", disabled = true},
                {kind = "input", id = "wait", size = 5, size_px = 46, text = "10", disabled = true},
                {kind = "label", text = "minutes", disabled = true},
            }},
            {kind = "checkbox", id = "resume", size = 1, size_px = 22,
                text = "On resume, display Welcome screen", checked = false, disabled = true},
            {kind = "label", size = 1, size_px = 20, text = state.failure or "Automatic start is not available.",
                alert = state.failure ~= nil},
        }},
        {kind = "group", title = "Monitor power", size = 5, size_px = 90, children = {
            {kind = "label", size = 2, size_px = 36, text = "Power saving is managed by your computer's operating system.", wrap = true},
            {kind = "row", size = 2, size_px = 30, align = "right", children = {
                {kind = "button", id = "power", size = 10, size_px = 81, width_px = 75, text = "Power…", disabled = true},
            }},
        }},
    }}
end

-- Appearance: the desktop color is the one live item — the original kept it
-- here, as the color of the Desktop.
local function appearance(state: any): any
    return {kind = "column", gap = 0, children = {
        monitor(state.chosen, state.pattern, state.wallpaper, state.mode),
        {kind = "row", size = 2, size_px = 26, gap = 1, children = {
            {kind = "label", size = 7, size_px = 60, text = "Item:"},
            {kind = "select", id = "item", value = "desktop", options = {{value = "desktop", label = "Desktop"}}, disabled = true},
        }},
        {kind = "row", gap = 1, children = {
            {kind = "label", size = 7, size_px = 60, text = "Color:"},
            {kind = "list", id = "colors", items = model.color_items(state.chosen), selected = state.chosen},
        }},
    }}
end

-- Settings, as the classic tab: the monitor, then "Color palette" (the
-- palette in a drop-down list, read-only — the runtime forces TrueColor — and
-- the spectrum under it), "Desktop area" (a Less–More slider, disabled — the
-- terminal sets the size — and the resolution in the original's words under it),
-- a disabled "Font size" and a disabled "Change Display Type…".
local function settings(state: any): any
    local info: any = state.info or {}
    local area: any = {kind = "label", size = 1, size_px = 20, text = model.resolution(info.screen, info.cell), align = "center"}
    if info.failure then
        area = {kind = "label", size = 1, size_px = 20, text = "the compositor did not answer: " .. tostring(info.failure), alert = true}
    end
    return {kind = "column", gap = 0, children = {
        -- The monitor takes what the groups leave: the page is short at 16 px rows.
        {kind = "monitor", color = state.saved, pattern = patterns.find(state.pattern_saved),
            wallpaper = wallpaper_file(state.wallpaper_saved), wallpaper_mode = state.mode_saved},
        {kind = "row", size = 4, size_px = 70, gap = 1, gap_px = 11, children = {
            {kind = "group", title = "Color palette", children = {
                {kind = "select", id = "palette", size = 1, size_px = 21, value = "truecolor",
                    options = {{value = "truecolor", label = model.palette()}}, disabled = true},
                {kind = "spectrum", size = 1, size_px = 15},
            }},
            {kind = "group", title = "Desktop area", children = {
                {kind = "row", size = 1, size_px = 21, gap = 1, children = {
                    {kind = "label", size = 4, size_px = 36, text = "Less"},
                    {kind = "slider", id = "area", value = 0, min = 0, max = 4, disabled = true},
                    {kind = "label", size = 4, size_px = 36, text = "More"},
                }},
                area,
            }},
        }},
        {kind = "group", size = 3, size_px = 50, title = "Font size", disabled = true, children = {
            {kind = "row", size = 1, size_px = 21, gap = 2, gap_px = 12, children = {
                {kind = "select", id = "fonts", value = "small", options = {{value = "small", label = "Small Fonts"}}, disabled = true},
                {kind = "button", id = "custom", size = 10, size_px = 81, text = "Custom…", disabled = true},
            }},
        }},
        {kind = "row", size = 2, size_px = 30, align = "right", children = {
            {kind = "button", id = "display_type", size = 22, size_px = 179, width_px = 173,
                text = "Change Display Type…", disabled = true},
        }},
    }}
end

local PAGES: any = {background, screen_saver, appearance, settings}

function definition.view(state: any, context: any): any
    -- In cells a caption is a cell per character: four tabs of the original
    -- need 48 cells, and the page has 42. So the tabs there take one cell of
    -- air instead of two, and "Screen Saver" is "Saver" — the one place this
    -- window asks which backend draws it.
    local native = type(context) == "table" and context.native == true
    local labels = {}
    for index, tab in ipairs(model.TABS) do
        labels[index] = (not native and tab.short) or tab.text
    end
    local page: any = (PAGES[whole(state.tab)] or background)(state)
    local button: any = {size = 10, size_px = 81, width_px = 75}
    local function push(id: string, text: string, extra: any): any
        local node: any = {kind = "button", id = id, text = text, size = button.size, size_px = button.size_px,
            width_px = button.width_px}
        for key, value in pairs(extra or {}) do node[key] = value end
        return node
    end
    -- In cells the sunken client already has its own edge, and the four tab
    -- captions need every column of it: no side padding there. In pixels
    -- `padding_px` stands for all four sides.
    return {kind = "column", padding = 1, padding_left = 0, padding_right = 0, padding_bottom = 0, padding_px = 7, gap = 0, children = {
        {kind = "tabs", id = "pages", labels = labels, active = state.tab, padding = 1, padding_px = 0, pad = 1, children = {page}},
        {kind = "row", size = 2, size_px = 30, gap = 1, gap_px = 0, align = "right", children = {
            push("ok", "OK", {default = true}),
            push("cancel", "Cancel"),
            push("apply", "Apply", {disabled = not changed(state)}),
        }},
    }}
end

local function apply(state: any): boolean
    if not changed(state) then return true end
    local settings_changed: any = {}
    if state.chosen ~= state.saved then settings_changed.desktop_color = state.chosen end
    if state.pattern ~= state.pattern_saved then settings_changed.desktop_pattern = state.pattern end
    if state.wallpaper ~= state.wallpaper_saved then settings_changed.desktop_wallpaper = state.wallpaper end
    if state.mode ~= state.mode_saved then settings_changed.wallpaper_mode = state.mode end
    local ok, err = state.persist(settings_changed)
    if not ok then
        state.failure = tostring(err)
        return false
    end
    state.saved, state.pattern_saved = state.chosen, state.pattern
    state.wallpaper_saved, state.mode_saved = state.wallpaper, state.mode
    state.failure = nil
    return true
end

function definition.update(state: any, action: any, context: any)
    if action.id == "saver_settings" and action.type == "activate" then
        local ok, err = state.saver_settings()
        state.failure = not ok and tostring(err or "Settings could not be opened.") or nil
    elseif action.id == "preview" and action.type == "activate" then
        local ok, err = state.preview()
        state.failure = not ok and tostring(err or "The preview could not be opened.") or nil
    elseif action.id == "pages" and action.type == "select" then state.tab = whole(action.index)
    elseif action.id == "colors" and (action.type == "select" or action.type == "activate") then
        local item: any = action.value
        if type(item) == "table" and model.valid(item.id) then state.chosen = item.id end
    elseif action.id == "wallpapers" and (action.type == "select" or action.type == "activate") then
        -- A wallpaper comes with the way it is meant to be shown; the radio
        -- buttons change it afterwards.
        local item: any = action.value
        if type(item) == "table" then
            state.wallpaper = wallpaper_of(item.id)
            local entry: any = wallpapers.find(state.wallpaper)
            if entry then state.mode = entry.mode end
        end
    elseif action.id == "mode" and action.type == "change" then
        if action.value == "tile" or action.value == "center" then state.mode = action.value end
    elseif action.id == "pattern" and action.type == "activate" then
        local ok, err = state.pattern_dialog(state.pattern, state.chosen)
        state.failure = not ok and tostring(err or "The Pattern dialog could not be opened.") or nil
    elseif action.type == "channel" then
        -- The Pattern dialog's OK: the pending pattern, written by Apply.
        local name = model.pattern_choice(action.value)
        if name == nil then return false end
        state.pattern = pattern_of(name)
    elseif action.id == "apply" then apply(state)
    elseif action.id == "ok" then
        if apply(state) then context.close() end
    elseif action.id == "cancel" then context.close()
    else return false end
end

-- Esc closes the window: the loop does it for an Esc `update` did not take.
definition.close_on_escape = true

return {main = app.main(definition), definition = definition}
