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

local STOW_TICKS = 180
local RECHECK = 12
local FIRE_TICKS = 24
local PENDING_TICKS = 180
local FRIENDLY_TTL = 30
local FIRE_VAR = "BumpAnimFinished"
local stopReposition

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGunfight] " .. tostring(text)) end end
local function warn(text) print("[BridgeGunfight] " .. tostring(text)) end
local function vlog(text) if Bridge ~= nil and Bridge.verbose then log(text) end end

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


local function setFields(item)
    BridgeGunfight.gunItem = item
    BridgeGunfight.assignedId = item:getID()
    BridgeGunfight.gun = BridgeGunRules.describe(item)
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
end


function BridgeGunfight.isAssigned(body)
    return BridgeGunfight.assignedId ~= nil
end

function BridgeGunfight.hasGun()
    return BridgeGunfight.assignedId ~= nil
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
    local item = BridgeGunfight.gunItem
    local ok = false
    pcall(function() ok = item ~= nil and item:getID() == id end)
    if ok and body ~= nil then
        local here = false
        pcall(function()
            here = inInventory(body, item) or body:getPrimaryHandItem() == item
                or body:getSecondaryHandItem() == item
        end)
        if not here then ok = false end
    end
    if not ok and body ~= nil then
        pcall(function() item = body:getInventory():getItemWithIDRecursiv(id) end)
    end
    if item == nil or not BridgeGunRules.valid(item) then
        return nil
    end
    BridgeGunfight.gunItem = item
    if BridgeGunfight.gun == nil then BridgeGunfight.gun = BridgeGunRules.describe(item) end
    return item
end


local function tellServer(gunType, gunId)
    if Bridge == nil or not Bridge.mp then return end
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "state", { gunType = gunType or "", gunId = gunId })
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


function BridgeGunfight.recover(body)
    BridgeGunfight.reset()
    BridgeGunfight.body = body
    if body == nil then return nil end
    local found = findFlagged(body)
    if found == nil and Bridge.store ~= nil and Bridge.store.gunId ~= nil then
        pcall(function() found = body:getInventory():getItemWithIDRecursiv(Bridge.store.gunId) end)
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
        log("recovered primary gun " .. BridgeGunRules.summary(BridgeGunfight.gun))
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
    if BridgeGunfight.assignedId ~= nil and BridgeGunfight.assignedId ~= item:getID() then
        BridgeGunfight.unassign(body, "replaced")
    end
    setMark(item, true)
    setFields(item)
    BridgeGunfight.body = body
    BridgeGunfight.target = nil
    BridgeGunfight.state = "idle"
    BridgeGunfight.stowAt = nil
    BridgeGunfight.fireUntil = nil
    pcall(function() BridgeWeapon.putAway(body) end)
    tellServer(BridgeGunfight.gun.fullType, BridgeGunfight.assignedId)
    log("assigned primary gun " .. BridgeGunRules.summary(BridgeGunfight.gun))
    return true
end


function BridgeGunfight.unassign(body, reason)
    if BridgeGunfight.assignedId == nil then return false end
    local item = BridgeGunfight.gunItem
    if BridgeGunfight.drawn then pcall(function() BridgeGunfight.stow(body) end) end
    setMark(item, false)
    local was = BridgeGunfight.gun and BridgeGunfight.gun.fullType or "?"
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
    local item = BridgeGunfight.gunItem
    if item == nil then return end
    pcall(function()
        body:setPrimaryHandItem(item)
        if BridgeGunfight.gun ~= nil and BridgeGunfight.gun.twoHanded then body:setSecondaryHandItem(item) end
        body:resetEquippedHandsModels()
    end)
    BridgeGunfight.handSyncAt = Bridge.time
end


function BridgeGunfight.draw(body)
    local item = BridgeGunfight.assignedItem(body)
    if item == nil then return false end
    local hand = nil
    pcall(function() hand = body:getPrimaryHandItem() end)
    if hand == item then
        pcall(function() body:resetEquippedHandsModels() end)
        BridgeGunfight.drawn = true
        return false
    end
    if hand ~= nil then
        pcall(function() BridgeWeapon.putAway(body) end)
    end
    detachGun(body)
    pcall(function() if body:isAttachedItem(item) then body:removeAttachedItem(item) end end)
    refresh(body)
    hands(body, item, true)
    BridgeGunfight.handSyncAt = Bridge.time
    BridgeGunfight.drawn = true
    log("drew " .. tostring(item:getType()))
    return true
