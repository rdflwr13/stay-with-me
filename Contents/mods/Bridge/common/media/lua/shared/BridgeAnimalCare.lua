BridgeAnimalCare = BridgeAnimalCare or {}

local SECOND = 60
local REACH = 1.45
local POSE_TICKS = 180
local POSE_TIMEOUT = 300
local MOVE_DIST = 2
local MOVE_LIMIT = 6
local COOLDOWN_HOURS = 0.1
local XP_MIN, XP_MAX = 5, 10
local MAX_TARGETS = 10
local MAX_SIDE = 40
local PENDING_TIMEOUT = 20 * SECOND

local function sqOf(a)
    local sq = nil
    pcall(function() sq = a:getCurrentSquare() end)
    return sq
end

local function hasMod(a)
    local yes = false
    pcall(function() yes = a:hasModData() == true end)
    return yes
end

local function animalName(a)
    local nm = nil
    pcall(function() nm = a:getFullName() end)
    if type(nm) ~= "string" or nm == "" then return "the animal" end
    return nm
end

local function speak(key, a)
    if Bridge ~= nil and Bridge.speak ~= nil then pcall(Bridge.speak, key, a) end
end

local function addPetXp()
    if BridgeSkills ~= nil and type(BridgeSkills.add) == "function" then
        pcall(BridgeSkills.add, "Husbandry", ZombRand(XP_MIN, XP_MAX + 1), "animalcare.pet")
    end
end

function BridgeAnimalCare.isTended(a)
    if a == nil then return false end
    local dead = false
    pcall(function() dead = a:isDead() == true end)
    if dead then return false end
    local exists = true
    pcall(function() exists = a:isExistInTheWorld() ~= false end)
    if not exists then return false end
    if sqOf(a) == nil then return false end
    local wild = false
    pcall(function() wild = a:isWild() == true end)
    if wild then return false end
    local companion = false
    pcall(function() companion = hasMod(a) and a:getModData().CompanionDogs ~= nil end)
    if companion then return false end
    local held, hook = false, false
    pcall(function() held = a:isHeld() == true end)
    if held then return false end
    local vehicle = nil
    pcall(function() vehicle = a:getVehicle() end)
    if vehicle ~= nil then return false end
    local hutch = nil
    pcall(function() hutch = a:getHutch() end)
    if hutch ~= nil then return false end
    pcall(function() hook = a:isOnHook() == true end)
    if hook then return false end
    local attachedPlayer, attachedTree = nil, nil
    pcall(function()
        local d = a:getData()
        if d ~= nil then
            attachedPlayer = d:getAttachedPlayer()
            attachedTree = d:getAttachedTree()
        end
    end)
    if attachedPlayer ~= nil or attachedTree ~= nil then return false end
    return true
end

function BridgeAnimalCare.cooldownLeft(a)
    if a == nil then return 0 end
    local last = nil
    pcall(function()
        if hasMod(a) then last = tonumber(a:getModData().BridgeLastPet) end
    end)
    if last == nil then return 0 end
    local now = nil
    pcall(function() now = getGameTime():getWorldAgeHours() end)
    now = tonumber(now)
    if now == nil then return 0 end
    return math.max(0, (last + COOLDOWN_HOURS) - now)
end

function BridgeAnimalCare.notePet(a)
    if a == nil then return end
    local now = nil
    pcall(function() now = getGameTime():getWorldAgeHours() end)
    now = tonumber(now)
    if now == nil then return end
    pcall(function() a:getModData().BridgeLastPet = now end)
end

function BridgeAnimalCare.canPet(a)
    if not BridgeAnimalCare.isTended(a) then return false end
    local can, done = false, false
    pcall(function() can = a:canBePet() == true end)
    pcall(function() done = a:petTimerDone() == true end)
    return can and done and BridgeAnimalCare.cooldownLeft(a) <= 0
end

function BridgeAnimalCare.refOf(a)
    if a == nil then return nil end
    local x, y, z = 0, 0, 0
    local onlineID, animalID = nil, nil
    pcall(function() x, y, z = a:getX(), a:getY(), a:getZ() end)
    pcall(function() onlineID = a:getOnlineID() end)
    pcall(function() animalID = a:getAnimalID() end)
    return {
        obj = a,
        onlineID = onlineID,
        animalID = animalID,
        x = math.floor(x),
        y = math.floor(y),
        z = math.floor(z),
        fx = x,
        fy = y,
    }
end

