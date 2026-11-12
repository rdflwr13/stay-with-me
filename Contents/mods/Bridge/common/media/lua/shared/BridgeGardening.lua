BridgeGardening = BridgeGardening or {}

local SECOND = 60

BridgeGardening.HARVEST_TIME = 150
BridgeGardening.HARVEST_RANGE = 1.45
BridgeGardening.MAX_HARVESTS = 80
BridgeGardening.SOUND = "HarvestCrops"
BridgeGardening.PENDING_TIMEOUT = 20 * SECOND
BridgeGardening.SEEN_TTL = 60 * 1000
BridgeGardening.SAY_COOLDOWN = 30 * SECOND
BridgeGardening.WORK_SAY_COOLDOWN = 25 * SECOND
BridgeGardening.WORK_SAY_CHANCE = 30

BridgeGardening.DIG_TIME = 110
BridgeGardening.DIG_RANGE = 1.45
BridgeGardening.MAX_FURROWS = 64
BridgeGardening.DIG_SAY_COOLDOWN = 30 * SECOND
BridgeGardening.DIG_WORK_SAY_COOLDOWN = 25 * SECOND
BridgeGardening.DIG_WORK_SAY_CHANCE = 30

BridgeGardening.serverSeen = BridgeGardening.serverSeen or {}
BridgeGardening.weighed = BridgeGardening.weighed or {}

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGardening] " .. tostring(text)) end
end

local function warn(text) print("[BridgeGardening] " .. tostring(text)) end

local function nowMs()
    local t = nil
    pcall(function() t = getTimestampMs() end)
    if type(t) ~= "number" then
        pcall(function() t = os.time() * 1000 end)
    end
    if type(t) ~= "number" then t = 0 end
    return t
end

BridgeGardening.now = nowMs

function BridgeGardening.system(server)
    local sys = nil
    if server == true then
        if SFarmingSystem ~= nil then sys = SFarmingSystem.instance end
        return sys
    end
    if CFarmingSystem ~= nil then
        sys = CFarmingSystem.instance
    elseif SFarmingSystem ~= nil then
        sys = SFarmingSystem.instance
    end
    return sys
end

function BridgeGardening.squareAt(target)
    if target == nil then return nil end
    local sq = nil
    pcall(function() sq = getCell():getGridSquare(target.x, target.y, target.z) end)
    return sq
end

function BridgeGardening.plantAt(sq, server)
    if sq == nil then return nil end
    local sys = BridgeGardening.system(server)
    if sys == nil then return nil end
    local plant = nil
    pcall(function() plant = sys:getLuaObjectOnSquare(sq) end)
    if plant ~= nil and server ~= true then
        pcall(function() plant:updateFromIsoObject() end)
    end
    return plant
end

function BridgeGardening.propsOf(plant)
    if plant == nil or farming_vegetableconf == nil then return nil end
    local props = nil
    pcall(function() props = farming_vegetableconf.props[plant.typeOfSeed] end)
    return props
end

function BridgeGardening.canHarvest(plant)
    if plant == nil then return false end
    local ready = false
    pcall(function() ready = plant:canHarvest() == true end)
    return ready
end

