require "ISUI/ISScrollingListBox"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"

local PAD = 10

local FONT_BODY, FONT_HEAD, FONT_S, FONT_M = UIFont.Small, UIFont.Medium, 0, 0

local function uiFonts()
    FONT_BODY, FONT_HEAD = UIFont.Small, UIFont.Medium
    FONT_S = getTextManager():getFontHeight(FONT_BODY)
    FONT_M = getTextManager():getFontHeight(FONT_HEAD)
    if BridgeWindow ~= nil and type(BridgeWindow.uiFonts) == "function" then
        local body, head, smallH, mediumH = BridgeWindow.uiFonts()
        FONT_BODY = body or FONT_BODY
        FONT_HEAD = head or FONT_HEAD
        FONT_S = smallH or FONT_S
        FONT_M = mediumH or FONT_M
    end
    return FONT_BODY, FONT_HEAD, FONT_S, FONT_M
end

local function tr(key, a)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key, a) end
    local text = key
    pcall(function()
        if a ~= nil then text = getText("IGUI_NotAlone_" .. key, a) else text = getText("IGUI_NotAlone_" .. key) end
    end)
    return text
end

local function wrapText(font, text, maxW)
    local lines, line = {}, ""
    for word in string.gmatch(tostring(text or ""), "%S+") do
        local trial = (line == "") and word or (line .. " " .. word)
        if line ~= "" and getTextManager():MeasureStringX(font, trial) > maxW then
            lines[#lines + 1] = line
            line = word
        else
            line = trial
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    if #lines == 0 then lines[1] = tostring(text or "") end
    return lines
end


BridgeOrderList = ISScrollingListBox:derive("BridgeOrderList")

function BridgeOrderList:new(x, y, width, height)
    uiFonts()
    local o = ISScrollingListBox:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.2 }
    o.drawBorder = true
    o.font = FONT_BODY
    o.fontHgt = FONT_S
    o.itemPadY = 5
    o.tickSize = o.fontHgt
    o.boxSize = o.fontHgt
    o.itemheight = o.fontHgt + o.itemPadY * 2
    o.dragTexture = getTexture("media/ui/dragModIcon.png")
    o.tickTexture = getTexture("media/ui/inventoryPanes/Tickbox_Tick.png")
    o.dragItem = nil
    return o
end

function BridgeOrderList:tickX()
    return 8
end

function BridgeOrderList:dragX()
    return self:tickX() + self.tickSize + 8
end

function BridgeOrderList:textX()
    return self:dragX() + self.boxSize + 8
end

function BridgeOrderList:onMouseDown(x, y)
    if #self.items == 0 then return end
    local row = self:rowAt(x, y)
    if row < 1 or row > #self.items then return end
    self.selected = row
    if self.mouseOverTick == self.items[row] then
        if type(self.onToggle) == "function" then self.onToggle(self.items[row]) end
        return
    end
    if self.mouseOverDragIcon then
        self.dragItem = self.items[row]
        getSoundManager():playUISound("UISelectListItem")
    end
end

