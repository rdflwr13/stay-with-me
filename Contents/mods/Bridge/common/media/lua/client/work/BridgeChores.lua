-- Home chores brain. Policy only: every action starts an existing owner
-- (BridgeTask, BridgeWash, BridgeShower, BridgeExercise) and movement reuses
-- Bridge.target / BridgeMove. No second walker, timer, or state machine for a
-- job that already owns one.

BridgeChores = BridgeChores or {}
BridgeChores.info = "idle"

local FLOOR = 60
local SCAN_CHUNK = 8
local TTL_OCCUPIED_MS = 45 * 1000
local TTL_EMPTY_MS = 5 * 60 * 1000
local TTL_DOOR_EMPTY_MS = 5 * 1000
local DECISION_GAP = 1 * FLOOR
local IDLE_GAP = 30 * FLOOR
local ROAM_DWELL = 2 * FLOOR
local SIT_DWELL = 90 * FLOOR
local STUCK = 120 * FLOOR
local START_FAIL = 3 * 60 * FLOOR
local START_FAIL_CAP = 2 * 60 * 60 * FLOOR
local BLACKLIST = 45 * 60 * FLOOR
local WASH_MIN_DIRTY = 2

local ROWS = {
    tend = { kind = "tendCrops", group = "gardening", flag = "TEND_ENABLED", cooldownH = 0.5, weight = 6 },
    harvest = { kind = "harvestCrops", group = "gardening", flag = "HARVESTING_ENABLED", cooldownH = 0.5, weight = 5 },
    animals = { group = "animals", cooldownH = 0.75, weight = 8, dynamic = true },
    troughs = { kind = "fillTroughs", group = "animals", flag = "TROUGHS_ENABLED", cooldownH = 0.5, weight = 7 },
    clean = { kind = "cleanUp", group = "cleanUp", flag = "CLEANING_ENABLED", cooldownH = 2, weight = 4 },
    yard = { kind = "clearPlants", group = "clearPlants", flag = "CLEARING_ENABLED", cooldownH = 2, weight = 2 },
    chop = { kind = "chopTree", group = "chopTree", flag = "TREECUTTING_ENABLED", cooldownH = 4, weight = 2 },
    deposit = { kind = "deposit", flag = "DEPOSIT_ENABLED", cooldownH = 1 },
    closeDoors = { kind = "closeDoors", group = "doors", flag = "DOORS_ENABLED", cooldownH = 1, weight = 1 },
    closeWindows = { kind = "closeWindows", group = "doors", flag = "WINDOWS_ENABLED", cooldownH = 1, weight = 1 },
    corpses = { kind = "moveCorpses", group = "moveCorpses", flag = "MOVE_CORPSES_ENABLED", cooldownH = 1, weight = 2 },
    wash = { idle = true, cooldownH = 1 },
    shower = { idle = true },
    exercise = { idle = true },
    sit = { idle = true },
    roam = { idle = true },
}

local SCAN_ROWS = { "animals", "troughs", "tend", "harvest", "clean", "yard", "chop", "closeDoors", "closeWindows", "corpses" }

local S = {
    scan = {},
    plans = {},
    planKey = nil,
    homeKey = nil,
    links = nil,
    linkKey = nil,
    stair = {},
    scanRow = 0,
    scanCount = 0,
    running = nil,
    waiting = nil,
    cooldown = {},
    retry = {},
    fails = {},
    blacklist = {},
    lastRow = nil,
    lastNeed = 0,
    lastSeat = nil,
    nextDecisionAt = 0,
    nextIdleAt = 0,
    idleAllowedAt = 0,
    scanBootDone = false,
    forceRoam = false,
    armed = false,
    playerBusyUntil = 0,
    scanReady = false,
    seatReady = false,
    seatChunks = {},
    seatCursor = 0,
    seatOrder = nil,
    seatOrderKey = nil,
    seatDirty = {},
    seatNextRefresh = 0,
    stopPending = nil,
    lastZ = nil,
    lastZAt = nil,
    danger = false,
    dangerTick = 0,
    closeAt = 0,
    diagAt = 0,
    statusCache = {},
    seatKey = nil,
    seatAt = 0,
    seatList = nil,
    showerKey = nil,
    showerAt = 0,
    showerObj = nil,
    showerSq = nil,
}

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeChores] " .. tostring(text)) end
end

function BridgeChores.arm()
    if S.armed then return end
    S.armed = true
    S.scanBootDone = false
    S.scanReady = false
    S.seatReady = false
    S.seatChunks = {}
    S.seatCursor = 0
    S.seatOrder = nil
    S.seatOrderKey = nil
    S.seatDirty = {}
    S.seatNextRefresh = 0
    S.stopPending = nil
    S.idleAllowedAt = (Bridge.time or 0) + 2 * FLOOR
    S.nextDecisionAt = 0
    S.nextIdleAt = 0
end

function BridgeChores.disarm()
    S.armed = false
end

local MANUAL_STOP_HOURS = 3
local MANUAL_STOP_TIME = MANUAL_STOP_HOURS * 60 * 60 * FLOOR
local KIND_ROW = {
    tendCrops = "tend", harvestCrops = "harvest",
    tendAnimals = "animals", animalCare = "animals", petAnimals = "animals",
    fillTroughs = "troughs", cleanUp = "clean", clearPlants = "yard",
    chopTree = "chop", deposit = "deposit", shower = "shower", exercise = "exercise",
    wash = "wash", sit = "sit", roam = "roam",
    closeDoors = "closeDoors", closeWindows = "closeWindows",
}

function BridgeChores.noteManualStop(kind)
    local id = KIND_ROW[kind]
    if id == nil then return end
    local now = Bridge.time or 0
    if id == "deposit" then
        S.retry[id] = now + MANUAL_STOP_TIME
        S.cooldown[id] = nil
        if S.running ~= nil and S.running.row == "deposit" then S.running = nil end
        if S.waiting ~= nil and S.waiting.row == "deposit" then S.waiting = nil end
    else
        S.cooldown[id] = now + MANUAL_STOP_TIME
        S.retry[id] = nil
    end
    S.statusCache[id] = nil
    S.nextDecisionAt = now + DECISION_GAP
    S.nextIdleAt = now + IDLE_GAP
    if id == "roam" then S.forceRoam = false end
    if id == "shower" and BridgeShower ~= nil and type(BridgeShower.setCooldown) == "function" then
        pcall(BridgeShower.setCooldown, Bridge.store, MANUAL_STOP_HOURS)
    elseif id == "exercise" and BridgeExercise ~= nil and type(BridgeExercise.setCooldown) == "function" then
        pcall(BridgeExercise.setCooldown, Bridge.store, MANUAL_STOP_HOURS)
    end
    log("manual stop cooldown " .. tostring(id) .. " " .. tostring(MANUAL_STOP_HOURS) .. "h")
end

function BridgeChores.noteSeat(x, y, z)
    if x == nil or y == nil then return end
    S.lastSeat = math.floor(x) .. ":" .. math.floor(y) .. ":" .. math.floor(z or 0)
    log("sit success seat=" .. S.lastSeat)
end

if Events ~= nil and Events.OnInventoryTransferActionPerform ~= nil then
    Events.OnInventoryTransferActionPerform.Add(function()
        S.playerBusyUntil = (Bridge.time or 0) + 4 * FLOOR
    end)
end

local function tr(key, a, b)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key, a, b) end
    local out = key
    pcall(function()
        if b ~= nil then out = getText("IGUI_NotAlone_" .. key, a, b)
        elseif a ~= nil then out = getText("IGUI_NotAlone_" .. key, a)
        else out = getText("IGUI_NotAlone_" .. key) end
    end)
    return out
end

local function nowMs()
    local v = 0
    pcall(function() v = getTimestampMs() end)
    v = tonumber(v) or 0
    if v <= 0 and Bridge ~= nil then v = math.floor((Bridge.time or 0) * 1000 / 60) end
    return v
end

local function bodyZ(body)
    local z = 0
    pcall(function() z = math.floor(body:getZ()) end)
    return z
end

function BridgeChores.chunkStart(base, value, size)
    size = tonumber(size) or SCAN_CHUNK
    value = tonumber(value) or base
    return base + math.floor((value - base) / size) * size
end

local function home()
    if BridgeHome == nil or type(BridgeHome.get) ~= "function" then return nil end
    local raw = BridgeHome.get()
    if type(raw) ~= "table" then return nil end
    return BridgeData.cleanHome(raw)
end

local function rectFor(h, z)
    return { x1 = h.x, y1 = h.y, x2 = h.x + h.w - 1, y2 = h.y + h.h - 1, z = z }
end

local function targetKey(t)
    if type(t) ~= "table" then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if x == nil and t.obj ~= nil then
        pcall(function()
            local sq = t.obj:getSquare()
            if sq ~= nil then x, y, z = sq:getX(), sq:getY(), sq:getZ() end
        end)
    end
    if x == nil or y == nil then return nil end
    return math.floor(x) .. ":" .. math.floor(y) .. ":" .. math.floor(z or 0)
end

local function targetPos(t)
    if type(t) ~= "table" then return nil, nil, nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if x == nil and t.obj ~= nil then
        pcall(function()
            local sq = t.obj:getSquare()
            if sq ~= nil then x, y, z = sq:getX(), sq:getY(), sq:getZ() end
        end)
    end
    if x == nil or y == nil then return nil, nil, nil end
    return math.floor(x), math.floor(y), math.floor(z or 0)
end

local function choreKind(id)
    local row = ROWS[id]
    if row == nil then return nil end
    if row.flag ~= nil and (BridgeTask == nil or BridgeTask[row.flag] ~= 1) then return nil end
    if row.dynamic ~= true then return row.kind end
    local hutch = BridgeTask ~= nil and BridgeTask.HUTCHCARE_ENABLED == 1
    local pets = BridgeTask ~= nil and BridgeTask.PET_ANIMALS_ENABLED == 1
    if hutch and pets then return "tendAnimals" end
    if hutch then return "animalCare" end
    if pets then return "petAnimals" end
    return nil
end

local function collector(kind)
    if kind == nil or BridgeWorkSelect == nil or type(BridgeWorkSelect.kinds) ~= "table" then return nil end
    local def = BridgeWorkSelect.kinds[kind]
    if type(def) ~= "table" then return nil end
    return def.collect
end

local function scanSettled()
    for i = 1, #SCAN_ROWS do
        local id = SCAN_ROWS[i]
        local kind = choreKind(id)
        if kind ~= nil and collector(kind) ~= nil then
            local sh = S.scan[id]
            if sh == nil or sh.ready ~= true then return false end
        end
    end
    return true
end

local function groupIndexMap()
    local map = {}
    if BridgeData == nil or type(BridgeData.workOrder) ~= "function" then return map end
    local order = BridgeData.workOrder(Bridge.store)
    for i = 1, #order do map[order[i]] = i end
    return map
end

