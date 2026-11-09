require "ISUI/ISPanelJoypad"
require "ISUI/ISWorldObjectContextMenu"

BridgeWorkSelect = BridgeWorkSelect or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeWorkSelect] " .. tostring(text)) end end

local UI = ISPanelJoypad:derive("BridgeWorkSelectUI")
BridgeWorkSelect.UI = UI

BridgeWorkSelect.active = nil
BridgeWorkSelect.lockCount = 0
BridgeWorkSelect.lockPrev = nil
BridgeWorkSelect.MAX_SIDE = 40
BridgeWorkSelect.MAX_TREES = 80
BridgeWorkSelect.MAX_STAINS = 80
BridgeWorkSelect.MAX_PLANTS = 80
BridgeWorkSelect.MAX_LOOT_ITEMS = 80
BridgeWorkSelect.MAX_CORPSES = 40
BridgeWorkSelect.MAX_DOORS = 80

local function acquireLock()
    if BridgeWorkSelect.lockCount == 0 then
        BridgeWorkSelect.lockPrev = ISWorldObjectContextMenu.disableWorldMenu
        ISWorldObjectContextMenu.disableWorldMenu = true
    end
    BridgeWorkSelect.lockCount = BridgeWorkSelect.lockCount + 1
end

local function releaseLock()
    if BridgeWorkSelect.lockCount <= 0 then return end
    BridgeWorkSelect.lockCount = BridgeWorkSelect.lockCount - 1
    if BridgeWorkSelect.lockCount == 0 then
        ISWorldObjectContextMenu.disableWorldMenu = BridgeWorkSelect.lockPrev
        BridgeWorkSelect.lockPrev = nil
    end
end

function UI:pickSquare()
    local mx, my = getMouseX(), getMouseY()
    local x = math.floor(screenToIsoX(self.playerNum, mx, my, self.level))
    local y = math.floor(screenToIsoY(self.playerNum, mx, my, self.level))
    return getCell():getGridSquare(x, y, self.level), x, y
end

function UI:bounds()
    if self.startX == nil or self.endX == nil then return nil end
    return { x1 = math.min(self.startX, self.endX), y1 = math.min(self.startY, self.endY),
             x2 = math.max(self.startX, self.endX), y2 = math.max(self.startY, self.endY), z = self.level }
end



function UI:countTargets(b)
    local key = b.x1 .. ":" .. b.y1 .. ":" .. b.x2 .. ":" .. b.y2 .. ":" .. b.z
    if self.countKey == key then return self.count or 0 end
    local def = BridgeWorkSelect.kinds[self.kind] or BridgeWorkSelect.kinds.chopTree
    local list = nil
    pcall(function() list = def.collect(b) end)
    self.countKey = key
    self.count = list ~= nil and #list or 0
    self.countList = list
    self.countListKey = key
    return self.count
end

function UI:valid(b)
    if b == nil then return false end
    local w = b.x2 - b.x1 + 1
    local h = b.y2 - b.y1 + 1
    local def = BridgeWorkSelect.kinds[self.kind] or BridgeWorkSelect.kinds.chopTree
    local side = def.maxSide or BridgeWorkSelect.MAX_SIDE
    if w > side or h > side then return false end


    if def.min ~= nil then
        local n = self:countTargets(b)
        return n >= def.min and n <= def.max
    end

    if w * h <= def.max then return true end


    return self:countTargets(b) <= def.max
end

function UI:quickValid(b)
    if b == nil then return false, true end
    local w = b.x2 - b.x1 + 1
    local h = b.y2 - b.y1 + 1
    local def = BridgeWorkSelect.kinds[self.kind] or BridgeWorkSelect.kinds.chopTree
    local side = def.maxSide or BridgeWorkSelect.MAX_SIDE
    if w > side or h > side then return false, true end
    if def.min == nil and w * h <= (def.max or math.huge) then return true, true end
    return true, false
end

function UI:close()
    if self.closed then return end
    self.closed = true
    self:releaseControllerFocus()
    self:setVisible(false)
    self:removeFromUIManager()
    if BridgeWorkSelect.active == self then BridgeWorkSelect.active = nil end
    releaseLock()
end

