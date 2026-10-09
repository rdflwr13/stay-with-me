




BridgeSkills = BridgeSkills or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeSkills] " .. tostring(text)) end end
BridgeSkills.PHASE = 5

BridgeSkills.TRACKED = BridgeData.SKILL_KEYS
BridgeSkills.MAX_LEVEL = 10
BridgeSkills.DEBUG = false
BridgeSkills.FLUSH_TICKS = 600
BridgeSkills.xpAccum = BridgeSkills.xpAccum or {}
BridgeSkills.pops = BridgeSkills.pops or {}

function BridgeSkills.store()
    if Bridge.store == nil then return nil end
    return BridgeData.skillsOf(Bridge.store)
end

function BridgeSkills.get(perk)
    local s = BridgeSkills.store()
    if s == nil or s[perk] == nil then return 0 end
    return tonumber(s[perk]) or 0
end


local perkCache = {}
local function perkOf(name)
    local p = perkCache[name]
    if p ~= nil then return p end
    pcall(function() p = PerkFactory.getPerk(Perks[name]) end)
    if p ~= nil then perkCache[name] = p end
    return p
end
BridgeSkills.perkOf = perkOf

local function levelForXp(p, xp)
    if p == nil then return 0 end
    local lvl = 0
    for n = 1, BridgeSkills.MAX_LEVEL do
        local total = nil
        pcall(function() total = p:getTotalXpForLevel(n) end)
        if total == nil or xp < total then break end
        lvl = n
    end
    return lvl
end
BridgeSkills.levelForXp = levelForXp


function BridgeSkills.level(perk)
    return levelForXp(perkOf(perk), BridgeSkills.get(perk))
end


function BridgeSkills.progress(perk)
    local xp = BridgeSkills.get(perk)
    local p = perkOf(perk)
    if p == nil then return 0 end
    local lvl = levelForXp(p, xp)
    if lvl >= BridgeSkills.MAX_LEVEL then return 1 end
    local base, need = 0, nil
    if lvl > 0 then pcall(function() base = p:getTotalXpForLevel(lvl) end) end
    pcall(function() need = p:getXpForLevel(lvl + 1) end)
    if need == nil or need <= 0 then return 0 end
    local frac = (xp - base) / need
    if frac < 0 then frac = 0 end
    if frac > 1 then frac = 1 end
    return frac
end


local WEAPON_CATEGORY_PERK = {
    { "AXE", "Axe" }, { "BLUNT", "Blunt" }, { "SMALL_BLUNT", "SmallBlunt" },
    { "LONG_BLADE", "LongBlade" }, { "SMALL_BLADE", "SmallBlade" }, { "SPEAR", "Spear" },
}

function BridgeSkills.categoryFor(item)
    if item == nil then return nil end
    local script = nil
    pcall(function() script = item:getScriptItem() end)
    if script == nil then return nil end
    for i = 1, #WEAPON_CATEGORY_PERK do
        local e = WEAPON_CATEGORY_PERK[i]
        local wc = nil
        pcall(function() wc = WeaponCategory[e[1]] end)
        if wc ~= nil then
            local match = false
            pcall(function() match = script:containsWeaponCategory(wc) end)
            if match then return e[2] end
        end
    end
    return nil
end







function BridgeSkills.rollMaintenance(item)
    if item == nil then return 0 end

    local ranged = false
    pcall(function() ranged = item:isRanged() end)
    if ranged then return 0 end

    local full = nil
    pcall(function() full = item:getFullType() end)
    if full == "Base.BareHands" then return 0 end

    local oneIn = nil
    pcall(function() oneIn = item:getConditionLowerChance() end)
    if oneIn == nil then pcall(function() oneIn = item:getConditionLowerChanceOneIn() end) end
    if oneIn == nil then
        local script = nil
        pcall(function() script = item:getScriptItem() end)
        if script ~= nil then
            pcall(function() oneIn = script:getConditionLowerChanceOneIn() end)
            if oneIn == nil then pcall(function() oneIn = script:getConditionLowerChance() end) end
        end
    end
    oneIn = tonumber(oneIn)
    if oneIn == nil or oneIn ~= oneIn or oneIn <= 0 then return 0 end

    if ZombRand(100) >= 50 then return 0 end
    if oneIn > 10 then return 2 * 10 / oneIn end
    return 2
