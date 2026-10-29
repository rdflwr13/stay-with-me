BridgeDeposit = BridgeDeposit or {}

local HOME_CAP = 240
local AREA_CAP = 80

local FUNCTIONAL_CATS = {
    ReceiveTool = true,
    ReceiveMeds = true,
    ReceiveElectronics = true,
    ReceiveAmmo = true,
}

local TYPE_AFFINITY = {
    ReceiveFood = { "fridge", "freezer", "cooler" },
    ReceiveCloth = { "wardrobe", "dresser", "closet", "drawer" },
    ReceiveAmmo = { "ammo", "gun", "weapon" },
    ReceiveMaterial = { "crate", "shelf", "counter", "storage" },
}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeDeposit] " .. tostring(text)) end end

local function owner() return BridgeData ~= nil and BridgeData.owner() or nil end
local function store() return Bridge ~= nil and Bridge.store or nil end
local function selfBody() return Bridge ~= nil and Bridge.body or nil end

local function itemType(item)
    local t = nil
    pcall(function() t = item:getType() end)
    return type(t) == "string" and t or nil
end

local function itemFull(item)
    local t = nil
    pcall(function() t = item:getFullType() end)
    return type(t) == "string" and t or nil
end

local function itemId(item)
    local id = nil
    pcall(function() id = item:getID() end)
    return id
end

local function itemWeight(item)
    if BridgeTask ~= nil and type(BridgeTask.lootWeight) == "function" then return BridgeTask.lootWeight(item) end
    local w = 0
    pcall(function() w = item:getUnequippedWeight() or 0 end)
    return tonumber(w) or 0
end

local function isContainerItem(item)
    local yes = false
    pcall(function() yes = item:IsInventoryContainer() == true end)
    return yes
end

local function containerEmpty(item)
    local n = 0
    pcall(function() n = item:getInventory():getItems():size() end)
    return n == 0
end

local function wornBagSet(body)
    local set = {}
    if BridgeInventory == nil or type(BridgeInventory.wornBags) ~= "function" then return set end
    pcall(function()
        for _, bag in ipairs(BridgeInventory.wornBags(body)) do set[bag] = true end
    end)
    return set
end

local function poolOf(item)
    local pool = nil
    pcall(function() pool = BridgeSocial.receivePool(item) end)
    return pool
end

local function catOf(item, pool)
    if item == nil then return nil end
    pool = pool or poolOf(item)
    local food, water, booze = false, false, false
    pcall(function() food = item:IsFood() == true end)
    pcall(function() water = item:isWaterSource() == true end)
    pcall(function() booze = item:isAlcoholic() == true end)
    if food or water or booze then return booze and "ReceiveBooze" or "ReceiveFood" end
    local cat = nil
    if BridgeData ~= nil then
        if pool ~= nil and pool ~= "ReceiveItem" then
            cat = BridgeData.LOOT_POOL_GROUP[pool]
            if cat == nil and BridgeData.LOOT_CAT_SET[pool] then cat = pool end
        end
        if cat == nil then cat = BridgeData.lootCatPrefix(item) end
        if cat == nil and pool ~= nil and BridgeData.LOOT_CAT_SET[pool] then cat = pool end
    end
    return cat
end

local function needMatch(id, item)
    local need = nil
    if BridgeFetch ~= nil and BridgeFetch.BY_ID ~= nil then need = BridgeFetch.BY_ID[id] end
    if need == nil or type(need.matches) ~= "function" then return false end
    local ok = false
    pcall(function() ok = need.matches(item) == true end)
    return ok
end

local function conditionOf(item)
    local c = 0
    pcall(function() c = item:getCondition() or 0 end)
    return tonumber(c) or 0
end

local function itemBusy(item)
    if BridgeInventory == nil then return false end
    local id = itemId(item)
    if id ~= nil then
        if type(BridgeInventory.pendingWear) == "function" then
            local w = nil
            pcall(function() w = BridgeInventory.pendingWear(item) end)
            if w ~= nil then return true end
        end
        if type(BridgeInventory.toWear) == "table" and BridgeInventory.toWear[id] ~= nil then return true end
        if type(BridgeInventory.pending) == "table" and BridgeInventory.pending[id] ~= nil then return true end
    end
    if type(BridgeInventory.taking) == "table" and BridgeInventory.taking[item] ~= nil then return true end
    return false
end

local function atHome(x, y, z)
    if BridgeHome == nil or type(BridgeHome.get) ~= "function" then return false end
    local h = BridgeHome.get()
    if h == nil or x == nil then return false end
    local all = false
    pcall(function() all = BridgeHome.allFloorsOn() == true end)
    local inside = false
    pcall(function() inside = BridgeData.homeHas(h, x, y, z, 0, all) == true end)
    return inside
end

local function bodyAtHome(body)
    if body == nil then return false end
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = body:getX(), body:getY(), body:getZ() end)
    return atHome(x, y, z)
end

local function assignedGun(rec, item)
    if rec == nil then return false end
    local id = tonumber(rec.gunId)
    if id ~= nil then return itemId(item) == id end
    if rec.gunType ~= nil then return itemFull(item) == rec.gunType end
    return false
end

function BridgeDeposit.storable(item, body, homeOk)
    if item == nil or body == nil then return false end
    local rec = store()
    local worn, equippedClothing, hands = false, false, false
    pcall(function()
        worn = body:isEquipped(item) == true
        equippedClothing = body:isEquippedClothing(item) == true
        hands = body:getPrimaryHandItem() == item or body:getSecondaryHandItem() == item
    end)
    if worn or equippedClothing or hands then return false end
    if BridgeWeapon ~= nil and type(BridgeWeapon.isAssigned) == "function" then
        local assigned = false
        pcall(function() assigned = BridgeWeapon.isAssigned(body, item) == true end)
        if assigned then return false end
    end
    if BridgeGear ~= nil and type(BridgeGear.locationOf) == "function" then
        local loc = nil
        pcall(function() loc = BridgeGear.locationOf(body, item) end)
        if loc ~= nil then return false end
    end
    if assignedGun(rec, item) then return false end
    if itemBusy(item) then return false end
    if isContainerItem(item) then
        if wornBagSet(body)[item] then return false end
        if not containerEmpty(item) then return false end
    end
    local pool = poolOf(item)
    local allowed = true
    pcall(function() allowed = BridgeData.storePoolAllowed(rec, pool, item) == true end)
    if not allowed then return false end
    if homeOk ~= true then
        local cat = catOf(item, pool)
        if cat ~= nil and FUNCTIONAL_CATS[cat] then return false end
    end
    return true
