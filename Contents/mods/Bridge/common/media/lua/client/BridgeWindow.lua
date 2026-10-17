











require "ISUI/ISCollapsableWindow"
require "ISUI/ISTabPanel"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTickBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISUI3DModel"
require "ISUI/ISToolTip"
require "BridgeOrder"
require "BridgeReport"
require "BridgeHome"

BridgeWindow = BridgeWindow or {}

local PAD = 10
local GROUP = PAD * 2
local ROW = 6
local BOX = 8
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



local CAP = {
    ["а"] = "А", ["б"] = "Б", ["в"] = "В", ["г"] = "Г", ["д"] = "Д", ["е"] = "Е", ["ё"] = "Ё",
    ["ж"] = "Ж", ["з"] = "З", ["и"] = "И", ["й"] = "Й", ["к"] = "К", ["л"] = "Л", ["м"] = "М",
    ["н"] = "Н", ["о"] = "О", ["п"] = "П", ["р"] = "Р", ["с"] = "С", ["т"] = "Т", ["у"] = "У",
    ["ф"] = "Ф", ["х"] = "Х", ["ц"] = "Ц", ["ч"] = "Ч", ["ш"] = "Ш", ["щ"] = "Щ", ["ъ"] = "Ъ",
    ["ы"] = "Ы", ["ь"] = "Ь", ["э"] = "Э", ["ю"] = "Ю", ["я"] = "Я",
}

local function capFirst(text)
    text = tostring(text or "")
    if text == "" then return text end
    local one = string.sub(text, 1, 1)
    local up = string.upper(one)
    if up ~= one then return up .. string.sub(text, 2) end
    if CAP[one] ~= nil then return CAP[one] .. string.sub(text, 2) end
    local two = string.sub(text, 1, 2)
    if CAP[two] ~= nil then return CAP[two] .. string.sub(text, 3) end
    return text
end

local function fitText(font, text, maxW)
    text = tostring(text or "")
    if maxW <= 0 or textW(font, text) <= maxW then return text end
    local n = string.len(text)
    while n > 0 and textW(font, string.sub(text, 1, n) .. "...") > maxW do
        local b = string.byte(text, n)
        if b ~= nil and b >= 128 and b < 192 then
            while n > 1 and string.byte(text, n) >= 128 and string.byte(text, n) < 192 do
                n = n - 1
            end
        end
        n = n - 1
    end
    if n < 1 then return "..." end
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



function BridgeWindow.makeDesc(st, furSpecies)
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
    local overrideFur = furSpecies ~= nil
    for _, rec in ipairs(BridgeWindow.wornRecords(st ~= nil and st.items or "")) do
        pcall(function()
            local item = instanceItem(rec.t)
            if item == nil then return end
            if overrideFur then
                local t = nil
                pcall(function() t = item:getType() end)
                if type(t) == "string" and string.sub(t, 1, 6) == "Furry_" then return end
            end
            BridgeItems.apply(item, rec)
            local loc = nil
            if item:IsClothing() then loc = item:getBodyLocation() end
            if loc == nil then loc = item:canBeEquipped() end
            if loc ~= nil then desc:setWornItem(loc, item) end
        end)
    end
    BridgeWindow.addCustomDesc(desc, st)
    if overrideFur and furSpecies ~= "Hooman" and type(FurManager) == "table"
        and type(FurManager.determineFurClothingName) == "function" then
        pcall(function()
            local id = FurManager.determineFurClothingName(BridgeData.isFemale(st), furSpecies)
            local item = instanceItem(id)
            if item ~= nil then
                local loc = item:getBodyLocation()
                if loc ~= nil then desc:setWornItem(loc, item) end
            end
        end)
    end
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
    self.appearBtn = ISButton:new(x, 0, w, BTN_H, change, self, BridgeWindowInfo.onAppearance)
    self.appearBtn:initialise()
    self.appearBtn:instantiate()
    self.appearBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.appearBtn)

    self.exerBtn = ISButton:new(x, 0, w, BTN_H, tr("Exercise"), self, BridgeWindowInfo.onExercise)
    self.exerBtn:initialise()
    self.exerBtn:instantiate()
    self.exerBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.exerBtn)
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
BridgeWindow.ROM_TICKS = { 20, 45, 75 }
BridgeWindow.REL_BAR_H = 8
BridgeWindow.ROM_COLOR = { 0.86, 0.46, 0.64 }
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
    local tier = BridgeData.relTier(rel)
    if tier == "Close" then tier = "Friend" end
    local c = BridgeWindow.REL_COLORS[tier] or BridgeWindow.REL_COLORS.Known
    return fill, c[1], c[2], c[3]
