BridgeAnimalsNoFear = BridgeAnimalsNoFear or {}

BridgeAnimalsNoFear.npcCalm = true

function BridgeAnimalsNoFear.isCompanionZombie(z)
    if z == nil then return false end
    local companion = rawget(_G, "BridgeCompanion")
    if type(companion) ~= "table" or type(companion.isBody) ~= "function" then return false end
    local ok, yes = pcall(companion.isBody, z)
    return ok and yes == true
end

function BridgeAnimalsNoFear.isProtectedAnimal(a)
    if a == nil then return false end
    local animal = false
    pcall(function() animal = instanceof(a, "IsoAnimal") == true end)
    if not animal then return false end
    local dead = false
    pcall(function() dead = a:isDead() == true end)
    if dead then return false end
    local wild = false
    pcall(function() wild = a:isWild() == true end)
    if wild then return false end
    local animals = rawget(_G, "BridgeAnimals")
    if type(animals) == "table" and type(animals.hostile) == "function" then
        local ok, hostile = pcall(animals.hostile, a)
        if ok and hostile == true then return false end
    end
    return true
end

function BridgeAnimalsNoFear.apply()
    local defs = AnimalDefinitions and AnimalDefinitions.animals
    if type(defs) ~= "table" then return 0, 0 end
    local n, wild = 0, 0
    for _, d in pairs(defs) do
        if type(d) == "table" then
            if d.wild == true then
                wild = wild + 1
            elseif d.fleeZombies ~= false then
                d.fleeZombies = false
                n = n + 1
            end
        end
    end
    return n, wild
end

local function applyPass()
    pcall(BridgeAnimalsNoFear.apply)
end

applyPass()

Events.OnGameBoot.Add(applyPass)

Events.OnGameStart.Add(function()
    if BridgeLog == nil or BridgeLog.on == nil or not BridgeLog.on() then return end
    local defs = AnimalDefinitions and AnimalDefinitions.animals
    local n, wild = 0, 0
    if type(defs) == "table" then
        for _, d in pairs(defs) do
            if type(d) == "table" then
                if d.wild == true then
                    wild = wild + 1
                elseif d.fleeZombies == false then
                    n = n + 1
                end
            end
        end
    end
    print("[BridgeAnimalsNoFear] fleeZombies=false species=" .. tostring(n)
        .. " wild skipped=" .. tostring(wild))
end)
