
BridgeDrive = BridgeDrive or {}

BridgeDrive.SEC = 60


BridgeDrive.ENABLED = 1



BridgeDrive.ON = {
    CRASH  = 1,
    HURT   = 1,
    AHEAD  = 1,
    FAST   = 1,
    ZOMBIE = 1,
    GREET  = 1,
    ANIMAL = 1,
    EXIT   = 1,
    STATE  = 1,
    ROADKILL = 1,
    WEATHER = 1,
    DARK    = 1,
    SMELL   = 1,
    SICK    = 1,
}







BridgeDrive.GAP = 12

BridgeDrive.FAST_KMH     = 70 * 1.609344
BridgeDrive.RECKLESS_KMH = 90 * 1.609344



BridgeDrive.CRASH_MIN_KMH = 25
BridgeDrive.CRASH_LIGHT   = 30
BridgeDrive.CRASH_HARD    = 45
BridgeDrive.CRASH_HP_DROP = 5
BridgeDrive.CRASH_WINDOW  = 30
BridgeDrive.HURT_HP_DROP  = 5


BridgeDrive.SCAN_MIN    = 6
BridgeDrive.SCAN_MAX    = 22
BridgeDrive.SCAN_HALF   = 2.5
BridgeDrive.HORDE_COUNT = 4
BridgeDrive.SCAN_EVERY  = 15



BridgeDrive.GREET_DELAY  = 150
BridgeDrive.GREET_RADIUS = 8



BridgeDrive.ANIMAL_MIN    = 8
BridgeDrive.ANIMAL_MAX    = 30
BridgeDrive.ANIMAL_HALF   = 15
BridgeDrive.ANIMAL_EVERY  = 30
BridgeDrive.ANIMAL_REPEAT = 600


BridgeDrive.EXIT_RADIUS = 8


BridgeDrive.STATE_EVERY      = 300
BridgeDrive.ROADKILL_MIN_KMH = 15
BridgeDrive.EAT_EVERY        = 60


BridgeDrive.WEATHER_CHECK = 30
BridgeDrive.RAIN_ON    = 0.05
BridgeDrive.RAIN_OFF   = 0.02
BridgeDrive.RAIN_HEAVY = 0.7
BridgeDrive.SNOW_ON    = 0.05
BridgeDrive.SNOW_OFF   = 0.02
BridgeDrive.FOG        = 0.4
BridgeDrive.WIND       = 0.5


BridgeDrive.SMELL_EVERY  = 60
BridgeDrive.SMELL_RADIUS = 4


BridgeDrive.CORPSE_SICK_MIN    = 0.3
BridgeDrive.CORPSE_SICK_RADIUS = 8
BridgeDrive.CORPSE_EMOTE_GAP   = 600







local STAT_OF = {}
pcall(function()
    STAT_OF.FATIGUE       = CharacterStat.FATIGUE
    STAT_OF.HUNGER        = CharacterStat.HUNGER
    STAT_OF.THIRST        = CharacterStat.THIRST
    STAT_OF.PANIC         = CharacterStat.PANIC
    STAT_OF.SICKNESS      = CharacterStat.SICKNESS
    STAT_OF.FOOD_SICKNESS = CharacterStat.FOOD_SICKNESS
    STAT_OF.UNHAPPINESS   = CharacterStat.UNHAPPINESS
    STAT_OF.STRESS        = CharacterStat.STRESS
    STAT_OF.WETNESS       = CharacterStat.WETNESS
end)
local HUNDRED = { PAIN = true, PANIC = true, UNHAPPINESS = true, WETNESS = true, FOOD_SICKNESS = true }

local function statOf(red, name)
    local st = STAT_OF[name]
    if st == nil then pcall(function() st = CharacterStat[name] end) end
    if st == nil then return 0 end
    local v = 0
    pcall(function() v = red:getStats():get(st) end)
    v = tonumber(v) or 0
    if HUNDRED[name] then v = v / 100 end
    return v
end


local function bleeding(red)
    local n = 0
    pcall(function() n = red:getBodyDamage():getNumPartsBleeding() end)
    return (tonumber(n) or 0) > 0
end


