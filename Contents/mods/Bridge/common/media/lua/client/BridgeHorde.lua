BridgeHorde = BridgeHorde or {}

BridgeHorde.RADIUS    = 14
BridgeHorde.CONE_MIN  = 5
BridgeHorde.CONE_MAX  = 35
BridgeHorde.CONE_HALF = 2.5

BridgeHorde.TIERS = { 4, 8, 16, 32 }

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeHorde] " .. tostring(text)) end end


function BridgeHorde.threat(z)
    if z == nil then return false end
    if BridgeZScan ~= nil and type(BridgeZScan.isThreat) == "function" then
        return BridgeZScan.isThreat(z) == true
    end
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


function BridgeHorde.count(cx, cy, cz, radius)
    if cx == nil or cy == nil then return 0 end
    local r = tonumber(radius) or BridgeHorde.RADIUS
    local r2 = r * r
    local czz = tonumber(cz) or 0
    local n = 0
    pcall(function()
        if BridgeZScan ~= nil and type(BridgeZScan.count) == "function" then
            if BridgeZScan.enabled == false then
                n = BridgeZScan.count(cx, cy, czz, r, "canonical", { tag = "horde.count", zTol = 1 })
                return
            end
            if BridgeZScan.refresh() ~= nil then
                n = BridgeZScan.count(cx, cy, czz, r, "canonical", { tag = "horde.count", zTol = 1 })
                return
            end
        end
        local list = nil
        if BridgeZS ~= nil then list = BridgeZS.near(cx, cy, r + 0.01, { tag = "horde.count" }) end
        if list == nil then list = getCell():getZombieList() end
        local sz = list:size()
        for i = 0, sz - 1 do
            local z = list:get(i)
            if z ~= nil and math.abs(z:getZ() - czz) < 1 and BridgeHorde.threat(z) then
                local dx, dy = z:getX() - cx, z:getY() - cy
                if dx * dx + dy * dy <= r2 then n = n + 1 end
            end
        end
    end)
    return n
end


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
        if BridgeZScan ~= nil and type(BridgeZScan.cone) == "function"
            and BridgeZScan.enabled ~= false and BridgeZScan.refresh() ~= nil then
            local opts = { tag = "horde.cone", zTol = 1, filter = BridgeZScan.isThreat }
            if cz ~= nil then opts.z = cz end
            local list = BridgeZScan.cone(C.cx, C.cy, C.fx, C.fy, dmin, dmax, hw, opts)
            if list == nil then return end
            for i = 0, list:size() - 1 do
                local z = list:get(i)
                if z ~= nil then
                    local ok = true
                    if seen and red ~= nil then
                        local vis = false
                        pcall(function() vis = red:CanSee(z) end)
                        ok = vis
                    end
                    if ok then n = n + 1 end
                end
            end
            return
        end
        local list = nil
        if BridgeZS ~= nil then
            local nearR = math.sqrt(dmax * dmax + hw * hw) + 0.5
            list = BridgeZS.near(C.cx, C.cy, nearR, { tag = "horde.cone" })
        end
        if list == nil then list = getCell():getZombieList() end
        local sz = list:size()
        for i = 0, sz - 1 do
            local z = list:get(i)
            if z ~= nil then
                local rx, ry = z:getX() - C.cx, z:getY() - C.cy
                local along = rx * C.fx + ry * C.fy
                local side = ry * C.fx - rx * C.fy
                if along >= dmin and along <= dmax and math.abs(side) <= hw
                    and (cz == nil or math.abs(z:getZ() - cz) < 1)
                    and BridgeHorde.threat(z) then
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