end


function BridgeGunfight.stow(body)
    if body == nil or (Bridge.body ~= nil and body ~= Bridge.body) then return false end
    stopReposition(body)
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
    refresh(body)
    local attached = attachGun(body, item)
    pcall(function() body:resetEquippedHandsModels() end)
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

local function clearBump(body)
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
    if companionBody(z) then return false end
    if BridgeGunRules.isForeignNpc(z) ~= nil then return false end
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
    if dist(body, z) > BridgeGunfight.gun.range + 0.9 then return false end
    local clear = false
    pcall(function() clear = BridgeMove.lineClear(body, z:getX(), z:getY(), z:getZ()) == true end)
    if not clear then return false end
    if not BridgeFight.visible(z, red) then return false end
    return true
end


local function pickTarget(body, red)
    local best, bestScore = nil, math.huge
    local range = BridgeGunfight.gun and BridgeGunfight.gun.range or 0
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if targetOk(z, body, red) and math.abs(z:getZ() - body:getZ()) < 0.8 then
            local dSelf = dist(body, z)
            if dSelf <= range then
                local clear = false
                pcall(function() clear = BridgeMove.lineClear(body, z:getX(), z:getY(), z:getZ()) == true end)
                if clear and BridgeFight.visible(z, red) then
                    local dRed = dist(red, z)
                    local score = dRed + dSelf * 0.01
                    if score < bestScore then
                        best, bestScore = z, score
                    end
                end
            end
        end
    end
    return best
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


local function playShot(body, gun)
    if gun == nil then return end
    if gun.sound ~= nil then
        pcall(function()
            if BridgeSound ~= nil then BridgeSound.sfx(body, gun.sound) else body:getEmitter():playSound(gun.sound) end
        end)
    end
    pcall(function()
        local radius = (gun.soundRadius or 20) * noiseMultiplier()
        local outside = true
        pcall(function() outside = body:isOutside() ~= false end)
        if not outside then radius = radius * 0.5 end
        local ok = pcall(function() body:addWorldSoundUnlessInvisible(radius, gun.soundVolume, true) end)
        if not ok then
            addSound(body, body:getX(), body:getY(), body:getZ(), radius, gun.soundVolume)
        end
    end)
    flash(body)
end


local function retainBump(body, name)
    BridgeGunfight.bumps[#BridgeGunfight.bumps + 1] = {
        body = body, name = name, untilT = (Bridge.time or 0) + FIRE_TICKS,
    }
end


