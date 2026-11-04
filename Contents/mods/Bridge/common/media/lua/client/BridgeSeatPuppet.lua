BridgeSeatPuppet = BridgeSeatPuppet or {}
local S = BridgeSeatPuppet

S.VAR = "SWMSeatPuppet"
S.RETRY_TICKS = 120
S.MAX_TRIES = 3
S.FINE = 0.02
S.COARSE = 0.10
S.LIMIT = 1.00
S.SWEEP_TICKS = 18000

S.p = nil
S.car = nil
S.seat = nil
S.snap = nil
S.retryAt = nil
S.losses = 0
S.offForEntry = false
S.playerSeat = nil
S.playerPrevSeat = nil
S.swap = false
S.sweepUntil = nil
S.sweepQueue = {}

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[SeatPuppet] " .. tostring(text)) end
end

local function store(create)
    local md = nil
    pcall(function() md = BridgeData.world() end)
    if type(md) ~= "table" then return nil end
    local st = md.seatPuppet
    if type(st) ~= "table" then
        if create ~= true then return nil end
        st = { off = {}, ids = {} }
        md.seatPuppet = st
        return st
    end
    if create == true then
        if type(st.off) ~= "table" then st.off = {} end
        if type(st.ids) ~= "table" then st.ids = {} end
    end
    return st
end

local function pidOf(z)
    local id = nil
    pcall(function() id = z:getPersistentOutfitID() end)
    if id == nil then return nil end
    local s = tostring(id)
    if s == "" or s == "0" or s == "-1" then return nil end
    return s
end

local function clamp(v)
    v = tonumber(v) or 0
    if v > S.LIMIT then return S.LIMIT end
    if v < -S.LIMIT then return -S.LIMIT end
    return v
end

local function round2(v)
    v = tonumber(v) or 0
    if v >= 0 then return math.floor(v * 100 + 0.5) / 100 end
    return math.ceil(v * 100 - 0.5) / 100
end

function S.enabled()
    if Bridge ~= nil and Bridge.mp then return false end
    if BridgeData == nil or type(BridgeData.sandboxFlag) ~= "function" then return false end
    local ok, v = pcall(BridgeData.sandboxFlag, "CarSeatPuppet", true)
    return ok and v == true
end

function S.is(z)
    if z == nil then return false end
    if S.p == nil then return false end
    if z == S.p then return true end
    local v = false
    pcall(function() v = z:getVariableBoolean(S.VAR) == true end)
    return v
end

function S.isCorpse(c)
    if c == nil then return false end
    local v = false
    pcall(function() v = c:hasModData() and c:getModData().swmSeatPuppet == true end)
    return v
end

function S.modelOf(car)
    local name = nil
    pcall(function()
        local script = car:getScript()
        if script == nil then return end
        local model = script:getModel()
        if model ~= nil then name = model:getFile() end
        if name == nil or name == "" then name = script:getFullName() end
        if name == nil or name == "" then name = script:getName() end
    end)
    if name == nil or name == "" then name = "unknown" end
    return tostring(name)
end

function S.offsetKey(car, seat)
    return S.modelOf(car) .. "|" .. tostring(seat)
end

function S.offset(car, seat)
    local st = store(false)
    local rec = nil
    if st ~= nil and type(st.off) == "table" then rec = st.off[S.offsetKey(car, seat)] end
    if type(rec) ~= "table" then return { u = 0, r = 0, f = 0 } end
    return { u = tonumber(rec.u) or 0, r = tonumber(rec.r) or 0, f = tonumber(rec.f) or 0 }
end

function S.setOffset(car, seat, t)
    if car == nil or seat == nil then return end
    local st = store(true)
    if st == nil then return end
    local key = S.offsetKey(car, seat)
    local u = clamp(t and t.u)
    local r = clamp(t and t.r)
    local f = clamp(t and t.f)
    if u == 0 and r == 0 and f == 0 then
        st.off[key] = nil
    else
        st.off[key] = { u = u, r = r, f = f }
    end
end

function S.nudge(car, seat, du, dr, df)
    local a = S.offset(car, seat)
    local u = round2(a.u + (tonumber(du) or 0))
    local r = round2(a.r + (tonumber(dr) or 0))
    local f = round2(a.f + (tonumber(df) or 0))
    S.setOffset(car, seat, { u = u, r = r, f = f })
    if S.p ~= nil and S.car == car and S.seat == seat then S.reposition() end
end

