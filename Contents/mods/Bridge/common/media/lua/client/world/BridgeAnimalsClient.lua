local EVERY = 30
local tick = 0

local function enabled()
    local mod = rawget(_G, "BridgeAnimalsNoFear")
    return type(mod) == "table" and mod.npcCalm == true
end

local function companion(z)
    if z == nil then return false end
    local comp = rawget(_G, "BridgeCompanion")
    if type(comp) == "table" and type(comp.isBody) == "function" then
        local ok, yes = pcall(comp.isBody, z)
        if ok and yes == true then return true end
    end
    local bridge = rawget(_G, "Bridge")
    return type(bridge) == "table" and bridge.body == z
end

local function addAnimals(out, seen, list)
    if list == nil then return end
    local size = 0
    pcall(function() size = list:size() end)
    if size > 0 then
        for i = 0, size - 1 do
            local a = nil
            pcall(function() a = list:get(i) end)
            if a ~= nil and not seen[a] then
                seen[a] = true
                out[#out + 1] = a
            end
        end
        return
    end
    if type(list.iterator) == "function" then
        pcall(function()
            local it = list:iterator()
            while it:hasNext() do
                local a = it:next()
                if a ~= nil and not seen[a] then
                    seen[a] = true
                    out[#out + 1] = a
                end
            end
        end)
    end
end

local function eachAnimal(fn)
    local out, seen = {}, {}
    pcall(function()
        local cell = getCell()
        if cell ~= nil then addAnimals(out, seen, cell:getAnimals()) end
    end)
    pcall(function()
        if DesignationZoneAnimal == nil or DesignationZoneAnimal.getAllZones == nil then return end
        local zones = DesignationZoneAnimal.getAllZones()
        local size = 0
        pcall(function() size = zones:size() end)
        for i = 0, size - 1 do
            local zone = nil
            pcall(function() zone = zones:get(i) end)
            if zone ~= nil then
                local list = nil
                pcall(function()
                    if zone.getAnimalsConnected ~= nil then
                        list = zone:getAnimalsConnected()
                    elseif zone.getAnimals ~= nil then
                        list = zone:getAnimals()
                    end
                end)
                addAnimals(out, seen, list)
            end
        end
    end)
    for i = 1, #out do fn(out[i]) end
end

local function clearVisual(a)
    local changed = false
    local alerted = false
    pcall(function()
        if companion(a.spottedChr) then
            a.spottedChr = nil
            changed = true
        end
    end)
    pcall(function()
        if companion(a.alertedChr) then
            a.alertedChr = nil
            alerted = true
            changed = true
        end
    end)
    if alerted then pcall(function() a:setIsAlerted(false) end) end
    return changed
end

local function tickPass()
    if not enabled() then return end
    local mod = rawget(_G, "BridgeAnimalsNoFear")
    eachAnimal(function(a)
        if mod ~= nil and type(mod.isProtectedAnimal) == "function" then
            local ok, protected = pcall(mod.isProtectedAnimal, a)
            if ok and protected == true and clearVisual(a) then
                local log = rawget(_G, "BridgeLog")
                if type(log) == "table" and type(log.on) == "function" and log.on() then
                    print("[BridgeAnimalsNoFear] client cleared companion alert")
                end
            end
        end
    end)
end

if Events ~= nil and Events.OnTick ~= nil then
    Events.OnTick.Add(function()
        if not enabled() then return end
        tick = tick + 1
        if tick % EVERY ~= 0 then return end
        pcall(tickPass)
    end)
end
