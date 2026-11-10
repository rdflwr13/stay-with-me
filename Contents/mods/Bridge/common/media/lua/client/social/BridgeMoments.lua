








BridgeMoments = BridgeMoments or {}
BridgeMoments.cool = {}
BridgeMoments.known = nil
BridgeMoments.lastLine = -99999
BridgeMoments.lastCheck = 0
BridgeMoments.pending = {}
BridgeMoments.info = "none"

local GAP = 14400
local MINUTE = 3600
local SECOND = 60

BridgeMoments.MIN_GAP = 4 * SECOND

local SKILL = {
    SPR = true, LFT = true, NIM = true, SNE = true, BAA = true, BUA = true, CRP = true, COO = true,
    FRM = true, DOC = true, ELC = true, MTL = true, FKN = true, CRV = true, AIM = true, REL = true,
    FIS = true, TRA = true, FOR = true, TAI = true, MEC = true, CMB = true, SPE = true, SBU = true,
    LBA = true, SBA = true, MAS = true, POT = true, BLA = true, GLA = true, HUS = true, BUT = true,
    TRK = true, RCP = true,
}

local function teachesCodes(codes)
    if type(codes) ~= "string" or codes == "" then return false end
    for code in string.gmatch(codes, "([^,]+)") do
        if #code > 4 and SKILL[string.sub(code, 1, 3)] == true then return true end
    end
    return false
end


local HEALTH_STEPS = { 50, 30, 15 }
local HEALTH_EVENTS = { "EvHealthHalf", "EvDying", "EvDyingLast" }
local HEALTH_BACK = 10
BridgeMoments.healthStep = 0
BridgeMoments.drunkStep = 0
BridgeMoments.soberAt = nil

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeMoments] " .. tostring(text)) end end
local function warn(text) print("[BridgeMoments] " .. tostring(text)) end


function BridgeMoments.group()
    local r = BridgeData.relOf(Bridge.store)
    if r == nil then return "Far" end
    local romance = true
    pcall(function() romance = BridgeSocial.romanceOn() end)
    if (romance and r.r >= 40) or r.f >= 75 then return "Close" end
    if r.f >= 20 then return "Near" end
    return "Far"
end

BridgeMoments.poolSize = {}
local function count(pool)
    local n = BridgeMoments.poolSize[pool]
    if n ~= nil then return n end
    n = 0
    for i = 1, 20 do
        local key = "IGUI_NotAlone_Soc_" .. pool .. "_" .. i
        local found = false

        pcall(function() found = BridgeSpeech.exists(key) end)
        if not found then break end
        n = i
    end
    BridgeMoments.poolSize[pool] = n
    return n
end


function BridgeMoments.line(event, a, b)
    local group = BridgeMoments.group()
    local pool = event .. "_" .. group
    if count(pool) == 0 then pool = event .. "_Near" end
    local n = count(pool)
    if n == 0 then return nil end
    local text = nil
    for _ = 1, 4 do
        local index = 1 + ZombRand(n)
        pcall(function() index = BridgeSocial.pick(pool, n) end)
        local key = "IGUI_NotAlone_Soc_" .. pool .. "_" .. index
        pcall(function() key = BridgeSocial.lineKey(pool, index) end)
        pcall(function()
            if b ~= nil then text = BridgeSpeech.get(key, a, b)
            elseif a ~= nil then text = BridgeSpeech.get(key, a)
            else text = BridgeSpeech.get(key) end
        end)
        local again = false
        pcall(function() again = BridgeSocial.sameAsLast(text) end)
        if n < 2 or not again then break end
    end
    return text
end



function BridgeMoments.ready(slot, urgent)
    if Bridge.time < (BridgeMoments.cool[slot] or 0) then return false end


    if urgent == true then return true end

    if Bridge ~= nil and type(Bridge.speechBusy) == "function" and Bridge.speechBusy() then return false end
    if Bridge.time - (Bridge.lastSpokeAt or -99999) < BridgeMoments.MIN_GAP then return false end
    if urgent then return true end
    if Bridge.time - BridgeMoments.lastLine < GAP then return false end

    local social = -99999
    pcall(function() social = BridgeSocial.lastRemark or -99999 end)
    return Bridge.time - social >= 3600
end


