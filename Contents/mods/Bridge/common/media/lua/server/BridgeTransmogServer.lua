if not isServer() then return end

BridgeTransmogServer = BridgeTransmogServer or {}

local OPERATIONS = {
    transmogrify = true,
    hide = true,
    show = true,
    remove = true,
    reset = true,
    color = true,
    texture = true,
}

local REACH = 6

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeTransmogServer] " .. tostring(text)) end
end

local function fail(player, args, why)
    local key = type(args) == "table" and args.key or nil
    local op = type(args) == "table" and args.op or nil
    pcall(function()
        sendServerCommand(player, "Bridge", "transmogFailed", { key = key, op = op, why = why })
    end)
    log("transmog rejected: " .. tostring(why) .. " key=" .. tostring(key))
end

local function tooFar(player, body)
    local far = true
    pcall(function()
        if player:getZ() ~= body:getZ() then return end
        local dx = player:getX() - body:getX()
        local dy = player:getY() - body:getY()
        far = (dx * dx + dy * dy) > (REACH * REACH)
    end)
    return far
end

local function handle(player, args)
    if player == nil then return end
    args = type(args) == "table" and args or {}
    if BridgeTransmogLogic == nil or not BridgeTransmogLogic.available() then
        fail(player, args, "unavailable")
        return
    end
    if BridgeData == nil or BridgeItems == nil then
        fail(player, args, "unavailable")
        return
    end

    local who = player:getUsername()
    local world = BridgeData.world(nil)
    local rec = world.players and world.players[who] or nil
    if rec == nil or rec.bodyId == nil then
        fail(player, args, "unavailable")
        return
    end

    local body = BridgeServer ~= nil and BridgeServer.bodies[who] or nil
    if body == nil then
        fail(player, args, "unavailable")
        return
    end
    local alive, inWorld = false, false
    pcall(function()
        alive = not body:isDead()
        inWorld = body:isExistInTheWorld()
    end)
    if not alive or not inWorld then
        fail(player, args, "unavailable")
        return
    end
    if tooFar(player, body) then
        fail(player, args, "too far")
        return
    end

    local op = args.op
    if type(op) ~= "string" or not OPERATIONS[op] then
        fail(player, args, "unavailable")
        return
    end
    local key = args.key
    if type(key) ~= "string" or key == "" then
        fail(player, args, "not found")
        return
    end
    if type(args.iseq) ~= "number" then
        fail(player, args, "stale")
        return
    end
    if args.iseq ~= (tonumber(rec.iseq) or 0) then
        fail(player, args, "stale")
        return
    end

    local list = BridgeItems.decode(rec.items)
    if type(list) ~= "table" or #list == 0 then
        fail(player, args, "not found")
        return
    end

    local target = BridgeTransmogLogic.findRecordByKey(list, key)
    if target == nil then
        fail(player, args, "not found")
        return
    end

    local scriptItem = nil
    pcall(function() scriptItem = ScriptManager.instance:getItem(target.t) end)
    if scriptItem == nil then
        fail(player, args, "not transmoggable")
        return
    end
    local transmoggable = false
    pcall(function() transmoggable = TransmogDE.isTransmoggable(scriptItem) == true end)
    if not transmoggable then
        fail(player, args, "not transmoggable")
        return
    end

    local temp = BridgeTransmogLogic.makeTempItem(target, args.md)
    if temp == nil then
        fail(player, args, "unavailable")
        return
    end

    local ok, why = BridgeTransmogLogic.applyToItem(temp, op, args.data)
    if not ok then
        fail(player, args, why or "unavailable")
        return
    end

    local applied = nil
    pcall(function() applied = temp:getModData().Transmog end)
    if type(applied) ~= "table" then
        fail(player, args, "unavailable")
        return
    end

    target.md = type(target.md) == "table" and target.md or {}
    target.md.Transmog = BridgeTransmogLogic.deepCopy(applied)

    local encoded = nil
    local encodedOk = pcall(function() encoded = BridgeItems.encode(list) end)
    if not encodedOk or type(encoded) ~= "string" then
        fail(player, args, "unavailable")
        return
    end
    local fit = 0
    pcall(function() fit = #BridgeItems.decode(encoded) end)
    if fit ~= #list then
        fail(player, args, "unavailable")
        return
    end

    local committed = pcall(function()
        BridgeItems.set(rec, encoded)
        rec.saved = 1
        rec.iseq = (tonumber(rec.iseq) or 0) + 1
        ModData.transmit(BridgeData.KEY)
    end)
    if not committed then
        fail(player, args, "unavailable")
        return
    end

    pcall(function()
        sendServerCommand(player, "Bridge", "transmogApplied", {
            iseq = rec.iseq,
            key = key,
            op = op,
            md = target.md.Transmog,
        })
    end)
    log("transmog applied: " .. tostring(op) .. " key=" .. tostring(key))
end

local function register()
    if BridgeServer == nil then return end
    BridgeServer.Commands = BridgeServer.Commands or {}
    BridgeServer.Commands.transmog = handle
end

register()
Events.OnGameStart.Add(register)

return BridgeTransmogServer
