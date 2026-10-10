BridgeGear = BridgeGear or {}

-- Slotted equipment for Rin.
--
-- Build 42 lets any IsoGameCharacter (player or zombie body) render an item on
-- a model attachment point. A worn item advertises those points through its
-- AttachmentsProvided script field and the item declares what it can mount with
-- AttachmentType; Hotbar/ISHotbarAttachDefinition maps the pair to a model
-- location. The vanilla ISHotbar UI is player-only, so it can only ever mount
-- things on the player. This module repeats the same low level calls for her
-- body, reusing her worn gear as the source of slots. It covers webbing, belts,
-- holsters and any modded gear that provides attachment points, and works in
-- singleplayer and multiplayer (persistence rides the existing outfit snapshot).

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGear] " .. tostring(text)) end end

-- Translation helpers that never leak a raw key when one is missing.
local function tr(key, fallback)
    local t = nil
    pcall(function() t = getText(key) end)
    if t == nil or t == "" or t == key then return fallback end
    return t
end

local function trOr(key, fallback)
    local t = nil
    pcall(function() t = getTextOrNull(key) end)
    if t == nil or t == "" or t == key then return fallback end
    return t
end

local function herName()
    local n = nil
    pcall(function() if Bridge ~= nil and Bridge.companionName ~= nil then n = Bridge.companionName() end end)
    if type(n) ~= "string" or n == "" then n = "Rin" end
    return n
end
BridgeGear.herName = herName

-- Speech, kept short and rate limited so swapping tools does not spam.
BridgeGear.said = BridgeGear.said or {}
local function sayGear(kind, fallback, gap)
    local now = 0
    pcall(function() now = Bridge.time or 0 end)
    if now - (BridgeGear.said[kind] or -99999) < (gap or 120) then return end
    BridgeGear.said[kind] = now
    local text = trOr("IGUI_NotAlone_Say_" .. kind, fallback)
    pcall(function() if Bridge ~= nil and Bridge.speakText ~= nil then Bridge.speakText(text) end end)
end

-- The "attach to belt/back" gestures. WeaponAttach*/WeaponDetach* are the bump
-- types this body already plays when she stows or draws a weapon, so we know the
-- animation graph accepts them (plain "AttachItem" is a player action anim and
-- does nothing on her).
local GEAR_BUMPS = {
    attach = { back = "WeaponAttachBack", ["belt left"] = "WeaponAttachBeltLeft",
               ["belt right"] = "WeaponAttachBeltRight", ["holster left"] = "WeaponAttachBeltLeft",
               ["holster right"] = "WeaponAttachBeltRight" },
    detach = { back = "WeaponDetachBack", ["belt left"] = "WeaponDetachBeltLeft",
               ["belt right"] = "WeaponDetachBeltRight", ["holster left"] = "WeaponDetachBeltLeft",
               ["holster right"] = "WeaponDetachBeltRight" },
}
local function gearBump(kind, animset)
    local map = GEAR_BUMPS[kind] or GEAR_BUMPS.attach
    return map[animset or ""] or map.back
end

local function isGearBump(bump)
    if type(bump) ~= "string" then return false end
    return bump == "AttachItem" or string.find(bump, "WeaponAttach", 1, true) == 1
        or string.find(bump, "WeaponDetach", 1, true) == 1
end
BridgeGear.isGearBump = isGearBump

local GEAR_FRAMES = 30
BridgeGear.animBody = nil
BridgeGear.animBump = nil
BridgeGear.animUntil = 0
local function playGearMove(b, animset, kind)
    if b == nil then return end
    local old = BridgeGear.animBody
    if old ~= nil and old ~= b then
        pcall(function()
            local bt = tostring(old:getBumpType())
            if isGearBump(bt) then old:setBumpType("") end
        end)
    end
    pcall(function()
        local red = BridgeData.owner()
        if red ~= nil then b:faceLocationF(red:getX(), red:getY()) end
    end)
    local bump = gearBump(kind, animset)
    pcall(function() b:SetVariable("AttachAnim", animset or "") end)
    pcall(function() b:setBumpType(bump) end)
    BridgeGear.animBody = b
    BridgeGear.animBump = bump
    BridgeGear.animUntil = 0
    pcall(function() BridgeGear.animUntil = (Bridge.time or 0) + GEAR_FRAMES end)
    pcall(function() log("gear " .. kind .. " anim " .. bump) end)
