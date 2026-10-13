BridgePlants = BridgePlants or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgePlants] " .. tostring(text)) end end

local function objectHasFlag(object, flag)
    if object == nil or flag == nil then return false end
    local yes = false
    pcall(function()
        local props = object:getProperties()
        if props ~= nil and props:has(flag) then yes = true end
    end)
    if yes then return true end
    pcall(function()
        local sprite = object:getSprite()
        if sprite ~= nil then
            local props = sprite:getProperties()
            if props ~= nil and props:has(flag) then yes = true end
        end
    end)
    return yes
end

local function matchingObjects(square, flag)
    local out = {}
    if square == nil or flag == nil then return out end
    pcall(function()
        local objects = square:getObjects()
        if objects == nil then return end
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if object ~= nil and objectHasFlag(object, flag) then out[#out + 1] = object end
        end
    end)
    return out
end

function BridgePlants.squareGrass(square)
    if square == nil or IsoFlagType == nil then return false end
    return #matchingObjects(square, IsoFlagType.canBeRemoved) > 0
end

function BridgePlants.squareBush(square)
    if square == nil or IsoFlagType == nil then return false end
    return #matchingObjects(square, IsoFlagType.canBeCut) > 0
end

function BridgePlants.plantKinds(square)
    local kinds = {}
    if square == nil then return kinds end
    if BridgePlants.squareGrass(square) then kinds[#kinds + 1] = "grass" end
    if BridgePlants.squareBush(square) then kinds[#kinds + 1] = "bush" end
    return kinds
end

local function removeObjects(square, objects)
    for i = 1, #objects do
        local object = objects[i]
        if isServer() then
            pcall(function() square:transmitRemoveItemFromSquare(object) end)
        end
        pcall(function() square:RemoveTileObject(object) end)
        pcall(function() square:getObjects():remove(object) end)
    end
end

function BridgePlants.applyPlant(square, kind, body)
    if square == nil or kind == nil or IsoFlagType == nil then return end
    if kind == "grass" then
        local objects = matchingObjects(square, IsoFlagType.canBeRemoved)
        if #objects == 0 then return end
        removeObjects(square, objects)
        if body ~= nil and not (Bridge ~= nil and Bridge.mp == true) then
            pcall(function()
                body:getInventory():AddItems("Base.GrassTuft", ZombRand(2, 4))
            end)
        end
    elseif kind == "bush" then
        local objects = matchingObjects(square, IsoFlagType.canBeCut)
        if #objects == 0 then return end
        removeObjects(square, objects)
        if isServer() or not (Bridge ~= nil and Bridge.mp == true) then
            if ZombRand(2) == 0 then
                pcall(function() square:AddWorldInventoryItem("Base.TreeBranch2", 0, 0, 0) end)
            end
            if ZombRand(1) == 0 then
                pcall(function() square:AddWorldInventoryItem("Base.Twigs", 0, 0, 0) end)
            end
        end
    end
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgePlants] loaded") end