BridgeDrive.STATES = {
    { key = "Hurt",    test = function(red) return bleeding(red) end },
    { key = "Panic",   test = function(red) return statOf(red, "PANIC") > 0.5 end },
    { key = "Sick",    test = function(red) return statOf(red, "SICKNESS") > 0.3 or statOf(red, "FOOD_SICKNESS") > 0.3 end },
    { key = "Tired",   test = function(red) return statOf(red, "FATIGUE") > 0.6 end },
    { key = "Thirsty", test = function(red) return statOf(red, "THIRST") > 0.35 end },
    { key = "Hungry",  test = function(red) return statOf(red, "HUNGER") > 0.35 end },
    { key = "Cold",    test = function(red) return statOf(red, "WETNESS") > 0.6 end },
    { key = "Sad",     test = function(red) return statOf(red, "UNHAPPINESS") > 0.4 or statOf(red, "STRESS") > 0.55 end },
}






BridgeDrive.EVENTS = {
    EvCarCrash     = { slot = "DriveCrash",     cooldown = 60,  urgent = true,  cat = "CRASH" },
    EvCarCrashHard = { slot = "DriveCrashHard", cooldown = 300, urgent = true,  cat = "CRASH" },
    EvCarHurt      = { slot = "DriveHurt",      cooldown = 120, urgent = true,  cat = "HURT" },
    EvCarAhead     = { slot = "DriveAhead",     cooldown = 45,  urgent = true,  cat = "AHEAD" },
    EvCarZombie    = { slot = "DriveZombie",    cooldown = 40,  urgent = false, cat = "ZOMBIE" },
    EvCarHorde     = { slot = "DriveHorde",     cooldown = 90,  urgent = false, cat = "ZOMBIE" },
    EvCarFast      = { slot = "DriveFast",      cooldown = 120, urgent = false, cat = "FAST" },
    EvCarReckless  = { slot = "DriveReckless",  cooldown = 120, urgent = false, cat = "FAST" },
    EvCarGreetClear   = { slot = "DriveGreetClear",   cooldown = 300, urgent = true, cat = "GREET" },
    EvCarGreetZombies = { slot = "DriveGreetZombies", cooldown = 300, urgent = true, cat = "GREET" },
    EvCarAnimal    = { slot = "DriveAnimal",    cooldown = 45,  urgent = false, cat = "ANIMAL" },
    EvCarExitClear   = { slot = "CarExitClear",   cooldown = 300, urgent = true, cat = "EXIT" },
    EvCarExitZombies = { slot = "CarExitZombies", cooldown = 300, urgent = true, cat = "EXIT" },
    EvCarRoadkill  = { slot = "DriveRoadkill",  cooldown = 60,  urgent = true,  cat = "ROADKILL" },
    EvCarRain         = { slot = "DriveRain",        cooldown = 300,  urgent = false, cat = "WEATHER" },
    EvCarRainHeavy    = { slot = "DriveRainHeavy",   cooldown = 600,  urgent = true,  cat = "WEATHER" },
    EvCarRainStop     = { slot = "DriveRainStop",    cooldown = 300,  urgent = false, cat = "WEATHER" },
    EvCarSnow         = { slot = "DriveSnow",        cooldown = 600,  urgent = false, cat = "WEATHER" },
    EvCarBlizzard     = { slot = "DriveBlizzard",    cooldown = 600,  urgent = true,  cat = "WEATHER" },
    EvCarStorm        = { slot = "DriveStorm",       cooldown = 600,  urgent = true,  cat = "WEATHER" },
    EvCarFog          = { slot = "DriveFog",         cooldown = 600,  urgent = false, cat = "WEATHER" },
    EvCarWindy        = { slot = "DriveWindy",       cooldown = 900,  urgent = false, cat = "WEATHER" },
    EvCarLightning    = { slot = "DriveLightning",   cooldown = 180,  urgent = true,  cat = "WEATHER" },
    EvCarWeatherIn    = { slot = "DriveWeatherIn",   cooldown = 300,  urgent = true,  cat = "WEATHER" },
    EvCarNightFalls   = { slot = "DriveNightFalls",  cooldown = 1200, urgent = false, cat = "DARK" },
    EvCarDawn         = { slot = "DriveDawn",        cooldown = 1200, urgent = false, cat = "DARK" },
    EvCarColdWet      = { slot = "DriveColdWet",     cooldown = 600,  urgent = true,  cat = "STATE" },
    EvCarTiredNight   = { slot = "DriveTiredNight",  cooldown = 600,  urgent = true,  cat = "STATE" },
    EvCarEating       = { slot = "DriveEating",      cooldown = 120,  urgent = true,  cat = "STATE" },
    EvCarSmell        = { slot = "DriveSmell",        cooldown = 300,  urgent = false, cat = "SMELL" },
    EvCarCorpseSick   = { slot = "DriveCorpseSick",   cooldown = 300,  urgent = true,  cat = "SICK" },
}


