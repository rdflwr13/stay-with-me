BridgeTransmogLogic = BridgeTransmogLogic or {}

local OPERATIONS = {
    transmogrify = true,
    hide = true,
    show = true,
    remove = true,
    reset = true,
    color = true,
    texture = true,
}

local REQUIRED = {
    "getItemTransmogModData",
    "setItemTransmog",
    "setClothingHidden",
    "setClothingShown",
    "removeTransmog",
    "setItemToDefault",
    "setClothingColorModdata",
    "setClothingTextureModdata",
    "isTransmoggable",
    "getClothingItemAsset",
    "createTransmogItem",
    "setWornTmogItems",
    "syncHiddenHeadgearVisual",
    "reapplyVisualsForAllWorn",
    "isTransmogItem",
    "isClothingHidden",
    "canRemoveTransmog",
    "canResetTransmog",
}

function BridgeTransmogLogic.available()
    if type(TransmogDE) ~= "table" then return false end
    for i = 1, #REQUIRED do
        if type(TransmogDE[REQUIRED[i]]) ~= "function" then return false end
    end
    return true
end

function BridgeTransmogLogic.deepCopy(value, depth)
    depth = depth or 1
    if type(value) ~= "table" or depth > 8 then return value end
    local out = {}
    for k, v in pairs(value) do
        local kt = type(k)
        if kt == "string" or kt == "number" then
            local vt = type(v)
            if vt == "table" then
                out[k] = BridgeTransmogLogic.deepCopy(v, depth + 1)
            elseif vt == "string" or vt == "number" or vt == "boolean" then
                out[k] = v
            end
        end
    end
    return out
end

local function unit(value)
    return type(value) == "number" and value >= 0 and value <= 1
end

function BridgeTransmogLogic.applyToItem(item, op, data)
    if item == nil then return false, "not found" end
    if not OPERATIONS[op] then return false, "unavailable" end
    if not BridgeTransmogLogic.available() then return false, "unavailable" end

    local call = nil
    if op == "transmogrify" then
        local target = type(data) == "table" and data.target or nil
        if type(target) ~= "string" or target == "" then return false, "not transmoggable" end
        local scriptItem = nil
        pcall(function() scriptItem = ScriptManager.instance:getItem(target) end)
        if scriptItem == nil then return false, "not transmoggable" end
        local transmoggable = false
        pcall(function() transmoggable = TransmogDE.isTransmoggable(scriptItem) == true end)
        if not transmoggable then return false, "not transmoggable" end
        call = function() TransmogDE.setItemTransmog(item, scriptItem) end
    elseif op == "hide" then
        call = function() TransmogDE.setClothingHidden(item) end
    elseif op == "show" then
        call = function() TransmogDE.setClothingShown(item) end
    elseif op == "remove" then
        call = function() TransmogDE.removeTransmog(item) end
    elseif op == "reset" then
        call = function() TransmogDE.setItemToDefault(item) end
    elseif op == "color" then
        local r = type(data) == "table" and data.r or nil
        local g = type(data) == "table" and data.g or nil
        local b = type(data) == "table" and data.b or nil
        if not (unit(r) and unit(g) and unit(b)) then return false, "unavailable" end
        call = function() TransmogDE.setClothingColorModdata(item, Color.new(r, g, b, 1)) end
    elseif op == "texture" then
        if type(data) ~= "number" or data < 0 or data ~= math.floor(data) then
            return false, "unavailable"
        end
        call = function() TransmogDE.setClothingTextureModdata(item, data) end
    end

    local ok = pcall(call)
    if not ok then return false, "unavailable" end

    local tmog = nil
    pcall(function() tmog = item:getModData().Transmog end)
    if type(tmog) ~= "table" then return false, "unavailable" end

    return true, nil
end

function BridgeTransmogLogic.findRecordByKey(list, key)
    if type(list) ~= "table" or type(key) ~= "string" then return nil end
    local fullType, occurrence = string.match(key, "^(.-)#(%d+)$")
    if fullType == nil or fullType == "" then return nil end
    occurrence = tonumber(occurrence)
    if occurrence == nil or occurrence < 1 then return nil end
    local seen = 0
    for i = 1, #list do
        local rec = list[i]
        if type(rec) == "table" and rec.t == fullType then
            seen = seen + 1
            if seen == occurrence then return rec end
        end
    end
    return nil
end

local function createItem(fullType)
    local item = nil
    pcall(function()
        if InventoryItemFactory ~= nil and type(InventoryItemFactory.CreateItem) == "function" then
            item = InventoryItemFactory.CreateItem(fullType)
        end
    end)
    if item == nil then
        pcall(function() item = instanceItem(fullType) end)
    end
    return item
