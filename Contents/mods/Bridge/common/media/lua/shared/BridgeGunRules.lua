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

local function typeText(fn)
    local value = text(fn, nil)
    if value == nil or value == "null" then return nil end
    return value
end

local function clamp(v, lo, hi)
    if type(v) ~= "number" or v ~= v then v = lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function ammoKeyOf(item)
    local key = nil
    pcall(function()
        local ammo = item:getAmmoType()
        if ammo ~= nil then key = ammo:getItemKey() end
    end)
    if type(key) ~= "string" or key == "" or key == "null" then return nil end
    return key
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


function BridgeGunRules.familyOf(desc)
    if type(desc) ~= "table" then return "unsupported" end
    local reload = string.lower(tostring(desc.reloadType or ""))
    if desc.external == true or desc.magazineType ~= nil then
        if string.find(reload, "handgun", 1, true) ~= nil or desc.kind == "Handgun" then return "handgun" end
        return "rifle"
    end
    if string.find(reload, "shotgun", 1, true) ~= nil then return "shotgun" end
    if string.find(reload, "revolver", 1, true) ~= nil then return "revolver" end
    if string.find(reload, "boltactionnomag", 1, true) ~= nil then return "rifle_nomag" end
    if desc.ammoTypeKey == nil then return "unsupported" end
    if (tonumber(desc.projectileCount) or 1) > 1 then return "shotgun" end
    if desc.kind == "Handgun" then return "revolver" end
    return "rifle_nomag"
end


function BridgeGunRules.describe(item)
    local maxAmmo = num(function() return item:getMaxAmmo() end, 0)
    if maxAmmo <= 0 then maxAmmo = num(function() return item:getClipSize() end, 0) end
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
        maxHitCount = num(function() return item:getMaxHitCount() end, 1),
        piercingBullets = flag(function() return item:isPiercingBullets() end),
        projectileSpread = num(function() return item:getProjectileSpread() end, 1),
        minAngle = num(function() return item:getMinAngle() end, 0.9),
        twoHanded = flag(function() return item:isTwoHandWeapon() or item:isRequiresEquippedBothHands() end),
        kind = "Handgun",
        maxAmmo = maxAmmo,
        reloadType = typeText(function() return item:getWeaponReloadType() end),
        magazineType = typeText(function() return item:getMagazineType() end),
        ammoTypeKey = ammoKeyOf(item),
        ammoBox = typeText(function() return item:getAmmoBox() end),
        insertAll = flag(function() return item:isInsertAllBulletsReload() end),
        insertSound = typeText(function() return item:getInsertAmmoSound() end),
        ejectSound = typeText(function() return item:getEjectAmmoSound() end),
        insertStartSound = typeText(function() return item:getInsertAmmoStartSound() end),
        insertStopSound = typeText(function() return item:getInsertAmmoStopSound() end),
        rackSound = typeText(function() return item:getRackSound() end),
        rounds = 0,
    }
    out.kind = BridgeGunRules.kind(item)
    out.range = BridgeGunRules.range(item)
    out.external = out.magazineType ~= nil
    out.reloadFamily = BridgeGunRules.familyOf(out)
    pcall(function() out.rounds = BridgeGunRules.roundsOf(item) end)
    return out
end


function BridgeGunRules.summary(gun)
    if type(gun) ~= "table" then return "none" end
    return string.format("%s rng=%s dmg=%.1f-%.1f hit=%.0f crit=%.0f aim=%.0f recoil=%.0f snd=%s rad=%.0f vol=%.0f two=%s kind=%s ammo=%s mag=%s family=%s reload=%s maxhit=%s pierce=%s spread=%s minang=%s",
        tostring(gun.fullType), tostring(gun.range), gun.minDamage or 0, gun.maxDamage or 0,
        gun.hitChance or 0, gun.critChance or 0, gun.aimingTime or 0, gun.recoilDelay or 0,
        tostring(gun.sound or "-"), gun.soundRadius or 0, gun.soundVolume or 0,
        tostring(gun.twoHanded == true), tostring(gun.kind), tostring(gun.maxAmmo or 0),
        tostring(gun.magazineType or "-"), tostring(gun.reloadFamily or "?"), tostring(gun.reloadType or "-"),
        tostring(gun.maxHitCount or 1), tostring(gun.piercingBullets == true),
        tostring(gun.projectileSpread or 1), tostring(gun.minAngle or 0.9))
