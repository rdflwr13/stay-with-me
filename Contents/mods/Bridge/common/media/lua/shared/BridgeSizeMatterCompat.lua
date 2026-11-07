BridgeSizeMatterCompat = BridgeSizeMatterCompat or {}
local M = BridgeSizeMatterCompat

local HEIGHT = "ZomboidTest1_HeightCm_v1"
local SHAPE = "VSM_BodyShape"
local MUSCLE = "VSM_Muscular"
local TOKEN = "VSM_MorphZombieToken"
local PROF_TOKEN = "VSM_ProfessionMorphToken"
local PROF = "VSM_MorphProfession"
local ALIFE_ROW = "VSM_ALifeBody_v1"
local LEGACY = "ZomboidTest1_ZombieHeight"
local NEUTRAL_MUSCLE = 0

M.wrapped = M.wrapped or {}
M.originals = M.originals or {}
M.resolved = M.resolved or {}
M.ticks = 0
M.lastResult = nil

local neutralised = setmetatable({}, { __mode = "k" })

local function say(text)
    print("[BridgeSizeMatterCompat] " .. tostring(text))
end

local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        say(text)
    end
end

local function activated()
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        if mods == nil then return end
        for index = 0, mods:size() - 1 do
            local id = tostring(mods:get(index))
            id = id:gsub("^[\\/]+", "")
            if id == "SizeMatter" then
                on = true
                return
            end
        end
    end)
    return on
end

local function cachedName(name)
    local direct = rawget(_G, name)
    if type(direct) == "table" then return direct end
    if type(package) ~= "table" or type(package.loaded) ~= "table" then return nil end
    local loaded = package.loaded[name]
    if type(loaded) == "table" then return loaded end
    loaded = package.loaded[name .. ".lua"]
    if type(loaded) == "table" then return loaded end
    for key, value in pairs(package.loaded) do
        if type(value) == "table" and type(key) == "string" then
            local tail = key:match("[\\/]([^\\/]+)$") or key
            if tail == name or tail == name .. ".lua" then return value end
        end
    end
    return nil
end

local function moduleOf(name)
    local cached = M.resolved[name]
    if type(cached) == "table" then return cached end
    local found = cachedName(name)
    if found ~= nil then
        M.resolved[name] = found
        return found
    end
    if not activated() then return nil end
    if type(require) == "function" then
        local ok, loaded = pcall(require, name)
        if ok and type(loaded) == "table" then
            M.resolved[name] = loaded
            return loaded
        end
    end
    found = cachedName(name)
    if found ~= nil then
        M.resolved[name] = found
        return found
    end
    return nil
end

function M.active()
    return moduleOf("VSMPolicy") ~= nil or moduleOf("VSMMorphPolicy") ~= nil or moduleOf("VSMALife") ~= nil
end

function M.isCompanion(z)
    if z == nil then return false end
    local bridge = rawget(_G, "Bridge")
    if type(bridge) == "table" and bridge.body ~= nil and bridge.body == z then return true end
    local marked = false
    pcall(function() marked = z:getVariableBoolean("NotAloneBody") == true end)
    if marked then return true end
    local data = nil
    pcall(function() data = z:getModData() end)
    if type(data) == "table" and data.notAloneBody == true then return true end
    local server = rawget(_G, "BridgeServer")
    if type(server) == "table" and type(server.isCompanionBody) == "function" then
        local ok, yes = pcall(server.isCompanionBody, z)
        if ok and yes == true then return true end
    end
    local companion = rawget(_G, "BridgeCompanion")
    if type(companion) == "table" and type(companion.isBody) == "function" then
        local ok, yes = pcall(companion.isBody, z)
        if ok and yes == true then return true end
    end
    return false
end

function M.recordOf(z)
    if z == nil then return nil end
    local bridge = rawget(_G, "Bridge")
    if type(bridge) == "table" then
        if bridge.body ~= nil and bridge.body == z and type(bridge.store) == "table" then return bridge.store end
        local pid = nil
        pcall(function() pid = z:getPersistentOutfitID() end)
        if pid ~= nil then
            if type(bridge.store) == "table" and bridge.store.bodyId == pid then return bridge.store end
            if type(bridge.bodyIndex) == "table" and type(bridge.world) == "table"
                    and type(bridge.world.players) == "table" then
                local owner = bridge.bodyIndex[pid]
                local rec = owner ~= nil and bridge.world.players[owner] or nil
                if type(rec) == "table" then return rec end
            end
        end
    end
    local server = rawget(_G, "BridgeServer")
    if type(server) == "table" and type(server.bodies) == "table" then
        local owner = nil
        for who, body in pairs(server.bodies) do
            if body == z then owner = who break end
        end
        if owner ~= nil then
            local data = rawget(_G, "BridgeData")
            if type(data) == "table" and type(data.world) == "function" then
                local ok, world = pcall(data.world, nil)
                if ok and type(world) == "table" and type(world.players) == "table" then
                    local rec = world.players[owner]
                    if type(rec) == "table" then return rec end
                end
            end
        end
    end
    return nil
