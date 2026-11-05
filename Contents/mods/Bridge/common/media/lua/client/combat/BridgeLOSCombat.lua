BridgeLOSCombat = BridgeLOSCombat or {}

local M = BridgeLOSCombat

local CACHE_MS = 250
local RETRY_MS = 2000

M.hooks = M.hooks or {}

local idCache = setmetatable({}, { __mode = "k" })

local installed = false
local logged = false
local listCache, listAt = nil, 0
local nextInstall = 0

local function compatOn()
    return BridgeLOSCompat ~= nil and type(BridgeLOSCompat.active) == "function"
        and BridgeLOSCompat.active() == true
end

function M.api()
    local los = rawget(_G, "LastOnesStanding")
    if type(los) ~= "table" then return nil end
    if type(los.Bodies) ~= "table" or type(los.Bodies.byId) ~= "table" then return nil end
    if type(los.Records) ~= "table" or type(los.Records.get) ~= "function" then return nil end
    if type(los.Relations) ~= "table" or type(los.Relations.hostileToPlayer) ~= "function" then return nil end
    if type(los.idOf) ~= "function" then return nil end
    return los
end

function M.active()
    if not compatOn() then return false end
    if Bridge ~= nil and Bridge.mp == true then return false end
    return M.api() ~= nil
end

local function playerOf()
    local p = nil
    if BridgeData ~= nil and type(BridgeData.owner) == "function" then
        pcall(function() p = BridgeData.owner() end)
    end
    return p
end

function M.idOf(npc)
    if npc == nil then return nil end
    local cached = idCache[npc]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    if npc == playerOf() then return nil end
    local los = rawget(_G, "LastOnesStanding")
    if type(los) ~= "table" then return nil end
    local id = nil
    if type(los.idOf) == "function" then pcall(function() id = los.idOf(npc) end) end
    if id == nil then
        pcall(function()
            local md = npc:getModData()
            if md ~= nil then id = md.LOS_Id end
        end)
    end
    if id == nil then id = false end
    idCache[npc] = id
    if id == false then return nil end
    return id
end

function M.recordOf(npc)
    local los = M.api()
    if los == nil then return nil end
    local id = M.idOf(npc)
    if id == nil then return nil end
    local rec = nil
    pcall(function() rec = los.Records.get(id) end)
    return rec
end

function M.byId(id)
    if id == nil then return nil end
    local los = M.api()
    if los == nil then return nil end
    local npc = nil
    pcall(function() npc = los.Bodies.byId[id] end)
    return npc
end

function M.hp(npc)
    if npc == nil then return 0 end
    local los = rawget(_G, "LastOnesStanding")
    local hp = nil
    if type(los) == "table" and type(los.hp) == "function" then
        pcall(function() hp = los.hp(npc) end)
    end
    if type(hp) ~= "number" then
        hp = nil
        pcall(function() hp = npc:getHealth() end)
    end
    if type(hp) ~= "number" then return 0 end
    return hp
end

function M.alive(npc)
    if npc == nil then return false end
    local ok = false
    pcall(function() ok = npc:isAlive() == true and npc:isDead() ~= true end)
    return ok
end

function M.isNpc(z)
    if z == nil then return false end
    if Bridge ~= nil and Bridge.body == z then return false end
    return M.idOf(z) ~= nil
end

function M.hostile(npc, player)
    if npc == nil then return false end
    if not M.isNpc(npc) then return false end
    if not M.active() then return false end
    if Bridge ~= nil and Bridge.body == npc then return false end
    if not M.alive(npc) then return false end
    local id = M.idOf(npc)
    if id == nil then return false end
    local los = M.api()
    local held = false
    if los.Surrender ~= nil and type(los.Surrender.isHeld) == "function" then
        pcall(function() held = los.Surrender.isHeld(id) == true end)
    end
    if held then return false end
    local rec = M.recordOf(npc)
    if rec == nil then return false end
    local yes = false
    pcall(function() yes = los.Relations.hostileToPlayer(rec) == true end)
    return yes
end