end

Events.OnTick.Add(function()
    local b = BridgeGear.animBody
    if b == nil then return end
    local now = 0
    pcall(function() now = Bridge.time or 0 end)
    local bump = BridgeGear.animBump
    if now >= (BridgeGear.animUntil or 0) then
        BridgeGear.animBody = nil
        BridgeGear.animBump = nil
        pcall(function() if tostring(b:getBumpType()) == bump then b:setBumpType("") end end)
    elseif bump ~= nil then
        -- Re-assert each frame, exactly like the weapon move does, so the state
        -- is held for the duration and not dropped after a single frame.
        pcall(function() if tostring(b:getBumpType()) ~= bump then b:setBumpType(bump) end end)
    end
end)

-- item -> { location, type, index, body }. Weak keys so a re-created body never
-- keeps a dead item alive.
BridgeGear.attached = setmetatable({}, { __mode = "k" })
BridgeGear.toAttach = BridgeGear.toAttach or {}

local function her()
    if Bridge == nil or not Bridge.alive() or Bridge.kind ~= "zombie" then return nil end
    return Bridge.body
end

local function inHer(b, item)
    if b == nil or item == nil then return false end
    local c = nil
    pcall(function() c = item:getContainer() end)
    if c == nil then return false end
    -- Worn gear (webbing, alice pouches) are her containers too, and the mod
    -- already knows how to recognise them.
    if BridgeInventory ~= nil and type(BridgeInventory.isHers) == "function" then
        local hers = false
        pcall(function() hers = BridgeInventory.isHers(c) end)
        if hers then return true end
    end
    local ok = false
    pcall(function()
        local inv = b:getInventory()
        ok = (c == inv) or (c:getOutermostContainer() == inv)
    end)
    return ok
end
BridgeGear.inHer = inHer

-- An item is mountable only when it names an attachment type and has a model.
-- Clothing without an attachment type, food, and broken items are refused.
function BridgeGear.canAttach(item)
    if item == nil then return false end
    local broken = false
    local kind = nil
    local model = nil
    pcall(function() broken = item:isBroken() end)
    pcall(function() kind = item:getAttachmentType() end)
    pcall(function() model = item:getStaticModel() end)
    return not broken and kind ~= nil and kind ~= ""
        and type(model) == "string" and model ~= ""
end

