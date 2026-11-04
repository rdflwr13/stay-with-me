BridgeGunRules = BridgeGunRules or {}

BridgeGunRules.MAX_RANGE = 60
BridgeGunRules.MIN_RANGE = 3
BridgeGunRules.AIM_BONUS = 10
BridgeGunRules.MOVING_FACTOR = 0.85
BridgeGunRules.CLOSE_BONUS = 1.15
BridgeGunRules.FAR_PENALTY = 0.25
BridgeGunRules.MIN_CHANCE = 15
BridgeGunRules.MAX_CHANCE = 95
BridgeGunRules.NPC_DAMAGE_SCALE = 3.0
BridgeGunRules.FRIENDLY_RADIUS = 0.9
BridgeGunRules.MARK = "bridgePrimaryGun"
BridgeGunRules.ATY_CORRIDOR = 2.0
BridgeGunRules.ATY_CORRIDOR_SHOTGUN = 4.6
BridgeGunRules.ATY_DAMAGE_SCALE = 1.0
BridgeGunRules.PLANT_TICKS = 60
BridgeGunRules.TURN_TICKS_MAX = 24
BridgeGunRules.RETARGET_TICKS = 30
BridgeGunRules.MOVE_EPS = 0.02
BridgeGunRules.MOVE_WINDOW = 6

local function num(fn, fallback)
    local value = fallback
    pcall(function()
        local got = fn()
        if type(got) == "number" and got == got then value = got end
    end)
    return value
end

local function text(fn, fallback)
    local value = fallback
    pcall(function()
        local got = fn()
        if type(got) == "string" and got ~= "" then value = got end
    end)
    return value
end

local function flag(fn)
    local value = false
    pcall(function() value = fn() == true end)
    return value
end

local function typeText(fn)
    local value = text(fn, nil)
    if value == nil or value == "null" then return nil end
    return value
end

local function clamp(v, lo, hi)
    if type(v) ~= "number" or v ~= v then v = lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function ammoTypeOf(item)
    local ammo = nil
    pcall(function() ammo = item:getAmmoType() end)
    return ammo
end

local function ammoIdOf(ammo)
    if ammo == nil then return nil end
    local id = nil
    pcall(function() id = tostring(ammo) end)
    if type(id) ~= "string" or id == "" or id == "null" then return nil end
    return id
end

local function ammoKeyOf(item, ammo)
    local key = nil
    pcall(function()
        local found = ammo
        if found == nil then found = item:getAmmoType() end
        if found ~= nil then key = found:getItemKey() end
    end)
    if type(key) ~= "string" or key == "" or key == "null" then return nil end
    return key
end


local warned = {}

local function warnOnce(key, message)
    if type(key) ~= "string" then key = tostring(message) end
    if warned[key] then return end
    warned[key] = true
    print("[BridgeGunRules] " .. tostring(message))
end


local function diag(key, message)
    if Bridge ~= nil and Bridge.verbose then warnOnce(key, message) end
end


local function gunsmith()
    local module = BridgeGunRules.gunsmith
    if module == nil then return nil end
    if module.active ~= nil and module.active() ~= true then return nil end
    return module
end

