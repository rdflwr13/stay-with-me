

BridgeLog = {}

function BridgeLog.on()
    if BridgeBuild ~= nil and BridgeBuild.test == true then return true end
    if Bridge ~= nil and Bridge.verbose == true then return true end
    if BridgeServer ~= nil and BridgeServer.verbose == true then return true end
    return false
end

-- Structured movement trace. One `key=value` line per decision event, gated by
-- BridgeLog.on() like every other log line in the mod. The ring buffer only
-- fills while logging is on, so it never costs anything in a normal session.

BridgeLog.RING_MAX = 600
BridgeLog.ring = {}
BridgeLog.seq = 0
BridgeLog.runId = nil
BridgeLog.lastSig = {}

local function nowTick()
    if Bridge ~= nil and tonumber(Bridge.tick) ~= nil then return tonumber(Bridge.tick) end
    return 0
end

local function clean(v)
    local s = tostring(v)
    s = string.gsub(s, "[\r\n\t]", " ")
    s = string.gsub(s, " ", "_")
    s = string.gsub(s, "=", ":")
    if #s > 80 then s = string.sub(s, 1, 80) end
    return s
end

local function fmt(v)
    if v == nil then return nil end
    local t = type(v)
    if t == "boolean" then return v and "1" or "0" end
    if t == "number" then
        if v ~= v then return "nan" end
        if v == math.floor(v) and math.abs(v) < 1.0e12 then return tostring(math.floor(v)) end
        return string.format("%.2f", v)
    end
    if t == "table" then
        local x, y, z = v.x, v.y, v.z
        if x ~= nil and y ~= nil then
            if z ~= nil then return string.format("%.1f,%.1f,%.1f", tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0) end
            return string.format("%.1f,%.1f", tonumber(x) or 0, tonumber(y) or 0)
        end
        return nil
    end
    return clean(v)
end

function BridgeLog.run()
    if BridgeLog.runId == nil then
        local ok, t = pcall(os.time)
        BridgeLog.runId = ok and tostring(t) or "0"
    end
    return BridgeLog.runId
end

function BridgeLog.event(ev, fields)
    if not BridgeLog.on() then return end
    ev = tostring(ev or "?")
    fields = fields or {}
    BridgeLog.seq = BridgeLog.seq + 1

    local keys = {}
    for k in pairs(fields) do keys[#keys + 1] = k end
    table.sort(keys)

    local parts = {}
    local sig = ev
    parts[#parts + 1] = "ev=" .. clean(ev)
    parts[#parts + 1] = "seq=" .. tostring(BridgeLog.seq)
    parts[#parts + 1] = "run=" .. BridgeLog.run()
    parts[#parts + 1] = "tick=" .. tostring(nowTick())
    local job = BridgeTask ~= nil and BridgeTask.jobId or nil
    parts[#parts + 1] = "job=" .. tostring(job or "-")
    local att = BridgeRoute ~= nil and BridgeRoute.att or nil
    parts[#parts + 1] = "att=" .. tostring(att or "-")
    local ent = "-"
    if Bridge ~= nil and Bridge.body ~= nil then
        local ok, id = pcall(function() return Bridge.body:getID() end)
        if ok and id ~= nil then ent = tostring(id) end
    end
    parts[#parts + 1] = "ent=" .. clean(ent)
    parts[#parts + 1] = "fn=" .. clean(fields.fn or "-")

    for i = 1, #keys do
        local k = keys[i]
        if k ~= "fn" and k ~= "sig" then
            local v = fmt(fields[k])
            if v ~= nil then
                parts[#parts + 1] = clean(k) .. "=" .. v
                sig = sig .. "|" .. k .. "=" .. v
            end
        end
    end
    if fields.sig ~= nil then sig = tostring(fields.sig) end

    local changed = BridgeLog.lastSig[ev] ~= sig and 1 or 0
    BridgeLog.lastSig[ev] = sig
    parts[#parts + 1] = "changed=" .. tostring(changed)

    local line = table.concat(parts, " ")
    local ring = BridgeLog.ring
    ring[#ring + 1] = line
    if #ring > BridgeLog.RING_MAX then table.remove(ring, 1) end
    print("[BridgeLog] " .. line)
end

function BridgeLog.invariant(id, detail, severity)
    BridgeLog.event("invariant", {
        id = id, detail = detail, severity = severity or "warn", fn = "BridgeLog.invariant" })
end

function BridgeLog.dump()
    if not BridgeLog.on() then return "logdump: verbose off" end
    local ring = BridgeLog.ring
    if #ring == 0 then return "logdump: empty" end
    local ok = pcall(function()
        local w = getFileWriter("bridge/movement-trace.txt", true, true)
        for i = 1, #ring do w:write(ring[i] .. "\r\n") end
        w:close()
    end)
    if not ok then return "logdump: write failed" end
    return "logdump: " .. tostring(#ring) .. " lines"
end
