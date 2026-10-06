
require "ISUI/ISCollapsableWindow"
require "ISUI/ISTabPanel"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISUI3DModel"
require "ISUI/ISColorPickerHSB"

BridgeAppearance = BridgeAppearance or {}

local PAD = 10
local PREVIEW_W, PREVIEW_H = 170, 300

local FONT_S, FONT_M, BTN_H = 0, 0, 0
local function refreshFonts()
    FONT_S = getTextManager():getFontHeight(UIFont.Small)
    FONT_M = getTextManager():getFontHeight(UIFont.Medium)
    BTN_H = FONT_S + 6
end
refreshFonts()

local function textW(font, text)
    local w = 0
    pcall(function() w = getTextManager():MeasureStringX(font, tostring(text or "")) end)
    return w or 0
end

local function fitText(font, text, maxW)
    text = tostring(text or "")
    if maxW <= 0 or textW(font, text) <= maxW then return text end
    local ell = "..."
    if textW(font, ell) > maxW then return "" end
    local n = #text
    while n > 0 and textW(font, string.sub(text, 1, n) .. ell) > maxW do
        n = n - 1
        local b = string.byte(text, n + 1)
        while n > 0 and b ~= nil and b >= 128 and b < 192 do
            n = n - 1
            b = string.byte(text, n + 1)
        end
    end
    return string.sub(text, 1, n) .. ell
end

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeAppearance] " .. tostring(text)) end end
local function warn(text) print("[BridgeAppearance] " .. tostring(text)) end

local function tr(key, a)
    local text = key
    pcall(function()
        if a ~= nil then text = getText("IGUI_NotAlone_" .. key, a) else text = getText("IGUI_NotAlone_" .. key) end
    end)
    return text
end

local function gameText(key, fallback)
    local text = nil
    pcall(function() text = getTextOrNull(key) end)
    if text == nil or text == "" then return fallback end
    return text
end

local function vanillaText(key, fallback)
    if type(getTextOrNull) ~= "function" then return fallback end
    local text = getTextOrNull(key)
    if type(text) ~= "string" or text == "" or text == key then return fallback end
    return text
end

local function copyColor(c)
    return { r = c.r, g = c.g, b = c.b }
end

local function sameColor(a, b)
    if a == nil or b == nil then return false end
    return math.abs(a.r - b.r) < 0.01 and math.abs(a.g - b.g) < 0.01 and math.abs(a.b - b.b) < 0.01
end

local function mark(btn, on)
    if on then
        btn.borderColor = { r = 1, g = 0.85, b = 0.2, a = 1 }
    else
        btn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    end
end



BridgeAppearance.Catalog = BridgeAppearance.Catalog or {}

