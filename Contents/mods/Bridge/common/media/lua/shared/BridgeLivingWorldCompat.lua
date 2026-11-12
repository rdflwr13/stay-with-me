BridgeLivingWorld = BridgeLivingWorld or {}

local MOD_ID = "LivingWorld"
local NPC_VAR = "LivingWorldNPC"
local TYPE_VAR = "LivingWorldNPCType"
local SPARE_VAR = "NoZombieHandling"
local HOSTILE_TYPES = { bandit = true }
local MODULE_RETRY_MS = 5000

BridgeLivingWorld.MOD_ID = MOD_ID
BridgeLivingWorld.NPC_VAR = NPC_VAR
BridgeLivingWorld.TYPE_VAR = TYPE_VAR
BridgeLivingWorld.SPARE_VAR = SPARE_VAR
BridgeLivingWorld.HOSTILE_TYPES = HOSTILE_TYPES
BridgeLivingWorld.MODULE_RETRY_MS = MODULE_RETRY_MS

local activeCache = false
local bodyAt = setmetatable({}, { __mode = "k" })
local bodyVal = setmetatable({}, { __mode = "k" })
local moduleSet = nil
local moduleTriedAt = nil

local function hasMod(mods)
    if mods == nil then return false end
    if type(mods) == "table" then
        for _, id in ipairs(mods) do
            id = tostring(id)
            if id == MOD_ID or id == "\\" .. MOD_ID then return true end
        end
        return false
    end
    local ok, has = pcall(function() return mods:contains(MOD_ID) end)
    if ok and has then return true end
    ok, has = pcall(function() return mods:contains("\\" .. MOD_ID) end)
    if ok and has then return true end
    local n = 0
    pcall(function() n = mods:size() end)
    for i = 0, n - 1 do
        local id = nil
        pcall(function() id = mods:get(i) end)
        if id ~= nil then
            id = tostring(id)
            if id == MOD_ID or id == "\\" .. MOD_ID then return true end
        end
    end
    return false
end

function BridgeLivingWorld.active()
    if activeCache then return true end
    local on = false
    pcall(function() on = hasMod(getActivatedMods()) end)
    if on then activeCache = true end
    return on
end

local function tickNow()
    if Bridge ~= nil and tonumber(Bridge.tick) ~= nil then return tonumber(Bridge.tick) end
    if BridgeServer ~= nil and tonumber(BridgeServer.tick) ~= nil then return tonumber(BridgeServer.tick) end
    return nil
end

function BridgeLivingWorld.isBody(z)
    if z == nil then return false end
    if not BridgeLivingWorld.active() then return false end
    local tick = tickNow()
    if tick ~= nil and tick > 0 and bodyAt[z] == tick then return bodyVal[z] == true end
    local yes = false
    local ok = pcall(function()
        if instanceof(z, "IsoZombie") ~= true then return end
        if z:getVariableBoolean(NPC_VAR) then yes = true return end
        if z:getVariableBoolean(SPARE_VAR) then
            local kind = z:getVariableString(TYPE_VAR)
            if type(kind) == "string" and kind ~= "" then yes = true end
        end
    end)
    if not ok then return false end
    if tick ~= nil and tick > 0 then
        bodyAt[z] = tick
        bodyVal[z] = yes
    end
    return yes
end

local function requireAll()
    local set = {}
    set.Body = require("LivingWorld/Body")
    set.Persons = require("LivingWorld/Persons")
    set.Relations = require("LivingWorld/Relations")
    set.Hostiles = require("LivingWorld/Hostiles")
    set.Combat = require("LivingWorld/Combat")
    return set
end

local function clockMs()
    local now = nil
    pcall(function() now = getTimestampMs() end)
    if now == nil then now = 0 end
    return now
end

local function modulesNow()
    local test = BridgeLivingWorld.testModules
    if test ~= nil then return test end
    if moduleSet ~= nil then return moduleSet end
    if Bridge ~= nil and Bridge.mp == true then return nil end
    local now = clockMs()
    if moduleTriedAt ~= nil and moduleTriedAt > 0 and now > 0 and now - moduleTriedAt < MODULE_RETRY_MS then
        return nil
    end
    moduleTriedAt = now
    local ok, set = pcall(requireAll)
    if not ok or type(set) ~= "table" then return nil end
    if type(set.Body) ~= "table" or type(set.Body.personIdOf) ~= "function" then return nil end
    if type(set.Persons) ~= "table" or type(set.Persons.get) ~= "function" then return nil end
    if type(set.Relations) ~= "table" or type(set.Relations.hostile) ~= "function"
        or type(set.Relations.inTruce) ~= "function" then return nil end
    if type(set.Hostiles) ~= "table" or type(set.Hostiles.atMercy) ~= "function" then return nil end
    if type(set.Combat) ~= "table" or type(set.Combat.attackBy) ~= "function" then return nil end
    moduleSet = set
    return moduleSet
end

local function ownerPlayer()
    if BridgeData ~= nil and type(BridgeData.owner) == "function" then return BridgeData.owner() end
    return nil
end

