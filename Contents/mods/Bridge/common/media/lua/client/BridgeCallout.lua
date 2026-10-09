BridgeCallout = BridgeCallout or {}

BridgeCallout.SEC = 60

BridgeCallout.HORDE_COUNT = 10
BridgeCallout.BEHIND_DIST = 6
BridgeCallout.SPOT_DIST = 15
BridgeCallout.SPOT_MIN_DIST = 8
BridgeCallout.LULL_DIST = 8
BridgeCallout.FLANK_DIST = 8
BridgeCallout.CRAWLER_DIST = 3
BridgeCallout.BREACH_DIST = 5
BridgeCallout.MELEE_DIST = 6
BridgeCallout.COMBAT_GRACE = 4
BridgeCallout.FINISH_HP = 0.5
BridgeCallout.PLAYER_HIT_DROP = 1.0

BridgeCallout.SWING_COMBAT_QUIET = 60
BridgeCallout.SWING_ZOMBIE_DIST = 10
BridgeCallout.SWING_Z_TOL = 0.8
BridgeCallout.SWING_RANGE_TOL = 0.3

BridgeCallout.FLANK_SIGN = -1

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

BridgeCallout.AMBIENT = { "EvTaunt" }


BridgeCallout.ENABLED = 1


BridgeCallout.DEBUG = 0


BridgeCallout.SAY = {
    EvBehind     = 0,
    EvEngage     = 1,
    EvKill       = 1,
    EvHorde      = 1,
    EvBreakOff   = 1,
    EvSpot       = 1,
    EvLull       = 1,
    EvPlayerHit  = 1,
    EvFlankLeft  = 0,
    EvFlankRight = 0,
    EvFinisher   = 1,
    EvCrawler    = 0,
    EvBreach     = 0,
    EvLostTarget = 1,
    EvTaunt      = 1,
    EvAimClear   = 1,
    EvAimOnMe    = 1,
    EvTorchLow   = 1,
    EvSwingAtMe  = 1,
}


BridgeCallout.REPEAT_GAP = 8

BridgeCallout.MILESTONES = { [1] = true, [5] = true, [10] = true, [25] = true, [50] = true,
    [100] = true, [250] = true, [500] = true, [1000] = true }
BridgeCallout.MILESTONE_CAP = 1000
BridgeCallout.MILESTONE_AFTER = 3


BridgeCallout.EVENTS = {
    EvBehind     = { slot = "Behind",     cooldown = 45 },
    EvEngage     = { slot = "Engage",     cooldown = 25 },
    EvKill       = { slot = "Kill",       cooldown = 20 },
    EvHorde      = { slot = "Horde",      cooldown = 75 },
    EvBreakOff   = { slot = "BreakOff",   cooldown = 30 },
    EvSpot       = { slot = "Spot",       cooldown = 120 },
    EvLull       = { slot = "Lull",       cooldown = 150 },
    EvPlayerHit  = { slot = "PlayerHit",  cooldown = 30 },
    EvFlankLeft  = { slot = "Flank",      cooldown = 45 },
    EvFlankRight = { slot = "Flank",      cooldown = 45 },
    EvFinisher   = { slot = "Finisher",   cooldown = 30 },
    EvCrawler    = { slot = "Crawler",    cooldown = 60 },
    EvBreach     = { slot = "Breach",     cooldown = 90 },
    EvLostTarget = { slot = "LostTarget", cooldown = 60 },
    EvTaunt      = { slot = "Taunt",      cooldown = 150 },
    EvAimClear   = { slot = "AimClear",   cooldown = 15 },
    EvAimOnMe    = { slot = "AimOnMe",    cooldown = 15 },
    EvTorchLow   = { slot = "TorchLow",   cooldown = 300 },
    EvSwingAtMe  = { slot = "SwingAtMe",  cooldown = 30 },
}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeCallout] " .. tostring(text)) end end

local function dlog(text)
    if BridgeCallout.DEBUG == 1 then log(text) end
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

local function proneZ(z)
    local prone = false
    pcall(function()
        local asn = z:getActionStateName()
        prone = z:isProne() or z:isCrawling() or asn == "onground" or asn == "sitonground"
    end)
    return prone == true
end

local function attackSignals(red)
    local h2h, atk = false, false
    local probe = nil
    pcall(function() probe = red.isDoHandToHandAttack end)
    if probe ~= nil then pcall(function() h2h = red:isDoHandToHandAttack() == true end) end
    pcall(function() atk = red:isAttacking() == true end)
    return h2h, atk
end

local function threatZ(z, body)
    local alive = false
    pcall(function() alive = z:isAlive() and z:getHealth() > 0 end)
    return z ~= nil and z ~= body and alive and not isBodyZ(z) and not remoteZ(z) and not BridgeData.harmless(z)
end

local function target()
    local t = nil
    pcall(function() if BridgeFight ~= nil then t = BridgeFight.target end end)
    return t
end

