
BridgeALifeCompat = BridgeALifeCompat or {}
local M = BridgeALifeCompat

M.wrapped = {}
M.installed = 0
M.missing = {}
M.externalPresent = false
M.checks = {}
M.ticks = 0

local filteredSnaps = setmetatable({}, { __mode = "k" })
local rescued = setmetatable({}, { __mode = "k" })
local RESCUE_FIELDS = { "ALifeContactSinceMs", "ALifeContactUID", "ALifeNextBitePoseAtMs",
    "ALifeStunUntilMs", "ProjectALifeNextBiteAtMs", "ProjectALifeBiterKey" }
local summary = nil

local function say(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeALifeCompat] " .. tostring(text)) end
end

function M.active(id)
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(id) or mods:contains("\\" .. id))
    end)
    return on
end

local function companion()
    local module = rawget(_G, "BridgeCompanion")
    return type(module) == "table" and module or nil
end

local function isBody(z)
    local module = companion()
    if module == nil or z == nil then return false end
    local ok, yes = pcall(module.isBody, z)
    return ok and yes == true
end

local function maskUid()
    local module = companion()
    return module ~= nil and module.MASK_UID or "SWM:companion"
end

local function uidOfBody(z)
    local uid = nil
    local mask = maskUid()
    pcall(function()
        local data = z:getModData()
        if type(data) == "table" and type(data.ProjectALifeUID) == "string"
                and data.ProjectALifeUID ~= mask then uid = data.ProjectALifeUID end
    end)
    if uid == nil then
        pcall(function()
            local value = z:GetVariable("ALifeUID")
            if value ~= nil and tostring(value) ~= "" then uid = tostring(value) end
        end)
    end
    return uid
end

local function recordOf(uid)
    local mod = rawget(_G, "ProjectALife")
    local registry = type(mod) == "table" and mod.ActorRegistry or nil
    if registry == nil then return nil end
    local read = registry.peek or registry.read
    if type(read) ~= "function" then return nil end
    local ok, record = pcall(read, uid)
    return ok and type(record) == "table" and record or nil
end

local function playerKeyOf(player)
    local jimmy = rawget(_G, "ProjectALifeJimmy")
    if type(jimmy) == "table" and type(jimmy.playerKey) == "function" then
        local ok, key = pcall(jimmy.playerKey, player)
        if ok and key ~= nil then return key end
    end
    local mod = rawget(_G, "ProjectALife")
    local reputation = type(mod) == "table" and mod.Reputation or nil
    if reputation ~= nil and type(reputation.playerKey) == "function" then
        local ok, key = pcall(reputation.playerKey, player)
        if ok then return key end
    end
    return nil
end

local function alifePeaceful(z, who)
    local uid = uidOfBody(z)
    if uid == nil then return nil end
    local actor = recordOf(uid)
    if actor == nil then return true end
    if actor.lifecycle == "dead" then return nil end
    local memory = type(actor.memory) == "table" and actor.memory or {}
    local player = who
    if player == nil then
        local data = rawget(_G, "BridgeData")
        player = type(data) == "table" and type(data.owner) == "function" and data.owner() or nil
    end
    local key = player ~= nil and playerKeyOf(player) or nil
    if key ~= nil and memory.combatTargetKind == "player" and memory.combatTargetPlayerKey == key
            and actor.activity == "combat" then
        return false
    end
    local order = memory.jimmyOrder
    if type(order) == "table" and (order.kind == "follow" or order.kind == "hold" or order.source == "surrender") then
        return true
    end
    if type(memory.jimmyResident) == "table" then return true end
    if type(memory.assPost) == "table" then return true end
    local studio = rawget(_G, "ALifeSurvivorStudio")
    if type(studio) == "table" and type(studio.commandable) == "function" and player ~= nil then
        local ok, yes = pcall(studio.commandable, actor, player)
        if ok and yes == true then return true end
    end
    local mod = rawget(_G, "ProjectALife")
    local relations = type(mod) == "table" and mod.Relations or nil
    if relations == nil or player == nil then return true end
    local stance = nil
    if type(relations.playerStance) == "function" then
        local ok, value = pcall(relations.playerStance, actor, player)
        if ok then stance = value end
    end
    local hostile = false
    if type(relations.hostileToPlayer) == "function" then
        local ok, value = pcall(relations.hostileToPlayer, actor, player)
        hostile = ok and value == true
    end
    if stance ~= nil and stance ~= "hostile" then return true end
    return not hostile
end

function M.peaceful(z, player)
    local ok, answer = pcall(alifePeaceful, z, player)
    if ok then return answer end
    return nil
end

