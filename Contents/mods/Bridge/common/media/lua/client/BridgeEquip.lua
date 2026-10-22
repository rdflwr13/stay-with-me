
require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISComboBox"
require "ISUI/ISUI3DModel"
require "ISUI/ISToolTipInv"
require "ISUI/ISMouseDrag"

BridgeEquip = BridgeEquip or {}

local DEV_PHASE = "P1"
local function log(text)
    if BridgeEquip.DEV or (BridgeLog ~= nil and BridgeLog.on()) then
        print("[BridgeEquip][" .. tostring(DEV_PHASE) .. "] " .. tostring(text))
    end
end
local function warn(text) print("[BridgeEquip][!] " .. tostring(text)) end

local function tr(key, a, b)
    if BridgeData ~= nil and type(BridgeData.text) == "function" then return BridgeData.text(key, a, b) end
    local out = key
    pcall(function()
        if b ~= nil then out = getText("IGUI_NotAlone_" .. key, a, b)
        elseif a ~= nil then out = getText("IGUI_NotAlone_" .. key, a)
        else out = getText("IGUI_NotAlone_" .. key) end
    end)
    return out
end

local function gameText(key, fallback)
    local out = nil
    pcall(function() out = getTextOrNull(key) end)
    if out == nil or out == "" then return fallback end
    return out
end

BridgeEquip.DEV = false

BridgeEquip.range = 2.5


local BASE = {
    PANEL_WIDTH = 220,
    X_OFFSET = 44,
    DOLL_W = 123,
    DOLL_H = 302,
    HEADER_LINE_Y = 12,
    SLOT_SIZE = 34,
    SUPER_SLOT_SIZE = 38,
    SUPER_SLOT_SUB_ITEM_WIDTH = 12,
    SUPER_SLOT_VERTICAL_OFFSET = 10,
    WEAPON_SLOT_SIZE = 46,
    DYN_MARGIN = 4,
    DYN_X = 16,
    HOTBAR_MARGIN = 4,
    BOTTOM_PADDING = 8,
    MINI_ICON_SCALE = 0.375,
    MINI_ICON_SIZE = 12,
    HOTBAR_PER_ROW = 5,
    DYN_PER_ROW = 5,
    SUB_SLOT_THING = 5,
    WEAPON_PRIMARY_X = -18,
    WEAPON_PRIMARY_Y = 142,
    WEAPON_GUN_RIGHT = 12,
    WEAPON_GUN_TOP = 10,
}

BridgeEquip.BASE = BASE
BridgeEquip.L = {}
BridgeEquip.onScale = {}


BridgeEquip.DEFAULT_COLORS = {
    GOOD = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },
    MIDDLE = { r = 1.0, g = 1.0, b = 0.0, a = 1.0 },
    BAD = { r = 1.0, g = 0.0, b = 0.0, a = 1.0 },
}
BridgeEquip.COLORBLIND_COLORS = {
    GOOD = { r = 0.000, g = 0.447, b = 0.698, a = 1.0 },
    MIDDLE = { r = 0.941, g = 0.894, b = 0.259, a = 1.0 },
    BAD = { r = 0.835, g = 0.369, b = 0.000, a = 1.0 },
}
BridgeEquip.colors = BridgeEquip.DEFAULT_COLORS

function BridgeEquip.setColorblind(on)
    BridgeEquip.colorblind = on == true
    BridgeEquip.colors = BridgeEquip.colorblind and BridgeEquip.COLORBLIND_COLORS or BridgeEquip.DEFAULT_COLORS
end


local function her()
    if Bridge == nil or type(Bridge.alive) ~= "function" or not Bridge.alive() then return nil end
    if Bridge.kind ~= "zombie" then return nil end
    return Bridge.body
end
BridgeEquip.her = her

local function playerOf(n)
    local p = nil
    pcall(function() p = getSpecificPlayer(n or 0) end)
    if p == nil then pcall(function() p = getPlayer() end) end
    return p
end
BridgeEquip.playerOf = playerOf

local function herName()
    local n = nil
    pcall(function() if Bridge ~= nil and Bridge.companionName ~= nil then n = Bridge.companionName() end end)
    if type(n) ~= "string" or n == "" then n = "Rin" end
    return n
end


BridgeEquip.REGIONS = {
    { id = "head", x = 44, y = 4, locs = { "HAT", "FULL_HAT", "SCARF", "NECK", "NECK_TEXTURE", "GORGET" } },
    { id = "face", x = 100, y = 16, locs = { "SCBA", "SCBANOTANK", "MASK", "MASK_EYES", "MASK_FULL", "EYES",
        "LEFT_EYE", "RIGHT_EYE", "MAKE_UP_FULL_FACE", "MAKE_UP_EYES", "MAKE_UP_EYES_SHADOW", "MAKE_UP_LIPS" } },
    { id = "torso", x = 44, y = 58, locs = { "FULL_ROBE", "BOILERSUIT", "FULL_SUIT", "FULL_SUIT_HEAD",
        "FULL_SUIT_HEAD_SCBA", "FULL_TOP", "BATH_ROBE", "JACKET", "JACKET_BULKY", "JACKET_DOWN", "JACKET_HAT",
        "JACKET_HAT_BULKY", "JACKET_SUIT", "JERSEY", "SWEATER", "SWEATER_HAT", "DRESS", "LONG_DRESS",
        "VEST_TEXTURE", "TORSO1LEGS1", "TORSO1", "SHIRT", "SHORT_SLEEVE_SHIRT", "TSHIRT", "TANK_TOP",
        "UNDERWEAR_TOP", "CUIRASS", "BODY_COSTUME" } },
    { id = "vest", x = 106, y = 72, locs = { "SATCHEL", "WEBBING", "SHOULDER_HOLSTER", "AMMO_STRAP",
        "TORSO_EXTRA_VEST_BULLET", "TORSO_EXTRA_VEST", "TORSO_EXTRA", "SHOULDERPAD_LEFT", "SHOULDERPAD_RIGHT",
        "SPORT_SHOULDERPAD", "SPORT_SHOULDERPAD_ON_TOP" } },
    { id = "back", x = -14, y = 16, locs = { "BACK", "TAIL" } },
    { id = "waist", x = 44, y = 128, locs = { "FANNY_PACK_FRONT", "FANNY_PACK_BACK", "BELT", "BELT_EXTRA", "CODPIECE" } },
    { id = "left_hand", x = 100, y = 206, locs = { "HANDS", "HANDS_LEFT", "LEFT_WRIST", "LEFT_MIDDLE_FINGER",
        "LEFT_RING_FINGER", "LEFT_ARM", "ELBOW_LEFT", "FORE_ARM_LEFT" } },
    { id = "right_hand", x = -14, y = 206, locs = { "HANDS", "HANDS_RIGHT", "RIGHT_WRIST", "RIGHT_RING_FINGER",
        "RIGHT_MIDDLE_FINGER", "RIGHT_ARM", "ELBOW_RIGHT", "FORE_ARM_RIGHT" } },
    { id = "jewelry", x = -20, y = 72, locs = { "NECKLACE", "NECKLACE_LONG", "EARS", "EAR_TOP", "NOSE", "BELLY_BUTTON" } },
    { id = "legs", x = 44, y = 202, locs = { "LONG_SKIRT", "SKIRT", "PANTS", "PANTS_EXTRA", "PANTS_SKINNY",
        "SHORT_PANTS", "SHORTS_SHORT", "LEGS5", "LEGS1", "UNDERWEAR", "UNDERWEAR_BOTTOM", "UNDERWEAR_EXTRA1",
        "UNDERWEAR_EXTRA2", "THIGH_LEFT", "THIGH_RIGHT", "KNEE_LEFT", "KNEE_RIGHT" } },
    { id = "feet", x = 44, y = 272, locs = { "ANKLE_HOLSTER", "SHOES", "SOCKS", "CALF_LEFT", "CALF_RIGHT",
        "CALF_LEFT_TEXTURE", "CALF_RIGHT_TEXTURE", "GAITER_LEFT", "GAITER_RIGHT" } },
    { id = "fur", x = 106, y = 128, locs = { "FUR" } },
}

local function furRegionOf()
    for _, r in ipairs(BridgeEquip.REGIONS) do
        if r.id == "fur" then return r end
    end
    return nil
end

local function furLocationId(v)
    if v == nil then return nil end
    local s = nil
    pcall(function() s = tostring(v) end)
    if type(s) ~= "string" then return nil end
    s = string.lower(s)
    local colon = string.find(s, ":", 1, true)
    if colon ~= nil then s = string.sub(s, colon + 1) end
    if string.find(s, "fur", 1, true) == nil then return nil end
    return v
end

local function asItemBodyLocation(v)
    if v == nil then return nil end
    if type(v) ~= "string" then return furLocationId(v) end
    local out = nil
    pcall(function()
        if type(ItemBodyLocation) == "table" and type(ResourceLocation) == "table"
            and type(ItemBodyLocation.get) == "function" and type(ResourceLocation.of) == "function" then
            out = ItemBodyLocation.get(ResourceLocation.of(v))
        end
        if out == nil then out = ItemBodyLocation[string.upper(v)] end
    end)
    return furLocationId(out)
end

