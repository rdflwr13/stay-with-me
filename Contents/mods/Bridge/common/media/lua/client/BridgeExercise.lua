
require "ISUI/ISModalDialog"


BridgeExercise = BridgeExercise or {}


BridgeExercise.ANIM = "NA_Squat"
BridgeExercise.REP_TICKS = 3 * 60
BridgeExercise.XP_CHANCE = 100
BridgeExercise.FATIGUE_PER_REP = 0.035
BridgeExercise.STAMINA_STOP = 0.90
BridgeExercise.START_MAX_FATIGUE = 0.01
BridgeExercise.RANGE = 4
BridgeExercise.COOLDOWN_HOURS = 24
BridgeExercise.EFFORT_EVERY = 4
BridgeExercise.CHEER_TICKS = 20 * 60
BridgeExercise.LUMP_FITNESS = 40
BridgeExercise.LUMP_STRENGTH = 40
BridgeExercise.MULT_PER_SESSION = 0.05
BridgeExercise.MULT_CAP = 2.0
BridgeExercise.CATCHUP = 1.5
BridgeExercise.DRAIN_PER_SESSION = 0.02
BridgeExercise.DRAIN_FLOOR = 0.6
BridgeExercise.COMBAT_WINDOW_TICKS = 60 * 60
BridgeExercise.POLL_EVERY = 10
BridgeExercise.POLL_PHASE = 3
BridgeExercise.TIERS = {
    { count = 0, key = "ExTierUntrained", label = "Untrained" },
    { count = 5, key = "ExTierWarmingUp", label = "Warming Up" },
    { count = 10, key = "ExTierRoutine", label = "Routine" },
    { count = 20, key = "ExTierDedicated", label = "Dedicated" },
    { count = 35, key = "ExTierAthletic", label = "Athletic" },
    { count = 50, key = "ExTierPeak", label = "Peak Form" },
}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeExercise] " .. tostring(text)) end end


function BridgeExercise.fatigue()
    local f = 0
    pcall(function() f = tonumber(BridgeFight and BridgeFight.fatigue) or 0 end)
    return f
end


function BridgeExercise.stamina()
    return 1 - BridgeExercise.fatigue()
end


function BridgeExercise.drainPerRep(rec)
    local d = BridgeExercise.FATIGUE_PER_REP
    local lvl = 0
    if BridgeSkills ~= nil and BridgeSkills.level ~= nil then
        pcall(function() lvl = BridgeSkills.level("Fitness") or 0 end)
    end
    local scale = 1 - 0.04 * lvl
    if scale < 0.5 then scale = 0.5 end
    return d * scale * BridgeExercise.drainMult(rec)
end


function BridgeExercise.count(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return 0 end
    return math.max(0, math.floor(tonumber(rec.exerciseCount) or 0))
end


function BridgeExercise.mult(rec)
    local m = 1 + BridgeExercise.MULT_PER_SESSION * BridgeExercise.count(rec)
    if m > BridgeExercise.MULT_CAP then m = BridgeExercise.MULT_CAP end
    return m
end


function BridgeExercise.drainMult(rec)
    local d = 1 - BridgeExercise.DRAIN_PER_SESSION * BridgeExercise.count(rec)
    if d < BridgeExercise.DRAIN_FLOOR then d = BridgeExercise.DRAIN_FLOOR end
    return d
end


function BridgeExercise.tierIndex(count)
    local idx = 1
    for i = 1, #BridgeExercise.TIERS do
        if (tonumber(count) or 0) >= BridgeExercise.TIERS[i].count then idx = i end
    end
    return idx
end


function BridgeExercise.tierLabel(count)
    local t = BridgeExercise.TIERS[BridgeExercise.tierIndex(count)]
    local text = t.label
    if BridgeData ~= nil and BridgeData.text ~= nil then pcall(function() text = BridgeData.text(t.key) end) end
    return text
end


function BridgeExercise.catchup(perk)
    local herLvl = 0
    if BridgeSkills ~= nil and BridgeSkills.level ~= nil then
        pcall(function() herLvl = tonumber(BridgeSkills.level(perk)) or 0 end)
    end
    local redLvl = 0
    if BridgeData ~= nil and BridgeData.owner ~= nil and BridgeSkills ~= nil and BridgeSkills.perkOf ~= nil then
        local red = BridgeData.owner()
        local p = BridgeSkills.perkOf(perk)
        if red ~= nil and p ~= nil then
            pcall(function() redLvl = tonumber(red:getPerkLevel(p)) or 0 end)
        end
    end
    if redLvl > herLvl then return BridgeExercise.CATCHUP end
    return 1
end


local function worldHours()
    local h = nil
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h
end


function BridgeExercise.cooldownLeft(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return 0 end
    local untilH = tonumber(rec.exerciseUntil)
    local now = worldHours()
    if untilH == nil or now == nil then return 0 end
    local left = untilH - now
    if left < 0 then left = 0 end
    return left
end


function BridgeExercise.setCooldown(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    local now = worldHours()
    if now == nil then return end
    local untilH = now + BridgeExercise.COOLDOWN_HOURS
    if rec ~= nil then rec.exerciseUntil = untilH end
    if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { exerciseUntil = untilH }) end)
    end
    log(string.format("set cooldown until %.2f (%.1fh)", untilH, BridgeExercise.COOLDOWN_HOURS))
end


function BridgeExercise.bankOf(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return 0 end
    local v = tonumber(rec.exerciseBank) or 0
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return v
end


function BridgeExercise.setBank(rec, v)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return end
    v = tonumber(v) or 0
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    rec.exerciseBank = v
    if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { exerciseBank = v }) end)
    end
