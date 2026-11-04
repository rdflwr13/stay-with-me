require "ISUI/ISCollapsableWindow"

BridgeSeatPuppetWindow = ISCollapsableWindow:derive("BridgeSeatPuppetWindow")

local PAD = 10
local BTN_H = 22
local ROW_H = 26
local BW = 36
local GAP = 4
local LABEL_W = 108
local VALUE_X = PAD + LABEL_W + (BW + GAP) * 2
local WIDTH = PAD + LABEL_W + (BW + GAP) * 4 + 40 + PAD
local HEIGHT = 196

local function tr(key)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key) end
    local text = key
    pcall(function() text = getText("IGUI_NotAlone_" .. key) end)
    return text
end

function BridgeSeatPuppetWindow:addStep(x, y, text, axis, delta)
    local b = ISButton:new(x, y, BW, BTN_H, text, self, BridgeSeatPuppetWindow.onNudge)
    b:initialise()
    b:instantiate()
    b:setOnClick(BridgeSeatPuppetWindow.onNudge, axis, delta)
    self:addChild(b)
    self.buttons[#self.buttons + 1] = b
    return b
end

function BridgeSeatPuppetWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    self.rowsTop = self:titleBarHeight() + PAD + fontS + 8
    self.rows = {
        { axis = "u", key = "SeatPuppetUp" },
        { axis = "r", key = "SeatPuppetRight" },
        { axis = "f", key = "SeatPuppetForward" },
    }
    self.buttons = {}
    local fine = BridgeSeatPuppet ~= nil and BridgeSeatPuppet.FINE or 0.02
    local coarse = BridgeSeatPuppet ~= nil and BridgeSeatPuppet.COARSE or 0.10
    for i, row in ipairs(self.rows) do
        local y = self.rowsTop + (i - 1) * ROW_H
        local x = PAD + LABEL_W
        self:addStep(x, y, "<<", row.axis, -coarse)
        x = x + BW + GAP
        self:addStep(x, y, "<", row.axis, -fine)
        x = x + BW + GAP + 40
        self:addStep(x, y, ">", row.axis, fine)
        x = x + BW + GAP
        self:addStep(x, y, ">>", row.axis, coarse)
    end
    local by = self.rowsTop + ROW_H * 3 + 8
    self.resetBtn = ISButton:new(PAD, by, 90, BTN_H, tr("SeatPuppetReset"), self, BridgeSeatPuppetWindow.onReset)
    self.resetBtn:initialise()
    self.resetBtn:instantiate()
    self:addChild(self.resetBtn)
    self.closeBtn = ISButton:new(PAD + 100, by, 90, BTN_H, tr("SeatPuppetClose"), self, BridgeSeatPuppetWindow.onCloseClick)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)
end

function BridgeSeatPuppetWindow:onNudge(button, axis, delta)
    local S = BridgeSeatPuppet
    if S == nil or S.p == nil or S.car ~= self.car or S.seat ~= self.seat then return end
    if axis == "u" then
        S.nudge(self.car, self.seat, delta, 0, 0)
    elseif axis == "r" then
        S.nudge(self.car, self.seat, 0, delta, 0)
    else
        S.nudge(self.car, self.seat, 0, 0, delta)
    end
end

function BridgeSeatPuppetWindow:onReset()
    local S = BridgeSeatPuppet
    if S == nil then return end
    S.setOffset(self.car, self.seat, nil)
    S.reposition()
end

function BridgeSeatPuppetWindow:onCloseClick()
    self:close()
end

function BridgeSeatPuppetWindow:prerender()
    local S = BridgeSeatPuppet
    if S ~= nil and S.p ~= nil and S.car == self.car and S.seat ~= nil then self.seat = S.seat end
    local name = (S ~= nil and S.car ~= nil) and S.modelOf(S.car) or ""
    self.title = tr("SeatPuppetTitle") .. " - " .. name .. " - " .. tostring(self.seat)
    ISCollapsableWindow.prerender(self)
end

function BridgeSeatPuppetWindow:render()
    ISCollapsableWindow.render(self)
    local S = BridgeSeatPuppet
    local live = S ~= nil and S.p ~= nil and S.car == self.car and S.seat == self.seat
    local y = self:titleBarHeight() + PAD
    if live then
        self:drawText(tr("SeatPuppetHint"), PAD, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
    else
        self:drawText(tr("SeatPuppetNotInCar"), PAD, y, 0.9, 0.55, 0.55, 1, UIFont.Small)
    end
    for i, row in ipairs(self.rows or {}) do
        local ry = self.rowsTop + (i - 1) * ROW_H
        self:drawText(tr(row.key), PAD, ry + 3, 1, 1, 1, 1, UIFont.Small)
        local v = 0
        if live then v = S.offset(self.car, self.seat)[row.axis] end
        self:drawText(string.format("%.2f", v), VALUE_X, ry + 3, 1, 1, 1, 1, UIFont.Small)
    end
    for _, b in ipairs(self.buttons or {}) do
        if b.enable ~= live then b:setEnable(live) end
    end
    if self.resetBtn ~= nil and self.resetBtn.enable ~= live then self.resetBtn:setEnable(live) end
end

function BridgeSeatPuppetWindow:update()
    ISCollapsableWindow.update(self)
    local S = BridgeSeatPuppet
    if S == nil or S.p == nil then self:close() end
end

function BridgeSeatPuppetWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    BridgeSeatPuppetWindow.instance = nil
end

function BridgeSeatPuppetWindow:new(x, y, w, h)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor.a = 0.9
    o:setResizable(false)
    o.alwaysOnTop = true
    o.title = tr("SeatPuppetTitle")
    return o
end

function BridgeSeatPuppetWindow.show()
    local S = BridgeSeatPuppet
    if S == nil or S.p == nil or S.car == nil or S.seat == nil then return nil end
    if BridgeSeatPuppetWindow.instance ~= nil then BridgeSeatPuppetWindow.instance:close() end
    local w = BridgeSeatPuppetWindow:new(120, 120, WIDTH, HEIGHT)
    w.car = S.car
    w.seat = S.seat
    w:initialise()
    w:addToUIManager()
    w:setVisible(true)
    BridgeSeatPuppetWindow.instance = w
    return w
end

local function onContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    if playerNum ~= 0 then return end
    local S = BridgeSeatPuppet
    if S == nil or type(S.enabled) ~= "function" or not S.enabled() then return end
    if S.p == nil then return end
    if BridgeCar == nil or type(BridgeCar.isInside) ~= "function" or not BridgeCar.isInside() then return end
    if BridgeCar.car == nil then return end
    local red = getSpecificPlayer(playerNum)
    if red == nil then return end
    local inCar = false
    pcall(function() inCar = red:getVehicle() == BridgeCar.car end)
    if not inCar then
        local d = nil
        pcall(function()
            local dx = red:getX() - BridgeCar.car:getX()
            local dy = red:getY() - BridgeCar.car:getY()
            d = math.sqrt(dx * dx + dy * dy)
        end)
        if d == nil or d > 4 then return end
    end
    context:addOption(tr("SeatPuppetAdjust"), nil, function() BridgeSeatPuppetWindow.show() end)
end

Events.OnFillWorldObjectContextMenu.Add(onContextMenu)
