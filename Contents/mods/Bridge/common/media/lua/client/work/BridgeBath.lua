
BridgeBath = BridgeBath or {}

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeBath] " .. tostring(text)) end
end

local function modActive(id)
    local on = false
    pcall(function() on = getActivatedMods():contains(id) == true end)
    return on
end

function BridgeBath.active()
    if BridgeBath._active == nil then
        BridgeBath._active = modActive("TakeABathAndShowerNew")
    end
    return BridgeBath._active
end

local function tabas()
    if BridgeBath._iso == nil then
        local ok, mod = pcall(require, "TABAS_Iso")
        BridgeBath._iso = ok and mod or false
    end
    if BridgeBath._water == nil then
        local ok, mod = pcall(require, "TABAS_WaterReader")
        BridgeBath._water = ok and mod or false
    end
    return BridgeBath._iso or nil, BridgeBath._water or nil
end

local function displayName(obj)
    local nm = nil
    pcall(function()
        if ISWorldObjectContextMenu ~= nil and ISWorldObjectContextMenu.getMoveableDisplayName ~= nil then
            nm = ISWorldObjectContextMenu.getMoveableDisplayName(obj)
        end
    end)
    return nm
end

local function faucetAmount(faucetObj, water)
    local own = 0
    pcall(function() own = faucetObj:getFluidAmount() or 0 end)
    local piped = 0
    if water ~= nil then pcall(function() piped = water.getWaterAmount(faucetObj) or 0 end) end
    return math.max(own, piped)
end

local function useFaucet(faucetObj, water, amount)
    local used = 0
    pcall(function() used = faucetObj:useFluid(amount) or 0 end)
    if used <= 0 and water ~= nil then
        pcall(function() used = water.consume(faucetObj, amount) or 0 end)
    end
    pcall(function() faucetObj:transmitModData() end)
    return used
end

local function tfcHasWater(tfc)
    local has = false
    pcall(function() has = tfc ~= nil and tfc:hasFluid() == true end)
    return has
end

local function useTfc(tfc, amount)
    local used = 0
    pcall(function()
        local fc = tfc:getTubFluidContainer()
        if fc ~= nil then used = fc:useFluid(amount) or 0 end
    end)
    pcall(function() if tfc.tfcObject ~= nil then tfc.tfcObject:transmitModData() end end)
    return used
end

function BridgeBath.sinkProxy(faucetObj)
    local iso, water = tabas()
    if iso == nil or faucetObj == nil then return nil end

    local square = nil
    pcall(function() square = faucetObj:getSquare() end)
    if square == nil then return nil end

    local tfc = nil
    pcall(function() tfc = iso.getTfcBaseOnBathObject(faucetObj) end)

    local tainted = false
    pcall(function() tainted = faucetObj:isTaintedWater() == true end)
    if not tainted and tfc ~= nil then
        pcall(function() tainted = tfc:isDirtyWater() == true end)
    end

    local proxy = {}
    proxy.bridgeTap = true
    proxy.bridgeBath = true
    proxy.getSquare = function() return square end
    proxy.getName = function() return displayName(faucetObj) end
    proxy.isTaintedWater = function() return tainted end
    proxy.getFluidContainer = function() return nil end
    proxy.transmitModData = function() end
    proxy.getFluidAmount = function()
        local fromFaucet = faucetAmount(faucetObj, water)
        if fromFaucet > 0 then return fromFaucet end
        if tfcHasWater(tfc) then return tfc:getAmount() or 0 end
        return fromFaucet
    end
    proxy.useFluid = function(self, amount)
        if faucetAmount(faucetObj, water) > 0 then
            return useFaucet(faucetObj, water, amount)
        end
        if tfcHasWater(tfc) then return useTfc(tfc, amount) end
        return 0
    end
    return proxy
end

function BridgeBath.sinkFor(worldobjects)
    local iso = tabas()
    if iso == nil then return nil end

    local obj, btype = nil, nil
    pcall(function() obj, btype = iso.getBathingObjectFromWorldObjects(worldobjects) end)
    if obj == nil then return nil end

    local sourceObj = nil
    if btype == "Bathtub" then
        pcall(function() sourceObj = iso.getFullyBathObject(obj) end)
    elseif btype == "Shower" then
        sourceObj = obj
    end
    if sourceObj == nil then return nil end

    return BridgeBath.sinkProxy(sourceObj), sourceObj, btype
