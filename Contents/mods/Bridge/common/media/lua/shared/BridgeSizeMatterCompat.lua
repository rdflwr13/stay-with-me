BridgeSizeMatterCompat = BridgeSizeMatterCompat or {}
local M = BridgeSizeMatterCompat

local HEIGHT = "ZomboidTest1_HeightCm_v1"
local SHAPE = "VSM_BodyShape"
local MUSCLE = "VSM_Muscular"
local DETAILS = "VSM_Details"
local MODEL = "VSM_BodyModel"
local ITEMS = "VSM_ItemsScaleWithHeight"
local MANAGED = "VSM_CompanionManaged"
local TOKEN = "VSM_MorphZombieToken"
local PROF_TOKEN = "VSM_ProfessionMorphToken"
local PROF = "VSM_MorphProfession"
local ALIFE_ROW = "VSM_ALifeBody_v1"
local LEGACY = "ZomboidTest1_ZombieHeight"
local NEUTRAL_MUSCLE = 0
local TOKEN_MAX = 512

M.DETAILS = {
    { id = "Shoulder_Volume", label = "Shoulder Volume" },
    { id = "UpperArm_Size", label = "UpperArm Size" },
    { id = "Forearm_Size", label = "Forearm Size" },
    { id = "Wrist_Size", label = "Wrist Size" },
    { id = "Chest_Width", label = "Chest Width" },
    { id = "Chest_Depth", label = "Chest Depth" },
    { id = "Breast_Volume", label = "Breast Volume" },
    { id = "Waist_Width", label = "Waist Width" },
    { id = "Waist_Depth", label = "Waist Depth" },
    { id = "Abdomen_Volume", label = "Abdomen Volume" },
    { id = "Hip_Width", label = "Hip Width" },
    { id = "Buttock_Volume", label = "Buttock Volume" },
    { id = "Thigh_Size", label = "Thigh Size" },
    { id = "Calf_Size", label = "Calf Size" },
    { id = "Ankle_Size", label = "Ankle Size" },
    { id = "Neck_Size", label = "Neck Size" },
    { id = "Breast_Width", label = "Breast Width" },
    { id = "Breast_Projection", label = "Breast Projection" },
    { id = "Buttock_Width", label = "Buttock Width" },
    { id = "Buttock_Projection", label = "Buttock Projection" },
}

M.GROUPS = {
    { id = "Torso", indexes = { 5, 6, 8, 9, 10 } },
    { id = "Breast", indexes = { 7, 17, 18 } },
    { id = "Arms", indexes = { 1, 2, 3, 4 } },
    { id = "Pelvis", indexes = { 11, 12, 19, 20 } },
    { id = "Legs", indexes = { 13, 14, 15 } },
    { id = "Neck", indexes = { 16 } },
}

M.wrapped = M.wrapped or {}
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

local function clampInt(value, lo, hi, fallback)
    local n = tonumber(value)
    if n == nil or n ~= n then n = fallback end
    n = math.floor(n)
    if n < lo then n = lo end
    if n > hi then n = hi end
    return n
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

function M.available()
    return moduleOf("VSMDetails") ~= nil and moduleOf("VSMPolicy") ~= nil
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

function M.heightBounds()
    local policy = moduleOf("VSMPolicy")
    if policy == nil then return 145, 220 end
    local limited = true
    local controls = moduleOf("VSMControls")
    if controls ~= nil and type(controls.snapshot) == "function" then
        local ok, options = pcall(controls.snapshot)
        if ok and type(options) == "table" and options.HeightLimits == false then limited = false end
    end
    if not limited then
        local hi = tonumber(policy.MAX_CM) or 2147483646
        if hi < 2 then hi = 2147483646 end
        return 1, hi
    end
    local ok, lo, hi = pcall(policy.characterRange)
    if ok and type(lo) == "number" and type(hi) == "number" and lo == lo and hi == hi then
        if lo > hi then lo, hi = hi, lo end
        return lo, hi
    end
    return 145, 220
end

function M.shapeBounds()
    local morph = moduleOf("VSMMorphPolicy")
    if morph ~= nil and type(morph.range) == "function" then
        local ok, lo, hi = pcall(morph.range, "Character", "BodyShape")
        if ok and type(lo) == "number" and type(hi) == "number" and lo == lo and hi == hi then
            if lo > hi then lo, hi = hi, lo end
            return lo, hi
        end
    end
    return -100, 100
