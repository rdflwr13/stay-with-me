do

BridgeAty = BridgeAty or {}

local marked = nil
local on = nil

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeAty] " .. tostring(text)) end
end

local function atyOn()
    if on ~= nil then return on end
    if BridgeGun == nil then return false end
    on = false
    pcall(function()
        on = BridgeGun.atActive() == true and rawget(_G, "Advanced_trajectory") ~= nil
    end)
    if on then log("Advanced Trajectory found: companion target highlight on") end
    return on
end

local function playerHas(z)
    local g = rawget(_G, "Advanced_trajectory")
    if type(g) ~= "table" or type(g.zombierank) ~= "table" then return false end
    local list = g.zombierank
    for i = 1, #list do
        local v = list[i]
        if type(v) == "table" and v[1] == z then return true end
    end
    return false
end

local function tick()
    local want = nil
    if atyOn() and Bridge ~= nil and Bridge.body ~= nil and BridgeGunfight ~= nil
        and BridgeFight ~= nil and BridgeFight.state == "gun"
        and BridgeGunfight.drawn == true and BridgeGunfight.target ~= nil
        and (BridgeGunfight.state == "aim" or BridgeGunfight.state == "backstep") then
        want = BridgeGunfight.target
        local alive = false
        pcall(function() alive = want:isAlive() == true end)
        if not alive or playerHas(want) then want = nil end
    end

    if marked ~= nil and marked ~= want then
        if not playerHas(marked) then
            pcall(function() marked:setOutlineHighlight(false) end)
        end
        marked = nil
    end
    if want == nil then return end

    marked = want
    local level = (BridgeSkills ~= nil and BridgeSkills.level("Aiming")) or 0
    local total = BridgeGunRules.aimTicks(BridgeGunfight.gun, level)
    local remain = math.max(0, (BridgeGunfight.aimUntil or 0) - (Bridge.time or 0))
    local acc = 1 - remain / math.max(1, total)
    if acc < 0 then acc = 0 elseif acc > 1 then acc = 1 end
    pcall(function()
        want:setOutlineHighlight(true)
        want:setOutlineHighlightCol(1 - acc, acc, 0, 0.8)
    end)
end

Events.OnTick.Add(function() pcall(tick) end)
Events.OnGameStart.Add(function() marked = nil on = nil end)
log("loaded")
end

do
BridgeCompatKnox = BridgeCompatKnox or {}

local KEE_MOD_ID = "KnoxEventExpandedNpc"
local CHECK_RANGE = 5
local CHECK_EVERY = 30
local RETRY_EVERY = 60

local retryTick = 0

local function keeActive()
    if BridgeCompatKnox.kee ~= nil then return BridgeCompatKnox.kee end
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(KEE_MOD_ID) or mods:contains("\\" .. KEE_MOD_ID))
    end)
    BridgeCompatKnox.kee = on
    return on
end


function BridgeCompatKnox.isOurBody(z)
    if z == nil then return false end
    if Bridge ~= nil and type(Bridge.isCompanion) == "function" then
        local ok, yes = pcall(Bridge.isCompanion, z)
        if ok and yes then return true end
    end
    if Bridge ~= nil and Bridge.body == z then return true end
    local ok, yes = pcall(function() return z:getVariableBoolean("NotAloneBody") == true end)
    return ok and yes == true
end


local function hasRealZombieNear(x, y, z, range)
    local cell = getCell()
    if not cell then return false end
    local xi = math.floor(x)
    local yi = math.floor(y)
    local zi = math.floor(z)
    for ix = xi - range, xi + range do
        for iy = yi - range, yi + range do
            local sq = cell:getGridSquare(ix, iy, zi)
            if sq then
                local objs = sq:getMovingObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if instanceof(obj, "IsoZombie") and not obj:isDead() and not BridgeCompatKnox.isOurBody(obj) then
                        return true
                    end
                end
            end
        end
    end
    return false
end


function BridgeCompatKnox.update(self)
    if not self:isVisible() or not self.metaNpc then return end

    self.zombieCheckTick = (self.zombieCheckTick or 0) + 1
    if self.zombieCheckTick < CHECK_EVERY then return end
    self.zombieCheckTick = 0

    local player = getSpecificPlayer(self.playerNum) or getPlayer()
    if not player or player:isDead() then return end

    if hasRealZombieNear(player:getX(), player:getY(), player:getZ(), CHECK_RANGE) then
        self:sayGoodbye(player)
        return
    end

    local npcObj = self.metaNpc:getWorldObject()
    if npcObj and hasRealZombieNear(npcObj:getX(), npcObj:getY(), npcObj:getZ(), CHECK_RANGE) then
        self:sayGoodbye(player)
    end
end


function BridgeCompatKnox.installDialogueGuard()
    if not keeActive() then return end
    local cls = rawget(_G, "NpcDialogueUI")
    if type(cls) ~= "table" or type(cls.update) ~= "function" then return end
    if cls.update == BridgeCompatKnox.update then return end
    if BridgeCompatKnox.originalUpdate == nil then
        BridgeCompatKnox.originalUpdate = cls.update
    end
    cls.update = BridgeCompatKnox.update
    if not BridgeCompatKnox.logged then
        BridgeCompatKnox.logged = true
        print("[BridgeCompatKnox] KEE dialogue guard installed")
    end
