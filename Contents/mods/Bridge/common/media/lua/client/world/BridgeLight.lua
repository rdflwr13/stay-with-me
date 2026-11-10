BridgeLight = BridgeLight or {}

BridgeLight.CHEAP_TICKS = 30
BridgeLight.SCAN_TICKS = 120
BridgeLight.entries = {}
BridgeLight.stats = { samples = 0, hits = 0, misses = 0, probes = 0, dirty = {}, scanMsMax = 0, lastWhy = "none" }
BridgeLight.sampleProvider = nil
BridgeLight.tickProvider = nil

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeLight] " .. tostring(text)) end end

local function cfg()
    return BridgeTorchShared ~= nil and BridgeTorchShared.CFG or nil
end

local function nowTick()
    if type(BridgeLight.tickProvider) == "function" then
        local ok, v = pcall(BridgeLight.tickProvider)
        if ok then return tonumber(v) or 0 end
    end
    return Bridge ~= nil and (tonumber(Bridge.tick) or 0) or 0
end

local function keyOf(body)
    if BridgeTorchShared == nil or type(BridgeTorchShared.keyOf) ~= "function" then return nil end
    local key = nil
    pcall(function() key = BridgeTorchShared.keyOf(body) end)
    return key
end

local function noteDirty(reason)
    BridgeLight.stats.dirty[reason] = (BridgeLight.stats.dirty[reason] or 0) + 1
    BridgeLight.stats.lastWhy = reason
end

function BridgeLight.invalidate(reason)
    BridgeLight.entries = {}
    noteDirty(tostring(reason or "start"))
end

local function blockedTo(cell, fromX, fromY, zz, tx, ty)
    if LosUtil ~= nil and type(LosUtil.lineClear) == "function" then
        local res, ok = nil, false
        ok = pcall(function() res = LosUtil.lineClear(cell, fromX, fromY, zz, tx, ty, zz, false) end)
        if ok and res ~= nil then
            local blocked = nil
            pcall(function() if LosUtil.TestResults ~= nil then blocked = LosUtil.TestResults.Blocked end end)
            if blocked ~= nil then return res == blocked end
            return tostring(res) == "Blocked"
        end
    end
    local sq, solid, solidtrans = nil, false, false
    pcall(function() sq = cell:getGridSquare(tx, ty, zz) end)
    if sq == nil then return true end
    pcall(function() solid = sq:isSolid() == true end)
    pcall(function() solidtrans = sq:isSolidTrans() == true end)
    return solid or solidtrans
end

