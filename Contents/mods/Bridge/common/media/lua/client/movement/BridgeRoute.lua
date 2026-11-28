BridgeRoute = BridgeRoute or {}

local GAP_WALK = 1.4
local GAP_RUN = 1.9
local STOP_GAP = 1.3
local START_DIST = 2.2
local START_GOING = 0.85
local SEE_FAR = 14
local CATCH_FROM = 1.0
local CATCH_FULL = 2.5
local NO_LINE_FRAMES = 20
local STUCK_LEAVE = 1.5
local FOLLOW_START = 2.0
local FOLLOW_STOP = 0.9
local CORPSE_EXTRA = 1.0
local TRACE_EVERY = 2
local PUSH_GRACE = 12
local COMING_COS = 0.5

local SLOW = { RED = 1.15, FRAMES = 45, GO = 0.45 }
local ASIDE = { AHEAD = 1.0, PUSH = 10, PATH = 0.55, STEP = 0.5, MAX = 45, QUIET = 45 }
local DOORWAY = { STOP = 1.0, ROOM = 1.2, CLEAR = 0.3 }
local NAV = { STALL_TICKS = 90, STALL_MOVE = 0.3, PATH_FAIL_LIMIT = 2, DETOUR_TICKS = 150,
    DETOUR_STEP = 1.6, OPENING_GIVE_UP = 360, FOLLOW_HOLD = 120 }
local SPOT = { SIDE = 1.3, BACK = 0.35, FAR = 1.0, REACH = 6, TURN = math.cos(math.rad(50)),
    ENTER = 8, LEAVE = 4, ARRIVE = 0.35, START = 0.7 }

local MEM = {}

local function log(text)
    if BridgeLog == nil or not BridgeLog.on() then return end
    text = tostring(text)
    if text == MEM.lastLogText then return end
    MEM.lastLogText = text
    if not string.find(text, " t=", 1, true) then
        if string.find(text, "seat:", 1, true) == 1 or string.find(text, "door", 1, true) == 1
                or string.find(text, "cross", 1, true) == 1 or string.find(text, "edge", 1, true) == 1
                or string.find(text, "toggleDoor", 1, true) == 1 then
            text = text .. " t=" .. tostring(Bridge.tick or 0)
        end
    end
    print("[BridgeRoute] " .. text)
end

local function ev(name, fields, fn)
    if BridgeLog == nil or BridgeLog.event == nil then return end
    fields = fields or {}
    fields.fn = fn or "BridgeRoute"
    BridgeLog.event(name, fields)
end

local function sformat(...) return BridgeMove.sformat(...) end
local function dist2d(...) return BridgeMove.dist2d(...) end
local function frameDt() return BridgeMove.frameDt() end
local function clamp(...) return BridgeMove.clamp(...) end
local function trackStep(body) return BridgeMove.trackStep(body) end
local function drive(...) return BridgeMove.drive(...) end
local function keepExtra() return BridgeMove.keepExtra() end

local function resolve(v)
    if type(v) == "function" then return v() end
    return v
end

local function doorBlocker(sq)
    local reason = nil
    if sq == nil then return nil end
    pcall(function()
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            if o ~= nil then
                local door = false
                pcall(function()
                    door = instanceof(o, "IsoDoor")
                        or (instanceof(o, "IsoThumpable") and o:isDoor())
                end)
                if door then
                    local bar, lock = false, false
                    pcall(function() bar = o:isBarricaded() end)
                    pcall(function() lock = o:isLocked() or o:isLockedByKey() end)
                    if bar then reason = "barricade" return end
                    if lock then reason = "locked" end
                end
            end
        end
    end)
    return reason
end

function BridgeRoute.blockedReason(target)
    local ob = ""
    pcall(function() ob = tostring(BridgeMove ~= nil and BridgeMove.obstacle or "") end)
    if string.find(ob, "barricad", 1, true) ~= nil then return "barricade" end
    if string.find(ob, "locked", 1, true) ~= nil then return "locked" end
    local reason = nil
    pcall(function()
        local body = Bridge.body
        if body ~= nil then reason = doorBlocker(body:getCurrentSquare()) end
        if reason == nil and target ~= nil then
            local sq = getCell():getGridSquare(target.x, target.y, target.z)
            reason = doorBlocker(sq)
        end
    end)
    return reason
end

function BridgeRoute.newState()
    return { checkX = nil, checkY = nil, still = 0, bestD = nil, progressAt = nil,
        pathFails = 0, pathFailTick = nil,
        openingKey = nil, openingSince = nil, openingRef = nil, openingTries = nil,
        detour = nil, detourSide = nil, reason = nil, status = "ok" }
end

function BridgeRoute.opening(state, opts)
    opts = opts or {}
    local way = BridgeMove ~= nil and BridgeMove.openingWay or nil
    if way == nil then return "ok" end
    if state.openingKey ~= way.key then
        state.openingKey = way.key
        state.openingSince = Bridge.time
    elseif state.openingSince ~= nil
            and Bridge.time - state.openingSince > (opts.giveUp or 360) then
        state.openingRef, state.openingKey, state.openingTries = nil, nil, nil
        state.openingSince = nil
        state.reason = BridgeRoute.blockedReason(opts.target)
        return "stale", state.reason
    end
    return "ok"
end

function BridgeRoute.notePathFail(state, opts)
    opts = opts or {}
    local failed = false
    pcall(function()
        failed = BridgeMove ~= nil and not BridgeMove.pathing
            and BridgeMove.pathResult == tostring(BehaviorResult.Failed)
    end)
    if not failed then return "ok" end
    if state.pathFailTick ~= Bridge.tick then
        state.pathFails = (state.pathFails or 0) + 1
    end
    state.pathFailTick = Bridge.tick
    pcall(function() BridgeMove.pathResult = "none" end)
    if (state.pathFails or 0) >= (opts.limit or 2) then
        return "failed"
    end
    return "ok"
end

local function progressEv(state, reason)
    if BridgeLog == nil or not BridgeLog.on() then return end
    local sig = tostring(reason)
    local now = Bridge.tick or 0
    if BridgeRoute.progressSig == sig and (now % 15) ~= 0 then return end
    BridgeRoute.progressSig = sig
    local body = Bridge.body
    local goal = state.goal
    local dGoal = -1
    if body ~= nil and goal ~= nil then dGoal = dist2d(body:getX(), body:getY(), goal.x, goal.y) end
    ev("route.progress", {
        progressAt = state.progressAt, since = state.since, bestD = state.bestD,
        dSpot = state.dSpot, dGoal = dGoal,
        age = Bridge.time - (state.progressAt or Bridge.time),
        sinceAge = Bridge.time - (state.since or Bridge.time),
        verdict = state.status or "-", refresh_reason = reason or "unknown",
        sig = tostring(reason) }, "BridgeRoute.progress")
end

function BridgeRoute.noteProgress(state, reason)
    state = state or BridgeRoute.state
    state.progressAt = Bridge.time
    state.refreshReason = reason or "unknown"
    progressEv(state, reason)
end

function BridgeRoute.progress(state, opts)
    opts = opts or {}
    local since = state.progressAt or state.since or Bridge.time
    if (Bridge.time - since) > (opts.noProgress or 300)
            or (Bridge.time - (state.since or Bridge.time)) > (opts.timeout or 1200) then
        if resolve(opts.onSpot) then
            state.progressAt = Bridge.time
            state.since = Bridge.time
            state.refreshReason = "waiting_player"
            progressEv(state, "waiting_player")
            return "waiting"
        end
        progressEv(state, "timeout")
        return "timeout"
    end
    progressEv(state, "ok")
    return "ok"
end

function BridgeRoute.stall(body, state, opts)
    opts = opts or {}
    if state.checkX == nil then state.checkX, state.checkY = body:getX(), body:getY() end
    state.still = (state.still or 0) + 1
    if state.still < (opts.ticks or 90) then return "ok" end
    local moved = math.abs(body:getX() - state.checkX) + math.abs(body:getY() - state.checkY)
        > (opts.move or 0.3)
    local function stallEv(result, exemptV, onSpotV)
        if BridgeLog == nil or not BridgeLog.on() then return end
        ev("route.stall", { result = result, still = state.still, moved = moved,
            exempt = exemptV, onSpot = onSpotV, detour = state.detour,
            side = state.detourSide, reason = result,
            opening = BridgeMove.openingWay ~= nil and BridgeMove.openingWay.key or nil,
            spot = state.spot, cross = BridgeMove.cross ~= nil,
            window = BridgeMove.window ~= nil, doorAct = BridgeMove.doorAct ~= nil,
            climb = BridgeMove.pendingClimb ~= nil, owner = BridgeRoute.state.owner,
            body = { x = body:getX(), y = body:getY() },
            age = Bridge.time - (state.progressAt or Bridge.time) }, "BridgeRoute.stall")
    end
    state.still = 0
    state.checkX, state.checkY = body:getX(), body:getY()
    if moved then return "ok" end
    local exempt = resolve(opts.exempt) == true
    local onSpot = false
    if not exempt then onSpot = resolve(opts.onSpot) == true end
    local owner = tostring(BridgeRoute.state.owner or "-")
    if owner ~= "-" and owner ~= "follow" then
        log(sformat("stall result=%s moved=false exempt=%s onSpot=%s cross=%s window=%s doorAct=%s climb=%s owner=%s body=%.2f,%.2f",
            exempt and "ok" or (onSpot and "waiting" or "stalled"),
            tostring(exempt), tostring(onSpot),
            tostring(BridgeMove ~= nil and BridgeMove.cross ~= nil),
            tostring(BridgeMove ~= nil and BridgeMove.window ~= nil),
            tostring(BridgeMove ~= nil and BridgeMove.doorAct ~= nil),
            tostring(BridgeMove ~= nil and BridgeMove.pendingClimb ~= nil),
            owner, body:getX(), body:getY()))
    end
    if exempt then
        state.still = 0
        stallEv("exempt", true, false)
        return "ok"
    end
    if onSpot then
        state.checkX, state.checkY = nil, nil
        state.still = 0
        BridgeRoute.noteProgress(state, "stall_wait")
        stallEv("waiting", false, true)
        return "waiting"
    end
    state.checkX, state.checkY = nil, nil
    stallEv("stalled", false, false)
    return "stalled"
end

function BridgeRoute.detour(body, x, y, z, state, opts)
    opts = opts or {}
    local bx, by = body:getX(), body:getY()
    local ddx, ddy = (x + 0.5) - bx, (y + 0.5) - by
    local dlen = math.sqrt(ddx * ddx + ddy * ddy)
    if dlen <= 0.05 then return nil end
    ddx, ddy = ddx / dlen, ddy / dlen
    local cell = getCell()
    local gz = math.floor(z)
    local red = Bridge.follow == true and BridgeData.owner() or nil
    local lineToPlayer = red ~= nil and BridgeMove.lineClear(body, red:getX(), red:getY(), red:getZ()) or false
    local bodyToPlayer = red ~= nil and dist2d(bx, by, red:getX(), red:getY()) or nil
    state.detourSide = -(state.detourSide or 1)
    for _, s in ipairs({ state.detourSide, -state.detourSide }) do
        local px = math.floor(bx + (-ddy * s) * (opts.step or 1.6))
        local py = math.floor(by + (ddx * s) * (opts.step or 1.6))
        local cand = cell:getGridSquare(px, py, gz)
        local free = false
        if cand ~= nil then pcall(function() free = cand:isFree(false) == true end) end
        local farther = false
        if red ~= nil and lineToPlayer and bodyToPlayer ~= nil then
            if dist2d(px + 0.5, py + 0.5, red:getX(), red:getY()) > bodyToPlayer + 0.6 then farther = true end
        end
        if free and not farther and (opts.passable == nil or opts.passable(px, py, gz) ~= false) then
            local point = { x = px + 0.5, y = py + 0.5, z = z,
                expires = Bridge.time + (opts.ticks or 150) }
            state.detour = point
            if BridgeLog ~= nil and BridgeLog.on() then
                ev("route.detour", { point = point, side = s, spot = state.spot,
                    still = state.still, reason = "stall",
                    opening = BridgeMove.openingWay ~= nil and BridgeMove.openingWay.key or nil },
                    "BridgeRoute.detour")
            end
            return point, px, py
        end
    end
    return nil
end

BridgeRoute.state = BridgeRoute.newState()
BridgeRoute.att = 0
BridgeRoute.stepTick = -9999
BridgeRoute.lastStatus = nil
BridgeRoute.traceArm = -9999
BridgeRoute.traceUntil = 0
BridgeRoute.traceLast = nil
BridgeRoute.traceSig = nil

function BridgeRoute.reset()
    BridgeRoute.att = (BridgeRoute.att or 0) + 1
    local s = BridgeRoute.newState()
    s.owner = nil
    s.goal = nil
    s.stand = nil
    s.target = nil
    s.mode = nil
    s.stepTick = nil
    s.lastStatus = nil
    BridgeRoute.state = s
    BridgeRoute.stepTick = -9999
    BridgeRoute.lastStatus = nil
    if BridgeTask ~= nil then
        BridgeTask.spot = nil
        BridgeTask.since = nil
        BridgeTask.progressAt = nil
        BridgeTask.bestD = nil
        BridgeTask.still = 0
        BridgeTask.checkX = nil
        BridgeTask.checkY = nil
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
        BridgeTask.openingRef = nil
        BridgeTask.openingKey = nil
        BridgeTask.openingTries = nil
        BridgeTask.openingSince = nil
        BridgeTask.detour = nil
    end
end

function BridgeRoute.trace(body, d, needPath, stalled)
    if Bridge.tick < BridgeRoute.traceUntil and (Bridge.tick % TRACE_EVERY) == 0 then
        pcall(function()
            local red = BridgeData.owner()
            local bx, by, rx, ry = body:getX(), body:getY(), red:getX(), red:getY()

            local last = BridgeRoute.traceLast
            local frames = last and math.max(1, Bridge.tick - last.t) or 1
            local bstep = last and dist2d(last.bx, last.by, bx, by) / frames or 0
            local rstep = last and dist2d(last.rx, last.ry, rx, ry) / frames or 0
            BridgeRoute.traceLast = { t = Bridge.tick, bx = bx, by = by, rx = rx, ry = ry }
            local mode = (red:isSprinting() and "S" or "") .. (red:isRunning() and "R" or "") .. (red:isSneaking() and "K" or "")
            local stype, wt, smod = -1, "?", -1
            pcall(function() smod = body:getSpeedMod() end)
            pcall(function() stype = body:getSpeedType() end)
            pcall(function() wt = tostring(body:getWalkType()) end)
            local goal = BridgeRoute.state.goal
            local dGoal = goal ~= nil and dist2d(bx, by, goal.x, goal.y) or -1
            local op = BridgeMove.openingWay
            local det = BridgeRoute.state.detour
            local msg = sformat("st=%s bump=%s %s wt=%s stype=%d d=%.2f bstep=%.3f rstep=%.3f player=%s path=%s need=%s stall=%s res=%s restarts=%d ws=%.2f smod=%.3f anim=%s fk=%s fs=%.2f ferr=%.2f fk1=%.3f tx=%.2f ty=%.2f bx=%.2f by=%.2f rx=%.2f ry=%.2f owner=%s status=%s src=%s dGoal=%.2f opening=%s detour=%s pf=%d still=%d guard=%s",
                tostring(body:getActionStateName()), tostring(body:getBumpType()),
                BridgeMove.walkType, wt, stype, d, bstep, rstep, mode ~= "" and mode or "-", tostring(BridgeMove.pathing),
                tostring(needPath), tostring(stalled), BridgeMove.pathResult, BridgeMove.restarts, BridgeMove.walkSpeedVar, smod, BridgeMove.animOld and "old" or "new",
                tostring(BridgeMove.follow.kind), BridgeMove.follow.s or 0, BridgeMove.follow.gap or 0, BridgeMove.stepPerMul or 0,
                BridgeMove.follow.tx or 0, BridgeMove.follow.ty or 0, bx, by, rx, ry,
                tostring(BridgeRoute.state.owner or "-"), tostring(BridgeRoute.state.status or "-"),
                tostring(BridgeRoute.src or "-"), dGoal,
                op ~= nil and tostring(op.key) or "-",
                det ~= nil and sformat("%.1f,%.1f", det.x, det.y) or "-",
                BridgeRoute.state.pathFails or 0, BridgeRoute.state.still or 0,
                tostring(BridgeRoute.guardHit == Bridge.tick))
            if msg == BridgeRoute.traceSig then return end
            BridgeRoute.traceSig = msg
            log("trace t=" .. tostring(Bridge.tick) .. " " .. msg)
            if BridgeLog ~= nil and BridgeLog.on() then
                local st = BridgeRoute.state
                local lineF = false
                if red ~= nil then
                    pcall(function() lineF = BridgeMove.lineClear(body, red:getX(), red:getY(), red:getZ()) end)
                end
                local fields = {
                    __order = {
                        "mode", "owner", "status", "reason", "branch",
                        "body", "player", "goal", "spot", "stand", "aim", "target", "opening", "detour",
                        "d", "dGoal", "dSpot", "bestD", "age", "since", "progressAt", "pathFails", "pathFailTick",
                        "still", "checkX", "checkY", "guard", "line", "hold", "res", "restarts",
                        "path", "need", "pathing", "steering", "forceCross", "climbUntil", "pendingClimb", "cross", "door",
                        "bstep", "rstep", "ws", "smod", "anim", "fk", "fs", "ferr", "fk1", "tx", "ty", "bump", "wt", "stype" },
                    mode = mode ~= "" and mode or "-",
                    owner = st.owner,
                    status = st.status,
                    reason = st.reason,
                    branch = BridgeMove.follow ~= nil and BridgeMove.follow.kind or nil,
                    body = { x = bx, y = by, z = body:getZ() },
                    player = red ~= nil and { x = rx, y = ry } or nil,
                    goal = goal,
                    spot = st.spot,
                    stand = st.stand,
                    aim = st.aim,
                    target = st.target,
                    opening = op ~= nil and op.key or nil,
                    detour = det,
                    d = d,
                    dGoal = dGoal,
                    dSpot = st.dSpot,
                    bestD = st.bestD,
                    age = Bridge.time - (st.progressAt or Bridge.time),
                    since = st.since,
                    progressAt = st.progressAt,
                    pathFails = st.pathFails,
                    pathFailTick = st.pathFailTick,
                    still = st.still,
                    checkX = st.checkX,
                    checkY = st.checkY,
                    guard = BridgeRoute.guardHit == Bridge.tick,
                    line = lineF,
                    hold = BridgeMove.followPriorityHold == true,
                    res = BridgeMove.pathResult,
                    restarts = BridgeMove.restarts,
                    path = BridgeMove.pathing,
                    need = needPath,
                    pathing = BridgeMove.pathing,
                    steering = BridgeMove.steering,
                    forceCross = BridgeMove.forceCross,
                    climbUntil = BridgeMove.climbUntil,
                    pendingClimb = BridgeMove.pendingClimb ~= nil,
                    cross = BridgeMove.cross ~= nil,
                    door = BridgeMove.doorAct ~= nil,
                    bstep = bstep,
                    rstep = rstep,
                    ws = BridgeMove.walkSpeedVar,
                    smod = smod,
                    anim = BridgeMove.animOld and "old" or "new",
                    fk = BridgeMove.follow ~= nil and BridgeMove.follow.kind or nil,
                    fs = BridgeMove.follow ~= nil and BridgeMove.follow.s or nil,
                    ferr = BridgeMove.follow ~= nil and BridgeMove.follow.gap or nil,
                    fk1 = BridgeMove.stepPerMul,
                    tx = BridgeMove.follow ~= nil and BridgeMove.follow.tx or nil,
                    ty = BridgeMove.follow ~= nil and BridgeMove.follow.ty or nil,
                    bump = body:getBumpType(),
                    wt = wt,
                    stype = stype,
                }
                ev("route.tick", fields, "BridgeRoute.trace")
            end
        end)
    end