function M.rescue(body)
    if body == nil or rescued[body] then return false end
    rescued[body] = true
    local changed = false
    local alife = rawget(_G, "ProjectALife")
    local horde = type(alife) == "table" and alife.HordeRelations or nil
    if type(horde) == "table" then
        for _, name in ipairs({ "cancelBite", "stopAggro", "release", "endChase",
                "dropSprint", "dropLunge" }) do
            local call = horde[name]
            if type(call) == "function" then
                local ok, acted = pcall(call, body)
                if ok and acted == true then changed = true end
            end
        end
    end
    local data = nil
    pcall(function() data = body:getModData() end)
    if type(data) == "table" then
        for index = 1, #RESCUE_FIELDS do
            if data[RESCUE_FIELDS[index]] ~= nil then
                data[RESCUE_FIELDS[index]] = nil
                changed = true
            end
        end
    end
    pcall(function()
        if type(body.getVariableBoolean) ~= "function" then return end
        if body:getVariableBoolean("ALifeHordeChase") == true then
            body:setVariable("ALifeHordeChase", false)
            changed = true
        end
        if body:getVariableBoolean("ALifeHordeLunge") == true then
            body:setVariable("ALifeHordeLunge", false)
            changed = true
        end
    end)
    pcall(function()
        if type(horde) ~= "table" or type(horde.isBiteName) ~= "function" then return end
        if not horde.isBiteName(body:getBumpType()) then return end
        body:setBumpType("")
        body:setBumpDone(true)
        body:setVariable("BumpDone", true)
        body:setVariable("BumpAnimFinished", true)
        body:setVariable("AttackType", "")
        body:setVariable("AttackOutcome", "")
        changed = true
    end)
    pcall(function()
        if body:getEatBodyTarget() ~= nil then
            body:setBodyToEat(nil)
            changed = true
        end
    end)
    if changed then
        M.rescues = (M.rescues or 0) + 1
        say("rescued companion from leftover A-Life state")
    end
    return changed
end