local function accuratePeaceful(z, player)
    local m = modulesNow()
    if m == nil then return nil end
    local id = m.Body.personIdOf(z)
    if id == nil then return nil end
    local person = m.Persons.get(id)
    if type(person) ~= "table" then return nil end
    local owner = ownerPlayer()
    local username = nil
    if owner ~= nil then pcall(function() username = owner:getUsername() end) end
    if type(username) ~= "string" or username == "" then return nil end
    local hostile = m.Relations.hostile(person, username) == true
    if hostile and m.Relations.inTruce(person, username) == true then hostile = false end
    if hostile and m.Hostiles.atMercy(person) == true then hostile = false end
    local now = nil
    pcall(function() now = getTimestampMs() end)
    if now ~= nil then
        local attack = m.Combat.attackBy(z, now)
        if attack ~= nil and attack.victim ~= nil then
            local victim = attack.victim
            if victim == owner then hostile = true end
            if victim == player then hostile = true end
            if Bridge ~= nil and Bridge.body ~= nil and victim == Bridge.body then hostile = true end
        end
    end
    return not hostile
end

local function factionPeaceful(z)
    local kind = nil
    pcall(function() kind = z:getVariableString(TYPE_VAR) end)
    if type(kind) == "string" and HOSTILE_TYPES[kind] == true then return false end
    return true
end

function BridgeLivingWorld.peaceful(z, player)
    local okBody, isIt = pcall(BridgeLivingWorld.isBody, z)
    if not okBody or not isIt then return nil end
    local ok, answer = pcall(function()
        local accurate = accuratePeaceful(z, player)
        if accurate ~= nil then return accurate end
        return factionPeaceful(z)
    end)
    if not ok then return true end
    return answer
end

function BridgeLivingWorld.reset()
    activeCache = false
    moduleSet = nil
    moduleTriedAt = nil
    bodyAt = setmetatable({}, { __mode = "k" })
    bodyVal = setmetatable({}, { __mode = "k" })
end

