-- Viewpoint native interaction panel adapter for the Stay With Me companion.
-- The Java patch registers the companion as a Viewpoint PERSON target; this
-- file wraps ViewpointInteract.harvest and mirrors BridgeMenu.fill as rows.

BridgeViewpoint = BridgeViewpoint or {}

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeViewpoint] " .. tostring(text)) end
end

BridgeViewpoint.path = {}
BridgeViewpoint.originalHarvest = nil
BridgeViewpoint.installed = false

local function resetPath()
    BridgeViewpoint.path = {}
end

local function pushPath(index)
    local p = BridgeViewpoint.path
    p[#p + 1] = index
end

local function popPath()
    local p = BridgeViewpoint.path
    if #p > 0 then table.remove(p, #p) end
end

local function pageAt(root, path)
    local page = root
    for _, index in ipairs(path) do
        local options = page ~= nil and page.options or nil
        local option = options ~= nil and options[index] or nil
        if option == nil or option.subOption == nil then return nil end
        page = page:getSubMenu(option.subOption)
        if page == nil then return nil end
    end
    return page
end

local function iconFor(option)
    local icons = BridgeRadial ~= nil and BridgeRadial.ICONS or nil
    if icons == nil then return nil end
    if option ~= nil and option.iconTexture ~= nil and type(option.iconTexture) == "userdata" then
        return option.iconTexture
    end
    local map = {
        [BridgeMenu.onFollow] = "follow",
        [BridgeMenu.onWait] = "wait",
        [BridgeMenu.onCall] = "call",
        [BridgeMenu.onHeal] = "heal",
        [BridgeMenu.onRest] = "rest",
        [BridgeMenu.onHome] = "wait",
        [BridgeMenu.onExercise] = "exercise",
        [BridgeMenu.onWash] = "wash",
        [BridgeMenu.onEquip] = "equip",
        [BridgeMenu.onReport] = "talk",
        [BridgeMenu.onGoodbye] = "back",
    }
    local handler = option ~= nil and option.onSelect or nil
    local key = handler ~= nil and map[handler] or nil
    if key == nil and option ~= nil and option.name ~= nil then
        local n = tostring(option.name)
        if n:find("Follow", 1, true) then key = "follow"
        elseif n:find("Wait", 1, true) then key = "wait"
        elseif n:find("Heal", 1, true) then key = "heal"
        elseif n:find("Talk", 1, true) then key = "talk"
        elseif n:find("Work", 1, true) then key = "work"
        elseif n:find("Combat", 1, true) then key = "fight"
        elseif n:find("Gun", 1, true) then key = "guns"
        end
    end
    local path = key ~= nil and icons[key] or icons.fallback
    if path == nil then return nil end
    local tex = nil
    pcall(function() tex = getTexture(path) end)
    return tex
end

local function rowsFor(root)
    local path = BridgeViewpoint.path
    local page = pageAt(root, path)
    if page == nil then
        resetPath()
        page = root
    end
    local rows = {}
    if #path > 0 then
        rows[#rows + 1] = {
            name = getText("IGUI_NotAlone_Back") or "Back",
            fn = function() popPath() end,
            args = {}, n = 0, menu = true, enabled = true,
            icon = iconFor({ name = "Back" }),
        }
    end
    local options = page ~= nil and page.options or {}
    for i, option in ipairs(options) do
        local enabled = not option.notAvailable and not option.isDisabled
        if option.subOption ~= nil then
            local sub = page:getSubMenu(option.subOption)
            if sub ~= nil and (sub.options == nil or #sub.options > 0) then
                rows[#rows + 1] = {
                    name = option.name,
                    fn = function() pushPath(i) end,
                    args = {}, n = 0, menu = true, enabled = enabled,
                    tip = option.toolTip,
                    icon = iconFor(option),
                }
            end
        elseif option.onSelect ~= nil then
            rows[#rows + 1] = {
                name = option.name,
                fn = function()
                    resetPath()
                    option.onSelect(option.target, option.param1, option.param2, option.param3,
                        option.param4, option.param5, option.param6, option.param7,
                        option.param8, option.param9, option.param10)
                end,
                args = {}, n = 0, menu = true, enabled = enabled,
                tip = option.toolTip,
                icon = iconFor(option),
            }
        end
    end
    return rows, page
end

function BridgeViewpoint.harvest(player, object)
    local original = BridgeViewpoint.originalHarvest
    if object ~= Bridge.body or BridgeMenu == nil or not BridgeMenu.inTalkRange() then
        if original ~= nil then return original(player, object) end
        return { why = "not the companion" }
    end
    local playerNum = player:getPlayerNum()
    local open, why = ViewpointInteract.menu(playerNum)
    if not open then return { why = why } end
    local root = BridgeMenu.TreeContext.new()
    BridgeMenu.fill(root, playerNum, false)
    local rows = rowsFor(root)
    local title = nil
    if BridgeData ~= nil and type(BridgeData.nameOf) == "function" then
        pcall(function() title = BridgeData.nameOf(Bridge.store) end)
    end
    ViewpointInteract.target = { square = object:getSquare(), object = object }
    return ViewpointInteract.finish(rows, title, #rows)
end

function BridgeViewpoint.install()
    if BridgeViewpoint.installed then return end
    if ViewpointInteract == nil or type(ViewpointInteract.harvest) ~= "function" then return end
    BridgeViewpoint.originalHarvest = ViewpointInteract.harvest
    ViewpointInteract.harvest = BridgeViewpoint.harvest
    BridgeViewpoint.installed = true
    log("installed")
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(BridgeViewpoint.install)
end
if Events ~= nil and Events.OnPostUIDraw ~= nil then
    Events.OnPostUIDraw.Add(function()
        if not BridgeViewpoint.installed then BridgeViewpoint.install() end
    end)
end
