BridgeTransmog = BridgeTransmog or {}

local OPERATIONS = {
    transmogrify = true,
    hide = true,
    show = true,
    remove = true,
    reset = true,
    color = true,
    texture = true,
}

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeTransmog] " .. tostring(text)) end
end

local function tr(key, fallback)
    local text = nil
    pcall(function() text = getTextOrNull(key) end)
    if type(text) == "string" and text ~= "" then return text end
    return fallback or key
end

function BridgeTransmog.available()
    if BridgeTransmogLogic == nil or type(BridgeTransmogLogic.available) ~= "function" then return false end
    if not BridgeTransmogLogic.available() then return false end
    if type(TransmogNet) ~= "table" then return false end
    return true
end

BridgeTransmog.derivedCache = setmetatable({}, { __mode = "k" })

function BridgeTransmog.isDerivedItem(item)
    if item == nil or type(TransmogDE) ~= "table" then return false end
    local cached = BridgeTransmog.derivedCache[item]
    if cached ~= nil then return cached end
    local yes = false
    pcall(function() yes = TransmogDE.isTransmogItem(item) == true end)
    BridgeTransmog.derivedCache[item] = yes
    return yes
end

BridgeTransmog.transmoggable = setmetatable({}, { __mode = "k" })

function BridgeTransmog.isTransmoggable(item)
    if item == nil or type(TransmogDE) ~= "table" then return false end
    local cached = BridgeTransmog.transmoggable[item]
    if cached ~= nil then return cached end
    local yes = false
    pcall(function() yes = TransmogDE.isTransmoggable(item) == true end)
    BridgeTransmog.transmoggable[item] = yes
    return yes
end

function BridgeTransmog.isCompanionItem(item)
    if item == nil or Bridge == nil or Bridge.body == nil then return false end
    if Bridge.kind ~= "zombie" then return false end
    if BridgeTransmog.isDerivedItem(item) then return false end
    local b = Bridge.body
    local yes = false
    pcall(function()
        local container = item:getContainer()
        yes = container ~= nil and BridgeInventory ~= nil and BridgeInventory.inBody(container) == true
    end)
    if yes then return true end
    pcall(function() yes = b:getWornItems():contains(item) == true end)
    return yes
end

function BridgeTransmog.walk(body, visit)
    if body == nil or type(visit) ~= "function" then return false end
    if BridgeInventory == nil or type(BridgeInventory.snapshot) ~= "function" then return false end
    local list, items = nil, nil
    local ok = pcall(function() list, items = BridgeInventory.snapshot(body, true) end)
    if not ok or type(list) ~= "table" then return false end
    local counts = {}
    for i = 1, #list do
        local rec = list[i]
        local fullType = rec.t
        local n = (counts[fullType] or 0) + 1
        counts[fullType] = n
        local item = items ~= nil and items[i] or nil
        if visit(rec, item, tostring(fullType) .. "#" .. tostring(n)) == false then return true end
    end
    return true
end

function BridgeTransmog.keyForItem(item)
    if item == nil or Bridge.body == nil then return nil end
    local key = nil
    BridgeTransmog.walk(Bridge.body, function(rec, it, k)
        if it == item then key = k return false end
    end)
    return key
end

function BridgeTransmog.findItemByKey(key)
    if key == nil or Bridge.body == nil then return nil end
    local found = nil
    BridgeTransmog.walk(Bridge.body, function(rec, it, k)
        if k == key then found = it return false end
    end)
    return found
end

local HELPER = "TransmogDE.Hide_Everything"

BridgeTransmog.helperCache = setmetatable({}, { __mode = "k" })

local function helperFor(body, inv)
    if body == nil or inv == nil then return nil end
    local cached = BridgeTransmog.helperCache[body]
    if cached ~= nil then
        local container = nil
        pcall(function() container = cached:getContainer() end)
        if container == inv then return cached end
        BridgeTransmog.helperCache[body] = nil
    end
    local helper = nil
    pcall(function() helper = inv:FindAndReturn(HELPER) end)
    if helper ~= nil then BridgeTransmog.helperCache[body] = helper end
    return helper
end

