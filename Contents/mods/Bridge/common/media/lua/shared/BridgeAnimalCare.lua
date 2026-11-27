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
local MILK_PER_UNIT = 0.1
local MILK_TICKS = 48
local SHEAR_TICKS = 100
local SHEAR_ELECTRIC_TICKS = 60
local SHEAR_MIN_TICKS = 40
local STRESS_LIMIT = 40
local PRODUCT_SLACK = 4 * SECOND

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeAnimalCare] " .. tostring(text)) end end

local function ffMult()
    local m = 1
    if BridgeTask ~= nil and type(BridgeTask.ffMult) == "function" then
        pcall(function() m = BridgeTask.ffMult() end)
    end
    if type(m) ~= "number" or m < 1 then m = 1 end
    return m
end

local function productsOn()
    return BridgeTask == nil or BridgeTask.ANIMAL_PRODUCTS_ENABLED ~= 0
end

local function dataOf(a)
    local d = nil
    if a ~= nil then pcall(function() d = a:getData() end) end
    return d
end

local function breedOf(a)
    local b = nil
    local d = dataOf(a)
    if d ~= nil then pcall(function() b = d:getBreed() end) end
    if b == nil and a ~= nil then pcall(function() b = a:getBreed() end) end
    return b
end

local function stressOf(a)
    local s = 0
    if a ~= nil then pcall(function() s = tonumber(a:getStress()) or 0 end) end
    return s
end

local function invOf(body)
    local inv = nil
    if body ~= nil then pcall(function() inv = body:getInventory() end) end
    return inv
end

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

local function petXpNow(chr)
    local v = nil
    pcall(function() v = chr:getXp():getXP(Perks.Husbandry) end)
    return tonumber(v) or 0
end

local function petXpLevel(chr)
    local v = 0
    pcall(function() v = chr:getPerkLevel(Perks.Husbandry) end)
    return tonumber(v) or 0
end

local function petXpShift(chr, amount, serverSide)
    if serverSide == true and type(addXp) == "function" then
        if pcall(addXp, chr, Perks.Husbandry, amount) then return true end
    end
    return pcall(function() chr:getXp():AddXPNoMultiplier(Perks.Husbandry, amount) end)
end

function BridgeAnimalCare.petNoPlayerXp(a, chr, serverSide)
    if a == nil or chr == nil then return false end
    local fn = a.petAnimal
    if fn == nil then return false end
    local beforeXp = petXpNow(chr)
    local beforeLvl = petXpLevel(chr)
    if not pcall(fn, a, chr) then return false end
    if petXpLevel(chr) ~= beforeLvl then
        log("pet xp kept: player level gain")
        return true
    end
    local scale = 1
    for _ = 1, 4 do
        local now = petXpNow(chr)
        local left = now - beforeXp
        if math.abs(left) <= 0.05 then break end
        local want = left / scale
        if math.abs(want) < 0.05 then break end
        petXpShift(chr, -want, serverSide)
        local after = petXpNow(chr)
        local moved = now - after
        if moved <= 0.0001 then break end
        scale = moved / want
        if scale <= 0.0001 then scale = 1 end
    end
    return true
end

local function isTendedRaw(a)
    if a == nil then return false, "nil" end
    local dead = false
    pcall(function() dead = a:isDead() == true end)
    if dead then return false, "dead" end
    local exists = true
    pcall(function() exists = a:isExistInTheWorld() ~= false end)
    if not exists then return false, "notexist" end
    if sqOf(a) == nil then return false, "nosquare" end
    local wild = false
    pcall(function() wild = a:isWild() == true end)
    if wild then return false, "wild" end
    local companion = false
    pcall(function() companion = hasMod(a) and a:getModData().CompanionDogs ~= nil end)
    if companion then return false, "companion" end
    local held, hook = false, false
    pcall(function() held = a:isHeld() == true end)
    if held then return false, "held" end
    local vehicle = nil
    pcall(function() vehicle = a:getVehicle() end)
    if vehicle ~= nil then return false, "vehicle" end
    local hutch = nil
    pcall(function() hutch = a:getHutch() end)
    if hutch ~= nil then return false, "hutch" end
    pcall(function() hook = a:isOnHook() == true end)
    if hook then return false, "hook" end
    local attachedPlayer, attachedTree = nil, nil
    pcall(function()
        local d = a:getData()
        if d ~= nil then
            attachedPlayer = d:getAttachedPlayer()
            attachedTree = d:getAttachedTree()
        end
    end)
    if attachedPlayer ~= nil or attachedTree ~= nil then return false, "attached" end
    return true, "ok"
end

local tendedMemo = setmetatable({}, { __mode = "k" })

function BridgeAnimalCare.isTended(a)
    if a == nil then return false end
    local tick = Bridge ~= nil and tonumber(Bridge.tick) or 0
    local e = tendedMemo[a]
    if e ~= nil and e.tick == tick then return e.v end
    local v = isTendedRaw(a) == true
    tendedMemo[a] = { tick = tick, v = v }
    return v
end

function BridgeAnimalCare.tendReason(a)
    local ok, reason = isTendedRaw(a)
    return reason
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

function BridgeAnimalCare.shearUsable(it)
    if it == nil then return false end
    local tag = false
    pcall(function() tag = it:hasTag(ItemTag.SHEAR) == true end)
    if not tag then return false end
    local drain = false
    pcall(function() drain = instanceof(it, "DrainableComboItem") == true end)
    if drain then
        local uses = 0
        pcall(function() uses = tonumber(it:getCurrentUsesFloat()) or 0 end)
        return uses > 0
    end
    local cond = 0
    pcall(function() cond = tonumber(it:getCondition()) or 0 end)
    return cond > 0
end

function BridgeAnimalCare.milkContainerItem(it)
    if it == nil then return false end
    local fc = nil
    pcall(function() fc = it:getFluidContainer() end)
    if fc == nil then return false end
    local cap, free = 0, 0
    pcall(function() cap = tonumber(fc:getCapacity()) or 0 end)
    pcall(function() free = tonumber(fc:getFreeCapacity()) or 0 end)
    if cap <= 0 or free <= 0 then return false end
    local empty = false
    pcall(function() empty = fc:isEmpty() == true end)
    if empty then return true end
    local name = nil
    pcall(function() name = fc:getPrimaryFluid():getFluidTypeString() end)
    return name == "CowMilk" or name == "SheepMilk"
end

function BridgeAnimalCare.findShears(body)
    local inv = invOf(body)
    if inv == nil then return nil end
    local list = nil
    pcall(function() list = inv:getAllEvalRecurse(BridgeAnimalCare.shearUsable) end)
    if list == nil then return nil end
    local n = 0
    pcall(function() n = list:size() end)
    for i = 0, n - 1 do
        local it = nil
        pcall(function() it = list:get(i) end)
        if it ~= nil then return it end
    end
    return nil
