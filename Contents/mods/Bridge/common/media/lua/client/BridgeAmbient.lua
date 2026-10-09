BridgeAmbient = BridgeAmbient or {}

BridgeAmbient.SEC = 60


BridgeAmbient.ENABLED = 1



BridgeAmbient.ON = {
    WEATHER = 1,
    DARK    = 1,
}





BridgeAmbient.CFG = {
    CHECK          = 30,
    GAP            = 12,
    NEAR           = 20,
    LIGHTNING_DIST = 30,
    COMBAT_HOLD    = 15,
    DANGER         = 12,
    RAIN_ON        = 0.05,
    RAIN_OFF       = 0.02,
    RAIN_HEAVY     = 0.7,
    SNOW_ON        = 0.05,
    SNOW_OFF       = 0.02,
    FOG            = 0.4,
    WIND           = 0.5,
    CLOUD          = 0.6,
    DARK_HI        = 0.28,
    DARK_LO        = 0.22,
    TORCH          = 0.05,
}





BridgeAmbient.EVENTS = {
    EvRainStart      = { slot = "AmbRainStart",    cooldown = 5 * 60,  cat = "WEATHER" },
    EvRainHeavy      = { slot = "AmbRainHeavy",    cooldown = 10 * 60, cat = "WEATHER" },
    EvRainStop       = { slot = "AmbRainStop",     cooldown = 5 * 60,  cat = "WEATHER" },
    EvRainInside     = { slot = "AmbRainInside",   cooldown = 12 * 60, cat = "WEATHER" },
    EvSnowStart      = { slot = "AmbSnowStart",    cooldown = 12 * 60, cat = "WEATHER" },
    EvBlizzard       = { slot = "AmbBlizzard",     cooldown = 12 * 60, cat = "WEATHER" },
    EvBlizzardInside = { slot = "AmbBlizzardIn",   cooldown = 12 * 60, cat = "WEATHER" },
    EvStorm          = { slot = "AmbStorm",        cooldown = 10 * 60, cat = "WEATHER" },
    EvStormInside    = { slot = "AmbStormInside",  cooldown = 10 * 60, cat = "WEATHER" },
    EvLightning      = { slot = "AmbLightning",    cooldown = 3 * 60,  cat = "WEATHER" },
    EvFog            = { slot = "AmbFog",          cooldown = 12 * 60, cat = "WEATHER" },
    EvWindy          = { slot = "AmbWindy",        cooldown = 15 * 60, cat = "WEATHER" },
    EvNightFalls     = { slot = "AmbNightFalls",   cooldown = 20 * 60, cat = "DARK" },
    EvDawn           = { slot = "AmbDawn",         cooldown = 20 * 60, cat = "DARK" },
    EvDarkOut        = { slot = "AmbDarkOut",      cooldown = 10 * 60, cat = "DARK" },
    EvDarkOutTorch   = { slot = "AmbDarkOutTorch", cooldown = 10 * 60, cat = "DARK" },
    EvNeedLightOut   = { slot = "AmbNeedLightOut", cooldown = 15 * 60, cat = "DARK" },
    EvDarkRoom       = { slot = "AmbDarkRoom",     cooldown = 12 * 60, cat = "DARK" },
    EvDarkRoomTorch  = { slot = "AmbDarkRoomTorch", cooldown = 12 * 60, cat = "DARK" },
    EvNeedLightIn    = { slot = "AmbNeedLightIn",  cooldown = 15 * 60, cat = "DARK" },
    EvLightOn        = { slot = "AmbLightOn",      cooldown = 10 * 60, cat = "DARK" },
    EvNoPowerIn      = { slot = "AmbNoPowerIn",    cooldown = 30 * 60, cat = "DARK" },
}

BridgeAmbient.prev = nil
BridgeAmbient.lastAny = -99999
BridgeAmbient.fightingAt = -99999
BridgeAmbient.info = "none"

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeAmbient] " .. tostring(text)) end end

function BridgeAmbient.on()
    return BridgeAmbient.ENABLED == 1
end



local function combatNow()
    local fighting = false
    pcall(function()
        fighting = BridgeFight ~= nil and (BridgeFight.state ~= "idle" or BridgeFight.target ~= nil)
    end)
    if fighting then BridgeAmbient.fightingAt = Bridge.time end
    if BridgeAmbient.CFG.COMBAT_HOLD <= 0 then return fighting end
    return fighting or (Bridge.time - BridgeAmbient.fightingAt < BridgeAmbient.CFG.COMBAT_HOLD * BridgeAmbient.SEC)
