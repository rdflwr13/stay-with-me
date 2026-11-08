BridgeHorse = BridgeHorse or {}
BridgeHorse.active = false
BridgeHorse.horse = nil
BridgeHorse.body = nil
BridgeHorse.player = nil
BridgeHorse.flags = nil
BridgeHorse.pending = nil
BridgeHorse.observedHorse = nil
BridgeHorse.installed = false
BridgeHorse.softDisabled = false
BridgeHorse.modules = nil
BridgeHorse.lastReconcileMs = 0
BridgeHorse.lastInstallMs = 0
BridgeHorse.requestedAt = 0
BridgeHorse.requestedFor = nil
BridgeHorse.turnSign = -1
BridgeHorse.marker = "BridgeHorsePassenger"

local RIDE_RANGE = 25
local RIDE_OFFSET = 0.26
local REQUEST_TIMEOUT_MS = 3000
local PENDING_WINDOW_MS = 10000
local PENDING_RETRY_MS = 1000
local RECONCILE_MS = 250
local INSTALL_RETRY_MS = 60000

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeHorse] " .. tostring(text)) end
end

local function safe(defaultValue, callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return defaultValue
end

local function living(object)
    if object == nil then return false end
    local dead = safe(false, function() return object:isDead() end)
    if dead then return false end
    return safe(true, function() return object:isAlive() end) ~= false
end

local function flatDistance(a, b)
    if a == nil or b == nil then return math.huge end
    local ax = tonumber(safe(nil, function() return a:getX() end))
    local ay = tonumber(safe(nil, function() return a:getY() end))
    local bx = tonumber(safe(nil, function() return b:getX() end))
    local by = tonumber(safe(nil, function() return b:getY() end))
    if ax == nil or ay == nil or bx == nil or by == nil then return math.huge end
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

local function modules()
    if BridgeHorse.modules ~= nil then return BridgeHorse.modules end
    local okMounts, mounts = pcall(require, "HorseMod/Mounts")
    local okAnim, anim = pcall(require, "HorseMod/definitions/AnimationVariable")
    local okDir, dir = pcall(require, "HorseMod/riding/MountedDirection")
    local okState, state = pcall(require, "HorseMod/riding/MountedAnimationState")
    local okCmd, cmds = pcall(require, "HorseMod/networking/commands")
    if not (okMounts and okAnim and okDir and okState and okCmd) then return nil end
    local m = { mounts = mounts, anim = anim, dir = dir, state = state, cmds = cmds }
    BridgeHorse.modules = m
    return m
end

local function riderBool(rider, name)
    if rider == nil then return false end
    return safe(false, function() return rider:getVariableBoolean(name) == true end)
end

local function riderFloat(rider, name)
    if rider == nil then return 0 end
    return tonumber(safe(0, function() return rider:getVariableFloat(name, 0) end)) or 0
end

local function horseBool(horse, name)
    if horse == nil then return false end
    return safe(false, function() return horse:getVariableBoolean(name) == true end)
end

local function horseFloat(horse, name)
    if horse == nil then return 0 end
    return tonumber(safe(0, function() return horse:getVariableFloat(name, 0) end)) or 0
end

local LOCK_FLAGS = {
    { "getIgnoreMovement", "setIgnoreMovement", true },
    { "isDeferredMovementEnabled", "setDeferredMovementEnabled", false },
    { "isCollidable", "setCollidable", false },
    { "isSolid", "setSolid", false },
}

local BOOLEAN_VARIABLES = {
    "HorseTrot", "HorseGallop", "HorseJump", "IdleToRun",
    "isTurningLeft", "isTurningRight", "isTurning",
    "animalWalking", "animalRunning", "HorseGalloping", "HorseMountedMoving",
    "walkstateRun", "bMoving", "isMoving", "pressedRunButton", "isRunning",
}

local FLOAT_VARIABLES = {
    "HorseGeneSpeed", "HorseWalkSpeed", "HorseTrotSpeed", "HorseRunSpeed", "mountedTwist",
}

local function applyLocks(body)
    if body == nil then return end
    for i = 1, #LOCK_FLAGS do
        local flag = LOCK_FLAGS[i]
        pcall(function() body[flag[2]](body, flag[3]) end)
    end
end

function BridgeHorse.captureLocks(body)
    local saved = {}
    if body == nil then return saved end
    for i = 1, #LOCK_FLAGS do
        local flag = LOCK_FLAGS[i]
        if body[flag[1]] and body[flag[2]] then
            local ok, value = pcall(function() return body[flag[1]](body) end)
            if ok then
                saved[#saved + 1] = { setter = flag[2], value = value }
                pcall(function() body[flag[2]](body, flag[3]) end)
            end
        end
    end
    return saved
end

local function restoreLocks(body, saved)
    if body == nil or saved == nil then return end
    for i = 1, #saved do
        local flag = saved[i]
        pcall(function() body[flag.setter](body, flag.value) end)
    end
end

local function placeBody(body, x, y, z)
    if body == nil then return end
    pcall(function() body:setForceX(x) end)
    pcall(function() body:setForceY(y) end)
    pcall(function() body:setX(x) end)
    pcall(function() body:setY(y) end)
    pcall(function() body:setZ(z) end)
    pcall(function() body:setLastX(x) end)
    pcall(function() body:setLastY(y) end)
    pcall(function() body:setLastZ(z) end)
    pcall(function() body:setNextX(x) end)
    pcall(function() body:setNextY(y) end)
    pcall(function() body:setCurrentSquareFromPosition() end)
    pcall(function()
        local sq = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z))
        if sq ~= nil then
            body:setSquare(sq)
            body:setCurrent(sq)
        end
    end)
    pcall(function() body:setMovingSquareNow() end)
