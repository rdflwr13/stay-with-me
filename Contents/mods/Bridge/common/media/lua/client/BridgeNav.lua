BridgeNav = BridgeNav or {}

local function resolve(v)
    if type(v) == "function" then return v() end
    return v
end

local function doorBlocker(sq)
    local reason = nil
    if sq == nil then return nil end
    pcall(function()
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            if o ~= nil then
                local door = false
                pcall(function()
                    door = instanceof(o, "IsoDoor")
                        or (instanceof(o, "IsoThumpable") and o:isDoor())
                end)
                if door then
                    local bar, lock = false, false
                    pcall(function() bar = o:isBarricaded() end)
                    pcall(function() lock = o:isLocked() or o:isLockedByKey() end)
                    if bar then reason = "barricade" return end
                    if lock then reason = "locked" end
                end
            end
        end
    end)
    return reason
end

function BridgeNav.blockedReason(target)
    local ob = ""
    pcall(function() ob = tostring(BridgeMove ~= nil and BridgeMove.obstacle or "") end)
    if string.find(ob, "barricad", 1, true) ~= nil then return "barricade" end
    if string.find(ob, "locked", 1, true) ~= nil then return "locked" end
    local reason = nil
    pcall(function()
        local body = Bridge.body
        if body ~= nil then reason = doorBlocker(body:getCurrentSquare()) end
        if reason == nil and target ~= nil then
            local sq = getCell():getGridSquare(target.x, target.y, target.z)
            reason = doorBlocker(sq)
        end
    end)
    return reason
end

function BridgeNav.newState()
    return { checkX = nil, checkY = nil, still = 0, bestD = nil, progressAt = nil,
        pathFails = 0, pathFailTick = nil,
        openingKey = nil, openingSince = nil, openingRef = nil, openingTries = nil,
        detour = nil, detourSide = nil, reason = nil, status = "ok" }
end

function BridgeNav.opening(state, opts)
    opts = opts or {}
    local way = BridgeMove ~= nil and BridgeMove.openingWay or nil
    if way == nil then return "ok" end
    if state.openingKey ~= way.key then
        state.openingKey = way.key
        state.openingSince = Bridge.time
    elseif state.openingSince ~= nil
            and Bridge.time - state.openingSince > (opts.giveUp or 360) then
        state.openingRef, state.openingKey, state.openingTries = nil, nil, nil
        state.openingSince = nil
        state.reason = BridgeNav.blockedReason(opts.target)
        return "stale", state.reason
    end
    return "ok"
end

function BridgeNav.notePathFail(state, opts)
    opts = opts or {}
    local failed = false
    pcall(function()
        failed = BridgeMove ~= nil and not BridgeMove.pathing
            and BridgeMove.pathResult == tostring(BehaviorResult.Failed)
    end)
    if not failed then return "ok" end
    if state.pathFailTick ~= Bridge.tick then
        state.pathFails = (state.pathFails or 0) + 1
    end
    state.pathFailTick = Bridge.tick
    pcall(function() BridgeMove.pathResult = "none" end)
    if (state.pathFails or 0) >= (opts.limit or 2) then
        return "failed"
    end
    return "ok"
end

function BridgeNav.progress(state, opts)
    opts = opts or {}
    local since = state.progressAt or state.since or Bridge.time
    if (Bridge.time - since) > (opts.noProgress or 300)
            or (Bridge.time - (state.since or Bridge.time)) > (opts.timeout or 1200) then
        if resolve(opts.onSpot) then
            state.progressAt = Bridge.time
            state.since = Bridge.time
            return "waiting"
        end
        return "timeout"
    end
    return "ok"
end

function BridgeNav.stall(body, state, opts)
    opts = opts or {}
    if state.checkX == nil then state.checkX, state.checkY = body:getX(), body:getY() end
    state.still = (state.still or 0) + 1
    if state.still < (opts.ticks or 90) then return "ok" end
    local moved = math.abs(body:getX() - state.checkX) + math.abs(body:getY() - state.checkY)
        > (opts.move or 0.3)
    state.still = 0
    state.checkX, state.checkY = body:getX(), body:getY()
    if moved then return "ok" end
    if resolve(opts.exempt) then
        state.still = 0
        return "ok"
    end
    if resolve(opts.onSpot) then
        state.checkX, state.checkY = nil, nil
        state.still = 0
        state.progressAt = Bridge.time
        return "waiting"
    end
    state.checkX, state.checkY = nil, nil
    return "stalled"
end

function BridgeNav.detour(body, x, y, z, state, opts)
    opts = opts or {}
    local bx, by = body:getX(), body:getY()
    local ddx, ddy = (x + 0.5) - bx, (y + 0.5) - by
    local dlen = math.sqrt(ddx * ddx + ddy * ddy)
    if dlen <= 0.05 then return nil end
    ddx, ddy = ddx / dlen, ddy / dlen
    local cell = getCell()
    local gz = math.floor(z)
    state.detourSide = -(state.detourSide or 1)
    for _, s in ipairs({ state.detourSide, -state.detourSide }) do
        local px = math.floor(bx + (-ddy * s) * (opts.step or 1.6))
        local py = math.floor(by + (ddx * s) * (opts.step or 1.6))
        local cand = cell:getGridSquare(px, py, gz)
        local free = false
        if cand ~= nil then pcall(function() free = cand:isFree(false) == true end) end
        if free then
            local point = { x = px + 0.5, y = py + 0.5, z = z,
                expires = Bridge.time + (opts.ticks or 150) }
            state.detour = point
            return point, px, py
        end
    end
    return nil
end
