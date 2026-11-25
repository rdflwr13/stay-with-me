BridgeLadder = BridgeLadder or {}

local function log(text)
    if BridgeLog == nil or not BridgeLog.on() then return end
    print("[BridgeLadder] " .. tostring(text))
end

local function spriteIsLadder(name)
    if name == nil then return false end
    local lower = string.lower(tostring(name))
    if string.find(lower, "ladder", 1, true) ~= nil then return true end
    local cfg = Bridge.CFG and Bridge.CFG.LADDER
    if cfg == nil then return false end
    for i = 1, #cfg.SPRITES do
        if string.find(lower, cfg.SPRITES[i], 1, true) ~= nil then return true end
    end
    return false
end

local function squareHasLadderFlag(square)
    if square == nil then return false end
    local cfg = Bridge.CFG and Bridge.CFG.LADDER
    if cfg == nil then return false end
    for i = 1, #cfg.FLAGS do
        local found = false
        pcall(function() found = square:has(cfg.FLAGS[i]) == true end)
        if found then return true end
    end
    return false
end

local function objectHasLadderFlag(obj)
    if obj == nil then return false end
    local cfg = Bridge.CFG and Bridge.CFG.LADDER
    if cfg == nil then return false end
    local found = false
    pcall(function()
        local props = obj:getProperties()
        if props == nil then return end
        for i = 1, #cfg.FLAGS do
            if props:has(cfg.FLAGS[i]) then
                found = true
                return
            end
        end
    end)
    return found
end