end

local function clearAnimation(body)
    if body == nil then return end
    pcall(function() body:setVariable("BridgeHorsePassenger", false) end)
    pcall(function() body:setVariable("BridgeHorsePassengerGait", "") end)
    pcall(function() body:setVariable("BridgeHorsePassengerTurn", "") end)
    pcall(function() body:setVariable("HorseRiding", false) end)
    pcall(function() body:setVariable("HorseMountingHorse", false) end)
    pcall(function() body:setVariable("HorseDismountStarted", false) end)
    pcall(function() body:setVariable("HorseHasReins", false) end)
    for i = 1, #BOOLEAN_VARIABLES do
        pcall(function() body:setVariable(BOOLEAN_VARIABLES[i], false) end)
    end
    pcall(function() body:setVariable("mountedTwist", 0) end)
    pcall(function() body:setVariable("momentumScalar", 1) end)
end

local function landingSpot(horse)
    if horse == nil then return nil end
    local cell = getCell()
    if cell == nil then return nil end
    local square = safe(nil, function() return horse:getCurrentSquare() end)
    if square == nil then return nil end
    local hx = tonumber(safe(nil, function() return horse:getX() end))
    local hy = tonumber(safe(nil, function() return horse:getY() end))
    local hz = tonumber(safe(nil, function() return horse:getZ() end))
    if hx == nil or hy == nil or hz == nil then return nil end
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }
    for i = 1, #dirs do
        local tile = cell:getGridSquare(math.floor(hx) + dirs[i][1], math.floor(hy) + dirs[i][2], math.floor(hz))
        if tile ~= nil and tile:isFree(false) and tile:TreatAsSolidFloor()
            and not square:isBlockedTo(tile) and not tile:isBlockedTo(square) then
            return { x = tile:getX() + 0.5, y = tile:getY() + 0.5, z = math.floor(hz) }
        end
    end
    return nil
end

local function rescueVisibility(player, body, horse)
    if player == nil or body == nil or horse == nil then return false end
    if type(player.getPlayerNum) ~= "function" or type(horse.getCurrentSquare) ~= "function" then return false end
    local playerZ = tonumber(safe(nil, function() return player:getZ() end))
    local horseZ = tonumber(safe(nil, function() return horse:getZ() end))
    local horseX = tonumber(safe(nil, function() return horse:getX() end))
    local horseY = tonumber(safe(nil, function() return horse:getY() end))
    local playerX = tonumber(safe(nil, function() return player:getX() end))
    local playerY = tonumber(safe(nil, function() return player:getY() end))
    if playerZ == nil or horseZ == nil or horseX == nil or horseY == nil
        or playerX == nil or playerY == nil then return false end
    if math.floor(playerZ) ~= math.floor(horseZ) then return false end
    local dx, dy = horseX - playerX, horseY - playerY
    if dx * dx + dy * dy > 225 then return false end
    local playerIndex = safe(nil, function() return player:getPlayerNum() end)
    if playerIndex == nil then return false end
    local square = safe(nil, function() return horse:getCurrentSquare() end)
    if square == nil or type(square.isCanSee) ~= "function" then return false end
    if safe(false, function() return square:isCanSee(playerIndex) end) then return false end
    if LosUtil == nil or type(LosUtil.lineClearCollide) ~= "function" then return false end
    local blocked = safe(true, function()
        return LosUtil.lineClearCollide(math.floor(playerX), math.floor(playerY), math.floor(playerZ),
            math.floor(horseX), math.floor(horseY), math.floor(horseZ), false)
    end)
    if blocked then return false end
    pcall(function() body:setAlphaAndTarget(playerIndex, 1) end)
    pcall(function() horse:setAlphaAndTarget(playerIndex, 1) end)
    return true
end