function BridgeGardening.cropsIn(b)
    local list = {}
    if b == nil then return list end
    local cap = BridgeGardening.MAX_HARVESTS
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            if #list >= cap then return list end
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(x, y, b.z) end)
            if sq ~= nil then
                local plant = BridgeGardening.plantAt(sq, false)
                if BridgeGardening.canHarvest(plant) then
                    list[#list + 1] = { x = x, y = y, z = b.z }
                end
            end
        end
    end
    return list
end

function BridgeGardening.plantUnder(worldobjects)
    local seen = {}
    for _, o in ipairs(worldobjects or {}) do
        local sq = nil
        pcall(function() sq = o:getSquare() end)
        if sq ~= nil and seen[sq] == nil then
            seen[sq] = true
            local plant = BridgeGardening.plantAt(sq, false)
            if plant ~= nil then
                local seed, state, alive = nil, nil, false
                pcall(function()
                    seed = plant.typeOfSeed
                    state = plant.state
                    alive = plant:isAlive() == true
                end)
                if seed ~= nil and alive and state ~= "harvested" and state ~= "destroyed" then
                    return { x = sq:getX(), y = sq:getY(), z = sq:getZ() },
                        BridgeGardening.canHarvest(plant), state == "seeded"
                end
            end
        end
    end
    return nil
end

function BridgeGardening.ripenPlant(plant)
    if plant == nil then return false, 0 end
    if SFarmingSystem == nil or SFarmingSystem.instance == nil then return false, 0 end
    local stages = 0
    if not BridgeGardening.canHarvest(plant) then
        pcall(function()
            plant.health = 100
            plant.waterLvl = 100
            if type(plant.aphidLvl) == "number" then plant.aphidLvl = 0 end
            if type(plant.fliesLvl) == "number" then plant.fliesLvl = 0 end
            if type(plant.mildewLvl) == "number" then plant.mildewLvl = 0 end
            if type(plant.slugsLvl) == "number" then plant.slugsLvl = 0 end
        end)
        for i = 1, 10 do
            if BridgeGardening.canHarvest(plant) then break end
            local before = tonumber(plant.nbOfGrow) or 0
            pcall(function() SFarmingSystem.instance:growPlant(plant, nil, true) end)
            stages = stages + 1
            local after = tonumber(plant.nbOfGrow) or 0
            if after <= before and not BridgeGardening.canHarvest(plant) then break end
        end
        pcall(function() plant:saveData() end)
    end
    return BridgeGardening.canHarvest(plant) == true, stages
end

function BridgeGardening.ripenAt(target, server)
    local sq = BridgeGardening.squareAt(target)
    local plant = BridgeGardening.plantAt(sq, server == true)
    return BridgeGardening.ripenPlant(plant)
end

BridgeGardening.DIG_CACHE_TICKS = 30
BridgeGardening.digVerdict = BridgeGardening.digVerdict or {}

local GROUND_GRAVEL = {
    floors_exterior_natural_01_13 = true,
    blends_street_01_55 = true, blends_street_01_54 = true,
    blends_street_01_53 = true, blends_street_01_48 = true,
}
local GROUND_SAND = {
    blends_natural_01_0 = true, blends_natural_01_5 = true,
    blends_natural_01_6 = true, blends_natural_01_7 = true,
    floors_exterior_natural_01_24 = true,
}
local GROUND_CLAY = {
    blends_natural_01_96 = true, blends_natural_01_101 = true,
    blends_natural_01_102 = true, blends_natural_01_103 = true,
}

local function groundName(name)
    if name == nil then return nil end
    if GROUND_GRAVEL[name] then return "gravel" end
    if GROUND_SAND[name] then return "sand" end
    if GROUND_CLAY[name] then return "clay" end
    local dirt = false
    pcall(function()
        dirt = luautils.stringStarts(name, "blends_natural_01_")
            or luautils.stringStarts(name, "floors_exterior_natural")
    end)
    if dirt then return "dirt" end
    return nil
end

function BridgeGardening.groundTypeAt(sq)
    if sq == nil then return nil end
    local kind = nil
    pcall(function()
        local objects = sq:getObjects()
        if objects == nil then return end
        local index = sq:getNextNonItemObjectIndex(0)
        while index >= 0 and index < objects:size() do
            local obj = objects:get(index)
            index = sq:getNextNonItemObjectIndex(index + 1)
            local skip = false
            pcall(function()
                if obj:hasModData() and obj:getModData().shovelled then skip = true end
            end)
            if not skip then
                local name = nil
                pcall(function()
                    if obj:getSprite() ~= nil then name = obj:getSprite():getName() end
                end)
                local found = groundName(name)
                if found ~= nil then kind = found return end
            end
        end
    end)
    return kind
end

function BridgeGardening.canDigHarvestedAt(sq)
    if sq == nil then return false end
    if CFarmingSystem == nil or CFarmingSystem.instance == nil then return false end
    local plant = nil
    pcall(function() plant = CFarmingSystem.instance:getLuaObjectOnSquare(sq) end)
    if plant == nil then return false end
    local dead = false
    pcall(function() dead = plant.state ~= "plow" and plant:isAlive() == false end)
    if not dead then return false end
    local grave = false
    pcall(function() grave = sq:hasGrave() == true end)
    if grave then return false end
    local above = false
    pcall(function()
        above = getSandboxOptions():getOptionByName("PlaceDirtAboveground"):getValue() == true
    end)
    if math.floor(sq:getZ()) ~= 0 and not above then return false end
    local free = false
    pcall(function() free = sq:isFree(false) == true end)
    if not free then return false end
    return BridgeGardening.groundTypeAt(sq) == "dirt"
end

local function digKey(sq)
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = sq:getX(), sq:getY(), sq:getZ() end)
    if x == nil or y == nil then return nil end
    return x .. ":" .. y .. ":" .. z
end

local function pruneDigCache(now)
    local cache = BridgeGardening.digVerdict
    local n = 0
    for _ in pairs(cache) do n = n + 1 end
    if n <= 512 then return end
    local ttl = BridgeGardening.DIG_CACHE_TICKS
    for k, e in pairs(cache) do
        if now - (tonumber(e.at) or 0) >= ttl then cache[k] = nil end
    end
end

function BridgeGardening.canDigAt(sq)
    if sq == nil then return false end
    local now = nil
    if Bridge ~= nil and type(Bridge.tick) == "number" then now = Bridge.tick end
    local key = nil
    if now ~= nil then key = digKey(sq) end
    if key ~= nil then
        local entry = BridgeGardening.digVerdict[key]
        if entry ~= nil and (now - (tonumber(entry.at) or 0)) < BridgeGardening.DIG_CACHE_TICKS then
            return entry.ok == true
        end
    end
    local ok = false
    pcall(function() ok = ISFarmingMenu ~= nil and ISFarmingMenu.canDigHereSquare(sq) == true end)
    if not ok then ok = BridgeGardening.canDigHarvestedAt(sq) == true end
    if key ~= nil then
        BridgeGardening.digVerdict[key] = { ok = ok, at = now }
        pruneDigCache(now)
    end
    return ok
end

