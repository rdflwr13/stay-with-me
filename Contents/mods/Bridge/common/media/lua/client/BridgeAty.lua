
BridgeAty = BridgeAty or {}

local marked = nil
local on = nil

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeAty] " .. tostring(text)) end
end

local function atyOn()
    if on ~= nil then return on end
    if BridgeGun == nil then return false end
    on = false
    pcall(function()
        on = BridgeGun.atActive() == true and rawget(_G, "Advanced_trajectory") ~= nil
    end)
    if on then log("Advanced Trajectory found: companion target highlight on") end
    return on
end

local function playerHas(z)
    local g = rawget(_G, "Advanced_trajectory")
    if type(g) ~= "table" or type(g.zombierank) ~= "table" then return false end
    local list = g.zombierank
    for i = 1, #list do
        local v = list[i]
        if type(v) == "table" and v[1] == z then return true end
    end
    return false
end

local function tick()
    local want = nil
    if atyOn() and Bridge ~= nil and Bridge.body ~= nil and BridgeGunfight ~= nil
        and BridgeFight ~= nil and BridgeFight.state == "gun"
        and BridgeGunfight.drawn == true and BridgeGunfight.target ~= nil
        and (BridgeGunfight.state == "aim" or BridgeGunfight.state == "backstep") then
        want = BridgeGunfight.target
        local alive = false
        pcall(function() alive = want:isAlive() == true end)
        if not alive or playerHas(want) then want = nil end
    end

    if marked ~= nil and marked ~= want then
        if not playerHas(marked) then
            pcall(function() marked:setOutlineHighlight(false) end)
        end
        marked = nil
    end
    if want == nil then return end

    marked = want
    local level = (BridgeSkills ~= nil and BridgeSkills.level("Aiming")) or 0
    local total = BridgeGunRules.aimTicks(BridgeGunfight.gun, level)
    local remain = math.max(0, (BridgeGunfight.aimUntil or 0) - (Bridge.time or 0))
    local acc = 1 - remain / math.max(1, total)
    if acc < 0 then acc = 0 elseif acc > 1 then acc = 1 end
    pcall(function()
        want:setOutlineHighlight(true)
        want:setOutlineHighlightCol(1 - acc, acc, 0, 0.8)
    end)
end

Events.OnTick.Add(function() pcall(tick) end)
Events.OnGameStart.Add(function() marked = nil on = nil end)
log("loaded")
