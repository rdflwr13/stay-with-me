BridgeHug = BridgeHug or {}

BridgeHug.PG_ID = "PlayerGreetings"
BridgeHug.BUMP = "NAPghugHigh2"
BridgeHug.MS = 3700
BridgeHug.TICKS_PER_SEC = 60

function BridgeHug.enabled()
    local mods = getActivatedMods()
    return mods ~= nil and mods:contains(BridgeHug.PG_ID) == true
end

function BridgeHug.tip(option, text)
    pcall(function()
        local t = ISInventoryPaneContextMenu.addToolTip()
        t.description = text
        option.toolTip = t
    end)
end

function BridgeHug.reason()
    if not BridgeHug.enabled() then return "Requires PZ Relationship (PlayerGreetings)" end
    if Bridge == nil or not Bridge.alive() or Bridge.body == nil then return "Companion not present" end
    if Bridge.kind ~= "zombie" then return "Unsupported companion body" end
    if BridgeTask == nil or BridgeTask.kinds == nil or BridgeTask.kinds.hug == nil then return "Hug task not loaded" end
    if BridgeTask.ENABLED ~= 1 then return "Companion tasks are disabled" end
    if Bridge.drivable ~= nil and not Bridge.drivable() then return "Companion not drivable" end
    if BridgeTask.active then return "Companion is busy" end
    local body = Bridge.body
    local seated, lying = false, false
    pcall(function() seated = BridgeTask.isSitting(body) == true end)
    pcall(function() lying = BridgeTask.isLying(body) == true end)
    if seated or lying then return "Companion is seated or lying down" end
    local inCar = false
    pcall(function() inCar = BridgeCar ~= nil and BridgeCar.holdsBody() == true end)
    pcall(function() inCar = inCar or body:getVehicle() ~= nil end)
    if inCar then return "Companion is in a vehicle" end
    local busy = false
    pcall(function() busy = BridgeHeal ~= nil and BridgeHeal.active == true end)
    pcall(function() busy = busy or (BridgeWash ~= nil and BridgeWash.state ~= "idle") end)
    pcall(function() busy = busy or (BridgeFight ~= nil and (BridgeFight.target ~= nil or BridgeFight.state ~= "idle")) end)
    if busy then return "Companion is busy" end
    return nil
end

function BridgeHug.test()
    local why = BridgeHug.reason()
    if why ~= nil then
        print("[BridgeHug] cannot test: " .. tostring(why))
        return
    end
    local res = BridgeTask.start("hug", {})
    print("[BridgeHug] hug test result: " .. tostring(res))
end

local function registerHugTask()
    if BridgeTask == nil or BridgeTask.kinds == nil then return end

    BridgeTask.kinds.hug = {
        noTargets = true,
        restoreMode = true,
        dangerRadius = 3.0,
    }

    function BridgeTask.kinds.hug.available(body)
        return BridgeHug.reason() == nil
    end

    function BridgeTask.kinds.hug.missing(body)
        return nil
    end

    function BridgeTask.kinds.hug.update(body)
        if BridgeTask.hugAt == nil then
            local owner = BridgeData.owner()
            if owner == nil or body == nil then return BridgeTask.cancel("hug target") end

            BridgeTask.hugAt = Bridge.time
            BridgeTask.hugEndAt = Bridge.time + math.floor((BridgeHug.MS / 1000) * BridgeHug.TICKS_PER_SEC) + 18
            BridgeTask.hugStowed = false
            BridgeTask.hugHandMain = nil
            BridgeTask.hugHandSec = nil

            pcall(function() body:faceLocationF(owner:getX(), owner:getY()) end)

            if BridgeWeapon ~= nil and BridgeWeapon.isOut(body) then
                BridgeTask.hugHandMain = body:getPrimaryHandItem()
                BridgeTask.hugHandSec = body:getSecondaryHandItem()
                pcall(function() BridgeWeapon.putAway(body) end)
                BridgeTask.hugStowed = true
            end

            pcall(function() body:setVariable("BumpAnimFinished", false) end)
            pcall(function() body:setBumpType(BridgeHug.BUMP) end)
            pcall(function() if Bridge.lookShare ~= nil then Bridge.lookShare(body) end end)

            BridgeTask.info = "hug: playing " .. BridgeHug.BUMP
            print("[BridgeHug] playing " .. BridgeHug.BUMP)
            return true
        end

        if Bridge.time >= (BridgeTask.hugEndAt or 0) then
            return BridgeTask.finish()
        end
        return true
    end

    function BridgeTask.kinds.hug.leave(body)
        if body ~= nil then
            pcall(function() BridgeMove.releaseBump(body) end)
            if BridgeTask.hugStowed then
                local main, sec = BridgeTask.hugHandMain, BridgeTask.hugHandSec
                if main ~= nil then pcall(function() body:setPrimaryHandItem(main) end) end
                if sec ~= nil then pcall(function() body:setSecondaryHandItem(sec) end) end
                pcall(function() body:resetModelNextFrame() end)
            end
        end
        BridgeTask.hugAt = nil
        BridgeTask.hugEndAt = nil
        BridgeTask.hugStowed = nil
        BridgeTask.hugHandMain = nil
        BridgeTask.hugHandSec = nil
    end
end

local function install()
    if BridgeMenu == nil or BridgeMenu.fill == nil or BridgeTask == nil then return end
    if BridgeMenu.hugTestWrapped then return end
    BridgeMenu.hugTestWrapped = true
    registerHugTask()

    local originalFill = BridgeMenu.fill
    function BridgeMenu.fill(context, playerNum, fromIcon)
        originalFill(context, playerNum, fromIcon)
        if fromIcon then return end
        if BridgeCar ~= nil and BridgeCar.inCarForMenu() then return end
        if not BridgeMenu.isPresent() then return end
        if not BridgeMenu.inTalkRange() then return end

        local option = context:addOption("Hug (test)", nil, BridgeHug.test)
        local why = BridgeHug.reason()
        if why ~= nil then
            option.notAvailable = true
            BridgeHug.tip(option, why)
        end
    end
end

Events.OnGameStart.Add(install)
