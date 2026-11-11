require "ISUI/ISModalDialog"

BridgeWarn = BridgeWarn or {}

BridgeWarn.VERSION = 1
BridgeWarn.WARN_RATIO = 0.83
BridgeWarn.shown = { zombie = false, inventory = false, compat = false }
BridgeWarn.queue = {}
BridgeWarn.active = nil
BridgeWarn.wrapped = false
BridgeWarn.PREFIX = "Stay With Me: "

local COMPATS = {
    { id = "ALifeStayWithMeCompat", name = "A-Life x Stay With Me Compat" },
    { id = "RinALifeGuard", name = "Stay With Me - A-Life Compatibility Patch" },
}

local function tr(key, ...)
    local args = { ... }
    local text = nil
    pcall(function() text = getText("IGUI_NotAlone_" .. key, unpack(args)) end)
    if type(text) ~= "string" then return "" end
    return text
end

local function modActive(id)
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(id) or mods:contains("\\" .. id))
    end)
    return on == true
end

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

function BridgeWarn.measure(text)
    local width, height = 520, 140
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
    return width, height
end

function BridgeWarn.pump()
    if BridgeWarn.active ~= nil then return end
    local text = table.remove(BridgeWarn.queue, 1)
    if text == nil then return end
    local shown = false
    pcall(function()
        if ISModalDialog == nil then return end
        local sw, sh = 800, 600
        pcall(function()
            local core = getCore()
            if core ~= nil then sw, sh = core:getScreenWidth(), core:getScreenHeight() end
        end)
        local modalText = BridgeWarn.PREFIX .. text
        local width, height = BridgeWarn.measure(modalText)
        local modal = ISModalDialog:new((sw - width) / 2, (sh - height) / 2, width, height,
            modalText, false, BridgeWarn, BridgeWarn.onClosed)
        modal:initialise()
        modal:addToUIManager()
        if modal.setAlwaysOnTop ~= nil then modal:setAlwaysOnTop(true) end
        if modal.setCapture ~= nil then modal:setCapture(true) end
        local sc = UIManager.getSpeedControls()
        if sc ~= nil then sc:SetCurrentGameSpeed(0) end
        BridgeWarn.active = modal
        shown = true
    end)
    if shown then return end
    BridgeWarn.active = nil
    pcall(function()
        if BridgeChat ~= nil and type(BridgeChat.addLine) == "function" then
            BridgeChat.addLine("Stay With Me", text, 0.95, 0.75, 0.35)
        end
    end)
    BridgeWarn.pump()
end

function BridgeWarn.show(text)
    if type(text) ~= "string" or text == "" then return end
    BridgeWarn.queue[#BridgeWarn.queue + 1] = text
    BridgeWarn.pump()
end

function BridgeWarn.onClosed()
    BridgeWarn.active = nil
    BridgeWarn.pump()
end

function BridgeWarn.shouldWarnZombie()
    if BridgeWarn.shown.zombie then return false end
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

function BridgeWarn.showZombie()
    if BridgeWarn.shown.zombie then return end
    BridgeWarn.shown.zombie = true
    pcall(function() if Bridge.store ~= nil then Bridge.store.zombieWarned = true end end)
    local name = "Rin"
    pcall(function() if BridgeData ~= nil then name = BridgeData.nameOf(Bridge.store) end end)
    BridgeWarn.show(tr("ZombieOffWarn", tostring(name)))
    if BridgeLog ~= nil and BridgeLog.on() then
        print("[Bridge] warning shown: zombies disabled, companion cannot spawn")
    end
end

function BridgeWarn.checkInventory(used, cap, truncated)
    if BridgeWarn.shown.inventory then return end
    used = tonumber(used)
    cap = tonumber(cap)
    if used == nil or cap == nil or cap <= 0 then return end
    if not truncated and used < cap * BridgeWarn.WARN_RATIO then return end

    BridgeWarn.shown.inventory = true
    pcall(function()
        if Bridge ~= nil and type(Bridge.speak) == "function" then Bridge.speak("JobLootFull") end
    end)

    local name = "Rin"
    pcall(function() if BridgeData ~= nil then name = BridgeData.nameOf(Bridge.store) end end)
    local blockAt = math.floor(cap * ((BridgeItems ~= nil and BridgeItems.BLOCK_RATIO) or 0.92))
    if truncated then
        BridgeWarn.show(tr("InvWarnTruncated", tostring(name), used, cap))
    else
        BridgeWarn.show(tr("InvWarnNear", tostring(name), used, cap, blockAt))
    end
    if BridgeLog ~= nil and BridgeLog.on() then
        print("[Bridge] warning shown: inventory near limit (" .. tostring(used) .. " / " .. tostring(cap) .. ")")
    end
end

function BridgeWarn.checkCompat()
    if BridgeWarn.shown.compat then return end
    if Bridge == nil then return end
    if Bridge.store == nil and type(Bridge.initStore) == "function" then pcall(Bridge.initStore) end
    if type(Bridge.store) ~= "table" then return end
    local warned = tonumber(Bridge.store.compatWarned) or 0
    if warned >= BridgeWarn.VERSION then return end
    local wants = false
    pcall(function() wants = BridgeData ~= nil and BridgeData.wants(Bridge.store) == true end)
    if not wants then return end
    local names = {}
    for index = 1, #COMPATS do
        local entry = COMPATS[index]
        if modActive(entry.id) then names[#names + 1] = entry.name end
    end
    if #names == 0 then return end
    BridgeWarn.shown.compat = true
    Bridge.store.compatWarned = BridgeWarn.VERSION
    if #names == 1 then
        BridgeWarn.show(tr("CompatWarnOne", names[1]))
    else
        BridgeWarn.show(tr("CompatWarnMany", table.concat(names, ", ")))
    end
end

function BridgeWarn.install()
    if Bridge == nil or type(Bridge.spawnZombie) ~= "function" then return end
    if BridgeWarn.wrapped then return end
    BridgeWarn.wrapped = true
    local original = Bridge.spawnZombie
    Bridge.spawnZombie = function(...)
        pcall(function()
            if BridgeWarn.shouldWarnZombie() then BridgeWarn.showZombie() end
        end)
        return original(...)
    end
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function()
        BridgeWarn.shown.inventory = false
        BridgeWarn.shown.compat = false
        BridgeWarn.queue = {}
        pcall(BridgeWarn.install)
        pcall(BridgeWarn.checkCompat)
    end)
end
