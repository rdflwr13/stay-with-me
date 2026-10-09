BridgeClothing = BridgeClothing or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeClothing] " .. tostring(text)) end end

local function install()
    if ISInventoryPaneContextMenu == nil then return end
    if ISInventoryPaneContextMenu.bridgeClothingWrapped then return end

    local tooltip = ISInventoryPaneContextMenu.doWearClothingTooltip
    if tooltip ~= nil then
        ISInventoryPaneContextMenu.doWearClothingTooltip = function(playerObj, newItem, currentItem, option)
            if newItem == nil then return end
            return tooltip(playerObj, newItem, currentItem, option)
        end
    end

    local onExtra = ISInventoryPaneContextMenu.onClothingItemExtra
    if onExtra ~= nil then
        ISInventoryPaneContextMenu.onClothingItemExtra = function(item, extra, playerObj)
            if extra == nil then return end
            local made = nil
            pcall(function() made = instanceItem(extra) end)
            if made == nil then return end
            return onExtra(item, extra, playerObj)
        end
    end

    ISInventoryPaneContextMenu.bridgeClothingWrapped = true
    log("clothing extra guard installed")
end

install()
Events.OnGameStart.Add(install)