end

BridgeRoute.stuckState = nil
BridgeRoute.lastFollowKind = nil
BridgeRoute.compatLogAt = -9999
BridgeRoute.src = nil
BridgeRoute.srcGoal = nil

function BridgeRoute.stuckTick(body)
    if BridgeLog ~= nil and BridgeLog.on() and BridgeRoute.stuckRecoverAt ~= nil
            and not BridgeRoute.stuckRecoverChecked
            and Bridge.tick - BridgeRoute.stuckRecoverAt > 180 then
        BridgeRoute.stuckRecoverChecked = true
        local nowKey = BridgeMove.openingWay ~= nil and BridgeMove.openingWay.key or nil
        if nowKey == BridgeRoute.stuckRecoverOpening then
            BridgeLog.invariant("I7", "stuck recover unchanged opening=" .. tostring(nowKey), "warn")
        end
    end
    local S = BridgeRoute.stuckState
    if S == nil then
        S = { x = body:getX(), y = body:getY(), tick = Bridge.tick, active = false }
        BridgeRoute.stuckState = S
    end
    local moving = BridgeMove.pathing or BridgeMove.steering
    if not moving then
        if S.active then
            local dt = Bridge.tick - (S.activeAt or Bridge.tick)
            log(sformat("stuck clear after %d ticks body=%.2f,%.2f dGoal=%.2f",
                dt, body:getX(), body:getY(), S.dGoal or -1))
            if BridgeLog ~= nil and BridgeLog.on() then
                local asn = "?"
                pcall(function() asn = tostring(body:getActionStateName()) end)
                ev("route.stuck", { phase = "clear", owner = BridgeRoute.state.owner,
                    kind = BridgeMove.follow ~= nil and BridgeMove.follow.kind or nil,
                    goal = BridgeRoute.state.goal, dGoal = S.dGoal,
                    body = { x = body:getX(), y = body:getY() }, bodyZ = body:getZ(),
                    bstep = 0, still = BridgeRoute.state.still,
                    path = BridgeMove.pathing, steer = BridgeMove.steering,
                    cross = BridgeMove.cross ~= nil, climb = BridgeMove.pendingClimb ~= nil,
                    door = BridgeMove.doorAct ~= nil, asn = asn, ticks = dt,
                    spot = BridgeRoute.state.spot,
                    opening = BridgeMove.openingWay ~= nil and BridgeMove.openingWay.key or nil },
                    "BridgeRoute.stuckTick")
            end
            S.active = false
        end
        S.x, S.y, S.tick = body:getX(), body:getY(), Bridge.tick
        return
    end
    local dt = Bridge.tick - (S.tick or Bridge.tick)
    if dt < 60 then return end
    local step = dist2d(S.x, S.y, body:getX(), body:getY())
    local goal = BridgeRoute.state.goal or Bridge.target
    local dGoal = goal ~= nil and dist2d(body:getX(), body:getY(), goal.x, goal.y) or -1
    if step < 0.5 and not S.active then
        S.active = true
        S.activeAt = Bridge.tick
        S.dGoal = dGoal
        local bodyZ, asn = -1, "?"
        pcall(function() bodyZ = body:getZ() end)
        pcall(function() asn = tostring(body:getActionStateName()) end)
        if BridgeLog ~= nil and BridgeLog.on() then
            ev("route.stuck", { phase = "start", owner = BridgeRoute.state.owner,
                kind = BridgeMove.follow ~= nil and BridgeMove.follow.kind or nil,
                goal = goal, dGoal = dGoal,
                body = { x = body:getX(), y = body:getY() }, bodyZ = bodyZ,
                bstep = step / math.max(1, dt), still = BridgeRoute.state.still,
                path = BridgeMove.pathing, steer = BridgeMove.steering,
                cross = BridgeMove.cross ~= nil, climb = BridgeMove.pendingClimb ~= nil,
                door = BridgeMove.doorAct ~= nil, asn = asn, ticks = dt,
                spot = BridgeRoute.state.spot,
                opening = BridgeMove.openingWay ~= nil and BridgeMove.openingWay.key or nil },
                "BridgeRoute.stuckTick")
        end
        log(sformat("stuck start owner=%s kind=%s goal=%.1f,%.1f dGoal=%.2f body=%.2f,%.2f bodyZ=%.2f bstep=%.3f still=%d path=%s steer=%s cross=%s climb=%s door=%s asn=%s",
            tostring(BridgeRoute.state.owner or "-"),
            tostring(BridgeMove.follow ~= nil and BridgeMove.follow.kind or "-"),
            goal and goal.x or -1, goal and goal.y or -1, dGoal,
            body:getX(), body:getY(), bodyZ, step / math.max(1, dt),
            BridgeRoute.state.still or 0, tostring(BridgeMove.pathing), tostring(BridgeMove.steering),
            tostring(BridgeMove.cross ~= nil), tostring(BridgeMove.pendingClimb ~= nil),
            tostring(BridgeMove.doorAct ~= nil), asn))
    end
    if S.active and (Bridge.tick - (S.activeAt or Bridge.tick)) >= 60 then
        if step < 0.5 then
            log(sformat("stuck recover after %d ticks body=%.2f,%.2f dGoal=%.2f",
                Bridge.tick - (S.activeAt or Bridge.tick), body:getX(), body:getY(), S.dGoal or -1))
            if BridgeLog ~= nil and BridgeLog.on() then
                local asn = "?"
                pcall(function() asn = tostring(body:getActionStateName()) end)
                ev("route.stuck", { phase = "recover", owner = BridgeRoute.state.owner,
                    kind = BridgeMove.follow ~= nil and BridgeMove.follow.kind or nil,
                    goal = BridgeRoute.state.goal, dGoal = S.dGoal,
                    body = { x = body:getX(), y = body:getY() }, bodyZ = body:getZ(),
                    bstep = 0, still = BridgeRoute.state.still,
                    path = BridgeMove.pathing, steer = BridgeMove.steering,
                    cross = BridgeMove.cross ~= nil, climb = BridgeMove.pendingClimb ~= nil,
                    door = BridgeMove.doorAct ~= nil, asn = asn,
                    ticks = Bridge.tick - (S.activeAt or Bridge.tick),
                    spot = BridgeRoute.state.spot,
                    opening = BridgeMove.openingWay ~= nil and BridgeMove.openingWay.key or nil },
                    "BridgeRoute.stuckTick")
            end
            BridgeRoute.stuckRecoverAt = Bridge.tick
            BridgeRoute.stuckRecoverOpening = BridgeMove.openingWay ~= nil and BridgeMove.openingWay.key or nil
            BridgeRoute.stuckRecoverChecked = false
            pcall(function() BridgeMove.stopPath(body) end)
            BridgeRoute.state.spot = nil
            if BridgeMove.pathing and BridgeRoute.state.goal ~= nil then
                local g = BridgeRoute.state.goal
                pcall(function() BridgeRoute.detour(body, g.x, g.y, g.z or 0, BridgeRoute.state, { ticks = 150 }) end)
            end
            if BridgeMove.steering then
                BridgeMove.steering = false
                BridgeMove.pathing = false
                BridgeMove.unPathfindUntil = 0
            elseif BridgeMove.pathing then
                BridgeMove.steerMode = true
                BridgeMove.steering = true
                BridgeMove.pathing = false
                BridgeMove.unPathfindUntil = 0
            end
            BridgeRoute.noteProgress(BridgeRoute.state, "stuck")
            S.active = false
            S.x, S.y, S.tick = body:getX(), body:getY(), Bridge.tick
            return
        end
        S.active = false
    end
    S.x, S.y, S.tick = body:getX(), body:getY(), Bridge.tick
end

function BridgeRoute.logSrc(src, goal)
    local g = goal
    local now = Bridge.tick or 0
    if now - (BridgeRoute.srcLogAt or -9999) < 15 then return end
    BridgeRoute.srcLogAt = now
    BridgeRoute.src = src
    BridgeRoute.srcGoal = g ~= nil and { x = g.x, y = g.y, z = g.z } or nil
    log(sformat("resolve src=%s goal=%.1f,%.1f,%.1f", tostring(src),
        g and g.x or -1, g and g.y or -1, g and g.z or -1))
end

function BridgeRoute.diag()
    local s = BridgeRoute.state
    local goal = s.goal
    local stand = s.stand
    local opening = BridgeMove.openingWay
    local detour = s.detour
    log(sformat("diag owner=%s status=%s goal=%.1f,%.1f stand=%s target=%d,%d,%d opening=%s detour=%s stall=%d pathFails=%d sinceAge=%.1f progressAge=%.1f",
        tostring(s.owner or "-"), tostring(s.status or "-"),
        goal and goal.x or -1, goal and goal.y or -1,
        stand ~= nil and sformat("%d,%d,%d", stand.x, stand.y, stand.z) or "-",
        s.target and s.target.x or -1, s.target and s.target.y or -1, s.target and s.target.z or -1,
        opening ~= nil and tostring(opening.key) or "-",
        detour ~= nil and sformat("%.1f,%.1f", detour.x, detour.y) or "-",
        s.still or 0, s.pathFails or 0,
        Bridge.time - (s.since or Bridge.time), Bridge.time - (s.progressAt or Bridge.time)))
    if BridgeLog ~= nil and BridgeLog.on() then
        ev("route.diag", { owner = s.owner, status = s.status, goal = goal,
            stand = stand, target = s.target,
            opening = opening ~= nil and opening.key or nil, detour = detour,
            stall = s.still or 0, pathFails = s.pathFails or 0,
            sinceAge = Bridge.time - (s.since or Bridge.time),
            progressAge = Bridge.time - (s.progressAt or Bridge.time) }, "BridgeRoute.diag")
    end
end

function BridgeRoute.navInfo()
    local F = BridgeMove.follow or {}
    local nav = BridgeRoute.state
    local hold = 0
    if F.navHoldUntil ~= nil and Bridge.time < F.navHoldUntil then
        hold = math.floor(F.navHoldUntil - Bridge.time)
    end
    local detour = nav ~= nil and nav.detour or nil
    return sformat("nav=%s kind=%s status=%s reason=%s fails=%d detour=%s hold=%d holdUntil=%d",
        BridgeMove.navEnabled and "on" or "off", tostring(F.kind or "-"),
        tostring((nav ~= nil and nav.status) or F.navStatus or "-"),
        tostring(F.navReason or (nav ~= nil and nav.reason) or "-"),
        (nav ~= nil and nav.pathFails) or 0,
        detour ~= nil and sformat("%.1f,%.1f", detour.x, detour.y) or "-", hold,
        F.navHoldUntil or 0)
end

local function keepLog(F, keep, what, why, toSpot, d, redGoes)
    if Bridge == nil or not Bridge.verbose then return end
    local key = tostring(what) .. "|" .. tostring(why)
    if F.keepKey == key and F.keepSide == keep then return end
    F.keepKey, F.keepSide = key, keep
    log(sformat("keep %s%s: %s (%s) spot=%.2f player=%.2f redGoes=%s t=%d", tostring(keep),
        BridgeMove.keepFar() and " far" or "", tostring(what), tostring(why), toSpot or -1, d or -1,
        tostring(redGoes), Bridge.time))
end

local DETOUR_CLOSE = 0.9
local DETOUR_R = 1.2
local function spotDetour(rx, ry, hx, hy, bx, by, px, py, goes)
    local ax, ay = bx - rx, by - ry
    local tx, ty = px - rx, py - ry
    local sx, sy = tx - ax, ty - ay
    local l2 = sx * sx + sy * sy
    local u = 0
    if l2 > 1e-6 then u = clamp(-(ax * sx + ay * sy) / l2, 0, 1) end
    local cx, cy = ax + sx * u, ay + sy * u
    if u <= 0.05 or cx * cx + cy * cy >= DETOUR_CLOSE * DETOUR_CLOSE then return px, py end
    local ra = math.sqrt(ax * ax + ay * ay)
    if ra < 0.05 then return px, py end
    local r = math.max(ra, DETOUR_R)
    local ux, uy = ax / ra, ay / ra
    local function turn(a)
        return ux * math.cos(a) - uy * math.sin(a), ux * math.sin(a) + uy * math.cos(a)
    end
    local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
    local function ang(vx, vy) return atan2(hx * vy - hy * vx, hx * vx + hy * vy) end
    local tb, tt = ang(ax, ay), ang(tx, ty)
    local dlt = tt - tb
    while dlt > math.pi do dlt = dlt - 2 * math.pi end
    while dlt <= -math.pi do dlt = dlt + 2 * math.pi end
    local dir = (dlt >= 0) and 1 or -1
    if goes then
        local a1 = tb + dlt
        if (tb < 0 and a1 > 0) or (tb > 0 and a1 < 0) then dir = -dir end
    end
    local wx, wy = turn(dir * math.rad(60))
    return rx + wx * r, ry + wy * r
end

local function followSpot(body, red, F, pf, d, redGoes, running, keep)
    local px, py, hx, hy = BridgeMove.spotPoint(red, keep, BridgeMove.keepFar(), F, redGoes)
    if px == nil then return nil end
    local bx, by = body:getX(), body:getY()
    local toSpot = dist2d(bx, by, px, py)
    local free, why = false, "too far from the spot"
    if toSpot <= SPOT.REACH then free, why = BridgeMove.spotFree(body, red, px, py) end
    local ok = free == true
    if ok then
        F.spotOk, F.spotBad = (F.spotOk or 0) + frameDt(), 0
    else
        F.spotOk, F.spotBad = 0, (F.spotBad or 0) + frameDt()
    end
    if F.inSpot then
        if (F.spotBad or 0) >= SPOT.LEAVE then F.inSpot = false end
    elseif (F.spotOk or 0) >= SPOT.ENTER then
        F.inSpot = true
    end
    if not F.inSpot then
        keepLog(F, keep, "behind on the trail", why, toSpot, d, redGoes)
        return nil
    end
    if not ok and F.spotX ~= nil then px, py = F.spotX, F.spotY end
    F.spotX, F.spotY = px, py
    local dx, dy = px - bx, py - by
    local along = dx * hx + dy * hy
    if redGoes then
        F.spotStand = false
    elseif F.spotStand then
        if toSpot > SPOT.START then F.spotStand = false end
    elseif toSpot <= SPOT.ARRIVE then
        F.spotStand = true
    end
    if F.spotStand then
        if BridgeMove.onPath() then BridgeMove.stopPath(body) end
        BridgeMove.moving = false
        F.kind, F.s, F.want = "spot-stand", 0, 0
        if Bridge.zombieTicks % 30 == 0 then
            pcall(function() body:faceLocationF(px + hx * 3, py + hy * 3) end)
        end
        keepLog(F, keep, "stands on the spot", "arrived", toSpot, d, redGoes)
        BridgeMove.goal = { x = red:getX(), y = red:getY() }
        BridgeMove.pathResult = "follow-spot-stand"
        trackStep(body)
        BridgeRoute.trace(body, d, false, false)
        return true
    end
    BridgeMove.moving = true
    Bridge.holdPos = nil
    if BridgeMove.pathing then
        pcall(function() pf:cancel() pf:reset() body:setPath2(nil) end)
        BridgeMove.pathing = false
    end
    BridgeMove.steering = true
    local want, tx, ty
    if redGoes then
        want = BridgeMove.redSpeed * clamp(1 + 0.9 * along, 0.3, 1.8) + 0.02 * math.max(0, toSpot - 0.6)
        if toSpot < 1.5 then tx, ty = px + hx * 0.8, py + hy * 0.8 else tx, ty = px, py end
    else
        want = 0.036 * clamp(0.4 + 0.6 * toSpot, 0.35, 0.9)
        tx, ty = px, py
    end
    local doing, doingWhy = "goes to the spot", ok and "free" or ("held last spot: " .. tostring(why))
    if redGoes then
        local rx0, ry0 = bx - red:getX(), by - red:getY()
        local lon = rx0 * hx + ry0 * hy
        local lat = rx0 * (-hy) + ry0 * hx
        if lon > -0.3 and lon < 2.0 and math.abs(lat) < 0.9 then
            want = math.max(want, BridgeMove.redSpeed * 1.3, 0.035)
            doing, doingWhy = "gets out of his way", sformat("ahead %.2f side %.2f", lon, lat)
        end
    end
    local ox, oy = spotDetour(red:getX(), red:getY(), hx, hy, bx, by, tx, ty, redGoes)
    if ox ~= tx or oy ~= ty then
        if BridgeMove.lineClear(body, ox, oy, red:getZ()) then
            tx, ty = ox, oy
            want = math.max(want, BridgeMove.redSpeed * 1.3, 0.03)
            doing, doingWhy = "detour around him", "spot on his other side"
        end
    end
    keepLog(F, keep, doing, doingWhy, toSpot, d, redGoes)
    if F.aimFrame == Bridge.tick - 1 and F.aimX ~= nil and dist2d(F.aimX, F.aimY, tx, ty) < 1.5 then
        tx = F.aimX * 0.7 + tx * 0.3
        ty = F.aimY * 0.7 + ty * 0.3
    end
    F.aimX, F.aimY, F.aimFrame = tx, ty, Bridge.tick
    return drive(body, red, F, pf, bx, by, tx, ty, want, "spot-" .. keep, running, d, toSpot)
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
    if running or d > 3.5 then return capRun("Run", d) end
    if BridgeMove.walkType == "Run" and d > 2.0 then return capRun("Run", d) end
    if BridgeMove.slowDist > 0 and BridgeMove.redMoving and d < BridgeMove.slowDist then return "SlowWalk" end
    return "Walk"