local function capture()
    local snap = (Bridge ~= nil) and Bridge.rebuildSnap or nil
    if (snap == nil or snap == "") and Bridge ~= nil and Bridge.body ~= nil
            and type(Bridge.liveOutfitSnapshot) == "function" then
        local ok, fresh = pcall(Bridge.liveOutfitSnapshot)
        if ok and type(fresh) == "string" and fresh ~= "" then snap = fresh end
    end
    if snap ~= nil and snap ~= "" then
        S.snap = snap
        return
    end
    local st = Bridge ~= nil and Bridge.store or nil
    if S.snap == nil and st ~= nil and type(st.items) == "string" and st.items ~= "" then
        S.snap = st.items
    end
end

local function seatFree(car, seat)
    if car == nil or seat == nil or seat == 0 then return false end
    local pos = nil
    pcall(function() pos = car:getPassengerPosition(seat, "inside") end)
    if pos == nil then return false end
    local who = nil
    pcall(function() who = car:getCharacter(seat) end)
    if who ~= nil then return false end
    local holding = false
    pcall(function() holding = car:isSeatHoldingItems(seat) == true end)
    return not holding
end

local function freeSeat(car, avoid)
    local max = 0
    pcall(function() max = car:getMaxPassengers() end)
    for i = 1, max - 1 do
        if i ~= avoid and seatFree(car, i) then return i end
    end
    return nil
end

local function targetSeat(car, red)
    local his = nil
    if red ~= nil then pcall(function() his = car:getSeat(red) end) end
    if his == -1 then his = nil end
    local want = (BridgeCar ~= nil) and BridgeCar.seat or nil
    local lap = (BridgeCar ~= nil) and BridgeCar.lap == true or false
    if want == nil or lap then
        S.swap = false
        return freeSeat(car, his)
    end
    local taken = false
    if red ~= nil then pcall(function() taken = car:getCharacter(want) == red end) end
    if taken then
        S.swap = true
        local prev = S.playerPrevSeat
        if prev ~= nil and prev ~= 0 and prev ~= want and seatFree(car, prev) then return prev end
        return freeSeat(car, his)
    end
    S.swap = false
    if seatFree(car, want) then return want end
    return freeSeat(car, his)
end

local function seatPos(car, seat)
    local pos = nil
    pcall(function() pos = car:getPassengerPosition(seat, "inside") end)
    if pos == nil then return nil end
    local o = nil
    pcall(function() o = pos:getOffset() end)
    if o == nil then return nil end
    local mx, my, mz = 0, 0, 0
    pcall(function()
        local model = car:getScript():getModel()
        if model ~= nil then
            local mo = model:getOffset()
            if mo ~= nil then mx, my, mz = mo:x(), mo:y(), mo:z() end
        end
    end)
    local a = S.offset(car, seat)
    local v = nil
    pcall(function()
        v = car:getWorldPos(o:x() + mx - a.r, 0, o:z() + mz + a.f, Vector3f.new())
    end)
    if v == nil then return nil end
    return v:x(), v:y(), v:z() + (o:y() + my + a.u) / 2.44949
end

local function stripped(encoded)
    if encoded == nil or encoded == "" then return nil end
    if BridgeInventory == nil then return nil end
    local ok, list = pcall(BridgeInventory.decode, encoded)
    if not ok or type(list) ~= "table" then return nil end
    for _, rec in ipairs(list) do
        if type(rec) == "table" then
            rec.h = nil
            rec.as = nil
        end
    end
    local ok2, enc = pcall(BridgeInventory.encode, list)
    if ok2 and type(enc) == "string" and enc ~= "" then return enc end
    return nil
end

local function place(car, seat)
    local p = S.p
    if p == nil then return end
    local x, y, z = seatPos(car, seat)
    if x == nil then return end
    pcall(function()
        p:setX(x)
        p:setY(y)
        p:setZ(z)
        p:setLastX(x)
        p:setLastY(y)
        p:setLastZ(z)
        p:setNextX(x)
        p:setNextY(y)
        p:setCurrentSquareFromPosition()
    end)
    local fx, fy = nil, nil
    pcall(function()
        local f = car:getForwardVector(Vector3f.new())
        fx, fy = f:x(), f:z()
    end)
    if fx ~= nil then pcall(function() p:setTargetAndCurrentDirection(fx, fy) end) end
    pcall(function() p:setbClimbing(true) end)
    pcall(function() p:setCollidable(false) end)
    pcall(function() p:setTarget(nil) end)
    pcall(function() p:setCanWalk(true) end)
    pcall(function() p:setCrawler(false) end)
    pcall(function() p:setKnockedDown(false) end)
    pcall(function() p:setOnFloor(false) end)
    pcall(function() p:setFallOnFront(false) end)
    local shoot = true
    pcall(function() shoot = p:isShootable() == true end)
    if shoot then pcall(function() p:setShootable(false) end) end
