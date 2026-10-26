BridgeGunfight = BridgeGunfight or {}

BridgeGunfight.assignedId = nil
BridgeGunfight.gunItem = nil
BridgeGunfight.gun = nil
BridgeGunfight.body = nil
BridgeGunfight.target = nil
BridgeGunfight.state = "idle"
BridgeGunfight.info = "none"
BridgeGunfight.drawn = false
BridgeGunfight.attached = nil
BridgeGunfight.aimUntil = nil
BridgeGunfight.nextShotAt = nil
BridgeGunfight.stowAt = nil
BridgeGunfight.lastTargetAt = nil
BridgeGunfight.lastShotAt = nil
BridgeGunfight.lastPick = 0
BridgeGunfight.fireUntil = nil
BridgeGunfight.lastBump = nil
BridgeGunfight.pendingShot = nil
BridgeGunfight.shots = 0
BridgeGunfight.hits = 0
BridgeGunfight.blockAt = nil
BridgeGunfight.moving = false
BridgeGunfight.missingSince = nil
BridgeGunfight.friendlies = nil
BridgeGunfight.friendliesAt = nil
BridgeGunfight.flashes = {}
BridgeGunfight.bumps = {}
BridgeGunfight.handSyncAt = nil
    BridgeGunfight.rounds = keepRounds
    BridgeGunfight.maxAmmo = 0
BridgeGunfight.reloadStage = nil
BridgeGunfight.reloadUntil = nil
BridgeGunfight.reloadFamily = nil
BridgeGunfight.reloadRoundsLeft = 0
BridgeGunfight.reloadNeed = 0
BridgeGunfight.reloadSavedRounds = 0
BridgeGunfight.reloadBaseRounds = 0
BridgeGunfight.reloadVirtual = false
    BridgeGunfight.reloadMagId = nil
    BridgeGunfight.reloadCancel = false
    BridgeGunfight.magCareStage = nil
    BridgeGunfight.magCareUntil = nil
    BridgeGunfight.magCareStageAt = nil
    BridgeGunfight.magCareStageTicks = 0
    BridgeGunfight.magCareMagId = nil
    BridgeGunfight.magCareMag = nil
    BridgeGunfight.magCareAt = nil
BridgeGunfight.reloadTotal = 0
BridgeGunfight.reloadStartedAt = nil
BridgeGunfight.reloadDoneAt = nil
BridgeGunfight.suspended = false
BridgeGunfight.recheckAt = nil
BridgeGunfight.lowSaid = false
BridgeGunfight.modeRange = 0
BridgeGunfight.canMelee = false
BridgeGunfight.meleeFallback = false
BridgeGunfight.stance = nil
BridgeGunfight.lastGunAt = nil
BridgeGunfight.meleeClearAt = nil
BridgeGunfight.reloadClientAmmo = false
BridgeGunfight.reloadTaken = 0
BridgeGunfight.noAmmoUntil = nil
BridgeGunfight.reloadMissingCount = 0
BridgeGunfight.reserveAt = nil
BridgeGunfight.reserveN = 0
BridgeGunfight.ammoItem = nil
BridgeGunfight.ammoOut = nil
BridgeGunfight.ammoAmount = 0
BridgeGunfight.ammoUntil = nil
BridgeGunfight.ammoCooldown = nil
BridgeGunfight.peek = nil
BridgeGunfight.peekCooldown = nil
BridgeGunfight.homeAmmoAt = nil
BridgeGunfight.ammoBorrow = nil
BridgeGunfight.reloadStageAt = nil
BridgeGunfight.reloadStageTicks = 0
BridgeGunfight.magCareStageAt = nil
BridgeGunfight.magCareStageTicks = 0
BridgeGunfight.ammoStageAt = nil
BridgeGunfight.ammoStageTicks = 0

local STOW_TICKS = 180
local RECHECK = 12
local MELEE_TO_GUN = 90
local GUN_TO_MELEE = 30
local MELEE_RELEASE_RANGE = 3.5
local MELEE_RELEASE_HOLD = 60
local FIRE_TICKS = 24
local PENDING_TICKS = 180
local FRIENDLY_TTL = 30
local FIRE_VAR = "BumpAnimFinished"
local RELOAD_VAR = "ReloadSpeed"
local OOA_RECHECK = 60
local RELOAD_UNLOAD_HANDGUN = 36
local RELOAD_UNLOAD_RIFLE = 45
local RELOAD_LOAD_HANDGUN = 66
local RELOAD_LOAD_RIFLE = 81
local RELOAD_RACK_HANDGUN = 21
local RELOAD_RACK_RIFLE = 30
local RELOAD_ROUND_SHOTGUN = 50
local RELOAD_ROUND_REVOLVER = 57
local RELOAD_ROUND_RIFLE = 35
local RELOAD_ROUND_MAGAZINE = 30
local stopReposition
local clearBump
local stageTicks
local bumpName
local playGunSound
local reloadFactor
local tellLoadOne

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGunfight] " .. tostring(text)) end end
local function warn(text) print("[BridgeGunfight] " .. tostring(text)) end
local function vlog(text) if Bridge ~= nil and Bridge.verbose then log(text) end end

local function speedMult()
    if Bridge ~= nil and Bridge.mp then return 1 end
    local m = 1
    pcall(function() m = getGameTime():getTrueMultiplier() end)
    if type(m) ~= "number" or m ~= m or m < 1 then m = 1 end
    if m > 10 then m = 10 end
    return m
end

local function actionElapsed(startAt, ticks)
    if startAt == nil then return false end
    return ((Bridge.time or 0) - startAt) * speedMult() >= (tonumber(ticks) or 0)
end

local function showGunBar(value)
    if value == nil or BridgeProgress == nil or BridgeProgress.show == nil then return end
    pcall(function() BridgeProgress.show(value, true) end)
end

local function stageFraction(startAt, ticks)
    local f = 0
    local t = tonumber(ticks) or 0
    if t > 0 and startAt ~= nil then
        f = ((Bridge.time or 0) - startAt) * speedMult() / t
        if f < 0 then f = 0 elseif f > 1 then f = 1 end
    end
    return f
end

local function magCareProgress()
    if BridgeGunfight.magCareStage == nil then return nil end
    local cap = 0
    local mag = BridgeGunfight.magCareMag
    if mag ~= nil then pcall(function() cap = math.floor(tonumber(mag:getMaxAmmo()) or 0) end) end
    if cap <= 0 and BridgeGunfight.gun ~= nil then cap = tonumber(BridgeGunfight.gun.maxAmmo) or 0 end
    if cap <= 0 then return nil end
    local f = stageFraction(BridgeGunfight.magCareStageAt, BridgeGunfight.magCareStageTicks)
    local rounds = tonumber(BridgeGunfight.magCareRounds) or 0
    local v = (rounds + f) / cap
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return v
end

local function dist(a, b)
    local dx, dy = a:getX() - b:getX(), a:getY() - b:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi)
    if type(v) ~= "number" or v ~= v then v = lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end


local function marked(item)
    local yes = false
    pcall(function()
        yes = item ~= nil and item:hasModData() == true and item:getModData()[BridgeGunRules.MARK] == true
    end)
    return yes
end

local function setMark(item, on)
    pcall(function()
        if item == nil or item:hasModData() ~= true then return end
        local md = item:getModData()
        if on then md[BridgeGunRules.MARK] = true else md[BridgeGunRules.MARK] = nil end
    end)
end

local function inInventory(body, item)
    local ok = false
    pcall(function()
        if body == nil or item == nil then return end
        local inv = body:getInventory()
        local c = item:getContainer()
        ok = c == inv or (c ~= nil and c:getOutermostContainer() == inv)
    end)
    return ok
end


local function ensureInMain(body, item)
    if body == nil or item == nil then return false end
    local inv = nil
    local container = nil
    pcall(function()
        inv = body:getInventory()
        container = item:getContainer()
    end)
    if inv == nil then return false end
    if container == inv then return true end
    if container == nil then return true end
    local moved = false
    pcall(function()
        container:Remove(item)
        local added = inv:AddItem(item)
        if added ~= nil then
            moved = true
        else
            container:AddItem(item)
        end
    end)
    return moved
end


local function setFields(item)
    BridgeGunfight.gunItem = item
    BridgeGunfight.assignedId = item:getID()
    BridgeGunfight.gun = BridgeGunRules.describe(item)
    BridgeGunfight.maxAmmo = tonumber(BridgeGunfight.gun.maxAmmo) or 0
    BridgeGunfight.rounds = BridgeGunRules.roundsOf(item)
    BridgeGunfight.reloadFamily = BridgeGunfight.gun.reloadFamily
    BridgeGunfight.suspended = false
    BridgeGunfight.meleeFallback = false
    BridgeGunfight.lowSaid = false
    BridgeGunfight.reloadMissingCount = 0
BridgeGunfight.reserveAt = nil
BridgeGunfight.reserveN = 0
end

local function clearFields()
    BridgeGunfight.assignedId = nil
    BridgeGunfight.gunItem = nil
    BridgeGunfight.gun = nil
    BridgeGunfight.target = nil
    BridgeGunfight.state = "idle"
    BridgeGunfight.drawn = false
    BridgeGunfight.attached = nil
    BridgeGunfight.aimUntil = nil
    BridgeGunfight.nextShotAt = nil
    BridgeGunfight.stowAt = nil
    BridgeGunfight.lastTargetAt = nil
    BridgeGunfight.lastShotAt = nil
    BridgeGunfight.lastPick = 0
    BridgeGunfight.fireUntil = nil
    BridgeGunfight.lastBump = nil
    BridgeGunfight.pendingShot = nil
    BridgeGunfight.moving = false
    BridgeGunfight.missingSince = nil
    BridgeGunfight.rounds = 0
    BridgeGunfight.maxAmmo = 0
    BridgeGunfight.reloadStage = nil
    BridgeGunfight.reloadUntil = nil
    BridgeGunfight.reloadStageAt = nil
    BridgeGunfight.reloadStageTicks = 0
    BridgeGunfight.reloadFamily = nil
    BridgeGunfight.reloadRoundsLeft = 0
    BridgeGunfight.reloadNeed = 0
    BridgeGunfight.reloadVirtual = false
    BridgeGunfight.reloadSavedRounds = 0
    BridgeGunfight.reloadBaseRounds = 0
    BridgeGunfight.reloadMagId = nil
    BridgeGunfight.reloadCancel = false
    BridgeGunfight.reloadTotal = 0
    BridgeGunfight.reloadStartedAt = nil
    BridgeGunfight.reloadDoneAt = nil
    BridgeGunfight.suspended = false
    BridgeGunfight.recheckAt = nil
    BridgeGunfight.lowSaid = false
    BridgeGunfight.modeRange = 0
    BridgeGunfight.canMelee = false
    BridgeGunfight.meleeFallback = false
    BridgeGunfight.stance = nil
    BridgeGunfight.lastGunAt = nil
    BridgeGunfight.meleeClearAt = nil
    BridgeGunfight.reloadClientAmmo = false
    BridgeGunfight.reloadTaken = 0
    BridgeGunfight.noAmmoUntil = nil
    BridgeGunfight.reloadMissingCount = 0
BridgeGunfight.reserveAt = nil
BridgeGunfight.reserveN = 0
    BridgeGunfight.ammoItem = nil
    BridgeGunfight.ammoOut = nil
    BridgeGunfight.ammoAmount = 0
    BridgeGunfight.ammoUntil = nil
    BridgeGunfight.ammoStageAt = nil
    BridgeGunfight.ammoStageTicks = 0
    BridgeGunfight.ammoCooldown = nil
    BridgeGunfight.peek = nil
    BridgeGunfight.peekCooldown = nil
    BridgeGunfight.homeAmmoAt = nil
    BridgeGunfight.ammoBorrow = nil
end


function BridgeGunfight.isAssigned(body)
    if BridgeGunfight.assignedId ~= nil then return true end
    if body == nil or Bridge.store == nil or BridgeGunfight.recovering == true then return false end
    if Bridge.store.gunType == nil and Bridge.store.gunId == nil then return false end
    local now = Bridge.time or 0
    if BridgeGunfight.recoverAt ~= nil and now < BridgeGunfight.recoverAt then return false end
    BridgeGunfight.recovering = true
    pcall(function() BridgeGunfight.recover(body) end)
    BridgeGunfight.recovering = false
    BridgeGunfight.recoverAt = now + 600
    return BridgeGunfight.assignedId ~= nil
end

function BridgeGunfight.hasGun()
    return BridgeGunfight.assignedId ~= nil and BridgeGunfight.suspended ~= true
        and BridgeGunfight.meleeFallback ~= true
end

function BridgeGunfight.hasAmmo(body)
    body = body or BridgeGunfight.body
    local gun = BridgeGunfight.gun
    if body == nil or gun == nil then return false end
    if BridgeGunRules.hasReloadSource(body, gun) then return true end
    return false
end

function BridgeGunfight.readyAmmo(body)
    return (BridgeGunfight.rounds or 0) > 0 or BridgeGunfight.hasAmmo(body)
end

function BridgeGunfight.isGunItem(item)
    return BridgeGunRules.isGun(item)
end


function BridgeGunfight.ownsHand(body)
    local item = BridgeGunfight.gunItem
    if item == nil or body == nil then return false end
    local ok = false
    pcall(function()
        ok = body:getPrimaryHandItem() == item or body:getSecondaryHandItem() == item
    end)
    return ok
end


function BridgeGunfight.assignedItem(body)
    local id = BridgeGunfight.assignedId
    if id == nil then return nil end
    local fullType = BridgeGunfight.gun and BridgeGunfight.gun.fullType or nil
    local item = BridgeGunRules.findGunItem(body, id, fullType)
    if item == nil then return nil end
    BridgeGunfight.gunItem = item
    if BridgeGunfight.gun == nil then BridgeGunfight.gun = BridgeGunRules.describe(item) end
    return item
end


local function tellServer(gunType, gunId, gunRounds)
    if Bridge == nil or not Bridge.mp then return end
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "state",
            { gunType = gunType or "", gunId = gunId, gunRounds = tonumber(gunRounds) or 0 })
    end)
end


local function findFlagged(body)
    local found = nil
    if body == nil then return nil end
    pcall(function()
        local inv = body:getInventory()
        local items = inv:getAllEvalRecurse(function(it)
            return marked(it) and BridgeGunRules.valid(it)
        end)
        if items ~= nil and items:size() > 0 then found = items:get(0) end
        if found == nil then
            local hand = body:getPrimaryHandItem()
            if marked(hand) and BridgeGunRules.valid(hand) then found = hand end
        end
        if found == nil then
            local secondary = body:getSecondaryHandItem()
            if marked(secondary) and BridgeGunRules.valid(secondary) then found = secondary end
        end
    end)
    return found
end


