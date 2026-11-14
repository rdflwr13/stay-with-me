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
BridgeGardening.DIG_SETTLE = 27
BridgeGardening.DIG_RANGE = 1.45
BridgeGardening.MAX_FURROWS = 64
BridgeGardening.DIG_SAY_COOLDOWN = 30 * SECOND
BridgeGardening.DIG_WORK_SAY_COOLDOWN = 25 * SECOND
BridgeGardening.DIG_WORK_SAY_CHANCE = 30

BridgeGardening.SEEDS_PER_PACKET = 5
BridgeGardening.SOW_TIME = 40
BridgeGardening.SOW_SETTLE = 21
BridgeGardening.SOW_RANGE = 1.45
BridgeGardening.MAX_SOWS = 80
BridgeGardening.SOW_XP = 0
BridgeGardening.SOW_SOUND = "SowSeeds"
BridgeGardening.SOW_SAY_COOLDOWN = 30 * SECOND
BridgeGardening.SOW_WORK_SAY_COOLDOWN = 25 * SECOND
BridgeGardening.SOW_WORK_SAY_CHANCE = 30
BridgeGardening.RETURN_TIMEOUT = 10 * SECOND

BridgeGardening.WATER_THRESHOLD = 60
BridgeGardening.WATER_MAX_USES = 10
BridgeGardening.WATER_PER_USE_ML = 200
BridgeGardening.MAX_WATER_PLANTS = 80

BridgeGardening.FEED_TIME = 100
BridgeGardening.FEED_SETTLE = 21
BridgeGardening.FEED_RANGE = 1.45
BridgeGardening.MAX_FEED_PLANTS = 80
BridgeGardening.FEED_YOUNG_GROWTH = 3
BridgeGardening.FEED_SAY_COOLDOWN = 30 * SECOND
BridgeGardening.FEED_WORK_SAY_COOLDOWN = 25 * SECOND
BridgeGardening.FEED_WORK_SAY_CHANCE = 30
BridgeGardening.FEED_XP = 0

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
                if state == "plow" then
                    return { x = sq:getX(), y = sq:getY(), z = sq:getZ() }, false, false, "plow"
                end
                if seed ~= nil and alive and state ~= "harvested" and state ~= "destroyed" then
                    return { x = sq:getX(), y = sq:getY(), z = sq:getZ() },
                        BridgeGardening.canHarvest(plant), state == "seeded", state
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

    if T.phase == "settle" then
        if (Bridge.time - (T.settleAt or Bridge.time)) * T.ffMult() < (T.settleFor or 0) then return true end
        T.settled = true
    end
    if T.phase ~= "dig" then
        local walk, why = T.walkTo(body, target, BridgeGardening.DIG_RANGE, true)
        if walk == "unreachable" then return T.dropTarget(why) end
        if walk ~= "arrived" then return true end
        pcall(function() BridgeMove.stopPath(body) end)
        T.forceIdle(body)
        pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)
        if (T.doneCount or 0) > 0 and T.settled ~= true then
            T.phase = "settle"
            T.settleAt = Bridge.time
            T.settleFor = BridgeGardening.DIG_SETTLE or 27
            T.info = "settling"
            return true
        end
        T.settled = nil
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

local seedCache = nil
local seedScanDone = false

local function stripSeedSuffix(full)
    if type(full) ~= "string" then return nil end
    local base = string.match(full, "^(.+)Seeds$")
    if base == nil then base = string.match(full, "^(.+)Seed$") end
    return base
end

local function itemExists(full)
    local ok = false
    if type(full) ~= "string" then return false end
    pcall(function()
        if ScriptManager ~= nil and ScriptManager.instance ~= nil then
            ok = ScriptManager.instance:getItem(full) ~= nil
        end
    end)
    return ok
end

local function packetForSeed(seed)
    local base = stripSeedSuffix(seed)
    if base == nil then return nil end
    local names = { "BagSeed", "BagSeed2" }
    for i = 1, #names do
        local typeName = base .. names[i]
        if itemExists(typeName) and itemExists(typeName .. "_Empty") then return typeName end
    end
    return nil
end

