















BridgeClean = BridgeClean or {}



BridgeClean.ASH_SPRITES = {
    floors_burnt_01_1 = true,
    floors_burnt_01_2 = true,
}
BridgeClean.GLASS_PREFIX = "brokenglass"
BridgeClean.GLASS_ITEM = "Base.BrokenGlass"



BridgeClean.VINE_PREFIX = "f_wallvines_"

BridgeClean.DIRT_PREFIXES = { "overlay_grime", "trash&junk", "trash_", "d_floorleaves", "d_trash", "LS_Scraps" }


BridgeClean.BLOOD_PREFIXES = { "overlay_blood", "blood_floor", "overlay_messages", "LS_HScraps" }


BridgeClean.GRIME_PREFIXES = { "overlay_grime" }

local DIRT_PREFIXES = BridgeClean.DIRT_PREFIXES
local BLOOD_PREFIXES = BridgeClean.BLOOD_PREFIXES
local GRIME_PREFIXES = BridgeClean.GRIME_PREFIXES

local function startsWith(s, pre)
    return s ~= nil and #s >= #pre and string.sub(s, 1, #pre) == pre
end
BridgeClean.startsWith = startsWith


local function objectSpriteName(object)
    local name = nil
    pcall(function() name = object:getSprite() and object:getSprite():getName() end)
    if name == nil then pcall(function() name = object:getSpriteName() end) end
    return name
end
BridgeClean.objectSpriteName = objectSpriteName

local function spriteInSet(object, set)
    local name = objectSpriteName(object)
    return name ~= nil and set[name] == true
end





local function squareHasPrefix(square, set)
    local found = false
    if square == nil or set == nil then return false end
    pcall(function()
        local objects = square:getObjects()
        for j = 0, objects:size() - 1 do
            local object = objects:get(j)
            if object ~= nil then
                local texName = nil
                pcall(function() texName = object:getTextureName() end)
                local spriteName = nil
                pcall(function() spriteName = object:getOverlaySprite() and object:getOverlaySprite():getName() end)
                local attached = nil
                pcall(function() attached = object:getAttachedAnimSprite() end)
                for n = 1, #set do
                    local pre = set[n]
                    if startsWith(texName, pre) or startsWith(spriteName, pre) then found = true return end
                    if attached ~= nil then
                        for i = 0, attached:size() - 1 do
                            local spr = attached:get(i)
                            local pn = spr and spr:getParentSprite() and spr:getParentSprite():getName()
                            if startsWith(pn, pre) then found = true return end
                        end
                    end
                end
            end
        end
    end)
    return found
end
BridgeClean.squareHasPrefix = squareHasPrefix


local function squareDirt(square)
    return squareHasPrefix(square, DIRT_PREFIXES)
end
BridgeClean.squareDirt = squareDirt


local function squareBlood(square)
    return squareHasPrefix(square, BLOOD_PREFIXES)
end
BridgeClean.squareBlood = squareBlood


local function squareGrime(square)
    return squareHasPrefix(square, GRIME_PREFIXES)
end
BridgeClean.squareGrime = squareGrime



local function removeSquareDirt(square)
    if square == nil then return end
    pcall(function()
        local mustRemove = {}
        local objects = square:getObjects()
        for j = 0, objects:size() - 1 do
            local object = objects:get(j)
            if object ~= nil then
                local texName = nil
                pcall(function() texName = object:getTextureName() end)
                local spriteName = nil
                pcall(function() spriteName = object:getOverlaySprite() and object:getOverlaySprite():getName() end)
                local attached = nil
                pcall(function() attached = object:getAttachedAnimSprite() end)
                for n = 1, #DIRT_PREFIXES do
                    local pre = DIRT_PREFIXES[n]
                    local matched = false
                    if startsWith(texName, pre) then
                        table.insert(mustRemove, object)
                        matched = true
                    elseif startsWith(spriteName, pre) then
                        object:setOverlaySprite(nil, false)
                        matched = true
                    elseif attached ~= nil then
                        for i = 0, attached:size() - 1 do
                            local spr = attached:get(i)
                            local pn = spr and spr:getParentSprite() and spr:getParentSprite():getName()
                            if startsWith(pn, pre) then
                                object:RemoveAttachedAnim(i)
                                matched = true
                                break
                            end
                        end
                    end
                    if matched then break end
                end
            end
        end
        for n = 1, #mustRemove do
            square:RemoveTileObject(mustRemove[n])
        end
    end)
end
BridgeClean.removeSquareDirt = removeSquareDirt



local function squareAsh(square)
    local found = nil
    if square == nil then return nil end
    pcall(function()
        local floor = nil
        pcall(function() floor = square:getFloor() end)
        local objects = square:getObjects()
        for j = 0, objects:size() - 1 do
            local o = objects:get(j)
            if o ~= nil and o ~= floor then
                local live = true
                pcall(function() live = o:getObjectIndex() >= 0 end)
                if live and spriteInSet(o, BridgeClean.ASH_SPRITES) then found = o return end
            end
        end
    end)
    return found