for _, s in ipairs(BridgeDrive.STATES) do
    local k = s.key
    BridgeDrive.EVENTS["EvCar" .. k .. "In"]    = { slot = "DriveState" .. k .. "In",    cooldown = 600, urgent = true,  cat = "STATE" }
    BridgeDrive.EVENTS["EvCar" .. k .. "Drive"] = { slot = "DriveState" .. k .. "Drive", cooldown = 600, urgent = false, cat = "STATE" }
    BridgeDrive.EVENTS["EvCar" .. k .. "Out"]   = { slot = "DriveState" .. k .. "Out",   cooldown = 600, urgent = true,  cat = "STATE" }
end

BridgeDrive.lastAny = -99999
BridgeDrive.hpBase = nil
BridgeDrive.peak = nil
BridgeDrive.peakAt = 0
BridgeDrive.crashArmed = true
BridgeDrive.fastSaid = false
BridgeDrive.recklessSaid = false
BridgeDrive.greetAt = nil
BridgeDrive.greetDone = false
BridgeDrive.info = "none"

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeDrive] " .. tostring(text)) end end


local function reset()
    BridgeDrive.hpBase = nil
    BridgeDrive.peak = nil
    BridgeDrive.peakAt = 0
    BridgeDrive.crashArmed = true
    BridgeDrive.fastSaid = false
    BridgeDrive.recklessSaid = false
    BridgeDrive.greetAt = nil
    BridgeDrive.greetDone = false
    BridgeDrive.prevWeather = nil
    BridgeDrive.curWeather = nil
    BridgeDrive.eatSaid = false
end






local function say(event)
    local e = BridgeDrive.EVENTS[event]
    if e == nil then return false end
    if BridgeDrive.ENABLED == 0 then return false end
    if e.cat ~= nil and BridgeDrive.ON[e.cat] ~= 1 then return false end
    if Bridge.time - BridgeDrive.lastAny < BridgeDrive.GAP * BridgeDrive.SEC then return false end
    local said = false
    pcall(function() said = BridgeMoments.say(event, e.cooldown * BridgeDrive.SEC, e.urgent == true and "soft" or false, e.slot) == true end)
    if said then
        BridgeDrive.lastAny = Bridge.time
        BridgeDrive.info = event
        log(event)
    else
        BridgeDrive.info = "blocked " .. event
    end
    return said
end





local function sayState(red, phase)
    if BridgeDrive.ON.STATE ~= 1 then return false end
    local w = BridgeDrive.curWeather
    if w ~= nil then
        if (w.raining or w.snowing) and statOf(red, "WETNESS") > 0.6 then
            if say("EvCarColdWet") then return true end
        end
        if w.night and statOf(red, "FATIGUE") > 0.6 then
            if say("EvCarTiredNight") then return true end
        end
    end
    for _, s in ipairs(BridgeDrive.STATES) do
        local hit = false
        pcall(function() hit = s.test(red) end)
        if hit then
            return say("EvCar" .. s.key .. phase)
        end
    end
    return false
end


local function edge(v, on, off, was)
    if was then return v > off end
    return v > on
end




