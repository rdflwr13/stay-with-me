BridgeTHECompat = BridgeTHECompat or {}
local M = BridgeTHECompat

local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeTHECompat] " .. tostring(text))
    end
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

function M.filterTargets(out)
    if type(out) ~= "table" then return end
    for i = #out, 1, -1 do
        local t = out[i]
        if type(t) == "table" and M.isBody(t.obj) then
            table.remove(out, i)
            if not M.testing and not M.seen then
                M.seen = true
                log("first companion target filtered from THE gunner")
            end
        end
    end
end

local function patchRunner(runner)
    if type(runner) ~= "function" then return false, "runner is not a function" end
    if not (debug and debug.getupvalue and debug.setupvalue) then
        return false, "debug upvalue API missing"
    end
    if M.installed and M.runner == runner then return true end

    local index = 1
    while true do
        local name, value = debug.getupvalue(runner, index)
        if not name then break end
        if name == "zombieTargets" and type(value) == "function" then
            local original = value
            local wrapper = function(ac, out)
                original(ac, out)
                M.filterTargets(out)
            end
            if not debug.setupvalue(runner, index, wrapper) then
                return false, "debug.setupvalue failed"
            end
            M.original = original
            M.wrapper = wrapper
            M.runner = runner
            M.upvalueIndex = index
            M.installed = true
            return true
        end
        index = index + 1
    end

    return false, "zombieTargets upvalue not found"
end

function M.uninstall()
    if not M.installed or M.runner == nil or M.original == nil then return false, "not installed" end
    if not (debug and debug.setupvalue) then return false, "debug upvalue API missing" end
    local ok = debug.setupvalue(M.runner, M.upvalueIndex, M.original)
    if not ok then return false, "debug.setupvalue failed" end
    M.installed = false
    M.runner = nil
    M.upvalueIndex = nil
    M.original = nil
    M.wrapper = nil
    return true
end

function M.install()
    local THE = rawget(_G, "THE")
    if type(THE) ~= "table" then return false, "THE not loaded" end
    if THE.MODID ~= "TrueHelicopterEvents" then return false, "THE.MODID mismatch" end
    if type(THE.Gunner) ~= "table" or type(THE.Gunner.update) ~= "function" then
        return false, "THE.Gunner.update missing"
    end
    local ok, why = patchRunner(THE.Gunner.update)
    if ok then log("installed: THE.Gunner.zombieTargets filters the companion") end
    return ok, why
end

function M.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local savedBridge = rawget(_G, "Bridge")
    local savedInstalled = M.installed
    local savedRunner = M.runner
    local savedUpvalueIndex = M.upvalueIndex
    local savedOriginal = M.original
    local savedWrapper = M.wrapper
    local savedTesting = M.testing
    local savedSeen = M.seen

    local function stub(md, vars)
        local z = { md = md or {}, vars = vars or {} }
        function z:hasModData() return true end
        function z:getModData() return self.md end
        function z:getVariableBoolean(name) return self.vars[name] == true end
        return z
    end

    local plain = stub({}, {})
    local tagged = stub({}, { NotAloneBody = true })
    local dataTagged = stub({ notAloneBody = true }, {})
    local bridgeBody = stub({}, {})

    rawset(_G, "Bridge", { body = bridgeBody, BODY_VAR = "NotAloneBody" })
    M.testing = true

    check("isBody Bridge.body", M.isBody(bridgeBody) == true)
    check("isBody variable", M.isBody(tagged) == true)
    check("isBody mod data", M.isBody(dataTagged) == true)
    check("isBody plain", M.isBody(plain) == false)

    local first = { obj = bridgeBody }
    local second = { obj = plain }
    local third = { obj = tagged }
    local out = { first, second, third }
    M.filterTargets(out)
    check("filterTargets removes companion", #out == 1 and out[1] == second)
    check("filterTargets keeps order", out[1] == second)

    local function zombieTargets(ac, list)
        list[#list + 1] = { obj = bridgeBody }
        list[#list + 1] = { obj = plain }
    end
    local function fakeUpdate(ac, list)
        zombieTargets(ac, list)
    end

    M.installed, M.runner, M.upvalueIndex, M.original, M.wrapper = nil, nil, nil, nil, nil

    local okPatch = patchRunner(fakeUpdate)
    check("patchRunner installs", okPatch == true)

    local list = {}
    fakeUpdate(nil, list)
    check("companion filtered from runner", #list == 1 and list[1].obj == plain)

    local okSecond = patchRunner(fakeUpdate)
    local list2 = {}
    fakeUpdate(nil, list2)
    check("patchRunner is idempotent", okSecond == true and #list2 == 1)

    local okUninstall = M.uninstall()
    local list3 = {}
    fakeUpdate(nil, list3)
    check("uninstall restores original", okUninstall == true and #list3 == 2)

    local function noUpvalue(ac, list4)
        return list4
    end
    M.installed, M.runner, M.upvalueIndex, M.original, M.wrapper = nil, nil, nil, nil, nil
    local okNone, whyNone = patchRunner(noUpvalue)
    check("missing upvalue fails", okNone == false and type(whyNone) == "string")

    M.installed, M.runner, M.upvalueIndex, M.original, M.wrapper, M.testing, M.seen =
        savedInstalled, savedRunner, savedUpvalueIndex, savedOriginal, savedWrapper, savedTesting, savedSeen
    rawset(_G, "Bridge", savedBridge)

    if #fails == 0 then return string.format("thecompat PASS (%d checks)", checks) end
    return string.format("thecompat FAIL (%d of %d): %s", checks, #fails, table.concat(fails, "; "))
end

local function tryInstall(quiet)
    local ok, why = M.install()
    if not ok and not quiet and M.lastFailure ~= why then
        M.lastFailure = why
        log("not installed: " .. tostring(why))
    end
end

tryInstall(true)

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function()
        if not M.installed then tryInstall(false) end
    end)
end
