require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISModalDialog"
require "ISUI/ISWorldObjectContextMenu"

BridgeHome = BridgeHome or {}

local PAD = 10

-- Highlight palette: the saved home and a valid selection are blue; an invalid
-- selection stays red.
local HOME_R, HOME_G, HOME_B, HOME_A = 0.20, 0.50, 1.00, 0.30
local SEL_R, SEL_G, SEL_B, SEL_A = 0.20, 0.50, 1.00, 0.35
local BAD_R, BAD_G, BAD_B = 1.00, 0.10, 0.10

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeHome] " .. tostring(text)) end end

local function tr(key, a)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key, a) end
    local text = key
    pcall(function()
        if a ~= nil then text = getText("IGUI_NotAlone_" .. key, a) else text = getText("IGUI_NotAlone_" .. key) end
    end)
    return text
end


BridgeHome.HANDLE_TYPE = "BridgeHome"
BridgeHome.handle = nil
BridgeHome.handleKey = nil


local function zoneAvailable()
    return type(DesignationZone) == "table" and type(DesignationZone.new) == "function"
end


local function destroyHandle()
    local handle = BridgeHome.handle
    BridgeHome.handle = nil
    BridgeHome.handleKey = nil
    if handle == nil then return end
    pcall(function() DesignationZone.removeZone(handle, false) end)
end


function BridgeHome.syncHandle()
    local st = Bridge ~= nil and Bridge.store or nil
    local home = BridgeData ~= nil and BridgeData.homeOf(st) or nil
    local h = BridgeData ~= nil and BridgeData.cleanHome(home) or nil
    local key = nil
    if h ~= nil then key = string.format("%d:%d:%d:%d:%d", h.x, h.y, h.z, h.w, h.h) end
    if key == BridgeHome.handleKey then return end
    destroyHandle()
    if h == nil then return end
    if not zoneAvailable() then return end
    local ok, err = pcall(function()
        local name = tr("Home")
        local handle = DesignationZone.new(BridgeHome.HANDLE_TYPE, name,
            h.x, h.y, h.z, h.x + h.w - 1, h.y + h.h - 1, false)
        BridgeHome.handle = handle
        BridgeHome.handleKey = key
    end)
    if not ok then log("handle failed: " .. tostring(err)) end
end


function BridgeHome.get()
    if BridgeData == nil or Bridge == nil then return nil end
    return BridgeData.homeOf(Bridge.store)
end


function BridgeHome.contains(x, y, z)
    local h = BridgeHome.get()
    if h == nil or x == nil or y == nil or z == nil then return false end
    if math.floor(z) ~= h.z then return false end
    return x >= h.x and x <= (h.x + h.w - 1) and y >= h.y and y <= (h.y + h.h - 1)
end


function BridgeHome.center()
    local h = BridgeHome.get()
    if h == nil then return nil end
    return h.x + h.w / 2, h.y + h.h / 2, h.z
end


function BridgeHome.statusText()
    local h = BridgeHome.get()
    if h == nil then return tr("HomeNone") end
    local out = nil
    pcall(function() out = getText("IGUI_NotAlone_HomeStatus", h.x, h.y, h.z, h.w, h.h) end)
    if out == nil or out == "" or out == "IGUI_NotAlone_HomeStatus" then
        out = string.format("Home: %d, %d  z%d  %dx%d", h.x, h.y, h.z, h.w, h.h)
    end
    return out
end



BridgeHome.lockCount = 0
BridgeHome.lockPrev = nil

local function acquireLock()
    if BridgeHome.lockCount == 0 then
        BridgeHome.lockPrev = ISWorldObjectContextMenu.disableWorldMenu
        ISWorldObjectContextMenu.disableWorldMenu = true
    end
    BridgeHome.lockCount = BridgeHome.lockCount + 1
end

local function releaseLock()
    if BridgeHome.lockCount <= 0 then return end
    BridgeHome.lockCount = BridgeHome.lockCount - 1
    if BridgeHome.lockCount == 0 then
        ISWorldObjectContextMenu.disableWorldMenu = BridgeHome.lockPrev
        BridgeHome.lockPrev = nil
    end
end



local SelectUI = ISPanel:derive("BridgeHomeSelect")
BridgeHome.SelectUI = SelectUI

BridgeHome.select = nil

function SelectUI:pickSquare()
    local mx, my = getMouseX(), getMouseY()
    local x = math.floor(screenToIsoX(self.playerNum, mx, my, self.level))
    local y = math.floor(screenToIsoY(self.playerNum, mx, my, self.level))
    return getCell():getGridSquare(x, y, self.level), x, y
end

function SelectUI:bounds()
    if self.startX == nil or self.endX == nil then return nil end
    return { x1 = math.min(self.startX, self.endX), y1 = math.min(self.startY, self.endY),
             x2 = math.max(self.startX, self.endX), y2 = math.max(self.startY, self.endY), z = self.level }
