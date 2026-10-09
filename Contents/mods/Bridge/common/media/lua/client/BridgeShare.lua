











BridgeShare = BridgeShare or {}
BridgeShare.PHASE = 7

BridgeShare.SHARE = 0.5
BridgeShare.CATCHUP = 0.75
BridgeShare.RANGE = 12

BridgeShare.who = nil
BridgeShare.xp = {}

local function owner()
    if BridgeData == nil or BridgeData.owner == nil then return nil end
    local red = nil
    pcall(function() red = BridgeData.owner() end)
    return red
end

local function perkObject(perk)
    if BridgeSkills == nil or BridgeSkills.perkOf == nil then return nil end
    return BridgeSkills.perkOf(perk)
end




local function maintXp(item)
    if BridgeSkills == nil or BridgeSkills.rollMaintenance == nil then return 0 end
    return BridgeSkills.rollMaintenance(item)
end


local function inRange(red)
    local body = Bridge.body
    if body == nil then return false end
    local dx, dy, dz = 0, 0, 99
    pcall(function()
        dx = red:getX() - body:getX()
        dy = red:getY() - body:getY()
        dz = red:getZ() - body:getZ()
    end)
    if math.abs(dz) >= 1 then return false end
    return (dx * dx + dy * dy) <= (BridgeShare.RANGE * BridgeShare.RANGE)
end

local function playerLevel(red, perk)
    local p = perkObject(perk)
    if p == nil then return 0 end
    local lvl = 0
    pcall(function() lvl = red:getPerkLevel(p) end)
    return tonumber(lvl) or 0
end




local function fracFor(perk, red)
    if BridgeSkills.level(perk) < playerLevel(red, perk) then return BridgeShare.CATCHUP end
    return BridgeShare.SHARE
end

function BridgeShare.tick()
    if BridgeSkills == nil or BridgeSkills.add == nil then return end
    local red = owner()
    if red == nil then return end


    if red ~= BridgeShare.who then
        BridgeShare.who = red
        BridgeShare.xp = {}
    end

    local near = inRange(red)
    local tracked = BridgeSkills.TRACKED or {}
    for i = 1, #tracked do
        local perk = tracked[i]
        local p = perkObject(perk)
        if p ~= nil then
            local now = nil
            pcall(function() now = red:getXp():getXP(p) end)
            if now ~= nil then
                local prev = BridgeShare.xp[perk]
                BridgeShare.xp[perk] = now

                if prev ~= nil and now > prev and near then
                    BridgeSkills.add(perk, (now - prev) * fracFor(perk, red), "share", true)
                end
            end
        end
    end
end







local function mirrorCap(red, perk, amount, reason)
    if red == nil or not inRange(red) then return end
    if amount == nil or amount <= 0 then return end
    if playerLevel(red, perk) < BridgeSkills.MAX_LEVEL then return end
    if BridgeSkills.level(perk) >= BridgeSkills.MAX_LEVEL then return end
    BridgeSkills.add(perk, amount * fracFor(perk, red), "mirror:" .. reason, true)
end



local function onWeaponHitXp(plr, weapon, hitObject, damage, hitCount)
    if Bridge.mp then return end
    local red = owner()
    if red == nil or plr ~= red then return end


    local sc = tonumber(hitCount)
    if sc == nil or sc <= 0 then sc = 1 end
    mirrorCap(red, "Strength",    sc, "hit")
    mirrorCap(red, "Maintenance", maintXp(weapon), "hit")
    local cat = BridgeSkills.categoryFor(weapon)
    if cat ~= nil then
        mirrorCap(red, cat, math.min((damage or 0) * 0.9, 3), "swing")
    end
end

local function onWeaponHitTree(plr, weapon)
    if Bridge.mp then return end
    local red = owner()
    if red == nil or plr ~= red then return end
    mirrorCap(red, "Strength", 2, "tree")
end

if type(Events) == "table" and Events.OnWeaponHitXp ~= nil then
    Events.OnWeaponHitXp.Add(onWeaponHitXp)
end
if type(Events) == "table" and Events.OnWeaponHitTree ~= nil then
    Events.OnWeaponHitTree.Add(onWeaponHitTree)
end





local MIRROR_FLAT = 1
local mirrorWasAttacking = false
local function mirrorTick()
    if not Bridge.mp then return end
    local red = owner()
    if red == nil then return end
    local attacking = false


    local probe = nil
    pcall(function() probe = red.isDoHandToHandAttack end)
    if probe ~= nil then pcall(function() attacking = red:isDoHandToHandAttack() end) end
    if not attacking then pcall(function() attacking = red:isAttacking() end) end
    if attacking and not mirrorWasAttacking then
        local w = nil
        pcall(function() w = red:getPrimaryHandItem() end)
        local cat = BridgeSkills.categoryFor(w)
        if cat ~= nil then mirrorCap(red, cat, MIRROR_FLAT, "mp") end
        mirrorCap(red, "Strength",    MIRROR_FLAT, "mp")
        mirrorCap(red, "Maintenance", maintXp(w), "mp")
    end
    mirrorWasAttacking = attacking
end




local function playerRunning(red)
    local v = false
    pcall(function() v = red:isRunning() end)
    if v ~= true then pcall(function() v = red:IsRunning() end) end
    if v ~= true then pcall(function() v = red:isSprinting() end) end
    return v == true
end





local fitnessAt = -9999
local fitWasX, fitWasY = nil, nil
local function fitnessMirrorTick()
    if BridgeSkills == nil then return end
    local red = owner()
    if red == nil then return end
    if (Bridge.time or 0) < fitnessAt then return end
    fitnessAt = (Bridge.time or 0) + 60
    if playerLevel(red, "Fitness") < BridgeSkills.MAX_LEVEL then
        fitWasX, fitWasY = nil, nil
        return
    end
    if not playerRunning(red) then
        fitWasX, fitWasY = nil, nil
        return
    end
    local x, y = nil, nil
    pcall(function() x, y = red:getX(), red:getY() end)
    local moved = true
    if x ~= nil and fitWasX ~= nil then moved = (x ~= fitWasX) or (y ~= fitWasY) end
    fitWasX, fitWasY = x, y
    if not moved then return end
    local endur, warn = 1.0, 0.5
    pcall(function() endur = red:getStats():get(CharacterStat.ENDURANCE) end)
    pcall(function() warn = red:getStats():getEnduranceWarning() end)
    if endur <= warn then return end

    if ZombRand(1000) < 50 then mirrorCap(red, "Fitness", 1, "run") end
end

if type(Events) == "table" and Events.OnTick ~= nil then
    Events.OnTick.Add(function() pcall(BridgeShare.tick) end)
    Events.OnTick.Add(function() pcall(mirrorTick) end)
    Events.OnTick.Add(function() pcall(fitnessMirrorTick) end)
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeShare] loaded") end