function BridgeAnimalCare.resolve(ref)
    if type(ref) ~= "table" then return nil end
    local obj = ref.obj
    if obj ~= nil and BridgeAnimalCare.isTended(obj) then return obj end
    if ref.onlineID == nil and ref.animalID == nil then return nil end
    local match, count = nil, 0
    pcall(function()
        local cell = getCell()
        if cell == nil then return end
        local list = cell:getAnimals()
        if list == nil then return end
        local n = 0
        pcall(function() n = list:size() end)
        for i = 0, n - 1 do
            local a = nil
            pcall(function() a = list:get(i) end)
            if a ~= nil then
                local oid, aid = nil, nil
                pcall(function() oid = a:getOnlineID() end)
                pcall(function() aid = a:getAnimalID() end)
                local ok = true
                if ref.onlineID ~= nil and oid ~= ref.onlineID then ok = false end
                if ref.animalID ~= nil and aid ~= ref.animalID then ok = false end
                if ok then
                    count = count + 1
                    match = a
                end
            end
        end
    end)
    if count == 1 then return match end
    return nil
end

function BridgeAnimalCare.poseFor(a)
    local t = nil
    pcall(function() t = a:getAnimalType() end)
    t = string.lower(tostring(t or ""))
    if t == "cow" then return "NA_PetCow" end
    if t == "bull" then return "NA_PetBull" end
    if t == "cowcalf" or t == "calf" then return "NA_PetCalf" end
    if t == "sow" or t == "boar" or t == "pig" then return "NA_PetPig" end
    if t == "piglet" then return "NA_PetPiglet" end
    if t == "ewe" then return "NA_PetSheep" end
    if t == "ram" then return "NA_PetRam" end
    if t == "lamb" then return "NA_PetLamb" end
    if t == "hen" or t == "cockerel" or t == "rooster" or t == "chicken"
            or t == "turkeyhen" or t == "gobblers" or t == "turkey" then
        return "NA_PetChicken"
    end
    if t == "chick" or t == "turkeypoult" or t == "mouse" or t == "mousefemale"
            or t == "mousepups" or t == "rat" or t == "ratfemale" or t == "ratbaby" then
        return "NA_PetSmall"
    end
    if t == "rabkitten" or t == "rabdoe" or t == "rabbuck" or t == "raccoonkit"
            or t == "raccoonsow" or t == "raccoonboar" then
        return "NA_PetPiglet"
    end
    return "NA_PetMedium"
end

function BridgeAnimalCare.clearPose(body)
    if body == nil then return end
    local bump = ""
    pcall(function() bump = tostring(body:getBumpType()) end)
    if string.sub(bump, 1, 6) ~= "NA_Pet" then return end
    pcall(function() body:setVariable("BumpAnimFinished", true) end)
    pcall(function()
        if ZombieIdleState ~= nil and ZombieIdleState.instance ~= nil then
            body:changeState(ZombieIdleState.instance())
        end
    end)
    pcall(function() body:setBumpType("") end)
end

function BridgeAnimalCare.targetsIn(b, cap)
    local out = {}
    if type(b) ~= "table" then return out end
    cap = tonumber(cap) or MAX_TARGETS
    local cell = nil
    pcall(function() cell = getCell() end)
    if cell == nil then return out end
    local list = nil
    pcall(function() list = cell:getAnimals() end)
    if list == nil then return out end
    local n = 0
    pcall(function() n = list:size() end)
    for i = 0, n - 1 do
        if #out >= cap then break end
        local a = nil
        pcall(function() a = list:get(i) end)
        if a ~= nil and BridgeAnimalCare.canPet(a) then
            local sq = sqOf(a)
            if sq ~= nil then
                local ax, ay, az = sq:getX(), sq:getY(), sq:getZ()
                if ax >= b.x1 and ax <= b.x2 and ay >= b.y1 and ay <= b.y2
                        and math.abs(az - b.z) < 1 then
                    local fx, fy = ax, ay
                    pcall(function() fx, fy = a:getX(), a:getY() end)
                    out[#out + 1] = {
                        x = ax,
                        y = ay,
                        z = math.floor(az),
                        animal = a,
                        ref = BridgeAnimalCare.refOf(a),
                        fx = fx,
                        fy = fy,
                    }
                end
            end
        end
    end
    return out
end

function BridgeAnimalCare.targetFor(a)
    if not BridgeAnimalCare.canPet(a) then return nil end
    local sq = sqOf(a)
    if sq == nil then return nil end
    local fx, fy = sq:getX(), sq:getY()
    pcall(function() fx, fy = a:getX(), a:getY() end)
    return {
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
        animal = a,
        ref = BridgeAnimalCare.refOf(a),
        fx = fx,
        fy = fy,
    }
