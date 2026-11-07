BridgeWoundExpCompat = BridgeWoundExpCompat or {}

local M = BridgeWoundExpCompat

M.ALLOWED = { rinse = true, debride = true, maggots = true }
M.WATER_UNITS = 0.2

local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeWoundExpCompat] " .. tostring(text))
    end
end

local ACTIVE = nil

function M.active()
    if ACTIVE == true then return true end
    if getActivatedMods == nil then return false end
    local ok, has = pcall(function()
        local mods = getActivatedMods()
        if mods == nil then return false end
        return mods:contains("WoundExpansion") == true
    end)
    if not ok or has ~= true then return false end
    local WE = rawget(_G, "WoundExpansion")
    if type(WE) ~= "table" then return false end
    if type(WE.Core) ~= "table" then return false end
    if type(WE.Wounds) ~= "table" then return false end
    if type(WE.Conditions) ~= "table" then return false end
    if type(WE.WOUND) ~= "table" then return false end
    if type(WE.CONDITION) ~= "table" then return false end
    if type(WE.Config) == "table" and WE.Config.ENABLED == false then return false end
    ACTIVE = true
    return true
end

local function rootOf(character)
    if character == nil then return nil end
    local md = nil
    pcall(function() md = character:getModData() end)
    if type(md) ~= "table" then return nil end
    local root = md.WoundExp
    if type(root) ~= "table" then return nil end
    if root.version ~= 1 then return nil end
    if type(root.parts) ~= "table" then return nil end
    return root
end

local function copyData(data)
    if type(data) ~= "table" then return {} end
    local out = {}
    for k, v in pairs(data) do out[k] = v end
    return out
end

local function doctorLevel()
    local lvl = 0
    if type(BridgeSkills) == "table" and type(BridgeSkills.level) == "function" then
        pcall(function() lvl = BridgeSkills.level("Doctor") end)
    end
    lvl = tonumber(lvl) or 0
    if lvl < 0 then lvl = 0 end
    if lvl > 10 then lvl = 10 end
    return lvl
end

local function internalBleedVisible()
    local WE = rawget(_G, "WoundExpansion")
    if type(WE) ~= "table" then return false end
    local def = nil
    pcall(function() def = WE.Conditions[WE.CONDITION.INTERNAL_BLEEDING] end)
    local hidden = 6
    if type(def) == "table" and type(def.hiddenBelowFirstAid) == "number" then
        hidden = def.hiddenBelowFirstAid
    end
    return doctorLevel() >= hidden
end

function M.root(character)
    return rootOf(character)
end

function M.issues(character, index, rootArg)
    if rootArg == false then return nil end
    local root = rootArg
    if root == nil then
        if not M.active() then return nil end
        root = rootOf(character)
    end
    if root == nil then return nil end
    if type(root.parts) ~= "table" then return nil end
    local entry = root.parts[index]
    if type(entry) ~= "table" then return nil end
    local WE = rawget(_G, "WoundExpansion")
    if type(WE) ~= "table" then return nil end
    local C = WE.CONDITION
    if type(C) ~= "table" then return nil end
    local we = nil
    if type(entry.wounds) == "table" then
        for id, data in pairs(entry.wounds) do
            if type(id) == "string" then
                if we == nil then we = { wounds = {}, conditions = {}, any = true, urgent = false } end
                we.wounds[id] = copyData(data)
            end
        end
    end
    if type(entry.conditions) == "table" then
        for id, data in pairs(entry.conditions) do
            if type(id) == "string" then
                local visible = true
                if id == C.INTERNAL_BLEEDING and not internalBleedVisible() then visible = false end
                if visible then
                    if we == nil then we = { wounds = {}, conditions = {}, any = true, urgent = false } end
                    we.conditions[id] = copyData(data)
                end
            end
        end
    end
    if we == nil then return nil end
    if we.conditions[C.MAGGOTS] ~= nil then we.urgent = true end
    if we.conditions[C.INTERNAL_BLEEDING] ~= nil then we.urgent = true end
    if we.conditions[C.NECROTIC] ~= nil then we.urgent = true end
    if we.conditions[C.SEPTIC_FEVER] ~= nil then we.urgent = true end
    return we
end

