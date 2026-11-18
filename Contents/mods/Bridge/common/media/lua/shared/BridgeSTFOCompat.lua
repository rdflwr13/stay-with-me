BridgeSTFOCompat = BridgeSTFOCompat or {}

local M = BridgeSTFOCompat

local MOD_ID = "STFO"

local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeSTFOCompat] " .. tostring(text))
    end
end

local function active()
    local alife = rawget(_G, "BridgeALifeCompat")
    if type(alife) == "table" and type(alife.active) == "function" then
        return alife.active(MOD_ID) == true
    end
    return false
end

function M.friendly(z)
    if z == nil then return false end
    local companion = rawget(_G, "BridgeCompanion")
    if type(companion) == "table" and type(companion.isBody) == "function" then
        local ok, yes = pcall(companion.isBody, z)
        if ok and yes == true then return true end
    end
    local puppet = rawget(_G, "BridgeSeatPuppet")
    if type(puppet) == "table" and type(puppet.is) == "function" then
        local ok, yes = pcall(puppet.is, z)
        if ok and yes == true then return true end
    end
    return false
end

local function registered(traps)
    local list = traps.friendlyChecks
    if type(list) ~= "table" then return false end
    for i = 1, #list do
        if list[i] == M.friendly then return true end
    end
    return false
end

function M.install()
    local traps = rawget(_G, "SimpleTraps")
    if type(traps) ~= "table" or type(traps.addFriendlyCheck) ~= "function" then
        return "absent"
    end
    if registered(traps) then
        M.installed = true
        return "ok"
    end
    traps.addFriendlyCheck(M.friendly)
    M.installed = true
    log("registered: STFO traps and turret ignore her")
    return "ok"
end

local function installAndReport()
    if M.install() == "ok" then return end
    if M.warned or not active() then return end
    M.warned = true
    print("[BridgeSTFOCompat] STFO is active but exposes no friendly check; its traps and turret still hit her")
end

pcall(M.install)

if type(Events) == "table" then
    if Events.OnGameStart ~= nil then Events.OnGameStart.Add(function() pcall(installAndReport) end) end
    if Events.OnServerStarted ~= nil then Events.OnServerStarted.Add(function() pcall(installAndReport) end) end
end
