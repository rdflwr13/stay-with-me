BridgeGiftTooltip = BridgeGiftTooltip or {}
local B = BridgeGiftTooltip

B.enabled = true

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGiftTooltip] " .. tostring(text)) end end

local function tr(key)
    local text = key
    pcall(function() text = getText("IGUI_NotAlone_" .. key) end)
    return text
end

local lastItem, lastVersion, lastInfo = nil, nil, nil

local function previewFor(item)
    if item == nil or not instanceof(item, "InventoryItem") then return nil end
    local version = BridgeSocial ~= nil and (BridgeSocial.giftVersion or 0) or 0
    if item == lastItem and version == lastVersion then return lastInfo end
    lastItem, lastVersion = item, version
    lastInfo = nil
    pcall(function()
        if BridgeSocial ~= nil and type(BridgeSocial.giftPreview) == "function" then
            lastInfo = BridgeSocial.giftPreview(item)
        end
    end)
    return lastInfo
end

function B.valueBase(info)
    local parts = {}
    if info.f > 0 then parts[#parts + 1] = "+" .. tostring(info.f) end
    if info.r > 0 and info.romanceOn then parts[#parts + 1] = "+" .. tostring(info.r) end
    local text = table.concat(parts, " / ")
    if text == "" then text = "+0" end
    return text
end

function B.valueText(info)
    local text = B.valueBase(info)
    if info.given then
        text = text .. " (" .. tr("TooltipGiftGiven") .. ")"
    elseif info.capped then
        text = text .. " (" .. tr("TooltipGiftFull") .. ")"
    end
    return text
end

local function appendGift(item, tooltip)
    local info = previewFor(item)
    if info == nil then return end
    local font, spacing, pad = nil, 14, 8
    pcall(function() font = tooltip:getFont() end)
    pcall(function() spacing = tooltip:getLineSpacing() or 14 end)
    pcall(function() pad = tooltip.padLeft or pad end)
    if type(pad) ~= "number" or pad <= 0 then pad = 8 end
    local text = tr("TooltipGift") .. ": " .. B.valueText(info)
    local y, w = 0, 0
    pcall(function() y = tooltip:getHeight(); w = tooltip:getWidth() end)
    pcall(function() tooltip:DrawText(font, text, pad, y + 2, 0.6, 1, 0.6, 1) end)
    local need = 0
    pcall(function() need = getTextManager():MeasureStringX(font, text) + pad * 2 end)
    if need > w then pcall(function() tooltip:setWidth(need) end) end
    pcall(function() tooltip:setHeight(y + spacing) end)
end

local function hookItemClass(item)
    if item == nil or type(getmetatable) ~= "function" then return false end
    local mt = getmetatable(item)
    local im = mt ~= nil and mt.__index or nil
    if im == nil or type(im.DoTooltip) ~= "function" then return false end
    if im.bridgeGiftHooked then return true end
    local orig = im.DoTooltip
    im.DoTooltip = function(self, tooltip)
        orig(self, tooltip)
        if B.enabled then pcall(appendGift, self, tooltip) end
    end
    im.bridgeGiftHooked = true
    log("gift tooltip hooked")
    return true
end

local function tryHook()
    local item = nil
    pcall(function()
        local p = getSpecificPlayer(0)
        local inv = p and p:getInventory()
        local items = inv and inv:getItems()
        if items ~= nil and items:size() > 0 then item = items:get(0) end
    end)
    return hookItemClass(item)
end

local function install()
    if tryHook() then return true end
    if ISToolTipInv == nil or type(ISToolTipInv.render) ~= "function" then return false end
    if ISToolTipInv.bridgeGiftProbe then return false end
    local oldRender = ISToolTipInv.render
    ISToolTipInv.render = function(self)
        if self ~= nil and self.item ~= nil then hookItemClass(self.item) end
        return oldRender(self)
    end
    ISToolTipInv.bridgeGiftProbe = true
    return true
end

local function hookStarlit()
    if B.starlitHooked then return true end
    local ok, inv = pcall(require, "Starlit/client/ui/InventoryUI")
    if not ok or inv == nil or inv.onFillItemTooltip == nil
        or type(inv.onFillItemTooltip.addListener) ~= "function" then
        return false
    end
    inv.onFillItemTooltip:addListener(function(tooltip, layout, item)
        if not B.enabled or layout == nil or item == nil then return end
        pcall(function()
            local info = previewFor(item)
            if info == nil then return end
            local row = layout:addItem()
            row:setLabel(tr("TooltipGift") .. ":", 1, 1, 0.8, 1)
            row:setValue(B.valueText(info), 0.6, 1, 0.6, 1)
        end)
    end)
    B.starlitHooked = true
    log("starlit tooltip listener added")
    return true
end

B.install = install
install()
hookStarlit()
if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() install(); hookStarlit() end)
end
if type(Events) == "table" and Events.OnTick ~= nil and Events.OnTick.Add ~= nil then
    local tries = 0
    local function retry()
        tries = tries + 1
        if tryHook() or tries > 600 then
            pcall(function() Events.OnTick.Remove(retry) end)
        end
    end
    Events.OnTick.Add(retry)
end
