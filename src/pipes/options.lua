-- One versioned per-user setting; unknown values fall back independently.
local options = {KEY = "display_pipes_v1"}
options.choices = {
    speed = {{value="slow",label="Slow"},{value="normal",label="Normal"},{value="fast",label="Fast"}},
    thickness = {{value="thin",label="Thin"},{value="normal",label="Normal"},{value="thick",label="Thick"}},
    palette = {{value="classic",label="Classic"},{value="chrome",label="Chrome"},{value="neon",label="Neon"}},
}
function options.valid(key: string, value: any): boolean
    for _, item in ipairs(options.choices[key] or {}) do if item.value == value then return true end end
    return false
end
function options.read(value: any): any
    if type(value) == "string" then
        local speed, thickness, palette = string.match(value, "^([^:]+):([^:]+):([^:]+)$")
        value = {speed=speed,thickness=thickness,palette=palette}
    end
    if type(value) ~= "table" then value = {} end
    return {speed=options.valid("speed",value.speed) and value.speed or "normal",
        thickness=options.valid("thickness",value.thickness) and value.thickness or "normal",
        palette=options.valid("palette",value.palette) and value.palette or "classic"}
end
function options.encode(value: any): string
    local clean = options.read(value)
    return clean.speed .. ":" .. clean.thickness .. ":" .. clean.palette
end
return options
