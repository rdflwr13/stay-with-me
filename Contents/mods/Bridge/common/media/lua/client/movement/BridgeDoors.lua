
BridgeDoors = BridgeDoors or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeDoors] " .. tostring(text)) end end

BridgeDoors.CACHE_MS            = 15000
BridgeDoors.REACH_CACHE_MS      = 60000
BridgeDoors.ROOMLESS_CACHE_MS   = 3000
BridgeDoors.CLOSED_PENALTY      = 1
BridgeDoors.WINDOW_PENALTY      = 1
BridgeDoors.CLOSED_WINDOW_PENALTY = 1
BridgeDoors.DETOUR_CAP          = 8
BridgeDoors.DOOR_MARGIN         = 8
BridgeDoors.MAX_SCAN            = 6400
BridgeDoors.MAX_GRAPH_SCAN      = 25000
BridgeDoors.ROOMLESS_REACH      = 3
BridgeDoors.GRAPH_STEP          = 400
BridgeDoors.GRAPH_SLICE_MS      = 50
BridgeDoors.RECHECK_MIN_AGE_MS  = 5000
BridgeDoors.RECHECK_EVERY_MS    = 20000

local OUTSIDE = -1

local graphCache = {}
local pendingGraphs = {}

local keyDenyAt = {}
local keyFindAt = {}
local logDeny = nil
local logReject = nil

local function logOn()
    return BridgeLog ~= nil and BridgeLog.on() == true
end

local function keyClock()
    return Bridge ~= nil and tonumber(Bridge.time) or 0
end

local function logRate(tbl, key, gap)
    local now = keyClock()
    if now < (tbl[key] or 0) then return false end
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    if n > 256 then
        for k in pairs(tbl) do tbl[k] = nil end
    end
    tbl[key] = now + (gap or 120)
    return true
end