end
BridgeClean.squareAsh = squareAsh


local function squareGlass(square)
    local found = nil
    if square == nil then return nil end
    pcall(function()
        local objects = square:getObjects()
        for j = 0, objects:size() - 1 do
            local o = objects:get(j)
            if o ~= nil then
                local live = true
                pcall(function() live = o:getObjectIndex() >= 0 end)
                local name = live and objectSpriteName(o) or nil
                if startsWith(name, BridgeClean.GLASS_PREFIX) then found = o return end
            end
        end
    end)
    return found
end
BridgeClean.squareGlass = squareGlass






local function squareVine(square)
    local foundObject, foundIndex = nil, nil
    if square == nil then return nil end
    pcall(function()
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            local attached = nil
            pcall(function() attached = object:getAttachedAnimSprite() end)
            if attached ~= nil then
                for n = 1, attached:size() do
                    local sprite = attached:get(n - 1)
                    local parentName = sprite and sprite:getParentSprite()
                        and sprite:getParentSprite():getName()
                    if startsWith(parentName, BridgeClean.VINE_PREFIX) then
                        foundObject, foundIndex = object, n - 1
                        return
                    end
                end
            end
        end
    end)
    return foundObject, foundIndex
end
BridgeClean.squareVine = squareVine


local function squareWindow(square)
    local found = nil
    if square == nil then return nil end
    pcall(function()
        local objects = square:getObjects()
        for j = 0, objects:size() - 1 do
            local o = objects:get(j)
            if o ~= nil then
                local isWindow = false
                pcall(function() isWindow = instanceof(o, "IsoWindow") end)
                if isWindow then
                    local smashed, removed = false, true
                    pcall(function() smashed = o:isSmashed() == true end)
                    pcall(function() removed = o:isGlassRemoved() == true end)
                    if smashed and not removed then found = o return end
                end
            end
        end
    end)
    return found
end
BridgeClean.squareWindow = squareWindow





local function objectSpriteName(obj)
    local n = nil
    pcall(function() n = obj:getSprite():getName() end)
    if n == nil then pcall(function() n = obj:getName() end) end
    return n
end
BridgeClean.objectSpriteName = objectSpriteName

local function isGraffitiObject(obj)
    if obj == nil then return false end
    local n = objectSpriteName(obj)
    return n ~= nil and string.find(string.lower(tostring(n)), "graffiti", 1, true) ~= nil
end
BridgeClean.isGraffitiObject = isGraffitiObject



