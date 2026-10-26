








BridgeSound = BridgeSound or {}
BridgeSound.last = {}
BridgeSound.logged = {}
BridgeSound.info = "none"


local FENCE_LOW = { Wood = 0, Metal = 1, Sandbag = 2, Gravelbag = 3, Barbwire = 4, RoadBlock = 5, MetalGate = 6 }
local FENCE_HIGH = { Wood = 0, Metal = 1, MetalGate = 2 }

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeSound] " .. tostring(text)) end end
local function warn(text) print("[BridgeSound] " .. tostring(text)) end



local function playStyled(emitter, sound, voiceType, pitch)
    local id, path = 0, "vocals"
    pcall(function() id = emitter:playVocals(sound) end)
    if id == nil or id == 0 then
        path = "sound"
        pcall(function() id = emitter:playSound(sound) end)
    end
    if id ~= nil and id ~= 0 then
        pcall(function()
            emitter:setParameterValueByName(id, "CharacterVoiceType", voiceType)
            emitter:setParameterValueByName(id, "CharacterVoicePitch", pitch)
        end)
    end
    return id, path
end

function BridgeSound.voice(body, name, gap, style)
    if body == nil then return "no body" end
    if type(style) ~= "table" or type(style.prefix) ~= "string" or style.prefix == "" then
        style = nil
        pcall(function() style = BridgeData.voiceOf(Bridge.store) end)
        if type(style) ~= "table" or type(style.prefix) ~= "string" or style.prefix == "" then
            style = BridgeData.defaultVoice(Bridge.store)
        end
    end
    local suffix = tostring(name)
    local key = tostring(style.prefix) .. suffix
    local wait = gap or 30
    local lastTick = BridgeSound.last[key] or -99999
    if wait > 0 and Bridge.time - lastTick < wait then return "too soon" end
    BridgeSound.last[key] = Bridge.time
    local emitter = nil
    pcall(function() emitter = body:getEmitter() end)
    if emitter == nil then return "no emitter" end
    local voiceType = tonumber(style.type) or 0
    local pitch = tonumber(style.pitch) or 0
    local sound = key
    local id, path = playStyled(emitter, sound, voiceType, pitch)
    local fallback = false
    if id == nil or id == 0 then
        local def = BridgeData.defaultVoice(Bridge.store)
        local alt = tostring(def.prefix) .. suffix
        if alt ~= sound then
            id, path = playStyled(emitter, alt, voiceType, pitch)
            if id ~= nil and id ~= 0 then
                sound, fallback = alt, true
            end
        end
    end
    local result = string.format("%s via %s id=%s type=%d pitch=%d%s", sound, path, tostring(id),
        voiceType, pitch, fallback and " fallback" or "")
    BridgeSound.info = result
    local logKey = fallback and ("fallback:" .. key) or sound
    if BridgeSound.logged[logKey] ~= path then
        BridgeSound.logged[logKey] = path
        log("voice " .. result)
    end
    return result
end

function BridgeSound.preview(body, style, name)
    return BridgeSound.voice(body, name or "ShoutHey", 0, style)
end



function BridgeSound.sfx(body, sound)
    if body == nil then return nil end
    local id = nil
    pcall(function() id = body:getEmitter():playSound(sound) end)
    if id == 0 then id = nil end
    BridgeSound.info = string.format("%s id=%s", tostring(sound), tostring(id))
    if not BridgeSound.logged[sound] then
        BridgeSound.logged[sound] = true
        log("sfx " .. BridgeSound.info)
    end
    return id
end


function BridgeSound.fenceMaterial(body, high)
    local found = nil
    pcall(function()
        local sq = body:getCurrentSquare()
        local cell = getCell()
        local around = { sq,
            cell:getGridSquare(sq:getX() + 1, sq:getY(), sq:getZ()), cell:getGridSquare(sq:getX() - 1, sq:getY(), sq:getZ()),
            cell:getGridSquare(sq:getX(), sq:getY() + 1, sq:getZ()), cell:getGridSquare(sq:getX(), sq:getY() - 1, sq:getZ()) }
        for _, s in ipairs(around) do
            if s ~= nil then
                local objects = s:getObjects()
                for i = 0, objects:size() - 1 do
                    local o = objects:get(i)
                    local fence = false
                    pcall(function() fence = (high and o:isTallHoppable()) or ((not high) and o:isHoppable()) end)
                    if fence then
                        local props = o:getProperties()
                        found = props:get(high and "FenceTypeHigh" or "FenceTypeLow") or props:get("FenceTypeHigh")
                        if found ~= nil then return end
                    end
                end
            end
        end
    end)
    return found
end



function BridgeSound.fence(body, sound, high)
    local material = BridgeSound.fenceMaterial(body, high)
    local value = (high and FENCE_HIGH or FENCE_LOW)[material or "Wood"] or 0
    local result = "none"
    pcall(function()
        local emitter = body:getEmitter()
        local id = emitter:playSound(sound)
        if id ~= nil and id ~= 0 then
            emitter:setParameterValueByName(id, high and "FenceTypeHigh" or "FenceTypeLow", value)
        end
        result = string.format("%s %s=%s id=%s", sound, tostring(material), tostring(value), tostring(id))
    end)
    BridgeSound.info = result
    if not BridgeSound.logged[sound] then
        BridgeSound.logged[sound] = true
        log("fence " .. result)
    end
    return result
end

log("loaded")