end


function BridgeCompatKnox.uninstall()
    local cls = rawget(_G, "NpcDialogueUI")
    if type(cls) == "table" and type(BridgeCompatKnox.originalUpdate) == "function" then
        cls.update = BridgeCompatKnox.originalUpdate
    end
    BridgeCompatKnox.originalUpdate = nil
    BridgeCompatKnox.logged = nil
end


Events.OnGameStart.Add(function() pcall(BridgeCompatKnox.installDialogueGuard) end)

Events.OnTick.Add(function()
    retryTick = retryTick + 1
    if retryTick < RETRY_EVERY then return end
    retryTick = 0
    pcall(BridgeCompatKnox.installDialogueGuard)
end)
end

do
BridgeCompatStayAwayWindows = BridgeCompatStayAwayWindows or {}
local C = BridgeCompatStayAwayWindows

local RETRY_EVERY = 60

local function isCompanion(z)
    if z == nil then return false end

    local zombie = false
    pcall(function() zombie = instanceof(z, "IsoZombie") end)
    if not zombie then return false end

    local marker = false
    pcall(function() marker = z:getVariableBoolean("NotAloneBody") == true end)
    if marker then return true end

    if Bridge ~= nil then
        if Bridge.body == z then return true end
        if type(Bridge.isCompanion) == "function" then
            local ok, yes = pcall(Bridge.isCompanion, z)
            if ok and yes == true then return true end
        end
    end

    return false
end

function C.install()
    local modHandler = rawget(_G, "jumpThroughWindow")
    if type(modHandler) ~= "function" then return end

    if C.guard == nil or C.modHandler ~= modHandler then
        if C.guard ~= nil then
            pcall(function() Events.OnObjectCollide.Remove(C.guard) end)
            C.guard = nil
        end

        local guard = function(character, collider)
            if isCompanion(character) then return end
            return modHandler(character, collider)
        end

        Events.OnObjectCollide.Add(guard)
        C.guard = guard
        C.modHandler = modHandler
    end

    pcall(function() Events.OnObjectCollide.Remove(modHandler) end)

    if not C.logged then
        C.logged = true
        print("[BridgeCompatStayAwayWindows] companion window guard installed")
    end
end

Events.OnGameStart.Add(function() pcall(C.install) end)

local ticks = 0
Events.OnTick.Add(function()
    ticks = ticks + 1
    if ticks < RETRY_EVERY then return end
    ticks = 0
    pcall(C.install)
end)
end

do
BridgeGore = BridgeGore or {}
local C = BridgeGore

local MOD_ID = "DeadWorksZeds"
local RETRY_EVERY = 60

C.seen = setmetatable({}, { __mode = "k" })
C.ticks = 0
C.guarded = 0
C.cleaned = 0
C.released = 0
C.hitsRefused = 0

local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeGore] " .. tostring(text))
    end
end

function C.wanted(force)
    if C.active == true then return true end
    if C.active == false and not force then return false end
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(MOD_ID) or mods:contains("\\" .. MOD_ID))
    end)
    local api = rawget(_G, "FPZWounds") ~= nil or rawget(_G, "FPZOptions") ~= nil
        or rawget(_G, "FPZNet") ~= nil
    C.active = on and api
    return C.active
end

function C.ours(z)
    if z == nil then return false end
    local zombie = false
    pcall(function() zombie = instanceof(z, "IsoZombie") == true end)
    if not zombie then return false end
    if Bridge ~= nil and Bridge.body == z then return true end
    local yes = false
    pcall(function() yes = z:getVariableBoolean("NotAloneBody") == true end)
    if yes then return true end
    pcall(function() yes = z:getVariableBoolean("SurvivorNPC") == true end)
    if yes then return true end
    pcall(function() yes = z:hasModData() and z:getModData().notAloneBody == true end)
    if yes then return true end
    if BridgeBandits ~= nil and type(BridgeBandits.hers) == "function" then
        local ok, hers = pcall(BridgeBandits.hers, z)
        if ok and hers == true then return true end
    end
    return false
end

function C.key(z)
    if z == nil then return nil end
    local key = nil
    if FPZNet ~= nil and type(FPZNet.key) == "function" then
        pcall(function() key = FPZNet.key(z) end)
    end
    if key ~= nil then return tostring(key) end
    pcall(function()
        local id = z:getPersistentOutfitID()
        if id ~= nil and id ~= 0 then key = tostring(id) end
    end)
    return key
end

function C.outfitKey(z)
    if z == nil then return nil end
    local key = nil
    pcall(function()
        local id = z:getPersistentOutfitID()
        if id ~= nil and id ~= 0 then
            local female = false
            pcall(function() female = z:isFemale() == true end)
            key = tostring(id) .. (female and "F" or "M")
        end
    end)
    if key == nil then return C.key(z) end
    return key
end

