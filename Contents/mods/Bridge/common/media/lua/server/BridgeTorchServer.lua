















if not isServer() then return end

BridgeTorchServer = BridgeTorchServer or {}
BridgeTorchServer.tick = 0

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeTorchServer] " .. tostring(text)) end end
local function warn(text) print("[BridgeTorchServer] " .. tostring(text)) end



local function companionFor(who)
    local b = nil
    pcall(function() b = BridgeServer.bodies and BridgeServer.bodies[who] or nil end)
    if b ~= nil then
        local ok = false
        pcall(function()
            ok = not b:isDead() and b:isExistInTheWorld()
                and b:getVariableBoolean("NotAloneBody") == true
        end)
        if ok then return b end
    end

    local want = nil
    pcall(function()
        local md = BridgeData.world(nil)
        local rec = md ~= nil and md.players and md.players[who] or nil
        if rec ~= nil then want = rec.bodyId end
    end)
    if want == nil then return nil end

    local found = nil
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and not z:isDead() and z:getPersistentOutfitID() == want then
                found = z
                break
            end
        end
    end)
    return found
end

BridgeTorchServer.companionFor = companionFor


local function serverBlocked(cell, x1, y1, z1, x2, y2)
    if LosUtil ~= nil and type(LosUtil.lineClear) == "function" then
        local res, ok = nil, false
        ok = pcall(function() res = LosUtil.lineClear(cell, x1, y1, z1, x2, y2, z1, false) end)
        if ok and res ~= nil then
            local blocked = nil
            pcall(function() if LosUtil.TestResults ~= nil then blocked = LosUtil.TestResults.Blocked end end)
            if blocked ~= nil then return res == blocked end
            return tostring(res) == "Blocked"
        end
    end
    return false
end





local function relay(who, body, on, range)
    local id = nil
    pcall(function() id = body:getPersistentOutfitID() end)
    pcall(function()
        sendServerCommand("Bridge", "torch", { owner = who, id = id, on = on, range = range })
    end)
end
BridgeTorchServer.relay = relay

local function install()
    if BridgeServer == nil or type(BridgeServer.Commands) ~= "table" then return false end

    BridgeServer.Commands.torch = function(player, args)
        if player == nil or args == nil then return end
        local who = player:getUsername()
        local body = companionFor(who)
        if body == nil then
            log("no companion body for " .. tostring(who) .. ", ignoring torch command")
            return
        end
        local on = args.on == true
        local range = tonumber(args.range)




        BridgeTorchShared.apply(body, on, range)
        relay(who, body, on, range)
        log("[BridgeTorchServer] torch " .. (on and "on" or "off") .. " for " .. tostring(who))
    end




    BridgeServer.Commands.reload = function(player, args)
        if player == nil then return end
        local who = player:getUsername()
        local body = companionFor(who)
        if body == nil then
            log("[TorchInv][server] reload: no companion body for " .. tostring(who))
            return
        end
        local ttype = "nil"
        local item = BridgeTorchShared.findTorch(body)
        if item ~= nil then pcall(function() ttype = item:getFullType() end) end
        local btype = "nil"
        pcall(function()
            local b = BridgeTorchShared.findBattery(body)
            if b ~= nil then btype = b:getFullType() end
        end)
        log(string.format("[TorchInv][server] reload who=%s combat=%s torch=%s charge=%s bat=%s",
            tostring(who), tostring(BridgeTorchShared.inCombat(body)), tostring(ttype),
            tostring(item and BridgeTorchShared.charge(item)), tostring(btype)))
        if BridgeTorchShared.inCombat(body) then
            log("[TorchInv][server] reload deferred (in combat) for " .. tostring(who))
            return
        end
        if item == nil then
            log("[TorchInv][server] reload aborted: no torch found on her")
            return
        end
        if BridgeTorchShared.charge(item) > 0.0001 then
            log("[TorchInv][server] reload aborted: torch not empty (charge " .. tostring(BridgeTorchShared.charge(item)) .. ")")
            return
        end
        if not BridgeTorchShared.swapBattery(body) then
            log("[TorchInv][server] reload: swapBattery failed (no battery in inventory?)")
            return
        end
        local id = nil
        pcall(function() id = body:getPersistentOutfitID() end)
        pcall(function()
            sendServerCommand("Bridge", "torch", { owner = who, id = id, on = false, range = nil, reload = true })
        end)
        log("[TorchInv][server] companion fitted a fresh cell for " .. tostring(who))
    end

    return true
end

BridgeTorchServer.install = install

local function torchTick()
    if not isMultiplayer() then return end
    BridgeTorchServer.tick = BridgeTorchServer.tick + 1
    if BridgeTorchServer.tick % 60 ~= 0 then return end

    local cell = getCell()
    if cell == nil then return end
    local list = nil
    pcall(function() list = cell:getZombieList() end)
    if list == nil then return end

    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z ~= nil then
            local marked = false
            pcall(function() marked = z:getVariableBoolean("NotAloneBody") == true end)
            if marked then
                local on = false
                pcall(function() on = z:getVariableBoolean(BridgeTorchShared.VAR) == true end)
                if on then
                    local empty, why = BridgeTorchShared.drain(z)
                    if empty then
                        BridgeTorchShared.apply(z, false)
                        pcall(function() z:setVariable(BridgeTorchShared.DEAD_VAR, true) end)
                        relay(nil, z, false, nil)
                        log("cell dead on companion, beam off")
                        if not BridgeTorchShared.inCombat(z) then
                            pcall(function() BridgeTorchShared.swapBattery(z) end)
                        end
                    elseif why == "none" or why == "not-drainable" then
                        BridgeTorchShared.apply(z, false)
                        relay(nil, z, false, nil)
                    end
                else



                    local item = BridgeTorchShared.findTorch(z)
                    if item ~= nil and BridgeTorchShared.charge(item) <= 0.0001
                        and not BridgeTorchShared.inCombat(z) then
                        local btype = "nil"
                        pcall(function()
                            local b = BridgeTorchShared.findBattery(z)
                            if b ~= nil then btype = b:getFullType() end
                        end)
                        if btype ~= "nil" then
                            log("[TorchInv][server] torchTick: torch empty + battery present (" .. tostring(btype) .. ") - fitting")
                        end
                        if BridgeTorchShared.swapBattery(z) then
                            local id = nil
                            pcall(function() id = z:getPersistentOutfitID() end)
                            pcall(function()
                                sendServerCommand("Bridge", "torch", { owner = nil, id = id, on = false, range = nil, reload = true })
                            end)
                            log("[TorchInv][server] companion fitted a fresh cell while off")
                        end
                    end
                end
            end
        end
    end
end

Events.OnTick.Add(function() pcall(torchTick) end)

if not pcall(install) then warn("command install deferred") end
Events.OnGameStart.Add(function() pcall(install) end)
Events.OnServerStarted.Add(function() pcall(install) end)

log("loaded")
