if BridgeMeet ~= nil and BridgeMeet.loaded == true then return end

BridgeMeet = BridgeMeet or {}
BridgeMeet.loaded = true

local NEAR_MIN, NEAR_MAX = 25, 40
local FAR_MIN, FAR_MAX = 50, 80
local TALK_RANGE = 12
local MARKER_RANGE = 60
local SIGHT_RANGE = 30
local HELP_RANGE = 15
local LEAVE_FAR = 30
local LEAVE_NEAR = 20
local WANDER_EVERY = 600
local WANDER_MIN, WANDER_MAX, WANDER_RANGE = 2, 3, 5
local SAFEHOUSE_MARGIN = 0
local PLAYER_KEEP_OUT = 20
local VISITED_BLOCK_HOURS = 24
local VISITED_MAX = 200
local ROAD_SCAN = 120

BridgeMeet.testMode = false
BridgeMeet.testZombies = {}
BridgeMeet.installed = false
BridgeMeet.menuHandler = nil
BridgeMeet.allowSpeech = false
BridgeMeet.leftFar = false
BridgeMeet.lastRefused = 0
BridgeMeet.lastForts = 0
BridgeMeet.lastRoadFail = nil
BridgeMeet.lastSceneFail = nil
BridgeMeet.retryAt = 0
BridgeMeet.sally = nil
BridgeMeet.sallyDoor = nil
BridgeMeet.buildingId = nil
BridgeMeet.pendingScene = false
BridgeMeet.poseBody = nil
BridgeMeet.readDone = false
BridgeMeet.wander = true
BridgeMeet.wanderAt = 0
BridgeMeet.visitedAt = 0
BridgeMeet.sightAt = 0
BridgeMeet.forceAt = 0

local SCENES = { "holdout", "scavenger", "driver" }

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeMeet] " .. tostring(text)) end
end

local function vlog(text)
    if Bridge ~= nil and Bridge.verbose then log(text) end
end

local function owner()
    if BridgeData == nil then return nil end
    return BridgeData.owner()
end

local function worldAge()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h or 0
end

local function dist2d(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function buildingKey(def)
    if def == nil then return nil end
    return tostring(def:getX()) .. "," .. tostring(def:getY())
end

local function buildingSquares(def, z, margin, fn)
    if def == nil or type(fn) ~= "function" then return end
    local m = tonumber(margin) or 0
    local x1, y1 = def:getX() - m, def:getY() - m
    local x2, y2 = def:getX2() + m, def:getY2() + m
    local w, h = x2 - x1 + 1, y2 - y1 + 1
    if w <= 0 or h <= 0 then return end
    local step = 1
    if w * h > 2500 then step = 2 end
    local cell = getCell()
    if cell == nil then return end
    for x = x1, x2, step do
        for y = y1, y2, step do
            local sq = cell:getGridSquare(x, y, z)
            if sq ~= nil and fn(sq) == false then return end
        end
    end
end

local function recordVisited()
    local red = owner()
    if red == nil then return end
    local sq = red:getCurrentSquare()
    if sq == nil then return end
    local building = sq:getBuilding()
    if building == nil then return end
    local def = building:getDef()
    local key = buildingKey(def)
    if key == nil or Bridge.store == nil then return end
    local st = Bridge.store
    local mode = tonumber(st.meetMode) or 1
    if st.meetState == nil and mode <= 1 then return end
    if type(st.meetVisited) ~= "table" then st.meetVisited = {} end
    local v = st.meetVisited
    v[key] = worldAge()
    local count, oldestKey, oldest = 0, nil, nil
    for k, t in pairs(v) do
        count = count + 1
        local n = tonumber(t) or 0
        if oldest == nil or n < oldest then oldestKey, oldest = k, n end
    end
    if count > VISITED_MAX and oldestKey ~= nil then v[oldestKey] = nil end
end

local function visitedRecently(def)
    local key = buildingKey(def)
    if key == nil or Bridge.store == nil then return false end
    local v = Bridge.store.meetVisited
    if type(v) ~= "table" then return false end
    local t = tonumber(v[key])
    if t == nil then return false end
    return (worldAge() - t) < VISITED_BLOCK_HOURS
end

local function playerInsideBuilding(def)
    local red = owner()
    if red == nil or def == nil then return false end
    local sq = red:getCurrentSquare()
    if sq == nil then return false end
    local building = sq:getBuilding()
    if building == nil then return false end
    return building:getDef() == def
end

local function isProtectedBuilding(building, z)
    local def = building and building:getDef() or nil
    if def == nil then return true end
    if playerInsideBuilding(def) then return true end
    local red = owner()
    if red ~= nil then
        local x1, y1 = def:getX() - PLAYER_KEEP_OUT, def:getY() - PLAYER_KEEP_OUT
        local x2, y2 = def:getX2() + PLAYER_KEEP_OUT, def:getY2() + PLAYER_KEEP_OUT
        if red:getX() >= x1 and red:getX() <= x2 and red:getY() >= y1 and red:getY() <= y2 then
            return true
        end
    end
    if visitedRecently(def) then return true end
    local protected = false
    if SafeHouse ~= nil and SafeHouse.isSafeHouse ~= nil then
        buildingSquares(def, z, SAFEHOUSE_MARGIN, function(sq)
            local yes = false
            pcall(function() yes = SafeHouse.isSafeHouse(sq, nil, true) == true end)
            if yes then protected = true return false end
            return true
        end)
        if protected then return true end
    end
    buildingSquares(def, z, 0, function(sq)
        local built = false
        pcall(function()
            local objects = sq:getObjects()
            for i = 0, objects:size() - 1 do
                local object = objects:get(i)
                if object ~= nil and instanceof(object, "IsoThumpable") and object:isDismantable() == true then
                    built = true
                    break
                end
            end
        end)
        if built then protected = true return false end
        return true
    end)
    return protected
end

local function cleanMode(value)
    local n = tonumber(value)
    if n == nil then return 1 end
    n = math.floor(n)
    return clamp(n, 1, 3)
end

local function cleanDays(value)
    local n = tonumber(value)
    if n == nil then return 1 end
    n = math.floor(n)
    if n < 1 then return 1 end
    return n
end

local function cleanHint(value)
    local n = tonumber(value)
    if n == nil then return 1 end
    n = math.floor(n)
    return clamp(n, 0, 1)
end

local function modeOf(st)
    return cleanMode(st and st.meetMode)
end

local function daysOf(st)
    return cleanDays(st and st.meetDays)
end

local function hintOf(st)
    return cleanHint(st and st.meetHint)
end

local function effectiveDays(st)
    if modeOf(st) == 3 then return daysOf(st) end
    return 0
end

local function stateOf(st)
    return st and st.meetState or nil
end

function BridgeMeet.unjoined()
    local state = stateOf(Bridge.store)
    return state ~= nil and state ~= "joined"
end

local function hasSpot(st)
    return st ~= nil and tonumber(st.meetX) ~= nil and tonumber(st.meetY) ~= nil and tonumber(st.meetZ) ~= nil
end

local function spotOf(st)
    if not hasSpot(st) then return nil end
    return tonumber(st.meetX), tonumber(st.meetY), tonumber(st.meetZ)
end

local function bodyAlive()
    return Bridge ~= nil and Bridge.kind == "zombie" and Bridge.alive() == true
end

function BridgeMeet.selfDefense()
    local state = stateOf(Bridge.store)
    if state ~= "placed" and state ~= "left" then return false end
    return bodyAlive()
end

function BridgeMeet.quietCombat()
    return BridgeMeet.selfDefense()
end

local function bodyPos()
    if not bodyAlive() then return nil end
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = Bridge.body:getX(), Bridge.body:getY(), Bridge.body:getZ() end)
    if x == nil then return nil end
    return x, y, z
end

local function spotDist(st)
    local red = owner()
    local x, y = spotOf(st)
    if red == nil or x == nil then return -1 end
    return dist2d(red:getX(), red:getY(), x, y)
end

local function bodySpotDist(st)
    local bx, by = bodyPos()
    local x, y = spotOf(st)
    if bx == nil or x == nil then return -1 end
    return dist2d(bx, by, x, y)
end

local function dir8(dx, dy)
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then return "here" end
    local ax, ay = math.abs(dx), math.abs(dy)
    if ay > ax * 2.414 then return dy > 0 and "S" or "N" end
    if ax > ay * 2.414 then return dx > 0 and "E" or "W" end
    if dx > 0 then return dy > 0 and "SE" or "NE" end
    return dy > 0 and "SW" or "NW"
end

local function fmtSpot(x, y, z)
    if x == nil then return "none" end
    return string.format("%d,%d,%d", math.floor(x), math.floor(y), math.floor(z))
end

