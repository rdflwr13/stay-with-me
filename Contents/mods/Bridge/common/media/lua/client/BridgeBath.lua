
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
