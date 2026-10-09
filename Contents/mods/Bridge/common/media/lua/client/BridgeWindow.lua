











require "ISUI/ISCollapsableWindow"
require "ISUI/ISTabPanel"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTickBox"
require "ISUI/ISUI3DModel"
require "ISUI/ISToolTip"

BridgeWindow = BridgeWindow or {}

local PAD = 10
local AVATAR_BORDER = 2
local AVATAR_W, AVATAR_H = 128, 256


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
    local n = string.len(text)
    while n > 1 and textW(font, string.sub(text, 1, n) .. "...") > maxW do n = n - 1 end
    return string.sub(text, 1, n) .. "..."
end

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeWindow] " .. tostring(text)) end end
local function warn(text) print("[BridgeWindow] " .. tostring(text)) end

local function tr(key, a)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key, a) end
    local text = key
    pcall(function()
        if a ~= nil then text = getText("IGUI_NotAlone_" .. key, a) else text = getText("IGUI_NotAlone_" .. key) end
    end)
    return text
end

local function name() return Bridge.companionName() end




function BridgeWindow.wornRecords(encoded)
    local out = {}
    for _, rec in ipairs(BridgeItems.decode(encoded or "")) do
        if rec.p == nil and rec.w then out[#out + 1] = rec end
    end
    return out
end


function BridgeWindow.lookKey(st)
    local items = (st ~= nil and st.items) or ""
    local app = BridgeData.appearanceOf(st)
    local hc = BridgeData.hairColorOf(st)
    local bc = BridgeData.beardColorOf(st)
    return BridgeData.genderOf(st) .. "|" .. BridgeData.skinOf(st) .. "|" .. BridgeData.hairOf(st) .. "|"
        .. tostring(hc.r) .. "," .. tostring(hc.g) .. "," .. tostring(hc.b) .. "|"
        .. tostring(app ~= nil and app.face or "") .. "|" .. table.concat(BridgeData.cleanDetails(app ~= nil and app.details or nil, BridgeData.genderOf(st)) or {}, ",") .. "|"
        .. tostring(BridgeData.muscleOf(st)) .. "|" .. table.concat(BridgeData.makeupOf(st), ",") .. "|"
        .. tostring(BridgeData.beardOf(st)) .. "|"
        .. tostring(bc.r) .. "," .. tostring(bc.g) .. "," .. tostring(bc.b) .. "|"
        .. BridgeItems.lookKey(BridgeItems.decode(items))
end



function BridgeWindow.makeDesc(st)
    local desc = SurvivorFactory.CreateSurvivor()
    desc:setFemale(BridgeData.isFemale(st))
    pcall(function() desc:getWornItems():clear() end)
    local hv = desc:getHumanVisual()
    pcall(function() hv:clear() end)
    pcall(function() hv:setSkinTextureName(BridgeData.skinOf(st)) end)
    pcall(function() hv:setHairModel(BridgeData.hairOf(st)) end)
    local hc = BridgeData.hairColorOf(st)
    pcall(function() hv:setHairColor(ImmutableColor.new(hc.r, hc.g, hc.b)) end)
    pcall(function() hv:setBeardModel(BridgeData.beardOf(st)) end)
    local bc = BridgeData.beardColorOf(st)
    pcall(function() hv:setBeardColor(ImmutableColor.new(bc.r, bc.g, bc.b)) end)
    pcall(function() hv:setNaturalBeardColor(ImmutableColor.new(bc.r, bc.g, bc.b)) end)
    for _, rec in ipairs(BridgeWindow.wornRecords(st ~= nil and st.items or "")) do
        pcall(function()
            local item = instanceItem(rec.t)
            if item == nil then return end
            BridgeItems.apply(item, rec)
            local loc = nil
            if item:IsClothing() then loc = item:getBodyLocation() end
            if loc == nil then loc = item:canBeEquipped() end
            if loc ~= nil then desc:setWornItem(loc, item) end
        end)
    end
    BridgeWindow.addCustomDesc(desc, st)
    return desc
end


function BridgeWindow.addCustomDesc(desc, st)
    if desc == nil then return end
    BridgeWindow.missingCustom = BridgeWindow.missingCustom or {}
    local idx = BridgeData.skinIndex(st)
    local function add(id, texture)
        if type(id) ~= "string" or id == "" then return end
        pcall(function()
            local item = instanceItem(id)
            if item == nil then
                if not BridgeWindow.missingCustom[id] then
                    BridgeWindow.missingCustom[id] = true
                    warn("custom item type not found: " .. tostring(id))
                end
                return
            end
            local v = item:getVisual()
            if v ~= nil and texture ~= nil then v:setBaseTexture(texture) v:setTextureChoice(texture) end
            desc:setWornItem(item:getBodyLocation(), item)
        end)
    end
    if BridgeData.spnccOn(BridgeData.genderOf(st)) then
        local face = BridgeData.faceEntry(st)
        if face ~= nil then add(face.id, BridgeData.spnccTexture(face, idx)) end
        for _, d in ipairs(BridgeData.detailEntries(st)) do
            add(d.id, BridgeData.spnccTexture(d, idx))
        end
        local m = BridgeData.muscleOf(st)
        if m > 0 then
            local mid = BridgeData.spnccMuscle(BridgeData.genderOf(st))
            if mid ~= nil then add(mid, idx + (m == 2 and 5 or 0)) end
        end
    end
    for _, type in ipairs(BridgeData.makeupOf(st)) do
        add(type, nil)
    end
end



BridgeWindowInfo = ISPanel:derive("BridgeWindowInfo")

function BridgeWindowInfo:createChildren()
    ISPanel.createChildren(self)
    self.avatarX = PAD + 1 + AVATAR_BORDER
    self.avatarY = PAD + 1 + AVATAR_BORDER
    self.avatar = ISUI3DModel:new(self.avatarX, self.avatarY, AVATAR_W, AVATAR_H)
    self.avatar:initialise()
    self.avatar:instantiate()
    self:addChild(self.avatar)
    pcall(function() self.avatar:setState("idle") end)
    pcall(function() self.avatar:setDirection(IsoDirections.S) end)
    pcall(function() self.avatar:setIsometric(false) end)
    self.avatarBack = getTexture("media/ui/avatarBackgroundWhite.png")

    local x = self.avatarX + AVATAR_W + AVATAR_BORDER + PAD
    self.textX = x
    local w = self.width - x - PAD
    self.callBtn = ISButton:new(x, 0, w, BTN_H, "", self, BridgeWindowInfo.onCall)
    self.callBtn:initialise()
    self.callBtn:instantiate()
    self.callBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.callBtn)

    local change = getText("IGUI_PlayerStats_Change")
    local bw = getTextManager():MeasureStringX(UIFont.Small, change) + PAD * 2
    self.appearBtn = ISButton:new(self.width - PAD - bw, 0, bw, BTN_H, change, self, BridgeWindowInfo.onAppearance)
    self.appearBtn:initialise()
    self.appearBtn:instantiate()
    self.appearBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.appearBtn)
