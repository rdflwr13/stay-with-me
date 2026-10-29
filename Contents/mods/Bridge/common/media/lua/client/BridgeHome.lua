require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISModalDialog"
require "ISUI/ISWorldObjectContextMenu"

BridgeHome = BridgeHome or {}

local PAD = 10

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
BridgeHome.handles = {}
BridgeHome.handleKey = nil
BridgeHome.pendingAllFloors = false

local floorCache = {}
local includedCache = {}


local function zoneAvailable()
    return type(DesignationZone) == "table" and type(DesignationZone.new) == "function"
end


function BridgeHome.allFloorsOn()
    if BridgeData == nil or Bridge == nil then return false end
    return BridgeData.optionOf(Bridge.store, "homeAllFloors") == true
end


function BridgeHome.hasRange(h)
    if type(h) ~= "table" then return false end
    return type(h.z1) == "number" and type(h.z2) == "number"
end


function BridgeHome.allFloorsPending(h)
    if h == nil or not BridgeHome.allFloorsOn() then return false end
    if BridgeHome.pendingAllFloors == true then return true end
    return not BridgeHome.hasRange(h)
end


function BridgeHome.homeKey(h)
    if type(h) ~= "table" then return nil end
    return string.format("%d:%d:%d:%d:%d:%s:%s:%s", h.x, h.y, h.z, h.w, h.h,
        tostring(h.z1 or h.z), tostring(h.z2 or h.z), tostring(h.bld or ""))
end


function BridgeHome.invalidate()
    floorCache = {}
    includedCache = {}
end


local function destroyHandles()
    local list = BridgeHome.handles or {}
    BridgeHome.handles = {}
    BridgeHome.handleKey = nil
    for _, handle in pairs(list) do
        if handle ~= nil then pcall(function() DesignationZone.removeZone(handle, false) end) end
    end
end