function BridgeMoments.say(event, cooldown, urgent, slot)
    slot = slot or event
    if not BridgeMoments.ready(slot, urgent) then return false end
    local text = BridgeMoments.line(event)
    if text == nil then return false end
    BridgeMoments.cool[slot] = Bridge.time + cooldown
    BridgeMoments.lastLine = Bridge.time

    local quiet = false
    pcall(function() quiet = Bridge.quiet() end)
    if quiet then
        pcall(function() Bridge.bridgeEvent(event, text) end)
        BridgeMoments.info = event .. " quiet"
        log(event .. " quiet")
        return true
    end
    Bridge.speakText(text)
    local where = Bridge.lastSpokeWhere
    if where == "blocked" then
        BridgeMoments.info = event .. " hidden"
    elseif where == "grace" then
        BridgeMoments.info = event .. " held"
    else
        BridgeMoments.info = event
    end
    log(event .. " " .. BridgeMoments.group())
    return true
end


function BridgeMoments.recent(ticks)
    return Bridge.time - BridgeMoments.lastLine < (ticks or MINUTE)
end



local HUNDRED = { PAIN = true, PANIC = true, UNHAPPINESS = true, WETNESS = true, FOOD_SICKNESS = true, BOREDOM = true }
local function stat(red, name)
    local v = 0
    pcall(function() v = red:getStats():get(CharacterStat[name]) end)
    v = v or 0
    if HUNDRED[name] then v = v / 100 end
    return v
end

local function hasItem(body, red, types)
    local found = false
    local function look(inv)
        pcall(function()
            for _, t in ipairs(types) do
                if inv:getFirstTypeRecurse(t) ~= nil then found = true return end
            end
        end)
    end
    if body ~= nil then look(body:getInventory()) end
    if not found and red ~= nil then look(red:getInventory()) end
    return found
end

local function zombiesNear(red, dist)
    local near = false
    if red == nil then return false end
    local frame = nil
    pcall(function() if BridgeScan ~= nil then frame = BridgeScan.frame(Bridge.body, red) end end)
    if frame ~= nil then
        local entries = frame.entries or {}
        for i = 1, #entries do
            local e = entries[i]
            if e.alive and not e.comp and not e.harm and e.seenP
                and e.dp < dist and math.abs(e.zp) < 1 then
                near = true
                break
            end
        end
        return near
    end
    pcall(function()
        local list = nil
        if BridgeZScan ~= nil then
            list = BridgeZScan.near(red:getX(), red:getY(), dist, { tag = "moments.danger" })
        end
        if list == nil then list = getCell():getZombieList() end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= Bridge.body then
                local dx, dy = z:getX() - red:getX(), z:getY() - red:getY()
                if dx * dx + dy * dy < dist * dist and math.abs(z:getZ() - red:getZ()) < 1
                    and z:isAlive() and not z:getVariableBoolean(Bridge.BODY_VAR) and not BridgeData.harmless(z) then

                    local seen = true
                    pcall(function() seen = red:CanSee(z) end)
                    if seen then near = true break end
                end
            end
        end
    end)
    return near
end

local COLD_MOODLE, HOT_MOODLE = nil, nil
pcall(function() COLD_MOODLE = MoodleType.HYPOTHERMIA end)
if COLD_MOODLE == nil then pcall(function() COLD_MOODLE = MoodleType.Hypothermia end) end
pcall(function() HOT_MOODLE = MoodleType.HYPERTHERMIA end)
if HOT_MOODLE == nil then pcall(function() HOT_MOODLE = MoodleType.Hyperthermia end) end
local DRUNK_MOODLE = nil
pcall(function() DRUNK_MOODLE = MoodleType.DRUNK end)
if DRUNK_MOODLE == nil then pcall(function() DRUNK_MOODLE = MoodleType.Drunk end) end

local function moodle(red, m)
    if m == nil then return 0 end
    local lv = 0
    pcall(function() lv = red:getMoodles():getMoodleLevel(m) end)
    return tonumber(lv) or 0
end

local function nightNow()
    local n = false
    pcall(function() n = getGameTime():isNight() == true end)
    return n
end

local function wetWeather()
    local wet = false
    pcall(function()
        local c = getClimateManager()
        if c ~= nil then
            wet = c:getPrecipitationIntensity() > 0.05 or c:getSnowStrength() > 0.05
        end
    end)
    return wet
