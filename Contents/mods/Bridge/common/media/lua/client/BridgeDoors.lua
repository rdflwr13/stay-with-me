-- BridgeDoors: reachability + opening routing for task movement.
--
-- The zombie pathfinder treats her body as a zombie (canThump = true), so closed
-- doors and windows count as passable and it plans a route straight through them;
-- the body then just stops at the collision. ProjectSurvivors documents the same
-- behaviour. This module answers two questions instead:
--   * canReach(fromSq, toSq): is there a usable way between the two squares on
--     this floor, through open passages, usable doors or climbable windows?
--   * findOpening(...): which exterior opening of a building to walk through.
-- It also knows the enclosing building of a square (roomless squares included).
--
-- Everything here is read-only and defensively wrapped: a false negative that
-- blocks a reachable target is worse than a missed abort, so unknown/oversized
-- buildings and nil squares count as reachable.

BridgeDoors = BridgeDoors or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeDoors] " .. tostring(text)) end end

BridgeDoors.CACHE_MS            = 15000  -- remember a building's exterior openings this long
BridgeDoors.REACH_CACHE_MS      = 60000  -- room graph rebuild interval per building@floor
BridgeDoors.ROOMLESS_CACHE_MS   = 3000   -- roomless-square lookup cache
BridgeDoors.CLOSED_PENALTY      = 1      -- a closed (openable) door: small tie-break cost
BridgeDoors.WINDOW_PENALTY      = 1      -- climbing through: small tie-break cost
BridgeDoors.CLOSED_WINDOW_PENALTY = 1    -- a closed window: small tie-break cost
BridgeDoors.DETOUR_CAP          = 8      -- may use an opening up to this many tiles past the nearest
BridgeDoors.MAX_SCAN            = 6400   -- larger building rectangles are not scanned
BridgeDoors.MAX_GRAPH_SCAN      = 25000  -- the room graph may be larger (built in slices)
BridgeDoors.ROOMLESS_REACH      = 3
BridgeDoors.GRAPH_STEP          = 400
BridgeDoors.GRAPH_SLICE_MS      = 50
BridgeDoors.RECHECK_MIN_AGE_MS  = 5000
BridgeDoors.RECHECK_EVERY_MS    = 20000

local OUTSIDE = -1

local graphCache = {}
local pendingGraphs = {}

