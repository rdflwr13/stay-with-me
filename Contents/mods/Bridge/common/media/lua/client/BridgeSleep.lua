








require "ISUI/ISWorldObjectContextMenu"

BridgeSleep = BridgeSleep or {}
BridgeSleep.trueVanilla = nil
BridgeSleep.ours = {}







BridgeSleep.CLOSE = 3
BridgeSleep.SEEN = 7

BridgeSleep.calmEnabled = true
BridgeSleep.parkFallback = true
BridgeSleep.window = nil
BridgeSleep.queue = {}
BridgeSleep.request = {}
BridgeSleep.letting = false
BridgeSleep.noWindow = 0
BridgeSleep.noWindowSaid = false
BridgeSleep.lastVerdict = nil
BridgeSleep.sweep = {}
BridgeSleep.GETTERS = { "getNumVisibleZombies", "getNumVeryCloseZombies", "getNumChasingZombies" }

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeSleep] " .. tostring(text)) end end
local function warn(text) print("[BridgeSleep] " .. tostring(text)) end

function BridgeSleep.tentSleepWrapper()
    local tents = rawget(_G, "TentSleepImmersion")
    if tents == nil then return nil end
    return tents._sleepWalkWrapper
end


function BridgeSleep.blocks(playerObj, z)
    local dx, dy = z:getX() - playerObj:getX(), z:getY() - playerObj:getY()
    local d2 = dx * dx + dy * dy
    local sameFloor = math.abs(z:getZ() - playerObj:getZ()) < 1
    local chasing = false
    pcall(function() chasing = z:getTarget() == playerObj end)
    if chasing then return true, "chasing" end
    if sameFloor and d2 < BridgeSleep.CLOSE * BridgeSleep.CLOSE then return true, "very close" end
    if sameFloor and d2 < BridgeSleep.SEEN * BridgeSleep.SEEN then
        local seen, sameRoom = false, false
        pcall(function() seen = playerObj:CanSee(z) end)
        pcall(function()
            local a, b = z:getCurrentSquare(), playerObj:getCurrentSquare()
            sameRoom = a ~= nil and b ~= nil and a:getRoom() == b:getRoom()
        end)
        if seen and sameRoom then return true, "seen" end
    end
    return false, nil
end


function BridgeSleep.statsIndex(playerObj)
    local idx, stats = nil, nil
    pcall(function()
        stats = playerObj:getStats()
        local meta = getmetatable(stats)
        if meta ~= nil and type(meta.__index) == "table" then idx = meta.__index end
    end)
    return idx, stats
end


function BridgeSleep.calmOpen(playerObj)
    if playerObj == nil or BridgeSleep.window ~= nil then return nil end
    local asleep = false
    pcall(function() asleep = playerObj:isAsleep() == true end)
    if asleep then return nil end
    local idx, stats = BridgeSleep.statsIndex(playerObj)
    if idx == nil or stats == nil then
        BridgeSleep.noWindow = BridgeSleep.noWindow + 1
        if not BridgeSleep.noWindowSaid then
            BridgeSleep.noWindowSaid = true
            log("stats method table is not a table: sleep window disabled")
        end
        return nil
    end
    local saved = {}
    for _, name in ipairs(BridgeSleep.GETTERS) do
        local real = idx[name]
        saved[name] = real
        if type(real) == "function" then
            idx[name] = function(s, ...)
                if s == stats then return 0 end
                return real(s, ...)
            end
        end
    end
    BridgeSleep.window = stats
    log("calm window open")
    return function()
        if BridgeSleep.window ~= stats then return end
        for _, name in ipairs(BridgeSleep.GETTERS) do
            idx[name] = saved[name]
        end
        BridgeSleep.window = nil
        log("calm window close")
    end
end


function BridgeSleep.engineCounts(playerObj, z)
    if playerObj == nil or z == nil then return false, false, false end
    local dead, dragged = false, false
    pcall(function() dead = z:isDead() == true end)
    if BridgeZScan ~= nil and type(BridgeZScan.isDragged) == "function" then
        pcall(function() dragged = BridgeZScan.isDragged(z) == true end)
    elseif BridgeData ~= nil and type(BridgeData.dragged) == "function" then
        pcall(function() dragged = BridgeData.dragged(z) == true end)
    end
    if dead or dragged then return false, false, false end
    local chasing = false
    pcall(function() chasing = z:getTarget() == playerObj end)
    local zz, dx, dy, d2 = z:getZ(), z:getX() - playerObj:getX(), z:getY() - playerObj:getY(), 0
    d2 = dx * dx + dy * dy
    local close = d2 < BridgeSleep.CLOSE * BridgeSleep.CLOSE
    local visible = false
    if zz >= playerObj:getZ() - 1 and d2 < BridgeSleep.SEEN * BridgeSleep.SEEN then
        local same = false
        pcall(function()
            local a, b = z:getCurrentSquare(), playerObj:getCurrentSquare()
            if a ~= nil and b ~= nil then same = a:getRoom() == b:getRoom() end
        end)
        if same then
            pcall(function() visible = playerObj:CanSee(z) == true end)
        end
    end
    return visible, close, chasing
end


