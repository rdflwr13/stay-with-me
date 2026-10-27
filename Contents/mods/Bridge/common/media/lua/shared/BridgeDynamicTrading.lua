
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