local function foreignLightNear(body)
    local cell = getCell()
    if cell == nil then return false end
    local bx, by, bz = nil, nil, nil
    pcall(function() bx, by, bz = math.floor(body:getX() + 0.5), math.floor(body:getY() + 0.5), body:getZ() end)
    if bx == nil then return false end
    local C = cfg()
    if C == nil then return false end

    local ours = {}
    local lamps = BridgeTorch ~= nil and BridgeTorch.lamps or {}
    for _, e in pairs(lamps) do
        for i = 1, #e.sources do ours[e.sources[i]] = true end
    end

    local found, bestD, bestR, bestBri = false, nil, nil, nil
    local nearD, nearR, nearBri = nil, nil, nil
    pcall(function()
        local positions = cell:getLamppostPositions()
        if positions == nil then return end
        for i = 0, positions:size() - 1 do
            local s = positions:get(i)
            if s ~= nil and not ours[s] then
                local active = false
                pcall(function() active = s:isActive() == true end)
                if active then
                    local sx, sy, sz, rr, bri = nil, nil, nil, 0, 0
                    pcall(function()
                        sx, sy, sz = s:getX(), s:getY(), s:getZ()
                        rr = tonumber(s:getRadius()) or 0
                        local cr = tonumber(s:getR()) or 0
                        local cg = tonumber(s:getG()) or 0
                        local cb = tonumber(s:getB()) or 0
                        bri = math.max(cr, math.max(cg, cb))
                    end)
                    if sx ~= nil and sz == bz then
                        local dx, dy = sx - bx, sy - by
                        local d2 = dx * dx + dy * dy
                        local dist = math.sqrt(d2)
                        if nearD == nil or dist < nearD then
                            nearD, nearR, nearBri = dist, rr, bri
                        end
                        if rr >= 2 and bri >= C.EXTERNAL_MIN_BRI then
                            local reach = math.min(rr, C.EXTERNAL_NEAR)
                            if d2 <= reach * reach then
                                if not blockedTo(cell, sx, sy, sz, bx, by) then
                                    if bestD == nil or dist < bestD then
                                        found, bestD, bestR, bestBri = true, dist, rr, bri
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    return found, bestD, bestR, bestBri, nearD, nearR, nearBri
end

local function vcall(obj, method, ...)
    if obj == nil then return nil end
    local fn = nil
    local ok = pcall(function() fn = obj[method] end)
    if not ok or fn == nil then return nil end
    local ok2, value = pcall(fn, obj, ...)
    if not ok2 then return nil end
    return value
end

local function vehicleLightNear(body)
    local cell = getCell()
    if cell == nil then return false, nil end
    local C = cfg()
    if C == nil then return false, nil end
    local bx, by, bz = vcall(body, "getX"), vcall(body, "getY"), vcall(body, "getZ")
    if bx == nil or by == nil or bz == nil then return false, nil end
    bx, by, bz = math.floor(bx + 0.5), math.floor(by + 0.5), math.floor(bz)

    local list = vcall(cell, "getVehicles")
    if list == nil then return false, nil end

    local near = C.EXTERNAL_NEAR
    local found, bestD = false, nil
    local count = tonumber(vcall(list, "size")) or 0
    for i = 0, count - 1 do
        local v = vcall(list, "get", i)
        if v ~= nil then
            local lit = vcall(v, "hasHeadlights") == true and vcall(v, "getHeadlightsOn") == true
            if lit then
                local can = vcall(v, "getHeadlightCanEmmitLight")
                if can ~= nil then lit = can ~= false end
            end
            if lit then
                local vx, vy, vz = vcall(v, "getX"), vcall(v, "getY"), vcall(v, "getZ")
                if vx ~= nil and vy ~= nil and vz ~= nil and math.floor(vz) == bz then
                    local dx, dy = vx - bx, vy - by
                    local d2 = dx * dx + dy * dy
                    if d2 <= near * near
                        and not blockedTo(cell, math.floor(vx + 0.5), math.floor(vy + 0.5), bz, bx, by) then
                        local dist = math.sqrt(d2)
                        if bestD == nil or dist < bestD then found, bestD = true, dist end
                    end
                end
            end
        end
    end
    return found, bestD
end

local function roomLitScan(body)
    if body == nil then return false, "nobody" end
    local sq = nil
    pcall(function() sq = body:getCurrentSquare() end)
    if sq == nil then return false, "nosq" end
    local room = nil
    pcall(function() room = sq:getRoom() end)
    if room == nil then return false, "outdoor" end
    local x1, x2, y1, y2 = nil, nil, nil, nil
    pcall(function()
        local rd = room:getRoomDef()
        if rd ~= nil then
            x1, x2, y1, y2 = rd:getX(), rd:getX2(), rd:getY(), rd:getY2()
        end
    end)
    if x1 == nil then return false, "nodef" end
    local z = nil
    pcall(function() z = sq:getZ() end)
    if z == nil then return false, "noz" end

    local herRid = nil
    do
        local fn = sq.getRoomID
        if type(fn) == "function" then pcall(function() herRid = fn(sq) end) end
    end

    local cell = getCell()
    if cell == nil then return false, "nocell" end
    local lit, switchOn = false, false
    pcall(function()
        for x = x1 - 1, x2 + 1 do
            for y = y1 - 1, y2 + 1 do
                local s = cell:getGridSquare(x, y, z)
                if s ~= nil then
                    local objs = s:getObjects()
                    if objs ~= nil then
                        for i = 0, objs:size() - 1 do
                            local o = objs:get(i)
                            if o ~= nil and instanceof(o, "IsoLightSwitch") then
                                local act, can = false, false
                                pcall(function() act = o:isActivated() == true end)
                                pcall(function() can = o:canSwitchLight() == true end)
                                local sameRoom = true
                                if herRid ~= nil then
                                    local rid = nil
                                    local fn = s.getRoomID
                                    if type(fn) == "function" then pcall(function() rid = fn(s) end) end
                                    if rid == nil then
                                        local ofn = o.getRoomID
                                        if type(ofn) == "function" then pcall(function() rid = ofn(o) end) end
                                    end
                                    if rid ~= nil and rid ~= herRid then sameRoom = false end
                                end
                                if sameRoom then
                                    if act then switchOn = true end
                                    if act and can then lit = true break end
                                end
                            end
                        end
                    end
                end
            end
            if lit then break end
        end
    end)
    if lit then return true, "roomLight" end
    if switchOn then return false, "switchOnNoPower" end
    return false, "roomLightOff"
end

local function sampleRaw(body)
    local lvl = 1
    local C = cfg()
    pcall(function()
        local sq = body:getCurrentSquare()
        if sq == nil then return end
        local pnum = 0
        pcall(function()
            local p = getPlayer()
            if p ~= nil then pnum = p:getPlayerNum() or 0 end
        end)
        lvl = sq:getLightLevel(pnum)
        if lvl > 0.8 then lvl = 1 end
        local c = getClimateManager()
        if sq:isOutside() then
            if c ~= nil then lvl = math.max(c:getDayLightStrength(), lvl) end
        else
            if c ~= nil and C ~= nil then lvl = lvl + (tonumber(c:getDayLightStrength()) or 0) * C.INDOOR_DAY end
        end
    end)
    lvl = tonumber(lvl)
    if lvl == nil then lvl = 1 end
    return lvl
end

local function sampleCheap(e, body)
    local sq = nil
    pcall(function() sq = body:getCurrentSquare() end)
    local outside, inside, power, roomId = false, true, true, nil
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = body:getX(), body:getY(), body:getZ() end)
    if sq ~= nil then
        pcall(function() outside = sq:isOutside() == true end)
        pcall(function() power = sq:haveElectricity() ~= false end)
        pcall(function() roomId = sq:getRoomID() end)
    end
    pcall(function() inside = not outside end)
    local day = 0
    pcall(function()
        local c = getClimateManager()
        if c ~= nil then day = tonumber(c:getDayLightStrength()) or 0 end
    end)
    e.raw = sampleRaw(body)
    e.outside = outside == true
    e.inside = inside ~= false
    e.power = power
    e.roomId = roomId
    e.day = day
    e.x, e.y, e.z = x, y, z
