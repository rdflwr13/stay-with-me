









BridgeBar = BridgeBar or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeBar] " .. tostring(text)) end end


local BAR_W = 46
local BAR_H = 6
local BAR_PAD = 2
local LIFT_EXTRA = -15


local COL_FILL   = { r = 0.16, g = 0.82, b = 0.74 }
local COL_BG     = { r = 0.05, g = 0.08, b = 0.09, a = 0.75 }
local COL_BORDER = { r = 0.02, g = 0.02, b = 0.02, a = 0.90 }

local surface = nil

local function getBody()
    if Bridge == nil or Bridge.body == nil then return nil end
    if Bridge.hiddenSince ~= nil then return nil end
    return Bridge.body
end

local function isEnabled()
    local on = false
    pcall(function() on = BridgeData.optionOf(Bridge.store, "fatigueBar") == true end)
    return on
end


local function stamina()
    local f = 0
    pcall(function() f = tonumber(BridgeFight and BridgeFight.fatigue) end)
    if type(f) ~= "number" or f ~= f then f = 0 end
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    return 1 - f
end

local function drawBar(self)
    local z = getBody()
    if not isEnabled() or z == nil then return end
    local player = BridgeData.owner()
    if player == nil then return end
    local pn = player:getPlayerNum()
    if z:isInvisible() or z:getAlpha(pn) < 0.1 then return end

    local inCar = false
    pcall(function() inCar = z:getVehicle() ~= nil end)
    if inCar then return end

    local zoom = getCore():getZoom(pn)
    local lift = 128 * Core.getTileScale() / 2 / zoom
    local x = isoToScreenX(pn, z:getX(), z:getY(), z:getZ())

    local y = isoToScreenY(pn, z:getX(), z:getY(), z:getZ()) - lift - BAR_H - LIFT_EXTRA


    local l, t = getPlayerScreenLeft(pn), getPlayerScreenTop(pn)
    local w, h = getPlayerScreenWidth(pn), getPlayerScreenHeight(pn)
    if x < l - BAR_W or x > l + w + BAR_W or y < t - BAR_H or y > t + h + BAR_H then return end

    local left = math.floor(x - BAR_W / 2)
    local top = math.floor(y)
    local v = stamina()

    self:drawRect(left - BAR_PAD, top - BAR_PAD, BAR_W + BAR_PAD * 2, BAR_H + BAR_PAD * 2,
        COL_BG.a, COL_BG.r, COL_BG.g, COL_BG.b)
    if v > 0 then
        self:drawRect(left, top, math.max(1, math.floor(BAR_W * v)), BAR_H, 1,
            COL_FILL.r, COL_FILL.g, COL_FILL.b)
    end
    self:drawRectBorder(left, top, BAR_W, BAR_H, COL_BORDER.a, COL_BORDER.r, COL_BORDER.g, COL_BORDER.b)
end

local function ensure()
    if surface ~= nil then return surface end
    if ISUIElement == nil then return nil end
    local s = ISUIElement:new(0, 0, 1, 1)
    s:initialise()
    s:instantiate()
    s.anchorLeft, s.anchorTop = true, true
    s.onMouseDown = function() return false end
    s.onMouseUp = function() return false end
    s.onRightMouseDown = function() return false end
    s.onRightMouseUp = function() return false end
    s:setCapture(false)
    if s.javaObject ~= nil and s.javaObject.setConsumeMouseEvents ~= nil then
        s.javaObject:setConsumeMouseEvents(false)
    end
    s.render = function(self)
        local ok = pcall(drawBar, self)
        if not ok and BridgeBar.debug then log("draw failed") end
    end
    s:addToUIManager()
    s:setVisible(true)
    surface = s
    log("stamina bar surface created")
    return s
end

function BridgeBar.refresh() ensure() end

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(ensure) end)
end
if type(Events) == "table" and Events.OnPlayerUpdate ~= nil then
    Events.OnPlayerUpdate.Add(function() if surface == nil then pcall(ensure) end end)
end

log("loaded")
