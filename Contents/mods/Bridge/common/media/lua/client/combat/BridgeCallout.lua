BridgeCallout = BridgeCallout or {}

BridgeCallout.SEC = 60

BridgeCallout.HORDE_COUNT = 10
BridgeCallout.SPOT_DIST = 15
BridgeCallout.SPOT_MIN_DIST = 8
BridgeCallout.LULL_DIST = 8
BridgeCallout.MELEE_DIST = 6
BridgeCallout.COMBAT_GRACE = 4
BridgeCallout.FINISH_HP = 0.5
BridgeCallout.PLAYER_HIT_DROP = 1.0

BridgeCallout.SWARM_RADIUS = 2
BridgeCallout.SWARM_PLAYER = 6
BridgeCallout.FIGHT_SCAN_SEC = 0.25
BridgeCallout.FIGHT_LONG_SEC = 45
BridgeCallout.FIGHT_HEAVY_PEAK = 6
BridgeCallout.FIGHT_AFTERMATH_SEC = 10
BridgeCallout.FIGHT_AFTERMATH_PEAK = 4
BridgeCallout.AFTERMATH_DELAY_SEC = 30
BridgeCallout.TENSE_DELAY_SEC = 60
BridgeCallout.REMARK_SLOT_CD = 600
BridgeCallout.REMARK_GAP = 4
BridgeCallout.WEAPON_LOW = 0.15
BridgeCallout.LASTFIGHT_MIN_HOURS = 1
BridgeCallout.LASTFIGHT_MAX_HOURS = 24
BridgeCallout.AMMO_NEAR = 12
BridgeCallout.SCAN_FIGHT = 15
BridgeCallout.SCAN_IDLE = 30
BridgeCallout.SCAN_QUIET = 60

BridgeCallout.PLACE_GAP = 60 * 60
BridgeCallout.PLACE_DWELL = 3 * 60
BridgeCallout.PLACE_NEAR = 12

BridgeCallout.HOME_EVENT = "EvHomeReturn"
BridgeCallout.HOME_NEAR = 12
BridgeCallout.HOME_WITH = 12
BridgeCallout.HOME_HOURS = 1.0
BridgeCallout.HOME_GAP = 60 * 60

BridgeCallout.MARK_EVENT = "EvMarkStorage"
BridgeCallout.UNMARK_EVENT = "EvUnmarkStorage"
BridgeCallout.MARK_GAP = 4

BridgeCallout.SWING_COMBAT_QUIET = 60
BridgeCallout.SWING_ZOMBIE_DIST = 10
BridgeCallout.SWING_Z_TOL = 0.8
BridgeCallout.SWING_RANGE_TOL = 0.3

BridgeCallout.CITY_MIN_AWAY = 24
BridgeCallout.CITY_DWELL    = 20 * BridgeCallout.SEC
BridgeCallout.CITY_GAP      = 30 * BridgeCallout.SEC
BridgeCallout.CITY_NEAR     = 12
BridgeCallout.CITY_BOXES = {
    { id = "muldraugh",      label = "Muldraugh",      minX = 9631,  maxX = 12731, minY = 8175,  maxY = 11275 },
    { id = "west_point",     label = "West Point",     minX = 10181, maxX = 12981, minY = 5516,  maxY = 8316  },
    { id = "riverside",      label = "Riverside",      minX = 4950,  maxX = 7650,  minY = 4318,  maxY = 7018  },
    { id = "rosewood",       label = "Rosewood",       minX = 7246,  maxX = 9646,  minY = 10356, maxY = 12756 },
    { id = "march_ridge",    label = "March Ridge",    minX = 8721,  maxX = 11121, minY = 11403, maxY = 13803 },
    { id = "valley_station", label = "Valley Station", minX = 11656, maxX = 14456, minY = 4631,  maxY = 7431  },
    { id = "louisville",     label = "Louisville",     minX = 11700, maxX = 14699, minY = 900,   maxY = 3899  },
    { id = "brandenburg",    label = "Brandenburg",    minX = 1064,  maxX = 3564,  minY = 5003,  maxY = 7503  },
    { id = "irvington",      label = "Irvington",      minX = 1479,  maxX = 3979,  minY = 12547, maxY = 15047 },
    { id = "ekron",          label = "Ekron",          minX = -30,   maxX = 2070,  minY = 8788,  maxY = 10888 },
    { id = "echo_creek",     label = "Echo Creek",     minX = 3185,  maxX = 5285,  minY = 10019, maxY = 12119 },
    { id = "fallas_lake",    label = "Fallas Lake",    minX = 6298,  maxX = 8398,  minY = 7321,  maxY = 9421  },
}

BridgeCallout.lastAny = -99999
BridgeCallout.deferred = {}
BridgeCallout.fightingAt = -99999
BridgeCallout.wasFighting = false
BridgeCallout.pendingKill = nil
BridgeCallout.lastHealth = nil
BridgeCallout.finisherTarget = nil
BridgeCallout.info = "none"
BridgeCallout.lastCombatAt = -99999
BridgeCallout.attackPrev = false

BridgeCallout.drawnPrev = false
BridgeCallout.scanAt = -99999
BridgeCallout.dueAt = -99999
BridgeCallout.hordeAt = -99999
BridgeCallout.hordeRaw = 0
BridgeCallout.hordeSeen = 0
BridgeCallout.recordOn = false
BridgeCallout.fightTime = 0
BridgeCallout.fightPeak = 0
BridgeCallout.fightGun = false
BridgeCallout.fightHit = false
BridgeCallout.fightWritten = false
BridgeCallout.aftermathAt = nil
BridgeCallout.tenseAt = nil
BridgeCallout.redWindedSaid = false
BridgeCallout.weaponLowItem = nil
BridgeCallout.weaponLowSaid = false

BridgeCallout.placeKey = nil
BridgeCallout.placeSince = 0
BridgeCallout.placeFired = false
BridgeCallout.placeLastAt = -99999
BridgeCallout.visitedSentAt = -9999
BridgeCallout.visitedSign = nil

BridgeCallout.homeHours = 0
BridgeCallout.homeAge = nil
BridgeCallout.homeFired = false
BridgeCallout.homeSuppress = false
BridgeCallout.homeInfo = "none"

BridgeCallout.cityKey = nil
BridgeCallout.citySince = 0
BridgeCallout.cityFired = false
BridgeCallout.cityLastAt = -99999
BridgeCallout.cityAway = nil
BridgeCallout.citiesSign = nil
BridgeCallout.citiesSentAt = -9999

BridgeCallout.AMBIENT = { "EvTaunt" }


BridgeCallout.ENABLED = 1


BridgeCallout.DEBUG = 0


BridgeCallout.SAY = {
    EvEngage     = 1,
    EvKill       = 1,
    EvHorde4     = 1,
    EvHorde8     = 1,
    EvHorde16    = 1,
    EvHorde32    = 1,
    EvBreakOff   = 1,
    EvSpot       = 1,
    EvLull       = 1,
    EvPlayerHit  = 1,
    EvFinisher   = 1,
    EvFinisherGun = 1,
    EvLostTarget = 1,
    EvTaunt      = 1,
    EvAimClear   = 1,
    EvAimOnMe    = 1,
    EvTorchLow   = 1,
    EvSwingAtMe  = 1,
    EvReload     = 1,
    EvReloadLoose = 1,
    EvOutOfAmmo  = 1,
    EvLowAmmo    = 1,
    EvLineOfFire = 1,
    EvGunKill    = 1,
    EvClimbUp    = 1,
    EvClimbDown  = 1,
    EvGunEngage  = 1,
    EvSwitchToMelee = 1,
    EvSwitchToGun = 1,
    EvNoShot     = 1,
    EvReloadCancel = 1,
    EvGunMultiKill = 1,
    EvUnarmed    = 1,
    EvCantReach  = 1,
    EvInTheWay   = 1,
    EvShove      = 1,
    EvRedWinded  = 1,
    EvNoSpare    = 1,
    EvMagLow     = 1,
    EvNoRoom     = 1,
    EvRedWeaponLow = 1,
    EvSwarmed    = 1,
    EvStillOnUs  = 1,
    EvAfterFightTired = 1,
    EvAfterFightGun = 1,
    EvAfterFightHard = 1,
    EvAfterFightLong = 1,
}


BridgeCallout.REPEAT_GAP = 8
BridgeCallout.HORDE_CD = 60
BridgeCallout.HORDE_SCAN_EVERY = 60

BridgeCallout.MILESTONES = { [1] = true, [5] = true, [10] = true, [25] = true, [50] = true,
    [100] = true, [250] = true, [500] = true, [1000] = true }
BridgeCallout.MILESTONE_CAP = 1000
BridgeCallout.MILESTONE_AFTER = 3


BridgeCallout.EVENTS = {
    EvEngage     = { slot = "Engage",     cooldown = 25 },
    EvKill       = { slot = "Kill",       cooldown = 20 },
    EvHorde4     = { slot = "Horde",      cooldown = BridgeCallout.HORDE_CD },
    EvHorde8     = { slot = "Horde",      cooldown = BridgeCallout.HORDE_CD },
    EvHorde16    = { slot = "Horde",      cooldown = BridgeCallout.HORDE_CD },
    EvHorde32    = { slot = "Horde",      cooldown = BridgeCallout.HORDE_CD },
    EvBreakOff   = { slot = "BreakOff",   cooldown = 30 },
    EvSpot       = { slot = "Spot",       cooldown = 120 },
    EvLull       = { slot = "Lull",       cooldown = 150 },
    EvPlayerHit  = { slot = "PlayerHit",  cooldown = 30 },
    EvFinisher   = { slot = "Finisher",   cooldown = 30 },
    EvFinisherGun = { slot = "Finisher",  cooldown = 30 },
    EvLostTarget = { slot = "LostTarget", cooldown = 60 },
    EvTaunt      = { slot = "Taunt",      cooldown = 150 },
    EvAimClear   = { slot = "AimClear",   cooldown = 15 },
    EvAimOnMe    = { slot = "AimOnMe",    cooldown = 15 },
    EvTorchLow   = { slot = "TorchLow",   cooldown = 300 },
    EvSwingAtMe  = { slot = "SwingAtMe",  cooldown = 30 },
    EvReload     = { slot = "Reload",     cooldown = 12 },
    EvReloadLoose = { slot = "Reload",    cooldown = 12 },
    EvOutOfAmmo  = { slot = "OutOfAmmo",  cooldown = 20 },
    EvLowAmmo    = { slot = "LowAmmo",    cooldown = 30 },
    EvLineOfFire = { slot = "LineOfFire", cooldown = 15 },
    EvGunKill    = { slot = "GunKill",    cooldown = 20 },
    EvClimbUp    = { slot = "Climb",      cooldown = 60 },
    EvClimbDown  = { slot = "Climb",      cooldown = 60 },
    EvGunEngage  = { slot = "GunEngage",  cooldown = 30 },
    EvSwitchToMelee = { slot = "Switch",  cooldown = 20 },
    EvSwitchToGun = { slot = "Switch",    cooldown = 20 },
    EvNoShot     = { slot = "NoShot",     cooldown = 20 },
    EvReloadCancel = { slot = "ReloadCancel", cooldown = 20 },
    EvGunMultiKill = { slot = "GunKill",  cooldown = 20 },
    EvUnarmed    = { slot = "Unarmed",    cooldown = 300 },
    EvCantReach  = { slot = "CantReach",  cooldown = 60 },
    EvInTheWay   = { slot = "InWay",      cooldown = 30 },
    EvShove      = { slot = "Shove",      cooldown = 20 },
    EvRedWinded  = { slot = "RedWinded",  cooldown = 120 },
    EvNoSpare    = { slot = "NoSpare",    cooldown = 300 },
    EvMagLow     = { slot = "MagLow",     cooldown = 20 },
    EvNoRoom     = { slot = "NoRoom",     cooldown = 60 },
    EvRedWeaponLow = { slot = "RedWeaponLow", cooldown = 600 },
    EvSwarmed    = { slot = "Swarmed",    cooldown = 120 },
    EvStillOnUs  = { slot = "AfterFight", cooldown = 60 },
    EvAfterFightTired = { slot = "AfterFight", cooldown = 120 },
    EvAfterFightGun = { slot = "AfterFight", cooldown = 120 },
    EvAfterFightHard = { slot = "AfterFight", cooldown = 120 },
    EvAfterFightLong = { slot = "AfterFight", cooldown = 120 },
}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeCallout] " .. tostring(text)) end end