end

function M.manual(rec)
    if type(rec) ~= "table" then return nil, nil end
    local data = rawget(_G, "BridgeData")
    if type(data) ~= "table" or type(data.appearanceOf) ~= "function" then return nil, nil end
    local ok, look = pcall(data.appearanceOf, rec)
    if not ok or type(look) ~= "table" then return nil, nil end
    local height = type(look.height) == "number" and look.height or nil
    local shape = type(look.shape) == "number" and look.shape or nil
    return height, shape
end

function M.neutralize(z, rec)
    if z == nil or not M.active() then return false end
    if rec == nil then rec = M.recordOf(z) end
    local data = nil
    pcall(function() data = z:getModData() end)
    if type(data) ~= "table" then return false end
    local manualHeight, manualShape = M.manual(rec)
    local changed = false
    if manualHeight == nil and data[HEIGHT] ~= nil then
        data[HEIGHT] = nil
        changed = true
    end
    if manualShape == nil then
        if data[SHAPE] ~= nil then
            data[SHAPE] = nil
            changed = true
        end
        if data[TOKEN] ~= nil then
            data[TOKEN] = nil
            changed = true
        end
    end
    if data[MUSCLE] ~= NEUTRAL_MUSCLE then
        data[MUSCLE] = NEUTRAL_MUSCLE
        changed = true
    end
    if data[PROF_TOKEN] ~= nil then
        data[PROF_TOKEN] = nil
        changed = true
    end
    if data[PROF] ~= nil then
        data[PROF] = nil
        changed = true
    end
    if data[ALIFE_ROW] ~= nil then
        data[ALIFE_ROW] = nil
        changed = true
    end
    if data[LEGACY] ~= nil then
        data[LEGACY] = nil
        changed = true
    end
    if changed then
        pcall(function() z:resetModelNextFrame() end)
    end
    if not neutralised[z] then
        neutralised[z] = true
        say(changed and "companion neutralised: sizing cleared"
            or "companion neutralised: sizing already neutral")
    end
    return changed
end

local function wrap(original)
    return function(first, ...)
        if M.isCompanion(first) then
            M.neutralize(first)
            return nil
        end
        return original(first, ...)
    end
end

local function hook(tbl, name, label)
    if type(tbl) ~= "table" then return "absent" end
    if type(tbl[name]) ~= "function" then return "missing" end
    if tbl[name] == M.wrapped[label] then return "ok" end
    local original = tbl[name]
    local wrapper = wrap(original)
    tbl[name] = wrapper
    M.wrapped[label] = wrapper
    M.originals[label] = original
    return "ok"
end

function M.install()
    local policy = moduleOf("VSMPolicy")
    local morph = moduleOf("VSMMorphPolicy")
    local life = moduleOf("VSMALife")
    local present = 0
    if policy ~= nil then present = present + 1 end
    if morph ~= nil then present = present + 1 end
    if life ~= nil then present = present + 1 end

    local count = 0
    if hook(policy, "assignZombie", "policy") == "ok" then count = count + 1 end
    if hook(morph, "assignZombie", "morph") == "ok" then count = count + 1 end
    if hook(life, "assign", "life") == "ok" then count = count + 1 end

    local result = "partial"
    if present == 0 then
        result = "absent"
    elseif count == 3 then
        result = "ok"
    end
    if result ~= M.lastResult then
        M.lastResult = result
        log("install " .. result)
    end
    if result == "ok" then
        M.installedOk = true
        if not M.announced then
            M.announced = true
            say("active: companion sizing blocked")
        end
    end
    return result
end

function M.reset()
    neutralised = setmetatable({}, { __mode = "k" })
    M.resolved = {}
end

local function bodyStub(companion)
    local data = {}
    return {
        __companion = companion == true,
        data = data,
        getVariableBoolean = function(self, name) return false end,
        getModData = function(self) return data end,
        getPersistentOutfitID = function(self) return 0 end,
        resetModelNextFrame = function(self) end,
    }
end

