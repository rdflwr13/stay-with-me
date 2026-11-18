BridgeUIScale = BridgeUIScale or {}

BridgeUIScale.MODE_AUTO = 0
BridgeUIScale.AUTO_MAX = 1.6
BridgeUIScale.AUTO_BASE_H = 1080
BridgeUIScale.MIN_SCALE = 0.5
BridgeUIScale.MARGIN = 10
BridgeUIScale.MODDATA_KEY = "StayWithMeUIScale"
BridgeUIScale.revision = 0

local function round2(v)
    if type(v) ~= "number" or v ~= v then return nil end
    return math.floor(v * 100 + 0.5) / 100
end

local function localPlayer()
    local p = nil
    pcall(function()
        if type(getSpecificPlayer) == "function" then p = getSpecificPlayer(0) end
        if p == nil and type(getPlayer) == "function" then p = getPlayer() end
    end)
    return p
end

local function playerModData()
    local data = nil
    local p = localPlayer()
    if p ~= nil then pcall(function() data = p:getModData() end) end
    return data
end

local function screenSize()
    local sw, sh = 1920, 1080
    pcall(function()
        if getCore == nil then return end
        local w, h = getCore():getScreenWidth(), getCore():getScreenHeight()
        if type(w) == "number" and w > 0 then sw = w end
        if type(h) == "number" and h > 0 then sh = h end
    end)
    return sw, sh
end

function BridgeUIScale.requested()
    local data = playerModData()
    if data == nil then return BridgeUIScale.MODE_AUTO end
    local v = tonumber(data[BridgeUIScale.MODDATA_KEY])
    if v == nil or v <= 0 then return BridgeUIScale.MODE_AUTO end
    local r = round2(v)
    if r == nil then return BridgeUIScale.MODE_AUTO end
    return r
end

function BridgeUIScale.auto()
    local _, sh = screenSize()
    local s = sh / BridgeUIScale.AUTO_BASE_H
    if s < 1.0 then s = 1.0 end
    if s > BridgeUIScale.AUTO_MAX then s = BridgeUIScale.AUTO_MAX end
    return s
end

function BridgeUIScale.baseScale()
    local r = BridgeUIScale.requested()
    if r == nil or r <= 0 then return BridgeUIScale.auto() end
    return r
end

function BridgeUIScale.effectiveFor(minW, minH, margin)
    local s = BridgeUIScale.baseScale()
    local sw, sh = screenSize()
    local m = margin or BridgeUIScale.MARGIN
    local fit = 1
    if type(minW) == "number" and minW > 0 then
        local room = (sw - 2 * m) / (minW * s)
        if room < fit then fit = room end
    end
    if type(minH) == "number" and minH > 0 then
        local room = (sh - 2 * m) / (minH * s)
        if room < fit then fit = room end
    end
    if fit < 0 then fit = 0 end
    local out = s * fit
    if out < BridgeUIScale.MIN_SCALE then out = BridgeUIScale.MIN_SCALE end
    return out
end

function BridgeUIScale.fontsFor(scale)
    local s = scale
    if type(s) ~= "number" or s ~= s then s = BridgeUIScale.baseScale() end
    local body, head = UIFont.Small, UIFont.Medium
    if s >= 1.8 then
        body, head = UIFont.Large, UIFont.Large
    elseif s >= 1.5 then
        body, head = UIFont.Medium, UIFont.Large
    end
    local bodyH, headH = 0, 0
    pcall(function()
        local tm = getTextManager()
        bodyH = tm:getFontHeight(body)
        headH = tm:getFontHeight(head)
    end)
    return body, head, bodyH, headH
end

function BridgeUIScale.set(value)
    local v = tonumber(value)
    if v == nil then return BridgeUIScale.requested() end
    if v <= 0 then
        v = BridgeUIScale.MODE_AUTO
    else
        v = round2(v)
        if v == nil then return BridgeUIScale.requested() end
        if v < 0.75 then v = 0.75 end
        if v > 2.0 then v = 2.0 end
    end
    local data = playerModData()
    if data ~= nil then data[BridgeUIScale.MODDATA_KEY] = v end
    BridgeUIScale.revision = BridgeUIScale.revision + 1
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        local S = BridgeUIScale.effectiveFor(BridgeUIScale.AUTO_BASE_H, BridgeUIScale.AUTO_BASE_H)
        print(string.format("[BridgeUIScale] set requested=%s effective=%.3f revision=%d",
            tostring(v), S, BridgeUIScale.revision))
    end
    return v
end

function BridgeUIScale.describe()
    local req = BridgeUIScale.requested()
    local S = BridgeUIScale.effectiveFor(BridgeUIScale.AUTO_BASE_H, BridgeUIScale.AUTO_BASE_H)
    local sw, sh = screenSize()
    return string.format("requested=%s effective=%.3f screen=%dx%d revision=%d",
        tostring(req), S, sw, sh, BridgeUIScale.revision)
end

local function onResolutionChange()
    BridgeUIScale.revision = BridgeUIScale.revision + 1
end

if Events ~= nil and Events.OnResolutionChange ~= nil then
    Events.OnResolutionChange.Add(onResolutionChange)
end
