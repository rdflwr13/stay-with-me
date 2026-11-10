BridgeSight = BridgeSight or {}

BridgeSight.SCALES = { 1.0, 0.75, 0.5, 0.3 }
BridgeSight.TORCH_FLOOR = 0.8
BridgeSight.RELEASE_BUFFER = 0.15
BridgeSight.stats = { lightCalls = 0 }
BridgeSight.memo = { tick = nil, byBody = setmetatable({}, { __mode = "k" }) }
BridgeSight.scaleTick = nil
BridgeSight.scaleValue = nil
BridgeSight.lastFactor = 1.0
BridgeSight.lastLevel = nil

local function tickNow()
    if Bridge ~= nil then
        local t = tonumber(Bridge.tick)
        if t ~= nil then return t end
    end
    return 0
end

function BridgeSight.scale()
    if BridgeSight.testScale ~= nil then return BridgeSight.testScale end
    local tick = tickNow()
    if BridgeSight.scaleTick == tick and BridgeSight.scaleValue ~= nil then
        return BridgeSight.scaleValue
    end
    local index = 1
    if BridgeData ~= nil and type(BridgeData.sandboxNumber) == "function" then
        local ok, value = pcall(BridgeData.sandboxNumber, "NightSight", 1, 1, 4)
        if ok then index = tonumber(value) or 1 end
    end
    if index < 1 then index = 1 end
    if index > #BridgeSight.SCALES then index = #BridgeSight.SCALES end
    local scale = BridgeSight.SCALES[index] or 1.0
    BridgeSight.scaleTick, BridgeSight.scaleValue = tick, scale
    return scale
end

function BridgeSight.reset(reason)
    BridgeSight.memo = { tick = nil, byBody = setmetatable({}, { __mode = "k" }) }
    BridgeSight.scaleTick = nil
    BridgeSight.scaleValue = nil
    BridgeSight.lastReason = reason
end

function BridgeSight.factor(body)
    local scale = BridgeSight.scale()
    if scale >= 1.0 then return 1.0 end
    if body == nil then return 1.0 end
    if BridgeSight.testEntry == nil and (BridgeLight == nil or type(BridgeLight.at) ~= "function") then
        return 1.0
    end
    if BridgeSight.testEntry == nil and BridgeTorchShared == nil then return 1.0 end

    local tick = (Bridge ~= nil and tonumber(Bridge.tick)) or tickNow()
    local cached = BridgeSight.memo.byBody[body]
    if cached ~= nil and cached.tick == tick then return cached.value end

    local entry = BridgeSight.testEntry
    if entry == nil then
        local ok, got = pcall(BridgeLight.at, body)
        BridgeSight.stats.lightCalls = BridgeSight.stats.lightCalls + 1
        if not ok or got == nil then
            BridgeSight.memo.byBody[body] = { tick = tick, value = 1.0 }
            return 1.0
        end
        entry = got
    end

    local f = 1.0
    if entry.external == true then
        f = 1.0
    else
        local lvl = tonumber(entry.raw)
        if lvl == nil then
            f = 1.0
        else
            local cfg = nil
            if BridgeTorchShared ~= nil then cfg = BridgeTorchShared.CFG end
            local lo, hi = 0.45, 0.55
            if entry.inside == true then
                lo = (cfg ~= nil and cfg.DARK_LO_IN) or 0.50
            else
                lo = (cfg ~= nil and cfg.DARK_LO) or 0.45
            end
            hi = (cfg ~= nil and cfg.DARK_HI) or 0.55
            if hi <= lo then hi = lo + 0.01 end
            if lvl <= lo then
                f = scale
            elseif lvl >= hi then
                f = 1.0
            else
                f = scale + (lvl - lo) / (hi - lo) * (1.0 - scale)
            end
        end
    end

    local torchOn = false
    if BridgeSight.testTorch ~= nil then
        torchOn = BridgeSight.testTorch == true
    elseif BridgeTorchShared ~= nil and type(BridgeTorchShared.isOn) == "function" then
        local ok, value = pcall(BridgeTorchShared.isOn, body)
        torchOn = ok and value == true
    end
    if torchOn and f < BridgeSight.TORCH_FLOOR then f = BridgeSight.TORCH_FLOOR end
    if f < scale then f = scale end
    if f > 1.0 then f = 1.0 end

    BridgeSight.memo.byBody[body] = { tick = tick, value = f }
    BridgeSight.memo.tick = tick
    BridgeSight.lastFactor = f
    BridgeSight.lastLevel = entry.raw
    return f
end

function BridgeSight.range(base, body)
    local factor = BridgeSight.factor(body)
    if factor == 1.0 then return base end
    return base * factor
end

function BridgeSight.releaseFactor(body)
    local factor = BridgeSight.factor(body)
    local release = factor + BridgeSight.RELEASE_BUFFER
    if release > 1.0 then release = 1.0 end
    return release
end

function BridgeSight.releaseRange(base, body)
    local factor = BridgeSight.releaseFactor(body)
    if factor == 1.0 then return base end
    return base * factor