end

local function pickSpeed(d)
    if BridgeMove.speedMode == "fixed" then return BridgeMove.fixedSpeed end
    if not BridgeMove.redMoving then return 1.0 end
    if d < 1.3 then return 0.8 end
    if d < 1.7 then return 0.88 end
    if d < 2.1 then return 1.1 end
    return 1.25
end

function BridgeRoute.shouldCross(body, kind, from, to)
    local safe, blockedWhy = BridgeMove.vaultSafe(body, from, to)
    if not safe then return false, blockedWhy end
    if BridgeMove.steering and not BridgeMove.forceCross then
        local yes, why, pa, pb = BridgeMove.trailCrosses(body, from, to)
        if yes then return true, why end
        if kind == "window" or kind == "frame" then
            local free = false
            pcall(function() free = to:isFree(false) == true end)
            local w = nil
            pcall(function() w = from:getWindowTo(to) end)
            if w == nil then pcall(function() w = to:getWindowTo(from) end) end
            if w == nil then pcall(function() w = from:getWindowFrameTo(to) end) end
            if w == nil then pcall(function() w = to:getWindowFrameTo(from) end) end
            local bar = false
            if w ~= nil then pcall(function() bar = w:isBarricaded() == true end) end
            local locked = false
            if w ~= nil then pcall(function() locked = w:isLocked() == true end) end
            local danger = false
            if BridgeTask ~= nil and type(BridgeTask.dangerNear) == "function" then
                pcall(function() danger = BridgeTask.dangerNear(body) == true end)
            end
            if free and not bar and not locked and not danger then return true, "safe window" end
        end
        return false, why, pa, pb
    end
    if Bridge.time < BridgeMove.noGapUntil then return true, "gap suppressed" end
    local g = BridgeMove.goal
    if g == nil then return true, "no goal" end
    local bx, by = body:getX(), body:getY()
    local ex = (from:getX() + to:getX()) / 2 + 0.5
    local ey = (from:getY() + to:getY()) / 2 + 0.5
    local over = dist2d(bx, by, ex, ey) + dist2d(ex, ey, g.x, g.y) + BridgeMove.climbCost(kind)
    local radius = math.max(1, math.floor(BridgeMove.climbCost(kind) / 2) + 1)
    local a, b = BridgeMove.passNear(body, from, to, radius)
    if a ~= nil then
        local around = dist2d(bx, by, a:getX() + 0.5, a:getY() + 0.5) + 1 + dist2d(b:getX() + 0.5, b:getY() + 0.5, g.x, g.y)
        if around < over and dist2d(b:getX() + 0.5, b:getY() + 0.5, g.x, g.y) < dist2d(bx, by, g.x, g.y) then
            return false, sformat("pass near %.1f < climb %.1f", around, over), a, b
        end
        return true, sformat("climb %.1f <= pass %.1f", over, around)
    end
    return true, "no pass near: " .. tostring(BridgeMove.passWhy)
end

function BridgeRoute.gapGoal(body)
    local g = BridgeMove.gapWay
    if g == nil then return nil end
    if math.abs(body:getZ() - g.z) >= 0.5 then BridgeMove.gapWay = nil return nil end
    local red = BridgeData.owner()
    if red ~= nil and math.abs(red:getZ() - g.z) >= 0.5 then
        BridgeMove.gapWay = nil
        if Bridge.verbose then
            log(sformat("gap cleared: player floor %.2f differs from gap %.2f", red:getZ(), g.z))
        end
        return nil
    end
    local tx, ty = g.ax, g.ay
    if g.stage == 2 then tx, ty = g.bx, g.by end
    local d = dist2d(body:getX(), body:getY(), tx, ty)
    if d < g.best - 0.2 then g.best, g.bestAt = d, Bridge.time end
    if d <= 0.5 then
        if g.stage == 1 then
            g.stage, g.best, g.bestAt = 2, math.huge, Bridge.time
            return g.bx, g.by, g.z
        end
        BridgeMove.gapWay = nil
        log("pass done")
        BridgeMove.noGapUntil = Bridge.time + 180
        return nil
    end
    if Bridge.time - g.bestAt > 180 then
        BridgeMove.gapWay = nil
        BridgeMove.noGapUntil = Bridge.time + 600
        log("pass: no progress, climbing")
        return nil
    end
    return tx, ty, g.z
end

function BridgeRoute.viaDoor(body, gx, gy, gz)
    if Bridge.time < BridgeMove.noDoorUntil then return nil end
    local bsq = body:getCurrentSquare()
    local cell = getCell()
    local tsq = cell:getGridSquare(math.floor(gx), math.floor(gy), math.floor(gz))
    if bsq == nil or tsq == nil or math.floor(body:getZ()) ~= math.floor(gz) then
        BridgeMove.doorWay = nil
        return nil
    end
    local bb, tb = BridgeMove.DOOR.buildingOf(bsq), BridgeMove.DOOR.buildingOf(tsq)
    if bb == tb then
        BridgeMove.doorWay = nil
        return nil
    end
    local way = BridgeMove.doorWay
    if way ~= nil then
        local d = dist2d(body:getX(), body:getY(), way.x, way.y)
        if d < way.best - 0.3 then way.best, way.bestAt = d, Bridge.time end
        if d <= 0.7 then
            way.reached = true
            return nil
        end
        if way.reached then
            if d > 3 then
                BridgeMove.doorWay = nil
                BridgeMove.noDoorUntil = Bridge.time + 600
            end
            return nil
        end
        if BridgeMove.walkType == "Run"
            and d + dist2d(way.x, way.y, gx, gy) > dist2d(body:getX(), body:getY(), gx, gy) + 3 then
            BridgeMove.doorWay = nil
            return nil
        end
        if Bridge.time - way.bestAt > 180 then
            log(sformat("doorWay drop why=no progress d=%.2f age=%d", d, Bridge.time - way.bestAt))
            BridgeMove.doorWay = nil
            BridgeMove.noDoorUntil = Bridge.time + 1800
            return nil
        end
        return way.x, way.y, way.z
    end
    local house = bb or tb
    local bx, by, bz = math.floor(body:getX()), math.floor(body:getY()), math.floor(body:getZ())
    local doorDetour = (BridgeMove.walkType == "Run") and 3 or 8
    local direct = dist2d(body:getX(), body:getY(), gx, gy)
    local best, bestCost = nil, math.huge
    for dx = -10, 10 do
        for dy = -10, 10 do
            local sq = cell:getGridSquare(bx + dx, by + dy, bz)
            if sq ~= nil then
                local objects = sq:getObjects()
                for i = 0, objects:size() - 1 do
                    local o = objects:get(i)
                    if BridgeMove.DOOR.isDoor(o) and BridgeMove.DOOR.usableDoor(o) then
                        local a, c = BridgeMove.DOOR.edgeSquares(o)
                        local ab, cb = BridgeMove.DOOR.buildingOf(a), c and BridgeMove.DOOR.buildingOf(c)
                        if c ~= nil and (ab == house or cb == house) and ab ~= cb then
                            local near = (ab == bb) and a or c
                            local nx, ny = near:getX() + 0.5, near:getY() + 0.5
                            local cost = dist2d(body:getX(), body:getY(), nx, ny) + dist2d(nx, ny, gx, gy)
                            if cost < bestCost and cost <= direct + doorDetour then
                                best, bestCost = { x = nx, y = ny, z = bz }, cost
                            end
                        end
                    end
                end
            end
        end
    end
    if best == nil then return nil end
    best.best = math.huge
    best.bestAt = Bridge.time
    BridgeMove.doorWay = best
    log(sformat("doorWay set=%d,%d d=%.2f", best.x, best.y,
        dist2d(body:getX(), body:getY(), best.x, best.y)))
    return best.x, best.y, best.z
end