function BridgeLivingWorld.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local savedInstanceof = rawget(_G, "instanceof")
    local savedMods = rawget(_G, "getActivatedMods")
    local savedNow = rawget(_G, "getTimestampMs")
    local savedBridge = rawget(_G, "Bridge")
    local savedBridgeServer = rawget(_G, "BridgeServer")
    local savedOwner = nil
    local savedNpcfw = nil
    if type(BridgeData) == "table" then
        savedOwner = BridgeData.owner
        savedNpcfw = BridgeData.NPCFW_ACTIVE
    end
    local savedTestModules = BridgeLivingWorld.testModules

    local function body(vars, class)
        local v = vars or {}
        return {
            class = class or "IsoZombie",
            getVariableBoolean = function(_, name) return v[name] == true end,
            getVariableString = function(_, name)
                local value = v[name]
                if type(value) == "string" then return value end
                return ""
            end,
            hasModData = function() return false end,
            getModData = function() return nil end,
            isReanimatedForGrappleOnly = function() return false end,
        }
    end

    local function faction(types)
        local out = {}
        for i = 1, #types do
            out[i] = body({ LivingWorldNPC = true, LivingWorldNPCType = types[i] })
        end
        return out
    end

    local okAll, errAll = pcall(function()
        rawset(_G, "instanceof", function(obj, name)
            return type(obj) == "table" and obj.class == name
        end)
        rawset(_G, "getTimestampMs", function() return 1000000 end)
        rawset(_G, "BridgeServer", nil)
        rawset(_G, "Bridge", { mp = false })
        BridgeLivingWorld.testModules = nil

        getActivatedMods = function() return {} end
        BridgeLivingWorld.reset()
        local ghost = body({ LivingWorldNPC = true })
        check("lw absent active", BridgeLivingWorld.active() == false)
        check("lw absent isBody", BridgeLivingWorld.isBody(ghost) == false)
        check("lw absent peaceful", BridgeLivingWorld.peaceful(ghost) == nil)

        getActivatedMods = function() return { MOD_ID } end
        BridgeLivingWorld.reset()
        check("npc marker", BridgeLivingWorld.isBody(body({ LivingWorldNPC = true })) == true)
        check("spare marker", BridgeLivingWorld.isBody(body({ NoZombieHandling = true, LivingWorldNPCType = "bandit" })) == true)
        check("spare empty type", BridgeLivingWorld.isBody(body({ NoZombieHandling = true })) == false)
        check("plain zombie", BridgeLivingWorld.isBody(body({})) == false)
        check("non zombie", BridgeLivingWorld.isBody(body({ LivingWorldNPC = true }, "IsoPlayer")) == false)
        check("dead lw cleared", BridgeLivingWorld.isBody(body({ LivingWorldNPC = false, NoZombieHandling = false, LivingWorldNPCType = "" })) == false)

        Bridge = { mp = true }
        BridgeLivingWorld.testModules = nil
        local bandit = body({ LivingWorldNPC = true, LivingWorldNPCType = "bandit" })
        check("bandit not peaceful", BridgeLivingWorld.peaceful(bandit) == false)
        local peaceful = faction({ "survivor", "loner", "team", "police", "military", "cult" })
        for i = 1, #peaceful do
            check("faction peaceful " .. i, BridgeLivingWorld.peaceful(peaceful[i]) == true)
        end
        check("unknown faction peaceful", BridgeLivingWorld.peaceful(body({ LivingWorldNPC = true, LivingWorldNPCType = "wat" })) == true)
        check("empty faction peaceful", BridgeLivingWorld.peaceful(body({ LivingWorldNPC = true })) == true)

        local playerChar = { class = "IsoPlayer" }
        local companion = body({ NotAloneBody = true })
        local person = {}
        local mods = {
            Body = { personIdOf = function(z) return z.personId end },
            Persons = { get = function(id) if id == "p1" then return person end return nil end },
            Relations = {
                hostile = function(p, username) return p.hostile == true end,
                inTruce = function(p, username) return p.truce == true end,
            },
            Hostiles = { atMercy = function(p) return p.mercy == true end },
            Combat = { attackBy = function(z, now) return z.attack end },
        }
        Bridge = { mp = false, body = companion }
        BridgeLivingWorld.testModules = mods
        BridgeData.owner = function() return { getUsername = function() return "player" end } end

        local hostileBody = body({ LivingWorldNPC = true, LivingWorldNPCType = "survivor" })
        hostileBody.personId = "p1"
        person.hostile = true
        check("accurate hostile", BridgeLivingWorld.peaceful(hostileBody, playerChar) == false)
        person.truce = true
        check("accurate truce peaceful", BridgeLivingWorld.peaceful(hostileBody, playerChar) == true)
        person.truce = false
        person.mercy = true
        check("accurate mercy peaceful", BridgeLivingWorld.peaceful(hostileBody, playerChar) == true)
        person.mercy = false
        person.hostile = false
        check("accurate neutral peaceful", BridgeLivingWorld.peaceful(hostileBody, playerChar) == true)
        hostileBody.attack = { victim = playerChar }
        check("attack on player", BridgeLivingWorld.peaceful(hostileBody, playerChar) == false)
        hostileBody.attack = { victim = companion }
        check("attack on companion", BridgeLivingWorld.peaceful(hostileBody, playerChar) == false)
        hostileBody.attack = { victim = {} }
        check("attack on third party", BridgeLivingWorld.peaceful(hostileBody, playerChar) == true)
        hostileBody.attack = nil
        local savedHostile = mods.Relations.hostile
        mods.Relations.hostile = function() error("lw error") end
        check("module error fail open", BridgeLivingWorld.peaceful(hostileBody, playerChar) == true)
        mods.Relations.hostile = savedHostile
        hostileBody.personId = nil
        hostileBody.getVariableString = function(_, name)
            if name == TYPE_VAR then return "bandit" end
            return ""
        end
        check("no person record faction bandit", BridgeLivingWorld.peaceful(hostileBody, playerChar) == false)
        hostileBody.personId = "p1"
        BridgeLivingWorld.testModules = nil
        BridgeLivingWorld.reset()
        Bridge = { mp = true }
        getActivatedMods = function() return { MOD_ID } end
        BridgeLivingWorld.reset()

        local lwPeaceful = body({ LivingWorldNPC = true, LivingWorldNPCType = "survivor" })
        local lwHostile = body({ LivingWorldNPC = true, LivingWorldNPCType = "bandit" })
        local lwDead = body({ LivingWorldNPC = false, NoZombieHandling = false, LivingWorldNPCType = "" })
        local plainZ = body({})

        check("foreign lw", BridgeData.foreign(lwPeaceful) == true)
        check("foreign lw hostile", BridgeData.foreign(lwHostile) == true)
        check("foreign dead lw", BridgeData.foreign(lwDead) == false)
        check("foreign plain", BridgeData.foreign(plainZ) == false)
        check("foreignPeaceful lw", BridgeData.foreignPeaceful(lwPeaceful) == true)
        check("foreignPeaceful lw hostile", BridgeData.foreignPeaceful(lwHostile) == false)
        check("harmless lw", BridgeData.harmless(lwPeaceful) == true)
        check("harmless lw hostile", BridgeData.harmless(lwHostile) == false)
        check("harmless dead lw", BridgeData.harmless(lwDead) == false)
        check("harmless plain", BridgeData.harmless(plainZ) == false)
    end)

    rawset(_G, "instanceof", savedInstanceof)
    rawset(_G, "getActivatedMods", savedMods)
    rawset(_G, "getTimestampMs", savedNow)
    rawset(_G, "Bridge", savedBridge)
    rawset(_G, "BridgeServer", savedBridgeServer)
    if type(BridgeData) == "table" then
        BridgeData.owner = savedOwner
        BridgeData.NPCFW_ACTIVE = savedNpcfw
    end
    BridgeLivingWorld.testModules = savedTestModules
    BridgeLivingWorld.reset()

    if not okAll then fails[#fails + 1] = "selftest error: " .. tostring(errAll) end
    if #fails == 0 then return string.format("livingworldselftest PASS (%d checks)", checks) end
    return string.format("livingworldselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end