function BridgeTransmog.wornSignature(body)
    local parts = {}
    local worn = body:getWornItems()
    local items, present = {}, {}
    local count = worn:size()
    for i = 0, count - 1 do
        local it = worn:getItemByIndex(i)
        if it ~= nil then
            items[#items + 1] = it
            local id = nil
            pcall(function() id = it:getID() end)
            if id ~= nil then present[id] = true end
        end
    end
    for i = 1, #items do
        local it = items[i]
        if BridgeTransmog.isDerivedItem(it) then
            local parent, target = nil, nil
            pcall(function()
                local md = it:getModData()
                parent = md and md.TransmogParent
                target = md and md.BridgeTarget
            end)
            parts[#parts + 1] = "D:" .. tostring(it:getFullType()) .. ":" .. tostring(parent)
                .. ":" .. tostring(target)
        else
            local target, child = nil, nil
            pcall(function()
                local md = it:getModData()
                local tmog = md and md.Transmog
                if tmog then
                    target = tmog.transmogTo
                    child = tonumber(tmog.childId)
                end
            end)
            parts[#parts + 1] = "R:" .. tostring(it:getFullType()) .. ":" .. tostring(target)
                .. ":" .. ((child ~= nil and present[child]) and "1" or "0")
        end
    end
    local inv = body:getInventory()
    local helper = helperFor(body, inv)
    local helperWorn = false
    if helper ~= nil then
        pcall(function() helperWorn = helper:isWorn() == true end)
    end
    parts[#parts + 1] = helperWorn and "H1" or "H0"
    return table.concat(parts, ";")
end

local function createCarrier(item, body)
    local carrier = nil
    if isClient() and sendAddItemToContainer ~= nil then
        local original = sendAddItemToContainer
        local replaced = pcall(function() sendAddItemToContainer = function() end end)
        local ok, result = pcall(TransmogDE.createTransmogItem, item, body)
        if replaced then pcall(function() sendAddItemToContainer = original end) end
        if ok then carrier = result end
    else
        local ok, result = pcall(TransmogDE.createTransmogItem, item, body)
        if ok then carrier = result end
    end
    return carrier
end

BridgeTransmog.createCarrier = createCarrier

function BridgeTransmog.rebuildNow(body)
    local worn = body:getWornItems()
    local inv = body:getInventory()
    local helper = helperFor(body, inv)

    local real = {}
    local wanted = {}
    for i = 0, worn:size() - 1 do
        local it = worn:getItemByIndex(i)
        if it ~= nil and not BridgeTransmog.isDerivedItem(it) then
            local id = nil
            pcall(function() id = it:getID() end)
            local target = nil
            if BridgeTransmog.isTransmoggable(it) then
                pcall(function()
                    local md = it:getModData()
                    local tmog = md and md.Transmog
                    if type(tmog) == "table" then target = tmog.transmogTo end
                end)
            end
            real[#real + 1] = { item = it, id = id, target = target }
            if id ~= nil then wanted[id] = target end
        end
    end

    local carriers = {}
    for i = worn:size() - 1, 0, -1 do
        local it = worn:getItemByIndex(i)
        if it ~= nil and it ~= helper and BridgeTransmog.isDerivedItem(it) then
            local parent, target = nil, nil
            pcall(function()
                local md = it:getModData()
                parent = md and md.TransmogParent
                target = md and md.BridgeTarget
            end)
            carriers[#carriers + 1] = { item = it, parent = parent, target = target }
        end
    end

    local keep, keepId, keepParent = {}, {}, {}
    for i = 1, #carriers do
        local c = carriers[i]
        local want = c.parent ~= nil and wanted[c.parent] or nil
        if want ~= nil and want == c.target and not keepParent[c.parent] then
            keep[c.item] = true
            keepParent[c.parent] = true
            local id = nil
            pcall(function() id = c.item:getID() end)
            keepId[c.parent] = id
        else
            pcall(function() worn:remove(c.item) end)
            pcall(function() inv:Remove(c.item) end)
        end
    end

    local items = inv:getItems()
    for i = items:size() - 1, 0, -1 do
        local it = items:get(i)
        if it ~= nil and it ~= helper and not keep[it] and BridgeTransmog.isDerivedItem(it) then
            inv:Remove(it)
        end
    end

    local made = {}
    local complete = true
    for i = 1, #real do
        local entry = real[i]
        local it = entry.item
        if BridgeTransmog.isTransmoggable(it) then
            local tmog = nil
            pcall(function() tmog = TransmogDE.getItemTransmogModData(it) end)
            if type(tmog) == "table" then
                if tmog.transmogTo == nil then
                    pcall(function() TransmogDE.syncHiddenHeadgearVisual(it, true) end)
                    pcall(function() tmog.childId = nil end)
                elseif entry.id ~= nil and keepParent[entry.id] then
                    pcall(function() tmog.childId = keepId[entry.id] end)
                else
                    local carrier = createCarrier(it, body)
                    if carrier ~= nil then
                        pcall(function() carrier:getModData().BridgeTarget = tmog.transmogTo end)
                        made[#made + 1] = carrier
                    else
                        complete = false
                    end
                end
            end
        end
    end

    if complete then
        if helper == nil then
            pcall(function() helper = inv:AddItem(HELPER) end)
            if helper ~= nil then BridgeTransmog.helperCache[body] = helper end
        end
        local hideLocation = nil
        pcall(function()
            hideLocation = TransmogDE.ItemBodyLocation and TransmogDE.ItemBodyLocation.Hide_Everything
        end)
        if helper ~= nil and hideLocation ~= nil then
            pcall(function()
                if worn:getItem(hideLocation) ~= helper then worn:setItem(hideLocation, helper) end
            end)
        end
        local wear = {}
        for i = 1, #carriers do
            local c = carriers[i]
            if keep[c.item] then wear[#wear + 1] = c.item end
        end
        for i = 1, #made do wear[#wear + 1] = made[i] end
        if #wear > 0 then
            pcall(function() TransmogDE.setWornTmogItems(body, wear) end)
        end
    elseif helper ~= nil then
        pcall(function() worn:remove(helper) end)
    end

    pcall(function() body:onWornItemsChanged() end)
    pcall(function() body:resetModelNextFrame() end)
    pcall(function() TransmogDE.reapplyVisualsForAllWorn(body) end)

    if not complete then error("carrier missing", 0) end
end

function BridgeTransmog.rebuild(body, force)
    if not BridgeTransmog.available() then return false end
    if body == nil or Bridge.body == nil then return false end
    if body ~= Bridge.body or Bridge.kind ~= "zombie" then return false end
    if BridgeTransmog.busy or BridgeTransmog.applying then return false end

    local now = Bridge.time or 0
    if not force and BridgeTransmog.retryAt ~= nil and now < BridgeTransmog.retryAt then return false end
    if not force and BridgeTransmog.sig ~= nil
        and BridgeTransmog.sig == BridgeTransmog.wornSignature(body) then return true end

    BridgeTransmog.busy = true
    local ok = pcall(BridgeTransmog.rebuildNow, body)
    BridgeTransmog.busy = nil
    if not ok then
        BridgeTransmog.retryAt = now + 60
        return false
    end

    BridgeTransmog.retryAt = nil
    BridgeTransmog.sig = BridgeTransmog.wornSignature(body)
    if BridgeEquip ~= nil then BridgeEquip.dirty = true end
    if Bridge ~= nil and type(Bridge.itemsChanged) == "function" then pcall(Bridge.itemsChanged) end
    if BridgeInventory ~= nil and type(BridgeInventory.applyWorn) == "function" then
        BridgeTransmog.applying = true
        pcall(BridgeInventory.applyWorn, body)
        BridgeTransmog.applying = nil
    end
    return true
end

function BridgeTransmog.sync(body, force)
    if not BridgeTransmog.available() then return false end
    if body == nil or Bridge.body == nil or body ~= Bridge.body then return false end
    if Bridge.kind ~= "zombie" then return false end
    if BridgeTransmog.busy or BridgeTransmog.applying then return false end
    if BridgeInventory ~= nil and BridgeInventory.restoring == true then return false end

    local now = Bridge.time or 0
    if not force and BridgeTransmog.retryAt ~= nil and now < BridgeTransmog.retryAt then return false end
    if not force and BridgeTransmog.sig ~= nil
        and BridgeTransmog.sig == BridgeTransmog.wornSignature(body) then return true end

    return BridgeTransmog.rebuild(body, true)
end

local MESSAGES = {
    stale = "Her outfit changed, try the transmog again",
    ["not found"] = "That item moved before the transmog applied, try again",
    ["not transmoggable"] = "That item cannot be transmogrified",
    unavailable = "Transmog is not available right now",
    ["too far"] = "Too far from her to change her look",
    batch = "Batch transmog is not available for her",
}

function BridgeTransmog.badMessage(why)
    local player = getSpecificPlayer(0)
    if player == nil then return end
    local text = MESSAGES[why] or "Transmog request failed"
    pcall(function() HaloTextHelper.addBadText(player, text) end)
end

function BridgeTransmog.requestModData()
    if not isClient() then return end
    local player = getSpecificPlayer(0)
    if player == nil then return end
    local module = type(TransmogNet) == "table" and TransmogNet.MODULE_ID or "EURY_TRANSMOG"
    pcall(function() sendClientCommand(player, module, "REQUEST_MODDATA", {}) end)
end

function BridgeTransmog.refresh(body, item)
    if body == nil then return end
    pcall(function() body:resetModelNextFrame() end)
    pcall(function() TransmogDE.reapplyVisualsForAllWorn(body) end)
    pcall(function() triggerEvent("TransmogClothingUpdate", getSpecificPlayer(0), item) end)
    if BridgeEquip ~= nil then BridgeEquip.dirty = true end
    pcall(function()
        local inv = getPlayerInventory(0)
        if inv ~= nil then inv:refreshBackpacks() end
        local loot = getPlayerLoot(0)
        if loot ~= nil then loot:refreshBackpacks() end
        if ISInventoryPage ~= nil then ISInventoryPage.renderDirty = true end
    end)
end

function BridgeTransmog.send(op, item, data)
    if Bridge == nil then return false end
    local key = BridgeTransmog.keyForItem(item)
    if key == nil then
        BridgeTransmog.badMessage("not found")
        return false
    end
    local seed = nil
    pcall(function()
        local md = TransmogDE.getItemTransmogModData(item)
        if type(md) == "table" then
            seed = BridgeTransmogLogic.deepCopy(md)
            seed.childId = nil
        end
    end)
    sendClientCommand(BridgeData.owner(), "Bridge", "transmog", {
        iseq = tonumber(Bridge.iseq) or 0,
        key = key,
        op = op,
        data = data,
        md = seed,
    })
    return true
end

function BridgeTransmog.request(op, item, data)
    if not BridgeTransmog.available() then return false end
    if item == nil or not OPERATIONS[op] then return false end
    if not BridgeTransmog.isCompanionItem(item) then return false end
    if Bridge.mp then return BridgeTransmog.send(op, item, data) end

    local ok, why = BridgeTransmogLogic.applyToItem(item, op, data)
    if not ok then
        BridgeTransmog.badMessage(why)
        return false
    end
    BridgeTransmog.rebuild(Bridge.body, true)
    BridgeTransmog.refresh(Bridge.body, item)
    if Bridge ~= nil and type(Bridge.saveOutfit) == "function" then
        pcall(Bridge.saveOutfit, nil, true)
    end
    return true
end

function BridgeTransmog.addMenu(context, item)
    if context == nil or item == nil then return false end
    if not BridgeTransmog.available() then return false end
    if not BridgeTransmog.isCompanionItem(item) then return false end
    if not BridgeTransmog.isTransmoggable(item) then return false end
    local player = getSpecificPlayer(0)
    if player == nil then return false end

    local option = context:addOption(tr("IGUI_TransmogDE_Context_Menu", "Transmog"))
    pcall(function() option.iconTexture = getTexture("media/ui/TransmogIcon.png") end)
    local sub = context:getNew(context)
    context:addSubMenu(option, sub)

    sub:addOption(tr("IGUI_TransmogDE_Context_Transmogrify", "Transmogrify"), player, function()
        if TransmogListViewer ~= nil and type(TransmogListViewer.Open) == "function" then
            TransmogListViewer.Open(player, item)
        end
    end)

    local hidden = false
    pcall(function() hidden = TransmogDE.isClothingHidden(item) == true end)
    if hidden then
        sub:addOption(tr("IGUI_TransmogDE_Context_Show", "Show"), item,
            function(t) BridgeTransmog.request("show", t) end)
    else
        sub:addOption(tr("IGUI_TransmogDE_Context_Hide", "Hide"), item,
            function(t) BridgeTransmog.request("hide", t) end)
    end

    local tmog = nil
    pcall(function() tmog = TransmogDE.getItemTransmogModData(item) end)
    local target = type(tmog) == "table" and (tmog.transmogTo or tmog.lastTransmogTo) or nil
    local asset = nil
    if type(target) == "string" and target ~= "" then
        pcall(function()
            local scriptItem = ScriptManager.instance:getItem(target)
            if scriptItem ~= nil then asset = TransmogDE.getClothingItemAsset(scriptItem) end
        end)
    end

    if asset ~= nil then
        local allowTint = false
        pcall(function() allowTint = asset:getAllowRandomTint() == true end)
        if allowTint and ColorPickerModal ~= nil and type(ColorPickerModal.Open) == "function" then
            sub:addOption(tr("IGUI_TransmogDE_Context_Color", "Color"), player, function()
                ColorPickerModal.Open(player, item)
            end)
        end

        local choices = nil
        pcall(function()
            if asset:hasModel() then
                choices = asset:getTextureChoices()
            else
                choices = asset:getBaseTextures()
            end
        end)
        if choices ~= nil and choices:size() > 1
            and TexturePickerModal ~= nil and type(TexturePickerModal.Open) == "function" then
            sub:addOption(tr("IGUI_TransmogDE_Context_Texture", "Texture"), player, function()
                TexturePickerModal.Open(player, item, choices)
            end)
        end
    end

    local canRemove, canReset = false, false
    pcall(function() canRemove = TransmogDE.canRemoveTransmog(item) == true end)
    pcall(function() canReset = TransmogDE.canResetTransmog(item) == true end)
    if canRemove then
        local removeOption = sub:addOption(tr("IGUI_TransmogDE_Context_RemoveTransmog", "Remove"),
            item, function(t) BridgeTransmog.request("remove", t) end)
        removeOption.goodColor = true
    end
    if canReset then
        local resetOption = sub:addOption(tr("IGUI_TransmogDE_Context_Default", "Default"),
            item, function(t) BridgeTransmog.request("reset", t) end)
        resetOption.badColor = true
    end

    return true
end

function BridgeTransmog.filterRecord(item, rec)
    if not BridgeTransmog.available() then return true end
    if BridgeTransmog.isDerivedItem(item) then return false end
    if type(rec) ~= "table" or type(rec.md) ~= "table" then return true end
    local tmog = rec.md.Transmog
    if type(tmog) == "table" then tmog.childId = nil end
    if BridgeTransmogLogic ~= nil and type(BridgeTransmogLogic.isDefaultTransmog) == "function"
        and BridgeTransmogLogic.isDefaultTransmog(rec.t, rec.md) then
        rec.md.Transmog = nil
        local any = false
        for _ in pairs(rec.md) do any = true break end
        if not any then rec.md = nil end
    end
    return true
end

function BridgeTransmog.visualRecord(rec)
    if not BridgeTransmog.available() then return nil end
    return BridgeTransmogLogic.visualRecord(rec)
end

function BridgeTransmog.filterPane(pane)
    if pane == nil or pane.itemslist == nil or pane.inventory == nil then return end
    if not BridgeTransmog.available() then return end
    if BridgeInventory == nil or type(BridgeInventory.isHers) ~= "function" then return end
    local hers = false
    pcall(function() hers = BridgeInventory.isHers(pane.inventory) == true end)
    if not hers then return end

    local list = pane.itemslist
    local out = {}
    local changed = false
    for i = 1, #list do
        local row = list[i]
        local rowItem = (row and row.items and row.items[1]) or row
        if BridgeTransmog.isDerivedItem(rowItem) then
            changed = true
        else
            out[#out + 1] = row
        end
    end
    if changed then
        pane.itemslist = out
        pane.cachedItemList = out
    end
end

local function installPaneFilter()
    if ISInventoryPane == nil or type(ISInventoryPane.refreshContainer) ~= "function" then return end
    if ISInventoryPane.bridgeTransmogWrapped then return end
    local previous = ISInventoryPane.refreshContainer
    ISInventoryPane.refreshContainer = function(self, ...)
        local result = previous(self, ...)
        pcall(BridgeTransmog.filterPane, self)
        return result
    end
    ISInventoryPane.bridgeTransmogWrapped = true
end

local REQUEST_WRAPPERS = {
    { "requestTransmog", "transmogrify" },
    { "requestHide", "hide" },
    { "requestShow", "show" },
    { "requestRemoveTransmog", "remove" },
    { "requestResetDefault", "reset" },
    { "requestSetColor", "color" },
    { "requestSetTexture", "texture" },
}

local BATCH_WRAPPERS = {
    "requestHideAll",
    "requestShowAll",
    "requestRemoveTransmogAll",
    "requestResetDefaultAll",
}

BridgeTransmog.wrapped = BridgeTransmog.wrapped or {}

local function wrapRequests()
    if type(TransmogNet) ~= "table" then return end

    for i = 1, #REQUEST_WRAPPERS do
        local name = REQUEST_WRAPPERS[i][1]
        local op = REQUEST_WRAPPERS[i][2]
        local original = TransmogNet[name]
        if type(original) == "function" and BridgeTransmog.wrapped[name] ~= original then
            local wrapper = function(player, item, data)
                if BridgeTransmog.isCompanionItem(item) then
                    local payload = data
                    if op == "transmogrify" then payload = { target = data } end
                    BridgeTransmog.request(op, item, payload)
                    return
                end
                return original(player, item, data)
            end
            BridgeTransmog.wrapped[name] = wrapper
            TransmogNet[name] = wrapper
        end
    end

    for i = 1, #BATCH_WRAPPERS do
        local name = BATCH_WRAPPERS[i]
        local original = TransmogNet[name]
        if type(original) == "function" and BridgeTransmog.wrapped[name] ~= original then
            local wrapper = function(player, focusItem)
                local viewer = TransmogListViewer ~= nil and TransmogListViewer.instance or nil
                local item = (viewer ~= nil and viewer.item) or focusItem
                if item ~= nil and BridgeTransmog.isCompanionItem(item) then
                    BridgeTransmog.badMessage("batch")
                    return
                end
                return original(player, focusItem)
            end
            BridgeTransmog.wrapped[name] = wrapper
            TransmogNet[name] = wrapper
        end
    end
end

BridgeTransmog.wrapRequests = wrapRequests

function BridgeTransmog.onServerCommand(module, command, args)
    if module ~= "Bridge" then return end
    if command ~= "transmogApplied" and command ~= "transmogFailed" then return end
    args = args or {}

    if command == "transmogFailed" then
        BridgeTransmog.badMessage(args.why)
        log("transmog failed: " .. tostring(args.why) .. " op=" .. tostring(args.op))
        return
    end

    if Bridge == nil then return end
    if type(args.iseq) == "number" then Bridge.iseq = args.iseq end

    local item = BridgeTransmog.findItemByKey(args.key)
    if item == nil then
        BridgeTransmog.badMessage("not found")
        BridgeTransmog.requestModData()
        log("transmog applied but item is gone: " .. tostring(args.key))
        return
    end

    pcall(function()
        local md = item:getModData()
        if type(args.md) == "table" then
            md.Transmog = BridgeTransmogLogic.deepCopy(args.md)
        else
            md.Transmog = nil
        end
    end)

    BridgeTransmog.rebuild(Bridge.body, true)
    BridgeTransmog.refresh(Bridge.body, item)
end

Events.OnServerCommand.Add(BridgeTransmog.onServerCommand)

Events.OnGameStart.Add(function()
    pcall(wrapRequests)
    pcall(installPaneFilter)
end)

pcall(wrapRequests)

return BridgeTransmog