function BridgeRoute.openingWay(body, gx, gy, gz)
    if BridgeDoors == nil or BridgeDoors.enclosureKey == nil or BridgeDoors.findOpening == nil then return nil end
    local bsq = nil
    pcall(function() bsq = body:getCurrentSquare() end)
    if bsq == nil then BridgeMove.openingWay = nil return nil end
    local bz = math.floor(gz)
    if math.floor(body:getZ()) ~= bz then BridgeMove.openingWay = nil return nil end
    local cell = getCell()
    local tsq = cell:getGridSquare(math.floor(gx), math.floor(gy), bz)
    if tsq == nil then BridgeMove.openingWay = nil return nil end
    local bK, tK = -1, -1
    pcall(function() bK = BridgeDoors.enclosureKey(bsq) end)
    pcall(function() tK = BridgeDoors.enclosureKey(tsq) end)
    local cur = BridgeMove.openingWay
    local sticky = false
    if cur ~= nil and cur.x ~= nil then
        local d = dist2d(body:getX(), body:getY(), cur.x, cur.y)
        local farD = cur.far ~= nil and dist2d(gx, gy, cur.far:getX() + 0.5, cur.far:getY() + 0.5) or math.huge
        local nearD = dist2d(gx, gy, cur.x, cur.y)
        sticky = d <= 2.0 and farD < nearD and (Bridge.time - (cur.bestAt or Bridge.time)) <= 240
    end
    local function enclosureEv(branch, force)
        if BridgeLog == nil or not BridgeLog.on() then return end
        local bx, by, bz = bsq:getX(), bsq:getY(), bsq:getZ()
        local tx, ty, tz = tsq:getX(), tsq:getY(), tsq:getZ()
        local bRoom, tRoom = -1, -1
        pcall(function() if bsq:getRoom() ~= nil then bRoom = bsq:getRoomID() end end)
        pcall(function() if tsq:getRoom() ~= nil then tRoom = tsq:getRoomID() end end)
        local bldId = nil
        pcall(function() bldId = BridgeDoors.buildingId(bsq) end)
        local sig = tostring(bK) .. "|" .. tostring(tK) .. "|" .. math.floor(bx) .. "," .. math.floor(by)
        local now = Bridge.tick or 0
        if not force and BridgeRoute.enclSig == sig and (now % 15) ~= 0 then return end
        BridgeRoute.enclSig = sig
        ev("route.enclosure", {
            bsq = { x = bx, y = by, z = bz }, bsq_room = bRoom, bsq_bld = bK,
            gsq = { x = tx, y = ty, z = tz }, gsq_room = tRoom, gsq_bld = tK,
            bK = bK, tK = tK, same = bK == tK, leaving = bK ~= -1 and tK ~= bK,
            bld_id = bldId, why = branch }, "BridgeRoute.openingWay")
    end
    local function stateEv(branch, ret)
        if BridgeLog == nil or not BridgeLog.on() then return end
        local curPlan = BridgeMove.openingWay
        local dCur, farDist, atFar = nil, nil, false
        if curPlan ~= nil and curPlan.x ~= nil then
            dCur = dist2d(body:getX(), body:getY(), curPlan.x, curPlan.y)
        end
        if curPlan ~= nil and curPlan.far ~= nil then
            farDist = dist2d(body:getX(), body:getY(), curPlan.far:getX() + 0.5, curPlan.far:getY() + 0.5)
            atFar = bsq:getX() == curPlan.far:getX() and bsq:getY() == curPlan.far:getY()
        end
        local phase = "none"
        if curPlan ~= nil then phase = curPlan.arrived and "cross" or "approach" end
        ev("route.opening.state", {
            branch = branch, phase = phase, ret = ret,
            bK = bK, tK = tK,
            bsq = { x = bsq:getX(), y = bsq:getY(), z = bsq:getZ() },
            curArrived = curPlan ~= nil and curPlan.arrived == true,
            curBest = curPlan ~= nil and curPlan.best or nil,
            curBestAt = curPlan ~= nil and curPlan.bestAt or nil,
            curX = curPlan ~= nil and curPlan.x or nil,
            curY = curPlan ~= nil and curPlan.y or nil,
            curFar = curPlan ~= nil and curPlan.far ~= nil and { x = curPlan.far:getX(), y = curPlan.far:getY() } or nil,
            d = dCur, farDist = farDist, atFar = atFar,
            doorPassed = BridgeMove.DOOR ~= nil and BridgeMove.DOOR.PASSED or nil,
            sticky = sticky,
        }, "BridgeRoute.openingWay")
    end
    enclosureEv("enter")
    if bK == tK then
        stateEv("sameEnclosure", "nil")
        BridgeMove.openingWay = nil
        BridgeMove.openingBlocked = nil
        BridgeMove.doorFail = nil
        local sameSig = tostring(bK) .. "|" .. tostring(tK) .. "|"
            .. math.floor(body:getX()) .. "," .. math.floor(body:getY())
        local now = Bridge.tick or 0
        if BridgeRoute.sameEnclSig ~= sameSig or (now % 15) == 0 then
            BridgeRoute.sameEnclSig = sameSig
            log(sformat("openingWay skip=sameEnclosure bK=%s tK=%s sticky=%s body=%.1f,%.1f goal=%.1f,%.1f",
                tostring(bK), tostring(tK), tostring(sticky), body:getX(), body:getY(), gx, gy))
            if BridgeLog ~= nil and BridgeLog.on() then
                ev("route.opening", { action = "skip", bK = bK, tK = tK, leaving = false,
                    reason = "sameEnclosure" }, "BridgeRoute.openingWay")
            end
        end
        return nil
    end
    local leaving = bK ~= -1 and tK ~= bK
    local building = nil
    if leaving then
        pcall(function() building = BridgeDoors.buildingOf(bsq) end)
    elseif tK ~= -1 then
        pcall(function() building = BridgeDoors.buildingOf(tsq) end)
    end
    if building == nil then
        if sticky then
            if cur.arrived and cur.kind == "door" and cur.far ~= nil then
                return cur.far:getX() + 0.5, cur.far:getY() + 0.5, cur.far:getZ()
            end
            return cur.x, cur.y, cur.z
        end
        BridgeMove.openingWay = nil
        enclosureEv("noBuilding", true)
        return nil
    end

    local way = BridgeMove.openingWay
    if way ~= nil and not sticky and way.bld ~= (leaving and bK or tK) then way = nil BridgeMove.openingWay = nil end
    if way ~= nil then
        enclosureEv("reuse")
        if way.arrived then
            if Bridge.time - (way.arrivedAt or Bridge.time) > 480 then
                stateEv("reuse-timeout", "nil")
                BridgeMove.openingWay = nil
                return nil
            end
            local obj = way.obj
            if obj ~= nil and way.kind == "window" then
                local frame = false
                pcall(function() frame = instanceof(obj, "IsoWindowFrame") end)
                if frame then
                    if BridgeMove.pendingClimb == nil and (Bridge.time - (way.climbAt or -9999) > 30) then
                        way.climbAt = Bridge.time
                        pcall(function() body:faceLocationF(way.x, way.y) end)
                        BridgeMove.askClimb(body, "frame", obj)
                        log("window frame climb at " .. tostring(way.key))
                    end
                    stateEv("reuse-arrived-frame", "near")
                    return way.x, way.y, way.z
                end
                local isOpen, blocked = false, false
                pcall(function() isOpen = obj:IsOpen() == true or obj:isSmashed() == true end)
                pcall(function() blocked = obj:isBarricaded() == true or obj:isPermaLocked() == true end)
                if not isOpen then
                    if blocked then
                        BridgeMove.DOOR.blacklistDoor(body, obj, "barricade")
                        stateEv("reuse-arrived-window", "near")
                        return way.x, way.y, way.z
                    end
                    if way.openAt == nil then
                        way.openAt = Bridge.time
                        pcall(function()
                            body:faceLocationF(way.x, way.y)
                            body:setVariable("BumpAnimFinished", false)
                            body:setBumpType("WindowOpen")
                        end)
                        log("window opening at " .. tostring(way.key))
                    elseif way.openAt < 1.0e15 and Bridge.time - way.openAt > 20 then
                        way.openAt = 1.0e16
                        pcall(function() obj:ToggleWindow(body) end)
                        pcall(function() body:playSound("OpenWindow") end)
                        local nowOpen = false
                        pcall(function() nowOpen = obj:IsOpen() == true or obj:isSmashed() == true end)
                        if not nowOpen then
                            BridgeMove.DOOR.blacklistDoor(body, obj, "locked")
                        else
                            BridgeMove.noteWindowOpened(body, obj)
                            log("window opened, climbing " .. tostring(way.key))
                        end
                    end
                elseif BridgeMove.pendingClimb == nil and (Bridge.time - (way.climbAt or -9999) > 30) then
                    if BridgeMove.glassStep(body, obj) then
                        way.climbAt = Bridge.time
                        pcall(function() body:faceLocationF(way.x, way.y) end)
                        BridgeMove.askClimb(body, "window", obj)
                        log("window climb at " .. tostring(way.key))
                    end
                end
                stateEv("reuse-arrived-window", "near")
                return way.x, way.y, way.z
            elseif obj ~= nil and way.kind == "door" then
                local isOpen = false
                pcall(function() isOpen = obj:IsOpen() == true end)
                if not isOpen then
                    if not BridgeMove.openDoor(body, obj) then
                        stateEv("reuse-arrived-door", "nil")
                        return nil
                    end
                end
                if way.far ~= nil then
                    stateEv("reuse-arrived-door", "far")
                    return way.far:getX() + 0.5, way.far:getY() + 0.5, way.far:getZ()
                end
                stateEv("reuse-arrived-door", "nil")
                return nil
            end
            return nil
        end
        local d = dist2d(body:getX(), body:getY(), way.x, way.y)
        if d < (way.best or math.huge) - 0.3 then way.best, way.bestAt = d, Bridge.time end
        if d <= 0.9 then
            way.arrived = true
            way.arrivedAt = Bridge.time
            stateEv("reuse-arrive", "nil")
            return nil
        end
        if Bridge.time - way.bestAt > 240 then
            if dist2d(body:getX(), body:getY(), way.x, way.y) <= 1.5 then
                log("opening waypoint: no progress at the opening, blacklisting")
                if way.obj ~= nil then pcall(function() BridgeMove.DOOR.blacklistDoor(body, way.obj, "no progress") end) end
            else
                log("opening waypoint: no progress away from the opening, detouring")
                pcall(function() BridgeRoute.detour(body, gx, gy, body:getZ(), BridgeRoute.state, { ticks = 150 }) end)
            end
            stateEv("reuse-noprogress", "nil")
            BridgeMove.openingWay = nil
            return nil
        end
        stateEv("reuse", "near")
        return way.x, way.y, way.z
    end

    BridgeMove.DOOR.pruneBadDoors()
    log(sformat("openingWay run bK=%s tK=%s leaving=%s building=%s body=%.1f,%.1f goal=%.1f,%.1f",
        tostring(bK), tostring(tK), tostring(leaving), tostring(building), body:getX(), body:getY(), gx, gy))
    if BridgeLog ~= nil and BridgeLog.on() then
        ev("route.opening", { action = "run", bK = bK, tK = tK, leaving = leaving },
            "BridgeRoute.openingWay")
    end
    local plan = nil
    local avoid = BridgeMove.badDoors or nil
    pcall(function()
        plan = BridgeDoors.findOpening(building, bz, body:getX(), body:getY(), gx, gy, leaving, true, avoid)
    end)
    if plan == nil or plan.near == nil then
        enclosureEv("noPlan")
        local any = 0
        pcall(function() any = #BridgeDoors.exteriorOpenings(building, bz) end)
        if (any > 0 or BridgeMove.doorFail ~= nil) and not Bridge.follow then
            local reason = BridgeMove.doorFail
            if reason == nil then
                reason = "locked"
                pcall(function()
                    for _, d in ipairs(BridgeDoors.exteriorOpenings(building, bz)) do
                        local bar = false
                        pcall(function() bar = d.obj:isBarricaded() == true end)
                        if bar then reason = "barricade" break end
                    end
                end)
            end
            BridgeMove.openingBlocked = reason
            log(sformat("opening none bld=%s z=%d from=%.1f,%.1f to=%.1f,%.1f leaving=%s candidates=%d reason=%s",
                tostring(building), bz, body:getX(), body:getY(), gx, gy, tostring(leaving), any, tostring(reason)))
            if BridgeLog ~= nil and BridgeLog.on() then
                ev("route.opening", { action = "none", bK = bK, tK = tK, leaving = leaving,
                    reason = reason }, "BridgeRoute.openingWay")
            end
        else
            log(sformat("opening none bld=%s z=%d from=%.1f,%.1f to=%.1f,%.1f leaving=%s candidates=%d reason=-",
                tostring(building), bz, body:getX(), body:getY(), gx, gy, tostring(leaving), any))
            if BridgeLog ~= nil and BridgeLog.on() then
                ev("route.opening", { action = "none", bK = bK, tK = tK, leaving = leaving },
                    "BridgeRoute.openingWay")
            end
        end
        stateEv("none", "nil")
        return nil
    end
    BridgeMove.openingBlocked = nil
    BridgeMove.doorFail = nil
    enclosureEv("select")
    if plan.obj ~= nil and plan.obj == BridgeMove.doorLoopDoor
            and Bridge.time < (BridgeMove.doorLoopUntil or 0) then
        log("opening loop ignored at " .. tostring(plan.key))
        if BridgeLog ~= nil and BridgeLog.on() then
            ev("route.opening", { action = "loop", key = plan.key }, "BridgeRoute.openingWay")
        end
        stateEv("loop", "nil")
        BridgeMove.openingWay = nil
        return nil
    end
    local nx, ny = plan.near:getX() + 0.5, plan.near:getY() + 0.5
    BridgeMove.openingWay = { x = nx, y = ny, z = bz, key = plan.key, bld = leaving and bK or tK,
        obj = plan.obj, kind = plan.kind, far = plan.far,
        best = math.huge, bestAt = Bridge.time }
    if BridgeRoute.stuckRecoverAt ~= nil and BridgeRoute.stuckRecoverOpening ~= plan.key then
        BridgeRoute.stuckRecoverAt = nil
    end
    local doors, wins = 0, 0
    pcall(function()
        for _, d in ipairs(BridgeDoors.exteriorOpenings(building, bz)) do
            if d.kind == "door" then doors = doors + 1 else wins = wins + 1 end
        end
    end)
    log(string.format("opening route %s key=%s near=%d,%d far=%d,%d t=%d doors=%d wins=%d",
        tostring(plan.kind), tostring(plan.key), plan.near:getX(), plan.near:getY(), plan.far:getX(), plan.far:getY(),
        math.floor(Bridge.time or 0), doors, wins))
    if BridgeLog ~= nil and BridgeLog.on() then
        ev("route.opening", { action = "route", bK = bK, tK = tK, leaving = leaving,
            key = plan.key, near = { x = plan.near:getX(), y = plan.near:getY() },
            far = { x = plan.far:getX(), y = plan.far:getY() }, doors = doors, wins = wins },
            "BridgeRoute.openingWay")
    end
    pcall(function()
        log("openings: " .. tostring(BridgeDoors.debugOpenings(building, bz, leaving)))
    end)
    stateEv("select", "near")
    return nx, ny, bz
end

function BridgeRoute.followPolicy(body)
    local red = BridgeData.owner()
    if red == nil or Bridge.target ~= nil then
        BridgeMove.setCollide(body, true)
        BridgeMove.endFollowBump(body, "")
        return false
    end
    if BridgeGunfight ~= nil and BridgeGunfight.reposition ~= nil then
        return true
    end
    local F = BridgeMove.follow

    if F.pathUntil ~= nil and Bridge.time < F.pathUntil then
        local at = F.stuckAt
        local left = at ~= nil and Bridge.time >= (F.pathMin or 0)
            and dist2d(at.x, at.y, body:getX(), body:getY()) >= at.leave

        if not left and at ~= nil and Bridge.time >= (F.pathMin or 0) and Bridge.every(10)
            and dist2d(body:getX(), body:getY(), red:getX(), red:getY()) <= 2.0
            and BridgeMove.lineClear(body, red:getX(), red:getY(), red:getZ()) then
            left = true
        end
        if not left then
            F.kind = "stuck-path"
            BridgeMove.setCollide(body, true)
            BridgeMove.endFollowBump(body, "")
            return false
        end
        F.pathUntil = nil
        BridgeMove.holdEnginePath(body)
        if Bridge.verbose then
            log(sformat("stuck path done after %d ticks at %.2f %.2f", Bridge.time - at.tick, body:getX(), body:getY()))
        end
    end

    local stairs = false
    pcall(function()
        if math.abs(body:getZ() - red:getZ()) > 0.3 then stairs = true return end
        local a, b = body:getCurrentSquare(), red:getCurrentSquare()
        if a ~= nil and a.HasStairs ~= nil and (a:HasStairs() or (b ~= nil and b:HasStairs())) then stairs = true end
    end)
    if stairs then F.stairsUntil = Bridge.time + 30 end
    if Bridge.time < (F.stairsUntil or 0) then
        if F.kind ~= "path-stairs" and Bridge.verbose then
            local bStairs, rStairs = false, false
            pcall(function()
                local bs = body:getCurrentSquare()
                local rs = red:getCurrentSquare()
                if bs ~= nil and bs.HasStairs ~= nil then bStairs = bs:HasStairs() == true end
                if rs ~= nil and rs.HasStairs ~= nil then rStairs = rs:HasStairs() == true end
            end)
            log(sformat("stairs: engine path (her z %.2f, his z %.2f, bodyStairs=%s redStairs=%s until=%d)",
                body:getZ(), red:getZ(), tostring(bStairs), tostring(rStairs), F.stairsUntil or 0))
        end
        F.kind = "path-stairs"
        BridgeMove.setCollide(body, true)
        BridgeMove.endFollowBump(body, "")
        if BridgeMove.steering then
            BridgeMove.steering = false
            BridgeMove.pathing = false
        end
        return false
    end

    if F.navHoldUntil ~= nil then
        if Bridge.time < F.navHoldUntil then
            F.kind = "nav-hold"
            BridgeMove.setCollide(body, true)
            BridgeMove.endFollowBump(body, "")
            BridgeMove.moving = false
            if BridgeMove.onPath() then BridgeMove.stopPath(body) end
            if BridgeMove.steering then
                BridgeMove.steering = false
                BridgeMove.pathing = false
            end
            if Bridge.tick % 30 == 0 then
                pcall(function() body:faceLocationF(red:getX(), red:getY()) end)
            end
            if Bridge.verbose and F.navHoldLog ~= F.navHoldUntil then
                F.navHoldLog = F.navHoldUntil
                log(sformat("nav hold: %s%s", tostring(F.navStatus or "hold"),
                    F.navReason ~= nil and (", " .. tostring(F.navReason)) or ""))
            end
            return true
        end
        F.navHoldUntil = nil
        F.navReason = nil
        F.navHoldLog = nil
        F.navStatus = "ok"
        BridgeRoute.state.pathFails = 0
    end

    if BridgeMove.gapWay ~= nil then
        F.kind = "path"
        BridgeMove.holdEnginePath(body)
        BridgeMove.setCollide(body, true)
        BridgeMove.endFollowBump(body, "")
        if BridgeMove.steering then
            BridgeMove.steering = false
            BridgeMove.pathing = false
        end
        return false
    end

    if Bridge.time < (F.awayUntil or 0) then
        F.kind = "path-away"
        return false
    end

    local tx, ty, tz, kind, along
    local cache = F.cache
    if cache ~= nil and (Bridge.time - cache.tick) < 4 and cache.body == body then
        tx, ty, tz, kind = cache.x, cache.y, cache.z, cache.kind
        if tx ~= nil then
            local rx, ry = red:getX(), red:getY()
            if kind == "player" then tx, ty = rx, ry end
            along = dist2d(body:getX(), body:getY(), tx, ty) + (kind == "player" and 0 or cache.tail)
        end
    else
        tx, ty, tz, kind, along = BridgeMove.followTarget(body, red)
        local tail = 0
        if tx ~= nil and kind ~= "player" then tail = along - dist2d(body:getX(), body:getY(), tx, ty) end
        F.cache = { tick = Bridge.time, body = body, x = tx, y = ty, z = tz, kind = kind, tail = tail }
    end

    local nav = BridgeRoute.state
    if nav ~= nil and nav.detour ~= nil then
        local det = nav.detour
        local bx0, by0 = body:getX(), body:getY()
        local dx0, dy0 = bx0 - det.x, by0 - det.y
        local near = math.sqrt(dx0 * dx0 + dy0 * dy0) <= 0.5
        if kind == "player" or Bridge.time > (det.expires or 0)
                or math.abs(body:getZ() - (det.z or body:getZ())) > 0.5 or near then
            nav.detour = nil
        else
            tx, ty, tz, kind = det.x, det.y, det.z or tz, "detour"
            along = dist2d(bx0, by0, tx, ty)
            F.engineHold = nil
        end
    end

    if F.engineHold ~= nil then
        local H = F.engineHold
        local hx, hy = body:getX(), body:getY()
        local keep = kind ~= "player"
        local why = "sees player"
        if keep and Bridge.time >= H.checkAt then
            if dist2d(H.x, H.y, hx, hy) < 1.0 then keep, why = false, "no progress" end
            H.x, H.y, H.checkAt = hx, hy, Bridge.time + 120
        end
        if keep then
            F.kind = "path-hold"
            BridgeMove.setCollide(body, true)
            BridgeMove.endFollowBump(body, "")
            if BridgeMove.steering then
                BridgeMove.steering = false
                BridgeMove.pathing = false
            end
            return false
        end
        if Bridge.verbose then
            log(sformat("engine path released after %d ticks: %s", Bridge.time - H.tick, why))
        end
        if why ~= "no progress" then F.detourFails = nil end
        if why == "no progress" then
            F.detourFails = F.detourFails or 0
            if F.detourFails >= 2 then
                F.detourFails = nil
                F.engineHold = nil
                F.kind = "path"
                BridgeMove.holdEnginePath(body)
                BridgeMove.setCollide(body, true)
                BridgeMove.endFollowBump(body, "")
                if BridgeMove.steering then
                    BridgeMove.steering = false
                    BridgeMove.pathing = false
                end
                if Bridge.verbose then
                    log(sformat("follow detour: 2 failed detours at %.2f,%.2f, engine path",
                        body:getX(), body:getY()))
                end
                return false
            end
            local dnav = BridgeRoute.state
            local p = nil
            if dnav ~= nil then
                p = BridgeRoute.detour(body, red:getX(), red:getY(), body:getZ(), dnav,
                    { step = NAV.DETOUR_STEP, ticks = NAV.DETOUR_TICKS,
                      passable = function(px, py, pz)
                          return BridgeMove.edgeOnLine(body, px + 0.5, py + 0.5, pz, 8) == nil
                      end })
            end
            if p ~= nil then
                F.detourFails = F.detourFails + 1
                dnav.status = "detour"
                tx, ty, tz, kind = p.x, p.y, p.z, "detour"
                along = dist2d(body:getX(), body:getY(), tx, ty)
                if Bridge.verbose then
                    log(sformat("follow detour: no progress at %.2f,%.2f, going to %.1f,%.1f",
                        body:getX(), body:getY(), tx, ty))
                end
            else
                F.detourFails = nil
                if Bridge.verbose then
                    log(sformat("follow detour: none available at %.2f,%.2f",
                        body:getX(), body:getY()))
                end
            end
        end
        F.engineHold = nil
    end
    if tx == nil then
        F.kind = "path"
        BridgeMove.holdEnginePath(body)
        BridgeMove.setCollide(body, true)
        BridgeMove.endFollowBump(body, "")
        if BridgeMove.steering then
            BridgeMove.steering = false
            BridgeMove.pathing = false
        end
        return false
    end
    local pf = body:getPathFindBehavior2()
    local d = dist2d(body:getX(), body:getY(), red:getX(), red:getY())
    local redGoes = BridgeMove.redMoving or BridgeMove.redSpeed > 0.012
    local running = false
    local okRun, rv = pcall(red.isRunning, red)
    if okRun then running = rv == true end
    if not running then
        local okSprint, sv = pcall(red.isSprinting, red)
        if okSprint then running = sv == true end
    end

    local walk = (running or along > 4) and "Run" or "Walk"
    if BridgeMove.walkType == "Run" and not running and along > 2.5 then walk = "Run" end
    BridgeMove.walkType = walk

    local extra = keepExtra()
    local gap = (walk == "Run" and GAP_RUN or GAP_WALK) + extra

    if Bridge.verbose and redGoes then
        F.gapSum, F.gapWant, F.gapN = (F.gapSum or 0) + d, (F.gapWant or 0) + gap, (F.gapN or 0) + 1
        if d < gap - 0.5 then F.gapClose = (F.gapClose or 0) + 1 end
        if kind ~= "player" then F.gapNoLine = (F.gapNoLine or 0) + 1 end
        if F.gapKind ~= nil and F.gapKind ~= F.kind then F.gapSwitch = (F.gapSwitch or 0) + 1 end
        F.gapKind = F.kind
        if Bridge.time - (F.gapLog or 0) >= 300 and F.gapN >= 120 then
            log(sformat("gap %s %s: walked at %.2f, asked %.2f, closer than asked by 0.5+ in %d%% of %d frames, speed scale %.2f (%d samples), no line %d%%, kind switches %d",
                BridgeMove.keepFar() and "far" or "near", walk, F.gapSum / F.gapN, F.gapWant / F.gapN,
                math.floor(100 * (F.gapClose or 0) / F.gapN + 0.5), F.gapN, BridgeMove.speedScale, BridgeMove.speedScaleN,
                math.floor(100 * (F.gapNoLine or 0) / F.gapN + 0.5), F.gapSwitch or 0))
            F.gapSum, F.gapWant, F.gapN, F.gapClose, F.gapLog = 0, 0, 0, 0, Bridge.time
            F.gapNoLine, F.gapSwitch = 0, 0
        end
    end

    local keep = BridgeMove.keepSide()
    if keep ~= "behind" then
        local done = followSpot(body, red, F, pf, d, redGoes, running, keep)
        if done ~= nil then return done end
    elseif F.inSpot then
        BridgeMove.spotReset()
    end

    local bx, by = body:getX(), body:getY()
    local sameFloor = math.abs(body:getZ() - red:getZ()) < 0.5
    local A = F.asideTo
    if A ~= nil then
        if sameFloor and Bridge.time < A.untilT and dist2d(bx, by, A.x, A.y) > 0.25 and F.cross == nil then
            return BridgeMove.stepAside(body, F, A, d)
        end
        F.asideTo = nil
        F.asideQuiet = Bridge.time + ASIDE.QUIET

        BridgeMove.moving = false
        if Bridge.verbose then log(sformat("aside done at %.2f %.2f, %.2f from player", bx, by, d)) end
    end

    local pushing = false
    local fx, fy = 0, 0
    pcall(function() pushing = red:isPlayerMoving() == true end)
    if pushing then
        fx, fy = BridgeMove.pushDir(red)
    elseif redGoes then
        fx, fy, pushing = BridgeMove.redVx or 0, BridgeMove.redVy or 0, true
    end

    local coming = false
    if pushing and d > 0.01 then
        local vl = math.sqrt(fx * fx + fy * fy)
        if vl > 0.001 then
            coming = (fx * (bx - red:getX()) + fy * (by - red:getY())) / (vl * d) > COMING_COS
        end
    end

    local backCalm = (BridgeFight == nil or BridgeFight.state == nil or BridgeFight.state == "idle")
        and (BridgeGunfight == nil or BridgeGunfight.state == nil or BridgeGunfight.state == "idle")
    local backOk = Bridge.backEnabled ~= false and backCalm and F.passing ~= true
        and sameFloor
        and Bridge.time >= (F.backQuiet or 0)
        and (F.pathUntil == nil or Bridge.time >= F.pathUntil)
        and BridgeMove.cross == nil and F.cross == nil and Bridge.pose == nil
    if F.back ~= nil then
        if not backOk or not (pushing and coming) then
            BridgeMove.backEnd(body, F, backOk and "player stopped" or "busy", d)
        elseif BridgeMove.backTick(body, F, red) then
            return true
        end
    elseif backOk and pushing and coming and kind == "player" and d <= ASIDE.AHEAD + ASIDE.PATH then
        local line = nil
        if running then
            line = BridgeMove.onRunLine(bx, by, red:getX(), red:getY(), fx, fy)
        else
            line = BridgeMove.onHisPath(bx, by, red:getX(), red:getY(), fx, fy)
        end
        if line ~= nil and BridgeMove.backStart(body, F, red, fx, fy, d) then
            if BridgeMove.backTick(body, F, red) then return true end
        end
    end

    if running and kind == "player" and sameFloor and F.asideTo == nil and Bridge.time > (F.asideQuiet or 0) then
        local ra, rs, rux, ruy = BridgeMove.onRunLine(bx, by, red:getX(), red:getY(), fx, fy)
        if ra ~= nil and ra > 0 then
            local nx, ny = -ruy, rux
            if rs < 0 then nx, ny = -nx, -ny end
            local tries = { { bx + nx * ASIDE.STEP, by + ny * ASIDE.STEP, "side" },
                            { bx - nx * ASIDE.STEP, by - ny * ASIDE.STEP, "other side" } }
            for _, t in ipairs(tries) do
                if BridgeMove.lineClear(body, t[1], t[2], tz) then
                    F.asideTo = { x = t[1], y = t[2], untilT = Bridge.time + ASIDE.MAX }
                    F.cross = nil
                    if Bridge.verbose then
                        log(sformat("aside %s: player runs at her, %.2f ahead, %.2f off his line", t[3], ra, rs))
                    end
                    return BridgeMove.stepAside(body, F, F.asideTo, d)
                end
            end
        end
    end

    local canPush = pushing and kind == "player" and sameFloor and d < ASIDE.AHEAD + ASIDE.PATH and F.cross == nil
    local ahead, side, ux, uy = nil, nil, nil, nil
    if canPush then ahead, side, ux, uy = BridgeMove.onHisPath(bx, by, red:getX(), red:getY(), fx, fy) end

    if ahead ~= nil then
        F.pushSeen = Bridge.time
    elseif F.pushSeen == nil or Bridge.time - F.pushSeen > PUSH_GRACE then
        F.pushSince = nil
    end

    if Bridge.verbose and d < ASIDE.AHEAD + ASIDE.PATH then
        local why
        if ahead ~= nil then why = "pushing"
        elseif not pushing then why = "not pressing"
        elseif kind ~= "player" then why = "no line to him (" .. tostring(kind) .. ")"
        elseif F.cross ~= nil then why = "crossing"
        elseif not sameFloor then why = "other floor"
        else
            local vl = math.sqrt(fx * fx + fy * fy)
            local al, sd = 0, 0
            if vl > 0.01 then
                local ox, oy = bx - red:getX(), by - red:getY()
                al, sd = (fx * ox + fy * oy) / vl, (-fy * ox + fx * oy) / vl
            end
            why = sformat("off his path (%.2f ahead, %.2f aside)", al, sd)
        end
        local cat = why:match("^[%a ]+")
        if cat ~= F.pushWhy then
            F.pushWhy = cat
            log(sformat("push check at %.2f: %s", d, why))
        end
    elseif F.pushWhy ~= nil then
        F.pushWhy = nil
    end
    if ahead ~= nil then
        F.pushSince = F.pushSince or Bridge.time

        if Bridge.time - F.pushSince >= ASIDE.PUSH then
            F.pushSince = nil

            if Bridge.time > (F.asideQuiet or 0) then
                local nx, ny = -uy, ux
                if side < 0 then nx, ny = -nx, -ny end
                local tries = { { bx + nx * ASIDE.STEP, by + ny * ASIDE.STEP, "side" },
                                { bx - nx * ASIDE.STEP, by - ny * ASIDE.STEP, "other side" } }
                for _, t in ipairs(tries) do
                    if BridgeMove.lineClear(body, t[1], t[2], tz) then
                        F.asideTo = { x = t[1], y = t[2], untilT = Bridge.time + ASIDE.MAX }
                        if Bridge.verbose then
                            log(sformat("aside %s: player walks into her, %.2f ahead, %.2f off his line", t[3], ahead, side))
                        end
                        return BridgeMove.stepAside(body, F, F.asideTo, d)
                    end
                end
            end

            BridgeMove.passThrough(body, true, sformat("player keeps pushing, %s (%.2f ahead)",
                Bridge.time > (F.asideQuiet or 0) and "no room aside" or "just stepped aside", ahead))
        end
    end

    local sees = kind == "player"
    local stopAt = STOP_GAP + extra
    local why = nil
    if not redGoes then
        if not sees and extra > 0 then stopAt, why = STOP_GAP, "no line to player" end
        if along > DOORWAY.STOP and BridgeMove.inDoorway(body) then
            local room = true
            if sees and d > 0.001 then
                local k = DOORWAY.ROOM / d
                local qx, qy = red:getX() + (body:getX() - red:getX()) * k, red:getY() + (body:getY() - red:getY()) * k
                room = not BridgeMove.doorwayCell(math.floor(qx), math.floor(qy), math.floor(body:getZ()))
            end
            if room then stopAt, why = DOORWAY.STOP, "in a doorway" end
        end
    end
    if why ~= F.stopWhy then
        F.stopWhy = why
        if Bridge.verbose and why ~= nil then
            log(sformat("stand rule: %s, stops at %.2f instead of %.2f (d %.2f, along %.2f)", why, stopAt, STOP_GAP + extra, d, along))
        end
    end

    if not BridgeMove.moving then
        if coming then
            if d > START_DIST + extra then
                BridgeMove.moving = true
                Bridge.holdPos = nil
            end
        elseif along > START_DIST + extra or (redGoes and along > START_GOING + extra) then
            BridgeMove.moving = true
            Bridge.holdPos = nil
        elseif why ~= nil and along > stopAt + 0.8 then
            BridgeMove.moving = true
            Bridge.holdPos = nil
        end
    elseif not redGoes and along <= stopAt + 0.05 then
        BridgeMove.moving = false
    elseif coming and d <= START_DIST + extra then
        BridgeMove.moving = false
        if Bridge.verbose then log(sformat("stands: player comes at her, d %.2f", d)) end
    end
    BridgeMove.applyAnimVars(body)
    if not BridgeMove.moving then
        if BridgeMove.onPath() then BridgeMove.stopPath(body) end
        F.cross = nil
        F.kind, F.s, F.want = "stand", 0, 0
        if Bridge.zombieTicks % 30 == 0 then
            pcall(function() body:faceLocationF(red:getX(), red:getY()) end)
        end
        trackStep(body)
        BridgeRoute.trace(body, d, false, false)
        return true
    end

    local function quenchPath()
        if BridgeMove.pathing then
            pcall(function() pf:cancel() pf:reset() body:setPath2(nil) end)
            BridgeMove.pathing = false
            BridgeMove.goal = nil
        end
    end
    BridgeMove.steering = true
    local bx2, by2 = body:getX(), body:getY()
    local px, py = tx, ty
    local err, want
    if redGoes then
        if kind == "player" and along - d < 0.4 then
            px, py = red:getX(), red:getY()
        else
            local qx, qy = BridgeMove.trailPoint(red, gap)
            if BridgeMove.lineClear(body, qx, qy, tz) then
                px, py = qx, qy
                kind = kind == "player" and "rope" or kind
            end
        end
        err = (d < gap) and (d - gap) or (along - gap)

        if sees then F.noLine = 0 else F.noLine = (F.noLine or 0) + frameDt() end
        if (sees or F.noLine < NO_LINE_FRAMES) and (px - bx2) * (red:getX() - bx2) + (py - by2) * (red:getY() - by2) <= 0 then
            px, py = red:getX(), red:getY()
        end
        want = BridgeMove.redSpeed * clamp(1 + 0.7 * err, 0.3, 1.7)

        if BridgeMove.catchUp and err > CATCH_FROM then
            local run = BridgeMove.speedModel.Run
            local runStep = (run.a + run.b * 0.65) * BridgeMove.speedScale
            want = math.max(want, runStep * clamp((err - CATCH_FROM) / (CATCH_FULL - CATCH_FROM), 0, 1))
        end

        local stepNow = BridgeMove.redStep or 0
        if stepNow < 0.35 * BridgeMove.redSpeed and err < 0.4 then
            want = math.min(want, math.max(stepNow, 0.25 * want))
        end
    else
        if kind == "player" then
            local k = d > 0.001 and math.max(0, d - stopAt) / d or 0
            px, py = bx2 + (tx - bx2) * k, by2 + (ty - by2) * k
        end
        err = along - stopAt
        local base = BridgeMove.bumpMove == "face" and 0.036 * BridgeMove.speedScale or BridgeMove.stepPerMul
        want = base * clamp(0.4 + 0.5 * err, 0.25, 0.9)
    end

    local yieldNow = redGoes and sees and (
        (F.kind == "yield" and d < stopAt + 0.4) or (F.kind ~= "yield" and d < stopAt - 0.4)
    )
    if yieldNow then
        quenchPath()
        BridgeMove.endFollowBump(body, "Stand")
        BridgeMove.setCollide(body, true)
        BridgeMove.steering = false
        F.cross = nil
        F.kind, F.s, F.want = "yield", 0, 0
        trackStep(body)
        BridgeRoute.trace(body, d, false, false)
        return true
    end

    do
        local minStep = BridgeMove.speedModel.Walk.a * BridgeMove.speedScale
        if redGoes and BridgeMove.redSpeed < minStep * SLOW.RED then
            F.slowFrames = (F.slowFrames or 0) + frameDt()
        else
            F.slowFrames = 0
        end
        local slowRed = F.slowFrames >= SLOW.FRAMES
        if not slowRed then
            F.slowWait = nil
        elseif F.slowWait then
            if err > SLOW.GO then F.slowWait = nil end
        elseif err <= 0 then
            F.slowWait = true
        end
        if F.slowWait then
            quenchPath()
            BridgeMove.endFollowBump(body, "Stand")
            BridgeMove.setCollide(body, true)
            BridgeMove.steering = false
            F.kind, F.s, F.want = "slow-wait", 0, 0
            trackStep(body)
            BridgeRoute.trace(body, d, false, false)
            return true
        end
    end

    if redGoes and err <= 0 and (BridgeMove.redStep or 0) < 0.35 * BridgeMove.redSpeed
        and want < 0.5 * BridgeMove.speedModel.Walk.a * BridgeMove.speedScale then
        quenchPath()
        BridgeMove.endFollowBump(body, "Stand")
        BridgeMove.setCollide(body, true)
        BridgeMove.steering = false
        F.kind, F.s, F.want = "hold", 0, 0
        trackStep(body)
        BridgeRoute.trace(body, d, false, false)
        return true
    end

    local rx0, ry0 = red:getX(), red:getY()
    if dist2d(px, py, rx0, ry0) > d + 0.6 then
        if BridgeMove.lineClear(body, rx0, ry0, tz) then
            px, py, kind = rx0, ry0, "player"
        elseif kind == "detour" then
            BridgeRoute.state.detour = nil
            px, py, kind = rx0, ry0, "player"
            if Bridge.verbose then
                log(sformat("detour dropped: farther from player, heading to player %.2f %.2f", px, py))
            end
        else
            if F.kind ~= "path-away" and Bridge.verbose then
                log(sformat("path-away: goal %.2f %.2f is farther from player than she is (d %.2f), no line to player, engine path", px, py, d))
            end
            F.kind = "path-away"
            F.awayUntil = Bridge.time + 30
            BridgeMove.holdEnginePath(body)
            BridgeMove.endFollowBump(body, "")
            BridgeMove.steering = false
            BridgeMove.setCollide(body, true)
            return false
        end
    end
    quenchPath()

    if F.aimFrame == Bridge.tick - 1 and F.aimX ~= nil and dist2d(F.aimX, F.aimY, px, py) < 1.5 then
        px = F.aimX * 0.7 + px * 0.3
        py = F.aimY * 0.7 + py * 0.3
    end
    F.aimX, F.aimY, F.aimFrame = px, py, Bridge.tick

    local nx, ny, narrow = BridgeMove.throughNarrow(body, px, py)
    if narrow then
        px, py = nx, ny
        kind = kind .. "-narrow"
    end

    local navKind = tostring(kind)
    if navKind:sub(-7) == "-narrow" then navKind = navKind:sub(1, -8) end
    local pursuing = navKind == "player" or navKind == "rope" or navKind == "trail"
        or navKind == "stuck-path" or navKind:sub(1, 4) == "path"
    local nav2 = BridgeRoute.state
    if nav2 ~= nil then
        if nav2.detour ~= nil and Bridge.time > (nav2.detour.expires or 0) then nav2.detour = nil end
        if not pursuing then
            nav2.checkX, nav2.checkY = nil, nil
            nav2.still = 0
        end
    end
    if nav2 ~= nil and pursuing and BridgeMove.moving
            and BridgeMove.cross == nil and BridgeMove.pendingClimb == nil
            and BridgeMove.doorAct == nil and BridgeMove.window == nil then
        MEM.followStallOpts = MEM.followStallOpts or { ticks = NAV.STALL_TICKS, move = NAV.STALL_MOVE }
        if BridgeRoute.stall(body, nav2, MEM.followStallOpts) == "stalled" then
            local point = BridgeRoute.detour(body, math.floor(px), math.floor(py), tz, nav2,
                { step = NAV.DETOUR_STEP, ticks = NAV.DETOUR_TICKS,
                  passable = function(dx, dy, dz)
                      return BridgeMove.edgeOnLine(body, dx + 0.5, dy + 0.5, dz, 8) == nil
                  end })
            if point ~= nil then
                px, py = point.x, point.y
                kind = "detour"
                nav2.status = "detour"
                if Bridge.verbose and Bridge.time - (F.navLogAt or -9999) >= 120 then
                    F.navLogAt = Bridge.time
                    log(sformat("nav: stalled, detour to %.1f %.1f", px, py))
                end
            else
                local bx3, by3 = body:getX(), body:getY()
                F.stuckAt = { x = bx3, y = by3, tick = Bridge.time, leave = STUCK_LEAVE }
                F.pathMin = Bridge.time + 60
                F.pathUntil = Bridge.time + 240
                nav2.status = "path"
                nav2.still = 0
                nav2.checkX, nav2.checkY = nil, nil
                BridgeMove.steering = false
                BridgeMove.setCollide(body, true)
                BridgeMove.endFollowBump(body, "")
                if Bridge.verbose and Bridge.time - (F.navLogAt or -9999) >= 120 then
                    F.navLogAt = Bridge.time
                    log(sformat("nav: stalled at %.2f %.2f, engine path", bx3, by3))
                end
                return false
            end
        end
    end
    return drive(body, red, F, pf, bx2, by2, px, py, want, kind, running, d, err)
end

local SEAT = { STAY = 4, RING_MAX = 4, ARRIVE = 0.3, NEAR = 0.7, GAP = 0.25, EDGE = 0.15,
    GIVE_UP = 360, DOWN_MAX = 180, NEAR_GOAL = 2.5 }

function BridgeRoute.seatStep(body)
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
    local bcx, bcy = BridgeMove.cellOf(bx, by)
    local inside = sameZ and BridgeMove.inSeatZone(zones, bcx, bcy)
    local rcx, rcy = BridgeMove.cellOf(red:getX(), red:getY())

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
        if S.placed then return BridgeMove.seatStand(body, red, d) end
        S.placed = true
        if BridgeMove.lineClear(BridgeMove.seatFrom(red, zones), bx, by, zones.z) then
            local gap = BridgeMove.zoneGap(zones, bx, by)
            if gap >= SEAT.EDGE then return BridgeMove.seatStand(body, red, d) end

            S.spot, S.path, S.spotSince, S.away, S.awayDone = { x = bcx, y = bcy, ring = cells }, false, Bridge.time, nil, true
            S.spotGiveUp = Bridge.time + 120
            log(sformat("seat: at the edge of his zone (gap %.2f), stepping into %d,%d", gap, bcx, bcy))
        else
            local spot, checked = BridgeMove.seatSpot(red, zones, bx, by, body, S.bad)
            if spot == nil or (spot.x == bcx and spot.y == bcy) then
                log(sformat("seat: out of his sight at %d,%d, %s, staying", bcx, bcy,
                    spot == nil and ("no spot (" .. checked .. " cells checked)") or "no better spot"))
                return BridgeMove.seatStand(body, red, d)
            end
            S.spot, S.path, S.spotSince, S.away, S.awayDone = spot, false, Bridge.time, nil, false
            spot.forSight = true
            S.spotGiveUp = Bridge.time + SEAT.GIVE_UP + math.floor(60 * dist2d(bx, by, spot.x + 0.5, spot.y + 0.5))
            log(sformat("seat: out of his sight, %d cells, going once to %d,%d (ring %d, %d cells checked, d=%.2f)",
                cells, spot.x, spot.y, spot.ring, checked, d))
        end
    end

    if S.spot ~= nil and (BridgeMove.inSeatZone(zones, S.spot.x, S.spot.y) or not BridgeMove.seatCellOk(S.spot.x, S.spot.y, zones.z)) then
        log(sformat("seat: spot %d,%d no longer fits (player %s)", S.spot.x, S.spot.y, zones.why))
        S.spot, S.path = nil, false
    end
    if S.spot == nil and Bridge.time < (S.retryAt or 0) then return BridgeMove.seatStand(body, red, d) end
    if S.spot == nil then
        local spot, checked = BridgeMove.seatSpot(red, zones, bx, by, body, S.bad)
        if spot == nil then
            S.retryAt = Bridge.time + 60
            if not S.noSpot then
                S.noSpot = true
                log(sformat("seat: no free spot 2-%d cells from player (%d cells checked), staying%s",
                    SEAT.RING_MAX, checked, inside and " in the way" or ""))
            end
            return BridgeMove.seatStand(body, red, d)
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
    if nearOk and S.spot.forSight and not BridgeMove.lineClear(BridgeMove.seatFrom(red, zones), bx, by, zones.z) then nearOk = false end
    if sameZ and (toSpot <= SEAT.ARRIVE or nearOk) then
        log(sformat("seat: at %d,%d after %d ticks, %d cells from player", S.spot.x, S.spot.y,
            Bridge.time - S.spotSince, math.max(math.abs(S.spot.x - rcx), math.abs(S.spot.y - rcy))))
        S.spot, S.path = nil, false
        return BridgeMove.seatStand(body, red, d)
    end
    if Bridge.time > (S.spotGiveUp or (S.spotSince + SEAT.GIVE_UP)) then
        S.bad[S.spot.x .. "," .. S.spot.y] = true
        log(sformat("seat: %d,%d not reached in %d ticks, another spot", S.spot.x, S.spot.y, Bridge.time - S.spotSince))
        S.spot, S.path = nil, false
        return BridgeMove.seatStand(body, red, d)
    end
    local F = BridgeMove.follow
    local pf = body:getPathFindBehavior2()
    Bridge.holdPos = nil
    BridgeMove.moving = true
    local wx, wy, stepping = BridgeMove.routeAround(S, body, red, zones.z, px, py, d)
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
        BridgeMove.freshDrive(F)
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

function BridgeRoute.asideStep(body)
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
    BridgeMove.freshDrive(BridgeMove.follow)
    if drive(body, red, BridgeMove.follow, pf, bx, by, t.x, t.y, want, "aside", false, d, toSpot) then return true end
    t.path = true
    log(sformat("seat: stuck stepping aside to %d,%d, engine path", t.cellX, t.cellY))
    BridgeMove.steering = false
    return false
end

local function sameTarget(a, b)
    if a == nil or b == nil then return false end
    return a.x == b.x and a.y == b.y and a.z == b.z
end

function BridgeRoute.standFor(body, target, targetSq, kind, onTarget, sameFloor)
    if target == nil then return nil end
    if sameFloor == false then return { x = target.x, y = target.y, z = target.z } end
    if onTarget then return { x = target.x, y = target.y, z = target.z } end
    if BridgeTask ~= nil and type(BridgeTask.reachSpot) == "function" then
        return BridgeTask.reachSpot(body, targetSq, target)
    end
    return nil
end

function BridgeRoute.resolve(spec)
    local body = spec.body
    local target = spec.target
    local targetSq = spec.targetSq
    local stand = spec.stand
    if stand == nil then stand = BridgeRoute.state.stand end
    if stand == nil then
        stand = BridgeRoute.standFor(body, target, targetSq, spec.kind, spec.onTarget, spec.sameFloor)
    end
    BridgeRoute.state.stand = stand
    local gx, gy, gz
    if stand ~= nil then
        gx, gy, gz = stand.x, stand.y, stand.z
    elseif spec.onTarget or spec.sameFloor == false then
        gx, gy, gz = target.x, target.y, target.z
    else
        BridgeRoute.state.goal = nil
        return nil
    end
    BridgeRoute.state.goal = { x = gx, y = gy, z = gz }
    BridgeRoute.logSrc(stand ~= nil and "stand" or "direct", BridgeRoute.state.goal)
    return BridgeRoute.state.goal
end

function BridgeRoute.arrived(body, spec)
    local target = spec.target
    local targetSq = spec.targetSq
    local tx, ty = target.x, target.y
    local bodyZ = math.floor(body:getZ())
    local sameFloor = targetSq == nil or math.floor(targetSq:getZ()) == bodyZ
    local clearOk = spec.clearFn or BridgeTask.adjacentClear
    local d = math.sqrt((body:getX() - (tx + 0.5)) ^ 2 + (body:getY() - (ty + 0.5)) ^ 2)
    if sameFloor and d <= (spec.reach or 0) and (not spec.reachClear or clearOk(body, targetSq)) then
        return true
    end
    return false
end

function BridgeRoute.request(spec)
    if spec == nil or spec.body == nil or type(spec.target) ~= "table" then
        return "unreachable", "badTarget"
    end
    local target = spec.target
    local tx, ty, tz = tonumber(target.x), tonumber(target.y), tonumber(target.z)
    if tx == nil or ty == nil or tz == nil then return "unreachable", "badTarget" end
    local owner = spec.owner or "job"
    local state = BridgeRoute.state
    local switched = false
    if state.owner ~= owner or not sameTarget(state.target, target) then
        BridgeRoute.reset()
        state = BridgeRoute.state
        state.owner = owner
        state.target = { x = tx, y = ty, z = tz }
        state.mode = spec.mode
        switched = true
    end
    local body = spec.body
    local targetSq = nil
    pcall(function() targetSq = getCell():getGridSquare(tx, ty, tz) end)
    spec.targetSq = targetSq
    spec.sameFloor = targetSq == nil or math.floor(targetSq:getZ()) == math.floor(body:getZ())
    if switched then
        log(sformat("req owner=%s target=%d,%d,%d reach=%.1f onTarget=%s sameFloor=%s body=%.1f,%.1f,%.1f",
            tostring(owner), tx, ty, tz, tonumber(spec.reach) or -1, tostring(spec.onTarget == true),
            tostring(spec.sameFloor), body:getX(), body:getY(), body:getZ()))
    end
    if BridgeRoute.arrived(body, spec) then
        state.status = "arrived"
        Bridge.target = nil
        return "arrived", nil
    end
    local goal = BridgeRoute.resolve(spec)
    if goal == nil then
        state.status = "unreachable"
        return "unreachable", nil
    end
    state.status = "walking"
    return "walking", nil
end

function BridgeRoute.syncCompat()
    local s = BridgeRoute.state
    if BridgeTask == nil then return end
    BridgeTask.spot = s.spot
    BridgeTask.since = s.since
    BridgeTask.progressAt = s.progressAt
    BridgeTask.bestD = s.bestD
    BridgeTask.still = s.still
    BridgeTask.checkX = s.checkX
    BridgeTask.checkY = s.checkY
    BridgeTask.pathFails = s.pathFails
    BridgeTask.pathFailTick = s.pathFailTick
    BridgeTask.openingRef = s.openingRef
    BridgeTask.openingKey = s.openingKey
    BridgeTask.openingTries = s.openingTries
    BridgeTask.openingSince = s.openingSince
    BridgeTask.detour = s.detour
end

function BridgeRoute.syncFromCompat()
    local s = BridgeRoute.state
    if BridgeTask == nil then return end
    local changed = nil
    local function take(name, v)
        if v ~= s[name] then
            s[name] = v
            changed = changed or {}
            changed[#changed + 1] = name
        end
    end
    take("progressAt", BridgeTask.progressAt)
    take("since", BridgeTask.since)
    take("bestD", BridgeTask.bestD)
    take("still", BridgeTask.still)
    take("checkX", BridgeTask.checkX)
    take("checkY", BridgeTask.checkY)
    take("pathFails", BridgeTask.pathFails)
    take("pathFailTick", BridgeTask.pathFailTick)
    take("detour", BridgeTask.detour)
    if changed ~= nil and Bridge.tick - (BridgeRoute.compatLogAt or -9999) >= 60 then
        BridgeRoute.compatLogAt = Bridge.tick
        log("compat overwrite " .. table.concat(changed, ","))
        if BridgeLog ~= nil and BridgeLog.on() then
            ev("route.progress", { progressAt = s.progressAt, since = s.since, bestD = s.bestD,
                dSpot = s.dSpot, still = s.still, pathFails = s.pathFails,
                verdict = s.status or "-", refresh_reason = "compat",
                changed_fields = table.concat(changed, ",") }, "BridgeRoute.syncFromCompat")
        end
    end
end

function BridgeRoute.jobPolicy(body, spec)
    local state = BridgeRoute.state
    BridgeRoute.syncFromCompat()
    local target = spec.target
    local tx, ty, tz = tonumber(target.x), tonumber(target.y), tonumber(target.z)
    local bodyZ = math.floor(body:getZ())
    local targetSq = spec.targetSq
    local sameFloor = spec.sameFloor
    local clearOk = spec.clearFn or BridgeTask.adjacentClear
    local reach = spec.reach or 0
    local onTarget = spec.onTarget
    local opts = spec.opts or {}

    local d = math.sqrt((body:getX() - (tx + 0.5)) ^ 2 + (body:getY() - (ty + 0.5)) ^ 2)
    if sameFloor and d <= reach and (not spec.reachClear or clearOk(body, targetSq)) then
        state.openingRef, state.openingKey, state.openingTries = nil, nil, nil
        state.openingSince = nil
        Bridge.target = nil
        BridgeRoute.syncCompat()
        return "arrived", nil
    end

    BridgeTask.noteWindowAttempts(body)
    if BridgeTask.windowLoopKey ~= nil then
        BridgeTask.info = "window loop"
        return "unreachable", "windowLoop"
    end

    if BridgeMove ~= nil and BridgeMove.openingBlocked ~= nil then
        local why = BridgeMove.openingBlocked
        BridgeMove.openingBlocked = nil
        BridgeTask.info = "openings exhausted"
        BridgeTask.routeAbort("openingBlocked", why, body, target)
        return "unreachable", why
    end

    local openStatus, openReason = BridgeRoute.opening(state, {
        giveUp = BridgeTask.OPENING_GIVE_UP, target = target })
    if openStatus == "stale" and (BridgeMove == nil or BridgeMove.pathResult ~= "Succeeded") then
        BridgeTask.info = "opening unreachable"
        BridgeTask.routeAbort("openingStale", openReason, body, target)
        return "unreachable", openReason
    end

    if sameFloor and not BridgeTask.reachOk(body, targetSq) then
        BridgeTask.info = "no accessible opening"
        local why = BridgeRoute.blockedReason(target)
        BridgeTask.routeAbort("reach", why, body, target)
        return "unreachable", why
    end

    if not sameFloor then
        if state.spot == nil or math.floor(state.spot.z or target.z) ~= math.floor(target.z) then
            state.spot = { x = target.x, y = target.y, z = target.z }
        end
    elseif onTarget then
        state.spot = { x = target.x, y = target.y, z = target.z }
    elseif state.spot == nil then
        state.spot = BridgeRoute.standFor(body, target, targetSq, spec.kind, false, sameFloor)
        if state.spot == nil then
            BridgeTask.info = "no reachable spot"
            log(string.format("no spot for target %d,%d,%d (body z=%s) bx=%.1f by=%.1f",
                target.x, target.y, target.z, tostring(bodyZ), body:getX(), body:getY()))
            log("  neighbours: " .. BridgeTask.spotDump(target))
            BridgeTask.routeAbort("noSpot", nil, body, target)
            BridgeRoute.syncCompat()
            return "unreachable", nil
        end
        log(string.format("spot %d,%d,%d for target %d,%d,%d bodyBld=%s tgtBld=%s spotBld=%s bx=%.2f by=%.2f bodyZ=%d",
            state.spot.x, state.spot.y, state.spot.z, target.x, target.y, target.z,
            BridgeTask.buildingIdAt(math.floor(body:getX()), math.floor(body:getY()), bodyZ),
            BridgeTask.buildingIdAt(target.x, target.y, target.z),
            BridgeTask.buildingIdAt(state.spot.x, state.spot.y, state.spot.z),
            body:getX(), body:getY(), bodyZ))
    end

    local sx, sy = state.spot.x + 0.5, state.spot.y + 0.5
    local dSpot = math.sqrt((body:getX() - sx) ^ 2 + (body:getY() - sy) ^ 2)
    local wx, wy = sx, sy
    local detour = state.detour
    if detour ~= nil then
        local dd = math.sqrt((body:getX() - detour.x) ^ 2 + (body:getY() - detour.y) ^ 2)
        if Bridge.time > (detour.expires or 0) or dd <= 1.0 then
            state.detour = nil
            detour = nil
        end
    end
    if detour ~= nil then
        wx, wy = detour.x, detour.y
        BridgeRoute.noteProgress(state, "detour")
    elseif not onTarget then
        local ndx, ndy = (target.x + 0.5) - sx, (target.y + 0.5) - sy
        local nlen = math.sqrt(ndx * ndx + ndy * ndy)
        if nlen > 0.05 then
            wx = sx + (ndx / nlen) * BridgeTask.SPOT_NUDGE
            wy = sy + (ndy / nlen) * BridgeTask.SPOT_NUDGE
        end
    end
    if sameFloor and dSpot <= (onTarget and reach or BridgeTask.STOP_DIST)
            and (not spec.reachClear or clearOk(body, targetSq)) then
        state.openingRef, state.openingKey, state.openingTries = nil, nil, nil
        state.openingSince = nil
        Bridge.target = nil
        BridgeRoute.syncCompat()
        return "arrived", nil
    end

    if state.bestD == nil or dSpot < state.bestD - 0.3 then
        state.bestD = dSpot
        BridgeRoute.noteProgress(state, "bestD")
        state.pathFails = 0
    end

    if BridgeMove ~= nil and BridgeMove.openingWay ~= nil then
        BridgeRoute.noteProgress(state, "opening")
        state.pathFails = 0
    end

    local pathStatus = BridgeRoute.notePathFail(state, { limit = BridgeTask.PATH_FAIL_LIMIT })
    if pathStatus == "failed" then
        BridgeTask.info = "no path to target"
        local why = BridgeRoute.blockedReason(target)
        BridgeTask.routeAbort("pathFail", why, body, target)
        BridgeRoute.syncCompat()
        return "unreachable", why
    end

    local progress = BridgeRoute.progress(state, {
        noProgress = opts.noProgress ~= nil and opts.noProgress or BridgeTask.WALK_NO_PROGRESS,
        timeout = opts.timeout ~= nil and opts.timeout or BridgeTask.WALK_TIMEOUT,
        onSpot = function() return sameFloor and BridgeTask.playerOnSquare(state.spot) end })
    if progress == "waiting" then
        BridgeTask.info = "waiting for player"
        BridgeRoute.syncCompat()
        return "walking", nil
    elseif progress == "timeout" then
        BridgeTask.info = "no progress to target"
        local why = BridgeRoute.blockedReason(target)
        BridgeTask.routeAbort("progress", why, body, target)
        BridgeRoute.syncCompat()
        return "unreachable", why
    end

    local stall = BridgeRoute.stall(body, state, {
        ticks = BridgeTask.STALL_TICKS,
        move = 0.3,
        exempt = function()
            return BridgeMove.cross ~= nil or BridgeMove.doorAct ~= nil
                or BridgeMove.window ~= nil or BridgeMove.pendingClimb ~= nil
        end,
        onSpot = function() return sameFloor and BridgeTask.playerOnSquare(state.spot) end })
    if stall == "waiting" then
        BridgeTask.info = "waiting for player"
        BridgeRoute.syncCompat()
        return "walking", nil
    elseif stall == "stalled" then
        local point, dpx, dpy = BridgeRoute.detour(body, target.x, target.y, target.z, state,
            { step = 1.6, ticks = 150 })
        if point ~= nil then
            local stallExtra = ""
            if BridgeTask.kind == "openDoors" or BridgeTask.kind == "closeDoors" then
                local fromSq = nil
                pcall(function() fromSq = body:getCurrentSquare() end)
                local standSq = nil
                if target.x ~= nil and target.y ~= nil and target.z ~= nil then
                    pcall(function() standSq = getCell():getGridSquare(target.x, target.y, target.z) end)
                end
                local blockedTo = false
                if fromSq ~= nil and standSq ~= nil then
                    pcall(function() blockedTo = fromSq:isBlockedTo(standSq) == true end)
                end
                local isDoor = BridgeTask.current ~= nil and target.x == BridgeTask.current.x and target.y == BridgeTask.current.y
                stallExtra = string.format(" from=%s stand=%d,%d standIsDoor=%s blockedTo=%s dStand=%.2f",
                    fromSq ~= nil and (fromSq:getX() .. "," .. fromSq:getY()) or "-",
                    target.x, target.y, tostring(isDoor), tostring(blockedTo), BridgeTask.doorDebugDist(body, standSq))
            end
            log(string.format("stalled: stepping around via %d,%d%s", dpx, dpy, stallExtra))
        else
            log("stalled: no safe detour")
        end
        if state.spot ~= nil then
            local key = state.spot.x .. "," .. state.spot.y
            BridgeTask.stallKey = BridgeTask.stallKey or {}
            BridgeTask.stallKey[key] = (BridgeTask.stallKey[key] or 0) + 1
            if BridgeTask.stallKey[key] >= 2 then
                BridgeTask.badSpots = BridgeTask.badSpots or {}
                BridgeTask.badSpots[key] = true
            end
        end
        state.spot = nil
        BridgeRoute.noteProgress(state, "stall_detour")
        pcall(function() BridgeMove.stopPath(body) end)
        if BridgeTask.forceIdle ~= nil then BridgeTask.forceIdle(body) end
        BridgeTask.info = "stalled, re-pathing"
        BridgeRoute.syncCompat()
        return "walking", nil
    end

    BridgeTask.phase = "walk"

    Bridge.target = { x = wx, y = wy, z = target.z }
    state.aim = Bridge.target
    state.dSpot = dSpot
    state.d = d
    BridgeRoute.syncCompat()
    return "walking", nil
end

function BridgeRoute.jobPath(body, spec)
    local state = BridgeRoute.state
    BridgeMove.setCollide(body, true)
    if BridgeMove.steering then
        BridgeMove.endFollowBump(body, "")
        BridgeMove.steering = false
        BridgeMove.pathing = false
        BridgeMove.wasWalking = false
    end
    local t = Bridge.target
    local gx, gy, gz, d = nil, nil, nil, nil
    if t ~= nil then
        gx, gy, gz = t.x, t.y, t.z
        d = dist2d(body:getX(), body:getY(), t.x, t.y)
    end
    if gx ~= nil then
        local wx, wy, wz = nil, nil, nil
        pcall(function() wx, wy, wz = BridgeRoute.openingWay(body, gx, gy, gz) end)
        if wx ~= nil then
            gx, gy, gz = wx, wy, wz
            BridgeRoute.logSrc("opening", { x = gx, y = gy, z = gz })
        else
            local px, py, pz = nil, nil, nil
            pcall(function() px, py, pz = BridgeRoute.gapGoal(body) end)
            if px ~= nil then
                gx, gy, gz = px, py, pz
                BridgeRoute.logSrc("gap", { x = gx, y = gy, z = gz })
            else
                BridgeRoute.logSrc("direct", { x = gx, y = gy, z = gz })
            end
        end
    end
    if gx == nil then
        BridgeMove.wasWalking = false
        if BridgeMove.onPath() then BridgeMove.stopPath(body) end
        return
    end
    if Bridge.target ~= nil and Bridge.target.x ~= nil and Bridge.target.y ~= nil then
        local zeroD = dist2d(body:getX(), body:getY(), gx, gy)
        local targetD = dist2d(body:getX(), body:getY(), Bridge.target.x, Bridge.target.y)
        if zeroD <= 0.9 and targetD > 0.9 then
            log(sformat("jobPath zero-length goal=%.2f,%.2f target=%.2f,%.2f body=%.2f,%.2f src=%s",
                gx, gy, Bridge.target.x, Bridge.target.y, body:getX(), body:getY(),
                BridgeMove.openingWay ~= nil and "opening" or "direct"))
        end
    end

    local arrived = d <= 0.8
    local tgt = Bridge.target
    if tgt ~= nil and tgt.cellX ~= nil then
        arrived = d <= 0.7 and math.floor(body:getX()) == tgt.cellX and math.floor(body:getY()) == tgt.cellY
    end
    if arrived and math.abs(gz - body:getZ()) < 0.3 then
        local onPath = BridgeMove.onPath()
        if Bridge.verbose and onPath then
            log(sformat("job arrived: d=%.2f gz=%.2f bodyZ=%.2f", d, gz, body:getZ()))
        end
        if onPath then BridgeMove.stopPath(body) end
        Bridge.target = nil
        return
    end

    BridgeMove.walkType = pickWalkType(d)
    BridgeMove.applyAnimVars(body)

    if Bridge.target ~= nil and BridgeTask ~= nil and BridgeTask.active
            and BridgeMove.cross == nil and BridgeMove.pendingClimb == nil and BridgeMove.doorAct == nil then
        local ekind, eobject, efrom, eto = BridgeMove.edgeOnLine(body, gx, gy, gz, 6)
        if ekind == "tall" and BridgeMove.beyondEdge(efrom, eto, gx, gy, 0) then
            BridgeMove.goal = { x = gx, y = gy }
            BridgeMove.walkType = "Walk"
            if BridgeRoute.shouldCross(body, ekind, efrom, eto) then
                local ex = efrom:getX() + 0.5 + (eto:getX() - efrom:getX()) * 0.5
                local ey = efrom:getY() + 0.5 + (eto:getY() - efrom:getY()) * 0.5
                BridgeMove.setCollide(body, true)
                BridgeMove.followWs = 0.4
                BridgeMove.applyAnimVars(body)
                BridgeMove.followBump(body, "Walk")
                pcall(function() BridgeMove.turnToward(body, ex, ey, 180) end)
                pcall(function() body:getPathFindBehavior2():moveToPoint(ex, ey, 0.5) end)
                BridgeMove.pathing = true
                BridgeMove.climbUntil = Bridge.time + 20
                BridgeMove.pathResult = "job-approach"
                trackStep(body)
                return
            end
        end
    end

    if BridgeMove.pathing then
        local okObs, busy = pcall(function() return BridgeMove.handleObstacle(body) end)
        if not okObs then BridgeMove.obstacle = "error: " .. tostring(busy) end
        if okObs and busy then
            log(sformat("obstacle=%s pathing=%s steering=%s body=%.2f,%.2f goal=%.1f,%.1f busy=%s",
                tostring(BridgeMove.obstacle), tostring(BridgeMove.pathing), tostring(BridgeMove.steering),
                body:getX(), body:getY(), gx or -1, gy or -1, tostring(busy)))
            return
        end
    end

    local pf = body:getPathFindBehavior2()

    local function pathEv(why)
        if BridgeLog == nil or not BridgeLog.on() then return end
        local asn, bump, bpf, bmv = "-", "-", false, false
        pcall(function()
            asn = tostring(body:getActionStateName())
            bump = tostring(body:getBumpType())
            bpf = body:getVariableBoolean("bPathfind") == true
            bmv = body:getVariableBoolean("bMoving") == true
        end)
        local collided, collidedDoor, collidedFrame = false, false, false
        pcall(function()
            collided = body:isCollided() == true
            collidedDoor = body:isCollidedWithDoor() == true
            collidedFrame = body:isCollidedThisFrame() == true
        end)
        local plen = -1
        if type(pf.getPathLength) == "function" then
            local ok, n = pcall(function() return pf:getPathLength() end)
            if ok and tonumber(n) ~= nil then plen = tonumber(n) end
        end
        local bstep, rstep = 0, 0
        local last = BridgeRoute.traceLast
        if last ~= nil then
            local frames = math.max(1, (Bridge.tick or 0) - last.t)
            bstep = dist2d(last.bx, last.by, body:getX(), body:getY()) / frames
            local red = BridgeData.owner()
            if red ~= nil then rstep = dist2d(last.rx, last.ry, red:getX(), red:getY()) / frames end
        end
        ev("move.path", { asn = asn, bump = bump, bPathfind = bpf, bMoving = bmv,
            pf_target = BridgeMove.goal, pf_result = BridgeMove.pathResult, pf_stopped = not BridgeMove.pathing,
            path_len = plen, bstep = bstep, rstep = rstep, collided = collided,
            collidedDoor = collidedDoor, collidedFrame = collidedFrame,
            goal = { x = gx, y = gy }, why = why }, "BridgeRoute.jobPath")
    end

    local replan = true
    if BridgeMove.goal ~= nil then
        replan = dist2d(BridgeMove.goal.x, BridgeMove.goal.y, gx, gy) > BridgeMove.replanDist
    end
    local function startPath()
        BridgeMove.lastPath = Bridge.time
        local bump = ""
        pcall(function() bump = tostring(body:getBumpType()) end)
        local asnNow = ""
        pcall(function() asnNow = tostring(body:getActionStateName()) end)
        local ramp = bump == BridgeMove.KICK
        local onTheMove = (Bridge.time - BridgeMove.stepTick) < 10
        if not ramp and not onTheMove and (bump == "Stand" or asnNow == "idle" or asnNow == "bumped"
            or (not BridgeMove.pathing and (not BridgeMove.wasWalking or BridgeMove.startBump == "on"))) then
            BridgeMove.startKick(body)
        end
        pf:pathToLocationF(gx, gy, gz)
        BridgeMove.goal = { x = gx, y = gy }
        BridgeMove.pathing = true
        log(sformat("path start body=%.1f,%.1f goal=%.1f,%.1f", body:getX(), body:getY(), gx, gy))
        pathEv("start")
    end

    local stalled = false
    if BridgeMove.redMoving and BridgeMove.pathing
        and (Bridge.time - BridgeMove.lastPath) >= 12 then
        pcall(function() stalled = (body:getActionStateName() == "idle") end)
    end

    local failedRecently = BridgeMove.lastFailed ~= nil and (Bridge.time - (BridgeMove.lastFailedAt or -9999)) < BridgeMove.pathEvery
    local every = BridgeMove.walkType == "Run" and BridgeMove.runEvery or BridgeMove.pathEvery
    local needPath = (not BridgeMove.pathing and not failedRecently) or stalled
        or (replan and (Bridge.time - BridgeMove.lastPath) >= every)
    if needPath then startPath() end
    local res = pf:update()
    BridgeMove.kickStep(body, pf)
    BridgeMove.pathResult = tostring(res)
    if res == BehaviorResult.Succeeded or res == BehaviorResult.Failed then
        BridgeMove.pathing = false
        if res == BehaviorResult.Failed then BridgeMove.lastFailed = Bridge.tick BridgeMove.lastFailedAt = Bridge.time end
        pathEv("result")
    elseif (Bridge.tick or 0) % 30 == 0 then
        pathEv("tick")
    end
    BridgeMove.wasWalking = BridgeMove.pathing
    trackStep(body)
    if BridgeLog ~= nil and BridgeLog.on() then
        if BridgeMove.pathing and BridgeMove.goal == nil then
            BridgeLog.invariant("I5", "pathing with nil goal", "warn")
        end
        if (Bridge.tick or 0) % 15 == 0 then
            local cs = nil
            pcall(function() cs = body:getCurrentSquare() end)
            local room, bld, asn, bpf = -1, -1, "-", false
            pcall(function()
                if cs ~= nil then
                    if cs:getRoom() ~= nil then room = cs:getRoomID() end
                    local b = BridgeDoors ~= nil and BridgeDoors.buildingId(cs) or nil
                    if b ~= nil then bld = b end
                end
                asn = tostring(body:getActionStateName())
                bpf = body:getVariableBoolean("bPathfind") == true
            end)
            ev("engine.probe", { pos = { x = body:getX(), y = body:getY() },
                current_square = cs ~= nil and { x = cs:getX(), y = cs:getY(), z = cs:getZ() } or nil,
                room = room, building = bld, asn = asn, bPathfind = bpf }, "BridgeRoute.jobPath")
        end
    end
    BridgeRoute.trace(body, d, needPath, stalled)

    pcall(function() BridgeMove.rememberDoorNear(body) end)
    pcall(function() BridgeMove.closeBehind(body) end)
    pcall(function() BridgeMove.closeWindows(body) end)
    BridgeTask.info = string.format("walking d=%.1f spot=%.1f %s", state.d or d or 0, state.dSpot or 0, tostring(BridgeMove.pathResult))
    pcall(function() BridgeTask.routeObstacle() end)
    pcall(function() BridgeTask.routeGoal(body, spec.target) end)
    if not spec.onTarget then pcall(function() BridgeTask.routeAway(body, spec.target, state.dSpot or 0) end) end
    if Bridge.tick ~= BridgeTask.walkLogAt and Bridge.tick % 60 == 0 then
        BridgeTask.walkLogAt = Bridge.tick
        pcall(function()
            local goal = BridgeMove ~= nil and BridgeMove.goal or nil
            local gx2, gy2, gdGoal = -1, -1, -1
            if goal ~= nil then
                gx2, gy2 = goal.x or 0, goal.y or 0
                gdGoal = math.sqrt((body:getX() - gx2) ^ 2 + (body:getY() - gy2) ^ 2)
            end
            local bldBody = BridgeTask.buildingIdAt(math.floor(body:getX()), math.floor(body:getY()), math.floor(body:getZ()))
            local bldTarget = BridgeTask.buildingIdAt(spec.target.x, spec.target.y, spec.target.z)
            local age = Bridge.time - (state.progressAt or Bridge.time)
            log(string.format("walk tgt=%d,%d spot=%d,%d aim=%.2f,%.2f d=%.2f dSpot=%.2f clear=%s path=%s stall=%d goal=%.2f,%.2f dGoal=%.2f bld=%s/%s bestD=%s age=%.1f",
                spec.target.x, spec.target.y, state.spot and state.spot.x or 0, state.spot and state.spot.y or 0,
                state.aim and state.aim.x or 0, state.aim and state.aim.y or 0, state.d or 0, state.dSpot or 0,
                tostring(BridgeTask.adjacentClear(body, spec.targetSq)), tostring(BridgeMove.pathResult),
                state.still or 0, gx2, gy2, gdGoal, bldBody, bldTarget,
                tostring(state.bestD), age))
            if BridgeLog ~= nil and BridgeLog.on() then
                ev("route.walk", {
                    tgt = { x = spec.target.x, y = spec.target.y, z = spec.target.z },
                    spot = state.spot,
                    aim = state.aim,
                    d = state.d,
                    dSpot = state.dSpot,
                    clear = BridgeTask.adjacentClear(body, spec.targetSq),
                    path = BridgeMove.pathResult,
                    stall = state.still,
                    goal = { x = gx2, y = gy2 },
                    dGoal = gdGoal,
                    bld = tostring(bldBody) .. "/" .. tostring(bldTarget),
                    bestD = state.bestD,
                    age = age,
                    since = state.since,
                    progressAt = state.progressAt,
                }, "BridgeRoute.jobPath")
            end
        end)
    end
end

function BridgeRoute.followGoal(body)
    local red = BridgeData.owner()
    if red == nil then return nil end
    local pend = false
    pcall(function() pend = BridgeInventory ~= nil and BridgeInventory.transferPending(body) end)
    if pend then
        BridgeMove.moving = false
        return nil
    end
    local d = dist2d(body:getX(), body:getY(), red:getX(), red:getY())
    if BridgeMove.moving then
        if d <= FOLLOW_STOP and not BridgeMove.redMoving then BridgeMove.moving = false end
    else
        if d > FOLLOW_START then
            BridgeMove.moving = true
            Bridge.holdPos = nil
        end
    end
    if not BridgeMove.moving then return nil end
    if BridgeGunfight ~= nil and type(BridgeGunfight.holdBand) == "function"
            and BridgeMove.followPriorityHold ~= true then
        local hold = false
        pcall(function() hold = BridgeGunfight.holdBand(body) == true end)
        if hold then
            BridgeMove.moving = false
            BridgeMove.steering = false
            local t = BridgeGunfight.target
            if t ~= nil then
                pcall(function() body:faceLocationF(t:getX(), t:getY()) end)
            end
            return nil
        end
    end
    local gx, gy, gz = BridgeMove.nearRed(red, body)
    return gx, gy, gz, d
end

function BridgeRoute.followPath(body)
    local state = BridgeRoute.state
    BridgeMove.setCollide(body, true)
    if BridgeMove.steering then
        BridgeMove.endFollowBump(body, "")
        BridgeMove.steering = false
        BridgeMove.pathing = false
        BridgeMove.wasWalking = false
    end
    local gx, gy, gz, d = BridgeRoute.followGoal(body)
    if gx ~= nil then
        local wx, wy, wz = nil, nil, nil
        pcall(function() wx, wy, wz = BridgeRoute.openingWay(body, gx, gy, gz) end)
        if wx ~= nil then
            gx, gy, gz = wx, wy, wz
            BridgeRoute.logSrc("opening", { x = gx, y = gy, z = gz })
        else
            local px, py, pz = nil, nil, nil
            pcall(function() px, py, pz = BridgeRoute.gapGoal(body) end)
            if px ~= nil then
                gx, gy, gz = px, py, pz
                BridgeRoute.logSrc("gap", { x = gx, y = gy, z = gz })
            else
                BridgeRoute.logSrc("direct", { x = gx, y = gy, z = gz })
            end
        end
    end
    if gx ~= nil then
        if BridgeMove.openingWay == nil then
            state.openingKey, state.openingSince = nil, nil
        else
            local openStatus, openReason = BridgeRoute.opening(state, {
                giveUp = NAV.OPENING_GIVE_UP, target = { x = gx, y = gy, z = gz } })
            if openStatus == "stale" then
                BridgeMove.follow.navHoldUntil = Bridge.time + NAV.FOLLOW_HOLD
                BridgeMove.follow.navReason = openReason
                BridgeMove.follow.navStatus = "stale"
                state.status = "stale"
                state.reason = openReason
                if BridgeMove.onPath() then BridgeMove.stopPath(body) end
                BridgeMove.moving = false
                if Bridge.verbose then
                    log(sformat("opening stale key=%s age=%d reason=%s",
                        tostring(state.openingKey or "-"),
                        Bridge.time - (state.openingSince or Bridge.time),
                        tostring(openReason or "-")))
                end
                if BridgeLog ~= nil and BridgeLog.on() then
                    ev("route.opening", { action = "stale", key = state.openingKey,
                        reason = openReason,
                        age = Bridge.time - (state.openingSince or Bridge.time) },
                        "BridgeRoute.followPath")
                end
                return
            end
        end
    end
    if gx == nil then
        BridgeMove.wasWalking = false
        if BridgeMove.onPath() then BridgeMove.stopPath(body) end
        if Bridge.zombieTicks % 30 == 0 then
            local red = BridgeData.owner()
            if red ~= nil then pcall(function() body:faceLocationF(red:getX(), red:getY()) end) end
        end
        return
    end

    local arrived = d <= 0.8
    if arrived and math.abs(gz - body:getZ()) < 0.3 then
        local onPath = BridgeMove.onPath()
        if Bridge.verbose and onPath then
            log(sformat("follow arrived: d=%.2f gz=%.2f bodyZ=%.2f", d, gz, body:getZ()))
        end
        if onPath then BridgeMove.stopPath(body) end
        return
    end

    BridgeMove.walkType = pickWalkType(d)
    BridgeMove.speed = pickSpeed(d)
    BridgeMove.applyAnimVars(body)

    if BridgeMove.pathing then
        local okObs, busy = pcall(function() return BridgeMove.handleObstacle(body) end)
        if not okObs then BridgeMove.obstacle = "error: " .. tostring(busy) end
        if okObs and busy then
            log(sformat("obstacle=%s pathing=%s steering=%s body=%.2f,%.2f goal=%.1f,%.1f busy=%s",
                tostring(BridgeMove.obstacle), tostring(BridgeMove.pathing), tostring(BridgeMove.steering),
                body:getX(), body:getY(), gx or -1, gy or -1, tostring(busy)))
            return
        end
    end

    local pf = body:getPathFindBehavior2()

    local replan = true
    local red = BridgeData.owner()
    if BridgeMove.redAt ~= nil and red ~= nil then
        local far = BridgeMove.walkType == "Run" and BridgeMove.runReplan or BridgeMove.replanDist
        replan = dist2d(BridgeMove.redAt.x, BridgeMove.redAt.y, red:getX(), red:getY()) > far
    end
    if BridgeMove.goal ~= nil and dist2d(BridgeMove.goal.x, BridgeMove.goal.y, gx, gy) > 2 then replan = true end
    local function startPath()
        BridgeMove.lastPath = Bridge.time
        if Bridge.verbose then
            local pg = BridgeMove.goal
            if pg == nil or dist2d(pg.x, pg.y, gx, gy) > 0.5 then
                log(sformat("follow path goal=%.1f,%.1f,%.1f body=%.2f,%.2f,%.2f",
                    gx, gy, gz, body:getX(), body:getY(), body:getZ()))
            end
        end
        local bump = ""
        pcall(function() bump = tostring(body:getBumpType()) end)
        local asnNow = ""
        pcall(function() asnNow = tostring(body:getActionStateName()) end)
        local ramp = bump == BridgeMove.KICK
        local onTheMove = (Bridge.time - BridgeMove.stepTick) < 10
        if not ramp and not onTheMove and (bump == "Stand" or asnNow == "idle" or asnNow == "bumped"
            or (not BridgeMove.pathing and (not BridgeMove.wasWalking or BridgeMove.startBump == "on"))) then
            BridgeMove.startKick(body)
        end
        pf:pathToLocationF(gx, gy, gz)
        BridgeMove.goal = { x = gx, y = gy }
        if red ~= nil then BridgeMove.redAt = { x = red:getX(), y = red:getY() } end
        BridgeMove.pathing = true
        if BridgeLog ~= nil and BridgeLog.on() then
            ev("move.path", { phase = "start", body = { x = body:getX(), y = body:getY() },
                goal = { x = gx, y = gy }, pathing = true }, "BridgeRoute.followPath")
        end
        if Bridge.verbose then
            log(sformat("follow path set goal=%.1f,%.1f,%.1f bodyZ=%.2f playerZ=%.2f",
                gx, gy, gz, body:getZ(), red ~= nil and red:getZ() or -1))
        end
    end

    local stalled = false
    if BridgeMove.redMoving and BridgeMove.pathing
        and (Bridge.time - BridgeMove.lastPath) >= 12 then
        pcall(function() stalled = (body:getActionStateName() == "idle") end)
    end

    local failedRecently = BridgeMove.lastFailed ~= nil and (Bridge.time - (BridgeMove.lastFailedAt or -9999)) < BridgeMove.pathEvery
    local every = BridgeMove.walkType == "Run" and BridgeMove.runEvery or BridgeMove.pathEvery
    local needPath = (not BridgeMove.pathing and not failedRecently) or stalled
        or (replan and (Bridge.time - BridgeMove.lastPath) >= every)
    if needPath then startPath() end
    local res = pf:update()
    if Bridge.verbose and Bridge.every(60) and BridgeMove.pathing and res == BehaviorResult.Working then
        local asn, bz, pz = "?", -1, -1
        pcall(function() asn = tostring(body:getActionStateName()) end)
        pcall(function() bz = body:getZ() end)
        pcall(function() pz = red ~= nil and red:getZ() or -1 end)
        log(sformat("follow path state goal=%.1f,%.1f,%.1f bodyZ=%.2f playerZ=%.2f asn=%s",
            gx, gy, gz, bz, pz, asn))
    end
    BridgeMove.kickStep(body, pf)
    BridgeMove.pathResult = tostring(res)
    if res == BehaviorResult.Succeeded or res == BehaviorResult.Failed then
        BridgeMove.pathing = false
        if res == BehaviorResult.Succeeded then state.pathFails = 0 end
        if res == BehaviorResult.Failed then BridgeMove.lastFailed = Bridge.tick BridgeMove.lastFailedAt = Bridge.time end
        if BridgeLog ~= nil and BridgeLog.on() then
            ev("move.path", { phase = "result", body = { x = body:getX(), y = body:getY() },
                goal = { x = gx, y = gy }, result = BridgeMove.pathResult,
                pathing = BridgeMove.pathing }, "BridgeRoute.followPath")
        end
        if BridgeMove.redMoving and res == BehaviorResult.Succeeded then
            BridgeMove.restarts = BridgeMove.restarts + 1
            BridgeMove.lastRestart = Bridge.time
            startPath()
            pcall(function() pf:update() end)
        else
            BridgeMove.moving = false
        end
    end
    if BridgeRoute.notePathFail(state, { limit = NAV.PATH_FAIL_LIMIT }) == "failed" then
        local reason = BridgeRoute.blockedReason(Bridge.target)
        BridgeMove.follow.navHoldUntil = Bridge.time + NAV.FOLLOW_HOLD
        BridgeMove.follow.navReason = reason
        BridgeMove.follow.navStatus = "failed"
        state.status = "failed"
        state.reason = reason
        BridgeMove.stopPath(body)
        BridgeMove.moving = false
        if Bridge.verbose then
            log(sformat("nav: path failed %d times%s, holding", state.pathFails or 0,
                reason ~= nil and (", " .. tostring(reason)) or ""))
        end
    end
    BridgeMove.wasWalking = BridgeMove.pathing
    trackStep(body)
    BridgeRoute.trace(body, d, needPath, stalled)
end

function BridgeRoute.step(body)
    if BridgeRoute.stepTick == Bridge.tick then
        BridgeRoute.guardHit = Bridge.tick
        if Bridge.tick % 60 == 0 then
            log(sformat("step guard skip t=%d owner=%s", Bridge.tick, tostring(BridgeRoute.state.owner or "-")))
        end
        return BridgeRoute.lastStatus
    end
    BridgeRoute.stepTick = Bridge.tick

    if BridgeLog ~= nil and BridgeLog.on() and (Bridge.tick or 0) % 60 == 0 then
        local s = BridgeRoute.state
        ev("state.snapshot", {
            body = { x = body:getX(), y = body:getY(), z = body:getZ() },
            stand = s.stand, target = s.target,
            opening = BridgeMove.openingWay ~= nil and BridgeMove.openingWay.key or nil,
            pathResult = BridgeMove.pathResult, progressAt = s.progressAt, since = s.since,
            still = s.still, pathFails = s.pathFails,
            cross = BridgeMove.cross ~= nil and BridgeMove.cross.kind or nil,
            doorAct = BridgeMove.doorAct ~= nil and BridgeMove.doorAct.want or nil,
            pendingClimb = BridgeMove.pendingClimb ~= nil and BridgeMove.pendingClimb.kind or nil,
            task = BridgeTask ~= nil and BridgeTask.kind or nil, mode = Bridge.mode }, "BridgeRoute.step")
        if s.owner ~= nil and s.since == nil and BridgeRoute.i3At ~= BridgeRoute.att then
            BridgeRoute.i3At = BridgeRoute.att
            BridgeLog.invariant("I3", "since nil owner=" .. tostring(s.owner), "warn")
        end
    end

    local state = BridgeRoute.state
    if Bridge.follow then
        if state.owner ~= "follow" then
            BridgeRoute.reset()
            state = BridgeRoute.state
            state.owner = "follow"
            state.mode = "follow"
        end
    elseif state.owner == nil and Bridge.target ~= nil then
        local t = Bridge.target
        state.owner = "legacy"
        state.target = { x = t.x, y = t.y, z = t.z }
        state.goal = { x = t.x, y = t.y, z = t.z }
        state.mode = "legacy"
        local targetSq = nil
        pcall(function() targetSq = getCell():getGridSquare(t.x, t.y, t.z) end)
        state.spec = { body = body, target = state.target, targetSq = targetSq,
            sameFloor = targetSq == nil or math.floor(targetSq:getZ()) == math.floor(body:getZ()),
            onTarget = false, reach = 0.7, owner = "legacy" }
        log(sformat("legacy adopt target=%d,%d,%d body=%.1f,%.1f,%.1f",
            t.x, t.y, t.z, body:getX(), body:getY(), body:getZ()))
    end

    BridgeMove.followDebug("update-enter", body, "entry")
    if not Bridge.follow and BridgeMove.follow ~= nil
            and (BridgeMove.follow.back ~= nil or BridgeMove.backActive) then
        BridgeMove.backEnd(body, BridgeMove.follow, "follow off", nil)
    end
    if Bridge.verbose and Bridge.tick - (BridgeRoute.traceArm or -9999) >= 60 then
        BridgeRoute.traceArm = Bridge.tick
        BridgeRoute.traceUntil = Bridge.tick + 60 * 60 * 5
    end
    do
        local red = BridgeData.owner()
        if red ~= nil then
            local px, py = red:getX(), red:getY()
            local el = frameDt()
            if BridgeMove.redPrev ~= nil then
                if BridgeMove.redPrev.t ~= nil and Bridge.time - BridgeMove.redPrev.t > 0 then
                    el = Bridge.time - BridgeMove.redPrev.t
                end
            end
            local hist = BridgeMove.redHist
            local lastH = hist and hist[#hist] or nil
            local raw = lastH ~= nil and dist2d(lastH.x, lastH.y, px, py) / el or 0
            if hist == nil or raw >= 0.5 then
                hist = {}
                BridgeMove.redHist = hist
                BridgeMove.redStep = raw
            end
            hist[#hist + 1] = { t = Bridge.time, x = px, y = py }
            while #hist > 2 and hist[2].t <= Bridge.time - 5 do table.remove(hist, 1) end
            local h0 = hist[1]
            if Bridge.time - h0.t > 0 then
                BridgeMove.redStep = dist2d(h0.x, h0.y, px, py) / (Bridge.time - h0.t)
            end
            BridgeMove.redPrevSlot.x, BridgeMove.redPrevSlot.y, BridgeMove.redPrevSlot.t = px, py, Bridge.time
            BridgeMove.redPrev = BridgeMove.redPrevSlot
            BridgeMove.redMoving = BridgeMove.redStep > 0.015

            if BridgeMove.redStep < 0.5 then
                local a = 1 - 0.8 ^ el
                BridgeMove.redSpeed = BridgeMove.redSpeed + (BridgeMove.redStep - BridgeMove.redSpeed) * a
                local prev = BridgeMove.redPrevPos
                if prev ~= nil then
                    local b = 1 - 0.7 ^ el
                    BridgeMove.redVx = (BridgeMove.redVx or 0) + ((px - prev.x) / el - (BridgeMove.redVx or 0)) * b
                    BridgeMove.redVy = (BridgeMove.redVy or 0) + ((py - prev.y) / el - (BridgeMove.redVy or 0)) * b
                end
            end
            BridgeMove.redPrevPosSlot.x, BridgeMove.redPrevPosSlot.y = px, py
            BridgeMove.redPrevPos = BridgeMove.redPrevPosSlot
            BridgeMove.addTrail(red)
        end
    end

    BridgeRoute.stuckTick(body)

    if not Bridge.follow and state.owner ~= "legacy" and state.spec ~= nil then
        local st = BridgeRoute.jobPolicy(body, state.spec)
        if st ~= "walking" then
            BridgeRoute.lastStatus = st
            return st
        end
    end

    if Bridge.time < (BridgeMove.unPathfindUntil or 0) and BridgeMove.cross == nil then
        pcall(function() body:setVariable("bPathfind", false) end)
    end
    if BridgeMove.climbStep(body) then
        BridgeMove.followDebug("update-exit", body, "climb")
        BridgeRoute.lastStatus = "walking"
        return "walking"
    end
    local okCross, crossing = pcall(function() return BridgeMove.crossStep(body) end)
    if not okCross then
        BridgeMove.crossInfo = "error: " .. tostring(crossing)
        BridgeMove.cross = nil
        pcall(function() body:setVariable("bPathfind", false) end)
    elseif crossing then
        BridgeMove.followDebug("update-exit", body, "cross")
        trackStep(body)
        BridgeRoute.lastStatus = "walking"
        return "walking"
    end

    local okDoor, atDoor = pcall(function() return BridgeMove.doorStep(body) end)
    if not okDoor then
        BridgeMove.doorLast = "error: " .. tostring(atDoor)
        BridgeMove.doorAct = nil
    elseif atDoor then
        BridgeMove.followDebug("update-exit", body, "door")
        trackStep(body)
        BridgeRoute.lastStatus = "walking"
        return "walking"
    end

    if BridgeAim ~= nil then
        local aimRed = BridgeData.owner()
        if aimRed ~= nil then pcall(function() BridgeAim.refresh(aimRed) end) end
        local aimOk = true
        if Bridge.follow then
            aimOk = BridgeAim.inCone(body:getX(), body:getY(), body:getZ())
        end
        if aimOk and BridgeAim.step(body, aimRed) then
            BridgeMove.followDebug("update-exit", body, "aim")
            trackStep(body)
            BridgeRoute.lastStatus = "walking"
            return "walking"
        end
    end

    if BridgeMove.steering or BridgeMove.pathing then
        pcall(function() BridgeMove.openAhead(body) end)
        if BridgeMove.doorAct ~= nil then
            trackStep(body)
            BridgeRoute.lastStatus = "walking"
            return "walking"
        end
    end

    if Bridge.follow then
        local okSeat, seated = pcall(function() return BridgeRoute.seatStep(body) end)
        if not okSeat then
            BridgeMove.seatInfo = "error: " .. tostring(seated)
            BridgeMove.seat = nil
        else
            BridgeMove.seatInfo = nil
            if seated then
                BridgeMove.followDebug("update-exit", body, "seat")
                BridgeRoute.lastStatus = "walking"
                return "walking"
            end
        end
    end

    if not Bridge.follow and Bridge.target ~= nil and Bridge.target.cellX ~= nil then
        local okAside, going = pcall(function() return BridgeRoute.asideStep(body) end)
        if not okAside then BridgeMove.seatInfo = "error: " .. tostring(going)
        elseif going then
            BridgeRoute.lastStatus = "walking"
            return "walking"
        end
    end

    if Bridge.follow then
        local pendHere = false
        pcall(function() pendHere = BridgeInventory ~= nil and BridgeInventory.transferPending(body) end)

        if not pendHere and BridgeMove.cross == nil
                and BridgeMove.pendingClimb == nil and BridgeMove.doorAct == nil then
            local red = BridgeData.owner()
            if red ~= nil and math.abs(red:getZ() - body:getZ()) < 0.5
                    and not BridgeMove.lineClear(body, red:getX(), red:getY(), red:getZ()) then
                local ekind, eobject, efrom, eto = BridgeMove.edgeOnLine(body, red:getX(), red:getY(), red:getZ(), 6)
                if ekind == "tall" and BridgeMove.beyondEdge(efrom, eto, red:getX(), red:getY(), 0) then
                    BridgeMove.goal = { x = red:getX(), y = red:getY() }
                    BridgeMove.walkType = "Walk"
                    BridgeMove.forceCross = true
                    if BridgeRoute.shouldCross(body, ekind, efrom, eto) then
                        local ex = efrom:getX() + 0.5 + (eto:getX() - efrom:getX()) * 0.5
                        local ey = efrom:getY() + 0.5 + (eto:getY() - efrom:getY()) * 0.5
                        BridgeMove.setCollide(body, true)
                        BridgeMove.followWs = 0.4
                        BridgeMove.applyAnimVars(body)
                        BridgeMove.followBump(body, "Walk")
                        pcall(function() BridgeMove.turnToward(body, ex, ey, 180) end)
                        pcall(function() body:getPathFindBehavior2():moveToPoint(ex, ey, 0.5) end)
                        BridgeMove.pathing = true
                        BridgeMove.climbUntil = Bridge.time + 20
                        BridgeMove.pathResult = "follow-approach"
                        trackStep(body)
                        BridgeRoute.lastStatus = "walking"
                        return "walking"
                    end
                    BridgeMove.forceCross = false
                else
                    BridgeMove.forceCross = false
                end
            else
                BridgeMove.forceCross = false
            end
        end

        local beforeKind = BridgeMove.follow.kind
        local done = false
        if BridgeMove.steerMode and not pendHere then done = BridgeRoute.followPolicy(body) end
        local afterKind = BridgeMove.follow.kind
        if afterKind ~= BridgeRoute.lastFollowKind then
            BridgeRoute.lastFollowKind = afterKind
            local redF = BridgeData.owner()
            local dF = redF ~= nil and dist2d(body:getX(), body:getY(), redF:getX(), redF:getY()) or -1
            local lineF = redF ~= nil and BridgeMove.lineClear(body, redF:getX(), redF:getY(), redF:getZ()) or false
            log(sformat("follow kind=%s->%s d=%.2f line=%s path=%s hold=%s detour=%s stall=%s",
                tostring(beforeKind), tostring(afterKind), dF, tostring(lineF),
                tostring(BridgeMove.pathing), tostring(BridgeMove.follow.engineHold ~= nil),
                tostring(BridgeRoute.state.detour ~= nil), tostring(BridgeRoute.state.still or 0)))
            if BridgeLog ~= nil and BridgeLog.on() then
                ev("route.follow", { from = beforeKind, to = afterKind, d = dF, line = lineF,
                    path = BridgeMove.pathing, hold = BridgeMove.follow.engineHold ~= nil,
                    detour = BridgeRoute.state.detour ~= nil,
                    stall = BridgeRoute.state.still or 0 }, "BridgeRoute.followPath")
            end
        end
        if done then
            BridgeMove.followDebug("update-exit", body, "trail")
            BridgeRoute.lastStatus = "walking"
            return "walking"
        end
        BridgeRoute.followPath(body)
        BridgeRoute.lastStatus = "walking"
        return "walking"
    end

    BridgeRoute.jobPath(body, state.spec)
    BridgeRoute.lastStatus = "walking"
    return "walking"
end

function BridgeRoute.seatAside(body)
    local red = BridgeData.owner()
    local zones = BridgeMove.seatZones(red)
    if zones == nil or math.abs(body:getZ() - zones.z) >= 0.5 then return false end
    local bcx, bcy = BridgeMove.cellOf(body:getX(), body:getY())
    if not BridgeMove.inSeatZone(zones, bcx, bcy) then return false end
    local spot, checked = BridgeMove.seatSpot(red, zones, body:getX(), body:getY(), body, nil)
    if spot == nil then
        if Bridge.time >= (BridgeMove.seatAsideQuiet or 0) then
            BridgeMove.seatAsideQuiet = Bridge.time + 600
            log(sformat("seat: player %s next to waiting me, no free spot (%d cells checked)", zones.why, checked))
        end
        return false
    end
    Bridge.target = { x = spot.x + 0.5, y = spot.y + 0.5, z = zones.z, cellX = spot.x, cellY = spot.y }
    Bridge.targetSince = Bridge.time
    Bridge.pose = nil
    log(sformat("seat: player %s next to waiting me (%s), stepping aside to %d,%d (ring %d)",
        zones.why, tostring(Bridge.mode), spot.x, spot.y, spot.ring))
    return true
end

function BridgeRoute.setGapWay(a, b)
    if (Bridge.time - (BridgeMove.passFirst or 0)) > 120 then
        BridgeMove.passFirst, BridgeMove.passCount = Bridge.time, 0
    end
    BridgeMove.passCount = (BridgeMove.passCount or 0) + 1
    if BridgeMove.passCount > 2 then
        BridgeMove.gapWay = nil
        BridgeMove.noGapUntil = Bridge.time + 600
        log("pass looped " .. BridgeMove.passCount .. "x, climbing")
        return
    end
    BridgeMove.gapWay = { ax = a:getX() + 0.5, ay = a:getY() + 0.5, bx = b:getX() + 0.5, by = b:getY() + 0.5,
        z = a:getZ(), stage = 1, best = math.huge, bestAt = Bridge.time, tick = Bridge.tick }
    log(sformat("pass instead of climbing: via %d,%d > %d,%d", a:getX(), a:getY(), b:getX(), b:getY()))
end

function BridgeRoute.passInstead(body, kind)
    if BridgeMove.gapWay ~= nil then return "active" end
    if Bridge.time < BridgeMove.noGapUntil then return nil end
    local found = nil
    pcall(function()
        local cur = body:getCurrentSquare()
        local dir = BridgeMove.cardinal(body)
        local dx, dy = 0, 0
        if dir == IsoDirections.E then dx = 1 elseif dir == IsoDirections.W then dx = -1
        elseif dir == IsoDirections.S then dy = 1 else dy = -1 end
        local to = getCell():getGridSquare(cur:getX() + dx, cur:getY() + dy, cur:getZ())
        if to == nil then return end
        local go, why, a, b = BridgeRoute.shouldCross(body, kind, cur, to)
        if not go then
            if a ~= nil then
                BridgeRoute.setGapWay(a, b)
                found = "new"
            else
                found = "around"
            end
        end
    end)
    return found
end

function BridgeRoute.enginePathGoal(body, x, y, z, way)
    if not way then return x, y, z end
    local wx, wy, wz = nil, nil, nil
    pcall(function() wx, wy, wz = BridgeRoute.viaDoor(body, x, y, z) end)
    if wx ~= nil then return wx, wy, wz end
    local px, py, pz = nil, nil, nil
    pcall(function() px, py, pz = BridgeRoute.gapGoal(body) end)
    if px ~= nil then return px, py, pz end
    return x, y, z
end

function BridgeRoute.enginePathNeed(body, x, y)
    local goalMoved = true
    if BridgeMove.goal ~= nil then
        goalMoved = dist2d(BridgeMove.goal.x, BridgeMove.goal.y, x, y) > 0.5
    end
    return (not BridgeMove.pathing) or (goalMoved and (Bridge.time - BridgeMove.lastPath) >= 10)
end