function UI:start(b)
    local def = BridgeWorkSelect.kinds[self.kind] or BridgeWorkSelect.kinds.chopTree
    local key = b.x1 .. ":" .. b.y1 .. ":" .. b.x2 .. ":" .. b.y2 .. ":" .. b.z
    local targets = nil
    if self.countListKey == key then targets = self.countList end
    self.countList, self.countListKey = nil, nil
    if targets == nil then targets = def.collect(b) end
    self:close()
    if #targets == 0 then
        if Bridge ~= nil then Bridge.speak(def.noneSay) end
        return
    end
    if #targets > def.max then
        if Bridge ~= nil then Bridge.speak("JobTooBig") end
        return
    end
    local doorMode = self.kind == "openDoors" and "open" or (self.kind == "closeDoors" and "close" or nil)
    if doorMode ~= nil then
        local pre = nil
        pcall(function() pre = BridgeTask.doorPreflight(targets, doorMode) end)
        if pre ~= nil and pre ~= "ok" then
            if Bridge ~= nil then
                if pre == "locked" then Bridge.speak("JobDoorLocked")
                elseif pre == "barricade" then Bridge.speak("JobDoorBarricaded")
                else Bridge.speak(def.noneSay) end
            end
            return
        end
    end
    BridgeWorkSelect.sortTargets(targets)
    local res = nil
    local doorKind = self.kind == "openDoors" or self.kind == "closeDoors"
    if doorKind and BridgeCar ~= nil and BridgeCar.isInside()
            and type(BridgeCar.startDoorTask) == "function" then
        res = BridgeCar.startDoorTask(self.kind, targets)
    elseif type(def.start) == "function" then
        res = def.start(targets)
    else
        res = BridgeTask.start(self.kind, targets)
    end
    log("area job " .. tostring(res) .. " kind=" .. tostring(self.kind) .. " targets=" .. tostring(#targets))
end

function UI:startMove(sq)
    local targets = self.pendingTargets or {}
    self:close()
    if #targets == 0 then
        if Bridge ~= nil then Bridge.speak("JobNoCorpses") end
        return
    end
    local dest = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
    local res = BridgeTask.start("moveCorpses", targets, dest)
    log("corpse job " .. tostring(res) .. " targets=" .. tostring(#targets))
end

function UI:anchorAt(wx, wy)
    local sq = getCell():getGridSquare(wx, wy, self.level)
    if sq == nil or not sq:getFloor() then return end
    self.startX, self.startY = wx, wy
    self.endX, self.endY = wx, wy
    self.dragging = true
end

function UI:confirmSelection()
    if self.awaitDest then return true end
    if not self.dragging then return true end
    self.dragging = false
    local b = self:bounds()
    self.startX, self.startY, self.endX, self.endY = nil, nil, nil, nil
    local def = BridgeWorkSelect.kinds[self.kind] or BridgeWorkSelect.kinds.chopTree
    if not self:valid(b) then
        if Bridge ~= nil then
            local w = b.x2 - b.x1 + 1
            local h = b.y2 - b.y1 + 1
            local side = def.maxSide or BridgeWorkSelect.MAX_SIDE
            local tooBig = (w > side or h > side)
            if not tooBig then tooBig = self:countTargets(b) > def.max end
            if tooBig then Bridge.speak("JobTooBig") else Bridge.speak(def.noneSay) end
        end
        self:close()
        return true
    end
    if def.destination == true then
        local targets = def.collect(b)
        if #targets == 0 then
            if Bridge ~= nil then Bridge.speak(def.noneSay) end
            self:close()
            return true
        end
        if #targets > def.max then
            if Bridge ~= nil then Bridge.speak("JobTooBig") end
            self:close()
            return true
        end
        BridgeWorkSelect.sortTargets(targets)
        self.pendingTargets = targets
        self.awaitDest = true
        if Bridge ~= nil then Bridge.speak("JobPickSpot") end
        return true
    end
    self:start(b)
    return true
end

function UI:cancelSelection()
    self:close()
end

function UI:releaseControllerFocus()
    if self.playerNum ~= nil and getJoypadFocus(self.playerNum) == self then
        setPrevFocusForPlayer(self.playerNum)
    end
    self.joypadFocus = nil
    self.controller = false
end

function UI:onMouseDownOutside(x, y)
    if self.controller then self:releaseControllerFocus() end
    if self.awaitDest then
        local sq = self:pickSquare()
        if sq == nil then return true end
        if not BridgeWorkSelect.isDestinationValid(sq) then
            if Bridge ~= nil then Bridge.speak("JobBadSpot") end
            return true
        end
        self:startMove(sq)
        return true
    end
    local sq, wx, wy = self:pickSquare()
    if sq == nil then return true end
    self:anchorAt(wx, wy)
    return true
end

function UI:onMouseMoveOutside(dx, dy)
    local sq, wx, wy = self:pickSquare()
    if self.dragging and sq ~= nil then
        self.endX, self.endY = wx, wy
    end
    return true
end

function UI:onMouseUpOutside(x, y)
    return self:confirmSelection()
end

function UI:onRightMouseDownOutside(x, y)
    self:cancelSelection()
    return true
end

function UI:prerender()
    if self.closed then return end
    local sq, wx, wy = nil, nil, nil
    if self.joypadFocus ~= nil then
        wx, wy = self.joypadWorldX, self.joypadWorldY
        sq = getCell():getGridSquare(wx, wy, self.level)
    else
        sq, wx, wy = self:pickSquare()
    end
    if self.awaitDest then
        local ok = BridgeWorkSelect.isDestinationValid(sq)
        if ok then
            addAreaHighlightForPlayer(self.playerNum, wx, wy, wx + 1, wy + 1, self.level, 0.1, 1.0, 0.1, 0.55)
        else
            addAreaHighlightForPlayer(self.playerNum, wx, wy, wx + 1, wy + 1, self.level, 1.0, 0.1, 0.1, 0.55)
        end
        return
    end
    local b = self:bounds()
    if b ~= nil then
        local ok, known = self:quickValid(b)
        local vr, vg, vb = 0.1, 1.0, 0.1
        local ir, ig, ib = 1.0, 0.1, 0.1
        if self.kind == "depositArea" then
            vr, vg, vb = 0.2, 0.5, 1.0
            ir, ig, ib = 1.0, 0.6, 0.1
        end
        local r, g, bl = 1.0, 1.0, 1.0
        if known then
            if ok then r, g, bl = vr, vg, vb else r, g, bl = ir, ig, ib end
        end
        addAreaHighlightForPlayer(self.playerNum, b.x1, b.y1, b.x2 + 1, b.y2 + 1, b.z,
            r, g, bl, 0.35)
    elseif sq ~= nil then
        addAreaHighlightForPlayer(self.playerNum, wx, wy, wx + 1, wy + 1, self.level, 0.1, 1.0, 0.1, 0.55)
    end
end

function UI:new(playerObj, kind)
    local o = ISPanelJoypad.new(self, -1000, -1000, 1, 1)
    o.playerObj = playerObj
    o.kind = kind or "chopTree"
    o.playerNum = playerObj:getPlayerNum()
    o.level = playerObj:getCurrentSquare():getZ()
    o.dragging = false
    o.closed = false
    o.background = false
    o.border = false
    o.awaitDest = false
    o.pendingTargets = nil
    o.joypadWorldX = playerObj:getCurrentSquare():getX()
    o.joypadWorldY = playerObj:getCurrentSquare():getY()
    o.joypadFocus = nil
    o.controller = false
    o.holdA = false
    return o
end

function UI:joypadSquareAt(x, y)
    return getCell():getGridSquare(x, y, self.level)
end

function UI:joypadStep(dx, dy)
    local fromX = self.joypadWorldX
    local fromY = self.joypadWorldY
    if self.startX ~= nil and self.endX ~= nil and self.endY ~= nil then
        fromX = self.endX
        fromY = self.endY
    end
    local x = fromX + dx
    local y = fromY + dy
    local sq = self:joypadSquareAt(x, y)
    if sq == nil then return end
    if self.awaitDest then
        if not BridgeWorkSelect.isDestinationValid(sq) then return end
        self.joypadWorldX, self.joypadWorldY = x, y
        return
    end
    if not sq:getFloor() then return end
    if self.startX == nil then
        self.joypadWorldX, self.joypadWorldY = x, y
    else
        self.endX, self.endY = x, y
    end
end

function UI:padPress()
    if self.awaitDest then
        local sq = self:joypadSquareAt(self.joypadWorldX, self.joypadWorldY)
        if not BridgeWorkSelect.isDestinationValid(sq) then
            if Bridge ~= nil then Bridge.speak("JobBadSpot") end
            return
        end
        self:startMove(sq)
        return
    end
    if self.startX == nil then
        self:anchorAt(self.joypadWorldX, self.joypadWorldY)
        self.holdA = self.dragging == true
    else
        self.holdA = false
        self:confirmSelection()
    end
end

function UI:padRelease()
    if not self.holdA then return end
    self.holdA = false
    if self.startX ~= nil and (self.endX ~= self.startX or self.endY ~= self.startY) then
        self:confirmSelection()
    end
end

function UI:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self.joypadFocus = joypadData
end

function UI:onLoseJoypadFocus(joypadData)
    if self.joypadFocus ~= nil then self.joypadFocus = nil end
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
end

function UI:onJoypadDirUp(joypadData)
    self:joypadStep(0, -1)
end

function UI:onJoypadDirDown(joypadData)
    self:joypadStep(0, 1)
end

function UI:onJoypadDirLeft(joypadData)
    self:joypadStep(-1, 0)
end

function UI:onJoypadDirRight(joypadData)
    self:joypadStep(1, 0)
end

function UI:onJoypadDown(button, joypadData)
    if button == Joypad.AButton then
        self:padPress()
        return
    end
    if button == Joypad.BButton then
        self:cancelSelection()
    end
end

function UI:onJoypadButtonReleased(button, joypadData)
    if button == Joypad.AButton then
        self:padRelease()
    end
end

function BridgeWorkSelect.treesIn(b)
    local list = {}
    if b == nil then return list end
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            local sq = getCell():getGridSquare(x, y, b.z)
            if sq ~= nil then
                local t = nil
                pcall(function() t = sq:getTree() end)
                if t ~= nil and t:getObjectIndex() >= 0 then
                    list[#list + 1] = { x = x, y = y, z = b.z }
                end
            end
        end
    end
    return list
end

function BridgeWorkSelect.plantsIn(b)
    local list = {}
    if b == nil or BridgePlants == nil then return list end
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            local sq = getCell():getGridSquare(x, y, b.z)
            if sq ~= nil then
                local have = false
                pcall(function()
                    have = BridgePlants.squareGrass(sq) or BridgePlants.squareBush(sq)
                end)
                if have then list[#list + 1] = { x = x, y = y, z = b.z } end
            end
        end
    end
    return list
end

function BridgeWorkSelect.stainsIn(b)
    local list = {}
    if b == nil then return list end
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            local sq = getCell():getGridSquare(x, y, b.z)
            if sq ~= nil then
                local have = false



                if BridgeClean ~= nil and BridgeClean.squareCleanKind ~= nil then
                    pcall(function() have = BridgeClean.squareCleanKind(sq) ~= nil end)
                elseif BridgeTask ~= nil and BridgeTask.squareCleanKind ~= nil then
                    pcall(function() have = BridgeTask.squareCleanKind(sq) ~= nil end)
                end
                if have then list[#list + 1] = { x = x, y = y, z = b.z } end
            end
        end
    end
    return list
end


local function lootAllowedContainer(c, o)
    local ok = true
    pcall(function()
        if o ~= nil and instanceof(o, "IsoThumpable") and o:isLockedToCharacter(BridgeData.owner()) then ok = false end
    end)
    if ok and BridgeInventory ~= nil then
        pcall(function() if BridgeInventory.inBody(c) or BridgeInventory.isHers(c) then ok = false end end)
    end
    return ok
end

local function addLootTarget(list, seen, x, y, z, kind, c, ref)
    if c == nil or seen[c] then return end
    seen[c] = true
    local n = 0
    pcall(function() n = c:getItems():size() end)
    if n <= 0 then return end
    list[#list + 1] = { x = x, y = y, z = z, kind = kind, cont = c, ref = ref, items = n }
end

local function lootRef(c)
    if BridgeInventory ~= nil and BridgeInventory.destRef ~= nil then return BridgeInventory.destRef(c) end
    return nil
end

function BridgeWorkSelect.lootTargets(b, cap)
    local list = {}
    if b == nil then return list end
    cap = tonumber(cap) or BridgeWorkSelect.MAX_LOOT_ITEMS
    local seen, seenVeh = {}, {}
    local red = BridgeData ~= nil and BridgeData.owner() or nil
    local wantCorpse, wantVeh = true, true
    pcall(function()
        if BridgeData ~= nil and type(BridgeData.lootOption) == "function" then
            wantCorpse = BridgeData.lootOption(Bridge.store, "lootCorpses") == true
            wantVeh = BridgeData.lootOption(Bridge.store, "lootVehicles") == true
        end
    end)
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            if #list >= cap then return list end
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(x, y, b.z) end)
            if sq ~= nil then
                pcall(function()
                    local function scan(objs)
                        if objs == nil then return end
                        for i = 0, objs:size() - 1 do
                            if #list >= cap then return end
                            local o = objs:get(i)
                            if o ~= nil then
                                local n = 0
                                pcall(function() n = o:getContainerCount() end)
                                for j = 0, n - 1 do
                                    if #list >= cap then return end
                                    local c = nil
                                    pcall(function() c = o:getContainerByIndex(j) end)
                                    if c ~= nil and lootAllowedContainer(c, o) then
                                        addLootTarget(list, seen, x, y, b.z, "obj", c, lootRef(c))
                                    end
                                end
                            end
                        end
                    end
                    scan(sq:getObjects())
                    scan(sq:getSpecialObjects())
                end)
                pcall(function()
                    if not wantCorpse then return end
                    local mv = sq:getStaticMovingObjects()
                    if mv == nil then return end
                    for i = 0, mv:size() - 1 do
                        if #list >= cap then return end
                        local so = mv:get(i)
                        if so ~= nil then
                            local c = nil
                            pcall(function() c = so:getContainer() end)
                            if c ~= nil then
                                local animal = false
                                pcall(function() animal = instanceof(so, "IsoDeadBody") and so:isAnimal() end)
                                if not animal and lootAllowedContainer(c, so) then
                                    addLootTarget(list, seen, x, y, b.z, "body", c, lootRef(c))
                                end
                            end
                        end
                    end
                end)
                pcall(function()
                    if not wantVeh then return end
                    local veh = sq:getVehicleContainer()
                    if veh == nil or seenVeh[veh] then return end
                    seenVeh[veh] = true
                    local pc = 0
                    pcall(function() pc = veh:getPartCount() end)
                    for pi = 0, pc - 1 do
                        if #list >= cap then return end
                        local part = nil
                        pcall(function() part = veh:getPartByIndex(pi) end)
                        if part ~= nil then
                            local c = nil
                            pcall(function() c = part:getItemContainer() end)
                            local id = ""
                            pcall(function() id = tostring(part:getId()) end)
                            id = string.lower(id)
                            local trunk = string.find(id, "trunk", 1, true) ~= nil
                                or string.find(id, "truckbed", 1, true) ~= nil
                            local access = true
                            pcall(function() access = red == nil or veh:canAccessContainer(pi, red) ~= false end)
                            if c ~= nil and trunk and access then
                                addLootTarget(list, seen, x, y, b.z, "veh", c, lootRef(c))
                            end
                        end
                    end
                end)
                pcall(function()
                    local wobs = sq:getWorldObjects()
                    if wobs == nil then return end
                    local have, c = false, nil
                    for i = 0, wobs:size() - 1 do
                        local wo = wobs:get(i)
                        local item = wo ~= nil and wo:getItem() or nil
                        if item ~= nil then
                            if c == nil then pcall(function() c = item:getContainer() end) end
                            have = true
                        end
                    end
                    if have and c ~= nil then
                        addLootTarget(list, seen, x, y, b.z, "floor", c, nil)
                    end
                end)
            end
        end
    end
    return list
end

function BridgeWorkSelect.lootTargetFor(c, o, kind)
    if c == nil then return nil end
    if not lootAllowedContainer(c, o) then return nil end
    local n = 0
    pcall(function() n = c:getItems():size() end)
    if n <= 0 then return nil end
    local x, y, z = 0, 0, 0
    pcall(function()
        local p = c:getParent()
        local sq = nil
        if p ~= nil then pcall(function() sq = p:getSquare() end) end
        if sq == nil then pcall(function() sq = c:getSourceGrid() end) end
        if sq ~= nil then x, y, z = sq:getX(), sq:getY(), sq:getZ() end
    end)
    return { x = x, y = y, z = z, kind = kind or "obj", cont = c, ref = lootRef(c), items = n }
end

function BridgeWorkSelect.outerWorldContainer(c)
    if c == nil then return nil end
    local outer = nil
    pcall(function() outer = c:getOutermostContainer() end)
    return outer or c
end

function BridgeWorkSelect.lootTargetForContainer(c, only)
    if c == nil then return nil end
    if not lootAllowedContainer(c, nil) then return nil end
    local outer = BridgeWorkSelect.outerWorldContainer(c)
    local ref = nil
    pcall(function() ref = lootRef(outer) end)
    if ref == nil then pcall(function() ref = lootRef(c) end) end
    local x, y, z, kind = nil, nil, nil, "obj"
    if type(ref) == "table" then
        kind = ref.kind or "obj"
        x, y, z = ref.x, ref.y, ref.z
    end
    if x == nil then
        pcall(function()
            local p = c:getParent()
            local sq = nil
            if p ~= nil then pcall(function() sq = p:getSquare() end) end
            if sq == nil then pcall(function() sq = c:getSourceGrid() end) end
            if sq == nil and outer ~= c then
                local po = outer:getParent()
                if po ~= nil then pcall(function() sq = po:getSquare() end) end
            end
            if sq ~= nil then x, y, z = sq:getX(), sq:getY(), sq:getZ() end
        end)
    end
    if x == nil then return nil end
    if type(only) == "table" and #only > 0 then
        return { x = x, y = y, z = z, kind = kind, cont = c, ref = ref, items = #only, only = only }
    end
    local n = 0
    pcall(function() n = c:getItems():size() end)
    if n <= 0 then return nil end
    return { x = x, y = y, z = z, kind = kind, cont = c, ref = ref, items = n }
end

function BridgeWorkSelect.lootTargetsForObject(o)
    local list = {}
    if o == nil then return list end
    local dead = false
    pcall(function() dead = instanceof(o, "IsoDeadBody") end)
    if dead then
        local c = nil
        pcall(function() c = o:getContainer() end)
        local t = BridgeWorkSelect.lootTargetFor(c, o, "body")
        if t ~= nil then list[#list + 1] = t end
        return list
    end
    local veh = false
    pcall(function() veh = instanceof(o, "BaseVehicle") end)
    if veh then
        local pc = 0
        pcall(function() pc = o:getPartCount() end)
        for pi = 0, pc - 1 do
            local part = nil
            pcall(function() part = o:getPartByIndex(pi) end)
            if part ~= nil then
                local id = ""
                pcall(function() id = tostring(part:getId()) end)
                id = string.lower(id)
                if string.find(id, "trunk", 1, true) ~= nil or string.find(id, "truckbed", 1, true) ~= nil then
                    local c = nil
                    pcall(function() c = part:getItemContainer() end)
                    local t = BridgeWorkSelect.lootTargetFor(c, nil, "veh")
                    if t ~= nil then list[#list + 1] = t end
                end
            end
        end
        return list
    end
    local n = 0
    pcall(function() n = o:getContainerCount() end)
    for j = 0, n - 1 do
        local c = nil
        pcall(function() c = o:getContainerByIndex(j) end)
        local t = BridgeWorkSelect.lootTargetFor(c, o, "obj")
        if t ~= nil then list[#list + 1] = t end
    end
    return list
end

function BridgeWorkSelect.corpsesIn(b)
    local list = {}
    if b == nil then return list end
    local seen = {}
    for x = b.x1, b.x2 do
        for y = b.y1, b.y2 do
            local sq = nil
            pcall(function() sq = getCell():getGridSquare(x, y, b.z) end)
            if sq ~= nil then
                pcall(function()
                    local burn = false
                    pcall(function() burn = sq:has(IsoFlagType.burning) == true end)
                    if burn then return end
                    local mv = sq:getStaticMovingObjects()
                    local n = (mv and mv:size() or 0)
                    for i = 0, n - 1 do
                        local c = mv:get(i)
                        if c ~= nil and instanceof(c, "IsoDeadBody") and not c:isAnimal() then
                            local id = nil
                            pcall(function() id = c:getObjectIDAsLong() end)
                            if type(id) ~= "number" or id == 0 then
                                id = nil
                                pcall(function()
                                    local v = c:getObjectID()
                                    if type(v) == "number" and v ~= 0 then id = v end
                                end)
                            end
                            if id == nil then id = x .. ":" .. y .. ":" .. i end
                            local key = tostring(id)
                            if not seen[key] then
                                seen[key] = true
                                list[#list + 1] = { x = x, y = y, z = b.z }
                            end
                        end
                    end
                end)
            end
        end
    end
    return list
end

local function doorPartObjects(door)
    local parts = { door }
    pcall(function()
        if IsoDoor == nil then return end
        if IsoDoor.getDoubleDoorIndex ~= nil and IsoDoor.getDoubleDoorIndex(door) ~= -1
                and IsoDoor.getDoubleDoorObject ~= nil then
            for i = 1, 4 do
                local p = IsoDoor.getDoubleDoorObject(door, i)
                if p ~= nil and p ~= door then parts[#parts + 1] = p end
            end
        end
        if IsoDoor.getGarageDoorIndex ~= nil and IsoDoor.getGarageDoorIndex(door) ~= -1 then
            local p = IsoDoor.getGarageDoorPrev ~= nil and IsoDoor.getGarageDoorPrev(door) or nil
            while p ~= nil and #parts < 12 do parts[#parts + 1] = p; p = IsoDoor.getGarageDoorPrev(p) end
            p = IsoDoor.getGarageDoorNext ~= nil and IsoDoor.getGarageDoorNext(door) or nil
            while p ~= nil and #parts < 24 do parts[#parts + 1] = p; p = IsoDoor.getGarageDoorNext(p) end
        end
    end)
    return parts
end

function BridgeWorkSelect.doorsIn(b, mode)
    local list = {}
    if b == nil then return list end
    local inside = function(x, y)
        return x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2
    end
    local seen = {}
    local function add(door, sq)
        if door == nil or seen[door] then return end
        local parts = doorPartObjects(door)
        local dsq, osq = nil, nil
        pcall(function() dsq = door:getSquare() end)
        pcall(function() osq = door:getOppositeSquare() end)
        local inBox = false
        if dsq ~= nil then
            pcall(function() inBox = inside(dsq:getX(), dsq:getY()) end)
        end
        if not inBox and osq ~= nil then
            pcall(function() inBox = inside(osq:getX(), osq:getY()) end)
        end
        if not inBox then return end
        local open = false
        pcall(function() open = door:IsOpen() == true end)
        if mode == "open" and open then return end
        if mode ~= "open" and not open then return end
        if #list >= BridgeWorkSelect.MAX_DOORS then return end
        local anchor = dsq or sq
        if anchor == nil then return end
        for i = 1, #parts do seen[parts[i]] = true end
        local north = false
        pcall(function() north = door:getNorth() == true end)
        list[#list + 1] = { x = anchor:getX(), y = anchor:getY(), z = anchor:getZ(), north = north }
    end
    local cell = getCell()
    for x = b.x1 - 1, b.x2 + 1 do
        for y = b.y1 - 1, b.y2 + 1 do
            local sq = nil
            pcall(function() sq = cell:getGridSquare(x, y, b.z) end)
            if sq ~= nil then
                pcall(function()
                    local objs = sq:getObjects()
                    if objs ~= nil then
                        for i = 0, objs:size() - 1 do
                            local o = objs:get(i)
                            if o ~= nil and BridgeDoors ~= nil and BridgeDoors.isDoor(o) then add(o, sq) end
                        end
                    end
                end)
                pcall(function()
                    local objs = sq:getSpecialObjects()
                    if objs ~= nil then
                        for i = 0, objs:size() - 1 do
                            local o = objs:get(i)
                            if o ~= nil and BridgeDoors ~= nil and BridgeDoors.isDoor(o) then add(o, sq) end
                        end
                    end
                end)
                pcall(function()
                    local objs = sq:getWorldObjects()
                    if objs ~= nil then
                        for i = 0, objs:size() - 1 do
                            local o = objs:get(i)
                            if o ~= nil and BridgeDoors ~= nil and BridgeDoors.isDoor(o) then add(o, sq) end
                        end
                    end
                end)
            end
        end
    end
    return list
end

function BridgeWorkSelect.isDestinationValid(sq)
    if sq == nil then return false end
    local floor = nil
    pcall(function() floor = sq:getFloor() end)
    if floor == nil then return false end
    local burn = false
    pcall(function() burn = sq:has(IsoFlagType.burning) == true end)
    if burn then return false end
    return true
end

BridgeWorkSelect.kinds = {
    chopTree = {
        collect = function(b) return BridgeWorkSelect.treesIn(b) end,
        max = BridgeWorkSelect.MAX_TREES,
        noneSay = "JobNoTree",
    },
    cleanUp = {
        collect = function(b) return BridgeWorkSelect.stainsIn(b) end,
        max = BridgeWorkSelect.MAX_STAINS,
        noneSay = "JobNoStains",
    },
    clearPlants = {
        collect = function(b) return BridgeWorkSelect.plantsIn(b) end,
        max = BridgeWorkSelect.MAX_PLANTS,
        noneSay = "JobNoPlants",
    },
    lootArea = {
        collect = function(b) return BridgeWorkSelect.lootTargets(b) end,
        max = BridgeWorkSelect.MAX_LOOT_ITEMS,
        maxSide = 8,
        min = 1,
        noneSay = "JobNoLoot",
    },
    moveCorpses = {
        collect = function(b) return BridgeWorkSelect.corpsesIn(b) end,
        max = BridgeWorkSelect.MAX_CORPSES,
        maxSide = 10,
        destination = true,
        noneSay = "JobNoCorpses",
    },
    depositArea = {
        collect = function(b)
            if BridgeDeposit == nil or type(BridgeDeposit.targetsIn) ~= "function" then return {} end
            return BridgeDeposit.targetsIn(b, BridgeWorkSelect.MAX_LOOT_ITEMS)
        end,
        start = function(targets)
            if BridgeDeposit == nil or type(BridgeDeposit.start) ~= "function" then return "unavailable" end
            return BridgeDeposit.start(targets)
        end,
        max = BridgeWorkSelect.MAX_LOOT_ITEMS,
        maxSide = 8,
        min = 1,
        noneSay = "JobNoStorage",
    },
    openDoors = {
        collect = function(b) return BridgeWorkSelect.doorsIn(b, "open") end,
        max = BridgeWorkSelect.MAX_DOORS,
        maxSide = 10,
        min = 1,
        noneSay = "JobNoDoorsOpen",
    },
    closeDoors = {
        collect = function(b) return BridgeWorkSelect.doorsIn(b, "close") end,
        max = BridgeWorkSelect.MAX_DOORS,
        maxSide = 10,
        min = 1,
        noneSay = "JobNoDoorsClose",
    },
}

function BridgeWorkSelect.sortTargets(targets)
    local ox, oy = 0, 0
    local bodyKey = nil
    pcall(function()
        local b = Bridge ~= nil and Bridge.body or nil
        if b ~= nil then
            ox, oy = b:getX(), b:getY()
            if BridgeDoors ~= nil and BridgeDoors.enclosureKey ~= nil then
                bodyKey = BridgeDoors.enclosureKey(b:getCurrentSquare())
            end
        else
            local red = BridgeData.owner()
            if red ~= nil then ox, oy = red:getX(), red:getY() end
            if BridgeDoors ~= nil and BridgeDoors.enclosureKey ~= nil and red ~= nil then
                bodyKey = BridgeDoors.enclosureKey(red:getCurrentSquare())
            end
        end
    end)
    local keys = nil
    if bodyKey ~= nil then
        keys = {}
        local cell = getCell()
        for _, t in ipairs(targets) do
            local k = nil
            pcall(function() k = BridgeDoors.enclosureKey(cell:getGridSquare(t.x, t.y, t.z)) end)
            keys[t] = k
        end
    end
    table.sort(targets, function(a, c)
        if keys ~= nil then
            local sa = keys[a] == bodyKey
            local sc = keys[c] == bodyKey
            if sa ~= sc then return sa end
        end
        return (a.x - ox) ^ 2 + (a.y - oy) ^ 2 < (c.x - ox) ^ 2 + (c.y - oy) ^ 2
    end)
end

function BridgeWorkSelect.begin(playerObj, kind)
    if playerObj == nil then return nil end
    kind = kind or "chopTree"
    if BridgeTask == nil or BridgeTask.ENABLED ~= 1 then return nil end
    if kind == "chopTree" and BridgeTask.TREECUTTING_ENABLED ~= 1 then return nil end
    if kind == "cleanUp" and BridgeTask.CLEANING_ENABLED ~= 1 then return nil end
    if kind == "clearPlants" and BridgeTask.CLEARING_ENABLED ~= 1 then return nil end
    if kind == "lootArea" and BridgeTask.LOOTING_ENABLED ~= 1 then return nil end
    if kind == "depositArea" and (BridgeTask.DEPOSIT_ENABLED ~= 1 or BridgeDeposit == nil) then return nil end
    if kind == "moveCorpses" and BridgeTask.MOVE_CORPSES_ENABLED ~= 1 then return nil end
    if (kind == "openDoors" or kind == "closeDoors") and BridgeTask.DOORS_ENABLED ~= 1 then return nil end
    if BridgeWorkSelect.active ~= nil then BridgeWorkSelect.active:close() end
    local ui = UI:new(playerObj, kind)
    BridgeWorkSelect.active = ui
    acquireLock()
    ui:initialise()
    ui:addToUIManager()
    local joypad = getJoypadData(ui.playerNum)
    local mouseRecent = true
    pcall(function() mouseRecent = wasMouseActiveMoreRecentlyThanJoypad() == true end)
    if joypad ~= nil and not mouseRecent then
        ui.controller = true
        setJoypadFocus(ui.playerNum, ui)
        ui.joypadFocus = joypad
        updateJoypadFocus(joypad)
    end
    log("selection begun")
    return ui
end

Events.OnKeyStartPressed.Add(function(key)
    if BridgeWorkSelect.lockCount == 0 then return end
    local esc = key == Keyboard.KEY_ESCAPE
    pcall(function() if getCore():isKey("Main Menu", key) then esc = true end end)
    if not esc then return end
    if BridgeWorkSelect.active ~= nil then BridgeWorkSelect.active:close() end
    GameKeyboard.eatKeyPress(key)
end)

Events.OnTick.Add(function()
    local ui = BridgeWorkSelect.active
    if ui == nil then return end
    local sq = nil
    pcall(function() sq = ui.playerObj ~= nil and ui.playerObj:getCurrentSquare() or nil end)
    local inCar = BridgeCar ~= nil and BridgeCar.isInside()
    if sq == nil or sq:getZ() ~= ui.level or (not Bridge.alive() and not inCar) then
        ui:close()
    end
end)

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeWorkSelect] loaded") end
