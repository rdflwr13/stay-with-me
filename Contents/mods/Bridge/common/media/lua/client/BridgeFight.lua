



BridgeFight = BridgeFight or {}

local PRONE_BONUS = 2.0
local PRONE_BONUS_RANGE = 4.0
local FENCE_HOP_PENALTY = 1.5


local TIRED_SAY = 0.5
local RESTED_SAY = 0.2

local ATTACK_TIME = 28
local SWING_LEN = 60
local SWING_MIN = 35
local SWING_MAX = 120
local HIT_FALLBACK_MAX = 50




local SWING_BY_ANIM = { Stab = 40, Bat = 55, Heavy = 75, Spear = 60, Shove = 45 }




local HIT_REACTION = {
    Attack2H1 = "HeadLeft", Attack2H2 = "HeadTop", Attack2H3 = "Uppercut", Attack2H4 = "HeadLeft", Attack2HFloor = "Floor",
    Attack1H1 = "HeadLeft", Attack1H2 = "HeadTop", Attack1H3 = "Uppercut", Attack1H4 = "HeadLeft", Attack1H5 = "HeadTop",
    Attack1HFloor = "Floor", AttackS1 = "HeadRight", AttackS2 = "HeadRight", AttackS1Floor = "Floor",
    AttackKnife = "Uppercut", AttackKnifeFloor = "Floor", AttackStomp = "Floor",

    AttackKnifeB = "Uppercut", AttackKnifeFloorB = "Floor", AttackStompB = "Floor", Attack1HFloorB = "Floor",
    Attack2HFloorB = "Floor", AttackS1FloorB = "Floor", AttackS1B = "HeadRight", AttackS2B = "HeadRight",
}

local CRIT_REACTION = {
    AttackS1 = "HitSpearDeath1", AttackS2 = "HitSpearDeath1",
    AttackS1B = "HitSpearDeath1", AttackS2B = "HitSpearDeath1",
    AttackKnife = "KnifeDeath", AttackKnifeB = "KnifeDeath",
}

