BridgeTHECompat = BridgeTHECompat or {}
local M = BridgeTHECompat

local MOD_ID = "TrueHelicopterEvents"
local RETRY_EVERY = 60
local ticks = 0

M.MOD_ID = MOD_ID
M.RETRY_EVERY = RETRY_EVERY

local function warn(text)
    if M.testing then return end
    print("[BridgeTHECompat] " .. tostring(text))
end

local function hasMod(mods)
    if mods == nil then return false end
    local function match(id)
        id = tostring(id)
        return id == MOD_ID or id == "\\" .. MOD_ID
    end
    if type(mods) == "table" then
        for _, id in ipairs(mods) do
            if match(id) then return true end
        end
        return false
    end
    local ok, yes = pcall(function() return mods:contains(MOD_ID) end)
    if ok and yes then return true end
    ok, yes = pcall(function() return mods:contains("\\" .. MOD_ID) end)
    if ok and yes then return true end
    local n = 0
    pcall(function() n = mods:size() end)
    for i = 0, n - 1 do
        local id = nil
        pcall(function() id = mods:get(i) end)
        if id ~= nil and match(id) then return true end
    end
    return false
end

function M.active()
    local on = false
    pcall(function() on = hasMod(getActivatedMods()) end)
    return on
end

local function bodyVar()
    local bridge = rawget(_G, "Bridge")
    if type(bridge) == "table" and type(bridge.BODY_VAR) == "string" then return bridge.BODY_VAR end
    return "NotAloneBody"
end

function M.isBody(z)
    if z == nil then return false end

    local bridge = rawget(_G, "Bridge")
    if type(bridge) == "table" and bridge.body ~= nil and bridge.body == z then return true end

    local companion = rawget(_G, "BridgeCompanion")
    if type(companion) == "table" and type(companion.isBody) == "function" then
        local ok, yes = pcall(companion.isBody, z)
        if ok and yes == true then return true end
    end

    local marked = false
    pcall(function() marked = z:getVariableBoolean(bodyVar()) == true end)
    if marked then return true end

    local hasData = false
    pcall(function() hasData = z:hasModData() == true end)
    if hasData then
        local md = nil
        pcall(function() md = z:getModData() end)
        if type(md) == "table" and md.notAloneBody == true then return true end
    end

    return false
end

function M.companionInCoverRange(ac)
    local bridge = rawget(_G, "Bridge")
    local body = type(bridge) == "table" and bridge.body or nil
    if body == nil then return false end

    local flight = ac ~= nil and ac.flight or nil
    local div = type(flight) == "table" and flight.div or nil
    if type(div) ~= "table" then return false end

    local gx, gy = nil, nil
    pcall(function() gx = div.gx or div.x end)
    pcall(function() gy = div.gy or div.y end)
    if type(gx) ~= "number" or type(gy) ~= "number" then return false end

    local the = rawget(_G, "THE")
    local radius = type(the) == "table" and tonumber(the.FIRE_COVER_R) or nil
    if radius == nil or radius <= 0 then radius = 15 end

    local bx, by = nil, nil
    pcall(function() bx = body:getX() end)
    pcall(function() by = body:getY() end)
    if type(bx) ~= "number" or type(by) ~= "number" then return false end

    local dx, dy = bx - gx, by - gy
    return dx * dx + dy * dy <= radius * radius
end

local function notInstalled(quiet, reason)
    if not quiet and M.lastFailure ~= reason then
        M.lastFailure = reason
        warn("not installed: " .. reason)
    end
    return false, reason
end

