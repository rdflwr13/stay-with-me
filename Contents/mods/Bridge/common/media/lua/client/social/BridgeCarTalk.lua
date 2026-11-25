
BridgeCarTalk = BridgeCarTalk or {}

pcall(function() require "Vehicles/ISUI/ISVehicleMenu" end)

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeCarTalk] " .. tostring(text)) end end


function BridgeCarTalk.with(playerObj)
    if playerObj == nil then return false end
    if BridgeCar == nil or type(BridgeCar.withRed) ~= "function" then return false end
    return BridgeCar.withRed(playerObj) == true
end


function BridgeCarTalk.open(playerObj)
    if playerObj == nil and BridgeData ~= nil and type(BridgeData.owner) == "function" then
        playerObj = BridgeData.owner()
    end
    BridgeCarTalk.pending = playerObj
end


local function showMenu(playerObj)
    if playerObj == nil then return end
    if BridgeMenu == nil or type(BridgeMenu.fill) ~= "function" then return end
    if not BridgeCarTalk.with(playerObj) then return end
    local pn = 0
    pcall(function() pn = playerObj:getPlayerNum() end)
    local x, y = 0, 0
    pcall(function()
        x = getPlayerScreenLeft(pn) + getPlayerScreenWidth(pn) / 2
        y = getPlayerScreenTop(pn) + getPlayerScreenHeight(pn) / 2
    end)
    local context = nil
    pcall(function() context = ISContextMenu.get(pn, x, y) end)
    if context == nil then return end
    BridgeMenu.fill(context, pn, true)
    log("talk menu opened from the vehicle wheel")
end


local function tick()
    local p = BridgeCarTalk.pending
    if p == nil then return end
    BridgeCarTalk.pending = nil
    pcall(showMenu, p)
end


function BridgeCarTalk.slice(playerObj)
    if BridgeCarTalk.off == true then return end
    if not BridgeCarTalk.with(playerObj) then log("wheel: she is not in this car, no slice") return end
    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    if menu == nil then return end
    if menu:isEmpty() == true then log("wheel: menu closed, no slice") return end
    local label = "Talk"
    if BridgeData ~= nil and type(BridgeData.text) == "function" then
        local t = BridgeData.text("Talk")
        if type(t) == "string" and t ~= "" then label = t end
    end
    local icon = getTexture("media/ui/Sidebar/NotAlone_On_48.png")
    menu:addSlice(label, icon, BridgeCarTalk.open, playerObj)
    log("wheel: Talk slice added")
end


if BridgeCarTalk.hooked ~= true then
    BridgeCarTalk.hooked = true
    if Events ~= nil and Events.OnTick ~= nil then Events.OnTick.Add(tick) end
end


if BridgeCarTalk.wrapped ~= true and ISVehicleMenu ~= nil and type(ISVehicleMenu.showRadialMenu) == "function" then
    BridgeCarTalk.wrapped = true
    local vanilla = ISVehicleMenu.showRadialMenu
    ISVehicleMenu.showRadialMenu = function(playerObj, ...)
        vanilla(playerObj, ...)
        if BridgeCarTalk.off == true then return end
        local ok, err = pcall(BridgeCarTalk.slice, playerObj)
        if not ok then
            BridgeCarTalk.off = true
            print("[BridgeCarTalk] wheel slice disabled for this session: " .. tostring(err))
        end
    end
    log("vehicle radial menu wrapped")
end

log("loaded")