end


function BridgeExercise.addBank(rec, d)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return end
    BridgeExercise.setBank(rec, BridgeExercise.bankOf(rec) + (tonumber(d) or 0))
end


function BridgeExercise.rollBankDay(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return end
    local now = worldHours()
    if now == nil then return end
    local day = math.floor(now / 24)
    if tonumber(rec.exerciseBankDay) == day then return end
    rec.exerciseBankDay = day
    BridgeExercise.setBank(rec, 0)
    if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { exerciseBankDay = day }) end)
    end
end


function BridgeExercise.ready(rec)
    BridgeExercise.rollBankDay(rec)
    if BridgeExercise.cooldownLeft(rec) > 0 then return false, "cooldown" end
    if BridgeExercise.fatigue() > BridgeExercise.START_MAX_FATIGUE then return false, "tired" end
    if BridgeExercise.combatRecent() then return false, "combat" end
    return true
end


function BridgeExercise.combatRecent()
    if BridgeExercise.playerCombatAt == nil then return false end
    return (Bridge.time or 0) < BridgeExercise.playerCombatAt + BridgeExercise.COMBAT_WINDOW_TICKS
end


function BridgeExercise.combatPoll()
    if Bridge == nil or BridgeData == nil or BridgeData.owner == nil then return end
    local red = BridgeData.owner()
    if red == nil then return end
    local hp = nil
    pcall(function() hp = red:getBodyDamage():getOverallBodyHealth() end)
    if hp ~= nil and BridgeExercise.lastRedHp ~= nil and hp < BridgeExercise.lastRedHp - 0.5 then
        BridgeExercise.playerCombatAt = Bridge.time
    end
    if hp ~= nil then BridgeExercise.lastRedHp = hp end
end


function BridgeExercise.blockReason()
    if BridgeTask ~= nil and BridgeTask.active then return "busy" end
    if BridgeExercise.hardBusy() then return "busy" end
    local ok, why = BridgeExercise.ready(Bridge.store)
    if not ok then return why end
    if BridgeTask ~= nil and BridgeTask.dangerNear ~= nil and Bridge.alive() and BridgeTask.dangerNear(Bridge.body) then
        return "danger"
    end
    return nil
end


function BridgeExercise.recordSession(rec)
    rec = rec or (Bridge ~= nil and Bridge.store) or nil
    if rec == nil then return end
    local before = BridgeExercise.count(rec)
    local after = before + 1
    rec.exerciseCount = after
    local now = worldHours()
    if now ~= nil then rec.exerciseLast = now end
    if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
        pcall(function()
            sendClientCommand(BridgeData.owner(), "Bridge", "state", { exerciseCount = after, exerciseLast = rec.exerciseLast })
        end)
    end
    if BridgeExercise.tierIndex(after) > BridgeExercise.tierIndex(before) then
        Bridge.speak("ExerciseTierUp", BridgeExercise.tierLabel(after))
    end
    log(string.format("session recorded count=%d mult=%.2f drain=%.2f", after, BridgeExercise.mult(rec), BridgeExercise.drainMult(rec)))
end


function BridgeExercise.cheer()
    if (Bridge.time or 0) < (BridgeExercise.cheerAt or 0) then return end
    BridgeExercise.cheerAt = (Bridge.time or 0) + BridgeExercise.CHEER_TICKS
    BridgeExercise.cheerIdx = ((BridgeExercise.cheerIdx or 0) % 3) + 1
    Bridge.speak("ExerciseCheer" .. BridgeExercise.cheerIdx)