local function animate(body, horse, rider)
    if body == nil or horse == nil then return end
    local gait = "idle"
    local gallop = rider ~= nil and riderBool(rider, "HorseGallop") or horseBool(horse, "HorseGallop")
    local trot = rider ~= nil and riderBool(rider, "HorseTrot") or horseBool(horse, "HorseTrot")
    local moving = rider ~= nil
        and (riderBool(rider, "HorseMountedMoving") or riderBool(rider, "animalWalking"))
        or (horseBool(horse, "HorseMountedMoving") or horseBool(horse, "animalWalking"))
    if gallop then
        gait = "gallop"
    elseif trot then
        gait = "trot"
    elseif moving then
        gait = "walk"
    end
    local twist = rider ~= nil and riderFloat(rider, "mountedTwist") or horseFloat(horse, "mountedTwist")
    local turn = "straight"
    if twist < -30 then
        turn = "left"
    elseif twist > 30 then
        turn = "right"
    end
    local turning = riderBool(rider, "isTurning") or horseBool(horse, "isTurning")
    local rideBump = "BridgeHorseRideIdle"
    if gait == "walk" then
        if turn == "left" then
            rideBump = "BridgeHorseRideWalkLeft"
        elseif turn == "right" then
            rideBump = "BridgeHorseRideWalkRight"
        else
            rideBump = "BridgeHorseRideWalk"
        end
    elseif gait == "trot" then
        if turn == "left" then
            rideBump = "BridgeHorseRideTrotLeft"
        elseif turn == "right" then
            rideBump = "BridgeHorseRideTrotRight"
        else
            rideBump = "BridgeHorseRideTrot"
        end
    elseif gait == "gallop" then
        if turn == "left" then
            rideBump = "BridgeHorseRideGallopLeft"
        elseif turn == "right" then
            rideBump = "BridgeHorseRideGallopRight"
        elseif turning then
            rideBump = "BridgeHorseRideGallopTurn"
        else
            rideBump = "BridgeHorseRideGallop"
        end
    end
    if gait == "gallop" and (riderBool(rider, "IdleToRun") or horseBool(horse, "IdleToRun")) then
        rideBump = "BridgeHorseRideIdleToGallop"
    end
    if riderBool(rider, "HorseHurt") or horseBool(horse, "HorseHurt") then
        rideBump = "BridgeHorseRideHit"
    end
    if riderBool(rider, "HorseDying") or horseBool(horse, "HorseDying") then
        rideBump = "BridgeHorseRideDying"
    end
    if riderBool(rider, "HorseFallBack") or horseBool(horse, "HorseFallBack") then
        rideBump = "BridgeHorseRideFallBack"
    end
    if riderBool(rider, "HorseJump") or horseBool(horse, "HorseJump") then
        rideBump = "BridgeHorseRideJump"
    end
    if BridgeHorse.rideBump ~= rideBump then
        BridgeHorse.rideBump = rideBump
        pcall(function() body:setVariable("BumpAnimFinished", false) end)
        pcall(function() body:setBumpType(rideBump) end)
    end
    pcall(function() body:setVariable("BridgeHorsePassenger", true) end)
    pcall(function() body:setVariable("BridgeHorsePassengerGait", gait) end)
    pcall(function() body:setVariable("BridgeHorsePassengerTurn", turn) end)
    pcall(function() body:setVariable("HorseRiding", true) end)
    pcall(function() body:setVariable("HorseMountingHorse", false) end)
    pcall(function() body:setVariable("HorseDismountStarted", false) end)
    pcall(function() body:setVariable("HorseHasReins", false) end)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        local stateName = safe("?", function() return body:getAnimationStateName() end)
        local trackName = safe("?", function() return body:dbgGetAnimTrackName(0, 0) end)
        local bumpType = safe("?", function() return body:getBumpType() end)
        if BridgeHorse.animLoggedState ~= stateName
            or BridgeHorse.animLoggedTrack ~= trackName
            or BridgeHorse.animLoggedBump ~= bumpType then
            BridgeHorse.animLoggedState = stateName
            BridgeHorse.animLoggedTrack = trackName
            BridgeHorse.animLoggedBump = bumpType
            local setName = safe("?", function() return body:GetAnimSetName() end)
            local passenger = safe(false, function() return body:getVariableBoolean("BridgeHorsePassenger") == true end)
            log("horse anim set=" .. tostring(setName) .. " state=" .. tostring(stateName)
                .. " bump=" .. tostring(bumpType) .. " track=" .. tostring(trackName)
                .. " passenger=" .. tostring(passenger) .. " dist=" .. tostring(flatDistance(body, horse)))
        end
    end
    for i = 1, #BOOLEAN_VARIABLES do
        local name = BOOLEAN_VARIABLES[i]
        local value = rider ~= nil and riderBool(rider, name) or horseBool(horse, name)
        pcall(function() body:setVariable(name, value) end)
    end
    pcall(function() body:setVariable("bMoving", false) end)
    pcall(function() body:setVariable("isMoving", false) end)
    pcall(function() body:setVariable("walkstateRun", false) end)
    for i = 1, #FLOAT_VARIABLES do
        local name = FLOAT_VARIABLES[i]
        local value = rider ~= nil and riderFloat(rider, name) or horseFloat(horse, name)
        pcall(function() body:setVariable(name, value) end)
    end