end

function BridgeTransmogLogic.makeTempItem(record, seed)
    if type(record) ~= "table" or type(record.t) ~= "string" then return nil end
    local item = createItem(record.t)
    if item == nil then return nil end

    local copy = {}
    for k, v in pairs(record) do
        if k ~= "item" then
            if type(v) == "table" then
                copy[k] = BridgeTransmogLogic.deepCopy(v)
            else
                copy[k] = v
            end
        end
    end
    pcall(function() BridgeItems.apply(item, copy) end)

    local tmog = nil
    if type(seed) == "table" then
        tmog = BridgeTransmogLogic.deepCopy(seed)
    elseif type(copy.md) == "table" and type(copy.md.Transmog) == "table" then
        tmog = BridgeTransmogLogic.deepCopy(copy.md.Transmog)
    end
    if type(tmog) == "table" then
        tmog.childId = nil
        pcall(function() item:getModData().Transmog = tmog end)
    end

    return item
end

function BridgeTransmogLogic.visualRecord(record)
    if type(record) ~= "table" or type(record.md) ~= "table" then return nil end
    local tmog = record.md.Transmog
    if type(tmog) ~= "table" then return nil end
    local target = tmog.transmogTo
    if target == nil then return false end
    if type(target) ~= "string" or target == "" then return nil end

    local color = type(tmog.color) == "table" and tmog.color or nil
    local texture = type(tmog.texture) == "number" and tmog.texture or nil
    local sameType = target == record.t

    local colorSame = true
    if color ~= nil then
        local original = type(tmog.originalColor) == "table" and tmog.originalColor or nil
        if original == nil then
            colorSame = false
        else
            colorSame = color.r == original.r and color.g == original.g and color.b == original.b
                and (color.a or 1) == (original.a or 1)
        end
    end

    local textureSame = true
    if texture ~= nil and texture >= 0 then
        local original = tonumber(tmog.originalTexture)
        textureSame = original ~= nil and texture == original
    end

    if sameType and colorSame and textureSame then return nil end

    local copy = {}
    for k, v in pairs(record) do copy[k] = v end
    copy.md = nil
    copy.item = nil
    copy.t = target

    if color ~= nil and not colorSame then
        copy.r, copy.g, copy.b = color.r, color.g, color.b
    end

    if texture ~= nil and texture >= 0 and not textureSame then
        local hasModel = false
        pcall(function()
            local scriptItem = ScriptManager.instance:getItem(target)
            if scriptItem ~= nil then
                local asset = TransmogDE.getClothingItemAsset(scriptItem)
                if asset ~= nil then hasModel = asset:hasModel() == true end
            end
        end)
        if hasModel then
            copy.tc, copy.bt = texture, nil
        else
            copy.bt, copy.tc = texture, nil
        end
    end

    return copy
end

local function sameColor(a, b)
    if a == nil and b == nil then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    return a.r == b.r and a.g == b.g and a.b == b.b and (a.a or 1) == (b.a or 1)
end

function BridgeTransmogLogic.isDefaultTransmog(fullType, md)
    local tmog = type(md) == "table" and md.Transmog or nil
    if type(tmog) ~= "table" then return false end
    if tmog.transmogTo == nil then return false end
    if type(fullType) ~= "string" or tmog.transmogTo ~= fullType then return false end
    if tmog.lastTransmogTo ~= nil and tmog.lastTransmogTo ~= tmog.transmogTo then return false end
    if tmog.texture ~= tmog.originalTexture then return false end
    if not sameColor(tmog.color, tmog.originalColor) then return false end
    for k in pairs(tmog) do
        if k ~= "transmogTo" and k ~= "lastTransmogTo" and k ~= "texture"
            and k ~= "originalTexture" and k ~= "color" and k ~= "originalColor"
            and k ~= "childId" then
            return false
        end
    end
    return true
end

function BridgeTransmogLogic.prepareModData(item, md)
    if type(md) ~= "table" or md.Transmog == nil then return end
    local fullType = nil
    pcall(function() fullType = item:getFullType() end)
    if BridgeTransmogLogic.isDefaultTransmog(fullType, md) then
        md.Transmog = nil
    end
end

if BridgeItems ~= nil then
    BridgeItems.prepareModData = BridgeTransmogLogic.prepareModData
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function()
        if BridgeItems ~= nil then
            BridgeItems.prepareModData = BridgeTransmogLogic.prepareModData
        end
    end)
end

return BridgeTransmogLogic
