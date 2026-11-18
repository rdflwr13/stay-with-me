BridgeCropGuard = BridgeCropGuard or {}
BridgeCropGuard.saved = BridgeCropGuard.saved or 0

local function logOnce()
    BridgeCropGuard.saved = BridgeCropGuard.saved + 1
    if BridgeCropGuard.saved ~= 1 then return end
    if BridgeLog ~= nil and BridgeLog.on() then
        print("[BridgeCropGuard] engine trample blocked (client hook active)")
    end
end

local function install()
    if CFarmingSystem == nil or type(CFarmingSystem.destroyPlant) ~= "function" then return false end
    if CFarmingSystem.destroyPlant == BridgeCropGuard.wrapped then return true end
    local wrapped = function(square)
        logOnce()
    end
    BridgeCropGuard.wrapped = wrapped
    CFarmingSystem.destroyPlant = wrapped
    return true
end

pcall(require, "Farming/CFarmingSystem")
pcall(install)
if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(install) end)
end