local function dist2d(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end
BridgeDoors.dist2d = dist2d

local function nowMs()
    local ms = nil
    pcall(function() ms = getTimestampMs() end)
    if type(ms) == "number" then return ms end
    return math.floor((Bridge ~= nil and Bridge.time or 0) * 1000 / 60)
end


local function edgeArg(north)
    local dir = GridSquareEdgeFacingDirection
    if dir ~= nil then
        local v = nil
        if north then v = dir.NORTH_SOUTH else v = dir.EAST_WEST end
        if v ~= nil then return v end
    end
    return north
end

function BridgeDoors.doorOnEdge(sq, north)
    local o = nil
    pcall(function() o = sq:getDoor(edgeArg(north)) end)
    return o
end

function BridgeDoors.windowOnEdge(sq, north)
    local o = nil
    pcall(function() o = sq:getWindow(edgeArg(north)) end)
    return o
end

function BridgeDoors.frameOnEdge(sq, north)
    local o = nil
    pcall(function() o = sq:getWindowFrame(edgeArg(north)) end)
    return o
end


function BridgeDoors.isDoor(obj)
    local yes = false
    pcall(function()
        yes = obj ~= nil and (instanceof(obj, "IsoDoor") or (instanceof(obj, "IsoThumpable") and obj:isDoor()))
    end)
    return yes
end

function BridgeDoors.isPassable(door)
    local yes = false
    pcall(function()
        if door:getSquare() == nil or door:getObjectIndex() < 0 or door:isDestroyed() or door:IsOpen() then
            yes = true
            return
        end
        yes = BridgeDoors.canOpen(door) and ((not door:isLocked() and not door:isLockedByKey())
            or BridgeDoors.hasKey(door))
    end)
    return yes
end

function BridgeDoors.canOpen(door, fromSq)
    local yes = false
    pcall(function()
        if door == nil or door:isDestroyed() or door:isBarricaded() or door:isObstructed() then return end
        if instanceof(door, "IsoThumpable") then
            local locked = true
            pcall(function()
                locked = door:isLocked() or door:isLockedByKey() or door:isLockedByPadlock() or door:getLockedByCode() > 0
            end)
            yes = (not locked) or BridgeDoors.hasKey(door)
            if not yes and logDeny ~= nil then logDeny(door, "thumpable") end
            return
        end
        local a, b = door:getSquare(), door:getOppositeSquare()
        local ra = a ~= nil and a:getRoom() or nil
        local rb = b ~= nil and b:getRoom() or nil
        local props = door:getProperties()
        local forceLocked = false
        pcall(function() forceLocked = props ~= nil and props:has("forceLocked") == true end)
        if not forceLocked then
            if ra ~= nil and rb ~= nil then yes = true return end
            local fr = fromSq ~= nil and fromSq:getRoom() or nil
            if fr ~= nil and (fr == ra or fr == rb) then yes = true return end
        end
        local customLock = false
        pcall(function() customLock = door:hasModData() and door:getModData().CustomLock == true end)
        if door:isLockedByKey() or customLock or door:isLocked() then
            if BridgeDoors.hasKey(door) then yes = true end
            if not yes and logDeny ~= nil then logDeny(door, "door") end
            return
        end
        yes = true
    end)
    return yes
end

local function callFn(obj, name, ...)
    local fn = obj ~= nil and obj[name] or nil
    if type(fn) ~= "function" then return false, nil end
    local ok, value = pcall(fn, obj, ...)
    if not ok then return false, nil end
    return true, value
end

local function callObj(obj, name, ...)
    local ok, value = callFn(obj, name, ...)
    if ok then return value end
    return nil
end

function BridgeDoors.keyId(door)
    if door == nil then return nil end
    local id = nil
    if instanceof(door, "IsoDoor") then
        id = callObj(door, "checkKeyId")
    elseif instanceof(door, "IsoThumpable") then
        id = callObj(door, "getKeyId")
    end
    id = tonumber(id)
    if id == nil or id <= 0 then return nil end
    return id
end

local function lockKind(door)
    if door == nil or not instanceof(door, "IsoDoor") then return "single" end
    local garage = IsoDoor ~= nil and IsoDoor.getGarageDoorIndex or nil
    if type(garage) == "function" then
        local ok, idx = pcall(garage, door)
        if ok and idx ~= -1 then return "garage" end
    end
    local double = IsoDoor ~= nil and IsoDoor.getDoubleDoorIndex or nil
    if type(double) == "function" then
        local ok, idx = pcall(double, door)
        if ok and idx ~= -1 then return "double" end
    end
    return "single"
end

local keyMemo = setmetatable({}, { __mode = "k" })
BridgeDoors.KEY_MEMO_TICKS = 30

local function computeKey(door, body)
    if lockKind(door) ~= "single" then return false end
    if callObj(door, "isBarricaded") == true then return false end
    if callObj(door, "hasModData") == true then
        local md = callObj(door, "getModData")
        if md ~= nil and md.CustomLock == true then return false end
    end
    local props = callObj(door, "getProperties")
    if props ~= nil and callObj(props, "has", "forceLocked") == true then return false end
    if instanceof(door, "IsoThumpable") then
        if callObj(door, "isLockedByPadlock") == true then return false end
        local code = tonumber(callObj(door, "getLockedByCode")) or 0
        if code > 0 then return false end
    end
    local id = BridgeDoors.keyId(door)
    if id == nil then return false end
    local inv = callObj(body, "getInventory")
    if inv == nil then return false end
    local held = callObj(inv, "haveThisKeyId", id)
    return held ~= nil and held ~= false
end

function BridgeDoors.hasKey(door, body, fresh)
    if door == nil then return false end
    if body == nil then body = Bridge ~= nil and Bridge.body or nil end
    if body == nil then return false end
    local dk = nil
    pcall(function() dk = BridgeDoors.key(door) end)
    if dk == "?" then dk = nil end
    local now = Bridge ~= nil and tonumber(Bridge.time) or 0
    local memo = nil
    if not fresh and dk ~= nil then
        memo = keyMemo[body]
        if memo == nil then
            memo = {}
            keyMemo[body] = memo
        end
        local rec = memo[dk]
        if rec ~= nil and now - rec.at <= BridgeDoors.KEY_MEMO_TICKS then return rec.value end
    end
    local value = computeKey(door, body)
    if memo ~= nil and dk ~= nil then
        local rec = memo[dk]
        if rec == nil then
            if (memo.__n or 0) >= 64 then
                for k in pairs(memo) do memo[k] = nil end
                memo.__n = 0
            end
            memo.__n = (memo.__n or 0) + 1
            rec = {}
            memo[dk] = rec
        end
        rec.at = now
        rec.value = value
    end
    return value
end

function BridgeDoors.unlock(door)
    if door == nil then return false end
    local was = callObj(door, "isLocked") == true or callObj(door, "isLockedByKey") == true
    if not was then return true end
    local done = false
    if instanceof(door, "IsoDoor") then
        local a = callFn(door, "setLocked", false)
        local b = callFn(door, "setLockedByKey", false)
        done = a or b
    elseif instanceof(door, "IsoThumpable") then
        local a = callFn(door, "setIsLocked", false)
        local b = callFn(door, "setLockedByKey", false)
        done = a or b
    end
    if done then
        callFn(door, "syncIsoObject", false, 0, nil, nil)
        log("key unlock " .. tostring(BridgeDoors.key(door)))
    end
    return done
end

local function customLockFlag(door)
    if callObj(door, "hasModData") ~= true then return false end
    local md = callObj(door, "getModData")
    return md ~= nil and md.CustomLock == true
end

local function forceLockedFlag(door)
    local props = callObj(door, "getProperties")
    return props ~= nil and callObj(props, "has", "forceLocked") == true
end

local function keyItemList(body)
    local inv = body ~= nil and callObj(body, "getInventory") or nil
    if inv == nil then return "inv=nil" end
    local out, seen, count = {}, {}, 0
    local function walk(cont, depth)
        if cont == nil or depth > 2 or count >= 16 then return end
        local items = callObj(cont, "getItems")
        if items == nil then return end
        local n = tonumber(callObj(items, "size")) or 0
        for i = 0, n - 1 do
            if count >= 16 then return end
            local it = callObj(items, "get", i)
            if it ~= nil then
                local typ = tostring(callObj(it, "getType") or "?")
                local id = tonumber(callObj(it, "getKeyId"))
                local isKey = string.find(typ, "Key", 1, true) ~= nil
                if isKey or (id ~= nil and id ~= -1 and id ~= 0) then
                    out[#out + 1] = "d" .. tostring(depth) .. ":" .. typ .. "#" .. tostring(id or "?")
                    count = count + 1
                end
                local isc = callObj(it, "IsInventoryContainer")
                if isc == true then
                    local sub = callObj(it, "getInventory")
                    if sub ~= nil and not seen[sub] then
                        seen[sub] = true
                        walk(sub, depth + 1)
                    end
                end
            end
        end
    end
    seen[inv] = true
    walk(inv, 0)
    if #out == 0 then return "keys=none" end
    return "keys=" .. table.concat(out, ",")
end

function BridgeDoors.keyWhy(door, body)
    if door == nil then return "door=nil" end
    if body == nil then body = Bridge ~= nil and Bridge.body or nil end
    local class = "other"
    if instanceof(door, "IsoDoor") then
        class = "IsoDoor"
    elseif instanceof(door, "IsoThumpable") then
        class = "IsoThumpable"
    end
    local dbl, gar = "-", "-"
    if IsoDoor ~= nil then
        local f = IsoDoor.getDoubleDoorIndex
        if type(f) == "function" then
            local ok, v = pcall(f, door)
            if ok then dbl = tostring(v) end
        end
        f = IsoDoor.getGarageDoorIndex
        if type(f) == "function" then
            local ok, v = pcall(f, door)
            if ok then gar = tostring(v) end
        end
    end
    local dsx, dsy = nil, nil
    local dsq = callObj(door, "getSquare")
    if dsq ~= nil then
        dsx, dsy = callObj(dsq, "getX"), callObj(dsq, "getY")
    end
    local id = BridgeDoors.keyId(door)
    local inv = body ~= nil and callObj(body, "getInventory") or nil
    local have = nil
    if inv ~= nil and id ~= nil then have = callObj(inv, "haveThisKeyId", id) end
    local storeId = nil
    if Bridge ~= nil and Bridge.store ~= nil then storeId = Bridge.store.bodyId end
    local parts = {
        "door=" .. tostring(dsx) .. "," .. tostring(dsy),
        "class=" .. class,
        "kind=" .. lockKind(door),
        "dbl=" .. dbl,
        "gar=" .. gar,
        "locked=" .. tostring(callObj(door, "isLocked")),
        "lockKey=" .. tostring(callObj(door, "isLockedByKey")),
        "padlock=" .. tostring(callObj(door, "isLockedByPadlock")),
        "code=" .. tostring(callObj(door, "getLockedByCode")),
        "bar=" .. tostring(callObj(door, "isBarricaded")),
        "obs=" .. tostring(callObj(door, "isObstructed")),
        "custom=" .. tostring(customLockFlag(door)),
        "forced=" .. tostring(forceLockedFlag(door)),
        "check=" .. tostring(callObj(door, "checkKeyId")),
        "keyId=" .. tostring(id),
        "have=" .. tostring(have),
        "isBody=" .. tostring(body ~= nil and Bridge ~= nil and body == Bridge.body),
        "storeId=" .. tostring(storeId),
        "bx=" .. tostring(body ~= nil and callObj(body, "getX") or nil),
        "by=" .. tostring(body ~= nil and callObj(body, "getY") or nil),
    }
    return table.concat(parts, " ")
end

function BridgeDoors.keyInfo(door, body)
    return BridgeDoors.keyWhy(door, body) .. " " .. keyItemList(body)
end

logDeny = function(door, branch)
    if not logOn() then return end
    local k = "deny|" .. tostring(BridgeDoors.key(door))
    if not logRate(keyDenyAt, k, 120) then return end
    log("deny branch=" .. tostring(branch) .. " " .. BridgeDoors.keyWhy(door, nil))
end

logReject = function(d, avoid, fromX, fromY, leaving)
    if not logOn() then return end
    local k = "find|" .. tostring(d.key)
    if not logRate(keyFindAt, k, 120) then return end
    local near = d.outside
    if leaving then near = d.inside end
    local dNear = "-"
    if near ~= nil then dNear = string.format("%.2f", dist2d(fromX, fromY, near:getX() + 0.5, near:getY() + 0.5)) end
    log("find reject key=" .. tostring(d.key)
        .. " avoid=" .. tostring(avoid ~= nil and avoid[d.key] == true)
        .. " in=" .. tostring(d.inside ~= nil)
        .. " out=" .. tostring(d.outside ~= nil)
        .. " dNear=" .. tostring(dNear)
        .. " " .. BridgeDoors.keyWhy(d.obj, nil))
end

function BridgeDoors.isClimbable(obj)
    local yes = false
    pcall(function() yes = obj:canClimbThrough(nil) end)
    return yes
end

function BridgeDoors.isOpenableWindow(obj)
    local yes = false
    pcall(function()
        yes = obj ~= nil and instanceof(obj, "IsoWindow") and not obj:IsOpen() and not obj:isSmashed()
            and not obj:isDestroyed() and not obj:isLocked() and not obj:isPermaLocked() and not obj:isBarricaded()
    end)
    return yes
end


function BridgeDoors.isCurtain(obj)
    local yes = false
    pcall(function() yes = obj ~= nil and instanceof(obj, "IsoCurtain") end)
    return yes
end


function BridgeDoors.curtainOpen(curtain)
    if curtain == nil then return nil end
    local open = nil
    pcall(function()
        if type(curtain.IsOpen) == "function" then
            open = curtain:IsOpen() == true
        elseif type(curtain.isCurtainOpen) == "function" then
            open = curtain:isCurtainOpen() == true
        end
    end)
    return open
end


function BridgeDoors.curtainParent(curtain)
    if curtain == nil then return nil end
    local parent = nil
    pcall(function()
        if type(curtain.getObjectAttachedTo) == "function" then parent = curtain:getObjectAttachedTo() end
    end)
    if parent ~= nil and (instanceof(parent, "IsoWindow") or instanceof(parent, "IsoDoor")) then return parent end
    local sq = nil
    pcall(function() sq = curtain:getSquare() end)
    if sq == nil then return nil end
    local function scan(s)
        if s == nil then return nil end
        local found = nil
        local function check(list)
            if list == nil or found ~= nil then return end
            local n = list:size()
            for i = 0, n - 1 do
                local o = list:get(i)
                if o ~= nil and (instanceof(o, "IsoWindow") or instanceof(o, "IsoDoor")) then
                    local c = nil
                    pcall(function() c = o:HasCurtains() end)
                    if c == curtain then found = o return end
                end
            end
        end
        pcall(function() check(s:getObjects()) end)
        pcall(function() check(s:getSpecialObjects()) end)
        pcall(function() check(s:getWorldObjects()) end)
        return found
    end
    local found = scan(sq)
    if found ~= nil then return found end
    local opp = nil
    pcall(function() opp = curtain:getOppositeSquare() end)
    if opp ~= nil and opp ~= sq then found = scan(opp) end
    return found
end


function BridgeDoors.curtainBlocked(curtain)
    if curtain == nil then return "gone" end
    local gone, idx = false, 0
    pcall(function()
        gone = type(curtain.isDestroyed) == "function" and curtain:isDestroyed() == true
        idx = type(curtain.getObjectIndex) == "function" and tonumber(curtain:getObjectIndex()) or 0
    end)
    if gone or idx < 0 then return "gone" end
    return nil
end

function BridgeDoors.usableWindow(obj)
    if obj == nil then return false end
    return BridgeDoors.isClimbable(obj) or BridgeDoors.isOpenableWindow(obj)
end

function BridgeDoors.canClimbAcross(a, b)
    local yes = false
    pcall(function() yes = a ~= nil and b ~= nil and a:isFree(false) and b:isFree(false) end)
    return yes
end

function BridgeDoors.isInteriorWindow(window)
    local yes = false
    pcall(function()
        local a, b = window:getSquare(), window:getOppositeSquare()
        if a == nil or b == nil or a:getRoom() == nil or b:getRoom() == nil then return end
        local ia = BridgeDoors.buildingId(a)
        yes = ia ~= nil and ia == BridgeDoors.buildingId(b)
    end)
    return yes
end

function BridgeDoors.key(obj)
    local key = "?"
    pcall(function()
        local sq = obj:getSquare()
        if sq == nil then return end
        key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() .. (obj:getNorth() and "N" or "W")
    end)
    return key
end

function BridgeDoors.center(obj)
    local x, y = nil, nil
    pcall(function()
        local sq = obj:getSquare()
        if obj:getNorth() then x, y = sq:getX() + 0.5, sq:getY() else x, y = sq:getX(), sq:getY() + 0.5 end
    end)
    return x, y
end


local function inDef(b, sq)
    local yes = false
    pcall(function()
        local def = b ~= nil and b:getDef() or nil
        if def == nil then return end
        local x, y, z = sq:getX(), sq:getY(), sq:getZ()
        yes = x >= def:getX() and x <= def:getX2() and y >= def:getY() and y <= def:getY2()
            and z >= def:getMinLevel() and z <= def:getMaxLevel()
    end)
    return yes
end

local roomlessCache, roomlessCacheSize = {}, 0

local function buildingOfRoomlessRaw(sq)
    local found = nil
    pcall(function()
        local cell = getCell()
        local z = sq:getZ()
        local seen = { [sq] = true }
        local front = { sq }
        for _ = 1, BridgeDoors.ROOMLESS_REACH do
            local nextFront = {}
            for _, s in ipairs(front) do
                for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                    local n = cell:getGridSquare(s:getX() + o[1], s:getY() + o[2], z)
                    if n ~= nil and not seen[n] and not s:isBlockedTo(n) and not s:isWallTo(n)
                        and not s:isWindowTo(n) and not s:isDoorTo(n) then
                        seen[n] = true
                        local b = n:getBuilding()
                        if b ~= nil then
                            if inDef(b, sq) then found = b return end
                        else
                            nextFront[#nextFront + 1] = n
                        end
                    end
                end
            end
            front = nextFront
            if #front == 0 then break end
        end
    end)
    return found
end

local function buildingOfRoomless(sq)
    if sq == nil then return nil end
    local key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
    local now = nowMs()
    local c = roomlessCache[key]
    if c ~= nil and now - c.ms < BridgeDoors.ROOMLESS_CACHE_MS then return c.b end
    local b = buildingOfRoomlessRaw(sq)
    if roomlessCacheSize > 2000 then roomlessCache, roomlessCacheSize = {}, 0 end
    if c == nil then roomlessCacheSize = roomlessCacheSize + 1 end
    roomlessCache[key] = { ms = now, b = b }
    return b
end

function BridgeDoors.buildingOf(sq)
    local b = nil
    pcall(function() b = sq ~= nil and sq:getBuilding() or nil end)
    if b == nil then b = buildingOfRoomless(sq) end
    return b
end

function BridgeDoors.buildingId(sq)
    if sq == nil then return nil end
    local b = BridgeDoors.buildingOf(sq)
    if b == nil then return nil end
    local id = nil
    pcall(function() id = b:getID() end)
    return id
end

function BridgeDoors.enclosureKey(sq)
    if sq == nil then return -1 end
    local id = BridgeDoors.buildingId(sq)
    if id == nil then return -1 end
    return id
end


local STAND_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

local function hasWayIn(n, src)
    local yes = false
    pcall(function()
        local cell = getCell()
        for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local m = cell:getGridSquare(n:getX() + o[1], n:getY() + o[2], n:getZ())
            if m ~= nil and m ~= src and m:canStand() and not n:isBlockedTo(m) and not n:isWindowTo(m)
                and not n:isWallTo(m) then
                yes = true
                return
            end
        end
    end)
    return yes
end

local function standOk(src, n, srcBuilding)
    local yes = false
    pcall(function()
        if n == nil or n == src or n:getZ() ~= src:getZ() or not n:canStand() then return end
        if src:isWallTo(n) or src:isWindowTo(n) then return end
        if srcBuilding ~= nil and BridgeDoors.buildingId(n) ~= srcBuilding then return end
        if not hasWayIn(n, src) then return end
        yes = true
    end)
    return yes
end

function BridgeDoors.standNear(sq, body)
    if sq == nil then return nil end
    local srcBuilding = BridgeDoors.buildingId(sq)
    local best, bestDist = nil, nil
    pcall(function()
        local adj = AdjacentFreeTileFinder.Find(sq, body)
        if adj ~= nil and standOk(sq, adj, srcBuilding) then best = adj end
    end)
    if best == nil then
        pcall(function()
            local cell = getCell()
            for i, o in ipairs(STAND_DIRS) do
                if i == 5 and best ~= nil then break end
                local n = cell:getGridSquare(sq:getX() + o[1], sq:getY() + o[2], sq:getZ())
                if standOk(sq, n, srcBuilding) then
                    local d = dist2d(body and body:getX() or 0, body and body:getY() or 0, n:getX() + 0.5, n:getY() + 0.5)
                    if bestDist == nil or d < bestDist then best, bestDist = n, d end
                end
            end
        end)
    end
    if best ~= nil then return best end
    local can = false
    pcall(function() can = sq:canStand() and hasWayIn(sq, nil) end)
    if can then return sq end
    return nil
end


local cache = {}

function BridgeDoors.invalidate()
    cache = {}
    graphCache = {}
    pendingGraphs = {}
end

local pruneAt = 0

local function pruneCaches(now)
    if now - pruneAt < 60000 then return end
    pruneAt = now
    for k, v in pairs(graphCache) do
        if now - (v.at or 0) > BridgeDoors.REACH_CACHE_MS * 2 then graphCache[k] = nil end
    end
    for k, v in pairs(cache) do
        if now - (v.at or 0) > BridgeDoors.CACHE_MS * 2 then cache[k] = nil end
    end
    for k, v in pairs(pendingGraphs) do
        if now - (v.at or 0) > 120000 then pendingGraphs[k] = nil end
    end
end

local function exteriorSides(obj, buildingId)
    local inside, outside = nil, nil
    pcall(function()
        local a, b = obj:getSquare(), obj:getOppositeSquare()
        if a == nil or b == nil then return end
        local ia, ib = BridgeDoors.buildingId(a), BridgeDoors.buildingId(b)
        if ia == buildingId and ib ~= buildingId then inside, outside = a, b
        elseif ib == buildingId and ia ~= buildingId then inside, outside = b, a end
    end)
    return inside, outside
end

local function addOpening(list, obj, kind, buildingId)
    if obj == nil then return end
    local inside, outside = exteriorSides(obj, buildingId)
    if inside ~= nil then
        list[#list + 1] = { obj = obj, kind = kind, inside = inside, outside = outside, key = BridgeDoors.key(obj) }
    end
end

local function scanBuilding(building, z)
    local list = {}
    local def = nil
    pcall(function() def = building:getDef() end)
    if def == nil then return list end
    local x1, y1, x2, y2 = def:getX() - 1, def:getY() - 1, def:getX2() + 1, def:getY2() + 1
    if (x2 - x1 + 1) * (y2 - y1 + 1) > BridgeDoors.MAX_SCAN then return list end
    local id = nil
    pcall(function() id = building:getID() end)
    if id == nil then return list end
    local cell = getCell()
    for x = x1, x2 do
        for y = y1, y2 do
            local sq = cell:getGridSquare(x, y, z)
            if sq ~= nil then
                for n = 1, 2 do
                    local north = n == 1
                    addOpening(list, BridgeDoors.doorOnEdge(sq, north), "door", id)
                    addOpening(list, BridgeDoors.windowOnEdge(sq, north), "window", id)
                    local frame = BridgeDoors.frameOnEdge(sq, north)
                    if frame ~= nil then
                        local has = true
                        pcall(function() has = frame:hasWindow() end)
                        if not has then addOpening(list, frame, "window", id) end
                    end
                end
            end
        end
    end
    return list
end

local function exteriorOpenings(building, z)
    local id = nil
    pcall(function() id = building:getID() end)
    if id == nil then return {} end
    local key = tostring(id) .. "@" .. z
    local now = nowMs()
    pruneCaches(now)
    local c = cache[key]
    if c == nil or now - c.at > BridgeDoors.CACHE_MS then
        c = { at = now, list = scanBuilding(building, z) }
        cache[key] = c
    end
    return c.list
end
BridgeDoors.exteriorOpenings = exteriorOpenings

function BridgeDoors.debugOpenings(building, z, leaving)
    local parts = {}
    pcall(function()
        local list = exteriorOpenings(building, z)
        for i = 1, #list do
            local d = list[i]
            local why = "?"
            if d.kind == "door" then
                if d.obj:IsOpen() then why = "open"
                elseif d.obj:isBarricaded() then why = "barricaded"
                elseif d.obj:isObstructed() then why = "obstructed"
                elseif BridgeDoors.canOpen(d.obj, leaving and d.inside or d.outside) then why = "openable"
                else why = "locked" end
            else
                if BridgeDoors.isClimbable(d.obj) then why = "climbable"
                elseif BridgeDoors.isOpenableWindow(d.obj) then why = "window-openable"
                elseif d.obj:isBarricaded() then why = "window-barricaded"
                else why = "window-no" end
            end
            local sx, sy = -1, -1
            pcall(function() local s = d.obj:getSquare(); sx, sy = s:getX(), s:getY() end)
            if d.kind == "door" then
                local kinfo = "-"
                if why == "locked" or why == "barricaded" or why == "obstructed" then
                    kinfo = BridgeDoors.keyWhy(d.obj, nil)
                end
                parts[#parts + 1] = string.format("%s:%s@%d,%d in=%s out=%s [%s]",
                    d.kind, why, sx, sy, tostring(d.inside ~= nil), tostring(d.outside ~= nil), kinfo)
            else
                parts[#parts + 1] = string.format("%s:%s@%d,%d", d.kind, why, sx, sy)
            end
        end
    end)
    return table.concat(parts, " | ")
end

function BridgeDoors.findOpening(building, z, fromX, fromY, toX, toY, leaving, doorsFirst, avoid)
    if building == nil then return nil end
    local list = exteriorOpenings(building, z)
    local cands = {}
    for i = 1, #list do
        local d = list[i]
        if (avoid == nil or not avoid[d.key]) and d.obj:getSquare() ~= nil then
            local extra = nil
            if d.kind == "door" then
                if d.obj:IsOpen() then
                    extra = 0
                elseif BridgeDoors.canOpen(d.obj, leaving and d.inside or d.outside) then
                    extra = BridgeDoors.CLOSED_PENALTY
                elseif logReject ~= nil then
                    logReject(d, avoid, fromX, fromY, leaving)
                end
            elseif d.kind == "window" and BridgeDoors.canClimbAcross(d.inside, d.outside) then
                if BridgeDoors.isClimbable(d.obj) then
                    extra = BridgeDoors.WINDOW_PENALTY
                elseif BridgeDoors.isOpenableWindow(d.obj) then
                    extra = BridgeDoors.WINDOW_PENALTY + BridgeDoors.CLOSED_WINDOW_PENALTY
                end
            end
            if extra ~= nil then
                local near, far = d.outside, d.inside
                if leaving then near, far = d.inside, d.outside end
                if near ~= nil and far ~= nil then
                    local nx, ny = near:getX() + 0.5, near:getY() + 0.5
                    local fx, fy = far:getX() + 0.5, far:getY() + 0.5
                    cands[#cands + 1] = { obj = d.obj, kind = d.kind, near = near, far = far, key = d.key,
                        dNear = dist2d(fromX, fromY, nx, ny), dFar = dist2d(fx, fy, toX, toY), extra = extra }
                end
            end
        end
    end
    if #cands == 0 then
        if BridgeLog ~= nil and BridgeLog.on() then
            BridgeLog.event("route.opening.select", { candidates = 0, avoid_keys = 0, kind = "-",
                dNear = -1, dFar = -1, extra = -1, why = "none", fn = "BridgeDoors.findOpening" })
        end
        return nil
    end
    local function openingEv(p, why)
        if BridgeLog == nil or not BridgeLog.on() then return end
        local avoidN = 0
        if avoid ~= nil then for _ in pairs(avoid) do avoidN = avoidN + 1 end end
        BridgeLog.event("route.opening.select", {
            candidates = #cands, avoid_keys = avoidN,
            chosen = (p ~= nil and p.near ~= nil) and { x = p.near:getX(), y = p.near:getY() } or nil,
            kind = p ~= nil and p.kind or "-",
            dNear = p ~= nil and p.dNear or -1, dFar = p ~= nil and p.dFar or -1,
            extra = p ~= nil and p.extra or -1, why = why, fn = "BridgeDoors.findOpening" })
    end
    local nearest = math.huge
    for i = 1, #cands do
        if cands[i].dNear < nearest then nearest = cands[i].dNear end
    end
    local cap = nearest + BridgeDoors.DETOUR_CAP
    local nearW = leaving and 0.5 or 1.0
    local reachFilter = false
    if not leaving and BridgeDoors.canReachInterior ~= nil then
        local toSq = nil
        pcall(function() toSq = getCell():getGridSquare(math.floor(toX), math.floor(toY), z) end)
        if toSq ~= nil then
            local anyOk = false
            for i = 1, #cands do
                local p = cands[i]
                local ok = false
                pcall(function() ok = BridgeDoors.canReachInterior(p.far, toSq) end)
                p.reachOk = ok
                if ok then anyOk = true end
            end
            reachFilter = anyOk
        end
    end
    local bestDoor, bestDoorScore, bestWin, bestWinScore = nil, nil, nil, nil
    for i = 1, #cands do
        local p = cands[i]
        local score = (p.dNear * nearW) + p.dFar + (p.extra or 0)
        p.score = score
        p.inCap = p.dNear <= cap
        if not reachFilter or p.reachOk then
            if p.kind == "door" and (bestDoorScore == nil or score < bestDoorScore) then
                bestDoor, bestDoorScore = p, score
            elseif p.kind == "window" and (bestWinScore == nil or score < bestWinScore) then
                bestWin, bestWinScore = p, score
            end
        end
    end    local function candEv(p, why)
        if not logOn() then return end
        if BridgeDoors.candAt == nil then BridgeDoors.candAt = {} end
        if not logRate(BridgeDoors.candAt, "cand", 60) then return end
        BridgeLog.event("route.opening.candidates", {
            from = { x = fromX, y = fromY }, to = { x = toX, y = toY },
            leaving = leaving and 1 or 0, doors_first = doorsFirst and 1 or 0,
            nearest = nearest, cap = cap, count = #cands,
            bestDoor = bestDoorScore, bestWin = bestWinScore,
            chosen = p ~= nil and p.key or nil, why = why,
            fn = "BridgeDoors.findOpening" })
        for i = 1, #cands do
            local c = cands[i]
            local tag = "-"
            if p ~= nil and c == p then
                tag = "chosen"
            elseif c.kind == "door" and c == bestDoor then
                tag = "bestDoor"
            elseif c.kind == "window" and c == bestWin then
                tag = "bestWin"
            end
            BridgeLog.event("route.opening.cand", {
                i = i, kind = c.kind, key = c.key,
                dNear = c.dNear, dFar = c.dFar, extra = c.extra,
                score = c.score, inCap = c.dNear <= cap and 1 or 0,
                tag = tag, fn = "BridgeDoors.findOpening" })
        end
    end
    if bestDoor ~= nil and bestWin ~= nil then
        local margin = BridgeDoors.DOOR_MARGIN or 8
        if bestWinScore < bestDoorScore - margin then
            candEv(bestWin, "window-far-door")
            openingEv(bestWin, "window-far-door")
            return bestWin
        end
    end
    if bestDoor ~= nil then candEv(bestDoor, "door") openingEv(bestDoor, "door") return bestDoor end
    if bestWin ~= nil then candEv(bestWin, "window") openingEv(bestWin, "window") return bestWin end
    local pick = cands[1]
    for i = 1, #cands do
        if cands[i].dNear < pick.dNear then pick = cands[i] end
    end
    candEv(pick, "nearest")
    openingEv(pick, "nearest")
    return pick
end


local lastRecheck = {}
local sliceMs, sliceLeft = 0, 0

local UNKNOWN = { tooBig = true, links = {}, reach = {} }

local function roomNode(sq, building)
    local node = OUTSIDE
    pcall(function()
        if sq:getBuilding() == building and sq:getRoom() ~= nil then node = sq:getRoomID() end
    end)
    return node
end

local function edgeOpen(sq, other)
    local open, free = false, false
    pcall(function()
        local door = sq:getDoorTo(other)
        if door ~= nil then
            local interior = sq:getRoom() ~= nil and other:getRoom() ~= nil
            open = BridgeDoors.isPassable(door) or (interior and BridgeDoors.canOpen(door))
            return
        end
        local window = sq:getWindowTo(other)
        if window ~= nil then
            open = BridgeDoors.isClimbable(window) or BridgeDoors.isOpenableWindow(window)
            return
        end
        local frame = sq:getWindowFrameTo(other)
        if frame ~= nil then
            open = BridgeDoors.isClimbable(frame)
            return
        end
        open = not sq:isBlockedTo(other)
        free = open
    end)
    return open, free
end

local function link(links, a, b)
    links[a] = links[a] or {}
    links[b] = links[b] or {}
    links[a][b], links[b][a] = true, true
end

local function addPortal(portals, a, b, ax, ay, bx, by, z, free)
    portals[a] = portals[a] or {}
    portals[a][b] = portals[a][b] or {}
    local list = portals[a][b]
    for i = 1, #list do
        local p = list[i]
        if p.ax == ax and p.ay == ay and p.bx == bx and p.by == by then
            if free then p.free = true end
            return
        end
    end
    list[#list + 1] = { ax = ax, ay = ay, bx = bx, by = by, z = z, free = free == true }
end

local function stepGraph(p)
    local now = nowMs()
    local startMs = now
    if now - sliceMs >= BridgeDoors.GRAPH_SLICE_MS then sliceMs, sliceLeft = now, BridgeDoors.GRAPH_STEP end
    local cell = getCell()
    while sliceLeft > 0 and p.x <= p.x2 do
        if (sliceLeft % 20) == 0 and (nowMs() - startMs) >= 5 then break end
        local sq = cell:getGridSquare(p.x, p.y, p.z)
        if sq ~= nil then
            local a = roomNode(sq, p.building)
            if a ~= OUTSIDE and p.rooms[a] == nil then p.rooms[a] = sq:getRoom() end
            for n = 1, 2 do
                local other = cell:getGridSquare(p.x + (n == 1 and 1 or 0), p.y + (n == 2 and 1 or 0), p.z)
                if other ~= nil then
                    local b = roomNode(other, p.building)
                    if a ~= b then
                        local open, free = edgeOpen(sq, other)
                        if open then
                            link(p.links, a, b)
                            if a ~= OUTSIDE and b ~= OUTSIDE then
                                addPortal(p.portals, a, b, sq:getX(), sq:getY(),
                                    other:getX(), other:getY(), p.z, free)
                                addPortal(p.portals, b, a, other:getX(), other:getY(),
                                    sq:getX(), sq:getY(), p.z, free)
                            end
                        end
                        if free then link(p.free, a, b) end
                    end
                end
            end
        end
        sliceLeft = sliceLeft - 1
        p.y = p.y + 1
        if p.y > p.y2 then p.y, p.x = p.y1, p.x + 1 end
    end
    return p.x > p.x2
end

local function roomGraph(building, z)
    local id = nil
    pcall(function() id = building:getID() end)
    if id == nil then return UNKNOWN end
    local key = tostring(id) .. "@" .. z
    local now = nowMs()
    pruneCaches(now)
    local g = graphCache[key]
    if g ~= nil and now - g.at < BridgeDoors.REACH_CACHE_MS then return g end
    local p = pendingGraphs[key]
    if p == nil then
        local def = nil
        pcall(function() def = building:getDef() end)
        if def == nil then return g or UNKNOWN end
        local x1, y1, x2, y2 = def:getX() - 1, def:getY() - 1, def:getX2() + 1, def:getY2() + 1
        if (x2 - x1 + 1) * (y2 - y1 + 1) > BridgeDoors.MAX_GRAPH_SCAN then
            g = { at = now, tooBig = true, links = {}, reach = {} }
            graphCache[key] = g
            return g
        end
        p = { links = {}, free = {}, rooms = {}, portals = {}, building = building, z = z,
              x1 = x1, y1 = y1, x2 = x2, y2 = y2, x = x1, y = y1, at = now }
        pendingGraphs[key] = p
    end
    if not stepGraph(p) then return g or UNKNOWN end
    pendingGraphs[key] = nil
    g = { at = now, links = p.links, free = p.free, rooms = p.rooms, portals = p.portals, reach = {} }
    graphCache[key] = g
    return g
end

local function recheckGraph(building, z)
    local id = nil
    pcall(function() id = building:getID() end)
    if id == nil then return false end
    local key = tostring(id) .. "@" .. z
    local g = graphCache[key]
    local now = nowMs()
    if g == nil or g.tooBig or pendingGraphs[key] ~= nil or now - g.at < BridgeDoors.RECHECK_MIN_AGE_MS
        or now - (lastRecheck[key] or -BridgeDoors.RECHECK_EVERY_MS) < BridgeDoors.RECHECK_EVERY_MS then
        return false
    end
    lastRecheck[key] = now
    graphCache[key] = nil
    return true
end

local function reachSet(g, start)
    local set = g.reach[start]
    if set ~= nil then return set end
    set = { [start] = true }
    local queue = { start }
    while #queue > 0 do
        local node = table.remove(queue)
        for other in pairs(g.links[node] or {}) do
            if not set[other] then
                set[other] = true
                queue[#queue + 1] = other
            end
        end
    end
    g.reach[start] = set
    return set
end

local function reachSetInterior(g, start)
    local key = "i" .. tostring(start)
    local set = g.reach[key]
    if set ~= nil then return set end
    set = { [start] = true }
    local queue = { start }
    while #queue > 0 do
        local node = table.remove(queue)
        for other in pairs(g.links[node] or {}) do
            if other ~= OUTSIDE and not set[other] then
                set[other] = true
                queue[#queue + 1] = other
            end
        end
    end
    g.reach[key] = set
    return set
end

local function reachableIn(building, z, fromNode, toNode)
    local g = roomGraph(building, z)
    if g.tooBig then return true end
    if reachSet(g, fromNode)[toNode] == true then return true end
    if recheckGraph(building, z) then return true end
    return false
end

function BridgeDoors.canReach(fromSq, toSq)
    local ok, result = pcall(function()
        if fromSq == nil or toSq == nil or fromSq == toSq then return true end
        local z = fromSq:getZ()
        if toSq:getZ() ~= z then return true end
        local fromB, toB = fromSq:getBuilding(), toSq:getBuilding()
        if fromB == nil and toB == nil then return true end
        if fromB ~= nil and toB ~= nil and fromB ~= toB then
            return reachableIn(fromB, z, roomNode(fromSq, fromB), OUTSIDE)
                and reachableIn(toB, z, OUTSIDE, roomNode(toSq, toB))
        end
        local b = fromB or toB
        return reachableIn(b, z, roomNode(fromSq, b), roomNode(toSq, b))
    end)
    if not ok then return true end
    return result == true
end

function BridgeDoors.canReachInterior(fromSq, toSq)
    local ok, result = pcall(function()
        if fromSq == nil or toSq == nil then return true end
        local z = fromSq:getZ()
        if toSq:getZ() ~= z then return true end
        local b = fromSq:getBuilding()
        if b == nil or toSq:getBuilding() ~= b then return true end
        local fromNode, toNode = roomNode(fromSq, b), roomNode(toSq, b)
        if fromNode == OUTSIDE or toNode == OUTSIDE then return true end
        if fromNode == toNode then return true end
        local g = roomGraph(b, z)
        if g.tooBig then return true end
        if reachSetInterior(g, fromNode)[toNode] == true then return true end
        if recheckGraph(b, z) then return true end
        return false
    end)
    if not ok then return true end
    return result == true
end

function BridgeDoors.findInteriorPortal(building, z, fromRoom, toRoom, fromX, fromY, toX, toY)
    if building == nil or fromRoom == nil or toRoom == nil then return nil end
    if fromRoom == OUTSIDE or toRoom == OUTSIDE or fromRoom == toRoom then return nil end
    local g = roomGraph(building, z)
    if g == nil or g.tooBig or g.portals == nil then return nil end
    local prev, seen, queue = {}, { [fromRoom] = true }, { fromRoom }
    while #queue > 0 do
        local node = table.remove(queue, 1)
        if node == toRoom then break end
        for other in pairs(g.links[node] or {}) do
            if other ~= OUTSIDE and not seen[other] then
                seen[other] = true
                prev[other] = node
                queue[#queue + 1] = other
            end
        end
    end
    if not seen[toRoom] then return nil end
    local hop = toRoom
    while prev[hop] ~= nil and prev[hop] ~= fromRoom do hop = prev[hop] end
    if prev[hop] == nil then return nil end
    local nextRoom = hop
    local list = g.portals[fromRoom] ~= nil and g.portals[fromRoom][nextRoom] or nil
    if list == nil or #list == 0 then return nil end
    local cell = getCell()
    if cell == nil then return nil end
    local goalX = toX or fromX
    local goalY = toY or fromY
    local best, bestScore = nil, math.huge
    for i = 1, #list do
        local p = list[i]
        local farSq = cell:getGridSquare(p.bx, p.by, p.z)
        local standable = false
        if farSq ~= nil then pcall(function() standable = farSq:isFree(false) == true end) end
        if standable then
            local dNow = dist2d(fromX, fromY, p.ax + 0.5, p.ay + 0.5)
            local dGoal = dist2d(p.bx + 0.5, p.by + 0.5, goalX, goalY)
            local score = dNow + dGoal
            if not p.free then score = score + 4 end
            if score < bestScore then best, bestScore = p, score end
        end
    end
    if best == nil then return nil end
    local near = cell:getGridSquare(best.ax, best.ay, best.z)
    local far = cell:getGridSquare(best.bx, best.by, best.z)
    if near == nil or far == nil then return nil end
    local door = nil
    pcall(function() door = near:getDoorTo(far) end)
    local key = "room:" .. tostring(fromRoom) .. ">" .. tostring(nextRoom)
        .. "@" .. best.ax .. "," .. best.ay
    return { obj = door, kind = door ~= nil and "door" or "arch", near = near, far = far,
        key = key, nextRoom = nextRoom, interior = true,
        dNear = dist2d(fromX, fromY, best.ax + 0.5, best.ay + 0.5),
        dFar = dist2d(best.bx + 0.5, best.by + 0.5, goalX, goalY), extra = 0 }
end

function BridgeDoors.debugInfo(body, door)
    if door == nil then return "-" end
    local parts = {}
    local dsq, osq, bs = nil, nil, nil
    pcall(function() dsq = door:getSquare() end)
    pcall(function() osq = door:getOppositeSquare() end)
    pcall(function() bs = body ~= nil and body:getCurrentSquare() or nil end)
    parts[#parts + 1] = "doorSq=" .. (dsq ~= nil and (dsq:getX() .. "," .. dsq:getY()) or "-")
    parts[#parts + 1] = "opp=" .. (osq ~= nil and (osq:getX() .. "," .. osq:getY()) or "-")
    parts[#parts + 1] = "bodySq=" .. (bs ~= nil and (bs:getX() .. "," .. bs:getY()) or "-")
    local north = false
    pcall(function() north = door:getNorth() == true end)
    parts[#parts + 1] = "north=" .. tostring(north)
    local open = false
    pcall(function() open = door:IsOpen() == true end)
    parts[#parts + 1] = "open=" .. tostring(open)
    local locked = false
    pcall(function() locked = door:isLocked() == true end)
    parts[#parts + 1] = "locked=" .. tostring(locked)
    local lockKey = false
    pcall(function() lockKey = door:isLockedByKey() == true end)
    parts[#parts + 1] = "lockKey=" .. tostring(lockKey)
    local barricade = false
    pcall(function() barricade = door:isBarricaded() == true end)
    parts[#parts + 1] = "barricade=" .. tostring(barricade)
    local obstructed = false
    pcall(function() obstructed = door:isObstructed() == true end)
    parts[#parts + 1] = "obstructed=" .. tostring(obstructed)
    local idx = -1
    pcall(function() idx = door:getObjectIndex() end)
    parts[#parts + 1] = "idx=" .. tostring(idx)
    return table.concat(parts, " ")
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeDoors] loaded") end
