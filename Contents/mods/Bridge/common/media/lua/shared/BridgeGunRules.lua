BridgeGunRules = BridgeGunRules or {}

BridgeGunRules.MAX_RANGE = 60
BridgeGunRules.MIN_RANGE = 3
BridgeGunRules.AIM_BONUS = 10
BridgeGunRules.MOVING_FACTOR = 0.85
BridgeGunRules.CLOSE_BONUS = 1.15
BridgeGunRules.FAR_PENALTY = 0.25
BridgeGunRules.MIN_CHANCE = 15
BridgeGunRules.MAX_CHANCE = 95
BridgeGunRules.NPC_DAMAGE_SCALE = 3.0
BridgeGunRules.FRIENDLY_RADIUS = 0.9
BridgeGunRules.MARK = "bridgePrimaryGun"

local function num(fn, fallback)
    local value = fallback
    pcall(function()
        local got = fn()
        if type(got) == "number" and got == got then value = got end
    end)
    return value
end

local function text(fn, fallback)
    local value = fallback
    pcall(function()
        local got = fn()
        if type(got) == "string" and got ~= "" then value = got end
    end)
    return value
end

local function flag(fn)
    local value = false
    pcall(function() value = fn() == true end)
    return value
end


function BridgeGunRules.isGun(item)
    local yes = false
    pcall(function()
        yes = item ~= nil and instanceof(item, "HandWeapon") and item:isRanged() == true
    end)
    return yes
end


function BridgeGunRules.valid(item)
    if not BridgeGunRules.isGun(item) then return false end
    local ok = false
    pcall(function()
        local broken = false
        pcall(function() broken = item:isBroken() == true end)
        local condition = 1
        pcall(function() condition = item:getCondition() end)
        local range = 0
        pcall(function() range = item:getMaxRange() end)
        ok = not broken and type(condition) == "number" and condition > 0
            and type(range) == "number" and range > 0
    end)
    return ok
end


function BridgeGunRules.kind(gun)
    local anim = text(function() return gun:getSwingAnim() end, "Handgun")
    if anim == "Rifle" then return "Rifle" end
    return "Handgun"
end


function BridgeGunRules.range(gun)
    local range = num(function() return gun:getMaxRange() end, 0)
    if range > BridgeGunRules.MAX_RANGE then range = BridgeGunRules.MAX_RANGE end
    if range < 1 then range = 1 end
    return range
end


function BridgeGunRules.describe(item)
    local out = {
        fullType = text(function() return item:getFullType() end, "?"),
        name = text(function() return item:getName() end, "gun"),
        maxRange = num(function() return item:getMaxRange() end, 0),
        minRange = num(function() return item:getMinRange() end, 0),
        minDamage = num(function() return item:getMinDamage() end, 0),
        maxDamage = num(function() return item:getMaxDamage() end, 0),
        hitChance = num(function() return item:getHitChance() end, 50),
        critChance = num(function() return item:getCriticalChance() end, 0),
        critMult = num(function() return item:getCriticalDamageMultiplier() end, 2),
        aimingTime = num(function() return item:getAimingTime() end, 40),
        recoilDelay = num(function() return item:getRecoilDelay() end, 24),
        sound = text(function() return item:getSwingSound() end, nil),
        hitSound = text(function() return item:getZombieHitSound() end, "ZombieHit"),
        impactSound = text(function() return item:getImpactSound() end, "BulletImpact"),
        soundRadius = num(function() return item:getSoundRadius() end, 20),
        soundVolume = num(function() return item:getSoundVolume() end, 10),
        projectileCount = num(function() return item:getProjectileCount() end, 1),
        twoHanded = flag(function() return item:isTwoHandWeapon() or item:isRequiresEquippedBothHands() end),
        kind = "Handgun",
    }
    out.kind = BridgeGunRules.kind(item)
    out.range = BridgeGunRules.range(item)
    return out
end