function BridgeLadder.near(x, y, zFrom, zTo)
    if x == nil or y == nil then return false end
    local z1 = zFrom or zTo
    local z2 = zTo or zFrom
    if z1 == nil or z2 == nil then return false end
    local cfg = Bridge.CFG and Bridge.CFG.LADDER
    if cfg == nil then return false end
    local zmin = math.floor(math.min(z1, z2)) - 1
    local zmax = math.floor(math.max(z1, z2)) + 1
    local centres = { { x, y } }
    local red = BridgeData.owner()
    if red ~= nil then
        local rx, ry = red:getX(), red:getY()
        if rx ~= nil and ry ~= nil and (math.abs(rx - x) > 0.01 or math.abs(ry - y) > 0.01) then
            centres[#centres + 1] = { rx, ry }
        end
    end
    local cell = getCell()
    if cell == nil then return false end
    for c = 1, #centres do
        local bx = math.floor(centres[c][1])
        local by = math.floor(centres[c][2])
        for dx = -cfg.RADIUS, cfg.RADIUS do
            for dy = -cfg.RADIUS, cfg.RADIUS do
                for z = zmin, zmax do
                    local square = cell:getGridSquare(bx + dx, by + dy, z)
                    if square ~= nil then
                        if squareHasLadderFlag(square) then return true end
                        local objects = nil
                        pcall(function() objects = square:getObjects() end)
                        if objects ~= nil then
                            local count = 0
                            pcall(function() count = objects:size() end)
                            for i = 0, count - 1 do
                                local obj = nil
                                pcall(function() obj = objects:get(i) end)
                                if obj ~= nil then
                                    if objectHasLadderFlag(obj) then return true end
                                    local name = nil
                                    pcall(function()
                                        local sprite = obj:getSprite()
                                        if sprite ~= nil then name = sprite:getName() end
                                    end)
                                    if spriteIsLadder(name) then return true end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

local LADDER_DIRS = {
    { IsoPropertyType.LADDER_N, IsoDirections.N, 0, -1 },
    { IsoPropertyType.LADDER_S, IsoDirections.S, 0, 1 },
    { IsoPropertyType.LADDER_W, IsoDirections.W, -1, 0 },
    { IsoPropertyType.LADDER_E, IsoDirections.E, 1, 0 },
}

local function ladderWalkable(square)
    if square == nil then return false end
    local ok = false
    pcall(function()
        ok = square:isSolidFloor() and not square:isSolid() and not square:isSolidTrans()
    end)
    return ok
end

local function ladderSameDir(ladder, prop)
    if ladder == nil then return false end
    local ok, has = pcall(function() return ladder:getProperties():has(prop) end)
    return ok and has == true
end

function BridgeLadder.route(cell, ladder, down, toZ)
    if cell == nil or ladder == nil then
        log("ladderRoute: no cell or ladder")
        return nil
    end
    local tile = nil
    pcall(function() tile = ladder:getSquare() end)
    if tile == nil then
        log("ladderRoute: ladder has no square")
        return nil
    end
    local dir = nil
    for i = 1, #LADDER_DIRS do
        if ladderSameDir(ladder, LADDER_DIRS[i][1]) then dir = LADDER_DIRS[i] break end
    end
    if dir == nil then
        log("ladderRoute: no ladder direction property")
        return nil
    end
    local x, y, z = tile:getX(), tile:getY(), tile:getZ()
    local bottom, topZ = z, z + 1
    local clamped = false
    if down then
        while not ladderWalkable(cell:getGridSquare(x, y, bottom)) do
            bottom = bottom - 1
            local square = cell:getGridSquare(x, y, bottom)
            if square == nil or not ladderSameDir(square:getLadder(), dir[1]) then
                log(string.format("ladderRoute: down shaft break at z%d", bottom))
                return nil
            end
        end
        if toZ ~= nil and toZ > bottom then
            bottom = toZ
            clamped = true
        end
    else
        if not ladderWalkable(tile) then
            log(string.format("ladderRoute: up base not walkable at z%d", z))
            return nil
        end
        while true do
            local square = cell:getGridSquare(x, y, topZ)
            if square == nil or not ladderSameDir(square:getLadder(), dir[1]) then break end
            if square:isSolidFloor() or square:isSolid() or square:isSolidTrans() then
                log(string.format("ladderRoute: up shaft solid at z%d", topZ))
                return nil
            end
            topZ = topZ + 1
        end
        if toZ ~= nil and toZ < topZ then
            topZ = toZ
            clamped = true
        end
    end
    local shaftTop = cell:getGridSquare(x, y, topZ)
    if shaftTop ~= nil and not clamped then
        local solid = false
        pcall(function() solid = shaftTop:isSolidFloor() or shaftTop:getLadder() ~= nil end)
        if solid then
            log(string.format("ladderRoute: shaft top occupied at z%d", topZ))
            return nil
        end
    end
    local dx, dy = dir[3], dir[4]
    local top = cell:getGridSquare(x + dx, y + dy, topZ)
    if not ladderWalkable(top) then
        log(string.format("ladderRoute: landing not walkable at %d,%d,z%d", x + dx, y + dy, topZ))
        return nil
    end
    local below = cell:getGridSquare(x, y, topZ - 1)
    local under, shaft = nil, nil
    pcall(function() under = top:getLadderUnder() end)
    pcall(function() shaft = below ~= nil and below:getLadder() or nil end)
    if under ~= shaft then
        log(string.format("ladderRoute: landing ladder mismatch at %d,%d,z%d", x + dx, y + dy, topZ))
        return nil
    end
    if shaftTop ~= nil then
        local blocked = false
        pcall(function() blocked = shaftTop:isSolid() or shaftTop:isSolidTrans() or shaftTop:isBlockedTo(top) end)
        if blocked then
            log(string.format("ladderRoute: shaft top blocked at z%d", topZ))
            return nil
        end
    end
    log(string.format("ladderRoute: ok dir=%s bottom=%d top=%d clamped=%s toZ=%s",
        tostring(dir[2]), bottom, topZ, tostring(clamped), tostring(toZ)))
    return {
        key = x .. "/" .. y .. "/" .. bottom .. "/" .. topZ .. "/" .. dx .. "/" .. dy,
        x = x, y = y, dx = dx, dy = dy, direction = dir[2],
        bottom = { x = x + 0.54, y = y + 0.60, z = bottom },
        top = { x = x + 0.54 + dx * 0.65, y = y + 0.60 + dy * 0.70, z = topZ },
    }
end

function BridgeLadder.hasDir(ladder)
    if ladder == nil then return false end
    local ok, has = pcall(function()
        local props = ladder:getProperties()
        return props ~= nil and (props:has(IsoPropertyType.LADDER_N) or props:has(IsoPropertyType.LADDER_S)
            or props:has(IsoPropertyType.LADDER_E) or props:has(IsoPropertyType.LADDER_W))
    end)
    return ok and has == true
end

function BridgeLadder.square(worldobjects)
    for _, o in ipairs(worldobjects or {}) do
        local sq = nil
        pcall(function() sq = o:getSquare() end)
        if sq ~= nil then
            local up, dn = nil, nil
            pcall(function() up = sq:getLadder() end)
            pcall(function() dn = sq:getLadderUnder() end)
            if BridgeLadder.hasDir(up) or BridgeLadder.hasDir(dn) then return sq, up, dn end
        end
    end
    return nil, nil, nil
end

function BridgeLadder.tryFollowClimb(red, z, pull)
    if pull == nil or pull.kind ~= "ladder" then return false end
    local body = Bridge.body
    local bodyZ = nil
    pcall(function() bodyZ = body:getZ() end)
    local toZ = math.floor(z)
    local down = z < pull.fromZ - 0.5
    local onFromFloor = bodyZ ~= nil and math.floor(bodyZ) == math.floor(pull.fromZ)
    local near = false
    pcall(function()
        local dx = body:getX() - red:getX()
        local dy = body:getY() - red:getY()
        near = (dx * dx + dy * dy) <= 64
    end)
    local fighting = false
    pcall(function()
        fighting = (BridgeFight ~= nil
                and (BridgeFight.target ~= nil or BridgeFight.state == "swing"))
            or (BridgeGunfight ~= nil
                and (BridgeGunfight.target ~= nil or BridgeGunfight.drawn == true))
    end)
    local noClimb = bodyZ ~= nil and math.floor(bodyZ) == toZ
    log(string.format(
        "ladder follow: kind=%s fromZ=%.2f z=%.2f toZ=%d down=%s bodyZ=%s onFromFloor=%s near=%s fighting=%s noClimb=%s",
        tostring(pull.kind), pull.fromZ, z, toZ, tostring(down), tostring(bodyZ),
        tostring(onFromFloor), tostring(near), tostring(fighting), tostring(noClimb)))
    if noClimb then
        Bridge.floorPull = nil
        Bridge.floorMismatchSince = nil
        return true
    end
    if not (onFromFloor and near and not fighting) then return false end
    local sq = nil
    pcall(function()
        sq = getCell():getGridSquare(math.floor(pull.fromX), math.floor(pull.fromY), math.floor(pull.fromZ))
    end)
    local ladder = nil
    if sq ~= nil then
        pcall(function()
            if down then
                ladder = sq:getLadderUnder() or sq:getLadder()
            else
                ladder = sq:getLadder() or sq:getLadderUnder()
            end
        end)
    end
    log(string.format("ladder follow: sq=%s ladder=%s", tostring(sq ~= nil), tostring(ladder ~= nil)))
    local route = nil
    if ladder ~= nil then
        pcall(function() route = BridgeLadder.route(getCell(), ladder, down, toZ) end)
    end
    log(string.format("ladder follow: route=%s", tostring(route ~= nil)))
    if route == nil then return false end
    local res = BridgeTask.start("climbLadder", { {
        x = math.floor(pull.fromX), y = math.floor(pull.fromY),
        z = math.floor(pull.fromZ), ladder = ladder, down = down, toZ = toZ,
    } })
    log(string.format("ladder follow: start=%s", tostring(res)))
    if res ~= "started" then return false end
    Bridge.floorPull = nil
    Bridge.floorMismatchSince = nil
    if BridgeCallout ~= nil and type(BridgeCallout.climb) == "function" then
        pcall(function() BridgeCallout.climb(down and "down" or "up") end)
    end
    return true
end

local LADDER_CLIP = { mountBottom = 0.6, mountTop = 2.267, leaveBottom = 0.5, leaveTop = 2.167 }
local LADDER_SPEED = 0.42
local LADDER_SOUND_GAP = 0.45

local function ladderCanClimb(body)
    if body == nil then return false end
    local ok = true
    local function bad(fn)
        local good, val = pcall(fn)
        if good and val == true then ok = false end
    end
    bad(function() return body:isDead() end)
    bad(function() return body:isCrawling() end)
    bad(function() return body:isOnFloor() end)
    bad(function() return body:isKnockedDown() end)
    bad(function() return body:hasHitReaction() end)
    bad(function() return body:isRagdoll() end)
    bad(function() return body:isBeingGrappled() end)
    bad(function() return body:isOnFire() end)
    bad(function() return body:isReanimatedPlayer() end)
    local sq = nil
    pcall(function() sq = body:getCurrentSquare() end)
    if sq == nil then ok = false end
    return ok
end

local function ladderPlayerBusy(route)
    local owner = BridgeData.owner()
    if owner == nil or route == nil then return false end
    local sig = nil
    pcall(function() sig = Bridge.climbSignal(owner) end)
    if sig == nil then return false end
    local ox, oy, oz = owner:getX(), owner:getY(), owner:getZ()
    local function near(p)
        if p == nil then return false end
        return math.abs(oz - p.z) < 1.5 and (ox - p.x) * (ox - p.x) + (oy - p.y) * (oy - p.y) < 4
    end
    return near(route.bottom) or near(route.top)
end

local function ladderSetPhase(body, phase)
    BridgeTask.ladderElapsed = 0
    BridgeTask.ladderTickAt = Bridge.time
    pcall(function() body:clearVariable("SWMLadderDone") end)
    pcall(function() body:setVariable("SWMLadderPhase", phase) end)
    BridgeTask.U.log("climb: phase " .. tostring(phase))
    if BridgeMove ~= nil and type(BridgeMove.sendLadder) == "function" then
        pcall(BridgeMove.sendLadder, phase)
    end
end

local function ladderSetPosition(body, x, y, z)
    local cell = getCell()
    if cell == nil then return false end
    local sx, sy, sz = math.floor(x), math.floor(y), math.floor(z)
    local square = cell:getGridSquare(sx, sy, sz) or cell:getGridSquare(sx, sy, sz - 1)
    if square == nil then return false end
    pcall(function()
        body:setX(x) body:setY(y) body:setZ(z)
        body:setNextX(x) body:setNextY(y)
        body:setCurrent(square)
    end)
    return true
end

local function ladderCleanup(body, completed)
    local from = BridgeTask.ladderFrom
    local ignore = BridgeTask.ladderIgnoreMovement
    local deferred = BridgeTask.ladderDeferredMovement
    BridgeTask.U.log(string.format("climb: end completed=%s fromZ=%s bodyZ=%s",
        tostring(completed), tostring(from ~= nil and from.z or nil),
        tostring(body ~= nil and body:getZ() or nil)))
    pcall(function() body:clearVariable("SWMLadderPhase") end)
    pcall(function() body:clearVariable("SWMLadderDone") end)
    pcall(function() body:setUseless(false) end)
    pcall(function() body:setbClimbing(false) end)
    if ignore ~= nil then pcall(function() body:setIgnoreMovement(ignore) end) end
    if deferred ~= nil then pcall(function() body:setDeferredMovementEnabled(deferred) end) end
    pcall(function() body:setCollidable(true) end)
    if BridgeMove ~= nil and type(BridgeMove.sendLadder) == "function" then
        pcall(BridgeMove.sendLadder, nil)
    end
    BridgeTask.ladderPlan = nil
    BridgeTask.ladderDown = nil
    BridgeTask.ladderEntry = nil
    BridgeTask.ladderExit = nil
    BridgeTask.ladderStartX, BridgeTask.ladderStartY = nil, nil
    BridgeTask.ladderFrom = nil
    BridgeTask.ladderIgnoreMovement = nil
    BridgeTask.ladderDeferredMovement = nil
    BridgeTask.ladderElapsed = nil
    BridgeTask.ladderSoundAt = nil
    BridgeTask.ladderTickAt = nil
    BridgeTask.phase = nil
    if not completed and from ~= nil then
        BridgeTask.U.placeAt(body, from.x, from.y, from.z)
    end
    if completed and BridgeTask.restoreHands ~= nil then
        pcall(BridgeTask.restoreHands, body)
    end
    if BridgeRoute ~= nil then BridgeRoute.reset() end
end

local function ladderBegin(body)
    pcall(function() BridgeMove.stopPath(body) end)
    if BridgeMove ~= nil then BridgeMove.moving = false end
    BridgeTask.clearPoseHands(body)
    BridgeTask.ladderStartX, BridgeTask.ladderStartY = body:getX(), body:getY()
    BridgeTask.ladderFrom = { x = body:getX(), y = body:getY(), z = body:getZ() }
    local ignore, deferred = false, true
    pcall(function() ignore = body:getIgnoreMovement() end)
    pcall(function() deferred = body:isDeferredMovementEnabled() end)
    BridgeTask.ladderIgnoreMovement = ignore
    BridgeTask.ladderDeferredMovement = deferred
    pcall(function() body:setTarget(nil) end)
    pcall(function() body:setDefaultState() end)
    pcall(function() body:setUseless(true) end)
    pcall(function() body:setIgnoreMovement(true) end)
    pcall(function() body:setDeferredMovementEnabled(false) end)
    pcall(function() body:setbClimbing(true) end)
    pcall(function() body:setCollidable(false) end)
    BridgeTask.ladderSoundAt = 0
    BridgeTask.phase = BridgeTask.ladderDown and "mountTop" or "mountBottom"
    BridgeTask.U.log(string.format("climb: mount start down=%s phase=%s start=%.2f,%.2f,%.2f",
        tostring(BridgeTask.ladderDown), tostring(BridgeTask.phase),
        BridgeTask.ladderStartX or 0, BridgeTask.ladderStartY or 0, body:getZ()))
    ladderSetPhase(body, BridgeTask.phase)
    return true
end

local function ladderLerp(a, b, f)
    return a + (b - a) * f
end

local function climbTick(body)
    local plan = BridgeTask.ladderPlan
    if plan == nil then return "failed" end
    local state = ""
    pcall(function() state = tostring(body:getActionStateName()) end)
    if not ladderCanClimb(body) then
        BridgeTask.U.log("climb: abort canClimb=false state=" .. tostring(state))
        ladderCleanup(body, false)
        return "failed"
    end
    if state ~= "idle" then pcall(function() body:setDefaultState() end) end

    local now = Bridge.time
    local last = BridgeTask.ladderTickAt or now
    BridgeTask.ladderTickAt = now
    local dt = (now - last) / BridgeTask.K.SECOND
    if dt < 0 then dt = 0 end
    if dt > 0.25 then dt = 0.25 end
    BridgeTask.ladderElapsed = (BridgeTask.ladderElapsed or 0) + dt

    local phase = BridgeTask.phase
    local bottom, top = plan.bottom, plan.top
    local shaftZ = top.z - 0.6
    local x, y, z = bottom.x, bottom.y, bottom.z
    local nextPhase = nil
    local clip = LADDER_CLIP[phase]
    if clip ~= nil then
        local fraction = math.min(BridgeTask.ladderElapsed / clip, 1)
        local done = false
        pcall(function() done = body:getVariableString("SWMLadderDone") == phase end)
        if BridgeTask.ladderElapsed >= clip + 0.55 then done = true end
        if done then fraction = 1 end
        if phase == "mountBottom" then
            x = ladderLerp(BridgeTask.ladderStartX or x, x, fraction)
            y = ladderLerp(BridgeTask.ladderStartY or y, y, fraction)
            nextPhase = "up"
        elseif phase == "mountTop" then
            local across = math.min(math.max((fraction - 0.20) / 0.60, 0), 1)
            x = ladderLerp(BridgeTask.ladderStartX or x, x, across)
            y = ladderLerp(BridgeTask.ladderStartY or y, y, across)
            z = ladderLerp(top.z, shaftZ, math.max((fraction - 0.30) / 0.70, 0))
            nextPhase = "down"
        elseif phase == "leaveTop" then
            local across = math.max((fraction - 0.30) / 0.70, 0)
            x = ladderLerp(x, top.x, across)
            y = ladderLerp(y, top.y, across)
            z = ladderLerp(shaftZ, top.z, fraction)
        end
        if (phase == "mountTop" or phase == "leaveTop")
                and (math.floor(x) ~= plan.x or math.floor(y) ~= plan.y) then
            z = top.z
        end
        if not done then nextPhase = phase end
    elseif phase == "up" then
        z = math.min(bottom.z + BridgeTask.ladderElapsed * LADDER_SPEED, shaftZ)
        nextPhase = z >= shaftZ and "leaveTop" or phase
    else
        z = math.max(shaftZ - BridgeTask.ladderElapsed * LADDER_SPEED, bottom.z)
        nextPhase = z <= bottom.z and "leaveBottom" or phase
    end

    pcall(function() body:setDir(plan.direction) end)
    pcall(function() body:setForwardDirection(plan.dx, plan.dy) end)
    pcall(function() body:setCollidable(false) end)
    if not ladderSetPosition(body, x, y, z) then
        BridgeTask.U.log(string.format("climb: abort no square x=%.2f y=%.2f z=%.2f", x, y, z))
        ladderCleanup(body, false)
        return "failed"
    end
    if nextPhase == nil then
        ladderCleanup(body, true)
        return "done"
    end
    if nextPhase ~= phase then
        BridgeTask.phase = nextPhase
        ladderSetPhase(body, nextPhase)
    end
    if (phase == "up" or phase == "down")
            and BridgeTask.ladderElapsed >= (BridgeTask.ladderSoundAt or 0) then
        BridgeTask.ladderSoundAt = BridgeTask.ladderElapsed + LADDER_SOUND_GAP
        if BridgeSound ~= nil and type(BridgeSound.sfx) == "function" then
            pcall(function() BridgeSound.sfx(body, "LadderFootstepsWood") end)
        end
    end
    return "climbing"
end

local function ladderClimb(body)
    local st = climbTick(body)
    if st == "climbing" then
        BridgeTask.info = "climb: " .. tostring(BridgeTask.phase)
        return true
    end
    return BridgeTask.finish()
end

BridgeLadder.kind = {}
BridgeLadder.kind.holdThreat = true

function BridgeLadder.kind.available(body)
    return BridgeTask.LADDER_ENABLED == 1
end

function BridgeLadder.kind.missing(body)
    return nil
end

function BridgeLadder.kind.update(body)
    if BridgeTask.LADDER_ENABLED ~= 1 then return BridgeTask.finish() end
    if body == nil then return BridgeTask.finish() end
    local plan = BridgeTask.ladderPlan
    if plan == nil then
        local target = BridgeTask.current
        if target == nil then
            if #BridgeTask.queue == 0 then return BridgeTask.finish() end
            target = table.remove(BridgeTask.queue, 1)
            BridgeTask.current = target
        end
        local ladder = target.ladder
        local cell = getCell()
        local sq = nil
        pcall(function() sq = cell ~= nil and cell:getGridSquare(target.x, target.y, target.z) or nil end)
        if sq ~= nil then
            local fresh = nil
            pcall(function() fresh = target.down and sq:getLadderUnder() or sq:getLadder() end)
            if fresh ~= nil then ladder = fresh end
        end
        local route = nil
        pcall(function() route = BridgeLadder.route(cell, ladder, target.down, target.toZ) end)
        if route == nil then
            BridgeTask.info = "climb: no route"
            BridgeTask.U.log(string.format("climb: no route down=%s toZ=%s ladder=%s",
                tostring(target.down), tostring(target.toZ), tostring(target.ladder ~= nil)))
            BridgeTask.current = nil
            BridgeTask.phase = nil
            if #BridgeTask.queue > 0 then return true end
            return BridgeTask.finish()
        end
        BridgeTask.U.log(string.format("climb: route down=%s toZ=%s bottom=%s top=%s",
            tostring(target.down), tostring(target.toZ),
            tostring(route.bottom ~= nil and route.bottom.z or nil),
            tostring(route.top ~= nil and route.top.z or nil)))
        if ladderPlayerBusy(route) then
            BridgeTask.info = "climb: player on ladder"
            BridgeTask.U.log("climb: player on ladder")
            BridgeTask.current = nil
            BridgeTask.phase = nil
            if #BridgeTask.queue > 0 then return true end
            return BridgeTask.finish()
        end
        BridgeTask.ladderPlan = route
        BridgeTask.ladderDown = target.down == true
        BridgeTask.ladderEntry = BridgeTask.ladderDown and route.top or route.bottom
        BridgeTask.ladderExit = BridgeTask.ladderDown and route.bottom or route.top
        BridgeTask.phase = "walk"
        BridgeTask.since = Bridge.time
        BridgeTask.progressAt = Bridge.time
        BridgeTask.bestD = nil
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
        BridgeTask.still = 0
        BridgeTask.checkX, BridgeTask.checkY = nil, nil
        BridgeRoute.state.spot = nil
        return true
    end

    if BridgeTask.phase == "walk" then
        local entry = BridgeTask.ladderEntry
        local walk, why = BridgeTask.walkTo(body, entry, BridgeTask.STOP_DIST, true, not BridgeTask.ladderDown)
        if walk == "unreachable" then
            BridgeTask.info = "climb: no path"
            BridgeTask.U.log("climb: entry unreachable " .. tostring(why))
            ladderCleanup(body, false)
            return BridgeTask.finish()
        end
        if walk == "arrived" then
            return ladderBegin(body)
        end
        BridgeTask.info = "climb: walking to ladder"
        return true
    end

    return ladderClimb(body)
end

function BridgeLadder.kind.leave(body)
    if BridgeTask.ladderPlan ~= nil or BridgeTask.phase ~= nil then
        ladderCleanup(body, false)
    end
end

local TASK_LADDER_RADIUS = 12

function BridgeLadder.findRoute(body, toZ)
    if body == nil or toZ == nil then return nil, nil end
    local cell = getCell()
    if cell == nil then return nil, nil end
    local bx, by = math.floor(body:getX()), math.floor(body:getY())
    local bz = math.floor(body:getZ())
    for dx = -TASK_LADDER_RADIUS, TASK_LADDER_RADIUS do
        for dy = -TASK_LADDER_RADIUS, TASK_LADDER_RADIUS do
            local sq = cell:getGridSquare(bx + dx, by + dy, bz)
            if sq ~= nil then
                local up = nil
                pcall(function() up = sq:getLadder() end)
                if up ~= nil then
                    local route = BridgeLadder.route(cell, up, false, toZ)
                    if route ~= nil and math.floor(route.top.z) == math.floor(toZ) then
                        return route, false
                    end
                end
                local dn = nil
                pcall(function() dn = sq:getLadderUnder() end)
                if dn ~= nil then
                    local route = BridgeLadder.route(cell, dn, true, toZ)
                    if route ~= nil and math.floor(route.bottom.z) == math.floor(toZ) then
                        return route, true
                    end
                end
            end
        end
    end
    return nil, nil
end

function BridgeLadder.beginSegment(body)
    return ladderBegin(body)
end

function BridgeLadder.climbSegment(body)
    return climbTick(body)
end

function BridgeLadder.cleanupSegment(body, completed)
    ladderCleanup(body, completed)
end

if BridgeTask ~= nil and BridgeTask.kinds ~= nil then
    BridgeTask.kinds.climbLadder = BridgeLadder.kind
end
