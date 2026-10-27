
BridgeShower = BridgeShower or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeShower] " .. tostring(text)) end end
local function warn(text) print("[BridgeShower] " .. tostring(text)) end

BridgeShower.enabled = true
BridgeShower.COOLDOWN_HOURS = 24
BridgeShower.WATER_MIN = 5
BridgeShower.WATER_MAX = 15

BridgeShower.BUMP_UNDRESS = "ShowerUndress"
BridgeShower.BUMP_DRESS = "ShowerDress"
BridgeShower.BUMP_START = "ShowerStart"
BridgeShower.BUMP_STOP = "ShowerStop"
BridgeShower.BUMP_TOWEL = "ShowerTowelDry"
BridgeShower.BUMP_WASH = "ShowerWash"
BridgeShower.BUMP_WASH_V = "ShowerWashV"

BridgeShower.WASH_PARTS_TABAS = { "Torso", "Arms", "Head" }
BridgeShower.WASH_PARTS_VANILLA = { "Face", "Hands", "Mid" }

BridgeShower.preShower = nil
BridgeShower.waterObj = nil
BridgeShower.waterSq = nil

local function worldHours()
    local h = nil
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h
end

local function body()
    local b = nil
    pcall(function() b = Bridge ~= nil and Bridge.body or nil end)
    return b
end

local function owner()
    local red = nil
    pcall(function() red = BridgeData ~= nil and BridgeData.owner ~= nil and BridgeData.owner() or nil end)
    return red
end


function BridgeShower.isTabas()
    local on = false
    pcall(function() on = BridgeBath ~= nil and BridgeBath.active ~= nil and BridgeBath.active() == true end)
    return on
end


function BridgeShower.facingOf(showerObj)
    local facing = nil
    pcall(function()
        local iso = require("TABAS_Iso")
        local f = iso.getObjectFacing(showerObj)
        if type(f) == "string" and f ~= "" then facing = f end
    end)
    return facing
end


function BridgeShower.faceDirName(facing)
    if facing == "S" then return "N" end
    if facing == "E" then return "W" end
    if facing == "W" then return "E" end
    return "S"
end


function BridgeShower.canHot(showerObj)
    local hot = true
    pcall(function()
        local iso = require("TABAS_Iso")
        hot = iso.canHot(showerObj) == true
    end)
    return hot
end



function BridgeShower.cooldownLeft(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return 0 end
    local untilH = tonumber(rec.showerUntil)
    local now = worldHours()
    if untilH == nil or now == nil then return 0 end
    local left = untilH - now
    if left < 0 then left = 0 end
    return left
end


function BridgeShower.setCooldown(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    local now = worldHours()
    if now == nil then return end
    local untilH = now + BridgeShower.COOLDOWN_HOURS
    if rec ~= nil then rec.showerUntil = untilH end
    if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { showerUntil = untilH }) end)
    end
    log(string.format("set cooldown until %.2f (%.0fh)", untilH, BridgeShower.COOLDOWN_HOURS))
end


function BridgeShower.resetCooldown(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec ~= nil then rec.showerUntil = nil end
    if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { showerUntil = 0 }) end)
    end
    log("cooldown cleared")
end


function BridgeShower.ready(rec)
    if BridgeShower.cooldownLeft(rec) > 0 then return false, "cooldown" end
    return true
end


function BridgeShower.progress(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return 0 end
    local v = tonumber(rec.showerProgress) or 0
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return v
end


function BridgeShower.setProgress(rec, v)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return end
    v = tonumber(v) or 0
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    rec.showerProgress = v
    if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { showerProgress = v }) end)
    end
end



function BridgeShower.hasPreShower()
    return BridgeShower.preShower ~= nil
end