local function scanPackets(t, missing)
    if seedScanDone or #missing == 0 then return end
    seedScanDone = true
    local all = nil
    pcall(function()
        all = getAllItems()
        if all == nil then
            local manager = getScriptManager()
            if manager ~= nil then all = manager:getAllItems() end
        end
    end)
    if all == nil then return end
    local want = {}
    for i = 1, #missing do
        local base = stripSeedSuffix(missing[i])
        if base ~= nil then want[base] = missing[i] end
    end
    local have = {}
    pcall(function()
        for i = 0, all:size() - 1 do
            local full = nil
            pcall(function() full = all:get(i):getFullName() end)
            if type(full) == "string" then have[full] = true end
        end
    end)
    local found = {}
    pcall(function()
        for i = 0, all:size() - 1 do
            local full = nil
            pcall(function() full = all:get(i):getFullName() end)
            if type(full) == "string" and string.find(full, "BagSeed", 1, true) ~= nil
                    and string.sub(full, -6) ~= "_Empty" then
                local base = string.match(full, "^(.+)BagSeed2$")
                if base == nil then base = string.match(full, "^(.+)BagSeed$") end
                local seed = base ~= nil and want[base] or nil
                local empty = full .. "_Empty"
                if seed ~= nil and found[seed] == nil and (have[empty] == true or itemExists(empty)) then
                    found[seed] = full
                end
            end
        end
    end)
    local n = 0
    for seed, packet in pairs(found) do
        local kind = t.bySeed[seed]
        local entry = kind ~= nil and t.byKind[kind] or nil
        if entry ~= nil then
            entry.packets[#entry.packets + 1] = packet
            t.byPacket[packet] = { seed = seed, empty = packet .. "_Empty", kind = kind }
            n = n + 1
        end
    end
    if n > 0 then log("seed table: scanned " .. tostring(n) .. " packet(s)") end
end

function BridgeGardening.seedTable()
    if seedCache ~= nil then return seedCache end
    local t = { bySeed = {}, byPacket = {}, byKind = {}, kinds = {} }
    seedCache = t
    local props = nil
    if farming_vegetableconf ~= nil then props = farming_vegetableconf.props end
    if props == nil then
        log("seed table: farming_vegetableconf unavailable")
        return t
    end
    local missing = {}
    for kind, cfg in pairs(props) do
        if type(cfg) == "table" then
            local seeds = {}
            local list = cfg.seedTypes
            if type(list) ~= "table" then list = (cfg.seedName ~= nil) and { cfg.seedName } or nil end
            for i = 1, #(list or {}) do
                local seed = list[i]
                if type(seed) == "string" and t.bySeed[seed] == nil then
                    seeds[#seeds + 1] = seed
                    t.bySeed[seed] = kind
                end
            end
            if #seeds > 0 then
                local entry = {
                    kind = kind,
                    seeds = seeds,
                    packets = {},
                    sowMonth = cfg.sowMonth,
                    bestMonth = cfg.bestMonth,
                    riskMonth = cfg.riskMonth,
                }
                for i = 1, #seeds do
                    local packet = packetForSeed(seeds[i])
                    if packet ~= nil then
                        entry.packets[#entry.packets + 1] = packet
                        t.byPacket[packet] = { seed = seeds[i], empty = packet .. "_Empty", kind = kind }
                    else
                        missing[#missing + 1] = seeds[i]
                    end
                end
                t.byKind[kind] = entry
                t.kinds[#t.kinds + 1] = kind
            end
        end
    end
    table.sort(t.kinds)
    local okScan, errScan = pcall(scanPackets, t, missing)
    if not okScan then log("seed table scan failed: " .. tostring(errScan)) end
    log("seed table: " .. tostring(#t.kinds) .. " crop kind(s), " .. tostring(#missing)
        .. " seed type(s) without a packet")
    return t
end

function BridgeGardening.seedTypesOf(kind)
    local entry = BridgeGardening.seedTable().byKind[kind]
    if entry == nil then return {} end
    return entry.seeds
end

function BridgeGardening.packetOf(kind)
    local entry = BridgeGardening.seedTable().byKind[kind]
    if entry == nil then return nil end
    return entry.packets[1]
end

function BridgeGardening.packetInfo(packetType)
    if packetType == nil then return nil end
    return BridgeGardening.seedTable().byPacket[packetType]
end

function BridgeGardening.cropOfItem(fullType)
    if fullType == nil then return nil end
    return BridgeGardening.seedTable().bySeed[fullType]
end

function BridgeGardening.kindLabel(kind)
    local text = nil
    pcall(function() text = getText("Farming_" .. tostring(kind)) end)
    local fallback = "Farming_" .. tostring(kind)
    if type(text) ~= "string" or text == "" or text == fallback then text = tostring(kind) end
    return text
end

local function seasonLabel(entry)
    local seasons = false
    pcall(function()
        local opt = getSandboxOptions():getOptionByName("PlantGrowingSeasons")
        if opt ~= nil then seasons = opt:getValue() == true end
    end)
    if not seasons then return nil, nil end
    local month = nil
    pcall(function() month = getGameTime():getMonth() + 1 end)
    if month == nil then return nil, nil end
    local function has(list)
        for i = 1, #(list or {}) do
            if list[i] == month then return true end
        end
        return false
    end
    local key = nil
    if has(entry.bestMonth) then
        key = "Farming_Tooltip_BestMonth"
    elseif has(entry.riskMonth) then
        key = "Farming_Tooltip_RiskMonth"
    elseif has(entry.sowMonth) then
        key = "Farming_Tooltip_InSeason"
    else
        key = "Farming_Tooltip_BadMonth"
    end
    local text = nil
    pcall(function() text = getText(key) end)
    if type(text) ~= "string" or text == "" or text == key then text = nil end
    return text, month
end

function BridgeGardening.seedMenuRows(stock)
    local rows = {}
    local t = BridgeGardening.seedTable()
    for i = 1, #t.kinds do
        local kind = t.kinds[i]
        local entry = t.byKind[kind]
        local counts = type(stock) == "table" and stock[kind] or nil
        local plantable = counts ~= nil and math.floor(tonumber(counts.plantable) or 0) or 0
        if plantable > 0 then
            local text = BridgeGardening.kindLabel(kind)
            local season, month = seasonLabel(entry)
            if season ~= nil then text = text .. " (" .. season .. ")" end
            local label = text
            local yours = counts ~= nil and math.floor(tonumber(counts.yours) or 0) or 0
            if yours > 0 then label = label .. " (+" .. tostring(yours) .. " yours)" end
            label = label .. " : " .. tostring(plantable)
            rows[#rows + 1] = {
                kind = kind, text = text, label = label,
                plantable = plantable, yours = yours, season = season, month = month,
            }
        end
    end
    table.sort(rows, function(a, c)
        if a.text == c.text then return a.kind < c.kind end
        return a.text < c.text
    end)
    return rows
end

function BridgeGardening.carriedSeedCount(body, kind)
    if BridgeFetch == nil or type(BridgeFetch.seedStock) ~= "function" then return 0 end
    local stock = nil
    pcall(function() stock = BridgeFetch.seedStock(false) end)
    local counts = stock ~= nil and stock[kind] or nil
    if counts == nil then return 0 end
    return math.floor(tonumber(counts.loose) or 0)
end

function BridgeGardening.plantableCount(kind)
    if BridgeFetch == nil or type(BridgeFetch.seedStock) ~= "function" then return 0 end
    local stock = nil
    pcall(function() stock = BridgeFetch.seedStock(false) end)
    local counts = stock ~= nil and stock[kind] or nil
    if counts == nil then return 0 end
    return math.floor(tonumber(counts.plantable) or 0)
end

function BridgeGardening.bagLists(body)
    local lists = {}
    if body == nil then return lists end
    pcall(function() lists[#lists + 1] = body:getInventory() end)
    if BridgeInventory ~= nil and type(BridgeInventory.wornBags) == "function" then
        pcall(function()
            for _, bag in ipairs(BridgeInventory.wornBags(body)) do
                local inv = nil
                pcall(function() inv = bag:getInventory() end)
                if inv ~= nil then lists[#lists + 1] = inv end
            end
        end)
    end
    return lists
end

local function itemFull(item)
    local full = nil
    pcall(function() full = item ~= nil and item:getFullType() or nil end)
    return full
end

local function itemId(item)
    local id = nil
    pcall(function() id = item ~= nil and item:getID() or nil end)
    return id
end

function BridgeGardening.looseCount(body, seedTypes)
    local total = 0
    local lists = BridgeGardening.bagLists(body)
    local want = {}
    for i = 1, #(seedTypes or {}) do want[seedTypes[i]] = true end
    for i = 1, #lists do
        local list = nil
        pcall(function() list = lists[i]:getItems() end)
        if list ~= nil then
            for j = 0, list:size() - 1 do
                local it = list:get(j)
                local full = itemFull(it)
                if full ~= nil and want[full] then
                    local n = 1
                    pcall(function() n = it:getCount() or 1 end)
                    total = total + math.max(1, math.floor(tonumber(n) or 1))
                end
            end
        end
    end
    return total
end

function BridgeGardening.firstSeedId(body, seedTypes)
    local want = {}
    for i = 1, #(seedTypes or {}) do want[seedTypes[i]] = true end
    local lists = BridgeGardening.bagLists(body)
    for i = 1, #lists do
        local list = nil
        pcall(function() list = lists[i]:getItems() end)
        if list ~= nil then
            for j = 0, list:size() - 1 do
                local it = list:get(j)
                local full = itemFull(it)
                if full ~= nil and want[full] then
                    local id = itemId(it)
                    if id ~= nil then return id end
                end
            end
        end
    end
    return nil
end

function BridgeGardening.firstPacket(body, entry)
    if entry == nil or #entry.packets == 0 then return nil, nil end
    local want = {}
    for i = 1, #entry.packets do want[entry.packets[i]] = true end
    local lists = BridgeGardening.bagLists(body)
    for i = 1, #lists do
        local list = nil
        pcall(function() list = lists[i]:getItems() end)
        if list ~= nil then
            for j = 0, list:size() - 1 do
                local it = list:get(j)
                local full = itemFull(it)
                if full ~= nil and want[full] then
                    local id = itemId(it)
                    if id ~= nil then return id, full end
                end
            end
        end
    end
    return nil, nil
end

function BridgeGardening.sowSpots(b)
    local list = {}
    if b == nil then return list end
    local cap = BridgeGardening.MAX_SOWS
    local pick = BridgeGardening.sowPick
    local kind = pick ~= nil and pick.kind or nil
    if kind ~= nil and BridgeFetch ~= nil and type(BridgeFetch.seedStock) == "function" then
        local stock = nil
        pcall(function() stock = BridgeFetch.seedStock(false) end)
        local counts = stock ~= nil and stock[kind] or nil
        if counts ~= nil then
            local plantable = math.floor(tonumber(counts.plantable) or 0)
            if plantable < cap then cap = plantable end
        end
    end
    if cap < 1 then return list end
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            if #list >= cap then return list end
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(x, y, b.z) end)
            if sq ~= nil then
                local plant = BridgeGardening.plantAt(sq, false)
                local state = nil
                pcall(function() state = plant ~= nil and plant.state or nil end)
                if state == "plow" then
                    list[#list + 1] = { x = x, y = y, z = b.z }
                end
            end
        end
    end
    return list
end

function BridgeGardening.sowMissing()
    local pick = BridgeGardening.sowPick
    local kind = pick ~= nil and pick.kind or nil
    if kind == nil then return "seeds" end
    if BridgeGardening.plantableCount(kind) <= 0 then return "seeds" end
    return nil
end

function BridgeGardening.resetSowTarget()
    local T = BridgeTask
    if T == nil then return end
    T.phase = nil
    T.sowStart = nil
    T.sowAnimStart = nil
    T.sowSoundId = nil
    T.sowEmitter = nil
    T.sowAnim = nil
    T.sowRestarts = nil
    T.animHold = 0
end

function BridgeGardening.clearSowState()
    local T = BridgeTask
    if T == nil then return end
    BridgeGardening.resetSowTarget()
    T.sowSaid = nil
    T.sowSayCheck = nil
    T.sowWorkSay = nil
    T.sowWorkSayCheck = nil
    T.sowDoneSaid = nil
    T.sowOutSaid = nil
    T.sowPending = nil
    T.sowWaitAt = nil
    T.sowPacket = nil
    T.sowPacketAt = nil
    T.sowReturnItems = nil
    T.sowReturnDest = nil
    T.sowReturnAt = nil
    T.sowReturnAct = nil
end

local function stopSowSound(body)
    local T = BridgeTask
    if T == nil then return end
    local id, emitter = T.sowSoundId, T.sowEmitter
    T.sowSoundId, T.sowEmitter = nil, nil
    if id == nil or emitter == nil or id == 0 then return end
    pcall(function() emitter:stopOrTriggerSound(id) end)
end

local function beginSow(body, target)
    local T = BridgeTask
    pcall(function() BridgeMove.stopPath(body) end)
    T.forceIdle(body)
    pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)
    T.sowAnim = T.LOOT_LOW or "LootLow"
    T.sowStart = Bridge.time
    T.sowAnimStart = Bridge.time
    T.sowRestarts = 0
    T.animHold = 0
    T.phase = "sow"
    pcall(function()
        body:setVariable("LootPosition", "Low")
        body:setVariable("BumpAnimFinished", false)
        body:setBumpType(T.sowAnim)
    end)
    local id = nil
    pcall(function()
        if BridgeSound ~= nil and type(BridgeSound.event) == "function" then
            id = BridgeSound.event(body, BridgeGardening.SOW_SOUND)
        end
    end)
    T.sowSoundId = id
    local emitter = nil
    pcall(function() emitter = body:getEmitter() end)
    T.sowEmitter = emitter
    log(string.format("sow start %d,%d anim=%s", target.x, target.y, tostring(T.sowAnim)))
end

function BridgeGardening.sowLocal(body, target, kind)
    local sq = BridgeGardening.squareAt(target)
    if sq == nil then return false, "gone" end
    local plant = BridgeGardening.plantAt(sq, true)
    if plant == nil then return false, "gone" end
    local state = nil
    pcall(function() state = plant.state end)
    if state ~= "plow" then return false, "noplow" end
    local skill = 0
    pcall(function() skill = BridgeSkills.level("Agriculture") end)
    local owner = nil
    if BridgeData ~= nil and type(BridgeData.owner) == "function" then
        pcall(function() owner = BridgeData.owner() end)
    end
    local ok, err = pcall(function()
        plant:seed(kind, skill)
        if owner ~= nil then plant.owner = owner:getPlayerNum() end
        plant:saveData()
    end)
    if not ok then
        warn("sow failed: " .. tostring(err))
        return false, "error"
    end
    return true, nil
end

function BridgeGardening.requestSow(target, kind)
    if target == nil or kind == nil then return end
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "sowSeeds",
            { x = target.x, y = target.y, z = target.z, kind = kind })
    end)
end

function BridgeGardening.requestOpenPacket(packetType)
    if packetType == nil then return end
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "openSeedPacket", { packetType = packetType })
    end)
end

local function stillHers(item)
    if item == nil then return false end
    local cont = nil
    pcall(function() cont = item:getContainer() end)
    if cont == nil then return false end
    local inside = false
    pcall(function()
        if BridgeInventory ~= nil and type(BridgeInventory.inBody) == "function" then
            inside = BridgeInventory.inBody(cont) == true
        end
    end)
    return inside
end

function BridgeGardening.restorePacket(body, packetType)
    if body == nil or packetType == nil then return end
    local dest = nil
    pcall(function() dest = body:getInventory() end)
    if dest == nil then return end
    pcall(function()
        local one = instanceItem(packetType)
        if one ~= nil then dest:AddItem(one) end
    end)
    pcall(function()
        if Bridge ~= nil and type(Bridge.itemsChanged) == "function" then Bridge.itemsChanged() end
        if Bridge ~= nil and type(Bridge.saveOutfit) == "function" then Bridge.saveOutfit() end
    end)
end

function BridgeGardening.openPacketLocal(body, packetId, packetType)
    local info = BridgeGardening.packetInfo(packetType)
    if info == nil then return false, "unknown" end
    if BridgeGunRules == nil or type(BridgeGunRules.removeItemById) ~= "function" then return false, "no rules" end
    local dest = nil
    pcall(function() dest = body:getInventory() end)
    if dest == nil then return false, "no bag" end
    if instanceItem(info.seed) == nil or instanceItem(info.empty) == nil then return false, "no item" end
    local got = nil
    pcall(function() got = BridgeGunRules.removeItemById(body, packetId) end)
    if got == nil then return false, "no packet" end
    local added = nil
    pcall(function() added = dest:AddItems(info.seed, BridgeGardening.SEEDS_PER_PACKET) end)
    local count = added ~= nil and added:size() or 0
    if count < BridgeGardening.SEEDS_PER_PACKET then
        if added ~= nil then
            pcall(function()
                for i = count - 1, 0, -1 do
                    local one = added:get(i)
                    if one ~= nil then dest:Remove(one) end
                end
            end)
        end
        BridgeGardening.restorePacket(body, packetType)
        return false, "no room"
    end
    local empty = nil
    pcall(function() empty = dest:AddItem(info.empty) end)
    if empty == nil then
        pcall(function()
            for i = 0, added:size() - 1 do
                local one = added:get(i)
                if one ~= nil then dest:Remove(one) end
            end
        end)
        BridgeGardening.restorePacket(body, packetType)
        return false, "no room"
    end
    pcall(function()
        if Bridge ~= nil and type(Bridge.itemsChanged) == "function" then Bridge.itemsChanged() end
        if Bridge ~= nil and type(Bridge.saveOutfit) == "function" then Bridge.saveOutfit() end
    end)
    log("opened " .. tostring(packetType) .. " into " .. tostring(BridgeGardening.SEEDS_PER_PACKET) .. " seeds")
    return true, nil
end

function BridgeGardening.leftovers(body)
    local out = {}
    if body == nil then return out end
    local pick = BridgeGardening.sowPick
    local kind = pick ~= nil and pick.kind or nil
    if kind == nil then return out end
    local t = BridgeGardening.seedTable()
    local entry = t.byKind[kind]
    if entry == nil then return out end
    local want = {}
    for i = 1, #entry.seeds do want[entry.seeds[i]] = true end
    for i = 1, #entry.packets do
        local info = t.byPacket[entry.packets[i]]
        if info ~= nil then want[info.empty] = true end
    end
    local lists = BridgeGardening.bagLists(body)
    for i = 1, #lists do
        local list = nil
        pcall(function() list = lists[i]:getItems() end)
        if list ~= nil then
            for j = 0, list:size() - 1 do
                local it = list:get(j)
                local full = itemFull(it)
                if full ~= nil and want[full] then out[#out + 1] = it end
            end
        end
    end
    return out
end

function BridgeGardening.returnDest(body)
    if body == nil then return nil end
    if BridgeDeposit == nil or type(BridgeDeposit.homeTargets) ~= "function" then return nil end
    local targets = nil
    pcall(function() targets = BridgeDeposit.homeTargets() end)
    if type(targets) ~= "table" then return nil end
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local best, bestD = nil, nil
    for i = 1, #targets do
        local t = targets[i]
        if t ~= nil and t.cont ~= nil then
            local usable = false
            pcall(function() usable = BridgeDeposit.destUsable(t) == true end)
            if usable then
                local d = (bx - (t.x or bx)) ^ 2 + (by - (t.y or by)) ^ 2 + 400 * math.abs(bz - (t.z or bz))
                if bestD == nil or d < bestD then best, bestD = t, d end
            end
        end
    end
    return best
end

function BridgeGardening.sowFinishStep(body, outOfSeeds)
    local T = BridgeTask
    if T == nil then return false end
    if (T.doneCount or 0) > 0 and not T.sowDoneSaid then
        T.sowDoneSaid = true
        sayLine("EvSowingDone", "SowingDone", BridgeGardening.SOW_SAY_COOLDOWN)
    end
    if outOfSeeds == true and not T.sowOutSaid then
        T.sowOutSaid = true
        if not sayLine("EvSowingOut", "SowingOut", BridgeGardening.SOW_SAY_COOLDOWN) then
            Bridge.speak("JobNoSeeds")
        end
    end
    local leftovers = BridgeGardening.leftovers(body)
    if #leftovers > 0 then
        local dest = BridgeGardening.returnDest(body)
        if dest ~= nil then
            T.phase = "return"
            T.current = { x = dest.x, y = dest.y, z = dest.z }
            T.spot = nil
            T.bestD = nil
            T.pathFails = 0
            T.pathFailTick = nil
            T.sowReturnItems = leftovers
            T.sowReturnDest = dest
            T.sowReturnAt = Bridge.time
            T.sowReturnAct = nil
            T.info = "return seeds"
            log("returning " .. tostring(#leftovers) .. " leftover item(s)")
            return true
        end
    end
    return T.finish()
end

function BridgeGardening.sowOutOfSeeds(body)
    local T = BridgeTask
    if T == nil then return false end
    T.queue = {}
    T.current = nil
    BridgeGardening.resetSowTarget()
    return BridgeGardening.sowFinishStep(body, true)
end

function BridgeGardening.openPacketStep(body, packetId, packetType)
    local T = BridgeTask
    if T == nil or packetId == nil or packetType == nil then return false end
    T.sowPacket = { id = packetId, t = packetType }
    T.sowPacketAt = Bridge.time
    T.info = "open packet"
    if Bridge ~= nil and Bridge.mp == true then
        T.phase = "packet"
        BridgeGardening.requestOpenPacket(packetType)
        log("seed packet requested: " .. tostring(packetType))
        return true
    end
    local ok, why = BridgeGardening.openPacketLocal(body, packetId, packetType)
    T.sowPacket = nil
    T.phase = nil
    if not ok then
        log("seed packet failed: " .. tostring(why))
        return BridgeGardening.sowOutOfSeeds(body)
    end
    return true
end

function BridgeGardening.commitSow(body, seedId)
    local T = BridgeTask
    if T == nil then return false end
    if seedId ~= nil and BridgeGunRules ~= nil and type(BridgeGunRules.removeItemById) == "function" then
        pcall(function() BridgeGunRules.removeItemById(body, seedId) end)
    end
    pcall(function()
        if Bridge ~= nil and type(Bridge.itemsChanged) == "function" then Bridge.itemsChanged() end
        if Bridge ~= nil and type(Bridge.saveOutfit) == "function" then Bridge.saveOutfit() end
    end)
    if BridgeGardening.SOW_XP > 0 then
        pcall(function() BridgeSkills.add("Agriculture", BridgeGardening.SOW_XP, "sow") end)
    end
    T.markDone()
    T.current = nil
    BridgeGardening.resetSowTarget()
    if #T.queue == 0 then return BridgeGardening.sowFinishStep(body, false) end
    return true
end

function BridgeGardening.sowReturn(body)
    local T = BridgeTask
    if T == nil or body == nil then return false end
    local dest = T.sowReturnDest
    if dest == nil then return T.finish() end
    local items = T.sowReturnItems or {}
    if T.sowReturnAct ~= nil then
        local pending = false
        for i = 1, #items do
            if stillHers(items[i]) then pending = true break end
        end
        if not pending then
            log("return seeds done")
            return T.finish()
        end
        if (Bridge.time - (T.sowReturnAt or Bridge.time)) > BridgeGardening.RETURN_TIMEOUT then
            log("return seeds timed out")
            return T.finish()
        end
        return true
    end
    if #items == 0 then return T.finish() end
    local walk, why = T.walkTo(body, T.current, BridgeGardening.SOW_RANGE, true)
    if walk == "unreachable" then
        log("return seeds unreachable: " .. tostring(why))
        return T.finish()
    end
    if walk ~= "arrived" then return true end
    pcall(function() BridgeMove.stopPath(body) end)
    T.forceIdle(body)
    local act = nil
    pcall(function() act = BridgeDeposit.depositItems(body, items, dest) end)
    if act == nil then
        log("return seeds unavailable")
        return T.finish()
    end
    T.sowReturnAct = act
    T.sowReturnAt = Bridge.time
    T.info = "returning seeds"
    return true
end

function BridgeGardening.sowUpdate(body)
    local T = BridgeTask
    if T == nil or body == nil then return false end
    if T.SOWING_ENABLED ~= 1 then return T.finish() end
    if BridgeMove ~= nil then BridgeMove.forcedWalk = "Walk" end

    local pick = BridgeGardening.sowPick
    local kind = pick ~= nil and pick.kind or nil
    local entry = kind ~= nil and BridgeGardening.seedTable().byKind[kind] or nil
    if entry == nil then return T.cancel("noSeeds") end

    if T.phase == "wait" then
        if T.sowPending == nil then
            T.phase = nil
        elseif (Bridge.time - (T.sowWaitAt or Bridge.time)) > BridgeGardening.PENDING_TIMEOUT then
            T.sowPending = nil
            T.info = "sow timeout"
            log("sow timeout")
            return T.cancel("sow timeout")
        end
        return true
    end

    if T.phase == "packet" then
        if T.sowPacket == nil then
            T.phase = nil
        elseif (Bridge.time - (T.sowPacketAt or Bridge.time)) > BridgeGardening.PENDING_TIMEOUT then
            T.sowPacket = nil
            T.info = "packet timeout"
            log("seed packet timeout")
            return T.cancel("packet timeout")
        end
        return true
    end

    if T.phase == "return" then return BridgeGardening.sowReturn(body) end

    if T.current == nil then
        if #T.queue == 0 then return BridgeGardening.sowFinishStep(body, false) end
        if BridgeGardening.looseCount(body, entry.seeds) <= 0 then
            local packetId, packetType = BridgeGardening.firstPacket(body, entry)
            if packetId ~= nil then
                return BridgeGardening.openPacketStep(body, packetId, packetType)
            end
            return BridgeGardening.sowOutOfSeeds(body)
        end
        local picked = BridgeGardening.nextTarget(body)
        if picked == nil then return BridgeGardening.sowFinishStep(body, false) end
        BridgeGardening.resetSowTarget()
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
    local plant = BridgeGardening.plantAt(sq, false)
    local state = nil
    pcall(function() state = plant ~= nil and plant.state or nil end)
    if state ~= "plow" then
        stopSowSound(body)
        BridgeGardening.clearAnim(body)
        BridgeGardening.resetSowTarget()
        T.info = "not plow"
        T.current = nil
        if #T.queue == 0 then return BridgeGardening.sowFinishStep(body, false) end
        return true
    end

    if not T.sowSaid then
        if (Bridge.time - (T.sowSayCheck or 0)) >= SECOND then
            T.sowSayCheck = Bridge.time
            if sayLine("EvSowing", "Sowing", BridgeGardening.SOW_SAY_COOLDOWN) then T.sowSaid = true end
        end
    end
    if T.phase ~= "walk" and T.sowSaid then
        if (Bridge.time - (T.sowWorkSayCheck or 0)) >= SECOND then
            T.sowWorkSayCheck = Bridge.time
            if (Bridge.time - (T.sowWorkSay or -99999)) >= BridgeGardening.SOW_WORK_SAY_COOLDOWN
                    and ZombRand(100) < BridgeGardening.SOW_WORK_SAY_CHANCE then
                if sayLine("EvSowingWork", "SowingWork", BridgeGardening.SOW_WORK_SAY_COOLDOWN) then
                    T.sowWorkSay = Bridge.time
                end
            end
        end
    end

    if T.phase == "settle" then
        if (Bridge.time - (T.settleAt or Bridge.time)) * T.ffMult() < (T.settleFor or 0) then return true end
        T.settled = true
    end
    if T.phase ~= "sow" then
        local walk, why = T.walkTo(body, target, BridgeGardening.SOW_RANGE, true)
        if walk == "unreachable" then return T.dropTarget(why) end
        if walk ~= "arrived" then return true end
        if (T.doneCount or 0) > 0 and T.settled ~= true then
            T.phase = "settle"
            T.settleAt = Bridge.time
            T.settleFor = BridgeGardening.SOW_SETTLE or 21
            T.info = "settling"
            return true
        end
        T.settled = nil
        beginSow(body, target)
        return true
    end

    local anim = T.sowAnim or T.LOOT_LOW or "LootLow"
    local animAge = (Bridge.time - (T.sowAnimStart or T.sowStart or Bridge.time)) * T.ffMult()
    if animAge >= T.SCRUB_GUARD then
        local playing = false
        pcall(function()
            playing = body:getActionStateName() == "bumped" and tostring(body:getBumpType()) == anim
        end)
        if not playing and (T.sowRestarts or 0) < 6 then
            T.sowRestarts = (T.sowRestarts or 0) + 1
            BridgeGardening.clearAnim(body)
            pcall(function()
                body:setVariable("BumpAnimFinished", false)
                body:setBumpType(anim)
            end)
            T.sowAnimStart = Bridge.time
            T.info = "sow anim restarted"
            return true
        end
    end
    local age = (Bridge.time - (T.sowStart or Bridge.time)) * T.ffMult()
    if age < BridgeGardening.SOW_TIME then return true end

    stopSowSound(body)
    BridgeGardening.clearAnim(body)

    local seedId = BridgeGardening.firstSeedId(body, entry.seeds)
    if seedId == nil then
        local packetId, packetType = BridgeGardening.firstPacket(body, entry)
        if packetId == nil then return BridgeGardening.sowOutOfSeeds(body) end
        return BridgeGardening.openPacketStep(body, packetId, packetType)
    end

    if Bridge ~= nil and Bridge.mp == true then
        T.sowPending = { x = target.x, y = target.y, z = target.z, kind = kind, seedId = seedId }
        T.sowWaitAt = Bridge.time
        T.phase = "wait"
        BridgeGardening.requestSow(target, kind)
        return true
    end

    local ok, why = BridgeGardening.sowLocal(body, target, kind)
    if not ok then
        if why == "noplow" or why == "gone" then
            BridgeGardening.resetSowTarget()
            T.current = nil
            if #T.queue == 0 then return BridgeGardening.sowFinishStep(body, false) end
            return true
        end
        return T.cancel("sow error")
    end
    return BridgeGardening.commitSow(body, seedId)
end

function BridgeGardening.sowLeave(body)
    local T = BridgeTask
    if T == nil then return end
    stopSowSound(body)
    BridgeGardening.clearAnim(body)
    BridgeGardening.clearSowState()
end

function BridgeGardening.onSowResult(args)
    local T = BridgeTask
    if T == nil or args == nil then return end
    if T.active ~= true or T.kind ~= "sowSeeds" then return end
    local pending = T.sowPending
    if pending == nil then return end
    if tonumber(args.x) ~= pending.x or tonumber(args.y) ~= pending.y then return end
    T.sowPending = nil
    local body = Bridge.body
    if args.ok == true then
        BridgeGardening.commitSow(body, pending.seedId)
        return
    end
    log("sow refused: " .. tostring(args.why))
    BridgeGardening.resetSowTarget()
    T.current = nil
    if #T.queue == 0 then BridgeGardening.sowFinishStep(body, false) end
end

function BridgeGardening.onSowPacketResult(args)
    local T = BridgeTask
    if T == nil or args == nil then return end
    if T.active ~= true or T.kind ~= "sowSeeds" then return end
    local pending = T.sowPacket
    if pending == nil then return end
    T.sowPacket = nil
    T.phase = nil
    local body = Bridge.body
    if args.ok == true then
        if BridgeGunRules ~= nil and type(BridgeGunRules.removeItemById) == "function" then
            pcall(function() BridgeGunRules.removeItemById(body, pending.id) end)
        end
        pcall(function()
            if Bridge ~= nil and type(Bridge.itemsChanged) == "function" then Bridge.itemsChanged() end
            if Bridge ~= nil and type(Bridge.saveOutfit) == "function" then Bridge.saveOutfit() end
        end)
        log("seed packet opened: " .. tostring(pending.t))
        return
    end
    log("seed packet refused: " .. tostring(args.why))
    BridgeGardening.sowOutOfSeeds(body)
end

function BridgeGardening.waterUsesFor(plant)
    if plant == nil then return 0 end
    local lvl = 100
    pcall(function() lvl = tonumber(plant.waterLvl) or 100 end)
    if lvl >= 100 then return 0 end
    local uses = math.ceil((100 - lvl) / 10)
    if uses < 1 then uses = 1 end
    local cap = BridgeGardening.WATER_MAX_USES or 10
    if uses > cap then uses = cap end
    return uses
end

function BridgeGardening.needsWater(plant)
    if plant == nil then return false end
    local ok = false
    pcall(function()
        local alive = plant:isAlive() == true
        local state = plant.state
        local seed = plant.typeOfSeed
        local lvl = tonumber(plant.waterLvl) or 0
        ok = alive and seed ~= nil and seed ~= "none"
            and state ~= "harvested" and state ~= "destroyed"
            and lvl < (BridgeGardening.WATER_THRESHOLD or 60)
    end)
    return ok
end

function BridgeGardening.waterSpots(b)
    local list = {}
    if b == nil then return list end
    local cap = BridgeGardening.MAX_WATER_PLANTS or 80
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            if #list >= cap then return list end
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(x, y, b.z) end)
            if sq ~= nil then
                local plant = BridgeGardening.plantAt(sq, false)
                if BridgeGardening.needsWater(plant) then
                    list[#list + 1] = { x = x, y = y, z = b.z }
                end
            end
        end
    end
    return list
end

function BridgeGardening.waterContainerRank(item)
    if item == nil then return 9 end
    local pour, full = nil, nil
    pcall(function() pour = item:getPourType() end)
    pcall(function() full = item:getFullType() end)
    local p = string.lower(tostring(pour or ""))
    local f = string.lower(tostring(full or ""))
    if p == "wateringcan" or string.find(f, "wateredcan", 1, true) ~= nil then return 1 end
    if p == "bucket" or string.find(f, "bucket", 1, true) ~= nil then return 2 end
    return 3
end

function BridgeGardening.isWaterContainer(item)
    if item == nil then return false end
    local ok = false
    pcall(function()
        local fc = item:getFluidContainer()
        if fc == nil then return end
        if item:canStoreWater() ~= true then return end
        local use = (BridgeGardening.WATER_PER_USE_ML or 200) / 1000
        local cap = fc:getCapacity()
        if type(cap) ~= "number" or cap < use then return end
        local amount = fc:getAmount() or 0
        if amount > 0 then
            local water = fc:contains(Fluid.Water) == true
                or (Fluid.TaintedWater ~= nil and fc:contains(Fluid.TaintedWater) == true)
            if not water then return end
        end
        ok = true
    end)
    return ok
end

function BridgeGardening.containerUses(item)
    if item == nil then return 0 end
    local uses = 0
    pcall(function()
        local fc = item:getFluidContainer()
        if fc == nil then return end
        local water = fc:contains(Fluid.Water) == true
            or (Fluid.TaintedWater ~= nil and fc:contains(Fluid.TaintedWater) == true)
        if not water then return end
        local amount = fc:getAmount() or 0
        local use = (BridgeGardening.WATER_PER_USE_ML or 200) / 1000
        if use <= 0 then return end
        uses = math.floor(amount / use)
    end)
    return uses
end

function BridgeGardening.findWaterContainer(b)
    if b == nil then return nil end
    local best, bestRank, bestUses = nil, nil, nil
    local function consider(it)
        if it == nil or not BridgeGardening.isWaterContainer(it) then return end
        local rank = BridgeGardening.waterContainerRank(it)
        local uses = BridgeGardening.containerUses(it)
        if best == nil or rank < bestRank or (rank == bestRank and uses > bestUses) then
            best, bestRank, bestUses = it, rank, uses
        end
    end
    local hand = nil
    pcall(function() hand = b:getPrimaryHandItem() end)
    consider(hand)
    pcall(function() hand = b:getSecondaryHandItem() end)
    consider(hand)
    local lists = BridgeGardening.bagLists(b)
    for i = 1, #lists do
        local items = nil
        pcall(function() items = lists[i]:getItems() end)
        if items ~= nil then
            for j = 0, items:size() - 1 do consider(items:get(j)) end
        end
    end
    return best
end

function BridgeGardening.useContainerWater(item, uses)
    local n = math.floor(tonumber(uses) or 0)
    if item == nil or n < 1 then return false end
    local ok = false
    pcall(function()
        local fc = item:getFluidContainer()
        if fc == nil then return end
        local amount = fc:getAmount() or 0
        local use = (BridgeGardening.WATER_PER_USE_ML or 200) / 1000
        local left = amount - n * use
        if left < 0 then left = 0 end
        fc:adjustAmount(left)
        ok = true
    end)
    if not ok then return false end
    pcall(function() item:syncItemFields() end)
    pcall(function() sendItemStats(item) end)
    pcall(function()
        if Bridge ~= nil and type(Bridge.itemsChanged) == "function" then Bridge.itemsChanged() end
        if Bridge ~= nil and type(Bridge.saveOutfit) == "function" then Bridge.saveOutfit() end
    end)
    return true
end

function BridgeGardening.waterAt(target, uses, server)
    if target == nil then return false, "notarget" end
    local n = math.floor(tonumber(uses) or 0)
    if n < 1 then return false, "nouses" end
    local sq = BridgeGardening.squareAt(target)
    local plant = BridgeGardening.plantAt(sq, true)
    if plant == nil and server ~= true then plant = BridgeGardening.plantAt(sq, false) end
    if plant == nil then return false, "noplant" end
    local water = nil
    pcall(function() water = plant.water end)
    if type(water) ~= "function" then return false, "nowater" end
    local ok, err = pcall(water, plant, nil, n)
    if not ok then return false, tostring(err) end
    pcall(function() plant:saveData() end)
    return true
end

function BridgeGardening.requestWater(target, uses)
    if target == nil then return false end
    local n = math.floor(tonumber(uses) or 0)
    if n < 1 then return false end
    if Bridge == nil or Bridge.mp ~= true or BridgeData == nil then return false end
    local red = nil
    pcall(function() red = BridgeData.owner() end)
    if red == nil then return false end
    local ok = pcall(function()
        sendClientCommand(red, "Bridge", "waterPlants",
            { x = target.x, y = target.y, z = target.z, uses = n })
    end)
    return ok == true
end

function BridgeGardening.onWaterResult(args)
    local T = BridgeTask
    if T == nil or args == nil then return end
    if T.active ~= true or T.kind ~= "waterPlants" then return end
    local pending = T.waterPending
    if pending == nil then return end
    if tonumber(args.x) ~= pending.x or tonumber(args.y) ~= pending.y then return end
    T.waterPending = nil
    T.waterPendingAt = nil
    if args.ok == true then
        BridgeGardening.useContainerWater(T.waterContainer, pending.uses)
        if pending.need ~= nil and (pending.uses or 0) < pending.need then
            table.insert(T.queue, 1, { x = pending.x, y = pending.y, z = pending.z })
        end
        T.waterUses = nil
        T.waterPhase = nil
        T.current = nil
        T.phase = nil
        T.waterNeed = nil
        T.waterApproachFor = nil
        T.markDone()
        return
    end
    log("water refused: " .. tostring(args.why))
    pcall(function() Bridge.speak("CantReachWater") end)
    T.waterUses = nil
    T.waterPhase = nil
    T.current = nil
    T.phase = nil
    T.waterApproachFor = nil
end

function BridgeGardening.waterSay(event, slot)
    return sayLine(event, slot)
end

function BridgeGardening.feedSay(event, slot)
    return sayLine(event, slot, BridgeGardening.FEED_SAY_COOLDOWN)
end

function BridgeGardening.feedSeasonOk()
    local seasons = false
    pcall(function()
        local opt = getSandboxOptions():getOptionByName("PlantGrowingSeasons")
        if opt ~= nil then seasons = opt:getValue() == true end
    end)
    if not seasons then return true end
    local season = nil
    pcall(function() season = getClimateManager():getSeasonName() end)
    if season == nil then return true end
    return tostring(season) ~= "Winter"
end

function BridgeGardening.needsFeed(plant)
    if plant == nil then return false end
    local ok = false
    pcall(function()
        local alive = plant:isAlive() == true
        local state = plant.state
        local seed = plant.typeOfSeed
        local grow = tonumber(plant.nbOfGrow) or 0
        local cursed = plant.cursed == true
        local composted = plant.compost == true
        local fert = tonumber(plant.fertilizer) or 0
        local fed = composted and fert >= 1
        ok = alive and seed ~= nil and seed ~= "none"
            and state == "seeded" and grow <= (BridgeGardening.FEED_YOUNG_GROWTH or 3)
            and not cursed and not fed
    end)
    if not ok then return false end
    return BridgeGardening.feedSeasonOk()
end

function BridgeGardening.isFeedItem(item)
    if item == nil then return false end
    local ok = false
    pcall(function()
        local uses = tonumber(item:getCurrentUses()) or 0
        if uses <= 0 then return end
        if ItemTag ~= nil and ItemTag.COMPOST ~= nil and item:hasTag(ItemTag.COMPOST) then
            ok = true
            return
        end
        if ItemTag ~= nil and ItemTag.FERTILIZER ~= nil and item:hasTag(ItemTag.FERTILIZER) then
            ok = true
            return
        end
        local kind = item:getType()
        if kind == "CompostBag" or kind == "Fertilizer" then ok = true end
    end)
    return ok
end

function BridgeGardening.feedKindOf(item)
    if item == nil then return nil end
    local kind = "fertilizer"
    pcall(function()
        if ItemTag ~= nil and ItemTag.COMPOST ~= nil and item:hasTag(ItemTag.COMPOST) then
            kind = "compost"
            return
        end
        if item:getType() == "CompostBag" then kind = "compost" end
    end)
    return kind
end

function BridgeGardening.findFeed(body, kind)
    if body == nil then return nil end
    local best, bestUses = nil, nil
    local function consider(it)
        if it == nil or not BridgeGardening.isFeedItem(it) then return end
        if kind ~= nil and BridgeGardening.feedKindOf(it) ~= kind then return end
        local uses = 0
        pcall(function() uses = tonumber(it:getCurrentUses()) or 0 end)
        if best == nil or uses > bestUses then
            best, bestUses = it, uses
        end
    end
    local hand = nil
    pcall(function() hand = body:getPrimaryHandItem() end)
    consider(hand)
    pcall(function() hand = body:getSecondaryHandItem() end)
    consider(hand)
    local lists = BridgeGardening.bagLists(body)
    for i = 1, #lists do
        local items = nil
        pcall(function() items = lists[i]:getItems() end)
        if items ~= nil then
            for j = 0, items:size() - 1 do consider(items:get(j)) end
        end
    end
    return best
end

function BridgeGardening.feedKindFor(plant, haveCompost, haveFertilizer)
    if plant == nil then return nil end
    local composted, fert = false, 0
    pcall(function()
        composted = plant.compost == true
        fert = tonumber(plant.fertilizer) or 0
    end)
    if haveCompost == true and not composted then return "compost" end
    if haveFertilizer == true and fert == 0 then return "fertilizer" end
    return nil
end

function BridgeGardening.feedSpots(b)
    local list = {}
    if b == nil then return list end
    local cap = BridgeGardening.MAX_FEED_PLANTS or 80
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            if #list >= cap then return list end
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(x, y, b.z) end)
            if sq ~= nil then
                local plant = BridgeGardening.plantAt(sq, false)
                if BridgeGardening.needsFeed(plant) then
                    list[#list + 1] = { x = x, y = y, z = b.z }
                end
            end
        end
    end
    return list
end

function BridgeGardening.fertilizeAt(target, compost, server)
    if target == nil then return false, "notarget" end
    local sq = BridgeGardening.squareAt(target)
    local plant = BridgeGardening.plantAt(sq, true)
    if plant == nil and server ~= true then plant = BridgeGardening.plantAt(sq, false) end
    if plant == nil then return false, "noplant" end
    if not BridgeGardening.needsFeed(plant) then return false, "nofeed" end
    local useCompost = compost == true
    local kind = BridgeGardening.feedKindFor(plant, useCompost, not useCompost)
    if kind == nil then return false, "nofeed" end
    local skill = 0
    pcall(function() skill = BridgeSkills.level("Agriculture") end)
    local ok, err = pcall(function()
        plant:fertilize({ compost = useCompost, skill = skill })
    end)
    if not ok then
        warn("fertilize failed: " .. tostring(err))
        return false, "error"
    end
    pcall(function() plant:saveData() end)
    return true, nil
end

function BridgeGardening.requestFertilize(target, compost)
    if target == nil then return false end
    if Bridge == nil or Bridge.mp ~= true or BridgeData == nil then return false end
    local red = nil
    pcall(function() red = BridgeData.owner() end)
    if red == nil then return false end
    local ok = pcall(function()
        sendClientCommand(red, "Bridge", "fertilizePlants",
            { x = target.x, y = target.y, z = target.z, compost = compost == true })
    end)
    return ok == true
end

function BridgeGardening.feedSpend(job)
    local item = job ~= nil and job.item or nil
    if item == nil then return false end
    local spent = false
    pcall(function()
        spent = BridgeCare ~= nil and BridgeCare.consume(item, false) == true
    end)
    pcall(function()
        if Bridge ~= nil and type(Bridge.itemsChanged) == "function" then Bridge.itemsChanged() end
    end)
    local saved = false
    pcall(function()
        if Bridge ~= nil and type(Bridge.saveOutfit) == "function" then
            saved = Bridge.saveOutfit() == true
        end
    end)
    if not saved and Bridge ~= nil then Bridge.itemsSpentAt = Bridge.time end
    return spent
end

function BridgeGardening.onFertilizeResult(args)
    local T = BridgeTask
    if T == nil or args == nil then return end
    if T.active ~= true or T.kind ~= "fertilizePlants" then return end
    local job = T.feedJob
    if job == nil or job.pending == nil then return end
    if tonumber(args.x) ~= job.pending.x or tonumber(args.y) ~= job.pending.y then return end
    local body = Bridge.body
    T.feedSoundStop(body)
    job.pending = nil
    job.pendingAt = nil
    if args.ok == true then
        BridgeTask.feedCommit(body, job)
        return
    end
    local why = tostring(args.why)
    log("fertilize refused: " .. why)
    T.feedClearTarget(job)
    if why == "error" then
        T.cancel("feed error")
        return
    end
    if why == "gone" or why == "noplant" then
        pcall(function() Bridge.speak("CantFeedCrop") end)
    end
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
        BridgeTask.kinds.sowSeeds = {
            available = function(body) return BridgeTask.SOWING_ENABLED == 1 end,
            missing = function(body) return BridgeGardening.sowMissing() end,
            update = function(body) return BridgeGardening.sowUpdate(body) end,
            leave = function(body) return BridgeGardening.sowLeave(body) end,
        }
        BridgeTask.kinds.waterPlants = {
            available = function(body) return BridgeTask.WATER_PLANTS_ENABLED == 1 end,
            missing = function(body)
                if BridgeGardening.findWaterContainer(body) == nil then return "waterContainer" end
                return nil
            end,
            update = function(body) return BridgeTask.waterUpdate(body) end,
            leave = function(body) return BridgeTask.waterLeave(body) end,
        }
        BridgeTask.kinds.fertilizePlants = {
            available = function(body) return BridgeTask.FEED_PLANTS_ENABLED == 1 end,
            missing = function(body)
                if BridgeGardening.findFeed(body) == nil then return "cropFeed" end
                return nil
            end,
            update = function(body) return BridgeTask.feedUpdate(body) end,
            leave = function(body) return BridgeTask.feedLeave(body) end,
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
        BridgeWorkSelect.kinds.sowSeeds = {
            collect = function(b) return BridgeGardening.sowSpots(b) end,
            max = BridgeGardening.MAX_SOWS,
            maxSide = 8,
            min = 1,
            noneSay = "JobNoSowSpots",
        }
        BridgeWorkSelect.kinds.waterPlants = {
            collect = function(b) return BridgeGardening.waterSpots(b) end,
            max = BridgeGardening.MAX_WATER_PLANTS,
            maxSide = 8,
            min = 1,
            noneSay = "JobNoWaterPlants",
        }
        BridgeWorkSelect.kinds.fertilizePlants = {
            collect = function(b) return BridgeGardening.feedSpots(b) end,
            max = BridgeGardening.MAX_FEED_PLANTS,
            maxSide = 8,
            min = 1,
            noneSay = "JobNoFeedSpots",
        }
    end
    log("kinds registered")
end

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(install) end)
end