local function randomScene()
    return SCENES[ZombRand(1, #SCENES + 1)]
end

local function sceneOk(name)
    for _, s in ipairs(SCENES) do
        if s == name then return true end
    end
    return false
end

local function clearRuntime()
    Bridge.leaveAt = nil
    Bridge.leaveTries = nil
    Bridge.respawnAt = nil
    Bridge.homeParked = false
    Bridge.target = nil
    BridgeMeet.leftFar = false
end

local function setWait(st, x, y, z)
    if st == nil then return end
    st.waitX, st.waitY, st.waitZ = x, y, z
end

local function reply(seq, text)
    if Bridge ~= nil then Bridge.result = text end
    local path = Bridge ~= nil and Bridge.outFile or nil
    if path ~= nil then
        pcall(function()
            local writer = getFileWriter(path, true, true)
            if writer ~= nil then
                writer:write("meet " .. tostring(seq) .. ": " .. tostring(text) .. "\r\n")
                writer:close()
            end
        end)
    end
    return text
end

local function writeState(text)
    if Bridge ~= nil then Bridge.result = text end
    return text
end

local function isTagged(board)
    local yes = false
    if board == nil then return false end
    pcall(function() yes = board:getModData().BridgeMeetFort == 1 end)
    return yes
end

local function addOppositeFor(entry)
    if entry == nil or entry.obj == nil or entry.outside == nil then return false end
    local same = false
    pcall(function() same = entry.obj:getSquare() == entry.outside end)
    return same
end

local function fallbackFor(flags)
    flags = flags or {}
    if flags.noBuilding then return "no_building" end
    if flags.noDoor then return "no_door" end
    if flags.noApi then return "no_barricade_api" end
    if flags.noBoards then return "no_barricade" end
    if flags.allBarred then return "all_doors_barred" end
    return "none"
end

local function isGarageDoor(obj)
    local garage = false
    pcall(function()
        local sprite = obj:getSprite()
        local name = sprite and sprite:getName() or ""
        name = string.lower(tostring(name))
        garage = string.find(name, "garage", 1, true) ~= nil
    end)
    return garage
end

local function doorLocked(obj)
    local locked = false
    pcall(function() locked = obj:isLocked() == true or obj:isLockedByKey() == true end)
    return locked
end

local function doorBarricaded(obj)
    local yes = false
    pcall(function() yes = obj:isBarricaded() == true end)
    return yes
end

local function doorDistance(obj, x, y)
    local d = 999
    pcall(function()
        local sq = obj:getSquare()
        if sq ~= nil then d = dist2d(sq:getX() + 0.5, sq:getY() + 0.5, x, y) end
    end)
    return d
end

local function doorScore(door, x, y)
    local score = 0
    if not door.barricaded then score = score + 100 end
    if not door.locked then score = score + 50 end
    if not door.garage then score = score + 20 end
    if door.tagged then score = score + 10 end
    score = score - (door.dist or 0)
    return score
end

local function rankDoors(list, x, y)
    local best = nil
    for _, door in ipairs(list or {}) do
        if door.dist == nil then door.dist = doorDistance(door.obj, x or 0, y or 0) end
        door.score = doorScore(door, x or 0, y or 0)
        if best == nil or door.score > best.score then best = door end
    end
    return best
end

local function isTwinLeaf(a, b)
    if a == nil or b == nil or a.obj == b.obj then return false end
    local sameRoom = false
    pcall(function()
        local ra = a.inside and a.inside:getRoom() or nil
        local rb = b.inside and b.inside:getRoom() or nil
        if ra ~= nil or rb ~= nil then sameRoom = ra == rb end
    end)
    local near = false
    pcall(function()
        near = math.abs(a.outside:getX() - b.outside:getX()) <= 1
            and math.abs(a.outside:getY() - b.outside:getY()) <= 1
            and a.outside:getZ() == b.outside:getZ()
    end)
    return sameRoom and near
end

local function clearDoorBoards(door)
    if door == nil or door.obj == nil then return 0 end
    local removed = 0
    local board = nil
    pcall(function() board = door.obj:getBarricadeOnSameSquare() end)
    if board == nil then pcall(function() board = door.obj:getBarricadeOnOppositeSquare() end) end
    if board == nil then return 0 end
    if not isTagged(board) then return 0 end
    local planks = 0
    pcall(function() planks = board:getNumPlanks() end)
    for _ = 1, planks do
        pcall(function() board:removePlank(nil) end)
    end
    local sq = nil
    pcall(function() sq = board:getSquare() or door.obj:getSquare() end)
    if sq ~= nil then pcall(function() sq:transmitRemoveItemFromSquare(board) end) end
    pcall(function()
        local still = door.obj:isBarricaded() == true
        if not still then removed = 1 end
    end)
    return removed
end

local function boardOpening(entry, red)
    local obj = entry and entry.obj or nil
    if obj == nil then return false, 0 end
    if doorBarricaded(obj) then return false, 0 end
    local isFrame = false
    pcall(function() isFrame = instanceof(obj, "IsoWindowFrame") end)
    if isFrame then
        local has = false
        pcall(function() has = obj:hasWindow() == true end)
        if has then return false, 0 end
        local allowed = false
        pcall(function() allowed = obj:isBarricadeAllowed() == true end)
        if not allowed then return false, 0 end
    end
    local isDoor = false
    pcall(function() isDoor = instanceof(obj, "IsoDoor") end)
    if isDoor then
        pcall(function()
            if obj:IsOpen() then
                obj:ToggleDoorSilent()
                obj:syncIsoObject(false, 0, nil, nil)
            end
        end)
        local open = false
        pcall(function() open = obj:IsOpen() == true end)
        if open then return false, 0 end
    end
    local addOpposite = addOppositeFor(entry)
    local ok, board = pcall(IsoBarricade.AddBarricadeToObject, obj, addOpposite)
    if not ok or board == nil then
        ok, board = pcall(IsoBarricade.AddBarricadeToObject, obj, red)
    end
    if not ok or board == nil then return false, 0 end
    local planks = 2 + ZombRand(0, 3)
    local added = 0
    for _ = 1, planks do
        local made = pcall(function() board:addPlank(nil, nil) end)
        if made then added = added + 1 end
    end
    if added == 0 then
        local sq = nil
        pcall(function() sq = board:getSquare() or obj:getSquare() end)
        if sq ~= nil then pcall(function() sq:transmitRemoveItemFromSquare(board) end) end
        return false, 0
    end
    pcall(function()
        local md = board:getModData()
        md.BridgeMeetFort = 1
        md.BridgeMeetFortScene = "holdout"
        md.BridgeMeetFortAt = worldAge()
    end)
    pcall(function() board:transmitCompleteItemToClients() end)
    return true, added
end

local function countZombies(x, y, z, radius)
    local n = 0
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local zombie = list:get(i)
            if zombie ~= nil and math.abs(zombie:getZ() - z) < 1
                and dist2d(zombie:getX(), zombie:getY(), x, y) <= radius then
                n = n + 1
            end
        end
    end)
    return n
end

local function spawnTestZombie(x, y, z)
    local created = nil
    pcall(function()
        local list = addZombiesInOutfit(x, y, z, 1, "Naked", 0, false, false, false, false, false, false, 1)
        if list ~= nil and list:size() > 0 then created = list:get(0) end
    end)
    if created ~= nil then BridgeMeet.testZombies[#BridgeMeet.testZombies + 1] = created end
    return created
end

local function findInteriorSquare(building, cx, cy, cz, wantContainer)
    local best, bestD = nil, nil
    local bestContainer = nil
    pcall(function()
        local id = building:getID()
        local cell = getCell()
        for r = 0, 8 do
            for dx = -r, r do
                for dy = -r, r do
                    if math.max(math.abs(dx), math.abs(dy)) == r then
                        local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
                        local b = nil
                        if sq ~= nil then pcall(function() b = BridgeDoors.buildingOf(sq) end) end
                        if sq ~= nil and b ~= nil and b:getID() == id then
                            local stand = false
                            pcall(function() stand = sq:canStand() == true end)
                            if stand then
                                local hasContainer = false
                                pcall(function()
                                    local objs = sq:getObjects()
                                    for i = 0, objs:size() - 1 do
                                        local o = objs:get(i)
                                        if o ~= nil then
                                            local c = nil
                                            pcall(function() c = o:getContainer() end)
                                            if c ~= nil then hasContainer = true break end
                                        end
                                    end
                                end)
                                local d = dist2d(sq:getX() + 0.5, sq:getY() + 0.5, cx, cy)
                                if wantContainer then
                                    if hasContainer and (best == nil or d < bestD) then
                                        best, bestD = sq, d
                                        bestContainer = true
                                    end
                                else
                                    if best == nil or d < bestD then best, bestD = sq, d end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    if best == nil and wantContainer then
        return findInteriorSquare(building, cx, cy, cz, false), bestContainer
    end
    return best, bestContainer
end

local function chairOnSquare(sq)
    local chair = nil
    pcall(function()
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            if o ~= nil then
                local isChair = false
                pcall(function()
                    local props = o:getProperties()
                    isChair = props ~= nil and props:has("IsChair") == true
                end)
                if isChair then chair = o break end
            end
        end
    end)
    return chair
end

local function placeCornered(tx, ty, z)
    local sx, sy, sz = Bridge.spawnSpot(tx, ty, z, false)
    if sx == nil then sx, sy, sz = math.floor(tx), math.floor(ty), math.floor(z) end
    local n = countZombies(sx, sy, sz, 8)
    if n == 0 and not Bridge.mp then
        local want = 1 + ZombRand(0, 2)
        local offsets = { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 }, { 3, 1 }, { -3, -1 } }
        for i = 1, want do
            local o = offsets[((i - 1) % #offsets) + 1]
            local zx, zy = sx + o[1], sy + o[2]
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(zx, zy, sz) end)
            if sq ~= nil then
                local free = false
                pcall(function() free = sq:isFree(false) == true end)
                if free then spawnTestZombie(zx + 0.5, zy + 0.5, sz) end
            end
        end
        n = countZombies(sx, sy, sz, 8)
    end
    return {
        scene = "cornered",
        x = sx, y = sy, z = sz,
        props = "zombies:" .. tostring(n),
        fallback = "none",
        pose = nil,
    }
end

local function placeScavenger(tx, ty, z)
    local cell = getCell()
    local sq = nil
    pcall(function() sq = cell:getGridSquare(tx, ty, z) end)
    local building = nil
    pcall(function() building = sq and BridgeDoors.buildingOf(sq) or nil end)
    local spot = nil
    local container = false
    if building ~= nil then
        spot, container = findInteriorSquare(building, tx, ty, z, true)
    end
    if spot == nil then
        local sx, sy, sz = Bridge.spawnSpot(tx, ty, z, false)
        if sx ~= nil then
            spot = cell:getGridSquare(sx, sy, sz)
        end
    end
    if spot == nil then
        local sx, sy, sz = math.floor(tx), math.floor(ty), math.floor(z)
        spot = cell:getGridSquare(sx, sy, sz)
    end
    if spot == nil then
        return {
            scene = "scavenger",
            x = math.floor(tx), y = math.floor(ty), z = math.floor(z),
            props = "container:0/loot:0",
            fallback = "no_building",
            pose = "LootLow",
        }
    end
    local props = "container:" .. (container and "1" or "0") .. "/loot:0"
    return {
        scene = "scavenger",
        x = spot:getX(), y = spot:getY(), z = spot:getZ(),
        props = props,
        fallback = "none",
        pose = "LootLow",
    }
end

local function vehiclesArray()
    local out = {}
    pcall(function()
        local set = getCell():getVehicles()
        if set == nil then return end
        local ok, arr = pcall(function() return set:toArray() end)
        if ok and arr ~= nil then
            for i = 1, #arr do out[#out + 1] = arr[i] end
            return
        end
        local it = set:iterator()
        while it:hasNext() do out[#out + 1] = it:next() end
    end)
    return out
end

local function spriteIsStreet(sprite)
    if sprite == nil then return false end
    local name = nil
    pcall(function() name = sprite:getName() end)
    if name == nil then return false end
    local lower = string.lower(name)
    return string.find(lower, "street", 1, true) ~= nil
        or string.find(lower, "road", 1, true) ~= nil
        or string.find(lower, "tarmac", 1, true) ~= nil
        or string.find(lower, "asphalt", 1, true) ~= nil
        or string.find(lower, "pavement", 1, true) ~= nil
end

local function isStreetSquare(sq)
    if sq == nil then return false end
    local street = false
    pcall(function()
        local floor = sq:getFloor()
        if floor ~= nil then
            street = spriteIsStreet(floor:getSprite())
            return
        end
        local objects = sq:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if object ~= nil and spriteIsStreet(object:getSprite()) then
                street = true
                return
            end
        end
    end)
    return street
end

local function streetOrientation(x, y, z)
    local cell = getCell()
    if cell == nil then return "X" end
    local xcount, ycount = 0, 0
    for i = -8, 8 do
        if isStreetSquare(cell:getGridSquare(x + i, y, z)) then xcount = xcount + 1 end
        if isStreetSquare(cell:getGridSquare(x, y + i, z)) then ycount = ycount + 1 end
    end
    if xcount >= ycount then return "X" end
    return "Y"
end

local function freeSquare(x, y, z)
    local sq = nil
    pcall(function() sq = getCell():getGridSquare(x, y, z) end)
    if sq == nil then return nil end
    local free = false
    local blocked = false
    pcall(function() free = sq:isFree(false) == true end)
    pcall(function() blocked = sq:isVehicleIntersecting() == true end)
    if free and not blocked then return sq end
    return nil
end

local function freeBeside(x, y, z)
    local offsets = {
        { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
        { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 },
        { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 },
        { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 },
    }
    for _, o in ipairs(offsets) do
        local sq = freeSquare(x + o[1], y + o[2], z)
        if sq ~= nil then return sq end
    end
    return nil
end

local function spawnRoadCar(x, y, z, orientation)
    local scriptName = nil
    pcall(function() scriptName = getScriptManager():getRandomVehicleScript():getName() end)
    if scriptName == nil then return nil end
    local vehicle = nil
    pcall(function() vehicle = addVehicle(scriptName, x, y, z) end)
    if vehicle == nil then
        local sq = nil
        pcall(function() sq = getCell():getGridSquare(x, y, z) end)
        if sq ~= nil and IsoDirections ~= nil then
            pcall(function() vehicle = addVehicleDebug(scriptName, IsoDirections.S, nil, sq) end)
        end
    end
    if vehicle == nil then return nil end
    pcall(function()
        local angle = 0
        if orientation == "X" then
            angle = ZombRand(2) == 0 and 90 or -90
        else
            angle = ZombRand(2) == 0 and 180 or 0
        end
        vehicle:setAngles(0, angle, 0)
    end)
    return vehicle
end

local function findRoadSpawn(tx, ty, z)
    local cell = getCell()
    if cell == nil then return nil end
    local zz = math.floor(z)
    for r = 0, ROAD_SCAN do
        local step = 1
        if r >= 64 then step = 8
        elseif r >= 16 then step = 4
        elseif r >= 4 then step = 2 end
        for dx = -r, r, step do
            for dy = -r, r, step do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local x, y = tx + dx, ty + dy
                    local sq = cell:getGridSquare(x, y, zz)
                    if isStreetSquare(sq) and freeSquare(x, y, zz) ~= nil then
                        return x, y, zz, streetOrientation(x, y, zz)
                    end
                end
            end
        end
    end
    return nil
end

local function fallbackCarSquare(tx, ty, z)
    local sq = freeSquare(tx, ty, z)
    if sq ~= nil then return sq end
    sq = freeBeside(tx, ty, z)
    if sq ~= nil then return sq end
    local red = owner()
    if red ~= nil then
        local px, py, pz = math.floor(red:getX()), math.floor(red:getY()), math.floor(red:getZ())
        sq = freeSquare(px, py, pz)
        if sq ~= nil then return sq end
        sq = freeBeside(px, py, pz)
        if sq ~= nil then return sq end
    end
    return nil
end

local function driverResultForCar(car)
    if car == nil then return nil end
    local cx, cy, cz = car:getX(), car:getY(), car:getZ()
    local sx, sy, sz = Bridge.spawnSpot(cx, cy, cz, false)
    if sx == nil then
        local sq = freeBeside(math.floor(cx), math.floor(cy), math.floor(cz))
        if sq ~= nil then sx, sy, sz = sq:getX(), sq:getY(), sq:getZ() end
    end
    if sx == nil then return nil end
    local onRoad = false
    pcall(function() onRoad = isStreetSquare(car:getSquare()) end)
    return {
        scene = "driver",
        x = sx, y = sy, z = sz,
        props = string.format("car:%d,%d/road:%d", math.floor(cx), math.floor(cy), onRoad and 1 or 0),
        fallback = "none",
        pose = nil,
    }
end

local function placeDriver(tx, ty, z)
    local car = nil
    local best = nil
    local nearestCar = nil
    local nearestD = nil
    for _, v in ipairs(vehiclesArray()) do
        if v ~= nil then
            local d = dist2d(v:getX(), v:getY(), tx, ty)
            if nearestD == nil or d < nearestD then nearestCar, nearestD = v, d end
            if d <= 10 and (best == nil or d < best) then
                car, best = v, d
            end
        end
    end
    if car == nil then
        local rx, ry, rz, orientation = findRoadSpawn(tx, ty, z)
        local onRoad = rx ~= nil
        if not onRoad then
            local existing = driverResultForCar(nearestCar)
            if existing ~= nil then return existing end
            local sq = fallbackCarSquare(tx, ty, z)
            if sq ~= nil then
                rx, ry, rz = sq:getX(), sq:getY(), sq:getZ()
                orientation = "X"
            end
        end
        if rx ~= nil then
            local vehicle = spawnRoadCar(rx, ry, rz, orientation)
            local spot = freeBeside(rx, ry, rz)
            if vehicle ~= nil and spot ~= nil then
                return {
                    scene = "driver",
                    x = spot:getX(), y = spot:getY(), z = spot:getZ(),
                    props = string.format("car:%d,%d/road:%d", math.floor(rx), math.floor(ry), onRoad and 1 or 0),
                    fallback = "none",
                    pose = nil,
                }
            end
        end
        local sx, sy, sz = tx, ty, z
        local sq = fallbackCarSquare(tx, ty, z)
        if sq ~= nil then sx, sy, sz = sq:getX(), sq:getY(), sq:getZ() end
        local result = placeScavenger(sx, sy, sz)
        result.fallback = "no_car"
        return result
    end
    local cx, cy, cz = car:getX(), car:getY(), car:getZ()
    local sx, sy, sz = Bridge.spawnSpot(cx, cy, cz, false)
    if sx == nil then sx, sy, sz = math.floor(cx), math.floor(cy), math.floor(cz) end
    return {
        scene = "driver",
        x = sx, y = sy, z = sz,
        props = string.format("car:%d,%d", math.floor(cx), math.floor(cy)),
        fallback = "none",
        pose = nil,
    }
end

local function scanBuildingNear(x, y, z, radius)
    local building = nil
    pcall(function()
        local cell = getCell()
        local base = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
        if base ~= nil then building = BridgeDoors.buildingOf(base) end
        if building ~= nil then return end
        for dx = -radius, radius do
            for dy = -radius, radius do
                local sq = cell:getGridSquare(math.floor(x) + dx, math.floor(y) + dy, math.floor(z))
                if sq ~= nil then
                    local b = BridgeDoors.buildingOf(sq)
                    if b ~= nil then building = b return end
                end
            end
        end
    end)
    return building
end

local function scanBuildingWide(x, y, z, maxRadius, accept)
    local building = nil
    pcall(function()
        local cell = getCell()
        local zz = math.floor(z)
        local cx, cy = math.floor(x), math.floor(y)
        local function check(gx, gy)
            if building ~= nil then return end
            local sq = cell:getGridSquare(gx, gy, zz)
            if sq == nil then return end
            local b = BridgeDoors.buildingOf(sq)
            if b ~= nil and (accept == nil or accept(b) == true) then building = b end
        end
        check(cx, cy)
        for r = 1, maxRadius do
            if building ~= nil then return end
            local step = 1
            if r >= 512 then step = 32
            elseif r >= 256 then step = 16
            elseif r >= 64 then step = 8
            elseif r >= 16 then step = 4
            elseif r >= 4 then step = 2 end
            local x0, x1 = cx - r, cx + r
            local y0, y1 = cy - r, cy + r
            for gx = x0, x1, step do
                check(gx, y0)
                check(gx, y1)
            end
            for gy = y0 + step, y1 - step, step do
                check(x0, gy)
                check(x1, gy)
            end
        end
    end)
    return building
end

local PROBE_RADII = { 6, 13, 20, 27, 34, 41, 48, 64, 80, 96, 128, 160, 200, 256 }
local PROBE_ANGLES = 12

local function probeBuildings(cx, cy, z)
    local cell = getCell()
    if cell == nil then return {} end
    local seen, list = {}, {}
    for _, radius in ipairs(PROBE_RADII) do
        for i = 0, PROBE_ANGLES - 1 do
            local angle = i * 2 * math.pi / PROBE_ANGLES
            local x = math.floor(cx + math.cos(angle) * radius)
            local y = math.floor(cy + math.sin(angle) * radius)
            local sq = cell:getGridSquare(x, y, math.floor(z))
            if sq ~= nil then
                local b = BridgeDoors.buildingOf(sq)
                if b ~= nil then
                    local def = b:getDef()
                    local key = def ~= nil and buildingKey(def) or nil
                    if key ~= nil and not seen[key] then
                        seen[key] = true
                        local mx = (def:getX() + def:getX2()) / 2
                        local my = (def:getY() + def:getY2()) / 2
                        list[#list + 1] = { building = b, dist = dist2d(cx, cy, mx, my) }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

local function placeHoldout(tx, ty, z)
    local red = owner()
    local function accept(building)
        return not isProtectedBuilding(building, math.floor(z))
    end
    local building = scanBuildingNear(tx, ty, z, 8)
    if building ~= nil and not accept(building) then building = nil end
    if building == nil then
        local town = Bridge.store ~= nil and Bridge.store.meetTown or "near"
        local candidates = probeBuildings(tx, ty, z)
        if #candidates == 0 and town == "near" and red ~= nil then
            candidates = probeBuildings(red:getX(), red:getY(), z)
        end
        local valid = {}
        local checked = 0
        for _, candidate in ipairs(candidates) do
            checked = checked + 1
            if checked > 12 then break end
            if accept(candidate.building) then
                valid[#valid + 1] = candidate.building
                if #valid >= 6 then break end
            end
        end
        if #valid > 0 then building = valid[ZombRand(1, #valid + 1)] end
    end
    if building == nil then
        return placeScavenger(tx, ty, z)
    end
    local openings = {}
    pcall(function() openings = BridgeDoors.exteriorOpenings(building, math.floor(z)) end)
    local doors = {}
    for _, entry in ipairs(openings or {}) do
        if entry.kind == "door" then
            doors[#doors + 1] = {
                obj = entry.obj,
                entry = entry,
                inside = entry.inside,
                outside = entry.outside,
                barricaded = doorBarricaded(entry.obj),
                locked = doorLocked(entry.obj),
                garage = isGarageDoor(entry.obj),
                tagged = false,
                dist = doorDistance(entry.obj, tx, ty),
            }
        end
    end
    if #doors == 0 then
        local result = placeScavenger(tx, ty, z)
        result.fallback = "no_door"
        return result
    end
    local sally = rankDoors(doors, tx, ty)
    local allBarred = true
    for _, door in ipairs(doors) do
        if not door.barricaded then allBarred = false end
    end
    if allBarred then
        local taggedDoor = nil
        for _, door in ipairs(doors) do
            local board = nil
            pcall(function() board = door.obj:getBarricadeOnSameSquare() end)
            if board == nil then pcall(function() board = door.obj:getBarricadeOnOppositeSquare() end) end
            if isTagged(board) then door.tagged = true end
            if door.tagged and taggedDoor == nil then taggedDoor = door end
        end
        if taggedDoor == nil then
            local result = placeScavenger(tx, ty, z)
            result.fallback = "all_doors_barred"
            return result
        end
        sally = taggedDoor
        clearDoorBoards(sally)
        local twinBarred = nil
        for _, door in ipairs(doors) do
            if door ~= sally and isTwinLeaf(sally, door) then twinBarred = door break end
        end
        if twinBarred ~= nil then clearDoorBoards(twinBarred) end
        sally.barricaded = doorBarricaded(sally.obj)
        if sally.barricaded then
            local result = placeScavenger(tx, ty, z)
            result.fallback = "all_doors_barred"
            return result
        end
    end
    if sally == nil then
        local result = placeScavenger(tx, ty, z)
        result.fallback = "no_door"
        return result
    end
    pcall(function() sally.obj:setLocked(false) end)
    pcall(function() sally.obj:setLockedByKey(false) end)
    pcall(function()
        if sally.obj:IsOpen() then
            sally.obj:ToggleDoorSilent()
            sally.obj:syncIsoObject(false, 0, nil, nil)
        end
    end)
    local twin = nil
    for _, door in ipairs(doors) do
        if door ~= sally and isTwinLeaf(sally, door) then twin = door break end
    end
    local survivorSq = nil
    if sally.inside ~= nil then
        survivorSq = findInteriorSquare(building, sally.inside:getX(), sally.inside:getY(), sally.inside:getZ(), false)
    end
    if survivorSq == nil then
        survivorSq = sally.inside
    end
    if survivorSq == nil then
        local result = placeScavenger(tx, ty, z)
        result.fallback = "no_building"
        return result
    end
    if IsoBarricade == nil or type(IsoBarricade.AddBarricadeToObject) ~= "function" then
        local result = placeScavenger(tx, ty, z)
        result.fallback = "no_barricade_api"
        return result
    end
    local forts, refused, preexisting, others = 0, 0, 0, 0
    for _, entry in ipairs(openings or {}) do
        local skip = entry.obj == sally.obj or (twin ~= nil and entry.obj == twin.obj)
        if not skip then
            others = others + 1
            if doorBarricaded(entry.obj) then
                preexisting = preexisting + 1
            else
                local ok = boardOpening(entry, red)
                if ok then
                    forts = forts + 1
                else
                    refused = refused + 1
                end
            end
        end
    end
    BridgeMeet.lastForts = forts
    BridgeMeet.lastRefused = refused
    if forts == 0 and preexisting == 0 and others > 0 then
        local result = placeScavenger(tx, ty, z)
        result.fallback = "no_barricade"
        return result
    end
    BridgeMeet.sally = { x = sally.inside:getX(), y = sally.inside:getY() }
    BridgeMeet.sallyDoor = sally.obj
    BridgeMeet.buildingId = building:getID()
    local barricaded = 0
    for _, entry in ipairs(openings or {}) do
        if doorBarricaded(entry.obj) then barricaded = barricaded + 1 end
    end
    local props = string.format("openings:%d/barricaded:%d/open:1/door:%d,%d",
        #openings, barricaded, sally.inside:getX(), sally.inside:getY())
    return {
        scene = "holdout",
        x = survivorSq:getX(), y = survivorSq:getY(), z = survivorSq:getZ(),
        props = props,
        fallback = "none",
        pose = nil,
    }
end

local function placeScene(scene, tx, ty, z)
    BridgeMeet.lastForts = 0
    BridgeMeet.lastRefused = 0
    BridgeMeet.sally = nil
    BridgeMeet.sallyDoor = nil
    BridgeMeet.buildingId = nil
    local name = sceneOk(scene) and scene or "scavenger"
    if name == "holdout" then return placeHoldout(tx, ty, z) end
    if name == "scavenger" then return placeScavenger(tx, ty, z) end
    if name == "driver" then return placeDriver(tx, ty, z) end
    return placeScavenger(tx, ty, z)
end

local function applyResult(st, result)
    st.meetScene = result.scene
    st.meetX, st.meetY, st.meetZ = result.x, result.y, result.z
    st.meetPose = result.pose
    st.meetState = "placed"
    st.meetAt = 0
    st.want = true
    Bridge.setMode("wait")
    setWait(st, result.x, result.y, result.z)
    BridgeMeet.poseBody = nil
    BridgeMeet.pendingScene = false
end

local function applyPose(st)
    if st.meetPose == nil or not bodyAlive() then return end
    if BridgeMeet.poseBody == Bridge.body then return end
    BridgeMeet.poseBody = Bridge.body
    if st.meetPose == "SitChair" then
        st.meetPose = nil
        return
    end
    pcall(function() Bridge.setPose(st.meetPose) end)
end

local function distanceBand(st)
    local d = st.meetDistance
    if d == "far" then return 50, 80 end
    if d == "very_far" then return 100, 160 end
    return NEAR_MIN, NEAR_MAX
end

local function findTownBox(id)
    local boxes = BridgeCallout ~= nil and BridgeCallout.CITY_BOXES or nil
    if type(boxes) ~= "table" or #boxes == 0 then return nil end
    if id == "random" then return boxes[ZombRand(1, #boxes + 1)] end
    for _, box in ipairs(boxes) do
        if box.id == id then return box end
    end
    return nil
end

local function townPoint(box)
    local cx = (box.minX + box.maxX) / 2
    local cy = (box.minY + box.maxY) / 2
    local radius = 128
    local x = clamp(cx + ZombRand(0, radius * 2 + 1) - radius, box.minX, box.maxX)
    local y = clamp(cy + ZombRand(0, radius * 2 + 1) - radius, box.minY, box.maxY)
    return math.floor(x), math.floor(y)
end

local function armSpot(st)
    local red = owner()
    if red == nil then return nil end
    local z = math.floor(red:getZ())
    local mode = modeOf(st)
    local min, max = distanceBand(st)
    local tx, ty = nil, nil
    local town = st.meetTown
    if town ~= nil and town ~= "near" then
        local box = findTownBox(town)
        if box ~= nil then
            tx, ty = townPoint(box)
            z = 0
        end
    end
    if tx == nil then
        local angle = ZombRandFloat(0, math.pi * 2)
        local radius = ZombRandFloat(min, max)
        tx = math.floor(red:getX() + math.cos(angle) * radius)
        ty = math.floor(red:getY() + math.sin(angle) * radius)
    end
    local loaded = false
    pcall(function() loaded = getCell():getGridSquare(tx, ty, z) ~= nil end)
    local scene = randomScene()
    st.meetScene = scene
    st.meetTargetX, st.meetTargetY, st.meetTargetZ = tx, ty, z
    if not loaded then
        st.meetX, st.meetY, st.meetZ = tx, ty, z
        st.meetPose = nil
        st.meetState = "placed"
        st.meetAt = 0
        st.want = true
        Bridge.setMode("wait")
        setWait(st, tx, ty, z)
        BridgeMeet.pendingScene = true
        BridgeMeet.poseBody = nil
        log(string.format("arm scene=%s target=%d,%d,%d unloaded, resolves on approach", scene, tx, ty, z))
        return true
    end
    local result = placeScene(scene, tx, ty, z)
    if result == nil then
        st.meetState = "pending"
        st.want = false
        st.meetRetryScene = scene
        st.meetRetryTX, st.meetRetryTY, st.meetRetryTZ = tx, ty, z
        log(string.format("arm scene=%s retry reason=%s", scene, tostring(BridgeMeet.lastSceneFail or BridgeMeet.lastRoadFail or "no_scene")))
        return false
    end
    applyResult(st, result)
    log(string.format("arm scene=%s spot=%s fallback=%s", result.scene, fmtSpot(result.x, result.y, result.z), result.fallback))
    return true
end

local function armTick(st)
    if st.meetRetryScene ~= nil then return end
    local red = owner()
    if red == nil then return end
    local mode = modeOf(st)
    if mode == 3 and tonumber(st.meetAt) == nil then
        st.meetAt = worldAge() + daysOf(st) * 24
        return
    end
    if worldAge() < (tonumber(st.meetAt) or 0) then return end
    local asleep, inCar, hasSquare = false, false, false
    pcall(function()
        asleep = red:isAsleep() == true
        inCar = red:getVehicle() ~= nil
        hasSquare = red:getCurrentSquare() ~= nil
    end)
    if asleep or inCar or not hasSquare then return end
    if mode == 1 then return end
    if mode == 2 then
        armSpot(st)
        return
    end
    armSpot(st)
end

local function resolveTarget(st)
    if not BridgeMeet.pendingScene then return end
    local x, y, z = spotOf(st)
    local red = owner()
    if x == nil or red == nil then return end
    local loaded = false
    pcall(function() loaded = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z)) ~= nil end)
    if not loaded then return end
    if dist2d(red:getX(), red:getY(), x, y) > 55 then return end
    local result = placeScene(st.meetScene, x, y, z)
    applyResult(st, result)
    log(string.format("resolved scene=%s spot=%s fallback=%s", result.scene, fmtSpot(result.x, result.y, result.z), result.fallback))
end

local function leftTick(st)
    if stateOf(st) ~= "left" then return end
    local red = owner()
    if red == nil then return end
    local d = spotDist(st)
    if d < 0 then return end
    if d > LEAVE_FAR then BridgeMeet.leftFar = true end
    if BridgeMeet.leftFar and d <= LEAVE_NEAR then
        BridgeMeet.leftFar = false
        Bridge.leaveAt, Bridge.leaveTries = nil, nil
        st.meetState = "placed"
        st.want = true
        Bridge.setMode("wait")
        setWait(st, st.meetX, st.meetY, st.meetZ)
        log("found again: waiting to be asked")
    end
end

local sayMeet

local function firstSightingSpeech()
    local fighting = false
    pcall(function()
        fighting = (BridgeFight ~= nil and (BridgeFight.target ~= nil or BridgeFight.state == "swing"))
            or (BridgeGunfight ~= nil and (BridgeGunfight.target ~= nil or BridgeGunfight.state == "swing"))
            or Bridge.target ~= nil
    end)
    if fighting then
        local n = ZombRand(1, 4)
        local lines = {
            "A little help here!",
            "They're on me! Help!",
            "Don't just stand there, help me!",
        }
        sayMeet("MeetHelp" .. tostring(n), lines[n])
        return
    end
    local n = ZombRand(1, 5)
    local lines = {
        "Don't come closer. Are you infected?",
        "Stay back. Have you been bitten?",
        "That you? Are you sick? Infected?",
        "Keep your distance. Are you one of them?",
    }
    sayMeet("MeetFirst" .. tostring(n), lines[n])
end

local function sightTick(st)
    if st.meetSeen == true then return end
    if not bodyAlive() then return end
    if Bridge.time - (BridgeMeet.sightAt or 0) < 15 then return end
    BridgeMeet.sightAt = Bridge.time
    local graced = false
    pcall(function() graced = Bridge.speechGraced() == true end)
    if graced then return end
    local bx, by = bodyPos()
    if bx == nil then return end
    local red = owner()
    if red == nil then return end
    local d = dist2d(red:getX(), red:getY(), bx, by)
    if d > SIGHT_RANGE then return end
    local seen = false
    local ok = pcall(function() seen = Bridge.body:CanSee(red) == true end)
    if not ok then pcall(function() seen = red:CanSee(Bridge.body) == true end) end
    if not seen then return end
    st.meetSeen = true
    log("first sighting")
    firstSightingSpeech()
end

local function wanderTick(st)
    if not BridgeMeet.wander then return end
    if stateOf(st) ~= "placed" then return end
    if st.meetScene == "holdout" then return end
    if Bridge.time - BridgeMeet.wanderAt < WANDER_EVERY then return end
    BridgeMeet.wanderAt = Bridge.time
    local x, y, z = spotOf(st)
    if x == nil then return end
    local engaged = false
    pcall(function()
        engaged = (BridgeFight ~= nil and BridgeFight.target ~= nil) or Bridge.target ~= nil
    end)
    if engaged then return end
    local sq = nil
    pcall(function() sq = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z)) end)
    if sq == nil then return end
    local inside = false
    pcall(function() inside = BridgeDoors.buildingOf(sq) ~= nil end)
    if inside then return end
    local angle = ZombRandFloat(0, math.pi * 2)
    local radius = ZombRandFloat(WANDER_MIN, WANDER_MAX)
    local wx = math.floor(x + math.cos(angle) * radius)
    local wy = math.floor(y + math.sin(angle) * radius)
    if dist2d(wx, wy, x, y) > WANDER_RANGE then return end
    local target = nil
    pcall(function() target = getCell():getGridSquare(wx, wy, math.floor(z)) end)
    if target == nil then return end
    local free = false
    pcall(function() free = target:isFree(false) == true and BridgeDoors.buildingOf(target) == nil end)
    if not free then return end
    setWait(st, wx, wy, z)
    vlog(string.format("wander wait=%d,%d", wx, wy))
end

local function applyDraftFallback(st)
    if BridgeMeet.readDone then return end
    BridgeMeet.readDone = true
    if st.meetMode ~= nil or st.meetState ~= nil then return end
    if BridgePregame == nil or type(BridgePregame.readMeetOptions) ~= "function" then return end
    if BridgeData == nil or type(BridgeData.neverSpawned) ~= "function" or not BridgeData.neverSpawned(st) then return end
    local opts = nil
    pcall(function() opts = BridgePregame.readMeetOptions() end)
    if opts == nil then return end
    st.meetMode = cleanMode(opts.mode)
    st.meetDays = cleanDays(opts.days)
    st.meetHint = cleanHint(opts.hint)
    st.meetTown = opts.town or "near"
    st.meetDistance = opts.distance or "close"
    if st.meetMode > 1 and st.meetState == nil and not bodyAlive() then
        st.meetState = "pending"
        st.want = false
        if st.meetMode == 3 then
            st.meetAt = worldAge() + st.meetDays * 24
        else
            st.meetAt = 0
        end
        log(string.format("meet pending from draft mode=%d days=%d hint=%d", st.meetMode, st.meetDays, st.meetHint))
    end
end

local function retryTick(st)
    if st.meetRetryScene == nil then return end
    if Bridge.time - (BridgeMeet.retryAt or 0) < 60 then return end
    BridgeMeet.retryAt = Bridge.time
    local x = tonumber(st.meetRetryTX)
    local y = tonumber(st.meetRetryTY)
    local z = tonumber(st.meetRetryTZ)
    if x == nil or y == nil or z == nil then
        st.meetRetryScene = nil
        return
    end
    local result = placeScene(st.meetRetryScene, x, y, z)
    if result == nil then return end
    applyResult(st, result)
    st.meetRetryScene = nil
    st.meetRetryTX, st.meetRetryTY, st.meetRetryTZ = nil, nil, nil
    st.meetTry = (tonumber(st.meetTry) or 0) + 1
    log(string.format("retry placed scene=%s spot=%s", result.scene, fmtSpot(result.x, result.y, result.z)))
end

local function forceSpawnEnabled()
    local sv = SandboxVars ~= nil and SandboxVars.StayWithMe or nil
    return sv ~= nil and sv.ForceSpawnNearPlayer == true
end

local function forceSpawnTick(st)
    if not forceSpawnEnabled() then return false end
    local red = owner()
    if red == nil then return true end
    if bodyAlive() then
        if st.meetState ~= "joined" then st.meetState = "joined" end
        st.want = true
        if Bridge.mode ~= "follow" then Bridge.setMode("follow") end
        return true
    end
    if Bridge.time - (BridgeMeet.forceAt or 0) < 60 then return true end
    BridgeMeet.forceAt = Bridge.time
    local x, y, z = red:getX(), red:getY(), red:getZ()
    local sx, sy, sz = Bridge.spawnSpot(x, y, z, false)
    if sx == nil then sx, sy, sz = x, y, z end
    pcall(function() Bridge.spawnZombie(sx, sy, sz) end)
    if bodyAlive() then
        st.meetState = "joined"
        st.meetScene = nil
        st.meetX, st.meetY, st.meetZ = nil, nil, nil
        st.meetTargetX, st.meetTargetY, st.meetTargetZ = nil, nil, nil
        st.meetRetryScene = nil
        st.meetRetryTX, st.meetRetryTY, st.meetRetryTZ = nil, nil, nil
        st.want = true
        Bridge.setMode("follow")
        log("force spawn near player")
    end
    return true
end

function BridgeMeet.tick()
    if Bridge == nil or Bridge.mp then return end
    local st = Bridge.store
    if st == nil or not Bridge.gotData then return end
    if forceSpawnTick(st) then return end
    if Bridge.time - (BridgeMeet.visitedAt or 0) >= 60 then
        BridgeMeet.visitedAt = Bridge.time
        pcall(recordVisited)
    end
    applyDraftFallback(st)
    local state = stateOf(st)
    if state == nil then
        if st.meetMode ~= nil and modeOf(st) > 1 and not bodyAlive() then
            st.meetState = "pending"
            st.want = false
            if modeOf(st) == 3 and tonumber(st.meetAt) == nil then
                st.meetAt = worldAge() + daysOf(st) * 24
            end
            log("meet pending recovered")
        end
        return
    end
    if state == "joined" then return end
    if state == "pending" then
        retryTick(st)
        state = stateOf(st)
        if state == "pending" then
            armTick(st)
            return
        end
    end
    if state == "placed" or state == "left" then
        resolveTarget(st)
        leftTick(st)
        if bodyAlive() then applyPose(st) end
        sightTick(st)
        wanderTick(st)
    end
end

local function awardHelp()
    local st = Bridge.store
    if st == nil then return "no_store", nil end
    if st.meetHelp == true then return "already", st end
    if BridgeSocial == nil or type(BridgeSocial.deed) ~= "function" then return "no_social", st end
    pcall(function() BridgeSocial.deed("meet") end)
    st.meetHelp = true
    log("fight bonus awarded")
    return "awarded", st
end

local function onZombieDead(z)
    if Bridge == nil or Bridge.mp or z == nil then return end
    local st = Bridge.store
    if st == nil then return end
    local state = stateOf(st)
    if state == nil or state == "joined" then return end
    if st.meetHelp == true then return end
    if not hasSpot(st) then return end
    local attacker = nil
    pcall(function() attacker = z:getAttackedBy() end)
    local player = false
    pcall(function() player = attacker ~= nil and instanceof(attacker, "IsoPlayer") end)
    if not player then return end
    local bx, by = bodyPos()
    local x, y = spotOf(st)
    if bx == nil then bx, by = x, y end
    if bx == nil then return end
    if dist2d(bx, by, x, y) > HELP_RANGE then return end
    awardHelp()
end

if type(Events) == "table" and Events.OnZombieDead ~= nil then
    Events.OnZombieDead.Add(function(z) pcall(onZombieDead, z) end)
end

local function installWrappers()
    if BridgeMeet.installed then return end
    if Bridge == nil or BridgeMenu == nil or BridgeWindow == nil or BridgeMap == nil or BridgeHeal == nil then return end
    local function wrap(tableName, key)
        local target = rawget(_G, tableName)
        if target == nil or type(target[key]) ~= "function" then return false end
        local flag = "__bridgeMeetWrapped_" .. key
        if rawget(target, flag) then return true end
        local orig = target[key]
        target[key] = function(...)
            local args = { ... }
            if BridgeMeet.unjoined() then
                if key == "fill" then
                    local context = args[1]
                    if context ~= nil and type(context.addOption) == "function" then
                        local text = nil
                        pcall(function() text = getText("IGUI_NotAlone_MeetNotYet") end)
                        if type(text) ~= "string" or text == "" or text == "IGUI_NotAlone_MeetNotYet" then text = "Not with you yet" end
                        local option = context:addOption(text)
                        if option ~= nil then option.isDisabled = true end
                    end
                    return nil
                end
                if key == "toggle" then
                    local red = owner()
                    local text = nil
                    pcall(function() text = getText("IGUI_NotAlone_MeetNotYet") end)
                    if type(text) ~= "string" or text == "" or text == "IGUI_NotAlone_MeetNotYet" then text = "Not with you yet" end
                    if red ~= nil then pcall(function() HaloTextHelper.addBadText(red, text) end) end
                    return nil
                end
                if key == "where" then return nil end
                if key == "autoCheck" then return nil end
                if (key == "speak" or key == "speakText") and not BridgeMeet.allowSpeech then
                    return nil
                end
            end
            return orig(unpack(args))
        end
        rawset(target, flag, true)
        return true
    end
    local ok = true
    ok = wrap("BridgeMenu", "fill") and ok
    ok = wrap("BridgeWindow", "toggle") and ok
    ok = wrap("Bridge", "speak") and ok
    ok = wrap("Bridge", "speakText") and ok
    ok = wrap("BridgeMap", "where") and ok
    ok = wrap("BridgeHeal", "autoCheck") and ok
    BridgeMeet.installed = ok
end

sayMeet = function(key, fallback)
    BridgeMeet.allowSpeech = true
    local text = nil
    pcall(function()
        if Bridge ~= nil and type(Bridge.speak) == "function" then text = Bridge.speak(key) end
    end)
    BridgeMeet.allowSpeech = false
    if type(text) ~= "string" or text == "" then
        BridgeMeet.allowSpeech = true
        pcall(function() Bridge.speakText(fallback) end)
        BridgeMeet.allowSpeech = false
    end
end

local function menuJoin()
    local st = Bridge.store
    if st == nil then return end
    local state = stateOf(st)
    if state ~= "placed" and state ~= "left" then return end
    local bx, by = bodyPos()
    local red = owner()
    if bx == nil or red == nil then return end
    if dist2d(bx, by, red:getX(), red:getY()) > TALK_RANGE then return end
    st.meetState = "joined"
    st.meetSeen = true
    Bridge.setMode("follow")
    sayMeet("MeetJoin", "I'll come with you.")
    log("joined")
end

local function menuLeave()
    local st = Bridge.store
    if st == nil then return end
    local state = stateOf(st)
    if state == "joined" then
        pcall(function() Bridge.goodbye() end)
    else
        st.want = false
        pcall(function() Bridge.goodbye() end)
    end
    st.meetState = "left"
    BridgeMeet.leftFar = false
    log("left")
end

local function installMenu()
    if BridgeMeet.menuHandler ~= nil then return end
    if type(Events) ~= "table" or Events.OnFillWorldObjectContextMenu == nil then return end
    local handler = function(playerNum, context, worldobjects, test)
        if test or Bridge == nil or Bridge.store == nil then return end
        if playerNum ~= nil and playerNum ~= 0 then return end
        if not BridgeMeet.unjoined() then return end
        local label = nil
        pcall(function() label = Bridge.companionName() end)
        if label ~= nil then pcall(function() context:removeOptionByName(label) end) end
        local survivor = nil
        pcall(function() survivor = getText("IGUI_NotAlone_MeetSurvivor") end)
        if type(survivor) ~= "string" or survivor == "" or survivor == "IGUI_NotAlone_MeetSurvivor" then survivor = "Survivor" end
        pcall(function() context:removeOptionByName(survivor) end)
        local bx, by = bodyPos()
        local red = owner()
        if bx == nil or red == nil then return end
        if dist2d(bx, by, red:getX(), red:getY()) > TALK_RANGE then return end
        local option = context:addOptionOnTop(survivor)
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(option, sub)
        local ask = nil
        local leave = nil
        pcall(function() ask = getText("IGUI_NotAlone_MeetAsk") end)
        pcall(function() leave = getText("IGUI_NotAlone_MeetLeave") end)
        if type(ask) ~= "string" or ask == "" or ask == "IGUI_NotAlone_MeetAsk" then ask = "Ask them to join you" end
        if type(leave) ~= "string" or leave == "" or leave == "IGUI_NotAlone_MeetLeave" then leave = "Leave them" end
        sub:addOption(ask, nil, menuJoin)
        sub:addOption(leave, nil, menuLeave)
    end
    Events.OnFillWorldObjectContextMenu.Add(handler)
    BridgeMeet.menuHandler = handler
end

local function install()
    installMenu()
    installWrappers()
end

if type(Events) == "table" then
    if Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function()
            BridgeMeet.testMode = false
            BridgeMeet.testZombies = {}
            BridgeMeet.installed = false
            install()
        end)
    end
    if Events.OnCreatePlayer ~= nil then
        Events.OnCreatePlayer.Add(function(playerIndex)
            if playerIndex ~= nil and playerIndex ~= 0 then return end
            install()
        end)
    end
end

function BridgeMeet.statusText()
    local st = Bridge.store or {}
    local state = stateOf(st) or "none"
    local scene = st.meetScene or "none"
    local spot = hasSpot(st) and fmtSpot(st.meetX, st.meetY, st.meetZ) or "none"
    local d = spotDist(st)
    local mode = modeOf(st)
    local days = effectiveDays(st)
    local hint = hintOf(st)
    local seen = st.meetSeen == true and 1 or 0
    local help = st.meetHelp == true and 1 or 0
    local tries = tonumber(st.meetTry) or 0
    local body = bodyAlive() and 1 or 0
    local want = (st.want ~= false) and 1 or 0
    local arm = 0
    if mode == 3 then arm = math.max(0, (tonumber(st.meetAt) or 0) - worldAge()) end
    local distText = d < 0 and "-1" or string.format("%.1f", d)
    return string.format("status mode=%d days=%d hint=%d state=%s scene=%s spot=%s dist=%s seen=%d help=%d try=%d body=%d want=%d arm=%.1f",
        mode, days, hint, state, scene, spot, distText, seen, help, tries, body, want, arm)
end

local function whereText()
    local st = Bridge.store or {}
    if not hasSpot(st) then return "where none" end
    local red = owner()
    if red == nil then return "where none" end
    local x, y, z = spotOf(st)
    local d = dist2d(red:getX(), red:getY(), x, y)
    local dir = dir8(x - red:getX(), y - red:getY())
    return string.format("where x=%d y=%d z=%d dist=%.1f dir=%s state=%s",
        math.floor(x), math.floor(y), math.floor(z), d, dir, stateOf(st) or "none")
end

local function gateState()
    local blocked = BridgeMeet.unjoined()
    local word = blocked and "blocked" or "open"
    return word
end

local function gateText()
    local state = stateOf(Bridge.store) or "none"
    local word = gateState()
    return string.format("gate state=%s menu=%s window=%s speak=%s map=%s heal=%s",
        state, word, word, word, word, word)
end

local function auditText()
    local st = Bridge.store or {}
    local scene = st.meetScene or "none"
    if scene == "holdout" and hasSpot(st) then
        local x, y, z = spotOf(st)
        local building = scanBuildingNear(x, y, z, 8)
        if building == nil then return "audit scene=holdout building=none z=" .. tostring(math.floor(z)) end
        local openings = {}
        pcall(function() openings = BridgeDoors.exteriorOpenings(building, math.floor(z)) end)
        local barricaded, tagged = 0, 0
        for _, entry in ipairs(openings or {}) do
            if doorBarricaded(entry.obj) then
                barricaded = barricaded + 1
                local board = nil
                pcall(function() board = entry.obj:getBarricadeOnSameSquare() end)
                if board == nil then pcall(function() board = entry.obj:getBarricadeOnOppositeSquare() end) end
                if isTagged(board) then tagged = tagged + 1 end
            end
        end
        local sally = BridgeMeet.sally
        local sallyText = "none"
        if sally ~= nil then sallyText = string.format("%d,%d", sally.x, sally.y) end
        local locked = 0
        if BridgeMeet.sallyDoor ~= nil then pcall(function() locked = doorLocked(BridgeMeet.sallyDoor) and 1 or 0 end) end
        local list = ""
        pcall(function() list = BridgeDoors.debugOpenings(building, math.floor(z)) end)
        return string.format("audit scene=holdout building=%s z=%d openings=%d barricaded=%d tagged=%d refused=%d sally=%s locked=%d list=%s",
            tostring(building:getID()), math.floor(z), #(openings or {}), barricaded, tagged,
            BridgeMeet.lastRefused or 0, sallyText, locked, list)
    end
    local props = st.meetScene ~= nil and ("zombies:" .. tostring(#BridgeMeet.testZombies)) or "none"
    return string.format("audit scene=%s props=%s testZombies=%d", scene, props, #BridgeMeet.testZombies)
end

function BridgeMeet.diagLine()
    local st = Bridge.store or {}
    local spot = hasSpot(st) and fmtSpot(st.meetX, st.meetY, st.meetZ) or "none"
    local target = "none"
    if tonumber(st.meetTargetX) ~= nil then
        target = fmtSpot(st.meetTargetX, st.meetTargetY, st.meetTargetZ)
    end
    local tagged = 0
    if hasSpot(st) then
        local x, y, z = spotOf(st)
        local building = scanBuildingNear(x, y, z, 8)
        if building ~= nil then
            local openings = {}
            pcall(function() openings = BridgeDoors.exteriorOpenings(building, math.floor(z)) end)
            for _, entry in ipairs(openings or {}) do
                local board = nil
                pcall(function() board = entry.obj:getBarricadeOnSameSquare() end)
                if board == nil then pcall(function() board = entry.obj:getBarricadeOnOppositeSquare() end) end
                if isTagged(board) then tagged = tagged + 1 end
            end
        end
    end
    local sally = "none"
    if BridgeMeet.sally ~= nil then sally = string.format("%d,%d", BridgeMeet.sally.x, BridgeMeet.sally.y) end
    return string.format("mode=%d days=%d hint=%d state=%s scene=%s spot=%s dist=%.1f seen=%s help=%s try=%s body=%s want=%s arm=%.1f forts=%d tagged=%d sally=%s",
        modeOf(st), effectiveDays(st), hintOf(st), stateOf(st) or "none", st.meetScene or "none", spot,
        spotDist(st), tostring(st.meetSeen == true), tostring(st.meetHelp == true), tostring(st.meetTry or 0),
        tostring(bodyAlive()), tostring(st.want ~= false),
        modeOf(st) == 3 and math.max(0, (tonumber(st.meetAt) or 0) - worldAge()) or 0,
        BridgeMeet.lastForts or 0, tagged, sally)
end

local function resetFields(st, hard)
    if st == nil then return "reset=FAIL no_store" end
    st.leaveAt, st.leaveTries, st.respawnAt = nil, nil, nil
    st.parked, st.sleepParked, st.claimParked, st.homeParked = nil, nil, nil, nil
    st.target = nil
    st.meetSeen, st.meetHelp, st.meetTry = nil, nil, nil
    st.meetRetryScene = nil
    st.meetRetryTX, st.meetRetryTY, st.meetRetryTZ = nil, nil, nil
    st.meetAt = 0
    if hard then
        st.meetScene, st.meetX, st.meetY, st.meetZ = nil, nil, nil, nil
        st.meetTargetX, st.meetTargetY, st.meetTargetZ, st.meetPose = nil, nil, nil, nil
        st.meetState = "pending"
        st.want = false
        return "reset=hard state=pending scene=none spot=none body=0 want=0"
    end
    if hasSpot(st) then
        st.meetState = "placed"
        st.want = true
        return string.format("reset=soft state=placed scene=%s spot=%s body=0 want=1",
            st.meetScene or "none", fmtSpot(st.meetX, st.meetY, st.meetZ))
    end
    st.meetState = "pending"
    st.want = false
    st.meetScene = nil
    return "reset=soft state=pending scene=none spot=none body=0 want=0"
end

local function resetRun(st, hard)
    if bodyAlive() then
        Bridge.despawnByCommand = true
        pcall(function() Bridge.despawn(true) end)
        Bridge.despawnByCommand = false
    end
    clearRuntime()
    Bridge.parked = false
    Bridge.sleepParked = nil
    Bridge.claimParked = nil
    Bridge.homeParked = false
    Bridge.setMode("wait")
    Bridge.startTick = Bridge.time
    Bridge.spawnBackoff = nil
    local text = resetFields(st, hard)
    if not hard and hasSpot(st) then
        Bridge.setMode("wait")
        setWait(st, st.meetX, st.meetY, st.meetZ)
    end
    BridgeMeet.pendingScene = false
    BridgeMeet.poseBody = nil
    return text
end

local function requireTest(sub, seq)
    if BridgeMeet.testMode then return nil end
    return reply(seq, tostring(sub) .. "=FAIL test_off (run: meet test on)")
end

local function doJoin(seq)
    local st = Bridge.store
    local state = stateOf(st)
    if state == "joined" then return reply(seq, "join=FAIL already_joined") end
    if state ~= "placed" then return reply(seq, "join=FAIL not_placed") end
    local bx, by = bodyPos()
    if bx == nil then return reply(seq, "join=FAIL no_body") end
    local red = owner()
    if red == nil then return reply(seq, "join=FAIL no_body") end
    if dist2d(bx, by, red:getX(), red:getY()) > TALK_RANGE then return reply(seq, "join=FAIL too_far") end
    st.meetState = "joined"
    st.meetSeen = true
    Bridge.setMode("follow")
    sayMeet("MeetJoin", "I'll come with you.")
    local help = st.meetHelp == true and 1 or 0
    log("joined")
    return reply(seq, string.format("join=joined mode=follow help=%d", help))
end

local function doLeave(seq)
    local st = Bridge.store
    if stateOf(st) ~= "joined" then return reply(seq, "leave=FAIL not_joined") end
    pcall(function() Bridge.goodbye() end)
    st.meetState = "left"
    BridgeMeet.leftFar = false
    local spot = hasSpot(st) and fmtSpot(st.meetX, st.meetY, st.meetZ) or "none"
    log("left")
    return reply(seq, "leave=left state=left spot=" .. spot)
end

local function doArm(seq, args)
    local st = Bridge.store
    if st == nil then return reply(seq, "arm=FAIL no_store") end
    if stateOf(st) == "joined" then return reply(seq, "arm=FAIL already_joined") end
    if modeOf(st) == 1 then return reply(seq, "arm=FAIL with_you") end
    if args[1] ~= nil then st.meetDays = cleanDays(args[1]) end
    clearRuntime()
    Bridge.leaveAt, Bridge.leaveTries, Bridge.respawnAt = nil, nil, nil
    Bridge.homeParked = false
    local scene = st.meetScene
    if scene == nil or not hasSpot(st) then
        scene = randomScene()
        st.meetScene = scene
        armSpot(st)
    else
        local x, y, z = spotOf(st)
        local result = placeScene(scene, x, y, z)
        if result == nil then
            st.meetState = "pending"
            st.want = false
            st.meetRetryScene = scene
            st.meetRetryTX, st.meetRetryTY, st.meetRetryTZ = x, y, z
            return reply(seq, "arm=RETRY " .. tostring(BridgeMeet.lastSceneFail or BridgeMeet.lastRoadFail or "no_scene") .. " state=pending")
        end
        applyResult(st, result)
        if result.fallback ~= nil and result.fallback ~= "none" then
            log(string.format("arm fallback=%s scene=%s", result.fallback, result.scene))
        end
    end
    st.meetState = "placed"
    st.meetAt = 0
    st.want = true
    st.meetTry = (tonumber(st.meetTry) or 0) + 1
    Bridge.setMode("wait")
    setWait(st, st.meetX, st.meetY, st.meetZ)
    local d = spotDist(st)
    return reply(seq, string.format("arm scene=%s spot=%s dist=%.1f state=placed spawn=waiting",
        st.meetScene or "none", fmtSpot(st.meetX, st.meetY, st.meetZ), d))
end

local function doPlace(seq, args)
    local st = Bridge.store
    if st == nil then return reply(seq, "place=FAIL no_store") end
    local scene = args[1] or "holdout"
    if not sceneOk(scene) then return reply(seq, "place=FAIL unknown_scene") end
    local dx = tonumber(args[2]) or 4
    local dy = tonumber(args[3]) or 4
    local red = owner()
    if red == nil then return reply(seq, "place=FAIL no_player") end
    local z = math.floor(red:getZ())
    local tx = math.floor(red:getX()) + dx
    local ty = math.floor(red:getY()) + dy
    local loaded = false
    pcall(function() loaded = getCell():getGridSquare(tx, ty, z) ~= nil end)
    if not loaded then
        if scene == "driver" then
            tx = math.floor(red:getX())
            ty = math.floor(red:getY())
            z = math.floor(red:getZ())
        else
            st.meetState = "pending"
            st.want = false
            st.meetScene = nil
            st.meetX, st.meetY, st.meetZ = nil, nil, nil
            st.meetTargetX, st.meetTargetY, st.meetTargetZ = nil, nil, nil
            Bridge.setMode("wait")
            return reply(seq, "place=FAIL not_loaded state=pending spot=none")
        end
    end
    clearRuntime()
    Bridge.leaveAt, Bridge.leaveTries, Bridge.respawnAt = nil, nil, nil
    Bridge.homeParked = false
    local result = placeScene(scene, tx, ty, z)
    if result == nil then
        st.meetState = "pending"
        st.want = false
        st.meetScene = nil
        st.meetX, st.meetY, st.meetZ = nil, nil, nil
        st.meetTargetX, st.meetTargetY, st.meetTargetZ = nil, nil, nil
        st.meetRetryScene = scene
        st.meetRetryTX, st.meetRetryTY, st.meetRetryTZ = tx, ty, z
        Bridge.setMode("wait")
        return reply(seq, "place=RETRY " .. tostring(BridgeMeet.lastSceneFail or BridgeMeet.lastRoadFail or "no_scene") .. " state=pending spot=none")
    end
    applyResult(st, result)
    st.meetTry = (tonumber(st.meetTry) or 0) + 1
    if result.fallback ~= nil and result.fallback ~= "none" then
        log(string.format("fallback=%s scene=%s", result.fallback, result.scene))
    end
    local d = spotDist(st)
    return reply(seq, string.format("place scene=%s spot=%s dist=%.1f props=%s forts=%d refused=%d sally=%s fallback=%s state=placed spawn=waiting",
        result.scene, fmtSpot(result.x, result.y, result.z), d, result.props or "none",
        BridgeMeet.lastForts or 0, BridgeMeet.lastRefused or 0,
        BridgeMeet.sally ~= nil and string.format("%d,%d", BridgeMeet.sally.x, BridgeMeet.sally.y) or "none",
        result.fallback or "none"))
end

local function doSpawn(seq)
    local st = Bridge.store
    if st == nil then return reply(seq, "spawn=FAIL no_store") end
    if stateOf(st) ~= "placed" then return reply(seq, "spawn=FAIL no_spot") end
    if bodyAlive() then return reply(seq, "spawn=FAIL already_alive") end
    if not hasSpot(st) then return reply(seq, "spawn=FAIL no_spot") end
    local x, y, z = spotOf(st)
    local loaded = false
    pcall(function() loaded = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z)) ~= nil end)
    if not loaded then return reply(seq, "spawn=FAIL not_loaded") end
    local res = Bridge.spawnZombie(x, y, z)
    if not bodyAlive() then return reply(seq, "spawn=FAIL " .. tostring(res)) end
    applyPose(st)
    log("spawned at " .. fmtSpot(x, y, z))
    return reply(seq, "spawn=PASS body=zombie spot=" .. fmtSpot(x, y, z))
end

local function doUnfortify(seq)
    local st = Bridge.store
    if st == nil or not hasSpot(st) then return reply(seq, "unfortify=FAIL no_spot") end
    local x, y, z = spotOf(st)
    local loaded = false
    pcall(function() loaded = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z)) ~= nil end)
    if not loaded then return reply(seq, "unfortify=FAIL not_loaded") end
    local building = scanBuildingNear(x, y, z, 8)
    if building == nil then return reply(seq, "unfortify=FAIL no_building") end
    local openings = {}
    pcall(function() openings = BridgeDoors.exteriorOpenings(building, math.floor(z)) end)
    local removed, kept = 0, 0
    for _, entry in ipairs(openings or {}) do
        local board = nil
        pcall(function() board = entry.obj:getBarricadeOnSameSquare() end)
        if board == nil then pcall(function() board = entry.obj:getBarricadeOnOppositeSquare() end) end
        if board ~= nil then
            if isTagged(board) then
                local planks = 0
                pcall(function() planks = board:getNumPlanks() end)
                for _ = 1, planks do pcall(function() board:removePlank(nil) end) end
                local sq = nil
                pcall(function() sq = board:getSquare() or entry.obj:getSquare() end)
                if sq ~= nil then pcall(function() sq:transmitRemoveItemFromSquare(board) end) end
                local still = false
                pcall(function() still = entry.obj:isBarricaded() == true end)
                if not still then removed = removed + 1 else kept = kept + 1 end
            else
                kept = kept + 1
            end
        end
    end
    if removed == 0 and kept == 0 then return reply(seq, "unfortify=FAIL none_tagged") end
    log(string.format("unfortify removed=%d kept=%d", removed, kept))
    return reply(seq, string.format("unfortify removed=%d kept=%d", removed, kept))
end

local function doMode(seq, args)
    local st = Bridge.store
    if st == nil then return reply(seq, "mode=FAIL no_store") end
    local mode = cleanMode(args[1])
    local days = cleanDays(args[2])
    st.meetMode = mode
    st.meetDays = days
    if mode == 3 then
        st.meetAt = worldAge() + days * 24
    else
        st.meetAt = 0
    end
    local outDays = mode == 3 and days or 0
    return reply(seq, string.format("mode=%d days=%d", mode, outDays))
end

local function findTown(id)
    local boxes = BridgeCallout ~= nil and BridgeCallout.CITY_BOXES or nil
    if type(boxes) ~= "table" or #boxes == 0 then return nil end
    if id == nil or id == "" or id == "random" then
        return boxes[ZombRand(1, #boxes + 1)]
    end
    for _, box in ipairs(boxes) do
        if box.id == id then return box end
    end
    return nil
end

local function townListText()
    local boxes = BridgeCallout ~= nil and BridgeCallout.CITY_BOXES or nil
    if type(boxes) ~= "table" or #boxes == 0 then return "town=FAIL no_towns" end
    local ids = {}
    for _, box in ipairs(boxes) do ids[#ids + 1] = box.id end
    return "towns " .. table.concat(ids, ",")
end

local function doTown(seq, args)
    local st = Bridge.store
    if st == nil then return reply(seq, "town=FAIL no_store") end
    local id = args[1]
    if id == "list" or id == "?" then return reply(seq, townListText()) end
    local box = findTown(id)
    if box == nil then return reply(seq, "town=FAIL unknown_town " .. townListText()) end
    local red = owner()
    if red == nil then return reply(seq, "town=FAIL no_player") end
    resetRun(st, true)
    local cx = math.floor((box.minX + box.maxX) / 2)
    local cy = math.floor((box.minY + box.maxY) / 2)
    pcall(function() red:setX(cx + 0.5) end)
    pcall(function() red:setY(cy + 0.5) end)
    pcall(function() red:setZ(0) end)
    pcall(function() red:setLastX(cx + 0.5) end)
    pcall(function() red:setLastY(cy + 0.5) end)
    pcall(function() red:setLastZ(0) end)
    st.meetRetryScene = "holdout"
    st.meetRetryTX, st.meetRetryTY, st.meetRetryTZ = cx, cy, 0
    st.meetState = "pending"
    st.want = false
    BridgeMeet.retryAt = Bridge.time
    Bridge.setMode("wait")
    log(string.format("town test id=%s center=%d,%d", box.id, cx, cy))
    return reply(seq, string.format("town=%s center=%d,%d,0 teleported=1 state=pending retry=holdout", box.id, cx, cy))
end

local function doKill(seq)
    local what, st = awardHelp()
    local f, r = 0, 0
    if st ~= nil then
        local rel = nil
        pcall(function() rel = BridgeData.relOf(st) end)
        if rel ~= nil then f, r = rel.f or 0, rel.r or 0 end
    end
    if what == "awarded" then return reply(seq, string.format("kill help=awarded f=%d r=%d", f, r)) end
    if what == "already" then return reply(seq, string.format("kill help=already f=%d r=%d", f, r)) end
    return reply(seq, "kill=FAIL " .. tostring(what))
end

function BridgeMeet.selftest()
    local fails, checks = {}, 0
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end
    local dirs = {
        { 1, 0, "E" }, { -1, 0, "W" }, { 0, 1, "S" }, { 0, -1, "N" },
        { 1, 1, "SE" }, { 1, -1, "NE" }, { -1, 1, "SW" }, { -1, -1, "NW" }, { 0, 0, "here" },
    }
    for _, d in ipairs(dirs) do check("dir8 " .. d[3], dir8(d[1], d[2]) == d[3]) end
    check("mode 0", cleanMode(0) == 1)
    check("mode 4", cleanMode(4) == 3)
    check("mode nil", cleanMode(nil) == 1)
    check("days 0", cleanDays(0) == 1)
    check("days 8", cleanDays(8) == 8)
    check("days 30", cleanDays(30) == 30)
    check("days nil", cleanDays(nil) == 1)
    check("hint nil", cleanHint(nil) == 1)
    check("hint 3", cleanHint(3) == 1)
    check("hint -1", cleanHint(-1) == 0)
    check("near band", NEAR_MIN == 25 and NEAR_MAX == 40)
    check("far band", FAR_MIN == 50 and FAR_MAX == 80)
    local st = { meetScene = "holdout", meetX = 10, meetY = 20, meetZ = 0, meetMode = 2, meetDays = 3, meetHint = 1 }
    local soft = resetFields(st, false)
    check("soft reset placed", string.find(soft, "state=placed", 1, true) ~= nil and string.find(soft, "want=1", 1, true) ~= nil)
    check("soft reset keeps scene", st.meetScene == "holdout" and st.meetX == 10)
    check("soft reset clears seen", st.meetSeen == nil and st.meetHelp == nil and st.meetTry == nil)
    local hard = resetFields(st, true)
    check("hard reset pending", string.find(hard, "state=pending", 1, true) ~= nil)
    check("hard reset clears spot", st.meetScene == nil and st.meetX == nil)
    local fakeA = { obj = { getSquare = function() return "inside" end }, outside = "outside" }
    local fakeB = { obj = { getSquare = function() return "outside" end }, outside = "outside" }
    check("addOpposite true", addOppositeFor(fakeA) == false)
    check("addOpposite false", addOppositeFor(fakeB) == true)
    local doors = {
        { obj = 1, barricaded = true, locked = true, garage = true, dist = 1, tagged = false },
        { obj = 2, barricaded = false, locked = false, garage = false, dist = 5, tagged = false },
    }
    local best = rankDoors(doors, 0, 0)
    check("sally rank unlocked", best ~= nil and best.obj == 2)
    local twinA = { obj = 1, inside = { getRoom = function() return "r" end, getX = function() return 0 end, getY = function() return 0 end, getZ = function() return 0 end },
        outside = { getX = function() return 0 end, getY = function() return 0 end, getZ = function() return 0 end } }
    local twinB = { obj = 2, inside = { getRoom = function() return "r" end, getX = function() return 0 end, getY = function() return 0 end, getZ = function() return 0 end },
        outside = { getX = function() return 1 end, getY = function() return 0 end, getZ = function() return 0 end } }
    check("twin leaf", isTwinLeaf(twinA, twinB) == true)
    check("fallback order", fallbackFor({ noBuilding = true }) == "no_building"
        and fallbackFor({ noDoor = true }) == "no_door"
        and fallbackFor({ noApi = true }) == "no_barricade_api"
        and fallbackFor({ noBoards = true }) == "no_barricade"
        and fallbackFor({ allBarred = true }) == "all_doors_barred")
    check("unfortify filter", isTagged({ getModData = function() return { BridgeMeetFort = 1 } end }) == true
        and isTagged({ getModData = function() return {} end }) == false)
    if #fails == 0 then return string.format("selftest PASS (%d checks)", checks) end
    return string.format("selftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end

function BridgeMeet.run(parts, line)
    local seq = parts[1] or "0"
    local sub = parts[3] or "status"
    if Bridge ~= nil and Bridge.mp then return reply(seq, "mp=off") end
    local args = {}
    for i = 4, #parts do args[#args + 1] = parts[i] end
    if sub == "status" then return reply(seq, BridgeMeet.statusText()) end
    if sub == "where" then return reply(seq, whereText()) end
    if sub == "diag" then
        return reply(seq, string.format("diag mode=%d days=%d hint=%d state=%s scene=%s spot=%s target=%s seen=%s help=%s try=%s body=%s want=%s arm=%.1f gates=menu:%s,window:%s,speak:%s,map:%s,heal:%s audit=%s",
            modeOf(Bridge.store), effectiveDays(Bridge.store), hintOf(Bridge.store), stateOf(Bridge.store) or "none",
            Bridge.store and Bridge.store.meetScene or "none",
            hasSpot(Bridge.store) and fmtSpot(Bridge.store.meetX, Bridge.store.meetY, Bridge.store.meetZ) or "none",
            tonumber(Bridge.store and Bridge.store.meetTargetX) ~= nil and fmtSpot(Bridge.store.meetTargetX, Bridge.store.meetTargetY, Bridge.store.meetTargetZ) or "none",
            tostring(Bridge.store and Bridge.store.meetSeen == true), tostring(Bridge.store and Bridge.store.meetHelp == true),
            tostring(Bridge.store and Bridge.store.meetTry or 0), tostring(bodyAlive()), tostring(Bridge.store and Bridge.store.want ~= false),
            modeOf(Bridge.store) == 3 and math.max(0, (tonumber(Bridge.store and Bridge.store.meetAt) or 0) - worldAge()) or 0,
            gateState(), gateState(), gateState(), gateState(), gateState(), auditText()))
    end
    if sub == "audit" then return reply(seq, auditText()) end
    if sub == "gate" then return reply(seq, gateText()) end
    if sub == "selftest" then return reply(seq, BridgeMeet.selftest()) end
    if sub == "help" then
        return reply(seq, "help status where diag audit gate selftest test | test on: reset [hard], unfortify, arm [days], place <holdout|scavenger|driver> [dx dy], town [list|<id>|random], spawn, join, leave, kill, mode <1|2|3> [days], hint <0|1>, seen <0|1>, wander on|off")
    end
    if sub == "test" then
        local arg = args[1]
        if arg == "on" then
            BridgeMeet.testMode = true
            log("test mode on")
            return reply(seq, "test=on")
        end
        if arg == "off" then
            BridgeMeet.testMode = false
            log("test mode off")
            return reply(seq, "test=off")
        end
        return reply(seq, BridgeMeet.testMode and "test=on" or "test=off")
    end
    if sub == "reset" then
        local refused = requireTest("reset", seq)
        if refused ~= nil then return refused end
        local hard = args[1] == "hard"
        return reply(seq, resetRun(Bridge.store, hard))
    end
    if sub == "unfortify" then
        local refused = requireTest("unfortify", seq)
        if refused ~= nil then return refused end
        return doUnfortify(seq)
    end
    if sub == "arm" then
        local refused = requireTest("arm", seq)
        if refused ~= nil then return refused end
        return doArm(seq, args)
    end
    if sub == "place" then
        local refused = requireTest("place", seq)
        if refused ~= nil then return refused end
        return doPlace(seq, args)
    end
    if sub == "spawn" then
        local refused = requireTest("spawn", seq)
        if refused ~= nil then return refused end
        return doSpawn(seq)
    end
    if sub == "join" then
        local refused = requireTest("join", seq)
        if refused ~= nil then return refused end
        return doJoin(seq)
    end
    if sub == "leave" then
        local refused = requireTest("leave", seq)
        if refused ~= nil then return refused end
        return doLeave(seq)
    end
    if sub == "kill" then
        local refused = requireTest("kill", seq)
        if refused ~= nil then return refused end
        return doKill(seq)
    end
    if sub == "mode" then
        local refused = requireTest("mode", seq)
        if refused ~= nil then return refused end
        return doMode(seq, args)
    end
    if sub == "town" then
        local refused = requireTest("town", seq)
        if refused ~= nil then return refused end
        return doTown(seq, args)
    end
    if sub == "hint" then
        local refused = requireTest("hint", seq)
        if refused ~= nil then return refused end
        local st = Bridge.store
        if st == nil then return reply(seq, "hint=FAIL no_store") end
        st.meetHint = cleanHint(args[1])
        return reply(seq, "hint=" .. tostring(st.meetHint))
    end
    if sub == "seen" then
        local refused = requireTest("seen", seq)
        if refused ~= nil then return refused end
        local st = Bridge.store
        if st == nil then return reply(seq, "seen=FAIL no_store") end
        st.meetSeen = (args[1] == "1")
        return reply(seq, "seen=" .. (st.meetSeen and "1" or "0"))
    end
    if sub == "wander" then
        local refused = requireTest("wander", seq)
        if refused ~= nil then return refused end
        BridgeMeet.wander = args[1] ~= "off"
        return reply(seq, BridgeMeet.wander and "wander=on" or "wander=off")
    end
    return reply(seq, "FAIL unknown (try: meet help)")
end

function BridgeMeet.markerTarget()
    if Bridge == nil or Bridge.mp then return nil end
    local st = Bridge.store
    if st == nil then return nil end
    local state = stateOf(st)
    if state ~= "placed" and state ~= "left" then return nil end
    if hintOf(st) == 0 then return nil end
    local x, y, z = spotOf(st)
    if x == nil then return nil end
    local bx, by = bodyPos()
    if bx ~= nil then x, y = bx, by end
    return x, y, z
end

function BridgeMeet.dirTo(x, y)
    local red = owner()
    if red == nil or x == nil or y == nil then return "?" end
    return dir8(x - red:getX(), y - red:getY())
end

function BridgeMeet.testAward()
    return awardHelp()
end

return BridgeMeet