function BridgeSleep.calm(playerObj)
    if playerObj == nil then return false, "no player" end
    local v, c, ch = 0, 0, 0
    local ok = pcall(function()
        local st = playerObj:getStats()
        v = tonumber(st:getNumVisibleZombies()) or 0
        c = tonumber(st:getNumVeryCloseZombies()) or 0
        ch = tonumber(st:getNumChasingZombies()) or 0
    end)
    if not ok then return false, "counters unavailable" end
    if v <= 0 and c <= 0 and ch <= 0 then
        BridgeSleep.lastVerdict = "nothing counted"
        return true, BridgeSleep.lastVerdict
    end
    local matchV, matchC, matchCh = 0, 0, 0
    local function tally(z)
        if z == nil then return true end
        local alive = false
        pcall(function() alive = z:isAlive() == true end)
        if not alive then return true end
        local visible, close, chasing = BridgeSleep.engineCounts(playerObj, z)
        local companion = false
        if BridgeZScan ~= nil and type(BridgeZScan.isCompanion) == "function" then
            pcall(function() companion = BridgeZScan.isCompanion(z) == true end)
        elseif Bridge ~= nil and type(Bridge.isCompanion) == "function" then
            pcall(function() companion = Bridge.isCompanion(z) == true end)
        end
        if not companion then
            if visible or close or chasing then
                BridgeSleep.lastVerdict = "real " .. (chasing and "chasing" or close and "very close" or "visible")
                return false
            end
            return true
        end
        if visible then matchV = matchV + 1 end
        if close then matchC = matchC + 1 end
        if chasing then matchCh = matchCh + 1 end
        return true
    end
    local refs = nil
    if BridgeZScan ~= nil and type(BridgeZScan.find) == "function" then
        pcall(function() refs = BridgeZScan.find(function(z) return z ~= nil end, nil, { tag = "sleep.calm" }) end)
    end
    if refs ~= nil then
        for i = 1, #refs do
            if not tally(refs[i]) then return false, BridgeSleep.lastVerdict end
        end
    else
        local cell = getCell()
        local list = cell ~= nil and cell:getZombieList() or nil
        if list == nil then return false, "no zombie list" end
        for i = 0, list:size() - 1 do
            if not tally(list:get(i)) then return false, BridgeSleep.lastVerdict end
        end
    end
    if matchV < v or matchC < c or matchCh < ch then
        BridgeSleep.lastVerdict = "unaccounted counter"
        return false, BridgeSleep.lastVerdict
    end
    BridgeSleep.lastVerdict = "only companion"
    return true, BridgeSleep.lastVerdict
end



function BridgeSleep.onlyCompanions(playerObj)
    if playerObj == nil then return false end
    local stats = playerObj:getStats()
    local counted = stats:getNumVisibleZombies() > 0 or stats:getNumChasingZombies() > 0
        or stats:getNumVeryCloseZombies() > 0
    if not counted then return false end
    local refs = nil
    if BridgeZScan ~= nil then
        refs = BridgeZScan.find(function(z)
            return z ~= nil and z:isAlive() and not BridgeZScan.isCompanion(z) and not BridgeZScan.isDragged(z)
        end, nil, { tag = "sleep.only" })
    end
    if refs ~= nil then
        for i = 1, #refs do
            local z = refs[i]
            local block, why = BridgeSleep.blocks(playerObj, z)
            if block then
                local d = 0
                pcall(function() d = math.sqrt((z:getX() - playerObj:getX()) ^ 2 + (z:getY() - playerObj:getY()) ^ 2) end)
                log(string.format("zombie %s at %.1f: game check decides", why, d))
                return false
            end
        end
        return true
    end
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)

        if z ~= nil and z:isAlive() and not Bridge.isCompanion(z) and not BridgeData.dragged(z) then
            local block, why = BridgeSleep.blocks(playerObj, z)
            if block then
                local d = 0
                pcall(function() d = math.sqrt((z:getX() - playerObj:getX()) ^ 2 + (z:getY() - playerObj:getY()) ^ 2) end)
                log(string.format("zombie %s at %.1f: game check decides", why, d))
                return false
            end
        end
    end
    return true
end








BridgeSleep.pending = nil
BridgeSleep.WAIT_MIN = 2
BridgeSleep.WAIT_MAX = 60

local function countersClear(playerObj)
    local clear = false
    pcall(function()
        local st = playerObj:getStats()
        clear = st:getNumVisibleZombies() == 0 and st:getNumChasingZombies() == 0 and st:getNumVeryCloseZombies() == 0
    end)
    return clear
end







function BridgeSleep.hidingCopies()
    if Bridge == nil or not Bridge.mp then return false end
    return BridgeSleep.pending ~= nil
end

function BridgeSleep.sleepAfterPark(player, bed, original)
    local parked = false
    pcall(function() parked = Bridge.sleepParkNow() end)
    BridgeSleep.pending = { player = player, bed = bed, original = original, since = Bridge.time }
    log("only companions near: " .. (parked and "body parked" or "no own body in the world") .. ", waiting for the game to recount")
end

function BridgeSleep.tickPending()
    local p = BridgeSleep.pending
    if p == nil then return end
    local waited = Bridge.time - p.since
    if waited < BridgeSleep.WAIT_MIN then return end
    local clear = countersClear(getSpecificPlayer(p.player))
    if not clear and waited < BridgeSleep.WAIT_MAX then return end
    BridgeSleep.pending = nil
    log(clear and "counters clear: going to sleep the game's way" or "counters still set after 1 s: the game decides")


    local call = ISWorldObjectContextMenu ~= nil and ISWorldObjectContextMenu.onSleepWalkToComplete or nil
    if type(call) ~= "function" then call = p.original end
    BridgeSleep.replaying = true
    local ok, err = pcall(call, p.player, p.bed)
    BridgeSleep.replaying = false
    if not ok then warn("sleep call failed: " .. tostring(err)) end