do
    local add = {}
    for k, v in pairs(HIT_REACTION) do add[#add + 1] = { k, v } end
    for _, kv in ipairs(add) do
        local b = kv[1] .. "Bwd"
        if HIT_REACTION[b] == nil then HIT_REACTION[b] = kv[2] end
        local nb = "NA_" .. b
        if HIT_REACTION[nb] == nil then HIT_REACTION[nb] = kv[2] end
    end
    local addc = {}
    for k, v in pairs(CRIT_REACTION) do addc[#addc + 1] = { k, v } end
    for _, kv in ipairs(addc) do
        local b = kv[1] .. "Bwd"
        if CRIT_REACTION[b] == nil then CRIT_REACTION[b] = kv[2] end
        local nb = "NA_" .. b
        if CRIT_REACTION[nb] == nil then CRIT_REACTION[nb] = kv[2] end
    end
end

local SECOND_NODE = { AttackKnife = true, AttackKnifeFloor = true, AttackStomp = true, Attack1HFloor = true,
    Attack2HFloor = true, AttackS1Floor = true, AttackS1 = true, AttackS2 = true }
local HIT_VAR = "NotAloneHitNow"


local ATTACK_NODES = {}
for _, n in ipairs({ "Attack2H1", "Attack2H2", "Attack2H3", "Attack2H4", "Attack2HFloor", "Attack2HFloorB",
    "Attack1H1", "Attack1H2", "Attack1H3", "Attack1H4", "Attack1H5", "Attack1HFloor", "Attack1HFloorB",
    "AttackS1", "AttackS2", "AttackS1B", "AttackS2B", "AttackS1Floor", "AttackS1FloorB", "AttackKnife", "AttackKnifeB", "AttackKnifeFloor",
    "AttackKnifeFloorB", "AttackStomp", "AttackStompB", "AttackBareHands1", "AttackBareHands2", "AttackBareHands3",
    "AttackBareHands4", "AttackBareHands5", "AttackBareHands6", "Shove" }) do ATTACK_NODES[n] = true end
function BridgeFight.isAttackNode(name) return type(name) == "string" and ATTACK_NODES[name] == true end

local BACK_ATTACK = {
    Attack1H1 = true, Attack1H2 = true, Attack1H3 = true, Attack1H4 = true, Attack1H5 = true,
    Attack2H1 = true, Attack2H2 = true, Attack2H3 = true, Attack2H4 = true,
    AttackS1 = true, AttackS2 = true, AttackKnife = true,
    AttackBareHands1 = true, AttackBareHands2 = true, AttackBareHands3 = true,
    AttackBareHands4 = true, AttackBareHands5 = true, AttackBareHands6 = true,
}
for base in pairs(BACK_ATTACK) do ATTACK_NODES["NA_" .. base .. "Bwd"] = true end
local function backAttackNode(name)
    if name == nil then return nil end
    local base = name
    if base == "AttackS1B" then base = "AttackS1"
    elseif base == "AttackS2B" then base = "AttackS2"
    elseif base == "AttackKnifeB" then base = "AttackKnife"
    end
    if BACK_ATTACK[base] == true then return "NA_" .. base .. "Bwd" end
    return nil
end

local BARRIER_STATE = { thump = true, climbfence = true, climbwindow = true }
local SWING_DEFAULT = 55


local STALE_END_MAX = 40

















local CRIT_PER_LEVEL = 3
local SKILL_DMG_PER_LEVEL = 0.10
local SKILL_SPEED_PER_LEVEL = 0.03
local STR_DMG_PER_LEVEL = 0.05
local STR_CENTER = 5
local STR_PUSH_BASE = 0.75
local STR_PUSH_PER_LEVEL = 0.05
local FIT_SPEED_PER_LEVEL = 0.02
local FIT_DRAIN_BASE = 1.00
local FIT_DRAIN_PER_LEVEL = 0.057
local FIT_DRAIN_MIN = 0.43
local FIT_RECOVER_BASE = 1.00
local FIT_RECOVER_PER_LEVEL = 0.06
local FIT_RECOVER_MAX = 1.60
local TIRED_CRIT = 20
local MISS_CHANCE = 15
local CROWD_RADIUS = 2.0
local CROWD_MISS = 0
local CROWD_MISS_MAX = 0







local END_BASE_SCALE = 0.28
local END_WEIGHT_MOD = 0.3
local END_FINAL = 0.04
local FATIGUE_MULT = 1.0
local END_TWOHAND_DIV = 1.5
local END_TWOHAND_SCALE = 10
local END_CLOSE_KILL = 0.2


local CHOP_STAMINA_MULT = 0.5
local FATIGUE_REST = 1 / 10800
local FATIGUE_REST_SIT = 2
local FATIGUE_REST_BUSY = 0.5
local TIRED_SWING = 0.5
local TIRED_MISS = 15
local TIRED_DAMAGE = 0.25
local PICK_EVERY = 10
local APPROACH_MAX = 150
local BLACKLIST_TICKS = 900
local MULTIHIT_ON = 1
local NO_CLIMB_ON = 1
local COMBATTEXT_ON = 1
local GROUND_BONUS_ON = 1
local MULTIHIT_MAX = 4
local HEAD_SPLIT = 3.0
local REACH_TTL = 120
local REACH_NODES = 240
local STUCK_TICKS = 60
local STUCK_MOVE = 0.4
local REACH_CACHE_MAX = 400
local reachCache = setmetatable({}, { __mode = "k" })
local reachCacheN = 0




local SHOVE_ON            = 1
local SHOVE_UNARMED       = 1
local SHOVE_DEFENSIVE     = 1
local SHOVE_RANGE         = 1.3
local SHOVE_DOT           = 0.5
local SHOVE_MAX           = 3
local SHOVE_MIN_CROWD     = 2
local SHOVE_PANIC_RANGE   = 0.85
local SHOVE_COOLDOWN      = 120
local SHOVE_FORCE_MULT    = 1.0
local SHOVE_KNOCKDOWN     = 1
local SHOVE_BEHIND_BONUS  = 5
local SHOVE_BEHIND_UNARMED_BONUS = 30

BridgeFight.enabled = true
BridgeFight.guardOnly = false
BridgeFight.target = nil
BridgeFight.state = "idle"
BridgeFight.swingStart = 0
BridgeFight.hit = false
BridgeFight.lastPick = 0
BridgeFight.info = "none"
BridgeFight.approachStart = 0
BridgeFight.playerFightUntil = 0
BridgeFight.playerTarget = nil
BridgeFight.lastHitChar = nil
BridgeFight.lastHitHealth = nil



BridgeFight.blacklist = {}

local function numberBan(z, b)
    if type(b) ~= "number" then return false end
    if b > (Bridge.tick or 0) then return true end
    BridgeFight.blacklist[z] = nil
    return false
end
BridgeFight.targetInfo = "none"
BridgeFight.fatigue = 0
BridgeFight.crowd = 0
BridgeFight.lastMiss = MISS_CHANCE
BridgeFight.saidTired = false
BridgeFight.kind = "hit"
BridgeFight.shoveStreak = 0
BridgeFight.shoveReadyAt = 0

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeFight] " .. tostring(text)) end end
local function warn(text) print("[BridgeFight] " .. tostring(text)) end


local function vlog(text) if Bridge ~= nil and Bridge.verbose then log(text) end end



BridgeFight.COMBAT_DEBUG = false
local function dbg(text)
    if BridgeFight.COMBAT_DEBUG and BridgeLog ~= nil and BridgeLog.on() then print("[BridgeFight] " .. tostring(text)) end
end




local function weaponSkill(item)
    if BridgeSkills == nil or BridgeSkills.categoryFor == nil then return nil, 0, 0 end
    local cat = BridgeSkills.categoryFor(item)
    if cat == nil then return nil, 0, 0 end
    local raw = BridgeSkills.level(cat) or 0
    local eff = (cat == "Axe") and raw or math.max(0, raw - 1)
    return cat, raw, eff
end

local function strengthLevel()
    if BridgeSkills == nil or BridgeSkills.level == nil then return STR_CENTER end
    return BridgeSkills.level("Strength") or STR_CENTER
end

local function damageMultiplier(skillEff, str)
    return 1 + SKILL_DMG_PER_LEVEL * (skillEff or 0) + STR_DMG_PER_LEVEL * ((str or STR_CENTER) - STR_CENTER)
end

local function pushMultiplier(str)
    return STR_PUSH_BASE + STR_PUSH_PER_LEVEL * (str or 0)
end




local function fitnessLevel()
    if BridgeSkills == nil or BridgeSkills.level == nil then return 0 end
    return BridgeSkills.level("Fitness") or 0
end

local function fitnessSpeedAdd(n)
    n = math.max(0, math.min(10, n or 0))
    return FIT_SPEED_PER_LEVEL * n
end

local function fitnessDrainMult(n)
    n = math.max(0, math.min(10, n or 0))
    return math.max(FIT_DRAIN_MIN, FIT_DRAIN_BASE - FIT_DRAIN_PER_LEVEL * n)
end

local function fitnessRecoverMult(n)
    n = math.max(0, math.min(10, n or 0))
    return math.min(FIT_RECOVER_MAX, FIT_RECOVER_BASE + FIT_RECOVER_PER_LEVEL * n)
end

local function dist(a, b)
    local dx, dy = a:getX() - b:getX(), a:getY() - b:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function isBody(z)
    local ok, v = pcall(function() return z:getVariableBoolean("NotAloneBody") end)
    return ok and v
end



local function remoteZombie(z)
    if not isClient() then return false end
    local ok, v = pcall(function() return z:isRemoteZombie() end)
    return ok and v
end


local function weapon(body)
    local item = body:getPrimaryHandItem()



    local thrown = false
    pcall(function() thrown = item ~= nil and item:getSwingAnim() == "Throw" end)
    if item ~= nil and instanceof(item, "HandWeapon") and not item:isRanged() and not thrown then return item end
    if BridgeFight.bareHands == nil then
        BridgeFight.bareHands = instanceItem("Base.BareHands")
    end
    return BridgeFight.bareHands
end

local function attackAnims(item, prone, crit)
    local kind = WeaponType.getWeaponType(item)
    if item:getFullType() == "Base.BareHands" or kind == WeaponType.UNARMED then
        if prone then return { "AttackStomp" }, "AttackStomp" end
        return { "AttackBareHands1", "AttackBareHands2", "AttackBareHands3",
                 "AttackBareHands4", "AttackBareHands5", "AttackBareHands6" }, item:getSwingSound()
    elseif kind == WeaponType.TWO_HANDED or kind == WeaponType.HEAVY then
        if prone then return { "Attack2HFloor" }, item:getSwingSound() end
        return { "Attack2H1", "Attack2H2", "Attack2H3", "Attack2H4" }, item:getSwingSound()
    elseif kind == WeaponType.ONE_HANDED then
        if prone then return { "Attack1HFloor" }, item:getSwingSound() end
        return { "Attack1H1", "Attack1H2", "Attack1H3", "Attack1H4", "Attack1H5" }, item:getSwingSound()
    elseif kind == WeaponType.SPEAR then
        if prone then return { "AttackS1Floor" }, item:getSwingSound() end
        if crit then return { "AttackS2" }, item:getSwingSound() end
        return { "AttackS1" }, item:getSwingSound()
    elseif kind == WeaponType.KNIFE then
        if prone then return { "AttackKnifeFloor" }, item:getSwingSound() end
        return { "AttackKnife" }, item:getSwingSound()
    end
    if prone then return { "Attack2HFloor" }, item:getSwingSound() end
    return { "Attack2H1", "Attack2H2", "Attack2H3", "Attack2H4" }, item:getSwingSound()
end

local function isProne(z)
    local asn = "?"
    pcall(function() asn = z:getActionStateName() end)
    local crawl = false
    pcall(function() crawl = z:isCrawling() end)
    local prone = false
    pcall(function() prone = z:isProne() end)
    return prone or crawl or asn == "onground" or asn == "sitonground"
        or string.sub(asn, 1, 5) == "getup"
end



local function isKnockedDown(z)
    local down, crawl = false, true
    pcall(function() down = isProne(z) crawl = z:isCrawling() end)
    return down and not crawl
end



local function wallBetween(a, b)
    local blocked = false
    pcall(function()
        local sa, sb = a:getCurrentSquare(), b:getCurrentSquare()
        if sa == nil or sb == nil then return end
        if sa:getZ() ~= sb:getZ() then blocked = true return end
        local dx, dy = sb:getX() - sa:getX(), sb:getY() - sa:getY()
        if dx == 0 and dy == 0 then return end
        if math.abs(dx) > 1 or math.abs(dy) > 1 then return end
        blocked = sa:isBlockedTo(sb)
    end)
    return blocked
end
BridgeFight.wallBetween = wallBetween





local function swingFrames(item)
    local t = nil
    pcall(function() t = item:getSwingTime() end)
    local kind = "?"
    pcall(function() kind = item:getType() end)
    if BridgeFight.swingLogged ~= kind then
        BridgeFight.swingLogged = kind
        local mn = nil
        pcall(function() mn = item:getMinimumSwingTime() end)
        vlog("weapon " .. tostring(kind) .. " swingTime=" .. tostring(t) ..
            " minSwing=" .. tostring(mn) .. " dmg=" .. tostring(item:getMinDamage()) ..
            ".." .. tostring(item:getMaxDamage()))
    end
    local anim, speed = nil, 1.0
    pcall(function() anim = item:getSwingAnim() end)
    pcall(function() speed = item:getBaseSpeed() end)
    if type(speed) ~= "number" or speed <= 0 then speed = 1.0 end
    local _, _, eff = weaponSkill(item)
    speed = speed + SKILL_SPEED_PER_LEVEL * (eff or 0)
    speed = speed + fitnessSpeedAdd(fitnessLevel())
    local len = math.floor((SWING_BY_ANIM[anim] or SWING_DEFAULT) / speed + 0.5)
    if len < SWING_MIN then len = SWING_MIN end
    if len > SWING_MAX then len = SWING_MAX end

    len = math.floor(len * (1 + TIRED_SWING * BridgeFight.fatigue) + 0.5)


    return len, math.min(math.floor(len * 0.45 + 0.5), HIT_FALLBACK_MAX)
end
BridgeFight.swingFrames = swingFrames



local function crowdAround(body, radius)
    radius = radius or CROWD_RADIUS
    local n = 0
    pcall(function()
        local bx, by = body:getX(), body:getY()
        local list = nil
        if BridgeZS ~= nil then list = BridgeZS.near(bx, by, radius + 0.05, { tag = "fight.crowd" }) end
        if list == nil then list = getCell():getZombieList() end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= body and not isBody(z) and z:isAlive() and z:getHealth() > 0
                and math.abs(z:getZ() - body:getZ()) < 0.8 and dist(z, body) < radius
                and not BridgeData.harmless(z) then
                n = n + 1
            end
        end
    end)
    return n
end
BridgeFight.crowdAround = crowdAround


local function missChance(body)
    local crowd = crowdAround(body)
    BridgeFight.crowd = crowd
    local fromCrowd = math.min(CROWD_MISS_MAX, CROWD_MISS * math.max(0, crowd - 1))
    local chance = MISS_CHANCE + TIRED_MISS * BridgeFight.fatigue + fromCrowd
    BridgeFight.lastMiss = chance
    return math.min(90, chance)
end



local function sayFatigue()
    if BridgeMoments == nil then return end


    if not BridgeFight.saidTired and BridgeFight.fatigue >= TIRED_SAY then
        local said = false
        pcall(function() said = BridgeMoments.say("EvWinded", 2 * 3600, true) == true end)
        if said then BridgeFight.saidTired = true end
    elseif BridgeFight.saidTired and BridgeFight.fatigue <= RESTED_SAY then


        local said = false
        pcall(function() said = BridgeMoments.say("EvRested", 2 * 3600, true) == true end)
        if said then BridgeFight.saidTired = false end
    end
end



local function tire(item, dealt, hp, prone, body)
    local w, fat, endu, maxD = 1.0, 1.0, 1.0, 1.0
    pcall(function() w = item:getWeight() end)


    pcall(function() fat = item:getFatigueMod(body) end)
    pcall(function() endu = item:getEnduranceMod() end)
    pcall(function() maxD = item:getMaxDamage() end)
    if type(w) ~= "number" then w = 1.0 end
    if type(fat) ~= "number" or fat <= 0 then fat = 1.0 end
    if type(endu) ~= "number" or endu <= 0 then endu = 1.0 end
    if type(maxD) ~= "number" or maxD <= 0 then maxD = 1.0 end
    local two = false
    pcall(function() two = item:isTwoHandWeapon() end)

    local oneHand = 0
    if two and BridgeFight.oneHanded then oneHand = w / END_TWOHAND_DIV / END_TWOHAND_SCALE end
    local cost = (w * END_BASE_SCALE * fat * endu * END_WEIGHT_MOD + oneHand) * END_FINAL
    local scale = 1
    if prone then
        scale = END_CLOSE_KILL
    elseif dealt ~= nil and dealt > 0 then
        scale = math.min(math.min(dealt, hp or dealt) / maxD, 1)
    end
    local fitDrain = fitnessDrainMult(fitnessLevel())
    BridgeFight.lastTire = cost * scale * FATIGUE_MULT * fitDrain
    BridgeFight.fatigue = math.min(1, BridgeFight.fatigue + cost * scale * FATIGUE_MULT * fitDrain)
    sayFatigue()
end


local function rest(busy, sitting)
    if BridgeFight.fatigue <= 0 then return end
    local r = FATIGUE_REST * (busy and FATIGUE_REST_BUSY or 1)

    if Bridge.pose ~= nil or sitting then r = r * FATIGUE_REST_SIT end

    r = r * (Bridge.dt or 1)
    r = r * fitnessRecoverMult(fitnessLevel())
    BridgeFight.fatigue = math.max(0, BridgeFight.fatigue - r)
    sayFatigue()
end
BridgeFight.rest = rest






function BridgeFight.tireTree(axe, body)
    local w, fat, charFat, endu = 1.0, 1.0, 1.0, 1.0
    local useEnd = true
    pcall(function() useEnd = axe:isUseEndurance() end)
    if axe == nil or body == nil or not useEnd then return 0 end
    pcall(function() w = axe:getWeight() end)
    pcall(function() fat = axe:getFatigueMod(body) end)
    pcall(function() charFat = body:getFatigueMod() end)
    pcall(function() endu = axe:getEnduranceMod() end)
    if type(w) ~= "number" or w <= 0 then w = 1.0 end
    if type(fat) ~= "number" or fat <= 0 then fat = 1.0 end
    if type(charFat) ~= "number" or charFat <= 0 then charFat = 1.0 end
    if type(endu) ~= "number" or endu <= 0 then endu = 1.0 end
    local use = w * fat * charFat * endu * 0.1 * 0.041
    local two = false
    pcall(function() two = axe:isTwoHandWeapon() end)
    if two then use = use + w / 1.5 / 10 / 20 end
    local fitLevel = fitnessLevel()
    use = use * CHOP_STAMINA_MULT
    use = use * fitnessDrainMult(fitLevel)
    if use > 0 then
        BridgeFight.lastTire = use
        BridgeFight.fatigue = math.min(1, BridgeFight.fatigue + use)
        dbg(string.format("FIT chop L%d drain x%.2f rec x%.2f fatigue=%.2f",
            fitLevel, fitnessDrainMult(fitLevel), fitnessRecoverMult(fitLevel), BridgeFight.fatigue))
        sayFatigue()
    end
    return use
end

local function critRoll(item)
    local critChance, critMult = 0, 1
    pcall(function() critChance = item:getCriticalChance() end)
    pcall(function() critMult = item:getCriticalDamageMultiplier() end)
    if type(critChance) ~= "number" then critChance = 0 end
    if type(critMult) ~= "number" or critMult <= 0 then critMult = 1 end
    local _, _, eff = weaponSkill(item)
    critChance = math.max(10, math.min(90, critChance + CRIT_PER_LEVEL * eff - TIRED_CRIT * BridgeFight.fatigue))
    return ZombRand(100) < critChance, critChance, critMult
end

local function headSound(item)
    local kind = nil
    pcall(function() kind = WeaponType.getWeaponType(item) end)
    if kind == WeaponType.SPEAR or kind == WeaponType.KNIFE then return "NA_HeadStab" end
    local cat = nil
    pcall(function() cat = item:getDamageCategory() end)
    if cat == "Blunt" then return "NA_HeadSmash" end
    if cat == "Slash" or cat == "Stab" then return "NA_HeadSlice" end
    return "NA_HeadSmash"
end

local function combatTextHit(victim, item, crit)
    if COMBATTEXT_ON ~= 1 then return end
    if CombatTextCache == nil or CombatTextCache.TrackingList == nil then return end
    pcall(function()
        local uid = victim:getUID()
        local hp = victim:getHealth() * 100.0
        local tick = getGameTime():getCalender():getTimeInMillis()
        local itm = CombatTextCache.TrackingList[uid]
        if itm == nil then
            CombatTextCache.TrackingList[uid] = { fullHp = hp, hp = hp, isDead = victim:isDead(),
                entity = victim, isOnFire = false, isBleeding = false, weapon = item, isCrit = crit, tick = tick }
            CombatTextCache.TrackingListCount = (CombatTextCache.TrackingListCount or 0) + 1
            itm = CombatTextCache.TrackingList[uid]
        else
            itm.weapon = item
            itm.isCrit = crit
            itm.tick = tick
        end
        if CombatTextCache.HealthBarManagers ~= nil then
            for _, m in pairs(CombatTextCache.HealthBarManagers) do
                if m ~= nil then pcall(function() m:onHit(uid, item, crit, itm) end) end
            end
        end
    end)
end

local function computeSwing(item, fixedDmg)
    local crit, critChance, critMult
    if BridgeFight.swingCrit ~= nil then
        crit = BridgeFight.swingCrit
        critChance = BridgeFight.swingCritChance or 0
        critMult = BridgeFight.swingCritMult or 1
    else
        crit, critChance, critMult = critRoll(item)
    end
    local dmg, rawDmg
    local headFloor = false
    local cat, rawSkill, eff = weaponSkill(item)
    local str = strengthLevel()
    local fitN = fitnessLevel()
    local mult = damageMultiplier(eff, str)
    if type(fixedDmg) == "number" then
        dmg = fixedDmg
        rawDmg = BridgeFight.lastRawDmg or fixedDmg
    else
        local dmgMin, dmgMax = 0.3, 1.0
        pcall(function() dmgMin = item:getMinDamage() end)
        pcall(function() dmgMax = item:getMaxDamage() end)
        dmg = dmgMin + (dmgMax - dmgMin) * ZombRandFloat(0, 1)
        rawDmg = dmg
        if crit then dmg = dmg * math.max(2, critMult) end
        dmg = dmg * mult
        dmg = dmg * (1 - TIRED_DAMAGE * BridgeFight.fatigue)
        if GROUND_BONUS_ON == 1 and BridgeFight.floorSwing then
            dmg = dmg * math.max(critMult, 5)
        end
        if BridgeFight.floorSwing then
            headFloor = ZombRand(2) > 0
            if headFloor then dmg = dmg * HEAD_SPLIT end
        end
        BridgeFight.lastRawDmg = rawDmg
        BridgeFight.lastHitDmg = dmg
    end
    dbg(string.format("HIT %s roll=%.3f crit=%s skill=%s L%d(eff %d, +%d%%) str=%d(+%d%%) mult=%.2f dmg=%.3f fatigue=%.2f fit=L%d(spd+%.0f%% drain x%.2f rec x%.2f)",
        tostring(item:getType()), rawDmg or 0,
        crit and ("x" .. tostring(math.max(2, critMult))) or "no",
        tostring(cat or "-"), rawSkill or 0, eff or 0,
        math.floor(SKILL_DMG_PER_LEVEL * (eff or 0) * 100 + 0.5),
        str or STR_CENTER, math.floor(STR_DMG_PER_LEVEL * ((str or STR_CENTER) - STR_CENTER) * 100 + 0.5),
        mult, dmg, BridgeFight.fatigue,
        fitN, fitnessSpeedAdd(fitN) * 100, fitnessDrainMult(fitN), fitnessRecoverMult(fitN)))
    BridgeFight.lastHead = headFloor
    return crit, critChance, critMult, dmg, rawDmg, headFloor
end

local function hitTarget(body, item, victim, noMiss, fixedDmg)
    local isAnimal = instanceof(victim, "IsoAnimal")
    if BridgeKnoxNpc ~= nil and BridgeKnoxNpc.isNpc(victim) then
        local range = item:getMaxRange()
        local d = dist(body, victim)
        if d >= range + 0.3 then return string.format("miss range d=%.2f r=%.2f", d, range) end
        if wallBetween(body, victim) then return "miss wall" end
        local miss = 0
        if not noMiss then
            miss = missChance(body)
            if ZombRand(100) >= 100 - miss then
                return string.format("miss roll (%.0f%% f=%.2f crowd=%d)", miss, BridgeFight.fatigue, BridgeFight.crowd)
            end
        end
        local crit, critChance, critMult, dmg, rawDmg, headFloor = computeSwing(item, fixedDmg)
        local hpBefore = 0
        pcall(function() hpBefore = victim:getHealth() end)
        BridgeKnoxNpc.hit(victim, body, item, dmg, crit)
        combatTextHit(victim, item, crit)
        tire(item, rawDmg, hpBefore, false, body)
        pcall(function() if BridgeSkills ~= nil then BridgeSkills.add("Strength", 1, "hit") end end)
        vlog(string.format("hit knox npc %s dmg=%.2f hp=%.2f crit=%.0f%%", tostring(item:getType()),
            dmg, hpBefore, critChance))
        return "hit"
    end
    local fake = isAnimal and nil or getCell():getFakeZombieForHit()
    local range = item:getMaxRange()
    local d = dist(body, victim)

    if d >= range + 0.3 then return string.format("miss range d=%.2f r=%.2f", d, range) end
    if isAnimal then
        if victim:isDead() then return "miss dead" end
    elseif victim:isOnKillDone() then
        return "miss killdone"
    end
    if wallBetween(body, victim) then return "miss wall" end

    local miss = 0
    if not noMiss then
        miss = missChance(body)
        if ZombRand(100) >= 100 - miss then
            if not isAnimal then pcall(function() victim:setHitFromBehind(false) end) end
            return string.format("miss roll (%.0f%% f=%.2f crowd=%d)", miss, BridgeFight.fatigue, BridgeFight.crowd)
        end
    end

    local crit, critChance, critMult, dmg, rawDmg, headFloor = computeSwing(item, fixedDmg)

    local hpBefore = 0
    pcall(function() hpBefore = victim:getHealth() end)

    if isAnimal then
        if BridgeAnimals ~= nil then BridgeAnimals.attack(victim, dmg, body) end
        tire(item, rawDmg, hpBefore, false, body)
        vlog(string.format("hit animal %s dmg=%.3f hp=%.2f%s crit=%.0f%%", tostring(item:getType()),
            dmg, hpBefore, crit and " CRIT" or "", critChance))
        return "hit"
    end

    local behind = body:isBehind(victim)
    victim:setHitFromBehind(behind)
    victim:setAttackedBy(fake)

    victim:setPlayerAttackPosition(victim:testDotSide(body))
    pcall(function() victim:setHitHeadWhileOnFloor(headFloor and 1 or 0) end)
    pcall(function() victim:setHitLegsWhileOnFloor(false) end)


    local reaction = HIT_REACTION[BridgeFight.anim or ""] or ""
    if crit then
        local cr = CRIT_REACTION[BridgeFight.anim or ""]
        if cr ~= nil then reaction = cr end
    end
    pcall(function()
        if victim:getEatBodyTarget() ~= nil then reaction = victim:getVariableBoolean("onknees") and "OnKnees" or "Eating" end
    end)
    if reaction ~= "" then
        pcall(function() victim:setHitReaction(reaction) end)
    else
        pcall(function()
            victim:setStaggerBack(true)
            victim:setHitReaction("")
        end)
    end
    BridgeFight.lastReaction = reaction
    combatTextHit(victim, item, crit)
    BridgeFight.lastHeadSound = nil
    if headFloor then
        local hs = headSound(item)
        if hs ~= nil then
            pcall(function()
                local em = victim:getEmitter()
                if em ~= nil then em:playSound(hs) end
            end)
            BridgeFight.lastHeadSound = hs
        end
    end
    victim:Hit(item, fake, dmg, false, 1, false)

    pcall(function() BridgeCallout.kill(victim) end)
    pcall(function() if BridgeKills ~= nil then BridgeKills.credit(victim) BridgeKills.confirm(victim) end end)

    tire(item, rawDmg, hpBefore, isProne(victim), body)
    pcall(function() victim:playSound(item:getZombieHitSound()) end)

    pcall(function()
        vlog(string.format("hit %s dmg=%.2f%s hp=%.2f->%.2f f=%.3f (+%.4f) miss=%.0f%% crit=%.0f%% crowd=%d head=%s reaction=%s snd=%s", tostring(item:getType()),
            dmg, crit and " CRIT" or "", hpBefore, victim:getHealth(), BridgeFight.fatigue, BridgeFight.lastTire or 0, miss, critChance, BridgeFight.crowd,
            tostring(BridgeFight.lastHead), BridgeFight.lastReaction ~= "" and tostring(BridgeFight.lastReaction) or "stagger",
            tostring(BridgeFight.lastHeadSound or "-")))
    end)



    pcall(function()
        if body:DistToSquared(victim) < 2 and math.abs(body:getZ() - victim:getZ()) < 0.5 then
            body:addBlood(nil, false, false, false)
        end
    end)

    BridgeFight.shoveStreak = 0

    pcall(function() BridgeSkills.add("Strength", 1, "hit") end)
    return "hit"
end




local function visible(z, red)
    local seen = true

    local viewer = red
    pcall(function() if red:isDead() and Bridge.body ~= nil then viewer = Bridge.body end end)
    pcall(function() seen = viewer:CanSee(z) end)
    return seen
end
BridgeFight.visible = visible



function BridgeFight.reachable(body, z)
    local ok = true
    pcall(function()
        local bsq, zsq = body:getCurrentSquare(), z:getCurrentSquare()
        if bsq == nil or zsq == nil then return end
        local bkey = bsq:getX() .. "," .. bsq:getY() .. "," .. bsq:getZ()
        local zkey = zsq:getX() .. "," .. zsq:getY() .. "," .. zsq:getZ()
        local rec = reachCache[z]
        if rec ~= nil and rec.b == bkey and rec.z == zkey and (Bridge.time - rec.tick) < REACH_TTL then
            ok = rec.reach
            return
        end
        local reach = false
        if BridgeMove ~= nil and BridgeMove.lineClear ~= nil then
            reach = BridgeMove.lineClear(body, z:getX(), z:getY(), z:getZ()) == true
            if not reach and BridgeMove.walkReach ~= nil then
                reach = BridgeMove.walkReach(body, z:getX(), z:getY(), z:getZ(), REACH_NODES) == true
            end
        end
        reachCache[z] = { b = bkey, z = zkey, tick = Bridge.time, reach = reach }
        reachCacheN = reachCacheN + 1
        if reachCacheN > REACH_CACHE_MAX then
            reachCache = setmetatable({}, { __mode = "k" })
            reachCacheN = 0
        end
        ok = reach
    end)
    return ok
end




function BridgeFight.mode()
    if BridgeFight.guardOnly then return BridgeData.COMBAT.bodyguard end
    local m = BridgeData.COMBAT[BridgeData.combatOf(Bridge.store)] or BridgeData.COMBAT.bodyguard
    if m.assist and (Bridge.time or 0) >= (BridgeFight.playerFightUntil or 0) then
        return BridgeData.COMBAT.stayback or m
    end
    return m
end


function BridgeFight.threat(z, body, red, mode)
    mode = mode or BridgeFight.mode()
    local bySelf = BridgeFight.guardOnly or mode.rank == "self"
    local d = bySelf and dist(z, body) or dist(z, red)


    local down = false
    pcall(function() down = isKnockedDown(z) end)
    if down and d > PRONE_BONUS_RANGE then down = false end
    local score = d - (down and PRONE_BONUS or 0)



    if d <= 6.0 then
        local clear = true
        pcall(function() clear = BridgeMove.lineClear(body, z:getX(), z:getY(), z:getZ()) == true end)
        if not clear then score = score + FENCE_HOP_PENALTY end
    end
    return score
end




local function barrierSide(z, body)
    local clear = false
    pcall(function() clear = BridgeMove.lineClear(body, z:getX(), z:getY(), z:getZ()) end)
    return not clear
end


local function pickTarget(body, red, mode)
    mode = mode or BridgeFight.mode()
    local best, bestD = nil, math.huge
    local reach = 1.0
    pcall(function() reach = weapon(body):getMaxRange() end)
    local bx, by = body:getX(), body:getY()
    local rx, ry, rz = red:getX(), red:getY(), red:getZ()
    local engageSelf = mode.engageSelf or math.huge
    local engageRed = mode.engageRed or math.huge
    if engageSelf < 0 then engageSelf = 0 end
    if engageRed < 0 then engageRed = 0 end
    local selfR2 = engageSelf * engageSelf
    local redR2 = engageRed * engageRed
    local guardOnly = BridgeFight.guardOnly
    local maxNear = guardOnly and engageSelf or math.max(engageSelf, engageRed)
    local list = nil
    if BridgeZS ~= nil and maxNear < 1000 then
        if guardOnly then
            list = BridgeZS.near(bx, by, maxNear + 0.2, { tag = "fight.pick" })
        else
            list = BridgeZS.nearUnion(bx, by, rx, ry, maxNear + 0.2, { tag = "fight.pick" })
        end
    end
    if list == nil then list = getCell():getZombieList() end
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        local nearEnough = false
        if z ~= nil then
            local zz = z:getZ()
            if math.abs(zz - rz) < 0.8 then
                local zx, zy = z:getX(), z:getY()
                local sdx, sdy = zx - bx, zy - by
                if sdx * sdx + sdy * sdy < selfR2 then
                    nearEnough = true
                elseif not guardOnly then
                    local rdx, rdy = zx - rx, zy - ry
                    nearEnough = (rdx * rdx + rdy * rdy) < redR2
                end
            end
        end
        if nearEnough then
            local banned = false
            pcall(function()
                local b = BridgeFight.blacklist[z]
                if b == nil then return end


                if type(b) == "number" then banned = numberBan(z, b) return end
                local st = tostring(z:getActionStateName())



                local broke = BARRIER_STATE[b.st] and not BARRIER_STATE[st]
                local came = (z:getX() - b.x) ^ 2 + (z:getY() - b.y) ^ 2 > 1.0 and dist(z, red) < mode.engageRed
                    and not wallBetween(body, z)
                if b.untilT <= Bridge.time or broke or came then
                    BridgeFight.blacklist[z] = nil
                    if b.untilT > Bridge.time then
                        vlog(string.format("target unbanned: %s", broke and ("stopped " .. b.st .. ", now " .. st) or "came to player"))
                    end
                else
                    banned = true
                end
            end)

            local busy = false
            pcall(function()
                local st = z:getActionStateName()
                busy = (st == "thump" and barrierSide(z, body))
            end)



            local isRemote = z ~= nil and remoteZombie(z)
            if z ~= nil and not banned and not busy and not isBody(z) and z:isAlive() and z:getHealth() > 0
                and not BridgeFight.ownerRisen(z, red)
                and math.abs(z:getZ() - red:getZ()) < 0.8 and not BridgeData.harmless(z) and visible(z, red) then
                local dRed = dist(z, red)
                local dSelf = dist(z, body)
                local remoteOk = (not isRemote) or dSelf <= reach + 0.3
                local near = remoteOk and (dSelf < mode.engageSelf or (not BridgeFight.guardOnly and dRed < mode.engageRed))
                if near then
                    local score = BridgeFight.threat(z, body, red, mode)
                    if BridgeAim ~= nil and BridgeAim.zone.on and BridgeAim.inCone(z:getX(), z:getY(), z:getZ()) then
                        score = score + (BridgeAim.TARGET_PENALTY or 30)
                    end
                    if score < bestD and (NO_CLIMB_ON == 0 or BridgeFight.reachable(body, z)) then
                        best, bestD = z, score
                    end
                end
            end
        end
    end

    if BridgeAnimals ~= nil and BridgeAnimals.wanted then
        pcall(function()
            local animals = getCell():getAnimals()
            if animals == nil then return end
            for i = 0, animals:size() - 1 do
                local a = animals:get(i)
                if a ~= nil and BridgeAnimals.hostile(a) and a:isAlive()
                    and math.abs(a:getZ() - red:getZ()) < 0.8 and visible(a, red) then
                    local dSelf = dist(a, body)
                    local dRed = dist(a, red)
                    local near = dSelf < mode.engageSelf or (not BridgeFight.guardOnly and dRed < mode.engageRed)
                    if near then
                        local score = BridgeFight.threat(a, body, red, mode)
                        if BridgeAim ~= nil and BridgeAim.zone.on and BridgeAim.inCone(a:getX(), a:getY(), a:getZ()) then
                            score = score + (BridgeAim.TARGET_PENALTY or 30)
                        end
                        if score < bestD then
                            best, bestD = a, score
                        end
                    end
                end
            end
        end)
    end
    if BridgeKnoxNpc ~= nil and BridgeKnoxNpc.allowMelee() then
        pcall(function()
            local npcs = BridgeKnoxNpc.near(bx, by, maxNear, red)
            for i = 1, #npcs do
                local n = npcs[i]
                local zz = n:getZ()
                if math.abs(zz - rz) < 0.8 and BridgeFight.blacklist[n] == nil and visible(n, red) then
                    local dSelf = dist(n, body)
                    local dRed = dist(n, red)
                    local near = dSelf < mode.engageSelf or (not BridgeFight.guardOnly and dRed < mode.engageRed)
                    if near then
                        local score = BridgeFight.threat(n, body, red, mode)
                        if BridgeAim ~= nil and BridgeAim.zone.on and BridgeAim.inCone(n:getX(), n:getY(), n:getZ()) then
                            score = score + (BridgeAim.TARGET_PENALTY or 30)
                        end
                        if score < bestD then
                            best, bestD = n, score
                        end
                    end
                end
            end
        end)
    end
    return best
end




function BridgeFight.ownerRisen(z, red)
    if z == nil or red == nil then return false end
    local risen = false
    pcall(function() risen = z:isReanimatedPlayer() and z:getReanimatedPlayer() == red end)
    return risen == true
end

local function validTarget(z, body, red, mode)
    mode = mode or BridgeFight.mode()
    if z == nil then return false end
    if BridgeKnoxNpc ~= nil and BridgeKnoxNpc.isNpc(z) then
        if not BridgeKnoxNpc.hostile(z, red) then return false end
        local ok, alive = pcall(function() return z:isAlive() == true and z:isDead() ~= true end)
        if not ok or not alive then return false end
        if math.abs(z:getZ() - red:getZ()) >= 0.8 then return false end
        if not visible(z, red) then return false end
        if BridgeFight.guardOnly then
            return dist(z, body) <= BridgeData.COMBAT.bodyguard.targetMax
        end
        local d = mode.rank == "self" and dist(z, body) or dist(z, red)
        return d <= mode.targetMax
    end
    if instanceof(z, "IsoAnimal") then
        if BridgeAnimals == nil or not BridgeAnimals.hostile(z) then return false end
        if not z:isAlive() then return false end
        if math.abs(z:getZ() - red:getZ()) >= 0.8 then return false end
        if not visible(z, red) then return false end
        if BridgeFight.guardOnly then
            return dist(z, body) <= BridgeData.COMBAT.bodyguard.targetMax
        end
        return dist(z, body) <= mode.targetMax
    end
    if BridgeFight.ownerRisen(z, red) then return false end
    local ok, alive = pcall(function() return z:isAlive() and z:getHealth() > 0 and not z:isOnKillDone() end)
    if not ok or not alive or BridgeData.harmless(z) then return false end
    if remoteZombie(z) then
        local reach = 1.0
        pcall(function() reach = weapon(body):getMaxRange() end)
        if dist(z, body) > reach + 0.3 then
            BridgeFight.info = "target remote, out of reach"
            return false
        end
    end




    local thumping = false
    pcall(function() thumping = tostring(z:getActionStateName()) == "thump" end)
    if thumping and barrierSide(z, body) then
        BridgeFight.info = "target behind a barrier (thump)"
        return false
    end

    if visible(z, red) then
        BridgeFight.unseenSince = nil
    else
        BridgeFight.unseenSince = BridgeFight.unseenSince or Bridge.time
        if Bridge.time - BridgeFight.unseenSince > 60 then
            BridgeFight.unseenSince = nil
            BridgeFight.info = "target out of sight"
            pcall(function() BridgeCallout.lostTarget() end)
            return false
        end
    end
    if BridgeFight.guardOnly then
        if dist(z, body) > BridgeData.COMBAT.bodyguard.targetMax then return false end
    else
        local d = mode.rank == "self" and dist(z, body) or dist(z, red)
        if d > mode.targetMax then return false end
    end
    if BridgeAim ~= nil and BridgeAim.zone.on and BridgeAim.inCone(z:getX(), z:getY(), z:getZ()) then
        local reach = 0
        pcall(function() reach = weapon(body):getMaxRange() end)
        if dist(z, body) > reach + 0.1 then
            BridgeFight.info = "target in the aim line, out of reach"
            return false
        end
    end
    return true
end


function BridgeFight.nearestInfo(body)
    local red = BridgeData.owner()
    if red == nil then return "no player" end
    local best, bestD, text = nil, math.huge, "none"
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and not isBody(z) and not BridgeData.harmless(z) then
                local d = math.min(dist(z, red), dist(z, body))
                if d < bestD then best, bestD = z, d end
            end
        end
        if best ~= nil then
            local banned = false
            local b = BridgeFight.blacklist[best]
            if type(b) == "number" then banned = numberBan(best, b)
            elseif b ~= nil and b.untilT > Bridge.time then banned = true end
            local see = false
            pcall(function() see = body:CanSee(best) end)
            text = string.format("dred=%.1f dself=%.1f st=%s hp=%.2f banned=%s see=%s", dist(best, red),
                dist(best, body), tostring(best:getActionStateName()), best:getHealth(),
                tostring(banned), tostring(see))
        end
    end)
    return text
