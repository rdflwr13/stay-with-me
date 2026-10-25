-- Shared, tick-scoped zombie snapshot for Stay With Me.
--
-- One cell-list read and one coordinate read per zombie per tick. Radius
-- consumers share the same snapshot instead of re-reading getZombieList().
-- Above BUCKET_AT zombies the snapshot gets a coarse 2D bucket index so
-- radius queries touch only nearby buckets.

BridgeZS = BridgeZS or {}

BridgeZS.enabled = true
BridgeZS.BUCKET_AT = 150
BridgeZS.BUCKET = 8

BridgeZS.stats = {
    builds = 0,
    zombies = 0,
    queries = 0,
    candidates = 0,
    fallbacks = 0,
    errors = 0,
    lastMs = 0,
    maxMs = 0,
}

local LIST_MT = {
    size = function(self) return #self.a end,
    get = function(self, i) return self.a[i + 1] end,
}

local function adapter(a)
    return setmetatable({ a = a }, LIST_MT)
end

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeZS] " .. tostring(text)) end
end

local function nowMs()
    local t = 0
    pcall(function() t = getTimestampMs() end)
    return t
end

local snap = nil
local lastTick = nil
local failedTick = nil
local nextLog = 0
local lastErrorLog = 0

local function flushLog()
    if Bridge == nil or not Bridge.verbose then return end
    local tick = tonumber(Bridge.tick) or 0
    if tick < (nextLog or 0) then return end
    nextLog = tick + 300
    local s = BridgeZS.stats
    log(string.format(
        "builds=%d n=%d zombies=%d queries=%d candidates=%d fallbacks=%d errors=%d lastMs=%.2f maxMs=%.2f buckets=%s",
        s.builds, snap ~= nil and snap.n or 0, s.zombies, s.queries, s.candidates,
        s.fallbacks, s.errors, s.lastMs, s.maxMs,
        snap ~= nil and snap.buckets ~= nil and "on" or "off"))
    s.builds, s.zombies, s.queries, s.candidates, s.fallbacks, s.errors = 0, 0, 0, 0, 0, 0
    s.lastMs, s.maxMs = 0, 0
end

function BridgeZS.invalidate()
    snap = nil
    lastTick = nil
    failedTick = nil
    nextLog = 0
end