local function weatherSnapshot(red)
    local p = BridgeDrive.prevWeather
    local s = {}
    pcall(function()
        local c = getClimateManager()
        if c == nil then return end
        local rain = c:getPrecipitationIntensity()
        local snow = math.min(c:getSnowStrength(), 1)
        s.raining = edge(rain, BridgeDrive.RAIN_ON, BridgeDrive.RAIN_OFF, p and p.raining)
        s.snowing = edge(snow, BridgeDrive.SNOW_ON, BridgeDrive.SNOW_OFF, p and p.snowing)
        s.heavy = s.raining and rain > BridgeDrive.RAIN_HEAVY
        s.foggy = edge(c:getFogIntensity(), BridgeDrive.FOG, BridgeDrive.FOG * 0.6, p and p.foggy)
        s.windy = edge(c:getWindPower(), BridgeDrive.WIND, BridgeDrive.WIND * 0.6, p and p.windy)
        local wp = nil
        pcall(function() wp = c:getWeatherPeriod() end)
        if wp ~= nil then
            local running, stage = false, -1
            pcall(function() running = wp:isRunning() end)
            pcall(function() if running then stage = wp:getCurrentStageID() end end)
            s.storm = running and stage == WeatherPeriod.STAGE_STORM
            s.blizzard = running and stage == WeatherPeriod.STAGE_BLIZZARD
        end
    end)
    pcall(function() s.night = getGameTime():isNight() end)
    return s
end



local function sayWeatherIn(red)
    if BridgeDrive.ON.WEATHER ~= 1 then return false end
    local s = nil
    pcall(function() s = weatherSnapshot(red) end)
    if s == nil then return false end
    BridgeDrive.curWeather = s
    if not (s.raining or s.snowing or s.foggy or s.storm or s.blizzard) then return false end
    return say("EvCarWeatherIn")
end



local function eatingNow(red)
    local q = nil
    pcall(function() q = ISTimedActionQueue.getTimedActionQueue(red) end)
    if q == nil then return false end
    local cur = q.current
    if cur == nil then return false end
    local e = false
    pcall(function() e = cur.isEating == true end)
    return e
end




local function mcall(obj, name, ...)
    if obj == nil then return nil end
    local fn = nil
    pcall(function() fn = obj[name] end)
    if fn == nil then return nil end
    local ok, v = pcall(fn, obj, ...)
    if ok then return v end
    return nil
end



local function corpsesNear(red, radius)
    local n = 0
    pcall(function()
        local cell = getCell()
        local cx, cy, cz = math.floor(red:getX()), math.floor(red:getY()), math.floor(red:getZ())
        local r = tonumber(radius) or BridgeDrive.SMELL_RADIUS
        for dx = -r, r do
            for dy = -r, r do
                local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
                if sq ~= nil then
                    local bodies = mcall(sq, "getDeadBodys")
                    n = n + (tonumber(mcall(bodies, "size")) or 0)
                end
            end
        end
    end)
    return n
end


local function isBodyZ(z)
    local ok, v = pcall(function() return z:getVariableBoolean(Bridge.BODY_VAR) end)
    return ok and v
end



local function threat(z)
    local alive = false
    pcall(function() alive = z:isAlive() and z:getHealth() > 0 end)
    local companion = isBodyZ(z)
    if not companion and Bridge.isCompanion ~= nil then pcall(function() companion = Bridge.isCompanion(z) end) end
    return z ~= nil and alive and not companion and not BridgeData.harmless(z)
end



local function scanAhead(car, red)
    local C = BridgeCar.frame(car)
    if C == nil then return 0, false end
    local zombies, carAhead = 0, false
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if threat(z) then
                local rx, ry = z:getX() - C.cx, z:getY() - C.cy
                local along = rx * C.fx + ry * C.fy
                local side = ry * C.fx - rx * C.fy
                if along >= BridgeDrive.SCAN_MIN and along <= BridgeDrive.SCAN_MAX
                    and math.abs(side) <= C.hw + BridgeDrive.SCAN_HALF then
                    local seen = false
                    pcall(function() seen = red:CanSee(z) end)
                    if seen then zombies = zombies + 1 end
                end
            end
        end
    end)
    pcall(function()
        local cell = getCell()
        local z = 0
        pcall(function() z = math.floor((car:getZ() or 0) + 0.01) end)
        local d = math.max(BridgeDrive.SCAN_MIN, (C.hl or 2.5) + 3)
        while d <= BridgeDrive.SCAN_MAX do
            local sq = cell:getGridSquare(math.floor(C.cx + C.fx * d), math.floor(C.cy + C.fy * d), z)
            if sq ~= nil and sq:isVehicleIntersecting() then carAhead = true break end
            d = d + 1.5
        end
    end)
    return zombies, carAhead
