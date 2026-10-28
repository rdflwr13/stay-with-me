require "ISUI/ISPanel"
require "ISUI/ISButton"

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
    local tm = getTextManager()
    local function fits(s) return tm:MeasureStringX(font, s) <= maxW end
    local lines, line = {}, ""
    local function flush()
        if line ~= "" then lines[#lines + 1] = line line = "" end
    end
    for word in string.gmatch(tostring(text or ""), "%S+") do
        if line ~= "" then
            if fits(line .. " " .. word) then line = line .. " " .. word else flush() end
        end
        if line == "" then
            while not fits(word) and #word > 1 do
                local cut = #word
                while cut > 1 and not fits(string.sub(word, 1, cut)) do cut = cut - 1 end
                lines[#lines + 1] = string.sub(word, 1, cut)
                word = string.sub(word, cut + 1)
            end
            line = word
        end
    end
    flush()
    if #lines == 0 then lines[1] = tostring(text or "") end
    return lines
end

local function safeValue(fn)
    local v = nil
    pcall(function() v = fn() end)
    if v == nil then return "-" end
    return tostring(v)
end


BridgeReport = BridgeReport or {}
BridgeReport.EVENTS_FILE = "bridge/events.txt"
BridgeReport.EVENTS_MAX = 200
BridgeReport.CONSOLE_PATH = "%UserProfile%\\Zomboid\\console.txt"
BridgeReport.BUG_PAGE = "https://steamcommunity.com/workshop/filedetails/discussion/3800989007/500617547938336972/"


function BridgeReport.stepLines(width)
    local out = {}
    local raw = {
        tr("ReportStep1a") .. " (" .. BridgeReport.CONSOLE_PATH .. ") " .. tr("ReportStep1b"),
        tr("ReportStep2"),
    }
    for _, s in ipairs(raw) do
        for _, l in ipairs(wrapText(UIFont.Small, s, width - PAD * 2)) do out[#out + 1] = l end
    end
    return out
end


function BridgeReport.logNoteLines(width)
    local out = {}
    for _, l in ipairs(wrapText(UIFont.Small, tr("ReportLogNote"), width - PAD * 2)) do out[#out + 1] = l end
    return out
end


function BridgeReport.isoNow()
    local base, zone = "-", ""
    pcall(function()
        base = os.date("%Y-%m-%dT%H:%M:%S")
        zone = os.date("%z") or ""
        if #zone == 5 then zone = string.sub(zone, 1, 3) .. ":" .. string.sub(zone, 4, 5) end
    end)
    return base .. zone
end


function BridgeReport.ingameNow()
    local s = "-"
    pcall(function()
        local gt = getGameTime()
        s = string.format("Y%d M%d D%d %02d:%02d", gt:getYear(), gt:getMonth() + 1, gt:getDay(), gt:getHour(), gt:getMinutes())
    end)
    return s
end


function BridgeReport.sessionId()
    if BridgeReport._session == nil then
        local id = nil
        pcall(function()
            if type(os) == "table" and type(os.date) == "function" then id = os.date("%y%m%d%H%M%S") end
        end)
        BridgeReport._session = id or "session"
    end
    return BridgeReport._session
end


function BridgeReport.gameMode()
    local mp, client, server = false, false, false
    pcall(function() mp = isMultiplayer() end)
    pcall(function() client = isClient() end)
    pcall(function() server = isServer() end)
    if not mp then return "SINGLEPLAYER" end
    if server then return "MULTIPLAYER (server)" end
    if client then return "MULTIPLAYER (client)" end
    return "MULTIPLAYER"
end


function BridgeReport.modVersion(id)
    local v = "?"
    pcall(function()
        local info = getModInfoByID(id)
        if info ~= nil then v = tostring(info:getModVersion()) end
    end)
    return v
end


function BridgeReport.sandboxPreset()
    local name = "-"
    pcall(function()
        local so = getSandboxOptions()
        if so ~= nil and type(so.getPresetName) == "function" then
            local n = so:getPresetName()
            if n ~= nil and tostring(n) ~= "" then name = tostring(n) end
        end
    end)
    return name
end


function BridgeReport.playerCell()
    local s = "-"
    pcall(function()
        local p = getPlayer()
        if p ~= nil then
            local sq = p:getSquare()
            if sq ~= nil then s = string.format("%d,%d,%d", sq:getX(), sq:getY(), sq:getZ()) end
        end
    end)
    return s
end


function BridgeReport.modList()
    local ids = {}
    pcall(function()
        local mods = getActivatedMods()
        for i = 0, mods:size() - 1 do
            ids[#ids + 1] = tostring(mods:get(i))
        end
    end)
    return ids
end


function BridgeReport.modIdLabel(id)
    id = tostring(id or "")
    if string.sub(id, 1, 1) == "\\" then id = string.sub(id, 2) end
    return id
end


function BridgeReport.modInfo(id)
    local name, ver, author, status = id, "?", "?", "?"
    pcall(function()
        local info = getModInfoByID(id)
        if info ~= nil then
            name = tostring(info:getName())
            ver = tostring(info:getModVersion())
            author = tostring(info:getAuthor())
            status = info:isAvailable() and "ok" or "unavailable"
        else
            status = "not found"
        end
    end)
    return name, ver, author, status
end


function BridgeReport.recentEvents(maxLines)
    local out = {}
    pcall(function()
        local reader = getFileReader(BridgeReport.EVENTS_FILE, false)
        if reader == nil then return end
        local all = {}
        while true do
            local l = reader:readLine()
            if l == nil then break end
            all[#all + 1] = l
            if #all > 5000 then table.remove(all, 1) end
        end
        reader:close()
        local start = math.max(1, #all - (maxLines or BridgeReport.EVENTS_MAX) + 1)
        for i = start, #all do
            local tick, kind, hex = string.match(all[i], "^(%d+)%s+(%S+)%s+(%S+)$")
            if tick ~= nil then
                local text = nil
                pcall(function() text = BridgeChat.fromHex(hex) end)
                out[#out + 1] = string.format("%s  %s  %s", tick, kind, tostring(text or hex))
            else
                out[#out + 1] = all[i]
            end
        end
    end)
    return out
end


function BridgeReport.generate()
    local out = {}
    local function line(s) out[#out + 1] = tostring(s) end
    local function section(name) line(""); line("[" .. name .. "]") end
    local function put(k, v) line(tostring(k) .. " = " .. tostring(v)) end

    line("=== Stay With Me - Bug Report ===")
    line("report_format = 1")
    line("generated = " .. BridgeReport.isoNow())
    line("session = " .. BridgeReport.sessionId())

    line("")
    line("[HOW TO SUBMIT]")
    line(tr("ReportStep1a") .. " (" .. BridgeReport.CONSOLE_PATH .. ") " .. tr("ReportStep1b"))
    line(tr("ReportStep2"))

    section("ENVIRONMENT")
    put("mod", "Stay With Me")
    put("mod_id", "Bridge")
    put("mod_version", BridgeReport.modVersion("Bridge"))
    put("game_version", safeValue(function() return getCore():getVersion() end))
    put("game_bullet", safeValue(function() return getCore():getBulletVersion() end))
    put("mode", BridgeReport.gameMode())
    put("language", safeValue(function() return Translator.getLanguage():name() end))

    section("SAVE")
    put("save", safeValue(function() return getWorld():getWorld() end))
    put("sandbox_preset", BridgeReport.sandboxPreset())
    put("world_age_days", safeValue(function() return string.format("%.1f", getGameTime():getWorldAgeHours() / 24) end))
    put("ingame_datetime", BridgeReport.ingameNow())
    put("cell", BridgeReport.playerCell())

    local ids = BridgeReport.modList()
    line("")
    line("[MODS] (N=" .. #ids .. ")")
    line("# name | version | author | status")
    if #ids == 0 then
        line("(none)")
    else
        for i, id in ipairs(ids) do
            local name, ver, author, status = BridgeReport.modInfo(id)
            if status == "not found" then
                line(string.format("%d. %s [not found]", i, BridgeReport.modIdLabel(id)))
            else
                line(string.format("%d. %s | %s | %s | %s", i, name, ver, author, status))
            end
        end
    end

    section("MOD_SETTINGS")
    local store = Bridge ~= nil and Bridge.store or nil
    local function opt(key)
        local v = nil
        pcall(function() v = BridgeData.optionOf(store, key) end)
        if v == nil then return "-" end
        return tostring(v)
    end
    put("combat", safeValue(function() return BridgeData.combatOf(store) end))
    put("follow", tostring(Bridge ~= nil and Bridge.follow or false))
    put("mode", tostring(Bridge ~= nil and Bridge.mode or "-"))
    put("mp", tostring(Bridge ~= nil and Bridge.mp or false))
    put("equip_scale", safeValue(function() return BridgeData.equipScale(store) end))
    for _, key in ipairs({ "autoHeal", "redKit", "gifts", "romance", "mood", "xpPopups", "relPopups", "fatigueBar" }) do
        put(key, opt(key))
    end

    section("SANDBOX")
    local SANDBOX_KEYS = {
        "Zombies", "Distribution", "ZombieRespawn", "ZombieMigrate",
        "ZombieLore.Speed", "ZombieLore.Strength", "ZombieLore.Toughness",
        "ZombieLore.Transmission", "ZombieLore.Mortality", "ZombieLore.Reanimate",
        "ZombieLore.Cognition", "ZombieLore.Memory", "ZombieLore.Sight",
        "ZombieLore.Hearing", "ZombieLore.ZombiesDragDown", "ZombieLore.ZombiesFenceLunge",
        "ZombieLore.DisableFakeDead", "ZombieConfig.PopulationMultiplier",
    }
    for _, key in ipairs(SANDBOX_KEYS) do
        local v = "-"
        pcall(function()
            local option = getSandboxOptions():getOptionByName(key)
            if option ~= nil then v = option:getValue() end
        end)
        put(key, v)
    end

    section("STATE")
    local stateLines = {}
    if Bridge ~= nil and type(Bridge.diagLines) == "function" then
        local ok, lines = pcall(Bridge.diagLines)
        if ok and type(lines) == "table" then stateLines = lines end
    end
    if #stateLines == 0 then
        line("(none)")
    else
        for _, l in ipairs(stateLines) do line(l) end
    end

    section("RECENT_ERRORS")
    line("# tick  ingame  source  count  first_tick..last_tick  message")
    local buf = Bridge ~= nil and Bridge.errBuf or {}
    if #buf == 0 then
        line("(none)")
    else
        for _, e in ipairs(buf) do
            line(string.format("%d  %s  %s  x%d  %d..%d  %s",
                tonumber(e.last_tick) or 0, tostring(e.ingame or "-"), tostring(e.source or "?"),
                tonumber(e.count) or 1, tonumber(e.first_tick) or 0, tonumber(e.last_tick) or 0, tostring(e.msg)))
        end
    end

    section("RECENT_EVENTS")
    line("# last " .. tostring(BridgeReport.EVENTS_MAX) .. " bridge/events.txt lines (hex-decoded)")
    local events = BridgeReport.recentEvents(BridgeReport.EVENTS_MAX)
    if #events == 0 then
        line("(none)")
    else
        for _, l in ipairs(events) do line(l) end
    end

    section("USER_NOTES")
    line("(none)")

    section("ATTACH")
    line("console.txt = %UserProfile%\\Zomboid\\console.txt")

    local text = table.concat(out, "\r\n") .. "\r\n"
    local stamp = "report"
    pcall(function()
        if type(os) == "table" and type(os.date) == "function" then stamp = os.date("%Y-%m-%d_%H-%M-%S") end
    end)
    local path = "bridge/bugreport_" .. stamp .. ".txt"
    local wrote, copied = false, false
    pcall(function()
        local writer = getFileWriter(path, true, false)
        writer:write(text)
        writer:close()
        wrote = true
    end)
    pcall(function()
        if Clipboard ~= nil and type(Clipboard.setClipboard) == "function" then
            Clipboard.setClipboard(text)
            copied = true
        end
    end)
    return text, path, wrote, copied
end


BridgeReportTab = ISPanel:derive("BridgeReportTab")

function BridgeReportTab.heightFor(width)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local stepH = #BridgeReport.stepLines(width) * (fontS + 2) + 4
    local noteH = #BridgeReport.logNoteLines(width) * (fontS + 2) + 4
    local btnH = fontS + 6
    return PAD + stepH + PAD + btnH + PAD / 2 + btnH + PAD / 2 + btnH + PAD / 2 + noteH + PAD + 4 * (fontS + 2) + PAD
end

function BridgeReportTab:createChildren()
    ISPanel.createChildren(self)
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local btnH = fontS + 6
    self.stepLines = BridgeReport.stepLines(self.width)
    local stepH = #self.stepLines * (fontS + 2) + 4
    local btnY = PAD + stepH + PAD
    self.btn = ISButton:new(PAD, btnY, self.width - PAD * 2, btnH, tr("ReportButton"), self, BridgeReportTab.onGenerate)
    self.btn:initialise()
    self.btn:instantiate()
    self.btn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.btn)
    local pageY = btnY + btnH + PAD / 2
    self.pageBtn = ISButton:new(PAD, pageY, self.width - PAD * 2, btnH, tr("ReportOpenPage"), self, BridgeReportTab.onOpenPage)
    self.pageBtn:initialise()
    self.pageBtn:instantiate()
    self.pageBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.pageBtn)
    local logY = pageY + btnH + PAD / 2
    self.logBtn = ISButton:new(PAD, logY, self.width - PAD * 2, btnH, BridgeReportTab.logLabel(), self, BridgeReportTab.onToggleLog)
    self.logBtn:initialise()
    self.logBtn:instantiate()
    self.logBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    self:addChild(self.logBtn)
    self.noteLines = BridgeReport.logNoteLines(self.width)
    self.noteY = logY + btnH + PAD / 2
    self.status = ""
    self.statusY = self.noteY + #self.noteLines * (fontS + 2) + PAD
end

function BridgeReportTab.logLabel()
    local on = Bridge ~= nil and Bridge.verbose == true
    return tr(on and "ReportLogOn" or "ReportLogOff")
end

function BridgeReportTab:onToggleLog()
    if Bridge == nil or type(Bridge.toggleVerbose) ~= "function" then return end
    Bridge.toggleVerbose()
    if self.logBtn ~= nil then self.logBtn:setTitle(BridgeReportTab.logLabel()) end
end

function BridgeReportTab:onOpenPage()
    local url = BridgeReport ~= nil and BridgeReport.BUG_PAGE or nil
    if url == nil then return end
    pcall(function()
        if type(isSteamOverlayEnabled) == "function" and isSteamOverlayEnabled()
            and type(activateSteamOverlayToWebPage) == "function" then
            activateSteamOverlayToWebPage(url)
        elseif type(openUrl) == "function" then
            openUrl(url)
        end
    end)
end

function BridgeReportTab:onGenerate()
    if BridgeReport == nil or type(BridgeReport.generate) ~= "function" then
        self.status = "Report generator unavailable."
        return
    end
    local ok, text, path, wrote, copied = pcall(BridgeReport.generate)
    if not ok then
        self.status = "error: " .. tostring(text)
        return
    end
    if wrote == false then
        self.status = "Could not write " .. tostring(path)
    elseif copied then
        self.status = tr("ReportDone", "Zomboid\\Lua\\" .. tostring(path))
    else
        self.status = "Zomboid\\Lua\\" .. tostring(path) .. " (clipboard unavailable)"
    end
end

function BridgeReportTab:prerender()
    ISPanel.prerender(self)
end

function BridgeReportTab:render()
    if Bridge == nil or Bridge.store == nil then return end
    local fontS = getTextManager():getFontHeight(UIFont.Small)
    local y = PAD
    for _, line in ipairs(self.stepLines or {}) do
        self:drawText(line, PAD, y, 0.85, 0.85, 0.85, 1, UIFont.Small)
        y = y + fontS + 2
    end
    y = self.noteY or y
    for _, line in ipairs(self.noteLines or {}) do
        self:drawText(line, PAD, y, 0.8, 0.8, 0.8, 1, UIFont.Small)
        y = y + fontS + 2
    end
    y = self.statusY or (y + PAD)
    local status = self.status or ""
    if status ~= "" then
        for _, line in ipairs(wrapText(UIFont.Small, status, self.width - PAD * 2)) do
            self:drawText(line, PAD, y, 0.75, 0.95, 0.75, 1, UIFont.Small)
            y = y + fontS + 2
        end
    end
end

function BridgeReportTab:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    return o
end
