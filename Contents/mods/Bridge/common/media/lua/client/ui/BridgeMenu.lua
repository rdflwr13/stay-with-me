








BridgeMenu = BridgeMenu or {}

local UI_BORDER_SPACING = 10

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeMenu] " .. tostring(text)) end end
local function warn(text) print("[BridgeMenu] " .. tostring(text)) end

local function tr(key, a)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key, a) end
    local text = key
    pcall(function()
        if a ~= nil then text = getText("IGUI_NotAlone_" .. key, a) else text = getText("IGUI_NotAlone_" .. key) end
    end)
    return text
end


local function tip(option, text)
    pcall(function()
        local t = ISInventoryPaneContextMenu.addToolTip()
        t.description = text
        option.toolTip = t
    end)
end

local MISSING_KEY = {
    axe = "Need_Axe",
    implement = "Need_CleanImplement",
    cleaner = "Need_Cleaner",
    both = "Need_CleanSupplies",
    cut = "Need_Cut",
    crowbar = "Need_Crowbar",
}


local function jobTip(option, kind)
    local missing = nil
    pcall(function()
        local def = BridgeTask ~= nil and BridgeTask.kinds[kind] or nil
        if def ~= nil and def.missing ~= nil then missing = def.missing(Bridge.body) end
    end)
    local key = missing ~= nil and MISSING_KEY[missing] or nil
    if key ~= nil then tip(option, tr(key)) end
end

local function name() return Bridge.companionName() end



BridgeMenu.TALK_RANGE = 12

BridgeMenu.SHOW_STATUS = false

BridgeMenu.NEW_SEEN_PREFIX = "bridge/companion_new_"
BridgeMenu.newHintSeen = nil
BridgeMenu.newHintKey = nil


local function hintWorldKey()
    local key = nil
    pcall(function()
        local w = getWorld()
        key = tostring(w:getGameMode()) .. "_" .. tostring(w:getWorld())
    end)
    if key == nil then return nil end
    return (string.gsub(key, "[^%w%-_]", "_"))
end


local function hintFile(key)
    return BridgeMenu.NEW_SEEN_PREFIX .. key .. ".txt"
end


function BridgeMenu.resetNewHintCache()
    BridgeMenu.newHintSeen = nil
    BridgeMenu.newHintKey = nil
end


function BridgeMenu.newHintOn()
    if BridgeData ~= nil and type(BridgeData.wants) == "function" then
        local store = nil
        if Bridge ~= nil then store = Bridge.store end
        if BridgeData.wants(store) == false then return false end
    end
    if BridgeMenu.newHintSeen == false then return true end
    if BridgeMenu.newHintSeen == true then return false end
    local key = hintWorldKey()
    if key == nil then return true end
    if BridgeMenu.newHintKey ~= key then
        BridgeMenu.newHintKey = key
        BridgeMenu.newHintSeen = false
        local seen = false
        pcall(function()
            local reader = getFileReader(hintFile(key), false)
            if reader == nil then return end
            local line = reader:readLine()
            if line ~= nil then seen = true end
            reader:close()
        end)
        if seen then BridgeMenu.newHintSeen = true end
    end
    return BridgeMenu.newHintSeen ~= true
end


function BridgeMenu.dismissNewHint()
    if not BridgeMenu.newHintOn() then return end
    BridgeMenu.newHintSeen = true
    local key = BridgeMenu.newHintKey or hintWorldKey()
    if key == nil then return end
    local ok = pcall(function()
        local writer = getFileWriter(hintFile(key), true, false)
        writer:write("seen\n")
        writer:close()
    end)
    if ok then log("new hint dismissed for " .. tostring(key)) end
end


local function present()
    if Bridge.alive() then return true end

    if Bridge.mp and Bridge.store ~= nil and Bridge.store.bodyId ~= nil then
        for _, info in pairs(Bridge.bodiesSeen()) do
            if info.who == BridgeData.me() then return true end
        end
    end
    return false
end

function BridgeMenu.isPresent() return present() end



function BridgeMenu.inCarWithRed()
    return BridgeCar ~= nil and BridgeCar.withRed(BridgeData.owner())
end



function BridgeMenu.lit()
    return (present() and BridgeMenu.inTalkRange()) or BridgeMenu.inCarWithRed()
end



function BridgeMenu.inTalkRange()
    local red = BridgeData.owner()
    if red == nil then return false end
    local function close(z)
        local yes = false
        pcall(function()
            local dx, dy = z:getX() - red:getX(), z:getY() - red:getY()
            yes = dx * dx + dy * dy <= BridgeMenu.TALK_RANGE * BridgeMenu.TALK_RANGE
                and math.abs(z:getZ() - red:getZ()) < 1.5
        end)
        return yes
    end
    if Bridge.alive() then return close(Bridge.body) end
    for z, info in pairs(Bridge.bodiesSeen()) do
        if info.who == BridgeData.me() and close(z) then return true end
    end
    return false
end


local function cursorSquare(playerNum)
    local sq = nil
    pcall(function()
        local pn = playerNum or 0
        local z = 0
        local red = (BridgeData ~= nil and BridgeData.owner ~= nil) and BridgeData.owner() or nil
        if red ~= nil then z = math.floor(red:getZ() + 0.01) end
        local mx, my = getMouseX(), getMouseY()
        local x = math.floor(screenToIsoX(pn, mx, my, z))
        local y = math.floor(screenToIsoY(pn, mx, my, z))
        sq = getCell():getGridSquare(x, y, z)
    end)
    return sq
end

local function clickedSquare(worldobjects, playerNum)
    local sq = cursorSquare(playerNum)
    if sq ~= nil then return sq end
    for _, o in ipairs(worldobjects or {}) do
        local s = nil
        pcall(function() s = o:getSquare() end)
        if s ~= nil then return s end
    end
    return nil
end

local function emptySpaceUnder(worldobjects, playerNum)
    local sq = clickedSquare(worldobjects, playerNum)
    if sq == nil then return false end
    local clear = true
    pcall(function()
        local floor = nil
        pcall(function() floor = sq:getFloor() end)
        local objects = sq:getObjects()
        if objects ~= nil then
            for i = 0, objects:size() - 1 do
                local o = objects:get(i)
                if o ~= nil and o ~= floor then
                    local isFloor = false
                    pcall(function() isFloor = o:hasProperty(IsoFlagType.solidfloor) == true end)
                    if not isFloor then
                        local live = true
                        pcall(function() live = o:getObjectIndex() >= 0 end)
                        if live then clear = false break end
                    end
                end
            end
        end
        if clear then
            local wobs = nil
            pcall(function() wobs = sq:getWorldObjects() end)
            if wobs ~= nil and wobs:size() > 0 then clear = false end
        end
    end)
    return clear
end



function BridgeMenu.statusParts(short)
    local st = Bridge.store
    local mode = BridgeData.modeOf(st)
    local function line(key)
        if short then return tr(key .. "Short") end
        return tr(key, name())
    end
    local tag = ""
    pcall(function() tag = BridgeSocial.label() end)
    if tag == nil then tag = "" end
    local function withTag(text)
        if tag ~= "" then return text, tag end
        return text, ""
    end
    if BridgeCar ~= nil and BridgeCar.inCarForMenu() then
        if BridgeMenu.inCarWithRed() then return withTag(line("StatusInCar")) end
        return line("StatusInCar"), ""
    end
    if present() then
        local key = "StatusHere"
        if mode == "rest" then key = "StatusResting"
        elseif mode == "wait" then key = "StatusWaiting" end
        return withTag(line(key))
    end
    if BridgeData.wants(st) and mode ~= "follow" and st ~= nil and st.waitX ~= nil then
        return line("StatusWaiting"), ""
    end
    return line("StatusAway"), ""
end

function BridgeMenu.status(short)
    local left = BridgeMenu.statusParts(short)
    return left
end



function BridgeMenu.onCall()
    if not present() then Bridge.greetOnReveal = true end
    Bridge.call()
end

function BridgeMenu.onFollow()
    Bridge.setMode("follow")
    Bridge.speak("Follow")
end

function BridgeMenu.onWait()
    Bridge.setMode("wait")
    Bridge.speak("Wait")
end

function BridgeMenu.onRest()
    Bridge.setMode("rest")
    Bridge.speak("Rest")
end

function BridgeMenu.onHeal()
    local res = BridgeHeal.request()
    log("heal from menu: " .. tostring(res))
end

function BridgeMenu.onEquip(playerNum)
    if BridgeEquip ~= nil and type(BridgeEquip.toggle) == "function" then BridgeEquip.toggle(playerNum) end
end

function BridgeMenu.onWash()
    BridgeWash.start("menu")
end

function BridgeMenu.onExercise()
    if BridgeExercise == nil or type(BridgeExercise.start) ~= "function" then return end
    local function go()
        local res = BridgeExercise.start(false)
        log("exercise from menu: " .. tostring(res))
    end
    local rec = Bridge.store
    if BridgeExercise.showNotice ~= nil and not BridgeExercise.noticeShown
        and (rec == nil or rec.exerciseTold ~= true) then
        BridgeExercise.showNotice(go)
    else
        go()
    end
end

function BridgeMenu.onGoodbye()
    Bridge.goodbye()
end


function BridgeMenu.onKeepSide(side)
    Bridge.setKeep(side)
    if present() then Bridge.speak("Keep_" .. tostring(side)) end
end


function BridgeMenu.onKeepDistance(which)
    local far = which == "far"
    Bridge.setFar(far)
    if present() then Bridge.speak(far and "KeepFarther" or "KeepCloser") end
end


function BridgeMenu.onCombat(mode)
    Bridge.setCombat(mode)
    if present() then Bridge.speak("Combat_" .. tostring(mode)) end
end




function BridgeMenu.onTorch(mode)
    if Bridge ~= nil and type(Bridge.setTorchMode) == "function" then Bridge.setTorchMode(mode) end
end


function BridgeMenu.onGunUse(mode)
    if Bridge ~= nil and type(Bridge.setGunUse) == "function" then Bridge.setGunUse(mode) end
end


function BridgeMenu.onAmmoReserve(mode)
    if Bridge ~= nil and type(Bridge.setAmmoReserve) == "function" then Bridge.setAmmoReserve(mode) end
end


function BridgeMenu.onGunMelee(on)
    if Bridge ~= nil and type(Bridge.setOption) == "function" then Bridge.setOption("gunMelee", on == true) end
end


function BridgeMenu.onGunReloadIdle(on)
    if Bridge ~= nil and type(Bridge.setOption) == "function" then Bridge.setOption("gunReloadIdle", on == true) end
    if BridgeGunfight ~= nil and type(BridgeGunfight.clearManualEjectHold) == "function" then
        BridgeGunfight.clearManualEjectHold()
    end
end


function BridgeMenu.onGunMagCare(on)
    if Bridge ~= nil and type(Bridge.setOption) == "function" then Bridge.setOption("gunMagCare", on == true) end
    if BridgeGunfight ~= nil and type(BridgeGunfight.clearManualEjectHold) == "function" then
        BridgeGunfight.clearManualEjectHold()
    end
end

function BridgeMenu.onRenameDone(target, button, playerNum)
    if button == nil or button.internal ~= "OK" then return end
    local text = nil
    pcall(function() text = button.parent.entry:getText() end)
    Bridge.setName(text)
    if present() then Bridge.speak("Renamed", name()) end
end

function BridgeMenu.onRename(playerNum)
    local modal = ISTextBox:new(0, 0, 280, 180, tr("NamePrompt"), name(), nil, BridgeMenu.onRenameDone, playerNum or 0)
    modal:initialise()
    modal:addToUIManager()
    pcall(function() modal.entry:setMaxTextLength(BridgeData.NAME_MAX) end)
