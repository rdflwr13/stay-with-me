
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISRichTextPanel"

BridgeNews = BridgeNews or {}

BridgeNews.LAYOUT = 1
BridgeNews.MOD_ID = "Bridge"
BridgeNews.FILE = "ChangeLog.txt"
BridgeNews.SEEN_FILE = "bridge/news.txt"
BridgeNews.DELAY_TICKS = 120

BridgeNews.PAD = 12
BridgeNews.HEADER_H = 36
BridgeNews.FOOTER_H = 42
BridgeNews.POSTER = 132
BridgeNews.MAX_W = 600
BridgeNews.MAX_H = 440

local C_WINDOW = { r = 0.141, g = 0.110, b = 0.078 }
local C_HEADER = { r = 0.239, g = 0.180, b = 0.118 }
local C_BORDER = { r = 0.549, g = 0.443, b = 0.278 }
local C_TITLE  = { r = 1.000, g = 0.839, b = 0.471 }
local C_BODY   = { r = 0.902, g = 0.878, b = 0.839 }
local C_FRAME  = { r = 0.851, g = 0.780, b = 0.620 }

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeNews] " .. tostring(text)) end
end

local function warn(text)
    print("[BridgeNews] " .. tostring(text))
end

local function tr(key, a, b)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then
        return BridgeData.text(key, a, b)
    end
    local text = key
    pcall(function()
        if b ~= nil then
            text = getText("IGUI_NotAlone_" .. key, a, b)
        elseif a ~= nil then
            text = getText("IGUI_NotAlone_" .. key, a)
        else
            text = getText("IGUI_NotAlone_" .. key)
        end
    end)
    return text
end

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

local function esc(text)
    text = tostring(text or "")
    text = string.gsub(text, "<", "&lt;")
    text = string.gsub(text, ">", "&gt;")
    return text
end