function C.clean(z)
    if z == nil then return false end
    local changed = false
    pcall(function()
        local visuals = z:getItemVisuals()
        if visuals == nil then return end
        for i = visuals:size() - 1, 0, -1 do
            local iv = visuals:get(i)
            if iv ~= nil then
                local itemType = nil
                local clothing = nil
                pcall(function() itemType = iv:getItemType() end)
                pcall(function() clothing = iv:getClothingItemName() end)
                local drop = false
                if type(itemType) == "string" and string.sub(itemType, 1, 4) == "FPZ." then
                    drop = true
                end
                if type(clothing) == "string"
                        and (string.find(clothing, "^FPZ_Wound_") ~= nil
                            or string.find(clothing, "^FPZ_Crawler") ~= nil) then
                    drop = true
                end
                if drop then
                    visuals:remove(i)
                    changed = true
                end
            end
        end
    end)
    pcall(function()
        z:clearVariable("FPZTorso")
        z:clearVariable("FPZLegL")
        z:clearVariable("FPZLegR")
    end)
    pcall(function()
        local md = z:getModData()
        md.FPZTorso = nil
        md.FPZLegVar = nil
        md.FPZCrawlState = nil
        md.FPZLegTick = nil
    end)
    local key = C.key(z)
    if key ~= nil and FPZNet ~= nil and type(FPZNet.remote) == "table" then
        pcall(function() FPZNet.remote[key] = nil end)
    end
    if changed then pcall(function() z:resetModelNextFrame() end) end
    local reapply = false
    pcall(function()
        reapply = z:getItemVisuals():size() < z:getWornItems():size()
    end)
    if reapply and BridgeInventory ~= nil and type(BridgeInventory.applyWorn) == "function" then
        pcall(BridgeInventory.applyWorn, z)
    end
    C.cleaned = C.cleaned + 1
    return changed
end

function C.prime(z)
    if z == nil then return false end
    local key = C.outfitKey(z)
    if key == nil then return false end
    pcall(function()
        local md = z:getModData()
        md.FPZWoundsKey = key
        md.FPZWounds = ""
        md.FPZImpact = nil
        md.FPZTorsoChecked = true
        md.FPZTorso = nil
        md.FPZLegVar = nil
        md.FPZCrawlState = nil
        md.FPZLegTick = nil
    end)
    pcall(function()
        z:clearVariable("FPZTorso")
        z:clearVariable("FPZLegL")
        z:clearVariable("FPZLegR")
    end)
    if FPZNet ~= nil and type(FPZNet.remote) == "table" then
        local remoteKey = C.key(z)
        if remoteKey ~= nil then pcall(function() FPZNet.remote[remoteKey] = nil end) end
    end
    return true
end

function C.dirty(z)
    if z == nil then return false end
    local key = C.outfitKey(z)
    local dirty = false
    pcall(function()
        local md = z:getModData()
        if key ~= nil and md.FPZWoundsKey ~= key then dirty = true end
        if md.FPZWounds ~= nil and md.FPZWounds ~= "" then dirty = true end
        if md.FPZImpact ~= nil and md.FPZImpact ~= "" then dirty = true end
        if md.FPZTorsoChecked ~= true then dirty = true end
        if md.FPZTorso ~= nil or md.FPZLegVar ~= nil or md.FPZCrawlState ~= nil
                or md.FPZLegTick ~= nil then
            dirty = true
        end
    end)
    pcall(function()
        if z:getVariableBoolean("FPZTorso") == true or z:getVariableBoolean("FPZLegL") == true
                or z:getVariableBoolean("FPZLegR") == true then
            dirty = true
        end
    end)
    if key ~= nil and FPZNet ~= nil and type(FPZNet.remote) == "table" then
        local remoteKey = C.key(z)
        if remoteKey ~= nil then
            pcall(function()
                if FPZNet.remote[remoteKey] ~= nil then dirty = true end
            end)
        end
    end
    return dirty
end

function C.guard(z)
    if not C.wanted() or not C.ours(z) then return end
    local first = C.seen[z] ~= true
    C.seen[z] = true
    if not first and not C.dirty(z) then return end
    C.clean(z)
    C.prime(z)
    C.guarded = C.guarded + 1
    if not C.said then
        C.said = true
        log("companion gore suppressed")
    end
end

function C.release(z)
    if z == nil then return end
    C.seen[z] = nil
    pcall(function()
        local md = z:getModData()
        md.FPZWoundsKey = nil
        md.FPZWounds = nil
        md.FPZImpact = nil
        md.FPZTorsoChecked = nil
        md.FPZTorso = nil
        md.FPZLegVar = nil
        md.FPZCrawlState = nil
        md.FPZLegTick = nil
    end)
    pcall(function()
        z:clearVariable("FPZTorso")
        z:clearVariable("FPZLegL")
        z:clearVariable("FPZLegR")
    end)
    local key = C.key(z)
    if key ~= nil and FPZNet ~= nil and type(FPZNet.remote) == "table" then
        pcall(function() FPZNet.remote[key] = nil end)
    end
    C.released = C.released + 1
end

function C.installHitGuard()
    local api = rawget(_G, "FPZWounds")
    if type(api) ~= "table" or type(api.addFromHit) ~= "function" then return false end
    if C.wrappedHit ~= nil and api.addFromHit == C.wrappedHit then return true end
    local original = api.addFromHit
    local wrapped = function(zombie, kinds)
        if C.ours(zombie) then
            C.hitsRefused = C.hitsRefused + 1
            return nil
        end
        return original(zombie, kinds)
    end
    C.originalHit = original
    C.wrappedHit = wrapped
    api.addFromHit = wrapped
    return true
end

Events.OnGameStart.Add(function()
    pcall(function()
        C.active = nil
        C.seen = setmetatable({}, { __mode = "k" })
        C.ticks = 0
        C.installHitGuard()
    end)
end)