end





local function actionsMenu(context)
    local option = context:addOption(tr("Actions"))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    return sub
end


local function buildTalk(context, playerNum, env)
    if env.inRange then pcall(function() BridgeSocial.fillMenu(context, tr) end) end
end

local function buildHeal(context, playerNum, env)
    if not env.inRange then return end
    local heal = context:addOption(tr("HealMe"), nil, BridgeMenu.onHeal)
    if not Bridge.drivable() or not Bridge.alive() then
        heal.notAvailable = true
    elseif BridgeHeal.active then
        heal.notAvailable = true
    end
end

local function buildEquip(context, playerNum, env)
    if env.inRange then
        local equipOption = context:addOption(tr("WindowEquip"), playerNum, BridgeMenu.onEquip)
        if BridgeEquip ~= nil and type(BridgeEquip.withinRange) == "function" and not BridgeEquip.withinRange(playerNum) then
            equipOption.notAvailable = true
            tip(equipOption, tr("EquipTooFar"))
        end
    elseif BridgeEquip ~= nil and BridgeEquip.DEV then
        context:addOption(tr("WindowEquip") .. " (dev)", playerNum, BridgeMenu.onEquip)
    end
end

local function buildWait(context, playerNum, env)
    if env.mode == "follow" then
        context:addOption(tr("WaitHere"), nil, BridgeMenu.onWait)
    else
        context:addOption(tr("ComeWithMe"), nil, BridgeMenu.onFollow)
    end
end

local function buildActions(context, playerNum, env)
    local actions = actionsMenu(context)
    if env.mode == "rest" then
        actions:addOption(tr("WaitHere"), nil, BridgeMenu.onWait)
    elseif env.inRange then
        actions:addOption(tr("Rest"), nil, BridgeMenu.onRest)
    end
    local canExercise = false
    pcall(function() canExercise = BridgeTask ~= nil and BridgeTask.kinds.exercise.available(Bridge.body) end)
    local exBusy = false
    pcall(function() exBusy = BridgeExercise ~= nil and BridgeExercise.hardBusy ~= nil and BridgeExercise.hardBusy() end)
    local exercise = actions:addOption(tr("Exercise"), nil, BridgeMenu.onExercise)
    if not canExercise or exBusy or (BridgeTask ~= nil and BridgeTask.active) then
        exercise.notAvailable = true
    end
    local exCool = 0
    pcall(function() exCool = (BridgeExercise ~= nil and BridgeExercise.cooldownLeft(nil)) or 0 end)
    if (tonumber(exCool) or 0) > 0 then
        local hours = string.format("%.0f", tonumber(exCool) or 0)
        local coolText = tr("ExReadyIn", hours)
        if type(coolText) ~= "string" or coolText == "" or string.find(coolText, "ExReadyIn", 1, true) ~= nil then
            coolText = string.format("Ready to train again in %sh", hours)
        end
        tip(exercise, coolText)
    end
    actions:addOption(tr("Goodbye"), nil, BridgeMenu.onGoodbye)
end

local function buildGun(context, env)
    local parent = context:addOption(tr("GunMenu"))
    local gun = ISContextMenu:getNew(context)
    context:addSubMenu(parent, gun)

    local function addMenu(key, entries)
        local opt = gun:addOption(tr(key))
        local sub = ISContextMenu:getNew(gun)
        gun:addSubMenu(opt, sub)
        for _, entry in ipairs(entries) do
            local value = entry[1]
            local handler = entry[3]
            local o = sub:addOption(tr(entry[2]), nil, function() handler(value) end)
            if entry[4] then o.isDisabled = true end
            tip(o, tr(entry[5]))
        end
    end

    local use = BridgeData.gunUseOf(env.st)
    addMenu("GunUse", {
        { "always", "GunUseAlways", BridgeMenu.onGunUse, use == "always", "GunUseAlwaysTip" },
        { "off", "GunUseOff", BridgeMenu.onGunUse, use == "off", "GunUseOffTip" },
    })

    local melee = BridgeData.optionOf(env.st, "gunMelee")
    addMenu("GunMelee", {
        { true, "GunOn", BridgeMenu.onGunMelee, melee == true, "GunMeleeOnTip" },
        { false, "GunOff", BridgeMenu.onGunMelee, melee == false, "GunMeleeOffTip" },
    })

    local idle = BridgeData.optionOf(env.st, "gunReloadIdle")
    addMenu("GunReloadIdle", {
        { true, "GunOn", BridgeMenu.onGunReloadIdle, idle == true, "GunReloadIdleOnTip" },
        { false, "GunOff", BridgeMenu.onGunReloadIdle, idle == false, "GunReloadIdleOffTip" },
    })

    local care = BridgeData.optionOf(env.st, "gunMagCare")
    addMenu("GunMagCare", {
        { true, "GunOn", BridgeMenu.onGunMagCare, care == true, "GunMagCareOnTip" },
        { false, "GunOff", BridgeMenu.onGunMagCare, care == false, "GunMagCareOffTip" },
    })

    local reserve = BridgeData.ammoReserveOf(env.st)
    local reserveLabels = { free = "GunReserveFree", conserve = "GunReserveConserve", emergency = "GunReserveEmergency" }
    local reserveEntries = {}
    for _, mode in ipairs({ "free", "conserve", "emergency" }) do
        reserveEntries[#reserveEntries + 1] = { mode, reserveLabels[mode], BridgeMenu.onAmmoReserve,
            reserve == mode, "GunReserve" .. (mode == "free" and "Free" or mode == "conserve" and "Conserve" or "Emergency") .. "Tip" }
    end
    addMenu("GunAmmoReserve", reserveEntries)
end


local function addKeepMenu(parent, env)
    if not BridgeData.KEEP_ON then return end
    local keepOption = parent:addOption(tr("Keep"))
    local keep = ISContextMenu:getNew(parent)
    parent:addSubMenu(keepOption, keep)
    local far = BridgeData.farOf(env.st)
    local side = BridgeData.keepOf(env.st)
    local closer = keep:addOption(tr("KeepCloser"), "near", BridgeMenu.onKeepDistance)
    if not far then closer.isDisabled = true end
    local farther = keep:addOption(tr("KeepFarther"), "far", BridgeMenu.onKeepDistance)
    if far then farther.isDisabled = true end
    if BridgeData.KEEP_SIDES_ON then
        for _, entry in ipairs({ { "behind", "KeepBehind" }, { "left", "KeepLeft" }, { "right", "KeepRight" } }) do
            local o = keep:addOption(tr(entry[2]), entry[1], BridgeMenu.onKeepSide)
            if side == entry[1] then o.isDisabled = true end
        end
    end
end

local function buildFight(context, playerNum, env)
    local combatOption = context:addOption(tr("Combat"))
    local guard = false
    pcall(function() if BridgeFight ~= nil then guard = BridgeFight.guardOnly end end)
    if guard then
        combatOption.isDisabled = true
        tip(combatOption, tr("CombatGuardTip"))
    else
        local combat = ISContextMenu:getNew(context)
        context:addSubMenu(combatOption, combat)
        buildGun(combat, env)
        local combatMode = BridgeData.combatOf(env.st)
        for _, entry in ipairs({ { "bodyguard", "CombatBodyguard" }, { "escort", "CombatEscort" },
            { "aggressive", "CombatAggressive" }, { "backup", "CombatBackMeUp" }, { "stayback", "CombatStayBack" } }) do
            local o = combat:addOption(tr(entry[2]), entry[1], BridgeMenu.onCombat)
            if combatMode == entry[1] then o.isDisabled = true end
            tip(o, tr(entry[2] .. "Tip"))
        end
        addKeepMenu(combat, env)
    end
end

local function buildTorch(context, playerNum, env)
    local torchOption = context:addOption(tr("OptTorch"))
    local torch = ISContextMenu:getNew(context)
    context:addSubMenu(torchOption, torch)
    local torchMode = BridgeData.torchMode(env.st)
    for _, entry in ipairs({ { "off", "OptTorchOff" }, { "auto", "OptTorchAuto" } }) do
        local o = torch:addOption(tr(entry[2]), entry[1], BridgeMenu.onTorch)
        if torchMode == entry[1] then o.isDisabled = true end
    end
end

local function addLootWorkMenu(parent)
    local lootOption = parent:addOption(tr("WindowLoot"))
    local loot = ISContextMenu:getNew(parent)
    parent:addSubMenu(lootOption, loot)
    if BridgeTask.LOOTING_ENABLED == 1 then
        local okLoot = false
        pcall(function() okLoot = BridgeTask.kinds.lootArea.available(Bridge.body) end)
        local l = loot:addOption(tr("JobLootArea"), nil, BridgeMenu.onJobLootArea)
        if not okLoot then jobTip(l, "lootArea") end
        if not okLoot or BridgeTask.active then l.notAvailable = true end
    end
    if BridgeTask.DEPOSIT_ENABLED == 1 and BridgeDeposit ~= nil then
        local area = loot:addOption(tr("JobDepositArea"), nil, BridgeMenu.onJobDepositArea)
        if BridgeTask.active then area.notAvailable = true end
        local home = loot:addOption(tr("DepositLootHome"), nil, BridgeMenu.onDepositHome)
        local homeOk = false
        pcall(function() homeOk = BridgeDeposit.homeHere() == true end)
        local marksOk = false
        pcall(function() marksOk = BridgeDeposit.hasValidMarks() == true end)
        if not homeOk or not marksOk or BridgeTask.active then home.notAvailable = true end
        if homeOk and not marksOk then tip(home, tr("DepositNeedsMarks")) end
    end
    return loot
end

local function buildJobs(context, playerNum, env)
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 then return end
    local jobsOption = context:addOption(tr("Jobs"))
    local jobs = ISContextMenu:getNew(context)
    context:addSubMenu(jobsOption, jobs)
    addLootWorkMenu(jobs)
    if BridgeTask.DOORS_ENABLED == 1 then
        local doorsOption = jobs:addOption(tr("Doors"))
        local doors = ISContextMenu:getNew(jobs)
        jobs:addSubMenu(doorsOption, doors)
        local open = doors:addOption(tr("JobOpenDoors"), nil, BridgeMenu.onJobOpenDoors)
        local close = doors:addOption(tr("JobCloseDoors"), nil, BridgeMenu.onJobCloseDoors)
        if BridgeTask.active then open.notAvailable = true; close.notAvailable = true end
    end
    if BridgeTask.CLEANING_ENABLED == 1 then
        local okClean = false
        pcall(function() okClean = BridgeTask.kinds.cleanUp.available(Bridge.body) end)
        local clean = jobs:addOption(tr("JobCleanUp"), nil, BridgeMenu.onJobCleanUp)
        if not okClean then jobTip(clean, "cleanUp") end
        if not okClean or BridgeTask.active then clean.notAvailable = true end
    end
    if BridgeTask.CLEARING_ENABLED == 1 then
        local okClear = false
        pcall(function() okClear = BridgeTask.kinds.clearPlants.available(Bridge.body) end)
        local clear = jobs:addOption(tr("JobClearPlants"), nil, BridgeMenu.onJobClearPlants)
        jobTip(clear, "clearPlants")
        if not okClear or BridgeTask.active then clear.notAvailable = true end
    end
    if BridgeTask.TREECUTTING_ENABLED == 1 then
        local ok = false
        pcall(function() ok = BridgeTask.kinds.chopTree.available(Bridge.body) end)
        local cut = jobs:addOption(tr("JobChopTree"), nil, BridgeMenu.onJobChopTree)
        if not ok then jobTip(cut, "chopTree") end
        if not ok or BridgeTask.active then cut.notAvailable = true end
    end
    if BridgeTask.MOVE_CORPSES_ENABLED == 1 then
        local ok = false
        pcall(function() ok = BridgeTask.kinds.moveCorpses.available(Bridge.body) end)
        local move = jobs:addOption(tr("JobMoveCorpses"), nil, BridgeMenu.onJobMoveCorpses)
        if not ok then jobTip(move, "moveCorpses") end
        if not ok or BridgeTask.active then move.notAvailable = true end
    end
