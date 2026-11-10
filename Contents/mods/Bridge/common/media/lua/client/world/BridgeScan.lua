BridgeScan = BridgeScan or {}

BridgeScan.RADIUS = 16
BridgeScan.MAX_AGE = 15
BridgeScan.SPEECH_AGE = 30

local frame = nil
local entryPool = {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeScan] " .. tostring(text)) end end

local function maxAge()
    if BridgePerf ~= nil and type(BridgePerf.age) == "function" then
        return BridgePerf.age("scanFrame", 30)
    end
    return BridgeScan.MAX_AGE
end

local function readPos(z)
    return z:getX(), z:getY(), z:getZ()
end

local function readAliveHp(z)
    return z:isAlive() == true, z:getHealth()
end

local function readBodyVar(z, var)
    return z:getVariableBoolean(var) == true
end

local function readHarmless(z)
    return BridgeData.harmless(z) == true
end

local function readAggro(z, red)
    return z:getTarget() == red
end

local function readAction(z)
    local st = z:getActionStateName()
    return st, (z:isProne() or z:isCrawling() or st == "onground" or st == "sitonground")
end

function BridgeScan.invalidate(reason)
    frame = nil
end

local function seenBy(viewer, z)
    if viewer == nil or z == nil then return false end
    if BridgeZScan ~= nil and type(BridgeZScan.canSee) == "function" then
        return BridgeZScan.canSee(z, viewer, viewer) == true
    end
    local seen = false
    local ok, got = pcall(viewer.CanSee, viewer, z)
    if ok then seen = got == true end
    return seen
end

local function entryRead(e, z, ox, oy, oz, cx, cy, cz, red, body, var)
    local zx, zy, zz = nil, nil, nil
    if BridgeZScan ~= nil and type(BridgeZScan.pos) == "function" then
        zx, zy, zz = BridgeZScan.pos(z)
    end
    if zx == nil then zx, zy, zz = z:getX(), z:getY(), z:getZ() end
    e.z, e.zz = z, zz
    e.dpx, e.dpy = zx - ox, zy - oy
    e.dcx, e.dcy = zx - cx, zy - cy
    e.dp2 = e.dpx * e.dpx + e.dpy * e.dpy
    e.dc2 = e.dcx * e.dcx + e.dcy * e.dcy
    e.dp = math.sqrt(e.dp2)
    e.dc = math.sqrt(e.dc2)
    e.zp = zz - oz
    e.zc = zz - cz
    local alive = false
    if BridgeZScan ~= nil and type(BridgeZScan.isAlive) == "function" then
        alive = BridgeZScan.isAlive(z) == true and BridgeZScan.healthUp(z) == true
    else
        local okA, a, hp = pcall(readAliveHp, z)
        alive = okA and a == true and (tonumber(hp) or 0) > 0
    end
    e.alive = alive
    e.comp = false
    local memoComp = nil
    if BridgeZScan ~= nil and type(BridgeZScan.cachedCompanion) == "function" then
        memoComp = BridgeZScan.cachedCompanion(z)
    end
    if memoComp ~= nil then
        e.comp = memoComp == true
    elseif BridgeZScan ~= nil and type(BridgeZScan.isCompanion) == "function" then
        e.comp = BridgeZScan.isCompanion(z) == true
    else
        local okB, bv = pcall(readBodyVar, z, var)
        if okB then e.comp = bv == true end
    end
    e.harm = false
    local memoHarm = nil
    if BridgeZScan ~= nil and type(BridgeZScan.cachedHarmless) == "function" then
        memoHarm = BridgeZScan.cachedHarmless(z)
    end
    if memoHarm ~= nil then
        e.harm = memoHarm == true
    else
        local okH, hv = pcall(readHarmless, z)
        if okH then e.harm = hv == true end
    end
    e.remote = false
    local memoRemote = nil
    if BridgeZScan ~= nil and type(BridgeZScan.cachedRemote) == "function" then
        memoRemote = BridgeZScan.cachedRemote(z)
    end
    if memoRemote ~= nil then
        e.remote = memoRemote == true
    elseif BridgeZScan ~= nil and type(BridgeZScan.isRemote) == "function" then
        e.remote = BridgeZScan.isRemote(z) == true
    end
    e.threat = e.alive and not e.comp and not e.harm and not e.remote
    e.seenP = seenBy(red, z)
    e.seenC = seenBy(body, z)
    e.seenR = e.seenP or e.seenC
    e.aggro = false
    local okG, aggro = pcall(readAggro, z, red)
    if okG then e.aggro = aggro == true end
    e.state = "?"
    e.down = false
    local okS, st, down = pcall(readAction, z)
    if okS then
        e.state = st
        e.down = down == true
    end
end

