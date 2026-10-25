










BridgeWash = BridgeWash or {}
BridgeWash.state = "idle"
BridgeWash.sink = nil
BridgeWash.spot = nil
BridgeWash.since = 0
BridgeWash.info = "none"
BridgeWash.queue = nil
BridgeWash.best = nil
BridgeWash.progressAt = 0

local RADIUS = 15
local GO_TICKS = 1800
local STALL_TICKS = 240
local WASH_TICKS = 420
local REACH = 1.6
local OTHER_HOUSE = 225

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeWash] " .. tostring(text)) end end
local function warn(text) print("[BridgeWash] " .. tostring(text)) end

BridgeWash.DEBUG = false

local function dbg(text)
    if BridgeWash.DEBUG or (Bridge ~= nil and Bridge.verbose == true) then
        print("[BridgeWash] " .. tostring(text))
    end
end





function BridgeWash.sayLine(pool, fallbackKey)
    local text = nil
    pcall(function()
        if BridgeMoments ~= nil and BridgeMoments.line ~= nil then text = BridgeMoments.line(pool) end
    end)
    if text ~= nil and text ~= "" then Bridge.speakText(text) else Bridge.speak(fallbackKey) end
end

local function sayWash(pool, key)
    BridgeWash.sayLine(pool, key)
end



local function washWhat(body)
    local g = BridgeWash.dirtyGear(body)
    local mine = (g.skin or 0) > 0
    local things = #g.cloth + #g.blood + #g.rags > 0
    if mine and things then return "Both" end
    if mine then return "Self" end
    return "Clothes"
end

local function dist(a, x, y)
    local dx, dy = a:getX() - x, a:getY() - y
    return math.sqrt(dx * dx + dy * dy)
end


BridgeWash.RAGS = {
    ["Base.BandageDirty"] = "Base.Bandage", ["Base.RippedSheetsDirty"] = "Base.RippedSheets",
    ["Base.DenimStripsDirty"] = "Base.DenimStrips", ["Base.LeatherStripsDirty"] = "Base.LeatherStrips",
}