end


function BridgeWindow.romBar(rel)
    local r = rel ~= nil and tonumber(rel.r) or 0
    if r == nil or r ~= r then r = 0 end
    local fill = r / 100
    if fill < 0 then fill = 0 elseif fill > 1 then fill = 1 end
    local c = BridgeWindow.ROM_COLOR
    return fill, c[1], c[2], c[3]
end


function BridgeWindow.relRows()
    if BridgeSocial ~= nil and type(BridgeSocial.romanceOn) == "function" and BridgeSocial.romanceOn() then return 2 end
    return 1
end


function BridgeWindow.relBarsHeight()
    local rows = BridgeWindow.relRows()
    if rows < 1 then return 0 end
    return FONT_S * rows + ROW * (rows - 1)
end

function BridgeWindowInfo:drawBar(x, y, w, h, fill, cr, cg, cb, ticks)
    self:drawRect(x, y, w, h, 1, 0.12, 0.12, 0.12)
    local fillW = math.floor(w * fill)
    if fillW > 0 then self:drawRect(x, y, fillW, h, 1, cr, cg, cb) end
    for _, t in ipairs(ticks or {}) do
        self:drawRect(x + math.floor(w * t / 100), y, 1, h, 1, 0.05, 0.05, 0.05)
    end
    self:drawRectBorder(x, y, w, h, 1, 0.35, 0.35, 0.35)
end


BridgeWindow.REL_LABEL_GAP = 18

function BridgeWindow.relLane(w)
    local font = UIFont.Small
    local labelW = math.max(textW(font, tr("RelBarFriendly")), textW(font, tr("RelBarRomance"))) + BridgeWindow.REL_LABEL_GAP
    local barX = labelW + PAD
    local barW = w - barX
    if barW < 24 then barW = 24 end
    return barX, barW
end

function BridgeWindowInfo:drawRelRow(x, y, label, fill, cr, cg, cb, ticks, lane)
    local h = BridgeWindow.REL_BAR_H
    local barX, barW = lane[1], lane[2]
    local barY = y + math.floor((FONT_S - h) / 2)
    self:drawText(label, x, y, 1, 1, 1, 1, UIFont.Small)
    self:drawBar(x + barX, barY, barW, h, fill, cr, cg, cb, ticks)
end


function BridgeWindowInfo:drawRelBars(x, y, w)
    local rel = BridgeData.relOf(Bridge.store) or {}
    local barX, barW = BridgeWindow.relLane(w)
    local lane = { barX, barW }
    local step = FONT_S + ROW
    local fFill, fr, fg, fb = BridgeWindow.relBar(rel)
    self:drawRelRow(x, y, tr("RelBarFriendly"), fFill, fr, fg, fb, BridgeWindow.REL_TICKS, lane)
    local used = FONT_S
    if BridgeSocial ~= nil and type(BridgeSocial.romanceOn) == "function" and BridgeSocial.romanceOn() then
        local rFill, rr, rg, rb = BridgeWindow.romBar(rel)
        self:drawRelRow(x, y + step, tr("RelBarRomance"), rFill, rr, rg, rb, BridgeWindow.ROM_TICKS, lane)
        used = step + FONT_S
    end
    return used
end

function BridgeWindowInfo:drawEnds(x, y, w, label, value, lr, lg, lb, vr, vg, vb)
    local font = UIFont.Small
    local vw = textW(font, value)
    local lw = textW(font, label)
    local overflow = lw + PAD + vw - w
    if overflow > 0 then
        value = fitText(font, value, math.max(8, vw - overflow))
        vw = textW(font, value)
        overflow = lw + PAD + vw - w
        if overflow > 0 then label = fitText(font, label, math.max(8, lw - overflow)) end
    end
    self:drawText(label, x, y, lr, lg, lb, 1, font)
    self:drawTextRight(value, x + w, y, vr, vg, vb, 1, font)
    return FONT_S
end


function BridgeWindowInfo:drawKills()
    local y = self.avatarY + AVATAR_H + AVATAR_BORDER + 4
    self:drawEnds(self.avatarX, y, AVATAR_W, tr("Kills"), tostring(Bridge.store.kills or 0), 1, 1, 1, 0.6, 0.6, 0.6)