local function addFurVal(vals, seen, v)
    v = asItemBodyLocation(v)
    if v == nil then return end
    local key = nil
    pcall(function() key = tostring(v) end)
    if type(key) ~= "string" then return end
    if seen[key] then return end
    seen[key] = true
    vals[#vals + 1] = v
end

local function furLocFromGroup(group)
    if group == nil then return nil end
    local n = nil
    pcall(function() n = group:size() end)
    if type(n) ~= "number" then return nil end
    for i = 0, n - 1 do
        local bl = nil
        pcall(function() bl = group:getLocationByIndex(i) end)
        if bl ~= nil then
            local id = nil
            pcall(function() id = bl:getId() end)
            if furLocationId(id) ~= nil then return id end
        end
    end
    return nil
end

function BridgeEquip.primeFurRegion()
    local region = furRegionOf()
    if region == nil or region._vals ~= nil then return end
    local vals, seen = {}, {}
    pcall(function()
        if type(FurManager) == "table" then
            addFurVal(vals, seen, FurManager.furItemBodyLocation)
        end
    end)
    if #vals == 0 then
        pcall(function()
            if BodyLocations ~= nil and type(BodyLocations.getGroup) == "function" then
                addFurVal(vals, seen, furLocFromGroup(BodyLocations.getGroup("Human")))
            end
        end)
    end
    if #vals == 0 then
        pcall(function()
            local b = her()
            if b ~= nil then
                local worn = b:getWornItems()
                if worn ~= nil then
                    for i = 0, worn:size() - 1 do
                        local it = worn:getItemByIndex(i)
                        if it ~= nil then
                            local loc = nil
                            pcall(function() loc = it:getBodyLocation() end)
                            addFurVal(vals, seen, loc)
                        end
                    end
                end
            end
        end)
    end
    if #vals > 0 then region._vals = vals end
end

local function enumOf(name)
    local v = nil
    pcall(function() v = ItemBodyLocation[name] end)
    if v == nil then return nil end
    return v
end

local function regionValues(region)
    if region.id == "fur" then BridgeEquip.primeFurRegion() end
    if region._vals ~= nil then return region._vals end
    local vals = {}
    for _, name in ipairs(region.locs) do
        local v = enumOf(name)
        if v ~= nil then vals[#vals + 1] = v end
    end
    region._vals = vals
    return vals
end

local function locInRegion(region, loc)
    if loc == nil then return false end
    for _, v in ipairs(regionValues(region)) do
        if v == loc then return true end
    end
    return false
end
BridgeEquip.locInRegion = locInRegion

local function itemLoc(item)
    if item == nil then return nil end
    local loc = nil
    pcall(function() loc = item:getBodyLocation() end)
    if loc == nil or loc == "" then pcall(function() loc = item:canBeEquipped() end) end
    return loc
end
BridgeEquip.itemLoc = itemLoc

local function spnccTag(name)
    if type(SPNCC) ~= "table" or SPNCC.ItemTag == nil then return nil end
    local t = nil
    pcall(function() t = SPNCC.ItemTag[name] end)
    return t
end

local function hasTag(item, name)
    local tag = spnccTag(name)
    if tag == nil then return false end
    local yes = false
    pcall(function() yes = item:hasTag(tag) == true end)
    return yes
end

local function isAppearance(item)
    if item == nil then return false end
    if hasTag(item, "Face") or hasTag(item, "BodyDetail") or hasTag(item, "Muscle") then return true end
    local loc = nil
    pcall(function() loc = item:getBodyLocation() end)
    if loc ~= nil then
        local id = tostring(loc)
        if string.find(id, "MakeUp", 1, true) ~= nil then return true end
        local nm = nil
        pcall(function() nm = loc:getTranslationName() end)
        if type(nm) == "string" and string.sub(nm, 1, 6) == "MakeUp" then return true end
    end
    if BridgeData ~= nil and type(BridgeData.spnccMuscleTypes) == "function" then
        local types = nil
        pcall(function() types = BridgeData.spnccMuscleTypes() end)
        if types ~= nil then
            local ft = nil
            pcall(function() ft = item:getFullType() end)
            if ft ~= nil then
                for _, tid in ipairs(types) do if tid == ft then return true end end
            end
        end
    end
    return false
end
BridgeEquip.isAppearance = isAppearance

local function isFurAppearance(item)
    if item == nil then return false end
    local loc = nil
    pcall(function() loc = item:getBodyLocation() end)
    if loc ~= nil then
        local s = nil
        pcall(function() s = tostring(loc) end)
        if type(s) == "string" and string.find(string.lower(s), "fur", 1, true) ~= nil then return true end
    end
    local t = nil
    pcall(function() t = item:getType() end)
    if type(t) == "string" and string.find(string.lower(t), "furry", 1, true) ~= nil then return true end
    local ft = nil
    pcall(function() ft = item:getFullType() end)
    if type(ft) == "string" and string.find(string.lower(ft), "furry", 1, true) ~= nil then return true end
    return false
end
BridgeEquip.isFurAppearance = isFurAppearance

local function itemLocs(item)
    local set = {}
    if item == nil then return set end
    pcall(function() local v = item:getBodyLocation() if v ~= nil then set[#set + 1] = v end end)
    pcall(function() local v = item:canBeEquipped() if v ~= nil then set[#set + 1] = v end end)
    return set
end
BridgeEquip.itemLocs = itemLocs

local function anyLocInRegion(region, locs)
    for _, l in ipairs(locs or {}) do if locInRegion(region, l) then return true end end
    return false
end
BridgeEquip.anyLocInRegion = anyLocInRegion

local function wornItems(b)
    local out = {}
    if b == nil then return out end
    pcall(function()
        local w = b:getWornItems()
        for i = 0, w:size() - 1 do
            local worn = w:get(i)
            if worn ~= nil then
                local it = nil
                pcall(function() it = worn:getItem() end)
                if it ~= nil and not isAppearance(it) then
                    local locs = {}
                    pcall(function() local v = worn:getLocation() if v ~= nil then locs[#locs + 1] = v end end)
                    for _, v in ipairs(itemLocs(it)) do locs[#locs + 1] = v end
                    out[#out + 1] = { item = it, loc = locs[1], locs = locs }
                end
            end
        end
    end)
    return out
end
BridgeEquip.wornItems = wornItems

local function displayWorn(b)
    local out = {}
    for _, w in ipairs(wornItems(b)) do
        if not isFurAppearance(w.item) then out[#out + 1] = w end
    end
    return out
end

local function regionItems(b, region)
    local out = {}
    local worn = displayWorn(b)
    for _, v in ipairs(regionValues(region)) do
        if v ~= nil then
            for _, w in ipairs(worn) do
                local hit = false
                for _, l in ipairs(w.locs or {}) do if l == v then hit = true break end end
                if hit then out[#out + 1] = w.item break end
            end
        end
    end
    return out
end
BridgeEquip.regionItems = regionItems

local function providerMounts(b, item)
    local out = {}
    if b == nil or item == nil or BridgeGear == nil or BridgeGear.attached == nil then return out end
    local pid = nil
    pcall(function() pid = item:getID() end)
    if pid == nil then return out end
    local entries = {}
    for mounted, info in pairs(BridgeGear.attached) do
        if info ~= nil and info.body == b and info.providerId == pid then
            entries[#entries + 1] = { item = mounted, index = info.index or 0, loc = tostring(info.location or "") }
        end
    end
    table.sort(entries, function(a, c)
        if a.loc ~= c.loc then return a.loc < c.loc end
        return a.index < c.index
    end)
    for _, e in ipairs(entries) do out[#out + 1] = e.item end
    return out
end
BridgeEquip.providerMounts = providerMounts
BridgeEquip.mountsOf = providerMounts

local function regionLayers(b, region)
    local out = {}
    local worn = displayWorn(b)
    for _, v in ipairs(regionValues(region)) do
        if v ~= nil then
            for _, w in ipairs(worn) do
                local hit = false
                for _, l in ipairs(w.locs or {}) do if l == v then hit = true break end end
                if hit then
                    out[#out + 1] = w.item
                    for _, m in ipairs(providerMounts(b, w.item)) do out[#out + 1] = m end
                    break
                end
            end
        end
    end
    return out
end
BridgeEquip.regionLayers = regionLayers

local function unmappedWorn(b)
    local out = {}
    for _, w in ipairs(displayWorn(b)) do
        local mapped = false
        for _, region in ipairs(BridgeEquip.REGIONS) do
            if anyLocInRegion(region, w.locs) then mapped = true break end
        end
        if not mapped then out[#out + 1] = w.item end
    end
    return out
end
BridgeEquip.unmappedWorn = unmappedWorn

local function weaponItem(b)
    if b == nil then return nil end
    local item = nil
    pcall(function() if BridgeWeapon ~= nil then item = BridgeWeapon.assigned(b) end end)
    if item == nil then pcall(function() item = b:getPrimaryHandItem() end) end
    return item
end
BridgeEquip.weaponItem = weaponItem

local function gearCells(b)
    local out = { { type = "Back", providerId = nil, providerName = nil, providerType = nil,
                    nameKey = "IGUI_HotbarAttachment_Back", name = "Back" } }
    if b == nil or ISHotbarAttachDefinition == nil then return out end
    local defs = {}
    for _, def in ipairs(ISHotbarAttachDefinition) do defs[def.type] = def end
    local seen = {}
    pcall(function()
        local worn = b:getWornItems()
        for i = 0, worn:size() - 1 do
            local w = worn:getItemByIndex(i)
            if w ~= nil then
                local provided = nil
                pcall(function() provided = w:getAttachmentsProvided() end)
                if provided ~= nil then
                    for j = 0, provided:size() - 1 do
                        local t = provided:get(j)
                        local pid = nil
                        pcall(function() pid = w:getID() end)
                        local key = tostring(pid) .. "|" .. tostring(t)
                        if not seen[key] then
                            seen[key] = true
                            local def = defs[t]
                            if def ~= nil then
                                local pname, ptype = nil, nil
                                pcall(function() pname = w:getName() end)
                                pcall(function() ptype = w:getType() end)
                                out[#out + 1] = { type = t, providerId = pid, providerName = pname, providerType = ptype,
                                                  def = def, nameKey = "IGUI_HotbarAttachment_" .. tostring(t),
                                                  name = def.name or t }
                            end
                        end
                    end
                end
            end
        end
    end)
    return out
end
BridgeEquip.gearCells = gearCells

local function cellLabel(cell)
    if cell == nil then return "" end
    local t = nil
    pcall(function() t = getTextOrNull(cell.nameKey) end)
    if t == nil or t == "" then t = cell.name or cell.type end
    return t
end
BridgeEquip.cellLabel = cellLabel

local function cellSlotFor(b, item, cell)
    if b == nil or item == nil or cell == nil or BridgeGear == nil then return nil end
    for _, s in ipairs(BridgeGear.slotsFor(b, item)) do
        if s.type == cell.type and s.providerId == cell.providerId then return s end
    end
    return nil
end
BridgeEquip.cellSlotFor = cellSlotFor

local function variantFor(region, item)
    if region == nil or item == nil or BridgeInventory == nil then return nil end
    local v = BridgeInventory.variants(item)
    for _, entry in ipairs(v.list or {}) do
        local ni = nil
        pcall(function() ni = instanceItem(entry.t) end)
        if ni ~= nil then
            if locInRegion(region, itemLoc(ni)) then return entry.t end
        end
    end
    return nil
end
BridgeEquip.variantFor = variantFor

local function regionAccepts(region, item)
    if region == nil or item == nil then return false end
    if BridgeInventory ~= nil then
        local loc = itemLoc(item)
        if locInRegion(region, loc) then
            if type(BridgeInventory.canWear) == "function" and BridgeInventory.canWear(item) then return true end
        end
    end
    return variantFor(region, item) ~= nil
end
BridgeEquip.regionAccepts = regionAccepts


local function fontClearance()
    local h = 14
    pcall(function() h = getTextManager():getFontHeight(UIFont.Small) end)
    if type(h) ~= "number" or h ~= h then h = 14 end
    return BASE.HEADER_LINE_Y + h / 2 + 6
end

function BridgeEquip.scaleValue()
    local s = 1
    pcall(function() if getCore() ~= nil then s = getCore():getOptionFontSizeReal() end end)
    if type(s) ~= "number" or s ~= s or s <= 0 then s = 1 end
    local u = 1
    pcall(function() if BridgeData ~= nil and Bridge ~= nil then u = BridgeData.equipScale(Bridge.store) end end)
    if type(u) ~= "number" or u ~= u or u <= 0 then u = 1 end
    return s * u
end

function BridgeEquip.subscribeScale(cb)
    if type(cb) ~= "function" then return end
    BridgeEquip.onScale[#BridgeEquip.onScale + 1] = cb
end

function BridgeEquip.applyScale(S)
    S = S or BridgeEquip.scaleValue()
    local c = fontClearance()
    local L = { S = S, clearance = c }
    L.PANEL_WIDTH = BASE.PANEL_WIDTH * S
    L.X_OFFSET = BASE.X_OFFSET * S
    L.DOLL_W, L.DOLL_H = BASE.DOLL_W, BASE.DOLL_H
    L.Y_OFFSET = math.max(24 * S, c - 4 * S)
    L.BOTTOM_PADDING = BASE.BOTTOM_PADDING * S
    L.SLOT_SIZE = BASE.SLOT_SIZE * S
    L.SUPER_SLOT_SIZE = BASE.SUPER_SLOT_SIZE * S
    L.SUPER_SLOT_SUB_ITEM_WIDTH = BASE.SUPER_SLOT_SUB_ITEM_WIDTH * S
    L.SUPER_SLOT_VERTICAL_OFFSET = BASE.SUPER_SLOT_VERTICAL_OFFSET * S
    L.WEAPON_SLOT_SIZE = BASE.WEAPON_SLOT_SIZE * S
    L.DYN_MARGIN = BASE.DYN_MARGIN * S
    L.DYN_X = BASE.DYN_X * S
    L.HOTBAR_MARGIN = BASE.HOTBAR_MARGIN * S
    L.DYN_Y = L.Y_OFFSET + (BASE.DOLL_H + 6) * S
    L.DYN_STEP = L.SLOT_SIZE + L.DYN_MARGIN
    L.HOTBAR_Y_OFFSET = math.max(26 * S, c)
    L.MINI_ICON_SIZE = BASE.MINI_ICON_SIZE * S
    L.SUB_SLOT_THING = BASE.SUB_SLOT_THING * S
    L.DYN_PER_ROW = BASE.DYN_PER_ROW
    L.HOTBAR_PER_ROW = BASE.HOTBAR_PER_ROW
    BridgeEquip.L = L

    local subs = {}
    for i = 1, #BridgeEquip.onScale do subs[i] = BridgeEquip.onScale[i] end
    for _, cb in ipairs(subs) do pcall(cb, S) end
    if BridgeEquip.instance ~= nil then pcall(function() BridgeEquip.instance:relayout() end) end
    return L
end


local function draggedItem()
    if ISMouseDrag == nil then return nil end
    local d = ISMouseDrag.dragging
    if d == nil then return nil end
    if instanceof(d, "InventoryItem") then return d end
    if d.items ~= nil then return d.items[1] end
    if ISInventoryPane ~= nil and ISInventoryPane.getActualItems ~= nil then
        local list = ISInventoryPane.getActualItems(d)
        if list ~= nil and list[1] ~= nil then return list[1] end
    end
    return d[1]
end
BridgeEquip.draggedItem = draggedItem

local function clearDrag()
    local source = BridgeEquip.drag ~= nil and BridgeEquip.drag.source or nil
    if ISMouseDrag ~= nil then
        local focus = ISMouseDrag.draggingFocus
        if focus ~= nil and focus ~= BridgeEquip.drag then
            pcall(function()
                focus.dragging = nil
                focus.dragStarted = false
                if focus.draggedItems ~= nil then focus.draggedItems:reset() end
            end)
        end
        ISMouseDrag.dragging = nil
        ISMouseDrag.draggingFocus = nil
    end
    BridgeEquip.drag = nil
    if source ~= nil then
        source.dragArmed = false
        source.dragItem = nil
    end
end
BridgeEquip.clearDrag = clearDrag

local function startDragSource(widget, item, kind)
    if item == nil then return end
    BridgeEquip.drag = { item = item, kind = kind, source = widget }
    if ISMouseDrag ~= nil then
        ISMouseDrag.dragging = { item }
        ISMouseDrag.draggingFocus = nil
    end
end
BridgeEquip.startDragSource = startDragSource

local function paneUnderCursor()
    local found = nil
    local function live(pane)
        if pane == nil then return false end
        local yes = false
        pcall(function() yes = pane:isVisible() and pane:isMouseOver() and pane.inventory ~= nil end)
        return yes
    end
    pcall(function()
        local page = getPlayerInventory(0)
        if page ~= nil and live(page.inventoryPane) then found = page.inventoryPane return end
    end)
    if found == nil then
        pcall(function()
            local loot = getPlayerLoot(0)
            if loot ~= nil and live(loot.inventoryPane) then found = loot.inventoryPane end
        end)
    end
    return found
end
BridgeEquip.paneUnderCursor = paneUnderCursor

local function overAnyUI()
    local mx, my = getMouseX(), getMouseY()
    local yes = false
    pcall(function()
        local uis = UIManager.getUI()
        for i = 0, uis:size() - 1 do
            local ui = uis:get(i)
            if ui ~= nil and ui:isPointOver(mx, my) then yes = true return end
        end
    end)
    return yes
end

local function takeOff(b, item, kind)
    if b == nil or item == nil then return end
    pcall(function()
        local isGear, isWeapon = false, false
        if BridgeGear ~= nil and type(BridgeGear.isGear) == "function" then isGear = BridgeGear.isGear(b, item) == true end
        if BridgeWeapon ~= nil and type(BridgeWeapon.isAssigned) == "function" then isWeapon = BridgeWeapon.isAssigned(b, item) == true end
        if isWeapon and not isGear then
            BridgeInventory.drop(b, item)
        elseif isGear then
            BridgeGear.detach(b, item)
        else
            BridgeInventory.unwear(b, item)
        end
    end)
end
BridgeEquip.takeOff = takeOff

local function playerContainer(inv)
    local p = playerOf(0)
    local yes = false
    pcall(function() yes = inv:isInCharacterInventory(p) end)
    return yes
end

local function routeOut(b, item, kind)
    if b == nil or item == nil then return end
    local player = playerOf(0)
    local pane = paneUnderCursor()
    if pane ~= nil then
        local inv = pane.inventory
        if inv == nil then takeOff(b, item, kind) return end
        local hers = false
        pcall(function() hers = BridgeInventory.isHers(inv) end)
        takeOff(b, item, kind)
        if hers then return end
        if player == nil then return end
        local src = nil
        pcall(function() src = item:getContainer() end)
        if src == nil then return end
        pcall(function()
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, src, inv))
        end)
        return
    end
    takeOff(b, item, kind)
    if player ~= nil and not overAnyUI() then
        pcall(function() ISInventoryPaneContextMenu.dropItem(item, 0) end)
    end
end
BridgeEquip.routeOut = routeOut

function BridgeEquip.resolveDrop(targetWidget)
    local drag = BridgeEquip.drag
    local item = drag ~= nil and drag.item or nil
    local kind = drag ~= nil and drag.kind or nil
    if item == nil then item = draggedItem() end
    clearDrag()
    if item == nil then return end
    local b = her()
    if b == nil then return end

    if targetWidget ~= nil then
        if type(targetWidget.acceptItem) == "function" then pcall(function() targetWidget:acceptItem(item) end) end
        log("drop-in " .. tostring(item:getType()) .. " -> " .. tostring(targetWidget.kind or "slot"))
        return
    end
    if kind == nil then return end
    log("drop-out " .. tostring(item:getType()) .. " kind=" .. tostring(kind))
    routeOut(b, item, kind)
end


local function refreshOutfit()
    pcall(function() if Bridge ~= nil and Bridge.saveOutfit ~= nil then Bridge.saveOutfit() end end)
    pcall(function() if ISInventoryPage ~= nil then ISInventoryPage.renderDirty = true end end)
end
BridgeEquip.refreshOutfit = refreshOutfit

local function inHerBody(b, item)
    local yes = false
    pcall(function() yes = BridgeGear ~= nil and BridgeGear.inHer(b, item) end)
    return yes == true
end

local function canHandOver(b, player, item)
    if item == nil then return false end
    if inHerBody(b, item) then return true end
    local fav = false
    pcall(function() fav = item:isFavorite() end)
    if fav then return false end
    local reach = false
    pcall(function()
        local c = item:getContainer()
        if c == nil then return end
        if c:getType() == "floor" then reach = true return end
        reach = c:isInCharacterInventory(player) == true
    end)
    return reach == true
end
BridgeEquip.canHandOver = canHandOver

local function acceptGear(b, player, item, cell)
    if b == nil or item == nil or cell == nil then return false end
    if BridgeGear == nil or not BridgeGear.canAttach(item) then return false end
    local slot = cellSlotFor(b, item, cell)
    if slot == nil then return false end
    if not canHandOver(b, player, item) then return false end
    local current = nil
    pcall(function() current = BridgeGear.gearInSlot(b, cell.providerId, cell.type) end)
    if current == item then return false end
    local ok = false
    if inHerBody(b, item) then ok = BridgeGear.attachSlot(b, item, slot)
    else ok = BridgeGear.attachOnHerTo(player, item, slot) end
    if ok then refreshOutfit() end
    return ok == true
end
BridgeEquip.acceptGear = acceptGear

local function wearable(item)
    if item == nil or BridgeInventory == nil then return false end
    local ok = false
    pcall(function() ok = BridgeInventory.canWear(item) or #BridgeInventory.variants(item).list > 0 end)
    return ok
end

local function acceptClothing(b, player, item, region)
    if b == nil or item == nil or region == nil then return false end
    if not wearable(item) then return false end
    if not regionAccepts(region, item) then return false end
    local variant = variantFor(region, item)
    local already = false
    pcall(function() already = b:isEquippedClothing(item) end)
    if already and variant == nil and locInRegion(region, itemLoc(item)) then return false end
    if not canHandOver(b, player, item) then return false end
    local top = false
    pcall(function() top = item:getContainer() == b:getInventory() end)
    if top then
        if variant ~= nil then
            local _, newItem = BridgeInventory.wearVariant(b, item, variant, false, false, false)
            if newItem ~= nil then BridgeInventory.gifted(b, newItem) end
        else
            BridgeInventory.wear(b, item)
            BridgeInventory.gifted(b, item)
        end
        refreshOutfit()
        return true
    end
    local ok = false
    if variant ~= nil then ok = BridgeInventory.wearOnHer(player, item, variant)
    else ok = BridgeInventory.wearOnHer(player, item) end
    if ok then refreshOutfit() end
    return ok == true
end
BridgeEquip.acceptClothing = acceptClothing

local function acceptWeapon(b, player, item)
    if b == nil or item == nil or BridgeWeapon == nil then return false end
    if not BridgeWeapon.isMelee(item) then return false end
    if not canHandOver(b, player, item) then return false end
    if weaponItem(b) == item then return false end
    local top = false
    pcall(function() top = item:getContainer() == b:getInventory() end)
    if top then
        BridgeInventory.hands(b, item)
    elseif not BridgeInventory.assignOnHer(player, item) then
        return false
    end
    refreshOutfit()
    return true
end
BridgeEquip.acceptWeapon = acceptWeapon

local function acceptGun(b, player, item)
    if b == nil or item == nil or BridgeGunfight == nil or BridgeInventory == nil then return false end
    if not BridgeInventory.isGun(item) then return false end
    if not canHandOver(b, player, item) then return false end
    if BridgeGunfight.assignedItem(b) == item then return false end
    local top = false
    pcall(function() top = item:getContainer() == b:getInventory() end)
    local ok = false
    if top then
        ok = BridgeInventory.handsGun(b, item)
    else
        ok = BridgeInventory.assignOnHer(player, item, "gun")
    end
    if ok then refreshOutfit() end
    return ok == true
end
BridgeEquip.acceptGun = acceptGun

local function itemColor(item)
    local r, g, bb = 1, 1, 1
    pcall(function()
        if not item:allowRandomTint() then r, g, bb = item:getR(), item:getG(), item:getB() return end
        local ci = item:getColorInfo()
        r, g, bb = ci:getR(), ci:getG(), ci:getB()
        local limit = 0.2
        while r < limit and g < limit and bb < limit do r = r + limit / 4 g = g + limit / 4 bb = bb + limit / 4 end
    end)
    return r, g, bb
end
BridgeEquip.itemColor = itemColor

local function drawItemBox(self, item, x, y, box, alpha)
    if item == nil then return end
    local tex = nil
    pcall(function() tex = item:getTex() end)
    local r, g, bb = itemColor(item)
    pcall(function() self:drawTextureScaledAspect(tex, x, y, box, box, alpha or 1, r, g, bb) end)
end
BridgeEquip.drawItemBox = drawItemBox


local function drawPlate(self, w, h, occupied, revealed, hovered)
    local fillA = occupied and 0.5 or (revealed and 0.35 or 0.0)
    if fillA > 0 then self:drawRect(1, 1, w - 2, h - 2, fillA, 0, 0, 0) end
    if hovered then self:drawRect(1, 1, w - 2, h - 2, 0.22, 1, 1, 1) end
    local borderA = occupied and 0.9 or (revealed and 0.65 or 0.14)
    self:drawRectBorder(0, 0, w, h, borderA, 0.62, 0.65, 0.7)
end
BridgeEquip.drawPlate = drawPlate

local function highlightColor(canAccept, conflict)
    if canAccept and conflict then return BridgeEquip.colors.MIDDLE end
    if canAccept then return BridgeEquip.colors.GOOD end
    if conflict then return BridgeEquip.colors.BAD end
    return nil
end
BridgeEquip.highlightColor = highlightColor


BridgeEquipSlot = ISPanel:derive("BridgeEquipSlot")

function BridgeEquipSlot:getItem()
    if self.kind == "gear" then
        local b = her()
        if b == nil or self.cell == nil or BridgeGear == nil then return nil end
        local it = nil
        pcall(function() it = BridgeGear.gearInSlot(b, self.cell.providerId, self.cell.type) end)
        if it ~= nil then
            local inHand = false
            pcall(function() inHand = b:getPrimaryHandItem() == it or b:getSecondaryHandItem() == it end)
            if inHand then return nil end
        end
        return it
    elseif self.kind == "weapon" then
        return weaponItem(her())
    elseif self.kind == "gun" then
        if BridgeGunfight == nil then return nil end
        return BridgeGunfight.assignedItem(her())
    elseif self.kind == "popup" or self.kind == "dynamic" then
        return self.dynItem
    end
    return nil
end

function BridgeEquipSlot:acceptItem(item)
    local b, player = her(), playerOf(0)
    if b == nil or item == nil then return end
    if self.kind == "gear" then acceptGear(b, player, item, self.cell)
    elseif self.kind == "weapon" then acceptWeapon(b, player, item)
    elseif self.kind == "gun" then acceptGun(b, player, item) end
end

function BridgeEquipSlot:canAccept(item)
    if item == nil then return false end
    if not canHandOver(her(), playerOf(0), item) then return false end
    if self.kind == "gear" then
        return self.cell ~= nil and BridgeGear ~= nil and BridgeGear.canAttach(item)
            and cellSlotFor(her(), item, self.cell) ~= nil
    elseif self.kind == "weapon" then
        local cur = self:getItem()
        return cur ~= item and BridgeWeapon ~= nil and BridgeWeapon.isMelee(item)
    elseif self.kind == "gun" then
        local cur = self:getItem()
        return cur ~= item and BridgeInventory ~= nil and BridgeInventory.isGun(item)
            and BridgeGunfight ~= nil
    end
    return false
end

function BridgeEquipSlot:hoverItem()
    local it = self:getItem()
    if it ~= nil then return it end
    if self.kind == "popup" then return self.dynItem end
    return nil
end

function BridgeEquipSlot:render()
    local item = self:getItem()
    self.item = item
    local w, h = self:getWidth(), self:getHeight()
    local dragged = draggedItem()
    local revealed = dragged ~= nil
    local hovered = self:isMouseOver()
    drawPlate(self, w, h, item ~= nil, revealed, hovered)

    if item ~= nil then
        local pad = math.max(2, (w - BridgeEquip.L.SLOT_SIZE) / 2)
        local box = w - pad * 2
        local alpha = (dragged == item) and 0.5 or 1
        drawItemBox(self, item, pad, pad, box, alpha)
    end

    if dragged ~= nil and dragged ~= item and self.kind ~= "dynamic" and self.kind ~= "popup" then
        local can = self:canAccept(dragged)
        local col = highlightColor(can, can and item ~= nil)
        if col ~= nil then self:drawRect(1, 1, w - 2, h - 2, 0.5, col.r, col.g, col.b) end
    end
end

local DRAG_LIMIT = 8

function BridgeEquipSlot:arm(item)
    if item == nil then return end
    self.dragArmed = true
    self.dragItem = item
    self.downX, self.downY = self:getMouseX(), self:getMouseY()
end

function BridgeEquipSlot:maybeStartDrag()
    if not self.dragArmed or self.dragItem == nil then return end
    if not isMouseButtonDown(0) then self.dragArmed = false return end
    local mx, my = self:getMouseX(), self:getMouseY()
    if math.abs(mx - (self.downX or mx)) > DRAG_LIMIT or math.abs(my - (self.downY or my)) > DRAG_LIMIT then
        startDragSource(self, self.dragItem, self.kind)
        self.dragArmed = false
    end
end

function BridgeEquipSlot:onMouseDown(x, y)
    self:arm(self:getItem())
    return true
end

function BridgeEquipSlot:onMouseMove(dx, dy)
    self:maybeStartDrag()
end

function BridgeEquipSlot:onMouseMoveOutside(dx, dy)
    self:maybeStartDrag()
end

function BridgeEquipSlot:onMouseUp(x, y)
    self.dragArmed = false
    self.dragItem = nil
    if BridgeEquip.drag ~= nil then
        BridgeEquip.resolveDrop(self)
        return true
    end
    local item = draggedItem()
    if item ~= nil then
        self:acceptItem(item)
        clearDrag()
        return true
    end
    return false
end

local function menuAction(context, label, target, fn, ...)
    local args = { ... }
    local o = context:addOption(label, target, function(t)
        fn(t, unpack(args))
    end)
    return o
end

local function addOffMenu(context, item)
    local b = her()
    if context == nil or item == nil or b == nil then return end
    local isGear, isWeapon, isGun = false, false, false
    pcall(function() isGear = BridgeGear ~= nil and type(BridgeGear.isGear) == "function" and BridgeGear.isGear(b, item) == true end)
    pcall(function() isWeapon = BridgeWeapon ~= nil and type(BridgeWeapon.isAssigned) == "function" and BridgeWeapon.isAssigned(b, item) == true end)
    pcall(function()
        isGun = BridgeGunfight ~= nil and BridgeGunfight.assignedItem(b) == item
    end)
    if isGun then
        menuAction(context, tr("MenuUnassignGun"), item,
            function(t) if BridgeInventory ~= nil then BridgeInventory.dropGun(b, t) end refreshOutfit() end)
    elseif isWeapon and not isGear then
        menuAction(context, tr("InvUnassign", herName()), item,
            function(t) if BridgeInventory ~= nil then BridgeInventory.drop(b, t) end end)
    elseif isGear then
        menuAction(context, herName() .. ": " .. gameText("ContextMenu_Unequip", "Unequip"), item,
            function(t) if BridgeGear ~= nil then BridgeGear.detach(b, t) end refreshOutfit() end)
    else
        menuAction(context, tr("InvUnwear", herName()), item,
            function(t) if BridgeInventory ~= nil then BridgeInventory.unwear(b, t) end refreshOutfit() end)
    end
end
BridgeEquip.addOffMenu = addOffMenu

function BridgeEquipSlot:openMenu(x, y)
    local item = self:getItem()
    if item == nil then return end
    addOffMenu(ISContextMenu.get(0, getMouseX(), getMouseY()), item)
end

function BridgeEquipSlot:onRightMouseDown(x, y)
    self:openMenu(x, y)
    return true
end

function BridgeEquipSlot:new(x, y, w, h, kind, cell)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    o.kind = kind
    o.cell = cell
    return o
end


BridgeEquipSuperSlot = ISPanel:derive("BridgeEquipSuperSlot")

function BridgeEquipSuperSlot:refreshItems()
    local b = her()
    self.items = b ~= nil and regionLayers(b, self.region) or {}
end

function BridgeEquipSuperSlot:hoverItem()
    if self.items == nil or #self.items == 0 then return nil end
    if not self:isMouseOver() then return nil end
    local idx = self:mousePositionToSlotIndex(self:getMouseX(), self:getMouseY())
    if idx >= 1 and self.items[idx] ~= nil then return self.items[idx] end
    return self.items[1]
end

function BridgeEquipSuperSlot:gearTarget(item)
    local b = her()
    if b == nil or item == nil or BridgeGear == nil or type(BridgeGear.canAttach) ~= "function" then return nil end
    if not BridgeGear.canAttach(item) then return nil end
    local wanted = BridgeGear.slotsFor(b, item)
    if wanted == nil or #wanted == 0 then return nil end
    local first = nil
    for _, w in ipairs(wornItems(b)) do
        if anyLocInRegion(self.region, w.locs) then
            local pid = nil
            pcall(function() pid = w.item:getID() end)
            if pid ~= nil then
                for _, s in ipairs(wanted) do
                    if s.providerId == pid then
                        local current = nil
                        pcall(function() current = BridgeGear.gearInSlot(b, s.providerId, s.type) end)
                        if current == item then return nil end
                        if first == nil then first = s end
                        if current == nil then return s end
                    end
                end
            end
        end
    end
    return first
end

function BridgeEquipSuperSlot:acceptItem(item)
    local b, player = her(), playerOf(0)
    if b == nil or item == nil then return false end
    local slot = self:gearTarget(item)
    if slot ~= nil then
        if not canHandOver(b, player, item) then return false end
        local current = nil
        pcall(function() current = BridgeGear.gearInSlot(b, slot.providerId, slot.type) end)
        if current == item then return false end
        local ok = false
        if inHerBody(b, item) then ok = BridgeGear.attachSlot(b, item, slot)
        else ok = BridgeGear.attachOnHerTo(player, item, slot) end
        if ok then refreshOutfit() end
        return ok == true
    end
    return acceptClothing(b, player, item, self.region)
end

function BridgeEquipSuperSlot:conflicts(item)
    local b = her()
    if b == nil or item == nil then return false end
    local loc = itemLoc(item)
    if loc == nil then return false end
    local group = nil
    pcall(function() group = b:getWornItems():getBodyLocationGroup() end)
    for _, w in ipairs(wornItems(b)) do
        if w.loc == loc then return true end
        if group ~= nil then
            local ex = false
            pcall(function() ex = group:isExclusive(w.loc, loc) == true end)
            if ex then return true end
        end
    end
    return false
end

function BridgeEquipSuperSlot:prerender()
    self:refreshItems()
    local L = BridgeEquip.L
    local box = L.SUPER_SLOT_SIZE
    local subW = L.SUPER_SLOT_SUB_ITEM_WIDTH
    local w, h = self:getWidth(), self:getHeight()
    local count = #(self.items or {})
    local plateW = count > 1 and (box + subW) or box
    local dragged = draggedItem()
    local handover = dragged ~= nil and canHandOver(her(), playerOf(0), dragged)
    local accepts = handover and (regionAccepts(self.region, dragged) or self:gearTarget(dragged) ~= nil)
    drawPlate(self, plateW, h, count > 0, dragged ~= nil, self:isMouseOver())

    if count == 0 then
        if accepts then
            local col = self:conflicts(dragged) and BridgeEquip.colors.MIDDLE or BridgeEquip.colors.GOOD
            self:drawRect(1, 1, plateW - 2, h - 2, 0.5, col.r, col.g, col.b)
        end
        return
    end

    local mainBox = L.SLOT_SIZE
    local off = (box - mainBox) / 2
    local alpha = (dragged == self.items[1]) and 0.5 or 1
    drawItemBox(self, self.items[1], off, off, mainBox, alpha)

    if count > 1 then
        local mini = L.MINI_ICON_SIZE
        for i = 2, math.min(count, 4) do
            local yy = mini * (i - 2)
            self:drawRect(box, yy, mini, mini, 0.7, 0, 0, 0)
            self:drawRectBorder(box, yy, mini, mini, 0.4, 1, 1, 1)
            drawItemBox(self, self.items[i], box + 1, yy + 1, mini - 2, 1)
        end
        self:drawRectBorder(box - 1, 0, subW + 1, box, 1, 1, 1, 1)
    end

    if dragged ~= nil and dragged ~= self.items[1] then
        if accepts then
            local col = self:conflicts(dragged) and BridgeEquip.colors.MIDDLE or BridgeEquip.colors.GOOD
            self:drawRect(1, 1, plateW - 2, h - 2, 0.5, col.r, col.g, col.b)
        elseif self:conflicts(dragged) then
            local col = BridgeEquip.colors.BAD
            self:drawRect(1, 1, plateW - 2, h - 2, 0.5, col.r, col.g, col.b)
        end
    end
end

function BridgeEquipSuperSlot:mousePositionToSlotIndex(x, y)
    local box = BridgeEquip.L.SUPER_SLOT_SIZE
    local subW = BridgeEquip.L.SUPER_SLOT_SUB_ITEM_WIDTH
    if x > 0 and y > 0 and x < box and y < box then return 1 end
    if x > box and y > 0 and x < box + subW and y < box then
        return math.floor(y / math.max(1, BridgeEquip.L.MINI_ICON_SIZE)) + 2
    end
    return -1
end

function BridgeEquipSuperSlot:itemAtCursor()
    if self.items == nil then return nil end
    local idx = self:mousePositionToSlotIndex(self:getMouseX(), self:getMouseY())
    if idx >= 1 and self.items[idx] ~= nil then return self.items[idx] end
    return self.items[1]
end

function BridgeEquipSuperSlot:onMouseDown(x, y)
    self.downX, self.downY = self:getMouseX(), self:getMouseY()
    self.dragItem = self.items ~= nil and self:itemAtCursor() or nil
    self.dragArmed = self.dragItem ~= nil
    return true
end

function BridgeEquipSuperSlot:onMouseMove(dx, dy)
    if not self.dragArmed or self.dragItem == nil then return end
    if not isMouseButtonDown(0) then self.dragArmed = false return end
    local mx, my = self:getMouseX(), self:getMouseY()
    if math.abs(mx - (self.downX or mx)) > DRAG_LIMIT or math.abs(my - (self.downY or my)) > DRAG_LIMIT then
        startDragSource(self, self.dragItem, "clothing")
        self.dragArmed = false
    end
end

function BridgeEquipSuperSlot:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function BridgeEquipSuperSlot:onMouseUp(x, y)
    local dragged = draggedItem()
    self.dragArmed = false
    self.dragItem = nil
    if BridgeEquip.drag ~= nil then
        BridgeEquip.resolveDrop(self)
        return true
    end
    if dragged ~= nil then
        self:acceptItem(dragged)
        clearDrag()
        return true
    end
    self:togglePopup()
    return true
end

function BridgeEquipSuperSlot:togglePopup()
    if self.items == nil or #self.items < 2 then return end
    local win = BridgeEquip.instance
    if win == nil then return end
    if win.popup ~= nil and win.popup.owner == self and win.popup:isVisible() then
        win:hidePopup()
    else
        win:showPopup(self)
    end
end

function BridgeEquipSuperSlot:openMenu(x, y)
    local context = ISContextMenu.get(0, getMouseX(), getMouseY())
    local b = her()
    self:refreshItems()
    local idx = self:mousePositionToSlotIndex(x, y)
    local item = (idx >= 1 and self.items and self.items[idx]) or (self.items and self.items[1])
    if item ~= nil then addOffMenu(context, item) end
    if #(regionItems(b, self.region)) > 0 then
        local regionName = tr("EquipSlot_" .. self.region.id)
        menuAction(context, tr("EquipTakeOffAll", regionName), self.region, function(region)
            for _, it in ipairs(regionItems(her(), region)) do
                if BridgeInventory ~= nil then BridgeInventory.unwear(her(), it) end
            end
            refreshOutfit()
        end)
    end
end

function BridgeEquipSuperSlot:onRightMouseDown(x, y)
    self:openMenu(x, y)
    return true
end

function BridgeEquipSuperSlot:new(region)
    local L = BridgeEquip.L
    local box = L.SUPER_SLOT_SIZE
    local o = ISPanel:new(L.X_OFFSET + region.x * L.S, L.Y_OFFSET + region.y * L.S,
        box + L.SUPER_SLOT_SUB_ITEM_WIDTH, box)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    o.region = region
    o.items = {}
    o.slotSize = box
    return o
end


BridgeEquipPopup = ISPanel:derive("BridgeEquipPopup")

function BridgeEquipPopup:applyItems(owner, items)
    self.owner = owner
    self.items = items or {}
    local L = BridgeEquip.L
    for i, slot in ipairs(self.slots or {}) do
        local item = self.items[i]
        slot.dynItem = item
        slot:setVisible(item ~= nil)
    end
    local count = #self.items
    local cols = math.min(3, math.max(1, count))
    local rows = count > 0 and math.ceil(count / 3) or 1
    local cell = L.SLOT_SIZE
    self:setWidth(cols * cell + L.SUB_SLOT_THING)
    self:setHeight(rows * cell + L.SUB_SLOT_THING)
    for i, slot in ipairs(self.slots or {}) do
        if i <= count then
            local c = (i - 1) % 3
            local r = math.floor((i - 1) / 3)
            slot:setX(c * cell + 2)
            slot:setY(r * cell + 2)
            slot:setWidth(cell)
            slot:setHeight(cell)
        end
    end
end

function BridgeEquipPopup:createChildren()
    ISPanel.createChildren(self)
    self.slots = {}
    for i = 1, 9 do
        local slot = BridgeEquipSlot:new(0, 0, BridgeEquip.L.SLOT_SIZE, BridgeEquip.L.SLOT_SIZE, "popup")
        slot:initialise()
        slot:setVisible(false)
        self:addChild(slot)
        self.slots[i] = slot
    end
end

function BridgeEquipPopup:prerender()
    ISPanel.prerender(self)
    self:drawRect(0, 0, self:getWidth(), self:getHeight(), 0.9, 0, 0, 0)
    self:drawRectBorder(0, 0, self:getWidth(), self:getHeight(), 0.8, 1, 1, 1)
end

function BridgeEquipPopup:onMouseUpOutside(x, y)
    if BridgeEquip.instance ~= nil then BridgeEquip.instance:hidePopup() end
end

function BridgeEquipPopup:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    o.items = {}
    return o
end


BridgeEquipWindow = ISCollapsableWindow:derive("BridgeEquipWindow")

function BridgeEquipWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.pin = true
    if self.collapseButton ~= nil then
        self.collapseButton.target = self
        self.collapseButton.onclick = function() self:setCollapsed(true) end
    end
    if self.pinButton ~= nil then
        self.pinButton.target = self
        self.pinButton.onclick = function() self:setCollapsed(false) end
    end
    local L = BridgeEquip.L
    local th = self:titleBarHeight()
    self.canvas = ISPanel:new(0, th, L.PANEL_WIDTH, 10)
    self.canvas:initialise()
    self.canvas:noBackground()
    self:addChild(self.canvas)

    self.avatar = ISUI3DModel:new(L.X_OFFSET, L.Y_OFFSET, L.DOLL_W * L.S, L.DOLL_H * L.S)
    self.avatar:initialise()
    self.avatar:instantiate()
    pcall(function() self.avatar:setState("idle") end)
    pcall(function() self.avatar:setDirection(IsoDirections.S) end)
    pcall(function() self.avatar:setIsometric(false) end)
    self.canvas:addChild(self.avatar)

    self.superSlots = {}
    for i, region in ipairs(BridgeEquip.REGIONS) do
        local slot = BridgeEquipSuperSlot:new(region)
        slot:initialise()
        self.canvas:addChild(slot)
        self.superSlots[i] = slot
    end

    self.weaponSlot = BridgeEquipSlot:new(L.X_OFFSET + BASE.WEAPON_PRIMARY_X * L.S,
        L.Y_OFFSET + BASE.WEAPON_PRIMARY_Y * L.S, L.WEAPON_SLOT_SIZE, L.WEAPON_SLOT_SIZE, "weapon")
    self.weaponSlot:initialise()
    self.canvas:addChild(self.weaponSlot)

    self.gunSlot = BridgeEquipSlot:new(L.PANEL_WIDTH - L.WEAPON_SLOT_SIZE - BASE.WEAPON_GUN_RIGHT * L.S,
        L.Y_OFFSET + BASE.WEAPON_GUN_TOP * L.S, L.WEAPON_SLOT_SIZE, L.WEAPON_SLOT_SIZE, "gun")
    self.gunSlot:initialise()
    self.canvas:addChild(self.gunSlot)

    self.dynamicSlots = {}
    self.gearSlots = {}

    self.popup = BridgeEquipPopup:new(0, 0, 10, 10)
    self.popup:initialise()
    self.popup:setVisible(false)
    self:addChild(self.popup)

    self.scaleCombo = ISComboBox:new(0, 0, 10, 18, self, BridgeEquipWindow.onScale)
    self.scaleCombo:initialise()
    if BridgeData ~= nil and BridgeData.EQUIP_SCALES ~= nil then
        for _, entry in ipairs(BridgeData.EQUIP_SCALES) do
            self.scaleCombo:addOptionWithData(string.format("%gx", entry), entry)
        end
    end
    self:addChild(self.scaleCombo)
end

function BridgeEquipWindow:onScale(combo)
    if combo == nil then return end
    local s = combo:getSelectedData()
    self.fitPass = 0
    if s ~= nil and Bridge ~= nil and type(Bridge.setEquipScale) == "function" then Bridge.setEquipScale(s) end
end

function BridgeEquipWindow:relayout()
    local L = BridgeEquip.L
    local S = L.S
    local b = her()
    BridgeEquip.primeFurRegion()
    local th = self:titleBarHeight()

    self.canvas:setX(0)
    self.canvas:setY(th)
    self.canvas:setWidth(L.PANEL_WIDTH)

    self.avatar:setX(L.X_OFFSET)
    self.avatar:setY(L.Y_OFFSET)
    self.avatar:setWidth(L.DOLL_W * S)
    self.avatar:setHeight(L.DOLL_H * S)

    for _, slot in ipairs(self.superSlots) do
        slot:setX(L.X_OFFSET + slot.region.x * S)
        slot:setY(L.Y_OFFSET + slot.region.y * S)
        slot:setWidth(L.SUPER_SLOT_SIZE + L.SUPER_SLOT_SUB_ITEM_WIDTH)
        slot:setHeight(L.SUPER_SLOT_SIZE)
    end

    self.weaponSlot:setX(L.X_OFFSET + BASE.WEAPON_PRIMARY_X * S)
    self.weaponSlot:setY(L.Y_OFFSET + BASE.WEAPON_PRIMARY_Y * S)
    self.weaponSlot:setWidth(L.WEAPON_SLOT_SIZE)
    self.weaponSlot:setHeight(L.WEAPON_SLOT_SIZE)

    if self.gunSlot ~= nil then
        self.gunSlot:setX(L.PANEL_WIDTH - L.WEAPON_SLOT_SIZE - BASE.WEAPON_GUN_RIGHT * S)
        self.gunSlot:setY(L.Y_OFFSET + BASE.WEAPON_GUN_TOP * S)
        self.gunSlot:setWidth(L.WEAPON_SLOT_SIZE)
        self.gunSlot:setHeight(L.WEAPON_SLOT_SIZE)
    end

    self.headerH = L.clearance
    self.yHeader = 2
    self.yDoll = L.Y_OFFSET
    self.yDynHeader = L.DYN_Y
    local dyn = unmappedWorn(b)
    local dynRows = math.ceil(#dyn / L.DYN_PER_ROW)
    self.yDynTop = self.yDynHeader + (dynRows > 0 and self.headerH or 0)
    self.dynBottom = self.yDynTop + dynRows * L.DYN_STEP

    local need = math.max(#dyn, 0)
    while #self.dynamicSlots < need do
        local slot = BridgeEquipSlot:new(0, 0, L.SLOT_SIZE, L.SLOT_SIZE, "dynamic")
        slot:initialise()
        self.canvas:addChild(slot)
        self.dynamicSlots[#self.dynamicSlots + 1] = slot
    end
    for i, slot in ipairs(self.dynamicSlots) do
        local item = dyn[i]
        slot.dynItem = item
        slot:setVisible(item ~= nil)
        if item ~= nil then
            local col = (i - 1) % L.DYN_PER_ROW
            local row = math.floor((i - 1) / L.DYN_PER_ROW)
            slot:setX(L.DYN_X + col * L.DYN_STEP)
            slot:setY(self.yDynTop + row * L.DYN_STEP)
            slot:setWidth(L.SLOT_SIZE)
            slot:setHeight(L.SLOT_SIZE)
        end
    end

    self.yHotbarHeader = self.dynBottom + math.max(4 * S, 4)
    local cells = gearCells(b)
    local gearRows = math.ceil(#cells / L.HOTBAR_PER_ROW)
    self.yGearTop = self.yHotbarHeader + self.headerH

    while #self.gearSlots < #cells do
        local slot = BridgeEquipSlot:new(0, 0, L.SUPER_SLOT_SIZE, L.SUPER_SLOT_SIZE, "gear")
        slot:initialise()
        self.canvas:addChild(slot)
        self.gearSlots[#self.gearSlots + 1] = slot
    end
    for i, slot in ipairs(self.gearSlots) do
        local cell = cells[i]
        slot.cell = cell
        slot:setVisible(cell ~= nil)
        if cell ~= nil then
            local row = math.floor((i - 1) / L.HOTBAR_PER_ROW)
            local col = (i - 1) % L.HOTBAR_PER_ROW
            local inThisRow = math.min(L.HOTBAR_PER_ROW, #cells - row * L.HOTBAR_PER_ROW)
            local rowW = (inThisRow * L.SUPER_SLOT_SIZE) + ((inThisRow - 1) * L.HOTBAR_MARGIN)
            local step = L.SUPER_SLOT_SIZE + L.HOTBAR_MARGIN
            slot:setX((L.PANEL_WIDTH - rowW) / 2 + col * step)
            slot:setY(self.yGearTop + row * step)
            slot:setWidth(L.SUPER_SLOT_SIZE)
            slot:setHeight(L.SUPER_SLOT_SIZE)
        end
    end

    local gearH = gearRows * (L.SUPER_SLOT_SIZE + L.HOTBAR_MARGIN)
    local fontH = 14
    pcall(function() fontH = getTextManager():getFontHeight(UIFont.Small) end)
    local btnH = fontH + 6
    local inset = math.max(8, math.floor(10 * S))
    local gap = math.max(8, math.floor(10 * S))
    local inner = math.max(40, L.PANEL_WIDTH - inset * 2)
    local lineY = self.yGearTop + gearH + gap
    self.scaleLineY = lineY
    self.scaleInset = inset
    self.scaleFontH = fontH
    local lines = {}
    local line, maxW = "", inner
    local function fits(s)
        local w = 0
        pcall(function() w = getTextManager():MeasureStringX(UIFont.Small, s) end)
        return w <= maxW
    end
    for word in string.gmatch(tostring(tr("OptEquipScale") or ""), "%S+") do
        if line ~= "" and fits(line .. " " .. word) then line = line .. " " .. word
        else
            if line ~= "" then lines[#lines + 1] = line end
            line = word
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    if #lines == 0 then lines[1] = tr("OptEquipScale") end
    self.scaleLines = lines
    local labelY = lineY + gap
    self.scaleLabelY = labelY
    local comboY = labelY + #lines * fontH + 4
    if self.scaleCombo ~= nil then
        self.scaleCombo:setX(inset)
        self.scaleCombo:setWidth(inner)
        self.scaleCombo:setHeight(btnH)
        self.scaleCombo:setY(th + comboY)
        self.scaleCombo:setVisible(self.isCollapsed ~= true)
    end
    local contentH = comboY + btnH + gap

    local sh, sw = 0, 0
    pcall(function() sh, sw = getCore():getScreenHeight(), getCore():getScreenWidth() end)
    if not self.isCollapsed and sh > 0 and th + contentH > sh - 8 and (self.fitPass or 0) < 2 then
        self.fitPass = (self.fitPass or 0) + 1
        local fit = (sh - 24 - th) / math.max(1, contentH)
        BridgeEquip.applyScale(math.max(0.5, L.S * fit))
        if BridgeEquip.instance ~= self then self:relayout() end
        return
    end
    self.fitPass = 0

    self.contentH = contentH
    self.canvas:setHeight(contentH)
    self:setWidth(L.PANEL_WIDTH)
    if self.isCollapsed then
        self:setMaxDrawHeight(self:titleBarHeight())
    else
        self:setHeight(th + contentH)
        if sh > 0 then
            if self:getY() + self:getHeight() > sh - 8 then
                self:setY(math.max(0, sh - 8 - self:getHeight()))
            end
            if sw > 0 and self:getX() + self:getWidth() > sw then
                self:setX(math.max(0, sw - self:getWidth()))
            end
        end
    end
    if self.popup ~= nil and self.popup:isVisible() then self:hidePopup() end
end

function BridgeEquipWindow:makeDesc(st)
    local desc = SurvivorFactory.CreateSurvivor()
    desc:setFemale(BridgeData.isFemale(st))
    pcall(function() desc:getWornItems():clear() end)
    local hv = desc:getHumanVisual()
    pcall(function() hv:clear() end)
    pcall(function() hv:setSkinTextureName(BridgeData.skinOf(st)) end)
    pcall(function() hv:setHairModel(BridgeData.hairOf(st)) end)
    local hc = BridgeData.hairColorOf(st)
    pcall(function() hv:setHairColor(ImmutableColor.new(hc.r, hc.g, hc.b)) end)
    pcall(function() hv:setBeardModel(BridgeData.beardOf(st)) end)
    local bc = BridgeData.beardColorOf(st)
    pcall(function() hv:setBeardColor(ImmutableColor.new(bc.r, bc.g, bc.b)) end)
    pcall(function() hv:setNaturalBeardColor(ImmutableColor.new(bc.r, bc.g, bc.b)) end)
    local b = her()
    if b ~= nil then
        for _, w in ipairs(wornItems(b)) do
            pcall(function()
                local loc = itemLoc(w.item)
                if loc ~= nil then desc:setWornItem(loc, w.item) end
            end)
        end
    end
    if BridgeWindow ~= nil and type(BridgeWindow.addCustomDesc) == "function" then
        pcall(function() BridgeWindow.addCustomDesc(desc, st) end)
    end
    return desc
end

function BridgeEquipWindow:liveKey(st)
    local parts = { BridgeData.genderOf(st), BridgeData.skinOf(st), BridgeData.hairOf(st) }
    local hc = BridgeData.hairColorOf(st)
    parts[#parts + 1] = tostring(hc.r) .. tostring(hc.g) .. tostring(hc.b)
    parts[#parts + 1] = tostring(BridgeWindow ~= nil and BridgeWindow.lookKey(st) or "")
    local b = her()
    if b ~= nil then
        for _, w in ipairs(wornItems(b)) do
            local id = nil
            pcall(function() id = w.item:getID() end)
            parts[#parts + 1] = tostring(w.item:getType()) .. ":" .. tostring(id) .. ":" .. tostring(w.loc)
        end
    end
    return table.concat(parts, "|")
end

function BridgeEquipWindow:refreshAvatar()
    if Bridge == nil or Bridge.store == nil then return end
    local key = self:liveKey(Bridge.store)
    if key == self.avatarKey then return end
    self.avatarKey = key
    local ok, err = pcall(function() self.avatar:setSurvivorDesc(self:makeDesc(Bridge.store)) end)
    if not ok then warn("avatar failed: " .. tostring(err)) return end
    pcall(function() self.avatar:setState("idle") end)
    pcall(function() self.avatar:setDirection(IsoDirections.S) end)
    pcall(function() self.avatar:setIsometric(false) end)
    log("doll rebuilt")
end

function BridgeEquipWindow:showPopup(owner)
    if self.popup == nil or owner == nil then return end
    self.popup:applyItems(owner, owner.items)
    local px = self.canvas:getX() + owner:getX()
    local py = self.canvas:getY() + owner:getY() + owner:getHeight()
    if px + self.popup:getWidth() > self:getWidth() then px = math.max(0, self:getWidth() - self.popup:getWidth()) end
    self.popup:setX(px)
    self.popup:setY(py)
    self.popup:setVisible(true)
    self.popup:bringToTop()
end

function BridgeEquipWindow:hidePopup()
    if self.popup ~= nil then self.popup:setVisible(false) self.popup.owner = nil end
end

function BridgeEquipWindow:setCollapsed(on)
    self.isCollapsed = on and true or false
    if self.isCollapsed then
        self:setMaxDrawHeight(self:titleBarHeight())
        if self.collapseButton ~= nil then self.collapseButton:setVisible(false) end
        if self.pinButton ~= nil then self.pinButton:setVisible(true) self.pinButton:bringToTop() end
        self:hidePopup()
        if self.scaleCombo ~= nil then self.scaleCombo:setVisible(false) end
    else
        self:clearMaxDrawHeight()
        if self.collapseButton ~= nil then self.collapseButton:setVisible(true) end
        if self.pinButton ~= nil then self.pinButton:setVisible(false) end
        if self.scaleCombo ~= nil then self.scaleCombo:setVisible(true) end
    end
end

function BridgeEquipWindow:uncollapse()
end

function BridgeEquipWindow:onMouseDown(x, y)
    if self.popup ~= nil and self.popup:isVisible() then self:hidePopup() end
    ISCollapsableWindow.onMouseDown(self, x, y)
    return true
end

function BridgeEquipWindow:prerender()
    self.title = herName()
    if self.scaleCombo ~= nil and Bridge ~= nil and BridgeData ~= nil then
        local s = BridgeData.equipScale(Bridge.store)
        if self.scaleCombo:getSelectedData() ~= s then self.scaleCombo:selectData(s) end
    end
    ISCollapsableWindow.prerender(self)
end

function BridgeEquipWindow:render()
    ISCollapsableWindow.render(self)
    local L = BridgeEquip.L
    local th = self:titleBarHeight()
    local cx = L.PANEL_WIDTH / 2
    self:drawTextCentre(tr("EquipHeader"), cx, th + self.yHeader, 1, 1, 1, 1, UIFont.Small)
    if self.dynBottom > self.yDynTop then
        self:drawTextCentre(tr("EquipWorn"), cx, th + self.yDynHeader, 0.85, 0.85, 0.85, 1, UIFont.Small)
    end
    self:drawTextCentre(tr("EquipHotbar"), cx, th + self.yHotbarHeader, 1, 1, 1, 1, UIFont.Small)
    if self.scaleLineY ~= nil and self.isCollapsed ~= true then
        local inset = self.scaleInset or 8
        local lineW = (L.PANEL_WIDTH or self:getWidth()) - inset * 2
        self:drawRect(inset, th + self.scaleLineY, lineW, 1, 1, 0.4, 0.4, 0.4)
        local fontH = self.scaleFontH or 14
        local y = th + (self.scaleLabelY or (self.scaleLineY + 8))
        for _, line in ipairs(self.scaleLines or {}) do
            self:drawText(line, inset, y, 1, 1, 1, 1, UIFont.Small)
            y = y + fontH
        end
    end

    if BridgeEquip.drag ~= nil and ISMouseDrag ~= nil and ISMouseDrag.dragging ~= nil then
        local mx, my = getMouseX(), getMouseY()
        local ax, ay = self:getAbsoluteX(), self:getAbsoluteY()
        local box = 32 * L.S
        drawItemBox(self, BridgeEquip.drag.item, mx - ax - box / 2, my - ay - box / 2, box, 1)
    end
end

function BridgeEquipWindow:close()
    BridgeEquip.savePosition(self)
    clearDrag()
    BridgeEquip.hideTooltip()
    if self.popup ~= nil then self.popup:setVisible(false) end
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    BridgeEquip.instance = nil
    log("closed")
end

function BridgeEquipWindow:new(x, y, w, h)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor.a = 0.9
    o:setResizable(false)
    o.title = herName()
    return o
end


function BridgeEquip.showTooltip(item)
    if item == nil then BridgeEquip.hideTooltip() return end
    if BridgeEquip.tooltip == nil then
        local tip = ISToolTipInv:new(item)
        tip:initialise()
        tip:addToUIManager()
        tip:setOwner(BridgeEquip.instance)
        pcall(function() tip:setCharacter(playerOf(0)) end)
        tip.followMouse = true
        BridgeEquip.tooltip = tip
    end
    local tip = BridgeEquip.tooltip
    if tip.item ~= item then tip:setItem(item) end
    tip:setVisible(true)
    tip:bringToTop()
    pcall(function() tip.tooltip:setWeightOfStack(1) end)
end

function BridgeEquip.hideTooltip()
    if BridgeEquip.tooltip ~= nil then
        BridgeEquip.tooltip:setVisible(false)
        BridgeEquip.tooltip:removeFromUIManager()
        BridgeEquip.tooltip = nil
    end
end


function BridgeEquip.savePosition(win)
    local p = playerOf(0)
    if p == nil or win == nil then return end
    pcall(function()
        local md = p:getModData()
        md["BridgeEquip"] = md["BridgeEquip"] or {}
        md["BridgeEquip"].x = win:getX()
        md["BridgeEquip"].y = win:getY()
    end)
end

function BridgeEquip.loadPosition()
    local x, y = nil, nil
    local p = playerOf(0)
    if p ~= nil then
        pcall(function()
            local md = p:getModData()["BridgeEquip"]
            if md ~= nil then x, y = md.x, md.y end
        end)
    end
    return x, y
end


function BridgeEquip.close()
    if BridgeEquip.instance ~= nil then BridgeEquip.instance:close() end
    BridgeEquip.instance = nil
end

function BridgeEquip.withinRange(playerNum)
    local b = her()
    if b == nil then return false end
    local red = playerOf(playerNum or 0)
    if red == nil then return true end
    local keep = BridgeEquip.range
    local ok = true
    pcall(function()
        local dx, dy = b:getX() - red:getX(), b:getY() - red:getY()
        ok = dx * dx + dy * dy <= keep * keep and math.abs(b:getZ() - red:getZ()) < 1.5
    end)
    return ok
end

function BridgeEquip.open(playerNum)
    if BridgeShower ~= nil and BridgeShower.showing ~= nil and BridgeShower.showing() then
        log("open refused: she is showering")
        return nil
    end
    if Bridge == nil or Bridge.store == nil then return nil end
    local b = her()
    if b == nil then log("open refused: no body") return nil end
    if not BridgeEquip.withinRange(playerNum) then log("open refused: too far") return nil end
    BridgeEquip.applyScale()
    local L = BridgeEquip.L
    local win = BridgeEquipWindow:new(100, 100, L.PANEL_WIDTH, 200)
    win:initialise()
    win:instantiate()
    win:relayout()
    local x, y = BridgeEquip.loadPosition()
    if x == nil then
        pcall(function()
            local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
            x = math.max(0, sw - win:getWidth() - 20)
            y = math.max(0, (sh - win:getHeight()) / 2)
        end)
    end
    pcall(function()
        local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
        x = math.max(0, math.min(x or 100, sw - win:getWidth()))
        y = math.max(0, math.min(y or 100, sh - win:getHeight()))
    end)
    win:setX(x or 100)
    win:setY(y or 100)
    win:addToUIManager()
    win:setVisible(true)
    BridgeEquip.instance = win
    log("open " .. string.format("%dx%d scale=%.2f", win:getWidth(), win:getHeight(), L.S))
    return win
end

function BridgeEquip.toggle(playerNum)
    if BridgeEquip.instance ~= nil then BridgeEquip.close() return nil end
    if BridgeShower ~= nil and BridgeShower.showing ~= nil and BridgeShower.showing() then
        log("toggle refused: she is showering")
        return nil
    end
    return BridgeEquip.open(playerNum)
end


local function findHoverItem(win)
    local item = nil
    pcall(function()
        if win.popup ~= nil and win.popup:isVisible() then
            if win.popup:isMouseOver() then
                for _, slot in ipairs(win.popup.slots or {}) do
                    if slot:isVisible() and slot:isMouseOver() then
                        item = slot.dynItem break
                    end
                end
                if item == nil then return end
            end
        end
        for _, slot in ipairs(win.gearSlots) do
            if slot:isVisible() and slot:isMouseOver() then item = slot:getItem() end
        end
        for _, slot in ipairs(win.dynamicSlots) do
            if slot:isVisible() and slot:isMouseOver() then item = slot.dynItem end
        end
        if win.weaponSlot:isMouseOver() then item = win.weaponSlot:getItem() end
    if win.gunSlot ~= nil and win.gunSlot:isMouseOver() then item = win.gunSlot:getItem() end
        for _, slot in ipairs(win.superSlots) do
            if slot:isMouseOver() then
                local it = slot:hoverItem()
                if it ~= nil then item = it end
            end
        end
    end)
    return item
end

local function tick()
    if BridgeEquip.DEV then
        pcall(function()
            if isKeyDown(Keyboard.KEY_KP_MINUS) and not BridgeEquip.devDown then
                BridgeEquip.devDown = true
                BridgeEquip.toggle(0)
            elseif not isKeyDown(Keyboard.KEY_KP_MINUS) then
                BridgeEquip.devDown = false
            end
        end)
    end

    local win = BridgeEquip.instance
    if win == nil then return end

    local b = her()
    if b == nil then
        log("auto-close: body gone") BridgeEquip.close() return
    end
    local red = playerOf(0)
    local keep = BridgeEquip.range
    local near = true
    pcall(function()
        if red ~= nil then
            local dx, dy = b:getX() - red:getX(), b:getY() - red:getY()
            near = dx * dx + dy * dy <= keep * keep and math.abs(b:getZ() - red:getZ()) < 1.5
        end
    end)
    if not near then log("auto-close: too far") BridgeEquip.close() return end

    if Bridge.store ~= nil then pcall(function() win:refreshAvatar() end) end

    local cells = gearCells(b)
    local dyn = unmappedWorn(b)
    local key = #cells .. "|" .. #dyn
    if key ~= win.layoutKey then
        win.layoutKey = key
        pcall(function() win:relayout() end)
    end

    if BridgeEquip.drag ~= nil and not isMouseButtonDown(0) then
        BridgeEquip.resolveDrop(nil)
    end

    if win.popup ~= nil and win.popup:isVisible() and not isMouseButtonDown(0) then
        local over = win.popup:isMouseOver() or (win.popup.owner ~= nil and win.popup.owner:isMouseOver())
        if not over then win:hidePopup() end
    end

    local item = findHoverItem(win)
    if item ~= nil and not isMouseButtonDown(0) then BridgeEquip.showTooltip(item) else BridgeEquip.hideTooltip() end
end

Events.OnTick.Add(tick)

Events.OnResolutionChange.Add(function(oldw, oldh, neww, newh)
    local win = BridgeEquip.instance
    if win ~= nil then win.fitPass = 0 end
    BridgeEquip.applyScale()
    if win == nil then return end
    pcall(function()
        local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
        win:setX(math.max(0, math.min(win:getX(), sw - win:getWidth())))
        win:setY(math.max(0, math.min(win:getY(), sh - win:getHeight())))
        win:hidePopup()
        win:relayout()
    end)
end)

Events.OnClothingUpdated.Add(function(playerObj)
    if BridgeEquip.instance == nil then return end
    pcall(function() BridgeEquip.instance:relayout() end)
end)

BridgeEquip.applyScale()
log("loaded")