local function hostileList(player)
    local los = M.api()
    if los == nil then return {} end
    local now = 0
    if getTimestampMs ~= nil then pcall(function() now = getTimestampMs() end) end
    if listCache ~= nil and now > 0 and (now - listAt) < CACHE_MS then return listCache end
    local out = {}
    pcall(function()
        for _, npc in pairs(los.Bodies.byId) do
            if npc ~= nil and M.hostile(npc, player) then out[#out + 1] = npc end
        end
    end)
    listCache, listAt = out, now
    return out
end

function M.near(x, y, r, player)
    local out = {}
    if x == nil or y == nil or r == nil or r <= 0 then return out end
    local list = hostileList(player)
    local r2 = r * r
    for i = 1, #list do
        local npc = list[i]
        local dx, dy = nil, nil
        pcall(function()
            dx, dy = npc:getX() - x, npc:getY() - y
        end)
        if dx ~= nil and dy ~= nil and dx * dx + dy * dy <= r2 then out[#out + 1] = npc end
    end
    return out
end

function M.hit(victim, body, weapon, damage, crit)
    if victim == nil or body == nil or weapon == nil then return false, 0, 0, false end
    local hpBefore = M.hp(victim)
    local ranged = false
    pcall(function() ranged = weapon:isRanged() == true end)
    local ok = false
    if ranged then
        local los = rawget(_G, "LastOnesStanding")
        if type(los) == "table" and type(los.PlayerBulletHit) == "function" then
            local called, res = pcall(los.PlayerBulletHit, victim, body, weapon, damage, nil)
            if called and res ~= nil and res ~= false then ok = true end
        end
    end
    if not ok then
        pcall(function()
            victim:Hit(weapon, body, damage, false, 1.0)
            ok = true
        end)
    end
    local hpAfter = M.hp(victim)
    local died = false
    pcall(function() died = victim:isDead() == true or victim:isAlive() ~= true end)
    return ok, hpBefore, hpAfter, died
end

local function hook(tbl, field, key, build)
    if type(tbl) ~= "table" then return false end
    local cur = tbl[field]
    if type(cur) ~= "function" then return false end
    local rec = M.hooks[key]
    if rec ~= nil and rec.wrapper == cur then return true end
    local first = cur
    if rec ~= nil and rec.first ~= nil then first = rec.first end
    local wrapper = build(cur)
    M.hooks[key] = { first = first, original = cur, wrapper = wrapper }
    tbl[field] = wrapper
    return true
end

function M.installInto(knox)
    if type(knox) ~= "table" then return false end
    if not compatOn() then return true end
    if Bridge ~= nil and Bridge.mp == true then return true end
    if M.api() == nil then return false end

    hook(knox, "active", "knox.active", function(orig)
        return function() return orig() == true or M.active() end
    end)

    hook(knox, "isNpc", "knox.isNpc", function(orig)
        return function(z)
            if orig(z) == true then return true end
            return M.isNpc(z)
        end
    end)

    hook(knox, "idOf", "knox.idOf", function(orig)
        return function(npc)
            local id = M.idOf(npc)
            if id ~= nil then return id end
            return orig(npc)
        end
    end)

    hook(knox, "byId", "knox.byId", function(orig)
        return function(id)
            local npc = orig(id)
            if npc ~= nil then return npc end
            return M.byId(id)
        end
    end)

    hook(knox, "hostile", "knox.hostile", function(orig)
        return function(npc, player)
            if M.isNpc(npc) then return M.hostile(npc, player) end
            return orig(npc, player)
        end
    end)

    hook(knox, "near", "knox.near", function(orig)
        return function(x, y, r, player)
            local out, seen = {}, {}
            local ok, base = pcall(orig, x, y, r, player)
            if ok and type(base) == "table" then
                for i = 1, #base do
                    local npc = base[i]
                    if npc ~= nil and not seen[npc] then
                        seen[npc] = true
                        out[#out + 1] = npc
                    end
                end
            end
            local extra = M.near(x, y, r, player)
            for i = 1, #extra do
                local npc = extra[i]
                if npc ~= nil and not seen[npc] then
                    seen[npc] = true
                    out[#out + 1] = npc
                end
            end
            return out
        end
    end)

    hook(knox, "allowMelee", "knox.allowMelee", function(orig)
        return function() return orig() == true or M.active() end
    end)

    hook(knox, "allowGunTarget", "knox.allowGunTarget", function(orig)
        return function(npc, player)
            if M.isNpc(npc) then return M.hostile(npc, player) end
            return orig(npc, player)
        end
    end)

    hook(knox, "hit", "knox.hit", function(orig)
        return function(victim, body, weapon, damage, crit)
            if M.isNpc(victim) then return M.hit(victim, body, weapon, damage, crit) end
            return orig(victim, body, weapon, damage, crit)
        end
    end)

    return true
end

function M.installClient()
    hook(BridgeFight, "assistWindow", "fight.assistWindow", function(orig)
        return function(body, red)
            orig(body, red)
            if red == nil then return end
            local h = nil
            pcall(function() h = red:getLastHitCharacter() end)
            if h == nil or not M.hostile(h, red) then return end
            if BridgeFight ~= nil then
                BridgeFight.playerFightUntil = ((Bridge ~= nil and Bridge.time) or 0) + 4 * 60
                BridgeFight.playerTarget = h
            end
        end
    end)

    hook(BridgeFight, "gunShove", "fight.gunShove", function(orig)
        return function(body, t)
            if M.isNpc(t) then return false end
            return orig(body, t)
        end
    end)

    hook(BridgeKills, "credit", "kills.credit", function(orig)
        return function(z)
            if M.isNpc(z) then return false end
            return orig(z)
        end
    end)

    hook(BridgeCallout, "gunKill", "callout.gunKill", function(orig)
        return function(z)
            if M.isNpc(z) then return false end
            return orig(z)
        end
    end)
end

function M.install()
    if not compatOn() then return false end
    if Bridge ~= nil and Bridge.mp == true then return false end
    if M.api() == nil then return false end
    local knox = rawget(_G, "BridgeKnoxNpc")
    if type(knox) ~= "table" then return false end
    M.installInto(knox)
    M.installClient()
    installed = true
    if not logged then
        logged = true
        print("[BridgeLOS] combat bridge installed")
    end
    return true
end

function M.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local saved = {
        los = rawget(_G, "LastOnesStanding"),
        knox = rawget(_G, "BridgeKnoxNpc"),
        compat = rawget(_G, "BridgeLOSCompat"),
        bridge = rawget(_G, "Bridge"),
        fight = rawget(_G, "BridgeFight"),
        kills = rawget(_G, "BridgeKills"),
        callout = rawget(_G, "BridgeCallout"),
        hooks = M.hooks,
        installed = installed,
        logged = logged,
        cache = listCache,
        cacheAt = listAt,
    }

    local function npc(id, hostile, alive, dead)
        local n = { mod = { LOS_Id = id }, x = 0, y = 0, health = 100 }
        n.rec = { hostile = hostile }
        n.alive = alive ~= false
        n.dead = dead == true
        function n:getModData() return self.mod end
        function n:getX() return self.x end
        function n:getY() return self.y end
        function n:getHealth() return self.health end
        function n:isAlive() return self.alive end
        function n:isDead() return self.dead end
        function n:Hit(w, b, d, c, k) self.hitCalled = true end
        return n
    end

    local player = npc(nil, false, true, false)
    local companion = npc(nil, false, true, false)
    local hostileNpc = npc(1, true, true, false)
    local neutralNpc = npc(2, false, true, false)
    local surrenderNpc = npc(3, true, true, false)
    local deadNpc = npc(4, true, false, true)
    local knoxNpc = npc(nil, false, true, false)
    local plain = npc(nil, false, true, false)

    local bodies = { [1] = hostileNpc, [2] = neutralNpc, [3] = surrenderNpc, [4] = deadNpc }
    local records = { [1] = hostileNpc.rec, [2] = neutralNpc.rec, [3] = surrenderNpc.rec, [4] = deadNpc.rec }
    local los = {
        Bodies = { byId = bodies },
        Records = { get = function(id) return records[tonumber(id)] end },
        Relations = { hostileToPlayer = function(rec) return rec ~= nil and rec.hostile == true end },
        idOf = function(chr)
            if chr == nil then return nil end
            local md = chr:getModData()
            return md and md.LOS_Id or nil
        end,
        hp = function(chr) return chr:getHealth() end,
        PlayerBulletHit = function(chr) chr.bulletHit = true return true end,
        Surrender = { isHeld = function(id) return id == 3 end },
    }

    local knoxStub = {
        active = function() return true end,
        isNpc = function(z) return z == knoxNpc end,
        idOf = function(z) if z == knoxNpc then return 99 end return nil end,
        byId = function(id) if id == 99 then return knoxNpc end return nil end,
        hostile = function(z) return z == knoxNpc end,
        near = function() return { knoxNpc } end,
        allowMelee = function() return true end,
        allowGunTarget = function(z) return z == knoxNpc end,
        hit = function(v) if v == knoxNpc then return true, 50, 40, false end return false, 0, 0, false end,
    }

    local assistCalls = 0
    local gunKillCalls = 0
    local fightStub = {
        assistWindow = function() assistCalls = assistCalls + 1 end,
        gunShove = function() return true end,
        state = "idle",
    }
    local killsStub = { credit = function() return true end }
    local calloutStub = { gunKill = function() gunKillCalls = gunKillCalls + 1 return true end }

    rawset(_G, "LastOnesStanding", los)
    rawset(_G, "BridgeLOSCompat", { active = function() return true end })
    rawset(_G, "BridgeKnoxNpc", knoxStub)
    rawset(_G, "Bridge", { body = companion, mp = false, time = 1000 })
    rawset(_G, "BridgeFight", fightStub)
    rawset(_G, "BridgeKills", killsStub)
    rawset(_G, "BridgeCallout", calloutStub)
    M.hooks = {}
    listCache, listAt = nil, 0

    local melee = { isRanged = function() return false end }
    local gun = { isRanged = function() return true end }

    check("active with LOS loaded", M.active() == true)
    check("hostile LOS npc recognized", M.hostile(hostileNpc, player) == true)
    check("neutral LOS npc rejected", M.hostile(neutralNpc, player) == false)
    check("surrendered LOS npc rejected", M.hostile(surrenderNpc, player) == false)
    check("dead LOS npc rejected", M.hostile(deadNpc, player) == false)
    check("plain object rejected", M.isNpc(plain) == false)
    check("player rejected", M.isNpc(player) == false)

    local near = M.near(0, 0, 50, player)
    check("near returns one hostile", #near == 1 and near[1] == hostileNpc)

    rawset(_G, "Bridge", { body = companion, mp = true, time = 1000 })
    check("inactive in mp", M.active() == false)
    rawset(_G, "Bridge", { body = companion, mp = false, time = 1000 })

    local ok = M.hit(hostileNpc, companion, melee, 10, false)
    check("melee hit calls Hit", ok == true and hostileNpc.hitCalled == true)
    ok = M.hit(hostileNpc, companion, gun, 10, false)
    check("ranged hit calls PlayerBulletHit", ok == true and hostileNpc.bulletHit == true)

    check("installInto accepts stub", M.installInto(knoxStub) == true)
    check("wrapped isNpc sees LOS", knoxStub.isNpc(hostileNpc) == true)
    check("wrapped idOf uses LOS id", knoxStub.idOf(hostileNpc) == 1)
    check("wrapped byId uses LOS body", knoxStub.byId(1) == hostileNpc)
    check("wrapped hostile LOS", knoxStub.hostile(hostileNpc, player) == true)
    check("original isNpc still wins", knoxStub.isNpc(knoxNpc) == true)
    check("original idOf still wins", knoxStub.idOf(knoxNpc) == 99)
    check("original hostile still wins", knoxStub.hostile(knoxNpc, player) == true)
    local baseOk, b1, b2, b3 = knoxStub.hit(knoxNpc, companion, melee, 10, false)
    check("original hit still wins", baseOk == true and b1 == 50 and b2 == 40 and b3 == false)
    local wrappedNear = knoxStub.near(0, 0, 50, player)
    local seenKnox, seenLos = false, false
    for i = 1, #wrappedNear do
        if wrappedNear[i] == knoxNpc then seenKnox = true end
        if wrappedNear[i] == hostileNpc then seenLos = true end
    end
    check("near merges knox and LOS", seenKnox and seenLos)

    local firstIsNpc = knoxStub.isNpc
    M.installInto(knoxStub)
    check("re-install idempotent", knoxStub.isNpc == firstIsNpc)

    M.installClient()
    player.getLastHitCharacter = function() return hostileNpc end
    fightStub.assistWindow(companion, player)
    check("assist wrapper calls original", assistCalls == 1)
    check("assist wrapper sets fight window", fightStub.playerFightUntil == 1000 + 240)
    check("assist wrapper sets target", fightStub.playerTarget == hostileNpc)
    check("gunShove yields false", fightStub.gunShove(companion, hostileNpc) == false)
    check("kill credit suppressed", killsStub.credit(hostileNpc) == false)
    check("gun kill callout suppressed", calloutStub.gunKill(hostileNpc) == false)
    check("gun kill original not called", gunKillCalls == 0)

    rawset(_G, "LastOnesStanding", saved.los)
    rawset(_G, "BridgeKnoxNpc", saved.knox)
    rawset(_G, "BridgeLOSCompat", saved.compat)
    rawset(_G, "Bridge", saved.bridge)
    rawset(_G, "BridgeFight", saved.fight)
    rawset(_G, "BridgeKills", saved.kills)
    rawset(_G, "BridgeCallout", saved.callout)
    M.hooks = saved.hooks
    installed, logged = saved.installed, saved.logged
    listCache, listAt = saved.cache, saved.cacheAt

    if #fails == 0 then return string.format("loscombatselftest PASS (%d checks)", checks) end
    return string.format("loscombatselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(M.install) end)
end

if type(Events) == "table" and Events.OnTick ~= nil then
    Events.OnTick.Add(function()
        local now = 0
        if getTimestampMs ~= nil then pcall(function() now = getTimestampMs() end) end
        if now > 0 and now < nextInstall then return end
        if now > 0 then nextInstall = now + RETRY_MS end
        pcall(M.install)
    end)
end