end

local function clearHands(body)
    if body == nil then return end
    pcall(function() body:setPrimaryHandItem(nil) end)
    pcall(function() body:setSecondaryHandItem(nil) end)
    pcall(function() body:resetModelNextFrame() end)
    pcall(function()
        if BridgeInventory ~= nil and BridgeInventory.redress ~= nil then
            BridgeInventory.redress(body)
        end
    end)
end

local function blockAnimal(a, on)
    if a == nil then return end
    pcall(function()
        local behavior = a:getBehavior()
        if behavior ~= nil and behavior.setBlockMovement ~= nil then
            behavior:setBlockMovement(on == true)
        end
    end)
end

local function clearIdleAction(a)
    if a == nil then return end
    local v = nil
    pcall(function() v = a:getVariableString("idleAction") end)
    if v == "petting" then pcall(function() a:clearVariable("idleAction") end) end
end

local function faceAnimal(body, a)
    if body == nil or a == nil then return end
    local ax, ay = nil, nil
    pcall(function() ax, ay = a:getX(), a:getY() end)
    if ax ~= nil and ay ~= nil then
        pcall(function() body:faceLocationF(ax, ay) end)
    end
    pcall(function() a:faceThisObject(body) end)
    local bx, by = nil, nil
    pcall(function() bx, by = body:getX(), body:getY() end)
    if bx ~= nil and by ~= nil then
        pcall(function() a:faceLocation(bx, by) end)
    end
end

local function finishPose(a, body)
    local b = body
    if b == nil and Bridge ~= nil then b = Bridge.body end
    BridgeAnimalCare.clearPose(b)
    clearIdleAction(a)
    blockAnimal(a, false)
    if BridgeTask ~= nil then
        BridgeTask.petHeld = nil
        BridgeTask.petPending = nil
        BridgeTask.petPendingAt = nil
        BridgeTask.petStart = nil
        BridgeTask.petTicks = nil
    end
end

local function beginPose(body, a)
    faceAnimal(body, a)
    clearHands(body)
    blockAnimal(a, true)
    pcall(function() a:setVariable("idleAction", "petting") end)
    pcall(function() body:setVariable("BumpAnimFinished", false) end)
    local pose = BridgeAnimalCare.poseFor(a)
    pcall(function() body:setBumpType(pose) end)
    if BridgeTask ~= nil then
        BridgeTask.phase = "pose"
        BridgeTask.petStart = Bridge.time
        BridgeTask.petTicks = POSE_TICKS
        BridgeTask.petHeld = a
        if BridgeTask.petSaid ~= true then
            BridgeTask.petSaid = true
            local line = 1
            pcall(function() line = ZombRand(1, 4) end)
            if line < 1 or line > 3 then line = 1 end
            if line == BridgeTask.petLastLine then line = line % 3 + 1 end
            BridgeTask.petLastLine = line
            local key = "JobPet"
            if line == 2 then key = "JobPet2" elseif line == 3 then key = "JobPet3" end
            speak(key, animalName(a))
        end
    end
end

local function requestPet(a)
    if Bridge == nil or Bridge.mp ~= true then return false end
    if BridgeTask == nil then return false end
    local red = nil
    if BridgeData ~= nil and BridgeData.owner ~= nil then red = BridgeData.owner() end
    if red == nil then return false end
    local id = nil
    pcall(function() id = a:getOnlineID() end)
    if id == nil then return false end
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = a:getX(), a:getY(), a:getZ() end)
    if x == nil or y == nil or z == nil then return false end
    BridgeTask.petPending = { id = id, animal = a }
    BridgeTask.petPendingAt = Bridge.time
    local ok = pcall(function()
        sendClientCommand(red, "Bridge", "petAnimals", { id = id, x = x, y = y, z = z })
    end)
    if not ok then
        BridgeTask.petPending = nil
        BridgeTask.petPendingAt = nil
        return false
    end
    return true
end

local function applyPet(a, body)
    if a == nil then return false end
    if Bridge ~= nil and Bridge.mp == true then return requestPet(a) end
    local red = nil
    if BridgeData ~= nil and BridgeData.owner ~= nil then red = BridgeData.owner() end
    if red == nil then return false end
    local fn = a.petAnimal
    if fn == nil then return false end
    local ok = pcall(fn, a, red)
    if not ok then return false end
    BridgeAnimalCare.notePet(a)
    addPetXp()
    if BridgeTask ~= nil and BridgeTask.markDone ~= nil then BridgeTask.markDone() end
    return true
