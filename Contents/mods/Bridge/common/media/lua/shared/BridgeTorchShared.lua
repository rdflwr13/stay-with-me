

















BridgeTorchShared = BridgeTorchShared or {}


BridgeTorchShared.VAR = "BridgeTorch"

BridgeTorchShared.RANGE_VAR = "BridgeTorchRange"

BridgeTorchShared.DEAD_VAR = "BridgeTorchDead"




BridgeTorchShared.CFG = {

    torchList = {
        ["Base.Torch"] = true,
        ["Base.HandTorch"] = true,
        ["Base.Flashlight_Crafted"] = true,
        ["Base.FlashLight_AngleHead"] = true,
        ["Base.FlashLight_AngleHead_Army"] = true,
        ["Base.PenLight"] = true,
    },


    exclude = {
        ["Base.Candle"] = true,
        ["Base.CandleLit"] = true,
        ["Base.Lantern_Hurricane"] = true,
        ["Base.Lantern_HurricaneLit"] = true,
    },

    excludePrefix = { "Lantern", "Candle", "Glowstick" },

    excludeSuffix = "Lit",




    DARK_LO = 0.45,
    DARK_HI = 0.55,
    DARK_LO_IN = 0.50,


    INDOOR_DAY = 0.35,









    DAY_OFF = 0.20,
    DAY_HYST = 0.07,


    TORCH = 0.05,


    NEAR = 20,




    EXTERNAL_NEAR = 12,



    EXTERNAL_MIN_BRI = 0.25,





    DEFAULT_RANGE = 15,
    color = { 1.0, 0.92, 0.72 },
    beamReach = 2,
    beamRadius = 8,



    DRAIN_SCALE = 1.0,
    DEFAULT_USE_DELTA = 0.006,
}


BridgeTorchShared.state = {}

local itemMemo = setmetatable({}, { __mode = "k" })
local batteryMemo = setmetatable({}, { __mode = "k" })
local ITEM_MEMO_TICKS = 6

local function memoTtl()
    if BridgePerf ~= nil and type(BridgePerf.age) == "function" then
        return BridgePerf.age("torch", ITEM_MEMO_TICKS)
    end
    return ITEM_MEMO_TICKS
end

local function memoClock()
    if Bridge ~= nil and tonumber(Bridge.tick) ~= nil then return tonumber(Bridge.tick) end
    if BridgeServer ~= nil and tonumber(BridgeServer.tick) ~= nil then return tonumber(BridgeServer.tick) end
    return nil
end
BridgeTorchShared.lastHours = {}
BridgeTorchShared.stepAcc = {}

local function log(text) if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then print("[BridgeTorchShared] " .. tostring(text)) end end

local function warn(text) print("[BridgeTorchShared] " .. tostring(text)) end





function BridgeTorchShared.keyOf(body)
    if body == nil then return nil end
    local pid = nil
    pcall(function() pid = body:getPersistentOutfitID() end)
    if pid ~= nil then return "p" .. tostring(pid) end
    return "o" .. tostring(body)
end

local function typeOf(item)
    local t = nil
    pcall(function() t = item:getFullType() end)
    if type(t) ~= "string" or t == "" then
        pcall(function() t = item:getType() end)
    end
    return type(t) == "string" and t or nil
end