end

function S.reposition()
    if S.p == nil or S.car == nil or S.seat == nil then return end
    place(S.car, S.seat)
end

local function create(car, seat)
    if S.offForEntry then return false end
    if S.losses >= S.MAX_TRIES then
        S.offForEntry = true
        log("disabled for this ride after " .. tostring(S.losses) .. " tries")
        return false
    end
    local enc = stripped(S.snap)
    if enc == nil then
        S.retryAt = (Bridge ~= nil and Bridge.time or 0) + S.RETRY_TICKS
        return false
    end
    local cx = math.floor(car:getX())
    local cy = math.floor(car:getY())
    local cz = math.floor(car:getZ())
    local chance = (BridgeData ~= nil and BridgeData.isFemale(Bridge.store)) and 100 or 0
    local ok, list = pcall(addZombiesInOutfit, cx, cy, cz, 1, "Naked", chance,
        false, false, false, false, false, false, 1)
    if not ok or list == nil or list:size() == 0 then
        S.retryAt = (Bridge ~= nil and Bridge.time or 0) + S.RETRY_TICKS
        log("spawn failed")
        return false
    end
    local p = list:get(0)
    if p == nil then return false end
    S.p = p
    pcall(function() p:setVariable(S.VAR, true) end)
    pcall(function() p:getModData().swmSeatPuppet = true end)
    pcall(function() p:getModData().ST_Ignore = true end)
    pcall(function() p:getModData().RandomZedsExcluded = true end)
    pcall(function() p:getModData().bScroungerorIncomprehensiveRolled = true end)
    pcall(function() p:setUseless(true) end)
    pcall(function() p:setNoTeeth(true) end)
    pcall(function() p:setTarget(nil) end)
    pcall(function() p:clearAggroList() end)
    pcall(function() p:setInvulnerable(true) end)
    pcall(function() p:setShootable(false) end)
    pcall(function() p:setSceneCulled(false) end)
    pcall(function() p:setDressInRandomOutfit(false) end)
    pcall(function() p:setCollidable(false) end)
    pcall(function() p:setbClimbing(true) end)
    if BridgeInventory ~= nil and type(BridgeInventory.dressVisual) == "function" then
        pcall(BridgeInventory.dressVisual, p, enc, Bridge.store)
    end
    pcall(function() p:setPrimaryHandItem(nil) end)
    pcall(function() p:setSecondaryHandItem(nil) end)
    pcall(function() p:resetModelNextFrame() end)
    local id = pidOf(p)
    local st = store(true)
    if st ~= nil and id ~= nil then st.ids[id] = true end
    log("created seat " .. tostring(seat))
    return true
end

local function sweepTick()
    if S.sweepQueue == nil then return end
    local st = store(false)
    local body = (Bridge ~= nil) and Bridge.body or nil
    for z, id in pairs(S.sweepQueue) do
        S.sweepQueue[z] = nil
        if z ~= S.p and z ~= body then
            pcall(function() z:removeFromSquare() end)
            pcall(function() z:removeFromWorld() end)
        end
        if st ~= nil and type(st.ids) == "table" and id ~= nil then st.ids[id] = nil end
    end
end

local function trackPlayerSeat(car, red)
    if red == nil then
        S.playerSeat, S.playerPrevSeat = nil, nil
        return
    end
    local his = nil
    pcall(function() his = car:getSeat(red) end)
    if his == nil or his == -1 then
        S.playerSeat, S.playerPrevSeat = nil, nil
        return
    end
    if S.playerSeat ~= his then
        S.playerPrevSeat = S.playerSeat
        S.playerSeat = his
    end
end

function S.show(car)
    if car == nil then return end
    if not S.enabled() then return end
    if S.p ~= nil then S.hide("show") end
    S.car = car
    S.seat = nil
    S.retryAt = nil
    S.losses = 0
    S.offForEntry = false
    S.playerSeat, S.playerPrevSeat, S.swap = nil, nil, false
    capture()
    log("show")
end