end



function BridgeFight.resetFatigue()
    BridgeFight.fatigue = 0
    BridgeFight.saidTired = false
end


local FATIGUE_FULL_HOURS = 3


local function staminaHours()
    local h = nil
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h
end


function BridgeFight.persistStamina(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return end
    local cur = math.max(0, math.min(1, tonumber(BridgeFight.fatigue) or 0))
    rec.fatigue = cur
    rec.fatigueAt = staminaHours()
    if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { fatigue = cur, fatigueAt = rec.fatigueAt }) end)
    end
end


function BridgeFight.applyStamina(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    local saved = 0
    if rec ~= nil then saved = tonumber(rec.fatigue) or 0 end
    if saved <= 0 then
        BridgeFight.resetFatigue()
        return
    end
    local now = staminaHours()
    local at = rec ~= nil and tonumber(rec.fatigueAt) or nil
    local elapsed = 0
    if now ~= nil and at ~= nil and now > at then elapsed = now - at end
    local left = saved - elapsed / FATIGUE_FULL_HOURS
    if left < 0 then left = 0 end
    BridgeFight.fatigue = left
    BridgeFight.saidTired = false
    if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { fatigue = left }) end)
    end
end

-- Footwork: back away from the edge of the crowd while fighting.
BridgeFight.FOOTWORK_ON = true
BridgeFight.FOOT_ESCAPE_ON = true
BridgeFight.FOOT_SWING_BACK = true
local FOOT_CROWD = 3.5
local FOOT_STAND_SCAN = 7.0
local FOOT_PRESS = 1.2
local FOOT_AROUND = 2.2
local FOOT_NEAR = 1.1
local FOOT_REACH = 0.3
local FOOT_GAP = 0.75
local FOOT_STEP = 1.2
local FOOT_OUT = 2.0
local FOOT_GAIN = 0.15
local FOOT_COOLDOWN = 15
local FOOT_STEP_MAX = 72
local FOOT_STALL = 30
local FOOT_ARRIVE = 0.35
local FOOT_SWING_DRIFT = 0.008
local FOOT_BWD_NUDGE = 0.018
local FOOT_BWD_BUDGET = 0.9
local FOOT_DRIFT_GAP = 0.0

local FLEE_ON              = true
local FLEE_SECTOR_R        = 2.2
local FLEE_GUN_SECTOR_R    = 3.2
local FLEE_GUN_CROWD_R     = 5.0
local FLEE_GUN_ENTER_SECTORS = 5
local FLEE_ENTER_SECTORS   = 5
local FLEE_ENTER_PRESS     = 3
local FLEE_EXIT_SECTORS    = 3
local FLEE_EXIT_NEAR       = 3
local FLEE_CLEAR_TICKS     = 22
local FLEE_LOCKOUT         = 60
local FLEE_LEASH_MULT      = 1.5
local FLEE_BURST_MIN       = 2.0
local FLEE_BURST_MAX       = 4.0
local FLEE_REPLAN          = 20
local FLEE_STUCK           = 30
local FLEE_MAX_FAILS       = 3
local FLEE_PRESSURE_PRESS  = 3
local FLEE_PRESSURE_SECTOR = 3
local FLEE_PRESSURE_BUDGET = 1.2

BridgeFight.stepUntil = 0
BridgeFight.stepGoalX = nil
BridgeFight.stepGoalY = nil
BridgeFight.stepGoalZ = nil
BridgeFight.stepTarget = nil
BridgeFight.stepWhy = nil
BridgeFight.stepBump = nil
BridgeFight.stepStart = nil
BridgeFight.stepThreatX = nil
BridgeFight.stepThreatY = nil
BridgeFight.stepLastCrowdDist = nil
BridgeFight.stepStallAt = nil
BridgeFight.stepReadyAt = 0
BridgeFight.stepScan = nil
BridgeFight.stepScanBody = nil
BridgeFight.stepScanAt = nil

