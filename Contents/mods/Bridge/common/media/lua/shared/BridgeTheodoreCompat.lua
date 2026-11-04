BridgeTheodoreCompat = BridgeTheodoreCompat or {}

local M = BridgeTheodoreCompat

local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeTheodoreCompat] " .. tostring(text))
    end
end

function M.isBody(z)
    if z == nil then return false end

    local T = rawget(_G, "Theodore")
    if type(T) == "table" then
        if type(T.getBody) == "function" then
            local body = nil
            pcall(function() body = T.getBody() end)
            if body ~= nil and body == z then return true end
        end
        if type(T.isHisZombie) == "function" then
            local yes = nil
            pcall(function() yes = T.isHisZombie(z) end)
            if yes == true then return true end
        end
    end

    local hasData = false
    pcall(function() hasData = z:hasModData() == true end)
    if hasData then
        local md = nil
        pcall(function() md = z:getModData() end)
        if type(md) == "table" and md.isTheodore == true then return true end
    end

    local human = false
    pcall(function() human = z:getVariableBoolean("TheodoreHuman") == true end)
    if human then return true end

    return false
end

function M.install()
    local data = rawget(_G, "BridgeData")
    if type(data) ~= "table" or type(data.foreignPeaceful) ~= "function" then
        return "absent"
    end
    if M.installed == true then return "ok" end

    local original = data.foreignPeaceful
    local wrapper = function(z, ...)
        if M.isBody(z) then
            if not M.seen then
                M.seen = true
                log("Theodore recognised: his body is not a target")
            end
            return true
        end
        return original(z, ...)
    end

    data.foreignPeaceful = wrapper
    M.wrapper = wrapper
    M.original = original
    M.installed = true
    log("installed: BridgeData.foreignPeaceful knows Theodore")
    return "ok"
end

function M.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local savedTheodore = rawget(_G, "Theodore")
    local savedBridgeData = rawget(_G, "BridgeData")
    local savedInstalled = M.installed
    local savedWrapper = M.wrapper
    local savedOriginal = M.original
    local savedSeen = M.seen

    local function stub(md, vars)
        local z = { md = md or {}, vars = vars or {} }
        function z:hasModData() return true end
        function z:getModData() return self.md end
        function z:getVariableBoolean(name) return self.vars[name] == true end
        return z
    end

    local plain = stub({}, {})
    local tagged = stub({ isTheodore = true }, {})
    local variant = stub({}, { TheodoreHuman = true })
    local his = stub({}, {})

    check("nil is not Theodore", M.isBody(nil) == false)
    check("plain body is not Theodore", M.isBody(plain) == false)
    check("isTheodore tag", M.isBody(tagged) == true)
    check("TheodoreHuman variable", M.isBody(variant) == true)

    rawset(_G, "Theodore", { isHisZombie = function(z) return z == his end })
    check("isHisZombie match", M.isBody(his) == true)
    check("isHisZombie miss", M.isBody(plain) == false)

    rawset(_G, "Theodore", { getBody = function() return his end })
    check("getBody identity", M.isBody(his) == true)
    check("getBody miss", M.isBody(plain) == false)

    local calls, lastPlayer = 0, nil
    local data = {
        foreignPeaceful = function(z, player)
            calls = calls + 1
            lastPlayer = player
            return "sentinel"
        end,
    }
    rawset(_G, "BridgeData", data)
    M.installed, M.wrapper, M.original, M.seen = nil, nil, nil, nil

    check("install ok", M.install() == "ok")
    check("installed flag", M.installed == true)
    local wrapped = data.foreignPeaceful
    check("Theodore is peaceful", wrapped(his, "playerA") == true)
    check("original not called for Theodore", calls == 0)
    check("plain forwards sentinel", wrapped(plain, "playerB") == "sentinel")
    check("original called once", calls == 1)
    check("player forwarded", lastPlayer == "playerB")
    check("second original call", wrapped(plain, "playerC") == "sentinel" and calls == 2)
    M.install()
    check("install is idempotent", data.foreignPeaceful == wrapped and calls == 2)

    M.installed, M.wrapper, M.original, M.seen =
        savedInstalled, savedWrapper, savedOriginal, savedSeen
    rawset(_G, "Theodore", savedTheodore)
    rawset(_G, "BridgeData", savedBridgeData)

    if #fails == 0 then return string.format("theodoreselftest PASS (%d checks)", checks) end
    return string.format("theodoreselftest FAIL (%d of %d): %s", checks, #fails, table.concat(fails, "; "))
end

pcall(M.install)

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function()
        if not M.installed then pcall(M.install) end
    end)
end
