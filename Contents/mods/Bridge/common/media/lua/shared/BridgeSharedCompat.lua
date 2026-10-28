do
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
end

do
BridgeExtraction = BridgeExtraction or {}
local M = BridgeExtraction

function M.ours(z)
    if z == nil then return false end

    if Bridge ~= nil and Bridge.body == z then return true end

    local yes = false
    pcall(function()
        yes = z:getVariableBoolean("NotAloneBody") == true
    end)
    if yes then return true end

    pcall(function()
        local md = z.getModData and z:getModData() or nil
        yes = md ~= nil and md.notAloneBody == true
    end)
    return yes
end

function M.install()
    local U = ExtractionMode and ExtractionMode.Util
    if type(U) ~= "table" then return false end

    local dead = U.isDeadOrDraggedZombie
    if type(dead) == "function" and dead ~= M.dead then
        M.dead = function(z)
            if M.ours(z) then return true end
            return dead(z)
        end
        U.isDeadOrDraggedZombie = M.dead
    end

    local npc = U.isNPCZombie
    if type(npc) == "function" and npc ~= M.npc then
        M.npc = function(z)
            if M.ours(z) then return true end
            return npc(z)
        end
        U.isNPCZombie = M.npc
    end

    local ready = U.isDeadOrDraggedZombie == M.dead and U.isNPCZombie == M.npc
    if ready and BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeExtraction] Extraction Mode zombie guards patched")
    end
    return ready
end

local installed = false
local function ensure()
    if installed then return end
    installed = M.install()
end

pcall(ensure)

if Events ~= nil then
    if Events.OnInitGlobalModData ~= nil then
        Events.OnInitGlobalModData.Add(function() pcall(ensure) end)
    end
    if Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function() pcall(ensure) end)
    end
    if Events.OnServerStarted ~= nil then
        Events.OnServerStarted.Add(function() pcall(ensure) end)
    end
    if Events.OnTick ~= nil then
        Events.OnTick.Add(function()
            if not installed then pcall(ensure) end
        end)
    end
end
end

do

BridgeDT = BridgeDT or {}

BridgeDT.wrappers = BridgeDT.wrappers or {}
BridgeDT.ticks = 0
BridgeDT.lastError = nil
BridgeDT._active = nil

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeDT] " .. tostring(text)) end
end

function BridgeDT.active()
    if BridgeDT._active ~= nil then return BridgeDT._active end
    local active = false
    pcall(function()
        if getActivatedMods == nil then return end
        local mods = getActivatedMods()
        if mods == nil then return end
        active = mods:contains("DynamicTradingV2") or mods:contains("\\DynamicTradingV2")
    end)
    BridgeDT._active = active == true
    return BridgeDT._active
end

function BridgeDT.isDTNPC(z)
    if z == nil then return false end
    local yes = false
    pcall(function()
        if type(z.getModData) == "function" then
            local md = nil
            pcall(function() md = z:getModData() end)
            if type(md) == "table" then
                if md.IsDTNPC == true or md.DTNPC_UUID ~= nil or md.DTNPC_Data ~= nil
                        or md.DTNPCBrain ~= nil then
                    yes = true
                    return
                end
            end
        end
        if type(z.getVariableBoolean) == "function" and z:getVariableBoolean("DTNPC") == true then
            yes = true
        end
    end)
    return yes
end

function BridgeDT.data(z)
    if z == nil then return nil end
    local target, uuid = nil, nil
    pcall(function()
        if type(z.getModData) ~= "function" then return end
        local md = z:getModData()
        if type(md) ~= "table" then return end
        target = md.DTNPC_Data or md.DTNPCBrain
        uuid = md.DTNPC_UUID
        if uuid == nil and type(target) == "table" then uuid = target.uuid end
    end)
    if type(target) == "table" then return target end
    if uuid ~= nil then
        pcall(function()
            local manager = rawget(_G, "DTNPCManager")
            if type(manager) == "table" and type(manager.Data) == "table" then
                target = manager.Data[tostring(uuid)]
            end
        end)
        if type(target) == "table" then return target end
        pcall(function()
            local roster = rawget(_G, "DynamicTrading_Roster")
            if type(roster) == "table" and type(roster.GetSoul) == "function" then
                target = roster.GetSoul(tostring(uuid))
            end
        end)
    end
    if type(target) == "table" then return target end
    return nil