end


function BridgeWindowInfo:render()
    if Bridge == nil or Bridge.store == nil then return end
    local x, y = self.textX, PAD
    local colW = self.width - x - PAD
    self:drawText(fitText(UIFont.Medium, name(), colW), x, y, 1, 1, 1, 1, UIFont.Medium)
    y = y + FONT_M + 2
    self:drawRect(x, y, colW, 1, 1, 0.4, 0.4, 0.4)
    y = y + GROUP
    local place, tag = "", ""
    pcall(function() place, tag = BridgeMenu.statusParts(true) end)
    if tag ~= nil and tag ~= "" then tag = capFirst(tag) end
    self:drawEnds(x, y, colW, place, tag or "", 1, 1, 1, 0.6, 0.6, 0.6)
    y = y + FONT_S + ROW
    y = y + self:drawRelBars(x, y, colW) + PAD

    local present = BridgeMenu.isPresent()


    local inCar = BridgeCar ~= nil and BridgeCar.inCarForMenu()
    self.callBtn:setTitle((present or inCar) and tr("Goodbye") or tr("Call", name()))
    self.callBtn:setEnable(not inCar)
    self.callBtn:setY(y)
    y = y + BTN_H + GROUP

    local shown = tr("LookDefault")
    if BridgeLooks ~= nil and type(BridgeLooks.shown) == "function" then
        local n = BridgeLooks.shown(Bridge.store)
        if type(n) == "string" and n ~= "" then shown = n end
    end
    self:drawEnds(x, y, colW, tr("WindowAppearance"), shown, 1, 1, 1, 0.6, 0.6, 0.6)
    y = y + FONT_S + PAD
    local appear = self.appearBtn
    if type(appear) == "table" or type(appear) == "userdata" then
        if appear.setX ~= nil then appear:setX(x) end
        if appear.setWidth ~= nil then appear:setWidth(colW) end
        if appear.setY ~= nil then appear:setY(y) end
    end
    y = y + BTN_H + GROUP
    local count, tier, pct = 0, "", 0
    if BridgeExercise ~= nil then
        pcall(function() count = BridgeExercise.count(Bridge.store) end)
        pcall(function() tier = BridgeExercise.tierLabel(count) end)
        pcall(function() pct = math.floor((BridgeExercise.mult(Bridge.store) - 1) * 100 + 0.5) end)
    end
    local unit = tr("ExXpWord")
    if unit == nil or unit == "" or unit == "ExXpWord" or unit == "IGUI_NotAlone_ExXpWord" then unit = "XP" end
    local trained = tostring(tier or "") .. " (" .. string.format("+%d%% %s", pct, unit) .. ")"
    local blockH = BOX + FONT_S + ROW + FONT_S + ROW + BTN_H + BOX
    self:drawRect(x, y, colW, blockH, 0.4, 0.07, 0.07, 0.07)
    self:drawRectBorder(x, y, colW, blockH, 0.55, 0.32, 0.32, 0.32)
    local ix, iw = x + BOX, colW - BOX * 2
    local lineY = y + BOX
    self:drawEnds(ix, lineY, iw, tr("ExTrainingLevel"), trained, 1, 1, 1, 0.6, 0.6, 0.6)
    lineY = lineY + FONT_S + ROW
    self:drawEnds(ix, lineY, iw, tr("ExWorkouts"), tostring(count), 1, 1, 1, 0.6, 0.6, 0.6)
    lineY = lineY + FONT_S + ROW
    local btn = self.exerBtn
    if (type(btn) == "table" or type(btn) == "userdata") and btn.setY ~= nil then
        if btn.setX ~= nil then btn:setX(ix) end
        if btn.setWidth ~= nil then btn:setWidth(iw) end
        btn:setY(lineY)
        btn:setTitle(tr("Exercise"))
        local reason = nil
        if BridgeExercise ~= nil and BridgeExercise.blockReason ~= nil then
            pcall(function() reason = BridgeExercise.blockReason() end)
        end
        btn:setEnable(reason == nil)
        if reason == nil then
            btn.tooltip = tr("ExReadyNow")
        elseif reason == "cooldown" then
            local left = 0
            if BridgeExercise ~= nil and BridgeExercise.cooldownLeft ~= nil then
                pcall(function() left = BridgeExercise.cooldownLeft(Bridge.store) or 0 end)
            end
            btn.tooltip = tr("ExReadyIn", string.format("%.1f", tonumber(left) or 0))
        elseif reason == "tired" then
            btn.tooltip = tr("Say_ExerciseWinded")
        elseif reason == "combat" then
            btn.tooltip = tr("ExerciseCombatTip")
        else
            btn.tooltip = nil
        end
    end
    self:drawKills()
