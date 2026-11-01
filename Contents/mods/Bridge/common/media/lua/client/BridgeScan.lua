BridgeScan = BridgeScan or {}

BridgeScan.RADIUS = 16
BridgeScan.MAX_AGE = 15
BridgeScan.SPEECH_AGE = 30

local frame = nil

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeScan] " .. tostring(text)) end end

function BridgeScan.invalidate(reason)
    frame = nil
end

local function seenBy(viewer, z)
    if viewer == nil or z == nil then return false end
    if BridgeZScan ~= nil and type(BridgeZScan.canSee) == "function" then
        return BridgeZScan.canSee(z, viewer, viewer) == true
    end
    local seen = false
    pcall(function() seen = viewer:CanSee(z) == true end)
    return seen
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
                local zx, zy, zz = nil, nil, nil
                pcall(function() zx, zy, zz = z:getX(), z:getY(), z:getZ() end)
                if zx ~= nil then
                    local e = { z = z, zz = zz }
                    e.dpx, e.dpy = zx - ox, zy - oy
                    e.dcx, e.dcy = zx - cx, zy - cy
                    e.dp2 = e.dpx * e.dpx + e.dpy * e.dpy
                    e.dc2 = e.dcx * e.dcx + e.dcy * e.dcy
                    e.dp = math.sqrt(e.dp2)
                    e.dc = math.sqrt(e.dc2)
                    e.zp = zz - oz
                    e.zc = zz - cz
                    local alive, hp = false, 0
                    pcall(function() alive = z:isAlive() == true hp = z:getHealth() end)
                    e.alive = alive and (tonumber(hp) or 0) > 0
                    e.comp = false
                    pcall(function() e.comp = z:getVariableBoolean(var) == true end)
                    if not e.comp and BridgeZScan ~= nil and type(BridgeZScan.isCompanion) == "function" then
                        local ok, v = pcall(BridgeZScan.isCompanion, z)
                        if ok then e.comp = v == true end
                    end
                    e.harm = false
                    pcall(function() e.harm = BridgeData.harmless(z) == true end)
                    e.remote = false
                    if BridgeZScan ~= nil and type(BridgeZScan.isRemote) == "function" then
                        local ok, v = pcall(BridgeZScan.isRemote, z)
                        if ok then e.remote = v == true end
                    end
                    e.threat = e.alive and not e.comp and not e.harm and not e.remote
                    e.seenP = seenBy(red, z)
                    e.seenC = seenBy(body, z)
                    e.seenR = e.seenP or e.seenC
                    e.aggro = false
                    pcall(function() e.aggro = z:getTarget() == red end)
                    e.state = "?"
                    e.down = false
                    pcall(function()
                        e.state = z:getActionStateName()
                        e.down = z:isProne() or z:isCrawling()
                            or e.state == "onground" or e.state == "sitonground"
                    end)
                    entries[#entries + 1] = e
                end
            end
        end
    end)
    local f = {
        tick = (Bridge ~= nil and tonumber(Bridge.tick)) or 0,
        cell = cell,
        entries = entries,
        ox = ox, oy = oy, oz = oz,
        cx = cx, cy = cy, cz = cz,
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
    local cell = nil
    pcall(function() cell = getCell() end)
    if cell == nil then return nil end
    local tick = (Bridge ~= nil and tonumber(Bridge.tick)) or 0
    if frame ~= nil and frame.cell == cell and (tick - frame.tick) < BridgeScan.MAX_AGE then
        local stale = false
        if red ~= nil then
            pcall(function()
                if red:isDead() then stale = true end
                if red:getVehicle() ~= nil then stale = true end
            end)
        end
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
