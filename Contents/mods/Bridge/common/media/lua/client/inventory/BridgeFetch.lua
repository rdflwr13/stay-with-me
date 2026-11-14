

BridgeFetch = BridgeFetch or {}

local MARGIN = 6
local PENDING_TIMEOUT = 240
BridgeFetch.AMMO_SCAN_CAP = 240
BridgeFetch.AMMO_CACHE_TTL = 120
BridgeFetch.ammoCache = BridgeFetch.ammoCache or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeFetch] " .. tostring(text)) end end

local function itemType(it)
    local t = nil
    pcall(function() t = it:getType() end)
    return type(t) == "string" and t or nil
end

local function isBroken(it)
    local b = true
    pcall(function() b = it:isBroken() == true end)
    return b
end

local function hasTag(it, tag)
    local ok = false
    pcall(function() ok = it ~= nil and tag ~= nil and it:hasTag(tag) == true end)
    return ok
end

local function tagOk(it, name)
    local tag = nil
    pcall(function() if ItemTag ~= nil then tag = ItemTag[name] end end)
    return hasTag(it, tag)
end

local ASH_TYPES = {
    Broom = true, Broom_Twig = true,
    Shovel = true, Shovel2 = true, SpadeForged = true, SpadeWood = true,
    SnowShovel = true, HandShovel = true, EntrenchingTool = true,
}
local STAIN_TYPES = { Broom = true, Broom_Twig = true, Mop = true, Sponge = true,
                      BathTowel = true, DishCloth = true, GrillBrush = true, ToiletBrush = true }

local function usableAxe(it)
    return it ~= nil and not isBroken(it) and tagOk(it, "CHOP_TREE")
end

local function usableCutTool(it)
    return it ~= nil and not isBroken(it) and tagOk(it, "CUT_PLANT")
end

local function ashToolItem(it)
    if it == nil or isBroken(it) then return false end
    if tagOk(it, "CLEAR_ASHES") then return true end
    return ASH_TYPES[itemType(it) or ""] == true
end

local function cleanStainItem(it)
    if it == nil or isBroken(it) then return false end
    if tagOk(it, "CLEAN_STAINS") then return true end
    return STAIN_TYPES[itemType(it) or ""] == true
end

local function fluidNeed()
    local n = nil
    pcall(function() n = BridgeTask and BridgeTask.CLEAN_FLUID_PER_SQUARE end)
    return tonumber(n) or 0.025
end

local function cleanerFluidAmt(it)
    local amt = 0
    pcall(function()
        local c = it ~= nil and it:getFluidContainer() or nil
        if c == nil then return end
        if c:contains(Fluid.Bleach) or c:contains(Fluid.CleaningLiquid) then
            local a = c:getAmount()
            if a >= fluidNeed() then amt = a end
        end
    end)
    return amt
end

local function petrolAmt(it)
    local amt = 0
    pcall(function()
        local c = it ~= nil and it:getFluidContainer() or nil
        if c == nil then return end
        if c:contains(Fluid.Petrol) then
            local a = c:getAmount()
            if a >= fluidNeed() then amt = a end
        end
    end)
    return amt
end

local function bandagePower(it)
    local p = 0
    pcall(function() p = it:getBandagePower() or 0 end)
    return tonumber(p) or 0
end


local function bandageDirty(it)
    local t = itemType(it) or ""
    return string.find(t, "Dirty", 1, true) ~= nil
end


local function bandageOk(it)
    return bandagePower(it) > 0 and not bandageDirty(it)
end


local function dirtyBandageOk(it)
    return bandagePower(it) > 0 and bandageDirty(it)
end


local function burnBandageOk(it)
    return bandagePower(it) >= 2 and not bandageDirty(it)
end

local function disinfectOk(it)
    local ok = false
    pcall(function()
        local fluid = BridgeCare.fluidAlcohol(it)
        if fluid ~= nil and fluid > 0 then ok = true return end
        ok = it:IsDrainable() == true and it:getAlcoholPower() == 4.0 and it:getCurrentUses() > 0
    end)
    return ok
end

local function isBattery(it)
    return itemType(it) == "Battery"
end


local function sutureNeedleOk(it)
    return itemType(it) == "SutureNeedle"
end


local function needleOk(it)
    return itemType(it) == "Needle" or tagOk(it, "SEWING_NEEDLE")
end


local function threadOk(it)
    local t = itemType(it)
    if t ~= "Thread" and not tagOk(it, "THREAD") then return false end
    local uses = 0
    pcall(function() uses = it:getCurrentUsesFloat() or 0 end)
    return (tonumber(uses) or 0) > 0
end


local function tweezersOk(it)
    local t = itemType(it)
    return t == "Tweezers" or t == "SutureNeedleHolder"
        or tagOk(it, "REMOVE_GLASS") or tagOk(it, "REMOVE_BULLET")
end


local function splintOk(it)
    return itemType(it) == "Splint"
end


local function splintPlankOk(it)
    local t = itemType(it)
    return t == "Plank" or t == "TreeBranch" or t == "TreeBranch2"
        or t == "WoodenStick" or t == "WoodenStick2"
end


local function splintSheetOk(it)
    return itemType(it) == "RippedSheets"
end