end

local function bestMelee(body, items)
    local best, bestC = nil, nil
    for i = 1, #items do
        local it = items[i]
        local melee = false
        pcall(function() melee = BridgeWeapon ~= nil and BridgeWeapon.isMelee(it) == true end)
        if melee then
            local c = conditionOf(it)
            if bestC == nil or c > bestC then best, bestC = it, c end
        end
    end
    return best
end

local function reserveIds(body, items)
    local keep = {}
    local rec = store()
    if BridgeData ~= nil and rec ~= nil and BridgeData.optionOf(rec, "storeKeepTools") then
        for _, id in ipairs({ "axe", "cutTool", "ashTool", "cleanImplement" }) do
            local best, bestC = nil, nil
            for i = 1, #items do
                local it = items[i]
                if needMatch(id, it) then
                    local c = conditionOf(it)
                    if bestC == nil or c > bestC then best, bestC = it, c end
                end
            end
            if best ~= nil then keep[best] = true end
        end
    end
    if BridgeData ~= nil and rec ~= nil and BridgeData.optionOf(rec, "storeKeepMeds") then
        for _, id in ipairs({ "bandage", "disinfectant" }) do
            for i = 1, #items do
                if needMatch(id, items[i]) then keep[items[i]] = true break end
            end
        end
    end
    if BridgeData ~= nil and rec ~= nil and BridgeData.optionOf(rec, "storeKeepLight") then
        for i = 1, #items do
            local it = items[i]
            local light, charge = false, 0
            pcall(function()
                light = BridgeTorchShared ~= nil and BridgeTorchShared.isFlashlight(it) == true
                if light then charge = BridgeTorchShared.charge(it) end
            end)
            if light and charge > 0 then keep[it] = true break end
        end
        for i = 1, #items do
            local it = items[i]
            if itemType(it) == "Battery" and BridgeTorchShared ~= nil then
                local charge = 0
                pcall(function() charge = BridgeTorchShared.charge(it) end)
                if charge > 0 then keep[it] = true break end
            end
        end
    end
    local assigned = nil
    if BridgeWeapon ~= nil and type(BridgeWeapon.assigned) == "function" then
        pcall(function() assigned = BridgeWeapon.assigned(body) end)
    end
    if assigned ~= nil then keep[assigned] = true
    else
        local best = bestMelee(body, items)
        if best ~= nil then keep[best] = true end
    end
    if BridgeGunRules ~= nil and type(BridgeGunRules.roundsOf) == "function" then
        for i = 1, #items do
            local rounds = 0
            pcall(function() rounds = BridgeGunRules.roundsOf(items[i]) or 0 end)
            if rounds > 0 then keep[items[i]] = true end
        end
    end
    return keep
end