local function logGunState(tag, body)
    local item = BridgeGunfight.gunItem
    local gun = BridgeGunfight.gun
    if item == nil or gun == nil then return end
    local contains, rounds, clipType = false, 0, nil
    pcall(function() contains = item:isContainsClip() == true end)
    pcall(function() rounds = tonumber(item:getCurrentAmmoCount()) or 0 end)
    pcall(function()
        local part = item:getWeaponPart("Clip")
        if part ~= nil then clipType = part:getFullType() end
    end)
    local total, loaded = BridgeGunRules.magazineCount(body, gun)
    log(string.format("%s: containsClip=%s clipPart=%s magType=%s maxAmmo=%s rounds=%s spareMags=%d loadedMags=%d",
        tostring(tag), tostring(contains), tostring(clipType or "-"), tostring(gun.magazineType or "-"),
        tostring(gun.maxAmmo), tostring(rounds), total, loaded))
    local list = gun.magazineTypes
    if type(list) == "table" and #list > 0 then
        local shown = {}
        for i = 1, math.min(#list, 24) do
            local t = list[i]
            local cap = 0
            pcall(function()
                local it = instanceItem(t)
                if it ~= nil then cap = math.floor(tonumber(it:getMaxAmmo()) or 0) end
            end)
            shown[#shown + 1] = cap > 0 and string.format("%s(%d)", tostring(t), cap) or tostring(t)
        end
        local suffix = #list > 24 and string.format(" (+%d more)", #list - 24) or ""
        log(string.format("%s: accepts %d magazine types: %s%s",
            tostring(tag), #list, table.concat(shown, ", "), suffix))
    end
    if BridgeLog ~= nil and BridgeLog.on() then
        local accept = BridgeGunRules.ammoAccept(gun)
        local function join(t)
            if type(t) ~= "table" or #t == 0 then return "-" end
            local shown = {}
            for i = 1, math.min(#t, 12) do shown[#shown + 1] = tostring(t[i]) end
            local suffix = #t > 12 and string.format(" (+%d more)", #t - 12) or ""
            return table.concat(shown, ", ") .. suffix
        end
        log(string.format("%s: accepts loose rounds: %s", tostring(tag), join(accept.rounds)))
        log(string.format("%s: accepts ammo boxes: %s", tostring(tag), join(accept.boxes)))
        log(string.format("%s: accepts cartons: %s", tostring(tag), join(accept.cartons)))
    end
end


function BridgeGunfight.recover(body)
    BridgeGunfight.reset()
    BridgeGunfight.body = body
    if body == nil then return nil end
    local found = findFlagged(body)
    if found == nil and Bridge.store ~= nil and Bridge.store.gunId ~= nil then
        pcall(function() found = BridgeGunRules.findItemById(body, Bridge.store.gunId) end)
        if found ~= nil and not BridgeGunRules.valid(found) then found = nil end
    end
    if found == nil and Bridge.store ~= nil and type(Bridge.store.gunType) == "string" then
        local wanted = Bridge.store.gunType
        pcall(function()
            local items = body:getInventory():getAllEvalRecurse(function(it)
                return BridgeGunRules.isGun(it) and it:getFullType() == wanted and BridgeGunRules.valid(it)
            end)
            if items ~= nil and items:size() > 0 then found = items:get(0) end
        end)
    end
    if found ~= nil then
        setMark(found, true)
        setFields(found)
        if BridgeGear ~= nil and BridgeGear.isGear(body, found) then
            pcall(function() BridgeGear.release(body, found) end)
            pcall(function() body:resetModelNextFrame() end)
        end
        tellServer(BridgeGunfight.gun.fullType, BridgeGunfight.assignedId, BridgeGunfight.rounds)
        log("recovered primary gun " .. BridgeGunRules.summary(BridgeGunfight.gun))
        logGunState("gun state at recover", body)
        return found
    end
    if Bridge.store ~= nil and (Bridge.store.gunType ~= nil or Bridge.store.gunId ~= nil) then
        log("recover: recorded gun is no longer in her inventory")
    end
    return nil
end


function BridgeGunfight.assign(body, item)
    if not BridgeGunRules.valid(item) then
        log("assign refused: not a usable gun")
        return false
    end
    if body == nil or not inInventory(body, item) then
        log("assign refused: gun is not in her inventory")
        return false
    end
    local desc = BridgeGunRules.describe(item)
    if desc.magazineType == nil and desc.ammoTypeKey == nil then
        log("assign refused: gun has no magazine or ammo type")
        return false
    end
    if BridgeGunfight.assignedId ~= nil and BridgeGunfight.assignedId ~= item:getID() then
        BridgeGunfight.unassign(body, "replaced")
    end
    if not ensureInMain(body, item) then
        log("assign refused: gun could not move to her main inventory")
        return false
    end
    if BridgeGear ~= nil and BridgeGear.isGear(body, item) then
        pcall(function() BridgeGear.release(body, item) end)
        pcall(function() body:resetModelNextFrame() end)
    end
    BridgeGunfight.cancelMagCare(body)
    setMark(item, true)
    setFields(item)
    BridgeGunfight.body = body
    BridgeGunfight.target = nil
    BridgeGunfight.state = "idle"
    BridgeGunfight.stowAt = nil
    BridgeGunfight.fireUntil = nil
    BridgeGunfight.reloadStage = nil
    BridgeGunfight.reloadUntil = nil
    BridgeGunfight.reloadStageAt = nil
    BridgeGunfight.reloadStageTicks = 0
    BridgeGunfight.reloadMagId = nil
    BridgeGunfight.peek = nil
    BridgeGunfight.peekCooldown = nil
    BridgeGunfight.magCareLogged = nil
    pcall(function() BridgeWeapon.putAway(body) end)
    tellServer(BridgeGunfight.gun.fullType, BridgeGunfight.assignedId, BridgeGunfight.rounds)
    log("assigned primary gun " .. BridgeGunRules.summary(BridgeGunfight.gun))
    logGunState("gun state at assign", body)
    return true
end


function BridgeGunfight.unassign(body, reason)
    if BridgeGunfight.assignedId == nil then return false end
    local item = BridgeGunfight.gunItem
    if BridgeGunfight.drawn then pcall(function() BridgeGunfight.stow(body) end) end
    setMark(item, false)
    local was = BridgeGunfight.gun and BridgeGunfight.gun.fullType or "?"
    BridgeGunfight.cancelMagCare(body)
    clearFields()
    BridgeGunfight.info = "none"
    BridgeGunfight.body = body
    tellServer("", nil)
    log("unassigned primary gun " .. tostring(was) .. ": " .. tostring(reason or "no reason"))
    return true
end


local function refresh(body)
    pcall(function() body:resetModelNextFrame() end)
    pcall(function() if BridgeInventory ~= nil and BridgeInventory.redress ~= nil then BridgeInventory.redress(body) end end)
end


local function detachGun(body)
    local a = BridgeGunfight.attached
    if a == nil then return false end
    if body ~= nil then
        pcall(function() body:removeAttachedItem(a.item) end)
        pcall(function()
            if a.item.setAttachedToModel ~= nil then a.item:setAttachedToModel(nil) end
            if a.item.setAttachedSlotType ~= nil then a.item:setAttachedSlotType(nil) end
            if a.item.setAttachedSlot ~= nil then a.item:setAttachedSlot(-1) end
        end)
    end
    BridgeGunfight.attached = nil
    return true
end


local function attachGun(body, item)
    local slot, set, defType = nil, nil, nil
    pcall(function() slot, set, defType = BridgeWeapon.slotFor(body, item) end)
    if slot == nil then return false end
    local taken = nil
    pcall(function() taken = body:getAttachedItem(slot) end)
    if taken ~= nil and taken ~= item then return false end
    detachGun(body)
    local ok = pcall(function()
        body:setAttachedItem(slot, item)
        if item.setAttachedToModel ~= nil then item:setAttachedToModel(slot) end
        if defType ~= nil and item.setAttachedSlotType ~= nil then item:setAttachedSlotType(defType) end
    end)
    if not ok then return false end
    BridgeGunfight.attached = { slot = slot, item = item, set = set, defType = defType }
    return true
end


local function hands(body, item, on)
    if body == nil or item == nil then return end
    if Bridge.body ~= nil and body ~= Bridge.body then return end
    pcall(function()
        if on then
            body:setPrimaryHandItem(item)
            if BridgeGunfight.gun ~= nil and BridgeGunfight.gun.twoHanded then body:setSecondaryHandItem(item) end
        else
            if body:getPrimaryHandItem() == item then body:setPrimaryHandItem(nil) end
            if body:getSecondaryHandItem() == item then body:setSecondaryHandItem(nil) end
        end
        body:resetEquippedHandsModels()
    end)
end


function BridgeGunfight.syncHands(body)
    if body == nil or BridgeGunfight.drawn ~= true then return end
    if BridgeGunfight.magCareStage ~= nil then return end
    local item = BridgeGunfight.gunItem
    if item == nil then return end
    pcall(function()
        body:setPrimaryHandItem(item)
        if BridgeGunfight.gun ~= nil and BridgeGunfight.gun.twoHanded then body:setSecondaryHandItem(item) end
        body:resetEquippedHandsModels()
    end)
    BridgeGunfight.handSyncAt = Bridge.time
    BridgeGunfight.meleeFallback = false
end


function BridgeGunfight.draw(body)
    local item = BridgeGunfight.assignedItem(body)
    if item == nil then return false end
    local hand = nil
    pcall(function() hand = body:getPrimaryHandItem() end)
    if hand == item then
        pcall(function() body:resetEquippedHandsModels() end)
        BridgeGunfight.drawn = true
        BridgeGunfight.meleeFallback = false
        BridgeGunfight.stance = "gun"
        return false
    end
    if not ensureInMain(body, item) then
        log("draw refused: gun could not move to her main inventory")
        return false
    end
    if hand ~= nil then
        pcall(function() BridgeWeapon.putAway(body) end)
    end
    detachGun(body)
    pcall(function() if body:isAttachedItem(item) then body:removeAttachedItem(item) end end)
    hands(body, item, true)
    refresh(body)
    BridgeGunfight.handSyncAt = Bridge.time
    BridgeGunfight.drawn = true
    BridgeGunfight.meleeFallback = false
    BridgeGunfight.stance = "gun"
    BridgeGunfight.lastGunAt = Bridge.time
    log("drew " .. tostring(item:getType()))
    return true
end


function BridgeGunfight.stow(body)
    if body == nil or (Bridge.body ~= nil and body ~= Bridge.body) then return false end
    BridgeGunfight.meleeFallback = true
    BridgeGunfight.stance = "melee"
    stopReposition(body)
    BridgeGunfight.peek = nil
    local item = BridgeGunfight.assignedItem(body)
    if item == nil then
        BridgeGunfight.drawn = false
        return false
    end
    BridgeGunfight.drawn = false
    pcall(function()
        body:setPrimaryHandItem(nil)
        body:setSecondaryHandItem(nil)
        body:resetEquippedHandsModels()
    end)
    detachGun(body)
    local attached = attachGun(body, item)
    refresh(body)
    pcall(function() body:resetEquippedHandsModels() end)
    clearBump(body)
    BridgeGunfight.moving = false
    log("stowed " .. tostring(item:getType()) .. (attached and " on her" or " in her bag"))
    return true
end


local function plant(body, name)
    if body == nil or name == nil then return end
    local cur = nil
    pcall(function() cur = tostring(body:getBumpType()) end)
    if cur ~= name then
        pcall(function() body:setBumpType(name) end)
    end
    BridgeGunfight.lastBump = name
end

local MOVEMENT_BUMPS = { FollowWalk = true, FollowRun = true, StartMove = true }

local function plantMaintenance(body, name)
    if body == nil or name == nil then return end
    local cur = nil
    pcall(function() cur = tostring(body:getBumpType()) end)
    if MOVEMENT_BUMPS[cur] then return end
    plant(body, name)
end

clearBump = function(body)
    if body == nil then return end
    local cur = nil
    pcall(function() cur = tostring(body:getBumpType()) end)
    if cur ~= nil and string.sub(cur, 1, 3) == "NA_" then
        pcall(function() body:setBumpType("") end)
    end
    BridgeGunfight.lastBump = nil
end


local function companionBody(z)
    local ok, v = pcall(function() return z:getVariableBoolean("NotAloneBody") end)
    return ok and v == true
end


local function targetOk(z, body, red)
    if z == nil or body == nil or z == body then return false end
    if Bridge.body ~= nil and z == Bridge.body then return false end
    if BridgeKnoxNpc ~= nil and BridgeKnoxNpc.isNpc(z) then
        return BridgeKnoxNpc.allowGunTarget(z, red)
    end
    if companionBody(z) then return false end
    if not BridgeGunRules.foreignGunAllowed(z, BridgeData.foreignPeaceful) then return false end
    if instanceof(z, "IsoAnimal") then
        if BridgeAnimals == nil or BridgeAnimals.wanted ~= true or not BridgeAnimals.hostile(z) then return false end
        local ok, alive = pcall(function() return z:isAlive() and z:getHealth() > 0 end)
        return ok and alive
    end
    local ok, alive = pcall(function() return z:isAlive() and z:getHealth() > 0 and not z:isOnKillDone() end)
    if not ok or not alive then return false end
    if BridgeData.harmless(z) then return false end
    if BridgeFight.ownerRisen(z, red) then return false end
    return true
end


local function validTarget(z, body, red)
    if BridgeGunfight.gun == nil then return false end
    if not targetOk(z, body, red) then return false end
    if math.abs(z:getZ() - body:getZ()) >= 0.8 then return false end
    local range = BridgeGunfight.modeRange or BridgeGunfight.gun.range
    if range <= 0 or dist(body, z) > range + 0.9 then return false end
    local cell = getCell()
    local clear = false
    pcall(function()
        clear = BridgeGunRules.fireLineClear(cell, body:getX(), body:getY(), body:getZ(),
            z:getX(), z:getY(), z:getZ()) == true
    end)
    if not clear then return false end
    if not BridgeGunRules.targetVisible(body, red, z) then return false end
    return true
end


local function pickTarget(body, red)
    local range = BridgeGunfight.modeRange or (BridgeGunfight.gun and BridgeGunfight.gun.range) or 0
    if range <= 0 then return nil end
    local cell = getCell()
    if cell == nil then return nil end
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local range2 = range * range
    local list = nil
    if BridgeZS ~= nil then list = BridgeZS.near(bx, by, range + 0.2) end
    if list == nil then list = cell:getZombieList() end
    local cands = {}
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z ~= nil and math.abs(z:getZ() - bz) < 0.8 then
            local dx, dy = z:getX() - bx, z:getY() - by
            local d2 = dx * dx + dy * dy
            if d2 <= range2 and targetOk(z, body, red) then
                local dSelf = math.sqrt(d2)
                if dSelf <= range then
                    cands[#cands + 1] = { z = z, score = dist(red, z) + dSelf * 0.01 }
                end
            end
        end
    end
    if BridgeAnimals ~= nil and BridgeAnimals.wanted then
        local animals = nil
        pcall(function() animals = cell:getAnimals() end)
        if animals ~= nil then
            for i = 0, animals:size() - 1 do
                local a = animals:get(i)
                if a ~= nil and math.abs(a:getZ() - bz) < 0.8 then
                    local dx, dy = a:getX() - bx, a:getY() - by
                    local d2 = dx * dx + dy * dy
                    if d2 <= range2 and targetOk(a, body, red) then
                        local dSelf = math.sqrt(d2)
                        if dSelf <= range then
                            cands[#cands + 1] = { z = a, score = dist(red, a) + dSelf * 0.01 }
                        end
                    end
                end
            end
        end
    end
    if BridgeKnoxNpc ~= nil and BridgeKnoxNpc.active() then
        pcall(function()
            local npcs = BridgeKnoxNpc.near(bx, by, range, red)
            for i = 1, #npcs do
                local n = npcs[i]
                if math.abs(n:getZ() - bz) < 0.8 and targetOk(n, body, red) then
                    local dS = dist(body, n)
                    if dS <= range then
                        cands[#cands + 1] = { z = n, score = dist(red, n) + dS * 0.01 }
                    end
                end
            end
        end)
    end
    if #cands == 0 then return nil end
    table.sort(cands, function(a, b) return a.score < b.score end)
    for _, c in ipairs(cands) do
        local z = c.z
        local clear = false
        pcall(function()
            clear = BridgeGunRules.fireLineClear(cell, body:getX(), body:getY(), body:getZ(),
                z:getX(), z:getY(), z:getZ()) == true
        end)
        if clear and BridgeGunRules.targetVisible(body, red, z) then return z end
    end
    return nil
end


local PEEK_OFFSET = 1.8
local PEEK_TIMEOUT = 120
local PEEK_RETRY = 180


local function peekTarget(body, red)
    local range = BridgeGunfight.modeRange or (BridgeGunfight.gun and BridgeGunfight.gun.range) or 0
    if range <= 0 then return nil end
    local best, bestD2 = nil, math.huge
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local range2 = range * range
    local min2 = BridgeGunRules.MIN_RANGE * BridgeGunRules.MIN_RANGE
    pcall(function()
        local list = nil
        if BridgeZS ~= nil then list = BridgeZS.near(bx, by, range + 0.2) end
        if list == nil then list = getCell():getZombieList() end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            local nearEnough, d2 = false, nil
            if z ~= nil then
                local zz = z:getZ()
                if math.abs(zz - bz) < 0.8 then
                    local dx, dy = z:getX() - bx, z:getY() - by
                    d2 = dx * dx + dy * dy
                    nearEnough = d2 <= range2
                end
            end
            if nearEnough and d2 > min2 and d2 < bestD2 and targetOk(z, body, red) and math.abs(z:getZ() - body:getZ()) < 0.8 then
                best, bestD2 = z, d2
            end
        end
    end)
    return best
end


local function peekTick(body, red)
    local now = Bridge.time or 0
    local p = BridgeGunfight.peek
    if p ~= nil then
        if now > p.untilT then
            BridgeGunfight.peek = nil
            BridgeGunfight.peekCooldown = now + PEEK_RETRY
            pcall(function() if BridgeMove.onPath() then BridgeMove.stopPath(body) end end)
            BridgeMove.moving = false
            BridgeMove.steering = false
            return false
        end
        local bx, by, bz = body:getX(), body:getY(), body:getZ()
        local dx, dy = p.x - bx, p.y - by
        local len = math.sqrt(dx * dx + dy * dy)
        if len <= 0.3 then
            BridgeGunfight.peek = nil
            BridgeGunfight.peekCooldown = now + PEEK_RETRY
            BridgeMove.moving = false
            BridgeMove.steering = false
            return false
        end
        pcall(function()
            BridgeMove.walkType = "Walk"
            BridgeMove.applyAnimVars(body)
            BridgeMove.steering = true
            BridgeMove.followWs = 1.0
            BridgeMove.followBump(body, "Walk")
            BridgeMove.goToward(body, p.x, p.y, bz)
        end)
        BridgeMove.moving = true
        return true
    end
    if BridgeGunfight.peekCooldown ~= nil and now < BridgeGunfight.peekCooldown then return false end
    local z = peekTarget(body, red)
    if z == nil then
        BridgeGunfight.peekCooldown = now + 30
        return false
    end
    local cell = getCell()
    if cell == nil then return false end
    local lineNow = false
    pcall(function()
        lineNow = BridgeGunRules.fireLineClear(cell, body:getX(), body:getY(), body:getZ(),
            z:getX(), z:getY(), z:getZ()) == true
    end)
    if lineNow then
        BridgeGunfight.peekCooldown = now + 30
        return false
    end
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local dx, dy = z:getX() - bx, z:getY() - by
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.6 then return false end
    local px, py = -dy / len, dx / len
    local range = BridgeGunfight.modeRange or (BridgeGunfight.gun and BridgeGunfight.gun.range) or 0
    for _, side in ipairs({ 1, -1 }) do
        local gx, gy = bx + px * PEEK_OFFSET * side, by + py * PEEK_OFFSET * side
        local okPath, clear = false, false
        pcall(function() okPath = BridgeMove.lineClear(body, gx, gy, bz) == true end)
        if okPath then
            local d = BridgeGunRules.dist2(z:getX(), z:getY(), gx, gy)
            if d <= range then
                pcall(function()
                    clear = BridgeGunRules.fireLineClear(cell, gx, gy, bz, z:getX(), z:getY(), z:getZ()) == true
                end)
            end
        end
        if okPath and clear then
            BridgeGunfight.peek = { x = gx, y = gy, z = bz, untilT = now + PEEK_TIMEOUT }
            pcall(function()
                BridgeMove.walkType = "Walk"
                BridgeMove.applyAnimVars(body)
                BridgeMove.steering = true
                BridgeMove.followWs = 1.0
                BridgeMove.followBump(body, "Walk")
                BridgeMove.goToward(body, gx, gy, bz)
            end)
            BridgeMove.moving = true
            vlog(string.format("peek %s to %.1f,%.1f", side > 0 and "right" or "left", gx, gy))
            return true
        end
    end
    BridgeGunfight.peekCooldown = now + 30
    return false
end


local function friendlies(body)
    if BridgeGunfight.friendlies ~= nil and BridgeGunfight.friendliesAt ~= nil
        and Bridge.time - BridgeGunfight.friendliesAt < FRIENDLY_TTL then
        return BridgeGunfight.friendlies
    end
    local list = {}
    local function add(c)
        if c ~= nil and c ~= body then list[#list + 1] = c end
    end
    add(BridgeData.owner())
    add(Bridge.body)
    pcall(function()
        local zombies = getCell():getZombieList()
        for i = 0, zombies:size() - 1 do
            local z = zombies:get(i)
            if z ~= nil and z ~= body then
                if companionBody(z) then
                    add(z)
                elseif BridgeGunRules.isForeignNpc(z) ~= nil and dist(body, z) <= 20 then
                    add(z)
                end
            end
        end
    end)
    BridgeGunfight.friendlies = list
    BridgeGunfight.friendliesAt = Bridge.time
    return list
end


local function blockedBy(body, t)
    local hit = BridgeGunRules.friendlyInLine(body, t, friendlies(body))
    if hit == nil then return nil end
    if Bridge.body ~= nil and hit == Bridge.body then return "companion", hit end
    if BridgeData.owner() ~= nil and hit == BridgeData.owner() then return "player", hit end
    return "friendly", hit
end


stopReposition = function(body)
    local r = BridgeGunfight.reposition
    if r == nil then return end
    BridgeGunfight.reposition = nil
    if body ~= nil then
        pcall(function() if BridgeMove.onPath() then BridgeMove.stopPath(body) end end)
        BridgeMove.moving = false
        BridgeMove.steering = false
        Bridge.holdPos = nil
        pcall(function() BridgeMove.endFollowBump(body, "") end)
    end
    BridgeGunfight.aimUntil = (Bridge.time or 0) + 20
    BridgeGunfight.nextShotAt = BridgeGunfight.aimUntil
end


local function repositionTick(body, t, blocker)
    local gun = BridgeGunfight.gun
    if gun == nil then return false end
    local now = Bridge.time or 0

    local r = BridgeGunfight.reposition
    if r ~= nil then
        local still = BridgeGunRules.friendlyInLine(body, t, friendlies(body))
        local arrived = BridgeGunRules.dist2(body:getX(), body:getY(), r.x, r.y) < 0.7
        local stalled = now > (r.startT + 90) and BridgeGunRules.dist2(body:getX(), body:getY(), r.sx, r.sy) < 0.3
        if stalled then
            if not r.manual then
                r.manual = true
                r.startT = now
                r.sx, r.sy = body:getX(), body:getY()
                vlog("sidestep path made no progress, stepping directly")
            else
                vlog("sidestep no progress, giving up this step")
                stopReposition(body)
                return false
            end
        end
        if still == nil or arrived or now > r.untilT then
            stopReposition(body)
            return false
        end

        if r.manual then
            local bx, by, bz = body:getX(), body:getY(), body:getZ()
            local dx, dy = r.x - bx, r.y - by
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 0.05 then
                local step = math.min(0.045, len)
                local nx, ny = bx + dx / len * step, by + dy / len * step
                local clear = false
                pcall(function() clear = BridgeMove.lineClear(body, nx, ny, bz) == true end)
                local far = true
                if r.blocker ~= nil then
                    pcall(function()
                        far = BridgeGunRules.dist2(r.blocker:getX(), r.blocker:getY(), nx, ny) >= 0.9
                    end)
                end
                if clear and far then
                    pcall(function()
                        body:setX(nx)
                        body:setY(ny)
                        body:setLastX(nx)
                        body:setLastY(ny)
                        body:setCurrentSquareFromPosition()
                    end)
                    pcall(function()
                        BridgeMove.walkType = "Walk"
                        BridgeMove.applyAnimVars(body)
                        BridgeMove.followBump(body, "Walk")
                    end)
                    BridgeMove.moving = true
                    return true
                end
            end
            stopReposition(body)
            return false
        end

        pcall(function()
            BridgeMove.walkType = "Walk"
            BridgeMove.applyAnimVars(body)
            BridgeMove.steering = true
            BridgeMove.followWs = 1.0
            BridgeMove.followBump(body, "Walk")
            BridgeMove.goToward(body, r.x, r.y, r.z)
        end)
        BridgeMove.moving = true
        return true
    end

    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local dx, dy = t:getX() - bx, t:getY() - by
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then return false end
    local px, py = -dy / len, dx / len
    local first = BridgeGunfight.reposSide or 1
    if BridgeGunfight.reposSide == nil and blocker ~= nil then
        local sx, sy = blocker:getX() - bx, blocker:getY() - by
        if (px * sx + py * sy) > 0 then first = -1 end
    end

    local range = gun.range + 0.9
    local function goalFor(side)
        local off = 2.0
        local x, y = bx + px * off * side, by + py * off * side
        local td = BridgeGunRules.dist2(t:getX(), t:getY(), x, y)
        if td > range or td < BridgeGunRules.MIN_RANGE * 0.8 then return nil end
        if blocker ~= nil and BridgeGunRules.dist2(blocker:getX(), blocker:getY(), x, y) < 1.0 then
            return nil
        end
        local ok = false
        pcall(function() ok = BridgeMove.lineClear(body, x, y, bz) == true end)
        if not ok then return nil end
        return { x = x, y = y, z = bz, side = side }
    end
    local g = goalFor(first)
    if g == nil then g = goalFor(-first) end
    if g == nil then return false end

    BridgeGunfight.reposSide = g.side
    BridgeGunfight.reposition = {
        x = g.x, y = g.y, z = g.z,
        untilT = now + 180,
        startT = now,
        sx = bx,
        sy = by,
        blocker = blocker,
    }
    Bridge.pose = nil
    vlog(string.format("sidestep %s to %.1f,%.1f (line to target %.1f)",
        g.side > 0 and "right" or "left", g.x, g.y, BridgeGunRules.dist2(t:getX(), t:getY(), g.x, g.y)))
    pcall(function()
        BridgeMove.walkType = "Walk"
        BridgeMove.applyAnimVars(body)
        BridgeMove.steering = true
        BridgeMove.followWs = 1.0
        BridgeMove.followBump(body, "Walk")
        BridgeMove.goToward(body, g.x, g.y, g.z)
    end)
    BridgeMove.moving = true
    return true
end


local function noiseMultiplier()
    return BridgeGunRules.noiseMultiplier()
end


local function flash(body)
    pcall(function()
        local cell = getCell()
        if cell == nil then return end
        local src = IsoLightSource.new(math.floor(body:getX()), math.floor(body:getY()), math.floor(body:getZ()),
            1.0, 0.8, 0.25, 6, 5)
        if src == nil then return end
        local added = false
        pcall(function() cell:getLamppostPositions():add(src) added = true end)
        if not added then pcall(function() cell:addLamppost(src) end) end
    end)
end


local function hitBlood(target)
    if target == nil then return end
    pcall(function() target:splatBlood(3, 0.3) end)
    pcall(function() target:splatBloodFloorBig() end)
    pcall(function() target:playBloodSplatterSound() end)
    pcall(function() target:addBlood(nil, false, true, false) end)
end


local function playGunshotAt(x, y, z, sound)
    if type(sound) ~= "string" or sound == "" then return false end
    local emitter = nil
    pcall(function() emitter = getWorld():getFreeEmitter(x, y, z) end)
    if emitter == nil then return false end
    local handle = nil
    pcall(function() handle = emitter:playSoundImpl(sound, false, nil) end)
    if handle == nil or handle == 0 then return false end
    pcall(function()
        local player = getPlayer()
        if player == nil then return end
        local dx, dy = player:getX() - x, player:getY() - y
        local dz = (player:getZ() - z) * 3.0
        local inside, area = 0, 0
        local square = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z))
        local room = square ~= nil and square:getRoom() or nil
        if room ~= nil then
            local here = player:getCurrentSquare()
            inside = (here ~= nil and here:getRoom() == room) and 1 or -1
            local def = room:getRoomDef()
            if def ~= nil then area = def:getArea() end
        end
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        emitter:setParameterValueByName(handle, "FirearmDistance", math.max(0, math.min(1000, distance)))
        emitter:setParameterValueByName(handle, "FirearmInside", inside)
        emitter:setParameterValueByName(handle, "FirearmRoomSize", math.max(0, math.min(1000, tonumber(area) or 0)))
        emitter:setParameterValueByName(handle, "LocalPlayer", 0)
    end)
    return true
end


local function playShot(body, gun)
    if body == nil or gun == nil then return end
    if gun.sound ~= nil then
        local played = false
        pcall(function() played = playGunshotAt(body:getX(), body:getY(), body:getZ(), gun.sound) end)
        if not played then
            pcall(function()
                if BridgeSound ~= nil then BridgeSound.sfx(body, gun.sound) else body:getEmitter():playSound(gun.sound) end
            end)
        end
    end
    pcall(function()
        local radius = (gun.soundRadius or 20) * noiseMultiplier()
        local outside = true
        pcall(function() outside = body:isOutside() ~= false end)
        if not outside then radius = radius * 0.5 end
        pcall(addSound, nil, math.floor(body:getX()), math.floor(body:getY()), math.floor(body:getZ()),
            math.floor(radius), math.floor(gun.soundVolume or 10))
    end)
    flash(body)
end


local function retainBump(body, name)
    BridgeGunfight.bumps[#BridgeGunfight.bumps + 1] = {
        body = body, name = name, untilT = (Bridge.time or 0) + FIRE_TICKS,
    }
end


local function shotFx(body, gun, kind)
    plant(body, "NA_Fire" .. kind)
    pcall(function() body:setVariable(FIRE_VAR, false) end)
    BridgeGunfight.fireUntil = (Bridge.time or 0) + FIRE_TICKS
    retainBump(body, "NA_Aim" .. kind)
    playShot(body, gun)
end


local function checkLowAmmo()
    local rounds = BridgeGunfight.rounds or 0
    if BridgeGunfight.lowSaid then return end
    local maxAmmo = BridgeGunfight.maxAmmo or 0
    if maxAmmo <= 0 then maxAmmo = tonumber(BridgeGunfight.gun and BridgeGunfight.gun.maxAmmo) or 0 end
    if maxAmmo <= 0 then return end
    if rounds <= 0 then
        BridgeGunfight.lowSaid = true
        return
    end
    local threshold = math.max(1, math.ceil(maxAmmo * 0.2))
    if rounds <= threshold then
        if BridgeGunfight.hasAmmo(BridgeGunfight.body) then return end
        local usable = BridgeGunfight.gun ~= nil
            and (BridgeGunfight.gun.magazineType == nil or BridgeData.optionOf(Bridge.store, "gunMagCare"))
        if usable and BridgeGunfight.body ~= nil
            and BridgeGunRules.findAmmoBox(BridgeGunfight.body, BridgeGunfight.gun) ~= nil then return end
        local home = false
        pcall(function() home = BridgeFetch ~= nil and type(BridgeFetch.hasAmmoStock) == "function" and BridgeFetch.hasAmmoStock(BridgeGunfight.gun) end)
        if home then
            BridgeGunfight.lowSaid = true
            return
        end
        BridgeGunfight.lowSaid = true
        pcall(function() BridgeCallout.lowAmmo() end)
    end
end


local aimingLevel

local function applyGunHit(body, item, gun, target, damage, crit)
    if body == nil or item == nil or gun == nil or target == nil then
        return false, 0, 0, false, "ShotBelly", "missing argument"
    end
    if BridgeKnoxNpc ~= nil and BridgeKnoxNpc.isNpc(target) then
        local ok, hpB, hpA, killed = BridgeKnoxNpc.hit(target, body, item, damage, crit)
        return ok, hpB, hpA, killed, nil, nil
    end
    local hpBefore = 0
    pcall(function() hpBefore = target:getHealth() end)
    local fake = nil
    pcall(function() fake = getCell():getFakeZombieForHit() end)
    local attacker = fake or body
    local reaction = BridgeGunRules.shotReaction(body, target, crit)

    pcall(function() attacker:setVariable("ZombieHitReaction", reaction) end)
    pcall(function() body:setVariable("ZombieHitReaction", reaction) end)
    pcall(function() target:setHitFromBehind(body:isBehind(target)) end)
    pcall(function() target:setAttackedBy(attacker) end)
    pcall(function() target:setPlayerAttackPosition(target:testDotSide(body)) end)
    pcall(function() target:setHitHeadWhileOnFloor(0) end)
    pcall(function() target:setHitLegsWhileOnFloor(false) end)
    pcall(function() body:setCriticalHit(crit) end)

    local ok, err = pcall(function() target:Hit(item, attacker, damage, false, 1, false) end)
    pcall(function() body:setCriticalHit(false) end)

    if ok then
        BridgeGunfight.hits = BridgeGunfight.hits + 1
        hitBlood(target)
        pcall(function() target:playSound(gun.hitSound or "ZombieHit") end)
    end
    local hpAfter = hpBefore
    pcall(function() hpAfter = target:getHealth() end)
    local dead = false
    pcall(function() dead = target:isDead() == true or target:getHealth() <= 0 end)
    return ok, hpBefore, hpAfter, dead, reaction, err
end


local function gunCandidates(body, red, primary)
    local out = {}
    local range = BridgeGunfight.modeRange or (BridgeGunfight.gun and BridgeGunfight.gun.range) or 0
    if range <= 0 then return out end
    local cell = getCell()
    if cell == nil then return out end
    local friends = friendlies(body)
    local bx, by = body:getX(), body:getY()
    local list = nil
    if BridgeZS ~= nil then list = BridgeZS.near(bx, by, range + 1.0) end
    if list == nil then list = cell:getZombieList() end
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z ~= nil and z ~= primary and targetOk(z, body, red)
            and math.abs(z:getZ() - body:getZ()) < 0.8 then
            local d = dist(body, z)
            if d <= range + 0.9 then
                local clear = false
                pcall(function()
                    clear = BridgeGunRules.fireLineClear(cell, body:getX(), body:getY(), body:getZ(),
                        z:getX(), z:getY(), z:getZ()) == true
                end)
                if clear and BridgeGunRules.targetVisible(body, red, z)
                    and BridgeGunRules.friendlyInLine(body, z, friends) == nil then
                    out[#out + 1] = z
                end
            end
        end
    end
    return out
end


local function glassTo(body, target)
    if body == nil or target == nil then return 0 end
    local broken = 0
    pcall(function()
        broken = BridgeGunRules.breakGlassOnLine(getCell(), body:getX(), body:getY(), body:getZ(),
            target:getX(), target:getY(), target:getZ()) or 0
    end)
    return broken
end


local function fire(body)
    local item = BridgeGunfight.gunItem
    local gun = BridgeGunfight.gun
    local t = BridgeGunfight.target
    if item == nil or gun == nil or t == nil then return end
    if BridgeGunfight.reloadStage ~= nil or (BridgeGunfight.rounds or 0) <= 0 then return end
    local kind = gun.kind or "Handgun"
    local d = dist(body, t)
    local moving = BridgeGunfight.moving == true
    local chance = BridgeGunRules.hitChance(gun, d, moving, aimingLevel())
    BridgeGunfight.shots = BridgeGunfight.shots + 1
    BridgeGunfight.lastShotAt = Bridge.time
    BridgeGunfight.lastGunAt = Bridge.time
    BridgeGunfight.nextShotAt = (Bridge.time or 0) + math.max(24, (gun.recoilDelay or 24) + 6) + ZombRand(0, 6)

    if Bridge ~= nil and Bridge.mp then
        local onlineId = nil
        pcall(function() onlineId = t:getOnlineID() end)
        local npcId = nil
        if BridgeKnoxNpc ~= nil and BridgeKnoxNpc.isNpc(t) then
            npcId = BridgeKnoxNpc.idOf(t)
            if npcId ~= nil then onlineId = nil end
        end
        local x, y, z = t:getX(), t:getY(), t:getZ()
        BridgeGunfight.pendingShot = { at = Bridge.time, chance = chance, dist = d, target = t }
        shotFx(body, gun, kind)
        pcall(function()
            sendClientCommand(BridgeData.owner(), "Bridge", "gunShot",
                { targetId = onlineId, npcId = npcId, x = x, y = y, z = z })
        end)
        vlog(string.format("shot request -> %s d=%.1f chance=%.0f%%", tostring(item:getType()), d, chance))
        BridgeGunfight.info = string.format("request d=%.1f chance=%.0f", d, chance)
        return
    end

    BridgeGunfight.rounds = math.max(0, (BridgeGunfight.rounds or 1) - 1)
    BridgeGunRules.setRounds(item, BridgeGunfight.rounds, true)
    if BridgeSkills ~= nil then
        pcall(function() BridgeSkills.add("Aiming", 0.5, "shot") end)
    end
    shotFx(body, gun, kind)

    if instanceof(t, "IsoAnimal") then
        local roll = ZombRand(100)
        local hit = roll < chance
        if hit then
            local crit = ZombRand(100) < (tonumber(gun.critChance) or 0)
            local dmg = BridgeGunRules.rollDamage(gun)
            if crit then dmg = dmg * math.max(1, math.min(5, gun.critMult or 2)) end
            if BridgeAnimals ~= nil then BridgeAnimals.attack(t, dmg, body) end
            if BridgeSkills ~= nil then pcall(function() BridgeSkills.add("Aiming", 1, "hit") end) end
            BridgeGunfight.info = string.format("hit d=%.1f dmg=%.1f%s", d, dmg, crit and " crit" or "")
            vlog(string.format("shot animal d=%.1f chance=%.0f%% dmg=%.2f%s", d, chance, dmg, crit and " CRIT" or ""))
        else
            pcall(function()
                local sq = t:getSquare()
                if sq ~= nil then sq:playSound(gun.impactSound or "BulletImpact") end
            end)
            BridgeGunfight.info = string.format("miss d=%.1f chance=%.0f", d, chance)
            vlog(string.format("shot animal miss d=%.1f chance=%.0f%% roll=%d", d, chance, roll + 1))
        end
        checkLowAmmo()
        return
    end

    local shotgun = (tonumber(gun.projectileCount) or 1) > 1
    local red = BridgeData.owner()
    local crit = false
    local shellDamage = 0
    local plan = { kind = nil, extras = {}, primaryShare = 1 }
    local range = BridgeGunfight.modeRange or gun.range or 0
    if shotgun then
        pcall(function() crit = ZombRand(100) < (gun.critChance or 0) end)
        shellDamage = BridgeGunRules.rollDamage(gun)
        if crit then shellDamage = shellDamage * math.max(1, math.min(5, gun.critMult or 2)) end
        plan = BridgeGunRules.multiPlan(body, t, gun, gunCandidates(body, red, t), range, {})
    end

    local roll = ZombRand(100)
    local hit = roll < chance
    local primaryDamage = 0
    local primaryShare = tonumber(plan.primaryShare) or 1
    if hit then
        if shotgun then
            primaryDamage = shellDamage
        else
            pcall(function() crit = ZombRand(100) < (gun.critChance or 0) end)
            primaryDamage = BridgeGunRules.rollDamage(gun)
            if crit then primaryDamage = primaryDamage * math.max(1, math.min(5, gun.critMult or 2)) end
            if gun.piercingBullets == true then
                plan = BridgeGunRules.multiPlan(body, t, gun, gunCandidates(body, red, t), range, {})
                primaryShare = tonumber(plan.primaryShare) or 1
            end
        end
        local ok, hpBefore, hpAfter, dead, reaction, err = applyGunHit(body, item, gun, t,
            primaryDamage * primaryShare, crit)
        if ok and BridgeSkills ~= nil then
            pcall(function() BridgeSkills.add("Aiming", 1, "hit") end)
        end
        if dead and ok then
            pcall(function() if BridgeKills ~= nil then BridgeKills.credit(t) BridgeKills.confirm(t) end end)
            pcall(function() BridgeCallout.gunKill(t) end)
        end
        vlog(string.format("shot hit %s d=%.1f chance=%.0f%% roll=%d dmg=%.2f%s hp=%.2f->%.2f%s reaction=%s%s",
            tostring(item:getType()), d, chance, roll + 1, primaryDamage * primaryShare, crit and " CRIT" or "",
            hpBefore, hpAfter, dead and " KILL" or "", tostring(reaction),
            ok and "" or (" error=" .. tostring(err))))
        BridgeGunfight.info = string.format("hit d=%.1f dmg=%.1f hp=%.1f%s", d, primaryDamage * primaryShare, hpAfter,
            dead and " kill" or "")
    else
        pcall(function()
            local sq = t:getSquare()
            if sq ~= nil then sq:playSound(gun.impactSound or "BulletImpact") end
        end)
        vlog(string.format("shot miss %s d=%.1f chance=%.0f%% roll=%d", tostring(item:getType()), d, chance, roll + 1))
        BridgeGunfight.info = string.format("miss d=%.1f chance=%.0f", d, chance)
    end

    local extras = plan.extras or {}
    local extraHits, extraKills = 0, 0
    local extraLog = {}
    for _, ex in ipairs(extras) do
        local z = ex.target
        local ehit = true
        local echance = 100
        if shotgun then
            echance = clamp(BridgeGunRules.hitChance(gun, ex.dist or dist(body, z), moving, aimingLevel())
                * (ex.chanceScale or 1), BridgeGunRules.MIN_CHANCE, BridgeGunRules.MAX_CHANCE)
            ehit = ZombRand(100) < echance
        end
        local edmg = 0
        local ok, dead = false, false
        if ehit then
            if shotgun then
                edmg = shellDamage * (ex.share or 0)
            else
                edmg = primaryDamage * (ex.share or 0)
            end
            ok, _, _, dead = applyGunHit(body, item, gun, z, edmg, crit)
            if ok then extraHits = extraHits + 1 end
            if ok and dead then
                extraKills = extraKills + 1
                pcall(function() if BridgeKills ~= nil then BridgeKills.credit(z) BridgeKills.confirm(z) end end)
            end
        else
            pcall(function()
                local sq = z:getSquare()
                if sq ~= nil then sq:playSound(gun.impactSound or "BulletImpact") end
            end)
        end
        extraLog[#extraLog + 1] = string.format("%.1f/s=%.2f/%s", dist(body, z), ex.share or 0,
            ehit and (ok and (dead and "kill" or "hit") or "error") or "miss")
    end

    local glass = glassTo(body, t)
    for _, ex in ipairs(extras) do glass = glass + glassTo(body, ex.target) end

    if not hit and extraHits > 0 then
        BridgeGunfight.info = string.format("miss primary, extras hit=%d", extraHits)
    end
    if #extras > 0 or glass > 0 then
        vlog(string.format("multi-hit %s kind=%s primaryShare=%.2f extras=%d hits=%d kills=%d glass=%d [%s]",
            tostring(item:getType()), tostring(plan.kind or "none"), primaryShare, #extras,
            extraHits, extraKills, glass, table.concat(extraLog, " ")))
    end
    checkLowAmmo()
end


local function backpedal(body, t)
    local bx, by = body:getX(), body:getY()
    local dx, dy = bx - t:getX(), by - t:getY()
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then dx, dy, len = 0, 1, 1 end
    local rx, ry = bx + (dx / len) * 3.5, by + (dy / len) * 3.5
    local z = body:getZ()
    if not BridgeMove.lineClear(body, rx, ry, z) then return false end
    local moved = false
    pcall(function()
        moved = BridgeMove.goStraight(body, rx, ry, z, false, function(b, x, y, zz)
            return BridgeMove.lineClear(b, x, y, zz)
        end) == true
    end)
    if moved then
        vlog(string.format("backpedal from %.1f tiles to %.1f,%.1f", dist(body, t), rx, ry))
    end
    return moved
end


aimingLevel = function()
    if BridgeSkills == nil or BridgeSkills.level == nil then return 0 end
    return BridgeSkills.level("Aiming") or 0
end


local function reserveNear(body)
    if BridgeGunfight.reserveAt == nil or (Bridge.time or 0) - BridgeGunfight.reserveAt >= 15 then
        BridgeGunfight.reserveAt = Bridge.time or 0
        local n = 0
        pcall(function()
            if BridgeHorde ~= nil and BridgeHorde.count ~= nil then
                n = BridgeHorde.count(body:getX(), body:getY(), body:getZ(), BridgeHorde.RADIUS)
            end
        end)
        BridgeGunfight.reserveN = tonumber(n) or 0
    end
    return BridgeGunfight.reserveN or 0
end


local meleeCache = { body = nil, at = nil, ready = false }

local function meleeReady(body)
    local now = Bridge.time or 0
    local c = meleeCache
    if c.body == body and c.at ~= nil and now - c.at < 30 then return c.ready end
    local ok = false
    pcall(function()
        local item = BridgeWeapon.bestOwn(body, false)
        ok = item ~= nil and BridgeWeapon.isMelee(item)
    end)
    meleeCache.body, meleeCache.at, meleeCache.ready = body, now, ok
    return ok
end


local function liveThreat(body, target, maxRange)
    if target == nil then return nil end
    local alive = false
    pcall(function() alive = target:isAlive() and target:getHealth() > 0 end)
    if not alive then return nil end
    if dist(body, target) > (maxRange or BridgeGunRules.MIN_RANGE) then return nil end
    return target
end


local nearestCache = { body = nil, at = nil, threat = nil }

local function nearestMeleeThreat(body, maxRange)
    if body == nil then return nil end
    local now = Bridge.time or 0
    local c = nearestCache
    local hit = nil
    if c.body == body and c.at ~= nil and now - c.at < 5 then
        hit = c.threat
    else
        local best, bestD = nil, MELEE_RELEASE_RANGE
        local red = BridgeData.owner()
        pcall(function()
            local list = nil
            if BridgeZS ~= nil then
                list = BridgeZS.near(body:getX(), body:getY(), MELEE_RELEASE_RANGE)
            end
            if list == nil then list = getCell():getZombieList() end
            if list == nil then return end
            for i = 0, list:size() - 1 do
                local z = list:get(i)
                if z ~= nil and z ~= body and targetOk(z, body, red)
                    and math.abs(z:getZ() - body:getZ()) < 0.8 then
                    local d = dist(body, z)
                    if d <= bestD then best, bestD = z, d end
                end
            end
        end)
        c.body, c.at, c.threat = body, now, best
        hit = best
    end
    return liveThreat(body, hit, maxRange or BridgeGunRules.MIN_RANGE)
end


local function meleeThreat(body)
    if not BridgeData.optionOf(Bridge.store, "gunMelee") or not meleeReady(body) then return nil end
    local target = liveThreat(body, BridgeFight.target, BridgeGunRules.MIN_RANGE)
    if target ~= nil then return target end
    return nearestMeleeThreat(body, BridgeGunRules.MIN_RANGE)
end


local function meleeReleaseReady(body)
    if not BridgeData.optionOf(Bridge.store, "gunMelee") or not meleeReady(body) then return true end
    if liveThreat(body, BridgeFight.target, MELEE_RELEASE_RANGE) ~= nil
        or nearestMeleeThreat(body, MELEE_RELEASE_RANGE) ~= nil then
        BridgeGunfight.meleeClearAt = nil
        return false
    end
    if BridgeGunfight.meleeClearAt == nil then
        BridgeGunfight.meleeClearAt = Bridge.time or 0
        return false
    end
    return (Bridge.time or 0) - BridgeGunfight.meleeClearAt >= MELEE_RELEASE_HOLD
end


local function swingRecoveryReady()
    local at = BridgeFight.lastSwingAt
    if at == nil then return true end
    local len = BridgeFight.swingLen or 0
    return (Bridge.time or 0) >= at + len + MELEE_TO_GUN
end


local function transferHoldsReload(body)
    if BridgeGunfight.reloadHoldUntil ~= nil and (Bridge.time or 0) < BridgeGunfight.reloadHoldUntil then
        return true
    end
    if BridgeInventory ~= nil and type(BridgeInventory.transferPending) == "function" then
        local pending = false
        pcall(function() pending = BridgeInventory.transferPending(body) == true end)
        if pending then return true end
    end
    return false
end

local function idleReloadWanted(body, gun)
    if body == nil or gun == nil then return false end
    local rounds = BridgeGunfight.rounds or 0
    if rounds <= 0 then return BridgeGunfight.readyAmmo(body) end
    if not BridgeData.optionOf(Bridge.store, "gunReloadIdle") then return false end
    local maxAmmo = tonumber(gun.maxAmmo) or 0
    if maxAmmo <= 0 then return false end
    if gun.magazineType ~= nil then
        local magazine, best = BridgeGunRules.findLoadedMagazine(body, gun)
        if magazine == nil or best <= 0 then return false end
        if rounds <= 0 then return true end
        return rounds <= math.floor(maxAmmo * 0.25) and best > rounds
    end
    return rounds < maxAmmo and BridgeGunRules.hasReloadSource(body, gun)
end


local function magCareTicks(gun)
    local base = RELOAD_LOAD_HANDGUN
    if gun ~= nil and gun.reloadFamily == "rifle" then base = RELOAD_LOAD_RIFLE end
    return stageTicks(base)
end


local function handAlive(item)
    local ok = false
    if item ~= nil then pcall(function() ok = item:getContainer() ~= nil end) end
    return ok
end


local function magCareBegin(body, magazine, skipAnim)
    BridgeGunfight.magCareHand1 = nil
    BridgeGunfight.magCareHand2 = nil
    pcall(function() BridgeGunfight.magCareHand1 = body:getPrimaryHandItem() end)
    pcall(function() BridgeGunfight.magCareHand2 = body:getSecondaryHandItem() end)
    pcall(function() body:setPrimaryHandItem(nil) end)
    pcall(function() body:setSecondaryHandItem(nil) end)
    if magazine ~= nil then
        pcall(function() body:setSecondaryHandItem(magazine) end)
    end
    pcall(function() body:setVariable(RELOAD_VAR, reloadFactor()) end)
    pcall(function() body:resetEquippedHandsModels() end)
    if not skipAnim then plantMaintenance(body, "NA_InsertBullets") end
end


local function magCareEnd(body)
    local h1, h2 = BridgeGunfight.magCareHand1, BridgeGunfight.magCareHand2
    BridgeGunfight.magCareHand1 = nil
    BridgeGunfight.magCareHand2 = nil
    if body == nil then return end
    pcall(function() body:setPrimaryHandItem(nil) end)
    pcall(function() body:setSecondaryHandItem(nil) end)
    if handAlive(h1) then pcall(function() body:setPrimaryHandItem(h1) end) end
    if handAlive(h2) and h2 ~= h1 then pcall(function() body:setSecondaryHandItem(h2) end) end
    pcall(function() body:setVariable(RELOAD_VAR, 1) end)
    pcall(function() body:resetEquippedHandsModels() end)
    clearBump(body)
end


local function finishMagCare(body, reason)
    if BridgeGunfight.magCareStage == nil then return end
    BridgeGunfight.magCareStage = nil
    BridgeGunfight.magCareUntil = nil
    BridgeGunfight.magCareStageAt = nil
    BridgeGunfight.magCareStageTicks = 0
    BridgeGunfight.magCareMagId = nil
    BridgeGunfight.magCareMag = nil
    BridgeGunfight.magCareAt = Bridge.time or 0
    BridgeGunfight.info = "magazine ready"
    magCareEnd(body)
    if BridgeWeapon ~= nil then pcall(function() BridgeWeapon.lost = nil end) end
    log("magazine care done: " .. tostring(reason))
end


local function advanceMagCare(body, gun)
    local now = Bridge.time or 0
    showGunBar(magCareProgress())
    if not actionElapsed(BridgeGunfight.magCareStageAt, BridgeGunfight.magCareStageTicks) then
        plantMaintenance(body, "NA_InsertBullets")
        return true
    end
    local magazine = nil
    if body ~= nil and BridgeGunfight.magCareMagId ~= nil then
        pcall(function() magazine = BridgeGunRules.findItemById(body, BridgeGunfight.magCareMagId) end)
    end
    if magazine == nil then magazine = BridgeGunfight.magCareMag end
    local alive = false
    if magazine ~= nil then
        pcall(function() alive = magazine:getContainer() ~= nil end)
    end
    if not alive then
        finishMagCare(body, "magazine gone")
        return false
    end
    local removed = BridgeGunRules.removeOneLooseRound(body, gun)
    if removed == nil then
        finishMagCare(body, "no loose rounds")
        return false
    end
    local got = 1
    tellLoadOne(removed, BridgeGunfight.magCareMagId)
    local maxAmmo = tonumber(gun.maxAmmo) or 0
    local magMax = 0
    pcall(function() magMax = math.floor(tonumber(magazine:getMaxAmmo()) or 0) end)
    if magMax > 0 then maxAmmo = magMax end
    local rounds = BridgeGunRules.roundsOf(magazine) + got
    if maxAmmo > 0 and rounds > maxAmmo then rounds = maxAmmo end
    BridgeGunRules.setRounds(magazine, rounds, false)
    playGunSound(body, "MagazineInsertAmmo")
    if BridgeSkills ~= nil and BridgeSkills.add ~= nil then
        pcall(function() BridgeSkills.add("Reloading", got, "round") end)
    end
    BridgeGunfight.magCareRounds = rounds
    BridgeGunfight.info = "loading magazine " .. tostring(rounds) .. "/" .. tostring(maxAmmo)
    log("magazine care loaded " .. tostring(rounds) .. "/" .. tostring(maxAmmo))
    if maxAmmo > 0 and rounds >= maxAmmo then
        finishMagCare(body, "magazine full")
        return false
    end
    local _, total = BridgeGunRules.findLooseRounds(body, gun, 1)
    if total <= 0 then
        finishMagCare(body, "no loose rounds")
        return false
    end
    local nextTicks = stageTicks(RELOAD_ROUND_MAGAZINE)
    BridgeGunfight.magCareStageAt = now
    BridgeGunfight.magCareStageTicks = nextTicks
    BridgeGunfight.magCareUntil = now + (nextTicks / speedMult())
    plantMaintenance(body, "NA_InsertBullets")
    return true
end


local function magazineCare(body, gun)
    if body == nil or gun == nil or gun.magazineType == nil then return false end
    if BridgeGunfight.magCareStage ~= nil then
        if BridgeFight ~= nil and BridgeFight.target ~= nil then
            finishMagCare(body, "target")
            BridgeGunfight.info = "magazine load cancelled"
            return false
        end
        return advanceMagCare(body, gun)
    end
    if transferHoldsReload(body) then return false end
    if not BridgeData.optionOf(Bridge.store, "gunMagCare") then return false end
    if BridgeFight == nil or BridgeFight.target ~= nil or BridgeFight.state == "swing" then return false end
    if BridgeGunfight.reloadStage ~= nil or BridgeGunfight.state ~= "idle" then return false end
    if BridgeTask ~= nil and BridgeTask.active then return false end
    if Bridge.time - (BridgeGunfight.magCareAt or 0) < magCareTicks(gun) then return false end
    local maxAmmo = tonumber(gun.maxAmmo) or 0
    if maxAmmo <= 0 then return false end
    local _, total = BridgeGunRules.findLooseRounds(body, gun, 1)
    if total <= 0 then return false end
    local magazine = BridgeGunRules.findPartialMagazine(body, gun)
    if magazine == nil and BridgeGunfight.gunItem ~= nil then
        local inserted = false
        local clipType = nil
        pcall(function() inserted = BridgeGunfight.gunItem:isContainsClip() == true end)
        pcall(function()
            local part = BridgeGunfight.gunItem:getWeaponPart("Clip")
            if part ~= nil then clipType = part:getFullType() end
        end)
        local loaded = BridgeGunRules.findLoadedMagazine(body, gun)
        if loaded == nil and inserted and BridgeGunRules.roundsOf(BridgeGunfight.gunItem) <= 0 then
            magazine = BridgeGunRules.ejectMagazine(body, gun, 0)
            if magazine ~= nil then
                BridgeGunRules.setRounds(BridgeGunfight.gunItem, 0, false)
                BridgeGunfight.rounds = 0
                log(string.format("magazine care: ejected inserted magazine id=%s type=%s rounds=%d clipPart=%s",
                    tostring(magazine:getID()), tostring(gun.magazineType), BridgeGunRules.roundsOf(magazine),
                    tostring(clipType or "-")))
            else
                log(string.format("magazine care: eject failed type=%s clipPart=%s",
                    tostring(gun.magazineType), tostring(clipType or "-")))
            end
        elseif not inserted and loaded == nil then
            local key = tostring(clipType)
            if BridgeGunfight.magCareLogged ~= key then
                BridgeGunfight.magCareLogged = key
                log(string.format("magazine care: no magazine (containsClip=false clipPart=%s spareMags=0)",
                    tostring(clipType or "-")))
            end
        end
    end
    if magazine == nil then
        BridgeGunfight.magCareAt = Bridge.time or 0
        return false
    end
    local firstTicks = stageTicks(RELOAD_ROUND_MAGAZINE)
    BridgeGunfight.magCareStage = "load"
    BridgeGunfight.magCareStageAt = Bridge.time or 0
    BridgeGunfight.magCareStageTicks = firstTicks
    BridgeGunfight.magCareMagId = magazine:getID()
    BridgeGunfight.magCareMag = magazine
    BridgeGunfight.magCareRounds = BridgeGunRules.roundsOf(magazine)
    BridgeGunfight.magCareUntil = (Bridge.time or 0) + (firstTicks / speedMult())
    local startType, startCap = nil, 0
    pcall(function() startType = magazine:getFullType() end)
    pcall(function() startCap = math.floor(tonumber(magazine:getMaxAmmo()) or 0) end)
    BridgeGunfight.info = "loading magazine"
    BridgeGunfight.magCareLogged = nil
    magCareBegin(body, magazine)
    log(string.format("magazine care start type=%s rounds=%d cap=%d",
        tostring(startType or "-"), BridgeGunfight.magCareRounds or 0, startCap))
    return true
end


function BridgeGunfight.cancelMagCare(body)
    if BridgeGunfight.magCareStage == nil then return false end
    finishMagCare(body or BridgeGunfight.body, "cancelled")
    return true
end

local function reloadingLevel()
    if BridgeSkills == nil or BridgeSkills.level == nil then return 0 end
    return BridgeSkills.level("Reloading") or 0
end

reloadFactor = function()
    return BridgeGunRules.reloadFactor(reloadingLevel())
end

stageTicks = function(base)
    local ticks = base / reloadFactor()
    if ticks < 6 then ticks = 6 end
    return math.floor(ticks + 0.5)
end

playGunSound = function(body, name)
    if body == nil or type(name) ~= "string" or name == "" then return end
    pcall(function()
        if BridgeSound ~= nil then BridgeSound.sfx(body, name) else body:getEmitter():playSound(name) end
    end)
end

local function applyReloadSpeed(body, factor)
    if body == nil then return end
    if factor == nil or factor <= 0 then factor = 1 end
    pcall(function() body:setVariable(RELOAD_VAR, 1 / factor) end)
end

local function clearReloadSpeed(body)
    if body == nil then return end
    pcall(function() body:setVariable(RELOAD_VAR, 1) end)
end

bumpName = function(action, family)
    if family == "handgun" then
        if action == "unload" then return "NA_UnloadHandgun" end
        if action == "load" then return "NA_LoadHandgun" end
        return "NA_RackHandgun"
    end
    if family == "rifle" then
        if action == "unload" then return "NA_UnloadRifle" end
        if action == "load" then return "NA_LoadRifle" end
        return "NA_RackRifle"
    end
    if family == "shotgun" then
        if action == "load" then return "NA_LoadShotgun" end
        return "NA_RackShotgun"
    end
    if family == "revolver" then
        if action == "load" then return "NA_LoadRevolver" end
        return "NA_RackRevolver"
    end
    if action == "load" then return "NA_LoadRifleNoMag" end
    return "NA_RackRifleNoMag"
end

local function tellReload(action, extra)
    if Bridge == nil or not Bridge.mp then return end
    local args = { action = action }
    if type(extra) == "table" then
        for k, v in pairs(extra) do args[k] = v end
    end
    pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "gunReload", args) end)
end


tellLoadOne = function(item, magId)
    if Bridge == nil or not Bridge.mp then return end
    local args = {}
    if item ~= nil then
        pcall(function()
            args.itemId = item:getID()
            args.itemType = item:getFullType()
        end)
    end
    if magId ~= nil then args.magId = magId end
    pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "gunLoadOne", args) end)
end

local function setReloadStage(body, stage, ticks)
    local now = Bridge.time or 0
    local base = tonumber(ticks) or 0
    local mult = speedMult()
    BridgeGunfight.reloadStage = stage
    BridgeGunfight.reloadStageAt = now
    BridgeGunfight.reloadStageTicks = base
    BridgeGunfight.reloadUntil = now + (base / mult)
    vlog(string.format("reload stage %s base=%d x=%.2f at=%.1f", tostring(stage), base, mult, now))
    local name = bumpName(stage, BridgeGunfight.reloadFamily)
    plant(body, name)
    pcall(function() body:setVariable(FIRE_VAR, false) end)
    local gun = BridgeGunfight.gun or {}
    local sound = gun.insertSound
    if stage == "unload" then sound = gun.ejectSound
    elseif stage == "rack" then sound = gun.rackSound end
    playGunSound(body, sound)
end

local function finishReload(body)
    if BridgeMove ~= nil then BridgeMove.forcedWalk = nil end
    local external = BridgeGunfight.gun ~= nil and BridgeGunfight.gun.magazineType ~= nil
    local virtual = BridgeGunfight.reloadVirtual == true
    local clientAmmo = BridgeGunfight.reloadClientAmmo == true
    local taken = BridgeGunfight.reloadTaken or 0
    local sendRounds = BridgeGunfight.reloadNeed or BridgeGunfight.rounds or 0
    if virtual and (BridgeGunfight.rounds or 0) > 0 then sendRounds = BridgeGunfight.rounds end
    local baseLog = tonumber(BridgeGunfight.reloadBaseRounds) or 0
    local needLog = tonumber(BridgeGunfight.reloadNeed) or 0

    local maxAmmo = tonumber(BridgeGunfight.gun and BridgeGunfight.gun.maxAmmo) or 0
    if maxAmmo <= 0 then maxAmmo = tonumber(BridgeGunfight.maxAmmo) or 0 end
    local expected = tonumber(BridgeGunfight.reloadNeed) or 0
    if not external then
        expected = (tonumber(BridgeGunfight.reloadBaseRounds) or 0) + expected
        if maxAmmo > 0 and expected > maxAmmo then expected = maxAmmo end
    elseif maxAmmo > 0 and expected > maxAmmo then
        expected = maxAmmo
    end
    local authoritative = Bridge == nil or not Bridge.mp
    if authoritative and expected > (BridgeGunfight.rounds or 0) then
        BridgeGunfight.rounds = expected
    end

    if Bridge ~= nil and Bridge.mp then
        tellReload("complete", { rounds = sendRounds, external = external, taken = taken,
            maxAmmo = maxAmmo, magType = BridgeGunfight.gun and BridgeGunfight.gun.magazineType })
    end
    if authoritative and BridgeGunfight.gunItem ~= nil then
        BridgeGunRules.setRounds(BridgeGunfight.gunItem, BridgeGunfight.rounds or 0, true)
    end
    BridgeGunfight.reloadStage = nil
    BridgeGunfight.reloadUntil = nil
    BridgeGunfight.reloadStageAt = nil
    BridgeGunfight.reloadStageTicks = 0
    BridgeGunfight.reloadMagId = nil
    BridgeGunfight.reloadRoundsLeft = 0
    BridgeGunfight.reloadNeed = 0
    BridgeGunfight.reloadVirtual = false
    BridgeGunfight.reloadClientAmmo = false
    BridgeGunfight.reloadTaken = 0
    BridgeGunfight.reloadSavedRounds = 0
    BridgeGunfight.reloadBaseRounds = 0
    BridgeGunfight.reloadCancel = false
    BridgeGunfight.reloadDoneAt = Bridge.time
    clearReloadSpeed(body)
    BridgeGunfight.lowSaid = false
    BridgeGunfight.aimUntil = (Bridge.time or 0) + BridgeGunRules.aimTicks(BridgeGunfight.gun, aimingLevel())
    BridgeGunfight.nextShotAt = BridgeGunfight.aimUntil
    BridgeGunfight.state = "aim"
    plant(body, "NA_Aim" .. ((BridgeGunfight.gun and BridgeGunfight.gun.kind) or "Handgun"))
    log(string.format("reload done rounds=%d/%d base=%d need=%d taken=%d clientAmmo=%s",
        BridgeGunfight.rounds or 0, BridgeGunfight.maxAmmo or 0, baseLog, needLog,
        taken, tostring(clientAmmo)))
    return false
end

local function cancelReload(body, reason)
    if BridgeMove ~= nil then BridgeMove.forcedWalk = nil end
    if BridgeGunfight.reloadStage == nil then return false end
    if Bridge ~= nil and Bridge.mp then tellReload("cancel", {}) end
    BridgeGunfight.reloadStage = nil
    BridgeGunfight.reloadUntil = nil
    BridgeGunfight.reloadStageAt = nil
    BridgeGunfight.reloadStageTicks = 0
    BridgeGunfight.reloadMagId = nil
    BridgeGunfight.reloadRoundsLeft = 0
    BridgeGunfight.reloadNeed = 0
    BridgeGunfight.reloadVirtual = false
    BridgeGunfight.reloadSavedRounds = 0
    BridgeGunfight.reloadBaseRounds = 0
    BridgeGunfight.reloadCancel = false
    clearReloadSpeed(body)
    clearBump(body)
    BridgeGunfight.state = "idle"
    log("reload cancelled: " .. tostring(reason or "?"))
    return false
end

function BridgeGunfight.interruptReload(body, reason)
    local stopped = false
    if BridgeGunfight.magCareStage ~= nil then
        pcall(function() BridgeGunfight.cancelMagCare(body) end)
        stopped = true
    end
    if BridgeGunfight.reloadStage ~= nil then
        pcall(function() cancelReload(body, reason or "inventory transfer") end)
        stopped = true
    end
    if BridgeGunfight.ammoItem ~= nil then
        BridgeGunfight.ammoItem, BridgeGunfight.ammoOut, BridgeGunfight.ammoAmount = nil, nil, 0
        BridgeGunfight.ammoUntil = nil
        BridgeGunfight.ammoStageAt = nil
        BridgeGunfight.ammoStageTicks = 0
        BridgeGunfight.ammoCooldown = (Bridge.time or 0) + 60
        pcall(function() magCareEnd(body) end)
        if BridgeWeapon ~= nil then pcall(function() BridgeWeapon.lost = nil end) end
        stopped = true
    end
    if stopped then
        BridgeGunfight.reloadHoldUntil = math.max(tonumber(BridgeGunfight.reloadHoldUntil) or 0,
            (Bridge.time or 0) + 120)
        if BridgeMove ~= nil then BridgeMove.forcedWalk = nil end
        pcall(function() clearBump(body) end)
        BridgeGunfight.state = "idle"
        BridgeGunfight.info = "reload interrupted: " .. tostring(reason or "inventory transfer")
    end
    return stopped
end

local function refillNeed(body, gun)
    if body == nil or gun == nil then return 0 end
    local cap = tonumber(gun.maxAmmo) or 0
    if cap <= 0 then return 0 end
    if gun.magazineType == nil then
        return math.max(0, cap - (BridgeGunfight.rounds or 0))
    end
    local mag = BridgeGunRules.findPartialMagazine(body, gun)
    if mag ~= nil then
        local magCap = 0
        pcall(function() magCap = math.floor(tonumber(mag:getMaxAmmo()) or 0) end)
        if magCap > 0 then cap = magCap end
        return math.max(0, cap - BridgeGunRules.roundsOf(mag))
    end
    if BridgeGunfight.gunItem ~= nil and BridgeGunRules.roundsOf(BridgeGunfight.gunItem) <= 0 then
        return cap
    end
    return 0
end


local function startAmmoOpen(body)
    if body == nil or BridgeGunfight.gun == nil then return false end
    if BridgeGunfight.ammoItem ~= nil then return true end
    if transferHoldsReload(body) then return false end
    if BridgeGunfight.ammoCooldown ~= nil and (Bridge.time or 0) < BridgeGunfight.ammoCooldown then return false end
    if BridgeGunfight.gun.magazineType ~= nil and not BridgeData.optionOf(Bridge.store, "gunMagCare") then
        BridgeGunfight.ammoCooldown = (Bridge.time or 0) + 600
        vlog("ammo box skipped: magazine gun without magazine care")
        return false
    end
    local need = refillNeed(body, BridgeGunfight.gun)
    if need <= 0 then return false end
    local _, loose = BridgeGunRules.findLooseRounds(body, BridgeGunfight.gun, need)
    if loose >= need then return false end
    local danger = false
    pcall(function()
        local red = BridgeData.owner()
        local bx, by = body:getX(), body:getY()
        local list = nil
        if BridgeZS ~= nil then list = BridgeZS.near(bx, by, BridgeGunRules.MIN_RANGE) end
        if list == nil then list = getCell():getZombieList() end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and dist(body, z) <= BridgeGunRules.MIN_RANGE and targetOk(z, body, red) then
                danger = true
                return
            end
        end
    end)
    if danger then
        BridgeGunfight.ammoCooldown = (Bridge.time or 0) + 30
        vlog("ammo box skipped: zombie at melee range")
        return false
    end
    local found, pick = pcall(BridgeGunRules.findAmmoBox, body, BridgeGunfight.gun)
    if not found then
        BridgeGunfight.ammoCooldown = (Bridge.time or 0) + 600
        log("ammo box lookup failed: " .. tostring(pick))
        return false
    end
    if pick == nil then return false end
    BridgeGunfight.ammoItem = pick.item
    BridgeGunfight.ammoOut = pick.out
    BridgeGunfight.ammoAmount = pick.amount
    local openTicks = math.max(15, tonumber(pick.ticks) or 75)
    BridgeGunfight.ammoStageAt = Bridge.time or 0
    BridgeGunfight.ammoStageTicks = openTicks
    BridgeGunfight.ammoUntil = (Bridge.time or 0) + (openTicks / speedMult())
    BridgeGunfight.ammoCooldown = nil
    BridgeGunfight.state = "open"
    BridgeGunfight.info = "opening " .. tostring(pick.type)
    BridgeGunfight.canMelee = false
    if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
    magCareBegin(body, pick.item, true)
    plantMaintenance(body, "NA_OpenAmmoBox")
    log(string.format("ammoOpen start box=%s out=%s n=%d ticks=%d",
        tostring(pick.type), tostring(pick.out), pick.amount, pick.ticks or 75))
    return true
end


local function homeAmmo(body)
    if body == nil or BridgeGunfight.gun == nil then return false end
    if BridgeFetch == nil or type(BridgeFetch.pullAmmo) ~= "function" then return false end
    local now = Bridge.time or 0
    if BridgeGunfight.ammoBorrow ~= nil then
        local held = nil
        pcall(function() held = BridgeGunRules.findItemById(body, BridgeGunfight.ammoBorrow.itemId) end)
        if held == nil then
            BridgeGunfight.ammoBorrow = nil
            log("home ammo: borrowed carton gone, clearing return record")
        end
    end
    if BridgeGunfight.homeAmmoAt ~= nil and now < BridgeGunfight.homeAmmoAt then return false end
    if not BridgeFetch.availableAmmo() then return false end
    local need = refillNeed(body, BridgeGunfight.gun)
    local minRounds = 0
    if BridgeGunfight.gun.magazineType ~= nil then
        local cap = tonumber(BridgeGunfight.gun.maxAmmo) or 0
        local partial = BridgeGunRules.findPartialMagazine(body, BridgeGunfight.gun)
        local _, best = BridgeGunRules.findLoadedMagazine(body, BridgeGunfight.gun)
        local inserted = 0
        if BridgeGunfight.gunItem ~= nil then inserted = BridgeGunRules.roundsOf(BridgeGunfight.gunItem) end
        inserted = tonumber(inserted) or 0
        if cap > 0 and best ~= nil and best >= cap and partial == nil then return false end
        if partial ~= nil then
            minRounds = 0
        else
            minRounds = inserted
            if need <= 0 and inserted > 0 and inserted < cap then need = cap - inserted end
        end
    end
    if need <= 0 then return false end
    local _, loose = BridgeGunRules.findLooseRounds(body, BridgeGunfight.gun, need)
    if loose >= need then return false end
    if BridgeGunRules.findAmmoBox(body, BridgeGunfight.gun) ~= nil then return false end
    local pull = need - loose
    if pull < 1 then pull = 1 end
    local res = BridgeFetch.pullAmmo(BridgeGunfight.gun, minRounds, pull)
    if res == "requested" or res == "moved" then
        BridgeGunfight.homeAmmoAt = now + 120
        BridgeGunfight.info = "taking ammo from home"
        log("home ammo " .. tostring(res))
        return true
    end
    if res == "absent" then
        log("home ammo: no matching ammo for " .. tostring(BridgeGunfight.gun and BridgeGunfight.gun.fullType or "?"))
    end
    if res == "unsupported" then
        log("home ammo: unsupported carton breakdown")
    end
    if res ~= "have" then BridgeGunfight.homeAmmoAt = now + 600 end
    return false
end


local function finishAmmoOpen(body)
    local item = BridgeGunfight.ammoItem
    local out, amount = BridgeGunfight.ammoOut, BridgeGunfight.ammoAmount
    local openedId = nil
    if item ~= nil then pcall(function() openedId = item:getID() end) end
    BridgeGunfight.ammoItem, BridgeGunfight.ammoOut, BridgeGunfight.ammoAmount = nil, nil, 0
    BridgeGunfight.ammoUntil = nil
    BridgeGunfight.ammoStageAt = nil
    BridgeGunfight.ammoStageTicks = 0
    BridgeGunfight.state = "idle"
    magCareEnd(body)
    BridgeGunfight.magCareAt = Bridge.time or 0
    if BridgeWeapon ~= nil then pcall(function() BridgeWeapon.lost = nil end) end
    local opened = false
    if item ~= nil and out ~= nil then
        local called, ok = pcall(BridgeGunRules.openAmmoBox, body, item, out, amount)
        if not called then
            log("ammo box open failed: " .. tostring(ok))
            ok = false
        end
        opened = ok == true
        BridgeGunfight.info = opened and ("opened box: +" .. tostring(amount) .. " " .. tostring(out)) or "ammo box failed"
        log(string.format("ammoOpen done ok=%s out=%s n=%d", tostring(opened), tostring(out), amount))
        local borrow = BridgeGunfight.ammoBorrow
        if borrow ~= nil and openedId ~= nil and openedId == borrow.itemId then
            local calledReturn, moved, available, reason =
                pcall(BridgeGunRules.returnAmmoBoxes, body, borrow.src, borrow.boxType, borrow.count)
            if not calledReturn then
                moved, available, reason = 0, 0, tostring(moved)
            end
            moved = tonumber(moved) or 0
            available = tonumber(available) or 0
            local created = opened and amount or 0
            log(string.format("home ammo: carton %s opened, created=%s, returned=%d, kept=%d, source=%s%s",
                tostring(borrow.cartonType), tostring(created), moved, math.max(0, available - moved),
                tostring(borrow.src), reason and (" reason=" .. tostring(reason)) or ""))
            if not opened then
                log("home ammo: carton open failed, return result=" .. tostring(moved) .. "/" .. tostring(available))
            end
            if moved > 0 then
                BridgeGunfight.info = "kept 1 box, returned " .. tostring(moved) .. " to home"
            end
            BridgeGunfight.ammoBorrow = nil
        end
    end
    BridgeGunfight.ammoCooldown = (Bridge.time or 0) + (opened and 30 or 600)
    return true
end


local function ammoOpenTick(body)
    if BridgeGunfight.ammoItem == nil then return false end
    if not actionElapsed(BridgeGunfight.ammoStageAt, BridgeGunfight.ammoStageTicks) then
        plantMaintenance(body, "NA_OpenAmmoBox")
        return true
    end
    return finishAmmoOpen(body)
end


local function outOfAmmo(body)
    BridgeGunfight.peek = nil
    if BridgeMove ~= nil then BridgeMove.forcedWalk = nil end
    local first = BridgeGunfight.suspended ~= true
    BridgeGunfight.rounds = 0
    if BridgeGunfight.gunItem ~= nil then
        BridgeGunRules.setRounds(BridgeGunfight.gunItem, 0, true)
    end
    BridgeGunfight.canMelee = true
    BridgeGunfight.suspended = true
    BridgeGunfight.reloadStage = nil
    BridgeGunfight.reloadUntil = nil
    BridgeGunfight.reloadStageAt = nil
    BridgeGunfight.reloadStageTicks = 0
    BridgeGunfight.reloadMagId = nil
    BridgeGunfight.reloadRoundsLeft = 0
    BridgeGunfight.reloadNeed = 0
    BridgeGunfight.reloadSavedRounds = 0
    BridgeGunfight.reloadBaseRounds = 0
    clearReloadSpeed(body)
    BridgeGunfight.recheckAt = (Bridge.time or 0) + OOA_RECHECK
    BridgeGunfight.state = "idle"
    BridgeGunfight.target = nil
    BridgeGunfight.blockSince = nil
    BridgeGunfight.stow(body)
    clearBump(body)
    if first then
        local source = false
        local usable = BridgeGunfight.gun ~= nil
            and (BridgeGunfight.gun.magazineType == nil or BridgeData.optionOf(Bridge.store, "gunMagCare"))
        if usable then
            pcall(function() source = BridgeGunRules.findAmmoBox(body, BridgeGunfight.gun) ~= nil end)
        end
        local home = false
        pcall(function() home = BridgeFetch ~= nil and type(BridgeFetch.hasAmmoStock) == "function" and BridgeFetch.hasAmmoStock(BridgeGunfight.gun) end)
        if not source and not home then pcall(function() BridgeCallout.outOfAmmo() end) end
    end
    log("out of ammo for " .. tostring(BridgeGunfight.gun and BridgeGunfight.gun.fullType or "?"))
    return false
end

local function beginReload(body, args)
    local gun = BridgeGunfight.gun
    if body == nil or gun == nil then return false end
    local external = args.external == true
    local base = tonumber(args.base) or tonumber(args.rounds) or 0
    local need = tonumber(args.needed) or 0
    if need < 0 then need = 0 end
    BridgeGunfight.reloadBaseRounds = base
    BridgeGunfight.reloadSavedRounds = base
    BridgeGunfight.reloadRoundsLeft = external and 1 or need
    BridgeGunfight.reloadNeed = need
    BridgeGunfight.reloadFamily = args.family or gun.reloadFamily
    BridgeGunfight.reloadVirtual = args.virtual == true
    BridgeGunfight.reloadClientAmmo = args.clientAmmo == true
    BridgeGunfight.reloadTaken = 0
    BridgeGunfight.noAmmoUntil = nil
    BridgeGunfight.rounds = base
    if BridgeGunfight.gunItem ~= nil then
        BridgeGunRules.setRounds(BridgeGunfight.gunItem, base, true)
    end
    BridgeGunfight.state = "reload"
    pcall(function() BridgeCallout.reloading(external) end)
    if external then
        local baseTicks = (gun.reloadFamily == "rifle") and RELOAD_UNLOAD_RIFLE or RELOAD_UNLOAD_HANDGUN
        setReloadStage(body, "unload", stageTicks(baseTicks))
    else
        local per = RELOAD_ROUND_RIFLE
        if gun.reloadFamily == "shotgun" then per = RELOAD_ROUND_SHOTGUN
        elseif gun.reloadFamily == "revolver" then per = RELOAD_ROUND_REVOLVER end
        local total = gun.insertAll and (per * math.max(1, need)) or per
        setReloadStage(body, "load", stageTicks(total))
    end
    return true
end


local function startReload(body, t, idle)
    if BridgeGunfight.reloadStage ~= nil then return true end
    if transferHoldsReload(body) then return false end
    if BridgeGunfight.reloadDoneAt ~= nil and (Bridge.time or 0) - BridgeGunfight.reloadDoneAt < 30 then
        return false
    end
    local gun = BridgeGunfight.gun
    if gun == nil or body == nil then return false end
    local rounds = BridgeGunfight.rounds or 0
    if BridgeGunfight.gunItem ~= nil then
        local actual = BridgeGunRules.roundsOf(BridgeGunfight.gunItem)
        if actual ~= rounds then
            rounds = actual
            BridgeGunfight.rounds = actual
        end
    end
    local maxAmmo = math.max(1, tonumber(gun.maxAmmo) or 1)
    if rounds > 0 then
        if idle ~= true then return false end
        if gun.magazineType ~= nil then
            if rounds > math.floor(maxAmmo * 0.25) then return false end
        elseif rounds >= maxAmmo then
            return false
        end
    end
    if t ~= nil and dist(body, t) < BridgeGunRules.MIN_RANGE then
        pcall(function() backpedal(body, t) end)
    end
    local external = gun.magazineType ~= nil
    local available = 0
    if external then
        local magazine, count = BridgeGunRules.findLoadedMagazine(body, gun)
        if magazine == nil then return outOfAmmo(body) end
        if rounds > 0 and count <= rounds then return false end
        BridgeGunfight.reloadMagId = magazine:getID()
        BridgeGunfight.reloadRoundsLeft = 1
        BridgeGunfight.reloadNeed = count
        available = count
    else
        local _, total = BridgeGunRules.findLooseRounds(body, gun, maxAmmo)
        if total <= 0 then return outOfAmmo(body) end
        available = math.min(total, math.max(1, maxAmmo - rounds))
        if available <= 0 then return false end
        BridgeGunfight.reloadMagId = nil
        BridgeGunfight.reloadRoundsLeft = available
        BridgeGunfight.reloadNeed = available
    end
    BridgeGunfight.reloadSavedRounds = rounds
    BridgeGunfight.reloadBaseRounds = rounds
    BridgeGunfight.reloadFamily = gun.reloadFamily
    BridgeGunfight.reloadCancel = false
    BridgeGunfight.reloadStartedAt = Bridge.time
    applyReloadSpeed(body, reloadFactor())
    if Bridge ~= nil and Bridge.mp then
        BridgeGunfight.reloadStage = "wait"
        BridgeGunfight.reloadUntil = (Bridge.time or 0) + 180
        BridgeGunfight.state = "reload"
        tellReload("start", { rounds = available, available = available, external = external,
            idle = idle == true, saved = rounds })
    else
        if external then
            local base = (gun.reloadFamily == "rifle") and RELOAD_UNLOAD_RIFLE or RELOAD_UNLOAD_HANDGUN
            setReloadStage(body, "unload", stageTicks(base))
        else
            local per = RELOAD_ROUND_RIFLE
            if gun.reloadFamily == "shotgun" then per = RELOAD_ROUND_SHOTGUN
            elseif gun.reloadFamily == "revolver" then per = RELOAD_ROUND_REVOLVER end
            local total = gun.insertAll and (per * math.max(1, available)) or per
            setReloadStage(body, "load", stageTicks(total))
        end
        pcall(function() BridgeCallout.reloading(gun.magazineType ~= nil) end)
        BridgeGunfight.state = "reload"
    end
    log(string.format("reload start %s family=%s need=%d rounds=%d", tostring(gun.fullType),
        tostring(gun.reloadFamily), available, BridgeGunfight.rounds or 0))
    return true
end

local function advanceReload(body)
    local stage = BridgeGunfight.reloadStage
    local gun = BridgeGunfight.gun
    if stage == nil or gun == nil then return false end
    local mp = Bridge ~= nil and Bridge.mp
    local virtual = mp and BridgeGunfight.reloadVirtual == true
    local clientAmmo = mp and BridgeGunfight.reloadClientAmmo == true
    if stage == "unload" then
        if not mp or virtual then
            local hasClip = false
            if BridgeGunfight.gunItem ~= nil then
                pcall(function() hasClip = BridgeGunfight.gunItem:isContainsClip() == true end)
            end
            if hasClip or (BridgeGunfight.reloadSavedRounds or 0) > 0 then
                local stashed = BridgeGunRules.stashMagazine(body, gun, BridgeGunfight.reloadSavedRounds or 0)
                if stashed ~= nil then
                    log(string.format("reload: ejected magazine id=%s rounds=%d",
                        tostring(stashed:getID()), BridgeGunRules.roundsOf(stashed)))
                end
            end
            if BridgeGunfight.gunItem ~= nil then
                BridgeGunRules.setRounds(BridgeGunfight.gunItem, 0, false)
            end
            BridgeGunfight.rounds = 0
        end
        local base = (gun.reloadFamily == "rifle") and RELOAD_LOAD_RIFLE or RELOAD_LOAD_HANDGUN
        setReloadStage(body, "load", stageTicks(base))
        return true
    end
    if stage == "load" then
        if gun.magazineType ~= nil then
            if not mp or virtual then
                local magazine = nil
                if BridgeGunfight.reloadMagId ~= nil then
                    pcall(function() magazine = BridgeGunRules.findItemById(body, BridgeGunfight.reloadMagId) end)
                end
                if magazine == nil then
                    cancelReload(body, "magazine gone")
                    return outOfAmmo(body)
                end
                local magId, magRounds, magCap, magType = nil, 0, 0, nil
                pcall(function() magId = magazine:getID() end)
                pcall(function() magType = magazine:getFullType() end)
                pcall(function() magCap = math.floor(tonumber(magazine:getMaxAmmo()) or 0) end)
                magRounds = BridgeGunRules.roundsOf(magazine)
                BridgeGunfight.rounds = BridgeGunRules.insertMagazine(body, BridgeGunfight.gunItem, magazine, gun)
                if magCap > 0 then
                    BridgeGunfight.maxAmmo = magCap
                    if gun ~= nil then gun.maxAmmo = magCap end
                    if BridgeGunfight.gunItem ~= nil then
                        pcall(function() BridgeGunfight.gunItem:setMaxAmmo(magCap) end)
                    end
                end
                if magType ~= nil then
                    if gun ~= nil then gun.magazineType = magType end
                    if BridgeGunfight.gunItem ~= nil then
                        pcall(function() BridgeGunfight.gunItem:setMagazineType(magType) end)
                    end
                end
                log(string.format("reload: inserted magazine id=%s type=%s rounds=%d cap=%d",
                    tostring(magId), tostring(magType or "-"), magRounds, magCap))
            end
            BridgeGunfight.reloadMagId = nil
            local base = (gun.reloadFamily == "rifle") and RELOAD_RACK_RIFLE or RELOAD_RACK_HANDGUN
            setReloadStage(body, "rack", stageTicks(base))
            return true
        end
        local got = 0
        if not mp or clientAmmo then
            local removed = BridgeGunRules.removeOneLooseRound(body, gun)
            if removed == nil then
                cancelReload(body, "no rounds left")
                return outOfAmmo(body)
            end
            got = 1
            BridgeGunfight.rounds = (BridgeGunfight.rounds or 0) + 1
            BridgeGunfight.reloadTaken = (BridgeGunfight.reloadTaken or 0) + 1
            if mp then tellLoadOne(removed) end
        else
            got = 1
        end
        BridgeGunfight.reloadRoundsLeft = math.max(0, (BridgeGunfight.reloadRoundsLeft or 0) - got)
        if BridgeSkills ~= nil and got > 0 then
            pcall(function() BridgeSkills.add("Reloading", got, "round") end)
        end
        local maxAmmo = tonumber(BridgeGunfight.maxAmmo) or 0
        if maxAmmo > 0 and BridgeGunfight.rounds > maxAmmo then BridgeGunfight.rounds = maxAmmo end
        if (not mp or clientAmmo) and BridgeGunfight.gunItem ~= nil then
            BridgeGunRules.setRounds(BridgeGunfight.gunItem, BridgeGunfight.rounds or 0, true)
        end
        if BridgeGunfight.reloadRoundsLeft > 0 then
            local per = RELOAD_ROUND_RIFLE
            if gun.reloadFamily == "shotgun" then per = RELOAD_ROUND_SHOTGUN
            elseif gun.reloadFamily == "revolver" then per = RELOAD_ROUND_REVOLVER end
            setReloadStage(body, "load", stageTicks(per))
            return true
        end
        if (not mp or clientAmmo) and BridgeGunfight.rounds <= 0 then
            cancelReload(body, "no rounds loaded")
            return outOfAmmo(body)
        end
        if mp and not virtual and got <= 0 then
            cancelReload(body, "no rounds loaded")
            return outOfAmmo(body)
        end
        local base = (gun.reloadFamily == "rifle_nomag") and RELOAD_RACK_RIFLE or RELOAD_RACK_HANDGUN
        if gun.reloadFamily == "shotgun" or gun.reloadFamily == "revolver" then base = RELOAD_RACK_HANDGUN end
        setReloadStage(body, "rack", stageTicks(base))
        return true
    end
    if stage == "rack" then
        return finishReload(body)
    end
    return finishReload(body)
end

local function reloadTick(body)
    if BridgeGunfight.reloadStage == nil then return false end
    if BridgeGunfight.reloadStage == "wait" then
        if (Bridge.time or 0) >= (BridgeGunfight.reloadUntil or 0) then
            cancelReload(body, "server start timeout")
            return false
        end
        return true
    end
    local done = actionElapsed(BridgeGunfight.reloadStageAt, BridgeGunfight.reloadStageTicks)
    if not done then
        local fin = false
        pcall(function() fin = body:getVariableBoolean(FIRE_VAR) == true end)
        if fin then done = true end
    end
    if not done then
        plant(body, bumpName(BridgeGunfight.reloadStage, BridgeGunfight.reloadFamily))
        return true
    end
    if Bridge ~= nil and Bridge.verbose and BridgeGunfight.reloadStageAt ~= nil then
        local real = (Bridge.time or 0) - BridgeGunfight.reloadStageAt
        vlog(string.format("reload stage %s done real=%.1f eff=%.1f",
            tostring(BridgeGunfight.reloadStage), real, real * speedMult()))
    end
    return advanceReload(body)
end


function BridgeGunfight.fastForwardTick(body)
    if Bridge == nil or Bridge.mp or body == nil then return false end
    if BridgeGunfight.body ~= nil and BridgeGunfight.body ~= body then return false end
    if BridgeGunfight.reloadStage ~= nil then
        if BridgeGunfight.reloadStage == "wait" then return false end
        return reloadTick(body)
    end
    if BridgeGunfight.ammoItem ~= nil then
        return ammoOpenTick(body)
    end
    if BridgeGunfight.magCareStage ~= nil then
        return advanceMagCare(body, BridgeGunfight.gun)
    end
    return false
end


function BridgeGunfight.update(body)
    BridgeGunfight.canMelee = false
    if body == nil then return false end
    if Bridge.body ~= nil and body ~= Bridge.body then
        BridgeGunfight.body = nil
        return false
    end
    BridgeGunfight.body = body
    if BridgeGunfight.assignedId == nil then return false end
    local item = BridgeGunfight.assignedItem(body)
    if item == nil then
        local gone = BridgeGunfight.gunItem
        BridgeGunfight.gunItem = nil
        BridgeGunfight.drawn = false
        if gone ~= nil then
            pcall(function()
                if body:getPrimaryHandItem() == gone then body:setPrimaryHandItem(nil) end
                if body:getSecondaryHandItem() == gone then body:setSecondaryHandItem(nil) end
                body:resetEquippedHandsModels()
            end)
            if BridgeGunfight.attached ~= nil and BridgeGunfight.attached.item == gone then
                detachGun(body)
                refresh(body)
            end
        end
        BridgeGunfight.missingSince = BridgeGunfight.missingSince or Bridge.time
        if Bridge.time - BridgeGunfight.missingSince >= 900 then
            BridgeGunfight.unassign(body, "gun gone or broken")
        end
        BridgeGunfight.canMelee = true
        BridgeGunfight.info = "gun missing"
        return false
    end
    BridgeGunfight.missingSince = nil
    if (BridgeGunfight.maxAmmo or 0) <= 0 and BridgeGunfight.gun ~= nil then
        BridgeGunfight.maxAmmo = tonumber(BridgeGunfight.gun.maxAmmo) or 0
    end
    local red = BridgeData.owner()
    if red == nil then return false end

    local mode = BridgeFight.mode()
    local allows = mode ~= nil and not mode.passive and (tonumber(mode.gunRangePct) or 0) > 0
    BridgeGunfight.modeRange = 0
    if allows and BridgeGunfight.gun ~= nil then
        BridgeGunfight.modeRange = BridgeGunRules.effectiveRange(BridgeGunfight.gun, aimingLevel())
            * (tonumber(mode.gunRangePct) or 0)
        if BridgeGunfight.modeRange < 1 then BridgeGunfight.modeRange = 0 end
    end

    if BridgeGunfight.reloadStage ~= nil then
        if BridgeMove ~= nil then BridgeMove.forcedWalk = "Walk" end
        if dist(body, red) > (tonumber(mode and mode.leash) or 999) then
            cancelReload(body, "player far")
            BridgeGunfight.target = nil
            if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
            BridgeGunfight.state = "idle"
            BridgeGunfight.info = "reload cancelled: player far"
            return false
        end
        if meleeThreat(body) ~= nil then
            cancelReload(body, "melee threat")
            BridgeGunfight.stow(body)
            BridgeGunfight.stance = "melee"
            BridgeGunfight.meleeClearAt = nil
            BridgeGunfight.canMelee = true
            BridgeGunfight.target = nil
            BridgeGunfight.state = "idle"
            BridgeGunfight.info = "melee threat during reload"
            return false
        end
        local busy = reloadTick(body)
        if not busy and BridgeMove ~= nil then BridgeMove.forcedWalk = nil end
        return false
    end

    if BridgeGunfight.ammoItem ~= nil then
        if BridgeMove ~= nil then BridgeMove.forcedWalk = "Walk" end
        local cancel = nil
        if dist(body, red) > (tonumber(mode and mode.leash) or 999) then
            cancel = "player far"
        elseif meleeThreat(body) ~= nil then
            cancel = "melee threat"
        end
        if cancel ~= nil then
            BridgeGunfight.ammoItem, BridgeGunfight.ammoOut, BridgeGunfight.ammoAmount = nil, nil, 0
            BridgeGunfight.ammoUntil = nil
            BridgeGunfight.ammoStageAt = nil
            BridgeGunfight.ammoStageTicks = 0
            BridgeGunfight.ammoCooldown = (Bridge.time or 0) + 60
            magCareEnd(body)
            if BridgeWeapon ~= nil then pcall(function() BridgeWeapon.lost = nil end) end
            if cancel == "melee threat" then
                BridgeGunfight.stow(body)
                BridgeGunfight.stance = "melee"
                BridgeGunfight.canMelee = true
            end
            BridgeGunfight.state = "idle"
            BridgeGunfight.info = "ammo open cancelled: " .. cancel
            if BridgeMove ~= nil then BridgeMove.forcedWalk = nil end
            return false
        end
        local busy = ammoOpenTick(body)
        if not busy and BridgeMove ~= nil then BridgeMove.forcedWalk = nil end
        return false
    end

    local idleScan = false
    if BridgeGunfight.idleScanAt == nil or (Bridge.time - BridgeGunfight.idleScanAt) >= 30 then
        idleScan = true
        BridgeGunfight.idleScanAt = Bridge.time
    end

    if idleScan and BridgeGunfight.gun ~= nil and BridgeGunfight.gun.magazineType ~= nil
        and BridgeData.optionOf(Bridge.store, "gunMagCare")
        and (BridgeFight == nil or BridgeFight.target == nil)
        and BridgeGunfight.state == "idle"
        and (BridgeTask == nil or not BridgeTask.active) then
        local _, loose = BridgeGunRules.findLooseRounds(body, BridgeGunfight.gun, 1)
        if loose <= 0 and (BridgeGunRules.findPartialMagazine(body, BridgeGunfight.gun) ~= nil
            or refillNeed(body, BridgeGunfight.gun) > 0) then
            homeAmmo(body)
        end
    end

    local care = false
    if BridgeGunfight.magCareStage ~= nil or idleScan then
        pcall(function() care = magazineCare(body, BridgeGunfight.gun) == true end)
    end
    if care then
        BridgeGunfight.canMelee = true
        BridgeGunfight.state = "idle"
        return false
    end

    local use = BridgeData.gunUseOf(Bridge.store)
    if use == "off" then
        if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
        BridgeGunfight.stance = "melee"
        BridgeGunfight.canMelee = true
        BridgeGunfight.target = nil
        BridgeGunfight.state = "idle"
        BridgeGunfight.info = "gun use off"
        return false
    end

    if BridgeGunfight.suspended then
        if BridgeGunfight.noAmmoUntil ~= nil and Bridge.time < BridgeGunfight.noAmmoUntil then
            BridgeGunfight.canMelee = true
            BridgeGunfight.stance = "melee"
            BridgeGunfight.info = "out of ammo"
            return false
        end
        if Bridge.time < (BridgeGunfight.recheckAt or 0) then
            BridgeGunfight.canMelee = true
            BridgeGunfight.info = "out of ammo"
            return false
        end
        BridgeGunfight.recheckAt = Bridge.time + OOA_RECHECK
        BridgeGunfight.rounds = BridgeGunRules.roundsOf(item)
        if BridgeGunfight.rounds <= 0 and not BridgeGunfight.hasAmmo(body) then
            if startAmmoOpen(body) then return false end
            if BridgeFight.target == nil and homeAmmo(body) then return false end
            BridgeGunfight.canMelee = true
            BridgeGunfight.info = "out of ammo"
            return false
        end
        if BridgeFight.target == nil and startAmmoOpen(body) then return false end
        if BridgeFight.target == nil and homeAmmo(body) then return false end
        BridgeGunfight.suspended = false
        BridgeGunfight.lowSaid = false
        log("ammo available, re-arming")
    end

    if not allows then
        if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
        BridgeGunfight.stance = "melee"
        BridgeGunfight.canMelee = true
        BridgeGunfight.suspended = true
        BridgeGunfight.recheckAt = Bridge.time + OOA_RECHECK
        BridgeGunfight.target = nil
        BridgeGunfight.state = "idle"
        BridgeGunfight.info = "guns off for this mode"
        return false
    end

    if dist(body, red) > (tonumber(mode.leash) or 999) then
        BridgeGunfight.target = nil
        if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
        BridgeGunfight.state = "idle"
        BridgeGunfight.info = "player far"
        return false
    end

    local reserve = BridgeData.ammoReserveOf(Bridge.store)
    local reserveBlocked, reserveN, reserveNeed = false, 0, 0
    if reserve ~= "free" then
        reserveN = reserveNear(body)
        reserveNeed = reserve == "conserve" and 4 or 13
        reserveBlocked = reserveN < reserveNeed




        if reserveBlocked and idleScan and BridgeGunfight.target == nil
            and (BridgeFight == nil or BridgeFight.target == nil) then
            if BridgeGunfight.gun ~= nil and BridgeGunfight.gun.magazineType ~= nil
                and startAmmoOpen(body) then return false end

            if idleReloadWanted(body, BridgeGunfight.gun) then
                if not BridgeGunfight.drawn then BridgeGunfight.draw(body) end
                if BridgeGunfight.drawn and startReload(body, nil, true) then return true end
            end

            if (BridgeGunfight.gun == nil or BridgeGunfight.gun.magazineType == nil)
                and startAmmoOpen(body) then return false end
        end
    end
    if reserveBlocked then
        if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
        BridgeGunfight.stance = "melee"
        BridgeGunfight.meleeClearAt = nil
        BridgeGunfight.meleeFallback = true
        BridgeGunfight.canMelee = true
        BridgeGunfight.target = nil
        BridgeGunfight.state = "idle"
        BridgeGunfight.info = string.format("ammo reserve %s: %d/%d", reserve, reserveN, reserveNeed)
        return false
    end
    BridgeGunfight.meleeFallback = false

    local gunLocked = BridgeGunfight.lastGunAt ~= nil
        and (Bridge.time or 0) - BridgeGunfight.lastGunAt < GUN_TO_MELEE
    local threat = meleeThreat(body)
    if threat ~= nil and not gunLocked then
        if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
        BridgeGunfight.stance = "melee"
        BridgeGunfight.meleeClearAt = nil
        BridgeGunfight.meleeFallback = true
        BridgeGunfight.canMelee = true
        BridgeGunfight.target = nil
        BridgeGunfight.state = "idle"
        BridgeGunfight.info = "melee threat"
        return false
    end
    if (BridgeGunfight.rounds or 0) <= 0 and BridgeGunfight.hasAmmo(body)
        and BridgeFight.state ~= "swing" then
        BridgeGunfight.stance = nil
        BridgeGunfight.meleeClearAt = nil
        BridgeGunfight.suspended = false
        BridgeGunfight.noAmmoUntil = nil
        if not BridgeGunfight.drawn then BridgeGunfight.draw(body) end
        if BridgeGunfight.drawn and startReload(body, nil, true) then return true end
    end
    if BridgeGunfight.stance == "melee" then
        if meleeReleaseReady(body) and swingRecoveryReady() and not gunLocked then
            BridgeGunfight.stance = nil
        else
            if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
            BridgeGunfight.meleeFallback = true
            BridgeGunfight.canMelee = true
            BridgeGunfight.target = nil
            BridgeGunfight.state = "idle"
            BridgeGunfight.info = "holding melee"
            return false
        end
    end
    if not swingRecoveryReady() then
        if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
        BridgeGunfight.stance = "melee"
        BridgeGunfight.meleeFallback = true
        BridgeGunfight.canMelee = true
        BridgeGunfight.target = nil
        BridgeGunfight.state = "idle"
        BridgeGunfight.info = "melee recovery"
        return false
    end

    if BridgeGunfight.target ~= nil or BridgeGunfight.drawn then Bridge.holdPos = nil end

    local hand = nil
    pcall(function() hand = body:getPrimaryHandItem() end)
    if hand == item then
        BridgeGunfight.drawn = true
        BridgeGunfight.meleeFallback = false
        BridgeGunfight.stance = "gun"
        if Bridge.time - (BridgeGunfight.handSyncAt or 0) >= 30 then
            BridgeGunfight.handSyncAt = Bridge.time
            pcall(function() body:resetEquippedHandsModels() end)
        end
    elseif BridgeGunfight.drawn then
        BridgeGunfight.draw(body)
    end

    if BridgeGunfight.fireUntil ~= nil then
        local fin = false
        pcall(function() fin = body:getVariableBoolean(FIRE_VAR) == true end)
        if fin or Bridge.time >= BridgeGunfight.fireUntil then
            BridgeGunfight.fireUntil = nil
            pcall(function() body:setVariable(FIRE_VAR, false) end)
        end
    end

    local t = BridgeGunfight.target
    local pick = (Bridge.time - (BridgeGunfight.lastPick or 0)) >= RECHECK
    if t ~= nil and pick and not validTarget(t, body, red) then
        local lost = "body"
        pcall(function() lost = tostring(t:getType()) end)
        vlog("target lost: " .. lost)
        t = nil
        BridgeGunfight.target = nil
        BridgeGunfight.state = "idle"
        BridgeGunfight.stowAt = Bridge.time + STOW_TICKS
    end
    if t == nil and pick then
        BridgeGunfight.lastPick = Bridge.time
        t = pickTarget(body, red)
        if t ~= nil then
            if BridgeGunfight.peek ~= nil then
                BridgeGunfight.peek = nil
                pcall(function() if BridgeMove.onPath() then BridgeMove.stopPath(body) end end)
                BridgeMove.moving = false
                BridgeMove.steering = false
            end
            BridgeGunfight.target = t
            BridgeGunfight.lastTargetAt = Bridge.time
            BridgeGunfight.stowAt = nil
            local aim = BridgeGunRules.aimTicks(BridgeGunfight.gun, aimingLevel())
            BridgeGunfight.aimUntil = Bridge.time + aim
            BridgeGunfight.nextShotAt = BridgeGunfight.aimUntil
            BridgeGunfight.state = "aim"
            vlog(string.format("target acquired d=%.1f aim=%d ticks", dist(body, t), aim))
        end
    end

    if t == nil then
        stopReposition(body)
        local gunUse = BridgeData.gunUseOf(Bridge.store)

        local f = BridgeFight.target
        local meleeHold = false
        if f ~= nil and not gunLocked and swingRecoveryReady() and gunUse ~= "off"
            and BridgeData.optionOf(Bridge.store, "gunMelee") and meleeReady(body) then
            local alive = false
            pcall(function() alive = f:isAlive() and f:getHealth() > 0 end)
            meleeHold = alive and dist(body, f) <= BridgeGunRules.MIN_RANGE
        end
        if meleeHold then
            if BridgeGunfight.peek ~= nil then
                BridgeGunfight.peek = nil
                if BridgeMove ~= nil then
                    BridgeMove.moving = false
                    BridgeMove.steering = false
                    pcall(function() if BridgeMove.onPath() then BridgeMove.stopPath(body) end end)
                end
            end
            if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
            BridgeGunfight.stance = "melee"
            BridgeGunfight.meleeClearAt = nil
            BridgeGunfight.canMelee = true
            BridgeGunfight.target = nil
            BridgeGunfight.state = "idle"
            BridgeGunfight.info = "melee switch"
            return false
        end

        if idleScan and BridgeGunfight.gun ~= nil and BridgeGunfight.gun.magazineType ~= nil
            and startAmmoOpen(body) then return false end

        if idleScan and idleReloadWanted(body, BridgeGunfight.gun) then
            if not BridgeGunfight.drawn then BridgeGunfight.draw(body) end
            if BridgeGunfight.drawn and startReload(body, nil, true) then return true end
        end

        if idleScan and (BridgeGunfight.gun == nil or BridgeGunfight.gun.magazineType == nil)
            and startAmmoOpen(body) then return false end

        if homeAmmo(body) then return false end

        local hasGunAmmo = (BridgeGunfight.rounds or 0) > 0 or BridgeGunfight.hasAmmo(body)
        if hasGunAmmo and peekTick(body, red) then
            BridgeGunfight.canMelee = false
            BridgeGunfight.state = "peek"
            BridgeGunfight.info = "peeking for a line"
            return true
        end

        if BridgeGunfight.readyAmmo(body) then
            if not BridgeGunfight.drawn then BridgeGunfight.draw(body) end
            clearBump(body)
            BridgeGunfight.canMelee = false
            BridgeGunfight.stowAt = nil
            BridgeGunfight.state = "idle"
            BridgeGunfight.info = string.format("%s following rounds=%d shots=%d hits=%d",
                tostring(item:getType()), BridgeGunfight.rounds or 0, BridgeGunfight.shots, BridgeGunfight.hits)
            return false
        end

        return outOfAmmo(body)
    end

    if (BridgeGunfight.rounds or 0) <= 0 then
        if BridgeGunfight.hasAmmo(body) then
            if not BridgeGunfight.drawn then BridgeGunfight.draw(body) end
            if BridgeGunfight.drawn and startReload(body, t, false) then return true end
            BridgeGunfight.canMelee = true
            return false
        end
        if startAmmoOpen(body) then return false end
        return outOfAmmo(body)
    end

    pcall(function() body:faceLocationF(t:getX(), t:getY()) end)

    local d = dist(body, t)
    if d <= BridgeGunRules.MIN_RANGE and not gunLocked and swingRecoveryReady()
        and BridgeData.optionOf(Bridge.store, "gunMelee") and meleeReady(body) then
        local meleeReach = BridgeFight.reachable ~= nil and BridgeFight.reachable(body, t)
        if not meleeReach then
            BridgeGunfight.info = "melee switch skipped: not reachable"
        else
            if BridgeGunfight.drawn then BridgeGunfight.stow(body) end
            BridgeGunfight.canMelee = true
            BridgeGunfight.target = nil
            BridgeGunfight.state = "idle"
            BridgeGunfight.info = "melee switch"
            return false
        end
    end
    if not BridgeGunfight.drawn then BridgeGunfight.draw(body) end
    local retreat = false
    if d < BridgeGunRules.MIN_RANGE then retreat = backpedal(body, t) end
    BridgeGunfight.moving = retreat
    BridgeGunfight.state = retreat and "backstep" or "aim"

    if (BridgeGunfight.rounds or 0) <= 0 then
        if BridgeGunfight.reposition ~= nil then stopReposition(body) end
        BridgeGunfight.blockSince = nil
        BridgeGunfight.reposSide = nil
        if d < BridgeGunRules.MIN_RANGE and retreat then
            BridgeGunfight.info = "backstep before reload"
            return true
        end
        local started = startReload(body, t, false)
        if started then return true end
        return false
    end

    local why, blocker = blockedBy(body, t)
    if why ~= nil then
        if why == "player" then pcall(function() BridgeCallout.lineOfFire() end) end
        BridgeGunfight.state = "sidestep"
        if BridgeGunfight.blockAt == nil or Bridge.time - BridgeGunfight.blockAt >= 60 then
            BridgeGunfight.blockAt = Bridge.time
            vlog("hold fire: " .. why .. " in the line")
        end
        local moved = repositionTick(body, t, blocker)
        if moved then
            BridgeGunfight.blockSince = nil
        else
            BridgeGunfight.blockSince = BridgeGunfight.blockSince or Bridge.time
        end
        BridgeGunfight.info = (moved and "sidestep " or "hold fire: ") .. why
        if not moved and Bridge.time - (BridgeGunfight.blockSince or Bridge.time) > 300 then
            vlog("gave up: " .. why .. " in the line for 5 s")
            BridgeGunfight.target = nil
            BridgeGunfight.stowAt = Bridge.time + STOW_TICKS
            BridgeGunfight.blockSince = nil
            BridgeGunfight.reposSide = nil
        end
        return true
    end
    if BridgeGunfight.reposition ~= nil then stopReposition(body) end
    BridgeGunfight.blockSince = nil
    BridgeGunfight.reposSide = nil

    if BridgeGunfight.fireUntil == nil then
        local kind = BridgeGunfight.gun.kind or "Handgun"
        plant(body, (retreat and "NA_Backstep" or "NA_Aim") .. kind)
    end

    if Bridge.time < (BridgeGunfight.aimUntil or 0) then
        BridgeGunfight.info = string.format("%s aiming d=%.1f in %d", tostring(item:getType()), d,
            math.max(0, (BridgeGunfight.aimUntil or 0) - Bridge.time))
        return true
    end
    if Bridge.time < (BridgeGunfight.nextShotAt or 0) then
        BridgeGunfight.info = string.format("%s ready d=%.1f in %d", tostring(item:getType()), d,
            math.max(0, (BridgeGunfight.nextShotAt or 0) - Bridge.time))
        return true
    end

    local nowT = Bridge.time
    local cachedBlock = BridgeGunfight.lineTarget == t
        and BridgeGunfight.lineOk ~= true
        and BridgeGunfight.lineAt ~= nil
        and nowT - BridgeGunfight.lineAt < 6
    local clear = false
    if not cachedBlock then
        pcall(function()
            clear = BridgeGunRules.fireLineClear(getCell(), body:getX(), body:getY(), body:getZ(),
                t:getX(), t:getY(), t:getZ()) == true
        end)
        BridgeGunfight.lineTarget, BridgeGunfight.lineAt, BridgeGunfight.lineOk = t, nowT, clear
    end
    if not clear then
        BridgeGunfight.info = "hold fire: no line"
        return true
    end

    if not BridgeGunRules.valid(item) then
        BridgeGunfight.canMelee = true
        BridgeGunfight.unassign(body, "gun became unusable")
        return false
    end

    if BridgeGunfight.reloadStage ~= nil then return true end
    if d > (BridgeGunfight.modeRange or 0) + 0.9 then
        BridgeGunfight.info = "out of mode range"
        return true
    end

    fire(body)
    return true
end


local function extraTarget(e)
    if type(e) ~= "table" then return nil end
    local found = nil
    local eid = tonumber(e.id)
    if eid ~= nil and eid ~= 0 then
        pcall(function()
            local list = getCell():getZombieList()
            for i = 0, list:size() - 1 do
                local z = list:get(i)
                if z ~= nil then
                    local oid = nil
                    pcall(function() oid = z:getOnlineID() end)
                    if oid == eid then found = z break end
                end
            end
        end)
    end
    if found == nil then
        local ex, ey, ez = tonumber(e.x), tonumber(e.y), tonumber(e.z)
        if ex ~= nil and ey ~= nil then
            pcall(function()
                local list = getCell():getZombieList()
                for i = 0, list:size() - 1 do
                    local z = list:get(i)
                    if z ~= nil and (ez == nil or math.abs(z:getZ() - ez) < 0.8)
                        and BridgeGunRules.dist2(z:getX(), z:getY(), ex, ey) <= 1.2 then
                        found = z
                        break
                    end
                end
            end)
        end
    end
    return found
end


function BridgeGunfight.onResult(args)
    local pending = BridgeGunfight.pendingShot
    BridgeGunfight.pendingShot = nil
    if type(args) ~= "table" then return end
    if args.ok == false then
        if args.rounds ~= nil then
            BridgeGunfight.rounds = math.max(0, math.floor(tonumber(args.rounds) or 0))
            if BridgeGunfight.gunItem ~= nil then
                BridgeGunRules.setRounds(BridgeGunfight.gunItem, BridgeGunfight.rounds, true)
            end
        end
        local why = tostring(args.why or "?")
        log("shot rejected: " .. why)
        BridgeGunfight.info = "rejected: " .. why
        if why == "out of ammo" then
            local first = BridgeGunfight.suspended ~= true
            BridgeGunfight.rounds = 0
            BridgeGunfight.canMelee = true
            BridgeGunfight.suspended = true
            BridgeGunfight.stance = "melee"
            BridgeGunfight.noAmmoUntil = (Bridge.time or 0) + 180
            BridgeGunfight.recheckAt = (Bridge.time or 0) + OOA_RECHECK
            if BridgeGunfight.drawn then BridgeGunfight.stow(BridgeGunfight.body) end
            clearBump(BridgeGunfight.body)
            if first then
                local source = false
                local usable = BridgeGunfight.gun ~= nil
                    and (BridgeGunfight.gun.magazineType == nil or BridgeData.optionOf(Bridge.store, "gunMagCare"))
                if usable and BridgeGunfight.body ~= nil then
                    pcall(function() source = BridgeGunRules.findAmmoBox(BridgeGunfight.body, BridgeGunfight.gun) ~= nil end)
                end
                local home = false
                pcall(function() home = BridgeFetch ~= nil and type(BridgeFetch.hasAmmoStock) == "function" and BridgeFetch.hasAmmoStock(BridgeGunfight.gun) end)
                if not source and not home then pcall(function() BridgeCallout.outOfAmmo() end) end
            end
        elseif why == "reloading" then
            BridgeGunfight.reloadStage = nil
            BridgeGunfight.reloadUntil = nil
            BridgeGunfight.reloadStageAt = nil
            BridgeGunfight.reloadStageTicks = 0
            BridgeGunfight.suspended = false
            BridgeGunfight.noAmmoUntil = nil
            BridgeGunfight.recheckAt = (Bridge.time or 0) + 20
            pcall(function() tellReload("cancel", {}) end)
            BridgeGunfight.info = "reload desync: cancel sent"
        elseif why == "gun missing" or why == "no primary gun" then
            BridgeGunfight.canMelee = true
            BridgeGunfight.suspended = true
            BridgeGunfight.recheckAt = (Bridge.time or 0) + 600
            pcall(function() BridgeGunfight.stow(BridgeGunfight.body) end)
        end
        return
    end
    if args.rounds ~= nil then
        BridgeGunfight.rounds = math.max(0, math.floor(tonumber(args.rounds) or 0))
        if BridgeGunfight.gunItem ~= nil then
            BridgeGunRules.setRounds(BridgeGunfight.gunItem, BridgeGunfight.rounds, true)
        end
    else
        BridgeGunfight.rounds = math.max(0, (BridgeGunfight.rounds or 1) - 1)
    end
    if BridgeSkills ~= nil then
        pcall(function() BridgeSkills.add("Aiming", 0.5, "shot") end)
        if args.hit == true then pcall(function() BridgeSkills.add("Aiming", 1, "hit") end) end
    end
    if args.hit == true then BridgeGunfight.hits = BridgeGunfight.hits + 1 end
    local dmg = tonumber(args.damage)
    local hp = tonumber(args.hpAfter)
    local target = pending ~= nil and pending.target or nil
    if target ~= nil then
        local dead = false
        pcall(function() dead = target:isDead() or target:getHealth() <= 0 end)
        local gun = BridgeGunfight.gun or {}
        if args.hit == true and not dead then
            local reaction = type(args.reaction) == "string" and args.reaction or "ShotBelly"
            pcall(function() target:setHitReaction(reaction) end)
            pcall(function() target:setStaggerBack(true) end)
            pcall(function() target:playSound(gun.hitSound or "ZombieHit") end)
            hitBlood(target)
        elseif args.hit ~= true then
            pcall(function()
                local sq = target:getSquare()
                if sq ~= nil then sq:playSound(gun.impactSound or "BulletImpact") end
            end)
        end
        if dead and args.hit == true then
            pcall(function() BridgeCallout.gunKill(target) end)
        end
    end
    checkLowAmmo()
    log(string.format("shot result hit=%s dmg=%s hp=%s->%s", tostring(args.hit == true),
        tostring(dmg and string.format("%.2f", dmg) or "-"),
        tostring(tonumber(args.hpBefore) or "-"), tostring(hp and string.format("%.2f", hp) or "-")))
    BridgeGunfight.info = string.format("result hit=%s dmg=%s", tostring(args.hit == true),
        tostring(dmg and string.format("%.1f", dmg) or "-"))

    local extras = args.extras
    if type(extras) == "table" then
        local gun = BridgeGunfight.gun or {}
        local extraHits, extraKills = 0, 0
        for _, e in ipairs(extras) do
            if type(e) == "table" and e.hit == true then
                local z = extraTarget(e)
                if z ~= nil then
                    local reaction = type(e.reaction) == "string" and e.reaction or "ShotBelly"
                    pcall(function() z:setHitReaction(reaction) end)
                    pcall(function() z:setStaggerBack(true) end)
                    pcall(function() z:playSound(gun.hitSound or "ZombieHit") end)
                    hitBlood(z)
                    BridgeGunfight.hits = BridgeGunfight.hits + 1
                    extraHits = extraHits + 1
                    if e.killed == true then
                        extraKills = extraKills + 1
                        pcall(function() if BridgeKills ~= nil then BridgeKills.credit(z) BridgeKills.confirm(z) end end)
                    end
                end
            end
        end
        log(string.format("shot extras n=%d hits=%d kills=%d", #extras, extraHits, extraKills))
        if extraHits > 0 then
            if args.hit ~= true then
                BridgeGunfight.info = string.format("miss primary, extras hit=%d", extraHits)
            else
                BridgeGunfight.info = string.format("result hit dmg=%s extras=%d kills=%d",
                    tostring(dmg and string.format("%.1f", dmg) or "-"), extraHits, extraKills)
            end
        end
    end
    if pending ~= nil then BridgeGunfight.lastShotAt = Bridge.time end
end


function BridgeGunfight.onReloadResult(args)
    if type(args) ~= "table" then return end
    local action = tostring(args.action or "")
    if args.ok == false then
        local why = tostring(args.why or "?")
        log("reload rejected: " .. why)
        BridgeGunfight.info = "reload rejected: " .. why
        if action == "start" then
            BridgeGunfight.reloadStage = nil
            BridgeGunfight.reloadUntil = nil
            BridgeGunfight.reloadStageAt = nil
            BridgeGunfight.reloadStageTicks = 0
            BridgeGunfight.reloadMagId = nil
            BridgeGunfight.reloadRoundsLeft = 0
            BridgeGunfight.reloadNeed = 0
            BridgeGunfight.reloadVirtual = false
            clearReloadSpeed(BridgeGunfight.body)
            if why == "not empty" then
                BridgeGunfight.reloadMissingCount = 0
                BridgeGunfight.suspended = false
                BridgeGunfight.noAmmoUntil = nil
                BridgeGunfight.recheckAt = nil
                BridgeGunfight.canMelee = false
                BridgeGunfight.meleeFallback = false
                BridgeGunfight.stance = "gun"
                BridgeGunfight.state = "idle"
                if BridgeGunfight.gunItem ~= nil then
                    BridgeGunfight.rounds = BridgeGunRules.roundsOf(BridgeGunfight.gunItem)
                end
                BridgeGunfight.info = "reload skipped: gun already loaded"
            elseif why == "no magazine" or why == "no ammo" then
                pcall(function() outOfAmmo(BridgeGunfight.body) end)
                BridgeGunfight.noAmmoUntil = (Bridge.time or 0) + 180
            else
                BridgeGunfight.canMelee = true
                BridgeGunfight.suspended = true
                local wait = 180
                if why == "gun missing" or why == "no primary gun" then
                    BridgeGunfight.reloadMissingCount = (BridgeGunfight.reloadMissingCount or 0) + 1
                    if BridgeGunfight.reloadMissingCount >= 3 then
                        BridgeGunfight.unassign(BridgeGunfight.body, "server cannot find gun")
                        BridgeGunfight.canMelee = true
                        return
                    end
                    wait = 600
                else
                    BridgeGunfight.reloadMissingCount = 0
BridgeGunfight.reserveAt = nil
BridgeGunfight.reserveN = 0
                end
                BridgeGunfight.recheckAt = (Bridge.time or 0) + wait
                if BridgeGunfight.gunItem ~= nil then
                    BridgeGunfight.rounds = BridgeGunRules.roundsOf(BridgeGunfight.gunItem)
                end
                pcall(function() BridgeGunfight.stow(BridgeGunfight.body) end)
                BridgeGunfight.state = "idle"
                log("reload backoff " .. why .. " " .. tostring(wait))
            end
        end
        return
    end
    if action == "complete" then
        BridgeGunfight.canMelee = false
        BridgeGunfight.reloadMissingCount = 0
BridgeGunfight.reserveAt = nil
BridgeGunfight.reserveN = 0
        BridgeGunfight.reloadVirtual = false
        if args.rounds ~= nil then
            BridgeGunfight.rounds = math.max(0, math.floor(tonumber(args.rounds) or 0))
            if BridgeGunfight.gunItem ~= nil then
                BridgeGunRules.setRounds(BridgeGunfight.gunItem, BridgeGunfight.rounds, true)
            end
        end
        BridgeGunfight.suspended = false
        BridgeGunfight.lowSaid = false
        BridgeGunfight.info = string.format("reload result rounds=%d", BridgeGunfight.rounds or 0)
    elseif action == "start" then
        BridgeGunfight.canMelee = false
        BridgeGunfight.reloadMissingCount = 0
BridgeGunfight.reserveAt = nil
BridgeGunfight.reserveN = 0
        BridgeGunfight.reloadTotal = tonumber(args.total) or 0
        if args.base == nil then args.base = BridgeGunfight.reloadBaseRounds or 0 end
        if args.needed == nil then args.needed = BridgeGunfight.reloadNeed or 0 end
        if args.external == nil then
            args.external = BridgeGunfight.gun ~= nil and BridgeGunfight.gun.magazineType ~= nil
        end
        if BridgeGunfight.reloadStage == "wait" then
            beginReload(BridgeGunfight.body, args)
        end
        BridgeGunfight.info = string.format("reload requested need=%d base=%d",
            tonumber(args.needed) or 0, tonumber(args.base) or 0)
    end
end


local function bodyById(id)
    if id == nil then return nil end
    local found = nil
    pcall(function()
        if Bridge.body ~= nil and Bridge.body:getPersistentOutfitID() == id then found = Bridge.body return end
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z:getPersistentOutfitID() == id then found = z break end
        end
    end)
    return found
end


function BridgeGunfight.onFx(args)
    if type(args) ~= "table" then return end
    if Bridge ~= nil and Bridge.mp and args.owner ~= nil
        and tostring(args.owner) == tostring(BridgeData.me()) then
        return
    end
    local body = bodyById(args.id)
    if body == nil then return end
    local kind = args.kind
    if (kind ~= "Rifle" and kind ~= "Handgun") then
        kind = BridgeGunfight.gun and BridgeGunfight.gun.kind or "Handgun"
    end
    pcall(function() body:setBumpType("NA_Fire" .. kind) end)
    BridgeGunfight.fireUntil = (Bridge.time or 0) + FIRE_TICKS
    retainBump(body, "NA_Aim" .. kind)
    if type(args.sound) == "string" and args.sound ~= "" then
        local played = false
        pcall(function() played = playGunshotAt(body:getX(), body:getY(), body:getZ(), args.sound) end)
        if not played then
            pcall(function()
                if BridgeSound ~= nil then BridgeSound.sfx(body, args.sound) else body:getEmitter():playSound(args.sound) end
            end)
        end
    end
    flash(body)
end


function BridgeGunfight.tick()
    local now = (Bridge ~= nil and Bridge.time) or 0
    local flashes = BridgeGunfight.flashes
    for i = #flashes, 1, -1 do
        local f = flashes[i]
        if f == nil or now >= (f.untilT or 0) then
            if f ~= nil then
                pcall(function() if f.src ~= nil then f.src:setActive(false) end end)
                pcall(function() if f.cell ~= nil and f.src ~= nil then f.cell:removeLamppost(f.src) end end)
            end
            table.remove(flashes, i)
        end
    end
    local bumps = BridgeGunfight.bumps
    for i = #bumps, 1, -1 do
        local b = bumps[i]
        if b == nil or now >= (b.untilT or 0) then
            if b ~= nil and b.body ~= nil then
                local cur = nil
                pcall(function() cur = tostring(b.body:getBumpType()) end)
                if cur ~= nil and string.sub(cur, 1, 6) == "NA_Fir" then
                    pcall(function() b.body:setBumpType(b.name) end)
                end
            end
            table.remove(bumps, i)
        end
    end
    local p = BridgeGunfight.pendingShot
    if p ~= nil and now - (p.at or now) > PENDING_TICKS then
        BridgeGunfight.pendingShot = nil
        log("shot request timed out, no server answer")
        BridgeGunfight.info = "shot timeout"
    end
end


function BridgeGunfight.reset()
    if Bridge ~= nil and Bridge.mp and (BridgeGunfight.assignedId ~= nil or BridgeGunfight.reloadStage ~= nil) then
        pcall(function() tellReload("cancel", {}) end)
    end
    if BridgeGunfight.ammoItem ~= nil then
        pcall(function() magCareEnd(BridgeGunfight.body) end)
    end
    if BridgeGunfight.magCareStage ~= nil then
        pcall(function() magCareEnd(BridgeGunfight.body) end)
    end
    local keepRounds = 0
    if BridgeGunfight.gunItem ~= nil then
        pcall(function() keepRounds = BridgeGunRules.roundsOf(BridgeGunfight.gunItem) end)
    end
    if BridgeMove ~= nil then BridgeMove.forcedWalk = nil end
    if Bridge.body ~= nil and BridgeGunfight.reposition ~= nil then
        pcall(function() stopReposition(Bridge.body) end)
    end
    BridgeGunfight.reposition = nil
    BridgeGunfight.reposSide = nil
    for _, f in ipairs(BridgeGunfight.flashes or {}) do
        pcall(function() if f.src ~= nil then f.src:setActive(false) end end)
        pcall(function() if f.cell ~= nil and f.src ~= nil then f.cell:removeLamppost(f.src) end end)
    end
    BridgeGunfight.flashes = {}
    BridgeGunfight.bumps = {}
    BridgeGunfight.target = nil
    BridgeGunfight.state = "idle"
    BridgeGunfight.drawn = false
    BridgeGunfight.attached = nil
    BridgeGunfight.aimUntil = nil
    BridgeGunfight.nextShotAt = nil
    BridgeGunfight.stowAt = nil
    BridgeGunfight.lastPick = 0
    BridgeGunfight.idleScanAt = nil
    BridgeGunfight.lineTarget = nil
    BridgeGunfight.lineAt = nil
    BridgeGunfight.lineOk = nil
    BridgeGunfight.fireUntil = nil
    BridgeGunfight.lastBump = nil
    BridgeGunfight.pendingShot = nil
    BridgeGunfight.moving = false
    BridgeGunfight.blockAt = nil
    BridgeGunfight.missingSince = nil
    BridgeGunfight.friendlies = nil
    BridgeGunfight.friendliesAt = nil
    BridgeGunfight.handSyncAt = nil
    BridgeGunfight.sideAt = nil
    BridgeGunfight.rounds = 0
    BridgeGunfight.maxAmmo = 0
    BridgeGunfight.reloadStage = nil
    BridgeGunfight.reloadUntil = nil
    BridgeGunfight.reloadStageAt = nil
    BridgeGunfight.reloadStageTicks = 0
    BridgeGunfight.reloadFamily = nil
    BridgeGunfight.reloadRoundsLeft = 0
    BridgeGunfight.reloadNeed = 0
    BridgeGunfight.reloadVirtual = false
    BridgeGunfight.reloadSavedRounds = 0
    BridgeGunfight.reloadBaseRounds = 0
    BridgeGunfight.reloadMagId = nil
    BridgeGunfight.reloadCancel = false
    BridgeGunfight.reloadTotal = 0
    BridgeGunfight.reloadStartedAt = nil
    BridgeGunfight.reloadDoneAt = nil
    BridgeGunfight.suspended = false
    BridgeGunfight.recheckAt = nil
    BridgeGunfight.lowSaid = false
    BridgeGunfight.modeRange = 0
    BridgeGunfight.canMelee = false
    BridgeGunfight.meleeFallback = false
    BridgeGunfight.stance = nil
    BridgeGunfight.lastGunAt = nil
    BridgeGunfight.meleeClearAt = nil
    BridgeGunfight.reloadClientAmmo = false
    BridgeGunfight.reloadTaken = 0
    BridgeGunfight.noAmmoUntil = nil
    BridgeGunfight.reloadMissingCount = 0
BridgeGunfight.reserveAt = nil
BridgeGunfight.reserveN = 0
    BridgeGunfight.ammoItem = nil
    BridgeGunfight.ammoOut = nil
    BridgeGunfight.ammoAmount = 0
    BridgeGunfight.ammoUntil = nil
    BridgeGunfight.ammoStageAt = nil
    BridgeGunfight.ammoStageTicks = 0
    BridgeGunfight.ammoCooldown = nil
    BridgeGunfight.peek = nil
    BridgeGunfight.peekCooldown = nil
    BridgeGunfight.homeAmmoAt = nil
    BridgeGunfight.ammoBorrow = nil
    BridgeGunfight.magCareStage = nil
    BridgeGunfight.magCareUntil = nil
    BridgeGunfight.magCareStageAt = nil
    BridgeGunfight.magCareStageTicks = 0
    BridgeGunfight.magCareMagId = nil
    BridgeGunfight.magCareMag = nil
    BridgeGunfight.magCareAt = nil
    BridgeGunfight.magCareHand1 = nil
    BridgeGunfight.magCareHand2 = nil
    BridgeGunfight.body = nil
end


Events.OnTick.Add(function() pcall(BridgeGunfight.tick) end)

log("loaded")





