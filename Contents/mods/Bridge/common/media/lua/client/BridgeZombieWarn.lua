require "ISUI/ISModalDialog"

BridgeZombieWarn = BridgeZombieWarn or {}
BridgeZombieWarn.shown = false
BridgeZombieWarn.wrapped = false

local function zombiesDisabled()
    local off = false
    pcall(function()
        local v = nil
        if type(getSandboxOptions) == "function" then
            local opt = getSandboxOptions():getOptionByName("Zombies")
            if opt ~= nil then v = opt:getValue() end
        end
        if v == nil and SandboxVars ~= nil then v = SandboxVars.Zombies end
        if v ~= nil then off = (tonumber(v) or 0) >= 6 end
    end)
    return off
end

function BridgeZombieWarn.shouldWarn()
    if BridgeZombieWarn.shown then return false end
    if Bridge == nil or Bridge.store == nil then return false end
    if Bridge.mp then return false end
    if Bridge.store.zombieWarned then return false end
    if not zombiesDisabled() then return false end
    local wants = false
    pcall(function() wants = BridgeData ~= nil and BridgeData.wants(Bridge.store) end)
    if not wants then return false end
    local alive = false
    pcall(function() alive = Bridge.alive() end)
    if alive then return false end
    return true
end

local function message()
    local name = "Rin"
    pcall(function() if BridgeData ~= nil then name = BridgeData.nameOf(Bridge.store) end end)
    local msg = nil
    pcall(function() if BridgeData ~= nil then msg = BridgeData.text("ZombieOffWarn", name) end end)
    if type(msg) ~= "string" or msg == "" or msg == "IGUI_NotAlone_ZombieOffWarn" then
        msg = tostring(name) .. " cannot appear: zombie spawning is disabled in this world " ..
            "(Sandbox: Zombies = None), so her body cannot be created. " ..
            "Set the Zombies sandbox option above None and reload the save. This warning is shown only once."
    end
    msg = "Stay With Me: " .. msg
    return msg
end

function BridgeZombieWarn.showOnce()
    if BridgeZombieWarn.shown then return end
    BridgeZombieWarn.shown = true
    pcall(function() if Bridge.store ~= nil then Bridge.store.zombieWarned = true end end)

    local text = message()
    pcall(function()
        if ISModalDialog == nil then return end
        local sw, sh = 800, 600
        pcall(function()
            local core = getCore()
            if core ~= nil then sw, sh = core:getScreenWidth(), core:getScreenHeight() end
        end)
        local width, height = 480, 140
        pcall(function()
            local tm = getTextManager()
            local font = UIFont.Small
            local measured = tm:MeasureStringX(font, text) + 60
            if measured > 560 then measured = 560 end
            if measured > width then width = measured end
            local lines = math.ceil((tm:MeasureStringX(font, text) + 1) / (width - 60))
            if lines < 2 then lines = 2 end
            height = math.max(height, (lines + 1) * (tm:getFontHeight(font) + 2) + 40)
        end)
        local modal = ISModalDialog:new((sw - width) / 2, (sh - height) / 2, width, height, text, false, nil, nil)
        modal:initialise()
        modal:addToUIManager()
        if modal.setAlwaysOnTop ~= nil then modal:setAlwaysOnTop(true) end
        if modal.setCapture ~= nil then modal:setCapture(true) end
        local sc = UIManager.getSpeedControls()
        if sc ~= nil then sc:SetCurrentGameSpeed(0) end
    end)

    pcall(function()
        if BridgeLog ~= nil and BridgeLog.on() then
            print("[Bridge] warning shown: zombies disabled, companion cannot spawn")
        end
    end)
end

local function install()
    if Bridge == nil or type(Bridge.spawnZombie) ~= "function" then return end
    if BridgeZombieWarn.wrapped then return end
    BridgeZombieWarn.wrapped = true
    local original = Bridge.spawnZombie
    Bridge.spawnZombie = function(...)
        pcall(function()
            if BridgeZombieWarn.shouldWarn() then BridgeZombieWarn.showOnce() end
        end)
        return original(...)
    end
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(install) end)
end
