BridgeAnimalsNoFear = BridgeAnimalsNoFear or {}

function BridgeAnimalsNoFear.apply()
    local defs = AnimalDefinitions and AnimalDefinitions.animals
    if type(defs) ~= "table" then return 0, 0 end
    local n, wild = 0, 0
    for _, d in pairs(defs) do
        if type(d) == "table" then
            if d.wild == true then
                wild = wild + 1
            elseif d.fleeZombies ~= false then
                d.fleeZombies = false
                n = n + 1
            end
        end
    end
    return n, wild
end

local function applyPass()
    pcall(BridgeAnimalsNoFear.apply)
end

applyPass()

Events.OnGameBoot.Add(applyPass)

Events.OnGameStart.Add(function()
    if BridgeLog == nil or BridgeLog.on == nil or not BridgeLog.on() then return end
    local defs = AnimalDefinitions and AnimalDefinitions.animals
    local n, wild = 0, 0
    if type(defs) == "table" then
        for _, d in pairs(defs) do
            if type(d) == "table" then
                if d.wild == true then
                    wild = wild + 1
                elseif d.fleeZombies == false then
                    n = n + 1
                end
            end
        end
    end
    print("[BridgeAnimalsNoFear] fleeZombies=false species=" .. tostring(n)
        .. " wild skipped=" .. tostring(wild))
end)
