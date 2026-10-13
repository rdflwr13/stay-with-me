
if not isServer() then return end

local function register()
    if BridgeServer == nil or BridgeServer.Commands == nil then return end
    if BridgeAnimals == nil then return end
    if BridgeServer.Commands.animalHit ~= nil then return end

    BridgeServer.Commands.animalHit = function(player, args)
        if player == nil or args == nil then return end
        local who = nil
        pcall(function() who = player:getUsername() end)
        if who == nil then return end
        local body = BridgeServer.bodies[who]
        if body == nil then return end
        local id = tonumber(args.id)
        if id == nil then return end

        local target = nil
        pcall(function()
            local list = getCell():getAnimals()
            if list == nil then return end
            for i = 0, list:size() - 1 do
                local a = list:get(i)
                if a ~= nil and a:getOnlineID() == id then
                    target = a
                    break
                end
            end
        end)
        if target == nil then return end
        if not BridgeAnimals.hostile(target) then return end

        BridgeAnimals.apply(target, tonumber(args.dmg) or 0, body)
    end
end

Events.OnGameStart.Add(register)
Events.OnServerStarted.Add(register)
