require "ISUI/ISScrollingListBox"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"

local PAD = 10

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
    local o = ISScrollingListBox:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.2 }
    o.drawBorder = true
    o.font = UIFont.Small
    o.fontHgt = getTextManager():getFontHeight(UIFont.Small)
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

function BridgeOrder.heightFor(width)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = fontS + 6
    local who = "Rin"
    pcall(function() if Bridge ~= nil and Bridge.companionName ~= nil then who = Bridge.companionName() end end)
    local lines = wrapText(UIFont.Small, tr("MenuOrderHint", who), math.max(40, (width or 0) - PAD * 2))
    local hintH = #lines * (fontS + 2) + 4
    local rowH = fontS + 10
    local n = 1
    if Bridge ~= nil and Bridge.store ~= nil and BridgeData ~= nil and BridgeData.menuOrder ~= nil then
        n = #BridgeData.menuOrder(Bridge.store)
    end
    if n < 1 then n = 1 end
    local gap = PAD / 2
    return PAD + hintH + n * rowH + PAD + btnH + gap + btnH + PAD
end

function BridgeOrder:applyHeight(h)
    self:setHeight(h)
    if self.list == nil or self.upBtn == nil then return end
    local gap = PAD / 2
    local tickY = h - PAD - self.btnH
    if tickY < 0 then tickY = 0 end
    local rowY = tickY - gap - self.btnH
    if rowY < 0 then rowY = 0 end
    local listY = PAD + (self.hintH or 0)
    local listH = rowY - listY - PAD
    if listH < 0 then listH = 0 end
    self.list:setY(listY)
    self.list:setHeight(listH)
    self.upBtn:setY(rowY)
    self.downBtn:setY(rowY)
    self.resetBtn:setY(rowY)
    if self.collapseTick ~= nil then
        self.collapseTick:setX(PAD)
        self.collapseTick:setWidth(self.width - PAD * 2)
        self.collapseTick:setY(tickY)
    end
end

function BridgeOrder:createChildren()
    ISPanel.createChildren(self)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = fontS + 6
    self.btnH = btnH
    self.hintLines = wrapText(UIFont.Small, tr("MenuOrderHint", Bridge.companionName()), self.width - PAD * 2)
    self.hintH = #self.hintLines * (fontS + 2) + 4

    local listY = PAD + self.hintH
    local gap = PAD / 2
    local tickY = self.height - PAD - btnH
    local rowY = tickY - gap - btnH
    if rowY < listY then rowY = listY end
    local listH = math.max(btnH, rowY - listY - PAD)
    self.list = BridgeOrderList:new(PAD, listY, self.width - PAD * 2, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.onReorder = function() self:onReorder() end
    self.list.onToggle = function(item) self:onToggle(item) end
    self:addChild(self.list)

    local labelW = getTextManager():MeasureStringX(UIFont.Small, tr("MenuReset")) + PAD * 2
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

    self.collapseTick = ISTickBox:new(PAD, tickY, self.width - PAD * 2, btnH, "", self, BridgeOrder.onCollapseTick, "collapseActions")
    self.collapseTick:initialise()
    self.collapseTick:instantiate()
    self.collapseTick:addOption(tr("OptCollapseActions"))
    self.collapseTick.tooltip = tr("OptCollapseActionsTip")
    self:addChild(self.collapseTick)

    self.key = nil
    self:refresh()
end

function BridgeOrder:orderKey()
    if Bridge == nil or Bridge.store == nil then return "" end
    local hidden = BridgeData.menuHidden(Bridge.store)
    return table.concat(BridgeData.menuOrder(Bridge.store), ",") .. "|" .. table.concat(hidden, ",")
end

function BridgeOrder:refresh()
    local list = self.list
    if list == nil then return end
    local keep = list.selected
    list.items = {}
    list.count = 0
    list:setScrollHeight(0)
    local order = {}
    if Bridge ~= nil and Bridge.store ~= nil then order = BridgeData.menuOrder(Bridge.store) end
    for _, id in ipairs(order) do
        local entry = BridgeMenu ~= nil and BridgeMenu.ORDERABLE_BY_ID and BridgeMenu.ORDERABLE_BY_ID[id] or nil
        local label = (entry ~= nil and tr(entry.label)) or id
        local item = list:addItem(label, nil)
        item.id = id
        item.on = BridgeData.menuShown(Bridge.store, id)
    end
    if keep == nil or keep < 1 or keep > #list.items then keep = 1 end
    list.selected = keep
    self.key = table.concat(order, ",")
end

function BridgeOrder:prerender()
    ISPanel.prerender(self)
    if Bridge == nil or Bridge.store == nil then return end
    if self.list == nil or self.list.dragItem ~= nil then return end
    if self:orderKey() ~= self.key then self:refresh() end
    if self.collapseTick ~= nil then
        local want = BridgeData.optionOf(Bridge.store, "collapseActions")
        if self.collapseTick:isSelected(1) ~= want then self.collapseTick:setSelected(1, want) end
    end
end

function BridgeOrder:render()
    if Bridge == nil or Bridge.store == nil then return end
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local y = PAD
    for _, line in ipairs(self.hintLines or {}) do
        self:drawText(line, PAD, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
        y = y + fontS + 2
    end
end

function BridgeOrder:onToggle(item)
    if item == nil or item.id == nil or Bridge == nil or type(Bridge.setMenuShown) ~= "function" then return end
    Bridge.setMenuShown(item.id, item.on ~= true)
    self.key = nil
    self:refresh()
end

function BridgeOrder:onReorder()
    local ids = {}
    for _, item in ipairs(self.list.items) do ids[#ids + 1] = item.id end
    if Bridge ~= nil and type(Bridge.setMenuOrder) == "function" then Bridge.setMenuOrder(ids) end
    self.key = table.concat(ids, ",")
end

function BridgeOrder:onReset()
    if Bridge ~= nil and type(Bridge.resetMenuOrder) == "function" then Bridge.resetMenuOrder() end
    self.key = nil
    self:refresh()
end

function BridgeOrder:onCollapseTick(index, selected, key)
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