end

function BridgeWindowInfo:onExercise()
    if BridgeMenu ~= nil and BridgeMenu.onExercise ~= nil then BridgeMenu.onExercise() end
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
    { key = "relPopups", label = "OptRelPopups", tip = "OptRelPopupsTip" },
    { key = "fatigueBar", label = "OptFatigueBar", tip = "OptFatigueBarTip" },
    { key = "sitWithRed", label = "OptSitWithRed", tip = "OptSitWithRedTip" },
    { key = "exerciseWithMe", label = "OptExerciseWithMe", tip = "OptExerciseWithMeTip" },
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
    self.aimLabelY = y + math.floor((BTN_H - FONT_S) / 2)
    local aimLabelW = textW(UIFont.Small, tr("OptAimSense")) + PAD * 2
    local aimX = PAD + aimLabelW
    local aimW = self.width - PAD - aimX
    if aimW < BTN_H * 3 then aimW = BTN_H * 3 end
    self.aimCombo = ISComboBox:new(aimX, y, aimW, BTN_H, self, BridgeWindowSettings.onAimSense)
    self.aimCombo:initialise()
    for _, lvl in ipairs(BridgeData.AIM_LEVELS) do
        self.aimCombo:addOptionWithData(tr(lvl.label), lvl.value, tr(lvl.tip))
    end
    self:addChild(self.aimCombo)
    y = y + BTN_H + PAD
    local frame = BridgeWindow.settingsFrame(self.width)
    self.frameX, self.frameY, self.frameW, self.frameH = frame.x, y, frame.w, frame.h
    self.colW = frame.col
    self.nameLabelX, self.nameLabelY = frame.left, y + frame.labelDy
    self.genderLabelX, self.genderLabelY = frame.right, y + frame.labelDy
    local ctrlY = y + frame.ctrlDy
    self.renameBtn = ISButton:new(frame.left, ctrlY, frame.col, BTN_H, tr("Rename"), self, BridgeWindowSettings.onRename)
    self.renameBtn:initialise()
    self.renameBtn:instantiate()
    self.renameBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.renameBtn)

    self.genderCombo = ISComboBox:new(frame.right, ctrlY, frame.col, BTN_H, self, BridgeWindowSettings.onGender)
    self.genderCombo:initialise()
    self.genderCombo:addOptionWithData(tr("GenderFemale"), "female")
    self.genderCombo:addOptionWithData(tr("GenderMale"), "male")
    self:addChild(self.genderCombo)

    self.newsY = y + frame.h + PAD
    local newsLabel = tr("NewsButton")
    local nbw = getTextManager():MeasureStringX(UIFont.Small, newsLabel) + PAD * 2
    self.newsBtn = ISButton:new(PAD, self.newsY, nbw, BTN_H, newsLabel, self, BridgeWindowSettings.onNews)
    self.newsBtn:initialise()
    self.newsBtn:instantiate()
    self.newsBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.newsBtn)
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
    if self.aimCombo ~= nil then
        local s = BridgeData.aimSense(Bridge.store)
        if self.aimCombo:getSelectedData() ~= s then self.aimCombo:selectData(s) end
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
    if self.frameY == nil then return end
    self:drawRect(self.frameX, self.frameY, self.frameW, self.frameH, 0.4, 0.07, 0.07, 0.07)
    self:drawRectBorder(self.frameX, self.frameY, self.frameW, self.frameH, 0.55, 0.32, 0.32, 0.32)
    local col = self.colW or 0
    self:drawText(fitText(UIFont.Small, tr("WindowName") .. " " .. name(), col), self.nameLabelX, self.nameLabelY, 1, 1, 1, 1, UIFont.Small)
    self:drawText(fitText(UIFont.Small, tr("Gender"), col), self.genderLabelX, self.genderLabelY, 1, 1, 1, 1, UIFont.Small)
    if self.aimLabelY ~= nil then
        self:drawText(fitText(UIFont.Small, tr("OptAimSense"), self.width - PAD * 2), PAD, self.aimLabelY, 1, 1, 1, 1, UIFont.Small)
    end
