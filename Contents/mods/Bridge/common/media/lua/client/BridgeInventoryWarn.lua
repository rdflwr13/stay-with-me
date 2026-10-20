require "ISUI/ISModalDialog"

BridgeInventoryWarn = BridgeInventoryWarn or {}
BridgeInventoryWarn.shown = false
BridgeInventoryWarn.WARN_RATIO = 0.83

local function companionName()
    local name = "Rin"
    pcall(function()
        if BridgeData ~= nil and BridgeData.nameOf ~= nil then name = BridgeData.nameOf(Bridge.store) end
    end)
    return tostring(name)
end

local function message(used, cap, truncated)
    local name = companionName()
    local blockAt = math.floor(cap * ((BridgeItems ~= nil and BridgeItems.BLOCK_RATIO) or 0.92))
    if truncated then
        return "Stay With Me: " .. name .. " is carrying too much. Her saved inventory has reached the save limit (" ..
            tostring(used) .. " / " .. tostring(cap) .. " characters). Recent inventory changes may not be saved. " ..
            "Store or remove some items."
    end
    return "Stay With Me: " .. name .. " is carrying too much. Her inventory is near the save limit (" ..
        tostring(used) .. " / " .. tostring(cap) .. " characters). New transfers will stop at " .. tostring(blockAt) ..
        ". Store or remove some items before that."
end

function BridgeInventoryWarn.check(used, cap, truncated)
    if BridgeInventoryWarn.shown then return end
    used = tonumber(used)
    cap = tonumber(cap)
    if used == nil or cap == nil or cap <= 0 then return end
    if not truncated and used < cap * BridgeInventoryWarn.WARN_RATIO then return end

    BridgeInventoryWarn.shown = true
    pcall(function()
        if Bridge ~= nil and type(Bridge.speak) == "function" then Bridge.speak("JobLootFull") end
    end)

    local text = message(used, cap, truncated)
    pcall(function()
        if ISModalDialog == nil then
            if BridgeChat ~= nil and type(BridgeChat.addLine) == "function" then
                BridgeChat.addLine("Stay With Me", text, 0.95, 0.75, 0.35)
            end
            return
        end

        local sw, sh = 800, 600
        pcall(function()
            local core = getCore()
            if core ~= nil then sw, sh = core:getScreenWidth(), core:getScreenHeight() end
        end)

        local width, height = 520, 150
        pcall(function()
            local tm = getTextManager()
            local font = UIFont.Small
            local measured = tm:MeasureStringX(font, text) + 60
            if measured > 600 then measured = 600 end
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
    end)

    pcall(function()
        if BridgeLog ~= nil and BridgeLog.on() then
            print("[Bridge] warning shown: inventory near limit (" .. tostring(used) .. " / " .. tostring(cap) .. ")")
        end
    end)
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() BridgeInventoryWarn.shown = false end)
end