local function fire(body)
    local item = BridgeGunfight.gunItem
    local gun = BridgeGunfight.gun
    local t = BridgeGunfight.target
    if item == nil or gun == nil or t == nil then return end
    local kind = gun.kind or "Handgun"
    local d = dist(body, t)
    local moving = BridgeGunfight.moving == true
    local chance = BridgeGunRules.hitChance(gun, d, moving)
    BridgeGunfight.shots = BridgeGunfight.shots + 1
    BridgeGunfight.lastShotAt = Bridge.time
    BridgeGunfight.nextShotAt = (Bridge.time or 0) + math.max(24, (gun.recoilDelay or 24) + 6) + ZombRand(0, 6)

    if Bridge ~= nil and Bridge.mp then
        local onlineId = nil
        pcall(function() onlineId = t:getOnlineID() end)
        local x, y, z = t:getX(), t:getY(), t:getZ()
        BridgeGunfight.pendingShot = { at = Bridge.time, chance = chance, dist = d, target = t }
        pcall(function()
            sendClientCommand(BridgeData.owner(), "Bridge", "gunShot",
                { targetId = onlineId, x = x, y = y, z = z })
        end)
        vlog(string.format("shot request -> %s d=%.1f chance=%.0f%%", tostring(item:getType()), d, chance))
        BridgeGunfight.info = string.format("request d=%.1f chance=%.0f", d, chance)
        return
    end

    plant(body, "NA_Fire" .. kind)
    pcall(function() body:setVariable(FIRE_VAR, false) end)
    BridgeGunfight.fireUntil = (Bridge.time or 0) + FIRE_TICKS
    retainBump(body, "NA_Aim" .. kind)
    playShot(body, gun)

    local roll = ZombRand(100)
    if roll < chance then
        local crit = false
        pcall(function() crit = ZombRand(100) < (gun.critChance or 0) end)
        local dmg = BridgeGunRules.rollDamage(gun)
        if crit then dmg = dmg * math.max(1, math.min(5, gun.critMult or 2)) end
        local hpBefore = 0
        pcall(function() hpBefore = t:getHealth() end)
        local fake = nil
        pcall(function() fake = getCell():getFakeZombieForHit() end)
        local attacker = fake or body
        local reaction = BridgeGunRules.shotReaction(body, t, crit)

        pcall(function() attacker:setVariable("ZombieHitReaction", reaction) end)
        pcall(function() body:setVariable("ZombieHitReaction", reaction) end)
        pcall(function() t:setHitFromBehind(body:isBehind(t)) end)
        pcall(function() t:setAttackedBy(attacker) end)
        pcall(function() t:setPlayerAttackPosition(t:testDotSide(body)) end)
        pcall(function() t:setHitHeadWhileOnFloor(0) end)
        pcall(function() t:setHitLegsWhileOnFloor(false) end)
        pcall(function() body:setCriticalHit(crit) end)

        local ok, err = pcall(function() t:Hit(item, attacker, dmg, false, 1, false) end)
        pcall(function() body:setCriticalHit(false) end)

        if ok then BridgeGunfight.hits = BridgeGunfight.hits + 1 end
        if ok then hitBlood(t) end
        local hpAfter = hpBefore
        pcall(function() hpAfter = t:getHealth() end)
        local dead = false
        pcall(function() dead = t:isDead() end)
        if dead and ok then
            pcall(function() if BridgeKills ~= nil then BridgeKills.credit(t) BridgeKills.confirm(t) end end)
        end
        pcall(function() t:playSound(gun.hitSound or "ZombieHit") end)
        vlog(string.format("shot hit %s d=%.1f chance=%.0f%% roll=%d dmg=%.2f%s hp=%.2f->%.2f%s reaction=%s%s",
            tostring(item:getType()), d, chance, roll + 1, dmg, crit and " CRIT" or "", hpBefore, hpAfter,
            dead and " KILL" or "", tostring(reaction),
            ok and "" or (" error=" .. tostring(err))))
        BridgeGunfight.info = string.format("hit d=%.1f dmg=%.1f hp=%.1f%s", d, dmg, hpAfter, dead and " kill" or "")
    else
        pcall(function()
            local sq = t:getSquare()
            if sq ~= nil then sq:playSound(gun.impactSound or "BulletImpact") end
        end)
        vlog(string.format("shot miss %s d=%.1f chance=%.0f%% roll=%d", tostring(item:getType()), d, chance, roll + 1))
        BridgeGunfight.info = string.format("miss d=%.1f chance=%.0f", d, chance)
    end
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


