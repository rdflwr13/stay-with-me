require "ISUI/ISRadialMenu"
require "ISUI/ISUI3DModel"

BridgeRadial = BridgeRadial or {}

local KEY_NAME = "Companion Wheel"
local KEY_SECTION = "[Companion]"
local HOLD_MS = 400
local AVATAR_SIZE = 170
local AVATAR_ENABLED = false

local ICONS = {
    follow = "media/textures/RadialMenu/ComeWithMe.png",
    wait = "media/textures/RadialMenu/WaitHere.png",
    talk = "media/textures/RadialMenu/TalkMenu.png",
    heal = "media/textures/RadialMenu/TreatMyWounds.png",
    fight = "media/textures/RadialMenu/FightMainMenu.png",
    guns = "media/textures/RadialMenu/GunMainMenu.png",
    keep = "media/ui/emotes/followbehind.png",
    work = "media/textures/RadialMenu/WorkMainMenu.png",
    depositHome = "media/textures/RadialMenu/WorkDepositAllLoot.png",
    depositArea = "media/textures/RadialMenu/WorkDepositLootInArea.png",
    self = "media/textures/RadialMenu/SelfMenu.png",
    gear = "media/textures/RadialMenu/EquipmentAppearanceMenu.png",
    call = "media/ui/emotes/wavehello.png",
    back = "media/ui/emotes/back.png",
    fallback = "media/ui/Sidebar/NotAlone_On_48.png",
    chat = "media/textures/RadialMenu/TalkChat.png",
    joke = "media/textures/RadialMenu/TalkJoke.png",
    compliment = "media/textures/RadialMenu/TalkCompliment.png",
    thanks = "media/textures/RadialMenu/TalkThanks.png",
    comfort = "media/textures/RadialMenu/TalkComfort.png",
    flirt = "media/textures/RadialMenu/TalkFlirt.png",
    hug = "media/ui/emotes/group.png",
    ask = "media/textures/RadialMenu/TalkAsk.png",
    bodyguard = "media/textures/RadialMenu/FightCoverMe.png",
    escort = "media/textures/RadialMenu/FightClearAroundUs.png",
    aggressive = "media/textures/RadialMenu/FightGoAfterThem.png",
    backup = "media/textures/RadialMenu/FightBackMeUp.png",
    stayback = "media/textures/RadialMenu/FightStayBehindMe.png",
    closer = "media/textures/RadialMenu/StayCloser.png",
    farther = "media/textures/RadialMenu/StayFurther.png",
    behind = "media/ui/emotes/followbehind.png",
    left = "media/ui/arrow_left.png",
    right = "media/ui/arrow_right.png",
    loot = "media/textures/RadialMenu/WorkLootArea.png",
    clean = "media/textures/RadialMenu/WorkMopUp.png",
    plants = "media/textures/RadialMenu/WorkCutPlants.png",
    chop = "media/textures/RadialMenu/ImageChopTrees.png",
    corpses = "media/textures/RadialMenu/WorkMoveCorpses.png",
    stopWork = "media/ui/emotes/no.png",
    rest = "media/textures/RadialMenu/TakeARest.png",
    exercise = "media/textures/RadialMenu/Exercise.png",
    wash = "media/textures/WorldItems/Soap.png",
    shower = "media/textures/WorldItems/BathTowel.png",
    dress = "media/textures/ClothingTShirt.png",
    equip = "media/textures/RadialMenu/EquipmentMenu.png",
    appearance = "media/textures/RadialMenu/AppearanceMenu.png",
    torchOff = "media/textures/RadialMenu/FlashlightOff.png",
    torchOn = "media/textures/RadialMenu/FlashLightOn.png",
    gunUseOn = "media/textures/RadialMenu/GunUseOn.png",
    gunUseOff = "media/textures/RadialMenu/GunUseOff.png",
    gunMeleeOn = "media/textures/RadialMenu/GunMeleeOn.png",
    gunMeleeOff = "media/textures/RadialMenu/GunMeleeOff.png",
    gunReloadOn = "media/textures/RadialMenu/GunMagReloadOn.png",
    gunReloadOff = "media/textures/RadialMenu/GunMagReloadOff.png",
    gunMagOn = "media/textures/RadialMenu/GunMagazineCareOn.png",
    gunMagOff = "media/textures/RadialMenu/GunMagazineCareOff.png",
    reserveFree = "media/textures/RadialMenu/GunUseFreely.png",
    reserveConserve = "media/textures/RadialMenu/GunUseConserve.png",
    reserveEmergency = "media/textures/RadialMenu/GunUseEmergency.png",
}

local TALK_ICONS = {
    Chat = "chat",
    Joke = "joke",
    Compliment = "compliment",
    Thanks = "thanks",
    Comfort = "comfort",
    Flirt = "flirt",
    Hug = "hug",
    Ask = "ask",
}

local DEFAULT_ORDER = { "wait", "talk", "heal", "fight", "guns", "keep", "jobs", "actions", "equip" }
local RADIAL_ONLY = {
    wait = true, talk = true, heal = true, fight = true, guns = true,
    keep = true, jobs = true, actions = true, equip = true, torch = true,
}

BridgeRadial.DEFAULT_ORDER = DEFAULT_ORDER
BridgeRadial.off = false
BridgeRadial.joypad = false
BridgeRadial.controllerHintShown = false

local state = {}

BridgeRadial.debug = false

local function dbg(text)
    if BridgeRadial.debug then
        print("[BridgeRadial][dbg] " .. tostring(text))
    end
end

function BridgeRadial.selectedSliceIndex(menu, joypadData)
    if menu == nil then return 1 end
    local count = #menu.slices
    if menu.javaObject ~= nil and joypadData ~= nil and joypadData.id ~= nil then
        local index = -1
        pcall(function() index = menu.javaObject:getSliceIndexFromJoypad(joypadData.id) end)
        if type(index) == "number" and index >= 0 and index < count then return index + 1 end
    end
    local i = BridgeRadial.dpadIndex or 1
    if count > 0 then
        if i > count then i = count end
        if i < 1 then i = 1 end
        return i
    end
    return 1
end

function BridgeRadial.cycleSelection(direction)
    local menu = BridgeRadial.activeMenu
    if menu == nil then return end
    local count = #menu.slices
    if count == 0 then return end
    local i = BridgeRadial.dpadIndex or 1
    if direction == "left" or direction == "up" then
        i = i - 1
    else
        i = i + 1
    end
    if i < 1 then i = count end
    if i > count then i = 1 end
    BridgeRadial.dpadIndex = i
end

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeRadial] " .. tostring(text)) end
end

local function warn(text) print("[BridgeRadial] " .. tostring(text)) end

local function fail(err)
    if BridgeRadial.off then return end
    BridgeRadial.off = true
    warn("wheel disabled for this session: " .. tostring(err))
end

local function guarded(fn, ...)
    if BridgeRadial.off then return end
    local ok, err = pcall(fn, ...)
    if not ok then fail(err) end
end

local function tr(key, a)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key, a) end
    local text = key
    pcall(function()
        if a ~= nil then text = getText("IGUI_NotAlone_" .. key, a) else text = getText("IGUI_NotAlone_" .. key) end
    end)
    return text
end

local function labelOr(key, fallback)
    local text = tr(key)
    if type(text) ~= "string" or text == "" or text == key or text == ("IGUI_NotAlone_" .. key) then
        return fallback or key
    end
    return text
end

local function companionName()
    local who = "Rin"
    pcall(function() if Bridge ~= nil and type(Bridge.companionName) == "function" then who = Bridge.companionName() end end)
    if type(who) ~= "string" or who == "" then who = "Rin" end
    return who
end

local function texture(path)
    local tex = nil
    pcall(function() tex = getTexture(path or ICONS.fallback) end)
    if tex == nil then pcall(function() tex = getTexture(ICONS.fallback) end) end
    return tex
end

local function make(label, icon, run, tip)
    return { label = label, icon = icon, run = run, tip = tip }
end

local function addSlices(menu, list, append)
    local offset = 0
    if append then
        offset = #menu.slices
        menu.bridgeTips = menu.bridgeTips or {}
    else
        menu.bridgeTips = {}
    end
    for i = 1, #list do
        local entry = list[i]
        local run = entry.run
        menu.bridgeTips[offset + i] = entry.tip
        menu:addSlice(entry.label, texture(entry.icon), function() guarded(run) end)
    end