end


function BridgeExercise.showNotice(onOk)
    BridgeExercise.noticeShown = true
    local rec = Bridge ~= nil and Bridge.store or nil
    if rec ~= nil and rec.exerciseTold ~= true then
        rec.exerciseTold = true
        if Bridge ~= nil and Bridge.mp and BridgeData ~= nil and BridgeData.owner ~= nil then
            pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { exerciseTold = true }) end)
        end
    end
    local text = nil
    if BridgeData ~= nil and BridgeData.text ~= nil then pcall(function() text = BridgeData.text("ExerciseNotice") end) end
    if type(text) ~= "string" or text == "" or text == "IGUI_NotAlone_ExerciseNotice" then
        text = "Heads up: she can only work out once every 24 hours, and she needs to be fully rested to start."
    end
    local shown = false
    pcall(function()
        if ISModalDialog == nil then return end
        local sw, sh = 800, 600
        pcall(function()
            local c = getCore()
            if c ~= nil then sw, sh = c:getScreenWidth(), c:getScreenHeight() end
        end)
        local width, height = 480, 140
        pcall(function()
            local tm = getTextManager()
            local lines = math.ceil((tm:MeasureStringX(UIFont.Small, text) + 1) / (width - 60))
            if lines < 2 then lines = 2 end
            height = math.max(height, (lines + 1) * (tm:getFontHeight(UIFont.Small) + 2) + 40)
        end)
        local function ok(target, button)
            if button == nil or button.internal == "OK" then
                if onOk ~= nil then pcall(onOk) end
            end
        end
        local modal = ISModalDialog:new((sw - width) / 2, (sh - height) / 2, width, height, text, false, nil, ok)
        modal:initialise()
        modal:addToUIManager()
        modal.moveWithMouse = true
        if modal.setAlwaysOnTop ~= nil then modal:setAlwaysOnTop(true) end
        if modal.setCapture ~= nil then modal:setCapture(true) end
        shown = true
    end)
    log("exercise notice shown=" .. tostring(shown))
    if not shown and onOk ~= nil then pcall(onOk) end
end


local function hardBusy()
    if BridgeWash ~= nil and BridgeWash.state ~= nil and BridgeWash.state ~= "idle" then return true end
    if BridgeHeal ~= nil and BridgeHeal.active == true then return true end
    if BridgeFight ~= nil then
        if BridgeFight.target ~= nil then return true end
        if BridgeFight.state ~= nil and BridgeFight.state ~= "idle" then return true end
    end
    local inCar = false
    pcall(function()
        local body = Bridge.body
        if body ~= nil then inCar = (body:getVehicle() ~= nil) end
    end)
    return inCar
end
BridgeExercise.hardBusy = hardBusy


local function busyElsewhere()
    if BridgeTask ~= nil and BridgeTask.active then
        return BridgeTask.kind ~= "exercise"
    end
    if hardBusy() then return true end
    if Bridge ~= nil and Bridge.pose ~= nil then return true end
    if Bridge ~= nil and Bridge.mode == "rest" then return true end
    if BridgeTask ~= nil then
        if BridgeTask.isSitting ~= nil and BridgeTask.isSitting(Bridge.body) then return true end
        if BridgeTask.isLying ~= nil and BridgeTask.isLying(Bridge.body) then return true end
    end
    local sitting = false
    pcall(function()
        local body = Bridge.body
        if body ~= nil and tostring(body:getBumpType()) == "Sit" then sitting = true end
    end)
    return sitting
end
BridgeExercise.busy = busyElsewhere


function BridgeExercise.start(mirror)
    if BridgeTask == nil or BridgeTask.start == nil then return "no task" end
    if BridgeTask.active then
        if BridgeTask.kind == "exercise" then return "already" end
        return "busy"
    end
    if Bridge == nil or not Bridge.alive() then return "no body" end
    if Bridge.drivable ~= nil and not Bridge.drivable() then return "not drivable" end
    if hardBusy() then return "busy" end
    local ok, why = BridgeExercise.ready(Bridge.store)
    if not ok then return why end
    if BridgeTask.dangerNear ~= nil and BridgeTask.dangerNear(Bridge.body) then return "danger" end
    local def = BridgeTask.kinds ~= nil and BridgeTask.kinds.exercise or nil
    if def == nil or (def.available ~= nil and not def.available(Bridge.body)) then return "unavailable" end
    local res = BridgeTask.start("exercise", {})
    if res == "started" then
        BridgeTask.exerciseMirror = mirror == true
        log("start mirror=" .. tostring(mirror))
    end
    return res
