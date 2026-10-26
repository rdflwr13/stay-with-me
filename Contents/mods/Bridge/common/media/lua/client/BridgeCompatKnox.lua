BridgeCompatKnox = BridgeCompatKnox or {}

local KEE_MOD_ID = "KnoxEventExpandedNpc"
local CHECK_RANGE = 5
local CHECK_EVERY = 30
local RETRY_EVERY = 60

local retryTick = 0

local function keeActive()
    if BridgeCompatKnox.kee ~= nil then return BridgeCompatKnox.kee end
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(KEE_MOD_ID) or mods:contains("\\" .. KEE_MOD_ID))
    end)
    BridgeCompatKnox.kee = on
    return on
end


function BridgeCompatKnox.isOurBody(z)
    if z == nil then return false end
    if Bridge ~= nil and type(Bridge.isCompanion) == "function" then
        local ok, yes = pcall(Bridge.isCompanion, z)
        if ok and yes then return true end
    end
    if Bridge ~= nil and Bridge.body == z then return true end
    local ok, yes = pcall(function() return z:getVariableBoolean("NotAloneBody") == true end)
    return ok and yes == true
end


local function hasRealZombieNear(x, y, z, range)
    local cell = getCell()
    if not cell then return false end
    local xi = math.floor(x)
    local yi = math.floor(y)
    local zi = math.floor(z)
    for ix = xi - range, xi + range do
        for iy = yi - range, yi + range do
            local sq = cell:getGridSquare(ix, iy, zi)
            if sq then
                local objs = sq:getMovingObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if instanceof(obj, "IsoZombie") and not obj:isDead() and not BridgeCompatKnox.isOurBody(obj) then
                        return true
                    end
                end
            end
        end
    end
    return false
end


function BridgeCompatKnox.update(self)
    if not self:isVisible() or not self.metaNpc then return end

    self.zombieCheckTick = (self.zombieCheckTick or 0) + 1
    if self.zombieCheckTick < CHECK_EVERY then return end
    self.zombieCheckTick = 0

    local player = getSpecificPlayer(self.playerNum) or getPlayer()
    if not player or player:isDead() then return end

    if hasRealZombieNear(player:getX(), player:getY(), player:getZ(), CHECK_RANGE) then
        self:sayGoodbye(player)
        return
    end

    local npcObj = self.metaNpc:getWorldObject()
    if npcObj and hasRealZombieNear(npcObj:getX(), npcObj:getY(), npcObj:getZ(), CHECK_RANGE) then
        self:sayGoodbye(player)
    end
end


function BridgeCompatKnox.installDialogueGuard()
    if not keeActive() then return end
    local cls = rawget(_G, "NpcDialogueUI")
    if type(cls) ~= "table" or type(cls.update) ~= "function" then return end
    if cls.update == BridgeCompatKnox.update then return end
    if BridgeCompatKnox.originalUpdate == nil then
        BridgeCompatKnox.originalUpdate = cls.update
    end
    cls.update = BridgeCompatKnox.update
    if not BridgeCompatKnox.logged then
        BridgeCompatKnox.logged = true
        print("[BridgeCompatKnox] KEE dialogue guard installed")
    end
end


function BridgeCompatKnox.uninstall()
    local cls = rawget(_G, "NpcDialogueUI")
    if type(cls) == "table" and type(BridgeCompatKnox.originalUpdate) == "function" then
        cls.update = BridgeCompatKnox.originalUpdate
    end
    BridgeCompatKnox.originalUpdate = nil
    BridgeCompatKnox.logged = nil
end


Events.OnGameStart.Add(function() pcall(BridgeCompatKnox.installDialogueGuard) end)

Events.OnTick.Add(function()
    retryTick = retryTick + 1
    if retryTick < RETRY_EVERY then return end
    retryTick = 0
    pcall(BridgeCompatKnox.installDialogueGuard)
end)
