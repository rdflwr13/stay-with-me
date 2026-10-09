require "ISUI/ISPanel"
require "ISUI/ISWorldObjectContextMenu"

BridgeWorkSelect = BridgeWorkSelect or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeWorkSelect] " .. tostring(text)) end end

local UI = ISPanel:derive("BridgeWorkSelectUI")
BridgeWorkSelect.UI = UI

BridgeWorkSelect.active = nil
BridgeWorkSelect.lockCount = 0
BridgeWorkSelect.lockPrev = nil
BridgeWorkSelect.MAX_SIDE = 40
BridgeWorkSelect.MAX_TREES = 80
BridgeWorkSelect.MAX_STAINS = 80

local function acquireLock()
    if BridgeWorkSelect.lockCount == 0 then
        BridgeWorkSelect.lockPrev = ISWorldObjectContextMenu.disableWorldMenu
        ISWorldObjectContextMenu.disableWorldMenu = true
    end
    BridgeWorkSelect.lockCount = BridgeWorkSelect.lockCount + 1
end

local function releaseLock()
    if BridgeWorkSelect.lockCount <= 0 then return end
    BridgeWorkSelect.lockCount = BridgeWorkSelect.lockCount - 1
    if BridgeWorkSelect.lockCount == 0 then
        ISWorldObjectContextMenu.disableWorldMenu = BridgeWorkSelect.lockPrev
        BridgeWorkSelect.lockPrev = nil
    end
end

function UI:pickSquare()
    local mx, my = getMouseX(), getMouseY()
    local x = math.floor(screenToIsoX(self.playerNum, mx, my, self.level))
    local y = math.floor(screenToIsoY(self.playerNum, mx, my, self.level))
    return getCell():getGridSquare(x, y, self.level), x, y
end

function UI:bounds()
    if self.startX == nil or self.endX == nil then return nil end
    return { x1 = math.min(self.startX, self.endX), y1 = math.min(self.startY, self.endY),
             x2 = math.max(self.startX, self.endX), y2 = math.max(self.startY, self.endY), z = self.level }
end