function M.describe(we)
    if type(we) ~= "table" then return "" end
    local list = {}
    if type(we.wounds) == "table" then
        for id, data in pairs(we.wounds) do
            local name = "w:" .. tostring(id)
            if id == "Frostbite" and type(data) == "table" and data.stage ~= nil then
                name = name .. tostring(data.stage)
            end
            list[#list + 1] = name
        end
    end
    if type(we.conditions) == "table" then
        for id in pairs(we.conditions) do list[#list + 1] = "c:" .. tostring(id) end
    end
    table.sort(list)
    return table.concat(list, "+")
end

local DETECT_WOUNDS = { "DISLOCATION", "CONCUSSION", "JOINT_DAMAGE", "NERVE_DAMAGE" }
local DETECT_CONDITIONS = { "INTERNAL_BLEEDING", "NECROTIC", "SEPTIC_FEVER", "POORLY_STITCHED", "TOURNIQUET", "OVER_BANDAGED" }

function M.detectOnly(we)
    local out = {}
    if type(we) ~= "table" then return out end
    local WE = rawget(_G, "WoundExpansion")
    if type(WE) ~= "table" then return out end
    local W = WE.WOUND or {}
    local C = WE.CONDITION or {}
    for _, key in ipairs(DETECT_WOUNDS) do
        local id = W[key]
        if id ~= nil and type(we.wounds) == "table" and we.wounds[id] ~= nil then out[#out + 1] = id end
    end
    for _, key in ipairs(DETECT_CONDITIONS) do
        local id = C[key]
        if id ~= nil and type(we.conditions) == "table" and we.conditions[id] ~= nil then out[#out + 1] = id end
    end
    return out
end

local function partOf(character, index)
    if type(BridgeCare) == "table" and type(BridgeCare.part) == "function" then
        return BridgeCare.part(character, index)
    end
    return nil
end

function M.plan(character, body, red, index, issue, lvl, has)
    if not M.active() then return {} end
    if type(issue) ~= "table" then return {} end
    local WE = rawget(_G, "WoundExpansion")
    if type(WE) ~= "table" then return {} end
    local W = WE.WOUND or {}
    local C = WE.CONDITION or {}
    local part = partOf(character, index)
    local bandaged, splint, fracture = false, false, false
    if part ~= nil then
        pcall(function() bandaged = part:bandaged() == true end)
        pcall(function() splint = part:getSplintFactor() > 0 end)
        pcall(function() fracture = part:getFractureTime() > 0 end)
    end
    has = type(has) == "table" and has or {}
    local conditions = type(issue.conditions) == "table" and issue.conditions or {}
    local wounds = type(issue.wounds) == "table" and issue.wounds or {}
    local out = {}
    local function add(op, extra)
        local step = { op = op }
        if type(extra) == "table" then
            for k, v in pairs(extra) do step[k] = v end
        end
        out[#out + 1] = step
    end
    if not bandaged then
        if conditions[C.DIRTY] ~= nil or (conditions[C.RINSED] ~= nil and has.soap == true) then
            add("rinse", { soap = has.soap == true })
        end
    end
    if not bandaged and has.debris == true and conditions[C.EMBEDDED_DEBRIS] ~= nil then
        local data = conditions[C.EMBEDDED_DEBRIS]
        if type(data) ~= "table" or data.source ~= "vanilla" then add("debride") end
    end
    if not bandaged and has.maggots == true and conditions[C.MAGGOTS] ~= nil then add("maggots") end
    if wounds[W.SPRAIN] ~= nil and not splint and not fracture then add("sprain") end
    if bandaged and conditions[C.TORN_BANDAGE] ~= nil then add("rebandage") end
    if not bandaged and has.vanillaBandage ~= true
        and (wounds[W.ABRASION] ~= nil or wounds[W.PUNCTURE] ~= nil) then
        add("dress")
    end
    return out
end

function M.apply(character, change)
    if not M.active() then return false, "no WoundExpansion" end
    if type(change) ~= "table" then return false, "no change" end
    local op = change.op
    if M.ALLOWED[op] ~= true then return false, "bad op" end
    local WE = rawget(_G, "WoundExpansion")
    if type(WE) ~= "table" then return false, "no WoundExpansion" end
    local Core = WE.Core
    if type(Core) ~= "table" then return false, "no WE.Core" end
    local maxPart = 17
    if type(BridgeCare) == "table" and type(BridgeCare.PARTS) == "number" then maxPart = BridgeCare.PARTS end
    local index = math.floor(tonumber(change.part) or -1)
    if index < 0 or index >= maxPart then return false, "bad part" end
    local part = partOf(character, index)
    if part == nil then return false, "no part" end
    local C = WE.CONDITION
    if op == "rinse" then
        local changed = false
        pcall(function() changed = WE.washDirt(character, index, change.soap == true) == true end)
        if not changed then return false, "no dirt" end
        return true, nil
    end
    if op == "debride" then
        local removed = false
        pcall(function() removed = Core.removeCondition(character, index, C.EMBEDDED_DEBRIS) == true end)
        if not removed then return false, "no debris" end
        pcall(function() part:setHaveGlass(false) end)
        local bullet = false
        pcall(function() bullet = part:haveBullet() == true end)
        if bullet then
            local lvl = math.floor(tonumber(change.level) or 0)
            if lvl < 0 then lvl = 0 end
            if lvl > 10 then lvl = 10 end
            pcall(function() part:setHaveBullet(false, lvl) end)
        end
        return true, nil
    end
    if op == "maggots" then
        local removed = false
        pcall(function() removed = Core.removeCondition(character, index, C.MAGGOTS) == true end)
        if not removed then return false, "no maggots" end
        return true, nil
    end
    return false, "bad op"
end

function M.filterDisinfectant(item)
    if item == nil then return false end
    local full = nil
    pcall(function() full = item:getFullType() end)
    if full == nil then
        pcall(function() full = item:getModule() .. "." .. item:getType() end)
    end
    return full == "WoundExpansion.WE_Iodine"
end

function M.spendWater(item)
    if item == nil then return false end
    local WE = rawget(_G, "WoundExpansion")
    if type(WE) == "table" and type(WE.spendWater) == "function" then
        local ok, spent = pcall(WE.spendWater, item)
        if ok and spent == true then return true end
    end
    local done = false
    pcall(function()
        if ComponentType ~= nil and item:hasComponent(ComponentType.FluidContainer) then
            local fc = item:getFluidContainer()
            if fc ~= nil then
                local left = fc:getAmount() - M.WATER_UNITS
                if left < 0 then left = 0 end
                fc:adjustAmount(left)
                if type(sendItemStats) == "function" then sendItemStats(item) end
                done = true
            end
        elseif item:IsDrainable() then
            if type(item.UseAndSync) == "function" then item:UseAndSync() else item:Use() end
            done = true
        end
    end)
    return done
end

function M.push(character)
    local WE = rawget(_G, "WoundExpansion")
    if type(WE) ~= "table" then return end
    if type(WE.Net) ~= "table" then return end
    if type(WE.Net.push) ~= "function" then return end
    pcall(WE.Net.push, character)
end

function M.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local savedWE = rawget(_G, "WoundExpansion")
    local savedSkills = rawget(_G, "BridgeSkills")
    local savedCare = rawget(_G, "BridgeCare")
    local savedMods = rawget(_G, "getActivatedMods")
    local savedActive = ACTIVE

    local removed = {}
    local Core = {
        removeCondition = function(character, index, cond)
            removed[#removed + 1] = cond
            return true
        end,
    }
    local config = {
        DIRTY = "Dirty", RINSED = "Rinsed", EMBEDDED_DEBRIS = "EmbeddedDebris", MAGGOTS = "Maggots",
        INTERNAL_BLEEDING = "InternalBleeding", NECROTIC = "Necrotic", SEPTIC_FEVER = "SepticFever",
        POORLY_STITCHED = "PoorlyStitched", TOURNIQUET = "Tourniquet", OVER_BANDAGED = "OverBandaged",
        TORN_BANDAGE = "TornBandage",
    }
    local wound = {
        SPRAIN = "Sprain", ABRASION = "Abrasion", PUNCTURE = "Puncture",
        DISLOCATION = "Dislocation", CONCUSSION = "Concussion", JOINT_DAMAGE = "JointDamage", NERVE_DAMAGE = "NerveDamage",
    }
    rawset(_G, "WoundExpansion", {
        Core = Core,
        WOUND = wound,
        CONDITION = config,
        Wounds = { Sprain = {}, Abrasion = {}, Puncture = {} },
        Conditions = { [config.INTERNAL_BLEEDING] = { hiddenBelowFirstAid = 6 } },
        washDirt = function() return true end,
        Net = { push = function() end },
    })
    rawset(_G, "BridgeSkills", { level = function() return 0 end })
    rawset(_G, "getActivatedMods", function()
        return { contains = function(_, name) return name == "WoundExpansion" end }
    end)
    ACTIVE = nil

    local function part(bandaged, splint, fracture)
        return {
            bandaged = function() return bandaged end,
            getSplintFactor = function() return splint and 1 or 0 end,
            getFractureTime = function() return fracture and 10 or 0 end,
            setHaveGlass = function() end,
            haveBullet = function() return false end,
            setHaveBullet = function() end,
        }
    end
    local currentPart = part(false, false, false)
    rawset(_G, "BridgeCare", { PARTS = 17, part = function() return currentPart end })

    local function character()
        local md = { WoundExp = { version = 1, parts = {} } }
        md.WoundExp.parts[3] = {
            wounds = { [wound.SPRAIN] = {}, [wound.ABRASION] = {} },
            conditions = { [config.DIRTY] = {}, [config.TORN_BANDAGE] = {}, [config.MAGGOTS] = {} },
            timers = {},
        }
        return { getModData = function() return md end }
    end

    check("active", M.active() == true)
    local we = M.issues(character(), 3)
    check("issues any", we ~= nil and we.any == true)
    check("issues urgent", we ~= nil and we.urgent == true)
    check("describe stable", M.describe(we):find("w:Sprain") ~= nil and M.describe(we):find("c:Dirty") ~= nil)
    check("detect-only list", #M.detectOnly(we) == 0)
    local root = M.root(character())
    check("root table", type(root) == "table")
    local viaRoot = M.issues(character(), 3, root)
    check("issues root", viaRoot ~= nil and viaRoot.any == true)
    check("issues clean part", M.issues(character(), 1) == nil)

    local plan = M.plan(character(), nil, nil, 3, we, 0, {
        water = true, soap = true, debris = true, maggots = true, splint = true, bandage = true,
    })
    local ops = {}
    for _, step in ipairs(plan) do ops[step.op] = true end
    check("plan rinse", ops.rinse == true)
    check("plan maggots", ops.maggots == true)
    check("plan sprain", ops.sprain == true)

    currentPart = part(true, false, false)
    local bandagedPlan = M.plan(character(), nil, nil, 3, we, 0, { bandage = true })
    local rebandage = false
    for _, step in ipairs(bandagedPlan) do if step.op == "rebandage" then rebandage = true end end
    check("plan rebandage", rebandage == true)

    currentPart = part(false, false, false)
    local noMaggots = M.issues(character(), 3)
    noMaggots.conditions[config.MAGGOTS] = nil
    local dressPlan = M.plan(character(), nil, nil, 3, noMaggots, 0, {
        water = false, soap = false, debris = false, maggots = false, splint = false, bandage = true,
    })
    local dress = false
    for _, step in ipairs(dressPlan) do if step.op == "dress" then dress = true end end
    check("plan dress", dress == true)

    check("filter iodine", M.filterDisinfectant({ getFullType = function() return "WoundExpansion.WE_Iodine" end }) == true)
    check("filter other", M.filterDisinfectant({ getFullType = function() return "Base.Bandage" end }) == false)

    check("apply rinse", M.apply(character(), { op = "rinse", part = 3 }) == true)
    check("apply debride", M.apply(character(), { op = "debride", part = 3 }) == true)
    check("apply maggots", M.apply(character(), { op = "maggots", part = 3 }) == true)
    check("apply bad op", M.apply(character(), { op = "surgery", part = 3 }) == false)
    check("apply bad part", M.apply(character(), { op = "rinse", part = 99 }) == false)

    ACTIVE = savedActive
    rawset(_G, "WoundExpansion", savedWE)
    rawset(_G, "BridgeSkills", savedSkills)
    rawset(_G, "BridgeCare", savedCare)
    rawset(_G, "getActivatedMods", savedMods)

    if #fails == 0 then return string.format("woundexpselftest PASS (%d checks)", checks) end
    return string.format("woundexpselftest FAIL (%d of %d): %s", checks, #fails, table.concat(fails, "; "))
end

pcall(log, "loaded")
