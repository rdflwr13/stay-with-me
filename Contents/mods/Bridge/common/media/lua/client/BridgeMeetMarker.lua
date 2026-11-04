if BridgeMeetMarker ~= nil and BridgeMeetMarker.loaded == true then return end

BridgeMeetMarker = BridgeMeetMarker or {}
BridgeMeetMarker.loaded = true
BridgeMeetMarker.instance = nil

local WIDTH = 120
local HEIGHT = 100
local ICON = 32
local TOP = 16
local MAX_RANGE = 500
local REFRESH_MS = 100
local DOT_RADIUS = 22

local OFFSETS = {
    N = { 0, -DOT_RADIUS },
    NE = { 16, -16 },
    E = { DOT_RADIUS, 0 },
    SE = { 16, 16 },
    S = { 0, DOT_RADIUS },
    SW = { -16, 16 },
    W = { -DOT_RADIUS, 0 },
    NW = { -16, -16 },
    here = { 0, 0 },
}

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeMeetMarker] " .. tostring(text)) end
end

local function screenPos(x, y, z)
    local px, py = nil, nil
    pcall(function()
        local left, top = IsoCamera.getScreenLeft(0), IsoCamera.getScreenTop(0)
        local zoom = getCore():getZoom(0)
        px = (IsoUtils.XToScreen(x, y, z, 0) - IsoCamera.getOffX(0)) / zoom + left
        py = (IsoUtils.YToScreen(x, y, z, 0) - IsoCamera.getOffY(0)) / zoom + top
    end)
    if px == nil or py == nil then
        pcall(function()
            px = isoToScreenX(0, x, y, z)
            py = isoToScreenY(0, x, y, z)
        end)
    end
    return px, py
end

local function screenDir(dx, dy)
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then return "here" end
    local ax, ay = math.abs(dx), math.abs(dy)
    if ay > ax * 2.414 then return dy < 0 and "N" or "S" end
    if ax > ay * 2.414 then return dx > 0 and "E" or "W" end
    if dx > 0 then return dy < 0 and "NE" or "SE" end
    return dy < 0 and "NW" or "SW"
end

BridgeMeetMarkerUI = ISUIElement:derive("BridgeMeetMarkerUI")

function BridgeMeetMarkerUI:initialise()
    ISUIElement.initialise(self)
    self:addToUIManager()
    self.moveWithMouse = true
    self:setVisible(false)
end

function BridgeMeetMarkerUI:createChildren()
end

function BridgeMeetMarkerUI:onMouseDoubleClick(x, y)
    return nil
end

function BridgeMeetMarkerUI:onMouseUp(x, y)
    if not self.moveWithMouse then return end
    if not self:getIsVisible() then return end
    self.moving = false
    if ISMouseDrag ~= nil and ISMouseDrag.tabPanel ~= nil then
        ISMouseDrag.tabPanel:onMouseUp(x, y)
    end
    if ISMouseDrag ~= nil then ISMouseDrag.dragView = nil end
    self:savePosition()
end

function BridgeMeetMarkerUI:onMouseUpOutside(x, y)
    if not self.moveWithMouse then return end
    if not self:getIsVisible() then return end
    self.moving = false
    if ISMouseDrag ~= nil then ISMouseDrag.dragView = nil end
    self:savePosition()
end

function BridgeMeetMarkerUI:onMouseDown(x, y)
    if not self.moveWithMouse then return true end
    if not self:getIsVisible() then return end
    if not self:isMouseOver() then return end
    self.downX = x
    self.downY = y
    self.moving = true
    self:bringToTop()
end

function BridgeMeetMarkerUI:onMouseMoveOutside(dx, dy)
    if not self.moveWithMouse then return end
    self.mouseOver = false
    if self.moving then self:moveBy(dx, dy) end
end

function BridgeMeetMarkerUI:onMouseMove(dx, dy)
    if not self.moveWithMouse then return end
    self.mouseOver = true
    if self.moving then self:moveBy(dx, dy) end
end

function BridgeMeetMarkerUI:moveBy(dx, dy)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local nx = math.max(0, math.min(sw - WIDTH, self:getX() + dx))
    local ny = math.max(0, math.min(sh - HEIGHT, self:getY() + dy))
    self:setX(nx)
    self:setY(ny)
    self:bringToTop()
    self:savePosition()
