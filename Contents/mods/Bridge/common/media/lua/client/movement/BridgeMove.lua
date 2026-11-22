



BridgeMove = BridgeMove or {}

local SPOT = {}
local SEAT = {}
local MOURN = {}
local NAV = {}
local DOOR = {}
local ASIDE = {}
local RUN = {}
local CROSS = {}
local STRAIGHT = {}
local SLOW = {}
local DOORWAY = {}
local CHAIR = {}

local FOLLOW_START = 2.0
local FOLLOW_STOP = 0.9
local FOLLOW_GAP = 1.2
RUN.DIST = 3.5
RUN.STOP = 2.0
local FOLLOW_SPRINT_HOLD = 30
local FOLLOW_SPRINT_RATE = 0.08

BridgeMove.moving = false
BridgeMove.pathing = false
BridgeMove.goal = nil
BridgeMove.lastPath = 0
BridgeMove.walkType = "Walk"
BridgeMove.pathResult = "none"
BridgeMove.obstacle = "none"
BridgeMove.window = nil
BridgeMove.redAt = nil
BridgeMove.redPrev = nil

local redPrevSlot = {}
local redPrevPosSlot = {}







ASIDE.AHEAD = 1.0
ASIDE.PUSH = 10
local PUSH_GRACE = 12
ASIDE.PATH = 0.55
ASIDE.STEP = 0.5
ASIDE.MAX = 45
ASIDE.QUIET = 45

local BACK = { step = 1.2, leash = 2.5, max = 120, quiet = 12, stall = 20, gain = 0.05, bump = "FollowWalkBwd" }


RUN.AHEAD = 2.5
RUN.PATH = 0.7
local COMING_COS = 0.5
BridgeMove.redStep = 0
BridgeMove.redHist = nil
local RED_WIN = 5
BridgeMove.redMoving = false
BridgeMove.speed = 1.0
BridgeMove.wasWalking = false
BridgeMove.restarts = 0

BridgeMove.replanDist = 0.6
BridgeMove.pathEvery = 15
BridgeMove.speedMode = "fixed"
BridgeMove.fixedSpeed = 1.0
BridgeMove.startBump = "off"
BridgeMove.traceUntil = 0
BridgeMove.climbUntil = 0
BridgeMove.stepTick = -9999
BridgeMove.stepPos = nil
BridgeMove.stride = false

BridgeMove.blendOverride = nil
BridgeMove.speedModOverride = nil
BridgeMove.animOld = false
BridgeMove.walkSpeedVar = 1.0
BridgeMove.runBlend = 0.65
BridgeMove.walkBlend = 0.78
BridgeMove.runReplan = 1.8
BridgeMove.runEvery = 30
BridgeMove.lastRestart = -9999
BridgeMove.steerMode = true
BridgeMove.navEnabled = true
BridgeMove.steering = false
BridgeMove.trail = {}
BridgeMove.redSpeed = 0
BridgeMove.stepPerMul = 0.07
BridgeMove.walkFrames = 0
BridgeMove.follow = {kind = "none", s = 0, want = 0, gap = 0}
BridgeMove.sprintSince = nil
BridgeMove.followPriorityHold = false
BridgeMove.noCollide = false
BridgeMove.collideOff = false
BridgeMove.bumpMove = "face"
BridgeMove.followWs = nil
BridgeMove.backActive = false
BridgeMove.turnLimit = nil
BridgeMove.doorGhost = true




BridgeMove.speedModel = {
    Walk = { a = 0.024, b = 0.015 }, Run = { a = 0.030, b = 0.057 },
    WalkSneak = { a = 0.024, b = 0.007 }, RunSneak = { a = 0.028, b = 0.034 },
}






BridgeMove.catchUp = true
BridgeMove.aheadPivot = false
BridgeMove.speedScale = 1.0
BridgeMove.speedScaleN = 0


local MEM = {}
MEM.lastLogText = nil
local function log(text)
    if BridgeLog == nil or not BridgeLog.on() then return end
    text = tostring(text)
    if text == MEM.lastLogText then return end
    MEM.lastLogText = text
    print("[BridgeMove] " .. text)
end
local function warn(text) print("[BridgeMove] " .. tostring(text)) end


function BridgeMove.followDebug(tag, body, why, pend, force)
    if not force and (BridgeGunfight == nil or BridgeGunfight.magCareStage == nil) then return end
    if body == nil then return end
    if BridgeLog == nil or not BridgeLog.on() then return end
    local now = Bridge.time or 0
    local key = tostring(tag) .. "|" .. tostring(why) .. "|" .. tostring(BridgeMove.moving)
        .. "|" .. tostring(BridgeMove.steering) .. "|" .. tostring(BridgeMove.pathing)
    if not force and BridgeMove.followDbgKey == key and now - (BridgeMove.followDbgAt or -999) < 10 then return end
    BridgeMove.followDbgKey, BridgeMove.followDbgAt = key, now
    local bump, asn, bmoving = "?", "?", "?"
    pcall(function()
        bump = tostring(body:getBumpType())
        asn = tostring(body:getActionStateName())
        bmoving = tostring(body:getVariableBoolean("bMoving"))
    end)
    local red = nil
    pcall(function() red = BridgeData.owner() end)
    local d = -1
    if red ~= nil then
        pcall(function()
            local dx, dy = body:getX() - red:getX(), body:getY() - red:getY()
            d = math.sqrt(dx * dx + dy * dy)
        end)
    end
    local care, flee = "nil", "false"
    if BridgeGunfight ~= nil then
        care = tostring(BridgeGunfight.magCareStage)
        flee = tostring(BridgeGunfight.reloadFlee)
    end
    local onPath = false
    if type(BridgeMove.onPath) == "function" then onPath = BridgeMove.onPath() == true end
    log(string.format("FOLLOWDBG %s why=%s t=%d bump=%s asn=%s bMoving=%s mv=%s steer=%s path=%s onPath=%s pend=%s d=%.2f redMoving=%s care=%s flee=%s",
        tostring(tag), tostring(why), now, bump, asn, bmoving, tostring(BridgeMove.moving),
        tostring(BridgeMove.steering), tostring(BridgeMove.pathing), tostring(onPath),
        tostring(pend), d, tostring(BridgeMove.redMoving), care, flee))
end


function BridgeMove.followPriority(body, red)
    if not Bridge.follow or Bridge.mode ~= "follow" then
        local wasHold = BridgeMove.followPriorityHold == true
        BridgeMove.sprintSince = nil
        BridgeMove.followPriorityHold = false
        if wasHold and BridgeGunfight ~= nil and type(BridgeGunfight.endFollowHold) == "function" then
            pcall(BridgeGunfight.endFollowHold)
        end
        return false
    end
    if body == nil or red == nil then return false end
    local sprinting = false
    pcall(function() sprinting = red:isSprinting() == true end)
    if not sprinting and (BridgeMove.redSpeed or 0) >= FOLLOW_SPRINT_RATE then sprinting = true end
    if sprinting then
        if BridgeMove.sprintSince == nil then
            BridgeMove.sprintSince = Bridge.time or 0
            if Bridge.verbose then log("follow priority: sprint hold start") end
        end
        if not BridgeMove.followPriorityHold
                and (Bridge.time or 0) - BridgeMove.sprintSince >= FOLLOW_SPRINT_HOLD then
            BridgeMove.followPriorityHold = true
            if Bridge.verbose then log("follow priority: engaged after sprint hold") end
        end
    else
        BridgeMove.sprintSince = nil
    end
    if not BridgeMove.followPriorityHold then return false end
    if BridgeFight ~= nil and BridgeFight.state == "swing" then return false end
    local d = 0
    pcall(function()
        local dx, dy = body:getX() - red:getX(), body:getY() - red:getY()
        d = math.sqrt(dx * dx + dy * dy)
    end)
    if BridgeGunfight ~= nil then
        local away = BridgeMove.redMoving == true and (BridgeMove.redSpeed or 0) >= FOLLOW_SPRINT_RATE
        if not away and (BridgeGunfight.fireUntil ~= nil or BridgeGunfight.pendingShot ~= nil) then
            return false
        end
    end
    if not sprinting and d <= FOLLOW_STOP + 0.5 then
        BridgeMove.followPriorityHold = false
        BridgeMove.sprintSince = nil
        if BridgeGunfight ~= nil and type(BridgeGunfight.endFollowHold) == "function" then
            pcall(BridgeGunfight.endFollowHold)
        end
        if Bridge.verbose then log("follow priority: released") end
        return false
    end
    return true
end




local rawFormat = string.format
local function sformat(f, ...)
    local args = { ... }
    local n = select("#", ...)
    local i = 0
    for spec in string.gmatch(f, "%%[-+ #0]*%d*%.?%d*([%a%%])") do
        if spec ~= "%" then
            i = i + 1
            local v = args[i]
            if (spec == "d" or spec == "i") and type(v) == "number" and v ~= math.floor(v) then
                args[i] = math.floor(v + 0.5)
            end
        end
    end
    return rawFormat(f, (table.unpack or unpack)(args, 1, n))
end







local function frameDt()
    local dt = Bridge.dt
    if type(dt) ~= "number" or dt ~= dt or dt <= 0 then return 1 end
    return dt
end
BridgeMove.frameDt = frameDt





local function wrapPi(a)
    return a - 2 * math.pi * math.floor((a + math.pi) / (2 * math.pi))
end
BridgeMove.wrapPi = wrapPi