end

local function bleeding(red)
    local n = 0
    pcall(function() n = red:getBodyDamage():getNumPartsBleeding() end)
    return (tonumber(n) or 0) > 0
end

local function eatingNow(red)
    local eating = false
    pcall(function()
        local q = ISTimedActionQueue.getTimedActionQueue(red)
        if q ~= nil and q.current ~= nil and q.current.isEating == true then eating = true end
    end)
    return eating
end

local DRUNK_EVENTS = { "EvTipsy", "EvDrunk", "EvWasted" }

local INTOX_STAT = nil
pcall(function() INTOX_STAT = CharacterStat.INTOXICATION end)

local function intox(red)
    if INTOX_STAT == nil then return 0 end
    local v = 0
    pcall(function() v = red:getStats():get(INTOX_STAT) end)
    return tonumber(v) or 0
end

local function drinkingNow(red)
    local act = nil
    pcall(function()
        local q = ISTimedActionQueue.getTimedActionQueue(red)
        if q ~= nil then act = q.current end
    end)
    if act == nil or act.isEating ~= true then return false end
    local it = act.item
    if it == nil then return false end
    local alc = false
    pcall(function() alc = it:isAlcoholic() == true end)
    if not alc then pcall(function() alc = BridgeCare ~= nil and BridgeCare.fluidAlcohol(it) ~= nil end) end
    return alc
end

local SMELL_RADIUS = 8
local SMELL_TIERS = { 4, 8, 16 }
local function bodiesNear(red, radius)
    local n = 0
    pcall(function()
        local cell = getCell()
        local cx, cy, cz = math.floor(red:getX()), math.floor(red:getY()), math.floor(red:getZ())
        local r = tonumber(radius) or SMELL_RADIUS
        for dx = -r, r do
            for dy = -r, r do
                local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
                if sq ~= nil then
                    local bodies = nil
                    pcall(function() bodies = sq:getDeadBodys() end)
                    if bodies ~= nil then
                        local sz = 0
                        pcall(function() sz = bodies:size() end)
                        n = n + (tonumber(sz) or 0)
                    end
                end
            end
        end
    end)
    return n
end

local function smellTierOf(n)
    local best = nil
    for i = 1, #SMELL_TIERS do
        if n >= SMELL_TIERS[i] then best = SMELL_TIERS[i] end
    end
    return best
end






local FLAGS = { "bite", "bullet", "glass", "deep", "fracture", "burn", "cut", "scratch", "bleed" }
local function flagsOf(w)
    return { bite = w.bitten, bullet = w.bullet, glass = w.glass, deep = w.deep and not w.stitched,
             fracture = w.fracture, burn = w.burn, cut = w.cut, scratch = w.scratched, bleed = w.bleeding }
end

function BridgeMoments.freshWounds(wounds)
    local first = BridgeMoments.known == nil
    local known = BridgeMoments.known or {}
    BridgeMoments.known = known
    local fresh = {}
    local present = {}
    for _, w in ipairs(wounds) do
        local key = tostring(w.key)
        present[key] = true
        local k = known[key] or {}
        known[key] = k
        local f = flagsOf(w)
        local covered = w.bandaged or w.splint
        for _, name in ipairs(FLAGS) do
            if f[name] then

                if not k[name] and not first and not k.covered then fresh[name] = true end
                k[name] = true
            elseif not covered then
                k[name] = nil
            end
        end

        if covered then k.covered = true else k.covered = nil end
    end
    for key, _ in pairs(known) do
        if not present[key] then known[key] = nil end
    end
    return fresh
end


function BridgeMoments.available(p, b, range)
    if p == nil or b == nil then return false end
    if Bridge == nil or BridgeData == nil then return false end
    if type(Bridge.alive) == "function" and not Bridge.alive() then return false end
    if Bridge.hiddenSince ~= nil or Bridge.parked or Bridge.sleepParked ~= nil then return false end
    local asleep = false
    pcall(function() asleep = p:isAsleep() == true end)
    if asleep then return false end
    if BridgeTask ~= nil and type(BridgeTask.idleChatBlocked) == "function"
            and BridgeTask.idleChatBlocked() then return false end
    if BridgeFight ~= nil and (BridgeFight.target ~= nil
            or (BridgeFight.state ~= nil and BridgeFight.state ~= "idle")) then return false end
    if zombiesNear(p, 10) then return false end
    local d2 = (p:getX() - b:getX()) ^ 2 + (p:getY() - b:getY()) ^ 2
    if d2 > (range or 12) ^ 2 or math.abs(p:getZ() - b:getZ()) >= 1 then return false end
    return true