BridgeFight.escapeOn = false
BridgeFight.escapeClearAt = nil
BridgeFight.escapePointX = nil
BridgeFight.escapePointY = nil
BridgeFight.escapePointZ = nil
BridgeFight.escapeWhy = nil
BridgeFight.escapeCornered = false
BridgeFight.escapePathAt = nil
BridgeFight.escapePathX = nil
BridgeFight.escapePathY = nil
BridgeFight.stepEscape = false
BridgeFight.stepPath = false
BridgeFight.swingBack = false
BridgeFight.swingBackX = nil
BridgeFight.swingBackY = nil
BridgeFight.swingBackFlank = false
BridgeFight.escapeScan = nil

BridgeFight.flee = false
BridgeFight.fleeClearAt = nil
BridgeFight.fleeUntil = 0
BridgeFight.fleeGoalX = nil
BridgeFight.fleeGoalY = nil
BridgeFight.fleeGoalZ = nil
BridgeFight.fleeNext = 0
BridgeFight.fleeFails = 0
BridgeFight.fleePathAt = nil
BridgeFight.fleePathX = nil
BridgeFight.fleePathY = nil
BridgeFight.pressN = 0
BridgeFight.sectorN = 0
BridgeFight.opposite = 0
BridgeFight.sectorNGun = 0
BridgeFight.oppositeGun = 0
BridgeFight.sectorNCrowd = 0
BridgeFight.oppositeCrowd = 0
BridgeFight.gunShoveSwing = false

local function footScan(body, red)
    local out = { n = 0, pressN = 0, nearN = 0, otherNear = 0, g2 = 0, g25 = 0, pushX = 0, pushY = 0,
                  cx = nil, cy = nil, centerDist = nil, threat = nil, threatD = math.huge,
                  standThreat = nil, standD = math.huge,
                  sectorMask = 0, sectorN = 0, opposite = 0,
                  sectorMaskGun = 0, sectorNGun = 0, oppositeGun = 0,
                  sectorMaskCrowd = 0, sectorNCrowd = 0, oppositeCrowd = 0 }
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local target = BridgeFight.target
    local cx, cy, cn = 0, 0, 0
    local seen = {}
    local scanLimit = FOOT_CROWD
    if BridgeGunfight ~= nil and BridgeGunfight.isAssigned ~= nil then
        local ok, assigned = pcall(BridgeGunfight.isAssigned, body)
        if ok and assigned == true then scanLimit = FOOT_STAND_SCAN end
    end

    local function addHostile(z)
        if z == nil or z == body or seen[z] then return end
        seen[z] = true
        local d = dist(z, body)
        if d > scanLimit then return end
        local downed = isProne(z) == true
        if not downed and d < out.standD then
            out.standD, out.standThreat = d, z
        end
        local ang, idx = nil, nil
        if not downed and d <= FLEE_GUN_CROWD_R then
            ang = math.atan2(z:getY() - by, z:getX() - bx) + math.pi
            idx = math.floor(ang / (2 * math.pi) * 8) % 8
            local bitCrowd = 2 ^ idx
            if math.floor(out.sectorMaskCrowd / bitCrowd) % 2 < 1 then
                out.sectorMaskCrowd = out.sectorMaskCrowd + bitCrowd
                out.sectorNCrowd = out.sectorNCrowd + 1
            end
            if d <= FLEE_GUN_SECTOR_R then
                local bitGun = 2 ^ idx
                if math.floor(out.sectorMaskGun / bitGun) % 2 < 1 then
                    out.sectorMaskGun = out.sectorMaskGun + bitGun
                    out.sectorNGun = out.sectorNGun + 1
                end
            end
        end
        if d > FOOT_CROWD then return end
        out.n = out.n + 1
        local pressing = d <= FOOT_PRESS
        if not pressing then
            pcall(function() pressing = z:getTarget() == body end)
        end
        if pressing and not downed then out.pressN = out.pressN + 1 end
        if d <= FOOT_NEAR and not downed then
            out.nearN = out.nearN + 1
            if z ~= target then out.otherNear = out.otherNear + 1 end
        end
        if d <= 2.0 then out.g2 = out.g2 + 1 end
        if d <= 2.5 then out.g25 = out.g25 + 1 end
        if idx ~= nil and d <= FLEE_SECTOR_R then
            local bit = 2 ^ idx
            if math.floor(out.sectorMask / bit) % 2 < 1 then
                out.sectorMask = out.sectorMask + bit
                out.sectorN = out.sectorN + 1
            end
        end
        local sx, sy = bx - z:getX(), by - z:getY()
        local len = math.sqrt(sx * sx + sy * sy)
        if len > 0.001 then
            local w = 1 / math.max(d, 0.5)
            out.pushX = out.pushX + (sx / math.max(d, 0.1)) * w
            out.pushY = out.pushY + (sy / math.max(d, 0.1)) * w
        end
        if d <= FOOT_AROUND then
            cx, cy, cn = cx + z:getX(), cy + z:getY(), cn + 1
        end
        if d < out.threatD then
            out.threatD, out.threat = d, z
        end
    end

    local list = nil
    if BridgeZS ~= nil then
        local ok, l = pcall(function() return BridgeZS.near(bx, by, scanLimit, { tag = "fight.crowd" }) end)
        if ok then list = l end
    end
    if list == nil then list = getCell():getZombieList() end
    if list ~= nil then
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            local ok = false
            if z ~= nil and z ~= body then
                pcall(function()
                    ok = z:isAlive() and z:getHealth() > 0
                        and math.abs(z:getZ() - bz) < 0.8
                        and not instanceof(z, "IsoAnimal")
                        and not isBody(z)
                        and not BridgeFight.ownerRisen(z, red)
                        and not BridgeData.harmless(z)
                end)
            end
            if ok then addHostile(z) end
        end
    end

    local npcOn = false
    if BridgeKnoxNpc ~= nil and type(BridgeKnoxNpc.near) == "function" then
        npcOn = true
        if type(BridgeKnoxNpc.allowMelee) == "function" then
            local okm, allow = pcall(BridgeKnoxNpc.allowMelee)
            npcOn = okm and allow == true
        end
    end
    if npcOn then
        pcall(function()
            local npcs = BridgeKnoxNpc.near(bx, by, scanLimit, red)
            for i = 1, #npcs do
                local n = npcs[i]
                local ok = false
                pcall(function()
                    ok = n ~= nil and n ~= body and BridgeKnoxNpc.isNpc(n)
                        and n:isAlive() == true and n:isDead() ~= true
                        and math.abs(n:getZ() - bz) < 0.8
                        and BridgeKnoxNpc.hostile(n, red) == true
                        and not isBody(n)
                        and not BridgeFight.ownerRisen(n, red)
                        and not BridgeData.harmless(n)
                end)
                if ok then addHostile(n) end
            end
        end)
    end

    if cn > 0 then
        out.cx, out.cy = cx / cn, cy / cn
        out.centerDist = math.sqrt((out.cx - bx) ^ 2 + (out.cy - by) ^ 2)
    elseif target ~= nil then
        out.cx, out.cy = target:getX(), target:getY()
        out.centerDist = dist(target, body)
    end
    for i = 0, 3 do
        local bi, bj = 2 ^ i, 2 ^ (i + 4)
        if math.floor(out.sectorMask / bi) % 2 >= 1
                and math.floor(out.sectorMask / bj) % 2 >= 1 then
            out.opposite = out.opposite + 1
        end
        if math.floor(out.sectorMaskGun / bi) % 2 >= 1
                and math.floor(out.sectorMaskGun / bj) % 2 >= 1 then
            out.oppositeGun = out.oppositeGun + 1
        end
        if math.floor(out.sectorMaskCrowd / bi) % 2 >= 1
                and math.floor(out.sectorMaskCrowd / bj) % 2 >= 1 then
            out.oppositeCrowd = out.oppositeCrowd + 1
        end
    end
    out.crowdN, out.crowdX, out.crowdY = cn, out.cx, out.cy
    return out
end
BridgeFight.scan = footScan

local function footBodyClear(body, x, y, z, skip, gap)
    local ok = false
    local lim = gap or FOOT_GAP
    pcall(function()
        local cell = getCell()
        local gx, gy, gz = math.floor(x), math.floor(y), math.floor(z)
        local dest = cell:getGridSquare(gx, gy, gz)
        if dest == nil or not dest:isFree(false) then return end
        if dest:isVehicleIntersecting() then return end
        if dest.HasStairs ~= nil and dest:HasStairs() then return end
        for dx = -1, 1 do
            for dy = -1, 1 do
                local sq = cell:getGridSquare(gx + dx, gy + dy, gz)
                if sq ~= nil then
                    local movers = sq:getMovingObjects()
                    if movers ~= nil then
                        for i = 0, movers:size() - 1 do
                            local m = movers:get(i)
                            if m ~= nil and m ~= body and m ~= skip then
                                local mx, my = m:getX(), m:getY()
                                local ddx, ddy = mx - x, my - y
                                if ddx * ddx + ddy * ddy < lim * lim then return end
                            end
                        end
                    end
                end
            end
        end
        ok = true
    end)
    return ok
end

local function footClear(body, x, y, z, skip, gap)
    if not BridgeMove.lineClear(body, x, y, z) then return false end
    return footBodyClear(body, x, y, z, skip, gap)
end

BridgeFight.clearAt = footClear

local function footPoint(body, dx, dy, len)
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local size = math.sqrt(dx * dx + dy * dy)
    if size < 0.001 then return nil end
    local x, y = bx + (dx / size) * len, by + (dy / size) * len
    if not footClear(body, x, y, bz) then return nil end
    return x, y
end

local function footLeash(mode)
    local leash = tonumber(mode and mode.leash) or 999
    if BridgeFight.guardOnly and leash > 3.0 then leash = 3.0 end
    return leash
end

local function swingDrift(body, red, t, mode)
    local reason = nil
    local dx, dy = BridgeFight.swingBackX, BridgeFight.swingBackY
    local drift = FOOT_SWING_DRIFT
    if BridgeFight.FOOT_SWING_BACK ~= true then
        reason = "disabled"
    elseif not BridgeFight.swingBack or not BridgeFight.escapeOn then
        reason = "flag"
    elseif BridgeFight.state ~= "swing" then
        reason = "state"
    elseif BridgeFight.floorSwing then
        reason = "floor"
    elseif dx == nil then
        reason = "dir"
    end
    local a = BridgeFight.anim
    local isBwd = type(a) == "string" and string.sub(a, -3) == "Bwd"
    if reason == nil and (BridgeFight.kind == "shove" or isBwd) then
        drift = FOOT_BWD_NUDGE
        local budget = FOOT_BWD_BUDGET
        if (BridgeFight.pressN or 0) >= FLEE_PRESSURE_PRESS
                and (BridgeFight.sectorN or 0) >= FLEE_PRESSURE_SECTOR
                and not BridgeFight.flee then
            budget = FLEE_PRESSURE_BUDGET
        end
        if isBwd and (BridgeFight.swingDriftApplied or 0) * FOOT_BWD_NUDGE >= budget then
            reason = "budget"
        end
    end
    local rng = nil
    pcall(function() rng = weapon(body):getMaxRange() end)
    if reason == nil and BridgeFight.swingBackFlank and rng ~= nil and t ~= nil
            and dist(body, t) >= rng - 0.15 then
        reason = "flank-reach"
    end
    local x, y = nil, nil
    if reason == nil then
        x = body:getX() + dx * drift
        y = body:getY() + dy * drift
        if not footClear(body, x, y, body:getZ(), t, FOOT_DRIFT_GAP) then
            reason = "clear"
        elseif red ~= nil then
            local rx, ry = x - red:getX(), y - red:getY()
            local leash = footLeash(mode)
            if rx * rx + ry * ry > leash * leash then reason = "leash" end
        end
    end
    if reason == nil then
        pcall(function()
            body:setX(x)
            body:setY(y)
        end)
        BridgeMove.moving = true
        BridgeFight.swingDriftApplied = (BridgeFight.swingDriftApplied or 0) + 1
    end
    if Bridge.verbose and (Bridge.time % 5) == 0 then
        local gap = t ~= nil and dist(body, t) or -1
        vlog(string.format("drift %s dx=%.2f dy=%.2f step=%.3f flank=%s gap=%.2f range=%.2f x=%.2f y=%.2f bump=%s",
            reason or "apply", dx or 0, dy or 0, drift, tostring(BridgeFight.swingBackFlank),
            gap, rng or -1, body:getX(), body:getY(), tostring(body:getBumpType())))
    end
end

local function footCandidate(body, red, mode, dx, dy, want, how)
    local size = math.sqrt(dx * dx + dy * dy)
    if size < 0.001 then return nil end
    dx, dy = dx / size, dy / size
    local rx, ry = red:getX(), red:getY()
    local leash = footLeash(mode)
    local scales = { 1.0, 0.6, 0.35 }
    for i = 1, #scales do
        local len = want * scales[i]
        local x, y = footPoint(body, dx, dy, len)
        if x ~= nil then
            local ddx, ddy = x - rx, y - ry
            if ddx * ddx + ddy * ddy <= leash * leash then
                return x, y, how
            end
        end
    end
    return nil
end

local function footBump(body)
    local v, rifle = "", ""
    pcall(function()
        v = tostring(body:getVariableString("NotAloneWeapon") or "")
        rifle = tostring(body:getVariableString("NotAloneRifle") or "")
    end)
    if v == "handgun" then return "NA_BackstepHandgun" end
    if v == "2h" then
        if rifle == "1" then return "NA_BackstepRifle" end
        return "NA_Backstep2H"
    end
    return "NA_Backstep1H"
end

local function footEnd(body)
    if body == nil and Bridge ~= nil then body = Bridge.body end
    local bump = BridgeFight.stepBump
    if body ~= nil and bump ~= nil then
        pcall(function() body:setAnimatingBackwards(false) end)
        pcall(function() if tostring(body:getBumpType()) == bump then body:setBumpType("") end end)
    end
    BridgeMove.walkType = "Walk"
    BridgeFight.stepBump = nil
    BridgeFight.stepUntil = 0
    BridgeFight.stepGoalX, BridgeFight.stepGoalY, BridgeFight.stepGoalZ = nil, nil, nil
    BridgeFight.stepTarget, BridgeFight.stepWhy = nil, nil
    BridgeFight.stepStart = nil
    BridgeFight.stepThreatX, BridgeFight.stepThreatY = nil, nil
    BridgeFight.stepLastCrowdDist = nil
    BridgeFight.stepScan, BridgeFight.stepScanBody, BridgeFight.stepScanAt = nil, nil, nil
    BridgeFight.stepEscape = false
    BridgeFight.stepPath = false
    BridgeFight.escapePathAt = nil
    BridgeFight.escapePathX, BridgeFight.escapePathY = nil, nil
    if BridgeFight.state == "step" then BridgeFight.state = "idle" end
    BridgeFight.stepReadyAt = Bridge.time + FOOT_COOLDOWN
end

local function footReset(body)
    footEnd(body)
    BridgeFight.stepStallAt = nil
    BridgeFight.stepReadyAt = 0
end

local function escapeReset()
    local hadStep = BridgeFight.stepEscape
    BridgeFight.escapeOn = false
    BridgeFight.escapeClearAt = nil
    BridgeFight.escapePointX, BridgeFight.escapePointY, BridgeFight.escapePointZ = nil, nil, nil
    BridgeFight.escapeWhy = nil
    BridgeFight.escapeCornered = false
    BridgeFight.stepEscape = false
    BridgeFight.stepPath = false
    BridgeFight.swingBack = false
    BridgeFight.swingBackX = nil
    BridgeFight.swingBackY = nil
    BridgeFight.swingBackFlank = false
    BridgeFight.escapeScan = nil
    BridgeFight.flee = false
    BridgeFight.fleeClearAt = nil
    BridgeFight.fleeGoalX, BridgeFight.fleeGoalY, BridgeFight.fleeGoalZ = nil, nil, nil
    BridgeFight.fleeNext = 0
    BridgeFight.fleeFails = 0
    BridgeFight.fleePathAt, BridgeFight.fleePathX, BridgeFight.fleePathY = nil, nil, nil
    BridgeFight.escapePathAt = nil
    BridgeFight.escapePathX, BridgeFight.escapePathY = nil, nil
    if hadStep then footEnd(nil) end
