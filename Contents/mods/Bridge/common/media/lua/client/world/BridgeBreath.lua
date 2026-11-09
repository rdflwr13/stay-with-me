BridgeBreath = BridgeBreath or {}
local B = BridgeBreath

local RETRY_TICKS = 60
local BUSY_RETRY_TICKS = 10

local state = {
    body = nil,
    id = 0,
    tier = nil,
    nextAt = 0,
    failKey = nil,
}

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then
        print("[BridgeBreath] " .. tostring(text))
    end
end

local function clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function ownerClient()
    if Bridge == nil or not Bridge.mp then return true end
    local owner, player = nil, nil
    pcall(function() owner = BridgeData.owner() end)
    pcall(function() player = getPlayer() end)
    return owner ~= nil and player ~= nil and owner == player
end

local function breathingVolume()
    local level = 3
    if BridgeData ~= nil and type(BridgeData.sandboxNumber) == "function" then
        pcall(function() level = BridgeData.sandboxNumber("BreathingVolume", 3, 1, 4) end)
    end
    level = math.floor(tonumber(level) or 3)
    if level == 1 then return 0 end
    if level == 2 then return 0.5 end
    if level == 4 then return 1.5 end
    return 1
end

local function stamina()
    local s = nil
    pcall(function() s = BridgeExercise.stamina() end)
    if type(s) ~= "number" then
        local f = 0
        pcall(function() f = tonumber(BridgeFight and BridgeFight.fatigue) or 0 end)
        s = 1 - f
    end
    return clamp01(s)
end

local function tierFor(s)
    local bf = rawget(_G, "BridgeFight")
    if bf ~= nil and type(bf.exhaustionLevel) == "function" then
        local ok, tier = pcall(bf.exhaustionLevel, s)
        if ok then return tier end
    end
    if s >= 0.75 then return 0 end
    if s > 0.50 then return 1 end
    if s > 0.25 then return 2 end
    if s > 0.10 then return 3 end
    return 4
end

local function intervalFor(tier)
    if tier == 1 then return 480 end
    if tier == 2 then return 360 end
    if tier == 3 then return 300 end
    return 120
end

local SOUND_GAIN = 0.6

local function aliasFor(body)
    local female = true
    pcall(function() female = body:isFemale() ~= false end)
    if female then return "NA_BreathFemale" end
    return "NA_BreathMale"
end

local function stop()
    if state.id ~= 0 and state.body ~= nil then
        local body, id = state.body, state.id
        pcall(function() body:getEmitter():stopSound(id) end)
        log("stop id=" .. tostring(id))
    end
    state.body, state.id, state.tier, state.nextAt, state.failKey = nil, 0, nil, 0, nil
end

function B.tick()
    local bridge = rawget(_G, "Bridge")
    if bridge == nil then return end

    if not ownerClient() then stop() return end
    if bridge.kind ~= "zombie" then stop() return end
    local breathVolume = breathingVolume()
    if breathVolume <= 0 then stop() return end

    local body = bridge.body
    if body == nil or not bridge.alive() then stop() return end

    local invisible, inVehicle = false, false
    pcall(function() invisible = body:isInvisible() == true end)
    pcall(function() inVehicle = body:getVehicle() ~= nil end)
    if invisible or inVehicle then stop() return end

    local emitter = nil
    pcall(function() emitter = body:getEmitter() end)
    if emitter == nil then stop() return end

    if state.body ~= body then
        stop()
        state.body = body
    end

    local now = tonumber(bridge.time) or 0
    local s = stamina()
    local tier = tierFor(s)
    if tier == 0 then
        if state.id ~= 0 or state.tier ~= nil then stop() end
        return
    end
    if tier ~= state.tier then
        state.tier = tier
        log(string.format("stamina=%.0f tier=%d", s * 100, tier))
    end

    if now < state.nextAt then return end

    local alias = aliasFor(body)
    local playing = false
    pcall(function() playing = emitter:isPlaying(alias) == true end)
    if playing then
        state.nextAt = now + BUSY_RETRY_TICKS
        return
    end

    local volume = SOUND_GAIN * breathVolume
    pcall(function() volume = getSoundManager():getSoundVolume() * SOUND_GAIN * breathVolume end)

    local id = nil
    if BridgeSound ~= nil and type(BridgeSound.sfxAt) == "function" then
        pcall(function() id = BridgeSound.sfxAt(body, alias, volume) end)
    end
    if type(id) ~= "number" or id == 0 then
        state.nextAt = now + RETRY_TICKS
        if state.failKey ~= alias then
            state.failKey = alias
            log("play failed " .. tostring(alias))
        end
        return
    end

    state.id = id
    state.failKey = nil
    state.nextAt = now + intervalFor(tier)
end

if type(Events) == "table" and Events.OnTick ~= nil then
    Events.OnTick.Add(function()
        pcall(function()
            if Bridge == nil or type(Bridge.every) ~= "function" then return end
            if not Bridge.every(5) then return end
            B.tick()
        end)
    end)
end

return B