end


function BridgeGunRules.effectiveRange(desc, aimingLevel)
    if type(desc) ~= "table" then return 0 end
    local base = tonumber(desc.range) or tonumber(desc.maxRange) or 0
    local level = tonumber(aimingLevel) or 0
    if level < 0 then level = 0 end
    local range = base * (1 + 0.10 * level)
    if range > BridgeGunRules.MAX_RANGE then range = BridgeGunRules.MAX_RANGE end
    if range < 1 then range = 1 end
    return range
end


function BridgeGunRules.aimTicks(desc, aimingLevel)
    if type(desc) ~= "table" then return 10 end
    local level = tonumber(aimingLevel) or 0
    if level < 0 then level = 0 end
    local aim = (tonumber(desc.aimingTime) or 40) * 0.6 * (1 - 0.02 * level)
    if aim < 10 then aim = 10 end
    return math.floor(aim + 0.5)
end


function BridgeGunRules.reloadFactor(reloadingLevel)
    local level = tonumber(reloadingLevel) or 0
    if level < 0 then level = 0 end
    local factor = 1 - 0.04 * level
    if factor < 0.6 then factor = 0.6 end
    return factor
end


function BridgeGunRules.hitChance(gun, distance, moving, aimingLevel)
    if type(gun) ~= "table" then return BridgeGunRules.MIN_CHANCE end
    local level = tonumber(aimingLevel) or 0
    if level < 0 then level = 0 end
    local chance = (tonumber(gun.hitChance) or 50) + BridgeGunRules.AIM_BONUS + 1.5 * level
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


BridgeGunRules.FULL_PLANKS = 4

local function barricadeClosed(b)
    local closed = false
    if b == nil then return false end
    pcall(function()
        local metal = false
        pcall(function() metal = b:isMetal() == true end)
        local metalBar = false
        pcall(function() metalBar = b:isMetalBar() == true end)
        local planks = 0
        pcall(function() planks = tonumber(b:getNumPlanks()) or 0 end)
        local vision = false
        pcall(function() vision = b:isBlockVision() == true end)
        closed = metal or metalBar or planks >= BridgeGunRules.FULL_PLANKS or vision
    end)
    return closed
end


function BridgeGunRules.windowClosedOff(w)
    if w == nil then return false end
    local closed = false
    pcall(function()
        local same, opposite = nil, nil
        pcall(function() same = w:getBarricadeOnSameSquare() end)
        pcall(function() opposite = w:getBarricadeOnOppositeSquare() end)
        closed = barricadeClosed(same) or barricadeClosed(opposite)
    end)
    return closed
end


local function edgeWindow(a, b)
    if a == nil or b == nil then return nil end
    local w = nil
    pcall(function()
        if type(a.getWindowTo) == "function" then w = a:getWindowTo(b) end
        if w == nil and type(b.getWindowTo) == "function" then w = b:getWindowTo(a) end
        if w == nil and type(a.getWindowFrameTo) == "function" then w = a:getWindowFrameTo(b) end
        if w == nil and type(b.getWindowFrameTo) == "function" then w = b:getWindowFrameTo(a) end
        if w == nil and type(a.getWindowThumpableTo) == "function" then w = a:getWindowThumpableTo(b) end
        if w == nil and type(b.getWindowThumpableTo) == "function" then w = b:getWindowThumpableTo(a) end
    end)
    return w
end
BridgeGunRules.edgeWindow = edgeWindow


local function edgeStopsBullet(a, b)
    if a == nil or b == nil then return true, "no_square" end
    local w = edgeWindow(a, b)
    if w ~= nil then
        if BridgeGunRules.windowClosedOff(w) then return true, "barricade" end
        return false, nil
    end
    local hop = false
    pcall(function() hop = a:isHoppableTo(b) == true or b:isHoppableTo(a) == true end)
    if hop then return false, nil end
    local blocked = false
    pcall(function() blocked = a:isBlockedTo(b) == true or b:isBlockedTo(a) == true end)
    if blocked then return true, "wall_or_door" end
    return false, nil
end
BridgeGunRules.edgeStopsBullet = edgeStopsBullet