local function dist2d(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end
BridgeDoors.dist2d = dist2d

-- Milliseconds clock for the caches; falls back to Bridge.time (60/s) if the
-- engine accessor is unavailable on this build.
local function nowMs()
    local ms = nil
    pcall(function() ms = getTimestampMs() end)
    if type(ms) == "number" then return ms end
    return math.floor((Bridge ~= nil and Bridge.time or 0) * 1000 / 60)
end

----------------------------------------------------------------------------
-- Edge lookups (older builds use a "north" boolean, newer an enum)
----------------------------------------------------------------------------

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

----------------------------------------------------------------------------
-- Opening predicates
----------------------------------------------------------------------------

function BridgeDoors.isDoor(obj)
    local yes = false
    pcall(function()
        yes = obj ~= nil and (instanceof(obj, "IsoDoor") or (instanceof(obj, "IsoThumpable") and obj:isDoor()))
    end)
    return yes
end

-- Can one walk through this door right now? Open or gone; a closed door only
-- when it opens and is not key-locked.
function BridgeDoors.isPassable(door)
    local yes = false
    pcall(function()
        if door:getSquare() == nil or door:getObjectIndex() < 0 or door:isDestroyed() or door:IsOpen() then
            yes = true
            return
        end
        yes = BridgeDoors.canOpen(door) and not door:isLocked() and not door:isLockedByKey()
    end)
    return yes
end

-- May she open this door? Mirrors IsoDoor.couldBeOpen for a character without
-- keys: from inside (one of the door's rooms, or an interior door) any door
-- opens unless "forceLocked"; from outside only key-locked doors stay shut.
function BridgeDoors.canOpen(door, fromSq)
    local yes = false
    pcall(function()
        if door == nil or door:isDestroyed() or door:isBarricaded() or door:isObstructed() then return end
        if instanceof(door, "IsoThumpable") then
            local locked = true
            pcall(function()
                locked = door:isLocked() or door:isLockedByKey() or door:isLockedByPadlock() or door:getLockedByCode() > 0
            end)
            yes = not locked
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
        -- From outside she cannot use a locked door: exclude it so the router
        -- picks a usable opening instead of walking up and failing.
        if door:isLockedByKey() or customLock or door:isLocked() then return end
        yes = true
    end)
    return yes
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

-- A window the router may use: open/climbable, or closed but openable.
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

-- Unique key of an opening (square + edge) for the blacklist.
function BridgeDoors.key(obj)
    local key = "?"
    pcall(function()
        local sq = obj:getSquare()
        if sq == nil then return end
        key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() .. (obj:getNorth() and "N" or "W")
    end)
    return key
end

-- Center of the edge (between the object's square and its opposite).
function BridgeDoors.center(obj)
    local x, y = nil, nil
    pcall(function()
        local sq = obj:getSquare()
        if obj:getNorth() then x, y = sq:getX() + 0.5, sq:getY() else x, y = sq:getX(), sq:getY() + 0.5 end
    end)
    return x, y
end

----------------------------------------------------------------------------
-- Building of a square (roomless interior squares included)
----------------------------------------------------------------------------

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

-- -1 outdoors, the building id inside (roomless squares included).
function BridgeDoors.enclosureKey(sq)
    if sq == nil then return -1 end
    local id = BridgeDoors.buildingId(sq)
    if id == nil then return -1 end
    return id
end

----------------------------------------------------------------------------
-- Standing square in front of an object
----------------------------------------------------------------------------

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

-- Square to stand on to use the object on sq. Never across a wall or window and,
-- for an object inside a building, only a square of the same building.
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

----------------------------------------------------------------------------
-- Exterior openings of a building
----------------------------------------------------------------------------

-- ["<building id>@<floor>"] = { at = ms, list = { { obj, kind, inside, outside, key } } }
local cache = {}

function BridgeDoors.invalidate()
    cache = {}
    graphCache = {}
    pendingGraphs = {}
end

local function exteriorSides(obj, buildingId)
    local inside, outside = nil, nil
    pcall(function()
        local a, b = obj:getSquare(), obj:getOppositeSquare()
        if a == nil or b == nil then return end
        local ia, ib = BridgeDoors.buildingId(a), BridgeDoors.buildingId(b)
        -- The far side counts as "outside" when it is any enclosure other than
        -- this building (open ground, or a neighbouring building's space).
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
    local c = cache[key]
    if c == nil or now - c.at > BridgeDoors.CACHE_MS then
        c = { at = now, list = scanBuilding(building, z) }
        cache[key] = c
    end
    return c.list
end
BridgeDoors.exteriorOpenings = exteriorOpenings

-- Diagnostic: one line listing every exterior opening and why it is/ isn't
-- usable. Logged once when she commits to a route, to explain the choice.
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
            parts[#parts + 1] = string.format("%s:%s@%d,%d", d.kind, why, sx, sy)
        end
    end)
    return table.concat(parts, " | ")
end

-- Best exterior opening for the way (fromX, fromY) -> (toX, toY).
-- leaving = true: she is inside and wants out (near side = inside).
-- avoid: [key] = true for openings that already failed.
-- Hybrid choice: among usable openings whose near side is no more than
-- DETOUR_CAP tiles beyond the nearest usable one, take the shortest total route
-- (dNear + dFar); doors are preferred over windows; nearest is the fallback.
-- Returns { obj, kind, near, far, key, score } or nil.
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
    if #cands == 0 then return nil end
    local nearest = math.huge
    for i = 1, #cands do
        if cands[i].dNear < nearest then nearest = cands[i].dNear end
    end
    local cap = nearest + BridgeDoors.DETOUR_CAP
    local bestDoor, bestDoorScore, bestWin, bestWinScore = nil, nil, nil, nil
    for i = 1, #cands do
        local p = cands[i]
        if p.dNear <= cap then
            local score = p.dNear + p.dFar + (p.extra or 0)
            p.score = score
            if p.kind == "door" and (bestDoorScore == nil or score < bestDoorScore) then
                bestDoor, bestDoorScore = p, score
            elseif p.kind == "window" and (bestWinScore == nil or score < bestWinScore) then
                bestWin, bestWinScore = p, score
            end
        end
    end
    if bestDoor ~= nil then return bestDoor end
    if bestWin ~= nil then return bestWin end
    local pick = cands[1]
    for i = 1, #cands do
        if cands[i].dNear < pick.dNear then pick = cands[i] end
    end
    return pick
end

----------------------------------------------------------------------------
-- Room graph (reachability), built in slices and cached
----------------------------------------------------------------------------

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
            -- A closed window she may open and climb counts as a passage.
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

local function stepGraph(p)
    local now = nowMs()
    if now - sliceMs >= BridgeDoors.GRAPH_SLICE_MS then sliceMs, sliceLeft = now, BridgeDoors.GRAPH_STEP end
    local cell = getCell()
    while sliceLeft > 0 and p.x <= p.x2 do
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
                        if open then link(p.links, a, b) end
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
        p = { links = {}, free = {}, rooms = {}, building = building, z = z,
              x1 = x1, y1 = y1, x2 = x2, y2 = y2, x = x1, y = y1 }
        pendingGraphs[key] = p
    end
    if not stepGraph(p) then return g or UNKNOWN end
    pendingGraphs[key] = nil
    g = { at = now, links = p.links, free = p.free, rooms = p.rooms, reach = {} }
    graphCache[key] = g
    return g
end

-- Drop a graph that may predate a door change (at most every RECHECK_EVERY_MS).
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

local function reachableIn(building, z, fromNode, toNode)
    local g = roomGraph(building, z)
    if g.tooBig then return true end
    if reachSet(g, fromNode)[toNode] == true then return true end
    -- The graph may be out of date (a door opened since it was built): drop it
    -- once and answer "unknown" so the caller never blocks on stale data.
    if recheckGraph(building, z) then return true end
    return false
end

-- Can she get from fromSq to toSq right now? Other floors and open ground count
-- as reachable; nil/unknown/oversized also count as reachable.
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

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeDoors] loaded") end