function BridgeGunRules.summary(gun)
    if type(gun) ~= "table" then return "none" end
    return string.format("%s rng=%s dmg=%.1f-%.1f hit=%.0f crit=%.0f aim=%.0f recoil=%.0f snd=%s rad=%.0f vol=%.0f two=%s kind=%s",
        tostring(gun.fullType), tostring(gun.range), gun.minDamage or 0, gun.maxDamage or 0,
        gun.hitChance or 0, gun.critChance or 0, gun.aimingTime or 0, gun.recoilDelay or 0,
        tostring(gun.sound or "-"), gun.soundRadius or 0, gun.soundVolume or 0,
        tostring(gun.twoHanded == true), tostring(gun.kind))
end


function BridgeGunRules.hitChance(gun, distance, moving)
    if type(gun) ~= "table" then return BridgeGunRules.MIN_CHANCE end
    local chance = (tonumber(gun.hitChance) or 50) + BridgeGunRules.AIM_BONUS
    chance = chance / 100
    if chance < 0 then chance = 0 end
    if chance > 1 then chance = 1 end
    local range = tonumber(gun.range) or BridgeGunRules.MAX_RANGE
    if range < 1 then range = 1 end
    local d = tonumber(distance) or 0
    if d < 0 then d = 0 end
    if d <= range * 0.4 then
        chance = chance * BridgeGunRules.CLOSE_BONUS
    else
        local far = math.min(1, (d - range * 0.4) / (range * 0.6))
        chance = chance * (1 - BridgeGunRules.FAR_PENALTY * far)
    end
    if moving then chance = chance * BridgeGunRules.MOVING_FACTOR end
    if chance < BridgeGunRules.MIN_CHANCE / 100 then chance = BridgeGunRules.MIN_CHANCE / 100 end
    if chance > BridgeGunRules.MAX_CHANCE / 100 then chance = BridgeGunRules.MAX_CHANCE / 100 end
    return chance * 100
end


function BridgeGunRules.rollDamage(gun)
    if type(gun) ~= "table" then return BridgeGunRules.NPC_DAMAGE_SCALE end
    local lo = tonumber(gun.minDamage) or 1
    local hi = tonumber(gun.maxDamage) or lo
    if hi < lo then hi = lo end
    local roll = 0
    pcall(function() roll = ZombRand(0, 1001) / 1000 end)
    local dmg = lo + (hi - lo) * roll
    return dmg * BridgeGunRules.NPC_DAMAGE_SCALE
end