local function dist2d(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end



local function setStride(body, on)
    if on == BridgeMove.stride then return end
    BridgeMove.stride = on
    pcall(function() body:setVariable("NotAloneStride", on) end)
end

local function trackStep(body)
    local px, py = body:getX(), body:getY()
    local prev = BridgeMove.stepPos
    if prev ~= nil then
        local dx, dy = px - prev.x, py - prev.y
        if dx * dx + dy * dy > 0.0001 then BridgeMove.stepTick = Bridge.time end
    end
    BridgeMove.stepPos = { x = px, y = py }
    setStride(body, BridgeMove.pathing and (Bridge.time - BridgeMove.stepTick) < 20)
end







function BridgeMove.setCollide(body, on)


    if on then
        if not BridgeMove.collideOff then return end
        BridgeMove.collideOff = false
        pcall(function() body:setCollidable(true) end)
        return
    end
    BridgeMove.collideOff = true
    pcall(function() body:setCollidable(false) end)
end



local function isFollowBump(bump)
    return bump == "FollowWalk" or bump == "FollowRun"
end





function BridgeMove.turnToward(body, px, py, maxDeg)
    if BridgeMove.turnLimit == nil then
        pcall(function() body:faceLocationF(px, py) end)
        return
    end
    maxDeg = BridgeMove.turnLimit
    pcall(function()
        local bx, by = body:getX(), body:getY()
        local tx, ty = px - bx, py - by
        local tl = math.sqrt(tx * tx + ty * ty)
        if tl < 0.01 then return end
        local fwd = body:getForwardDirection()
        local fx, fy = fwd:getX(), fwd:getY()
        local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
        local cur = atan2(fy, fx)
        local want = atan2(ty, tx)
        local diff = wrapPi(want - cur)
        local lim = math.rad((maxDeg or 18) * frameDt())
        if diff > lim then diff = lim elseif diff < -lim then diff = -lim end
        local a = cur + diff
        body:faceLocationF(bx + math.cos(a), by + math.sin(a))
    end)
end







local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
function BridgeMove.pivotToward(body, px, py, maxDeg)
    local ok, left = pcall(function()
        local tx, ty = px - body:getX(), py - body:getY()
        if tx * tx + ty * ty < 0.0001 then return 0 end
        local cur = body:getAnimAngleRadians()
        local diff = wrapPi(atan2(ty, tx) - cur)

        local lim = math.rad(maxDeg * frameDt())
        local step = diff
        if step > lim then step = lim elseif step < -lim then step = -lim end
        body:setTargetAndCurrentDirection(math.cos(cur + step), math.sin(cur + step))
        return math.abs(diff - step)
    end)
    if ok then return left end

    if not BridgeMove.pivotFailed then
        BridgeMove.pivotFailed = true
        warn("seat: pivot failed, turning as before: " .. tostring(left))
    end
    return nil
end



function BridgeMove.facingOff(body, px, py)
    local ok, deg = pcall(function()
        local cur = body:getAnimAngleRadians()
        local diff = wrapPi(atan2(py - body:getY(), px - body:getX()) - cur)
        return math.floor(math.abs(math.deg(diff)) + 0.5)
    end)
    if ok then return deg end
    return nil
end

function BridgeMove.followBump(body, walk)
    local want = walk == "Run" and "FollowRun" or "FollowWalk"
    BridgeMove.followDebug("followBump", body, want)
    pcall(function()
        body:setVariable("bPathfind", false)
        body:setMoving(false)
        if tostring(body:getBumpType()) ~= want then
            body:setVariable("BumpAnimFinished", false)
            body:setBumpType(want)
        end
    end)

    if BridgeFastForward ~= nil then pcall(BridgeFastForward.keepMoving, body) end
end


function BridgeMove.endFollowBump(body, to)
    pcall(function()
        if isFollowBump(tostring(body:getBumpType())) then
            BridgeMove.followDebug("endFollowBump", body, tostring(to))
            if to == "" then



                local flagged = BridgeFastForward ~= nil and BridgeFastForward.flagged == body
                    and tostring(body:getActionStateName()) == "bumped"
                if flagged then BridgeMove.startKick(body) else BridgeMove.releaseBump(body) end
            else
                body:setBumpType(to)
            end
        end
    end)
end






function BridgeMove.releaseBump(body)
    pcall(function()
        if tostring(body:getActionStateName()) == "bumped" then body:setVariable("BumpAnimFinished", true) end
        body:setBumpType("")
    end)
end









local KICK = "StartMove"
local KICK_MAX = 50
BridgeMove.KICK = KICK

function BridgeMove.startKick(body)



    pcall(function()
        local asn = tostring(body:getActionStateName())
        if asn ~= "walktoward" and asn ~= "pathfind" then body:setMoving(false) end
    end)
    pcall(function()
        body:setVariable("BumpAnimFinished", false)
        body:setBumpType(KICK)
    end)
    BridgeMove.kickAt = Bridge.time
    BridgeMove.kickIn = false
end





function BridgeMove.kickStep(body, pf)
    if BridgeMove.kickAt == nil then return end
    local bump, asn = "", ""
    pcall(function()
        bump = tostring(body:getBumpType())
        asn = tostring(body:getActionStateName())
    end)
    if bump ~= KICK then BridgeMove.kickAt = nil return end
    if asn == "bumped" then BridgeMove.kickIn = true end
    local found = false


    local forced = BridgeFastForward ~= nil and BridgeFastForward.forcedMove ~= nil
    pcall(function() found = pf:hasStartedMoving() or (body:isMoving() and not forced) end)
    local ready = found and BridgeMove.kickIn
    if ready or Bridge.time - BridgeMove.kickAt >= KICK_MAX then
        BridgeMove.releaseBump(body)
        if Bridge.verbose then
            log(string.format("start from standing: %s after %.2f s", ready and "path ready, moving"
                or (found and ("path ready, never in the stance (state " .. asn .. "), released")
                or "no path yet, released"), (Bridge.time - BridgeMove.kickAt) / 60))
        end
        BridgeMove.kickAt = nil
    end
end




function BridgeMove.onPath()
    return BridgeMove.pathing or BridgeMove.steering or BridgeMove.kickAt ~= nil
end

function BridgeMove.stopPath(body)
    BridgeMove.setCollide(body, true)
    if BridgeMove.steering then BridgeMove.endFollowBump(body, "Stand") end

    if BridgeMove.kickAt ~= nil then
        pcall(function() if tostring(body:getBumpType()) == KICK then body:setBumpType("Stand") end end)
        BridgeMove.kickAt = nil
    end
    pcall(function()
        local pf = body:getPathFindBehavior2()
        pf:cancel()
        pf:reset()
        body:setPath2(nil)
    end)
    if BridgeMove.steering then
        pcall(function() body:setMoving(false) end)
        BridgeMove.steering = false
    end
    BridgeMove.pathing = false
    BridgeMove.goal = nil
    BridgeMove.redAt = nil
    BridgeMove.forceCross = false
    BridgeMove.wasWalking = false
    setStride(body, false)

    if BridgeFastForward ~= nil then pcall(BridgeFastForward.keepMoving, body) end
end













MEM.nearCache = nil
local function nearRed(red, body)
    local rx, ry = math.floor(red:getX()), math.floor(red:getY())
    local rz = red:getZ()
    local bx, by = body:getX(), body:getY()
    local key = rx .. "," .. ry .. "," .. math.floor(rz) .. ">" .. math.floor(bx) .. "," .. math.floor(by)
    if MEM.nearCache ~= nil and MEM.nearCache.key == key and Bridge.time - MEM.nearCache.tick < 30 then
        return MEM.nearCache.x, MEM.nearCache.y, rz
    end
    local dx, dy = bx - red:getX(), by - red:getY()
    local first
    if math.abs(dx) >= math.abs(dy) then
        first = { (dx >= 0) and 1 or -1, 0 }
    else
        first = { 0, (dy >= 0) and 1 or -1 }
    end
    local sides = { first }
    local rest = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    table.sort(rest, function(a, b)
        return dist2d(bx, by, rx + a[1] + 0.5, ry + a[2] + 0.5) < dist2d(bx, by, rx + b[1] + 0.5, ry + b[2] + 0.5)
    end)
    for _, s in ipairs(rest) do
        if s[1] ~= first[1] or s[2] ~= first[2] then sides[#sides + 1] = s end
    end
    local cell = getCell()
    local z = math.floor(rz)
    local rsq = cell and cell:getGridSquare(rx, ry, z)
    for _, s in ipairs(sides) do
        local open = true
        if rsq ~= nil then
            open = false
            pcall(function()
                local n = cell:getGridSquare(rx + s[1], ry + s[2], z)
                open = n ~= nil and not rsq:isBlockedTo(n) and BridgeMove.edgeBetween(body, rsq, n) == nil
                    and n:isFree(false)
            end)
        end
        if open then

            local x, y = rx + s[1] + 0.5 - s[1] * 0.3, ry + s[2] + 0.5 - s[2] * 0.3
            MEM.nearCache = { key = key, tick = Bridge.time, x = x, y = y }
            return x, y, rz
        end
    end
    local x, y = rx + first[1] + 0.5 - first[1] * 0.3, ry + first[2] + 0.5 - first[2] * 0.3
    MEM.nearCache = { key = key, tick = Bridge.time, x = x, y = y }
    return x, y, rz
end
BridgeMove.nearRed = nearRed
BridgeMove.nearReset = function() MEM.nearCache = nil end






local function profileMoveSpeed()
    local bf = rawget(_G, "BridgeFight")
    if bf == nil or type(bf.profile) ~= "function" then return 1.0 end
    local okP, prof = pcall(bf.profile)
    if not okP or prof == nil or type(prof.moveSpeed) ~= "table" then return 1.0 end
    local okL, level = pcall(bf.exhaustionLevel)
    if not okL then return 1.0 end
    local mult = tonumber(prof.moveSpeed[(tonumber(level) or 0) + 1])
    if mult == nil then return 1.0 end
    if mult < 0.60 then mult = 0.60 elseif mult > 1.0 then mult = 1.0 end
    return mult
end
BridgeMove.exhaustionSpeed = profileMoveSpeed

function BridgeMove.exhaustionRunBlocked(d, followAllowed)
    local bf = rawget(_G, "BridgeFight")
    if bf == nil or type(bf.profile) ~= "function" then return false end
    local okP, prof = pcall(bf.profile)
    if not okP or prof == nil then return false end
    local limit = tonumber(prof.noRunFrom) or 99
    if limit <= 0 then return false end
    local okL, level = pcall(bf.exhaustionLevel)
    if not okL or (tonumber(level) or 0) < limit then return false end
    if followAllowed and Bridge ~= nil and Bridge.follow and type(bf.mode) == "function" then
        local okM, mode = pcall(bf.mode)
        local leash = okM and tonumber(mode and mode.leash) or nil
        if leash ~= nil and (tonumber(d) or 0) > leash then return false end
    end
    return true
end

function BridgeMove.applyAnimVars(body)
    local ws = BridgeMove.blendOverride
    if ws == nil and BridgeMove.steering and BridgeMove.followWs ~= nil then ws = BridgeMove.followWs end
    if ws == nil and not (BridgeMove.steering and BridgeMove.followWs ~= nil) then
        local red = BridgeData.owner()
        local redWs, redRuns = nil, false
        if red ~= nil then
            pcall(function() redWs = red:getVariableFloat("WalkSpeed", 1.0) end)
            pcall(function() redRuns = red:isRunning() or red:isSprinting() end)
        end

        if redRuns and redWs ~= nil and redWs >= 0.3 then BridgeMove.runBlend = redWs end
        if BridgeMove.walkType == "Run" then


            ws = redRuns and redWs or BridgeMove.runBlend
        else

            ws = (not redRuns) and redWs or 1.0
            if not redRuns and redWs ~= nil and redWs >= 0.3 then BridgeMove.walkBlend = redWs end
        end
        if ws == nil or ws < 0.3 then ws = 1.0 end
    end
    BridgeMove.walkSpeedVar = ws
    pcall(function()
        body:setVariable("WalkSpeed", ws)
        body:setVariable("WalkInjury", 0.0)
        body:setVariable("NotAloneAnimOld", BridgeMove.animOld == true)
    end)
    if BridgeMove.speedModOverride ~= nil then
        pcall(function() body:setSpeedMod(BridgeMove.speedModOverride) end)
    end
end














local TRAIL_STEP = 0.5
local TRAIL_MAX = 60
local GAP_WALK = 1.4
local GAP_RUN = 1.9
local STOP_GAP = 1.3
local START_DIST = 2.2
local START_GOING = 0.85
local SEE_FAR = 14
SLOW.RED = 1.15
SLOW.FRAMES = 45
SLOW.GO = 0.45
local CATCH_FROM = 1.0
local CATCH_FULL = 2.5
local NO_LINE_FRAMES = 20
local AHEAD_PIVOT_DEG = 45
local STUCK_LEAVE = 1.5
local STUCK_LEAVE_AGAIN = 3.0
NAV.STALL_TICKS = 90
NAV.STALL_MOVE = 0.3
NAV.PATH_FAIL_LIMIT = 2
NAV.DETOUR_TICKS = 150
NAV.DETOUR_STEP = 1.6
NAV.OPENING_GIVE_UP = 360
NAV.FOLLOW_HOLD = 120
DOORWAY.STOP = 1.0
DOORWAY.ROOM = 1.2
DOORWAY.CLEAR = 0.3

function BridgeMove.addTrail(red)
    local t = BridgeMove.trail
    local x, y, z = red:getX(), red:getY(), red:getZ()
    local last = t[#t]
    if last ~= nil and (math.abs(last.z - z) > 0.5 or dist2d(last.x, last.y, x, y) > 3) then

        BridgeMove.trail = {}
        t = BridgeMove.trail
        last = nil
    end
    if last == nil or dist2d(last.x, last.y, x, y) >= TRAIL_STEP then
        t[#t + 1] = { x = x, y = y, z = z }
        if #t > TRAIL_MAX then table.remove(t, 1) end
    end
end



function BridgeMove.followTarget(body, red)
    local rx, ry, rz = red:getX(), red:getY(), red:getZ()
    local bx, by = body:getX(), body:getY()
    local d = dist2d(bx, by, rx, ry)
    if d > SEE_FAR then return nil end
    local sameEnclosure = true
    local bsq, psq = nil, nil
    pcall(function() bsq = body:getCurrentSquare() end)
    pcall(function() psq = red:getCurrentSquare() end)
    if bsq ~= nil and psq ~= nil and BridgeDoors ~= nil and type(BridgeDoors.enclosureKey) == "function" then
        local a, b = nil, nil
        pcall(function() a = BridgeDoors.enclosureKey(bsq) end)
        pcall(function() b = BridgeDoors.enclosureKey(psq) end)
        if a ~= nil and b ~= nil and a ~= b then sameEnclosure = false end
    end
    if sameEnclosure and BridgeMove.lineClear(body, rx, ry, rz) then return rx, ry, rz, "player", d end
    local t = BridgeMove.trail
    local tail = 0
    local prevx, prevy = rx, ry
    for i = #t, math.max(1, #t - 60), -1 do
        local c = t[i]
        tail = tail + dist2d(prevx, prevy, c.x, c.y)
        prevx, prevy = c.x, c.y


        if tail > 26 then break end
        if dist2d(bx, by, c.x, c.y) <= SEE_FAR and BridgeMove.lineClear(body, c.x, c.y, c.z) then
            return c.x, c.y, c.z, "trail", dist2d(bx, by, c.x, c.y) + tail
        end
    end
    if not sameEnclosure and BridgeMove.lineClear(body, rx, ry, rz) then
        return rx, ry, rz, "player", d
    end
    return nil
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end


function BridgeMove.trailPoint(red, gap)
    local t = BridgeMove.trail
    local px, py = red:getX(), red:getY()
    local acc = 0
    for i = #t, 1, -1 do
        local c = t[i]
        local seg = dist2d(px, py, c.x, c.y)
        if seg > 0.001 and acc + seg >= gap then
            local k = (gap - acc) / seg
            return px + (c.x - px) * k, py + (c.y - py) * k
        end
        acc = acc + seg
        px, py = c.x, c.y
    end
    return px, py
end



local function blockedAhead(body)
    local blocked = false
    pcall(function()
        local a = body:getAnimAngleRadians()
        local bx, by = body:getX(), body:getY()
        local cx, cy = math.floor(bx), math.floor(by)
        local nx, ny = math.floor(bx + math.cos(a) * 0.45), math.floor(by + math.sin(a) * 0.45)
        if cx == nx and cy == ny then return end
        local cell = getCell()
        local z = math.floor(body:getZ())
        local me, sq = cell:getGridSquare(cx, cy, z), cell:getGridSquare(nx, ny, z)
        if me == nil or sq == nil then return end
        local function shut(from, to)
            return to == nil or from:isBlockedTo(to) or BridgeMove.engineBlocked(from, to)
        end
        if cx ~= nx and cy ~= ny then
            blocked = shut(me, cell:getGridSquare(nx, cy, z)) or shut(me, cell:getGridSquare(cx, ny, z)) or not sq:isFree(false)
        else
            blocked = shut(me, sq) or not sq:isFree(false)
        end
    end)
    return blocked
end


function BridgeMove.aheadText(body, px, py)
    local text = "?"
    pcall(function()
        local bx, by = body:getX(), body:getY()
        local dist = dist2d(bx, by, px, py)
        if dist < 0.01 then text = "goal reached" return end
        local cell = getCell()
        local z = math.floor(body:getZ())
        local me = cell:getGridSquare(math.floor(bx), math.floor(by), z)
        local ax, ay = bx + (px - bx) / dist * 0.7, by + (py - by) / dist * 0.7
        local sq = cell:getGridSquare(math.floor(ax), math.floor(ay), z)
        if me == nil or sq == nil then text = "no square ahead" return end
        local parts = { sformat("ahead %d,%d", sq:getX(), sq:getY()) }
        if sq == me then parts[#parts + 1] = "same square" end
        if not sq:isFree(false) then parts[#parts + 1] = "occupied" end
        if sq.HasStairs ~= nil then
            if sq:HasStairs() then parts[#parts + 1] = "stairs" end
            if me:HasStairs() then parts[#parts + 1] = "on stairs" end
        end
        if sq:isVehicleIntersecting() then parts[#parts + 1] = "vehicle" end
        if sq ~= me and math.abs(sq:getX() - me:getX()) + math.abs(sq:getY() - me:getY()) == 1 then
            if me:isBlockedTo(sq) then parts[#parts + 1] = "wall" end
            if BridgeMove.engineBlocked(me, sq) then parts[#parts + 1] = "engine blocks the step" end
        end
        local movers = sq:getMovingObjects()
        if movers ~= nil and movers:size() > 0 then parts[#parts + 1] = "movers " .. movers:size() end
        parts[#parts + 1] = sformat("z %.2f", body:getZ())
        text = table.concat(parts, ", ")
    end)
    return text
end

local GAIT_HOLD = 24




local function drive(body, red, F, pf, bx, by, px, py, want, kind, running, d, err)
    local bf = rawget(_G, "BridgeFight")
    if bf ~= nil and type(bf.profile) == "function" then
        local okP, prof = pcall(bf.profile)
        if okP and prof ~= nil and type(prof.moveSpeed) == "table" then
            local okL, level = pcall(bf.exhaustionLevel)
            local mult = okL and tonumber(prof.moveSpeed[(tonumber(level) or 0) + 1]) or nil
            if mult ~= nil then
                if mult < 0.60 then mult = 0.60 elseif mult > 1.0 then mult = 1.0 end
                if mult < 1.0 then want = want * mult end
            end
        end
    end
    local s = clamp(want / math.max(0.02, BridgeMove.stepPerMul), 0.15, 1.6)

    local st = ""
    pcall(function() st = body:getActionStateName() end)
    BridgeMove.walkFrames = (st == "walktoward" or st == "bumped") and (BridgeMove.walkFrames + frameDt()) or 0
    local free = dist2d(bx, by, px, py)


    if F.frame == Bridge.tick - 1 and F.px ~= nil then

        local el = (F.time ~= nil and Bridge.time - F.time > 0) and (Bridge.time - F.time) or frameDt()
        F.lastStep = dist2d(F.px, F.py, bx, by) / el
    else
        F.lastStep = nil
    end
    if BridgeMove.walkFrames > 25 and F.s and F.s > 0.3 and F.lastStep and F.lastStep > 0.01
        and F.lastFree and F.lastFree > F.lastStep + 0.05 then
        BridgeMove.stepPerMul = clamp(BridgeMove.stepPerMul * 0.9 + (F.lastStep / F.s) * 0.1, 0.02, 0.15)
    end

    if F.lastStep ~= nil and (F.s or 0) >= 0.3 and (F.lastFree or 0) > 0.3 and F.lastStep < 0.004 then
        F.stuck = (F.stuck or 0) + frameDt()
    else
        F.stuck = 0
    end



    if F.frame ~= Bridge.tick - 1 then F.netFrame = nil end
    if F.netFrame == nil or Bridge.time - F.netFrame >= 40 then
        if F.netFrame ~= nil and F.netX ~= nil and dist2d(F.netX, F.netY, bx, by) < 0.25 and want > 0.015 then
            F.stuck = 20
        end
        F.netFrame, F.netX, F.netY = Bridge.time, bx, by
    end
    if F.stuck >= 12 then
        F.stuck = 0





        local at = F.stuckAt
        local again = at ~= nil and Bridge.time - at.tick < 600 and dist2d(at.x, at.y, bx, by) < 1.5
        F.stuckAt = { x = bx, y = by, tick = Bridge.time, leave = again and STUCK_LEAVE_AGAIN or STUCK_LEAVE }
        BridgeMove.stuckCount = (BridgeMove.stuckCount or 0) + 1
        F.pathMin = Bridge.time + 60
        F.pathUntil = Bridge.time + (again and 480 or 240)
        BridgeMove.steering = false
        BridgeMove.setCollide(body, true)
        BridgeMove.endFollowBump(body, "")
        log(sformat("follow stuck at %.2f %.2f going to %.2f %.2f (%s)%s, path until %.1f cells away: %s", bx, by, px, py,
            tostring(kind), again and ", again here" or "", F.stuckAt.leave, BridgeMove.aheadText(body, px, py)))
        return false
    end


    local ghost = BridgeMove.doorGhost and F.cross ~= nil and F.cross.door == true
    BridgeMove.setCollide(body, not (BridgeMove.noCollide or ghost))
    if BridgeMove.bumpMove == "face" then

        local M = BridgeMove.speedModel
        local sneaking = false
        pcall(function() sneaking = red:isSneaking() end)
        local nameWalk = sneaking and "WalkSneak" or "Walk"
        local nameRun = sneaking and "RunSneak" or "Run"



        local cal = F.cal
        if cal ~= nil and cal.bump == tostring(body:getBumpType()) and BridgeMove.walkFrames > 25 and (F.stuck or 0) == 0 then
            local ticks = Bridge.time - cal.tick
            if ticks >= 1 and ticks <= 3 and cal.free > 0.6 then
                local step = dist2d(cal.x, cal.y, bx, by) / ticks
                local pred = cal.pred
                if pred > 0.01 and step >= 0.5 * pred * BridgeMove.speedScale and step <= 3.5 * pred then
                    local ratio = clamp(step / pred, 0.6, 3.0)
                    local k = BridgeMove.speedScaleN < 40 and 0.10 or 0.02
                    BridgeMove.speedScale = BridgeMove.speedScale * (1 - k) + ratio * k
                    BridgeMove.speedScaleN = BridgeMove.speedScaleN + 1
                end
            end
        end
        local scale = BridgeMove.speedScale
        local wantT = want / scale
        local walkMax = M[nameWalk].a + M[nameWalk].b





        local gait = F.gait or BridgeMove.walkType



        local mayChange = F.gaitAt == nil or Bridge.time - F.gaitAt >= GAIT_HOLD
        if mayChange then



            if gait == "Run" then
                if wantT <= walkMax and not running then gait = "Walk" end
            elseif wantT > walkMax + 0.012 or running then
                gait = "Run"
            end
        end
        if gait == "Run" and BridgeMove.exhaustionRunBlocked(d, F == BridgeMove.follow and Bridge ~= nil and Bridge.follow == true) then
            gait = "Walk"
        end
        local prevGait = F.gait
        if prevGait ~= nil and prevGait ~= gait then F.gaitAt = Bridge.time end
        F.gait = gait
        BridgeMove.walkType = gait
        local m = M[gait == "Run" and nameRun or nameWalk]
        local prevWs = BridgeMove.followWs
        BridgeMove.followWs = clamp((wantT - m.a) / m.b, 0, 1)


        if Bridge.verbose and prevGait ~= gait then
            log(sformat("gait %s -> %s: want %.3f (table %.3f), mix %.2f -> %.2f, player %.3f, d %.2f, err %.2f",
                tostring(prevGait), gait, want, wantT, prevWs or -1, BridgeMove.followWs, BridgeMove.redSpeed, d, err or 0))
        end
        F.cal = { tick = Bridge.time, x = bx, y = by, free = free, bump = gait == "Run" and "FollowRun" or "FollowWalk",
                  pred = m.a + m.b * BridgeMove.followWs }
        BridgeMove.applyAnimVars(body)
        BridgeMove.followBump(body, gait)
        local pivotDeg = nil
        if kind == "seat" or kind == "aside" then pivotDeg = BridgeMove.SEAT_PIVOT_DEG
        elseif kind == "mourn" then pivotDeg = BridgeMove.MOURN_PIVOT_DEG end
        if BridgeMove.backwardsStep then

        elseif pivotDeg ~= nil and BridgeMove.pivotToward(body, px, py, pivotDeg) ~= nil then

        else




            local off = BridgeMove.facingOff(body, px, py)
            if BridgeMove.aheadPivot and off ~= nil and off > 30 and blockedAhead(body) then
                BridgeMove.pivotToward(body, px, py, AHEAD_PIVOT_DEG)
                F.pivots = (F.pivots or 0) + 1
            end
            BridgeMove.turnToward(body, px, py, 18)
        end
    else
        BridgeMove.followBump(body, BridgeMove.walkType)
        pcall(function() pf:moveToPoint(px, py, s) end)
    end
    F.ws = BridgeMove.followWs or -1
    F.px, F.py, F.frame, F.time = bx, by, Bridge.tick, Bridge.time
    F.lastFree = free
    F.kind, F.s, F.want, F.gap = kind, s, want, err
    F.tx, F.ty = px, py

    BridgeMove.goal = { x = red:getX(), y = red:getY() }
    BridgeMove.pathResult = "follow-" .. kind
    BridgeMove.wasWalking = true
    trackStep(body)
    setStride(body, true)
    BridgeRoute.trace(body, d, false, false)
    return true
end










SPOT.SIDE = 1.3
SPOT.BACK = 0.35
SPOT.FAR = 1.0
local CORPSE_EXTRA = 1.0
SPOT.REACH = 6
SPOT.TURN = math.cos(math.rad(50))
SPOT.ENTER = 8
SPOT.LEAVE = 4
SPOT.ARRIVE = 0.35
SPOT.START = 0.7

function BridgeMove.keepSide()
    local side = "behind"
    pcall(function() side = BridgeData.keepOf(Bridge.store) end)
    return side
end

function BridgeMove.keepFar()
    local far = false
    pcall(function() far = BridgeData.farOf(Bridge.store) end)
    return far
end



function BridgeMove.redDragsCorpse()
    local red = BridgeData.owner()
    local drag = false
    if red ~= nil then
        pcall(function()
            if red.isDraggingCorpse ~= nil then drag = red:isDraggingCorpse() == true end
        end)
    end
    return drag
end




local function keepExtra()
    if BridgeMove.keepFar() then return SPOT.FAR end
    return BridgeMove.redDragsCorpse() and CORPSE_EXTRA or 0
end

function BridgeMove.spotReset()
    local F = BridgeMove.follow
    F.spotHx, F.spotHy, F.spotOk, F.spotBad, F.inSpot, F.spotStand = nil, nil, 0, 0, false, false
end


function BridgeMove.spotPoint(red, keep, far, F, redGoes)
    local vx, vy = BridgeMove.redVx or 0, BridgeMove.redVy or 0
    local vl = math.sqrt(vx * vx + vy * vy)
    if redGoes and vl > 0.01 then
        F.spotHx, F.spotHy = vx / vl, vy / vl
    else
        local fx, fy = nil, nil
        pcall(function()
            local fwd = red:getForwardDirection()
            fx, fy = fwd:getX(), fwd:getY()
        end)
        if fx ~= nil then
            local fl = math.sqrt(fx * fx + fy * fy)
            if fl > 0.001 then
                fx, fy = fx / fl, fy / fl
                if F.spotHx == nil or (F.spotHx * fx + F.spotHy * fy) < SPOT.TURN then F.spotHx, F.spotHy = fx, fy end
            end
        end
    end
    local hx, hy = F.spotHx, F.spotHy
    if hx == nil then return nil end
    local extra = far and SPOT.FAR or 0
    local rx, ry = red:getX(), red:getY()

    local sgn = (keep == "right") and 1 or -1
    local side = SPOT.SIDE + extra
    return rx - hy * side * sgn - hx * SPOT.BACK, ry + hx * side * sgn - hy * SPOT.BACK, hx, hy
end



function BridgeMove.spotFree(body, red, px, py)
    local z = red:getZ()
    if math.abs(body:getZ() - z) >= 0.5 then return false, "other floor" end
    if not BridgeMove.lineClear(red, px, py, z) then return false, "player does not see the spot" end
    local free = false
    pcall(function()
        local sq = getCell():getGridSquare(math.floor(px), math.floor(py), math.floor(z))
        free = sq ~= nil and sq:isFree(false)
    end)
    if not free then return false, "square busy" end
    if not BridgeMove.lineClear(body, px, py, z) then return false, "she does not see the spot" end
    return true, "ok"
end









local DETOUR_CLOSE = 0.9
local DETOUR_R = 1.2



















SEAT.STAY = 4





SEAT.RING_MAX = 4
SEAT.ARRIVE = 0.3
SEAT.NEAR = 0.7
SEAT.GAP = 0.25
SEAT.EDGE = 0.15

BridgeMove.SEAT_PIVOT_DEG = 15
SEAT.GIVE_UP = 360
SEAT.DOWN_MAX = 180
SEAT.NEAR_GOAL = 2.5
BridgeMove.seat = nil
BridgeMove.sitDangerLatch = nil

local function cellOf(x, y) return math.floor(x), math.floor(y) end


local function pointAt(x, y, z)
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z end }
end










function BridgeMove.seatZones(red)
    if red == nil then return nil end
    local sitting, furniture, tx, ty, why, ground = false, nil, nil, nil, nil, false
    pcall(function() sitting = red:isSittingOnFurniture() == true end)
    pcall(function() furniture = red:getSitOnFurnitureObject() end)
    pcall(function() ground = red:isSitOnGround() == true end)
    if furniture == nil or sitting then BridgeMove.sitDownSince = nil end
    if sitting then
        why = "sits"
    elseif furniture ~= nil then



        BridgeMove.sitDownSince = BridgeMove.sitDownSince or Bridge.time
        if Bridge.time - BridgeMove.sitDownSince > SEAT.DOWN_MAX then return nil end
        why = "sitting down"
    elseif ground then
        why = "sits"
    else
        pcall(function()
            local q = ISTimedActionQueue.queues[red]
            local first = q and q.queue and q.queue[1]
            if first == nil then return end
            if first.Type == "ISPathFindAction" and type(first.goal) == "table" and first.goal[1] == "SitOnFurniture" then

                local pf = red:getPathFindBehavior2()
                if not pf:isGoalSitOnFurniture() then return end
                local gx, gy = pf:getTargetX(), pf:getTargetY()
                if gx == nil or gx <= 0 or dist2d(red:getX(), red:getY(), gx, gy) > SEAT.NEAR_GOAL then return end

                pcall(function() furniture = pf:getGoalSitOnFurnitureObject() end)
                if furniture == nil then furniture = first.goal[2] end
                tx, ty, why = gx, gy, "going to sit"
            else

                for _, a in ipairs(q.queue) do
                    if a.Type == "ISRestAction" and a.bed ~= nil then
                        furniture, why = a.bed, "about to sit"
                        break
                    end
                end
            end
        end)
        if why == nil then return nil end
    end
    local rx, ry = cellOf(red:getX(), red:getY())


    local zones = { { x = rx, y = ry }, z = math.floor(red:getZ() + 0.5), why = why, cx = rx, cy = ry, ground = ground }
    if tx ~= nil and tx > 0 and ty ~= nil and ty > 0 then
        local gx, gy = cellOf(tx, ty)
        zones[#zones + 1] = { x = gx, y = gy }
        zones.cx, zones.cy = gx, gy
    end
    if furniture ~= nil then
        local sq = nil
        pcall(function() sq = furniture:getSquare() end)
        if sq ~= nil then zones[#zones + 1] = { x = sq:getX(), y = sq:getY() } end
    end
    return zones
end

function BridgeMove.inSeatZone(zones, cx, cy)
    for _, c in ipairs(zones) do
        if math.abs(cx - c.x) <= 1 and math.abs(cy - c.y) <= 1 then return true end
    end
    return false
end



function BridgeMove.zoneGap(zones, x, y)
    local best = nil
    for _, c in ipairs(zones) do
        local dx = math.max(c.x - 1 - x, 0, x - (c.x + 2))
        local dy = math.max(c.y - 1 - y, 0, y - (c.y + 2))
        local g = math.sqrt(dx * dx + dy * dy)
        if best == nil or g < best then best = g end
    end
    return best or 99
end


function BridgeMove.seatBlocks(x, y, z)
    local zones = BridgeMove.seatZones(BridgeData.owner())
    if zones == nil or math.floor(z or 0) ~= zones.z then return false end
    local cx, cy = cellOf(x, y)
    return BridgeMove.inSeatZone(zones, cx, cy)
end


local function seatCellOk(x, y, z)
    local ok = false
    pcall(function()
        local sq = getCell():getGridSquare(x, y, z)
        if sq == nil or not sq:isFree(false) then return end
        ok = true
        pcall(function() if sq:isVehicleIntersecting() or sq:isWaterSquare() then ok = false end end)
    end)
    return ok
end



local ZONE_MARGIN = 0.25
local function zoneFree(zones, ax, ay, bx, by)
    local len = dist2d(ax, ay, bx, by)
    local steps = math.max(1, math.ceil(len / 0.1))
    local nx, ny = 0, 0
    if len > 1e-6 then nx, ny = -(by - ay) / len * ZONE_MARGIN, (bx - ax) / len * ZONE_MARGIN end
    for i = 0, steps do
        local t = i / steps
        local px, py = ax + (bx - ax) * t, ay + (by - ay) * t


        local ends = t * len < 0.8 or (1 - t) * len < 0.8
        for _, k in ipairs(ends and { 0 } or { 0, 1, -1 }) do
            local cx, cy = cellOf(px + nx * k, py + ny * k)
            if BridgeMove.inSeatZone(zones, cx, cy) then return false end
        end
    end
    return true
end
BridgeMove.zoneFree = zoneFree




local function zoneDetour(zones, body, bx, by, gx, gy)
    local best, bestLen = nil, nil
    for r = 2, 4 do
        for dx = -r, r do
            for dy = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local x, y = zones.cx + dx, zones.cy + dy
                    if not BridgeMove.inSeatZone(zones, x, y) and seatCellOk(x, y, zones.z) then
                        local px, py = x + 0.5, y + 0.5
                        if zoneFree(zones, bx, by, px, py) and zoneFree(zones, px, py, gx, gy)
                            and BridgeMove.lineClear(body, px, py, zones.z)
                            and BridgeMove.lineClear(pointAt(px, py, zones.z), gx, gy, zones.z) then
                            local len = dist2d(bx, by, px, py) + dist2d(px, py, gx, gy)
                            if bestLen == nil or len < bestLen then best, bestLen = { x = px, y = py }, len end
                        end
                    end
                end
            end
        end
    end
    return best
end


local function seatFrom(red, zones)
    if zones.why == "going to sit" then return pointAt(zones.cx + 0.5, zones.cy + 0.5, zones.z) end
    return red
end


local function segDist(px, py, ax, ay, bx, by)
    local vx, vy = bx - ax, by - ay
    local l2 = vx * vx + vy * vy
    local t = 0
    if l2 > 1e-9 then t = clamp(((px - ax) * vx + (py - ay) * vy) / l2, 0, 1) end
    return dist2d(px, py, ax + vx * t, ay + vy * t)
end







function BridgeMove.seatSpot(red, zones, bx, by, body, bad)
    local from = seatFrom(red, zones)
    local rx, ry = red:getX(), red:getY()
    local best, bestCost, checked = nil, nil, 0
    for r = 2, SEAT.RING_MAX do
        for dx = -r, r do
            for dy = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local x, y = zones.cx + dx, zones.cy + dy
                    if not BridgeMove.inSeatZone(zones, x, y) and not (bad and bad[x .. "," .. y]) then
                        checked = checked + 1
                        local px, py = x + 0.5, y + 0.5
                        local redSees = BridgeMove.lineClear(from, px, py, zones.z)
                        local sheSees = body == nil or BridgeMove.lineClear(body, px, py, zones.z)



                        if seatCellOk(x, y, zones.z) and (redSees or sheSees) then
                            local cost = dist2d(bx, by, px, py) + (r - 2) * 2.5
                            if not redSees then cost = cost + 4 end
                            if not sheSees then cost = cost + 3 end
                            if segDist(rx, ry, bx, by, px, py) < 1.0 then cost = cost + 5 end
                            if not zoneFree(zones, bx, by, px, py) then cost = cost + 6 end
                            if bestCost == nil or cost < bestCost then
                                best, bestCost = { x = x, y = y, ring = r }, cost
                            end
                        end
                    end
                end
            end
        end
    end
    return best, checked
end



local function freshDrive(F)
    if F.frame ~= Bridge.tick - 1 then F.netFrame, F.stuck = nil, 0 end
end





local AWAY_STEP = 0.6
local function awayPoint(body, red, z, tx, ty)
    local bx, by = body:getX(), body:getY()
    local dx, dy = bx - red:getX(), by - red:getY()
    local l = math.sqrt(dx * dx + dy * dy)
    if l < 0.05 then dx, dy, l = 1, 0, 1 end
    dx, dy = dx / l, dy / l
    local gx, gy = (tx or bx + dx) - bx, (ty or by + dy) - by
    local gl = math.sqrt(gx * gx + gy * gy)
    if gl < 1e-6 then gx, gy, gl = dx, dy, 1 end
    gx, gy = gx / gl, gy / gl
    local bestX, bestY, bestDot = nil, nil, nil
    for _, a in ipairs({ 0, 45, -45, 90, -90 }) do
        local r = math.rad(a)
        local ux, uy = dx * math.cos(r) - dy * math.sin(r), dx * math.sin(r) + dy * math.cos(r)
        local px, py = bx + ux * AWAY_STEP, by + uy * AWAY_STEP
        local dot = ux * gx + uy * gy
        if (bestDot == nil or dot > bestDot + 1e-6) and BridgeMove.lineClear(body, px, py, z) then
            bestX, bestY, bestDot = px, py, dot
        end
    end
    return bestX, bestY
end



local function routeAround(S, body, red, z, tx, ty, d)
    local bx, by = body:getX(), body:getY()
    if S.away ~= nil then
        if dist2d(bx, by, S.away.x, S.away.y) <= 0.2 then
            S.away, S.awayDone = nil, true
        else
            return S.away.x, S.away.y, true
        end
    end





    if not S.awayDone and (d < 0.45 or segDist(red:getX(), red:getY(), bx, by, tx, ty) < math.min(d, 0.7) - 0.05) then
        local ax, ay = awayPoint(body, red, z, tx, ty)
        if ax ~= nil then
            S.away = { x = ax, y = ay }
            log(sformat("seat: right at him (d=%.2f), first a step away to %.2f,%.2f, then %.2f,%.2f", d, ax, ay, tx, ty))
            return ax, ay, true
        end
    end
    return tx, ty, false
end


local function seatStand(body, red, d)
    if BridgeMove.onPath() then BridgeMove.stopPath(body) end
    BridgeMove.moving = false
    local F = BridgeMove.follow
    F.kind, F.s, F.want = "seat-stand", 0, 0
    if Bridge.zombieTicks % 30 == 0 then
        pcall(function() body:faceLocationF(red:getX(), red:getY()) end)
    end
    BridgeMove.goal = { x = red:getX(), y = red:getY() }
    BridgeMove.pathResult = "follow-seat-stand"
    trackStep(body)
    BridgeRoute.trace(body, d, false, false)
    return true
end


function BridgeMove.seatText()
    local S = BridgeMove.seat
    if S == nil then return "none" end
    local text = tostring(S.why)
    if S.phase ~= nil then text = text .. " phase=" .. S.phase end
    if S.chair ~= nil then text = text .. sformat(" chair=%d,%d", S.chair.x, S.chair.y) end
    if S.spot ~= nil then text = text .. sformat(" spot=%d,%d%s", S.spot.x, S.spot.y, S.path and " path" or "") end
    if S.noSpot then text = text .. " no-spot" end
    return text
end













CHAIR.RING_MAX = 3
CHAIR.ARRIVE = 0.2
CHAIR.ANIM_MAX = 240
local SIT_DIRS = { "N", "S", "W", "E" }
BridgeMove.CHAIR_POSES = { SitChairDown = true, SitChair = true, SitChairUp = true }
BridgeMove.seatFlag = false
BridgeMove.seatBound = nil






function BridgeMove.findChair(red, zones, body, bad)
    local sm, v = nil, nil
    pcall(function() sm = SeatingManager.getInstance() end)
    pcall(function() v = Vector3f.new() end)
    if sm == nil or v == nil then return nil, 0 end
    local rcx, rcy = zones[1].x, zones[1].y
    local bx, by = body:getX(), body:getY()
    local cell = getCell()
    local best, bestCost, seats = nil, nil, 0
    for dx = -CHAIR.RING_MAX, CHAIR.RING_MAX do
        for dy = -CHAIR.RING_MAX, CHAIR.RING_MAX do
            local ring = math.max(math.abs(dx), math.abs(dy))
            local x, y = rcx + dx, rcy + dy
            if ring >= 2 and not BridgeMove.inSeatZone(zones, x, y) and not (bad and bad[x .. "," .. y]) then



                local sq = cell:getGridSquare(x, y, zones.z)
                local objects = sq ~= nil and sq:getObjects() or nil
                local n = objects ~= nil and objects:size() or 0
                for i = 0, n - 1 do
                    local o = objects:get(i)



                    local sprite, sittable = nil, false
                    pcall(function()
                        sprite = o:getSprite()
                        local props = sprite ~= nil and sprite:getProperties() or nil
                        sittable = props ~= nil and props:has(IsoFlagType.bed) == true
                    end)
                    local places, taken = 0, false
                    if sittable then
                        pcall(function() places = sm:getTilePositionCount(o) end)
                        pcall(function() taken = o:isFurnitureOccupied(body) == true end)
                    end
                    if sittable and places > 0 and not taken then
                        seats = seats + 1
                        for _, dir in ipairs(SIT_DIRS) do





                            local ok = false
                            pcall(function() ok = sm:getAdjacentPosition(red, o, dir, "Front", "sitonfurniture", "SitOnFurnitureFront", v) == true end)
                            if ok then
                                local ax, ay = v:x(), v:y()
                                local acx, acy = cellOf(ax, ay)
                                if not BridgeMove.inSeatZone(zones, acx, acy) and seatCellOk(acx, acy, zones.z)
                                    and BridgeMove.lineClear(red, ax, ay, zones.z) then
                                    local cost = dist2d(bx, by, ax, ay) + (ring - 2)
                                    if not BridgeMove.lineClear(body, ax, ay, zones.z) then cost = cost + 3 end
                                    if not zoneFree(zones, bx, by, ax, ay) then cost = cost + 6 end
                                    if bestCost == nil or cost < bestCost then
                                        local name = "?"
                                        pcall(function() name = tostring(sprite:getName()) end)
                                        best, bestCost = { obj = o, x = x, y = y, ax = ax, ay = ay, dir = dir, ring = ring, name = name }, cost
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best, seats
end



function BridgeMove.sendSit(value)
    local st = Bridge.store
    if st == nil or st.sit == value then return end
    st.sit = value
    if Bridge.mp then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { sit = value or false }) end)
    end
end


local function chairFlags(body, plan)
    pcall(function() body:setCollidable(false) end)
    local obj = plan and plan.obj or nil
    local dir = plan and plan.dir or nil
    if BridgeMove.seatFlag and BridgeMove.seatBound == obj then return end
    if BridgeMove.seatBound ~= nil and BridgeMove.seatBound ~= obj then
        pcall(function() BridgeMove.seatBound:setSatChair(false) end)
    end
    BridgeMove.seatFlag = true
    BridgeMove.seatBound = obj
    pcall(function() body:setSittingOnFurniture(true) end)
    if obj ~= nil then
        pcall(function() body:setSitOnFurnitureObject(obj) end)
        pcall(function() obj:setSatChair(true) end)
    end
    if dir ~= nil then
        pcall(function() body:setSitOnFurnitureDirection(IsoDirections.fromString(dir)) end)
    end
    pcall(function() body:setVariable("SitOnFurnitureDirection", "Front") end)
    pcall(function() body:setVariable("SitOnFurnitureStarted", true) end)
end

local function chairFlagsOff(body)
    if not BridgeMove.seatFlag and BridgeMove.seatBound == nil then return end
    BridgeMove.seatFlag = false
    if BridgeMove.seatBound ~= nil then
        local obj = BridgeMove.seatBound
        BridgeMove.seatBound = nil
        pcall(function() obj:setSatChair(false) end)
    end
    pcall(function() body:setSittingOnFurniture(false) end)
    pcall(function() body:setSitOnFurnitureObject(nil) end)
    pcall(function() body:clearVariable("SitOnFurnitureDirection") end)
    pcall(function() body:clearVariable("SitOnFurnitureStarted") end)
    pcall(function() body:setCollidable(true) end)
end




local function animDone(body, S)
    local bump, fin = "", false
    pcall(function() bump = tostring(body:getBumpType()) end)
    pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") end)
    if bump == S.anim then S.animSeen = true end
    if S.animSeen and (fin or bump ~= S.anim) then return true end
    return Bridge.time - S.phaseSince > CHAIR.ANIM_MAX
end

local function startPose(body, S, anim, move)
    pcall(function() body:setVariable("BumpAnimFinished", false) end)
    Bridge.pose = { anim = anim, move = move, seat = true }
    S.anim, S.animSeen = anim, false
end






local function chairLeave(body, S, why)
    local c = S and S.chair
    if c ~= nil then
        pcall(function()
            body:setX(c.ax)
            body:setY(c.ay)
            body:setLastX(c.ax)
            body:setLastY(c.ay)
        end)
        local sq = getCell():getGridSquare(math.floor(c.ax), math.floor(c.ay), math.floor(body:getZ()))
        if sq ~= nil then pcall(function() body:setCurrent(sq) end) end
    end
    pcall(function()
        if BridgeMove.CHAIR_POSES[tostring(body:getBumpType())] then BridgeMove.releaseBump(body) end
    end)
    Bridge.holdPos = nil
    chairFlagsOff(body)
    log(sformat("seat: off %s without stand-up (%s)%s", c and (c.x .. "," .. c.y) or "the seat", why,
        c and sformat(", put at %.2f,%.2f", c.ax, c.ay) or ""))
end



function BridgeMove.seatPose(body)
    local S = BridgeMove.seat
    if S == nil or S.phase == nil or S.phase == "go" then return false end
    local red = BridgeData.owner()
    local zones = BridgeMove.seatZones(red)
    local up = zones == nil or zones.why ~= "sits"
    local danger = BridgeTask ~= nil and BridgeTask.dangerNear(body)
    if S.phase == "down" then
        chairFlags(body, S.chair)
        if animDone(body, S) then
            S.phase, S.phaseSince = "sit", Bridge.time
            startPose(body, S, "SitChair", false)
            BridgeMove.sendSit("chair")
            log(sformat("seat: on %d,%d after %d ticks, at %.2f,%.2f, %d cells from player", S.chair.x, S.chair.y,
                Bridge.time - S.since, body:getX(), body:getY(),
                math.max(math.abs(math.floor(body:getX()) - math.floor(red:getX())), math.abs(math.floor(body:getY()) - math.floor(red:getY())))))
        end
    elseif S.phase == "sit" then
        chairFlags(body, S.chair)
        if up then
            S.phase, S.phaseSince = "up", Bridge.time
            startPose(body, S, "SitChairUp", true)
            BridgeMove.sendSit(nil)
            log(sformat("seat: player is up, standing up from %d,%d", S.chair.x, S.chair.y))
        end
    elseif S.phase == "up" then
        chairFlags(body, S.chair)
        if animDone(body, S) then
            Bridge.pose = nil
            chairFlagsOff(body)
            BridgeMove.sendSit(nil)
            log(sformat("seat: up after %d ticks at %.2f,%.2f, following again", Bridge.time - S.phaseSince, body:getX(), body:getY()))
            BridgeMove.seat = nil
        end
    elseif S.phase == "floor" then
        if danger then
            BridgeMove.sitDangerLatch = true
            Bridge.pose = nil
            BridgeMove.sendSit(nil)
            pcall(function() BridgeMoments.say("EvSitDanger", 0, true, "SitDanger") end)
            BridgeMove.seat = nil
        elseif up then
            Bridge.pose = nil
            BridgeMove.sendSit(nil)
            pcall(function() BridgeMoments.say("EvSitUp", 0, true, "SitUp") end)
            BridgeMove.seat = nil
        elseif Bridge.every(300) then
            pcall(function() BridgeMoments.say("EvSitIdle", 0, false, "SitIdle") end)
        end
    end
    return true
end



function BridgeMove.seatGuard(body)
    local pose = Bridge.pose
    local chairPose = pose ~= nil and BridgeMove.CHAIR_POSES[pose.anim] == true
    local S = BridgeMove.seat
    local phase = S and S.phase
    local onChair = phase == "down" or phase == "sit" or phase == "up"
    local busy = false
    pcall(function()
        busy = (BridgeTask ~= nil and BridgeTask.active)
            or (BridgeFight ~= nil and BridgeFight.state ~= "idle")
            or (BridgeHeal ~= nil and BridgeHeal.active)
    end)
    if onChair or phase == "floor" then
        local ours = (phase == "floor" and pose ~= nil and pose.anim == "Sit") or chairPose
        if not ours or not Bridge.follow or busy then
            local why = sformat("pose %s, mode %s", pose and tostring(pose.anim) or "none", tostring(Bridge.mode))
            if onChair then chairLeave(body, S, why)
            else log("seat: up from the floor (" .. why .. ")") end
            BridgeMove.sendSit(nil)
            BridgeMove.seat = nil
        end
    elseif pose ~= nil and pose.seat and not busy then

        if chairPose then chairLeave(body, nil, "pose without sitting") end
        Bridge.pose = nil
        BridgeMove.sendSit(nil)
    end
    if BridgeMove.seatFlag and not chairPose then chairFlagsOff(body) end
end



BridgeMove.STAY_SIT = 3
BridgeMove.STAY_SIT_OUT = 5

function BridgeMove.staySitTick(body)
    if body == nil then return false end
    local pose = Bridge.pose
    local ours = pose ~= nil and pose.staySit == true
    if Bridge.mode == "wait" and (pose == nil or ours)
            and BridgeData.optionOf(Bridge.store, "sitWithRed") then
        local red = BridgeData.owner()
        local busy = false
        pcall(function()
            busy = (BridgeTask ~= nil and BridgeTask.active)
                or (BridgeFight ~= nil and BridgeFight.state ~= "idle")
                or (BridgeHeal ~= nil and BridgeHeal.active)
                or (BridgeWash ~= nil and BridgeWash.state ~= "idle")
        end)
        local danger = false
        pcall(function() danger = BridgeTask ~= nil and BridgeTask.dangerNear ~= nil and BridgeTask.dangerNear(body) end)
        local ground, sameZ, d = false, false, 99
        if red ~= nil then
            pcall(function()
                ground = red:isSitOnGround() == true
                local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
                d = math.sqrt(dx * dx + dy * dy)
                sameZ = math.abs(red:getZ() - body:getZ()) < 0.9
            end)
        end
        local limit = ours and BridgeMove.STAY_SIT_OUT or BridgeMove.STAY_SIT
        if ground and sameZ and d <= limit and not busy and not danger then
            if pose == nil then
                Bridge.pose = { anim = "Sit", staySit = true }
                pcall(function() body:setBumpType("Sit") end)
                pcall(function() body:faceLocationF(red:getX(), red:getY()) end)
                pcall(function() BridgeMove.sendSit("floor") end)
                log("stay-sit: sitting with the player while waiting")
            end
            return true
        end
    end
    if ours then
        Bridge.pose = nil
        pcall(function() BridgeMove.sendSit(nil) end)
        log("stay-sit: standing (player up, out of range, busy or danger)")
    end
    return false
end


BridgeMove.sitFlag = false
BridgeMove.sitFlagBody = nil

function BridgeMove.isOnChair(body)
    if body == nil then return false end
    local seated = false
    pcall(function() seated = body:isSittingOnFurniture() == true end)
    if seated then return true end
    local pose = nil
    if Bridge ~= nil then pose = Bridge.pose end
    if pose ~= nil and BridgeMove.CHAIR_POSES[pose.anim] == true then return true end
    local bump = ""
    pcall(function() bump = tostring(body:getBumpType()) end)
    if bump == "SitChair" or bump == "SitChairDown" or bump == "SitChairUp" then return true end
    return false
end

function BridgeMove.sitFlagOff(body)
    if not BridgeMove.sitFlag then return end
    local b = body or BridgeMove.sitFlagBody
    if b ~= nil then pcall(function() b:setReanimatedForGrappleOnly(false) end) end
    BridgeMove.sitFlag, BridgeMove.sitFlagBody = false, nil
end

function BridgeMove.sitFlagTick(body)
    if body == nil or body.setReanimatedForGrappleOnly == nil then return end
    if Bridge == nil or Bridge.kind ~= "zombie" then return end
    local mp = false
    pcall(function() mp = isClient() or isServer() end)
    if mp then BridgeMove.sitFlagOff(body) return end
    if BridgeFastForward ~= nil and BridgeFastForward.flagged ~= nil then return end
    local holding = BridgeMove.sitFlag == true
        or (BridgeTask ~= nil and BridgeTask.active == true)
        or Bridge.pose ~= nil
    if not holding
        and type(Bridge.companionUpdateDue) == "function"
        and not Bridge.companionUpdateDue(BridgeMove, "sitCapNext", 2) then
        return
    end
    if BridgeMove.isOnChair(body) then
        local fell = false
        pcall(function()
            local asn = tostring(body:getActionStateName())
            fell = string.find(asn, "falldown", 1, true) == 1
                or string.find(asn, "onground", 1, true) == 1
                or string.find(asn, "knockeddown", 1, true) == 1
                or string.find(asn, "hitreaction", 1, true) == 1
                or string.find(asn, "staggerback", 1, true) == 1
                or string.find(asn, "getup", 1, true) == 1
        end)
        if fell then
            BridgeMove.sitFlagOff(body)
            return
        end
        if BridgeTask ~= nil and BridgeTask.isSeated ~= nil and BridgeTask.isSeated(body) then
            local asn, bump = "", ""
            pcall(function() asn = tostring(body:getActionStateName()) end)
            pcall(function() bump = tostring(body:getBumpType()) end)
            if asn ~= "bumped" or bump ~= "SitChair" then
                pcall(function() body:setVariable("BumpAnimFinished", false) end)
                pcall(function() body:setBumpType("") end)
                pcall(function() body:setBumpType("SitChair") end)
            end
        end
        local on = false
        pcall(function() on = body:isReanimatedForGrappleOnly() == true end)
        if not on then
            pcall(function() body:setReanimatedForGrappleOnly(true) end)
            log("sit: her body out of the zombie check while seated")
        end
        BridgeMove.sitFlag, BridgeMove.sitFlagBody = true, body
    else
        BridgeMove.sitFlagOff(body)
    end
    if BridgeTask ~= nil and BridgeTask.isLying ~= nil and BridgeTask.isLying(body) then
        local asn, bump = "", ""
        pcall(function() asn = tostring(body:getActionStateName()) end)
        pcall(function() bump = tostring(body:getBumpType()) end)
        local anim = bump
        if anim ~= "LayAwake" and anim ~= "LayAsleep"
            and anim ~= "FloorLayAwake" and anim ~= "FloorLayAsleep" then
            anim = BridgeTask.layAnim
        end
        if (anim == "LayAwake" or anim == "LayAsleep"
            or anim == "FloorLayAwake" or anim == "FloorLayAsleep")
            and (asn ~= "bumped" or bump ~= anim) then
            pcall(function() body:setVariable("BumpAnimFinished", false) end)
            pcall(function() body:setBumpType("") end)
            pcall(function() body:setBumpType(anim) end)
        end
    end
end

function BridgeMove.sitDownNear(body, red, zones, S, d, inside)
    local bx, by = body:getX(), body:getY()
    local sameZ = math.abs(body:getZ() - zones.z) < 0.5
    S.bad = S.bad or {}
    if S.phase == nil and Bridge.time < (S.retryAt or 0) then return seatStand(body, red, d) end
    if S.phase == nil then
        local chair, seats = nil, 0
        if not zones.ground then chair, seats = BridgeMove.findChair(red, zones, body, S.bad) end
        if chair ~= nil then
            S.phase, S.goal, S.chair, S.phaseSince, S.path, S.via, S.gate = "go", { x = chair.ax, y = chair.ay }, chair, Bridge.time, false, nil, nil
            S.away, S.awayDone = nil, false
            log(sformat("seat: player sits, going to sit on %s at %d,%d facing %s (ring %d, %d seats checked), from %.2f,%.2f to %.2f,%.2f",
                tostring(chair.name), chair.x, chair.y, chair.dir, chair.ring, seats, bx, by, chair.ax, chair.ay))
        else
            local spot, checked = BridgeMove.seatSpot(red, zones, bx, by, body, S.bad)
            if spot == nil then
                if not S.noSpot then
                    S.noSpot = true
                    log(sformat("seat: player sits, no seat 2-%d cells (%d seats), no floor spot (%d cells), staying%s",
                        CHAIR.RING_MAX, seats, checked, inside and " in the way" or ""))
                end
                S.retryAt = Bridge.time + 60
                return seatStand(body, red, d)
            end
            S.noSpot = false
            S.phase, S.goal, S.chair, S.phaseSince, S.path, S.via, S.gate = "go", { x = spot.x + 0.5, y = spot.y + 0.5, floor = true }, nil, Bridge.time, false, nil, nil
            S.away, S.awayDone = nil, false
            log(sformat("seat: player sits, no seat 2-%d cells (%d seats checked), floor at %d,%d (ring %d)",
                CHAIR.RING_MAX, seats, spot.x, spot.y, spot.ring))
        end
    end
    local gx, gy = S.goal.x, S.goal.y
    local toGoal = dist2d(bx, by, gx, gy)

    local arrive = S.goal.floor and SEAT.ARRIVE or (S.path and 0.6 or CHAIR.ARRIVE)
    if sameZ and toGoal <= arrive then
        if BridgeMove.onPath() then BridgeMove.stopPath(body) end
        BridgeMove.moving = false
        Bridge.holdPos = nil
        if S.goal.floor then
            pcall(function() body:faceLocationF(red:getX(), red:getY()) end)
            S.phase, S.phaseSince = "floor", Bridge.time
            startPose(body, S, "Sit", false)
            BridgeMove.sendSit("floor")
            pcall(function() BridgeMoments.say("EvSitDown", 0, true, "SitDown") end)
            log(sformat("seat: sitting on the floor at %.2f,%.2f after %d ticks", bx, by, Bridge.time - S.since))
        else

            pcall(function()
                body:setX(gx)
                body:setY(gy)
                body:setLastX(gx)
                body:setLastY(gy)
            end)
            local sq = getCell():getGridSquare(math.floor(gx), math.floor(gy), zones.z)
            if sq ~= nil then pcall(function() body:setCurrent(sq) end) end
            pcall(function() body:faceDirection(IsoDirections.fromString(S.chair.dir)) end)
            S.phase, S.phaseSince = "down", Bridge.time
            chairFlags(body, S.chair)
            startPose(body, S, "SitChairDown", true)
            log(sformat("seat: sitting down on %d,%d facing %s from %.2f,%.2f (snapped %.2f)",
                S.chair.x, S.chair.y, S.chair.dir, gx, gy, toGoal))
        end
        return true
    end
    local key = S.chair and (S.chair.x .. "," .. S.chair.y) or (math.floor(gx) .. "," .. math.floor(gy))

    if S.giveUpAt == nil or S.goalSince ~= S.phaseSince then
        S.goalSince = S.phaseSince
        S.giveUpAt = S.phaseSince + SEAT.GIVE_UP + math.floor(60 * dist2d(bx, by, gx, gy))
    end
    if Bridge.time > S.giveUpAt then
        S.bad[key] = true
        log(sformat("seat: %s not reached in %d ticks, choosing again", key, Bridge.time - S.phaseSince))
        S.phase, S.goal, S.chair = nil, nil, nil
        return seatStand(body, red, d)
    end

    local ax, ay, stepping = routeAround(S, body, red, zones.z, gx, gy, d)
    if stepping then
        local F = BridgeMove.follow
        local pf = body:getPathFindBehavior2()
        if BridgeMove.pathing then
            pcall(function() pf:cancel() pf:reset() body:setPath2(nil) end)
            BridgeMove.pathing = false
            BridgeMove.goal = nil
        end
        Bridge.holdPos = nil
        BridgeMove.moving = true
        BridgeMove.steering = true
        freshDrive(F)
        if drive(body, red, F, pf, bx, by, ax, ay, 0.04, "seat", false, d, toGoal) then return true end
        S.away, S.awayDone = nil, true
    end


    if S.via ~= nil and dist2d(bx, by, S.via.x, S.via.y) <= 0.4 then S.via = nil end
    if S.via == nil and sameZ and not zoneFree(zones, bx, by, gx, gy) then
        if inside then
            local out = BridgeMove.seatSpot(red, zones, bx, by, body, nil)
            if out ~= nil then S.via = { x = out.x + 0.5, y = out.y + 0.5 } end
        else
            S.via = zoneDetour(zones, body, bx, by, gx, gy)
        end
        if S.via == nil then
            S.bad[key] = true
            log(sformat("seat: way to %.2f,%.2f crosses his cells and no way round, choosing again", gx, gy))
            S.phase, S.goal, S.chair = nil, nil, nil
            return seatStand(body, red, d)
        end
        log(sformat("seat: way to %.2f,%.2f crosses his cells, via %.1f,%.1f", gx, gy, S.via.x, S.via.y))
    end
    local tx, ty = gx, gy
    if S.via ~= nil then tx, ty = S.via.x, S.via.y end



    local seesTarget = BridgeMove.lineClear(body, tx, ty, zones.z)
    if S.gate ~= nil and (seesTarget or dist2d(bx, by, S.gate.x, S.gate.y) <= 0.15) then S.gate = nil end
    if S.gate == nil and not seesTarget then
        local t = BridgeMove.trail
        local seen, any = nil, nil
        for i = #t, 1, -1 do
            local p = t[i]
            local pcx, pcy = cellOf(p.x, p.y)
            if math.floor(p.z) == zones.z and not BridgeMove.inSeatZone(zones, pcx, pcy) and dist2d(bx, by, p.x, p.y) > 0.3
                and zoneFree(zones, p.x, p.y, tx, ty) and BridgeMove.lineClear(pointAt(p.x, p.y, zones.z), tx, ty, zones.z) then
                any = any or p
                if BridgeMove.lineClear(body, p.x, p.y, zones.z) and zoneFree(zones, bx, by, p.x, p.y) then seen = p break end
            end
        end
        local p = seen or any
        if p ~= nil then
            S.gate = { x = p.x, y = p.y }
            if S.gateLogged == nil or dist2d(S.gateLogged.x, S.gateLogged.y, p.x, p.y) > 0.5 then
                S.gateLogged = S.gate
                log(sformat("seat: %.2f,%.2f not in sight, first to his trail at %.2f,%.2f%s", tx, ty, p.x, p.y,
                    seen and "" or " (not in sight either, engine path)"))
            end
        end
    end
    if S.gate ~= nil then tx, ty = S.gate.x, S.gate.y end
    local toNext = dist2d(bx, by, tx, ty)

    local F = BridgeMove.follow
    local pf = body:getPathFindBehavior2()
    Bridge.holdPos = nil
    BridgeMove.moving = true
    if not S.path and sameZ and BridgeMove.lineClear(body, tx, ty, zones.z) then
        if BridgeMove.pathing then
            pcall(function() pf:cancel() pf:reset() body:setPath2(nil) end)
            BridgeMove.pathing = false
            BridgeMove.goal = nil
        end
        BridgeMove.steering = true
        local want = 0.036 * clamp(0.4 + 0.6 * toNext, 0.3, 0.9)
        if inside or S.via ~= nil then want = math.max(want, 0.05) end
        freshDrive(F)
        if drive(body, red, F, pf, bx, by, tx, ty, want, "seat", false, d, toGoal) then return true end


        S.stuck = (S.stuck or 0) + 1
        if S.gate == nil and not inside and S.stuck < 3 then
            S.bad[key] = true
            log(sformat("seat: stuck on the way to %.2f,%.2f, choosing again", tx, ty))
            S.phase, S.goal, S.chair, S.via = nil, nil, nil, nil
            return seatStand(body, red, d)
        end
        S.path = true
        log(sformat("seat: stuck on the way to his trail %.2f,%.2f, engine path", tx, ty))
    end
    if BridgeMove.steering then
        BridgeMove.endFollowBump(body, "")
        BridgeMove.steering = false
    end
    BridgeMove.setCollide(body, true)
    BridgeMove.walkType = "Walk"
    BridgeMove.applyAnimVars(body)
    BridgeMove.goToward(body, tx, ty, zones.z, true)
    if BridgeMove.lastFailed == Bridge.tick then
        S.bad[key] = true
        log(sformat("seat: path to %.2f,%.2f failed (%s) from %.2f,%.2f, d=%.2f, choosing again", tx, ty,
            tostring(BridgeMove.pathResult), bx, by, d))
        S.phase, S.goal, S.chair = nil, nil, nil
    end
    return true
end



function BridgeMove.seatStep(body)
    if BridgeMove.isOnChair(body) then return true end
    local red = BridgeData.owner()
    local zones = BridgeMove.seatZones(red)
    local S = BridgeMove.seat


    if Bridge.store ~= nil and Bridge.store.sit ~= nil then BridgeMove.sendSit(nil) end
    if zones == nil then
        BridgeMove.sitDangerLatch = nil
        if S ~= nil then
            log(sformat("seat: player is up, following again after %d ticks", Bridge.time - S.since))
            BridgeMove.seat = nil
        end
        return false
    end
    local bx, by = body:getX(), body:getY()
    local d = dist2d(bx, by, red:getX(), red:getY())



    local sameZ = math.abs(body:getZ() - zones.z) < 0.5
    local bcx, bcy = cellOf(bx, by)
    local inside = sameZ and BridgeMove.inSeatZone(zones, bcx, bcy)
    local rcx, rcy = cellOf(red:getX(), red:getY())

    local cells = math.max(math.abs(bcx - zones.cx), math.abs(bcy - zones.cy))
    if S == nil or S.why ~= zones.why then
        local where = {}
        for i, c in ipairs(zones) do where[i] = c.x .. "," .. c.y end
        log(sformat("seat: player %s, keep out of 3x3 around %s; me %d cells away (d=%.2f)%s",
            zones.why, table.concat(where, " "), cells, d, inside and ", in the way" or ""))
        if S == nil then
            S = { since = Bridge.time, bad = {} }
            BridgeMove.seat = S
        end
        S.why = zones.why
    end

    local danger = BridgeTask ~= nil and BridgeTask.dangerNear(body)
    if zones.ground and BridgeData.optionOf(Bridge.store, "sitWithRed")
            and not BridgeMove.sitDangerLatch and not danger then
        return BridgeMove.sitDownNear(body, red, zones, S, d, inside)
    end
    if S.phase ~= nil then S.phase, S.goal, S.chair = nil, nil, nil end



    if not inside and (not sameZ or cells > SEAT.STAY) then
        if Bridge.time >= (S.freedLog or 0) then
            S.freedLog = Bridge.time + 60
            log(sformat("seat: following, %s (her z=%.2f, floor %d, %d cells)%s", sameZ and "far" or "other floor",
                body:getZ(), zones.z, cells, S.spot ~= nil and sformat(", spot %d,%d dropped", S.spot.x, S.spot.y) or ""))
        end
        if S.spot ~= nil then S.spot, S.path = nil, false end
        return false
    end





    if S.spot == nil and not inside then
        if S.placed then return seatStand(body, red, d) end
        S.placed = true
        if BridgeMove.lineClear(seatFrom(red, zones), bx, by, zones.z) then
            local gap = BridgeMove.zoneGap(zones, bx, by)
            if gap >= SEAT.EDGE then return seatStand(body, red, d) end

            S.spot, S.path, S.spotSince, S.away, S.awayDone = { x = bcx, y = bcy, ring = cells }, false, Bridge.time, nil, true
            S.spotGiveUp = Bridge.time + 120
            log(sformat("seat: at the edge of his zone (gap %.2f), stepping into %d,%d", gap, bcx, bcy))
        else
            local spot, checked = BridgeMove.seatSpot(red, zones, bx, by, body, S.bad)
            if spot == nil or (spot.x == bcx and spot.y == bcy) then
                log(sformat("seat: out of his sight at %d,%d, %s, staying", bcx, bcy,
                    spot == nil and ("no spot (" .. checked .. " cells checked)") or "no better spot"))
                return seatStand(body, red, d)
            end
            S.spot, S.path, S.spotSince, S.away, S.awayDone = spot, false, Bridge.time, nil, false
            spot.forSight = true
            S.spotGiveUp = Bridge.time + SEAT.GIVE_UP + math.floor(60 * dist2d(bx, by, spot.x + 0.5, spot.y + 0.5))
            log(sformat("seat: out of his sight, %d cells, going once to %d,%d (ring %d, %d cells checked, d=%.2f)",
                cells, spot.x, spot.y, spot.ring, checked, d))
        end
    end

    if S.spot ~= nil and (BridgeMove.inSeatZone(zones, S.spot.x, S.spot.y) or not seatCellOk(S.spot.x, S.spot.y, zones.z)) then
        log(sformat("seat: spot %d,%d no longer fits (player %s)", S.spot.x, S.spot.y, zones.why))
        S.spot, S.path = nil, false
    end
    if S.spot == nil and Bridge.time < (S.retryAt or 0) then return seatStand(body, red, d) end
    if S.spot == nil then
        local spot, checked = BridgeMove.seatSpot(red, zones, bx, by, body, S.bad)
        if spot == nil then
            S.retryAt = Bridge.time + 60
            if not S.noSpot then
                S.noSpot = true
                log(sformat("seat: no free spot 2-%d cells from player (%d cells checked), staying%s",
                    SEAT.RING_MAX, checked, inside and " in the way" or ""))
            end
            return seatStand(body, red, d)
        end
        S.noSpot = false
        S.placed = true
        S.spot, S.path, S.spotSince, S.away, S.awayDone = spot, false, Bridge.time, nil, false
        S.spotGiveUp = Bridge.time + SEAT.GIVE_UP + math.floor(60 * dist2d(bx, by, spot.x + 0.5, spot.y + 0.5))
        log(sformat("seat: in the way, going to %d,%d (ring %d, %d cells checked, d=%.2f, turn %s deg)",
            spot.x, spot.y, spot.ring, checked, d, tostring(BridgeMove.facingOff(body, spot.x + 0.5, spot.y + 0.5))))
    end
    local px, py = S.spot.x + 0.5, S.spot.y + 0.5
    local toSpot = dist2d(bx, by, px, py)



    local nearOk = not inside and toSpot <= SEAT.NEAR and BridgeMove.zoneGap(zones, bx, by) >= SEAT.GAP
    if nearOk and S.spot.forSight and not BridgeMove.lineClear(seatFrom(red, zones), bx, by, zones.z) then nearOk = false end
    if sameZ and (toSpot <= SEAT.ARRIVE or nearOk) then
        log(sformat("seat: at %d,%d after %d ticks, %d cells from player", S.spot.x, S.spot.y,
            Bridge.time - S.spotSince, math.max(math.abs(S.spot.x - rcx), math.abs(S.spot.y - rcy))))
        S.spot, S.path = nil, false
        return seatStand(body, red, d)
    end
    if Bridge.time > (S.spotGiveUp or (S.spotSince + SEAT.GIVE_UP)) then
        S.bad[S.spot.x .. "," .. S.spot.y] = true
        log(sformat("seat: %d,%d not reached in %d ticks, another spot", S.spot.x, S.spot.y, Bridge.time - S.spotSince))
        S.spot, S.path = nil, false
        return seatStand(body, red, d)
    end
    local F = BridgeMove.follow
    local pf = body:getPathFindBehavior2()
    Bridge.holdPos = nil
    BridgeMove.moving = true
    local wx, wy, stepping = routeAround(S, body, red, zones.z, px, py, d)
    if stepping or (not S.path and sameZ and BridgeMove.lineClear(body, px, py, zones.z)) then

        if BridgeMove.pathing then
            pcall(function() pf:cancel() pf:reset() body:setPath2(nil) end)
            BridgeMove.pathing = false
            BridgeMove.goal = nil
        end
        BridgeMove.steering = true
        local toNext = dist2d(bx, by, wx, wy)
        local want = 0.036 * clamp(0.4 + 0.6 * toNext, 0.35, 0.9)


        local off = BridgeMove.facingOff(body, wx, wy)
        if inside and (off == nil or off < 90) then want = math.max(want, 0.05) end
        freshDrive(F)
        if drive(body, red, F, pf, bx, by, wx, wy, want, "seat", false, d, toSpot) then return true end
        if stepping then S.away, S.awayDone = nil, true end
        S.path = true
        log(sformat("seat: stuck on the way to %.2f,%.2f, engine path", wx, wy))
    end

    if BridgeMove.steering then
        BridgeMove.endFollowBump(body, "")
        BridgeMove.steering = false
    end
    BridgeMove.setCollide(body, true)
    BridgeMove.walkType = "Walk"
    BridgeMove.applyAnimVars(body)
    BridgeMove.goToward(body, px, py, zones.z, true)
    if BridgeMove.lastFailed == Bridge.tick then
        log(sformat("seat: path to %d,%d failed (%s) from %.2f,%.2f, d=%.2f", S.spot.x, S.spot.y,
            tostring(BridgeMove.pathResult), bx, by, d))
        S.bad[S.spot.x .. "," .. S.spot.y] = true
        log(sformat("seat: no path to %d,%d, another spot", S.spot.x, S.spot.y))
        S.spot, S.path = nil, false
    end
    return true
end




function BridgeMove.asideStep(body)
    local t = Bridge.target
    local red = BridgeData.owner()
    if t == nil or t.cellX == nil or red == nil then return false end
    local bx, by = body:getX(), body:getY()
    local toSpot = dist2d(bx, by, t.x, t.y)
    local d = dist2d(bx, by, red:getX(), red:getY())
    if math.abs(body:getZ() - math.floor(t.z or 0)) >= 0.5 then return false end
    local zones = BridgeMove.seatZones(red)
    local clear = zones ~= nil and toSpot <= SEAT.NEAR and BridgeMove.zoneGap(zones, bx, by) >= SEAT.GAP
    if toSpot <= SEAT.ARRIVE or clear then
        if BridgeMove.onPath() then BridgeMove.stopPath(body) end
        BridgeMove.moving = false
        Bridge.target = nil
        log(sformat("seat: waiting at %d,%d now, %d cells from player", t.cellX, t.cellY,
            math.max(math.abs(t.cellX - math.floor(red:getX())), math.abs(t.cellY - math.floor(red:getY())))))
        return true
    end
    if t.path or not BridgeMove.lineClear(body, t.x, t.y, t.z or 0) then return false end
    local pf = body:getPathFindBehavior2()
    if BridgeMove.pathing then
        pcall(function() pf:cancel() pf:reset() body:setPath2(nil) end)
        BridgeMove.pathing = false
        BridgeMove.goal = nil
    end
    Bridge.holdPos = nil
    BridgeMove.moving = true
    BridgeMove.steering = true
    local want = 0.036 * clamp(0.4 + 0.6 * toSpot, 0.35, 0.9)

    local off = BridgeMove.facingOff(body, t.x, t.y)
    if off == nil or off < 90 then want = math.max(0.05, want) end
    freshDrive(BridgeMove.follow)
    if drive(body, red, BridgeMove.follow, pf, bx, by, t.x, t.y, want, "aside", false, d, toSpot) then return true end
    t.path = true
    log(sformat("seat: stuck stepping aside to %d,%d, engine path", t.cellX, t.cellY))
    BridgeMove.steering = false
    return false
end





STRAIGHT.TURN_DEG = 25
STRAIGHT.PIVOT_DEG = 60
STRAIGHT.TURN_MAX = 8
function BridgeMove.goStraight(body, x, y, z, run, clear, backwards)
    local red = BridgeData.owner()
    if red == nil then return false end
    local F = BridgeMove.follow

    if F.pathUntil ~= nil and Bridge.time < F.pathUntil then return false end

    if clear ~= nil then
        if not clear(body, x, y, z or 0) then return false end
    elseif not BridgeMove.lineClear(body, x, y, z or 0) then
        return false
    end
    local pf = body:getPathFindBehavior2()
    if BridgeMove.pathing then
        pcall(function() pf:cancel() pf:reset() body:setPath2(nil) end)
        BridgeMove.pathing = false
        BridgeMove.goal = nil
    end

    if BridgeMove.kickAt ~= nil then
        pcall(function() if tostring(body:getBumpType()) == KICK then body:setBumpType("") end end)
        BridgeMove.kickAt = nil
    end
    Bridge.holdPos = nil
    BridgeMove.moving = true
    BridgeMove.steering = true
    local bx, by = body:getX(), body:getY()
    local toGoal = dist2d(bx, by, x, y)
    local d = dist2d(bx, by, red:getX(), red:getY())






    local kind = run and "straight-run" or "straight"
    local starting = (F.frame ~= Bridge.tick - 1 and F.pivotTick ~= Bridge.tick - 1) or F.kind ~= kind
    if starting then F.pivotFrames = 0 end
    if backwards ~= true then
        local off = BridgeMove.facingOff(body, x, y)
        if off ~= nil and off > STRAIGHT.TURN_DEG and (F.pivotFrames or 0) < STRAIGHT.TURN_MAX then
            F.pivotFrames = (F.pivotFrames or 0) + 1

            pcall(function() if isFollowBump(tostring(body:getBumpType())) then BridgeMove.endFollowBump(body, "Stand") end end)
            local left = BridgeMove.pivotToward(body, x, y, STRAIGHT.PIVOT_DEG)
            F.pivotTick, F.kind = Bridge.tick, kind

            if left ~= nil then return true end
        end
    end
    local M = BridgeMove.speedModel
    local want = run and (M.Run.a + M.Run.b * 0.8) or (M.Walk.a + M.Walk.b * 0.8)

    want = want * clamp(0.4 + 0.6 * toGoal, 0.5, 1.0)
    BridgeMove.walkType = run and "Run" or "Walk"
    freshDrive(F)
    BridgeMove.backwardsStep = backwards == true or nil
    local moved = drive(body, red, F, pf, bx, by, x, y, want, run and "straight-run" or "straight", run == true, d, toGoal)
    BridgeMove.backwardsStep = nil
    if moved then
        return true
    end
    BridgeMove.steering = false
    return false
end













BridgeMove.MOURN_PIVOT_DEG = 8
MOURN.CHEST_BACK = 0.38
MOURN.CHEST_FRONT = 0.25
MOURN.HEAD_BACK = 0.7
MOURN.HEAD_FRONT = 0.5
MOURN.FEET_BACK = 0.6
MOURN.FEET_FRONT = 0.75
MOURN.CLEAR = 0.45
MOURN.OFF_OUT = 0.12
BridgeMove.MOURN_CLEAR = MOURN.CLEAR



function BridgeMove.corpseLine(red)
    local rx, ry, z = red:getX(), red:getY(), red:getZ()
    local a = nil
    pcall(function() a = red:getAnimAngleRadians() end)
    if a == nil then
        pcall(function()
            local f = red:getForwardDirection()
            a = atan2(f:getY(), f:getX())
        end)
    end
    if a == nil then return nil end
    local front = false
    pcall(function() front = red:isFallOnFront() == true end)
    local hx, hy = math.cos(a), math.sin(a)
    if not front then hx, hy = -hx, -hy end
    local chest = front and MOURN.CHEST_FRONT or MOURN.CHEST_BACK
    local head = front and MOURN.HEAD_FRONT or MOURN.HEAD_BACK
    local feet = front and MOURN.FEET_FRONT or MOURN.FEET_BACK
    return { ex1 = rx + hx * head, ey1 = ry + hy * head, ex2 = rx - hx * feet, ey2 = ry - hy * feet,
             hx = hx, hy = hy, cx = rx + hx * chest, cy = ry + hy * chest, z = z, front = front }
end



function BridgeMove.mournBodyDist(s, px, py)
    local vx, vy = s.ex2 - s.ex1, s.ey2 - s.ey1
    local l2 = vx * vx + vy * vy
    local t = 0
    if l2 > 1e-9 then t = clamp(((px - s.ex1) * vx + (py - s.ey1) * vy) / l2, 0, 1) end
    local qx, qy = s.ex1 + vx * t, s.ey1 + vy * t
    return dist2d(px, py, qx, qy), qx, qy
end



function BridgeMove.mournCrosses(s, ax, ay, bx, by, clear)
    clear = clear or MOURN.CLEAR
    for i = 1, 8 do
        local t = i / 8
        local px, py = ax + (bx - ax) * t, ay + (by - ay) * t
        if segDist(px, py, s.ex1, s.ey1, s.ex2, s.ey2) < clear then return true end
    end
    return false
end






function BridgeMove.mournStepOff(body, s)
    local red = BridgeData.owner()
    if red == nil then return "stuck" end
    local bx, by = body:getX(), body:getY()
    local onD, qx, qy = BridgeMove.mournBodyDist(s, bx, by)
    if not (onD < MOURN.CLEAR or (s.offing and onD < MOURN.CLEAR + MOURN.OFF_OUT)) then
        s.offing = false
        return "off"
    end
    s.offing = true
    local ux, uy = bx - qx, by - qy
    local l = math.sqrt(ux * ux + uy * uy)
    if l < 0.05 then

        ux, uy, l = -s.hy, s.hx, 1
    end
    local out = MOURN.CLEAR + MOURN.OFF_OUT + 0.05
    local tx, ty = qx + ux / l * out, qy + uy / l * out
    if s.logged ~= "off" then
        s.logged = "off"
        log(sformat("mourning: on him (%.2f), one step off to %.2f,%.2f", onD, tx, ty))
    end
    if not BridgeMove.lineClear(body, tx, ty, s.z) then return "stuck" end
    local pf = body:getPathFindBehavior2()
    if BridgeMove.pathing then
        pcall(function() pf:cancel() pf:reset() body:setPath2(nil) end)
        BridgeMove.pathing = false
        BridgeMove.goal = nil
    end
    Bridge.holdPos = nil
    BridgeMove.moving = true
    BridgeMove.steering = true
    freshDrive(BridgeMove.follow)
    local d = dist2d(bx, by, red:getX(), red:getY())
    if drive(body, red, BridgeMove.follow, pf, bx, by, tx, ty, 0.02, "mourn", false, d, dist2d(bx, by, tx, ty)) then return "step" end
    BridgeMove.steering = false
    return "stuck"
end






function BridgeMove.holdEnginePath(body)
    local F = BridgeMove.follow
    if F.engineHold == nil then
        F.engineHold = { tick = Bridge.time, x = body:getX(), y = body:getY(), checkAt = Bridge.time + 120 }
    end
end





function BridgeMove.pushDir(red)
    local vx, vy = BridgeMove.redVx or 0, BridgeMove.redVy or 0
    if vx * vx + vy * vy > 0.000225 then return vx, vy end
    local fx, fy = 0, 0
    pcall(function()
        local f = red:getForwardDirection()
        fx, fy = f:getX(), f:getY()
    end)
    return fx, fy
end


function BridgeMove.onHisPath(bx, by, rx, ry, vx, vy)
    local vl = math.sqrt(vx * vx + vy * vy)
    if vl <= 0.01 then return nil end
    local ux, uy = vx / vl, vy / vl
    local ox, oy = bx - rx, by - ry
    local ahead = ux * ox + uy * oy
    local side = -uy * ox + ux * oy
    if ahead <= 0 or ahead >= ASIDE.AHEAD or math.abs(side) >= ASIDE.PATH then return nil end
    return ahead, side, ux, uy
end






local PASS_KEEP = 20
function BridgeMove.passThrough(body, on, why)
    local F = BridgeMove.follow
    if on then F.passUntil = Bridge.time + PASS_KEEP end
    if (F.passing == true) == on then return end
    local ok = pcall(function() body:setSolid(not on) end)
    F.passing = on and ok or nil
    if ok then log(on and ("lets player pass through: " .. tostring(why)) or ("solid again: " .. tostring(why))) end
end




function BridgeMove.pushCheck(body, red)
    local F = BridgeMove.follow
    if F == nil or red == nil then return end
    if F.back ~= nil then
        F.pushSinceIdle = nil
        return
    end
    local pushing, fx, fy = false, 0, 0
    pcall(function()
        pushing = red:isPlayerMoving() == true
        if not pushing then pushing = red:pressedMovement(true) == true end
    end)
    if pushing then fx, fy = BridgeMove.pushDir(red) end
    local ahead, d = nil, 0
    if pushing then
        pcall(function()
            ahead = BridgeMove.onHisPath(body:getX(), body:getY(), red:getX(), red:getY(), fx, fy)
            d = dist2d(body:getX(), body:getY(), red:getX(), red:getY())
        end)
    end
    local contact = pushing and ahead == nil and Bridge.follow and Bridge.pose == nil and d > 0 and d < 0.75

    if ahead == nil and not contact then
        if F.pushSeenIdle == nil or Bridge.time - F.pushSeenIdle > PUSH_GRACE then F.pushSinceIdle = nil end
        return
    end
    F.pushSeenIdle = Bridge.time
    F.pushSinceIdle = F.pushSinceIdle or Bridge.time
    if Bridge.time - F.pushSinceIdle >= ASIDE.PUSH then
        if contact then
            BridgeMove.passThrough(body, true, sformat("player pressed against her (%.2f)", d))
        else
            BridgeMove.passThrough(body, true, sformat("player keeps pushing while she %s (%.2f ahead)",
                Bridge.pose ~= nil and "sits" or (Bridge.follow and "follows" or "waits"), ahead))
        end
    end
end


function BridgeMove.passTick(body, red)
    local F = BridgeMove.follow
    if F == nil or not F.passing then return end
    local d2, pushing = math.huge, false
    pcall(function()
        local dx, dy = body:getX() - red:getX(), body:getY() - red:getY()
        d2 = dx * dx + dy * dy
        pushing = red:isPlayerMoving() == true
    end)
    if d2 < 0.64 then
        F.passUntil = Bridge.time + PASS_KEEP
        return
    end
    if Bridge.time >= (F.passUntil or 0) then
        BridgeMove.passThrough(body, false, d2 < 1.0 and "player stopped" or "player passed")
    end
end



function BridgeMove.onRunLine(bx, by, rx, ry, fx, fy)
    local vl = math.sqrt(fx * fx + fy * fy)
    if vl <= 0.01 then return nil end
    local ux, uy = fx / vl, fy / vl
    local ox, oy = bx - rx, by - ry
    local ahead = ux * ox + uy * oy
    local side = -uy * ox + ux * oy
    if ahead <= -0.2 or ahead >= RUN.AHEAD or math.abs(side) >= RUN.PATH then return nil end
    return ahead, side, ux, uy
end









function BridgeMove.runGuard(body, red)
    if body == nil or red == nil then return end
    local running = false
    pcall(function() running = red:isRunning() == true or red:isSprinting() == true end)
    if not running then return end
    local ahead, side = nil, nil
    pcall(function()
        if math.abs(body:getZ() - red:getZ()) > 0.3 then return end
        local f = red:getForwardDirection()
        ahead, side = BridgeMove.onRunLine(body:getX(), body:getY(), red:getX(), red:getY(), f:getX(), f:getY())
    end)
    if ahead == nil then return end
    BridgeMove.passThrough(body, true, sformat("player runs at her (%.2f ahead, %.2f aside)", ahead, side))
end


local function stepAside(body, F, A, d)
    BridgeMove.walkType = "Walk"
    BridgeMove.applyAnimVars(body)
    BridgeMove.steering = true
    BridgeMove.followWs = 1.0
    BridgeMove.followBump(body, "Walk")
    if BridgeMove.bumpMove == "face" then
        BridgeMove.turnToward(body, A.x, A.y, 180)
    else
        pcall(function() body:getPathFindBehavior2():moveToPoint(A.x, A.y, 1.0) end)
    end
    BridgeMove.moving = true
    F.kind, F.s, F.want = "aside", 1.0, 0
    BridgeMove.pathResult = "follow-aside"
    trackStep(body)
    BridgeRoute.trace(body, d, false, false)
    pcall(function()
        if BridgeCallout ~= nil and type(BridgeCallout.bumpAside) == "function" then
            BridgeCallout.bumpAside()
        end
    end)
    return true
end

function BridgeMove.backClear(body, x, y, z)
    if not BridgeMove.lineClear(body, x, y, z) then return false end
    if BridgeFight ~= nil and BridgeFight.clearAt ~= nil then
        return BridgeFight.clearAt(body, x, y, z, nil) == true
    end
    return true
end

function BridgeMove.backGoal(body, red, vx, vy, d)
    local vl = math.sqrt(vx * vx + vy * vy)
    if vl <= 0.01 then return nil end
    local ux, uy = vx / vl, vy / vl
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local rx, ry = red:getX(), red:getY()
    local scales = { 1.0, 0.6, 0.35 }
    for i = 1, #scales do
        local len = BACK.step * scales[i]
        local x, y = bx + ux * len, by + uy * len
        local rd = dist2d(x, y, rx, ry)
        if rd >= d + 0.2 * len and rd <= BACK.leash and BridgeMove.backClear(body, x, y, bz) then
            return x, y
        end
    end
    return nil
end

function BridgeMove.backEnd(body, F, why, d)
    local bump = ""
    pcall(function() bump = tostring(body:getBumpType()) end)
    if bump == BACK.bump then pcall(function() body:setBumpType("") end) end
    local fightOwns = BridgeFight ~= nil and BridgeFight.state == "step" and BridgeFight.stepBump ~= nil
    if not fightOwns then pcall(function() body:setAnimatingBackwards(false) end) end
    BridgeMove.backActive = false
    F.back = nil
    F.backQuiet = Bridge.time + BACK.quiet
    BridgeMove.moving = false
    if Bridge.verbose then
        log(sformat("follow back end: %s, d %.2f, %d flips", tostring(why), d or 0, F.backFlips or 0))
    end
end

function BridgeMove.backStart(body, F, red, vx, vy, d)
    if F.asideTo ~= nil then return false end
    local gx, gy = BridgeMove.backGoal(body, red, vx, vy, d)
    if gx == nil then return false end
    F.back = { x = gx, y = gy, z = body:getZ(), tick = Bridge.time, lastD = d, lastCheck = Bridge.time,
               axisX = vx, axisY = vy, retargetAt = Bridge.time, count = 0, stall = 0 }
    F.backFlips = 0
    F.pushSince, F.pushSeen = nil, nil
    if Bridge.verbose then
        log(sformat("follow back: d %.2f, goal %.2f %.2f, player %.2f %.2f", d, gx, gy, red:getX(), red:getY()))
    end
    pcall(function()
        if BridgeCallout ~= nil and type(BridgeCallout.bumpAside) == "function" then
            BridgeCallout.bumpAside()
        end
    end)
    return true
end

function BridgeMove.backTick(body, F, red)
    local b = F.back
    local bx, by = body:getX(), body:getY()
    local d = dist2d(bx, by, red:getX(), red:getY())
    if Bridge.time - b.lastCheck >= 4 then
        b.lastCheck = Bridge.time
        if d < b.lastD + BACK.gain then b.stall = (b.stall or 0) + 4 else b.stall = 0 end
        b.lastD = d
    end
    b.count = b.count + 1
    if d >= BACK.leash then
        BridgeMove.backEnd(body, F, "leash", d)
        return false
    end
    if (b.stall or 0) >= BACK.stall then
        BridgeMove.backEnd(body, F, "stall", d)
        return false
    end
    if Bridge.time - b.tick >= BACK.max then
        BridgeMove.backEnd(body, F, "timeout", d)
        return false
    end
    local ux, uy = BridgeMove.pushDir(red)
    local ul = math.sqrt(ux * ux + uy * uy)
    if ul > 0.01 then
        ux, uy = ux / ul, uy / ul
        if (b.axisX or 0) * ux + (b.axisY or 0) * uy < 0 then F.backFlips = (F.backFlips or 0) + 1 end
        b.axisX, b.axisY = ux, uy
    end
    local gx, gy = BridgeMove.backGoal(body, red, ux, uy, d)
    if gx == nil then
        BridgeMove.backEnd(body, F, "blocked", d)
        return false
    end
    local moved = BridgeMove.goStraight(body, gx, gy, body:getZ(), false, BridgeMove.backClear, true)
    if not moved then
        BridgeMove.backEnd(body, F, "no move", d)
        return false
    end
    pcall(function() body:setBumpType(BACK.bump) end)
    pcall(function() body:setAnimatingBackwards(true) end)
    pcall(function() body:faceLocationF(red:getX(), red:getY()) end)
    BridgeMove.backActive = true
    BridgeMove.walkType = "Walk"
    BridgeMove.moving = true
    F.kind, F.s, F.want = "back", 1.0, 0
    BridgeMove.pathResult = "follow-back"
    trackStep(body)
    BridgeRoute.trace(body, d, false, false)
    if (b.count % 15) == 0 and Bridge.verbose then
        log(sformat("follow back: d %.2f, goal %.2f %.2f, player %.2f %.2f", d, gx, gy, red:getX(), red:getY()))
    end
    return true
end

MEM.followStallOpts = nil









local function postAt(cell, ax, ay, bx, by, z)
    local a = cell:getGridSquare(ax, ay, z)
    local b = cell:getGridSquare(bx, by, z)
    if a == nil or b == nil then return true end
    return a:isBlockedTo(b) or not a:isFree(false) or not b:isFree(false)
end






local function narrowEdge(cell, from, to, z)
    if from:isDoorTo(to) then return true, true end
    local fx, fy, tx, ty = from:getX(), from:getY(), to:getX(), to:getY()
    local function side(dx, dy)
        return postAt(cell, fx + dx, fy + dy, tx + dx, ty + dy, z)
            or from:isBlockedTo(cell:getGridSquare(fx + dx, fy + dy, z) or from)
            or to:isBlockedTo(cell:getGridSquare(tx + dx, ty + dy, z) or to)
    end
    if fx ~= tx then return side(0, -1) and side(0, 1), false end
    return side(-1, 0) and side(1, 0), false
end





function BridgeMove.doorwayCell(cx, cy, z)
    local F = BridgeMove.follow
    local key = cx .. "," .. cy .. "," .. z
    if F.doorCells == nil or (F.doorCellsN or 0) > 200 then F.doorCells, F.doorCellsN = {}, 0 end
    local c = F.doorCells[key]
    if c ~= nil and Bridge.time - c.tick < 100 then return c.value end
    local value = false
    pcall(function()
        local cell = getCell()
        local me = cell:getGridSquare(cx, cy, z)
        if me == nil then return end
        local function open(a, b)
            if a == nil or b == nil or a:isBlockedTo(b) then return false end
            local climb = false
            pcall(function() climb = a:getWindowTo(b) ~= nil or a:getWindowFrameTo(b) ~= nil or a:isHoppableTo(b) end)
            return not climb
        end
        for _, s in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nb = cell:getGridSquare(cx + s[1], cy + s[2], z)
            if open(me, nb) then
                local narrow, door = narrowEdge(cell, me, nb, z)
                if door then value = true return end
                if narrow then
                    local nxt = cell:getGridSquare(cx + 2 * s[1], cy + 2 * s[2], z)
                    local prv = cell:getGridSquare(cx - s[1], cy - s[2], z)
                    local nextNarrow = open(nb, nxt) and (narrowEdge(cell, nb, nxt, z)) == true
                    local prevNarrow = open(prv, me) and (narrowEdge(cell, prv, me, z)) == true
                    if not (nextNarrow and prevNarrow) then value = true return end
                end
            end
        end
    end)
    if c == nil then F.doorCellsN = (F.doorCellsN or 0) + 1 end
    F.doorCells[key] = { tick = Bridge.time, value = value }
    return value
end




function BridgeMove.inDoorway(body)
    local F = BridgeMove.follow
    local bx, by = body:getX(), body:getY()
    if BridgeMove.doorwayCell(math.floor(bx), math.floor(by), math.floor(body:getZ())) then
        F.doorAt = { x = bx, y = by, tick = Bridge.time }
        return true
    end
    local a = F.doorAt
    if a ~= nil then
        if Bridge.time - a.tick < 90 and dist2d(a.x, a.y, bx, by) < DOORWAY.CLEAR then return true end
        F.doorAt = nil
    end
    return false
end





function BridgeMove.throughNarrow(body, px, py)
    local rx, ry, used = px, py, false
    local F = BridgeMove.follow
    local c = F.cross
    if c ~= nil then
        local bx, by = body:getX(), body:getY()
        local past = (c.axis == "x") and ((bx - c.edge) * c.dir > 0.25) or ((by - c.edge) * c.dir > 0.25)
        local away = dist2d(bx, by, c.tx, c.ty) > 3.5





        local closed = false
        if c.door and c.fx ~= nil then
            pcall(function()
                local cell = getCell()
                local a = cell:getGridSquare(c.fx, c.fy, c.z)
                local b = cell:getGridSquare(c.bx2, c.by2, c.z)
                closed = a ~= nil and b ~= nil and a:isBlockedTo(b)
            end)
        end
        if closed then
            F.cross = nil
            F.pathUntil = Bridge.time + 60
            F.stuckAt = nil
            log("cross dropped: door on the edge closed")
            return px, py, false
        end
        if past or away or Bridge.time > c.until_ then
            F.cross = nil
        else
            return c.tx, c.ty, true
        end
    end
    pcall(function()
        local cell = getCell()
        local z = math.floor(body:getZ())
        local bx, by = body:getX(), body:getY()
        local dist = math.sqrt((px - bx) ^ 2 + (py - by) ^ 2)
        if dist < 0.05 then return end
        local steps = math.max(1, math.ceil(math.min(dist, 1.2) / 0.1))
        local sx0, sy0 = math.floor(bx), math.floor(by)
        for i = 1, steps do
            local t = i * 0.1 / dist
            if t > 1 then t = 1 end
            local sx, sy = math.floor(bx + (px - bx) * t), math.floor(by + (py - by) * t)
            if sx ~= sx0 or sy ~= sy0 then
                if sx ~= sx0 and sy ~= sy0 then return end
                local from = cell:getGridSquare(sx0, sy0, z)
                local to = cell:getGridSquare(sx, sy, z)
                if from == nil or to == nil then return end
                local isNarrow, isDoor = narrowEdge(cell, from, to, z)
                if not isNarrow then return end


                if sx ~= sx0 then
                    local dir = sx > sx0 and 1 or -1
                    local ex, cy = math.max(sx, sx0), sy0 + 0.5
                    rx, ry = ex + dir * 0.6, cy
                    F.cross = { axis = "x", edge = ex, dir = dir, tx = rx, ty = ry, door = isDoor, until_ = Bridge.time + 150,
                        fx = sx0, fy = sy0, bx2 = sx, by2 = sy, z = z }
                else
                    local dir = sy > sy0 and 1 or -1
                    local ey, cx = math.max(sy, sy0), sx0 + 0.5
                    rx, ry = cx, ey + dir * 0.6
                    F.cross = { axis = "y", edge = ey, dir = dir, tx = rx, ty = ry, door = DOOR.isDoor, until_ = Bridge.time + 150,
                        fx = sx0, fy = sy0, bx2 = sx, by2 = sy, z = z }
                end
                used = true
                return
            end
        end
    end)
    return rx, ry, used
end







local function stepNeedsClimbImpl(a, b)
    return a:getWindowTo(b) ~= nil or a:getWindowFrameTo(b) ~= nil or a:isHoppableTo(b)
end

local function stepNeedsClimb(a, b)
    local ok, yes = pcall(stepNeedsClimbImpl, a, b)
    if not ok then return false end
    return yes and true or false
end










local function engineBlockedImpl(a, b)
    if not (a:HasStairs() or b:HasStairs()) then return false end
    return a:testCollideAdjacentAdvanced(b:getX() - a:getX(), b:getY() - a:getY(), 0, false) == true
end

local function engineBlocked(a, b)
    if BridgeMove.engineTest == nil then
        local has = false
        pcall(function() has = a.testCollideAdjacentAdvanced ~= nil end)
        BridgeMove.engineTest = has
        log("engine collide test " .. (has and "available" or "missing: line check as before"))
    end
    if not BridgeMove.engineTest then return false end
    local ok, blocked = pcall(engineBlockedImpl, a, b)
    return ok and blocked == true
end
BridgeMove.engineBlocked = engineBlocked


local function underCar(sq)
    local F = BridgeMove.follow
    if F.carCells == nil or (F.carCellsN or 0) > 300 then F.carCells, F.carCellsN = {}, 0 end
    local key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
    local c = F.carCells[key]
    if c ~= nil and Bridge.time - c.tick < 30 then return c.value end
    local value = false
    pcall(function() value = sq:isVehicleIntersecting() == true end)
    if c == nil then F.carCellsN = (F.carCellsN or 0) + 1 end
    F.carCells[key] = { tick = Bridge.time, value = value }
    return value
end






local function lineClearImpl(body, gx, gy, gz)
    if math.abs(body:getZ() - gz) >= 0.5 then return false end
    local cell = getCell()
    local bx, by = body:getX(), body:getY()
    local z = math.floor(gz)
    local dx, dy = gx - bx, gy - by
    local dist = math.sqrt(dx ^ 2 + dy ^ 2)
    local steps = math.max(1, math.ceil(dist / 0.4))
    local prev = cell:getGridSquare(math.floor(bx), math.floor(by), z)
    if prev == nil then return false end
    local prevX, prevY = prev:getX(), prev:getY()

    local cars = true
    for i = 1, steps do
        local t = i / steps
        local sx, sy = math.floor(bx + dx * t), math.floor(by + dy * t)
        if sx ~= prevX or sy ~= prevY then
            local sq = cell:getGridSquare(sx, sy, z)
            if sq == nil then return false end
            if sx ~= prevX and sy ~= prevY then
                local a = cell:getGridSquare(sx, prevY, z)
                local b = cell:getGridSquare(prevX, sy, z)
                if a == nil or b == nil or prev:isBlockedTo(a) or a:isBlockedTo(sq) or prev:isBlockedTo(b) or b:isBlockedTo(sq) then return false end
                if stepNeedsClimb(prev, a) or stepNeedsClimb(a, sq) or stepNeedsClimb(prev, b) or stepNeedsClimb(b, sq) then return false end
                if not a:isFree(false) or not b:isFree(false) then return false end
                if engineBlocked(prev, a) or engineBlocked(a, sq) or engineBlocked(prev, b) or engineBlocked(b, sq) then return false end
                if cars and (underCar(a) or underCar(b)) then return false end
            elseif prev:isBlockedTo(sq) or stepNeedsClimb(prev, sq) or engineBlocked(prev, sq) then
                return false
            end
            if i < steps and not sq:isFree(false) then return false end
            if i < steps and cars and underCar(sq) then return false end
            prev, prevX, prevY = sq, sx, sy
        end
    end
    return true
end

MEM.lcTick, MEM.lcBody, MEM.lcKX, MEM.lcKY, MEM.lcKZ, MEM.lcVal = nil, nil, nil, nil, nil, false

function BridgeMove.lineClear(body, gx, gy, gz)
    if body == nil or gx == nil or gy == nil then return false end
    local tick = Bridge.tick or 0
    local kx = math.floor(gx * 10 + 0.5)
    local ky = math.floor(gy * 10 + 0.5)
    local kz = math.floor((gz or 0) * 10 + 0.5)
    if MEM.lcTick == tick and MEM.lcBody == body and MEM.lcKX == kx and MEM.lcKY == ky and MEM.lcKZ == kz then
        return MEM.lcVal
    end
    local ok, clear = pcall(lineClearImpl, body, gx, gy, gz)
    local v = ok and clear == true
    MEM.lcTick, MEM.lcBody, MEM.lcKX, MEM.lcKY, MEM.lcKZ, MEM.lcVal = tick, body, kx, ky, kz, v
    return v
end

local WALK_REACH_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local WALK_REACH_KEY = 2097152

function BridgeMove.walkReach(body, tx, ty, tz, maxNodes, passDoors, blockSeats)
    local ok = false
    local visited, doorHits = 0, 0
    pcall(function()
        local cell = getCell()
        local bz = math.floor(body:getZ())
        if math.floor(tz) ~= bz then return end
        local bx, by = math.floor(body:getX()), math.floor(body:getY())
        tx, ty = math.floor(tx), math.floor(ty)
        if bx == tx and by == ty then ok = true return end
        local start = cell:getGridSquare(bx, by, bz)
        if start == nil then return end
        local budget = maxNodes or 240
        local dirs = WALK_REACH_DIRS
        local seen = { [bx * WALK_REACH_KEY + by] = true }
        local queue, head = { start }, 1
        while head <= #queue and visited < budget do
            local cur = queue[head]
            head = head + 1
            visited = visited + 1
            local cx, cy = cur:getX(), cur:getY()
            for i = 1, 4 do
                local nx, ny = cx + dirs[i][1], cy + dirs[i][2]
                local key = nx * WALK_REACH_KEY + ny
                if not seen[key] then
                    local nb = cell:getGridSquare(nx, ny, bz)
                    if nb ~= nil then


                        local okHop, hopType = pcall(BridgeMove.edgeBetween, body, cur, nb)
                        local hop = okHop and hopType == "fence"
                        local step = hop or (not cur:isBlockedTo(nb) and not stepNeedsClimb(cur, nb))
                        local door = cur:isDoorTo(nb)
                        local doorOk = true
                        if door then
                            doorHits = doorHits + 1
                            doorOk = false
                            if passDoors then
                                local d = nil
                                pcall(function() d = cur:getDoorTo(nb) end)
                                if d == nil then
                                    doorOk = true
                                elseif BridgeDoors ~= nil and type(BridgeDoors.isPassable) == "function" then
                                    doorOk = BridgeDoors.isPassable(d) == true
                                else
                                    doorOk = true
                                end
                            end
                        end
                        if door and doorOk then step = true end
                        local seatBlocked = false
                        if blockSeats and math.abs(nb:getX() - tx) + math.abs(nb:getY() - ty) <= 2
                                and BridgeTask ~= nil and type(BridgeTask.seatIsSeat) == "function" then
                            pcall(function()
                                local objs = nb:getObjects()
                                for i = 0, objs:size() - 1 do
                                    if BridgeTask.seatIsSeat(objs:get(i)) then seatBlocked = true break end
                                end
                            end)
                        end
                        if step and doorOk and not seatBlocked and not underCar(nb) and nb:isFree(false) then
                            if nx == tx and ny == ty then ok = true return end
                            seen[key] = true
                            queue[#queue + 1] = nb
                        end
                    end
                end
            end
        end
    end)
    if BridgeTask ~= nil and BridgeTask.seatTrace == true then
        log(string.format("walkReach %d,%d,%d found=%s visited=%d doorHits=%d budget=%d doors=%s seats=%s",
            math.floor(tx or 0), math.floor(ty or 0), math.floor(tz or 0),
            tostring(ok), visited, doorHits, maxNodes or 240,
            tostring(passDoors == true), tostring(blockSeats == true)))
    end
    return ok
end


local TRACE_EVERY = 2








BridgeMove.slowDist = 1.6
local function capRun(walk, d)
    if walk ~= "Run" then return walk end
    local bf = rawget(_G, "BridgeFight")
    if bf == nil or type(bf.profile) ~= "function" then return walk end
    local okP, prof = pcall(bf.profile)
    if not okP or prof == nil then return walk end
    local limit = tonumber(prof.noRunFrom) or 99
    if limit <= 0 then return walk end
    local okL, level = pcall(bf.exhaustionLevel)
    if not okL or (tonumber(level) or 0) < limit then return walk end
    if Bridge ~= nil and Bridge.follow and type(bf.mode) == "function" then
        local okM, mode = pcall(bf.mode)
        local leash = okM and tonumber(mode and mode.leash) or nil
        if leash ~= nil and (tonumber(d) or 0) > leash then return walk end
    end
    return "Walk"
end
local function pickWalkType(d)
    if BridgeMove.forcedWalk ~= nil then return BridgeMove.forcedWalk end
    local red = BridgeData.owner()
    local running = false
    if red ~= nil then
        pcall(function() running = red:isRunning() or red:isSprinting() end)
    end
    if running or d > RUN.DIST then return capRun("Run", d) end

    if BridgeMove.walkType == "Run" and d > RUN.STOP then return capRun("Run", d) end
    if BridgeMove.slowDist > 0 and BridgeMove.redMoving and d < BridgeMove.slowDist then return "SlowWalk" end
    return "Walk"
end




local function squareAhead(body)
    local dir = body:getDirectionAngle()
    local bx, by, bz = math.floor(body:getX()), math.floor(body:getY()), body:getZ()
    local sx, sy
    if (dir >= -180 and dir < -45) or (dir >= 135 and dir <= 180) then
        sx, sy = bx, by
    elseif dir >= -45 and dir < 45 then
        sx, sy = bx + 1, by
    elseif dir >= 45 and dir < 135 then
        sx, sy = bx, by + 1
    end
    if sx == nil then return nil end
    return getCell():getGridSquare(sx, sy, bz)
end











function DOOR.isDoor(object)
    local door = false
    pcall(function() door = instanceof(object, "IsoDoor") or (instanceof(object, "IsoThumpable") and object:isDoor()) end)
    return door
end



function DOOR.doorKind(door)
    local kind = "single"
    pcall(function()
        if IsoDoor.getDoubleDoorIndex(door) ~= -1 then
            kind = "double"
        elseif instanceof(door, "IsoDoor") and IsoDoor.getGarageDoorIndex(door) ~= -1 then
            kind = "garage"
        end
    end)
    return kind
end


function DOOR.doorParts(door, kind)
    local parts = {}
    pcall(function()
        if kind == "double" then
            for i = 1, 4 do
                local p = IsoDoor.getDoubleDoorObject(door, i)
                if p ~= nil then parts[#parts + 1] = p end
            end
        elseif kind == "garage" then
            parts[1] = door
            local p = IsoDoor.getGarageDoorPrev(door)
            while p ~= nil and #parts < 12 do parts[#parts + 1] = p p = IsoDoor.getGarageDoorPrev(p) end
            p = IsoDoor.getGarageDoorNext(door)
            while p ~= nil and #parts < 24 do parts[#parts + 1] = p p = IsoDoor.getGarageDoorNext(p) end
        end
    end)
    if #parts == 0 then parts = { door } end
    return parts
end






function DOOR.doorAnchor(door, kind)
    if kind ~= "double" then return door end
    local anchor = nil
    pcall(function() anchor = IsoDoor.getDoubleDoorObject(door, 1) or IsoDoor.getDoubleDoorObject(door, 4) end)
    return anchor or door
end




function DOOR.doorCells(door, kind)
    local cells = {}
    local north = false
    pcall(function() north = door:getNorth() end)
    for _, p in ipairs(DOOR.doorParts(door, kind)) do
        local sq = p:getSquare()
        if sq ~= nil then
            local x, y = sq:getX(), sq:getY()
            cells[#cells + 1] = { x = x, y = y, z = sq:getZ(), ox = north and x or x - 1, oy = north and y - 1 or y }
        end
    end
    return cells, north
end



function DOOR.carInDoorway(cells)
    local cell = getCell()
    for _, c in ipairs(cells) do
        for _, xy in ipairs({ { c.x, c.y }, { c.ox, c.oy } }) do
            local sq = cell:getGridSquare(xy[1], xy[2], c.z)
            local car = nil
            if sq ~= nil then pcall(function() car = sq:getVehicleContainer() end) end
            if car ~= nil then return true end
        end
    end
    return false
end


DOOR.SOUND_RADIUS = 10
DOOR.SOUND_GAIN = 0.7


function DOOR.playerFarFromSquare(sq)
    if sq == nil then return true end
    local red = BridgeData ~= nil and BridgeData.owner() or nil
    if red == nil then return true end
    local far = true
    pcall(function()
        if math.abs(red:getZ() - sq:getZ()) >= 0.5 then return end
        far = dist2d(red:getX(), red:getY(), sq:getX() + 0.5, sq:getY() + 0.5) > DOOR.SOUND_RADIUS
    end)
    return far
end


function BridgeMove.toggleDoor(body, door, kind)
    kind = kind or DOOR.doorKind(door)
    local wasOpen = door:IsOpen()
    local sq = nil
    pcall(function() sq = door:getSquare() end)
    local far = DOOR.playerFarFromSquare(sq)
    local byGame = false
    local engineSound = false
    if kind == "double" then
        local blocked = true
        pcall(function() blocked = IsoDoor.isDoubleDoorObstructed(door) end)
        if blocked then
            log("toggleDoor rejected kind=double obstructed")
            return false
        end
        IsoDoor.toggleDoubleDoor(door, true)
    elseif kind == "garage" then
        if wasOpen and DOOR.carInDoorway(DOOR.doorCells(door, kind)) then
            log("toggleDoor rejected kind=garage car in doorway")
            return false
        end
        IsoDoor.toggleGarageDoor(door, true)
    else









        local actor = nil
        if not far and BridgeData ~= nil then actor = BridgeData.owner() end
        if not wasOpen and BridgeDoors ~= nil then
            local locked = false
            pcall(function() locked = door:isLocked() == true or door:isLockedByKey() == true end)
            if locked and BridgeDoors.hasKey(door, body, true) then BridgeDoors.unlock(door) end
        end
        if actor ~= nil then
            pcall(function() door:ToggleDoor(actor) end)
            byGame = door:IsOpen() ~= wasOpen
        end
        engineSound = byGame
        if not byGame then
            if sq ~= nil then
                door:DirtySlice()
                IsoGridSquare.RecalcLightTime = -1.0
                sq:InvalidateSpecialObjectPaths()
                door:ToggleDoorSilent()
                sq:RecalcProperties()
                pcall(function() door:syncIsoObject(false, 1, nil, nil) end)
                pcall(function() LuaEventManager.triggerEvent("OnContainerUpdate") end)
                pcall(function() door:invalidateRenderChunkLevel(FBORenderChunk.DIRTY_OBJECT_MODIFY) end)
            else
                pcall(function() door:ToggleDoorSilent() end)
            end
        end
    end
    local open = door:IsOpen()
    local sound = "-"
    if open ~= wasOpen and not engineSound then
        local prefix = "WoodDoor"
        pcall(function() prefix = door:getSoundPrefix() or "WoodDoor" end)
        sound = prefix .. (open and "Open" or "Close")
        if sq ~= nil then
            if BridgeSound ~= nil and type(BridgeSound.world) == "function" then
                BridgeSound.world(sound, sq, DOOR.SOUND_RADIUS, DOOR.SOUND_GAIN)
            else
                pcall(function()
                    getSoundManager():PlayWorldSound(sound, sq, 0, DOOR.SOUND_RADIUS, DOOR.SOUND_GAIN, true)
                end)
            end
        end
    end
    local sx, sy = -1, -1
    if sq ~= nil then pcall(function() sx, sy = sq:getX(), sq:getY() end) end
    log(sformat("toggleDoor kind=%s open=%s wasOpen=%s far=%s engineSound=%s sound=%s at=%s,%s",
        tostring(kind), tostring(open), tostring(wasOpen), tostring(far), tostring(engineSound),
        tostring(sound), tostring(sx), tostring(sy)))
    local dkey = nil
    if BridgeDoors ~= nil and type(BridgeDoors.key) == "function" then
        pcall(function() dkey = BridgeDoors.key(door) end)
    end
    if dkey ~= nil then
        BridgeMove.doorState = BridgeMove.doorState or {}
        BridgeMove.doorState[dkey] = { open = not wasOpen, at = Bridge.time }
    end
    if open == wasOpen then return false end
    return true
end




BridgeMove.opened = {}
BridgeMove.keepOpenDoors = setmetatable({}, { __mode = "k" })
BridgeMove.doorLast = "none"

function BridgeMove.markKeepOpen(door)
    if door ~= nil then BridgeMove.keepOpenDoors[door] = true end
end

function BridgeMove.clearKeepOpen(door)
    if door ~= nil then BridgeMove.keepOpenDoors[door] = nil end
end
DOOR.FORGET = 6000
DOOR.BACK = 180




DOOR.PASSED = 0.5
DOOR.EDGE = 0.4
DOOR.REACH = 2.3
DOOR.BACK_OFF = 1.2
local OWN_BEHIND = 4.0
local OWN_AT_DOOR = 3.0


function DOOR.doorSide(rec, x, y)
    local v = rec.north and y or x
    return (v < rec.edge) and -1 or 1, math.abs(v - rec.edge)
end

function BridgeMove.rememberDoor(body, door, kind, cells, north)
    if #cells == 0 then return end
    local rec = { door = door, kind = kind, cells = cells, north = north, tick = Bridge.time }
    local use = BridgeMove.doorUse[door]
    if use ~= nil and Bridge.time - (use.at or 0) <= 600 then
        use.n = (use.n or 0) + 1
        use.at = Bridge.time
    else
        use = { n = 1, at = Bridge.time }
        BridgeMove.doorUse[door] = use
    end
    if use.n >= 4 then
        BridgeMove.doorLoopDoor = door
        BridgeMove.doorLoopUntil = Bridge.time + 900
        log(sformat("door loop guard at %d,%d n=%d", cells[1].x, cells[1].y, use.n))
    end
    local keep = BridgeMove.keepOpenDoors[door] == true
    if not keep and BridgeTask ~= nil and BridgeTask.active and BridgeTask.kind == "openDoors" then
        keep = true
        BridgeMove.keepOpenDoors[door] = true
    end
    if not keep and BridgeTask ~= nil and BridgeTask.active
            and BridgeMove.openingWay ~= nil and BridgeMove.openingWay.obj == door then
        keep = true
    end
    rec.keepOpen = keep
    rec.edge = north and cells[1].y or cells[1].x
    rec.side = DOOR.doorSide(rec, body:getX(), body:getY())

    local sx, sy = 0, 0
    for _, c in ipairs(cells) do sx, sy = sx + c.x + 0.5, sy + c.y + 0.5 end
    rec.cx, rec.cy = sx / #cells, sy / #cells
    if north then rec.cy = rec.edge else rec.cx = rec.edge end
    local list = BridgeMove.opened
    for i = #list, 1, -1 do
        if list[i].door == door then table.remove(list, i) end
    end
    list[#list + 1] = rec
    if #list > 4 then table.remove(list, 1) end
    log(sformat("door opened: %s at %d,%d, %d parts", kind, cells[1].x, cells[1].y, #cells))
end




function BridgeMove.rememberDoorNear(body)
    if body == nil then return end
    local cur = body:getCurrentSquare()
    if cur == nil then return end
    local cell = getCell()
    local cx, cy, cz = cur:getX(), cur:getY(), cur:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
            if sq ~= nil then
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    local object = objects:get(i)
                    if DOOR.isDoor(object) then
                        local open = false
                        pcall(function() open = object:IsOpen() end)
                        if open then
                            local have = false
                            for _, r in ipairs(BridgeMove.opened) do
                                if r.door == object then have = true end
                            end
                            if not have then
                                local adopted = false
                                pcall(function()
                                    local kind = DOOR.doorKind(object)
                                    local cells, north = DOOR.doorCells(object, kind)
                                    local anchor = DOOR.doorAnchor(object, kind)
                                    BridgeMove.rememberDoor(body, anchor, kind, cells, north)
                                    adopted = true
                                end)
                                if adopted then
                                    local dox, doy, ddist = -1, -1, -1
                                    pcall(function()
                                        local dsq = object:getSquare()
                                        if dsq ~= nil then dox, doy = dsq:getX(), dsq:getY() end
                                        local ocx, ocy = BridgeDoors.center(object)
                                        if ocx ~= nil and ocy ~= nil then
                                            ddist = math.sqrt((body:getX() - ocx) ^ 2 + (body:getY() - ocy) ^ 2)
                                        end
                                    end)
                                    log(sformat("door adopt at %d,%d d=%.2f body=%.2f,%.2f", dox, doy, ddist, body:getX(), body:getY()))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end


function DOOR.doorReach(rec, x, y)
    local best = math.huge
    for _, c in ipairs(rec.cells) do
        best = math.min(best, dist2d(x, y, c.x + 0.5, c.y + 0.5), dist2d(x, y, c.ox + 0.5, c.oy + 0.5))
    end
    return best
end








function DOOR.ownNear(rec, body, side, radius)
    local cell = getCell()
    local mark = (Bridge ~= nil and Bridge.BODY_VAR) or "NotAloneBody"
    local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
    for _, c in ipairs(rec.cells) do
        minx, maxx = math.min(minx, c.x, c.ox), math.max(maxx, c.x, c.ox)
        miny, maxy = math.min(miny, c.y, c.oy), math.max(maxy, c.y, c.oy)
    end
    local r = math.ceil(radius)
    local z = rec.cells[1].z
    for x = minx - r, maxx + r do
        for y = miny - r, maxy + r do
            local sq = cell:getGridSquare(x, y, z)
            local who = nil
            if sq ~= nil then
                pcall(function()
                    local list = sq:getMovingObjects()
                    for i = 0, list:size() - 1 do
                        local o = list:get(i)
                        local kind = nil
                        if o ~= body then
                            if instanceof(o, "IsoAnimal") then
                                kind = nil
                            elseif instanceof(o, "IsoPlayer") then
                                if not o:isDead() then kind = "player" end
                            elseif instanceof(o, "IsoZombie") and o:getVariableBoolean(mark) then
                                kind = "companion"
                            end
                        end
                        if kind ~= nil then
                            local ox, oy = o:getX(), o:getY()
                            if (side == nil or DOOR.doorSide(rec, ox, oy) == side) and DOOR.doorReach(rec, ox, oy) <= radius then
                                who = kind
                            end
                        end
                    end
                end)
            end
            if who ~= nil then return who end
        end
    end
    return nil
end



function DOOR.doorwayBusy(rec, body)
    local cell = getCell()
    for _, c in ipairs(rec.cells) do
        for _, xy in ipairs({ { c.x, c.y }, { c.ox, c.oy } }) do
            local sq = cell:getGridSquare(xy[1], xy[2], c.z)
            local busy = false
            if sq ~= nil then
                pcall(function()
                    local list = sq:getMovingObjects()
                    for i = 0, list:size() - 1 do
                        local o = list:get(i)
                        if o ~= body then
                            local _, off = DOOR.doorSide(rec, o:getX(), o:getY())
                            if off < DOOR.EDGE then busy = true end
                        end
                    end
                end)
            end
            if busy then return true end
        end
    end
    return false
end













function DOOR.closeWait(rec, body, passed)
    local red = BridgeData.owner()
    local wait = nil
    if red ~= nil and math.abs(red:getZ() - rec.cells[1].z) < 0.5 then
        local rside = DOOR.doorSide(rec, red:getX(), red:getY())
        local rd = dist2d(red:getX(), red:getY(), rec.cx, rec.cy)
        if passed and rside == rec.side and rd < 4 then
            wait = "player behind"
        elseif not passed and rd < 3 then
            wait = "player at door"
        end
    end
    if wait == nil and passed then
        local gx, gy = nil, nil
        if Bridge.target ~= nil then
            gx, gy = Bridge.target.x, Bridge.target.y
        elseif BridgeMove.goal ~= nil then
            gx, gy = BridgeMove.goal.x, BridgeMove.goal.y
        end
        if gx ~= nil and gy ~= nil then
            local gside = DOOR.doorSide(rec, gx, gy)
            if gside == rec.side then wait = "goal behind" end
        end
    end
    if wait == nil then
        local who = nil
        if passed then
            who = DOOR.ownNear(rec, body, rec.side, OWN_BEHIND)
            if who ~= nil then wait = who .. " behind" end
        else
            who = DOOR.ownNear(rec, body, nil, OWN_AT_DOOR)
            if who ~= nil then wait = who .. " at door" end
        end
    end
    if wait == nil and DOOR.doorwayBusy(rec, body) then wait = "doorway busy" end
    return wait
end

function BridgeMove.closeBehind(body)
    local list = BridgeMove.opened
    if #list == 0 then return end
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    for i = #list, 1, -1 do
        local rec = list[i]
        local why = nil
        local open = false
        pcall(function() open = rec.door:getObjectIndex() ~= -1 and rec.door:IsOpen() end)
        if rec.keepOpen == true and open then
            why = nil
        elseif not open then
            why = "closed by someone else"
        elseif Bridge.time - rec.tick > DOOR.FORGET then
            why = "left open: timeout"
        elseif math.abs(bz - rec.cells[1].z) >= 0.5 then
            why = "left open: other floor"
        elseif DOOR.doorReach(rec, bx, by) > DOOR.REACH then
            why = "left open: walked away"
        else
            local side, off = DOOR.doorSide(rec, bx, by)
            local passed = side ~= rec.side and off >= DOOR.PASSED
            local back = side == rec.side and off >= DOOR.BACK_OFF and (Bridge.time - rec.tick) >= DOOR.BACK
            if (passed or back) and BridgeMove.doorAct == nil and Bridge.time >= (rec.retryAt or 0)
                and not BridgeMove.holdDoors then
                local alone = false
                if passed then
                    local red = BridgeData.owner()
                    if red ~= nil then
                        local rside = DOOR.doorSide(rec, red:getX(), red:getY())
                        local rd = dist2d(red:getX(), red:getY(), rec.cx, rec.cy)
                        if rside == rec.side and rd >= 4 then alone = true end
                    end
                end
                if alone then
                    why = "left open: alone inside"
                else
                    local wait = DOOR.closeWait(rec, body, passed)
                    if wait ~= nil then
                        if wait ~= rec.wait then
                            log("door close waits: " .. wait)
                            if wait == "player behind" or wait == "player at door" then
                                pcall(function() if Bridge ~= nil and type(Bridge.speak) == "function" then Bridge.speak("DoorWaitPlayer") end end)
                            end
                        end
                        rec.wait = wait
                    else

                        BridgeMove.startDoorAct(body, "close", rec.door, rec, rec.cx, rec.cy, passed)
                    end
                end
            end
        end
        if why ~= nil then
            table.remove(list, i)
            if why == "closed by someone else" then BridgeMove.clearKeepOpen(rec.door) end
            local detail = ""
            if why == "left open: walked away" then
                detail = sformat(" d=%.2f limit=%.1f", DOOR.doorReach(rec, bx, by), DOOR.REACH)
            end
            BridgeMove.doorLast = sformat("%s: %s at %d,%d%s", why, rec.kind, rec.cells[1].x, rec.cells[1].y, detail)
            local taskKind = BridgeTask ~= nil and BridgeTask.active and BridgeTask.kind or nil
            log("door " .. BridgeMove.doorLast .. (taskKind ~= nil and (" task=" .. tostring(taskKind)) or ""))
        end
    end
end




function BridgeMove.closeNow(body, rec, passed)
    local list = BridgeMove.opened
    local idx = nil
    for i, r in ipairs(list) do if r == rec then idx = i end end
    if idx == nil then return nil end
    local why = nil
    local open = false
    pcall(function() open = rec.door:getObjectIndex() ~= -1 and rec.door:IsOpen() end)
    if not open then
        why = "closed by someone else"
    else
        local wait = DOOR.closeWait(rec, body, passed)
        if wait ~= nil then
            if wait ~= rec.wait then
                log("door close waits: " .. wait)
                if wait == "player behind" or wait == "player at door" then
                    pcall(function() if Bridge ~= nil and type(Bridge.speak) == "function" then Bridge.speak("DoorWaitPlayer") end end)
                end
            end
            rec.wait = wait
            return wait
        end
        local ok, done = pcall(function()
            if rec.kind == "single" and rec.door:isObstructed() then return false end
            return BridgeMove.toggleDoor(body, rec.door, rec.kind)
        end)
        if ok and done then
            why = passed and "closed behind" or "closed, did not go through"
        else
            why = "left open: " .. (ok and "blocked" or tostring(done))
        end
    end
    table.remove(list, idx)
    BridgeMove.doorLast = sformat("%s: %s at %d,%d", why, rec.kind, rec.cells[1].x, rec.cells[1].y)
    log("door " .. BridgeMove.doorLast)
    return nil
end





function BridgeMove.doorsNear(red, radius, only)
    local cell = getCell()
    local rx, ry, rz = math.floor(red:getX()), math.floor(red:getY()), math.floor(red:getZ())
    local seen, found = {}, {}
    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = cell:getGridSquare(rx + dx, ry + dy, rz)
            if sq ~= nil then
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    local o = objects:get(i)
                    if DOOR.isDoor(o) and not seen[o] then
                        local kind = DOOR.doorKind(o)
                        local parts = DOOR.doorParts(o, kind)
                        local open = 0
                        for _, p in ipairs(parts) do
                            seen[p] = true
                            if p:IsOpen() then open = open + 1 end
                        end
                        local psq = parts[1]:getSquare() or sq
                        local north, gate, locked = false, false, false
                        pcall(function() north = o:getNorth() end)
                        pcall(function() gate = o:isHoppable() end)
                        pcall(function() locked = o:isLocked() or o:isLockedByKey() end)
                        local wanted = only == nil or only == kind or (only == "gate" and gate)
                        if wanted then found[#found + 1] = {
                            d = dist2d(rx, ry, psq:getX(), psq:getY()),
                            text = sformat("%s %d,%d %s %d/%d open%s%s", kind, psq:getX(), psq:getY(),
                                north and "N" or "W", open, #parts, gate and " gate" or "", locked and " locked" or ""),
                        } end
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    local out = {}
    for i = 1, math.min(15, #found) do out[#out + 1] = found[i].text end
    return sformat("doors %d: %s", #found, table.concat(out, "; "))
end



function BridgeMove.doorInfo()
    local list = BridgeMove.opened
    local last = list[#list]
    return sformat("open=%d wait=%s last=%s", #list, last and tostring(last.wait) or "none", BridgeMove.doorLast)
end



function DOOR.usableDoor(object)
    local ok = false
    pcall(function()
        if object:isBarricaded() or object:isObstructed() then return end
        if object:IsOpen() then ok = true return end
        local locked = false
        pcall(function() locked = object:isLocked() or object:isLockedByKey() end)
        ok = not locked
    end)
    return ok
end

function DOOR.buildingOf(square)
    local b = nil
    pcall(function() b = square:getBuilding() end)
    return b
end


function DOOR.edgeSquares(object)
    local sq = object:getSquare()
    local other = nil
    pcall(function()
        local north = object:getNorth()
        other = getCell():getGridSquare(sq:getX() - (north and 0 or 1), sq:getY() - (north and 1 or 0), sq:getZ())
    end)
    return sq, other
end







BridgeMove.doorWay = nil
BridgeMove.noDoorUntil = 0



BridgeMove.openingWay = nil
BridgeMove.openingBlocked = nil
BridgeMove.holdDoors = false
BridgeMove.doorLoopDoor = nil
BridgeMove.doorLoopUntil = 0
BridgeMove.doorUse = setmetatable({}, { __mode = "k" })
BridgeMove.doorFail = nil
BridgeMove.doorFailObj = nil
BridgeMove.doorFailUntil = 0
BridgeMove.badDoors = BridgeMove.badDoors or {}
local BAD_DOOR_TICKS = 90 * 60

function BridgeMove.badDoor(key)
    if key == nil then return false end
    local rec = BridgeMove.badDoors[key]
    if rec == nil then return false end
    if Bridge.time >= (rec.expires or 0) then
        BridgeMove.badDoors[key] = nil
        return false
    end
    return true
end

function DOOR.pruneBadDoors()
    local now = Bridge.time
    for key, rec in pairs(BridgeMove.badDoors) do
        if now >= (rec.expires or 0) then
            BridgeMove.badDoors[key] = nil
        else
            local open = false
            local window = false
            pcall(function() window = rec.obj ~= nil and instanceof(rec.obj, "IsoWindow") end)
            if window then
                pcall(function() open = rec.obj:IsOpen() == true end)
            end
            if open then
                BridgeMove.badDoors[key] = nil
            elseif rec.obj ~= nil and BridgeDoors ~= nil and BridgeDoors.isDoor(rec.obj) then
                local locked = false
                pcall(function() locked = rec.obj:isLocked() == true or rec.obj:isLockedByKey() == true end)
                if locked and BridgeDoors.hasKey(rec.obj, Bridge.body) then
                    BridgeMove.badDoors[key] = nil
                end
            end
        end
    end
end

function DOOR.blacklistDoor(body, object, reason)
    local key = nil
    pcall(function() key = BridgeDoors ~= nil and BridgeDoors.key(object) or nil end)
    if key ~= nil then BridgeMove.badDoors[key] = { expires = Bridge.time + BAD_DOOR_TICKS, obj = object } end
    BridgeMove.doorFailObj = object
    BridgeMove.doorFailUntil = Bridge.time + BAD_DOOR_TICKS
    BridgeMove.doorFail = reason or "locked"
    BridgeMove.openingWay = nil
    log(sformat("opening blacklisted (%s) %s", tostring(BridgeMove.doorFail), tostring(key)))
    local isDoorObj = false
    pcall(function()
        isDoorObj = instanceof(object, "IsoDoor")
            or (instanceof(object, "IsoThumpable") and object:isDoor())
    end)
    if reason ~= "barricade" and isDoorObj then
        pcall(function() if body ~= nil then body:playSound("DoorIsLocked") end end)
    end
end
BridgeMove.blacklistDoor = DOOR.blacklistDoor

function BridgeMove.doorBlocked(object)
    if object == nil then return false end
    local open = false
    pcall(function() open = object:IsOpen() == true end)
    if open then return false end
    local key = nil
    pcall(function() key = BridgeDoors ~= nil and BridgeDoors.key(object) or nil end)
    local fails = BridgeMove.doorFailObj == object and Bridge.time < (BridgeMove.doorFailUntil or 0)
    if not fails and not BridgeMove.badDoor(key) then return false end
    local locked = false
    pcall(function() locked = object:isLocked() == true or object:isLockedByKey() == true end)
    if locked and BridgeDoors ~= nil and BridgeDoors.hasKey(object, Bridge.body) then
        if key ~= nil then BridgeMove.badDoors[key] = nil end
        BridgeMove.doorFailObj = nil
        BridgeMove.doorFailUntil = 0
        BridgeMove.doorFail = nil
        return false
    end
    return true
end

BridgeMove.openWindows = BridgeMove.openWindows or {}
local WINDOW_CLOSE_MS = 900

function BridgeMove.noteWindowOpened(body, object, behind)
    if object == nil then return end
    local tracked = BridgeTask ~= nil and BridgeTask.active
    if not tracked and (Bridge == nil or Bridge.mode ~= "home") then return end
    local x, y, z, fx, fy = nil, nil, nil, nil, nil
    pcall(function()
        local a, b = object:getSquare(), object:getOppositeSquare()
        if a ~= nil then x, y, z = a:getX() + 0.5, a:getY() + 0.5, a:getZ() end
        if b ~= nil then fx, fy = b:getX() + 0.5, b:getY() + 0.5 end
    end)
    if x == nil then return end
    local flag = behind == true or nil
    BridgeMove.openWindows = BridgeMove.openWindows or {}
    for _, rec in ipairs(BridgeMove.openWindows) do
        if rec.obj == object then
            rec.tick = Bridge.time
            rec.behind = flag
            return
        end
    end
    BridgeMove.openWindows[#BridgeMove.openWindows + 1] =
        { obj = object, x = x, y = y, z = z, farX = fx, farY = fy, tick = Bridge.time, behind = flag }
end


function BridgeMove.beginWindow(body, obj, opening)
    if body == nil or obj == nil then return end
    local bump = opening and "WindowOpen" or "WindowClose"
    local sound = opening and "OpenWindow" or "CloseWindow"
    pcall(function() body:setVariable("BumpAnimFinished", false) end)
    pcall(function() if body:getBumpType() ~= bump then body:setBumpType(bump) end end)
    pcall(function() body:playSound(sound) end)
end


function BridgeMove.toggleWindow(body, obj)
    if obj == nil then return false end
    local wasOpen = false
    pcall(function() wasOpen = obj:IsOpen() == true end)
    pcall(function() obj:ToggleWindow(body) end)
    local nowOpen = wasOpen
    pcall(function() nowOpen = obj:IsOpen() == true end)
    return nowOpen ~= wasOpen
end


function BridgeMove.toggleCurtain(body, curtain)
    if curtain == nil or BridgeDoors == nil then return false end
    local wasOpen = BridgeDoors.curtainOpen(curtain)
    if wasOpen == nil then return false end
    pcall(function() curtain:ToggleDoor(body) end)
    local nowOpen = BridgeDoors.curtainOpen(curtain)
    if nowOpen == wasOpen and type(curtain.ToggleDoorSilent) == "function" then
        pcall(function() curtain:ToggleDoorSilent() end)
        pcall(function() curtain:sendObjectChange(IsoObjectChange.STATE) end)
        pcall(function() syncIsoObject(false, 1, nil, nil) end)
        nowOpen = BridgeDoors.curtainOpen(curtain)
    end
    if nowOpen ~= wasOpen then log("curtain toggle was=" .. tostring(wasOpen) .. " now=" .. tostring(nowOpen)) end
    return nowOpen ~= wasOpen
end


function BridgeMove.closeWindows(body)
    local list = BridgeMove.openWindows
    if list == nil or #list == 0 then return end
    if body == nil then return end
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    for i = #list, 1, -1 do
        local rec = list[i]
        local obj = rec.obj
        local done = false
        if obj == nil then
            done = true
        else
            local ok, open, smashed = true, false, false
            pcall(function()
                ok = obj:getObjectIndex() ~= -1
                open = obj:IsOpen() == true
                smashed = obj:isSmashed() == true
            end)
            if not ok or not open or smashed then
                done = true
            elseif BridgeMove.pendingClimb == nil and math.abs(bz - rec.z) < 0.5 and not BridgeMove.holdDoors then
                local near = dist2d(bx, by, rec.x, rec.y)
                local far = rec.farX ~= nil and dist2d(bx, by, rec.farX, rec.farY) <= 1.0
                local goalAway = true
                if Bridge.target ~= nil and rec.farX ~= nil then
                    local gx, gy = Bridge.target.x, Bridge.target.y
                    goalAway = dist2d(gx, gy, rec.farX, rec.farY) <= dist2d(gx, gy, rec.x, rec.y)
                end
                if goalAway and (far or near > 1.6) then
                    if rec.closingAt == nil then
                        rec.closingAt = Bridge.time
                        BridgeMove.beginWindow(body, obj, false)
                        local taskKind = BridgeTask ~= nil and BridgeTask.active and BridgeTask.kind or nil
                        local cur = BridgeTask ~= nil and BridgeTask.current or nil
                        local curText = cur ~= nil and string.format("%d,%d,%d", cur.x, cur.y, cur.z) or "-"
                        local pathObj = BridgeMove.openingWay ~= nil and BridgeMove.openingWay.obj or nil
                        log(string.format("window closing behind at %d,%d task=%s target=%s path=%s behind=%s",
                            rec.x, rec.y, tostring(taskKind), curText, tostring(pathObj ~= nil and pathObj == obj),
                            tostring(rec.behind)))
                    elseif Bridge.time - rec.closingAt >= 20 then
                        BridgeMove.toggleWindow(body, obj)
                        log("window closed behind")
                        done = true
                    end
                end
            end
        end
        if done then table.remove(list, i) end
    end
end






BridgeMove.pendingClimb = nil

local function cardinal(body)
    local a = body:getDirectionAngle()
    if a >= -45 and a < 45 then return IsoDirections.E end
    if a >= 45 and a < 135 then return IsoDirections.S end
    if a >= -135 and a < -45 then return IsoDirections.N end
    return IsoDirections.W
end

function BridgeMove.askClimb(body, kind, object)
    local goal = BridgeMove.goal
    if goal == nil and Bridge ~= nil and Bridge.follow == true then
        local red = BridgeData.owner()
        if red ~= nil then goal = { x = red:getX(), y = red:getY() } end
    end
    if kind == "fence" and goal ~= nil and goal.x ~= nil and goal.y ~= nil and object ~= nil then
        local cur, sq = nil, nil
        pcall(function() cur = body:getCurrentSquare() end)
        pcall(function() sq = object:getSquare() end)
        if cur ~= nil and sq ~= nil
                and not BridgeMove.beyondEdge(cur, sq, goal.x, goal.y, 0) then
            return false
        end
    end
    BridgeMove.pendingClimb = { kind = kind, object = object, tick = Bridge.time, asked = -9999 }
    if kind == "fence" then
        pcall(function()
            local cur, sq = nil, nil
            cur = body:getCurrentSquare()
            sq = object ~= nil and object:getSquare() or nil
            if cur ~= nil and sq ~= nil and BridgeMove.stepDir ~= nil then
                BridgeMove.pendingClimb.dir = BridgeMove.stepDir(cur, sq)
            else
                BridgeMove.pendingClimb.dir = cardinal(body)
            end
        end)
    end
    BridgeMove.climbUntil = Bridge.time + 60
    return true
end


local function stopReloadForTraversal(body, why)
    if BridgeGunfight ~= nil and type(BridgeGunfight.interruptReload) == "function" then
        pcall(BridgeGunfight.interruptReload, body, why or "traversal")
    end
end

local function clearClimbHands(body)
    if not isClient() then return true end
    if body:getPrimaryHandItem() == nil and body:getSecondaryHandItem() == nil then
        return true
    end

    pcall(function() BridgeWeapon.putAway(body) end)

    if body:getPrimaryHandItem() ~= nil or body:getSecondaryHandItem() ~= nil then
        pcall(function()
            body:setPrimaryHandItem(nil)
            body:setSecondaryHandItem(nil)
            body:resetEquippedHandsModels()
        end)
    end

    return body:getPrimaryHandItem() == nil and body:getSecondaryHandItem() == nil
end

function BridgeMove.climbStep(body)
    local c = BridgeMove.pendingClimb
    if c == nil then return false end
    stopReloadForTraversal(body, "climb")
    local asn = ""
    pcall(function() asn = tostring(body:getActionStateName()) end)
    if asn == "climbwindow" or asn == "climbfence" then
        if asn == "climbwindow" and c.kind == "window" and c.object ~= nil
                and BridgeTask ~= nil and BridgeTask.active and BridgeTask.kind == "closeWindows" then
            pcall(function() BridgeMove.noteWindowOpened(body, c.object, true) end)
        end
        BridgeMove.pendingClimb = nil
        BridgeMove.climbUntil = Bridge.time + 150
        return true
    end
    if Bridge.time - c.tick > 45 then
        BridgeMove.pendingClimb = nil
        BridgeMove.climbUntil = 0
        BridgeMove.obstacle = "climb not started: " .. asn
        return false
    end
    if asn == "idle" or asn == "pathfind" then


        if not clearClimbHands(body) then
            BridgeMove.pendingClimb = nil
            BridgeMove.climbUntil = 0
            BridgeMove.obstacle = "climb skipped: item in hands"
            return false
        end
        if Bridge.time - c.asked >= 5 then
            c.asked = Bridge.time
            local ok, err = pcall(function()
                if c.kind == "window" then
                    body:climbThroughWindow(c.object)
                elseif c.kind == "frame" then
                    body:climbThroughWindowFrame(c.object)
                else
                    body:climbOverFence(c.dir)
                end
            end)
            if not ok then
                BridgeMove.pendingClimb = nil
                BridgeMove.climbUntil = 0
                BridgeMove.obstacle = "climb failed: " .. tostring(err)
                return false
            end
        end
        return true
    end

    if BridgeMove.onPath() then BridgeMove.stopPath(body) end
    pcall(function()
        if asn == "bumped" then body:setVariable("BumpAnimFinished", true) end
        body:setBumpType("")
    end)
    return true
end

















BridgeMove.cross = nil
BridgeMove.noCrossUntil = 0
BridgeMove.crossInfo = "none"

CROSS.LOOK = 0.9
CROSS.CALL = 0.55
CROSS.WAIT = 90
local TALL_GRAB_MS = 640
local TALL_OVER_MS = 1830

local function nowMs()
    local ms = nil
    pcall(function() ms = getTimestampMs() end)
    return ms or (Bridge.time * 1000 / 60)
end

local function sameSquare(a, b)
    return a ~= nil and b ~= nil and a:getX() == b:getX() and a:getY() == b:getY() and a:getZ() == b:getZ()
end

local function stepDir(a, b)
    if b:getX() > a:getX() then return IsoDirections.E end
    if b:getX() < a:getX() then return IsoDirections.W end
    if b:getY() > a:getY() then return IsoDirections.S end
    return IsoDirections.N
end
BridgeMove.stepDir = stepDir


local function edgeDist(body, a, b)
    local x, y = body:getX(), body:getY()
    if b:getX() > a:getX() then return (a:getX() + 1) - x end
    if b:getX() < a:getX() then return x - a:getX() end
    if b:getY() > a:getY() then return (a:getY() + 1) - y end
    return y - a:getY()
end


local function beyondEdge(a, b, x, y, margin)
    if x == nil or y == nil then return false end
    local m = margin or 0
    if b:getX() > a:getX() then return x >= a:getX() + 1 + m end
    if b:getX() < a:getX() then return x < a:getX() - m end
    if b:getY() > a:getY() then return y >= a:getY() + 1 + m end
    return y < a:getY() - m
end
BridgeMove.beyondEdge = beyondEdge




CROSS.MARGIN = 0.3









local BACK_BLOCK = 120
local BACK_SPAN = 2
BridgeMove.lastCross = nil



local function lineOf(from, to)
    if from:getX() ~= to:getX() then
        return "x", math.max(from:getX(), to:getX()), from:getY(), (to:getX() > from:getX()) and 1 or -1
    end
    return "y", math.max(from:getY(), to:getY()), from:getX(), (to:getY() > from:getY()) and 1 or -1
end



local function sideOf(axis, edge, x, y, margin)
    local v = (axis == "x") and x or y
    if v >= edge + margin then return 1 end
    if v < edge - margin then return -1 end
    return 0
end



local function backBlocked(from, to)
    local lc = BridgeMove.lastCross
    if lc == nil or Bridge.time - lc.tick >= BACK_BLOCK then return nil end
    local axis, edge, along, dir = lineOf(from, to)
    if axis ~= lc.axis or edge ~= lc.edge or dir ~= -lc.dir or math.abs(along - lc.along) > BACK_SPAN then return nil end
    local red = BridgeData.owner()
    local now = 0
    if red ~= nil then now = sideOf(axis, edge, red:getX(), red:getY(), CROSS.MARGIN) end
    if lc.redSide == lc.dir and now == dir then return nil end
    return sformat("crossed here %d ticks ago, player side %d then, %d now", Bridge.time - lc.tick, lc.redSide, now)
end
BridgeMove.backBlocked = backBlocked






function BridgeMove.edgeBetween(body, a, b)
    if a == nil or b == nil or a:getZ() ~= b:getZ() then return nil end
    local w = nil
    pcall(function() w = a:getWindowTo(b) end)
    if w ~= nil then
        local ok = false
        pcall(function() ok = not w:isBarricaded() and (w:IsOpen() or w:isSmashed()) and w:canClimbThrough(body) end)
        if ok then return "window", w end
        return nil
    end
    local f = nil
    pcall(function() f = a:getWindowFrameTo(b) end)
    if f ~= nil then
        local ok = false
        pcall(function() ok = f:canClimbThrough(body) end)
        if ok then return "frame", f end
        return nil
    end


    local door = nil
    pcall(function() door = a:getDoorTo(b) end)
    if door ~= nil then
        local barricaded = false
        pcall(function() barricaded = door:isBarricaded() end)
        if not barricaded then return nil end
    end
    local low = false
    pcall(function() low = a:isHoppableTo(b) end)
    if low then return "fence", nil end

    local owner, north
    if a:getX() ~= b:getX() then
        owner, north = (a:getX() > b:getX()) and a or b, false
    else
        owner, north = (a:getY() > b:getY()) and a or b, true
    end
    local tall = nil
    pcall(function()
        local objects = owner:getObjects()
        for i = 0, objects:size() - 1 do
            local o = objects:get(i)
            if o ~= nil and o:isTallHoppable() then
                local props = o:getProperties()
                local n = props:has(IsoFlagType.TallHoppableN)
                local wf = props:has(IsoFlagType.TallHoppableW)
                if (north and n) or (not north and wf) then tall = o break end
            end
        end
    end)
    if tall ~= nil then return "tall", tall end
    return nil
end



local function farSideJoined(body, to, sb)
    local dx, dy = sb:getX() - to:getX(), sb:getY() - to:getY()
    if (dx ~= 0 and dy ~= 0) or sb:getZ() ~= to:getZ() then return false end
    local ux = (dx > 0 and 1) or (dx < 0 and -1) or 0
    local uy = (dy > 0 and 1) or (dy < 0 and -1) or 0
    local cell = getCell()
    local prev = to
    for k = 1, math.abs(dx) + math.abs(dy) do
        local nxt = cell:getGridSquare(to:getX() + ux * k, to:getY() + uy * k, to:getZ())
        if nxt == nil then return false end
        local open = false
        pcall(function() open = not prev:isBlockedTo(nxt) and BridgeMove.edgeBetween(body, prev, nxt) == nil end)
        if not open then return false end
        prev = nxt
    end
    return true
end













function BridgeMove.trailCrosses(body, from, to)
    local t = BridgeMove.trail
    local fx, fy, tx, ty = from:getX(), from:getY(), to:getX(), to:getY()
    local z = from:getZ()
    local byY = (fx == tx)
    local edge = byY and math.max(fy, ty) or math.max(fx, tx)
    local toSide = byY and ((ty > fy) and 1 or -1) or ((tx > fx) and 1 or -1)
    local along = byY and fx or fy
    local cell = getCell()
    for i = #t, math.max(2, #t - 40), -1 do
        local a, b = t[i - 1], t[i]
        local av, bv = byY and a.y or a.x, byY and b.y or b.x
        local aSide = (av < edge) and -1 or 1
        local bSide = (bv < edge) and -1 or 1
        if aSide ~= toSide and bSide == toSide and bv ~= av then
            local k = (edge - av) / (bv - av)
            local c = math.floor(byY and (a.x + (b.x - a.x) * k) or (a.y + (b.y - a.y) * k))
            local off = math.abs(c - along)
            if off <= 8 then
                local sa, sb
                if byY then
                    sa, sb = cell:getGridSquare(c, fy, z), cell:getGridSquare(c, ty, z)
                else
                    sa, sb = cell:getGridSquare(fx, c, z), cell:getGridSquare(tx, c, z)
                end
                local over = false
                pcall(function() over = sa ~= nil and sb ~= nil and BridgeMove.edgeBetween(body, sa, sb) ~= nil end)
                if not over then
                    if off == 0 then return false, "player went through a passage here" end
                    return false, sformat("player went through a passage %d away", off)
                end
                if off == 0 then return true, "player crossed here" end
                if farSideJoined(body, to, sb) then return true, sformat("player climbed %d away", off) end
                return false, sformat("player climbed %d away, other side not joined", off)
            end
        end
    end
    return false, "player did not cross near"
end





BridgeMove.passWhy = ""
function BridgeMove.passNear(body, from, to, radius)
    local cell = getCell()
    local z = from:getZ()
    local ux, uy = 0, 0
    if from:getX() == to:getX() then ux = 1 else uy = 1 end
    local why = {}
    for _, dir in ipairs({ 1, -1 }) do
        local prev = from
        local stop = "radius"
        for k = 1, radius do
            local a = cell:getGridSquare(from:getX() + ux * dir * k, from:getY() + uy * dir * k, z)
            local b = cell:getGridSquare(to:getX() + ux * dir * k, to:getY() + uy * dir * k, z)
            if a == nil or b == nil then stop = "no square at " .. k break end
            local walk, how = false, "?"
            pcall(function()
                if prev:isBlockedTo(a) then how = "wall"
                elseif BridgeMove.edgeBetween(body, prev, a) ~= nil then how = "fence"
                elseif not a:isFree(false) then how = "busy"
                else walk = true end
            end)
            if not walk then stop = how .. " at " .. k break end
            local pass = false
            pcall(function()
                local door = a:getDoorTo(b)
                if door ~= nil then
                    pass = DOOR.usableDoor(door)
                else
                    pass = not a:isBlockedTo(b) and BridgeMove.edgeBetween(body, a, b) == nil and b:isFree(false)
                end
            end)
            if pass then return a, b end
            prev = a
        end
        why[#why + 1] = (dir == 1 and "+" or "-") .. stop
    end
    BridgeMove.passWhy = table.concat(why, " ")
    return nil
end








local CLIMB_SEC = { tall = 2.6, fence = 2.0, window = 2.0, frame = 2.0 }
local function climbCost(kind)
    local speed = (BridgeMove.walkType == "Run") and 4.2 or 2.2
    return (CLIMB_SEC[kind] or 1.5) * speed
end




local function squareFloor(sq)
    if sq == nil then return nil end
    local known = nil
    pcall(function() known = sq:TreatAsSolidFloor() end)
    if known == nil then pcall(function() known = sq:hasFloor() end) end
    return known
end


function BridgeMove.vaultSafe(body, from, to)
    if from == nil or to == nil then return true end
    local offStairs = false
    pcall(function()
        if from.HasStairs ~= nil and from:HasStairs() and to.isSameStaircase ~= nil then
            offStairs = not from:isSameStaircase(to:getX(), to:getY(), to:getZ())
        end
    end)
    if offStairs then return false, "vaults off the staircase" end
    if math.floor(from:getZ()) <= 0 then return true end
    if squareFloor(to) ~= true then return false, "far side is open air" end
    return true
end
















BridgeMove.gapWay = nil
BridgeMove.noGapUntil = 0
BridgeMove.passFirst = 0
BridgeMove.passCount = 0




local function edgeAhead(body)
    local cur = body:getCurrentSquare()
    if cur == nil then return nil end
    local x, y = body:getX(), body:getY()
    local dx, dy = 0, 0
    local prev = BridgeMove.stepPos
    if prev ~= nil then dx, dy = x - prev.x, y - prev.y end
    if dx * dx + dy * dy < 0.00005 and BridgeMove.goal ~= nil then
        dx, dy = BridgeMove.goal.x - x, BridgeMove.goal.y - y
    end
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.0001 then return nil end
    dx, dy = dx / len, dy / len
    local cell = getCell()
    for _, s in ipairs({ 0.35, 0.65, CROSS.LOOK }) do
        local nx, ny = math.floor(x + dx * s), math.floor(y + dy * s)
        if nx ~= cur:getX() or ny ~= cur:getY() then
            local candidates = {}
            if nx ~= cur:getX() and ny ~= cur:getY() then
                candidates = { cell:getGridSquare(nx, cur:getY(), cur:getZ()), cell:getGridSquare(cur:getX(), ny, cur:getZ()) }
            else
                candidates = { cell:getGridSquare(nx, ny, cur:getZ()) }
            end
            for _, b in ipairs(candidates) do
                if b ~= nil then
                    local kind, object = BridgeMove.edgeBetween(body, cur, b)
                    if kind ~= nil then return kind, object, cur, b end
                end
            end
            return nil
        end
    end
    return nil
end

function BridgeMove.edgeOnLine(body, x, y, z, maxTiles)
    local out = nil
    pcall(function()
        local bz = math.floor(body:getZ())
        if math.floor(z or bz) ~= bz then return end
        local cell = getCell()
        local bx, by = body:getX(), body:getY()
        local d = dist2d(bx, by, x, y)
        if d < 0.25 then return end
        local cap = math.min(d, maxTiles or 6)
        local steps = math.max(1, math.ceil(cap / 0.4))
        local prev = cell:getGridSquare(math.floor(bx), math.floor(by), bz)
        if prev == nil then return end
        for i = 1, steps do
            local t = i / steps
            local sx, sy = math.floor(bx + (x - bx) * t), math.floor(by + (y - by) * t)
            if sx ~= prev:getX() or sy ~= prev:getY() then
                local sq = cell:getGridSquare(sx, sy, bz)
                if sq == nil then return end
                local kind, object = BridgeMove.edgeBetween(body, prev, sq)
                if kind ~= nil then
                    out = { kind = kind, object = object, from = prev, to = sq }
                    return
                end
                prev = sq
            end
        end
    end)
    if out == nil then return nil end
    return out.kind, out.object, out.from, out.to
end

local function crossEnd(body, why)
    BridgeMove.setCollide(body, true)
    local c = BridgeMove.cross
    BridgeMove.cross = nil
    BridgeMove.crossInfo = tostring(why)
    BridgeMove.forceCross = false
    pcall(function() body:setVariable("bPathfind", false) end)
    if c ~= nil and c.kind == "tall" then
        pcall(function()
            local bump = body:getBumpType()
            if bump == "ClimbFenceTall" or bump == "ClimbFenceTallStart" then

                BridgeMove.releaseBump(body)
            end
        end)
    end


    BridgeMove.pathing = false
    BridgeMove.goal = nil
    BridgeMove.climbUntil = Bridge.time + 20
    BridgeMove.unPathfindUntil = Bridge.time + 30
    if why == "done" then



        BridgeMove.noCrossUntil = 0
        if c ~= nil and c.from ~= nil and c.to ~= nil then
            local axis, edge, along, dir = lineOf(c.from, c.to)
            local redSide = c.redSide
            if redSide == nil then
                local red = BridgeData.owner()
                redSide = red ~= nil and sideOf(axis, edge, red:getX(), red:getY(), CROSS.MARGIN) or 0
            end
            BridgeMove.lastCross = { axis = axis, edge = edge, along = along, dir = dir, tick = Bridge.time, redSide = redSide }
            local ckey = c.from:getX() .. "," .. c.from:getY() .. ">" .. c.to:getX() .. "," .. c.to:getY()
            BridgeMove.crossLoops = BridgeMove.crossLoops or {}
            local rec = BridgeMove.crossLoops[ckey]
            if rec == nil or Bridge.time - rec.first > 400 then
                rec = { first = Bridge.time, n = 0 }
                BridgeMove.crossLoops[ckey] = rec
            end
            rec.n = rec.n + 1
            if rec.n >= 2 then
                if c.object ~= nil then pcall(function() DOOR.blacklistDoor(body, c.object, "looped") end) end
                BridgeMove.noCrossUntil = Bridge.time + 120
                log("edge looped, blacklisted: " .. ckey)
            end
        end
    elseif why == "left the edge" then


        BridgeMove.noCrossUntil = Bridge.time + 20
    else
        BridgeMove.noCrossUntil = Bridge.time + ((why == "goal on this side") and 20 or 90)
    end
    log("cross " .. tostring(c and c.kind) .. " ended: " .. tostring(why))
end
BridgeMove.crossEnd = crossEnd

function BridgeMove.noteCrossLoop(body, from, to, tag)
    if from == nil or to == nil then return false end

    local a, b = from:getX() .. "," .. from:getY(), to:getX() .. "," .. to:getY()
    if a > b then a, b = b, a end
    local ckey = "fight:" .. a .. "|" .. b

    BridgeMove.crossLoops = BridgeMove.crossLoops or {}
    local rec = BridgeMove.crossLoops[ckey]
    if rec == nil or Bridge.time - rec.first > 400 then
        rec = { first = Bridge.time, n = 0, last = -9999 }
        BridgeMove.crossLoops[ckey] = rec
    end
    if Bridge.time - (rec.last or -9999) < 60 then return false end
    rec.last = Bridge.time
    rec.n = rec.n + 1
    if rec.n >= 2 then
        BridgeMove.noCrossUntil = Bridge.time + 120
        log(string.format("edge looped (%s), blacklisted: %s", tostring(tag or "?"), ckey))
        return true
    end
    return false
end






local function shiftCross(body, c, cur)
    if cur == nil or c.from == nil or c.to == nil or cur:getZ() ~= c.from:getZ() then return false end
    local dx, dy = c.to:getX() - c.from:getX(), c.to:getY() - c.from:getY()
    local sx, sy = cur:getX() - c.from:getX(), cur:getY() - c.from:getY()
    if dx ~= 0 then
        if sx ~= 0 or math.abs(sy) ~= 1 then return false end
    elseif sy ~= 0 or math.abs(sx) ~= 1 then
        return false
    end
    local to = getCell():getGridSquare(cur:getX() + dx, cur:getY() + dy, cur:getZ())
    if to == nil then return false end
    local kind, object = BridgeMove.edgeBetween(body, cur, to)
    if kind == nil or (kind == "tall") ~= (c.kind == "tall") then return false end
    if not BridgeMove.vaultSafe(body, cur, to) then return false end
    if not farSideJoined(body, c.to, to) then return false end
    log(sformat("cross %s shifted: from %d,%d to %d,%d", kind, cur:getX(), cur:getY(), to:getX(), to:getY()))
    c.from, c.to, c.kind, c.object = cur, to, kind, object
    pcall(function() c.dir = stepDir(cur, to) end)
    return true
end
BridgeMove.shiftCross = shiftCross

local function inPathFindState(body)
    local yes = false
    pcall(function() yes = body:isCurrentState(PathFindState.instance()) end)
    if yes then return true end
    local s = ""
    pcall(function() s = tostring(body:getCurrentState()) end)
    return string.find(s, "PathFindState", 1, true) ~= nil
end


function BridgeMove.crossStep(body)
    if BridgeMove.noClimb then return false end
    local c = BridgeMove.cross

    if c ~= nil and not c.started and Bridge.time - (c.lastFrame or c.tick) > 10 then
        crossEnd(body, "stale")
        c = nil
    end
    if c == nil then



        if not (BridgeMove.pathing or BridgeMove.steering or (BridgeTask ~= nil and BridgeTask.active)) then
            BridgeMove.edgeSeen = nil
            return false
        end
        local kind, object, from, to = edgeAhead(body)
        if kind == nil then
            BridgeMove.edgeSeen = nil
            return false
        end
        local key = kind .. from:getX() .. "," .. from:getY() .. ">" .. to:getX() .. "," .. to:getY()


        local seen = BridgeMove.edgeSeen
        if seen == nil or seen.key ~= key or Bridge.time - seen.last > 10 then
            seen = { key = key, first = Bridge.time }
            BridgeMove.edgeSeen = seen
        end
        seen.last = Bridge.time
        if Bridge.time < BridgeMove.noCrossUntil then
            if BridgeMove.edgeLogged ~= "wait" .. key then
                BridgeMove.edgeLogged = "wait" .. key
                log(sformat("edge %s ahead, not climbing %d ticks more after: %s", kind,
                    BridgeMove.noCrossUntil - Bridge.time, tostring(BridgeMove.crossInfo)))
            end
            return false
        end


        local goal = BridgeMove.goal
        if goal == nil or not beyondEdge(from, to, goal.x, goal.y, CROSS.MARGIN) then
            if BridgeMove.edgeLogged ~= key then
                BridgeMove.edgeLogged = key
                log("edge " .. kind .. " ahead, goal on this side")
            end
            return false
        end

        local back = backBlocked(from, to)
        if back ~= nil then
            if BridgeMove.edgeLogged ~= "back" .. key then
                BridgeMove.edgeLogged = "back" .. key
                log("edge " .. kind .. " ahead, not climbing back: " .. back)
            end
            return false
        end

        local go, why, pa, pb = BridgeRoute.shouldCross(body, kind, from, to)
        if not go then
            if pa ~= nil and BridgeMove.gapWay == nil and Bridge.time >= BridgeMove.noGapUntil then
                BridgeRoute.setGapWay(pa, pb)
            end

            local key = (string.match(why, "^[%a ]+") or why) .. kind .. from:getX() .. "," .. from:getY() .. ">" .. to:getX() .. "," .. to:getY()
            if BridgeMove.edgeLogged ~= key then
                BridgeMove.edgeLogged = key
                log("edge " .. kind .. " ahead, not climbing: " .. why)
            end
            return false
        end
        local red0 = BridgeData.owner()
        log(sformat("cross %s start: from %d,%d to %d,%d (%s, %s) player=%.1f,%.1f goal=%.1f,%.1f seen=%d", kind,
            from:getX(), from:getY(), to:getX(), to:getY(), BridgeMove.steering and "trail" or "path", tostring(why),
            red0 and red0:getX() or 0, red0 and red0:getY() or 0, goal.x, goal.y, Bridge.time - seen.first))
        c = { kind = kind, object = object, from = from, to = to, tick = Bridge.time, started = false }
        pcall(function() c.dir = stepDir(from, to) end)



        if red0 ~= nil then
            local axis, edge = lineOf(from, to)
            c.redSide = sideOf(axis, edge, red0:getX(), red0:getY(), CROSS.MARGIN)
        end
        BridgeMove.cross = c
        BridgeMove.crossInfo = "cross " .. kind
        Bridge.holdPos = nil
        pcall(function() body:setBumpType("") end)
        if kind == "tall" then
            c.waitEdge = true

        else
            pcall(function()
                body:setVariable("bPathfind", true)
                body:setVariable("bMoving", false)
            end)
        end
    end
    stopReloadForTraversal(body, "climb")
    c.lastFrame = Bridge.time
    BridgeMove.climbUntil = Bridge.time + 30
    local asn = ""
    pcall(function() asn = tostring(body:getActionStateName()) end)

    if c.kind == "tall" then
        if c.waitEdge then


            if BridgeMove.steering then
                local dist = edgeDist(body, c.from, c.to)
                if dist > 1.6 then crossEnd(body, "left the edge") return false end
                if dist > 0.45 then
                    local ex = c.from:getX() + 0.5 + (c.to:getX() - c.from:getX()) * 0.5
                    local ey = c.from:getY() + 0.5 + (c.to:getY() - c.from:getY()) * 0.5


                    BridgeMove.setCollide(body, false)
                    BridgeMove.walkType = "Walk"
                    BridgeMove.followWs = 0.4
                    BridgeMove.applyAnimVars(body)
                    BridgeMove.followBump(body, "Walk")
                    BridgeMove.turnToward(body, ex, ey, 180)
                    if Bridge.time - c.tick > CROSS.WAIT then crossEnd(body, "tall fence not reached") return false end
                    return true
                end
                BridgeMove.steering = false
                BridgeMove.endFollowBump(body, "")
                BridgeMove.setCollide(body, true)



                local curT = body:getCurrentSquare()
                if not sameSquare(curT, c.from) and not sameSquare(curT, c.to) and not shiftCross(body, c, curT) then
                    crossEnd(body, "left the edge") return false
                end
            elseif not sameSquare(body:getCurrentSquare(), c.from) and not shiftCross(body, c, body:getCurrentSquare()) then
                crossEnd(body, "left the edge") return false
            end
            if edgeDist(body, c.from, c.to) > (((BridgeTask ~= nil and BridgeTask.active) or BridgeMove.forceCross) and 1.5 or 0.45) then
                if Bridge.time - c.tick > CROSS.WAIT then crossEnd(body, "tall fence not reached") return false end
                return false
            end
            BridgeMove.steering = false
            c.waitEdge = false
            c.t0 = nowMs()
            local x, y = body:getX(), body:getY()
            local tx, ty = x, y
            if c.to:getX() > c.from:getX() then tx = c.to:getX() + 0.45
            elseif c.to:getX() < c.from:getX() then tx = c.to:getX() + 0.55
            elseif c.to:getY() > c.from:getY() then ty = c.to:getY() + 0.45
            else ty = c.to:getY() + 0.55 end
            c.x0, c.y0, c.x1, c.y1 = x, y, tx, ty
            if BridgeMove.onPath() then BridgeMove.stopPath(body) end
            pcall(function()
                body:setDir(c.dir)
                body:setVariable("BumpAnimFinished", false)
                body:setBumpType("ClimbFenceTallStart")
            end)

            pcall(function() BridgeSound.fence(body, "ClimbOverFenceHighStart", true) end)
            pcall(function() BridgeSound.voice(body, "JumpHigh", 30) end)
            c.phase = "grab"
            log("cross tall fence")
        end


        pcall(function() body:setCollidable(false) end)
        local elapsed = nowMs() - c.t0
        if c.phase == "grab" then

            local g = math.min(1, elapsed / TALL_GRAB_MS)
            pcall(function()
                local nx, ny = c.x0 + (c.x1 - c.x0) * 0.12 * g, c.y0 + (c.y1 - c.y0) * 0.12 * g
                body:setX(nx) body:setY(ny) body:setLastX(nx) body:setLastY(ny)
            end)
            if elapsed < TALL_GRAB_MS then return true end
            c.phase = "over"
            pcall(function() body:setBumpType("ClimbFenceTall") end)
            pcall(function() BridgeSound.fence(body, "ClimbOverFenceHighSuccess", true) end)
        end
        local t = math.min(1, (elapsed - TALL_GRAB_MS) / TALL_OVER_MS)
        local k = 0.12 + 0.88 * (t * t * (3 - 2 * t))
        pcall(function()
            local nx, ny = c.x0 + (c.x1 - c.x0) * k, c.y0 + (c.y1 - c.y0) * k
            body:setX(nx) body:setY(ny) body:setLastX(nx) body:setLastY(ny)
        end)
        if t >= 1 then crossEnd(body, "done") end
        return true
    end

    if c.started then

        crossEnd(body, "done")
        return true
    end
    if Bridge.time - c.tick > CROSS.WAIT then
        crossEnd(body, "not started in " .. asn)
        return true
    end
    local goal = BridgeMove.goal
    if goal ~= nil and not beyondEdge(c.from, c.to, goal.x, goal.y) then
        crossEnd(body, "goal on this side")
        return true
    end



    if BridgeMove.steering and c.kind ~= "tall" then
        local cur0 = body:getCurrentSquare()
        if not sameSquare(cur0, c.from) then
            if sameSquare(cur0, c.to) then crossEnd(body, "done") return true end
            if not shiftCross(body, c, cur0) then crossEnd(body, "left the edge") return true end
        end
        local ex = c.from:getX() + 0.5 + (c.to:getX() - c.from:getX()) * 0.5
        local ey = c.from:getY() + 0.5 + (c.to:getY() - c.from:getY()) * 0.5
        BridgeMove.walkType = "Walk"
        BridgeMove.followWs = 0.4
        BridgeMove.applyAnimVars(body)
        BridgeMove.followBump(body, "Walk")
        BridgeMove.turnToward(body, ex, ey, 180)
        if edgeDist(body, c.from, c.to) <= CROSS.CALL and Bridge.time - (c.asked or -99) >= 3 then
            c.asked = Bridge.time
            BridgeMove.steering = false
            BridgeMove.endFollowBump(body, "")
            BridgeMove.setCollide(body, true)




            if not clearClimbHands(body) then
                crossEnd(body, "item in hands")
                return true
            end
            if c.kind == "window" and not BridgeMove.glassStep(body, c.object) then
                crossEnd(body, "glass first")
                return true
            end
            local ok, err = pcall(function()
                if c.kind == "fence" then
                    body:climbOverFence(c.dir)
                elseif c.kind == "window" then
                    body:faceThisObject(c.object)
                    body:climbThroughWindow(c.object)
                else
                    body:faceThisObject(c.object)
                    body:climbThroughWindowFrame(c.object)
                end
            end)
            if not ok then crossEnd(body, "climb error: " .. tostring(err)) end
        end
        return true
    end
    if asn == "bumped" then
        pcall(function() body:setBumpType("") body:setVariable("BumpAnimFinished", true) end)



        BridgeMove.kickAt = nil
        return true
    end
    pcall(function()
        body:setVariable("bPathfind", true)
        if asn == "walktoward" then body:setVariable("bMoving", false) end
    end)
    if asn ~= "pathfind" then return true end

    if not inPathFindState(body) then
        pcall(function() body:getPathFindBehavior2():update() end)
    end
    local cur = body:getCurrentSquare()
    if not sameSquare(cur, c.from) then

        if sameSquare(cur, c.to) then crossEnd(body, "done") return true end
        if not shiftCross(body, c, cur) then crossEnd(body, "left the edge") return true end
    end


    if c.kind ~= "fence" and not clearClimbHands(body) then
        crossEnd(body, "item in hands")
        return true
    end
    if edgeDist(body, c.from, c.to) <= CROSS.CALL and Bridge.time - (c.asked or -99) >= 3 then
        c.asked = Bridge.time
        if c.kind == "window" and not BridgeMove.glassStep(body, c.object) then
            crossEnd(body, "glass first")
            return true
        end
        local ok, err = pcall(function()
            if c.kind == "fence" then
                body:climbOverFence(c.dir)
            elseif c.kind == "window" then
                body:faceThisObject(c.object)
                body:climbThroughWindow(c.object)
            else
                body:faceThisObject(c.object)
                body:climbThroughWindowFrame(c.object)
            end
        end)
        if not ok then crossEnd(body, "climb error: " .. tostring(err)) return true end
    end
    return true
end


local function redWentThrough(cells)
    local t = BridgeMove.trail
    for i = #t, math.max(2, #t - 40), -1 do
        local a, b = t[i], t[i - 1]
        local ax, ay, bx, by = math.floor(a.x), math.floor(a.y), math.floor(b.x), math.floor(b.y)
        for _, c in ipairs(cells) do
            if math.abs(a.z - c.z) < 0.5 and ((ax == c.x and ay == c.y and bx == c.ox and by == c.oy)
                or (ax == c.ox and ay == c.oy and bx == c.x and by == c.y)) then
                return true
            end
        end
    end
    return false
end






function BridgeMove.openDoor(body, object)
    local key = nil
    pcall(function() key = BridgeDoors ~= nil and BridgeDoors.key(object) or nil end)
    if object:isBarricaded() then
        BridgeMove.obstacle = "door barricaded"
        BridgeMove.doorWay = nil
        BridgeMove.noDoorUntil = Bridge.time + 1800
        DOOR.blacklistDoor(body, object, "barricade")
        return false
    end
    if object:IsOpen() then
        if key ~= nil then BridgeMove.badDoors[key] = nil end
        BridgeMove.doorFail = nil
        return true
    end
    local locked = false
    pcall(function() locked = object:isLocked() or object:isLockedByKey() end)
    local hasKey = false
    if locked and BridgeDoors ~= nil then hasKey = BridgeDoors.hasKey(object, body, true) end
    local inRoom = false
    pcall(function() inRoom = body:getCurrentSquare():getRoom() ~= nil end)
    local ra, rb = nil, nil
    pcall(function()
        ra = object:getSquare():getRoom()
        rb = object:getOppositeSquare():getRoom()
    end)

    local behindRed = false
    if locked and not inRoom then
        pcall(function() behindRed = redWentThrough(DOOR.doorCells(object, DOOR.doorKind(object))) end)
        if behindRed then log("door locked, but player just went through it: opening") end
    end
    local refuse = locked and not inRoom and not behindRed and not hasKey
    if refuse and ra == nil and rb == nil then
        local actor = BridgeData ~= nil and BridgeData.owner() or nil
        local near = false
        pcall(function()
            local dsq = object:getSquare()
            near = dsq ~= nil and not DOOR.playerFarFromSquare(dsq)
        end)
        if actor ~= nil and near then
            local wasOpen = false
            pcall(function() wasOpen = object:IsOpen() end)
            local tried = pcall(function() object:ToggleDoor(actor) end)
            local nowOpen = false
            pcall(function() nowOpen = object:IsOpen() end)
            if tried and nowOpen ~= wasOpen then refuse = false end
        elseif not near then
            log("door locked probe skipped: player far")
        end
    end
    if refuse or object:isObstructed() then
        BridgeMove.obstacle = "door locked"
        BridgeMove.doorWay = nil
        BridgeMove.noDoorUntil = Bridge.time + 1800
        DOOR.blacklistDoor(body, object, "locked")
        return false
    end
    if not object:IsOpen() then
        local kind = DOOR.doorKind(object)


        local cells, north = DOOR.doorCells(object, kind)
        local anchor = DOOR.doorAnchor(object, kind)



        if locked and instanceof(object, "IsoDoor") then
            if hasKey then log("key unlock " .. tostring(key)) end
            pcall(function()
                object:setLocked(false)
                object:setLockedByKey(false)
            end)
        elseif hasKey then
            if BridgeDoors ~= nil then BridgeDoors.unlock(object) end
        end
        if not BridgeMove.toggleDoor(body, object, kind) then
            BridgeMove.obstacle = "door blocked"
            BridgeMove.doorWay = nil
            BridgeMove.noDoorUntil = Bridge.time + 1800
            DOOR.blacklistDoor(body, object, "locked")
            return false
        end
        BridgeMove.rememberDoor(body, anchor, kind, cells, north)
        BridgeMove.obstacle = "door opened"
    end
    if key ~= nil then BridgeMove.badDoors[key] = nil end
    BridgeMove.doorFail = nil
    return true
end





function BridgeMove.openAhead(body)


    local goal = BridgeMove.goal
    if goal == nil then return false end
    local cur = body:getCurrentSquare()
    if cur == nil then return false end
    local x, y = body:getX(), body:getY()
    local dx, dy = 0, 0
    local prev = BridgeMove.stepPos
    if prev ~= nil then dx, dy = x - prev.x, y - prev.y end

    if dx * dx + dy * dy < 0.00005 then dx, dy = goal.x - x, goal.y - y end
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.0001 then return false end
    dx, dy = dx / len, dy / len
    local cell = getCell()
    for _, s in ipairs({ 0.35, 0.65 }) do
        local nx, ny = math.floor(x + dx * s), math.floor(y + dy * s)
        if nx ~= cur:getX() or ny ~= cur:getY() then
            local candidates
            if nx ~= cur:getX() and ny ~= cur:getY() then
                candidates = { cell:getGridSquare(nx, cur:getY(), cur:getZ()), cell:getGridSquare(cur:getX(), ny, cur:getZ()) }
            else
                candidates = { cell:getGridSquare(nx, ny, cur:getZ()) }
            end
            for _, b in ipairs(candidates) do
                local door = nil
                if b ~= nil then pcall(function() door = cur:getDoorTo(b) end) end
                if door ~= nil and DOOR.isDoor(door) and not door:IsOpen() and beyondEdge(cur, b, goal.x, goal.y) then

                    if not Bridge.follow and BridgeMove.doorBlocked(door) then
                        BridgeMove.obstacle = "door blacklisted"
                        return false
                    end
                    if not BridgeMove.doorOpenable(body, door) then return BridgeMove.openDoor(body, door) end
                    local fx = (cur:getX() + b:getX()) / 2 + 0.5
                    local fy = (cur:getY() + b:getY()) / 2 + 0.5
                    return BridgeMove.startDoorAct(body, "open", door, nil, fx, fy)
                end
            end
            return false
        end
    end
    return false
end




function BridgeMove.doorOpenable(body, object)
    local ok = true
    pcall(function()
        if object:isBarricaded() then ok = false return end
        local locked = false
        pcall(function() locked = object:isLocked() or object:isLockedByKey() end)
        local inRoom = false
        pcall(function() inRoom = body:getCurrentSquare():getRoom() ~= nil end)
        local hasKey = false
        if locked and not inRoom and BridgeDoors ~= nil then hasKey = BridgeDoors.hasKey(object, body) end
        if object:isObstructed() then ok = false return end
        if locked and not inRoom and not hasKey then ok = false return end
        if DOOR.doorKind(object) == "double" then
            local blocked = true
            pcall(function() blocked = IsoDoor.isDoubleDoorObstructed(object) end)
            if blocked then ok = false end
        end
    end)
    return ok
end









BridgeMove.doorAct = nil


local DOOR_HAND = { open = 10, close = 4 }
local DOOR_HAND_BIG = { open = 16, close = 8 }
local DOOR_AFTER = { open = 6, close = 4 }
DOOR.ACT_MAX = 150

function BridgeMove.startDoorAct(body, want, door, rec, fx, fy, passed)
    if BridgeMove.doorAct ~= nil or door == nil then return false end

    if BridgeFight ~= nil and BridgeFight.target ~= nil then return false end
    local kind = rec ~= nil and rec.kind or DOOR.doorKind(door)
    BridgeMove.doorAct = { want = want, door = door, kind = kind, rec = rec, fx = fx, fy = fy,
        passed = passed, t0 = Bridge.time, lastFrame = Bridge.time }
    return true
end


function BridgeMove.doorStep(body)
    local a = BridgeMove.doorAct
    if a == nil then return false end

    if Bridge.time - a.lastFrame > 10 or Bridge.time - a.t0 > DOOR.ACT_MAX then
        BridgeMove.doorAct = nil
        return false
    end
    a.lastFrame = Bridge.time

    if BridgeMove.onPath() then BridgeMove.stopPath(body) end
    pcall(function()
        local bump = tostring(body:getBumpType())
        if bump ~= "Stand" then body:setBumpType("Stand") end
    end)
    pcall(function()
        if a.fx ~= nil then body:faceLocationF(a.fx, a.fy) else body:faceThisObject(a.door) end
    end)
    if a.doneAt == nil then
        local hand = ((a.kind == "double" or a.kind == "garage") and DOOR_HAND_BIG or DOOR_HAND)[a.want] or 10
        if Bridge.time - a.t0 < hand then return true end
        a.doneAt = Bridge.time
        if a.want == "open" then
            local ok = false
            pcall(function() ok = BridgeMove.openDoor(body, a.door) end)
            if not ok then
                BridgeMove.doorAct = nil
                return false
            end
            log(sformat("door opened by hand after %d ticks", a.doneAt - a.t0))
        else
            local wait = BridgeMove.closeNow(body, a.rec, a.passed)
            if wait ~= nil then


                if a.rec ~= nil then a.rec.retryAt = Bridge.time + 30 end
                BridgeMove.doorAct = nil
                return false
            end
        end
        return true
    end
    if Bridge.time - a.doneAt < (DOOR_AFTER[a.want] or 6) then return true end
    BridgeMove.doorAct = nil
    return false
end






function BridgeMove.glassStep(body, object)
    local sq = nil
    pcall(function() sq = object ~= nil and object:getSquare() or nil end)
    if sq == nil or BridgeClean == nil or BridgeClean.squareWindow == nil then return true end
    local g = nil
    pcall(function() g = BridgeClean.squareWindow(sq) end)
    if g == nil then return true end
    local delegated = false
    if BridgeTask ~= nil and BridgeTask.requireGlass ~= nil then
        pcall(function() delegated = BridgeTask.requireGlass(sq) == true end)
    end
    if not delegated then
        pcall(function() BridgeTask.applyClean(body, sq, "window") end)
        pcall(function() if BridgeTask.CLEAN_SOUND ~= nil then body:playSound(BridgeTask.CLEAN_SOUND) end end)
        log("window glass cleared before climbing")
    else
        log("window glass queued for clean-up before climbing")
    end
    return false
end


function BridgeMove.handleObstacle(body)

    if BridgeMove.noClimb then return false end
    if BridgeMove.window then
        local w = BridgeMove.window
        body:faceLocationF(w.x, w.y)
        pcall(function()
            body:setVariable("bPathfind", false)
            body:setMoving(false)
            if tostring(body:getBumpType()) ~= "WindowOpen" then
                body:setVariable("BumpAnimFinished", false)
                body:setBumpType("WindowOpen")
            end
        end)
        local square = getCell():getGridSquare(w.x, w.y, w.z)
        local window = square and square:getWindow()
        if window == nil or window:IsOpen() or window:isSmashed() or (Bridge.time - w.tick) > 40 then
            local opened = window == nil
            if window ~= nil and not window:IsOpen() and not window:isSmashed() then
                pcall(function() window:ToggleWindow(body) end)
                pcall(function() body:playSound("OpenWindow") end)
            end
            pcall(function() opened = window ~= nil and (window:IsOpen() or window:isSmashed()) end)
            if window ~= nil and not opened then
                DOOR.blacklistDoor(body, window, "locked")
                BridgeMove.obstacle = "window would not open"
BridgeMove.window = nil
BridgeMove.noClimb = false
                return false
            end
            if window ~= nil and opened then BridgeMove.noteWindowOpened(body, window) end
            BridgeMove.window = nil
            BridgeMove.obstacle = "window opened"
            return false
        end
        return true
    end

    local collided = body:isCollidedWithDoor() or body:isCollidedThisFrame() or body:isCollided()
    if not collided then return false end

    local square = squareAhead(body)
    if square == nil then return false end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local properties = object and object:getProperties()
        if properties then




            local gate = DOOR.isDoor(object)

            if not gate and (properties:get("FenceTypeLow") or object:isHoppable()) then
                if body:isFacingObject(object, 0.5) then
                    local pass = BridgeRoute.passInstead(body, "fence")
                    if pass ~= nil then
                        BridgeMove.obstacle = "low fence: " .. pass
                        return pass == "new"
                    end
                    if BridgeMove.askClimb(body, "fence", object) then
                        BridgeMove.obstacle = "low fence"
                        return true
                    end
                    BridgeMove.obstacle = "low fence: goal on this side"
                    return false
                else
                    body:faceThisObject(object)
                end
                return true
            end

            if not gate and (properties:get("FenceTypeHigh") or object:isTallHoppable()) then


                BridgeMove.obstacle = "tall fence"
                BridgeMove.noCrossUntil = 0
                return false
            end

            local frame = false
            pcall(function() frame = instanceof(object, "IsoWindowFrame") end)

            if frame and square:getWindow() == nil then
                local can = false
                pcall(function() can = object:canClimbThrough(body) end)
                if not can then
                    BridgeMove.obstacle = "window frame blocked"
                    return false
                end
                if body:isFacingObject(object, 0.5) then
                    local pass = BridgeRoute.passInstead(body, "frame")
                    if pass ~= nil then
                        BridgeMove.obstacle = "window frame: " .. pass
                        return pass == "new"
                    end
                    BridgeMove.askClimb(body, "frame", object)
                    BridgeMove.obstacle = "window frame climb"
                else
                    body:faceThisObject(object)
                end
                return true
            end
            if instanceof(object, "IsoWindow") then
                if body:isFacingObject(object, 0.5) then
                    if not Bridge.follow and BridgeMove.doorBlocked(object) then
                        BridgeMove.obstacle = "window blacklisted"
                        return false
                    end
                    local wkey = nil
                    pcall(function() wkey = BridgeDoors ~= nil and BridgeDoors.key(object) or nil end)
                    if BridgeMove.openingWay ~= nil and wkey ~= nil
                        and BridgeMove.openingWay.key == wkey then
                        return false
                    end
                    if object:isBarricaded() then
                        DOOR.blacklistDoor(body, object, "barricade")
                        BridgeMove.obstacle = "window barricaded"
                        return false
                    elseif BridgeRoute.passInstead(body, "window") ~= nil then
                        BridgeMove.obstacle = "window: going around"
                        return BridgeMove.gapWay ~= nil and BridgeMove.gapWay.tick == Bridge.tick
                    elseif not object:IsOpen() and not object:isSmashed() then
                        if not object:isPermaLocked() then
                            local sq = object:getSquare()
                            BridgeMove.window = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), tick = Bridge.time }
                            pcall(function()
                                body:faceLocationF(sq:getX() + 0.5, sq:getY() + 0.5)
                                body:setVariable("BumpAnimFinished", false)
                                body:setBumpType("WindowOpen")
                            end)
                            BridgeMove.obstacle = "window opening"
                            return true
                        end
                        DOOR.blacklistDoor(body, object, "locked")
                        BridgeMove.obstacle = "window locked"
                        return false
                    elseif object:canClimbThrough(body) then
                        if not BridgeMove.glassStep(body, object) then
                            BridgeMove.obstacle = "window glass first"
                            return false
                        end
                        BridgeMove.askClimb(body, "window", object)
                        BridgeMove.obstacle = "window climb"
                        return true
                    else
                        DOOR.blacklistDoor(body, object, "locked")
                        BridgeMove.obstacle = "window not climbable"
                        return false
                    end
                else
                    body:faceThisObject(object)
                    return true
                end
            end

            if instanceof(object, "IsoDoor") or (instanceof(object, "IsoThumpable") and object:isDoor()) then
                if body:isFacingObject(object, 0.5) then

                    local doorInside = false
                    pcall(function() doorInside = body:getCurrentSquare():getRoom() ~= nil end)
                    local doorCrossed = false
                    if Bridge.follow and not doorInside then
                        pcall(function() doorCrossed = redWentThrough(DOOR.doorCells(object, DOOR.doorKind(object))) end)
                    end
                    if BridgeMove.doorBlocked(object) and (not Bridge.follow or (not doorInside and not doorCrossed)) then
                        BridgeMove.obstacle = "door blacklisted"
                        return false
                    end
                    if object:IsOpen() or not BridgeMove.doorOpenable(body, object) then
                        return BridgeMove.openDoor(body, object)
                    end
                    return BridgeMove.startDoorAct(body, "open", object)
                else
                    body:faceThisObject(object)
                    return true
                end
            end
        end
    end
    return false
end








local function pickSpeed(d)
    if BridgeMove.speedMode == "fixed" then return BridgeMove.fixedSpeed end
    if not BridgeMove.redMoving then return 1.0 end
    if d < 1.3 then return 0.8 end
    if d < 1.7 then return 0.88 end
    if d < 2.1 then return 1.1 end
    return 1.25
end




function BridgeMove.set(name, value)
    if name == "anim" then
        BridgeMove.animOld = value == "old"
        return "anim " .. (BridgeMove.animOld and "old" or "new")
    elseif name == "blend" then
        BridgeMove.blendOverride = (value ~= "auto") and tonumber(value) or nil
        return "blend " .. tostring(BridgeMove.blendOverride or "auto")
    elseif name == "doorghost" then
        BridgeMove.doorGhost = value ~= "off"
        return "doorghost " .. (BridgeMove.doorGhost and "on" or "off")
    elseif name == "turn" then
        BridgeMove.turnLimit = (value ~= "off") and tonumber(value) or nil
        return "turn " .. tostring(BridgeMove.turnLimit or "off")
    elseif name == "bumpmove" then
        BridgeMove.bumpMove = value == "face" and "face" or "move"
        return "bumpmove " .. BridgeMove.bumpMove
    elseif name == "nocollide" then
        BridgeMove.noCollide = value ~= "off"
        return "nocollide " .. (BridgeMove.noCollide and "on" or "off")
    elseif name == "steer" then
        BridgeMove.steerMode = value ~= "off"
        return "steer " .. (BridgeMove.steerMode and "on" or "off")
    elseif name == "nav" then
        BridgeMove.navEnabled = value ~= "off"
        BridgeRoute.reset()
        return "nav " .. (BridgeMove.navEnabled and "on" or "off")
    elseif name == "back" then
        Bridge.backEnabled = value ~= "off"
        if Bridge.backEnabled == false and BridgeMove.follow ~= nil then
            if BridgeMove.follow.back ~= nil and Bridge.body ~= nil then
                BridgeMove.backEnd(Bridge.body, BridgeMove.follow, "off", nil)
            end
            BridgeMove.follow.back = nil
            BridgeMove.follow.backQuiet = 0
            BridgeMove.backActive = false
        end
        return "back " .. (Bridge.backEnabled == false and "off" or "on")
    elseif name == "runreplan" then
        BridgeMove.runReplan = tonumber(value) or BridgeMove.runReplan
        return "runreplan " .. tostring(BridgeMove.runReplan)
    elseif name == "runevery" then
        BridgeMove.runEvery = tonumber(value) or BridgeMove.runEvery
        return "runevery " .. tostring(BridgeMove.runEvery)
    elseif name == "speedmod" then
        BridgeMove.speedModOverride = (value ~= "auto") and tonumber(value) or nil
        return "speedmod " .. tostring(BridgeMove.speedModOverride or "auto")
    elseif name == "sneakhold" then
        if BridgeGunfight == nil then return "sneakhold unavailable" end
        return BridgeGunfight.setSneakHold(value)
    end
    if name == "replan" then BridgeMove.replanDist = tonumber(value) or BridgeMove.replanDist
    elseif name == "every" then BridgeMove.pathEvery = tonumber(value) or BridgeMove.pathEvery
    elseif name == "speed" then BridgeMove.speedMode = value or BridgeMove.speedMode
    elseif name == "fixed" then BridgeMove.fixedSpeed = tonumber(value) or BridgeMove.fixedSpeed
    elseif name == "bump" then BridgeMove.startBump = value or BridgeMove.startBump
    elseif name == "slow" then BridgeMove.slowDist = tonumber(value) or BridgeMove.slowDist
    else return "unknown param: " .. tostring(name) end
    return sformat("replan=%.2f every=%d speed=%s fixed=%.2f bump=%s slow=%.2f", BridgeMove.replanDist,
        BridgeMove.pathEvery, BridgeMove.speedMode, BridgeMove.fixedSpeed, BridgeMove.startBump, BridgeMove.slowDist)
end




function BridgeMove.goToward(body, x, y, z, way)

    if BridgeMove.cross ~= nil then crossEnd(body, "other move") end
    local pf = body:getPathFindBehavior2()
    local exSpeed = BridgeMove.exhaustionSpeed()
    if exSpeed < 1.0 then
        pcall(function()
            body:setVariable("WalkSpeed", ((BridgeMove.walkType == "SlowWalk") and 0.75 or 1.0) * exSpeed)
        end)
    end
    if way then
        if BridgeMove.climbStep(body) then return end
        local okDoor, atDoor = pcall(function() return BridgeMove.doorStep(body) end)
        if okDoor and atDoor then return end
        if BridgeMove.pathing then
            local okObs, busy = pcall(function() return BridgeMove.handleObstacle(body) end)
            if not okObs then BridgeMove.obstacle = "error: " .. tostring(busy) end
            if okObs and busy then
                log(sformat("obstacle=%s pathing=%s steering=%s body=%.2f,%.2f goal=%.1f,%.1f busy=%s",
                    tostring(BridgeMove.obstacle), tostring(BridgeMove.pathing), tostring(BridgeMove.steering),
                    body:getX(), body:getY(), x, y, tostring(busy)))
                return
            end
        end
        x, y, z = BridgeRoute.enginePathGoal(body, x, y, z, true)
    end
    if BridgeRoute.enginePathNeed(body, x, y) then
        local wasPathing = BridgeMove.pathing
        BridgeMove.lastPath = Bridge.time
        local bump = ""
        pcall(function() bump = tostring(body:getBumpType()) end)
        if not BridgeMove.pathing or bump == "Stand" then







            local asn = ""
            pcall(function() asn = tostring(body:getActionStateName()) end)
            local onTheMove = (Bridge.time - BridgeMove.stepTick) < 10
                and (isFollowBump(bump) or asn == "walktoward" or asn == "pathfind")
            if onTheMove and bump ~= KICK then
                if isFollowBump(bump) then BridgeMove.endFollowBump(body, "") end
                BridgeMove.steering = false
            elseif bump ~= KICK then
                BridgeMove.startKick(body)
            end
            Bridge.holdPos = nil
        end
        pf:pathToLocationF(x, y, z)
        BridgeMove.goal = { x = x, y = y }
        BridgeMove.pathing = true
        log(sformat("path start goal=%.1f,%.1f,%.1f from=%.2f,%.2f replan=%s every=%d",
            x, y, z, body:getX(), body:getY(), tostring(wasPathing), BridgeMove.pathEvery))
    end
    local res = pf:update()
    BridgeMove.kickStep(body, pf)
    BridgeMove.pathResult = tostring(res)
    if res == BehaviorResult.Succeeded or res == BehaviorResult.Failed then
        BridgeMove.pathing = false
        BridgeMove.lastPath = Bridge.time
        if res == BehaviorResult.Failed then BridgeMove.lastFailed = Bridge.time end
        log(sformat("path result=%s goal=%.1f,%.1f body=%.2f,%.2f pathing=%s",
            tostring(res), x, y, body:getX(), body:getY(), tostring(BridgeMove.pathing)))
    end
    trackStep(body)
end





function BridgeMove.reset(body)
    if body ~= nil then
        BridgeMove.setCollide(body, true)
        BridgeMove.endFollowBump(body, "")

        if BridgeMove.follow ~= nil and BridgeMove.follow.passing then pcall(function() body:setSolid(true) end) end
    end
    BridgeMove.collideOff = false
    if BridgeMove.follow ~= nil then
        if body ~= nil and (BridgeMove.follow.back ~= nil or BridgeMove.backActive) then
            BridgeMove.backEnd(body, BridgeMove.follow, "reset", nil)
        end
        BridgeMove.follow.back = nil
        BridgeMove.follow.backQuiet = 0
    end
    BridgeMove.backActive = false
    BridgeMove.trail = {}
    BridgeMove.follow.cross = nil
    BridgeMove.redVx, BridgeMove.redVy, BridgeMove.redPrevPos = 0, 0, nil
    BridgeMove.steering = false
    BridgeMove.walkFrames = 0
    if body ~= nil then BridgeMove.stopPath(body) end
    BridgeMove.pathing = false
    BridgeMove.goal = nil
    BridgeMove.redAt = nil
    BridgeMove.wasWalking = false
    BridgeMove.moving = false
    BridgeMove.window = nil
    BridgeMove.walkType = "Walk"
    BridgeMove.redPrev = nil
    BridgeMove.redHist = nil
    BridgeMove.redMoving = false
    BridgeMove.stepPos = nil
    BridgeMove.climbUntil = 0
    BridgeMove.pendingClimb = nil
    if BridgeMove.cross ~= nil and body ~= nil then
        pcall(function()
            body:setVariable("bPathfind", false)
            local bump = body:getBumpType()
            if bump == "ClimbFenceTall" or bump == "ClimbFenceTallStart" then BridgeMove.releaseBump(body) end
        end)
    end
    BridgeMove.cross = nil
    BridgeMove.noCrossUntil = 0
    BridgeMove.lastCross = nil
    BridgeMove.edgeSeen = nil
    BridgeMove.doorAct = nil
    BridgeMove.doorWay = nil

    BridgeMove.opened = {}
    BridgeMove.openWindows = {}
    BridgeMove.gapWay = nil
    BridgeMove.openingWay = nil
    BridgeMove.openingBlocked = nil
    BridgeMove.seat = nil
    if BridgeMove.seatFlag or BridgeMove.seatBound ~= nil then chairFlagsOff(body) end
    BridgeMove.sitFlagOff(body)
    BridgeMove.nearReset()
    BridgeRoute.reset()

    BridgeMove.stride = nil
    if body ~= nil then setStride(body, false) end
end

BridgeMove.dist2d = dist2d
BridgeMove.sformat = sformat
BridgeMove.clamp = clamp
BridgeMove.keepExtra = keepExtra
BridgeMove.drive = drive
BridgeMove.trackStep = trackStep
BridgeMove.stepAside = stepAside
BridgeMove.freshDrive = freshDrive
BridgeMove.routeAround = routeAround
BridgeMove.seatStand = seatStand
BridgeMove.seatFrom = seatFrom
BridgeMove.seatCellOk = seatCellOk
BridgeMove.zoneFree = zoneFree
BridgeMove.zoneDetour = zoneDetour
BridgeMove.pointAt = pointAt
BridgeMove.cellOf = cellOf
BridgeMove.cardinal = cardinal
BridgeMove.pickWalkType = pickWalkType
BridgeMove.pickSpeed = pickSpeed
BridgeMove.capRun = capRun
BridgeMove.blockedAhead = blockedAhead
BridgeMove.redPrevSlot = redPrevSlot
BridgeMove.redPrevPosSlot = redPrevPosSlot
BridgeMove.KICK = KICK
BridgeMove.climbCost = climbCost
BridgeMove.DOOR = DOOR

log("loaded")




local function freeSeat(vehicle)
    local n = vehicle:getMaxPassengers()
    for seat = 1, n - 1 do
        if vehicle:isSeatInstalled(seat) and not vehicle:isSeatOccupied(seat) then
            return seat
        end
    end
    return nil
end


function BridgeMove.enterCar(body, vehicle)
    local seat = freeSeat(vehicle)
    if seat == nil then return "no free seat" end
    BridgeRoute.reset()
    BridgeMove.stopPath(body)
    local ok, err = pcall(function()
        if not vehicle:enter(seat, body) then return "enter returned false" end
        vehicle:setCharacterPosition(body, seat, "inside")
        pcall(function() vehicle:playPassengerAnim(seat, "idle") end)
    end)
    if ok and err ~= nil then ok = false end
    if not ok then

        local ok2, err2 = pcall(function()
            local fd = body:getForwardDirection()
            body:enterVehicle(vehicle, seat, Vector3f.new(fd:getX(), fd:getY(), 0))
        end)
        if not ok2 then return "enter failed: " .. tostring(err) .. " / " .. tostring(err2) end
    end
    pcall(function() body:playSound("VehicleDoorClose") end)
    return "seat " .. tostring(seat)
end

function BridgeMove.exitCar(body)
    local vehicle = body:getVehicle()
    if vehicle == nil then return "not in car" end
    local ok, err = pcall(function()
        local seat = vehicle:getSeat(body)
        vehicle:exit(body)
        vehicle:setCharacterPosition(body, seat, "outside")
    end)
    if not ok then return "exit failed: " .. tostring(err) end
    pcall(function() body:playSound("VehicleDoorOpen") end)
    BridgeMove.reset(body)
    return "exited"
end


function BridgeMove.toCar(body, vehicle)
    local d = dist2d(body:getX(), body:getY(), vehicle:getX(), vehicle:getY())
    if d > 2.4 then
        BridgeMove.walkType = (d > RUN.DIST) and "Run" or "Walk"
        BridgeMove.goToward(body, vehicle:getX(), vehicle:getY(), vehicle:getZ())
        return true
    end
    local res = BridgeMove.enterCar(body, vehicle)
    BridgeMove.obstacle = "car: " .. tostring(res)
    return true
end

if type(Events) == "table" and Events.OnTick ~= nil then
    Events.OnTick.Add(function()
        local b = Bridge ~= nil and Bridge.body or nil
        if b == nil then
            pcall(function() BridgeMove.sitFlagOff(nil) end)
            return
        end
        pcall(BridgeMove.sitFlagTick, b)
    end)
end

