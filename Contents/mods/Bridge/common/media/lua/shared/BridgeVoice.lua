-- BridgeVoice - keeps the companion's zombie body from playing vanilla zombie
-- vocal aliases. The body is still an IsoZombie, so the engine can start an
-- idle/breath/attack voice from the descriptor voice bank at any time. We point
-- the bank at a nonexistent prefix and sweep the aliases already known to the
-- engine. Every engine call is pcall-wrapped: emitters may be missing on the
-- server and a single unknown alias must not abort the sweep.

BridgeVoice = BridgeVoice or {}

-- Nonexistent voice bank: the engine resolves <prefix><suffix>, finds no sound,
-- and stays quiet (same approach as Bandits / Project ALife).
BridgeVoice.SILENT_PREFIX = "NotAZombie"

-- Gender-appropriate vanilla bank, used only when handing a silenced body back.
BridgeVoice.FEMALE_PREFIX = "FemaleZombie"
BridgeVoice.MALE_PREFIX = "MaleZombie"

-- Vocal aliases registered by the base game voice table. Idle is the one that
-- previously slipped through the old VoiceA/B/C-only sweep.
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

-- Point the descriptor at the silent bank. Only called for bodies the mod owns;
-- does nothing when the descriptor is unavailable.
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

-- Restore the vanilla bank only when we are the ones who silenced the body.
-- Released or pooled bodies must not stay silent as normal zombies.
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

-- Stop every tracked zombie vocal on the body emitter. Each alias is isolated so
-- one unknown name cannot abort the rest of the sweep.
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

-- Short diagnostic: prefix, engine-cached voice name when available, and any
-- tracked alias still reporting as playing.
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