end


function BridgeExercise.mirrorTick()
    if Bridge == nil or BridgeTask == nil then return end
    if Bridge.kind ~= "zombie" then return end
    if BridgeData == nil or BridgeData.optionOf == nil then return end
    if BridgeTask.active then return end
    if not Bridge.alive() then return end
    local body = Bridge.body
    if body == nil then return end
    local red = BridgeData.owner()
    if red == nil then return end


    local ex = nil
    pcall(function()
        local fit = red:getFitness()
        if fit ~= nil then ex = fit:getCurrentExe() end
    end)
    if ex == nil then
        BridgeExercise.watchSaid = nil
        BridgeExercise.restSaid = nil
        BridgeExercise.cheerAt = nil
        BridgeExercise.cheerIdx = nil
        return
    end


    local inRange = false
    pcall(function()
        local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
        inRange = (dx * dx + dy * dy) <= (BridgeExercise.RANGE * BridgeExercise.RANGE)
            and math.abs(red:getZ() - body:getZ()) < 0.9
    end)
    if not inRange then return end
    if busyElsewhere() then return end


    if not BridgeData.optionOf(Bridge.store, "exerciseWithMe") then
        if not BridgeExercise.watchSaid then
            BridgeExercise.watchSaid = true
            BridgeExercise.cheerAt = (Bridge.time or 0) + BridgeExercise.CHEER_TICKS
            Bridge.speak("ExerciseWatch")
            return
        end
        BridgeExercise.cheer()
        return
    end


    local ok, why = BridgeExercise.ready(Bridge.store)
    if not ok then
        if not BridgeExercise.restSaid then
            BridgeExercise.restSaid = true
            BridgeExercise.cheerAt = (Bridge.time or 0) + BridgeExercise.CHEER_TICKS
            Bridge.speak((why == "tired") and "ExerciseWinded" or "ExerciseRest")
            return
        end
        BridgeExercise.cheer()
        return
    end
    if (Bridge.time or 0) < (BridgeExercise.retryAt or 0) then return end


    if BridgeTask.dangerNear ~= nil and BridgeTask.dangerNear(body) then return end

    local res = BridgeExercise.start(true)
    if res ~= "started" then BridgeExercise.retryAt = (Bridge.time or 0) + 60 end
end


function BridgeExercise.readyTick()
    if Bridge == nil or BridgeTask == nil then return end
    if Bridge.kind ~= "zombie" then return end
    BridgeExercise.rollBankDay(Bridge.store)
    BridgeExercise.combatPoll()
    if not Bridge.alive() then return end
    local rec = Bridge.store
    if BridgeExercise.cooldownLeft(rec) > 0 then
        BridgeExercise.wasCooling = true
        return
    end
    if not BridgeExercise.wasCooling then return end
    if BridgeTask.active then return end
    if BridgeExercise.combatRecent() then return end
    local red = BridgeData.owner()
    if red == nil then return end
    local near = false
    pcall(function()
        local body = Bridge.body
        local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
        near = (dx * dx + dy * dy) <= (BridgeExercise.RANGE * BridgeExercise.RANGE)
            and math.abs(red:getZ() - body:getZ()) < 0.9
    end)
    if not near then return end
    if busyElsewhere() then return end
    BridgeExercise.wasCooling = false
    local idx = BridgeExercise.tierIndex(BridgeExercise.count(rec))
    Bridge.speak("ExerciseReady" .. (idx >= 4 and "3" or (idx >= 2 and "2" or "1")))
end


if type(Events) == "table" and Events.OnTick ~= nil then
    Events.OnTick.Add(function()
        if Bridge.every ~= nil and not Bridge.every(BridgeExercise.POLL_EVERY, BridgeExercise.POLL_PHASE) then return end
        pcall(BridgeExercise.readyTick)
        pcall(BridgeExercise.mirrorTick)
    end)
end

if type(Events) == "table" and Events.OnWeaponHitXp ~= nil then
    Events.OnWeaponHitXp.Add(function(plr)
        if plr == nil or BridgeData == nil or BridgeData.owner == nil then return end
        if plr == BridgeData.owner() then BridgeExercise.playerCombatAt = Bridge.time end
    end)
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeExercise] loaded") end