function BridgeGunfight.update(body)
    if body == nil then return false end
    if Bridge.body ~= nil and body ~= Bridge.body then
        BridgeGunfight.body = nil
        return false
    end
    BridgeGunfight.body = body
    if BridgeGunfight.assignedId == nil then return false end
    local item = BridgeGunfight.assignedItem(body)
    if item == nil then
        BridgeGunfight.missingSince = BridgeGunfight.missingSince or Bridge.time
        if Bridge.time - BridgeGunfight.missingSince >= 900 then
            BridgeGunfight.unassign(body, "gun gone or broken")
        end
        BridgeGunfight.info = "gun missing"
        return false
    end
    BridgeGunfight.missingSince = nil
    local red = BridgeData.owner()
    if red == nil then return false end

    if BridgeGunfight.target ~= nil or BridgeGunfight.drawn then Bridge.holdPos = nil end

    local hand = nil
    pcall(function() hand = body:getPrimaryHandItem() end)
    if hand == item then
        BridgeGunfight.drawn = true
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
        vlog("target lost: " .. tostring(t:getType()))
        t = nil
        BridgeGunfight.target = nil
        BridgeGunfight.state = "idle"
        BridgeGunfight.stowAt = Bridge.time + STOW_TICKS
    end
    if t == nil and pick then
        BridgeGunfight.lastPick = Bridge.time
        t = pickTarget(body, red)
        if t ~= nil then
            BridgeGunfight.target = t
            BridgeGunfight.lastTargetAt = Bridge.time
            BridgeGunfight.stowAt = nil
            local aim = clamp((BridgeGunfight.gun.aimingTime or 40) * 0.6, 15, 45)
            BridgeGunfight.aimUntil = Bridge.time + aim
            BridgeGunfight.nextShotAt = BridgeGunfight.aimUntil
            BridgeGunfight.state = "aim"
            BridgeGunfight.draw(body)
            vlog(string.format("target acquired d=%.1f aim=%d ticks", dist(body, t), aim))
        end
    end

    if t == nil then
        stopReposition(body)
        if BridgeGunfight.drawn then
            if BridgeGunfight.stowAt == nil then BridgeGunfight.stowAt = Bridge.time + STOW_TICKS end
            if Bridge.time >= BridgeGunfight.stowAt then
                BridgeGunfight.stow(body)
                BridgeGunfight.stowAt = nil
                BridgeGunfight.state = "idle"
                clearBump(body)
            elseif BridgeGunfight.fireUntil == nil then
                plant(body, "NA_Aim" .. (BridgeGunfight.gun.kind or "Handgun"))
            end
        else
            clearBump(body)
        end
        BridgeGunfight.info = string.format("%s idle shots=%d hits=%d", tostring(item:getType()), BridgeGunfight.shots, BridgeGunfight.hits)
        if BridgeGunfight.drawn then return true end
        return false
    end

    pcall(function() body:faceLocationF(t:getX(), t:getY()) end)

    local d = dist(body, t)
    local retreat = false
    if d < BridgeGunRules.MIN_RANGE then retreat = backpedal(body, t) end
    BridgeGunfight.moving = retreat
    BridgeGunfight.state = retreat and "backstep" or "aim"

    local why, blocker = blockedBy(body, t)
    if why ~= nil then
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

    local clear = false
    pcall(function() clear = BridgeMove.lineClear(body, t:getX(), t:getY(), t:getZ()) == true end)
    if not clear then
        BridgeGunfight.info = "hold fire: no line"
        return true
    end

    if not BridgeGunRules.valid(item) then
        BridgeGunfight.unassign(body, "gun became unusable")
        return false
    end

    fire(body)
    return true
end


function BridgeGunfight.onResult(args)
    local pending = BridgeGunfight.pendingShot
    BridgeGunfight.pendingShot = nil
    if type(args) ~= "table" then return end
    if args.ok == false then
        log("shot rejected: " .. tostring(args.why or "?"))
        BridgeGunfight.info = "rejected: " .. tostring(args.why or "?")
        return
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
    end
    log(string.format("shot result hit=%s dmg=%s hp=%s->%s", tostring(args.hit == true),
        tostring(dmg and string.format("%.2f", dmg) or "-"),
        tostring(tonumber(args.hpBefore) or "-"), tostring(hp and string.format("%.2f", hp) or "-")))
    BridgeGunfight.info = string.format("result hit=%s dmg=%s", tostring(args.hit == true),
        tostring(dmg and string.format("%.1f", dmg) or "-"))
    if pending ~= nil then BridgeGunfight.lastShotAt = Bridge.time end
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
        pcall(function()
            if BridgeSound ~= nil then BridgeSound.sfx(body, args.sound) else body:getEmitter():playSound(args.sound) end
        end)
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
    BridgeGunfight.body = nil
end


Events.OnTick.Add(function() pcall(BridgeGunfight.tick) end)

log("loaded")
