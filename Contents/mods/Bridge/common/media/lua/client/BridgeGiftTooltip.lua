-- Adds a "Gift" line to the inventory item hover tooltip showing what the companion
-- would gain from the item. Uses the B42 ObjectTooltip layout API (same one the base
-- game's farming/trough tooltips use). Wrapped defensively: if the API or the item
-- class is not available, the vanilla tooltip is drawn unchanged.
BridgeGiftTooltip = BridgeGiftTooltip or {}
local B = BridgeGiftTooltip

B.enabled = true

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGiftTooltip] " .. tostring(text)) end end

local function tr(key)
    local text = key
    pcall(function() text = getText("IGUI_NotAlone_" .. key) end)
    return text
end

-- The item does not change while its tooltip is up, so compute the preview once.
-- Recompute when the hovered item changes or after any gift is given (which can
-- change what is left for the day and the "already given" flag).
local lastItem, lastVersion, lastInfo = nil, nil, nil

local function previewFor(item)
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

-- "+3" or "+3 / +1" (romance shown only when open).
function B.valueBase(info)
    local parts = {}
    if info.f > 0 then parts[#parts + 1] = "+" .. tostring(info.f) end
    if info.r > 0 and info.romanceOn then parts[#parts + 1] = "+" .. tostring(info.r) end
    local text = table.concat(parts, " / ")
    if text == "" then text = "+0" end
    return text
end

-- Base value plus a state suffix when it will not pay right now.
function B.valueText(info)
    local text = B.valueBase(info)
    if info.given then
        text = text .. " (" .. tr("TooltipGiftGiven") .. ")"
    elseif info.capped then
        text = text .. " (" .. tr("TooltipGiftFull") .. ")"
    end
    return text
end

-- Reserve the same top space Starlit-style wrapping does: the item's title line,
-- plus a line per extra item and for food with spices.
local function topOffset(item, tooltip)
    local spacing = 16
    pcall(function() spacing = tooltip:getLineSpacing() + 5 end)
    local off = spacing
    pcall(function()
        local extra = item:getExtraItems()
        if extra ~= nil then off = off + spacing * extra:size() end
    end)
    pcall(function()
        if instanceof ~= nil and instanceof(item, "Food") and item:getSpices() ~= nil then
            off = off + spacing
        end
    end)
    return off
end

local function padX(tooltip)
    local pad = 8
    pcall(function() pad = getTextManager():MeasureStringX(tooltip:getFont(), "0") or pad end)
    if type(pad) ~= "number" or pad <= 0 then pad = 8 end
    return pad
end

local function drawWithGift(item, tooltip, info, oldDoTooltip)
    local ok = pcall(function()
        local layout = tooltip:beginLayout()
        pcall(function() layout:setMinLabelWidth(80) end)
        pcall(function() layout:setMinValueWidth(80) end)
        item:DoTooltipEmbedded(tooltip, layout, 0)
        local row = layout:addItem()
        row:setLabel(tr("TooltipGift") .. ":", 1, 1, 0.8, 1)
        row:setValue(B.valueText(info), 0.6, 1, 0.6, 1)
        local pad = padX(tooltip)
        local height = layout:render(pad, topOffset(item, tooltip), tooltip)
        tooltip:endLayout(layout)
        local width = tooltip:getWidth()
        if type(width) ~= "number" or width < 150 then width = 150 end
        tooltip:setHeight(height + math.floor(pad / 2))
        tooltip:setWidth(width)
    end)
    if not ok then pcall(oldDoTooltip, item, tooltip) end
end

local function install()
    if ISToolTipInv == nil or type(ISToolTipInv.render) ~= "function" then return false end
    if ISToolTipInv.bridgeGiftWrapped then return true end
    local oldRender = ISToolTipInv.render
    ISToolTipInv.render = function(self)
        local item = self ~= nil and self.item or nil
        if not B.enabled or item == nil or type(getmetatable) ~= "function" then
            return oldRender(self)
        end
        local info = previewFor(item)
        if info == nil then
            return oldRender(self)
        end
        local mt = getmetatable(item)
        local itemMetatable = mt ~= nil and mt.__index or nil
        if itemMetatable == nil or type(itemMetatable.DoTooltip) ~= "function" then
            return oldRender(self)
        end
        local oldDoTooltip = itemMetatable.DoTooltip
        itemMetatable.DoTooltip = function(innerItem, tooltip)
            drawWithGift(innerItem, tooltip, info, oldDoTooltip)
        end
        local ok, err = pcall(oldRender, self)
        itemMetatable.DoTooltip = oldDoTooltip
        if not ok then log("render error: " .. tostring(err)) end
    end
    ISToolTipInv.bridgeGiftWrapped = true
    log("gift tooltip installed")
    return true
end

B.install = install
if not install() then
    if type(Events) == "table" and Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function() install() end)
    end
end