-- Every model slot provided by her worn gear that accepts this item.
function BridgeGear.slotsFor(b, item)
    local out = {}
    if b == nil or item == nil or ISHotbarAttachDefinition == nil then return out end
    local kind = nil
    pcall(function() kind = item:getAttachmentType() end)
    if kind == nil or kind == "" then return out end
    local defs = {}
    for _, def in ipairs(ISHotbarAttachDefinition) do defs[def.type] = def end
    local replacers = {}
    for _, def in ipairs(ISHotbarAttachDefinition.replacements or {}) do replacers[def.type] = def end
    -- Back is always present on the body, then each worn item separately, so
    -- every piece of gear that can hold the item gets its own entry.
    local list = { { type = "Back", provider = nil } }
    local replacements = {}
    pcall(function()
        local worn = b:getWornItems()
        for i = 0, worn:size() - 1 do
            local w = worn:getItemByIndex(i)
            if w ~= nil then
                local provided = nil
                pcall(function() provided = w:getAttachmentsProvided() end)
                if provided ~= nil then
                    for j = 0, provided:size() - 1 do
                        list[#list + 1] = { type = provided:get(j), provider = w }
                    end
                end
                local rep = nil
                pcall(function() rep = w:getAttachmentReplacement() end)
                local rdef = rep ~= nil and replacers[rep] or nil
                if rdef ~= nil and rdef.replacement ~= nil then
                    for k, v in pairs(rdef.replacement) do replacements[k] = v end
                end
            end
        end
    end)
    -- One entry per (worn item, slot). The belt, the vest and the backpack each
    -- get their own entry, and each tracks its own occupant.
    local seen, index = {}, 1
    for _, entry in ipairs(list) do
        local t, w = entry.type, entry.provider
        local def = defs[t]
        if def ~= nil and def.attachments ~= nil and def.attachments[kind] ~= nil then
            local loc = def.attachments[kind]
            if def.name == "Back" and replacements[kind] ~= nil then loc = replacements[kind] end
            if loc ~= nil and loc ~= "null" then
                local pid, pname, ptype = nil, nil, nil
                if w ~= nil then
                    pcall(function() pid = w:getID() end)
                    pcall(function() pname = w:getName() end)
                    pcall(function() ptype = w:getType() end)
                end
                local key = tostring(pid) .. "|" .. t
                if not seen[key] then
                    seen[key] = true
                    local name = nil
                    pcall(function() name = getTextOrNull("IGUI_HotbarAttachment_" .. def.type) end)
                    out[#out + 1] = { name = name or def.name or def.type,
                                      location = loc, type = def.type, index = index, animset = def.animset,
                                      providerId = pid, providerName = pname, providerType = ptype }
                end
            end
        end
        index = index + 1
    end
    return out
end

function BridgeGear.firstSlot(b, item)
    local slots = BridgeGear.slotsFor(b, item)
    return slots[1]
end

function BridgeGear.slotStill(b, item, location)
    for _, s in ipairs(BridgeGear.slotsFor(b, item)) do
        if s.location == location then return true end
    end
    return false
end

-- Where the item currently sits on her, if anywhere.
function BridgeGear.locationOf(b, item)
    if b == nil or item == nil then return nil end
    local info = BridgeGear.attached[item]
    if info ~= nil and info.body == b then return info.location end
    -- The weapon system owns its own attachment; do not report it as gear.
    if BridgeWeapon ~= nil and (BridgeWeapon.isAssigned(b, item)
            or (BridgeWeapon.attached ~= nil and BridgeWeapon.attached.item == item)) then return nil end
    local loc = nil
    pcall(function() loc = item:getAttachedToModel() end)
    if type(loc) == "string" and loc ~= "" then return loc end
    return nil
end

function BridgeGear.isGear(b, item)
    if b == nil or item == nil then return false end
    local info = BridgeGear.attached[item]
    return info ~= nil and info.body == b
end

local function saveLook()
    pcall(function() if Bridge ~= nil and Bridge.saveOutfit ~= nil then Bridge.saveOutfit() end end)
    pcall(function() if ISInventoryPage ~= nil then ISInventoryPage.renderDirty = true end end)
end

local function setOnModel(b, item, slot)
    return pcall(function()
        b:setAttachedItem(slot.location, item)
        if item.setAttachedToModel ~= nil then item:setAttachedToModel(slot.location) end
        if item.setAttachedSlotType ~= nil then item:setAttachedSlotType(slot.type) end
        if item.setAttachedSlot ~= nil then item:setAttachedSlot(slot.index) end
    end)
end

-- The item we mounted into one specific worn holder's slot. Keyed by holder, so
-- a belt entry never reports the vest's occupant (and vice versa).
local function gearInSlot(b, providerId, slotType)
    if b == nil or slotType == nil then return nil end
    for item, info in pairs(BridgeGear.attached) do
        if info.body == b and info.type == slotType and info.providerId == providerId then
            return item
        end
    end
    return nil
end
BridgeGear.gearInSlot = gearInSlot

-- True while the worn item a mount was attached from is still worn.
local function providerStill(b, id)
    if id == nil then return true end
    local ok = false
    pcall(function()
        local worn = b:getWornItems()
        for i = 0, worn:size() - 1 do
            local w = worn:getItemByIndex(i)
            if w ~= nil and w:getID() == id then ok = true return end
        end
    end)
    return ok
end

-- Mount the item on one specific slot. The item must already be in her body.
function BridgeGear.attachSlot(b, item, slot, quiet)
    if b == nil or item == nil or slot == nil or not inHer(b, item) then return false end
    -- Hand it over from the weapon system if it happens to be her assigned weapon.
    pcall(function()
        if BridgeWeapon ~= nil and BridgeWeapon.isAssigned(b, item) then
            BridgeWeapon.assignedId = nil
            if BridgeWeapon.attached ~= nil and BridgeWeapon.attached.item == item then BridgeWeapon.release(b) end
        end
    end)
    pcall(function()
        if b:getPrimaryHandItem() == item then b:setPrimaryHandItem(nil) end
        if b:getSecondaryHandItem() == item then b:setSecondaryHandItem(nil) end
    end)
    -- Mounted gear must sit in the main inventory so it stays top level and is
    -- saved with the outfit; move it there when it came out of a worn pocket.
    pcall(function()
        local inv = b:getInventory()
        local c = item:getContainer()
        if c ~= nil and c ~= inv then
            c:Remove(item)
            if inv:AddItem(item) == nil then c:AddItem(item) end
        end
    end)
    -- Replace only what was mounted from this same holder, so equipping to the
    -- vest does not disturb a tool already sitting on the belt.
    local current = gearInSlot(b, slot.providerId, slot.type)
    if current ~= nil and current ~= item then BridgeGear.release(b, current) end
    if not setOnModel(b, item, slot) then return false end
    BridgeGear.attached[item] = { location = slot.location, type = slot.type, index = slot.index,
                                  animset = slot.animset, providerId = slot.providerId,
                                  providerName = slot.providerName, providerType = slot.providerType, body = b }
    pcall(function() b:resetModelNextFrame() end)
    saveLook()
    if not quiet then
        playGearMove(b, slot.animset, "attach")
        sayGear("Equip", "Got it.")
    end
    log("attached " .. tostring(item:getType()) .. " at " .. tostring(slot.location))
    return true
end

function BridgeGear.attach(b, item, quiet)
    return BridgeGear.attachSlot(b, item, BridgeGear.firstSlot(b, item), quiet)
end

-- Mount without an outfit save; used while rebuilding a body from a snapshot.
function BridgeGear.attachTo(b, item, location, defType, providerType)
    if b == nil or item == nil or type(location) ~= "string" or location == "" then return false end
    if not setOnModel(b, item, { location = location, type = defType or "", index = 1 }) then return false end
    -- Recover the slot's animset and holder so a later detach still works. The
    -- holder is matched by item type (IDs do not survive a reload).
    local animset, providerId, providerName, ptype = nil, nil, nil, nil
    local slots = BridgeGear.slotsFor(b, item)
    for _, s in ipairs(slots) do
        if s.location == location and (providerType == nil or s.providerType == providerType) then
            animset, providerId, providerName, ptype = s.animset, s.providerId, s.providerName, s.providerType
            break
        end
    end
    if providerId == nil then
        for _, s in ipairs(slots) do
            if s.location == location then
                animset, providerId, providerName, ptype = s.animset, s.providerId, s.providerName, s.providerType
                break
            end
        end
    end
    BridgeGear.attached[item] = { location = location, type = defType or "", index = 1,
                                  animset = animset, providerId = providerId,
                                  providerName = providerName, providerType = ptype, body = b }
    return true
end

function BridgeGear.release(b, item)
    if item == nil then return false end
    BridgeGear.attached[item] = nil
    if b ~= nil then pcall(function() b:removeAttachedItem(item) end) end
    pcall(function()
        if item.setAttachedToModel ~= nil then item:setAttachedToModel(nil) end
        if item.setAttachedSlotType ~= nil then item:setAttachedSlotType(nil) end
        if item.setAttachedSlot ~= nil then item:setAttachedSlot(-1) end
    end)
    return true
end

function BridgeGear.detach(b, item)
    if b == nil or item == nil then return false end
    local info = BridgeGear.attached[item]
    local animset = info ~= nil and info.animset or nil
    BridgeGear.release(b, item)
    pcall(function() b:resetModelNextFrame() end)
    saveLook()
    playGearMove(b, animset, "detach")
    sayGear("Unequip", "Taking it off.")
    log("detached " .. tostring(item:getType()))
    return true
end

-- Re-assert valid mounts and drop any whose item or slot point is gone. Safe to
-- call on every model rebuild; it never saves on its own.
function BridgeGear.sync(b)
    if b == nil then return end
    local changed = false
    local drop, handsOff = nil, nil
    for item, info in pairs(BridgeGear.attached) do
        if info.body == b then
            -- If the weapon system has taken the item back (she drew it, or it
            -- was assigned), stop tracking it and leave the model alone.
            local weapon = BridgeWeapon ~= nil and (BridgeWeapon.isAssigned(b, item)
                or (BridgeWeapon.attached ~= nil and BridgeWeapon.attached.item == item))
            if weapon then
                handsOff = handsOff or {}
                handsOff[#handsOff + 1] = item
            elseif not (inHer(b, item) and BridgeGear.slotStill(b, item, info.location)
                    and providerStill(b, info.providerId)) then
                drop = drop or {}
                drop[#drop + 1] = item
            end
        end
    end
    if handsOff ~= nil then
        for _, item in ipairs(handsOff) do
            BridgeGear.attached[item] = nil
            changed = true
        end
    end
    if drop ~= nil then
        for _, item in ipairs(drop) do
            BridgeGear.release(b, item)
            changed = true
        end
    end
    for item, info in pairs(BridgeGear.attached) do
        if info.body == b then
            local current = nil
            pcall(function() current = b:getAttachedItem(info.location) end)
            if current ~= item then
                pcall(function()
                    b:setAttachedItem(info.location, item)
                    if item.setAttachedToModel ~= nil then item:setAttachedToModel(info.location) end
                    if item.setAttachedSlotType ~= nil then item:setAttachedSlotType(info.type) end
                    if item.setAttachedSlot ~= nil then item:setAttachedSlot(info.index) end
                end)
                changed = true
            end
        end
    end
    if changed then pcall(function() b:resetModelNextFrame() end) end
end

function BridgeGear.reset(b)
    for item, info in pairs(BridgeGear.attached) do
        if b == nil or info.body == b then BridgeGear.attached[item] = nil end
    end
end

-- Hand an item to her and mount it, for items the player is carrying.
function BridgeGear.attachOnHerTo(player, item, slot)
    local b = her()
    if b == nil or item == nil or slot == nil then return end
    if item:getContainer() == b:getInventory() then
        BridgeGear.attachSlot(b, item, slot)
        return
    end
    local inv = b:getInventory()
    local room = true
    pcall(function() room = inv:hasRoomFor(player, item) ~= false end)
    if not room then return end
    local id = item:getID()
    BridgeGear.toAttach[id] = slot
    local ok = pcall(function()
        local act = ISInventoryTransferAction:new(player, item, item:getContainer(), inv)
        if act.bridgeRelay ~= nil then
            act.bridgeRelay.after = { f = BridgeGear.finishAttach, a = id }
        else
            act:setOnComplete(BridgeGear.finishAttach, id)
        end
        ISTimedActionQueue.add(act)
    end)
    if not ok then BridgeGear.toAttach[id] = nil end
end

function BridgeGear.finishAttach(id)
    local slot = BridgeGear.toAttach[id]
    BridgeGear.toAttach[id] = nil
    local b = her()
    if b == nil then return end
    local item = nil
    pcall(function() item = b:getInventory():getItemWithIDRecursiv(id) end)
    if item == nil then return end
    if slot ~= nil and BridgeGear.slotStill(b, item, slot.location) then
        BridgeGear.attachSlot(b, item, slot)
    else
        BridgeGear.attach(b, item)
    end
end

-- Right-click options for her slotted gear.
function BridgeGear.menu(context, b, player, list)
    if context == nil or b == nil or type(list) ~= "table" then return end
    if BridgeInventory == nil or BridgeInventory.shown ~= true then return end
    local item = list[1]
    if item == nil or #list ~= 1 then return end

    -- Already mounted: offer to take it off.
    if inHer(b, item) and BridgeGear.locationOf(b, item) ~= nil then
        local label = herName() .. ": " .. tr("ContextMenu_Unequip", "Unequip")
        context:addOption(label, b, BridgeGear.detach, item)
        return
    end
    if not BridgeGear.canAttach(item) then return end

    local mine = inHer(b, item)
    if not mine then
        -- Never hand over a favourite the player is carrying by accident.
        local fav = false
        pcall(function() fav = item:isFavorite() end)
        if fav then return end
        local reach = false
        pcall(function()
            local c = item:getContainer()
            reach = c ~= nil and c:isInCharacterInventory(player)
        end)
        if not reach then return end
    end
    local slots = BridgeGear.slotsFor(b, item)
    if #slots == 0 then return end

    -- "<Name>: Equip" so it can never be confused with the vanilla "Attach"
    -- (which mounts on the player, not on her).
    local rootLabel = herName() .. ": " .. tr("ContextMenu_Equip", "Equip")
    local root = context:addOption(rootLabel)
    local sub = context:getNew(context)
    context:addSubMenu(root, sub)
    local replaces = tr("Tooltip_ReplaceWornItems", "Replaces:")
    for _, slot in ipairs(slots) do
        local label = slot.name
        if type(slot.providerName) == "string" and slot.providerName ~= "" then
            label = label .. " (" .. slot.providerName .. ")"
        end
        local option = nil
        if mine then
            option = sub:addOption(label, b, BridgeGear.attachSlot, item, slot)
        else
            option = sub:addOption(label, player, BridgeGear.attachOnHerTo, item, slot)
        end
        -- Only warn about an occupant mounted from THIS holder, so the vest's
        -- Belt Left does not echo the screwdriver sitting on the belt.
        local cur = gearInSlot(b, slot.providerId, slot.type)
        if cur ~= nil and cur ~= item then
            pcall(function()
                local tip = ISWorldObjectContextMenu.addToolTip()
                tip.description = replaces .. " <LINE> <INDENT:20> " .. cur:getDisplayName()
                option.toolTip = tip
            end)
        end
    end
end

-- The vanilla attach menu always targets the player's own hotbar, which is
-- misleading for items sitting in her inventory. Hide it for those.
function BridgeGear.install()
    if ISHotbar ~= nil and type(ISHotbar.doMenuFromInventory) == "function" and not ISHotbar.bridgeGearWrapped then
        local original = ISHotbar.doMenuFromInventory
        ISHotbar.doMenuFromInventory = function(playerNum, item, context)
            local hers = false
            pcall(function()
                if item ~= nil and BridgeInventory ~= nil then
                    hers = BridgeInventory.inBody(item:getContainer())
                end
            end)
            if hers then return end
            return original(playerNum, item, context)
        end
        ISHotbar.bridgeGearWrapped = true
        log("vanilla attach menu hidden for her items")
    end
end

Events.OnGameStart.Add(function() pcall(BridgeGear.install) end)
log("loaded")
