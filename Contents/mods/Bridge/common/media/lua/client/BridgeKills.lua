BridgeKills = BridgeKills or {}

BridgeKills.pending = setmetatable({}, { __mode = "k" })
BridgeKills.PENDING_TTL = 20 * 60
BridgeKills.PENDING_MAX = 64
BridgeKills.lastSweep = -99999
BridgeKills.info = "none"

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeKills] " .. tostring(text)) end end

local function isBodyZ(z)
    local ok, v = pcall(function() return z:getVariableBoolean("NotAloneBody") end)
    return ok and v
end

local function deadZ(z)
    local dead = false
    pcall(function() dead = (not z:isAlive()) or z:isDead() or z:isOnKillDone() or z:getHealth() <= 0 end)
    return dead == true
end

function BridgeKills.credit(z)
    if z == nil then return false end
    if isBodyZ(z) then return false end
    local pending = BridgeKills.pending
    pending[z] = { t = Bridge.time }
    local count = 0
    local oldest, oldestT = nil, nil
    for k, v in pairs(pending) do
        count = count + 1
        if oldestT == nil or v.t < oldestT then oldest, oldestT = k, v.t end
    end
    if count > BridgeKills.PENDING_MAX and oldest ~= nil then pending[oldest] = nil end
    return true
end

function BridgeKills.clear(z)
    if z == nil then return false end
    BridgeKills.pending[z] = nil
    return true
end

function BridgeKills.count()
    if Bridge.store ~= nil and type(Bridge.store.kills) == "number" then return math.floor(Bridge.store.kills) end
    if type(Bridge.localKills) == "number" then return math.floor(Bridge.localKills) end
    return 0
end

function BridgeKills.setCount(n)
    n = BridgeData.cleanCount(n)
    if Bridge.store ~= nil then Bridge.store.kills = n end
    Bridge.localKills = n
    if Bridge.mp then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { kills = n }) end)
    end
    return n
end

function BridgeKills.bump()
    local base = Bridge.localKills
    if Bridge.store ~= nil and type(Bridge.store.kills) == "number" then base = Bridge.store.kills end
    if type(base) ~= "number" then base = 0 end
    local n = math.floor(base) + 1
    if Bridge.store ~= nil then Bridge.store.kills = n end
    Bridge.localKills = n
    if Bridge.mp then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { kills = n }) end)
    end
    pcall(function() if BridgeCallout ~= nil and BridgeCallout.milestone ~= nil then BridgeCallout.milestone(n) end end)
    BridgeKills.info = "kills " .. tostring(n)
    log("bump " .. tostring(n))
    return n
end

function BridgeKills.confirm(z)
    if z == nil then return false end
    local p = BridgeKills.pending[z]
    if p == nil then return false end
    if not deadZ(z) then return false end
    BridgeKills.pending[z] = nil
    BridgeKills.bump()
    return true
end

function BridgeKills.sweep()
    local pending = BridgeKills.pending
    for z, v in pairs(pending) do
        if deadZ(z) then
            pending[z] = nil
            BridgeKills.bump()
        elseif Bridge.time - v.t > BridgeKills.PENDING_TTL then
            pending[z] = nil
        end
    end
end

function BridgeKills.onTick()
    if Bridge == nil or Bridge.time == nil then return end
    if Bridge.time - BridgeKills.lastSweep < 60 then return end
    BridgeKills.lastSweep = Bridge.time
    pcall(BridgeKills.sweep)
end

function BridgeKills.onDead(z)
    if z == nil then return end
    if isBodyZ(z) then return end
    pcall(function() BridgeKills.confirm(z) end)
end

Events.OnZombieDead.Add(BridgeKills.onDead)
Events.OnTick.Add(BridgeKills.onTick)

log("loaded")