local function graffitiObjects(square)
    local found = {}
    if square == nil then return found end
    local seen = {}
    local function add(obj)
        if obj ~= nil and seen[obj] == nil and isGraffitiObject(obj) then
            seen[obj] = true
            found[#found + 1] = obj
        end
    end
    local g = nil
    pcall(function() g = square:getGraffitiObject() end)
    add(g)
    local objects = nil
    pcall(function() objects = square:getObjects() end)
    if objects ~= nil then
        for i = 0, objects:size() - 1 do add(objects:get(i)) end
    end
    return found
end
BridgeClean.graffitiObjects = graffitiObjects

local function squareGraffiti(square)
    if square == nil then return false end
    local yes = false
    pcall(function() yes = square:haveGraffiti() == true end)
    if yes then return true end


    return #graffitiObjects(square) > 0
end
BridgeClean.squareGraffiti = squareGraffiti









local function splatOnQueue(q, x, y, z)
    if q == nil then return false, false end
    local ok, matched = pcall(function()
        local n = q:size()
        for i = 0, n - 1 do
            local s = q:get(i)
            if s ~= nil
                    and math.floor(s.x) == x
                    and math.floor(s.y) == y
                    and math.floor(s.z) == z then
                return true
            end
        end
        return false
    end)
    if not ok then return false, false end
    return matched == true, true
end

local function floorBloodHere(square)
    if square == nil then return false end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local readable, has = false, false
    pcall(function()
        local chunk = square:getChunk()
        if chunk == nil then return end
        local q = chunk.floorBloodSplats
        if q == nil then return end
        local matched, ok = splatOnQueue(q, x, y, z)
        if not ok then return end
        readable, has = true, matched
        if not has then
            local m2, ok2 = splatOnQueue(chunk.floorBloodSplatsFade, x, y, z)
            if not ok2 then readable = false return end
            has = m2
        end
    end)
    if readable then return has end
    local fb = false
    pcall(function() fb = square:haveBloodFloor() == true end)
    return fb
end
BridgeClean.floorBloodHere = floorBloodHere



local function squareStains(square)
    if square == nil then return false, false end
    local blood = false
    pcall(function() blood = square:haveBloodWall() == true end)
    blood = blood or floorBloodHere(square) or squareBlood(square)
    local grime = squareGrime(square) or squareDirt(square)
    return blood, grime
end
BridgeClean.squareStains = squareStains



local function stainIsWall(square)
    if square == nil then return false end
    local wallBlood = false
    pcall(function() wallBlood = square:haveBloodWall() == true end)
    if wallBlood then return true end
    local wall, floorDirt = false, false
    pcall(function()
        local objects = square:getObjects()
        for j = 0, objects:size() - 1 do
            local object = objects:get(j)
            if object ~= nil then
                local texName = nil
                pcall(function() texName = object:getTextureName() end)
                if startsWith(texName, "overlay_grime_wall") then wall = true end
                if startsWith(texName, "overlay_grime_floor")
                        or startsWith(texName, "d_trash")
                        or startsWith(texName, "d_floorleaves") then floorDirt = true end
            end
        end
    end)
    if floorDirt then return false end
    return wall
end
BridgeClean.stainIsWall = stainIsWall


local function squareCleanKinds(square)
    local kinds = {}
    if square == nil then return kinds end
    pcall(function()
        if squareVine(square) ~= nil then kinds[#kinds + 1] = "vine" end
        if squareWindow(square) ~= nil then kinds[#kinds + 1] = "window" end
        if squareGlass(square) ~= nil then kinds[#kinds + 1] = "glass" end
        if squareAsh(square) ~= nil then kinds[#kinds + 1] = "ashes" end
        if squareGraffiti(square) then kinds[#kinds + 1] = "graffiti" end
        local blood, grime = squareStains(square)
        if blood then kinds[#kinds + 1] = "blood" end
        if grime then kinds[#kinds + 1] = "grime" end
    end)
    return kinds
end
BridgeClean.squareCleanKinds = squareCleanKinds


local function squareCleanKind(square)
    local kinds = squareCleanKinds(square)
    return kinds[1]
end
BridgeClean.squareCleanKind = squareCleanKind





local function transmitSquare(square)
    if not isServer() then return end
    pcall(function() square:transmitModdata() end)
    pcall(function() square:transmitModData() end)
end
BridgeClean.transmitSquare = transmitSquare





function BridgeClean.applyClean(square, kind, body)
    if square == nil or kind == nil then return end
    if kind == "blood" then
        pcall(function()
            square:removeBlood(false, false)
            transmitSquare(square)
        end)
    elseif kind == "grime" then
        pcall(function()
            square:removeGrime()
            transmitSquare(square)
        end)
        pcall(function() removeSquareDirt(square) end)
    elseif kind == "ashes" then
        local obj = squareAsh(square)
        if obj ~= nil then



            local osq = square
            pcall(function() osq = obj:getSquare() or square end)
            pcall(function() triggerEvent("OnObjectAboutToBeRemoved", obj) end)
            if isServer() then
                pcall(function() osq:transmitRemoveItemFromSquare(obj) end)
            end
            pcall(function() osq:RemoveTileObject(obj) end)
            pcall(function() osq:getObjects():remove(obj) end)
            pcall(function() obj:removeFromWorld() end)
            pcall(function() osq:RecalcProperties() end)
            pcall(function() osq:RecalcAllWithNeighbours(true) end)
        end
    elseif kind == "glass" then



        local obj = squareGlass(square)
        if obj ~= nil then
            pcall(function() triggerEvent("OnObjectAboutToBeRemoved", obj) end)



            if body ~= nil then
                pcall(function() body:getInventory():AddItem(BridgeClean.GLASS_ITEM) end)
            end
            if isServer() then
                pcall(function() square:transmitRemoveItemFromSquare(obj) end)
            end
            pcall(function() square:getObjects():remove(obj) end)
        end
    elseif kind == "graffiti" then





        local doomed = graffitiObjects(square)
        pcall(function() square:removeGraffiti() end)
        for i = 1, #doomed do
            local obj = doomed[i]
            if isServer() then
                pcall(function() obj:transmitRemoveItemFromSquare() end)
            end
            pcall(function() square:RemoveTileObject(obj) end)
            pcall(function() obj:removeFromWorld() end)
        end
        pcall(function() square:RecalcProperties() end)
        pcall(function() square:RecalcAllWithNeighbours(true) end)
        transmitSquare(square)
    elseif kind == "window" then
        local w = squareWindow(square)
        if w ~= nil then
            pcall(function() w:removeBrokenGlass() end)

            pcall(function() if isServer() then w:sync() end end)

            pcall(function() w:transmitUpdatedSpriteToClients() end)
        end
    elseif kind == "vine" then




        pcall(function()
            local function clearVineOn(s)
                if s == nil then return end
                local object, index = squareVine(s)
                if object ~= nil and index ~= nil then
                    pcall(function() object:RemoveAttachedAnim(index) end)
                    if isServer() then
                        pcall(function() object:transmitUpdatedSpriteToClients() end)
                    end
                    pcall(function() s:removeErosionObject("WallVines") end)
                end
            end
            clearVineOn(square)
            local topSq = getCell():getGridSquare(square:getX(), square:getY(), square:getZ() + 1)
            clearVineOn(topSq)
            pcall(function() square:RecalcProperties() end)
            pcall(function() square:RecalcAllWithNeighbours(true) end)
        end)
    end
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeClean] loaded") end