local function shown(group)
    if group == nil then return true end
    if BridgeData == nil or type(BridgeData.workShown) ~= "function" then return true end
    return BridgeData.workShown(Bridge.store, group) == true
end

local function on(id)
    if BridgeData == nil or type(BridgeData.choreOn) ~= "function" then return false end
    return BridgeData.choreOn(Bridge.store, id) == true
end

local function cooldownUntil(id)
    return S.cooldown[id] or 0
end

local function retryUntil(id)
    return S.retry[id] or 0
end

local function backoff(n)
    n = math.max(1, math.floor(tonumber(n) or 1))
    local value = START_FAIL * (2 ^ (n - 1))
    if value > START_FAIL_CAP then value = START_FAIL_CAP end
    return value
end

local function startFail(id, why)
    if id == nil then return end
    local n = (S.fails[id] or 0) + 1
    S.fails[id] = n
    S.retry[id] = (Bridge.time or 0) + backoff(n)
    S.statusCache[id] = nil
    log("backoff " .. tostring(id) .. " x" .. tostring(n) .. " why=" .. tostring(why))
end

local function startOk(id)
    if id ~= nil then
        S.fails[id] = nil
        S.retry[id] = nil
        S.statusCache[id] = nil
    end
end

local function chunkPlan(h)
    local key = BridgeHome.homeKey(h) .. "|" .. tostring(BridgeHome.allFloorsOn()) .. "|" .. tostring(SCAN_CHUNK)
    if S.planKey == key then return S.plans end
    S.plans = {}
    S.planKey = key
    local floors = BridgeHome.includedFloors(h, BridgeHome.allFloorsOn())
    for i = 1, #floors do
        local z = floors[i]
        for x = h.x, h.x + h.w - 1, SCAN_CHUNK do
            for y = h.y, h.y + h.h - 1, SCAN_CHUNK do
                local x2 = math.min(h.x + h.w - 1, x + SCAN_CHUNK - 1)
                local y2 = math.min(h.y + h.h - 1, y + SCAN_CHUNK - 1)
                local key2 = x .. ":" .. y .. ":" .. z
                S.plans[key2] = { x1 = x, y1 = y, x2 = x2, y2 = y2, z = z, key = key2, at = nil, empty = false, list = {} }
            end
        end
    end
    return S.plans
end

local function scanFor(id)
    local sh = S.scan[id]
    if sh == nil then
        sh = { byKey = {}, order = {}, list = {}, ready = false }
        S.scan[id] = sh
    end
    return sh
end