local function wornList(body)
    local out = {}
    pcall(function()
        local worn = body:getWornItems()
        for i = 0, worn:size() - 1 do
            local it = worn:getItemByIndex(i)
            if it ~= nil then out[#out + 1] = it end
        end
    end)
    return out
end

local function handList(body)
    local out = {}
    pcall(function()
        local p = body:getPrimaryHandItem()
        local s = body:getSecondaryHandItem()
        if p ~= nil then out[#out + 1] = p end
        if s ~= nil and s ~= p then out[#out + 1] = s end
    end)
    return out
end

local function carriedList(body, skip)
    local seen = {}
    local out = {}
    local function walk(inv, depth)
        if inv == nil or depth > 3 then return end
        local items = inv:getItems()
        local list = {}
        for i = 0, items:size() - 1 do list[#list + 1] = items:get(i) end
        for _, it in ipairs(list) do
            if it ~= nil and not skip[it] and not seen[it] then
                seen[it] = true
                out[#out + 1] = it
            end
            local bag = false
            pcall(function() bag = it:IsInventoryContainer() end)
            if bag then pcall(function() walk(it:getInventory(), depth + 1) end) end
        end
    end
    pcall(function() walk(body:getInventory(), 0) end)
    return out
end

local function gearList(body, scope)
    local worn = wornList(body)
    local hands = handList(body)
    if scope == "inventory" then
        local skip = {}
        for _, it in ipairs(worn) do skip[it] = true end
        for _, it in ipairs(hands) do skip[it] = true end
        return carriedList(body, skip)
    end
    local out = {}
    for _, it in ipairs(worn) do out[#out + 1] = it end
    for _, it in ipairs(hands) do out[#out + 1] = it end
    if scope ~= "self" then
        local skip = {}
        for _, it in ipairs(worn) do skip[it] = true end
        for _, it in ipairs(hands) do skip[it] = true end
        for _, it in ipairs(carriedList(body, skip)) do out[#out + 1] = it end
    end
    return out
end


local function clothDirt(item)
    local isCloth = false
    pcall(function() isCloth = instanceof(item, "Clothing") or instanceof(item, "InventoryContainer") end)
    if not isCloth then return nil end
    local blood, dirt = 0, 0
    pcall(function()
        local parts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
        if parts == nil then return end
        for j = 0, parts:size() - 1 do
            local part = parts:get(j)
            blood = blood + item:getBlood(part)
            dirt = dirt + item:getDirt(part)
        end
    end)
    return blood, dirt
end


local function bloodLevel(item)
    local b = 0
    pcall(function() b = item:getBloodLevel() or 0 end)
    return b
end


function BridgeWash.dirtyGear(body, scope)
    local out = { skin = 0, cloth = {}, blood = {}, rags = {} }
    if scope ~= "inventory" then
        pcall(function()
            local visual = body:getHumanVisual()
            for i = 1, BloodBodyPartType.MAX:index() do
                local part = BloodBodyPartType.FromIndex(i - 1)
                if visual:getBlood(part) + visual:getDirt(part) > 0 then out.skin = out.skin + 1 end
            end
        end)
    end
    local seen = {}
    for _, it in ipairs(gearList(body, scope)) do
        if it ~= nil and not seen[it] then
            seen[it] = true
            local full = nil
            pcall(function() full = it:getFullType() end)
            if full ~= nil and BridgeWash.RAGS[full] ~= nil then
                out.rags[#out.rags + 1] = it
            else
                local blood, dirt = clothDirt(it)
                if blood ~= nil then
                    if blood + dirt > 0 then out.cloth[#out.cloth + 1] = it end
                elseif bloodLevel(it) > 0 then
                    out.blood[#out.blood + 1] = it
                end
            end
        end
    end
    return out
end


function BridgeWash.dirtyParts(body, scope)
    local g = BridgeWash.dirtyGear(body, scope)
    return g.skin + #g.cloth + #g.blood + #g.rags
end


BridgeWash.SOAP_SPEED = 0.5
BridgeWash.SOAP_TYPES = { ["Base.Soap"] = true, ["Base.Soap2"] = true }

local function soapItem(item)
    if item == nil then return false end
    local ok = false
    pcall(function()
        local full = item:getFullType()
        if full ~= nil then
            ok = BridgeWash.SOAP_TYPES[full] == true
                or string.find(string.lower(tostring(full)), "soap", 1, true) ~= nil
        end
    end)
    return ok
end
BridgeWash.soapItem = soapItem

function BridgeWash.hasSoap(body)
    if body == nil then return false end
    local found = false
    pcall(function()
        local items = body:getInventory():getAllEvalRecurse(soapItem)
        found = items ~= nil and items:size() > 0
    end)
    return found
end

function BridgeWash.washTicks(body)
    local base = WASH_TICKS
    if BridgeWash.hasSoap(body) then
        base = math.max(1, math.floor(base * (BridgeWash.SOAP_SPEED or 0.5)))
    end
    return base
end

function BridgeWash.waterNeeded(body, tainted, scope)
    if body == nil then return 0 end
    local g = BridgeWash.dirtyGear(body, scope)
    local total = g.skin or 0
    for _, item in ipairs(g.cloth) do
        local blood, dirt = clothDirt(item)
        if blood ~= nil then total = total + math.ceil(4 + blood * 3 + dirt) end
    end
    for _, item in ipairs(g.blood) do
        total = total + math.ceil(4 + bloodLevel(item) * 3)
    end
    if not tainted then total = total + #g.rags end
    return total
end

function BridgeWash.safeCall(o, name, ...)
    if o == nil then return nil end
    local args = { n = select("#", ...), ... }
    local m = nil
    pcall(function() m = o[name] end)
    if type(m) ~= "function" then return nil end
    local r = nil
    pcall(function() r = m(o, unpack(args, 1, args.n)) end)
    return r
end

function BridgeWash.objInfo(o)
    if o == nil then return "nil" end
    local flags = {}
    local function try(name)
        local is = false
        if instanceof ~= nil then pcall(function() is = instanceof(o, name) end) end
        if is then flags[#flags + 1] = name end
    end
    try("IsoWorldInventoryObject")
    try("IsoThumpable")
    try("IsoObject")
    local hw = BridgeWash.safeCall(o, "hasWater")
    local hf = BridgeWash.safeCall(o, "hasFluid")
    local amt = BridgeWash.safeCall(o, "getFluidAmount")
    local fc = BridgeWash.safeCall(o, "getFluidContainer")
    local fcws = "nil"
    if fc ~= nil then fcws = tostring(BridgeWash.safeCall(fc, "isWaterSource")) end
    return string.format("%s classes=%s hasWater=%s hasFluid=%s amount=%s fcWater=%s",
        tostring(o), table.concat(flags, "|"), tostring(hw), tostring(hf), tostring(amt), fcws)
end

function BridgeWash.isWaterFluid(fc)
    if fc == nil then return false end
    if BridgeWash.safeCall(fc, "isWaterSource") == true then return true end
    local water = false
    pcall(function()
        water = BridgeWash.safeCall(fc, "contains", Fluid.Water) == true
            or (Fluid.TaintedWater ~= nil and BridgeWash.safeCall(fc, "contains", Fluid.TaintedWater) == true)
    end)
    return water
end

function BridgeWash.isWaterObject(o)
    if o == nil then return false end
    local custom = nil
    local props = BridgeWash.safeCall(o, "getProperties")
    if props ~= nil then custom = BridgeWash.safeCall(props, "get", "CustomName") end
    if custom == "Dispenser" then return true end
    local fc = BridgeWash.safeCall(o, "getFluidContainer")
    if fc ~= nil then
        if BridgeWash.isWaterFluid(fc) then return true end
        if BridgeWash.safeCall(o, "hasWater") == true then return true end
        return false
    end
    if BridgeWash.safeCall(o, "hasWater") == true then return true end
    return false
end

function BridgeWash.waterUnits(o)
    if o == nil then return 0 end
    local amt = BridgeWash.safeCall(o, "getFluidAmount")
    if type(amt) ~= "number" or amt <= 0 then
        local fc = BridgeWash.safeCall(o, "getFluidContainer")
        if fc ~= nil then amt = BridgeWash.safeCall(fc, "getAmount") end
    end
    if type(amt) ~= "number" then amt = 0 end
    return amt
end

function BridgeWash.waterSquare(square)
    local wet = false
    pcall(function() wet = square ~= nil and square:getWater() ~= nil end)
    return wet
end

function BridgeWash.waterProxy(square)
    local proxy = {}
    proxy.getSquare = function() return square end
    proxy.getName = function() return getText("ContextMenu_WaterName") end
    proxy.isTaintedWater = function() return false end
    proxy.getFluidAmount = function() return 99999 end
    proxy.getFluidContainer = function() return nil end
    proxy.transferFluidTo = function() end
    proxy.transmitModData = function() end
    proxy.useFluid = function() return 1 end
    return proxy
end

function BridgeWash.waterOn(square)
    local found = nil
    if square == nil then return nil end
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local o = objects:get(i)
            if BridgeWash.isWaterObject(o) then
                if found == nil then found = o end
                dbg("waterOn " .. BridgeWash.objInfo(o))
            end
        end
    end)
    if found == nil and BridgeWash.waterSquare(square) then
        found = BridgeWash.waterProxy(square)
        dbg("waterOn natural water square " .. tostring(square:getX()) .. "," .. tostring(square:getY()))
    end
    return found
end


function BridgeWash.waterList(body)
    local list = {}
    pcall(function()
        local cell = getCell()
        local bx, by, bz = math.floor(body:getX()), math.floor(body:getY()), math.floor(body:getZ())
        local home = nil
        pcall(function() local sq = body:getCurrentSquare() if sq ~= nil then home = sq:getBuilding() end end)
        for dx = -RADIUS, RADIUS do
            for dy = -RADIUS, RADIUS do
                local sq = cell:getGridSquare(bx + dx, by + dy, bz)
                if sq ~= nil then
                    local objects = sq:getObjects()
                    for i = 0, objects:size() - 1 do
                        local o = objects:get(i)
                        local wet = false
                        pcall(function()
                            wet = BridgeWash.isWaterObject(o) and (o:getFluidAmount() or 0) > 0
                        end)
                        if wet then
                            local d = dx * dx + dy * dy
                            local house = nil
                            pcall(function() house = sq:getBuilding() end)
                            if house ~= home then d = d + OTHER_HOUSE end
                            list[#list + 1] = { o = o, d = d }
                            if BridgeWash.DEBUG or (Bridge ~= nil and Bridge.verbose == true) then
                                dbg("waterList " .. BridgeWash.objInfo(o))
                            end
                        end
                    end
                end
            end
        end
    end)
    table.sort(list, function(a, b) return a.d < b.d end)
    return list
end


function BridgeWash.findWater(body)
    local list = BridgeWash.waterList(body)
    return list[1] and list[1].o or nil
end


function BridgeWash.isFillable(item)
    if item == nil then return false end
    local ok = false
    pcall(function()
        local fc = item:getFluidContainer()
        if fc == nil then return end
        if item:canStoreWater() ~= true then return end
        if fc:getFreeCapacity() <= 0 then return end
        if fc:getAmount() > 0 then
            local water = false
            pcall(function()
                water = fc:contains(Fluid.Water) == true
                    or (Fluid.TaintedWater ~= nil and fc:contains(Fluid.TaintedWater) == true)
            end)
            if not water then return end
        end
        ok = true
    end)
    return ok
end

function BridgeWash.fillables(body)
    local out = {}
    if body == nil then return out end
    local skip = {}
    for _, it in ipairs(wornList(body)) do skip[it] = true end
    pcall(function()
        for _, it in ipairs(carriedList(body, skip)) do
            if BridgeWash.isFillable(it) then out[#out + 1] = it end
        end
    end)
    return out
end

function BridgeWash.groupByName(list)
    local groups = {}
    if list == nil then return groups end
    local sorted = {}
    for i = 1, #list do sorted[i] = list[i] end
    table.sort(sorted, function(a, b)
        local an, bn = "", ""
        pcall(function() an = tostring(a:getName() or "") end)
        pcall(function() bn = tostring(b:getName() or "") end)
        return string.lower(an) < string.lower(bn)
    end)
    local byName, order = {}, {}
    for _, it in ipairs(sorted) do
        local nm = ""
        pcall(function() nm = tostring(it:getName() or "") end)
        local g = byName[nm]
        if g == nil then g = {} byName[nm] = g order[#order + 1] = g end
        g[#g + 1] = it
    end
    for i = 1, #order do groups[i] = order[i] end
    return groups
end

function BridgeWash.emptyables(body)
    local out = {}
    if body == nil then return out end
    local skip = {}
    for _, it in ipairs(wornList(body)) do skip[it] = true end
    pcall(function()
        for _, it in ipairs(carriedList(body, skip)) do
            local ok = false
            pcall(function()
                local fc = it:getFluidContainer()
                ok = fc ~= nil and fc:getAmount() > 0
            end)
            if ok then out[#out + 1] = it end
        end
    end)
    return out
end

function BridgeWash.fillSoundFor(obj, item)
    if type(obj) == "table" then
        if obj.bridgeTap == true then return "GetWaterFromTap" end
        return "GetWaterFromLake"
    end
    local function itemSound(fn)
        local s = nil
        if item ~= nil then s = BridgeWash.safeCall(item, fn) end
        if type(s) == "string" and s ~= "" then return s end
        return nil
    end
    local name = nil
    if obj ~= nil then
        local props = BridgeWash.safeCall(obj, "getProperties")
        local custom = nil
        if props ~= nil then custom = BridgeWash.safeCall(props, "get", "CustomName") end
        if custom == "Dispenser" then
            name = itemSound("getFillFromDispenserSound") or "GetWaterFromDispenser"
        elseif custom == "Toilet" then
            name = itemSound("getFillFromToiletSound") or "GetWaterFromToilet"
        else
            local hasWaterFlag = props ~= nil and BridgeWash.safeCall(props, "has", IsoFlagType.water) == true
            local isInventoryItem = false
            if instanceof ~= nil then pcall(function() isInventoryItem = instanceof(obj, "IsoWorldInventoryObject") end) end
            local isLakeOrRiver = false
            if not isInventoryItem then
                local spr = BridgeWash.safeCall(obj, "getSprite")
                local sn = spr ~= nil and BridgeWash.safeCall(spr, "getName") or nil
                isLakeOrRiver = type(sn) == "string" and luautils.stringStarts(sn, "blends_natural_02")
            end
            local isPuddle = not hasWaterFlag and not isLakeOrRiver and props ~= nil
                and BridgeWash.safeCall(props, "has", IsoFlagType.solidfloor) == true
            local thumpable = false
            if instanceof ~= nil then pcall(function() thumpable = instanceof(obj, "IsoThumpable") end) end
            if thumpable or hasWaterFlag or isLakeOrRiver or isPuddle then
                name = "GetWaterFromLake"
            else
                name = itemSound("getFillFromTapSound") or "GetWaterFromTap"
            end
        end
    end
    return name or "GetWaterFromTap"
end





local function besideWater(sinkSq, s)
    if sinkSq == nil or s == nil or s:getZ() ~= sinkSq:getZ() then return false end
    if math.abs(s:getX() - sinkSq:getX()) > 1 or math.abs(s:getY() - sinkSq:getY()) > 1 then return false end
    if s == sinkSq then return false end
    local ok = false
    pcall(function() ok = AdjacentFreeTileFinder.privTrySquareForWalls(sinkSq, s) end)
    return ok
end
BridgeWash.besideWater = besideWater

local function spotNear(body, sink)
    local sq = sink:getSquare()
    if sq == nil then return nil end



    local who = body
    if BridgeMove ~= nil and BridgeMove.keepFar ~= nil and BridgeMove.keepFar() then
        pcall(function()
            local red = BridgeData.owner()
            if red ~= nil then who = red end
        end)
    end
    local found = nil
    pcall(function() found = AdjacentFreeTileFinder.Find(sq, who) end)
    if found ~= nil and besideWater(sq, found) then
        return { x = found:getX() + 0.5, y = found:getY() + 0.5, z = found:getZ(), square = found }
    end
    return nil
end

function BridgeWash.stop(why)
    BridgeWash.state = "idle"
    BridgeWash.sink = nil
    BridgeWash.spot = nil
    BridgeWash.queue = nil
    BridgeWash.info = "stopped: " .. tostring(why)
end


local function nextWater(body)
    while BridgeWash.queue ~= nil and #BridgeWash.queue > 0 do
        local entry = table.remove(BridgeWash.queue, 1)
        local spot = nil
        pcall(function() spot = spotNear(body, entry.o) end)
        if spot ~= nil then
            BridgeWash.sink = entry.o
            BridgeWash.spot = spot
            BridgeWash.best = math.huge
            BridgeWash.progressAt = Bridge.time
            BridgeWash.goal = nil
            BridgeWash.fails = 0
            BridgeWash.lastUpdate = Bridge.time
            BridgeMove.doorWay = nil
            return true
        end
    end
    return false
end



function BridgeWash.start(why)
    if Bridge == nil or not Bridge.drivable() then return "no body here" end
    local body = Bridge.body
    if BridgeWash.dirtyParts(body) == 0 then
        sayWash("WashClean", "AlreadyClean")
        return "already clean"
    end
    local list = BridgeWash.waterList(body)
    if #list == 0 then
        sayWash("WashNoWater", "NoWater")
        return "no water nearby"
    end
    BridgeWash.queue = list
    if not nextWater(body) then
        BridgeWash.queue = nil
        sayWash("WashNoPath", "CantReachWater")
        return "water not reachable"
    end
    pcall(function() BridgeHeal.stop("wash") end)
    BridgeMove.pathResult = "none"
    BridgeWash.state = "going"
    BridgeWash.since = Bridge.time
    BridgeWash.info = "going " .. tostring(why)
    Bridge.pose = nil
    BridgeWash.what = washWhat(body)
    sayWash("WashGo" .. BridgeWash.what, "GoWash")
    return "going to wash"
end




local function clean(body, sink, scope)
    if sink == nil then return 0, 0 end
    if type(sink) ~= "table" and not (BridgeWash.isWaterObject ~= nil and BridgeWash.isWaterObject(sink)) then
        return 0, 0
    end
    local water, washed = 0, 0
    local left = 0
    pcall(function() left = sink:getFluidAmount() end)

    if isClient() and left > 60 then left = 60 end
    local tainted = false
    pcall(function() tainted = sink:isTaintedWater() == true end)
    local g = BridgeWash.dirtyGear(body, scope)
    if scope ~= "inventory" then
        pcall(function()
            local visual = body:getHumanVisual()
            for i = 1, BloodBodyPartType.MAX:index() do
                local part = BloodBodyPartType.FromIndex(i - 1)
                if visual:getBlood(part) + visual:getDirt(part) > 0 and water + 1 <= left then
                    visual:setBlood(part, 0)
                    visual:setDirt(part, 0)
                    water = water + 1
                end
            end
        end)
    end
    for _, item in ipairs(g.cloth) do
        local blood, dirt = clothDirt(item)
        local need = math.ceil(4 + blood * 3 + dirt)
        if water + need <= left then
            pcall(function()
                local parts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
                for j = 0, parts:size() - 1 do
                    item:setBlood(parts:get(j), 0)
                    item:setDirt(parts:get(j), 0)
                end
            end)
            pcall(function() if instanceof(item, "Clothing") then item:setWetness(100) item:setDirtiness(0) end end)
            pcall(function() item:setBloodLevel(0) end)
            water = water + need
            washed = washed + 1
        end
    end
    for _, item in ipairs(g.blood) do
        local need = math.ceil(4 + bloodLevel(item) * 3)
        if water + need <= left then
            local after = nil
            pcall(function() after = item:getItemAfterCleaning() end)
            if after ~= nil and after ~= "" then

                pcall(function()
                    local box = item:getContainer()
                    box:Remove(item)
                    box:AddItem(after)
                end)
            else
                pcall(function() item:setBloodLevel(0) end)
            end
            water = water + need
            washed = washed + 1
        end
    end

    if not tainted then
        for _, item in ipairs(g.rags) do
            if water + 1 <= left then
                pcall(function()
                    local box = item:getContainer()
                    local cleanType = BridgeWash.RAGS[item:getFullType()]
                    box:Remove(item)
                    box:AddItem(cleanType)
                end)
                water = water + 1
                washed = washed + 1
            end
        end
    end
    pcall(function()
        if water <= 0 then return end
        if isClient() then

            local sq = sink:getSquare()
            sendClientCommand(BridgeData.owner(), "Bridge", "water", { x = sq:getX(), y = sq:getY(), z = sq:getZ(), amount = water })
        elseif sink:useFluid(water) > 0 then
            pcall(function() sink:transmitModData() end)
        end
    end)
    pcall(function() BridgeInventory.applyWorn(body) end)
    pcall(function() body:resetModelNextFrame() end)
    pcall(function() body:resetModel() end)
    return water, washed
end
BridgeWash.clean = clean


function BridgeWash.update(body)
    if BridgeWash.state == "idle" then return false end
    local sink = BridgeWash.sink
    if sink == nil or BridgeWash.spot == nil then BridgeWash.stop("lost water") return false end

    if Bridge.every(10) then
        local threat = false
        pcall(function()
            local list = nil
            if BridgeZScan ~= nil then
                list = BridgeZScan.near(body:getX(), body:getY(), 5, { tag = "wash.threat" })
            end
            if list == nil then list = getCell():getZombieList() end
            for i = 0, list:size() - 1 do
                local z = list:get(i)
                if z ~= nil and z ~= body and z:isAlive() and not z:getVariableBoolean(Bridge.BODY_VAR)
                    and math.abs(z:getZ() - body:getZ()) < 0.8 and dist(z, body:getX(), body:getY()) < 5
                    and not BridgeData.harmless(z) then
                    threat = true
                    break
                end
            end
        end)
        if threat then
            BridgeWash.stop("zombie")
            sayWash("WashZombie", "WashLater")
            return false
        end
    end
    local spot = BridgeWash.spot
    if BridgeWash.state == "going" then


        local here = nil
        pcall(function() here = body:getCurrentSquare() end)
        local sinkSq = nil
        pcall(function() sinkSq = sink:getSquare() end)
        if here ~= nil and dist(body, spot.x, spot.y) <= REACH and besideWater(sinkSq, here)
            and math.floor(body:getZ() + 0.01) == sinkSq:getZ() then
            BridgeMove.stopPath(body)
            BridgeWash.state = "washing"
            BridgeWash.since = Bridge.time
            return true
        end



        if Bridge.time - (BridgeWash.lastUpdate or 0) > 5 then BridgeWash.progressAt = Bridge.time end
        BridgeWash.lastUpdate = Bridge.time
        local goal = BridgeMove.doorWay or spot
        if goal ~= BridgeWash.goal then
            BridgeWash.goal = goal
            BridgeWash.best = math.huge
            BridgeWash.progressAt = Bridge.time
        end
        local d = dist(body, goal.x, goal.y)
        if d < (BridgeWash.best or math.huge) - 0.3 then
            BridgeWash.best = d
            BridgeWash.progressAt = Bridge.time
        end
        local stalled = (Bridge.time - BridgeWash.progressAt) > STALL_TICKS
        if BridgeMove.pathResult == tostring(BehaviorResult.Failed) and not BridgeMove.pathing then
            if BridgeWash.failTick ~= Bridge.tick then BridgeWash.fails = (BridgeWash.fails or 0) + 1 end
            BridgeWash.failTick = Bridge.tick
            BridgeMove.pathResult = "none"
        end
        local failed = (BridgeWash.fails or 0) >= 2
        if stalled or failed or (Bridge.time - BridgeWash.since) > GO_TICKS then
            BridgeWash.fails = 0
            BridgeMove.stopPath(body)
            BridgeMove.pathResult = "none"
            if (Bridge.time - BridgeWash.since) <= GO_TICKS and nextWater(body) then
                log("water not reachable, next source")
                return true
            end
            BridgeWash.stop("cannot reach")
            sayWash("WashNoPath", "CantReachWater")
            return false
        end
        BridgeMove.walkType = "Walk"
        pcall(function() BridgeMove.goToward(body, spot.x, spot.y, spot.z, true) end)
        return true
    end

    pcall(function()
        local sq = sink:getSquare()
        body:faceLocationF(sq:getX() + 0.5, sq:getY() + 0.5)
    end)
    pcall(function() if body:getBumpType() ~= "washFace" then body:setBumpType("washFace") end end)
    if (Bridge.time - BridgeWash.since) >= WASH_TICKS then
        local water, washed = clean(body, sink)
        pcall(function() body:setBumpType("") end)
        log("washed, water used " .. tostring(water) .. ", items washed " .. tostring(washed))
        BridgeWash.stop("done")
        BridgeWash.info = "done water=" .. tostring(water)
        sayWash("WashDone" .. (BridgeWash.what or "Both"), "Washed")
        pcall(function() Bridge.saveOutfit() end)


        local st = Bridge.store
        local blocked = false
        pcall(function() blocked = st ~= nil and st.waitX ~= nil and BridgeMove.seatBlocks(st.waitX, st.waitY, st.waitZ or 0) end)
        if Bridge.mode ~= "follow" and st ~= nil and st.waitX ~= nil and not blocked then
            Bridge.target = { x = st.waitX, y = st.waitY, z = st.waitZ or 0 }
            Bridge.targetSince = Bridge.time
        end
    end
    return true
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeWash] loaded") end
