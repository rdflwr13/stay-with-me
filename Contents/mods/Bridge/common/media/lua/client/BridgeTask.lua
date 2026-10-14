BridgeTask = BridgeTask or {}

BridgeTask.ENABLED = 1
BridgeTask.TREECUTTING_ENABLED = 1
BridgeTask.CLEANING_ENABLED = 1
BridgeTask.CLEARING_ENABLED = 1
BridgeTask.LOOTING_ENABLED = 1
BridgeTask.SIT_ENABLED = 1



local SECOND = 60
local MINUTE = 60 * SECOND

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


BridgeTask.CLEAN_SOUND = "CleanBloodScrub"
BridgeTask.CLEAN_SOUND_HAND = "CleanBloodBleach"
BridgeTask.ASH_SOUND = "Shoveling"


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
BridgeTask.OPENING_GIVE_UP = 6 * SECOND



BridgeTask.DIRT_PREFIXES = { "overlay_grime", "trash&junk", "trash_", "d_floorleaves", "d_trash", "LS_Scraps" }

BridgeTask.active = false
BridgeTask.state = "idle"
BridgeTask.kind = nil
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

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeTask] " .. tostring(text)) end end
local function warn(text) print("[BridgeTask] " .. tostring(text)) end




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


local function doorBlocker(sq)
    local reason = nil
    if sq == nil then return nil end
    pcall(function()
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local o = objs:get(i)
            if o ~= nil then
                local door = false
                pcall(function()
                    door = instanceof(o, "IsoDoor")
                        or (instanceof(o, "IsoThumpable") and o:isDoor())
                end)
                if door then
                    local bar, lock = false, false
                    pcall(function() bar = o:isBarricaded() end)
                    pcall(function() lock = o:isLocked() or o:isLockedByKey() end)
                    if bar then reason = "barricade" return end
                    if lock then reason = "locked" end
                end
            end
        end
    end)
    return reason
end