Events.OnTick.Add(function()
    C.ticks = C.ticks + 1
    if C.ticks < RETRY_EVERY then return end
    C.ticks = 0
    pcall(function()
        if not C.wanted(true) then return end
        C.installHitGuard()
    end)
end)
end

do
BridgeProjectRemnants = BridgeProjectRemnants or {}
local M = BridgeProjectRemnants

local MOD_ID = "ProjectRemnants"
local STANCE = "defensive"
local ENTER_R2 = 18 * 18
local LEAVE_R2 = 22 * 22
local RESTORE_TICKS = 300
local EVERY = 15

M.state = {}
M.tick = 0
M.logged = false
M.warned = false

local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeProjectRemnants] " .. tostring(text))
    end
end

local function active()
    if BridgeData ~= nil and type(BridgeData.npcfwActive) == "function" then
        return BridgeData.npcfwActive()
    end
    if getActivatedMods == nil then return false end
    local ok, on = pcall(function() return getActivatedMods():contains(MOD_ID) == true end)
    return ok and on == true
end

local function apiReady()
    return type(npcfwSetStance) == "function" and type(npcfwGetStance) == "function"
        and type(npcfwGetPlayerFactionMemberIds) == "function" and type(npcfwGetNPC) == "function"
end

local function stanceOf(npc)
    if npc == nil then return nil end
    local value = nil
    pcall(function() value = npcfwGetStance(npc) end)
    if value == nil then return nil end
    return string.lower(tostring(value))
end

local function setStance(npc, value)
    if npc == nil then return false end
    local ok = pcall(npcfwSetStance, npc, value)
    if ok then
        pcall(function() npc:getModData().npcfwStance = value end)
    end
    return ok
end

local function distance2(npc, body)
    if npc == nil or body == nil then return nil end
    local ok, d2 = pcall(function()
        if math.abs(npc:getZ() - body:getZ()) >= 0.8 then return nil end
        local dx = npc:getX() - body:getX()
        local dy = npc:getY() - body:getY()
        return dx * dx + dy * dy
    end)
    if not ok then return nil end
    return d2
end

local function eachFactionNpc(fn)
    local ok, ids = pcall(npcfwGetPlayerFactionMemberIds)
    if not ok or ids == nil then return end
    pcall(function()
        for _, id in ipairs(ids) do
            local key = tostring(id)
            local npc = nil
            pcall(function() npc = npcfwGetNPC(key) end)
            if npc ~= nil then
                local dead = false
                pcall(function() dead = npc:isDead() == true end)
                if not dead then fn(npc, key) end
            end
        end
    end)
end

local function bodyUsable(body)
    if body == nil then return false end
    local dead = false
    pcall(function() dead = body:isDead() == true end)
    if dead then return false end
    if Bridge ~= nil and type(Bridge.hiddenObjs) == "table" and Bridge.hiddenObjs[body] then
        return false
    end
    return true
end

local function restoreEntry(id, entry)
    if entry == nil then return end
    if entry.phase == "forced" and entry.npc ~= nil and stanceOf(entry.npc) == STANCE then
        setStance(entry.npc, entry.saved or STANCE)
    end
    M.state[id] = nil
end

local function ageMissing()
    for id, entry in pairs(M.state) do
        entry.leaveTicks = (entry.leaveTicks or 0) + EVERY
        if entry.leaveTicks >= RESTORE_TICKS then
            restoreEntry(id, entry)
        end
    end
end

local function process(npc, key, body)
    local d2 = distance2(npc, body)
    local entry = M.state[key]

    if entry == nil then
        if d2 == nil or d2 > ENTER_R2 then return end
        local current = stanceOf(npc)
        if current == nil or current == STANCE or current == "passive" then return end
        if setStance(npc, STANCE) then
            M.state[key] = { npc = npc, saved = current, phase = "forced", leaveTicks = 0 }
            log("forced defensive on " .. key .. " (was " .. tostring(current) .. ")")
        elseif not M.warned then
            M.warned = true
            log("stance call failed; will retry")
        end
        return
    end

    if d2 ~= nil and d2 <= LEAVE_R2 then
        if entry.phase == "forced" then
            entry.leaveTicks = 0
            local current = stanceOf(npc)
            if current ~= nil and current ~= STANCE then
                entry.phase = "overridden"
                entry.saved = nil
                entry.leaveTicks = 0
                log("player override on " .. key)
            end
        end
        return
    end

    entry.leaveTicks = (entry.leaveTicks or 0) + EVERY
    if entry.leaveTicks >= RESTORE_TICKS then
        restoreEntry(key, entry)
    end
end

local function restoreAll()
    for id, entry in pairs(M.state) do
        restoreEntry(id, entry)
    end
end

function M.onTick()
    M.tick = M.tick + 1
    if M.tick % EVERY ~= 0 then return end
    if not active() then return end
    if not apiReady() then
        if not M.warned then
            M.warned = true
            log("NPCFW stance API unavailable; compatibility disabled")
        end
        return
    end
    if not M.logged then
        M.logged = true
        log("compatibility active")
    end

    local body = Bridge ~= nil and Bridge.body or nil
    if not bodyUsable(body) then
        ageMissing()
        return
    end

    eachFactionNpc(function(npc, key) process(npc, key, body) end)