end

function M.muscleBounds()
    local morph = moduleOf("VSMMorphPolicy")
    if morph ~= nil and type(morph.range) == "function" then
        local ok, lo, hi = pcall(morph.range, "Character", "Muscular")
        if ok and type(lo) == "number" and type(hi) == "number" and lo == lo and hi == hi then
            if lo > hi then lo, hi = hi, lo end
            return lo, hi
        end
    end
    return 0, 100
end

function M.detailValues(text)
    local details = moduleOf("VSMDetails")
    if details ~= nil and type(details.decode) == "function" then
        local ok, values = pcall(details.decode, text)
        if ok and type(values) == "table" then return values end
    end
    local out = {}
    for i = 1, #M.DETAILS do out[i] = 0 end
    return out
end

function M.detailAt(text, index)
    local values = M.detailValues(text)
    return values[tonumber(index) or 0] or 0
end

function M.detailSet(text, index, value)
    local details = moduleOf("VSMDetails")
    if details == nil then return text end
    local values = M.detailValues(text)
    local i = math.floor(tonumber(index) or 0)
    if i < 1 or i > #values then return text end
    values[i] = math.max(-100, math.min(100, math.floor((tonumber(value) or 0) + 0.5)))
    return details.encode(values)
end

function M.cleanProfile(value)
    if type(value) ~= "table" then return nil end
    local details = moduleOf("VSMDetails")
    if details == nil then return nil end
    local hlo, hhi = M.heightBounds()
    local slo, shi = M.shapeBounds()
    local mlo, mhi = M.muscleBounds()
    local text = value.details
    if text == nil then
        text = details.ZERO
    elseif type(text) ~= "string" then
        return nil
    end
    if #text > 400 then return nil end
    local cleaned = details.normalize(text)
    if type(cleaned) ~= "string" then return nil end
    local model = "original"
    local body = moduleOf("VSMPlayerBody")
    if body ~= nil and type(body.normalize) == "function" then
        local ok, normalized = pcall(body.normalize, value.bodyModel)
        if ok and type(normalized) == "string" then model = normalized end
    end
    return {
        height = clampInt(value.height, hlo, hhi, 175),
        shape = clampInt(value.shape, slo, shi, 0),
        muscle = clampInt(value.muscle, mlo, mhi, 0),
        details = cleaned,
        bodyModel = model,
    }
end

function M.neutralProfile()
    local details = moduleOf("VSMDetails")
    if details == nil then return nil end
    local hlo, hhi = M.heightBounds()
    local slo, shi = M.shapeBounds()
    local mlo, mhi = M.muscleBounds()
    return {
        height = clampInt(175, hlo, hhi, 175),
        shape = clampInt(0, slo, shi, 0),
        muscle = clampInt(0, mlo, mhi, 0),
        details = details.ZERO,
        bodyModel = "original",
    }
end

function M.copyProfile(value)
    local clean = M.cleanProfile(value)
    if clean == nil then return nil end
    return {
        height = clean.height,
        shape = clean.shape,
        muscle = clean.muscle,
        details = clean.details,
        bodyModel = clean.bodyModel,
    }
end

function M.sameProfile(a, b)
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end
    local one, two = M.cleanProfile(a), M.cleanProfile(b)
    if one == nil or two == nil then return false end
    return one.height == two.height and one.shape == two.shape and one.muscle == two.muscle
        and one.details == two.details and one.bodyModel == two.bodyModel
end

function M.profileToken(value)
    local clean = M.cleanProfile(value)
    if clean == nil then return nil end
    return string.format("%d|%d|%d|%s|%s", clean.height, clean.shape, clean.muscle, clean.bodyModel, clean.details)
end

function M.profileFromToken(text)
    if type(text) ~= "string" or text == "" or #text > TOKEN_MAX then return nil end
    local height, shape, muscle, model, details = string.match(text, "^(%-?%d+)|(%-?%d+)|(%-?%d+)|([%a_]+)|(.*)$")
    if height == nil then return nil end
    return M.cleanProfile({ height = tonumber(height), shape = tonumber(shape), muscle = tonumber(muscle),
        bodyModel = model, details = details })