function BridgeGardening.furrowSpots(b)
    local list = {}
    if b == nil then return list end
    local cap = BridgeGardening.MAX_FURROWS
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            if #list >= cap then return list end
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(x, y, b.z) end)
            if BridgeGardening.canDigAt(sq) then
                list[#list + 1] = { x = x, y = y, z = b.z }
            end
        end
    end
    return list
end

BridgeGardening.DIG_TRACE = BridgeGardening.DIG_TRACE ~= false

function BridgeGardening.digAt(target, server)
    local sq = BridgeGardening.squareAt(target)
    if sq == nil then return false, "noSquare" end
    if SFarmingSystem == nil or SFarmingSystem.instance == nil then return false, "noFarming" end
    local plant = BridgeGardening.plantAt(sq, server == true)
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = sq:getX(), sq:getY(), sq:getZ() end)

    local function hasObject()
        local has = nil
        pcall(function()
            has = SFarmingSystem.instance.system:getObjectAt(x, y, z) ~= nil
        end)
        return has
    end

    local function trace(tag)
        if BridgeGardening.DIG_TRACE == false then return end
        local state, iso, objs = "nil", nil, nil
        pcall(function() if plant ~= nil then state = tostring(plant.state) end end)
        pcall(function() iso = plant ~= nil and plant:getIsoObject() ~= nil end)
        pcall(function() objs = sq:getObjects():size() end)
        log(string.format("digAt %s %s,%s plant=%s iso=%s obj=%s objs=%s",
            tag, tostring(x), tostring(y), state, tostring(iso), tostring(hasObject()), tostring(objs)))
    end

    trace("before")

    local ok, err = pcall(function()
        SFarmingSystem:removeTallGrass(sq)
        local floor = sq:getFloor()
        local props = nil
        if floor ~= nil then pcall(function() props = floor:getProperties() end) end
        if props ~= nil and props:has(IsoPropertyType.GRASS_FLOOR) and sq:checkHaveGrass() == true then
            sq:removeGrass()
        end
        if plant ~= nil then SFarmingSystem.instance:removePlant(plant) end
    end)
    if not ok then
        warn("digAt clear failed: " .. tostring(err))
        return false, "error"
    end

    trace("removed")

    if plant ~= nil and hasObject() == true then
        pcall(function() SFarmingSystem.instance:removeLuaObject(plant) end)
        trace("purged")
    end

    local okPlow, errPlow = pcall(function() SFarmingSystem.instance:plow(sq) end)
    if not okPlow then
        warn("digAt plow failed: " .. tostring(errPlow))
        return false, "error"
    end

    trace("plowed")
    return true, nil
end

function BridgeGardening.requestDig(target)
    if target == nil then return end
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "digFurrow",
            { x = target.x, y = target.y, z = target.z })
    end)
end

function BridgeGardening.animFor(plant)
    local props = BridgeGardening.propsOf(plant)
    local where = "Low"
    if props ~= nil and props.harvestPosition ~= nil then where = tostring(props.harvestPosition) end
    if where == "High" then return "LootHigh" end
    if where == "Mid" then return (BridgeTask ~= nil and BridgeTask.LOOT_MID) or "LootMid" end
    return (BridgeTask ~= nil and BridgeTask.LOOT_LOW) or "LootLow"
end

function BridgeGardening.xpFor(plant)
    local health = 0
    pcall(function() health = tonumber(plant.health) or 0 end)
    local xp = health / 2
    local bad = false
    pcall(function() bad = plant.badCare == true end)
    if bad then xp = xp - 15 else xp = xp + 25 end
    xp = math.max(1, math.min(100, xp))
    return xp
end

local function itemWeight(typeName)
    local w = nil
    pcall(function()
        local item = instanceItem(typeName)
        if item == nil and InventoryItemFactory ~= nil then
            item = InventoryItemFactory.CreateItem(typeName)
        end
        if item ~= nil then w = item:getUnequippedWeight() end
    end)
    if type(w) ~= "number" or w <= 0 then
        if type(typeName) == "string" and BridgeGardening.weighed[typeName] == nil then
            BridgeGardening.weighed[typeName] = true
            log("weight fallback for " .. tostring(typeName))
        end
        return 1.0
    end
    return w
end