end

function M.reset()
    M.state = {}
    M.tick = 0
    M.logged = false
    M.warned = false
end

if Events ~= nil then
    if Events.OnTick ~= nil then
        Events.OnTick.Add(function() pcall(M.onTick) end)
    end
    if Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function()
            pcall(function()
                M.reset()
                if BridgeData ~= nil then BridgeData.NPCFW_ACTIVE = nil end
            end)
        end)
    end
    if Events.OnGameStop ~= nil then
        Events.OnGameStop.Add(function()
            pcall(function()
                restoreAll()
                M.reset()
            end)
        end)
    end
end

end

do
BridgePz3dAlarm = BridgePz3dAlarm or {}

local BODY_VAR = "NotAloneBody"
local wrapped = {}
local depth = 0
local realGetCell = nil

local function log(text)
    print("[BridgePz3dAlarm] " .. tostring(text))
end

local function warnOnce(text)
    if BridgePz3dAlarm.warned then return end
    BridgePz3dAlarm.warned = true
    log(text)
end

local function isHer(z)
    if z == nil then return false end
    if Bridge ~= nil and Bridge.body == z then return true end
    local marked = false
    pcall(function()
        if z.getVariableBoolean ~= nil then marked = z:getVariableBoolean(BODY_VAR) == true end
    end)
    if marked then return true end
    local md = nil
    pcall(function()
        if z.hasModData ~= nil and z:hasModData() then md = z:getModData() end
    end)
    return md ~= nil and md.notAloneBody == true
end

local function listWithoutHer(list)
    local keep, n = {}, 0
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if not isHer(z) then
            n = n + 1
            keep[n] = z
        end
    end
    return {
        size = function() return n end,
        get = function(_, i) return keep[i + 1] end,
    }
end

local function cellWithoutHer(cell)
    local proxy = {}
    proxy.getZombieList = function()
        local list = cell:getZombieList()
        if list == nil then return nil end
        return listWithoutHer(list)
    end
    proxy.getGridSquare = function(_, x, y, z)
        return cell:getGridSquare(x, y, z)
    end
    return proxy
end

local function withHerHidden(fn, ...)
    depth = depth + 1
    local ok, a, b, c = pcall(fn, ...)
    depth = depth - 1
    if not ok then warnOnce("wrapped call failed: " .. tostring(a)) end
    return a, b, c
end

local function wrap(tbl, key, isMethod)
    if type(tbl) ~= "table" then return false end
    local fn = tbl[key]
    if type(fn) ~= "function" then return false end
    if wrapped[tbl] == nil then wrapped[tbl] = {} end
    if wrapped[tbl][key] then return true end
    wrapped[tbl][key] = true
    if isMethod then
        tbl[key] = function(self, ...) return withHerHidden(fn, self, ...) end
    else
        tbl[key] = function(...) return withHerHidden(fn, ...) end
    end
    return true
end

function BridgePz3dAlarm.install()
    if BridgePz3dAlarm.installed then return BridgePz3dAlarm.installed end
    local n = 0
    if wrap(aparosa_pz3dAlarm, "alarmUpdate") then n = n + 1 end
    if wrap(aparosa_pz3dMinimap, "alarmUpdate") then n = n + 1 end
    if aparosa_pz3dMinimap ~= nil and wrap(aparosa_pz3dMinimap.Panel, "drawZombies", true) then
        n = n + 1
    end
    if n == 0 then return 0 end
    realGetCell = getCell
    getCell = function()
        local cell = realGetCell()
        if depth <= 0 or cell == nil then return cell end
        return cellWithoutHer(cell)
    end
    BridgePz3dAlarm.installed = n
    if BridgeLog ~= nil and BridgeLog.on() then log("installed on " .. n .. " hook(s)") end
    return n
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(BridgePz3dAlarm.install) end)
end
end

do

































BridgeTetris = BridgeTetris or {}

local KEY = "StayWithMeCompanion"
BridgeTetris.KEY = KEY
BridgeTetris.GRID_W = 8
BridgeTetris.GRID_H = 6

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeTetris] " .. tostring(text)) end end
local function warn(text) print("[BridgeTetris] " .. tostring(text)) end
local logged = {}
local function logOnce(text)
    if logged[text] then return end
    logged[text] = true
    log(text)
end
local function warnOnce(text)
    if logged[text] then return end
    logged[text] = true
    warn(text)
end

local function logKey(key, make)
    if logged[key] then return end
    logged[key] = true
    local ok, text = pcall(make)
    log(ok and text or key)
end

local function herBody()
    if Bridge == nil or Bridge.alive == nil or not Bridge.alive() or Bridge.kind ~= "zombie" then return nil end
    return Bridge.body
end



local cache = { tick = nil, body = nil, alive = nil, inv = nil }
local function refresh()
    local tick = Bridge ~= nil and Bridge.tick or nil
    local b0 = Bridge ~= nil and Bridge.body or nil
    if tick == nil or tick ~= cache.tick or b0 ~= cache.body then
        cache.tick, cache.body, cache.alive, cache.inv = tick, b0, nil, nil
        local b = herBody()
        if b ~= nil then
            cache.alive = b
            pcall(function() cache.inv = b:getInventory() end)
        end
    end
end
local function herInv()
    refresh()
    return cache.inv