end

function BridgeMeetMarkerUI:savePosition()
    if Bridge == nil or Bridge.store == nil then return end
    Bridge.store.meetMarkerX = math.floor(self:getX())
    Bridge.store.meetMarkerY = math.floor(self:getY())
end

function BridgeMeetMarkerUI:update()
    local now = getTimeInMillis()
    if self.lastUpdate ~= nil and now - self.lastUpdate < REFRESH_MS then return end
    self.lastUpdate = now
    if Bridge == nil or BridgeMeet == nil or BridgeData == nil then self:setVisible(false) return end
    if BridgeMeet.unjoined() ~= true then self:setVisible(false) return end
    local x, y, z = BridgeMeet.markerTarget()
    if x == nil then self:setVisible(false) return end
    local red = BridgeData.owner()
    if red == nil then self:setVisible(false) return end
    local d = math.sqrt((red:getX() - x) ^ 2 + (red:getY() - y) ^ 2)
    if d > MAX_RANGE then self:setVisible(false) return end
    self.dist = d
    local ppx, ppy = screenPos(red:getX(), red:getY(), red:getZ())
    local tpx, tpy = screenPos(x, y, z)
    if ppx ~= nil and ppy ~= nil and tpx ~= nil and tpy ~= nil then
        self.dir = screenDir(tpx - ppx, tpy - ppy)
    else
        self.dir = BridgeMeet.dirTo(x, y)
    end
    self:setVisible(true)
end

function BridgeMeetMarkerUI:render()
    if not self:getIsVisible() then return end
    local cx, cy = WIDTH / 2, 30
    local icon = self.iconTex
    if icon == nil then
        pcall(function() icon = getTexture("media/ui/SWM/MeetMarker.png") end)
        self.iconTex = icon
    end
    if icon ~= nil then
        self:drawTexture(icon, cx - ICON / 2, cy - ICON / 2, 1, 1, 1, 1)
    else
        self:drawRect(cx - 6, cy - 6, 12, 12, 0.95, 0.95, 0.45, 0.70)
    end
    local off = OFFSETS[self.dir or "here"] or OFFSETS.here
    self:drawRect(cx + off[1] - 4, cy + off[2] - 4, 8, 8, 1, 1, 0.85, 0.30)
    local text = tostring(self.dir or "?") .. " " .. tostring(math.floor(self.dist or 0)) .. " m"
    self:drawTextCentre(text, cx, cy + DOT_RADIUS + 10, 1, 1, 1, 1, UIFont.Small)
end

function BridgeMeetMarker.install()
    if BridgeMeetMarker.instance ~= nil then return true end
    local sw = getCore():getScreenWidth()
    local x, y = sw / 2 - WIDTH / 2, TOP
    if Bridge ~= nil and Bridge.store ~= nil then
        x = tonumber(Bridge.store.meetMarkerX) or x
        y = tonumber(Bridge.store.meetMarkerY) or y
    end
    x = math.max(0, math.min(sw - WIDTH, x))
    y = math.max(0, math.min(getCore():getScreenHeight() - HEIGHT, y))
    local ui = BridgeMeetMarkerUI:new(math.floor(x), math.floor(y), WIDTH, HEIGHT)
    ui.bConsumeMouseEvents = false
    ui.moveWithMouse = true
    ui:initialise()
    BridgeMeetMarker.instance = ui
    log("installed")
    return true
end

function BridgeMeetMarker.remove()
    local ui = BridgeMeetMarker.instance
    if ui == nil then return end
    pcall(function() ui:removeFromUIManager() end)
    BridgeMeetMarker.instance = nil
end

if type(Events) == "table" then
    if Events.OnTick ~= nil then
        Events.OnTick.Add(function()
            local ui = BridgeMeetMarker.instance
            if ui ~= nil then ui:update() end
        end)
    end
    if Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function() BridgeMeetMarker.install() end)
    end
    if Events.OnCreatePlayer ~= nil then
        Events.OnCreatePlayer.Add(function(playerIndex)
            if playerIndex ~= nil and playerIndex ~= 0 then return end
            BridgeMeetMarker.install()
        end)
    end
end

return BridgeMeetMarker