end




function BridgeSkills.applyCarry(explicitBody)
    local body = explicitBody or Bridge.body
    if body == nil then return end
    local cap = BridgeData.carryForStrengthLevel(BridgeSkills.level("Strength"))
    if cap == nil then return end


    local setw = nil
    pcall(function() setw = body.setMaxWeight end)
    if setw ~= nil then pcall(function() body:setMaxWeight(cap) end) end
    pcall(function() body:getInventory():setCapacity(cap) end)
end




local function xpMultiplier(perk)
    local cfg = nil
    pcall(function() cfg = SandboxVars ~= nil and SandboxVars.MultiplierConfig or nil end)
    if cfg == nil then return 1 end
    local mult = nil
    pcall(function()
        if cfg.GlobalToggle == true then
            mult = tonumber(cfg.Global)
        else
            mult = tonumber(cfg[perk])
        end
    end)
    if mult == nil or mult ~= mult or mult <= 0 then return 1 end
    return mult
end
BridgeSkills.xpMultiplier = xpMultiplier



function BridgeSkills.add(perk, amount, reason, skipMultiplier)
    local s = BridgeSkills.store()
    if s == nil or s[perk] == nil then return 0 end
    amount = tonumber(amount)
    if amount == nil or amount ~= amount or amount <= 0 then return 0 end


    if not skipMultiplier then amount = amount * xpMultiplier(perk) end
    local p = perkOf(perk)
    local cap = nil
    if p ~= nil then pcall(function() cap = p:getTotalXpForLevel(BridgeSkills.MAX_LEVEL) end) end
    local before = tonumber(s[perk]) or 0
    local after = before + amount
    if cap ~= nil and after > cap then after = cap end
    if after == before then return before end
    s[perk] = after
    BridgeSkills.noteXp(perk, after - before)
    local oldLvl = levelForXp(p, before)
    local newLvl = levelForXp(p, after)
    if BridgeSkills.DEBUG then
        log(string.format("+%.2f %s (%s) %.1f -> %.1f L%d", amount, tostring(perk),
            tostring(reason or ""), before, after, newLvl))
    end
    if newLvl > oldLvl then
        BridgeSkills.lastLevelUp = { perk = perk, from = oldLvl, to = newLvl, tick = Bridge.time or 0 }
        pcall(function() BridgeSkills.onLevel(perk, newLvl) end)
        BridgeSkills.flush()
        if perk == "Strength" then pcall(BridgeSkills.applyCarry) end
    else
        BridgeSkills.dirty = true
    end
    return after
end


function BridgeSkills.perkLabel(perk)
    local label = nil
    pcall(function() label = getTextOrNull("IGUI_perks_" .. tostring(perk)) end)
    if label == nil or label == "" then label = tostring(perk) end
    return label
end





function BridgeSkills.onLevel(perk, lvl)
    log(string.format("LEVELUP %s -> %d", tostring(perk), lvl))
    BridgeSkills.levelUpAt = Bridge.time or 0
    BridgeSkills.xpAccum = {}
    BridgeSkills.xpAt = nil
    if Bridge.body == nil then return end
    pcall(function() Bridge.body:addLineChatElement(BridgeData.text("SkillLevelUp", BridgeSkills.perkLabel(perk)), 0.4, 0.9, 0.4) end)
    pcall(function() Bridge.body:playSound("GainExperienceLevel") end)
    BridgeSkills.sayAt = (Bridge.time or 0) + 90
    BridgeSkills.sayTries = 0
end





