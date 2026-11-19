-- Chores settings and debug tab. Rows toggle policy; the Run column and
-- footer call BridgeChores.debug* so they use the same start path as the
-- automatic brain.

require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"

BridgeChoresTab = ISPanel:derive("BridgeChoresTab")

local PAD = 10
local ROW_PAD = 4
local GAP = 4
local MAX_LIST_H = 360
local RUN_W = 38
local RUN_MARGIN = 14

BridgeChoresTab.RUN_W = RUN_W

local DEBUG_BUTTONS = {
    { key = "reset", label = "ChoreDebugReset" },
    { key = "blacklist", label = "ChoreDebugBlacklist" },
    { key = "rescan", label = "ChoreDebugRescan" },
    { key = "cancel", label = "ChoreDebugCancel" },
}

local function bodyFont()
    if BridgeWindow ~= nil and type(BridgeWindow.uiFonts) == "function" then
        local font = BridgeWindow.uiFonts()
        if font ~= nil then return font end
    end
    return UIFont.Small
end

local function tr(key, a, b)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key, a, b) end
    local out = key
    pcall(function()
        if b ~= nil then out = getText("IGUI_NotAlone_" .. key, a, b)
        elseif a ~= nil then out = getText("IGUI_NotAlone_" .. key, a)
        else out = getText("IGUI_NotAlone_" .. key) end
    end)
    return out
end

local function fitText(font, text, maxW)
    text = tostring(text or "")
    if maxW <= 0 then return "" end
    local w = 0
    pcall(function() w = getTextManager():MeasureStringX(font, text) end)
    if w <= maxW then return text end
    local n = string.len(text)
    while n > 0 do
        local trial = string.sub(text, 1, n) .. "..."
        local tw = 0
        pcall(function() tw = getTextManager():MeasureStringX(font, trial) end)
        if tw <= maxW then return trial end
        n = n - 1
    end
    return "..."
end

function BridgeChoresTab.labelFor(id)
    local key = BridgeData ~= nil and BridgeData.CHORE_LABELS and BridgeData.CHORE_LABELS[id] or nil
    if key ~= nil then return tr(key) end
    return tostring(id)
end

local function hintLines(width)
    if BridgeWindow ~= nil and type(BridgeWindow.hintLines) == "function" then
        local who = ""
        if Bridge ~= nil and type(Bridge.companionName) == "function" then who = Bridge.companionName() end
        local lines, h = BridgeWindow.hintLines(width, "ChoresHint", who)
        return lines, h
    end
    return { tr("ChoresHint") }, getTextManager():getFontHeight(bodyFont()) + 4
end

local function debugMetrics(font)
    local fontH = getTextManager():getFontHeight(font)
    local lineH = fontH + 2
    local btnH = fontH + 8
    return lineH, btnH, GAP + lineH + GAP + btnH * 2 + GAP
end

function BridgeChoresTab.heightFor(width)
    local font = bodyFont()
    local rowH = math.max(getTextManager():getFontHeight(font) + ROW_PAD * 2, 20)
    local n = BridgeData ~= nil and BridgeData.CHORE_IDS and #BridgeData.CHORE_IDS or 0
    local listH = math.min(n * rowH + 4, MAX_LIST_H)
    local _, _, debugH = debugMetrics(font)
    local _, hh = hintLines(width)
    return PAD + hh + listH + debugH + PAD
end

BridgeChoresList = ISScrollingListBox:derive("BridgeChoresList")

function BridgeChoresList:new(x, y, width, height, font)
    local o = ISScrollingListBox:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.2 }
    o.drawBorder = true
    o.font = font or UIFont.Small
    o.fontHgt = getTextManager():getFontHeight(o.font)
    o.itemheight = math.max(o.fontHgt + ROW_PAD * 2, 20)
    return o
end

function BridgeChoresList:runZone()
    return self:getWidth() - RUN_W - RUN_MARGIN