end

local function objCall(obj, name, ...)
    local fn = obj ~= nil and obj[name] or nil
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, obj, ...)
    if ok then return value end
    return nil
end

local function isA(obj, cls)
    if type(instanceof) ~= "function" then return false end
    local ok, value = pcall(instanceof, obj, cls)
    return ok and value == true
end

local deviceRoomCache = {}
local deviceRoomCount = 0
local DEVICE_ROOM_TICKS = 900

local function roomDevice(room, z)
    local tv, radio = false, false
    if room == nil then return tv, radio end
    local squares = objCall(room, "getSquares")
    if squares == nil then return tv, radio end
    local n = tonumber(objCall(squares, "size")) or 0
    for i = 0, n - 1 do
        local sq = objCall(squares, "get", i)
        local sz = objCall(sq, "getZ")
        if sz ~= nil and math.floor(sz) == z then
            local objs = objCall(sq, "getObjects")
            if objs ~= nil then
                local count = tonumber(objCall(objs, "size")) or 0
                for j = 0, count - 1 do
                    local o = objCall(objs, "get", j)
                    if o ~= nil then
                        local isTV = isA(o, "IsoTelevision")
                        local isRadio = false
                        if not isTV then isRadio = isA(o, "IsoRadio") end
                        if isTV or isRadio then
                            local dd = objCall(o, "getDeviceData")
                            if dd ~= nil then
                                local on = objCall(dd, "getIsTurnedOn") == true
                                local signal = objCall(dd, "isReceivingSignal") == true
                                if on and signal then
                                    if isTV then tv = true else radio = true end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return tv, radio
end

local function roomCacheKey(room, sq, z)
    local id = objCall(sq, "getRoomIDString")
    if id == nil then
        local num = objCall(sq, "getRoomID")
        if num ~= nil then id = tostring(num) end
    end
    if id == nil then return nil end
    local bid = nil
    local bld = objCall(room, "getBuilding")
    if bld ~= nil then bid = objCall(bld, "getID") end
    return tostring(bid or "-") .. "|" .. tostring(id) .. "@" .. tostring(z)
end

local function roomDeviceCached(room, sq, z)
    local key = roomCacheKey(room, sq, z)
    local now = Bridge ~= nil and tonumber(Bridge.time) or 0
    if key ~= nil then
        local rec = deviceRoomCache[key]
        if rec ~= nil and now - rec.at <= DEVICE_ROOM_TICKS then return rec.tv, rec.radio end
    end
    local tv, radio = roomDevice(room, z)
    if key ~= nil then
        if deviceRoomCache[key] == nil then
            deviceRoomCount = deviceRoomCount + 1
            if deviceRoomCount > 256 then
                for k in pairs(deviceRoomCache) do deviceRoomCache[k] = nil end
                deviceRoomCount = 1
            end
        end
        deviceRoomCache[key] = { at = now, tv = tv, radio = radio }
    end
    return tv, radio
end

function BridgeMoments.deviceTick(red, body, danger, busy, fightNow, say)
    if red == nil or body == nil then return false end
    if danger or busy or fightNow then return false end
    if Bridge == nil then return false end
    if Bridge.time < (BridgeMoments.deviceAt or 0) then return false end
    BridgeMoments.deviceAt = Bridge.time + 300
    local sq = nil
    pcall(function() sq = red:getCurrentSquare() end)
    if sq == nil then return false end
    local room = nil
    pcall(function() room = sq:getRoom() end)
    if room == nil then return false end
    local tv, radio = roomDeviceCached(room, sq, math.floor(red:getZ()))
    if tv then
        if BridgeMoments.lastShowAt == nil or Bridge.time - BridgeMoments.lastShowAt >= 30 * 60 then
            if say("EvIdleWorldTV", 10 * MINUTE, false, "IdleWorldTV") then return true end
        end
        return false
    end
    if radio then
        local inCar = false
        pcall(function() inCar = red:getVehicle() ~= nil end)
        if not inCar and say("EvIdleWorldRadio", 10 * MINUTE, false, "IdleWorldRadio") then return true end
    end
    return false
