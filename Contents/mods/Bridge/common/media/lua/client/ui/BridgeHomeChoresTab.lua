require "ISUI/ISPanel"
require "ISUI/ISButton"
require "BridgeHome"

BridgeHomeChoresTab = ISPanel:derive("BridgeHomeChoresTab")

local PAD = 10

local function bodyFont()
    if BridgeWindow ~= nil and type(BridgeWindow.uiFonts) == "function" then
        local font = BridgeWindow.uiFonts()
        if font ~= nil then return font end
    end
    return UIFont.Small
end

local function tr(key, a)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key, a) end
    local text = key
    pcall(function()
        if a ~= nil then text = getText("IGUI_NotAlone_" .. key, a) else text = getText("IGUI_NotAlone_" .. key) end
    end)
    return text
end

local function btnH()
    return getTextManager():getFontHeight(bodyFont()) + 6
end

function BridgeHomeChoresTab.switchHeight()
    return PAD + btnH() + PAD
end

function BridgeHomeChoresTab.heightFor(width)
    local switchH = BridgeHomeChoresTab.switchHeight()
    local mode = BridgeWindow ~= nil and BridgeWindow.homeMode or "home"
    local pageH = nil
    if mode == "chores" then
        if BridgeChoresTab ~= nil and type(BridgeChoresTab.heightFor) == "function" then
            pageH = BridgeChoresTab.heightFor(width)
        end
    else
        if BridgeHomeTab ~= nil and type(BridgeHomeTab.heightFor) == "function" then
            pageH = BridgeHomeTab.heightFor(width)
        end
    end
    if type(pageH) ~= "number" or pageH <= 0 then
        pageH = BridgeWindow ~= nil and BridgeWindow.HEIGHT or 340
    end
    return switchH + pageH
end

function BridgeHomeChoresTab:createChildren()
    ISPanel.createChildren(self)
    local h = btnH()
    self.btnH = h
    local half = math.max(40, math.floor((self.width - PAD * 3) / 2))
    self.homeBtn = ISButton:new(PAD, PAD, half, h, tr("WindowHome"), self, BridgeHomeChoresTab.onModeHome)
    self.homeBtn:initialise()
    self.homeBtn:instantiate()
    self.homeBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self.homeBtn.tooltip = tr("HomeHint", Bridge.companionName())
    self:addChild(self.homeBtn)
    self.choresBtn = ISButton:new(PAD + half + PAD, PAD, half, h, tr("WindowChores"), self, BridgeHomeChoresTab.onModeChores)
    self.choresBtn:initialise()
    self.choresBtn:instantiate()
    self.choresBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.choresBtn)

    local switchH = BridgeHomeChoresTab.switchHeight()
    if BridgeHomeTab ~= nil then
        self.homePage = BridgeHomeTab:new(0, switchH, self.width, BridgeHomeTab.heightFor(self.width))
        self.homePage:initialise()
        self:addChild(self.homePage)
    end
    if BridgeChoresTab ~= nil then
        self.choresPage = BridgeChoresTab:new(0, switchH, self.width, BridgeChoresTab.heightFor(self.width))
        self.choresPage:initialise()
        self:addChild(self.choresPage)
    end
    self.mode = (BridgeWindow ~= nil and BridgeWindow.homeMode) or "home"
    self:applyMode()
end

function BridgeHomeChoresTab:applyMode()
    local store = self.mode == "chores"
    if self.homePage ~= nil then self.homePage:setVisible(not store) end
    if self.choresPage ~= nil then self.choresPage:setVisible(store) end
    local active = { r = 0.25, g = 0.45, b = 0.75, a = 0.55 }
    local idle = { r = 0.12, g = 0.12, b = 0.12, a = 0.35 }
    if self.homeBtn ~= nil then self.homeBtn.backgroundColor = store and idle or active end
    if self.choresBtn ~= nil then self.choresBtn.backgroundColor = store and active or idle end
    local switchH = BridgeHomeChoresTab.switchHeight()
    if self.homePage ~= nil then
        self.homePage:setX(0)
        self.homePage:setY(switchH)
        self.homePage:setWidth(self.width)
    end
    if self.choresPage ~= nil then
        self.choresPage:setX(0)
        self.choresPage:setY(switchH)
        self.choresPage:setWidth(self.width)
    end
end

function BridgeHomeChoresTab:setMode(mode)
    if mode ~= "home" and mode ~= "chores" then return end
    self.mode = mode
    if BridgeWindow ~= nil then BridgeWindow.homeMode = mode end
    self:applyMode()
    if BridgeWindow ~= nil and type(BridgeWindow.contentHeight) == "function" then
        self:applyHeight(BridgeWindow.contentHeight("homechores", self.width))
    end
end

function BridgeHomeChoresTab:applyHeight(h)
    self:setHeight(h)
    local switchH = BridgeHomeChoresTab.switchHeight()
    local pageH = math.max(0, h - switchH)
    if self.homePage ~= nil then
        self.homePage:setHeight(pageH)
        self.homePage:setY(switchH)
    end
    if self.choresPage ~= nil then
        self.choresPage:setHeight(pageH)
        self.choresPage:setY(switchH)
    end
end

function BridgeHomeChoresTab:onModeHome()
    self:setMode("home")
end

function BridgeHomeChoresTab:onModeChores()
    self:setMode("chores")
end

function BridgeHomeChoresTab:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end