local function build()
    local started = nowMs()
    local refs, xs, ys, zs = {}, {}, {}, {}
    local count = 0
    local cell = nil
    local ok, err = pcall(function()
        cell = getCell()
        if cell == nil then return end
        local list = cell:getZombieList()
        if list == nil then return end
        local n = list:size()
        for i = 0, n - 1 do
            local z = list:get(i)
            if z ~= nil then
                count = count + 1
                refs[count] = z
                xs[count] = z:getX()
                ys[count] = z:getY()
                zs[count] = z:getZ()
            end
        end
    end)
    if not ok or cell == nil then
        BridgeZS.stats.errors = BridgeZS.stats.errors + 1
        local tick = tonumber(Bridge.tick) or 0
        if Bridge ~= nil and Bridge.verbose and tick >= (lastErrorLog or 0) then
            lastErrorLog = tick + 300
            log("build failed: " .. tostring(err or "no cell"))
        end
        return nil
    end

    local buckets = nil
    if count > BridgeZS.BUCKET_AT then
        buckets = {}
        local B = BridgeZS.BUCKET
        for i = 1, count do
            local bx = math.floor(xs[i] / B)
            local by = math.floor(ys[i] / B)
            local layer = buckets[bx]
            if layer == nil then
                layer = {}
                buckets[bx] = layer
            end
            local col = layer[by]
            if col == nil then
                col = {}
                layer[by] = col
            end
            col[#col + 1] = i
        end
    end

    local s = BridgeZS.stats
    s.builds = s.builds + 1
    s.zombies = s.zombies + count
    local ms = (nowMs() - started)
    s.lastMs = ms
    if ms > s.maxMs then s.maxMs = ms end

    snap = {
        tick = tonumber(Bridge.tick) or 0,
        cell = cell,
        refs = refs,
        xs = xs,
        ys = ys,
        zs = zs,
        n = count,
        buckets = buckets,
    }
    return snap
end

function BridgeZS.update()
    if not BridgeZS.enabled then return nil end
    local tick = (Bridge ~= nil and tonumber(Bridge.tick)) or 0
    if lastTick ~= nil and tick < lastTick then BridgeZS.invalidate() end
    if snap ~= nil and snap.tick == tick then
        flushLog()
        return snap
    end
    if failedTick == tick then return nil end
    lastTick = tick
    local s = build()
    if s == nil then
        failedTick = tick
        BridgeZS.stats.fallbacks = BridgeZS.stats.fallbacks + 1
    end
    flushLog()
    return s
end

local function addFromBuckets(out, seen, x, y, r, r2)
    local B = BridgeZS.BUCKET
    local minBX, maxBX = math.floor((x - r) / B), math.floor((x + r) / B)
    local minBY, maxBY = math.floor((y - r) / B), math.floor((y + r) / B)
    for bx = minBX, maxBX do
        local layer = snap.buckets[bx]
        if layer ~= nil then
            for by = minBY, maxBY do
                local col = layer[by]
                if col ~= nil then
                    for k = 1, #col do
                        local idx = col[k]
                        if not seen[idx] then
                            local dx, dy = snap.xs[idx] - x, snap.ys[idx] - y
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
end

local function noteQuery(results)
    local s = BridgeZS.stats
    s.queries = s.queries + 1
    s.candidates = s.candidates + #results
end

function BridgeZS.list()
    local s = BridgeZS.update()
    if s == nil then return nil end
    noteQuery(s.refs)
    flushLog()
    return adapter(s.refs)
end

function BridgeZS.near(x, y, r)
    local s = BridgeZS.update()
    if s == nil then return nil end
    x, y = tonumber(x), tonumber(y)
    if x == nil or y == nil then return adapter({}) end
    local out = {}
    local radius = tonumber(r) or 0
    if radius > 0 then
        local r2 = radius * radius
        if s.buckets ~= nil then
            addFromBuckets(out, {}, x, y, radius, r2)
        else
            for i = 1, s.n do
                local dx, dy = s.xs[i] - x, s.ys[i] - y
                if dx * dx + dy * dy <= r2 then out[#out + 1] = i end
            end
        end
    end
    local results = {}
    for i = 1, #out do results[i] = s.refs[out[i]] end
    noteQuery(results)
    flushLog()
    return adapter(results)
end

function BridgeZS.nearUnion(x1, y1, x2, y2, r)
    local s = BridgeZS.update()
    if s == nil then return nil end
    x1, y1 = tonumber(x1), tonumber(y1)
    if x1 == nil or y1 == nil then return adapter({}) end
    x2, y2 = tonumber(x2) or x1, tonumber(y2) or y1
    local out = {}
    local radius = tonumber(r) or 0
    if radius > 0 then
        local r2 = radius * radius
        if s.buckets ~= nil then
            local seen = {}
            addFromBuckets(out, seen, x1, y1, radius, r2)
            addFromBuckets(out, seen, x2, y2, radius, r2)
        else
            for i = 1, s.n do
                local dx1, dy1 = s.xs[i] - x1, s.ys[i] - y1
                local dx2, dy2 = s.xs[i] - x2, s.ys[i] - y2
                if dx1 * dx1 + dy1 * dy1 <= r2 or dx2 * dx2 + dy2 * dy2 <= r2 then
                    out[#out + 1] = i
                end
            end
        end
    end
    local results = {}
    for i = 1, #out do results[i] = s.refs[out[i]] end
    noteQuery(results)
    flushLog()
    return adapter(results)
end

if Events ~= nil and Events.OnGameStart ~= nil then
    pcall(function() Events.OnGameStart.Add(function() BridgeZS.invalidate() end) end)
end

if Events ~= nil and Events.OnCreatePlayer ~= nil then
    pcall(function() Events.OnCreatePlayer.Add(function() BridgeZS.invalidate() end) end)
end