end


local function nearbyZombies(car)
    local cx, cy = nil, nil
    local C = BridgeCar.frame(car)
    if C ~= nil then cx, cy = C.cx, C.cy end
    if cx == nil then pcall(function() cx, cy = car:getX(), car:getY() end) end
    if cx == nil then return 0 end
    local n = 0
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if threat(z) then
                local dx, dy = z:getX() - cx, z:getY() - cy
                if dx * dx + dy * dy <= BridgeDrive.GREET_RADIUS * BridgeDrive.GREET_RADIUS then n = n + 1 end
            end
        end
    end)
    return n
end


local function zombiesNear(red, radius)
    local n = 0
    local x, y = nil, nil
    pcall(function() x, y = red:getX(), red:getY() end)
    if x == nil then return 0 end
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if threat(z) then
                local dx, dy = z:getX() - x, z:getY() - y
                if dx * dx + dy * dy <= radius * radius then n = n + 1 end
            end
        end
    end)
    return n
end




local function wildAnimal(obj)
    local isAnimal = false
    pcall(function() isAnimal = instanceof(obj, "IsoAnimal") end)
    if not isAnimal then return false end
    local wild = false
    if obj.isWild ~= nil then pcall(function() wild = obj:isWild() == true end) end
    if not wild then return false end
    local inZone = false
    pcall(function()
        if DesignationZoneAnimal ~= nil and DesignationZoneAnimal.getZone ~= nil then
            inZone = DesignationZoneAnimal.getZone(obj:getX(), obj:getY(), obj:getZ()) ~= nil
        end
    end)
    return not inZone
end


