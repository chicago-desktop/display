-- Bounded, deterministic lattice walks. All state belongs to one preview.
local pipes = {}
pipes.LIMIT = 360
local DIRECTIONS = {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
local function random(state: any, n: integer): integer
    state.seed = (state.seed * 48271) % 2147483647
    return math.floor(state.seed % n) + 1
end
local function key(point: any): string
    return table.concat(point, ",")
end
function pipes.new(seed: integer): any
    local state: any = {seed = math.max(1, seed % 2147483647), segments = {}, heads = {}, occupied = {}, frame = 0, hold = 0}
    for i = 1, 8 do
        local p = {i*2-9, random(state, 11)-6, random(state, 17)-9}
        state.heads[i] = {point = p, color = (i-1)%5+1, count = 0, pipe = i}
        state.occupied[key(p)] = true
    end
    return state
end
function pipes.step(state: any): any
    state.frame = state.frame + 1
    local unfinished = false
    for _, segment in ipairs(state.segments) do
        if segment.progress < 1 then segment.progress = math.min(1, segment.progress + 0.25); unfinished = true end
    end
    if unfinished then return state end
    local added = false
    if #state.segments < pipes.LIMIT then
        for _, head in ipairs(state.heads) do
            local choices = {}
            for _, direction in ipairs(DIRECTIONS) do
                local p = {head.point[1]+direction[1], head.point[2]+direction[2], head.point[3]+direction[3]}
                if math.abs(p[1]) <= 9 and math.abs(p[2]) <= 6 and math.abs(p[3]) <= 9 and not state.occupied[key(p)] then
                    choices[#choices+1] = p
                    if head.direction and direction[1] == head.direction[1] and direction[2] == head.direction[2]
                        and direction[3] == head.direction[3] then
                        for weight=1,3 do choices[#choices+1]=p end
                    end
                end
            end
            if #choices > 0 and #state.segments < pipes.LIMIT then
                local next_point = choices[random(state, #choices)]
                state.segments[#state.segments+1] = {a = head.point, b = next_point, color = head.color, pipe = head.pipe, progress = 0.25}
                head.direction = {next_point[1]-head.point[1],next_point[2]-head.point[2],next_point[3]-head.point[3]}
                head.point, head.count = next_point, head.count + 1
                state.occupied[key(next_point)], added = true, true
            end
        end
    end
    if not added then
        state.hold = state.hold + 1
        if state.hold >= 25 then return pipes.new(random(state, 2147483646)) end
    end
    return state
end
return pipes
