BridgeZScan = BridgeZScan or {}
local S = BridgeZScan

S.enabled = true
S.debug = 0
S.WARN_MS = 2.0
S.BUCKET_AT = 150
S.BUCKET = 8
S.BUCKET_REPEAT = 40

S.TAGS = {
    ["callout.scan"] = true,
    ["scan.frame"] = true,
    ["fight.crowd"] = true,
    ["fight.pick"] = true,
    ["fight.extra"] = true,
    ["fight.shove"] = true,
    ["gun.pick"] = true,
    ["gun.friendlies"] = true,
    ["gun.candidates"] = true,
    ["gun.target"] = true,
    ["gun.extra"] = true,
    ["horde.count"] = true,
    ["horde.count.seen"] = true,
    ["horde.cone"] = true,
    ["task.danger"] = true,
    ["ambient.danger"] = true,
    ["drive.greet"] = true,
    ["drive.exit"] = true,
    ["social.busy"] = true,
    ["moments.danger"] = true,
    ["mood.calm"] = true,
    ["heal.threat"] = true,
    ["wash.threat"] = true,
    ["sleep.calm"] = true,
    ["aim.beyond"] = true,
    ["sleep.only"] = true,
    ["sleep.search"] = true,
    ["sleep.speed"] = true,
    ["fastforward.sight"] = true,
    ["watch.others"] = true,
    ["server.othersNear"] = true,
}

local function newStats()
    return {
        tick = 0,
        refBuilds = 0, coordBuilds = 0, listReads = 0,
        queries = 0, candidates = 0,
        queriesNear = 0, queriesUnion = 0, queriesCone = 0, queriesCount = 0, queriesFind = 0,
        filterRejects = 0, memoHits = 0, memoMisses = 0, fallbacks = 0,
        invalidations = { tick = 0, start = 0, cell = 0 },
        buildMsLast = 0, buildMsMax = 0, queryMsLast = 0, queryMsMax = 0,
        unattributed = 0, lastError = nil,
        byTag = {}, lastQuery = {},
    }
end

S.stats = newStats()

S.tickOf = nil
S.cellOf = nil
S.listProvider = nil
S.isCompanionOf = nil
S.isRemoteOf = nil
S.isHarmlessOf = nil
S.isDraggedOf = nil
S.isOwnerRisenOf = nil

S.traceTag = nil
S.traceUntil = nil

local snap = nil
local memo = nil
local failedTick = nil
local failedCell = nil
local lastRefBuildTick = nil
local invSec = nil
local invCount = 0
local nextSummary = 0
local warnNext = {}
local quietSelf = false

local LIST_MT = {
    size = function(self) return #self.a end,
    get = function(self, i) return self.a[i + 1] end,
}
LIST_MT.__index = LIST_MT

local function adapter(a)
    return setmetatable({ a = a }, LIST_MT)
end

local function toList(arr, opts)
    if type(opts) == "table" and type(opts.out) == "table" then
        local out = opts.out
        for i = 1, #arr do out[i] = arr[i] end
        for i = #arr + 1, #out do out[i] = nil end
        return adapter(out)
    end
    return adapter(arr)
end

local function nowMs()
    if getTimestampMs == nil then return 0 end
    local ok, t = pcall(getTimestampMs)
    if ok and type(t) == "number" then return t end
    return 0
end

local function tickNow()
    local f = S.tickOf
    if type(f) == "function" then
        local ok, v = pcall(f)
        if ok and tonumber(v) ~= nil then return tonumber(v) end
    end
    if BridgeServer ~= nil and tonumber(BridgeServer.tick) ~= nil then return tonumber(BridgeServer.tick) end
    if Bridge ~= nil and tonumber(Bridge.tick) ~= nil then return tonumber(Bridge.tick) end
    return 0
end

local function cellNow()
    local f = S.cellOf
    if type(f) == "function" then
        local ok, v = pcall(f)
        if ok then return v end
        return nil
    end
    if getCell == nil then return nil end
    local ok, v = pcall(getCell)
    if ok then return v end
    return nil
end

local function clientNow()
    if isClient == nil then return false end
    local ok, v = pcall(isClient)
    return ok and v == true
end

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[zscan] " .. tostring(text)) end
end

local function thrashCheck()
    local now = nowMs()
    if invSec == nil or now - invSec >= 1000 then
        invSec = now
        invCount = 0
    end
    invCount = invCount + 1
    if invCount > 10 and not quietSelf then
        local tick = tickNow()
        if tick >= (warnNext.thrash or 0) then
            warnNext.thrash = tick + 300
            log("invalidation thrash: " .. tostring(invCount) .. " in one second")
        end
    end
end

local function warn(key, text)
    if quietSelf then return end
    local tick = tickNow()
    if tick < (warnNext[key] or 0) then return end
    warnNext[key] = tick + 300
    log(text)
end

local function resetStats()
    local s = S.stats
    s.tick = 0
    s.refBuilds, s.coordBuilds, s.listReads = 0, 0, 0
    s.queries, s.candidates = 0, 0
    s.queriesNear, s.queriesUnion, s.queriesCone, s.queriesCount, s.queriesFind = 0, 0, 0, 0, 0
    s.filterRejects, s.memoHits, s.memoMisses, s.fallbacks = 0, 0, 0, 0
    s.invalidations.tick, s.invalidations.start, s.invalidations.cell = 0, 0, 0
    s.buildMsLast, s.buildMsMax, s.queryMsLast, s.queryMsMax = 0, 0, 0, 0
    s.unattributed = 0
    s.lastError = nil
    for k in pairs(s.byTag) do s.byTag[k] = nil end
    for k in pairs(s.lastQuery) do s.lastQuery[k] = nil end
end

local STAT_FLAT = {
    "tick", "refBuilds", "coordBuilds", "listReads", "queries", "candidates",
    "queriesNear", "queriesUnion", "queriesCone", "queriesCount", "queriesFind",
    "filterRejects", "memoHits", "memoMisses", "fallbacks",
    "buildMsLast", "buildMsMax", "queryMsLast", "queryMsMax", "unattributed",
}

local function copyStats()
    local s = S.stats
    local c = {
        byTag = {}, lastQuery = {},
        invalidations = {
            tick = s.invalidations.tick,
            start = s.invalidations.start,
            cell = s.invalidations.cell,
        },
        lastError = s.lastError,
    }
    for _, k in ipairs(STAT_FLAT) do c[k] = s[k] end
    for k, v in pairs(s.byTag) do
        local r = {}
        for kk, vv in pairs(v) do r[kk] = vv end
        c.byTag[k] = r
    end
    for k, v in pairs(s.lastQuery) do c.lastQuery[k] = v end
    return c
end

local function applyStats(c)
    local s = S.stats
    for _, k in ipairs(STAT_FLAT) do s[k] = c[k] end
    s.invalidations.tick = c.invalidations.tick
    s.invalidations.start = c.invalidations.start
    s.invalidations.cell = c.invalidations.cell
    s.lastError = c.lastError
    for k in pairs(s.byTag) do s.byTag[k] = nil end
    for k, v in pairs(c.byTag) do s.byTag[k] = v end
    for k in pairs(s.lastQuery) do s.lastQuery[k] = nil end
    for k, v in pairs(c.lastQuery) do s.lastQuery[k] = v end
end

local WEAK_K = { __mode = "k" }

local function newMemo(tick)
    return { tick = tick, q = {} }
end

local function field(m, k)
    local t = m[k]
    if t == nil then
        t = setmetatable({}, WEAK_K)
        m[k] = t
    end
    return t
end

local function memoNow()
    local tick
    if snap ~= nil then
        tick = snap.tick
    else
        tick = tickNow()
    end
    if memo == nil or memo.tick ~= tick then memo = newMemo(tick) end
    return memo
end

local function bodyVar()
    if Bridge ~= nil and type(Bridge.BODY_VAR) == "string" then return Bridge.BODY_VAR end
    return "NotAloneBody"
end

function S.isAlive(z)
    if z == nil then return false end
    local m = memoNow()
    local t = m.alive
    local v = t and t[z]
    if v ~= nil then
        S.stats.memoHits = S.stats.memoHits + 1
        return v
    end
    S.stats.memoMisses = S.stats.memoMisses + 1
    v = false
    local ok, got = pcall(z.isAlive, z)
    if ok then v = got == true end
    t = field(m, "alive")
    t[z] = v
    return v
end

