BridgePerf = BridgePerf or {}
local P = BridgePerf

P.tier = 2

P.ages = {
    zscan = 4,
    zscanShort = 3,
    zscanTight = 2,
    bodyVar = 3,
    outfit = 5,
    ammoPresence = 3,
    scanFrame = 30,
    list = 15,
    items = 6,
    torch = 6,
    wornBags = 30,
    melee = 30,
    gunItem = 60,
    fetchAmmo = 120,
    homeTargets = 120,
    ooa = 60,
    reserve = 15,
    needAmmo = 30,
    hasAmmo = 30,
}

P.agesBase = {
    zscan = 1,
    zscanShort = 1,
    zscanTight = 1,
    bodyVar = 1,
    outfit = 1,
    ammoPresence = 1,
    scanFrame = 15,
    list = 15,
    items = 1,
    torch = 1,
    wornBags = 1,
    melee = 1,
    gunItem = 1,
    fetchAmmo = 1,
    homeTargets = 1,
    ooa = 1,
    reserve = 1,
    needAmmo = 1,
    hasAmmo = 1,
}

P.everyBase = { snapshot = 30, backup = 60 }
P.everyTier2 = { snapshot = 60, backup = 180 }

P.prev = {}
P.lastTier = nil

local function tier()
    local t = tonumber(P.tier) or 0
    if t < 0 then t = 0 elseif t > 2 then t = 2 end
    return t
end

local function whole(v, low)
    v = math.floor(tonumber(v) or low)
    if v < low then v = low end
    return v
end

function P.age(kind, fallback)
    if tier() < 2 then
        local base = P.agesBase[kind]
        if base ~= nil then return base end
        return 1
    end
    local v = P.ages[kind]
    if v == nil then v = tonumber(fallback) end
    return whole(v, 1)
end

function P.on(kind)
    return tier() >= 1
end

function P.every(tag, ticks)
    local n
    if tier() >= 2 then
        n = P.everyTier2[tag] or tonumber(ticks) or 60
    else
        n = P.everyBase[tag] or tonumber(ticks) or 30
    end
    n = whole(n, 1)
    local now = 0
    if Bridge ~= nil then now = tonumber(Bridge.time) or 0 end
    local prev = P.prev[tag]
    P.prev[tag] = now
    if prev == nil then return true end
    return math.floor(now / n) > math.floor(prev / n)
end

function P.set(n)
    local t = tonumber(n)
    if t == nil then return "perf 0|1|2" end
    t = math.max(0, math.min(2, math.floor(t)))
    local changed = P.tier ~= t
    P.tier = t
    P.prev = {}
    if changed and P.lastTier ~= t then
        P.lastTier = t
        print("[BridgePerf] tier " .. tostring(t))
    end
    return "perf " .. tostring(t)
end

function P.statusText()
    return string.format("perf tier=%d zscan=%d/%d/%d bodyVar=%d outfit=%d ammo=%d scanFrame=%d snapshot=%d backup=%d items=%d wornBags=%d melee=%d fetch=%d",
        tier(), P.age("zscan"), P.age("zscanShort"), P.age("zscanTight"), P.age("bodyVar"),
        P.age("outfit"), P.age("ammoPresence"), P.age("scanFrame"),
        P.everyTier2.snapshot, P.everyTier2.backup,
        P.age("items"), P.age("wornBags"), P.age("melee"), P.age("fetchAmmo"))
end