end

local function buildCancel(context, playerNum, env)
    BridgeMenu.addCancelTask(context)
end


local function onHomeSet()
    if BridgeHome ~= nil and type(BridgeHome.requestSet) == "function" then BridgeHome.requestSet(BridgeData.owner()) end
end

local function onHomeClear()
    if BridgeHome ~= nil and type(BridgeHome.confirmClear) == "function" then BridgeHome.confirmClear(BridgeData.owner()) end
end

local function buildHome(context, playerNum, env)
    if BridgeHome == nil then return end
    local homeOption = context:addOption(tr("Home"))
    local home = ISContextMenu:getNew(context)
    context:addSubMenu(homeOption, home)
    home:addOption(tr("HomeSetHome"), nil, onHomeSet)
    if BridgeData.homeOf(env.st) ~= nil then
        home:addOption(tr("HomeClear"), nil, onHomeClear)
    end
end


BridgeMenu.ORDERABLE = {
    { id = "talk", label = "Talk", build = buildTalk },
    { id = "heal", label = "HealMe", build = buildHeal },
    { id = "equip", label = "WindowEquip", build = buildEquip },
    { id = "wait", label = "MenuFollow", build = buildWait },
    { id = "actions", label = "Actions", build = buildActions },
    { id = "fight", label = "Combat", build = buildFight },
    { id = "guns", label = "GunMenu", radialOnly = true },
    { id = "torch", label = "OptTorch", build = buildTorch },
    { id = "jobs", label = "Jobs", build = buildJobs },
    { id = "cancel", label = "CancelTask", build = buildCancel },
}

BridgeMenu.ORDERABLE_BY_ID = {}
for _, entry in ipairs(BridgeMenu.ORDERABLE) do BridgeMenu.ORDERABLE_BY_ID[entry.id] = entry end


function BridgeMenu.fill(context, playerNum, fromIcon)
    if Bridge == nil or Bridge.store == nil then return end
    local st = Bridge.store
    local mode = BridgeData.modeOf(st)
    if fromIcon and BridgeMenu.SHOW_STATUS then
        local status = context:addOption(BridgeMenu.status(true))
        status.isDisabled = true
    end

    if BridgeCar ~= nil and BridgeCar.inCarForMenu() then
        if not fromIcon and BridgeMenu.SHOW_STATUS then
            local status = context:addOption(BridgeMenu.status(false))
            status.isDisabled = true
        end
        if BridgeMenu.inCarWithRed() then
            pcall(function() BridgeSocial.fillMenu(context, tr) end)
            if BridgeCar.isInside() then
                local heal = context:addOption(tr("HealMe"), nil, BridgeMenu.onHeal)
                local dead = false
                pcall(function()
                    local red = BridgeData.owner()
                    dead = red ~= nil and red:isDead() == true
                end)
                if BridgeHeal == nil or BridgeHeal.active or dead then heal.notAvailable = true end
            end
        end
        return
    end
    if not present() then
        context:addOption(fromIcon and tr("CallShort") or tr("Call", name()), nil, BridgeMenu.onCall)
        return
    end
    local inRange = BridgeMenu.inTalkRange()
    local env = { st = st, mode = mode, inRange = inRange, fromIcon = fromIcon }
    local order = BridgeData.menuOrder(st)
    for _, id in ipairs(order) do
        local entry = BridgeMenu.ORDERABLE_BY_ID[id]
        if entry ~= nil and entry.radialOnly ~= true and BridgeData.menuShown(st, id) then
            entry.build(context, playerNum, env)
        end
    end
    if BridgeShower ~= nil and BridgeShower.hasPreShower ~= nil and BridgeShower.hasPreShower()
            and not (BridgeTask ~= nil and BridgeTask.active and BridgeTask.kind == "shower") then
        local label = getText("IGUI_NotAlone_GetDressed")
        if label == nil or label == "" or label == "IGUI_NotAlone_GetDressed" then label = "Get dressed" end
        context:addOption(label, nil, BridgeMenu.onGetDressed)
    end
end



local function iconSize(btn)
    local w = 48
    pcall(function() w = btn:getWidth() end)
    for _, size in ipairs({ 128, 96, 80, 64, 48 }) do
        if w >= size then return size end
    end
    return 48
end



local SIDEBAR_FIRST = 5
local SIDEBAR_STABLE = 30

BridgeMenu.VANILLA_BTNS = { "invBtn", "healthBtn", "craftingBtn", "buildBtn", "movableBtn",
    "zoneBtn", "mapBtn", "searchBtn", "safetyBtn", "adminBtn", "debugBtn", "clientBtn",
    "arfBtn", "warManagerBtn" }


BridgeMenu.sidebarAuto = 0


function BridgeMenu.sidebarAutoSlots()
    local n = tonumber(BridgeMenu.sidebarAuto) or 0
    if n < 0 then n = 0 end
    if n > 12 then n = 12 end
    return math.floor(n)
end


function BridgeMenu.sidebarShift()
    local base = 0
    pcall(function()
        base = BridgeData.sandboxNumber("SidebarOffsetSlots", 0, 0, 12)
    end)
    base = math.floor(base) + BridgeMenu.sidebarAutoSlots()
    if base >= 12 then return false end
    BridgeMenu.sidebarAuto = BridgeMenu.sidebarAutoSlots() + 1
    return true
end


local WINDOW_KEY_NAME = "Companion Menu"
local WINDOW_KEY_SECTION = "[Companion Menu]"





function BridgeMenu.sidebarTarget(panel, btn, screenH)
    local bottom, last = 0, nil


    for _, key in ipairs(BridgeMenu.VANILLA_BTNS) do
        local child = panel[key]
        if child ~= nil and child ~= btn and child:isVisible() and child:getBottom() > bottom then
            bottom, last = child:getBottom(), child
        end
    end
    if last == nil then return nil end
    local slots = 0
    pcall(function()
        slots = BridgeData.sandboxNumber("SidebarOffsetSlots", 0, 0, 12)
    end)
    slots = math.floor(slots) + BridgeMenu.sidebarAutoSlots()
    if slots > 12 then slots = 12 end
    local gap = UI_BORDER_SPACING + 5
    local h = btn:getHeight()
    local x, y = 0, bottom + gap + math.floor(slots) * (h + gap)
    if screenH ~= nil and screenH > 0 and panel:getAbsoluteY() + y + h > screenH then
        x, y = last:getRight() + UI_BORDER_SPACING, last:getY()
    end
    return x, y
end









function BridgeMenu.sidebarStep(panel, btn, screenH)
    local x, y = BridgeMenu.sidebarTarget(panel, btn, screenH)
    if x == nil then return false end
    local S = panel.notAlonePlace
    if S == nil then S = {} panel.notAlonePlace = S end
    if S.x == x and S.y == y then S.n = (S.n or 0) + 1 else S.x, S.y, S.n = x, y, 1 end
    local need = S.shown and SIDEBAR_STABLE or SIDEBAR_FIRST
    if S.n < need then return false end
    local moved = false
    if btn:getX() ~= x or btn:getY() ~= y then
        btn:setX(x)
        btn:setY(y)
        moved = true
    end
    if panel:getHeight() < btn:getBottom() then panel:setHeight(btn:getBottom()) end
    if panel:getWidth() < btn:getRight() then panel:setWidth(btn:getRight()) end
    if not S.shown then
        S.shown = true
        btn:setVisible(true)
        if Bridge ~= nil then
            log(string.format("sidebar diag icon shown t=%.1f tick=%d x=%d y=%d", Bridge.time, Bridge.tick, x, y))
        end
        moved = true
    end
    return moved
end


function BridgeMenu.onButton(panel, button)
    BridgeMenu.dismissNewHint()
    if Bridge == nil or Bridge.store == nil or BridgeWindow == nil then return end
    local x = panel:getAbsoluteX() + button:getRight() + 4
    local y = panel:getAbsoluteY() + button:getY()

    pcall(function()
        local screenH = getCore():getScreenHeight()
        if y + BridgeWindow.HEIGHT > screenH then y = math.max(0, screenH - BridgeWindow.HEIGHT) end
    end)
    BridgeWindow.toggle(x, y)
end


function BridgeMenu.onButtonMenu(panel, button)
    BridgeMenu.dismissNewHint()
    if Bridge == nil or Bridge.store == nil then return end
    local playerNum = 0
    pcall(function() playerNum = panel.chr:getPlayerNum() end)
    local x = panel:getAbsoluteX() + button:getRight() + 4
    local y = panel:getAbsoluteY() + button:getY()
    local context = ISContextMenu.get(playerNum, x, y)
    BridgeMenu.fill(context, playerNum, true)
end


function BridgeMenu.installWindowKeybind()
    if BridgeMenu.windowKeybindDone then return end
    if type(keyBinding) ~= "table" then return end
    for _, bind in ipairs(keyBinding) do
        if type(bind) == "table" and bind.value == WINDOW_KEY_NAME then
            BridgeMenu.windowKeybindDone = true
            return
        end
    end
    local section = false
    for _, bind in ipairs(keyBinding) do
        if type(bind) == "table" and bind.value == WINDOW_KEY_SECTION then section = true break end
    end
    if not section then table.insert(keyBinding, { value = WINDOW_KEY_SECTION }) end
    local key = nil
    if Keyboard ~= nil then key = Keyboard.KEY_F8 end
    if key == nil then return end
    table.insert(keyBinding, { value = WINDOW_KEY_NAME, key = key })
    BridgeMenu.windowKeybindDone = true
    log("window keybind registered")
end


function BridgeMenu.applySandboxWindowKey()
    if type(keyBinding) ~= "table" then return false end
    if BridgeRadial == nil or type(BridgeRadial.sandboxKeyCode) ~= "function" then return false end
    local t = nil
    pcall(function() t = (SandboxVars ~= nil) and SandboxVars.StayWithMe or nil end)
    if t == nil then return false end
    local code = BridgeRadial.sandboxKeyCode(t.CompanionMenuKey)
    if code == nil then return false end
    local found = false
    for _, bind in ipairs(keyBinding) do
        if type(bind) == "table" and bind.value == WINDOW_KEY_NAME then
            bind.key = code
            found = true
            pcall(function() getCore():addKeyBinding(WINDOW_KEY_NAME, code, 0, false, false, false) end)
            break
        end
    end
    if not found then return false end
    if MainOptions ~= nil and type(MainOptions.keys) == "table" then
        for _, bind in ipairs(MainOptions.keys) do
            if type(bind) == "table" and bind.value == WINDOW_KEY_NAME then bind.key = code end
        end
    end
    BridgeMenu.windowKeyApplied = true
    return true
end


function BridgeMenu.onWindowKey(key)
    if Bridge == nil or Bridge.store == nil then return end
    if BridgeWindow == nil then return end
    if getSpecificPlayer(0) == nil then return end
    if MainScreen == nil or MainScreen.instance == nil or MainScreen.instance.inGame ~= true then return end
    local hit = false
    pcall(function() hit = getCore():isKey(WINDOW_KEY_NAME, key) == true end)
    if not hit then return end
    local x, y = nil, nil
    pcall(function()
        local panel = ISEquippedItem ~= nil and ISEquippedItem.instance or nil
        if panel == nil then return end
        local btn = panel.notAloneBtn
        if btn == nil or not btn:isVisible() then return end
        x = panel:getAbsoluteX() + btn:getRight() + 4
        y = panel:getAbsoluteY() + btn:getY()
    end)
    BridgeWindow.toggle(x, y)
