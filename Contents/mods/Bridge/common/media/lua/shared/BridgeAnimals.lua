
BridgeAnimals = BridgeAnimals or {}

local function modActive(id)
    local on = false
    pcall(function() on = getActivatedMods():contains(id) == true end)
    return on
end

BridgeAnimals.wanted = modActive("VRaptor") or modActive("WolfPredator")

local function isDead(a)
    local dead = false
    pcall(function() dead = a:isDead() == true end)
    return dead
end

local function companionAnimal(a)
    local cd = false
    pcall(function() cd = a:hasModData() and a:getModData().CompanionDogs ~= nil end)
    return cd
end

local function leashed(a)
    local on = false
    pcall(function() on = a:getData():getAttachedPlayer() ~= nil end)
    return on
end

local function isPredatorDino(a)
    if VDinoSpecies == nil or VDinoSpecies.isDinosaur == nil then return false end
    local isDino = false
    pcall(function() isDino = VDinoSpecies.isDinosaur(a) == true end)
    if not isDino then return false end
    local profile = nil
    pcall(function() profile = VDinoSpecies.get(a) end)
    return profile ~= nil and profile.role == "predator"
end

local function isWolf(a)
    if WolfPredatorAI == nil or WolfPredatorAI.isWolf == nil then return false end
    local wolf = false
    pcall(function() wolf = WolfPredatorAI.isWolf(a) == true end)
    return wolf
end

function BridgeAnimals.hostile(a)
    if a == nil then return false end
    if isDead(a) then return false end
    if companionAnimal(a) or leashed(a) then return false end
    if isPredatorDino(a) then return true end
    if isWolf(a) then return true end
    return false
end

function BridgeAnimals.attack(a, dmg, attacker)
    if a == nil then return end
    if isClient() then
        local owner = nil
        if BridgeData ~= nil and BridgeData.owner ~= nil then owner = BridgeData.owner() end
        if owner == nil then return end
        local id = nil
        pcall(function() id = a:getOnlineID() end)
        if id == nil then return end
        pcall(function() sendClientCommand(owner, "Bridge", "animalHit", { id = id, dmg = dmg }) end)
        return
    end
    BridgeAnimals.apply(a, dmg, attacker)
end

function BridgeAnimals.apply(a, dmg, attacker)
    if a == nil then return end
    if isDead(a) then return end
    dmg = tonumber(dmg) or 0
    if dmg <= 0 then return end

    local isDino = false
    if VDinoSpecies ~= nil and VDinoSpecies.isDinosaur ~= nil then
        pcall(function() isDino = VDinoSpecies.isDinosaur(a) == true end)
    end
    if isDino and VDinoTargetDamage ~= nil and VDinoTargetDamage.dinosaur ~= nil then
        pcall(function() VDinoTargetDamage.dinosaur(a, dmg, attacker) end)
        return
    end

    pcall(function() a:setAttackedBy(getFakeAttacker()) end)
    pcall(function() a:addBlood(nil, false, false, false) end)
    local hp = 0
    pcall(function() hp = a:getHealth() end)
    pcall(function() a:setHealth(math.max(0, (tonumber(hp) or 0) - dmg)) end)
end