local function nearTarget(body)
    local t = target()
    if t == nil then return false end
    local d = 99
    pcall(function() d = math.sqrt((t:getX() - body:getX()) ^ 2 + (t:getY() - body:getY()) ^ 2) end)
    return d <= BridgeCallout.MELEE_DIST
end

local DEFER = { EvKill = true }

local function trySay(event)
    local e = BridgeCallout.EVENTS[event]
    if e == nil then return false end
    if BridgeCallout.ENABLED == 0 then return false end
    if BridgeCallout.SAY[event] == 0 then return false end
    local gap = BridgeCallout.REPEAT_GAP * BridgeCallout.SEC
    if Bridge.time - BridgeCallout.lastAny < gap then return false end
    local said = false
    pcall(function() said = BridgeMoments.say(event, e.cooldown * BridgeCallout.SEC, true, e.slot) == true end)
    if said then
        BridgeCallout.lastAny = Bridge.time
        BridgeCallout.info = event
        log(event)
        local grp = "?"
        pcall(function() grp = BridgeMoments.group() end)
        dlog("said " .. event .. " (slot " .. tostring(e.slot) .. ", " .. tostring(grp)
            .. ", cd " .. tostring(e.cooldown) .. "s)")
    else
        BridgeCallout.info = "blocked " .. event
    end
    return said
end

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

local function dropCarLines()
    BridgeCallout.deferred = {}
    BridgeCallout.pendingKill = nil
    BridgeCallout.milestoneDue = nil
    BridgeCallout.wasFighting = false
    BridgeCallout.fightingAt = -99999
    BridgeCallout.finisherTarget = nil
    BridgeCallout.lastHealth = nil
end

local function say(event)
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

local function scanWorld(body, red)
    local facts = { horde = 0, near8 = 0, behind = false, flank = false, flankSide = nil,
        crawler = false, breach = false, spot = false }
    local S = BridgeCallout.SAY
    local wantHorde = S.EvHorde ~= 0
    local wantNear = S.EvLull ~= 0
    local wantBehind = S.EvBehind ~= 0
    local wantFlank = S.EvFlankLeft ~= 0 or S.EvFlankRight ~= 0
    local wantSpot = S.EvSpot ~= 0
    local wantCrawler = S.EvCrawler ~= 0
    local wantBreach = S.EvBreach ~= 0
    if not (wantHorde or wantNear or wantBehind or wantFlank or wantSpot or wantCrawler or wantBreach) then
        return facts
    end
    local t = (wantBehind or wantFlank or wantSpot) and target() or nil
    local fx, fy = nil, nil
    if wantFlank then
        local ax, ay = 0, 0
        pcall(function()
            local f = red:getForwardDirection()
            ax, ay = f:getX(), f:getY()
        end)
        local fl = math.sqrt(ax * ax + ay * ay)
        if fl >= 0.01 then fx, fy = ax / fl, ay / fl end
    end
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if threatZ(z, body) then
                local bx, by = z:getX() - body:getX(), z:getY() - body:getY()
                local bd2 = bx * bx + by * by
                if (wantHorde or wantNear) and math.abs(z:getZ() - body:getZ()) < 0.8 then
                    if wantHorde and bd2 < 4 * 4 then facts.horde = facts.horde + 1 end
                    if wantNear and bd2 < 8 * 8 then facts.near8 = facts.near8 + 1 end
                end
                if math.abs(z:getZ() - red:getZ()) < 1 then
                    local rx, ry = z:getX() - red:getX(), z:getY() - red:getY()
                    local rd2 = rx * rx + ry * ry
                    if wantBehind and not facts.behind and z ~= t
                        and rd2 < BridgeCallout.BEHIND_DIST * BridgeCallout.BEHIND_DIST then
                        local seeBody, seeRed = false, false
                        pcall(function() seeBody = body:CanSee(z) end)
                        pcall(function() seeRed = red:CanSee(z) end)
                        if seeBody and not seeRed then facts.behind = true end
                    end
                    if wantFlank and not facts.flank and z ~= t and fx ~= nil
                        and rd2 > 2.25 and rd2 < BridgeCallout.FLANK_DIST * BridgeCallout.FLANK_DIST then
                        local d = math.sqrt(rd2)
                        local cross = fx * (ry / d) - fy * (rx / d)
                        if math.abs(cross) >= 0.7 then
                            local seen = false
                            pcall(function() seen = red:CanSee(z) end)
                            if seen then
                                facts.flank = true
                                facts.flankSide = (cross * BridgeCallout.FLANK_SIGN) > 0 and "left" or "right"
                            end
                        end
                    end
                    if wantSpot and not facts.spot and z ~= t
                        and rd2 > BridgeCallout.SPOT_MIN_DIST * BridgeCallout.SPOT_MIN_DIST
                        and rd2 < BridgeCallout.SPOT_DIST * BridgeCallout.SPOT_DIST then
                        local seen = false
                        pcall(function() seen = BridgeFight.visible(z, red) end)
                        if seen then facts.spot = true end
                    end
                    if wantCrawler and not facts.crawler and proneZ(z)
                        and math.min(math.sqrt(bd2), math.sqrt(rd2)) < BridgeCallout.CRAWLER_DIST then
                        local seen = false
                        pcall(function() seen = red:CanSee(z) or body:CanSee(z) end)
                        if seen then facts.crawler = true end
                    end
                    if wantBreach and not facts.breach and tostring(z:getActionStateName()) == "thump"
                        and math.min(math.sqrt(bd2), math.sqrt(rd2)) < BridgeCallout.BREACH_DIST then
                        local seen = false
                        pcall(function() seen = red:CanSee(z) or body:CanSee(z) end)
                        if seen then facts.breach = true end
                    end
                end
            end
        end
    end)
    return facts