end


function BridgeMenu.sidebarOverlap(panel)
    if panel == nil then return nil end
    local btn = panel.notAloneBtn
    if btn == nil or not btn:isVisible() then return nil end
    local order = nil
    pcall(function() order = panel:getChildrenInOrder() end)
    if type(order) ~= "table" then return nil end
    local ignored = {}
    for _, name in ipairs(BridgeMenu.VANILLA_BTNS) do
        local child = panel[name]
        if child ~= nil then ignored[child] = true end
    end
    if panel.mainHand ~= nil then ignored[panel.mainHand] = true end
    if panel.offHand ~= nil then ignored[panel.offHand] = true end
    if panel.movableTooltip ~= nil then ignored[panel.movableTooltip] = true end
    if panel.radialIcon ~= nil then ignored[panel.radialIcon] = true end
    ignored[btn] = true
    local mine = nil
    for i = 1, #order do
        if order[i] == btn then mine = i break end
    end
    if mine == nil then return nil end
    local left, top = btn:getX(), btn:getY()
    local right, bottom = btn:getRight(), btn:getBottom()
    for i = mine + 1, #order do
        local other = order[i]
        if other ~= nil and ignored[other] ~= true then
            local visible = false
            pcall(function() visible = other:isVisible() == true end)
            if visible then
                local w, h = other:getWidth(), other:getHeight()
                if w > 0 and h > 0
                        and other:getX() < right and other:getRight() > left
                        and other:getY() < bottom and other:getBottom() > top then
                    return other
                end
            end
        end
    end
    for i = mine - 1, 1, -1 do
        local other = order[i]
        if other ~= nil and ignored[other] ~= true then
            local visible = false
            pcall(function() visible = other:isVisible() == true end)
            if visible then
                local w, h = other:getWidth(), other:getHeight()
                if w > 0 and h > 0 and h <= btn:getHeight() * 3
                        and other:getX() < right and other:getRight() > left
                        and other:getY() < bottom and other:getBottom() > top then
                    return other
                end
            end
        end
    end
    return nil
end