end

function M.profileOf(rec)
    if rec == nil then return nil end
    local data = rawget(_G, "BridgeData")
    if type(data) ~= "table" or type(data.appearanceOf) ~= "function" then return nil end
    local ok, app = pcall(data.appearanceOf, rec)
    if not ok or type(app) ~= "table" then return nil end
    return M.cleanProfile(app.vsmBody)
end

function M.bodyModelsAvailable()
    local body = moduleOf("VSMPlayerBody")
    if body == nil or type(body.available) ~= "function" then return false end
    local ok, yes = pcall(body.available)
    return ok and yes == true
end

function M.applyProfilePreview(avatar, profile, gender)
    if avatar == nil then return false end
    local clean = M.cleanProfile(profile)
    if clean == nil then return false end
    avatar.vsmHeightCm = clean.height
    avatar.vsmBodyShape = clean.shape
    avatar.vsmMuscular = clean.muscle
    avatar.vsmDetails = clean.details
    avatar.vsmBodyModel = clean.bodyModel
    avatar.vsmMorphFemale = gender ~= "male"
    return true
end

function M.applyPreview(avatar, rec)
    if avatar == nil then return false end
    local profile = M.profileOf(rec)
    if profile == nil then return false end
    return M.applyProfilePreview(avatar, profile, BridgeData.genderOf(rec))
end

function M.withField(profile, field, value)
    local nextValue = M.copyProfile(profile)
    if nextValue == nil then return nil end
    nextValue[field] = value
    return M.cleanProfile(nextValue)
end

function M.withDetail(profile, index, value)
    local nextValue = M.copyProfile(profile)
    if nextValue == nil then return nil end
    nextValue.details = M.detailSet(nextValue.details, index, value)
    return M.cleanProfile(nextValue)
end

function M.applyProfile(actor, rec)
    if actor == nil then return false end
    if rec == nil then rec = M.recordOf(actor) end
    local profile = M.profileOf(rec)
    if profile == nil then return false end
    local data = nil
    pcall(function() data = actor:getModData() end)
    if type(data) ~= "table" then return false end
    local changed = false
    local writes = {
        [HEIGHT] = profile.height,
        [SHAPE] = profile.shape,
        [MUSCLE] = profile.muscle,
        [DETAILS] = profile.details,
        [MODEL] = profile.bodyModel,
    }
    for key, value in pairs(writes) do
        if data[key] ~= value then
            data[key] = value
            changed = true
        end
    end
    local controls = moduleOf("VSMControls")
    local scaling = nil
    if controls ~= nil and type(controls.snapshot) == "function" then
        local ok, options = pcall(controls.snapshot)
        if ok and type(options) == "table" then scaling = options.ItemsScaleWithHeight == true end
    end
    if scaling ~= nil and data[ITEMS] ~= scaling then
        data[ITEMS] = scaling
        changed = true
    end
    if data[MANAGED] ~= true then
        data[MANAGED] = true
        changed = true
    end
    local clear = { TOKEN, PROF_TOKEN, PROF, ALIFE_ROW }
    for i = 1, #clear do
        if data[clear[i]] ~= nil then
            data[clear[i]] = nil
            changed = true
        end
    end
    if changed then
        pcall(function() actor:resetModelNextFrame() end)
    end
    return changed
end

function M.neutralize(z, rec)
    if z == nil or not M.active() then return false end
    if rec == nil then rec = M.recordOf(z) end
    local profile = M.profileOf(rec)
    if profile ~= nil then
        local changed = M.applyProfile(z, rec)
        if not neutralised[z] then
            neutralised[z] = true
            say(string.format("companion profile applied: height=%d shape=%d muscle=%d",
                profile.height, profile.shape, profile.muscle))
        end
        return changed
    end
    local data = nil
    pcall(function() data = z:getModData() end)
    if type(data) ~= "table" then return false end
    local changed = false
    if data[HEIGHT] ~= nil then
        data[HEIGHT] = nil
        changed = true
    end
    if data[SHAPE] ~= nil then
        data[SHAPE] = nil
        changed = true
    end
    if data[DETAILS] ~= nil then
        data[DETAILS] = nil
        changed = true
    end
    if data[MODEL] ~= nil then
        data[MODEL] = nil
        changed = true
    end
    if data[TOKEN] ~= nil then
        data[TOKEN] = nil
        changed = true
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

