BridgePz3dAlarm = BridgePz3dAlarm or {}

local BODY_VAR = "NotAloneBody"
local wrapped = {}
local depth = 0
local realGetCell = nil

local function log(text)
    print("[BridgePz3dAlarm] " .. tostring(text))
end

local function warnOnce(text)
    if BridgePz3dAlarm.warned then return end
    BridgePz3dAlarm.warned = true
    log(text)
end

local function isHer(z)
    if z == nil then return false end
    if Bridge ~= nil and Bridge.body == z then return true end
    local marked = false
    pcall(function()
        if z.getVariableBoolean ~= nil then marked = z:getVariableBoolean(BODY_VAR) == true end
    end)
    if marked then return true end
    local md = nil
    pcall(function()
        if z.hasModData ~= nil and z:hasModData() then md = z:getModData() end
    end)
    return md ~= nil and md.notAloneBody == true
end

local function listWithoutHer(list)
    local keep, n = {}, 0
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if not isHer(z) then
            n = n + 1
            keep[n] = z
        end
    end
    return {
        size = function() return n end,
        get = function(_, i) return keep[i + 1] end,
    }
end

local function cellWithoutHer(cell)
    local proxy = {}
    proxy.getZombieList = function()
        local list = cell:getZombieList()
        if list == nil then return nil end
        return listWithoutHer(list)
    end
    proxy.getGridSquare = function(_, x, y, z)
        return cell:getGridSquare(x, y, z)
    end
    return proxy
end

local function withHerHidden(fn, ...)
    depth = depth + 1
    local ok, a, b, c = pcall(fn, ...)
    depth = depth - 1
    if not ok then warnOnce("wrapped call failed: " .. tostring(a)) end
    return a, b, c
end

local function wrap(tbl, key, isMethod)
    if type(tbl) ~= "table" then return false end
    local fn = tbl[key]
    if type(fn) ~= "function" then return false end
    if wrapped[tbl] == nil then wrapped[tbl] = {} end
    if wrapped[tbl][key] then return true end
    wrapped[tbl][key] = true
    if isMethod then
        tbl[key] = function(self, ...) return withHerHidden(fn, self, ...) end
    else
        tbl[key] = function(...) return withHerHidden(fn, ...) end
    end
    return true
end

function BridgePz3dAlarm.install()
    if BridgePz3dAlarm.installed then return BridgePz3dAlarm.installed end
    local n = 0
    if wrap(aparosa_pz3dAlarm, "alarmUpdate") then n = n + 1 end
    if wrap(aparosa_pz3dMinimap, "alarmUpdate") then n = n + 1 end
    if aparosa_pz3dMinimap ~= nil and wrap(aparosa_pz3dMinimap.Panel, "drawZombies", true) then
        n = n + 1
    end
    if n == 0 then return 0 end
    realGetCell = getCell
    getCell = function()
        local cell = realGetCell()
        if depth <= 0 or cell == nil then return cell end
        return cellWithoutHer(cell)
    end
    BridgePz3dAlarm.installed = n
    if BridgeLog ~= nil and BridgeLog.on() then log("installed on " .. n .. " hook(s)") end
    return n
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(function() pcall(BridgePz3dAlarm.install) end)
end