end

local function backLabel()
    local text = nil
    pcall(function() text = getText("IGUI_Emote_Back") end)
    if type(text) ~= "string" or text == "" or text == "IGUI_Emote_Back" then text = "Back" end
    return text
end

local function talkEntries()
    local out = {}
    if BridgeSocial == nil or type(BridgeSocial.menuTalkOptions) ~= "function" then return out end
    local opts = nil
    pcall(function() opts = BridgeSocial.menuTalkOptions() end)
    if opts == nil then return out end
    for _, option in ipairs(opts) do
        if option.blocked == nil then
            local id = option.id
            local ask = option.ask == true
            local label = tr(option.label)
            local icon = ICONS[TALK_ICONS[id] or "talk"]
            local run = function()
                if ask then
                    BridgeSocial.ask()
                else
                    BridgeSocial.talk(id)
                end
            end
            out[#out + 1] = make(label, icon, run)
        end
    end
    return out
end

local function fightEntries()
    local out = {}
    local st = Bridge.store
    if st == nil then return out end
    local current = BridgeData.combatOf(st)
    local defs = {
        { id = "bodyguard", key = "CombatBodyguard", icon = ICONS.bodyguard },
        { id = "escort", key = "CombatEscort", icon = ICONS.escort },
        { id = "aggressive", key = "CombatAggressive", icon = ICONS.aggressive },
        { id = "backup", key = "CombatBackMeUp", icon = ICONS.backup },
        { id = "stayback", key = "CombatStayBack", icon = ICONS.stayback },
    }
    for _, def in ipairs(defs) do
        if current ~= def.id then
            local mode = def.id
            out[#out + 1] = make(tr(def.key), def.icon, function() BridgeMenu.onCombat(mode) end, tr(def.key .. "Tip"))
        end
    end
    if BridgeData.KEEP_ON == true then
        if BridgeData.farOf(st) then
            out[#out + 1] = make(tr("RadialStayCloser"), ICONS.closer, function() BridgeMenu.onKeepDistance("near") end)
        else
            out[#out + 1] = make(tr("RadialStayFurther"), ICONS.farther, function() BridgeMenu.onKeepDistance("far") end)
        end
    end
    return out
end

local function stayEntries()
    local out = {}
    local st = Bridge.store
    if st == nil or BridgeData.KEEP_ON ~= true then return out end

    if BridgeData.KEEP_SIDES_ON == true then
        local side = BridgeData.keepOf(st)
        local defs = {
            { id = "behind", key = "KeepBehind", icon = ICONS.behind },
            { id = "left", key = "KeepLeft", icon = ICONS.left },
            { id = "right", key = "KeepRight", icon = ICONS.right },
        }
        for _, def in ipairs(defs) do
            if side ~= def.id then
                local which = def.id
                out[#out + 1] = make(tr(def.key), def.icon, function() BridgeMenu.onKeepSide(which) end)
            end
        end
    end
    return out
end

local function jobsBusy()
    if BridgeTask ~= nil and BridgeTask.active == true then return true end
    if BridgeQueue ~= nil and type(BridgeQueue.jobs) == "table" and #BridgeQueue.jobs > 0 then return true end
    return false
end

local JOB_KINDS = {
    lootArea = true, depositArea = true, deposit = true, cleanUp = true, clearPlants = true, chopTree = true,
    moveCorpses = true, pryDoor = true, fillWater = true, emptyFluid = true,
    washSink = true,
}

local function doingJob()
    if BridgeQueue ~= nil and type(BridgeQueue.jobs) == "table" and #BridgeQueue.jobs > 0 then return true end
    if BridgeTask ~= nil and BridgeTask.active == true and JOB_KINDS[BridgeTask.kind] == true then return true end
    return false
end

local function workEntries()
    local out = {}
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 then return out end
    if jobsBusy() then
        if Bridge.store ~= nil and BridgeData.menuShown(Bridge.store, "cancel") then
            local entry = nil
            pcall(function() entry = BridgeMenu.cancelEntry() end)
            if entry ~= nil then
                out[#out + 1] = make(tr(entry.key), ICONS.stopWork, entry.handler)
            end
        end
        return out
    end
    local defs = {
        { flag = "LOOTING_ENABLED", kind = "lootArea", key = "JobLootArea", handler = BridgeMenu.onJobLootArea, icon = ICONS.loot },
        { flag = "DEPOSIT_ENABLED", kind = "depositArea", key = "JobDepositArea", handler = BridgeMenu.onJobDepositArea, icon = ICONS.depositArea },
        { flag = "DEPOSIT_ENABLED", kind = "deposit", key = "DepositLootHome", handler = BridgeMenu.onDepositHome, icon = ICONS.depositHome,
            when = function() return BridgeDeposit ~= nil and BridgeDeposit.homeHere() end },
        { flag = "CLEANING_ENABLED", kind = "cleanUp", key = "JobCleanUp", handler = BridgeMenu.onJobCleanUp, icon = ICONS.clean },
        { flag = "CLEARING_ENABLED", kind = "clearPlants", key = "JobClearPlants", handler = BridgeMenu.onJobClearPlants, icon = ICONS.plants },
        { flag = "TREECUTTING_ENABLED", kind = "chopTree", key = "JobChopTree", handler = BridgeMenu.onJobChopTree, icon = ICONS.chop },
        { flag = "MOVE_CORPSES_ENABLED", kind = "moveCorpses", key = "JobMoveCorpses", handler = BridgeMenu.onJobMoveCorpses, icon = ICONS.corpses },
    }
    for _, def in ipairs(defs) do
        if BridgeTask[def.flag] == 1 and (def.when == nil or def.when() == true) then
            local ok = false
            if def.kind == "depositArea" then
                ok = BridgeDeposit ~= nil and type(BridgeDeposit.start) == "function"
            else
                pcall(function() ok = BridgeTask.kinds[def.kind].available(Bridge.body) == true end)
            end
            if ok then
                out[#out + 1] = make(tr(def.key), def.icon, def.handler)
            end
        end
    end
    return out
end

local function exerciseReady()
    if BridgeTask == nil or BridgeExercise == nil then return false end
    if BridgeTask.active == true then return false end
    local ok = false
    pcall(function() ok = BridgeTask.kinds.exercise.available(Bridge.body) == true end)
    if not ok then return false end
    local busy = true
    pcall(function() busy = BridgeExercise.hardBusy() == true end)
    if busy then return false end
    local cool = 0
    pcall(function() cool = tonumber(BridgeExercise.cooldownLeft(nil)) or 0 end)
    return cool <= 0
end

local function selfEntries(playerNum)
    local out = {}
    local st = Bridge.store
    if st == nil then return out end
    if BridgeData.modeOf(st) ~= "rest" then
        out[#out + 1] = make(tr("Rest"), ICONS.rest, BridgeMenu.onRest)
    end
    if exerciseReady() then
        out[#out + 1] = make(tr("Exercise"), ICONS.exercise, BridgeMenu.onExercise)
    end

    if BridgeShower ~= nil and type(BridgeShower.isTabas) == "function" then
        local tabas, shower = false, nil
        pcall(function() tabas = BridgeShower.isTabas() == true end)
        if tabas then pcall(function() shower = BridgeShower.findNearest() end) end
        if shower ~= nil then
            out[#out + 1] = make(tr("ShowerTake"), ICONS.shower, function() BridgeShower.startAtNearest() end)
        end
    end
    if BridgeShower ~= nil and type(BridgeShower.hasPreShower) == "function" then
        local ready = false
        pcall(function() ready = BridgeShower.hasPreShower() == true end)
        if ready then
            out[#out + 1] = make(tr("GetDressed"), ICONS.dress, BridgeMenu.onGetDressed)
        end
    end
    return out
end

local function gearEntries(playerNum)
    local out = {}
    local st = Bridge.store
    if st == nil then return out end
    if BridgeData.menuShown(st, "equip") and BridgeEquip ~= nil and type(BridgeEquip.withinRange) == "function" then
        local near = false
        pcall(function() near = BridgeEquip.withinRange(playerNum) == true end)
        if near then
            out[#out + 1] = make(tr("WindowEquip"), ICONS.equip, function() BridgeMenu.onEquip(playerNum) end)
        end
    end
    if BridgeAppearance ~= nil then
        out[#out + 1] = make(tr("WindowAppearance"), ICONS.appearance, function() BridgeAppearance.open("body") end)
    end
    if BridgeData.menuShown(st, "torch") then
        local mode = BridgeData.torchMode(st)
        if mode ~= "off" then
            out[#out + 1] = make(tr("OptTorch") .. ": " .. tr("OptTorchOff"), ICONS.torchOff, function() BridgeMenu.onTorch("off") end)
        end
        if mode ~= "auto" then
            out[#out + 1] = make(tr("OptTorch") .. ": " .. tr("OptTorchAuto"), ICONS.torchOn, function() BridgeMenu.onTorch("auto") end)
        end
    end
    return out
end

local function gunEntries()
    local out = {}
    local st = Bridge.store
    if st == nil then return out end
    local use = BridgeData.gunUseOf(st)
    if use == "off" then
        out[#out + 1] = make(tr("GunUse") .. ": " .. tr("GunUseAlways"), ICONS.gunUseOn, function() BridgeMenu.onGunUse("always") end, tr("GunUseAlwaysTip"))
    else
        out[#out + 1] = make(tr("GunUse") .. ": " .. tr("GunUseOff"), ICONS.gunUseOff, function() BridgeMenu.onGunUse("off") end, tr("GunUseOffTip"))
    end
    local toggles = {
        { key = "GunMelee", option = "gunMelee", on = BridgeMenu.onGunMelee, onIcon = ICONS.gunMeleeOn, offIcon = ICONS.gunMeleeOff },
        { key = "GunReloadIdle", option = "gunReloadIdle", on = BridgeMenu.onGunReloadIdle, onIcon = ICONS.gunReloadOn, offIcon = ICONS.gunReloadOff },
        { key = "GunMagCare", option = "gunMagCare", on = BridgeMenu.onGunMagCare, onIcon = ICONS.gunMagOn, offIcon = ICONS.gunMagOff },
    }
    for _, def in ipairs(toggles) do
        local current = BridgeData.optionOf(st, def.option) == true
        if current then
            out[#out + 1] = make(tr(def.key) .. ": " .. tr("GunOff"), def.offIcon, function() def.on(false) end, tr(def.key .. "OffTip"))
        else
            out[#out + 1] = make(tr(def.key) .. ": " .. tr("GunOn"), def.onIcon, function() def.on(true) end, tr(def.key .. "OnTip"))
        end
    end
    local reserve = BridgeData.ammoReserveOf(st)
    local modes = {
        { id = "free", key = "GunReserveFree", tip = "GunReserveFreeTip", icon = ICONS.reserveFree },
        { id = "conserve", key = "GunReserveConserve", tip = "GunReserveConserveTip", icon = ICONS.reserveConserve },
        { id = "emergency", key = "GunReserveEmergency", tip = "GunReserveEmergencyTip", icon = ICONS.reserveEmergency },
    }
    for _, mode in ipairs(modes) do
        if reserve ~= mode.id then
            local value = mode.id
            out[#out + 1] = make(tr("GunAmmoReserve") .. ": " .. tr(mode.key), mode.icon, function() BridgeMenu.onAmmoReserve(value) end, tr(mode.tip))
        end
    end
    return out
end

function BridgeRadial.ringEntries(ring, playerNum)
    if ring == "talk" then return talkEntries() end
    if ring == "fight" then return fightEntries() end
    if ring == "stay" then return stayEntries() end
    if ring == "work" then return workEntries() end
    if ring == "self" then return selfEntries(playerNum) end
    if ring == "gear" then return gearEntries(playerNum) end
    if ring == "guns" then return gunEntries() end
    return {}
end

function BridgeRadial.order(st)
    if st ~= nil and type(st.menuOrder) == "table" and BridgeData ~= nil then
        local out = {}
        for _, id in ipairs(BridgeData.menuOrder(st)) do
            if RADIAL_ONLY[id] then out[#out + 1] = id end
        end
        if #out > 0 then return out end
    end
    return DEFAULT_ORDER
end

local function waitSlice(st)
    if BridgeData.modeOf(st) == "follow" then
        return make(tr("WaitHere"), ICONS.wait, BridgeMenu.onWait)
    end
    return make(tr("ComeWithMe"), ICONS.follow, BridgeMenu.onFollow)
end

function BridgeRadial.topEntries(playerNum)
    local out = {}
    local st = Bridge.store
    if Bridge == nil or st == nil then return out end
    if not BridgeMenu.isPresent() or not BridgeMenu.inTalkRange() then
        out[1] = make(tr("Call", companionName()), ICONS.call, BridgeMenu.onCall)
        return out
    end
    local order = BridgeRadial.order(st)
    local gearDone = false
    for _, id in ipairs(order) do
        local shown = BridgeData.menuShown(st, id)
        if id == "equip" or id == "torch" then
            if not gearDone then
                gearDone = true
                local gearShown = BridgeData.menuShown(st, "equip") or BridgeData.menuShown(st, "torch")
                local list = gearShown and BridgeRadial.ringEntries("gear", playerNum) or {}
                if #list > 0 then
                    out[#out + 1] = make(labelOr("RadialGear", "Gear"), ICONS.gear, function()
                        BridgeRadial.showRing("gear", playerNum)
                    end)
                end
            end
        elseif shown and id == "wait" then
            out[#out + 1] = waitSlice(st)
        elseif shown and id == "talk" then
            if #BridgeRadial.ringEntries("talk", playerNum) > 0 then
                out[#out + 1] = make(tr("Talk"), ICONS.talk, function() BridgeRadial.showRing("talk", playerNum) end)
            end
        elseif shown and id == "heal" then
            local alive = Bridge.alive() == true
            local drivable = Bridge.drivable() == true
            local healing = BridgeHeal ~= nil and BridgeHeal.active == true
            if alive and drivable and not healing then
                out[#out + 1] = make(tr("HealMe"), ICONS.heal, BridgeMenu.onHeal)
            end
        elseif shown and id == "fight" then
            local guard = false
            pcall(function() guard = BridgeFight ~= nil and BridgeFight.guardOnly == true end)
            if not guard and #BridgeRadial.ringEntries("fight", playerNum) > 0 then
                out[#out + 1] = make(tr("Combat"), ICONS.fight, function() BridgeRadial.showRing("fight", playerNum) end)
            end
        elseif shown and id == "guns" then
            out[#out + 1] = make(tr("GunMenu"), ICONS.guns, function() BridgeRadial.showRing("guns", playerNum) end)
        elseif shown and id == "keep" then
            if BridgeData.KEEP_ON == true and #BridgeRadial.ringEntries("stay", playerNum) > 0 then
                out[#out + 1] = make(tr("Keep"), ICONS.keep, function() BridgeRadial.showRing("stay", playerNum) end)
            end
        elseif id == "jobs" then
            if doingJob() then
                local entry = nil
                pcall(function() entry = BridgeMenu.cancelEntry() end)
                if entry ~= nil then
                    out[#out + 1] = make(tr("CancelTask"), ICONS.stopWork, entry.handler)
                end
            elseif shown and #BridgeRadial.ringEntries("work", playerNum) > 0 then
                out[#out + 1] = make(tr("Jobs"), ICONS.work, function() BridgeRadial.showRing("work", playerNum) end)
            end
        elseif shown and id == "actions" then
            if #BridgeRadial.ringEntries("self", playerNum) > 0 then
                out[#out + 1] = make(labelOr("RadialSelf", "Self"), ICONS.self, function()
                    BridgeRadial.showRing("self", playerNum)
                end)
            end
        end
    end
    if #out == 0 then
        out[1] = make(tr("Call", companionName()), ICONS.call, BridgeMenu.onCall)
    end
    return out
end

local function removeAvatar()
    local panel = BridgeRadial.avatar
    BridgeRadial.avatar = nil
    BridgeRadial.avatarPlayer = nil
    if panel ~= nil then pcall(function() panel:removeFromUIManager() end) end
end

local function sandboxWheel()
    local t = nil
    pcall(function() t = (SandboxVars ~= nil) and SandboxVars.StayWithMe or nil end)
    return t
end

local CONTROLLER_SELECT_BUTTONS = {
    { id = "bumpers", joypads = { "LBumper", "RBumper" }, labelKey = "IGUI_StayWithMe_SelectButtonEither", fallback = "L1 / R1" },
    { id = "lb",      joypads = { "LBumper" },            labelKey = "IGUI_StayWithMe_SelectButtonL1",     fallback = "L1" },
    { id = "rb",      joypads = { "RBumper" },            labelKey = "IGUI_StayWithMe_SelectButtonR1",     fallback = "R1" },
    { id = "a",       joypads = { "AButton" },            labelKey = "IGUI_StayWithMe_SelectButtonA",      fallback = "A" },
    { id = "x",       joypads = { "XButton" },            labelKey = "IGUI_StayWithMe_SelectButtonX",      fallback = "X" },
    { id = "y",       joypads = { "YButton" },            labelKey = "IGUI_StayWithMe_SelectButtonY",      fallback = "Y" },
}

local function configuredSelectButton()
    local t = sandboxWheel()
    local index = 1
    if t ~= nil and t.CompanionWheelSelectButton ~= nil then
        index = tonumber(t.CompanionWheelSelectButton) or 1
    end
    if index < 1 or index > #CONTROLLER_SELECT_BUTTONS then index = 1 end
    return CONTROLLER_SELECT_BUTTONS[index], index
end

local function selectButtonLabel(def)
    if def == nil then return "L1 / R1" end
    local text = nil
    if type(getTextOrNull) == "function" then
        local got = getTextOrNull(def.labelKey)
        if type(got) == "string" and got ~= "" and got ~= def.labelKey then text = got end
    end
    return text or def.fallback
end

local function selectButtonDown(def, id)
    if def == nil or def.joypads == nil or Joypad == nil then return false end
    for _, name in ipairs(def.joypads) do
        local button = Joypad[name]
        if button ~= nil then
            local held = false
            pcall(function() held = button:isDown(id) == true end)
            if held then return true end
        end
    end
    return false
end

local function isSelectButton(button)
    local def = configuredSelectButton()
    if def == nil or def.joypads == nil or Joypad == nil then return false end
    for _, name in ipairs(def.joypads) do
        if Joypad[name] ~= nil and button == Joypad[name] then return true end
    end
    return false
end

local TIP_MAX_WIDTH = 340
local TIP_PAD = 6

BridgeRadialTip = ISPanel:derive("BridgeRadialTip")

local function measureTip(text)
    return getTextManager():MeasureStringX(UIFont.Small, text)
end

local function wrapTip(text)
    local lines = {}
    local line = ""
    for word in tostring(text):gmatch("%S+") do
        local candidate = (line == "") and word or (line .. " " .. word)
        if measureTip(candidate) <= TIP_MAX_WIDTH then
            line = candidate
        else
            if line ~= "" then lines[#lines + 1] = line end
            while measureTip(word) > TIP_MAX_WIDTH and #word > 1 do
                local cut = #word
                while cut > 1 and measureTip(word:sub(1, cut)) > TIP_MAX_WIDTH do cut = cut - 1 end
                lines[#lines + 1] = word:sub(1, cut)
                word = word:sub(cut + 1)
            end
            line = word
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

local function radialHelpText(key, fallback)
    if type(getTextOrNull) == "function" then
        local got = getTextOrNull(key)
        if type(got) == "string" and got ~= "" and got ~= key then return got end
    end
    return fallback
end

local function drawControllerHelp(panel, menu)
    local select = selectButtonLabel(configuredSelectButton())
    local lines = {}
    local index = BridgeRadial.selectedSliceIndex(menu, menu.joyfocus)
    if menu.slices ~= nil and menu.slices[index] ~= nil then
        local selected = tostring(menu.slices[index].text)
        lines[#lines + 1] = radialHelpText("IGUI_StayWithMe_RadialHelpSelected", "Selected") .. ": " .. selected
    end
    lines[#lines + 1] = radialHelpText("IGUI_StayWithMe_RadialHelpSelect", "Select") .. ": " .. select
    lines[#lines + 1] = radialHelpText("IGUI_StayWithMe_RadialHelpChoose", "Choose: Right Stick / D-Pad")
    lines[#lines + 1] = radialHelpText("IGUI_StayWithMe_RadialHelpClose", "Close: B")
    local font = UIFont.Small
    local lineH = getTextManager():getFontFromEnum(font):getLineHeight()
    local widest = 0
    for _, line in ipairs(lines) do
        widest = math.max(widest, measureTip(line))
    end
    local pad = 6
    local w = widest + pad * 2
    local h = #lines * lineH + pad * 2
    local x = getPlayerScreenLeft(0) + 18
    local y = getPlayerScreenTop(0) + getPlayerScreenHeight(0) - h - 18
    panel:drawRect(x, y, w, h, 0.82, 0.06, 0.06, 0.06)
    panel:drawRectBorder(x, y, w, h, 0.9, 0.45, 0.45, 0.45)
    for i, line in ipairs(lines) do
        panel:drawText(line, x + pad, y + pad + (i - 1) * lineH, 1, 1, 1, 1, font)
    end
end

function BridgeRadialTip:render()
    local menu = BridgeRadial.activeMenu
    if menu == nil or menu.javaObject == nil or not menu:isReallyVisible() then return end
    local tips = menu.bridgeTips
    if tips ~= nil then
        local sliceIndex = nil
        if BridgeRadial.joypad then
            sliceIndex = BridgeRadial.selectedSliceIndex(menu, menu.joyfocus)
        else
            local index = -1
            if menu.joyfocus ~= nil and menu.joyfocus.id ~= nil then
                index = menu.javaObject:getSliceIndexFromJoypad(menu.joyfocus.id)
            else
                index = menu.javaObject:getSliceIndexFromMouse(menu:getMouseX(), menu:getMouseY())
            end
            if type(index) == "number" and index >= 0 then sliceIndex = index + 1 end
        end
        local text = nil
        if sliceIndex ~= nil then text = tips[sliceIndex] end
        if type(text) == "string" and text ~= "" then
            if self.tipText ~= text then
                self.tipText = text
                self.tipLines = wrapTip(text)
                local widest = 0
                for _, line in ipairs(self.tipLines) do
                    widest = math.max(widest, measureTip(line))
                end
                self.tipWidth = math.min(TIP_MAX_WIDTH, widest) + TIP_PAD * 2
            end
            local lineH = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
            local height = #self.tipLines * lineH + TIP_PAD * 2
            local screenW = getCore():getScreenWidth()
            local screenH = getCore():getScreenHeight()
            local x = menu:getX() + menu:getWidth() / 2 - self.tipWidth / 2
            local y = menu:getY() + menu:getHeight() + 8
            if y + height > screenH - 8 then y = menu:getY() - height - 8 end
            x = math.max(8, math.min(x, screenW - self.tipWidth - 8))
            y = math.max(8, math.min(y, screenH - height - 8))
            self:drawRect(x, y, self.tipWidth, height, 0.92, 0.08, 0.08, 0.08)
            self:drawRectBorder(x, y, self.tipWidth, height, 0.9, 0.45, 0.45, 0.45)
            for i, line in ipairs(self.tipLines) do
                self:drawText(line, x + TIP_PAD, y + TIP_PAD + (i - 1) * lineH, 1, 1, 1, 1, UIFont.Small)
            end
        end
    end
    if BridgeRadial.joypad then drawControllerHelp(self, menu) end
end

local function removeTip()
    local panel = BridgeRadial.tip
    BridgeRadial.tip = nil
    if panel ~= nil then pcall(function() panel:removeFromUIManager() end) end
end

local function removeOverlays()
    if BridgeRadial.activeMenu ~= nil and ISRadialMenu ~= nil then
        BridgeRadial.activeMenu.onJoypadDown = ISRadialMenu.onJoypadDown
    end
    BridgeRadial.activeMenu = nil
    BridgeRadial.dpadIndex = nil
    BridgeRadial.selectHeld = nil
    removeAvatar()
    removeTip()
end

local function showTipPanel()
    if BridgeRadial.tip == nil then
        local panel = BridgeRadialTip:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
        panel:noBackground()
        panel:initialise()
        panel:instantiate()
        panel:setWantMouseEvents(false)
        panel:addToUIManager()
        BridgeRadial.tip = panel
    end
    if BridgeRadial.tip ~= nil then pcall(function() BridgeRadial.tip:bringToTop() end) end
end

local function showAvatar(playerNum)
    if not AVATAR_ENABLED then
        removeAvatar()
        return
    end
    if Bridge == nil or Bridge.body == nil or BridgeMenu == nil then
        removeAvatar()
        return
    end
    if not BridgeMenu.isPresent() then
        removeAvatar()
        return
    end
    if BridgeRadial.avatar ~= nil then
        if BridgeRadial.avatarPlayer == playerNum then return end
        removeAvatar()
    end
    local panel = nil
    local made = pcall(function()
        local p = ISUI3DModel:new(0, 0, AVATAR_SIZE, AVATAR_SIZE)
        p.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        p.borderColor = { r = 0, g = 0, b = 0, a = 0 }
        p:initialise()
        p:instantiate()
        p:setWantMouseEvents(false)
        p:setCharacter(Bridge.body)
        p:setState("idle")
        p:setDirection(IsoDirections.S)
        p:setIsometric(false)
        p:setDoRandomExtAnimations(false)
        p:setZoom(0)
        p:setYOffset(0)
        p:setXOffset(0)
        p.javaObject:setAnimate(false)
        p.prerender = function(self)
            ISUIElement.prerender(self)
            if self.javaObject ~= nil then self.javaObject:setAnimate(false) end
        end
        panel = p
    end)
    if not made or panel == nil then return end
    local cx = getPlayerScreenLeft(playerNum) + getPlayerScreenWidth(playerNum) / 2
    local cy = getPlayerScreenTop(playerNum) + getPlayerScreenHeight(playerNum) / 2
    panel:setX(cx - AVATAR_SIZE / 2)
    panel:setY(cy - AVATAR_SIZE / 2)
    local ok = pcall(function() panel:addToUIManager() end)
    if not ok then return end
    pcall(function() panel:setWantMouseEvents(false) end)
    BridgeRadial.avatar = panel
    BridgeRadial.avatarPlayer = playerNum
end

local function sandboxControllerEnabled()
    local t = sandboxWheel()
    if t == nil or t.CompanionWheelController == nil then return true end
    return t.CompanionWheelController == true
end

local CONTROLLER_BUTTONS = {
    { id = "dpadLeft",  joypad = "DPadLeft",   dpad = "left",  labelKey = "IGUI_StayWithMe_ControllerButtonDPadLeft",  fallback = "D-Pad Left" },
    { id = "dpadRight", joypad = "DPadRight",  dpad = "right", labelKey = "IGUI_StayWithMe_ControllerButtonDPadRight", fallback = "D-Pad Right" },
    { id = "dpadUp",    joypad = "DPadUp",     dpad = "up",    labelKey = "IGUI_StayWithMe_ControllerButtonDPadUp",    fallback = "D-Pad Up" },
    { id = "dpadDown",  joypad = "DPadDown",   dpad = "down",  labelKey = "IGUI_StayWithMe_ControllerButtonDPadDown",  fallback = "D-Pad Down" },
    { id = "lstick",    joypad = "LStickButton",                labelKey = "IGUI_StayWithMe_ControllerButtonL3",        fallback = "L3" },
    { id = "rstick",    joypad = "RStickButton",                labelKey = "IGUI_StayWithMe_ControllerButtonR3",        fallback = "R3" },
}

local function configuredControllerButton()
    local t = sandboxWheel()
    local index = 1
    if t ~= nil and t.CompanionWheelControllerButton ~= nil then
        index = tonumber(t.CompanionWheelControllerButton) or 1
    end
    if index < 1 or index > #CONTROLLER_BUTTONS then index = 1 end
    return CONTROLLER_BUTTONS[index], index
end

local function controllerJoypadButton(def)
    if def == nil or def.joypad == nil or Joypad == nil then return nil end
    return Joypad[def.joypad]
end

local function controllerDebugConfig(tag)
    local t = sandboxWheel()
    local def, index = configuredControllerButton()
    local raw = nil
    if t ~= nil then raw = t.CompanionWheelControllerButton end
    dbg(tostring(tag)
        .. " enabled=" .. tostring(sandboxControllerEnabled())
        .. " rawButton=" .. tostring(raw)
        .. " index=" .. tostring(index)
        .. " id=" .. tostring(def and def.id)
        .. " joypad=" .. tostring(def and def.joypad))
end

local function controllerButtonDown(def, id)
    local button = controllerJoypadButton(def)
    if button == nil then return false end
    local held = false
    pcall(function() held = button:isDown(id) == true end)
    return held
end

local function controllerButtonLabel(def)
    if def == nil then return "D-Pad Left" end
    local text = nil
    if type(getTextOrNull) == "function" then
        local got = getTextOrNull(def.labelKey)
        if type(got) == "string" and got ~= "" and got ~= def.labelKey then text = got end
    end
    return text or def.fallback
end

local function present(menu, playerNum)
    menu:center()
    menu:addToUIManager()
    BridgeRadial.activeMenu = menu
    if BridgeRadial.joypad and JoypadState ~= nil and JoypadState.players ~= nil and JoypadState.players[playerNum + 1] then
        local trigger = configuredControllerButton()
        local select = configuredSelectButton()
        local selectHeld = false
        pcall(function()
            local joypad = getJoypadData(playerNum)
            if joypad ~= nil then selectHeld = selectButtonDown(select, joypad.id) == true end
        end)
        BridgeRadial.dpadIndex = 1
        BridgeRadial.selectHeld = selectHeld == true and true or nil
        menu.hideWhenButtonReleased = nil
        menu.onJoypadDown = function(radial, button, joypadData)
            if isSelectButton(button) then return end
            return ISRadialMenu.onJoypadDown(radial, button, joypadData)
        end
        dbg("present player=" .. tostring(playerNum)
            .. " trigger=" .. tostring(trigger and trigger.id)
            .. " select=" .. tostring(select and select.id)
            .. " latch=" .. tostring(selectHeld == true))
        setJoypadFocus(playerNum, menu)
    else
        menu.hideWhenButtonReleased = nil
        menu.onJoypadDown = ISRadialMenu.onJoypadDown
    end
    showAvatar(playerNum)
    pcall(function() menu:bringToTop() end)
    showTipPanel()
end

local function fillTop(playerNum)
    local menu = getPlayerRadialMenu(playerNum)
    if menu == nil then return false end
    menu:clear()
    menu.bridgeTips = {}
    local list = BridgeRadial.topEntries(playerNum)
    if #list == 0 then return false end
    addSlices(menu, list)
    present(menu, playerNum)
    return true
end

function BridgeRadial.openTop(playerNum)
    guarded(fillTop, playerNum)
end

local function fillRing(ring, playerNum)
    local menu = getPlayerRadialMenu(playerNum)
    if menu == nil then return end
    menu:clear()
    menu.bridgeTips = {}
    local list = BridgeRadial.ringEntries(ring, playerNum)
    addSlices(menu, list)
    menu:addSlice(backLabel(), texture(ICONS.back), function() BridgeRadial.openTop(playerNum) end)
    present(menu, playerNum)
end

function BridgeRadial.showRing(ring, playerNum)
    guarded(fillRing, ring, playerNum)
end

local function canOpen(playerNum)
    if Bridge == nil or Bridge.store == nil then return false end
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil or playerObj:isDead() then return false end
    if playerObj:getVehicle() ~= nil then return false end
    if isGamePaused() then return false end
    local dragging = false
    pcall(function() dragging = getCell():getDrag(playerNum) ~= nil end)
    if dragging then return false end
    local queue = nil
    if ISTimedActionQueue ~= nil then queue = ISTimedActionQueue.queues[playerObj] end
    if queue ~= nil and queue.queue ~= nil and #queue.queue > 0 then return false end
    return true
end

local function startWheel(playerNum)
    if not canOpen(playerNum) then return end
    local menu = getPlayerRadialMenu(playerNum)
    if menu == nil or menu:isReallyVisible() then return end
    BridgeRadial.joypad = false
    fillTop(playerNum)
end

function BridgeRadial.open(playerNum)
    guarded(startWheel, playerNum)
end

function BridgeRadial.openController(playerNum)
    if BridgeRadial.off then return false end
    local opened = false
    local ok, err = pcall(function()
        if not canOpen(playerNum) then return end
        local menu = getPlayerRadialMenu(playerNum)
        if menu == nil or menu:isReallyVisible() then return end
        BridgeRadial.joypad = true
        opened = fillTop(playerNum) == true
    end)
    if not ok then
        BridgeRadial.joypad = false
        fail(err)
        return false
    end
    if not opened then BridgeRadial.joypad = false end
    return opened
end

local function controllerWheelAvailable(playerNum)
    if BridgeRadial.off or not sandboxControllerEnabled() then return false end
    return canOpen(playerNum)
end

local function controllerWheelReady(playerNum)
    if not controllerWheelAvailable(playerNum) then return false end
    local list = nil
    local ok = pcall(function() list = BridgeRadial.topEntries(playerNum) end)
    return ok and list ~= nil and #list > 0
end

local function openControllerWheel(playerNum)
    if not controllerWheelAvailable(playerNum) then return false end
    local opened = false
    local ok, err = pcall(function() opened = BridgeRadial.openController(playerNum) end)
    if not ok then
        fail(err)
        return false
    end
    if opened then return true end
    return BridgeRadial.activeMenu ~= nil and BridgeRadial.activeMenu:isReallyVisible()
end

local SANDBOX_KEY_CODES = {
    (Mouse and Mouse.BTN_3) or 0,
    (Mouse and Mouse.BTN_4) or 0,
    (Mouse and Mouse.BTN_2) or 0,
    (Mouse and Mouse.BTN_0) or 0,
    (Mouse and Mouse.BTN_1) or 0,
    (Mouse and Mouse.BTN_5) or 0,
    (Mouse and Mouse.BTN_6) or 0,
    (Mouse and Mouse.BTN_7) or 0,
    0,
    (Keyboard and Keyboard.KEY_ESCAPE) or 0,
    (Keyboard and Keyboard.KEY_F1) or 0,
    (Keyboard and Keyboard.KEY_F2) or 0,
    (Keyboard and Keyboard.KEY_F3) or 0,
    (Keyboard and Keyboard.KEY_F4) or 0,
    (Keyboard and Keyboard.KEY_F5) or 0,
    (Keyboard and Keyboard.KEY_F6) or 0,
    (Keyboard and Keyboard.KEY_F7) or 0,
    (Keyboard and Keyboard.KEY_F8) or 0,
    (Keyboard and Keyboard.KEY_F9) or 0,
    (Keyboard and Keyboard.KEY_F10) or 0,
    (Keyboard and Keyboard.KEY_F11) or 0,
    (Keyboard and Keyboard.KEY_F12) or 0,
    (Keyboard and Keyboard.KEY_SYSRQ) or 0,
    (Keyboard and Keyboard.KEY_SCROLL) or 0,
    (Keyboard and Keyboard.KEY_PAUSE) or 0,
    (Keyboard and Keyboard.KEY_GRAVE) or 0,
    (Keyboard and Keyboard.KEY_1) or 0,
    (Keyboard and Keyboard.KEY_2) or 0,
    (Keyboard and Keyboard.KEY_3) or 0,
    (Keyboard and Keyboard.KEY_4) or 0,
    (Keyboard and Keyboard.KEY_5) or 0,
    (Keyboard and Keyboard.KEY_6) or 0,
    (Keyboard and Keyboard.KEY_7) or 0,
    (Keyboard and Keyboard.KEY_8) or 0,
    (Keyboard and Keyboard.KEY_9) or 0,
    (Keyboard and Keyboard.KEY_0) or 0,
    (Keyboard and Keyboard.KEY_MINUS) or 0,
    (Keyboard and Keyboard.KEY_EQUALS) or 0,
    (Keyboard and Keyboard.KEY_BACK) or 0,
    (Keyboard and Keyboard.KEY_TAB) or 0,
    (Keyboard and Keyboard.KEY_Q) or 0,
    (Keyboard and Keyboard.KEY_W) or 0,
    (Keyboard and Keyboard.KEY_E) or 0,
    (Keyboard and Keyboard.KEY_R) or 0,
    (Keyboard and Keyboard.KEY_T) or 0,
    (Keyboard and Keyboard.KEY_Y) or 0,
    (Keyboard and Keyboard.KEY_U) or 0,
    (Keyboard and Keyboard.KEY_I) or 0,
    (Keyboard and Keyboard.KEY_O) or 0,
    (Keyboard and Keyboard.KEY_P) or 0,
    (Keyboard and Keyboard.KEY_LBRACKET) or 0,
    (Keyboard and Keyboard.KEY_RBRACKET) or 0,
    (Keyboard and Keyboard.KEY_BACKSLASH) or 0,
    (Keyboard and Keyboard.KEY_CAPITAL) or 0,
    (Keyboard and Keyboard.KEY_A) or 0,
    (Keyboard and Keyboard.KEY_S) or 0,
    (Keyboard and Keyboard.KEY_D) or 0,
    (Keyboard and Keyboard.KEY_F) or 0,
    (Keyboard and Keyboard.KEY_G) or 0,
    (Keyboard and Keyboard.KEY_H) or 0,
    (Keyboard and Keyboard.KEY_J) or 0,
    (Keyboard and Keyboard.KEY_K) or 0,
    (Keyboard and Keyboard.KEY_L) or 0,
    (Keyboard and Keyboard.KEY_SEMICOLON) or 0,
    (Keyboard and Keyboard.KEY_APOSTROPHE) or 0,
    (Keyboard and Keyboard.KEY_RETURN) or 0,
    (Keyboard and Keyboard.KEY_LSHIFT) or 0,
    (Keyboard and Keyboard.KEY_Z) or 0,
    (Keyboard and Keyboard.KEY_X) or 0,
    (Keyboard and Keyboard.KEY_C) or 0,
    (Keyboard and Keyboard.KEY_V) or 0,
    (Keyboard and Keyboard.KEY_B) or 0,
    (Keyboard and Keyboard.KEY_N) or 0,
    (Keyboard and Keyboard.KEY_M) or 0,
    (Keyboard and Keyboard.KEY_COMMA) or 0,
    (Keyboard and Keyboard.KEY_PERIOD) or 0,
    (Keyboard and Keyboard.KEY_SLASH) or 0,
    (Keyboard and Keyboard.KEY_RSHIFT) or 0,
    (Keyboard and Keyboard.KEY_LCONTROL) or 0,
    (Keyboard and Keyboard.KEY_LWIN) or 0,
    (Keyboard and Keyboard.KEY_LMENU) or 0,
    (Keyboard and Keyboard.KEY_SPACE) or 0,
    (Keyboard and Keyboard.KEY_RMENU) or 0,
    (Keyboard and Keyboard.KEY_RWIN) or 0,
    (Keyboard and Keyboard.KEY_APPS) or 0,
    (Keyboard and Keyboard.KEY_RCONTROL) or 0,
    (Keyboard and Keyboard.KEY_INSERT) or 0,
    (Keyboard and Keyboard.KEY_HOME) or 0,
    (Keyboard and Keyboard.KEY_PRIOR) or 0,
    (Keyboard and Keyboard.KEY_DELETE) or 0,
    (Keyboard and Keyboard.KEY_END) or 0,
    (Keyboard and Keyboard.KEY_NEXT) or 0,
    (Keyboard and Keyboard.KEY_UP) or 0,
    (Keyboard and Keyboard.KEY_LEFT) or 0,
    (Keyboard and Keyboard.KEY_DOWN) or 0,
    (Keyboard and Keyboard.KEY_RIGHT) or 0,
    (Keyboard and Keyboard.KEY_NUMLOCK) or 0,
    (Keyboard and Keyboard.KEY_DIVIDE) or 0,
    (Keyboard and Keyboard.KEY_MULTIPLY) or 0,
    (Keyboard and Keyboard.KEY_SUBTRACT) or 0,
    (Keyboard and Keyboard.KEY_ADD) or 0,
    (Keyboard and Keyboard.KEY_DECIMAL) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD0) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD1) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD2) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD3) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD4) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD5) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD6) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD7) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD8) or 0,
    (Keyboard and Keyboard.KEY_NUMPAD9) or 0,
    (Keyboard and Keyboard.KEY_NUMPADENTER) or 0,
    (Keyboard and Keyboard.KEY_F13) or 0,
    (Keyboard and Keyboard.KEY_F14) or 0,
    (Keyboard and Keyboard.KEY_F15) or 0,
    (Keyboard and Keyboard.KEY_F16) or 0,
    (Keyboard and Keyboard.KEY_F17) or 0,
    (Keyboard and Keyboard.KEY_F18) or 0,
    (Keyboard and Keyboard.KEY_F19) or 0,
    (Keyboard and Keyboard.KEY_KANA) or 0,
    (Keyboard and Keyboard.KEY_CONVERT) or 0,
    (Keyboard and Keyboard.KEY_NOCONVERT) or 0,
    (Keyboard and Keyboard.KEY_YEN) or 0,
    (Keyboard and Keyboard.KEY_NUMPADEQUALS) or 0,
    (Keyboard and Keyboard.KEY_CIRCUMFLEX) or 0,
    (Keyboard and Keyboard.KEY_AT) or 0,
    (Keyboard and Keyboard.KEY_COLON) or 0,
    (Keyboard and Keyboard.KEY_UNDERLINE) or 0,
    (Keyboard and Keyboard.KEY_KANJI) or 0,
    (Keyboard and Keyboard.KEY_STOP) or 0,
    (Keyboard and Keyboard.KEY_AX) or 0,
    (Keyboard and Keyboard.KEY_UNLABELED) or 0,
    (Keyboard and Keyboard.KEY_SECTION) or 0,
    (Keyboard and Keyboard.KEY_NUMPADCOMMA) or 0,
    (Keyboard and Keyboard.KEY_FUNCTION) or 0,
    (Keyboard and Keyboard.KEY_CLEAR) or 0,
    (Keyboard and Keyboard.KEY_POWER) or 0,
    (Keyboard and Keyboard.KEY_SLEEP) or 0,
}

local function sandboxWheelKeyCode()
    local t = sandboxWheel()
    if t == nil then return nil end
    local index = tonumber(t.CompanionWheelKey)
    if index == nil then return nil end
    local code = SANDBOX_KEY_CODES[index]
    if type(code) ~= "number" then code = SANDBOX_KEY_CODES[1] or 0 end
    return code
end

local function isWheelKey(key)
    local ok = false
    pcall(function() ok = getCore():isKey(KEY_NAME, key) == true end)
    return ok
end

local function isMouseCode(code)
    if type(code) ~= "number" then return false end
    local offset = 10000
    if Mouse ~= nil and Mouse.BTN_OFFSET ~= nil then offset = Mouse.BTN_OFFSET end
    return code >= offset
end

local function mouseHeld(code)
    if Mouse == nil or type(code) ~= "number" then return false end
    local offset = Mouse.BTN_OFFSET or 10000
    local down = false
    pcall(function() down = Mouse.isButtonDown(code - offset) == true end)
    return down
end

local function mouseTick()
    if BridgeRadial.off or BridgeRadial.joypad or not state.mouseOpened then return end
    local menu = getPlayerRadialMenu(0)
    if menu == nil or not menu:isReallyVisible() then
        state.mouseOpened = false
        return
    end
    local code = nil
    pcall(function() code = getCore():getKey(KEY_NAME) end)
    if not isMouseCode(code) then
        state.mouseOpened = false
        return
    end
    local toggle = false
    pcall(function() toggle = getCore():getOptionRadialMenuKeyToggle() == true end)
    if toggle then return end
    if mouseHeld(code) then return end
    state.mouseOpened = false
    menu:removeFromUIManager()
    removeOverlays()
end

local function controllerHintTick()
    if BridgeRadial.controllerHintShown then return end
    if BridgeRadial.off or not sandboxControllerEnabled() then return end
    local player = getSpecificPlayer(0)
    if player == nil then return end
    local bind = -1
    pcall(function() bind = player:getJoypadBind() end)
    if bind == -1 then return end
    if player:getVehicle() ~= nil then return end
    if not controllerWheelReady(0) then return end
    local mouseRecent = false
    pcall(function() mouseRecent = wasMouseActiveMoreRecentlyThanJoypad() == true end)
    if mouseRecent then return end
    local label = controllerButtonLabel(configuredControllerButton())
    local suffix = "companion wheel"
    if type(getTextOrNull) == "function" then
        local got = getTextOrNull("IGUI_StayWithMe_ControllerWheelHint")
        if type(got) == "string" and got ~= "" and got ~= "IGUI_StayWithMe_ControllerWheelHint" then suffix = got end
    end
    local text = label .. ": " .. suffix
    local ok = false
    pcall(function()
        player:setHaloNote(text, 220, 220, 220, 350)
        ok = true
    end)
    if ok then BridgeRadial.controllerHintShown = true end
end

local function controllerWheelTick()
    if BridgeRadial.off then return end
    local joypad = nil
    pcall(function() joypad = getJoypadData(0) end)
    if joypad == nil then return end
    local def = configuredControllerButton()
    local held = controllerButtonDown(def, joypad.id)
    if held ~= state.wheelButtonHeld then
        state.wheelButtonHeld = held
        dbg("controller " .. (held and "DOWN" or "UP")
            .. " id=" .. tostring(def and def.id)
            .. " joypadId=" .. tostring(joypad.id)
            .. " focus=" .. tostring(joypad.focus))
        if held then controllerDebugConfig("press") end
    end
    local focus = joypad.focus
    if focus ~= nil and (MainScreen == nil or focus ~= MainScreen.instance) then return end
    if held then
        if state.wheelButtonDownMS == nil then state.wheelButtonDownMS = getTimestampMs() end
    elseif state.wheelButtonDownMS ~= nil then
        state.wheelButtonDownMS = nil
        state.wheelButtonOpened = nil
        state.wheelButtonLogged = nil
    end
    local down = state.wheelButtonDownMS
    if down == nil or state.wheelButtonOpened == true then return end
    if getTimestampMs() - down < 250 then return end
    if state.wheelButtonLogged ~= true then
        state.wheelButtonLogged = true
        dbg("hold reached enabled=" .. tostring(sandboxControllerEnabled())
            .. " present=" .. tostring(BridgeMenu ~= nil and BridgeMenu.isPresent())
            .. " talk=" .. tostring(BridgeMenu ~= nil and BridgeMenu.inTalkRange())
            .. " available=" .. tostring(controllerWheelAvailable(0))
            .. " ready=" .. tostring(controllerWheelReady(0))
            .. " store=" .. tostring(Bridge ~= nil and Bridge.store ~= nil))
    end
    if openControllerWheel(0) then
        state.wheelButtonOpened = true
        dbg("controller wheel opened")
        log("controller wheel opened")
    end
end

local function controllerSelectTick()
    if BridgeRadial.off or not BridgeRadial.joypad then return end
    local menu = BridgeRadial.activeMenu
    if menu == nil or not menu:isReallyVisible() then
        BridgeRadial.selectHeld = nil
        return
    end
    local joypad = nil
    pcall(function() joypad = getJoypadData(0) end)
    if joypad == nil then return end
    local def = configuredSelectButton()
    local held = selectButtonDown(def, joypad.id)
    if held and not BridgeRadial.selectHeld then
        BridgeRadial.selectHeld = true
        local index = BridgeRadial.selectedSliceIndex(menu, joypad)
        local command = menu:getSliceCommand(index)
        menu:undisplay()
        if command and command[1] then
            command[1](command[2], command[3], command[4], command[5], command[6], command[7])
        end
        dbg("select button=" .. tostring(def and def.id) .. " index=" .. tostring(index))
    elseif not held then
        BridgeRadial.selectHeld = nil
    end
end

local TICK_MS = 250

local function wheelTick()
    controllerWheelTick()
    controllerSelectTick()
    local now = getTimestampMs()
    if state.lastWheelTick ~= nil and now - state.lastWheelTick < TICK_MS then return end
    state.lastWheelTick = now
    if not state.sandboxApplied then
        state.sandboxApplied = BridgeRadial.applySandboxKey() == true
    end
    if BridgeRadial.activeMenu ~= nil then
        local menu = BridgeRadial.activeMenu
        if menu == nil or not menu:isReallyVisible() then removeOverlays() end
    elseif BridgeRadial.avatar ~= nil then
        local playerNum = BridgeRadial.avatarPlayer or 0
        local menu = getPlayerRadialMenu(playerNum)
        if menu == nil or not menu:isReallyVisible() then removeAvatar() end
    end
    mouseTick()
    controllerHintTick()
end

function BridgeRadial.onKeyPressed(key)
    if BridgeRadial.off or not isWheelKey(key) then return end
    local menu = getPlayerRadialMenu(0)
    if menu == nil then return end
    local toggle = false
    pcall(function() toggle = getCore():getOptionRadialMenuKeyToggle() == true end)
    if toggle and menu:isReallyVisible() then
        state.radialWasVisible = true
        state.mouseOpened = false
        menu:removeFromUIManager()
        removeOverlays()
        return
    end
    state.keyPressedMS = getTimestampMs()
    state.radialWasVisible = false
end

function BridgeRadial.onKeyRepeat(key)
    if BridgeRadial.off or not isWheelKey(key) then return end
    if state.radialWasVisible or state.keyPressedMS == nil then return end
    local menu = getPlayerRadialMenu(0)
    if menu == nil or menu:isReallyVisible() then return end
    if getTimestampMs() - state.keyPressedMS < HOLD_MS then return end
    state.mouseOpened = isMouseCode(key)
    local ok, err = pcall(BridgeRadial.open, 0)
    if not ok then
        BridgeRadial.off = true
        warn("wheel disabled for this session: " .. tostring(err))
    end
end

function BridgeRadial.onKeyReleased(key)
    if not isWheelKey(key) then return end
    if isMouseCode(key) then return end
    if state.keyPressedMS == nil then return end
    local menu = getPlayerRadialMenu(0)
    if menu == nil then return end
    local toggle = false
    pcall(function() toggle = getCore():getOptionRadialMenuKeyToggle() == true end)
    if menu:isReallyVisible() or state.radialWasVisible then
        if not toggle then
            menu:removeFromUIManager()
            removeOverlays()
        end
        return
    end
end

function BridgeRadial.installKeybind()
    if BridgeRadial.keybindDone then return end
    if type(keyBinding) ~= "table" then return end
    for _, bind in ipairs(keyBinding) do
        if type(bind) == "table" and bind.value == KEY_NAME then
            if Keyboard ~= nil and Mouse ~= nil and Mouse.BTN_3 ~= nil and bind.key == Keyboard.KEY_K then
                bind.key = Mouse.BTN_3
            end
            BridgeRadial.keybindDone = true
            return
        end
    end
    local key = nil
    if Mouse ~= nil and Mouse.BTN_3 ~= nil then key = Mouse.BTN_3 end
    if key == nil and Keyboard ~= nil then key = Keyboard.KEY_F8 end
    if key == nil then return end
    table.insert(keyBinding, { value = KEY_SECTION })
    table.insert(keyBinding, { value = KEY_NAME, key = key })
    BridgeRadial.keybindDone = true
    log("keybind registered")
end

function BridgeRadial.applySandboxKey()
    if type(keyBinding) ~= "table" then return false end
    local code = sandboxWheelKeyCode()
    if code == nil then return false end
    for _, bind in ipairs(keyBinding) do
        if type(bind) == "table" and bind.value == KEY_NAME then
            bind.key = code
            pcall(function() getCore():addKeyBinding(KEY_NAME, code, 0, false, false, false) end)
            break
        end
    end
    if MainOptions ~= nil and type(MainOptions.keys) == "table" then
        for _, bind in ipairs(MainOptions.keys) do
            if type(bind) == "table" and bind.value == KEY_NAME then bind.key = code end
        end
    end
    return true
end

local function hookEvents()
    if BridgeRadial.hooked then return end
    BridgeRadial.hooked = true
    BridgeRadial.installKeybind()
    if Events == nil then return end
    if Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function()
            BridgeRadial.installKeybind()
            state.sandboxApplied = BridgeRadial.applySandboxKey() == true
            BridgeRadial.joypad = false
            BridgeRadial.off = false
            BridgeRadial.controllerHintShown = false
            state.wheelButtonDownMS = nil
            state.wheelButtonOpened = nil
            state.wheelButtonHeld = nil
            state.wheelButtonLogged = nil
            controllerDebugConfig("gamestart")
        end)
    end
    if Events.OnKeyStartPressed ~= nil then Events.OnKeyStartPressed.Add(BridgeRadial.onKeyPressed) end
    if Events.OnKeyKeepPressed ~= nil then Events.OnKeyKeepPressed.Add(BridgeRadial.onKeyRepeat) end
    if Events.OnKeyPressed ~= nil then Events.OnKeyPressed.Add(BridgeRadial.onKeyReleased) end
    if Events.OnTick ~= nil then Events.OnTick.Add(function() pcall(wheelTick) end) end
end

BridgeRadial.installKeybind()
hookEvents()

local function wrapDPadWheel(name, direction)
    if ISDPadWheels == nil or type(ISDPadWheels[name]) ~= "function" then
        dbg("wrap skipped " .. tostring(name)
            .. " isDPadWheels=" .. tostring(ISDPadWheels ~= nil)
            .. " fn=" .. tostring(ISDPadWheels ~= nil and type(ISDPadWheels[name])))
        return
    end
    if BridgeRadial.dpadWrapped == nil then BridgeRadial.dpadWrapped = {} end
    if BridgeRadial.dpadWrapped[name] then return end
    BridgeRadial.dpadWrapped[name] = true
    local vanilla = ISDPadWheels[name]
    ISDPadWheels[name] = function(joypadData)
        if BridgeRadial.joypad and BridgeRadial.activeMenu ~= nil
                and BridgeRadial.activeMenu:isReallyVisible() then
            BridgeRadial.cycleSelection(direction)
            return
        end
        local def, index = configuredControllerButton()
        dbg("dpad " .. tostring(direction)
            .. " called player=" .. tostring(joypadData and joypadData.player)
            .. " index=" .. tostring(index)
            .. " id=" .. tostring(def and def.id))
        if joypadData ~= nil then
            if def ~= nil and def.dpad == direction then
                local playerNum = joypadData.player or 0
                local available = controllerWheelAvailable(playerNum)
                local opened = available and openControllerWheel(playerNum)
                dbg("dpad " .. tostring(direction)
                    .. " matched available=" .. tostring(available)
                    .. " opened=" .. tostring(opened))
                if opened then return end
            end
        end
        return vanilla(joypadData)
    end
    dbg("wrapped " .. tostring(name))
end

dbg("load isDPadWheels=" .. tostring(ISDPadWheels ~= nil)
    .. " isJoystickRadial=" .. tostring(ISJoystickButtonRadialMenu ~= nil))

wrapDPadWheel("onDisplayLeft", "left")
wrapDPadWheel("onDisplayRight", "right")
wrapDPadWheel("onDisplayUp", "up")
wrapDPadWheel("onDisplayDown", "down")

if BridgeRadial.lstickWrapped ~= true and ISJoystickButtonRadialMenu ~= nil
        and type(ISJoystickButtonRadialMenu.onRepeatLeftStickButton) == "function" then
    BridgeRadial.lstickWrapped = true
    local vanillaRepeat = ISJoystickButtonRadialMenu.onRepeatLeftStickButton
    ISJoystickButtonRadialMenu.onRepeatLeftStickButton = function(joypadData)
        local def, index = configuredControllerButton()
        if state.lastL3Log == nil or getTimestampMs() - state.lastL3Log >= 1000 then
            state.lastL3Log = getTimestampMs()
            dbg("l3 repeat player=" .. tostring(joypadData and joypadData.player)
                .. " index=" .. tostring(index)
                .. " id=" .. tostring(def and def.id))
        end
        if joypadData ~= nil then
            if def ~= nil and def.id == "lstick" then
                local playerNum = joypadData.player or 0
                local ready = controllerWheelReady(playerNum)
                dbg("l3 suppress=" .. tostring(ready))
                if ready then return end
            end
        end
        return vanillaRepeat(joypadData)
    end
end

if BridgeRadial.firearmRadialWrapped ~= true and ISFirearmRadialMenu ~= nil
        and type(ISFirearmRadialMenu.onRepeatRBumper) == "function" then
    BridgeRadial.firearmRadialWrapped = true
    local vanillaRBFirearm = ISFirearmRadialMenu.onRepeatRBumper
    ISFirearmRadialMenu.onRepeatRBumper = function(...)
        if BridgeRadial.joypad and BridgeRadial.activeMenu ~= nil
                and BridgeRadial.activeMenu:isReallyVisible() then
            local def = configuredSelectButton()
            if def ~= nil and def.joypads ~= nil then
                for _, name in ipairs(def.joypads) do
                    if name == "RBumper" then return end
                end
            end
        end
        return vanillaRBFirearm(...)
    end
end

if BridgeRadial.undisplayWrapped ~= true and ISRadialMenu ~= nil
        and type(ISRadialMenu.undisplay) == "function" then
    BridgeRadial.undisplayWrapped = true
    local vanillaUndisplay = ISRadialMenu.undisplay
    ISRadialMenu.undisplay = function(self, ...)
        vanillaUndisplay(self, ...)
        if BridgeRadial.activeMenu ~= nil and self == BridgeRadial.activeMenu then
            removeOverlays()
        end
    end
end

log("loaded")