end


function SelectUI:reason(b)
    if b == nil then return "HomeTooSmall" end
    local w = b.x2 - b.x1 + 1
    local h = b.y2 - b.y1 + 1
    if w < BridgeData.HOME_MIN or h < BridgeData.HOME_MIN then return "HomeTooSmall" end
    if w > BridgeData.HOME_MAX or h > BridgeData.HOME_MAX then return "HomeTooBig" end
    return nil
end

function SelectUI:valid(b)
    return self:reason(b) == nil
end

function SelectUI:close()
    if self.closed then return end
    self.closed = true
    self:setVisible(false)
    self:removeFromUIManager()
    if BridgeHome.select == self then BridgeHome.select = nil end
    releaseLock()
    pcall(function() self.playerObj:setSeeDesignationZone(self.prevSee) end)
end


function SelectUI:showReason(key)
    local modal = ISModalDialog:new(0, 0, 340, 120, tr(key), false, nil, nil)
    if modal == nil then return end
    modal:initialise()
    modal:addToUIManager()
    modal.moveWithMouse = true
end


function SelectUI:apply(rect)
    Bridge.setHome(rect)
    BridgeHome.syncHandle()
    self:close()
    pcall(function()
        if BridgeMenu ~= nil and BridgeMenu.isPresent() and BridgeMenu.inTalkRange() then
            Bridge.speak("HomeSet")
        end
    end)
end


function SelectUI:confirmReplace(rect)
    self.pending = rect
    local modal = ISModalDialog:new(0, 0, 340, 140, tr("HomeReplaceConfirm"), true, self, SelectUI.onReplaceDone)
    if modal == nil then return end
    modal:initialise()
    modal:addToUIManager()
    modal.moveWithMouse = true
end

function SelectUI:onReplaceDone(button)
    if button == nil or button.internal ~= "YES" then
        self.pending = nil
        return
    end
    local rect = self.pending
    self.pending = nil
    if rect ~= nil then self:apply(rect) end
end


function SelectUI:onMouseDownOutside(x, y)
    local sq, wx, wy = self:pickSquare()
    if sq == nil or not sq:getFloor() then return true end
    self.startX, self.startY = wx, wy
    self.endX, self.endY = wx, wy
    self.dragging = true
    return true
end

function SelectUI:onMouseMoveOutside(dx, dy)
    local sq, wx, wy = self:pickSquare()
    if self.dragging and sq ~= nil then
        self.endX, self.endY = wx, wy
    end
    return true
end

function SelectUI:onMouseUpOutside(x, y)
    if not self.dragging then return true end
    self.dragging = false
    local b = self:bounds()
    self.startX, self.startY, self.endX, self.endY = nil, nil, nil, nil
    if b == nil then return true end
    local reason = self:reason(b)
    if reason ~= nil then
        self:showReason(reason)
        return true
    end
    local rect = { x = b.x1, y = b.y1, z = b.z, w = b.x2 - b.x1 + 1, h = b.y2 - b.y1 + 1 }
    if BridgeHome.get() ~= nil then
        self:confirmReplace(rect)
        return true
    end
    self:apply(rect)
    return true
end

function SelectUI:onRightMouseDownOutside(x, y)
    self:close()
    return true
end

function SelectUI:prerender()
    if self.closed then return end
    local sq, wx, wy = self:pickSquare()
    local b = self:bounds()
    if b ~= nil then
        local ok = self:valid(b)
        addAreaHighlightForPlayer(self.playerNum, b.x1, b.y1, b.x2 + 1, b.y2 + 1, b.z,
            ok and SEL_R or BAD_R, ok and SEL_G or BAD_G, ok and SEL_B or BAD_B, SEL_A)
    elseif sq ~= nil then
        addAreaHighlightForPlayer(self.playerNum, wx, wy, wx + 1, wy + 1, self.level, SEL_R, SEL_G, SEL_B, 0.55)
    end
end


function SelectUI:new(playerObj)
    local o = ISPanel.new(self, -1000, -1000, 1, 1)
    o.playerObj = playerObj
    o.playerNum = playerObj:getPlayerNum()
    local sq = nil
    pcall(function() sq = playerObj:getCurrentSquare() end)
    o.level = sq ~= nil and sq:getZ() or playerObj:getZ()
    o.dragging = false
    o.closed = false
    o.background = false
    o.border = false
    o.prevSee = nil
    pcall(function()
        o.prevSee = playerObj:isSeeDesignationZone()
        playerObj:setSeeDesignationZone(true)
    end)
    return o
end


function BridgeHome.beginSelect(playerObj)
    if playerObj == nil then playerObj = BridgeData.owner() end
    if playerObj == nil then return nil end
    if BridgeHome.select ~= nil then BridgeHome.select:close() end
    local ui = SelectUI:new(playerObj)
    BridgeHome.select = ui
    acquireLock()
    ui:initialise()
    ui:addToUIManager()
    log("selection begun")
    return ui