end

function BridgeHorse.pin(body, horse, player, remote)
    local m = modules()
    if m == nil or body == nil or horse == nil then return false end
    local logical = safe(nil, function() return m.dir.toRiderDirection(horse:getDir()) end)
    if logical == nil then return false end
    local angle = tonumber(safe(nil, function() return m.dir.getMovementAngle(horse, logical) end)) or 0
    local hx = tonumber(safe(nil, function() return horse:getX() end))
    local hy = tonumber(safe(nil, function() return horse:getY() end))
    local hz = tonumber(safe(nil, function() return horse:getZ() end))
    if hx == nil or hy == nil or hz == nil then return false end
    local x = hx - math.cos(angle) * RIDE_OFFSET
    local y = hy - math.sin(angle) * RIDE_OFFSET
    placeBody(body, x, y, hz)
    if not remote then
        pcall(function() body:setMoving(false) end)
        pcall(function() body:setRunning(false) end)
    end
    pcall(function() body:setSneaking(false) end)
    pcall(function() body:setVariable("momentumScalar", 1) end)
    pcall(function() body:setDir(logical) end)
    pcall(function() body:setTargetAndCurrentDirection(math.cos(angle), math.sin(angle)) end)
    if not remote then
        applyLocks(body)
        local now = getTimestampMs()
        if BridgeHorse.lastLandingAt == nil or now - BridgeHorse.lastLandingAt >= 250 then
            BridgeHorse.lastLandingAt = now
            local spot = landingSpot(horse)
            if spot ~= nil then BridgeHorse.lastLanding = spot end
        end
    end
    animate(body, horse, player)
    return true
end

function BridgeHorse.frame(body)
    if BridgeHorse.softDisabled then return false end
    if not BridgeHorse.active or BridgeHorse.body == nil or BridgeHorse.body ~= body then return false end
    if BridgeHorse.horse == nil then return false end
    if safe(false, function() return body:getVehicle() ~= nil end) then return false end
    return BridgeHorse.pin(body, BridgeHorse.horse, BridgeHorse.player) == true
end

function BridgeHorse.latePin(zombie)
    if not BridgeHorse.active or BridgeHorse.body == nil or BridgeHorse.body ~= zombie then return end
    if BridgeHorse.horse == nil then return end
    if safe(false, function() return zombie:getVehicle() ~= nil end) then return end
    BridgeHorse.pin(zombie, BridgeHorse.horse, BridgeHorse.player)
end

local function ensureLatePin()
    if BridgeHorse.latePinInstalled then return end
    BridgeHorse.latePinInstalled = true
    if Events ~= nil and Events.OnZombieUpdate ~= nil then
        Events.OnZombieUpdate.Add(function(zombie) BridgeHorse.latePin(zombie) end)
    end
end

function BridgeHorse.eligible(player, horse)
    if player == nil or horse == nil then return false, "no mount" end
    if BridgeData == nil or not BridgeData.horseRidingEnabled() then return false, "disabled" end
    if Bridge == nil then return false, "no bridge" end
    if type(Bridge.alive) ~= "function" or not Bridge.alive() then return false, "no body" end
    if Bridge.kind ~= "zombie" or Bridge.body == nil then return false, "not zombie" end
    if Bridge.mode ~= "follow" or Bridge.follow ~= true or Bridge.mourning ~= nil then return false, "not following" end
    if Bridge.store == nil or not BridgeData.wants(Bridge.store) then return false, "not wanted" end
    if Bridge.mp and (Bridge.gotData ~= true or Bridge.store == nil) then return false, "no data" end
    if Bridge.pose ~= nil or Bridge.target ~= nil or Bridge.hiddenSince ~= nil then return false, "busy pose" end
    if Bridge.parked or Bridge.sleepParked ~= nil or Bridge.claimParked ~= nil or Bridge.respawnAt ~= nil
        or Bridge.spawnAsked ~= nil or Bridge.leaveAt ~= nil or Bridge.stash ~= nil then return false, "parked" end
    if BridgeCar ~= nil and type(BridgeCar.busy) == "function" and BridgeCar.busy() then return false, "car busy" end
    if BridgeTask ~= nil and BridgeTask.active == true then return false, "task" end
    if BridgeHeal ~= nil and (BridgeHeal.active == true or BridgeHeal.current ~= nil) then return false, "heal" end
    if BridgeWash ~= nil and BridgeWash.state ~= nil and BridgeWash.state ~= "idle" then return false, "wash" end
    if BridgeFight ~= nil and (BridgeFight.state ~= "idle" or BridgeFight.target ~= nil) then return false, "fight" end
    local body = Bridge.body
    if not living(body) then return false, "body dead" end
    if safe(false, function() return body:isKnockedDown() end) then return false, "knocked down" end
    if safe(false, function() return body:isCrawling() end) then return false, "crawling" end
    if safe(false, function() return body:isProne() end) then return false, "prone" end
    if safe(false, function() return body:getVehicle() ~= nil end) then return false, "body in vehicle" end
    if safe(false, function() return player:getVehicle() ~= nil end) then return false, "player in vehicle" end
    local bz = tonumber(safe(nil, function() return body:getZ() end))
    local pz = tonumber(safe(nil, function() return player:getZ() end))
    if bz == nil or pz == nil then return false, "no position" end
    if math.abs(bz - pz) > 0.5 then return false, "different floor" end
    if flatDistance(body, player) > RIDE_RANGE then return false, "too far" end
    return true