end

local function sampleScans(e, body, key)
    local C = cfg()
    if C == nil then
        e.external, e.why = false, "noconfig"
        return
    end

    local day = false
    if e.outside == true then
        local ds = tonumber(e.day) or 0
        local wasDay = e.dayLit == true
        local onThr = C.DAY_OFF
        local offThr = onThr - C.DAY_HYST
        local isDay = (wasDay and ds > offThr) or (ds > onThr)
        e.dayLit = isDay
        day = isDay
    else
        e.dayLit = false
    end
    if day then
        e.external, e.why, e.externalAt = true, "daylight", getTimestampMs()
        return
    end

    local found, dist, rr, bri, nd, nr, nb = foreignLightNear(body)
    e.lamp, e.lampWhy = found == true, nil
    if found then
        e.external = true
        e.why = string.format("foreignLight d=%.1f r=%s b=%.2f", dist or -1, tostring(rr), bri or -1)
        e.externalAt = getTimestampMs()
        return
    end
    if nd ~= nil then
        e.lampWhy = string.format("none near d=%.1f r=%s b=%.2f", nd, tostring(nr), nb or -1)
    end

    local vfound, vdist = vehicleLightNear(body)
    e.vehicle, e.vehicleWhy = vfound == true, nil
    if vfound then
        local confirmed = nil
        if BridgeTorch ~= nil and key ~= nil and type(BridgeTorch.lvlAt) == "table" then
            local at = BridgeTorch.lvlAt[key]
            if at ~= nil and (getTimestampMs() - at) <= 2500 and type(BridgeTorch.lvl) == "table" then
                confirmed = BridgeTorch.lvl[key]
            end
        end
        if confirmed ~= nil and confirmed >= C.DARK_LO then
            e.external = true
            e.why = string.format("vehicleLight d=%.1f", vdist or -1)
            e.externalAt = getTimestampMs()
            return
        end
        e.vehicleWhy = "vehicleLight unconfirmed"
    end

    local rl, rw = roomLitScan(body)
    e.roomLight, e.roomWhy = rl == true, rw
    if e.outside ~= true and rl == true then
        e.external = true
        e.why = rw or "roomLight"
        e.externalAt = getTimestampMs()
        return
    end

    e.external = false
    e.externalAt = getTimestampMs()
    if nd ~= nil then
        e.why = e.lampWhy
    else
        e.why = "none"
    end
