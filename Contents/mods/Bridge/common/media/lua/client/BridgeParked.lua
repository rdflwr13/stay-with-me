----------------------------------------------------------------------------------------------------
-- BridgeParked: show the companion's inventory while the player drives, and allow moving items
-- in and out of it through the vanilla loot pane.
--
-- While she rides in the car her body is despawned. This module rebuilds a stand-in container
-- (main + worn bags) from the saved snapshot (Bridge.store.items) so the loot pane can show it,
-- and writes the snapshot back so her body is dressed correctly when she gets out again.
--
-- Singleplayer: this container is the source of truth while parked; every change is written back
-- to the store. Multiplayer: it is a client-side mirror of the server-owned snapshot; take/give go
-- through the existing server commands and the mirror follows the server responses.
--
-- Everything here is defensive: the file loads after BridgeMain.lua, so every cross reference is
-- resolved at call time and wrapped in pcall.
-----------------------------------------------------------------------------------------------------

BridgeParked = BridgeParked or {}

BridgeParked.active = false
BridgeParked.car = nil
BridgeParked.main = nil
BridgeParked.bags = {}
BridgeParked.locked = setmetatable({}, { __mode = "k" })
BridgeParked.extra = setmetatable({}, { __mode = "k" })
BridgeParked.why = nil
BridgeParked.savedSig = nil
BridgeParked.containerType = "BridgeParked"

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeParked] " .. tostring(text)) end end
local function warn(text) print("[BridgeParked] " .. tostring(text)) end

local function store()
    local md = nil
    pcall(function() if Bridge ~= nil then md = Bridge.store end end)
    return md
end

local function owner()
    local red = nil
    pcall(function() red = BridgeData.owner() end)
    return red
end

local function companionName()
    local name = "?"
    pcall(function() if Bridge ~= nil then name = Bridge.companionName() end end)
    if type(name) ~= "string" or name == "" then name = "?" end
    return name
end

local function isMP()
    local mp = false
    pcall(function() if Bridge ~= nil then mp = Bridge.mp == true end end)
    return mp
end

local function refreshPanels()
    local inv, loot = getPlayerInventory(0), getPlayerLoot(0)
    if inv == nil or loot == nil then return end
    pcall(function()
        inv:refreshBackpacks()
        loot:refreshBackpacks()
        ISInventoryPage.renderDirty = true
    end)
end


----------------------------------------------------------------------------------------------------
-- identity
-----------------------------------------------------------------------------------------------------

function BridgeParked.isParked(container)
    if not BridgeParked.active or container == nil then return false end
    local main = BridgeParked.main
    if main == nil then return false end
    if container == main then return true end
    local outer = container
    pcall(function() outer = container:getOutermostContainer() end)
    return outer == main
end

function BridgeParked.isRoot(container, item)
    local main = BridgeParked.main
    if main == nil or item == nil then return false end
    local c = nil
    pcall(function() c = item:getContainer() end)
    return c ~= nil and c == main
end

function BridgeParked.lockedItem(item)
    return item ~= nil and BridgeParked.locked[item] == true
end

function BridgeParked.inSameCar()
    local red = owner()
    if red == nil then return false end
    local inside, car = false, nil
    pcall(function()
        if BridgeCar ~= nil then
            inside = BridgeCar.isInside()
            car = BridgeCar.car
        end
    end)
    if not inside then return false end
    local v = nil
    pcall(function() v = red:getVehicle() end)
    return v ~= nil and (car == nil or v == car)
end


----------------------------------------------------------------------------------------------------
-- build / extra / save
-----------------------------------------------------------------------------------------------------