local function animalMemory()
    if BridgeDrive.animalSeen == nil then BridgeDrive.animalSeen = {} end

    if Bridge.time - (BridgeDrive.animalPrunedAt or -99999) >= 10 * BridgeDrive.SEC then
        BridgeDrive.animalPrunedAt = Bridge.time
        local old = {}
        for id, at in pairs(BridgeDrive.animalSeen) do
            if Bridge.time - at >= BridgeDrive.ANIMAL_REPEAT then old[#old + 1] = id end
        end
        for i = 1, #old do BridgeDrive.animalSeen[old[i]] = nil end
    end
    return BridgeDrive.animalSeen
end


local function animalId(obj)
    local id = nil
    if obj.getModData ~= nil then pcall(function() id = obj:getModData().AnimalMapID end) end
    if id == nil then
        local t, x, y = "animal", 0, 0
        if obj.getAnimalType ~= nil then pcall(function() t = tostring(obj:getAnimalType()) end) end
        pcall(function() x, y = math.floor(obj:getX()), math.floor(obj:getY()) end)
        id = t .. ":" .. tostring(x) .. ":" .. tostring(y)
    end
    return id
end





local function eachObj(collection, fn)
    if collection == nil then return end
    if type(collection) == "table" then
        for _, obj in pairs(collection) do fn(obj) end
        return
    end
    local usedIterator = false
    pcall(function()
        if collection.iterator ~= nil then
            local it = collection:iterator()
            if it ~= nil and it.hasNext ~= nil and it.next ~= nil then
                while it:hasNext() do
                    local obj = it:next()
                    if obj ~= nil then fn(obj) end
                end
                usedIterator = true
            end
        end
    end)
    if usedIterator then return end
    local done = false
    pcall(function()
        if collection.size ~= nil then
            local n = collection:size()
            if type(n) == "number" then
                if collection.get ~= nil then
                    for i = 0, n - 1 do fn(collection:get(i)) end
                else
                    for i = 0, n - 1 do fn(collection[i]) end
                end
                done = true
            end
        end
    end)
    if done then return end
    pcall(function()
        local n = collection.length
        if type(n) == "number" then
            for i = 0, n - 1 do fn(collection[i]) end
        end
    end)
end



local function scanAnimal(car, red)
    local C = BridgeCar.frame(car)
    if C == nil then return nil end
    local found = nil
    local function consider(obj)
        pcall(function()
            if found ~= nil or not wildAnimal(obj) then return end
            local x, y = nil, nil
            pcall(function() x, y = obj:getX(), obj:getY() end)
            if x == nil then return end
            local rx, ry = x - C.cx, y - C.cy
            local along = rx * C.fx + ry * C.fy
            local side = ry * C.fx - rx * C.fy
            if along < BridgeDrive.ANIMAL_MIN or along > BridgeDrive.ANIMAL_MAX
                or math.abs(side) > BridgeDrive.ANIMAL_HALF then return end
            local seen = false
            pcall(function() seen = red:CanSee(obj) end)
            if not seen then return end
            local id = animalId(obj)
            local mem = animalMemory()
            if mem[id] ~= nil and Bridge.time - mem[id] < BridgeDrive.ANIMAL_REPEAT then return end
            mem[id] = Bridge.time
            found = obj
        end)
    end
    local cell = getCell()
    if cell == nil then return nil end
    if cell.getMovingObjects ~= nil then
        local list = nil
        pcall(function() list = cell:getMovingObjects() end)
        eachObj(list, consider)
    end
    if found == nil and cell.getObjectList ~= nil then
        local list = nil
        pcall(function() list = cell:getObjectList() end)
        eachObj(list, consider)
    end
    return found
end





function BridgeDrive.onExit()
    if BridgeDrive.ENABLED == 0 then return end
    if BridgeDrive.ON.EXIT ~= 1 then return end
    local red = BridgeData.owner()
    if red == nil then return end
    local fight = false
    pcall(function() fight = BridgeFight ~= nil and (BridgeFight.target ~= nil or BridgeFight.state == "swing") end)
    local n = zombiesNear(red, BridgeDrive.EXIT_RADIUS)
    local tense = fight or n > 0
    local said = false
    if tense then
        said = say("EvCarExitZombies")
    else
        pcall(function() said = sayState(red, "Out") end)
        if not said then said = say("EvCarExitClear") end
    end
    if not said then return end
    if BridgeSocial ~= nil and BridgeSocial.emote ~= nil then
        if tense then
            pcall(function() BridgeSocial.emote("PullAtCollar", true, true) end)
        else
            pcall(function() BridgeSocial.emote("ShiftWeight", true, true) end)
        end
    end
end



function BridgeDrive.onZombieDead(zombie)
    if BridgeDrive.ENABLED == 0 or BridgeDrive.ON.ROADKILL ~= 1 then return end
    if zombie == nil then return end
    local red = BridgeData.owner()
    if red == nil then return end
    local car = nil
    pcall(function() car = red:getVehicle() end)
    if car == nil then return end
    if BridgeCar == nil or not BridgeCar.isInside() then return end
    local speed = 0
    pcall(function() speed = math.abs(car:getCurrentSpeedKmHour()) end)
    if speed < BridgeDrive.ROADKILL_MIN_KMH then return end
    local by = nil
    pcall(function() by = zombie:getAttackedBy() end)
    local vehicle = false
    pcall(function() vehicle = by ~= nil and instanceof(by, "BaseVehicle") end)
    local near = false
    pcall(function()
        local dx, dy = zombie:getX() - red:getX(), zombie:getY() - red:getY()
        near = dx * dx + dy * dy <= 9 * 9
    end)
    if not (vehicle or near) then return end
    say("EvCarRoadkill")
end






function BridgeDrive.tick()
    if BridgeDrive.ENABLED == 0 then return end
    local red = BridgeData.owner()
    if red == nil then return end
    if BridgeCar == nil or not BridgeCar.withRed(red) then reset() return end
    local car = nil
    pcall(function() car = red:getVehicle() end)
    if car == nil then reset() return end



    local inside = false
    pcall(function() inside = BridgeCar.isInside() end)
    if not inside then
        BridgeDrive.greetAt, BridgeDrive.greetDone = nil, false
    elseif BridgeDrive.greetAt == nil then
        BridgeDrive.greetAt = Bridge.time
    end

    local speed = 0
    pcall(function() speed = math.abs(car:getCurrentSpeedKmHour()) end)
    if type(speed) ~= "number" or speed ~= speed then speed = 0 end
    local hp = nil
    pcall(function() hp = tonumber(red:getBodyDamage():getOverallBodyHealth()) end)



    if hp ~= nil and BridgeDrive.hpBase == nil then BridgeDrive.hpBase = hp end
    if hp ~= nil and hp >= (BridgeDrive.hpBase or hp) then BridgeDrive.hpBase = hp end
    local hpDrop = 0
    if hp ~= nil and BridgeDrive.hpBase ~= nil then hpDrop = BridgeDrive.hpBase - hp end




    if BridgeDrive.peak == nil or speed >= BridgeDrive.peak
        or (Bridge.time - (BridgeDrive.peakAt or 0)) > BridgeDrive.CRASH_WINDOW then
        BridgeDrive.peak, BridgeDrive.peakAt = speed, Bridge.time
    end
    local drop = (BridgeDrive.peak or 0) - speed


    if BridgeDrive.crashArmed and (BridgeDrive.peak or 0) >= BridgeDrive.CRASH_MIN_KMH
        and drop >= BridgeDrive.CRASH_LIGHT then
        local hard = drop >= BridgeDrive.CRASH_HARD or hpDrop >= BridgeDrive.CRASH_HP_DROP
        BridgeDrive.crashArmed = false
        BridgeDrive.peak, BridgeDrive.peakAt = speed, Bridge.time
        if say(hard and "EvCarCrashHard" or "EvCarCrash") then
            BridgeDrive.hpBase = hp or BridgeDrive.hpBase
            return
        end
    end
    if speed < BridgeDrive.CRASH_MIN_KMH then BridgeDrive.crashArmed = true end


    if hpDrop >= BridgeDrive.HURT_HP_DROP then
        if say("EvCarHurt") then
            BridgeDrive.hpBase = hp
            return
        end
    end



    if not BridgeDrive.greetDone and BridgeDrive.greetAt ~= nil
        and Bridge.time - BridgeDrive.greetAt >= BridgeDrive.GREET_DELAY then
        local said = false
        pcall(function() BridgeDrive.curWeather = weatherSnapshot(red) end)
        pcall(function() said = sayState(red, "In") end)
        if not said then pcall(function() said = sayWeatherIn(red) end) end
        if not said then
            local n = nearbyZombies(car)
            said = say(n > 0 and "EvCarGreetZombies" or "EvCarGreetClear")
        end
        if said then
            BridgeDrive.greetDone = true
            BridgeDrive.hpBase = hp or BridgeDrive.hpBase
            return
        end
    end


    if Bridge.every(BridgeDrive.SCAN_EVERY) then
        local zombies, carAhead = scanAhead(car, red)
        if carAhead and say("EvCarAhead") then
            BridgeDrive.hpBase = hp or BridgeDrive.hpBase
            return
        end
        if zombies > 0 then
            if say(zombies >= BridgeDrive.HORDE_COUNT and "EvCarHorde" or "EvCarZombie") then
                BridgeDrive.hpBase = hp or BridgeDrive.hpBase
                return
            end
        end
    end



    if BridgeDrive.greetDone and Bridge.every(BridgeDrive.SMELL_EVERY) then
        local sick = statOf(red, "SICKNESS")
        if sick > BridgeDrive.CORPSE_SICK_MIN then
            local n = 0
            pcall(function() n = corpsesNear(red, BridgeDrive.CORPSE_SICK_RADIUS) end)
            if n > 0 then
                if Bridge.time - (BridgeDrive.corpseEmoteAt or -99999) > BridgeDrive.CORPSE_EMOTE_GAP then
                    BridgeDrive.corpseEmoteAt = Bridge.time
                    if BridgeSocial ~= nil and BridgeSocial.emote ~= nil then
                        pcall(function() BridgeSocial.emote("PullAtCollar", true) end)
                    end
                end
                if say("EvCarCorpseSick") then
                    BridgeDrive.hpBase = hp or BridgeDrive.hpBase
                    return
                end
            end
        end
    end


    if BridgeDrive.greetDone and Bridge.every(BridgeDrive.STATE_EVERY) then
        if sayState(red, "Drive") then
            BridgeDrive.hpBase = hp or BridgeDrive.hpBase
            return
        end
    end


    if Bridge.every(BridgeDrive.WEATHER_CHECK) then
        local s = weatherSnapshot(red)
        local p = BridgeDrive.prevWeather
        BridgeDrive.prevWeather = s
        BridgeDrive.curWeather = s
        if p ~= nil then
            local list = {}
            if s.blizzard and not p.blizzard then list[#list + 1] = "EvCarBlizzard" end
            if s.storm and not p.storm then list[#list + 1] = "EvCarStorm" end
            if s.raining and not p.raining then list[#list + 1] = "EvCarRain" end
            if s.raining and s.heavy and not p.heavy then list[#list + 1] = "EvCarRainHeavy" end
            if not s.raining and p.raining then list[#list + 1] = "EvCarRainStop" end
            if s.snowing and not p.snowing then list[#list + 1] = "EvCarSnow" end
            if s.foggy and not p.foggy then list[#list + 1] = "EvCarFog" end
            if s.windy and not p.windy then list[#list + 1] = "EvCarWindy" end
            if s.night and not p.night then list[#list + 1] = "EvCarNightFalls" end
            if not s.night and p.night then list[#list + 1] = "EvCarDawn" end
            for i = 1, #list do
                if say(list[i]) then
                    BridgeDrive.hpBase = hp or BridgeDrive.hpBase
                    return
                end
            end
        end
    end


    if BridgeDrive.greetDone and Bridge.every(BridgeDrive.EAT_EVERY) then
        local eating = false
        pcall(function() eating = eatingNow(red) end)
        if eating and not BridgeDrive.eatSaid then
            BridgeDrive.eatSaid = true
            if say("EvCarEating") then
                BridgeDrive.hpBase = hp or BridgeDrive.hpBase
                return
            end
        elseif not eating then
            BridgeDrive.eatSaid = false
        end
    end


    if Bridge.every(BridgeDrive.SMELL_EVERY) then
        local n = 0
        pcall(function() n = corpsesNear(red, BridgeDrive.SMELL_RADIUS) end)
        if n > 0 and say("EvCarSmell") then
            BridgeDrive.hpBase = hp or BridgeDrive.hpBase
            return
        end
    end


    if Bridge.every(BridgeDrive.ANIMAL_EVERY) then
        local animal = nil
        pcall(function() animal = scanAnimal(car, red) end)
        if animal ~= nil and say("EvCarAnimal") then
            BridgeDrive.hpBase = hp or BridgeDrive.hpBase
            return
        end
    end


    if speed >= BridgeDrive.RECKLESS_KMH and not BridgeDrive.recklessSaid then
        if say("EvCarReckless") then
            BridgeDrive.recklessSaid, BridgeDrive.fastSaid = true, true
            BridgeDrive.hpBase = hp or BridgeDrive.hpBase
            return
        end
    elseif speed >= BridgeDrive.FAST_KMH and not BridgeDrive.fastSaid then
        if say("EvCarFast") then
            BridgeDrive.fastSaid = true
            BridgeDrive.hpBase = hp or BridgeDrive.hpBase
            return
        end
    end
    if speed < BridgeDrive.FAST_KMH - 8 then
        BridgeDrive.fastSaid, BridgeDrive.recklessSaid = false, false
    end

    if hp ~= nil then BridgeDrive.hpBase = hp end
end


Events.OnZombieDead.Add(function(zombie) pcall(BridgeDrive.onZombieDead, zombie) end)

Events.OnThunderEvent.Add(function(x, y, strike, light, rumble)
    if not light then return end
    if BridgeDrive.ENABLED == 0 or BridgeDrive.ON.WEATHER ~= 1 then return end
    local red = BridgeData.owner()
    if red == nil then return end
    local car = nil
    pcall(function() car = red:getVehicle() end)
    if car == nil or BridgeCar == nil or not BridgeCar.isInside() then return end
    local dx, dy = x - red:getX(), y - red:getY()
    if dx * dx + dy * dy > 30 * 30 then return end
    say("EvCarLightning")
end)

log("loaded")
