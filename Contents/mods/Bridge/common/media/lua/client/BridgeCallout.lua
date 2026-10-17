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

BridgeCallout.PLACE_GAP = 60 * 60
BridgeCallout.PLACE_DWELL = 3 * 60
BridgeCallout.PLACE_NEAR = 12

BridgeCallout.HOME_EVENT = "EvHomeReturn"
BridgeCallout.HOME_NEAR = 12
BridgeCallout.HOME_WITH = 12
BridgeCallout.HOME_HOURS = 1.0
BridgeCallout.HOME_GAP = 60 * 60

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

BridgeCallout.AMBIENT = { "EvTaunt" }


BridgeCallout.ENABLED = 1


BridgeCallout.DEBUG = 0


BridgeCallout.SAY = {
    EvBehind     = 0,
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
    EvHorde4     = { slot = "Horde4",     cooldown = 75 },
    EvHorde8     = { slot = "Horde8",     cooldown = 90 },
    EvHorde16    = { slot = "Horde16",    cooldown = 120 },
    EvHorde32    = { slot = "Horde32",    cooldown = 150 },
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

-- inclRemote == true keeps remote zombies in scope (used by the swing-clear
-- close-threat check); otherwise remote zombies are ignored (main callout facts).
local function threatZ(z, body, inclRemote)
    local alive = false
    pcall(function() alive = z:isAlive() and z:getHealth() > 0 end)
    return z ~= nil and z ~= body and alive and not isBodyZ(z)
        and (inclRemote == true or not remoteZ(z)) and not BridgeData.harmless(z)
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


-- Shared gate for every callout. `priority` (BridgeCallout.sayPriority) also
-- respects carQuiet, drops the deferred queue on success, and marks gap-blocks.
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

local function dropCarLines()
    BridgeCallout.deferred = {}
    BridgeCallout.pendingKill = nil
    BridgeCallout.milestoneDue = nil
    BridgeCallout.wasFighting = false
    BridgeCallout.fightingAt = -99999
    BridgeCallout.finisherTarget = nil
    BridgeCallout.lastHealth = nil
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

-- Reused across scans to avoid allocating a table every update.
local scanFacts = { near8 = 0, behind = false, flank = false, flankSide = nil,
    crawler = false, breach = false, spot = false, anyThreatInSwing = false }

local function scanWorld(body, red, wantClear)
    local facts = scanFacts
    facts.near8 = 0
    facts.behind = false
    facts.flank = false
    facts.flankSide = nil
    facts.crawler = false
    facts.breach = false
    facts.spot = false
    facts.anyThreatInSwing = false

    local S = BridgeCallout.SAY
    local wantNear = S.EvLull ~= 0
    local wantBehind = S.EvBehind ~= 0
    local wantFlank = S.EvFlankLeft ~= 0 or S.EvFlankRight ~= 0
    local wantSpot = S.EvSpot ~= 0
    local wantCrawler = S.EvCrawler ~= 0
    local wantBreach = S.EvBreach ~= 0
    local wantBody = wantNear
    local wantRed = wantBehind or wantFlank or wantSpot or wantCrawler or wantBreach
    if not (wantBody or wantRed or wantClear) then
        return facts
    end

    local near2 = 8 * 8
    local behind2 = BridgeCallout.BEHIND_DIST * BridgeCallout.BEHIND_DIST
    local flank2 = BridgeCallout.FLANK_DIST * BridgeCallout.FLANK_DIST
    local spotMin2 = BridgeCallout.SPOT_MIN_DIST * BridgeCallout.SPOT_MIN_DIST
    local spot2 = BridgeCallout.SPOT_DIST * BridgeCallout.SPOT_DIST
    local crawler2 = BridgeCallout.CRAWLER_DIST * BridgeCallout.CRAWLER_DIST
    local breach2 = BridgeCallout.BREACH_DIST * BridgeCallout.BREACH_DIST
    local swing2 = BridgeCallout.SWING_ZOMBIE_DIST * BridgeCallout.SWING_ZOMBIE_DIST

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

    local bodyx, bodyy, bodyz = 0, 0, 0
    local redx, redy, redz = 0, 0, 0
    pcall(function() bodyx, bodyy, bodyz = body:getX(), body:getY(), body:getZ() end)
    pcall(function() redx, redy, redz = red:getX(), red:getY(), red:getZ() end)

    pcall(function()
        local list = getCell():getZombieList()
        local n = list:size()
        for i = 0, n - 1 do
            local z = nil
            pcall(function() z = list:get(i) end)
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

                    -- Cheap relevance cull so distant/other-floor zombies skip the
                    -- pcall-heavy threatZ/CanSee work (superset of every enabled check).
                    local relevant = false
                    if wantNear and math.abs(dzBody) < 0.8 and bd2 < near2 then
                        relevant = true
                    end
                    if not relevant and wantRed and inRedBand and (rd2 < spot2 or bd2 < breach2) then
                        relevant = true
                    end
                    local clearRel = wantClear and inRedBand and rd2 < swing2

                    if relevant or clearRel then
                        -- inclRemote keeps the swing-clear check identical to the old
                        -- noZombiesInSight predicate; the main facts exclude remote.
                        if threatZ(z, body, true) then
                            local isRemote = remoteZ(z)
                            if relevant and not isRemote then
                                if wantNear and math.abs(dzBody) < 0.8 and bd2 < near2 then
                                    facts.near8 = facts.near8 + 1
                                end
                                if inRedBand then
                                    if wantBehind and not facts.behind and z ~= t and rd2 < behind2 then
                                        local seeBody, seeRed = false, false
                                        pcall(function() seeBody = body:CanSee(z) end)
                                        pcall(function() seeRed = red:CanSee(z) end)
                                        if seeBody and not seeRed then facts.behind = true end
                                    end
                                    if wantFlank and not facts.flank and z ~= t and fx ~= nil
                                        and rd2 > 2.25 and rd2 < flank2 then
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
                                        and rd2 > spotMin2 and rd2 < spot2 then
                                        local seen = false
                                        pcall(function() seen = BridgeFight.visible(z, red) end)
                                        if seen then facts.spot = true end
                                    end
                                    if wantCrawler and not facts.crawler and proneZ(z)
                                        and math.min(bd2, rd2) < crawler2 then
                                        local seen = false
                                        pcall(function() seen = red:CanSee(z) or body:CanSee(z) end)
                                        if seen then facts.crawler = true end
                                    end
                                    if wantBreach and not facts.breach and tostring(z:getActionStateName()) == "thump"
                                        and math.min(bd2, rd2) < breach2 then
                                        local seen = false
                                        pcall(function() seen = red:CanSee(z) or body:CanSee(z) end)
                                        if seen then facts.breach = true end
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
    return attempt(event, true)
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


local function homeAreaHas(home, x, y, margin)
    if home == nil then return false end
    local x1, y1 = home.x - margin, home.y - margin
    local x2, y2 = home.x + home.w - 1 + margin, home.y + home.h - 1 + margin
    return x >= x1 and x <= x2 and y >= y1 and y <= y2
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
    local bx, by = nil, nil
    pcall(function() bx, by = body:getX(), body:getY() end)
    if bx == nil or by == nil then return false end
    if not homeAreaHas(home, bx, by, BridgeCallout.HOME_NEAR) then return false end
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

    local bx, by = nil, nil
    pcall(function() bx, by = body:getX(), body:getY() end)
    if bx == nil or by == nil then return end

    local atHome = homeAreaHas(home, bx, by, BridgeCallout.HOME_NEAR)

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
        local text = nil
        pcall(function() text = getTextOrNull(key, "", "") end)
        if text == nil or text == key or text == "" then break end
        n = i
    end
    return n
end


function BridgeCallout.homeStatus()
    local h = BridgeHome ~= nil and BridgeHome.get() or nil
    local loc = "none"
    if h ~= nil then loc = string.format("%d,%d z%d %dx%d", h.x, h.y, h.z, h.w, h.h) end
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
        local bx, by = nil, nil
        if body ~= nil then pcall(function() bx, by = body:getX(), body:getY() end) end
        local atHome = home ~= nil and bx ~= nil and homeAreaHas(home, bx, by, BridgeCallout.HOME_NEAR)
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
        return string.format("home set %d,%d z%d %dx%d", got.x, got.y, got.z, got.w, got.h)
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

    return "home [status | why | set [x y z w h] | clear | away <hours> | fire | exit | reset]"
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


function BridgeCallout.update(body)
    if body == nil then return end
    local scanDue = Bridge.every(15)
    -- homeTrack accumulates from world-age deltas, so sampling it at the scan
    -- cadence (not every frame) keeps the same result. carQuiet stays per-frame
    -- because it guards flush()/dropCarLines() ordering.
    if scanDue and type(BridgeCallout.homeTrack) == "function" then
        pcall(function() BridgeCallout.homeTrack(body, BridgeData.owner()) end)
    end
    if carQuiet() then
        dropCarLines()
        BridgeCallout.info = "car"
        return
    end
    if BridgeCallout.ENABLED == 0 then return end
    if not scanDue then return end
    if not Bridge.alive() then return end
    local red = BridgeData.owner()
    if red == nil then return end

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

    -- Unified horde tiers are a priority line in both idle and combat.
    if BridgeHorde ~= nil then
        local SAY = BridgeCallout.SAY
        if SAY.EvHorde32 ~= 0 or SAY.EvHorde16 ~= 0 or SAY.EvHorde8 ~= 0 or SAY.EvHorde4 ~= 0 then
            local hx, hy, hz = nil, nil, nil
            pcall(function() hx, hy, hz = red:getX(), red:getY(), red:getZ() end)
            if hx ~= nil then
                local n = BridgeHorde.count(hx, hy, hz, BridgeHorde.RADIUS)
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
    end

    local facts = scanWorld(body, red, not engaged)

    if facts.breach and say("EvBreach") then return end

    if fighting then
        if facts.behind and say("EvBehind") then return end
        if facts.flank and say(facts.flankSide == "left" and "EvFlankLeft" or "EvFlankRight") then return end
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
        and not facts.anyThreatInSwing
        and swingingAtHer(red, body, attackingNow, prevAttack) then
        BridgeCallout.swingAtMe()
    end
    if not guard and not engaged and facts.spot then say("EvSpot") end
end

log("loaded")