end


local function dangerNear(red, body)
    local dist = BridgeAmbient.CFG.DANGER
    if dist <= 0 then return false end
    local near = false
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= body and z:isAlive()
                and not z:getVariableBoolean(Bridge.BODY_VAR) and not BridgeData.harmless(z) then
                local dx, dy = z:getX() - red:getX(), z:getY() - red:getY()
                if dx * dx + dy * dy < dist * dist and math.abs(z:getZ() - red:getZ()) < 1 then
                    local seen = true
                    pcall(function() seen = red:CanSee(z) end)
                    if seen then near = true break end
                end
            end
        end
    end)
    return near
end


local function blocked(red, body)
    if not BridgeAmbient.on() then return true end
    if Bridge.mode == "rest" then return true end
    if Bridge.quiet ~= nil and Bridge.quiet() then return true end
    if red == nil then return true end
    if combatNow() then return true end
    local busy = false
    pcall(function() busy = BridgeHeal ~= nil and BridgeHeal.active end)
    pcall(function() busy = busy or (BridgeWash ~= nil and BridgeWash.state ~= "idle") end)
    pcall(function() busy = busy or red:isAsleep() end)
    pcall(function() busy = busy or red:getVehicle() ~= nil end)
    if busy then return true end
    return dangerNear(red, body)
end

local function edge(v, hi, lo, was)
    if was then return v > lo end
    return v > hi
end

local function place(red)
    local sq = nil
    pcall(function() sq = red:getCurrentSquare() end)
    if sq == nil then return "out", false end
    local out = true
    pcall(function() out = sq:isOutside() end)
    if out then return "out", false end
    local room = nil
    pcall(function() room = sq:getRoom() end)
    if room ~= nil then return "in", true end
    return "sheltered", true
end

local function lightAt(red)
    local lvl, torch = 1, 0
    pcall(function()
        local sq = red:getCurrentSquare()
        if sq == nil then return end
        lvl = sq:getLightLevel(red:getPlayerNum())
        torch = math.min(1, red:getTorchStrength())
        lvl = math.max(lvl, torch)
        if sq:isOutside() then
            local c = getClimateManager()
            if c ~= nil then lvl = math.max(c:getDayLightStrength(), lvl) end
        end
    end)
    return lvl, torch
end