end
local function herCachedBody()
    refresh()
    return cache.alive
end


function BridgeTetris.isHerMain(container)
    if container == nil then return false end
    local inv = herInv()
    return inv ~= nil and container == inv
end


function BridgeTetris.isHerOwn(container)
    if container == nil then return false end
    local inv = herInv()
    if inv == nil then return false end
    if container == inv then return true end
    local yes = false
    pcall(function() yes = container:getOutermostContainer() == inv end)
    return yes
end


local function isWornBag(item)
    local b = herCachedBody()
    if b == nil or item == nil then return false end
    local yes = false
    pcall(function() yes = item:IsInventoryContainer() and b:isEquippedClothing(item) end)
    return yes
end


function BridgeTetris.definition()
    return {
        gridDefinitions = { {
            size = { width = BridgeTetris.GRID_W, height = BridgeTetris.GRID_H },
            position = { x = 0, y = 0 },
        } },
        isFragile = true,
    }
end

local function tetrisLoaded()
    return TetrisContainerData ~= nil and TetrisEvents ~= nil
end

local function wrapKey()
    local compat = require("InventoryTetris/TetrisModCompatibility")
    if type(compat) ~= "table" or compat.getModContainerKey == nil then return false end
    if compat.bridgeWrapped then return true end
    local getKey = compat.getModContainerKey
    compat.getModContainerKey = function(container, ...)
        if BridgeTetris.isHerMain(container) then
            logKey("key", function() return "her grid key served: " .. KEY end)
            return KEY
        end
        return getKey(container, ...)
    end
    compat.bridgeWrapped = true
    return true
end

local function registerDefinition()
    local data = TetrisContainerData
    if data == nil or data.registerContainerDefinitions == nil then return false end
    data.registerContainerDefinitions({ [KEY] = BridgeTetris.definition() })


    if type(data._containerDefinitions) == "table" and data._containerDefinitions[KEY] == nil then
        data._containerDefinitions[KEY] = BridgeTetris.definition()
    end
    return true
end

local function wrapContainerGrid()
    local ICG = require("InventoryTetris/Model/ItemContainerGrid")
    if type(ICG) ~= "table" or ICG.bridgeWrapped then return type(ICG) == "table" end

    local isItemValid = ICG._isItemValid
    if isItemValid ~= nil then
        ICG._isItemValid = function(self, item, ...)
            if BridgeTetris.isHerMain(self.inventory) and isWornBag(item) then
                logKey("wornbag", function() return "worn bag not in her grid: " .. item:getFullType() end)
                return false
            end
            return isItemValid(self, item, ...)
        end
    end

    local canAddItem = ICG.canAddItem
    if canAddItem ~= nil then
        ICG.canAddItem = function(self, item, ...)
            if not BridgeTetris.isHerMain(self.inventory) then return canAddItem(self, item, ...) end
            local allowed = self:isItemAllowed(item)
            if allowed and not logged["overflow"] and not canAddItem(self, item, ...) then
                logKey("overflow", function() return "no free cell in her grid for " .. item:getFullType() .. ": goes to the overflow list" end)
            end
            return allowed
        end
    end


    local validate = ICG.validateCapacityRestrictions
    if validate ~= nil then
        ICG.validateCapacityRestrictions = function(self, item, container, playerObj, ...)
            if BridgeTetris.isHerMain(container) and BridgeInventory ~= nil and BridgeInventory.roomVerdict ~= nil then
                local inside = false
                pcall(function() inside = item:getContainer() == container end)
                local strict = false
                pcall(function() strict = SandboxVars.InventoryTetris.EnforceCarryWeight or isClient() end)
                if not inside and strict then
                    local verdict = nil
                    pcall(function() verdict = BridgeInventory.roomVerdict(container, playerObj, item) end)
                    if verdict ~= nil then
                        if not verdict then logKey("room", function() return "room check: no room for " .. item:getFullType() end) end
                        return verdict
                    end
                end
            end
            return validate(self, item, container, playerObj, ...)
        end
    end
    ICG.bridgeWrapped = true
    return true
end

local function wrapSearch()
    local IG = require("InventoryTetris/Model/ItemGrid")
    if type(IG) ~= "table" or IG.isUnsearched == nil then return false end
    if IG.bridgeWrapped then return true end
    local isUnsearched = IG.isUnsearched
    IG.isUnsearched = function(self, ...)
        if not isUnsearched(self, ...) then return false end
        return not BridgeTetris.isHerOwn(self.inventory)
    end
    IG.bridgeWrapped = true
    return true
end

local BASIC_INV_TEXTURE = nil

local function wrapTitle()
    local UI = require("InventoryTetris/UI/Container/ItemGridContainerUI")
    if type(UI) ~= "table" or UI.getInventoryName == nil then return false end
    if rawget(UI, "bridgeWrapped") then return true end
    local getInventoryName = UI.getInventoryName
    UI.getInventoryName = function(self, inventory, ...)
        if BridgeTetris.isHerMain(inventory) then
            local name = nil
            pcall(function() name = Bridge.companionName() end)
            if name ~= nil and name ~= "" then return name end
        end
        return getInventoryName(self, inventory, ...)
    end
    local updateContainerTexture = UI.updateContainerTexture
    if updateContainerTexture ~= nil then


        UI.updateContainerTexture = function(self, container, ...)
            if BridgeTetris.isHerMain(container) then
                BASIC_INV_TEXTURE = BASIC_INV_TEXTURE or getTexture("media/ui/Icon_InventoryBasic.png")
                if BASIC_INV_TEXTURE ~= nil then
                    self.invTexture = BASIC_INV_TEXTURE
                    return
                end
            end
            return updateContainerTexture(self, container, ...)
        end
    end
    UI.bridgeWrapped = true
    return true