end

function BridgeSight.statusText()
    return string.format("sight scale=%.2f factor=%.2f level=%s",
        BridgeSight.scale(), BridgeSight.lastFactor or 1.0, tostring(BridgeSight.lastLevel))
end

function BridgeSight.selftest()
    local checks, fails = 0, {}
    local function check(name, got, want)
        checks = checks + 1
        if got ~= want then
            fails[#fails + 1] = string.format("%s got=%s want=%s", name, tostring(got), tostring(want))
        end
    end
    local function near(name, got, want)
        checks = checks + 1
        if type(got) ~= "number" or math.abs(got - want) > 0.0001 then
            fails[#fails + 1] = string.format("%s got=%s want=%s", name, tostring(got), tostring(want))
        end
    end

    local oldLight = BridgeLight
    local oldTorch = BridgeTorchShared
    local oldScale = BridgeSight.testScale
    local oldEntry = BridgeSight.testEntry
    local oldTorchTest = BridgeSight.testTorch
    local oldMemo = BridgeSight.memo
    local oldStats = BridgeSight.stats

    local body = {}
    local okAll, errAll = pcall(function()
        BridgeSight.stats = { lightCalls = 0 }

        BridgeSight.testScale, BridgeSight.testEntry, BridgeSight.testTorch = 0.5, nil, nil
        BridgeLight = nil
        BridgeSight.reset("selftest")
        check("missing light", BridgeSight.factor(body), 1.0)
        BridgeLight = oldLight

        BridgeTorchShared = nil
        BridgeSight.reset("selftest")
        check("missing torch shared", BridgeSight.factor(body), 1.0)
        BridgeTorchShared = oldTorch

        BridgeSight.testScale, BridgeSight.testEntry, BridgeSight.testTorch = 1.0, nil, false
        BridgeSight.stats.lightCalls = 0
        BridgeSight.reset("selftest")
        check("off factor", BridgeSight.factor(body), 1.0)
        check("off light calls", BridgeSight.stats.lightCalls, 0)

        BridgeSight.testScale, BridgeSight.testTorch = 0.5, false
        BridgeSight.testEntry = { raw = 0.10, external = true, inside = false }
        BridgeSight.reset("selftest")
        check("external", BridgeSight.factor(body), 1.0)

        BridgeSight.testEntry = { raw = 0.10, external = false, inside = false }
        BridgeSight.reset("selftest")
        near("dark low", BridgeSight.factor(body), 0.5)

        BridgeSight.testEntry = { raw = 0.90, external = false, inside = false }
        BridgeSight.reset("selftest")
        check("dark high", BridgeSight.factor(body), 1.0)

        BridgeSight.testEntry = { raw = 0.50, external = false, inside = false }
        BridgeSight.reset("selftest")
        near("dark middle", BridgeSight.factor(body), 0.75)

        BridgeSight.testEntry = { raw = 0.10, external = false, inside = false }
        BridgeSight.testTorch = true
        BridgeSight.reset("selftest")
        near("torch floor", BridgeSight.factor(body), 0.8)

        BridgeSight.testTorch = false
        BridgeSight.testEntry = { raw = 0.10, external = false, inside = false }
        BridgeSight.reset("selftest")
        local base = BridgeSight.range(10, body)
        local release = BridgeSight.releaseRange(10, body)
        near("range", base, 5.0)
        near("release range", release, 6.5)
        check("release wider", release > base, true)

        local calls = 0
        BridgeSight.testEntry = nil
        BridgeSight.testTorch = nil
        BridgeSight.testScale = 0.5
        BridgeLight = { at = function() calls = calls + 1 return { raw = 0.10, external = false, inside = false } end }
        BridgeTorchShared = { CFG = { DARK_LO = 0.45, DARK_HI = 0.55, DARK_LO_IN = 0.50 },
            isOn = function() return false end }
        BridgeSight.stats.lightCalls = 0
        BridgeSight.reset("selftest")
        local first = BridgeSight.factor(body)
        local second = BridgeSight.factor(body)
        near("memo value", second, first)
        check("memo one call", calls, 1)
    end)

    BridgeLight, BridgeTorchShared = oldLight, oldTorch
    BridgeSight.testScale, BridgeSight.testEntry, BridgeSight.testTorch = oldScale, oldEntry, oldTorchTest
    BridgeSight.memo = oldMemo
    BridgeSight.stats = oldStats
    if not okAll then fails[#fails + 1] = "selftest error: " .. tostring(errAll) end
    if #fails == 0 then return string.format("sightselftest PASS (%d checks)", checks) end
    return string.format("sightselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end

if Events ~= nil then
    Events.OnGameStart.Add(function() pcall(BridgeSight.reset, "start") end)
    Events.OnCreatePlayer.Add(function() pcall(BridgeSight.reset, "player") end)
    Events.OnResetLua.Add(function() pcall(BridgeSight.reset, "reset") end)
end

if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then print("[BridgeSight] loaded") end