local function build(body, red)
    if body == nil and red == nil then return nil end
    local cell = nil
    pcall(function() cell = getCell() end)
    if cell == nil then return nil end
    local ox, oy, oz = 0, 0, 0
    local cx, cy, cz = 0, 0, 0
    if red ~= nil then pcall(function() ox, oy, oz = red:getX(), red:getY(), red:getZ() end) end
    if body ~= nil then
        pcall(function() cx, cy, cz = body:getX(), body:getY(), body:getZ() end)
    else
        cx, cy, cz = ox, oy, oz
    end
    local list = nil
    if BridgeZS ~= nil then
        list = BridgeZS.nearUnion(ox, oy, cx, cy, BridgeScan.RADIUS, { tag = "scan.frame" })
    end
    if list == nil then pcall(function() list = cell:getZombieList() end) end
    if list == nil then return nil end
    local entries = {}
    local var = (Bridge ~= nil and Bridge.BODY_VAR) or "NotAloneBody"
    pcall(function()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil then
                local e = entryPool[#entries + 1]
                if e == nil then
                    e = {}
                    entryPool[#entries + 1] = e
                end
                local ok = pcall(entryRead, e, z, ox, oy, oz, cx, cy, cz, red, body, var)
                if ok then entries[#entries + 1] = e end
            end
        end
    end)
    for i = #entries + 1, #entryPool do
        local e = entryPool[i]
        if e ~= nil then e.z = nil end
    end
    local f = {
        tick = (Bridge ~= nil and tonumber(Bridge.time)) or 0,
        cell = cell,
        entries = entries,
        ox = ox, oy = oy, oz = oz,
        cx = cx, cy = cy, cz = cz,
        targetWasNil = BridgeFight == nil or BridgeFight.target == nil,
        bodyZ = body ~= nil and body:getZ() or nil,
    }
    function f.zombies()
        local out = {}
        for i = 1, #entries do out[i] = entries[i].z end
        return out
    end
    function f.count(radius, viewer)
        local r = tonumber(radius) or 12
        local n = 0
        for i = 1, #entries do
            local e = entries[i]
            if e.alive and not e.comp and not e.harm then
                if viewer == "player" then
                    if e.dp <= r and math.abs(e.zp) < 1 then n = n + 1 end
                else
                    if e.dc <= r and math.abs(e.zc) < 1 then n = n + 1 end
                end
            end
        end
        return n
    end
    f.countNear = f.count
    function f.seen(radius, viewer)
        local r = tonumber(radius) or 12
        local n = 0
        for i = 1, #entries do
            local e = entries[i]
            if e.alive and not e.comp and not e.harm then
                local ok = viewer == "player" and e.seenP or e.seenC
                if viewer == nil then ok = e.seenR end
                if ok then
                    if viewer == "player" then
                        if e.dp <= r and math.abs(e.zp) < 1 then n = n + 1 end
                    else
                        if e.dc <= r and math.abs(e.zc) < 1 then n = n + 1 end
                    end
                end
            end
        end
        return n
    end
    function f.onPlayer()
        local n = 0
        for i = 1, #entries do
            local e = entries[i]
            if e.aggro and e.dp <= 1.5 and math.abs(e.zp) < 1 then n = n + 1 end
        end
        return n
    end
    function f.downed()
        local out = {}
        for i = 1, #entries do
            local e = entries[i]
            if e.down and e.alive and not e.comp then out[#out + 1] = e.z end
        end
        return out
    end
    function f.attackers(radius)
        local r = tonumber(radius) or 12
        local n = 0
        for i = 1, #entries do
            local e = entries[i]
            if e.aggro and e.dp <= r and math.abs(e.zp) < 1 then n = n + 1 end
        end
        return n
    end
    return f
end

function BridgeScan.frame(body, red)
    local okCell, cell = pcall(getCell)
    if not okCell or cell == nil then return nil end
    local tick = (Bridge ~= nil and tonumber(Bridge.time)) or 0
    if frame ~= nil and frame.cell == cell and (tick - frame.tick) < maxAge() then
        local stale = false
        if frame.checkTick ~= tick or frame.checkBody ~= body or frame.checkRed ~= red then
            if red ~= nil then
                local okDead, dead = pcall(red.isDead, red)
                if okDead and dead then stale = true end
                local okVeh, veh = pcall(red.getVehicle, red)
                if okVeh and veh ~= nil then stale = true end
            end
            if body ~= nil then
                local okZ, bz = pcall(body.getZ, body)
                if okZ and bz ~= nil then
                    if frame.bodyZ ~= nil and bz ~= frame.bodyZ then stale = true end
                    frame.bodyZ = bz
                end
            end
            frame.checkTick, frame.checkBody, frame.checkRed, frame.checkStale = tick, body, red, stale
        else
            stale = frame.checkStale
        end
        local target = BridgeFight ~= nil and BridgeFight.target or nil
        if frame.targetWasNil == true and target ~= nil then stale = true end
        frame.targetWasNil = target == nil
        if not stale then return frame end
    end
    frame = nil
    if body == nil and red == nil then return nil end
    frame = build(body, red)
    return frame
end

if Events ~= nil and Events.OnGameStart ~= nil then
    pcall(function() Events.OnGameStart.Add(function() BridgeScan.invalidate("start") end) end)
end

if Events ~= nil and Events.OnCreatePlayer ~= nil then
    pcall(function() Events.OnCreatePlayer.Add(function() BridgeScan.invalidate("start") end) end)
end

log("loaded")