function BridgeOrderList:onMouseUp(x, y)
    ISScrollingListBox.onMouseUp(self, x, y)
    local item = self.dragItem
    self.dragItem = nil
    if item == nil then return end
    local row = self:rowAt(x, y)
    if row < 1 or row > #self.items then return end
    local moved = {}
    for i, v in ipairs(self.items) do
        if i == row then moved[#moved + 1] = item end
        if v ~= item then moved[#moved + 1] = v end
    end
    self.items = moved
    for i, v in ipairs(self.items) do
        v.index = i
        if v == item then self.selected = i end
    end
    if type(self.onReorder) == "function" then self.onReorder() end
end

function BridgeOrderList:onMouseUpOutside(x, y)
    ISScrollingListBox.onMouseUpOutside(self, x, y)
    self.dragItem = nil
end

function BridgeOrderList:prerender()
    self.mouseOverDragIcon = nil
    self.mouseOverTick = nil
    ISScrollingListBox.prerender(self)
end

function BridgeOrderList:doDrawItem(y, item, alt)
    if not item.height then item.height = self.itemheight end
    if item.height <= 0 then return y + item.height end
    if self.dragItem == item then
        self:drawRect(0, y, self:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
    elseif self.selected == item.index then
        self:drawSelection(0, y, self:getWidth(), item.height - 1)
    elseif self.mouseoverselected == item.index and self:isMouseOver() and not self:isMouseOverScrollBar() then
        self:drawMouseOverHighlight(0, y, self:getWidth(), item.height - 1)
    end
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    local tick = self.tickSize or 16
    local tickX = self:tickX()
    local tickY = y + (item.height - tick) / 2
    self:drawRectBorder(tickX, tickY, tick, tick, 0.8, 1, 1, 1)
    if item.on == true and self.tickTexture ~= nil then
        local mark = tick - 4
        local tr, tg, tb = 1, 1, 1
        pcall(function()
            local c = getCore():getGoodHighlitedColor()
            tr, tg, tb = c:getR(), c:getG(), c:getB()
        end)
        self:drawTextureScaled(self.tickTexture, tickX + 2, tickY + 2, mark, mark, 1, tr, tg, tb)
    end
    local dragX = self:dragX()
    local box = self.boxSize
    local shift = (item.height - box) / 2
    if self.dragTexture ~= nil then
        self:drawTextureScaled(self.dragTexture, dragX, y + shift, box, box, 1, 1, 1, 1)
    end
    if self.mouseoverselected == item.index and self:isMouseOver() then
        local mx, my = self:getMouseX(), self:getMouseY()
        if mx >= tickX and mx <= tickX + tick and my >= tickY and my <= tickY + tick then
            self.mouseOverTick = item
        end
        if mx >= dragX and mx <= dragX + box and my >= y + shift and my <= y + shift + box then
            self.mouseOverDragIcon = item
        end
    end

    local textColor = item.textColor or self.textColor
    local cr, cg, cb, ca = textColor.r, textColor.g, textColor.b, textColor.a
    if item.on ~= true then cr, cg, cb, ca = 0.45, 0.45, 0.45, 1 end
    local ty = y + (item.height - self.fontHgt) / 2
    self:drawText(item.text, self:textX(), ty, cr, cg, cb, ca, self.font)
    return y + item.height
end

function BridgeOrderList:render()
    ISScrollingListBox.render(self)
    local item = self.dragItem
    if item == nil then return end
    if not item.height then item.height = self.itemheight end
    local y = self:getMouseY()
    local y0 = 0
    for _, v in ipairs(self.items) do
        if not v.height then v.height = self.itemheight end
        if y >= y0 and y < y0 + v.height / 2 and v ~= item then
            self:drawRect(0, y0 - v.height / 8, self:getWidth(), v.height / 4, 0.5, 1, 1, 1)
            break
        end
        y0 = y0 + v.height
    end
    if y >= y0 then
        self:drawRect(0, y0 - item.height / 8, self:getWidth(), item.height / 4, 0.5, 1, 1, 1)
    end
    local gy = y - item.height / 2
    self:drawRect(0, gy, self:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
    self:drawRectBorder(0, gy, self:getWidth(), item.height, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local box = self.boxSize
    local shift = (item.height - box) / 2
    if self.dragTexture ~= nil then
        self:drawTextureScaled(self.dragTexture, self:dragX(), shift + gy, box, box, 1, 1, 1, 1)
    end
    self:drawText(item.text, self:textX(), gy + (item.height - self.fontHgt) / 2, 0.9, 0.9, 0.9, 0.9, self.font)
end


BridgeOrder = ISPanel:derive("BridgeOrder")

local function orderMode()
    if BridgeWindow ~= nil and BridgeWindow.orderMode == "work" then return "work" end
    return "menu"
end

function BridgeOrder.heightFor(width)
    uiFonts()
    local fontS = FONT_S
    local btnH = fontS + 6
    local gap = PAD / 2
    local kind = orderMode()
    local who = "Rin"
    pcall(function() if Bridge ~= nil and Bridge.companionName ~= nil then who = Bridge.companionName() end end)
    local hintKey = kind == "work" and "MenuOrderHintWork" or "MenuOrderHint"
    local lines = wrapText(FONT_BODY, tr(hintKey, who), math.max(40, (width or 0) - PAD * 2))
    local hintH = #lines * (fontS + 2) + 4
    local rowH = fontS + 10
    local n = 1
    if Bridge ~= nil and Bridge.store ~= nil and BridgeData ~= nil then
        if kind == "work" and BridgeData.workOrder ~= nil then
            n = #BridgeData.workOrder(Bridge.store)
        elseif BridgeData.menuOrder ~= nil then
            n = #BridgeData.menuOrder(Bridge.store)
        end
    end
    if n < 1 then n = 1 end
    local tail = btnH
    if kind == "menu" then tail = btnH + gap + btnH end
    return PAD + btnH + gap + hintH + n * rowH + PAD + tail + PAD
end

function BridgeOrder:applyHeight(h)
    self:setHeight(h)
    if self.list == nil or self.upBtn == nil then return end
    local gap = PAD / 2
    local menu = self.kind ~= "work"
    local lootY = nil
    local rowY = h - PAD - self.btnH
    if menu and self.lootTick ~= nil then
        lootY = rowY
        rowY = lootY - gap - self.btnH
    end
    if rowY < 0 then rowY = 0 end
    local listY = PAD + self.btnH + gap + (self.hintH or 0)
    local listH = rowY - listY - PAD
    if listH < 0 then listH = 0 end
    self.list:setY(listY)
    self.list:setHeight(listH)
    self.upBtn:setY(rowY)
    self.downBtn:setY(rowY)
    self.resetBtn:setY(rowY)
    if self.menuBtn ~= nil then self.menuBtn:setY(PAD) end
    if self.workBtn ~= nil then self.workBtn:setY(PAD) end
    if self.lootTick ~= nil then
        self.lootTick:setX(PAD)
        self.lootTick:setWidth(self.width - PAD * 2)
        if menu then self.lootTick:setY(lootY) end
    end
end

function BridgeOrder:createChildren()
    ISPanel.createChildren(self)
    uiFonts()
    local fontS = FONT_S
    local btnH = fontS + 6
    self.btnH = btnH
    self.kind = orderMode()
    self:buildHints()

    local gap = PAD / 2
    local half = math.max(40, math.floor((self.width - PAD * 3) / 2))
    self.menuBtn = ISButton:new(PAD, PAD, half, btnH, tr("WindowOrder"), self, BridgeOrder.onModeMenu)
    self.menuBtn:initialise()
    self.menuBtn:instantiate()
    self.menuBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.menuBtn)

    self.workBtn = ISButton:new(PAD + half + PAD, PAD, half, btnH, tr("Jobs"), self, BridgeOrder.onModeWork)
    self.workBtn:initialise()
    self.workBtn:instantiate()
    self.workBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.workBtn)

    local listY = PAD + btnH + gap + self.hintH
    local lootY = self.height - PAD - btnH
    local rowY = lootY - gap - btnH
    if rowY < listY then rowY = listY end
    local listH = math.max(btnH, rowY - listY - PAD)
    self.list = BridgeOrderList:new(PAD, listY, self.width - PAD * 2, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.onReorder = function() self:onReorder() end
    self.list.onToggle = function(item) self:onToggle(item) end
    self:addChild(self.list)

    local labelW = getTextManager():MeasureStringX(FONT_BODY, tr("MenuReset")) + PAD * 2
    local bw = math.max(labelW, btnH * 2)
    self.upBtn = ISButton:new(PAD, rowY, bw, btnH, "^", self, BridgeOrder.onUp)
    self.upBtn:initialise()
    self.upBtn:instantiate()
    self.upBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.upBtn)

    self.downBtn = ISButton:new(PAD + bw + gap, rowY, bw, btnH, "v", self, BridgeOrder.onDown)
    self.downBtn:initialise()
    self.downBtn:instantiate()
    self.downBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.downBtn)

    self.resetBtn = ISButton:new(PAD + (bw + gap) * 2, rowY, bw, btnH, tr("MenuReset"), self, BridgeOrder.onReset)
    self.resetBtn:initialise()
    self.resetBtn:instantiate()
    self.resetBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.resetBtn)

    self.lootTick = ISTickBox:new(PAD, lootY, self.width - PAD * 2, btnH, "", self, BridgeOrder.onOptionTick, "lootMenu")
    self.lootTick:initialise()
    self.lootTick:instantiate()
    self.lootTick:addOption(tr("OptLootMenu"))
    self.lootTick.tooltip = tr("OptLootMenuTip")
    self:addChild(self.lootTick)

    self:applyMode()
    self.key = nil
    self:refresh()
end

function BridgeOrder:buildHints()
    uiFonts()
    local fontS = FONT_S
    local who = "Rin"
    pcall(function() if Bridge ~= nil and Bridge.companionName ~= nil then who = Bridge.companionName() end end)
    local menuLines = wrapText(FONT_BODY, tr("MenuOrderHint", who), self.width - PAD * 2)
    local workLines = wrapText(FONT_BODY, tr("MenuOrderHintWork", who), self.width - PAD * 2)
    self.hints = {
        menu = { lines = menuLines, h = #menuLines * (fontS + 2) + 4 },
        work = { lines = workLines, h = #workLines * (fontS + 2) + 4 },
    }
    local hint = self.hints[self.kind] or self.hints.menu
    self.hintLines = hint.lines
    self.hintH = hint.h
end

function BridgeOrder:applyMode()
    local work = self.kind == "work"
    if self.lootTick ~= nil then self.lootTick:setVisible(not work) end
    local active = { r = 0.25, g = 0.45, b = 0.75, a = 0.55 }
    local idle = { r = 0.12, g = 0.12, b = 0.12, a = 0.35 }
    if self.menuBtn ~= nil then self.menuBtn.backgroundColor = work and idle or active end
    if self.workBtn ~= nil then self.workBtn.backgroundColor = work and active or idle end
    if self.hints == nil then self:buildHints() end
    local hint = self.hints ~= nil and self.hints[self.kind] or nil
    self.hintLines = (hint ~= nil and hint.lines) or {}
    self.hintH = (hint ~= nil and hint.h) or 0
end

function BridgeOrder:setMode(mode)
    if mode ~= "menu" and mode ~= "work" then return end
    self.kind = mode
    if BridgeWindow ~= nil then BridgeWindow.orderMode = mode end
    self:applyMode()
    self.key = nil
    self:refresh()
    if BridgeWindow ~= nil and type(BridgeWindow.contentHeight) == "function" then
        self:applyHeight(BridgeWindow.contentHeight("order", self.width))
    end
end

function BridgeOrder:onModeMenu()
    self:setMode("menu")
end

function BridgeOrder:onModeWork()
    self:setMode("work")
end

function BridgeOrder:orderKey()
    if Bridge == nil or Bridge.store == nil or BridgeData == nil then return "" end
    local order, hidden = {}, {}
    if self.kind == "work" and BridgeData.workOrder ~= nil then
        order = BridgeData.workOrder(Bridge.store)
        hidden = BridgeData.workHidden(Bridge.store)
    else
        order = BridgeData.menuOrder(Bridge.store)
        hidden = BridgeData.menuHidden(Bridge.store)
    end
    return tostring(self.kind) .. "|" .. table.concat(order, ",") .. "|" .. table.concat(hidden, ",")
end

function BridgeOrder:refresh()
    local list = self.list
    if list == nil then return end
    local keep = list.selected
    list.items = {}
    list.count = 0
    list:setScrollHeight(0)
    local work = self.kind == "work"
    local order = {}
    if Bridge ~= nil and Bridge.store ~= nil and BridgeData ~= nil then
        if work and BridgeData.workOrder ~= nil then
            order = BridgeData.workOrder(Bridge.store)
        elseif BridgeData.menuOrder ~= nil then
            order = BridgeData.menuOrder(Bridge.store)
        end
    end
    local byId = nil
    if BridgeMenu ~= nil then
        byId = work and BridgeMenu.WORK_ORDERABLE_BY_ID or BridgeMenu.ORDERABLE_BY_ID
    end
    for _, id in ipairs(order) do
        local entry = byId ~= nil and byId[id] or nil
        local label = (entry ~= nil and tr(entry.label)) or id
        local item = list:addItem(label, nil)
        item.id = id
        if work and BridgeData ~= nil and BridgeData.workShown ~= nil then
            item.on = BridgeData.workShown(Bridge.store, id)
        else
            item.on = BridgeData ~= nil and BridgeData.menuShown(Bridge.store, id) or true
        end
    end
    if keep == nil or keep < 1 or keep > #list.items then keep = 1 end
    list.selected = keep
    self.key = table.concat(order, ",")
end

function BridgeOrder:prerender()
    ISPanel.prerender(self)
    if Bridge == nil or Bridge.store == nil then return end
    local kind = orderMode()
    if kind ~= self.kind then
        self.kind = kind
        self:applyMode()
        self.key = nil
    end
    if self.list == nil or self.list.dragItem ~= nil then return end
    if self:orderKey() ~= self.key then self:refresh() end
    if self.lootTick ~= nil and self.kind ~= "work" then
        local want = BridgeData.optionOf(Bridge.store, "lootMenu")
        if self.lootTick:isSelected(1) ~= want then self.lootTick:setSelected(1, want) end
    end
end

function BridgeOrder:render()
    if Bridge == nil or Bridge.store == nil then return end
    uiFonts()
    local fontS = FONT_S
    local y = PAD + (self.btnH or 0) + PAD / 2
    for _, line in ipairs(self.hintLines or {}) do
        self:drawText(line, PAD, y, 0.75, 0.75, 0.75, 1, FONT_BODY)
        y = y + fontS + 2
    end
end

function BridgeOrder:onToggle(item)
    if item == nil or item.id == nil or Bridge == nil then return end
    if self.kind == "work" then
        if type(Bridge.setWorkShown) ~= "function" then return end
        Bridge.setWorkShown(item.id, item.on ~= true)
    else
        if type(Bridge.setMenuShown) ~= "function" then return end
        Bridge.setMenuShown(item.id, item.on ~= true)
    end
    self.key = nil
    self:refresh()
end

function BridgeOrder:onReorder()
    local ids = {}
    for _, item in ipairs(self.list.items) do ids[#ids + 1] = item.id end
    if Bridge ~= nil then
        if self.kind == "work" then
            if type(Bridge.setWorkOrder) == "function" then Bridge.setWorkOrder(ids) end
        elseif type(Bridge.setMenuOrder) == "function" then
            Bridge.setMenuOrder(ids)
        end
    end
    self.key = table.concat(ids, ",")
end

function BridgeOrder:onReset()
    if Bridge ~= nil then
        if self.kind == "work" then
            if type(Bridge.resetWorkOrder) == "function" then Bridge.resetWorkOrder() end
        elseif type(Bridge.resetMenuOrder) == "function" then
            Bridge.resetMenuOrder()
        end
    end
    self.key = nil
    self:refresh()
end

function BridgeOrder:onOptionTick(index, selected, key)
    if Bridge ~= nil and type(Bridge.setOption) == "function" then Bridge.setOption(key, selected == true) end
end

function BridgeOrder:move(delta)
    local list = self.list
    local sel = list.selected
    if sel == nil or sel < 1 or sel > #list.items then return end
    local target = sel + delta
    if target < 1 or target > #list.items then return end
    list.items[sel], list.items[target] = list.items[target], list.items[sel]
    for i, v in ipairs(list.items) do v.index = i end
    list.selected = target
    self:onReorder()
end

function BridgeOrder:onUp() self:move(-1) end

function BridgeOrder:onDown() self:move(1) end

function BridgeOrder:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end