function BridgeGardening.itemPlan(plant, skill)
    local plan = {}
    local props = BridgeGardening.propsOf(plant)
    if props == nil then return plan end
    local maxVeg = tonumber(props.maxVegAutorized or props.maxVeg or 1) or 1
    maxVeg = maxVeg + 11
    if props.vegetableName ~= nil then
        plan[#plan + 1] = { type = props.vegetableName, n = maxVeg }
    end
    if props.produceExtra ~= nil then
        plan[#plan + 1] = { type = props.produceExtra, n = maxVeg }
    end
    local hasSeed = false
    pcall(function() hasSeed = plant.hasSeed == true end)
    if hasSeed and props.seedName ~= nil then
        local per = tonumber(props.seedPerVeg) or 0.5
        local n = math.max(math.floor(maxVeg * per), 1)
        plan[#plan + 1] = { type = props.seedName, n = n }
    end
    return plan
end

function BridgeGardening.planWeight(plan)
    local total = 0
    for i = 1, #(plan or {}) do
        local entry = plan[i]
        total = total + itemWeight(entry.type) * (tonumber(entry.n) or 0)
    end
    return total
end

function BridgeGardening.freeCapacity(cont, chr)
    if cont == nil then return 0 end
    local cap, load = nil, nil
    pcall(function() cap = cont:getEffectiveCapacity(chr) end)
    if type(cap) ~= "number" or cap <= 0 then return 0 end
    pcall(function() load = cont:getContentsWeight() end)
    if type(load) ~= "number" then load = 0 end
    pcall(function() load = ItemContainer.floatingPointCorrection(load) end)
    if type(load) ~= "number" then return 0 end
    local free = cap - load
    if free < 0 then free = 0 end
    return free
end

function BridgeGardening.roomFor(cont, plant, skill, chr)
    if cont == nil then return false end
    local plan = BridgeGardening.itemPlan(plant, skill)
    local need = BridgeGardening.planWeight(plan)
    local free = BridgeGardening.freeCapacity(cont, chr)
    return need <= free + 0.001
end

function BridgeGardening.pickDest(body, plant, skill)
    if body == nil or BridgeTask == nil or type(BridgeTask.lootDests) ~= "function" then return nil end
    local dests = nil
    pcall(function() dests = BridgeTask.lootDests(body) end)
    if dests == nil or #dests == 0 then return nil end
    local chr = nil
    if BridgeData ~= nil and type(BridgeData.owner) == "function" then
        pcall(function() chr = BridgeData.owner() end)
    end
    for i = 1, #dests do
        if BridgeGardening.roomFor(dests[i], plant, skill, chr) then
            log(string.format("dest pick %s free=%.2f need=%.2f slot=%d/%d",
                tostring(i == #dests and "main" or "bag"),
                BridgeGardening.freeCapacity(dests[i], chr),
                BridgeGardening.planWeight(BridgeGardening.itemPlan(plant, skill)), i, #dests))
            return dests[i], i == #dests
        end
    end
    log("dest pick none, every container full")
    return nil
end

function BridgeGardening.recsWeight(recs)
    local total = 0
    for i = 1, #(recs or {}) do
        local rec = recs[i]
        if type(rec) == "table" and type(rec.t) == "string" then
            total = total + itemWeight(rec.t)
        end
    end
    return total
end

function BridgeGardening.destForRecs(body, recs, chr)
    if body == nil then return nil end
    local need = BridgeGardening.recsWeight(recs)
    local dests = nil
    pcall(function() dests = BridgeTask.lootDests(body) end)
    for i = 1, #(dests or {}) do
        if BridgeGardening.freeCapacity(dests[i], chr) + 0.001 >= need then
            return dests[i]
        end
    end
    local main = nil
    pcall(function() main = body:getInventory() end)
    return main
end

function BridgeGardening.harvestWithBag(plant, dest, skill)
    if plant == nil or dest == nil then return false, "gone", 0 end
    if SFarmingSystem == nil or SFarmingSystem.instance == nil then return false, "error", 0 end
    local target = plant
    local px, py, pz = nil, nil, nil
    pcall(function() px, py, pz = plant.x, plant.y, plant.z end)
    if px ~= nil and py ~= nil and pz ~= nil then
        local serverPlant = nil
        pcall(function() serverPlant = SFarmingSystem.instance:getLuaObjectAt(px, py, pz) end)
        if serverPlant ~= nil then target = serverPlant end
    end
    if not BridgeGardening.canHarvest(target) then return false, "notripe", 0 end
    local xp = BridgeGardening.xpFor(target)
    local proxy = {
        getPerkLevel = function(self, perk) return tonumber(skill) or 0 end,
        getInventory = function(self) return dest end,
        getStats = function(self) return { remove = function() end } end,
    }
    local ok, err = pcall(function() SFarmingSystem.instance:harvest(target, proxy) end)
    if not ok then
        warn("harvest failed: " .. tostring(err))
        return false, "error", 0
    end
    return true, nil, xp
end

function BridgeGardening.harvestProduce(plant, skill)
    local temp = nil
    pcall(function() temp = ItemContainer.new("BridgeHarvest", nil, nil) end)
    if temp == nil then return false, "error", 0, {} end
    pcall(function() temp:setCapacity(1000) end)
    local original = sendAddItemsToContainer
    local hooked = false
    if type(original) == "function" then
        pcall(function()
            sendAddItemsToContainer = function(cont, items)
                if cont == temp then return end
                return original(cont, items)
            end
            hooked = true
        end)
    end
    local ok, why, xp = BridgeGardening.harvestWithBag(plant, temp, skill)
    if hooked then pcall(function() sendAddItemsToContainer = original end) end
    local recs = {}
    if ok and BridgeItems ~= nil then
        pcall(function()
            local list = temp:getItems()
            for i = 0, list:size() - 1 do
                local item = list:get(i)
                if item ~= nil then
                    local rec = BridgeItems.record(item, true)
                    if rec ~= nil then recs[#recs + 1] = rec end
                end
            end
            temp:clear()
        end)
        log("harvest produced " .. tostring(#recs) .. " record(s)")
    end
    return ok, why, xp, recs
end

function BridgeGardening.receiveHarvest(body, args)
    if body == nil or args == nil then return 0 end
    local recs = args.recs
    if type(recs) ~= "table" or #recs == 0 then return 0 end
    if BridgeItems == nil then return 0 end
    local dest = nil
    if BridgeTask ~= nil then dest = BridgeTask.harvestDest end
    if dest ~= nil and BridgeInventory ~= nil and type(BridgeInventory.inBody) == "function" then
        local ok = false
        pcall(function() ok = BridgeInventory.inBody(dest) == true end)
        if not ok then dest = nil end
    end
    if dest == nil then
        local chr = nil
        if BridgeData ~= nil and type(BridgeData.owner) == "function" then
            pcall(function() chr = BridgeData.owner() end)
        end
        dest = BridgeGardening.destForRecs(body, recs, chr)
    end
    if dest == nil then pcall(function() dest = body:getInventory() end) end
    if dest == nil then return 0 end
    local made = 0
    for i = 1, #recs do
        local item = nil
        pcall(function() item = BridgeItems.make(dest, recs[i]) end)
        if item == nil then
            pcall(function() item = BridgeItems.make(body:getInventory(), recs[i]) end)
        end
        if item ~= nil then made = made + 1 end
    end
    pcall(function()
        if BridgeInventory ~= nil and type(BridgeInventory.resetWornBags) == "function" then
            BridgeInventory.resetWornBags(body)
        end
    end)
    pcall(function()
        if Bridge ~= nil and type(Bridge.itemsChanged) == "function" then Bridge.itemsChanged() end
    end)
    pcall(function()
        local inv, loot = getPlayerInventory(0), getPlayerLoot(0)
        if inv ~= nil then inv:refreshBackpacks() end
        if loot ~= nil then loot:refreshBackpacks() end
        if ISInventoryPage ~= nil then ISInventoryPage.renderDirty = true end
    end)
    log("harvest materialized " .. tostring(made) .. " of " .. tostring(#recs) .. " item(s)")
    return made
end

function BridgeGardening.harvestLocal(body, plant, dest, skill)
    if plant == nil or dest == nil then return false, "gone", 0 end
    local chr = nil
    if BridgeData ~= nil and type(BridgeData.owner) == "function" then
        pcall(function() chr = BridgeData.owner() end)
    end
    if not BridgeGardening.roomFor(dest, plant, skill, chr) then return false, "bagfull", 0 end
    return BridgeGardening.harvestWithBag(plant, dest, skill)
end

function BridgeGardening.requestHarvest(id, target)
    if target == nil then return end
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "harvestCrops",
            { id = id, x = target.x, y = target.y, z = target.z })
    end)
end

function BridgeGardening.pruneSeen()
    local seen = BridgeGardening.serverSeen
    local now = nowMs()
    for key, entry in pairs(seen) do
        if type(entry) ~= "table" or now - (tonumber(entry.at) or 0) > BridgeGardening.SEEN_TTL then
            seen[key] = nil
        end
    end
end

function BridgeGardening.clearAnim(body)
    if body == nil then return end
    pcall(function()
        body:setVariable("BumpAnimFinished", true)
        body:changeState(ZombieIdleState.instance())
        body:setBumpType("")
    end)
end

function BridgeGardening.stopSound(body)
    if BridgeTask == nil then return end
    local id = BridgeTask.harvestSoundId
    local emitter = BridgeTask.harvestEmitter
    BridgeTask.harvestSoundId = nil
    BridgeTask.harvestEmitter = nil
    if id == nil or emitter == nil or id == 0 then return end
    pcall(function() emitter:stopOrTriggerSound(id) end)
end

function BridgeGardening.nextTarget(body)
    local T = BridgeTask
    if T == nil or body == nil then return nil end
    local bx, by = body:getX(), body:getY()
    local bestI, bestD = nil, nil
    local bestAnyI, bestAnyD = nil, nil
    local bodyKey = nil
    pcall(function() bodyKey = T.enclosureKey(body) end)
    for i = 1, #T.queue do
        local t = T.queue[i]
        local sq = BridgeGardening.squareAt(t)
        local d = (bx - t.x) ^ 2 + (by - t.y) ^ 2
        if bestAnyD == nil or d < bestAnyD then
            bestAnyD = d
            bestAnyI = i
        end
        local allowed = true
        if bodyKey ~= nil then
            pcall(function() allowed = T.enclosureKeyOf(sq) == bodyKey end)
        end
        if allowed then
            if bestD == nil or d < bestD then
                bestD = d
                bestI = i
            end
        end
    end
    local idx = bestI or bestAnyI
    if idx == nil then return nil end
    return table.remove(T.queue, idx)
end

local function sayLine(event, slot, cooldown)
    cooldown = cooldown or BridgeGardening.SAY_COOLDOWN
    local said = false
    pcall(function()
        said = BridgeMoments ~= nil
            and BridgeMoments.say(event, cooldown, true, slot) == true
    end)
    return said
end

function BridgeGardening.clearHarvestState()
    if BridgeTask == nil then return end
    BridgeTask.harvestAnim = nil
    BridgeTask.harvestStart = nil
    BridgeTask.harvestAnimStart = nil
    BridgeTask.harvestRestarts = nil
    BridgeTask.harvestDest = nil
    BridgeTask.harvestWaitAt = nil
    BridgeTask.harvestRequestId = nil
    BridgeTask.harvestPending = nil
    BridgeTask.harvestSeq = nil
end

function BridgeGardening.commitHarvest()
    local T = BridgeTask
    if T == nil then return false end
    T.markDone()
    T.current = nil
    T.phase = nil
    BridgeGardening.clearHarvestState()
    BridgeGardening.stopSound(Bridge.body)
    BridgeGardening.clearAnim(Bridge.body)
    if #T.queue == 0 then
        if (T.doneCount or 0) > 0 then sayLine("EvHarvestingDone", "HarvestDone") end
        return T.finish()
    end
    return true
end

local function dropCrop(body)
    local T = BridgeTask
    BridgeGardening.stopSound(body)
    BridgeGardening.clearAnim(body)
    T.current = nil
    T.phase = nil
    BridgeGardening.clearHarvestState()
    if #T.queue == 0 then return T.finish() end
    return true
end

local function beginHarvest(body, target, plant)
    local T = BridgeTask
    pcall(function() BridgeMove.stopPath(body) end)
    T.forceIdle(body)
    pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)
    pcall(function()
        body:setPrimaryHandItem(nil)
        body:setSecondaryHandItem(nil)
        body:resetModelNextFrame()
    end)
    T.harvestAnim = BridgeGardening.animFor(plant)
    T.harvestStart = Bridge.time
    T.harvestAnimStart = Bridge.time
    T.harvestRestarts = 0
    T.animHold = 0
    T.phase = "harvest"
    pcall(function()
        body:setVariable("BumpAnimFinished", false)
        body:setBumpType(T.harvestAnim)
    end)
    local id = nil
    pcall(function()
        if BridgeSound ~= nil and type(BridgeSound.event) == "function" then
            id = BridgeSound.event(body, BridgeGardening.SOUND)
        end
    end)
    T.harvestSoundId = id
    local emitter = nil
    pcall(function() emitter = body:getEmitter() end)
    T.harvestEmitter = emitter
    log(string.format("harvest start %d,%d anim=%s", target.x, target.y, tostring(T.harvestAnim)))
end

function BridgeGardening.kindUpdate(body)
    local T = BridgeTask
    if T == nil or body == nil then return false end
    if T.HARVESTING_ENABLED ~= 1 then return T.finish() end
    if BridgeMove ~= nil then BridgeMove.forcedWalk = "Walk" end

    if T.phase == "wait" then
        if T.harvestPending == nil then
            T.phase = nil
        elseif (Bridge.time - (T.harvestWaitAt or Bridge.time)) > BridgeGardening.PENDING_TIMEOUT then
            T.harvestPending = nil
            T.info = "harvest timeout"
            log("harvest timeout")
            return T.cancel("harvest timeout")
        end
        return true
    end

    if T.current == nil then
        if #T.queue == 0 then return T.finish() end
        local picked = BridgeGardening.nextTarget(body)
        if picked == nil then return T.finish() end
        T.current = picked
        T.phase = "walk"
        T.harvestAnim = nil
        T.harvestStart = nil
        T.harvestPending = nil
        T.harvestWaitAt = nil
        T.animHold = 0
        T.info = "crop"
        T.progressAt = Bridge.time
        T.pathFails = 0
        T.pathFailTick = nil
        T.bestD = nil
        T.spot = nil
    end

    local target = T.current
    local sq = BridgeGardening.squareAt(target)
    local plant = BridgeGardening.plantAt(sq, false)
    if plant == nil or not BridgeGardening.canHarvest(plant) then
        return dropCrop(body)
    end

    if not T.harvestSaid then
        if (Bridge.time - (T.harvestSayCheck or 0)) >= SECOND then
            T.harvestSayCheck = Bridge.time
            if sayLine("EvHarvesting", "Harvest") then T.harvestSaid = true end
        end
    end
    if T.phase ~= "walk" and T.harvestSaid then
        if (Bridge.time - (T.harvestWorkSayCheck or 0)) >= SECOND then
            T.harvestWorkSayCheck = Bridge.time
            if (Bridge.time - (T.harvestWorkSay or -99999)) >= BridgeGardening.WORK_SAY_COOLDOWN
                    and ZombRand(100) < BridgeGardening.WORK_SAY_CHANCE then
                if sayLine("EvHarvestingWork", "HarvestWork", BridgeGardening.WORK_SAY_COOLDOWN) then
                    T.harvestWorkSay = Bridge.time
                end
            end
        end
    end

    if T.phase == "walk" then
        local walk, why = T.walkTo(body, target, BridgeGardening.HARVEST_RANGE, true)
        if walk == "unreachable" then return T.dropTarget(why) end
        if walk ~= "arrived" then return true end
        beginHarvest(body, target, plant)
        return true
    end

    local anim = T.harvestAnim or BridgeGardening.animFor(plant)
    local animAge = (Bridge.time - (T.harvestAnimStart or T.harvestStart or Bridge.time)) * T.ffMult()
    if animAge >= T.SCRUB_GUARD then
        local playing = false
        pcall(function()
            playing = body:getActionStateName() == "bumped" and tostring(body:getBumpType()) == anim
        end)
        if not playing and (T.harvestRestarts or 0) < 6 then
            T.harvestRestarts = (T.harvestRestarts or 0) + 1
            BridgeGardening.clearAnim(body)
            pcall(function()
                body:setVariable("BumpAnimFinished", false)
                body:setBumpType(anim)
            end)
            T.harvestAnimStart = Bridge.time
            T.info = "harvest anim restarted"
            return true
        end
    end
    local age = (Bridge.time - (T.harvestStart or Bridge.time)) * T.ffMult()
    if age < BridgeGardening.HARVEST_TIME then return true end

    BridgeGardening.stopSound(body)

    local skill = 0
    pcall(function() skill = BridgeSkills.level("Agriculture") end)
    local dest = BridgeGardening.pickDest(body, plant, skill)
    if dest == nil then
        T.info = "no room"
        sayLine("EvHarvestingFull", "HarvestFull")
        return T.finish()
    end

    if Bridge ~= nil and Bridge.mp == true then
        T.harvestDest = dest
        T.harvestSeq = (T.harvestSeq or 0) + 1
        T.harvestRequestId = string.format("%d:%d:%d:%d", Bridge.tick or 0, target.x, target.y, T.harvestSeq)
        T.harvestPending = { id = T.harvestRequestId, x = target.x, y = target.y, z = target.z }
        T.harvestWaitAt = Bridge.time
        T.phase = "wait"
        BridgeGardening.requestHarvest(T.harvestRequestId, target)
        return true
    end

    local ok, why, xp = BridgeGardening.harvestLocal(body, plant, dest, skill)
    if ok then
        if (tonumber(xp) or 0) > 0 then
            pcall(function() BridgeSkills.add("Agriculture", xp, "harvest") end)
        end
        return BridgeGardening.commitHarvest()
    end
    if why == "bagfull" then
        T.info = "no room"
        sayLine("EvHarvestingFull", "HarvestFull")
        return T.finish()
    end
    if why == "gone" or why == "notripe" then
        return dropCrop(body)
    end
    return T.cancel("harvest error")
end

function BridgeGardening.kindLeave(body)
    local T = BridgeTask
    if T == nil then return end
    BridgeGardening.stopSound(body)
    BridgeGardening.clearAnim(body)
    BridgeGardening.clearHarvestState()
    T.harvestSaid = nil
    T.harvestSayCheck = nil
    T.harvestWorkSayCheck = nil
    T.harvestWorkSay = nil
    T.animHold = 0
end

function BridgeGardening.onResult(args)
    local T = BridgeTask
    if T == nil or args == nil then return end
    if T.active ~= true or T.kind ~= "harvestCrops" then return end
    local pending = T.harvestPending
    if pending == nil or tostring(pending.id) ~= tostring(args.id) then return end
    T.harvestPending = nil
    local body = Bridge.body
    BridgeGardening.stopSound(body)
    if args.ok == true then
        local made = 0
        local wanted = 0
        if type(args.recs) == "table" then
            wanted = #args.recs
            made = BridgeGardening.receiveHarvest(body, args)
        end
        if type(args.iseq) == "number" then Bridge.iseq = args.iseq end
        local xp = tonumber(args.xp) or 0
        if xp > 0 then
            pcall(function() BridgeSkills.add("Agriculture", xp, "harvest") end)
        end
        log(string.format("harvest result ok xp=%.1f items=%d/%d", xp, made, wanted))
        BridgeGardening.commitHarvest()
        return
    end
    local why = tostring(args.why)
    if why == "bagfull" then
        T.info = "no room"
        sayLine("EvHarvestingFull", "HarvestFull")
        T.finish()
        return
    end
    if why == "notripe" or why == "gone" then
        dropCrop(body)
        return
    end
    log("harvest result error: " .. why)
    T.cancel("harvest error")
end

local function stopDigSound()
    local T = BridgeTask
    if T == nil then return end
    local id, emitter = T.digSoundId, T.digEmitter
    T.digSoundId, T.digEmitter = nil, nil
    if id == nil or emitter == nil or id == 0 then return end
    pcall(function() emitter:stopOrTriggerSound(id) end)
end

local function resetDigTarget()
    local T = BridgeTask
    if T == nil then return end
    T.phase = nil
    T.digStart = nil
    T.digAnimStart = nil
    T.digSoundId = nil
    T.digEmitter = nil
    T.digAnim = nil
    T.digRestarts = nil
    T.animHold = 0
end

function BridgeGardening.clearDigState()
    local T = BridgeTask
    if T == nil then return end
    resetDigTarget()
    T.digSaid = nil
    T.digSayCheck = nil
    T.digWorkSay = nil
    T.digWorkSayCheck = nil
end

local function equipDigTool(body, tool)
    if body == nil or tool == nil then return end
    local inv = nil
    pcall(function() inv = body:getInventory() end)
    if inv ~= nil then
        local inMain = false
        pcall(function() inMain = tool:getContainer() == inv end)
        if not inMain then
            pcall(function()
                tool:getContainer():Remove(tool)
                inv:AddItem(tool)
            end)
        end
    end
    pcall(function()
        body:setPrimaryHandItem(tool)
        if tool:isTwoHandWeapon() or tool:isRequiresEquippedBothHands() then
            body:setSecondaryHandItem(tool)
        end
    end)
end

function BridgeGardening.digUpdate(body)
    local T = BridgeTask
    if T == nil or body == nil then return false end
    if T.FURROWS_ENABLED ~= 1 then return T.finish() end
    local tool = T.cachedTool(body, "digTool", T.findDigTool, T.toolOk)
    if tool == nil then return T.cancel("noSupplies") end
    if body:getPrimaryHandItem() ~= tool then equipDigTool(body, tool) end
    if BridgeMove ~= nil then BridgeMove.forcedWalk = "Walk" end

    if T.current == nil then
        if #T.queue == 0 then return T.finish() end
        local picked = BridgeGardening.nextTarget(body)
        if picked == nil then return T.finish() end
        resetDigTarget()
        T.current = picked
        T.phase = "walk"
        T.info = "furrow"
        T.progressAt = Bridge.time
        T.pathFails = 0
        T.pathFailTick = nil
        T.bestD = nil
        T.spot = nil
    end

    local target = T.current
    local sq = BridgeGardening.squareAt(target)
    if not BridgeGardening.canDigAt(sq) then
        stopDigSound()
        BridgeGardening.clearAnim(body)
        resetDigTarget()
        T.info = "not diggable"
        T.current = nil
        if #T.queue == 0 then return T.finish() end
        return true
    end

    if not T.digSaid then
        if (Bridge.time - (T.digSayCheck or 0)) >= SECOND then
            T.digSayCheck = Bridge.time
            if sayLine("EvDigging", "Digging", BridgeGardening.DIG_SAY_COOLDOWN) then T.digSaid = true end
        end
    end
    if T.phase ~= "walk" and T.digSaid then
        if (Bridge.time - (T.digWorkSayCheck or 0)) >= SECOND then
            T.digWorkSayCheck = Bridge.time
            if (Bridge.time - (T.digWorkSay or -99999)) >= BridgeGardening.DIG_WORK_SAY_COOLDOWN
                    and ZombRand(100) < BridgeGardening.DIG_WORK_SAY_CHANCE then
                if sayLine("EvDiggingWork", "DiggingWork", BridgeGardening.DIG_WORK_SAY_COOLDOWN) then
                    T.digWorkSay = Bridge.time
                end
            end
        end
    end

    if T.phase ~= "dig" then
        local walk, why = T.walkTo(body, target, BridgeGardening.DIG_RANGE, true)
        if walk == "unreachable" then return T.dropTarget(why) end
        if walk ~= "arrived" then return true end
        pcall(function() BridgeMove.stopPath(body) end)
        T.forceIdle(body)
        pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)
        T.phase = "dig"
        T.digStart = Bridge.time
        T.digAnimStart = Bridge.time
        T.digAnim = T.digAnimFor(tool)
        T.digRestarts = 0
        pcall(function()
            body:setVariable("BumpAnimFinished", false)
            body:setBumpType(T.digAnim)
        end)
        local id = nil
        pcall(function()
            if BridgeSound ~= nil and type(BridgeSound.event) == "function" then
                id = BridgeSound.event(body, T.digSoundFor(tool))
            end
        end)
        T.digSoundId = id
        local emitter = nil
        pcall(function() emitter = body:getEmitter() end)
        T.digEmitter = emitter
        T.info = "digging"
        log(string.format("dig start %d,%d anim=%s", target.x, target.y, tostring(T.digAnim)))
        return true
    end

    local anim = T.digAnim or T.digAnimFor(tool)
    local animAge = (Bridge.time - (T.digAnimStart or T.digStart or Bridge.time)) * T.ffMult()
    if animAge >= T.SCRUB_GUARD then
        local playing = false
        pcall(function()
            playing = body:getActionStateName() == "bumped" and tostring(body:getBumpType()) == anim
        end)
        if not playing and (T.digRestarts or 0) < 6 then
            T.digRestarts = (T.digRestarts or 0) + 1
            BridgeGardening.clearAnim(body)
            pcall(function()
                body:setVariable("BumpAnimFinished", false)
                body:setBumpType(anim)
            end)
            T.digAnimStart = Bridge.time
            T.info = "dig anim restarted"
            return true
        end
    end
    local age = (Bridge.time - (T.digStart or Bridge.time)) * T.ffMult()
    if age < BridgeGardening.DIG_TIME then return true end

    stopDigSound()
    BridgeGardening.clearAnim(body)
    if Bridge ~= nil and Bridge.mp == true then
        BridgeGardening.requestDig(target)
    else
        BridgeGardening.digAt(target, true)
    end
    pcall(function() body:getStats():remove(CharacterStat.ENDURANCE, 0.0013) end)
    T.markDone()
    T.current = nil
    resetDigTarget()
    if #T.queue == 0 then
        if (T.doneCount or 0) > 0 then sayLine("EvDiggingDone", "DiggingDone") end
        return T.finish()
    end
    return true
end

function BridgeGardening.digLeave(body)
    local T = BridgeTask
    if T == nil then return end
    stopDigSound()
    BridgeGardening.clearAnim(body)
    BridgeGardening.clearDigState()
end

local function install()
    if BridgeTask ~= nil and BridgeTask.kinds ~= nil then
        BridgeTask.kinds.harvestCrops = {
            available = function(body) return BridgeTask.HARVESTING_ENABLED == 1 end,
            missing = function(body) return nil end,
            update = function(body) return BridgeGardening.kindUpdate(body) end,
            leave = function(body) return BridgeGardening.kindLeave(body) end,
        }
        BridgeTask.kinds.digFurrows = {
            available = function(body)
                if BridgeTask.FURROWS_ENABLED ~= 1 then return false end
                return BridgeTask.cachedTool(body, "digTool", BridgeTask.findDigTool,
                    BridgeTask.toolOk) ~= nil
            end,
            missing = function(body)
                if BridgeTask.findDigTool(body) == nil then return "digTool" end
                return nil
            end,
            update = function(body) return BridgeGardening.digUpdate(body) end,
            leave = function(body) return BridgeGardening.digLeave(body) end,
        }
    end
    if BridgeWorkSelect ~= nil and BridgeWorkSelect.kinds ~= nil then
        BridgeWorkSelect.kinds.harvestCrops = {
            collect = function(b) return BridgeGardening.cropsIn(b) end,
            max = BridgeGardening.MAX_HARVESTS,
            noneSay = "JobNoCrops",
        }
        BridgeWorkSelect.kinds.digFurrows = {
            collect = function(b) return BridgeGardening.furrowSpots(b) end,
            max = BridgeGardening.MAX_FURROWS,
            maxSide = 8,
            min = 1,
            noneSay = "JobNoDigSpots",
        }
    end
    log("kinds registered")
end

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(install) end)
end
