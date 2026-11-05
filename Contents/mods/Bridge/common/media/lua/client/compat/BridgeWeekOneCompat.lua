pcall(function() require "OptionScreens/CharacterCreationMain" end)

BridgeWeekOne = BridgeWeekOne or {}

local installed = false
local hookedSaid = false

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeWeekOne] " .. tostring(text)) end
end

local function weekOnePresent()
    return type(CharacterCreationMain) == "table"
        and type(CharacterCreationMain.onOptionMouseDown2) == "function"
end

local function hookVariant(self)
    if not weekOnePresent() then return false end
    local button = self ~= nil and self.variantButton or nil
    if type(button) ~= "table" then return false end
    if button.__bridgeWeekOneHooked then return true end

    local original = button.onclick
    if type(original) ~= "function" then return false end

    button.__bridgeWeekOneOriginal = original
    button.__bridgeWeekOneHooked = true
    button.onclick = function(target, pressed, ...)
        if BridgePregame == nil or type(BridgePregame.intercept) ~= "function"
            or type(target) ~= "table" or type(target.playButton) ~= "table" then
            return original(target, pressed, ...)
        end
        if BridgePregame.active or BridgePregame.finishing then return end

        if BridgePregame.intercept(target, target.playButton, 0, 0) then
            local pending = BridgePregame.pending
            if pending ~= nil then
                pending.finish = function()
                    return original(target, button, 0, 0)
                end
            end
            return
        end
        return original(target, pressed, ...)
    end

    if not hookedSaid then
        hookedSaid = true
        log("hooked Week One variant button")
    end
    return true
end

local function install()
    if installed then return end
    if not weekOnePresent() then return end
    if BridgePregame == nil or type(BridgePregame.intercept) ~= "function" then return end
    if type(CharacterCreationMain.prerender) ~= "function" then return end

    if not CharacterCreationMain.__bridgeWeekOnePrerender then
        CharacterCreationMain.__bridgeWeekOnePrerender = true
        local originalPrerender = CharacterCreationMain.prerender
        CharacterCreationMain.prerender = function(self)
            if type(originalPrerender) == "function" then originalPrerender(self) end
            hookVariant(self)
        end
    end

    installed = true
    log("installed")
end

install()
if type(Events) == "table" then
    local names = { "OnGameBoot", "OnMainMenuEnter" }
    for i = 1, #names do
        local event = Events[names[i]]
        if event ~= nil and type(event.Add) == "function" then event.Add(install) end
    end
end