end

function BridgeWindowSettings:onTick(index, selected, key)
    Bridge.setOption(key, selected == true)
end

function BridgeWindowSettings:onGender(combo)
    if combo == nil then return end
    local g = combo:getSelectedData()
    if g ~= nil and Bridge ~= nil and type(Bridge.setGender) == "function" then Bridge.setGender(g) end
end

function BridgeWindowSettings:onAimSense(combo)
    if combo == nil then return end
    local v = combo:getSelectedData()
    if v ~= nil and Bridge ~= nil and type(Bridge.setAimSense) == "function" then Bridge.setAimSense(v) end
end

function BridgeWindowSettings:onRename()
    BridgeMenu.onRename(0)
end

function BridgeWindowSettings:onNews()
    if BridgeNews ~= nil and type(BridgeNews.open) == "function" then pcall(BridgeNews.open) end
end

function BridgeWindowSettings:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end



BridgeWindow.LOOT_TICKS = {
    { key = "lootCorpses", label = "LootCorpses", tip = "LootCorpsesTip" },
    { key = "lootVehicles", label = "LootVehicles", tip = "LootVehiclesTip" },
}

BridgeWindow.LOOT_WEIGHTS = { 0, 1, 2, 5, 10, 15, 20 }

local LOOT_ROW_PAD = 4

BridgeLootList = ISScrollingListBox:derive("BridgeLootList")

function BridgeLootList:new(x, y, width, height)
    local o = ISScrollingListBox:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.2 }
    o.drawBorder = true
    o.font = UIFont.Small
    o.fontHgt = getTextManager():getFontHeight(UIFont.Small)
    o.itemheight = math.max(o.fontHgt + LOOT_ROW_PAD * 2, 20)
    return o
end

function BridgeLootList:doDrawItem(y, item, alt)
    if not item.height then item.height = self.itemheight end
    local box = self.fontHgt
    local by = y + (item.height - box) / 2
    self:drawRectBorder(6, by, box, box, 1, 0.6, 0.6, 0.6)
    if item.on then self:drawRect(8, by + 2, box - 4, box - 4, 1, 0.72, 0.86, 0.62) end
    self:drawText(item.text, 6 + box + 8, y + (item.height - self.fontHgt) / 2, 1, 1, 1, 1, self.font)
    return y + item.height
end

function BridgeLootList:onMouseDown(x, y)
    local row = self:rowAt(x, y)
    if row < 1 or row > #self.items then return end
    local item = self.items[row]
    item.on = not item.on
    if type(self.onToggle) == "function" then self.onToggle(item) end
end


BridgeLootSettings = ISPanel:derive("BridgeLootSettings")

