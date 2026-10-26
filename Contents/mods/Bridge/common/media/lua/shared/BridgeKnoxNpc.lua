BridgeKnoxNpc = BridgeKnoxNpc or {}

local MOD_ID = "KnoxEventExpandedNpc"
local CACHE_MS = 250

local activeCache = nil
local apiCache = nil
local npcsCache, npcsAt = nil, 0

local function nowMs()
    local t = 0
    if getTimestampMs ~= nil then pcall(function() t = getTimestampMs() end) end
    return t
end


function BridgeKnoxNpc.active()
    if activeCache == true then return true end
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(MOD_ID) or mods:contains("\\" .. MOD_ID))
    end)
    if on then activeCache = true end
    return on
end


function BridgeKnoxNpc.api()
    if not BridgeKnoxNpc.active() then return nil end
    if apiCache ~= nil then return apiCache end
    pcall(function()
        local loader = rawget(_G, "KnoxEventLoader")
        if loader ~= nil and type(loader.getAPI) == "function" then
            apiCache = loader.getAPI("npc")
        end
    end)
    return apiCache
end


function BridgeKnoxNpc.npcs()
    if not BridgeKnoxNpc.active() then return nil end
    local now = nowMs()
    if npcsCache ~= nil and now > 0 and (now - npcsAt) < CACHE_MS then return npcsCache end
    local list = nil
    local api = BridgeKnoxNpc.api()
    if api ~= nil then pcall(function() list = api:getWorldNpcs() end) end
    npcsCache, npcsAt = list, now
    return list
end


function BridgeKnoxNpc.isNpc(z)
    if z == nil or not BridgeKnoxNpc.active() then return false end
    local yes = false
    pcall(function() yes = instanceof(z, "IsoNpcPlayer") == true end)
    return yes
end


function BridgeKnoxNpc.idOf(npc)
    local id = nil
    pcall(function() id = npc:getNpcID() end)
    return id
end


function BridgeKnoxNpc.allowMelee()
    if not BridgeKnoxNpc.active() then return false end
    if Bridge ~= nil and Bridge.mp == true then return false end
    return true
end


local function alive(npc)
    local ok = false
    pcall(function() ok = npc:isAlive() == true and npc:isDead() ~= true end)
    return ok
end


local function sameGroup(npc, player)
    local same = false
    pcall(function()
        local api = BridgeKnoxNpc.api()
        if api == nil then return end
        local meta = npc:getMetaCharacter()
        if meta == nil then return end
        local mine = api:getGroup(player)
        local theirs = meta:getGroup()
        if mine ~= nil and theirs ~= nil and mine == theirs then same = true end
    end)
    return same
end


function BridgeKnoxNpc.hostile(npc, player)
    if npc == nil or player == nil then return false end
    if not BridgeKnoxNpc.active() then return false end
    if Bridge ~= nil and Bridge.body == npc then return false end
    if not alive(npc) then return false end
    if sameGroup(npc, player) then return false end
    local yes = false
    pcall(function()
        local st = npc:getAggressiveTo(player)
        if st ~= nil and string.find(string.upper(tostring(st)), "AGGRESSIVE", 1, true) ~= nil then
            yes = true
            return
        end
        if npc:getRobberyTarget() == player then yes = true return end
        if npc:getTrespassingTarget() == player then yes = true return end
    end)
    return yes
end


function BridgeKnoxNpc.allowGunTarget(npc, player)
    if not BridgeKnoxNpc.isNpc(npc) then return false end
    return BridgeKnoxNpc.hostile(npc, player)
end


function BridgeKnoxNpc.near(x, y, r, player)
    local out = {}
    if x == nil or y == nil or r == nil or r <= 0 then return out end
    local list = BridgeKnoxNpc.npcs()
    if list == nil then return out end
    local r2 = r * r
    local ok = pcall(function()
        for i = 0, list:size() - 1 do
            local n = list:get(i)
            if n ~= nil and BridgeKnoxNpc.hostile(n, player) then
                local dx, dy = n:getX() - x, n:getY() - y
                if dx * dx + dy * dy <= r2 then out[#out + 1] = n end
            end
        end
    end)
    if not ok then return {} end
    return out
end


function BridgeKnoxNpc.byId(id)
    if id == nil then return nil end
    local list = BridgeKnoxNpc.npcs()
    if list == nil then return nil end
    local found = nil
    pcall(function()
        for i = 0, list:size() - 1 do
            local n = list:get(i)
            if n ~= nil and BridgeKnoxNpc.idOf(n) == id then
                found = n
                return
            end
        end
    end)
    return found
end


function BridgeKnoxNpc.hit(victim, body, weapon, damage, crit)
    if victim == nil or body == nil or weapon == nil then return false, 0, 0, false end
    local hpBefore, hpAfter = 0, 0
    pcall(function() hpBefore = victim:getHealth() end)
    hpAfter = hpBefore
    pcall(function() victim:setAttackedBy(body) end)
    pcall(function() victim:handleNpcHitReaction(weapon, body) end)
    local ok = false
    pcall(function()
        victim:Hit(weapon, body, damage, false, 1, false)
        ok = true
    end)
    pcall(function() hpAfter = victim:getHealth() end)
    local killed = false
    pcall(function() killed = victim:isDead() == true or victim:getHealth() <= 0 end)
    return ok, hpBefore, hpAfter, killed
end
