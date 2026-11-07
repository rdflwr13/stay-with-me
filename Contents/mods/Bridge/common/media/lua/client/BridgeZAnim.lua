BridgeAnim = BridgeAnim or {}

BridgeAnim.PG_ID = "PlayerGreetings"
BridgeAnim.BUMP = "NAPghugHigh2"
BridgeAnim.MS = 3700
BridgeAnim.TICKS_PER_SEC = 60
BridgeAnim.RANGE = 1.6
BridgeAnim.GAP = 0.171
BridgeAnim.PLAYER_EMOTE = "PGHugLow2"
BridgeAnim.VARIANTS = {
    romantic = { label = "HugRomantic", bump = "NAPGhugHigh2", emote = "PGHugLow2", ms = 3700, gap = 0.171, mode = "front" },
    reversed = { label = "HugReversed", bump = "NAPghugLow2", emote = "PGHugHigh2", ms = 3700, gap = 0.171, mode = "front" },
    tight = { label = "HugTight", bump = "NAPghugHigh1", emote = "PGHugLow1", ms = 3700, gap = 0.132, mode = "front" },
    wide = { label = "HugWide", bump = "NAPghugHigh3", emote = "PGHugLow3", ms = 3700, gap = 0.211, mode = "front" },
    backYou = { label = "BackHugYou", bump = "NAPGDance2Follow", emote = "PGDance2Lead", ms = 6349, gap = 0.03, mode = "frontSame", pinPlayer = true },
    backHer = { label = "BackHugHer", bump = "NAPGDance2Lead", emote = "PGDance2Follow", ms = 6349, gap = 0.03, mode = "behind", pinPlayer = true },
    shoulderYou = { label = "ShoulderComfortYou", bump = "NAPGMassageF", emote = "PGMassageL", ms = 8000, gap = 0.03, mode = "frontSame", pinPlayer = true },
    shoulderHer = { label = "ShoulderComfortHer", bump = "NAPGMassageL", emote = "PGMassageF", ms = 8000, gap = 0.03, mode = "behind", pinPlayer = true },
    lean = { label = "LeanIn", bump = "NAPGKissL", emote = "PGKissF", ms = 4800, gap = 0.303, mode = "front" },
    dance = { label = "SlowDance", bump = "NAPGDanceLead", emote = "PGDanceFollow", ms = 6349, gap = 0.01, mode = "front", pinPlayer = true, loopUntilStop = true },
}
BridgeAnim.HUG_POOL = { "romantic", "reversed", "tight", "wide" }
BridgeAnim.ORDER = { "romantic", "backYou", "backHer", "shoulderYou", "shoulderHer", "lean", "dance" }
BridgeAnim.current = "romantic"

function BridgeAnim.pick(name)
    if BridgeAnim.VARIANTS[name] ~= nil then BridgeAnim.current = name end
    return BridgeAnim.current
end

