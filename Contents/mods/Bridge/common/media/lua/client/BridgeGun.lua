


BridgeGun = BridgeGun or {}
BridgeGun.enabled = true
BridgeGun.installed = false
BridgeGun.ticks = 0
BridgeGun.metrics = { installs = 0, damage = 0, kill = 0, targets = 0, blasts = 0, blastRepair = 0, blastFail = 0 }

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGun] " .. tostring(text)) end end
local function warn(text) print("[BridgeGun] " .. tostring(text)) end
local logged = {}
local function logOnce(text)
    if logged[text] then return end
    logged[text] = true
    log(text)
end
local function warnOnce(text)
    if logged[text] then return end
    logged[text] = true
    warn(text)
end

local function ours(z)
    if z == nil then return false end
    if Bridge ~= nil and Bridge.body ~= nil and z == Bridge.body then return true end
    local marked = false
    pcall(function() marked = z.getVariableBoolean ~= nil and z:getVariableBoolean("NotAloneBody") == true end)
    return marked
end
BridgeGun.ours = ours


local function atActive()
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        for i = 0, mods:size() - 1 do
            local id = string.lower(tostring(mods:get(i)))
            if string.sub(id, 1, 1) == "\\" then id = string.sub(id, 2) end
            if string.find(id, "trajector", 1, true) ~= nil or string.sub(id, 1, 3) == "aty" then on = true end
        end
    end)
    return on
end
BridgeGun.atActive = atActive

local function core()
    local ok, module = pcall(require, "Advanced_trajectory_core")
    if ok and type(module) == "table" and type(module.damageZombie) == "function" then return module end
    return nil
end

local function globalCore()
    local g = rawget(_G, "Advanced_trajectory")
    if type(g) == "table" and (type(g.getshotzombies) == "function" or type(g.OnWeaponSwing) == "function") then return g end
    return nil
end

function BridgeGun.nearBlast(body, sq, info)
    local near = false
    pcall(function()
        if body == nil or sq == nil then return end
        if math.abs(math.floor(body:getZ()) - math.floor(sq:getZ())) > 1 then return end
        local range = 10
        local r = tonumber(info and info[3])
        if r ~= nil and r > 0 then range = math.max(range, r + 2) end
        local dx, dy = body:getX() - sq:getX(), body:getY() - sq:getY()
        near = dx * dx + dy * dy <= range * range
    end)
    return near
end

function BridgeGun.shieldBlast(body, boom, sq, info)
    local list, removed = nil, false
    pcall(function()
        local square = body:getCurrentSquare()
        if square == nil then return end
        list = square:getMovingObjects()
        if list == nil then return end
        local index = list:indexOf(body)
        if index ~= nil and index >= 0 then
            list:remove(body)
            removed = true
        end
    end)
    local ok, err = pcall(boom, sq, info)
    if removed then
        local listed = false
        pcall(function() listed = getCell():getZombieList():contains(body) end)
        if listed then
            pcall(function()
                local live = body:getCurrentSquare()
                local dest = (live ~= nil and live:getMovingObjects()) or list
                if dest ~= nil and dest:indexOf(body) < 0 then dest:add(body) end
            end)
        else



            BridgeGun.metrics.blastRepair = BridgeGun.metrics.blastRepair + 1
            if Bridge ~= nil and Bridge.mp and Bridge.body == body then
                Bridge.body = nil
                Bridge.kind = nil
            end
        end
    end
    if not ok then
        BridgeGun.metrics.blastFail = BridgeGun.metrics.blastFail + 1
        warnOnce("blast guard failed: " .. tostring(err))
    else
        BridgeGun.metrics.blasts = BridgeGun.metrics.blasts + 1
    end
    return ok
end

function BridgeGun.install()
    if BridgeGun.installed then return true end
    local found = false

    local t = core()
    if t ~= nil then
        found = true
        if type(t.damageZombie) == "function" then
            local damage = t.damageZombie
            t.damageZombie = function(zombie, ...)
                if ours(zombie) then
                    BridgeGun.metrics.damage = BridgeGun.metrics.damage + 1
                    return
                end
                return damage(zombie, ...)
            end
        end
        if type(t.killZombie) == "function" then
            local kill = t.killZombie
            t.killZombie = function(zombie, ...)
                if ours(zombie) then
                    BridgeGun.metrics.kill = BridgeGun.metrics.kill + 1
                    return
                end
                return kill(zombie, ...)
            end
        end
        if type(t.searchTargetNearBullet) == "function" then
            local search = t.searchTargetNearBullet
            t.searchTargetNearBullet = function(bulletTable, playerTable, missedShot)
                local target, kind = search(bulletTable, playerTable, missedShot)
                if ours(target) then
                    BridgeGun.metrics.targets = BridgeGun.metrics.targets + 1
                    return nil, nil
                end
                return target, kind
            end
        end
        if type(t.Boom) == "function" then
            local boom = t.Boom
            t.Boom = function(sq, info)
                local body = Bridge ~= nil and Bridge.body or nil
                if body == nil or not BridgeGun.nearBlast(body, sq, info) then return boom(sq, info) end
                return BridgeGun.shieldBlast(body, boom, sq, info)
            end
        end
    end

    local g = globalCore()
    if g ~= nil then
        found = true
        if type(g.getshotzombies) == "function" and g.getshotzombies ~= BridgeGun.guardShot then
            local search = g.getshotzombies
            local wrapper
            wrapper = function(weapon, player)
                local list = search(weapon, player)
                if type(list) == "table" then
                    for i = #list, 1, -1 do
                        local v = list[i]
                        local z = (type(v) == "table" and v[1]) or v
                        if ours(z) then table.remove(list, i) end
                    end
                end
                return list
            end
            BridgeGun.guardShot = wrapper
            g.getshotzombies = wrapper
        end
        if type(g.OnWeaponSwing) == "function" and g.OnWeaponSwing ~= BridgeGun.guardSwing then
            local swing = g.OnWeaponSwing
            local wrapper
            wrapper = function(character, handWeapon)
                local rank = g.zombierank
                if type(rank) == "table" then
                    for i = #rank, 1, -1 do
                        local v = rank[i]
                        local z = (type(v) == "table" and v[1]) or v
                        if ours(z) then table.remove(rank, i) end
                    end
                end
                return swing(character, handWeapon)
            end
            BridgeGun.guardSwing = wrapper
            g.OnWeaponSwing = wrapper
        end
    end

    if not found then return false end
    BridgeGun.installed = true
    BridgeGun.metrics.installs = BridgeGun.metrics.installs + 1
    log("Advanced Trajectory found: companion bullets and blasts handled")
    return true
end

function BridgeGun.tick()
    if not BridgeGun.enabled or BridgeGun.installed or BridgeGun.absent == true then return end
    if BridgeGun.absent == nil then
        BridgeGun.absent = not atActive()
        if BridgeGun.absent then return end
    end
    BridgeGun.ticks = BridgeGun.ticks + 1
    if BridgeGun.ticks > 1 and BridgeGun.ticks % 60 ~= 0 then return end
    BridgeGun.install()
end

Events.OnTick.Add(function() pcall(BridgeGun.tick) end)
Events.OnGameStart.Add(function()
    BridgeGun.ticks = 0
    BridgeGun.absent = nil
    pcall(BridgeGun.tick)
end)