function M.install(quiet)
    local the = rawget(_G, "THE")
    if type(the) ~= "table" then return notInstalled(quiet, "THE not loaded") end
    if the.MODID ~= MOD_ID then return notInstalled(quiet, "THE.MODID mismatch") end
    if type(the.Gunner) ~= "table" or type(the.Gunner.update) ~= "function" then
        return notInstalled(quiet, "THE.Gunner.update missing")
    end
    if type(the.Rules) ~= "table" then return notInstalled(quiet, "THE.Rules missing") end

    if the.Gunner.update == M.wrapper then
        M.installed = true
        if not quiet and not M.reported then
            M.reported = true
            warn("installed: THE.Gunner.update guard")
        end
        return true
    end

    if M.wrapper ~= nil then
        M.original, M.wrapper, M.mode = nil, nil, nil
        M.installed = false
        M.reported = false
    end

    local original = the.Gunner.update
    local wrapper = function(ac, players, dtMin)
        if not M.companionInCoverRange(ac) then
            return original(ac, players, dtMin)
        end
        if not M.testing and not M.seen then
            M.seen = true
            warn("gunner help suppressed: companion in cover range")
        end
        local rules = rawget(_G, "THE")
        rules = type(rules) == "table" and rules.Rules or nil
        local saved = type(rules) == "table" and rules.helping or nil
        if type(saved) == "function" then
            rules.helping = function(a)
                if a == ac then return false end
                return saved(a)
            end
            local ok, result = pcall(original, ac, players, dtMin)
            rules.helping = saved
            if not ok then error(result, 0) end
            M.mode = "helping"
            return result
        end
        M.mode = "skip"
        return nil
    end

    the.Gunner.update = wrapper
    M.original, M.wrapper, M.mode = original, wrapper, "helping"
    M.installed = true
    M.lastFailure = nil
    if not quiet and not M.reported then
        M.reported = true
        warn("installed: THE.Gunner.update guard")
    end
    return true
end

function M.uninstall()
    local the = rawget(_G, "THE")
    local gunner = type(the) == "table" and the.Gunner or nil
    if M.wrapper ~= nil and type(gunner) == "table" and gunner.update == M.wrapper then
        gunner.update = M.original
    end
    M.original, M.wrapper, M.mode = nil, nil, nil
    M.installed = false
    M.reported = false
    return true
end

function M.status()
    local the = rawget(_G, "THE")
    local gunner = type(the) == "table" and the.Gunner or nil
    local live = M.wrapper ~= nil and type(gunner) == "table" and gunner.update == M.wrapper
    return string.format("thecompat status installed=%s mode=%s live=%s seen=%s",
        tostring(M.installed == true), tostring(M.mode or "none"),
        tostring(live), tostring(M.seen == true))
end