function BridgeParked.rebuild()
    local md = store()
    local text = ""
    if md ~= nil and type(md.items) == "string" then text = md.items end
    local list = {}
    pcall(function() list = BridgeItems.decode(text) end)

    local main = ItemContainer.new(BridgeParked.containerType, nil, nil)
    if main == nil then warn("could not create parked container") return 0 end
    pcall(function() main:setExplored(true) end)
    local cap = nil
    pcall(function() cap = BridgeInventory.herCapacity() end)
    if type(cap) == "number" and cap > 0 then pcall(function() main:setCapacity(cap) end) end

    BridgeParked.main = main
    BridgeParked.bags = {}
    BridgeParked.locked = setmetatable({}, { __mode = "k" })
    BridgeParked.extra = setmetatable({}, { __mode = "k" })

    local made = {}
    for i, rec in ipairs(list) do
        pcall(function()
            local container = main
            if rec.p ~= nil then
                local parent = made[rec.p]
                if parent ~= nil and parent:IsInventoryContainer() then container = parent:getInventory() end
            end
            local item = BridgeItems.make(container, rec)
            made[i] = item
            if item == nil then return end
            BridgeParked.extra[item] = { w = rec.w, h = rec.h, as = rec.as, ga = rec.ga, gt = rec.gt, gp = rec.gp }
            if rec.w or (tonumber(rec.h) or 0) > 0 or rec.as then BridgeParked.locked[item] = true end
            if container == main then
                local isBag = false
                pcall(function() isBag = item:IsInventoryContainer() end)
                if isBag and rec.w then
                    BridgeParked.bags[#BridgeParked.bags + 1] = { item = item, container = item:getInventory() }
                end
            end
        end)
    end
    BridgeParked.savedSig = text
    return #list
end

function BridgeParked.snapshot()
    local main = BridgeParked.main
    if main == nil then return nil end
    local out = {}
    local extra = BridgeParked.extra
    pcall(function()
        local function walk(container, parent)
            local items = container:getItems()
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item ~= nil then
                    local rec = BridgeItems.record(item, false)
                    if parent ~= nil then rec.p = parent end
                    local f = extra[item]
                    if f ~= nil then
                        if f.w then rec.w = true end
                        if f.h ~= nil and f.h ~= 0 then rec.h = f.h end
                        if f.as then rec.as = true end
                        if f.ga ~= nil then rec.ga = f.ga end
                        if f.gt ~= nil then rec.gt = f.gt end
                        if f.gp ~= nil then rec.gp = f.gp end
                    end
                    out[#out + 1] = rec
                    local index = #out
                    local isBag = false
                    pcall(function() isBag = item:IsInventoryContainer() end)
                    if isBag then walk(item:getInventory(), index) end
                end
            end
        end
        walk(main, nil)
    end)
    return out
end

function BridgeParked.save()
    if not BridgeParked.active then return false end
    if isMP() then return false end
    local md = store()
    if md == nil then return false end
    local list = BridgeParked.snapshot()
    if list == nil then return false end
    local text = nil
    BridgeItems.truncated = false
    local ok = pcall(function() text = BridgeItems.encode(list) end)
    if not ok or text == nil then return false end
    if BridgeItems.truncated == true then
        log("parked snapshot truncated, kept the previous one")
        return false
    end
    local saved = false
    pcall(function()
        md.items = text
        md.saved = 1
        md.cut = nil
        saved = true
    end)
    if saved then BridgeParked.savedSig = text end
    return saved
end


----------------------------------------------------------------------------------------------------
-- enter / exit / server notice
-----------------------------------------------------------------------------------------------------

function BridgeParked.notifyServer(on)
    local red = owner()
    if red == nil then return end
    pcall(function()
        sendClientCommand(red, "Bridge", "parked", { on = on == true })
    end)
end

function BridgeParked.enter(car, why)
    if BridgeParked.active then
        if car ~= nil then BridgeParked.car = car end
        return
    end
    BridgeParked.active = true
    BridgeParked.car = car
    BridgeParked.why = why
    local n = 0
    pcall(function() n = BridgeParked.rebuild() end)
    if isMP() then pcall(BridgeParked.notifyServer, true) end
    refreshPanels()
    log(string.format("enter (%s): %d records", tostring(why), tonumber(n) or 0))
end

function BridgeParked.exit(why)
    if not BridgeParked.active then return end
    pcall(BridgeParked.save)
    BridgeParked.active = false
    BridgeParked.car = nil
    BridgeParked.main = nil
    BridgeParked.bags = {}
    BridgeParked.locked = setmetatable({}, { __mode = "k" })
    BridgeParked.extra = setmetatable({}, { __mode = "k" })
    if isMP() then pcall(BridgeParked.notifyServer, false) end
    refreshPanels()
    log("exit " .. tostring(why))
end


----------------------------------------------------------------------------------------------------
-- loot pane buttons
-----------------------------------------------------------------------------------------------------

function BridgeParked.addButtons(page)
    if page == nil or page.onCharacter then return false end
    if not BridgeParked.active or BridgeParked.main == nil then return false end
    if not BridgeParked.inSameCar() then return false end
    local red = getSpecificPlayer(page.player or 0)
    if red == nil then return false end

    local function has(container)
        for _, btn in ipairs(page.backpacks or {}) do
            if btn.inventory == container then return true end
        end
        return false
    end

    local added = false
    local ok, err = pcall(function()
        local main = BridgeParked.main
        if not has(main) then
            main:setExplored(true)
            local icon = getTexture("media/ui/Icon_InventoryBasic.png")
            local name = companionName()
            local button = page:addContainerButton(main, icon, name, name)
            local bcap = nil
            pcall(function() bcap = main:getEffectiveCapacity(red) end)
            if type(bcap) ~= "number" or bcap <= 0 then
                pcall(function() bcap = BridgeInventory.herCapacity() end)
            end
            button.capacity = bcap
            added = true
        end
        for _, bag in ipairs(BridgeParked.bags) do
            local bagInv = bag.container
            local it = bag.item
            if bagInv ~= nil and it ~= nil and not has(bagInv) then
                bagInv:setExplored(true)
                local button = page:addContainerButton(bagInv, it:getTex(), it:getName(), it:getName())
                pcall(function()
                    local vis = it:getVisual()
                    local ci = it:getClothingItem()
                    local tint = (vis ~= nil and ci ~= nil) and vis:getTint(ci) or nil
                    if tint ~= nil then button:setTextureRGBA(tint:getRedFloat(), tint:getGreenFloat(), tint:getBlueFloat(), 1.0) end
                end)
                added = true
            end
        end
    end)
    if not ok then warn("addButtons failed: " .. tostring(err)) end
    return added
end


----------------------------------------------------------------------------------------------------
-- context menu + take all
-----------------------------------------------------------------------------------------------------

function BridgeParked.onFill(playerNum, context, items)
    if context == nil or not BridgeParked.active then return end
    local list = nil
    pcall(function()
        if BridgeInventory ~= nil and BridgeInventory.actualItems ~= nil then list = BridgeInventory.actualItems(items) end
    end)
    if type(list) ~= "table" or #list == 0 then return end
    local anyLocked = false
    for _, it in ipairs(list) do
        if BridgeParked.locked[it] then anyLocked = true break end
    end
    if not anyLocked then return end
    local text = "Worn while driving (cannot be moved)"
    pcall(function()
        if BridgeData ~= nil and type(BridgeData.text) == "function" then text = BridgeData.text("ParkedWorn", companionName()) end
    end)
    local opt = context:addOption(text, nil)
    if opt ~= nil then opt.notAvailable = true end
end

function BridgeParked.lootAll(pane)
    if pane == nil or pane.inventory == nil then return end
    local playerNum = pane.player or 0
    local playerInv = getPlayerInventory(playerNum)
    if playerInv == nil then return end
    local items = {}
    pcall(function()
        local it = pane.inventory:getItems()
        for i = 0, it:size() - 1 do
            local item = it:get(i)
            if item ~= nil and not BridgeParked.locked[item] then
                local heavy = false
                pcall(function() heavy = isForceDropHeavyItem ~= nil and isForceDropHeavyItem(item) end)
                if not heavy then items[#items + 1] = item end
            end
        end
    end)
    if #items > 0 then pcall(function() pane:transferItemsByWeight(items, playerInv.inventory) end) end
    pane.selected = {}
    pcall(function() getPlayerLoot(playerNum).inventoryPane.selected = {} end)
    pcall(function() getPlayerInventory(playerNum).inventoryPane.selected = {} end)
    pcall(BridgeParked.save)
end


----------------------------------------------------------------------------------------------------
-- visual cue for locked (worn/held) items
-----------------------------------------------------------------------------------------------------

function BridgeParked.drawLocks(pane)
    if pane == nil or pane.inventory == nil then return end
    if not BridgeParked.isParked(pane.inventory) then return end
    local locked = BridgeParked.locked
    local ih, hh = pane.itemHgt, pane.headerHgt
    if type(ih) ~= "number" or type(hh) ~= "number" then return end
    local maxStack = 1000
    pcall(function() maxStack = ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER end)
    local y = 0
    for _, v in ipairs(pane.itemslist or {}) do
        local items = v.items or {}
        local count = 1
        for k = 1, #items do
            local item = items[count]
            if item ~= nil and locked[item] then
                pcall(function()
                    pane:drawRect(1, (y * ih) + hh, pane:getWidth() - 1, ih, 0.35, 0.0, 0.0, 0.0)
                end)
            end
            y = y + 1
            if count == 1 and pane.collapsed ~= nil and v.name ~= nil and pane.collapsed[v.name] then break end
            if count >= maxStack + 1 then break end
            count = count + 1
        end
    end
end

function BridgeParked.wrapPane()
    if ISInventoryPane == nil or type(ISInventoryPane.renderdetails) ~= "function"
        or ISInventoryPane.bridgeParkedWrapped then return end
    local renderdetails = ISInventoryPane.renderdetails
    ISInventoryPane.renderdetails = function(self, doDragged, ...)
        renderdetails(self, doDragged, ...)
        if BridgeParked.active and not doDragged then pcall(BridgeParked.drawLocks, self) end
    end
    ISInventoryPane.bridgeParkedWrapped = true
    log("inventory pane wrapped for the parked lock cue")
end

-----------------------------------------------------------------------------------------------------
-- displayed weight
--
-- The parked container is a plain ItemContainer; nothing in it is worn/equipped, so the engine
-- counts every item at its full unequipped weight. Her real body inventory applies each worn
-- bag's WeightReduction to that bag's contents ("17.12 / 15" instead of "8.55 / 15" while driving).
-- Reproduce that here for the pane's weight label so the parked main reads the same as on foot.
-- The bag buttons are separate containers and keep their own (unreduced) weight.
-----------------------------------------------------------------------------------------------------

function BridgeParked.loadWeight(container)
    local main = BridgeParked.main
    if main == nil or container == nil or container ~= main then return nil end
    local total = nil
    pcall(function() total = main:getCapacityWeight() end)
    if type(total) ~= "number" then return nil end
    local extra = BridgeParked.extra
    pcall(function()
        local items = main:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item ~= nil then
                local f = extra[item]
                if f ~= nil and f.w == true and item:IsInventoryContainer() then
                    local red = 0
                    pcall(function() red = item:getWeightReduction() end)
                    if type(red) == "number" and red > 0 then
                        local full, own = nil, nil
                        pcall(function() full = item:getUnequippedWeight() end)
                        pcall(function() own = item:getActualWeight() end)
                        if type(full) == "number" and type(own) == "number" and own <= full then
                            total = total - (full - own) * (red / 100)
                        end
                    end
                end
            end
        end
    end)
    pcall(function() total = ItemContainer.floatingPointCorrection(total) end)
    if type(total) ~= "number" or total < 0 then return nil end
    return total
end

function BridgeParked.wrapLoad()
    if ISInventoryPage == nil or type(ISInventoryPage.loadWeight) ~= "function"
        or ISInventoryPage.bridgeParkedLoadWrapped then return end
    local loadWeight = ISInventoryPage.loadWeight
    ISInventoryPage.loadWeight = function(inv, ...)
        if BridgeParked.active and BridgeParked.main ~= nil then
            local ok, w = pcall(BridgeParked.loadWeight, inv)
            if ok and type(w) == "number" then return w end
        end
        return loadWeight(inv, ...)
    end
    ISInventoryPage.bridgeParkedLoadWrapped = true
    log("loadWeight wrapped: the parked weight counts a worn bag's reduction")
end

pcall(BridgeParked.wrapPane)
pcall(BridgeParked.wrapLoad)
if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(BridgeParked.wrapPane) pcall(BridgeParked.wrapLoad) end)
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeParked] loaded") end
