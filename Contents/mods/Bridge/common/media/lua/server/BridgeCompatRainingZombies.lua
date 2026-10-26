BridgeCompatRainingZombies = BridgeCompatRainingZombies or {}
local C = BridgeCompatRainingZombies

local MOD_ID = "RainingZombies"
local RETRY_EVERY = 30

local active = nil
local ticks = 0
local logged = false

function C.modActive()
    if active ~= nil then return active end
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(MOD_ID) or mods:contains("\\" .. MOD_ID))
    end)
    active = on
    return on
end

function C.apply(body)
    if body == nil then return end

    local want = C.modActive()
    local ok, current = pcall(function() return body:getVariableBoolean("ClimbWindow") end)
    if not ok then return end
    if current == want then return end

    if want then
        pcall(function() body:setVariable("ClimbWindow", true) end)
        if not logged then
            logged = true
            print("[BridgeCompatRainingZombies] companion fall guard active")
        end
    else
        pcall(function() body:clearVariable("ClimbWindow") end)
    end
end

function C.clear(body)
    if body == nil then return end
    pcall(function() body:clearVariable("ClimbWindow") end)
end

local function eachBody()
    local server = rawget(_G, "BridgeServer")
    if type(server) ~= "table" or type(server.bodies) ~= "table" then return end
    for _, body in pairs(server.bodies) do C.apply(body) end
end

Events.OnGameStart.Add(function()
    active = nil
    pcall(eachBody)
end)

Events.OnTick.Add(function()
    ticks = ticks + 1
    if ticks < RETRY_EVERY then return end
    ticks = 0
    pcall(eachBody)
end)
