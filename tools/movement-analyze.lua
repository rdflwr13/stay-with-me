local path = arg[1]
if path == nil then
    io.stderr:write("usage: luajit movement-analyze.lua <DebugLog.txt>\n")
    os.exit(2)
end

local function num(v)
    if v == nil then return nil end
    return tonumber(v)
end

local function bool(v)
    if v == nil then return nil end
    if v == "true" or v == "1" then return true end
    if v == "false" or v == "0" then return false end
    return nil
end

local function tokens(s)
    local t = {}
    for k, v in string.gmatch(s, "([%w_%.%-]+)=([^%s]+)") do t[k] = v end
    return t
end

local events = {}

local function add(ev, tick, f)
    f = f or {}
    f.ev = ev
    f.tick = tick
    events[#events + 1] = f
end

local fh = assert(io.open(path, "r"))
local lineNo = 0
local lastTick = 0
for line in fh:lines() do
    lineNo = lineNo + 1
    local payload = string.match(line, "%[BridgeLog%] (.*)$")
    if payload ~= nil then
        local f = tokens(payload)
        local tick = num(f.tick)
        if tick ~= nil then lastTick = tick else tick = lastTick end
        add(f.ev or "?", tick, f)
    else
        local r = string.match(line, "%[BridgeRoute%] (.*)$")
        local m = string.match(line, "%[BridgeMove%] (.*)$")
        if r ~= nil then
            local f = tokens(r)
            local tick = num(f.t) or num(f.tick)
            if tick ~= nil then lastTick = tick else tick = lastTick end
            if string.find(r, "^trace ", 1) then
                add("route.tick", tick, f)
            elseif string.find(r, "^stuck start ", 1) then
                f.phase = "start"
                add("route.stuck", tick, f)
            elseif string.find(r, "^stuck recover ", 1) then
                f.phase = "recover"
                f.ticks = num(string.match(r, "after (%d+) ticks"))
                add("route.stuck", tick, f)
            elseif string.find(r, "^stuck clear ", 1) then
                f.phase = "clear"
                f.ticks = num(string.match(r, "after (%d+) ticks"))
                add("route.stuck", tick, f)
            elseif string.find(r, "^stall result=", 1) then
                add("route.stall", tick, f)
            elseif string.find(r, "^follow kind=", 1) then
                local from, to = string.match(r, "kind=([^%s]+)->([^%s]+)")
                f.from, f.to = from, to
                add("route.follow", tick, f)
            elseif string.find(r, "^diag ", 1) then
                add("route.diag", tick, f)
            elseif string.find(r, "^walk tgt=", 1) then
                add("route.walk", tick, f)
            elseif string.find(r, "^path start ", 1) then
                f.phase = "start"
                add("move.path", tick, f)
            elseif string.find(r, "^openingWay run ", 1) then
                f.action = "run"
                add("route.opening", tick, f)
            elseif string.find(r, "^openingWay skip=", 1) then
                f.action = "skip"
                add("route.opening", tick, f)
            elseif string.find(r, "^opening route ", 1) then
                f.action = "route"
                add("route.opening", tick, f)
            elseif string.find(r, "^opening none ", 1) then
                f.action = "none"
                add("route.opening", tick, f)
            elseif string.find(r, "^opening loop ", 1) then
                f.action = "loop"
                f.key = string.match(r, "at ([^%s]+)")
                if f.key ~= nil then f.key = string.gsub(f.key, "[%.,]+$", "") end
                add("route.opening", tick, f)
            elseif string.find(r, "^opening stale ", 1) then
                f.action = "stale"
                add("route.opening", tick, f)
            elseif string.find(r, "^compat overwrite ", 1) then
                add("compat", tick, f)
            end
        elseif m ~= nil then
            local f = tokens(m)
            local tick = num(f.t) or num(f.tick)
            if tick ~= nil then lastTick = tick else tick = lastTick end
            if string.find(m, "^walkReach ", 1) then
                add("move.walkReach", tick, f)
            end
        end
    end
end
fh:close()

local findings = {}
local function flag(check, tick, detail)
    findings[#findings + 1] = { check = check, tick = tick, detail = detail }
end

do
    local prevTarget, prevSpot, prevOpening, prevSince = nil, nil, nil, nil
    for _, e in ipairs(events) do
        if e.ev == "route.tick" and e.since ~= nil then
            local switched = (prevTarget ~= nil and e.target ~= prevTarget)
                or (prevSpot ~= nil and e.spot ~= prevSpot)
                or (prevOpening ~= nil and e.opening ~= prevOpening)
            if switched and prevSince ~= nil and e.since == prevSince then
                flag("since-stale-on-switch", e.tick,
                    string.format("target=%s spot=%s opening=%s since=%s",
                        tostring(e.target), tostring(e.spot), tostring(e.opening), tostring(e.since)))
            end
            prevTarget, prevSpot, prevOpening, prevSince = e.target, e.spot, e.opening, e.since
        end
    end
end

do
    for _, e in ipairs(events) do
        local still = num(e.still)
        local pathing = bool(e.pathing)
        if pathing == nil then pathing = bool(e.path) end
        local steering = bool(e.steering)
        if steering == nil then steering = bool(e.steer) end
        local cross = bool(e.cross)
        local door = bool(e.door)
        if door == nil then door = bool(e.doorAct) end
        if still ~= nil and still >= 60 and pathing == true
                and steering == false and cross == false and door == false then
            flag("stalled-with-path", e.tick,
                string.format("still=%s pathing=%s steering=%s cross=%s door=%s",
                    tostring(still), tostring(pathing), tostring(steering), tostring(cross), tostring(door)))
        end
    end
end

do
    local lastCompat = nil
    for _, e in ipairs(events) do
        if e.ev == "compat" then
            lastCompat = e.tick
        elseif e.ev == "route.stall" and e.result == "stalled" then
            if lastCompat ~= nil and e.tick ~= nil and e.tick - lastCompat <= 600 then
                flag("progressat-overwrite-before-stall", e.tick,
                    string.format("compat_tick=%s stall_tick=%s", tostring(lastCompat), tostring(e.tick)))
            end
        end
    end
end

do
    local first = {}
    local seenLoop = {}
    for _, e in ipairs(events) do
        if e.ev == "route.opening" and e.action == "route" and e.key ~= nil then
            if first[e.key] == nil then first[e.key] = e.tick end
            if e.tick ~= nil and first[e.key] ~= nil and e.tick - first[e.key] > 360 then
                flag("opening-loop", e.tick,
                    string.format("key=%s age=%s", tostring(e.key), tostring(e.tick - first[e.key])))
            end
        elseif e.ev == "route.opening" and e.action == "loop" and e.key ~= nil then
            if not seenLoop[e.key] then
                seenLoop[e.key] = true
                flag("opening-loop", e.tick, "loop key=" .. tostring(e.key))
            end
        end
    end
end

do
    local prevTarget, prevFails = nil, nil
    for _, e in ipairs(events) do
        if e.ev == "route.tick" then
            local fails = num(e.pathFails)
            if fails ~= nil then
                if prevTarget ~= nil and e.target ~= prevTarget and prevFails ~= nil and fails > prevFails then
                    flag("pathfails-no-reset", e.tick,
                        string.format("target=%s->%s pathFails=%s->%s",
                            tostring(prevTarget), tostring(e.target), tostring(prevFails), tostring(fails)))
                end
                prevTarget, prevFails = e.target, fails
            end
        end
    end
end

do
    for _, e in ipairs(events) do
        if e.ev == "route.tick" and bool(e.cross) == true and bool(e.door) == true then
            flag("cross-door-conflict", e.tick, "cross=1 door=1")
        end
    end
end

do
    local run = 0
    for _, e in ipairs(events) do
        if e.ev == "route.tick" then
            local path = bool(e.path)
            local bstep = num(e.bstep)
            local rstep = num(e.rstep)
            if path == true and bstep ~= nil and rstep ~= nil and bstep == 0 and rstep == 0 then
                run = run + 1
                if run == 60 then
                    flag("path-true-no-bstep", e.tick, "run=60 bstep=0 rstep=0")
                end
            else
                run = 0
            end
        end
    end
end

do
    local prev = nil
    local run = 0
    for _, e in ipairs(events) do
        if e.ev == "route.tick" and bool(e.pathing) == true then
            local dg = num(e.dGoal)
            if dg ~= nil then
                if prev ~= nil and dg >= prev then
                    run = run + 1
                    if run == 60 then
                        flag("dgoal-not-decreasing", e.tick,
                            string.format("dGoal=%s run=60", tostring(dg)))
                    end
                else
                    run = 0
                end
                prev = dg
            end
        else
            prev = nil
            run = 0
        end
    end
end

print(string.format("movement-analyze: %d events, %d findings", #events, #findings))
local counts = {}
for _, f in ipairs(findings) do counts[f.check] = (counts[f.check] or 0) + 1 end
local names = {}
for k in pairs(counts) do names[#names + 1] = k end
table.sort(names)
for _, k in ipairs(names) do
    print(string.format("  %-38s %d", k, counts[k]))
end
local limit = #findings
if limit > 60 then limit = 60 end
for i = 1, limit do
    local f = findings[i]
    print(string.format("  [%s] tick=%s %s", f.check, tostring(f.tick), f.detail))
end