end

function BridgeMoments.onDeviceText(guid, codes, x, y, z, line)
    if Bridge == nil then return end
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return end
    if x == -1 and y == -1 and z == -1 then return end
    local p = nil
    if BridgeData ~= nil and type(BridgeData.owner) == "function" then p = BridgeData.owner() end
    local b = Bridge.body
    if p == nil or b == nil then return end
    if not BridgeMoments.available(p, b, 12) then return end
    local psq = nil
    pcall(function() psq = p:getCurrentSquare() end)
    local dsq = nil
    pcall(function() dsq = getCell():getGridSquare(x, y, z) end)
    if psq == nil or dsq == nil then return end
    local proom, droom = nil, nil
    pcall(function() proom = psq:getRoom() end)
    pcall(function() droom = dsq:getRoom() end)
    if proom == nil or droom ~= proom then return end
    local tv = false
    pcall(function()
        local objs = dsq:getObjects()
        if objs == nil then return end
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            if o ~= nil and instanceof(o, "IsoTelevision") then tv = true return end
        end
    end)
    if not tv then return end
    if not teachesCodes(codes) then return end
    if BridgeMoments.say("EvIdleTVShow", 5 * MINUTE, "soft", "IdleTVShow") then
        BridgeMoments.lastShowAt = Bridge.time
    end
end