end

function BridgeAnimalCare.onPetResult(args)
    if BridgeTask == nil or not BridgeTask.active or BridgeTask.kind ~= "petAnimals" then return end
    local pending = BridgeTask.petPending
    if pending == nil then return end
    if args == nil or tostring(args.id) ~= tostring(pending.id) then return end
    local a = pending.animal
    BridgeTask.petPending = nil
    BridgeTask.petPendingAt = nil
    local body = nil
    if Bridge ~= nil then body = Bridge.body end
    if args.ok == true then
        BridgeAnimalCare.notePet(a)
        addPetXp()
        if BridgeTask.markDone ~= nil then BridgeTask.markDone() end
        if BridgeTask.phase ~= "pose" or BridgeTask.petHeld == nil then
            finishPose(a, body)
            BridgeTask.current = nil
            BridgeTask.phase = nil
            BridgeTask.resetWalkDest()
        end
        return
    end
    local why = tostring(args.why or "")
    if (why == "far" or why == "nobody") and BridgeTask.current ~= nil then
        BridgeTask.petFarRetries = (BridgeTask.petFarRetries or 0) + 1
        if BridgeTask.petFarRetries <= 2 then
            finishPose(a, body)
            local target = BridgeTask.current
            local sq = sqOf(a)
            if sq ~= nil then
                target.x, target.y, target.z = sq:getX(), sq:getY(), sq:getZ()
            end
            pcall(function() target.fx, target.fy = a:getX(), a:getY() end)
            BridgeTask.phase = "walk"
            BridgeTask.petRetryTarget = nil
            BridgeTask.petRetargets = 0
            BridgeTask.resetWalkDest()
            BridgeTask.info = "pet retry"
            return
        end
    end
    if BridgeTask.petFailSaid ~= true then
        BridgeTask.petFailSaid = true
        if why == "notready" then speak("JobPetNotReady", animalName(a)) else speak("JobPetNoReach") end
    end
    finishPose(a, body)
    BridgeTask.current = nil
    BridgeTask.phase = nil
    BridgeTask.resetWalkDest()
end

local function petPendingWait()
    if BridgeTask == nil then return false end
    local pending = BridgeTask.petPending
    if pending == nil then return false end
    local started = BridgeTask.petPendingAt or Bridge.time
    if Bridge.time - started > PENDING_TIMEOUT then
        local a = pending.animal
        local body = nil
        if Bridge ~= nil then body = Bridge.body end
        finishPose(a, body)
        BridgeTask.current = nil
        BridgeTask.phase = nil
        BridgeTask.resetWalkDest()
        if BridgeTask.petFailSaid ~= true then
            BridgeTask.petFailSaid = true
            speak("JobPetNoReach")
        end
    end
    return true
end

local function leave(body)
    if BridgeTask == nil then return end
    finishPose(BridgeTask.petHeld, body)
    BridgeTask.petRetargets = nil
    BridgeTask.petRetryTarget = nil
    BridgeTask.petFarRetries = nil
    BridgeTask.petSaid = nil
    BridgeTask.petLastLine = nil
    BridgeTask.petFailSaid = nil
    BridgeTask.petIdSeq = nil
end

local function dropWithSpeech(body, reason)
    local a = BridgeTask.petHeld
    finishPose(a, body)
    BridgeTask.current = nil
    BridgeTask.phase = nil
    BridgeTask.resetWalkDest()
    BridgeTask.spokeUnreachable = true
    local res = BridgeTask.dropTarget(reason)
    if BridgeTask.petFailSaid ~= true then
        BridgeTask.petFailSaid = true
        speak("JobPetNoReach")
    end
    return res
end