function BridgeMenu.sidebarDiag(panel, other)
    local btn = panel.notAloneBtn
    if btn == nil then return "no-btn" end
    local order = nil
    pcall(function() order = panel:getChildrenInOrder() end)
    if type(order) ~= "table" then return "no-order" end
    local mine = nil
    for i = 1, #order do
        if order[i] == btn then mine = i break end
    end
    if mine == nil then return "btn-not-listed" end
    local x, y = 0, 0
    local w, h = 0, 0
    pcall(function() x, y = btn:getX(), btn:getY() end)
    pcall(function() w, h = btn:getWidth(), btn:getHeight() end)
    local left, top, right, bottom = x, y, x + w, y + h
    local parts = {}
    parts[#parts + 1] = string.format("mine=%d,%d,%d,%d", x, y, w, h)
    parts[#parts + 1] = "shown=" .. tostring(panel.notAlonePlace ~= nil and panel.notAlonePlace.shown == true)
    local alive = false
    pcall(function() alive = Bridge ~= nil and Bridge.alive() == true end)
    parts[#parts + 1] = "alive=" .. tostring(alive)
    parts[#parts + 1] = "other=" .. tostring(other ~= nil and (other.internal or other.type or "?") or "nil")
    for i = mine + 1, #order do
        local c = order[i]
        if c ~= nil then
            local vis = false
            pcall(function() vis = c:isVisible() == true end)
            local cw, ch = 0, 0
            pcall(function() cw, ch = c:getWidth(), c:getHeight() end)
            if vis and cw > 0 and ch > 0 then
                local cx, cy = 0, 0
                local cr, cb = 0, 0
                pcall(function()
                    cx, cy = c:getX(), c:getY()
                    cr, cb = c:getRight(), c:getBottom()
                end)
                local over = cx < right and cr > left and cy < bottom and cb > top
                parts[#parts + 1] = string.format("%s[%d,%d,%d,%d,%s]",
                    tostring(c.internal or c.type or "?"), cx, cy, cw, ch, over and "over" or "clear")
            end
        end
    end
    return table.concat(parts, " ")
end


if ISEquippedItem ~= nil and not ISEquippedItem.notAloneWrapped then
    local originalInit = ISEquippedItem.initialise
    ISEquippedItem.initialise = function(self, ...)
        originalInit(self, ...)
        pcall(function()
            if self.chr == nil or self.chr:getPlayerNum() ~= 0 or self.invBtn == nil then return end
            BridgeMenu.resetNewHintCache()
            BridgeMenu.sidebarDiagSig = nil
            local w, h = self.invBtn:getWidth(), self.invBtn:getHeight()
            local size = iconSize(self.invBtn)
            self.notAloneOff = getTexture("media/ui/Sidebar/NotAlone_Off_" .. size .. ".png")
            self.notAloneOn = getTexture("media/ui/Sidebar/NotAlone_On_" .. size .. ".png")
            local y = self:getHeight() + UI_BORDER_SPACING + 5
            local btn = ISButton:new(0, y, w, h, "", self, BridgeMenu.onButton)
            btn:setImage(self.notAloneOff)
            btn.internal = "NOTALONE"
            btn:initialise()
            btn:instantiate()
            local baseRender = btn.render
            btn.render = function(button, ...)
                if baseRender ~= nil then baseRender(button, ...) end
                if not BridgeMenu.newHintOn() then return end
                local r = math.max(3, math.floor(button.height * 0.12))
                local cx, cy = button.width - r - 3, r + 3
                button:drawRect(cx - r - 1, cy - r - 1, 2 * r + 2, 2 * r + 2, 0.85, 0, 0, 0)
                button:drawRect(cx - r, cy - r, 2 * r, 2 * r, 1, 0.95, 0.25, 0.20)
            end
            btn:setDisplayBackground(false)
            btn:ignoreWidthChange()
            btn:ignoreHeightChange()
            local panel = self
            btn.onRightMouseUp = function(_, x, y) BridgeMenu.onButtonMenu(panel, btn) end
            self:addChild(btn)


            btn:setVisible(false)
            self.notAloneBtn = btn
            self.notAloneLit = false
            self:addMouseOverToolTipItem(btn, tr("Companion"))
            self:setHeight(btn:getBottom())
        end)
    end

    local originalPrerender = ISEquippedItem.prerender
    ISEquippedItem.prerender = function(self, ...)
        originalPrerender(self, ...)
        local btn = self.notAloneBtn
        if btn == nil or Bridge == nil then return end
        pcall(function()
            local lit = BridgeMenu.lit() or BridgeMenu.newHintOn()
            if lit ~= self.notAloneLit then
                self.notAloneLit = lit
                btn:setImage(lit and self.notAloneOn or self.notAloneOff)
            end

            local screenH = nil
            pcall(function() screenH = getCore():getScreenHeight() end)
            BridgeMenu.sidebarStep(self, btn, screenH)

            if not BridgeMenu.windowKeyApplied and Bridge.every(60) then
                pcall(BridgeMenu.applySandboxWindowKey)
            end
            if self.notAlonePlace ~= nil and self.notAlonePlace.shown == true
                    and Bridge.every(60) then
                local other = BridgeMenu.sidebarOverlap(self)
                local sig = BridgeMenu.sidebarDiag(self, other)
                if sig ~= BridgeMenu.sidebarDiagSig then
                    BridgeMenu.sidebarDiagSig = sig
                    log(string.format("sidebar diag t=%.1f tick=%d %s", Bridge.time, Bridge.tick, sig))
                end
                if other ~= nil then
                    local tag = tostring(other.internal or "?")
                    if BridgeMenu.sidebarOverlapSeen ~= tag then
                        BridgeMenu.sidebarOverlapSeen = tag
                        log("sidebar overlap: " .. tag)
                    end
                    if BridgeMenu.sidebarShift() then
                        log("sidebar auto shift: " .. tostring(BridgeMenu.sidebarAutoSlots()))
                    end
                end
            end

            if Bridge.every(30) then
                for _, item in ipairs(self.mouseOverList or {}) do
                    if item.object == btn then item.displayString = BridgeMenu.newHintOn() and tr("SidebarNewTip") or BridgeMenu.status() end
                end
            end
        end)
    end
    ISEquippedItem.notAloneWrapped = true
    log("sidebar button wrapped")
end

BridgeMenu.installWindowKeybind()
if Events ~= nil then
    if Events.OnKeyStartPressed ~= nil then
        Events.OnKeyStartPressed.Add(function(key) pcall(BridgeMenu.onWindowKey, key) end)
    end
    if Events.OnGameStart ~= nil then
        Events.OnGameStart.Add(function()
            pcall(BridgeMenu.installWindowKeybind)
            BridgeMenu.windowKeyApplied = BridgeMenu.applySandboxWindowKey() == true
        end)
    end
end





local function underMouse(z, playerNum)
    local hit = false
    pcall(function()
        local core = getCore()
        local zoom = core:getZoom(playerNum)
        local height = 128 * Core.getTileScale() / 2 / zoom
        local half = height * 0.3
        local sx = isoToScreenX(playerNum, z:getX(), z:getY(), z:getZ())
        local sy = isoToScreenY(playerNum, z:getX(), z:getY(), z:getZ())
        local mx, my = getMouseX(), getMouseY()
        hit = mx >= sx - half and mx <= sx + half and my <= sy + height * 0.1 and my >= sy - height
    end)
    return hit
end




local menuMemo = setmetatable({}, { __mode = "k" })

local function menuEntry(worldobjects)
    if type(worldobjects) ~= "table" then return nil end
    local tick = Bridge ~= nil and tonumber(Bridge.tick) or 0
    local e = menuMemo[worldobjects]
    if e == nil or e.tick ~= tick then
        e = { tick = tick }
        menuMemo[worldobjects] = e
    end
    return e
end

local function bodyNear(worldobjects, playerNum)
    local e = menuEntry(worldobjects)
    if e ~= nil and e.bodyNear ~= nil then return e.bodyNear end
    local function done(v)
        if e ~= nil then e.bodyNear = v end
        return v
    end
    local pn = playerNum or 0
    local me = BridgeData.me()
    local mine, others = {}, {}
    if Bridge.alive() then mine[Bridge.body] = true end
    for z, info in pairs(Bridge.bodiesSeen()) do
        if info.who == me then mine[z] = true else others[z] = true end
    end
    for z in pairs(mine) do if underMouse(z, pn) then return done(true) end end
    for z in pairs(others) do if underMouse(z, pn) then return done(false) end end
    local sq = nil
    for _, o in ipairs(worldobjects or {}) do
        pcall(function() sq = o:getSquare() end)
        if sq ~= nil then break end
    end
    if sq == nil then return done(false) end
    local function dist2(z)
        local d = nil
        pcall(function()
            if math.abs(z:getZ() - sq:getZ()) >= 1 then return end
            local dx, dy = z:getX() - (sq:getX() + 0.5), z:getY() - (sq:getY() + 0.5)
            d = dx * dx + dy * dy
        end)
        return d
    end
    local best, bestMine = 2.25, false
    local found = false
    for z in pairs(mine) do
        local d = dist2(z)
        if d ~= nil and d <= best then best, bestMine, found = d, true, true end
    end
    for z in pairs(others) do
        local d = dist2(z)
        if d ~= nil and d < best then best, bestMine, found = d, false, true end
    end
    return done(found and bestMine)
end

function BridgeMenu.onWorldMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end

    if playerNum ~= nil and playerNum ~= 0 then return end
    local ok, yes = pcall(bodyNear, worldobjects, playerNum)
    if not ok or not yes then return end
    BridgeMenu.clickObjects = worldobjects
    local option = context:addOptionOnTop(name())
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    BridgeMenu.fill(sub, playerNum)
end

local function treeUnder(worldobjects)
    local e = menuEntry(worldobjects)
    if e ~= nil and e.tree ~= nil then return e.tree or nil end
    local tree = nil
    for _, o in ipairs(worldobjects or {}) do
        pcall(function()
            local sq = o:getSquare()
            if sq ~= nil then
                local t = sq:getTree()
                if t ~= nil and t:getObjectIndex() >= 0 then tree = t end
            end
        end)
        if tree ~= nil then break end
    end
    if e ~= nil then e.tree = tree or false end
    return tree
end

local function seatUnder(worldobjects)
    local e = menuEntry(worldobjects)
    if e ~= nil and e.seat ~= nil then return e.seat or nil end
    for _, o in ipairs(worldobjects or {}) do
        if o ~= nil then
            local isSeat = false
            pcall(function()
                isSeat = BridgeTask ~= nil and BridgeTask.seatIsSeat ~= nil and BridgeTask.seatIsSeat(o) == true
            end)
            if isSeat then
                if e ~= nil then e.seat = o end
                return o
            end
        end
    end
    if e ~= nil then e.seat = false end
    return nil
end

local function bedUnder(worldobjects)
    local e = menuEntry(worldobjects)
    if e ~= nil and e.bed ~= nil then return e.bed or nil end
    for _, o in ipairs(worldobjects or {}) do
        if o ~= nil then
            local isBed = false
            pcall(function()
                isBed = BridgeTask ~= nil and BridgeTask.sitIsRealBed ~= nil and BridgeTask.sitIsRealBed(o) == true
            end)
            if isBed then
                if e ~= nil then e.bed = o end
                return o
            end
        end
    end
    if e ~= nil then e.bed = false end
    return nil
end

function BridgeMenu.onCutTree(target, tree)
    tree = tree or target
    if BridgeTask == nil or tree == nil then return end
    local sq = nil
    pcall(function() sq = tree:getSquare() end)
    if sq == nil then return end
    local res = BridgeTask.start("chopTree", { { x = sq:getX(), y = sq:getY(), z = sq:getZ() } })
    log("cut tree from menu: " .. tostring(res))
end

function BridgeMenu.onJobChopTree()
    if BridgeTask == nil or BridgeWorkSelect == nil then return end
    if not Bridge.alive() then return end
    BridgeWorkSelect.begin(BridgeData.owner(), "chopTree")
end

function BridgeMenu.onJobCleanUp()
    if BridgeTask == nil or BridgeWorkSelect == nil then return end
    if not Bridge.alive() then return end
    BridgeWorkSelect.begin(BridgeData.owner(), "cleanUp")
end

function BridgeMenu.onJobClearPlants()
    if BridgeTask == nil or BridgeWorkSelect == nil then return end
    if not Bridge.alive() then return end
    BridgeWorkSelect.begin(BridgeData.owner(), "clearPlants")
end

function BridgeMenu.onJobLootArea()
    if BridgeTask == nil or BridgeWorkSelect == nil then return end
    if not Bridge.alive() then return end
    BridgeWorkSelect.begin(BridgeData.owner(), "lootArea")
end

function BridgeMenu.onJobDepositArea()
    if BridgeTask == nil or BridgeWorkSelect == nil or BridgeDeposit == nil then return end
    if not Bridge.alive() then return end
    BridgeWorkSelect.begin(BridgeData.owner(), "depositArea")
end

function BridgeMenu.onDepositHome()
    if BridgeDeposit == nil or type(BridgeDeposit.startHome) ~= "function" then return end
    local res = BridgeDeposit.startHome()
    log("deposit home from menu: " .. tostring(res))
end

function BridgeMenu.onJobMoveCorpses()
    if BridgeTask == nil or BridgeWorkSelect == nil then return end
    if not Bridge.alive() then return end
    BridgeWorkSelect.begin(BridgeData.owner(), "moveCorpses")
end

function BridgeMenu.onJobOpenDoors()
    if BridgeTask == nil or BridgeWorkSelect == nil then return end
    if not Bridge.alive() and not (BridgeCar ~= nil and BridgeCar.isInside()) then return end
    BridgeWorkSelect.begin(BridgeData.owner(), "openDoors")
end

function BridgeMenu.onJobCloseDoors()
    if BridgeTask == nil or BridgeWorkSelect == nil then return end
    if not Bridge.alive() and not (BridgeCar ~= nil and BridgeCar.isInside()) then return end
    BridgeWorkSelect.begin(BridgeData.owner(), "closeDoors")
end


function BridgeMenu.cancelEntry()
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 then return nil end
    if BridgeTask.isLying ~= nil and BridgeTask.isLying() then
        return { key = "GetUp", handler = BridgeMenu.onLayGetUp }
    end
    if BridgeTask.isSeated ~= nil and BridgeTask.isSeated() then
        return { key = "StandUp", handler = BridgeMenu.onSitStandUp }
    end
    local task = BridgeTask.active == true
    local transfers = BridgeQueue ~= nil and BridgeQueue.jobs ~= nil and #BridgeQueue.jobs > 0
    if not task and not transfers then return nil end
    local key = "CancelTask"
    if task and BridgeTask.kind == "exercise" then
        key = "CancelExercise"
    elseif task and BridgeTask.kind == "shower" then
        key = "CancelShower"
    end
    return { key = key, handler = BridgeMenu.onCancelTask }
end

function BridgeMenu.addCancelTask(context)
    if context == nil then return end
    local entry = BridgeMenu.cancelEntry()
    if entry == nil then return end
    context:addOption(tr(entry.key), nil, entry.handler)
end

function BridgeMenu.onCancelTask()
    local did = false
    if BridgeTask ~= nil and BridgeTask.active then
        BridgeTask.cancel("menu")
        did = true
    end
    if BridgeQueue ~= nil and BridgeQueue.jobs ~= nil and #BridgeQueue.jobs > 0 then
        pcall(function() BridgeQueue.clear("menu") end)
        did = true
    end
    if did and Bridge ~= nil then Bridge.speak("JobCancel") end
end

function BridgeMenu.onJobsMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 then return end
    if not present() then return end
    if context:getOptionFromName(name()) ~= nil then return end
    local option = context:addOptionOnTop(name())
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    if BridgeMenu.SHOW_STATUS then
        local status = sub:addOption(BridgeMenu.status(true))
        status.isDisabled = true
    end
    local jobsOption = sub:addOption(tr("Jobs"))
    local jobs = ISContextMenu:getNew(sub)
    sub:addSubMenu(jobsOption, jobs)
    addLootWorkMenu(jobs)
    if BridgeTask.DOORS_ENABLED == 1 then
        local doorsOption = jobs:addOption(tr("Doors"))
        local doors = ISContextMenu:getNew(jobs)
        jobs:addSubMenu(doorsOption, doors)
        local open = doors:addOption(tr("JobOpenDoors"), nil, BridgeMenu.onJobOpenDoors)
        local close = doors:addOption(tr("JobCloseDoors"), nil, BridgeMenu.onJobCloseDoors)
        if BridgeTask.active then open.notAvailable = true; close.notAvailable = true end
    end
    if BridgeTask.CLEANING_ENABLED == 1 then
        local okClean = false
        pcall(function() okClean = BridgeTask.kinds.cleanUp.available(Bridge.body) end)
        local clean = jobs:addOption(tr("JobCleanUp"), nil, BridgeMenu.onJobCleanUp)
        if not okClean then jobTip(clean, "cleanUp") end
        if not okClean or BridgeTask.active then clean.notAvailable = true end
    end
    if BridgeTask.CLEARING_ENABLED == 1 then
        local okClear = false
        pcall(function() okClear = BridgeTask.kinds.clearPlants.available(Bridge.body) end)
        local clear = jobs:addOption(tr("JobClearPlants"), nil, BridgeMenu.onJobClearPlants)
        jobTip(clear, "clearPlants")
        if not okClear or BridgeTask.active then clear.notAvailable = true end
    end
    if BridgeTask.TREECUTTING_ENABLED == 1 then
        local ok = false
        pcall(function() ok = BridgeTask.kinds.chopTree.available(Bridge.body) end)
        local area = jobs:addOption(tr("JobChopTree"), nil, BridgeMenu.onJobChopTree)
        if not ok then jobTip(area, "chopTree") end
        if not ok or BridgeTask.active then area.notAvailable = true end
    end
    if BridgeTask.MOVE_CORPSES_ENABLED == 1 then
        local ok = false
        pcall(function() ok = BridgeTask.kinds.moveCorpses.available(Bridge.body) end)
        local move = jobs:addOption(tr("JobMoveCorpses"), nil, BridgeMenu.onJobMoveCorpses)
        if not ok then jobTip(move, "moveCorpses") end
        if not ok or BridgeTask.active then move.notAvailable = true end
    end
    BridgeMenu.addCancelTask(sub)
end

local function moveableName(obj)
    if obj == nil then return nil end
    local nm = nil
    if ISWorldObjectContextMenu ~= nil and ISWorldObjectContextMenu.getMoveableDisplayName ~= nil then
        pcall(function()
            local shown = ISWorldObjectContextMenu.getMoveableDisplayName(obj)
            if shown ~= nil and tostring(shown) ~= "" and tostring(shown) ~= "nil" then
                nm = tostring(shown)
            end
        end)
    end
    return nm
end

local function rinMenuForName(context, nm)
    if context == nil or nm == nil or nm == "" then return nil end
    local parentOpt = nil
    pcall(function() parentOpt = context:getOptionFromName(nm) end)
    if parentOpt == nil or parentOpt.subOption == nil then return nil end
    local sub = nil
    pcall(function() sub = context:getSubMenu(parentOpt.subOption) end)
    if sub == nil then return nil end
    local exists = nil
    pcall(function() exists = sub:getOptionFromName(name()) end)
    if exists ~= nil and exists.subOption ~= nil then
        local rin = nil
        pcall(function() rin = sub:getSubMenu(exists.subOption) end)
        if rin ~= nil then return rin end
    end
    if exists ~= nil then return nil end
    local rinOpt = sub:addOption(name())
    local rinMenu = ISContextMenu:getNew(sub)
    sub:addSubMenu(rinOpt, rinMenu)
    return rinMenu
end

local function doorPartObjects(door)
    local parts = {}
    if door == nil then return parts end
    parts[#parts + 1] = door
    pcall(function()
        if IsoDoor == nil then return end
        if IsoDoor.getDoubleDoorIndex ~= nil and IsoDoor.getDoubleDoorIndex(door) ~= -1 and IsoDoor.getDoubleDoorObject ~= nil then
            for i = 1, 4 do
                local p = IsoDoor.getDoubleDoorObject(door, i)
                if p ~= nil and p ~= door then parts[#parts + 1] = p end
            end
        end
        if IsoDoor.getGarageDoorIndex ~= nil and IsoDoor.getGarageDoorIndex(door) ~= -1 then
            local p = IsoDoor.getGarageDoorPrev ~= nil and IsoDoor.getGarageDoorPrev(door) or nil
            while p ~= nil and #parts < 12 do parts[#parts + 1] = p; p = IsoDoor.getGarageDoorPrev(p) end
            p = IsoDoor.getGarageDoorNext ~= nil and IsoDoor.getGarageDoorNext(door) or nil
            while p ~= nil and #parts < 24 do parts[#parts + 1] = p; p = IsoDoor.getGarageDoorNext(p) end
        end
    end)
    return parts
end

local function doorLabels()
    local out = {}
    for _, key in ipairs({ "ContextMenu_Door_option", "ContextMenu_Door", "ContextMenu_Door_Frame",
        "ContextMenu_Wooden_Door", "ContextMenu_Double_Wooden_Door", "ContextMenu_Double_Metal_Door",
        "ContextMenu_BigMetalDoubleDoor", "ContextMenu_Wooden_Fence_Door" }) do
        local t = nil
        pcall(function() t = getText(key) end)
        if type(t) == "string" and t ~= "" and t ~= key then out[#out + 1] = t end
    end
    return out
end

local function isDoorObject(obj)
    local ok = false
    pcall(function()
        ok = instanceof ~= nil and obj ~= nil and (instanceof(obj, "IsoDoor")
            or (instanceof(obj, "IsoThumpable") and obj:isDoor()))
    end)
    return ok
end

local function rinInObject(context, obj)
    local menu = rinMenuForName(context, moveableName(obj))
    if menu ~= nil then return menu end
    if obj == nil then return nil end
    if not isDoorObject(obj) then return nil end
    local parts = doorPartObjects(obj)
    for i = 2, #parts do
        menu = rinMenuForName(context, moveableName(parts[i]))
        if menu ~= nil then return menu end
    end
    local labels = doorLabels()
    for i = 1, #labels do
        menu = rinMenuForName(context, labels[i])
        if menu ~= nil then return menu end
    end
    return nil
end

local function addInObject(context, obj, label, target, fn)
    local menu = rinInObject(context, obj)
    if menu == nil then return nil end
    local existing = nil
    pcall(function() existing = menu:getOptionFromName(label) end)
    if existing ~= nil then return existing end
    return menu:addOption(label, target, fn)
end

local function rinTopMenu(context)
    local label = name()
    local parent = nil
    pcall(function() parent = context:getOptionFromName(label) end)
    local sub = nil
    if parent ~= nil and parent.subOption ~= nil then
        pcall(function() sub = context:getSubMenu(parent.subOption) end)
    end
    if sub ~= nil then return sub end
    if parent == nil then parent = context:addOptionOnTop(label) end
    sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)
    return sub
end

local function addCompanion(context, obj, label, target, fn)
    return addInObject(context, obj, label, target, fn)
end

function BridgeMenu.onTreeMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 or BridgeTask.TREECUTTING_ENABLED ~= 1 then return end
    if not present() then return end
    local tree = treeUnder(worldobjects)
    if tree == nil then return end
    local sub = rinInObject(context, tree)
    if sub == nil then return end
    if sub:getOptionFromName(tr("CutTree")) ~= nil then return end
    local ok = false
    pcall(function() ok = BridgeTask.kinds.chopTree.available(Bridge.body) end)
    local cut = sub:addOption(tr("CutTree"), tree, BridgeMenu.onCutTree)
    if not ok then cut.notAvailable = true end
    if BridgeTask ~= nil and BridgeTask.ENABLED == 1 and BridgeTask.TREECUTTING_ENABLED == 1 then
        local jobsOption = sub:addOption(tr("Jobs"))
        local jobs = ISContextMenu:getNew(sub)
        sub:addSubMenu(jobsOption, jobs)
        addLootWorkMenu(jobs)
        local area = jobs:addOption(tr("JobChopTree"), nil, BridgeMenu.onJobChopTree)
        if not ok or BridgeTask.active then area.notAvailable = true end
    end
    BridgeMenu.addCancelTask(sub)
end

local function lootTargetsUnder(worldobjects)
    local e = menuEntry(worldobjects)
    if e ~= nil and e.loot ~= nil then return e.loot or nil end
    for _, o in ipairs(worldobjects or {}) do
        if o ~= nil then
            local list = nil
            pcall(function() list = BridgeWorkSelect.lootTargetsForObject(o) end)
            if list ~= nil and #list > 0 then
                if e ~= nil then e.loot = list end
                return list
            end
        end
    end
    local sq = nil
    for _, o in ipairs(worldobjects or {}) do
        pcall(function() sq = o:getSquare() end)
        if sq ~= nil then break end
    end
    if sq == nil then
        if e ~= nil then e.loot = false end
        return nil
    end
    local list = nil
    pcall(function()
        local x, y, z = sq:getX(), sq:getY(), sq:getZ()
        list = BridgeWorkSelect.lootTargets({ x1 = x, y1 = y, x2 = x, y2 = y, z = z })
    end)
    if list ~= nil and #list > 0 then
        if e ~= nil then e.loot = list end
        return list
    end
    if e ~= nil then e.loot = false end
    return nil
end

local function depositTargetsUnder(worldobjects)
    local e = menuEntry(worldobjects)
    if e ~= nil and e.deposit ~= nil then return e.deposit or nil end
    local targets = nil
    if BridgeDeposit ~= nil and type(BridgeDeposit.targetsUnder) == "function" then
        targets = BridgeDeposit.targetsUnder(worldobjects)
    end
    if e ~= nil then e.deposit = targets or false end
    return targets
end

function BridgeMenu.onLootThis(targets)
    if BridgeTask == nil or targets == nil or #targets == 0 then return end
    local res = BridgeTask.start("lootArea", targets)
    log("loot this from menu: " .. tostring(res))
end

function BridgeMenu.onDepositThis(targets)
    if BridgeDeposit == nil or targets == nil or #targets == 0 then return end
    local res = BridgeDeposit.start(targets)
    log("deposit here from menu: " .. tostring(res))
end

local function pryDoorAtObject(o)
    local door = nil
    pcall(function()
        if o == nil then return end
        local isDoor = instanceof(o, "IsoDoor")
            or (instanceof(o, "IsoThumpable") and o:isDoor())
        if not isDoor then return end
        local closed, locked, bar = false, false, false
        pcall(function() closed = not o:IsOpen() end)
        pcall(function() locked = o:isLocked() or o:isLockedByKey() end)
        pcall(function() bar = o:isBarricaded() end)
        if closed and locked and not bar then door = o end
    end)
    return door
end

local function pryDoorInSquare(sq)
    local door = nil
    if sq == nil then return nil end
    pcall(function()
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local d = pryDoorAtObject(objs:get(i))
            if d ~= nil then door = d return end
        end
    end)
    return door
end

local function doorUnder(worldobjects)
    for _, o in ipairs(worldobjects or {}) do
        local d = pryDoorAtObject(o)
        if d ~= nil then return d end
    end
    local sq = nil
    for _, o in ipairs(worldobjects or {}) do
        pcall(function() sq = o:getSquare() end)
        if sq ~= nil then break end
    end
    if sq == nil then return nil end
    local door = pryDoorInSquare(sq)
    if door ~= nil then return door end
    local cell = getCell()
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    for i = 1, #offsets do
        local nsq = nil
        pcall(function() nsq = cell:getGridSquare(x + offsets[i][1], y + offsets[i][2], z) end)
        door = pryDoorInSquare(nsq)
        if door ~= nil then return door end
    end
    return nil
end

function BridgeMenu.onPryOpen(target)
    if BridgeTask == nil or target == nil then return end
    local res = BridgeTask.start("pryDoor", { { x = target.x, y = target.y, z = target.z } })
    log("pry open from menu: " .. tostring(res))
end

function BridgeMenu.onPryMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 or BridgeTask.PRY_ENABLED ~= 1 then return end
    if not present() then return end
    local door = doorUnder(worldobjects)
    if door == nil then return end
    if BridgeDoors ~= nil and BridgeLog ~= nil and BridgeLog.on() then
        print("[BridgeDoors] pry " .. tostring(BridgeDoors.keyInfo(door, Bridge.body)))
    end
    local keyed = false
    pcall(function() keyed = BridgeDoors ~= nil and BridgeDoors.hasKey(door, Bridge.body, true) == true end)
    if keyed then return end
    local sq = nil
    pcall(function() sq = door:getSquare() end)
    if sq == nil then return end
    local target = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
    local opt = addCompanion(context, door, tr("PryOpen"), target, BridgeMenu.onPryOpen)
    if opt == nil then return end
    local hasTool = false
    pcall(function() hasTool = BridgeTask.findCrowbar(Bridge.body) ~= nil end)
    if not hasTool or BridgeTask.active then opt.notAvailable = true end
    if not hasTool then tip(opt, tr("Need_Crowbar")) end
end

local GENERIC_LOOT_ICON = "media/textures/WorldItems/CrateBasic.png"

local function iconOf(option, item, withColor)
    if option == nil or item == nil then return end
    pcall(function()
        local tex = item:getTex()
        if tex ~= nil then option.iconTexture = tex:splitIcon() end
    end)
    if withColor then
        pcall(function()
            local c = item:getColor()
            if c ~= nil then option.color = { r = c:getR(), g = c:getG(), b = c:getB() } end
        end)
    end
end

local function lootIcon(option)
    if option == nil then return end
    pcall(function()
        local tex = getTexture(GENERIC_LOOT_ICON)
        if tex ~= nil then option.iconTexture = tex end
    end)
end

local function containerIcon(option, cont)
    if option == nil or cont == nil then return end
    local tex = nil
    local parent = nil
    pcall(function() parent = cont:getParent() end)
    if parent ~= nil then
        local name = nil
        pcall(function() name = parent:getTextureName() end)
        if name ~= nil and name ~= "" then pcall(function() tex = getTexture(name) end) end
    end
    if tex == nil then
        local part = nil
        pcall(function() part = cont:getVehiclePart() end)
        if part ~= nil then lootIcon(option) end
    end
    if tex ~= nil then option.iconTexture = tex end
end

function BridgeMenu.onLootMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 or BridgeTask.LOOTING_ENABLED ~= 1 then return end
    if not BridgeData.optionOf(Bridge.store, "lootMenu") then return end
    if not present() then return end
    if BridgeWorkSelect == nil or BridgeWorkSelect.lootTargetFor == nil then return end
    local targets = lootTargetsUnder(worldobjects)
    if targets == nil or #targets == 0 then return end
    local ok = false
    pcall(function() ok = BridgeTask.kinds.lootArea.available(Bridge.body) end)
    local sub = rinTopMenu(context)
    local label = tr("LootContainer")
    if sub:getOptionFromName(label) ~= nil then return end
    local opt = sub:addOption(label, targets, BridgeMenu.onLootThis)
    containerIcon(opt, targets[1] ~= nil and targets[1].cont or nil)
    if not ok or BridgeTask.active then opt.notAvailable = true end
end

function BridgeMenu.onDepositMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 or BridgeTask.DEPOSIT_ENABLED ~= 1 then return end
    if BridgeDeposit == nil or type(BridgeDeposit.targetsUnder) ~= "function" then return end
    if not BridgeData.optionOf(Bridge.store, "lootMenu") then return end
    local isPresent = present()
    local markOk = BridgeDeposit.homeMarkHere() == true
    if not isPresent and not markOk then return end
    local targets = depositTargetsUnder(worldobjects)
    if targets == nil or #targets == 0 then return end
    local sub = rinTopMenu(context)
    if isPresent then
        local ok = false
        pcall(function() ok = BridgeTask.kinds.deposit.available(Bridge.body) end)
        local label = tr("DepositLootHere")
        if sub:getOptionFromName(label) == nil then
            local opt = sub:addOption(label, targets, BridgeMenu.onDepositThis)
            if not ok or BridgeTask.active then opt.notAvailable = true end
        end
    end
    if markOk then
        local homeTargets = {}
        for i = 1, #targets do
            if BridgeDeposit.targetAtHome(targets[i]) then homeTargets[#homeTargets + 1] = targets[i] end
        end
        if #homeTargets == 1 then
            local cont = homeTargets[1].cont
            local marked = BridgeDeposit.isMarked(cont)
            local mopt = sub:addOption(tr(marked and "UnmarkStorage" or "MarkStorage"), cont, BridgeMenu.onToggleMark)
            if BridgeTask.active then mopt.notAvailable = true end
        elseif #homeTargets > 1 then
            local mopt = sub:addOption(tr("MarkStorageMenu"))
            local menu = ISContextMenu:getNew(sub)
            sub:addSubMenu(mopt, menu)
            local seenTypes = {}
            for i = 1, #homeTargets do
                local t = homeTargets[i]
                local typeName = "?"
                pcall(function() typeName = tostring(t.cont:getType()) end)
                local n = (seenTypes[typeName] or 0) + 1
                seenTypes[typeName] = n
                local label2 = typeName
                if n > 1 then label2 = label2 .. " " .. tostring(n) end
                local marked = BridgeDeposit.isMarked(t.cont)
                local o = menu:addOption(tr(marked and "UnmarkStorage" or "MarkStorage") .. ": " .. label2, t.cont,
                    BridgeMenu.onToggleMark)
                if BridgeTask.active then o.notAvailable = true end
            end
        end
    end
end

function BridgeMenu.onToggleMark(cont)
    if BridgeDeposit == nil or type(BridgeDeposit.toggleMark) ~= "function" then return end
    local state = BridgeDeposit.toggleMark(cont)
    log("mark toggle " .. tostring(state))
    if state ~= nil and BridgeCallout ~= nil and type(BridgeCallout.markSay) == "function" then
        pcall(BridgeCallout.markSay, state == true)
    end
end

local function lootTargetsForItems(list, playerNum, whole)
    local targets = {}
    if BridgeWorkSelect == nil or BridgeWorkSelect.lootTargetForContainer == nil then return targets end
    local playerInv = nil
    pcall(function()
        local p = getSpecificPlayer(playerNum or 0)
        if p ~= nil then playerInv = p:getInventory() end
    end)
    local groups, order = {}, {}
    for _, it in ipairs(list or {}) do
        local c = nil
        pcall(function() c = it:getContainer() end)
        if c ~= nil then
            local outer = c
            pcall(function() outer = BridgeWorkSelect.outerWorldContainer(c) end)
            local mine = false
            pcall(function() mine = playerInv ~= nil and outer == playerInv end)
            if not mine then
                if groups[c] == nil then
                    groups[c] = {}
                    order[#order + 1] = c
                end
                groups[c][#groups[c] + 1] = it
            end
        end
    end
    for i = 1, #order do
        local c = order[i]
        local t = nil
        pcall(function()
            if whole then t = BridgeWorkSelect.lootTargetForContainer(c)
            else t = BridgeWorkSelect.lootTargetForContainer(c, groups[c]) end
        end)
        if t ~= nil then targets[#targets + 1] = t end
    end
    return targets
end

function BridgeMenu.addItemLootOptions(menu, list, playerNum)
    if menu == nil or type(list) ~= "table" or #list == 0 then return 0 end
    if Bridge == nil or Bridge.store == nil then return 0 end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 or BridgeTask.LOOTING_ENABLED ~= 1 then return 0 end
    if not BridgeData.optionOf(Bridge.store, "lootMenu") then return 0 end
    if not present() then return 0 end
    if not BridgeMenu.inTalkRange() then return 0 end
    local ok = false
    pcall(function() ok = BridgeTask.kinds.lootArea.available(Bridge.body) end)
    local busy = BridgeTask.active
    local added = 0

    if menu:getOptionFromName(tr("LootThis")) == nil then
        local targets = lootTargetsForItems(list, playerNum, false)
        if #targets > 0 then
            local opt = menu:addOption(tr("LootThis"), targets, BridgeMenu.onLootThis)
            iconOf(opt, list[1], true)
            if not ok or busy then opt.notAvailable = true end
            added = added + 1
        end
    end

    if menu:getOptionFromName(tr("LootAll")) == nil then
        local targets = lootTargetsForItems(list, playerNum, true)
        if #targets > 0 then
            local opt = menu:addOption(tr("LootAll"), targets, BridgeMenu.onLootThis)
            lootIcon(opt)
            if not ok or busy then opt.notAvailable = true end
            added = added + 1
        end
    end
    return added
end

function BridgeMenu.onSitThis(targets)
    if BridgeTask == nil or targets == nil or #targets == 0 then return end
    local res = BridgeTask.start("sit", targets)
    log("sit from menu: " .. tostring(res))
end

function BridgeMenu.onSitReadThis(targets)
    if BridgeTask == nil or targets == nil or #targets == 0 then return end
    targets[1].read = true
    local res = BridgeTask.start("sit", targets)
    log("sit+read test: " .. tostring(res))
end

function BridgeMenu.onSitReadStop()
    if BridgeTask == nil or type(BridgeTask.sitReadStop) ~= "function" then return end
    BridgeTask.sitReadStop(Bridge.body)
end

function BridgeMenu.onSitStandUp()
    if BridgeTask ~= nil and BridgeTask.sitStandUp ~= nil then BridgeTask.sitStandUp() end
end

function BridgeMenu.onSitMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 or BridgeTask.SIT_ENABLED ~= 1 then return end
    if not present() then return end
    local seat = seatUnder(worldobjects)
    if seat == nil then return end

    if BridgeTask.isSeated ~= nil and BridgeTask.isSeated() then
        addCompanion(context, seat, tr("StandUp"), nil, BridgeMenu.onSitStandUp)
        if BridgeTask.READ_TEST == true and BridgeTask.sitRead then
            addCompanion(context, seat, "Stop reading (test)", nil, BridgeMenu.onSitReadStop)
        end
        return
    end

    if BridgeTask.active and BridgeTask.kind == "sit" then
        addCompanion(context, seat, tr("CancelTask"), nil, BridgeMenu.onCancelTask)
        return
    end

    local ok = false
    pcall(function() ok = BridgeTask.kinds.sit.available(Bridge.body) end)
    local targets = { { obj = seat, x = 0, y = 0, z = 0 } }
    pcall(function()
        local sq = seat:getSquare()
        if sq ~= nil then targets[1].x, targets[1].y, targets[1].z = sq:getX(), sq:getY(), sq:getZ() end
    end)
    local opt = addCompanion(context, seat, tr("Sit"), targets, BridgeMenu.onSitThis)
    if opt == nil then return end
    if not ok or BridgeTask.active then opt.notAvailable = true end
    pcall(function()
        if BridgeTask.seatTaken({ obj = seat }, Bridge.body) then opt.notAvailable = true end
    end)
    if BridgeTask.READ_TEST == true then
        local readTargets = { { obj = seat, x = targets[1].x, y = targets[1].y, z = targets[1].z, read = true } }
        local readOpt = addCompanion(context, seat, "Sit + read (test)", readTargets, BridgeMenu.onSitReadThis)
        if readOpt ~= nil then
            if not ok or BridgeTask.active then readOpt.notAvailable = true end
            pcall(function()
                if BridgeTask.seatTaken({ obj = seat }, Bridge.body) then readOpt.notAvailable = true end
            end)
        end
    end
end

function BridgeMenu.onLayThis(targets)
    if BridgeTask == nil or targets == nil or #targets == 0 then return end
    local res = BridgeTask.start("lay", targets)
    log("lay from menu: " .. tostring(res))
end

function BridgeMenu.onLayGetUp()
    if BridgeTask ~= nil and BridgeTask.layStandUp ~= nil then
        log("lay get up requested from menu")
        BridgeTask.layStandUp()
    end
end

function BridgeMenu.onLaySleep()
    if BridgeTask ~= nil and BridgeTask.layToggleSleep ~= nil then BridgeTask.layToggleSleep() end
end

function BridgeMenu.onLayMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 or BridgeTask.LAY_ENABLED ~= 1 then return end
    if not present() then return end
    local bed = bedUnder(worldobjects)
    if bed == nil then return end

    if BridgeTask.isLying ~= nil and BridgeTask.isLying() then
        addCompanion(context, bed, tr("GetUp"), nil, BridgeMenu.onLayGetUp)
        local asleep = false
        pcall(function() asleep = BridgeTask.laySleep == true end)
        addCompanion(context, bed, tr(asleep and "Wake" or "Sleep"), nil, BridgeMenu.onLaySleep)
        return
    end

    if BridgeTask.active and BridgeTask.kind == "lay" then
        addCompanion(context, bed, tr("CancelTask"), nil, BridgeMenu.onCancelTask)
        return
    end

    local ok = false
    pcall(function() ok = BridgeTask.kinds.lay.available(Bridge.body) end)
    local targets = { { obj = bed, x = 0, y = 0, z = 0 } }
    pcall(function()
        local sq = bed:getSquare()
        if sq ~= nil then targets[1].x, targets[1].y, targets[1].z = sq:getX(), sq:getY(), sq:getZ() end
    end)
    local opt = addCompanion(context, bed, tr("Lay"), targets, BridgeMenu.onLayThis)
    if opt == nil then return end
    if not ok or BridgeTask.active then opt.notAvailable = true end
    local occupied = false
    pcall(function()
        if BridgeTask.seatTaken({ obj = bed }, Bridge.body) then occupied = true end
    end)
    local playerOn = false
    pcall(function() playerOn = BridgeTask.layPlayerOnBed({ obj = bed }) == true end)
    if occupied then
        opt.notAvailable = true
        tip(opt, tr("LayOccupied"))
    elseif playerOn then
        opt.notAvailable = true
        tip(opt, tr("LayPlayerOn"))
    end
end

local function waterUnder(worldobjects, playerNum)
    for _, o in ipairs(worldobjects or {}) do
        if o ~= nil and BridgeWash ~= nil and BridgeWash.isWaterObject ~= nil and BridgeWash.isWaterObject(o) then
            if BridgeWash.objInfo ~= nil then pcall(function() log("waterUnder " .. BridgeWash.objInfo(o)) end) end
            return o
        end
    end
    for _, o in ipairs(worldobjects or {}) do
        if o ~= nil then
            local sq = nil
            pcall(function() sq = o:getSquare() end)
            if sq ~= nil then
                local found = nil
                pcall(function()
                    if BridgeWash ~= nil and BridgeWash.waterOn ~= nil then found = BridgeWash.waterOn(sq) end
                end)
                if found ~= nil then
                    if BridgeWash ~= nil and BridgeWash.objInfo ~= nil then
                        pcall(function() log("waterUnder (tile) " .. BridgeWash.objInfo(found)) end)
                    end
                    return found
                end
            end
        end
    end
    local found = nil
    pcall(function()
        if BridgeWash ~= nil and BridgeWash.waterOn ~= nil then
            local sq = cursorSquare(playerNum)
            if sq ~= nil then found = BridgeWash.waterOn(sq) end
        end
    end)
    if found ~= nil then
        log("waterUnder (clicked tile)")
        return found
    end
    return nil
end

function BridgeMenu.onWashSinkThis(sink, scope)
    if BridgeTask == nil or sink == nil then return end
    local sq = nil
    pcall(function() sq = sink:getSquare() end)
    if sq == nil then return end
    local res = BridgeTask.start("washSink",
        { { x = sq:getX(), y = sq:getY(), z = sq:getZ() } }, nil,
        { sink = sink, scope = scope })
    log("wash sink from menu: " .. tostring(res) .. " scope=" .. tostring(scope))
end

local function washObjectName(sink)
    local nm = nil
    local isItem = false
    if instanceof ~= nil then pcall(function() isItem = instanceof(sink, "IsoWorldInventoryObject") end) end
    if isItem then
        pcall(function()
            local item = sink:getItem()
            if item ~= nil then nm = item:getName() end
        end)
    elseif type(sink) ~= "table" and ISWorldObjectContextMenu ~= nil and ISWorldObjectContextMenu.getMoveableDisplayName ~= nil then
        local shown = nil
        pcall(function() shown = ISWorldObjectContextMenu.getMoveableDisplayName(sink) end)
        if shown ~= nil and tostring(shown) ~= "nil" and tostring(shown) ~= "" then nm = tostring(shown) end
    end
    if nm == nil or nm == "" then
        if isItem then
            pcall(function() nm = sink:getName() end)
        else
            local fluidName = nil
            local fluidContainer = nil
            if type(sink) ~= "table" then
                pcall(function() fluidContainer = sink:getFluidContainer() end)
            end
            if fluidContainer ~= nil then
                pcall(function() fluidName = sink:getFluidUiName() end)
            end
            if fluidName ~= nil and tostring(fluidName) ~= "" and tostring(fluidName) ~= "nil" then
                nm = tostring(fluidName)
            else
                nm = getText("ContextMenu_NaturalWaterSource")
            end
        end
    end
    return nm
end

local function washScopeReady(scope)
    local ok = false
    pcall(function()
        ok = BridgeTask ~= nil and BridgeTask.kinds ~= nil and BridgeTask.kinds.washSink ~= nil
            and BridgeTask.kinds.washSink.available ~= nil
            and BridgeTask.kinds.washSink.available(Bridge.body, scope)
    end)
    return ok
end

function BridgeMenu.onFillThis(sink, list, item)
    if BridgeTask == nil or sink == nil then return end
    local sq = nil
    pcall(function() sq = sink:getSquare() end)
    if sq == nil then return end
    local targets = { { x = sq:getX(), y = sq:getY(), z = sq:getZ() } }
    local opts = { sink = sink }
    if list ~= nil then opts.items = list
    elseif item ~= nil then opts.item = item end
    local res = BridgeTask.start("fillWater", targets, nil, opts)
    log("fill from menu: " .. tostring(res))
end

local function fillNum(v)
    if type(v) ~= "number" then return "0" end
    if math.floor(v) == v then return string.format("%d", v) end
    return string.format("%.2f", v)
end

local function addFillActions(menu, sink)
    local busy = BridgeTask ~= nil and BridgeTask.active
    local list = {}
    pcall(function()
        if BridgeWash ~= nil and BridgeWash.fillables ~= nil then list = BridgeWash.fillables(Bridge.body) end
    end)
    local fillOpt = menu:addOption(tr("FillHer"), nil, nil)
    log("fill menu containers=" .. tostring(#list) .. (busy and " (busy)" or ""))
    if busy or #list == 0 then
        fillOpt.notAvailable = true
        if #list == 0 and not busy then tip(fillOpt, tr("Say_JobFillNothing")) end
        return
    end
    local containerMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(fillOpt, containerMenu)
    if #list >= 1 then
        containerMenu:addOption(getText("ContextMenu_FillAll"), sink, BridgeMenu.onFillThis, list, nil)
    end
    local groups = {}
    pcall(function()
        if BridgeWash ~= nil and BridgeWash.groupByName ~= nil then groups = BridgeWash.groupByName(list) end
    end)
    for _, g in ipairs(groups) do
        local first = g[1]
        local nm = ""
        pcall(function() nm = tostring(first:getName() or "") end)
        if #g > 1 then
            local typeOpt = containerMenu:addOption(nm .. " (" .. #g .. ")", nil, nil)
            pcall(function() typeOpt.itemForTexture = first end)
            local typeMenu = ISContextMenu:getNew(containerMenu)
            containerMenu:addSubMenu(typeOpt, typeMenu)
            typeMenu:addOption(getText("ContextMenu_FillOne"), sink, BridgeMenu.onFillThis, nil, first)
            typeMenu:addOption(getText("ContextMenu_FillAll"), sink, BridgeMenu.onFillThis, g, nil)
        else
            local oneOpt = containerMenu:addOption(nm, sink, BridgeMenu.onFillThis, nil, first)
            pcall(function() oneOpt.itemForTexture = first end)
            pcall(function()
                local fc = first:getFluidContainer()
                if fc == nil then return end
                local t = ISWorldObjectContextMenu.addToolTip()
                t.maxLineWidth = 512
                t.description = getText("ContextMenu_ItemWaterCapacity") .. " "
                    .. fillNum(fc:getFreeCapacity()) .. " / " .. fillNum(fc:getCapacity())
                oneOpt.toolTip = t
            end)
        end
    end
end

local function showerLabel()
    local text = getText("IGUI_NotAlone_ShowerTake")
    if text == nil or text == "" or text == "IGUI_NotAlone_ShowerTake" then text = "Take a shower" end
    return text
end


function BridgeMenu.onShowerThis(showerObj)
    if BridgeTask == nil or BridgeShower == nil then return end
    local res = nil
    pcall(function() res = BridgeShower.start(showerObj) end)
    log("shower from menu: " .. tostring(res))
end


function BridgeMenu.addShowerAction(menu, showerObj)
    if menu == nil or showerObj == nil then return end
    local opt = menu:addOption(showerLabel(), showerObj, BridgeMenu.onShowerThis)
    if BridgeTask ~= nil and BridgeTask.active then
        opt.notAvailable = true
    else
        local cd = 0
        pcall(function() cd = BridgeShower.cooldownLeft(nil) end)
        if cd ~= nil and cd > 0 then
            opt.notAvailable = true
            tip(opt, string.format("She only showers once a day (%.0fh left).", cd))
        elseif BridgeShower ~= nil and BridgeShower.occupied ~= nil and BridgeShower.occupied(showerObj) then
            opt.notAvailable = true
            tip(opt, "The shower is already in use.")
        elseif BridgeShower ~= nil and BridgeShower.waterSink ~= nil then
            local sink = nil
            pcall(function() sink = BridgeShower.waterSink(showerObj) end)
            if sink ~= nil and BridgeShower.waterAvailable(sink) < 1 then
                opt.notAvailable = true
                tip(opt, "The shower has no water.")
            end
        end
    end
end


function BridgeMenu.onGetDressed()
    if BridgeShower == nil then return end
    local res = nil
    pcall(function() res = BridgeShower.redressNow() end)
    log("get dressed from menu: " .. tostring(res))
end


function BridgeMenu.addRinActions(menu, sink)
    local busy = BridgeTask ~= nil and BridgeTask.active
    local selfOpt = menu:addOption(tr("WashSelf"), sink, BridgeMenu.onWashSinkThis, "self")
    local invOpt = menu:addOption(tr("WashInventory"), sink, BridgeMenu.onWashSinkThis, "inventory")
    if busy or not washScopeReady("self") then
        selfOpt.notAvailable = true
        local clean = false
        pcall(function()
            clean = BridgeWash ~= nil and BridgeWash.dirtyParts ~= nil
                and BridgeWash.dirtyParts(Bridge.body, "self") == 0
        end)
        if clean and not busy then tip(selfOpt, tr("Say_AlreadyClean")) end
    end
    if busy or not washScopeReady("inventory") then
        invOpt.notAvailable = true
        local clean = false
        pcall(function()
            clean = BridgeWash ~= nil and BridgeWash.dirtyParts ~= nil
                and BridgeWash.dirtyParts(Bridge.body, "inventory") == 0
        end)
        if clean and not busy then tip(invOpt, tr("Say_AlreadyClean")) end
    end
    addFillActions(menu, sink)
end

function BridgeMenu.onWashSinkMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 then return end
    if not present() then return end
    if not BridgeMenu.inTalkRange() then return end
    local sink = waterUnder(worldobjects, playerNum)
    if sink == nil then return end

    local rinMenu = nil
    local objName = washObjectName(sink)
    local parentOpt = nil
    if objName ~= nil then
        pcall(function() parentOpt = context:getOptionFromName(objName) end)
    end
    if parentOpt ~= nil and parentOpt.subOption ~= nil then
        local sub = nil
        pcall(function() sub = context:getSubMenu(parentOpt.subOption) end)
        if sub ~= nil then
            local exists = nil
            pcall(function() exists = sub:getOptionFromName(name()) end)
            if exists == nil then
                local rinOpt = sub:addOption(name())
                rinMenu = ISContextMenu:getNew(sub)
                sub:addSubMenu(rinOpt, rinMenu)
            end
        end
    end
    if rinMenu == nil then return end

    local dupe = nil
    pcall(function() dupe = rinMenu:getOptionFromName(tr("WashSelf")) end)
    if dupe ~= nil then return end

    BridgeMenu.addRinActions(rinMenu, sink)
    log("wash sink menu obj=" .. tostring(objName))
end

function BridgeMenu.addWashTo(menu, worldobjects, playerNum)
    if menu == nil then return end
    local sink = waterUnder(worldobjects, playerNum)
    if sink == nil then return end
    local dupe = nil
    pcall(function() dupe = menu:getOptionFromName(tr("WashSelf")) end)
    if dupe ~= nil then return end
    BridgeMenu.addRinActions(menu, sink)
end

local function onCarDoorMenu(playerNum, context, worldobjects, test)
    if test or Bridge == nil or Bridge.store == nil then return end
    if playerNum ~= nil and playerNum ~= 0 then return end
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 then return end
    if BridgeTask.DOORS_ENABLED ~= 1 then return end
    if BridgeCar == nil or not BridgeCar.isInside() then return end
    local red = BridgeData.owner()
    if red == nil or not BridgeCar.withRed(red) then return end
    if context:getOptionFromName(name()) ~= nil then return end
    local option = context:addOptionOnTop(name())
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    if BridgeTask.active and BridgeTask.fromCar then
        BridgeMenu.addCancelTask(sub)
        return
    end
    local jobsOption = sub:addOption(tr("Jobs"))
    local jobs = ISContextMenu:getNew(sub)
    sub:addSubMenu(jobsOption, jobs)
    local doorsOption = jobs:addOption(tr("Doors"))
    local doors = ISContextMenu:getNew(jobs)
    jobs:addSubMenu(doorsOption, doors)
    local open = doors:addOption(tr("JobOpenDoors"), nil, BridgeMenu.onJobOpenDoors)
    local close = doors:addOption(tr("JobCloseDoors"), nil, BridgeMenu.onJobCloseDoors)
    if BridgeTask.active then open.notAvailable = true; close.notAvailable = true end
end

Events.OnFillWorldObjectContextMenu.Add(BridgeMenu.onWorldMenu)
Events.OnFillWorldObjectContextMenu.Add(BridgeMenu.onTreeMenu)
Events.OnFillWorldObjectContextMenu.Add(BridgeMenu.onJobsMenu)
Events.OnFillWorldObjectContextMenu.Add(BridgeMenu.onLootMenu)
Events.OnFillWorldObjectContextMenu.Add(BridgeMenu.onDepositMenu)
Events.OnFillWorldObjectContextMenu.Add(BridgeMenu.onSitMenu)
Events.OnFillWorldObjectContextMenu.Add(BridgeMenu.onLayMenu)
Events.OnFillWorldObjectContextMenu.Add(BridgeMenu.onPryMenu)
Events.OnFillWorldObjectContextMenu.Add(BridgeMenu.onWashSinkMenu)
Events.OnFillWorldObjectContextMenu.Add(onCarDoorMenu)

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    if Bridge ~= nil and Bridge.claimMenuFix ~= nil then pcall(Bridge.claimMenuFix, playerNum, context, worldobjects, test) end
end)
log("loaded")