end





local function wrapWeight()
    local GCI = require("InventoryTetris/UI/Container/GridContainerInfo")
    if type(GCI) ~= "table" or GCI.prerender == nil then return false end
    if rawget(GCI, "bridgeWrapped") then return true end
    local prerender = GCI.prerender
    GCI.prerender = function(self, ...)
        pcall(function()
            local ui = self.containerUi
            if ui == nil or not BridgeTetris.isHerMain(ui.inventory) then return end
            local b = herBody()
            local theirs = round(ui.inventory:getCapacityWeight(), 1)
            local ours = round(BridgeInventory.mainLoad(b), 1)



            local cap = BridgeInventory.capacity or 15
            pcall(function() cap = ui.inventory:getEffectiveCapacity(ui.player) end)
            self.lastWeight = theirs
            self.weightText = ours .. " / " .. cap
        end)
        return prerender(self, ...)
    end
    GCI.bridgeWrapped = true
    return true
end




local markTex = nil
local hotTex = nil
BridgeTetris.marksDrawn = 0
local Marks = {}
function Marks.call(eventData, drawingContext, renderInstructions, instructionCount, playerObj)
    if drawingContext == nil then return end

    local inv = drawingContext.grid ~= nil and drawingContext.grid.inventory or drawingContext.inventory
    if inv == nil or not BridgeTetris.isHerMain(inv) then return end
    local b = herCachedBody()
    local jo = drawingContext.javaObject
    if b == nil or jo == nil then return end
    markTex = markTex or getTexture("media/ui/icon.png")
    hotTex = hotTex or getTexture("media/ui/iconInHotbar.png")
    for r = 1, instructionCount do
        local ins = renderInstructions[r]
        if ins ~= nil and not ins[9] then
            local item = ins[2]
            local tex = nil
            if item ~= nil then
                if b:isEquipped(item) then
                    tex = markTex
                elseif BridgeWeapon ~= nil and BridgeWeapon.isAssigned(b, item) then
                    tex = hotTex
                end
            end
            if tex ~= nil then
                jo:DrawTexture(tex, ins[3] + 2, ins[4] + 2, 1)
                BridgeTetris.marksDrawn = BridgeTetris.marksDrawn + 1
            end
        end
    end
end
BridgeTetris.Marks = Marks

local function addMarks()
    if TetrisEvents == nil or TetrisEvents.OnPostRenderGrid == nil then return false end
    if BridgeTetris.marksAdded then return true end
    TetrisEvents.OnPostRenderGrid:add({ call = function(...)
        local ok, err = pcall(Marks.call, ...)
        if not ok then warnOnce("marks failed: " .. tostring(err)) end
    end })
    BridgeTetris.marksAdded = true
    return true
end





local function wrapRelayTarget()
    local A = ISInventoryTransferAction
    if A == nil or A.setTetrisTarget == nil then return false end
    if A.bridgeTargetWrapped then return true end
    local setTetrisTarget = A.setTetrisTarget
    A.setTetrisTarget = function(self, ...)
        if self.bridgeRelay ~= nil or self.finalDest ~= nil or self.bridgeDir ~= nil then
            logOnce("grid cell not used for her relayed transfer: placed automatically")
            return
        end
        return setTetrisTarget(self, ...)
    end
    A.bridgeTargetWrapped = true
    return true
end







local function wrapRelayRules()
    local A = ISInventoryTransferAction
    if A == nil or A.validateTetrisRules == nil then return false end
    if rawget(A, "bridgeRulesWrapped") then return true end
    local validateTetrisRules = A.validateTetrisRules
    A.validateTetrisRules = function(self, ...)
        local relay = self.bridgeRelay
        if relay ~= nil and relay.dest ~= nil then
            local fits = true
            pcall(function() fits = relay.dest:hasRoomFor(self.character, self.item) ~= false end)
            if not fits then logKey("relayroom", function() return "relay to her: no room at her for " .. self.item:getFullType() end) end
            return fits
        end
        return validateTetrisRules(self, ...)
    end
    A.bridgeRulesWrapped = true
    return true
end





local function wrapTakeRules()
    local T = BridgeTransferAction
    if T == nil or T.isValid == nil then return false end
    if rawget(T, "bridgeTetrisWrapped") then return true end
    local isValid = T.isValid
    T.isValid = function(self, ...)
        local ok = isValid(self, ...)
        if ok and self.bridgeDir == "take" and self.enforceTetrisRules and not self.started and not self.sent
            and self.validateTetrisRules ~= nil then
            local fits = true
            pcall(function() fits = self:validateTetrisRules() ~= false end)
            if not fits then
                logKey("takeroom", function() return "take from her: no free cell in player's grid for " .. self.item:getFullType() end)
                return false
            end
        end
        return ok
    end
    T.bridgeTetrisWrapped = true
    return true
end