function BridgeDeposit.storableItems(body)
    local out = {}
    if body == nil or BridgeData == nil then return out end
    local home = bodyAtHome(body)
    local invs = {}
    pcall(function() invs[#invs + 1] = body:getInventory() end)
    if BridgeInventory ~= nil and type(BridgeInventory.wornBags) == "function" then
        pcall(function()
            for _, bag in ipairs(BridgeInventory.wornBags(body)) do
                local inv = nil
                pcall(function() inv = bag:getInventory() end)
                if inv ~= nil then invs[#invs + 1] = inv end
            end
        end)
    end
    for i = 1, #invs do
        local list = nil
        pcall(function() list = invs[i]:getItems() end)
        if list ~= nil then
            for j = 0, list:size() - 1 do
                local item = list:get(j)
                if item ~= nil and BridgeDeposit.storable(item, body, home) then out[#out + 1] = item end
            end
        end
    end
    local keep = reserveIds(body, out)
    local filtered = {}
    for i = 1, #out do
        local it = out[i]
        if not keep[it] then filtered[#filtered + 1] = it end
    end
    table.sort(filtered, function(a, b) return itemWeight(a) < itemWeight(b) end)
    return filtered
end

local function reasonFor(item, body, homeOk, keep)
    local rec = store()
    local worn, equippedClothing, hands = false, false, false
    pcall(function()
        worn = body:isEquipped(item) == true
        equippedClothing = body:isEquippedClothing(item) == true
        hands = body:getPrimaryHandItem() == item or body:getSecondaryHandItem() == item
    end)
    if worn or equippedClothing or hands then return "equipped" end
    if BridgeWeapon ~= nil and type(BridgeWeapon.isAssigned) == "function" then
        local assigned = false
        pcall(function() assigned = BridgeWeapon.isAssigned(body, item) == true end)
        if assigned then return "assigned" end
    end
    if BridgeGear ~= nil and type(BridgeGear.locationOf) == "function" then
        local loc = nil
        pcall(function() loc = BridgeGear.locationOf(body, item) end)
        if loc ~= nil then return "attached" end
    end
    if assignedGun(rec, item) then return "assigned gun" end
    if itemBusy(item) then return "pending" end
    if isContainerItem(item) then
        if wornBagSet(body)[item] then return "worn bag" end
        if not containerEmpty(item) then return "container has items" end
    end
    local pool = poolOf(item)
    local allowed = true
    pcall(function() allowed = BridgeData.storePoolAllowed(rec, pool, item) == true end)
    if not allowed then return "category off" end
    if homeOk ~= true then
        local cat = catOf(item, pool)
        if cat ~= nil and FUNCTIONAL_CATS[cat] then return "home only" end
    end
    if keep[item] then return "reserved" end
    return "storable"
end

function BridgeDeposit.explain(body)
    local out = {}
    if body == nil then return out end
    local home = bodyAtHome(body)
    local seen = {}
    local invs = {}
    pcall(function() invs[#invs + 1] = body:getInventory() end)
    if BridgeInventory ~= nil and type(BridgeInventory.wornBags) == "function" then
        pcall(function()
            for _, bag in ipairs(BridgeInventory.wornBags(body)) do
                local inv = nil
                pcall(function() inv = bag:getInventory() end)
                if inv ~= nil then invs[#invs + 1] = inv end
            end
        end)
    end
    local all, candidates = {}, {}
    for i = 1, #invs do
        local items = nil
        pcall(function() items = invs[i]:getItems() end)
        if items ~= nil then
            for j = 0, items:size() - 1 do
                local item = items:get(j)
                if item ~= nil and not seen[item] then
                    seen[item] = true
                    all[#all + 1] = item
                    if BridgeDeposit.storable(item, body, home) then candidates[#candidates + 1] = item end
                end
            end
        end
    end
    local keep = reserveIds(body, candidates)
    for i = 1, #all do
        local item = all[i]
        local reason = nil
        if BridgeDeposit.storable(item, body, home) then
            reason = keep[item] and "reserved" or "storable"
        else
            reason = reasonFor(item, body, home, keep)
        end
        out[#out + 1] = string.format("%s=%s", tostring(itemFull(item)), reason)
    end
    return out
end

local function burningSquare(x, y, z)
    local burn = false
    pcall(function()
        local sq = getCell():getGridSquare(x, y, z)
        if sq ~= nil then burn = sq:has(IsoFlagType.burning) == true end
    end)
    return burn
end

local function lockedTo(obj, player)
    if obj == nil then return false end
    local locked = false
    pcall(function()
        locked = instanceof(obj, "IsoThumpable") and obj:isLockedToCharacter(player) == true
    end)
    return locked
end

function BridgeDeposit.destUsable(t)
    if type(t) ~= "table" or t.cont == nil then return false end
    if t.kind == "floor" or t.kind == "body" then return false end
    local hers = false
    pcall(function() hers = BridgeInventory.isHers(t.cont) or BridgeInventory.inBody(t.cont) end)
    if hers then return false end
    if burningSquare(t.x, t.y, t.z) then return false end
    local obj = t.obj
    if obj ~= nil and lockedTo(obj, owner()) then return false end
    return true
end

local function destRefOf(cont)
    local ref = nil
    if BridgeInventory ~= nil and type(BridgeInventory.destRef) == "function" then
        pcall(function() ref = BridgeInventory.destRef(cont) end)
    end
    return ref
end

local function newTarget(cont, x, y, z, kind, obj)
    if cont == nil then return nil end
    return { x = x, y = y, z = z, kind = kind or "obj", cont = cont, ref = destRefOf(cont), obj = obj }
end

local function vehicleTargets(o, list, seen, player, cap)
    local pc = 0
    pcall(function() pc = o:getPartCount() end)
    for pi = 0, pc - 1 do
        if #list >= cap then return end
        local part = nil
        pcall(function() part = o:getPartByIndex(pi) end)
        if part ~= nil then
            local c = nil
            local id = ""
            pcall(function() c = part:getItemContainer() end)
            pcall(function() id = tostring(part:getId()) end)
            id = string.lower(id)
            local trunk = string.find(id, "trunk", 1, true) ~= nil
                or string.find(id, "truckbed", 1, true) ~= nil
            local access = true
            pcall(function() access = player == nil or o:canAccessContainer(pi, player) ~= false end)
            if c ~= nil and trunk and access and not seen[c] then
                seen[c] = true
                local sq = nil
                pcall(function() sq = o:getSquare() end)
                if sq == nil then pcall(function() sq = part:getSquare() end) end
                local x, y, z = 0, 0, 0
                if sq ~= nil then x, y, z = sq:getX(), sq:getY(), sq:getZ() end
                list[#list + 1] = newTarget(c, x, y, z, "veh", o)
            end
        end
    end
end

local function objectTargets(o, list, seen, player, cap)
    if o == nil then return end
    if lockedTo(o, player) then return end
    local n = 0
    pcall(function() n = o:getContainerCount() end)
    for j = 0, n - 1 do
        if #list >= cap then return end
        local c = nil
        pcall(function() c = o:getContainerByIndex(j) end)
        if c ~= nil and not seen[c] then
            seen[c] = true
            local sq = nil
            pcall(function() sq = o:getSquare() end)
            if sq == nil then pcall(function() sq = c:getSourceGrid() end) end
            local x, y, z = 0, 0, 0
            if sq ~= nil then x, y, z = sq:getX(), sq:getY(), sq:getZ() end
            list[#list + 1] = newTarget(c, x, y, z, "obj", o)
        end
    end
end

local function squareTargets(sq, list, seen, player, cap)
    if sq == nil then return end
    if burningSquare(sq:getX(), sq:getY(), sq:getZ()) then return end
    pcall(function()
        local objs = sq:getObjects()
        if objs ~= nil then
            for i = 0, objs:size() - 1 do
                if #list >= cap then return end
                objectTargets(objs:get(i), list, seen, player, cap)
            end
        end
    end)
    pcall(function()
        local objs = sq:getSpecialObjects()
        if objs ~= nil then
            for i = 0, objs:size() - 1 do
                if #list >= cap then return end
                objectTargets(objs:get(i), list, seen, player, cap)
            end
        end
    end)
    pcall(function()
        local veh = sq:getVehicleContainer()
        if veh ~= nil and not seen[veh] then
            seen[veh] = true
            vehicleTargets(veh, list, seen, player, cap)
        end
    end)
end

function BridgeDeposit.targetsIn(b, cap)
    local list = {}
    if type(b) ~= "table" then return list end
    cap = tonumber(cap) or AREA_CAP
    local seen = {}
    local player = owner()
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            if #list >= cap then return list end
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(x, y, b.z) end)
            squareTargets(sq, list, seen, player, cap)
        end
    end
    return list
end

function BridgeDeposit.targetsForObject(o)
    local list = {}
    if o == nil then return list end
    local dead = false
    pcall(function() dead = instanceof(o, "IsoDeadBody") == true end)
    if dead then return list end
    local seen = {}
    local player = owner()
    local veh = false
    pcall(function() veh = instanceof(o, "BaseVehicle") == true end)
    if veh then
        vehicleTargets(o, list, seen, player, AREA_CAP)
        return list
    end
    objectTargets(o, list, seen, player, AREA_CAP)
    return list
end

function BridgeDeposit.targetsUnder(worldobjects)
    local list = {}
    if type(worldobjects) ~= "table" then return list end
    local seen = {}
    local player = owner()
    for _, o in ipairs(worldobjects) do
        if #list >= AREA_CAP then break end
        local more = BridgeDeposit.targetsForObject(o)
        for i = 1, #more do
            local t = more[i]
            if t.cont ~= nil and not seen[t.cont] then
                seen[t.cont] = true
                list[#list + 1] = t
            end
        end
    end
    if #list == 0 then
        local sq = nil
        for _, o in ipairs(worldobjects) do
            pcall(function() sq = o:getSquare() end)
            if sq ~= nil then break end
        end
        if sq ~= nil then squareTargets(sq, list, seen, player, AREA_CAP) end
    end
    return list
end

function BridgeDeposit.homeTargets()
    local list = {}
    if BridgeHome == nil or type(BridgeHome.get) ~= "function" then return list end
    local h = BridgeHome.get()
    if h == nil then return list end
    local floors = nil
    pcall(function() floors = BridgeHome.includedFloors(h, BridgeHome.allFloorsOn()) end)
    if floors == nil or #floors == 0 then floors = { h.z } end
    local player = owner()
    local seen = {}
    for fi = 1, #floors do
        if #list >= HOME_CAP then break end
        local z = floors[fi]
        for x = h.x, h.x + h.w - 1 do
            if #list >= HOME_CAP then break end
            for y = h.y, h.y + h.h - 1 do
                if #list >= HOME_CAP then break end
                local sq = nil
                pcall(function() sq = getCell():getGridSquare(x, y, z) end)
                if sq ~= nil and BridgeData.homeBuildingOk(h, sq) then
                    squareTargets(sq, list, seen, player, HOME_CAP)
                end
            end
        end
    end
    return list
end

BridgeDeposit.contIds = BridgeDeposit.contIds or setmetatable({}, { __mode = "k" })
BridgeDeposit.contSeq = BridgeDeposit.contSeq or 0

local function contId(c)
    if c == nil then return "?" end
    local id = BridgeDeposit.contIds[c]
    if id == nil then
        BridgeDeposit.contSeq = BridgeDeposit.contSeq + 1
        id = BridgeDeposit.contSeq
        BridgeDeposit.contIds[c] = id
    end
    return id
end

local function refKey(t)
    local r = t.ref
    if type(r) == "table" then
        return string.format("%s:%s:%s:%s:%s:%s:%s:%s", tostring(r.kind), tostring(r.x), tostring(r.y),
            tostring(r.z), tostring(r.v), tostring(r.p), tostring(r.o), tostring(contId(t.cont)))
    end
    return string.format("%d:%d:%d:%s", t.x or 0, t.y or 0, t.z or 0, tostring(contId(t.cont)))
end

local function currentHome()
    if BridgeHome == nil or type(BridgeHome.get) ~= "function" then return nil end
    return BridgeHome.get()
end

local function refAtHome(ref)
    local h = currentHome()
    if h == nil or type(ref) ~= "table" then return false end
    local all = false
    pcall(function() all = BridgeHome.allFloorsOn() == true end)
    local inside = false
    pcall(function() inside = BridgeData.homeHas(h, ref.x, ref.y, ref.z, 0, all) == true end)
    return inside
end

function BridgeDeposit.targetAtHome(t)
    return t ~= nil and refAtHome(t.ref or t)
end

function BridgeDeposit.resolveStoredRef(ref)
    local key = BridgeData.storeRefKey(ref)
    if key == nil then return nil end
    local kind = ref.kind
    if kind == "body" or kind == "floor" then return nil end
    local h = currentHome()
    if h == nil then return nil end
    local x, y, z = tonumber(ref.x), tonumber(ref.y), tonumber(ref.z)
    if x == nil or y == nil or z == nil then return nil end
    local cont, obj = nil, nil
    local tx, ty, tz = math.floor(x), math.floor(y), math.floor(z)
    if kind == "obj" then
        local sq = nil
        pcall(function() sq = getCell():getGridSquare(tx, ty, tz) end)
        if sq == nil then return nil end
        local objs = nil
        pcall(function() objs = sq:getObjects() end)
        if objs == nil then return nil end
        local o = nil
        pcall(function() o = objs:get(tonumber(ref.o) or -1) end)
        if o == nil then return nil end
        if tonumber(ref.c) ~= nil and tonumber(ref.c) >= 0 then
            pcall(function() cont = o:getContainerByIndex(tonumber(ref.c)) end)
        else
            pcall(function() cont = o:getContainer() end)
        end
        obj = o
    else
        local v = nil
        pcall(function() v = getVehicleById(ref.v) end)
        if v == nil then return nil end
        local part = nil
        pcall(function() part = v:getPartById(tostring(ref.p)) end)
        if part == nil then return nil end
        local access = true
        pcall(function() access = v:canAccessContainer(part:getIndex(), owner()) ~= false end)
        if not access then return nil end
        pcall(function() cont = part:getItemContainer() end)
        obj = v
        pcall(function() tx, ty, tz = math.floor(v:getX()), math.floor(v:getY()), math.floor(v:getZ()) end)
    end
    if cont == nil then return nil end
    local all = false
    pcall(function() all = BridgeHome.allFloorsOn() == true end)
    local inHome = false
    pcall(function() inHome = BridgeData.homeHas(h, tx, ty, tz, 0, all) == true end)
    if not inHome then return nil end
    local t = newTarget(cont, tx, ty, tz, kind, obj)
    if t == nil or not BridgeDeposit.destUsable(t) then return nil end
    t.marked = true
    return t
end

function BridgeDeposit.sendStoreRefs()
    if Bridge == nil or Bridge.store == nil then return end
    local refs = BridgeData.cleanStoreRefs(Bridge.store.storeRefs) or {}
    Bridge.store.storeRefs = refs
    if Bridge.mp then
        pcall(function() sendClientCommand(owner(), "Bridge", "state", { storeRefs = refs }) end)
    end
end

function BridgeDeposit.markedTargets(prune)
    local list, kept = {}, {}
    local rec = store()
    local refs = type(rec) == "table" and type(rec.storeRefs) == "table" and rec.storeRefs or {}
    for i = 1, #refs do
        local t = BridgeDeposit.resolveStoredRef(refs[i])
        if t ~= nil then
            list[#list + 1] = t
            kept[#kept + 1] = refs[i]
        end
    end
    local pruned = #refs - #kept
    if prune ~= false and pruned > 0 and BridgeDeposit.homeHere() then
        rec.storeRefs = kept
        BridgeDeposit.sendStoreRefs()
        log(string.format("marked prune removed=%d total=%d", pruned, #kept))
    end
    log(string.format("marked resolve total=%d valid=%d pruned=%d", #refs, #list, pruned))
    return list
end

function BridgeDeposit.depositTargets()
    return BridgeDeposit.markedTargets()
end

function BridgeDeposit.markedCount()
    local rec = store()
    if type(rec) ~= "table" or type(rec.storeRefs) ~= "table" then return 0 end
    return #rec.storeRefs
end

function BridgeDeposit.hasValidMarks()
    if not BridgeDeposit.homeHere() then return false end
    return #BridgeDeposit.markedTargets(false) > 0
end

function BridgeDeposit.isMarked(cont)
    if cont == nil or BridgeInventory == nil then return false end
    local ref = nil
    pcall(function() ref = BridgeInventory.destRef(cont) end)
    return BridgeData.storeRefInList(store(), ref)
end

function BridgeDeposit.toggleMark(cont)
    if not BridgeDeposit.homeHere() then return nil end
    local ref = nil
    pcall(function() ref = BridgeInventory.destRef(cont) end)
    local key = BridgeData.storeRefKey(ref)
    if key == nil or ref.kind == "body" or ref.kind == "floor" then return nil end
    if not refAtHome(ref) then return nil end
    local rec = store()
    local refs = BridgeData.cleanStoreRefs(rec.storeRefs) or {}
    local found = false
    for i = 1, #refs do
        if BridgeData.storeRefKey(refs[i]) == key then
            table.remove(refs, i)
            found = true
            break
        end
    end
    if not found then
        refs[#refs + 1] = ref
        refs = BridgeData.cleanStoreRefs(refs)
    end
    rec.storeRefs = refs
    BridgeDeposit.sendStoreRefs()
    log(string.format("mark %s key=%s total=%d", found and "remove" or "add", key, #refs))
    return not found
end

function BridgeDeposit.seedMarks()
    if not BridgeDeposit.homeHere() then return 0 end
    local rec = store()
    local refs = BridgeData.cleanStoreRefs(rec.storeRefs) or {}
    local seen = {}
    for i = 1, #refs do seen[BridgeData.storeRefKey(refs[i])] = true end
    local added = 0
    local list = BridgeDeposit.homeTargets()
    for i = 1, #list do
        local ref = list[i].ref
        local key = BridgeData.storeRefKey(ref)
        if key ~= nil and not seen[key] then
            refs[#refs + 1] = ref
            seen[key] = true
            added = added + 1
        end
    end
    refs = BridgeData.cleanStoreRefs(refs)
    rec.storeRefs = refs
    BridgeDeposit.sendStoreRefs()
    log(string.format("mark seed added=%d total=%d", added, #refs))
    return added
end

function BridgeDeposit.clearMarks()
    local rec = store()
    if rec == nil then return end
    rec.storeRefs = {}
    BridgeDeposit.sendStoreRefs()
    log("mark clear")
end

local function containerContents(cont)
    local full, cats, n = {}, {}, 0
    pcall(function()
        local list = cont:getItems()
        if list == nil then return end
        n = list:size()
        for i = 0, n - 1 do
            local it = list:get(i)
            if it ~= nil then
                local f = itemFull(it)
                if f ~= nil then full[f] = true end
                local cat = catOf(it)
                if cat ~= nil then cats[cat] = true end
            end
        end
    end)
    return { full = full, cats = cats, n = n }
end

function BridgeDeposit.refreshIndex(job)
    if job == nil then return end
    local dests = {}
    for i = 1, #job.dests do
        local t = job.dests[i]
        if BridgeDeposit.destUsable(t) then
            local c = containerContents(t.cont)
            t._full, t._cats, t._n = c.full, c.cats, c.n
            dests[#dests + 1] = t
        end
    end
    job.dests = dests
end

local function freeSpace(t, item, player)
    local cap, load = nil, 0
    pcall(function() cap = t.cont:getEffectiveCapacity(player or getSpecificPlayer(0)) end)
    pcall(function() load = t.cont:getContentsWeight() end)
    if type(cap) ~= "number" or cap <= 0 then return nil end
    if type(load) ~= "number" then load = 0 end
    pcall(function() load = ItemContainer.floatingPointCorrection(load) end)
    return cap - load - itemWeight(item)
end

local function affinityRank(cat, t)
    if cat == nil then return 0 end
    local want = TYPE_AFFINITY[cat]
    if want == nil then return 0 end
    local kind = ""
    pcall(function() kind = string.lower(tostring(t.cont:getType())) end)
    for i = 1, #want do
        if string.find(kind, want[i], 1, true) ~= nil then
            BridgeDeposit.affinitySeen = BridgeDeposit.affinitySeen or {}
            local key = cat .. "|" .. kind
            if not BridgeDeposit.affinitySeen[key] then
                BridgeDeposit.affinitySeen[key] = true
                log("container affinity " .. tostring(cat) .. " type=" .. tostring(kind))
            end
            return 1
        end
    end
    return 0
end

function BridgeDeposit.scoreDest(job, item)
    local player = owner()
    local body = job.body or selfBody()
    local cat = catOf(item)
    local full = itemFull(item)
    local match = BridgeData.optionOf(store(), "storeMatch") == true
    local best, bestScore = nil, nil
    for i = 1, #job.dests do
        local t = job.dests[i]
        if not job.bad[refKey(t)] then
            local fits = false
            pcall(function()
                fits = t.cont:hasRoomFor(player, item) ~= false and t.cont:isItemAllowed(item) ~= false
            end)
            if fits then
                local tier = 4
                if match then
                    if full ~= nil and t._full ~= nil and t._full[full] then
                        tier = 1
                    elseif cat ~= nil and t._cats ~= nil and t._cats[cat] then
                        tier = 2
                    elseif (t._n or 0) == 0 then
                        tier = affinityRank(cat, t) > 0 and 3 or 3.5
                    end
                end
                local free = freeSpace(t, item, player)
                if free == nil or free >= -0.001 then
                    local enclose = false
                    if job.bodyKey ~= nil then
                        local sq = nil
                        pcall(function() sq = getCell():getGridSquare(t.x, t.y, t.z) end)
                        if sq ~= nil then
                            local k = nil
                            pcall(function() k = BridgeDoors.enclosureKey(sq) end)
                            enclose = k == job.bodyKey
                        end
                    end
                    local dx, dy = 0, 0
                    if body ~= nil then dx, dy = body:getX() - (t.x + 0.5), body:getY() - (t.y + 0.5) end
                    local dist = math.sqrt(dx * dx + dy * dy) + 20 * math.abs((t.z or 0) - (body ~= nil and math.floor(body:getZ()) or 0))
                    local score = {
                        t = t,
                        tier = tier,
                        free = free or math.huge,
                        enclose = enclose,
                        dist = dist,
                        key = refKey(t),
                    }
                    local better = false
                    if bestScore == nil then
                        better = true
                    elseif score.tier ~= bestScore.tier then
                        better = score.tier < bestScore.tier
                    elseif not match then
                        if math.abs(score.dist - bestScore.dist) > 0.001 then
                            better = score.dist < bestScore.dist
                        elseif math.abs(score.free - bestScore.free) > 0.001 then
                            better = score.free < bestScore.free
                        elseif score.enclose ~= bestScore.enclose then
                            better = score.enclose
                        else
                            better = score.key < bestScore.key
                        end
                    elseif math.abs(score.free - bestScore.free) > 0.001 then
                        better = score.free < bestScore.free
                    elseif score.enclose ~= bestScore.enclose then
                        better = score.enclose
                    elseif math.abs(score.dist - bestScore.dist) > 0.001 then
                        better = score.dist < bestScore.dist
                    else
                        better = score.key < bestScore.key
                    end
                    if better then best, bestScore = score.t, score end
                end
            end
        end
    end
    return best
end

local function itemInHer(item)
    local src = nil
    pcall(function() src = item:getContainer() end)
    if src == nil then return false end
    local ok = false
    pcall(function()
        ok = BridgeInventory ~= nil and (BridgeInventory.inBody(src) or BridgeInventory.isHers(src))
    end)
    return ok
end

local function compact(list)
    local out = {}
    for i = 1, #list do
        if list[i] ~= nil then out[#out + 1] = list[i] end
    end
    return out
end

local function refreshPanels()
    pcall(function()
        local inv, loot = getPlayerInventory(0), getPlayerLoot(0)
        if inv ~= nil then inv:refreshBackpacks() end
        if loot ~= nil then loot:refreshBackpacks() end
        ISInventoryPage.renderDirty = true
    end)
end
BridgeDeposit.refreshPanels = refreshPanels

local function saveOutfit()
    pcall(function() if Bridge ~= nil and type(Bridge.saveOutfit) == "function" then Bridge.saveOutfit() end end)
end

local function sayFor(job, item)
    if job == nil or item == nil then return end
    local cat = catOf(item) or "ReceiveItem"
    if job.said[cat] then return end
    job.said[cat] = true
    pcall(function() BridgeTask.lootSay(item, nil) end)
end

local function stillPresent(body, item)
    if item == nil then return false end
    if not itemInHer(item) then return false end
    return BridgeDeposit.storable(item, body, bodyAtHome(body))
end

function BridgeDeposit.clear()
    BridgeDeposit.job = nil
    BridgeDeposit.pending = nil
    if BridgeTask ~= nil and type(BridgeTask.lootAbortAct) == "function" then pcall(BridgeTask.lootAbortAct) end
    if BridgeMove ~= nil then BridgeMove.holdDoors = false end
end

local function initJob(body, pending)
    local job = pending
    job.body = body
    job.said = job.said or {}
    job.bad = {}
    job.blocked = {}
    job.full = false
    local key = nil
    pcall(function() key = BridgeDoors.enclosureKey(body:getCurrentSquare()) end)
    job.bodyKey = key
    local items = {}
    for i = 1, #(job.items or {}) do
        local it = job.items[i]
        if it ~= nil and stillPresent(body, it) then items[#items + 1] = it end
    end
    job.items = items
    if job.dests == nil then job.dests = {} end
    BridgeDeposit.refreshIndex(job)
    job.count = job.count or 0
    BridgeTask.depositFull = false
    BridgeTask.depositCount = job.count
    if job.remote ~= true and BridgeMove ~= nil then
        BridgeMove.forcedWalk = "Walk"
        BridgeMove.holdDoors = true
    end
    return job
end

function BridgeDeposit.start(destTargets, opts)
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 or BridgeTask.DEPOSIT_ENABLED ~= 1 then return "disabled" end
    local cfg = opts or {}
    local body = selfBody()
    if body == nil then return "no body" end
    local items = BridgeDeposit.storableItems(body)
    if #items == 0 then
        local why = BridgeDeposit.explain(body)
        if #why == 0 then
            log("unavailable: nothing carried")
        else
            local shown = {}
            for i = 1, math.min(#why, 12) do shown[#shown + 1] = why[i] end
            if #why > 12 then shown[#shown + 1] = string.format("+%d more", #why - 12) end
            log("unavailable: nothing storable; " .. table.concat(shown, ", "))
        end
        if Bridge ~= nil then Bridge.speak("JobNoStore") end
        return "unavailable"
    end
    local dests = nil
    if type(destTargets) == "table" then dests = destTargets
    else dests = BridgeDeposit.homeTargets() end
    if Bridge.mp then
        local only = {}
        for i = 1, #dests do
            if dests[i] ~= nil and type(dests[i].ref) == "table" then only[#only + 1] = dests[i] end
        end
        dests = only
    end
    local pending = { items = items, dests = dests, remote = cfg.remote == true, said = {}, bad = {}, count = 0 }
    local probe = { body = body, dests = dests, bad = {}, bodyKey = nil }
    pcall(function() probe.bodyKey = BridgeDoors.enclosureKey(body:getCurrentSquare()) end)
    BridgeDeposit.refreshIndex(probe)
    local fit = false
    for i = 1, #items do
        if BridgeDeposit.scoreDest(probe, items[i]) ~= nil then fit = true break end
    end
    if not fit then
        log(string.format("unavailable: no destination fits %d item(s) in %d container(s)", #items, #dests))
        if Bridge ~= nil then
            if cfg.home == true and #dests == 0 then Bridge.speak("JobNoMarked") else Bridge.speak("JobNoStorage") end
        end
        return "unavailable"
    end
    BridgeDeposit.pending = pending
    local res = BridgeTask.start("deposit", {}, nil, nil)
    if res ~= "started" then
        BridgeDeposit.pending = nil
        log("deposit start failed: " .. tostring(res))
    end
    return res
end

function BridgeDeposit.startHome()
    local targets = BridgeDeposit.depositTargets()
    log(string.format("startHome stored=%d resolved=%d", BridgeDeposit.markedCount(), #targets))
    return BridgeDeposit.start(targets, { remote = true, home = true })
end

function BridgeDeposit.homeHere()
    local h = nil
    if BridgeHome ~= nil and type(BridgeHome.get) == "function" then h = BridgeHome.get() end
    if h == nil then return false end
    local red = owner()
    local body = selfBody()
    if red == nil or body == nil then return false end
    local rx, ry, rz = nil, nil, nil
    local bx, by, bz = nil, nil, nil
    pcall(function() rx, ry, rz = red:getX(), red:getY(), red:getZ() end)
    pcall(function() bx, by, bz = body:getX(), body:getY(), body:getZ() end)
    return atHome(rx, ry, rz) and atHome(bx, by, bz)
end

local function finishJob(job)
    BridgeTask.depositCount = job ~= nil and (job.count or 0) or 0
    BridgeTask.depositFull = job ~= nil and job.full == true or false
    return BridgeTask.finish()
end

local function destAssignments(job, body)
    local groups, order = {}, {}
    for i = 1, #job.items do
        local item = job.items[i]
        if item ~= nil and stillPresent(body, item) then
            local dest = BridgeDeposit.scoreDest(job, item)
            if dest ~= nil then
                local key = refKey(dest)
                if groups[key] == nil then
                    groups[key] = { dest = dest, items = {} }
                    order[#order + 1] = key
                end
                groups[key].items[#groups[key].items + 1] = item
            end
        end
    end
    if #order == 0 then return nil end
    local bx, by, bz = 0, 0, 0
    pcall(function() bx, by, bz = body:getX(), body:getY(), math.floor(body:getZ()) end)
    local bestKey, best = nil, nil
    for i = 1, #order do
        local entry = groups[order[i]]
        local d = entry.dest
        local enclose = false
        if job.bodyKey ~= nil then
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(d.x, d.y, d.z) end)
            if sq ~= nil then
                local k = nil
                pcall(function() k = BridgeDoors.enclosureKey(sq) end)
                enclose = k == job.bodyKey
            end
        end
        local dist = math.sqrt((d.x + 0.5 - bx) ^ 2 + (d.y + 0.5 - by) ^ 2) + 20 * math.abs((d.z or 0) - bz)
        local score = { enclose = enclose, dist = dist, key = order[i] }
        local better = false
        if best == nil then
            better = true
        elseif score.enclose ~= best.enclose then
            better = score.enclose
        elseif math.abs(score.dist - best.dist) > 0.001 then
            better = score.dist < best.dist
        else
            better = score.key < best.key
        end
        if better then best, bestKey = score, order[i] end
    end
    if bestKey == nil then return nil end
    return groups[bestKey]
end

local function removeItems(job, group)
    for i = 1, #(group or {}) do
        local it = group[i]
        if it ~= nil then
            for j = 1, #job.items do
                if job.items[j] == it then job.items[j] = nil break end
            end
        end
    end
    job.items = compact(job.items)
end

local function depositTime(group)
    local chr = owner()
    local w = 0
    for i = 1, #(group or {}) do
        local it = group[i]
        local iw = 0
        pcall(function() iw = it:getActualWeight() or 0 end)
        if iw > 3 then iw = 3 end
        w = w + iw
    end
    if w > 3 then w = 3 end
    local t = 50 * w + 25
    pcall(function()
        if chr:hasTrait(CharacterTrait.DEXTROUS) then t = t * 0.5 end
        if chr:hasTrait(CharacterTrait.ALL_THUMBS) or chr:isWearingAwkwardGloves() then t = t * 2 end
        if chr:isTimedActionInstant() then t = 1 end
    end)
    if t < 30 then t = 30 end
    return math.floor(t + 0.5)
end

local function destLabel(dest)
    if dest == nil then return "?" end
    local kind = "?"
    local cont = dest.cont
    if cont ~= nil then pcall(function() kind = tostring(cont:getType()) end) end
    return string.format("%s@%s,%s,%s", kind, tostring(dest.x), tostring(dest.y), tostring(dest.z))
end

local function depositTake(body, item, target, available, home)
    local dest = target ~= nil and target.cont or nil
    local src = nil
    pcall(function() src = item:getContainer() end)
    if src == nil or dest == nil then return nil, nil end
    local act = nil
    pcall(function() act = ISInventoryTransferAction:new(owner(), item, src, dest) end)
    if act == nil then return nil, nil end
    local group = { item }
    local cap = (BridgeTask ~= nil and BridgeTask.LOOT_BATCH_MAX) or 20
    local full = itemFull(item)
    for i = 1, #(available or {}) do
        if #group >= cap then break end
        local it = available[i]
        local same = false
        pcall(function()
            same = it ~= nil and it ~= item and it:getContainer() == src and it:getFullType() == full
        end)
        if same then group[#group + 1] = it end
    end
    local t = depositTime(group)
    local tw = 0
    for i = 1, #group do
        local iw = 0
        pcall(function() iw = group[i]:getActualWeight() or 0 end)
        if iw > 3 then iw = 3 end
        tw = tw + iw
    end
    local ok = false
    pcall(function()
        act.maxTime = t
        act.bridgeMinTime = t
        act.bridgeHome = home == true
        act.bridgeDeposit = home == true
        if #group > 1 then
            if isClient() then
                if act.bridgeRelay ~= nil then
                    act.queueList = { { items = group, time = t, type = full } }
                    act.bridgeRelay.group = group
                else
                    act.group = group
                end
            else
                act.queueList = { { items = group, time = t, type = full } }
            end
        end
        BridgeTask.lootAct = act
        BridgeTask.lootSrc = src
        if BridgeQueue ~= nil and BridgeQueue.push ~= nil then
            BridgeQueue.push(act)
        else
            ISTimedActionQueue.add(act)
        end
        ok = true
    end)
    if not ok then return nil, nil end
    log(string.format("transfer n=%d home=%s dest=%s weight=%.2f time=%d", #group,
        tostring(home == true), destLabel(target), tw, t))
    return act, group, t
end

local function removeDest(job, dest)
    if job == nil or dest == nil then return end
    for i = 1, #job.dests do
        if job.dests[i].cont == dest.cont then table.remove(job.dests, i) break end
    end
end

local function updateTransfers(body, job)
    if job.pending ~= nil then
        local act = BridgeTask.lootAct
        if act ~= nil and act.bridgeRefused == true then
            log("transfer refused dest=" .. destLabel(job.current))
            removeDest(job, job.current)
            pcall(BridgeTask.lootAbortAct)
            job.pending, job.pendingSrc, job.pendingGroup, job.pendingAt, job.pendingMin = nil, nil, nil, nil, nil
            job.current = nil
            job.assign = nil
            BridgeTask.lootAct = nil
            BridgeTask.lootSrc = nil
            return true
        end
        local src = job.pendingSrc
        local here = false
        pcall(function() here = src ~= nil and src:contains(job.pending) end)
        local elapsed = Bridge.time - (job.pendingAt or Bridge.time)
        local minTicks = job.pendingMin or 0
        if (not here and elapsed >= minTicks) or elapsed > BridgeTask.LOOT_TRANSFER_WAIT then
            if not here then
                local group = job.pendingGroup or { job.pending }
                local movedItems = {}
                for i = 1, #group do
                    local it = group[i]
                    local moved = it == nil
                    if it ~= nil then
                        pcall(function() moved = src == nil or not src:contains(it) end)
                    end
                    if moved and it ~= nil then movedItems[#movedItems + 1] = it end
                end
                job.count = (job.count or 0) + #movedItems
                if #movedItems > 0 then sayFor(job, job.pending) end
                removeItems(job, movedItems)
                BridgeDeposit.refreshIndex(job)
                refreshPanels()
                saveOutfit()
                log(string.format("placed n=%d dest=%s total=%d", #movedItems, destLabel(job.current), job.count))
                BridgeTask.lootAct = nil
                BridgeTask.lootSrc = nil
            else
                log("transfer timed out dest=" .. destLabel(job.current))
                pcall(BridgeTask.lootAbortAct)
            end
            job.pending, job.pendingSrc, job.pendingGroup, job.pendingAt, job.pendingMin = nil, nil, nil, nil, nil
            job.current = nil
            job.assign = nil
            pcall(function() BridgeMove.stopPath(body) end)
        end
        if #job.items == 0 then return finishJob(job) end
        return true
    end
    if job.current == nil then
        local entry = destAssignments(job, body)
        if entry == nil then
            job.full = #job.items > 0
            if job.full then BridgeTask.depositFull = true end
            log(string.format("no destination for %d remaining item(s)", #job.items))
            return finishJob(job)
        end
        job.current = entry.dest
        job.assign = entry.items
        if not job.remote then
            BridgeTask.since = Bridge.time
            BridgeTask.still = 0
            BridgeTask.bestD = nil
            BridgeTask.progressAt = Bridge.time
            BridgeTask.pathFails = 0
        end
    end
    local target = job.current
    if not job.remote then
        local walk = BridgeTask.walkTo(body, target, BridgeTask.LOOT_RANGE, true)
        if walk == "unreachable" then
            removeDest(job, target)
            job.current = nil
            job.assign = nil
            log("deposit destination unreachable, rescoring")
            return true
        end
        if walk == "walking" then return true end
        pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)
    end
    local items = job.assign or {}
    job.assign = nil
    local item = nil
    for i = 1, #items do
        if items[i] ~= nil and stillPresent(body, items[i]) then item = items[i] break end
    end
    if item == nil then
        job.current = nil
        return true
    end
    local fits = false
    pcall(function()
        fits = target.cont:hasRoomFor(owner(), item) ~= false
            and target.cont:isItemAllowed(item) ~= false
    end)
    if not fits then
        removeDest(job, target)
        job.current = nil
        log("destination refused item, rescoring dest=" .. destLabel(target))
        return true
    end
    local src = item:getContainer()
    local act, group, t = depositTake(body, item, target, items, job.remote)
    if act == nil then
        removeDest(job, target)
        job.current = nil
        log("could not build transfer dest=" .. destLabel(target))
        return true
    end
    job.pending = item
    job.pendingSrc = src
    job.pendingGroup = group
    job.pendingAt = Bridge.time
    job.pendingMin = t or 0
    return true
end

function BridgeDeposit.update(body)
    local job = BridgeDeposit.job or BridgeDeposit.pending
    if job == nil then return finishJob(job) end
    if job.inited ~= true then
        job = initJob(body, job)
        job.inited = true
        BridgeDeposit.job = job
        BridgeDeposit.pending = nil
    end
    BridgeTask.depositFull = false
    BridgeTask.depositCount = job.count or 0
    local items = {}
    for i = 1, #(job.items or {}) do
        local it = job.items[i]
        local flying = false
        if job.pending ~= nil then
            flying = it == job.pending
            if not flying and type(job.pendingGroup) == "table" then
                for g = 1, #job.pendingGroup do
                    if job.pendingGroup[g] == it then flying = true break end
                end
            end
        end
        if it ~= nil and (flying or stillPresent(body, it)) then items[#items + 1] = it end
    end
    job.items = items
    if #job.items == 0 then return finishJob(job) end
    return updateTransfers(body, job)
end

function BridgeDeposit.selftest()
    local fails, ran = {}, 0
    local function check(name, condition)
        ran = ran + 1
        if not condition then fails[#fails + 1] = name end
    end
    local refA = { kind = "obj", x = 1, y = 2, z = 0, o = 0, c = 0 }
    local refB = { kind = "obj", x = 3, y = 4, z = 0, o = 1, c = 0 }
    check("ref key differs", refKey({ ref = refA }) ~= refKey({ ref = refB }))
    check("ref key stable", refKey({ ref = refA }) == refKey({ ref = refA }))
    local c1, c2 = {}, {}
    check("container ids differ", contId(c1) ~= contId(c2))
    check("same ref different container", refKey({ ref = refA, cont = c1 }) ~= refKey({ ref = refA, cont = c2 }))
    check("functional cat tool", FUNCTIONAL_CATS.ReceiveTool == true)
    check("functional cat ammo", FUNCTIONAL_CATS.ReceiveAmmo == true)
    check("material affinity", affinityRank("ReceiveMaterial", { cont = { getType = function() return "crate" end } }) == 1)
    check("food affinity", affinityRank("ReceiveFood", { cont = { getType = function() return "fridge" end } }) == 1)
    check("no affinity", affinityRank("ReceiveFood", { cont = { getType = function() return "counter" end } }) == 0)
    local k1 = BridgeData.storeRefKey(refA)
    local k2 = BridgeData.storeRefKey(refB)
    check("store ref stable", k1 ~= nil and k1 == BridgeData.storeRefKey(refA))
    check("store ref distinct", k1 ~= k2)
    check("store ref rejects body", BridgeData.storeRefKey({ kind = "body", x = 1, y = 1, z = 0, i = 0 }) == nil)
    check("store ref rejects floor", BridgeData.storeRefKey({ kind = "floor", x = 1, y = 1, z = 0 }) == nil)
    local clean = BridgeData.cleanStoreRefs({
        refA, { kind = "obj", x = 1, y = 2, z = 0, o = 0, c = 0 },
        { kind = "body", x = 1, y = 2, z = 0, i = 0 },
        { kind = "floor", x = 1, y = 2, z = 0 }, refB,
    })
    check("store refs dedupe/reject", #clean == 2)
    check("store ref membership", BridgeData.storeRefInList({ storeRefs = { refA } }, refA) == true)
    check("store ref not member", BridgeData.storeRefInList({ storeRefs = { refA } }, refB) == false)
    local many = {}
    for i = 0, 199 do many[#many + 1] = { kind = "obj", x = 10, y = 10, z = 0, o = i, c = 0 } end
    check("store refs cap", #BridgeData.cleanStoreRefs(many) == 128)
    if #fails == 0 then return string.format("depositselftest PASS (%d checks)", ran) end
    return string.format("depositselftest FAIL (%d of %d): %s", #fails, ran, table.concat(fails, "; "))
end

log("loaded")