function M.selftest()
    local checks, fails = 0, {}
    local function check(name, value)
        checks = checks + 1
        if not value then fails[#fails + 1] = name end
    end

    local savedPolicy = rawget(_G, "VSMPolicy")
    local savedMorph = rawget(_G, "VSMMorphPolicy")
    local savedLife = rawget(_G, "VSMALife")
    local savedCompanion = rawget(_G, "BridgeCompanion")
    local hasPackage = type(package) == "table" and type(package.loaded) == "table"
    local savedLoadedLife = hasPackage and package.loaded["VSMALife"] or nil

    local calls = { normal = 0 }
    local function assignStub(actor)
        calls.normal = calls.normal + 1
        local data = actor:getModData()
        data.ZomboidTest1_HeightCm_v1 = 180
        data.VSM_BodyShape = 12
        data.VSM_Muscular = 40
        data.VSM_MorphZombieToken = "token"
        data.VSM_ProfessionMorphToken = "token"
        data.VSM_MorphProfession = "profile"
        data.VSM_ALifeBody_v1 = { cm = 180 }
        data.ZomboidTest1_ZombieHeight = { schema = 1, cm = 180 }
        return 180
    end

    local policy = { assignZombie = wrap(assignStub) }
    local morph = { assignZombie = wrap(assignStub) }
    local life = { assign = wrap(assignStub) }

    rawset(_G, "VSMPolicy", policy)
    rawset(_G, "VSMMorphPolicy", morph)
    rawset(_G, "VSMALife", life)
    rawset(_G, "BridgeCompanion", { isBody = function(z) return z ~= nil and z.__companion == true end,
        bodies = function() return {} end })
    if hasPackage then package.loaded["VSMALife"] = life end

    local companionBody = bodyStub(true)
    assignStub(companionBody)
    check("companion height cleared", policy.assignZombie(companionBody) == nil)
    check("companion height key cleared", companionBody.data.ZomboidTest1_HeightCm_v1 == nil)
    check("companion shape cleared", companionBody.data.VSM_BodyShape == nil)
    check("companion token cleared", companionBody.data.VSM_MorphZombieToken == nil)
    check("companion muscle zero", companionBody.data.VSM_Muscular == 0)
    check("companion alife cleared", companionBody.data.VSM_ALifeBody_v1 == nil)
    check("companion profession token cleared", companionBody.data.VSM_ProfessionMorphToken == nil)
    check("companion profession cleared", companionBody.data.VSM_MorphProfession == nil)
    check("companion legacy cleared", companionBody.data.ZomboidTest1_ZombieHeight == nil)
    check("morph companion returns nil", morph.assignZombie(companionBody) == nil)
    check("life companion returns nil", life.assign(companionBody) == nil)

    local ordinary = bodyStub(false)
    check("ordinary original returns", policy.assignZombie(ordinary) == 180)
    check("ordinary keeps height", ordinary.data.ZomboidTest1_HeightCm_v1 == 180)
    check("ordinary keeps shape", ordinary.data.VSM_BodyShape == 12)
    check("ordinary keeps muscle", ordinary.data.VSM_Muscular == 40)
    check("ordinary called original", calls.normal >= 1)

    rawset(_G, "VSMPolicy", savedPolicy)
    rawset(_G, "VSMMorphPolicy", savedMorph)
    rawset(_G, "VSMALife", savedLife)
    rawset(_G, "BridgeCompanion", savedCompanion)
    if hasPackage then package.loaded["VSMALife"] = savedLoadedLife end

    M.reset()
    if savedPolicy ~= nil or savedMorph ~= nil or savedLife ~= nil then pcall(M.install) end

    if #fails == 0 then return string.format("size matter compat selftest PASS (%d checks)", checks) end
    return string.format("size matter compat selftest FAIL (%d of %d): %s", #fails, checks,
        table.concat(fails, "; "))
end

local boot = select(2, pcall(M.install))
if boot == "ok" then M.installedOk = true end

if type(Events) == "table" then
    if Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function()
            M.reset()
            pcall(M.install)
        end)
    end
    if Events.OnServerStarted ~= nil then
        Events.OnServerStarted.Add(function()
            M.reset()
            pcall(M.install)
        end)
    end
    if Events.OnTick ~= nil then
        Events.OnTick.Add(function()
            if M.installedOk then return end
            M.ticks = (M.ticks or 0) + 1
            if M.ticks % 60 ~= 1 then return end
            local ok, result = pcall(M.install)
            if ok and result == "ok" then M.installedOk = true end
        end)
    end
end

return M