function BridgeAnim.randomHug()
    local pick = BridgeAnim.HUG_POOL[ZombRand(#BridgeAnim.HUG_POOL) + 1]
    BridgeAnim.current = pick
    return pick
end

BridgeAnim.DEBUG = true

function BridgeAnim.log(fmt, ...)
    if BridgeAnim.DEBUG ~= true then return end
    local ok, s = pcall(string.format, fmt, ...)
    print("[BridgeAnim] " .. tostring(ok and s or fmt))
end

local function hugSnapshot(body, owner, v)
    local px, py, pz = 0, 0, 0
    local pfx, pfy = 0, 0
    local bx, by, bz = 0, 0, 0
    local bfx, bfy = 0, 0
    if owner ~= nil then
        pcall(function()
            px, py, pz = owner:getX(), owner:getY(), owner:getZ()
            local f = owner:getForwardDirection()
            if f ~= nil then pfx, pfy = f:getX(), f:getY() end
        end)
    end
    if body ~= nil then
        pcall(function()
            bx, by, bz = body:getX(), body:getY(), body:getZ()
            local f = body:getForwardDirection()
            if f ~= nil then bfx, bfy = f:getX(), f:getY() end
        end)
    end
    local dx, dy = bx - px, by - py
    local dist = math.sqrt(dx * dx + dy * dy)
    local fdot = pfx * bfx + pfy * bfy
    local bodyToPlayer = 0
    if dist > 0.001 then bodyToPlayer = (bfx * (-dx) + bfy * (-dy)) / dist end
    local along, side = 0, 0
    if dist > 0.001 then
        along = dx * pfx + dy * pfy
        side = dx * (-pfy) + dy * pfx
    end
    local pAnim, bAnim = 0, 0
    if owner ~= nil then pcall(function() pAnim = tonumber(owner:getAnimAngle()) or 0 end) end
    if body ~= nil then pcall(function() bAnim = tonumber(body:getAnimAngle()) or 0 end) end
    local mode = v ~= nil and v.mode or "front"
    local gap = tonumber(v ~= nil and v.gap) or 0
    local faceOk = "?"
    if mode == "behind" or mode == "frontSame" then
        faceOk = tostring(fdot > 0.9)
    elseif mode == "front" then
        faceOk = tostring(fdot < -0.9)
    end
    local alongOk = "?"
    if gap > 0 then
        if mode == "behind" then
            alongOk = tostring(along < -gap * 0.5 and math.abs(side) < 0.15)
        else
            alongOk = tostring(along > gap * 0.5 and math.abs(side) < 0.15)
        end
    end
    local spotDelta = -1
    if BridgeTask ~= nil and BridgeTask.hugSpotX ~= nil and BridgeTask.hugSpotY ~= nil then
        local sx, sy = bx - BridgeTask.hugSpotX, by - BridgeTask.hugSpotY
        spotDelta = math.sqrt(sx * sx + sy * sy)
    end
    local asn, bump, bmoving = "?", "?", "?"
    local solidP, solidB = "?", "?"
    local collB = "?"
    local emote, emoting = "?", "?"
    local pMain, pSec, bMain, bSec = "?", "?", "?", "?"
    if body ~= nil then
        pcall(function() asn = tostring(body:getActionStateName()) end)
        pcall(function() bump = tostring(body:getBumpType()) end)
        pcall(function() bmoving = tostring(body:getVariableBoolean("bMoving")) end)
        pcall(function() solidB = tostring(body:isSolid()) end)
        pcall(function() collB = tostring(body:isCollidable()) end)
        pcall(function() local it = body:getPrimaryHandItem(); bMain = it ~= nil and tostring(it:getFullType()) or "nil" end)
        pcall(function() local it = body:getSecondaryHandItem(); bSec = it ~= nil and tostring(it:getFullType()) or "nil" end)
    end
    if owner ~= nil then
        pcall(function() solidP = tostring(owner:isSolid()) end)
        pcall(function() emote = tostring(owner:getVariableString("emote")) end)
        pcall(function() emoting = tostring(owner:getVariableBoolean("EmotePlaying")) end)
        pcall(function() local it = owner:getPrimaryHandItem(); pMain = it ~= nil and tostring(it:getFullType()) or "nil" end)
        pcall(function() local it = owner:getSecondaryHandItem(); pSec = it ~= nil and tostring(it:getFullType()) or "nil" end)
    end
    return string.format(
        "variant=%s mode=%s gap=%.3f bump=%s emote=%s | player=(%.3f,%.3f,%.3f) pf=(%.3f,%.3f) anim=%.3f hands=%s,%s | body=(%.3f,%.3f,%.3f) bf=(%.3f,%.3f) anim=%.3f hands=%s,%s | dist=%.3f along=%.3f side=%.3f fdot=%.3f b2p=%.3f spotDelta=%.3f | asn=%s bumpType=%s bMoving=%s solidP=%s solidB=%s collB=%s pEmote=%s pPlaying=%s faceOk=%s alongOk=%s",
        tostring(BridgeTask ~= nil and BridgeTask.hugVariant or BridgeAnim.current),
        tostring(v ~= nil and v.mode or "?"),
        tonumber(v ~= nil and v.gap) or -1,
        tostring(v ~= nil and v.bump or "?"),
        tostring(v ~= nil and v.emote or "?"),
        px, py, pz, pfx, pfy, pAnim, pMain, pSec,
        bx, by, bz, bfx, bfy, bAnim, bMain, bSec,
        dist, along, side, fdot, bodyToPlayer, spotDelta,
        asn, bump, bmoving, solidP, solidB, collB, emote, emoting, faceOk, alongOk)
end

function BridgeAnim.dump(tag, body, v)
    if BridgeAnim.DEBUG ~= true then return end
    local owner = nil
    pcall(function() owner = BridgeData.owner() end)
    local ok, info = pcall(hugSnapshot, body, owner, v)
    BridgeAnim.log("%s %s", tostring(tag), tostring(ok and info or "snapshot failed"))
end

function BridgeAnim.taskConfig()
    local id = nil
    if BridgeTask ~= nil then id = BridgeTask.hugVariant end
    return BridgeAnim.VARIANTS[id] or BridgeAnim.VARIANTS.romantic
end
BridgeAnim.END_BUFFER = 6
BridgeAnim.PREP_MAX = 90
BridgeAnim.PREP_TICKS = 30
BridgeAnim.RETRY_TICKS = 24
BridgeAnim.RETRY_MAX = 1

function BridgeAnim.enabled()
    local mods = getActivatedMods()
    return mods ~= nil and mods:contains(BridgeAnim.PG_ID) == true
end

function BridgeAnim.tip(option, text)
    pcall(function()
        local t = ISInventoryPaneContextMenu.addToolTip()
        t.description = text
        option.toolTip = t
    end)
end

local function faceAt(character, x, y)
    if character == nil then return end
    pcall(function()
        local dx, dy = x - character:getX(), y - character:getY()
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.001 then character:setForwardDirection(dx / d, dy / d) end
        character:faceLocationF(x, y)
    end)
end

local function hasMethod(object, name)
    if object == nil then return false end
    local ok, method = pcall(function() return object[name] end)
    return ok and type(method) == "function"
end

local function playerReady(body, waiting)
    local owner = BridgeData.owner()
    if owner == nil then return "Player not found" end
    if body == nil then return "Companion not present" end

    local dx, dy, dz = 0, 0, 0
    pcall(function()
        dx = owner:getX() - body:getX()
        dy = owner:getY() - body:getY()
        dz = math.abs(owner:getZ() - body:getZ())
    end)
    if dz >= 0.5 then return "Player is on another floor" end
    if dx * dx + dy * dy > BridgeAnim.RANGE * BridgeAnim.RANGE then return "Player is too far away" end

    local inCar = false
    pcall(function() inCar = owner:getVehicle() ~= nil end)
    if inCar then return "Player is in a vehicle" end

    local aiming = false
    pcall(function() aiming = owner:isAiming() == true end)
    if aiming then return "Player is aiming" end

    local asleep = false
    pcall(function() asleep = owner:isAsleep() == true end)
    if asleep then return "Player is asleep" end

    local acting = false
    if hasMethod(owner, "isPerformingAnAction") then
        pcall(function() acting = owner:isPerformingAnAction() == true end)
    end
    if not acting then
        pcall(function() acting = owner:getVariableBoolean("IsPerformingAnAction") == true end)
    end
    if acting and not waiting then return "Player is busy" end

    local emoting = false
    pcall(function() emoting = owner:getVariableBoolean("EmotePlaying") == true end)
    if emoting then return "Player is already emoting" end

    local seated = false
    pcall(function() seated = owner:isSittingOnFurniture() == true end)
    if seated then return "Player is sitting" end

    local prone = false
    pcall(function() prone = owner:isProne() == true end)
    if prone then return "Player is on the ground" end

    local moving = false
    pcall(function()
        moving = owner:isPlayerMoving() == true
        if not moving then moving = owner:pressedMovement(false) == true end
    end)
    if moving then return "Player is moving" end

    return nil
end

local function playerBusy(owner)
    if owner == nil then return true end
    local busy = false
    if hasMethod(owner, "isPerformingAnAction") then
        pcall(function() busy = owner:isPerformingAnAction() == true end)
    end
    if not busy then
        pcall(function() busy = owner:getVariableBoolean("IsPerformingAnAction") == true end)
    end
    if not busy and ISTimedActionQueue ~= nil and type(ISTimedActionQueue.isPlayerDoingAction) == "function" then
        pcall(function() busy = ISTimedActionQueue.isPlayerDoingAction(owner) == true end)
    end
    if not busy and hasMethod(owner, "getCurrentActionContextStateName") then
        local st = nil
        pcall(function() st = owner:getCurrentActionContextStateName() end)
        if st ~= nil and st ~= "idle" and st ~= "emote" then busy = true end
    end
    return busy
end

local function placeCompanion(body, owner, v)
    if body == nil or owner == nil then return false end
    v = v or BridgeAnim.VARIANTS.romantic
    local px, py, pz = 0, 0, 0
    local bx, by = 0, 0
    pcall(function()
        px, py, pz = owner:getX(), owner:getY(), math.floor(owner:getZ())
        bx, by = body:getX(), body:getY()
    end)

    local mode = v.mode or "front"
    local tx, ty = 0, 0
    local fx, fy = 0, 1
    if mode == "behind" or mode == "frontSame" then
        pcall(function()
            local f = owner:getForwardDirection()
            if f ~= nil then
                fx, fy = f:getX(), f:getY()
                local d = math.sqrt(fx * fx + fy * fy)
                if d > 0.001 then fx, fy = fx / d, fy / d end
            end
        end)
        local gap = v.gap or BridgeAnim.GAP
        if mode == "behind" then
            tx, ty = px - fx * gap, py - fy * gap
        else
            tx, ty = px + fx * gap, py + fy * gap
        end
    else
        local dx, dy = bx - px, by - py
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 0.01 then
            dx, dy = 0, 1
            pcall(function()
                local f = owner:getForwardDirection()
                if f ~= nil then dx, dy = f:getX(), f:getY() end
            end)
            d = math.sqrt(dx * dx + dy * dy)
            if d > 0.001 then dx, dy = dx / d, dy / d end
        else
            dx, dy = dx / d, dy / d
        end
        local gap = v.gap or BridgeAnim.GAP
        tx, ty = px + dx * gap, py + dy * gap
    end

    local sq = nil
    pcall(function() sq = getCell():getGridSquare(math.floor(tx), math.floor(ty), pz) end)
    if sq == nil then
        BridgeAnim.log("place fail mode=%s target=(%.3f,%.3f,%d) reason=no square", tostring(mode), tx, ty, pz)
        return false
    end

    local solid = false
    pcall(function() solid = sq:isSolid() == true or sq:isSolidTrans() == true end)
    if solid then
        BridgeAnim.log("place fail mode=%s target=(%.3f,%.3f,%d) reason=solid", tostring(mode), tx, ty, pz)
        return false
    end

    local blocked = false
    pcall(function()
        local cur = owner:getCurrentSquare()
        blocked = cur ~= nil and cur ~= sq and cur:isBlockedTo(sq) == true
    end)
    if blocked then
        BridgeAnim.log("place fail mode=%s target=(%.3f,%.3f,%d) reason=blocked", tostring(mode), tx, ty, pz)
        return false
    end

    pcall(function()
        body:setX(tx)
        body:setY(ty)
        body:setLastX(tx)
        body:setLastY(ty)
        body:setNextX(tx)
        body:setNextY(ty)
    end)

    if mode == "behind" then
        faceAt(body, px + fx, py + fy)
        pcall(function() owner:setForwardDirection(fx, fy) end)
    elseif mode == "frontSame" then
        faceAt(body, px + fx * 2, py + fy * 2)
        pcall(function() owner:setForwardDirection(fx, fy) end)
    else
        faceAt(body, px, py)
        faceAt(owner, body:getX(), body:getY())
    end
    return true
end

local function holdPose(body, owner, v)
    if body == nil then return end
    if BridgeTask.hugSpotX ~= nil and BridgeTask.hugSpotY ~= nil then
        pcall(function()
            body:setX(BridgeTask.hugSpotX)
            body:setY(BridgeTask.hugSpotY)
            body:setLastX(BridgeTask.hugSpotX)
            body:setLastY(BridgeTask.hugSpotY)
            body:setNextX(BridgeTask.hugSpotX)
            body:setNextY(BridgeTask.hugSpotY)
        end)
    end
    if owner ~= nil and v ~= nil and v.pinPlayer and BridgeTask.hugPlayerX ~= nil and BridgeTask.hugPlayerY ~= nil then
        pcall(function()
            owner:setX(BridgeTask.hugPlayerX)
            owner:setY(BridgeTask.hugPlayerY)
            owner:setLastX(BridgeTask.hugPlayerX)
            owner:setLastY(BridgeTask.hugPlayerY)
            owner:setNextX(BridgeTask.hugPlayerX)
            owner:setNextY(BridgeTask.hugPlayerY)
        end)
    end
    local mode = v ~= nil and v.mode or "front"
    if mode == "behind" or mode == "frontSame" then
        local fx, fy = BridgeTask.hugFaceX, BridgeTask.hugFaceY
        if fx == nil or fy == nil then fx, fy = 0, 1 end
        pcall(function() body:setForwardDirection(fx, fy) end)
        if owner ~= nil then pcall(function() owner:setForwardDirection(fx, fy) end) end
    elseif owner ~= nil then
        local px, py = 0, 0
        pcall(function() px, py = owner:getX(), owner:getY() end)
        faceAt(body, px, py)
    end
end

function BridgeAnim.reason()
    if not BridgeAnim.enabled() then return "Requires PZ Relationship (PlayerGreetings)" end
    if Bridge == nil or not Bridge.alive() or Bridge.body == nil then return "Companion not present" end
    if Bridge.kind ~= "zombie" then return "Unsupported companion body" end
    if BridgeTask == nil or BridgeTask.kinds == nil or BridgeTask.kinds.anim == nil then return "Anim task not loaded" end
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
    local ready = playerReady(body)
    if ready ~= nil then return ready end
    return nil
end

function BridgeAnim.test(name)
    if name == "romantic" then
        name = BridgeAnim.randomHug()
    else
        BridgeAnim.pick(name)
    end
    local why = BridgeAnim.reason()
    if why ~= nil then
        print("[BridgeAnim] cannot test " .. tostring(name) .. ": " .. tostring(why))
        return
    end
    local res = BridgeTask.start("anim", {})
    print("[BridgeAnim] " .. tostring(name) .. " result: " .. tostring(res))
end

local function registerAnimTask()
    if BridgeTask == nil or BridgeTask.kinds == nil then return end

    BridgeTask.kinds.anim = {
        noTargets = true,
        restoreMode = true,
        dangerRadius = 3.0,
    }

    function BridgeTask.kinds.anim.available(body)
        return BridgeAnim.reason() == nil
    end

    function BridgeTask.kinds.anim.missing(body)
        return nil
    end

    local function cancelHug(why)
        BridgeTask.hugEndReason = tostring(why)
        BridgeAnim.log("cancel %s", tostring(why))
        return BridgeTask.cancel(why)
    end

    local function finishHug(why)
        BridgeTask.hugEndReason = tostring(why)
        BridgeAnim.log("finish %s", tostring(why))
        return BridgeTask.finish()
    end

    function BridgeTask.kinds.anim.update(body)
        if BridgeTask.hugVariant == nil then BridgeTask.hugVariant = BridgeAnim.current or "romantic" end
        local v = BridgeAnim.taskConfig()
        if BridgeTask.hugAt == nil then
            local owner = BridgeData.owner()
            if owner == nil or body == nil then return cancelHug("hug target") end

            if not BridgeTask.hugArmed then
                local why = playerReady(body)
                if why ~= nil then return cancelHug("hug " .. why) end

                if BridgeMove ~= nil and BridgeMove.stopPath ~= nil then
                    pcall(function() BridgeMove.stopPath(body) end)
                end
                pcall(function()
                    body:setVariable("bPathfind", false)
                    body:setVariable("bMoving", false)
                    body:setMoving(false)
                end)

                local asn = ""
                pcall(function() asn = tostring(body:getActionStateName()) end)
                if asn == "walktoward" or asn == "pathfind" or asn == "turnalerted" or asn == "lunge" then
                    BridgeTask.hugWait = (BridgeTask.hugWait or 0) + 1
                    if BridgeTask.hugWait > BridgeAnim.PREP_MAX then return cancelHug("hug busy") end
                    return true
                end
                BridgeTask.hugWait = nil

                local playerSolid, bodySolid = true, true
                pcall(function() playerSolid = owner:isSolid() end)
                pcall(function() bodySolid = body:isSolid() end)
                BridgeTask.hugPlayerSolid = playerSolid
                BridgeTask.hugBodySolid = bodySolid
                pcall(function() owner:setSolid(false) end)
                pcall(function() body:setSolid(false) end)
                BridgeTask.hugBodyCollidable = nil
                pcall(function() BridgeTask.hugBodyCollidable = body:isCollidable() end)
                pcall(function() body:setCollidable(false) end)

                if not placeCompanion(body, owner, v) then return cancelHug("hug no room") end
                BridgeTask.hugSpotX = body:getX()
                BridgeTask.hugSpotY = body:getY()
                BridgeTask.hugPlayerX = nil
                BridgeTask.hugPlayerY = nil
                if v.pinPlayer then
                    BridgeTask.hugPlayerX = owner:getX()
                    BridgeTask.hugPlayerY = owner:getY()
                end
                BridgeTask.hugFaceX = nil
                BridgeTask.hugFaceY = nil
                if v.mode == "behind" or v.mode == "frontSame" then
                    local fx, fy = 0, 1
                    pcall(function()
                        local f = owner:getForwardDirection()
                        if f ~= nil then
                            fx, fy = f:getX(), f:getY()
                            local d = math.sqrt(fx * fx + fy * fy)
                            if d > 0.001 then fx, fy = fx / d, fy / d end
                        end
                    end)
                    BridgeTask.hugFaceX, BridgeTask.hugFaceY = fx, fy
                end

                BridgeTask.hugPlayerHandMain = nil
                BridgeTask.hugPlayerHandSec = nil
                pcall(function()
                    BridgeTask.hugPlayerHandMain = owner:getPrimaryHandItem()
                    BridgeTask.hugPlayerHandSec = owner:getSecondaryHandItem()
                    owner:setPrimaryHandItem(nil)
                    owner:setSecondaryHandItem(nil)
                    owner:resetEquippedHandsModels()
                end)

                BridgeTask.hugStowed = false
                BridgeTask.hugHandMain = nil
                BridgeTask.hugHandSec = nil

                if BridgeWeapon ~= nil and BridgeWeapon.isOut(body) then
                    BridgeTask.hugHandMain = body:getPrimaryHandItem()
                    BridgeTask.hugHandSec = body:getSecondaryHandItem()
                    pcall(function() BridgeWeapon.putAway(body) end)
                    BridgeTask.hugStowed = true
                end

                BridgeAnim.dump("arm", body, v)
                BridgeTask.hugArmed = true
                BridgeTask.hugArmedAt = Bridge.time
                BridgeTask.hugRetries = 0
                BridgeTask.info = "hug: ready"
                return true
            end

            local why = playerReady(body, true)
            if why ~= nil then return cancelHug("hug " .. why) end

            holdPose(body, owner, v)

            local waited = Bridge.time - (BridgeTask.hugArmedAt or 0)
            if waited > BridgeAnim.PREP_MAX then return cancelHug("hug busy") end
            if waited >= BridgeAnim.PREP_TICKS and not playerBusy(owner) then
                BridgeAnim.dump("go", body, v)
                pcall(function() body:setVariable("BumpAnimFinished", false) end)
                pcall(function() body:setBumpType(v.bump) end)
                pcall(function() owner:playEmote(v.emote) end)
                pcall(function() if Bridge.lookShare ~= nil then Bridge.lookShare(body) end end)

                BridgeTask.hugPlaced = true
                BridgeTask.hugPlayerEmote = v.emote
                BridgeTask.hugAt = Bridge.time
                BridgeTask.hugEndAt = Bridge.time + math.floor((v.ms / 1000) * BridgeAnim.TICKS_PER_SEC) + BridgeAnim.END_BUFFER
                BridgeTask.hugRetryAt = Bridge.time + BridgeAnim.RETRY_TICKS
                BridgeTask.hugSettleAt = Bridge.time + 30
                BridgeTask.hugSettleLogged = false

                BridgeTask.info = "hug: playing " .. v.bump
                print("[BridgeAnim] playing " .. v.bump)
            end
            return true
        end

        local owner = BridgeData.owner()
        if owner == nil then return finishHug("no owner") end

        holdPose(body, owner, v)

        local moving, dead = false, false
        pcall(function()
            moving = owner:pressedMovement(false) == true
            dead = owner:isDead() == true
        end)
        if moving then return finishHug("player moved") end
        if dead then return finishHug("player dead") end

        if not BridgeTask.hugSettleLogged and BridgeTask.hugSettleAt ~= nil and Bridge.time >= BridgeTask.hugSettleAt then
            BridgeTask.hugSettleLogged = true
            BridgeAnim.dump("settle", body, v)
        end

        if BridgeTask.hugRetryAt ~= nil and Bridge.time >= BridgeTask.hugRetryAt then
            local busy = playerBusy(owner)
            local playing = false
            pcall(function()
                playing = owner:getVariableBoolean("EmotePlaying") == true
                    and owner:getVariableString("emote") == v.emote
            end)
            local retries = BridgeTask.hugRetries or 0
            if (not playing or busy) and retries < BridgeAnim.RETRY_MAX then
                if busy then
                    BridgeTask.hugRetryAt = Bridge.time + 6
                else
                    BridgeTask.hugRetries = retries + 1
                    pcall(function() owner:playEmote(v.emote) end)
                    BridgeTask.hugRetryAt = Bridge.time + BridgeAnim.RETRY_TICKS
                end
            else
                BridgeTask.hugRetryAt = nil
            end
        end

        if v.loopUntilStop == true then
            local waited = Bridge.time - (BridgeTask.hugAt or 0)
            local bt, asn = "", ""
            local fin = false
            pcall(function() bt = tostring(body:getBumpType()) end)
            pcall(function() asn = tostring(body:getActionStateName()) end)
            pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
            if not BridgeTask.hugLoopLogged and waited >= v.ms then
                BridgeTask.hugLoopLogged = true
                BridgeAnim.log("loop boundary bumpType=%s asn=%s finished=%s", bt, asn, tostring(fin))
            end
            if waited > 30 and Bridge.time >= (BridgeTask.hugNextBumpAt or 0) then
                if bt ~= v.bump or asn ~= "bumped" or fin then
                    pcall(function() body:setVariable("BumpAnimFinished", false) end)
                    pcall(function() body:setBumpType(v.bump) end)
                    BridgeTask.hugNextBumpAt = Bridge.time + 30
                    BridgeAnim.log("loop restart bump=%s was=%s asn=%s finished=%s", v.bump, bt, asn, tostring(fin))
                end
            end
        end

        local finished = false
        pcall(function() finished = body:getVariableBoolean("BumpAnimFinished") == true end)
        if v.loopUntilStop ~= true then
            if finished then return finishHug("anim end") end

            if Bridge.time >= (BridgeTask.hugEndAt or 0) then
                return finishHug("timer")
            end
        end
        return true
    end

    function BridgeTask.kinds.anim.leave(body)
        local owner = BridgeData.owner()
        local v = BridgeAnim.taskConfig()
        BridgeAnim.log("end reason=%s elapsed=%s", tostring(BridgeTask.hugEndReason or "?"),
            tostring(BridgeTask.hugAt ~= nil and (Bridge.time - BridgeTask.hugAt) or 0))
        BridgeAnim.dump("end", body, v)
        if owner ~= nil then
            local dead = false
            pcall(function() dead = owner:isDead() == true end)
            if not dead then
                local emote = nil
                pcall(function() emote = owner:getVariableString("emote") end)
                if emote == v.emote then
                    pcall(function() owner:setVariable("EmotePlaying", false) end)
                end
            end

            if BridgeTask.hugPlayerSolid ~= nil then
                pcall(function() owner:setSolid(BridgeTask.hugPlayerSolid) end)
            end

            local inv = nil
            pcall(function() inv = owner:getInventory() end)
            local function holds(item)
                if item == nil or inv == nil then return false end
                local yes = false
                pcall(function() yes = inv:contains(item) == true end)
                return yes
            end

            local main = BridgeTask.hugPlayerHandMain
            if main ~= nil and holds(main) then
                local cur = nil
                pcall(function() cur = owner:getPrimaryHandItem() end)
                if cur == nil then pcall(function() owner:setPrimaryHandItem(main) end) end
            end

            local sec = BridgeTask.hugPlayerHandSec
            if sec ~= nil and holds(sec) then
                local cur = nil
                pcall(function() cur = owner:getSecondaryHandItem() end)
                if cur == nil then pcall(function() owner:setSecondaryHandItem(sec) end) end
            end

            pcall(function() owner:resetEquippedHandsModels() end)
        end

        if body ~= nil then
            if BridgeTask.hugBodySolid ~= nil then
                pcall(function() body:setSolid(BridgeTask.hugBodySolid) end)
            end
            if BridgeTask.hugBodyCollidable ~= nil then
                pcall(function() body:setCollidable(BridgeTask.hugBodyCollidable) end)
            end
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
        BridgeTask.hugPlayerHandMain = nil
        BridgeTask.hugPlayerHandSec = nil
        BridgeTask.hugPlayerSolid = nil
        BridgeTask.hugBodySolid = nil
        BridgeTask.hugBodyCollidable = nil
        BridgeTask.hugPlayerEmote = nil
        BridgeTask.hugPlaced = nil
        BridgeTask.hugWait = nil
        BridgeTask.hugSpotX = nil
        BridgeTask.hugSpotY = nil
        BridgeTask.hugArmed = nil
        BridgeTask.hugArmedAt = nil
        BridgeTask.hugRetries = nil
        BridgeTask.hugRetryAt = nil
        BridgeTask.hugVariant = nil
        BridgeTask.hugSettleAt = nil
        BridgeTask.hugSettleLogged = nil
        BridgeTask.hugEndReason = nil
        BridgeTask.hugFaceX = nil
        BridgeTask.hugFaceY = nil
        BridgeTask.hugPlayerX = nil
        BridgeTask.hugPlayerY = nil
        BridgeTask.hugNextBumpAt = nil
        BridgeTask.hugLoopLogged = nil
    end
end

local function install()
    if BridgeTask == nil then return end
    if BridgeAnim.taskRegistered then return end
    BridgeAnim.taskRegistered = true
    registerAnimTask()
end

Events.OnGameStart.Add(install)