end

local function noZombiesInSight(red, body, dist)
    local clear = true
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= body and not isBodyZ(z) and not BridgeData.harmless(z) then
                local alive = false
                pcall(function() alive = z:isAlive() and z:getHealth() > 0 end)
                if alive then
                    local dx, dy = z:getX() - red:getX(), z:getY() - red:getY()
                    if dx * dx + dy * dy < dist * dist and math.abs(z:getZ() - red:getZ()) < 1 then
                        local seen = false
                        pcall(function() seen = red:CanSee(z) end)
                        if seen then clear = false return end
                    end
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
    if t == nil then return false end
    if t == BridgeCallout.finisherTarget then return false end
    local hp, low = 1, false
    pcall(function() hp = t:getHealth() low = hp <= BridgeCallout.FINISH_HP end)
    if low then BridgeCallout.finisherTarget = t return true end
    return false
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
    pcall(function() text = getTextOrNull(key) end)
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

function BridgeCallout.sayPriority(event)
    if BridgeCallout.ENABLED == 0 then return false end
    if carQuiet() then return false end
    local e = BridgeCallout.EVENTS[event]
    if e == nil then return false end
    if BridgeCallout.SAY[event] == 0 then return false end
    local gap = BridgeCallout.REPEAT_GAP * BridgeCallout.SEC
    if Bridge.time - BridgeCallout.lastAny < gap then
        BridgeCallout.info = "blocked " .. event
        return false
    end
    local said = false
    pcall(function() said = BridgeMoments.say(event, e.cooldown * BridgeCallout.SEC, true, e.slot) == true end)
    if said then
        BridgeCallout.lastAny = Bridge.time
        BridgeCallout.deferred = {}
        BridgeCallout.info = event
        log(event)
        dlog("said priority " .. event .. " (slot " .. tostring(e.slot) .. ")")
    else
        BridgeCallout.info = "blocked " .. event
    end
    return said
end

function BridgeCallout.aimClear(onMe)
    if onMe then return BridgeCallout.sayPriority("EvAimOnMe") end
    return BridgeCallout.sayPriority("EvAimClear")
end

function BridgeCallout.swingAtMe()
    return say("EvSwingAtMe")
end

function BridgeCallout.behind()
    return say("EvBehind")
end

function BridgeCallout.horde(n)
    if n ~= nil and n < BridgeCallout.HORDE_COUNT then return false end
    return say("EvHorde")
end

function BridgeCallout.spot()
    return say("EvSpot")
end

function BridgeCallout.lull()
    return say("EvLull")
end

function BridgeCallout.update(body)
    if body == nil then return end
    if carQuiet() then
        dropCarLines()
        BridgeCallout.info = "car"
        return
    end
    if BridgeCallout.ENABLED == 0 then return end
    if not Bridge.every(15) then return end
    if not Bridge.alive() then return end
    local red = BridgeData.owner()
    if red == nil then return end

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

    if flush() then return end

    local fighting = false
    pcall(function() if BridgeFight ~= nil then fighting = BridgeFight.state ~= "idle" end end)
    if fighting then
        BridgeCallout.wasFighting = true
        BridgeCallout.fightingAt = Bridge.time
        BridgeCallout.lastCombatAt = Bridge.time
    end
    if not fighting then BridgeCallout.finisherTarget = nil end
    local engaged = fighting or (Bridge.time - BridgeCallout.fightingAt < BridgeCallout.COMBAT_GRACE * BridgeCallout.SEC)

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
        end
        BridgeCallout.lastHealth = health
    end

    local facts = scanWorld(body, red)

    if facts.breach and say("EvBreach") then return end

    if fighting then
        if facts.behind and say("EvBehind") then return end
        if facts.flank and say(facts.flankSide == "left" and "EvFlankLeft" or "EvFlankRight") then return end
        if facts.horde >= BridgeCallout.HORDE_COUNT and say("EvHorde") then return end
        if facts.crawler and say("EvCrawler") then return end
        if BridgeCallout.SAY.EvFinisher ~= 0 and scanFinisher() and say("EvFinisher") then return end
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
        if facts.near8 == 0 and say("EvLull") then return end
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
        and noZombiesInSight(red, body, BridgeCallout.SWING_ZOMBIE_DIST)
        and swingingAtHer(red, body, attackingNow, prevAttack) then
        BridgeCallout.swingAtMe()
    end
    if not guard and not engaged and facts.spot then say("EvSpot") end
end

log("loaded")