end

local function footFinish(body, red, why)
    local wasEscape = BridgeFight.stepEscape
    local before = BridgeFight.stepLastCrowdDist
    if before ~= nil and not wasEscape then
        local S = footScan(body, red)
        local after = S.centerDist
        if after ~= nil and after >= before + FOOT_GAIN then
            BridgeFight.stepStallAt = nil
        elseif BridgeFight.stepStallAt == nil then
            BridgeFight.stepStallAt = BridgeFight.stepStart or Bridge.time
        end
        vlog(string.format("footwork %s: crowd %.2f -> %s (%+.2f)",
            tostring(why), before, after ~= nil and string.format("%.2f", after) or "?", after ~= nil and (after - before) or 0))
    end
    if wasEscape then vlog("escape burst end: " .. tostring(why)) end
    footEnd(body)
end

local function footStart(body, red, t, mode, range)
    if BridgeFight.state == "swing" then return false end
    if Bridge.time < (BridgeFight.stepReadyAt or 0) then return false end
    if BridgeFight.stepStallAt ~= nil and Bridge.time - BridgeFight.stepStallAt >= FOOT_STALL then
        BridgeFight.stepStallAt = nil
        BridgeFight.stepReadyAt = Bridge.time + FOOT_STALL
        vlog("footwork stop: no crowd gain for 0.5 s")
        return false
    end
    local S = footScan(body, red)
    BridgeFight.stepScan, BridgeFight.stepScanBody, BridgeFight.stepScanAt = S, body, Bridge.time
    local d = (t ~= nil) and dist(body, t) or math.huge
    local tooClose = t ~= nil and d < (range - FOOT_REACH)
    local crowded = S.otherNear >= 1 or (S.nearN >= 1 and S.pressN >= 2)
    if not (tooClose or crowded) then return false end

    local step = FOOT_STEP
    if t ~= nil and range ~= nil then
        step = math.max(0, math.min(FOOT_STEP, range - 0.15 - d))
    end
    if step < 0.3 then return false end

    local bx, by = body:getX(), body:getY()
    local dirX, dirY = S.pushX, S.pushY
    if S.pressN < 2 then
        local z = S.threat or t
        if z ~= nil then dirX, dirY = bx - z:getX(), by - z:getY() end
    end
    local size = math.sqrt(dirX * dirX + dirY * dirY)
    if size < 0.001 and S.cx ~= nil then
        dirX, dirY = bx - S.cx, by - S.cy
        size = math.sqrt(dirX * dirX + dirY * dirY)
    end
    if size < 0.001 and t ~= nil then
        dirX, dirY = bx - t:getX(), by - t:getY()
        size = math.sqrt(dirX * dirX + dirY * dirY)
    end

    local x, y, how = footCandidate(body, red, mode, dirX, dirY, step, "push")
    if x == nil and size > 0.001 then
        local px, py = -dirY / size, dirX / size
        if S.cx ~= nil then
            local d1 = (bx + px - S.cx) ^ 2 + (by + py - S.cy) ^ 2
            local d2 = (bx - px - S.cx) ^ 2 + (by - py - S.cy) ^ 2
            if d2 > d1 then px, py = -px, -py end
        elseif t ~= nil then
            local d1 = (bx + px - t:getX()) ^ 2 + (by + py - t:getY()) ^ 2
            local d2 = (bx - px - t:getX()) ^ 2 + (by - py - t:getY()) ^ 2
            if d2 > d1 then px, py = -px, -py end
        end
        x, y, how = footCandidate(body, red, mode, px, py, step, "side")
    end
    if x == nil then
        local bestX, bestY, bestDot = nil, nil, nil
        for i = 0, 7 do
            local a = i * math.pi / 4
            local ox, oy = math.cos(a), math.sin(a)
            local px, py = footPoint(body, ox, oy, FOOT_OUT)
            if px ~= nil then
                local fits = true
                if range ~= nil and t ~= nil then
                    local gx, gy = px - t:getX(), py - t:getY()
                    fits = gx * gx + gy * gy <= (range - 0.1) * (range - 0.1)
                end
                local dot = 0
                if size > 0.001 then dot = (ox * dirX + oy * dirY) / size end
                if fits and (bestDot == nil or dot > bestDot) then
                    bestX, bestY, bestDot = px, py, dot
                end
            end
        end
        if bestX ~= nil then
            local rx, ry = red:getX(), red:getY()
            local leash = footLeash(mode)
            local ddx, ddy = bestX - rx, bestY - ry
            if ddx * ddx + ddy * ddy <= leash * leash then
                x, y, how = bestX, bestY, "out"
            end
        end
    end
    if x == nil then
        vlog(string.format("footwork reject: press=%d near=%d other=%d push=%.2f,%.2f d=%.2f",
            S.pressN, S.nearN, S.otherNear, S.pushX, S.pushY, d))
        return false
    end

    local len = math.sqrt((x - bx) ^ 2 + (y - by) ^ 2)
    local bump = footBump(body)
    local threat = S.threat or t
    BridgeFight.state = "step"
    BridgeFight.stepBump = bump
    BridgeFight.stepGoalX, BridgeFight.stepGoalY, BridgeFight.stepGoalZ = x, y, body:getZ()
    BridgeFight.stepTarget = t
    BridgeFight.stepWhy = how
    BridgeFight.stepStart = Bridge.time
    BridgeFight.stepUntil = Bridge.time + FOOT_STEP_MAX
    BridgeFight.stepLastCrowdDist = S.centerDist
    BridgeFight.stepThreatX = threat ~= nil and threat:getX() or nil
    BridgeFight.stepThreatY = threat ~= nil and threat:getY() or nil
    BridgeFight.info = string.format("step %s %.1f", tostring(how), len)
    vlog(string.format("footwork step %s len=%.2f step=%.2f reach=%.2f gap=%.2f press=%d near=%d other=%d push=%.2f,%.2f crowd=%.2f bump=%s",
        tostring(how), len, step, range or -1, d, S.pressN, S.nearN, S.otherNear, S.pushX, S.pushY, S.centerDist or -1, bump))
    return true
end

local function footTick(body, red, t, mode, range)
    if BridgeFight.FOOTWORK_ON ~= true and not BridgeFight.stepEscape then return false end
    if BridgeFight.state == "step" then
        if t == nil or not validTarget(t, body, red, mode) then
            local escape = BridgeFight.stepEscape
            footFinish(body, red, "target lost")
            if escape then escapeReset() end
            return false
        end
        if dist(body, red) > footLeash(mode) then
            local escape = BridgeFight.stepEscape
            footFinish(body, red, "leash")
            if escape then escapeReset() end
            return false
        end
        local goalX, goalY, goalZ = BridgeFight.stepGoalX, BridgeFight.stepGoalY, BridgeFight.stepGoalZ
        if goalX == nil then
            footFinish(body, red, "no goal")
            return false
        end
        local dx, dy = goalX - body:getX(), goalY - body:getY()
        if dx * dx + dy * dy <= FOOT_ARRIVE * FOOT_ARRIVE then
            footFinish(body, red, "arrived")
            return false
        end
        if Bridge.time >= (BridgeFight.stepUntil or 0) then
            footFinish(body, red, "timeout")
            return false
        end
        if BridgeFight.stepEscape and BridgeFight.stepPath then
            local px, py = BridgeFight.escapePathX, BridgeFight.escapePathY
            local moved = 0
            if px ~= nil then
                local mx, my = body:getX() - px, body:getY() - py
                moved = math.sqrt(mx * mx + my * my)
            end
            if BridgeFight.escapePathAt ~= nil and Bridge.time - BridgeFight.escapePathAt >= 30 and moved < 0.4 then
                BridgeFight.escapeCornered = true
                footFinish(body, red, "escape path blocked")
                return false
            end
            if moved >= 0.4 then
                BridgeFight.escapePathAt = Bridge.time
                BridgeFight.escapePathX, BridgeFight.escapePathY = body:getX(), body:getY()
            end
            pcall(function() BridgeMove.goToward(body, goalX, goalY, goalZ, true) end)
            BridgeMove.walkType = "Walk"
            return true
        end
        local bump = BridgeFight.stepBump
        local ok = BridgeMove.goStraight(body, goalX, goalY, goalZ, false,
            function(b, x, y, zz) return footClear(b, x, y, zz) end, true)
        if not ok then
            footFinish(body, red, "blocked")
            return false
        end
        pcall(function() body:setBumpType(bump) end)
        pcall(function() body:setAnimatingBackwards(true) end)
        local tx, ty = BridgeFight.stepThreatX, BridgeFight.stepThreatY
        if tx == nil and t ~= nil then tx, ty = t:getX(), t:getY() end
        if tx ~= nil then pcall(function() body:faceLocationF(tx, ty) end) end
        BridgeMove.walkType = "Walk"
        return true
    end
    return footStart(body, red, t, mode, range)
end

local function escapePoint(body, red, S, mode, radii, leash)
    local gx, gy = S.cx, S.cy
    if gx == nil then return nil end
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local pushX, pushY = S.pushX, S.pushY
    local plen = math.sqrt(pushX * pushX + pushY * pushY)
    if plen > 0.001 then
        pushX, pushY = pushX / plen, pushY / plen
    else
        pushX, pushY = bx - gx, by - gy
        plen = math.sqrt(pushX * pushX + pushY * pushY)
        if plen > 0.001 then
            pushX, pushY = pushX / plen, pushY / plen
        else
            pushX, pushY = 0, 0
        end
    end
    local nowDist = math.sqrt((bx - gx) ^ 2 + (by - gy) ^ 2)
    local lim = leash or footLeash(mode)
    local rx, ry = red:getX(), red:getY()
    local best, bestScore = nil, nil
    local farBest, farScore = nil, nil
    for _, radius in ipairs(radii or { 2.0, 3.0 }) do
        for i = 0, 7 do
            local a = i * math.pi / 4
            local dx, dy = math.cos(a), math.sin(a)
            local x, y = bx + dx * radius, by + dy * radius
            if footClear(body, x, y, bz) then
                local lx, ly = x - rx, y - ry
                if lx * lx + ly * ly <= lim * lim then
                    local nd = math.sqrt((x - gx) ^ 2 + (y - gy) ^ 2)
                    local dot = (plen > 0.001) and (dx * pushX + dy * pushY) or 0
                    local score = 2 * dot + (nd - nowDist)
                    local cand = { x = x, y = y, score = score, dist = nd }
                    if bestScore == nil or score > bestScore then best, bestScore = cand, score end
                    if nd > nowDist + 0.01 and (farScore == nil or score > farScore) then
                        farBest, farScore = cand, score
                    end
                end
            end
        end
    end
    local pick = farBest or best
    if pick == nil then return nil end
    return pick.x, pick.y, pick.score
end
BridgeFight.escapePoint = escapePoint

local function nearestInReach(body, red, range, S)
    S = S or footScan(body, red)
    local z = S.threat
    if z ~= nil and S.threatD <= range + 0.1 then
        local clear = false
        pcall(function() clear = BridgeMove.lineClear(body, z:getX(), z:getY(), z:getZ()) end)
        if clear then return z end
    end
    local cur = BridgeFight.target
    if cur ~= nil and cur ~= z and dist(body, cur) <= range + 0.1 then
        local clear = false
        pcall(function() clear = BridgeMove.lineClear(body, cur:getX(), cur:getY(), cur:getZ()) end)
        if clear then return cur end
    end
    return nil
end

local function escapeTick(body, red, t, mode, range, S)
    if BridgeFight.FOOT_ESCAPE_ON ~= true then
        if BridgeFight.stepEscape then footEnd(body) end
        escapeReset()
        return false
    end
    if BridgeFight.state == "swing" and not BridgeFight.escapeOn then return false end

    S = S or footScan(body, red)
    BridgeFight.escapeScan = S
    local g2, g25 = S.g2 or 0, S.g25 or 0

    if BridgeFight.escapeOn then
        if g25 < 2 then
            if BridgeFight.escapeClearAt == nil then BridgeFight.escapeClearAt = Bridge.time end
            if Bridge.time - BridgeFight.escapeClearAt >= 30 then
                escapeReset()
                footEnd(body)
                BridgeFight.info = "escape clear"
                vlog(string.format("escape clear: g2=%d g25=%d", g2, g25))
                return false
            end
        else
            BridgeFight.escapeClearAt = nil
        end
    end

    if BridgeFight.state == "swing" then return false end

    if BridgeFight.state == "step" and BridgeFight.stepEscape then
        if footTick(body, red, t, mode, range) then return true end
    end

    BridgeFight.swingBack = false
    BridgeFight.swingBackFlank = false

    if g2 < 2 then return false end

    BridgeFight.escapeOn = true
    BridgeFight.escapeClearAt = nil
    if BridgeFight.state == "step" then return false end

    local near = nil
    if BridgeFight.FOOT_SWING_BACK == true then
        near = nearestInReach(body, red, range, S)
    end
    local pressed = (S.pressN or 0) >= 2
    local flankClose = (S.threatD or 999) <= (range or 0) - 0.15
    if Bridge.verbose and (Bridge.time % 10) == 3 then
        vlog(string.format("escape tick: g2=%d g25=%d nearN=%d pressN=%d nearest=%.2f range=%.2f near=%s pressed=%s flankClose=%s state=%s target=%s",
            g2, g25, S.nearN or 0, S.pressN or 0, S.threatD or -1, range or -1,
            near ~= nil and "yes" or "no", tostring(pressed), tostring(flankClose),
            tostring(BridgeFight.state), t ~= nil and tostring(t:getActionStateName()) or "nil"))
    end
    -- Engage at range - 0.15 so the backward drift still lands the hit.
    if near ~= nil and pressed and (S.threatD or 999) <= (range or 0) - 0.15 then
        local sx, sy = escapePoint(body, red, S, mode)
        local bx, by, bz = body:getX(), body:getY(), body:getZ()
        local ddx, ddy, src = nil, nil, "point"
        if sx ~= nil then
            ddx, ddy = sx - bx, sy - by
        else
            src = "away-nearest"
            ddx, ddy = bx - near:getX(), by - near:getY()
            if math.abs(ddx) < 0.001 and math.abs(ddy) < 0.001 and S.cx ~= nil then
                src = "away-crowd"
                ddx, ddy = bx - S.cx, by - S.cy
            end
            if math.abs(ddx) < 0.001 and math.abs(ddy) < 0.001 then
                src = "fallback"
                ddx, ddy = -1, 0
            end
        end
        local dlen = math.sqrt(ddx * ddx + ddy * ddy)
        if dlen < 0.001 then return false end
        BridgeFight.escapeCornered = false
        BridgeFight.escapeWhy = "swing"
        if sx ~= nil then
            BridgeFight.escapePointX, BridgeFight.escapePointY, BridgeFight.escapePointZ = sx, sy, bz
        end
        BridgeFight.swingBack = true
        BridgeFight.swingBackFlank = not pressed
        BridgeFight.swingBackX, BridgeFight.swingBackY = ddx / dlen, ddy / dlen
        BridgeFight.info = "escape swing"
        vlog(string.format("escape swing-back src=%s flank=%s dir=%.2f,%.2f drift=%.3f gap=%.2f range=%.2f target=%s",
            tostring(src), tostring(BridgeFight.swingBackFlank), ddx / dlen, ddy / dlen, FOOT_SWING_DRIFT,
            dist(body, near), range or -1, tostring(near:getActionStateName())))
        return false
    end

    -- No target in weapon reach: close in and fight. Do not add distance.
    if Bridge.verbose and (Bridge.time % 10) == 4 then
        vlog(string.format("escape hold: nearest=%.2f range=%.2f near=%s pressed=%s flankClose=%s -> fight/approach",
            S.threatD or -1, range or -1, near ~= nil and "yes" or "no", tostring(pressed), tostring(flankClose)))
    end
    do
        return false
    end

    local px, py, score = escapePoint(body, red, S, mode)
    if px == nil then
        BridgeFight.escapeCornered = true
        BridgeFight.info = string.format("escape cornered %d", g2)
        vlog(string.format("escape cornered: g2=%d g25=%d push=%.2f,%.2f", g2, g25, S.pushX, S.pushY))
        return false
    end
    BridgeFight.escapeCornered = false
    BridgeFight.escapeWhy = "group"

    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local dx, dy = px - bx, py - by
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then return false end
    local want = math.max(0.30, math.min(0.60, range * 0.4))
    local step = math.min(len, want + FOOT_ARRIVE)
    local gx, gy = bx + (dx / len) * step, by + (dy / len) * step

    BridgeFight.escapePointX, BridgeFight.escapePointY, BridgeFight.escapePointZ = px, py, bz
    BridgeFight.stepEscape = true
    BridgeFight.stepPath = false
    BridgeFight.state = "step"
    BridgeFight.stepGoalX, BridgeFight.stepGoalY, BridgeFight.stepGoalZ = gx, gy, bz
    BridgeFight.stepTarget = t
    BridgeFight.stepWhy = "escape"
    BridgeFight.stepStart = Bridge.time
    BridgeFight.stepUntil = Bridge.time + FOOT_STEP_MAX
    BridgeFight.stepLastCrowdDist = nil
    BridgeFight.escapePathAt = Bridge.time
    BridgeFight.escapePathX, BridgeFight.escapePathY = bx, by
    local threat = S.threat or t
    local bump = footBump(body)
    BridgeFight.stepBump = bump
    BridgeFight.stepThreatX = threat ~= nil and threat:getX() or nil
    BridgeFight.stepThreatY = threat ~= nil and threat:getY() or nil
    BridgeFight.info = string.format("escape group %d", g2)

    pcall(function() BridgeMove.stopPath(body) end)

    if footClear(body, gx, gy, bz) then
        local ok = BridgeMove.goStraight(body, gx, gy, bz, false,
            function(b, x, y, zz) return footClear(b, x, y, zz) end, true)
        if ok then
            pcall(function() body:setBumpType(bump) end)
            pcall(function() body:setAnimatingBackwards(true) end)
            if threat ~= nil then pcall(function() body:faceLocationF(threat:getX(), threat:getY()) end) end
            BridgeMove.walkType = "Walk"
            vlog(string.format("escape burst back goal=%.2f dist=%.2f reach=%.2f gap=%.2f g2=%d g25=%d point=%.1f,%.1f score=%.2f bump=%s",
                step, want, range or -1, S.threatD or 0, g2, g25, px, py, score or 0, bump))
            return true
        end
    end

    BridgeFight.stepPath = true
    BridgeFight.stepBump = nil
    pcall(function() BridgeMove.goToward(body, gx, gy, bz, true) end)
    if threat ~= nil then pcall(function() body:faceLocationF(threat:getX(), threat:getY()) end) end
    vlog(string.format("escape burst path goal=%.2f dist=%.2f reach=%.2f gap=%.2f g2=%d g25=%d point=%.1f,%.1f score=%.2f",
        step, want, range or -1, S.threatD or 0, g2, g25, px, py, score or 0))
    return true