function BridgeMoments.update(body)
    if Bridge.time - BridgeMoments.lastCheck < 30 then return end
    BridgeMoments.lastCheck = Bridge.time
    local red = BridgeData.owner()
    if red == nil then return end
    local near = false
    pcall(function()
        local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
        near = dx * dx + dy * dy < 144 and math.abs(red:getZ() - body:getZ()) < 1
    end)
    if not near then return end
    local asleep = false
    pcall(function() asleep = red:isAsleep() end)
    if asleep then return end

    local momentSay = BridgeMoments.say
    local sayBlocked = false
    if BridgeTask ~= nil and BridgeTask.idleChatBlocked ~= nil and BridgeTask.idleChatBlocked() then
        sayBlocked = true
        momentSay = function() return false end
    end




    local wounds = {}
    pcall(function() wounds = BridgeHeal.scan(red) end)
    local fresh = BridgeMoments.freshWounds(wounds)
    local names = {}
    for k, _ in pairs(fresh) do
        names[#names + 1] = k
        BridgeMoments.pending[k] = Bridge.time
    end
    if #names > 0 then
        table.sort(names)
        log("new wounds: " .. table.concat(names, ","))
        BridgeMoments.info = "new " .. table.concat(names, ",")
    end
    for k, at in pairs(BridgeMoments.pending) do
        if Bridge.time - at > 3 * MINUTE then BridgeMoments.pending[k] = nil end
    end
    local present = {}
    for _, w in ipairs(wounds) do
        for name, on in pairs(flagsOf(w)) do
            if on and not (w.bandaged or w.splint) then present[name] = true end
        end
    end

    local danger = zombiesNear(red, 10)
    local busy = false
    pcall(function() busy = BridgeFight.state ~= "idle" or BridgeHeal.active end)
    local fightNow = false
    pcall(function() fightNow = BridgeFight.state ~= "idle" end)


    local health = 100
    pcall(function() health = red:getBodyDamage():getOverallBodyHealth() end)
    health = tonumber(health) or 100
    while BridgeMoments.healthStep > 0 and health >= HEALTH_STEPS[BridgeMoments.healthStep] + HEALTH_BACK do
        BridgeMoments.healthStep = BridgeMoments.healthStep - 1
    end
    local step = 0
    for i, limit in ipairs(HEALTH_STEPS) do
        if health < limit then step = i end
    end
    if step > BridgeMoments.healthStep then
        BridgeMoments.healthStep = step



        local event = HEALTH_EVENTS[step]
        if not (danger or fightNow) then event = event .. "Quiet" end
        if momentSay(event, 0, true, "Health" .. step) then return end
    end
    if danger or fightNow then


        if fresh.bite then
            if momentSay("EvFightBite", 20 * 60, true) then return end
        end
        if fresh.deep or fresh.glass or fresh.bullet or fresh.bleed then
            momentSay("EvFightHurt", 15 * 60, true)
        end
        return
    end

    local function has(kind)
        local yes = true
        pcall(function() yes = BridgeHeal.hasFor(body, red, kind) end)
        return yes
    end



    local autoHeal = true
    pcall(function() autoHeal = BridgeData.optionOf(Bridge.store, "autoHeal") end)
    local function wound(name, slot, cooldown, lackKind, withLack)
        local at = BridgeMoments.pending[name]
        if at == nil then return false end

        if not BridgeMoments.ready(slot, true) then BridgeMoments.pending[name] = nil return false end


        if not present[name] and Bridge.time - at > 30 * 60 then return false end
        if sayBlocked then return false end
        local event = slot
        if lackKind ~= nil and not has(lackKind) then event = withLack end
        if not autoHeal then event = "EvHurtAsk" end

        if event == false then return false end
        if momentSay(event, cooldown, true, slot) then

            BridgeMoments.pending = {}
            return true
        end
        return false
    end

    if wound("bite", "EvBite", 30 * MINUTE) then return end
    if wound("bullet", "EvBullet", 2 * MINUTE, "bullet", "EvBulletNoTools") then return end
    if wound("glass", "EvGlass", 2 * MINUTE, "glass", "EvGlassNoTweezers") then return end
    if wound("deep", "EvDeep", 2 * MINUTE, "suture", "EvDeepNoSuture") then return end
    if wound("fracture", "EvFracture", 5 * MINUTE, "splint", "EvFractureNoSplint") then return end


    if wound("burn", "EvBurn", 3 * MINUTE, "burn", false) then return end

    if wound("cut", "EvCut", 2 * MINUTE, "bandage", "EvBleedNoBandage") then return end
    if wound("scratch", "EvScratch", 3 * MINUTE) then return end
    if wound("bleed", "EvBleed", 2 * MINUTE, "bandage", "EvBleedNoBandage") then return end


    if bleeding(red) then
        local ev = has("bandage") and "EvBleed" or "EvBleedNoBandage"
        if not autoHeal then ev = "EvHurtAsk" end
        if momentSay(ev, 2 * MINUTE, true, "EvBleed") then return end
    end



    if stat(red, "PANIC") > 0.5 then
        if momentSay("EvPanic", 5 * MINUTE, true) then return end
    end
    if busy then return end
    local affectionRel = nil
    pcall(function() affectionRel = BridgeData.relOf(Bridge.store) end)
    if affectionRel ~= nil then
        local seenNow = 0
        pcall(function() seenNow = tonumber(affectionRel.seen) or 0 end)
        local seenPrev = BridgeMoments.seenSnap
        BridgeMoments.seenSnap = seenNow
        if seenPrev ~= nil and seenNow > seenPrev then
            local away = seenNow - seenPrev
            if away > 24 and affectionRel.f >= 30 then
                if momentSay("EvAffectionReunion", 120 * MINUTE, false, "AffectionReunion") then return end
            end
        end
        local hurting = stat(red, "STRESS") > 0.55 or stat(red, "UNHAPPINESS") > 0.4
            or stat(red, "PAIN") > 0.45
        local fought = false
        pcall(function() fought = BridgeSocial.recentFight() == true end)
        if affectionRel.f >= 30 and (hurting or fought) then
            if momentSay("EvAffectionComfort", 45 * MINUTE, false, "AffectionComfort") then return end
        end
        local relaxed = false
        pcall(function() relaxed = BridgeSocial.relaxed(affectionRel) == true end)
        local romance = false
        pcall(function() romance = BridgeSocial.romanceOpen(affectionRel) == true end)
        local world = 0
        pcall(function() world = getGameTime():getWorldAgeHours() end)
        local day = math.floor((tonumber(world) or 0) / 24)
        if relaxed and romance and affectionRel.f >= 45 and affectionRel.r >= 30
                and nightNow() and BridgeMoments.dateDay ~= day then
            if momentSay("EvAffectionDate", 90 * MINUTE, false, "AffectionDate") then
                BridgeMoments.dateDay = day
                return
            end
        end
    end
    if wetWeather() and stat(red, "WETNESS") > 0.6 then
        if momentSay("EvColdWet", 20 * MINUTE) then return end
    end
    if nightNow() and stat(red, "FATIGUE") > 0.6 then
        if momentSay("EvTiredNight", 20 * MINUTE) then return end
    end
    if stat(red, "PAIN") > 0.45 then
        local pills = false
        if not sayBlocked and BridgeMoments.ready("Pain", false) then
            pills = hasItem(body, red, { "Base.Pills" })
        end
        if momentSay(pills and "EvPain" or "EvPainNoPills", 15 * MINUTE, false, "Pain") then return end
    end
    if stat(red, "SICKNESS") > 0.3 or stat(red, "FOOD_SICKNESS") > 0.3 then
        if momentSay("EvSick", 20 * MINUTE) then return end
    end
    if stat(red, "UNHAPPINESS") > 0.4 or stat(red, "STRESS") > 0.55 then
        if momentSay("EvSad", 25 * MINUTE) then return end
    end
    if stat(red, "THIRST") > 0.35 then
        if momentSay("EvThirsty", 20 * MINUTE) then return end
    end
    if stat(red, "HUNGER") > 0.35 then
        if momentSay("EvHungry", 20 * MINUTE) then return end
    end
    if stat(red, "FATIGUE") > 0.6 then
        if momentSay("EvTired", 20 * MINUTE) then return end
    end
    if stat(red, "WETNESS") > 0.6 then
        if momentSay("EvCold", 20 * MINUTE) then return end
    end
    if stat(red, "BOREDOM") > 0.6 then
        if momentSay("EvBored", 20 * MINUTE) then return end
    end
    if moodle(red, COLD_MOODLE) >= 1 then
        if momentSay("EvFreezing", 20 * MINUTE) then return end
    end
    if moodle(red, HOT_MOODLE) >= 1 then
        if momentSay("EvOverheat", 20 * MINUTE) then return end
    end
    local inCar = false
    pcall(function() inCar = red:getVehicle() ~= nil end)
    if not inCar then
        local drunkMoodle = 0
        pcall(function() drunkMoodle = red:getMoodles():getMoodleLevel(DRUNK_MOODLE) end)
        drunkMoodle = tonumber(drunkMoodle) or 0
        local drunkLevel = intox(red)
        local drunkTier = 0
        if drunkMoodle >= 3 or drunkLevel >= 70 then
            drunkTier = 3
        elseif drunkMoodle >= 2 or drunkLevel >= 40 then
            drunkTier = 2
        elseif drunkMoodle >= 1 or drunkLevel >= 15 then
            drunkTier = 1
        end
        if drunkTier > (BridgeMoments.drunkStep or 0) then
            BridgeMoments.soberAt = nil
            if momentSay(DRUNK_EVENTS[drunkTier], 25 * MINUTE, false, "Drunk" .. drunkTier) then
                BridgeMoments.drunkStep = drunkTier
                return
            end
        elseif drunkTier == 0 then
            if BridgeMoments.soberAt == nil then BridgeMoments.soberAt = Bridge.time end
            if Bridge.time - BridgeMoments.soberAt > 5 * MINUTE then BridgeMoments.drunkStep = 0 end
        else
            BridgeMoments.soberAt = nil
        end
        if drinkingNow(red) then
            if momentSay("EvDrinking", 20 * MINUTE, false, "Drink") then return end
        elseif eatingNow(red) then
            if momentSay("EvEating", 20 * MINUTE) then return end
        end
    end
    local smell = BridgeMoments.smellTier
    if Bridge.time >= (BridgeMoments.smellAt or 0) then
        BridgeMoments.smellAt = Bridge.time + 120
        smell = smellTierOf(bodiesNear(red, SMELL_RADIUS))
        BridgeMoments.smellTier = smell
    end
    if smell ~= nil then
        if momentSay("EvSmell" .. smell, 10 * MINUTE, false, "Smell" .. smell) then return end
    end

    if BridgeMoments.deviceTick(red, body, danger, busy, fightNow, momentSay) then return end
end

if Events ~= nil and Events.OnDeviceText ~= nil and not BridgeMoments.deviceTextHooked then
    BridgeMoments.deviceTextHooked = true
    Events.OnDeviceText.Add(BridgeMoments.onDeviceText)
end

log("loaded")
