BridgeHorseSlowdown = BridgeHorseSlowdown or {}
local installed = false

local SLOWDOWN_MAX = 2.5
local SLOWDOWN_ZOMBIE_KNOCKDOWN_INCREASE = 0.75
local SLOWDOWN_ZOMBIE_NEARBY_INCREASE = 4
local SLOWDOWN_ZOMBIE_GROUND_INCREASE = 2
local KNOCKDOWN_MIN_SPEED = 6.5

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeHorse] " .. tostring(text)) end
end

local function isPassenger(zombie)
    return BridgeHorse ~= nil and type(BridgeHorse.isPassenger) == "function"
        and BridgeHorse.isPassenger(zombie) == true
end

local function directionToDegrees(direction)
    return Vector2.getDirection(direction:dx(), direction:dy()) * (180 / math.pi)
end

function BridgeHorseSlowdown.install()
    if installed then return true end
    if BridgeHorse ~= nil and BridgeHorse.softDisabled then return false end
    local ok, RidingMovement = pcall(require, "HorseMod/riding/RidingMovement")
    if not ok or type(RidingMovement) ~= "table" or type(RidingMovement.updateSlowdown) ~= "function" then
        if not BridgeHorseSlowdown.warned then
            BridgeHorseSlowdown.warned = true
            log("RidingMovement.updateSlowdown missing, passenger slowdown wrapper inactive")
        end
        return false
    end
    if RidingMovement.bridgeSlowdownWrapped then
        installed = true
        return true
    end
    RidingMovement.updateSlowdown = function(self, deltaTime)
        self.slowdownCounter = math.max(self.slowdownCounter - deltaTime, 0)
        local square = self.pair.mount:getSquare()
        if not square then return end
        local movingObjects = square:getLuaMovingObjectList()
        for i = 1, #movingObjects do
            local zombie = movingObjects[i]
            if instanceof(zombie, "IsoZombie") and not isPassenger(zombie) then
                if zombie:isKnockedDown() or zombie:isCrawling() then
                    self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_GROUND_INCREASE * deltaTime
                else
                    if self.speed >= KNOCKDOWN_MIN_SPEED then
                        self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_KNOCKDOWN_INCREASE
                        if self.effects.authoritative then
                            local facingSameDir = math.abs(zombie:getDirectionAngle() - directionToDegrees(self.direction)) <= 180
                            zombie:knockDown(facingSameDir)
                        end
                    else
                        self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_NEARBY_INCREASE * deltaTime
                    end
                end
            end
        end
        self.slowdownCounter = math.min(self.slowdownCounter, SLOWDOWN_MAX)
    end
    RidingMovement.bridgeSlowdownWrapped = true
    installed = true
    log("horse slowdown wrapper installed")
    return true
end

pcall(BridgeHorseSlowdown.install)