end

local function milkFits(it, milkType)
    if it == nil then return false end
    local fc = nil
    pcall(function() fc = it:getFluidContainer() end)
    if fc == nil then return false end
    local free = 0
    pcall(function() free = tonumber(fc:getFreeCapacity()) or 0 end)
    if free < MILK_PER_UNIT - 0.000001 then return false end
    local empty = false
    pcall(function() empty = fc:isEmpty() == true end)
    if empty then return true end
    if milkType == nil then return false end
    local pure = false
    pcall(function()
        local f = Fluid.Get(milkType)
        if f ~= nil then pure = fc:isPureFluid(f) == true end
    end)
    return pure
end
BridgeAnimalCare.milkFits = milkFits

function BridgeAnimalCare.findMilkContainer(body, milkType)
    local inv = invOf(body)
    if inv == nil then return nil end
    local list = nil
    pcall(function() list = inv:getAvailableFluidContainer(milkType) end)
    if list ~= nil then
        local n = 0
        pcall(function() n = list:size() end)
        for i = 0, n - 1 do
            local it = nil
            pcall(function() it = list:get(i) end)
            if it ~= nil and milkFits(it, milkType) then return it end
        end
    end
    local all = nil
    pcall(function() all = inv:getAllEvalRecurse(BridgeAnimalCare.milkContainerItem) end)
    if all == nil then return nil end
    local n = 0
    pcall(function() n = all:size() end)
    for i = 0, n - 1 do
        local it = nil
        pcall(function() it = all:get(i) end)
        if it ~= nil and milkFits(it, milkType) then return it end
    end
    return nil
end

function BridgeAnimalCare.findMilkContainerAny(body)
    local it = BridgeAnimalCare.findMilkContainer(body, "CowMilk")
    if it ~= nil then return it end
    return BridgeAnimalCare.findMilkContainer(body, "SheepMilk")
end

function BridgeAnimalCare.milkInfo(a)
    if not BridgeAnimalCare.isTended(a) then return false, nil, 0, 0 end
    local can, have = false, false
    local qty, max = 0, 0
    pcall(function() can = a:canBeMilked() == true end)
    local d = dataOf(a)
    if d ~= nil then
        pcall(function() have = d:canHaveMilk() == true end)
        pcall(function() qty = tonumber(d:getMilkQuantity()) or 0 end)
        pcall(function() max = tonumber(d:getMaxMilk()) or 0 end)
    end
    local milkType = nil
    local b = breedOf(a)
    if b ~= nil then pcall(function() milkType = b:getMilkType() end) end
    local ready = can and have and qty > MILK_PER_UNIT
        and milkType ~= nil and milkType ~= ""
    return ready, milkType, qty, max
end

function BridgeAnimalCare.shearInfo(a)
    if not BridgeAnimalCare.isTended(a) then return false, nil, 0, 0 end
    local can = false
    local qty, max = 0, 0
    pcall(function() can = a:canBeSheared() == true end)
    local d = dataOf(a)
    if d ~= nil then
        pcall(function() qty = tonumber(d:getWoolQuantity()) or 0 end)
        pcall(function() max = tonumber(d:getMaxWool()) or 0 end)
    end
    local woolType = nil
    local b = breedOf(a)
    if b ~= nil then pcall(function() woolType = b:getWoolType() end) end
    if woolType == nil or woolType == "" then woolType = "Base.WoolRaw" end
    local ready = can and qty > 1
    return ready, woolType, qty, max
end

local function taskForRaw(a)
    if a == nil then return nil end
    if productsOn() then
        local shear = BridgeAnimalCare.shearInfo(a)
        if shear then return "shear" end
        local milk = BridgeAnimalCare.milkInfo(a)
        if milk then return "milk" end
    end
    if BridgeAnimalCare.canPet(a) then return "pet" end
    return nil
end

local taskMemo = setmetatable({}, { __mode = "k" })

function BridgeAnimalCare.taskFor(a)
    if a == nil then return nil end
    local tick = Bridge ~= nil and tonumber(Bridge.tick) or 0
    local e = taskMemo[a]
    if e ~= nil and e.tick == tick then
        if e.v == false then return nil end
        return e.v
    end
    local v = taskForRaw(a)
    taskMemo[a] = { tick = tick, v = v == nil and false or v }
    return v
end

function BridgeAnimalCare.canTend(a)
    return BridgeAnimalCare.taskFor(a) ~= nil
end

function BridgeAnimalCare.taskDebug(a)
    if a == nil then return "nil" end
    local task = BridgeAnimalCare.taskFor(a)
    local canPet = BridgeAnimalCare.canPet(a)
    local shear = BridgeAnimalCare.shearInfo(a) and "1" or "0"
    local milk = BridgeAnimalCare.milkInfo(a) and "1" or "0"
    local stress = stressOf(a)
    local cd = BridgeAnimalCare.cooldownLeft(a)
    return string.format("task=%s canPet=%s shear=%s milk=%s stress=%s cooldown=%.2f",
        tostring(task or "-"), tostring(canPet), shear, milk, tostring(stress), cd)
end

function BridgeAnimalCare.taskReady(a, task)
    if task == nil then return false end
    if task == "shear" then return (BridgeAnimalCare.shearInfo(a)) end
    if task == "milk" then return (BridgeAnimalCare.milkInfo(a)) end
    if task == "pet" then return BridgeAnimalCare.canPet(a) end
    return false
end

BridgeAnimalCare.stressOf = stressOf
BridgeAnimalCare.nameOf = animalName

function BridgeAnimalCare.readyForTask(a, task)
    if task == nil or a == nil then return false end
    if task == "pet" then return BridgeAnimalCare.canPet(a) end
    if not BridgeAnimalCare.taskReady(a, task) then return false end
    return stressOf(a) <= STRESS_LIMIT
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
    local pet = string.sub(bump, 1, 6) == "NA_Pet"
    local milk = string.sub(bump, 1, 7) == "NA_Milk"
    local shear = string.sub(bump, 1, 8) == "NA_Shear"
    if not (pet or milk or shear) then return end
    pcall(function() body:setVariable("BumpAnimFinished", true) end)
    pcall(function()
        if ZombieIdleState ~= nil and ZombieIdleState.instance ~= nil then
            body:changeState(ZombieIdleState.instance())
        end
    end)
    pcall(function() body:setBumpType("") end)
end

