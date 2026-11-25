BridgeMuzzleSmokeCompat = BridgeMuzzleSmokeCompat or {}
local B = BridgeMuzzleSmokeCompat

local logged = false
local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeMuzzleSmoke] " .. tostring(text))
    end
end

function B.ready()
    if MuzzleSmoke == nil then return false end
    if MuzzleSmoke.initialized ~= true then return false end
    if type(MuzzleSmoke.spawnBurstInto) ~= "function" then return false end
    if type(MuzzleSmoke.particles) ~= "table" then return false end
    return true
end

function B.burst(body, tx, ty)
    if not B.ready() then return false end
    if body == nil then return false end
    local weapon = nil
    pcall(function() weapon = body:getPrimaryHandItem() end)
    if weapon == nil then return false end

    local x, y, z, dx, dy
    pcall(function() x, y, z, dx, dy = MuzzleSmoke.muzzlePos(body, weapon) end)
    if x == nil then
        local fx = rawget(_G, "BridgeShotFx")
        if fx == nil or type(fx.muzzleOf) ~= "function" then return false end
        pcall(function() x, y, z = fx.muzzleOf(body, tx, ty) end)
        pcall(function()
            local f = body:getForwardDirection()
            if f ~= nil then dx, dy = f:getX(), f:getY() end
        end)
    end
    if x == nil or dx == nil or dy == nil then return false end

    local outside = false
    pcall(function() outside = body:isOutside() == true end)
    local scale = 1.0
    pcall(function() scale = MuzzleSmoke.smokeScaleFor(weapon) end)
    local suppressed = false
    pcall(function() suppressed = MuzzleSmoke.isSuppressed(weapon) end)
    pcall(MuzzleSmoke.spawnBurstInto, MuzzleSmoke.particles,
        x, y, z, dx, dy, scale, suppressed, outside, nil)
    if not logged then
        logged = true
        log("active: muzzle smoke for companion shots")
    end
    return true
end
