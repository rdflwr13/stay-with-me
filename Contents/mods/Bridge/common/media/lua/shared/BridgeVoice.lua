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

BridgeVoice.VANILLA_STYLES = {
    { name = "Kate", prefix = "VoiceFemale", type = 0, bodyType = 1 },
    { name = "Casey-Jo", prefix = "VoiceFemale", type = 1, bodyType = 1 },
    { name = "Maryanne", prefix = "VoiceFemale", type = 2, bodyType = 1 },
    { name = "Janine", prefix = "VoiceFemale", type = 3, bodyType = 1 },
    { name = "Bob", prefix = "VoiceMale", type = 0, bodyType = 2 },
    { name = "Hank", prefix = "VoiceMale", type = 1, bodyType = 2 },
    { name = "James", prefix = "VoiceMale", type = 2, bodyType = 2 },
    { name = "Chris", prefix = "VoiceMale", type = 3, bodyType = 2 },
}

BridgeVoice.registry = BridgeVoice.registry or {}

local function voiceTypeMax()
    if BridgeData ~= nil and type(BridgeData.VOICE_TYPE_MAX) == "number" then return BridgeData.VOICE_TYPE_MAX end
    return 15
end

local function clampType(value)
    local v = math.floor(tonumber(value) or 0)
    if v < 0 then v = 0 end
    if v > voiceTypeMax() then v = voiceTypeMax() end
    return v
end

local function clampPitch(value)
    local v = math.floor((tonumber(value) or 0) + 0.5)
    if v < -100 then v = -100 end
    if v > 100 then v = 100 end
    return v
end

local function normBodyType(value)
    local v = math.floor(tonumber(value) or 0)
    if v ~= 1 and v ~= 2 then return 0 end
    return v
end

local function field(style, method, key)
    local value = nil
    pcall(function()
        if type(style[method]) == "function" then value = style[method](style) end
    end)
    if value == nil then pcall(function() value = style[key] end) end
    return value
end

local function normStyle(style)
    if style == nil then return nil end
    local name = field(style, "getName", "name")
    local prefix = field(style, "getPrefix", "prefix")
    local ty = field(style, "getVoiceType", "voiceType")
    if ty == nil then pcall(function() ty = style.type end) end
    local bodyType = field(style, "getBodyTypeDefault", "bodyTypeDefault")
    if bodyType == nil then pcall(function() bodyType = style.bodyType end) end
    if type(name) ~= "string" or name == "" then return nil end
    if type(prefix) ~= "string" or prefix == "" then return nil end
    return {
        name = name,
        prefix = prefix,
        type = clampType(ty),
        pitch = 0,
        bodyType = normBodyType(bodyType),
    }
end

function BridgeVoice.engineStyles()
    local out = {}
    local list = nil
    pcall(function() list = getAllVoiceStyles() end)
    if list ~= nil then
        local n = nil
        pcall(function() n = tonumber(list:size()) end)
        if n ~= nil then
            pcall(function()
                for i = 0, n - 1 do
                    local s = normStyle(list:get(i))
                    if s ~= nil then out[#out + 1] = s end
                end
            end)
        else
            pcall(function()
                if type(list) == "table" then
                    for i = 1, #list do
                        local s = normStyle(list[i])
                        if s ~= nil then out[#out + 1] = s end
                    end
                end
            end)
        end
    end
    if #out == 0 then
        for i = 1, #BridgeVoice.VANILLA_STYLES do out[#out + 1] = normStyle(BridgeVoice.VANILLA_STYLES[i]) end
    end
    return out
end

function BridgeVoice.registerStyle(style)
    if type(style) ~= "table" then return false end
    local name = style.name
    if type(name) ~= "string" or name == "" or #name > 48 then return false end
    if string.find(name, "[%z\1-\31]") ~= nil then return false end
    local prefix = style.prefix
    if type(prefix) ~= "string" or prefix == "" or #prefix > 48 then return false end
    if string.find(prefix, "[^%w_]") ~= nil then return false end
    local ty = clampType(style.type)
    local key = prefix .. ":" .. tostring(ty)
    if BridgeVoice.registry[key] ~= nil then return false end
    BridgeVoice.registry[key] = {
        name = name,
        prefix = prefix,
        type = ty,
        pitch = clampPitch(style.pitch),
        bodyType = normBodyType(style.bodyType),
    }
    return true
end

function BridgeVoice.stylesFor(gender)
    local want = (gender == "male") and 2 or 1
    local out, seen = {}, {}
    local function add(style)
        if style == nil then return end
        local bt = normBodyType(style.bodyType)
        if bt ~= 0 and bt ~= want then return end
        local key = tostring(style.prefix) .. ":" .. tostring(style.type)
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = {
            name = style.name,
            prefix = style.prefix,
            type = clampType(style.type),
            pitch = clampPitch(style.pitch),
            bodyType = bt,
        }
    end
    local list = BridgeVoice.engineStyles()
    for i = 1, #list do add(list[i]) end
    local keys = {}
    for key in pairs(BridgeVoice.registry) do keys[#keys + 1] = key end
    table.sort(keys)
    for i = 1, #keys do add(BridgeVoice.registry[keys[i]]) end
    return out
end

function BridgeVoice.findStyle(name, prefix, ty)
    local wantName = tostring(name or "")
    local wantPrefix = tostring(prefix or "")
    local wantType = clampType(ty)
    local function matches(style)
        if style == nil then return nil end
        if style.prefix == wantPrefix and clampType(style.type) == wantType
            and tostring(style.name) == wantName then
            return { name = style.name, prefix = style.prefix, type = clampType(style.type),
                pitch = clampPitch(style.pitch), bodyType = normBodyType(style.bodyType) }
        end
        return nil
    end
    local list = BridgeVoice.engineStyles()
    for i = 1, #list do
        local found = matches(list[i])
        if found ~= nil then return found end
    end
    local keys = {}
    for key in pairs(BridgeVoice.registry) do keys[#keys + 1] = key end
    table.sort(keys)
    for i = 1, #keys do
        local found = matches(BridgeVoice.registry[keys[i]])
        if found ~= nil then return found end
    end
    return nil
end

function BridgeVoice.applyStyle(body, voice)
    if body == nil or type(voice) ~= "table" then return false end
    local ty = clampType(voice.type)
    local pitch = clampPitch(voice.pitch)
    local ok = false
    pcall(function()
        local d = body:getDescriptor()
        if d ~= nil then
            d:setVoiceType(ty)
            d:setVoicePitch(pitch)
            ok = true
        end
    end)
    return ok
end

return BridgeVoice