local function blockedReason(target)
    local ob = ""
    pcall(function() ob = tostring(BridgeMove ~= nil and BridgeMove.obstacle or "") end)
    if string.find(ob, "barricad", 1, true) ~= nil then return "barricade" end
    if string.find(ob, "locked", 1, true) ~= nil then return "locked" end
    local reason = nil
    pcall(function()
        local body = Bridge.body
        if body ~= nil then reason = doorBlocker(body:getCurrentSquare()) end
        if reason == nil and target ~= nil then
            local sq = getCell():getGridSquare(target.x, target.y, target.z)
            reason = doorBlocker(sq)
        end
    end)
    return reason
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

    if BridgeMove ~= nil and BridgeMove.openingWay ~= nil then
        local way = BridgeMove.openingWay
        if BridgeTask.openingKey ~= way.key then
            BridgeTask.openingKey = way.key
            BridgeTask.openingSince = Bridge.time
        elseif BridgeTask.openingSince ~= nil
                and Bridge.time - BridgeTask.openingSince > BridgeTask.OPENING_GIVE_UP then
            BridgeTask.openingRef, BridgeTask.openingKey, BridgeTask.openingTries = nil, nil, nil
            BridgeTask.openingSince = nil
            BridgeTask.info = "opening unreachable"
            return "unreachable", blockedReason(target)
        end
    end

    if sameFloor and not BridgeTask.reachOk(body, targetSq) then
        BridgeTask.info = "no accessible opening"
        return "unreachable", blockedReason(target)
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

    local failed = false
    pcall(function()
        failed = BridgeMove ~= nil and not BridgeMove.pathing
            and BridgeMove.pathResult == tostring(BehaviorResult.Failed)
    end)
    if failed then
        if BridgeTask.pathFailTick ~= Bridge.tick then
            BridgeTask.pathFails = (BridgeTask.pathFails or 0) + 1
        end
        BridgeTask.pathFailTick = Bridge.tick
        pcall(function() BridgeMove.pathResult = "none" end)
        if (BridgeTask.pathFails or 0) >= BridgeTask.PATH_FAIL_LIMIT then
            BridgeTask.info = "no path to target"
            return "unreachable", blockedReason(target)
        end
    end



    local since = BridgeTask.progressAt or BridgeTask.since or Bridge.time
    if (Bridge.time - since) > BridgeTask.WALK_NO_PROGRESS
            or (Bridge.time - (BridgeTask.since or Bridge.time)) > BridgeTask.WALK_TIMEOUT then
        if sameFloor and playerOnSquare(BridgeTask.spot) then
            BridgeTask.progressAt = Bridge.time
            BridgeTask.since = Bridge.time
            BridgeTask.info = "waiting for player"
            return "walking", nil
        end
        BridgeTask.info = "no progress to target"
        return "unreachable", blockedReason(target)
    end

    if BridgeTask.checkX == nil then BridgeTask.checkX, BridgeTask.checkY = body:getX(), body:getY() end
    BridgeTask.still = (BridgeTask.still or 0) + 1
    if BridgeTask.still >= BridgeTask.STALL_TICKS then
        local moved = math.abs(body:getX() - BridgeTask.checkX) + math.abs(body:getY() - BridgeTask.checkY) > 0.3
        BridgeTask.still = 0
        BridgeTask.checkX, BridgeTask.checkY = body:getX(), body:getY()
        if not moved then
            if BridgeMove.cross ~= nil or BridgeMove.doorAct ~= nil
                    or BridgeMove.window ~= nil or BridgeMove.pendingClimb ~= nil then

                BridgeTask.still = 0
            elseif sameFloor and playerOnSquare(BridgeTask.spot) then
                BridgeTask.checkX, BridgeTask.checkY = nil, nil
                BridgeTask.still = 0
                BridgeTask.progressAt = Bridge.time
                BridgeTask.info = "waiting for player"
                return "walking", nil
            else
                BridgeTask.checkX, BridgeTask.checkY = nil, nil
                local bx, by = body:getX(), body:getY()
                local ddx, ddy = (target.x + 0.5) - bx, (target.y + 0.5) - by
                local dlen = math.sqrt(ddx * ddx + ddy * ddy)
                if dlen > 0.05 then
                    ddx, ddy = ddx / dlen, ddy / dlen
                    local cell = getCell()
                    local z = math.floor(target.z)
                    BridgeTask.detourSide = -(BridgeTask.detourSide or 1)
                    for _, s in ipairs({ BridgeTask.detourSide, -BridgeTask.detourSide }) do
                        local px = math.floor(bx + (-ddy * s) * 1.6)
                        local py = math.floor(by + (ddx * s) * 1.6)
                        local cand = cell:getGridSquare(px, py, z)
                        local free = false
                        if cand ~= nil then pcall(function() free = cand:isFree(false) == true end) end
                        if free then
                            BridgeTask.detour = { x = px + 0.5, y = py + 0.5, z = target.z, expires = Bridge.time + 150 }
                            log(string.format("stalled: stepping around via %d,%d", px, py))
                            break
                        end
                    end
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
        end
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
    elseif missing == "broom" then key = "JobNeedBroom" end
    Bridge.speak(key)
end

