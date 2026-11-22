BridgeQuestSurvivors = BridgeQuestSurvivors or {}
local Q = BridgeQuestSurvivors

local MOD_IDS = { "QuestSurvivorsPrototype", "QuestSurvivors" }
local activeCache = false
local marked = setmetatable({}, { __mode = "k" })
local loggedActive = false

local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeQuestSurvivors] " .. tostring(text))
    end
end

function Q.active()
    if activeCache then return true end
    if getActivatedMods == nil then return false end
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        if mods == nil then return end
        for i = 1, #MOD_IDS do
            local id = MOD_IDS[i]
            if mods:contains(id) or mods:contains("\\" .. id) then on = true return end
        end
    end)
    if on then
        activeCache = true
        if not loggedActive then
            loggedActive = true
            log("Quest Survivors detected: actors treated as friendly")
        end
    end
    return on
end

function Q.isQuestNpc(z)
    if z == nil then return false end
    local yes = false
    pcall(function()
        if type(z.getVariableBoolean) == "function" and z:getVariableBoolean("QSQuestHuman") == true then
            yes = true
            return
        end
    end)
    if yes then return true end
    pcall(function()
        if z.hasModData == nil or not z:hasModData() then return end
        local md = z:getModData()
        if type(md) ~= "table" then return end
        if md.QSQuestActor ~= nil or md.QSQuestActor_v1 ~= nil then yes = true end
    end)
    return yes
end

function Q.peaceful(z)
    return Q.active() and Q.isQuestNpc(z)
end

function Q.markCompanion(z)
    if z == nil or not Q.active() then return false end
    local zombie = false
    pcall(function() zombie = instanceof(z, "IsoZombie") == true end)
    if not zombie then return false end
    if marked[z] then return true end
    local ok = pcall(function() z:setVariable("QSQuestHuman", true) end)
    if not ok then return false end
    marked[z] = true
    return true
end

function Q.clearCompanion(z)
    if z == nil or not marked[z] then return false end
    pcall(function() z:clearVariable("QSQuestHuman") end)
    marked[z] = nil
    return true
end

function Q.status()
    local n = 0
    for _ in pairs(marked) do n = n + 1 end
    return string.format("active=%s marked=%d", tostring(Q.active()), n)
end

function Q.selftest()
    local fails, checks = {}, 0
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local savedMods = rawget(_G, "getActivatedMods")
    local savedInstanceof = rawget(_G, "instanceof")
    local savedBridge = rawget(_G, "Bridge")
    local savedSeat = rawget(_G, "BridgeSeatPuppet")
    local savedActive = Q.active
    local savedCache = activeCache

    local function fakeBody(class, vars, md)
        return {
            class = class or "IsoZombie",
            vars = vars or {},
            md = md or {},
            getVariableBoolean = function(self, name) return self.vars[name] == true end,
            setVariable = function(self, name, v) self.vars[name] = v end,
            clearVariable = function(self, name) self.vars[name] = nil end,
            hasModData = function() return true end,
            getModData = function(self) return self.md end,
        }
    end

    local function mods(list)
        return {
            contains = function(_, id)
                for i = 1, #list do if list[i] == id then return true end end
                return false
            end,
        }
    end

    rawset(_G, "instanceof", function(obj, name)
        return type(obj) == "table" and obj.class == name
    end)
    rawset(_G, "BridgeSeatPuppet", nil)

    activeCache = false
    rawset(_G, "getActivatedMods", function() return mods({ "SomeOtherMod" }) end)
    local plain = fakeBody("IsoZombie", {}, {})
    Q.markCompanion(plain)
    check("inactive mark is inert", plain.vars.QSQuestHuman ~= true)
    check("inactive peaceful false", Q.peaceful(plain) == false)

    activeCache = false
    rawset(_G, "getActivatedMods", function() return mods({ "QuestSurvivorsPrototype" }) end)
    check("active detected", Q.active() == true)

    local human = fakeBody("IsoZombie", { QSQuestHuman = true }, {})
    local actor = fakeBody("IsoZombie", {}, { QSQuestActor = {} })
    local actor1 = fakeBody("IsoZombie", {}, { QSQuestActor_v1 = {} })
    local plain2 = fakeBody("IsoZombie", {}, {})
    check("QSQuestHuman recognized", Q.isQuestNpc(human) == true)
    check("QSQuestActor recognized", Q.isQuestNpc(actor) == true)
    check("QSQuestActor_v1 recognized", Q.isQuestNpc(actor1) == true)
    check("plain not recognized", Q.isQuestNpc(plain2) == false)

    local target = fakeBody("IsoZombie", {}, {})
    check("mark writes when active", Q.markCompanion(target) == true and target.vars.QSQuestHuman == true)
    check("mark leaves actor keys alone", target.md.QSQuestActor == nil and target.md.QSQuestActor_v1 == nil)
    local foreign = fakeBody("IsoZombie", { QSQuestHuman = true }, {})
    check("clear ignores unmarked", Q.clearCompanion(foreign) == false and foreign.vars.QSQuestHuman == true)
    check("clear removes own marker", Q.clearCompanion(target) == true and target.vars.QSQuestHuman == nil)

    rawset(_G, "Bridge", {})
    check("harmless quest body", BridgeData ~= nil and BridgeData.harmless(human) == true)
    check("harmless plain body", BridgeData ~= nil and BridgeData.harmless(plain2) == false)

    activeCache = savedCache
    Q.active = savedActive
    rawset(_G, "getActivatedMods", savedMods)
    rawset(_G, "instanceof", savedInstanceof)
    rawset(_G, "Bridge", savedBridge)
    rawset(_G, "BridgeSeatPuppet", savedSeat)

    if #fails == 0 then return string.format("questsurvivorsselftest PASS (%d checks)", checks) end
    return string.format("questsurvivorsselftest FAIL (%d of %d): %s", checks, #fails, table.concat(fails, "; "))
end

return Q
