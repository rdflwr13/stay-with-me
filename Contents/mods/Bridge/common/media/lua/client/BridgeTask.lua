BridgeTask = BridgeTask or {}

BridgeTask.ENABLED = 1
BridgeTask.TREECUTTING_ENABLED = 1
BridgeTask.CLEANING_ENABLED = 1
BridgeTask.CLEARING_ENABLED = 1
BridgeTask.LOOTING_ENABLED = 1
BridgeTask.SIT_ENABLED = 1
BridgeTask.LAY_ENABLED = 1
BridgeTask.MOVE_CORPSES_ENABLED = 1



local SECOND = 60
local MINUTE = 60 * SECOND

local function ffMult()
    local m = 1
    pcall(function() m = getGameTime():getTrueMultiplier() end)
    if type(m) ~= "number" or m < 1 then m = 1 end
    if m > 10 then m = 10 end
    return m
end

BridgeTask.CHOP_RANGE = 1.45
BridgeTask.STOP_DIST = 0.9
BridgeTask.SPOT_NUDGE = 0.42
BridgeTask.STALL_TICKS = 1.5 * SECOND
BridgeTask.DANGER_RADIUS = 6
BridgeTask.MIN_SWING = 0.2 * SECOND
BridgeTask.SWING_MAX = 200
BridgeTask.ATTACK_AT = 0.5 * SECOND
BridgeTask.CHOP_TIMEOUT = 30 * SECOND
BridgeTask.WALK_TIMEOUT = 20 * SECOND




BridgeTask.WALK_NO_PROGRESS = 5 * SECOND
BridgeTask.PATH_FAIL_LIMIT = 2


BridgeTask.SIT_RANGE = 0.35
BridgeTask.SIT_TIMEOUT = 20 * SECOND
BridgeTask.SIT_SETTLE = 0.30
BridgeTask.SIT_ANIM_MAX = 240


BridgeTask.ABORT_AFTER_FAILS = 3
BridgeTask.CHOP_ANIM = "NA_Chop"
BridgeTask.CHOP_ANIM_B = "NA_ChopB"




BridgeTask.CHOP_REST_AT = 0.90
BridgeTask.CHOP_REFUSE_STAMINA = 0.40
BridgeTask.CHOP_RESUME_STAMINA = 0.80
BridgeTask.CHOP_REST_SIT_DELAY = 2 * SECOND
BridgeTask.CHOP_RESUME_DELAY = 2 * SECOND
BridgeTask.CHOP_REST_SAY_RANGE = 20
BridgeTask.CHOP_REST_SAY_COOLDOWN = 30 * SECOND

BridgeTask.CLEAN_RANGE = 1.45




BridgeTask.SCRUB_FLOOR_SPONGE = "NA_ScrubFloorSponge"
BridgeTask.SCRUB_FLOOR_BROOM = "NA_ScrubFloorBroom"
BridgeTask.SCRUB_FLOOR_BRUSH = "NA_ScrubFloorBrush"
BridgeTask.SCRUB_WALL_SPONGE = "NA_ScrubWallSponge"
BridgeTask.SCRUB_WALL_BROOM = "NA_ScrubWallBroom"
BridgeTask.SCRUB_WALL_BRUSH = "NA_ScrubWallBrush"
BridgeTask.SCRUB_FLOOR_BY_TOOL = {
    Sponge = "NA_ScrubFloorSponge", Broom = "NA_ScrubFloorBroom", Brush = "NA_ScrubFloorBrush",
}
BridgeTask.SCRUB_WALL_BY_TOOL = {
    Sponge = "NA_ScrubWallSponge", Broom = "NA_ScrubWallBroom", Brush = "NA_ScrubWallBrush",
}


BridgeTask.RAKE_ANIM = "NA_Rake"

BridgeTask.DIG_FLOOR = "NA_DigShovel"
BridgeTask.DIG_ANIMS = {
    DigShovel = "NA_DigShovel", DigTrowel = "NA_DigTrowel",
    DigHoe = "NA_DigHoe", DigPickAxe = "NA_DigPickAxe", Dig = "NA_DigShovel",
}



BridgeTask.VINE_TIME = 100
BridgeTask.VINE_ANIMS = {
    Axe = "NA_RemoveBushAxe", LongBlade = "NA_RemoveBushLongBlade",
    Knife = "NA_RemoveBushKnife", Default = "NA_RemoveBush",
}


BridgeTask.CLEAR_RANGE = 1.45
BridgeTask.GRASS_TIME = 50
BridgeTask.BUSH_TIME = 100
BridgeTask.CLEAR_TIMEOUT = MINUTE
BridgeTask.CLEAR_SAY_COOLDOWN = 25 * SECOND
BridgeTask.GRASS_ANIM = "NA_RemoveGrass"
BridgeTask.GRASS_ENDURANCE = 0.006
BridgeTask.SCRUB_TIME = 2.5 * SECOND
BridgeTask.SCRUB_GUARD = 0.5 * SECOND
BridgeTask.SCRUB_TIMEOUT = MINUTE
BridgeTask.CLEAN_FLUID_PER_SQUARE = 0.025
BridgeTask.CLEAN_SAY_COOLDOWN = 25 * SECOND
BridgeTask.CHOP_SAY_COOLDOWN = 25 * SECOND


BridgeTask.CORPSE_RANGE = 1.45
BridgeTask.CORPSE_PICKUP_MS = 90
BridgeTask.CORPSE_DROP_MS = 90

BridgeTask.CORPSE_HAUL_WALK = "SlowWalk"
BridgeTask.CORPSE_TIMEOUT = 30 * SECOND
BridgeTask.CORPSE_SAY_COOLDOWN = 30 * SECOND
BridgeTask.CORPSE_DROP_SEARCH = 3
BridgeTask.CORPSE_STAMINA_PER = 0.02
BridgeTask.CORPSE_STAMINA_PER_TILE = 0.002
BridgeTask.CORPSE_REFUSE_STAMINA = 0.40
BridgeTask.CORPSE_REST_AT = 0.90
BridgeTask.CORPSE_RESUME_STAMINA = 0.80
BridgeTask.CORPSE_REST_SIT_DELAY = 2 * SECOND
BridgeTask.CORPSE_RESUME_DELAY = 2 * SECOND
BridgeTask.CORPSE_REST_SAY_RANGE = 20
BridgeTask.CORPSE_REST_SAY_COOLDOWN = 30 * SECOND
BridgeTask.CORPSE_XP_STRENGTH = 2
BridgeTask.CORPSE_XP_FITNESS = 1


BridgeTask.PRY_ENABLED = 1
BridgeTask.PRY_ANIM = "NA_Pry"
BridgeTask.PRY_RANGE = 0.85
BridgeTask.PRY_TIME = 190
BridgeTask.PRY_DANGER_RADIUS = 2
BridgeTask.PRY_NOISE_RADIUS = 15
BridgeTask.PRY_NOISE_EVERY = 30
BridgeTask.PRY_STAMINA = 0.12
BridgeTask.PRY_STAMINA_MIN = 0.30
BridgeTask.PRY_CHANCE_FLOOR = 0.30
BridgeTask.PRY_CHANCE_K = 3
BridgeTask.PRY_SOUND_START = "CrowbarHit"
BridgeTask.PRY_SOUND_SUCCESS = "BreakBarricadePlank"
BridgeTask.PRY_SOUND_FAIL = "CrowbarBreak"


BridgeTask.CLEAN_SOUND = "CleanBloodScrub"
BridgeTask.CLEAN_SOUND_HAND = "CleanBloodBleach"
BridgeTask.ASH_SOUND = "Shoveling"
BridgeTask.WASH_REACH = 1
BridgeTask.WASH_GREET_TICKS = 90
BridgeTask.WASH_SOUND = "WashYourself"
BridgeTask.WASH_SOUND_EVERY = 120
BridgeTask.WASH_PASSES = 12


BridgeTask.FILL_REACH = BridgeTask.WASH_REACH
BridgeTask.BATH_REACH = 1.5
BridgeTask.FILL_ANIM = "fillBottle"
BridgeTask.FILL_UNIT_TICKS = 100
BridgeTask.FILL_BASE_TICKS = 30
BridgeTask.FILL_SOUND_EVERY = 120
BridgeTask.FILL_MIN_TICKS = 60


BridgeTask.EMPTY_ANIM = "pourFluid"
BridgeTask.EMPTY_UNIT_TICKS = 100
BridgeTask.EMPTY_BASE_TICKS = 30
BridgeTask.EMPTY_MIN_TICKS = 60


BridgeTask.LOOT_LOW = "LootLow"
BridgeTask.LOOT_MID = "LootMid"
BridgeTask.ASH_PREFIX = "floors_burnt"
BridgeTask.GLASS_PREFIX = "brokenglass"
BridgeTask.GLASS_ITEM = "Base.BrokenGlass"


BridgeTask.LOOT_RANGE = 1.45
BridgeTask.LOOT_TIMEOUT = 30 * SECOND
BridgeTask.LOOT_TRANSFER_WAIT = 20 * SECOND
BridgeTask.LOOT_ITEM_TIME = 0.5 * SECOND
BridgeTask.LOOT_SAY_COOLDOWN = 25 * SECOND
BridgeTask.LOOT_SCAN_BUDGET = 200
BridgeTask.LOOT_BATCH_MAX = 20
BridgeTask.OPENING_GIVE_UP = 6 * SECOND



BridgeTask.DIRT_PREFIXES = { "overlay_grime", "trash&junk", "trash_", "d_floorleaves", "d_trash", "LS_Scraps" }

BridgeTask.active = false
BridgeTask.state = "idle"
BridgeTask.kind = nil


function BridgeTask.idleChatBlocked()
    if not BridgeTask.active then return false end
    local k = BridgeTask.kind
    if k == "sit" then return false end
    if k == "lay" then return BridgeTask.laySleep == true end
    return true
end
BridgeTask.kinds = {}
BridgeTask.body = nil
BridgeTask.queue = {}
BridgeTask.current = nil
BridgeTask.prevMode = "follow"
BridgeTask.phase = nil
BridgeTask.nextSwing = 0
BridgeTask.since = 0
BridgeTask.swings = 0
BridgeTask.info = "none"
BridgeTask.cleanApplied = {}
BridgeTask.cleanSpend = nil
BridgeTask.cleanSoundHandle = nil
BridgeTask.subHands = nil
BridgeTask.cleanHandsKey = nil
BridgeTask.cleanStowPending = false
BridgeTask.cleanDrawPending = false
BridgeTask.tools = {}
BridgeTask.toolsAt = {}
BridgeTask.cleanGearCache = {}
BridgeTask.cleanGearAt = {}
BridgeTask.cleanKindCache = nil
BridgeTask.cleanClassKey = nil
BridgeTask.cleanClassAt = nil
BridgeTask.cleanWallCache = nil
BridgeTask.plantKindCache = nil
BridgeTask.plantKindKey = nil
BridgeTask.plantKindAt = nil
BridgeTask.danger = nil
BridgeTask.dangerAt = nil
BridgeTask.washSink = nil
BridgeTask.washPhase = nil
BridgeTask.washSince = 0
BridgeTask.washTicks = nil
BridgeTask.washScope = nil
BridgeTask.fillSink = nil
BridgeTask.fillPhase = nil
BridgeTask.fillSince = 0
BridgeTask.fillItems = nil
BridgeTask.fillItem = nil
BridgeTask.fillIndex = nil
BridgeTask.fillTicks = nil
BridgeTask.fillAmount = nil
BridgeTask.fillTainted = false
BridgeTask.fillSoundAt = nil
BridgeTask.fillSoundHandle = nil
BridgeTask.fillSoundEmitter = nil
BridgeTask.fillPourType = nil
BridgeTask.emptyItems = nil
BridgeTask.emptyItem = nil
BridgeTask.emptyIndex = nil
BridgeTask.emptyTicks = nil
BridgeTask.emptySince = 0
BridgeTask.emptySound = nil
BridgeTask.emptyEmitter = nil
BridgeTask.emptyPourType = nil
BridgeTask.clearNeedCut = nil
BridgeTask.chopRest = false
BridgeTask.chopRestSitAt = nil
BridgeTask.chopResumeAt = nil
BridgeTask.savedPrimary = nil
BridgeTask.savedSecondary = nil
BridgeTask.lootList = nil
BridgeTask.lootIdx = nil
BridgeTask.lootPending = nil
BridgeTask.lootPendingAt = nil
BridgeTask.lootAct = nil
BridgeTask.lootSrc = nil
BridgeTask.lootSettled = false
BridgeTask.lootNextAt = nil
BridgeTask.lootFullSaid = false
BridgeTask.lootTook = 0
BridgeTask.lootNoRoom = 0
BridgeTask.lootFull = false
BridgeTask.exercisePhase = nil
BridgeTask.exerciseRepAt = nil
BridgeTask.exerciseRepMark = nil
BridgeTask.exerciseBudget = nil
BridgeTask.exerciseMirror = nil
BridgeTask.exerciseStopReason = nil


BridgeTask.corpseDest = nil
BridgeTask.carryCorpse = nil
BridgeTask.carrySource = nil
BridgeTask.corpsePhase = nil
BridgeTask.corpseStart = nil
BridgeTask.corpseRest = false
BridgeTask.corpseRestSitAt = nil
BridgeTask.corpseResumeAt = nil
BridgeTask.corpseDropSq = nil
BridgeTask.corpseFailSaid = false
BridgeTask.corpseCarried = 0

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeTask] " .. tostring(text)) end end
local function warn(text) print("[BridgeTask] " .. tostring(text)) end

function BridgeTask.clearCorpseState()
    BridgeTask.corpseDest = nil
    BridgeTask.carryCorpse = nil
    BridgeTask.carrySource = nil
    BridgeTask.corpsePhase = nil
    BridgeTask.corpseStart = nil
    BridgeTask.corpseRest = false
    BridgeTask.corpseRestSitAt = nil
    BridgeTask.corpseResumeAt = nil
    BridgeTask.corpseDropSq = nil
    BridgeTask.corpseFailSaid = false
    BridgeTask.corpseCarried = 0
end