BridgeFetch.NEEDS = {
    { id = "axe",            matches = usableAxe },
    { id = "cutTool",        matches = usableCutTool },
    { id = "digTool",        matches = function(it)
        return BridgeTask ~= nil and BridgeTask.isDigTool(it) == true
    end },
    { id = "waterContainer", matches = function(it)
        return BridgeGardening ~= nil and BridgeGardening.isWaterContainer(it) == true
    end },
    { id = "cropFeed", matches = function(it)
        return BridgeGardening ~= nil and BridgeGardening.isFeedItem(it) == true
    end },
    { id = "ashTool",        matches = ashToolItem },
    { id = "cleanImplement", matches = cleanStainItem },
    { id = "cleanerFluid",   fluid = true, matches = cleanerFluidAmt },
    { id = "petrol",         fluid = true, matches = petrolAmt },
    { id = "bandage",        matches = bandageOk },
    { id = "dirtyBandage",   matches = dirtyBandageOk },
    { id = "burnBandage",    matches = burnBandageOk },
    { id = "disinfectant",   matches = disinfectOk },
    { id = "sutureNeedle",   matches = sutureNeedleOk },
    { id = "needle",         matches = needleOk },
    { id = "thread",         matches = threadOk },
    { id = "tweezers",       matches = tweezersOk },
    { id = "splint",         matches = splintOk },
    { id = "splintPlank",    matches = splintPlankOk },
    { id = "splintSheet",    matches = splintSheetOk },
    { id = "battery",        matches = isBattery },
}
BridgeFetch.BY_ID = {}
for _, n in ipairs(BridgeFetch.NEEDS) do BridgeFetch.BY_ID[n.id] = n end


function BridgeFetch.has(id)
    local b = Bridge.body
    if b == nil then return false end
    local ok = false
    pcall(function()
        if id == "axe" then ok = BridgeTask.findAxe(b) ~= nil
        elseif id == "cutTool" then ok = BridgeTask.findCutTool(b) ~= nil
        elseif id == "digTool" then ok = BridgeTask.findDigTool(b) ~= nil
        elseif id == "waterContainer" then
            ok = BridgeGardening ~= nil and BridgeGardening.findWaterContainer(b) ~= nil
        elseif id == "cropFeed" then
            ok = BridgeGardening ~= nil and BridgeGardening.findFeed(b) ~= nil
        elseif id == "ashTool" then ok = BridgeTask.findAshTool(b) ~= nil
        elseif id == "cleanImplement" then ok = BridgeTask.findCleanStainItem(b) ~= nil
        elseif id == "cleanerFluid" then ok = BridgeTask.findStainCleaner(b) ~= nil
        elseif id == "petrol" then ok = BridgeTask.findPetrol(b) ~= nil
        elseif id == "bandage" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "bandage") == true
        elseif id == "dirtyBandage" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "dirtyBandage") == true
        elseif id == "burnBandage" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "burnBandage") == true
        elseif id == "disinfectant" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "disinfect") == true
        elseif id == "sutureNeedle" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "sutureNeedle") == true
        elseif id == "needle" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "needle") == true
        elseif id == "thread" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "thread") == true
        elseif id == "tweezers" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "tweezers") == true
        elseif id == "splint" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "splint") == true
        elseif id == "splintPlank" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "plank") == true
        elseif id == "splintSheet" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "sheet") == true
        elseif id == "battery" then ok = BridgeTorchShared.findBattery(b) ~= nil
        end
    end)
    return ok == true
end


local function allFloorsOn()
    if BridgeData == nil or Bridge == nil then return false end
    return BridgeData.optionOf(Bridge.store, "homeAllFloors") == true
end


local function nearHome(b, h)
    if b == nil or h == nil then return false end
    local bx, by, bz = nil, nil, nil
    pcall(function() bx, by, bz = math.floor(b:getX()), math.floor(b:getY()), math.floor(b:getZ()) end)
    if bx == nil then return false end
    return BridgeData.homeHas(h, bx, by, bz, MARGIN, allFloorsOn())
end
BridgeFetch.nearHome = nearHome


function BridgeFetch.available()
    if Bridge == nil or Bridge.store == nil or Bridge.body == nil then return false end
    if not BridgeData.optionOf(Bridge.store, "homeResources") then return false end
    local h = nil
    pcall(function() h = BridgeHome ~= nil and BridgeHome.get() or nil end)
    if h == nil then return false end
    return nearHome(Bridge.body, h)
end


function BridgeFetch.availableAmmo()
    if Bridge == nil or Bridge.store == nil or Bridge.body == nil then return false end
    if not BridgeData.optionOf(Bridge.store, "homeAmmo") then return false end
    local h = nil
    pcall(function() h = BridgeHome ~= nil and BridgeHome.get() or nil end)
    if h == nil then return false end
    return nearHome(Bridge.body, h)
end


local function bodyFloor()
    local bz = nil
    pcall(function()
        local b = Bridge ~= nil and Bridge.body or nil
        if b ~= nil then bz = math.floor(b:getZ()) end
    end)
    return bz
end


local function floorList(h)
    local list = {}
    if h == nil then return list end
    local floors = nil
    if BridgeHome ~= nil and type(BridgeHome.includedFloors) == "function" then
        local ok, res = pcall(BridgeHome.includedFloors, h, allFloorsOn())
        if ok and type(res) == "table" then floors = res end
    end
    if floors == nil or #floors == 0 then floors = { h.z } end
    local base = bodyFloor() or h.z
    for index = 1, #floors do list[#list + 1] = floors[index] end
    table.sort(list, function(a, c)
        local da, dc = math.abs(a - base), math.abs(c - base)
        if da == dc then return a > c end
        return da < dc
    end)
    return list
end


local function buildingOk(h, x, y, z, cache)
    if h == nil or h.bld == nil then return true end
    local key = tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
    local hit = cache[key]
    if hit ~= nil then return hit end
    local sq = nil
    pcall(function()
        local cell = getCell()
        if cell ~= nil then sq = cell:getGridSquare(x, y, z) end
    end)
    local ok = BridgeData.homeBuildingOk(h, sq)
    cache[key] = ok
    return ok
end


local homeMemoAt, homeMemoKey, homeMemoOut = nil, nil, nil
local HOME_TARGET_TTL = 120

