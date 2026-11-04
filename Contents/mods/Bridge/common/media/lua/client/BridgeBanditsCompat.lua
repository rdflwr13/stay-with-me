BridgeBanditsCompat = BridgeBanditsCompat or {}

local OUTFIT = "Bedroom"
local SAFE = { Bedroom = true }

local checked = false
local on = false
local said = false

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeBandits] " .. tostring(text)) end
end

local function banditsPresent()
    if checked then return on end
    checked = true
    pcall(function()
        local mods = getActivatedMods()
        for i = 0, mods:size() - 1 do
            local id = tostring(mods:get(i))
            if id == "Bandits" or id == "Bandits2" then on = true end
        end
    end)
    if not on then
        pcall(function()
            if type(GetBanditClusterData) == "function" then on = true end
        end)
    end
    return on
end

function BridgeBanditsCompat.active()
    return banditsPresent()
end

function BridgeBanditsCompat.outfit()
    if not banditsPresent() then return "Naked" end
    if not said then
        said = true
        log("companion spawns in " .. OUTFIT .. ", the Bandits orphan sweep skips that outfit")
    end
    return OUTFIT
end

function BridgeBanditsCompat.isHerOutfit(z)
    if z == nil then return false end
    local name = nil
    pcall(function() name = z:getOutfitName() end)
    if name == "Naked" then return true end
    return banditsPresent() and name ~= nil and SAFE[name] == true
end