local function snapshot(red)
    local p = BridgeAmbient.prev
    local s = { place = "out", covered = false }
    s.place, s.covered = place(red)
    pcall(function()
        local c = getClimateManager()
        if c == nil then return end
        local rain = c:getPrecipitationIntensity()
        local snow = math.min(c:getSnowStrength(), 1)
        s.raining = edge(rain, BridgeAmbient.CFG.RAIN_ON, BridgeAmbient.CFG.RAIN_OFF, p and p.raining)
        s.snowing = edge(snow, BridgeAmbient.CFG.SNOW_ON, BridgeAmbient.CFG.SNOW_OFF, p and p.snowing)
        s.heavy = s.raining and rain > BridgeAmbient.CFG.RAIN_HEAVY
        s.foggy = edge(c:getFogIntensity(), BridgeAmbient.CFG.FOG, BridgeAmbient.CFG.FOG * 0.6, p and p.foggy)
        s.windy = edge(c:getWindPower(), BridgeAmbient.CFG.WIND, BridgeAmbient.CFG.WIND * 0.6, p and p.windy)
        s.cloudy = edge(c:getCloudIntensity(), BridgeAmbient.CFG.CLOUD, BridgeAmbient.CFG.CLOUD * 0.6, p and p.cloudy)
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
    local sq = nil
    pcall(function() sq = red:getCurrentSquare() end)
    if sq ~= nil then pcall(function() s.power = sq:haveElectricity() end) end
    s.light, s.torch = lightAt(red)
    s.torchOn = (s.torch or 0) > BridgeAmbient.CFG.TORCH
    if p and p.dark then
        s.dark = (s.light or 1) < BridgeAmbient.CFG.DARK_HI
    else
        s.dark = (s.light or 1) < BridgeAmbient.CFG.DARK_LO
    end
    pcall(function() s.night = getGameTime():isNight() end)
    pcall(function() s.car = red:getVehicle() ~= nil end)
    return s
end

local function say(event)
    local e = BridgeAmbient.EVENTS[event]
    if e == nil then return false end
    if e.cat ~= nil and BridgeAmbient.ON[e.cat] ~= 1 then return false end
    if Bridge.time - BridgeAmbient.lastAny < BridgeAmbient.CFG.GAP * BridgeAmbient.SEC then return false end
    local said = false
    pcall(function() said = BridgeMoments.say(event, e.cooldown * BridgeAmbient.SEC, "soft", e.slot) == true end)
    if said then
        BridgeAmbient.lastAny = Bridge.time
        BridgeAmbient.info = event
    end
    return said
end

local function fire(list)
    for i = 1, #list do
        if say(list[i]) then return true end
    end
    return false
end

function BridgeAmbient.update(body)
    if body == nil then return end
    if not BridgeAmbient.on() then return end
    if not Bridge.every(BridgeAmbient.CFG.CHECK) then return end
    if not Bridge.alive() then return end
    local red = BridgeData.owner()
    if red == nil then return end

    local s = snapshot(red)
    local p = BridgeAmbient.prev
    BridgeAmbient.prev = s
    if p == nil then return end

    if blocked(red, body) then return end

    local near = false
    pcall(function()
        local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
        near = dx * dx + dy * dy <= BridgeAmbient.CFG.NEAR * BridgeAmbient.CFG.NEAR
            and math.abs(red:getZ() - body:getZ()) < 1
    end)
    if not near then return end

    local room = s.place == "in"
    local covered = s.covered
    local list = {}



    local herLight = false
    pcall(function()
        if BridgeTorchShared ~= nil and type(BridgeTorchShared.findTorch) == "function" then
            herLight = BridgeTorchShared.findTorch(body) ~= nil
        end
    end)

    if s.blizzard and not (p.blizzard) then list[#list + 1] = covered and "EvBlizzardInside" or "EvBlizzard" end
    if s.storm and not (p.storm) then list[#list + 1] = covered and "EvStormInside" or "EvStorm" end
    if s.raining and not (p.raining) then list[#list + 1] = covered and "EvRainInside" or "EvRainStart" end
    if s.raining and s.heavy and not (p.heavy) then list[#list + 1] = "EvRainHeavy" end
    if not s.raining and p.raining then list[#list + 1] = "EvRainStop" end
    if s.snowing and not (p.snowing) then list[#list + 1] = "EvSnowStart" end
    if s.foggy and not (p.foggy) and not covered then list[#list + 1] = "EvFog" end
    if s.windy and not (p.windy) then list[#list + 1] = "EvWindy" end

    if s.night and not (p.night) then list[#list + 1] = "EvNightFalls" end
    if not s.night and p.night then list[#list + 1] = "EvDawn" end
    if s.torchOn and not (p.torchOn) and p.dark then list[#list + 1] = "EvLightOn" end
    if s.dark and not (p.dark) then
        if s.torchOn or herLight then


            list[#list + 1] = room and "EvDarkRoomTorch" or "EvDarkOutTorch"
        else
            list[#list + 1] = room and "EvNeedLightIn" or "EvNeedLightOut"
        end
    end
    if room and s.night and s.power == false and p.power ~= false then list[#list + 1] = "EvNoPowerIn" end

    if fire(list) then log(BridgeAmbient.info .. " (" .. tostring(s.place) .. ")") end
end

Events.OnThunderEvent.Add(function(x, y, strike, light, rumble)
    if not light then return end
    if not Bridge.alive() then return end
    local red = BridgeData.owner()
    local body = Bridge.body
    if red == nil or body == nil then return end
    if blocked(red, body) then return end
    local dx, dy = x - red:getX(), y - red:getY()
    if dx * dx + dy * dy > BridgeAmbient.CFG.LIGHTNING_DIST * BridgeAmbient.CFG.LIGHTNING_DIST then return end
    local bx, by = x - body:getX(), y - body:getY()
    if bx * bx + by * by > BridgeAmbient.CFG.NEAR * BridgeAmbient.CFG.NEAR then return end
    say("EvLightning")
end)

log("loaded")