local function startsWith(text, prefix)
    return text ~= nil and prefix ~= nil and string.sub(text, 1, #prefix) == prefix
end

local function endsWith(text, suffix)
    return text ~= nil and suffix ~= nil and #text >= #suffix and string.sub(text, #text - #suffix + 1) == suffix
end



function BridgeTorchShared.isExcluded(item, t)
    if item == nil then return true end
    t = t or typeOf(item)
    if t == nil then return true end
    if BridgeTorchShared.CFG.exclude[t] then return true end
    local prefixes = BridgeTorchShared.CFG.excludePrefix
    for i = 1, #prefixes do
        if startsWith(t, prefixes[i]) then return true end
    end
    if endsWith(t, BridgeTorchShared.CFG.excludeSuffix) then return true end
    return false
end

function BridgeTorchShared.isListedTorch(item)
    if item == nil then return false end
    local ft, t = nil, nil
    pcall(function() ft = item:getFullType() end)
    pcall(function() t = item:getType() end)
    if ft ~= nil and BridgeTorchShared.CFG.torchList[ft] == true then return true end
    if t ~= nil and BridgeTorchShared.CFG.torchList[t] == true then return true end

    if t ~= nil and t ~= "" then
        local dot = "." .. t
        for k in pairs(BridgeTorchShared.CFG.torchList) do
            if string.sub(k, -#dot) == dot then return true end
        end
    end
    return false
end


function BridgeTorchShared.canLight(item)
    if item == nil then return false end
    local light = false
    pcall(function() light = item:canEmitLight() and item:getLightStrength() > 0 end)
    if not light then return false end
    return not BridgeTorchShared.isExcluded(item)
end

function BridgeTorchShared.isDrainable(item)
    if item == nil then return false end
    local ok, value = pcall(function() return item:IsDrainable() == true end)
    return ok and value == true
end







function BridgeTorchShared.isFlashlight(item)
    if item == nil then return false end
    if BridgeTorchShared.isListedTorch(item) then return true end
    if BridgeTorchShared.isExcluded(item) then return false end

    local cat = nil
    if type(item.getDisplayCategory) == "function" then
        pcall(function() cat = item:getDisplayCategory() end)
    end
    if cat == "LightSource" then return true end

    local s = ""
    pcall(function() s = tostring(item:getFullType()) .. " " .. tostring(item:getType()) end)
    s = string.lower(s)
    if string.find(s, "flashlight", 1, true) ~= nil
        or string.find(s, "handtorch", 1, true) ~= nil
        or string.find(s, "penlight", 1, true) ~= nil then
        return true
    end

    return false
end


function BridgeTorchShared.charge(item)
    local c = 1
    pcall(function()
        if item:IsDrainable() then c = item:getCurrentUsesFloat() end
    end)
    c = tonumber(c)
    if c == nil then c = 1 end
    return c
end

function BridgeTorchShared.rangeOf(item)
    local range = BridgeTorchShared.CFG.DEFAULT_RANGE
    if item == nil then return range end


    local has = false
    pcall(function() has = type(item.getLightDistance) == "function" end)
    if has then
        pcall(function()
            local d = item:getLightDistance()
            if type(d) == "number" and d > 0 then range = d end
        end)
    end
    return range
end











local function eachItem(body, fn)
    if body == nil then return false end
    local function walk(inv, depth)
        if inv == nil or depth > 3 then return false end
        local items = nil
        pcall(function() items = inv:getItems() end)
        if items == nil then return false end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it ~= nil then
                if fn(it) == true then return true end
                local isBag = false
                pcall(function() isBag = it:IsInventoryContainer() == true end)
                if isBag then
                    local sub = nil
                    pcall(function() sub = it:getInventory() end)
                    if walk(sub, depth + 1) then return true end
                end
            end
        end
        return false
    end
    local inv = nil
    pcall(function() inv = body:getInventory() end)
    return walk(inv, 0)
end
BridgeTorchShared.eachItem = eachItem


function BridgeTorchShared.findBattery(body)
    if body == nil then return nil end
    local now = memoClock()
    local memo = now ~= nil and batteryMemo[body] or nil
    if memo ~= nil and now - memo.at < memoTtl() then return memo.item end
    local found = nil
    eachItem(body, function(it)
        local t = nil
        local okType, typ = pcall(it.getType, it)
        if okType then t = typ end
        if t == "Battery" then found = it return true end
        return false
    end)
    if now ~= nil then batteryMemo[body] = { at = now, item = found } end
    return found
end





function BridgeTorchShared.pullToMain(body, item)
    if body == nil or item == nil then return false end
    local mp = false
    pcall(function() mp = (Bridge ~= nil and Bridge.mp == true) end)
    if mp then
        local srv = false
        pcall(function() srv = isServer() == true end)
        if not srv then return false end
    end
    local inv = nil
    pcall(function() inv = body:getInventory() end)
    if inv == nil then return false end
    local top = false
    pcall(function() top = item:getContainer() == inv end)
    if top then return true end
    local moved = false
    pcall(function()
        local c = item:getContainer()
        if c == nil then return end
        c:Remove(item)
        inv:AddItem(item)
        if item:getContainer() == inv then
            moved = true
        else

            c:AddItem(item)
        end
    end)
    if moved then
        pcall(function() if sendItemStats ~= nil then sendItemStats(item) end end)
    end
    return moved
end





local rejectedLight = {}
local function noteRejectedLight(item)
    if type(BridgeTorch) ~= "table" or BridgeTorch.DEBUG ~= true then return end
    local t = typeOf(item)
    if t == nil or rejectedLight[t] then return end
    rejectedLight[t] = true
    log("ignoring non-drainable light " .. t)
end

function BridgeTorchShared.findTorch(body)
    if body == nil then return nil end
    local now = memoClock()
    local memo = now ~= nil and itemMemo[body] or nil
    if memo ~= nil and now - memo.at < memoTtl() then return memo.item end

    local function bestOf(predicate, allowEmpty)
        local best, bestScore = nil, -1
        eachItem(body, function(it)
            local ok, yes = pcall(predicate, it)
            if ok and yes then
                local c = BridgeTorchShared.charge(it)
                if allowEmpty or c > 0.0001 then
                    local strength = 0
                    pcall(function() strength = it:getLightStrength() or 0 end)

                    local score = c * 100 + strength
                    if score > bestScore then best, bestScore = it, score end
                end
            end
            return false
        end)
        return best
    end

    local result = nil
    local listed = bestOf(function(it)
        if not BridgeTorchShared.isListedTorch(it) then return false end
        if not BridgeTorchShared.isDrainable(it) then noteRejectedLight(it) return false end
        return BridgeTorchShared.canLight(it)
    end)
    if listed ~= nil then
        BridgeTorchShared.pullToMain(body, listed)
        result = listed
    else
        local generic = bestOf(function(it)
            if BridgeTorchShared.isListedTorch(it) then return false end
            if not BridgeTorchShared.canLight(it) then return false end
            if not BridgeTorchShared.isDrainable(it) then noteRejectedLight(it) return false end
            return true
        end)
        if generic ~= nil then
            BridgeTorchShared.pullToMain(body, generic)
            result = generic
        else
            local dead = bestOf(function(it)
                return BridgeTorchShared.isListedTorch(it) and BridgeTorchShared.isDrainable(it)
            end, true)
            if dead ~= nil then BridgeTorchShared.pullToMain(body, dead) end
            result = dead
        end
    end
    if now ~= nil then itemMemo[body] = { at = now, item = result } end
    return result
end









function BridgeTorchShared.darkAt(body)
    local lvl = 1
    pcall(function()
        local sq = body:getCurrentSquare()
        if sq == nil then return end




        local pnum = 0
        pcall(function()
            local p = getPlayer()
            if p ~= nil then pnum = p:getPlayerNum() or 0 end
        end)
        lvl = sq:getLightLevel(pnum)

        if lvl > 0.8 then lvl = 1 end
        local c = getClimateManager()
        if sq:isOutside() then
            if c ~= nil then lvl = math.max(c:getDayLightStrength(), lvl) end
        else
            if c ~= nil then lvl = lvl + (tonumber(c:getDayLightStrength()) or 0) * BridgeTorchShared.CFG.INDOOR_DAY end
        end
    end)
    lvl = tonumber(lvl)
    if lvl == nil then lvl = 1 end
    return lvl
end

function BridgeTorchShared.isOn(body)
    local on = false
    pcall(function() on = body:getVariableBoolean(BridgeTorchShared.VAR) == true end)
    return on
end

local function prevOn(body)
    local st = BridgeTorchShared.state[BridgeTorchShared.keyOf(body)]
    return st ~= nil and st.on == true
end

local function setPrevOn(body, on)
    BridgeTorchShared.state[BridgeTorchShared.keyOf(body)] = { on = on == true }
end



function BridgeTorchShared.remember(body, on)
    setPrevOn(body, on)
end


local function override()
    if type(BridgeTorch) == "table" then
        if BridgeTorch.TEST_ON == true then return "on" end
        if BridgeTorch.TEST_OFF == true then return "off" end
    end
    return nil
end

local function modeOf()
    local rec = nil
    if type(Bridge) == "table" then rec = Bridge.store end
    if BridgeData ~= nil and type(BridgeData.torchMode) == "function" then
        return BridgeData.torchMode(rec)
    end
    return "auto"
end

local function ownerNear(body, red)
    if red == nil then return false end
    local near = false
    pcall(function()
        local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
        near = dx * dx + dy * dy <= BridgeTorchShared.CFG.NEAR * BridgeTorchShared.CFG.NEAR
            and math.abs(red:getZ() - body:getZ()) < 1
    end)
    return near
end



function BridgeTorchShared.isDark(lvl, external, why, lo)
    if lvl == nil then return false end
    if external == true and why ~= nil
        and (why == "daylight" or startsWith(why, "foreignLight") or why == "vehicleLight") then
        return false
    end
    return lvl < (lo or BridgeTorchShared.CFG.DARK_LO)
end


function BridgeTorchShared.wantOn(body, red, lvl, external, why)
    if body == nil then return false end

    local ov = override()
    if ov == "on" then return true end
    if ov == "off" then return false end

    local mode = modeOf()
    if mode == "off" then return false end

    local item = BridgeTorchShared.findTorch(body)
    if item == nil then return false end
    if BridgeTorchShared.charge(item) <= 0.0001 then return false end

    if not ownerNear(body, red) then return false end

    local was = prevOn(body)


    if was then




        if lvl ~= nil and lvl >= BridgeTorchShared.CFG.DARK_HI then return false end
        return external ~= true
    end




    if lvl == nil then lvl = BridgeTorchShared.darkAt(body) end

    local lo = BridgeTorchShared.CFG.DARK_LO
    pcall(function()
        local sq = body:getCurrentSquare()
        if sq ~= nil and sq:isOutside() == false then lo = BridgeTorchShared.CFG.DARK_LO_IN end
    end)






    return BridgeTorchShared.isDark(lvl, external, why, lo)
end







function BridgeTorchShared.apply(body, on, range)
    if body == nil then return nil end
    on = on == true
    local was = prevOn(body)





    local item = BridgeTorchShared.findTorch(body)
    if range == nil and item ~= nil then range = BridgeTorchShared.rangeOf(item) end
    if range == nil then range = BridgeTorchShared.CFG.DEFAULT_RANGE end

    pcall(function() body:setVariable(BridgeTorchShared.VAR, on) end)
    pcall(function()
        body:setVariable(BridgeTorchShared.RANGE_VAR, on and tostring(range) or "")
    end)
    setPrevOn(body, on)
    if was ~= on then
        local key = BridgeTorchShared.keyOf(body)
        pcall(function() BridgeTorchShared.lastHours[key] = getGameTime():getWorldAgeHours() end)
    end
    return item
end



local function gameMinutesSince(body)
    local now = nil
    pcall(function() now = getGameTime():getWorldAgeHours() end)
    if type(now) ~= "number" then return 0 end
    local key = BridgeTorchShared.keyOf(body)
    local last = BridgeTorchShared.lastHours[key]
    BridgeTorchShared.lastHours[key] = now
    if type(last) ~= "number" then return 0 end
    local d = (now - last) * 60
    if d <= 0 or d > 600 then return 0 end
    return d
end


local function setTorchCharge(item, value)
    if item == nil then return false end
    local ok = false
    pcall(function()
        if type(item.setUsedDelta) == "function" then
            item:setUsedDelta(value)
            ok = true
        elseif type(item.setCurrentUsesFloat) == "function" then
            item:setCurrentUsesFloat(value)
            ok = true
        end
    end)
    return ok
end

function BridgeTorchShared.drain(body, dt)
    if body == nil then return false, "none" end
    local item = BridgeTorchShared.findTorch(body)
    if item == nil then return false, "none" end
    if not BridgeTorchShared.isDrainable(item) then return false, "not-drainable" end
    local c = BridgeTorchShared.charge(item)
    if c <= 0.0001 then return true, "empty" end

    local rate = BridgeTorchShared.CFG.DEFAULT_USE_DELTA
    pcall(function()
        local r = item:getUseDelta()
        if type(r) == "number" and r > 0 then rate = r end
    end)
    rate = rate * BridgeTorchShared.CFG.DRAIN_SCALE

    local minutes = gameMinutesSince(body)
    if minutes <= 0 then return false, "wait" end

    local key = BridgeTorchShared.keyOf(body)
    local acc = (BridgeTorchShared.stepAcc[key] or 0) + minutes
    local steps = math.floor(acc / 10)
    BridgeTorchShared.stepAcc[key] = acc - steps * 10
    if steps <= 0 then return false, "wait" end

    local left = c - rate * steps
    if left < 0 then left = 0 end
    setTorchCharge(item, left)
    if left <= 0.0001 then return true, "empty" end
    return false, "ok"
end


function BridgeTorchShared.swapBattery(body)
    if body == nil then return false end
    local inv = nil
    pcall(function() inv = body:getInventory() end)
    if inv == nil then return false end




    local battery = BridgeTorchShared.findBattery(body)
    if battery == nil then return false end


    local batteryCharge = 1
    pcall(function() batteryCharge = BridgeTorchShared.charge(battery) end)
    batteryCharge = tonumber(batteryCharge) or 1
    if batteryCharge < 0 then batteryCharge = 0 end

    local item = BridgeTorchShared.findTorch(body)
    if item == nil then return false end
    if not BridgeTorchShared.isDrainable(item) then return false end

    local removed, removedFrom = false, nil
    pcall(function()
        local c = battery:getContainer() or inv
        c:Remove(battery)
        removedFrom = c
        removed = true
    end)
    if not removed then return false end

    setTorchCharge(item, batteryCharge)


    pcall(function()
        if isServer() and sendRemoveItemFromContainer ~= nil and removedFrom ~= nil then
            sendRemoveItemFromContainer(removedFrom, battery)
        end
    end)
    pcall(function()
        if sendItemStats ~= nil then sendItemStats(item) end
    end)
    log("swapped in a fresh battery")
    return true
end



function BridgeTorchShared.inCombat(body)
    local fighting = false
    pcall(function()
        fighting = BridgeFight ~= nil and (BridgeFight.state ~= "idle" or BridgeFight.target ~= nil)
    end)
    if not fighting then
        pcall(function() fighting = body ~= nil and body:getTarget() ~= nil end)
    end
    return fighting == true
end




function BridgeTorchShared.beamPoint(range)
    local r = tonumber(range)
    if r == nil or r <= 0 then r = BridgeTorchShared.CFG.DEFAULT_RANGE end
    local scale = r / BridgeTorchShared.CFG.DEFAULT_RANGE
    if scale < 0.8 then scale = 0.8 elseif scale > 1.5 then scale = 1.5 end
    local reach = BridgeTorchShared.CFG.beamReach * scale
    local radius = math.max(4, math.floor(BridgeTorchShared.CFG.beamRadius * scale + 0.5))
    return reach, radius
end

log("loaded")