end

function BridgeDT.hostilityAPI()
    local protect = rawget(_G, "DTNPCProtect")
    if type(protect) ~= "table" then return nil end
    local internal = protect.Internal
    if type(internal) ~= "table" then return nil end
    if type(internal.IsHostilePlayerForNPC) == "function" then return internal.IsHostilePlayerForNPC end
    return nil
end

function BridgeDT.isHostileData(data)
    if type(data) ~= "table" then return false end
    if data.isHostile == true or data.isBandit == true then return true end
    if data.factionID == "Bandits" then return true end
    if data.raidHostileFaction == true then return true end
    if data.banditGroupID ~= nil or data.hostileNegotiationGroupID ~= nil then return true end
    local mode = data.tradeCycleMode
    if mode == "robbery" or mode == "hostile_bribe" then return true end
    local faction = nil
    pcall(function()
        local mod = rawget(_G, "DynamicTrading_Factions")
        if type(mod) == "table" and type(mod.GetFaction) == "function" and data.factionID ~= nil then
            faction = mod.GetFaction(data.factionID)
        end
    end)
    if type(faction) ~= "table" and data.factionID ~= nil then
        pcall(function()
            if ModData == nil or type(ModData.get) ~= "function" then return end
            local all = ModData.get("DynamicTrading_Factions")
            if type(all) ~= "table" then return end
            faction = all[data.factionID] or all[tostring(data.factionID)]
        end)
    end
    if type(faction) == "table" then
        if faction.hostileToPlayers == true or faction.alwaysHostile == true then return true end
        if faction.factionType == "bandit" then return true end
    end
    return false
end

function BridgeDT.peaceful(z, player)
    if not BridgeDT.isDTNPC(z) then return nil end
    if player == nil then
        local data = rawget(_G, "BridgeData")
        if type(data) == "table" and type(data.owner) == "function" then
            local ok, who = pcall(data.owner)
            if ok then player = who end
        end
    end
    local info = BridgeDT.data(z)
    if info == nil then return true end
    local api = BridgeDT.hostilityAPI()
    if api ~= nil and player ~= nil then
        local ok, hostile = pcall(api, info, player)
        if ok and type(hostile) == "boolean" then return not hostile end
    end
    return not BridgeDT.isHostileData(info)
end

function BridgeDT.gunAllowed(z, peacefulOf)
    if not BridgeDT.isDTNPC(z) then return nil end
    local answer = nil
    if type(peacefulOf) == "function" then
        local ok, value = pcall(peacefulOf, z)
        if ok then answer = value end
    end
    if answer == nil then answer = BridgeDT.peaceful(z) end
    return answer == false
end