local function milkSide(body, a)
    if body == nil or a == nil then return false end
    local right = false
    pcall(function()
        local vr = a:getAttachmentWorldPos("rightmilk")
        local vl = a:getAttachmentWorldPos("leftmilk")
        if vr ~= nil and vl ~= nil then
            local dr = body:DistToSquared(vr:x(), vr:y())
            local dl = body:DistToSquared(vl:x(), vl:y())
            right = dr < dl
        end
    end)
    return right
end

function BridgeAnimalCare.productPose(body, a, task, milkType)
    if task == "shear" then return "NA_Shear" end
    local cow = tostring(milkType or "") == "CowMilk"
    local right = milkSide(body, a)
    if cow then return right and "NA_MilkCowR" or "NA_MilkCowL" end
    return right and "NA_MilkSheepR" or "NA_MilkSheepL"
end

local function setAnimalSize(body, a)
    if body == nil then return end
    local d = dataOf(a)
    if d == nil then return end
    local minS, maxS, size = nil, nil, nil
    pcall(function() minS = tonumber(d:getMinSize()) end)
    pcall(function() maxS = tonumber(d:getMaxSize()) end)
    pcall(function() size = tonumber(d:getSize()) end)
    local ratio = 0
    if minS ~= nil and maxS ~= nil and size ~= nil and maxS > minS then
        local cur = size - minS
        if cur <= 0.001 then cur = 0.001 end
        ratio = cur / (maxS - minS)
    end
    pcall(function() body:setVariable("AnimalSizeX", 0.01) end)
    pcall(function() body:setVariable("AnimalSizeY", ratio) end)
end

local function startProductSound(body, task, tool)
    if body == nil then return end
    local name = "MilkAnimal"
    if task == "shear" then
        name = "AnimalFoleyShearSheepManual"
        local drain = false
        if tool ~= nil then
            pcall(function() drain = instanceof(tool, "DrainableComboItem") == true end)
        end
        if drain then name = "AnimalFoleyShearSheepElectric" end
    end
    local emitter = nil
    pcall(function() emitter = body:getEmitter() end)
    local id = nil
    if emitter ~= nil then pcall(function() id = emitter:playSound(name) end) end
    if id == nil then pcall(function() id = body:playSound(name) end) end
    BridgeTask.petSoundEmitter = emitter
    BridgeTask.petSoundHandle = id
    BridgeTask.petSound = name
end