function BridgeTask.dangerNear(body)
    local danger = false
    local red = BridgeData.owner()
    pcall(function()
        if BridgeFight ~= nil and (BridgeFight.target ~= nil or BridgeFight.state ~= "idle") then danger = true return end
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= body and z:isAlive() and z:getHealth() > 0
                and not z:getVariableBoolean("NotAloneBody") and not BridgeData.harmless(z)
                and math.abs(z:getZ() - body:getZ()) < 0.8 then
                local d = dist2(z, body)
                local dr = red ~= nil and dist2(z, red) or 999
                if d < BridgeTask.DANGER_RADIUS or dr < BridgeTask.DANGER_RADIUS then
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
    BridgeTask.detour = nil
    BridgeTask.detourSide = nil
    restoreForcedWalk()
    Bridge.target = nil
end

function BridgeTask.start(kind, targets)
    if BridgeTask.ENABLED ~= 1 then return "disabled" end
    if BridgeTask.active then return "busy" end
    if Bridge == nil or not Bridge.alive() or Bridge.kind ~= "zombie" then return "no body" end
    if Bridge.drivable ~= nil and not Bridge.drivable() then return "not drivable" end
    if type(targets) ~= "table" or #targets == 0 then return "no targets" end
    local def = BridgeTask.kinds[kind]
    if def == nil then return "unknown job" end
    if def.available ~= nil and not def.available(Bridge.body) then
        BridgeTask.speakMissing(kind)
        return "unavailable"
    end

    if kind == "chopTree" and BridgeFight ~= nil
            and (1 - (BridgeFight.fatigue or 0)) < BridgeTask.CHOP_REFUSE_STAMINA then
        Bridge.speak("JobNeedRest")
        return "tired"
    end

    BridgeTask.kind = kind
    BridgeTask.queue = {}
    for i = 1, #targets do BridgeTask.queue[i] = targets[i] end
    if BridgeWorkSelect ~= nil and BridgeWorkSelect.sortTargets ~= nil then
        pcall(BridgeWorkSelect.sortTargets, BridgeTask.queue)
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
    BridgeTask.prevForcedWalk = BridgeMove ~= nil and BridgeMove.forcedWalk or nil
    BridgeTask.forcedWalkSaved = true
    BridgeTask.cleanApplied = {}
    BridgeTask.chargeCleanSpend()
    BridgeTask.cleanSoundHandle = nil
    BridgeTask.subHands = nil
    BridgeTask.cleanHandsKey = nil
    BridgeTask.cleanStowPending = false
    BridgeTask.cleanDrawPending = false
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
    BridgeTask.info = "start " .. tostring(kind)
    Bridge.follow = false
    Bridge.target = nil
    pcall(function() BridgeMove.stopPath(Bridge.body) end)
    pcall(function() BridgeFight.reset(Bridge.body) end)
    pcall(function() BridgeWeapon.cancelMove(nil) end)
    pcall(function() BridgeTask.clearChop(Bridge.body) end)


    if kind == "cleanUp" then pcall(stowCleanWeapon, Bridge.body) end





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
    BridgeTask.target = nil
    BridgeTask.needImplement, BridgeTask.needFluid = nil, nil
    BridgeTask.needPetrol, BridgeTask.needAshTool = nil, nil
    BridgeTask.needCut = nil
    BridgeTask.clearNeedCut = nil
    BridgeTask.cleanApplied = {}
    BridgeTask.chargeCleanSpend()
    BridgeTask.cleanStowPending = false
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
    restoreForcedWalk()
    if body ~= nil then pcall(endCleanHands, body) end
    if body ~= nil then pcall(stopCleanSound, body) end
    if body ~= nil then pcall(restoreHands, body) end
    if body ~= nil then pcall(function() BridgeMove.stopPath(body) end) end
    if reason ~= "mode" and Bridge.setMode ~= nil then Bridge.setMode("follow") end
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
    BridgeTask.chopRest = false
    BridgeTask.chopRestSitAt = nil
    BridgeTask.chopResumeAt = nil
    BridgeTask.info = "done"
    Bridge.target = nil
    local wasLootFull = BridgeTask.lootFull == true
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
        if wasLootFull then Bridge.speak("JobLootFull") else Bridge.speak("JobDone") end
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
        local p = (t - BridgeTask.scrubStart) / span
        if p < 0 then p = 0 elseif p > 1 then p = 1 end
        return p
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
    if BridgeTask.dangerNear(body) then
        BridgeTask.cancel("danger")
        return false
    end

    pcall(function() BridgeMove.closeBehind(body) end)
    local def = BridgeTask.kinds[BridgeTask.kind]
    if def == nil or def.update == nil then
        BridgeTask.cancel("error")
        return false
    end
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
    if tree ~= nil then
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

    local axe = BridgeTask.findAxe(body)
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

    local age = Bridge.time - BridgeTask.swingStart
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
            if not BridgeTask.recordCleanNeeds(body, sq) then
                table.remove(BridgeTask.queue, i)
            else
                local d = (bx - t.x) ^ 2 + (by - t.y) ^ 2
                if bestAnyD == nil or d < bestAnyD then bestAnyD = d; bestAnyI = i end
                if bodyKey == nil or BridgeTask.enclosureKeyOf(sq) == bodyKey then
                    if bestD == nil or d < bestD then bestD = d; bestI = i end
                end
                i = i + 1
            end
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
        BridgeTask.vineObject = nil
        BridgeTask.chargeCleanSpend()
        BridgeTask.bestD = nil
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
    end

    local square = getCell():getGridSquare(target.x, target.y, target.z)
    log(string.format("target %d,%d enclosure=%s", target.x, target.y, tostring(BridgeTask.enclosureKeyOf(square))))




    local kind = BridgeTask.cleanCanDo(body, square, BridgeTask.cleanApplied)
    if kind == nil then
        BridgeTask.recordCleanNeeds(body, square)
        BridgeTask.clearChop(body)
        pcall(stopCleanSound, body)
        BridgeTask.info = "clean"
        BridgeTask.current = nil
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        return true
    end
    local tool, cleaner = BridgeTask.cleanKindTool(body, kind)

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
        wall = stainIsWall(square)
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

    local age = Bridge.time - BridgeTask.swingStart


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
    if (Bridge.time - (BridgeTask.scrubStart or Bridge.time)) >= workTime then
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
            if plantKind(sq) == nil then
                table.remove(BridgeTask.queue, i)
            else
                local d = (bx - t.x) ^ 2 + (by - t.y) ^ 2
                if bestAnyD == nil or d < bestAnyD then bestAnyD = d; bestAnyI = i end
                if bodyKey == nil or BridgeTask.enclosureKeyOf(sq) == bodyKey then
                    if bestD == nil or d < bestD then bestD = d; bestI = i end
                end
                i = i + 1
            end
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
        BridgeTask.bestD = nil
        BridgeTask.progressAt = Bridge.time
        BridgeTask.pathFails = 0
        BridgeTask.pathFailTick = nil
    end

    local square = getCell():getGridSquare(target.x, target.y, target.z)
    local kind = plantKind(square)
    if kind == nil then
        BridgeTask.clearChop(body)
        BridgeTask.info = "clear"
        BridgeTask.current = nil
        if #BridgeTask.queue == 0 then return BridgeTask.finish() end
        return true
    end

    local tool = nil
    if kind == "bush" then
        tool = BridgeTask.findCutTool(body)
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

    local age = Bridge.time - BridgeTask.swingStart

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
    if (Bridge.time - (BridgeTask.clearStart or Bridge.time)) >= workTime then
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

function BridgeTask.lootFilter(item, kind)
    if item == nil or BridgeData == nil then return false end
    local rec = Bridge ~= nil and Bridge.store or nil
    local maxW = BridgeData.lootMaxWeight(rec)
    local w = BridgeTask.lootWeight(item)
    if maxW > 0 and w > maxW then
        if Bridge ~= nil and Bridge.verbose then
            log(string.format("loot skip heavy %s w=%.2f > %.2f", tostring(item:getType()), w, maxW))
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
            log(string.format("loot skip cat %s pool=%s disp=%s", tostring(item:getType()), tostring(pool), tostring(disp)))
        end
        return true
    end
    if Bridge ~= nil and Bridge.verbose then
        local disp = nil
        pcall(function() disp = item:getDisplayCategory() end)
        log(string.format("loot take %s pool=%s disp=%s", tostring(item:getType()), tostring(pool), tostring(disp)))
    end
    return false
end

function BridgeTask.lootItems(body, target)
    local items = {}
    if target == nil then return items end
    local c = target.cont
    if c == nil then return items end
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
        if isClient() then
            local group = BridgeInventory.sameStack(src, item, BridgeInventory.LOOT_STACK_MAX)
            if act.bridgeRelay ~= nil then
                act.queueList = { { items = group, time = act.maxTime, type = item:getFullType() } }
                act.bridgeRelay.group = group
            else
                act.group = group
            end
        else
            local full = item:getFullType()
            local group = { item }
            local list = src:getItems()
            for i = 0, list:size() - 1 do
                local it = list:get(i)
                if it ~= nil and it ~= item and it:getFullType() == full then group[#group + 1] = it end
            end
            if #group > 1 then
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
    pcall(function()
        if BridgeQueue ~= nil and BridgeQueue.indexOf ~= nil then
            local i = BridgeQueue.indexOf(act)
            if i ~= nil then table.remove(BridgeQueue.jobs, i) end
        end
        act:forceCancel()
    end)
end

function BridgeTask.lootSay(item, kind)
    if BridgeTask.lootFullSaid then return end
    if BridgeMoments == nil or BridgeMoments.say == nil then return end
    local event = nil
    if kind == "floor" then event = "LootGround"
    elseif kind == "body" then event = "LootCorpse" end
    if event == nil and item ~= nil and BridgeSocial ~= nil and BridgeSocial.receivePool ~= nil then
        local pool = nil
        pcall(function() pool = BridgeSocial.receivePool(item) end)
        if type(pool) == "string" and string.sub(pool, 1, 7) == "Receive" then
            local cand = "Loot" .. string.sub(pool, 8)
            local exists = nil
            pcall(function() exists = getTextOrNull("IGUI_NotAlone_Soc_" .. cand .. "_Near_1", "", "") end)
            if type(exists) == "string" and exists ~= "" and exists ~= ("IGUI_NotAlone_Soc_" .. cand .. "_Near_1") then
                event = cand
            end
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
        pcall(function() skip = BridgeTask.lootFilter(item, target.kind) == true end)
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

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeTask] loaded") end
