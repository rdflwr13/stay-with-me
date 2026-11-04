
if not isServer() then return end

local function register()
    if BridgeServer == nil or BridgeServer.Commands == nil then return end
    if BridgeAnimals == nil then return end
    if BridgeServer.Commands.animalHit ~= nil then return end

    BridgeServer.Commands.animalHit = function(player, args)
        if player == nil or args == nil then return end
        local who = nil
        pcall(function() who = player:getUsername() end)
        if who == nil then return end
        local body = BridgeServer.bodies[who]
        if body == nil then return end
        local id = tonumber(args.id)
        if id == nil then return end

        local target = nil
        pcall(function()
            local list = getCell():getAnimals()
            if list == nil then return end
            for i = 0, list:size() - 1 do
                local a = list:get(i)
                if a ~= nil and a:getOnlineID() == id then
                    target = a
                    break
                end
            end
        end)
        if target == nil then return end
        if not BridgeAnimals.hostile(target) then return end

        BridgeAnimals.apply(target, tonumber(args.dmg) or 0, body)
    end
end

Events.OnGameStart.Add(register)
Events.OnServerStarted.Add(register)

local NPC_CALM_RADIUS = 10
local NPC_CALM_TICK = 20
local calmTick = 0
local stressBase = setmetatable({}, { __mode = "k" })
local npcNear = setmetatable({}, { __mode = "k" })

local function noFear()
    local mod = rawget(_G, "BridgeAnimalsNoFear")
    if type(mod) ~= "table" or mod.npcCalm ~= true then return nil end
    return mod
end

local function calmLog(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeAnimalsNoFear] " .. tostring(text))
    end
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

local function countThreats(a, mod)
    local npc, real = 0, 0
    local ax, ay, az = a:getX(), a:getY(), a:getZ()
    local r2 = NPC_CALM_RADIUS * NPC_CALM_RADIUS
    pcall(function()
        local list = getCell():getZombieList()
        if list == nil then return end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and not z:isDead() then
                local dx, dy = z:getX() - ax, z:getY() - ay
                if math.abs(z:getZ() - az) < 1 and dx * dx + dy * dy <= r2 then
                    if mod.isCompanionZombie(z) then
                        npc = npc + 1
                    else
                        real = real + 1
                    end
                end
            end
        end
    end)
    return real, npc
end

local function clearCompanionAlert(a, mod)
    local cleared = false
    local alerted = false
    pcall(function()
        if mod.isCompanionZombie(a.spottedChr) then
            a.spottedChr = nil
            cleared = true
        end
    end)
    pcall(function()
        if mod.isCompanionZombie(a.alertedChr) then
            a.alertedChr = nil
            alerted = true
            cleared = true
        end
    end)
    pcall(function()
        if mod.isCompanionZombie(a.atkTarget) then
            a.atkTarget = nil
            cleared = true
        end
    end)
    if alerted then pcall(function() a:setIsAlerted(false) end) end
    return cleared
end

local function baselineOnly(a)
    local cur = nil
    pcall(function() cur = a:getStress() end)
    if type(cur) == "number" then stressBase[a] = cur end
end

local function rollbackStress(a)
    local cur = nil
    pcall(function() cur = a:getStress() end)
    if type(cur) ~= "number" then return false end
    local prev = stressBase[a]
    if prev == nil then
        stressBase[a] = cur
        return false
    end
    if cur > prev then
        local ok = false
        pcall(function()
            a:setDebugStress(prev)
            ok = true
        end)
        if not ok then pcall(function() a:changeStress(-(cur - prev)) end) end
        stressBase[a] = prev
        return true
    end
    stressBase[a] = cur
    return false
end

local function npcCalmTick(force)
    local mod = noFear()
    if mod == nil then return end
    if force ~= true then
        calmTick = calmTick + 1
        if calmTick % NPC_CALM_TICK ~= 0 then return end
    end
    eachAnimal(function(a)
        if mod.isProtectedAnimal(a) then
            local real, npc = countThreats(a, mod)
            if npc > 0 then clearCompanionAlert(a, mod) end
            if real == 0 and npc > 0 then
                if rollbackStress(a) and npcNear[a] ~= true then
                    npcNear[a] = true
                    calmLog("companion near: alert cleared and stress rolled back")
                end
            else
                npcNear[a] = nil
                baselineOnly(a)
            end
        end
    end)
end

Events.OnTick.Add(function() pcall(npcCalmTick) end)
if Events.EveryOneMinute ~= nil then
    Events.EveryOneMinute.Add(function() pcall(npcCalmTick, true) end)
end