function S.healthUp(z)
    if z == nil then return false end
    local m = memoNow()
    local t = m.health
    local v = t and t[z]
    if v ~= nil then
        S.stats.memoHits = S.stats.memoHits + 1
        return v
    end
    S.stats.memoMisses = S.stats.memoMisses + 1
    v = false
    local ok, got = pcall(z.getHealth, z)
    if ok and type(got) == "number" then v = got > 0 end
    t = field(m, "health")
    t[z] = v
    return v
end

function S.isCompanion(z)
    if z == nil then return false end
    local m = memoNow()
    local t = m.comp
    local v = t and t[z]
    if v ~= nil then
        S.stats.memoHits = S.stats.memoHits + 1
        return v
    end
    S.stats.memoMisses = S.stats.memoMisses + 1
    v = false
    local var = bodyVar()
    local ok, got = pcall(z.getVariableBoolean, z, var)
    if ok then v = got == true end
    if not v then
        local f = S.isCompanionOf
        if type(f) ~= "function" then
            if clientNow() and Bridge ~= nil and type(Bridge.isCompanion) == "function" then
                f = Bridge.isCompanion
            elseif BridgeServer ~= nil and type(BridgeServer.isCompanionBody) == "function" then
                f = BridgeServer.isCompanionBody
            end
        end
        if type(f) == "function" then
            local ok2, got2 = pcall(f, z)
            if ok2 then v = got2 == true end
        end
    end
    t = field(m, "comp")
    t[z] = v
    return v
end

function S.isRemote(z)
    if z == nil then return false end
    local m = memoNow()
    local t = m.rem
    local v = t and t[z]
    if v ~= nil then
        S.stats.memoHits = S.stats.memoHits + 1
        return v
    end
    S.stats.memoMisses = S.stats.memoMisses + 1
    v = false
    local f = S.isRemoteOf
    if type(f) == "function" then
        local ok, got = pcall(f, z)
        if ok then v = got == true end
    elseif clientNow() then
        local ok, got = pcall(z.isRemoteZombie, z)
        if ok then v = got == true end
    end
    t = field(m, "rem")
    t[z] = v
    return v
end

function S.isHarmless(z)
    if z == nil then return false end
    local m = memoNow()
    local t = m.harm
    local v = t and t[z]
    if v ~= nil then
        S.stats.memoHits = S.stats.memoHits + 1
        return v
    end
    S.stats.memoMisses = S.stats.memoMisses + 1
    v = false
    local f = S.isHarmlessOf
    if type(f) ~= "function" and BridgeData ~= nil and type(BridgeData.harmless) == "function" then
        f = BridgeData.harmless
    end
    if type(f) == "function" then
        local ok, got = pcall(f, z)
        if ok then v = got == true end
    end
    t = field(m, "harm")
    t[z] = v
    return v
end

function S.isDragged(z)
    if z == nil then return false end
    local m = memoNow()
    local t = m.drag
    local v = t and t[z]
    if v ~= nil then
        S.stats.memoHits = S.stats.memoHits + 1
        return v
    end
    S.stats.memoMisses = S.stats.memoMisses + 1
    v = false
    local f = S.isDraggedOf
    if type(f) ~= "function" and BridgeData ~= nil and type(BridgeData.dragged) == "function" then
        f = BridgeData.dragged
    end
    if type(f) == "function" then
        local ok, got = pcall(f, z)
        if ok then v = got == true end
    end
    t = field(m, "drag")
    t[z] = v
    return v
end

function S.isOwnerRisen(z, red)
    if z == nil then return false end
    local m = memoNow()
    local t = m.risen
    local v = t and t[z]
    if v ~= nil then
        S.stats.memoHits = S.stats.memoHits + 1
        return v
    end
    S.stats.memoMisses = S.stats.memoMisses + 1
    v = false
    local f = S.isOwnerRisenOf
    if type(f) ~= "function" and BridgeFight ~= nil and type(BridgeFight.ownerRisen) == "function" then
        f = BridgeFight.ownerRisen
    end
    if type(f) == "function" then
        local ok, got = pcall(f, z, red)
        if ok then v = got == true end
    end
    t = field(m, "risen")
    t[z] = v
    return v
end

function S.isThreat(z)
    if z == nil then return false end
    local m = memoNow()
    local t = m.threat
    local v = t and t[z]
    if v ~= nil then
        S.stats.memoHits = S.stats.memoHits + 1
        return v
    end
    S.stats.memoMisses = S.stats.memoMisses + 1
    v = S.isAlive(z) and S.healthUp(z) and not S.isCompanion(z)
        and not S.isRemote(z) and not S.isHarmless(z)
    t = field(m, "threat")
    t[z] = v
    return v
end

local function currentMemo()
    if snap == nil or memo == nil then return nil end
    local t = nil
    if Bridge ~= nil then t = tonumber(Bridge.tick) end
    if t == nil then t = tickNow() end
    if snap.tick ~= t then return nil end
    if memo.tick ~= snap.tick then return nil end
    return memo
end

function S.cachedBodyVar(z)
    if z == nil then return nil end
    local m = currentMemo()
    if m == nil then return nil end
    local t = m.bod
    if t == nil then return nil end
    return t[z]
end

function S.cachedCompanion(z)
    if z == nil then return nil end
    local m = currentMemo()
    if m == nil then return nil end
    local t = m.comp
    if t == nil then return nil end
    return t[z]
end

function S.cachedRemote(z)
    if z == nil then return nil end
    local m = currentMemo()
    if m == nil then return nil end
    local t = m.rem
    if t == nil then return nil end
    return t[z]
end

function S.cachedHarmless(z)
    if z == nil then return nil end
    local m = currentMemo()
    if m == nil then return nil end
    local t = m.harm
    if t == nil then return nil end
    return t[z]
end

function S.cachedOutfit(z)
    return nil
end

local MEMO_MAX = 32

local function round2(v)
    local n = tonumber(v) or 0
    return math.floor(n * 10000 + (n >= 0 and 0.5 or -0.5))
end


local function filterKey(f)
    if f == nil then return "-" end
    if type(f) == "string" then return "s:" .. f end
    return "f:" .. tostring(f)
end


local function memGet(kind, key)
    local m = memoNow()
    local bucket = m.q[kind]
    if bucket == nil then return nil end
    local v = bucket[key]
    if v ~= nil then S.stats.memoHits = S.stats.memoHits + 1 end
    return v
end


local function memPut(kind, key, value)
    local m = memoNow()
    local bucket = m.q[kind]
    if bucket == nil then
        bucket = { n = 0 }
        m.q[kind] = bucket
    end
    if bucket.n >= MEMO_MAX then return end
    bucket[key] = value
    bucket.n = bucket.n + 1
end


local function visGet(viewer, z)
    if viewer == nil or z == nil then return nil end
    local m = memoNow()
    local outer = m.vis
    if outer == nil then return nil end
    local byViewer = outer[viewer]
    if byViewer == nil then return nil end
    local v = byViewer[z]
    if v ~= nil then S.stats.memoHits = S.stats.memoHits + 1 end
    return v
end


local function visPut(viewer, z, v)
    if viewer == nil or z == nil then return end
    local m = memoNow()
    local outer = field(m, "vis")
    local byViewer = outer[viewer]
    if byViewer == nil then
        byViewer = setmetatable({}, WEAK_K)
        outer[viewer] = byViewer
    end
    byViewer[z] = v
end


function S.canSee(z, a, b)
    if z == nil then return false end
    local seen = false
    if a ~= nil then
        local v = visGet(a, z)
        if v == nil then
            local got = false
            pcall(function() got = a:CanSee(z) == true end)
            S.stats.memoMisses = S.stats.memoMisses + 1
            visPut(a, z, got)
            v = got
        end
        seen = v
    end
    if not seen and b ~= nil and b ~= a then
        local v = visGet(b, z)
        if v == nil then
            local got = false
            pcall(function() got = b:CanSee(z) == true end)
            S.stats.memoMisses = S.stats.memoMisses + 1
            visPut(b, z, got)
            v = got
        end
        seen = v
    end
    return seen
end

local PROFILES = {
    canonical = function(z) return S.isThreat(z) end,
    alert = function(z)
        return S.isAlive(z) and S.healthUp(z) and not S.isCompanion(z) and not S.isHarmless(z)
    end,
    social = function(z)
        return S.isAlive(z) and not S.isCompanion(z) and not S.isHarmless(z)
    end,
    sleep = function(z)
        return S.isAlive(z) and not S.isCompanion(z) and not S.isDragged(z)
    end,
    raw = function() return true end,
}
S.PROFILES = PROFILES