local function stopProductSound(body)
    if BridgeTask == nil then return end
    local id = BridgeTask.petSoundHandle
    local emitter = BridgeTask.petSoundEmitter
    BridgeTask.petSoundHandle = nil
    BridgeTask.petSoundEmitter = nil
    BridgeTask.petSound = nil
    if id == nil then return end
    if emitter ~= nil then
        pcall(function() emitter:stopOrTriggerSound(id) end)
    elseif body ~= nil then
        pcall(function() body:stopOrTriggerSound(id) end)
    end
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
    local inBox, tended = 0, 0
    local rejects = {}
    for i = 0, n - 1 do
        if #out >= cap then break end
        local a = nil
        pcall(function() a = list:get(i) end)
        if a ~= nil then
            local sq = sqOf(a)
            if sq ~= nil then
                local ax, ay, az = sq:getX(), sq:getY(), sq:getZ()
                if ax >= b.x1 and ax <= b.x2 and ay >= b.y1 and ay <= b.y2
                        and math.abs(az - b.z) < 1 then
                    inBox = inBox + 1
                    if BridgeAnimalCare.canTend(a) then
                        tended = tended + 1
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
                    else
                        if BridgeLog ~= nil and BridgeLog.on() then
                            local reason = BridgeAnimalCare.tendReason(a) or "?"
                            if reason == "ok" then reason = "notready" end
                            rejects[reason] = (rejects[reason] or 0) + 1
                        end
                    end
                end
            end
        end
    end
    if BridgeLog ~= nil and BridgeLog.on() then
        local parts = {}
        for k, v in pairs(rejects) do parts[#parts + 1] = tostring(k) .. ":" .. tostring(v) end
        table.sort(parts)
        log(string.format("targetsIn cell=%d inbox=%d tended=%d out=%d cap=%d reject=%s box=%s,%s,%s,%s,z%s",
            n, inBox, tended, #out, cap, (#parts > 0 and table.concat(parts, ",") or "-"),
            tostring(b.x1), tostring(b.y1), tostring(b.x2), tostring(b.y2), tostring(b.z)))
    end
    return out
end

function BridgeAnimalCare.targetFor(a, task)
    if task ~= nil then
        if not BridgeAnimalCare.readyForTask(a, task) then return nil end
    elseif not BridgeAnimalCare.canTend(a) then
        return nil
    end
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
        task = task or BridgeAnimalCare.taskFor(a),
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

local function releaseAnimal(a)
    if BridgeTask == nil then return end
    a = a or BridgeTask.petHoldAnimal
    local id = BridgeTask.petHoldId
    local x, y, z = BridgeTask.petHoldX, BridgeTask.petHoldY, BridgeTask.petHoldZ
    local action = BridgeTask.petHoldAction
    local on = BridgeTask.petHoldOn == true
    BridgeTask.petHoldOn = nil
    BridgeTask.petHoldAnimal = nil
    BridgeTask.petHoldId = nil
    BridgeTask.petHoldX, BridgeTask.petHoldY, BridgeTask.petHoldZ = nil, nil, nil
    BridgeTask.petHoldAction = nil
    if a ~= nil then
        blockAnimal(a, false)
        if action == "pet" then clearIdleAction(a) end
    end
    if not on or Bridge == nil or Bridge.mp ~= true or id == nil then return end
    local red = nil
    if BridgeData ~= nil and BridgeData.owner ~= nil then red = BridgeData.owner() end
    if red == nil then return end
    pcall(function()
        sendClientCommand(red, "Bridge", "animalHold", {
            on = false, id = id, x = x, y = y, z = z, action = action,
        })
    end)
end

local function holdAnimal(a, action)
    if a == nil or BridgeTask == nil then return end
    if BridgeTask.petHoldOn == true and BridgeTask.petHoldAnimal == a then return end
    if BridgeTask.petHoldOn == true then releaseAnimal(BridgeTask.petHoldAnimal) end
    local id, x, y, z = nil, nil, nil, nil
    pcall(function()
        id = a:getOnlineID()
        x, y, z = a:getX(), a:getY(), a:getZ()
    end)
    local bx, by, bz = nil, nil, nil
    if Bridge ~= nil and Bridge.body ~= nil then
        pcall(function() bx, by, bz = Bridge.body:getX(), Bridge.body:getY(), Bridge.body:getZ() end)
    end
    BridgeTask.petHoldAnimal = a
    BridgeTask.petHoldId = id
    BridgeTask.petHoldX, BridgeTask.petHoldY, BridgeTask.petHoldZ = x, y, z
    BridgeTask.petHoldAction = action
    BridgeTask.petHoldOn = true
    pcall(function() a:stopAllMovementNow() end)
    blockAnimal(a, true)
    if action == "pet" then pcall(function() a:setVariable("idleAction", "petting") end) end
    if Bridge == nil or Bridge.mp ~= true or id == nil then return end
    local red = nil
    if BridgeData ~= nil and BridgeData.owner ~= nil then red = BridgeData.owner() end
    if red == nil then return end
    local opId = (BridgeTask.petHoldSeq or 0) + 1
    BridgeTask.petHoldSeq = opId
    pcall(function()
        sendClientCommand(red, "Bridge", "animalHold", {
            on = true, id = id, x = x, y = y, z = z, bx = bx, by = by, bz = bz,
            action = action, opId = opId,
        })
    end)
end
BridgeAnimalCare.holdAnimal = holdAnimal
BridgeAnimalCare.releaseAnimal = releaseAnimal

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
    stopProductSound(b)
    if b ~= nil then
        pcall(function() b:setVariable("AnimalSizeX", 0.01) end)
        pcall(function() b:setVariable("AnimalSizeY", 0) end)
    end
    BridgeAnimalCare.clearPose(b)
    clearIdleAction(a)
    releaseAnimal(a)
    if BridgeTask ~= nil then
        BridgeTask.petHeld = nil
        BridgeTask.petValidRef = nil
        BridgeTask.petValidAt = nil
        BridgeTask.petPending = nil
        BridgeTask.petPendingAt = nil
        BridgeTask.petStart = nil
        BridgeTask.petTicks = nil
        BridgeTask.petTicksPerUnit = nil
        BridgeTask.petUnitsWanted = nil
        BridgeTask.petUnitsDone = nil
        BridgeTask.petMilkType = nil
        BridgeTask.petWoolType = nil
        BridgeTask.petTool = nil
        BridgeTask.petTask = nil
        BridgeTask.petDidWork = nil
        BridgeTask.petSound = nil
    end
end

local function beginPose(body, a)
    faceAnimal(body, a)
    clearHands(body)
    holdAnimal(a, "pet")
    pcall(function() body:setVariable("BumpAnimFinished", false) end)
    local pose = BridgeAnimalCare.poseFor(a)
    pcall(function() body:setBumpType(pose) end)
    if BridgeTask ~= nil then
        BridgeTask.phase = "pose"
        BridgeTask.petTask = "pet"
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

local function beginProductPose(body, a, task, units, ticksPerUnit)
    faceAnimal(body, a)
    clearHands(body)
    holdAnimal(a, task)
    setAnimalSize(body, a)
    pcall(function() body:setVariable("BumpAnimFinished", false) end)
    local pose = BridgeAnimalCare.productPose(body, a, task, BridgeTask.petMilkType)
    pcall(function() body:setBumpType(pose) end)
    startProductSound(body, task, BridgeTask.petTool)
    BridgeTask.phase = "pose"
    BridgeTask.petStart = Bridge.time
    BridgeTask.petTicksPerUnit = ticksPerUnit
    BridgeTask.petUnitsWanted = units
    BridgeTask.petUnitsDone = 0
    BridgeTask.petTicks = units * ticksPerUnit
    BridgeTask.petHeld = a
    BridgeTask.petDidWork = false
    if task == "milk" then
        speak("JobMilkStart", animalName(a))
    else
        speak("JobShearStart", animalName(a))
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
    local bx, by, bz = nil, nil, nil
    if Bridge ~= nil and Bridge.body ~= nil then
        pcall(function() bx, by, bz = Bridge.body:getX(), Bridge.body:getY(), Bridge.body:getZ() end)
    end
    BridgeTask.petPending = { id = id, animal = a }
    BridgeTask.petPendingAt = Bridge.time
    local ok = pcall(function()
        sendClientCommand(red, "Bridge", "petAnimals", {
            id = id, x = x, y = y, z = z, bx = bx, by = by, bz = bz,
        })
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
    local ok = BridgeAnimalCare.petNoPlayerXp(a, red, false)
    if not ok then return false end
    BridgeAnimalCare.notePet(a)
    addPetXp()
    if BridgeTask ~= nil and BridgeTask.markDone ~= nil then BridgeTask.markDone() end
    return true
end

local function wearShears(body, tool)
    if tool == nil then return end
    local drain = false
    pcall(function() drain = instanceof(tool, "DrainableComboItem") == true end)
    if drain then
        pcall(function() tool:Use() end)
    else
        local cond = 0
        pcall(function() cond = tonumber(tool:getCondition()) or 0 end)
        pcall(function() tool:setCondition(math.max(0, cond - 1)) end)
    end
end
BridgeAnimalCare.wearShears = wearShears

local function syncItems()
    if Bridge ~= nil then
        if Bridge.itemsChanged ~= nil then pcall(Bridge.itemsChanged) end
        if Bridge.saveOutfit ~= nil then pcall(Bridge.saveOutfit) end
    end
end

local function addWoolItem(body, woolType)
    if body == nil or woolType == nil then return false end
    if BridgeItems == nil or type(BridgeItems.record) ~= "function"
            or type(BridgeItems.make) ~= "function" then return false end
    local item = nil
    pcall(function() item = instanceItem(woolType) end)
    if item == nil then return false end
    local rec = nil
    pcall(function() rec = BridgeItems.record(item, true) end)
    if rec == nil then return false end
    local dests = nil
    pcall(function() dests = BridgeTask.lootDests(body) end)
    if type(dests) ~= "table" then return false end
    local dest = nil
    pcall(function() dest = BridgeTask.lootDestFor(body, item, dests) end)
    if dest == nil then return false end
    local made = nil
    pcall(function() made = BridgeItems.make(dest, rec) end)
    if made == nil then return false end
    syncItems()
    return true
end
BridgeAnimalCare.addWoolItem = addWoolItem

local function fillMilkUnit(body, milkType)
    if body == nil or milkType == nil then return false, "nofluid" end
    local item = BridgeTask.petTool
    if item == nil or not milkFits(item, milkType) then
        item = BridgeAnimalCare.findMilkContainer(body, milkType)
        BridgeTask.petTool = item
    end
    if item == nil then return false, "noroom" end
    local fc = nil
    pcall(function() fc = item:getFluidContainer() end)
    if fc == nil then return false, "noroom" end
    local before = 0
    pcall(function() before = tonumber(fc:getAmount()) or 0 end)
    local fluid = nil
    pcall(function() fluid = Fluid.Get(milkType) end)
    if fluid == nil then return false, "nofluid" end
    pcall(function() fc:addFluid(fluid, MILK_PER_UNIT) end)
    local after = before
    pcall(function() after = tonumber(fc:getAmount()) or before end)
    if after - before < MILK_PER_UNIT - 0.0001 then return false, "noroom" end
    pcall(function() item:sendSyncEntity(nil) end)
    syncItems()
    return true
end
BridgeAnimalCare.fillMilkUnit = fillMilkUnit

local function applyProductUnit(body, a, task)
    if task == "milk" then
        local d = dataOf(a)
        if d == nil then return false, "notready" end
        local qty = 0
        pcall(function() qty = tonumber(d:getMilkQuantity()) or 0 end)
        if qty < MILK_PER_UNIT then return false, "notready" end
        local ok, why = fillMilkUnit(body, BridgeTask.petMilkType)
        if not ok then return false, why or "noroom" end
        pcall(function() d:setMilkQuantity(math.max(0, qty - MILK_PER_UNIT)) end)
        if BridgeSkills ~= nil and type(BridgeSkills.add) == "function" then
            pcall(BridgeSkills.add, "Husbandry", 0.1, "animalcare.milk")
        end
        return true
    end
    local tool = BridgeTask.petTool
    if tool == nil or not BridgeAnimalCare.shearUsable(tool) then return false, "notool" end
    local d = dataOf(a)
    if d == nil then return false, "notready" end
    local qty = 0
    pcall(function() qty = tonumber(d:getWoolQuantity()) or 0 end)
    if qty < 1 then return false, "notready" end
    if not addWoolItem(body, BridgeTask.petWoolType or "Base.WoolRaw") then return false, "noroom" end
    pcall(function() d:setWoolQuantity(math.max(0, qty - 1), true) end)
    wearShears(body, tool)
    if BridgeSkills ~= nil and type(BridgeSkills.add) == "function" then
        pcall(BridgeSkills.add, "Husbandry", 1, "animalcare.shear")
    end
    return true
end
BridgeAnimalCare.applyProductUnit = applyProductUnit

local function finishProduct(body, a, why, sayKey)
    local T = BridgeTask
    local task = T.petTask
    local done = tonumber(T.petUnitsDone) or 0
    if done > 0 and task == "shear" then
        T.petWoolGot = (T.petWoolGot or 0) + done
        if T.petWoolType ~= nil then
            T.petWoolTypes = T.petWoolTypes or {}
            T.petWoolTypes[T.petWoolType] = true
        end
    elseif done > 0 and task == "milk" then
        T.petMilkGot = (T.petMilkGot or 0) + done
    end
    finishPose(a, body)
    if sayKey ~= nil then
        speak(sayKey, animalName(a))
    elseif done > 0 then
        if task == "milk" then speak("JobMilkDone") else speak("JobShearDone") end
    end
    if done > 0 and T.markDone ~= nil then T.markDone() end
    T.current = nil
    T.phase = nil
    T.resetWalkDest()
end

local function releaseCurrent(body, a, sayKey)
    finishPose(a, body)
    BridgeTask.current = nil
    BridgeTask.phase = nil
    BridgeTask.resetWalkDest()
    if sayKey ~= nil then speak(sayKey, animalName(a)) end
end

local function sayNeedOnce(key, flag)
    if BridgeTask == nil or key == nil then return end
    if BridgeTask[flag] == true then return end
    BridgeTask[flag] = true
    speak(key)
end

local function beginPetFallback(body, a, target)
    if not BridgeAnimalCare.canPet(a) then return false end
    target.task = "pet"
    beginPose(body, a)
    if not applyPet(a, body) then
        releaseCurrent(body, a, "JobPetNoReach")
    end
    return true
end

local function requestProduct(a, task)
    if Bridge == nil or Bridge.mp ~= true or BridgeTask == nil then return false end
    local red = nil
    if BridgeData ~= nil and BridgeData.owner ~= nil then red = BridgeData.owner() end
    if red == nil then return false end
    local id = nil
    pcall(function() id = a:getOnlineID() end)
    if id == nil then return false end
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = a:getX(), a:getY(), a:getZ() end)
    if x == nil or y == nil or z == nil then return false end
    local bx, by, bz = nil, nil, nil
    if Bridge ~= nil and Bridge.body ~= nil then
        pcall(function() bx, by, bz = Bridge.body:getX(), Bridge.body:getY(), Bridge.body:getZ() end)
    end
    local opId = (BridgeTask.petOpSeq or 0) + 1
    local ok = pcall(function()
        sendClientCommand(red, "Bridge", "petAnimals", {
            id = id, x = x, y = y, z = z, bx = bx, by = by, bz = bz,
            task = task, units = 1, opId = opId,
        })
    end)
    if not ok then return false end
    BridgeTask.petOpSeq = opId
    BridgeTask.petPending = {
        opId = opId,
        product = task,
        animal = a,
        at = Bridge.time,
        milkType = BridgeTask.petMilkType,
    }
    BridgeTask.petPendingAt = Bridge.time
    return true
end

local function setupProduct(body, a, task)
    local T = BridgeTask
    T.petTask = task
    T.petUnitsDone = 0
    T.petTool = nil
    T.petMilkType = nil
    T.petWoolType = nil
    T.petDidWork = false
    local husbandry = 0
    if BridgeSkills ~= nil and type(BridgeSkills.level) == "function" then
        pcall(function() husbandry = math.floor(tonumber(BridgeSkills.level("Husbandry")) or 0) end)
    end
    if task == "milk" then
        local ready, milkType, qty = BridgeAnimalCare.milkInfo(a)
        if not ready then return false, "JobPetNotReady" end
        local tool = BridgeAnimalCare.findMilkContainer(body, milkType)
        if tool == nil then return false, "JobNoMilkContainer" end
        local free = 0
        pcall(function() free = tonumber(tool:getFluidContainer():getFreeCapacity()) or 0 end)
        local units = math.floor((qty + 0.000001) / MILK_PER_UNIT)
        local cap = math.floor((free + 0.000001) / MILK_PER_UNIT)
        if units > cap then units = cap end
        if units < 1 then return false, "JobNoMilkContainer" end
        T.petMilkType = milkType
        T.petTool = tool
        beginProductPose(body, a, task, units, MILK_TICKS)
        return true
    end
    local ready, woolType, qty = BridgeAnimalCare.shearInfo(a)
    if not ready then return false, "JobPetNotReady" end
    local tool = BridgeAnimalCare.findShears(body)
    if tool == nil then return false, "JobNoShears" end
    local units = math.floor(qty - 1) + 1
    local drain = false
    pcall(function() drain = instanceof(tool, "DrainableComboItem") == true end)
    if not drain then
        local cond = nil
        pcall(function() cond = tonumber(tool:getCondition()) end)
        if cond ~= nil and units > cond then units = cond end
    end
    if units < 1 then return false, "JobNoShears" end
    local ticks = SHEAR_TICKS
    if drain then ticks = SHEAR_ELECTRIC_TICKS end
    ticks = ticks - 2 * husbandry
    if ticks < SHEAR_MIN_TICKS then ticks = SHEAR_MIN_TICKS end
    T.petWoolType = woolType
    T.petTool = tool
    beginProductPose(body, a, task, units, ticks)
    return true
end

local function onProductResult(args, pending)
    local T = BridgeTask
    local body = nil
    if Bridge ~= nil then body = Bridge.body end
    T.petPending = nil
    T.petPendingAt = nil
    local a = pending.animal
    if args.ok ~= true then
        local why = tostring(args.why or "")
        local sayKey = "JobPetNoReach"
        if why == "notready" then
            sayKey = "JobProductStress"
        elseif why == "full" or why == "noitem" then
            sayKey = "JobProductNoRoom"
        end
        finishProduct(body, a, why, sayKey)
        return
    end
    local n = math.floor(tonumber(args.count) or 0)
    if n < 1 then n = 1 end
    if pending.product == "milk" then
        local milkType = args.milkType or pending.milkType or T.petMilkType
        for _ = 1, n do
            local ok = fillMilkUnit(body, milkType)
            if not ok then
                finishProduct(body, a, "noroom", "JobProductNoRoom")
                return
            end
        end
        if BridgeSkills ~= nil and type(BridgeSkills.add) == "function" then
            pcall(BridgeSkills.add, "Husbandry", 0.1 * n, "animalcare.milk")
        end
    else
        for _ = 1, n do wearShears(body, T.petTool) end
        if BridgeSkills ~= nil and type(BridgeSkills.add) == "function" then
            pcall(BridgeSkills.add, "Husbandry", n, "animalcare.shear")
        end
    end
    T.petUnitsDone = (T.petUnitsDone or 0) + n
    T.petDidWork = true
end

function BridgeAnimalCare.onPetResult(args)
    local animalPart = BridgeTask ~= nil and (BridgeTask.kind == "petAnimals"
        or (BridgeTask.kind == "tendAnimals" and BridgeTask.tendPart == "animal"))
    if BridgeTask == nil or not BridgeTask.active or not animalPart then return end
    local pending = BridgeTask.petPending
    if pending == nil then return end
    if args == nil or args.ok ~= true then
        log("pet result fail why=" .. tostring(args and args.why or "nil"))
    end
    if pending.opId ~= nil then
        if args == nil or tostring(args.opId) ~= tostring(pending.opId) then return end
        onProductResult(args, pending)
        return
    end
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
        if pending.opId ~= nil then
            local done = tonumber(BridgeTask.petUnitsDone) or 0
            local task = BridgeTask.petTask
            if done > 0 and task == "shear" then
                BridgeTask.petWoolGot = (BridgeTask.petWoolGot or 0) + done
                if BridgeTask.petWoolType ~= nil then
                    BridgeTask.petWoolTypes = BridgeTask.petWoolTypes or {}
                    BridgeTask.petWoolTypes[BridgeTask.petWoolType] = true
                end
            elseif done > 0 and task == "milk" then
                BridgeTask.petMilkGot = (BridgeTask.petMilkGot or 0) + done
            end
            finishPose(a, body)
            if done > 0 then
                if task == "milk" then speak("JobMilkDone") else speak("JobShearDone") end
                if BridgeTask.markDone ~= nil then BridgeTask.markDone() end
            end
            BridgeTask.current = nil
            BridgeTask.phase = nil
            BridgeTask.resetWalkDest()
            if BridgeTask.petFailSaid ~= true then
                BridgeTask.petFailSaid = true
                speak("JobPetNoReach")
            end
            return true
        end
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
    BridgeTask.petValidRef = nil
    BridgeTask.petValidAt = nil
    BridgeTask.petSaidShears = nil
    BridgeTask.petSaidMilk = nil
    BridgeTask.petHoldSeq = nil
    BridgeTask.petIdSeq = nil
    BridgeTask.petOpSeq = nil
    BridgeTask.petWoolGot = nil
    BridgeTask.petWoolTypes = nil
    BridgeTask.petMilkGot = nil
    BridgeTask.petDepositPhase = nil
    BridgeTask.petDepositAct = nil
    BridgeTask.petDepositAt = nil
    BridgeTask.petDepositTarget = nil
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

local function petDepositItems(body)
    local T = BridgeTask
    local out = {}
    local dests = nil
    pcall(function() dests = T.lootDests(body) end)
    if type(dests) ~= "table" then return out end
    local woolLeft = tonumber(T.petWoolGot) or 0
    if woolLeft > 0 then
        local types = T.petWoolTypes or {}
        local cand = {}
        for d = 1, #dests do
            local items = nil
            pcall(function() items = dests[d]:getItems() end)
            if items ~= nil then
                for i = 0, items:size() - 1 do
                    local it = items:get(i)
                    if it ~= nil then
                        local full = nil
                        pcall(function() full = it:getFullType() end)
                        if full ~= nil and types[full] == true then
                            local id = 0
                            pcall(function() id = tonumber(it:getID()) or 0 end)
                            cand[#cand + 1] = { it = it, id = id }
                        end
                    end
                end
            end
        end
        table.sort(cand, function(x, y) return x.id > y.id end)
        local take = math.min(woolLeft, #cand)
        for i = 1, take do out[#out + 1] = cand[i].it end
    end
    for d = 1, #dests do
        local items = nil
        pcall(function() items = dests[d]:getItems() end)
        if items ~= nil then
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                if it ~= nil then
                    local fc = nil
                    pcall(function() fc = it:getFluidContainer() end)
                    if fc ~= nil then
                        local free = 1
                        local pure = false
                        pcall(function() free = tonumber(fc:getFreeCapacity()) or 1 end)
                        pcall(function()
                            pure = fc:isPureFluid(Fluid.Get("CowMilk")) == true
                                or fc:isPureFluid(Fluid.Get("SheepMilk")) == true
                        end)
                        if pure and free <= 0.001 then out[#out + 1] = it end
                    end
                end
            end
        end
    end
    return out
end

local function petDepositWanted(body)
    if (BridgeTask.petWoolGot or 0) > 0 or (BridgeTask.petMilkGot or 0) > 0 then return true end
    return false
end

local function petDepositTick(body)
    local T = BridgeTask
    local phase = T.petDepositPhase
    if phase == "pick" then
        local target = nil
        if type(T.hutchDepositPick) == "function" then target = T.hutchDepositPick(body) end
        if target == nil then
            T.petDepositPhase = nil
            return T.finish()
        end
        T.petDepositTarget = target
        T.petDepositPhase = "walk"
        T.resetWalkDest()
        return true
    end
    if phase == "walk" then
        local target = T.petDepositTarget
        if target == nil then
            T.petDepositPhase = nil
            return T.finish()
        end
        local walk = T.walkTo(body, { x = target.x, y = target.y, z = target.z }, T.HUTCH_REACH, true)
        if walk == "unreachable" then
            T.petDepositTarget = nil
            T.petDepositPhase = nil
            T.resetWalkDest()
            return T.finish()
        end
        if walk ~= "arrived" then return true end
        pcall(function() BridgeMove.stopPath(body) end)
        T.forceIdle(body)
        local items = petDepositItems(body)
        if #items == 0 then
            T.petDepositPhase = nil
            return T.finish()
        end
        local act = nil
        pcall(function() act = BridgeDeposit.depositItems(body, items, target) end)
        if act == nil then
            T.petDepositPhase = nil
            return T.finish()
        end
        T.petDepositAct = act
        T.petDepositAt = Bridge.time
        T.petDepositPhase = "wait"
        return true
    end
    if phase == "wait" then
        local done = false
        if T.petDepositAct == nil then
            done = true
        elseif BridgeInventory ~= nil and type(BridgeInventory.actionQueued) == "function" then
            local queued = true
            pcall(function() queued = BridgeInventory.actionQueued(T.petDepositAct) == true end)
            if not queued then done = true end
        end
        if (Bridge.time - (T.petDepositAt or Bridge.time)) > (T.LOOT_TRANSFER_WAIT or 1200) then done = true end
        if done then
            T.petDepositAct = nil
            T.petDepositAt = nil
            T.petDepositPhase = nil
            T.petDepositTarget = nil
            T.lootAct = nil
            T.lootSrc = nil
            return T.finish()
        end
        return true
    end
    T.petDepositPhase = nil
    return T.finish()
end

local function jobUpdate(body)
    if BridgeTask == nil then return false end
    if BridgeMove ~= nil then BridgeMove.forcedWalk = "Walk" end
    if BridgeTask.PET_ANIMALS_ENABLED ~= 1 then return BridgeTask.finish() end
    if BridgeTask.petPending ~= nil then
        petPendingWait()
        return true
    end

    local target = BridgeTask.current
    if target == nil then
        if BridgeTask.petDepositPhase ~= nil then return petDepositTick(body) end
        local picked = nil
        while #BridgeTask.queue > 0 do
            local t = table.remove(BridgeTask.queue, 1)
            if type(t) == "table" and t.animal ~= nil and BridgeAnimalCare.canTend(t.animal) then
                picked = t
                break
            end
        end
        if picked == nil then
            if BridgeTask.DEPOSIT_ENABLED == 1 and BridgeDeposit ~= nil
                    and type(BridgeDeposit.homeTargets) == "function"
                    and petDepositWanted(body) then
                BridgeTask.petDepositPhase = "pick"
                return petDepositTick(body)
            end
            return BridgeTask.finish()
        end
        BridgeTask.current = picked
        log(string.format("pick animal=%s task=%s", tostring(BridgeAnimalCare.nameOf(picked.animal)), tostring(picked.task or "-")))
        BridgeTask.phase = "walk"
        BridgeTask.petSaid = nil
        BridgeTask.petRetryTarget = nil
        BridgeTask.petRetargets = 0
        BridgeTask.petFarRetries = 0
        BridgeTask.petTask = nil
        BridgeTask.petValidRef = nil
        BridgeTask.petValidAt = nil
        BridgeTask.petUnitsDone = nil
        BridgeTask.petUnitsWanted = nil
        BridgeTask.petTicksPerUnit = nil
        BridgeTask.petMilkType = nil
        BridgeTask.petWoolType = nil
        BridgeTask.petTool = nil
        BridgeTask.petDidWork = false
        BridgeTask.resetWalkDest()
        target = picked
    end

    local a = target.animal
    local tick = Bridge ~= nil and tonumber(Bridge.tick) or 0
    local valid = false
    if a ~= nil and BridgeTask.petValidRef == a and BridgeTask.petValidAt ~= nil
            and (tick - BridgeTask.petValidAt) < 6 then
        valid = true
    else
        if a ~= nil and BridgeAnimalCare.isTended(a) then valid = true end
        if not valid then
            a = BridgeAnimalCare.resolve(target.ref)
            if a ~= nil then
                target.animal = a
                local sq = sqOf(a)
                if sq ~= nil then
                    target.x, target.y, target.z = sq:getX(), sq:getY(), sq:getZ()
                end
                pcall(function() target.fx, target.fy = a:getX(), a:getY() end)
                if BridgeAnimalCare.isTended(a) then valid = true end
            end
        end
        if valid then
            BridgeTask.petValidRef, BridgeTask.petValidAt = a, tick
        else
            BridgeTask.petValidRef, BridgeTask.petValidAt = nil, nil
        end
    end
    if a == nil or not valid then
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
            if BridgeTask.petTask ~= nil and BridgeTask.petTask ~= "pet" then
                local done = tonumber(BridgeTask.petUnitsDone) or 0
                if (BridgeTask.petRetargets or 0) < MOVE_LIMIT
                        and BridgeAnimalCare.isTended(a) then
                    if done > 0 and BridgeTask.petTask == "shear" then
                        BridgeTask.petWoolGot = (BridgeTask.petWoolGot or 0) + done
                        if BridgeTask.petWoolType ~= nil then
                            BridgeTask.petWoolTypes = BridgeTask.petWoolTypes or {}
                            BridgeTask.petWoolTypes[BridgeTask.petWoolType] = true
                        end
                    end
                    finishPose(a, body)
                    BridgeTask.petRetargets = (BridgeTask.petRetargets or 0) + 1
                    local sq = sqOf(a)
                    if sq ~= nil then
                        target.x, target.y, target.z = sq:getX(), sq:getY(), sq:getZ()
                    end
                    pcall(function() target.fx, target.fy = a:getX(), a:getY() end)
                    BridgeTask.phase = "walk"
                    BridgeTask.resetWalkDest()
                    return true
                end
                finishProduct(body, a, "moved", "JobProductMoved")
                return true
            end
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
            log(string.format("walk unreachable animal=%s", tostring(BridgeAnimalCare.nameOf(a))))
            return dropWithSpeech(body, "unreachable")
        end
        if walk ~= "arrived" then return true end
        log(string.format("walk arrived animal=%s", tostring(BridgeAnimalCare.nameOf(a))))
        pcall(function() BridgeMove.stopPath(body) end)
        BridgeTask.forceIdle(body)
        local task = target.task
        if task ~= nil and not BridgeAnimalCare.taskReady(a, task) then task = nil end
        if task == nil then task = BridgeAnimalCare.taskFor(a) end
        if task == nil then
            releaseCurrent(body, a, "JobPetNotReady")
            return true
        end
        target.task = task
        if task == "pet" then
            if not BridgeAnimalCare.canPet(a) then
                releaseCurrent(body, a, "JobPetNotReady")
                return true
            end
            beginPose(body, a)
            if not applyPet(a, body) then
                return dropWithSpeech(body, "petfail")
            end
            return true
        end
        local ok, why = setupProduct(body, a, task)
        if ok then return true end
        if why == "JobNoShears" then
            sayNeedOnce("JobNoShears", "petSaidShears")
            if BridgeAnimalCare.milkInfo(a) then
                local ok2, why2 = setupProduct(body, a, "milk")
                if ok2 then
                    target.task = "milk"
                    return true
                end
                if why2 == "JobNoMilkContainer" then
                    sayNeedOnce("JobNoMilkContainer", "petSaidMilk")
                end
            end
            if beginPetFallback(body, a, target) then return true end
            releaseCurrent(body, a, nil)
            return true
        end
        if why == "JobNoMilkContainer" then
            sayNeedOnce("JobNoMilkContainer", "petSaidMilk")
            if beginPetFallback(body, a, target) then return true end
            releaseCurrent(body, a, nil)
            return true
        end
        releaseCurrent(body, a, why)
        return true
    end

    if BridgeTask.petStart == nil or BridgeTask.petTicks == nil then
        finishPose(a, body)
        BridgeTask.current = nil
        BridgeTask.phase = nil
        BridgeTask.resetWalkDest()
        return true
    end

    if BridgeTask.petTask == nil or BridgeTask.petTask == "pet" then
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

    local task = BridgeTask.petTask
    local ticks = tonumber(BridgeTask.petTicksPerUnit) or 1
    if ticks < 1 then ticks = 1 end
    local wanted = tonumber(BridgeTask.petUnitsWanted) or 0
    local done = tonumber(BridgeTask.petUnitsDone) or 0
    if done >= wanted then
        finishProduct(body, a, "done", nil)
        return true
    end
    if stressOf(a) > STRESS_LIMIT then
        finishProduct(body, a, "stress", "JobProductStress")
        return true
    end
    local age = (Bridge.time - BridgeTask.petStart) * ffMult()
    if age < (done + 1) * ticks then
        if age > BridgeTask.petTicks * 4 + PRODUCT_SLACK then
            finishProduct(body, a, "timeout", nil)
        end
        return true
    end
    if task == "milk" then
        if BridgeTask.petTool == nil or not milkFits(BridgeTask.petTool, BridgeTask.petMilkType) then
            local nextItem = BridgeAnimalCare.findMilkContainer(body, BridgeTask.petMilkType)
            if nextItem == nil then
                finishProduct(body, a, "noroom", "JobProductNoRoom")
                return true
            end
            BridgeTask.petTool = nextItem
        end
    elseif BridgeTask.petTool == nil or not BridgeAnimalCare.shearUsable(BridgeTask.petTool) then
        finishProduct(body, a, "notool", "JobNoShears")
        return true
    end
    if Bridge ~= nil and Bridge.mp == true then
        if not requestProduct(a, task) then
            finishProduct(body, a, "noreach", "JobPetNoReach")
        end
        return true
    end
    local ok, why = applyProductUnit(body, a, task)
    if not ok then
        local key = nil
        if why == "noroom" then
            key = "JobProductNoRoom"
        elseif why == "notool" then
            key = "JobNoShears"
        elseif why == "notready" then
            key = "JobProductStress"
        end
        finishProduct(body, a, why, key)
        return true
    end
    BridgeTask.petUnitsDone = done + 1
    BridgeTask.petDidWork = true
    return true
end

function BridgeAnimalCare.debugAnimal(a, op)
    if a == nil or op == nil then return false end
    if op == "calm" then pcall(function() a:setDebugStress(0) end) end
    if Bridge ~= nil and Bridge.mp == true then
        local red = nil
        if BridgeData ~= nil and BridgeData.owner ~= nil then red = BridgeData.owner() end
        if red == nil then return false end
        local id = nil
        pcall(function() id = a:getOnlineID() end)
        if id == nil then return false end
        local x, y, z = nil, nil, nil
        pcall(function() x, y, z = a:getX(), a:getY(), a:getZ() end)
        local ok = pcall(function()
            sendClientCommand(red, "Bridge", "animalDebug", { op = op, id = id, x = x, y = y, z = z })
        end)
        return ok == true
    end
    local d = dataOf(a)
    if d == nil then return false end
    if op == "calm" then return true end
    if op == "milk" then
        local max = 0
        pcall(function() max = tonumber(d:getMaxMilk()) or 0 end)
        if max <= 0 then max = 10 end
        pcall(function() d:setMaxMilkActual(max) end)
        pcall(function() d:setMilkQuantity(max) end)
        return true
    end
    if op == "wool" then
        local max = 0
        pcall(function() max = tonumber(d:getMaxWool()) or 0 end)
        pcall(function() d:setWoolQuantity(max, true) end)
        return true
    end
    return false
end

local function available(body)
    return BridgeTask ~= nil and BridgeTask.PET_ANIMALS_ENABLED == 1
end

function BridgeAnimalCare.petMissing(body)
    if BridgeTask == nil then return nil end
    local targets = {}
    if BridgeTask.current ~= nil then targets[#targets + 1] = BridgeTask.current end
    if type(BridgeTask.queue) == "table" then
        for i = 1, #BridgeTask.queue do targets[#targets + 1] = BridgeTask.queue[i] end
    end
    local needShear, needMilk = false, false
    for i = 1, #targets do
        local t = targets[i]
        local a = type(t) == "table" and t.animal or nil
        if a ~= nil then
            local task = t.task or BridgeAnimalCare.taskFor(a)
            if task == "shear" then
                needShear = true
            elseif task == "milk" then
                needMilk = true
            end
        end
    end
    if needShear and BridgeAnimalCare.findShears(body) == nil then return "shearTool" end
    if needMilk and BridgeAnimalCare.findMilkContainerAny(body) == nil then return "milkContainer" end
    return nil
end

function BridgeAnimalCare.install()
    if type(BridgeTask) == "table" and BridgeTask.kinds ~= nil then
        BridgeTask.kinds.petAnimals = {
            available = available,
            missing = BridgeAnimalCare.petMissing,
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