function BridgeGunRules.fireLineClear(cell, x1, y1, z1, x2, y2, z2)
    if cell == nil then return false, "no_square" end
    if math.abs((z1 or 0) - (z2 or 0)) >= 0.5 then return false, "floor" end
    local ok, why = true, nil
    pcall(function()
        local z = math.floor(z1 or 0)
        local prev = cell:getGridSquare(math.floor(x1), math.floor(y1), z)
        if prev == nil then ok = false why = "no_square" return end
        local dist = dist2(x1, y1, x2, y2)
        local steps = math.max(1, math.ceil(dist / 0.4))
        for i = 1, steps do
            local t = i / steps
            local sx = math.floor(x1 + (x2 - x1) * t)
            local sy = math.floor(y1 + (y2 - y1) * t)
            if sx ~= prev:getX() or sy ~= prev:getY() then
                local sq = cell:getGridSquare(sx, sy, z)
                if sq == nil then ok = false why = "no_square" return end
                local stopped, reason = false, nil
                if sx ~= prev:getX() and sy ~= prev:getY() then
                    local a = cell:getGridSquare(sx, prev:getY(), z)
                    local b = cell:getGridSquare(prev:getX(), sy, z)
                    if a == nil or b == nil then ok = false why = "no_square" return end
                    stopped, reason = edgeStopsBullet(prev, a)
                    if not stopped then stopped, reason = edgeStopsBullet(a, sq) end
                    if not stopped then stopped, reason = edgeStopsBullet(prev, b) end
                    if not stopped then stopped, reason = edgeStopsBullet(b, sq) end
                else
                    stopped, reason = edgeStopsBullet(prev, sq)
                end
                if stopped then ok = false why = reason or "wall_or_door" return end
                prev = sq
            end
        end
    end)
    return ok, why
end


function BridgeGunRules.targetVisible(body, red, z)
    if z == nil then return false end
    local seen = false
    if body ~= nil then
        pcall(function() seen = body:CanSee(z) == true end)
    end
    if not seen and red ~= nil and red ~= body then
        pcall(function() seen = red:CanSee(z) == true end)
    end
    return seen
end


function BridgeGunRules.breakGlassOnLine(cell, x1, y1, z1, x2, y2, z2)
    if cell == nil then return 0 end
    if math.abs((z1 or 0) - (z2 or 0)) >= 0.5 then return 0 end
    local broken = 0
    local seen = {}
    local function smash(w)
        if w == nil or seen[w] then return end
        seen[w] = true
        local skip = false
        pcall(function()
            if w:IsOpen() == true or w:isSmashed() == true then skip = true end
            if w.isInvincible ~= nil and w:isInvincible() == true then skip = true end
        end)
        if skip then return end
        local done = false
        pcall(function() w:smashWindow() done = true end)
        if done then broken = broken + 1 end
    end
    local function panesOn(sq)
        if sq == nil then return end
        pcall(function()
            local objects = sq:getObjects()
            if objects == nil then return end
            for i = 0, objects:size() - 1 do
                local object = objects:get(i)
                if object ~= nil and instanceof(object, "IsoWindow") then smash(object) end
            end
        end)
    end
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
                local w = edgeWindow(prev, sq)
                if w ~= nil then
                    smash(w)
                else
                    panesOn(prev)
                    panesOn(sq)
                end
                prev = sq
            end
        end
    end)
    return broken
end


BridgeGunRules.MAX_GUN_HITS = 16


function BridgeGunRules.shotgunConeDot(desc)
    local d = type(desc) == "table" and desc or {}
    local minDot = tonumber(d.minAngle) or 0.9
    local spread = math.max(1, tonumber(d.projectileSpread) or 1)
    return clamp(minDot - 0.05 * (spread - 1), 0.70, 0.98)
end