end

local function useProvider(e, body)
    if type(BridgeLight.sampleProvider) ~= "function" then return false end
    local ok, got = pcall(BridgeLight.sampleProvider, body, e)
    if not ok or type(got) ~= "table" then return false end
    for k, v in pairs(got) do e[k] = v end
    return true
end

function BridgeLight.decide(entry, lo)
    if entry == nil then return false end
    if BridgeTorchShared == nil or type(BridgeTorchShared.isDark) ~= "function" then return false end
    local lvl = entry.lvl
    if lvl == nil then lvl = entry.raw end
    local dark = false
    pcall(function() dark = BridgeTorchShared.isDark(lvl, entry.external, entry.why, lo) == true end)
    return dark
end

function BridgeLight.at(body)
    if body == nil then return nil end
    local key = keyOf(body)
    if key == nil then return nil end
    local e = BridgeLight.entries[key]
    if e == nil then
        e = { key = key, body = body }
        BridgeLight.entries[key] = e
    end

    local tick = nowTick()
    if e.returnTick == tick then return e end
    local cell = nil
    pcall(function() cell = getCell() end)
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = body:getX(), body:getY(), body:getZ() end)
    local tx = x ~= nil and math.floor(x) or nil
    local ty = y ~= nil and math.floor(y) or nil
    local tz = z ~= nil and math.floor(z) or nil
    local roomId = nil
    pcall(function()
        local sq = body:getCurrentSquare()
        if sq ~= nil then roomId = sq:getRoomID() end
    end)

    local reason = nil
    if e.cell ~= nil and cell ~= nil and e.cell ~= cell then reason = "cell" end
    if reason == nil and e.tileX ~= nil and (e.tileX ~= tx or e.tileY ~= ty or e.z ~= tz) then reason = "tile" end
    if reason == nil and e.roomId ~= nil and roomId ~= nil and e.roomId ~= roomId then reason = "room" end
    if reason ~= nil then
        noteDirty(reason)
        e.sampledTick = nil
        e.scanTick = nil
    end
    e.cell, e.tileX, e.tileY, e.z = cell, tx, ty, tz
    e.body = body
    e.roomId = roomId or e.roomId

    local cheapDue = e.sampledTick == nil or (tick - e.sampledTick) >= BridgeLight.CHEAP_TICKS
    local scanDue = e.scanTick == nil or (tick - e.scanTick) >= BridgeLight.SCAN_TICKS
    local providerUsed = false
    if cheapDue then
        providerUsed = useProvider(e, body)
        if not providerUsed then sampleCheap(e, body) end
        e.sampledTick = tick
        BridgeLight.stats.misses = BridgeLight.stats.misses + 1
        BridgeLight.stats.samples = BridgeLight.stats.samples + 1
    else
        BridgeLight.stats.hits = BridgeLight.stats.hits + 1
    end
    if scanDue and not providerUsed then
        local t0 = getTimestampMs()
        sampleScans(e, body, key)
        e.scanTick = tick
        local ms = getTimestampMs() - t0
        if ms > BridgeLight.stats.scanMsMax then BridgeLight.stats.scanMsMax = ms end
    elseif scanDue then
        e.scanTick = tick
    end
    local nowMs = getTimestampMs()
    local lvl = e.raw
    if BridgeTorch ~= nil and type(BridgeTorch.lvlAt) == "table" and type(BridgeTorch.lvl) == "table" then
        local lat = BridgeTorch.lvlAt[key]
        local settle = tonumber(BridgeTorch.SETTLE_MS) or 2000
        if lat ~= nil and (nowMs - lat) <= (settle - 500) and BridgeTorch.lvl[key] ~= nil then
            lvl = BridgeTorch.lvl[key]
        end
    end
    e.lvl = lvl
    e.dark = BridgeLight.decide(e)
    e.at = nowMs
    e.returnTick = tick
    return e
end

