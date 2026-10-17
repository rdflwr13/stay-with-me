-- Unified horde detection, shared by BridgeCallout (on foot) and BridgeDrive (in car).
-- One threat definition and one tier mapping for every callout that reports hordes.
BridgeHorde = BridgeHorde or {}

BridgeHorde.RADIUS    = 14     -- on foot: tiles around the player
BridgeHorde.CONE_MIN  = 5      -- in car: near edge of the forward cone
BridgeHorde.CONE_MAX  = 35     -- in car: far edge of the forward cone
BridgeHorde.CONE_HALF = 2.5    -- lateral slack added to the car half-width

-- Minimum tier is 4; topped out at 32. tier(n) returns the highest tier <= n.
BridgeHorde.TIERS = { 4, 8, 16, 32 }

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeHorde] " .. tostring(text)) end end


-- A live, non-companion, non-harmless, non-remote zombie. Single source of truth.
function BridgeHorde.threat(z)
    if z == nil then return false end
    local alive = false
    pcall(function() alive = z:isAlive() and z:getHealth() > 0 end)
    if not alive then return false end
    local companion = false
    pcall(function() companion = z:getVariableBoolean(Bridge.BODY_VAR) end)
    if not companion and Bridge.isCompanion ~= nil then pcall(function() companion = Bridge.isCompanion(z) end) end
    if companion then return false end
    local remote = false
    if isClient() then pcall(function() remote = z:isRemoteZombie() end) end
    if remote then return false end
    if BridgeData.harmless(z) then return false end
    return true
end


function BridgeHorde.tier(n)
    if type(n) ~= "number" then return nil end
    local best = nil
    for i = 1, #BridgeHorde.TIERS do
        if n >= BridgeHorde.TIERS[i] then best = BridgeHorde.TIERS[i] end
    end
    return best
end


-- Count threats within `radius` of (cx, cy, cz) on the same floor.
function BridgeHorde.count(cx, cy, cz, radius)
    if cx == nil or cy == nil then return 0 end
    local r = tonumber(radius) or BridgeHorde.RADIUS
    local r2 = r * r
    local czz = tonumber(cz) or 0
    local n = 0
    pcall(function()
        local list = getCell():getZombieList()
        local sz = list:size()
        for i = 0, sz - 1 do
            local z = nil
            pcall(function() z = list:get(i) end)
            if z ~= nil and BridgeHorde.threat(z) then
                local dx, dy = z:getX() - cx, z:getY() - cy
                if dx * dx + dy * dy <= r2 and math.abs(z:getZ() - czz) < 1 then n = n + 1 end
            end
        end
    end)
    return n
end


-- Count threats in the car's forward cone between minD and maxD (tiles), within the
-- car half-width plus `half`. When `seen` is true, the target must be visible to `red`.
function BridgeHorde.countCone(car, minD, maxD, half, seen, red)
    if car == nil or BridgeCar == nil then return 0 end
    local C = BridgeCar.frame(car)
    if C == nil then return 0 end
    local dmin = tonumber(minD) or BridgeHorde.CONE_MIN
    local dmax = tonumber(maxD) or BridgeHorde.CONE_MAX
    local hw = C.hw + (tonumber(half) or BridgeHorde.CONE_HALF)
    local cz = nil
    pcall(function() cz = car:getZ() end)
    local n = 0
    pcall(function()
        local list = getCell():getZombieList()
        local sz = list:size()
        for i = 0, sz - 1 do
            local z = nil
            pcall(function() z = list:get(i) end)
            if z ~= nil and BridgeHorde.threat(z) then
                local rx, ry = z:getX() - C.cx, z:getY() - C.cy
                local along = rx * C.fx + ry * C.fy
                local side = ry * C.fx - rx * C.fy
                if along >= dmin and along <= dmax and math.abs(side) <= hw
                    and (cz == nil or math.abs(z:getZ() - cz) < 1) then
                    local ok = true
                    if seen and red ~= nil then
                        local vis = false
                        pcall(function() vis = red:CanSee(z) end)
                        ok = vis
                    end
                    if ok then n = n + 1 end
                end
            end
        end
    end)
    return n
end


log("loaded")
