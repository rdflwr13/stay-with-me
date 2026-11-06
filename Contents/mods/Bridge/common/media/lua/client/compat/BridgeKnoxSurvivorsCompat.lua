BridgeKnoxSurvivors = BridgeKnoxSurvivors or {}

local MOD_ID = "KnoxSurvivors"
local RETRY_EVERY = 60

BridgeKnoxSurvivors.MOD_ID = MOD_ID
BridgeKnoxSurvivors.RETRY_EVERY = RETRY_EVERY

local activeCache = false
local ticks = 0

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

function BridgeKnoxSurvivors.active()
    if activeCache then return true end
    local on = false
    pcall(function() on = hasMod(getActivatedMods()) end)
    if on then activeCache = true end
    return on
end

function BridgeKnoxSurvivors.isOurs(z)
    if z == nil then return false end
    local ours = false
    pcall(function()
        if Bridge ~= nil and type(Bridge.isCompanion) == "function" then
            ours = Bridge.isCompanion(z) == true
        end
    end)
    if ours then return true end
    pcall(function()
        if Bridge ~= nil and Bridge.body == z then ours = true end
    end)
    if ours then return true end
    pcall(function() ours = z:getVariableBoolean("NotAloneBody") == true end)
    return ours
end

local function wrapper(z)
    if BridgeKnoxSurvivors.isOurs(z) then return true end
    local original = BridgeKnoxSurvivors.original
    if type(original) ~= "function" then return false end
    local ok, result = pcall(original, z)
    if not ok then return false end
    return result
end

function BridgeKnoxSurvivors.install()
    if not BridgeKnoxSurvivors.active() then return false end
    local T = rawget(_G, "KnoxThreatClassifier")
    if type(T) ~= "table" or type(T.isCorpseProxy) ~= "function" then return false end
    if T.isCorpseProxy == wrapper then
        BridgeKnoxSurvivors.wrapper = wrapper
        return true
    end
    BridgeKnoxSurvivors.original = T.isCorpseProxy
    BridgeKnoxSurvivors.wrapper = wrapper
    T.isCorpseProxy = wrapper
    if BridgeKnoxSurvivors.logged ~= true then
        BridgeKnoxSurvivors.logged = true
        print("[BridgeKnoxSurvivors] Knox Survivors threat guard installed")
    end
    return true
end

function BridgeKnoxSurvivors.uninstall()
    local T = rawget(_G, "KnoxThreatClassifier")
    if type(T) == "table" and BridgeKnoxSurvivors.wrapper ~= nil
        and T.isCorpseProxy == BridgeKnoxSurvivors.wrapper
        and BridgeKnoxSurvivors.original ~= nil then
        T.isCorpseProxy = BridgeKnoxSurvivors.original
    end
    BridgeKnoxSurvivors.original = nil
    BridgeKnoxSurvivors.wrapper = nil
    BridgeKnoxSurvivors.logged = false
end

function BridgeKnoxSurvivors.selftest()
    local checks, fails = 0, {}
    local function check(name, ok)
        checks = checks + 1
        if not ok then fails[#fails + 1] = name end
    end
    local function reset()
        activeCache = false
        BridgeKnoxSurvivors.activeCache = false
        BridgeKnoxSurvivors.original = nil
        BridgeKnoxSurvivors.wrapper = nil
        BridgeKnoxSurvivors.logged = true
    end

    local oldMods = getActivatedMods
    local oldT = rawget(_G, "KnoxThreatClassifier")
    local oldPredicate = oldT ~= nil and oldT.isCorpseProxy or nil
    local oldBridge = Bridge
    local oldOriginal = BridgeKnoxSurvivors.original
    local oldWrapper = BridgeKnoxSurvivors.wrapper
    local oldLogged = BridgeKnoxSurvivors.logged
    local oldActive = BridgeKnoxSurvivors.activeCache

    local okAll, errAll = pcall(function()
        getActivatedMods = function() return {} end
        KnoxThreatClassifier = { isCorpseProxy = function() return false end }
        BridgeKnoxSurvivors.original = nil
        BridgeKnoxSurvivors.wrapper = nil
        BridgeKnoxSurvivors.logged = true
        BridgeKnoxSurvivors.activeCache = false
        check("inactive does not install", BridgeKnoxSurvivors.install() == false)

        getActivatedMods = function() return { MOD_ID } end
        BridgeKnoxSurvivors.activeCache = false
        KnoxThreatClassifier = nil
        local okNoTable, installedNoTable = pcall(BridgeKnoxSurvivors.install)
        check("missing classifier does not throw", okNoTable == true and installedNoTable == false)

        local originalCalls = 0
        local original = function(z)
            originalCalls = originalCalls + 1
            return true
        end
        KnoxThreatClassifier = { isCorpseProxy = original }
        reset()
        check("install wraps", BridgeKnoxSurvivors.install() == true)
        local wrapped = KnoxThreatClassifier.isCorpseProxy
        check("wrapper installed", type(wrapped) == "function" and wrapped ~= original)
        check("reinstall idempotent", BridgeKnoxSurvivors.install() == true
            and KnoxThreatClassifier.isCorpseProxy == wrapped
            and BridgeKnoxSurvivors.original == original)

        Bridge = { isCompanion = function(z) return z ~= nil and z.ours == true end, body = {} }
        check("own body", wrapped({ ours = true }) == true)
        originalCalls = 0
        check("delegate preserves true", wrapped({ ours = false }) == true and originalCalls == 1)

        BridgeKnoxSurvivors.uninstall()
        check("uninstall restores original", KnoxThreatClassifier.isCorpseProxy == original)

        local replacement = function() return false end
        KnoxThreatClassifier.isCorpseProxy = replacement
        BridgeKnoxSurvivors.logged = true
        check("reinstall after replace", BridgeKnoxSurvivors.install() == true
            and KnoxThreatClassifier.isCorpseProxy ~= replacement
            and BridgeKnoxSurvivors.original == replacement)

        Bridge = nil
        local okMissing, value = pcall(wrapped, {})
        check("missing Bridge does not throw", okMissing == true and value == false)
    end)

    getActivatedMods = oldMods
    KnoxThreatClassifier = oldT
    if oldT ~= nil and oldPredicate ~= nil then oldT.isCorpseProxy = oldPredicate end
    Bridge = oldBridge
    BridgeKnoxSurvivors.original = oldOriginal
    BridgeKnoxSurvivors.wrapper = oldWrapper
    BridgeKnoxSurvivors.logged = oldLogged
    BridgeKnoxSurvivors.activeCache = oldActive
    activeCache = oldActive

    if not okAll then fails[#fails + 1] = "selftest error: " .. tostring(errAll) end
    if #fails == 0 then return string.format("knoxsurvivorsselftest PASS (%d checks)", checks) end
    return string.format("knoxsurvivorsselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end

Events.OnGameStart.Add(function()
    pcall(BridgeKnoxSurvivors.uninstall)
    activeCache = false
    BridgeKnoxSurvivors.activeCache = false
    ticks = 0
    pcall(BridgeKnoxSurvivors.install)
end)

Events.OnTick.Add(function()
    ticks = ticks + 1
    if ticks % RETRY_EVERY ~= 0 then return end
    pcall(BridgeKnoxSurvivors.install)
end)