local function trim(text)
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function splitLines(text)
    local out = {}
    text = tostring(text or "")
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        out[#out + 1] = line
    end
    if #out > 0 and out[#out] == "" then out[#out] = nil end
    return out
end

local function hashText(text)
    text = tostring(text or "")
    local hash = 5381
    for i = 1, #text do
        hash = (hash * 33 + string.byte(text, i)) % 2147483648
    end
    return hash
end

local function btnH()
    local h = 18
    pcall(function() h = getTextManager():getFontHeight(UIFont.Small) + 6 end)
    return h
end

local function isServerMode()
    local v = false
    pcall(function() v = isServer() == true end)
    return v
end

local function isClientMode()
    local v = false
    pcall(function() v = isClient() == true end)
    return v
end

function BridgeNews.readFile()
    local sep = "/"
    pcall(function() sep = getFileSeparator() end)
    local candidates = {
        BridgeNews.FILE,
        "common" .. sep .. BridgeNews.FILE,
        "media" .. sep .. BridgeNews.FILE,
    }
    for i = 1, #candidates do
        local reader = nil
        pcall(function() reader = getModFileReader(BridgeNews.MOD_ID, candidates[i], false) end)
        if reader ~= nil then
            local lines = {}
            local ok = pcall(function()
                local guard = 0
                while guard < 20000 do
                    guard = guard + 1
                    local line = reader:readLine()
                    if line == nil then break end
                    lines[#lines + 1] = tostring(line)
                end
            end)
            pcall(function() reader:close() end)
            if ok and #lines > 0 then return table.concat(lines, "\n") end
        end
    end
    return nil
end

function BridgeNews.parse(text)
    if type(text) ~= "string" or text == "" then return nil end
    local pages = {}
    for title, body in string.gmatch(text, "%[ ([^%]]+)% ](.-)%[ ------ %]") do
        title = trim(title)
        if title ~= "" and title ~= "ALERT_CONFIG" then
            pages[#pages + 1] = { title = title, body = body }
        end
    end
    if #pages == 0 then return nil end
    local out = {}
    for i = #pages, 1, -1 do out[#out + 1] = pages[i] end
    return out
end

function BridgeNews.pageTags(sec)
    local out = {}
    local function add(...)
        for i = 1, select("#", ...) do out[#out + 1] = select(i, ...) end
    end

    add("<RGB:1,0.84,0.47>", "<SIZE:large>", esc(sec.title), "<LINE>")
    add("<LINE>")
    add("<RGB:0.90,0.88,0.84>", "<SIZE:small>")

    local lines = splitLines(sec.body)
    local trimmed = {}
    for i = 1, #lines do trimmed[i] = trim(lines[i]) end

    for i = 1, #trimmed do
        local line = trimmed[i]
        if line == "" then
            add("<LINE>")
        else
            local heading = false
            if string.sub(line, 1, 1) ~= "-" then
                for j = i + 1, #trimmed do
                    if trimmed[j] ~= "" then
                        heading = (string.sub(trimmed[j], 1, 1) == "-")
                        break
                    end
                end
            end
            if heading then
                add("<RGB:1,0.84,0.47>", esc(line), "<LINE>")
            elseif string.sub(line, 1, 1) == "-" then
                add("<RGB:0.72,0.70,0.66>", esc(line), "<LINE>")
            else
                add("<RGB:0.90,0.88,0.84>", esc(line), "<LINE>")
            end
        end
    end

    return table.concat(out, " ")
end

function BridgeNews.load()
    local text = BridgeNews.readFile()
    if text == nil then return nil end
    local pages = BridgeNews.parse(text)
    if pages == nil then return nil end
    return { pages = pages, marker = tostring(hashText(text)) }
end

function BridgeNews.seen()
    local out = nil
    pcall(function()
        local reader = getFileReader(BridgeNews.SEEN_FILE, false)
        if reader == nil then return end
        local line = reader:readLine()
        pcall(function() reader:close() end)
        if line ~= nil then out = tostring(line) end
    end)
    return out
end

function BridgeNews.writeSeen(marker)
    pcall(function()
        local writer = getFileWriter(BridgeNews.SEEN_FILE, true, false)
        if writer == nil then return end
        writer:write(tostring(marker) .. "\n")
        writer:close()
    end)
end

function BridgeNews.posterTexture()
    if BridgeNews._poster ~= nil then return BridgeNews._poster or nil end
    local sep = "/"
    pcall(function() sep = getFileSeparator() end)
    local candidates = {}
    pcall(function()
        local mod = getModInfoByID(BridgeNews.MOD_ID)
        if mod == nil then return end
        local common = nil
        pcall(function() common = mod:getCommonDir() end)
        if common ~= nil then candidates[#candidates + 1] = common .. sep .. "poster.png" end
        local dir = nil
        pcall(function() dir = mod:getDir() end)
        if dir ~= nil then
            candidates[#candidates + 1] = dir .. sep .. "poster.png"
            candidates[#candidates + 1] = dir .. sep .. "common" .. sep .. "poster.png"
        end
    end)
    candidates[#candidates + 1] = "media/ui/BridgeNews/poster.png"
    candidates[#candidates + 1] = "media/ui/poster.png"
    candidates[#candidates + 1] = "media/ui/Sidebar/NotAlone_On_128.png"
    for i = 1, #candidates do
        local tex = nil
        pcall(function() tex = getTexture(candidates[i]) end)
        if tex ~= nil then
            BridgeNews._poster = tex
            return tex
        end
    end
    BridgeNews._poster = false
    return nil
end

function BridgeNews.version()
    local v = "?"
    pcall(function()
        local mod = getModInfoByID(BridgeNews.MOD_ID)
        if mod ~= nil then v = tostring(mod:getModVersion()) end
    end)
    return v
end



BridgeNewsWindow = ISPanel:derive("BridgeNewsWindow")

function BridgeNewsWindow:createChildren()
    ISPanel.createChildren(self)
    local PAD = BridgeNews.PAD
    local POSTER = BridgeNews.POSTER
    local HEADER_H = BridgeNews.HEADER_H
    local FOOTER_H = BridgeNews.FOOTER_H
    local BTN_H = btnH()

    self.poster = BridgeNews.posterTexture()

    local colX = PAD + POSTER + PAD
    local bodyX = colX + 1 + PAD
    local bodyY = HEADER_H + PAD
    local bodyW = self.width - bodyX - PAD
    local bodyH = self.height - HEADER_H - FOOTER_H - PAD * 2
    if bodyW < 80 then bodyW = 80 end
    if bodyH < 60 then bodyH = 60 end
    self.colX = colX

    self.body = ISRichTextPanel:new(bodyX, bodyY, bodyW, bodyH)
    self.body:initialise()
    self.body.autosetheight = false
    self.body.clip = true
    self.body.background = false
    self.body.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.body.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.body:setMargins(4, 4, 4, 4)
    self:addChild(self.body)
    self.body:addScrollBars()

    local btnY = self.height - FOOTER_H + (FOOTER_H - BTN_H) / 2
    local closeW = textW(UIFont.Small, tr("NewsClose")) + PAD * 2
    self.closeBtn = ISButton:new(self.width - PAD - closeW, btnY, closeW, BTN_H, tr("NewsClose"),
        self, BridgeNewsWindow.onClose)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self.closeBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.closeBtn)

    local gap = PAD / 2
    local nextX = self.closeBtn:getX() - gap - BTN_H
    local prevX = nextX - gap - BTN_H
    self.nextBtn = ISButton:new(nextX, btnY, BTN_H, BTN_H, "", self, BridgeNewsWindow.onNext)
    self.nextBtn:initialise()
    self.nextBtn:instantiate()
    self.nextBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self.nextBtn.tooltip = tr("NewsNext")
    pcall(function() self.nextBtn:setImage(getTexture("media/ui/arrow_right.png")) end)
    self:addChild(self.nextBtn)

    self.prevBtn = ISButton:new(prevX, btnY, BTN_H, BTN_H, "", self, BridgeNewsWindow.onPrev)
    self.prevBtn:initialise()
    self.prevBtn:instantiate()
    self.prevBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self.prevBtn.tooltip = tr("NewsPrev")
    pcall(function() self.prevBtn:setImage(getTexture("media/ui/arrow_left.png")) end)
    self:addChild(self.prevBtn)

    self:refresh()
end

function BridgeNewsWindow:refresh()
    local total = #(self.pages or {})
    local sec = (self.pages ~= nil) and self.pages[self.page] or nil
    if sec ~= nil and self.body ~= nil then
        self.body.text = BridgeNews.pageTags(sec)
        self.body:paginate()
        pcall(function() self.body:setYScroll(0) end)
    end
    if self.prevBtn ~= nil then self.prevBtn:setEnable(self.page > 1) end
    if self.nextBtn ~= nil then self.nextBtn:setEnable(self.page < total) end
end

function BridgeNewsWindow:setPage(n)
    local total = #(self.pages or {})
    if total == 0 then return end
    if n < 1 then n = 1 end
    if n > total then n = total end
    self.page = n
    self:refresh()
end

function BridgeNewsWindow:onPrev() self:setPage(self.page - 1) end
function BridgeNewsWindow:onNext() self:setPage(self.page + 1) end
function BridgeNewsWindow:onClose() self:close() end

function BridgeNewsWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function BridgeNewsWindow:onKeyRelease(key)
    if self:isVisible() and key == Keyboard.KEY_ESCAPE then
        self:close()
    end
end

function BridgeNewsWindow:prerender()
    ISPanel.prerender(self)
    local PAD = BridgeNews.PAD
    local POSTER = BridgeNews.POSTER
    local HEADER_H = BridgeNews.HEADER_H
    local FOOTER_H = BridgeNews.FOOTER_H
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local fontM = getTextManager():getFontHeight(UIFont.Medium)

    self:drawRect(0, 0, self.width, HEADER_H, 1, C_HEADER.r, C_HEADER.g, C_HEADER.b)
    self:drawRect(0, HEADER_H - 1, self.width, 1, 1, C_BORDER.r, C_BORDER.g, C_BORDER.b)
    local title = fitText(UIFont.Medium, tr("NewsTitle"), self.width - PAD * 2)
    self:drawText(title, PAD, (HEADER_H - fontM) / 2, C_TITLE.r, C_TITLE.g, C_TITLE.b, 1, UIFont.Medium)

    local px, py = PAD, HEADER_H + PAD
    self:drawRect(px - 3, py - 3, POSTER + 6, POSTER + 6, 1, C_FRAME.r, C_FRAME.g, C_FRAME.b)
    if self.poster ~= nil then
        self:drawTextureScaledAspect(self.poster, px, py, POSTER, POSTER, 1, 1, 1, 1)
    else
        self:drawRect(px, py, POSTER, POSTER, 1, 0.10, 0.08, 0.06)
    end
    self:drawRect(px - 2, py - 9, 30, 11, 0.5, 0.92, 0.92, 0.86)
    self:drawRect(px + POSTER - 28, py - 9, 30, 11, 0.5, 0.92, 0.92, 0.86)

    self:drawRect(self.colX, HEADER_H + PAD, 1, self.height - HEADER_H - FOOTER_H - PAD * 2,
        0.4, C_FRAME.r, C_FRAME.g, C_FRAME.b)

    local vY = py + POSTER + PAD
    self:drawText(tr("NewsVersion", BridgeNews.version()), PAD, vY,
        C_BODY.r, C_BODY.g, C_BODY.b, 1, UIFont.Small)
    local total = #(self.pages or {})
    self:drawText(tr("NewsPage", tostring(self.page), tostring(total)), PAD, vY + fontS + 2,
        C_TITLE.r, C_TITLE.g, C_TITLE.b, 1, UIFont.Small)

    self:drawRect(0, self.height - FOOTER_H, self.width, 1, 0.4, C_BORDER.r, C_BORDER.g, C_BORDER.b)
    local note = fitText(UIFont.Small, tr("NewsFooter"), self.width - PAD * 2 - 190)
    self:drawText(note, PAD, self.height - FOOTER_H + (FOOTER_H - fontS) / 2,
        C_BODY.r, C_BODY.g, C_BODY.b, 0.85, UIFont.Small)
end

function BridgeNewsWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if BridgeNews.instance == self then BridgeNews.instance = nil end

    if not isClientMode() then
        pcall(function()
            local c = UIManager.getSpeedControls()
            if c ~= nil then c:SetCurrentGameSpeed(1) end
        end)
        pcall(function() UIManager.setShowPausedMessage(true) end)
    end

    pcall(function()
        if self.player ~= nil and JoypadState ~= nil and JoypadState.players ~= nil
            and JoypadState.players[self.player + 1] ~= nil then
            setJoypadFocus(self.player, self.prevFocus)
        end
    end)
end

function BridgeNewsWindow:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.background = true
    o.backgroundColor = { r = C_WINDOW.r, g = C_WINDOW.g, b = C_WINDOW.b, a = 0.98 }
    o.borderColor = { r = C_BORDER.r, g = C_BORDER.g, b = C_BORDER.b, a = 1 }
    o.moveWithMouse = true
    o.page = 1
    o.pages = {}
    o.player = 0
    o.prevFocus = nil
    o:setWantKeyEvents(true)
    return o
end



function BridgeNews.show(force)
    if BridgeNews.instance ~= nil then return end
    if isServerMode() then return end

    local data, ok, err = nil, true, nil
    ok, err = pcall(function() data = BridgeNews.load() end)
    if not ok then warn("load failed: " .. tostring(err)) return end
    if data == nil then return end

    if not force then
        local seen = BridgeNews.seen()
        if seen ~= nil and seen == data.marker then return end
    end

    local sw, sh = 800, 600
    pcall(function() sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight() end)
    local W = math.min(BridgeNews.MAX_W, sw - 60)
    local H = math.min(BridgeNews.MAX_H, sh - 100)
    if W < 320 then W = math.max(320, sw - 20) end
    if H < 220 then H = math.max(220, sh - 20) end
    local x = math.floor((sw - W) / 2)
    local y = math.floor(math.min(sh * 0.16, 110))

    local w = BridgeNewsWindow:new(x, y, W, H)
    w.pages = data.pages
    w.marker = data.marker
    pcall(function() w.prevFocus = getJoypadFocus(0) end)
    w:initialise()
    w:addToUIManager()
    w:setVisible(true)
    BridgeNews.instance = w
    w:setPage(1)

    if not isClientMode() then
        pcall(function() UIManager.setShowPausedMessage(false) end)
        pcall(function()
            local c = UIManager.getSpeedControls()
            if c ~= nil then c:SetCurrentGameSpeed(0) end
        end)
    end

    if not force then BridgeNews.writeSeen(data.marker) end
    log("opened, " .. tostring(#data.pages) .. " page(s)")
end

function BridgeNews.open()
    BridgeNews.show(true)
end


if type(Events) == "table" then
    if Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function()
            BridgeNews.timer = BridgeNews.DELAY_TICKS
        end)
    end
    if Events.OnTick ~= nil then
        Events.OnTick.Add(function()
            local t = BridgeNews.timer
            if t == nil or t <= 0 then return end
            t = t - 1
            BridgeNews.timer = t
            if t <= 0 then pcall(BridgeNews.show) end
        end)
    end
end

log("loaded")