end

function BridgeHorse.trySeat(player, horse)
    if BridgeHorse.active then return true end
    if player == nil or horse == nil then return false end
    local ok, why = BridgeHorse.eligible(player, horse)
    if not ok then
        if BridgeHorse.lastWhy ~= why then
            BridgeHorse.lastWhy = why
            log("horse seat skipped: " .. tostring(why))
        end
        return false
    end
    local m = modules()
    if m == nil then return false end
    if Bridge.mp then
        local now = getTimestampMs()
        if BridgeHorse.requestedFor ~= horse or (now - BridgeHorse.requestedAt) >= REQUEST_TIMEOUT_MS then
            local id = safe(nil, function() return m.cmds.getAnimalId(horse) end)
            if id == nil then return false end
            BridgeHorse.requestedFor = horse
            BridgeHorse.requestedAt = now
            pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "horse", { animal = id }) end)
            log("horse seat requested animal=" .. tostring(id))
        end
        return false
    end
    BridgeHorse.activate(player, horse, Bridge.body)
    return true
end

local function clearRideHands(body)
    if body == nil then return end
    local changed = false
    pcall(function()
        if BridgeGunfight ~= nil and BridgeGunfight.drawn == true
            and type(BridgeGunfight.stow) == "function" then
            BridgeGunfight.stow(body)
            changed = true
        end
    end)
    pcall(function()
        if BridgeWeapon ~= nil and type(BridgeWeapon.isOut) == "function"
            and BridgeWeapon.isOut(body) and type(BridgeWeapon.putAway) == "function" then
            BridgeWeapon.putAway(body)
            changed = true
        end
    end)
    local primary, secondary = nil, nil
    pcall(function()
        primary = body:getPrimaryHandItem()
        secondary = body:getSecondaryHandItem()
    end)
    if primary ~= nil or secondary ~= nil or changed then
        pcall(function() body:setPrimaryHandItem(nil) end)
        pcall(function() body:setSecondaryHandItem(nil) end)
        pcall(function() body:resetEquippedHandsModels() end)
    end
end

function BridgeHorse.activate(player, horse, body)
    if body == nil or horse == nil then return false end
    if BridgeHorse.active then BridgeHorse.release("reseat", false) end
    BridgeHorse.active = true
    BridgeHorse.horse = horse
    BridgeHorse.body = body
    BridgeHorse.player = player
    BridgeHorse.turnSign = -1
    BridgeHorse.rideBump = nil
    BridgeHorse.animLoggedState = nil
    BridgeHorse.animLoggedTrack = nil
    BridgeHorse.animLoggedBump = nil
    BridgeHorse.pending = nil
    BridgeHorse.requestedFor = nil
    BridgeHorse.requestedAt = 0
    clearRideHands(body)
    BridgeHorse.flags = BridgeHorse.captureLocks(body)
    BridgeHorse.lastLanding = nil
    BridgeHorse.lastLandingAt = 0
    ensureLatePin()
    Bridge.pose = nil
    Bridge.target = nil
    pcall(function() if body.stopMovement then body:stopMovement() end end)
    pcall(function() body:setMoving(false) end)
    pcall(function() body:setRunning(false) end)
    pcall(function() if BridgeMove ~= nil and type(BridgeMove.stopPath) == "function" then BridgeMove.stopPath(body) end end)
    pcall(function() if BridgeMove ~= nil and type(BridgeMove.reset) == "function" then BridgeMove.reset(body) end end)
    pcall(function() if BridgeTask ~= nil and type(BridgeTask.cancel) == "function" and BridgeTask.active then BridgeTask.cancel("horse") end end)
    pcall(function() if BridgeHeal ~= nil and type(BridgeHeal.stop) == "function" then BridgeHeal.stop("horse") end end)
    pcall(function() if BridgeWash ~= nil and type(BridgeWash.stop) == "function" then BridgeWash.stop("horse") end end)
    pcall(function() if BridgeQueue ~= nil and type(BridgeQueue.clear) == "function" then BridgeQueue.clear("horse") end end)
    pcall(function() if BridgeFight ~= nil and type(BridgeFight.reset) == "function" then BridgeFight.reset(body) end end)
    BridgeHorse.pin(body, horse, player)
    if type(Bridge.speak) == "function" then pcall(function() Bridge.speak("HorseMount") end) end
    log("horse passenger seated")
    return true