local function filterOf(f)
    if type(f) == "function" then return f end
    if type(f) == "string" then return PROFILES[f] end
    return nil
end

local rawTick, rawList = nil, nil

local function readRawList()
    local tick = tickNow()
    if rawTick == tick and rawList ~= nil then return rawList end
    local list = nil
    if type(S.listProvider) == "function" then
        local ok, got = pcall(S.listProvider)
        if ok then list = got else S.stats.lastError = "list provider failed" end
    else
        local cell = cellNow()
        if cell == nil then return nil end
        local ok, got = pcall(cell.getZombieList, cell)
        if ok then list = got else S.stats.lastError = "list read failed" end
    end
    if list ~= nil then rawTick, rawList = tick, list end
    return list
end

local function readZombieList(cell)
    if type(S.listProvider) == "function" then return S.listProvider() end
    return cell:getZombieList()
end

local function fillRefs(list, refs)
    local n = 0
    local sz = list:size()
    for i = 0, sz - 1 do
        local z = list:get(i)
        if z ~= nil then
            n = n + 1
            refs[n] = z
        end
    end
    return n
end

local function buildRefs()
    local started = nowMs()
    local tick = tickNow()
    local cell = cellNow()
    if cell == nil then
        S.stats.lastError = "no cell"
        warn("nocell", "no cell for zombie scan")
        failedTick, failedCell = tick, cell
        S.stats.fallbacks = S.stats.fallbacks + 1
        return nil
    end
    local ok, list = pcall(readZombieList, cell)
    S.stats.listReads = S.stats.listReads + 1
    if not ok or list == nil then
        S.stats.lastError = "nil zombie list: " .. tostring(list)
        warn("nolist", "nil zombie list")
        failedTick, failedCell = tick, cell
        S.stats.fallbacks = S.stats.fallbacks + 1
        return nil
    end

    local refs = {}
    local ok2, n = pcall(fillRefs, list, refs)
    if ok2 then
        n = tonumber(n) or 0
    end
    if not ok2 then
        S.stats.lastError = "ref build failed: " .. tostring(n)
        warn("refbuild", "ref build failed: " .. tostring(n))
        failedTick, failedCell = tick, cell
        S.stats.fallbacks = S.stats.fallbacks + 1
        return nil
    end

    snap = {
        tick = tick,
        listTick = tick,
        cell = cell,
        refs = refs,
        n = n,
        level = 0,
        xs = nil, ys = nil, zs = nil,
        alive = nil, bod = nil, rem = nil,
        buckets = nil,
    }
    S.stats.refBuilds = S.stats.refBuilds + 1
    if lastRefBuildTick == tick then
        warn("multibuild", "more than one ref build in tick " .. tostring(tick))
    end
    lastRefBuildTick = tick
    local ms = nowMs() - started
    S.stats.buildMsLast = ms
    if ms > S.stats.buildMsMax then S.stats.buildMsMax = ms end
    if ms > S.WARN_MS then warn("buildms", string.format("ref build took %.2f ms", ms)) end
    if S.stats.listReads ~= S.stats.refBuilds then
        warn("misaligned", string.format("listReads=%d refBuilds=%d", S.stats.listReads, S.stats.refBuilds))
    end
    return snap
end

local buildCoords

local function refreshRefs(maxAge)
    maxAge = tonumber(maxAge) or 1
    if maxAge < 1 then maxAge = 1 end
    local tick = tickNow()
    local cell = cellNow()
    S.stats.tick = tick
    local rebuild, listRead = false, false
    if snap == nil then
        rebuild, listRead = true, true
    elseif snap.cell ~= cell then
        local inv = S.stats.invalidations
        inv.cell = (inv.cell or 0) + 1
        thrashCheck()
        snap = nil
        failedTick, failedCell = nil, nil
        rebuild, listRead = true, true
    elseif maxAge <= 1 then
        if snap.tick ~= tick then
            local inv = S.stats.invalidations
            inv.tick = (inv.tick or 0) + 1
            snap = nil
            failedTick, failedCell = nil, nil
            rebuild, listRead = true, true
        end
    elseif tick - (snap.tick or tick) >= maxAge then
        local listAge = tonumber(S.listAge) or 15
        if listAge < 1 then listAge = 1 end
        if tick - (snap.listTick or snap.tick or tick) >= listAge then
            snap = nil
            failedTick, failedCell = nil, nil
            rebuild, listRead = true, true
        else
            rebuild, listRead = true, false
        end
    end
    if not rebuild then return snap end
    if listRead then
        if failedTick == tick and failedCell == cell then return nil end
        return buildRefs()
    end
    if snap == nil then return nil end
    snap.tick = tick
    snap.level = 0
    return buildCoords()
end

local function readOne(z, xs, ys, zs, alive, bod, rem, i, var, remoteHook, isClientNow)
    xs[i] = z:getX()
    ys[i] = z:getY()
    zs[i] = z:getZ()
    alive[i] = z:isAlive() == true
    bod[i] = z:getVariableBoolean(var) == true
    if type(remoteHook) == "function" then
        rem[i] = remoteHook(z) == true
    elseif isClientNow then
        rem[i] = z:isRemoteZombie() == true
    else
        rem[i] = false
    end
end

local scratch = { xs = {}, ys = {}, zs = {}, alive = {}, bod = {}, rem = {}, n = 0 }