do
    local GSC = {}
    BridgeGunRules.gunsmith = GSC

    local warned = {}

    local function say(text)
        if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGunRules] " .. tostring(text)) end
    end

    local function warnOnce(key, message)
        if warned[key] == true then return end
        warned[key] = true
        say(message)
    end

    local function api()
        local module = rawget(_G, "Gunsmith")
        return type(module) == "table" and module or nil
    end

    local function isServerNow()
        local yes = false
        pcall(function() yes = isServer() == true end)
        return yes
    end

    local function active()
        if isServerNow() then return false end
        return api() ~= nil
    end

    GSC.active = active

    local function isGunItem(G, item)
        if G == nil or item == nil then return false end
        if type(G.IsGun) ~= "function" then return false end
        local ok, yes = pcall(G.IsGun, item)
        return ok and yes == true
    end

    local function instantiate(fullType)
        if type(fullType) ~= "string" or fullType == "" then return nil end
        local item = nil
        local ok = pcall(function() item = instanceItem(fullType) end)
        if not ok then return nil end
        return item
    end

    local function isPlayer(character)
        if character == nil then return false end
        local yes = false
        pcall(function() yes = instanceof(character, "IsoPlayer") == true end)
        return yes
    end

    local function callWithNpcSafeSync(fn)
        local hand = rawget(_G, "syncHandWeaponFields")
        local mod = rawget(_G, "syncItemModData")
        if type(hand) == "function" then
            rawset(_G, "syncHandWeaponFields", function(character, item)
                if isPlayer(character) then return hand(character, item) end
            end)
        end
        if type(mod) == "function" then
            rawset(_G, "syncItemModData", function(character, item)
                if isPlayer(character) then return mod(character, item) end
            end)
        end
        local ok, err = pcall(fn)
        if type(hand) == "function" then rawset(_G, "syncHandWeaponFields", hand) end
        if type(mod) == "function" then rawset(_G, "syncItemModData", mod) end
        return ok, err
    end

    function GSC.isGun(item)
        if not active() then return false end
        return isGunItem(api(), item)
    end

    function GSC.isInternal(item)
        if not active() then return false end
        local G = api()
        if not isGunItem(G, item) then return false end
        if type(G.IsInternal) ~= "function" then return false end
        local ok, yes = pcall(G.IsInternal, item)
        return ok and yes == true
    end

    function GSC.magazineTypes(itemOrFullType)
        if not active() then return {} end
        local G = api()
        if G == nil then return {} end
        local item = itemOrFullType
        if type(itemOrFullType) == "string" then item = instantiate(itemOrFullType) end
        if not isGunItem(G, item) then return {} end
        if type(G.MagazineTypesFor) ~= "function" then return {} end
        local list = nil
        local ok = pcall(function() list = G.MagazineTypesFor(item) end)
        if not ok then
            warnOnce("magazinetypes", "MagazineTypesFor failed")
            return {}
        end
        local out, seen = {}, {}
        if type(list) == "table" then
            for _, fullType in ipairs(list) do
                if type(fullType) == "string" and fullType ~= "" and seen[fullType] ~= true then
                    seen[fullType] = true
                    out[#out + 1] = fullType
                end
            end
        end
        return out
    end

    function GSC.ammoTypes(desc, owner)
        local out, seen = {}, {}
        if not active() then return out end
        local function add(fullType)
            if type(fullType) ~= "string" or fullType == "" or seen[fullType] == true then return end
            seen[fullType] = true
            out[#out + 1] = fullType
        end
        local G = api()
        if G == nil or type(desc) ~= "table" then return out end
        local item = desc.gunsmithItem
        if not isGunItem(G, item) then item = instantiate(desc.fullType) end
        if not isGunItem(G, item) then return out end
        local cal = nil
        if type(G.CaliberOf) == "function" then
            local ok = false
            ok, cal = pcall(G.CaliberOf, item)
            if not ok then cal = nil end
        end
        if type(cal) ~= "string" or cal == "" then return out end
        if type(G.Calibers) ~= "table" then return out end
        if owner ~= nil and type(G.CarriedAmmo) == "function" then
            local list = nil
            pcall(function() list = G.CarriedAmmo(owner, cal) end)
            if type(list) == "table" then
                for _, entry in ipairs(list) do
                    if type(entry) == "table" then add(entry.type) end
                end
            end
        end
        local caliberDef = type(G.Calibers) == "table" and G.Calibers[cal] or nil
        if type(caliberDef) == "table" and type(caliberDef.ammo) == "table" then
            for _, fullType in ipairs(caliberDef.ammo) do add(fullType) end
        end
        if type(G.DefaultAmmo) == "function" then
            local fullType = nil
            local ok = false
            ok, fullType = pcall(G.DefaultAmmo, cal)
            if ok then add(fullType) end
        end
        if type(G.ItemAmmo) == "function" then
            local fullType = nil
            local ok = false
            ok, fullType = pcall(G.ItemAmmo, item)
            if ok then add(fullType) end
        end
        return out
    end

    function GSC.boxTypes(roundType, gun)
        local out, seen = {}, {}
        if not active() then return out end
        local function add(fullType)
            if type(fullType) ~= "string" or fullType == "" or seen[fullType] == true then return end
            local item = instantiate(fullType)
            if item == nil then return end
            seen[fullType] = true
            out[#out + 1] = fullType
        end
        local G = api()
        if G == nil or type(roundType) ~= "string" then return out end
        if type(G.AmmoDef) ~= "function" then return out end
        local def = nil
        local ok = false
        ok, def = pcall(G.AmmoDef, roundType)
        if not ok or type(def) ~= "table" then return out end
        local suffix = string.match(roundType, "^Gunsmith%.Ammo(.+)$")
        if suffix == nil then return out end
        local boxPrefix = type(G.Box) == "string" and G.Box or "Gunsmith.Box"
        local cartonPrefix = type(G.Carton) == "string" and G.Carton or "Gunsmith.Carton"
        add(boxPrefix .. suffix)
        add(cartonPrefix .. suffix)
        return out
    end

    function GSC.prepareGun(body, item)
        if not active() then return false end
        local G = api()
        if not isGunItem(G, item) then return false end
        local ran = false
        if type(G.EnsureInit) == "function" then
            local ok = pcall(G.EnsureInit, item, body)
            if ok then ran = true else warnOnce("ensureinit", "EnsureInit failed") end
        end
        if type(G.Refresh) == "function" then
            local ok = pcall(G.Refresh, item, body)
            if ok then ran = true else warnOnce("refresh", "Refresh failed") end
        end
        if type(G.SyncRounds) == "function" then
            local ok = pcall(G.SyncRounds, item)
            if ok then ran = true else warnOnce("syncrounds", "SyncRounds failed") end
        end
        return ran
    end

    function GSC.insertMagazine(body, weapon, magazine, desc)
        if not active() then return false end
        local G = api()
        if not isGunItem(G, weapon) or magazine == nil then return false end
        local Action = rawget(_G, "GS_InsertMagAction")
        if type(Action) ~= "table" or type(Action.new) ~= "function" then return false end
        local carrier = nil
        if type(G.CarrierOf) == "function" then
            pcall(function() carrier = G.CarrierOf(body, magazine) end)
        end
        local ok = false
        local err = nil
        ok, err = callWithNpcSafeSync(function()
            local action = Action:new(body, weapon, magazine, carrier)
            action:loadAmmo()
        end)
        local hasClip = false
        pcall(function() hasClip = weapon:isContainsClip() == true end)
        if not ok then
            if hasClip then
                warnOnce("insertmagazine-sync", "insert magazine completed despite a sync error: " .. tostring(err))
                return true
            end
            warnOnce("insertmagazine", "insert magazine failed: " .. tostring(err))
            return false
        end
        return hasClip
    end

    function GSC.ejectMagazine(body, weapon)
        if not active() then return false end
        local G = api()
        if not isGunItem(G, weapon) then return false end
        local Action = rawget(_G, "GS_EjectMagAction")
        if type(Action) ~= "table" or type(Action.new) ~= "function" then return false end
        local hasClip = false
        pcall(function() hasClip = weapon:isContainsClip() == true end)
        if not hasClip then return false end
        local carrier = nil
        if type(G.CarrierOf) == "function" then
            pcall(function() carrier = G.CarrierOf(body, weapon) end)
        end
        local ok = false
        local err = nil
        ok, err = callWithNpcSafeSync(function()
            local action = Action:new(body, weapon, carrier)
            action:unloadAmmo()
        end)
        local stillLoaded = true
        pcall(function() stillLoaded = weapon:isContainsClip() == true end)
        if not ok then
            if not stillLoaded then
                warnOnce("ejectmagazine-sync", "eject magazine completed despite a sync error: " .. tostring(err))
                return true
            end
            warnOnce("ejectmagazine", "eject magazine failed: " .. tostring(err))
            return false
        end
        if stillLoaded then
            warnOnce("ejectmagazine", "eject magazine left the gun loaded")
            return false
        end
        return true
    end

    function GSC.addInternalRound(item, roundType)
        if not active() then return false end
        local G = api()
        if not isGunItem(G, item) then return false end
        if type(roundType) ~= "string" or roundType == "" then return false end
        if type(G.IsInternal) ~= "function" or type(G.TubeRounds) ~= "function" then return false end
        local internal = false
        pcall(function() internal = G.IsInternal(item) == true end)
        if not internal then return false end
        local ok = false
        pcall(function()
            local rounds = G.TubeRounds(item)
            if type(rounds) == "table" then
                table.insert(rounds, roundType)
                ok = true
            end
        end)
        if not ok then warnOnce("addinternalround", "TubeRounds failed") end
        return ok
    end

    function GSC.prepareShot(body, item)
        if not active() then return false end
        local G = api()
        if not isGunItem(G, item) then return false end
        local ran = false
        if type(G.SyncRounds) == "function" then
            local ok = pcall(G.SyncRounds, item)
            if ok then ran = true else warnOnce("syncrounds", "SyncRounds failed") end
        end
        local internal = false
        if type(G.IsInternal) == "function" then
            pcall(function() internal = G.IsInternal(item) == true end)
        end
        local round = nil
        if internal then
            if type(G.NextRound) == "function" then
                local ok, value = pcall(G.NextRound, item)
                if ok then round = value end
            end
        else
            local data = nil
            pcall(function() data = item:getModData() end)
            local record = type(data) == "table" and data.GS_mag or nil
            local rounds = type(record) == "table" and record.rounds or nil
            if type(rounds) == "table" and #rounds > 0 then round = rounds[#rounds] end
        end
        if type(round) == "string" and round ~= "" then
            pcall(function()
                local data = item:getModData()
                if type(data) == "table" then
                    data.GS_chamber = round
                    data.GS_dudRolled = nil
                end
            end)
        end
        if type(G.ApplyStats) == "function" then
            local ok = pcall(G.ApplyStats, item)
            if ok then ran = true else warnOnce("applystats", "ApplyStats failed") end
        end
        return ran
    end

    function GSC.afterShot(item)
        if not active() then return false end
        local G = api()
        if not isGunItem(G, item) then return false end
        if type(G.SyncRounds) ~= "function" then return false end
        local ok = pcall(G.SyncRounds, item)
        if not ok then warnOnce("syncrounds", "SyncRounds failed") end
        return ok
    end
end


local function gunworksModule(name, cacheKey)
    local cache = BridgeGunRules[cacheKey]
    if cache == nil then
        cache = { checked = false, value = nil }
        BridgeGunRules[cacheKey] = cache
    end
    if not cache.checked then
        cache.checked = true
        local mod = nil
        pcall(function() mod = require(name) end)
        if type(mod) == "table" then cache.value = mod end
    end
    return cache.value
end


local function gunworksAmmo()
    return gunworksModule("WeaponSystems/Utils/Ammo", "gunworksAmmoCache")
end


local function gunworksMagazine()
    return gunworksModule("WeaponSystems/Utils/Magazine", "gunworksMagazineCache")
end


local function gunworksSpeedLoader()
    return gunworksModule("WeaponSystems/Utils/SpeedLoader", "gunworksSpeedLoaderCache")
end


function BridgeGunRules.syncAmmoList(character, item)
    if item == nil then return end
    local ammoMod = gunworksAmmo()
    if ammoMod == nil or ammoMod.SyncAmmoListToClient == nil then return end
    pcall(function() ammoMod.SyncAmmoListToClient(character, item) end)
end


local function moduleOf(fullType)
    if type(fullType) ~= "string" then return nil end
    local module = string.match(fullType, "^([^%.]+)%.")
    return module
end


BridgeGunRules.itemExistsCache = BridgeGunRules.itemExistsCache or {}

local function itemExists(candidate)
    if type(candidate) ~= "string" or candidate == "" then return false end
    local cached = BridgeGunRules.itemExistsCache[candidate]
    if cached ~= nil then return cached end
    local exists, checked = false, false
    pcall(function()
        local manager = nil
        if ScriptManager ~= nil then manager = ScriptManager.instance end
        if manager == nil then manager = getScriptManager() end
        if manager == nil then return end
        exists = manager:getItem(candidate) ~= nil
        checked = true
    end)
    if not checked then return false end
    BridgeGunRules.itemExistsCache[candidate] = exists
    return exists
end
BridgeGunRules.itemExists = itemExists

local function probeItem(candidate)
    return itemExists(candidate)
end


local function tryCandidate(candidate, seen)
    if candidate == nil or candidate == "" or seen[candidate] then return nil end
    seen[candidate] = true
    if probeItem(candidate) then return candidate end
    return nil
end


local function resolveItemType(value, ...)
    if type(value) ~= "string" then return nil end
    local raw = string.match(value, "^%s*(.-)%s*$")
    if raw == "" then return nil end
    local seen = {}
    local hit = nil
    if string.find(raw, ".", 1, true) ~= nil then
        return tryCandidate(raw, seen)
    end
    local colon = string.find(raw, ":", 1, true)
    if colon ~= nil then
        local module = string.sub(raw, 1, colon - 1)
        local name = string.sub(raw, colon + 1)
        if module ~= "" and name ~= "" then
            local capital = string.upper(string.sub(module, 1, 1)) .. string.sub(module, 2)
            hit = tryCandidate(capital .. "." .. name, seen)
            if hit ~= nil then return hit end
        end
        return tryCandidate(raw, seen)
    end
    for i = 1, select("#", ...) do
        local module = select(i, ...)
        if type(module) == "string" and module ~= "" then
            hit = tryCandidate(module .. "." .. raw, seen)
            if hit ~= nil then return hit end
        end
    end
    return tryCandidate("Base." .. raw, seen)
end
BridgeGunRules.moduleOf = moduleOf
BridgeGunRules.resolveItemType = resolveItemType


local GGS = {}

local function ggsProfiles()
    local profiles = rawget(_G, "GGS_AmmoProfiles")
    if type(profiles) ~= "table" then return nil end
    return profiles
end

local function ggsQueue()
    local queue = rawget(_G, "GGS_AmmoQueue")
    if type(queue) ~= "table" then return nil end
    return queue
end

local function ggsReady()
    local profiles = ggsProfiles()
    local queue = ggsQueue()
    return profiles ~= nil and queue ~= nil
        and type(profiles.get) == "function"
        and type(profiles.getByAmmoFullType) == "function"
        and type(profiles.getRoundsForCaliber) == "function"
        and type(queue.isSupportedAmmoContainer) == "function"
        and type(queue.isSupportedWeapon) == "function"
        and type(queue.getQueue) == "function"
        and type(queue.insertLoadedRound) == "function"
        and type(queue.popNextRound) == "function"
        and type(queue.copyQueue) == "function"
        and type(queue.syncQueueWithAmmoCount) == "function"
        and type(queue.copyMagazineQueueFromWeapon) == "function"
        and type(queue.getEffectiveStats) == "function"
end

function BridgeGunRules.ggsActive()
    if GGS.active == true then return true end
    local on = ggsReady()
    if on then
        GGS.active = true
        if not GGS.logged then
            GGS.logged = true
            print("[BridgeGGS] GaelGunStore found: dynamic ammo queues enabled")
        end
    end
    return on
end

local function ggsProfileOf(desc)
    if type(desc) ~= "table" or type(desc.ammoTypeKey) ~= "string" then return nil end
    local profiles = ggsProfiles()
    if profiles == nil then return nil end
    local profile = nil
    pcall(function() profile = profiles.getByAmmoFullType(desc.ammoTypeKey) end)
    return profile
end

local function ggsAmmoTypesFor(desc)
    local out = {}
    if not BridgeGunRules.ggsActive() then return out end
    local profile = ggsProfileOf(desc)
    if type(profile) ~= "table" or type(profile.caliber) ~= "string" then return out end
    local profiles = ggsProfiles()
    local seen = {}
    local function add(t)
        if type(t) ~= "string" or t == "" or seen[t] then return end
        seen[t] = true
        out[#out + 1] = t
    end
    add(desc.ammoTypeKey)
    local list = nil
    pcall(function() list = profiles.getRoundsForCaliber(profile.caliber) end)
    if type(list) == "table" then
        for _, roundId in ipairs(list) do
            local round = nil
            pcall(function() round = profiles.get(roundId) end)
            if type(round) == "table" then add(round.ammoFullType) end
        end
    end
    return out
end

local function ggsMagazineTypesFor(desc, item)
    local out = {}
    if not BridgeGunRules.ggsActive() then return out end
    if type(desc) ~= "table" or desc.magazineType == nil then return out end
    local map = rawget(_G, "AWCWF_WeaponMagazineType")
    if type(map) ~= "table" then return out end
    local gun = item
    if gun == nil and type(desc.fullType) == "string" then
        pcall(function() gun = instanceItem(desc.fullType) end)
    end
    if gun == nil then return out end
    local gunType = nil
    pcall(function() gunType = gun:getType() end)
    if type(gunType) ~= "string" then return out end
    local list = map[gunType]
    if type(list) ~= "table" then return out end
    local mapping = rawget(_G, "GGS_MagMapping")
    for _, t in ipairs(list) do
        if type(t) == "string" and t ~= "" then
            local full = nil
            if mapping ~= nil and type(mapping.toFullType) == "function" then
                pcall(function() full = mapping.toFullType(t) end)
            end
            if type(full) ~= "string" then
                if string.find(t, ".", 1, true) ~= nil then full = t else full = "Base." .. t end
            end
            out[#out + 1] = full
        end
    end
    return out
end

local function ggsEnrichDesc(desc, item)
    if type(desc) ~= "table" then return end
    if not BridgeGunRules.ggsActive() then return end
    if desc.magazineType == nil then return end
    local types = ggsMagazineTypesFor(desc, item)
    if #types == 0 then return end
    desc.magazineTypes = desc.magazineTypes or {}
    desc.magazineSet = desc.magazineSet or {}
    for _, t in ipairs(types) do
        if type(t) == "string" and t ~= "" and not desc.magazineSet[t] then
            desc.magazineSet[t] = true
            desc.magazineTypes[#desc.magazineTypes + 1] = t
        end
    end
end

local function ggsLoadedRoundType(item)
    if item == nil or not BridgeGunRules.ggsActive() then return nil end
    local queue = ggsQueue()
    if queue == nil then return nil end
    local supported = false
    pcall(function() supported = queue.isSupportedAmmoContainer(item) == true end)
    if not supported then return nil end
    local list = nil
    pcall(function() list = queue.getQueue(item) end)
    if type(list) ~= "table" or #list == 0 then return nil end
    local profiles = ggsProfiles()
    local round = nil
    pcall(function() round = profiles.get(list[1]) end)
    if type(round) ~= "table" then return nil end
    return round.ammoFullType
end

local function ggsInsertLoadedRound(item, fullType)
    if item == nil or type(fullType) ~= "string" then return false end
    if not BridgeGunRules.ggsActive() then return false end
    local profiles = ggsProfiles()
    local queue = ggsQueue()
    if profiles == nil or queue == nil then return false end
    local roundId = nil
    pcall(function() roundId = profiles.ammoToRound[fullType] end)
    if roundId == nil then return false end
    local ok = false
    pcall(function() ok = queue.insertLoadedRound(item, roundId, 1) == true end)
    return ok
end

local function ggsConsumeRound(item)
    if item == nil or not BridgeGunRules.ggsActive() then return false end
    local queue = ggsQueue()
    if queue == nil then return false end
    local ok = false
    pcall(function() ok = queue.popNextRound(item) ~= nil end)
    return ok
end

local function ggsCopyQueue(source, target)
    if source == nil or target == nil then return false end
    if not BridgeGunRules.ggsActive() then return false end
    local queue = ggsQueue()
    if queue == nil then return false end
    local ok = false
    pcall(function() ok = queue.copyQueue(source, target) == true end)
    return ok
end

local function ggsCopyWeaponQueue(weapon, magazine)
    if weapon == nil or magazine == nil then return false end
    if not BridgeGunRules.ggsActive() then return false end
    local queue = ggsQueue()
    if queue == nil then return false end
    local ok = false
    pcall(function() ok = queue.copyMagazineQueueFromWeapon(weapon, magazine) == true end)
    return ok
end

local function ggsSyncCount(item)
    if item == nil or not BridgeGunRules.ggsActive() then return false end
    local queue = ggsQueue()
    if queue == nil then return false end
    local ok = false
    pcall(function()
        queue.syncQueueWithAmmoCount(item)
        ok = true
    end)
    return ok
end

local function ggsClearQueue(item)
    if item == nil or not BridgeGunRules.ggsActive() then return false end
    local queue = ggsQueue()
    if queue == nil then return false end
    local list = nil
    pcall(function() list = queue.getQueue(item) end)
    if type(list) ~= "table" then return false end
    for i = #list, 1, -1 do list[i] = nil end
    return true
end

local function ggsShotDesc(desc, item)
    if type(desc) ~= "table" or item == nil then return desc end
    if not BridgeGunRules.ggsActive() then return desc end
    local queue = ggsQueue()
    if queue == nil then return desc end
    local supported = false
    pcall(function() supported = queue.isSupportedWeapon(item) == true end)
    if not supported then return desc end
    local list = nil
    pcall(function() list = queue.getQueue(item) end)
    if type(list) ~= "table" or #list == 0 then return desc end
    local stats, profile = nil, nil
    pcall(function() stats, profile = queue.getEffectiveStats(item, list[1]) end)
    if type(stats) ~= "table" then return desc end
    local copy = {}
    for k, v in pairs(desc) do copy[k] = v end
    local fields = {
        "minDamage", "maxDamage", "maxRange", "maxHitCount", "piercingBullets",
        "projectileCount", "projectileSpread", "stopPower", "knockdownMod",
        "doorDamage", "soundRadius",
    }
    for _, key in ipairs(fields) do
        local value = stats[key]
        if value ~= nil then copy[key] = value end
    end
    local range = tonumber(copy.maxRange) or tonumber(copy.range) or 0
    if range > BridgeGunRules.MAX_RANGE then range = BridgeGunRules.MAX_RANGE end
    if range < 1 then range = 1 end
    copy.range = range
    if type(profile) == "table" and type(profile.ammoFullType) == "string" then
        copy.ammoTypeKey = profile.ammoFullType
    end
    return copy
end

BridgeGunRules.ggsShotDesc = ggsShotDesc
BridgeGunRules.ggsConsumeRound = ggsConsumeRound
BridgeGunRules.ggsInsertLoadedRound = ggsInsertLoadedRound
BridgeGunRules.ggsSyncCount = ggsSyncCount
BridgeGunRules.ggsCopyQueue = ggsCopyQueue


local function specFeeds(spec, ammoTypeKey)
    if type(spec) ~= "table" or type(spec.out) ~= "table" or ammoTypeKey == nil then return false end
    for _, t in ipairs(spec.out) do
        if t == ammoTypeKey then return true end
    end
    return false
end


local function ammoBoxFor(gunFullType, rawBox, ammoTypeKey)
    local gunModule = moduleOf(gunFullType)
    local ammoModule = moduleOf(ammoTypeKey)
    local label = tostring(gunFullType or "?") .. " ammoBox:" .. tostring(rawBox)
    local box = resolveItemType(rawBox, gunModule, ammoModule, "Base")
    if box == nil then
        local derived = nil
        if type(ammoTypeKey) == "string" then
            derived = resolveItemType(ammoTypeKey .. "Box", gunModule, ammoModule, "Base")
        end
        if derived ~= nil and specFeeds(BridgeGunRules.unpackOf(derived), ammoTypeKey) then
            return derived
        end
        if rawBox ~= nil then
            warnOnce(label, string.format("%s ammoBox %s unresolved", tostring(gunFullType), tostring(rawBox)))
        end
        return nil
    end
    if type(ammoTypeKey) ~= "string" then return box end
    local spec = BridgeGunRules.unpackOf(box)
    if spec == nil then return box end
    if specFeeds(spec, ammoTypeKey) then return box end
    local derived = resolveItemType(ammoTypeKey .. "Box", gunModule, ammoModule, "Base")
    if derived ~= nil and derived ~= box and specFeeds(BridgeGunRules.unpackOf(derived), ammoTypeKey) then
        warnOnce(label, string.format("%s ammoBox %s -> %s (feeds %s)",
            tostring(gunFullType), tostring(rawBox), derived, tostring(ammoTypeKey)))
        return derived
    end
    diag(label, string.format("%s ammoBox %s could not be verified to feed %s",
        tostring(gunFullType), tostring(box), tostring(ammoTypeKey)))
    return box
end


function BridgeGunRules.isGun(item)
    local yes = false
    pcall(function()
        yes = item ~= nil and instanceof(item, "HandWeapon") and item:isRanged() == true
    end)
    return yes
end


function BridgeGunRules.valid(item)
    if not BridgeGunRules.isGun(item) then return false end
    local ok = false
    pcall(function()
        local broken = false
        pcall(function() broken = item:isBroken() == true end)
        local condition = 1
        pcall(function() condition = item:getCondition() end)
        local range = 0
        pcall(function() range = item:getMaxRange() end)
        ok = not broken and type(condition) == "number" and condition > 0
            and type(range) == "number" and range > 0
    end)
    return ok
end


function BridgeGunRules.kind(gun)
    local anim = text(function() return gun:getSwingAnim() end, "Handgun")
    if anim == "Rifle" then return "Rifle" end
    return "Handgun"
end


function BridgeGunRules.range(gun)
    local range = num(function() return gun:getMaxRange() end, 0)
    if range > BridgeGunRules.MAX_RANGE then range = BridgeGunRules.MAX_RANGE end
    if range < 1 then range = 1 end
    return range
end


function BridgeGunRules.familyOf(desc)
    if type(desc) ~= "table" then return "unsupported" end
    local reload = string.lower(tostring(desc.reloadType or ""))
    if desc.external == true or desc.magazineType ~= nil then
        if string.find(reload, "handgun", 1, true) ~= nil or desc.kind == "Handgun" then return "handgun" end
        return "rifle"
    end
    if string.find(reload, "shotgun", 1, true) ~= nil then return "shotgun" end
    if string.find(reload, "revolver", 1, true) ~= nil then return "revolver" end
    if string.find(reload, "boltactionnomag", 1, true) ~= nil then return "rifle_nomag" end
    if desc.ammoTypeKey == nil then return "unsupported" end
    if (tonumber(desc.projectileCount) or 1) > 1 then return "shotgun" end
    if desc.kind == "Handgun" then return "revolver" end
    return "rifle_nomag"
end


function BridgeGunRules.talkKind(desc)
    if type(desc) ~= "table" then return "Other" end
    local family = tostring(desc.reloadFamily or "")
    if family == "shotgun" or (tonumber(desc.projectileCount) or 1) > 1 then
        return "Shotgun"
    end
    if desc.kind == "Rifle" or family == "rifle" or family == "rifle_nomag" then
        return "Rifle"
    end
    if desc.kind == "Handgun" or family == "handgun" or family == "revolver" then
        return "Pistol"
    end
    return "Other"
end


local MARZ_RIFLE_EXCLUDE = {
    ["MarzGuns.THOMPSON"] = true,
    ["MarzGuns.MP5"] = true,
    ["MarzGuns.MP5SD"] = true,
    ["MarzGuns.MP5A2"] = true,
    ["MarzGuns.M60"] = true,
    ["MarzGuns.BAR"] = true,
}

local function applyMarzRifleMultiHit(desc)
    if type(desc) ~= "table" then return end
    if moduleOf(desc.fullType) ~= "MarzGuns" then return end
    if desc.kind ~= "Rifle" then return end
    if (tonumber(desc.projectileCount) or 1) > 1 then return end
    if MARZ_RIFLE_EXCLUDE[desc.fullType] then return end
    if (tonumber(desc.maxHitCount) or 1) ~= 1 then return end
    desc.maxHitCount = 2
    desc.piercingBullets = true
end


function BridgeGunRules.describe(item)
    local maxAmmo = num(function() return item:getMaxAmmo() end, 0)
    if maxAmmo <= 0 then maxAmmo = num(function() return item:getClipSize() end, 0) end
    local ammo = ammoTypeOf(item)
    local out = {
        fullType = text(function() return item:getFullType() end, "?"),
        name = text(function() return item:getName() end, "gun"),
        maxRange = num(function() return item:getMaxRange() end, 0),
        minRange = num(function() return item:getMinRange() end, 0),
        minDamage = num(function() return item:getMinDamage() end, 0),
        maxDamage = num(function() return item:getMaxDamage() end, 0),
        hitChance = num(function() return item:getHitChance() end, 50),
        critChance = num(function() return item:getCriticalChance() end, 0),
        critMult = num(function() return item:getCriticalDamageMultiplier() end, 2),
        aimingTime = num(function() return item:getAimingTime() end, 40),
        recoilDelay = num(function() return item:getRecoilDelay() end, 24),
        sound = text(function() return item:getSwingSound() end, nil),
        hitSound = text(function() return item:getZombieHitSound() end, "ZombieHit"),
        impactSound = text(function() return item:getImpactSound() end, "BulletImpact"),
        soundRadius = num(function() return item:getSoundRadius() end, 20),
        soundVolume = num(function() return item:getSoundVolume() end, 10),
        projectileCount = num(function() return item:getProjectileCount() end, 1),
        maxHitCount = num(function() return item:getMaxHitCount() end, 1),
        piercingBullets = flag(function() return item:isPiercingBullets() end),
        projectileSpread = num(function() return item:getProjectileSpread() end, 1),
        minAngle = num(function() return item:getMinAngle() end, 0.9),
        twoHanded = flag(function() return item:isTwoHandWeapon() or item:isRequiresEquippedBothHands() end),
        kind = "Handgun",
        maxAmmo = maxAmmo,
        reloadType = typeText(function() return item:getWeaponReloadType() end),
        magazineType = typeText(function() return item:getMagazineType() end),
        ammoTypeKey = ammoKeyOf(item, ammo),
        ammoTypeId = ammoIdOf(ammo),
        ammoBox = typeText(function() return item:getAmmoBox() end),
        insertAll = flag(function() return item:isInsertAllBulletsReload() end),
        insertSound = typeText(function() return item:getInsertAmmoSound() end),
        ejectSound = typeText(function() return item:getEjectAmmoSound() end),
        insertStartSound = typeText(function() return item:getInsertAmmoStartSound() end),
        insertStopSound = typeText(function() return item:getInsertAmmoStopSound() end),
        rackSound = typeText(function() return item:getRackSound() end),
        rounds = 0,
    }
    local gunModule = moduleOf(out.fullType)
    local rawKey = out.ammoTypeKey
    out.ammoTypeKey = resolveItemType(rawKey, gunModule) or rawKey
    out.magazineType = resolveItemType(out.magazineType, gunModule, moduleOf(out.ammoTypeKey))
    out.magazineTypes = {}
    out.magazineSet = {}
    local function addMag(t)
        if type(t) ~= "string" or t == "" or out.magazineSet[t] then return end
        out.magazineSet[t] = true
        out.magazineTypes[#out.magazineTypes + 1] = t
    end
    addMag(out.magazineType)
    pcall(function()
        local mod = require("WeaponSystems/Utils/Magazine")
        local list = mod and mod.GetMagazineTypesForGun and mod.GetMagazineTypesForGun(item) or nil
        if type(list) == "table" then
            for _, t in ipairs(list) do addMag(t) end
        end
    end)
    out.ammoBox = ammoBoxFor(out.fullType, out.ammoBox, out.ammoTypeKey)
    out.kind = BridgeGunRules.kind(item)
    out.range = BridgeGunRules.range(item)
    out.external = out.magazineType ~= nil
    out.reloadFamily = BridgeGunRules.familyOf(out)
    out.ammoFamily = nil
    local ammoMod = gunworksAmmo()
    if ammoMod ~= nil then
        pcall(function() out.ammoFamily = ammoMod.GetFamilyForItem(item) end)
        if out.ammoFamily == nil and type(out.ammoTypeKey) == "string" then
            pcall(function()
                local _, foundFamily = ammoMod.FindBulletEntry(out.ammoTypeKey)
                if foundFamily ~= nil then out.ammoFamily = foundFamily end
            end)
        end
    end
    out.clipTypes = {}
    out.clipSet = {}
    local speedMod = gunworksSpeedLoader()
    if speedMod ~= nil then
        local list = nil
        pcall(function() list = speedMod.GetSpeedLoaderTypesForGun(item) end)
        if type(list) == "table" then
            for _, t in ipairs(list) do
                if type(t) == "string" and t ~= "" and not out.clipSet[t] then
                    out.clipSet[t] = true
                    out.clipTypes[#out.clipTypes + 1] = t
                end
            end
        end
    end
    for _, t in ipairs(out.clipTypes) do addMag(t) end
    local gs = gunsmith()
    if gs ~= nil then
        local ok = pcall(function()
            local list = gs.magazineTypes(item)
            if type(list) == "table" then
                for _, t in ipairs(list) do addMag(t) end
            end
            if gs.isGun(item) then
                out.gunsmith = true
                out.gunsmithItem = item
            end
        end)
        if not ok then diag("gunsmith-describe", "Gunsmith describe hook failed") end
    end
    out.hasMagazineProfile = #out.magazineTypes > 0
    out.hasClipProfile = #out.clipTypes > 0
    out.external = out.hasMagazineProfile
    if out.gunsmith == true then out.reloadFamily = BridgeGunRules.familyOf(out) end
    out.clipFamily = (out.reloadFamily == "revolver") and "revolver" or "rifle"
    pcall(function() out.rounds = BridgeGunRules.roundsOf(item) end)
    applyMarzRifleMultiHit(out)
    ggsEnrichDesc(out, item)
    return out
end


function BridgeGunRules.invalidateAmmoTypes(desc)
    if type(desc) == "table" then
        desc._ammoTypesCache = nil
        desc._ammoWantedCache = nil
    end
end

function BridgeGunRules.ammoTypesFor(desc, owner)
    local out, seen = {}, {}
    if type(desc) ~= "table" then return out end
    local ownerKey = tostring(owner)
    local sig = (gunworksAmmo() ~= nil and "1" or "0") .. (gunsmith() ~= nil and "1" or "0")
        .. (BridgeGunRules.ggsActive() and "1" or "0")
    local memo = desc._ammoTypesCache
    if type(memo) == "table" and memo.owner == ownerKey and memo.sig == sig then return memo.types end
    local function add(t)
        if type(t) ~= "string" or t == "" or seen[t] then return end
        seen[t] = true
        out[#out + 1] = t
    end
    local ammoMod = gunworksAmmo()
    local family = type(desc.ammoFamily) == "string" and desc.ammoFamily or nil
    if ammoMod ~= nil and type(desc.ammoTypeKey) == "string" then
        if family == nil then
            pcall(function()
                local _, foundFamily = ammoMod.FindBulletEntry(desc.ammoTypeKey)
                if type(foundFamily) == "string" then family = foundFamily end
            end)
            if family ~= nil then desc.ammoFamily = family end
        end
        if family ~= nil then
            local list = nil
            pcall(function() list = ammoMod.GetOrderedBulletTypesForFamily(owner, family) end)
            if type(list) ~= "table" or #list == 0 then
                pcall(function() list = ammoMod.GetBulletTypesForFamily(family) end)
            end
            if type(list) ~= "table" or #list == 0 then
                local foundFamily = nil
                pcall(function()
                    local _, f = ammoMod.FindBulletEntry(desc.ammoTypeKey)
                    foundFamily = f
                end)
                if type(foundFamily) == "string" and foundFamily ~= family then
                    family = foundFamily
                    desc.ammoFamily = family
                    pcall(function() list = ammoMod.GetOrderedBulletTypesForFamily(owner, family) end)
                    if type(list) ~= "table" or #list == 0 then
                        pcall(function() list = ammoMod.GetBulletTypesForFamily(family) end)
                    end
                end
            end
            if type(list) == "table" then
                for _, t in ipairs(list) do add(t) end
            end
        end
    end
    local gs = gunsmith()
    if gs ~= nil then
        local list = nil
        local ok = pcall(function() list = gs.ammoTypes(desc, owner) end)
        if ok and type(list) == "table" then
            for _, t in ipairs(list) do add(t) end
        elseif not ok then
            diag("gunsmith-ammotypes", "Gunsmith ammo type hook failed")
        end
    end
    add(desc.ammoTypeKey)
    for _, t in ipairs(ggsAmmoTypesFor(desc)) do add(t) end
    desc._ammoTypesCache = { owner = ownerKey, sig = sig, types = out }
    return out
end


function BridgeGunRules.summary(gun)
    if type(gun) ~= "table" then return "none" end
    return string.format("%s rng=%s dmg=%.1f-%.1f hit=%.0f crit=%.0f aim=%.0f recoil=%.0f snd=%s rad=%.0f vol=%.0f two=%s kind=%s ammo=%s box=%s mag=%s family=%s reload=%s maxhit=%s pierce=%s spread=%s minang=%s",
        tostring(gun.fullType), tostring(gun.range), gun.minDamage or 0, gun.maxDamage or 0,
        gun.hitChance or 0, gun.critChance or 0, gun.aimingTime or 0, gun.recoilDelay or 0,
        tostring(gun.sound or "-"), gun.soundRadius or 0, gun.soundVolume or 0,
        tostring(gun.twoHanded == true), tostring(gun.kind), tostring(gun.maxAmmo or 0),
        tostring(gun.ammoBox or "-"), tostring(gun.magazineType or "-"),
        tostring(gun.reloadFamily or "?"), tostring(gun.reloadType or "-"),
        tostring(gun.maxHitCount or 1), tostring(gun.piercingBullets == true),
        tostring(gun.projectileSpread or 1), tostring(gun.minAngle or 0.9))
end


function BridgeGunRules.effectiveRange(desc, aimingLevel)
    if type(desc) ~= "table" then return 0 end
    local base = tonumber(desc.range) or tonumber(desc.maxRange) or 0
    local level = tonumber(aimingLevel) or 0
    if level < 0 then level = 0 end
    local range = base * (1 + 0.10 * level)
    if range > BridgeGunRules.MAX_RANGE then range = BridgeGunRules.MAX_RANGE end
    if range < 1 then range = 1 end
    return range
end


function BridgeGunRules.aimTicks(desc, aimingLevel)
    if type(desc) ~= "table" then return 10 end
    local level = tonumber(aimingLevel) or 0
    if level < 0 then level = 0 end
    local aim = (tonumber(desc.aimingTime) or 40) * 0.6 * (1 - 0.02 * level)
    if aim < 10 then aim = 10 end
    return math.floor(aim + 0.5)
end


function BridgeGunRules.reloadFactor(reloadingLevel)
    local level = tonumber(reloadingLevel) or 0
    if level < 0 then level = 0 end
    local factor = 1 - 0.04 * level
    if factor < 0.6 then factor = 0.6 end
    return factor
end


function BridgeGunRules.hitChance(gun, distance, moving, aimingLevel)
    if type(gun) ~= "table" then return BridgeGunRules.MIN_CHANCE end
    local level = tonumber(aimingLevel) or 0
    if level < 0 then level = 0 end
    local chance = (tonumber(gun.hitChance) or 50) + BridgeGunRules.AIM_BONUS + 1.5 * level
    chance = chance / 100
    if chance < 0 then chance = 0 end
    if chance > 1 then chance = 1 end
    local range = tonumber(gun.range) or BridgeGunRules.MAX_RANGE
    if range < 1 then range = 1 end
    local d = tonumber(distance) or 0
    if d < 0 then d = 0 end
    if d <= range * 0.4 then
        chance = chance * BridgeGunRules.CLOSE_BONUS
    else
        local far = math.min(1, (d - range * 0.4) / (range * 0.6))
        chance = chance * (1 - BridgeGunRules.FAR_PENALTY * far)
    end
    if moving then chance = chance * BridgeGunRules.MOVING_FACTOR end
    if chance < BridgeGunRules.MIN_CHANCE / 100 then chance = BridgeGunRules.MIN_CHANCE / 100 end
    if chance > BridgeGunRules.MAX_CHANCE / 100 then chance = BridgeGunRules.MAX_CHANCE / 100 end
    return chance * 100
end


function BridgeGunRules.rollDamage(gun)
    if type(gun) ~= "table" then return BridgeGunRules.NPC_DAMAGE_SCALE end
    local lo = tonumber(gun.minDamage) or 1
    local hi = tonumber(gun.maxDamage) or lo
    if hi < lo then hi = lo end
    local roll = 0
    pcall(function() roll = ZombRand(0, 1001) / 1000 end)
    local dmg = lo + (hi - lo) * roll
    return dmg * BridgeGunRules.NPC_DAMAGE_SCALE
end


local function dist2(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end
BridgeGunRules.dist2 = dist2


function BridgeGunRules.noiseMultiplier()
    local mult = 1
    pcall(function()
        if SandboxVars ~= nil and type(SandboxVars.FirearmNoiseMultiplier) == "number" then
            mult = SandboxVars.FirearmNoiseMultiplier
        end
    end)
    if mult < 0 then mult = 0 end
    return mult
end


function BridgeGunRules.lineClear(cell, x1, y1, z1, x2, y2, z2)
    if cell == nil then return false end
    if math.abs((z1 or 0) - (z2 or 0)) >= 0.5 then return false end
    local ok = false
    pcall(function()
        local z = math.floor(z1 or 0)
        local prev = cell:getGridSquare(math.floor(x1), math.floor(y1), z)
        if prev == nil then return end
        local dist = dist2(x1, y1, x2, y2)
        local steps = math.max(1, math.ceil(dist / 0.4))
        for i = 1, steps do
            local t = i / steps
            local sx = math.floor(x1 + (x2 - x1) * t)
            local sy = math.floor(y1 + (y2 - y1) * t)
            if sx ~= prev:getX() or sy ~= prev:getY() then
                local sq = cell:getGridSquare(sx, sy, z)
                if sq == nil then return end
                if sx ~= prev:getX() and sy ~= prev:getY() then
                    local a = cell:getGridSquare(sx, prev:getY(), z)
                    local b = cell:getGridSquare(prev:getX(), sy, z)
                    if a == nil or b == nil then return end
                    if prev:isBlockedTo(a) or a:isBlockedTo(sq) then return end
                    if prev:isBlockedTo(b) or b:isBlockedTo(sq) then return end
                elseif prev:isBlockedTo(sq) then
                    return
                end
                prev = sq
            end
        end
        ok = true
    end)
    return ok
end


BridgeGunRules.FULL_PLANKS = 4

local function barricadeClosed(b)
    local closed = false
    if b == nil then return false end
    pcall(function()
        local metal = false
        pcall(function() metal = b:isMetal() == true end)
        local metalBar = false
        pcall(function() metalBar = b:isMetalBar() == true end)
        local planks = 0
        pcall(function() planks = tonumber(b:getNumPlanks()) or 0 end)
        local vision = false
        pcall(function() vision = b:isBlockVision() == true end)
        closed = metal or metalBar or planks >= BridgeGunRules.FULL_PLANKS or vision
    end)
    return closed
end


function BridgeGunRules.windowClosedOff(w)
    if w == nil then return false end
    local closed = false
    pcall(function()
        local same, opposite = nil, nil
        pcall(function() same = w:getBarricadeOnSameSquare() end)
        pcall(function() opposite = w:getBarricadeOnOppositeSquare() end)
        closed = barricadeClosed(same) or barricadeClosed(opposite)
    end)
    return closed
end


local function edgeWindow(a, b)
    if a == nil or b == nil then return nil end
    local w = nil
    pcall(function()
        if type(a.getWindowTo) == "function" then w = a:getWindowTo(b) end
        if w == nil and type(b.getWindowTo) == "function" then w = b:getWindowTo(a) end
        if w == nil and type(a.getWindowFrameTo) == "function" then w = a:getWindowFrameTo(b) end
        if w == nil and type(b.getWindowFrameTo) == "function" then w = b:getWindowFrameTo(a) end
        if w == nil and type(a.getWindowThumpableTo) == "function" then w = a:getWindowThumpableTo(b) end
        if w == nil and type(b.getWindowThumpableTo) == "function" then w = b:getWindowThumpableTo(a) end
    end)
    return w
end
BridgeGunRules.edgeWindow = edgeWindow


local function edgeTallHoppable(a, b)
    if a == nil or b == nil then return false end
    local owner, north = nil, false
    if a:getX() ~= b:getX() then
        owner, north = (a:getX() > b:getX()) and a or b, false
    else
        owner, north = (a:getY() > b:getY()) and a or b, true
    end
    local tall = false
    pcall(function()
        local objects = owner:getObjects()
        if objects == nil then return end
        for i = 0, objects:size() - 1 do
            local o = objects:get(i)
            if o ~= nil and o:isTallHoppable() then
                local props = o:getProperties()
                local n = props:has(IsoFlagType.TallHoppableN)
                local w = props:has(IsoFlagType.TallHoppableW)
                if (north and n) or (not north and w) then tall = true return end
            end
        end
    end)
    return tall
end
BridgeGunRules.edgeTallHoppable = edgeTallHoppable


local function edgeTallObject(a, b)
    if a == nil or b == nil then return nil end
    local owner, north = nil, false
    if a:getX() ~= b:getX() then
        owner, north = (a:getX() > b:getX()) and a or b, false
    else
        owner, north = (a:getY() > b:getY()) and a or b, true
    end
    local found = nil
    pcall(function()
        local objects = owner:getObjects()
        if objects == nil then return end
        for i = 0, objects:size() - 1 do
            local o = objects:get(i)
            if o ~= nil and o:isTallHoppable() then
                local props = o:getProperties()
                local n = props:has(IsoFlagType.TallHoppableN)
                local w = props:has(IsoFlagType.TallHoppableW)
                if (north and n) or (not north and w) then found = o return end
            end
        end
    end)
    return found
end


local function tallFenceSeeThrough(o)
    if o == nil then return false end
    local parts = {}
    pcall(function()
        local sprite = o:getSprite()
        if sprite ~= nil then parts[#parts + 1] = tostring(sprite:getName()) end
    end)
    pcall(function() parts[#parts + 1] = tostring(o:getName()) end)
    pcall(function() parts[#parts + 1] = tostring(o:getSpriteName()) end)
    pcall(function()
        local props = o:getProperties()
        if props ~= nil then
            parts[#parts + 1] = tostring(props:get("FenceTypeHigh") or "")
            parts[#parts + 1] = tostring(props:get("FenceTypeLow") or "")
        end
    end)
    local text = string.lower(table.concat(parts, " "))
    if string.find(text, "wire", 1, true) ~= nil then return true end
    if string.find(text, "chain", 1, true) ~= nil then return true end
    if string.find(text, "barb", 1, true) ~= nil then return true end
    if string.find(text, "metal", 1, true) ~= nil then return true end
    return false
end


local function edgeStopsBullet(a, b)
    if a == nil or b == nil then return true, "no_square" end
    local w = edgeWindow(a, b)
    if w ~= nil then
        if BridgeGunRules.windowClosedOff(w) then return true, "barricade" end
        return false, nil
    end
    local hop = false
    pcall(function() hop = a:isHoppableTo(b) == true or b:isHoppableTo(a) == true end)
    if hop then return false, nil end
    local tall = edgeTallObject(a, b)
    if tall ~= nil then
        if tallFenceSeeThrough(tall) then return false, nil end
        return true, "tall_fence"
    end
    local blocked = false
    pcall(function() blocked = a:isBlockedTo(b) == true or b:isBlockedTo(a) == true end)
    if blocked then return true, "wall_or_door" end
    return false, nil
end
BridgeGunRules.edgeStopsBullet = edgeStopsBullet


function BridgeGunRules.fireLineClear(cell, x1, y1, z1, x2, y2, z2)
    if cell == nil then return false, "no_square" end
    if math.abs((z1 or 0) - (z2 or 0)) >= 0.5 then return false, "floor" end
    local ok, why = true, nil
    pcall(function()
        local z = math.floor(z1 or 0)
        local prev = cell:getGridSquare(math.floor(x1), math.floor(y1), z)
        if prev == nil then ok = false why = "no_square" return end
        local dist = dist2(x1, y1, x2, y2)
        local steps = math.max(1, math.ceil(dist / 0.4))
        for i = 1, steps do
            local t = i / steps
            local sx = math.floor(x1 + (x2 - x1) * t)
            local sy = math.floor(y1 + (y2 - y1) * t)
            if sx ~= prev:getX() or sy ~= prev:getY() then
                local sq = cell:getGridSquare(sx, sy, z)
                if sq == nil then ok = false why = "no_square" return end
                local stopped, reason = false, nil
                if sx ~= prev:getX() and sy ~= prev:getY() then
                    local a = cell:getGridSquare(sx, prev:getY(), z)
                    local b = cell:getGridSquare(prev:getX(), sy, z)
                    if a == nil or b == nil then ok = false why = "no_square" return end
                    stopped, reason = edgeStopsBullet(prev, a)
                    if not stopped then stopped, reason = edgeStopsBullet(a, sq) end
                    if not stopped then stopped, reason = edgeStopsBullet(prev, b) end
                    if not stopped then stopped, reason = edgeStopsBullet(b, sq) end
                else
                    stopped, reason = edgeStopsBullet(prev, sq)
                end
                if stopped then ok = false why = reason or "wall_or_door" return end
                prev = sq
            end
        end
    end)
    return ok, why
end


function BridgeGunRules.targetVisible(body, red, z)
    if z == nil then return false end
    if BridgeZScan ~= nil and type(BridgeZScan.canSee) == "function" then
        return BridgeZScan.canSee(z, body, red) == true
    end
    local seen = false
    if body ~= nil then
        pcall(function() seen = body:CanSee(z) == true end)
    end
    if not seen and red ~= nil and red ~= body then
        pcall(function() seen = red:CanSee(z) == true end)
    end
    return seen
end


function BridgeGunRules.breakGlassOnLine(cell, x1, y1, z1, x2, y2, z2)
    if cell == nil then return 0 end
    if math.abs((z1 or 0) - (z2 or 0)) >= 0.5 then return 0 end
    local broken = 0
    local seen = {}
    local function smash(w)
        if w == nil or seen[w] then return end
        seen[w] = true
        local skip = false
        pcall(function()
            if w:IsOpen() == true or w:isSmashed() == true then skip = true end
            if w.isInvincible ~= nil and w:isInvincible() == true then skip = true end
        end)
        if skip then return end
        local done = false
        pcall(function() w:smashWindow() done = true end)
        if done then broken = broken + 1 end
    end
    local function panesOn(sq)
        if sq == nil then return end
        pcall(function()
            local objects = sq:getObjects()
            if objects == nil then return end
            for i = 0, objects:size() - 1 do
                local object = objects:get(i)
                if object ~= nil and instanceof(object, "IsoWindow") then smash(object) end
            end
        end)
    end
    pcall(function()
        local z = math.floor(z1 or 0)
        local prev = cell:getGridSquare(math.floor(x1), math.floor(y1), z)
        if prev == nil then return end
        local dist = dist2(x1, y1, x2, y2)
        local steps = math.max(1, math.ceil(dist / 0.4))
        for i = 1, steps do
            local t = i / steps
            local sx = math.floor(x1 + (x2 - x1) * t)
            local sy = math.floor(y1 + (y2 - y1) * t)
            if sx ~= prev:getX() or sy ~= prev:getY() then
                local sq = cell:getGridSquare(sx, sy, z)
                if sq == nil then return end
                local w = edgeWindow(prev, sq)
                if w ~= nil then
                    smash(w)
                else
                    panesOn(prev)
                    panesOn(sq)
                end
                prev = sq
            end
        end
    end)
    return broken
end


BridgeGunRules.MAX_GUN_HITS = 16


function BridgeGunRules.shotgunConeDot(desc)
    local d = type(desc) == "table" and desc or {}
    local minDot = tonumber(d.minAngle) or 0.9
    local spread = math.max(1, tonumber(d.projectileSpread) or 1)
    return clamp(minDot - 0.05 * (spread - 1), 0.70, 0.98)
end


function BridgeGunRules.multiPlan(body, primary, desc, candidates, modeRange, opts)
    local plan = { kind = nil, extras = {}, primaryShare = 1 }
    if body == nil or primary == nil or type(desc) ~= "table" then return plan end
    local cap = math.floor(tonumber(desc.maxHitCount) or 1)
    cap = clamp(cap, 1, BridgeGunRules.MAX_GUN_HITS)
    if cap <= 1 then return plan end
    local range = tonumber(modeRange) or tonumber(desc.range) or 0
    local bx, by = body:getX(), body:getY()
    local px, py = primary:getX(), primary:getY()
    local pdx, pdy = px - bx, py - by
    local primaryDist = math.sqrt(pdx * pdx + pdy * pdy)
    if primaryDist < 0.001 then return plan end
    local list = {}
    if (tonumber(desc.projectileCount) or 1) > 1 then
        local ux, uy = pdx / primaryDist, pdy / primaryDist
        local cone = BridgeGunRules.shotgunConeDot(desc)
        cap = math.min(cap, math.max(1, math.floor(tonumber(desc.projectileCount) or 1)))
        for _, z in ipairs(candidates or {}) do
            if z ~= nil and z ~= body and z ~= primary then
                local dx, dy = z:getX() - bx, z:getY() - by
                local d = math.sqrt(dx * dx + dy * dy)
                if d > 0.001 and d <= range + 0.9 then
                    local dot = (dx * ux + dy * uy) / d
                    if dot >= cone then
                        list[#list + 1] = { target = z, dist = d, dot = dot }
                    end
                end
            end
        end
        table.sort(list, function(a, b)
            if math.abs(a.dot - b.dot) > 0.0001 then return a.dot > b.dot end
            return a.dist < b.dist
        end)
        while #list > cap - 1 do table.remove(list) end
        if #list > 0 then
            plan.kind = "shotgun"
            plan.primaryShare = 0.5
            local share = 0.5 / #list
            for _, ex in ipairs(list) do
                ex.share = share
                ex.chanceScale = clamp(0.55 + 0.45 * ex.dot, 0.55, 1.0)
                plan.extras[#plan.extras + 1] = ex
            end
        end
        return plan
    end
    if desc.piercingBullets == true then
        local ux, uy = pdx / primaryDist, pdy / primaryDist
        for _, z in ipairs(candidates or {}) do
            if z ~= nil and z ~= body and z ~= primary then
                local dx, dy = z:getX() - bx, z:getY() - by
                local along = dx * ux + dy * uy
                local lateral = math.abs(dx * uy - dy * ux)
                if along > primaryDist + 0.3 and along <= range + 0.3
                    and lateral <= 0.35 + 0.05 * along then
                    list[#list + 1] = { target = z, along = along, lateral = lateral }
                end
            end
        end
        table.sort(list, function(a, b) return a.along < b.along end)
        while #list > cap - 1 do table.remove(list) end
        if #list > 0 then
            plan.kind = "rifle"
            plan.primaryShare = 1
            local share = 0.5
            for _, ex in ipairs(list) do
                ex.share = share
                ex.chanceScale = 1
                share = share * 0.5
                plan.extras[#plan.extras + 1] = ex
            end
        end
        return plan
    end
    return plan
end


function BridgeGunRules.atyOn()
    if BridgeGunRules.atyCache ~= nil then return BridgeGunRules.atyCache end
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        for i = 0, mods:size() - 1 do
            local id = string.lower(tostring(mods:get(i)))
            if string.sub(id, 1, 1) == "\\" then id = string.sub(id, 2) end
            if string.find(id, "trajector", 1, true) ~= nil
                or string.sub(id, 1, 3) == "aty" then on = true end
        end
    end)
    BridgeGunRules.atyCache = on
    return on
end


function BridgeGunRules.atyShotgun(desc)
    local key = string.lower(tostring(desc and desc.ammoTypeKey or ""))
    return string.find(key, "shotgun", 1, true) ~= nil
end


function BridgeGunRules.atyShotgunnum(override)
    if override ~= nil then return math.max(0, math.floor(tonumber(override) or 1)) end
    if BridgeGunRules.atyNum ~= nil then return BridgeGunRules.atyNum end
    local num = 1
    pcall(function()
        local opt = getSandboxOptions():getOptionByName("Advanced_trajectory.shotgunnum")
        if opt ~= nil then num = math.max(0, math.floor(tonumber(opt:getValue()) or 1)) end
    end)
    BridgeGunRules.atyNum = num
    return num
end


function BridgeGunRules.atyCap(desc, shotgunnum)
    local mh = math.max(1, math.floor(tonumber(desc and desc.maxHitCount) or 1))
    if BridgeGunRules.atyShotgun(desc) then
        return math.max(1, math.floor(mh / 2) + BridgeGunRules.atyShotgunnum(shotgunnum))
    end
    return mh
end


function BridgeGunRules.atyScale(shotgun, lateral, dist, modeRange)
    local scale
    if shotgun then
        local r = 0
        if modeRange ~= nil and modeRange > 0 then
            r = math.max(0, math.min(1, (tonumber(dist) or 0) / modeRange))
        end
        scale = 1 - 0.5 * r
    else
        scale = 1 - math.min(1, math.max(0, (tonumber(lateral) or 0) / 2))
    end
    return scale * BridgeGunRules.ATY_DAMAGE_SCALE
end


function BridgeGunRules.atyPlan(body, primary, desc, candidates, modeRange)
    local plan = { kind = "aty", extras = {}, primaryShare = 1 }
    if body == nil or primary == nil or type(desc) ~= "table" then return plan end
    local shotgun = BridgeGunRules.atyShotgun(desc)
    local cap = BridgeGunRules.atyCap(desc)
    local half = shotgun and BridgeGunRules.ATY_CORRIDOR_SHOTGUN or BridgeGunRules.ATY_CORRIDOR
    local range = tonumber(modeRange) or tonumber(desc.range) or 0
    local bx, by = body:getX(), body:getY()
    local px, py = primary:getX(), primary:getY()
    local pdx, pdy = px - bx, py - by
    local pd = math.sqrt(pdx * pdx + pdy * pdy)
    if pd < 0.001 or range <= 0 then return plan end
    local ux, uy = pdx / pd, pdy / pd
    plan.primaryShare = BridgeGunRules.atyScale(shotgun, 0, pd, range)

    local list = {}
    if cap > 1 then
        for _, z in ipairs(candidates or {}) do
            if z ~= nil and z ~= body and z ~= primary then
                local dx, dy = z:getX() - bx, z:getY() - by
                local along = dx * ux + dy * uy
                local lateral = math.abs(dx * uy - dy * ux)
                if along > 0 and along <= range + 0.9 and lateral <= half then
                    local scale = BridgeGunRules.atyScale(shotgun, lateral, along, range)
                    if scale > 0.02 then
                        list[#list + 1] = { target = z, share = scale, forceHit = true,
                            dist = along, lateral = lateral }
                    end
                end
            end
        end
        table.sort(list, function(a, b)
            if math.abs(a.dist - b.dist) > 0.0001 then return a.dist < b.dist end
            return a.lateral < b.lateral
        end)
        while #list > cap - 1 do table.remove(list) end
    end
    plan.extras = list
    return plan
end


function BridgeGunRules.aimAngle(fx, fy, tx, ty)
    local ax, ay = tonumber(fx) or 0, tonumber(fy) or 0
    local bx, by = tonumber(tx) or 0, tonumber(ty) or 0
    local la = math.sqrt(ax * ax + ay * ay)
    local lb = math.sqrt(bx * bx + by * by)
    if la < 0.001 or lb < 0.001 then return 0 end
    local c = (ax * bx + ay * by) / (la * lb)
    if c < -1 then c = -1 elseif c > 1 then c = 1 end
    return math.acos(c)
end


function BridgeGunRules.turnTicks(angle)
    local a = tonumber(angle) or 0
    if a < 0 then a = 0 elseif a > math.pi then a = math.pi end
    local x = a / math.pi * BridgeGunRules.TURN_TICKS_MAX
    return math.floor(x + 0.5)
end


function BridgeGunRules.plantTicks(moving)
    if moving == true then return BridgeGunRules.PLANT_TICKS end
    return 0
end


function BridgeGunRules.retargetTicks(changed)
    if changed == true then return BridgeGunRules.RETARGET_TICKS end
    return 0
end


function BridgeGunRules.pointSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len = dx * dx + dy * dy
    if len <= 0.0001 then return dist2(px, py, ax, ay), 0 end
    local t = ((px - ax) * dx + (py - ay) * dy) / len
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    local cx, cy = ax + dx * t, ay + dy * t
    return dist2(px, py, cx, cy), t
end


function BridgeGunRules.friendlyInLine(body, target, friendlies)
    if body == nil or target == nil then return nil end
    local blocked = nil
    pcall(function()
        local ax, ay, az = body:getX(), body:getY(), body:getZ()
        local bx, by, bz = target:getX(), target:getY(), target:getZ()
        for _, f in ipairs(friendlies or {}) do
            if f ~= nil and f ~= body and f ~= target then
                local fx, fy, fz = f:getX(), f:getY(), f:getZ()
                if math.abs((fz or az) - az) < 0.8 then
                    local d, t = BridgeGunRules.pointSegment(fx, fy, ax, ay, bx, by)
                    if d <= BridgeGunRules.FRIENDLY_RADIUS and t > 0 and t < 0.99 then
                        blocked = f
                        return
                    end
                end
            end
        end
    end)
    return blocked
end


local foreignMemo = setmetatable({}, { __mode = "k" })
local foreignMemoTick = nil

local function foreignTickNow()
    local f = nil
    if BridgeZScan ~= nil and type(BridgeZScan.tickOf) == "function" then f = BridgeZScan.tickOf end
    if type(f) == "function" then
        local ok, v = pcall(f)
        if ok and tonumber(v) ~= nil then return tonumber(v) end
    end
    if Bridge ~= nil and tonumber(Bridge.tick) ~= nil then return tonumber(Bridge.tick) end
    if BridgeServer ~= nil and tonumber(BridgeServer.tick) ~= nil then return tonumber(BridgeServer.tick) end
    return 0
end

function BridgeGunRules.isForeignNpc(z)
    if z == nil then return nil end
    local tick = foreignTickNow()
    if foreignMemoTick ~= tick then
        foreignMemo = setmetatable({}, { __mode = "k" })
        foreignMemoTick = tick
    end
    local hit = foreignMemo[z]
    if hit ~= nil then return hit or nil end
    local who = nil
    pcall(function()
        if z == nil then return end
        local npc = false
        pcall(function() npc = instanceof(z, "IsoNpcPlayer") end)
        if not npc and type(z.hasModData) == "function" and z:hasModData() == false then return end
        local md = nil
        pcall(function() md = z:getModData() end)
        if md ~= nil then
            if md.PS_NPC_ID ~= nil then who = "Project Survivors" end
            if md.ProjectALifeOwned == true or md.ProjectALifeActor == true then who = "Project A-Life" end
            if md.brainId ~= nil then who = "Bandits" end
        end
        if who == nil then
            local actor = nil
            pcall(function() actor = z:getVariableString("ALifeActor") end)
            if actor == "true" or actor == true then who = "Project A-Life" end
        end
        if who == nil then
            local primary = nil
            pcall(function() primary = z:getVariableString("BanditPrimary") end)
            if type(primary) == "string" and primary ~= "" then who = "Bandits" end
        end
        if who == nil and PS ~= nil and PS.Bodies ~= nil and type(PS.Bodies.isOurs) == "function" then
            local ours = false
            pcall(function() ours = PS.Bodies.isOurs(z) == true end)
            if ours then who = "Project Survivors" end
        end
        if who == nil and npc then who = "Knox Event Expanded" end
    end)
    foreignMemo[z] = who or false
    return who
end


function BridgeGunRules.foreignGunAllowed(z, peacefulOf)
    local dt = rawget(_G, "BridgeDT")
    if type(dt) == "table" and type(dt.gunAllowed) == "function" then
        local answer = dt.gunAllowed(z, peacefulOf)
        if answer ~= nil then return answer end
    end
    local who = BridgeGunRules.isForeignNpc(z)
    if who == nil then return true end
    if who ~= "Project A-Life" then return false end
    local answer = nil
    if type(peacefulOf) == "function" then
        local ok, value = pcall(peacefulOf, z)
        if ok then answer = value end
    end
    return answer == false
end


local SHOT_SIDE = { "ShotChest", "ShotChestStep", "ShotLeg", "ShotShoulder", "ShotShoulderStep" }

function BridgeGunRules.shotReaction(shooter, victim, crit)
    if shooter == nil or victim == nil then return "ShotBelly" end
    local reaction = "ShotBelly"
    pcall(function()
        local fx, fy = victim:getForwardDirectionX(), victim:getForwardDirectionY()
        local dx, dy = shooter:getX() - victim:getX(), shooter:getY() - victim:getY()
        local len = math.sqrt(fx * fx + fy * fy) * math.sqrt(dx * dx + dy * dy)
        if len < 0.0001 then return end
        local facing = (fx * dx + fy * dy) / len
        if facing > 0.7 then
            if crit then reaction = "ShotHeadBwd"
            else reaction = ZombRand(2) == 0 and "ShotBelly" or "ShotBellyStep" end
        elseif facing < -0.7 then
            if crit then reaction = ZombRand(2) == 0 and "ShotHeadFwd" or "ShotHeadFwd02"
            else reaction = "ShotBellyStepBehind" end
        else
            local side = (fx * dy - fy * dx) >= 0 and "R" or "L"
            reaction = SHOT_SIDE[ZombRand(1, #SHOT_SIDE + 1)] .. side
        end
    end)
    return reaction
end


function BridgeGunRules.validType(value)
    if type(value) ~= "string" or value == "" or #value > 64 then return false end
    if string.match(value, "^[%w_%.]+$") == nil then return false end
    local item = nil
    pcall(function() item = instanceItem(value) end)
    return BridgeGunRules.valid(item)
end


local function wornItems(body)
    local list = {}
    if body == nil then return list end
    pcall(function()
        local worn = body:getWornItems()
        if worn == nil then return end
        for i = 0, worn:size() - 1 do
            local entry = nil
            pcall(function() entry = worn:get(i) end)
            if entry == nil then pcall(function() entry = worn:getItemByIndex(i) end) end
            local item = entry
            if entry ~= nil then
                local ok, inner = pcall(function() return entry:getItem() end)
                if ok and inner ~= nil then item = inner end
            end
            if item ~= nil then list[#list + 1] = item end
        end
    end)
    return list
end


local itemsMemo = setmetatable({}, { __mode = "k" })
local itemsEpoch = 0

function BridgeGunRules.bumpItems()
    itemsEpoch = itemsEpoch + 1
end

local function itemsTick()
    if Bridge ~= nil and tonumber(Bridge.tick) ~= nil then return tonumber(Bridge.tick) end
    if BridgeServer ~= nil and tonumber(BridgeServer.tick) ~= nil then return tonumber(BridgeServer.tick) end
    return 0
end

function BridgeGunRules.itemsOf(body)
    local out = {}
    if body == nil then return out end
    local now = itemsTick()
    local cached = itemsMemo[body]
    if cached ~= nil and cached.tick == now and cached.epoch == itemsEpoch then return cached.list end
    local seen = {}
    local function scan(container)
        if container == nil or seen[container] then return end
        seen[container] = true
        local items = nil
        pcall(function() items = container:getItems() end)
        if items == nil then return end
        for i = 0, items:size() - 1 do
            local item = nil
            pcall(function() item = items:get(i) end)
            if item ~= nil then
                out[#out + 1] = item
                local inner = nil
                pcall(function()
                    if item:IsInventoryContainer() then inner = item:getInventory() end
                end)
                if inner ~= nil then scan(inner) end
            end
        end
    end
    pcall(function() scan(body:getInventory()) end)
    pcall(function()
        for _, item in ipairs(wornItems(body)) do
            out[#out + 1] = item
            local bag = nil
            pcall(function() if item:IsInventoryContainer() then bag = item:getInventory() end end)
            if bag ~= nil then scan(bag) end
        end
    end)
    itemsMemo[body] = { tick = now, epoch = itemsEpoch, list = out }
    return out
end


function BridgeGunRules.placeItem(body, item, prefer)
    if body == nil or item == nil then return false end
    local added = false
    if prefer ~= nil then
        pcall(function() added = prefer:AddItem(item) ~= nil end)
        if added then return true end
    end
    pcall(function()
        for _, bagItem in ipairs(wornItems(body)) do
            if added then break end
            if bagItem:IsInventoryContainer() then
                local bag = nil
                pcall(function() bag = bagItem:getInventory() end)
                if bag ~= nil then
                    pcall(function() added = bag:AddItem(item) ~= nil end)
                end
            end
        end
    end)
    if added then return true end
    if BridgeGunRules.addToBody(body, item) then return true end
    pcall(function()
        local sq = nil
        pcall(function() sq = body:getCurrentSquare() end)
        if sq == nil then pcall(function() sq = body:getSquare() end) end
        if sq == nil then return end
        local x, y = ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9)
        local z = sq:getApparentZ(x, y) - sq:getZ()
        sq:AddWorldInventoryItem(item, x, y, z)
        added = true
    end)
    if added then
        pcall(function()
            print("[BridgeGunRules] no room for " .. tostring(item:getType()) .. ": dropped at her feet")
        end)
    end
    return added
end


function BridgeGunRules.findItemById(body, id)
    if body == nil or id == nil then return nil end
    local item = nil
    pcall(function() item = body:getInventory():getItemWithIDRecursiv(id) end)
    if item ~= nil then return item end
    for _, bagItem in ipairs(wornItems(body)) do
        if item ~= nil then break end
        local bag = nil
        pcall(function() if bagItem:IsInventoryContainer() then bag = bagItem:getInventory() end end)
        if bag ~= nil then
            pcall(function() item = bag:getItemWithIDRecursiv(id) end)
        end
    end
    return item
end


function BridgeGunRules.findGunItem(body, id, fullType)
    if body == nil then return nil end
    local function match(item)
        if item == nil or not BridgeGunRules.valid(item) then return false end
        if fullType ~= nil then
            local full = nil
            pcall(function() full = item:getFullType() end)
            if full ~= fullType then return false end
        end
        return true
    end

    local found = nil
    if id ~= nil then
        found = BridgeGunRules.findItemById(body, id)
        if not match(found) then found = nil end
    end

    if found == nil and fullType ~= nil then
        pcall(function()
            local items = BridgeGunRules.itemsOf(body)
            for _, item in ipairs(items) do
                if match(item) then found = item break end
            end
        end)
    end
    return found
end


function BridgeGunRules.itemCount(item)
    local count = 1
    if item == nil then return 0 end
    pcall(function()
        local n = item:getCount()
        if type(n) == "number" and n == n and n > 0 then count = math.floor(n) end
    end)
    return count
end


function BridgeGunRules.removeItem(item)
    if item == nil then return false end
    BridgeGunRules.bumpItems()
    local ok = false
    pcall(function()
        local container = item:getContainer()
        if container ~= nil then
            container:Remove(item)
            ok = true
        end
    end)
    return ok
end


function BridgeGunRules.setItemCount(item, count)
    if item == nil then return false end
    if count <= 0 then return BridgeGunRules.removeItem(item) end
    BridgeGunRules.bumpItems()
    local ok = false
    pcall(function()
        item:setCount(math.floor(count))
        ok = BridgeGunRules.itemCount(item) <= count
    end)
    if not ok then return BridgeGunRules.removeItem(item) end
    return true
end


function BridgeGunRules.addToBody(body, item)
    if body == nil or item == nil then return false end
    BridgeGunRules.bumpItems()
    local ok = false
    pcall(function() ok = body:getInventory():AddItem(item) ~= nil end)
    return ok
end


function BridgeGunRules.roundsOf(item)
    local rounds = 0
    if item == nil then return 0 end
    pcall(function()
        local n = item:getCurrentAmmoCount()
        if type(n) == "number" and n == n and n > 0 then rounds = math.floor(n) end
    end)
    return rounds
end


function BridgeGunRules.setRounds(item, rounds, containsClip)
    if item == nil then return false end
    BridgeGunRules.bumpItems()
    local n = math.floor(tonumber(rounds) or 0)
    if n < 0 then n = 0 end
    local gun = BridgeGunRules.isGun(item)
    local gs = gunsmith()
    if gs ~= nil and gun then
        local internal = false
        local ok = pcall(function() internal = gs.isInternal(item) == true end)
        if ok and internal then containsClip = false end
    end
    if not gun then
        local cap = 0
        pcall(function() cap = math.floor(tonumber(item:getMaxAmmo()) or 0) end)
        if cap > 0 and n > cap then n = cap end
    end
    local ok = false
    if gun and containsClip == true then
        pcall(function() item:setContainsClip(true) end)
        pcall(function()
            item:setCurrentAmmoCount(n)
            ok = true
        end)
    else
        pcall(function()
            item:setCurrentAmmoCount(n)
            ok = true
        end)
        if gun and containsClip ~= nil then
            pcall(function() item:setContainsClip(containsClip == true) end)
        end
    end
    return ok
end


function BridgeGunRules.loadedRoundType(item)
    if item == nil then return nil end
    local ggsType = ggsLoadedRoundType(item)
    if type(ggsType) == "string" then return ggsType end
    local roundType = nil
    pcall(function()
        local md = item:getModData()
        local list = md and md.AmmoList
        if type(list) == "table" and #list > 0 then
            roundType = list[#list]
        end
    end)
    if type(roundType) ~= "string" then
        roundType = nil
        pcall(function()
            local ammo = item:getAmmoType()
            if ammo ~= nil then roundType = ammo:getItemKey() end
        end)
    end
    return roundType
end


function BridgeGunRules.ammoListOf(item)
    if item == nil then return nil end
    local list = nil
    pcall(function()
        local md = item:getModData()
        local src = md and md.AmmoList
        if type(src) == "table" and #src > 0 then
            list = {}
            for i = 1, #src do list[i] = src[i] end
        end
    end)
    return list
end


function BridgeGunRules.setAmmoList(item, list)
    if item == nil then return end
    pcall(function()
        local md = item:getModData()
        if md == nil then return end
        if type(list) == "table" and #list > 0 then
            local copy = {}
            for i = 1, #list do copy[i] = list[i] end
            md.AmmoList = copy
        else
            md.AmmoList = nil
        end
    end)
end


function BridgeGunRules.applyNextRound(item, desc)
    if item == nil then return false end
    local roundType = BridgeGunRules.loadedRoundType(item)
    if type(roundType) ~= "string" then return false end
    local ammoMod = gunworksAmmo()
    if ammoMod == nil or ammoMod.AmmoProfileSetter == nil then return false end
    local ok = false
    pcall(function()
        ammoMod.AmmoProfileSetter(item, roundType)
        ok = true
    end)
    return ok
end


function BridgeGunRules.setGunAmmoState(weapon, rounds, ammoList, nextType)
    if weapon == nil then return 0 end
    local n = math.max(0, math.floor(tonumber(rounds) or 0))
    BridgeGunRules.setRounds(weapon, n, true)
    BridgeGunRules.setAmmoList(weapon, ammoList)
    local t = nextType
    if type(t) ~= "string" and type(ammoList) == "table" and #ammoList > 0 then
        t = ammoList[#ammoList]
    end
    if type(t) == "string" then
        local ammoMod = gunworksAmmo()
        if ammoMod ~= nil and ammoMod.AmmoProfileSetter ~= nil then
            pcall(function() ammoMod.AmmoProfileSetter(weapon, t) end)
        end
    end
    return n
end


function BridgeGunRules.appendMagazineRound(magazine, bulletType)
    if magazine == nil or type(bulletType) ~= "string" then return false end
    local list = BridgeGunRules.ammoListOf(magazine) or {}
    list[#list + 1] = bulletType
    BridgeGunRules.setAmmoList(magazine, list)
    local ammoMod = gunworksAmmo()
    if ammoMod ~= nil and ammoMod.MagazineAmmoProfileSetter ~= nil then
        pcall(function() ammoMod.MagazineAmmoProfileSetter(magazine, bulletType) end)
    end
    return true
end


function BridgeGunRules.consumeRound(weapon, desc)
    if weapon == nil then return false end
    local rounds = math.max(0, BridgeGunRules.roundsOf(weapon) - 1)
    BridgeGunRules.setRounds(weapon, rounds, true)
    local list = BridgeGunRules.ammoListOf(weapon)
    if type(list) ~= "table" or #list == 0 then
        if type(list) == "table" then BridgeGunRules.setAmmoList(weapon, nil) end
        return true
    end
    list[#list] = nil
    BridgeGunRules.setAmmoList(weapon, list)
    if #list > 0 then
        local ammoMod = gunworksAmmo()
        if ammoMod ~= nil and ammoMod.AmmoProfileSetter ~= nil then
            pcall(function() ammoMod.AmmoProfileSetter(weapon, list[#list]) end)
        end
    end
    return true
end


function BridgeGunRules.refreshStats(desc, gun)
    if type(desc) ~= "table" or gun == nil then return desc end
    local fresh = BridgeGunRules.describe(gun)
    if type(fresh) ~= "table" then return desc end
    local fields = {
        "maxRange", "minRange", "minDamage", "maxDamage", "hitChance", "critChance", "critMult",
        "aimingTime", "recoilDelay", "sound", "hitSound", "impactSound", "soundRadius", "soundVolume",
        "projectileCount", "maxHitCount", "piercingBullets", "projectileSpread", "minAngle", "twoHanded",
        "kind", "maxAmmo", "reloadType", "magazineType", "magazineTypes", "magazineSet",
        "ammoTypeKey", "ammoTypeId", "ammoBox",
        "insertAll", "insertSound", "ejectSound", "insertStartSound", "insertStopSound", "rackSound",
        "ammoFamily", "clipTypes", "clipSet", "hasMagazineProfile", "hasClipProfile", "clipFamily", "external", "reloadFamily",
        "range", "rounds",
    }
    for _, k in ipairs(fields) do desc[k] = fresh[k] end
    local roundType = BridgeGunRules.loadedRoundType(gun)
    if type(roundType) == "string" then
        desc.ammoTypeKey = roundType
        local ammoMod = gunworksAmmo()
        if ammoMod ~= nil then
            pcall(function()
                desc.ammoTypeId = ammoMod.GetEnumForBullet(roundType)
                local _, family = ammoMod.FindBulletEntry(roundType)
                if family ~= nil then desc.ammoFamily = family end
            end)
        end
    end
    return desc
end


function BridgeGunRules.isMagazineType(desc, fullType)
    if type(desc) ~= "table" or type(fullType) ~= "string" then return false end
    if desc.magazineType ~= nil and fullType == desc.magazineType then return true end
    local set = desc.magazineSet
    return type(set) == "table" and set[fullType] == true
end


function BridgeGunRules.findLoadedMagazine(body, desc, items)
    if body == nil or type(desc) ~= "table" then return nil, 0 end
    if desc.hasMagazineProfile ~= true then BridgeGunRules.refreshMagazineProfile(desc) end
    if desc.magazineType == nil and desc.hasClipProfile ~= true then return nil, 0 end
    local best, bestCount = nil, 0
    for _, item in ipairs(items or BridgeGunRules.itemsOf(body)) do
        local full = nil
        pcall(function() full = item:getFullType() end)
        if BridgeGunRules.isMagazineType(desc, full) then
            local n = BridgeGunRules.roundsOf(item)
            if n > bestCount then best, bestCount = item, n end
        end
    end
    if bestCount <= 0 then return nil, 0 end
    return best, bestCount
end


function BridgeGunRules.refreshMagazineProfile(desc)
    if type(desc) ~= "table" then return false end
    if desc.hasMagazineProfile == true then return true end
    local now = 0
    if Bridge ~= nil then now = tonumber(Bridge.time) or 0 end
    if now > 0 and desc.magCheckedAt ~= nil and now - desc.magCheckedAt < 300 then
        return desc.hasMagazineProfile == true
    end
    desc.magCheckedAt = now
    desc.magazineTypes = desc.magazineTypes or {}
    desc.magazineSet = desc.magazineSet or {}
    desc.clipTypes = desc.clipTypes or {}
    desc.clipSet = desc.clipSet or {}
    local function addMag(t)
        if type(t) ~= "string" or t == "" or desc.magazineSet[t] then return end
        desc.magazineSet[t] = true
        desc.magazineTypes[#desc.magazineTypes + 1] = t
    end
    addMag(desc.magazineType)
    local ggsItem = nil
    pcall(function() ggsItem = instanceItem(desc.fullType) end)
    ggsEnrichDesc(desc, ggsItem)
    local speedMod = gunworksSpeedLoader()
    if speedMod ~= nil and type(desc.fullType) == "string" then
        local gunItem = nil
        pcall(function() gunItem = instanceItem(desc.fullType) end)
        if gunItem ~= nil then
            local list = nil
            pcall(function() list = speedMod.GetSpeedLoaderTypesForGun(gunItem) end)
            if type(list) == "table" then
                for _, t in ipairs(list) do
                    if type(t) == "string" and t ~= "" then
                        if not desc.clipSet[t] then
                            desc.clipSet[t] = true
                            desc.clipTypes[#desc.clipTypes + 1] = t
                        end
                        addMag(t)
                    end
                end
            end
        end
    end
    local gs = gunsmith()
    if gs ~= nil and type(desc.fullType) == "string" then
        local ok = pcall(function()
            local gunItem = instanceItem(desc.fullType)
            if gunItem ~= nil then
                local list = gs.magazineTypes(gunItem)
                if type(list) == "table" then
                    for _, t in ipairs(list) do addMag(t) end
                end
            end
        end)
        if not ok then diag("gunsmith-magprofile", "Gunsmith magazine profile hook failed") end
    end
    desc.hasMagazineProfile = #desc.magazineTypes > 0
    desc.hasClipProfile = #desc.clipTypes > 0
    desc.external = desc.hasMagazineProfile
    if desc.gunsmith == true then desc.reloadFamily = BridgeGunRules.familyOf(desc) end
    desc.clipFamily = (desc.reloadFamily == "revolver") and "revolver" or "rifle"
    return desc.hasMagazineProfile == true
end


function BridgeGunRules.magazineCount(body, desc)
    local total, loaded = 0, 0
    if body == nil or type(desc) ~= "table" then return 0, 0 end
    if desc.hasMagazineProfile ~= true then BridgeGunRules.refreshMagazineProfile(desc) end
    if desc.magazineType == nil and desc.hasClipProfile ~= true then return 0, 0 end
    for _, item in ipairs(BridgeGunRules.itemsOf(body)) do
        local full = nil
        pcall(function() full = item:getFullType() end)
        if BridgeGunRules.isMagazineType(desc, full) then
            total = total + 1
            if BridgeGunRules.roundsOf(item) > 0 then loaded = loaded + 1 end
        end
    end
    return total, loaded
end


function BridgeGunRules.findLooseRounds(body, desc, need, items, owner)
    local out, total = {}, 0
    if body == nil or type(desc) ~= "table" then return out, total end
    local want = math.floor(tonumber(need) or 1)
    local types = BridgeGunRules.ammoTypesFor(desc, owner)
    if #types == 0 then return out, total end
    local rank = {}
    for i, t in ipairs(types) do rank[t] = i end
    local byType = {}
    for _, item in ipairs(items or BridgeGunRules.itemsOf(body)) do
        local full = nil
        pcall(function() full = item:getFullType() end)
        if type(full) == "string" and rank[full] ~= nil then
            local n = BridgeGunRules.itemCount(item)
            if n > 0 then
                byType[full] = byType[full] or {}
                byType[full][#byType[full] + 1] = { item = item, count = n, type = full }
            end
        end
    end
    for _, t in ipairs(types) do
        if total >= want then break end
        local entries = byType[t]
        if entries ~= nil then
            for _, entry in ipairs(entries) do
                if total >= want then break end
                out[#out + 1] = entry
                total = total + entry.count
            end
        end
    end
    return out, total
end


function BridgeGunRules.removeOneLooseRound(body, desc, items, owner)
    if body == nil or type(desc) ~= "table" then return nil end
    local types = BridgeGunRules.ammoTypesFor(desc, owner)
    for _, key in ipairs(types) do
        local removed = nil
        pcall(function() removed = body:getInventory():RemoveOneOf(key, true) end)
        if removed ~= nil then return removed end
        for _, bagItem in ipairs(wornItems(body)) do
            if removed ~= nil then break end
            if bagItem:IsInventoryContainer() then
                local bag = nil
                pcall(function() bag = bagItem:getInventory() end)
                if bag ~= nil then
                    pcall(function() removed = bag:RemoveOneOf(key, true) end)
                end
            end
        end
        if removed ~= nil then return removed end
    end
    return nil
end


function BridgeGunRules.canSync(container)
    if container == nil then return false end
    local client = false
    pcall(function() client = isClient() == true end)
    if client then return false end
    local ok = false
    pcall(function()
        local parent = container:getParent()
        if parent == nil then return end
        local square = nil
        pcall(function() square = parent:getSquare() end)
        ok = square ~= nil
    end)
    return ok
end


function BridgeGunRules.removeItemById(body, id)
    if body == nil or id == nil then return nil end
    local item = BridgeGunRules.findItemById(body, id)
    if item == nil then return nil end
    local container = nil
    pcall(function() container = item:getContainer() end)
    if container == nil then return nil end
    local count = BridgeGunRules.itemCount(item)
    if count > 1 then
        BridgeGunRules.setItemCount(item, count - 1)
        if BridgeGunRules.canSync(container) then
            pcall(function() sendItemStats(item) end)
        end
    else
        container:Remove(item)
        if BridgeGunRules.canSync(container) then
            pcall(function() sendRemoveItemFromContainer(container, item) end)
        end
    end
    return item
end


function BridgeGunRules.takeLooseRounds(body, desc, need, owner)
    local want = math.floor(tonumber(need) or 0)
    if want <= 0 then return 0 end
    local rounds, taken = BridgeGunRules.findLooseRounds(body, desc, want, nil, owner)
    local done = 0
    for _, entry in ipairs(rounds) do
        if done >= want then break end
        local n = math.min(entry.count, want - done)
        local container = nil
        pcall(function() container = entry.item:getContainer() end)
        local sync = BridgeGunRules.canSync(container)
        if n >= entry.count then
            BridgeGunRules.removeItem(entry.item)
            if sync then
                pcall(function() sendRemoveItemFromContainer(container, entry.item) end)
            end
        else
            BridgeGunRules.setItemCount(entry.item, entry.count - n)
            if sync then
                pcall(function() sendItemStats(entry.item) end)
            end
        end
        done = done + n
    end
    return done
end


function BridgeGunRules.findEmptyMagazine(body, desc)
    if body == nil or type(desc) ~= "table" or desc.magazineType == nil then return nil end
    for _, item in ipairs(BridgeGunRules.itemsOf(body)) do
        local full, rounds = nil, 0
        pcall(function() full = item:getFullType() end)
        if BridgeGunRules.isMagazineType(desc, full) then
            rounds = BridgeGunRules.roundsOf(item)
            if rounds <= 0 then return item end
        end
    end
    return nil
end


function BridgeGunRules.findPartialMagazine(body, desc, items)
    if body == nil or type(desc) ~= "table" then return nil end
    if desc.hasMagazineProfile ~= true then BridgeGunRules.refreshMagazineProfile(desc) end
    if desc.magazineType == nil and desc.hasClipProfile ~= true then return nil end
    local gunMax = tonumber(desc.maxAmmo) or 0
    local best, bestRounds = nil, nil
    for _, item in ipairs(items or BridgeGunRules.itemsOf(body)) do
        local full = nil
        pcall(function() full = item:getFullType() end)
        if BridgeGunRules.isMagazineType(desc, full) then
            local rounds = BridgeGunRules.roundsOf(item)
            local cap = 0
            pcall(function() cap = math.floor(tonumber(item:getMaxAmmo()) or 0) end)
            if cap <= 0 then cap = gunMax end
            if (cap <= 0 or rounds < cap) and (best == nil or rounds > bestRounds) then
                best, bestRounds = item, rounds
            end
        end
    end
    return best
end


local function applyMagazineAmmo(magazine, ammoList)
    if magazine == nil or type(ammoList) ~= "table" or #ammoList == 0 then return end
    BridgeGunRules.setAmmoList(magazine, ammoList)
    local roundType = ammoList[#ammoList]
    local ammoMod = gunworksAmmo()
    if ammoMod ~= nil and ammoMod.MagazineAmmoProfileSetter ~= nil and type(roundType) == "string" then
        pcall(function() ammoMod.MagazineAmmoProfileSetter(magazine, roundType) end)
    end
end


function BridgeGunRules.makeEmptyMagazine(body, desc, prefer, ammoList)
    if type(desc) ~= "table" or desc.magazineType == nil then return nil end
    local magazine = nil
    pcall(function() magazine = instanceItem(desc.magazineType) end)
    if magazine == nil then return nil end
    BridgeGunRules.setRounds(magazine, 0, false)
    applyMagazineAmmo(magazine, ammoList)
    if not BridgeGunRules.placeItem(body, magazine, prefer) then return nil end
    return magazine
end


function BridgeGunRules.unloadMagazine(body, desc)
    local magazine = BridgeGunRules.makeEmptyMagazine(body, desc)
    if magazine ~= nil then BridgeGunRules.setRounds(magazine, 0, false) end
    return magazine
end


function BridgeGunRules.stashMagazine(body, desc, rounds, prefer, ammoList, weapon)
    local n = math.max(0, math.floor(tonumber(rounds) or 0))
    if n <= 0 then return BridgeGunRules.makeEmptyMagazine(body, desc, prefer, ammoList) end
    if type(desc) ~= "table" or desc.magazineType == nil then return nil end
    local magazine = nil
    pcall(function() magazine = instanceItem(desc.magazineType) end)
    if magazine == nil then return nil end
    BridgeGunRules.setRounds(magazine, n, false)
    applyMagazineAmmo(magazine, ammoList)
    ggsCopyWeaponQueue(weapon, magazine)
    if not BridgeGunRules.placeItem(body, magazine, prefer) then return nil end
    return magazine
end


function BridgeGunRules.ejectMagazine(body, desc, rounds, prefer, ammoList, weapon)
    if body == nil or type(desc) ~= "table" or desc.magazineType == nil then return nil end
    local n = math.max(0, math.floor(tonumber(rounds) or 0))
    local magazine = nil
    pcall(function() magazine = instanceItem(desc.magazineType) end)
    if magazine == nil then return nil end
    BridgeGunRules.setRounds(magazine, n, false)
    applyMagazineAmmo(magazine, ammoList)
    ggsCopyWeaponQueue(weapon, magazine)
    if not BridgeGunRules.placeItem(body, magazine, prefer) then return nil end
    return magazine
end


function BridgeGunRules.insertMagazine(body, weapon, magazine, desc)
    if weapon == nil or magazine == nil then return 0 end
    local gs = gunsmith()
    if gs ~= nil then
        local inserted = false
        local ok = pcall(function() inserted = gs.insertMagazine(body, weapon, magazine, desc) == true end)
        if ok and inserted then return BridgeGunRules.roundsOf(weapon) end
        if not ok then diag("gunsmith-insertmag", "Gunsmith insert magazine hook failed") end
    end
    local full = nil
    pcall(function() full = magazine:getFullType() end)
    local isClip = type(desc) == "table" and type(desc.clipSet) == "table"
        and full ~= nil and desc.clipSet[full] == true
    local rounds = BridgeGunRules.roundsOf(magazine)
    if isClip then
        if rounds <= 0 then return 0 end
        local cap = 0
        pcall(function() cap = math.floor(tonumber(weapon:getMaxAmmo()) or 0) end)
        if cap > 0 and rounds > cap then rounds = cap end
        local list = BridgeGunRules.ammoListOf(magazine)
        if type(list) ~= "table" or #list == 0 then
            local fallback = nil
            pcall(function()
                local ammo = magazine:getAmmoType()
                if ammo ~= nil then fallback = ammo:getItemKey() end
            end)
            list = {}
            if type(fallback) == "string" then
                for _ = 1, rounds do list[#list + 1] = fallback end
            end
        end
        if #list > rounds then
            for i = #list, rounds + 1, -1 do list[i] = nil end
        end
        ggsCopyQueue(magazine, weapon)
        BridgeGunRules.setGunAmmoState(weapon, rounds, list, list[#list])
        ggsSyncCount(weapon)
        pcall(function() weapon:setContainsClip(true) end)
        BridgeGunRules.setRounds(magazine, 0, false)
        BridgeGunRules.setAmmoList(magazine, nil)
        ggsClearQueue(magazine)
        return rounds
    end
    local magList = BridgeGunRules.ammoListOf(magazine)
    local magType = nil
    pcall(function()
        local ammo = magazine:getAmmoType()
        if ammo ~= nil then magType = ammo:getItemKey() end
    end)
    local gunList = nil
    if type(magList) == "table" and #magList > 0 then
        gunList = {}
        for i = 1, #magList do gunList[i] = magList[i] end
        pcall(function()
            local md = weapon:getModData()
            local current = md and md.AmmoList
            if weapon:isRoundChambered() and type(current) == "table" and #current > 0 then
                gunList[#gunList + 1] = current[#current]
            end
        end)
    end
    ggsCopyQueue(magazine, weapon)
    BridgeGunRules.removeItem(magazine)
    local nextType = magType
    if type(gunList) == "table" and #gunList > 0 then nextType = gunList[#gunList] end
    BridgeGunRules.setGunAmmoState(weapon, rounds, gunList, nextType)
    ggsSyncCount(weapon)
    return rounds
end


function BridgeGunRules.hasReloadSource(body, desc, items)
    if body == nil or type(desc) ~= "table" then return false end
    if desc.hasMagazineProfile ~= true then BridgeGunRules.refreshMagazineProfile(desc) end
    if desc.magazineType ~= nil or desc.hasClipProfile == true then
        return BridgeGunRules.findLoadedMagazine(body, desc, items) ~= nil
    end
    local _, total = BridgeGunRules.findLooseRounds(body, desc, 1, items)
    return total > 0
end


BridgeGunRules.unpackCache = BridgeGunRules.unpackCache or {}
BridgeGunRules.unpackRecipeIndex = nil

local function safeMethod(obj, name)
    if obj == nil then return nil end
    local fn = nil
    pcall(function() fn = obj[name] end)
    if type(fn) == "function" then return fn end
    return nil
end

local function safeCall(obj, name, arg)
    local fn = safeMethod(obj, name)
    if fn == nil then return nil end
    local value = nil
    if arg == nil then
        pcall(function() value = fn(obj) end)
    else
        pcall(function() value = fn(obj, arg) end)
    end
    return value
end

local function safeList(list)
    local sizeFn = safeMethod(list, "size")
    local getFn = safeMethod(list, "get")
    if sizeFn == nil or getFn == nil then return nil, nil, 0 end
    local count = 0
    pcall(function() count = sizeFn(list) end)
    return sizeFn, getFn, tonumber(count) or 0
end

local function itemTypeOf(entry)
    if entry == nil then return nil end
    local full = safeCall(entry, "getFullType")
    if type(full) == "string" and full ~= "" then return full end
    full = safeCall(entry, "getFullName")
    if type(full) == "string" and full ~= "" then
        if string.find(full, ".", 1, true) == nil then
            local module = safeCall(entry, "getModuleName")
            if type(module) == "string" and module ~= "" then
                full = module .. "." .. full
            end
        end
        return full
    end
    full = safeCall(entry, "getItemKey")
    if type(full) == "string" and full ~= "" then return full end
    return nil
end

local function unpackUp(fullType)
    if type(fullType) ~= "string" then return nil end
    local module, name = string.match(fullType, "^([^%.]+)%.(.+)$")
    if name == nil then module, name = "Base", fullType end
    local up = nil
    if string.find(name, "Crate", 1, true) then
        up = string.gsub(name, "Crate", "Carton")
    elseif string.find(name, "Carton", 1, true) then
        up = string.gsub(name, "Carton", "Box")
    end
    if up == nil or up == name then return nil end
    local target = module .. "." .. up
    if not itemExists(target) then return nil end
    return target
end
BridgeGunRules.unpackUp = unpackUp


local function typeIsAmmo(fullType)
    local yes = false
    if type(fullType) ~= "string" or not itemExists(fullType) then return false end
    pcall(function()
        local inst = instanceItem(fullType)
        if inst == nil or ItemTag == nil or ItemTag.AMMO == nil then return end
        yes = inst:hasTag(ItemTag.AMMO) == true
    end)
    return yes
end


local function typeMaxAmmo(fullType)
    local cap = 0
    if type(fullType) ~= "string" or not itemExists(fullType) then return 0 end
    pcall(function()
        local inst = instanceItem(fullType)
        if inst ~= nil then cap = tonumber(inst:getMaxAmmo()) or 0 end
    end)
    return cap
end


local function buildUnpackRecipeIndex()
    local index = {}
    pcall(function()
        local manager = getScriptManager()
        if manager == nil then return end
        local recipes = safeCall(manager, "getAllCraftRecipes")
        local _, recipeGet, recipeCount = safeList(recipes)
        if recipeGet == nil then return end
        local itemRes = nil
        pcall(function() itemRes = ResourceType.Item end)
        if itemRes == nil then return end
        for i = 0, recipeCount - 1 do
            local recipe = nil
            pcall(function() recipe = recipeGet(recipes, i) end)
            if recipe ~= nil then
                local inputs = safeCall(recipe, "getInputs")
                local _, inputGet, inputCount = safeList(inputs)
                local input, itemInputs = nil, 0
                if inputGet ~= nil then
                    for k = 0, inputCount - 1 do
                        local candidate = nil
                        pcall(function() candidate = inputGet(inputs, k) end)
                        if candidate ~= nil and safeCall(candidate, "getResourceType") == itemRes then
                            itemInputs = itemInputs + 1
                            input = candidate
                        end
                    end
                end
                if input ~= nil and itemInputs == 1
                    and tonumber(safeCall(input, "getIntAmount")) == 1
                    and not flag(function() return input:isTool() end)
                    and not flag(function() return input:isKeep() end)
                    and not flag(function() return input:isAutomationOnly() end) then
                    local outs = safeCall(recipe, "getOutputs")
                    local _, outputGet, outputCount = safeList(outs)
                    local hasOutput = false
                    if outputGet ~= nil then
                        for j = 0, outputCount - 1 do
                            local out = nil
                            pcall(function() out = outputGet(outs, j) end)
                            if out ~= nil and safeCall(out, "getResourceType") == itemRes
                                and (tonumber(safeCall(out, "getIntAmount")) or 0) > 0 then
                                hasOutput = true
                                break
                            end
                        end
                    end
                    if hasOutput then
                        local candidates = safeCall(input, "getPossibleInputItems")
                        local _, candidateGet, candidateCount = safeList(candidates)
                        if candidateGet ~= nil and candidateCount > 0 then
                            for j = 0, candidateCount - 1 do
                                local entry = nil
                                pcall(function() entry = candidateGet(candidates, j) end)
                                local full = itemTypeOf(entry)
                                if full ~= nil then
                                    local bucket = index[full]
                                    if bucket == nil then
                                        bucket = {}
                                        index[full] = bucket
                                    end
                                    bucket[#bucket + 1] = recipe
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    return index
end


local function recipeIndex()
    if BridgeGunRules.unpackRecipeIndex == nil then
        BridgeGunRules.unpackRecipeIndex = buildUnpackRecipeIndex()
    end
    return BridgeGunRules.unpackRecipeIndex
end


local function recipeAcceptsOut(recipe, expectedOut)
    local accepted = false
    pcall(function()
        local outs = safeCall(recipe, "getOutputs")
        local _, outputGet, outputCount = safeList(outs)
        if outputGet == nil then return end
        local itemRes = nil
        pcall(function() itemRes = ResourceType.Item end)
        if itemRes == nil then return end
        for i = 0, outputCount - 1 do
            local out = nil
            pcall(function() out = outputGet(outs, i) end)
            if out ~= nil and safeCall(out, "getResourceType") == itemRes then
                local candidates = safeCall(out, "getPossibleResultItems")
                local _, candidateGet, candidateCount = safeList(candidates)
                if candidateGet ~= nil then
                    for j = 0, candidateCount - 1 do
                        local entry = nil
                        pcall(function() entry = candidateGet(candidates, j) end)
                        local full = itemTypeOf(entry)
                        if full ~= nil and (full == expectedOut or typeIsAmmo(full)) then
                            accepted = true
                            return
                        end
                    end
                end
            end
        end
    end)
    return accepted
end


local function findUnpackRecipe(itemType)
    if type(itemType) ~= "string" or itemType == "" then return nil end
    if typeIsAmmo(itemType) then return nil end
    if typeMaxAmmo(itemType) > 0 then return nil end
    local expectedOut = unpackUp(itemType)
    local bucket = recipeIndex()[itemType]
    if type(bucket) ~= "table" then return nil end
    for _, recipe in ipairs(bucket) do
        if recipe ~= nil and recipeAcceptsOut(recipe, expectedOut) then return recipe end
    end
    return nil
end


local function nameMappedOutput(itemType, types)
    local module, bare = string.match(itemType, "^(.-)%.([^%.]+)$")
    if module == nil or bare == nil then return nil end
    local candidates = {}
    if string.find(bare, "Carton", 1, true) ~= nil then
        candidates[#candidates + 1] = string.gsub(bare, "Carton", "Box", 1)
    elseif string.find(bare, "Box", 1, true) ~= nil then
        candidates[#candidates + 1] = string.gsub(bare, "Box", "Bullet", 1)
        candidates[#candidates + 1] = string.gsub(bare, "Box", "Bullets", 1)
        candidates[#candidates + 1] = string.gsub(bare, "Box", "Shell", 1)
        candidates[#candidates + 1] = string.gsub(bare, "Box", "Shells", 1)
    end
    local set = {}
    for _, t in ipairs(types) do set[t] = true end
    local found, count = nil, 0
    local seen = {}
    local modules = { module, "SWMG", "MarzGuns", "GunsOfTien", "GunsOfTienPost93", "Base" }
    for _, name in ipairs(candidates) do
        for _, m in ipairs(modules) do
            local full = m .. "." .. name
            if full ~= itemType and set[full] == true and not seen[full] then
                seen[full] = true
                found = full
                count = count + 1
            end
        end
    end
    if count == 1 then return found end
    return nil
end


local function exactUnpackOutput(recipe, itemType, types, itemRes)
    local unionSet = {}
    for _, t in ipairs(types) do unionSet[t] = true end
    local named = nameMappedOutput(itemType, types)
    if named ~= nil and unionSet[named] == true then return named end
    local exact = nil
    local inputIndex, inputCount = nil, 0
    local inputs = safeCall(recipe, "getInputs")
    local _, inputGet, inCount = safeList(inputs)
    if inputGet ~= nil then
        for i = 0, inCount - 1 do
            local input = nil
            pcall(function() input = inputGet(inputs, i) end)
            if input ~= nil and safeCall(input, "getResourceType") == itemRes then
                local candidates = safeCall(input, "getPossibleInputItems")
                local _, candGet, candCount = safeList(candidates)
                if candGet ~= nil then
                    local found, total = nil, 0
                    for j = 0, candCount - 1 do
                        local entry = nil
                        pcall(function() entry = candGet(candidates, j) end)
                        local full = itemTypeOf(entry)
                        if full ~= nil then
                            total = total + 1
                            if full == itemType then found = j end
                        end
                    end
                    if found ~= nil then
                        inputIndex, inputCount = found, total
                        break
                    end
                end
            end
        end
    end
    local outs = safeCall(recipe, "getOutputs")
    local _, outGet, outCount = safeList(outs)
    if outGet == nil then return nil end
    for i = 0, outCount - 1 do
        local out = nil
        pcall(function() out = outGet(outs, i) end)
        if out ~= nil and safeCall(out, "getResourceType") == itemRes
            and (tonumber(safeCall(out, "getIntAmount")) or 0) > 0 then
            local candidates = safeCall(out, "getPossibleResultItems")
            local _, candGet, candCount = safeList(candidates)
            if candGet ~= nil then
                if inputIndex ~= nil and candCount == inputCount and inputIndex < candCount then
                    local entry = nil
                    pcall(function() entry = candGet(candidates, inputIndex) end)
                    exact = itemTypeOf(entry)
                    if exact ~= nil then return exact end
                end
                if exact == nil and candCount == 1 then
                    local entry = nil
                    pcall(function() entry = candGet(candidates, 0) end)
                    exact = itemTypeOf(entry)
                    if exact ~= nil then return exact end
                end
            end
        end
    end
    return nameMappedOutput(itemType, types)
end


function BridgeGunRules.unpackOf(itemType)
    if type(itemType) ~= "string" then return nil end
    local hit = BridgeGunRules.unpackCache[itemType]
    if hit ~= nil then return hit or nil end
    local spec = false
    pcall(function()
        local manager = getScriptManager()
        if manager == nil then return end
        if not itemExists(itemType) then return end
        local inst = instanceItem(itemType)
        local recipeName = safeCall(inst, "getDoubleClickRecipe")
        if type(recipeName) ~= "string" or recipeName == "" then recipeName = nil end
        local recipe = nil
        if recipeName ~= nil then
            recipe = safeCall(manager, "getCraftRecipe", recipeName)
        end
        if recipe == nil then
            recipe = findUnpackRecipe(itemType)
            if recipe ~= nil then
                recipeName = safeCall(recipe, "getOriginalname")
                if type(recipeName) ~= "string" or recipeName == "" then
                    recipeName = safeCall(recipe, "getName")
                end
            end
        end
        local outs = safeCall(recipe, "getOutputs")
        local _, outGet, outCount = safeList(outs)
        local itemRes = nil
        pcall(function() itemRes = ResourceType.Item end)
        if outGet == nil or itemRes == nil then return end
        for i = 0, outCount - 1 do
            local out = nil
            pcall(function() out = outGet(outs, i) end)
            if out ~= nil and safeCall(out, "getResourceType") == itemRes then
                local amount = math.floor(tonumber(safeCall(out, "getIntAmount")) or 0)
                local types = {}
                local candidates = safeCall(out, "getPossibleResultItems")
                local _, candGet, candCount = safeList(candidates)
                if candGet ~= nil then
                    for j = 0, candCount - 1 do
                        local entry = nil
                        pcall(function() entry = candGet(candidates, j) end)
                        local full = itemTypeOf(entry)
                        if full ~= nil then types[#types + 1] = full end
                    end
                end
                local up = unpackUp(itemType)
                if up ~= nil then
                    local found = false
                    for _, t in ipairs(types) do
                        if t == up then found = true break end
                    end
                    if not found then types[#types + 1] = up end
                end
                if amount > 0 then
                    local ticks = 75
                    local t = tonumber(safeCall(recipe, "getTime"))
                    if t ~= nil then ticks = math.max(15, math.floor(t * 5)) end
                    local exactOut = exactUnpackOutput(recipe, itemType, types, itemRes)
                    spec = { out = types, exactOut = exactOut, amount = amount, ticks = ticks, recipe = recipeName }
                    break
                end
            end
        end
    end)
    BridgeGunRules.unpackCache[itemType] = spec
    return spec or nil
end


function BridgeGunRules.cartonBreakdown(itemType)
    local spec = BridgeGunRules.unpackOf(itemType)
    if spec == nil then return nil, "no recipe", spec end
    local amount = math.floor(tonumber(spec.amount) or 0)
    if amount <= 1 then return nil, "amount " .. tostring(amount), spec end
    local out = spec.exactOut
    if out == nil and type(spec.out) == "table" and #spec.out == 1 then out = spec.out[1] end
    if out == nil then return nil, "ambiguous mapping", spec end
    local expected = unpackUp(itemType)
    if expected == nil then return nil, "no box type", spec end
    if out ~= expected then return nil, "output mismatch", spec end
    return { out = out, amount = amount, ticks = spec.ticks }, nil, spec
end


function BridgeGunRules.unpackPick(itemType, want, level)
    level = level or 1
    if level > 3 then return nil end
    local spec = BridgeGunRules.unpackOf(itemType)
    if spec == nil then return nil end
    local exact = spec.exactOut
    if exact == nil and type(spec.out) == "table" and #spec.out == 1 then exact = spec.out[1] end
    if exact ~= nil and exact == want then
        return { type = exact, amount = spec.amount, ticks = spec.ticks, depth = 1 }
    end
    return nil
end


function BridgeGunRules.ammoAccept(desc)
    local out = { rounds = {}, boxes = {}, cartons = {} }
    if type(desc) ~= "table" then return out end
    local seenRound = {}
    local function addRound(t)
        if type(t) ~= "string" or t == "" or seenRound[t] then return end
        seenRound[t] = true
        out.rounds[#out.rounds + 1] = t
    end
    for _, t in ipairs(BridgeGunRules.ammoTypesFor(desc)) do addRound(t) end
    addRound(desc.ammoTypeKey)
    local seenBox = {}
    local function addBox(t)
        if type(t) ~= "string" or t == "" or seenBox[t] then return end
        seenBox[t] = true
        out.boxes[#out.boxes + 1] = t
    end
    for _, roundType in ipairs(out.rounds) do
        if roundType == desc.ammoTypeKey then addBox(desc.ammoBox) end
        for _, boxType in ipairs(BridgeGunRules.boxTypesFor(roundType, desc)) do
            if itemExists(boxType) then addBox(boxType) end
        end
    end
    if #out.boxes == 0 then return out end
    local all = nil
    pcall(function()
        all = getAllItems()
        if all == nil then
            local manager = getScriptManager()
            if manager ~= nil then all = manager:getAllItems() end
        end
    end)
    if all == nil then return out end
    local seenCarton = {}
    pcall(function()
        for i = 0, all:size() - 1 do
            local script = all:get(i)
            local full = nil
            pcall(function() full = script:getFullName() end)
            if type(full) == "string" and not seenCarton[full]
                and string.find(full, "Carton", 1, true) ~= nil then
                local up = unpackUp(full)
                local hit = up ~= nil and seenBox[up] == true
                if not hit and up ~= nil then
                    local up2 = unpackUp(up)
                    hit = up2 ~= nil and seenBox[up2] == true
                end
                if hit then
                    seenCarton[full] = true
                    out.cartons[#out.cartons + 1] = full
                end
            end
        end
    end)
    table.sort(out.cartons)
    return out
end


function BridgeGunRules.exactOutput(spec)
    if type(spec) ~= "table" then return nil end
    if type(spec.exactOut) == "string" then return spec.exactOut end
    if type(spec.out) == "table" and #spec.out == 1 then return spec.out[1] end
    return nil
end


local function boxNameCandidates(roundType)
    local module, bare = string.match(roundType, "^(.-)%.([^%.]+)$")
    if module == nil or bare == nil then return {} end
    local out, seen = {}, {}
    local function add(name)
        if type(name) ~= "string" or name == "" then return end
        local full = module .. "." .. name
        if not seen[full] then
            seen[full] = true
            out[#out + 1] = full
        end
    end
    add(bare .. "Box")
    add(bare .. "_Box")
    local mapped = string.gsub(bare, "Bullets", "Box", 1)
    if mapped ~= bare then add(mapped) end
    mapped = string.gsub(bare, "Shells", "Box", 1)
    if mapped ~= bare then add(mapped) end
    mapped = string.gsub(bare, "Bullet", "Box", 1)
    if mapped ~= bare then add(mapped) end
    mapped = string.gsub(bare, "Shell", "Box", 1)
    if mapped ~= bare then add(mapped) end
    mapped = string.gsub(bare, "_Bullet", "_Box", 1)
    if mapped ~= bare then add(mapped) end
    mapped = string.gsub(bare, "_Shell", "_Box", 1)
    if mapped ~= bare then add(mapped) end
    mapped = string.gsub(bare, "_?Bullets?", "", 1)
    if mapped ~= bare then add(mapped .. "Box") end
    mapped = string.gsub(bare, "_?Shells?", "", 1)
    if mapped ~= bare then add(mapped .. "Box") end
    return out
end


local function boxCandidatesFor(roundType, gun)
    local out, seen = {}, {}
    local function add(full)
        if type(full) ~= "string" or full == "" or seen[full] then return end
        seen[full] = true
        out[#out + 1] = full
    end
    for _, full in ipairs(boxNameCandidates(roundType)) do
        add(full)
        local bareName = string.match(full, "%.([^%.]+)$") or full
        local resolved = resolveItemType(bareName, moduleOf(gun.fullType), moduleOf(roundType), "MarzGuns", "Base")
        if resolved ~= nil then add(resolved) end
    end
    local bare = string.match(roundType, "%.([^%.]+)$")
    if bare ~= nil then
        local resolved = resolveItemType(bare .. "Box", moduleOf(gun.fullType), moduleOf(roundType), "MarzGuns", "Base")
        if resolved ~= nil then add(resolved) end
    end
    return out
end


function BridgeGunRules.boxTypesFor(roundType, gun)
    if type(roundType) ~= "string" or type(gun) ~= "table" then return {} end
    local out = boxCandidatesFor(roundType, gun)
    local gs = gunsmith()
    if gs ~= nil then
        local extra = nil
        local ok = pcall(function() extra = gs.boxTypes(roundType, gun) end)
        if ok and type(extra) == "table" then
            local seen = {}
            for _, t in ipairs(out) do seen[t] = true end
            for _, t in ipairs(extra) do
                if type(t) == "string" and t ~= "" and seen[t] ~= true then
                    seen[t] = true
                    out[#out + 1] = t
                end
            end
        elseif not ok then
            diag("gunsmith-boxtypes", "Gunsmith box hook failed")
        end
    end
    return out
end


local function cartonCandidatesFor(boxType)
    local module, bare = string.match(boxType, "^(.-)%.([^%.]+)$")
    if module == nil or bare == nil then return {} end
    local out, seen = {}, {}
    local function add(name)
        if type(name) ~= "string" or name == "" then return end
        local full = module .. "." .. name
        if not seen[full] then
            seen[full] = true
            out[#out + 1] = full
        end
    end
    if string.find(bare, "Box", 1, true) ~= nil then
        add(string.gsub(bare, "Box", "Carton", 1))
    end
    return out
end


function BridgeGunRules.findAmmoBox(body, gun, items, owner)
    if body == nil or type(gun) ~= "table" then return nil end
    local types = BridgeGunRules.ammoTypesFor(gun, owner)
    if #types == 0 then return nil end
    local wantedKey = tostring(owner) .. "|" .. tostring(#types) .. "|"
        .. (gunworksAmmo() ~= nil and "1" or "0") .. (gunsmith() ~= nil and "1" or "0")
    local wantedMemo = gun._ammoWantedCache
    local wanted
    if type(wantedMemo) == "table" and wantedMemo.key == wantedKey then
        wanted = wantedMemo.wanted
    else
        wanted = {}
        local function addWanted(full, out, rank, depth)
            if type(full) ~= "string" then return end
            local old = wanted[full]
            if old == nil or rank < old.rank or (rank == old.rank and depth < old.depth) then
                wanted[full] = { out = out, rank = rank, depth = depth }
            end
        end
        local fastBox = gun.ammoBox
        if type(fastBox) == "string" then
            local spec = BridgeGunRules.unpackOf(fastBox)
            if BridgeGunRules.exactOutput(spec) == types[1] then
                addWanted(fastBox, types[1], 0, 1)
            end
        end
        for i, roundType in ipairs(types) do
            for _, boxType in ipairs(BridgeGunRules.boxTypesFor(roundType, gun)) do
                local spec = BridgeGunRules.unpackOf(boxType)
                if BridgeGunRules.exactOutput(spec) == roundType then
                    addWanted(boxType, roundType, i, 1)
                    for _, cartonType in ipairs(cartonCandidatesFor(boxType)) do
                        local resolved = resolveItemType(cartonType, moduleOf(boxType), moduleOf(roundType), "Base")
                        if resolved ~= nil then
                            local bd = BridgeGunRules.cartonBreakdown(resolved)
                            if bd ~= nil and bd.out == boxType then
                                addWanted(resolved, boxType, i, 2)
                            end
                        end
                    end
                end
            end
        end
        gun._ammoWantedCache = { key = wantedKey, wanted = wanted }
    end
    local best, bestRank, bestDepth = nil, nil, nil
    for _, item in ipairs(items or BridgeGunRules.itemsOf(body)) do
        local full = nil
        pcall(function() full = item:getFullType() end)
        local w = wanted[full]
        if w ~= nil then
            local better = best == nil or w.rank < bestRank
                or (w.rank == bestRank and w.depth < bestDepth)
            if better then
                local spec = BridgeGunRules.unpackOf(full)
                if spec ~= nil then
                    best = { item = item, type = full, out = w.out, amount = spec.amount, ticks = spec.ticks }
                    bestRank, bestDepth = w.rank, w.depth
                end
            end
        end
    end
    return best
end


function BridgeGunRules.openAmmoBox(body, item, outType, amount)
    if body == nil or item == nil or type(outType) ~= "string" then return false end
    local n = math.floor(tonumber(amount) or 0)
    if n < 1 then return false end
    if item:getContainer() == nil then return false end
    local count = BridgeGunRules.itemCount(item)
    if count > 1 then
        BridgeGunRules.setItemCount(item, count - 1)
    else
        BridgeGunRules.removeItem(item)
    end
    local left = n
    local function put(container)
        if container == nil then return end
        while left > 0 do
            local added = nil
            pcall(function() added = container:AddItem(outType, 1) end)
            if added == nil then
                pcall(function()
                    local one = instanceItem(outType)
                    if one ~= nil then added = container:AddItem(one) end
                end)
            end
            if added == nil then return end
            left = left - 1
        end
    end
    pcall(function()
        for _, bagItem in ipairs(wornItems(body)) do
            if left <= 0 then break end
            if bagItem:IsInventoryContainer() then
                local bag = bagItem:getInventory()
                if bag ~= nil then put(bag) end
            end
        end
    end)
    put(body:getInventory())
    if left > 0 then
        pcall(function()
            local sq = body:getCurrentSquare() or body:getSquare()
            if sq == nil then return end
            local out = instanceItem(outType)
            if out == nil then return end
            out:setCount(left)
            local x, y = ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9)
            sq:AddWorldInventoryItem(out, x, y, sq:getApparentZ(x, y) - sq:getZ())
        end)
    end
    return left <= 0
end


local function vlog(text)
    if Bridge ~= nil and Bridge.verbose and BridgeLog ~= nil and BridgeLog.on() then
        print("[BridgeGunRules] " .. tostring(text))
    end
end


function BridgeGunRules.returnAmmoBoxes(body, src, boxType, want)
    local moved, available = 0, 0
    if body == nil or src == nil or type(boxType) ~= "string" then return 0, 0, "no source" end
    local n = math.floor(tonumber(want) or 0)
    local items = {}
    for _, item in ipairs(BridgeGunRules.itemsOf(body)) do
        local full = nil
        pcall(function() full = item:getFullType() end)
        if full == boxType then
            local count = BridgeGunRules.itemCount(item)
            available = available + count
            items[#items + 1] = item
        end
    end
    vlog(string.format("return ammo boxes: found=%d want=%d type=%s src=%s",
        available, n, boxType, tostring(src)))
    if n <= 0 or available <= 0 then
        return 0, available, "nothing to return"
    end
    local take = math.min(n, available - 1)
    if take <= 0 then return 0, available, "keep one" end
    local left = take
    local reason = (take < n) and "shortfall" or nil
    for _, item in ipairs(items) do
        if left <= 0 then break end
        local count = BridgeGunRules.itemCount(item)
        if count <= left then
            local ok = false
            pcall(function()
                local from = item:getContainer()
                if from == nil then return end
                from:Remove(item)
                ok = src:AddItem(item) ~= nil
                if not ok then from:AddItem(item) end
            end)
            if ok then
                moved = moved + count
                left = left - count
            else
                reason = "source rejected box"
            end
        else
            local use = left
            local before = count
            local split = BridgeGunRules.setItemCount(item, count - use)
            local made, madeCount = nil, 0
            if split then
                pcall(function() made = src:AddItems(boxType, use) end)
                if made ~= nil then pcall(function() madeCount = made:size() end) end
            end
            if madeCount == use then
                moved = moved + use
                left = left - use
            else
                if made ~= nil and madeCount > 0 then
                    pcall(function()
                        for i = madeCount - 1, 0, -1 do
                            local one = made:get(i)
                            if one ~= nil then src:Remove(one) end
                        end
                    end)
                end
                pcall(function() item:setCount(before) end)
                reason = "source rejected box"
            end
        end
    end
    if left > 0 and reason == nil then reason = "shortfall" end
    vlog(string.format("return ammo boxes: moved=%d kept=%d shortfall=%d src=%s%s",
        moved, available - moved, left, tostring(src), reason and (" reason=" .. reason) or ""))
    return moved, available, reason
end


function BridgeGunRules.unpackDebug(itemType)
    if type(itemType) ~= "string" or itemType == "" then return "unpack: no item type" end
    BridgeGunRules.unpackCache[itemType] = nil
    local spec = BridgeGunRules.unpackOf(itemType)
    if spec == nil then return "unpack " .. itemType .. ": none" end
    local list = {}
    for _, t in ipairs(spec.out) do list[#list + 1] = t end
    table.sort(list)
    return string.format("unpack %s recipe=%s amount=%d ticks=%d out=%s",
        itemType, tostring(spec.recipe), spec.amount, spec.ticks,
        (#list > 0) and table.concat(list, ",") or "-")
end


function BridgeGunRules.selftest()
    local checks, fails = 0, {}
    local function check(name, got, want)
        checks = checks + 1
        if got ~= want then
            fails[#fails + 1] = string.format("%s got=%s want=%s", name, tostring(got), tostring(want))
        end
    end
    local function itemOf(fullType)
        local item = nil
        pcall(function() item = instanceItem(fullType) end)
        return item
    end
    local function descOf(fullType)
        local item = itemOf(fullType)
        if item == nil then return nil end
        local desc = nil
        pcall(function() desc = BridgeGunRules.describe(item) end)
        return desc
    end

    check("resolve bare", resolveItemType("Bullets44Box", "Base"), "Base.Bullets44Box")
    check("resolve qualified", resolveItemType("Base.Bullets44Box", "Base"), "Base.Bullets44Box")
    check("resolve missing", resolveItemType("NoSuchAmmoBox_XYZ", "Base"), nil)
    check("resolve colon", resolveItemType("base:Bullets44Box", "Base"), "Base.Bullets44Box")
    check("unpackUp carton", unpackUp("Base.Bullets44Carton"), "Base.Bullets44Box")

    local function unpackHas(spec, want)
        if spec == nil or type(spec.out) ~= "table" then return false end
        for _, t in ipairs(spec.out) do
            if t == want then return true end
        end
        return false
    end
    if itemOf("Base.RF_762x39Box") ~= nil then
        local rf762Box = BridgeGunRules.unpackOf("Base.RF_762x39Box")
        check("RF 762x39 box amount", rf762Box and rf762Box.amount, 30)
        check("RF 762x39 box out", unpackHas(rf762Box, "Base.RF_762x39Bullets"), true)
    end
    if itemOf("Base.RF_9x18Box") ~= nil then
        local rf9x18Box = BridgeGunRules.unpackOf("Base.RF_9x18Box")
        check("RF 9x18 box amount", rf9x18Box and rf9x18Box.amount, 50)
    end
    if itemOf("Base.RF_12GaugeBox") ~= nil then
        local rf12GaugeBox = BridgeGunRules.unpackOf("Base.RF_12GaugeBox")
        check("RF 12Gauge box amount", rf12GaugeBox and rf12GaugeBox.amount, 24)
    end
    if itemOf("Base.RF_500Box") ~= nil then
        local rf500Box = BridgeGunRules.unpackOf("Base.RF_500Box")
        check("RF 500 box amount", rf500Box and rf500Box.amount, 10)
    end
    if itemOf("Base.RF_762x39Carton") ~= nil then
        local rf762Carton = BridgeGunRules.unpackOf("Base.RF_762x39Carton")
        check("RF 762x39 carton amount", rf762Carton and rf762Carton.amount, 12)
        check("RF 762x39 carton out", unpackHas(rf762Carton, "Base.RF_762x39Box"), true)
    end

    local mosin = descOf("MarzGuns.MOSIN")
    if mosin ~= nil then
        check("Mosin magazine profile", mosin.hasMagazineProfile, true)
        check("Mosin clipSet", mosin.clipSet and mosin.clipSet["MarzGuns.762x54StripperClip5_MOSIN"], true)
        check("Mosin family", mosin.ammoFamily, "7.62x54mm")
        local fakeClip = {
            getFullType = function() return "MarzGuns.762x54StripperClip5_MOSIN" end,
            getCurrentAmmoCount = function() return 5 end,
        }
        local clip, clipRounds = BridgeGunRules.findLoadedMagazine({}, mosin, { fakeClip })
        check("Mosin loaded clip", clip, fakeClip)
        check("Mosin loaded clip rounds", clipRounds, 5)
    end
    local marzChecks = {
        { "AK74", "MarzGuns.AK74", 2, true },
        { "AKS74U", "MarzGuns.AKS74U", 2, true },
        { "SVD", "MarzGuns.SVD", 2, true },
        { "CAMP_CARBINE", "MarzGuns.CAMP_CARBINE", 2, nil },
        { "W1873", "MarzGuns.W1873", 2, nil },
        { "MP5", "MarzGuns.MP5", 1, false },
        { "M60", "MarzGuns.M60", 1, nil },
        { "MOSSBERG_590", "MarzGuns.MOSSBERG_590", 9, false },
    }
    for _, entry in ipairs(marzChecks) do
        local desc = descOf(entry[2])
        if desc ~= nil then
            check("Marz " .. entry[1] .. " maxHitCount", desc.maxHitCount, entry[3])
            if entry[4] ~= nil then
                check("Marz " .. entry[1] .. " piercingBullets", desc.piercingBullets, entry[4])
            end
        end
    end
    local vanillaAssault = descOf("Base.AssaultRifle")
    if vanillaAssault ~= nil then
        check("Vanilla AssaultRifle maxHitCount", vanillaAssault.maxHitCount, 1)
        check("Vanilla AssaultRifle piercingBullets", vanillaAssault.piercingBullets, false)
    end

    local aug = descOf("GunsOfTien.AUG")
    if aug ~= nil and type(aug.magazineSet) == "table" then
        local count = 0
        for _ in pairs(aug.magazineSet) do count = count + 1 end
        check("AUG magazine profile entries", count > 0, true)
    end
    local m249 = descOf("GunsOfTien.M249")
    if m249 ~= nil and type(m249.magazineSet) == "table" then
        check("M249 belt box profile", m249.magazineSet["GunsOfTien.556x45Box200_M249"], true)
    end
    local apBox = "MarzGuns.556x45_Box_ArmorPiercing"
    if itemOf(apBox) ~= nil then
        local apSpec = BridgeGunRules.unpackOf(apBox)
        local apRound = BridgeGunRules.exactOutput(apSpec)
        check("AP box exact", apRound ~= nil, true)
        local rifle = descOf("MarzGuns.M16A1") or descOf("GunsOfTien.AUG")
        if rifle ~= nil and apRound ~= nil then
            local owner = Bridge ~= nil and Bridge.body or nil
                local fakeLoose = {
                    getFullType = function() return apRound end,
                    getCount = function() return 1 end,
                }
            local _, total = BridgeGunRules.findLooseRounds({}, rifle, 1, { fakeLoose }, owner)
            check("AP loose found", total > 0, true)
            if type(rifle.ammoBox) == "string" and rifle.ammoBox ~= apBox then
                local baseItem = { getFullType = function() return rifle.ammoBox end }
                local apItem = { getFullType = function() return apBox end }
                local pick = BridgeGunRules.findAmmoBox({}, rifle, { baseItem, apItem }, owner)
                check("AP box chosen", pick and pick.type, apBox)
            end
        end
    end
    local syntheticWeapon = {
        md = {},
        getModData = function(self) return self.md end,
        isRoundChambered = function() return false end,
        setContainsClip = function() end,
        setCurrentAmmoCount = function(self, n) self.rounds = n end,
        getCurrentAmmoCount = function(self) return self.rounds or 0 end,
        getMaxAmmo = function() return 30 end,
        setAmmoType = function() end,
        getAmmoType = function() return nil end,
    }
    local syntheticContainer = {
        Remove = function() end,
        getParent = function() return nil end,
    }
    local syntheticMagazine = {
        md = { AmmoList = { "SWMG.556x45_Bullet", "SWMG.556x45_Bullet_ArmorPiercing" } },
        getModData = function(self) return self.md end,
        getFullType = function() return "MarzGuns.556x45Magazine30_STANAG" end,
        getCurrentAmmoCount = function() return 2 end,
        getAmmoType = function() return { getItemKey = function() return "SWMG.556x45_Bullet" end } end,
        getContainer = function() return syntheticContainer end,
    }
    local syntheticDesc = { magazineType = "MarzGuns.556x45Magazine30_STANAG", ammoBox = "Base.556Box" }
    local inserted = BridgeGunRules.insertMagazine({}, syntheticWeapon, syntheticMagazine, syntheticDesc)
    check("insertMagazine rounds", inserted, 2)
    check("insertMagazine AmmoList kept",
        syntheticWeapon.md.AmmoList and #syntheticWeapon.md.AmmoList, 2)

    local de44 = descOf("Base.DE44")
    if de44 ~= nil then
        check("DE44 ammoBox", de44.ammoBox, "Base.Bullets44Box")
    end
    local de357 = descOf("Base.DE357")
    if de357 ~= nil then
        check("DE357 ammoBox", de357.ammoBox, "Base.Bullets357Box")
        check("DE357 ammo", de357.ammoTypeKey, "Base.Bullets357")
    end
    local m60 = descOf("Base.M60")
    if m60 ~= nil then
        check("M60 ammoBox", m60.ammoBox, "Base.308Box")
        check("M60 magazine", m60.magazineType, "Base.M60Box")
    end
    local m1 = descOf("Base.M1Carbine")
    if m1 ~= nil then
        check("M1Carbine ammoBox", m1.ammoBox, "Base.30CarBox")
    end
    local sw29 = descOf("Base.SW29")
    if sw29 ~= nil then
        check("SW29 ammoBox", sw29.ammoBox, "Base.Bullets44Box")
    end

    check("talkKind pistol", BridgeGunRules.talkKind(
        { kind = "Handgun", reloadFamily = "handgun", projectileCount = 1 }), "Pistol")
    check("talkKind revolver", BridgeGunRules.talkKind(
        { kind = "Handgun", reloadFamily = "revolver", projectileCount = 1 }), "Pistol")
    check("talkKind sawed-off", BridgeGunRules.talkKind(
        { kind = "Handgun", reloadFamily = "handgun", projectileCount = 8 }), "Shotgun")
    check("talkKind pump shotgun", BridgeGunRules.talkKind(
        { kind = "Handgun", reloadFamily = "shotgun", projectileCount = 1 }), "Shotgun")
    check("talkKind rifle", BridgeGunRules.talkKind(
        { kind = "Rifle", reloadFamily = "rifle", projectileCount = 1 }), "Rifle")
    check("talkKind bolt-action", BridgeGunRules.talkKind(
        { kind = "Rifle", reloadFamily = "rifle_nomag", projectileCount = 1 }), "Rifle")
    check("talkKind unsupported", BridgeGunRules.talkKind(
        { kind = nil, reloadFamily = "unsupported", projectileCount = 1 }), "Other")
    check("talkKind nil", BridgeGunRules.talkKind(nil), "Other")

    local realPistol = descOf("Base.Pistol")
    if realPistol ~= nil then check("talkKind Base.Pistol", BridgeGunRules.talkKind(realPistol), "Pistol") end
    local realRevolver = descOf("Base.Revolver")
    if realRevolver ~= nil then check("talkKind Base.Revolver", BridgeGunRules.talkKind(realRevolver), "Pistol") end
    local realSawn = descOf("Base.ShotgunSawnoff")
    if realSawn ~= nil then check("talkKind Base.ShotgunSawnoff", BridgeGunRules.talkKind(realSawn), "Shotgun") end
    local realPump = descOf("Base.Shotgun")
    if realPump ~= nil then check("talkKind Base.Shotgun", BridgeGunRules.talkKind(realPump), "Shotgun") end
    local realRifle = descOf("Base.HuntingRifle")
    if realRifle ~= nil then check("talkKind Base.HuntingRifle", BridgeGunRules.talkKind(realRifle), "Rifle") end

    BridgeGunRules.atyCache = nil
    BridgeGunRules.atyNum = nil
    local fake = function(x, y)
        return { getX = function() return x end, getY = function() return y end }
    end
    check("atyShotgun key", BridgeGunRules.atyShotgun({ ammoTypeKey = "Base.ShotgunShells" }), true)
    check("atyShotgun pistol", BridgeGunRules.atyShotgun({ ammoTypeKey = "Base.Bullets45" }), false)
    check("atyShotgun nil", BridgeGunRules.atyShotgun(nil), false)
    local pump = { ammoTypeKey = "Base.ShotgunShells", maxHitCount = 9 }
    check("atyCap shotgun 9 num1", BridgeGunRules.atyCap(pump, 1), 5)
    check("atyCap shotgun 9 num0", BridgeGunRules.atyCap(pump, 0), 4)
    check("atyCap pistol 1", BridgeGunRules.atyCap({ ammoTypeKey = "Base.Bullets45", maxHitCount = 1 }, 1), 1)
    check("atyCap rifle 2", BridgeGunRules.atyCap({ ammoTypeKey = "Base.308", maxHitCount = 2 }, 1), 2)
    check("atyScale lateral 0", BridgeGunRules.atyScale(false, 0, 10, 20), 1)
    check("atyScale lateral 1", BridgeGunRules.atyScale(false, 1, 10, 20), 0.5)
    check("atyScale lateral 2", BridgeGunRules.atyScale(false, 2, 10, 20), 0)
    check("atyScale lateral 3", BridgeGunRules.atyScale(false, 3, 10, 20), 0)
    check("atyScale shotgun near", BridgeGunRules.atyScale(true, 0, 0, 20), 1)
    check("atyScale shotgun mid", BridgeGunRules.atyScale(true, 0, 10, 20), 0.75)
    check("atyScale shotgun max", BridgeGunRules.atyScale(true, 0, 20, 20), 0.5)
    check("atyScale shotgun over", BridgeGunRules.atyScale(true, 0, 40, 20), 0.5)
    local shooter = fake(0, 0)
    local primary = fake(5, 0)
    local near = fake(2, 0.5)
    local mid = fake(3, -1)
    local far = fake(6, 0.2)
    local wide = fake(1, 2.5)
    local plan = BridgeGunRules.atyPlan(shooter, primary,
        { ammoTypeKey = "Base.308", maxHitCount = 3 }, { far, wide, mid, near, primary }, 20)
    check("atyPlan kind", plan.kind, "aty")
    check("atyPlan primaryShare", plan.primaryShare, 1)
    check("atyPlan extras", #plan.extras, 2)
    check("atyPlan first", plan.extras[1] and plan.extras[1].target, near)
    check("atyPlan second", plan.extras[2] and plan.extras[2].target, mid)
    check("atyPlan forceHit", plan.extras[1] and plan.extras[1].forceHit, true)
    check("atyPlan near share", plan.extras[1] and plan.extras[1].share, 0.75)
    check("atyPlan wide skipped", plan.extras[1] and plan.extras[1].target ~= wide, true)
    local solo = BridgeGunRules.atyPlan(shooter, primary,
        { ammoTypeKey = "Base.Bullets45", maxHitCount = 1 }, { near }, 20)
    check("atyPlan cap1 extras", #solo.extras, 0)
    local sgPlan = BridgeGunRules.atyPlan(fake(0, 0), fake(10, 0), pump, {}, 20)
    check("atyPlan shotgun share", sgPlan.primaryShare, 0.75)
    check("atyPlan shotgun no extras", #sgPlan.extras, 0)
    BridgeGunRules.atyCache = nil
    BridgeGunRules.atyNum = nil

    check("turnTicks 0", BridgeGunRules.turnTicks(0), 0)
    check("turnTicks quarter", BridgeGunRules.turnTicks(math.pi / 2), 12)
    check("turnTicks pi", BridgeGunRules.turnTicks(math.pi), 24)
    check("turnTicks over", BridgeGunRules.turnTicks(5), 24)
    check("turnTicks negative", BridgeGunRules.turnTicks(-1), 0)
    check("turnTicks nil", BridgeGunRules.turnTicks(nil), 0)
    check("plantTicks true", BridgeGunRules.plantTicks(true), 60)
    check("plantTicks false", BridgeGunRules.plantTicks(false), 0)
    check("plantTicks nil", BridgeGunRules.plantTicks(nil), 0)
    check("retargetTicks true", BridgeGunRules.retargetTicks(true), 30)
    check("retargetTicks false", BridgeGunRules.retargetTicks(false), 0)
    check("retargetTicks nil", BridgeGunRules.retargetTicks(nil), 0)
    check("aimAngle same", BridgeGunRules.aimAngle(1, 0, 1, 0), 0)
    check("aimAngle quarter", string.format("%.2f", BridgeGunRules.aimAngle(1, 0, 0, 1)), "1.57")
    check("aimAngle empty", BridgeGunRules.aimAngle(0, 0, 1, 1), 0)

    local bodyViewer = { CanSee = function(_, z) return z.flag == "body" end }
    local redViewer = { CanSee = function(_, z) return z.flag == "red" end }
    local blind = { CanSee = function() return false end }
    local zb = { flag = "body" }
    local zr = { flag = "red" }
    local zn = { flag = "none" }
    check("targetVisible body", BridgeGunRules.targetVisible(bodyViewer, redViewer, zb), true)
    check("targetVisible red", BridgeGunRules.targetVisible(bodyViewer, redViewer, zr), true)
    check("targetVisible neither", BridgeGunRules.targetVisible(blind, blind, zn), false)
    check("targetVisible nil", BridgeGunRules.targetVisible(bodyViewer, redViewer, nil), false)
    check("targetVisible delegates body", BridgeGunRules.targetVisible(bodyViewer, redViewer, zb),
        BridgeZScan.canSee(zb, bodyViewer, redViewer))
    check("targetVisible delegates red", BridgeGunRules.targetVisible(bodyViewer, redViewer, zr),
        BridgeZScan.canSee(zr, bodyViewer, redViewer))

    local function laneFake(x, y, z)
        return {
            getX = function() return x end,
            getY = function() return y end,
            getZ = function() return z or 0 end,
        }
    end
    local laneShooter = laneFake(0, 0, 0)
    local laneTarget = laneFake(5, 0, 0)
    local laneAhead = laneFake(2, 0.5, 0)
    local laneBehind = laneFake(-0.5, 0, 0)
    local laneBeyond = laneFake(6, 0.2, 0)
    local laneSide = laneFake(2, 2.0, 0)
    check("friendlyInLine ahead", BridgeGunRules.friendlyInLine(
        laneShooter, laneTarget, { laneAhead }), laneAhead)
    check("friendlyInLine behind", BridgeGunRules.friendlyInLine(
        laneShooter, laneTarget, { laneBehind }), nil)
    check("friendlyInLine beyond", BridgeGunRules.friendlyInLine(
        laneShooter, laneTarget, { laneBeyond }), nil)
    check("friendlyInLine side", BridgeGunRules.friendlyInLine(
        laneShooter, laneTarget, { laneSide }), nil)

    if #fails == 0 then return string.format("gunselftest PASS (%d checks)", checks) end
    return string.format("gunselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end


local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGunRules] " .. tostring(text)) end
end

log("loaded")


local function efzLogOnce(key, message)
    BridgeGunRules.efzLogSeen = BridgeGunRules.efzLogSeen or {}
    if BridgeGunRules.efzLogSeen[key] then return end
    BridgeGunRules.efzLogSeen[key] = true
    print("[BridgeGunRules] " .. tostring(message))
end


function BridgeGunRules.efzRuntime()
    local runtime = rawget(_G, "TWRuntime")
    if type(runtime) ~= "table" then return nil end
    if type(runtime.tree) ~= "function" or type(runtime.applyTree) ~= "function" then return nil end
    if BridgeGunRules.efzRuntimeLogged ~= true then
        BridgeGunRules.efzRuntimeLogged = true
        print("[BridgeGunRules] EFZ runtime detected")
    end
    return runtime
end


function BridgeGunRules.efzData()
    if BridgeGunRules.efzDataModule ~= nil then return BridgeGunRules.efzDataModule end
    local ok, data = pcall(require, "TW/Data")
    if ok and type(data) == "table" then
        BridgeGunRules.efzDataModule = data
        return data
    end
    return nil
end


local function efzTableString(tree)
    if type(tree) ~= "table" then return nil end
    local paths = {}
    for path in pairs(tree) do
        if type(path) == "string" and path ~= "" and type(tree[path]) == "string" and tree[path] ~= "" then
            paths[#paths + 1] = path
        end
    end
    if #paths == 0 then return nil end
    table.sort(paths)
    local out = {}
    for _, path in ipairs(paths) do out[#out + 1] = path .. ":" .. tree[path] end
    return table.concat(out, "+")
end


local function noKeys(t)
    for _ in pairs(t) do return false end
    return true
end


function BridgeGunRules.efzTreeString(item)
    if item == nil then return nil end
    local runtime = BridgeGunRules.efzRuntime()
    if runtime == nil then return nil end
    local isWeapon = false
    pcall(function() isWeapon = runtime.isWeapon(item) == true end)
    if not isWeapon then return nil end
    local ok, tree = pcall(runtime.tree, item)
    if not ok then return nil end
    return efzTableString(tree)
end


function BridgeGunRules.efzParseTree(text)
    if type(text) ~= "string" or text == "" then return nil end
    local tree = {}
    local any = false
    for entry in string.gmatch(text, "[^+]+") do
        local path, tpl = string.match(entry, "^([^:]+):([^:]+)$")
        if path == nil or path == "" or tpl == nil or tpl == "" then return nil end
        tree[path] = tpl
        any = true
    end
    if not any then return nil end
    return tree
end


local function efzFallbackApply(item, tree)
    local coreOk, core = pcall(require, "TW/Core")
    local runtime = BridgeGunRules.efzRuntime()
    if not coreOk or type(core) ~= "table" or runtime == nil then return false, "no-core" end
    if type(core.validate) ~= "function" or type(core.isClip) ~= "function"
        or type(core.depth) ~= "function" or type(core.clipType) ~= "function" then
        return false, "no-core"
    end
    local key = nil
    pcall(function() key = runtime.key(item) end)
    if key == nil then return false, "invalidItem" end
    local valid, reason = core.validate(key, tree)
    if not valid then return false, tostring(reason or "invalidTree") end
    local list = item:getAllWeaponParts()
    local installed = {}
    for i = 0, list:size() - 1 do installed[#installed + 1] = list:get(i) end
    for _, part in ipairs(installed) do
        local meta = nil
        pcall(function() meta = runtime.meta(part) end)
        if meta ~= nil then pcall(function() item:detachWeaponPart(part) end) end
    end
    local paths = {}
    for path, tpl in pairs(tree) do
        if not core.isClip(tpl) then paths[#paths + 1] = path end
    end
    table.sort(paths, function(a, b)
        local da, db = core.depth(a), core.depth(b)
        if da == db then return a < b end
        return da < db
    end)
    local used = {}
    for _, path in ipairs(paths) do
        local tpl = tree[path]
        local copy = used[tpl] or 0
        used[tpl] = copy + 1
        local part = nil
        pcall(function() part = instanceItem(runtime.typeFor(tpl, copy)) end)
        if part == nil then return false, "missingNativeAlias" end
        pcall(function() part:getModData().TWPath = path end)
        pcall(function() item:attachWeaponPart(part, false) end)
    end
    pcall(function()
        item:setCurrentAmmoCount(0)
        item:setRoundChambered(false)
        item:getModData().AmmoList = nil
    end)
    if core.isClip(tree.mod_magazine) then
        local full = core.clipType(key, tree.mod_magazine)
        local magazine = nil
        pcall(function() magazine = instanceItem(full) end)
        if magazine == nil then return false, "missingMagazine" end
        pcall(function()
            item:setMagazineType(full)
            item:setMaxAmmo(magazine:getMaxAmmo())
            item:setContainsClip(true)
        end)
        local mod = nil
        pcall(function() mod = require("WeaponSystems/Utils/Magazine") end)
        if type(mod) == "table" then
            if type(mod.SaveMagazineType) == "function" then pcall(mod.SaveMagazineType, item, full) end
            if type(mod.manageMagazineAttachment) == "function" then pcall(mod.manageMagazineAttachment, item, full) end
        end
    else
        pcall(function() item:setContainsClip(false) end)
    end
    pcall(runtime.refresh, item, nil)
    return true
end


function BridgeGunRules.efzApplyTree(item, tree)
    if item == nil or type(tree) ~= "table" or noKeys(tree) then return false, "bad-tree" end
    local runtime = BridgeGunRules.efzRuntime()
    if runtime == nil then return false, "no-runtime" end
    local ok, result, reason = pcall(runtime.applyTree, item, tree)
    if ok and result == true then return true end
    local fallbackRan, fallbackOk, fallbackWhy = pcall(efzFallbackApply, item, tree)
    if fallbackRan and fallbackOk then
        efzLogOnce("fallback", "EFZ applyTree fallback used")
        return true
    end
    if not fallbackRan then fallbackWhy = fallbackOk end
    if not ok then return false, tostring(result) end
    return false, tostring(reason or "applyTree") .. "/" .. tostring(fallbackWhy or "fallback")
end


function BridgeGunRules.efzCanRebuild(fullType, tree)
    if type(fullType) ~= "string" or type(tree) ~= "table" then return false, "bad-tree" end
    if BridgeGunRules.efzRuntime() == nil then return false, "no-runtime" end
    local text = efzTableString(tree)
    if text == nil then return false, "empty-tree" end
    BridgeGunRules.efzValidated = BridgeGunRules.efzValidated or {}
    local key = fullType .. "|" .. text
    local seen = BridgeGunRules.efzValidated[key]
    if seen ~= nil then return seen.ok, seen.why end
    local item = nil
    pcall(function() item = instanceItem(fullType) end)
    if item == nil then
        BridgeGunRules.efzValidated[key] = { ok = false, why = "missing-item" }
        efzLogOnce("item:" .. fullType, "EFZ item unavailable: " .. tostring(fullType))
        return false, "missing-item"
    end
    local ok, why = BridgeGunRules.efzApplyTree(item, tree)
    BridgeGunRules.efzValidated[key] = { ok = ok, why = why }
    if not ok then
        efzLogOnce("rebuild:" .. key, "EFZ tree rejected for " .. fullType .. ": " .. tostring(why))
    end
    return ok, why
end


function BridgeGunRules.efzNoteSizes(rec)
    if type(rec) ~= "table" or BridgeGunRules.efzRuntime() == nil then return end
    if Bridge == nil or Bridge.verbose ~= true then return end
    BridgeGunRules.efzSizeSeen = BridgeGunRules.efzSizeSeen or {}
    local key = tostring(rec.t)
    if BridgeGunRules.efzSizeSeen[key] then return end
    BridgeGunRules.efzSizeSeen[key] = true
    local total = 0
    if BridgeItems ~= nil and type(BridgeItems.encode) == "function" then
        local oldTruncated = BridgeItems.truncated
        local oldLength = BridgeItems.lastLength
        local oldLogged = BridgeItems.truncatedLogged
        local ok, text = pcall(BridgeItems.encode, { rec })
        if ok and type(text) == "string" then total = #text end
        BridgeItems.truncated = oldTruncated
        BridgeItems.lastLength = oldLength
        BridgeItems.truncatedLogged = oldLogged
    end
    local cap = BridgeItems ~= nil and tonumber(BridgeItems.MAX_LENGTH) or 0
    print(string.format("[BridgeGunRules] EFZ snapshot %s tw=%d al=%d wp=%d wpold=%d total=%d max=%d",
        key, #tostring(rec.tw or ""), #tostring(rec.al or ""), #tostring(rec.wp or ""),
        tonumber(rec.legacyWpSize) or 0, total, cap))
end


BridgeGunRules.efzAmmoCache = BridgeGunRules.efzAmmoCache or {}
BridgeGunRules.efzBoxRound = BridgeGunRules.efzBoxRound or nil


local function efzBoxMap()
    if BridgeGunRules.efzBoxRound ~= nil then return BridgeGunRules.efzBoxRound end
    local map = {}
    local data = BridgeGunRules.efzData()
    local calibres = type(data) == "table" and data.ammo and data.ammo.calibres or nil
    for _, cal in pairs(calibres or {}) do
        for _, round in ipairs(cal.rounds or {}) do
            if type(round.box) == "string" and type(round.type) == "string" then
                map[round.box] = round.type
            end
        end
    end
    BridgeGunRules.efzBoxRound = map
    return map
end


local function efzAmmoFor(desc, item)
    if type(desc) ~= "table" or type(desc.fullType) ~= "string" then return nil end
    if desc.efzAmmo ~= nil then return desc.efzAmmo end
    local cache = BridgeGunRules.efzAmmoCache
    local hit = cache[desc.fullType]
    if hit ~= nil then return hit or nil end
    local runtime = BridgeGunRules.efzRuntime()
    if runtime == nil then return nil end
    local key = nil
    pcall(function() key = runtime.key(item) end)
    if key == nil then
        cache[desc.fullType] = false
        return nil
    end
    local data = BridgeGunRules.efzData()
    local weapon = type(data) == "table" and data.weapons and data.weapons[key] or nil
    local calibre = weapon ~= nil and type(data.ammo) == "table" and data.ammo.calibres
        and data.ammo.calibres[weapon.ammoKey] or nil
    if type(calibre) ~= "table" then
        cache[desc.fullType] = false
        return nil
    end
    local types, typeSet, boxes, boxSet = {}, {}, {}, {}
    local function addType(t)
        if type(t) ~= "string" or t == "" or typeSet[t] then return end
        typeSet[t] = true
        types[#types + 1] = t
    end
    local function addBox(t)
        if type(t) ~= "string" or t == "" or boxSet[t] then return end
        boxSet[t] = true
        boxes[#boxes + 1] = t
    end
    addType(desc.ammoTypeKey)
    addType(weapon.ammo)
    addBox(weapon.ammoBox)
    for _, t in ipairs(calibre.aliases or {}) do addType(t) end
    for _, round in ipairs(calibre.rounds or {}) do
        addType(round.type)
        addBox(round.box)
    end
    local info = { types = types, typeSet = typeSet, boxes = boxes, boxSet = boxSet, family = calibre.family }
    cache[desc.fullType] = info
    return info
end


function BridgeGunRules.efzUnpackOf(itemType)
    if type(itemType) ~= "string" then return nil end
    local roundType = efzBoxMap()[itemType]
    if roundType == nil then return nil end
    local spec = BridgeGunRules.unpackOf(itemType)
    local amount = spec ~= nil and math.floor(tonumber(spec.amount) or 0) or 0
    local ticks = spec ~= nil and tonumber(spec.ticks) or 75
    if amount <= 0 and itemExists(itemType) then
        local name = nil
        pcall(function()
            local inst = instanceItem(itemType)
            if inst ~= nil then name = inst:getName() end
        end)
        if type(name) == "string" then
            amount = tonumber(string.match(name, "(%d+)%s*[Pp][Cc][Ss]"))
                or tonumber(string.match(name, "(%d+)%s*[Ss]hots"))
                or tonumber(string.match(name, "(%d+)%s*шт"))
                or 0
        end
    end
    if amount <= 0 then amount = 30 end
    return { out = { roundType }, amount = amount, ticks = ticks, recipe = "efz-box" }
end


BridgeGunRules.findLooseRoundsBase = BridgeGunRules.findLooseRounds
BridgeGunRules.removeOneLooseRoundBase = BridgeGunRules.removeOneLooseRound
BridgeGunRules.findAmmoBoxBase = BridgeGunRules.findAmmoBox


if BridgeGunRules.efzAmmoWrapped ~= true then
    BridgeGunRules.efzAmmoWrapped = true

    local baseDescribe = BridgeGunRules.describe
    function BridgeGunRules.describe(item)
        local desc = baseDescribe(item)
        if type(desc) == "table" and desc.efzAmmo == nil then
            desc.efzAmmo = efzAmmoFor(desc, item)
        end
        return desc
    end

    local baseFindLooseRounds = BridgeGunRules.findLooseRounds
    function BridgeGunRules.findLooseRounds(body, desc, need, items)
        if body == nil or type(desc) ~= "table" then return {}, 0 end
        local list = items or BridgeGunRules.itemsOf(body)
        if desc.efzAmmo == nil then return baseFindLooseRounds(body, desc, need, list) end
        local out, total = {}, 0
        local extras, extraTotal = {}, 0
        local want = math.floor(tonumber(need) or 1)
        local key = desc.ammoTypeKey
        local typeSet = desc.efzAmmo.typeSet
        for _, item in ipairs(list) do
            local full = nil
            pcall(function() full = item:getFullType() end)
            if type(full) == "string" then
                if full == key then
                    local n = BridgeGunRules.itemCount(item)
                    if n > 0 and total < want then
                        out[#out + 1] = { item = item, count = n }
                        total = total + n
                    end
                elseif typeSet[full] then
                    local n = BridgeGunRules.itemCount(item)
                    if n > 0 then
                        extras[#extras + 1] = { item = item, count = n }
                        extraTotal = extraTotal + n
                    end
                end
            end
        end
        if total >= want or extraTotal <= 0 then return out, total end
        for i = 1, #extras do
            if total >= want then break end
            local entry = extras[i]
            out[#out + 1] = entry
            total = total + entry.count
        end
        return out, total
    end

    local baseRemoveOneLooseRound = BridgeGunRules.removeOneLooseRound
    function BridgeGunRules.removeOneLooseRound(body, desc, items)
        local removed = baseRemoveOneLooseRound(body, desc, items)
        if removed ~= nil or body == nil or type(desc) ~= "table" or desc.efzAmmo == nil then return removed end
        for _, item in ipairs(items or BridgeGunRules.itemsOf(body)) do
            local full = nil
            pcall(function() full = item:getFullType() end)
            if type(full) == "string" and desc.efzAmmo.typeSet[full] then
                local id = nil
                pcall(function() id = item:getID() end)
                local got = BridgeGunRules.removeItemById(body, id)
                if got ~= nil then return got end
            end
        end
        return nil
    end

    local baseFindAmmoBox = BridgeGunRules.findAmmoBox
    function BridgeGunRules.findAmmoBox(body, gun, items)
        local best = baseFindAmmoBox(body, gun, items)
        if best ~= nil or body == nil or type(gun) ~= "table" or gun.efzAmmo == nil then return best end
        for _, item in ipairs(items or BridgeGunRules.itemsOf(body)) do
            local full = nil
            pcall(function() full = item:getFullType() end)
            if type(full) == "string" and gun.efzAmmo.boxSet[full] then
                local spec = BridgeGunRules.efzUnpackOf(full)
                if spec ~= nil and spec.out ~= nil and spec.out[1] ~= nil then
                    return {
                        item = item,
                        type = full,
                        out = spec.out[1],
                        amount = spec.amount,
                        ticks = spec.ticks,
                    }
                end
            end
        end
        return nil
    end

    local baseAmmoAccept = BridgeGunRules.ammoAccept
    function BridgeGunRules.ammoAccept(desc)
        local out = baseAmmoAccept(desc)
        if type(out) ~= "table" or type(desc) ~= "table" or desc.efzAmmo == nil then return out end
        local seen = {}
        for _, t in ipairs(out.boxes or {}) do seen[t] = true end
        out.boxes = out.boxes or {}
        for _, t in ipairs(desc.efzAmmo.boxes or {}) do
            if not seen[t] then
                seen[t] = true
                out.boxes[#out.boxes + 1] = t
            end
        end
        local seenRound = {}
        for _, t in ipairs(out.rounds or {}) do seenRound[t] = true end
        out.rounds = out.rounds or {}
        for _, t in ipairs(desc.efzAmmo.types or {}) do
            if not seenRound[t] then
                seenRound[t] = true
                out.rounds[#out.rounds + 1] = t
            end
        end
        return out
    end
end


local efzFindLooseRounds = BridgeGunRules.findLooseRounds
local efzRemoveOneLooseRound = BridgeGunRules.removeOneLooseRound
local efzFindAmmoBox = BridgeGunRules.findAmmoBox


function BridgeGunRules.findLooseRounds(body, desc, need, items, owner)
    if owner ~= nil and type(desc) == "table" and desc.efzAmmo == nil then
        return BridgeGunRules.findLooseRoundsBase(body, desc, need, items, owner)
    end
    return efzFindLooseRounds(body, desc, need, items)
end


function BridgeGunRules.removeOneLooseRound(body, desc, items, owner)
    if owner ~= nil and type(desc) == "table" and desc.efzAmmo == nil then
        return BridgeGunRules.removeOneLooseRoundBase(body, desc, items, owner)
    end
    return efzRemoveOneLooseRound(body, desc, items)
end


function BridgeGunRules.findAmmoBox(body, gun, items, owner)
    if owner ~= nil and type(gun) == "table" and gun.efzAmmo == nil then
        return BridgeGunRules.findAmmoBoxBase(body, gun, items, owner)
    end
    return efzFindAmmoBox(body, gun, items)
end
