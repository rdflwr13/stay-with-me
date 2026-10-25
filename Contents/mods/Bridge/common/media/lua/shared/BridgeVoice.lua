BridgeVoice = BridgeVoice or {}

BridgeVoice.SILENT_PREFIX = "NotAZombie"

BridgeVoice.FEMALE_PREFIX = "FemaleZombie"
BridgeVoice.MALE_PREFIX = "MaleZombie"

BridgeVoice.ZOMBIE_ALIASES = {
    "FemaleZombieIdle", "MaleZombieIdle",
    "FemaleZombieHurt", "MaleZombieHurt",
    "FemaleZombieAttack", "MaleZombieAttack",
    "FemaleZombieDeath", "MaleZombieDeath",
    "FemaleZombieVoiceA", "FemaleZombieVoiceB", "FemaleZombieVoiceC",
    "MaleZombieVoiceA", "MaleZombieVoiceB", "MaleZombieVoiceC",
    "FemaleZombieSprinterVoiceA", "FemaleZombieSprinterVoiceB",
    "MaleZombieSprinterVoiceA", "MaleZombieSprinterVoiceB",
    "FemaleZombieBiteA", "FemaleZombieBiteB", "FemaleZombieBiteC",
    "MaleZombieBiteA", "MaleZombieBiteB", "MaleZombieBiteC",
    "FemaleZombieSprinterBiteA", "FemaleZombieSprinterBiteB",
    "MaleZombieSprinterBiteA", "MaleZombieSprinterBiteB",
    "FemaleZombieCombined", "MaleZombieCombined",
}

local ALIASES = BridgeVoice.ZOMBIE_ALIASES

local function prefixOf(body)
    local prefix = nil
    pcall(function()
        local d = body:getDescriptor()
        if d ~= nil then prefix = d:getVoicePrefix() end
    end)
    return prefix
end

function BridgeVoice.applyPrefix(body)
    if body == nil then return false end
    local prefix = prefixOf(body)
    if prefix == BridgeVoice.SILENT_PREFIX then return true end
    local ok = false
    pcall(function()
        local d = body:getDescriptor()
        if d ~= nil then
            d:setVoicePrefix(BridgeVoice.SILENT_PREFIX)
            ok = true
        end
    end)
    return ok
end

function BridgeVoice.restore(body)
    if body == nil then return false end
    if prefixOf(body) ~= BridgeVoice.SILENT_PREFIX then return false end
    local female = false
    pcall(function() female = body:isFemale() == true end)
    local prefix = female and BridgeVoice.FEMALE_PREFIX or BridgeVoice.MALE_PREFIX
    local ok = false
    pcall(function()
        local d = body:getDescriptor()
        if d ~= nil then
            d:setVoicePrefix(prefix)
            ok = true
        end
    end)
    return ok
end

function BridgeVoice.suppress(body)
    if body == nil then return false end
    local emitter = nil
    pcall(function() emitter = body:getEmitter() end)
    if emitter == nil then return false end
    for i = 1, #ALIASES do
        pcall(function() emitter:stopSoundByName(ALIASES[i]) end)
    end
    return true
end

function BridgeVoice.ensure(body)
    if body == nil then return false end
    local ok = BridgeVoice.applyPrefix(body)
    BridgeVoice.suppress(body)
    return ok
end

function BridgeVoice.info(body)
    if body == nil then return "no body" end
    local prefix = "?"
    pcall(function()
        local d = body:getDescriptor()
        if d ~= nil then prefix = tostring(d:getVoicePrefix()) end
    end)
    local vname = "n/a"
    pcall(function()
        if type(body.getVoiceSoundName) == "function" then
            vname = tostring(body:getVoiceSoundName())
        end
    end)
    local playing = {}
    pcall(function()
        local emitter = body:getEmitter()
        if emitter == nil then return end
        for i = 1, #ALIASES do
            local alias = ALIASES[i]
            local on = false
            pcall(function() on = emitter:isPlaying(alias) == true end)
            if on then playing[#playing + 1] = alias end
        end
    end)
    local playingText = #playing > 0 and table.concat(playing, ",") or "none"
    return string.format("prefix=%s vname=%s playing=%s", tostring(prefix), tostring(vname), playingText)
end

return BridgeVoice