local function companionProfile(first)
    if not M.isCompanion(first) then return false, nil end
    local rec = M.recordOf(first)
    local profile = M.profileOf(rec)
    if profile ~= nil then
        M.applyProfile(first, rec)
        return true, profile
    end
    return true, nil
end

local function wrapHeight(original)
    return function(first, ...)
        local companion, profile = companionProfile(first)
        if companion then
            if profile ~= nil then return profile.height end
            return nil
        end
        return original(first, ...)
    end
end

local function wrapMorph(original)
    return function(first, ...)
        local companion = companionProfile(first)
        if companion then return nil end
        return original(first, ...)
    end
end

local function wrapALife(original)
    return function(first, ...)
        local companion = companionProfile(first)
        if companion then return nil end
        return original(first, ...)
    end
end

local function hook(tbl, name, wrapper, label)
    if type(tbl) ~= "table" then return "absent" end
    if type(tbl[name]) ~= "function" then return "missing" end
    if tbl[name] == M.wrapped[label] then return "ok" end
    local original = tbl[name]
    local wrapped = wrapper(original)
    tbl[name] = wrapped
    M.wrapped[label] = wrapped
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
    if hook(policy, "assignZombie", wrapHeight, "policy") == "ok" then count = count + 1 end
    if hook(morph, "assignZombie", wrapMorph, "morph") == "ok" then count = count + 1 end
    if hook(life, "assign", wrapALife, "life") == "ok" then count = count + 1 end

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
            say("active: companion sizing managed")
        end
    end
    return result
end

function M.reset()
    neutralised = setmetatable({}, { __mode = "k" })
    M.resolved = {}
end

function M.selftest()
    if not M.available() then return "sizeselftest SKIP (Size Matters absent)" end
    local fails, checks = {}, 0
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end
    local details = moduleOf("VSMDetails")
    local hlo, hhi = M.heightBounds()
    local slo, shi = M.shapeBounds()
    local mlo, mhi = M.muscleBounds()
    check("cleanProfile nil", M.cleanProfile(nil) == nil)
    check("cleanProfile string", M.cleanProfile("x") == nil)
    local low = M.cleanProfile({ height = -50, shape = -500, muscle = 500, details = "junk", bodyModel = "junk" })
    check("height low", low ~= nil and low.height == hlo)
    check("shape low", low ~= nil and low.shape == slo)
    check("muscle high", low ~= nil and low.muscle == mhi)
    check("details junk", low ~= nil and low.details == details.ZERO)
    check("model junk", low ~= nil and low.bodyModel == "original")
    local high = M.cleanProfile({ height = hhi + 999, details = details.ZERO })
    check("height high", high ~= nil and high.height == hhi)
    local token = M.profileToken(low)
    check("token roundtrip", type(token) == "string" and M.sameProfile(M.profileFromToken(token), low))
    check("token junk", M.profileFromToken("a|b") == nil)
    local neutral = M.neutralProfile()
    check("neutral baseline", neutral ~= nil and neutral.height == math.max(hlo, math.min(hhi, 175))
        and neutral.details == details.ZERO)
    check("same copy", M.sameProfile(neutral, M.copyProfile(neutral)))
    local other = M.copyProfile(neutral)
    other.details = M.detailSet(neutral.details, 1, 5)
    check("same differs", not M.sameProfile(neutral, other))
    local data, resets = {}, 0
    local actor = {
        getModData = function() return data end,
        resetModelNextFrame = function() resets = resets + 1 end,
    }
    local rec = { vsmBody = M.copyProfile(neutral) }
    check("profileOf", M.profileOf(rec) ~= nil and M.profileOf(nil) == nil)
    check("apply", M.applyProfile(actor, rec) == true and data[HEIGHT] == neutral.height
        and data[MANAGED] == true and resets == 1)
    check("apply stable", M.applyProfile(actor, rec) == false and resets == 1)
    data[TOKEN] = "stale"
    check("clear token", M.applyProfile(actor, rec) == true and data[TOKEN] == nil)
    if #fails == 0 then return string.format("sizeselftest PASS (%d checks)", checks) end
    return string.format("sizeselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
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