function S.hide(why)
    local p = S.p
    local id = nil
    if p ~= nil then id = pidOf(p) end
    S.p, S.car, S.seat = nil, nil, nil
    S.retryAt = nil
    S.playerSeat, S.playerPrevSeat, S.swap = nil, nil, false
    if p == nil then return end
    if id ~= nil then
        local st = store(false)
        if st ~= nil and type(st.ids) == "table" then st.ids[id] = nil end
    end
    pcall(function() p:setVariable(S.VAR, false) end)
    pcall(function() p:removeFromSquare() end)
    pcall(function() p:removeFromWorld() end)
    log("hide " .. tostring(why))
end

function S.tick()
    sweepTick()
    if not S.enabled() then
        if S.p ~= nil then S.hide("off") end
        return
    end
    if BridgeCar == nil or BridgeCar.state ~= "inside" or BridgeCar.car == nil then
        if S.p ~= nil then S.hide("not inside") end
        return
    end
    if Bridge ~= nil and Bridge.body ~= nil then return end
    if S.offForEntry then return end
    local now = (Bridge ~= nil and Bridge.time) or 0
    if S.retryAt ~= nil and now < S.retryAt then return end
    S.retryAt = nil
    local car = BridgeCar.car
    if S.car ~= car then
        S.car = car
        if S.snap == nil then capture() end
    end
    local red = (BridgeData ~= nil) and BridgeData.owner() or nil
    trackPlayerSeat(car, red)
    if S.p ~= nil then
        local alive, sq = false, nil
        pcall(function() alive = S.p:isAlive() == true end)
        pcall(function() sq = S.p:getCurrentSquare() end)
        if not alive or sq == nil then
            S.losses = S.losses + 1
            S.hide(alive and "lost" or "gone")
            S.retryAt = now + S.RETRY_TICKS
            return
        end
    end
    local seat = targetSeat(car, red)
    if seat == nil then
        if S.p ~= nil then S.hide("no seat") end
        return
    end
    if S.p == nil then
        if S.snap == nil then capture() end
        if S.snap == nil then return end
        if not create(car, seat) then return end
    end
    S.seat = seat
    place(car, seat)
end

local function installMutants()
    local m = nil
    pcall(function() m = PZTheMutants end)
    if m == nil then return end
    local fo = nil
    pcall(function() fo = m.ForeignOwnership end)
    if fo == nil or type(fo.isClaimed) ~= "function" then return end
    if fo.__notAloneSeatPuppet == true then return end
    local orig = fo.isClaimed
    local function wrapper(a, b, ...)
        local z = a
        if type(a) == "table" and a.isClaimed ~= nil then z = b end
        if S.is(z) then return true, "NotAloneSeatPuppet", "seated puppet" end
        if z ~= nil then
            local st = store(false)
            if st ~= nil and type(st.ids) == "table" then
                local id = pidOf(z)
                if id ~= nil and st.ids[id] then return true, "NotAloneSeatPuppet", "seated puppet" end
            end
        end
        return orig(a, b, ...)
    end
    fo.isClaimed = wrapper
    fo.__notAloneSeatPuppet = true
end

installMutants()

Events.OnGameStart.Add(function()
    S.sweepUntil = (Bridge ~= nil and Bridge.time or 0) + S.SWEEP_TICKS
    S.sweepQueue = {}
    installMutants()
end)

Events.OnSave.Add(function() S.hide("save") end)

Events.OnZombieDead.Add(function(z)
    if not S.is(z) then return end
    S.losses = S.losses + 1
    S.hide("dead")
    S.retryAt = (Bridge ~= nil and Bridge.time or 0) + S.RETRY_TICKS
end)

Events.OnZombieUpdate.Add(function(z)
    if z == nil then return end
    if S.is(z) then
        pcall(function() z:setVehicle4TestCollision(nil) end)
        return
    end
    if S.sweepUntil == nil or (Bridge ~= nil and Bridge.time or 0) > S.sweepUntil then return end
    if Bridge == nil then return end
    if z == Bridge.body or z == S.p then return end
    local id = pidOf(z)
    if id == nil then return end
    local st = store(false)
    if st == nil or type(st.ids) ~= "table" or not st.ids[id] then return end
    local companion = false
    if type(Bridge.isCompanion) == "function" then
        pcall(function() companion = Bridge.isCompanion(z) == true end)
    end
    if companion then return end
    local body = false
    pcall(function() body = z:getVariableBoolean("NotAloneBody") == true end)
    if body then return end
    S.sweepQueue[z] = id
end)
