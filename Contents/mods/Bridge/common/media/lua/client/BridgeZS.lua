-- Compatibility shim for the unified zombie scan.
--
-- The cache now lives in shared/BridgeZScan.lua (one raw cell-list read per
-- tick per process). Existing BridgeZS callers keep working unchanged.
-- Rollback: set BridgeZScan.enabled = false.

BridgeZS = BridgeZS or {}

local function scan()
    return BridgeZScan
end

function BridgeZS.near(x, y, r, opts)
    local s = scan()
    if s == nil then return nil end
    return s.near(x, y, r, opts)
end

function BridgeZS.nearUnion(x1, y1, x2, y2, r, opts)
    local s = scan()
    if s == nil then return nil end
    return s.nearUnion(x1, y1, x2, y2, r, opts)
end

function BridgeZS.cone(x, y, fx, fy, minD, maxD, half, opts)
    local s = scan()
    if s == nil then return nil end
    return s.cone(x, y, fx, fy, minD, maxD, half, opts)
end

function BridgeZS.count(cx, cy, cz, r, filterOrProfile, opts)
    local s = scan()
    if s == nil then return 0 end
    return s.count(cx, cy, cz, r, filterOrProfile, opts)
end

function BridgeZS.find(pred, maxN, opts)
    local s = scan()
    if s == nil then return nil end
    return s.find(pred, maxN, opts)
end

function BridgeZS.list(opts)
    local s = scan()
    if s == nil then return nil end
    return s.list(opts)
end

function BridgeZS.update()
    local s = scan()
    if s == nil then return nil end
    return s.refresh()
end

function BridgeZS.invalidate(reason)
    local s = scan()
    if s ~= nil then s.invalidate(reason or "start") end
end

BridgeZS.stats = BridgeZScan ~= nil and BridgeZScan.stats or {}

if BridgeZScan ~= nil then
    BridgeZScan.tickOf = function()
        if Bridge == nil then return 0 end
        return tonumber(Bridge.tick) or 0
    end

    BridgeZScan.isCompanionOf = function(z)
        if Bridge ~= nil and type(Bridge.isCompanion) == "function" then
            return Bridge.isCompanion(z) == true
        end
        return false
    end

    BridgeZScan.isRemoteOf = function(z)
        if isClient == nil or not isClient() then return false end
        local remote = false
        pcall(function() remote = z:isRemoteZombie() == true end)
        return remote
    end
end

if Events ~= nil and Events.OnGameStart ~= nil then
    pcall(function() Events.OnGameStart.Add(function() BridgeZS.invalidate("start") end) end)
end

if Events ~= nil and Events.OnCreatePlayer ~= nil then
    pcall(function() Events.OnCreatePlayer.Add(function() BridgeZS.invalidate("start") end) end)
end
