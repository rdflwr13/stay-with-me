
BridgeCompanion = BridgeCompanion or {}
local C = BridgeCompanion

C.MASK_UID = "SWM:companion"

local BODY_VAR = "NotAloneBody"
local SCAN_MS = 2000
local KNOWN_MS = 2000

local bodiesCache = {}
local setCache = {}
local scannedAt = -1e12
local known = setmetatable({}, { __mode = "k" })

local function nowMs()
    return type(getTimestampMs) == "function" and getTimestampMs() or 0
end

local function global(name)
    return rawget(_G, name)
end

local function deepIdentity(z)
    local yes = false
    pcall(function()
        if type(z.getVariableBoolean) == "function" and z:getVariableBoolean(BODY_VAR) == true then
            yes = true
            return
        end
        if type(z.hasModData) == "function" and z:hasModData() then
            local data = z:getModData()
            if type(data) == "table" and data.notAloneBody == true then yes = true end
        end
    end)
    if yes then return true end
    local compat = global("BridgeCompat")
    if type(compat) == "table" and type(compat.isOurBody) == "function" then
        local ok, ours = pcall(compat.isOurBody, z)
        if ok and ours == true then return true end
    end
    local server = global("BridgeServer")
    if type(server) == "table" and type(server.isCompanionBody) == "function" then
        local ok, ours = pcall(server.isCompanionBody, z)
        if ok and ours == true then return true end
    end
    local bridge = global("Bridge")
    if type(bridge) == "table" and type(bridge.isCompanion) == "function" then
        local ok, ours = pcall(bridge.isCompanion, z)
        if ok and ours == true then return true end
    end
    return false
end

function C.isBody(z)
    if z == nil then return false end
    local bridge = global("Bridge")
    if type(bridge) == "table" and bridge.body ~= nil and bridge.body == z then return true end
    if setCache[z] == true then return true end
    local record = known[z]
    local t = nowMs()
    if record ~= nil and t - record.at < KNOWN_MS then return record.yes end
    local yes = deepIdentity(z)
    known[z] = { yes = yes, at = t }
    return yes
end

function C.bodies()
    local out, seen = {}, {}
    local bridge = global("Bridge")
    if type(bridge) == "table" and bridge.body ~= nil then
        out[1] = bridge.body
        seen[bridge.body] = true
    end
    local server = global("BridgeServer")
    if type(server) == "table" and type(server.bodies) == "table" then
        for _, body in pairs(server.bodies) do
            if body ~= nil and not seen[body] then
                out[#out + 1] = body
                seen[body] = true
            end
        end
    end
    local t = nowMs()
    if t - scannedAt > SCAN_MS then
        scannedAt = t
        bodiesCache = {}
        pcall(function()
            local cell = getCell()
            local list = cell ~= nil and cell:getZombieList() or nil
            if list == nil then return end
            for index = 0, list:size() - 1 do
                local z = list:get(index)
                if z ~= nil and C.isBody(z) then bodiesCache[#bodiesCache + 1] = z end
            end
        end)
    end
    for _, body in ipairs(bodiesCache) do
        if not seen[body] then
            out[#out + 1] = body
            seen[body] = true
        end
    end
    setCache = seen
    return out
end

local function restore(saved)
    for index = #saved, 1, -1 do
        local entry = saved[index]
        if entry.data.ProjectALifeUID == C.MASK_UID then entry.data.ProjectALifeUID = entry.before end
    end
end

function C.masked(fn, ...)
    local saved = {}
    for _, body in ipairs(C.bodies()) do
        local ok, data = pcall(function() return body:getModData() end)
        if ok and type(data) == "table" then
            local before = data.ProjectALifeUID
            if before ~= C.MASK_UID then
                data.ProjectALifeUID = C.MASK_UID
                saved[#saved + 1] = { data = data, before = before }
            else
                saved[#saved + 1] = { data = data, before = C.MASK_UID }
            end
        end
    end
    if #saved == 0 then return fn(...) end
    local result = { pcall(fn, ...) }
    restore(saved)
    if not result[1] then error(result[2], 0) end
    local unpackFn = table.unpack or unpack
    return unpackFn(result, 2)
end

function C.reset()
    bodiesCache = {}
    setCache = {}
    known = setmetatable({}, { __mode = "k" })
    scannedAt = -1e12
end

function C.status()
    local list = C.bodies()
    local maskedCount = 0
    for _, body in ipairs(list) do
        pcall(function()
            local data = body:getModData()
            if type(data) == "table" and data.ProjectALifeUID == C.MASK_UID then maskedCount = maskedCount + 1 end
        end)
    end
    return string.format("%d body(s), %d masked as %s", #list, maskedCount, C.MASK_UID)
end

return C