end

local function fleeTick(body, red, mode, S, gunMode)
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local sectors = gunMode == true and (S.sectorNGun or 0) or (S.sectorN or 0)
    local nearN = S.nearN or 0

    if sectors <= FLEE_EXIT_SECTORS and nearN < FLEE_EXIT_NEAR then
        if BridgeFight.fleeClearAt == nil then BridgeFight.fleeClearAt = Bridge.time end
        local clearFor = Bridge.time - BridgeFight.fleeClearAt
        if clearFor >= FLEE_CLEAR_TICKS then
            BridgeFight.flee = false
            BridgeFight.fleeUntil = Bridge.time + FLEE_LOCKOUT
            BridgeFight.fleeClearAt = nil
            BridgeFight.fleeGoalX, BridgeFight.fleeGoalY, BridgeFight.fleeGoalZ = nil, nil, nil
            BridgeFight.fleePathAt, BridgeFight.fleePathX, BridgeFight.fleePathY = nil, nil, nil
            BridgeFight.state = "idle"
            BridgeFight.info = "flee end"
            BridgeMove.walkType = "Walk"
            pcall(function() BridgeMove.stopPath(body) end)
            if BridgeGunfight ~= nil and BridgeGunfight.isAssigned(body) then
                pcall(function() BridgeGunfight.resetAim(body, "flee end") end)
            end
            vlog(string.format("flee end clearFor=%d sectors=%d nearN=%d gun=%s ring=%.1f",
                clearFor, sectors, nearN, tostring(gunMode == true), gunMode == true and FLEE_GUN_SECTOR_R or FLEE_SECTOR_R))
            vlog(string.format("flee lockout until=%d", BridgeFight.fleeUntil))
            return false
        end
    elseif BridgeFight.fleeClearAt ~= nil then
        BridgeFight.fleeClearAt = nil
    end

    if BridgeFight.fleePathAt == nil then
        BridgeFight.fleePathAt = Bridge.time
        BridgeFight.fleePathX, BridgeFight.fleePathY = bx, by
    elseif Bridge.time - BridgeFight.fleePathAt >= FLEE_STUCK then
        local px, py = BridgeFight.fleePathX or bx, BridgeFight.fleePathY or by
        local moved = math.sqrt((bx - px) * (bx - px) + (by - py) * (by - py))
        if moved < 0.4 then
            BridgeFight.fleeFails = (BridgeFight.fleeFails or 0) + 1
            vlog(string.format("flee blocked reason=stuck moved=%.2f fails=%d", moved, BridgeFight.fleeFails))
            BridgeFight.fleeGoalX, BridgeFight.fleeGoalY, BridgeFight.fleeGoalZ = nil, nil, nil
            BridgeFight.fleeNext = 0
            if BridgeFight.fleeFails >= FLEE_MAX_FAILS * 2 then
                BridgeFight.flee = false
                BridgeFight.fleeUntil = Bridge.time + FLEE_LOCKOUT
                BridgeFight.fleeClearAt = nil
                BridgeFight.fleeGoalX, BridgeFight.fleeGoalY, BridgeFight.fleeGoalZ = nil, nil, nil
                BridgeFight.fleePathAt, BridgeFight.fleePathX, BridgeFight.fleePathY = nil, nil, nil
                BridgeFight.state = "idle"
                BridgeFight.info = "flee end"
                BridgeMove.walkType = "Walk"
                pcall(function() BridgeMove.stopPath(body) end)
                if BridgeGunfight ~= nil and BridgeGunfight.isAssigned(body) then
                    pcall(function() BridgeGunfight.resetAim(body, "flee end") end)
                end
                vlog(string.format("flee end reason=stuck sectors=%d gun=%s ring=%.1f",
                    sectors, tostring(gunMode == true), gunMode == true and FLEE_GUN_SECTOR_R or FLEE_SECTOR_R))
                return false
            end
        else
            BridgeFight.fleeFails = 0
        end
        BridgeFight.fleePathAt = Bridge.time
        BridgeFight.fleePathX, BridgeFight.fleePathY = bx, by
    end

    local gx, gy = BridgeFight.fleeGoalX, BridgeFight.fleeGoalY
    if gx == nil or Bridge.time >= (BridgeFight.fleeNext or 0) then
        local forcePlayer = (BridgeFight.fleeFails or 0) >= FLEE_MAX_FAILS
        local playerSafe = false
        if forcePlayer then
            playerSafe = true
        elseif dist(body, red) <= mode.leash * FLEE_LEASH_MULT then
            playerSafe = true
            if S.cx ~= nil then
                local rcx, rcy = red:getX() - S.cx, red:getY() - S.cy
                local bdx, bdy = bx - S.cx, by - S.cy
                local rd = math.sqrt(rcx * rcx + rcy * rcy)
                local bd = math.sqrt(bdx * bdx + bdy * bdy)
                playerSafe = rd > 2.0 and rd <= bd
            end
        end
        if playerSafe then
            gx, gy = red:getX(), red:getY()
        else
            gx, gy = escapePoint(body, red, S, mode,
                { FLEE_BURST_MIN + 1.0, FLEE_BURST_MAX }, mode.leash * FLEE_LEASH_MULT)
        end
        if gx == nil then
            local bestD = nil
            for i = 0, 7 do
                local a = i * math.pi / 4
                local px, py = bx + math.cos(a) * FLEE_BURST_MIN, by + math.sin(a) * FLEE_BURST_MIN
                if footClear(body, px, py, bz) then
                    local dd = 0
                    if S.cx ~= nil then
                        dd = math.sqrt((px - S.cx) * (px - S.cx) + (py - S.cy) * (py - S.cy))
                    end
                    if bestD == nil or dd > bestD then gx, gy, bestD = px, py, dd end
                end
            end
        end
        if gx == nil then gx, gy = red:getX(), red:getY() end

        local dx, dy = gx - bx, gy - by
        local len = math.sqrt(dx * dx + dy * dy)
        if len > FLEE_BURST_MAX then
            gx, gy = bx + dx / len * FLEE_BURST_MAX, by + dy / len * FLEE_BURST_MAX
            len = FLEE_BURST_MAX
        end
        if len < 0.001 then return true end
        BridgeFight.fleeGoalX, BridgeFight.fleeGoalY, BridgeFight.fleeGoalZ = gx, gy, bz
        BridgeFight.fleeNext = Bridge.time + FLEE_REPLAN
        BridgeFight.state = "idle"
        pcall(function() BridgeMove.stopPath(body) end)
    end

    local goalZ = BridgeFight.fleeGoalZ or bz
    local straight = footClear(body, gx, gy, goalZ)
    pcall(function() body:faceLocationF(gx, gy) end)
    local ran = false
    if straight then
        BridgeMove.walkType = "Run"
        ran = BridgeMove.goStraight(body, gx, gy, goalZ, true,
            function(b, x, y, z) return footClear(b, x, y, z) end, false) == true
    end
    if not ran then
        BridgeMove.walkType = "Walk"
        pcall(function() BridgeMove.goToward(body, gx, gy, goalZ, true) end)
    end
    if Bridge.verbose and (Bridge.time % 10) == 0 then
        vlog(string.format("flee step goal=%.2f,%.2f dist=%.2f player=%s run=%s fails=%d",
            gx, gy, dist(body, red), tostring(dist(body, red) <= mode.leash * FLEE_LEASH_MULT),
            tostring(ran), BridgeFight.fleeFails or 0))
    end
    return true
end

function BridgeFight.reset(body)
    BridgeFight.target = nil
    BridgeFight.state = "idle"
    BridgeFight.hit = false
    BridgeFight.kind = "hit"
    BridgeFight.info = "none"
    BridgeFight.targetInfo = "none"
    BridgeFight.playerTarget = nil
    BridgeFight.playerFightUntil = 0
    BridgeFight.lastHitChar = nil
    BridgeFight.lastHitHealth = nil
    BridgeFight.flee = false
    BridgeFight.fleeUntil = 0
    BridgeFight.gunShoveSwing = false
    footReset(body)
    escapeReset()
    if BridgeGunfight ~= nil and BridgeGunfight.reset ~= nil then pcall(BridgeGunfight.reset) end
end




local function watchCrawlers(body, red)
    if not (Bridge.verbose and Bridge.every(60, 20)) then return end
    pcall(function()
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= body and z:isCrawling() and z:isAlive() and dist(z, body) < 4 then
                vlog(string.format("crawler d=%.2f dred=%.2f state=%s seen=%s target=%s fight=%s info=%s",
                    dist(z, body), dist(z, red), tostring(z:getActionStateName()), tostring(visible(z, red)),
                    tostring(BridgeFight.target == z), tostring(BridgeFight.state), tostring(BridgeFight.info)))
            end
        end
    end)
end

local hitCapCache = {}
local function hitCap(item)
    local key = nil
    pcall(function() key = item:getFullType() end)
    if key ~= nil and hitCapCache[key] ~= nil then return hitCapCache[key] end
    local cap = 1
    pcall(function() cap = item:getMaxHitCount() end)
    if type(cap) ~= "number" or cap < 1 then cap = 1 end
    if cap > MULTIHIT_MAX then cap = MULTIHIT_MAX end
    if key ~= nil then hitCapCache[key] = cap end
    return cap
end
BridgeFight.hitCap = hitCap