function BridgeAppearance.Catalog.bodyEntries()
    local out = {}
    for i, id in ipairs(BridgeData.SKINS) do
        out[#out + 1] = { id = id, label = tr("SkinTone", i) }
    end
    return out
end

function BridgeAppearance.Catalog.hairEntries()
    local out = {}
    local styles = (BridgeWindow ~= nil and BridgeWindow.hairStyles ~= nil) and BridgeWindow.hairStyles() or {}
    for _, s in ipairs(styles) do
        out[#out + 1] = { name = s.id, label = s.label }
    end
    return out
end

function BridgeAppearance.Catalog.faceEntries()
    local out = { { name = "", label = tr("AppearanceDefaultFace") } }
    for _, e in ipairs(BridgeData.spnccFaces() or {}) do
        local label = gameText("IGUI_Face_" .. tostring(e.display or e.name), tostring(e.display or e.name))
        out[#out + 1] = { name = e.name, label = label }
    end
    return out
end

function BridgeAppearance.Catalog.detailEntries()
    local out = {}
    for _, e in ipairs(BridgeData.spnccDetails() or {}) do
        local label = gameText("IGUI_Detail_" .. tostring(e.display or e.name), tostring(e.display or e.name))
        out[#out + 1] = { name = e.name, label = label }
    end
    return out
end

function BridgeAppearance.Catalog.hairColorPresets()
    local out = {}
    pcall(function()
        local desc = SurvivorFactory.CreateSurvivor()
        local list = desc:getCommonHairColor()
        if list == nil then return end
        for i = 0, list:size() - 1 do
            local c = list:get(i)
            out[#out + 1] = { r = c:getRedFloat(), g = c:getGreenFloat(), b = c:getBlueFloat() }
        end
    end)
    if #out == 0 then
        out = {
            { r = 0.05, g = 0.03, b = 0.02 },
            { r = 0.16, g = 0.09, b = 0.05 },
            { r = 0.35, g = 0.18, b = 0.08 },
            { r = 0.55, g = 0.12, b = 0.12 },
            { r = 0.72, g = 0.50, b = 0.18 },
            { r = 0.90, g = 0.80, b = 0.55 },
            { r = 0.62, g = 0.62, b = 0.62 },
            { r = 0.92, g = 0.92, b = 0.92 },
        }
    end
    return out
end



BridgeAppearance.candidate = { skin = nil, hair = nil, hairColor = nil, face = nil, details = {}, muscle = 0, makeup = {} }

function BridgeAppearance.makePreviewDesc()
    local st = Bridge.store or {}
    local c = BridgeAppearance.candidate
    local tmp = { skin = c.skin, hair = c.hair, hairColor = c.hairColor, items = st.items,
                  face = c.face, details = c.details, muscle = c.muscle, makeup = c.makeup }
    return BridgeWindow.makeDesc(tmp)
end

function BridgeAppearance.refreshPreview()
    local w = BridgeAppearance.instance
    if w == nil or w.preview == nil then return end
    local ok, err = pcall(function() w.preview:setSurvivorDesc(BridgeAppearance.makePreviewDesc()) end)
    if not ok then warn("preview failed: " .. tostring(err)) end
end

function BridgeAppearance.refreshViews()
    local w = BridgeAppearance.instance
    if w == nil then return end
    pcall(function() w:refresh() end)
end

function BridgeAppearance.setSkin(id)
    local skin = BridgeData.cleanSkin(id)
    if skin == nil then return end
    BridgeAppearance.candidate.skin = skin
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
end

function BridgeAppearance.setHair(id)
    local hair = BridgeData.cleanHair(id)
    if hair == nil then return end
    BridgeAppearance.candidate.hair = hair
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
end

function BridgeAppearance.setColor(c)
    local color = BridgeData.cleanHairColor(c)
    if color == nil then return end
    BridgeAppearance.candidate.hairColor = color
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
end

function BridgeAppearance.setFace(name)
    if name == nil or name == "" then
        BridgeAppearance.candidate.face = nil
    else
        BridgeAppearance.candidate.face = BridgeData.cleanFace(name)
    end
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
end

function BridgeAppearance.hasDetail(name)
    for _, n in ipairs(BridgeAppearance.candidate.details) do
        if n == name then return true end
    end
    return false
end

function BridgeAppearance.toggleDetail(name)
    local valid = false
    for _, e in ipairs(BridgeData.spnccDetails() or {}) do
        if e.name == name then valid = true break end
    end
    if not valid then return end
    local out, removed = {}, false
    for _, n in ipairs(BridgeAppearance.candidate.details) do
        if n == name then removed = true else out[#out + 1] = n end
    end
    if not removed then out[#out + 1] = name end
    BridgeAppearance.candidate.details = out
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
end

function BridgeAppearance.setMuscle(level)
    local m = tonumber(level)
    if m == nil or m ~= m then return end
    m = math.floor(m)
    if m < 0 then m = 0 end
    if m > BridgeData.MUSCLE_MAX then m = BridgeData.MUSCLE_MAX end
    BridgeAppearance.candidate.muscle = m
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
end

function BridgeAppearance.setMakeup(category, itemType)
    local out = {}
    for _, t in ipairs(BridgeAppearance.candidate.makeup) do
        local m = BridgeData.makeupMeta(t)
        if m == nil or m.category ~= category then out[#out + 1] = t end
    end
    if itemType ~= nil and itemType ~= "" then out[#out + 1] = itemType end
    BridgeAppearance.candidate.makeup = out
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
end

function BridgeAppearance.openColorPicker(button)
    local cur = BridgeAppearance.candidate.hairColor or BridgeData.DEFAULT_HAIR_COLOR
    local picker = nil
    local ok, err = pcall(function()
        picker = ISColorPickerHSB:new(0, 0, ColorInfo.new(cur.r, cur.g, cur.b, 1))
        picker:initialise()
        picker.keepOnScreen = true
        picker.pickedTarget = BridgeAppearance
        picker.resetFocusTo = BridgeAppearance.instance
        picker:setPickedFunc(BridgeAppearance.onCustomColor)
        picker:setInitialColor(ColorInfo.new(cur.r, cur.g, cur.b, 1))
        if button ~= nil then
            picker:setX(button:getAbsoluteX())
            picker:setY(button:getAbsoluteY() + button:getHeight())
        end
        picker:addToUIManager()
        picker:setCapture(false)
    end)
    if not ok then warn("color picker failed: " .. tostring(err)) end
    BridgeAppearance.picker = picker
    return picker
end

function BridgeAppearance.onCustomColor(target, color, mouseUp)
    if color ~= nil then
        BridgeAppearance.setColor({ r = color.r, g = color.g, b = color.b })
    end
    local picker = BridgeAppearance.picker
    BridgeAppearance.picker = nil
    if picker ~= nil then pcall(function() picker:removeSelf() end) end
end



BridgeAppearanceBody = ISPanel:derive("BridgeAppearanceBody")

function BridgeAppearanceBody:createChildren()
    ISPanel.createChildren(self)
    self.skinCombo = ISComboBox:new(PAD, 0, 10, BTN_H, self, BridgeAppearanceBody.onSkin)
    self.skinCombo:initialise()
    for i, id in ipairs(BridgeData.SKINS) do
        self.skinCombo:addOptionWithData(tr("SkinTone", i), id)
    end
    self:addChild(self.skinCombo)

    self.muscleLabelY = nil
    self.muscleCombo = nil
    if BridgeData.spnccMuscle() ~= nil then
        self.muscleCombo = ISComboBox:new(PAD, 0, 10, BTN_H, self, BridgeAppearanceBody.onMuscle)
        self.muscleCombo:initialise()
        self.muscleCombo:addOptionWithData(tr("Muscle_0"), 0)
        self.muscleCombo:addOptionWithData(tr("Muscle_1"), 1)
        self.muscleCombo:addOptionWithData(tr("Muscle_2"), 2)
        self:addChild(self.muscleCombo)
    end
    self:layout()
end

function BridgeAppearanceBody:layout()
    local cw = math.min(260, self.width - PAD * 2)
    if cw < 60 then cw = 60 end
    local y = PAD
    self.skinLabelY = y
    y = y + FONT_S + 4
    self.skinCombo:setX(PAD)
    self.skinCombo:setY(y)
    self.skinCombo:setWidth(cw)
    self.skinCombo:setHeight(BTN_H)
    y = y + BTN_H + PAD
    if self.muscleCombo ~= nil then
        self.muscleLabelY = y
        y = y + FONT_S + 4
        self.muscleCombo:setX(PAD)
        self.muscleCombo:setY(y)
        self.muscleCombo:setWidth(cw)
        self.muscleCombo:setHeight(BTN_H)
    end
end

function BridgeAppearanceBody:render()
    self:drawText(tr("AppearanceSkin"), PAD, self.skinLabelY, 1, 1, 1, 1, UIFont.Small)
    if self.muscleLabelY ~= nil then
        self:drawText(tr("AppearanceBody"), PAD, self.muscleLabelY, 1, 1, 1, 1, UIFont.Small)
    end
end

function BridgeAppearanceBody:onSkin(combo)
    BridgeAppearance.setSkin(combo:getSelectedData())
end

function BridgeAppearanceBody:onMuscle(combo)
    BridgeAppearance.setMuscle(combo:getSelectedData())
end

function BridgeAppearanceBody:refresh()
    self.skinCombo:selectData(BridgeAppearance.candidate.skin)
    if self.muscleCombo ~= nil then
        self.muscleCombo:selectData(BridgeAppearance.candidate.muscle)
    end
end

function BridgeAppearanceBody:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end




local MAX_ROWS = 6

local function fitRows(viewH, extraH)
    local headerH = PAD + FONT_S + PAD
    local rowH = BTN_H + 6
    local avail = viewH - headerH - BTN_H - (extraH or 0) - PAD
    local rows = math.floor(avail / rowH)
    if rows < 1 then rows = 1 end
    if rows > MAX_ROWS then rows = MAX_ROWS end
    return rows
end



local function gridButton(view, i, onClick)
    local b = ISButton:new(PAD, PAD, 10, BTN_H + 2, "", view, onClick)
    b:initialise()
    b:instantiate()
    mark(b, false)
    view:addChild(b)
    return b
end

local function addPager(view, onPrev, onNext)
    local pw = BTN_H + 20
    view.prevBtn = ISButton:new(PAD, 0, pw, BTN_H, "<", view, onPrev)
    view.prevBtn:initialise()
    view.prevBtn:instantiate()
    view:addChild(view.prevBtn)
    view.nextBtn = ISButton:new(PAD, 0, pw, BTN_H, ">", view, onNext)
    view.nextBtn:initialise()
    view.nextBtn:instantiate()
    view:addChild(view.nextBtn)
end


local function gridLayout(view, extraH)
    local rows = fitRows(view.height, extraH)
    view.rows = rows
    view.per = view.cols * rows
    local rowH = BTN_H + 6
    local bw = math.floor((view.width - PAD * (view.cols + 1)) / view.cols)
    if bw < 20 then bw = 20 end
    for i = 1, #view.btns do
        local b = view.btns[i]
        if i <= view.per then
            local row = math.floor((i - 1) / view.cols)
            local col = (i - 1) - row * view.cols
            b:setX(PAD + col * (bw + PAD))
            b:setY(PAD + FONT_S + PAD + row * rowH)
            b:setWidth(bw)
            b:setHeight(BTN_H + 2)
            b:setVisible(true)
        else
            b:setVisible(false)
        end
    end
    view.pageY = PAD + FONT_S + PAD + rows * rowH
    local pw = BTN_H + 20
    view.prevBtn:setX(PAD)
    view.prevBtn:setY(view.pageY)
    view.prevBtn:setWidth(pw)
    view.prevBtn:setHeight(BTN_H)
    view.nextBtn:setX(PAD + pw + PAD)
    view.nextBtn:setY(view.pageY)
    view.nextBtn:setWidth(pw)
    view.nextBtn:setHeight(BTN_H)
end

local function pagerRefresh(view, selectedName, isSelected)
    local pages = math.max(1, math.ceil(#view.entries / view.per))
    if view.page > pages then view.page = pages end
    if view.page < 1 then view.page = 1 end
    local start = (view.page - 1) * view.per
    for i, b in ipairs(view.btns) do
        if i > view.per then
            b:setVisible(false)
            b:setEnable(false)
            b.entryName = nil
            mark(b, false)
        else
            b:setVisible(true)
            local e = view.entries[start + i]
            if e ~= nil then
                b:setTitle(fitText(b.font or UIFont.Small, e.label, b.width or 0))
                b:setEnable(true)
                b.entryName = e.name or e.id
                mark(b, isSelected(b.entryName))
            else
                b:setTitle("")
                b:setEnable(false)
                b.entryName = nil
                mark(b, false)
            end
        end
    end
    view.pageText = view.page .. " / " .. pages
    view.prevBtn:setEnable(view.page > 1)
    view.nextBtn:setEnable(view.page < pages)
end



BridgeAppearanceFace = ISPanel:derive("BridgeAppearanceFace")

function BridgeAppearanceFace:createChildren()
    ISPanel.createChildren(self)
    self.entries = BridgeAppearance.Catalog.faceEntries()
    self.cols = 2
    self.rows = 1
    self.per = self.cols
    self.page = 1
    self.pageText = "1 / 1"
    self.btns = {}
    for i = 1, self.cols * MAX_ROWS do
        self.btns[i] = gridButton(self, i, BridgeAppearanceFace.onPick)
    end
    addPager(self, BridgeAppearanceFace.onPrev, BridgeAppearanceFace.onNext)
    self:layout()
end

function BridgeAppearanceFace:layout()
    gridLayout(self, 0)
    self:refresh()
end

function BridgeAppearanceFace:render()
    self:drawText(tr("AppearanceFace"), PAD, PAD, 1, 1, 1, 1, UIFont.Small)
    self:drawText(self.pageText, self.nextBtn:getRight() + PAD, self.pageY + 3, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function BridgeAppearanceFace:onPick(button)
    if button.entryName ~= nil then BridgeAppearance.setFace(button.entryName) end
end

function BridgeAppearanceFace:onPrev() self.page = self.page - 1 self:refresh() end
function BridgeAppearanceFace:onNext() self.page = self.page + 1 self:refresh() end

function BridgeAppearanceFace:refresh()
    pagerRefresh(self, nil, function(name) return (BridgeAppearance.candidate.face or "") == name end)
end

function BridgeAppearanceFace:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end



BridgeAppearanceDetails = ISPanel:derive("BridgeAppearanceDetails")

function BridgeAppearanceDetails:createChildren()
    ISPanel.createChildren(self)
    self.entries = BridgeAppearance.Catalog.detailEntries()
    self.cols = 2
    self.rows = 1
    self.per = self.cols
    self.page = 1
    self.pageText = "1 / 1"
    self.btns = {}
    for i = 1, self.cols * MAX_ROWS do
        self.btns[i] = gridButton(self, i, BridgeAppearanceDetails.onToggle)
    end
    addPager(self, BridgeAppearanceDetails.onPrev, BridgeAppearanceDetails.onNext)
    self.clearBtn = ISButton:new(PAD, 0, 10, BTN_H, tr("AppearanceClearDetails"), self, BridgeAppearanceDetails.onClear)
    self.clearBtn:initialise()
    self.clearBtn:instantiate()
    self:addChild(self.clearBtn)
    self:layout()
end

function BridgeAppearanceDetails:layout()
    gridLayout(self, PAD + BTN_H)
    self.clearBtn:setX(PAD)
    self.clearBtn:setY(self.pageY + BTN_H + PAD)
    self.clearBtn:setWidth(self.width - PAD * 2)
    self.clearBtn:setHeight(BTN_H)
    self:refresh()
end

function BridgeAppearanceDetails:render()
    self:drawText(tr("AppearanceDetails"), PAD, PAD, 1, 1, 1, 1, UIFont.Small)
    self:drawText(self.pageText, self.nextBtn:getRight() + PAD, self.pageY + 3, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function BridgeAppearanceDetails:onToggle(button)
    if button.entryName ~= nil then BridgeAppearance.toggleDetail(button.entryName) end
end

function BridgeAppearanceDetails:onClear()
    BridgeAppearance.candidate.details = {}
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
end

function BridgeAppearanceDetails:onPrev() self.page = self.page - 1 self:refresh() end
function BridgeAppearanceDetails:onNext() self.page = self.page + 1 self:refresh() end

function BridgeAppearanceDetails:refresh()
    pagerRefresh(self, nil, function(name) return BridgeAppearance.hasDetail(name) end)
end

function BridgeAppearanceDetails:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end



BridgeAppearanceHair = ISPanel:derive("BridgeAppearanceHair")

function BridgeAppearanceHair:createChildren()
    ISPanel.createChildren(self)
    self.entries = BridgeAppearance.Catalog.hairEntries()
    self.cols = 2
    self.rows = 1
    self.per = self.cols
    self.page = 1
    self.pageText = "1 / 1"
    self.btns = {}
    for i = 1, self.cols * MAX_ROWS do
        self.btns[i] = gridButton(self, i, BridgeAppearanceHair.onStyle)
    end
    addPager(self, BridgeAppearanceHair.onPrev, BridgeAppearanceHair.onNext)

    self.swatches = {}
    local presets = BridgeAppearance.Catalog.hairColorPresets()
    for _, c in ipairs(presets) do
        local b = ISButton:new(PAD, 0, 24, 24, "", self, BridgeAppearanceHair.onColor)
        b:initialise()
        b:instantiate()
        b.backgroundColor = { r = c.r, g = c.g, b = c.b, a = 1 }
        b.colorValue = c
        mark(b, false)
        self:addChild(b)
        self.swatches[#self.swatches + 1] = b
    end
    self.customBtn = ISButton:new(PAD, 0, 10, BTN_H, tr("AppearanceCustomColor"), self, BridgeAppearanceHair.onCustom)
    self.customBtn:initialise()
    self.customBtn:instantiate()
    self:addChild(self.customBtn)
    self:layout()
end

function BridgeAppearanceHair:layout()
    local sw = 24
    gridLayout(self, PAD + FONT_S + PAD + sw + PAD + BTN_H)
    self.colorY = self.pageY + BTN_H + PAD + FONT_S + PAD
    local sx = PAD
    for _, b in ipairs(self.swatches) do
        if sx + sw > self.width - PAD then
            b:setVisible(false)
        else
            b:setVisible(true)
            b:setX(sx)
            b:setY(self.colorY)
            b:setWidth(sw)
            b:setHeight(sw)
            sx = sx + sw + 4
        end
    end
    self.customBtn:setX(PAD)
    self.customBtn:setY(self.colorY + sw + PAD)
    self.customBtn:setWidth(self.width - PAD * 2)
    self.customBtn:setHeight(BTN_H)
    self:refresh()
end

function BridgeAppearanceHair:render()
    self:drawText(tr("AppearanceHair"), PAD, PAD, 1, 1, 1, 1, UIFont.Small)
    self:drawText(self.pageText, self.nextBtn:getRight() + PAD, self.pageY + 3, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText(tr("AppearanceColor"), PAD, self.pageY + BTN_H + PAD, 1, 1, 1, 1, UIFont.Small)
end

function BridgeAppearanceHair:onStyle(button)
    if button.entryName ~= nil then BridgeAppearance.setHair(button.entryName) end
end

function BridgeAppearanceHair:onColor(button)
    if button.colorValue ~= nil then BridgeAppearance.setColor(button.colorValue) end
end

function BridgeAppearanceHair:onCustom(button)
    BridgeAppearance.openColorPicker(button)
end

function BridgeAppearanceHair:onPrev() self.page = self.page - 1 self:refresh() end
function BridgeAppearanceHair:onNext() self.page = self.page + 1 self:refresh() end

function BridgeAppearanceHair:refresh()
    pagerRefresh(self, nil, function(name) return BridgeAppearance.candidate.hair == name end)
    local cur = BridgeAppearance.candidate.hairColor
    for _, b in ipairs(self.swatches) do
        mark(b, sameColor(b.colorValue, cur))
    end
end

function BridgeAppearanceHair:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end



BridgeAppearanceMakeup = ISPanel:derive("BridgeAppearanceMakeup")

function BridgeAppearanceMakeup:createChildren()
    ISPanel.createChildren(self)
    self.combos, self.labelY, self.comboOrder = {}, {}, {}
    local defs = rawget(_G, "MakeUpDefinitions")
    local order = { "FullFace", "Eyes", "EyesShadow", "Lips" }
    for _, cat in ipairs(order) do
        local info = defs ~= nil and defs.categories ~= nil and defs.categories[cat] or nil
        if info ~= nil then
            local combo = ISComboBox:new(PAD, 0, 10, BTN_H, self, BridgeAppearanceMakeup.onPick)
            combo:initialise()
            combo.category = cat
            combo:addOptionWithData(tr("AppearanceNone"), nil)
            for _, m in ipairs(defs.makeup) do
                if m.category == cat then
                    combo:addOptionWithData(gameText("MakeUpType_" .. tostring(m.name), tostring(m.name)), m.item)
                end
            end
            self:addChild(combo)
            self.combos[cat] = combo
            self.comboOrder[#self.comboOrder + 1] = cat
        end
    end
    self:layout()
end

function BridgeAppearanceMakeup:layout()
    local cw = math.min(260, self.width - PAD * 2)
    if cw < 60 then cw = 60 end
    local y = PAD + FONT_S + PAD
    for _, cat in ipairs(self.comboOrder) do
        local combo = self.combos[cat]
        self.labelY[cat] = y
        y = y + FONT_S + 4
        combo:setX(PAD)
        combo:setY(y)
        combo:setWidth(cw)
        combo:setHeight(BTN_H)
        y = y + BTN_H + PAD
    end
end

function BridgeAppearanceMakeup:render()
    self:drawText(tr("AppearanceMakeup"), PAD, PAD, 1, 1, 1, 1, UIFont.Small)
    local defs = rawget(_G, "MakeUpDefinitions")
    for cat, ly in pairs(self.labelY) do
        local info = defs ~= nil and defs.categories ~= nil and defs.categories[cat] or nil
        local label = cat
        if info ~= nil then label = gameText("MakeUpCategory_" .. tostring(info.name), cat) end
        self:drawText(label, PAD, ly, 1, 1, 1, 1, UIFont.Small)
    end
end

function BridgeAppearanceMakeup:onPick(combo)
    BridgeAppearance.setMakeup(combo.category, combo:getSelectedData())
end

function BridgeAppearanceMakeup:refresh()
    for cat, combo in pairs(self.combos) do
        local current = nil
        for _, t in ipairs(BridgeAppearance.candidate.makeup) do
            local m = BridgeData.makeupMeta(t)
            if m ~= nil and m.category == cat then current = t break end
        end
        combo:selectData(current)
    end
end

function BridgeAppearanceMakeup:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end



BridgeAppearance.Window = ISCollapsableWindow:derive("BridgeAppearanceWindow")

BridgeAppearance.ZOOM_MIN = 0
BridgeAppearance.ZOOM_MAX = 20
BridgeAppearance.ZOOM_STEP = 4
BridgeAppearance.ZOOM = { body = 0, face = 18, hair = 16, details = 18, makeup = 20 }

local function zoomY(zoom)
    local z = zoom
    if z > 18 then z = 18 end
    local y = -0.5 + (z / 18) * (-0.375)
    if y < -0.875 then y = -0.875 end
    return y
end


function BridgeAppearance.Window:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.preview = ISUI3DModel:new(PAD, PAD, PREVIEW_W, PREVIEW_H)
    self.preview:initialise()
    self.preview:instantiate()
    self:addChild(self.preview)
    pcall(function() self.preview:setState("idle") end)
    pcall(function() self.preview:setDirection(IsoDirections.S) end)
    pcall(function() self.preview:setIsometric(false) end)
    self.previewBack = getTexture("media/ui/avatarBackgroundWhite.png")

    self.panel = ISTabPanel:new(0, 0, 10, 10)
    self.panel:initialise()
    self.panel.tabPadX = PAD
    self.panel.equalTabWidth = false
    self:addChild(self.panel)

    self.bodyView = BridgeAppearanceBody:new(0, 0, 10, 10)
    self.bodyView.tabKey = "body"
    self.bodyView:initialise()
    self.panel:addView(tr("AppearanceBody"), self.bodyView)

    self.faceView = nil
    if BridgeData.spnccFaces() ~= nil then
        self.faceView = BridgeAppearanceFace:new(0, 0, 10, 10)
        self.faceView.tabKey = "face"
        self.faceView:initialise()
        self.panel:addView(tr("AppearanceFace"), self.faceView)
    end

    self.hairView = BridgeAppearanceHair:new(0, 0, 10, 10)
    self.hairView.tabKey = "hair"
    self.hairView:initialise()
    self.panel:addView(tr("AppearanceHair"), self.hairView)

    self.detailView = nil
    if BridgeData.spnccDetails() ~= nil then
        self.detailView = BridgeAppearanceDetails:new(0, 0, 10, 10)
        self.detailView.tabKey = "details"
        self.detailView:initialise()
        self.panel:addView(tr("AppearanceDetails"), self.detailView)
    end

    self.makeupView = nil
    if BridgeData.makeupList() ~= nil then
        self.makeupView = BridgeAppearanceMakeup:new(0, 0, 10, 10)
        self.makeupView.tabKey = "makeup"
        self.makeupView:initialise()
        self.panel:addView(tr("AppearanceMakeup"), self.makeupView)
    end

    self.zoomOutBtn = ISButton:new(PAD, 0, 30, BTN_H, "-", self, BridgeAppearance.Window.onZoomOut)
    self.zoomOutBtn:initialise()
    self.zoomOutBtn:instantiate()
    self.zoomOutBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.zoomOutBtn)
    self.zoomInBtn = ISButton:new(PAD, 0, 30, BTN_H, "+", self, BridgeAppearance.Window.onZoomIn)
    self.zoomInBtn:initialise()
    self.zoomInBtn:instantiate()
    self.zoomInBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.zoomInBtn)

    self.applyText = tr("AppearanceApply")
    self.closeText = tr("Close")
    self.applyBtn = ISButton:new(0, 0, 10, BTN_H, self.applyText, self, BridgeAppearance.Window.onApply)
    self.applyBtn:initialise()
    self.applyBtn:instantiate()
    self:addChild(self.applyBtn)
    self.closeBtn = ISButton:new(0, 0, 10, BTN_H, self.closeText, self, BridgeAppearance.Window.onClose)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)

    self.saveText = vanillaText("UI_characreation_BuildSave", "Save")
    self.delText = vanillaText("UI_characreation_BuildDel", "Del")
    self.lookCombo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgeAppearance.Window.onLook)
    self.lookCombo:initialise()
    self.lookCombo.openUpwards = true
    self.lookCombo.noSelectionText = ""
    self:addChild(self.lookCombo)
    self.saveBtn = ISButton:new(0, 0, 10, BTN_H, self.saveText, self, BridgeAppearance.Window.onSave)
    self.saveBtn:initialise()
    self.saveBtn:instantiate()
    if self.saveBtn.enableAcceptColor ~= nil then self.saveBtn:enableAcceptColor() end
    self:addChild(self.saveBtn)
    self.deleteBtn = ISButton:new(0, 0, 10, BTN_H, self.delText, self, BridgeAppearance.Window.onDelete)
    self.deleteBtn:initialise()
    self.deleteBtn:instantiate()
    if self.deleteBtn.enableCancelColor ~= nil then self.deleteBtn:enableCancelColor() end
    self.deleteBtn:setEnable(false)
    self:addChild(self.deleteBtn)

    self:layout()
end



function BridgeAppearance.Window:layout()
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local footerH = BTN_H + PAD * 2

    if self.resizeWidget ~= nil then
        self.resizeWidget:setX(self.width - rh)
        self.resizeWidget:setY(self.height - rh)
    end
    if self.resizeWidget2 ~= nil then
        self.resizeWidget2:setX(0)
        self.resizeWidget2:setY(self.height - rh)
        self.resizeWidget2:setWidth(self.width - rh)
    end

    local tabX = PAD + PREVIEW_W + PAD
    local tabW = self.width - tabX - PAD
    if tabW < 80 then tabW = 80 end
    local tabY = th + PAD
    local tabH = self.height - tabY - rh - footerH - PAD
    if tabH < 40 then tabH = 40 end

    local previewH = PREVIEW_H
    if previewH > tabH then previewH = math.max(40, tabH) end
    self.previewH = previewH
    self.preview:setX(PAD)
    self.preview:setY(th + PAD)
    self.preview:setWidth(PREVIEW_W)
    self.preview:setHeight(previewH)

    self.panel:setX(tabX)
    self.panel:setY(tabY)
    self.panel:setWidth(tabW)
    self.panel:setHeight(tabH)

    local innerH = tabH - self.panel.tabHeight
    if innerH < 40 then innerH = 40 end
    local views = { self.bodyView, self.faceView, self.hairView, self.detailView, self.makeupView }
    for i = 1, #views do
        local v = views[i]
        if v ~= nil then
            v:setWidth(tabW)
            v:setHeight(innerH)
            if type(v.layout) == "function" then v:layout() end
        end
    end

    local zy = th + PAD + previewH + PAD
    self.zoomOutBtn:setX(PAD)
    self.zoomOutBtn:setY(zy)
    self.zoomOutBtn:setWidth(30)
    self.zoomOutBtn:setHeight(BTN_H)
    self.zoomInBtn:setX(PAD + 34)
    self.zoomInBtn:setY(zy)
    self.zoomInBtn:setWidth(30)
    self.zoomInBtn:setHeight(BTN_H)

    local by = self.height - rh - footerH + PAD
    local applyW = textW(UIFont.Small, self.applyText) + PAD * 3
    local closeW = textW(UIFont.Small, self.closeText) + PAD * 3
    local gap = PAD
    local saveW = math.max(50, textW(UIFont.Small, self.saveText) + PAD * 2)
    local delW = math.max(50, textW(UIFont.Small, self.delText) + PAD * 2)

    self.closeBtn:setX(self.width - PAD - closeW)
    self.closeBtn:setY(by)
    self.closeBtn:setWidth(closeW)
    self.closeBtn:setHeight(BTN_H)
    self.applyBtn:setX(self.width - PAD - applyW - PAD - closeW)
    self.applyBtn:setY(by)
    self.applyBtn:setWidth(applyW)
    self.applyBtn:setHeight(BTN_H)

    local limit = self.applyBtn:getX() - gap
    local comboW = math.min(PREVIEW_W, limit - PAD - saveW - delW - gap * 2)
    if comboW < 80 then comboW = 80 end
    self.lookCombo:setX(PAD)
    self.lookCombo:setY(by)
    self.lookCombo:setWidth(comboW)
    self.lookCombo:setHeight(BTN_H)
    self.saveBtn:setX(PAD + comboW + gap)
    self.saveBtn:setY(by)
    self.saveBtn:setWidth(saveW)
    self.saveBtn:setHeight(BTN_H)
    self.deleteBtn:setX(self.saveBtn:getX() + saveW + gap)
    self.deleteBtn:setY(by)
    self.deleteBtn:setWidth(delW)
    self.deleteBtn:setHeight(BTN_H)
end

function BridgeAppearance.Window:onResize()
    local base = ISCollapsableWindow.onResize
    if type(base) == "function" then base(self) end
    if self.preview ~= nil then
        self:layout()
    end
end

function BridgeAppearance.Window:prerender()
    ISCollapsableWindow.prerender(self)
    if self.preview ~= nil then
        local py = self:titleBarHeight() + PAD
        local ph = self.previewH or PREVIEW_H
        self:drawRectBorder(PAD - 2, py - 2, PREVIEW_W + 4, ph + 4, 1, 0.3, 0.3, 0.3)
        self:drawTextureScaled(self.previewBack, PAD, py, PREVIEW_W, ph, 1, 0.4, 0.4, 0.4)
    end
end

function BridgeAppearance.Window:setZoom(zoom)
    if zoom == nil then zoom = 0 end
    if zoom < BridgeAppearance.ZOOM_MIN then zoom = BridgeAppearance.ZOOM_MIN end
    if zoom > BridgeAppearance.ZOOM_MAX then zoom = BridgeAppearance.ZOOM_MAX end
    self.zoom = zoom
    if self.preview ~= nil then
        pcall(function() self.preview:setZoom(zoom) end)
        pcall(function() self.preview:setYOffset(zoomY(zoom)) end)
        pcall(function() self.preview:setXOffset(0) end)
    end
    if self.zoomInBtn ~= nil then self.zoomInBtn:setVisible(zoom < BridgeAppearance.ZOOM_MAX) end
    if self.zoomOutBtn ~= nil then self.zoomOutBtn:setVisible(zoom > BridgeAppearance.ZOOM_MIN) end
end

function BridgeAppearance.Window:applyTabZoom(key)
    local z = BridgeAppearance.ZOOM[key]
    if z == nil then z = 0 end
    self:setZoom(z)
end

function BridgeAppearance.Window:onZoomIn()
    self:setZoom((self.zoom or 0) + BridgeAppearance.ZOOM_STEP)
end

function BridgeAppearance.Window:onZoomOut()
    self:setZoom((self.zoom or 0) - BridgeAppearance.ZOOM_STEP)
end

function BridgeAppearance.Window:update()
    ISCollapsableWindow.update(self)
    local v = nil
    pcall(function() v = self.panel:getActiveView() end)
    if v ~= nil and v ~= self.lastView then
        self.lastView = v
        self:applyTabZoom(v.tabKey)
    end
    if self.lookCombo ~= nil then self:refreshLookButtons() end
end

function BridgeAppearance.Window:refresh()
    if self.bodyView ~= nil then self.bodyView:refresh() end
    if self.faceView ~= nil then self.faceView:refresh() end
    if self.hairView ~= nil then self.hairView:refresh() end
    if self.detailView ~= nil then self.detailView:refresh() end
    if self.makeupView ~= nil then self.makeupView:refresh() end
end

function BridgeAppearance.Window:tabName(which)
    if which == "body" then return tr("AppearanceBody") end
    if which == "face" then return tr("AppearanceFace") end
    if which == "details" then return tr("AppearanceDetails") end
    if which == "makeup" then return tr("AppearanceMakeup") end
    return tr("AppearanceHair")
end

function BridgeAppearance.Window:selectTab(which)
    local name = self:tabName(which)
    pcall(function() self.panel:activateView(name) end)
end

function BridgeAppearance.Window:refreshLookButtons()
    local combo = self.lookCombo
    local name = nil
    if combo ~= nil and type(combo.options) == "table" and type(combo.selected) == "number" then
        name = combo.options[combo.selected]
    end
    local del = self.deleteBtn
    if del ~= nil and del.setEnable ~= nil then
        local ok = type(name) == "string" and BridgeLooks ~= nil and BridgeLooks.canDelete(name) == true
        del:setEnable(ok)
    end
    local save = self.saveBtn
    if save ~= nil and save.setEnable ~= nil then
        save:setEnable(BridgeLooks ~= nil and BridgeLooks.locked ~= nil and BridgeLooks.locked() ~= true)
    end
end

function BridgeAppearance.Window:refreshLooks()
    local combo = self.lookCombo
    if combo == nil or BridgeLooks == nil or type(combo.addOption) ~= "function" then return end
    local keep = nil
    if type(combo.options) == "table" and type(combo.selected) == "number" then
        keep = combo.options[combo.selected]
    end
    self.fillingLooks = true
    combo.options = {}
    combo.selected = 0
    local list = BridgeLooks.all()
    if type(list) == "table" then
        for i = 1, #list do
            local look = list[i]
            if type(look) == "table" and type(look.name) == "string" then combo:addOption(look.name) end
        end
    end
    combo.selected = 0
    if type(keep) == "string" and type(combo.options) == "table" then
        for i = 1, #combo.options do
            if combo.options[i] == keep then combo.selected = i break end
        end
    end
    self.fillingLooks = false
    self:refreshLookButtons()
end

function BridgeAppearance.Window:selectedLook()
    local combo = self.lookCombo
    if combo == nil or type(combo.options) ~= "table" or type(combo.selected) ~= "number" then return nil end
    local name = combo.options[combo.selected]
    if type(name) ~= "string" then return nil end
    return name
end

function BridgeAppearance.Window:selectLook(name)
    local combo = self.lookCombo
    if combo == nil or type(combo.options) ~= "table" then return end
    combo.selected = 0
    if type(name) ~= "string" then return end
    for i = 1, #combo.options do
        if combo.options[i] == name then combo.selected = i return end
    end
end



function BridgeAppearance.Window:syncLook()
    if BridgeLooks == nil or self.lookCombo == nil then return end
    self:selectLook(BridgeLooks.current(BridgeAppearance.candidate))
    self:refreshLookButtons()
end

function BridgeAppearance.Window:onLook(combo)
    if self.fillingLooks then return end
    if combo == nil or type(combo.options) ~= "table" or BridgeLooks == nil then return end
    local name = combo.options[combo.selected]
    if type(name) ~= "string" or BridgeAppearance.candidate == nil then return end
    local look = BridgeLooks.find(name)
    if look == nil then return end
    BridgeLooks.applyTo(look, BridgeAppearance.candidate)
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
    self:refreshLookButtons()
end

function BridgeAppearance.Window:saveValidate(text)
    if BridgeLooks == nil then return false end
    local name = BridgeLooks.cleanName(text)
    return name ~= nil and not BridgeLooks.isBuiltin(name)
end

function BridgeAppearance.Window:onSave()
    if BridgeLooks == nil or BridgeLooks.locked() then return end
    if ISTextBox == nil then return end
    local text = self:selectedLook() or ""
    if BridgeLooks.isBuiltin(text) then text = "" end
    local modal = ISTextBox:new(0, 0, 280, 180, tr("LookPrompt"), text, self, BridgeAppearance.Window.onSaveDone)
    if type(modal.backgroundColor) == "table" then modal.backgroundColor.a = 0.9 end
    modal:initialise()
    modal:addToUIManager()
    if modal.entry ~= nil and modal.entry.setMaxTextLength ~= nil then modal.entry:setMaxTextLength(BridgeLooks.NAME_MAX) end
    if modal.setValidateFunction ~= nil then modal:setValidateFunction(self, BridgeAppearance.Window.saveValidate) end
end

function BridgeAppearance.Window:onSaveDone(button)
    if button == nil or button.internal ~= "OK" or BridgeLooks == nil then return end
    local text = nil
    if button.parent ~= nil and button.parent.entry ~= nil and button.parent.entry.getText ~= nil then
        text = button.parent.entry:getText()
    end
    local look = BridgeLooks.save(text, BridgeAppearance.candidate)
    if look == nil then return end
    self:refreshLooks()
    self:selectLook(look.name)
    self:refreshLookButtons()
end

function BridgeAppearance.Window:onDelete()
    local combo = self.lookCombo
    if combo == nil or type(combo.options) ~= "table" or BridgeLooks == nil or ISModalDialog == nil then return end
    local name = combo.options[combo.selected]
    if type(name) ~= "string" or not BridgeLooks.canDelete(name) then return end
    self.deleteName = name
    local prompt = "Delete \"" .. name .. "\"?"
    if type(getText) == "function" then
        local t = getText("UI_characreation_BuildDeletePrompt", name)
        if type(t) == "string" and t ~= "" and t ~= "UI_characreation_BuildDeletePrompt" then prompt = t end
    end
    local sw, sh = 800, 600
    if type(getCore) == "function" then
        local core = getCore()
        if core ~= nil and core.getScreenWidth ~= nil then sw = core:getScreenWidth() end
        if core ~= nil and core.getScreenHeight ~= nil then sh = core:getScreenHeight() end
    end
    local width = textW(UIFont.Small, prompt) + 48
    if width < 230 then width = 230 end
    if width > 480 then width = 480 end
    local modal = ISModalDialog:new((sw - width) / 2, (sh - 120) / 2, width, 120, prompt, true, self, BridgeAppearance.Window.onDeleteDone)
    if type(modal.backgroundColor) == "table" then modal.backgroundColor.a = 0.9 end
    modal:initialise()
    modal:addToUIManager()
    if modal.setCapture ~= nil then modal:setCapture(true) end
    if modal.setAlwaysOnTop ~= nil then modal:setAlwaysOnTop(true) end
end

function BridgeAppearance.Window:onDeleteDone(button)
    if button == nil or button.internal ~= "YES" or BridgeLooks == nil then return end
    local name = self.deleteName
    self.deleteName = nil
    if type(name) ~= "string" or not BridgeLooks.delete(name) then return end
    self:refreshLooks()
    self:syncLook()
end

function BridgeAppearance.Window:onApply()
    local c = BridgeAppearance.candidate
    if c.skin ~= nil then pcall(function() Bridge.setSkin(c.skin) end) end
    if c.hair ~= nil then pcall(function() Bridge.setHair(c.hair) end) end
    if c.hairColor ~= nil then
        pcall(function() Bridge.setHairColor(c.hairColor.r, c.hairColor.g, c.hairColor.b) end)
    end
    if BridgeData.spnccFaces() ~= nil then
        pcall(function() Bridge.setFace(c.face) end)
    end
    if BridgeData.spnccMuscle() ~= nil then
        pcall(function() Bridge.setMuscle(c.muscle) end)
    end
    if BridgeData.spnccDetails() ~= nil then
        pcall(function() Bridge.setDetails(c.details) end)
    end
    if BridgeData.makeupList() ~= nil then
        pcall(function() Bridge.setMakeup(c.makeup) end)
    end
    if BridgeLooks ~= nil then BridgeLooks.remember(self:selectedLook()) end
end

function BridgeAppearance.Window:onClose()
    self:close()
end

function BridgeAppearance.Window:close()
    self:saveGeometry()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if BridgeAppearance.instance == self then BridgeAppearance.instance = nil end
end

function BridgeAppearance.Window:onMouseUp(x, y)
    ISCollapsableWindow.onMouseUp(self, x, y)
    self:saveGeometry()
end

function BridgeAppearance.Window:onMouseUpOutside(x, y)
    ISCollapsableWindow.onMouseUpOutside(self, x, y)
    self:saveGeometry()
end

function BridgeAppearance.Window:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor.a = 0.9
    o.minimumWidth = BridgeAppearance.MIN_WIDTH
    o.minimumHeight = BridgeAppearance.MIN_HEIGHT
    o:setResizable(true)
    o.title = tr("WindowAppearance")
    return o
end



BridgeAppearance.WIDTH = 620
BridgeAppearance.HEIGHT = 440
BridgeAppearance.MIN_WIDTH = 460
BridgeAppearance.MIN_HEIGHT = 320
BridgeAppearance.MAX_SCALE = 1.6

local GEO_KEY = "StayWithMeAppearanceWindow"

local function playerModData()
    local data = nil
    pcall(function()
        local p = nil
        if type(getSpecificPlayer) == "function" then p = getSpecificPlayer(0) end
        if p == nil and type(getPlayer) == "function" then p = getPlayer() end
        if p ~= nil then data = p:getModData() end
    end)
    return data
end

function BridgeAppearance.Window:saveGeometry()
    local data = playerModData()
    if data == nil then return end
    data[GEO_KEY] = { x = self:getX(), y = self:getY(), w = self:getWidth(), h = self:getHeight() }
end

local function loadGeometry()
    local data = playerModData()
    if data == nil or type(data[GEO_KEY]) ~= "table" then return nil end
    local g = data[GEO_KEY]
    if type(g.w) ~= "number" or type(g.h) ~= "number" then return nil end
    return g
end

function BridgeAppearance.open(tab)
    if Bridge == nil or Bridge.store == nil then return nil end
    if BridgeAppearance.instance ~= nil then
        BridgeAppearance.instance:selectTab(tab)
        return BridgeAppearance.instance
    end
    refreshFonts()
    local c = BridgeAppearance.candidate
    c.skin = BridgeData.skinOf(Bridge.store)
    c.hair = BridgeData.hairOf(Bridge.store)
    c.hairColor = copyColor(BridgeData.hairColorOf(Bridge.store))
    c.face = BridgeData.cleanFace(Bridge.store.face)
    c.details = BridgeData.cleanDetails(Bridge.store.details) or {}
    c.muscle = BridgeData.muscleOf(Bridge.store)
    c.makeup = BridgeData.makeupOf(Bridge.store)

    local sw, sh = 800, 600
    pcall(function() sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight() end)

    local ww, wh, xx, yy
    local g = loadGeometry()
    if g ~= nil then
        ww, wh, xx, yy = g.w, g.h, g.x, g.y
    else
        local scale = math.max(1, math.min(BridgeAppearance.MAX_SCALE, sh / 1080))
        ww = math.floor(BridgeAppearance.WIDTH * scale)
        wh = math.floor(BridgeAppearance.HEIGHT * scale)
    end
    ww = math.max(BridgeAppearance.MIN_WIDTH, math.min(ww, sw - PAD * 2))
    wh = math.max(BridgeAppearance.MIN_HEIGHT, math.min(wh, sh - PAD * 2))
    if type(xx) ~= "number" or type(yy) ~= "number" then
        xx = math.floor((sw - ww) / 2)
        yy = math.floor((sh - wh) / 2)
    end
    xx = math.max(0, math.min(xx, sw - ww))
    yy = math.max(0, math.min(yy, sh - wh))

    local w = BridgeAppearance.Window:new(xx, yy, ww, wh)
    w:initialise()
    w:addToUIManager()
    w:setVisible(true)
    BridgeAppearance.instance = w
    w:refresh()
    if w.refreshLooks ~= nil then w:refreshLooks() end
    if w.syncLook ~= nil then w:syncLook() end
    BridgeAppearance.refreshPreview()
    w:selectTab(tab)
    log("opened")
    return w
end

log("loaded")