end

function BridgeHorse.release(reason, speak)
    local was = BridgeHorse.active
    local body = BridgeHorse.body
    local horse = BridgeHorse.horse
    BridgeHorse.active = false
    BridgeHorse.body = nil
    BridgeHorse.horse = nil
    BridgeHorse.player = nil
    BridgeHorse.pending = nil
    BridgeHorse.requestedFor = nil
    BridgeHorse.requestedAt = 0
    if not was then return false end
    local spot = nil
    local red = nil
    pcall(function() red = BridgeData.owner() end)
    local redInCar = false
    if red ~= nil then pcall(function() redInCar = red:getVehicle() ~= nil end) end
    if red ~= nil and living(red) and not redInCar then
        local rx, ry, rz = 0, 0, 0
        pcall(function() rx, ry, rz = red:getX(), red:getY(), red:getZ() end)
        if horse == nil or math.abs(rz - horse:getZ()) <= 0.5 then
            local sx, sy, sz = nil, nil, nil
            pcall(function()
                if Bridge ~= nil and type(Bridge.spawnSpot) == "function" then
                    sx, sy, sz = Bridge.spawnSpot(math.floor(rx), math.floor(ry), math.floor(rz), true)
                end
            end)
            if sx ~= nil then
                local sq = nil
                pcall(function() sq = getCell():getGridSquare(sx, sy, sz) end)
                if sq ~= nil and sq:TreatAsSolidFloor() and sq:isFree(false) then
                    spot = { x = sx + 0.5, y = sy + 0.5, z = sz }
                end
            end
        end
    end
    if spot == nil and horse ~= nil then spot = landingSpot(horse) end
    if spot == nil then
        spot = BridgeHorse.lastLanding
        if spot ~= nil and horse ~= nil then
            local dx, dy = spot.x - horse:getX(), spot.y - horse:getY()
            if dx * dx + dy * dy > 16 then spot = nil end
        end
    end
    if spot ~= nil and body ~= nil and living(body) then
        local tile = nil
        pcall(function()
            tile = getCell():getGridSquare(math.floor(spot.x), math.floor(spot.y), math.floor(spot.z))
        end)
        if tile ~= nil and tile:isFree(false) and tile:TreatAsSolidFloor() then
            placeBody(body, spot.x, spot.y, spot.z)
        else
            spot = nil
        end
    end
    if spot == nil then
        log("horse release: no landing tile, keeping current position")
    end
    if body ~= nil then
        clearAnimation(body)
        restoreLocks(body, BridgeHorse.flags)
        pcall(function() body:setVariable("BumpAnimFinished", true) end)
        pcall(function() body:setBumpType("") end)
        pcall(function() if IdleState ~= nil then body:changeState(IdleState.instance()) end end)
    end
    BridgeHorse.flags = nil
    BridgeHorse.rideBump = nil
    BridgeHorse.lastLanding = nil
    if Bridge ~= nil then
        Bridge.pose = nil
        Bridge.target = nil
    end
    pcall(function() if BridgeMove ~= nil and type(BridgeMove.reset) == "function" then BridgeMove.reset(body) end end)
    pcall(function() if BridgeFight ~= nil and type(BridgeFight.reset) == "function" then BridgeFight.reset(body) end end)
    pcall(function() if BridgeTask ~= nil and type(BridgeTask.cancel) == "function" and BridgeTask.active then BridgeTask.cancel("horse") end end)
    pcall(function() if BridgeHeal ~= nil and type(BridgeHeal.stop) == "function" then BridgeHeal.stop("horse") end end)
    pcall(function() if BridgeWash ~= nil and type(BridgeWash.stop) == "function" then BridgeWash.stop("horse") end end)
    pcall(function() if BridgeQueue ~= nil and type(BridgeQueue.clear) == "function" then BridgeQueue.clear("horse") end end)
    if Bridge ~= nil and Bridge.mp then
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "horse", { release = true }) end)
    end
    if speak and Bridge ~= nil and type(Bridge.speak) == "function" then
        pcall(function() Bridge.speak("HorseDismount") end)
    end
    log("horse passenger released: " .. tostring(reason))
    return true
end