function UI:countTargets(b)
    local key = b.x1 .. ":" .. b.y1 .. ":" .. b.x2 .. ":" .. b.y2 .. ":" .. b.z
    if self.countKey == key then return self.count or 0 end
    local def = BridgeWorkSelect.kinds[self.kind] or BridgeWorkSelect.kinds.chopTree
    local n = 0
    pcall(function() n = #def.collect(b) end)
    self.countKey = key
    self.count = n
    return n
end

function UI:valid(b)
    if b == nil then return false end
    local w = b.x2 - b.x1 + 1
    local h = b.y2 - b.y1 + 1
    if w > BridgeWorkSelect.MAX_SIDE or h > BridgeWorkSelect.MAX_SIDE then return false end
    local def = BridgeWorkSelect.kinds[self.kind] or BridgeWorkSelect.kinds.chopTree


    if w * h <= def.max then return true end


    return self:countTargets(b) <= def.max
end

function UI:close()
    if self.closed then return end
    self.closed = true
    self:setVisible(false)
    self:removeFromUIManager()
    if BridgeWorkSelect.active == self then BridgeWorkSelect.active = nil end
    releaseLock()
end

function UI:start(b)
    local def = BridgeWorkSelect.kinds[self.kind] or BridgeWorkSelect.kinds.chopTree
    local targets = def.collect(b)
    self:close()
    if #targets == 0 then
        if Bridge ~= nil then Bridge.speak(def.noneSay) end
        return
    end
    if #targets > def.max then
        if Bridge ~= nil then Bridge.speak("JobTooBig") end
        return
    end
    BridgeWorkSelect.sortTargets(targets)
    local res = BridgeTask.start(self.kind, targets)
    log("area job " .. tostring(res) .. " kind=" .. tostring(self.kind) .. " targets=" .. tostring(#targets))
end

function UI:onMouseDownOutside(x, y)
    local sq, wx, wy = self:pickSquare()
    if sq == nil or not sq:getFloor() then return true end
    self.startX, self.startY = wx, wy
    self.endX, self.endY = wx, wy
    self.dragging = true
    return true
end

function UI:onMouseMoveOutside(dx, dy)
    local sq, wx, wy = self:pickSquare()
    if self.dragging and sq ~= nil then
        self.endX, self.endY = wx, wy
    end
    return true
end

function UI:onMouseUpOutside(x, y)
    if not self.dragging then return true end
    self.dragging = false
    local b = self:bounds()
    self.startX, self.startY, self.endX, self.endY = nil, nil, nil, nil
    if not self:valid(b) then
        if Bridge ~= nil then Bridge.speak("JobTooBig") end
        self:close()
        return true
    end
    self:start(b)
    return true
end

function UI:onRightMouseDownOutside(x, y)
    self:close()
    return true
end

function UI:prerender()
    if self.closed then return end
    local sq, wx, wy = self:pickSquare()
    local b = self:bounds()
    if b ~= nil then
        local ok = self:valid(b)
        addAreaHighlightForPlayer(self.playerNum, b.x1, b.y1, b.x2 + 1, b.y2 + 1, b.z,
            ok and 0.1 or 1.0, ok and 1.0 or 0.1, 0.1, 0.35)
    elseif sq ~= nil then
        addAreaHighlightForPlayer(self.playerNum, wx, wy, wx + 1, wy + 1, self.level, 0.1, 1.0, 0.1, 0.55)
    end
end

function UI:new(playerObj, kind)
    local o = ISPanel.new(self, -1000, -1000, 1, 1)
    o.playerObj = playerObj
    o.kind = kind or "chopTree"
    o.playerNum = playerObj:getPlayerNum()
    o.level = playerObj:getCurrentSquare():getZ()
    o.dragging = false
    o.closed = false
    o.background = false
    o.border = false
    return o
end

function BridgeWorkSelect.treesIn(b)
    local list = {}
    if b == nil then return list end
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            local sq = getCell():getGridSquare(x, y, b.z)
            if sq ~= nil then
                local t = nil
                pcall(function() t = sq:getTree() end)
                if t ~= nil and t:getObjectIndex() >= 0 then
                    list[#list + 1] = { x = x, y = y, z = b.z }
                end
            end
        end
    end
    return list
end

function BridgeWorkSelect.stainsIn(b)
    local list = {}
    if b == nil then return list end
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            local sq = getCell():getGridSquare(x, y, b.z)
            if sq ~= nil then
                local have = false



                if BridgeClean ~= nil and BridgeClean.squareCleanKind ~= nil then
                    pcall(function() have = BridgeClean.squareCleanKind(sq) ~= nil end)
                elseif BridgeTask ~= nil and BridgeTask.squareCleanKind ~= nil then
                    pcall(function() have = BridgeTask.squareCleanKind(sq) ~= nil end)
                end
                if have then list[#list + 1] = { x = x, y = y, z = b.z } end
            end
        end
    end
    return list
end


BridgeWorkSelect.kinds = {
    chopTree = {
        collect = function(b) return BridgeWorkSelect.treesIn(b) end,
        max = BridgeWorkSelect.MAX_TREES,
        noneSay = "JobNoTree",
    },
    cleanUp = {
        collect = function(b) return BridgeWorkSelect.stainsIn(b) end,
        max = BridgeWorkSelect.MAX_STAINS,
        noneSay = "JobNoStains",
    },
}

function BridgeWorkSelect.sortTargets(targets)
    local ox, oy = 0, 0
    pcall(function()
        local b = Bridge ~= nil and Bridge.body or nil
        if b ~= nil then
            ox, oy = b:getX(), b:getY()
        else
            local red = BridgeData.owner()
            if red ~= nil then ox, oy = red:getX(), red:getY() end
        end
    end)
    table.sort(targets, function(a, c)
        return (a.x - ox) ^ 2 + (a.y - oy) ^ 2 < (c.x - ox) ^ 2 + (c.y - oy) ^ 2
    end)
end

function BridgeWorkSelect.begin(playerObj, kind)
    if playerObj == nil then return nil end
    kind = kind or "chopTree"
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 then return nil end
    if kind == "chopTree" and BridgeTask.TREECUTTING_ENABLED ~= 1 then return nil end
    if kind == "cleanUp" and BridgeTask.CLEANING_ENABLED ~= 1 then return nil end
    if BridgeWorkSelect.active ~= nil then BridgeWorkSelect.active:close() end
    local ui = UI:new(playerObj, kind)
    BridgeWorkSelect.active = ui
    acquireLock()
    ui:initialise()
    ui:addToUIManager()
    log("selection begun")
    return ui
end

Events.OnKeyStartPressed.Add(function(key)
    if BridgeWorkSelect.lockCount == 0 then return end
    local esc = key == Keyboard.KEY_ESCAPE
    pcall(function() if getCore():isKey("Main Menu", key) then esc = true end end)
    if not esc then return end
    if BridgeWorkSelect.active ~= nil then BridgeWorkSelect.active:close() end
    GameKeyboard.eatKeyPress(key)
end)

Events.OnTick.Add(function()
    local ui = BridgeWorkSelect.active
    if ui == nil then return end
    local sq = nil
    pcall(function() sq = ui.playerObj ~= nil and ui.playerObj:getCurrentSquare() or nil end)
    if sq == nil or sq:getZ() ~= ui.level or not Bridge.alive() then
        ui:close()
    end
end)

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeWorkSelect] loaded") end