end


function BridgeWindowInfo:refreshAvatar()
    local st = Bridge.store
    local key = BridgeWindow.lookKey(st)
    if key == self.avatarKey then return end
    self.avatarKey = key
    local ok, err = pcall(function() self.avatar:setSurvivorDesc(BridgeWindow.makeDesc(st)) end)
    if not ok then warn("avatar failed: " .. tostring(err)) end
end

function BridgeWindowInfo:prerender()
    ISPanel.prerender(self)
    if Bridge == nil or Bridge.store == nil then return end
    self:refreshAvatar()
    self:drawRectBorder(self.avatarX - 2, self.avatarY - 2, AVATAR_W + 4, AVATAR_H + 4, 1, 0.3, 0.3, 0.3)
    self:drawTextureScaled(self.avatarBack, self.avatarX, self.avatarY, AVATAR_W, AVATAR_H, 1, 0.4, 0.4, 0.4)
end


function BridgeWindow.hairLabel(style)
    local text = nil
    pcall(function() text = getTextOrNull("IGUI_Hair_" .. tostring(style)) end)
    return text or tostring(style)
end




BridgeWindow.REL_TICKS = { 20, 45, 75 }
BridgeWindow.REL_BAR_H = 8
BridgeWindow.REL_COLORS = {
    Cold = { 0.38, 0.42, 0.50 },
    Known = { 0.50, 0.58, 0.68 },
    Pal = { 0.42, 0.62, 0.80 },
    Friend = { 0.62, 0.52, 0.82 },
    Close = { 0.86, 0.46, 0.64 },
}

