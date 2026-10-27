BridgeExtraction = BridgeExtraction or {}
local M = BridgeExtraction

function M.ours(z)
    if z == nil then return false end

    if Bridge ~= nil and Bridge.body == z then return true end

    local yes = false
    pcall(function()
        yes = z:getVariableBoolean("NotAloneBody") == true
    end)
    if yes then return true end

    pcall(function()
        local md = z.getModData and z:getModData() or nil
        yes = md ~= nil and md.notAloneBody == true
    end)
    return yes
end

function M.install()
    local U = ExtractionMode and ExtractionMode.Util
    if type(U) ~= "table" then return false end

    local dead = U.isDeadOrDraggedZombie
    if type(dead) == "function" and dead ~= M.dead then
        M.dead = function(z)
            if M.ours(z) then return true end
            return dead(z)
        end
        U.isDeadOrDraggedZombie = M.dead
    end

    local npc = U.isNPCZombie
    if type(npc) == "function" and npc ~= M.npc then
        M.npc = function(z)
            if M.ours(z) then return true end
            return npc(z)
        end
        U.isNPCZombie = M.npc
    end

    local ready = U.isDeadOrDraggedZombie == M.dead and U.isNPCZombie == M.npc
    if ready and BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeExtraction] Extraction Mode zombie guards patched")
    end
    return ready
end

local installed = false
local function ensure()
    if installed then return end
    installed = M.install()
end

pcall(ensure)

if Events ~= nil then
    if Events.OnInitGlobalModData ~= nil then
        Events.OnInitGlobalModData.Add(function() pcall(ensure) end)
    end
    if Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function() pcall(ensure) end)
    end
    if Events.OnServerStarted ~= nil then
        Events.OnServerStarted.Add(function() pcall(ensure) end)
    end
    if Events.OnTick ~= nil then
        Events.OnTick.Add(function()
            if not installed then pcall(ensure) end
        end)
    end
end

return M