function BridgeTetris.install()
    if BridgeTetris.installed then return true end
    if not tetrisLoaded() then
        logOnce("Inventory Tetris not active")
        return false
    end
    local done, failed = {}, {}

    for _, step in ipairs({ { "definition", registerDefinition }, { "key", wrapKey }, { "grid", wrapContainerGrid },
                            { "search", wrapSearch }, { "title", wrapTitle }, { "weight", wrapWeight },
                            { "marks", addMarks }, { "relay", wrapRelayTarget },
                            { "relayrules", wrapRelayRules }, { "take", wrapTakeRules } }) do
        local ok, res = pcall(step[2])
        if ok and res then done[#done + 1] = step[1] else failed[#failed + 1] = step[1] .. (ok and "" or (": " .. tostring(res))) end
    end
    BridgeTetris.installed = true
    log(string.format("Inventory Tetris: her grid %dx%d (%s), hooks: %s%s", BridgeTetris.GRID_W, BridgeTetris.GRID_H, KEY,
        table.concat(done, ","), #failed > 0 and ("; failed: " .. table.concat(failed, ", ")) or ""))
    return true
end

local tetrisRetry = 0

Events.OnGameStart.Add(function()
    pcall(function()
        tetrisRetry = 0
        BridgeTetris.install()
    end)
end)

Events.OnTick.Add(function()
    if BridgeTetris.installed then return end
    tetrisRetry = tetrisRetry + 1
    if tetrisRetry < 60 then return end
    tetrisRetry = 0
    pcall(BridgeTetris.install)
end)
end

do
    BridgeEFZCompat = BridgeEFZCompat or {}
    local installed = false
    local reported = false

    local function patch(body)
        if installed or body == nil then return installed end
        local zombie = false
        pcall(function() zombie = instanceof(body, "IsoZombie") == true end)
        if not zombie then return false end
        local ok, mt = pcall(getmetatable, body)
        if not ok or type(mt) ~= "table" then return false end
        local index = mt.__index
        if type(index) ~= "table" then return false end
        if rawget(index, "isLocalPlayer") == nil then
            rawset(index, "isLocalPlayer", function() return false end)
        end
        installed = true
        if not reported then
            reported = true
            print("[BridgeCompat] installed IsoZombie.isLocalPlayer guard for EFZ equip events")
        end
        return true
    end

    function BridgeEFZCompat.patchBody(body) return patch(body) end
    function BridgeEFZCompat.installed() return installed end

    local function fromWorld()
        if installed then return true end
        local cell = nil
        pcall(function() cell = getCell() end)
        if cell == nil then return false end
        local list = nil
        pcall(function() list = cell:getZombieList() end)
        if list == nil or list:size() == 0 then return false end
        return patch(list:get(0))
    end

    Events.OnGameStart.Add(function()
        pcall(fromWorld)
        pcall(function() patch(Bridge ~= nil and Bridge.body or nil) end)
    end)

    local tries = 0
    Events.OnTick.Add(function()
        if installed then return end
        tries = tries + 1
        if tries % 30 ~= 0 then return end
        pcall(fromWorld)
        pcall(function() patch(Bridge ~= nil and Bridge.body or nil) end)
    end)

    local targets = nil
    local targetsTried = false
    local sentBody = nil

    local function gripTargets()
        if targets ~= nil then return targets end
        if targetsTried then return nil end
        targetsTried = true
        local ok, mod = pcall(require, "TW/GripTargets")
        if ok and type(mod) == "table" then targets = mod end
        return targets
    end

    local function gripOff()
        if sentBody ~= nil then
            local zb = rawget(_G, "TWZB")
            if zb ~= nil and type(zb.gripIKOff) == "function" then pcall(zb.gripIKOff, sentBody) end
        end
        sentBody = nil
    end

    local function gripBusy()
        return BridgeGunfight ~= nil and (BridgeGunfight.reloadStage ~= nil or BridgeGunfight.magCareStage ~= nil)
    end

    local function gripUpdate()
        local zb = rawget(_G, "TWZB")
        local body = Bridge ~= nil and Bridge.body or nil
        if body == nil or Bridge == nil or Bridge.kind ~= "zombie" or zb == nil or type(zb.gripIK) ~= "function" then
            gripOff()
            return
        end
        local zombie = false
        pcall(function() zombie = instanceof(body, "IsoZombie") == true end)
        if not zombie then gripOff() return end
        local dead = false
        pcall(function() dead = body:isDead() == true end)
        if dead then gripOff() return end
        local mods = gripTargets()
        if mods == nil then gripOff() return end
        local gun = nil
        pcall(function() gun = body:getPrimaryHandItem() end)
        local busy = gripBusy()
        local value = nil
        if gun ~= nil and not busy then
            pcall(function() value = mods.forGun(gun, body:isFemale()) end)
        end
        if not value then gripOff() return end
        if sentBody ~= nil and sentBody ~= body then gripOff() end
        local moving = false
        pcall(function() moving = body:isMoving() == true end)
        local ok = pcall(zb.gripIK, body, gun, mods.carryParams(value, moving))
        if not ok then gripOff() return end
        if type(zb.gripIKActing) == "function" then pcall(zb.gripIKActing, body, false) end
        sentBody = body
    end

    function BridgeEFZCompat.updateGrip() return gripUpdate() end

    Events.OnTick.Add(function() pcall(gripUpdate) end)
end