end

if Events ~= nil and Events.OnTick ~= nil then
    Events.OnTick.Add(function() pcall(BridgeSleep.tickPending) end)
    Events.OnTick.Add(function() pcall(BridgeSleep.flushQueue) end)
end










function BridgeSleep.queueSleep(original, playerNum, ...)
    if BridgeSleep.letting or type(original) ~= "function" then return false end
    BridgeSleep.queue[playerNum] = { original = original, args = { ... }, at = Bridge.time }
    log("sleep queued for player " .. tostring(playerNum))
    return true
end


function BridgeSleep.flushQueue()
    if BridgeSleep.letting then return end
    local pending = {}
    for num, entry in pairs(BridgeSleep.queue) do pending[#pending + 1] = { num = num, entry = entry } end
    if #pending == 0 then return end
    local okAll, errAll = pcall(function()
        for _, item in ipairs(pending) do
            local num, entry = item.num, item.entry
            BridgeSleep.queue[num] = nil
            local p = nil
            pcall(function() p = getSpecificPlayer(num) end)
            local drop = p == nil
            if not drop then
                local dead, asleep = false, false
                pcall(function() dead = p:isDead() == true end)
                pcall(function() asleep = p:isAsleep() == true end)
                drop = dead or asleep or (Bridge.time - entry.at) > 5
            end
            if not drop then
                local calm = false
                pcall(function() calm = BridgeSleep.calm(p) == true end)
                if not calm then
                    log("sleep queue: not calm any more, the game decides")
                    pcall(entry.original, unpack(entry.args))
                else
                    BridgeSleep.letting = true
                    local close = BridgeSleep.calmOpen(p)
                    local ok, err = pcall(entry.original, unpack(entry.args))
                    if close ~= nil then close() end
                    BridgeSleep.letting = false
                    if not ok then warn("queued sleep call failed: " .. tostring(err)) end
                    log("sleep let through")
                end
            end
        end
    end)
    BridgeSleep.letting = false
    if not okAll then warn("sleep queue failed: " .. tostring(errAll)) end
end


local function makeSleepWrapper(original)
    local w
    local active = false
    w = function(player, bed)
        if active then
            local base = BridgeSleep.trueVanilla
            if base ~= nil and not BridgeSleep.ours[base] then return base(player, bed) end
            return nil
        end
        if BridgeSleep.replaying or BridgeSleep.letting then return original(player, bed) end
        active = true
        local ok, result = pcall(function()
            local playerObj = getSpecificPlayer(player)
            if Bridge.mp then
                local okOnly, only = pcall(function() return BridgeSleep.onlyCompanions(playerObj) end)
                if okOnly and only then
                    return BridgeSleep.sleepAfterPark(player, bed, original)
                end
                return original(player, bed)
            end
            if not BridgeSleep.calmEnabled then return original(player, bed) end
            local calm, verdict = BridgeSleep.calm(playerObj)
            if calm then
                log("sleep gate calm: " .. tostring(verdict))
                BridgeSleep.queueSleep(original, player, player, bed)
                return nil
            end
            log("sleep gate blocked: " .. tostring(verdict))
            return original(player, bed)
        end)
        active = false
        if not ok then warn("sleep call failed: " .. tostring(result)) end
        return result
    end
    BridgeSleep.ours[w] = true
    BridgeSleep.wrapper = w
    return w
end

function BridgeSleep.wrap(when)
    if ISWorldObjectContextMenu == nil or ISWorldObjectContextMenu.onSleepWalkToComplete == nil then return end
    local current = ISWorldObjectContextMenu.onSleepWalkToComplete
    if BridgeSleep.ours[current] then return end
    local tents = rawget(_G, "TentSleepImmersion")
    local tentWrapper = tents ~= nil and tents._sleepWalkWrapper or nil
    if tentWrapper ~= nil and current == tentWrapper then
        if BridgeSleep.ours[tents._vanillaSleepWalkToComplete] then return end
        local prior = tents._vanillaSleepWalkToComplete
        if prior == nil or prior == tentWrapper then return end
        if BridgeSleep.trueVanilla == nil then BridgeSleep.trueVanilla = prior end
        tents._vanillaSleepWalkToComplete = makeSleepWrapper(prior)
        log("joined the ImmersiveTents sleep chain as its delegate (" .. tostring(when) .. ")")
        return
    end
    if BridgeSleep.trueVanilla == nil then BridgeSleep.trueVanilla = current end
    ISWorldObjectContextMenu.onSleepWalkToComplete = makeSleepWrapper(current)
    ISWorldObjectContextMenu.bridgeSleepWrapped = true
    if when ~= "load" then log("sleep check was replaced after us (" .. tostring(when) .. "), wrapped again") end
end










BridgeSleep.SLEEP_OPTIONS = { "ContextMenu_Sleep", "ContextMenu_SleepOnGround", "ContextMenu_SleepOnGroundPillow" }

local function isSleepOption(o)
    if o == nil then return false end
    if ISWorldObjectContextMenu ~= nil and o.onSelect ~= nil and o.onSelect == ISWorldObjectContextMenu.onSleep then return true end
    for _, key in ipairs(BridgeSleep.SLEEP_OPTIONS) do
        if o.name == getText(key) then return true end
    end
    return false
end



function BridgeSleep.allOptions(context)
    local out, seen = {}, {}
    local function walk(menu, depth)
        if menu == nil or menu.options == nil or seen[menu] or depth > 4 then return end
        seen[menu] = true
        for _, o in ipairs(menu.options) do
            out[#out + 1] = o
            if o.subOption ~= nil then
                local sub = nil
                pcall(function() sub = context:getSubMenu(o.subOption) end)
                walk(sub, depth + 1)
            end
        end
    end
    walk(context, 1)
    return out
end

function BridgeSleep.fixSleepOption(playerNum, context, worldobjects, test)
    if test or context == nil or context.options == nil then return end
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil then return end
    local notSafe = getText("IGUI_Sleep_NotSafe")
    for _, o in ipairs(BridgeSleep.allOptions(context)) do
        local tip = o.toolTip
        local desc = tip ~= nil and tip.description or nil
        if isSleepOption(o) and o.notAvailable and type(desc) == "string" and string.find(desc, notSafe, 1, true) ~= nil then
            local ok, calm = pcall(function() return BridgeSleep.calm(playerObj) == true end)
            if ok and calm then

                local needed = true
                pcall(function() if isClient() then needed = getServerOptions():getBoolean("SleepNeeded") end end)
                local tired = true
                pcall(function() tired = playerObj:getStats():get(CharacterStat.FATIGUE) > 0.3 end)
                local rest = desc:gsub(notSafe:gsub("%p", "%%%0") .. " <BR> ", "", 1)
                if needed and not tired then
                    tip.description = (rest == desc) and getText("IGUI_Sleep_NotTiredEnough")
                        or (getText("IGUI_Sleep_NotTiredEnough") .. " <BR> " .. rest)
                    log("sleep option: only companions near, but not tired")
                else
                    o.notAvailable = false
                    if rest == desc then o.toolTip = nil else tip.description = rest end
                    if not o.bridgeCalmWrapped and type(o.onSelect) == "function" then
                        o.bridgeCalmWrapped = true
                        o.bridgeCalmOnSelect = o.onSelect
                        local saved = o.onSelect
                        o.onSelect = function(...)
                            if BridgeSleep.parkFallback and not Bridge.mp and not BridgeSleep.ownsGate() then
                                if Bridge ~= nil then pcall(function() Bridge.sleepParkNow() end) end
                                log("park fallback: foreign gate")
                            end
                            return saved(...)
                        end
                    end
                    BridgeSleep.request[playerNum] = Bridge.time
                    log("sleep option: only companions near, enabled")
                end
            end
        end
    end
    if not BridgeSleep.sweeping then BridgeSleep.sweep[playerNum] = Bridge.time + 1 end
end


function BridgeSleep.lateMenuSweep()
    for num, at in pairs(BridgeSleep.sweep) do
        if Bridge.time >= at then
            BridgeSleep.sweep[num] = nil
            local ctx = nil
            pcall(function() ctx = getPlayerContextMenu(num) end)
            if ctx ~= nil then
                BridgeSleep.sweeping = true
                pcall(BridgeSleep.fixSleepOption, num, ctx, nil, false)
                BridgeSleep.sweeping = false
            end
        end
    end
    for num, at in pairs(BridgeSleep.request) do
        if Bridge.time - at > 10 then BridgeSleep.request[num] = nil end
    end
end

BridgeSleep.wrap("load")
if Events ~= nil and Events.OnFillWorldObjectContextMenu ~= nil then
    Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
        pcall(BridgeSleep.fixSleepOption, playerNum, context, worldobjects, test)
    end)
end
if Events ~= nil and Events.OnTick ~= nil then
    Events.OnTick.Add(function() pcall(BridgeSleep.lateMenuSweep) end)
end
if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function()
        BridgeSleep.queue = {}
        BridgeSleep.request = {}
        BridgeSleep.sweep = {}
        BridgeSleep.window = nil
        BridgeSleep.letting = false
        pcall(BridgeSleep.wrap, "game start")
        pcall(BridgeSleep.wrapVehicle)
    end)