local function dlog(text)
    if BridgeCallout.DEBUG == 1 then log(text) end
end

local function vlog(text)
    if Bridge.verbose then log(text) end
end

local function isBodyZ(z)
    local ok, v = pcall(function() return z:getVariableBoolean("NotAloneBody") end)
    return ok and v
end

local function remoteZ(z)
    if not isClient() then return false end
    local ok, v = pcall(function() return z:isRemoteZombie() end)
    return ok and v
end

local function deadZ(z)
    local dead = false
    pcall(function() dead = (not z:isAlive()) or z:isDead() or z:getHealth() <= 0 end)
    return dead == true
end

local function attackSignals(red)
    local h2h, atk = false, false
    local probe = nil
    pcall(function() probe = red.isDoHandToHandAttack end)
    if probe ~= nil then pcall(function() h2h = red:isDoHandToHandAttack() == true end) end
    pcall(function() atk = red:isAttacking() == true end)
    return h2h, atk
end

local function threatZ(z, body, inclRemote)
    local alive = false
    pcall(function() alive = z:isAlive() and z:getHealth() > 0 end)
    return z ~= nil and z ~= body and alive and not isBodyZ(z)
        and (inclRemote == true or not remoteZ(z)) and not BridgeData.harmless(z)
end

local function target()
    local t = nil
    pcall(function()
        if BridgeGunfight ~= nil and BridgeGunfight.target ~= nil then
            t = BridgeGunfight.target
            return
        end
        if BridgeFight ~= nil then t = BridgeFight.target end
    end)
    return t
end

local function gunThreat()
    local assigned = false
    pcall(function() assigned = BridgeGunfight ~= nil and BridgeGunfight.assignedId ~= nil end)
    if not assigned then return false end
    local active = false
    pcall(function() active = BridgeFight ~= nil and BridgeFight.state == "gun" end)
    if active then return true end
    local now = Bridge.time or 0
    if BridgeCallout.gunThreatAt == now then return BridgeCallout.gunThreatValue == true end
    local body, red = Bridge.body, nil
    pcall(function() red = BridgeData.owner() end)
    if body == nil and red == nil then
        BridgeCallout.gunThreatAt, BridgeCallout.gunThreatValue = now, false
        return false
    end
    local near = false
    local frame = nil
    pcall(function() if BridgeScan ~= nil then frame = BridgeScan.frame(body, red) end end)
    if frame ~= nil then
        local entries = frame.entries or {}
        for i = 1, #entries do
            local e = entries[i]
            if e.alive and not e.comp and not e.harm
                and math.abs(e.zc) < 1 and (e.dc <= 15.1 or e.dp <= 15.1) then
                near = true
                break
            end
        end
    else
        pcall(function()
            local bx, by, rx, ry = nil, nil, nil, nil
            if body ~= nil then bx, by = body:getX(), body:getY() end
            if red ~= nil then rx, ry = red:getX(), red:getY() end
            local wx, wy = bx or rx, by or ry
            local list = nil
            if BridgeZS ~= nil and wx ~= nil and wy ~= nil then
                list = BridgeZS.nearUnion(wx, wy, rx or wx, ry or wy, 15.1)
            end
            if list == nil then list = getCell():getZombieList() end
            for i = 0, list:size() - 1 do
                local z = list:get(i)
                if z ~= nil and z ~= body and z ~= red and not isBodyZ(z) and not BridgeData.harmless(z) then
                    local alive = false
                    pcall(function() alive = z:isAlive() and z:getHealth() > 0 end)
                    if alive then
                        if body ~= nil then
                            local dx, dy = z:getX() - body:getX(), z:getY() - body:getY()
                            if dx * dx + dy * dy <= 225 and math.abs(z:getZ() - body:getZ()) < 1 then near = true return end
                        end
                        if red ~= nil then
                            local dx, dy = z:getX() - red:getX(), z:getY() - red:getY()
                            if dx * dx + dy * dy <= 225 and math.abs(z:getZ() - red:getZ()) < 1 then near = true return end
                        end
                    end
                end
            end
        end)
    end
    BridgeCallout.gunThreatAt, BridgeCallout.gunThreatValue = now, near
    return near
end

local function nearTarget(body)
    local t = target()
    if t == nil then return false end
    local d = 99
    pcall(function() d = math.sqrt((t:getX() - body:getX()) ^ 2 + (t:getY() - body:getY()) ^ 2) end)
    return d <= BridgeCallout.MELEE_DIST
end

local DEFER = { EvKill = true }


local attempt

local function trySay(event) return attempt(event, false) end