end


function BridgeBath.spawnBathWater(faucetObj, facing)
    BridgeBath.removeBathWater()
    local iso = tabas()
    if iso == nil or faucetObj == nil then return end
    local dir = tostring(facing or "S")
    local faucetSprite = nil
    local tubSprite = nil
    pcall(function() faucetSprite = iso.getSpritesTable("BathWater", "sprite" .. dir, "faucet", "full") end)
    pcall(function() tubSprite = iso.getSpritesTable("BathWater", "sprite" .. dir, "tub", "full") end)
    if faucetSprite == nil then return end
    local baseSq = nil
    pcall(function() baseSq = faucetObj:getSquare() end)
    if baseSq == nil then return end
    local linkedSq = nil
    pcall(function() local linkedObj, sq = iso.getGridExtensionBath(faucetObj); linkedSq = sq end)
    local objs = {}
    local function add(sq, sprite)
        if sq == nil or sprite == nil then return end
        local obj = nil
        pcall(function() obj = IsoObject.new(sq, sprite, "BathWaterVisual") end)
        if obj == nil then return end
        pcall(function() obj:setName("BathWaterVisual") end)
        pcall(function() sq:AddSpecialObject(obj) end)
        pcall(function() obj:transmitModData() end)
        objs[#objs + 1] = obj
    end
    add(baseSq, faucetSprite)
    add(linkedSq, tubSprite)
    BridgeBath.waterObjs = objs
    log("bath water visual on")
end


function BridgeBath.removeBathWater()
    local objs = BridgeBath.waterObjs
    BridgeBath.waterObjs = nil
    if objs == nil then return end
    for i = 1, #objs do
        local obj = objs[i]
        pcall(function()
            local sq = obj:getSquare()
            if sq == nil then return end
            if isClient() then pcall(function() sq:transmitRemoveItemFromSquareOnClients(obj) end) end
            sq:RemoveTileObject(obj)
        end)
    end
    log("bath water visual off")
end

function BridgeBath.showerUsable(obj)
    local iso = tabas()
    if iso == nil or iso.isBathObject == nil or iso.isBathWithShower == nil then return true end
    local usable = true
    pcall(function()
        if iso.isBathObject(obj) == true and iso.isBathWithShower(obj) ~= true then
            usable = false
        end
    end)
    return usable
end


function BridgeBath.bathUsable(faucetObj)
    if faucetObj == nil then return false end
    local sink = nil
    pcall(function() sink = BridgeBath.sinkProxy(faucetObj) end)
    if sink == nil then return false end
    local units = 0
    pcall(function() units = BridgeWash.waterUnits(sink) end)
    if type(units) ~= "number" then units = 0 end
    return units >= 1
end


function BridgeBath.tubOf(faucetObj)
    local iso = tabas()
    if iso == nil or faucetObj == nil then return nil end
    local source, tub = nil, nil
    pcall(function() source, tub = iso.getFullyBathObject(faucetObj) end)
    return tub or source
end


function BridgeBath.findNearest(centre, radius, rect)
    local red = BridgeData ~= nil and BridgeData.owner ~= nil and BridgeData.owner() or nil
    if red == nil and centre == nil and rect == nil then return nil end
    local iso = tabas()
    if iso == nil or type(iso.getBathObjectOnSquare) ~= "function" then return nil end
    local best, bestD, bestSq, bestTub, bestFacing = nil, nil, nil, nil, nil
    pcall(function()
        local cell = getCell()
        local r = radius or 12
        local cz = nil
        if rect ~= nil and rect.z ~= nil then
            cz = math.floor(rect.z)
        elseif centre ~= nil and centre.z ~= nil then
            cz = math.floor(centre.z)
        elseif red ~= nil then
            cz = math.floor(red:getZ())
        end
        if cz == nil then return end
        local cx, cy = nil, nil
        if centre ~= nil then
            cx, cy = math.floor(centre.x or 0), math.floor(centre.y or 0)
        elseif red ~= nil then
            cx, cy = math.floor(red:getX()), math.floor(red:getY())
        end
        local function check(x, y)
            local sq = cell:getGridSquare(x, y, cz)
            if sq == nil then return end
            local obj = iso.getBathObjectOnSquare(sq)
            if obj == nil then return end
            local source, tub = nil, nil
            pcall(function() source, tub = iso.getFullyBathObject(obj) end)
            if source == nil then return end
            if not BridgeBath.bathUsable(source) then return end
            local baseSq = nil
            pcall(function() baseSq = source:getSquare() end)
            if baseSq == nil then return end
            local facing = nil
            pcall(function() facing = iso.getObjectFacing(source) end)
            local d = 0
            if cx ~= nil and cy ~= nil then d = (baseSq:getX() - cx) ^ 2 + (baseSq:getY() - cy) ^ 2 end
            if bestD == nil or d < bestD then
                best, bestD, bestSq = source, d, baseSq
                bestTub, bestFacing = tub, facing
                log(string.format("bath candidate obj=%s,%s source=%s,%s facing=%s",
                    tostring(sq:getX()), tostring(sq:getY()),
                    tostring(baseSq:getX()), tostring(baseSq:getY()), tostring(facing)))
            end
        end
        if rect ~= nil then
            for x = rect.x1, rect.x2 do
                for y = rect.y1, rect.y2 do check(x, y) end
            end
        elseif cx ~= nil and cy ~= nil then
            for dx = -r, r do
                for dy = -r, r do check(cx + dx, cy + dy) end
            end
        end
    end)
    return best, bestTub, bestSq, bestFacing
end


function BridgeBath.startBath(faucetObj, tubObj, sink, sq, facing)
    if BridgeTask == nil or BridgeTask.start == nil then return "no task" end
    if BridgeTask.active then
        if BridgeTask.kind == "bath" then return "already" end
        return "busy"
    end
    if Bridge == nil or not Bridge.alive() or Bridge.kind ~= "zombie" then return "no body" end
    if Bridge.drivable ~= nil and not Bridge.drivable() then return "not drivable" end
    if not BridgeBath.active() then return "no tabas" end
    if not BridgeBath.bathUsable(faucetObj) then return "nowater" end
    if sink == nil then pcall(function() sink = BridgeBath.sinkProxy(faucetObj) end) end
    if facing == nil then
        local iso = tabas()
        if iso ~= nil then pcall(function() facing = iso.getObjectFacing(faucetObj) end) end
    end
    if BridgeExercise ~= nil and BridgeExercise.hardBusy ~= nil then
        local busy = false
        pcall(function() busy = BridgeExercise.hardBusy() == true end)
        if busy then return "busy" end
    end
    if BridgeTask.dangerNear ~= nil then
        local danger = false
        pcall(function() danger = BridgeTask.dangerNear(Bridge.body) == true end)
        if danger then return "danger" end
    end
    if BridgeShower ~= nil and BridgeShower.occupied ~= nil and BridgeShower.occupied(tubObj or faucetObj) then
        return "occupied"
    end
    local ok, why = BridgeShower.bathReady(Bridge.store)
    if not ok then return why end
    local target = sq
    if target ~= nil and (type(target) ~= "table" or tonumber(target.x) == nil) then
        local sx, sy, sz = nil, nil, nil
        pcall(function() sx, sy, sz = target:getX(), target:getY(), target:getZ() end)
        if sx ~= nil then target = { x = sx, y = sy, z = sz } end
    end
    if target == nil then
        pcall(function()
            local s = faucetObj:getSquare()
            if s ~= nil then target = { x = s:getX(), y = s:getY(), z = s:getZ() } end
        end)
    end
    if target == nil then return "no tub" end
    local faucetSq = nil
    pcall(function() faucetSq = faucetObj:getSquare() end)
    local tubSq = nil
    pcall(function() if tubObj ~= nil then tubSq = tubObj:getSquare() end end)
    log(string.format("start faucet=%s,%s tub=%s,%s target=%s,%s facing=%s",
        faucetSq and faucetSq:getX() or "?", faucetSq and faucetSq:getY() or "?",
        tubSq and tubSq:getX() or "?", tubSq and tubSq:getY() or "?",
        tostring(target.x), tostring(target.y), tostring(facing)))
    local res = BridgeTask.start("bath", { target }, nil, {
        faucet = faucetObj,
        tub = tubObj,
        sq = { x = target.x, y = target.y, z = target.z },
        sink = sink,
        facing = facing,
    })
    log("start " .. tostring(res))
    return res
end

function BridgeBath.onWashSinkMenu(playerNum, context, worldobjects, test)
    if test then return end
    if not BridgeBath.active() then return end
    if Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 then return end
    if BridgeMenu == nil or BridgeMenu.isPresent == nil or not BridgeMenu.isPresent() then return end
    if not BridgeMenu.inTalkRange() then return end
    if BridgeMenu.addRinActions == nil then return end

    local sink, faucetObj, btype = BridgeBath.sinkFor(worldobjects)
    if sink == nil or faucetObj == nil then return end

    local rootName = displayName(faucetObj)
    if rootName == nil then return end

    local parentOpt = nil
    pcall(function() parentOpt = context:getOptionFromName(rootName) end)
    if parentOpt == nil or parentOpt.subOption == nil then return end

    local sub = nil
    pcall(function() sub = context:getSubMenu(parentOpt.subOption) end)
    if sub == nil then return end

    local who = Bridge.companionName()
    local rinMenu = nil
    local rinOpt = nil
    pcall(function() rinOpt = sub:getOptionFromName(who) end)
    if rinOpt == nil then
        rinOpt = sub:addOption(who)
        rinMenu = ISContextMenu:getNew(sub)
        sub:addSubMenu(rinOpt, rinMenu)
    else
        pcall(function() rinMenu = sub:getSubMenu(rinOpt.subOption) end)
    end
    if rinMenu == nil then return end

    local label = nil
    pcall(function()
        if BridgeData ~= nil and type(BridgeData.text) == "function" then label = BridgeData.text("WashSelf") end
    end)
    local dupe = nil
    if label ~= nil then pcall(function() dupe = rinMenu:getOptionFromName(label) end) end
    if dupe ~= nil then return end

    BridgeMenu.addRinActions(rinMenu, sink)
    if BridgeBath.showerUsable(faucetObj) and BridgeMenu.addShowerAction ~= nil then
        BridgeMenu.addShowerAction(rinMenu, faucetObj)
    end
    if btype == "Bathtub" and BridgeMenu.addBathAction ~= nil then
        BridgeMenu.addBathAction(rinMenu, faucetObj, sink)
    end
    log("tabas bath sink menu obj=" .. tostring(rootName) .. " type=" .. tostring(btype))
end

function BridgeBath.selftest()
    local savedIso, savedWater = BridgeBath._iso, BridgeBath._water
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end
    local function fakeIso(isBath, hasShower)
        return {
            isBathObject = function() return isBath end,
            isBathWithShower = function() return hasShower end,
        }
    end

    BridgeBath._water = false
    BridgeBath._iso = fakeIso(false, false)
    check("plain shower allowed", BridgeBath.showerUsable({}) == true)

    BridgeBath._iso = fakeIso(true, true)
    check("tub with shower allowed", BridgeBath.showerUsable({}) == true)

    BridgeBath._iso = fakeIso(true, false)
    check("showerless tub blocked", BridgeBath.showerUsable({}) == false)

    BridgeBath._iso = { isBathObject = function() error("x") end,
                        isBathWithShower = function() return false end }
    check("lookup failure keeps old behavior", BridgeBath.showerUsable({}) == true)

    BridgeBath._iso = false
    check("no tabas keeps old behavior", BridgeBath.showerUsable({}) == true)

    local savedProxy = BridgeBath.sinkProxy
    BridgeBath.sinkProxy = function() return { getFluidAmount = function() return 10 end } end
    check("bath usable with water", BridgeBath.bathUsable({}) == true)
    BridgeBath.sinkProxy = function() return { getFluidAmount = function() return 0 end } end
    check("bath unusable without water", BridgeBath.bathUsable({}) == false)
    BridgeBath.sinkProxy = function() return nil end
    check("bath unusable without proxy", BridgeBath.bathUsable({}) == false)
    BridgeBath.sinkProxy = savedProxy

    BridgeBath._iso, BridgeBath._water = savedIso, savedWater
    if #fails == 0 then return string.format("bathselftest PASS (%d checks)", checks) end
    return string.format("bathselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end

Events.OnGameStart.Add(function()
    if not BridgeBath.active() then return end
    if BridgeBath.registered then return end
    BridgeBath.registered = true
    Events.OnFillWorldObjectContextMenu.Add(BridgeBath.onWashSinkMenu)
    log("tabas compat on")
end)