local XP_FLUSH_TICKS = 45
local POP_LIFE_MS = 2000
local POP_RISE = 22
local POP_BASE = 14
local POP_COLOR = { 0.4, 0.9, 0.4 }

function BridgeSkills.noteXp(perk, amount)
    amount = tonumber(amount)
    if amount == nil or amount ~= amount or amount <= 0 then return end
    BridgeSkills.xpAccum[perk] = (BridgeSkills.xpAccum[perk] or 0) + amount
    if BridgeSkills.xpAt == nil then BridgeSkills.xpAt = (Bridge.time or 0) + XP_FLUSH_TICKS end
end



function BridgeSkills.popXp(perk, amount)
    if Bridge.body == nil then return end
    if not BridgeData.optionOf(Bridge.store, "xpPopups") then return end
    local pops = BridgeSkills.pops
    pops[#pops + 1] = { perk = perk, amount = amount, t0 = getTimestampMs() }
    if BridgeSkills.DEBUG then
        log(string.format("pop +%.1f %s (%d active)", amount, tostring(perk), #pops))
    end
end

local function flushXp()
    if Bridge.body == nil then return end
    local accum = BridgeSkills.xpAccum
    for k, v in pairs(accum) do
        if v > 0 then
            BridgeSkills.popXp(k, v)
            accum[k] = nil
        end
    end
    BridgeSkills.xpAt = nil
end




local function drawPops()
    local pops = BridgeSkills.pops
    if #pops == 0 then return end
    local z = Bridge.body
    if z == nil then return end
    local player = BridgeData.owner()
    if player == nil then return end
    local pn = player:getPlayerNum()
    local tm = getTextManager()
    local now = getTimestampMs()
    local i = 1
    while i <= #pops do
        local p = pops[i]
        local age = now - p.t0
        if age >= POP_LIFE_MS then
            table.remove(pops, i)
        else
            local frac = age / POP_LIFE_MS
            local alpha = 1 - frac
            local rowH = tm:getFontHeight(UIFont.Small) + 2
            local zoom = getCore():getZoom(pn)
            local lift = 128 * Core.getTileScale() / 2 / zoom
            local x = isoToScreenX(pn, z:getX(), z:getY(), z:getZ())
            local y = isoToScreenY(pn, z:getX(), z:getY(), z:getZ())
                - lift - tm:getFontHeight(UIFont.Small) - POP_BASE - POP_RISE * frac - (i - 1) * rowH
            local text = BridgeData.text("SkillXpPop", BridgeSkills.perkLabel(p.perk), string.format("%.1f", p.amount))
            tm:DrawStringCentre(UIFont.Small, x - 1, y, text, 0, 0, 0, alpha * 0.8)
            tm:DrawStringCentre(UIFont.Small, x + 1, y, text, 0, 0, 0, alpha * 0.8)
            tm:DrawStringCentre(UIFont.Small, x, y - 1, text, 0, 0, 0, alpha * 0.8)
            tm:DrawStringCentre(UIFont.Small, x, y + 1, text, 0, 0, 0, alpha * 0.8)
            tm:DrawStringCentre(UIFont.Small, x, y, text, POP_COLOR[1], POP_COLOR[2], POP_COLOR[3], alpha)
            i = i + 1
        end
    end
end


local function sayTick()
    if BridgeSkills.sayAt == nil then return end
    if (Bridge.time or 0) < BridgeSkills.sayAt then return end
    local ok = false
    pcall(function() ok = BridgeMoments ~= nil and BridgeMoments.say("EvSkillUp", 0, "soft") end)
    if ok then
        BridgeSkills.sayAt = nil
        BridgeSkills.sayTries = 0
    else
        local tries = (BridgeSkills.sayTries or 0) + 1

        if tries >= 7 then
            BridgeSkills.sayAt = nil
            BridgeSkills.sayTries = 0
        else
            BridgeSkills.sayTries = tries
            BridgeSkills.sayAt = (Bridge.time or 0) + 60
        end
    end
end

local function xpTick()
    if BridgeSkills.xpAt == nil then return end
    if (Bridge.time or 0) < BridgeSkills.xpAt then return end
    BridgeSkills.xpAt = nil
    pcall(flushXp)
end


















local runWasX, runWasY = nil, nil
local function runTick()
    if Bridge.body == nil then return end
    if (Bridge.time or 0) < (BridgeSkills.runAt or 0) then return end
    BridgeSkills.runAt = (Bridge.time or 0) + 60
    if BridgeMove == nil or BridgeMove.walkType ~= "Run" then
        runWasX, runWasY = nil, nil
        return
    end
    local body = Bridge.body
    local x, y = nil, nil
    pcall(function() x, y = body:getX(), body:getY() end)
    local moved = true
    if x ~= nil and runWasX ~= nil then moved = (x ~= runWasX) or (y ~= runWasY) end
    runWasX, runWasY = x, y
    if not moved then return end
    local endur, warn = 1.0, 0.5
    pcall(function() endur = body:getStats():get(CharacterStat.ENDURANCE) end)
    pcall(function() warn = body:getStats():getEnduranceWarning() end)
    if endur <= warn then return end



    if ZombRand(1000) < 50 then BridgeSkills.add("Fitness", 1, "run") end
end

function BridgeSkills.summary()
    local s = BridgeSkills.store()
    if s == nil then return "skills: no store" end
    local out = {}
    for i = 1, #BridgeSkills.TRACKED do
        local k = BridgeSkills.TRACKED[i]
        out[#out + 1] = k .. "=" .. tostring(s[k]) .. "(L" .. tostring(BridgeSkills.level(k)) .. ")"
    end
    return table.concat(out, " ")
end


function BridgeSkills.flush()
    BridgeSkills.dirty = false
    if not Bridge.mp then return end
    local s = BridgeSkills.store()
    if s == nil then return end
    Bridge.localSkills = s
    BridgeSkills.sentAt = Bridge.time or 0
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "state", { skills = BridgeData.cleanSkills(s) })
    end)
end


local function flushTick()
    if not BridgeSkills.dirty then return end
    if Bridge.mp and (Bridge.time or 0) - (BridgeSkills.sentAt or -99999) < BridgeSkills.FLUSH_TICKS then return end
    BridgeSkills.flush()
end
BridgeSkills.flushTick = flushTick












































local function installWrappers()


















    if type(Bridge.refreshStore) == "function" and not BridgeSkills._refreshWrapped then
        BridgeSkills._refreshWrapped = true
        local baseRefresh = Bridge.refreshStore
        Bridge.refreshStore = function()
            baseRefresh()
            if Bridge.store == nil then return end
            BridgeData.skillsOf(Bridge.store)
            if Bridge.mp then
                local incoming = Bridge.store.skills
                if Bridge.localSkills ~= nil and incoming ~= Bridge.localSkills then
                    Bridge.store.skills = Bridge.localSkills
                elseif Bridge.localSkills == nil and type(incoming) == "table" then
                    Bridge.localSkills = incoming
                end
            end
        end
    end
end

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(installWrappers)
    Events.OnGameStart.Add(function()
        pcall(function()
            if Bridge.store == nil then return end
            BridgeData.skillsOf(Bridge.store)
            log("SKILLS " .. BridgeSkills.summary())
        end)
    end)
end
if type(Bridge) == "table" and type(Bridge.run) == "function" then
    installWrappers()
end


if type(Events) == "table" and Events.OnTick ~= nil then
    Events.OnTick.Add(function()
        pcall(sayTick)
        pcall(xpTick)
        pcall(runTick)
        pcall(flushTick)
    end)
end

if type(Events) == "table" and Events.OnPreUIDraw ~= nil then
    Events.OnPreUIDraw.Add(function() pcall(drawPops) end)
end

log("loaded")