function BridgeLight.probe(body)
    if body == nil then return nil end
    local key = keyOf(body)
    local e = key ~= nil and BridgeLight.entries[key] or nil
    if key == nil then return nil end
    if e == nil then
        e = { key = key, body = body }
        BridgeLight.entries[key] = e
        noteDirty("beam")
    end
    if not useProvider(e, body) then sampleCheap(e, body) end
    e.sampledTick = nowTick()
    e.ambient = e.raw
    e.ambientAt = getTimestampMs()
    BridgeLight.stats.probes = BridgeLight.stats.probes + 1
    if e.scanTick == nil then
        sampleScans(e, body, key)
        e.scanTick = nowTick()
    end
    return e.raw
end

function BridgeLight.statusText()
    local st = BridgeLight.stats
    local dirty = 0
    for _, v in pairs(st.dirty) do dirty = dirty + v end
    return string.format("light samples=%d hits=%d misses=%d probes=%d dirty=%d scanMsMax=%.1f last=%s",
        st.samples, st.hits, st.misses, st.probes, dirty, st.scanMsMax or 0, tostring(st.lastWhy))
end

function BridgeLight.selftest()
    local checks, fails = 0, {}
    local function check(name, got, want)
        checks = checks + 1
        if got ~= want then
            fails[#fails + 1] = string.format("%s got=%s want=%s", name, tostring(got), tostring(want))
        end
    end
    local oldEntries, oldStats = BridgeLight.entries, BridgeLight.stats
    local oldProvider, oldTick = BridgeLight.sampleProvider, BridgeLight.tickProvider
    BridgeLight.entries = {}
    BridgeLight.stats = { samples = 0, hits = 0, misses = 0, probes = 0, dirty = {}, scanMsMax = 0, lastWhy = "none" }
    local clock = 1000
    BridgeLight.tickProvider = function() return clock end
    local body = { getX = function() return 1 end, getY = function() return 1 end, getZ = function() return 0 end,
        getCurrentSquare = function() return nil end }
    local sample = { raw = 0.10, outside = true, inside = false, power = true, roomId = nil, day = 0.10,
        external = false, why = "none", roomLight = false, vehicle = false, lamp = false }
    BridgeLight.sampleProvider = function() return sample end
    local okAll, errAll = pcall(function()
        local e = BridgeLight.at(body)
        check("entry", e ~= nil, true)
        check("dark low light", e.dark, true)
        check("sample raw", e.raw, 0.10)
        check("sample inside", e.inside, false)
        local before = BridgeLight.stats.hits
        BridgeLight.at(body)
        check("ttl hit", BridgeLight.stats.hits, before + 1)
        local misses = BridgeLight.stats.misses
        clock = clock + BridgeLight.CHEAP_TICKS
        BridgeLight.at(body)
        check("ttl miss", BridgeLight.stats.misses, misses + 1)
        BridgeLight.invalidate("tile")
        check("invalidate clears", next(BridgeLight.entries), nil)
        local e2 = BridgeLight.at(body)
        check("resample after invalidate", e2 ~= nil, true)
        local raw = BridgeLight.probe(body)
        check("probe returns raw", raw, 0.10)
        check("probe ambient", e2.ambient, 0.10)
        local lit = { raw = 0.10, outside = true, inside = false, power = true, day = 0.10,
            external = true, why = "daylight" }
        BridgeLight.sampleProvider = function() return lit end
        BridgeLight.invalidate("torch")
        check("external override", BridgeLight.at(body).dark, false)
        local bright = { raw = 0.90, outside = true, inside = false, power = true, day = 0.90,
            external = false, why = "none" }
        BridgeLight.sampleProvider = function() return bright end
        BridgeLight.invalidate("torch")
        check("bright not dark", BridgeLight.at(body).dark, false)
        check("nil body", BridgeLight.at(nil), nil)
    end)
    BridgeLight.entries, BridgeLight.stats = oldEntries, oldStats
    BridgeLight.sampleProvider, BridgeLight.tickProvider = oldProvider, oldTick
    if not okAll then fails[#fails + 1] = "selftest error: " .. tostring(errAll) end
    if #fails == 0 then return string.format("lightselftest PASS (%d checks)", checks) end
    return string.format("lightselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end

Events.OnGameStart.Add(function() pcall(BridgeLight.invalidate, "start") end)
Events.OnResetLua.Add(function() pcall(BridgeLight.invalidate, "start") end)
Events.OnCreatePlayer.Add(function() pcall(BridgeLight.invalidate, "start") end)
Events.OnPlayerDeath.Add(function() pcall(BridgeLight.invalidate, "start") end)

log("loaded")