local function jobUpdate(body)
    if BridgeTask == nil then return false end
    if BridgeTask.PET_ANIMALS_ENABLED ~= 1 then return BridgeTask.finish() end
    if BridgeTask.petPending ~= nil then
        petPendingWait()
        return true
    end

    local target = BridgeTask.current
    if target == nil then
        local picked = nil
        while #BridgeTask.queue > 0 do
            local t = table.remove(BridgeTask.queue, 1)
            if type(t) == "table" and t.animal ~= nil and BridgeAnimalCare.canPet(t.animal) then
                picked = t
                break
            end
        end
        if picked == nil then return BridgeTask.finish() end
        BridgeTask.current = picked
        BridgeTask.phase = "walk"
        BridgeTask.petSaid = nil
        BridgeTask.petRetryTarget = nil
        BridgeTask.petRetargets = 0
        BridgeTask.petFarRetries = 0
        BridgeTask.resetWalkDest()
        target = picked
    end

    local a = target.animal
    if a == nil or not BridgeAnimalCare.isTended(a) then
        a = BridgeAnimalCare.resolve(target.ref)
        if a ~= nil then
            target.animal = a
            local sq = sqOf(a)
            if sq ~= nil then
                target.x, target.y, target.z = sq:getX(), sq:getY(), sq:getZ()
            end
            pcall(function() target.fx, target.fy = a:getX(), a:getY() end)
        end
    end
    if a == nil or not BridgeAnimalCare.isTended(a) then
        BridgeTask.current = nil
        BridgeTask.phase = nil
        BridgeTask.resetWalkDest()
        return true
    end

    local moved = false
    if target.fx ~= nil and target.fy ~= nil then
        local ax, ay = nil, nil
        pcall(function() ax, ay = a:getX(), a:getY() end)
        if ax ~= nil and ay ~= nil then
            local dx, dy = ax - target.fx, ay - target.fy
            if math.sqrt(dx * dx + dy * dy) > MOVE_DIST then moved = true end
        end
    end

    if moved then
        if BridgeTask.phase == "pose" then
            finishPose(a, body)
            BridgeTask.current = nil
            BridgeTask.phase = nil
            BridgeTask.resetWalkDest()
            return true
        end
        local sq = sqOf(a)
        if sq ~= nil then
            target.x, target.y, target.z = sq:getX(), sq:getY(), sq:getZ()
        end
        pcall(function() target.fx, target.fy = a:getX(), a:getY() end)
        BridgeTask.petRetargets = (BridgeTask.petRetargets or 0) + 1
        if BridgeTask.petRetargets > MOVE_LIMIT then
            return dropWithSpeech(body, "moved")
        end
        BridgeTask.resetWalkDest()
    end

    if BridgeTask.phase ~= "pose" then
        local walk, _ = BridgeTask.walkTo(body, { x = target.x, y = target.y, z = target.z }, REACH, true)
        if walk == "unreachable" then
            if BridgeTask.petRetryTarget ~= BridgeTask.current then
                BridgeTask.petRetryTarget = BridgeTask.current
                BridgeTask.resetWalkDest()
                BridgeTask.info = "pet retry"
                return true
            end
            BridgeTask.petRetryTarget = nil
            return dropWithSpeech(body, "unreachable")
        end
        if walk ~= "arrived" then return true end
        pcall(function() BridgeMove.stopPath(body) end)
        BridgeTask.forceIdle(body)
        if not BridgeAnimalCare.canPet(a) then
            BridgeTask.current = nil
            BridgeTask.phase = nil
            BridgeTask.resetWalkDest()
            return true
        end
        beginPose(body, a)
        if not applyPet(a, body) then
            return dropWithSpeech(body, "petfail")
        end
        return true
    end

    if BridgeTask.petStart == nil or BridgeTask.petTicks == nil then
        finishPose(a, body)
        BridgeTask.current = nil
        BridgeTask.phase = nil
        BridgeTask.resetWalkDest()
        return true
    end
    local age = Bridge.time - BridgeTask.petStart
    if age < BridgeTask.petTicks and age < POSE_TIMEOUT then
        return true
    end
    finishPose(a, body)
    BridgeTask.current = nil
    BridgeTask.phase = nil
    BridgeTask.resetWalkDest()
    return true
end

local function available(body)
    return BridgeTask ~= nil and BridgeTask.PET_ANIMALS_ENABLED == 1
end

function BridgeAnimalCare.install()
    if type(BridgeTask) == "table" and BridgeTask.kinds ~= nil then
        BridgeTask.kinds.petAnimals = {
            available = available,
            missing = nil,
            update = jobUpdate,
            leave = leave,
        }
    end
    if type(BridgeWorkSelect) == "table" and BridgeWorkSelect.kinds ~= nil then
        BridgeWorkSelect.kinds.petAnimals = {
            collect = BridgeAnimalCare.targetsIn,
            max = MAX_TARGETS,
            maxSide = MAX_SIDE,
            min = 1,
            noneSay = "JobNoPets",
        }
    end
end

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(BridgeAnimalCare.install) end)
end