end

function BridgeChoresList:doDrawItem(y, item, alt)
    if not item.height then item.height = self.itemheight end
    local box = self.fontHgt
    local by = y + (item.height - box) / 2
    self:drawRectBorder(6, by, box, box, 1, 0.6, 0.6, 0.6)
    if item.on then self:drawRect(8, by + 2, box - 4, box - 4, 1, 0.72, 0.86, 0.62) end
    local textX = 6 + box + 8
    local runX = self:runZone()
    local status = tostring(item.status or "")
    local statusW = 0
    if status ~= "" then pcall(function() statusW = getTextManager():MeasureStringX(self.font, status) end) end
    local statusX = runX - statusW - 6
    if statusX < textX then statusX = textX end
    local label = fitText(self.font, item.text or "", statusX - textX - 6)
    self:drawText(label, textX, y + (item.height - self.fontHgt) / 2, 1, 1, 1, 1, self.font)
    if status ~= "" then
        self:drawText(status, statusX, y + (item.height - self.fontHgt) / 2, 0.82, 0.82, 0.72, 1, self.font)
    end
    self:drawRectBorder(runX, by - 1, RUN_W, box + 2, 1, 0.55, 0.55, 0.55)
    local run = tr("ChoreDebugRun")
    local rw = 0
    pcall(function() rw = getTextManager():MeasureStringX(self.font, run) end)
    self:drawText(run, runX + (RUN_W - rw) / 2, y + (item.height - self.fontHgt) / 2, 0.85, 0.9, 0.75, 1, self.font)
    return y + item.height
end

function BridgeChoresList:onMouseDown(x, y)
    local row = self:rowAt(x, y)
    if row < 1 or row > #self.items then return end
    local item = self.items[row]
    self.selected = row
    if x >= self:runZone() then
        pcall(function() getSoundManager():playUISound("UIActivateButton") end)
        local res = "debug not loaded"
        if BridgeChores ~= nil and type(BridgeChores.debugForce) == "function" then
            res = BridgeChores.debugForce(item.id)
        end
        if self.owner ~= nil and type(self.owner.setDebug) == "function" then
            self.owner:setDebug(tostring(res))
        end
        if BridgeChores ~= nil and type(BridgeChores.status) == "function" then
            item.status = BridgeChores.status(item.id)
        end
        return
    end
    pcall(function() getSoundManager():playUISound("UIActivateButton") end)
    item.on = not item.on
    if Bridge.setChore ~= nil then Bridge.setChore(item.id, item.on) end
    if BridgeChores ~= nil and type(BridgeChores.status) == "function" then
        item.status = BridgeChores.status(item.id)
    end
end