end


function BridgeHome.requestSet(playerObj)
    if playerObj == nil then playerObj = BridgeData.owner() end
    return BridgeHome.beginSelect(playerObj)
end


local function clearDone(target, button)
    if button == nil or button.internal ~= "YES" then return end
    Bridge.clearHome()
    BridgeHome.syncHandle()
end


function BridgeHome.confirmClear(playerObj)
    local modal = ISModalDialog:new(0, 0, 340, 140, tr("HomeClearConfirm"), true, nil, clearDone)
    if modal == nil then return end
    modal:initialise()
    modal:addToUIManager()
    modal.moveWithMouse = true
end



BridgeHomeTab = ISPanel:derive("BridgeHomeTab")

function BridgeHomeTab.heightFor(width)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = fontS + 6
    local tickH = math.max(btnH, fontS) + (UI_BORDER_SPACING or 10)
    return PAD + fontS + PAD + btnH + PAD + btnH + PAD + tickH + PAD
end

function BridgeHomeTab:createChildren()
    ISPanel.createChildren(self)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = fontS + 6
    self.btnH = btnH
    self.statusY = PAD
    local y = PAD + fontS + PAD
    self.setBtn = ISButton:new(PAD, y, self.width - PAD * 2, btnH, tr("HomeSetHome"), self, BridgeHomeTab.onSet)
    self.setBtn:initialise()
    self.setBtn:instantiate()
    self.setBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.setBtn)
    y = y + btnH + PAD
    self.clearBtn = ISButton:new(PAD, y, self.width - PAD * 2, btnH, tr("HomeClear"), self, BridgeHomeTab.onClear)
    self.clearBtn:initialise()
    self.clearBtn:instantiate()
    self.clearBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.clearBtn)
    y = y + btnH + PAD
    self.resTick = ISTickBox:new(PAD, y, self.width - PAD * 2, btnH, "", self, BridgeHomeTab.onResourceTick, "homeResources")
    self.resTick:initialise()
    self.resTick:instantiate()
    self.resTick:addOption(tr("OptHomeResources"))
    self.resTick.tooltip = tr("OptHomeResourcesTip")
    self:addChild(self.resTick)
    self.resTickY = y
end

function BridgeHomeTab:onResourceTick(index, selected, key)
    if Bridge ~= nil and type(Bridge.setOption) == "function" then Bridge.setOption(key, selected == true) end
end

function BridgeHomeTab:onSet()
    BridgeHome.requestSet(BridgeData.owner())
end

function BridgeHomeTab:onClear()
    BridgeHome.confirmClear(BridgeData.owner())
end

function BridgeHomeTab:prerender()
    ISPanel.prerender(self)
    if Bridge == nil or Bridge.store == nil then return end
    local h = BridgeHome.get()
    local has = h ~= nil
    if self.clearBtn ~= nil and self.clearBtn.enable ~= has then self.clearBtn:setEnable(has) end
    if self.resTick ~= nil then
        local want = BridgeData.optionOf(Bridge.store, "homeResources")
        if self.resTick:isSelected(1) ~= want then self.resTick:setSelected(1, want) end
    end
    -- Draw the current home radius in-world while the Home tab is open.
    -- addAreaHighlightForPlayer is per-frame, so it clears itself when the tab
    -- is switched away or the window is closed.
    if h ~= nil then
        local pn = 0
        pcall(function()
            local p = BridgeData.owner()
            if p ~= nil then pn = p:getPlayerNum() end
        end)
        addAreaHighlightForPlayer(pn, h.x, h.y, h.x + h.w, h.y + h.h, h.z, HOME_R, HOME_G, HOME_B, HOME_A)
    end
end

function BridgeHomeTab:render()
    if Bridge == nil or Bridge.store == nil then return end
    self:drawText(BridgeHome.statusText(), PAD, self.statusY, 1, 1, 1, 1, UIFont.Small)
end

function BridgeHomeTab:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end



if not BridgeHome._eventsHooked then
    BridgeHome._eventsHooked = true

    Events.OnKeyStartPressed.Add(function(key)
        if BridgeHome.select == nil then return end
        local esc = key == Keyboard.KEY_ESCAPE
        pcall(function() if getCore():isKey("Main Menu", key) then esc = true end end)
        if not esc then return end
        if BridgeHome.select ~= nil then BridgeHome.select:close() end
        GameKeyboard.eatKeyPress(key)
    end)

    Events.OnTick.Add(function()
        local ui = BridgeHome.select
        if ui == nil then return end
        local sq = nil
        pcall(function() sq = ui.playerObj ~= nil and ui.playerObj:getCurrentSquare() or nil end)
        if sq == nil or sq:getZ() ~= ui.level then
            pcall(function() ui:close() end)
        end
    end)

    Events.OnGameStart.Add(function()
        pcall(BridgeHome.syncHandle)
    end)
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeHome] loaded") end