function BridgeHorse.onServerState(args)
    if BridgeHorse.softDisabled then return end
    if type(args) ~= "table" then return end
    if args.ok == true then
        if BridgeHorse.pending == nil then return end
        local m = modules()
        if m == nil then return end
        local horse = safe(nil, function() return m.cmds.getAnimal(args.h) end)
        local player = getSpecificPlayer(0)
        local body = nil
        if Bridge.body ~= nil and safe(nil, function() return Bridge.body:getPersistentOutfitID() end) == args.b then
            body = Bridge.body
        end
        if body == nil then
            for z, info in pairs(Bridge.bodiesSeen()) do
                if info.rec ~= nil and info.rec.bodyId == args.b then body = z break end
            end
        end
        if horse == nil or body == nil or player == nil then
            BridgeHorse.pending = nil
            BridgeHorse.requestedFor = nil
            log("horse seat ack could not resolve")
            return
        end
        BridgeHorse.activate(player, horse, body)
        return
    end
    if args.ok == false then
        BridgeHorse.pending = nil
        BridgeHorse.requestedFor = nil
        BridgeHorse.requestedAt = 0
        log("horse seat rejected: " .. tostring(args.why))
    end
end

function BridgeHorse.pinRemote(body, rec, who)
    if BridgeHorse.softDisabled then return false end
    if body == nil or type(rec) ~= "table" or type(rec.horse) ~= "table" then return false end
    local m = modules()
    if m == nil then return false end
    local horse = safe(nil, function() return m.cmds.getAnimal(rec.horse.h) end)
    if horse == nil then return false end
    return BridgeHorse.pin(body, horse, nil, true)
end

function BridgeHorse.blocksFollow()
    return BridgeHorse.active == true or BridgeHorse.pending ~= nil
end

function BridgeHorse.isPassenger(zombie)
    return BridgeHorse.active == true and zombie ~= nil and zombie == BridgeHorse.body
end

local function findBody(seen, pid)
    for z, info in pairs(seen) do
        if info.rec ~= nil and info.rec.bodyId == pid then return z end
        local zp = safe(nil, function() return z:getPersistentOutfitID() end)
        if zp == pid then return z end
    end
    return nil
end

function BridgeHorse.renderTick()
    local player = getSpecificPlayer(0)
    if BridgeHorse.active and player ~= nil and BridgeHorse.body ~= nil and BridgeHorse.horse ~= nil then
        rescueVisibility(player, BridgeHorse.body, BridgeHorse.horse)
    end
    if Bridge == nil or not Bridge.mp or Bridge.world == nil or Bridge.world.players == nil then
        if BridgeHorse.remotePinned ~= nil then
            for body in pairs(BridgeHorse.remotePinned) do clearAnimation(body) end
            BridgeHorse.remotePinned = nil
        end
        return
    end
    if Bridge.body == nil and Bridge.gotData ~= true then return end
    local me = BridgeData.me()
    local seen = Bridge.bodiesSeen()
    local pinnedNow = {}
    for who, rec in pairs(Bridge.world.players) do
        if who ~= me and type(rec) == "table" and type(rec.horse) == "table" then
            local pid = rec.horse.b
            if pid ~= nil then
                local body = findBody(seen, pid)
                if body ~= nil and not (BridgeSeatPuppet ~= nil and type(BridgeSeatPuppet.is) == "function"
                        and BridgeSeatPuppet.is(body)) then
                    if BridgeHorse.pinRemote(body, rec, who) then pinnedNow[body] = true end
                end
            end
        end
    end
    if BridgeHorse.remotePinned ~= nil then
        for body in pairs(BridgeHorse.remotePinned) do
            if not pinnedNow[body] then clearAnimation(body) end
        end
    end
    BridgeHorse.remotePinned = pinnedNow
end