function BridgeChoresTab:createChildren()
    ISPanel.createChildren(self)
    local font = bodyFont()
    self.font = font
    self.rowH = math.max(getTextManager():getFontHeight(font) + ROW_PAD * 2, 20)
    self.hint, self.hintH = hintLines(self.width)
    local n = BridgeData ~= nil and BridgeData.CHORE_IDS and #BridgeData.CHORE_IDS or 0
    local listH = math.min(n * self.rowH + 4, MAX_LIST_H)
    self.list = BridgeChoresList:new(PAD, PAD + self.hintH, self.width - PAD * 2, listH, font)
    self.list.owner = self
    self.list:initialise()
    self.list:instantiate()
    self:addChild(self.list)

    local _, btnH, _ = debugMetrics(font)
    self.debugY = PAD + self.hintH + listH + GAP
    self.debugLineH = getTextManager():getFontHeight(font) + 2
    self.btnH = btnH
    local bw = math.max(60, math.floor((self.width - PAD * 3) / 2))
    local by = self.debugY + self.debugLineH + GAP
    self.debugButtons = {}
    for i = 1, #DEBUG_BUTTONS do
        local spec = DEBUG_BUTTONS[i]
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = PAD + col * (bw + PAD)
        local y = by + row * (btnH + GAP)
        local btn = ISButton:new(x, y, bw, btnH, tr(spec.label), self, BridgeChoresTab["onDebug" .. spec.key])
        btn:initialise()
        btn:instantiate()
        btn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
        self:addChild(btn)
        self.debugButtons[#self.debugButtons + 1] = btn
    end
    self:refresh()
end

function BridgeChoresTab:refresh()
    if self.list == nil then return end
    local list = self.list
    list.items = {}
    list.count = 0
    list:setScrollHeight(0)
    local rec = Bridge ~= nil and Bridge.store or nil
    if BridgeData == nil or BridgeData.CHORE_IDS == nil then return end
    for i = 1, #BridgeData.CHORE_IDS do
        local id = BridgeData.CHORE_IDS[i]
        local label = BridgeChoresTab.labelFor(id)
        local on = BridgeData.choreOn(rec, id) == true
        local status = BridgeChores ~= nil and BridgeChores.status(id) or ""
        local item = list:addItem(label, nil)
        item.id = id
        item.text = label
        item.on = on
        item.status = status
        item.height = list.itemheight
    end
    list.selected = 1
    if self.debugResult == nil then self.debugResult = tr("ChoreDebugHint") end
    self.refreshAt = Bridge ~= nil and Bridge.tick or 0
end

function BridgeChoresTab:refreshStatuses()
    if self.list == nil or BridgeChores == nil or type(BridgeChores.status) ~= "function" then return end
    local rec = Bridge ~= nil and Bridge.store or nil
    for i = 1, #self.list.items do
        local item = self.list.items[i]
        item.status = BridgeChores.status(item.id)
        if BridgeData ~= nil then item.on = BridgeData.choreOn(rec, item.id) == true end
    end
    self.refreshAt = Bridge ~= nil and Bridge.tick or 0
end

function BridgeChoresTab:setDebug(text)
    self.debugResult = tostring(text or "")
    self:refreshStatuses()
end

function BridgeChoresTab:onDebugreset()
    local res = "debug not loaded"
    if BridgeChores ~= nil and type(BridgeChores.debugReset) == "function" then res = BridgeChores.debugReset("all") end
    self:setDebug(res)
end

function BridgeChoresTab:onDebugblacklist()
    local res = "debug not loaded"
    if BridgeChores ~= nil and type(BridgeChores.debugClearBlacklist) == "function" then res = BridgeChores.debugClearBlacklist() end
    self:setDebug(res)
end

function BridgeChoresTab:onDebugrescan()
    local res = "debug not loaded"
    if BridgeChores ~= nil and type(BridgeChores.debugRescan) == "function" then res = BridgeChores.debugRescan("all") end
    self:setDebug(res)
end

function BridgeChoresTab:onDebugcancel()
    local res = "debug not loaded"
    if BridgeChores ~= nil and type(BridgeChores.debugCancel) == "function" then res = BridgeChores.debugCancel() end
    self:setDebug(res)
end

function BridgeChoresTab:prerender()
    ISPanel.prerender(self)
    if Bridge == nil then return end
    if self.refreshAt == nil or (Bridge.tick - (self.refreshAt or 0)) >= 30 then
        self:refreshStatuses()
    end
end

function BridgeChoresTab:render()
    local y = PAD
    local font = self.font or bodyFont()
    local lines = self.hint or {}
    for i = 1, #lines do
        self:drawText(tostring(lines[i]), PAD, y, 0.75, 0.75, 0.75, 1, font)
        y = y + getTextManager():getFontHeight(font) + 2
    end
    if self.debugY ~= nil then
        self:drawText(fitText(font, self.debugResult or "", self.width - PAD * 2), PAD, self.debugY,
            0.82, 0.86, 0.72, 1, font)
    end
end

function BridgeChoresTab:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeChoresTab] loaded") end