end












function BridgeSleep.ownsGate()
    if ISWorldObjectContextMenu == nil then return false end
    local top = ISWorldObjectContextMenu.onSleepWalkToComplete
    if top == nil then return false end
    if BridgeSleep.ours[top] or top == BridgeSleep.wrapper then return true end
    local tents = rawget(_G, "TentSleepImmersion")
    if tents ~= nil and top == tents._sleepWalkWrapper and BridgeSleep.ours[tents._vanillaSleepWalkToComplete] then
        return true
    end
    return false
end


function BridgeSleep.wrapVehicle()
    local V = ISVehicleMenu
    if V == nil then return end
    if type(V.showRadialMenu) == "function"
        and (not V.bridgeSleepWrapped or V.showRadialMenu ~= BridgeSleep.vehicleRadial) then
        local original = V.showRadialMenu
        local wrapper = function(playerObj, ...)
            local calm = false
            pcall(function() calm = BridgeSleep.calm(playerObj) == true end)
            if not calm then return original(playerObj, ...) end
            local close = BridgeSleep.calmOpen(playerObj)
            local ok, err = pcall(original, playerObj, ...)
            if close ~= nil then close() end
            if not ok then warn("vehicle sleep radial failed: " .. tostring(err)) end
        end
        V.showRadialMenu = wrapper
        BridgeSleep.vehicleRadial = wrapper
        V.bridgeSleepWrapped = true
    end
    if type(V.onSleep) == "function"
        and (not V.bridgeSleepSleepWrapped or V.onSleep ~= BridgeSleep.vehicleSleep) then
        local original = V.onSleep
        local wrapper = function(playerObj, ...)
            local calm = false
            pcall(function() calm = BridgeSleep.calm(playerObj) == true end)
            if not calm then return original(playerObj, ...) end
            local close = BridgeSleep.calmOpen(playerObj)
            local ok, err = pcall(original, playerObj, ...)
            if close ~= nil then close() end
            if not ok then warn("vehicle sleep call failed: " .. tostring(err)) end
        end
        V.onSleep = wrapper
        BridgeSleep.vehicleSleep = wrapper
        V.bridgeSleepSleepWrapped = true
    end
    if type(V.onConfirmSleep) == "function"
        and (not V.bridgeSleepConfirmWrapped or V.onConfirmSleep ~= BridgeSleep.vehicleConfirm) then
        local original = V.onConfirmSleep
        local wrapper = function(this, button, player, bed)
            local p = nil
            pcall(function() p = getSpecificPlayer(player) end)
            local yes = button ~= nil and button.internal == "YES"
            local calm = false
            if p ~= nil and yes then pcall(function() calm = BridgeSleep.calm(p) == true end) end
            if not calm then return original(this, button, player, bed) end
            if BridgeSleep.parkFallback and not Bridge.mp and not BridgeSleep.ownsGate() then
                if Bridge ~= nil then pcall(function() Bridge.sleepParkNow() end) end
                log("park fallback: foreign vehicle gate")
            end
            local close = BridgeSleep.calmOpen(p)
            local ok, err = pcall(original, this, button, player, bed)
            if close ~= nil then close() end
            if not ok then warn("vehicle sleep confirm failed: " .. tostring(err)) end
        end
        V.onConfirmSleep = wrapper
        BridgeSleep.vehicleConfirm = wrapper
        V.bridgeSleepConfirmWrapped = true
    end