function BridgeHorse.tick()
    if BridgeHorse.softDisabled then return end
    if not BridgeHorse.installed then
        local now = getTimestampMs()
        if now - (BridgeHorse.lastInstallMs or 0) >= INSTALL_RETRY_MS then
            BridgeHorse.lastInstallMs = now
            BridgeHorse.install()
        end
        if not BridgeHorse.installed then return end
    end
    if BridgeHorseSlowdown ~= nil and type(BridgeHorseSlowdown.install) == "function" then
        pcall(BridgeHorseSlowdown.install)
    end
    local m = modules()
    if m == nil or Bridge == nil then return end
    local player = getSpecificPlayer(0)
    if player == nil then return end
    local now = getTimestampMs()
    if now - (BridgeHorse.lastReconcileMs or 0) >= RECONCILE_MS then
        BridgeHorse.lastReconcileMs = now
        local horse = safe(nil, function() return m.mounts.getMount(player) end)
        if horse ~= BridgeHorse.observedHorse then
            if horse == nil and BridgeHorse.observedHorse ~= nil then
                BridgeHorse.observedHorse = nil
                BridgeHorse.pending = nil
                if BridgeHorse.active then BridgeHorse.release("unmounted", false) end
            elseif horse ~= nil then
                BridgeHorse.observedHorse = horse
                if not BridgeHorse.active and BridgeHorse.pending == nil then
                    BridgeHorse.pending = { player = player, horse = horse,
                        untilMs = now + PENDING_WINDOW_MS, nextTryMs = 0 }
                end
            end
        end
    end
    local pending = BridgeHorse.pending
    if pending ~= nil then
        if BridgeHorse.active then
            BridgeHorse.pending = nil
        elseif now >= pending.untilMs then
            BridgeHorse.pending = nil
            log("horse seat window ended")
        elseif BridgeHorse.requestedFor ~= nil and Bridge.mp
            and (now - BridgeHorse.requestedAt) >= REQUEST_TIMEOUT_MS then
            BridgeHorse.pending = nil
            BridgeHorse.requestedFor = nil
            BridgeHorse.requestedAt = 0
            log("horse seat request timed out")
        elseif now >= pending.nextTryMs then
            pending.nextTryMs = now + PENDING_RETRY_MS
            local horse = safe(nil, function() return m.mounts.getMount(player) end)
            if horse == nil or horse ~= pending.horse then
                BridgeHorse.pending = nil
            else
                BridgeHorse.trySeat(player, horse)
            end
        end
    end
    if not BridgeHorse.active then return end
    local body = BridgeHorse.body
    local horse = BridgeHorse.observedHorse or BridgeHorse.horse
    if body == nil or type(Bridge.alive) ~= "function" or not Bridge.alive() or Bridge.body ~= body then
        BridgeHorse.release("body lost", false)
        return
    end
    if BridgeData == nil or not BridgeData.horseRidingEnabled() then
        BridgeHorse.release("disabled", false)
        return
    end
    if horse == nil or not living(horse) then
        BridgeHorse.release("horse lost", false)
        return
    end
    if safe(false, function() return player:getVehicle() ~= nil end) then
        BridgeHorse.release("car", false)
        return
    end
    local jumping = false
    pcall(function() jumping = horse:getVariableBoolean("HorseJump") == true end)
    if flatDistance(body, horse) > 8 and not jumping then
        BridgeHorse.release("too far", false)
        return
    end
    BridgeHorse.pin(body, horse, player)
end

function BridgeHorse.status()
    return string.format("horse active=%s pending=%s body=%s horse=%s installed=%s",
        tostring(BridgeHorse.active), tostring(BridgeHorse.pending ~= nil),
        tostring(BridgeHorse.body ~= nil), tostring(BridgeHorse.horse ~= nil),
        tostring(BridgeHorse.installed))
end

local function onMount(player, animal)
    if not BridgeHorse.installed then return end
    if player ~= getSpecificPlayer(0) then return end
    if animal == nil then return end
    if BridgeHorse.observedHorse == animal and (BridgeHorse.active or BridgeHorse.pending ~= nil) then return end
    BridgeHorse.observedHorse = animal
    if BridgeData == nil or not BridgeData.horseRidingEnabled() then return end
    if BridgeHorse.active then BridgeHorse.release("mount", false) end
    BridgeHorse.pending = { player = player, horse = animal,
        untilMs = getTimestampMs() + PENDING_WINDOW_MS, nextTryMs = 0 }
    BridgeHorse.trySeat(player, animal)
end

local function onDismount(player, animal)
    if not BridgeHorse.installed then return end
    if player ~= getSpecificPlayer(0) then return end
    BridgeHorse.observedHorse = nil
    BridgeHorse.pending = nil
    BridgeHorse.requestedFor = nil
    BridgeHorse.requestedAt = 0
    if BridgeHorse.active then BridgeHorse.release("dismount", true) end
end

function BridgeHorse.install()
    if BridgeHorse.installed then return true end
    if BridgeHorse.softDisabled then return false end
    if BridgeData ~= nil and type(BridgeData.horseModActive) == "function" then
        local active = BridgeData.horseModActive()
        if not active and getActivatedMods ~= nil then
            BridgeHorse.softDisabled = true
            return false
        end
    end
    local m = modules()
    if m == nil then return false end
    if type(m.mounts.onMount) ~= "table" or type(m.mounts.onMount.add) ~= "function" then return false end
    if type(m.mounts.onDismount) ~= "table" or type(m.mounts.onDismount.add) ~= "function" then return false end
    m.mounts.onMount:add(onMount)
    m.mounts.onDismount:add(onDismount)
    if not BridgeHorse.renderInstalled and Events ~= nil and Events.OnRenderTick ~= nil then
        BridgeHorse.renderInstalled = true
        Events.OnRenderTick.Add(function() pcall(BridgeHorse.renderTick) end)
    end
    BridgeHorse.installed = true
    log("horse rider installed")
    return true
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function()
        if BridgeHorse.active then BridgeHorse.release("game start", false) end
        BridgeHorse.observedHorse = nil
        BridgeHorse.pending = nil
        BridgeHorse.lastReconcileMs = 0
        pcall(BridgeHorse.install)
    end)
end

pcall(BridgeHorse.install)