function BridgeGunRules.multiPlan(body, primary, desc, candidates, modeRange, opts)
    local plan = { kind = nil, extras = {}, primaryShare = 1 }
    if body == nil or primary == nil or type(desc) ~= "table" then return plan end
    local cap = math.floor(tonumber(desc.maxHitCount) or 1)
    cap = clamp(cap, 1, BridgeGunRules.MAX_GUN_HITS)
    if cap <= 1 then return plan end
    local range = tonumber(modeRange) or tonumber(desc.range) or 0
    local bx, by = body:getX(), body:getY()
    local px, py = primary:getX(), primary:getY()
    local pdx, pdy = px - bx, py - by
    local primaryDist = math.sqrt(pdx * pdx + pdy * pdy)
    if primaryDist < 0.001 then return plan end
    local list = {}
    if (tonumber(desc.projectileCount) or 1) > 1 then
        local ux, uy = pdx / primaryDist, pdy / primaryDist
        local cone = BridgeGunRules.shotgunConeDot(desc)
        cap = math.min(cap, math.max(1, math.floor(tonumber(desc.projectileCount) or 1)))
        for _, z in ipairs(candidates or {}) do
            if z ~= nil and z ~= body and z ~= primary then
                local dx, dy = z:getX() - bx, z:getY() - by
                local d = math.sqrt(dx * dx + dy * dy)
                if d > 0.001 and d <= range + 0.9 then
                    local dot = (dx * ux + dy * uy) / d
                    if dot >= cone then
                        list[#list + 1] = { target = z, dist = d, dot = dot }
                    end
                end
            end
        end
        table.sort(list, function(a, b)
            if math.abs(a.dot - b.dot) > 0.0001 then return a.dot > b.dot end
            return a.dist < b.dist
        end)
        while #list > cap - 1 do table.remove(list) end
        if #list > 0 then
            plan.kind = "shotgun"
            plan.primaryShare = 0.5
            local share = 0.5 / #list
            for _, ex in ipairs(list) do
                ex.share = share
                ex.chanceScale = clamp(0.55 + 0.45 * ex.dot, 0.55, 1.0)
                plan.extras[#plan.extras + 1] = ex
            end
        end
        return plan
    end
    if desc.piercingBullets == true then
        local ux, uy = pdx / primaryDist, pdy / primaryDist
        for _, z in ipairs(candidates or {}) do
            if z ~= nil and z ~= body and z ~= primary then
                local dx, dy = z:getX() - bx, z:getY() - by
                local along = dx * ux + dy * uy
                local lateral = math.abs(dx * uy - dy * ux)
                if along > primaryDist + 0.3 and along <= range + 0.3
                    and lateral <= 0.35 + 0.05 * along then
                    list[#list + 1] = { target = z, along = along, lateral = lateral }
                end
            end
        end
        table.sort(list, function(a, b) return a.along < b.along end)
        while #list > cap - 1 do table.remove(list) end
        if #list > 0 then
            plan.kind = "rifle"
            plan.primaryShare = 1
            local share = 0.5
            for _, ex in ipairs(list) do
                ex.share = share
                ex.chanceScale = 1
                share = share * 0.5
                plan.extras[#plan.extras + 1] = ex
            end
        end
        return plan
    end
    return plan
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


local function wornItems(body)
    local list = {}
    if body == nil then return list end
    pcall(function()
        local worn = body:getWornItems()
        if worn == nil then return end
        for i = 0, worn:size() - 1 do
            local entry = nil
            pcall(function() entry = worn:get(i) end)
            if entry == nil then pcall(function() entry = worn:getItemByIndex(i) end) end
            local item = entry
            if entry ~= nil then
                local ok, inner = pcall(function() return entry:getItem() end)
                if ok and inner ~= nil then item = inner end
            end
            if item ~= nil then list[#list + 1] = item end
        end
    end)
    return list
end


function BridgeGunRules.itemsOf(body)
    local out = {}
    if body == nil then return out end
    local seen = {}
    local function scan(container)
        if container == nil or seen[container] then return end
        seen[container] = true
        local items = nil
        pcall(function() items = container:getItems() end)
        if items == nil then return end
        for i = 0, items:size() - 1 do
            local item = nil
            pcall(function() item = items:get(i) end)
            if item ~= nil then
                out[#out + 1] = item
                local inner = nil
                pcall(function()
                    if item:IsInventoryContainer() then inner = item:getInventory() end
                end)
                if inner ~= nil then scan(inner) end
            end
        end
    end
    pcall(function() scan(body:getInventory()) end)
    pcall(function()
        for _, item in ipairs(wornItems(body)) do
            out[#out + 1] = item
            local bag = nil
            pcall(function() if item:IsInventoryContainer() then bag = item:getInventory() end end)
            if bag ~= nil then scan(bag) end
        end
    end)
    return out
end


function BridgeGunRules.placeItem(body, item, prefer)
    if body == nil or item == nil then return false end
    local added = false
    if prefer ~= nil then
        pcall(function() added = prefer:AddItem(item) ~= nil end)
        if added then return true end
    end
    pcall(function()
        for _, bagItem in ipairs(wornItems(body)) do
            if added then break end
            if bagItem:IsInventoryContainer() then
                local bag = nil
                pcall(function() bag = bagItem:getInventory() end)
                if bag ~= nil then
                    pcall(function() added = bag:AddItem(item) ~= nil end)
                end
            end
        end
    end)
    if added then return true end
    if BridgeGunRules.addToBody(body, item) then return true end
    pcall(function()
        local sq = nil
        pcall(function() sq = body:getCurrentSquare() end)
        if sq == nil then pcall(function() sq = body:getSquare() end) end
        if sq == nil then return end
        local x, y = ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9)
        local z = sq:getApparentZ(x, y) - sq:getZ()
        sq:AddWorldInventoryItem(item, x, y, z)
        added = true
    end)
    if added then
        pcall(function()
            print("[BridgeGunRules] no room for " .. tostring(item:getType()) .. ": dropped at her feet")
        end)
    end
    return added
end


function BridgeGunRules.findItemById(body, id)
    if body == nil or id == nil then return nil end
    local item = nil
    pcall(function() item = body:getInventory():getItemWithIDRecursiv(id) end)
    if item ~= nil then return item end
    for _, bagItem in ipairs(wornItems(body)) do
        if item ~= nil then break end
        local bag = nil
        pcall(function() if bagItem:IsInventoryContainer() then bag = bagItem:getInventory() end end)
        if bag ~= nil then
            pcall(function() item = bag:getItemWithIDRecursiv(id) end)
        end
    end
    return item
end


function BridgeGunRules.findGunItem(body, id, fullType)
    if body == nil then return nil end
    local function match(item)
        if item == nil or not BridgeGunRules.valid(item) then return false end
        if fullType ~= nil then
            local full = nil
            pcall(function() full = item:getFullType() end)
            if full ~= fullType then return false end
        end
        return true
    end

    local found = nil
    if id ~= nil then
        found = BridgeGunRules.findItemById(body, id)
        if not match(found) then found = nil end
    end

    if found == nil then
        pcall(function()
            local primary = body:getPrimaryHandItem()
            if match(primary) then found = primary end
            if found == nil then
                local secondary = body:getSecondaryHandItem()
                if match(secondary) then found = secondary end
            end
        end)
    end

    if found == nil then
        pcall(function()
            local attached = body:getAttachedItems()
            if attached == nil then return end
            for i = 0, attached:size() - 1 do
                local entry = nil
                pcall(function() entry = attached:get(i) end)
                if entry == nil then pcall(function() entry = attached:getItemByIndex(i) end) end
                local item = entry
                if entry ~= nil then
                    local ok, inner = pcall(function() return entry:getItem() end)
                    if ok and inner ~= nil then item = inner end
                end
                if match(item) then found = item break end
            end
        end)
    end

    if found == nil and fullType ~= nil then
        pcall(function()
            local items = BridgeGunRules.itemsOf(body)
            for _, item in ipairs(items) do
                if match(item) then found = item break end
            end
        end)
    end
    return found
end


function BridgeGunRules.itemCount(item)
    local count = 1
    if item == nil then return 0 end
    pcall(function()
        local n = item:getCount()
        if type(n) == "number" and n == n and n > 0 then count = math.floor(n) end
    end)
    return count
end


function BridgeGunRules.removeItem(item)
    if item == nil then return false end
    local ok = false
    pcall(function()
        local container = item:getContainer()
        if container ~= nil then
            container:Remove(item)
            ok = true
        end
    end)
    return ok
end


function BridgeGunRules.setItemCount(item, count)
    if item == nil then return false end
    if count <= 0 then return BridgeGunRules.removeItem(item) end
    local ok = false
    pcall(function()
        item:setCount(math.floor(count))
        ok = BridgeGunRules.itemCount(item) <= count
    end)
    if not ok then return BridgeGunRules.removeItem(item) end
    return true
end


function BridgeGunRules.addToBody(body, item)
    if body == nil or item == nil then return false end
    local ok = false
    pcall(function() ok = body:getInventory():AddItem(item) ~= nil end)
    return ok
end


function BridgeGunRules.roundsOf(item)
    local rounds = 0
    if item == nil then return 0 end
    pcall(function()
        local n = item:getCurrentAmmoCount()
        if type(n) == "number" and n == n and n > 0 then rounds = math.floor(n) end
    end)
    return rounds
end


function BridgeGunRules.setRounds(item, rounds, containsClip)
    if item == nil then return false end
    local n = math.floor(tonumber(rounds) or 0)
    if n < 0 then n = 0 end
    local ok = false
    local gun = BridgeGunRules.isGun(item)
    if gun and containsClip == true then
        pcall(function() item:setContainsClip(true) end)
        pcall(function()
            item:setCurrentAmmoCount(n)
            ok = true
        end)
    else
        pcall(function()
            item:setCurrentAmmoCount(n)
            ok = true
        end)
        if gun and containsClip ~= nil then
            pcall(function() item:setContainsClip(containsClip == true) end)
        end
    end
    return ok
end


function BridgeGunRules.findLoadedMagazine(body, desc)
    if body == nil or type(desc) ~= "table" or desc.magazineType == nil then return nil, 0 end
    local best, bestCount = nil, 0
    for _, item in ipairs(BridgeGunRules.itemsOf(body)) do
        local full = nil
        pcall(function() full = item:getFullType() end)
        if full == desc.magazineType then
            local n = BridgeGunRules.roundsOf(item)
            if n > bestCount then best, bestCount = item, n end
        end
    end
    if bestCount <= 0 then return nil, 0 end
    return best, bestCount
end


function BridgeGunRules.findLooseRounds(body, desc, need)
    local out, total = {}, 0
    if body == nil or type(desc) ~= "table" or desc.ammoTypeKey == nil then return out, total end
    local want = math.floor(tonumber(need) or 1)
    for _, item in ipairs(BridgeGunRules.itemsOf(body)) do
        if total >= want then break end
        local full = nil
        pcall(function() full = item:getFullType() end)
        if full == desc.ammoTypeKey then
            local n = BridgeGunRules.itemCount(item)
            if n > 0 then
                out[#out + 1] = { item = item, count = n }
                total = total + n
            end
        end
    end
    return out, total
end


function BridgeGunRules.removeOneLooseRound(body, desc)
    local key = type(desc) == "table" and desc.ammoTypeKey or nil
    if body == nil or key == nil then return nil end
    local removed = nil
    pcall(function() removed = body:getInventory():RemoveOneOf(key, true) end)
    if removed ~= nil then return removed end
    for _, bagItem in ipairs(wornItems(body)) do
        if removed ~= nil then break end
        if bagItem:IsInventoryContainer() then
            local bag = nil
            pcall(function() bag = bagItem:getInventory() end)
            if bag ~= nil then
                pcall(function() removed = bag:RemoveOneOf(key, true) end)
            end
        end
    end
    return removed
end


function BridgeGunRules.canSync(container)
    if container == nil then return false end
    local client = false
    pcall(function() client = isClient() == true end)
    if client then return false end
    local ok = false
    pcall(function()
        local parent = container:getParent()
        if parent == nil then return end
        local square = nil
        pcall(function() square = parent:getSquare() end)
        ok = square ~= nil
    end)
    return ok
end


function BridgeGunRules.removeItemById(body, id)
    if body == nil or id == nil then return nil end
    local item = BridgeGunRules.findItemById(body, id)
    if item == nil then return nil end
    local container = nil
    pcall(function() container = item:getContainer() end)
    if container == nil then return nil end
    local count = BridgeGunRules.itemCount(item)
    if count > 1 then
        BridgeGunRules.setItemCount(item, count - 1)
        if BridgeGunRules.canSync(container) then
            pcall(function() sendItemStats(item) end)
        end
    else
        container:Remove(item)
        if BridgeGunRules.canSync(container) then
            pcall(function() sendRemoveItemFromContainer(container, item) end)
        end
    end
    return item
end


function BridgeGunRules.takeLooseRounds(body, desc, need)
    local want = math.floor(tonumber(need) or 0)
    if want <= 0 then return 0 end
    local rounds, taken = BridgeGunRules.findLooseRounds(body, desc, want)
    local done = 0
    for _, entry in ipairs(rounds) do
        if done >= want then break end
        local n = math.min(entry.count, want - done)
        local container = nil
        pcall(function() container = entry.item:getContainer() end)
        local sync = BridgeGunRules.canSync(container)
        if n >= entry.count then
            BridgeGunRules.removeItem(entry.item)
            if sync then
                pcall(function() sendRemoveItemFromContainer(container, entry.item) end)
            end
        else
            BridgeGunRules.setItemCount(entry.item, entry.count - n)
            if sync then
                pcall(function() sendItemStats(entry.item) end)
            end
        end
        done = done + n
    end
    return done
end


function BridgeGunRules.findEmptyMagazine(body, desc)
    if body == nil or type(desc) ~= "table" or desc.magazineType == nil then return nil end
    for _, item in ipairs(BridgeGunRules.itemsOf(body)) do
        local full, rounds = nil, 0
        pcall(function() full = item:getFullType() end)
        if full == desc.magazineType then
            rounds = BridgeGunRules.roundsOf(item)
            if rounds <= 0 then return item end
        end
    end
    return nil
end


function BridgeGunRules.findPartialMagazine(body, desc)
    if body == nil or type(desc) ~= "table" or desc.magazineType == nil then return nil end
    local maxAmmo = tonumber(desc.maxAmmo) or 0
    if maxAmmo <= 0 then return nil end
    local best, bestRounds = nil, nil
    for _, item in ipairs(BridgeGunRules.itemsOf(body)) do
        local full = nil
        pcall(function() full = item:getFullType() end)
        if full == desc.magazineType then
            local rounds = BridgeGunRules.roundsOf(item)
            if rounds < maxAmmo and (best == nil or rounds < bestRounds) then
                best, bestRounds = item, rounds
            end
        end
    end
    return best
end


function BridgeGunRules.makeEmptyMagazine(body, desc, prefer)
    if type(desc) ~= "table" or desc.magazineType == nil then return nil end
    local magazine = nil
    pcall(function() magazine = instanceItem(desc.magazineType) end)
    if magazine == nil then return nil end
    BridgeGunRules.setRounds(magazine, 0, false)
    if not BridgeGunRules.placeItem(body, magazine, prefer) then return nil end
    return magazine
end


function BridgeGunRules.unloadMagazine(body, desc)
    local magazine = BridgeGunRules.makeEmptyMagazine(body, desc)
    if magazine ~= nil then BridgeGunRules.setRounds(magazine, 0, false) end
    return magazine
end


function BridgeGunRules.stashMagazine(body, desc, rounds, prefer)
    local n = math.max(0, math.floor(tonumber(rounds) or 0))
    if n <= 0 then return BridgeGunRules.makeEmptyMagazine(body, desc, prefer) end
    if type(desc) ~= "table" or desc.magazineType == nil then return nil end
    local magazine = nil
    pcall(function() magazine = instanceItem(desc.magazineType) end)
    if magazine == nil then return nil end
    BridgeGunRules.setRounds(magazine, n, false)
    if not BridgeGunRules.placeItem(body, magazine, prefer) then return nil end
    return magazine
end


function BridgeGunRules.ejectMagazine(body, desc, rounds, prefer)
    if body == nil or type(desc) ~= "table" or desc.magazineType == nil then return nil end
    local n = math.max(0, math.floor(tonumber(rounds) or 0))
    local magazine = nil
    pcall(function() magazine = instanceItem(desc.magazineType) end)
    if magazine == nil then return nil end
    BridgeGunRules.setRounds(magazine, n, false)
    if not BridgeGunRules.placeItem(body, magazine, prefer) then return nil end
    return magazine
end


function BridgeGunRules.insertMagazine(body, weapon, magazine, desc)
    if weapon == nil or magazine == nil then return 0 end
    local rounds = BridgeGunRules.roundsOf(magazine)
    BridgeGunRules.removeItem(magazine)
    BridgeGunRules.setRounds(weapon, rounds, true)
    return rounds
end


function BridgeGunRules.hasReloadSource(body, desc)
    if body == nil or type(desc) ~= "table" then return false end
    if desc.magazineType ~= nil then
        return BridgeGunRules.findLoadedMagazine(body, desc) ~= nil
    end
    local _, total = BridgeGunRules.findLooseRounds(body, desc, 1)
    return total > 0
end


local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGunRules] " .. tostring(text)) end
end

log("loaded")