local function installOne(tbl, name, label, make)
    if type(tbl) ~= "table" then return "absent" end
    if type(tbl[name]) ~= "function" then return "missing" end
    if tbl[name] ~= M.wrapped[label] then
        local wrapper = make(tbl[name])
        tbl[name] = wrapper
        M.wrapped[label] = wrapper
    end
    M.checks[#M.checks + 1] = { label = label, tbl = tbl, name = name }
    return "ok"
end

local function maskedOne(tbl, name, label)
    local module = companion()
    if module == nil then return "absent" end
    return installOne(tbl, name, label, function(original)
        return function(...) return module.masked(original, ...) end
    end)
end

local function firstBodyOne(tbl, name, label, verdict, why)
    return installOne(tbl, name, label, function(original)
        return function(first, ...)
            if isBody(first) then return verdict, why end
            return original(first, ...)
        end
    end)
end

local function secondBodyOne(tbl, name, label, verdict, why)
    return installOne(tbl, name, label, function(original)
        return function(first, second, ...)
            if isBody(second) then return verdict, why end
            return original(first, second, ...)
        end
    end)
end

function M.install()
    M.checks = {}
    local okCount, missingLabels = 0, {}

    local function note(result, label)
        if result == "ok" then
            okCount = okCount + 1
        elseif result == "missing" then
            missingLabels[#missingLabels + 1] = label
        end
    end

    local function hook(tbl, name, label, make)
        local result = installOne(tbl, name, label, make)
        note(result, label)
        return result
    end

    local function hookMasked(tbl, name, label)
        local result = maskedOne(tbl, name, label)
        note(result, label)
        return result
    end

    local function hookFirst(tbl, name, label, verdict, why)
        local result = firstBodyOne(tbl, name, label, verdict, why)
        note(result, label)
        return result
    end

    local function hookSecond(tbl, name, label, verdict, why)
        local result = secondBodyOne(tbl, name, label, verdict, why)
        note(result, label)
        return result
    end

    local external = type(rawget(_G, "ALifeStayWithMeCompat")) == "table"
    M.externalPresent = external

    local alife = rawget(_G, "ProjectALife")
    local jimmy = rawget(_G, "ProjectALifeJimmy")

    if type(alife) == "table" then
        hookFirst(alife.OrphanGuard, "markedWith", "alife.orphan", true)
        hookFirst(alife.TargetPolicy, "canAttack", "alife.target", false, "bridge_companion")
        hook(alife.Combat, "strikeZombie", "alife.strike", function(original)
            return function(shell, zombie, ...)
                if isBody(zombie) then return false end
                return original(shell, zombie, ...)
            end
        end)
        hookFirst(alife.ModuleWithdraw, "ours", "alife.withdraw", true)
    end

    if not external then
        if type(alife) == "table" then
            hook(alife.Perception, "snapshotFor", "alife.snapshot", function(original)
                return function(...)
                    local snap = original(...)
                    if type(snap) == "table" and type(snap.bodies) == "table" and not filteredSnaps[snap] then
                        filteredSnaps[snap] = true
                        local module = companion()
                        if module ~= nil then
                            module.bodies()
                            for index = #snap.bodies, 1, -1 do
                                local row = snap.bodies[index]
                                if type(row) == "table" and isBody(row.body) then
                                    table.remove(snap.bodies, index)
                                end
                            end
                        end
                    end
                    return snap
                end
            end)
            hookMasked(alife.Discretion, "countZombies", "alife.discretion")
            hookFirst(alife.AIFence, "lower", "alife.fence", false)
        end

        if type(jimmy) == "table" then
            hookMasked(jimmy.Discretion, "countZombies", "jeem.discretion.count")
            hookMasked(jimmy.Discretion, "threatOn", "jeem.discretion.threat")
            hookMasked(jimmy.Injuries, "zombiesAround", "jeem.injuries")
            hookMasked(jimmy.Intimidation, "zombieNear", "jeem.intimidation")
            hookMasked(jimmy.AlifeFixes, "noteBaseZombies", "jeem.basezombies")
            hookFirst(jimmy.AlifeFixes, "undressed", "jeem.undressed", false)
            hook(jimmy.RestNearNpcs, "blocker", "jeem.rest", function(original)
                return function(zombie, ...)
                    local module = companion()
                    if module ~= nil then module.bodies() end
                    if isBody(zombie) then return nil end
                    return original(zombie, ...)
                end
            end)
        end

        local data = rawget(_G, "BridgeData")
        hook(data, "foreignPeaceful", "bridge.peaceful", function(original)
            return function(z, ...)
                local ok, answer = pcall(alifePeaceful, z)
                if ok and answer ~= nil then return answer end
                return original(z, ...)
            end
        end)
    end

    if type(jimmy) == "table" then
        local residents = jimmy.Residents
        local sweep = type(residents) == "table" and residents.sweep or nil
        hook(sweep, "liveZombies", "jeem.sweep", function(original)
            return function(...)
                local list = original(...)
                if type(list) ~= "table" then return list end
                local out = {}
                for index = 1, #list do
                    local entry = list[index]
                    if entry == nil or not isBody(entry.obj) then out[#out + 1] = entry end
                end
                return out
            end
        end)
    end

    if type(alife) == "table" then
        hookSecond(alife.Perception, "comrade", "alife.comrade", true)
        hookSecond(alife.Perception, "contactReachable", "alife.contact", false)
        hook(alife.Perception, "lastKnownFor", "alife.lastknown", function(original)
            return function(actor, ...)
                local entry = original(actor, ...)
                if type(entry) == "table" and isBody(entry.target) then
                    local known = actor ~= nil and alife.Perception.lastKnown or nil
                    if type(known) == "table" then known[actor.uid] = nil end
                    return nil
                end
                return entry
            end
        end)
    end

    if type(alife) == "table" then
        local horde = alife.HordeRelations
        hookFirst(horde, "steersHere", "alife.horde.steers", false)
        hook(horde, "preyRows", "alife.horde.prey", function(original)
            return function(...)
                local rows = original(...)
                if type(rows) ~= "table" then return rows end
                for index = #rows, 1, -1 do
                    local row = rows[index]
                    if type(row) == "table" and isBody(row.body) then table.remove(rows, index) end
                end
                return rows
            end
        end)
        if not M.externalPresent then
            hookFirst(horde, "wake", "alife.horde.wake", nil)
            hookFirst(horde, "settle", "alife.horde.settle", false)
            hookFirst(horde, "settleFree", "alife.horde.settlefree", false)
            hookFirst(horde, "applyHold", "alife.horde.hold", false)
            hook(horde, "startBite", "alife.horde.startbite", function(original)
                return function(zombie, actor, ...)
                    if isBody(zombie) or isBody(actor) then return false end
                    return original(zombie, actor, ...)
                end
            end)
        end
        hook(horde, "applyBiteDamage", "alife.horde.bite", function(original)
            return function(actor, zombie, ...)
                if isBody(actor) or isBody(zombie) then return false, "bridge_companion" end
                return original(actor, zombie, ...)
            end
        end)
    end

    table.sort(missingLabels)
    M.installed = okCount
    M.missing = missingLabels
    local module = companion()
    if module ~= nil then
        local list = module.bodies()
        for index = 1, #list do pcall(M.rescue, list[index]) end
    end
    local text = okCount .. " hook(s), " .. #missingLabels .. " missing"
    if text ~= summary then
        summary = text
        say(text .. (#missingLabels > 0 and (" (" .. table.concat(missingLabels, ", ") .. ")") or ""))
    end
    return okCount
end

function M.status()
    local module = companion()
    local bridge = rawget(_G, "Bridge")
    local body = type(bridge) == "table" and bridge.body or nil
    if body == nil and module ~= nil then
        local list = module.bodies()
        body = list[1]
    end
    local mod = rawget(_G, "ProjectALife")
    local horde = type(mod) == "table" and mod.HordeRelations or nil
    local hordePrey = false
    if body ~= nil and type(horde) == "table" and type(horde.markedOurs) == "function" then
        local ok, marked = pcall(horde.markedOurs, body)
        hordePrey = ok and marked == true
    end
    local steers = nil
    if body ~= nil and type(horde) == "table" and type(horde.steersHere) == "function" then
        local ok, value = pcall(horde.steersHere, body)
        if ok then steers = value end
    end
    local missing = M.missing or {}
    return string.format("compat: %s; hooks %d installed, %d missing%s; externalPresent=%s; hordePrey=%s; steersHere=%s; rescues=%d",
        module ~= nil and module.status() or "BridgeCompanion missing",
        M.installed or 0, #missing,
        #missing > 0 and (" [" .. table.concat(missing, ", ") .. "]") or "",
        tostring(M.externalPresent), tostring(hordePrey), tostring(steers), M.rescues or 0)
end

function M.selftest()
    local fails, ran = {}, 0
    local function check(name, condition)
        ran = ran + 1
        if not condition then fails[#fails + 1] = name end
    end

    local module = companion()
    check("BridgeCompanion loaded", module ~= nil)
    if module == nil then return string.format("compat selftest FAIL (1 of 1): %s", table.concat(fails, "; ")) end

    local bridge = rawget(_G, "Bridge")
    local body = type(bridge) == "table" and bridge.body or nil
    if body ~= nil then
        check("isBody(Bridge.body)", module.isBody(body) == true)
        local data = nil
        pcall(function() data = body:getModData() end)
        if type(data) == "table" then
            local before = data.ProjectALifeUID

            data.ProjectALifeUID = nil
            module.masked(function()
                check("mask sets", data.ProjectALifeUID == module.MASK_UID)
            end)
            check("mask restores", data.ProjectALifeUID == nil)

            data.ProjectALifeUID = "existing-uid"
            module.masked(function()
                check("mask over existing", data.ProjectALifeUID == module.MASK_UID)
            end)
            check("existing uid preserved", data.ProjectALifeUID == "existing-uid")

            module.masked(function()
                module.masked(function()
                    check("nested mask sets", data.ProjectALifeUID == module.MASK_UID)
                end)
                check("nested mask restores", data.ProjectALifeUID == module.MASK_UID)
            end)
            check("outer mask restores", data.ProjectALifeUID == "existing-uid")

            data.ProjectALifeUID = before
        else
            check("body mod data readable", false)
        end

        local mod = rawget(_G, "ProjectALife")
        local horde = type(mod) == "table" and mod.HordeRelations or nil
        if type(horde) == "table" and type(horde.markedOurs) == "function" then
            local ok, marked = pcall(horde.markedOurs, body)
            check("markedOurs is false", ok and marked ~= true)
        end
        if type(horde) == "table" and type(horde.steersHere) == "function" then
            local ok, value = pcall(horde.steersHere, body)
            check("steersHere is false", ok and value == false)
        end
    end

    for _, entry in ipairs(M.checks or {}) do
        check("hook " .. entry.label, entry.tbl[entry.name] == M.wrapped[entry.label])
    end

    if body ~= nil then check("rescue ran", rescued[body] == true) end

    if #fails == 0 then return string.format("compat selftest PASS (%d checks)", ran) end
    return string.format("compat selftest FAIL (%d of %d): %s", #fails, ran, table.concat(fails, "; "))
end

local function tick()
    M.ticks = (M.ticks or 0) + 1
    if M.ticks % 600 ~= 1 then return end
    pcall(M.install)
end

if type(Events) == "table" then
    if Events.OnGameStart ~= nil then Events.OnGameStart.Add(function()
        rescued = setmetatable({}, { __mode = "k" })
        pcall(M.install)
    end) end
    if Events.OnServerStarted ~= nil then Events.OnServerStarted.Add(function() pcall(M.install) end) end
    if Events.OnTick ~= nil then Events.OnTick.Add(tick) end
end

return M