local function homeTargets(perFloorCap, totalCap)
    local h = nil
    pcall(function() h = BridgeHome ~= nil and BridgeHome.get() or nil end)
    if h == nil then return nil end
    local floors = floorList(h)
    perFloorCap = tonumber(perFloorCap) or 80
    totalCap = tonumber(totalCap) or (perFloorCap * math.max(1, #floors))
    local keyParts = { h.x, h.y, h.w, h.h, perFloorCap, totalCap }
    for i = 1, #floors do keyParts[#keyParts + 1] = floors[i] end
    local key = table.concat(keyParts, ":")
    local now = Bridge.time or 0
    local ttl = HOME_TARGET_TTL
    if BridgePerf ~= nil and type(BridgePerf.age) == "function" then ttl = BridgePerf.age("homeTargets", HOME_TARGET_TTL) end
    if homeMemoKey == key and homeMemoAt ~= nil and now - homeMemoAt < ttl then
        return homeMemoOut
    end
    local out, seen, bldCache = {}, {}, {}
    for index = 1, #floors do
        if #out >= totalCap then break end
        local z = floors[index]
        local rect = { x1 = h.x, y1 = h.y, x2 = h.x + h.w - 1, y2 = h.y + h.h - 1, z = z }
        local left = math.min(perFloorCap, totalCap - #out)
        local targets = nil
        if BridgeWorkSelect ~= nil and type(BridgeWorkSelect.lootTargets) == "function" then
            local ok, res = pcall(BridgeWorkSelect.lootTargets, rect, left)
            if ok then targets = res end
        end
        if type(targets) == "table" then
            for j = 1, #targets do
                local t = targets[j]
                if #out >= totalCap then break end
                if t ~= nil and t.cont ~= nil and not seen[t.cont]
                        and buildingOk(h, t.x, t.y, t.z, bldCache) then
                    seen[t.cont] = true
                    out[#out + 1] = t
                end
            end
        end
    end
    homeMemoAt, homeMemoKey, homeMemoOut = now, key, out
    return out
end


BridgeFetch.SEED_STOCK_MS = 5000
BridgeFetch.SEED_SCAN_CONTAINERS = 60
BridgeFetch.SEED_SCAN_ITEMS = 800

local seedStockAt, seedStockKey, seedStockOut = nil, nil, nil


function BridgeFetch.invalidateSeedStock()
    seedStockAt, seedStockKey, seedStockOut = nil, nil, nil
end


local function seedPickKind()
    local pick = BridgeGardening ~= nil and BridgeGardening.sowPick or nil
    return pick ~= nil and pick.kind or nil
end


function BridgeFetch.sowWant(count)
    local kind = seedPickKind()
    if kind == nil then return 0 end
    local stock = BridgeFetch.seedStock(false)
    local counts = stock ~= nil and stock[kind] or nil
    if counts == nil then return 0 end
    local plantable = math.floor(tonumber(counts.plantable) or 0)
    local want = math.min(math.floor(tonumber(count) or 0), plantable)
    if want < 0 then want = 0 end
    return want
end


function BridgeFetch.sowNeed(count)
    local kind = seedPickKind()
    if kind == nil then return 0 end
    local stock = BridgeFetch.seedStock(false)
    local counts = stock ~= nil and stock[kind] or nil
    if counts == nil then return 0 end
    local per = BridgeGardening.SEEDS_PER_PACKET or 5
    local carried = math.floor(tonumber(counts.loose) or 0)
        + per * math.floor(tonumber(counts.packets) or 0)
    local want = BridgeFetch.sowWant(count)
    if carried >= want then return 0 end
    return want - carried
end


function BridgeFetch.seedStock(force)
    local b = Bridge.body
    if b == nil or BridgeGardening == nil or type(BridgeGardening.seedTable) ~= "function" then return {} end
    local st = BridgeGardening.seedTable()
    local h = nil
    pcall(function() h = BridgeHome ~= nil and BridgeHome.get() or nil end)
    local hk = "none"
    if h ~= nil then
        hk = string.format("%s:%s:%s:%s:%s", tostring(h.x), tostring(h.y), tostring(h.z),
            tostring(h.w), tostring(h.h))
    end
    local dirty = 0
    pcall(function() dirty = tonumber(Bridge.itemsDirtyAt) or 0 end)
    local key = hk .. "|" .. tostring(dirty) .. "|" .. tostring(Bridge.itemsDirty == true)
    local now = 0
    if BridgeGardening ~= nil and type(BridgeGardening.now) == "function" then
        pcall(function() now = BridgeGardening.now() end)
    end
    local ttl = BridgeFetch.SEED_STOCK_MS or 5000
    if force ~= true and seedStockOut ~= nil and seedStockKey == key
            and (now - (seedStockAt or 0)) < ttl then
        return seedStockOut
    end
    local out = {}
    local itemsSeen, capped = 0, false
    local itemCap = BridgeFetch.SEED_SCAN_ITEMS or 800

    local function bump(kind, field, n)
        local entry = out[kind]
        if entry == nil then
            entry = { loose = 0, packets = 0, homeLoose = 0, homePackets = 0, yours = 0, plantable = 0 }
            out[kind] = entry
        end
        entry[field] = (entry[field] or 0) + n
    end

    local function scanContainer(cont, bucket)
        if cont == nil or itemsSeen >= itemCap then return end
        local list = nil
        pcall(function() list = cont:getItems() end)
        if list == nil then return end
        for i = 0, list:size() - 1 do
            if itemsSeen >= itemCap then
                capped = true
                return
            end
            local it = list:get(i)
            if it ~= nil then
                itemsSeen = itemsSeen + 1
                local full = nil
                pcall(function() full = it:getFullType() end)
                if type(full) == "string" then
                    local kind = st.bySeed[full]
                    local packet = st.byPacket[full]
                    if kind ~= nil or packet ~= nil then
                        local n = 1
                        pcall(function() n = it:getCount() or 1 end)
                        n = math.max(1, math.floor(tonumber(n) or 1))
                        if kind ~= nil then
                            if bucket == "hers" then bump(kind, "loose", n)
                            elseif bucket == "home" then bump(kind, "homeLoose", n)
                            else bump(kind, "yours", n) end
                        elseif bucket == "hers" then
                            bump(packet.kind, "packets", n)
                        elseif bucket == "home" then
                            bump(packet.kind, "homePackets", n)
                        else
                            bump(packet.kind, "yours", (BridgeGardening.SEEDS_PER_PACKET or 5) * n)
                        end
                    end
                end
            end
        end
    end

    local lists = BridgeGardening.bagLists(b)
    for i = 1, #lists do scanContainer(lists[i], "hers") end
    local cap = BridgeFetch.SEED_SCAN_CONTAINERS or 60
    local targets = homeTargets(cap, cap)
    local used = 0
    for i = 1, #(targets or {}) do
        if used >= cap then
            capped = true
            break
        end
        local cont = targets[i].cont
        if cont ~= nil then
            used = used + 1
            scanContainer(cont, "home")
        end
    end
    local red = nil
    pcall(function() red = BridgeData.owner() end)
    if red ~= nil then
        local pinv = nil
        pcall(function() pinv = red:getInventory() end)
        scanContainer(pinv, "player")
    end

    local per = BridgeGardening.SEEDS_PER_PACKET or 5
    for kind, entry in pairs(out) do
        entry.plantable = (entry.loose or 0) + (entry.homeLoose or 0)
            + per * ((entry.packets or 0) + (entry.homePackets or 0))
    end
    if capped then
        log(string.format("seed stock capped at %d item(s) in %d container(s)", itemsSeen, used))
    end
    seedStockAt, seedStockKey, seedStockOut = now, key, out
    return out
end


local function moveSeedLocal(body, red, kind, want)
    local types = BridgeGardening.seedTypesOf(kind)
    if #types == 0 then return "absent" end
    local rank = {}
    for i = 1, #types do rank[types[i]] = i end
    local cap = BridgeFetch.SEED_SCAN_CONTAINERS or 60
    local targets = homeTargets(cap, cap)
    if targets == nil then return "absent" end
    local need = math.floor(tonumber(want) or 0)
    if need < 1 then need = 1 end
    local moved = 0
    for i = 1, #targets do
        if need <= 0 then break end
        local cont = targets[i].cont
        if cont ~= nil then
            local list = nil
            pcall(function() list = cont:getItems() end)
            if list ~= nil then
                for j = list:size() - 1, 0, -1 do
                    if need <= 0 then break end
                    local it = list:get(j)
                    local full = nil
                    pcall(function() full = it ~= nil and it:getFullType() or nil end)
                    if full ~= nil and rank[full] ~= nil then
                        local have = BridgeGunRules.itemCount(it)
                        local use = math.min(have, need)
                        local dest = nil
                        pcall(function() dest = BridgeInventory.overflowDest(body, red, it, nil) end)
                        if dest ~= nil then
                            local okMove = false
                            pcall(function()
                                if use >= have then
                                    cont:Remove(it)
                                    dest:AddItem(it)
                                    okMove = it:getContainer() == dest
                                elseif BridgeGunRules.setItemCount(it, have - use) then
                                    local made = nil
                                    pcall(function() made = dest:AddItems(full, use) end)
                                    okMove = made ~= nil and made:size() >= use
                                end
                            end)
                            if okMove then
                                moved = moved + use
                                need = need - use
                            end
                        end
                    end
                end
            end
        end
    end
    if moved <= 0 then return "absent" end
    pcall(function() if Bridge.saveOutfit ~= nil then Bridge.saveOutfit() end end)
    BridgeFetch.invalidateSeedStock()
    log(string.format("home seeds: pulled %d of %s from home", moved, tostring(kind)))
    return "moved"
end


function BridgeFetch.pullSeeds(kind, want)
    if BridgeGardening == nil then return "unavailable" end
    local b = Bridge.body
    local red = BridgeData.owner()
    if b == nil or red == nil or kind == nil then return "unavailable" end
    if #BridgeGardening.seedTypesOf(kind) == 0 then return "absent" end
    local n = math.floor(tonumber(want) or 0)
    if n < 1 then n = 1 end
    if Bridge.mp then
        local ok = pcall(function()
            sendClientCommand(red, "Bridge", "fetchSeeds", { kind = kind, want = n })
        end)
        if not ok then return "failed" end
        log(string.format("home seeds: requested %d of %s from home", n, tostring(kind)))
        return "requested"
    end
    return moveSeedLocal(b, red, kind, n)
end


function BridgeFetch.findItem(needId)
    local need = BridgeFetch.BY_ID[needId]
    local b = Bridge.body
    if need == nil or b == nil then return nil end
    local targets = homeTargets()
    if targets == nil then return nil end
    local bx, by, bz = nil, nil, nil
    pcall(function() bx, by, bz = b:getX(), b:getY(), math.floor(b:getZ()) end)
    local best, bestScore = nil, nil
    for i = 1, #targets do
        local t = targets[i]
        local c = t.cont
        if c ~= nil then
            local d = 0
            if bx ~= nil and t.x ~= nil then
                local dx, dy = bx - t.x, by - t.y
                d = math.sqrt(dx * dx + dy * dy)
            end
            if t.z ~= nil and bz ~= nil then d = d + 20 * math.abs(t.z - bz) end
            local list = nil
            pcall(function() list = c:getItems() end)
            if list ~= nil then
                for j = 0, list:size() - 1 do
                    local it = list:get(j)
                    if it ~= nil then
                        local m = nil
                        pcall(function() m = need.matches(it) end)
                        if m then
                            local score = need.fluid and m or -d
                            if bestScore == nil or score > bestScore then best, bestScore = it, score end
                        end
                    end
                end
            end
        end
    end
    return best
end


function BridgeFetch.invalidateAmmoCache()
    BridgeFetch.ammoCache = {}
end

local function ammoCacheKey(gun, minRounds)
    local g = "?"
    if type(gun) == "table" then
        g = gun.fullType or "?"
    else
        pcall(function() g = gun:getFullType() or gun:getType() end)
    end
    local h = nil
    pcall(function() h = BridgeHome ~= nil and BridgeHome.get() or nil end)
    local hk = "none"
    if h ~= nil then
        hk = string.format("%s:%s:%s:%s:%s", tostring(h.x), tostring(h.y), tostring(h.z), tostring(h.w), tostring(h.h))
    end
    local owner = nil
    pcall(function() owner = BridgeData ~= nil and BridgeData.owner() or nil end)
    local own = owner ~= nil and tostring(owner) or "none"
    local care = "0"
    pcall(function()
        if BridgeData ~= nil and BridgeData.optionOf(Bridge.store, "gunMagCare") then care = "1" end
    end)
    local floors = "none"
    if h ~= nil then
        local list = nil
        pcall(function() list = BridgeHome.includedFloors(h, allFloorsOn()) end)
        if type(list) == "table" and #list > 0 then
            local parts = {}
            for i = 1, #list do parts[i] = tostring(list[i]) end
            table.sort(parts)
            floors = table.concat(parts, ",")
        end
    end
    return tostring(g) .. "|" .. hk .. "|" .. own .. "|" .. care .. "|" .. floors .. "|" .. tostring(minRounds or 0)
end

function BridgeFetch.findAmmo(gun, minRounds)
    if gun == nil then return nil end
    minRounds = tonumber(minRounds) or 0
    local cacheKey = ammoCacheKey(gun, minRounds)
    local hit = BridgeFetch.ammoCache[cacheKey]
    local now = Bridge.time or 0
    local ttl = BridgeFetch.AMMO_CACHE_TTL
    if BridgePerf ~= nil and type(BridgePerf.age) == "function" then ttl = BridgePerf.age("fetchAmmo", BridgeFetch.AMMO_CACHE_TTL) end
    if hit ~= nil and now - (hit.at or 0) < ttl then
        if hit.item == nil then return hit.item, hit.kind, hit.value end
        local alive = false
        pcall(function() alive = hit.item:getContainer() ~= nil end)
        if alive then return hit.item, hit.kind, hit.value end
        BridgeFetch.ammoCache[cacheKey] = nil
    end
    local cap = BridgeFetch.AMMO_SCAN_CAP or 240
    local targets = homeTargets(cap, cap)
    if targets == nil then return nil end
    local b = Bridge.body
    local bx, by, bz = nil, nil, nil
    if b ~= nil then pcall(function() bx, by, bz = b:getX(), b:getY(), math.floor(b:getZ()) end) end
    local owner = BridgeData.owner()
    local types = BridgeGunRules.ammoTypesFor(gun, owner)
    if #types == 0 then return nil end
    local rank = {}
    for i, t in ipairs(types) do rank[t] = i end
    local useMag = gun.magazineType ~= nil or gun.hasClipProfile == true
    if not useMag then
        pcall(function() BridgeGunRules.refreshMagazineProfile(gun) end)
        useMag = gun.magazineType ~= nil or gun.hasClipProfile == true
    end
    local useBox = not useMag or BridgeData.optionOf(Bridge.store, "gunMagCare")
    local useLoose = useBox
    local best, bestKind, bestValue, bestD = nil, nil, nil, nil
    for i = 1, #targets do
        local t = targets[i]
        local c = t.cont
        if c ~= nil then
            local d = 0
            if bx ~= nil and t.x ~= nil then
                local dx, dy = bx - t.x, by - t.y
                d = math.sqrt(dx * dx + dy * dy)
            end
            if t.z ~= nil and bz ~= nil then d = d + 20 * math.abs(t.z - bz) end
            local list = nil
            pcall(function() list = c:getItems() end)
            if list ~= nil then
                local ln = list:size()
                for j = 0, ln - 1 do
                    local it = list:get(j)
                    if it ~= nil then
                        local kind, value = nil, 0
                        pcall(function()
                            local full = it:getFullType()
                            local inProfile = gun.magazineSet ~= nil and gun.magazineSet[full] == true
                            if useMag
                                and (full == gun.magazineType or inProfile) then
                                local r = BridgeGunRules.roundsOf(it)
                                if r > minRounds then kind, value = 1, r end
                            elseif useLoose and rank[full] ~= nil then
                                kind, value = 2, -rank[full] * 100000 + BridgeGunRules.itemCount(it)
                            elseif useBox then
                                local spec = BridgeGunRules.unpackOf(full)
                                local exact = BridgeGunRules.exactOutput(spec)
                                if exact ~= nil and rank[exact] ~= nil then
                                    kind, value = 3, -rank[exact]
                                else
                                    local bd = BridgeGunRules.cartonBreakdown(full)
                                    if bd ~= nil and bd.out ~= nil then
                                        local boxSpec = BridgeGunRules.unpackOf(bd.out)
                                        local boxOut = BridgeGunRules.exactOutput(boxSpec)
                                        if boxOut ~= nil and rank[boxOut] ~= nil then
                                            kind, value = 4, -rank[boxOut]
                                        end
                                    end
                                end
                            end
                        end)
                        if kind ~= nil then
                            local better = false
                            if best == nil then
                                better = true
                            elseif kind < bestKind then
                                better = true
                            elseif kind == bestKind then
                                if value > bestValue then
                                    better = true
                                elseif value == bestValue and (bestD == nil or d < bestD) then
                                    better = true
                                end
                            end
                            if better then best, bestKind, bestValue, bestD = it, kind, value, d end
                        end
                    end
                end
            end
        end
    end
    BridgeFetch.ammoCache[cacheKey] = { at = now, item = best, kind = bestKind, value = bestValue }
    return best, bestKind, bestValue
end


function BridgeFetch.hasAmmoStock(gun)
    if not BridgeFetch.availableAmmo() then return false end
    return BridgeFetch.findAmmo(gun) ~= nil
end


local function homeLoose(gun, want)
    local b = Bridge.body
    if b == nil or type(gun) ~= "table" then return {}, 0, nil end
    local types = BridgeGunRules.ammoTypesFor(gun, BridgeData.owner())
    if #types == 0 then return {}, 0, nil end
    local rank = {}
    for i, t in ipairs(types) do rank[t] = i end
    local cap = BridgeFetch.AMMO_SCAN_CAP or 240
    local targets = homeTargets(cap, cap)
    if targets == nil then return {}, 0, nil end
    local bx, by, bz = nil, nil, nil
    pcall(function() bx, by, bz = b:getX(), b:getY(), math.floor(b:getZ()) end)
    local order = {}
    for i = 1, #targets do
        local t = targets[i]
        if t.cont ~= nil then
            local d = 0
            if bx ~= nil and t.x ~= nil then
                local dx, dy = bx - t.x, by - t.y
                d = math.sqrt(dx * dx + dy * dy)
            end
            if t.z ~= nil and bz ~= nil then d = d + 20 * math.abs(t.z - bz) end
            order[#order + 1] = { cont = t.cont, d = d }
        end
    end
    table.sort(order, function(a, b2) return a.d < b2.d end)
    local need = math.floor(tonumber(want) or 0)
    if need <= 0 then need = 1 end
    local byType = {}
    local bestType, bestRank = nil, nil
    for i = 1, #order do
        local list = nil
        pcall(function() list = order[i].cont:getItems() end)
        if list ~= nil then
            local ln = list:size()
            for j = 0, ln - 1 do
                local it = list:get(j)
                if it ~= nil then
                    local t = nil
                    pcall(function() t = it:getFullType() end)
                    if t ~= nil and rank[t] ~= nil then
                        byType[t] = byType[t] or {}
                        byType[t][#byType[t] + 1] = it
                        if bestRank == nil or rank[t] < bestRank then
                            bestType, bestRank = t, rank[t]
                        end
                    end
                end
            end
        end
    end
    if bestType == nil then return {}, 0, nil end
    local items, total = {}, 0
    for _, item in ipairs(byType[bestType]) do
        if total >= need then break end
        local n = BridgeGunRules.itemCount(item)
        if n > 0 then
            items[#items + 1] = item
            total = total + n
        end
    end
    return items, total, bestType
end


function BridgeFetch.pullLoose(gun, want)
    local b = Bridge.body
    local red = BridgeData.owner()
    if b == nil or red == nil or type(gun) ~= "table" then return "unavailable" end
    local n = math.floor(tonumber(want) or 0)
    if n <= 0 then n = 1 end
    local items, total, selectedType = homeLoose(gun, n)
    if selectedType == nil then return "absent" end
    local full = selectedType
    if Bridge.mp then
        local ok = pcall(function()
            sendClientCommand(red, "Bridge", "fetchSupply", { loose = full, take = n })
        end)
        if not ok then return "failed" end
        log(string.format("home ammo: requested %d loose %s from a home container", n, tostring(full)))
        return "requested"
    end
    if total <= 0 then return "absent" end
    local left = math.min(n, total)
    local moved = 0
    for i = 1, #items do
        if left <= 0 then break end
        local item = items[i]
        local have = BridgeGunRules.itemCount(item)
        local use = math.min(have, left)
        local src = nil
        pcall(function() src = item:getContainer() end)
        if src ~= nil then
            local dest = nil
            pcall(function() dest = BridgeInventory.overflowDest(b, red, item, nil) end)
            if dest ~= nil then
                local okMove = false
                pcall(function()
                    local made = {}
                    local function addSingles(count)
                        for _ = 1, count do
                            local one = instanceItem(full)
                            if one == nil then break end
                            local put = nil
                            pcall(function() put = dest:AddItem(one) end)
                            if put == nil then break end
                            made[#made + 1] = (type(put) == "table") and put or one
                        end
                        return #made
                    end
                    local function undo()
                        for i = #made, 1, -1 do pcall(function() dest:Remove(made[i]) end) end
                    end
                    if use >= have then
                        if addSingles(use) == use then
                            src:Remove(item)
                            okMove = true
                        else
                            undo()
                        end
                    elseif BridgeGunRules.setItemCount(item, have - use) then
                        if addSingles(use) == use then
                            okMove = true
                        else
                            undo()
                            pcall(function() item:setCount(have) end)
                        end
                    end
                end)
                if okMove then
                    moved = moved + use
                    left = left - use
                end
            end
        end
    end
    if moved <= 0 then return "noroom" end
    pcall(function() if Bridge.saveOutfit ~= nil then Bridge.saveOutfit() end end)
    BridgeFetch.invalidateAmmoCache()
    log(string.format("home ammo: pulled %d loose %s from home (need %d, had %d)",
        moved, tostring(full), n, total))
    return "moved"
end


function BridgeFetch.pull(needId)
    if not BridgeFetch.available() then return "unavailable" end
    if BridgeFetch.has(needId) then return "have" end
    local item = BridgeFetch.findItem(needId)
    if item == nil then return "absent" end
    return BridgeFetch.pullItem(item, needId)
end


function BridgeFetch.pullItem(item, label, opts)
    local b = Bridge.body
    local red = BridgeData.owner()
    if label == "ammo" then BridgeFetch.invalidateAmmoCache() end
    if item == nil then return "absent" end
    if b == nil or red == nil then return "unavailable" end
    local dest = nil
    pcall(function() dest = BridgeInventory.overflowDest(b, red, item, nil) end)
    if dest == nil then return "noroom" end
    local breakCarton = type(opts) == "table" and opts.breakCarton == true
    if Bridge.mp then
        local id = nil
        pcall(function() id = item:getID() end)
        if id == nil then return "failed" end
        if not breakCarton then
            BridgeInventory.pending[id] = { item = item, dest = dest }
        end
        local payload = { id = id, need = label or "item" }
        if breakCarton then payload.breakCarton = true end
        local ok = pcall(function() sendClientCommand(red, "Bridge", "fetchSupply", payload) end)
        if not ok then
            if not breakCarton then BridgeInventory.pending[id] = nil end
            return "failed"
        end
        log("requested " .. tostring(label) .. " (" .. tostring(itemType(item)) .. ") from a home container")
        return "requested"
    end
    local src = nil
    pcall(function() src = item:getContainer() end)
    if src == nil then return "absent" end
    local moved = false
    pcall(function()
        src:Remove(item)
        dest:AddItem(item)
        moved = item:getContainer() == dest
    end)
    if not moved then
        pcall(function() dest:Remove(item) src:AddItem(item) end)
        return "noroom"
    end
    pcall(function() if Bridge.saveOutfit ~= nil then Bridge.saveOutfit() end end)
    log("took " .. tostring(label) .. " (" .. tostring(itemType(item)) .. ") from a home container")
    return "moved"
end


function BridgeFetch.pullAmmo(gun, minRounds, need)
    if not BridgeFetch.availableAmmo() then return "unavailable" end
    local item, kind = BridgeFetch.findAmmo(gun, minRounds)
    if item == nil then return "absent" end
    local function clearBorrow()
        if BridgeGunfight ~= nil then BridgeGunfight.ammoBorrow = nil end
    end
    if kind == 2 then
        clearBorrow()
        return BridgeFetch.pullLoose(gun, need)
    end
    if kind ~= 4 then
        clearBorrow()
        return BridgeFetch.pullItem(item, "ammo")
    end
    local full = nil
    pcall(function() full = item:getFullType() end)
    local breakdown, why, spec = nil, nil, nil
    pcall(function() breakdown, why, spec = BridgeGunRules.cartonBreakdown(full) end)
    local outputs = (spec ~= nil and type(spec.out) == "table") and #spec.out or 0
    local exactRound = nil
    if breakdown ~= nil and breakdown.out ~= nil then
        exactRound = BridgeGunRules.exactOutput(BridgeGunRules.unpackOf(breakdown.out))
    end
    local accept = {}
    for _, t in ipairs(gun ~= nil and BridgeGunRules.ammoTypesFor(gun, BridgeData.owner()) or {}) do
        accept[t] = true
    end
    if breakdown == nil or exactRound == nil or accept[exactRound] ~= true then
        log(string.format("home ammo: carton %s has unsupported breakdown recipe (%s, out=%d, amount=%s); left in storage",
            tostring(full), tostring(why or "round mismatch"), outputs,
            tostring(spec ~= nil and spec.amount or "?")))
        return "unsupported"
    end
    local boxType = breakdown.out
    local count = breakdown.amount - 1
    if Bridge.mp then
        return BridgeFetch.pullItem(item, "ammo", { breakCarton = true })
    end
    local src, itemId = nil, nil
    pcall(function()
        src = item:getContainer()
        itemId = item:getID()
    end)
    if src == nil then return "absent" end
    if BridgeGunfight ~= nil then
        BridgeGunfight.ammoBorrow = {
            src = src,
            itemId = itemId,
            cartonType = full,
            boxType = boxType,
            count = count,
        }
    end
    log(string.format("home ammo: carton %s selected from %s, will keep 1 and return %d",
        tostring(full), tostring(src), count))
    local res = BridgeFetch.pullItem(item, "ammo")
    if res ~= "moved" then clearBorrow() end
    if res == "moved" then
        log(string.format("home ammo: carton %s pulled from %s id=%s",
            tostring(full), tostring(src), tostring(itemId)))
    end
    return res
end


local function jobEnabled(kind)
    local ok = true
    pcall(function()
        if kind == "chopTree" then ok = BridgeTask.TREECUTTING_ENABLED == 1
        elseif kind == "clearPlants" then ok = BridgeTask.CLEARING_ENABLED == 1
        elseif kind == "cleanUp" then ok = BridgeTask.CLEANING_ENABLED == 1
        elseif kind == "digFurrows" then ok = BridgeTask.FURROWS_ENABLED == 1
        elseif kind == "sowSeeds" then ok = BridgeTask.SOWING_ENABLED == 1
        elseif kind == "waterPlants" then ok = BridgeTask.WATER_PLANTS_ENABLED == 1
        elseif kind == "fertilizePlants" then ok = BridgeTask.FEED_PLANTS_ENABLED == 1
        end
    end)
    return ok == true
end


function BridgeFetch.jobMissing(kind, targets)
    local out = {}
    local b = Bridge.body
    if b == nil or type(targets) ~= "table" or not jobEnabled(kind) then return out end
    pcall(function()
        if kind == "chopTree" then
            if BridgeTask.findAxe(b) == nil then out[#out + 1] = "axe" end
        elseif kind == "digFurrows" then
            if BridgeTask.findDigTool(b) == nil then out[#out + 1] = "digTool" end
        elseif kind == "sowSeeds" then
            if BridgeFetch.sowNeed(#targets) > 0 then out[#out + 1] = "seeds" end
        elseif kind == "waterPlants" then
            if BridgeGardening == nil or BridgeGardening.findWaterContainer(b) == nil then
                out[#out + 1] = "waterContainer"
            end
        elseif kind == "fertilizePlants" then
            local haveCompost, haveFertilizer = false, false
            local want = false
            if BridgeGardening ~= nil then
                haveCompost = BridgeGardening.findFeed(b, "compost") ~= nil
                haveFertilizer = BridgeGardening.findFeed(b, "fertilizer") ~= nil
                for i = 1, #targets do
                    local t = targets[i]
                    local plant = BridgeGardening.plantAt(BridgeGardening.squareAt(t), false)
                    if BridgeGardening.needsFeed(plant)
                            and BridgeGardening.feedKindFor(plant, haveCompost, haveFertilizer) ~= nil then
                        want = true
                        break
                    end
                end
            end
            if not want then
                if haveCompost or haveFertilizer then
                    out[#out + 1] = "cropFeed"
                elseif BridgeGardening ~= nil then
                    for i = 1, #targets do
                        local t = targets[i]
                        local plant = BridgeGardening.plantAt(BridgeGardening.squareAt(t), false)
                        if BridgeGardening.needsFeed(plant) then
                            out[#out + 1] = "cropFeed"
                            break
                        end
                    end
                end
            end
        elseif kind == "clearPlants" then
            local needCut = false
            local haveCut = BridgeTask.findCutTool(b) ~= nil
            if not haveCut then
                for i = 1, #targets do
                    local t = targets[i]
                    local sq = getCell():getGridSquare(t.x, t.y, t.z)
                    if sq ~= nil and BridgePlants ~= nil and BridgePlants.squareBush(sq) then needCut = true break end
                end
            end
            if needCut then out[#out + 1] = "cutTool" end
        elseif kind == "cleanUp" then
            local need = {}
            for i = 1, #targets do
                local t = targets[i]
                local sq = getCell():getGridSquare(t.x, t.y, t.z)
                if sq ~= nil then
                    local kinds = BridgeTask.squareCleanKinds(sq)
                    for k = 1, #kinds do
                        local kk = kinds[k]
                        local tool, cleaner, canDo = BridgeTask.cleanKindTool(b, kk)
                        if not canDo then
                            if kk == "blood" or kk == "grime" then
                                if tool == nil then need.implement = true end
                                if cleaner == nil then need.fluid = true end
                            elseif kk == "graffiti" then
                                if tool == nil then need.implement = true end
                                if cleaner == nil then need.petrol = true end
                            elseif kk == "ashes" then
                                if tool == nil then need.ash = true end
                            elseif kk == "vine" then
                                if tool == nil then need.cut = true end
                            end
                        end
                    end
                end
            end
            if need.implement then out[#out + 1] = "cleanImplement" end
            if need.fluid then out[#out + 1] = "cleanerFluid" end
            if need.petrol then out[#out + 1] = "petrol" end
            if need.ash then out[#out + 1] = "ashTool" end
            if need.cut then out[#out + 1] = "cutTool" end
        end
    end)
    if #out > 0 then BridgeFetch.invalidateAmmoCache() end
    return out
end


function BridgeFetch.primeJob(kind, targets)
    if not BridgeFetch.available() then return "skip" end
    local missing = BridgeFetch.jobMissing(kind, targets)
    if #missing == 0 then return "skip" end
    log("job " .. tostring(kind) .. " missing home supplies: " .. table.concat(missing, ","))
    local requested = 0
    for i = 1, #missing do
        local res = nil
        if missing[i] == "seeds" then
            local kind = BridgeGardening ~= nil and BridgeGardening.sowPick ~= nil
                and BridgeGardening.sowPick.kind or nil
            if kind ~= nil then
                res = BridgeFetch.pullSeeds(kind, BridgeFetch.sowWant(#targets))
            end
            if res == nil then res = "absent" end
        else
            res = BridgeFetch.pull(missing[i])
        end
        if res == "requested" then requested = requested + 1 end
        log("  " .. missing[i] .. " -> " .. tostring(res))
    end
    local remaining = 0
    for i = 1, #missing do
        if missing[i] == "seeds" then
            if BridgeFetch.sowNeed(#targets) > 0 then remaining = remaining + 1 end
        elseif not BridgeFetch.has(missing[i]) then
            remaining = remaining + 1
        end
    end
    if remaining == 0 then return "ok" end
    if requested > 0 then return "pending" end
    return "blocked"
end


function BridgeFetch.tick()
    local ps = nil
    pcall(function() ps = BridgeTask and BridgeTask.pendingStart or nil end)
    if ps == nil then return end
    local now = 0
    pcall(function() now = tonumber(Bridge.time) or 0 end)
    if (now - (ps.since or now)) > PENDING_TIMEOUT then
        BridgeTask.pendingStart = nil
        log("home fetch timed out for " .. tostring(ps.kind))
        pcall(function() BridgeTask.speakMissing(ps.kind) end)
        return
    end
    local danger = false
    pcall(function() danger = BridgeTask.dangerNear ~= nil and BridgeTask.dangerNear(Bridge.body) end)
    if danger then
        BridgeTask.pendingStart = nil
        log("home fetch aborted (danger) for " .. tostring(ps.kind))
        return
    end
    local still = BridgeFetch.jobMissing(ps.kind, ps.targets)
    if #still == 0 then
        BridgeTask.pendingStart = nil
        log("home supplies arrived, starting " .. tostring(ps.kind))
        pcall(function() BridgeTask.start(ps.kind, ps.targets, ps.corpseDest) end)
    end
end


if not BridgeFetch._hooked then
    BridgeFetch._hooked = true
    Events.OnTick.Add(function() pcall(BridgeFetch.tick) end)
end

log("loaded")