function BridgeWindow.relBar(rel)
    local f = rel ~= nil and tonumber(rel.f) or 0
    if f == nil or f ~= f then f = 0 end
    local fill = f / 100
    if fill < 0 then fill = 0 elseif fill > 1 then fill = 1 end
    local c = BridgeWindow.REL_COLORS[BridgeData.relTier(rel)] or BridgeWindow.REL_COLORS.Known
    return fill, c[1], c[2], c[3]
end

function BridgeWindowInfo:drawRelBar(x, y, w)
    local fill, cr, cg, cb = BridgeWindow.relBar(BridgeData.relOf(Bridge.store))
    local h = BridgeWindow.REL_BAR_H
    self:drawRect(x, y, w, h, 1, 0.12, 0.12, 0.12)
    local fillW = math.floor(w * fill)
    if fillW > 0 then self:drawRect(x, y, fillW, h, 1, cr, cg, cb) end
    for _, t in ipairs(BridgeWindow.REL_TICKS) do
        self:drawRect(x + math.floor(w * t / 100), y, 1, h, 1, 0.05, 0.05, 0.05)
    end
    self:drawRectBorder(x, y, w, h, 1, 0.35, 0.35, 0.35)
end

function BridgeWindowInfo:render()
    if Bridge == nil or Bridge.store == nil then return end
    local x, y = self.textX, PAD
    local colW = self.width - x - PAD
    self:drawText(fitText(UIFont.Medium, name(), colW), x, y, 1, 1, 1, 1, UIFont.Medium)
    y = y + FONT_M + 2
    self:drawRect(x, y, colW, 1, 1, 0.4, 0.4, 0.4)
    y = y + PAD
    self:drawText(fitText(UIFont.Small, BridgeMenu.status(true), colW), x, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
    y = y + FONT_S + 4
    self:drawRelBar(x, y, colW)
    y = y + BridgeWindow.REL_BAR_H + PAD

    local present = BridgeMenu.isPresent()


    local inCar = BridgeCar ~= nil and BridgeCar.inCarForMenu()
    self.callBtn:setTitle((present or inCar) and tr("Goodbye") or tr("Call", name()))
    self.callBtn:setEnable(not inCar)
    self.callBtn:setY(y)
    y = y + BTN_H + PAD * 2

    self:drawText(tr("WindowAppearance"), x, y, 1, 1, 1, 1, UIFont.Small)
    local shown = tr("LookDefault")
    if BridgeLooks ~= nil and type(BridgeLooks.shown) == "function" then
        local n = BridgeLooks.shown(Bridge.store)
        if type(n) == "string" and n ~= "" then shown = n end
    end
    local lookX = x + textW(UIFont.Small, tr("WindowAppearance")) + PAD
    local appear = self.appearBtn
    local room = colW - (lookX - x)
    if type(appear) == "table" or type(appear) == "userdata" then
        if appear.getX ~= nil then room = appear:getX() - PAD - lookX end
        appear:setY(y - (BTN_H - FONT_S) / 2)
    end
    self:drawText(fitText(UIFont.Small, shown, room), lookX, y, 0.6, 0.6, 0.6, 1, UIFont.Small)


end

function BridgeWindowInfo:onCall()
    if BridgeCar ~= nil and BridgeCar.inCarForMenu() then return end
    if BridgeMenu.isPresent() then BridgeMenu.onGoodbye() else BridgeMenu.onCall() end
end


function BridgeWindow.hairStyles(gender)
    if gender == nil then gender = BridgeData.genderOf(Bridge.store) end
    local out = {}
    pcall(function()
        local inst = getHairStylesInstance()
        local all = nil
        if gender == "male" and type(inst.getAllMaleStyles) == "function" then
            all = inst:getAllMaleStyles()
        else
            all = inst:getAllFemaleStyles()
        end
        for i = 0, all:size() - 1 do
            local style = all:get(i)
            local id = style:getName()
            if id ~= nil and id ~= "" and not style:isNoChoose() and BridgeData.cleanHair(id) ~= nil then
                out[#out + 1] = { id = id, label = BridgeWindow.hairLabel(id) }
            end
        end
    end)



    local count = {}
    for _, e in ipairs(out) do count[e.label] = (count[e.label] or 0) + 1 end
    for _, e in ipairs(out) do
        if count[e.label] > 1 then e.label = e.label .. " (" .. e.id .. ")" end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

function BridgeWindow.beardStyles()
    local out = {}
    pcall(function()
        if type(getAllBeardStyles) ~= "function" then return end
        local all = getAllBeardStyles()
        if all == nil then return end
        for i = 0, all:size() - 1 do
            local id = all:get(i)
            local label
            if id == nil or id == "" then
                label = getText("IGUI_Beard_None")
            else
                label = getText("IGUI_Beard_" .. tostring(id))
            end
            out[#out + 1] = { id = id or "", label = label }
        end
    end)
    return out
end

function BridgeWindowInfo:onAppearance()
    if BridgeAppearance ~= nil then BridgeAppearance.open("body") end
end

function BridgeWindowInfo:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end



BridgeWindowSettings = ISPanel:derive("BridgeWindowSettings")


BridgeWindow.TICKS = {
    { key = "autoHeal", label = "OptAutoHeal", tip = "OptAutoHealTip" },

    { key = "redKit", label = "OptRedKit", tip = "OptRedKitTip" },
    { key = "hitMatters", label = "OptHitMatters", tip = "OptHitMattersTip" },
    { key = "gifts", label = "OptGifts", tip = "OptGiftsTip" },
    { key = "romance", label = "OptRomance", tip = "OptRomanceTip" },
    { key = "mood", label = "OptMood", tip = "OptMoodTip" },
    { key = "xpPopups", label = "OptXpPopups", tip = "OptXpPopupsTip" },
    { key = "fatigueBar", label = "OptFatigueBar", tip = "OptFatigueBarTip" },
}

function BridgeWindowSettings:createChildren()
    ISPanel.createChildren(self)
    local y = PAD
    self.ticks = {}
    for i, entry in ipairs(BridgeWindow.TICKS) do
        local tick = ISTickBox:new(PAD, y, self.width - PAD * 2, BTN_H, "", self, BridgeWindowSettings.onTick, entry.key)
        tick:initialise()
        tick:instantiate()
        tick:addOption(tr(entry.label))
        tick.tooltip = tr(entry.tip)
        self:addChild(tick)
        self.ticks[i] = tick
        y = y + math.max(BTN_H, tick:getHeight()) + PAD
    end
    y = y + PAD
    self.nameY = y
    local label = tr("Rename")
    local bw = getTextManager():MeasureStringX(UIFont.Small, label) + PAD * 2
    self.renameBtn = ISButton:new(PAD, y + FONT_S + PAD / 2, bw, BTN_H, label, self, BridgeWindowSettings.onRename)
    self.renameBtn:initialise()
    self.renameBtn:instantiate()
    self.renameBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.renameBtn)

    self.genderLabelY = y + FONT_S + PAD / 2 + BTN_H + PAD
    local gy = self.genderLabelY + FONT_S + 4
    self.genderCombo = ISComboBox:new(PAD, gy, self.width - PAD * 2, BTN_H, self, BridgeWindowSettings.onGender)
    self.genderCombo:initialise()
    self.genderCombo:addOptionWithData(tr("GenderFemale"), "female")
    self.genderCombo:addOptionWithData(tr("GenderMale"), "male")
    self:addChild(self.genderCombo)
end

function BridgeWindowSettings:prerender()
    ISPanel.prerender(self)
    if Bridge == nil or Bridge.store == nil then return end

    for i, entry in ipairs(BridgeWindow.TICKS) do
        local want = BridgeData.optionOf(Bridge.store, entry.key)
        if self.ticks[i]:isSelected(1) ~= want then self.ticks[i]:setSelected(1, want) end
    end
    if self.genderCombo ~= nil then
        local g = BridgeData.genderOf(Bridge.store)
        if self.genderCombo:getSelectedData() ~= g then self.genderCombo:selectData(g) end
    end

    local g = BridgeData.genderOf(Bridge.store)
    if self.lastGender ~= g then
        self.lastGender = g
        for i, entry in ipairs(BridgeWindow.TICKS) do
            local tick = self.ticks[i]
            local text = tr(entry.label)
            if type(tick.options) == "table" then tick.options[1] = text end
            if type(tick.optionsIndex) == "table" then tick.optionsIndex[1] = text end
            tick.tooltip = tr(entry.tip)
        end
    end
end

function BridgeWindowSettings:render()
    if Bridge == nil or Bridge.store == nil then return end
    self:drawText(tr("WindowName") .. " " .. name(), PAD, self.nameY, 1, 1, 1, 1, UIFont.Small)
    self:drawText(tr("Gender"), PAD, self.genderLabelY, 1, 1, 1, 1, UIFont.Small)
end

function BridgeWindowSettings:onTick(index, selected, key)
    Bridge.setOption(key, selected == true)
end

function BridgeWindowSettings:onGender(combo)
    if combo == nil then return end
    local g = combo:getSelectedData()
    if g ~= nil and Bridge ~= nil and type(Bridge.setGender) == "function" then Bridge.setGender(g) end
end

function BridgeWindowSettings:onRename()
    BridgeMenu.onRename(0)
end

function BridgeWindowSettings:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end






BridgeWindow.STATSMENU_ENABLE = 1


BridgeWindow.SKILLS = {
    { category = "IGUI_perks_Combat", rows = {
        { perk = "Axe" },
        { perk = "Blunt" },
        { perk = "SmallBlunt" },
        { perk = "LongBlade" },
        { perk = "SmallBlade" },
        { perk = "Spear" },
        { perk = "Maintenance" },
    }},
    { category = "IGUI_perks_PhysicalCategory", rows = {
        { perk = "Strength" },
        { perk = "Fitness" },
    }},
}

local SKILL_GAP = 2

local function skillUnit() return math.max(6, math.floor((FONT_S + 6) / 2)) end
local function skillRowH() return math.max(skillUnit() + 6, FONT_S + 6) end

local function gameText(key, fallback)
    local text = nil
    pcall(function() text = getTextOrNull(key) end)
    if text == nil or text == "" then return fallback or key end
    return text
end

function BridgeWindow.skillLabel(perk)
    return gameText("IGUI_perks_" .. perk, perk)
end



local function skillLevel(perk)
    if BridgeSkills ~= nil and BridgeSkills.level ~= nil then return BridgeSkills.level(perk) end
    return 0
end

local function skillProgress(perk)
    if BridgeSkills ~= nil and BridgeSkills.progress ~= nil then return BridgeSkills.progress(perk) end
    return 0
end


local function skillXp(perk)
    if BridgeSkills ~= nil and BridgeSkills.get ~= nil then return BridgeSkills.get(perk) end
    return 0
end

local function skillTotalForNext(perk)
    if BridgeSkills == nil or BridgeSkills.perkOf == nil or BridgeSkills.level == nil then return 0 end
    local p = BridgeSkills.perkOf(perk)
    if p == nil then return 0 end
    local lvl = BridgeSkills.level(perk)
    if lvl >= 10 then return 0 end
    local total = 0
    pcall(function() total = p:getTotalXpForLevel(lvl + 1) end)
    return total or 0
end


local GLOW_TICKS = 180
local function skillGlow(perk)
    if BridgeSkills == nil or BridgeSkills.lastLevelUp == nil then return 0 end
    local lu = BridgeSkills.lastLevelUp
    if lu.perk ~= perk then return 0 end
    local age = (Bridge.time or 0) - (lu.tick or 0)
    if age < 0 or age >= GLOW_TICKS then return 0 end
    return 1 - (age / GLOW_TICKS)
end

function BridgeWindow.skillsHeight()
    local h = PAD
    for _, group in ipairs(BridgeWindow.SKILLS) do
        h = h + FONT_M + 2 + PAD + #group.rows * skillRowH() + PAD
    end
    return h
end

function BridgeWindow.skillsWidth()
    local labelW = 0
    for _, group in ipairs(BridgeWindow.SKILLS) do
        for _, row in ipairs(group.rows) do
            labelW = math.max(labelW, textW(UIFont.Small, BridgeWindow.skillLabel(row.perk)))
        end
    end
    return PAD * 3 + labelW + (10 * skillUnit() + 9 * SKILL_GAP)
end


BridgeWindowSkills = ISPanel:derive("BridgeWindowSkills")

function BridgeWindowSkills:createChildren()
    ISPanel.createChildren(self)
    self.unit = skillUnit()
    self.rowH = skillRowH()
    self.labelW = 0
    for _, group in ipairs(BridgeWindow.SKILLS) do
        for _, row in ipairs(group.rows) do
            self.labelW = math.max(self.labelW, textW(UIFont.Small, BridgeWindow.skillLabel(row.perk)))
        end
    end
    self.barX = PAD + self.labelW + PAD
    self.barW = 10 * self.unit + 9 * SKILL_GAP
end

function BridgeWindowSkills:drawBar(x, y, level, xp)
    for i = 1, 10 do
        local ux = x + (i - 1) * (self.unit + SKILL_GAP)
        if i <= level then
            self:drawRect(ux, y, self.unit, self.unit, 1, 1, 0.89, 0.38)
            self:drawRectBorder(ux, y, self.unit, self.unit, 1, 1, 0.89, 0.38)
        elseif i == level + 1 then
            self:drawRectBorder(ux, y, self.unit, self.unit, 1, 0.4, 0.4, 0.4)
            local w = math.floor(self.unit * math.max(0, math.min(1, xp or 0)))

            if w > 0 then self:drawRect(ux, y, w, self.unit, 0.35, 1, 0.89, 0.38) end
        else
            self:drawRectBorder(ux, y, self.unit, self.unit, 1, 0.2, 0.2, 0.2)
        end
    end
end

function BridgeWindowSkills:render()
    self.unit = skillUnit()
    self.rowH = skillRowH()
    local x, y = PAD, PAD
    self.hitRows = {}
    for _, group in ipairs(BridgeWindow.SKILLS) do
        self:drawText(gameText(group.category, group.category), x, y, 1, 1, 1, 1, UIFont.Medium)
        y = y + FONT_M + 2
        self:drawRect(x, y, self.width - PAD * 2, 1, 1, 0.4, 0.4, 0.4)
        y = y + PAD
        for _, row in ipairs(group.rows) do
            local glow = skillGlow(row.perk)
            if glow > 0 then
                self:drawRect(x - 2, y, self.width - PAD * 2 + 4, self.rowH, glow * 0.45, 1, 0.89, 0.38)
            end
            local ty = y + (self.rowH - FONT_S) / 2
            self:drawText(BridgeWindow.skillLabel(row.perk), x, ty, 1, 1, 1, 1, UIFont.Small)
            self:drawBar(self.barX, y + (self.rowH - self.unit) / 2, skillLevel(row.perk), skillProgress(row.perk))
            self.hitRows[#self.hitRows + 1] = { row = row, y = y, h = self.rowH }
            y = y + self.rowH
        end
        y = y + PAD
    end
end

function BridgeWindowSkills:removeTooltip()
    if self.tooltip ~= nil then
        self.tooltip:setVisible(false)
        self.tooltip:removeFromUIManager()
        self.tooltip = nil
    end
end

function BridgeWindowSkills:showTooltip(row, lvl)
    local label = BridgeWindow.skillLabel(row.perk)
    local cur = skillLevel(row.perk)
    local msg = label .. " " .. gameText("IGUI_XP_level", "level") .. " " .. (lvl + 1)
    if lvl < cur then
        msg = msg .. " <LINE> " .. gameText("IGUI_XP_UnLocked", "Unlocked")
    elseif lvl == cur then
        local need = skillTotalForNext(row.perk)
        if need > 0 then
            msg = msg .. " <LINE> " .. string.format("%.0f / %.0f XP  (%.0f%%)",
                skillXp(row.perk), need, skillProgress(row.perk) * 100)
        else
            msg = msg .. " <LINE> " .. string.format("%.0f XP", skillXp(row.perk))
        end
    else
        msg = msg .. " <LINE> " .. gameText("IGUI_XP_Locked", "Locked")
    end
    local desc = gameText("IGUI_perks_" .. label .. "_Description", "")
    if desc ~= "" then msg = msg .. " <LINE><LINE> " .. desc end
    if self.tooltip == nil then
        self.tooltip = ISToolTip:new()
        self.tooltip:initialise()
        self.tooltip:addToUIManager()
        self.tooltip:setOwner(self)
    end
    self.tooltip.description = msg
end

function BridgeWindowSkills:onMouseMove(dx, dy)
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, e in ipairs(self.hitRows or {}) do
        if my >= e.y and my < e.y + e.h and mx >= self.barX and mx < self.barX + self.barW then
            local idx = math.floor((mx - self.barX) / (self.unit + SKILL_GAP))
            if idx >= 0 and idx <= 9 then
                self:showTooltip(e.row, idx)
                if self.tooltip ~= nil then
                    self.tooltip:setDesiredPosition(self:getAbsoluteX() + self.barX,
                        self:getAbsoluteY() + e.y + e.h + 4)
                end
                return
            end
        end
    end
    self:removeTooltip()
end

function BridgeWindowSkills:onMouseMoveOutside(dx, dy)
    self:removeTooltip()
end

function BridgeWindowSkills:setVisible(visible)
    if not visible then self:removeTooltip() end
    ISPanel.setVisible(self, visible)
end

function BridgeWindowSkills:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end



BridgeWindowMain = ISCollapsableWindow:derive("BridgeWindowMain")

function BridgeWindowMain:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    self.panel = ISTabPanel:new(0, th, self.width, self.height - th - rh)
    self.panel:initialise()
    self.panel.tabPadX = PAD
    self.panel.equalTabWidth = false
    self:addChild(self.panel)
    local inner = self.height - th - rh - self.panel.tabHeight
    self.info = BridgeWindowInfo:new(0, 8, self.width, inner)
    self.info:initialise()
    self.panel:addView(tr("WindowInfo"), self.info)
    self.skills = nil
    if BridgeWindow.STATSMENU_ENABLE == 1 then
        self.skills = BridgeWindowSkills:new(0, 8, self.width, inner)
        self.skills:initialise()
        self.panel:addView(tr("WindowSkills"), self.skills)
    end
    self.settings = BridgeWindowSettings:new(0, 8, self.width, inner)
    self.settings:initialise()
    self.panel:addView(tr("WindowSettings"), self.settings)
end

function BridgeWindowMain:prerender()

    self.title = ""
    ISCollapsableWindow.prerender(self)
end

function BridgeWindowMain:close()
    if self.skills ~= nil then self.skills:removeTooltip() end
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    BridgeWindow.instance = nil
end

function BridgeWindowMain:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor.a = 0.9
    o:setResizable(false)
    o.title = ""
    return o
end

BridgeWindow.WIDTH = 420
BridgeWindow.HEIGHT = 340



function BridgeWindow.neededSize()
    refreshFonts()
    local textX = PAD + 1 + AVATAR_BORDER + AVATAR_W + AVATAR_BORDER + PAD
    local status = ""
    pcall(function() status = BridgeMenu.status(true) end)

    local lookLabel = tr("LookDefault")
    local colW = math.max(
        textW(UIFont.Medium, name()),
        textW(UIFont.Small, status),
        textW(UIFont.Small, tr("Goodbye")) + PAD * 2,
        textW(UIFont.Small, tr("Call", name())) + PAD * 2,
        textW(UIFont.Small, tr("WindowAppearance")) + PAD + textW(UIFont.Small, lookLabel) + PAD + textW(UIFont.Small, getText("IGUI_PlayerStats_Change")) + PAD * 2)
    local w = textX + colW + PAD

    local gap = UI_BORDER_SPACING or 10
    for _, entry in ipairs(BridgeWindow.TICKS) do
        w = math.max(w, PAD * 2 + BTN_H + gap + textW(UIFont.Small, tr(entry.label)) + PAD)
    end
    w = math.max(w, PAD * 2 + textW(UIFont.Small, tr("WindowName") .. " " .. name()))
    local tickH = math.max(BTN_H, FONT_S) + gap
    local infoH = math.max(PAD * 2 + 2 + AVATAR_H + AVATAR_BORDER * 2,
        PAD + FONT_M + 2 + PAD + FONT_S + 4 + BridgeWindow.REL_BAR_H + PAD + BTN_H + PAD * 2 + BTN_H + PAD)
    local setH = PAD + #BridgeWindow.TICKS * (tickH + PAD) + PAD + FONT_S + PAD / 2 + BTN_H + PAD + FONT_S + 4 + BTN_H + PAD
    local contentH = math.max(infoH, setH)
    if BridgeWindow.STATSMENU_ENABLE == 1 then
        w = math.max(w, BridgeWindow.skillsWidth())
        contentH = math.max(contentH, BridgeWindow.skillsHeight())
    end
    return math.max(BridgeWindow.WIDTH, math.ceil(w)), math.ceil(contentH)
end


function BridgeWindow.toggle(x, y)
    if Bridge == nil or Bridge.store == nil then return nil end
    if BridgeWindow.instance ~= nil then
        BridgeWindow.instance:close()
        return nil
    end
    refreshFonts()
    local width, contentH = BridgeWindow.WIDTH, 0
    local ok, err = pcall(function() width, contentH = BridgeWindow.neededSize() end)
    if not ok then warn("size failed: " .. tostring(err)) end
    local w = BridgeWindowMain:new(x or 100, y or 100, width, BridgeWindow.HEIGHT)


    pcall(function()
        local h = w:titleBarHeight() + FONT_S + 6 + 8 + contentH + w:resizeWidgetHeight()
        w:setHeight(math.max(BridgeWindow.HEIGHT, math.ceil(h)))
    end)

    pcall(function()
        local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
        w:setX(math.max(0, math.min(w:getX(), sw - w:getWidth() - PAD)))
        w:setY(math.max(0, math.min(w:getY(), sh - w:getHeight() - PAD)))
    end)
    if Bridge.verbose then
        log(string.format("window %dx%d, font small %d medium %d", w:getWidth(), w:getHeight(), FONT_S, FONT_M))
    end
    w:initialise()
    w:addToUIManager()
    w:setVisible(true)
    BridgeWindow.instance = w
    return w
end

log("loaded")