function BridgeCallout.defer(event)
    local q = BridgeCallout.deferred
    for _, item in ipairs(q) do if item == event then return false end end
    if #q >= 4 then table.remove(q, 1) end
    q[#q + 1] = event
    dlog("deferred " .. event)
    return true
end

local function carQuiet()
    local red = nil
    pcall(function() red = BridgeData.owner() end)
    if red ~= nil then
        local v = nil
        pcall(function() v = red:getVehicle() end)
        if v ~= nil then return true end
    end
    local inside = false
    pcall(function() inside = BridgeCar ~= nil and (BridgeCar.isInside() or (red ~= nil and BridgeCar.withRed(red))) end)
    return inside == true
end

local function clearOneShots()
    BridgeCallout.aftermathAt = nil
    BridgeCallout.tenseAt = nil
end

local function ammoThreat()
    if BridgeCallout.ENABLED == 0 then return false end
    if not Bridge.alive() then return false end
    if Bridge.mode == "rest" then return false end
    if BridgeFastForward ~= nil and BridgeFastForward.active() then return false end
    if carQuiet() then return false end
    local usable = false
    pcall(function()
        usable = BridgeGunfight ~= nil and type(BridgeGunfight.hasGun) == "function"
            and BridgeGunfight.hasGun() == true
    end)
    if not usable then return false end
    local active = false
    pcall(function() active = BridgeFight ~= nil and BridgeFight.state == "gun" end)
    if active then return true end
    local body, red = Bridge.body, nil
    pcall(function() red = BridgeData.owner() end)
    if body == nil or red == nil then return false end
    local asleep = false
    pcall(function() asleep = red:isAsleep() == true end)
    if asleep then return false end
    local near = false
    pcall(function()
        local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
        near = dx * dx + dy * dy <= BridgeCallout.AMMO_NEAR * BridgeCallout.AMMO_NEAR
            and math.abs(red:getZ() - body:getZ()) < 1
    end)
    return near
end

local function dropCarLines()
    BridgeCallout.deferred = {}
    BridgeCallout.pendingKill = nil
    BridgeCallout.milestoneDue = nil
    BridgeCallout.wasFighting = false
    BridgeCallout.fightingAt = -99999
    BridgeCallout.finisherTarget = nil
    BridgeCallout.lastHealth = nil
    clearOneShots()
end


attempt = function(event, priority)
    if BridgeCallout.ENABLED == 0 then return false end
    if priority and carQuiet() then return false end
    local e = BridgeCallout.EVENTS[event]
    if e == nil then return false end
    if BridgeCallout.SAY[event] == 0 then return false end
    local gap = BridgeCallout.REPEAT_GAP * BridgeCallout.SEC
    if Bridge.time - BridgeCallout.lastAny < gap then
        if priority then BridgeCallout.info = "blocked " .. event end
        return false
    end
    local said = false
    pcall(function() said = BridgeMoments.say(event, e.cooldown * BridgeCallout.SEC, true, e.slot) == true end)
    if said then
        BridgeCallout.lastAny = Bridge.time
        if priority then BridgeCallout.deferred = {} end
        BridgeCallout.info = event
        log(event)
        if priority then
            dlog("said priority " .. event .. " (slot " .. tostring(e.slot) .. ")")
        else
            local grp = "?"
            pcall(function() grp = BridgeMoments.group() end)
            dlog("said " .. event .. " (slot " .. tostring(e.slot) .. ", " .. tostring(grp)
                .. ", cd " .. tostring(e.cooldown) .. "s)")
        end
    else
        BridgeCallout.info = "blocked " .. event
    end
    return said
end


local function say(event)
    if BridgeMeet ~= nil and type(BridgeMeet.quietCombat) == "function" and BridgeMeet.quietCombat() then return false end
    if carQuiet() then dropCarLines() return false end
    if BridgeCallout.ENABLED == 0 then return false end
    if trySay(event) then return true end
    if DEFER[event] then BridgeCallout.defer(event) end
    return false
end

local function flush()
    local q = BridgeCallout.deferred
    local i = 1
    while i <= #q do
        local ev = q[i]
        if trySay(ev) then
            table.remove(q, i)
            dlog("said deferred " .. ev)
            return true
        end
        i = i + 1
    end
    return false
end

local scanFacts = { near8 = 0, spot = false, anyThreatInSwing = false }

local function scanWorld(body, red, wantClear)
    local facts = scanFacts
    facts.near8 = 0
    facts.spot = false
    facts.anyThreatInSwing = false

    local S = BridgeCallout.SAY
    local wantNear = S.EvLull ~= 0 or S.EvStillOnUs ~= 0
    local wantSpot = S.EvSpot ~= 0
    local wantBody = wantNear
    local wantRed = wantSpot
    if not (wantBody or wantRed or wantClear) then
        return facts
    end

    local near2 = 8 * 8
    local spotMin2 = BridgeCallout.SPOT_MIN_DIST * BridgeCallout.SPOT_MIN_DIST
    local spot2 = BridgeCallout.SPOT_DIST * BridgeCallout.SPOT_DIST
    local swing2 = BridgeCallout.SWING_ZOMBIE_DIST * BridgeCallout.SWING_ZOMBIE_DIST

    local t = wantSpot and target() or nil

    local bodyx, bodyy, bodyz = 0, 0, 0
    local redx, redy, redz = 0, 0, 0
    pcall(function() bodyx, bodyy, bodyz = body:getX(), body:getY(), body:getZ() end)
    pcall(function() redx, redy, redz = red:getX(), red:getY(), red:getZ() end)

    local frame = nil
    pcall(function() if BridgeScan ~= nil then frame = BridgeScan.frame(body, red) end end)
    if frame ~= nil then
        local entries = frame.entries or {}
        for i = 1, #entries do
            local e = entries[i]
            if e.alive and not e.comp and not e.harm then
                local relevant = false
                if wantNear and math.abs(e.zp) < 0.8 and e.dp2 < near2 then relevant = true end
                if not relevant and wantRed and math.abs(e.zc) < 1 and e.dc2 < spot2 then relevant = true end
                local clearRel = wantClear and math.abs(e.zc) < 1 and e.dc2 < swing2
                if relevant or clearRel then
                    if not e.remote then
                        if wantNear and math.abs(e.zp) < 0.8 and e.dp2 < near2 then
                            facts.near8 = facts.near8 + 1
                        end
                        if wantSpot and not facts.spot and e.z ~= t
                            and e.dc2 > spotMin2 and e.dc2 < spot2 and e.seenR then
                            facts.spot = true
                        end
                    end
                    if clearRel and not facts.anyThreatInSwing and e.seenP then
                        facts.anyThreatInSwing = true
                    end
                end
            end
        end
        return facts
    end

    pcall(function()
        local list = nil
        if BridgeZS ~= nil then list = BridgeZS.nearUnion(bodyx, bodyy, redx, redy, 15.5, { tag = "callout.scan" }) end
        if list == nil then list = getCell():getZombieList() end
        local n = list:size()
        for i = 0, n - 1 do
            local z = list:get(i)
            if z ~= nil then
                local zx, zy, zz = nil, nil, nil
                pcall(function() zx, zy, zz = z:getX(), z:getY(), z:getZ() end)
                if zx ~= nil then
                    local bx, by = zx - bodyx, zy - bodyy
                    local bd2 = bx * bx + by * by
                    local rx, ry = zx - redx, zy - redy
                    local rd2 = rx * rx + ry * ry
                    local dzBody = zz - bodyz
                    local dzRed = zz - redz
                    local inRedBand = math.abs(dzRed) < 1

                    local relevant = false
                    if wantNear and math.abs(dzBody) < 0.8 and bd2 < near2 then
                        relevant = true
                    end
                    if not relevant and wantRed and inRedBand and rd2 < spot2 then
                        relevant = true
                    end
                    local clearRel = wantClear and inRedBand and rd2 < swing2

                    if relevant or clearRel then
                        if threatZ(z, body, true) then
                            local isRemote = remoteZ(z)
                            if relevant and not isRemote then
                                if wantNear and math.abs(dzBody) < 0.8 and bd2 < near2 then
                                    facts.near8 = facts.near8 + 1
                                end
                                if inRedBand then
                                    if wantSpot and not facts.spot and z ~= t
                                        and rd2 > spotMin2 and rd2 < spot2 then
                                        local seen = false
                                        pcall(function() seen = BridgeFight.visible(z, red) end)
                                        if seen then facts.spot = true end
                                    end
                                end
                            end
                            if clearRel and not facts.anyThreatInSwing then
                                local seen = false
                                pcall(function() seen = red:CanSee(z) end)
                                if seen then facts.anyThreatInSwing = true end
                            end
                        end
                    end
                end
            end
        end
    end)
    return facts
end

local function noZombiesInSight(red, body, dist)
    local clear = true
    local d2 = dist * dist
    pcall(function()
        local list = getCell():getZombieList()
        local n = list:size()
        for i = 0, n - 1 do
            local z = nil
            pcall(function() z = list:get(i) end)
            if z ~= nil and threatZ(z, body, true) then
                local dx, dy = z:getX() - red:getX(), z:getY() - red:getY()
                if dx * dx + dy * dy < d2 and math.abs(z:getZ() - red:getZ()) < 1 then
                    local seen = false
                    pcall(function() seen = red:CanSee(z) end)
                    if seen then clear = false return end
                end
            end
        end
    end)
    return clear
end

local function swingingAtHer(red, body, attackingNow, prevAttack)
    if not (attackingNow and not prevAttack) then return false end
    local item = nil
    pcall(function() item = red:getPrimaryHandItem() end)
    if item == nil then pcall(function() item = red:getSecondaryHandItem() end) end
    if item == nil or BridgeWeapon == nil or BridgeWeapon.isMelee == nil then return false end
    if not BridgeWeapon.isMelee(item) then return false end
    local ok = false
    pcall(function()
        if math.abs(body:getZ() - red:getZ()) > BridgeCallout.SWING_Z_TOL then return end
        local fx, fy = 0, 0
        pcall(function()
            local f = red:getForwardDirection()
            fx, fy = f:getX(), f:getY()
        end)
        local fl = math.sqrt(fx * fx + fy * fy)
        if fl < 0.01 then return end
        fx, fy = fx / fl, fy / fl
        local dx, dy = body:getX() - red:getX(), body:getY() - red:getY()
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= 0.01 then return end
        local range, minA = 2.0, 0
        pcall(function() range = item:getMaxRange() end)
        pcall(function() minA = item:getMinAngle() end)
        if type(range) ~= "number" then range = 2.0 end
        if type(minA) ~= "number" then minA = 0 end
        if d > range + BridgeCallout.SWING_RANGE_TOL then return end
        if (fx * dx + fy * dy) / d < minA then return end
        local seen = false
        pcall(function() seen = red:CanSee(body) end)
        if not seen then return end
        ok = true
    end)
    return ok
end

local function scanFinisher()
    local t = target()
    if t == nil then return nil end
    if t == BridgeCallout.finisherTarget then return nil end
    local hp, low = 1, false
    pcall(function() hp = t:getHealth() low = hp <= BridgeCallout.FINISH_HP end)
    if low then BridgeCallout.finisherTarget = t return t end
    return nil
end

function BridgeCallout.engage(z)
    if z == nil then return false end
    return say("EvEngage")
end

function BridgeCallout.kill(z)
    if BridgeCallout.ENABLED == 0 then return false end
    if carQuiet() then dropCarLines() return false end
    if z == nil then return false end
    if deadZ(z) then return say("EvKill") end
    BridgeCallout.pendingKill = z
    return false
end

function BridgeCallout.forceMilestone(n)
    n = tonumber(n)
    if n == nil or n ~= n then return false end
    n = math.floor(n)
    local key = "IGUI_NotAlone_KillMilestone_" .. n
    local text = nil
    pcall(function() text = BridgeSpeech.getOrNull(key) end)
    if type(text) ~= "string" or text == "" or text == key then return false end
    if Bridge.quiet() then
        pcall(function() Bridge.bridgeEvent("KillMilestone" .. n, text) end)
    else
        Bridge.speakText(text)
    end
    BridgeCallout.lastAny = Bridge.time
    BridgeCallout.deferred = {}
    BridgeCallout.milestoneDue = nil
    if BridgeMoments ~= nil then
        BridgeMoments.cool["KillMilestone"] = Bridge.time
        BridgeMoments.lastLine = Bridge.time
    end
    BridgeCallout.info = "KillMilestone" .. tostring(n)
    log("milestone " .. tostring(n))
    return true
end

function BridgeCallout.milestone(n)
    n = tonumber(n)
    if n == nil or n ~= n then return false end
    n = math.floor(n)
    if n > BridgeCallout.MILESTONE_CAP or not BridgeCallout.MILESTONES[n] then return false end
    local wait = BridgeCallout.MILESTONE_AFTER * BridgeCallout.SEC
    local since = Bridge.time - BridgeCallout.lastAny
    if since < wait then
        BridgeCallout.milestoneDue = { n = n, at = Bridge.time + (wait - since) }
        return true
    end
    return BridgeCallout.forceMilestone(n)
end

function BridgeCallout.breakOff()
    return say("EvBreakOff")
end

function BridgeCallout.lostTarget()
    return say("EvLostTarget")
end

function BridgeCallout.reloading(hasMag)
    if not ammoThreat() then return false end
    if hasMag == false then return say("EvReloadLoose") end
    return say("EvReload")
end

function BridgeCallout.climb(direction)
    if direction == "down" then return say("EvClimbDown") end
    return say("EvClimbUp")
end

function BridgeCallout.outOfAmmo()
    if not ammoThreat() then return false end
    return say("EvOutOfAmmo")
end

function BridgeCallout.lowAmmo()
    if not ammoThreat() then return false end
    return say("EvLowAmmo")
end

function BridgeCallout.lowMag()
    if not ammoThreat() then return false end
    return say("EvMagLow")
end

function BridgeCallout.noSpare()
    if not ammoThreat() then return false end
    return say("EvNoSpare")
end

function BridgeCallout.reloadCancel()
    if not gunThreat() then return false end
    return say("EvReloadCancel")
end

function BridgeCallout.gunEngage()
    return say("EvGunEngage")
end

function BridgeCallout.noShot()
    return say("EvNoShot")
end

function BridgeCallout.gunMultiKill()
    return say("EvGunMultiKill")
end

function BridgeCallout.switchToMelee()
    return say("EvSwitchToMelee")
end

function BridgeCallout.switchToGun()
    return say("EvSwitchToGun")
end

function BridgeCallout.unarmed()
    return say("EvUnarmed")
end

function BridgeCallout.cantReach()
    return say("EvCantReach")
end

function BridgeCallout.inTheWay()
    return say("EvInTheWay")
end

function BridgeCallout.shove()
    return say("EvShove")
end

function BridgeCallout.noRoom()
    return say("EvNoRoom")
end

function BridgeCallout.redWinded()
    return say("EvRedWinded")
end

function BridgeCallout.redWeaponLow()
    return say("EvRedWeaponLow")
end

function BridgeCallout.swarmed()
    return say("EvSwarmed")
end

function BridgeCallout.lineOfFire()
    local active = false
    pcall(function()
        active = BridgeGunfight ~= nil and BridgeGunfight.assignedId ~= nil
            and BridgeGunfight.drawn == true and BridgeGunfight.reloadStage == nil
            and (tonumber(BridgeGunfight.rounds) or 0) > 0
    end)
    if not active then return false end
    if not gunThreat() then return false end
    return say("EvLineOfFire")
end

function BridgeCallout.gunKill(z)
    if z == nil or not deadZ(z) then return false end
    if not gunThreat() then return false end
    return say("EvGunKill")
end

function BridgeCallout.sayPriority(event)
    return attempt(event, true)
end

function BridgeCallout.aimClear(onMe)
    if onMe then return BridgeCallout.sayPriority("EvAimOnMe") end
    return BridgeCallout.sayPriority("EvAimClear")
end

function BridgeCallout.swingAtMe()
    return say("EvSwingAtMe")
end

function BridgeCallout.horde(n)
    if BridgeHorde == nil then return false end
    local tier = BridgeHorde.tier(n)
    if tier == nil then return false end
    return say("EvHorde" .. tier)
end

function BridgeCallout.spot()
    return say("EvSpot")
end

function BridgeCallout.lull()
    return say("EvLull")
end


BridgeCallout.PLACE_POOL = {
    Fossoil = "Place_GasStation", Gas2Go = "Place_GasStation", ThunderGas = "Place_GasStation",
    McCoys = "Place_GasStation", CarRepair = "Place_CarRepair", NolansUsedCars = "Place_CarLot",

    Spiffo = "Place_Spiffo", Spiffos = "Place_Spiffo",
    PizzaWhirled = "Place_FastFood", Dinner = "Place_FastFood", PileOCrepe = "Place_FastFood",
    Jays = "Place_Store", Butcher = "Place_Butcher",
    CoffeeShop = "Place_Cafe", CoffeShop = "Place_Cafe", Cafe = "Place_Cafe",
    SeaHorse = "Place_Restaurant", Seahorse = "Place_Restaurant", SeaHorses = "Place_Restaurant",
    Restaurant = "Place_Restaurant", FancyRestaurant = "Place_Restaurant", Bar = "Place_Bar", Smokeys = "Place_Bar",
    Nightclub = "Place_Nightclub", Stripclub = "Place_Stripclub",

    Gigamart = "Place_Supermarket", VariousFoodMarket = "Place_Supermarket", Pharmacist = "Place_Pharmacy",
    FarmingStore = "Place_FarmingStore", Bank = "Place_Bank", KnoxBank = "Place_Bank",
    Bowling = "Place_Bowling", Theatre = "Place_Theatre", LaserTag = "Place_Leisure",
    Spa = "Place_Spa", HotelRich = "Place_Hotel", FancyHotel = "Place_Hotel",
    SunstarMotel = "Place_Hotel", WaitesMotel = "Place_Hotel", CountryClub = "Place_Leisure",
    Golf = "Place_Leisure", Tennis = "Place_Leisure", SwimmingPool = "Place_Leisure",
    Boxing = "Place_Leisure", Athletic = "Place_Leisure", Athletics = "Place_Leisure",
    StreetSports = "Place_Leisure", StreetSport = "Place_Leisure", WestMapleCountryClub = "Place_Leisure",
    Baseball = "Place_Leisure", Football = "Place_Leisure", Swimmer = "Place_Leisure",
    MusicFest = "Place_Leisure", cornmaze = "Place_Leisure",
    HitVids = "Place_Store", Greenes = "Place_Store", UStoreIt = "Place_Storage",
    HSmithAttorney = "Place_Office", FirstBaptistChapel = "Place_Chapel", Church = "Place_Chapel",
    Studio = "Place_Studio", Shelter = "Place_Shelter", Beach = "Place_Beach",
    Farm = "Place_Farm", Farmer = "Place_Farm", Pony = "Place_Farm", PonyRoama = "Place_Farm",
    BinkysFarm = "Place_Farm",

    Factory = "Place_Factory", MassGenfacCo = "Place_Factory", ConstructionSite = "Place_Construction",
    Offices = "Place_Office", Office = "Place_Office",

    Police = "Place_Police", PoliceState = "Place_Police", FireDept = "Place_FireDept",
    School = "Place_School", University = "Place_University", NursingHome = "Place_NursingHome",
    Doctor = "Place_Hospital",

    Prison = "Place_Prison", Army = "Place_Military", SecretBase = "Place_Military",
    SecretLab = "Place_Military", CrossRoadsMall = "Place_Mall",
    RustyRifle = "Place_GunStore", JamietonArmySurplus = "Place_GunStore", shootingrange = "Place_GunStore",
}

BridgeCallout.PLACE_SKIP = {
    Rich = true, StreetPoor = true, StreetRich = true, Rocker = true, Young = true, BaseballFan = true,
    TrailerPark = true, Wedding = true, Mob = true, Cultists = true, Cowboy = true, Survivalist = true,
    BensCabin = true, Nav = true, Default = true,
}

local function placePoolFor(name)
    if name == nil then return nil end
    if BridgeCallout.PLACE_SKIP[name] then return nil end
    return BridgeCallout.PLACE_POOL[name] or "Place_Commercial"
end

local function zoneNameOf(zone)
    local v = nil
    pcall(function() v = zone:getName() end)
    if type(v) ~= "string" or v == "" then return nil end
    return v
end

local function zoneTypeOf(zone)
    local v = nil
    pcall(function() v = zone:getType() end)
    if type(v) ~= "string" or v == "" then return nil end
    return v
end

local function zoneOrigin(zone)
    local x, y = nil, nil
    pcall(function() x = zone:getX() end)
    pcall(function() y = zone:getY() end)
    if type(x) ~= "number" then x = nil end
    if type(y) ~= "number" then y = nil end
    return x, y
end


function BridgeCallout.resolvePlace(square)
    if square == nil then return nil end
    local sx, sy, sz = nil, nil, nil
    pcall(function() sx, sy, sz = square:getX(), square:getY(), square:getZ() end)
    if sx == nil or sy == nil then return nil end
    if sz == nil then sz = 0 end

    local zones = {}
    local list = nil
    pcall(function() list = getWorld():getMetaGrid():getZonesAt(sx, sy, sz) end)
    if list ~= nil then
        local n = nil
        pcall(function() n = list:size() end)
        if type(n) == "number" then
            for i = 0, n - 1 do
                local zn = nil
                pcall(function() zn = list:get(i) end)
                if zn ~= nil then zones[#zones + 1] = zn end
            end
        elseif type(list) == "table" then
            for i = 1, #list do zones[#zones + 1] = list[i] end
        end
    end
    if #zones == 0 then
        local zn = nil
        pcall(function() zn = square:getZone() end)
        if zn ~= nil then zones[1] = zn end
    end
    if #zones == 0 then return nil end

    local best, special = nil, false
    for i = 1, #zones do
        local t = zoneTypeOf(zones[i])
        if t == "BuildingName" then
            best, special = zones[i], true
            break
        elseif t == "ZombiesType" and best == nil then
            best, special = zones[i], false
        end
    end
    if best == nil then return nil end

    local name = zoneNameOf(best)
    if name == nil then return nil end
    local pool = placePoolFor(name)
    if pool == nil then return nil end

    local key = nil
    local b = nil
    pcall(function() b = square:getBuilding() end)
    if b ~= nil then
        local id = nil
        pcall(function() id = b:getDef():getIDString() end)
        if id == nil then pcall(function() id = b:getID() end) end
        if id ~= nil and tostring(id) ~= "" and tostring(id) ~= "0" then key = "b" .. tostring(id) end
    end
    if key == nil then
        local zx, zy = zoneOrigin(best)
        if zx == nil or zy == nil then return nil end
        key = "z" .. string.format("%d,%d:%s", zx, zy, name)
    end
    return { key = key, pool = pool, name = name, special = special }
end


local function placeNear(red, body)
    if red == nil or body == nil then return false end
    local near = false
    pcall(function()
        local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
        near = dx * dx + dy * dy < BridgeCallout.PLACE_NEAR * BridgeCallout.PLACE_NEAR
            and math.abs(red:getZ() - body:getZ()) < 1
    end)
    return near
end

local function placeCanSpeak()
    if Bridge.time - BridgeCallout.placeLastAt < BridgeCallout.PLACE_GAP then return false end
    local fighting = false
    pcall(function()
        fighting = BridgeFight ~= nil and (BridgeFight.state ~= "idle" or BridgeFight.target ~= nil)
    end)
    return not fighting
end

local function evictOldest(v)
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    while n > BridgeData.VISITED_MAX do
        local oldestKey, oldestS = nil, nil
        for k, e in pairs(v) do
            local s = tonumber(e and e.s) or 0
            if oldestS == nil or s < oldestS then oldestKey, oldestS = k, s end
        end
        if oldestKey == nil then break end
        v[oldestKey] = nil
        n = n - 1
    end
end

local function visitedSign(v)
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = { tostring(#keys) }
    for i = 1, #keys do
        local e = v[keys[i]]
        parts[#parts + 1] = keys[i] .. ":" .. tostring(e.s or 0) .. ":" .. (e.t and "1" or "0")
    end
    return table.concat(parts, "|")
end


function BridgeCallout.saveVisited()
    if not Bridge.mp then return end
    local st = Bridge.store
    if st == nil or type(st.visited) ~= "table" then return end
    local sg = visitedSign(st.visited)
    local important = sg ~= BridgeCallout.visitedSign
    if not important and (Bridge.time - BridgeCallout.visitedSentAt) < 18000 then return end
    BridgeCallout.visitedSign = sg
    BridgeCallout.visitedSentAt = Bridge.time
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "state", { visited = BridgeData.cleanVisited(st.visited) })
    end)
end


local function placeFire(poi)
    local st = Bridge.store
    if st == nil then return end
    if type(st.visited) ~= "table" then st.visited = {} end
    local v = st.visited
    local e = v[poi.key]
    if e == nil then
        v[poi.key] = { s = Bridge.time, n = poi.name }
        evictOldest(v)
        vlog(string.format("place %s %s seen (pool %s)", poi.key, poi.name, poi.pool))
        if v[poi.key] ~= nil and placeCanSpeak()
            and BridgeMoments.say(poi.pool, BridgeCallout.PLACE_GAP, true, "Place") then
            v[poi.key].t = true
            BridgeCallout.placeLastAt = Bridge.time
            vlog("place " .. poi.key .. " told")
        end
    elseif not e.t then
        if placeCanSpeak() and BridgeMoments.say(poi.pool, BridgeCallout.PLACE_GAP, true, "Place") then
            e.t = true
            BridgeCallout.placeLastAt = Bridge.time
            vlog("place " .. poi.key .. " told")
        end
    else
        if placeCanSpeak() and BridgeMoments.say(poi.pool .. "Again", BridgeCallout.PLACE_GAP, true, "Place") then
            BridgeCallout.placeLastAt = Bridge.time
            vlog("place " .. poi.key .. " again")
        end
    end
    BridgeCallout.saveVisited()
end


local function placeTick(body, red)
    if Bridge.store == nil then return end
    if not Bridge.alive() then return end
    if Bridge.mode == "rest" then return end
    if BridgeFastForward ~= nil and BridgeFastForward.active() then return end
    local asleep = false
    pcall(function() asleep = red:isAsleep() end)
    if asleep then return end
    if not placeNear(red, body) then return end

    local square = nil
    pcall(function() square = red:getCurrentSquare() end)
    local poi = BridgeCallout.resolvePlace(square)
    if poi == nil then
        BridgeCallout.placeKey = nil
        return
    end
    if poi.key == BridgeCallout.placeKey then
        if not BridgeCallout.placeFired
            and (Bridge.time - BridgeCallout.placeSince) >= BridgeCallout.PLACE_DWELL then
            BridgeCallout.placeFired = true
            placeFire(poi)
        end
    else
        BridgeCallout.placeKey = poi.key
        BridgeCallout.placeSince = Bridge.time
        BridgeCallout.placeFired = false
    end
end


local function homeAreaHas(home, x, y, z, margin)
    if home == nil then return false end
    local module = rawget(_G, "BridgeHome")
    if type(module) ~= "table" or type(module.contains) ~= "function" then return false end
    local ok, yes = pcall(module.contains, x, y, z, margin)
    return ok and yes == true
end


local function homeWithPlayer(red, bx, by)
    local near = false
    pcall(function()
        local dx, dy = red:getX() - bx, red:getY() - by
        near = dx * dx + dy * dy <= BridgeCallout.HOME_WITH * BridgeCallout.HOME_WITH
    end)
    return near
end


local function homeCanSpeak(red)
    if BridgeCallout.ENABLED == 0 then return false end
    if Bridge.mode == "rest" then return false end
    if BridgeFastForward ~= nil and BridgeFastForward.active() then return false end
    local asleep = false
    pcall(function() asleep = red:isAsleep() end)
    if asleep then return false end
    local fighting = false
    pcall(function() fighting = BridgeFight ~= nil and (BridgeFight.state ~= "idle" or BridgeFight.target ~= nil) end)
    return not fighting
end


local function homeFire()
    if BridgeMoments == nil or type(BridgeMoments.say) ~= "function" then return false end
    local said = false
    pcall(function() said = BridgeMoments.say(BridgeCallout.HOME_EVENT, BridgeCallout.HOME_GAP, true, "HomeReturn") == true end)
    return said
end


function BridgeCallout.markSay(marked)
    if BridgeCallout.ENABLED == 0 then return false end
    if BridgeMenu == nil or type(BridgeMenu.inTalkRange) ~= "function" then return false end
    if not BridgeMenu.inTalkRange() then return false end
    local red = BridgeData.owner()
    if red == nil or not homeCanSpeak(red) then return false end
    local event = marked and BridgeCallout.MARK_EVENT or BridgeCallout.UNMARK_EVENT
    local slot = marked and "StorageMark" or "StorageUnmark"
    local said = false
    pcall(function()
        said = BridgeMoments.say(event, BridgeCallout.MARK_GAP, true, slot) == true
    end)
    if said then vlog("storage mark spoken " .. tostring(marked == true)) end
    return said
end


function BridgeCallout.homeReset()
    BridgeCallout.homeHours = 0
    BridgeCallout.homeFired = false
    BridgeCallout.homeSuppress = true
end


function BridgeCallout.homeCanReturn(red, body)
    if BridgeCallout.ENABLED == 0 then return false end
    if not Bridge.alive() then return false end
    if BridgeCallout.homeSuppress or BridgeCallout.homeFired then return false end
    if BridgeCallout.homeHours < BridgeCallout.HOME_HOURS then return false end
    local home = BridgeHome ~= nil and BridgeHome.get() or nil
    if home == nil or body == nil or red == nil then return false end
    local bx, by, bz = nil, nil, nil
    pcall(function() bx, by, bz = body:getX(), body:getY(), body:getZ() end)
    if bx == nil or by == nil then return false end
    if not homeAreaHas(home, bx, by, bz, BridgeCallout.HOME_NEAR) then return false end
    if not homeWithPlayer(red, bx, by) then return false end
    return homeCanSpeak(red)
end


function BridgeCallout.homeReturnOnExit()
    local red = BridgeData.owner()
    local body = Bridge.body
    if not BridgeCallout.homeCanReturn(red, body) then return false end
    if not homeFire() then return false end
    BridgeCallout.homeFired = true
    BridgeCallout.homeHours = 0
    vlog("home return spoken on exit")
    return true
end


function BridgeCallout.homeTrack(body, red)
    if body == nil or red == nil then return end
    local age = nil
    pcall(function() age = getGameTime():getWorldAgeHours() end)
    if age == nil then return end
    local prev = BridgeCallout.homeAge
    BridgeCallout.homeAge = age

    local home = BridgeHome ~= nil and BridgeHome.get() or nil
    if home == nil then
        BridgeCallout.homeHours = 0
        BridgeCallout.homeFired = false
        BridgeCallout.homeSuppress = false
        BridgeCallout.homeInfo = "none"
        return
    end
    if not Bridge.alive() then
        BridgeCallout.homeHours = 0
        BridgeCallout.homeFired = false
        BridgeCallout.homeInfo = "none"
        return
    end

    local bx, by, bz = nil, nil, nil
    pcall(function() bx, by, bz = body:getX(), body:getY(), body:getZ() end)
    if bx == nil or by == nil then return end

    local atHome = homeAreaHas(home, bx, by, bz, BridgeCallout.HOME_NEAR)

    if atHome then
        BridgeCallout.homeInfo = "home"
        if BridgeCallout.homeSuppress then
            BridgeCallout.homeSuppress = false
            BridgeCallout.homeHours = 0
            BridgeCallout.homeFired = false
            BridgeCallout.homeInfo = "home (called)"
            return
        end
        if BridgeCallout.homeHours < BridgeCallout.HOME_HOURS then
            BridgeCallout.homeHours = 0
            BridgeCallout.homeFired = false
            return
        end
        if not BridgeCallout.homeFired and homeWithPlayer(red, bx, by) and not carQuiet() then
            if homeCanSpeak(red) and homeFire() then
                BridgeCallout.homeFired = true
                BridgeCallout.homeHours = 0
                BridgeCallout.homeInfo = "returned"
                vlog("home return spoken")
            end
        end
        return
    end

    BridgeCallout.homeFired = false
    if homeWithPlayer(red, bx, by) then
        local dt = 0
        if prev ~= nil and age > prev then dt = age - prev end
        BridgeCallout.homeHours = BridgeCallout.homeHours + dt
        BridgeCallout.homeInfo = string.format("away %.2fh", BridgeCallout.homeHours)
    else
        BridgeCallout.homeInfo = "away (alone)"
    end
end


local function homePoolCount(pool)
    local n = 0
    for i = 1, 20 do
        local key = "IGUI_NotAlone_Soc_" .. pool .. "_" .. i
        local found = false
        pcall(function() found = BridgeSpeech.exists(key) end)
        if not found then break end
        n = i
    end
    return n
end


function BridgeCallout.homeStatus()
    local h = BridgeHome ~= nil and BridgeHome.get() or nil
    local loc = "none"
    local all = false
    local pending = false
    if h ~= nil then
        all = BridgeHome ~= nil and type(BridgeHome.allFloorsOn) == "function" and BridgeHome.allFloorsOn() or false
        local z1, z2 = BridgeData.homeRange(h, all)
        pending = BridgeHome ~= nil and type(BridgeHome.allFloorsPending) == "function"
            and BridgeHome.allFloorsPending(h) == true or false
        loc = string.format("%d,%d z%d..z%d %dx%d all=%s pending=%s", h.x, h.y, z1, z2, h.w, h.h,
            all and "on" or "off", tostring(pending))
    end
    return string.format("%s away=%.2fh fired=%s suppress=%s info=%s",
        loc, BridgeCallout.homeHours, tostring(BridgeCallout.homeFired),
        tostring(BridgeCallout.homeSuppress), tostring(BridgeCallout.homeInfo))
end


function BridgeCallout.homeCommand(parts)
    local sub = parts ~= nil and parts[3] or nil
    local home = BridgeHome ~= nil and BridgeHome.get() or nil

    if sub == nil or sub == "status" then
        return "home=" .. BridgeCallout.homeStatus()
    end

    if sub == "why" or sub == "diag" then
        local red = BridgeData.owner()
        local body = Bridge.body
        local bx, by, bz = nil, nil, nil
        if body ~= nil then pcall(function() bx, by, bz = body:getX(), body:getY(), body:getZ() end) end
        local atHome = home ~= nil and bx ~= nil and homeAreaHas(home, bx, by, bz, BridgeCallout.HOME_NEAR)
        local withYou = (bx ~= nil and red ~= nil) and homeWithPlayer(red, bx, by) or false
        local quiet = carQuiet()
        local asleep, fighting, ff, group = "?", "?", "?", "?"
        if red ~= nil then pcall(function() asleep = tostring(red:isAsleep()) end) end
        pcall(function() fighting = tostring(BridgeFight ~= nil and (BridgeFight.state ~= "idle" or BridgeFight.target ~= nil)) end)
        pcall(function() ff = tostring(BridgeFastForward ~= nil and BridgeFastForward.active()) end)
        pcall(function() group = tostring(BridgeMoments.group()) end)
        local can = red ~= nil and homeCanSpeak(red)
        local line = "none"
        pcall(function() line = tostring(BridgeMoments.line(BridgeCallout.HOME_EVENT)) end)
        return string.format(
            "home why: atHome=%s withYou=%s carQuiet=%s canSpeak=%s asleep=%s ff=%s fighting=%s mode=%s enabled=%s hours=%.2f fired=%s suppress=%s group=%s pools[F=%d N=%d C=%d] line=%s",
            tostring(atHome), tostring(withYou), tostring(quiet), tostring(can), asleep, ff, fighting,
            tostring(Bridge.mode), tostring(BridgeCallout.ENABLED), BridgeCallout.homeHours,
            tostring(BridgeCallout.homeFired), tostring(BridgeCallout.homeSuppress), group,
            homePoolCount("EvHomeReturn_Far"), homePoolCount("EvHomeReturn_Near"), homePoolCount("EvHomeReturn_Close"),
            line)
    end

    if sub == "clear" then
        if home == nil then return "home clear: none set" end
        Bridge.clearHome()
        if BridgeHome ~= nil then BridgeHome.syncHandle() end
        return "home cleared"
    end

    if sub == "set" then
        local x, y, z, w, h
        if parts[4] == nil then
            local red = BridgeData.owner()
            local sq = nil
            if red ~= nil then pcall(function() sq = red:getCurrentSquare() end) end
            if sq == nil then return "home set: no square" end
            x, y, z, w, h = sq:getX(), sq:getY(), sq:getZ(), 12, 12
        elseif parts[8] ~= nil then
            x, y, z = tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6])
            w, h = tonumber(parts[7]), tonumber(parts[8])
        elseif parts[5] ~= nil then
            local red = BridgeData.owner()
            local sq = nil
            if red ~= nil then pcall(function() sq = red:getCurrentSquare() end) end
            if sq == nil then return "home set: no square" end
            x, y, z = sq:getX(), sq:getY(), sq:getZ()
            w, h = tonumber(parts[4]), tonumber(parts[5])
        else
            return "home set: use 'home set' | 'home set <w> <h>' | 'home set <x> <y> <z> <w> <h>'"
        end
        if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number"
            or type(w) ~= "number" or type(h) ~= "number" then
            return "home set: bad numbers"
        end
        local res = Bridge.setHome({ x = x, y = y, z = z, w = w, h = h })
        if BridgeHome ~= nil then BridgeHome.syncHandle() end
        if res == "bad home" then
            return string.format("home set failed: size must be %d-%d on both sides",
                BridgeData.HOME_MIN, BridgeData.HOME_MAX)
        end
        local got = BridgeHome ~= nil and BridgeHome.get() or nil
        if got == nil then return "home set failed: " .. tostring(res) end
        local all = BridgeHome ~= nil and type(BridgeHome.allFloorsOn) == "function" and BridgeHome.allFloorsOn() or false
        local z1, z2 = BridgeData.homeRange(got, all)
        return string.format("home set %d,%d z%d..z%d %dx%d all=%s", got.x, got.y, z1, z2, got.w, got.h,
            all and "on" or "off")
    end

    if sub == "all" then
        if BridgeHome == nil then return "home all: home not loaded" end
        local how = parts[4]
        if how ~= "on" and how ~= "off" then return "home all [on | off]" end
        if Bridge == nil or type(Bridge.setOption) ~= "function" then return "home all: no bridge" end
        Bridge.setOption("homeAllFloors", how == "on")
        pcall(function() BridgeHome.onAllFloorsChanged(how == "on") end)
        local got = BridgeHome.get()
        if got == nil then return string.format("home all=%s", how) end
        local z1, z2 = BridgeData.homeRange(got, how == "on")
        local pending = type(BridgeHome.allFloorsPending) == "function" and BridgeHome.allFloorsPending(got) or false
        return string.format("home all=%s z%d..z%d pending=%s", how, z1, z2, tostring(pending))
    end

    if sub == "floors" then
        if home == nil then return "home floors: none set" end
        if BridgeHome == nil or type(BridgeHome.includedFloors) ~= "function" then return "home floors: home not loaded" end
        local all = type(BridgeHome.allFloorsOn) == "function" and BridgeHome.allFloorsOn() or false
        local floors = BridgeHome.includedFloors(home, all)
        local partsOut = {}
        for index = 1, #floors do partsOut[#partsOut + 1] = string.format("z%d", floors[index]) end
        return string.format("home floors all=%s [%s] bld=%s", all and "on" or "off",
            table.concat(partsOut, " "), tostring(home.bld))
    end

    if sub == "away" then
        local hrs = tonumber(parts[4])
        if hrs == nil then return string.format("home away=%.2fh", BridgeCallout.homeHours) end
        BridgeCallout.homeHours = hrs
        BridgeCallout.homeFired = false
        BridgeCallout.homeSuppress = false
        BridgeCallout.homeAge = nil
        return string.format("home away=%.2fh", BridgeCallout.homeHours)
    end

    if sub == "fire" then
        if home == nil then return "home fire: no home set" end
        if BridgeMoments == nil then return "home fire: no moments" end
        BridgeMoments.cool["HomeReturn"] = -99999
        local said = false
        pcall(function()
            said = BridgeMoments.say(BridgeCallout.HOME_EVENT, BridgeCallout.HOME_GAP, true, "HomeReturn") == true
        end)
        if said then
            BridgeCallout.homeFired = true
            BridgeCallout.homeHours = 0
        end
        return said and "home fire: said" or "home fire: could not speak"
    end

    if sub == "exit" then
        return BridgeCallout.homeReturnOnExit() and "home exit: spoke (replaces car-exit line)"
            or "home exit: not armed/eligible"
    end

    if sub == "reset" then
        BridgeCallout.homeReset()
        return "home state reset (suppressed until next arrival)"
    end

    return "home [status | why | set [x y z w h] | clear | away <hours> | fire | exit | reset | all on|off | floors]"
end


function BridgeCallout.placesCommand(sub, a)
    local max = BridgeData.VISITED_MAX or 200

    if sub == "help" or sub == "?" then
        return "places [list | reset | forget <key> | here | test | help]"
    end

    if sub == "here" or sub == "test" then
        local red = BridgeData.owner()
        local square = nil
        if red ~= nil then pcall(function() square = red:getCurrentSquare() end) end
        local poi = BridgeCallout.resolvePlace(square)
        if poi == nil then return "places " .. tostring(sub) .. ": no POI at this square" end
        if sub == "here" then
            return string.format("places here: key=%s pool=%s name=%s special=%s",
                tostring(poi.key), tostring(poi.pool), tostring(poi.name), tostring(poi.special))
        end
        local st = Bridge.store
        if st == nil then return "places test: no store" end
        if type(st.visited) ~= "table" then st.visited = {} end
        st.visited[poi.key] = nil
        BridgeCallout.placeLastAt = -99999
        BridgeCallout.placeKey = nil
        placeFire(poi)
        return string.format("places test: fired key=%s pool=%s name=%s",
            tostring(poi.key), tostring(poi.pool), tostring(poi.name))
    end

    local st = Bridge.store
    if st == nil then return "places: no store" end

    if sub == "reset" then
        st.visited = {}
        BridgeCallout.visitedSign = nil
        BridgeCallout.placeKey = nil
        BridgeCallout.placeFired = false
        BridgeCallout.saveVisited()
        return string.format("places reset: 0/%d", max)
    end

    local v = st.visited
    if type(v) ~= "table" then
        if sub == "forget" then return "places forget: no entries" end
        return string.format("places 0/%d", max)
    end

    if sub == "forget" then
        if a == nil or a == "" then return "places forget: needs a key" end
        if v[a] == nil then return "places forget: no such key " .. tostring(a) end
        v[a] = nil
        BridgeCallout.saveVisited()
        return "places forget: removed " .. tostring(a)
    end

    local keys, n, told = {}, 0, 0
    for k, e in pairs(v) do
        n = n + 1
        if e ~= nil and e.t then told = told + 1 end
        keys[#keys + 1] = k
    end
    table.sort(keys)
    if sub == "list" then
        local out = {}
        for i = 1, #keys do
            local e = v[keys[i]] or {}
            out[#out + 1] = string.format("%s %s%s", tostring(keys[i]), tostring(e.n or "?"), e.t and "*" or "")
        end
        return string.format("places %d/%d told=%d: %s", n, max, told, table.concat(out, "; "))
    end
    return string.format("places %d/%d told=%d", n, max, told)
end



local function cityAt(x, y)
    local best, bestD2 = nil, nil
    for i = 1, #BridgeCallout.CITY_BOXES do
        local b = BridgeCallout.CITY_BOXES[i]
        if x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY then
            local dx, dy = x - (b.minX + b.maxX) / 2, y - (b.minY + b.maxY) / 2
            local d2 = dx * dx + dy * dy
            if bestD2 == nil or d2 < bestD2 then best, bestD2 = b, d2 end
        end
    end
    return best
end


local function citiesSignOf(v)
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = { tostring(#keys) }
    for i = 1, #keys do
        local e = v[keys[i]] or {}
        parts[#parts + 1] = keys[i] .. ":" .. (e.seen and "1" or "0") .. ":"
            .. string.format("%.2f", tonumber(e.lastAge) or 0)
    end
    return table.concat(parts, "|")
end


function BridgeCallout.saveCities()
    if not Bridge.mp then return end
    local st = Bridge.store
    if st == nil or type(st.cities) ~= "table" then return end
    local sg = citiesSignOf(st.cities)
    local important = sg ~= BridgeCallout.citiesSign
    if not important and (Bridge.time - BridgeCallout.citiesSentAt) < 18000 then return end
    BridgeCallout.citiesSign = sg
    BridgeCallout.citiesSentAt = Bridge.time
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "state", { cities = BridgeData.cleanCities(st.cities) })
    end)
end


function BridgeCallout.cityTick(body)
    if Bridge.store == nil then return end
    if not Bridge.alive() then return end
    if Bridge.mode == "rest" then return end
    if BridgeFastForward ~= nil and BridgeFastForward.active() then return end
    local red = BridgeData.owner()
    if red == nil then return end

    local asleep = false
    pcall(function() asleep = red:isAsleep() end)
    if asleep then return end

    local age = nil
    pcall(function() age = getGameTime():getWorldAgeHours() end)
    if age == nil then return end

    local x, y = nil, nil
    pcall(function() x, y = red:getX(), red:getY() end)
    if x == nil or y == nil then return end

    local box = cityAt(x, y)
    if box == nil then
        if BridgeCallout.cityKey ~= nil then
            BridgeCallout.cityKey = nil
            BridgeCallout.cityFired = false
            BridgeCallout.cityAway = nil
        end
        return
    end

    local st = Bridge.store
    if type(st.cities) ~= "table" then st.cities = {} end
    local cities = st.cities
    local e = cities[box.id]
    if type(e) ~= "table" then e = {} cities[box.id] = e end

    if box.id ~= BridgeCallout.cityKey then
        BridgeCallout.cityKey = box.id
        BridgeCallout.citySince = Bridge.time
        BridgeCallout.cityFired = false
        BridgeCallout.cityAway = nil
        local prev = tonumber(e.lastAge)
        if e.seen == true and prev ~= nil and age >= prev then
            BridgeCallout.cityAway = age - prev
        end
    end

    e.lastAge = age

    if BridgeCallout.cityFired then
        BridgeCallout.saveCities()
        return
    end
    if (Bridge.time - BridgeCallout.citySince) < BridgeCallout.CITY_DWELL then
        BridgeCallout.saveCities()
        return
    end
    if (Bridge.time - BridgeCallout.cityLastAt) < BridgeCallout.CITY_GAP then
        BridgeCallout.saveCities()
        return
    end

    local near = false
    pcall(function()
        local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
        near = dx * dx + dy * dy <= BridgeCallout.CITY_NEAR * BridgeCallout.CITY_NEAR
            and math.abs(red:getZ() - body:getZ()) < 1
    end)
    local inCar = false
    pcall(function()
        inCar = BridgeCar ~= nil and type(BridgeCar.withRed) == "function" and BridgeCar.withRed(red) == true
    end)
    if not near and not inCar then
        BridgeCallout.saveCities()
        return
    end

    BridgeCallout.cityFired = true
    local pool = nil
    if e.seen ~= true then
        pool = "City_" .. box.id
    elseif BridgeCallout.cityAway ~= nil and BridgeCallout.cityAway >= BridgeCallout.CITY_MIN_AWAY then
        pool = "City_" .. box.id .. "Again"
    end
    e.seen = true
    e.lastAge = age
    BridgeCallout.saveCities()

    if pool ~= nil and BridgeMoments ~= nil and type(BridgeMoments.say) == "function" then
        local said = false
        pcall(function() said = BridgeMoments.say(pool, BridgeCallout.CITY_GAP, true, "City") == true end)
        if said then
            BridgeCallout.cityLastAt = Bridge.time
            vlog("city " .. box.id .. " -> " .. pool)
        end
    end
end


function BridgeCallout.citiesCommand(sub, a)
    local boxes = BridgeCallout.CITY_BOXES or {}
    if sub == "help" or sub == "?" then
        return "cities [here | list | reset | fire <id> | again <id>]"
    end
    local st = Bridge.store
    if st == nil then return "cities: no store" end
    if type(st.cities) ~= "table" then st.cities = {} end

    if sub == "here" then
        local red = BridgeData.owner()
        local x, y = nil, nil
        if red ~= nil then pcall(function() x, y = red:getX(), red:getY() end) end
        if x == nil then return "cities here: unknown position" end
        local box = cityAt(x, y)
        if box == nil then return string.format("cities here: none (%.0f,%.0f)", x, y) end
        return string.format("cities here: %s (%s) %.0f,%.0f", tostring(box.id), tostring(box.label), x, y)
    end

    if sub == "reset" then
        st.cities = {}
        BridgeCallout.citiesSign = nil
        BridgeCallout.cityKey = nil
        BridgeCallout.cityFired = false
        BridgeCallout.cityAway = nil
        BridgeCallout.saveCities()
        return "cities reset: 0"
    end

    local function findBox(id)
        for i = 1, #boxes do if boxes[i].id == id then return boxes[i] end end
        return nil
    end

    if sub == "fire" or sub == "again" then
        local box = findBox(a)
        if box == nil then return "cities " .. tostring(sub) .. ": unknown id " .. tostring(a) end
        local pool = (sub == "fire") and ("City_" .. box.id) or ("City_" .. box.id .. "Again")
        local said = false
        if BridgeMoments ~= nil and type(BridgeMoments.say) == "function" then
            pcall(function() said = BridgeMoments.say(pool, 0, true, "City") == true end)
        end
        BridgeCallout.cityLastAt = Bridge.time
        return string.format("cities %s %s -> %s (%s)", tostring(sub), tostring(box.id), pool, said and "spoke" or "no line")
    end

    local age = nil
    pcall(function() age = getGameTime():getWorldAgeHours() end)
    local keys = {}
    for k in pairs(st.cities) do keys[#keys + 1] = k end
    table.sort(keys)
    if #keys == 0 then return "cities: none seen" end
    local out = {}
    for i = 1, #keys do
        local e = st.cities[keys[i]] or {}
        local away = "?"
        if age ~= nil and tonumber(e.lastAge) ~= nil then away = string.format("%.1f", age - tonumber(e.lastAge)) end
        out[#out + 1] = string.format("%s(seen=%s away=%s)", tostring(keys[i]), tostring(e.seen == true), away)
    end
    return "cities " .. #keys .. ": " .. table.concat(out, ", ")
end


local function fightNow()
    local fighting = false
    pcall(function() if BridgeFight ~= nil then fighting = BridgeFight.state ~= "idle" end end)
    return fighting
end


local function scanInterval(body, red)
    if Bridge.mode == "rest" then return BridgeCallout.SCAN_QUIET end
    if BridgeFastForward ~= nil and BridgeFastForward.active() then return BridgeCallout.SCAN_QUIET end
    local inCar = false
    pcall(function() inCar = red ~= nil and red:getVehicle() ~= nil end)
    if inCar then return BridgeCallout.SCAN_QUIET end
    if fightNow() then return BridgeCallout.SCAN_FIGHT end
    if Bridge.time - BridgeCallout.lastCombatAt < BridgeCallout.COMBAT_GRACE * BridgeCallout.SEC then
        return BridgeCallout.SCAN_FIGHT
    end
    local near = false
    pcall(function()
        if BridgeScan == nil or red == nil then return end
        local frame = BridgeScan.frame(body, red)
        if frame ~= nil and frame.countNear ~= nil then near = frame.countNear(15, "companion") > 0 end
    end)
    if near then return BridgeCallout.SCAN_FIGHT end
    return BridgeCallout.SCAN_IDLE
end


local function peakThreats(body, red)
    local n = 0
    local frame = nil
    pcall(function() if BridgeScan ~= nil then frame = BridgeScan.frame(body, red) end end)
    if frame ~= nil then
        local entries = frame.entries or {}
        for i = 1, #entries do
            local e = entries[i]
            if e.threat then
                if (e.dc <= 8 and math.abs(e.zc) < 1) or (e.dp <= 8 and math.abs(e.zp) < 1) then
                    n = n + 1
                end
            end
        end
        return n
    end
    pcall(function()
        if BridgeHorde ~= nil and type(BridgeHorde.count) == "function" then
            n = BridgeHorde.count(body:getX(), body:getY(), body:getZ(), 8)
        end
    end)
    return tonumber(n) or 0
end


local function startFightRecord()
    BridgeCallout.recordOn = true
    BridgeCallout.fightTime = 0
    BridgeCallout.fightPeak = 0
    BridgeCallout.fightGun = false
    BridgeCallout.fightHit = false
    BridgeCallout.fightWritten = false
    BridgeCallout.redWindedSaid = false
    clearOneShots()
end


local function writeLastFight()
    if BridgeCallout.fightWritten then return end
    BridgeCallout.fightWritten = true
    local age = 0
    pcall(function() age = getGameTime():getWorldAgeHours() end)
    local rec = {
        d = BridgeCallout.fightTime,
        p = BridgeCallout.fightPeak,
        m = BridgeCallout.fightGun and "gun" or "melee",
        h = BridgeCallout.fightHit and 1 or 0,
        a = tonumber(age) or 0,
    }
    if Bridge.store ~= nil then Bridge.store.lastFight = rec end
    if Bridge.mp then
        pcall(function()
            sendClientCommand(BridgeData.owner(), "Bridge", "state", { lastFight = rec })
        end)
    end
end


local function endFightLine(facts)
    local heavy = BridgeCallout.fightPeak >= BridgeCallout.FIGHT_HEAVY_PEAK or BridgeCallout.fightHit
    local long = BridgeCallout.fightTime >= BridgeCallout.FIGHT_LONG_SEC
    if facts ~= nil and facts.near8 > 0 then return "EvStillOnUs" end
    if not BridgeCallout.fightGun then
        local tired, threshold = 0, 0.5
        pcall(function() tired = tonumber(BridgeFight.fatigue) or 0 end)
        pcall(function()
            if BridgeFight ~= nil and type(BridgeFight.tiredThreshold) == "function" then
                threshold = tonumber(BridgeFight.tiredThreshold()) or 0.5
            end
        end)
        if tired >= (tonumber(threshold) or 0.5) then return "EvAfterFightTired" end
    end
    if BridgeCallout.fightGun and (heavy or long) then return "EvAfterFightGun" end
    if heavy then return "EvAfterFightHard" end
    if long then return "EvAfterFightLong" end
    return nil
end


local function checkOneShots(body, red)
    local now = Bridge.time
    if BridgeCallout.aftermathAt ~= nil and now >= BridgeCallout.aftermathAt then
        BridgeCallout.aftermathAt = nil
        if now - BridgeCallout.lastAny >= BridgeCallout.REMARK_GAP * BridgeCallout.SEC then
            local ok = true
            local pd, sameZ, alive, asleep, inCar = 99, false, false, true, true
            pcall(function()
                local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
                pd = math.sqrt(dx * dx + dy * dy)
                sameZ = math.abs(red:getZ() - body:getZ()) < 1
                alive = body:isAlive() == true
                asleep = red:isAsleep() == true
                inCar = red:getVehicle() ~= nil
            end)
            if ok and fightNow() then ok = false end
            if ok and not noZombiesInSight(red, body, 8) then ok = false end
            if ok and (not alive or pd > BridgeCallout.AMMO_NEAR or not sameZ or asleep or inCar) then ok = false end
            if ok then
                pcall(function()
                    BridgeSocial.sayExact("RemarkAfterFight", BridgeCallout.REMARK_SLOT_CD * BridgeCallout.SEC,
                        "RemarkAfterFight")
                end)
            end
        end
    end
    if BridgeCallout.tenseAt ~= nil and now >= BridgeCallout.tenseAt then
        BridgeCallout.tenseAt = nil
        if now - BridgeCallout.lastAny >= BridgeCallout.REMARK_GAP * BridgeCallout.SEC then
            local calm = not fightNow()
            local ok = false
            pcall(function() ok = BridgeSocial.unseenNearby(red) == true end)
            if calm and ok then
                pcall(function()
                    BridgeSocial.sayExact("RemarkTense", BridgeCallout.REMARK_SLOT_CD * BridgeCallout.SEC, "RemarkTense")
                end)
            end
        end
    end
end


local function checkRedWinded(red, engaged)
    if BridgeCallout.redWindedSaid then return end
    if not engaged then return end
    local low = false
    pcall(function()
        if not Bridge.alive() then return end
        local v = nil
        pcall(function() v = red:getVehicle() end)
        if v ~= nil then return end
        local asleep = false
        pcall(function() asleep = red:isAsleep() == true end)
        if asleep then return end
        local endur, warn = 1, 0.5
        pcall(function() endur = red:getStats():get(CharacterStat.ENDURANCE) end)
        pcall(function() warn = red:getStats():getEnduranceWarning() end)
        low = type(endur) == "number" and type(warn) == "number" and endur < warn
    end)
    if not low then return end
    BridgeCallout.redWindedSaid = true
    BridgeCallout.redWinded()
end


local function checkWeaponLow(red)
    local item = nil
    pcall(function() item = red:getPrimaryHandItem() end)
    if item == nil then
        BridgeCallout.weaponLowItem = nil
        BridgeCallout.weaponLowSaid = false
        return
    end
    if not instanceof(item, "HandWeapon") then
        BridgeCallout.weaponLowItem = nil
        BridgeCallout.weaponLowSaid = false
        return
    end
    local ranged = false
    pcall(function() ranged = item:isRanged() == true end)
    if ranged then
        BridgeCallout.weaponLowItem = nil
        BridgeCallout.weaponLowSaid = false
        return
    end
    local cond, max = nil, nil
    pcall(function() cond = item:getCondition() max = item:getConditionMax() end)
    if type(cond) ~= "number" or type(max) ~= "number" or max <= 0 then
        BridgeCallout.weaponLowItem = nil
        BridgeCallout.weaponLowSaid = false
        return
    end
    if BridgeCallout.weaponLowItem ~= item then
        BridgeCallout.weaponLowItem = item
        BridgeCallout.weaponLowSaid = false
    end
    if (cond / max) > BridgeCallout.WEAPON_LOW then
        BridgeCallout.weaponLowSaid = false
        return
    end
    if BridgeCallout.weaponLowSaid then return end
    BridgeCallout.weaponLowSaid = true
    BridgeCallout.redWeaponLow()
end


local function checkSwitch()
    local drawn = false
    pcall(function() drawn = BridgeGunfight ~= nil and BridgeGunfight.drawn == true end)
    local prev = BridgeCallout.drawnPrev
    local fighting = fightNow()
    if drawn ~= prev and fighting then
        if drawn then
            local gunMode = false
            pcall(function()
                gunMode = (BridgeFight ~= nil and BridgeFight.state == "gun")
                    or (BridgeGunfight ~= nil and BridgeGunfight.target ~= nil)
            end)
            if gunMode then BridgeCallout.switchToGun() end
        else
            local meleeMode = false
            pcall(function()
                meleeMode = (BridgeFight ~= nil and BridgeFight.state == "swing")
                    or (BridgeGunfight ~= nil and (BridgeGunfight.stance == "melee"
                        or BridgeGunfight.meleeFallback == true))
            end)
            if meleeMode then BridgeCallout.switchToMelee() end
        end
    end
    BridgeCallout.drawnPrev = drawn
end


function BridgeCallout.update(body)
    if body == nil then return end
    local scanDue = Bridge.every(15)
    if scanDue and type(BridgeCallout.homeTrack) == "function" then
        pcall(function() BridgeCallout.homeTrack(body, BridgeData.owner()) end)
    end
    if BridgeCallout.ENABLED == 0 then return end
    if Bridge.time < (BridgeCallout.dueAt or 0) then return end
    if carQuiet() then
        BridgeCallout.dueAt = Bridge.time + BridgeCallout.SCAN_QUIET
        dropCarLines()
        BridgeCallout.info = "car"
        return
    end
    local red = BridgeData.owner()
    local interval = scanInterval(body, red)
    BridgeCallout.dueAt = Bridge.time + interval
    if Bridge.time - (BridgeCallout.scanAt or 0) < interval then return end
    BridgeCallout.scanAt = Bridge.time
    if not Bridge.alive() then
        BridgeCallout.recordOn = false
        clearOneShots()
        return
    end
    if red == nil then return end

    local asleep = false
    pcall(function() asleep = red:isAsleep() == true end)
    if asleep then clearOneShots() end

    placeTick(body, red)

    local due = BridgeCallout.milestoneDue
    if due ~= nil then
        local at = due.at or 0
        if Bridge.time >= at then
            BridgeCallout.milestoneDue = nil
            BridgeCallout.forceMilestone(due.n)
        elseif Bridge.time - at > 8 * BridgeCallout.SEC then
            BridgeCallout.milestoneDue = nil
        end
    end

    local prevAttack = BridgeCallout.attackPrev
    local h2h, atk = attackSignals(red)
    local attackingNow = h2h or atk
    BridgeCallout.attackPrev = attackingNow

    local fighting = fightNow()
    local stepSec = interval / BridgeCallout.SEC
    if fighting then
        BridgeCallout.wasFighting = true
        BridgeCallout.fightingAt = Bridge.time
        BridgeCallout.lastCombatAt = Bridge.time
        if not BridgeCallout.recordOn then startFightRecord() end
        BridgeCallout.fightTime = BridgeCallout.fightTime + stepSec
        local peak = peakThreats(body, red)
        if peak > BridgeCallout.fightPeak then BridgeCallout.fightPeak = peak end
        local gunNow = false
        pcall(function() gunNow = BridgeFight ~= nil and BridgeFight.state == "gun" end)
        if gunNow then BridgeCallout.fightGun = true end
    end
    if not fighting then BridgeCallout.finisherTarget = nil end
    local engaged = fighting or (Bridge.time - BridgeCallout.fightingAt < BridgeCallout.COMBAT_GRACE * BridgeCallout.SEC)

    if flush() then return end

    checkSwitch()
    checkRedWinded(red, engaged)
    if engaged then checkWeaponLow(red) end
    checkOneShots(body, red)

    local pk = BridgeCallout.pendingKill
    if pk ~= nil then
        BridgeCallout.pendingKill = nil
        if deadZ(pk) then say("EvKill") end
    end

    local health = nil
    pcall(function() health = red:getBodyDamage():getOverallBodyHealth() end)
    if health ~= nil then
        if fighting and BridgeCallout.lastHealth ~= nil
            and BridgeCallout.lastHealth - health >= BridgeCallout.PLAYER_HIT_DROP then
            say("EvPlayerHit")
            BridgeCallout.fightHit = true
        end
        BridgeCallout.lastHealth = health
    end

    if BridgeHorde ~= nil then
        local SAY = BridgeCallout.SAY
        if SAY.EvHorde32 ~= 0 or SAY.EvHorde16 ~= 0 or SAY.EvHorde8 ~= 0 or SAY.EvHorde4 ~= 0 then
            local raw, n = BridgeCallout.hordeRaw, BridgeCallout.hordeSeen
            if Bridge.time - (BridgeCallout.hordeAt or -99999) >= BridgeCallout.HORDE_SCAN_EVERY then
                local hx, hy, hz = nil, nil, nil
                pcall(function() hx, hy, hz = red:getX(), red:getY(), red:getZ() end)
                if hx ~= nil then
                    raw = BridgeHorde.count(hx, hy, hz, BridgeHorde.RADIUS)
                    n = 0
                    if raw >= BridgeHorde.TIERS[1] then
                        n = BridgeHorde.countSeen(hx, hy, hz, BridgeHorde.RADIUS, body, red, raw)
                        vlog(string.format("horde: raw=%d seen=%d at %.1f,%.1f", raw, n, hx, hy))
                    end
                    BridgeCallout.hordeAt = Bridge.time
                    BridgeCallout.hordeRaw, BridgeCallout.hordeSeen = raw, n
                end
            end
            local tiers = BridgeHorde.TIERS
            for i = #tiers, 1, -1 do
                local t = tiers[i]
                if n >= t and SAY["EvHorde" .. t] ~= 0 then
                    if say("EvHorde" .. t) then return end
                    break
                end
            end
        end
    end

    local facts = scanWorld(body, red, not engaged)

    if fighting then
        local crowd, playerDist = 0, 99
        pcall(function()
            if BridgeFight ~= nil and type(BridgeFight.crowdAround) == "function" then
                crowd = BridgeFight.crowdAround(body, BridgeCallout.SWARM_RADIUS) or 0
            end
            local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
            playerDist = math.sqrt(dx * dx + dy * dy)
        end)
        if BridgeCallout.SAY.EvSwarmed ~= 0 and crowd >= 3
            and playerDist > BridgeCallout.SWARM_PLAYER then
            BridgeCallout.swarmed()
            return
        end
        if BridgeCallout.SAY.EvFinisher ~= 0 or BridgeCallout.SAY.EvFinisherGun ~= 0 then
            local ft = scanFinisher()
            if ft ~= nil then
                local gunFinisher = false
                pcall(function()
                    gunFinisher = BridgeFight ~= nil and BridgeFight.state == "gun"
                        and BridgeGunfight ~= nil and BridgeGunfight.target == ft
                end)
                if say(gunFinisher and "EvFinisherGun" or "EvFinisher") then return end
            end
        end
        if BridgeCallout.SAY.EvTaunt ~= 0 and nearTarget(body) then
            local n = #BridgeCallout.AMBIENT
            local start = ZombRand(n)
            for i = 0, n - 1 do
                local k = start + i
                if k >= n then k = k - n end
                if say(BridgeCallout.AMBIENT[k + 1]) then return end
            end
        end
        return
    end

    if BridgeCallout.wasFighting then
        BridgeCallout.wasFighting = false
        BridgeCallout.recordOn = false
        local line = endFightLine(facts)
        if line ~= nil and BridgeCallout.SAY[line] == 0 then line = nil end
        if line ~= nil then
            say(line)
        elseif facts.near8 == 0 then
            say("EvLull")
        end
        if BridgeCallout.fightTime >= BridgeCallout.FIGHT_AFTERMATH_SEC
            or BridgeCallout.fightPeak >= BridgeCallout.FIGHT_AFTERMATH_PEAK then
            BridgeCallout.aftermathAt = Bridge.time + BridgeCallout.AFTERMATH_DELAY_SEC * BridgeCallout.SEC
        end
        BridgeCallout.tenseAt = Bridge.time + BridgeCallout.TENSE_DELAY_SEC * BridgeCallout.SEC
        writeLastFight()
        return
    end

    local guard = false
    pcall(function() if BridgeFight ~= nil then guard = BridgeFight.guardOnly end end)
    if BridgeCallout.DEBUG == 1 and attackingNow and not prevAttack then
        print("[BridgeCallout] SWING edge h2h=" .. tostring(h2h) .. " atk=" .. tostring(atk)
            .. " guard=" .. tostring(guard) .. " engaged=" .. tostring(engaged)
            .. " task=" .. tostring(BridgeTask ~= nil and BridgeTask.active)
            .. " quiet=" .. tostring(Bridge.time - BridgeCallout.lastCombatAt)
            .. " clear=" .. tostring(noZombiesInSight(red, body, BridgeCallout.SWING_ZOMBIE_DIST))
            .. " atHer=" .. tostring(swingingAtHer(red, body, attackingNow, prevAttack)))
    end
    if not engaged
        and not (BridgeTask ~= nil and BridgeTask.active)
        and (Bridge.time - BridgeCallout.lastCombatAt) >= BridgeCallout.SWING_COMBAT_QUIET * BridgeCallout.SEC
        and not facts.anyThreatInSwing
        and swingingAtHer(red, body, attackingNow, prevAttack) then
        BridgeCallout.swingAtMe()
    end
    if not guard and not engaged and facts.spot then say("EvSpot") end
end

log("loaded")