function BridgeLootSettings.heightFor(width)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = fontS + 6
    local rowH = math.max(fontS + LOOT_ROW_PAD * 2, 20)
    local listH = math.min(#BridgeData.LOOT_CATS * rowH + 4, 260)
    local controls = (btnH + PAD) * 2 + (fontS + 4) + btnH + PAD
    return PAD + listH + PAD + controls
end

function BridgeLootSettings:createChildren()
    ISPanel.createChildren(self)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = fontS + 6
    self.btnH = btnH
    local controls = (btnH + PAD) * 2 + (fontS + 4) + btnH + PAD
    local listH = math.max(btnH, self.height - PAD - PAD - controls)
    self.list = BridgeLootList:new(PAD, PAD, self.width - PAD * 2, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.onToggle = function(item) self:onToggleCat(item) end
    self:addChild(self.list)

    local ty = PAD + listH + PAD
    self.ticks = {}
    for i, entry in ipairs(BridgeWindow.LOOT_TICKS) do
        local tick = ISTickBox:new(PAD, ty, self.width - PAD * 2, btnH, "", self, BridgeLootSettings.onTick, entry.key)
        tick:initialise()
        tick:instantiate()
        tick:addOption(tr(entry.label))
        tick.tooltip = tr(entry.tip)
        self:addChild(tick)
        self.ticks[i] = tick
        ty = ty + btnH + PAD
    end
    self.weightLabelY = ty
    local cy = ty + fontS + 4
    self.weightCombo = ISComboBox:new(PAD, cy, self.width - PAD * 2, btnH, self, BridgeLootSettings.onWeight)
    self.weightCombo:initialise()
    for _, wv in ipairs(BridgeWindow.LOOT_WEIGHTS) do
        local label
        if wv <= 0 then label = tr("LootMaxWeightOff") else label = string.format("%g", wv) end
        self.weightCombo:addOptionWithData(label, wv)
    end
    self:addChild(self.weightCombo)

    self:refresh()
end

function BridgeLootSettings:refresh()
    local list = self.list
    if list == nil or Bridge == nil or Bridge.store == nil then return end
    local keep = list.selected
    list.items = {}
    list.count = 0
    list:setScrollHeight(0)
    for _, entry in ipairs(BridgeData.LOOT_CATS) do
        local on = true
        pcall(function() on = BridgeData.lootCatOn(Bridge.store, entry.id) end)
        local item = list:addItem(tr(entry.label), nil)
        item.id = entry.id
        item.on = on
        item.height = list.itemheight
    end
    if keep == nil or keep < 1 or keep > #list.items then keep = 1 end
    list.selected = keep
end

function BridgeLootSettings:prerender()
    ISPanel.prerender(self)
    if Bridge == nil or Bridge.store == nil then return end
    for i, entry in ipairs(BridgeWindow.LOOT_TICKS) do
        local want = BridgeData.lootOption(Bridge.store, entry.key)
        if self.ticks[i] ~= nil and self.ticks[i]:isSelected(1) ~= want then self.ticks[i]:setSelected(1, want) end
    end
    if self.weightCombo ~= nil then
        local w = BridgeData.lootMaxWeight(Bridge.store)
        if self.weightCombo:getSelectedData() ~= w then self.weightCombo:selectData(w) end
    end
end

function BridgeLootSettings:render()
    if Bridge == nil or Bridge.store == nil then return end
    self:drawText(tr("LootMaxWeight"), PAD, self.weightLabelY, 1, 1, 1, 1, UIFont.Small)
end

function BridgeLootSettings:onToggleCat(item)
    if item == nil or Bridge == nil or type(Bridge.setLootCat) ~= "function" then return end
    Bridge.setLootCat(item.id, item.on == true)
end

function BridgeLootSettings:onTick(index, selected, key)
    if Bridge ~= nil and type(Bridge.setLootOption) == "function" then Bridge.setLootOption(key, selected == true) end
end

function BridgeLootSettings:onWeight(combo)
    if combo == nil then return end
    local w = combo:getSelectedData()
    if w ~= nil and Bridge ~= nil and type(Bridge.setLootMaxWeight) == "function" then Bridge.setLootMaxWeight(w) end
end

function BridgeLootSettings:applyHeight(h)
    self:setHeight(h)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = self.btnH or (fontS + 6)
    local controls = (btnH + PAD) * 2 + (fontS + 4) + btnH + PAD
    local listH = h - PAD - PAD - controls
    if listH < 0 then listH = 0 end
    if self.list ~= nil then
        self.list:setHeight(listH)
    end
    local ty = PAD + listH + PAD
    for _, tick in ipairs(self.ticks or {}) do
        tick:setY(ty)
        ty = ty + btnH + PAD
    end
    self.weightLabelY = ty
    if self.weightCombo ~= nil then self.weightCombo:setY(ty + fontS + 4) end
end

function BridgeLootSettings:new(x, y, width, height)
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
    self.panel.target = self
    self.panel.onActivateView = function(target)
        if target ~= nil and target.fitHeight ~= nil then target:fitHeight() end
    end
    self:addChild(self.panel)
    local function page(kind, ctor)
        local h = BridgeWindow.contentHeight(kind, self.width)
        local view = ctor(0, self.panel.tabHeight, self.width, h)
        view:initialise()
        return view
    end
    self.info = page("info", function(x, y, w, h) return BridgeWindowInfo:new(x, y, w, h) end)
    self.panel:addView(tr("WindowInfo"), self.info)
    self.skills = nil
    if BridgeWindow.STATSMENU_ENABLE == 1 then
        self.skills = page("skills", function(x, y, w, h) return BridgeWindowSkills:new(x, y, w, h) end)
        self.panel:addView(tr("WindowSkills"), self.skills)
    end
    if BridgeHome ~= nil and BridgeHomeTab ~= nil then
        self.home = page("home", function(x, y, w, h) return BridgeHomeTab:new(x, y, w, h) end)
        self.panel:addView(tr("WindowHome"), self.home)
    end
    self.loot = page("loot", function(x, y, w, h) return BridgeLootSettings:new(x, y, w, h) end)
    self.panel:addView(tr("WindowLoot"), self.loot)
    self.order = page("order", function(x, y, w, h) return BridgeOrder:new(x, y, w, h) end)
    self.panel:addView(tr("WindowOrder"), self.order)
    self.settings = page("settings", function(x, y, w, h) return BridgeWindowSettings:new(x, y, w, h) end)
    self.panel:addView(tr("WindowSettings"), self.settings)
    self.report = nil
    if BridgeReport ~= nil and BridgeReportTab ~= nil then
        self.report = page("report", function(x, y, w, h) return BridgeReportTab:new(x, y, w, h) end)
        self.panel:addView(tr("WindowReport"), self.report)
    end
    self:fitHeight()
end

function BridgeWindowMain:prerender()

    self.title = ""
    self:fitHeight()
    ISCollapsableWindow.prerender(self)
end

function BridgeWindowMain:kindOf(view)
    if view == self.info then return "info" end
    if view == self.settings then return "settings" end
    if view == self.skills then return "skills" end
    if view == self.home then return "home" end
    if view == self.order then return "order" end
    if view == self.loot then return "loot" end
    if view == self.report then return "report" end
    return nil
end

function BridgeWindowMain:fitHeight()
    if self.panel == nil or self.panel.activeView == nil then return end
    local view = self.panel.activeView.view
    local kind = self:kindOf(view)
    if view == nil or kind == nil then return end
    local content = BridgeWindow.contentHeight(kind, self:getWidth())
    if type(content) ~= "number" or content <= 0 then return end
    content = math.ceil(content)
    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local y = view:getY()
    local tabH = self.panel.tabHeight or 0
    if y < tabH then y = tabH end
    local sh = getCore():getScreenHeight()
    local maxH = sh - PAD * 2
    local h = th + y + content + rh
    if h > maxH then
        h = maxH
        content = math.floor(h - th - y - rh)
        if content < 1 then content = 1 end
    end
    if view:getHeight() ~= content then
        if view.applyHeight ~= nil then view:applyHeight(content) else view:setHeight(content) end
    end
    h = math.ceil(th + y + view:getHeight() + rh)
    if h > maxH then h = maxH end
    if self:getHeight() ~= h then self:setHeight(h) end
    local panelH = self:getHeight() - th - rh
    if self.panel:getHeight() ~= panelH then self.panel:setHeight(panelH) end
    if self:getY() + self:getHeight() > sh - PAD then
        self:setY(math.max(0, sh - PAD - self:getHeight()))
    end
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



function BridgeWindow.infoHeight()
    refreshFonts()
    local text = PAD + FONT_M + 2 + GROUP
        + FONT_S + ROW
        + BridgeWindow.relBarsHeight() + PAD
        + BTN_H + GROUP
        + FONT_S + PAD + BTN_H + GROUP
        + BOX + FONT_S + ROW + FONT_S + ROW + BTN_H + BOX
        + PAD
    local avatar = PAD + 1 + AVATAR_BORDER + AVATAR_H + AVATAR_BORDER + 4 + FONT_S + PAD
    return math.max(text, avatar)
end

function BridgeWindow.settingsFrame(width)
    refreshFonts()
    local x = PAD
    local w = math.max(0, (width or 0) - PAD * 2)
    local inner = math.max(0, w - BOX * 2)
    local gap = PAD
    local col = math.floor((inner - gap) / 2)
    if col < 1 then col = 1 end
    return {
        x = x, w = w, h = BOX + FONT_S + ROW + BTN_H + BOX,
        left = x + BOX, right = x + BOX + col + gap, col = col,
        labelDy = BOX, ctrlDy = BOX + FONT_S + ROW,
    }
end

function BridgeWindow.settingsHeight()
    refreshFonts()
    local frameH = BOX + FONT_S + ROW + BTN_H + BOX
    local aimH = BTN_H + PAD
    return PAD + #BridgeWindow.TICKS * (BTN_H + PAD) + PAD + aimH + frameH + PAD + BTN_H + PAD
end

function BridgeWindow.contentHeight(kind, width)
    refreshFonts()
    local h = nil
    if kind == "info" then h = BridgeWindow.infoHeight()
    elseif kind == "settings" then h = BridgeWindow.settingsHeight()
    elseif kind == "skills" then h = BridgeWindow.skillsHeight()
    elseif kind == "home" and BridgeHomeTab ~= nil then h = BridgeHomeTab.heightFor(width)
    elseif kind == "order" and BridgeOrder ~= nil and BridgeOrder.heightFor ~= nil then h = BridgeOrder.heightFor(width)
    elseif kind == "loot" and BridgeLootSettings ~= nil then h = BridgeLootSettings.heightFor(width)
    elseif kind == "report" and BridgeReportTab ~= nil then h = BridgeReportTab.heightFor(width)
    end
    if type(h) ~= "number" or h ~= h or h <= 0 then return BridgeWindow.HEIGHT end
    return math.ceil(h)
end

function BridgeWindow.neededSize()
    refreshFonts()
    local textX = PAD + 1 + AVATAR_BORDER + AVATAR_W + AVATAR_BORDER + PAD
    local status = ""
    pcall(function() status = BridgeMenu.status(true) end)

    local lookLabel = tr("LookDefault")
    local tierW = 0
    for _, key in ipairs({ "ExTierUntrained", "ExTierWarmingUp", "ExTierRoutine", "ExTierDedicated", "ExTierAthletic", "ExTierPeak" }) do
        tierW = math.max(tierW, textW(UIFont.Small, tr(key)))
    end
    local colW = math.max(
        textW(UIFont.Medium, name()),
        textW(UIFont.Small, status),
        math.max(textW(UIFont.Small, tr("RelBarFriendly")), textW(UIFont.Small, tr("RelBarRomance"))) + BridgeWindow.REL_LABEL_GAP + PAD + 80,
        textW(UIFont.Small, tr("ExTrainingLevel")) + PAD + tierW + textW(UIFont.Small, " (+100% " .. tr("ExXpWord") .. ")") + BOX * 2,
        textW(UIFont.Small, tr("ExWorkouts")) + PAD + textW(UIFont.Small, "1000"),
        textW(UIFont.Small, tr("Goodbye")) + PAD * 2,
        textW(UIFont.Small, tr("Call", name())) + PAD * 2,
        textW(UIFont.Small, tr("WindowAppearance")) + PAD + textW(UIFont.Small, lookLabel),
        textW(UIFont.Small, getText("IGUI_PlayerStats_Change")) + PAD * 2)
    local w = textX + colW + PAD

    local gap = UI_BORDER_SPACING or 10
    for _, entry in ipairs(BridgeWindow.TICKS) do
        w = math.max(w, PAD * 2 + BTN_H + gap + textW(UIFont.Small, tr(entry.label)) + PAD)
    end
    w = math.max(w, PAD * 2 + textW(UIFont.Small, tr("OptAimSense")) + PAD * 4 + textW(UIFont.Small, tr("AimSensNormal")))
    w = math.max(w, PAD * 2 + textW(UIFont.Small, tr("WindowName") .. " " .. name()))
    w = math.max(w, PAD * 2 + textW(UIFont.Small, tr("WindowReport")))
    if BridgeWindow.STATSMENU_ENABLE == 1 then
        w = math.max(w, BridgeWindow.skillsWidth())
    end
    if BridgeLootSettings ~= nil then
        w = math.max(w, PAD * 2 + textW(UIFont.Small, tr("WindowLoot")))
    end
    if BridgeHomeTab ~= nil then
        w = math.max(w, PAD * 2 + textW(UIFont.Small, tr("WindowHome")))
        w = math.max(w, PAD * 2 + BTN_H + gap + textW(UIFont.Small, tr("OptHomeResources")) + PAD)
    end
    return math.max(BridgeWindow.WIDTH, math.ceil(w))
end


function BridgeWindow.toggle(x, y)
    if Bridge == nil or Bridge.store == nil then return nil end
    if BridgeWindow.instance ~= nil then
        BridgeWindow.instance:close()
        return nil
    end
    refreshFonts()
    local width = BridgeWindow.WIDTH
    local ok, err = pcall(function() width = BridgeWindow.neededSize() end)
    if not ok then warn("size failed: " .. tostring(err)) end
    local w = BridgeWindowMain:new(x or 100, y or 100, width, BridgeWindow.HEIGHT)

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