local function extraTargets(body, item, primary, want)
    local out = {}
    if want <= 0 then return out end
    local range, minAngle, fx, fy = 1.0, 0, 0, 0
    pcall(function() range = item:getMaxRange() end)
    pcall(function() minAngle = item:getMinAngle() end)
    pcall(function() fx, fy = body:getForwardDirectionX(), body:getForwardDirectionY() end)
    local red = BridgeData.owner()
    local cands = {}
    pcall(function()
        local bx, by = body:getX(), body:getY()
        local list = nil
        if BridgeZS ~= nil then list = BridgeZS.near(bx, by, range + 0.35, { tag = "fight.extra" }) end
        if list == nil then list = getCell():getZombieList() end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= primary and z ~= body and z:isAlive() and z:getHealth() > 0
                and not instanceof(z, "IsoPlayer") and (red == nil or z ~= red)
                and not isBody(z) and not remoteZombie(z) and not BridgeData.harmless(z)
                and not BridgeFight.ownerRisen(z, red)
                and math.abs(z:getZ() - body:getZ()) < 0.8 then
                local d = dist(body, z)
                if d <= range + 0.3 then
                    local dx, dy = z:getX() - body:getX(), z:getY() - body:getY()
                    local len = math.sqrt(dx * dx + dy * dy)
                    local dot = (len > 0.001) and ((fx * dx + fy * dy) / len) or 1
                    if dot >= minAngle then
                        local clear = false
                        pcall(function() clear = BridgeMove.lineClear(body, z:getX(), z:getY(), z:getZ()) end)
                        if clear then cands[#cands + 1] = { z = z, d = d } end
                    end
                end
            end
        end
    end)
    table.sort(cands, function(a, b) return a.d < b.d end)
    for i = 1, math.min(#cands, want) do out[i] = cands[i].z end
    return out
end

function BridgeFight.multiHit(body, item, primary)
    if MULTIHIT_ON ~= 1 then return end
    if not (SandboxVars and SandboxVars.MultiHitZombies) then return end
    if BridgeFight.floorSwing or isProne(primary) then return end
    local cap = hitCap(item)
    if cap <= 1 then return end
    local primaryDmg = BridgeFight.lastHitDmg
    if type(primaryDmg) ~= "number" then return end
    local extras = extraTargets(body, item, primary, cap - 1)
    for i = 1, #extras do
        local k = i + 1
        pcall(function() hitTarget(body, item, extras[i], true, primaryDmg / k) end)
    end
    if #extras > 0 then
        vlog(string.format("multi-hit: %d extra target(s) (cap %d)", #extras, cap))
    end
end






local function bareHands()
    if BridgeFight.bareHands == nil then
        BridgeFight.bareHands = instanceItem("Base.BareHands")
    end
    return BridgeFight.bareHands
end

local function isUnarmed(item)
    local unarmed = false
    pcall(function()
        unarmed = item ~= nil and (item:getFullType() == "Base.BareHands" or WeaponType.getWeaponType(item) == WeaponType.UNARMED)
    end)
    return unarmed
end



local function shoveDamageSplit()
    local mn, mx = 0.2, 0.4
    local bare = bareHands()
    pcall(function() mn = bare:getMinDamage() end)
    pcall(function() mx = bare:getMaxDamage() end)
    local roll = mn + (mx - mn) * ZombRandFloat(0, 1)
    return (roll / 0.5) * SHOVE_FORCE_MULT * pushMultiplier(strengthLevel())
end


local function shoveTargets(body)
    local out = {}
    local fx, fy = 0, 1
    pcall(function() fx, fy = body:getForwardDirectionX(), body:getForwardDirectionY() end)
    local red = BridgeData.owner()
    pcall(function()
        local bx, by = body:getX(), body:getY()
        local list = nil
        if BridgeZS ~= nil then list = BridgeZS.near(bx, by, SHOVE_RANGE + 0.05, { tag = "fight.shove" }) end
        if list == nil then list = getCell():getZombieList() end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= body and z:isAlive() and z:getHealth() > 0
                and not instanceof(z, "IsoPlayer") and (red == nil or z ~= red)
                and not isBody(z) and not remoteZombie(z) and not BridgeData.harmless(z)
                and not BridgeFight.ownerRisen(z, red) and not isProne(z)
                and math.abs(z:getZ() - body:getZ()) < 0.8 then
                local d = dist(body, z)
                if d <= SHOVE_RANGE then
                    local dx, dy = z:getX() - body:getX(), z:getY() - body:getY()
                    local len = math.sqrt(dx * dx + dy * dy)
                    local dot = (len > 0.001) and ((fx * dx + fy * dy) / len) or 1
                    if dot >= SHOVE_DOT then
                        local clear = false
                        pcall(function() clear = BridgeMove.lineClear(body, z:getX(), z:getY(), z:getZ()) end)
                        if clear then out[#out + 1] = { z = z, d = d, dot = dot } end
                    end
                end
            end
        end
    end)
    table.sort(out, function(a, b) return a.d < b.d end)
    while #out > SHOVE_MAX do out[#out] = nil end
    return out
end


local function shoveCritChance(body, victim)
    local chance = 35 + 2 * strengthLevel()
    local behind = false
    pcall(function() behind = body:isBehind(victim) end)
    if behind then
        local unarmedUnaware = false
        pcall(function()
            unarmedUnaware = (body:getPrimaryHandItem() == nil) and (victim:getTarget() == nil)
        end)
        chance = chance + (unarmedUnaware and SHOVE_BEHIND_UNARMED_BONUS or SHOVE_BEHIND_BONUS)
    end
    return chance
end


local function shoveApply(body, victim, dot, d, crit)
    local fake = getCell():getFakeZombieForHit()
    local rangeDel = d / 1.1 * 2
    if rangeDel < 0.3 then rangeDel = 1.0 end
    pcall(function() victim:setPlayerAttackPosition(victim:testDotSide(body)) end)
    pcall(function() victim:setHitFromBehind(body:isBehind(victim)) end)
    pcall(function() victim:setHitFromAngle(dot) end)
    pcall(function() victim:setAttackedBy(fake) end)

    pcall(function() victim:Hit(bareHands(), fake, shoveDamageSplit(), true, rangeDel * 1.5, false) end)
    if SHOVE_KNOCKDOWN == 1 and crit then
        pcall(function() victim:setKnockedDown(true) end)
    else

        pcall(function() victim:setHitReaction("") end)
        pcall(function() victim:setStaggerBack(true) end)
    end
    pcall(function() BridgeCallout.kill(victim) end)
    pcall(function() if BridgeKills ~= nil then BridgeKills.credit(victim) BridgeKills.confirm(victim) end end)
end


function BridgeFight.shoveResolve(body, primary)
    local crit, chance = false, 0
    if SHOVE_KNOCKDOWN == 1 then
        chance = shoveCritChance(body, primary)
        crit = ZombRand(100) < chance
    end
    BridgeFight.lastShoveCrit = chance
    BridgeFight.shoveCrit = crit
    local targets = shoveTargets(body)
    for i = 1, #targets do
        local e = targets[i]
        pcall(function() shoveApply(body, e.z, e.dot, e.d, crit) end)
    end
    local str = strengthLevel()
    local fitN = fitnessLevel()
    dbg(string.format("SHOVE targets=%d str=%d forceMult=%.2f crit=%.0f%% kd=%s fit=L%d(spd+%.0f%% drain x%.2f rec x%.2f)",
        #targets, str, pushMultiplier(str), chance, tostring(crit),
        fitN, fitnessSpeedAdd(fitN) * 100, fitnessDrainMult(fitN), fitnessRecoverMult(fitN)))
    BridgeFight.shoveStreak = (BridgeFight.shoveStreak or 0) + 1
    BridgeFight.shoveReadyAt = Bridge.time + SHOVE_COOLDOWN
    BridgeFight.info = string.format("shove %d%s", #targets, crit and " KD" or "")
    tire(bareHands(), 0, 0, false, body)
    vlog(string.format("shove: %d target(s) crit=%s (%.0f%%) streak=%d", #targets, tostring(crit), chance, BridgeFight.shoveStreak or 0))
end


local function wantShove(body, t, item)
    if SHOVE_ON ~= 1 then return false end
    if t == nil or instanceof(t, "IsoAnimal") then return false end
    if BridgeKnoxNpc ~= nil and BridgeKnoxNpc.isNpc(t) then return false end
    if isProne(t) then return false end
    if Bridge.time < (BridgeFight.shoveReadyAt or 0) then return false end
    local d = dist(body, t)
    -- Edge shoves whiff after the resolve delay; start closer.
    if d > SHOVE_RANGE - 0.25 then return false end
    if SHOVE_UNARMED == 1 and isUnarmed(item) then return true end
    if SHOVE_DEFENSIVE == 1 then
        local crowd = crowdAround(body)
        if crowd >= SHOVE_MIN_CROWD or d <= SHOVE_PANIC_RANGE then return true end
    end
    return false
end


local function startShove(body, t)
    pcall(function() body:faceLocationF(t:getX(), t:getY()) end)
    pcall(function()
        local st = body:getActionStateName()
        if st ~= "bumped" and st ~= "idle" then body:changeState(ZombieIdleState.instance()) end
    end)
    pcall(function() body:setVariable(HIT_VAR, false) end)
    pcall(function() body:setVariable("BumpAnimFinished", false) end)
    pcall(function() body:playSound("AttackShove") end)
    pcall(function() BridgeSound.voice(body, "MeleeShove", 40) end)
    body:setBumpType("Shove")
    if Bridge.mp then pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "look", { a = "Shove" }) end) end
    BridgeFight.anim = "Shove"
    BridgeFight.kind = "shove"
    BridgeFight.swingBack = false
    BridgeFight.swingBackFlank = false
    BridgeFight.swingBackX, BridgeFight.swingBackY = nil, nil
    local shovePress = 0
    local escS = BridgeFight.escapeScan
    if escS ~= nil then shovePress = escS.pressN or 0 end
    -- Shove drift only when the crowd is actually pressing (2+); flank shoves stay put.
    if BridgeFight.FOOT_SWING_BACK == true and BridgeFight.escapeOn and shovePress >= 2 then
        local bx, by = body:getX(), body:getY()
        local dx, dy = bx - t:getX(), by - t:getY()
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.001 then dx, dy, len = -1, 0, 1 end
        BridgeFight.swingBack = true
        BridgeFight.swingBackFlank = false
        BridgeFight.swingBackX, BridgeFight.swingBackY = dx / len, dy / len
    end
    BridgeFight.state = "swing"
    BridgeFight.swingStart = Bridge.time
    BridgeFight.swingLen, BridgeFight.attackAt = swingFrames(bareHands())
    BridgeFight.hit = false
    BridgeFight.swingStartX, BridgeFight.swingStartY = body:getX(), body:getY()
    BridgeFight.swingDriftApplied = 0
    BridgeFight.info = "shove " .. tostring(BridgeFight.swingLen) .. "f"
    BridgeFight.lastSwingAt = Bridge.time
    vlog(string.format("shove start len=%d escapeOn=%s pressN=%d back=%s flank=%s dir=%.2f,%.2f gap=%.2f",
        BridgeFight.swingLen, tostring(BridgeFight.escapeOn), shovePress, tostring(BridgeFight.swingBack),
        tostring(BridgeFight.swingBackFlank), BridgeFight.swingBackX or 0, BridgeFight.swingBackY or 0, dist(body, t)))
    return true
end


function BridgeFight.gunShove(body, t)
    if SHOVE_ON ~= 1 then return false end
    if body == nil or t == nil then return false end
    if Bridge.time < (BridgeFight.shoveReadyAt or 0) then return false end
    if isProne(t) then return false end
    if dist(body, t) > SHOVE_RANGE - 0.25 then return false end
    BridgeFight.target = t
    local ok = startShove(body, t)
    if ok then
        BridgeFight.gunShoveSwing = true
        if BridgeGunfight ~= nil then
            BridgeGunfight.aimUntil = nil
            BridgeGunfight.nextShotAt = nil
            BridgeGunfight.plantRequired = false
            BridgeGunfight.moving = false
            BridgeGunfight.state = "idle"
            BridgeGunfight.info = "shove"
            BridgeGunfight.gunShoveAt = Bridge.time
        end
    end
    return ok
end


local ASSIST_GRACE = 4 * 60

function BridgeFight.assistWindow(body, red)
    local attacking = false
    pcall(function() attacking = red:isAttacking() == true end)

    local hit, hp = nil, nil
    pcall(function()
        local h = red:getLastHitCharacter()
        if h ~= nil and instanceof(h, "IsoZombie") and h:isAlive() and h:getHealth() > 0 then
            hit, hp = h, h:getHealth()
        end
    end)
    local freshHit = hit ~= nil and hit ~= BridgeFight.lastHitChar
    local hurt = hit ~= nil and hit == BridgeFight.lastHitChar
        and BridgeFight.lastHitHealth ~= nil and hp < BridgeFight.lastHitHealth
    if hit ~= nil then
        BridgeFight.lastHitChar = hit
        BridgeFight.lastHitHealth = hp
    end

    if not (attacking or freshHit or hurt) then return end
    BridgeFight.playerFightUntil = Bridge.time + ASSIST_GRACE
    if hit ~= nil then BridgeFight.playerTarget = hit end
end




local function tryVault(body, t)
    if BridgeMove == nil or BridgeMove.askClimb == nil then return end
    if BridgeMove.pendingClimb ~= nil then return end
    pcall(function()
        if Bridge.time < (BridgeMove.noCrossUntil or 0) then return end
        if math.abs(body:getZ() - t:getZ()) >= 0.5 then return end
        local cur = body:getCurrentSquare()
        if cur == nil then return end
        local dx, dy = t:getX() - body:getX(), t:getY() - body:getY()
        if math.abs(dx) < 0.05 and math.abs(dy) < 0.05 then return end
        local sx, sy = 0, 0
        if math.abs(dx) >= math.abs(dy) then sx = (dx >= 0) and 1 or -1
        else sy = (dy >= 0) and 1 or -1 end
        local ahead = getCell():getGridSquare(cur:getX() + sx, cur:getY() + sy, cur:getZ())
        if ahead == nil then return end
        local kind = nil
        pcall(function() kind = BridgeMove.edgeBetween(body, cur, ahead) end)
        if kind ~= "fence" then return end
        local safe = true
        pcall(function() safe = BridgeMove.vaultSafe(body, cur, ahead) == true end)
        if not safe then return end
        pcall(function() body:faceLocationF(t:getX(), t:getY()) end)
        pcall(function() BridgeMove.askClimb(body, "fence", nil) end)
    end)
end

function BridgeFight.update(body)
    if not BridgeFight.enabled then rest(false) return false end
    local red = BridgeData.owner()
    if red == nil then return false end

    if BridgeFight.stepBump ~= nil and (BridgeFight.state ~= "step" or BridgeFight.FOOTWORK_ON ~= true) then
        pcall(footEnd, body)
    end

    if BridgeData.combatOf(Bridge.store) == "backup" then
        pcall(BridgeFight.assistWindow, body, red)
    end

    local mode = BridgeFight.mode()
    local S = nil
    if FLEE_ON and not mode.passive then
        S = footScan(body, red)
        BridgeFight.escapeScan = S
        BridgeFight.pressN = S.pressN or 0
        BridgeFight.sectorN = S.sectorN or 0
        BridgeFight.opposite = S.opposite or 0
        BridgeFight.sectorNGun = S.sectorNGun or 0
        BridgeFight.oppositeGun = S.oppositeGun or 0
        BridgeFight.sectorNCrowd = S.sectorNCrowd or 0
        BridgeFight.oppositeCrowd = S.oppositeCrowd or 0
        local gunMode = BridgeGunfight ~= nil and BridgeGunfight.isAssigned ~= nil
            and BridgeGunfight.isAssigned(body) and BridgeGunfight.stance ~= "melee"
        local sectors = gunMode and (S.sectorNGun or 0) or (S.sectorN or 0)
        local needSectors = gunMode and FLEE_GUN_ENTER_SECTORS or FLEE_ENTER_SECTORS
        local ring = gunMode and FLEE_GUN_SECTOR_R or FLEE_SECTOR_R
        if not mode.passive then
            if BridgeFight.flee then
                return fleeTick(body, red, mode, S, gunMode)
            end
            local reloadFlee = BridgeGunfight ~= nil and BridgeGunfight.reloadFlee == true
            if not BridgeFight.gunShoveSwing and not reloadFlee
                    and Bridge.time >= (BridgeFight.fleeUntil or 0)
                    and sectors >= needSectors
                    and (S.pressN or 0) >= FLEE_ENTER_PRESS then
                if BridgeGunfight ~= nil and BridgeGunfight.isAssigned(body) then
                    pcall(function() BridgeGunfight.interruptForFlee(body) end)
                end
                escapeReset()
                footEnd(body)
                pcall(function() BridgeMove.stopPath(body) end)
                BridgeFight.flee = true
                BridgeFight.fleeClearAt = nil
                BridgeFight.fleeNext = 0
                BridgeFight.fleeFails = 0
                BridgeFight.fleeGoalX, BridgeFight.fleeGoalY, BridgeFight.fleeGoalZ = nil, nil, nil
                BridgeFight.fleePathAt, BridgeFight.fleePathX, BridgeFight.fleePathY = nil, nil, nil
                BridgeFight.target = nil
                BridgeFight.state = "idle"
                BridgeFight.swingBack = false
                BridgeFight.swingBackFlank = false
                BridgeFight.info = "flee"
                pcall(function() body:setVariable(HIT_VAR, false) end)
                pcall(function() body:changeState(ZombieIdleState.instance()) end)
                pcall(function() body:setAnimatingBackwards(false) end)
                pcall(function() BridgeCallout.breakOff() end)
                vlog(string.format("flee start sectors=%d opp=%d pressN=%d g2=%d dist=%.1f gun=%s ring=%.1f",
                    sectors, gunMode and (S.oppositeGun or 0) or (S.opposite or 0), S.pressN or 0, S.g2 or 0,
                    dist(body, red), tostring(gunMode), ring))
                return true
            end
        end
    end

    if BridgeAim ~= nil then
        BridgeAim.refresh(red)
        if BridgeAim.zone.on
            and (Bridge.mode ~= "follow"
                 or BridgeAim.inCone(body:getX(), body:getY(), body:getZ()))
            and BridgeAim.step(body, red) then
            return true
        end
    end
    local swinging = BridgeFight.state == "swing"
    if not swinging and BridgeGunfight ~= nil and BridgeGunfight.isAssigned ~= nil and BridgeGunfight.isAssigned(body) then
        local ok, busy = pcall(function() return BridgeGunfight.update(body, S) end)
        if not ok then
            BridgeFight.info = "gun error: " .. tostring(busy)
            Bridge.logError("gun", busy)
            return false
        end
        if busy == true then
            BridgeFight.state = "gun"
            return true
        end
        if BridgeGunfight.canMelee ~= true and BridgeFight.state ~= "swing" then
            BridgeFight.state = "idle"
            return false
        end
        if BridgeFight.state == "gun" then BridgeFight.state = "idle" end
    end
    watchCrawlers(body, red)

    if mode.passive then
        BridgeFight.target = nil
        BridgeFight.state = "idle"
        rest(false)
        return false
    end





    if BridgeFight.target == nil and BridgeFight.state ~= "swing" then rest(false) end


    if not BridgeFight.guardOnly and not BridgeFight.flee
            and dist(body, red) > mode.leash and BridgeFight.state ~= "swing" then
        if BridgeFight.target ~= nil then
            BridgeFight.info = "gave up: player far"
            pcall(function() BridgeCallout.breakOff() end)
        end
        BridgeFight.target = nil
        BridgeFight.state = "idle"
        escapeReset()
        return false
    end

    if BridgeFight.state == "swing" then
        BridgeWeapon.lastFight = Bridge.time
        local t = BridgeFight.target
        if t ~= nil then pcall(function() body:faceLocationF(t:getX(), t:getY()) end) end
        if BridgeFight.swingBack then swingDrift(body, red, t, mode) end
        local age = Bridge.time - BridgeFight.swingStart
        local swingLen = BridgeFight.swingLen or SWING_LEN
        local attackAt = BridgeFight.attackAt or ATTACK_TIME



        local mark = false
        pcall(function() mark = body:getVariableBoolean(HIT_VAR) end)


        if not BridgeFight.hit and not mark and age >= attackAt then
            local playing = false
            pcall(function() playing = body:getActionStateName() == "bumped" and tostring(body:getBumpType()) == BridgeFight.anim end)
            if not playing then
                local st = "?"
                pcall(function() st = tostring(body:getActionStateName()) .. "/" .. tostring(body:getBumpType()) end)
                vlog("swing without animation (" .. st .. "), swinging again")
                if BridgeFight.kind == "shove" then

                    BridgeFight.shoveStreak = (BridgeFight.shoveStreak or 0) + 1
                    BridgeFight.shoveReadyAt = Bridge.time + SHOVE_COOLDOWN
                end
                BridgeFight.state = "idle"
                return true
            end
        end
        if not BridgeFight.hit and (mark or age >= attackAt) then
            BridgeFight.hit = true
            pcall(function() body:setVariable(HIT_VAR, false) end)
            vlog(string.format("hit moment: %s at %.2f s of the swing", mark and "animation mark" or "time (no mark)", age / 60))
            if BridgeFight.kind == "shove" then
                pcall(function() BridgeFight.shoveResolve(body, t) end)
            elseif validTarget(t, body, red, mode) then
                local w = weapon(body)
                local ok, res = pcall(function() return hitTarget(body, w, t) end)
                BridgeFight.info = ok and ("swing " .. tostring(res)) or ("hit error: " .. tostring(res))
                if not ok or res ~= "hit" then
                    local st, crawl = "?", false
                    pcall(function() st = tostring(t:getActionStateName()) crawl = t:isCrawling() end)
                    vlog("swing " .. BridgeFight.info .. " target state=" .. st .. " crawling=" .. tostring(crawl))
                else
                    pcall(function() BridgeFight.multiHit(body, w, t) end)

                    pcall(function()
                        local cat = BridgeSkills.categoryFor(w)
                        if cat ~= nil then
                            BridgeSkills.add(cat, math.min((BridgeFight.lastRawDmg or 0) * 0.9, 3), "swing")
                        end
                    end)




                    pcall(function()
                        if BridgeSkills ~= nil and BridgeSkills.rollMaintenance ~= nil then
                            local mxp = BridgeSkills.rollMaintenance(w)
                            if mxp > 0 then BridgeSkills.add("Maintenance", mxp, "hit") end
                        end
                    end)


                    pcall(function()
                        local endur, warn = 1.0, 0.5
                        pcall(function() endur = body:getStats():get(CharacterStat.ENDURANCE) end)
                        pcall(function() warn = body:getStats():getEnduranceWarning() end)
                        if endur > warn then BridgeSkills.add("Fitness", 1, "swing") end
                    end)
                end
            else
                vlog("swing lost target before the hit")
            end
        end

        if BridgeFight.hit and not BridgeFight.guardOnly and not BridgeFight.flee
                and dist(body, red) > mode.leash then
            BridgeFight.target = nil
            BridgeFight.state = "idle"
            BridgeFight.info = "gave up mid-swing: player far"
            pcall(function() BridgeCallout.breakOff() end)
            return false
        end
        if age >= swingLen then
            BridgeFight.gunShoveSwing = false
            if Bridge.verbose then
                local sx = BridgeFight.swingStartX or body:getX()
                local sy = BridgeFight.swingStartY or body:getY()
                local mx, my = body:getX() - sx, body:getY() - sy
                vlog(string.format("swing end %s dx=%.2f dy=%.2f dist=%.2f drift=%d bump=%s hit=%s",
                    tostring(BridgeFight.anim), mx, my, math.sqrt(mx * mx + my * my),
                    BridgeFight.swingDriftApplied or 0, tostring(body:getBumpType()), tostring(BridgeFight.hit)))
            end
            BridgeFight.state = "idle"
        end
        return true
    end



    if BridgeFight.target ~= nil and (Bridge.time - BridgeFight.lastPick) >= PICK_EVERY
        and validTarget(BridgeFight.target, body, red, mode) then
        BridgeFight.lastPick = Bridge.time
        local okP, z = pcall(function() return pickTarget(body, red, mode) end)
        local cur = BridgeFight.target
        if okP and z ~= nil and z ~= cur
            and BridgeFight.threat(z, body, red, mode) + 1.0 < BridgeFight.threat(cur, body, red, mode) then
            vlog(string.format("target switched: threat %.1f -> %.1f (dred %.1f -> %.1f)", BridgeFight.threat(cur, body, red, mode),
                BridgeFight.threat(z, body, red, mode), dist(cur, red), dist(z, red)))
            BridgeFight.target = z
            BridgeFight.state = "idle"
        end
    end
    local picked = false
    if not validTarget(BridgeFight.target, body, red, mode) then
        BridgeFight.target = nil




        BridgeFight.state = "idle"
        if (Bridge.time - BridgeFight.lastPick) < PICK_EVERY then return false end
        BridgeFight.lastPick = Bridge.time
        local ok, z = pcall(function() return pickTarget(body, red, mode) end)
        if not ok then BridgeFight.info = "pick error: " .. tostring(z); return false end
        BridgeFight.target = z
        if z == nil then
            if BridgeFight.escapeOn then escapeReset() end
            return false
        end
        BridgeFight.info = "target picked"
        picked = true




        pcall(function()
            local foreign = BridgeData.foreign(z)
            local banditNpc, banditHostile = BridgeData.bandit(z)
            local line = string.format("target picked: hp=%.2f d=%.1f dred=%.1f state=%s foreign=%s hostile=%s",
                z:getHealth(), dist(z, body), dist(z, red), tostring(z:getActionStateName()), tostring(foreign),
                banditNpc and ("bandit " .. tostring(banditHostile)) or tostring(foreign and BridgeData.alifeHostile(z) or "-"))
            if foreign then log(line) else vlog(line) end
        end)
    end

    local t = BridgeFight.target

    pcall(function() BridgeWeapon.fight(body) end)

    local drawing = false
    pcall(function() drawing = BridgeWeapon.busy() end)
    if drawing then
        pcall(function() body:faceLocationF(t:getX(), t:getY()) end)
        BridgeFight.info = "drawing weapon"
        return true
    end
    local item = weapon(body)
    local range = item:getMaxRange()
    local d = dist(body, t)

    if escapeTick(body, red, t, mode, range, S) then return true end

    if BridgeFight.state == "step" then
        if footTick(body, red, t, mode, range) then return true end
    end

    if BridgeFight.escapeOn then
        local near = nearestInReach(body, red, range, S)
        if near ~= nil then
            if near ~= t then
                BridgeFight.target = near
                t = near
                BridgeFight.info = "escape target"
                vlog(string.format("escape swing target d=%.2f", dist(body, near)))
            end
            d = dist(body, t)
        end
    end

    if d > mode.approach then
        if BridgeFight.escapeOn and Bridge.verbose then
            vlog(string.format("escape far: d=%.2f range=%.2f -> drop target", d, range or -1))
        end
        BridgeFight.target = nil
        BridgeFight.state = "idle"
        BridgeFight.info = "target too far, waiting"
        return false
    end

    if picked then pcall(function() BridgeCallout.engage(t) end) end

    local escS = BridgeFight.escapeScan
    local escapeNeedClose = BridgeFight.escapeOn and d > range - 0.15
    local walled = d <= range + 0.1 and wallBetween(body, t)
    if d > range + 0.1 or walled or escapeNeedClose then
        if BridgeFight.escapeOn and Bridge.verbose and (Bridge.time % 10) == 6 then
            vlog(string.format("escape approach: d=%.2f range=%.2f walled=%s needClose=%s nearN=%d state=%s",
                d, range or -1, tostring(walled), tostring(escapeNeedClose),
                escS and (escS.nearN or 0) or -1, tostring(BridgeFight.state)))
        end
        if walled then BridgeFight.info = "target behind wall" end
        if BridgeFight.state ~= "approach" then
            BridgeFight.state = "approach"
            BridgeFight.approachStart = Bridge.time
            BridgeFight.approachX, BridgeFight.approachY = body:getX(), body:getY()
            BridgeFight.approachStuck = 0
        elseif (Bridge.time - BridgeFight.approachStart) > APPROACH_MAX then


            BridgeFight.blacklist[t] = { untilT = Bridge.time + BLACKLIST_TICKS, x = t:getX(), y = t:getY(),
                                         st = tostring(t:getActionStateName()) }
            BridgeFight.info = "approach timeout, blacklisted"
            log(string.format("approach timeout: d=%.2f st=%s bump=%s path=%s", d,
                tostring(t:getActionStateName()), tostring(body:getBumpType()), BridgeMove.pathResult))
            BridgeFight.target = nil
            BridgeFight.state = "idle"
            escapeReset()
            BridgeMove.stopPath(body)
            return false
        end
        local adx = body:getX() - (BridgeFight.approachX or body:getX())
        local ady = body:getY() - (BridgeFight.approachY or body:getY())
        if math.sqrt(adx * adx + ady * ady) < STUCK_MOVE then
            BridgeFight.approachStuck = (BridgeFight.approachStuck or 0) + 1
        else
            BridgeFight.approachStuck = 0
            BridgeFight.approachX, BridgeFight.approachY = body:getX(), body:getY()
        end
        if (BridgeFight.approachStuck or 0) >= STUCK_TICKS then
            BridgeFight.blacklist[t] = { untilT = Bridge.time + BLACKLIST_TICKS, x = t:getX(), y = t:getY(),
                                         st = tostring(t:getActionStateName()) }
            BridgeFight.info = "stuck approaching, blacklisted"
            log(string.format("approach stuck: d=%.2f st=%s bump=%s path=%s", d,
                tostring(t:getActionStateName()), tostring(body:getBumpType()), BridgeMove.pathResult))
            BridgeFight.target = nil
            BridgeFight.state = "idle"
            escapeReset()
            BridgeMove.stopPath(body)
            return false
        end
        BridgeFight.targetInfo = string.format("d=%.1f hp=%.2f st=%s", d, t:getHealth(), tostring(t:getActionStateName()))
        BridgeMove.walkType = (d > 3) and "Run" or "Walk"




        pcall(function() BridgeMove.endFollowBump(body, "") end)
        pcall(function() BridgeMove.setCollide(body, true) end)

        tryVault(body, t)

        pcall(function() BridgeMove.goToward(body, t:getX(), t:getY(), t:getZ(), true) end)
        return true
    end


    BridgeMove.stopPath(body)

    if not BridgeFight.escapeOn then
        if footTick(body, red, t, mode, range) then return true end
    end

    if wantShove(body, t, item) then
        local dShove = dist(body, t)
        local escS = BridgeFight.escapeScan
        local flankNoPress = BridgeFight.escapeOn and escS ~= nil and (escS.nearN or 0) == 0
        if not flankNoPress or dShove <= SHOVE_RANGE - 0.25 then
            return startShove(body, t)
        end
        if Bridge.verbose and (Bridge.time % 10) == 7 then
            vlog(string.format("shove hold flank: d=%.2f limit=%.2f nearN=%d pressN=%d",
                dShove, SHOVE_RANGE - 0.25, escS and (escS.nearN or 0) or -1,
                escS and (escS.pressN or 0) or -1))
        end
    end


    pcall(function()
        local st = body:getActionStateName()
        if st ~= "bumped" and st ~= "idle" then
            vlog("swing from state " .. tostring(st) .. ": to idle first")
            body:changeState(ZombieIdleState.instance())
        end
    end)
    pcall(function() body:faceLocationF(t:getX(), t:getY()) end)
    local crit, critChance, critMult = critRoll(item)
    BridgeFight.swingCrit, BridgeFight.swingCritChance, BridgeFight.swingCritMult = crit, critChance, critMult
    local prone = isProne(t)
    BridgeFight.floorSwing = prone == true
    local anims, swingSound = attackAnims(item, prone, crit)
    local anim = anims[1 + ZombRand(#anims)]





    local cur = nil
    pcall(function() if tostring(body:getActionStateName()) == "bumped" then cur = tostring(body:getBumpType()) end end)
    local curBase = cur
    if curBase ~= nil and string.sub(curBase, -3) == "Bwd" then curBase = string.sub(curBase, 1, #curBase - 3) end
    if curBase ~= nil and string.sub(curBase, 1, 3) == "NA_" then curBase = string.sub(curBase, 4) end
    if curBase ~= nil and (curBase == anim or curBase == anim .. "B") then
        if #anims > 1 then
            local others = {}
            for _, a in ipairs(anims) do if a ~= curBase then others[#others + 1] = a end end
            anim = others[1 + ZombRand(#others)]
        elseif SECOND_NODE[anim] and curBase == anim then
            anim = anim .. "B"
        end
    end
    if not prone and BridgeFight.swingBack and BridgeFight.escapeOn and BridgeFight.FOOT_SWING_BACK == true then
        local back = backAttackNode(anim)
        if back ~= nil then anim = back end
    end
    pcall(function() if swingSound then body:playSound(swingSound) end end)
    pcall(function() BridgeSound.voice(body, "MeleeAttack", 40) end)
    pcall(function() body:setVariable(HIT_VAR, false) end)




    pcall(function() body:setVariable("BumpAnimFinished", false) end)
    body:setBumpType(anim)


    if Bridge.mp then pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "look", { a = anim }) end) end
    BridgeFight.anim = anim
    BridgeFight.kind = "hit"
    BridgeFight.state = "swing"
    BridgeFight.swingStart = Bridge.time
    BridgeFight.swingLen, BridgeFight.attackAt = swingFrames(item)
    BridgeFight.hit = false
    BridgeFight.swingStartX, BridgeFight.swingStartY = body:getX(), body:getY()
    BridgeFight.swingDriftApplied = 0
    BridgeFight.info = "swing " .. anim .. " " .. tostring(BridgeFight.swingLen) .. "f"

    vlog(string.format("swing start %s kind=%s back=%s escapeOn=%s gap=%.2f len=%d since=%.2fs range=%.2f dt=%.3f",
        tostring(anim), tostring(BridgeFight.kind), tostring(BridgeFight.swingBack), tostring(BridgeFight.escapeOn), dist(body, t),
        BridgeFight.swingLen, BridgeFight.lastSwingAt and (Bridge.time - BridgeFight.lastSwingAt) / 60 or -1,
        range or -1, Bridge.dt or 1))
    BridgeFight.lastSwingAt = Bridge.time
    return true
end










function BridgeFight.staleEnd(body)
    if body == nil or body ~= Bridge.body or BridgeFight.state ~= "swing" or BridgeFight.hit then return false end
    if Bridge.time - (BridgeFight.swingStart or 0) > STALE_END_MAX then return false end
    local fin, st, bump = false, "?", ""
    pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
    if not fin then return false end
    pcall(function() st = tostring(body:getActionStateName()) bump = tostring(body:getBumpType()) end)
    if st ~= "bumped" or bump ~= BridgeFight.anim then return false end
    local ok = pcall(function() body:setVariable("BumpAnimFinished", false) end)
    if ok then
        vlog(string.format("old clip end during the swing ignored: %s at %.2f s", tostring(bump),
            (Bridge.time - (BridgeFight.swingStart or 0)) / 60))
    end
    return ok
end

Events.OnTickEvenPaused.Add(function() pcall(BridgeFight.staleEnd, Bridge ~= nil and Bridge.body or nil) end)

if type(Events) == "table" and Events.OnSave ~= nil then
    Events.OnSave.Add(function()
        if Bridge ~= nil and Bridge.alive() then pcall(function() BridgeFight.persistStamina(Bridge.store) end) end
    end)
end

log("loaded")