function BridgeTask.noteCleanSpend(item)
    if item == nil then return end
    if type(BridgeTask.cleanSpend) ~= "table" then BridgeTask.cleanSpend = {} end
    for _, it in ipairs(BridgeTask.cleanSpend) do
        if it == item then return end
    end
    BridgeTask.cleanSpend[#BridgeTask.cleanSpend + 1] = item
end

function BridgeTask.chargeCleanSpend()
    local list = BridgeTask.cleanSpend
    BridgeTask.cleanSpend = nil
    if type(list) ~= "table" or #list == 0 then return end
    for _, item in ipairs(list) do
        pcall(function()
            local c = item:getFluidContainer()
            if c ~= nil then
                c:adjustAmount(c:getAmount() - (BridgeTask.CLEAN_FLUID_PER_SQUARE or 0.025))
                item:syncItemFields()
            end
        end)
    end

    if Bridge ~= nil and Bridge.itemsSpentAt == nil then Bridge.itemsSpentAt = Bridge.time or 0 end
end



local function restoreForcedWalk()
    if BridgeTask.forcedWalkSaved and BridgeMove ~= nil then
        BridgeMove.forcedWalk = BridgeTask.prevForcedWalk
    end
    BridgeTask.forcedWalkSaved = false
end

local function dist2(a, b)
    local dx, dy = a:getX() - b:getX(), a:getY() - b:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function usableAxe(item)
    local ok = false
    pcall(function()
        ok = item ~= nil and not item:isBroken()
            and ItemTag ~= nil and ItemTag.CHOP_TREE ~= nil and item:hasTag(ItemTag.CHOP_TREE)
    end)
    return ok
end

function BridgeTask.findAxe(body)
    if body == nil then return nil end
    local axe = nil
    pcall(function()
        local hand = body:getPrimaryHandItem()
        if usableAxe(hand) then axe = hand return end
        local best, bestScore = nil, -1
        local items = body:getInventory():getAllEvalRecurse(usableAxe)
        if items ~= nil then
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                local score = 0
                pcall(function() score = it:getTreeDamage() end)
                if score > bestScore then best, bestScore = it, score end
            end
        end
        axe = best
    end)
    return axe
end

local function usableCrowbar(item)
    local ok = false
    pcall(function()
        if item == nil or item:isBroken() then return end
        if ItemTag ~= nil and ItemTag.CROWBAR ~= nil then
            ok = item:hasTag(ItemTag.CROWBAR) == true
            return
        end
        local type = tostring(item:getType() or "")
        local full = tostring(item:getFullType() or "")
        ok = string.find(type, "Crowbar", 1, true) ~= nil
            or string.find(full, "Crowbar", 1, true) ~= nil
    end)
    return ok
end

function BridgeTask.findCrowbar(body)
    if body == nil then return nil end
    local crowbar = nil
    pcall(function()
        local hand = body:getPrimaryHandItem()
        if usableCrowbar(hand) then crowbar = hand return end
        local items = body:getInventory():getAllEvalRecurse(usableCrowbar)
        if items ~= nil and items:size() > 0 then crowbar = items:get(0) end
    end)
    return crowbar
end

function BridgeTask.resolvePryDoor(target)
    local door = nil
    if target == nil then return nil end
    pcall(function()
        local sq = getCell():getGridSquare(target.x, target.y, target.z)
        if sq == nil then return end
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            if o ~= nil then
                local isDoor = false
                pcall(function()
                    isDoor = instanceof(o, "IsoDoor")
                        or (instanceof(o, "IsoThumpable") and o:isDoor())
                end)
                if isDoor then
                    local closed, locked, bar = false, false, false
                    pcall(function() closed = not o:IsOpen() end)
                    pcall(function() locked = o:isLocked() or o:isLockedByKey() end)
                    pcall(function() bar = o:isBarricaded() end)
                    if closed and locked and not bar then door = o return end
                end
            end
        end
    end)
    return door
end

local function resolveTree(target)
    local tree = nil
    pcall(function()
        local sq = getCell():getGridSquare(target.x, target.y, target.z)
        if sq ~= nil then
            local t = sq:getTree()
            if t ~= nil and t:getObjectIndex() >= 0 then tree = t end
        end
    end)
    return tree
end
BridgeTask.resolveTree = resolveTree






local function itemType(item)
    local t = nil
    pcall(function() t = item:getType() end)
    return type(t) == "string" and t or nil
end

local function isBroom(item)
    local t = itemType(item)
    if t == nil then return false end
    return t == "Broom" or t == "Broom_Twig" or t == "Broom_BarbedWire"
        or string.sub(t, 1, 5) == "Broom"
end

local function itemNotBroken(item)
    local ok = false
    pcall(function() ok = item ~= nil and not item:isBroken() end)
    return ok
end

local function itemHasTag(item, tag)
    local ok = false
    pcall(function() ok = item ~= nil and tag ~= nil and item:hasTag(tag) end)
    return ok
end




local STAIN_TYPES = { Broom = true, Broom_Twig = true, Mop = true, Sponge = true,
                      BathTowel = true, DishCloth = true, GrillBrush = true, ToiletBrush = true }
local function cleanStainItem(item)
    if not itemNotBroken(item) then return false end
    if itemHasTag(item, ItemTag ~= nil and ItemTag.CLEAN_STAINS or nil) then return true end
    return STAIN_TYPES[itemType(item) or ""] == true
end






local ASH_TYPES = {
    Broom = true, Broom_Twig = true,
    Shovel = true, Shovel2 = true, SpadeForged = true, SpadeWood = true,
    SnowShovel = true, HandShovel = true, EntrenchingTool = true,
}
local function ashToolItem(item)
    if not itemNotBroken(item) then return false end
    if itemHasTag(item, ItemTag ~= nil and ItemTag.CLEAR_ASHES or nil) then return true end
    return ASH_TYPES[itemType(item) or ""] == true
end

local function findImplement(body, predicate)
    if body == nil then return nil end
    local found = nil
    pcall(function()
        local hand = body:getPrimaryHandItem()
        if predicate(hand) then found = hand return end
        local items = body:getInventory():getAllEvalRecurse(predicate)
        if items ~= nil and items:size() > 0 then found = items:get(0) end
    end)
    return found
end



local function stainRank(item)
    local t = itemType(item)
    if t == nil then return 1 end
    if t == "Mop" or string.sub(t, 1, 3) == "Mop" then return 3 end
    if t == "Broom" or string.sub(t, 1, 5) == "Broom" then return 2 end
    return 1
end


function BridgeTask.findCleanStainItem(body)
    if body == nil then return nil end
    local best, bestRank = nil, -1
    pcall(function()
        local hand = body:getPrimaryHandItem()
        if cleanStainItem(hand) then best, bestRank = hand, stainRank(hand) end
        local items = body:getInventory():getAllEvalRecurse(cleanStainItem)
        if items ~= nil then
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                if it ~= nil then
                    local r = stainRank(it)
                    if r > bestRank then best, bestRank = it, r end
                end
            end
        end
    end)
    return best
end



function BridgeTask.findAshTool(body)
    return findImplement(body, ashToolItem)
end




local function usableCutTool(item)
    local ok = false
    pcall(function()
        ok = item ~= nil and not item:isBroken()
            and ItemTag ~= nil and ItemTag.CUT_PLANT ~= nil and item:hasTag(ItemTag.CUT_PLANT)
    end)
    return ok
end

function BridgeTask.findCutTool(body)
    if body == nil then return nil end
    local tool = nil
    pcall(function()
        local hand = body:getPrimaryHandItem()
        if usableCutTool(hand) then tool = hand return end
        local items = body:getInventory():getAllEvalRecurse(usableCutTool)
        if items ~= nil and items:size() > 0 then tool = items:get(0) end
    end)
    return tool
end



local function vineCleanAnim(tool)
    if tool == nil then return BridgeTask.VINE_ANIMS.Default end
    local function hasCat(cat)
        local ok = false
        pcall(function()
            ok = WeaponCategory ~= nil and cat ~= nil
                and tool:getScriptItem() ~= nil
                and tool:getScriptItem():containsWeaponCategory(cat)
        end)
        return ok
    end
    local axe = WeaponCategory ~= nil and WeaponCategory.AXE or nil
    local long = WeaponCategory ~= nil and WeaponCategory.LONG_BLADE or nil
    local small = WeaponCategory ~= nil and WeaponCategory.SMALL_BLADE or nil
    if hasCat(axe) then return BridgeTask.VINE_ANIMS.Axe end
    if hasCat(long) then return BridgeTask.VINE_ANIMS.LongBlade end
    if hasCat(small) then return BridgeTask.VINE_ANIMS.Knife end
    return BridgeTask.VINE_ANIMS.Default
end
BridgeTask.vineCleanAnim = vineCleanAnim




local function vineUseEndurance(body, tool)
    if body == nil or tool == nil then return end
    pcall(function()
        local useEnd = true
        pcall(function() useEnd = tool:isUseEndurance() end)
        if not useEnd then return end
        local w, fat, charFat, endu = 1.0, 1.0, 1.0, 1.0
        pcall(function() w = tool:getWeight() end)
        pcall(function() fat = tool:getFatigueMod(body) end)
        pcall(function() charFat = body:getFatigueMod() end)
        pcall(function() endu = tool:getEnduranceMod() end)
        if type(w) ~= "number" or w <= 0 then w = 1.0 end
        if type(fat) ~= "number" or fat <= 0 then fat = 1.0 end
        if type(charFat) ~= "number" or charFat <= 0 then charFat = 1.0 end
        if type(endu) ~= "number" or endu <= 0 then endu = 1.0 end
        local use = w * fat * charFat * endu * 0.1
        use = use * 1.0 * 0.041
        local two = false
        pcall(function()
            two = tool:isTwoHandWeapon() and body:getSecondaryHandItem() ~= tool
        end)
        if two then use = use + w / 1.5 / 10 / 20 end
        if use > 0 then body:getStats():remove(CharacterStat.ENDURANCE, use) end
    end)
end
BridgeTask.vineUseEndurance = vineUseEndurance


local function isToiletBrush(item)
    return itemHasTag(item, ItemTag ~= nil and ItemTag.TOILET_BRUSH or nil)
end
BridgeTask.isToiletBrush = isToiletBrush

local function cleanerHasFluid(item)
    local ok = false
    pcall(function()
        local c = item ~= nil and item:getFluidContainer() or nil
        if c == nil then return end
        local need = BridgeTask.CLEAN_FLUID_PER_SQUARE or 0.025
        ok = (c:contains(Fluid.Bleach) and c:getAmount() >= need)
            or (c:contains(Fluid.CleaningLiquid) and c:getAmount() >= need)
    end)
    return ok
end

local function petrolHasFluid(item)
    local ok = false
    pcall(function()
        local c = item ~= nil and item:getFluidContainer() or nil
        if c == nil then return end
        local need = BridgeTask.CLEAN_FLUID_PER_SQUARE or 0.025
        ok = c:contains(Fluid.Petrol) and c:getAmount() >= need
    end)
    return ok
end

local function findFluidItem(body, predicate)
    if body == nil then return nil end
    local found = nil
    pcall(function()
        local secondary = body:getSecondaryHandItem()
        if predicate(secondary) then found = secondary return end
        local items = body:getInventory():getAllEvalRecurse(predicate)
        if items ~= nil and items:size() > 0 then found = items:get(0) end
    end)
    return found
end


function BridgeTask.findStainCleaner(body)
    return findFluidItem(body, cleanerHasFluid)
end


function BridgeTask.findPetrol(body)
    return findFluidItem(body, petrolHasFluid)
end





local function squareCleanKinds(square)
    if BridgeClean == nil then return {} end
    return BridgeClean.squareCleanKinds(square)
end

local function squareCleanKind(square)
    if BridgeClean == nil then return nil end
    return BridgeClean.squareCleanKind(square)
end

local function stainIsWall(square)
    if BridgeClean == nil then return false end
    return BridgeClean.stainIsWall(square)
end

BridgeTask.squareDirt = function(square)
    return BridgeClean ~= nil and BridgeClean.squareDirt(square) or false
end
BridgeTask.removeSquareDirt = function(square)
    if BridgeClean ~= nil then BridgeClean.removeSquareDirt(square) end
end
BridgeTask.squareCleanKinds = squareCleanKinds
BridgeTask.squareCleanKind = squareCleanKind

local function plantKind(square)
    if BridgePlants == nil then return nil end
    if BridgePlants.squareBush(square) then return "bush" end
    if BridgePlants.squareGrass(square) then return "grass" end
    return nil
end

local function twoHandedImplement(item)
    local two = false
    pcall(function() two = instanceof(item, "HandWeapon") and item:isTwoHandWeapon() end)
    return two
end
BridgeTask.isTwoHandImplement = twoHandedImplement


local function implementVariant(tool)
    if tool == nil then return "Sponge" end
    if isToiletBrush(tool) then return "Brush" end
    if twoHandedImplement(tool) then return "Broom" end
    return "Sponge"
end





local function digTypeIs(item, want)
    local v = nil
    pcall(function() v = item:getDigType() end)
    return v == want or tostring(v) == want
end
local function ashCleanAnim(tool)
    if tool == nil then return BridgeTask.LOOT_LOW end
    local t = itemType(tool)
    if isBroom(tool) then return BridgeTask.RAKE_ANIM end
    if digTypeIs(tool, "Trowel") or t == "HandShovel" or t == "EntrenchingTool" then
        return BridgeTask.DIG_ANIMS.DigTrowel
    end
    return BridgeTask.DIG_ANIMS.DigShovel
end






function BridgeTask.cleanKindTool(body, kind)
    local tool, cleaner = nil, nil
    if kind == "blood" or kind == "grime" then
        tool = BridgeTask.findCleanStainItem(body)
        cleaner = BridgeTask.findStainCleaner(body)
    elseif kind == "graffiti" then
        tool = BridgeTask.findCleanStainItem(body)
        cleaner = BridgeTask.findPetrol(body)
    elseif kind == "ashes" then
        tool = BridgeTask.findAshTool(body)
    elseif kind == "vine" then
        tool = BridgeTask.findCutTool(body)
    end
    local canDo = true
    if kind == "blood" or kind == "grime" or kind == "graffiti" then
        if tool == nil or cleaner == nil then canDo = false end
    elseif kind == "ashes" or kind == "vine" then
        if tool == nil then canDo = false end
    end
    return tool, cleaner, canDo
end



function BridgeTask.recordCleanNeeds(body, square)
    local kinds = squareCleanKinds(square)
    local canAny = false
    for i = 1, #kinds do
        local kind = kinds[i]
        local tool, cleaner, canDo = BridgeTask.cleanKindTool(body, kind)
        if canDo then
            canAny = true
        elseif kind == "blood" then
            if tool == nil then BridgeTask.needImplement = true end
            if cleaner == nil then BridgeTask.needFluid = true end
        elseif kind == "grime" then
            if tool == nil then BridgeTask.needImplement = true end
            if cleaner == nil then BridgeTask.needFluid = true end
        elseif kind == "graffiti" then
            if tool == nil then BridgeTask.needImplement = true end
            if cleaner == nil then BridgeTask.needPetrol = true end
        elseif kind == "ashes" then
            if tool == nil then BridgeTask.needAshTool = true end
        elseif kind == "vine" then
            if tool == nil then BridgeTask.needCut = true end
        end
    end
    return canAny
end




function BridgeTask.cleanCanDo(body, square, skip)
    local kinds = squareCleanKinds(square)
    for i = 1, #kinds do
        local k = kinds[i]
        if skip == nil or not skip[k] then
            local _, _, canDo = BridgeTask.cleanKindTool(body, k)
            if canDo then return k end
        end
    end
    return nil
end






local function needFragmentKey(name)
    if name == "fluid" then
        return "JobNeedFragFluid"
    elseif name == "implement" then
        return "JobNeedFragImplement"
    elseif name == "petrol" then
        return "JobNeedFragPetrol"
    elseif name == "cut" then
        return "JobNeedFragCut"
    else
        return "JobNeedFragAsh"
    end
end


local function sayGet(key, a)
    local full = "IGUI_NotAlone_Say_" .. key
    pcall(function()
        if Bridge ~= nil and BridgeData ~= nil and BridgeData.isMale(Bridge.store) then
            local m = "IGUI_NotAlone_SayM_" .. key
            local t = getTextOrNull(m, "", "")
            if t ~= nil and t ~= "" and t ~= m then full = m end
        end
    end)
    return getText(full, a)
end

function BridgeTask.cleanNeedText(needs, mode)
    if needs == nil then return nil end
    local order = {}
    if needs.implement then order[#order + 1] = "implement" end
    if needs.fluid then order[#order + 1] = "fluid" end
    if needs.petrol then order[#order + 1] = "petrol" end
    if needs.ash then order[#order + 1] = "ash" end
    if needs.cut then order[#order + 1] = "cut" end
    if #order == 0 then return nil end
    local frags = {}
    for i = 1, #order do
        frags[i] = sayGet(needFragmentKey(order[i]))
    end
    local body
    if #frags == 1 then
        body = frags[1]
    else
        local join = sayGet("JobNeedListJoin")
        local andw = sayGet("JobNeedListAnd")
        local head = {}
        for i = 1, #frags - 1 do head[#head + 1] = frags[i] end
        body = table.concat(head, join) .. andw .. frags[#frags]
    end
    if mode == "start" then
        return sayGet("JobStartNeedList", body)
    elseif mode == "partial" then
        return sayGet("JobPartialNeedList", body)
    end
    return sayGet("JobNeedList", body)
end


local function cleanNeedsTable(implement, fluid, petrol, ash, cut)
    return { implement = implement == true, fluid = fluid == true,
             petrol = petrol == true, ash = ash == true, cut = cut == true }
end
BridgeTask.cleanNeedsTable = cleanNeedsTable







local function applyClean(body, square, kind)
    if square == nil then return end
    if Bridge ~= nil and Bridge.mp then






        if BridgeClean ~= nil then pcall(function() BridgeClean.applyClean(square, kind, body) end) end
        pcall(function()
            sendClientCommand(BridgeData.owner(), "Bridge", "cleanSquare",
                { x = square:getX(), y = square:getY(), z = square:getZ(), kind = kind })
        end)
        return
    end
    if BridgeClean ~= nil then BridgeClean.applyClean(square, kind, body) end
end
BridgeTask.applyClean = applyClean


local CLEAN_EVENT = {
    blood = "EvCleaning", grime = "EvCleaning", graffiti = "EvGraffiti",
    ashes = "EvClearingAsh", glass = "EvGlassGround", window = "EvGlassWindow",
    vine = "EvCutVines",
}



local function ensureInMain(body, item)
    if body == nil or item == nil then return end
    local inv = body:getInventory()
    local top = false
    pcall(function() top = item:getContainer() == inv end)
    if top then return end
    pcall(function()
        item:getContainer():Remove(item)
        inv:AddItem(item)
    end)
end




local function rememberHands(body)
    BridgeTask.savedPrimary, BridgeTask.savedSecondary = nil, nil
    if body == nil then return end
    pcall(function() BridgeTask.savedPrimary = body:getPrimaryHandItem() end)
    pcall(function() BridgeTask.savedSecondary = body:getSecondaryHandItem() end)
end

local function ownedByBody(body, item)
    if item == nil then return false end
    local ok = false
    pcall(function()
        local c = item:getContainer()
        ok = c == body:getInventory() or (c ~= nil and c:getOutermostContainer() == body:getInventory())
    end)
    return ok
end

local function cleanerStillOk(item, kind)
    if item == nil then return false end
    local ok = false
    pcall(function()
        local c = item:getFluidContainer()
        ok = c ~= nil and c:getAmount() >= (BridgeTask.CLEAN_FLUID_PER_SQUARE or 0.025)
    end)
    return ok
end
BridgeTask.cleanerStillOk = cleanerStillOk

function BridgeTask.toolOk(body, item)
    if body == nil or item == nil then return false end
    local ok = false
    pcall(function() ok = not item:isBroken() end)
    if not ok then return false end
    local held = false
    pcall(function()
        held = body:getPrimaryHandItem() == item or body:getSecondaryHandItem() == item
    end)
    return held or ownedByBody(body, item)
end

function BridgeTask.cachedTool(body, key, finder, okFn)
    local item = BridgeTask.tools[key]
    local at = BridgeTask.toolsAt[key] or -99999
    if item ~= nil and (Bridge.tick - at) < 120 and (okFn == nil or okFn(body, item)) then
        return item
    end
    item = finder(body)
    BridgeTask.tools[key] = item
    BridgeTask.toolsAt[key] = Bridge.tick
    return item
end

function BridgeTask.cleanGear(body, kind)
    local entry = BridgeTask.cleanGearCache[kind]
    local at = BridgeTask.cleanGearAt[kind] or -99999
    local age = Bridge.tick - at
    if entry ~= nil and age < 120 then
        local toolOk = entry.tool == nil or BridgeTask.toolOk(body, entry.tool)
        local fluidOk = true
        if kind == "blood" or kind == "grime" or kind == "graffiti" then
            fluidOk = cleanerStillOk(entry.cleaner, kind)
        end
        if toolOk and fluidOk then return entry.tool, entry.cleaner end
        BridgeTask.cleanClassAt = -99999
    end
    local tool, cleaner = BridgeTask.cleanKindTool(body, kind)
    BridgeTask.cleanGearCache[kind] = { tool = tool, cleaner = cleaner }
    BridgeTask.cleanGearAt[kind] = Bridge.tick
    return tool, cleaner
end

local function restoreHands(body)
    local p, s = BridgeTask.savedPrimary, BridgeTask.savedSecondary
    BridgeTask.savedPrimary, BridgeTask.savedSecondary = nil, nil
    BridgeTask.subHands = nil


    if BridgeTask.cleanDrawPending then
        BridgeTask.cleanDrawPending = false
        return
    end
    if body == nil then return end
    pcall(function()
        if p == nil or ownedByBody(body, p) then body:setPrimaryHandItem(p) end
        if s == nil or ownedByBody(body, s) then body:setSecondaryHandItem(s) end
        body:resetModelNextFrame()
    end)
    pcall(function() BridgeInventory.redress(body) end)
end







local function beginCleanHands(body, kind, tool, cleaner)
    if body == nil then return end



    local key = tostring(kind) .. "|" .. tostring(tool and tool:getID() or "-")
        .. "|" .. tostring(cleaner and cleaner:getID() or "-")
    if BridgeTask.cleanHandsKey == key then return end
    if BridgeTask.subHands == nil then
        BridgeTask.subHands = {}
        pcall(function() BridgeTask.subHands.p = body:getPrimaryHandItem() end)
        pcall(function() BridgeTask.subHands.s = body:getSecondaryHandItem() end)
    end
    BridgeTask.cleanHandsKey = key
    if kind == "glass" or kind == "window" then
        local empty = false
        pcall(function() empty = body:getPrimaryHandItem() == nil and body:getSecondaryHandItem() == nil end)
        if not empty then
            pcall(function()
                body:setPrimaryHandItem(nil)
                body:setSecondaryHandItem(nil)
                body:resetModelNextFrame()
            end)
            pcall(function() BridgeInventory.redress(body) end)
        end
        return
    end
    if tool == nil then return end
    local two = twoHandedImplement(tool)


    local offWanted = two and tool or nil
    local same = false
    pcall(function()
        same = body:getPrimaryHandItem() == tool and body:getSecondaryHandItem() == offWanted
    end)
    if same then return end
    ensureInMain(body, tool)



    if cleaner ~= nil then ensureInMain(body, cleaner) end
    pcall(function()
        body:setPrimaryHandItem(tool)
        body:setSecondaryHandItem(offWanted)
        body:resetModelNextFrame()
    end)
    pcall(function() BridgeInventory.redress(body) end)
end



local function stowCleanWeapon(body)
    BridgeTask.cleanStowPending = false
    if body == nil or BridgeWeapon == nil or BridgeWeapon.putAwayMoved == nil then return false end
    local moved = false
    pcall(function() moved = BridgeWeapon.putAwayMoved(body, true) == true end)
    BridgeTask.cleanStowPending = moved
    return moved
end
BridgeTask.stowCleanWeapon = stowCleanWeapon



local function endCleanHands(body)
    if BridgeTask.subHands == nil and BridgeTask.cleanHandsKey == nil then return end

    local p, s = BridgeTask.savedPrimary, BridgeTask.savedSecondary
    BridgeTask.subHands = nil
    BridgeTask.cleanHandsKey = nil
    if body == nil then return end

    pcall(function()
        body:setPrimaryHandItem(nil)
        body:setSecondaryHandItem(nil)
    end)




    local assigned = false
    pcall(function()
        assigned = BridgeWeapon ~= nil and p ~= nil and BridgeWeapon.isAssigned(body, p)
    end)
    if assigned then


        local red = BridgeData ~= nil and BridgeData.owner() or nil
        local want = false
        pcall(function() want = red ~= nil and BridgeWeapon.wantNow(body, red) == true end)
        if want then


            pcall(function()
                local b = tostring(body:getBumpType())
                if b ~= "" and b ~= "nil" then body:setBumpType("") end
            end)
            pcall(function() BridgeWeapon.drawMoved(body, true, true) end)
            local moving = false
            pcall(function() moving = BridgeWeapon.move ~= nil end)
            if moving then
                BridgeTask.cleanDrawPending = true
                pcall(function() BridgeInventory.redress(body) end)
                return
            end
        end

        pcall(function()
            if p == nil or ownedByBody(body, p) then body:setPrimaryHandItem(p) end
            if s == nil or ownedByBody(body, s) then body:setSecondaryHandItem(s) end
            body:resetModelNextFrame()
        end)
        pcall(function() BridgeInventory.redress(body) end)
        return
    end
    pcall(function()
        if p == nil or ownedByBody(body, p) then body:setPrimaryHandItem(p) end
        if s == nil or ownedByBody(body, s) then body:setSecondaryHandItem(s) end
        body:resetModelNextFrame()
    end)
    pcall(function() BridgeInventory.redress(body) end)
end
BridgeTask.beginCleanHands = beginCleanHands
BridgeTask.endCleanHands = endCleanHands




local function playGlassSound(body, square, radius)
    if square == nil then return end
    pcall(function() square:playSound("RemoveBrokenGlass") end)
    if body ~= nil then
        pcall(function() addSound(body, body:getX(), body:getY(), body:getZ(), radius or 6, 1) end)
    end
end








local function cleanSound(body, square, kind, tool)


    if kind == "vine" then return end
    if kind == "window" then
        playGlassSound(body, square, 6)
        return
    elseif kind == "glass" then
        playGlassSound(body, square, 20)
        return
    end
    local name = nil
    if kind == "ashes" then
        name = BridgeTask.ASH_SOUND
    elseif kind == "grime" then
        name = BridgeTask.CLEAN_SOUND
    else
        name = (twoHandedImplement(tool) or isToiletBrush(tool))
            and BridgeTask.CLEAN_SOUND or BridgeTask.CLEAN_SOUND_HAND
    end
    if body == nil or name == nil then return end

    local prev = BridgeTask.cleanSoundHandle
    BridgeTask.cleanSoundHandle = nil
    if prev ~= nil then pcall(function() body:stopOrTriggerSound(prev) end) end
    local snd = nil
    pcall(function() snd = body:playSound(name) end)
    BridgeTask.cleanSoundHandle = snd
end


local function stopCleanSound(body)
    local snd = BridgeTask.cleanSoundHandle
    BridgeTask.cleanSoundHandle = nil
    if body == nil or snd == nil then return end
    pcall(function() body:stopOrTriggerSound(snd) end)
end
BridgeTask.stopCleanSound = stopCleanSound

local function clearBetween(a, b)
    if a == nil or b == nil then return true end
    local yes = true
    pcall(function()
        yes = false
        if a:isWallTo(b) then yes = true return end
        local win = nil
        pcall(function() win = a:getWindowTo(b) end)
        if win ~= nil then
            local open = false
            pcall(function() open = win:IsOpen() end)
            if not open then yes = true end
        end
    end)
    return yes
end

local function sealedBetween(a, b)
    if a == nil or b == nil then return true end
    local dx, dy = b:getX() - a:getX(), b:getY() - a:getY()
    if math.abs(dx) > 1 or math.abs(dy) > 1 then return true end
    if math.abs(dx) + math.abs(dy) == 1 then return clearBetween(a, b) end
    local cell = getCell()
    local p = cell:getGridSquare(a:getX() + dx, a:getY(), a:getZ())
    local q = cell:getGridSquare(a:getX(), a:getY() + dy, a:getZ())
    return (clearBetween(a, p) or clearBetween(p, b)) and (clearBetween(a, q) or clearBetween(q, b))
end

local function playerOnSquare(sq)
    if sq == nil then return false end
    local red = BridgeData ~= nil and BridgeData.owner() or nil
    if red == nil then return false end
    local yes = false
    pcall(function()
        yes = math.abs(red:getX() - (sq.x + 0.5)) < 0.6
            and math.abs(red:getY() - (sq.y + 0.5)) < 0.6
            and math.abs(math.floor(red:getZ()) - math.floor(sq.z or 0)) < 1
    end)
    return yes
end

local function isBadSpot(x, y)
    local set = BridgeTask.badSpots
    return set ~= nil and set[x .. "," .. y] == true
end

local function spotUsable(sq)
    if sq == nil then return false end
    local ok = false
    pcall(function() ok = sq:canStand() == true end)
    return ok
end

local function freeAdjacent(body, target)
    local orth, orthD, diag, diagD = nil, nil, nil, nil
    local targetSq = nil
    pcall(function() targetSq = getCell():getGridSquare(target.x, target.y, target.z) end)
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local x, y = target.x + dx, target.y + dy
                local sq = nil
                pcall(function() sq = getCell():getGridSquare(x, y, target.z) end)
                if sq ~= nil then
                    local free = false
                    pcall(function() free = sq:canStand() end)


                    local blocked = false
                    if targetSq ~= nil then
                        pcall(function() blocked = sq:isSomethingTo(targetSq) end)
                    end
                    if free and not blocked and not isBadSpot(x, y)
                            and not sealedBetween(sq, targetSq) then
                        local d = (body:getX() - (x + 0.5)) ^ 2 + (body:getY() - (y + 0.5)) ^ 2
                        if dx == 0 or dy == 0 then
                            if orthD == nil or d < orthD then orth, orthD = { x = x, y = y, z = target.z }, d end
                        else
                            if diagD == nil or d < diagD then diag, diagD = { x = x, y = y, z = target.z }, d end
                        end
                    end
                end
            end
        end
    end
    return orth or diag
end

function BridgeTask.clearChop(body)
    if body == nil then return end
    pcall(function()
        body:setVariable("NotAloneHitNow", false)


        local bump = tostring(body:getBumpType())
        local st = tostring(body:getActionStateName())
        if bump == BridgeTask.CHOP_ANIM or st == "bumped" then
            body:setVariable("BumpAnimFinished", true)
            body:setBumpType("Stand")
        end
    end)
end

function BridgeTask.markDone()
    BridgeTask.doneCount = (BridgeTask.doneCount or 0) + 1
end


local function noPathKey(reason)
    if reason == "locked" then return "JobDoorLocked" end
    if reason == "barricade" then return "JobDoorBarricaded" end
    return "JobNoPath"
end



function BridgeTask.unreachableKey(reason)
    if reason == "locked" then return "JobDoorLockedNoPath" end
    if reason == "barricade" then return "JobDoorBarricadedNoPath" end
    return "JobNoPath"
end




function BridgeTask.markUnreachable(reason)
    BridgeTask.failCount = (BridgeTask.failCount or 0) + 1
    if reason ~= nil and BridgeTask.blockedReason == nil then
        BridgeTask.blockedReason = reason
    end
    if BridgeTask.spokeUnreachable then return end
    BridgeTask.spokeUnreachable = true
    BridgeTask.spokeNoPath = true
    Bridge.speak(noPathKey(reason))
end







function BridgeTask.dropTarget(reason)
    BridgeTask.markUnreachable(reason)


    local body = Bridge ~= nil and Bridge.body or nil
    pcall(stopCleanSound, body)
    BridgeTask.current = nil
    BridgeTask.spot = nil
    BridgeTask.bestD = nil
    BridgeTask.vineObject = nil
    BridgeTask.cleanSpan = nil
    BridgeTask.progressAt = nil
    BridgeTask.pathFails = 0
    BridgeTask.pathFailTick = nil
    BridgeTask.still = 0
    BridgeTask.checkX, BridgeTask.checkY = nil, nil
    BridgeTask.openingRef, BridgeTask.openingKey, BridgeTask.openingTries = nil, nil, nil
    BridgeTask.openingSince = nil
    if (BridgeTask.doneCount or 0) == 0 and (BridgeTask.failCount or 0) >= BridgeTask.ABORT_AFTER_FAILS
            and #BridgeTask.queue > 0 then
        BridgeTask.info = "area unreachable, stopping"
        return BridgeTask.finish()
    end
    if #BridgeTask.queue == 0 then return BridgeTask.finish() end
    return true
end

function BridgeTask.enclosureKey(body)
    if BridgeDoors == nil or BridgeDoors.enclosureKey == nil or body == nil then return nil end
    local k = nil
    pcall(function() k = BridgeDoors.enclosureKey(body:getCurrentSquare()) end)
    return k
end

function BridgeTask.enclosureKeyOf(sq)
    if BridgeDoors == nil or BridgeDoors.enclosureKey == nil or sq == nil then return nil end
    local k = nil
    pcall(function() k = BridgeDoors.enclosureKey(sq) end)
    return k
end

function BridgeTask.reachOk(body, targetSq)
    if targetSq == nil or BridgeDoors == nil or BridgeDoors.canReach == nil then return true end
    local bodySq = nil
    pcall(function() bodySq = body:getCurrentSquare() end)
    local bk = BridgeTask.enclosureKey(body)
    local tk = BridgeTask.enclosureKeyOf(targetSq)
    if tk == nil or tk == -1 then return true end
    local ok = true
    pcall(function() ok = BridgeDoors.canReach(bodySq, targetSq) == true end)
    if not ok then
        log(string.format("target %d,%d unreachable: no accessible opening", targetSq:getX(), targetSq:getY()))
    end
    return ok
end

local function spotDump(target)
    local cell = getCell()
    local t = nil
    pcall(function() t = cell:getGridSquare(target.x, target.y, target.z) end)
    local parts = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local sq = nil
                pcall(function() sq = cell:getGridSquare(target.x + dx, target.y + dy, target.z) end)
                if sq ~= nil then
                    local stand, free, seal = false, false, false
                    pcall(function() stand = sq:canStand() == true end)
                    pcall(function() free = sq:isFree(false) == true end)
                    if t ~= nil then pcall(function() seal = sealedBetween(sq, t) == true end) end
                    local pl = playerOnSquare({ x = target.x + dx, y = target.y + dy, z = target.z })
                    parts[#parts + 1] = string.format("%d,%d %s %s %s %s",
                        target.x + dx, target.y + dy,
                        stand and "stand" or "NOstand", free and "free" or "NOfree",
                        seal and "SEALED" or "open", pl and "player" or "-")
                end
            end
        end
    end
    return table.concat(parts, " | ")
end

local function reachSpot(body, targetSq, target)
    local tkey = target.x .. "," .. target.y .. "," .. tostring(target.z)
    if BridgeTask.badSpotTarget ~= tkey then
        BridgeTask.badSpotTarget = tkey
        BridgeTask.badSpots = {}
        BridgeTask.stallKey = {}
    end
    local spot = nil
    if targetSq ~= nil and BridgeDoors ~= nil and BridgeDoors.standNear ~= nil then
        local sq = nil
        pcall(function() sq = BridgeDoors.standNear(targetSq, body) end)
        if sq ~= nil and spotUsable(sq) and not isBadSpot(sq:getX(), sq:getY())
                and not (sq:getX() == target.x and sq:getY() == target.y)
                and not sealedBetween(sq, targetSq) then
            pcall(function() spot = { x = sq:getX(), y = sq:getY(), z = sq:getZ() } end)
        end
    end
    if spot == nil then spot = freeAdjacent(body, target) end
    return spot
end

function BridgeTask.adjacentClear(body, sq)
    if body == nil or sq == nil then return true end
    local ok = true
    pcall(function()
        local bs = body:getCurrentSquare()
        if bs == nil or bs == sq then return end
        if math.floor(bs:getZ()) ~= math.floor(sq:getZ()) then return end
        local dx, dy = sq:getX() - bs:getX(), sq:getY() - bs:getY()
        if math.abs(dx) > 1 or math.abs(dy) > 1 then ok = false return end
        if sealedBetween(bs, sq) then ok = false end
    end)
    return ok
end

function BridgeTask.walkTo(body, target, reach, reachClear, onTarget)
    local bodyZ = math.floor(body:getZ())
    local targetSq = nil
    pcall(function() targetSq = getCell():getGridSquare(target.x, target.y, target.z) end)
    local sameFloor = targetSq == nil or math.floor(targetSq:getZ()) == bodyZ

    local d = math.sqrt((body:getX() - (target.x + 0.5)) ^ 2 + (body:getY() - (target.y + 0.5)) ^ 2)
    if sameFloor and d <= reach and (not reachClear or BridgeTask.adjacentClear(body, targetSq)) then
        BridgeTask.openingRef, BridgeTask.openingKey, BridgeTask.openingTries = nil, nil, nil
        BridgeTask.openingSince = nil
        return "arrived", nil
    end

    if BridgeMove ~= nil and BridgeMove.openingBlocked ~= nil then
        local why = BridgeMove.openingBlocked
        BridgeMove.openingBlocked = nil
        BridgeTask.info = "openings exhausted"
        return "unreachable", why
    end

    local openStatus, openReason = BridgeNav.opening(BridgeTask, {
        giveUp = BridgeTask.OPENING_GIVE_UP, target = target })
    if openStatus == "stale" then
        BridgeTask.info = "opening unreachable"
        return "unreachable", openReason
    end

    if sameFloor and not BridgeTask.reachOk(body, targetSq) then
        BridgeTask.info = "no accessible opening"
        return "unreachable", BridgeNav.blockedReason(target)
    end

    if not sameFloor then
        if BridgeTask.spot == nil or math.floor(BridgeTask.spot.z or target.z) ~= math.floor(target.z) then
            BridgeTask.spot = { x = target.x, y = target.y, z = target.z }
        end
    elseif onTarget then
        BridgeTask.spot = { x = target.x, y = target.y, z = target.z }
    elseif BridgeTask.spot == nil then
        BridgeTask.spot = reachSpot(body, targetSq, target)
        if BridgeTask.spot == nil then
            BridgeTask.info = "no reachable spot"
            log(string.format("no spot for target %d,%d,%d (body z=%s) bx=%.1f by=%.1f",
                target.x, target.y, target.z, tostring(bodyZ), body:getX(), body:getY()))
            log("  neighbours: " .. spotDump(target))
            return "unreachable", nil
        end
        log(string.format("spot %d,%d,%d for target %d,%d,%d", BridgeTask.spot.x, BridgeTask.spot.y, BridgeTask.spot.z, target.x, target.y, target.z))
    end

    local sx, sy = BridgeTask.spot.x + 0.5, BridgeTask.spot.y + 0.5
    local dSpot = math.sqrt((body:getX() - sx) ^ 2 + (body:getY() - sy) ^ 2)
    local wx, wy = sx, sy
    local detour = BridgeTask.detour
    if detour ~= nil then
        local dd = math.sqrt((body:getX() - detour.x) ^ 2 + (body:getY() - detour.y) ^ 2)
        if Bridge.time > (detour.expires or 0) or dd <= 1.0 then
            BridgeTask.detour = nil
            detour = nil
        end
    end
    if detour ~= nil then
        wx, wy = detour.x, detour.y
        BridgeTask.progressAt = Bridge.time
    elseif not onTarget then
        local ndx, ndy = (target.x + 0.5) - sx, (target.y + 0.5) - sy
        local nlen = math.sqrt(ndx * ndx + ndy * ndy)
        if nlen > 0.05 then
            wx = sx + (ndx / nlen) * BridgeTask.SPOT_NUDGE
            wy = sy + (ndy / nlen) * BridgeTask.SPOT_NUDGE
        end
    end
    if sameFloor and dSpot <= (onTarget and reach or BridgeTask.STOP_DIST)
            and (not reachClear or BridgeTask.adjacentClear(body, targetSq)) then
        BridgeTask.openingRef, BridgeTask.openingKey, BridgeTask.openingTries = nil, nil, nil
        BridgeTask.openingSince = nil
        return "arrived", nil
    end



    if BridgeTask.bestD == nil or dSpot < BridgeTask.bestD - 0.3 then
        BridgeTask.bestD = dSpot
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
    end

    if BridgeMove ~= nil and BridgeMove.openingWay ~= nil then
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
    end

    local pathStatus = BridgeNav.notePathFail(BridgeTask, { limit = BridgeTask.PATH_FAIL_LIMIT })
    if pathStatus == "failed" then
        BridgeTask.info = "no path to target"
        return "unreachable", BridgeNav.blockedReason(target)
    end



    local progress = BridgeNav.progress(BridgeTask, {
        noProgress = BridgeTask.WALK_NO_PROGRESS, timeout = BridgeTask.WALK_TIMEOUT,
        onSpot = function() return sameFloor and playerOnSquare(BridgeTask.spot) end })
    if progress == "waiting" then
        BridgeTask.info = "waiting for player"
        return "walking", nil
    elseif progress == "timeout" then
        BridgeTask.info = "no progress to target"
        return "unreachable", BridgeNav.blockedReason(target)
    end

    local stall = BridgeNav.stall(body, BridgeTask, {
        ticks = BridgeTask.STALL_TICKS,
        move = 0.3,
        exempt = function()
            return BridgeMove.cross ~= nil or BridgeMove.doorAct ~= nil
                or BridgeMove.window ~= nil or BridgeMove.pendingClimb ~= nil
        end,
        onSpot = function() return sameFloor and playerOnSquare(BridgeTask.spot) end })
    if stall == "waiting" then
        BridgeTask.info = "waiting for player"
        return "walking", nil
    elseif stall == "stalled" then
        local point, dpx, dpy = BridgeNav.detour(body, target.x, target.y, target.z, BridgeTask,
            { step = 1.6, ticks = 150 })
        if point ~= nil then
            log(string.format("stalled: stepping around via %d,%d", dpx, dpy))
        end
        if BridgeTask.spot ~= nil then
            local key = BridgeTask.spot.x .. "," .. BridgeTask.spot.y
            BridgeTask.stallKey = BridgeTask.stallKey or {}
            BridgeTask.stallKey[key] = (BridgeTask.stallKey[key] or 0) + 1
            if BridgeTask.stallKey[key] >= 2 then
                BridgeTask.badSpots = BridgeTask.badSpots or {}
                BridgeTask.badSpots[key] = true
            end
        end
        BridgeTask.spot = nil
        BridgeTask.progressAt = Bridge.time
        pcall(function() BridgeMove.stopPath(body) end)
        if BridgeTask.forceIdle ~= nil then BridgeTask.forceIdle(body) end
        BridgeTask.info = "stalled, re-pathing"
        return "walking", nil
    end

    BridgeTask.phase = "walk"


    Bridge.target = { x = wx, y = wy, z = target.z }
    pcall(function() BridgeMove.update(body) end)

    pcall(function() BridgeMove.rememberDoorNear(body) end)
    pcall(function() BridgeMove.closeBehind(body) end)
    BridgeTask.info = string.format("walking d=%.1f spot=%.1f %s", d, dSpot, tostring(BridgeMove.pathResult))
    if Bridge.tick ~= BridgeTask.walkLogAt and Bridge.tick % 60 == 0 then
        BridgeTask.walkLogAt = Bridge.tick
        pcall(function()
            log(string.format("walk tgt=%d,%d spot=%d,%d aim=%.2f,%.2f d=%.2f dSpot=%.2f clear=%s path=%s stall=%d",
                target.x, target.y, BridgeTask.spot.x, BridgeTask.spot.y, wx, wy, d, dSpot,
                tostring(BridgeTask.adjacentClear(body, targetSq)), tostring(BridgeMove.pathResult),
                BridgeTask.still or 0))
        end)
    end
    return "walking", nil
end

function BridgeTask.requireGlass(sq)
    if sq == nil or not BridgeTask.active or BridgeTask.kind ~= "cleanUp" then return false end
    local t = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
    local cur = BridgeTask.current
    if cur ~= nil and cur.x == t.x and cur.y == t.y and cur.z == t.z then return true end
    for i = 1, #BridgeTask.queue do
        local q = BridgeTask.queue[i]
        if q.x == t.x and q.y == t.y and q.z == t.z then
            BridgeTask.mustTarget = t
            return true
        end
    end
    if cur ~= nil then
        table.insert(BridgeTask.queue, 1, cur)
        BridgeTask.current = nil
        BridgeTask.cleanApplied = {}
        BridgeTask.spot = nil
        pcall(stopCleanSound, Bridge.body)
    end
    table.insert(BridgeTask.queue, 1, t)
    BridgeTask.mustTarget = t
    log(string.format("glass window %d,%d queued for clean-up", t.x, t.y))
    return true
end

function BridgeTask.speakMissing(kind)
    local def = kind ~= nil and BridgeTask.kinds[kind] or nil
    local missing = nil
    if def ~= nil and def.missing ~= nil then
        pcall(function() missing = def.missing(Bridge.body) end)
    end



    if kind == "cleanUp" then
        local needs = cleanNeedsTable(BridgeTask.needImplement, BridgeTask.needFluid,
            BridgeTask.needPetrol, BridgeTask.needAshTool, BridgeTask.needCut)
        local text = BridgeTask.cleanNeedText(needs, "need")
        if text ~= nil then
            Bridge.speakText(text)
            return
        end
    end
    local key = "JobNoSupplies"
    if missing == "axe" then key = "JobNoAxe"
    elseif missing == "implement" then key = "JobNeedImplement"
    elseif missing == "cleaner" then key = "JobNeedCleaner"
    elseif missing == "petrol" then key = "JobNeedPetrol"
    elseif missing == "ashes" then key = "JobNeedAshTool"
    elseif missing == "broom" then key = "JobNeedBroom"
    elseif missing == "crowbar" then key = "JobNeedCrowbar" end
    Bridge.speak(key)
end

function BridgeTask.dangerNear(body, radius)
    local danger = false
    local red = BridgeData.owner()
    local dr = radius or BridgeTask.DANGER_RADIUS
    pcall(function()
        if BridgeFight ~= nil and (BridgeFight.target ~= nil or BridgeFight.state ~= "idle") then danger = true return end
        local bx, by = body:getX(), body:getY()
        local rx, ry = bx, by
        if red ~= nil then rx, ry = red:getX(), red:getY() end
        local list = nil
        if BridgeZS ~= nil then list = BridgeZS.nearUnion(bx, by, rx, ry, dr + 0.01, { tag = "task.danger" }) end
        if list == nil then list = getCell():getZombieList() end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            local nearEnough = false
            if z ~= nil and z ~= body then
                local d = dist2(z, body)
                local dr2 = red ~= nil and dist2(z, red) or 999
                nearEnough = math.abs(z:getZ() - body:getZ()) < 0.8 and (d < dr or dr2 < dr)
            end
            if nearEnough then
                local threat = false
                if BridgeHorde ~= nil and BridgeHorde.threat ~= nil then
                    threat = BridgeHorde.threat(z)
                else
                    threat = z:isAlive() and z:getHealth() > 0
                        and not z:getVariableBoolean("NotAloneBody") and not BridgeData.harmless(z)
                end
                if threat then
                    local seen = false
                    pcall(function() seen = (red ~= nil and red:CanSee(z)) or body:CanSee(z) end)
                    if seen then danger = true return end
                end
            end
        end
    end)
    return danger
end

function BridgeTask.reset()
    local ckind = BridgeTask.kind
    local def = ckind ~= nil and BridgeTask.kinds[ckind] or nil
    if def ~= nil and def.leave ~= nil then pcall(def.leave, Bridge.body) end
    BridgeTask.active = false
    BridgeTask.state = "idle"
    BridgeTask.kind = nil
    BridgeTask.body = nil
    BridgeTask.queue = {}
    BridgeTask.current = nil
    BridgeTask.phase = nil
    BridgeTask.info = "reset"
    BridgeTask.pendingStart = nil
    BridgeTask.deferred = {}
    BridgeTask.needImplement, BridgeTask.needFluid = nil, nil
    BridgeTask.needPetrol, BridgeTask.needAshTool = nil, nil
    BridgeTask.needCut = nil
    BridgeTask.clearNeedCut = nil
    BridgeTask.cleanApplied = {}
    BridgeTask.chargeCleanSpend()
    BridgeTask.cleanSoundHandle = nil
    BridgeTask.subHands = nil
    BridgeTask.cleanHandsKey = nil
    BridgeTask.cleanStowPending = false
    BridgeTask.cleanDrawPending = false
    BridgeTask.tools = {}
    BridgeTask.toolsAt = {}
    BridgeTask.cleanGearCache = {}
    BridgeTask.cleanGearAt = {}
    BridgeTask.cleanKindCache, BridgeTask.cleanClassKey, BridgeTask.cleanClassAt, BridgeTask.cleanWallCache = nil, nil, nil, nil
    BridgeTask.plantKindCache, BridgeTask.plantKindKey, BridgeTask.plantKindAt = nil, nil, nil
    BridgeTask.danger, BridgeTask.dangerAt = nil, nil
    BridgeTask.washSink = nil
    BridgeTask.washPhase = nil
    BridgeTask.washSince = 0
    BridgeTask.washTicks = nil
    BridgeTask.fillSink = nil
    BridgeTask.fillPhase = nil
    BridgeTask.fillItems = nil
    BridgeTask.fillItem = nil
    BridgeTask.fillIndex = nil
    BridgeTask.fillTicks = nil
    BridgeTask.fillAmount = nil
    BridgeTask.emptyItems = nil
    BridgeTask.emptyItem = nil
    BridgeTask.emptyIndex = nil
    BridgeTask.emptyTicks = nil
    BridgeTask.chopRest = false
    BridgeTask.chopRestSitAt = nil
    BridgeTask.chopResumeAt = nil
    BridgeTask.savedPrimary, BridgeTask.savedSecondary = nil, nil
    BridgeTask.mustTarget = nil
    BridgeTask.lootList = nil
    BridgeTask.lootIdx = nil
    BridgeTask.lootPending = nil
    BridgeTask.lootPendingAt = nil
    BridgeTask.lootAct = nil
    BridgeTask.lootSrc = nil
    BridgeTask.lootSettled = false
    BridgeTask.lootNextAt = nil
    BridgeTask.lootFullSaid = false
    BridgeTask.lootTook = 0
    BridgeTask.lootNoRoom = 0
    BridgeTask.lootFull = false
    BridgeTask.sitPlan = nil
    BridgeTask.sitUp = nil
    BridgeTask.sitAnimSeen = false
    BridgeTask.sitPathFails = 0
    BridgeTask.sitFailTick = nil
    BridgeTask.sitBestD = nil
    BridgeTask.sitCloseAt = nil
    BridgeTask.sitFromX, BridgeTask.sitFromY, BridgeTask.sitSlideAt = nil, nil, nil
    BridgeTask.layPlan = nil
    BridgeTask.layUp = nil
    BridgeTask.laySleep = false
    BridgeTask.layAnim = nil
    BridgeTask.layAnimSeen = false
    BridgeTask.layHintSaid = false
    BridgeTask.layCloseAt = nil
    BridgeTask.layFromX, BridgeTask.layFromY, BridgeTask.laySlideAt = nil, nil, nil
    BridgeTask.detour = nil
    BridgeTask.detourSide = nil
    BridgeTask.clearCorpseState()
    restoreForcedWalk()
    Bridge.target = nil
end

function BridgeTask.start(kind, targets, corpseDest, opts)
    if BridgeTask.ENABLED ~= 1 then return "disabled" end
    if BridgeTask.active then return "busy" end
    if Bridge == nil or not Bridge.alive() or Bridge.kind ~= "zombie" then return "no body" end
    if Bridge.drivable ~= nil and not Bridge.drivable() then return "not drivable" end
    local def = BridgeTask.kinds[kind]
    if def == nil then return "unknown job" end
    if type(targets) ~= "table" then return "no targets" end
    if #targets == 0 and def.noTargets ~= true then return "no targets" end

    BridgeTask.pendingStart = nil

    if BridgeFetch ~= nil and type(BridgeFetch.primeJob) == "function" then
        local fetch = nil
        pcall(function() fetch = BridgeFetch.primeJob(kind, targets) end)
        if fetch == "pending" then
            BridgeTask.pendingStart = { kind = kind, targets = targets, corpseDest = corpseDest, since = Bridge.time }
            log("waiting for home supplies for " .. tostring(kind))
            return "fetching"
        end
    end

    local availScope = nil
    if kind == "washSink" then availScope = opts ~= nil and opts.scope or "self" end
    if def.available ~= nil and not def.available(Bridge.body, availScope) then
        if kind == "fillWater" then
            Bridge.speak("JobFillNothing")
            return "unavailable"
        end
        if kind == "emptyFluid" then
            Bridge.speak("JobEmptyNothing")
            return "unavailable"
        end
        BridgeTask.speakMissing(kind)
        return "unavailable"
    end

    if kind == "chopTree" and BridgeFight ~= nil
            and (1 - (BridgeFight.fatigue or 0)) < BridgeTask.CHOP_REFUSE_STAMINA then
        Bridge.speak("JobNeedRest")
        return "tired"
    end
    if kind == "moveCorpses" and BridgeFight ~= nil
            and (1 - (BridgeFight.fatigue or 0)) < BridgeTask.CORPSE_REFUSE_STAMINA then
        Bridge.speak("JobNeedRest")
        return "tired"
    end
    if kind == "pryDoor" and BridgeFight ~= nil
            and (1 - (BridgeFight.fatigue or 0)) < BridgeTask.PRY_STAMINA_MIN then
        Bridge.speak("JobNeedRest")
        return "tired"
    end

    BridgeTask.kind = kind
    BridgeTask.queue = {}
    for i = 1, #targets do BridgeTask.queue[i] = targets[i] end
    if BridgeWorkSelect ~= nil and BridgeWorkSelect.sortTargets ~= nil then
        pcall(BridgeWorkSelect.sortTargets, BridgeTask.queue)
    end
    BridgeTask.grabOnly = false
    if kind == "lootArea" and #targets > 0 then
        local allOnly = true
        for i = 1, #targets do
            local t = targets[i]
            if type(t) ~= "table" or type(t.only) ~= "table" or #t.only == 0 then
                allOnly = false
                break
            end
        end
        BridgeTask.grabOnly = allOnly
    end
    if kind == "lootArea" then
        local wanted, fits = BridgeTask.lootScan(Bridge.body)
        if not wanted then
            Bridge.speak("JobNoLoot")
            BridgeTask.queue = {}
            BridgeTask.kind = nil
            return "unavailable"
        end
        if not fits then
            Bridge.speak("JobLootFull")
            BridgeTask.queue = {}
            BridgeTask.kind = nil
            return "unavailable"
        end
    end
    local clearNeedPlants = false
    if kind == "clearPlants" then
        local canAny, needCut = false, false
        local hasTool = BridgeTask.findCutTool(Bridge.body) ~= nil
        for i = 1, #BridgeTask.queue do
            local t = BridgeTask.queue[i]
            local sq = getCell():getGridSquare(t.x, t.y, t.z)
            if sq ~= nil and BridgePlants ~= nil then
                if BridgePlants.squareGrass(sq) then canAny = true end
                if BridgePlants.squareBush(sq) and not hasTool then needCut = true end
            end
        end
        if not canAny and needCut then
            Bridge.speak("JobNeedCutTool")
            BridgeTask.queue = {}
            BridgeTask.kind = nil
            return "unavailable"
        end
        clearNeedPlants = needCut
    end
    BridgeTask.prevMode = BridgeData.modeOf(Bridge.store)
    BridgeTask.body = Bridge.body
    rememberHands(Bridge.body)
    BridgeTask.active = true
    BridgeTask.state = "running"
    BridgeTask.current = nil
    BridgeTask.phase = nil
    BridgeTask.swings = 0
    BridgeTask.since = Bridge.time
    BridgeTask.nextSwing = 0
    BridgeTask.spot = nil
    BridgeTask.swingStart = nil
    BridgeTask.still = 0
    BridgeTask.checkX = nil
    BridgeTask.animHold = 0
    BridgeTask.bestD = nil
    BridgeTask.progressAt = Bridge.time
    BridgeTask.pathFails = 0
    BridgeTask.pathFailTick = nil
    BridgeTask.doneCount = 0
    BridgeTask.failCount = 0
    BridgeTask.spokeNoPath = false
    BridgeTask.spokeUnreachable = false
    BridgeTask.blockedReason = nil
    BridgeTask.lastNoPathAt = nil
    if BridgeMove ~= nil then
        BridgeMove.openingBlocked = nil
        BridgeMove.openingWay = nil
        BridgeMove.doorFail = nil
        BridgeMove.doorFailObj = nil
        BridgeMove.doorFailUntil = 0
    end
    BridgeTask.deferred = {}
    BridgeTask.needImplement = nil
    BridgeTask.needFluid = nil
    BridgeTask.needPetrol = nil
    BridgeTask.needAshTool = nil
    BridgeTask.needCut = nil
    BridgeTask.clearNeedCut = nil
    BridgeTask.clearCorpseState()
    if kind == "moveCorpses" then
        BridgeTask.corpseDest = corpseDest
    end
    if kind == "washSink" then
        BridgeTask.washSink = opts ~= nil and opts.sink or nil
        BridgeTask.washPhase = nil
        BridgeTask.washSince = 0
        BridgeTask.washTicks = nil
        BridgeTask.washScope = opts ~= nil and opts.scope or "self"
    end
    if kind == "fillWater" then
        BridgeTask.fillSink = opts ~= nil and opts.sink or nil
        BridgeTask.fillItems = opts ~= nil and opts.items or nil
        BridgeTask.fillItem = opts ~= nil and opts.item or nil
        BridgeTask.fillPhase = nil
        BridgeTask.fillSince = 0
        BridgeTask.fillIndex = nil
        BridgeTask.fillTicks = nil
        BridgeTask.fillAmount = nil
        BridgeTask.fillTainted = false
        BridgeTask.fillSoundAt = nil
        BridgeTask.fillSoundHandle = nil
        BridgeTask.fillPourType = nil
    end
    if kind == "emptyFluid" then
        BridgeTask.emptyItems = opts ~= nil and opts.items or nil
        BridgeTask.emptyItem = opts ~= nil and opts.item or nil
        BridgeTask.emptyIndex = nil
        BridgeTask.emptyTicks = nil
        BridgeTask.emptySince = 0
        BridgeTask.emptySound = nil
        BridgeTask.emptyEmitter = nil
        BridgeTask.emptyPourType = nil
    end
    if kind == "shower" then
        BridgeTask.showerObj = opts ~= nil and opts.shower or nil
        BridgeTask.showerSq = opts ~= nil and opts.sq or nil
        BridgeTask.showerFacing = opts ~= nil and opts.facing or nil
        BridgeTask.showerStand = nil
        BridgeTask.showerPhase = nil
        BridgeTask.showerSince = 0
        BridgeTask.showerSeen = nil
        BridgeTask.showerWaterOn = nil
        BridgeTask.showerWashSince = nil
        BridgeTask.showerWashStartH = nil
        BridgeTask.showerWashSaid = nil
        BridgeTask.showerSink = nil
        BridgeTask.showerWaterTotal = nil
        BridgeTask.showerWaterUsed = nil
        BridgeTask.showerWaterDry = nil
        BridgeTask.showerProgressStart = nil
        BridgeTask.showerProgressTotal = nil
        BridgeTask.showerPart = nil
        BridgeTask.showerOffTo = nil
        BridgeTask.showerTowel = nil
        BridgeTask.showerTowelAt = nil
        BridgeTask.showerDressAt = nil
        BridgeTask.showerDressed = nil
    end
    BridgeTask.prevForcedWalk = BridgeMove ~= nil and BridgeMove.forcedWalk or nil
    BridgeTask.forcedWalkSaved = true
    BridgeTask.cleanApplied = {}
    BridgeTask.chargeCleanSpend()
    BridgeTask.cleanSoundHandle = nil
    BridgeTask.subHands = nil
    BridgeTask.cleanHandsKey = nil
    BridgeTask.cleanStowPending = false
    BridgeTask.cleanDrawPending = false
    BridgeTask.tools = {}
    BridgeTask.toolsAt = {}
    BridgeTask.cleanGearCache = {}
    BridgeTask.cleanGearAt = {}
    BridgeTask.cleanKindCache, BridgeTask.cleanClassKey, BridgeTask.cleanClassAt, BridgeTask.cleanWallCache = nil, nil, nil, nil
    BridgeTask.plantKindCache, BridgeTask.plantKindKey, BridgeTask.plantKindAt = nil, nil, nil
    BridgeTask.danger, BridgeTask.dangerAt = nil, nil
    BridgeTask.chopRest = false
    BridgeTask.chopRestSitAt = nil
    BridgeTask.chopResumeAt = nil
    BridgeTask.mustTarget = nil
    BridgeTask.lootList = nil
    BridgeTask.lootIdx = nil
    BridgeTask.lootPending = nil
    BridgeTask.lootPendingAt = nil
    BridgeTask.lootAct = nil
    BridgeTask.lootSrc = nil
    BridgeTask.lootSettled = false
    BridgeTask.lootNextAt = nil
    BridgeTask.lootFullSaid = false
    BridgeTask.lootTook = 0
    BridgeTask.lootNoRoom = 0
    BridgeTask.lootFull = false
    BridgeTask.sitPlan = nil
    BridgeTask.sitUp = nil
    BridgeTask.sitAnimSeen = false
    BridgeTask.sitPathFails = 0
    BridgeTask.sitFailTick = nil
    BridgeTask.sitBestD = nil
    BridgeTask.sitCloseAt = nil
    BridgeTask.sitFromX, BridgeTask.sitFromY, BridgeTask.sitSlideAt = nil, nil, nil
    BridgeTask.layPlan = nil
    BridgeTask.layUp = nil
    BridgeTask.laySleep = false
    BridgeTask.layAnim = nil
    BridgeTask.layAnimSeen = false
    BridgeTask.layHintSaid = false
    BridgeTask.layCloseAt = nil
    BridgeTask.layFromX, BridgeTask.layFromY, BridgeTask.laySlideAt = nil, nil, nil
    BridgeTask.info = "start " .. tostring(kind)
    Bridge.follow = false
    Bridge.target = nil
    pcall(function() BridgeMove.stopPath(Bridge.body) end)
    pcall(function() BridgeFight.reset(Bridge.body) end)
    pcall(function() BridgeWeapon.cancelMove(nil) end)
    pcall(function() BridgeTask.clearChop(Bridge.body) end)


    if kind == "cleanUp" or kind == "washSink" or kind == "fillWater" or kind == "emptyFluid" then pcall(stowCleanWeapon, Bridge.body) end





    local startText = nil
    if kind == "cleanUp" then
        local canAny = false
        for i = 1, #BridgeTask.queue do
            local t = BridgeTask.queue[i]
            local sq = getCell():getGridSquare(t.x, t.y, t.z)
            if BridgeTask.recordCleanNeeds(Bridge.body, sq) then canAny = true end
        end
        local needs = BridgeTask.cleanNeedsTable(
            BridgeTask.needImplement, BridgeTask.needFluid,
            BridgeTask.needPetrol, BridgeTask.needAshTool, BridgeTask.needCut)
        if needs.implement or needs.fluid or needs.petrol or needs.ash or needs.cut then
            startText = BridgeTask.cleanNeedText(needs, canAny and "start" or "need")
        end
    end
    if kind == "clearPlants" then
        BridgeTask.clearNeedCut = clearNeedPlants
        Bridge.speak(clearNeedPlants and "JobStartNeedCutTool" or "JobStart")
    elseif kind == "exercise" then
    elseif kind == "washSink" then
    elseif kind == "fillWater" then
    elseif kind == "emptyFluid" then
    elseif kind == "shower" then
    elseif kind == "pryDoor" then
        Bridge.speak("PryStart")
    elseif startText ~= nil then
        Bridge.speakText(startText)
    else
        Bridge.speak("JobStart")
    end
    log("start " .. tostring(kind) .. " targets=" .. tostring(#targets) .. " prevMode=" .. tostring(BridgeTask.prevMode))
    return "started"
end

function BridgeTask.cancel(reason)
    if not BridgeTask.active then return "idle" end
    local body = Bridge.body
    local ckind = BridgeTask.kind
    local def = ckind ~= nil and BridgeTask.kinds[ckind] or nil
    if def ~= nil and def.leave ~= nil then pcall(def.leave, body) end
    BridgeTask.active = false
    BridgeTask.state = "idle"
    BridgeTask.kind = nil
    BridgeTask.body = nil
    BridgeTask.queue = {}
    BridgeTask.current = nil
    BridgeTask.phase = nil
    BridgeTask.info = "cancel " .. tostring(reason)
    BridgeTask.pendingStart = nil
    BridgeTask.target = nil
    BridgeTask.needImplement, BridgeTask.needFluid = nil, nil
    BridgeTask.needPetrol, BridgeTask.needAshTool = nil, nil
    BridgeTask.needCut = nil
    BridgeTask.clearNeedCut = nil
    BridgeTask.cleanApplied = {}
    BridgeTask.chargeCleanSpend()
    BridgeTask.cleanStowPending = false
    BridgeTask.tools = {}
    BridgeTask.toolsAt = {}
    BridgeTask.cleanGearCache = {}
    BridgeTask.cleanGearAt = {}
    BridgeTask.cleanKindCache, BridgeTask.cleanClassKey, BridgeTask.cleanClassAt, BridgeTask.cleanWallCache = nil, nil, nil, nil
    BridgeTask.plantKindCache, BridgeTask.plantKindKey, BridgeTask.plantKindAt = nil, nil, nil
    BridgeTask.danger, BridgeTask.dangerAt = nil, nil
    BridgeTask.washSink = nil
    BridgeTask.washPhase = nil
    BridgeTask.washSince = 0
    BridgeTask.washTicks = nil
    BridgeTask.fillSink = nil
    BridgeTask.fillPhase = nil
    BridgeTask.fillItems = nil
    BridgeTask.fillItem = nil
    BridgeTask.fillIndex = nil
    BridgeTask.fillTicks = nil
    BridgeTask.fillAmount = nil
    BridgeTask.emptyItems = nil
    BridgeTask.emptyItem = nil
    BridgeTask.emptyIndex = nil
    BridgeTask.emptyTicks = nil
    BridgeTask.clearCorpseState()
    BridgeTask.chopRest = false
    BridgeTask.chopRestSitAt = nil
    BridgeTask.chopResumeAt = nil
    BridgeTask.lootList = nil
    BridgeTask.lootIdx = nil
    BridgeTask.lootPending = nil
    BridgeTask.lootPendingAt = nil
    BridgeTask.lootAct = nil
    BridgeTask.lootSrc = nil
    BridgeTask.lootSettled = false
    BridgeTask.lootNextAt = nil
    BridgeTask.lootFullSaid = false
    BridgeTask.lootTook = 0
    BridgeTask.lootNoRoom = 0
    BridgeTask.lootFull = false
    BridgeTask.layPlan = nil
    BridgeTask.layUp = nil
    BridgeTask.laySleep = false
    BridgeTask.layAnim = nil
    BridgeTask.layAnimSeen = false
    BridgeTask.layHintSaid = false
    BridgeTask.layCloseAt = nil
    BridgeTask.layFromX, BridgeTask.layFromY, BridgeTask.laySlideAt = nil, nil, nil
    restoreForcedWalk()
    if body ~= nil then pcall(endCleanHands, body) end
    if body ~= nil then pcall(stopCleanSound, body) end
    if body ~= nil then pcall(restoreHands, body) end
    if body ~= nil then pcall(function() BridgeMove.stopPath(body) end) end
    if reason ~= "mode" and Bridge.setMode ~= nil then
        local mode = "follow"
        if def ~= nil and def.restoreMode == true then mode = BridgeTask.prevMode or "follow" end
        Bridge.setMode(mode)
    end
    if reason == "danger" then Bridge.speak("JobDanger")
    elseif reason == "noAxe" then Bridge.speak("JobNoAxe")
    elseif reason == "noSupplies" then BridgeTask.speakMissing(ckind) end
    log("cancel " .. tostring(reason))
    return "cancelled"
end

function BridgeTask.finish()
    if not BridgeTask.active then return "idle" end
    BridgeTask.chargeCleanSpend()
    local body = Bridge.body
    local clearNeed = BridgeTask.clearNeedCut == true
    BridgeTask.clearNeedCut = nil
    local finishKind = BridgeTask.kind
    local def = BridgeTask.kind ~= nil and BridgeTask.kinds[BridgeTask.kind] or nil
    if def ~= nil and def.leave ~= nil then pcall(def.leave, body) end
    local prev = BridgeTask.prevMode or "follow"
    BridgeTask.active = false
    BridgeTask.state = "idle"
    BridgeTask.kind = nil
    BridgeTask.body = nil
    BridgeTask.queue = {}
    BridgeTask.current = nil
    BridgeTask.phase = nil
    BridgeTask.cleanStowPending = false
    BridgeTask.washSink = nil
    BridgeTask.washPhase = nil
    BridgeTask.washSince = 0
    BridgeTask.washTicks = nil
    BridgeTask.fillSink = nil
    BridgeTask.fillPhase = nil
    BridgeTask.fillItems = nil
    BridgeTask.fillItem = nil
    BridgeTask.fillIndex = nil
    BridgeTask.fillTicks = nil
    BridgeTask.fillAmount = nil
    BridgeTask.emptyItems = nil
    BridgeTask.emptyItem = nil
    BridgeTask.emptyIndex = nil
    BridgeTask.emptyTicks = nil
    BridgeTask.chopRest = false
    BridgeTask.chopRestSitAt = nil
    BridgeTask.chopResumeAt = nil
    BridgeTask.info = "done"
    Bridge.target = nil
    local wasLootFull = BridgeTask.lootFull == true
    local wasGrabOnly = BridgeTask.grabOnly == true
    BridgeTask.lootList = nil
    BridgeTask.lootIdx = nil
    BridgeTask.lootPending = nil
    BridgeTask.lootPendingAt = nil
    BridgeTask.lootAct = nil
    BridgeTask.lootSrc = nil
    BridgeTask.lootSettled = false
    BridgeTask.lootNextAt = nil
    BridgeTask.lootFullSaid = false
    BridgeTask.lootTook = 0
    BridgeTask.lootNoRoom = 0
    BridgeTask.lootFull = false
    if body ~= nil then pcall(function() BridgeMove.stopPath(body) end) end
    if Bridge.setMode ~= nil then Bridge.setMode(prev) end
    if body ~= nil then pcall(endCleanHands, body) end
    if body ~= nil then pcall(stopCleanSound, body) end
    if body ~= nil then pcall(restoreHands, body) end


    local needs = BridgeTask.cleanNeedsTable(
        BridgeTask.needImplement, BridgeTask.needFluid,
        BridgeTask.needPetrol, BridgeTask.needAshTool, BridgeTask.needCut)
    BridgeTask.needImplement, BridgeTask.needFluid = nil, nil
    BridgeTask.needPetrol, BridgeTask.needAshTool = nil, nil
    BridgeTask.needCut = nil
    BridgeTask.clearCorpseState()
    restoreForcedWalk()
    local needText = nil
    if needs.implement or needs.fluid or needs.petrol or needs.ash or needs.cut then
        needText = BridgeTask.cleanNeedText(needs, (BridgeTask.doneCount or 0) > 0 and "partial" or "need")
    end


    if clearNeed then
        Bridge.speak((BridgeTask.doneCount or 0) > 0 and "JobPartialNeedCutTool" or "JobNeedCutTool")
    elseif needText ~= nil then
        Bridge.speakText(needText)
    elseif (BridgeTask.failCount or 0) > 0 then

        if (BridgeTask.doneCount or 0) > 0 then
            Bridge.speak("JobPartialUnreachable")
        elseif not BridgeTask.spokeUnreachable then

            Bridge.speak(BridgeTask.unreachableKey(BridgeTask.blockedReason))
        elseif noPathKey(BridgeTask.blockedReason) ~= "JobNoPath" then


            Bridge.speak("JobNoPath")
        end
    else
        if finishKind == "sit" or finishKind == "lay" or finishKind == "exercise" or finishKind == "washSink"
                or finishKind == "fillWater" or finishKind == "emptyFluid" or finishKind == "pryDoor"
                or finishKind == "shower" then
        elseif wasLootFull then
            Bridge.speak("JobLootFull")
        elseif wasGrabOnly then
        else
            Bridge.speak("JobDone")
        end
    end
    log("finished, restored mode=" .. tostring(prev) .. " done=" .. tostring(BridgeTask.doneCount) .. " failed=" .. tostring(BridgeTask.failCount))
    return "done"
end






function BridgeTask.progress()
    if not BridgeTask.active or BridgeTask.state ~= "running" then return nil end
    local t = Bridge.time
    if BridgeTask.phase == "scrub" and BridgeTask.scrubStart ~= nil then
        local span = BridgeTask.cleanSpan or BridgeTask.SCRUB_TIME or 1
        if span <= 0 then span = 1 end
        local p = (t - BridgeTask.scrubStart) * ffMult() / span
        if p < 0 then p = 0 elseif p > 1 then p = 1 end
        return p
    end
    if BridgeTask.washPhase == "washing" and BridgeTask.washSince ~= nil then
        local span = BridgeTask.washTicks or 420
        if span <= 0 then span = 1 end
        local p = (t - BridgeTask.washSince) * ffMult() / span
        if p < 0 then p = 0 elseif p > 1 then p = 1 end
        return p
    end
    if BridgeTask.fillPhase == "filling" and BridgeTask.fillSince ~= nil and BridgeTask.fillTicks ~= nil then
        local span = BridgeTask.fillTicks
        if span <= 0 then span = 1 end
        local p = (t - BridgeTask.fillSince) * ffMult() / span
        if p < 0 then p = 0 elseif p > 1 then p = 1 end
        return p
    end
    if BridgeTask.emptyTicks ~= nil and BridgeTask.emptySince ~= nil then
        local span = BridgeTask.emptyTicks
        if span <= 0 then span = 1 end
        local p = (t - BridgeTask.emptySince) * ffMult() / span
        if p < 0 then p = 0 elseif p > 1 then p = 1 end
        return p
    end
    if BridgeTask.phase == "pry" and BridgeTask.swingStart ~= nil then
        local span = BridgeTask.PRY_TIME or 190
        if span <= 0 then span = 1 end
        local p = (t - BridgeTask.swingStart) * ffMult() / span
        if p < 0 then p = 0 elseif p > 1 then p = 1 end
        return p
    end
    if BridgeTask.kind == "shower" and BridgeTask.showerPhase == "washing"
            and BridgeTask.showerWashFrac ~= nil then
        local frac = nil
        pcall(function() frac = BridgeTask.showerWashFrac() end)
        if frac ~= nil then return frac end
    end
    return nil
end

function BridgeTask.update(body)
    if not BridgeTask.active then return false end
    if body == nil or Bridge.body ~= body or BridgeTask.body ~= body then
        BridgeTask.reset()
        return false
    end
    if BridgeTask.state ~= "running" then return false end

    local def = BridgeTask.kinds[BridgeTask.kind]
    if def == nil or def.update == nil then
        BridgeTask.cancel("error")
        return false
    end
    local fighting = false
    pcall(function()
        fighting = BridgeFight ~= nil and (BridgeFight.target ~= nil or BridgeFight.state ~= "idle")
    end)
    if fighting then
        BridgeTask.cancel("danger")
        return false
    end
    if BridgeTask.danger == nil
            or (Bridge.tick - (BridgeTask.dangerAt or -99999)) >= 6 then
        BridgeTask.dangerAt = Bridge.tick
        BridgeTask.danger = BridgeTask.dangerNear(body, def.dangerRadius) == true
    end
    if BridgeTask.danger then
        BridgeTask.cancel("danger")
        return false
    end

    pcall(function() BridgeMove.closeBehind(body) end)
    local ok, res = pcall(def.update, body)
    if not ok then
        BridgeTask.info = "error " .. tostring(res)
        warn("job error: " .. tostring(res))
        BridgeTask.cancel("error")
        return false
    end

    pcall(function()
        if BridgeProgress ~= nil and BridgeTask.progress ~= nil then
            local p = BridgeTask.progress()
            if p ~= nil then BridgeProgress.show(p) end
        end
    end)
    return res
end


local function ownerNear(body, range)
    local d = nil
    pcall(function()
        local red = BridgeData.owner()
        if red ~= nil and body ~= nil then
            local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
            d = math.sqrt(dx * dx + dy * dy)
        end
    end)
    return d ~= nil and d <= (range or 20)
end




local function sitDown(body)
    pcall(function()
        if tostring(body:getBumpType()) ~= "Sit" then body:setBumpType("Sit") end
    end)
end
local function standUp(body)
    pcall(function()
        if tostring(body:getBumpType()) == "Sit" then body:setBumpType("") end
    end)
end




function BridgeTask.chopBeginRest(body)
    if BridgeFight == nil or (BridgeFight.fatigue or 0) < BridgeTask.CHOP_REST_AT then return false end
    BridgeTask.chopRest = true
    BridgeTask.chopRestSitAt = Bridge.time + BridgeTask.CHOP_REST_SIT_DELAY
    BridgeTask.swingStart = nil
    BridgeTask.clearChop(body)
    pcall(function() BridgeMove.stopPath(body) end)
    BridgeTask.info = "winded"
    if ownerNear(body, BridgeTask.CHOP_REST_SAY_RANGE) then
        pcall(function()
            if BridgeMoments ~= nil then
                BridgeMoments.say("EvWinded", BridgeTask.CHOP_REST_SAY_COOLDOWN, true, "ChopRest")
            end
        end)
    end
    return true
end

BridgeTask.kinds.chopTree = {}

function BridgeTask.kinds.chopTree.available(body)
    if BridgeTask.TREECUTTING_ENABLED ~= 1 then return false end
    if BridgeTask.findAxe(body) == nil then return false end
    return true
end


function BridgeTask.kinds.chopTree.missing(body)
    if BridgeTask.findAxe(body) == nil then return "axe" end
    return nil
end

function BridgeTask.kinds.chopTree.update(body)
    if BridgeTask.TREECUTTING_ENABLED ~= 1 then return BridgeTask.finish() end



    if BridgeTask.chopRest then
        pcall(function() BridgeMove.stopPath(body) end)

        if Bridge.time < (BridgeTask.chopRestSitAt or 0) then
            BridgeTask.info = "catching her breath"
            return true
        end
        sitDown(body)


        pcall(function()
            if BridgeFight ~= nil and BridgeFight.rest ~= nil then BridgeFight.rest(false, true) end
        end)
        local f = 0
        pcall(function() f = tonumber(BridgeFight and BridgeFight.fatigue) or 0 end)
        BridgeTask.info = string.format("resting %d%%", math.floor((1 - f) * 100 + 0.5))
        if f <= (1 - BridgeTask.CHOP_RESUME_STAMINA) then
            BridgeTask.chopRest = false
            standUp(body)
            BridgeTask.chopResumeAt = Bridge.time + BridgeTask.CHOP_RESUME_DELAY
            BridgeTask.info = "getting up"
            if ownerNear(body, BridgeTask.CHOP_REST_SAY_RANGE) then
                pcall(function()
                    if BridgeMoments ~= nil then
                        BridgeMoments.say("EvRested", BridgeTask.CHOP_REST_SAY_COOLDOWN, true, "ChopRested")
                    end
                end)
            end
        end
        return true
    end


    if BridgeTask.chopResumeAt ~= nil then
        if Bridge.time < BridgeTask.chopResumeAt then
            pcall(function() BridgeMove.stopPath(body) end)
            BridgeTask.info = "getting back to it"
            return true
        end
        BridgeTask.chopResumeAt = nil
        BridgeTask.since = Bridge.time
        BridgeTask.progressAt = Bridge.time
    end



    if BridgeFight ~= nil and (BridgeFight.fatigue or 0) >= BridgeTask.CHOP_REST_AT
            and (BridgeTask.current ~= nil or #BridgeTask.queue > 0) then
        if BridgeTask.chopBeginRest(body) then return true end
    end

    local target = BridgeTask.current
    if target == nil then
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        target = table.remove(BridgeTask.queue, 1)
        if resolveTree(target) == nil then
            BridgeTask.info = "stale target"
            if #BridgeTask.queue == 0 then return BridgeTask.finish() end
            return true
        end
        BridgeTask.current = target
        BridgeTask.phase = "walk"
        BridgeTask.swings = 0
        BridgeTask.since = Bridge.time
        BridgeTask.spot = nil
        BridgeTask.swingStart = nil
        BridgeTask.still = 0
        BridgeTask.checkX = nil
        BridgeTask.animHold = 0
        BridgeTask.bestD = nil
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
    end

    local tree = resolveTree(target)
    if tree ~= nil and Bridge.tick % 60 == 0 then
        log(string.format("tree target %d,%d enclosure=%s", target.x, target.y,
            tostring(BridgeTask.enclosureKeyOf(getCell():getGridSquare(target.x, target.y, target.z)))))
    end
    if tree == nil then
        BridgeTask.clearChop(body)
        BridgeTask.info = "tree down"
        BridgeTask.markDone()
        BridgeTask.current = nil
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        return true
    end

    local axe = BridgeTask.cachedTool(body, "axe", BridgeTask.findAxe, BridgeTask.toolOk)
    if axe == nil then
        BridgeTask.cancel("noAxe")
        return false
    end
    if body:getPrimaryHandItem() ~= axe then


        ensureInMain(body, axe)
        pcall(function()
            body:setPrimaryHandItem(axe)
            if axe:isTwoHandWeapon() or axe:isRequiresEquippedBothHands() then body:setSecondaryHandItem(axe) end
        end)
    end

    local reach = BridgeTask.CHOP_RANGE
    if BridgeTask.phase == "chop" then reach = BridgeTask.CHOP_RANGE + 1.0 end
    local walk, why = BridgeTask.walkTo(body, target, reach)
    if walk == "unreachable" then return BridgeTask.dropTarget(why) end
    if walk == "walking" then return true end

    if BridgeTask.phase ~= "chop" then
        BridgeTask.phase = "chop"
        BridgeTask.since = Bridge.time
        BridgeTask.swings = 0
        BridgeTask.swingStart = nil
        BridgeTask.swingHit = false
        pcall(function() BridgeMove.stopPath(body) end)
        BridgeTask.info = "chopping"
        log(string.format("arrived at tree %d,%d", target.x, target.y))
    end


    if (Bridge.time - (BridgeTask.lastChopSayCheck or 0)) >= SECOND then
        BridgeTask.lastChopSayCheck = Bridge.time
        if (Bridge.time - (BridgeTask.lastChopSay or -99999)) >= BridgeTask.CHOP_SAY_COOLDOWN
                and ZombRand(100) < 30 then
            local said = false
            pcall(function()
                said = BridgeMoments ~= nil
                    and BridgeMoments.say("EvChopping", BridgeTask.CHOP_SAY_COOLDOWN, true, "Chopping") == true
            end)
            if said then BridgeTask.lastChopSay = Bridge.time end
        end
    end

    if (Bridge.time - (BridgeTask.since or Bridge.time)) > BridgeTask.CHOP_TIMEOUT then
        BridgeTask.clearChop(body)
        BridgeTask.info = "skip stubborn tree"
        return BridgeTask.dropTarget(nil)
    end
    pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)

    local bump = ""
    pcall(function() bump = tostring(body:getBumpType()) end)
    if BridgeTask.swingStart == nil then



        if (BridgeTask.animHold or 0) > 0 then
            BridgeTask.animHold = BridgeTask.animHold - 1
            pcall(function() body:setVariable("BumpAnimFinished", true) end)
            pcall(function() body:changeState(ZombieIdleState.instance()) end)
            pcall(function() body:setBumpType("") end)
            BridgeTask.info = "resettling chop"
            return true
        end
        BridgeTask.swingStart = Bridge.time
        BridgeTask.swingHit = false
        local at, len = nil, nil
        pcall(function() len, at = BridgeFight.swingFrames(axe) end)
        BridgeTask.attackAt = at or BridgeTask.ATTACK_AT
        BridgeTask.swingLen = len or BridgeTask.SWING_MAX

        BridgeTask.chopAlt = not BridgeTask.chopAlt
        local anim = BridgeTask.chopAlt and BridgeTask.CHOP_ANIM_B or BridgeTask.CHOP_ANIM
        BridgeTask.chopCurrent = anim
        pcall(function() body:setVariable("NotAloneHitNow", false) end)
        pcall(function()
            body:setVariable("BumpAnimFinished", false)
            body:setBumpType(anim)
        end)
        return true
    end

    local age = (Bridge.time - BridgeTask.swingStart) * ffMult()
    local mark = false
    pcall(function() mark = body:getVariableBoolean("NotAloneHitNow") end)



    if not BridgeTask.swingHit and not mark and
            age >= (BridgeTask.attackAt or BridgeTask.ATTACK_AT) then
        local fin = false
        pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
        local playing = false
        pcall(function()
            local b = tostring(body:getBumpType())
            playing = body:getActionStateName() == "bumped"
                and (b == BridgeTask.CHOP_ANIM or b == BridgeTask.CHOP_ANIM_B)
        end)
        if fin or not playing then
            pcall(function() body:setVariable("BumpAnimFinished", true) end)
            pcall(function() body:changeState(ZombieIdleState.instance()) end)
            pcall(function() body:setBumpType("") end)
            BridgeTask.animHold = 2
            BridgeTask.swingStart = nil
            BridgeTask.info = "chop anim lost, restarting"
            return true
        end
    end
    if not BridgeTask.swingHit and (mark or age >= (BridgeTask.attackAt or BridgeTask.ATTACK_AT)) then
        BridgeTask.swingHit = true
        pcall(function() body:setVariable("NotAloneHitNow", false) end)
        if isClient() then


            pcall(function()
                local full = nil
                pcall(function() full = axe ~= nil and axe:getFullType() or nil end)
                sendClientCommand(BridgeData.owner(), "Bridge", "chopHit",
                    { x = target.x, y = target.y, z = target.z, axe = full })
            end)
            pcall(function() tree:WeaponHitEffects(body, axe) end)
        else
            pcall(function() tree:WeaponHit(body, axe) end)
        end

        pcall(function()
            if BridgeFight ~= nil and BridgeFight.tireTree ~= nil then
                BridgeFight.tireTree(axe, body)
            end
        end)
        BridgeTask.swings = (BridgeTask.swings or 0) + 1
        BridgeTask.info = "swing " .. tostring(BridgeTask.swings)


        pcall(function()
            if BridgeSkills ~= nil and BridgeSkills.add ~= nil then
                BridgeSkills.add("Strength", 2, "chop")
            end
        end)



        pcall(function()
            if BridgeSkills ~= nil and BridgeSkills.rollMaintenance ~= nil then
                local mxp = BridgeSkills.rollMaintenance(axe)
                if mxp > 0 then BridgeSkills.add("Maintenance", mxp, "chop") end
            end
        end)
    end

    local fin = false
    pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
    if (age > BridgeTask.MIN_SWING and (fin or bump ~= (BridgeTask.chopCurrent or BridgeTask.CHOP_ANIM)))
            or age >= BridgeTask.SWING_MAX then
        BridgeTask.swingStart = nil
    end
    return true
end

function BridgeTask.kinds.chopTree.leave(body)
    BridgeTask.clearChop(body)
end

BridgeTask.kinds.pryDoor = {}
BridgeTask.kinds.pryDoor.dangerRadius = BridgeTask.PRY_DANGER_RADIUS

function BridgeTask.kinds.pryDoor.available(body)
    if BridgeTask.PRY_ENABLED ~= 1 then return false end
    if BridgeTask.findCrowbar(body) == nil then return false end
    return true
end

function BridgeTask.kinds.pryDoor.missing(body)
    if BridgeTask.findCrowbar(body) == nil then return "crowbar" end
    return nil
end

function BridgeTask.kinds.pryDoor.update(body)
    if BridgeTask.PRY_ENABLED ~= 1 then return BridgeTask.finish() end

    local target = BridgeTask.current
    if target == nil then
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        target = table.remove(BridgeTask.queue, 1)
        if BridgeTask.resolvePryDoor(target) == nil then
            BridgeTask.info = "stale target"
            if #BridgeTask.queue == 0 then return BridgeTask.finish() end
            return true
        end
        BridgeTask.current = target
        BridgeTask.phase = "walk"
        BridgeTask.since = Bridge.time
        BridgeTask.spot = nil
        BridgeTask.swingStart = nil
        BridgeTask.still = 0
        BridgeTask.checkX = nil
        BridgeTask.animHold = 0
        BridgeTask.bestD = nil
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
        BridgeTask.pryDrained = 0
        BridgeTask.pryNoiseAt = nil
    end

    local door = BridgeTask.resolvePryDoor(target)
    if door == nil then
        BridgeTask.info = "door no longer pryable"
        BridgeTask.current = nil
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        return true
    end

    local crowbar = BridgeTask.cachedTool(body, "crowbar", BridgeTask.findCrowbar, BridgeTask.toolOk)
    if crowbar == nil then
        BridgeTask.cancel("noSupplies")
        return false
    end
    local crowbarTwo = false
    pcall(function()
        crowbarTwo = crowbar:isTwoHandWeapon() == true or crowbar:isRequiresEquippedBothHands() == true
    end)
    local offWanted = crowbarTwo and crowbar or nil
    local handsOk = false
    pcall(function()
        handsOk = body:getPrimaryHandItem() == crowbar and body:getSecondaryHandItem() == offWanted
    end)
    if not handsOk then
        ensureInMain(body, crowbar)
        pcall(function()
            body:setPrimaryHandItem(crowbar)
            body:setSecondaryHandItem(offWanted)
            body:resetModelNextFrame()
        end)
        pcall(function() BridgeInventory.redress(body) end)
    end

    local walk, why = BridgeTask.walkTo(body, target, BridgeTask.PRY_RANGE, nil, true)
    if walk == "unreachable" then return BridgeTask.dropTarget(why) end
    if walk == "walking" then return true end

    if BridgeTask.phase ~= "pry" then
        BridgeTask.phase = "pry"
        BridgeTask.since = Bridge.time
        BridgeTask.swingStart = nil
        BridgeTask.animHold = 0
        BridgeTask.pryDrained = 0
        BridgeTask.pryNoiseAt = Bridge.time
        pcall(function() BridgeMove.stopPath(body) end)
        BridgeTask.info = "prying"
    end

    pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)

    if BridgeTask.swingStart == nil then
        if (BridgeTask.animHold or 0) > 0 then
            BridgeTask.animHold = BridgeTask.animHold - 1
            pcall(function() body:setVariable("BumpAnimFinished", true) end)
            pcall(function() body:changeState(ZombieIdleState.instance()) end)
            pcall(function() body:setBumpType("") end)
            BridgeTask.info = "resettling pry"
            return true
        end
        BridgeTask.swingStart = Bridge.time
        pcall(function()
            body:setVariable("BumpAnimFinished", false)
            body:setBumpType(BridgeTask.PRY_ANIM)
        end)
        BridgeSound.sfx(body, BridgeTask.PRY_SOUND_START)
        return true
    end

    local age = (Bridge.time - BridgeTask.swingStart) * ffMult()

    if BridgeFight ~= nil then
        local span = BridgeTask.PRY_TIME or 190
        if span <= 0 then span = 1 end
        local frac = age / span
        if frac > 1 then frac = 1 end
        local want = (BridgeTask.PRY_STAMINA or 0) * frac
        local have = BridgeTask.pryDrained or 0
        if want > have then
            pcall(function()
                BridgeFight.fatigue = math.min(1, (BridgeFight.fatigue or 0) + (want - have))
            end)
            BridgeTask.pryDrained = want
        end
    end

    if (Bridge.time - (BridgeTask.pryNoiseAt or -99999)) >= BridgeTask.PRY_NOISE_EVERY then
        BridgeTask.pryNoiseAt = Bridge.time
        pcall(function() addSound(body, target.x, target.y, target.z, BridgeTask.PRY_NOISE_RADIUS, 10) end)
    end

    if age >= BridgeTask.SCRUB_GUARD then
        local playing = false
        pcall(function()
            playing = body:getActionStateName() == "bumped"
                and tostring(body:getBumpType()) == BridgeTask.PRY_ANIM
        end)
        if not playing then
            pcall(function() body:setVariable("BumpAnimFinished", true) end)
            pcall(function() body:changeState(ZombieIdleState.instance()) end)
            pcall(function() body:setBumpType("") end)
            BridgeTask.animHold = 2
            BridgeTask.swingStart = nil
            BridgeTask.info = "pry anim lost, restarting"
            return true
        end
    end

    local fin = false
    pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
    if not fin and age < BridgeTask.PRY_TIME then
        BridgeTask.info = "prying"
        return true
    end
    BridgeTask.swingStart = nil

    local strength = 0
    pcall(function()
        if BridgeSkills ~= nil and BridgeSkills.level ~= nil then
            strength = tonumber(BridgeSkills.level("Strength")) or 0
        else
            strength = tonumber(body:getPerkLevel(Perks.Strength)) or 0
        end
    end)
    local success = false
    pcall(function()
        local chance = BridgeTask.PRY_CHANCE_FLOOR
            + (1 - BridgeTask.PRY_CHANCE_FLOOR) * (strength / (strength + BridgeTask.PRY_CHANCE_K))
        success = ZombRand(100) < chance * 100
    end)

    if success then
        pcall(function()
            door:setLocked(false)
            door:setLockedByKey(false)
        end)
        if BridgeMove ~= nil and BridgeMove.openDoor ~= nil then
            pcall(function() BridgeMove.openDoor(body, door) end)
        end
        BridgeSound.sfx(body, BridgeTask.PRY_SOUND_SUCCESS)
        pcall(function() addSound(body, target.x, target.y, target.z, BridgeTask.PRY_NOISE_RADIUS, 10) end)
        Bridge.speak("PrySuccess")
        if isClient() then
            pcall(function()
                sendClientCommand(BridgeData.owner(), "Bridge", "pryDoor",
                    { x = target.x, y = target.y, z = target.z })
            end)
        end
    else
        BridgeSound.sfx(body, BridgeTask.PRY_SOUND_FAIL)
        pcall(function() addSound(body, target.x, target.y, target.z, BridgeTask.PRY_NOISE_RADIUS, 10) end)
        Bridge.speak("PryFail")
    end

    BridgeTask.current = nil
    if #BridgeTask.queue == 0 then return BridgeTask.finish() end
    return true
end

function BridgeTask.kinds.pryDoor.leave(body)
    if body == nil then return end
    pcall(function()
        body:setVariable("BumpAnimFinished", true)
        body:changeState(ZombieIdleState.instance())
        body:setBumpType("")
    end)
end

BridgeTask.kinds.cleanUp = {}
BridgeTask.kinds.cleanUp.unavailableSpeech = "JobNoSupplies"





function BridgeTask.kinds.cleanUp.available(body)
    return true
end

function BridgeTask.kinds.cleanUp.missing(body)
    if BridgeTask.findCleanStainItem(body) == nil
            and BridgeTask.findAshTool(body) == nil
            and BridgeTask.findCutTool(body) == nil then
        return "implement"
    end
    return nil
end

function BridgeTask.kinds.cleanUp.update(body)
    if BridgeTask.CLEANING_ENABLED ~= 1 then return BridgeTask.finish() end


    if BridgeMove ~= nil then BridgeMove.forcedWalk = "Walk" end



    if BridgeTask.cleanStowPending then
        local moving = false
        pcall(function() moving = BridgeWeapon ~= nil and BridgeWeapon.busy() end)
        if moving then
            BridgeTask.info = "putting weapon away"
            return true
        end
        BridgeTask.cleanStowPending = false
    end

    local target = BridgeTask.current
    if target == nil then
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        local bx, by = body:getX(), body:getY()
        local bestI, bestD = nil, nil
        local bestAnyI, bestAnyD = nil, nil
        local bodyKey = BridgeTask.enclosureKey(body)
        local i = 1
        while i <= #BridgeTask.queue do
            local t = BridgeTask.queue[i]
            local sq = getCell():getGridSquare(t.x, t.y, t.z)
            local d = (bx - t.x) ^ 2 + (by - t.y) ^ 2
            if bestAnyD == nil or d < bestAnyD then bestAnyD = d; bestAnyI = i end
            if bodyKey == nil or BridgeTask.enclosureKeyOf(sq) == bodyKey then
                if bestD == nil or d < bestD then bestD = d; bestI = i end
            end
            i = i + 1
        end
        local must = BridgeTask.mustTarget
        if must ~= nil then
            BridgeTask.mustTarget = nil
            for j = 1, #BridgeTask.queue do
                local t = BridgeTask.queue[j]
                if t.x == must.x and t.y == must.y and t.z == must.z then bestI = j break end
            end
        end
        if bestI == nil then bestI, bestD = bestAnyI, bestAnyD end
        if bestI == nil then
            BridgeTask.info = "nothing reachable"
            return BridgeTask.finish()
        end
        target = table.remove(BridgeTask.queue, bestI)
        BridgeTask.current = target
        BridgeTask.phase = "walk"
        BridgeTask.swings = 0
        BridgeTask.since = Bridge.time
        BridgeTask.spot = nil
        BridgeTask.swingStart = nil
        BridgeTask.still = 0
        BridgeTask.checkX = nil
        BridgeTask.animHold = 0
        BridgeTask.animLogged = false
        BridgeTask.cleanRounds = 0
        BridgeTask.cleanApplied = {}
        BridgeTask.cleanKindCache, BridgeTask.cleanClassKey, BridgeTask.cleanClassAt, BridgeTask.cleanWallCache = nil, nil, nil, nil
        BridgeTask.vineObject = nil
        BridgeTask.chargeCleanSpend()
        BridgeTask.bestD = nil
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
    end

    local square = getCell():getGridSquare(target.x, target.y, target.z)
    local targetKey = target.x .. "," .. target.y .. "," .. target.z
    if BridgeTask.cleanClassKey ~= targetKey
            or (Bridge.tick - (BridgeTask.cleanClassAt or -99999)) >= 30 then
        BridgeTask.cleanClassKey = targetKey
        BridgeTask.cleanClassAt = Bridge.tick
        BridgeTask.cleanKindCache = BridgeTask.cleanCanDo(body, square, BridgeTask.cleanApplied)
        BridgeTask.cleanWallCache = nil
        if BridgeTask.cleanKindCache == "blood" or BridgeTask.cleanKindCache == "grime" then
            BridgeTask.cleanWallCache = stainIsWall(square)
        end
        if Bridge.tick % 60 == 0 then
            log(string.format("target %d,%d enclosure=%s", target.x, target.y, tostring(BridgeTask.enclosureKeyOf(square))))
        end
    end

    local kind = BridgeTask.cleanKindCache
    if kind == nil then
        BridgeTask.recordCleanNeeds(body, square)
        BridgeTask.clearChop(body)
        pcall(stopCleanSound, body)
        BridgeTask.info = "clean"
        BridgeTask.current = nil
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        return true
    end
    local tool, cleaner = BridgeTask.cleanGear(body, kind)

    BridgeTask.cleanSpan = (kind == "vine") and BridgeTask.VINE_TIME or BridgeTask.SCRUB_TIME





    if tool ~= nil or kind == "glass" or kind == "window" then
        beginCleanHands(body, kind, tool, cleaner)
    end

    local reach = BridgeTask.CLEAN_RANGE

    if kind == "window" or kind == "glass" then reach = 1.0 end
    if BridgeTask.phase == "scrub" then reach = reach + 1.0 end
    local walk, why = BridgeTask.walkTo(body, target, reach)
    if walk == "unreachable" then return BridgeTask.dropTarget(why) end
    if walk == "walking" then return true end

    if BridgeTask.phase ~= "scrub" then
        BridgeTask.phase = "scrub"
        BridgeTask.since = Bridge.time
        BridgeTask.scrubStart = Bridge.time
        BridgeTask.swings = 0
        BridgeTask.swingStart = nil
        BridgeTask.swingHit = false
        pcall(function() BridgeMove.stopPath(body) end)
        BridgeTask.info = "scrubbing"
        cleanSound(body, square, kind, tool)
        if kind == "vine" then

            pcall(function()
                addSound(body, body:getX(), body:getY(), body:getZ(), 20, 10)
            end)
        end
        log(string.format("arrived at clean-up %d,%d kind=%s", target.x, target.y, tostring(kind)))
    end

    if (Bridge.time - (BridgeTask.since or Bridge.time)) > BridgeTask.SCRUB_TIMEOUT then
        BridgeTask.clearChop(body)
        BridgeTask.info = "skip stubborn stain"
        return BridgeTask.dropTarget(nil)
    end
    if kind == "vine" then

        if BridgeTask.vineObject == nil and BridgeClean ~= nil then
            BridgeTask.vineObject = BridgeClean.squareVine(square)
        end
        local vineObj = BridgeTask.vineObject
        if vineObj ~= nil then
            pcall(function() body:faceThisObject(vineObj) end)
        else
            pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)
        end
    else
        pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)
    end


    local wall = false
    if kind == "blood" or kind == "grime" then
        wall = BridgeTask.cleanWallCache == true
    elseif kind == "graffiti" then
        wall = true
    end
    local anim
    if kind == "window" then
        anim = BridgeTask.LOOT_MID
    elseif kind == "glass" then
        anim = BridgeTask.LOOT_LOW
    elseif kind == "ashes" then
        anim = ashCleanAnim(tool)
    elseif kind == "vine" then
        anim = vineCleanAnim(tool)
    elseif kind == "grime" and isBroom(tool) and not wall then


        anim = BridgeTask.RAKE_ANIM
    else
        local tbl = wall and BridgeTask.SCRUB_WALL_BY_TOOL or BridgeTask.SCRUB_FLOOR_BY_TOOL
        anim = tbl[implementVariant(tool)]
            or (wall and BridgeTask.SCRUB_WALL_SPONGE or BridgeTask.SCRUB_FLOOR_SPONGE)
    end
    if not BridgeTask.animLogged then
        BridgeTask.animLogged = true
        log(string.format("clean anim=%s kind=%s wall=%s", tostring(anim), tostring(kind), tostring(wall)))
    end




    local cleanEvent = CLEAN_EVENT[kind] or "EvCleaning"
    if (Bridge.time - (BridgeTask.lastCleanSayCheck or 0)) >= SECOND then
        BridgeTask.lastCleanSayCheck = Bridge.time
        if (Bridge.time - (BridgeTask.lastCleanSay or -99999)) >= BridgeTask.CLEAN_SAY_COOLDOWN
                and ZombRand(100) < 30 then
            local said = false
            pcall(function()
                said = BridgeMoments ~= nil
                    and BridgeMoments.say(cleanEvent, BridgeTask.CLEAN_SAY_COOLDOWN, true, "CleanUp") == true
            end)
            if said then BridgeTask.lastCleanSay = Bridge.time end
        end
    end

    local bump = ""
    pcall(function() bump = tostring(body:getBumpType()) end)
    if BridgeTask.swingStart == nil then
        if (BridgeTask.animHold or 0) > 0 then
            BridgeTask.animHold = BridgeTask.animHold - 1
            pcall(function() body:setVariable("BumpAnimFinished", true) end)
            pcall(function() body:changeState(ZombieIdleState.instance()) end)
            pcall(function() body:setBumpType("") end)
            BridgeTask.info = "resettling scrub"
            return true
        end
        BridgeTask.swingStart = Bridge.time
        BridgeTask.swingHit = false
        pcall(function() body:setVariable("NotAloneHitNow", false) end)
        pcall(function()
            body:setVariable("BumpAnimFinished", false)
            body:setBumpType(anim)
        end)
        return true
    end

    local age = (Bridge.time - BridgeTask.swingStart) * ffMult()


    if age >= BridgeTask.SCRUB_GUARD then
        local fin, playing = false, false
        pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
        pcall(function()
            playing = body:getActionStateName() == "bumped"
                and tostring(body:getBumpType()) == anim
        end)
        if not playing then
            pcall(function() body:setVariable("BumpAnimFinished", true) end)
            pcall(function() body:changeState(ZombieIdleState.instance()) end)
            pcall(function() body:setBumpType("") end)
            BridgeTask.animHold = 2
            BridgeTask.swingStart = nil
            BridgeTask.info = "scrub anim lost, restarting"
            return true
        end
        if fin or bump ~= anim then

            BridgeTask.swingStart = nil
        end
    end




    local workTime = BridgeTask.SCRUB_TIME
    if kind == "vine" then workTime = BridgeTask.VINE_TIME end
    if (Bridge.time - (BridgeTask.scrubStart or Bridge.time)) * ffMult() >= workTime then
        applyClean(body, square, kind)
        if kind == "vine" then



            pcall(function() square:playSound("ChopTree") end)
            pcall(function()
                addSound(body, body:getX(), body:getY(), body:getZ(), 20, 1)
            end)
            vineUseEndurance(body, tool)
        end
        BridgeTask.swings = (BridgeTask.swings or 0) + 1
        BridgeTask.info = "clean " .. tostring(kind) .. " " .. tostring(BridgeTask.swings)


        if Bridge ~= nil and Bridge.mp then
            BridgeTask.cleanApplied[kind] = true
        end



        if cleaner ~= nil then
            BridgeTask.noteCleanSpend(cleaner)
        end




        local remaining = BridgeTask.cleanCanDo(body, square, BridgeTask.cleanApplied)
        if remaining == nil then

            BridgeTask.chargeCleanSpend()
            BridgeTask.clearChop(body)
            pcall(stopCleanSound, body)
            BridgeTask.info = "clean"
            BridgeTask.markDone()
            BridgeTask.current = nil
            if #BridgeTask.queue == 0 then return BridgeTask.finish() end
            return true
        end
        BridgeTask.cleanKindCache = remaining
        BridgeTask.cleanClassAt = Bridge.tick
        BridgeTask.cleanWallCache = nil
        if remaining == "blood" or remaining == "grime" then
            BridgeTask.cleanWallCache = stainIsWall(square)
        end


        BridgeTask.cleanRounds = (BridgeTask.cleanRounds or 0) + 1
        if BridgeTask.cleanRounds > 8 then
            BridgeTask.info = "clean round cap"
            return BridgeTask.dropTarget(nil)
        end
        BridgeTask.scrubStart = Bridge.time
        cleanSound(body, square, kind, tool)
    end

    if age >= BridgeTask.SWING_MAX then
        BridgeTask.swingStart = nil
    end
    return true
end

function BridgeTask.kinds.cleanUp.leave(body)
    BridgeTask.clearChop(body)


    if BridgeTask.cleanStowPending then
        BridgeTask.cleanStowPending = false
        if body ~= nil then pcall(function() BridgeWeapon.cancelMove(body) end) end
    end
    if body ~= nil then pcall(endCleanHands, body) end
    if body ~= nil then pcall(stopCleanSound, body) end
    restoreForcedWalk()
    BridgeTask.deferred = {}
end

BridgeTask.kinds.washSink = {}
BridgeTask.kinds.washSink.unavailableSpeech = "AlreadyClean"

local function washWaterOn(sq)
    local obj = nil
    if BridgeWash ~= nil and BridgeWash.waterOn ~= nil then
        pcall(function() obj = BridgeWash.waterOn(sq) end)
    end
    return obj
end

local function washSinkWater(sink, body, scope)
    local avail, tainted = 0, false
    if sink ~= nil then
        pcall(function() tainted = sink:isTaintedWater() == true end)
        if BridgeWash ~= nil and BridgeWash.waterUnits ~= nil then
            pcall(function() avail = BridgeWash.waterUnits(sink) end)
        else
            pcall(function() avail = sink:getFluidAmount() or 0 end)
        end
    end
    local need = nil
    if BridgeWash ~= nil and BridgeWash.waterNeeded ~= nil then
        pcall(function() need = BridgeWash.waterNeeded(body, tainted, scope) end)
    end
    return avail, need, tainted
end

local function washSinkEmote(anim)
    if BridgeSocial ~= nil and BridgeSocial.emote ~= nil then
        pcall(function() BridgeSocial.emote(anim, true, true) end)
    end
end

local function washSinkSound(body, force)
    if body == nil or BridgeTask.WASH_SOUND == nil then return end
    local now = Bridge.time or 0
    if not force and BridgeTask.washSoundAt ~= nil
        and (now - BridgeTask.washSoundAt) < (BridgeTask.WASH_SOUND_EVERY or 120) then
        return
    end
    BridgeTask.washSoundAt = now
    pcall(function() body:playSound(BridgeTask.WASH_SOUND) end)
end

local function washPools(scope)
    if scope == "inventory" then
        return "JobWashInv", "JobWashInvNoSoap", "JobWashInvDone"
    end
    return "JobWashSelf", "JobWashSelfNoSoap", "JobWashSelfDone"
end

local function washSay(pool, fallbackKey)
    if BridgeWash ~= nil and BridgeWash.sayLine ~= nil then
        local ok = pcall(function() BridgeWash.sayLine(pool, fallbackKey) end)
        if ok then return end
    end
    Bridge.speak(fallbackKey)
end

local function washGoLine(scope, body)
    local goPool, noSoapPool = washPools(scope)
    local hasSoap = false
    pcall(function()
        hasSoap = BridgeWash ~= nil and BridgeWash.hasSoap ~= nil and BridgeWash.hasSoap(body)
    end)
    washSay(hasSoap and goPool or noSoapPool, "GoWash")
end

local function washDoneLine(scope)
    local _, _, donePool = washPools(scope)
    washSay(donePool, "Washed")
end

function BridgeTask.kinds.washSink.available(body, scope)
    local ok = false
    pcall(function()
        ok = BridgeWash ~= nil and BridgeWash.dirtyParts ~= nil
            and BridgeWash.dirtyParts(body, scope or "self") > 0
    end)
    return ok
end

function BridgeTask.kinds.washSink.missing(body)
    return nil
end

function BridgeTask.kinds.washSink.update(body)
    local scope = BridgeTask.washScope or "self"
    local sink = BridgeTask.washSink
    if sink == nil then
        local t = BridgeTask.current
        if t ~= nil then
            sink = washWaterOn(getCell():getGridSquare(t.x, t.y, t.z))
            BridgeTask.washSink = sink
        end
    end
    local target = nil
    if sink ~= nil then
        local sq = nil
        pcall(function() sq = sink:getSquare() end)
        if sq ~= nil then target = { x = sq:getX(), y = sq:getY(), z = sq:getZ() } end
    end
    if target == nil then
        Bridge.speak("NoWater")
        return BridgeTask.finish()
    end

    if BridgeTask.washPhase == nil then
        local cleanNow = false
        pcall(function()
            cleanNow = BridgeWash ~= nil and BridgeWash.dirtyParts ~= nil
                and BridgeWash.dirtyParts(body, scope) == 0
        end)
        if cleanNow then
            Bridge.speak("AlreadyClean")
            return BridgeTask.finish()
        end
        local avail, need, tainted = washSinkWater(sink, body, scope)
        local info = "?"
        if BridgeWash ~= nil and BridgeWash.objInfo ~= nil then
            pcall(function() info = BridgeWash.objInfo(sink) end)
        end
        log("wash check scope=" .. tostring(scope) .. " avail=" .. tostring(avail)
            .. " need=" .. tostring(need) .. " tainted=" .. tostring(tainted)
            .. " sink=" .. tostring(info))
        if need ~= nil and need <= 0 then
            Bridge.speak("AlreadyClean")
            return BridgeTask.finish()
        end
        if avail == nil or avail <= 0 then
            Bridge.speakText(getText("IGUI_NotAlone_Say_NotEnoughWater"))
            return BridgeTask.finish()
        end
        BridgeTask.washPhase = "going"
        BridgeTask.washSince = Bridge.time
        washGoLine(scope, body)
        BridgeTask.info = "wash going " .. tostring(scope)
        return true
    end

    if BridgeTask.washPhase == "going" then
        local bath = sink ~= nil and sink.bridgeBath == true
        local res = BridgeTask.walkTo(body, target,
            bath and (BridgeTask.BATH_REACH or 1.5) or (BridgeTask.WASH_REACH or 1), not bath, bath)
        if res == "arrived" then
            pcall(function() BridgeMove.stopPath(body) end)
            Bridge.target = nil
            BridgeTask.washPhase = "greet"
            BridgeTask.washSince = Bridge.time
            BridgeTask.washTicks = nil
            if BridgeWash ~= nil and BridgeWash.washTicks ~= nil then
                pcall(function() BridgeTask.washTicks = BridgeWash.washTicks(body) end)
            end
            washSinkEmote("WipeBrow")
            BridgeTask.info = "wash greet"
            return true
        elseif res == "unreachable" then
            Bridge.speak("CantReachWater")
            return BridgeTask.finish()
        end
        BridgeTask.info = "wash walking"
        return true
    end

    if BridgeTask.washPhase == "greet" then
        if (Bridge.time - (BridgeTask.washSince or Bridge.time)) * ffMult() >= (BridgeTask.WASH_GREET_TICKS or 90) then
            BridgeTask.washPhase = "washing"
            BridgeTask.washSince = Bridge.time
            BridgeTask.washSoundAt = nil
            washSinkSound(body, true)
        end
        return true
    end

    local sq = nil
    pcall(function() sq = sink:getSquare() end)
    if sq == nil then
        Bridge.speak("CantReachWater")
        return BridgeTask.finish()
    end
    pcall(function() body:faceLocationF(sq:getX() + 0.5, sq:getY() + 0.5) end)
    pcall(function()
        if tostring(body:getBumpType()) ~= "washFace" then body:setBumpType("washFace") end
    end)
    washSinkSound(body, false)
    if (Bridge.time - (BridgeTask.washSince or Bridge.time)) * ffMult() >= (BridgeTask.washTicks or 420) then
        local okClean = false
        if BridgeWash ~= nil and BridgeWash.clean ~= nil then
            okClean = true
            local prevDirty = -1
            for pass = 1, (BridgeTask.WASH_PASSES or 12) do
                local d = 0
                pcall(function() d = BridgeWash.dirtyParts(body, scope) end)
                if d <= 0 then break end
                if prevDirty >= 0 and d >= prevDirty then break end
                prevDirty = d
                local okPass = pcall(function() BridgeWash.clean(body, sink, scope) end)
                if not okPass then okClean = false break end
            end
            local leftDirty = -1
            pcall(function() leftDirty = BridgeWash.dirtyParts(body, scope) end)
            log("wash done scope=" .. tostring(scope) .. " dirty=" .. tostring(leftDirty))
        end
        pcall(function() body:setBumpType("") end)
        if okClean then
            washDoneLine(scope)
            washSinkEmote("EmoteYes")
            pcall(function() Bridge.saveOutfit() end)
        else
            Bridge.speak("JobNoPath")
        end
        return BridgeTask.finish()
    end
    BridgeTask.info = "washing"
    return true
end

function BridgeTask.kinds.washSink.leave(body)
    BridgeTask.washSink = nil
    BridgeTask.washPhase = nil
    BridgeTask.washSoundAt = nil
    BridgeTask.washScope = nil
    if body ~= nil then
        pcall(function()
            if tostring(body:getBumpType()) == "washFace" then body:setBumpType("") end
        end)
    end
end


BridgeTask.kinds.fillWater = {}
BridgeTask.kinds.fillWater.unavailableSpeech = "JobFillNothing"

local function fillSay(pool, fallbackKey)
    if BridgeWash ~= nil and BridgeWash.sayLine ~= nil then
        local ok = pcall(function() BridgeWash.sayLine(pool, fallbackKey) end)
        if ok then return end
    end
    Bridge.speak(fallbackKey)
end

local function fillTicksFor(amount)
    local ticks = math.floor((amount or 0) * (BridgeTask.FILL_UNIT_TICKS or 100) + (BridgeTask.FILL_BASE_TICKS or 30))
    local minTicks = BridgeTask.FILL_MIN_TICKS or 60
    if ticks < minTicks then ticks = minTicks end
    return ticks
end

local function fillCurrentItem()
    local list = BridgeTask.fillItems
    local i = BridgeTask.fillIndex
    if list == nil or i == nil then return nil end
    return list[i + 1]
end

local function fillSoundStop(body)
    local emitter = BridgeTask.fillSoundEmitter
    local snd = BridgeTask.fillSoundHandle
    BridgeTask.fillSoundEmitter, BridgeTask.fillSoundHandle = nil, nil
    if snd == nil then return end
    if emitter ~= nil then
        pcall(function() emitter:stopSound(snd) end)
        return
    end
    if body ~= nil then
        local playing = false
        pcall(function() playing = body:getEmitter():isPlaying(snd) == true end)
        if playing then pcall(function() body:stopOrTriggerSound(snd) end) end
    end
end

local function fillSoundStart(body, item)
    fillSoundStop(body)
    if body == nil or BridgeTask.fillSink == nil then return end
    local name = "GetWaterFromTap"
    if BridgeWash ~= nil and BridgeWash.fillSoundFor ~= nil then
        pcall(function() name = BridgeWash.fillSoundFor(BridgeTask.fillSink, item) end)
    end
    local emitter = nil
    pcall(function() emitter = body:getEmitter() end)
    local snd = nil
    if emitter ~= nil then
        pcall(function() snd = emitter:playSound(name) end)
    else
        pcall(function() snd = body:playSound(name) end)
    end
    BridgeTask.fillSoundEmitter = emitter
    BridgeTask.fillSoundHandle = snd
    log("fill sound " .. tostring(name) .. " id=" .. tostring(snd))
end

local function fillApply(body, sink, item, amount)
    if body == nil or sink == nil or item == nil or amount == nil or amount <= 0 then return end
    local fc = nil
    pcall(function() fc = item:getFluidContainer() end)
    if fc == nil then return end
    local before = -1
    pcall(function() before = fc:getAmount() end)
    local fluid = Fluid.Water
    pcall(function() if sink:isTaintedWater() == true and Fluid.TaintedWater ~= nil then fluid = Fluid.TaintedWater end end)
    pcall(function() fc:addFluid(fluid, amount) end)
    local after = before
    pcall(function() after = fc:getAmount() end)
    local added = amount
    if type(before) == "number" and type(after) == "number" then
        added = after - before
        if added < 0 then added = 0 end
    end
    pcall(function() item:syncItemFields() end)
    pcall(function() sendItemStats(item) end)
    if isClient() then
        local sq = nil
        pcall(function() sq = sink:getSquare() end)
        if sq ~= nil then
            pcall(function()
                sendClientCommand(BridgeData.owner(), "Bridge", "water",
                    { x = sq:getX(), y = sq:getY(), z = sq:getZ(), amount = added })
            end)
        end
    else
        pcall(function() sink:useFluid(added) end)
        pcall(function() sink:transmitModData() end)
    end
    log(string.format("fill %s +%.2f -> %s", tostring(item:getName()), added, tostring(after)))
end

function BridgeTask.kinds.fillWater.available(body, scope)
    local ok = false
    pcall(function()
        ok = BridgeWash ~= nil and BridgeWash.fillables ~= nil and #BridgeWash.fillables(body) > 0
    end)
    return ok
end

function BridgeTask.kinds.fillWater.missing(body)
    return nil
end

function BridgeTask.kinds.fillWater.update(body)
    local sink = BridgeTask.fillSink
    local sq = nil
    if sink ~= nil then pcall(function() sq = sink:getSquare() end) end
    local target = nil
    if sq ~= nil then target = { x = sq:getX(), y = sq:getY(), z = sq:getZ() } end
    if target == nil then
        Bridge.speak("CantReachWater")
        return BridgeTask.finish()
    end

    if BridgeTask.fillPhase == nil then
        local list = {}
        if BridgeTask.fillItems ~= nil then
            for _, it in ipairs(BridgeTask.fillItems) do list[#list + 1] = it end
        elseif BridgeTask.fillItem ~= nil then
            list[1] = BridgeTask.fillItem
        end
        local keep = {}
        for _, it in ipairs(list) do
            local ok = false
            pcall(function() ok = BridgeWash.isFillable(it) and ownedByBody(body, it) end)
            if ok then keep[#keep + 1] = it end
        end
        BridgeTask.fillItems = keep
        BridgeTask.fillIndex = 0
        log("fill containers=" .. tostring(#keep) .. " of " .. tostring(#list))
        if #keep == 0 then
            fillSay("JobFillNothing", "JobFillNothing")
            return BridgeTask.finish()
        end
        local avail = 0
        pcall(function() avail = BridgeWash.waterUnits(sink) end)
        if avail <= 0 then
            fillSay("JobFillDry", "JobFillDry")
            return BridgeTask.finish()
        end
        local tainted = false
        pcall(function() tainted = sink:isTaintedWater() == true end)
        BridgeTask.fillTainted = tainted
        BridgeTask.fillPhase = "going"
        BridgeTask.fillSince = Bridge.time
        fillSay(tainted and "JobFillTainted" or "JobFill", "JobFill")
        BridgeTask.info = "fill going containers=" .. tostring(#keep)
        return true
    end

    if BridgeTask.fillPhase == "going" then
        local bath = sink ~= nil and sink.bridgeBath == true
        local res = BridgeTask.walkTo(body, target,
            bath and (BridgeTask.BATH_REACH or 1.5) or (BridgeTask.FILL_REACH or 1), not bath, bath)
        if res == "arrived" then
            pcall(function() BridgeMove.stopPath(body) end)
            Bridge.target = nil
            BridgeTask.fillPhase = "filling"
            BridgeTask.fillSince = Bridge.time
            BridgeTask.fillIndex = 0
            BridgeTask.fillTicks = nil
            BridgeTask.info = "fill at source"
            return true
        elseif res == "unreachable" then
            Bridge.speak("CantReachWater")
            return BridgeTask.finish()
        end
        BridgeTask.info = "fill walking"
        return true
    end

    pcall(function() body:faceLocationF(sq:getX() + 0.5, sq:getY() + 0.5) end)
    pcall(function()
        if tostring(body:getBumpType()) ~= BridgeTask.FILL_ANIM then
            body:setBumpType(BridgeTask.FILL_ANIM)
        end
    end)

    local list = BridgeTask.fillItems or {}
    BridgeTask.fillIndex = BridgeTask.fillIndex or 0
    if BridgeTask.fillIndex >= #list then
        fillSoundStop(body)
        fillSay("JobFillDone", "JobFillDone")
        return BridgeTask.finish()
    end

    if BridgeTask.fillTicks == nil then
        local it = fillCurrentItem()
        local ok = false
        pcall(function() ok = it ~= nil and BridgeWash.isFillable(it) and ownedByBody(body, it) end)
        if not ok then
            BridgeTask.fillIndex = BridgeTask.fillIndex + 1
            return true
        end
        local avail = 0
        pcall(function() avail = BridgeWash.waterUnits(sink) end)
        if avail <= 0 then
            fillSoundStop(body)
            fillSay("JobFillDry", "JobFillDry")
            return BridgeTask.finish()
        end
        local fc = nil
        pcall(function() fc = it:getFluidContainer() end)
        local free = 0
        pcall(function() free = fc:getFreeCapacity() end)
        local amount = free
        if avail < amount then amount = avail end
        if type(amount) ~= "number" or amount <= 0 then
            log(string.format("fill skip %s free=%s avail=%s", tostring(it:getName()), tostring(free), tostring(avail)))
            BridgeTask.fillIndex = BridgeTask.fillIndex + 1
            return true
        end
        BridgeTask.fillAmount = amount
        BridgeTask.fillTicks = fillTicksFor(amount)
        BridgeTask.fillSince = Bridge.time
        pcall(function() body:setVariable("PourType", it:getPourType() or "Bottle") end)
        fillSoundStart(body, it)
        BridgeTask.info = string.format("fill %s amount=%.2f ticks=%d",
            tostring(it:getName()), amount, BridgeTask.fillTicks)
        return true
    end

    if (Bridge.time - (BridgeTask.fillSince or Bridge.time)) * ffMult() >= (BridgeTask.fillTicks or 1) then
        local it = fillCurrentItem()
        fillSoundStop(body)
        fillApply(body, sink, it, BridgeTask.fillAmount)
        BridgeTask.fillTicks = nil
        BridgeTask.fillAmount = nil
        BridgeTask.fillIndex = BridgeTask.fillIndex + 1
        if BridgeTask.fillIndex >= #list then
            fillSay("JobFillDone", "JobFillDone")
            return BridgeTask.finish()
        end
        local avail = 0
        pcall(function() avail = BridgeWash.waterUnits(sink) end)
        if avail <= 0 then
            fillSay("JobFillDry", "JobFillDry")
            return BridgeTask.finish()
        end
        return true
    end
    BridgeTask.info = string.format("fill %d/%d", (BridgeTask.fillIndex or 0) + 1, #list)
    return true
end

function BridgeTask.kinds.fillWater.leave(body)
    fillSoundStop(body)
    BridgeTask.fillSink = nil
    BridgeTask.fillPhase = nil
    BridgeTask.fillItems = nil
    BridgeTask.fillItem = nil
    BridgeTask.fillIndex = nil
    BridgeTask.fillTicks = nil
    BridgeTask.fillAmount = nil
    BridgeTask.fillTainted = false
    BridgeTask.fillSoundAt = nil
    BridgeTask.fillSoundHandle = nil
    BridgeTask.fillSoundEmitter = nil
    if body ~= nil then
        pcall(function()
            if tostring(body:getBumpType()) == BridgeTask.FILL_ANIM then body:setBumpType("") end
        end)
        pcall(function() body:setVariable("PourType", "") end)
    end
end


BridgeTask.kinds.emptyFluid = {}
BridgeTask.kinds.emptyFluid.noTargets = true
BridgeTask.kinds.emptyFluid.unavailableSpeech = "JobEmptyNothing"

local function emptyTicksFor(amount, item)
    local ms = nil
    pcall(function()
        local perLiter = FluidUtil.getTransferActionTimePerLiter()
        local minTime = FluidUtil.getMinTransferActionTime()
        if type(perLiter) == "number" and perLiter > 0 then ms = (amount or 0) * perLiter end
        local rate = 0
        pcall(function() rate = item:getFluidContainer():getTransferRate() end)
        if type(ms) == "number" and type(rate) == "number" and rate > 0 then ms = ms / rate end
        if type(minTime) == "number" and (ms == nil or ms < minTime) then ms = minTime end
    end)
    if type(ms) ~= "number" then
        ms = (amount or 0) * (BridgeTask.EMPTY_UNIT_TICKS or 100) + (BridgeTask.EMPTY_BASE_TICKS or 30)
    end
    local ticks = math.floor(ms)
    if ticks < (BridgeTask.EMPTY_MIN_TICKS or 60) then ticks = BridgeTask.EMPTY_MIN_TICKS or 60 end
    return ticks
end

local function emptySoundStop(body)
    local emitter = BridgeTask.emptyEmitter
    local snd = BridgeTask.emptySound
    BridgeTask.emptyEmitter, BridgeTask.emptySound = nil, nil
    if snd == nil then return end
    if emitter ~= nil then
        pcall(function() emitter:stopSound(snd) end)
        return
    end
    if body ~= nil then
        local playing = false
        pcall(function() playing = body:getEmitter():isPlaying(snd) == true end)
        if playing then pcall(function() body:stopOrTriggerSound(snd) end) end
    end
end

local function emptySoundStart(body, item)
    emptySoundStop(body)
    if body == nil or item == nil then return end
    local name = nil
    pcall(function() name = item:getPourLiquidOnGroundSound() end)
    if type(name) ~= "string" or name == "" then name = "PourLiquidOnGround" end
    local emitter = nil
    pcall(function() emitter = body:getEmitter() end)
    local snd = nil
    if emitter ~= nil then
        pcall(function() snd = emitter:playSound(name) end)
    else
        pcall(function() snd = body:playSound(name) end)
    end
    BridgeTask.emptyEmitter = emitter
    BridgeTask.emptySound = snd
    log("empty sound " .. tostring(name) .. " id=" .. tostring(snd))
end

local function emptyApply(body, item)
    if item == nil then return end
    local cont = nil
    pcall(function() cont = item:getFluidContainer() end)
    if cont == nil then return end
    local ok = false
    pcall(function() cont:Empty() ok = true end)
    pcall(function() item:syncItemFields() end)
    pcall(function() sendItemStats(item) end)
    log("empty " .. tostring(item:getName()) .. (ok and "" or " (failed)"))
end

function BridgeTask.kinds.emptyFluid.available(body, scope)
    local ok = false
    pcall(function()
        ok = BridgeWash ~= nil and BridgeWash.emptyables ~= nil and #BridgeWash.emptyables(body) > 0
    end)
    return ok
end

function BridgeTask.kinds.emptyFluid.missing(body)
    return nil
end

function BridgeTask.kinds.emptyFluid.update(body)
    local list = BridgeTask.emptyItems
    if list == nil then
        list = {}
        if BridgeTask.emptyItem ~= nil then list[1] = BridgeTask.emptyItem end
        BridgeTask.emptyItems = list
        BridgeTask.emptyIndex = 0
    end
    BridgeTask.emptyIndex = BridgeTask.emptyIndex or 0
    if BridgeTask.emptyIndex >= #list then
        emptySoundStop(body)
        Bridge.speak("JobEmptyDone")
        return BridgeTask.finish()
    end

    pcall(function()
        if tostring(body:getBumpType()) ~= BridgeTask.EMPTY_ANIM then
            body:setBumpType(BridgeTask.EMPTY_ANIM)
        end
    end)

    local it = list[BridgeTask.emptyIndex + 1]
    local ok = false
    pcall(function()
        ok = it ~= nil and ownedByBody(body, it)
            and it:getFluidContainer() ~= nil and it:getFluidContainer():getAmount() > 0
    end)
    if not ok then
        emptySoundStop(body)
        BridgeTask.emptyTicks = nil
        BridgeTask.emptyIndex = BridgeTask.emptyIndex + 1
        return true
    end

    if BridgeTask.emptyTicks == nil then
        local amount = 0
        pcall(function() amount = it:getFluidContainer():getAmount() end)
        BridgeTask.emptyTicks = emptyTicksFor(amount, it)
        BridgeTask.emptySince = Bridge.time
        local pt = nil
        pcall(function() pt = it:getPourType() end)
        BridgeTask.emptyPourType = pt
        pcall(function() body:setVariable("PourType", pt or "Bottle") end)
        emptySoundStart(body, it)
        BridgeTask.info = string.format("empty %s amount=%.2f ticks=%d",
            tostring(it:getName()), amount, BridgeTask.emptyTicks)
        return true
    end

    if (Bridge.time - (BridgeTask.emptySince or Bridge.time)) * ffMult() >= (BridgeTask.emptyTicks or 1) then
        emptySoundStop(body)
        emptyApply(body, it)
        BridgeTask.emptyTicks = nil
        BridgeTask.emptyIndex = BridgeTask.emptyIndex + 1
        pcall(function() body:setVariable("PourType", "") end)
        if BridgeTask.emptyIndex >= #list then
            Bridge.speak("JobEmptyDone")
            return BridgeTask.finish()
        end
        return true
    end
    BridgeTask.info = string.format("emptying %d/%d", (BridgeTask.emptyIndex or 0) + 1, #list)
    return true
end

function BridgeTask.kinds.emptyFluid.leave(body)
    emptySoundStop(body)
    BridgeTask.emptyItems = nil
    BridgeTask.emptyItem = nil
    BridgeTask.emptyIndex = nil
    BridgeTask.emptyTicks = nil
    BridgeTask.emptySince = 0
    BridgeTask.emptyPourType = nil
    if body ~= nil then
        pcall(function()
            if tostring(body:getBumpType()) == BridgeTask.EMPTY_ANIM then body:setBumpType("") end
        end)
        pcall(function() body:setVariable("PourType", "") end)
    end
end

local function dropBushTargets()
    local i = 1
    while i <= #BridgeTask.queue do
        local t = BridgeTask.queue[i]
        local sq = nil
        pcall(function() sq = getCell():getGridSquare(t.x, t.y, t.z) end)
        if plantKind(sq) == "bush" and (BridgePlants == nil or not BridgePlants.squareGrass(sq)) then
            table.remove(BridgeTask.queue, i)
        else
            i = i + 1
        end
    end
end

BridgeTask.kinds.clearPlants = {}

function BridgeTask.kinds.clearPlants.available(body)
    return BridgeTask.CLEARING_ENABLED == 1
end

function BridgeTask.kinds.clearPlants.missing(body)
    if BridgeTask.findCutTool(body) == nil then return "cut" end
    return nil
end

function BridgeTask.kinds.clearPlants.update(body)
    if BridgeTask.CLEARING_ENABLED ~= 1 then return BridgeTask.finish() end

    if BridgeMove ~= nil then BridgeMove.forcedWalk = "Walk" end

    local target = BridgeTask.current
    if target == nil then
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        local bx, by = body:getX(), body:getY()
        local bestI, bestD = nil, nil
        local bestAnyI, bestAnyD = nil, nil
        local bodyKey = BridgeTask.enclosureKey(body)
        local i = 1
        while i <= #BridgeTask.queue do
            local t = BridgeTask.queue[i]
            local sq = getCell():getGridSquare(t.x, t.y, t.z)
            local d = (bx - t.x) ^ 2 + (by - t.y) ^ 2
            if bestAnyD == nil or d < bestAnyD then bestAnyD = d; bestAnyI = i end
            if bodyKey == nil or BridgeTask.enclosureKeyOf(sq) == bodyKey then
                if bestD == nil or d < bestD then bestD = d; bestI = i end
            end
            i = i + 1
        end
        if bestI == nil then bestI, bestD = bestAnyI, bestAnyD end
        if bestI == nil then
            BridgeTask.info = "nothing to clear"
            return BridgeTask.finish()
        end
        target = table.remove(BridgeTask.queue, bestI)
        BridgeTask.current = target
        BridgeTask.phase = "walk"
        BridgeTask.swings = 0
        BridgeTask.since = Bridge.time
        BridgeTask.spot = nil
        BridgeTask.swingStart = nil
        BridgeTask.still = 0
        BridgeTask.checkX = nil
        BridgeTask.animHold = 0
        BridgeTask.animLogged = false
        BridgeTask.clearStart = nil
        BridgeTask.plantKindCache, BridgeTask.plantKindKey, BridgeTask.plantKindAt = nil, nil, nil
        BridgeTask.bestD = nil
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
    end

    local square = getCell():getGridSquare(target.x, target.y, target.z)
    local plantKey = target.x .. "," .. target.y .. "," .. target.z
    if BridgeTask.plantKindKey ~= plantKey
            or (Bridge.tick - (BridgeTask.plantKindAt or -99999)) >= 30 then
        BridgeTask.plantKindKey = plantKey
        BridgeTask.plantKindAt = Bridge.tick
        BridgeTask.plantKindCache = plantKind(square)
    end
    local kind = BridgeTask.plantKindCache
    if kind == nil then
        BridgeTask.clearChop(body)
        BridgeTask.info = "clear"
        BridgeTask.current = nil
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        return true
    end

    local tool = nil
    if kind == "bush" then
        tool = BridgeTask.cachedTool(body, "cut", BridgeTask.findCutTool, BridgeTask.toolOk)
        if tool == nil then
            BridgeTask.clearNeedCut = true
            dropBushTargets()
            Bridge.speak("JobNeedCutTool")
            BridgeTask.clearChop(body)
            BridgeTask.current = nil
            if #BridgeTask.queue == 0 then return BridgeTask.finish() end
            return true
        end
        if body:getPrimaryHandItem() ~= tool then
            ensureInMain(body, tool)
            pcall(function()
                body:setPrimaryHandItem(tool)
                if tool:isTwoHandWeapon() or tool:isRequiresEquippedBothHands() then body:setSecondaryHandItem(tool) end
                body:resetModelNextFrame()
            end)
        end
    end

    local reach = BridgeTask.CLEAR_RANGE
    if BridgeTask.phase == "work" then reach = reach + 1.0 end
    local walk, why = BridgeTask.walkTo(body, target, reach)
    if walk == "unreachable" then return BridgeTask.dropTarget(why) end
    if walk == "walking" then return true end

    if BridgeTask.phase ~= "work" then
        BridgeTask.phase = "work"
        BridgeTask.since = Bridge.time
        BridgeTask.clearStart = Bridge.time
        BridgeTask.swings = 0
        BridgeTask.swingStart = nil
        BridgeTask.swingHit = false
        pcall(function() BridgeMove.stopPath(body) end)
        BridgeTask.info = "clearing"
        log(string.format("arrived at clear %d,%d kind=%s", target.x, target.y, tostring(kind)))
    end

    if (Bridge.time - (BridgeTask.since or Bridge.time)) > BridgeTask.CLEAR_TIMEOUT then
        BridgeTask.clearChop(body)
        BridgeTask.info = "skip stubborn plant"
        return BridgeTask.dropTarget(nil)
    end

    pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)

    local anim = (kind == "bush") and vineCleanAnim(tool) or BridgeTask.GRASS_ANIM
    if not BridgeTask.animLogged then
        BridgeTask.animLogged = true
        log(string.format("clear anim=%s kind=%s", tostring(anim), tostring(kind)))
    end

    if (Bridge.time - (BridgeTask.lastClearSayCheck or 0)) >= SECOND then
        BridgeTask.lastClearSayCheck = Bridge.time
        if (Bridge.time - (BridgeTask.lastClearSay or -99999)) >= BridgeTask.CLEAR_SAY_COOLDOWN
                and ZombRand(100) < 30 then
            local said = false
            pcall(function()
                said = BridgeMoments ~= nil
                    and BridgeMoments.say("EvClearing", BridgeTask.CLEAR_SAY_COOLDOWN, true, "Clearing") == true
            end)
            if said then BridgeTask.lastClearSay = Bridge.time end
        end
    end

    local bump = ""
    pcall(function() bump = tostring(body:getBumpType()) end)
    if BridgeTask.swingStart == nil then
        if (BridgeTask.animHold or 0) > 0 then
            BridgeTask.animHold = BridgeTask.animHold - 1
            pcall(function() body:setVariable("BumpAnimFinished", true) end)
            pcall(function() body:changeState(ZombieIdleState.instance()) end)
            pcall(function() body:setBumpType("") end)
            BridgeTask.info = "resettling clear"
            return true
        end
        BridgeTask.swingStart = Bridge.time
        BridgeTask.swingHit = false
        pcall(function() body:setVariable("NotAloneHitNow", false) end)
        pcall(function()
            body:setVariable("BumpAnimFinished", false)
            body:setBumpType(anim)
        end)
        return true
    end

    local age = (Bridge.time - BridgeTask.swingStart) * ffMult()

    if age >= BridgeTask.SCRUB_GUARD then
        local playing = false
        pcall(function()
            playing = body:getActionStateName() == "bumped"
                and tostring(body:getBumpType()) == anim
        end)
        if not playing then
            pcall(function() body:setVariable("BumpAnimFinished", true) end)
            pcall(function() body:changeState(ZombieIdleState.instance()) end)
            pcall(function() body:setBumpType("") end)
            BridgeTask.animHold = 2
            BridgeTask.swingStart = nil
            BridgeTask.info = "clear anim lost, restarting"
            return true
        end
    end

    local workTime = (kind == "bush") and BridgeTask.BUSH_TIME or BridgeTask.GRASS_TIME
    if (Bridge.time - (BridgeTask.clearStart or Bridge.time)) * ffMult() >= workTime then
        BridgePlants.applyPlant(square, kind, body)
        if Bridge ~= nil and Bridge.mp then
            pcall(function()
                sendClientCommand(BridgeData.owner(), "Bridge", "clearPlants",
                    { x = square:getX(), y = square:getY(), z = square:getZ(), kind = kind })
            end)
        end
        if kind == "bush" then
            pcall(function() square:playSound("ChopTree") end)
            pcall(function() addSound(body, body:getX(), body:getY(), body:getZ(), 20, 1) end)
            vineUseEndurance(body, tool)
        else
            pcall(function() square:playSound("RemovePlant") end)
            pcall(function() addSound(body, body:getX(), body:getY(), body:getZ(), 10, 5) end)
            pcall(function()
                local skill = body:getPerkLevel(Perks.Farming)
                local use = (1 - (skill * 0.05)) * BridgeTask.GRASS_ENDURANCE
                if use > 0 then body:getStats():remove(CharacterStat.ENDURANCE, use) end
            end)
        end
        BridgeTask.swings = (BridgeTask.swings or 0) + 1
        BridgeTask.info = "clear " .. tostring(kind) .. " " .. tostring(BridgeTask.swings)

        BridgeTask.clearChop(body)
        BridgeTask.markDone()
        BridgeTask.current = nil
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        return true
    end

    if age >= BridgeTask.SWING_MAX then
        BridgeTask.swingStart = nil
    end
    return true
end

function BridgeTask.kinds.clearPlants.leave(body)
    BridgeTask.clearChop(body)
    restoreForcedWalk()
    BridgeTask.clearNeedCut = nil
    BridgeTask.clearStart = nil
    BridgeTask.deferred = {}
end


function BridgeTask.lootDests(body)
    local out = {}
    if body == nil then return out end
    if BridgeInventory ~= nil and BridgeInventory.wornBags ~= nil then
        pcall(function()
            for _, bag in ipairs(BridgeInventory.wornBags(body)) do
                local inv = nil
                pcall(function() inv = bag:getInventory() end)
                if inv ~= nil then out[#out + 1] = inv end
            end
        end)
    end
    local main = nil
    pcall(function() main = body:getInventory() end)
    if main ~= nil then out[#out + 1] = main end
    return out
end

function BridgeTask.lootDestFor(body, item, dests)
    if item == nil or dests == nil then return nil end
    if BridgeInventory ~= nil and type(BridgeInventory.capBlocked) == "function" and BridgeInventory.capBlocked() then
        return nil
    end
    for i = 1, #dests do
        local ok = nil
        pcall(function() ok = BridgeInventory.roomVerdict(dests[i], item) end)
        if ok == true then return dests[i] end
    end
    return nil
end

function BridgeTask.lootWeight(item)
    local w = nil
    pcall(function() w = item:getActualWeight() end)
    if type(w) ~= "number" or w < 0 then
        w = nil
        pcall(function() w = item:getUnequippedWeight() end)
    end
    if type(w) ~= "number" or w < 0 then w = 0 end
    return w
end

local lootTraceSeen = {}
local function lootTrace(key, text)
    if Bridge == nil or not Bridge.verbose then return end
    if lootTraceSeen[key] then return end
    lootTraceSeen[key] = true
    log(text)
end

function BridgeTask.lootFilter(item, kind)
    if item == nil or BridgeData == nil then return false end
    local rec = Bridge ~= nil and Bridge.store or nil
    local maxW = BridgeData.lootMaxWeight(rec)
    local w = BridgeTask.lootWeight(item)
    if maxW > 0 and w > maxW then
        if Bridge ~= nil and Bridge.verbose then
            local t = tostring(item:getType())
            lootTrace("heavy|" .. t .. "|" .. tostring(maxW),
                string.format("loot skip heavy %s w=%.2f > %.2f", t, w, maxW))
        end
        return true
    end
    local pool = nil
    pcall(function() pool = BridgeSocial.receivePool(item) end)
    local allowed = true
    pcall(function() allowed = BridgeData.lootPoolAllowed(rec, pool, item) == true end)
    if not allowed then
        if Bridge ~= nil and Bridge.verbose then
            local disp = nil
            pcall(function() disp = item:getDisplayCategory() end)
            local t = tostring(item:getType())
            lootTrace("cat|" .. t .. "|" .. tostring(pool),
                string.format("loot skip cat %s pool=%s disp=%s", t, tostring(pool), tostring(disp)))
        end
        return true
    end
    if Bridge ~= nil and Bridge.verbose then
        local disp = nil
        pcall(function() disp = item:getDisplayCategory() end)
        local t = tostring(item:getType())
        lootTrace("take|" .. t .. "|" .. tostring(pool),
            string.format("loot take %s pool=%s disp=%s", t, tostring(pool), tostring(disp)))
    end
    return false
end

function BridgeTask.lootItems(body, target)
    local items = {}
    if target == nil then return items end
    local c = target.cont
    if c == nil then return items end
    if type(target.only) == "table" and #target.only > 0 then
        for i = 1, #target.only do
            local it = target.only[i]
            local present = false
            pcall(function() present = it ~= nil and c:contains(it) == true end)
            if present then items[#items + 1] = { item = it, w = BridgeTask.lootWeight(it) } end
        end
        table.sort(items, function(a, b) return a.w < b.w end)
        return items
    end
    pcall(function()
        local list = c:getItems()
        if list == nil then return end
        for i = 0, list:size() - 1 do
            local it = list:get(i)
            if it ~= nil then
                local skip = false
                if BridgeTask.lootFilter ~= nil then
                    pcall(function() skip = BridgeTask.lootFilter(it, target.kind) == true end)
                end
                if not skip then items[#items + 1] = { item = it, w = BridgeTask.lootWeight(it) } end
            end
        end
    end)
    table.sort(items, function(a, b) return a.w < b.w end)
    return items
end

function BridgeTask.lootScan(body)
    if body == nil then return false, false end
    local dests = BridgeTask.lootDests(body)
    local budget = BridgeTask.LOOT_SCAN_BUDGET
    local wanted = false
    for i = 1, #BridgeTask.queue do
        local list = BridgeTask.lootItems(body, BridgeTask.queue[i])
        if #list > 0 then wanted = true end
        for j = 1, #list do
            budget = budget - 1
            if budget < 0 then return true, true end
            if BridgeTask.lootDestFor(body, list[j].item, dests) ~= nil then return wanted, true end
        end
    end
    return wanted, false
end

function BridgeTask.lootAnyFits(body)
    local _, fits = BridgeTask.lootScan(body)
    return fits
end

function BridgeTask.lootQueueFits(body)
    return BridgeTask.lootAnyFits(body)
end

function BridgeTask.lootAnim(cont)
    if BridgeInventory ~= nil and BridgeInventory.lootAnimFor ~= nil then
        local a = nil
        pcall(function() a = BridgeInventory.lootAnimFor(cont) end)
        if a ~= nil then return a end
    end
    return BridgeTask.LOOT_MID
end

function BridgeTask.lootTake(body, target, item, dest)
    local src = nil
    pcall(function() src = item:getContainer() end)
    if src == nil and target ~= nil then src = target.cont end
    if src == nil or dest == nil then return false end
    local act = nil
    local chr = BridgeData ~= nil and BridgeData.owner() or nil
    pcall(function() act = ISInventoryTransferAction:new(chr, item, src, dest) end)
    if act == nil then return false end
    pcall(function()
        local only = (target ~= nil and type(target.only) == "table" and #target.only > 0)
            and target.only or nil
        local cap = BridgeTask.LOOT_BATCH_MAX or 20
        local full = item:getFullType()
        local group = { item }
        if only ~= nil then
            for i = 1, #only do
                if #group >= cap then break end
                local it = only[i]
                if it ~= item and it:getContainer() == src and it:getFullType() == full then
                    group[#group + 1] = it
                end
            end
        else
            local list = src:getItems()
            for i = 0, list:size() - 1 do
                if #group >= cap then break end
                local it = list:get(i)
                if it ~= nil and it ~= item and it:getFullType() == full then
                    group[#group + 1] = it
                end
            end
        end
        if #group > 1 then
            if isClient() then
                if act.bridgeRelay ~= nil then
                    act.queueList = { { items = group, time = act.maxTime, type = full } }
                    act.bridgeRelay.group = group
                else
                    act.group = group
                end
            else
                act.queueList = { { items = group, time = act.maxTime, type = full } }
            end
        end
    end)
    pcall(function() act.bridgeHerLoot = BridgeTask.lootAnim(src) end)
    BridgeTask.lootAct = act
    BridgeTask.lootSrc = src
    local ok = false
    pcall(function()
        if BridgeQueue ~= nil and BridgeQueue.push ~= nil then
            BridgeQueue.push(act)
        else
            ISTimedActionQueue.add(act)
        end
        ok = true
    end)
    return ok
end

function BridgeTask.lootAbortAct()
    local act = BridgeTask.lootAct
    BridgeTask.lootAct = nil
    BridgeTask.lootSrc = nil
    if act == nil then return end
    local started = act.started == true
    if not started and act.action ~= nil and BridgeQueue ~= nil
            and getmetatable(act.action) == BridgeQueue.Fake then
        started = act.action.started == true
    end
    if not started and act.loopSound ~= nil then started = true end
    pcall(function()
        if BridgeQueue ~= nil and BridgeQueue.indexOf ~= nil then
            local i = BridgeQueue.indexOf(act)
            if i ~= nil then table.remove(BridgeQueue.jobs, i) end
        end
        if started then
            act:stop()
        else
            act:forceCancel()
        end
    end)
end

function BridgeTask.lootSay(item, kind)
    if BridgeTask.lootFullSaid then return end
    if BridgeMoments == nil or BridgeMoments.say == nil then return end
    local event = nil
    local pool = nil
    if item ~= nil and BridgeSocial ~= nil and BridgeSocial.receivePool ~= nil then
        pcall(function() pool = BridgeSocial.receivePool(item) end)
    end
    if pool == "ReceiveGun" or pool == "ReceiveAmmo" or pool == "ReceiveAmmoParts" then
        if BridgeGunTalk ~= nil and BridgeGunTalk.loot ~= nil then
            pcall(function() BridgeGunTalk.loot(pool) end)
        end
        return
    end
    if kind == "floor" then event = "LootGround"
    elseif kind == "body" then event = "LootCorpse" end
    if event == nil and type(pool) == "string" and string.sub(pool, 1, 7) == "Receive" then
        local cand = "Loot" .. string.sub(pool, 8)
        local exists = nil
        pcall(function() exists = getTextOrNull("IGUI_NotAlone_Soc_" .. cand .. "_Near_1", "", "") end)
        if type(exists) == "string" and exists ~= "" and exists ~= ("IGUI_NotAlone_Soc_" .. cand .. "_Near_1") then
            event = cand
        end
    end
    if event == nil then
        if ZombRand(100) >= 30 then return end
        event = "EvLooting"
    end
    pcall(function() BridgeMoments.say(event, BridgeTask.LOOT_SAY_COOLDOWN, true, "Loot") end)
end

function BridgeTask.lootSayFull()
    if BridgeTask.lootFullSaid then return end
    BridgeTask.lootFullSaid = true
    BridgeTask.lootSaid = true
    if BridgeMoments == nil or BridgeMoments.say == nil then return end
    pcall(function() BridgeMoments.say("LootFull", 0, true, "LootFull") end)
end

BridgeTask.kinds.lootArea = {}

function BridgeTask.forceIdle(body)
    if body == nil then return end
    pcall(function()
        if BridgeMove ~= nil then
            BridgeMove.stopPath(body)
            BridgeMove.moving = false
            BridgeMove.pathing = false
            BridgeMove.steering = false
        end
        body:setVariable("bPathfind", false)
        pcall(function() body:setMoving(false) end)
        local asn = tostring(body:getActionStateName())
        if asn == "walktoward" or asn == "pathfind" then
            if ZombieIdleState ~= nil and ZombieIdleState.instance ~= nil then
                body:changeState(ZombieIdleState.instance())
            end
        end
    end)
end

function BridgeTask.kinds.lootArea.available(body)
    return BridgeTask.LOOTING_ENABLED == 1
end

function BridgeTask.kinds.lootArea.missing(body)
    return nil
end

function BridgeTask.kinds.lootArea.update(body)
    if BridgeTask.LOOTING_ENABLED ~= 1 then return BridgeTask.finish() end
    if BridgeMove ~= nil then
        BridgeMove.forcedWalk = "Walk"
        BridgeMove.holdDoors = true
    end
    pcall(function()
        if BridgeMove ~= nil and BridgeMove.doorAct == nil and BridgeMove.window == nil and BridgeMove.cross == nil
                and tostring(body:getActionStateName()) == "bumped"
                and tostring(body:getBumpType()) == "Stand" then
            if BridgeMove.releaseBump ~= nil then BridgeMove.releaseBump(body) end
        end
    end)

    local target = BridgeTask.current
    if target == nil then
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        local bx, by = body:getX(), body:getY()
        local bestI, bestD = nil, nil
        local bestAnyI, bestAnyD = nil, nil
        local bodyKey = BridgeTask.enclosureKey(body)
        local i = 1
        while i <= #BridgeTask.queue do
            local t = BridgeTask.queue[i]
            local empty = false
            pcall(function() empty = t.cont == nil or t.cont:getItems():size() == 0 end)
            if empty then
                table.remove(BridgeTask.queue, i)
            else
                local d = (bx - t.x) ^ 2 + (by - t.y) ^ 2
                if bestAnyD == nil or d < bestAnyD then bestAnyD = d; bestAnyI = i end
                local sq = nil
                pcall(function() sq = getCell():getGridSquare(t.x, t.y, t.z) end)
                if bodyKey == nil or BridgeTask.enclosureKeyOf(sq) == bodyKey then
                    if bestD == nil or d < bestD then bestD = d; bestI = i end
                end
                i = i + 1
            end
        end
        if bestI == nil then bestI, bestD = bestAnyI, bestAnyD end
        if bestI == nil then return BridgeTask.finish() end
        target = table.remove(BridgeTask.queue, bestI)
        BridgeTask.current = target
        BridgeTask.phase = "walk"
        BridgeTask.since = Bridge.time
        BridgeTask.spot = nil
        BridgeTask.still = 0
        BridgeTask.checkX = nil
        BridgeTask.animHold = 0
        BridgeTask.bestD = nil
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
        BridgeTask.lootList = nil
        BridgeTask.lootIdx = nil
        BridgeTask.lootPending = nil
        BridgeTask.lootPendingAt = nil
        BridgeTask.lootTook = 0
        BridgeTask.lootNoRoom = 0
        BridgeTask.lootSaid = false
        BridgeTask.lootSettled = false
        BridgeTask.openingRef, BridgeTask.openingKey, BridgeTask.openingTries = nil, nil, nil
    BridgeTask.openingSince = nil
    end

    local walk, why = BridgeTask.walkTo(body, target, BridgeTask.LOOT_RANGE, true)
    if walk == "unreachable" then
        pcall(function()
            local d = math.sqrt((body:getX() - (target.x + 0.5)) ^ 2 + (body:getY() - (target.y + 0.5)) ^ 2)
            local clear = BridgeTask.adjacentClear(body, getCell():getGridSquare(target.x, target.y, target.z))
            log(string.format("loot drop %d,%d,%d why=%s d=%.2f clear=%s bx=%.1f by=%.1f",
                target.x, target.y, target.z, tostring(why), d, tostring(clear), body:getX(), body:getY()))
        end)
        return BridgeTask.dropTarget(why)
    end
    if walk == "walking" then return true end

    local climbing = false
    pcall(function()
        local asn = tostring(body:getActionStateName())
        climbing = asn == "climbwindow" or asn == "climbfence"
            or (BridgeMove ~= nil and (BridgeMove.pendingClimb ~= nil or BridgeMove.cross ~= nil))
    end)
    if climbing then
        BridgeTask.info = "climbing"
        return true
    end

    if BridgeTask.phase ~= "loot" then
        BridgeTask.phase = "loot"
        BridgeTask.since = Bridge.time
        BridgeTask.lootSettled = false
        BridgeTask.info = "looting"
        pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)
    end
    BridgeTask.forceIdle(body)

    local pend = BridgeTask.lootPending
    if pend ~= nil then
        local src = BridgeTask.lootSrc
        local here = false
        pcall(function() here = src ~= nil and src:contains(pend) end)
        if (not here) or (Bridge.time - (BridgeTask.lootPendingAt or Bridge.time)) > BridgeTask.LOOT_TRANSFER_WAIT then
            BridgeTask.lootPending = nil
            BridgeTask.lootPendingAt = nil
            if not here then
                BridgeTask.lootAct = nil
                BridgeTask.lootSrc = nil
                BridgeTask.lootTook = (BridgeTask.lootTook or 0) + 1
                if not BridgeTask.lootSaid then
                    BridgeTask.lootSaid = true
                    pcall(function() BridgeTask.lootSay(pend, target.kind) end)
                end
            else
                BridgeTask.lootAbortAct()
            end
        end
        return true
    end

    if not BridgeTask.lootSettled then
        local moving = false
        pcall(function()
            local asn = tostring(body:getActionStateName())
            moving = (asn == "walktoward" or asn == "pathfind")
                or (BridgeMove ~= nil and BridgeMove.moving == true)
        end)
        if moving and (Bridge.time - (BridgeTask.since or Bridge.time)) < 3 * SECOND then
            BridgeTask.forceIdle(body)
            BridgeTask.info = "settling"
            return true
        end
        BridgeTask.lootSettled = true
    end

    if BridgeTask.lootNextAt ~= nil and Bridge.time < BridgeTask.lootNextAt then return true end

    local list = BridgeTask.lootList
    if list == nil then
        list = BridgeTask.lootItems(body, target)
        BridgeTask.lootList = list
        BridgeTask.lootIdx = 0
    end
    local dests = BridgeTask.lootDests(body)
    while true do
        BridgeTask.lootIdx = (BridgeTask.lootIdx or 0) + 1
        local entry = list[BridgeTask.lootIdx]
        if entry == nil then
            local full = false
            if (BridgeTask.lootNoRoom or 0) > 0 and not BridgeTask.lootQueueFits(body) then full = true end
            BridgeTask.current = nil
            BridgeTask.lootList = nil
            BridgeTask.lootIdx = nil
            pcall(function() BridgeMove.stopPath(body) end)
            if BridgeMove ~= nil and BridgeMove.releaseBump ~= nil then pcall(BridgeMove.releaseBump, body) end
            BridgeTask.markDone()
            if full then
                BridgeTask.lootFull = true
                return BridgeTask.finish()
            end
            if #BridgeTask.queue == 0 then return BridgeTask.finish() end
            return true
        end
        local item = entry.item
        local present = false
        pcall(function() present = target.cont ~= nil and target.cont:contains(item) end)
        local skip = false
        if type(target.only) ~= "table" or #target.only == 0 then
            pcall(function() skip = BridgeTask.lootFilter(item, target.kind) == true end)
        end
        if present and not skip then
            local dest = BridgeTask.lootDestFor(body, item, dests)
            if dest == nil then
                BridgeTask.lootNoRoom = (BridgeTask.lootNoRoom or 0) + 1
                pcall(BridgeTask.lootSayFull)
            elseif BridgeTask.lootTake(body, target, item, dest) then
                BridgeTask.lootPending = item
                BridgeTask.lootPendingAt = Bridge.time
                BridgeTask.lootNextAt = Bridge.time + BridgeTask.LOOT_ITEM_TIME
                pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)
                return true
            end
        end
    end
end

function BridgeTask.kinds.lootArea.leave(body)
    BridgeTask.clearChop(body)
    if BridgeMove ~= nil and BridgeMove.releaseBump ~= nil then pcall(BridgeMove.releaseBump, body) end
    pcall(BridgeTask.lootAbortAct)
    if BridgeMove ~= nil then BridgeMove.holdDoors = false end
    restoreForcedWalk()
    BridgeTask.lootList = nil
    BridgeTask.lootIdx = nil
    BridgeTask.lootPending = nil
    BridgeTask.lootPendingAt = nil
    BridgeTask.deferred = {}
end





local SIT_DIRS = { "N", "S", "W", "E" }
local SIT_SIDES = { "Front", "Left", "Right" }
local SIT_MAX_TRANSLATION = 1.0
local SIT_FACING_OFF = { N = { 0, -1 }, S = { 0, 1 }, W = { -1, 0 }, E = { 1, 0 } }


BridgeTask.LAY_ANIM_MAX = 240
BridgeTask.LAY_SETTLE = 0.30
BridgeTask.LAY_AWAKE = "LayAwake"
BridgeTask.LAY_ASLEEP = "LayAsleep"

local function sitDist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function sitFaceOf(side, dir)
    local d = nil
    pcall(function() d = IsoDirections.fromString(dir) end)
    if d == nil then return nil end
    if side == "Left" then return d:RotRight(2) end
    if side == "Right" then return d:RotLeft(2) end
    return d
end

local function sitIsRealBed(obj)
    local props, sprite = nil, nil
    pcall(function() props = obj:getProperties() end)
    pcall(function() sprite = obj:getSprite() end)
    if props == nil or sprite == nil then return false end
    local bed = false
    pcall(function() bed = props:has(IsoFlagType.bed) == true end)
    if not bed then return false end
    local name = nil
    pcall(function() name = sprite:getName() end)
    if name == nil then return false end
    if string.find(name, "seating", 1, true) ~= nil
            or string.find(name, "fixtures_bathroom", 1, true) ~= nil then return false end
    if string.find(name, "bedding", 1, true) ~= nil then return true end
    local grid = nil
    pcall(function() grid = sprite:getSpriteGrid() end)
    return grid ~= nil
end
BridgeTask.sitIsRealBed = sitIsRealBed

function BridgeTask.seatIsSeat(obj)
    if obj == nil then return false end
    local sprite = nil
    pcall(function() sprite = obj:getSprite() end)
    if sprite == nil then return false end
    local name = nil
    pcall(function() name = sprite:getName() end)
    if name ~= nil and string.find(name, "fixtures_bathroom", 1, true) == 1 then return false end
    if sitIsRealBed(obj) then return false end
    local n = 0
    pcall(function() n = SeatingManager.getInstance():getTilePositionCount(obj) or 0 end)
    return n > 0
end

local function sitSquareFree(sq)
    if sq == nil then return false end
    local ok = false
    pcall(function()
        if not sq:isFree(false) then return end
        ok = true
        if sq:isVehicleIntersecting() or sq:isWaterSquare() then ok = false end
    end)
    return ok
end

local function sitWalkable(walkSq, seatSq)
    if walkSq == nil or seatSq == nil then return false end
    local ok = false
    pcall(function()
        if not sitSquareFree(walkSq) then return end
        ok = true
        if not walkSq:isSolidFloor() or walkSq:HasStairs() then ok = false return end
        local ddx = math.abs(walkSq:getX() - seatSq:getX())
        local ddy = math.abs(walkSq:getY() - seatSq:getY())
        if ddx + ddy == 1 then
            if seatSq:isWallTo(walkSq) or seatSq:getDoorTo(walkSq) ~= nil or seatSq:getWindowTo(walkSq) ~= nil then
                ok = false
            end
        end
    end)
    return ok
end

local function sitWalkSquareFor(seatSq, sx, sy)
    local x0, y0, z = seatSq:getX(), seatSq:getY(), seatSq:getZ()
    local fx, fy = math.floor(sx), math.floor(sy)
    if fx ~= x0 or fy ~= y0 then return getCell():getGridSquare(fx, fy, z) end
    local lx, ly = sx - x0 - 0.5, sy - y0 - 0.5
    if math.abs(lx) >= math.abs(ly) then
        return getCell():getGridSquare(x0 + (lx >= 0 and 1 or -1), y0, z)
    end
    return getCell():getGridSquare(x0, y0 + (ly >= 0 and 1 or -1), z)
end

function BridgeTask.seatTaken(plan, body)
    if plan == nil or plan.obj == nil then return false end
    local taken = false
    pcall(function() taken = plan.obj:isFurnitureOccupied(body) == true end)
    if taken then return true end
    local red = BridgeData.owner()
    if red ~= nil then
        pcall(function() if red:isSitOnFurnitureObject(plan.obj) then taken = true end end)
    end
    if taken then return true end
    pcall(function()
        local sq = plan.obj:getSquare()
        if sq == nil then return end
        local movers = sq:getMovingObjects()
        for i = 0, movers:size() - 1 do
            local m = movers:get(i)
            if m ~= nil and m ~= body and instanceof(m, "IsoGameCharacter") and not m:isDead() then
                taken = true
                return
            end
        end
    end)
    return taken
end

local function sitObjFacing(obj)
    local name = nil
    pcall(function()
        local d = SeatingManager.getInstance():getFacingDirection(obj)
        if type(d) == "string" then
            name = d
        elseif d ~= nil then
            name = tostring(d:name())
        end
    end)
    if name == nil then
        pcall(function()
            local d = obj:getDir()
            if d ~= nil then name = d:name() end
        end)
    end
    return name
end

function BridgeTask.seatPlan(body, obj)
    if body == nil or obj == nil or not BridgeTask.seatIsSeat(obj) then return nil end
    local seatSq, sprite = nil, nil
    pcall(function() seatSq = obj:getSquare() end)
    pcall(function() sprite = obj:getSprite() end)
    if seatSq == nil or sprite == nil then return nil end
    local z = seatSq:getZ()
    local cx, cy = seatSq:getX() + 0.5, seatSq:getY() + 0.5
    local bx, by = body:getX(), body:getY()
    local sm = nil
    pcall(function() sm = SeatingManager.getInstance() end)

    local facing = sitObjFacing(obj)

    local eng = nil
    if sm ~= nil then
        local best, bestD = nil, nil
        for _, dir in ipairs(SIT_DIRS) do
            for _, side in ipairs(SIT_SIDES) do
                local pos = nil
                pcall(function() pos = Vector3f.new() end)
                if pos ~= nil then
                    local valid = false
                    pcall(function()
                        valid = sm:getAdjacentPosition(body, obj, dir, side, "idle",
                            "SitOnFurniture" .. side .. "_NA", pos) == true
                    end)
                    if valid then
                        local sx, sy = pos:x(), pos:y()
                        local wsq = sitWalkSquareFor(seatSq, sx, sy)
                        if wsq ~= nil and wsq ~= seatSq and sitWalkable(wsq, seatSq) then
                            local d = sitDist(bx, by, sx, sy)
                            if bestD == nil or d < bestD then
                                best = { dir = dir, side = side, standX = sx, standY = sy,
                                    sx = wsq:getX(), sy = wsq:getY() }
                                bestD = d
                            end
                        end
                    end
                end
            end
        end
        eng = best
    end

    local dir = facing or (eng and eng.dir)

    local function sitSeatBlocks(wx, wy)
        local x0, y0 = body:getX(), body:getY()
        local dx, dy = wx - x0, wy - y0
        local dist = math.sqrt(dx * dx + dy * dy)
        local steps = math.max(1, math.ceil(dist / 0.25))
        for i = 1, steps - 1 do
            local t = i / steps
            if math.floor(x0 + dx * t) == seatSq:getX()
                    and math.floor(y0 + dy * t) == seatSq:getY() then
                return true
            end
        end
        return false
    end

    local function sitReachable(sqx, sqy)
        if sitSeatBlocks(sqx + 0.5, sqy + 0.5) then return false end
        if BridgeMove == nil or BridgeMove.walkReach == nil then return true end
        local res = true
        pcall(function() res = BridgeMove.walkReach(body, sqx, sqy, z, 4000) ~= false end)
        return res
    end

    local standX, standY, sx, sy = nil, nil, nil, nil
    if dir ~= nil then
        local fo = SIT_FACING_OFF[dir]
        if fo ~= nil then
            local cand = getCell():getGridSquare(seatSq:getX() - fo[1], seatSq:getY() - fo[2], z)
            if sitWalkable(cand, seatSq) and sitReachable(cand:getX(), cand:getY()) then
                standX, standY, sx, sy = cand:getX() + 0.5, cand:getY() + 0.5, cand:getX(), cand:getY()
            end
        end
    end
    if standX == nil and eng ~= nil and sitReachable(eng.sx, eng.sy) then
        standX, standY, sx, sy = eng.standX, eng.standY, eng.sx, eng.sy
    end
    if standX == nil then
        local bestD = nil
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    local cand = getCell():getGridSquare(seatSq:getX() + dx, seatSq:getY() + dy, z)
                    if sitWalkable(cand, seatSq) and sitReachable(cand:getX(), cand:getY()) then
                        local d = sitDist(bx, by, cand:getX() + 0.5, cand:getY() + 0.5)
                        if bestD == nil or d < bestD then
                            standX, standY, sx, sy = cand:getX() + 0.5, cand:getY() + 0.5, cand:getX(), cand:getY()
                            bestD = d
                        end
                    end
                end
            end
        end
    end
    if standX == nil then return nil end

    if dir == nil then
        if math.abs(cx - standX) >= math.abs(cy - standY) then
            dir = cx > standX and "E" or "W"
        else
            dir = cy > standY and "S" or "N"
        end
    end

    local tx, ty = 0, 0
    if sm ~= nil then
        pcall(function()
            local xln = sm:getTranslation(sprite, dir, Vector3f.new())
            if xln ~= nil then tx, ty = xln:x(), xln:y() end
        end)
    end
    if math.abs(tx) > SIT_MAX_TRANSLATION or math.abs(ty) > SIT_MAX_TRANSLATION then return nil end
    return { obj = obj, dir = dir, side = "Front", standX = standX, standY = standY,
        sx = sx, sy = sy, seatX = cx + tx, seatY = cy + ty, z = z,
        walkX = sx + 0.5, walkY = sy + 0.5,
        engDir = (eng and eng.dir) or nil }
end


local BED_RULES = {
    N = { axis = "y", footPos = 0, toHead = "S", step = { 0, -1 } },
    S = { axis = "y", footPos = 1, toHead = "N", step = { 0, 1 } },
    W = { axis = "x", footPos = 0, toHead = "E", step = { -1, 0 } },
    E = { axis = "x", footPos = 1, toHead = "W", step = { 1, 0 } },
}

local function bedDirOf(name)
    if name == "N" then return IsoDirections.N end
    if name == "S" then return IsoDirections.S end
    if name == "E" then return IsoDirections.E end
    return IsoDirections.W
end

local function bedObjectAt(sq)
    if sq == nil then return nil end
    local found = nil
    pcall(function()
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            if sitIsRealBed(o) then found = o return end
        end
    end)
    return found
end

local function bedInfo(obj)
    if obj == nil or not sitIsRealBed(obj) then return nil end
    local sprite, sq = nil, nil
    pcall(function() sprite = obj:getSprite() end)
    pcall(function() sq = obj:getSquare() end)
    if sprite == nil or sq == nil then return nil end
    local grid = nil
    pcall(function() grid = sprite:getSpriteGrid() end)
    if grid == nil then return nil end
    local facing = nil
    pcall(function() facing = sprite:getProperties():get("Facing") end)
    if BED_RULES[facing] == nil then
        pcall(function()
            local d = SeatingManager.getInstance():getFacingDirection(obj)
            if type(d) == "string" then facing = d elseif d ~= nil then facing = tostring(d:name()) end
        end)
    end
    local rule = BED_RULES[facing]
    if rule == nil then facing, rule = "S", BED_RULES.S end
    local w, h = grid:getWidth(), grid:getHeight()
    if rule.axis == "x" and w == 1 and h >= 2 then
        facing, rule = "S", BED_RULES.S
    elseif rule.axis == "y" and h == 1 and w >= 2 then
        facing, rule = "E", BED_RULES.E
    end
    local head = obj
    local pos = rule.axis == "y" and grid:getSpriteGridPosY(sprite) or grid:getSpriteGridPosX(sprite)
    if pos == rule.footPos then
        local adj = nil
        pcall(function() adj = sq:getAdjacentSquare(bedDirOf(rule.toHead)) end)
        local o = bedObjectAt(adj)
        if o == nil then return nil end
        head = o
        sq = adj
    end
    local hx, hy, hz = sq:getX(), sq:getY(), sq:getZ()
    local sx, sy = rule.step[1], rule.step[2]
    return { obj = head, key = hx .. "," .. hy .. "," .. hz, x = hx, y = hy, z = hz,
        facing = facing, lieX = hx + 0.5, lieY = hy + 0.5,
        faceX = hx + 0.5 + sx * 5, faceY = hy + 0.5 + sy * 5, stepX = sx, stepY = sy }
end


local function bedParts(obj)
    local parts, seen = {}, {}
    local function add(o)
        if o == nil or seen[o] then return end
        seen[o] = true
        if sitIsRealBed(o) then parts[#parts + 1] = o end
    end
    add(obj)
    pcall(function()
        local sq = obj:getSquare()
        if sq == nil then return end
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do add(objs:get(i)) end
        for _, d in ipairs({ IsoDirections.N, IsoDirections.S, IsoDirections.E, IsoDirections.W }) do
            local adj = nil
            pcall(function() adj = sq:getAdjacentSquare(d) end)
            if adj ~= nil then
                local a = adj:getObjects()
                for i = 0, a:size() - 1 do add(a:get(i)) end
            end
        end
    end)
    return parts
end


function BridgeTask.layPlayerOnBed(plan)
    if plan == nil or plan.obj == nil then return false end
    local red = BridgeData ~= nil and BridgeData.owner() or nil
    if red == nil then return false end
    local on = false
    pcall(function() on = red:isOnBed() == true end)
    if not on then return false end
    local same = false
    pcall(function()
        local b = red:getBed()
        if b == nil or b == plan.obj then same = true end
    end)
    if same then return true end
    local psq = nil
    pcall(function() psq = red:getCurrentSquare() end)
    if psq ~= nil then
        local parts = bedParts(plan.obj)
        for _, bed in ipairs(parts) do
            local sq = nil
            pcall(function() sq = bed:getSquare() end)
            if sq ~= nil and sq == psq then return true end
        end
    end
    return false
end


function BridgeTask.bedPlan(body, obj)
    if body == nil or obj == nil or not sitIsRealBed(obj) then return nil end
    local red = BridgeData ~= nil and BridgeData.owner() or nil
    local px, py = body:getX(), body:getY()
    if red ~= nil then px, py = red:getX(), red:getY() end
    local rx, ry = body:getX(), body:getY()

    local best, seen = nil, {}
    local parts = bedParts(obj)
    for _, part in ipairs(parts) do
        local info = bedInfo(part)
        if info ~= nil and not seen[info.key] then
            seen[info.key] = true
            local spot = nil
            pcall(function() spot = freeAdjacent(body, { x = info.x, y = info.y, z = info.z }) end)
            if spot == nil then
                pcall(function()
                    spot = freeAdjacent(body, { x = info.x + info.stepX, y = info.y + info.stepY, z = info.z })
                end)
            end
            if spot ~= nil then
                local pdist = sitDist(px, py, info.lieX, info.lieY)
                local rdist = sitDist(rx, ry, spot.x + 0.5, spot.y + 0.5)
                local left = (info.stepX + info.stepY) < 0
                local cand = { obj = info.obj, key = info.key, z = info.z, facing = info.facing,
                    dir = info.facing, side = "Front",
                    lieX = info.lieX, lieY = info.lieY, faceX = info.faceX, faceY = info.faceY,
                    seatX = info.lieX, seatY = info.lieY,
                    standX = spot.x + 0.5, standY = spot.y + 0.5,
                    sx = spot.x, sy = spot.y, walkX = spot.x + 0.5, walkY = spot.y + 0.5,
                    entry = left and "LayDownLeft" or "LayDownRight",
                    pdist = pdist, rdist = rdist }
                local take = false
                if best == nil then
                    take = true
                elseif math.abs(cand.pdist - best.pdist) > 0.6 then
                    take = cand.pdist > best.pdist
                else
                    take = cand.rdist < best.rdist
                end
                if take then best = cand end
            end
        end
    end

    if best == nil then
        local bed = parts[1] or obj
        local sq = nil
        pcall(function() sq = bed:getSquare() end)
        if sq ~= nil then
            local z = sq:getZ()
            local spot = freeAdjacent(body, { x = sq:getX(), y = sq:getY(), z = z })
            if spot ~= nil then
                local cx, cy = sq:getX() + 0.5, sq:getY() + 0.5
                best = { obj = bed, key = sq:getX() .. "," .. sq:getY() .. "," .. z, z = z,
                    facing = "S", dir = "S", side = "Front",
                    lieX = cx, lieY = cy, faceX = cx, faceY = cy + 5, seatX = cx, seatY = cy,
                    standX = spot.x + 0.5, standY = spot.y + 0.5,
                    sx = spot.x, sy = spot.y, walkX = spot.x + 0.5, walkY = spot.y + 0.5,
                    entry = "LayDownLeft", pdist = 0, rdist = 0 }
                log("lay: bedPlan fell back to the bed tile centre")
            end
        end
    end
    return best
end

local function sitApplyDown(body, plan)
    pcall(function() BridgeMove.stopPath(body) end)
    if BridgeMove ~= nil then BridgeMove.moving = false end
    local face = sitFaceOf(plan.side, plan.dir)
    pcall(function() body:setSitOnFurnitureObject(plan.obj) end)
    pcall(function()
        body:setX(plan.standX) body:setY(plan.standY)
        body:setLastX(plan.standX) body:setLastY(plan.standY)
    end)
    BridgeTask.sitFromX, BridgeTask.sitFromY = plan.standX, plan.standY
    BridgeTask.sitSlideAt = Bridge.time
    pcall(function() if face ~= nil then body:setSitOnFurnitureDirection(face) end end)
    pcall(function() body:setSittingOnFurniture(true) end)
    pcall(function() body:setCollidable(false) end)
    pcall(function() body:setVariable("SitOnFurnitureDirection", plan.side) end)
    pcall(function() body:setVariable("SitOnFurnitureStarted", true) end)
    pcall(function() plan.obj:setSatChair(true) end)
    pcall(function() if face ~= nil then body:faceDirection(face) end end)
    pcall(function() body:setVariable("BumpAnimFinished", false) end)
    pcall(function() body:setBumpType("SitChairDown") end)
end

local function sitClear(body, plan)
    if body ~= nil then
        pcall(function()
            body:setSittingOnFurniture(false)
            body:setSitOnFurnitureObject(nil)
            body:setCollidable(true)
        end)
        pcall(function() body:clearVariable("SitOnFurnitureDirection") end)
        pcall(function() body:clearVariable("SitOnFurnitureStarted") end)
        pcall(function()
            if tostring(body:getActionStateName()) == "bumped" then body:setVariable("BumpAnimFinished", true) end
            local b = tostring(body:getBumpType())
            if b == "SitChair" or b == "SitChairDown" or b == "SitChairUp" then body:setBumpType("") end
        end)
        if plan ~= nil and plan.sx ~= nil and plan.obj ~= nil then
            pcall(function()
                local sq = plan.obj:getSquare()
                if sq ~= nil and body:getCurrentSquare() == sq then
                    body:setX(plan.sx + 0.5) body:setY(plan.sy + 0.5)
                    body:setLastX(plan.sx + 0.5) body:setLastY(plan.sy + 0.5)
                    local wsq = getCell():getGridSquare(plan.sx, plan.sy, math.floor(plan.z))
                    if wsq ~= nil then body:setCurrent(wsq) end
                end
            end)
        end
    end
    if plan ~= nil and plan.obj ~= nil then pcall(function() plan.obj:setSatChair(false) end) end
    Bridge.pose = nil
    if BridgeMove ~= nil then pcall(BridgeMove.sendSit, nil) end
end

function BridgeTask.isSitting(body)
    body = body or Bridge.body
    if body == nil then return false end
    if BridgeTask.active and BridgeTask.kind == "sit" then return true end
    local bump = ""
    pcall(function() bump = tostring(body:getBumpType()) end)
    return bump == "SitChair" or bump == "SitChairDown" or bump == "SitChairUp"
end

function BridgeTask.isSeated(body)
    body = body or Bridge.body
    if body == nil then return false end
    if BridgeTask.active and BridgeTask.kind == "sit" and BridgeTask.phase == "sit" then return true end
    if BridgeMove ~= nil and BridgeMove.seat ~= nil and BridgeMove.seat.phase == "sit" then return true end
    local bump = ""
    pcall(function() bump = tostring(body:getBumpType()) end)
    return bump == "SitChair"
end

function BridgeTask.sitStandUp()
    if BridgeTask.active and BridgeTask.kind == "sit" then
        BridgeTask.sitUp = true
        return
    end
    sitClear(Bridge.body, nil)
end

BridgeTask.kinds.sit = {}

function BridgeTask.kinds.sit.available(body)
    return BridgeTask.SIT_ENABLED == 1
end

function BridgeTask.kinds.sit.missing(body)
    return nil
end

function BridgeTask.kinds.sit.update(body)
    if BridgeTask.SIT_ENABLED ~= 1 then return BridgeTask.finish() end

    local target = BridgeTask.current
    if target == nil then
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        target = table.remove(BridgeTask.queue, 1)
        local obj = target.obj
        if obj == nil then
            pcall(function() obj = getCell():getGridSquare(target.x, target.y, target.z) end)
        end
        local plan = BridgeTask.seatPlan(body, obj)
        if plan == nil then
            BridgeTask.info = "sit: no seat plan"
            BridgeTask.markUnreachable(nil)
            return BridgeTask.finish()
        end
        if BridgeTask.seatTaken(plan, body) then
            Bridge.speak("SitOccupied")
            BridgeTask.info = "sit: seat occupied"
            return BridgeTask.finish()
        end
        BridgeTask.current = target
        BridgeTask.sitPlan = plan
        BridgeTask.sitUp = nil
        BridgeTask.sitAnimSeen = false
        BridgeTask.sitPathFails = 0
        BridgeTask.sitFailTick = nil
        BridgeTask.sitBestD = nil
        BridgeTask.sitCloseAt = nil
        BridgeTask.sitFromX, BridgeTask.sitFromY, BridgeTask.sitSlideAt = nil, nil, nil
    BridgeTask.layPlan = nil
    BridgeTask.layUp = nil
    BridgeTask.laySleep = false
    BridgeTask.layAnim = nil
    BridgeTask.layAnimSeen = false
    BridgeTask.layHintSaid = false
    BridgeTask.layCloseAt = nil
    BridgeTask.layFromX, BridgeTask.layFromY, BridgeTask.laySlideAt = nil, nil, nil
        BridgeTask.phase = "walk"
        BridgeTask.since = Bridge.time
        BridgeTask.progressAt = Bridge.time
        BridgeTask.bestD = nil
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
        BridgeTask.spot = nil
        BridgeTask.still = 0
        BridgeTask.checkX, BridgeTask.checkY = nil, nil
        BridgeTask.detour = nil
        pcall(function()
            local sq = plan.obj:getSquare()
            log(string.format("sit: seat %s at %s, stand %.2f,%.2f facing %s (engine %s)",
                tostring(sq and (sq:getX() .. "," .. sq:getY()) or "?"), tostring(plan.obj),
                plan.standX, plan.standY, tostring(plan.dir), tostring(plan.engDir)))
        end)
    end

    local plan = BridgeTask.sitPlan
    if plan == nil then return BridgeTask.finish() end
    local phase = BridgeTask.phase or "walk"

    if phase == "walk" then
        local sx, sy = plan.sx, plan.sy
        if sx == nil or sy == nil then
            BridgeTask.info = "sit: no stand square"
            BridgeTask.markUnreachable(nil)
            return BridgeTask.finish()
        end
        local walk, why = BridgeTask.walkTo(body, { x = sx, y = sy, z = plan.z },
            BridgeTask.STOP_DIST, true, true)
        if walk == "unreachable" then
            BridgeTask.info = "sit: no path to seat"
            BridgeTask.markUnreachable(why)
            return BridgeTask.finish()
        end
        local d = sitDist(body:getX(), body:getY(), sx + 0.5, sy + 0.5)
        local arrive = walk == "arrived"
        if not arrive and d <= 0.75 then
            BridgeTask.sitCloseAt = BridgeTask.sitCloseAt or Bridge.time
            if (Bridge.time - BridgeTask.sitCloseAt) > 0.5 * SECOND then arrive = true end
        elseif not arrive then
            BridgeTask.sitCloseAt = nil
        end
        if arrive then
            pcall(function() BridgeMove.stopPath(body) end)
            if BridgeMove ~= nil then BridgeMove.moving = false end
            Bridge.target = nil
            BridgeTask.phase = "down"
            BridgeTask.since = Bridge.time
            BridgeTask.sitAnimSeen = false
            sitApplyDown(body, plan)
            Bridge.speak("Sit")
            return true
        end
        BridgeTask.info = "sit: walking to seat"
        return true
    end

    if phase == "down" then
        local dur = 0.9 * SECOND
        local t = (Bridge.time - (BridgeTask.sitSlideAt or BridgeTask.since or Bridge.time)) / dur
        if t > 1 then t = 1 end
        local e = t * t * (3 - 2 * t)
        local fromX = BridgeTask.sitFromX or plan.standX
        local fromY = BridgeTask.sitFromY or plan.standY
        local nx = fromX + (plan.seatX - fromX) * e
        local ny = fromY + (plan.seatY - fromY) * e
        pcall(function() body:setX(nx) body:setY(ny) body:setLastX(nx) body:setLastY(ny) end)
        local face = sitFaceOf(plan.side, plan.dir)
        pcall(function() if face ~= nil then body:faceDirection(face) end end)

        local bump, fin = "", false
        pcall(function() bump = tostring(body:getBumpType()) end)
        pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
        if bump == "SitChairDown" then BridgeTask.sitAnimSeen = true end
        local clipDone = BridgeTask.sitAnimSeen and (fin or bump ~= "SitChairDown")
        if (clipDone and t >= 1) or (Bridge.time - (BridgeTask.since or Bridge.time)) > BridgeTask.SIT_ANIM_MAX then
            pcall(function()
                body:setX(plan.seatX) body:setY(plan.seatY)
                body:setLastX(plan.seatX) body:setLastY(plan.seatY)
            end)
            pcall(function()
                local wsq = getCell():getGridSquare(math.floor(plan.seatX), math.floor(plan.seatY), math.floor(plan.z))
                if wsq ~= nil then body:setCurrent(wsq) end
            end)
            BridgeTask.phase = "sit"
            BridgeTask.since = Bridge.time
            pcall(function() body:setVariable("BumpAnimFinished", false) end)
            pcall(function() body:setBumpType("SitChair") end)
            Bridge.pose = { anim = "SitChair", seat = true }
            pcall(function() BridgeMove.sendSit("chair") end)
            log("sit: seated")
        end
        BridgeTask.info = "sit: sitting down"
        return true
    end

    if phase == "sit" then
        pcall(function() body:setVariable("SitOnFurnitureStarted", true) end)
        pcall(function() if tostring(body:getBumpType()) ~= "SitChair" then body:setBumpType("SitChair") end end)
        Bridge.pose = { anim = "SitChair", seat = true }
        local face = sitFaceOf(plan.side, plan.dir)
        pcall(function() if face ~= nil then body:faceDirection(face) end end)
        local d = sitDist(body:getX(), body:getY(), plan.seatX, plan.seatY)
        if d > BridgeTask.SIT_SETTLE then
            pcall(function()
                body:setX(plan.seatX) body:setY(plan.seatY)
                body:setLastX(plan.seatX) body:setLastY(plan.seatY)
            end)
        end
        pcall(function()
            if BridgeFight ~= nil and BridgeFight.rest ~= nil then BridgeFight.rest(false, true) end
        end)
        if BridgeTask.sitUp then
            BridgeTask.sitUp = nil
            BridgeTask.phase = "up"
            BridgeTask.since = Bridge.time
            BridgeTask.sitAnimSeen = false
            pcall(function() body:setVariable("BumpAnimFinished", false) end)
            pcall(function() body:setBumpType("SitChairUp") end)
            Bridge.pose = { anim = "SitChairUp", seat = true }
            pcall(function() BridgeMove.sendSit(nil) end)
            Bridge.speak("StandUp")
            return true
        end
        BridgeTask.info = "sitting"
        return true
    end

    if phase == "up" then
        local dur = 0.9 * SECOND
        local t = (Bridge.time - (BridgeTask.since or Bridge.time)) / dur
        if t > 1 then t = 1 end
        local e = t * t * (3 - 2 * t)
        local nx = plan.seatX + (plan.standX - plan.seatX) * e
        local ny = plan.seatY + (plan.standY - plan.seatY) * e
        pcall(function() body:setX(nx) body:setY(ny) body:setLastX(nx) body:setLastY(ny) end)
        local bump, fin = "", false
        pcall(function() bump = tostring(body:getBumpType()) end)
        pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
        if bump == "SitChairUp" then BridgeTask.sitAnimSeen = true end
        local clipDone = BridgeTask.sitAnimSeen and (fin or bump ~= "SitChairUp")
        if (clipDone and t >= 1) or (Bridge.time - (BridgeTask.since or Bridge.time)) > BridgeTask.SIT_ANIM_MAX then
            sitClear(body, plan)
            return BridgeTask.finish()
        end
        BridgeTask.info = "sit: standing up"
        return true
    end

    BridgeTask.phase = "walk"
    return true
end

function BridgeTask.kinds.sit.leave(body)
    sitClear(body, BridgeTask.sitPlan)
    BridgeTask.sitPlan = nil
    BridgeTask.sitUp = nil
end


local function placeAt(body, x, y, z)
    pcall(function()
        body:setX(x) body:setY(y)
        if z ~= nil then body:setZ(z) end
        body:setLastX(x) body:setLastY(y)
        if z ~= nil then body:setLastZ(z) end
        body:setCurrentSquareFromPosition(x, y, z or body:getZ())
        body:setMovingSquareNow()
    end)
end

local function bedJoin(body, plan)
    if body == nil or plan == nil or plan.obj == nil then return end
    local face = nil
    pcall(function() face = sitFaceOf(plan.side or "Front", plan.dir or plan.facing or "S") end)
    if face == nil then pcall(function() face = bedDirOf(plan.facing or "S") end) end
    local ok = false
    pcall(function()
        body:setSitOnFurnitureObject(plan.obj)
        if face ~= nil then body:setSitOnFurnitureDirection(face) end
        ok = true
    end)
    if not ok then return end
    pcall(function() plan.obj:setSatChair(true) end)
    pcall(function() body:setSittingOnFurniture(true) end)
    pcall(function() body:setVariable("SitOnFurnitureDirection", plan.side or "Front") end)
    pcall(function() body:setVariable("SitOnFurnitureStarted", true) end)
end

local function bedUnjoin(body, plan)
    if body ~= nil then
        pcall(function()
            body:setSittingOnFurniture(false)
            body:setSitOnFurnitureObject(nil)
        end)
        pcall(function() body:clearVariable("SitOnFurnitureDirection") end)
        pcall(function() body:clearVariable("SitOnFurnitureStarted") end)
    end
    if plan ~= nil and plan.obj ~= nil then pcall(function() plan.obj:setSatChair(false) end) end
end

local function lieAt(body, plan)
    pcall(function()
        body:setX(plan.lieX or plan.seatX)
        body:setY(plan.lieY or plan.seatY)
        body:setZ(plan.z)
        body:setLastX(plan.lieX or plan.seatX)
        body:setLastY(plan.lieY or plan.seatY)
        body:setLastZ(plan.z)
    end)
    pcall(function() body:faceLocationF(plan.faceX, plan.faceY) end)
end

local function bedApplyDown(body, plan)
    pcall(function() BridgeMove.stopPath(body) end)
    if BridgeMove ~= nil then BridgeMove.moving = false end
    placeAt(body, plan.standX, plan.standY, plan.z)
    bedJoin(body, plan)
    BridgeTask.layFromX, BridgeTask.layFromY = plan.standX, plan.standY
    BridgeTask.laySlideAt = Bridge.time
    pcall(function() body:setCollidable(false) end)
    pcall(function() body:setVariable("BumpAnimFinished", false) end)
end

local function bedClear(body, plan)
    bedUnjoin(body, plan)
    if body ~= nil then
        pcall(function() body:setCollidable(true) end)
        pcall(function()
            local b = tostring(body:getBumpType())
            if b == BridgeTask.LAY_AWAKE or b == BridgeTask.LAY_ASLEEP then body:setBumpType("") end
        end)
        if plan ~= nil and plan.sx ~= nil and plan.sy ~= nil then
            pcall(function()
                placeAt(body, plan.sx + 0.5, plan.sy + 0.5, plan.z)
            end)
        end
    end
    Bridge.pose = nil
    if BridgeMove ~= nil then pcall(BridgeMove.sendSit, nil) end
end


function BridgeTask.isLying(body)
    body = body or Bridge.body
    if BridgeTask.active and BridgeTask.kind == "lay" and BridgeTask.phase == "lie" then return true end
    if body == nil then return false end
    local bump = ""
    pcall(function() bump = tostring(body:getBumpType()) end)
    return bump == BridgeTask.LAY_AWAKE or bump == BridgeTask.LAY_ASLEEP
end

function BridgeTask.layStandUp()
    if BridgeTask.active and BridgeTask.kind == "lay" then
        BridgeTask.layUp = true
        return
    end
    bedClear(Bridge.body, nil)
end

function BridgeTask.layToggleSleep()
    if not (BridgeTask.active and BridgeTask.kind == "lay") then return false end
    BridgeTask.laySleep = not BridgeTask.laySleep
    BridgeTask.layAnim = BridgeTask.laySleep and BridgeTask.LAY_ASLEEP or BridgeTask.LAY_AWAKE
    if BridgeTask.laySleep then Bridge.speak("Sleep") else Bridge.speak("Wake") end
    return true
end

function BridgeTask.layClose()
    local r = nil
    pcall(function() r = BridgeData.relOf(Bridge.store) end)
    local romance = false
    pcall(function() romance = BridgeSocial.romanceOn() end)
    return romance and r ~= nil and (r.r or 0) >= 40
end

BridgeTask.kinds.lay = {}

function BridgeTask.kinds.lay.available(body)
    return BridgeTask.LAY_ENABLED == 1
end

function BridgeTask.kinds.lay.missing(body)
    return nil
end

function BridgeTask.kinds.lay.update(body)
    if BridgeTask.LAY_ENABLED ~= 1 then return BridgeTask.finish() end

    local target = BridgeTask.current
    if target == nil then
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        target = table.remove(BridgeTask.queue, 1)
        local obj = target.obj
        if obj == nil then
            pcall(function() obj = getCell():getGridSquare(target.x, target.y, target.z) end)
        end
        local plan = BridgeTask.bedPlan(body, obj)
        if plan == nil then
            BridgeTask.info = "lay: no bed plan"
            BridgeTask.markUnreachable(nil)
            return BridgeTask.finish()
        end
        if BridgeTask.layPlayerOnBed(plan) then
            Bridge.speak("LayPlayerOn")
            BridgeTask.info = "lay: player is on the bed"
            return BridgeTask.finish()
        end
        if BridgeTask.seatTaken(plan, body) then
            Bridge.speak("LayOccupied")
            BridgeTask.info = "lay: bed occupied"
            return BridgeTask.finish()
        end
        BridgeTask.current = target
        BridgeTask.layPlan = plan
        BridgeTask.layUp = nil
        BridgeTask.laySleep = false
        BridgeTask.layAnim = BridgeTask.LAY_AWAKE
        BridgeTask.layAnimSeen = false
        BridgeTask.layHintSaid = false
        BridgeTask.layCloseAt = nil
        BridgeTask.layFromX, BridgeTask.layFromY, BridgeTask.laySlideAt = nil, nil, nil
        BridgeTask.phase = "walk"
        BridgeTask.since = Bridge.time
        BridgeTask.progressAt = Bridge.time
        BridgeTask.bestD = nil
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
        BridgeTask.spot = nil
        BridgeTask.still = 0
        BridgeTask.checkX, BridgeTask.checkY = nil, nil
        BridgeTask.detour = nil
        pcall(function()
            local sq = plan.obj:getSquare()
            log(string.format("lay: bed %s, lie %.2f,%.2f stand %.2f,%.2f side %s dir %s",
                tostring(sq and (sq:getX() .. "," .. sq:getY()) or "?"),
                plan.seatX, plan.seatY, plan.standX, plan.standY, tostring(plan.side), tostring(plan.dir)))
        end)
    end

    local plan = BridgeTask.layPlan
    if plan == nil then return BridgeTask.finish() end
    local phase = BridgeTask.phase or "walk"

    if phase == "walk" then
        local sx, sy = plan.sx, plan.sy
        if sx == nil or sy == nil then
            BridgeTask.info = "lay: no stand square"
            BridgeTask.markUnreachable(nil)
            return BridgeTask.finish()
        end
        local walk, why = BridgeTask.walkTo(body, { x = sx, y = sy, z = plan.z },
            BridgeTask.STOP_DIST, true, true)
        if walk == "unreachable" then
            BridgeTask.info = "lay: no path to bed"
            BridgeTask.markUnreachable(why)
            return BridgeTask.finish()
        end
        local d = sitDist(body:getX(), body:getY(), sx + 0.5, sy + 0.5)
        local arrive = walk == "arrived"
        if not arrive and d <= 0.75 then
            BridgeTask.layCloseAt = BridgeTask.layCloseAt or Bridge.time
            if (Bridge.time - BridgeTask.layCloseAt) > 0.5 * SECOND then arrive = true end
        elseif not arrive then
            BridgeTask.layCloseAt = nil
        end
        if arrive then
            pcall(function() BridgeMove.stopPath(body) end)
            if BridgeMove ~= nil then BridgeMove.moving = false end
            Bridge.target = nil
            BridgeTask.phase = "down"
            BridgeTask.since = Bridge.time
            BridgeTask.layAnimSeen = false
            bedApplyDown(body, plan)
            Bridge.speak("Lay")
            return true
        end
        BridgeTask.info = "lay: walking to bed"
        return true
    end

    if phase == "down" then
        lieAt(body, plan)
        bedJoin(body, plan)
        pcall(function() body:setVariable("BumpAnimFinished", false) end)
        pcall(function() body:setBumpType(BridgeTask.laySleep and BridgeTask.LAY_ASLEEP or BridgeTask.LAY_AWAKE) end)
        Bridge.pose = nil
        pcall(function() BridgeMove.sendSit(BridgeTask.laySleep and "bedasleep" or "bedawake") end)
        if not BridgeTask.layHintSaid then
            BridgeTask.layHintSaid = true
            pcall(function()
                Bridge.speak(BridgeTask.layClose() and "LayHint" or "LayHintPlain")
            end)
        end
        BridgeTask.phase = "lie"
        BridgeTask.since = Bridge.time
        log(string.format("lay: lying at %.2f,%.2f z=%.3f facing %s sit=%s",
            plan.lieX or plan.seatX, plan.lieY or plan.seatY, body:getZ(), tostring(plan.facing),
            tostring(body:getVariableBoolean("SitOnFurnitureStarted"))))
        BridgeTask.info = "lying"
        return true
    end

    if phase == "lie" then
        local anim = BridgeTask.laySleep and BridgeTask.LAY_ASLEEP or BridgeTask.LAY_AWAKE
        BridgeTask.layAnim = anim
        bedJoin(body, plan)
        pcall(function() if tostring(body:getBumpType()) ~= anim then body:setBumpType(anim) end end)
        Bridge.pose = nil
        local lx = plan.lieX or plan.seatX
        local ly = plan.lieY or plan.seatY
        local d = sitDist(body:getX(), body:getY(), lx, ly)
        if d > BridgeTask.LAY_SETTLE or math.abs(body:getZ() - plan.z) > 0.05 then
            lieAt(body, plan)
        end
        if BridgeTask.layUp then
            BridgeTask.layUp = nil
            BridgeTask.phase = "up"
            BridgeTask.since = Bridge.time
            bedUnjoin(body, plan)
            pcall(function() body:setBumpType("") end)
            pcall(function() BridgeMove.sendSit(nil) end)
            Bridge.speak("GetUp")
            return true
        end
        BridgeTask.info = "lying"
        return true
    end

    if phase == "up" then
        local dur = 0.6 * SECOND
        local t = (Bridge.time - (BridgeTask.since or Bridge.time)) / dur
        if t > 1 then t = 1 end
        local e = t * t * (3 - 2 * t)
        local lx = plan.lieX or plan.seatX
        local ly = plan.lieY or plan.seatY
        local nx = lx + (plan.standX - lx) * e
        local ny = ly + (plan.standY - ly) * e
        pcall(function() body:setX(nx) body:setY(ny) body:setLastX(nx) body:setLastY(ny) end)
        if t >= 1 then
            bedClear(body, plan)
            return BridgeTask.finish()
        end
        BridgeTask.info = "lay: getting up"
        return true
    end

    BridgeTask.phase = "walk"
    return true
end

function BridgeTask.kinds.lay.leave(body)
    bedClear(body, BridgeTask.layPlan)
    BridgeTask.layPlan = nil
    BridgeTask.layUp = nil
    BridgeTask.laySleep = false
end


function BridgeTask.staleEnd(body)
    if body == nil or body ~= Bridge.body then return false end
    if not BridgeTask.active or BridgeTask.kind ~= "chopTree" then return false end
    if BridgeTask.swingStart == nil then return false end
    if (Bridge.time - BridgeTask.swingStart) > BridgeTask.ATTACK_AT then return false end
    local fin, st, bump = false, "?", ""
    pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
    if not fin then return false end
    pcall(function()
        st = tostring(body:getActionStateName())
        bump = tostring(body:getBumpType())
    end)
    if st ~= "bumped" or (bump ~= BridgeTask.CHOP_ANIM and bump ~= BridgeTask.CHOP_ANIM_B) then return false end
    return pcall(function() body:setVariable("BumpAnimFinished", false) end)
end
Events.OnTickEvenPaused.Add(function() pcall(BridgeTask.staleEnd, Bridge ~= nil and Bridge.body or nil) end)

BridgeTask.lastSpeed = nil
Events.OnTickEvenPaused.Add(function()
    local speed = nil
    pcall(function() speed = UIManager.getSpeedControls():getCurrentGameSpeed() end)
    if speed == nil then return end
    local was = BridgeTask.lastSpeed
    BridgeTask.lastSpeed = speed
    if was ~= 0 or speed <= 0 then return end
    if not BridgeTask.active then return end
    local body = Bridge.body
    if body == nil then return end
    if BridgeTask.kind == "exercise" then
        BridgeTask.exerciseRepMark = Bridge.time
        return
    end
    if BridgeTask.kind == "sit" or BridgeTask.kind == "lay" then
        local posed = false
        if BridgeMove ~= nil and BridgeMove.isOnChair ~= nil and BridgeMove.isOnChair(body) then posed = true end
        if BridgeTask.isLying ~= nil and BridgeTask.isLying(body) then posed = true end
        if posed then return end
    end
    pcall(function() BridgeMove.stopPath(body) end)
    pcall(function() BridgeTask.clearChop(body) end)


    pcall(function() body:changeState(ZombieIdleState.instance()) end)
    BridgeTask.spot = nil
    BridgeTask.swingStart = nil
    BridgeTask.attackAt = nil
    BridgeTask.animHold = 2
    BridgeTask.still = 0
    BridgeTask.checkX = nil
    BridgeTask.info = "unpaused"
    log("unpaused, task re-pathing")
end)


BridgeTask.EXERCISE_ANIM = "NA_Squat"
BridgeTask.EXERCISE_ENABLED = 1


local function exerciseConst(name, default)
    local v = nil
    if BridgeExercise ~= nil then v = BridgeExercise[name] end
    if type(v) == "number" then return v end
    return default
end


local function exerciseFatigue()
    local f = 0
    pcall(function() f = tonumber(BridgeFight and BridgeFight.fatigue) or 0 end)
    return f
end
BridgeTask.exerciseFatigue = exerciseFatigue


local function exerciseBank()
    local v = 0
    if BridgeExercise ~= nil and BridgeExercise.bankOf ~= nil then
        pcall(function() v = BridgeExercise.bankOf() end)
    end
    return tonumber(v) or 0
end
BridgeTask.exerciseBank = exerciseBank


local function exerciseClear(body)
    if body == nil then return end
    pcall(function()
        if tostring(body:getBumpType()) == BridgeTask.EXERCISE_ANIM then body:setBumpType("") end
    end)
    pcall(function() body:setVariable("BumpAnimFinished", true) end)
end


BridgeTask.kinds.exercise = {}
BridgeTask.kinds.exercise.noTargets = true
BridgeTask.kinds.exercise.restoreMode = true

function BridgeTask.kinds.exercise.available(body)
    if BridgeTask.EXERCISE_ENABLED ~= 1 then return false end
    if body == nil then return false end
    if BridgeExercise == nil or BridgeExercise.blockReason == nil then return false end
    local ok = true
    pcall(function() ok = BridgeExercise.blockReason() == nil end)
    return ok
end

function BridgeTask.kinds.exercise.missing(body)
    return nil
end

function BridgeTask.exerciseProgress()
    local stopAt = exerciseConst("STAMINA_STOP", 0.90)
    if stopAt <= 0 then stopAt = 0.90 end
    local frac = exerciseBank() / stopAt
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    if BridgeProgress ~= nil and BridgeProgress.show ~= nil then pcall(function() BridgeProgress.show(frac) end) end
    if frac >= 0.5 and not BridgeTask.exerciseHalfSaid then
        BridgeTask.exerciseHalfSaid = true
        Bridge.speak("ExerciseHalf")
    end
end


local function exerciseDrain()
    local d = exerciseConst("FATIGUE_PER_REP", 0.035)
    if BridgeExercise ~= nil and BridgeExercise.drainPerRep ~= nil then
        local v = nil
        pcall(function() v = BridgeExercise.drainPerRep() end)
        if type(v) == "number" and v > 0 then d = v end
    end
    if d <= 0 then d = 0.035 end
    return d
end
BridgeTask.exerciseDrain = exerciseDrain


function BridgeTask.kinds.exercise.update(body)
    if BridgeTask.EXERCISE_ENABLED ~= 1 then return BridgeTask.finish() end
    local anim = BridgeTask.EXERCISE_ANIM
    local stopAt = exerciseConst("STAMINA_STOP", 0.90)


    if BridgeTask.exercisePhase == nil then
        BridgeTask.exercisePhase = "active"
        BridgeTask.exerciseRepMark = Bridge.time
        BridgeTask.exerciseBudget = 0
        BridgeTask.exerciseReps = 0
        BridgeTask.exerciseHalfSaid = false
        pcall(function() body:setVariable("BumpAnimFinished", false) end)
        pcall(function() body:setBumpType(anim) end)
        if BridgeTask.exerciseMirror == true then
            pcall(function()
                local red = BridgeData.owner()
                if red ~= nil then body:faceLocationF(red:getX(), red:getY()) end
            end)
        end
        if BridgeWeapon ~= nil and BridgeWeapon.isOut ~= nil then
            local out = false
            pcall(function() out = BridgeWeapon.isOut(body) end)
            if out then
                local main, sec = nil, nil
                pcall(function() main = body:getPrimaryHandItem() end)
                pcall(function() sec = body:getSecondaryHandItem() end)
                pcall(function() BridgeWeapon.putAway(body) end)
                BridgeTask.exerciseHandMain, BridgeTask.exerciseHandSec = main, sec
                BridgeTask.exerciseStowed = true
            end
        end
        Bridge.speak("ExerciseStart")
        BridgeTask.exerciseProgress()
        BridgeTask.info = "exercise: start"
        log(string.format("exercise start mirror=%s stamina=%.2f", tostring(BridgeTask.exerciseMirror), 1 - exerciseFatigue()))
        return true
    end


    local asn = "?"
    pcall(function() asn = tostring(body:getActionStateName()) end)
    if string.sub(asn, 1, 8) == "onground" or string.sub(asn, 1, 8) == "falldown" then
        pcall(function() body:setVariable("BumpAnimFinished", false) end)
        pcall(function() body:changeState(ZombieGetUpState.instance()) end)
        BridgeTask.exerciseRepMark = Bridge.time
        return true
    end


    pcall(function()
        if tostring(body:getBumpType()) ~= anim then body:setBumpType(anim) end
    end)


    if BridgeTask.exerciseMirror == true then
        local stop = false
        pcall(function()
            local red = BridgeData.owner()
            local ex = nil
            if red ~= nil then
                local fit = nil
                pcall(function() fit = red:getFitness() end)
                if fit ~= nil then pcall(function() ex = fit:getCurrentExe() end) end
            end
            if red == nil or ex == nil then stop = true return end
        end)
        if stop then return BridgeTask.finish() end
    end


    local now = Bridge.time
    local mark = BridgeTask.exerciseRepMark or now
    BridgeTask.exerciseRepMark = now
    BridgeTask.exerciseBudget = (BridgeTask.exerciseBudget or 0) + (now - mark) * ffMult()
    local repSpan = exerciseConst("REP_TICKS", 3 * SECOND)
    if repSpan <= 0 then repSpan = 3 * SECOND end
    local reps = BridgeTask.exerciseReps or 0
    local before = reps
    local burst = 0
    while BridgeTask.exerciseBudget >= repSpan and burst < 30 do
        BridgeTask.exerciseBudget = BridgeTask.exerciseBudget - repSpan
        burst = burst + 1
        reps = reps + 1
        local d = exerciseDrain()
        pcall(function() BridgeFight.fatigue = math.min(1, (tonumber(BridgeFight and BridgeFight.fatigue) or 0) + d) end)
        if BridgeExercise ~= nil and BridgeExercise.addBank ~= nil then
            pcall(function() BridgeExercise.addBank(Bridge.store, d) end)
        end
        if ZombRand(1000) < exerciseConst("XP_CHANCE", 100) then
            if BridgeSkills ~= nil and BridgeSkills.add ~= nil then
                local m = 1
                if BridgeExercise ~= nil and BridgeExercise.mult ~= nil then
                    pcall(function() m = BridgeExercise.mult(Bridge.store) end)
                end
                local cfFit, cfStr = 1, 1
                if BridgeExercise ~= nil and BridgeExercise.catchup ~= nil then
                    pcall(function() cfFit = BridgeExercise.catchup("Fitness") end)
                    pcall(function() cfStr = BridgeExercise.catchup("Strength") end)
                end
                BridgeSkills.add("Fitness", m * cfFit, "exercise")
                BridgeSkills.add("Strength", m * cfStr, "exercise")
            end
        end
    end
    if reps ~= before then
        BridgeTask.exerciseReps = reps
        log(string.format("exercise reps %d->%d drain=%.3f fatigue=%.2f ff=%.1f", before, reps, exerciseDrain(), exerciseFatigue(), ffMult()))
        if math.floor(reps / 4) > math.floor(before / 4) then
            Bridge.speak("ExerciseEffort" .. (1 + ZombRand(3)))
        end
    end


    if exerciseBank() >= stopAt then
        return BridgeTask.kinds.exercise.stop(body)
    end

    BridgeTask.exerciseProgress()
    BridgeTask.info = "exercise: active"
    return true
end

function BridgeTask.kinds.exercise.stop(body)
    exerciseClear(body)
    local mult = 1
    if BridgeExercise ~= nil and BridgeExercise.mult ~= nil then
        pcall(function() mult = BridgeExercise.mult(Bridge.store) end)
    end
    local cfFit, cfStr = 1, 1
    if BridgeExercise ~= nil and BridgeExercise.catchup ~= nil then
        pcall(function() cfFit = BridgeExercise.catchup("Fitness") end)
        pcall(function() cfStr = BridgeExercise.catchup("Strength") end)
    end
    if BridgeSkills ~= nil and BridgeSkills.add ~= nil then
        BridgeSkills.add("Fitness", exerciseConst("LUMP_FITNESS", 40) * mult * cfFit, "exercise")
        BridgeSkills.add("Strength", exerciseConst("LUMP_STRENGTH", 40) * mult * cfStr, "exercise")
    end
    if BridgeExercise ~= nil and BridgeExercise.setCooldown ~= nil then
        pcall(function() BridgeExercise.setCooldown(Bridge.store) end)
    end
    if BridgeExercise ~= nil and BridgeExercise.recordSession ~= nil then
        pcall(function() BridgeExercise.recordSession(Bridge.store) end)
    end
    if BridgeExercise ~= nil and BridgeExercise.setBank ~= nil then
        pcall(function() BridgeExercise.setBank(Bridge.store, 0) end)
    end
    Bridge.speak("ExerciseDone")
    return BridgeTask.finish()
end

function BridgeTask.kinds.exercise.leave(body)
    exerciseClear(body)
    if BridgeTask.exerciseStowed then
        local b = body or (Bridge ~= nil and Bridge.body) or nil
        local main, sec = BridgeTask.exerciseHandMain, BridgeTask.exerciseHandSec
        BridgeTask.exerciseStowed, BridgeTask.exerciseHandMain, BridgeTask.exerciseHandSec = nil, nil, nil
        if b ~= nil then
            if main ~= nil then pcall(function() b:setPrimaryHandItem(main) end) end
            if sec ~= nil then pcall(function() b:setSecondaryHandItem(sec) end) end
        end
    end
    BridgeTask.exercisePhase = nil
    BridgeTask.exerciseRepAt = nil
    BridgeTask.exerciseRepMark = nil
    BridgeTask.exerciseBudget = nil
    BridgeTask.exerciseMirror = nil
    BridgeTask.exerciseStopReason = nil
    BridgeTask.exerciseReps = nil
    BridgeTask.exerciseHalfSaid = nil
end



BridgeTask.SHOWER_ENABLED = 1
BridgeTask.SHOWER_ONESHOT_MAX = 6 * SECOND
BridgeTask.SHOWER_WASH_HOURS = 30 / 60
BridgeTask.SHOWER_WASH_TICKS = 75 * SECOND
BridgeTask.SHOWER_MOUNT_REACH = 0.35

BridgeTask.kinds.shower = {}
BridgeTask.kinds.shower.noTargets = true
BridgeTask.kinds.shower.restoreMode = true

function BridgeTask.kinds.shower.available(body)
    if BridgeTask.SHOWER_ENABLED ~= 1 then return false end
    if BridgeShower == nil or BridgeShower.isTabas == nil then return false end
    local ok = false
    pcall(function() ok = BridgeShower.isTabas() == true end)
    return ok
end

function BridgeTask.kinds.shower.missing(body)
    return nil
end


local function showerSetBump(body, bump)
    pcall(function() body:setVariable("BumpAnimFinished", false) end)
    pcall(function() body:setBumpType(bump) end)
end


local function showerClear(body)
    if body == nil then return end
    pcall(function() body:setVariable("BumpAnimFinished", true) end)
    pcall(function() body:clearVariable("ShowerWashPart") end)
    pcall(function()
        local b = tostring(body:getBumpType())
        if string.sub(b, 1, 6) == "Shower" then body:setBumpType("") end
    end)
end


local function showerWait(body, bump, startAt)
    local cur, fin = "", false
    pcall(function() cur = tostring(body:getBumpType()) end)
    pcall(function() fin = body:getVariableBoolean("BumpAnimFinished") == true end)
    if cur == bump then BridgeTask.showerSeen = true end
    if fin then
        pcall(function() body:setVariable("BumpAnimFinished", false) end)
        return true
    end
    if BridgeTask.showerSeen and cur ~= bump then return true end
    if startAt ~= nil and (Bridge.time - startAt) * ffMult() > (BridgeTask.SHOWER_ONESHOT_MAX or (6 * SECOND)) then
        return true
    end
    return false
end


local function showerSquare()
    local t = BridgeTask.showerSq
    if t == nil then
        t = BridgeTask.current
        if t == nil and #BridgeTask.queue > 0 then t = BridgeTask.queue[1] end
    end
    return t
end


local function showerFacingDir()
    if BridgeShower == nil then return "S" end
    return BridgeShower.faceDirName(BridgeTask.showerFacing)
end


local function showerFace(body)
    local dir = nil
    pcall(function() dir = IsoDirections.fromString(showerFacingDir()) end)
    if dir ~= nil then pcall(function() body:faceDirection(dir) end) end
end


local function showerSnap(body, x, y, z)
    pcall(function()
        body:setX(x) body:setY(y)
        body:setLastX(x) body:setLastY(y)
        body:setCurrentSquareFromPosition(x, y, z)
        body:setMovingSquareNow()
    end)
end


local function showerFreeSquare(t, body)
    if t == nil then return nil end
    local best, bestScore = nil, nil
    pcall(function()
        local cell = getCell()
        local bx, by = nil, nil
        pcall(function()
            local red = BridgeData ~= nil and BridgeData.owner ~= nil and BridgeData.owner() or nil
            if red ~= nil then bx, by = red:getX(), red:getY() end
        end)
        if bx == nil and body ~= nil then bx, by = body:getX(), body:getY() end
        bx, by = bx or t.x, by or t.y
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    local sq = cell:getGridSquare(t.x + dx, t.y + dy, t.z)
                    if sq ~= nil then
                        local free = false
                        pcall(function() free = sq:isFree(false) == true end)
                        if free then
                            local score = math.abs(bx - (t.x + dx)) + math.abs(by - (t.y + dy))
                            if bestScore == nil or score < bestScore then
                                best, bestScore = { x = t.x + dx, y = t.y + dy, z = t.z }, score
                            end
                        end
                    end
                end
            end
        end
    end)
    return best
end


function BridgeTask.showerWashFrac()
    local start = BridgeTask.showerProgressStart or 0
    if start < 0 then start = 0 elseif start > 1 then start = 1 end
    local share = 1 - start
    if share <= 0 then return 1 end

    local session = nil
    local nowH = nil
    pcall(function() nowH = getGameTime():getWorldAgeHours() end)
    if nowH ~= nil and BridgeTask.showerWashStartH ~= nil then
        local span = (BridgeTask.SHOWER_WASH_HOURS or 0.5) * share
        if span <= 0 then return 1 end
        session = (nowH - BridgeTask.showerWashStartH) / span
    elseif BridgeTask.showerWashSince ~= nil then
        local span = (BridgeTask.SHOWER_WASH_TICKS or (75 * SECOND)) * share
        if span <= 0 then return 1 end
        session = (Bridge.time - BridgeTask.showerWashSince) * ffMult() / span
    end
    if session == nil then session = 0 end
    if session < 0 then session = 0 elseif session > 1 then session = 1 end
    return start + session * share
end


function BridgeTask.kinds.shower.update(body)
    if BridgeTask.SHOWER_ENABLED ~= 1 then return BridgeTask.finish() end
    if BridgeShower == nil then return BridgeTask.finish() end
    if not BridgeShower.isTabas() then
        Bridge.speak("NoWater")
        return BridgeTask.finish()
    end

    local phase = BridgeTask.showerPhase

    if phase == nil then
        local t = showerSquare()
        if t == nil then return BridgeTask.finish() end
        BridgeTask.showerSq = { x = t.x, y = t.y, z = t.z }

        local startP = BridgeShower.progress(Bridge.store)
        if startP >= 1 then startP = 0 end
        BridgeTask.showerProgressStart = startP
        BridgeTask.showerProgressTotal = startP
        local waterShare = 1 - startP
        if waterShare < 0.05 then waterShare = 0.05 end

        BridgeTask.showerSink = nil
        pcall(function() BridgeTask.showerSink = BridgeShower.waterSink(BridgeTask.showerObj) end)
        BridgeTask.showerWaterUsed = 0
        BridgeTask.showerWaterDry = nil
        BridgeTask.showerWaterTotal = nil
        if BridgeTask.showerSink ~= nil then
            if BridgeShower.waterAvailable(BridgeTask.showerSink) < 1 then
                Bridge.speak("NoWater")
                return BridgeTask.finish()
            end
            local lo = BridgeShower.WATER_MIN or 5
            local hi = BridgeShower.WATER_MAX or 15
            local full = lo + ZombRand((hi - lo) + 1)
            BridgeTask.showerWaterTotal = math.max(1, math.floor(full * waterShare + 0.5))
        end

        pcall(function() if BridgeEquip ~= nil and BridgeEquip.close ~= nil then BridgeEquip.close() end end)

        local snapOk = false
        pcall(function() snapOk = BridgeShower.snapshotOutfit(body) end)
        if not snapOk then
            log("shower: outfit snapshot failed, not undressing")
            return BridgeTask.finish()
        end
        pcall(function() BridgeShower.strip(body) end)
        BridgeTask.showerPhase = "undress"
        BridgeTask.showerSince = Bridge.time
        BridgeTask.showerSeen = false
        showerSetBump(body, BridgeShower.BUMP_UNDRESS)
        BridgeTask.info = "shower: undressing"
        log("shower: undressing first at " .. tostring(math.floor(body:getX())) .. "," .. tostring(math.floor(body:getY())))
        return true
    end

    if phase == "undress" then
        if showerWait(body, BridgeShower.BUMP_UNDRESS, BridgeTask.showerSince) then
            BridgeTask.showerPhase = "mount"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerSeen = false
            BridgeTask.showerBesideSince = nil
            BridgeTask.showerWalkIn = nil
            pcall(function()
                local iso = require("TABAS_Iso")
                if BridgeTask.showerObj ~= nil then
                    BridgeTask.showerWalkIn = iso.isBathObject(BridgeTask.showerObj) ~= true
                end
            end)
            BridgeTask.info = "shower: stepping in"
        end
        return true
    end

    if phase == "mount" then
        local t = BridgeTask.showerSq
        local reach = BridgeTask.SHOWER_MOUNT_REACH
        if BridgeTask.showerWalkIn == true then reach = BridgeTask.STOP_DIST end
        local res = BridgeTask.walkTo(body, t, reach, false, true)
        local onTile = false
        pcall(function() onTile = math.floor(body:getX()) == t.x and math.floor(body:getY()) == t.y end)
        local beside = false
        pcall(function()
            local dx, dy = body:getX() - (t.x + 0.5), body:getY() - (t.y + 0.5)
            beside = (dx * dx + dy * dy) <= (1.2 * 1.2)
        end)
        if beside and not onTile then
            BridgeTask.showerBesideSince = BridgeTask.showerBesideSince or Bridge.time
        else
            BridgeTask.showerBesideSince = nil
        end
        local parked = BridgeTask.showerBesideSince ~= nil
            and (Bridge.time - BridgeTask.showerBesideSince) > (2 * SECOND)
        local stalled = (Bridge.time - (BridgeTask.showerSince or Bridge.time)) > (20 * SECOND)
        if res == "arrived" or onTile or parked or res == "unreachable" or stalled then
            BridgeTask.showerBesideSince = nil
            pcall(function() BridgeMove.stopPath(body) end)
            Bridge.target = nil
            showerSnap(body, t.x + 0.5, t.y + 0.5, t.z)
            showerFace(body)
            BridgeTask.showerPhase = "start"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerSeen = false
            showerSetBump(body, BridgeShower.BUMP_START)
            pcall(function() body:playSound("tabas_turntap") end)
            Bridge.speak("ShowerStart")
            BridgeTask.showerWashSaid = nil
            BridgeTask.info = "shower: turning on"
            log("shower: on the tile, turning on (" .. tostring(res) .. ", onTile=" .. tostring(onTile)
                .. ", parked=" .. tostring(parked) .. ", walkIn=" .. tostring(BridgeTask.showerWalkIn) .. ")")
            return true
        end
        BridgeTask.info = "shower: stepping under the water"
        return true
    end

    if phase == "start" then
        showerFace(body)
        if not BridgeTask.showerWaterOn then
            local t = BridgeTask.showerSq
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(t.x, t.y, t.z) end)
            pcall(function() BridgeShower.spawnShowerWater(sq, BridgeTask.showerFacing, true) end)
            BridgeTask.showerWaterOn = true
        end
        if showerWait(body, BridgeShower.BUMP_START, BridgeTask.showerSince) then
            BridgeTask.showerPhase = "washing"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerWashSince = Bridge.time
            BridgeTask.showerWashStartH = nil
            pcall(function() BridgeTask.showerWashStartH = getGameTime():getWorldAgeHours() end)
            BridgeTask.showerPart = nil
            BridgeTask.info = "shower: washing"
            log("shower: washing")
        end
        return true
    end

    if phase == "washing" then
        showerFace(body)
        local tabas = BridgeShower.isTabas()
        local parts = tabas and BridgeShower.WASH_PARTS_TABAS or BridgeShower.WASH_PARTS_VANILLA
        local bump = tabas and BridgeShower.BUMP_WASH or BridgeShower.BUMP_WASH_V

        local p = BridgeTask.showerWashFrac()
        BridgeTask.showerProgressTotal = p

        if not BridgeTask.showerWashSaid and p >= 0.5 then
            BridgeTask.showerWashSaid = true
            Bridge.speak("ShowerWash")
        end

        if BridgeTask.showerSink ~= nil and BridgeTask.showerWaterTotal ~= nil and not BridgeTask.showerWaterDry then
            local want = math.floor(p * BridgeTask.showerWaterTotal + 0.5)
            local used = BridgeTask.showerWaterUsed or 0
            if want > used then
                local sq = nil
                pcall(function() sq = BridgeTask.showerSink:getSquare() end)
                local got = 0
                pcall(function() got = BridgeShower.consumeWater(BridgeTask.showerSink, sq, want - used) end)
                if type(got) ~= "number" then got = 0 end
                BridgeTask.showerWaterUsed = used + got
            end
            local avail = BridgeShower.waterAvailable(BridgeTask.showerSink)
            if avail < 1 and (BridgeTask.showerWaterUsed or 0) < BridgeTask.showerWaterTotal then
                BridgeTask.showerWaterDry = true
                log("shower: water ran dry")
            end
        end

        local idx = math.floor(p * #parts) + 1
        if idx < 1 then idx = 1 elseif idx > #parts then idx = #parts end
        local part = parts[idx]

        if BridgeTask.showerPart ~= part then
            BridgeTask.showerPart = part
            pcall(function() body:setVariable("ShowerWashPart", part) end)
            pcall(function() body:setBumpType("Stand") end)
            pcall(function() body:setBumpType(bump) end)
            log("shower: wash part " .. tostring(part))
        else
            pcall(function() body:setVariable("ShowerWashPart", part) end)
            pcall(function()
                if tostring(body:getBumpType()) ~= bump then body:setBumpType(bump) end
            end)
        end
        BridgeTask.info = "shower: washing " .. tostring(part)

        if p >= 1 or BridgeTask.showerWaterDry then
            BridgeTask.showerPhase = "stop"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerSeen = false
            showerSetBump(body, BridgeShower.BUMP_STOP)
            pcall(function() body:playSound("tabas_turntap") end)
            pcall(function() BridgeShower.removeShowerWater() end)
            BridgeTask.showerWaterOn = false
            if BridgeTask.showerWaterDry then Bridge.speak("NoWater") end
            BridgeTask.info = BridgeTask.showerWaterDry and "shower: out of water" or "shower: turning off"
            log(BridgeTask.info)
        end
        return true
    end

    if phase == "stop" then
        showerFace(body)
        if showerWait(body, BridgeShower.BUMP_STOP, BridgeTask.showerSince) then
            BridgeTask.showerPhase = "off"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerSeen = false
            BridgeTask.showerOffTo = nil
            BridgeTask.info = "shower: stepping out"
        end
        return true
    end

    if phase == "off" then
        pcall(function()
            if tostring(body:getBumpType()) ~= "" then body:setBumpType("") end
        end)
        if BridgeTask.showerOffTo == nil then
            BridgeTask.showerOffTo = showerFreeSquare(BridgeTask.showerSq, body) or false
        end
        local to = BridgeTask.showerOffTo
        if to == false then
            BridgeTask.showerPhase = "towel"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerSeen = false
            return true
        end
        local res = BridgeTask.walkTo(body, to, BridgeTask.STOP_DIST, false, false)
        local left = false
        pcall(function()
            local s = BridgeTask.showerSq
            if s ~= nil then left = math.floor(body:getX()) ~= s.x or math.floor(body:getY()) ~= s.y end
        end)
        if res == "arrived" or left then
            pcall(function() BridgeMove.stopPath(body) end)
            BridgeTask.showerPhase = "towel"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerSeen = false
        elseif res == "unreachable"
                or (Bridge.time - (BridgeTask.showerSince or Bridge.time)) > (6 * SECOND) then
            pcall(function() BridgeMove.stopPath(body) end)
            showerSnap(body, to.x + 0.5, to.y + 0.5, to.z)
            BridgeTask.showerPhase = "towel"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerSeen = false
        end
        BridgeTask.info = "shower: stepping out"
        return true
    end

    if phase == "towel" then
        if BridgeTask.showerTowel == nil then
            local towel = nil
            pcall(function() towel = BridgeShower.findTowel(body) end)
            BridgeTask.showerTowel = towel or false
            log("shower: towel " .. (towel ~= nil and "yes" or "no"))
        end
        if BridgeTask.showerTowel == false then
            BridgeTask.showerPhase = "dress"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerSeen = false
            return true
        end
        if BridgeTask.showerTowelAt == nil then
            BridgeTask.showerTowelAt = Bridge.time
            BridgeTask.showerSeen = false
            showerSetBump(body, BridgeShower.BUMP_TOWEL)
        end
        if showerWait(body, BridgeShower.BUMP_TOWEL, BridgeTask.showerTowelAt) then
            BridgeTask.showerPhase = "dress"
            BridgeTask.showerSince = Bridge.time
            BridgeTask.showerSeen = false
        end
        BridgeTask.info = "shower: drying off"
        return true
    end

    if phase == "dress" then
        if BridgeTask.showerDressAt == nil then
            BridgeTask.showerDressAt = Bridge.time
            BridgeTask.showerSeen = false
            showerSetBump(body, BridgeShower.BUMP_DRESS)
        end
        if not BridgeTask.showerDressed then
            BridgeTask.showerDressed = true
            pcall(function() BridgeShower.restorePreShower(body) end)
        end
        if showerWait(body, BridgeShower.BUMP_DRESS, BridgeTask.showerDressAt) then
            return BridgeTask.kinds.shower.stop(body)
        end
        BridgeTask.info = "shower: dressing"
        return true
    end

    return BridgeTask.finish()
end


function BridgeTask.kinds.shower.stop(body)
    showerClear(body)
    pcall(function() BridgeShower.removeShowerWater() end)
    pcall(function() if BridgeShower ~= nil and BridgeShower.setProgress ~= nil then BridgeShower.setProgress(Bridge.store, 0) end end)
    pcall(function()
        if BridgeShower ~= nil and BridgeShower.setCooldown ~= nil then BridgeShower.setCooldown(Bridge.store) end
    end)
    pcall(function()
        if BridgeShower ~= nil and BridgeShower.hasPreShower ~= nil and BridgeShower.hasPreShower() then
            BridgeShower.restorePreShower(body)
        end
    end)
    Bridge.speak("ShowerDone")
    log("shower: done")
    return BridgeTask.finish()
end


function BridgeTask.kinds.shower.leave(body)
    pcall(function() if BridgeShower ~= nil then BridgeShower.removeShowerWater() end end)
    pcall(function()
        if BridgeShower ~= nil and BridgeShower.hasPreShower ~= nil and BridgeShower.hasPreShower() then
            BridgeShower.restorePreShower(body)
        end
    end)
    pcall(function()
        if BridgeShower ~= nil and BridgeShower.setProgress ~= nil and BridgeTask.showerProgressStart ~= nil then
            local total = BridgeTask.showerProgressTotal or BridgeTask.showerProgressStart or 0
            if total >= 1 then total = 0 end
            BridgeShower.setProgress(Bridge.store, total)
        end
    end)
    showerClear(body)
    BridgeTask.showerPhase = nil
    BridgeTask.showerSince = nil
    BridgeTask.showerSeen = nil
    BridgeTask.showerSq = nil
    BridgeTask.showerStand = nil
    BridgeTask.showerWalkIn = nil
    BridgeTask.showerObj = nil
    BridgeTask.showerFacing = nil
    BridgeTask.showerWaterOn = nil
    BridgeTask.showerWashSince = nil
    BridgeTask.showerWashStartH = nil
    BridgeTask.showerWashSaid = nil
    BridgeTask.showerSink = nil
    BridgeTask.showerWaterTotal = nil
    BridgeTask.showerWaterUsed = nil
    BridgeTask.showerWaterDry = nil
    BridgeTask.showerProgressStart = nil
    BridgeTask.showerProgressTotal = nil
    BridgeTask.showerPart = nil
    BridgeTask.showerOffTo = nil
    BridgeTask.showerTowel = nil
    BridgeTask.showerTowelAt = nil
    BridgeTask.showerDressAt = nil
    BridgeTask.showerDressed = nil
end


local function corpseIsBurning(sq)
    if sq == nil then return false end
    local burn = false
    pcall(function() burn = sq:has(IsoFlagType.burning) == true end)
    return burn
end


local function corpseOn(sq)
    local found = nil
    if sq == nil then return nil end
    pcall(function()
        local list = sq:getStaticMovingObjects()
        if list == nil then return end
        for i = 0, list:size() - 1 do
            local o = list:get(i)
            if o ~= nil and instanceof(o, "IsoDeadBody") and not o:isAnimal() then found = o return end
        end
    end)
    if found == nil then
        pcall(function()
            local list = sq:getDeadBodys()
            for i = 0, (list and list:size() or 0) - 1 do
                local o = list:get(i)
                if o ~= nil and not o:isAnimal() then found = o return end
            end
        end)
    end
    return found
end


local function corpseNearest(sq, cx, cy)
    local best, bestD = nil, nil
    if sq == nil then return nil end
    pcall(function()
        local list = sq:getStaticMovingObjects()
        if list == nil then return end
        for i = 0, list:size() - 1 do
            local o = list:get(i)
            if o ~= nil and instanceof(o, "IsoDeadBody") and not o:isAnimal() then
                local d = 0
                if cx ~= nil and cy ~= nil then
                    d = (o:getX() - cx) ^ 2 + (o:getY() - cy) ^ 2
                end
                if bestD == nil or d < bestD then best, bestD = o, d end
            end
        end
    end)
    if best == nil then best = corpseOn(sq) end
    return best
end


local function dropSquareValid(sq)
    if sq == nil then return false end
    local floor = nil
    pcall(function() floor = sq:getFloor() end)
    if floor == nil then return false end
    if corpseIsBurning(sq) then return false end
    return true
end


local function resolveDropSquare(dest)
    if dest == nil then return nil end
    local maxR = BridgeTask.CORPSE_DROP_SEARCH
    local best, bestD = nil, nil
    local cell = getCell()
    for dx = -maxR, maxR do
        for dy = -maxR, maxR do
            local sq = nil
            pcall(function() sq = cell:getGridSquare(dest.x + dx, dest.y + dy, dest.z) end)
            if dropSquareValid(sq) then
                local d = dx * dx + dy * dy
                if bestD == nil or d < bestD then best, bestD = sq, d end
            end
        end
    end
    return best
end


local function corpseBendClear(body)
    if body == nil then return end
    pcall(function()
        body:setVariable("NotAloneHitNow", false)
        body:setVariable("BumpAnimFinished", true)
        body:changeState(ZombieIdleState.instance())
        body:setBumpType("")
    end)
end


local function corpseDropLocal(sq, carry)
    if sq == nil or carry == nil then return false end
    local done = false
    local mp = Bridge ~= nil and Bridge.mp == true
    local function placeObject()
        if carry.corpse == nil then return end
        pcall(function()
            local c = carry.corpse
            c:setX(sq:getX() + 0.5)
            c:setY(sq:getY() + 0.5)
            c:setZ(sq:getZ())
            if c.setSquare ~= nil then c:setSquare(sq) end
            if c.setCurrent ~= nil then c:setCurrent(sq) end
            sq:addCorpse(c, false)
            done = true
        end)
    end
    if not mp then placeObject() end
    if not done and carry.item ~= nil then
        pcall(function() sq:tryAddCorpseToWorld(carry.item, 0.5, 0.5) done = true end)
    end
    if not done then placeObject() end
    return done
end


function BridgeTask.corpseToServer(name, args, localFn)
    if isClient() then

        if localFn ~= nil then pcall(localFn) end
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", name, args) end)
        return true
    end
    local mp = false
    pcall(function() mp = isMultiplayer() end)
    if mp then

        pcall(function()
            if BridgeServer ~= nil and BridgeServer.Commands ~= nil
                    and BridgeServer.Commands[name] ~= nil then
                BridgeServer.Commands[name](getPlayer(), args)
            end
        end)
        return true
    end
    if localFn ~= nil then pcall(localFn) end
    return true
end


local function corpseBend(body, workTime)
    if body == nil then return false end
    if BridgeTask.swingStart == nil then
        if (BridgeTask.animHold or 0) > 0 then
            BridgeTask.animHold = BridgeTask.animHold - 1
            corpseBendClear(body)
            BridgeTask.info = "resettling bend"
            return false
        end
        BridgeTask.swingStart = Bridge.time
        pcall(function()
            body:setVariable("NotAloneHitNow", false)
            body:setVariable("BumpAnimFinished", false)
            body:setBumpType(BridgeTask.LOOT_LOW)
        end)
        return false
    end
    local age = (Bridge.time - BridgeTask.swingStart) * ffMult()
    if age >= BridgeTask.SCRUB_GUARD then
        local playing = false
        pcall(function()
            playing = body:getActionStateName() == "bumped"
                and tostring(body:getBumpType()) == BridgeTask.LOOT_LOW
        end)
        if not playing then
            corpseBendClear(body)
            BridgeTask.animHold = 2
            BridgeTask.swingStart = nil
            BridgeTask.info = "bend anim lost, restarting"
            return false
        end
    end
    if (Bridge.time - (BridgeTask.corpseStart or Bridge.time)) * ffMult() >= workTime then
        return true
    end
    return false
end


BridgeTask.kinds.moveCorpses = {}

function BridgeTask.kinds.moveCorpses.available(body)
    return BridgeTask.MOVE_CORPSES_ENABLED == 1
end

function BridgeTask.kinds.moveCorpses.missing(body)
    return nil
end


function BridgeTask.kinds.moveCorpses.update(body)
    if BridgeTask.MOVE_CORPSES_ENABLED ~= 1 then return BridgeTask.finish() end
    if BridgeMove ~= nil then
        BridgeMove.forcedWalk = (BridgeTask.carryCorpse ~= nil)
            and BridgeTask.CORPSE_HAUL_WALK or "Walk"
    end


    if BridgeTask.corpseRest then
        pcall(function() BridgeMove.stopPath(body) end)
        if Bridge.time < (BridgeTask.corpseRestSitAt or 0) then
            BridgeTask.info = "catching her breath"
            return true
        end
        sitDown(body)
        pcall(function()
            if BridgeFight ~= nil and BridgeFight.rest ~= nil then BridgeFight.rest(false, true) end
        end)
        local f = 0
        pcall(function() f = tonumber(BridgeFight and BridgeFight.fatigue) or 0 end)
        BridgeTask.info = string.format("resting %d%%", math.floor((1 - f) * 100 + 0.5))
        if f <= (1 - BridgeTask.CORPSE_RESUME_STAMINA) then
            BridgeTask.corpseRest = false
            standUp(body)
            BridgeTask.corpseResumeAt = Bridge.time + BridgeTask.CORPSE_RESUME_DELAY
            BridgeTask.info = "getting up"
            if ownerNear(body, BridgeTask.CORPSE_REST_SAY_RANGE) then
                pcall(function()
                    if BridgeMoments ~= nil then
                        BridgeMoments.say("EvRested", BridgeTask.CORPSE_REST_SAY_COOLDOWN, true, "CorpseRested")
                    end
                end)
            end
        end
        return true
    end


    if BridgeTask.corpseResumeAt ~= nil then
        if Bridge.time < BridgeTask.corpseResumeAt then
            pcall(function() BridgeMove.stopPath(body) end)
            BridgeTask.info = "getting back to it"
            return true
        end
        BridgeTask.corpseResumeAt = nil
        BridgeTask.since = Bridge.time
        BridgeTask.progressAt = Bridge.time
    end


    if BridgeTask.carryCorpse == nil and BridgeFight ~= nil
            and (BridgeFight.fatigue or 0) >= BridgeTask.CORPSE_REST_AT
            and (BridgeTask.current ~= nil or #BridgeTask.queue > 0) then
        BridgeTask.corpseRest = true
        BridgeTask.corpseRestSitAt = Bridge.time + BridgeTask.CORPSE_REST_SIT_DELAY
        BridgeTask.corpsePhase = nil
        pcall(function() BridgeMove.stopPath(body) end)
        BridgeTask.info = "winded"
        if ownerNear(body, BridgeTask.CORPSE_REST_SAY_RANGE) then
            pcall(function()
                if BridgeMoments ~= nil then
                    BridgeMoments.say("EvWinded", BridgeTask.CORPSE_REST_SAY_COOLDOWN, true, "CorpseRest")
                end
            end)
        end
        return true
    end


    if (Bridge.time - (BridgeTask.lastCorpseSayCheck or 0)) >= SECOND then
        BridgeTask.lastCorpseSayCheck = Bridge.time
        if (Bridge.time - (BridgeTask.lastCorpseSay or -99999)) >= BridgeTask.CORPSE_SAY_COOLDOWN
                and ZombRand(100) < 25 then
            local said = false
            pcall(function()
                said = BridgeMoments ~= nil
                    and BridgeMoments.say("EvDraggingCorpse", BridgeTask.CORPSE_SAY_COOLDOWN, true, "DraggingCorpse") == true
            end)
            if said then BridgeTask.lastCorpseSay = Bridge.time end
        end
    end


    if BridgeTask.carryCorpse ~= nil then
        return BridgeTask.kinds.moveCorpses.haul(body)
    end


    local target = BridgeTask.current
    if target == nil then
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        target = table.remove(BridgeTask.queue, 1)
        BridgeTask.current = target
        BridgeTask.corpsePhase = nil
        BridgeTask.corpseStart = nil
        BridgeTask.swingStart = nil
        BridgeTask.animHold = 0
        BridgeTask.since = Bridge.time
        BridgeTask.spot = nil
        BridgeTask.still = 0
        BridgeTask.checkX = nil
        BridgeTask.bestD = nil
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
    end

    local sq = nil
    pcall(function() sq = getCell():getGridSquare(target.x, target.y, target.z) end)
    local corpse = corpseOn(sq)
    if corpse == nil then

        BridgeTask.info = "corpse gone"
        corpseBendClear(body)
        BridgeTask.current = nil
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        return true
    end

    local reach = BridgeTask.CORPSE_RANGE
    if BridgeTask.corpsePhase == "bend" then reach = reach + 1.0 end
    local walk, why = BridgeTask.walkTo(body, target, reach)
    if walk == "unreachable" then return BridgeTask.dropTarget(why) end
    if walk == "walking" then return true end

    if BridgeTask.corpsePhase ~= "bend" then
        BridgeTask.corpsePhase = "bend"
        BridgeTask.corpseStart = Bridge.time
        BridgeTask.swingStart = nil
        BridgeTask.animHold = 0
        pcall(function() BridgeMove.stopPath(body) end)
        BridgeTask.info = "bending to the body"
        log(string.format("arrived at corpse %d,%d", target.x, target.y))
    end

    if (Bridge.time - (BridgeTask.corpseStart or Bridge.time)) > BridgeTask.CORPSE_TIMEOUT then
        corpseBendClear(body)
        BridgeTask.info = "skip stubborn corpse"
        return BridgeTask.dropTarget(nil)
    end

    pcall(function() body:faceLocationF(target.x + 0.5, target.y + 0.5) end)

    if corpseBend(body, BridgeTask.CORPSE_PICKUP_MS) then
        local item = nil
        pcall(function() item = corpse:getItem() end)
        local cx, cy = target.x + 0.5, target.y + 0.5
        pcall(function() cx, cy = corpse:getX(), corpse:getY() end)
        BridgeTask.carryCorpse = { item = item, corpse = corpse }
        BridgeTask.carrySource = { x = target.x, y = target.y, z = target.z }
        BridgeTask.corpseToServer("corpseGrab",
            { x = target.x, y = target.y, z = target.z, cx = cx, cy = cy },
            function()
                if sq ~= nil then pcall(function() sq:removeCorpse(corpse, false) end) end
            end)
        corpseBendClear(body)
        BridgeTask.swingStart = nil
        BridgeTask.corpsePhase = "haul"
        BridgeTask.current = nil
        BridgeTask.since = Bridge.time
        BridgeTask.progressAt = Bridge.time
        BridgeTask.spot = nil
        BridgeTask.bestD = nil
        BridgeTask.info = "carrying the body"
        log("corpse picked up")
        return true
    end
    return true
end


function BridgeTask.kinds.moveCorpses.haul(body)
    local dest = BridgeTask.corpseDest
    if dest == nil then return BridgeTask.kinds.moveCorpses.dropHere(body) end

    local walk, why = BridgeTask.walkTo(body, dest, BridgeTask.CORPSE_RANGE, false, true)
    if walk == "unreachable" then return BridgeTask.kinds.moveCorpses.dropHere(body) end
    if walk == "walking" then return true end

    if BridgeTask.corpsePhase ~= "drop" then
        BridgeTask.corpsePhase = "drop"
        BridgeTask.corpseStart = Bridge.time
        BridgeTask.swingStart = nil
        BridgeTask.animHold = 0
        pcall(function() BridgeMove.stopPath(body) end)
        BridgeTask.info = "bending to set it down"
        log("arrived at destination")
    end

    if (Bridge.time - (BridgeTask.corpseStart or Bridge.time)) > BridgeTask.CORPSE_TIMEOUT then
        return BridgeTask.kinds.moveCorpses.dropHere(body)
    end

    pcall(function() body:faceLocationF(dest.x + 0.5, dest.y + 0.5) end)

    if corpseBend(body, BridgeTask.CORPSE_DROP_MS) then
        local sq = resolveDropSquare(dest)
        if sq == nil then return BridgeTask.kinds.moveCorpses.dropHere(body) end
        return BridgeTask.kinds.moveCorpses.placeCarry(sq, body)
    end
    return true
end


function BridgeTask.kinds.moveCorpses.placeCarry(sq, body)
    local carry = BridgeTask.carryCorpse
    if carry == nil then return true end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    BridgeTask.corpseToServer("corpseDrop", { x = x, y = y, z = z },
        function() corpseDropLocal(sq, carry) end)
    corpseBendClear(body)

    local tiles = 1
    local src = BridgeTask.carrySource
    if src ~= nil then tiles = math.sqrt((src.x - x) ^ 2 + (src.y - y) ^ 2) end
    local use = BridgeTask.CORPSE_STAMINA_PER + tiles * BridgeTask.CORPSE_STAMINA_PER_TILE
    pcall(function()
        if BridgeFight ~= nil then
            BridgeFight.fatigue = math.min(1, (BridgeFight.fatigue or 0) + use)
        end
    end)
    pcall(function()
        if BridgeSkills ~= nil and BridgeSkills.add ~= nil then
            BridgeSkills.add("Strength", BridgeTask.CORPSE_XP_STRENGTH, "corpse")
            BridgeSkills.add("Fitness", BridgeTask.CORPSE_XP_FITNESS, "corpse")
        end
    end)

    BridgeTask.markDone()
    BridgeTask.corpseCarried = (BridgeTask.corpseCarried or 0) + 1
    BridgeTask.carryCorpse = nil
    BridgeTask.carrySource = nil
    BridgeTask.corpsePhase = nil
    BridgeTask.corpseStart = nil
    BridgeTask.swingStart = nil
    BridgeTask.current = nil
    BridgeTask.since = Bridge.time
    BridgeTask.progressAt = Bridge.time
    BridgeTask.info = "body on the pile"
    if #BridgeTask.queue == 0 then return BridgeTask.finish() end
    return true
end


function BridgeTask.kinds.moveCorpses.dropHere(body)
    local carry = BridgeTask.carryCorpse
    if carry == nil then return BridgeTask.finish() end
    local sq = nil
    pcall(function() sq = body ~= nil and body:getCurrentSquare() or nil end)
    if sq == nil then
        local src = BridgeTask.carrySource
        if src ~= nil then pcall(function() sq = getCell():getGridSquare(src.x, src.y, src.z) end) end
    end
    if sq == nil then
        Bridge.speak("JobBodyDropBlocked")
        return BridgeTask.finish()
    end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    BridgeTask.corpseToServer("corpseDrop", { x = x, y = y, z = z },
        function() corpseDropLocal(sq, carry) end)
    corpseBendClear(body)
    BridgeTask.carryCorpse = nil
    BridgeTask.carrySource = nil
    BridgeTask.corpsePhase = nil
    BridgeTask.corpseStart = nil
    BridgeTask.swingStart = nil
    BridgeTask.info = "body set down where she stands"
    Bridge.speak("JobBodyDropBlocked")
    return BridgeTask.finish()
end


function BridgeTask.kinds.moveCorpses.leave(body)
    if BridgeTask.carryCorpse ~= nil then
        local carry = BridgeTask.carryCorpse
        local sq = nil
        pcall(function() sq = body ~= nil and body:getCurrentSquare() or nil end)
        if sq == nil then
            local src = BridgeTask.carrySource
            if src ~= nil then pcall(function() sq = getCell():getGridSquare(src.x, src.y, src.z) end) end
        end
        if sq ~= nil then
            local x, y, z = sq:getX(), sq:getY(), sq:getZ()
            BridgeTask.corpseToServer("corpseDrop", { x = x, y = y, z = z },
                function() corpseDropLocal(sq, carry) end)
        end
        BridgeTask.carryCorpse = nil
        BridgeTask.carrySource = nil
    end
    corpseBendClear(body)
    BridgeTask.corpsePhase = nil
    BridgeTask.corpseStart = nil
    BridgeTask.swingStart = nil
    BridgeTask.animHold = 0
    restoreForcedWalk()
end


if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeTask] loaded") end