local function ensureBuckets(s)
    if s.buckets ~= nil then return end
    local repeatUse = (s.qn or 0) > 1 and s.n > S.BUCKET_REPEAT
    if s.n <= S.BUCKET_AT and not repeatUse then return end
    local xs, ys = s.xs, s.ys
    if xs == nil or ys == nil then return end
    local buckets = {}
    local B = S.BUCKET
    for i = 1, s.n do
        if xs[i] ~= nil and ys[i] ~= nil then
            local bx = math.floor(xs[i] / B)
            local by = math.floor(ys[i] / B)
            local layer = buckets[bx]
            if layer == nil then layer = {}; buckets[bx] = layer end
            local col = layer[by]
            if col == nil then col = {}; layer[by] = col end
            col[#col + 1] = i
        end
    end
    s.buckets = buckets
end

buildCoords = function()
    local s = snap
    if s == nil then return nil end
    if s.level >= 1 then return s end
    local started = nowMs()
    local reuse = not quietSelf
    local xs = reuse and scratch.xs or {}
    local ys = reuse and scratch.ys or {}
    local zs = reuse and scratch.zs or {}
    local alive = reuse and scratch.alive or {}
    local bod = reuse and scratch.bod or {}
    local rem = reuse and scratch.rem or {}
    local isClientNow = clientNow()
    local remoteHook = S.isRemoteOf
    local var = bodyVar()
    local m = memoNow()
    local ma, mr, mb = field(m, "alive"), field(m, "rem"), field(m, "bod")
    local mc = nil
    for i = 1, s.n do
        local z = s.refs[i]
        xs[i], ys[i], zs[i] = nil, nil, nil
        alive[i], bod[i], rem[i] = nil, nil, nil
        local ok = pcall(readOne, z, xs, ys, zs, alive, bod, rem, i, var, remoteHook, isClientNow)
        if not ok then
            xs[i], ys[i], zs[i] = nil, nil, nil
            alive[i], bod[i], rem[i] = nil, nil, nil
        elseif z ~= nil then
            if alive[i] ~= nil then ma[z] = alive[i] end
            if rem[i] ~= nil then mr[z] = rem[i] end
            if bod[i] ~= nil then mb[z] = bod[i] end
            if bod[i] == true then
                if mc == nil then mc = field(m, "comp") end
                mc[z] = true
            end
        end
    end
    if reuse and scratch.n > s.n then
        for i = s.n + 1, scratch.n do
            xs[i], ys[i], zs[i] = nil, nil, nil
            alive[i], bod[i], rem[i] = nil, nil, nil
        end
    end
    if reuse then scratch.n = s.n end
    s.xs, s.ys, s.zs = xs, ys, zs
    s.alive, s.bod, s.rem = alive, bod, rem
    s.level = 1
    s.buckets = nil

    S.stats.coordBuilds = S.stats.coordBuilds + 1
    local ms = nowMs() - started
    S.stats.buildMsLast = ms
    if ms > S.stats.buildMsMax then S.stats.buildMsMax = ms end
    if ms > S.WARN_MS then warn("coordms", string.format("coord build took %.2f ms", ms)) end
    return s
end

local function ensureCoords(maxAge)
    local s = refreshRefs(maxAge)
    if s == nil then return nil end
    s.qn = (s.qn or 0) + 1
    if s.level >= 1 then return s end
    return buildCoords()
end

function S.refresh()
    return refreshRefs()
end

function S.ready()
    return snap ~= nil
end

S.listAge = 15

S.TAG_AGE = {
    ["mood.calm"] = "zscan",
    ["social.busy"] = "zscan",
    ["ambient.danger"] = "zscan",
    ["moments.danger"] = "zscan",
    ["drive.greet"] = "zscan",
    ["drive.exit"] = "zscan",
    ["fastforward.sight"] = "zscan",
    ["watch.others"] = "zscan",
    ["fight.crowd"] = "zscan",
    ["fight.pick"] = "zscan",
    ["fight.extra"] = "zscan",
    ["fight.shove"] = "zscan",
    ["gun.pick"] = "zscan",
    ["gun.target"] = "zscan",
    ["callout.scan"] = "zscanShort",
    ["horde.count"] = "zscanShort",
    ["horde.count.seen"] = "zscanShort",
    ["horde.cone"] = "zscanShort",
    ["server.othersNear"] = "zscanShort",
    ["heal.threat"] = "zscanTight",
    ["wash.threat"] = "zscanTight",
    ["task.danger"] = "zscanTight",
    ["scan.frame"] = "zscanTight",
    ["gun.friendlies"] = "zscan",
    ["gun.extra"] = "zscanTight",
    ["sleep.calm"] = "zscanTight",
    ["aim.beyond"] = "zscanTight",
    ["sleep.only"] = "zscanTight",
    ["sleep.search"] = "zscanTight",
    ["sleep.speed"] = "zscanTight",
}

local function optsTag(opts)
    if type(opts) ~= "table" then return nil end
    if type(opts.tag) == "string" then return opts.tag end
    return nil
end

local function optsAge(opts)
    if type(opts) ~= "table" then return 1 end
    local age = tonumber(opts.age)
    if age ~= nil and age >= 1 then return math.floor(age) end
    local kind = opts.tag ~= nil and S.TAG_AGE[opts.tag] or nil
    if kind ~= nil and BridgePerf ~= nil and type(BridgePerf.age) == "function" then
        local v = tonumber(BridgePerf.age(kind, 1))
        if v ~= nil and v >= 1 then return math.floor(v) end
    end
    return 1
end

local function optsZ(opts)
    if type(opts) ~= "table" then return nil, 0.8 end
    local z = tonumber(opts.z)
    if z == nil then return nil, 0.8 end
    local tol = tonumber(opts.zTol) or 0.8
    return z, tol
end

local QUERY_KEY = {
    Near = "queriesNear",
    Union = "queriesUnion",
    Cone = "queriesCone",
    Count = "queriesCount",
    Find = "queriesFind",
}

local function beginQuery(kind, tag)
    local s = S.stats
    s.queries = s.queries + 1
    local key = QUERY_KEY[kind]
    if key ~= nil then s[key] = (s[key] or 0) + 1 end
    if tag == nil then
        s.unattributed = s.unattributed + 1
    elseif not S.TAGS[tag] then
        warn("unknown:" .. tag, "query tag not registered: " .. tostring(tag))
    end
    if tag ~= nil and S.debug >= 1 then
        local rec = s.byTag[tag]
        if rec == nil then
            rec = { q = 0, cand = 0, rejects = 0, lastMs = 0, maxMs = 0, lastTick = 0, lastScan = nil }
            s.byTag[tag] = rec
        end
        rec.q = rec.q + 1
    end
    return tag
end

local function tracing(tag)
    if tag == nil then return false end
    if S.debug >= 2 then return true end
    if S.traceTag == nil or S.traceTag ~= tag then return false end
    if S.traceUntil ~= nil and tickNow() > S.traceUntil then
        S.traceTag = nil
        return false
    end
    return true
end

local function finishQuery(kind, tag, accepted, rejects, scanned, rejZ, rejFilter, ms)
    local s = S.stats
    s.candidates = s.candidates + accepted
    s.filterRejects = s.filterRejects + rejects
    s.queryMsLast = ms
    if ms > s.queryMsMax then s.queryMsMax = ms end
    local lvl = snap ~= nil and snap.level or 0
    local bucket = snap ~= nil and snap.buckets ~= nil
    if tag ~= nil and S.debug >= 1 then
        local rec = s.byTag[tag]
        if rec ~= nil then
            rec.cand = rec.cand + accepted
            rec.rejects = rec.rejects + rejects
            rec.lastMs = ms
            if ms > rec.maxMs then rec.maxMs = ms end
            rec.lastTick = s.tick
            rec.lastScan = scanned
        end
        s.lastQuery[tag] = {
            kind = kind,
            accepted = accepted,
            rejects = rejects,
            scanned = scanned,
            rejZ = rejZ or 0,
            rejFilter = rejFilter or 0,
            ms = ms,
            tick = s.tick,
            level = lvl,
            bucket = bucket,
        }
    end
    if tracing(tag) then
        print(string.format("[zscan] trace %s %s scanned=%d acc=%d rej=%d ms=%.2f tick=%d L%d bucket=%s",
            tostring(tag), tostring(kind), scanned or 0, accepted, rejects, ms, s.tick, lvl,
            bucket and "on" or "off"))
    end
    if not quietSelf and s.tick >= nextSummary and BridgeLog ~= nil and BridgeLog.on() then
        nextSummary = s.tick + 300
        log(S.diagLine())
    end
end

local function zReject(s, idx, z, tol)
    if z == nil then return false end
    if s.zs[idx] == nil then return false end
    return math.abs(s.zs[idx] - z) >= tol
end

local function filterPass(fn, z)
    if fn == nil then return true, false end
    local ok, v = pcall(fn, z)
    if not ok then
        S.stats.lastError = "filter failed: " .. tostring(v)
        return false, true
    end
    return v == true, false
end

local function gatherRadius(s, out, x, y, radius, seen)
    local r2 = radius * radius
    if radius > 0 then ensureBuckets(s) end
    if s.buckets ~= nil then
        local B = S.BUCKET
        local minBX, maxBX = math.floor((x - radius) / B), math.floor((x + radius) / B)
        local minBY, maxBY = math.floor((y - radius) / B), math.floor((y + radius) / B)
        for bx = minBX, maxBX do
            local layer = s.buckets[bx]
            if layer ~= nil then
                for by = minBY, maxBY do
                    local col = layer[by]
                    if col ~= nil then
                        for k = 1, #col do
                            local idx = col[k]
                            if not seen[idx] then
                                local dx, dy = s.xs[idx] - x, s.ys[idx] - y
                                if dx * dx + dy * dy <= r2 then
                                    seen[idx] = true
                                    out[#out + 1] = idx
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        for i = 1, s.n do
            if s.xs[i] ~= nil and not seen[i] then
                local dx, dy = s.xs[i] - x, s.ys[i] - y
                if dx * dx + dy * dy <= r2 then
                    seen[i] = true
                    out[#out + 1] = i
                end
            end
        end
    end
end

local function scanNear(s, out, x, y, radius, opts)
    local zf, tol = optsZ(opts)
    local fn = type(opts) == "table" and opts.filter or nil
    local seen = {}
    local cand = {}
    if radius > 0 then gatherRadius(s, cand, x, y, radius, seen) end
    local scanned, rejZ, rejF = 0, 0, 0
    for i = 1, #cand do
        local idx = cand[i]
        local z = s.refs[idx]
        if z ~= nil then
            scanned = scanned + 1
            if zf ~= nil and zReject(s, idx, zf, tol) then
                rejZ = rejZ + 1
            else
                local pass = filterPass(fn, z)
                if pass then out[#out + 1] = idx else rejF = rejF + 1 end
            end
        end
    end
    return scanned, rejZ, rejF
end

local function scanUnion(s, out, x1, y1, x2, y2, radius, opts)
    local zf, tol = optsZ(opts)
    local fn = type(opts) == "table" and opts.filter or nil
    local cand, seen = {}, {}
    if radius > 0 then
        gatherRadius(s, cand, x1, y1, radius, seen)
        gatherRadius(s, cand, x2, y2, radius, seen)
    end
    local scanned, rejZ, rejF = 0, 0, 0
    for i = 1, #cand do
        local idx = cand[i]
        local z = s.refs[idx]
        if z ~= nil then
            scanned = scanned + 1
            if zf ~= nil and zReject(s, idx, zf, tol) then
                rejZ = rejZ + 1
            else
                local pass = filterPass(fn, z)
                if pass then out[#out + 1] = idx else rejF = rejF + 1 end
            end
        end
    end
    return scanned, rejZ, rejF
end

local function scanCone(s, out, x, y, fx, fy, minD, maxD, half, opts)
    local zf, tol = optsZ(opts)
    local fn = type(opts) == "table" and opts.filter or nil
    local cand, seen = {}, {}
    local radius = math.sqrt(maxD * maxD + half * half) + 0.5
    if radius > 0 then gatherRadius(s, cand, x, y, radius, seen) end
    local scanned, rejZ, rejF = 0, 0, 0
    for i = 1, #cand do
        local idx = cand[i]
        local z = s.refs[idx]
        if z ~= nil and s.xs[idx] ~= nil then
            local rx, ry = s.xs[idx] - x, s.ys[idx] - y
            local along = rx * fx + ry * fy
            local side = ry * fx - rx * fy
            if along >= minD and along <= maxD and math.abs(side) <= half then
                scanned = scanned + 1
                if zf ~= nil and zReject(s, idx, zf, tol) then
                    rejZ = rejZ + 1
                else
                    local pass = filterPass(fn, z)
                    if pass then out[#out + 1] = idx else rejF = rejF + 1 end
                end
            end
        end
    end
    return scanned, rejZ, rejF
end

local function refsOf(s, idxs)
    local arr = {}
    for i = 1, #idxs do arr[i] = s.refs[idxs[i]] end
    return arr
end

function S.invalidate(reason)
    local r = reason or "start"
    if r ~= "tick" and r ~= "cell" and r ~= "start" then r = "start" end
    if snap ~= nil then
        local inv = S.stats.invalidations
        inv[r] = (inv[r] or 0) + 1
        thrashCheck()
    end
    snap = nil
    memo = nil
    failedTick, failedCell = nil, nil
end

function S.near(x, y, r, opts)
    local tag = optsTag(opts)
    if not S.enabled then
        beginQuery("Near", tag)
        S.stats.fallbacks = S.stats.fallbacks + 1
        warn("disabled", "scan disabled, returning raw list")
        local list = readRawList()
        finishQuery("near", tag, list ~= nil and list:size() or 0, 0, 0, 0, 0, 0)
        return list
    end
    beginQuery("Near", tag)
    local started = nowMs()
    local s = ensureCoords(optsAge(opts))
    if s == nil then
        finishQuery("near", tag, 0, 0, 0, 0, 0, nowMs() - started)
        return nil
    end
    x, y = tonumber(x), tonumber(y)
    if x == nil or y == nil then
        finishQuery("near", tag, 0, 0, 0, 0, 0, nowMs() - started)
        return adapter({})
    end
    local idxs = nil
    local zf, tol = optsZ(opts)
    local fn = type(opts) == "table" and opts.filter or nil
    local key = "N|" .. round2(x) .. "|" .. round2(y) .. "|" .. round2(r)
        .. "|" .. round2(zf or -999999) .. "|" .. round2(tol) .. "|" .. filterKey(fn)
    idxs = memGet("near", key)
    if idxs == nil then
        S.stats.memoMisses = S.stats.memoMisses + 1
        idxs = {}
        local scanned, rejZ, rejF = scanNear(s, idxs, x, y, tonumber(r) or 0, opts)
        memPut("near", key, idxs)
        local ms = nowMs() - started
        finishQuery("near", tag, #idxs, rejZ + rejF, scanned, rejZ, rejF, ms)
    else
        finishQuery("near", tag, #idxs, 0, #idxs, 0, 0, nowMs() - started)
    end
    return toList(refsOf(s, idxs), opts)
end

function S.nearUnion(x1, y1, x2, y2, r, opts)
    local tag = optsTag(opts)
    if not S.enabled then
        beginQuery("Union", tag)
        S.stats.fallbacks = S.stats.fallbacks + 1
        warn("disabled", "scan disabled, returning raw list")
        local list = readRawList()
        finishQuery("union", tag, list ~= nil and list:size() or 0, 0, 0, 0, 0, 0)
        return list
    end
    beginQuery("Union", tag)
    local started = nowMs()
    local s = ensureCoords(optsAge(opts))
    if s == nil then
        finishQuery("union", tag, 0, 0, 0, 0, 0, nowMs() - started)
        return nil
    end
    x1, y1 = tonumber(x1), tonumber(y1)
    if x1 == nil or y1 == nil then
        finishQuery("union", tag, 0, 0, 0, 0, 0, nowMs() - started)
        return adapter({})
    end
    x2, y2 = tonumber(x2) or x1, tonumber(y2) or y1
    local idxs = nil
    local zf, tol = optsZ(opts)
    local fn = type(opts) == "table" and opts.filter or nil
    local key = "U|" .. round2(x1) .. "|" .. round2(y1) .. "|" .. round2(x2) .. "|" .. round2(y2)
        .. "|" .. round2(r) .. "|" .. round2(zf or -999999) .. "|" .. round2(tol) .. "|" .. filterKey(fn)
    idxs = memGet("union", key)
    if idxs == nil then
        S.stats.memoMisses = S.stats.memoMisses + 1
        idxs = {}
        local scanned, rejZ, rejF = scanUnion(s, idxs, x1, y1, x2, y2, tonumber(r) or 0, opts)
        memPut("union", key, idxs)
        local ms = nowMs() - started
        finishQuery("union", tag, #idxs, rejZ + rejF, scanned, rejZ, rejF, ms)
    else
        finishQuery("union", tag, #idxs, 0, #idxs, 0, 0, nowMs() - started)
    end
    return toList(refsOf(s, idxs), opts)
end

function S.cone(x, y, fx, fy, minD, maxD, half, opts)
    local tag = optsTag(opts)
    if not S.enabled then
        beginQuery("Cone", tag)
        S.stats.fallbacks = S.stats.fallbacks + 1
        warn("disabled", "scan disabled, returning raw list")
        local list = readRawList()
        finishQuery("cone", tag, list ~= nil and list:size() or 0, 0, 0, 0, 0, 0)
        return list
    end
    beginQuery("Cone", tag)
    local started = nowMs()
    local s = ensureCoords(optsAge(opts))
    if s == nil then
        finishQuery("cone", tag, 0, 0, 0, 0, 0, nowMs() - started)
        return nil
    end
    x, y = tonumber(x), tonumber(y)
    fx, fy = tonumber(fx) or 0, tonumber(fy) or 1
    minD = tonumber(minD) or 0
    maxD = tonumber(maxD) or 0
    half = tonumber(half) or 0
    local idxs = nil
    local zf, tol = optsZ(opts)
    local fn = type(opts) == "table" and opts.filter or nil
    local key = "C|" .. round2(x) .. "|" .. round2(y) .. "|" .. round2(fx) .. "|" .. round2(fy)
        .. "|" .. round2(minD) .. "|" .. round2(maxD) .. "|" .. round2(half)
        .. "|" .. round2(zf or -999999) .. "|" .. round2(tol) .. "|" .. filterKey(fn)
    idxs = memGet("cone", key)
    if idxs == nil then
        S.stats.memoMisses = S.stats.memoMisses + 1
        idxs = {}
        local scanned, rejZ, rejF = scanCone(s, idxs, x, y, fx, fy, minD, maxD, half, opts)
        memPut("cone", key, idxs)
        local ms = nowMs() - started
        finishQuery("cone", tag, #idxs, rejZ + rejF, scanned, rejZ, rejF, ms)
    else
        finishQuery("cone", tag, #idxs, 0, #idxs, 0, 0, nowMs() - started)
    end
    return toList(refsOf(s, idxs), opts)
end

function S.count(cx, cy, cz, r, filterOrProfile, opts)
    local tag = optsTag(opts)
    local tol = type(opts) == "table" and (tonumber(opts.zTol) or 0.8) or 0.8
    local czz = tonumber(cz)

    if not S.enabled then
        beginQuery("Count", tag)
        S.stats.fallbacks = S.stats.fallbacks + 1
        warn("disabled", "scan disabled, walking raw list")
        local list = readRawList()
        if list == nil then
            finishQuery("count", tag, 0, 0, 0, 0, 0, 0)
            return 0
        end
        local fn = filterOf(filterOrProfile)
        local x, y = tonumber(cx), tonumber(cy)
        local r2 = (tonumber(r) or 0) ^ 2
        local n, scanned, rejZ, rejF = 0, 0, 0, 0
        local sz = 0
        pcall(function() sz = list:size() end)
        for i = 0, sz - 1 do
            local z = nil
            pcall(function() z = list:get(i) end)
            if z ~= nil then
                scanned = scanned + 1
                local okDist = false
                pcall(function() okDist = (z:getX() - x) ^ 2 + (z:getY() - y) ^ 2 <= r2 end)
                if okDist then
                    local okZ = true
                    if czz ~= nil then pcall(function() okZ = math.abs(z:getZ() - czz) < tol end) end
                    if not okZ then
                        rejZ = rejZ + 1
                    else
                        local pass = filterPass(fn, z)
                        if pass then n = n + 1 else rejF = rejF + 1 end
                    end
                end
            end
        end
        finishQuery("count", tag, n, rejZ + rejF, scanned, rejZ, rejF, 0)
        return n
    end

    beginQuery("Count", tag)
    local started = nowMs()
    local s = ensureCoords(optsAge(opts))
    if s == nil then
        finishQuery("count", tag, 0, 0, 0, 0, 0, nowMs() - started)
        return 0
    end
    local x, y = tonumber(cx), tonumber(cy)
    if x == nil or y == nil then
        finishQuery("count", tag, 0, 0, 0, 0, 0, nowMs() - started)
        return 0
    end
    local r2 = (tonumber(r) or 0) ^ 2
    local fn = filterOf(filterOrProfile)
    local key = "K|" .. round2(x) .. "|" .. round2(y) .. "|" .. round2(czz or -999999) .. "|" .. round2(r)
        .. "|" .. round2(tol) .. "|" .. filterKey(filterOrProfile)
    local cached = memGet("count", key)
    if cached ~= nil then
        finishQuery("count", tag, cached, 0, 0, 0, 0, nowMs() - started)
        return cached
    end
    S.stats.memoMisses = S.stats.memoMisses + 1
    local idxs, seen = {}, {}
    gatherRadius(s, idxs, x, y, tonumber(r) or 0, seen)
    local n, scanned, rejZ, rejF = 0, 0, 0, 0
    for i = 1, #idxs do
        local idx = idxs[i]
        local z = s.refs[idx]
        if z ~= nil then
            scanned = scanned + 1
            local dz = s.zs[idx]
            if czz ~= nil and dz ~= nil and math.abs(dz - czz) >= tol then
                rejZ = rejZ + 1
            elseif s.xs[idx] ~= nil then
                local dx, dy = s.xs[idx] - x, s.ys[idx] - y
                if dx * dx + dy * dy <= r2 then
                    local pass = filterPass(fn, z)
                    if pass then n = n + 1 else rejF = rejF + 1 end
                end
            end
        end
    end
    memPut("count", key, n)
    local ms = nowMs() - started
    finishQuery("count", tag, n, rejZ + rejF, scanned, rejZ, rejF, ms)
    return n
end

function S.countSeen(cx, cy, cz, r, a, b, opts)
    local tol = type(opts) == "table" and (tonumber(opts.zTol) or 0.8) or 0.8
    local key = "S|" .. round2(cx) .. "|" .. round2(cy) .. "|" .. round2(cz or -999999) .. "|" .. round2(r)
        .. "|" .. round2(tol) .. "|" .. tostring(a) .. "|" .. tostring(b)
    local cached = memGet("countSeen", key)
    if cached ~= nil then return cached end
    S.stats.memoMisses = S.stats.memoMisses + 1
    local n = S.count(cx, cy, cz, r, function(z)
        return S.isThreat(z) and S.canSee(z, a, b)
    end, opts)
    memPut("countSeen", key, tonumber(n) or 0)
    return n
end

function S.find(pred, maxN, opts)
    local tag = optsTag(opts)
    local started = nowMs()
    local out = {}
    local scanned, rejF = 0, 0

    if not S.enabled then
        beginQuery("Find", tag)
        S.stats.fallbacks = S.stats.fallbacks + 1
        warn("disabled", "scan disabled, walking raw list")
        local list = readRawList()
        if list ~= nil then
            local sz = 0
            pcall(function() sz = list:size() end)
            for i = 0, sz - 1 do
                local z = nil
                pcall(function() z = list:get(i) end)
                if z ~= nil then
                    scanned = scanned + 1
                    if pred == nil or filterPass(pred, z) then
                        out[#out + 1] = z
                        if maxN ~= nil and #out >= maxN then break end
                    else
                        rejF = rejF + 1
                    end
                end
            end
        else
            finishQuery("find", tag, 0, 0, 0, 0, 0, nowMs() - started)
            return nil
        end
        finishQuery("find", tag, #out, rejF, scanned, 0, rejF, nowMs() - started)
        return out
    end

    beginQuery("Find", tag)
    local s = refreshRefs(optsAge(opts))
    if s == nil then
        finishQuery("find", tag, 0, 0, 0, 0, 0, nowMs() - started)
        return nil
    end
    for i = 1, s.n do
        local z = s.refs[i]
        if z ~= nil then
            scanned = scanned + 1
            if pred == nil or filterPass(pred, z) then
                out[#out + 1] = z
                if maxN ~= nil and #out >= maxN then break end
            else
                rejF = rejF + 1
            end
        end
    end
    finishQuery("find", tag, #out, rejF, scanned, 0, rejF, nowMs() - started)
    return out
end

function S.list(opts)
    local tag = optsTag(opts)
    beginQuery("Near", tag)
    local started = nowMs()
    if not S.enabled then
        local list = readRawList()
        finishQuery("list", tag, list ~= nil and list:size() or 0, 0, 0, 0, 0, 0)
        return list
    end
    local s = refreshRefs(optsAge(opts))
    if s == nil then
        finishQuery("list", tag, 0, 0, 0, 0, 0, nowMs() - started)
        return nil
    end
    finishQuery("list", tag, s.n, 0, s.n, 0, 0, nowMs() - started)
    return toList(s.refs, opts)
end

function S.diagLine()
    local s = S.stats
    local n = snap ~= nil and snap.n or 0
    local tops = {}
    for tag, rec in pairs(s.byTag) do tops[#tops + 1] = tag .. ":" .. tostring(rec.q) end
    table.sort(tops)
    while #tops > 5 do tops[#tops] = nil end
    return string.format("enabled=%d builds=%d/%d n=%d q=%d cand=%d memo=%d/%d ms=%.1f/%.1f off=%d tags=%s",
        S.enabled and 1 or 0, s.refBuilds, s.coordBuilds, n, s.queries, s.candidates,
        s.memoHits, s.memoMisses, s.buildMsLast, s.queryMsMax, s.fallbacks, table.concat(tops, " "))
end

function S.statusText()
    local s = S.stats
    local n = snap ~= nil and snap.n or 0
    local lvl = snap ~= nil and snap.level or 0
    local age = snap ~= nil and (s.tick - snap.tick) or 0
    local bucket = snap ~= nil and snap.buckets ~= nil
    local tops = {}
    for tag, rec in pairs(s.byTag) do tops[#tops + 1] = { tag = tag, q = rec.q } end
    table.sort(tops, function(a, b) if a.q == b.q then return a.tag < b.tag end return a.q > b.q end)
    local top = {}
    for i = 1, math.min(5, #tops) do top[#top + 1] = tops[i].tag .. ":" .. tops[i].q end
    local inv = s.invalidations
    return string.format(
        "zscan enabled=%d debug=%d tick=%d age=%d n=%d level=L%d buckets=%s\n" ..
        "builds ref=%d coord=%d reads=%d ms=%.2f/%.2f inval tick=%d start=%d cell=%d\n" ..
        "queries=%d near=%d union=%d cone=%d count=%d find=%d cand=%d rej=%d fallback=%d\n" ..
        "memo hits=%d miss=%d unattributed=%d lastError=%s top=%s",
        S.enabled and 1 or 0, S.debug, s.tick, age, n, lvl, bucket and "on" or "off",
        s.refBuilds, s.coordBuilds, s.listReads, s.buildMsLast, s.buildMsMax,
        inv.tick, inv.start, inv.cell,
        s.queries, s.queriesNear, s.queriesUnion, s.queriesCone, s.queriesCount, s.queriesFind,
        s.candidates, s.filterRejects, s.fallbacks,
        s.memoHits, s.memoMisses, s.unattributed, tostring(s.lastError or "none"),
        #top > 0 and table.concat(top, " ") or "none")
end

function S.tagsText()
    local names = {}
    for tag in pairs(S.TAGS) do names[#names + 1] = tag end
    table.sort(names)
    local out = {}
    for _, tag in ipairs(names) do
        local rec = S.stats.byTag[tag]
        if rec == nil then
            out[#out + 1] = tag .. " never"
        else
            out[#out + 1] = string.format("%s q=%d cand=%d ms=%.2f/%.2f tick=%d",
                tag, rec.q, rec.cand, rec.lastMs, rec.maxMs, rec.lastTick)
        end
    end
    return "zscan tags:\n" .. table.concat(out, "\n")
end

function S.whyText(tag)
    if type(tag) ~= "string" then return "zscan why <tag>" end
    if not S.TAGS[tag] then return "unknown tag: " .. tag end
    if S.debug < 1 then return "zscan why needs debug >= 1 (zscan debug 1)" end
    local q = S.stats.lastQuery[tag]
    if q == nil then return tag .. ": no query recorded this session" end
    return string.format("%s kind=%s tick=%d L%d bucket=%s scanned=%d acc=%d rej=%d rejZ=%d rejFilter=%d ms=%.2f",
        tag, tostring(q.kind), q.tick, q.level, q.bucket and "on" or "off",
        q.scanned or 0, q.accepted, q.rejects, q.rejZ, q.rejFilter, q.ms)
end

function S.trace(tag, ticks)
    if tag == nil then return "zscan trace <tag> [ticks] | zscan trace 0" end
    if tag == "0" or tag == "off" then
        S.traceTag, S.traceUntil = nil, nil
        return "zscan trace off"
    end
    if not S.TAGS[tag] then return "unknown trace tag: " .. tag end
    S.traceTag = tag
    S.traceUntil = tickNow() + (tonumber(ticks) or 300)
    return "tracing " .. tag .. " for " .. tostring(tonumber(ticks) or 300) .. " ticks"
end

function S.debugNear(x, y, r)
    x, y, r = tonumber(x), tonumber(y), tonumber(r)
    if x == nil or y == nil then return "zscan near X Y R" end
    r = r or 10
    local s = ensureCoords()
    if s == nil then return "zscan near: no snapshot (" .. tostring(S.stats.lastError or "no cell") .. ")" end
    local r2 = r * r
    local total = 0
    local lines = {}
    for i = 1, s.n do
        if s.xs[i] ~= nil then
            local dx, dy = s.xs[i] - x, s.ys[i] - y
            if dx * dx + dy * dy <= r2 then
                total = total + 1
                if #lines < 5 then
                    lines[#lines + 1] = string.format("#%d d=%.2f z=%.2f", i, math.sqrt(dx * dx + dy * dy), s.zs[i] or 0)
                end
            end
        end
    end
    return string.format("zscan near %.2f,%.2f r=%.2f count=%d n=%d L%d bucket=%s | %s",
        x, y, r, total, s.n, s.level, s.buckets ~= nil and "on" or "off",
        #lines > 0 and table.concat(lines, " ") or "none")
end

function S.setDebug(n)
    S.debug = math.max(0, math.floor(tonumber(n) or 0))
    if S.debug < 1 then S.traceTag, S.traceUntil = nil, nil end
    return "zscan debug " .. tostring(S.debug)
end

function S.setOn(on)
    S.enabled = on == true
    S.invalidate("start")
    log("scan " .. (S.enabled and "on" or "off"))
    return "zscan " .. (S.enabled and "on" or "off")
end

function S.reset()
    resetStats()
    return "zscan reset"
end

local function fakeList(zs)
    return {
        size = function() return #zs end,
        get = function(_, i) return zs[i + 1] end,
    }
end

local function fakeZombie(x, y, z, t)
    t = t or {}
    local o = {
        x = x, y = y, z = z,
        id = t.id,
        fakeBody = t.body == true,
        fakeRemote = t.remote == true,
        fakeHarmless = t.harmless == true,
        fakeDragged = t.dragged == true,
        chasing = t.chasing == true,
        target = t.target,
    }
    function o:getX() return self.x end
    function o:getY() return self.y end
    function o:getZ() return self.z end
    function o:isAlive() return t.alive ~= false end
    function o:getHealth() return t.hp or 100 end
    function o:isDead() return t.dead == true end
    function o:getVariableBoolean() return self.fakeBody end
    function o:isRemoteZombie() return self.fakeRemote end
    function o:getTarget() return self.target end
    return o
end

function S.selftest()
    local saved = {
        enabled = S.enabled,
        debug = S.debug,
        tickOf = S.tickOf,
        cellOf = S.cellOf,
        listProvider = S.listProvider,
        isCompanionOf = S.isCompanionOf,
        isRemoteOf = S.isRemoteOf,
        isHarmlessOf = S.isHarmlessOf,
        isDraggedOf = S.isDraggedOf,
        isOwnerRisenOf = S.isOwnerRisenOf,
        bucketAt = S.BUCKET_AT,
        traceTag = S.traceTag,
        traceUntil = S.traceUntil,
        snap = snap,
        memo = memo,
        failedTick = failedTick,
        failedCell = failedCell,
        invSec = invSec,
        invCount = invCount,
        lastRefBuildTick = lastRefBuildTick,
        nextSummary = nextSummary,
        quietSelf = quietSelf,
        stats = copyStats(),
    }
    quietSelf = true

    local checks, fails = 0, {}
    local function check(name, cond, detail)
        checks = checks + 1
        if not cond then
            fails[#fails + 1] = name .. (detail ~= nil and (" [" .. tostring(detail) .. "]") or "")
        end
    end

    local ftick = 1
    local fcell = {}
    local flist = fakeList({})
    local providerCalls = 0
    local function nextTick()
        ftick = ftick + 1
    end
    local function setList(zs)
        flist = fakeList(zs)
        nextTick()
        S.invalidate("start")
    end
    local function ids(list)
        if list == nil then return "nil" end
        local arr = {}
        for i = 0, list:size() - 1 do arr[#arr + 1] = tostring(list:get(i).id) end
        table.sort(arr)
        return table.concat(arr, ",")
    end

    do
        S.enabled = true
        S.debug = 0
        S.tickOf = function() return ftick end
        S.cellOf = function() return fcell end
        S.listProvider = function()
            providerCalls = providerCalls + 1
            return flist
        end
        S.isCompanionOf = function(z) return z.fakeBody == true end
        S.isRemoteOf = function(z) return z.fakeRemote == true end
        S.isHarmlessOf = function(z) return z.fakeHarmless == true end
        S.isDraggedOf = function(z) return z.fakeDragged == true end
        S.isOwnerRisenOf = function() return false end
    end

    do
        local A = fakeZombie(0, 0, 0, { id = "A" })
        local B = fakeZombie(3, 0, 0, { id = "B" })
        local C = fakeZombie(3.5, 0, 0, { id = "C" })
        local D = fakeZombie(0, 0, 0.5, { id = "D" })
        local E = fakeZombie(0, 0, 0.9, { id = "E" })
        local F = fakeZombie(0, 2, 0, { id = "F" })
        local H = fakeZombie(0, 0, 0, { id = "H" })
        local I = fakeZombie(3, 1, 0, { id = "I" })
        local J = fakeZombie(3, 1.5, 0, { id = "J" })
        local G = fakeZombie(100, 100, 0, { id = "G" })
        setList({ A, B, C, D, E, F, H, I, J, G })

        check("near radius boundary inclusive", ids(S.near(0, 0, 3)) == "A,B,D,E,F,H", ids(S.near(0, 0, 3)))
        check("near radius boundary outer", ids(S.near(0, 0, 2.9999)) == "A,D,E,F,H", ids(S.near(0, 0, 2.9999)))
        check("near duplicate coords kept", S.near(0, 0, 3):size() == 6, S.near(0, 0, 3):size())
        check("near z-band default 0.8", ids(S.near(0, 0, 3, { z = 0 })) == "A,B,D,F,H",
            ids(S.near(0, 0, 3, { z = 0 })))
        check("near z-band explicit", ids(S.near(0, 0, 3, { z = 0, zTol = 1.0 })) == "A,B,D,E,F,H",
            ids(S.near(0, 0, 3, { z = 0, zTol = 1.0 })))
        check("near filter", ids(S.near(0, 0, 3, { filter = function(z) return z.id ~= "A" end })) == "B,D,E,F,H",
            ids(S.near(0, 0, 3, { filter = function(z) return z.id ~= "A" end })))
        check("nearUnion dedupe", ids(S.nearUnion(0, 0, 0.2, 0, 1)) == "A,D,E,H",
            ids(S.nearUnion(0, 0, 0.2, 0, 1)))
        check("cone geometry", ids(S.cone(0, 0, 1, 0, 1, 4, 1)) == "B,C,I",
            ids(S.cone(0, 0, 1, 0, 1, 4, 1)))
    end

    do
        local K1 = fakeZombie(1, 0, 0, { id = "K1" })
        local K2 = fakeZombie(1, 0, 0, { id = "K2", hp = 0 })
        local K3 = fakeZombie(1, 0, 0, { id = "K3", body = true })
        local K4 = fakeZombie(1, 0, 0, { id = "K4", remote = true })
        local K5 = fakeZombie(1, 0, 0, { id = "K5", harmless = true })
        local K6 = fakeZombie(1, 0, 0, { id = "K6" })
        local K7 = fakeZombie(1, 0, 0, { id = "K7", dragged = true })
        setList({ K1, K2, K3, K4, K5, K6, K7 })

        check("count canonical", S.count(0, 0, 0, 5, "canonical") == 3, S.count(0, 0, 0, 5, "canonical"))
        check("count alert", S.count(0, 0, 0, 5, "alert") == 4, S.count(0, 0, 0, 5, "alert"))
        check("count social", S.count(0, 0, 0, 5, "social") == 5, S.count(0, 0, 0, 5, "social"))
        check("count sleep", S.count(0, 0, 0, 5, "sleep") == 5, S.count(0, 0, 0, 5, "sleep"))
        check("count raw", S.count(0, 0, 0, 5, "raw") == 7, S.count(0, 0, 0, 5, "raw"))
        check("count z-band", S.count(0, 0, 0, 5, "raw", { zTol = 0.1 }) == 7, S.count(0, 0, 0, 5, "raw", { zTol = 0.1 }))
    end

    do
        local V1 = { CanSee = function(_, z) return z.id == "V1" or z.id == "V2" or z.id == "HM" or z.id == "Z5" end }
        local V2 = { CanSee = function(_, z) return z.id == "V2" end }
        local none = {}
        local z1 = fakeZombie(1, 0, 0, { id = "V1" })
        local z2 = fakeZombie(1, 0, 0, { id = "V2" })
        local z3 = fakeZombie(1, 0, 0, { id = "V3" })
        local z4 = fakeZombie(1, 0, 0, { id = "V4" })
        setList({ z1, z2, z3, z4 })

        check("canSee nil", S.canSee(nil, V1, V1) == false)
        check("canSee primary", S.canSee(z1, V1, V1) == true)
        check("canSee secondary", S.canSee(z2, none, V1) == true)
        check("canSee neither", S.canSee(z3, none, V2) == false)
        check("canSee no method", S.canSee(z1, none, nil) == false)
        check("countSeen two", S.countSeen(0, 0, 0, 5, V1, V1) == 2, S.countSeen(0, 0, 0, 5, V1, V1))

        local hm = fakeZombie(1, 0, 0, { id = "HM", harmless = true })
        setList({ z1, z2, hm })
        check("countSeen excludes harmless", S.countSeen(0, 0, 0, 5, V1, V1) == 2,
            S.countSeen(0, 0, 0, 5, V1, V1))

        local z5 = fakeZombie(1, 0, 0.5, { id = "Z5" })
        setList({ z1, z5 })
        check("countSeen z-band default", S.countSeen(0, 0, 0, 5, V1, V1) == 2,
            S.countSeen(0, 0, 0, 5, V1, V1))
        check("countSeen z-band tight", S.countSeen(0, 0, 0, 5, V1, V1, { zTol = 0.1 }) == 1,
            S.countSeen(0, 0, 0, 5, V1, V1, { zTol = 0.1 }))
    end

    do
        local near = fakeZombie(0, 0, 0, { id = "near" })
        local far = fakeZombie(500, 500, 0, { id = "far", chasing = true })
        setList({ near, far })
        local got = S.find(function(z) return z.chasing == true end)
        check("find distant chaser", #got == 1 and got[1] == far, #got)
    end

    do
        local function grid(n)
            local zs = {}
            for i = 1, n do
                zs[i] = fakeZombie((i * 7) % 40 - 20, (i * 13) % 40 - 20, 0, { id = i })
            end
            return zs
        end
        for _, n in ipairs({ 149, 150, 151 }) do
            setList(grid(n))
            S.BUCKET_AT = 999999
            nextTick()
            local linear = ids(S.near(0, 0, 9))
            S.BUCKET_AT = n - 1
            nextTick()
            local bucketed = ids(S.near(0, 0, 9))
            check("bucket parity n=" .. n, linear == bucketed, linear .. " vs " .. bucketed)
        end
        S.BUCKET_AT = saved.bucketAt
    end

    do
        setList({ fakeZombie(0, 0, 0, { id = "T" }) })
        local base = S.stats.refBuilds
        providerCalls = 0
        S.near(0, 0, 1)
        S.near(0, 0, 2)
        S.nearUnion(0, 0, 1, 1, 2)
        S.count(0, 0, 0, 2, "canonical")
        S.find(function() return true end)
        check("one list read per tick", providerCalls == 1, providerCalls)
        check("one ref build per tick", S.stats.refBuilds - base == 1, S.stats.refBuilds - base)

        nextTick()
        providerCalls = 0
        S.near(0, 0, 1)
        check("tick invalidation", providerCalls == 1 and S.stats.refBuilds - base == 2,
            providerCalls .. "/" .. (S.stats.refBuilds - base))

        fcell = {}
        providerCalls = 0
        S.near(0, 0, 1)
        check("cell invalidation", providerCalls == 1, providerCalls)
    end

    do
        local d1 = fakeZombie(0, 0, 0, { id = "d1" })
        local d2 = fakeZombie(50, 50, 0, { id = "d2" })
        S.enabled = false
        setList({ d1, d2 })
        local all = S.near(0, 0, 1)
        check("disabled near full list", all ~= nil and all:size() == 2, all ~= nil and all:size() or "nil")
        check("disabled count filters", S.count(0, 0, 0, 1, "canonical") == 1,
            S.count(0, 0, 0, 1, "canonical"))
        S.enabled = true
    end

    check("listReads == refBuilds", S.stats.listReads == S.stats.refBuilds,
        S.stats.listReads .. "/" .. S.stats.refBuilds)
    check("coordBuilds <= refBuilds", S.stats.coordBuilds <= S.stats.refBuilds,
        S.stats.coordBuilds .. "/" .. S.stats.refBuilds)

    S.enabled = saved.enabled
    S.debug = saved.debug
    S.tickOf = saved.tickOf
    S.cellOf = saved.cellOf
    S.listProvider = saved.listProvider
    S.isCompanionOf = saved.isCompanionOf
    S.isRemoteOf = saved.isRemoteOf
    S.isHarmlessOf = saved.isHarmlessOf
    S.isDraggedOf = saved.isDraggedOf
    S.isOwnerRisenOf = saved.isOwnerRisenOf
    S.BUCKET_AT = saved.bucketAt
    S.traceTag = saved.traceTag
    S.traceUntil = saved.traceUntil
    snap = saved.snap
    memo = saved.memo
    failedTick = saved.failedTick
    failedCell = saved.failedCell
    invSec = saved.invSec
    invCount = saved.invCount
    lastRefBuildTick = saved.lastRefBuildTick
    nextSummary = saved.nextSummary
    quietSelf = saved.quietSelf
    applyStats(saved.stats)

    if #fails == 0 then return string.format("ZSELFTEST PASS (%d checks)", checks) end
    local list = {}
    for i = 1, math.min(5, #fails) do list[i] = fails[i] end
    return string.format("ZSELFTEST FAIL %s (%d of %d) n=%d bucketAt=%d",
        table.concat(list, "; "), #fails, checks, snap ~= nil and snap.n or 0, S.BUCKET_AT)
end

if Events ~= nil and Events.OnGameStart ~= nil then
    pcall(function() Events.OnGameStart.Add(function() S.invalidate("start") end) end)
end

if Events ~= nil and Events.OnCreatePlayer ~= nil then
    pcall(function() Events.OnCreatePlayer.Add(function() S.invalidate("start") end) end)
end