function BridgeDT.companionBodies()
    local out, seen = {}, {}
    local function add(body)
        if body == nil or seen[body] then return end
        out[#out + 1] = body
        seen[body] = true
    end
    local bridge = rawget(_G, "Bridge")
    if type(bridge) == "table" then
        add(bridge.body)
        if type(bridge.bodies) == "table" then
            for _, body in pairs(bridge.bodies) do add(body) end
        end
    end
    local server = rawget(_G, "BridgeServer")
    if type(server) == "table" and type(server.bodies) == "table" then
        for _, body in pairs(server.bodies) do add(body) end
    end
    if #out == 0 then
        local companion = rawget(_G, "BridgeCompanion")
        if type(companion) == "table" and type(companion.bodies) == "function" then
            local ok, list = pcall(companion.bodies)
            if ok and type(list) == "table" then
                for _, body in ipairs(list) do add(body) end
            end
        end
    end
    return out
end

function BridgeDT.withHiddenCompanions(fn, ...)
    local bodies = BridgeDT.companionBodies()
    local saved = {}
    for index = 1, #bodies do
        local body = bodies[index]
        local md = nil
        pcall(function()
            if type(body.getModData) == "function" then md = body:getModData() end
        end)
        if type(md) == "table" then
            saved[#saved + 1] = { data = md, before = md.IsDTNPC }
            md.IsDTNPC = true
        end
    end
    local results = { pcall(fn, ...) }
    for index = #saved, 1, -1 do
        saved[index].data.IsDTNPC = saved[index].before
    end
    if not results[1] then error(results[2], 0) end
    return unpack(results, 2, #results)
end

function BridgeDT.install()
    if not BridgeDT.active() then return false end
    local protect = rawget(_G, "DTNPCProtect")
    if type(protect) ~= "table" then return false end
    local installed = 0
    local function wrap(name)
        local original = protect[name]
        if type(original) ~= "function" then return end
        local record = BridgeDT.wrappers[name]
        if record ~= nil and protect[name] == record.wrapper then
            installed = installed + 1
            return
        end
        local wrapper = function(...)
            return BridgeDT.withHiddenCompanions(original, ...)
        end
        protect[name] = wrapper
        BridgeDT.wrappers[name] = { original = original, wrapper = wrapper }
        installed = installed + 1
    end
    wrap("SelectNearestThreat")
    wrap("GetNearbyHostilePressure")
    if installed > 0 then log("installed " .. tostring(installed) .. " hooks") end
    return true
end

function BridgeDT.tick()
    BridgeDT.ticks = (BridgeDT.ticks or 0) + 1
    if BridgeDT.ticks == 1 or BridgeDT.ticks % 60 == 0 then
        local ok, err = pcall(BridgeDT.install)
        if not ok then BridgeDT.lastError = tostring(err) end
    end
end

function BridgeDT.status()
    local count = 0
    for _ in pairs(BridgeDT.wrappers) do count = count + 1 end
    return string.format("dt active=%s wrappers=%d bodies=%d error=%s",
        tostring(BridgeDT.active()), count, #BridgeDT.companionBodies(),
        tostring(BridgeDT.lastError or "none"))
end

function BridgeDT.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end
    local savedApi = BridgeDT.hostilityAPI
    BridgeDT.hostilityAPI = function() return nil end
    check("ordinary trader peaceful", BridgeDT.isHostileData({ name = "Trader" }) == false)
    check("hostile flag", BridgeDT.isHostileData({ isHostile = true }) == true)
    check("bandit flag", BridgeDT.isHostileData({ isBandit = true }) == true)
    check("bandit faction", BridgeDT.isHostileData({ factionID = "Bandits" }) == true)
    check("robbery mode", BridgeDT.isHostileData({ tradeCycleMode = "robbery" }) == true)

    local function stubZombie(md)
        return {
            getModData = function() return md end,
            getVariableBoolean = function() return false end,
        }
    end
    local trader = stubZombie({ IsDTNPC = true, DTNPC_Data = { name = "Trader" } })
    local bandit = stubZombie({ IsDTNPC = true, DTNPC_Data = { isHostile = true } })
    local plain = stubZombie({})
    local nobody = {}
    check("trader peaceful", BridgeDT.peaceful(trader, nobody) == true)
    check("hostile trader not peaceful", BridgeDT.peaceful(bandit, nobody) == false)
    check("non-dt not classified", BridgeDT.peaceful(plain, nobody) == nil)
    check("unknown data peaceful", BridgeDT.peaceful(stubZombie({ IsDTNPC = true }), nobody) == true)
    check("gun allowed only hostile", BridgeDT.gunAllowed(bandit, BridgeDT.peaceful) == true)
    check("friendly gun blocked", BridgeDT.gunAllowed(trader, BridgeDT.peaceful) == false)
    check("non-dt gun unclassified", BridgeDT.gunAllowed(plain, BridgeDT.peaceful) == nil)

    local savedBodies = BridgeDT.companionBodies
    local md = { IsDTNPC = "keep" }
    local stubBody = { getModData = function() return md end }
    BridgeDT.companionBodies = function() return { stubBody } end
    local seenInside = nil
    local ok, result = pcall(function()
        return BridgeDT.withHiddenCompanions(function()
            seenInside = md.IsDTNPC
            return "inner"
        end)
    end)
    check("marker visible during call", ok and result == "inner" and seenInside == true)
    check("marker restored after call", md.IsDTNPC == "keep")
    local okErr = pcall(function()
        BridgeDT.withHiddenCompanions(function() error("boom") end)
    end)
    check("error propagates", okErr == false)
    check("marker restored after error", md.IsDTNPC == "keep")
    BridgeDT.companionBodies = savedBodies
    BridgeDT.hostilityAPI = savedApi

    if #fails == 0 then return string.format("dtselftest PASS (%d checks)", checks) end
    return string.format("dtselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end

if Events ~= nil then
    Events.OnGameStart.Add(function()
        BridgeDT._active = nil
        BridgeDT.ticks = 0
        BridgeDT.lastError = nil
        pcall(BridgeDT.install)
    end)
    Events.OnServerStarted.Add(function()
        BridgeDT._active = nil
        BridgeDT.ticks = 0
        BridgeDT.lastError = nil
        pcall(BridgeDT.install)
    end)
    Events.OnTick.Add(function()
        pcall(BridgeDT.tick)
    end)
end
end

do



























BridgeBandits = BridgeBandits or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeBandits] " .. tostring(text)) end end
local function warn(text) print("[BridgeBandits] " .. tostring(text)) end

local BODY_VAR = "NotAloneBody"


function BridgeBandits.hers(z)
    if z == nil then return false end
    if Bridge ~= nil and Bridge.body == z then return true end
    if z:getVariableBoolean(BODY_VAR) == true then return true end


    if z:hasModData() and z:getModData().notAloneBody == true then return true end




    local B = Bridge
    if B == nil or not B.mp or B.bodyIndex == nil or B.world == nil or B.world.players == nil then return false end
    local yes = false
    pcall(function()
        local pid = z:getPersistentOutfitID()
        local who = B.bodyIndex[pid]
        local rec = who ~= nil and B.world.players[who] or nil
        yes = rec ~= nil and rec.bodyId == pid and (rec.onlineId == nil or rec.onlineId == z:getOnlineID())
    end)
    return yes
end



function BridgeBandits.hostileTarget(z)
    if z == nil then return false end
    if BridgeBandits.wanted ~= true then return false end
    if type(BridgeData) ~= "table" or type(BridgeData.bandit) ~= "function" then return false end
    local npc, hostile = false, nil
    local ok = pcall(function() npc, hostile = BridgeData.bandit(z) end)
    return ok and npc == true and hostile == true
end


function BridgeBandits.windowClose(z)
    local near = false
    pcall(function()
        local bx, by, bz = math.floor(z:getX()), math.floor(z:getY()), z:getZ()
        local cell = getCell()
        for x = -1, 1 do
            for y = -1, 1 do
                local sq = cell:getGridSquare(bx + x, by + y, bz)
                if sq ~= nil and not near then
                    local objects = sq:getObjects()
                    for i = 0, objects:size() - 1 do
                        local o = objects:get(i)
                        if o ~= nil and (instanceof(o, "IsoWindow") or instanceof(o, "IsoWindowFrame") or instanceof(o, "IsoThumpable"))
                            and o:canClimbThrough(z) then
                            near = true
                            break
                        end
                    end
                end
            end
        end
    end)
    return near
end

local function active(id)
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods:contains(id) or mods:contains("\\" .. id)
    end)
    return on
end



function BridgeBandits.install()
    if type(BanditCompatibility) ~= "table" or type(BanditCompatibility.IsReanimatedForGrappleOnly) ~= "function" then
        return false
    end
    if BanditCompatibility.IsReanimatedForGrappleOnly == BridgeBandits.skip then return true end
    local original = BanditCompatibility.IsReanimatedForGrappleOnly
    BridgeBandits.skip = function(zombie)
        if BridgeBandits.hers(zombie) then return true end
        return original(zombie)
    end
    BanditCompatibility.IsReanimatedForGrappleOnly = BridgeBandits.skip
    BanditCompatibility.bridgeSkip = true
    log("Bandits: her body is skipped (IsReanimatedForGrappleOnly)")
    return true
end

if BridgeBandits.wanted == nil then BridgeBandits.wanted = active("Bandits2") end
if BridgeBandits.wanted then
    pcall(function() require "BanditCompatibility" end)
    if not BridgeBandits.install() then log("Bandits active, but BanditCompatibility.IsReanimatedForGrappleOnly not found") end
end








function BridgeBandits.wrapHit()
    if type(BanditUtils) ~= "table" or type(BanditUtils.Hit) ~= "function" or BanditUtils.Hit == BridgeBandits.hit then return end
    local hit = BanditUtils.Hit
    local last = nil
    BridgeBandits.hit = function(shooter, item, victim, ...)
        if BridgeBandits.hers(victim) then
            local now = getTimestampMs()
            if last ~= nil and last.shooter == shooter and now - last.t <= 1 then return last.landed end
            return false
        end
        local landed = hit(shooter, item, victim, ...)
        last = { shooter = shooter, landed = landed, t = getTimestampMs() }
        return landed
    end
    BanditUtils.Hit = BridgeBandits.hit
    log("Bandits: stray bullets pass through her")
end



function BridgeBandits.check()
    if Bridge == nil or Bridge.body == nil or type(BanditZombie) ~= "table" or type(BanditZombie.Cache) ~= "table"
        or type(BanditUtils) ~= "table" or type(BanditUtils.GetZombieID) ~= "function" then return nil end
    local seen = false
    pcall(function() seen = BanditZombie.Cache[BanditUtils.GetZombieID(Bridge.body)] == Bridge.body end)
    if seen and not BridgeBandits.warned then
        BridgeBandits.warned = true
        log("Bandits still sees her body: skip does not work (Bandits updated?)")
    elseif not seen then
        BridgeBandits.warned = nil
    end

    if BanditCompatibility ~= nil and BanditCompatibility.IsReanimatedForGrappleOnly ~= BridgeBandits.skip then
        BridgeBandits.install()
    end
    return seen
end









BridgeBandits.corpses = BridgeBandits.corpses or {}

function BridgeBandits.forgetCorpse(x, y, z)
    if type(BWOScheduler) ~= "table" then return false end
    BridgeBandits.corpses[#BridgeBandits.corpses + 1] = { x = x, y = y, z = z }
    return true
end


function BridgeBandits.corpseTick()
    if #BridgeBandits.corpses == 0 then return end
    local list = BridgeBandits.corpses
    BridgeBandits.corpses = {}
    for _, c in ipairs(list) do


        local real = false
        pcall(function()
            local sq = getCell():getGridSquare(math.floor(c.x), math.floor(c.y), math.floor(c.z))
            real = sq ~= nil and sq:getDeadBody() ~= nil
        end)
        if real then
            log("Week One: a real corpse lies where she died, its record kept")
        else
            local ok, err = pcall(function() sendClientCommand(getSpecificPlayer(0), "Commands", "DeadBodyRemove", c) end)
            if ok then
                log(string.format("Week One: her corpse record removed at %.1f,%.1f,%.1f", c.x, c.y, c.z))
            else
                warn("Week One: her corpse record not removed: " .. tostring(err))
            end
        end
    end
end

if BridgeBandits.wanted and not BridgeBandits.eventsAdded and Events ~= nil then
    BridgeBandits.eventsAdded = true
    Events.OnGameStart.Add(function() pcall(BridgeBandits.wrapHit) end)
    if Events.EveryOneMinute ~= nil then
        Events.EveryOneMinute.Add(function()
            if not isServer() then pcall(BridgeBandits.check) end
        end)
    end
end


function BridgeBandits.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local savedWanted = BridgeBandits.wanted
    local savedBandit = BridgeData ~= nil and BridgeData.bandit or nil
    local savedForeign = BridgeGunRules ~= nil and BridgeGunRules.isForeignNpc or nil

    check("nil is not a target", BridgeBandits.hostileTarget(nil) == false)

    BridgeBandits.wanted = false
    BridgeData.bandit = function() return true, true end
    check("inactive mod never allows", BridgeBandits.hostileTarget({}) == false)

    BridgeBandits.wanted = true
    BridgeData.bandit = function() return true, true end
    check("hostile bandit allowed", BridgeBandits.hostileTarget({}) == true)

    BridgeData.bandit = function() return true, false end
    check("peaceful bandit blocked", BridgeBandits.hostileTarget({}) == false)

    BridgeData.bandit = function() return true, nil end
    check("unknown hostility blocked", BridgeBandits.hostileTarget({}) == false)

    BridgeData.bandit = function() return false, true end
    check("non-bandit blocked", BridgeBandits.hostileTarget({}) == false)

    BridgeData.bandit = function() error("boom") end
    check("error is safe", BridgeBandits.hostileTarget({}) == false)

    if savedForeign ~= nil then
        BridgeGunRules.isForeignNpc = function() return "Bandits" end
        local allowed = BridgeGunRules.foreignGunAllowed({}, function() return false end)
        BridgeGunRules.isForeignNpc = savedForeign
        check("shared foreign gate unchanged", allowed == false)
    end

    BridgeBandits.wanted = savedWanted
    if savedBandit ~= nil then BridgeData.bandit = savedBandit end

    if #fails == 0 then return string.format("banditselftest PASS (%d checks)", checks) end
    return string.format("banditselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end
end