function BridgeShower.snapshotOutfit(b)
    b = b or body()
    if b == nil then return false end
    BridgeShower.preShower = nil
    local list = nil
    pcall(function() list = BridgeInventory.snapshot(b) end)
    if list == nil then return false end

    BridgeItems.truncated = false
    local enc = nil
    local ok = pcall(function() enc = BridgeInventory.encode(list) end)
    if not ok or type(enc) ~= "string" then return false end
    if enc == "" and #list > 0 then return false end


    if BridgeItems.truncated == true then
        warn("shower snapshot truncated, refusing to undress")
        return false
    end

    BridgeShower.preShower = { enc = enc, list = list }
    pcall(function()
        if Bridge ~= nil and Bridge.store ~= nil and enc ~= "" then
            Bridge.store.showerOutfit = BridgeItems.store(enc)
        end
    end)
    log("outfit snapshot taken (" .. tostring(#list) .. " records)")
    return true
end


function BridgeShower.strip(b)
    b = b or body()
    if b == nil then return false end
    local inv = nil
    pcall(function() inv = b:getInventory() end)
    if inv == nil then return false end

    local main, sec = nil, nil
    pcall(function() main = b:getPrimaryHandItem() end)
    pcall(function() sec = b:getSecondaryHandItem() end)
    pcall(function() b:setPrimaryHandItem(nil) end)
    pcall(function() b:setSecondaryHandItem(nil) end)
    if main ~= nil then
        local here = false
        pcall(function() here = inv:contains(main) end)
        if not here then pcall(function() inv:AddItem(main) end) end
    end
    if sec ~= nil and sec ~= main then
        local here = false
        pcall(function() here = inv:contains(sec) end)
        if not here then pcall(function() inv:AddItem(sec) end) end
    end

    local wornCount = 0
    local worn = nil
    pcall(function() worn = b:getWornItems() end)
    if worn ~= nil then
        local n = 0
        pcall(function() n = worn:size() end)
        for i = n - 1, 0, -1 do
            local it = nil
            pcall(function() it = worn:getItemByIndex(i) end)
            if it ~= nil then
                wornCount = wornCount + 1
                pcall(function() b:removeWornItem(it) end)
                local here = false
                pcall(function() here = inv:contains(it) end)
                if not here then pcall(function() inv:AddItem(it) end) end
            end
        end
    end

    pcall(function() if BridgeInventory.redress ~= nil then BridgeInventory.redress(b, true) end end)
    log("stripped for shower (" .. tostring(wornCount) .. " worn, "
        .. tostring(main ~= nil and 1 or 0) .. tostring(sec ~= nil and 1 or 0) .. " hands)")
    return true
end


function BridgeShower.restorePreShower(b)
    local snap = BridgeShower.preShower
    if snap == nil then return false end
    b = b or body()
    if b == nil then return false end
    local list = snap.list
    if list == nil then
        pcall(function() list = BridgeInventory.decode(snap.enc or "") end)
    end
    if list == nil then
        BridgeShower.preShower = nil
        pcall(function() if Bridge ~= nil and Bridge.store ~= nil then Bridge.store.showerOutfit = nil end end)
        return false
    end
    local ok = true
    pcall(function() BridgeInventory.restore(b, list) end)
    pcall(function() if BridgeInventory.redress ~= nil then BridgeInventory.redress(b, true) end end)
    BridgeShower.preShower = nil
    pcall(function() if Bridge ~= nil and Bridge.store ~= nil then Bridge.store.showerOutfit = nil end end)
    log("outfit restored ok=" .. tostring(ok))
    return true
end


function BridgeShower.restorePersisted(b)
    b = b or body()
    if b == nil then return false end
    local store = (Bridge ~= nil) and Bridge.store or nil
    local enc = BridgeItems.text(store and store.showerOutfit)
    if store ~= nil then store.showerOutfit = nil end
    if type(enc) ~= "string" or enc == "" then return false end
    local list = nil
    pcall(function() list = BridgeInventory.decode(enc) end)
    if list == nil then return false end
    pcall(function() BridgeInventory.restore(b, list) end)
    pcall(function() if BridgeInventory.redress ~= nil then BridgeInventory.redress(b, true) end end)
    log("outfit restored from before the interrupted shower")
    return true
end


function BridgeShower.redressNow()
    if not BridgeShower.hasPreShower() then return "dressed" end
    BridgeShower.restorePreShower(body())
    return "dressed"
end


function BridgeShower.findTowel(b)
    b = b or body()
    if b == nil then return nil end
    local found = nil
    pcall(function()
        local inv = b:getInventory()
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it ~= nil and tostring(it:getType()) == "BathTowel" then found = it return end
        end
    end)
    return found
end



function BridgeShower.spawnShowerWater(sq, facing, hot)
    if sq == nil then return nil end
    BridgeShower.removeShowerWater()
    local sprite = nil
    pcall(function()
        local iso = require("TABAS_Iso")
        sprite = iso.getSpritesTable("ShowerBlank", "sprite" .. tostring(facing or "S"))
    end)
    if sprite == nil then
        warn("no ShowerBlank sprite for facing " .. tostring(facing))
        return nil
    end
    local obj = nil
    pcall(function() obj = IsoObject.new(sq, sprite, "ShowerWater") end)
    if obj == nil then return nil end
    pcall(function() obj:setName("ShowerWater") end)
    pcall(function()
        local md = obj:getModData()
        md.facing = facing
        md.isHotWater = hot == true
    end)
    pcall(function() sq:AddSpecialObject(obj) end)
    pcall(function() obj:transmitModData() end)
    pcall(function() triggerEvent("OnObjectAdded", obj) end)
    BridgeShower.waterObj = obj
    BridgeShower.waterSq = sq
    log(string.format("water on at %d,%d hot=%s facing=%s", sq:getX(), sq:getY(), tostring(hot), tostring(facing)))
    return obj
end


function BridgeShower.removeShowerWater()
    local obj = BridgeShower.waterObj
    local sq = BridgeShower.waterSq
    BridgeShower.waterObj, BridgeShower.waterSq = nil, nil
    if obj == nil then return end
    pcall(function()
        local s = sq
        if s == nil then s = obj:getSquare() end
        if s == nil then return end
        if isClient() then pcall(function() s:transmitRemoveItemFromSquareOnClients(obj) end) end
        s:RemoveTileObject(obj)
    end)
    log("water off")
end



function BridgeShower.showing()
    return BridgeTask ~= nil and BridgeTask.active == true and BridgeTask.kind == "shower"
end


function BridgeShower.startAtNearest()
    local red = owner()
    if red == nil then return "no player" end
    local best, bestD = nil, nil
    pcall(function()
        local iso = require("TABAS_Iso")
        local cell = getCell()
        local rx, ry, rz = math.floor(red:getX()), math.floor(red:getY()), math.floor(red:getZ())
        local r = 12
        for dx = -r, r do
            for dy = -r, r do
                local sq = cell:getGridSquare(rx + dx, ry + dy, rz)
                if sq ~= nil then
                    local obj = iso.getShowerObjectOnSquare(sq, false)
                    if obj ~= nil then
                        local d = dx * dx + dy * dy
                        if bestD == nil or d < bestD then best, bestD = obj, d end
                    end
                end
            end
        end
    end)
    if best == nil then return "no shower nearby" end
    return BridgeShower.start(best)
end


function BridgeShower.waterSink(showerObj)
    if BridgeBath == nil or BridgeBath.sinkProxy == nil then return nil end
    local sink = nil
    pcall(function() sink = BridgeBath.sinkProxy(showerObj) end)
    return sink
end


function BridgeShower.waterAvailable(sink)
    if sink == nil then return 0 end
    local avail = 0
    pcall(function() avail = BridgeWash.waterUnits(sink) end)
    if type(avail) ~= "number" or avail < 0 then avail = 0 end
    return avail
end


function BridgeShower.consumeWater(sink, sq, amount)
    if sink == nil or amount == nil or amount <= 0 then return 0 end
    local used = 0
    pcall(function() used = sink:useFluid(amount) end)
    if type(used) ~= "number" then used = 0 end
    pcall(function() sink:transmitModData() end)
    return used
end


function BridgeShower.occupied(object)
    if object == nil then return false end
    local sq = nil
    pcall(function() sq = object:getSquare() end)
    if sq == nil then return false end
    local busy = false
    pcall(function()
        local list = sq:getSpecialObjects()
        for i = 0, list:size() - 1 do
            local o = list:get(i)
            if o ~= nil and o:getName() ~= nil and tostring(o:getName()) == "ShowerWater" then busy = true break end
        end
    end)
    if busy then return true end
    pcall(function()
        local u = require("TABAS_Utils")
        if u.isCurrentlyUsing(BridgeData.owner(), object) == true then busy = true end
    end)
    if busy then return true end
    pcall(function()
        local red = BridgeData.owner()
        if red ~= nil then
            local rs = red:getSquare()
            if rs ~= nil and rs:getX() == sq:getX() and rs:getY() == sq:getY() and rs:getZ() == sq:getZ() then
                busy = true
            end
        end
    end)
    return busy
end


function BridgeShower.guardTabas()
    if BridgeShower.tabasGuarded then return end
    local mod = nil
    pcall(function() mod = require("ContextMenu/TABAS_ContextMenuShower") end)
    if type(mod) ~= "table" then return end
    BridgeShower.tabasGuarded = true

    local function busyOn(object)
        if not (BridgeTask ~= nil and BridgeTask.active == true and BridgeTask.kind == "shower") then return false end
        local t = BridgeTask.showerSq
        local sq = nil
        pcall(function() sq = object ~= nil and object:getSquare() or nil end)
        if t == nil or sq == nil then return false end
        return sq:getX() == t.x and sq:getY() == t.y and sq:getZ() == t.z
    end

    local function makeGuard(orig)
        return function(player, object, ...)
            if busyOn(object) then
                pcall(function()
                    local p = getSpecificPlayer(player)
                    if p == nil then return end
                    local msg = "Someone's already using this."
                    pcall(function()
                        local t = getTextOrNull("IGUI_NotAlone_ShowerInUse")
                        if t ~= nil and t ~= "" and t ~= "IGUI_NotAlone_ShowerInUse" then msg = t end
                    end)
                    p:Say(msg)
                end)
                return
            end
            if orig ~= nil then return orig(player, object, ...) end
        end
    end

    if mod.onTakeShower ~= nil then mod.onTakeShower = makeGuard(mod.onTakeShower) end
    if mod.onTakeShowerInBath ~= nil then mod.onTakeShowerInBath = makeGuard(mod.onTakeShowerInBath) end
    log("tabas shower guarded")
end


function BridgeShower.start(showerObj, sq)
    if BridgeTask == nil or BridgeTask.start == nil then return "no task" end
    if BridgeTask.active then
        if BridgeTask.kind == "shower" then return "already" end
        return "busy"
    end
    if Bridge == nil or not Bridge.alive() or Bridge.kind ~= "zombie" then return "no body" end
    if Bridge.drivable ~= nil and not Bridge.drivable() then return "not drivable" end
    if not BridgeShower.isTabas() then return "no tabas" end
    if BridgeBath ~= nil and BridgeBath.showerUsable ~= nil
            and not BridgeBath.showerUsable(showerObj) then
        return "no shower fixture"
    end
    local busy = false
    if BridgeExercise ~= nil and BridgeExercise.hardBusy ~= nil then
        pcall(function() busy = BridgeExercise.hardBusy() == true end)
    end
    if busy then return "busy" end
    if BridgeTask.dangerNear ~= nil then
        local danger = false
        pcall(function() danger = BridgeTask.dangerNear(Bridge.body) == true end)
        if danger then return "danger" end
    end
    if BridgeShower.occupied(showerObj) then return "occupied" end
    BridgeShower.guardTabas()
    local sink = nil
    pcall(function() sink = BridgeShower.waterSink(showerObj) end)
    if sink ~= nil and BridgeShower.waterAvailable(sink) < 1 then return "nowater" end
    local ok, why = BridgeShower.ready(Bridge.store)
    if not ok then return why end
    local def = BridgeTask.kinds ~= nil and BridgeTask.kinds.shower or nil
    if def == nil or (def.available ~= nil and not def.available(Bridge.body)) then return "unavailable" end

    local target = sq
    if target == nil then
        pcall(function()
            local s = showerObj:getSquare()
            if s ~= nil then target = { x = s:getX(), y = s:getY(), z = s:getZ() } end
        end)
    end
    if target == nil then return "no shower" end

    local res = BridgeTask.start("shower", { target }, nil, {
        shower = showerObj,
        sq = { x = target.x, y = target.y, z = target.z },
        facing = BridgeShower.facingOf(showerObj),
    })
    log("start " .. tostring(res))
    return res
end


function BridgeShower.stop()
    if BridgeTask ~= nil and BridgeTask.active and BridgeTask.kind == "shower" then
        return BridgeTask.cancel("menu")
    end
    return "not showering"
end


if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function()
        pcall(function() BridgeShower.guardTabas() end)
    end)
end


if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeShower] loaded") end
