BridgeVoidRingCompat = BridgeVoidRingCompat or {}

local M = BridgeVoidRingCompat

local MOD_ID = "TFC_VoidRingMod"
local RING_CAPACITY = 50000
local CHECK_INTERVAL = 0.25

local RING_TYPES = {
    ["TFC_VoidRing.TFC_VoidRing"] = true,
    ["TFC_VoidRing.TFC_VoidRing_LeftMiddle"] = true,
    ["TFC_VoidRing.TFC_VoidRing_RightRing"] = true,
    ["TFC_VoidRing.TFC_VoidRing_LeftRing"] = true,
}

local activeCache = false
local loggedState = nil

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeVoidRing] " .. tostring(text)) end
end

function M.modActive()
    if activeCache then return true end
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(MOD_ID) or mods:contains("\\" .. MOD_ID))
    end)
    if on then activeCache = true end
    return on
end

function M.isRing(item)
    if item == nil then return false end
    local full = nil
    pcall(function() full = item:getFullType() end)
    return full ~= nil and RING_TYPES[full] == true
end

function M.wearsRing(body)
    if body == nil then return false end
    local worn = nil
    pcall(function() worn = body:getWornItems() end)
    if worn == nil then return false end
    local found = false
    pcall(function()
        local n = worn:size()
        for i = 0, n - 1 do
            local item = nil
            if type(worn.getItemByIndex) == "function" then
                pcall(function() item = worn:getItemByIndex(i) end)
            end
            if item == nil and type(worn.get) == "function" then
                local entry = nil
                pcall(function() entry = worn:get(i) end)
                if entry ~= nil and type(entry.getItem) == "function" then
                    pcall(function() item = entry:getItem() end)
                end
            end
            if item ~= nil and M.isRing(item) then
                found = true
                return
            end
        end
    end)
    return found
end

function M.ensureCapacity(body)
    if body == nil then return false end
    local changed = false
    local inv = nil
    pcall(function() inv = body:getInventory() end)
    if inv ~= nil then
        local cap = nil
        pcall(function() cap = inv:getCapacity() end)
        if type(cap) ~= "number" or cap < RING_CAPACITY then
            pcall(function() inv:setCapacity(RING_CAPACITY) end)
            changed = true
        end
    end
    local maxw = nil
    pcall(function() maxw = body:getMaxWeight() end)
    if type(maxw) ~= "number" or maxw < RING_CAPACITY then
        pcall(function() body:setMaxWeight(RING_CAPACITY) end)
        changed = true
    end
    return changed
end

function M.restoreCapacity(body)
    if body == nil then return false end
    if BridgeSkills ~= nil and type(BridgeSkills.applyCarry) == "function" then
        local ok = pcall(BridgeSkills.applyCarry, body)
        if ok then return true end
    end
    local level = 0
    if BridgeSkills ~= nil and type(BridgeSkills.level) == "function" then
        pcall(function() level = BridgeSkills.level("Strength") or 0 end)
    end
    local cap = nil
    if BridgeData ~= nil and type(BridgeData.carryForStrengthLevel) == "function" then
        pcall(function() cap = BridgeData.carryForStrengthLevel(level) end)
    end
    if cap == nil then return false end
    local ok = false
    pcall(function()
        body:getInventory():setCapacity(cap)
        body:setMaxWeight(cap)
        ok = true
    end)
    return ok
end

local function drop()
    if M.applied and M.body ~= nil then M.restoreCapacity(M.body) end
    M.body, M.applied = nil, false
end

function M.step()
    if not M.modActive() then return false end
    if Bridge == nil then
        drop()
        return false
    end
    local alive = false
    if type(Bridge.alive) == "function" then pcall(function() alive = Bridge.alive() == true end) end
    if not alive or Bridge.kind ~= "zombie" or Bridge.mp == true or Bridge.body == nil then
        drop()
        return false
    end
    local body = Bridge.body
    if M.body ~= body then
        if M.applied and M.body ~= nil then M.restoreCapacity(M.body) end
        M.body, M.applied = body, false
    end
    if M.wearsRing(body) then
        local was = M.applied
        M.ensureCapacity(body)
        M.applied = true
        if not was and loggedState ~= "on" then
            loggedState = "on"
            log("worn Void Ring: capacity set to 50000")
        end
    elseif M.applied then
        M.applied = false
        M.restoreCapacity(body)
        if loggedState ~= "off" then
            loggedState = "off"
            log("worn Void Ring removed: capacity restored")
        end
    end
    return true
end

function M.tick()
    local now = 0
    if Bridge ~= nil and type(Bridge.time) == "number" then now = Bridge.time end
    if (now - (M.lastCheck or -1e9)) < CHECK_INTERVAL * 60 then return end
    M.lastCheck = now
    pcall(M.step)
end

function M.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local function item(full)
        local i = {}
        function i:getFullType() return full end
        return i
    end

    local ring = item("TFC_VoidRing.TFC_VoidRing")
    local base = item("Base.WaterBottle")
    local otherRing = item("SomeOtherMod.SomeRing")

    check("ring type accepted", M.isRing(ring) == true)
    check("base item rejected", M.isRing(base) == false)
    check("other ring rejected", M.isRing(otherRing) == false)
    check("nil item rejected", M.isRing(nil) == false)

    local wornWith = { size = function() return 1 end,
        getItemByIndex = function(_, i) return ring end }
    local wornWithout = { size = function() return 1 end,
        getItemByIndex = function(_, i) return base end }
    check("worn ring detected", M.wearsRing({ getWornItems = function() return wornWith end }) == true)
    check("no ring detected", M.wearsRing({ getWornItems = function() return wornWithout end }) == false)
    check("nil body rejected", M.wearsRing(nil) == false)

    if #fails == 0 then return string.format("voidringselftest PASS (%d checks)", checks) end
    return string.format("voidringselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end

if type(Events) == "table" and Events.OnPlayerUpdate ~= nil then
    Events.OnPlayerUpdate.Add(function() M.tick() end)
end