function BridgeHome.syncHandle()
    local st = Bridge ~= nil and Bridge.store or nil
    local home = BridgeData ~= nil and BridgeData.homeOf(st) or nil
    local h = BridgeData ~= nil and BridgeData.cleanHome(home) or nil
    local all = BridgeHome.allFloorsOn()
    local key = nil
    if h ~= nil then key = BridgeHome.homeKey(h) .. (all and ":1" or ":0") end
    if key == BridgeHome.handleKey then return end
    destroyHandles()
    if h == nil then
        log("zones cleared: no home")
        return
    end
    BridgeHome.handleKey = key
    if not zoneAvailable() then
        log("zones skipped: DesignationZone unavailable")
        return
    end
    local floors = BridgeHome.includedFloors(h, all)
    local name = tr("Home")
    local made = {}
    for index = 1, #floors do
        local z = floors[index]
        local ok, err = pcall(function()
            local handle = DesignationZone.new(BridgeHome.HANDLE_TYPE, name,
                h.x, h.y, z, h.x + h.w - 1, h.y + h.h - 1, false)
            BridgeHome.handles[z] = handle
            made[#made + 1] = z
        end)
        if not ok then log("handle failed z" .. tostring(z) .. ": " .. tostring(err)) end
    end
    local z1, z2 = BridgeData.homeRange(h, all)
    log(string.format("zones home z%s..z%s all=%s floors=%s", tostring(z1), tostring(z2),
        all and "on" or "off", table.concat(made, ",")))
end


function BridgeHome.get()
    if BridgeData == nil or Bridge == nil then return nil end
    return BridgeData.homeOf(Bridge.store)
end


function BridgeHome.hasFloor(h, z)
    if type(h) ~= "table" or z == nil then return false end
    local key = string.format("%d:%d:%d:%d:%d:%d", h.x, h.y, h.z, h.w, h.h, math.floor(z))
    local hit = floorCache[key]
    if hit ~= nil then return hit end
    local cell = nil
    pcall(function() cell = getCell() end)
    if cell == nil then return false end
    local yes = false
    pcall(function()
        for x = h.x, h.x + h.w - 1 do
            if yes then return end
            for y = h.y, h.y + h.h - 1 do
                local sq = cell:getGridSquare(x, y, math.floor(z))
                if sq ~= nil and sq:getFloor() then yes = true return end
            end
        end
    end)
    floorCache[key] = yes
    return yes
end


function BridgeHome.includedFloors(h, allFloors)
    if type(h) ~= "table" then return {} end
    local key = BridgeHome.homeKey(h) .. (allFloors and ":1" or ":0")
    local hit = includedCache[key]
    if hit ~= nil then return hit end
    local z1, z2 = BridgeData.homeRange(h, allFloors)
    local out = {}
    if z1 ~= nil then
        for z = z1, z2 do
            if z == h.z or BridgeHome.hasFloor(h, z) then out[#out + 1] = z end
        end
    end
    includedCache[key] = out
    return out
end


function BridgeHome.windowFor(minZ, maxZ, selectedZ, cap)
    minZ = math.floor(tonumber(minZ) or 0)
    maxZ = math.floor(tonumber(maxZ) or minZ)
    selectedZ = math.floor(tonumber(selectedZ) or minZ)
    cap = math.floor(tonumber(cap) or BridgeData.HOME_MAX_FLOORS)
    if cap < 1 then cap = 1 end
    if maxZ < minZ then return selectedZ, selectedZ end
    local span = maxZ - minZ + 1
    if span <= cap then return minZ, maxZ end
    local low = selectedZ - math.floor((cap - 1) / 2)
    local high = low + cap - 1
    if low < minZ then
        low = minZ
        high = minZ + cap - 1
    end
    if high > maxZ then
        high = maxZ
        low = maxZ - cap + 1
    end
    return low, high
end


function BridgeHome.computeRange(h)
    if type(h) ~= "table" then return nil end
    local cell = nil
    pcall(function() cell = getCell() end)
    if cell == nil then
        log(string.format("range: cell not loaded for %d,%d z%d, deferring", h.x, h.y, h.z))
        return nil
    end

    local counts, order = {}, {}
    for x = h.x, h.x + h.w - 1 do
        for y = h.y, h.y + h.h - 1 do
            local sq = nil
            pcall(function() sq = cell:getGridSquare(x, y, h.z) end)
            if sq ~= nil then
                local b = nil
                local doors = rawget(_G, "BridgeDoors")
                if type(doors) == "table" and type(doors.buildingOf) == "function" then
                    local ok, found = pcall(doors.buildingOf, sq)
                    if ok then b = found end
                end
                if b == nil then pcall(function() b = sq:getBuilding() end) end
                if b ~= nil then
                    if counts[b] == nil then
                        counts[b] = 0
                        order[#order + 1] = b
                    end
                    counts[b] = counts[b] + 1
                end
            end
        end
    end

    local best, bestCount = nil, 0
    for index = 1, #order do
        local b = order[index]
        if (counts[b] or 0) > bestCount then
            best, bestCount = b, counts[b]
        end
    end

    local ownerBld = nil
    pcall(function()
        local red = BridgeData.owner()
        local sq = red ~= nil and red:getCurrentSquare() or nil
        if sq ~= nil and sq:getZ() == h.z
                and sq:getX() >= h.x and sq:getX() <= h.x + h.w - 1
                and sq:getY() >= h.y and sq:getY() <= h.y + h.h - 1 then
            ownerBld = sq:getBuilding()
        end
    end)
    if ownerBld ~= nil and counts[ownerBld] ~= nil then best = ownerBld end

    if best ~= nil then
        local def = nil
        pcall(function() def = best:getDef() end)
        if def ~= nil then
            local minZ, maxZ = nil, nil
            pcall(function() minZ, maxZ = def:getMinLevel(), def:getMaxLevel() end)
            if minZ ~= nil and maxZ ~= nil and h.z >= minZ and h.z <= maxZ then
                local z1, z2 = BridgeHome.windowFor(minZ, maxZ, h.z, BridgeData.HOME_MAX_FLOORS)
                local id = nil
                pcall(function() id = tostring(def:getIDString()) end)
                if id == nil or id == "" or id == "0" or id == "nil" then
                    id = nil
                    pcall(function() id = tostring(best:getID()) end)
                    if id == "0" or id == "nil" then id = nil end
                end
                log(string.format("range: building %s levels %s..%s -> z%d..z%d at z%d",
                    tostring(id), tostring(minZ), tostring(maxZ), z1, z2, h.z))
                return z1, z2, id
            end
            log(string.format("range: building levels %s..%s do not cover z%d, using floor scan",
                tostring(minZ), tostring(maxZ), h.z))
        else
            log("range: building without a definition, using floor scan")
        end
    else
        log("range: no building under the footprint, using floor scan")
    end

    local z1, z2 = h.z, h.z
    local up, down = true, true
    while (z2 - z1 + 1) < BridgeData.HOME_MAX_FLOORS and (up or down) do
        if up then
            if BridgeHome.hasFloor(h, z2 + 1) then z2 = z2 + 1 else up = false end
        end
        if (z2 - z1 + 1) < BridgeData.HOME_MAX_FLOORS and down then
            if BridgeHome.hasFloor(h, z1 - 1) then z1 = z1 - 1 else down = false end
        end
    end
    log(string.format("range: floor scan -> z%d..z%d (base z%d)", z1, z2, h.z))
    return z1, z2, nil
end


function BridgeHome.contains(x, y, z, margin)
    local h = BridgeHome.get()
    if h == nil or x == nil or y == nil or z == nil then return false end
    if not BridgeData.homeHas(h, x, y, z, margin, BridgeHome.allFloorsOn()) then return false end
    local sq = nil
    pcall(function()
        local cell = getCell()
        if cell ~= nil then sq = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z)) end
    end)
    return BridgeData.homeBuildingOk(h, sq)
end


function BridgeHome.center()
    local h = BridgeHome.get()
    if h == nil then return nil end
    return h.x + h.w / 2, h.y + h.h / 2, h.z
end


function BridgeHome.statusText()
    local h = BridgeHome.get()
    if h == nil then return tr("HomeNone") end
    local all = BridgeHome.allFloorsOn()
    local z1, z2 = BridgeData.homeRange(h, all)
    if BridgeHome.allFloorsPending(h) then
        local out = nil
        pcall(function() out = getText("IGUI_NotAlone_HomeAllFloorsPending") end)
        if out == nil or out == "" or out == "IGUI_NotAlone_HomeAllFloorsPending" then
            out = "All floors pending: reset the home to include every floor"
        end
        return out .. "  " .. string.format("%d, %d  z%d  %dx%d", h.x, h.y, h.z, h.w, h.h)
    end
    if all and z2 ~= nil and z2 > z1 then
        local out = nil
        pcall(function() out = getText("IGUI_NotAlone_HomeStatusRange", h.x, h.y, z1, z2, h.w, h.h) end)
        if out == nil or out == "" or out == "IGUI_NotAlone_HomeStatusRange" then
            out = string.format("Home: %d, %d  z%d..z%d  %dx%d", h.x, h.y, z1, z2, h.w, h.h)
        end
        return out
    end
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


function BridgeHome.onAllFloorsChanged(selected)
    BridgeHome.invalidate()
    BridgeHome.pendingAllFloors = false
    log("all floors " .. (selected == true and "on" or "off"))
    if selected ~= true then
        BridgeHome.syncHandle()
        return true
    end
    local h = BridgeHome.get()
    if h == nil then
        BridgeHome.syncHandle()
        return true
    end
    local stored = BridgeData.cleanHome(h) or h
    local wide = type(stored.z1) == "number" and type(stored.z2) == "number" and stored.z2 > stored.z1
    if not wide then
        local z1, z2, bld = BridgeHome.computeRange(stored)
        local clean = nil
        if z1 ~= nil then
            clean = BridgeData.cleanHome({ x = stored.x, y = stored.y, z = stored.z,
                w = stored.w, h = stored.h, z1 = z1, z2 = z2, bld = bld })
        end
        if clean ~= nil and Bridge ~= nil and type(Bridge.saveHome) == "function" then
            log(string.format("all floors: range z%s..z%s bld=%s", tostring(z1), tostring(z2), tostring(bld)))
            Bridge.saveHome(clean)
        else
            log("all floors: no usable range, pending")
            BridgeHome.pendingAllFloors = true
        end
    end
    BridgeHome.syncHandle()
    return true
end


function BridgeHome.selftest()
    local fails, ran = {}, 0
    local function check(name, condition)
        ran = ran + 1
        if not condition then fails[#fails + 1] = name end
    end

    local z1, z2 = BridgeHome.windowFor(-1, 2, 0, 6)
    check("basement window start", z1 == -1)
    check("basement window end", z2 == 2)

    z1, z2 = BridgeHome.windowFor(0, 5, 0, 6)
    check("six floor window", z1 == 0 and z2 == 5)

    z1, z2 = BridgeHome.windowFor(0, 9, 0, 6)
    check("bottom edge clipped", z1 == 0 and z2 == 5)
    z1, z2 = BridgeHome.windowFor(0, 9, 9, 6)
    check("top edge clipped", z1 == 4 and z2 == 9)
    z1, z2 = BridgeHome.windowFor(0, 9, 4, 6)
    check("selected inside window", z1 <= 4 and z2 >= 4 and (z2 - z1 + 1) == 6)

    local old = BridgeData.cleanHome({ x = 1, y = 2, z = 3, w = 12, h = 12 })
    check("old five field home", old ~= nil and old.z1 == nil and old.z2 == nil)
    check("has range false", BridgeHome.hasRange({ x = 1, y = 2, z = 3, w = 12, h = 12 }) == false)
    check("has range true", BridgeHome.hasRange({ x = 1, y = 2, z = 0, w = 12, h = 12, z1 = 0, z2 = 1 }) == true)

    local range = BridgeData.cleanHome({ x = 1, y = 2, z = 0, w = 12, h = 12, z1 = -1, z2 = 2 })
    check("range accepted", range ~= nil and range.z1 == -1 and range.z2 == 2)
    check("base outside range rejected",
        BridgeData.cleanHome({ x = 1, y = 2, z = 5, w = 12, h = 12, z1 = 0, z2 = 2 }) == nil)
    check("span over six rejected",
        BridgeData.cleanHome({ x = 1, y = 2, z = 0, w = 12, h = 12, z1 = -3, z2 = 3 }) == nil)
    check("one range field rejected",
        BridgeData.cleanHome({ x = 1, y = 2, z = 0, w = 12, h = 12, z1 = 0 }) == nil)

    local home = { x = 10, y = 10, z = 0, w = 4, h = 4, z1 = -1, z2 = 2 }
    check("off base floor", BridgeData.homeHas(home, 10, 10, 0, 0, false) == true)
    check("off other floor", BridgeData.homeHas(home, 10, 10, 1, 0, false) == false)
    check("on other floor", BridgeData.homeHas(home, 10, 10, 1, 0, true) == true)
    check("on outside range", BridgeData.homeHas(home, 10, 10, 3, 0, true) == false)
    check("margin edge", BridgeData.homeHas(home, 14, 10, 0, 1, false) == true)
    check("margin outside", BridgeData.homeHas(home, 15, 10, 0, 1, false) == false)

    if #fails == 0 then return string.format("homeselftest PASS (%d checks)", ran) end
    return string.format("homeselftest FAIL (%d of %d): %s", #fails, ran, table.concat(fails, "; "))
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

local function clearMarksDone(target, button)
    if button == nil or button.internal ~= "YES" then return end
    if BridgeDeposit ~= nil and type(BridgeDeposit.clearMarks) == "function" then BridgeDeposit.clearMarks() end
end

function BridgeHome.confirmClearMarks()
    local modal = ISModalDialog:new(0, 0, 340, 140, tr("ClearMarksConfirm"), true, nil, clearMarksDone)
    if modal == nil then return end
    modal:initialise()
    modal:addToUIManager()
    modal.moveWithMouse = true
end



BridgeHomeTab = ISPanel:derive("BridgeHomeTab")

function BridgeHomeTab.heightFor(width)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = fontS + 6
    local headerH = fontS + 4
    local _, hintH = BridgeWindow.hintLines(width, "HomeHint", Bridge.companionName())
    return PAD + hintH
        + headerH + fontS + PAD
        + btnH + PAD + PAD
        + headerH
        + fontS + 2
        + btnH + PAD
        + btnH + PAD + PAD
        + headerH
        + btnH * 3 + 4
        + PAD
end

function BridgeHomeTab:createChildren()
    ISPanel.createChildren(self)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = fontS + 6
    local headerH = fontS + 4
    self.btnH = btnH
    self.headerH = headerH
    self.hintLines, self.hintH = BridgeWindow.hintLines(self.width, "HomeHint", Bridge.companionName())
    local y = PAD + self.hintH
    self.zoneHeaderY = y
    self.statusY = y + headerH
    y = self.statusY + fontS + PAD
    local half = math.max(40, math.floor((self.width - PAD * 3) / 2))
    self.setBtn = ISButton:new(PAD, y, half, btnH, tr("HomeSetHome"), self, BridgeHomeTab.onSet)
    self.setBtn:initialise()
    self.setBtn:instantiate()
    self.setBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.setBtn)
    self.clearBtn = ISButton:new(PAD + half + PAD, y, half, btnH, tr("HomeClear"), self, BridgeHomeTab.onClear)
    self.clearBtn:initialise()
    self.clearBtn:instantiate()
    self.clearBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.clearBtn)
    y = y + btnH + PAD + PAD
    self.storageHeaderY = y
    y = y + headerH
    self.markedY = y
    y = y + fontS + 2
    self.markAllBtn = ISButton:new(PAD, y, self.width - PAD * 2, btnH, tr("MarkAllHome"), self, BridgeHomeTab.onMarkAll)
    self.markAllBtn:initialise()
    self.markAllBtn:instantiate()
    self.markAllBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self.markAllBtn.tooltip = tr("MarkAllHomeTip")
    self:addChild(self.markAllBtn)
    y = y + btnH + PAD
    self.clearMarksBtn = ISButton:new(PAD, y, self.width - PAD * 2, btnH, tr("ClearMarks"), self, BridgeHomeTab.onClearMarks)
    self.clearMarksBtn:initialise()
    self.clearMarksBtn:instantiate()
    self.clearMarksBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self.clearMarksBtn.tooltip = tr("ClearMarksTip")
    self:addChild(self.clearMarksBtn)
    y = y + btnH + PAD + PAD
    self.behaviorHeaderY = y
    y = y + headerH
    self.resTick = ISTickBox:new(PAD, y, self.width - PAD * 2, btnH, "", self, BridgeHomeTab.onResourceTick, "homeResources")
    self.resTick:initialise()
    self.resTick:instantiate()
    self.resTick:addOption(tr("OptHomeResources"))
    self.resTick.tooltip = tr("OptHomeResourcesTip")
    self:addChild(self.resTick)
    self.resTickY = y
    y = y + btnH + 2
    self.ammoTick = ISTickBox:new(PAD, y, self.width - PAD * 2, btnH, "", self, BridgeHomeTab.onAmmoTick, "homeAmmo")
    self.ammoTick:initialise()
    self.ammoTick:instantiate()
    self.ammoTick:addOption(tr("OptHomeAmmo"))
    self.ammoTick.tooltip = tr("OptHomeAmmoTip")
    self:addChild(self.ammoTick)
    self.ammoTickY = y
    y = y + btnH + 2
    self.allTick = ISTickBox:new(PAD, y, self.width - PAD * 2, btnH, "", self, BridgeHomeTab.onAllTick, "homeAllFloors")
    self.allTick:initialise()
    self.allTick:instantiate()
    self.allTick:addOption(tr("OptHomeAllFloors"))
    self.allTick.tooltip = tr("OptHomeAllFloorsTip")
    self:addChild(self.allTick)
    self.allTickY = y
end

function BridgeHomeTab:onResourceTick(index, selected, key)
    if Bridge ~= nil and type(Bridge.setOption) == "function" then Bridge.setOption(key, selected == true) end
end

function BridgeHomeTab:onAmmoTick(index, selected, key)
    if Bridge ~= nil and type(Bridge.setOption) == "function" then Bridge.setOption(key, selected == true) end
end

function BridgeHomeTab:onAllTick(index, selected, key)
    if Bridge ~= nil and type(Bridge.setOption) == "function" then Bridge.setOption(key, selected == true) end
    pcall(BridgeHome.onAllFloorsChanged, selected == true)
end

function BridgeHomeTab:onSet()
    BridgeHome.requestSet(BridgeData.owner())
end

function BridgeHomeTab:onClear()
    BridgeHome.confirmClear(BridgeData.owner())
end

function BridgeHomeTab:onMarkAll()
    if BridgeDeposit ~= nil and type(BridgeDeposit.seedMarks) == "function" then BridgeDeposit.seedMarks() end
end

function BridgeHomeTab:onClearMarks()
    BridgeHome.confirmClearMarks()
end

function BridgeHomeTab:prerender()
    ISPanel.prerender(self)
    if Bridge == nil or Bridge.store == nil then return end
    local h = BridgeHome.get()
    local has = h ~= nil
    if self.clearBtn ~= nil and self.clearBtn.enable ~= has then self.clearBtn:setEnable(has) end
    local marked = 0
    if BridgeDeposit ~= nil and type(BridgeDeposit.markedCount) == "function" then marked = BridgeDeposit.markedCount() end
    if self.markAllBtn ~= nil then
        local canMark = has
        if BridgeDeposit ~= nil and type(BridgeDeposit.homeHere) == "function" then canMark = has and BridgeDeposit.homeHere() end
        if self.markAllBtn.enable ~= canMark then self.markAllBtn:setEnable(canMark) end
    end
    if self.clearMarksBtn ~= nil then
        local canClear = marked > 0
        if self.clearMarksBtn.enable ~= canClear then self.clearMarksBtn:setEnable(canClear) end
    end
    if self.resTick ~= nil then
        local want = BridgeData.optionOf(Bridge.store, "homeResources")
        if self.resTick:isSelected(1) ~= want then self.resTick:setSelected(1, want) end
    end
    if self.ammoTick ~= nil then
        local want = BridgeData.optionOf(Bridge.store, "homeAmmo")
        if self.ammoTick:isSelected(1) ~= want then self.ammoTick:setSelected(1, want) end
    end
    if self.allTick ~= nil then
        local want = BridgeData.optionOf(Bridge.store, "homeAllFloors")
        if self.allTick:isSelected(1) ~= want then self.allTick:setSelected(1, want) end
    end
    if h ~= nil then
        local pn = 0
        pcall(function()
            local p = BridgeData.owner()
            if p ~= nil then pn = p:getPlayerNum() end
        end)
        local floors = BridgeHome.includedFloors(h, BridgeHome.allFloorsOn())
        for index = 1, #floors do
            addAreaHighlightForPlayer(pn, h.x, h.y, h.x + h.w, h.y + h.h, floors[index],
                HOME_R, HOME_G, HOME_B, HOME_A)
        end
    end
end

function BridgeHomeTab:render()
    if Bridge == nil or Bridge.store == nil then return end
    local y = PAD
    for _, line in ipairs(self.hintLines or {}) do
        self:drawText(line, PAD, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
        y = y + getTextManager():getFontHeight(UIFont.Small) + 2
    end
    self:drawText(tr("HomeZoneSection"), PAD, self.zoneHeaderY, 0.7, 0.7, 0.7, 1, UIFont.Small)
    self:drawText(BridgeHome.statusText(), PAD, self.statusY, 1, 1, 1, 1, UIFont.Small)
    self:drawText(tr("HomeStorageSection"), PAD, self.storageHeaderY, 0.7, 0.7, 0.7, 1, UIFont.Small)
    local marked = 0
    if BridgeDeposit ~= nil and type(BridgeDeposit.markedCount) == "function" then marked = BridgeDeposit.markedCount() end
    self:drawText(tr("MarkedCount", marked), PAD, self.markedY, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText(tr("HomeBehaviorSection"), PAD, self.behaviorHeaderY, 0.7, 0.7, 0.7, 1, UIFont.Small)
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