end

pcall(BridgeSleep.wrapVehicle)


function BridgeSleep.statusText()
    local depth = 0
    for _ in pairs(BridgeSleep.queue) do depth = depth + 1 end
    return string.format("sleep calm=%s park=%s window=%s queue=%d noWindow=%d verdict=%s",
        tostring(BridgeSleep.calmEnabled), tostring(BridgeSleep.parkFallback), tostring(BridgeSleep.window ~= nil),
        depth, BridgeSleep.noWindow, tostring(BridgeSleep.lastVerdict or "-"))
end


function BridgeSleep.set(key, value)
    if key == nil or key == "status" then return BridgeSleep.statusText() end
    if key ~= "calm" and key ~= "park" then return "sleepfix [calm on|off] [park on|off] [status]" end
    local on = value ~= "off" and value ~= "false" and value ~= "0" and value ~= false
    if key == "calm" then
        BridgeSleep.calmEnabled = on
        log("calm window " .. (on and "on" or "off"))
    else
        BridgeSleep.parkFallback = on
        log("park fallback " .. (on and "on" or "off"))
    end
    return BridgeSleep.statusText()
end


function BridgeSleep.selftest()
    local checks, fails = 0, {}
    local function check(name, got, want)
        checks = checks + 1
        if got ~= want then
            fails[#fails + 1] = string.format("%s got=%s want=%s", name, tostring(got), tostring(want))
        end
    end
    local function statsStub(v, c, ch, fatigue)
        local idx = {}
        idx.getNumVisibleZombies = function() return v end
        idx.getNumVeryCloseZombies = function() return c end
        idx.getNumChasingZombies = function() return ch end
        idx.get = function(_, stat) return fatigue == nil and 0.5 or fatigue end
        return setmetatable({}, { __index = idx }), idx
    end
    local squareStub = { getRoom = function() return nil end }
    local function playerStub(st, asleep)
        return {
            getStats = function() return st end,
            isAsleep = function() return asleep == true end,
            isDead = function() return false end,
            getX = function() return 0 end,
            getY = function() return 0 end,
            getZ = function() return 0 end,
            getCurrentSquare = function() return squareStub end,
            CanSee = function() return true end,
        }
    end
    local function zombieStub(x, y, z, target)
        return {
            isAlive = function() return true end,
            isDead = function() return false end,
            getX = function() return x end,
            getY = function() return y end,
            getZ = function() return z end,
            getTarget = function() return target end,
            getCurrentSquare = function() return squareStub end,
        }
    end
    local st, idx = statsStub(0, 0, 0)
    local p = playerStub(st, false)
    local v, c, ch = BridgeSleep.engineCounts(p, zombieStub(2, 0, 1, nil))
    check("close any floor", c, true)
    v, c, ch = BridgeSleep.engineCounts(p, zombieStub(4, 0, 0, nil))
    check("visible four tiles", v, true)
    v, c, ch = BridgeSleep.engineCounts(p, zombieStub(8, 0, 0, nil))
    check("not visible eight tiles", v, false)
    local chaser = zombieStub(20, 0, 0, p)
    v, c, ch = BridgeSleep.engineCounts(p, chaser)
    check("chasing far", ch, true)
    local oldFind, oldComp, oldDragged = BridgeZScan.find, BridgeZScan.isCompanion, BridgeZScan.isDragged
    local oldGetText, oldGetPlayer, oldIsClient, oldCharStat = getText, getSpecificPlayer, isClient, CharacterStat
    local refs = {}
    BridgeZScan.find = function() return refs end
    BridgeZScan.isCompanion = function(z) return z.companion == true end
    BridgeZScan.isDragged = function() return false end
    local okAll, errAll = pcall(function()
        local s1 = statsStub(1, 0, 0)
        local p1 = playerStub(s1, false)
        local z1 = zombieStub(4, 0, 0, nil)
        z1.companion = true
        refs = { z1 }
        check("calm one companion", BridgeSleep.calm(p1), true)
        local s2 = statsStub(2, 0, 0)
        refs = { z1 }
        check("calm unaccounted", BridgeSleep.calm(playerStub(s2, false)), false)
        refs = {}
        check("calm no match", BridgeSleep.calm(p1), false)
        local z2 = zombieStub(4, 0, 0, nil)
        refs = { z2 }
        check("calm real visible", BridgeSleep.calm(p1), false)
        check("calm nothing counted", BridgeSleep.calm(playerStub(statsStub(0, 0, 0), false)), true)
        local s3 = statsStub(0, 0, 0)
        local p3 = playerStub(s3, false)
        local close = BridgeSleep.calmOpen(p3)
        check("window open", BridgeSleep.window ~= nil, true)
        check("window visible getter", s3:getNumVisibleZombies(), 0)
        check("window close", type(close), "function")
        if close ~= nil then close() end
        check("window restored", BridgeSleep.window, nil)
        check("window awake refused", BridgeSleep.calmOpen(playerStub(s3, true)), nil)
        BridgeSleep.queue = {}
        BridgeSleep.letting = false
        local fired = 0
        local function original() fired = fired + 1 end
        check("queue accepted", BridgeSleep.queueSleep(original, 7, 7, nil), true)
        check("queue replaced", BridgeSleep.queueSleep(original, 7, 7, nil), true)
        local depth = 0
        for _ in pairs(BridgeSleep.queue) do depth = depth + 1 end
        check("queue depth one", depth, 1)
        BridgeSleep.letting = true
        check("queue while letting", BridgeSleep.queueSleep(original, 8, 8, nil), false)
        BridgeSleep.letting = false
        BridgeSleep.queue[9] = { original = original, args = { 9, nil }, at = Bridge.time - 10 }
        BridgeSleep.flushQueue()
        check("queue timeout dropped", BridgeSleep.queue[9], nil)
        check("queue timeout not fired", fired, 0)
        local sFix = statsStub(0, 0, 0, 0.5)
        local pFix = playerStub(sFix, false)
        getText = function(k) return k end
        getSpecificPlayer = function() return pFix end
        isClient = function() return false end
        CharacterStat = { FATIGUE = 1 }
        local opt = { name = "ContextMenu_Sleep", notAvailable = true,
            toolTip = { description = "IGUI_Sleep_NotSafe <BR> " }, onSelect = function() end }
        BridgeSleep.fixSleepOption(0, { options = { opt } })
        check("fix clears", opt.notAvailable, false)
        check("fix wraps", opt.bridgeCalmWrapped, true)
        local wrapped = opt.onSelect
        BridgeSleep.fixSleepOption(0, { options = { opt } })
        check("fix wraps once", opt.onSelect, wrapped)
        local sTired = statsStub(0, 0, 0, 0.1)
        local pTired = playerStub(sTired, false)
        getSpecificPlayer = function() return pTired end
        local optTired = { name = "ContextMenu_Sleep", notAvailable = true,
            toolTip = { description = "IGUI_Sleep_NotSafe <BR> " }, onSelect = function() end }
        BridgeSleep.fixSleepOption(0, { options = { optTired } })
        check("fix tired stays unavailable", optTired.notAvailable, true)
        check("fix tired text", optTired.toolTip.description, "IGUI_Sleep_NotTiredEnough <BR> ")
        BridgeSleep.queue = {}
    end)
    BridgeZScan.find, BridgeZScan.isCompanion, BridgeZScan.isDragged = oldFind, oldComp, oldDragged
    getText, getSpecificPlayer, isClient, CharacterStat = oldGetText, oldGetPlayer, oldIsClient, oldCharStat
    BridgeSleep.window = nil
    check("selftest body", okAll, true)
    if not okAll then fails[#fails + 1] = "selftest error: " .. tostring(errAll) end
    if #fails == 0 then return string.format("sleepselftest PASS (%d checks)", checks) end
    return string.format("sleepselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end


BridgeSleep.SEARCH_CLOSE = 3
BridgeSleep.SEARCH_SEEN = 7
BridgeSleep.SEARCH_CACHE_MS = 250


function BridgeSleep.searchZombieBlock(playerObj)
    local stats = playerObj:getStats()
    local veryClose = stats:getNumVeryCloseZombies()
    local visible = stats:getNumVisibleZombies()
    local chasing = stats:getNumChasingZombies()
    if veryClose <= 0 and not (visible >= 3 and chasing >= 3) then return false end
    local px, py, pz = playerObj:getX(), playerObj:getY(), playerObj:getZ()
    local close2 = BridgeSleep.SEARCH_CLOSE * BridgeSleep.SEARCH_CLOSE
    local seen2 = BridgeSleep.SEARCH_SEEN * BridgeSleep.SEARCH_SEEN
    local ownClose, ownSeen, ownChasing = 0, 0, 0
    local refs = nil
    if BridgeZScan ~= nil then
        refs = BridgeZScan.find(function(z)
            return z ~= nil and z:isAlive() and not BridgeZScan.isDragged(z)
        end, nil, { tag = "sleep.search" })
    end
    if refs ~= nil then
        for i = 1, #refs do
            local z = refs[i]
            local dx, dy = z:getX() - px, z:getY() - py
            local d2 = dx * dx + dy * dy
            local floor = math.abs(z:getZ() - pz) < 1
            if z:getVariableBoolean(Bridge.BODY_VAR) then
                if d2 < close2 then ownClose = ownClose + 1 end
                if d2 < seen2 then ownSeen = ownSeen + 1 end
                if z:getTarget() == playerObj then ownChasing = ownChasing + 1 end
            elseif floor and d2 < close2 then
                return true
            end
        end
    else
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z:isAlive() and not BridgeData.dragged(z) then
                local dx, dy = z:getX() - px, z:getY() - py
                local d2 = dx * dx + dy * dy
                local floor = math.abs(z:getZ() - pz) < 1
                if z:getVariableBoolean(Bridge.BODY_VAR) then
                    if d2 < close2 then ownClose = ownClose + 1 end
                    if d2 < seen2 then ownSeen = ownSeen + 1 end
                    if z:getTarget() == playerObj then ownChasing = ownChasing + 1 end
                elseif floor and d2 < close2 then
                    return true
                end
            end
        end
    end
    if veryClose > ownClose then return true end
    return (visible - ownSeen) >= 3 and (chasing - ownChasing) >= 3
end


function BridgeSleep.searchOtherBlock(manager)
    local c = manager.character
    if (c:isRunning() or c:isSprinting() and c:isJustMoved()) then return true end
    if manager.searchMode:isOverrideSearchManager(manager.player) then return true end
    if isClient() then
        if not SafeHouse.isSafehouseAllowLoot(manager.square, c) then return true end
    end
    return false
end


BridgeSleep.searchCache = {}
function BridgeSleep.searchZombieBlockCached(playerObj)
    local now = getTimestampMs()
    local c = BridgeSleep.searchCache[playerObj]
    if c ~= nil and now - c.at < BridgeSleep.SEARCH_CACHE_MS then return c.block end
    local block = BridgeSleep.searchZombieBlock(playerObj)
    BridgeSleep.searchCache[playerObj] = { at = now, block = block }
    return block
end

if ISSearchManager ~= nil and ISSearchManager.checkShouldDisable ~= nil
    and not ISSearchManager.bridgeSearchWrapped then
    local original = ISSearchManager.checkShouldDisable
    ISSearchManager.checkShouldDisable = function(self, ...)
        if ISSearchManager.showDebug or self == nil or self.character == nil then
            return original(self, ...)
        end
        local ok, zombies = pcall(BridgeSleep.searchZombieBlockCached, self.character)
        if not ok then return original(self, ...) end
        if zombies then return true end
        return BridgeSleep.searchOtherBlock(self)
    end
    ISSearchManager.bridgeSearchWrapped = true
end























local SPEED_MULT = { [2] = 5.0, [3] = 20.0, [4] = 40.0 }
BridgeSleep.wantedSpeed = 1
BridgeSleep.restored = 0
BridgeSleep.blockedWhy = nil
BridgeSleep.traceLeft = 0
BridgeSleep.rateAt = nil

local function speedTrace(src, c)
    if BridgeSleep.traceLeft <= 0 then return end
    local mult, hours = -1, -1
    pcall(function() mult = getGameTime():getTrueMultiplier() end)
    pcall(function() hours = getGameTime():getWorldAgeHours() end)
    pcall(function()
        log(string.format("speedtrace t=%s %s speed=%s mult=%s want=%s hours=%s", tostring(Bridge.tick), tostring(src),
            tostring(c and c:getCurrentGameSpeed()), tostring(mult), tostring(BridgeSleep.wantedSpeed), tostring(hours)))
    end)
end

local function controls()
    local c = nil
    pcall(function() c = UIManager.getSpeedControls() end)
    return c
end




function BridgeSleep.speedBlocker(playerObj)
    if playerObj == nil then return "no player" end
    if Bridge == nil or not Bridge.alive() then return "no companion" end
    local body = Bridge.body
    local dx, dy = body:getX() - playerObj:getX(), body:getY() - playerObj:getY()
    if dx * dx + dy * dy > 8 * 8 then return "companion far" end
    local refs = nil
    if BridgeZScan ~= nil then
        refs = BridgeZScan.find(function(z)
            return z ~= nil and z:isAlive() and not BridgeZScan.isCompanion(z) and not BridgeZScan.isDragged(z)
        end, nil, { tag = "sleep.speed" })
    end
    if refs ~= nil then
        for i = 1, #refs do
            local z = refs[i]
            local zx, zy = z:getX() - playerObj:getX(), z:getY() - playerObj:getY()
            local d2 = zx * zx + zy * zy
            if d2 < 4 * 4 then return "zombie within 4" end
            if d2 < 20 * 20 then
                local seen = false
                pcall(function() seen = playerObj:CanSee(z) end)
                if seen then return "zombie in sight" end
            end
            local chasing = false
            pcall(function() chasing = z:getTarget() == playerObj end)
            if chasing then return "zombie chasing" end
        end
        return nil
    end
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)

        if z ~= nil and z:isAlive() and not Bridge.isCompanion(z) and not BridgeData.dragged(z) then
            local zx, zy = z:getX() - playerObj:getX(), z:getY() - playerObj:getY()
            local d2 = zx * zx + zy * zy
            if d2 < 4 * 4 then return "zombie within 4" end
            if d2 < 20 * 20 then
                local seen = false
                pcall(function() seen = playerObj:CanSee(z) end)
                if seen then return "zombie in sight" end
            end
            local chasing = false
            pcall(function() chasing = z:getTarget() == playerObj end)
            if chasing then return "zombie chasing" end
        end
    end
    return nil
end


function BridgeSleep.movementKeyDown()
    local down = false
    pcall(function()
        for _, name in ipairs({ "Forward", "Backward", "Left", "Right" }) do
            if GameKeyboard.isKeyDown(name) then down = true return end
        end
    end)
    return down
end


function BridgeSleep.onTickEvenPaused()
    if isClient() then return end
    local c = controls()
    if c == nil then return end
    local before = BridgeSleep.wantedSpeed
    BridgeSleep.wantedSpeed = c:getCurrentGameSpeed()




    if SPEED_MULT[BridgeSleep.wantedSpeed] ~= nil and BridgeSleep.movementKeyDown() then
        c:SetCurrentGameSpeed(1)
        BridgeSleep.wantedSpeed = 1
        log("movement key: fast forward stopped before the step")
    end
    if SPEED_MULT[BridgeSleep.wantedSpeed] ~= nil and BridgeSleep.wantedSpeed ~= before then
        BridgeSleep.traceLeft = 120
        BridgeSleep.rateAt = nil
    end
    speedTrace("evenPaused", c)
    if BridgeSleep.traceLeft > 0 then BridgeSleep.traceLeft = BridgeSleep.traceLeft - 1 end

    if SPEED_MULT[BridgeSleep.wantedSpeed] ~= nil then
        pcall(function()
            local hours = getGameTime():getWorldAgeHours()
            local now = getTimestampMs()
            local r = BridgeSleep.rateAt
            if r == nil then
                BridgeSleep.rateAt = { hours = hours, ms = now }
            elseif now - r.ms >= 5000 then
                log(string.format("speed rate x%d: %.3f game hours in %.1f s", BridgeSleep.wantedSpeed,
                    hours - r.hours, (now - r.ms) / 1000))
                BridgeSleep.rateAt = { hours = hours, ms = now }
            end
        end)
    end
end


function BridgeSleep.onPlayerUpdate(playerObj)
    if isClient() or playerObj ~= BridgeData.owner() then return end
    local c = controls()
    speedTrace("playerUpdate", c)
    if c ~= nil and c:getCurrentGameSpeed() == 1 then BridgeSleep.wantedSpeed = 1 end
end



function BridgeSleep.keepSpeed(src)
    if isClient() then return end
    local want = BridgeSleep.wantedSpeed
    local mult = SPEED_MULT[want]
    if mult == nil then return end
    local c = controls()
    if c == nil then return end
    speedTrace(tostring(src or "tick"), c)
    if c:getCurrentGameSpeed() ~= 1 then

        local tm = 0
        pcall(function() tm = getGameTime():getTrueMultiplier() end)
        if c:getCurrentGameSpeed() == want and (tm or 0) < mult then
            getGameTime():setMultiplier(mult)
            pcall(function() c:SetCorrectIconStates() end)
        end
        return
    end
    local ok, why = pcall(function() return BridgeSleep.speedBlocker(BridgeData.owner()) end)
    if not ok then why = "error: " .. tostring(why) end
    if why ~= nil then
        if BridgeSleep.blockedWhy ~= why then
            BridgeSleep.blockedWhy = why
            log("speed not kept: " .. tostring(why))
        end
        BridgeSleep.wantedSpeed = 1
        return
    end
    BridgeSleep.blockedWhy = nil
    c:SetCurrentGameSpeed(want)
    getGameTime():setMultiplier(mult)

    pcall(function() c:SetCorrectIconStates() end)
    BridgeSleep.restored = BridgeSleep.restored + 1
    if BridgeSleep.restored == 1 or BridgeSleep.restored % 3600 == 0 then
        log("speed kept near companion: x" .. tostring(want) .. " times=" .. tostring(BridgeSleep.restored))
    end
end





BridgeSleep.speedKeepEnabled = false
if BridgeSleep.speedKeepEnabled then
    Events.OnTickEvenPaused.Add(BridgeSleep.onTickEvenPaused)
    Events.OnPlayerUpdate.Add(BridgeSleep.onPlayerUpdate)
    Events.OnTick.Add(function() BridgeSleep.keepSpeed("tick") end)
    Events.OnPreUIDraw.Add(function() BridgeSleep.keepSpeed("ui") end)
end

log("loaded")