function M.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local saved = {
        bridge = rawget(_G, "Bridge"),
        the = rawget(_G, "THE"),
        installed = M.installed, original = M.original, wrapper = M.wrapper,
        mode = M.mode, seen = M.seen, reported = M.reported,
        lastFailure = M.lastFailure, testing = M.testing,
    }

    local function resetModule()
        M.installed, M.original, M.wrapper, M.mode = nil, nil, nil, nil
        M.seen, M.reported, M.lastFailure = nil, nil, nil
    end

    M.testing = true

    local body = { x = 1000, y = 1000 }
    function body:getX() return self.x end
    function body:getY() return self.y end
    rawset(_G, "Bridge", { body = body })

    local calls = 0
    local seenHelping = nil
    local otherHelping = nil
    local helping = function() return true end
    local function original(ac, players, dtMin)
        calls = calls + 1
        seenHelping = THE.Rules.helping(ac)
        otherHelping = THE.Rules.helping({ flight = { div = { gx = 9999, gy = 9999 } } })
        return "ran"
    end

    rawset(_G, "THE", {
        MODID = "TrueHelicopterEvents",
        FIRE_COVER_R = 15,
        Gunner = { update = original },
        Rules = { helping = helping },
    })

    local acNear = { flight = { div = { gx = 1000, gy = 1000 } } }
    local acFar = { flight = { div = { gx = 0, gy = 0 } } }

    resetModule()
    check("install guards gunner", M.install(false) == true and M.installed == true)
    check("status installed live", M.status():find("installed=true", 1, true) ~= nil
        and M.status():find("live=true", 1, true) ~= nil)
    check("gunner update wrapped", THE.Gunner.update == M.wrapper)

    calls = 0
    local farResult = THE.Gunner.update(acFar, {}, 0.1)
    check("far calls original", calls == 1 and farResult == "ran")
    check("far leaves helping", THE.Rules.helping == helping)

    calls = 0
    local nearResult = THE.Gunner.update(acNear, {}, 0.1)
    check("near calls original", calls == 1 and nearResult == "ran")
    check("near sees helping false", seenHelping == false)
    check("other target still helping", otherHelping == true)
    check("helping restored after call", THE.Rules.helping == helping)
    check("mode helping", M.mode == "helping")

    local savedBody = Bridge.body
    Bridge.body = nil
    calls = 0
    THE.Gunner.update(acNear, {}, 0.1)
    check("nil body calls original", calls == 1)
    Bridge.body = savedBody

    local raised = function() error("boom") end
    rawset(_G, "THE", {
        MODID = "TrueHelicopterEvents",
        FIRE_COVER_R = 15,
        Gunner = { update = raised },
        Rules = { helping = helping },
    })
    M.install(false)
    local raisedWrapper = THE.Gunner.update
    local okRaise, errRaise = pcall(raisedWrapper, acNear, {}, 0.1)
    check("error propagates", okRaise == false and tostring(errRaise):find("boom", 1, true) ~= nil)
    check("error restores helping", THE.Rules.helping == helping)

    local skipOriginal = function() calls = calls + 1 end
    rawset(_G, "THE", {
        MODID = "TrueHelicopterEvents",
        FIRE_COVER_R = 15,
        Gunner = { update = skipOriginal },
        Rules = {},
    })
    M.install(false)
    calls = 0
    THE.Gunner.update(acNear, {}, 0.1)
    check("missing helping skips original", calls == 0 and M.mode == "skip")
    THE.Gunner.update(acFar, {}, 0.1)
    check("missing helping far calls original", calls == 1)

    local wrapped = THE.Gunner.update
    check("install idempotent", M.install(false) == true and THE.Gunner.update == wrapped)

    local lastOriginal = function() calls = calls + 1 end
    rawset(_G, "THE", {
        MODID = "TrueHelicopterEvents",
        FIRE_COVER_R = 15,
        Gunner = { update = lastOriginal },
        Rules = {},
    })
    M.install(false)
    local okUninstall = M.uninstall()
    check("uninstall restores original", okUninstall == true and THE.Gunner.update == lastOriginal)
    check("uninstall clears wrapper", M.installed ~= true and M.wrapper == nil)

    check("isBody Bridge.body", M.isBody(body) == true)
    local plain = {}
    function plain:getVariableBoolean() return false end
    function plain:hasModData() return false end
    check("isBody plain", M.isBody(plain) == false)

    M.installed, M.original, M.wrapper = saved.installed, saved.original, saved.wrapper
    M.mode, M.seen, M.reported = saved.mode, saved.seen, saved.reported
    M.lastFailure, M.testing = saved.lastFailure, saved.testing
    rawset(_G, "Bridge", saved.bridge)
    rawset(_G, "THE", saved.the)

    if #fails == 0 then return string.format("thecompat PASS (%d checks)", checks) end
    return string.format("thecompat FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end

M.install(true)

if type(Events) == "table" and Events.OnGameStart ~= nil and Events.OnGameStart.Add ~= nil then
    Events.OnGameStart.Add(function()
        M.seen = false
        if M.active() then M.install(false) end
    end)
end

if type(Events) == "table" and Events.OnTick ~= nil and Events.OnTick.Add ~= nil then
    Events.OnTick.Add(function()
        ticks = ticks + 1
        if ticks % RETRY_EVERY ~= 0 then return end
        if not M.active() then return end
        pcall(M.install, false)
    end)
end
