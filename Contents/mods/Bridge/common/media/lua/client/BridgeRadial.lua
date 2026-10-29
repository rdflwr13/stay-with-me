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

local state = {}

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
        { flag = "DEPOSIT_ENABLED", kind = "depositArea", key = "JobDepositArea", handler = BridgeMenu.onJobDepositArea, icon = ICONS.loot },
        { flag = "DEPOSIT_ENABLED", kind = "deposit", key = "DepositLootHome", handler = BridgeMenu.onDepositHome, icon = ICONS.work,
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

function BridgeRadialTip:render()
    local menu = BridgeRadial.activeMenu
    if menu == nil or menu.javaObject == nil or not menu:isReallyVisible() then return end
    local tips = menu.bridgeTips
    if tips == nil then return end
    local index = -1
    if menu.joyfocus ~= nil and menu.joyfocus.id ~= nil then
        index = menu.javaObject:getSliceIndexFromJoypad(menu.joyfocus.id)
    else
        index = menu.javaObject:getSliceIndexFromMouse(menu:getMouseX(), menu:getMouseY())
    end
    if type(index) ~= "number" or index < 0 then return end
    local text = tips[index + 1]
    if type(text) ~= "string" or text == "" then return end
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

local function removeTip()
    local panel = BridgeRadial.tip
    BridgeRadial.tip = nil
    if panel ~= nil then pcall(function() panel:removeFromUIManager() end) end
end

local function removeOverlays()
    BridgeRadial.activeMenu = nil
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

local function present(menu, playerNum)
    menu:center()
    menu:addToUIManager()
    BridgeRadial.activeMenu = menu
    if BridgeRadial.joypad and JoypadState ~= nil and JoypadState.players ~= nil and JoypadState.players[playerNum + 1] then
        menu:setHideWhenButtonReleased(Joypad.LStickButton)
        setJoypadFocus(playerNum, menu)
    end
    showAvatar(playerNum)
    pcall(function() menu:bringToTop() end)
    showTipPanel()
end

local function fillTop(playerNum)
    local menu = getPlayerRadialMenu(playerNum)
    if menu == nil then return end
    menu:clear()
    menu.bridgeTips = {}
    local list = BridgeRadial.topEntries(playerNum)
    if #list == 0 then return end
    addSlices(menu, list)
    present(menu, playerNum)
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

function BridgeRadial.appendController(joypadData)
    if BridgeRadial.off or joypadData == nil then return end
    local playerNum = joypadData.player
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil or playerObj:getVehicle() ~= nil then return end
    if Bridge == nil or Bridge.store == nil then return end
    if not sandboxControllerEnabled() then return end
    if not BridgeMenu.isPresent() or not BridgeMenu.inTalkRange() then return end
    local menu = getPlayerRadialMenu(playerNum)
    if menu == nil or not menu:isReallyVisible() then return end
    BridgeRadial.joypad = true
    state.mouseOpened = false
    menu.bridgeTips = {}
    addSlices(menu, BridgeRadial.topEntries(playerNum), true)
    BridgeRadial.activeMenu = menu
    showAvatar(playerNum)
    pcall(function() menu:bringToTop() end)
    showTipPanel()
    log("controller wheel appended")
end

local function sandboxWheel()
    local t = nil
    pcall(function() t = (SandboxVars ~= nil) and SandboxVars.StayWithMe or nil end)
    return t
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

local function sandboxControllerEnabled()
    local t = sandboxWheel()
    if t == nil or t.CompanionWheelController == nil then return true end
    return t.CompanionWheelController == true
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

local TICK_MS = 250

local function wheelTick()
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
        end)
    end
    if Events.OnKeyStartPressed ~= nil then Events.OnKeyStartPressed.Add(BridgeRadial.onKeyPressed) end
    if Events.OnKeyKeepPressed ~= nil then Events.OnKeyKeepPressed.Add(BridgeRadial.onKeyRepeat) end
    if Events.OnKeyPressed ~= nil then Events.OnKeyPressed.Add(BridgeRadial.onKeyReleased) end
    if Events.OnTick ~= nil then Events.OnTick.Add(function() pcall(wheelTick) end) end
end

BridgeRadial.installKeybind()
hookEvents()

if BridgeRadial.controllerWrapped ~= true and ISJoystickButtonRadialMenu ~= nil
        and type(ISJoystickButtonRadialMenu.displayLeft) == "function" then
    BridgeRadial.controllerWrapped = true
    local vanilla = ISJoystickButtonRadialMenu.displayLeft
    ISJoystickButtonRadialMenu.displayLeft = function(joypadData, ...)
        vanilla(joypadData, ...)
        if BridgeRadial.off then return end
        local ok, err = pcall(BridgeRadial.appendController, joypadData)
        if not ok then
            BridgeRadial.off = true
            print("[BridgeRadial] wheel disabled for this session: " .. tostring(err))
        end
    end
    log("controller radial wrapped")
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