local function ensureScan(id, h)
    local sh = scanFor(id)
    local plan = chunkPlan(h)
    local added = false
    for key, ch in pairs(plan) do
        if sh.byKey[key] == nil then
            local copy = { x1 = ch.x1, y1 = ch.y1, x2 = ch.x2, y2 = ch.y2, z = ch.z,
                key = ch.key, at = nil, empty = false, list = {} }
            sh.byKey[key] = copy
            sh.order[#sh.order + 1] = copy
            added = true
        end
    end
    if added then sh.ready = false end
    return sh
end

local function rebuild(id)
    local sh = S.scan[id]
    if sh == nil then return end
    local out, seen = {}, {}
    local complete = #sh.order > 0
    for i = 1, #sh.order do
        local ch = sh.order[i]
        if ch.at == nil then complete = false end
        for j = 1, #(ch.list or {}) do
            local t = ch.list[j]
            local key = targetKey(t)
            if key ~= nil and not seen[key] then
                seen[key] = true
                out[#out + 1] = t
            end
        end
    end
    sh.list = out
    sh.ready = complete
end

local function refreshHomeKey(h)
    local key = BridgeHome.homeKey(h)
    if S.homeKey ~= key then
        S.homeKey = key
        S.scan = {}
        S.plans = {}
        S.planKey = nil
        S.links = nil
        S.linkKey = nil
        S.stair = {}
        S.blacklist = {}
        S.statusCache = {}
        S.lastRow, S.lastNeed = nil, 0
        S.forceRoam = false
        S.idleAllowedAt = (Bridge.time or 0) + 2 * FLOOR
        S.scanReady = false
        S.seatReady = false
        S.seatChunks = {}
        S.seatCursor = 0
        S.seatOrder = nil
        S.seatOrderKey = nil
        S.seatDirty = {}
        S.seatNextRefresh = 0
        S.stopPending = nil
        if Bridge.target ~= nil and Bridge.mode == "home" then Bridge.target = nil end
        log("home changed " .. tostring(key))
    end
end

local function hasStair(h, z)
    local key = BridgeHome.homeKey(h) .. ":" .. tostring(z)
    local hit = S.stair[key]
    if hit ~= nil then return hit, true end
    local yes = false
    local seen = 0
    local cell = nil
    pcall(function() cell = getCell() end)
    if cell ~= nil and Bridge.onStairs ~= nil then
        for x = h.x, h.x + h.w - 1 do
            if yes then break end
            for y = h.y, h.y + h.h - 1 do
                local sq = nil
                pcall(function() sq = cell:getGridSquare(x, y, z) end)
                if sq ~= nil then
                    seen = seen + 1
                    pcall(function() yes = Bridge.onStairs(sq) == true end)
                    if yes then break end
                end
            end
        end
    end
    if seen > 0 then S.stair[key] = yes end
    return yes, seen > 0
end

local function buildLinks(h)
    local key = BridgeHome.homeKey(h) .. ":links"
    if S.linkKey == key then return S.links end
    local floors = BridgeHome.includedFloors(h, true)
    local adj = {}
    for i = 1, #floors do adj[floors[i]] = adj[floors[i]] or {} end
    local definitive = true
    for i = 1, #floors - 1 do
        local a, b = floors[i], floors[i + 1]
        if b == a + 1 then
            local sa, da = hasStair(h, a)
            local sb, db = hasStair(h, b)
            if not da or not db then definitive = false end
            if sa or sb then
                adj[a][b] = true
                adj[b][a] = true
            end
        end
    end
    S.links = adj
    if definitive then S.linkKey = key else S.linkKey = nil end
    return adj
end

local function floorReachable(h, fromZ, toZ)
    if toZ == nil then return false end
    if toZ == fromZ then return true end
    if h == nil or BridgeHome.allFloorsOn() ~= true then return false end
    local adj = buildLinks(h)
    local seen, queue = {}, { fromZ }
    seen[fromZ] = true
    local i = 1
    while i <= #queue do
        local z = queue[i]
        i = i + 1
        if z == toZ then return true end
        local nxt = adj[z]
        if nxt ~= nil then
            for nz, yes in pairs(nxt) do
                if yes and not seen[nz] then seen[nz] = true queue[#queue + 1] = nz end
            end
        end
    end
    return false
end

local function pruneBlacklist()
    local now = Bridge.time or 0
    for key, untilT in pairs(S.blacklist) do
        if type(untilT) ~= "number" or untilT <= now then S.blacklist[key] = nil end
    end
end

local function currentZ()
    if Bridge ~= nil and Bridge.body ~= nil then return bodyZ(Bridge.body) end
    local red = BridgeData ~= nil and BridgeData.owner() or nil
    if red ~= nil then return bodyZ(red) end
    return 0
end

local function filterList(id, list, h, z)
    local out = {}
    if type(list) ~= "table" then return out end
    local now = Bridge.time or 0
    local spot = nil
    local skipR = nil
    if id == "corpses" then
        spot = BridgeData ~= nil and BridgeData.corpseSpotOf(Bridge.store) or nil
        if spot == nil then return out end
        local spotSq = nil
        pcall(function() spotSq = getCell():getGridSquare(spot.x, spot.y, spot.z) end)
        if spotSq == nil then return out end
        local search = 3
        if BridgeTask ~= nil and tonumber(BridgeTask.CORPSE_DROP_SEARCH) ~= nil then
            search = tonumber(BridgeTask.CORPSE_DROP_SEARCH)
        end
        skipR = search + 1
    end
    for i = 1, #list do
        local t = list[i]
        local x, y, tz = targetPos(t)
        if x ~= nil then
            local key = x .. ":" .. y .. ":" .. tz
            local untilT = S.blacklist[key]
            local nearSpot = false
            if spot ~= nil and tz == spot.z then
                local dx = x - spot.x
                local dy = y - spot.y
                if dx * dx + dy * dy <= skipR * skipR then nearSpot = true end
            end
            if not nearSpot and (untilT == nil or untilT <= now)
                    and BridgeHome.contains(x, y, tz) and floorReachable(h, z, tz) then
                out[#out + 1] = t
            end
        end
    end
    return out
end

local function distanceTo(body, t)
    local x, y, tz = targetPos(t)
    if x == nil then return 9999 end
    local dz = math.abs((body:getZ() or 0) - (tz or 0))
    local dx = (body:getX() or 0) - (x + 0.5)
    local dy = (body:getY() or 0) - (y + 0.5)
    return math.sqrt(dx * dx + dy * dy) + dz * 40
end

local function compareCands(a, b)
    if a.group ~= b.group then return a.group < b.group end
    if a.weight ~= b.weight then return a.weight > b.weight end
    if a.need ~= b.need then return a.need > b.need end
    if a.same ~= b.same then return a.same end
    return a.dist < b.dist
end

local function candidates(body)
    local h = home()
    if h == nil then return {} end
    local z = bodyZ(body)
    local groups = groupIndexMap()
    local out = {}
    for i = 1, #BridgeData.CHORE_IDS do
        local id = BridgeData.CHORE_IDS[i]
        local row = ROWS[id]
        if row ~= nil and row.idle ~= true and on(id) and shown(row.group) then
            local doorRow = (id == "closeDoors" or id == "closeWindows")
            local kind = choreKind(id)
            local sh = S.scan[id]
            if kind ~= nil and (doorRow or (sh ~= nil and sh.ready == true))
                    and (Bridge.time or 0) >= cooldownUntil(id)
                    and (Bridge.time or 0) >= retryUntil(id) then
                local list = nil
                if doorRow then
                    list = {}
                    if BridgeWorkSelect ~= nil then
                        local floors = nil
                        pcall(function() floors = BridgeHome.includedFloors(h, BridgeHome.allFloorsOn()) end)
                        if type(floors) ~= "table" or #floors == 0 then floors = { z } end
                        local ordered = {}
                        for _, fz in ipairs(floors) do if fz == z then ordered[#ordered + 1] = fz end end
                        for _, fz in ipairs(floors) do if fz ~= z then ordered[#ordered + 1] = fz end end
                        for _, fz in ipairs(ordered) do
                            local rect = { x1 = h.x, y1 = h.y, x2 = h.x + h.w - 1, y2 = h.y + h.h - 1, z = fz }
                            local got = nil
                            if id == "closeDoors" and type(BridgeWorkSelect.doorsIn) == "function" then
                                got = BridgeWorkSelect.doorsIn(rect, "close")
                            elseif id == "closeWindows" and type(BridgeWorkSelect.windowsIn) == "function" then
                                got = BridgeWorkSelect.windowsIn(rect, "close")
                            end
                            if got ~= nil and #got > 0 then list = got break end
                        end
                    end
                else
                    list = filterList(id, sh.list, h, z)
                end
                if doorRow and #list > 1 then
                    local bx, by = body:getX(), body:getY()
                    table.sort(list, function(a, b)
                        local ax, ay, az = targetPos(a)
                        local bx2, by2, bz2 = targetPos(b)
                        local af = az == z
                        local bf = bz2 == z
                        if af ~= bf then return af end
                        local ad = (ax - bx) ^ 2 + (ay - by) ^ 2
                        local bd = (bx2 - bx) ^ 2 + (by2 - by) ^ 2
                        return ad < bd
                    end)
                end
                if #list > 0 then
                    local dest = nil
                    if id == "corpses" then
                        dest = BridgeData.corpseSpotOf(Bridge.store)
                        local cap = 40
                        if BridgeWorkSelect ~= nil and tonumber(BridgeWorkSelect.MAX_CORPSES) ~= nil then
                            cap = tonumber(BridgeWorkSelect.MAX_CORPSES)
                        end
                        if #list > cap then
                            local trimmed = {}
                            for j = 1, cap do trimmed[j] = list[j] end
                            list = trimmed
                        end
                    end
                    local same, best = false, nil
                    for j = 1, #list do
                        local _, _, tz = targetPos(list[j])
                        if tz == z then same = true end
                        local d = distanceTo(body, list[j])
                        if best == nil or d < best then best = d end
                    end
                    out[#out + 1] = {
                        row = id, kind = kind, list = list, need = #list,
                        group = groups[row.group] or 99, weight = row.weight or 1,
                        same = same, dist = best or 9999, dest = dest,
                    }
                end
            end
        end
    end
    table.sort(out, compareCands)
    if #out > 1 and S.lastRow ~= nil and out[1].row == S.lastRow
            and out[1].need <= (S.lastNeed or 0) then
        for i = 2, #out do
            if out[i].need > 0 then
                table.remove(out, 1)
                break
            end
        end
    end
    return out
end

local function insideHome(body, margin)
    local x, y, z = body:getX(), body:getY(), body:getZ()
    if x == nil then return false end
    return BridgeHome.contains(x, y, z, margin or 0)
end

local function returnToAnchor(body)
    if BridgeHome == nil or type(BridgeHome.anchor) ~= "function" then return end
    local ax, ay, az = BridgeHome.anchor(bodyZ(body))
    if ax == nil then return end
    if BridgeTask ~= nil and BridgeTask.active ~= true then
        local res = BridgeTask.start("roam", { { x = ax, y = ay, z = az } })
        if res == "started" then
            S.running = { row = "roam", kind = "roam", idle = true, startedAt = Bridge.time,
                done0 = BridgeTask.doneCount or 0, need = 1, changedAt = Bridge.time, sig = nil,
                jobId = BridgeTask.jobId }
            S.nextIdleAt = 0
            return
        end
    end
    local ct = BridgeRoute.state.target
    if ct == nil or math.abs((ct.x or -9999) - ax) > 0.6
            or math.abs((ct.y or -9999) - ay) > 0.6 then
        local target = { x = ax, y = ay, z = az }
        local spec = { owner = "chore", body = body, target = target, reach = 0.7, onTarget = false }
        local st = BridgeRoute.request(spec)
        if st == "walking" then
            BridgeRoute.state.spec = spec
            Bridge.targetSince = Bridge.time
        end
    end
end

local function kindOfTarget(t)
    local x, y, z = targetPos(t)
    if x == nil then return nil end
    return x .. ":" .. y .. ":" .. z
end

local function markDirty(rowId, targets)
    local sh = S.scan[rowId]
    if sh == nil or type(targets) ~= "table" then return end
    local h = home()
    if h == nil then return end
    for i = 1, #targets do
        local x, y, z = targetPos(targets[i])
        if x ~= nil then
            local cx = BridgeChores.chunkStart(h.x, x, SCAN_CHUNK)
            local cy = BridgeChores.chunkStart(h.y, y, SCAN_CHUNK)
            local key = cx .. ":" .. cy .. ":" .. z
            local ch = sh.byKey[key]
            if ch ~= nil then ch.at = nil end
        end
    end
    sh.ready = false
end

local function blacklistFailed()
    local failed = BridgeTask ~= nil and BridgeTask.lastFailedTarget or nil
    if type(failed) == "table" and failed.x ~= nil and failed.y ~= nil then
        local key = math.floor(failed.x) .. ":" .. math.floor(failed.y) .. ":" .. math.floor(failed.z or 0)
        if failed.reason == nil then
            log("blacklist skip " .. key .. " reason=nil")
        else
            S.blacklist[key] = (Bridge.time or 0) + BLACKLIST
            log("blacklist " .. key .. " reason=" .. tostring(failed.reason))
        end
    end
    if BridgeTask ~= nil then BridgeTask.lastFailedTarget = nil end
end

local function finishIdleRow(id, ok)
    S.running = nil
    if ok == true then
        startOk(id)
        local row = ROWS[id]
        if row ~= nil and row.cooldownH ~= nil then
            S.cooldown[id] = (Bridge.time or 0) + row.cooldownH * 3600 * FLOOR
        end
        S.lastRow, S.lastNeed = id, 0
        blacklistFailed()
    else
        startFail(id, "idle")
    end
    S.nextDecisionAt = (Bridge.time or 0) + DECISION_GAP
    S.nextIdleAt = (Bridge.time or 0) + IDLE_GAP
end

local function finishJobRow()
    local r = S.running
    S.running = nil
    if r == nil then return end
    local done = (BridgeTask.doneCount or 0) - (r.done0 or 0)
    local fail = BridgeTask.failCount or 0
    local succeeded = done > 0
    if r.idle == true and fail == 0 and not (r.row == "deposit" and done <= 0) then succeeded = true end
    if succeeded then
        startOk(r.row)
        local row = ROWS[r.row]
        if row ~= nil and row.cooldownH ~= nil then
            S.cooldown[r.row] = (Bridge.time or 0) + row.cooldownH * 3600 * FLOOR
        end
        S.lastRow, S.lastNeed = r.row, r.need or 0
    else
        startFail(r.row, "job")
        if fail == 0 then S.retry[r.row] = (Bridge.time or 0) + START_FAIL end
    end
    if r.idle == true then
        if r.row == "roam" then
            S.nextIdleAt = (Bridge.time or 0) + ROAM_DWELL
        else
            S.nextIdleAt = (Bridge.time or 0) + IDLE_GAP
        end
    end
    log("job end row=" .. tostring(r.row) .. " id=" .. tostring(r.jobId or "-")
        .. " done=" .. tostring(done) .. " fail=" .. tostring(fail)
        .. " blocked=" .. tostring(BridgeTask.blockedReason))
    blacklistFailed()
    if type(r.targets) == "table" then markDirty(r.row, r.targets) end
    S.nextDecisionAt = (Bridge.time or 0) + DECISION_GAP
end

local function activitySignature(body)
    local current = BridgeTask.current
    local key = "nil"
    if type(current) == "table" then
        key = targetKey(current) or tostring(current)
    end
    local prog = nil
    pcall(function() prog = BridgeTask.progress() end)
    local moving = false
    pcall(function()
        moving = BridgeMove ~= nil and (BridgeMove.pathing == true or BridgeMove.moving == true
            or BridgeMove.steering == true or BridgeMove.redMoving == true)
    end)
    return table.concat({
        key, tostring(BridgeTask.doneCount or 0), tostring(BridgeTask.failCount or 0),
        tostring(BridgeTask.phase), tostring(BridgeTask.info),
        tostring(prog ~= nil and math.floor(prog * 20) or -1), tostring(moving),
    }, "|")
end

local function watch(body)
    if S.waiting ~= nil then
        if BridgeTask.active == true then
            local w = S.waiting
            S.waiting = nil
            S.running = {
                row = w.row, kind = BridgeTask.kind or w.kind, idle = w.idle == true,
                startedAt = Bridge.time, done0 = BridgeTask.doneCount or 0,
                need = w.need or 0, targets = w.targets, sig = nil, changedAt = Bridge.time,
                jobId = BridgeTask.jobId,
            }
            return true
        end
        if BridgeTask.pendingStart == nil then
            local w = S.waiting
            S.waiting = nil
            startFail(w.row, "fetch")
            S.nextDecisionAt = (Bridge.time or 0) + DECISION_GAP
            return false
        end
        return true
    end

    local r = S.running
    if r == nil then return false end

    if r.idle == true and r.row == "wash" then
        if BridgeWash == nil or BridgeWash.state == "idle" then
            local info = BridgeWash ~= nil and tostring(BridgeWash.info or "") or ""
            S.running = nil
            if string.sub(info, 1, 4) == "done" then
                finishIdleRow("wash", true)
            elseif info == "stopped: zombie" then
                S.nextDecisionAt = (Bridge.time or 0) + DECISION_GAP
                S.nextIdleAt = (Bridge.time or 0) + IDLE_GAP
                log("wash stopped by zombie")
            else
                finishIdleRow("wash", false)
            end
            return false
        end
        if (Bridge.time or 0) - (r.changedAt or Bridge.time) > STUCK * 2 then
            pcall(function() BridgeWash.stop("chores-stuck") end)
            finishIdleRow("wash", false)
            return false
        end
        r.changedAt = Bridge.time
        return true
    end

    if BridgeTask.active ~= true then
        finishJobRow()
        return false
    end

    if r.row == "sit" and BridgeTask.kind == "sit" and BridgeTask.phase == "sit"
            and (Bridge.time or 0) - (r.startedAt or Bridge.time) >= SIT_DWELL then
        BridgeTask.sitUp = true
    end

    local sig = activitySignature(body)
    if r.sig ~= sig then
        r.sig = sig
        r.changedAt = Bridge.time
    elseif r.row ~= "roam" and (Bridge.time or 0) - (r.changedAt or Bridge.time) > STUCK then
        log("stuck " .. tostring(r.row) .. " " .. tostring(BridgeTask.info))
        pcall(function() BridgeTask.cancel("chores-stuck") end)
        if Bridge.mode ~= "home" and Bridge.setMode ~= nil then Bridge.setMode("home") end
        S.running = nil
        startFail(r.row, "stuck")
        S.nextDecisionAt = (Bridge.time or 0) + DECISION_GAP
        return false
    end
    return true
end

local function scanIsComplete()
    for i = 1, #SCAN_ROWS do
        local id = SCAN_ROWS[i]
        local kind = choreKind(id)
        if kind ~= nil and collector(kind) ~= nil then
            local sh = S.scan[id]
            if sh == nil or sh.ready ~= true then return false end
        end
    end
    return true
end

local function scanStep(body)
    local h = home()
    if h == nil then return end
    local z = bodyZ(body)
    local _, _, anchorZ = BridgeHome.anchor(z)
    local allowOther = (S.scanCount % 4) == 3
    local start = nowMs()
    local n = #SCAN_ROWS
    local function normalFloor(fz)
        return fz == z or (anchorZ ~= nil and fz == anchorZ)
    end
    for step = 1, n do
        local idx = ((S.scanRow + step - 1) % n) + 1
        local id = SCAN_ROWS[idx]
        local doorsRow = (id == "closeDoors" or id == "closeWindows")
        local kind = choreKind(id)
        local collect = collector(kind)
        if collect ~= nil then
            local sh = ensureScan(id, h)
            local due = nil
            for i = 1, #sh.order do
                local ch = sh.order[i]
                if doorsRow or ch.z == z or normalFloor(ch.z) or allowOther then
                    local ttl = ch.empty and (doorsRow and TTL_DOOR_EMPTY_MS or TTL_EMPTY_MS) or TTL_OCCUPIED_MS
                    if ch.at == nil or (start - ch.at) >= ttl then due = ch break end
                end
            end
            if due == nil then
                for i = 1, #sh.order do
                    local ch = sh.order[i]
                    local ttl = ch.empty and (doorsRow and TTL_DOOR_EMPTY_MS or TTL_EMPTY_MS) or TTL_OCCUPIED_MS
                    if ch.at == nil or (start - ch.at) >= ttl then due = ch break end
                end
            end
            if due ~= nil then
                S.scanRow = idx
                S.scanCount = S.scanCount + 1
                local list = {}
                local rect = { x1 = due.x1, y1 = due.y1, x2 = due.x2, y2 = due.y2, z = due.z }
                local ok, got = pcall(function() return collect(rect) or {} end)
                if ok then
                    list = got
                else
                    log("scan error " .. tostring(kind) .. ": " .. tostring(got))
                end
                due.list = list
                due.empty = #list == 0
                due.at = nowMs()
                rebuild(id)
                if scanIsComplete() then S.scanReady = true end
                return
            end
        end
    end
end

local function collectSeatChunk(ch)
    local cell = nil
    pcall(function() cell = getCell() end)
    if cell == nil or BridgeTask == nil or type(BridgeTask.seatIsSeat) ~= "function" then return end
    local list = {}
    for x = ch.x1, ch.x2 do
        for y = ch.y1, ch.y2 do
            local sq = nil
            pcall(function() sq = cell:getGridSquare(x, y, ch.z) end)
            if sq ~= nil then
                local objects = nil
                pcall(function() objects = sq:getObjects() end)
                if objects ~= nil then
                    for i = 0, objects:size() - 1 do
                        local o = objects:get(i)
                        local isSeat = false
                        pcall(function() isSeat = BridgeTask.seatIsSeat(o) == true end)
                        if isSeat then
                            local room = nil
                            pcall(function()
                                if BridgeDoors ~= nil and BridgeDoors.enclosureKey ~= nil then
                                    room = BridgeDoors.enclosureKey(sq)
                                end
                            end)
                            list[#list + 1] = { obj = o, x = x, y = y, z = ch.z, room = room }
                        end
                    end
                end
            end
        end
    end
    S.seatChunks[ch.key] = { list = list, at = nowMs() }
    S.seatDirty[ch.key] = nil
end

local function seatScanStep(h)
    if h == nil then return end
    local plan = chunkPlan(h)
    if S.seatOrderKey ~= S.planKey then
        S.seatOrder = {}
        for key in pairs(plan) do S.seatOrder[#S.seatOrder + 1] = key end
        table.sort(S.seatOrder)
        S.seatOrderKey = S.planKey
        S.seatCursor = 0
        S.seatReady = false
        S.seatDirty = {}
        S.seatNextRefresh = 0
    end
    local order = S.seatOrder or {}
    if #order == 0 then S.seatReady = false return end
    local now = nowMs()
    if S.seatReady then
        if now >= (S.seatNextRefresh or 0) then
            S.seatReady = false
            S.seatCursor = 0
            S.seatChunks = {}
            S.seatDirty = {}
            S.seatNextRefresh = now + 120000
        else
            local dirtyKey = nil
            for key in pairs(S.seatDirty) do dirtyKey = key break end
            if dirtyKey == nil then return end
            local ch = plan[dirtyKey]
            if ch ~= nil then collectSeatChunk(ch) end
            S.seatDirty[dirtyKey] = nil
            return
        end
    end
    S.seatCursor = (S.seatCursor % #order) + 1
    local ch = plan[order[S.seatCursor]]
    if ch ~= nil then collectSeatChunk(ch) end
    local ready = true
    for i = 1, #order do
        if S.seatChunks[order[i]] == nil then ready = false break end
    end
    S.seatReady = ready
    if ready then S.seatNextRefresh = now + 120000 end
end

local function seatTargets(body, h)
    local z = bodyZ(body)
    local key = BridgeHome.homeKey(h) .. ":" .. math.floor(body:getX()) .. ":" .. math.floor(body:getY()) .. ":" .. z
    local now = nowMs()
    local t0 = now
    local scanCalls = 0
    if not S.seatReady then
        local guard = 0
        while not S.seatReady and guard < 256 do
            seatScanStep(h)
            scanCalls = scanCalls + 1
            guard = guard + 1
        end
        if S.seatReady then S.seatKey = nil end
    end
    local chunkCount = 0
    for _ in pairs(S.seatChunks) do chunkCount = chunkCount + 1 end
    log(string.format("seat scan ready=%s chunks=%d calls=%d ms=%d",
        tostring(S.seatReady), chunkCount, scanCalls, nowMs() - t0))
    if S.seatKey == key and (now - (S.seatAt or 0)) < 10000 and S.seatList ~= nil then
        log("seat cache hit n=" .. tostring(#S.seatList))
        return S.seatList
    end
    local out = {}
    S.seatKey, S.seatAt, S.seatList = key, now, out
    if not S.seatReady or BridgeTask == nil or type(BridgeTask.seatIsSeat) ~= "function" then
        log("seat scan unavailable ready=" .. tostring(S.seatReady))
        S.seatKey, S.seatAt = nil, 0
        return out
    end
    local bodyKey = nil
    pcall(function()
        local bs = body:getCurrentSquare()
        if bs ~= nil and BridgeDoors ~= nil and BridgeDoors.enclosureKey ~= nil then
            bodyKey = BridgeDoors.enclosureKey(bs)
        end
    end)
    local cands = {}
    local function addFloor(fz)
        for _, chunk in pairs(S.seatChunks) do
            local list = chunk.list or {}
            for i = 1, #list do
                local c = list[i]
                if c.z == fz and BridgeHome.contains(c.x, c.y, c.z) then
                    local same = bodyKey ~= nil and c.room ~= nil and c.room == bodyKey
                    cands[#cands + 1] = { obj = c.obj, x = c.x, y = c.y, z = c.z,
                        read = true, same = same, seat = c, d = distanceTo(body, c) }
                end
            end
        end
    end
    addFloor(z)
    if #cands == 0 and BridgeHome.allFloorsOn() then
        local floors = BridgeHome.includedFloors(h, true)
        for i = 1, #floors do
            local fz = floors[i]
            if fz ~= z and floorReachable(h, z, fz) then addFloor(fz) end
        end
    end
    if #cands == 0 then
        log("seat cands=0 home filter")
        S.seatKey, S.seatAt = nil, 0
        return out
    end
    log("seat cands=" .. tostring(#cands))
    local bodySq = math.floor(body:getX()) .. ":" .. math.floor(body:getY()) .. ":" .. z
    table.sort(cands, function(a, b)
        if a.same ~= b.same then return a.same end
        return a.d < b.d
    end)
    for i = 1, #cands do
        if #out >= 4 or i > 6 then break end
        local c = cands[i]
        local rec = c.seat
        local plan = rec.plan
        local tPlan = nowMs()
        if rec.planKey ~= bodySq or rec.planAt == nil or (now - rec.planAt) >= 30000 then
            plan = nil
            BridgeTask.seatTrace = true
            pcall(function() plan = BridgeTask.seatPlan(body, c.obj) end)
            BridgeTask.seatTrace = nil
            if plan ~= nil then
                rec.plan, rec.planAt, rec.planKey = plan, now, bodySq
            else
                rec.plan, rec.planAt, rec.planKey = nil, nil, nil
            end
        end
        local taken = false
        if plan ~= nil then
            pcall(function() taken = BridgeTask.seatTaken(plan, body) == true end)
        end
        log(string.format("seat plan %d,%d -> %s taken=%s ms=%d", c.x, c.y,
            plan ~= nil and "ok" or "nil", tostring(taken), nowMs() - tPlan))
        if plan ~= nil and not taken then
            out[#out + 1] = { obj = c.obj, x = c.x, y = c.y, z = c.z, read = true }
        end
    end
    table.sort(out, function(a, b) return distanceTo(body, a) < distanceTo(body, b) end)
    S.seatList = out
    if #out == 0 then S.seatKey, S.seatAt = nil, 0 end
    log(string.format("seat out=%d totalMs=%d", #out, nowMs() - t0))
    return out
end

local function showerTarget(body, h)
    if BridgeShower == nil or type(BridgeShower.findNearest) ~= "function" then
        log("shower search result=nil reason=BridgeShower missing")
        return nil
    end
    local z = bodyZ(body)
    local key = BridgeHome.homeKey(h) .. ":" .. tostring(z)
    local now = nowMs()
    if S.showerKey == key and (now - (S.showerAt or 0)) < 30000 then
        log(string.format("shower cache z=%d found=%s", z, tostring(S.showerObj ~= nil)))
        return S.showerObj, S.showerSq
    end
    S.showerKey, S.showerAt, S.showerObj, S.showerSq = key, now, nil, nil
    local ok = false
    pcall(function() ok = BridgeShower.isTabas() == true end)
    if not ok then
        log(string.format("shower search z=%d result=nil reason=no tabas", z))
        return nil
    end
    local all = BridgeHome.allFloorsOn()
    local floors = BridgeHome.includedFloors(h, all)
    log(string.format("shower search z=%d tabas=%s all=%s floors=%s range=%s..%s rect=%d,%d..%d,%d",
        z, tostring(ok), tostring(all), table.concat(floors, ","),
        tostring(h.z1), tostring(h.z2), h.x, h.y, h.x + h.w - 1, h.y + h.h - 1))
    for i = 1, #floors do
        local fz = floors[i]
        if fz ~= z then
            log(string.format("shower floor fz=%d reach=%s stairFrom=%s stairTo=%s",
                fz, tostring(floorReachable(h, z, fz)), tostring(hasStair(h, z)), tostring(hasStair(h, fz))))
        end
    end
    for pass = 1, 2 do
        for i = 1, #floors do
            local fz = floors[i]
            if (pass == 1 and fz == z) or (pass == 2 and fz ~= z and floorReachable(h, z, fz)) then
                local obj, sq = BridgeShower.findNearest(nil, nil, rectFor(h, fz))
                local at = "-"
                if sq ~= nil then at = tostring(sq:getX()) .. "," .. tostring(sq:getY()) end
                log(string.format("shower scan pass=%d fz=%d found=%s at=%s",
                    pass, fz, tostring(obj ~= nil), at))
                if obj ~= nil then
                    S.showerObj, S.showerSq = obj, sq
                    return obj, sq
                end
            end
        end
    end
    log("shower search result=nil reason=no fixture on eligible floors")
    return nil
end

local function pickRoam(body, h)
    local cell = nil
    pcall(function() cell = getCell() end)
    if cell == nil then return nil end
    local z = bodyZ(body)
    if not floorReachable(h, z, z) then return nil end
    local bx, by = body:getX(), body:getY()
    local px, py = nil, nil
    local red = BridgeData.owner()
    if red ~= nil then px, py = red:getX(), red:getY() end
    local bodyKey = nil
    pcall(function()
        local bs = body:getCurrentSquare()
        if bs ~= nil and BridgeDoors ~= nil and BridgeDoors.enclosureKey ~= nil then
            bodyKey = BridgeDoors.enclosureKey(bs)
        end
    end)
    local blockedNames = { "bath", "tub", "shower", "toilet", "sink", "bed", "chair", "table", "counter", "stove", "oven", "fridge", "freezer" }
    for attempt = 1, 30 do
        local dx = ZombRand(-12, 13)
        local dy = ZombRand(-12, 13)
        if math.abs(dx) + math.abs(dy) >= 3 then
            local x, y = math.floor(bx) + dx, math.floor(by) + dy
            if BridgeHome.contains(x, y, z) then
                local sq = nil
                pcall(function() sq = cell:getGridSquare(x, y, z) end)
                local ok = false
                pcall(function()
                    ok = sq ~= nil and sq:isFree(false) == true and sq:HasStairs() ~= true
                end)
                if ok and bodyKey ~= nil and BridgeDoors ~= nil and BridgeDoors.enclosureKey ~= nil then
                    pcall(function()
                        local sk = BridgeDoors.enclosureKey(sq)
                        if sk ~= nil and sk ~= bodyKey then ok = false end
                    end)
                end
                if ok then
                    pcall(function()
                        local objects = sq:getObjects()
                        for i = 0, objects:size() - 1 do
                            local o = objects:get(i)
                            local nm = o:getName()
                            if nm == nil then
                                pcall(function() nm = o:getSprite() and o:getSprite():getName() end)
                            end
                            nm = string.lower(tostring(nm or ""))
                            if instanceof ~= nil and instanceof(o, "IsoWindow") then ok = false break end
                            for j = 1, #blockedNames do
                                if string.find(nm, blockedNames[j], 1, true) ~= nil then ok = false break end
                            end
                            if not ok then break end
                        end
                    end)
                end
                if ok and Bridge.standSquareOk ~= nil then
                    pcall(function() ok = Bridge.standSquareOk(sq) == true end)
                end
                if ok and (px == nil or math.abs(px - (x + 0.5)) + math.abs(py - (y + 0.5)) > 1.5) then
                    local bkey = x .. ":" .. y .. ":" .. z
                    local untilT = S.blacklist[bkey]
                    if untilT == nil or untilT <= (Bridge.time or 0) then
                        return { x = x, y = y, z = z }
                    end
                end
            end
        end
    end
    return nil
end

local function invalidateRow(id)
    local sh = S.scan[id]
    if sh == nil then return end
    for i = 1, #sh.order do sh.order[i].at = nil end
    sh.ready = false
end

local function depositFull(body)
    if BridgeTask == nil or type(BridgeTask.lootDests) ~= "function" then return false end
    local dests = BridgeTask.lootDests(body)
    for i = 1, #dests do
        local left = BridgeTask.remainingCapacity(dests[i], BridgeData.owner())
        if type(left) == "number" and left > 0.001 then return false end
    end
    return true
end

local function startDeposit(body, h, now, force)
    if BridgeTask == nil or BridgeTask.DEPOSIT_ENABLED ~= 1 then return false, "disabled" end
    if BridgeDeposit == nil or type(BridgeDeposit.startHome) ~= "function" then
        return false, "unavailable"
    end
    if not on("deposit") then return false, "off" end
    if not insideHome(body, 0) then return false, "not home" end
    local marks = 0
    pcall(function() marks = BridgeDeposit.markedCount() end)
    if marks <= 0 then return false, "no marks" end
    local full = depositFull(body)
    if force ~= true then
        if not full and now < cooldownUntil("deposit") then return false, "cooldown" end
        if now < retryUntil("deposit") then return false, "backoff" end
    end
    local n = 0
    pcall(function() n = #BridgeDeposit.storableItems(body) end)
    if n <= 0 then return false, "nothing" end
    local res = BridgeDeposit.startHome({ quiet = true })
    if res == "started" then
        startOk("deposit")
        S.running = {
            row = "deposit", kind = "deposit", idle = true,
            startedAt = now, done0 = BridgeTask.doneCount or 0, need = n,
            changedAt = now, sig = nil, jobId = BridgeTask.jobId,
        }
        return true, "started"
    end
    startFail("deposit", res)
    return false, res
end

local function startRow(body, cand, h, quiet)
    local kind = cand.kind
    local res = nil
    local targets = cand.list
    if kind == "sit" then
        local seat = cand.list[1]
        targets = { { obj = seat.obj, x = seat.x, y = seat.y, z = seat.z, read = true } }
    end
    local opts = quiet == true and { quiet = true } or nil
    res = BridgeTask.start(kind, targets, cand.dest, opts)
    if res == "started" then
        startOk(cand.row)
        S.running = {
            row = cand.row, kind = kind, idle = false, startedAt = Bridge.time,
            done0 = BridgeTask.doneCount or 0, need = cand.need or 0, targets = cand.list,
            sig = nil, changedAt = Bridge.time, jobId = BridgeTask.jobId,
        }
        return true, "started"
    end
    if res == "fetching" then
        S.waiting = {
            row = cand.row, kind = kind, idle = false, since = Bridge.time,
            need = cand.need or 0, targets = cand.list,
        }
        return true, "fetching"
    end
    if res == "busy" or res == "no body" or res == "not drivable" or res == "unknown job" or res == "disabled" then
        return false, res
    end
    startFail(cand.row, res)
    invalidateRow(cand.row)
    return false, res
end

local function startIdle(id, body, h, now, force)
    if id == "wash" then
        if BridgeWash == nil or BridgeWash.dirtyParts == nil then return false, "unavailable" end
        local dirty = 0
        pcall(function() dirty = BridgeWash.dirtyParts(body, "self") end)
        if force ~= true and dirty < WASH_MIN_DIRTY then return false, "clean" end
        local res = nil
        local z0 = bodyZ(body)
        local floors = BridgeHome.includedFloors(h, BridgeHome.allFloorsOn())
        if type(floors) ~= "table" or #floors == 0 then floors = { z0 } end
        local ordered = {}
        for i = 1, #floors do
            if floors[i] == z0 then ordered[#ordered + 1] = floors[i] end
        end
        for i = 1, #floors do
            if floors[i] ~= z0 then ordered[#ordered + 1] = floors[i] end
        end
        local chosen = nil
        for i = 1, #ordered do
            local r = rectFor(h, ordered[i])
            local list = {}
            pcall(function() list = BridgeWash.waterList(body, nil, nil, r) end)
            if #list > 0 then chosen = r break end
        end
        pcall(function() res = BridgeWash.start("chores", nil, nil, chosen or rectFor(h, z0), force == true) end)
        if res == "going to wash" then
            S.running = { row = "wash", idle = true, startedAt = now, changedAt = now }
            return true, "started"
        end
        startFail("wash", res)
        return false, res
    end

    if id == "shower" then
        if BridgeShower == nil then return false, "unavailable" end
        if force ~= true then
            local ready = false
            pcall(function() ready = BridgeShower.ready(Bridge.store) == true end)
            if not ready then return false, "cooldown" end
        end
        local obj, sq = showerTarget(body, h)
        if obj == nil then return false, "no shower" end
        local res = nil
        pcall(function() res = BridgeShower.start(obj, sq, force == true) end)
        if res == "started" then
            startOk("shower")
            S.running = { row = "shower", kind = "shower", idle = true, startedAt = now,
                done0 = BridgeTask.doneCount or 0, need = 0, changedAt = now, sig = nil,
                jobId = BridgeTask.jobId }
            return true, "started"
        end
        startFail("shower", res)
        return false, res
    end

    if id == "exercise" then
        if BridgeExercise == nil then return false, "unavailable" end
        if force ~= true then
            local ready = false
            pcall(function() ready = BridgeExercise.ready(Bridge.store) == true end)
            if not ready then return false, "cooldown" end
        end
        local res = nil
        pcall(function() res = BridgeExercise.start(false, force == true) end)
        if res == "started" then
            startOk("exercise")
            S.running = { row = "exercise", kind = "exercise", idle = true, startedAt = now,
                done0 = BridgeTask.doneCount or 0, need = 0, changedAt = now, sig = nil,
                jobId = BridgeTask.jobId }
            return true, "started"
        end
        startFail("exercise", res)
        return false, res
    end

    if id == "sit" then
        if BridgeTask ~= nil and BridgeTask.isSeated ~= nil and BridgeTask.isSeated(body) == true then
            return false, "seated"
        end
        local seats = seatTargets(body, h)
        if #seats == 0 then return false, "no seat" end
        local first = 1
        if force ~= true and #seats > 1 then
            local firstKey = seats[1].x .. ":" .. seats[1].y .. ":" .. seats[1].z
            if S.lastSeat == firstKey then first = 2 end
        end
        local order = {}
        order[1] = seats[first]
        for i = 1, #seats do
            if i ~= first then order[#order + 1] = seats[i] end
        end
        local targets = {}
        for i = 1, #order do
            local s = order[i]
            targets[i] = { obj = s.obj, x = s.x, y = s.y, z = s.z, read = true }
        end
        log(string.format("sit choose force=%s last=%s first=%d,%d n=%d",
            tostring(force == true), tostring(S.lastSeat),
            order[1].x, order[1].y, #order))
        local res = nil
        pcall(function()
            res = BridgeTask.start("sit", targets)
        end)
        if res == "started" then
            startOk("sit")
            S.running = { row = "sit", kind = "sit", idle = true, startedAt = now,
                done0 = BridgeTask.doneCount or 0, need = 1, targets = order, changedAt = now, sig = nil,
                jobId = BridgeTask.jobId }
            return true, "started"
        end
        startFail("sit", res)
        return false, res
    end

    if id == "roam" then
        local spot = pickRoam(body, h)
        if spot == nil then return false, "no spot" end
        local res = nil
        pcall(function()
            res = BridgeTask.start("roam", { { x = spot.x, y = spot.y, z = spot.z } })
        end)
        if res == "started" then
            S.running = { row = "roam", kind = "roam", idle = true, startedAt = now,
                done0 = BridgeTask.doneCount or 0, need = 1, changedAt = now, sig = nil,
                jobId = BridgeTask.jobId }
            return true, "started"
        end
        startFail("roam", res)
        return false, res
    end

    return false, "unknown"
end

local function idleTargets(body, h)
    local now = Bridge.time or 0
    if now < (S.idleAllowedAt or 0) then return end
    if now < (S.nextIdleAt or 0) then return end
    if S.forceRoam ~= true and not S.scanReady then return end

    if S.forceRoam then
        if on("roam") then
            local ok = startIdle("roam", body, h, now)
            if ok then return end
        end
        S.forceRoam = false
    end

    local order = { "wash", "shower", "exercise", "sit", "roam" }
    for i = 1, #order do
        local id = order[i]
        local allowed = not (id == "sit" and S.seatReady ~= true)
        if allowed and on(id) and now >= cooldownUntil(id) and now >= retryUntil(id) then
            local started = startIdle(id, body, h, now)
            if started then return end
        end
    end
    S.nextIdleAt = now + IDLE_GAP
end

local function threat(body)
    if BridgeTask == nil or BridgeTask.dangerNear == nil then return false end
    local tick = Bridge.tick or 0
    if tick >= (S.dangerTick or 0) + 6 then
        S.dangerTick = tick
        local danger = false
        pcall(function() danger = BridgeTask.dangerNear(body) == true end)
        S.danger = danger
    end
    return S.danger == true
end

local function breakIdle(body)
    local broke = S.running ~= nil or S.waiting ~= nil
    S.forceRoam = false
    local r = S.running
    if r ~= nil then
        if r.row == "wash" then
            pcall(function() if BridgeWash ~= nil then BridgeWash.stop("danger") end end)
        elseif BridgeTask ~= nil and BridgeTask.active == true then
            pcall(function() BridgeTask.cancel("danger") end)
        end
        S.running = nil
    end
    if S.waiting ~= nil then
        if BridgeTask ~= nil and BridgeTask.pendingStart ~= nil
                and BridgeTask.pendingStart.kind == S.waiting.kind then
            BridgeTask.pendingStart = nil
        end
        if BridgeTask ~= nil and BridgeTask.active == true then
            pcall(function() BridgeTask.cancel("danger") end)
        end
        S.waiting = nil
    end
    if broke then
        S.nextDecisionAt = (Bridge.time or 0) + DECISION_GAP
        log("idle broken by danger")
    end
end

local function eligible(body)
    if BridgeTask == nil or BridgeTask.dangerNear == nil then return false end
    if Bridge.drivable ~= nil and Bridge.drivable() ~= true then return false end
    if BridgeWash ~= nil and BridgeWash.state ~= nil and BridgeWash.state ~= "idle" then return false end
    if BridgeHeal ~= nil and BridgeHeal.active == true then return false end
    if BridgeCar ~= nil and BridgeCar.state ~= nil and BridgeCar.state ~= "idle" then return false end
    if BridgeFight ~= nil and (BridgeFight.target ~= nil or (BridgeFight.state or "idle") ~= "idle") then return false end
    if Bridge.sleepParked ~= nil then return false end
    if S.danger then return false end
    return true
end

local function stairSettle(body)
    local z = bodyZ(body)
    if S.lastZ == nil or z ~= S.lastZ then
        S.lastZ, S.lastZAt = z, Bridge.time
    end
    if (Bridge.time or 0) - (S.lastZAt or 0) < 1 * FLOOR then return true end
    local sq = nil
    pcall(function() sq = body:getCurrentSquare() end)
    if sq ~= nil and Bridge.onStairs ~= nil then
        local on = false
        pcall(function() on = Bridge.onStairs(sq) == true end)
        if on then return true end
    end
    return false
end

local function playerBusy(red)
    if red == nil then return false end
    local busy = false
    if ISTimedActionQueue ~= nil and ISTimedActionQueue.getTimedActionQueue ~= nil then
        pcall(function()
            local q = ISTimedActionQueue.getTimedActionQueue(red)
            if q ~= nil and q.queue ~= nil then
                for i = 1, #q.queue do
                    local action = q.queue[i]
                    local kind = tostring(action ~= nil and (action.Type or action.TypeName) or "")
                    if string.find(kind, "InventoryTransfer", 1, true) ~= nil
                            or string.find(kind, "Equip", 1, true) ~= nil
                            or string.find(kind, "Unequip", 1, true) ~= nil then
                        busy = true
                        break
                    end
                end
            end
        end)
    end
    return busy
end

local function pauseForPlayer(now)
    local r = S.running
    local w = S.waiting
    if r ~= nil then
        if r.row == "wash" then
            pcall(function() if BridgeWash ~= nil then BridgeWash.stop("playerBusy") end end)
        elseif BridgeTask ~= nil and BridgeTask.active == true then
            pcall(function() BridgeTask.cancel("playerBusy") end)
        end
    end
    if w ~= nil then
        if BridgeTask ~= nil and BridgeTask.pendingStart ~= nil
                and BridgeTask.pendingStart.kind == w.kind then
            BridgeTask.pendingStart = nil
        end
        if BridgeTask ~= nil and BridgeTask.active == true then
            pcall(function() BridgeTask.cancel("playerBusy") end)
        end
    end
    S.running, S.waiting = nil, nil
    if Bridge.target ~= nil then Bridge.target = nil end
    S.nextDecisionAt = now + 5 * FLOOR
    S.nextIdleAt = now + 5 * FLOOR
    if r ~= nil or w ~= nil then log("paused for player action") end
end

local function cancelRunning(reason, now)
    local r = S.running
    if r ~= nil then
        if r.row == "wash" then
            pcall(function() if BridgeWash ~= nil then BridgeWash.stop(reason) end end)
        elseif BridgeTask ~= nil and BridgeTask.active == true then
            pcall(function() BridgeTask.cancel(reason) end)
        end
        if r.row == "roam" then S.forceRoam = false end
    end
    S.running, S.waiting = nil, nil
    S.stopPending = nil
    S.nextDecisionAt = now + DECISION_GAP
    S.nextIdleAt = now + IDLE_GAP
end

local function checkToggleStop(now)
    if S.waiting ~= nil and not on(S.waiting.row) then
        if BridgeTask ~= nil and BridgeTask.pendingStart ~= nil
                and BridgeTask.pendingStart.kind == S.waiting.kind then
            BridgeTask.pendingStart = nil
        end
        S.waiting = nil
        S.nextDecisionAt = now + DECISION_GAP
        return true
    end
    local r = S.running
    if r == nil then S.stopPending = nil return false end
    local row = ROWS[r.row]
    if row ~= nil and row.idle == true then
        if (r.row == "sit" or r.row == "roam") and not on(r.row) then
            cancelRunning("toggleOff", now)
            return true
        end
        return false
    end
    if on(r.row) then
        S.stopPending = nil
        return false
    end
    if S.stopPending == nil or S.stopPending.row ~= r.row then
        S.stopPending = { row = r.row, done = BridgeTask.doneCount or 0,
            key = targetKey(BridgeTask.current) }
        return false
    end
    local done = BridgeTask.doneCount or 0
    local cur = targetKey(BridgeTask.current)
    if done > (S.stopPending.done or 0)
            or (cur ~= nil and S.stopPending.key ~= nil and cur ~= S.stopPending.key) then
        cancelRunning("toggleOff", now)
        return true
    end
    return false
end

function BridgeChores.tick(body)
    if Bridge == nil or BridgeData == nil or Bridge.store == nil or body == nil then return end
    if Bridge.mode ~= "home" then
        if S.waiting ~= nil and BridgeTask ~= nil and BridgeTask.pendingStart ~= nil
                and BridgeTask.pendingStart.kind == S.waiting.kind then
            BridgeTask.pendingStart = nil
        end
        if S.running ~= nil or S.waiting ~= nil then
            S.running, S.waiting = nil, nil
            S.forceRoam = false
            S.stopPending = nil
        end
        S.armed = false
        return
    end
    local h = home()
    if h == nil or BridgeHome == nil or type(BridgeHome.anchor) ~= "function" then
        if S.waiting ~= nil and BridgeTask ~= nil and BridgeTask.pendingStart ~= nil
                and BridgeTask.pendingStart.kind == S.waiting.kind then
            BridgeTask.pendingStart = nil
        end
        if Bridge.setMode ~= nil then Bridge.setMode("wait") end
        S.running, S.waiting = nil, nil
        S.forceRoam = false
        return
    end
    local ax = BridgeHome.anchor(bodyZ(body))
    if ax == nil then
        if S.waiting ~= nil and BridgeTask ~= nil and BridgeTask.pendingStart ~= nil
                and BridgeTask.pendingStart.kind == S.waiting.kind then
            BridgeTask.pendingStart = nil
        end
        if Bridge.setMode ~= nil then Bridge.setMode("wait") end
        S.running, S.waiting = nil, nil
        S.forceRoam = false
        return
    end
    if not S.armed then return end
    local red = BridgeData.owner()
    if red ~= nil then
        local now = Bridge.time or 0
        if playerBusy(red) then S.playerBusyUntil = now + 4 * FLOOR end
        if now < (S.playerBusyUntil or 0) then
            pauseForPlayer(now)
            return
        end
    end
    refreshHomeKey(h)
    pruneBlacklist()

    if threat(body) then
        breakIdle(body)
        return
    end

    local tickNow = Bridge.tick or 0
    if BridgeMove ~= nil and tickNow >= (S.closeAt or 0) + 10 then
        S.closeAt = tickNow
        pcall(function() BridgeMove.rememberDoorNear(body) end)
        pcall(function() BridgeMove.closeBehind(body) end)
        pcall(function() BridgeMove.closeWindows(body) end)
    end

    local busy = false
    if S.running ~= nil or S.waiting ~= nil then busy = watch(body) end
    if busy then
        local now = Bridge.time or 0
        local stopped = checkToggleStop(now)
        if not stopped then
            local r = S.running
            if r ~= nil and (r.row == "sit" or r.row == "roam")
                    and S.forceRoam ~= true and S.scanReady then
                local cands = candidates(body)
                if #cands > 0 then
                    cancelRunning("chore", now)
                    S.nextDecisionAt = 0
                    S.nextIdleAt = 0
                    stopped = true
                end
            end
        end
        if not stopped then
            if BridgeTask.active == true and (BridgeTask.kind == "sit"
                    or (S.running ~= nil and S.running.idle == true)) then
                scanStep(body)
            end
            seatScanStep(h)
            return
        end
    end
    if BridgeTask.active == true or BridgeTask.pendingStart ~= nil then
        if BridgeTask.active == true and BridgeTask.kind == "sit" then scanStep(body) end
        seatScanStep(h)
        return
    end
    if not eligible(body) then return end

    if stairSettle(body) then return end

    seatScanStep(h)

    if not insideHome(body, 3) then
        returnToAnchor(body)
        return
    end

    scanStep(body)
    if not S.scanReady and scanIsComplete() then S.scanReady = true end
    if BridgeLog ~= nil and BridgeLog.on() then BridgeChores.diag() end

    if S.forceRoam then
        idleTargets(body, h)
        return
    end

    local now = Bridge.time or 0
    if now < (S.nextDecisionAt or 0) then return end
    S.nextDecisionAt = now + DECISION_GAP

    local startedDeposit = startDeposit(body, h, now)
    if startedDeposit then return end

    local cands = candidates(body)
    for i = 1, #cands do
        if startRow(body, cands[i], h) then return end
    end
    idleTargets(body, h)
end

function BridgeChores.statusText()
    if Bridge.mode ~= "home" then return "chores off mode=" .. tostring(Bridge.mode) end
    local h = home()
    if h == nil then return "chores no home" end
    local parts = {}
    if S.running ~= nil then parts[#parts + 1] = "run=" .. tostring(S.running.row) end
    if S.waiting ~= nil then parts[#parts + 1] = "fetch=" .. tostring(S.waiting.row) end
    for key in pairs(S.blacklist) do parts[#parts + 1] = "bl=" .. tostring(key) end
    return "chores row=" .. tostring(S.running and S.running.row or "-")
        .. " scan=" .. tostring(S.scanCount) .. " " .. table.concat(parts, " ")
end

local function computeStatus(id)
    if id == nil or not BridgeData.CHORE_SET[id] then return tr("ChoreOff") end
    pruneBlacklist()
    local h = home()
    if h == nil then return tr("ChoreNoHome") end
    if not S.armed then return tr("ChoreOff") end
    if not on(id) then return tr("ChoreOff") end
    local row = ROWS[id]
    if row ~= nil and row.group ~= nil and not shown(row.group) then return tr("ChoreOff") end
    if id == "corpses" then
        local spot = BridgeData.corpseSpotOf(Bridge.store)
        if spot == nil then return tr("ChoreNoPile") end
        local sq = nil
        pcall(function() sq = getCell():getGridSquare(spot.x, spot.y, spot.z) end)
        if sq == nil then return tr("ChoreNoPile") end
    end
    if S.running ~= nil and S.running.row == id then return tr("ChoreRunning") end
    local now = Bridge.time or 0
    if now < cooldownUntil(id) then
        return tr("ChoreCooldown", string.format("%.1f", (cooldownUntil(id) - now) / (3600 * FLOOR)))
    end
    if now < retryUntil(id) then
        return tr("ChoreCooldown", string.format("%.1f", (retryUntil(id) - now) / (3600 * FLOOR)))
    end
    if id == "deposit" then
        local marks = 0
        if BridgeDeposit ~= nil and type(BridgeDeposit.markedCount) == "function" then
            pcall(function() marks = BridgeDeposit.markedCount() end)
        end
        if marks <= 0 then return tr("ChoreNoMarked") end
        local n = 0
        if BridgeDeposit ~= nil and type(BridgeDeposit.storableItems) == "function" then
            local body = Bridge.body or BridgeData.owner()
            if body ~= nil then pcall(function() n = #BridgeDeposit.storableItems(body) end) end
        end
        if n <= 0 then return tr("ChoreNone") end
        return tr("ChoreReady", n)
    end
    if row ~= nil and row.idle == true then
        local rec = Bridge.store
        if id == "wash" then
            local dirty = 0
            local body = Bridge.body or BridgeData.owner()
            if body ~= nil and BridgeWash ~= nil and BridgeWash.dirtyParts ~= nil then
                pcall(function() dirty = BridgeWash.dirtyParts(body, "self") end)
            end
            if dirty < WASH_MIN_DIRTY then return tr("ChoreCleanSelf") end
        elseif id == "shower" then
            local tabas = false
            pcall(function() tabas = BridgeShower ~= nil and BridgeShower.isTabas() == true end)
            if not tabas then return tr("ChoreNoShower") end
            local cd = 0
            pcall(function() cd = BridgeShower.cooldownLeft(rec) end)
            if cd > 0 then return tr("ChoreCooldown", string.format("%.1f", cd)) end
        elseif id == "exercise" then
            local cd = 0
            pcall(function() cd = BridgeExercise.cooldownLeft(rec) end)
            if cd > 0 then return tr("ChoreCooldown", string.format("%.1f", cd)) end
            local tired = false
            pcall(function() tired = BridgeExercise.fatigue() > BridgeExercise.START_MAX_FATIGUE end)
            if tired then return tr("ChoreTired") end
        end
        return tr("ChoreEnabled")
    end
    local kind = choreKind(id)
    if kind == nil then return tr("ChoreOff") end
    local sh = S.scan[id]
    if sh == nil or sh.ready ~= true then return tr("ChoreScan") end
    local list = filterList(id, sh.list, h, currentZ())
    local black, blackUntil = 0, 0
    for i = 1, #sh.list do
        local key = targetKey(sh.list[i])
        if key ~= nil and S.blacklist[key] ~= nil then
            black = black + 1
            if S.blacklist[key] > blackUntil then blackUntil = S.blacklist[key] end
        end
    end
    local blackMin = string.format("%.0f", math.max(0, blackUntil - now) / (60 * FLOOR))
    if #list == 0 then
        if #sh.list > 0 and black >= #sh.list then
            return tr("ChoreUnreachable", blackMin)
        end
        if #sh.list > 0 then
            local blocked = false
            local z = currentZ()
            for i = 1, #sh.list do
                local _, _, tz = targetPos(sh.list[i])
                if tz ~= nil and tz ~= z and not floorReachable(h, z, tz) then blocked = true break end
            end
            if blocked then return tr("ChoreNoStairs") end
        end
        return tr("ChoreNone")
    end
    if black >= #sh.list then
        return tr("ChoreUnreachable", blackMin)
    end
    if BridgeFetch ~= nil and type(BridgeFetch.jobMissing) == "function" then
        local missing = nil
        pcall(function() missing = BridgeFetch.jobMissing(kind, list) end)
        if type(missing) == "table" and #missing > 0 then return tr("ChoreNoSupply") end
    end
    return tr("ChoreReady", #list)
end

function BridgeChores.status(id)
    if type(id) ~= "string" then return computeStatus(id) end
    local now = nowMs()
    local hit = S.statusCache[id]
    if hit ~= nil and (now - (hit.at or 0)) < 2000 then return hit.text end
    local text = computeStatus(id)
    S.statusCache[id] = { at = now, text = text }
    return text
end

function BridgeChores.diag()
    local now = Bridge.time or 0
    if now < (S.diagAt or 0) + 10 * FLOOR then return end
    S.diagAt = now
    local parts = { "row=" .. tostring(S.running and S.running.row or "-") }
    for i = 1, #BridgeData.CHORE_IDS do
        local id = BridgeData.CHORE_IDS[i]
        local sh = S.scan[id]
        if sh ~= nil then
            parts[#parts + 1] = string.format("%s:%s/%d", id, sh.ready and "r" or "p", #sh.list)
        end
    end
    log(table.concat(parts, " "))
end

function BridgeChores.debugLine(id)
    local row = ROWS[id]
    if row == nil then return tostring(id) .. " unknown" end
    local now = Bridge.time or 0
    local cd = math.max(0, cooldownUntil(id) - now) / (3600 * FLOOR)
    local rt = math.max(0, retryUntil(id) - now) / (3600 * FLOOR)
    local sh = S.scan[id]
    local ready, raw, filtered = "none", 0, 0
    if sh ~= nil then
        ready = sh.ready and "ready" or "partial"
        raw = #sh.list
        local h = home()
        if h ~= nil then filtered = #filterList(id, sh.list, h, currentZ()) end
    end
    local bl = 0
    if sh ~= nil then
        for i = 1, #sh.list do
            local key = targetKey(sh.list[i])
            if key ~= nil and S.blacklist[key] ~= nil then bl = bl + 1 end
        end
    end
    return string.format("%s on=%s kind=%s cd=%.1fh retry=%.1fh fails=%d scan=%s/%d targets=%d bl=%d",
        id, tostring(on(id)), tostring(choreKind(id) or "-"), cd, rt, tonumber(S.fails[id]) or 0,
        ready, raw, filtered, bl)
end

function BridgeChores.debugText()
    local out = { "running=" .. tostring(S.running and S.running.row or "-")
        .. " waiting=" .. tostring(S.waiting and S.waiting.row or "-")
        .. " danger=" .. tostring(S.danger == true)
        .. " scans=" .. tostring(S.scanCount) }
    for i = 1, #BridgeData.CHORE_IDS do out[#out + 1] = BridgeChores.debugLine(BridgeData.CHORE_IDS[i]) end
    return table.concat(out, "\n")
end

function BridgeChores.debugReset(scope)
    scope = tostring(scope or "all")
    local function clearRow(id)
        S.cooldown[id] = nil
        S.retry[id] = nil
        S.fails[id] = nil
        S.statusCache[id] = nil
    end
    if scope == "all" then
        S.cooldown = {}
        S.retry = {}
        S.fails = {}
        S.statusCache = {}
        S.nextIdleAt = 0
        S.nextDecisionAt = 0
        S.seatKey, S.seatList = nil, nil
        S.showerKey, S.showerObj, S.showerSq = nil, nil, nil
    elseif scope == "idle" then
        S.nextIdleAt = 0
        S.seatKey, S.seatList = nil, nil
        S.showerKey, S.showerObj, S.showerSq = nil, nil, nil
        for _, id in ipairs({ "wash", "shower", "exercise", "sit", "roam" }) do clearRow(id) end
    elseif BridgeData.CHORE_SET[scope] then
        clearRow(scope)
    else
        return "chores reset [all|idle|" .. table.concat(BridgeData.CHORE_IDS, "|") .. "]"
    end
    log("debug reset " .. scope)
    return "reset " .. scope
end

function BridgeChores.debugClearBlacklist()
    S.blacklist = {}
    S.statusCache = {}
    log("debug blacklist cleared")
    return "blacklist cleared"
end

function BridgeChores.debugRescan(scope)
    scope = tostring(scope or "all")
    if BridgeData.CHORE_SET[scope] then
        invalidateRow(scope)
        S.statusCache[scope] = nil
        S.seatKey, S.seatList = nil, nil
        S.showerKey, S.showerObj, S.showerSq = nil, nil, nil
        log("debug rescan " .. scope)
        return "rescan " .. scope
    end
    local keepHome = S.homeKey
    BridgeChores.invalidate()
    S.homeKey = keepHome
    S.seatKey, S.seatList = nil, nil
    S.showerKey, S.showerObj, S.showerSq = nil, nil, nil
    log("debug rescan all")
    return "rescan all"
end

function BridgeChores.debugCancel()
    local r = S.running
    local w = S.waiting
    local active = BridgeTask ~= nil and BridgeTask.active == true
    local washing = BridgeWash ~= nil and BridgeWash.state ~= nil and BridgeWash.state ~= "idle"
    local pending = BridgeTask ~= nil and BridgeTask.pendingStart ~= nil
    local activeKind = active and BridgeTask ~= nil and BridgeTask.kind or nil
    local had = r ~= nil or w ~= nil or active or washing or pending

    if washing then
        pcall(function() BridgeWash.stop("debug") end)
    end
    if active then
        pcall(function() BridgeTask.cancel("debug") end)
    end
    if BridgeTask ~= nil and BridgeTask.pendingStart ~= nil then
        BridgeTask.pendingStart = nil
    end
    local now = Bridge.time or 0
    local stopped = r ~= nil and r.row or (w ~= nil and w.row or nil)
    if stopped == nil and activeKind ~= nil then stopped = activeKind end
    if stopped == nil and washing then stopped = "wash" end
    S.running, S.waiting = nil, nil
    if Bridge.target ~= nil then Bridge.target = nil end
    if stopped ~= nil then
        BridgeChores.noteManualStop(stopped)
        S.statusCache[stopped] = nil
    end
    S.forceRoam = false
    S.nextDecisionAt = now + 60 * FLOOR
    S.nextIdleAt = now + 5 * 60 * FLOOR
    log("debug cancel " .. tostring(had) .. " stopped=" .. tostring(stopped))
    return had and "cancelled" or "nothing running"
end

function BridgeChores.debugForce(id, index)
    if type(id) ~= "string" or not BridgeData.CHORE_SET[id] then return "bad chore: " .. tostring(id) end
    if Bridge == nil or Bridge.store == nil then return "not ready" end
    if Bridge.mode ~= "home" then return "not home" end
    BridgeChores.arm()
    if BridgeTask == nil then return "task not loaded" end
    local row0 = ROWS[id]
    if id ~= "deposit" and row0 ~= nil and row0.idle ~= true then
        if choreKind(id) == nil then return "disabled" end
        local doorRow = (id == "closeDoors" or id == "closeWindows")
        if not doorRow then
            local sh0 = S.scan[id]
            if sh0 == nil or #sh0.list == 0 then
                invalidateRow(id)
                S.statusCache[id] = nil
                return "scanning"
            end
        end
    end
    local active = BridgeTask.active == true
    local washing = BridgeWash ~= nil and BridgeWash.state ~= nil and BridgeWash.state ~= "idle"
    local pending = BridgeTask.pendingStart ~= nil
    if active or washing or pending or S.running ~= nil or S.waiting ~= nil then
        local runningRow = S.running ~= nil and S.running.row or nil
        if runningRow == nil and active and BridgeTask.kind ~= nil then runningRow = BridgeTask.kind end
        if runningRow == id then return "already running" end
        BridgeChores.debugCancel()
    end
    local body = Bridge.alive ~= nil and Bridge.alive() and Bridge.body or nil
    if body == nil then return "no body" end
    if Bridge.drivable ~= nil and Bridge.drivable() ~= true then return "not drivable" end
    local h = home()
    if h == nil then return "no home" end
    if threat(body) then return "danger" end

    local now = Bridge.time or 0
    local row = ROWS[id]
    local ok, res
    if id == "deposit" then
        local dok, dres = startDeposit(body, h, now, true)
        local out = tostring(dres or (dok and "started" or "failed"))
        S.statusCache[id] = nil
        log("debug force " .. id .. " -> " .. out)
        return out
    end
    if row ~= nil and row.idle == true then
        if id ~= "roam" then S.forceRoam = false end
        ok, res = startIdle(id, body, h, now, true)
        if id == "roam" then S.forceRoam = ok == true end
    else
        S.forceRoam = false
        local kind = choreKind(id)
        if kind == nil then return "disabled" end
        local sh = S.scan[id]
        if sh == nil or #sh.list == 0 then
            invalidateRow(id)
            S.statusCache[id] = nil
            return "scanning"
        end
        local list = filterList(id, sh.list, h, bodyZ(body))
        if index ~= nil then
            local n = tonumber(index)
            local one = n ~= nil and list[n] or nil
            if one == nil then return "bad target: " .. tostring(index) end
            list = { one }
        end
        if #list == 0 then return "no targets" end
        ok, res = startRow(body, { row = id, kind = kind, list = list, need = #list }, h, true)
    end
    local out = tostring(res or (ok and "started" or "failed"))
    S.statusCache[id] = nil
    log("debug force " .. id .. " -> " .. out)
    return out
end

function BridgeChores.debugNext()
    if Bridge == nil or Bridge.store == nil then return "not ready" end
    if Bridge.mode ~= "home" then return "not home" end
    BridgeChores.arm()
    if BridgeTask == nil then return "task not loaded" end
    if BridgeTask.active == true or BridgeTask.pendingStart ~= nil
            or (BridgeWash ~= nil and BridgeWash.state ~= nil and BridgeWash.state ~= "idle")
            or S.running ~= nil or S.waiting ~= nil then
        BridgeChores.debugCancel()
    end
    local body = Bridge.alive ~= nil and Bridge.alive() and Bridge.body or nil
    if body == nil then return "no body" end
    if Bridge.drivable ~= nil and Bridge.drivable() ~= true then return "not drivable" end
    local h = home()
    if h == nil then return "no home" end
    if threat(body) then return "danger" end
    local cands = candidates(body)
    if #cands == 0 then return "no candidates" end
    local ok, res = startRow(body, cands[1], h, true)
    local out = tostring(res or (ok and "started" or "failed"))
    log("debug next " .. tostring(cands[1].row) .. " -> " .. out)
    return out
end

function BridgeChores.debugTargets(id)
    if type(id) ~= "string" or not BridgeData.CHORE_SET[id] then return "bad chore: " .. tostring(id) end
    local h = home()
    if h == nil then return "no home" end
    local sh = S.scan[id]
    if sh == nil or #sh.list == 0 then return "no targets cached" end
    local list = filterList(id, sh.list, h, currentZ())
    if #list == 0 then return "no reachable targets" end
    local out = {}
    for i = 1, #list do
        local x, y, z = targetPos(list[i])
        if x ~= nil then
            local key = x .. ":" .. y .. ":" .. z
            local bl = S.blacklist[key] ~= nil and " blacklisted" or ""
            out[#out + 1] = i .. ": " .. x .. "," .. y .. ",z" .. z .. bl
        end
    end
    return table.concat(out, "; ")
end

function BridgeChores.command(parts)
    local sub = parts ~= nil and parts[3] or "status"
    local arg = parts ~= nil and parts[4] or nil
    if sub == nil or sub == "status" then return BridgeChores.statusText() end
    if sub == "selftest" then return BridgeChores.selftest() end
    if sub == "on" or sub == "off" then
        if Bridge.setChore ~= nil then return Bridge.setChore(arg, sub == "on") end
        return "chores not ready"
    end
    if sub == "debug" then
        if arg ~= nil then return BridgeChores.debugLine(arg) end
        return BridgeChores.debugText()
    end
    if sub == "reset" then return BridgeChores.debugReset(arg or "all") end
    if sub == "blacklist" and arg == "clear" then return BridgeChores.debugClearBlacklist() end
    if sub == "rescan" then return BridgeChores.debugRescan(arg or "all") end
    if sub == "cancel" then return BridgeChores.debugCancel() end
    if sub == "force" then return BridgeChores.debugForce(arg, parts ~= nil and parts[5] or nil) end
    if sub == "next" then return BridgeChores.debugNext() end
    if sub == "targets" then return BridgeChores.debugTargets(arg) end
    return "chores [status|debug [id]|reset [all|idle|id]|blacklist clear|rescan [all|id]|cancel|force <id> [n]|next|targets <id>|on <id>|off <id>|selftest]"
end

function BridgeChores.invalidate()
    S.scan = {}
    S.plans = {}
    S.planKey = nil
    S.homeKey = nil
    S.links = nil
    S.linkKey = nil
    S.stair = {}
    S.statusCache = {}
end

function BridgeChores.clearStatus()
    S.statusCache = {}
end

local function check(name, got, want, fails, checks)
    checks.n = checks.n + 1
    if got ~= want then fails[#fails + 1] = name .. " got=" .. tostring(got) .. " want=" .. tostring(want) end
end

function BridgeChores.selftest()
    if BridgeData == nil then return "choresselftest FAIL no BridgeData" end
    local fails, checks = {}, { n = 0 }
    local clean = BridgeData.cleanChores({ tend = false, yard = true, bogus = true, harvest = "yes" })
    check("clean bogus", clean.bogus, nil, fails, checks)
    check("clean string", clean.harvest, nil, fails, checks)
    check("clean tend", clean.tend, false, fails, checks)
    check("clean yard", clean.yard, true, fails, checks)
    check("choreOn default on", BridgeData.choreOn({}, "tend"), true, fails, checks)
    check("choreOn default off", BridgeData.choreOn({}, "yard"), false, fails, checks)
    check("deposit registered", BridgeData.CHORE_SET.deposit, true, fails, checks)
    check("deposit default on", BridgeData.choreOn({}, "deposit"), true, fails, checks)
    check("closeDoors registered", BridgeData.CHORE_SET.closeDoors, true, fails, checks)
    check("closeWindows registered", BridgeData.CHORE_SET.closeWindows, true, fails, checks)
    check("closeDoors default off", BridgeData.choreOn({}, "closeDoors"), false, fails, checks)
    check("closeWindows default on", BridgeData.choreOn({}, "closeWindows"), true, fails, checks)
    check("choreOn stored on", BridgeData.choreOn({ chores = { yard = true } }, "yard"), true, fails, checks)
    check("choreOn stored off", BridgeData.choreOn({ chores = { tend = false } }, "tend"), false, fails, checks)
    check("backoff 1", backoff(1), START_FAIL, fails, checks)
    check("backoff cap", backoff(20), START_FAIL_CAP, fails, checks)
    check("chunk base", BridgeChores.chunkStart(0, 10, 8), 8, fails, checks)
    check("chunk first", BridgeChores.chunkStart(4, 4, 8), 4, fails, checks)
    check("chunk edge", BridgeChores.chunkStart(4, 11, 8), 4, fails, checks)
    check("chunk next", BridgeChores.chunkStart(4, 12, 8), 12, fails, checks)
    local a = { group = 1, weight = 1, need = 1, same = false, dist = 1 }
    local b = { group = 2, weight = 99, need = 99, same = true, dist = 0 }
    check("group first", compareCands(a, b), true, fails, checks)
    local c = { group = 1, weight = 2, need = 1, same = false, dist = 50 }
    check("weight second", compareCands(c, a), true, fails, checks)
    if #fails == 0 then return "choresselftest PASS " .. tostring(checks.n) end
    return "choresselftest FAIL " .. table.concat(fails, "; ")
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeChores] loaded") end