local function dist2(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end
BridgeGunRules.dist2 = dist2


function BridgeGunRules.noiseMultiplier()
    local mult = 1
    pcall(function()
        if SandboxVars ~= nil and type(SandboxVars.FirearmNoiseMultiplier) == "number" then
            mult = SandboxVars.FirearmNoiseMultiplier
        end
    end)
    if mult < 0 then mult = 0 end
    return mult
end


function BridgeGunRules.lineClear(cell, x1, y1, z1, x2, y2, z2)
    if cell == nil then return false end
    if math.abs((z1 or 0) - (z2 or 0)) >= 0.5 then return false end
    local ok = false
    pcall(function()
        local z = math.floor(z1 or 0)
        local prev = cell:getGridSquare(math.floor(x1), math.floor(y1), z)
        if prev == nil then return end
        local dist = dist2(x1, y1, x2, y2)
        local steps = math.max(1, math.ceil(dist / 0.4))
        for i = 1, steps do
            local t = i / steps
            local sx = math.floor(x1 + (x2 - x1) * t)
            local sy = math.floor(y1 + (y2 - y1) * t)
            if sx ~= prev:getX() or sy ~= prev:getY() then
                local sq = cell:getGridSquare(sx, sy, z)
                if sq == nil then return end
                if sx ~= prev:getX() and sy ~= prev:getY() then
                    local a = cell:getGridSquare(sx, prev:getY(), z)
                    local b = cell:getGridSquare(prev:getX(), sy, z)
                    if a == nil or b == nil then return end
                    if prev:isBlockedTo(a) or a:isBlockedTo(sq) then return end
                    if prev:isBlockedTo(b) or b:isBlockedTo(sq) then return end
                elseif prev:isBlockedTo(sq) then
                    return
                end
                prev = sq
            end
        end
        ok = true
    end)
    return ok
end


function BridgeGunRules.pointSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len = dx * dx + dy * dy
    if len <= 0.0001 then return dist2(px, py, ax, ay), 0 end
    local t = ((px - ax) * dx + (py - ay) * dy) / len
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    local cx, cy = ax + dx * t, ay + dy * t
    return dist2(px, py, cx, cy), t
end


function BridgeGunRules.friendlyInLine(body, target, friendlies)
    if body == nil or target == nil then return nil end
    local blocked = nil
    pcall(function()
        local ax, ay, az = body:getX(), body:getY(), body:getZ()
        local bx, by, bz = target:getX(), target:getY(), target:getZ()
        for _, f in ipairs(friendlies or {}) do
            if f ~= nil and f ~= body and f ~= target then
                local fx, fy, fz = f:getX(), f:getY(), f:getZ()
                if math.abs((fz or az) - az) < 0.8 then
                    local d, t = BridgeGunRules.pointSegment(fx, fy, ax, ay, bx, by)
                    if d <= BridgeGunRules.FRIENDLY_RADIUS and t >= 0 and t < 0.99 then
                        blocked = f
                        return
                    end
                end
            end
        end
    end)
    return blocked
end


function BridgeGunRules.isForeignNpc(z)
    local who = nil
    pcall(function()
        if z == nil then return end
        if type(z.hasModData) == "function" and z:hasModData() == false then return end
        local md = nil
        pcall(function() md = z:getModData() end)
        if md ~= nil then
            if md.PS_NPC_ID ~= nil then who = "Project Survivors" end
            if md.ProjectALifeOwned == true or md.ProjectALifeActor == true then who = "Project A-Life" end
            if md.brainId ~= nil then who = "Bandits" end
        end
        if who == nil then
            local actor = nil
            pcall(function() actor = z:getVariableString("ALifeActor") end)
            if actor == "true" or actor == true then who = "Project A-Life" end
        end
        if who == nil then
            local primary = nil
            pcall(function() primary = z:getVariableString("BanditPrimary") end)
            if type(primary) == "string" and primary ~= "" then who = "Bandits" end
        end
        if who == nil and PS ~= nil and PS.Bodies ~= nil and type(PS.Bodies.isOurs) == "function" then
            local ours = false
            pcall(function() ours = PS.Bodies.isOurs(z) == true end)
            if ours then who = "Project Survivors" end
        end
    end)
    return who
end


local SHOT_SIDE = { "ShotChest", "ShotChestStep", "ShotLeg", "ShotShoulder", "ShotShoulderStep" }

function BridgeGunRules.shotReaction(shooter, victim, crit)
    if shooter == nil or victim == nil then return "ShotBelly" end
    local reaction = "ShotBelly"
    pcall(function()
        local fx, fy = victim:getForwardDirectionX(), victim:getForwardDirectionY()
        local dx, dy = shooter:getX() - victim:getX(), shooter:getY() - victim:getY()
        local len = math.sqrt(fx * fx + fy * fy) * math.sqrt(dx * dx + dy * dy)
        if len < 0.0001 then return end
        local facing = (fx * dx + fy * dy) / len
        if facing > 0.7 then
            if crit then reaction = "ShotHeadBwd"
            else reaction = ZombRand(2) == 0 and "ShotBelly" or "ShotBellyStep" end
        elseif facing < -0.7 then
            if crit then reaction = ZombRand(2) == 0 and "ShotHeadFwd" or "ShotHeadFwd02"
            else reaction = "ShotBellyStepBehind" end
        else
            local side = (fx * dy - fy * dx) >= 0 and "R" or "L"
            reaction = SHOT_SIDE[ZombRand(1, #SHOT_SIDE + 1)] .. side
        end
    end)
    return reaction
end


function BridgeGunRules.validType(value)
    if type(value) ~= "string" or value == "" or #value > 64 then return false end
    if string.match(value, "^[%w_%.]+$") == nil then return false end
    local item = nil
    pcall(function() item = instanceItem(value) end)
    return BridgeGunRules.valid(item)
end


local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGunRules] " .. tostring(text)) end
end

log("loaded")
