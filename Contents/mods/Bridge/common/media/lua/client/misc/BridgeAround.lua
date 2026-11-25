-- Bridge commands "look" and "take": what lies around the player, and taking it.
-- look [radius]        lists containers, corpses, trunks and floor piles around the player.
-- take <n> [Type]      Rin collects container n from the last look, or only items of that type.
-- Taking runs the same "lootArea" job as the "Loot this" menu, so items move through the game's own actions.

BridgeAround = BridgeAround or {}
BridgeAround.last = {}
BridgeAround.MAX_RADIUS = 15
BridgeAround.MAX_TARGETS = 40

local function countItems(c)
    local counts, order = {}, {}
    pcall(function()
        local items = c:getItems()
        for j = 0, items:size() - 1 do
            local it = items:get(j)
            if it ~= nil then
                local ft = tostring(it:getFullType())
                if counts[ft] == nil then
                    counts[ft] = 0
                    order[#order + 1] = ft
                end
                counts[ft] = counts[ft] + 1
            end
        end
    end)
    local parts = {}
    for _, ft in ipairs(order) do parts[#parts + 1] = ft .. "=" .. counts[ft] end
    return table.concat(parts, " ")
end

function BridgeAround.look(radius)
    if BridgeWorkSelect == nil or type(BridgeWorkSelect.lootTargets) ~= "function" then return "look: not loaded" end
    local red = BridgeData ~= nil and BridgeData.owner() or nil
    if red == nil then return "look: no player" end
    local r = math.max(1, math.min(BridgeAround.MAX_RADIUS, math.floor(tonumber(radius) or 8)))
    local px, py, pz = math.floor(red:getX()), math.floor(red:getY()), math.floor(red:getZ())
    local list = BridgeWorkSelect.lootTargets({ x1 = px - r, y1 = py - r, x2 = px + r, y2 = py + r, z = pz }, BridgeAround.MAX_TARGETS)
    BridgeAround.last = list
    if #list == 0 then return "look r" .. r .. ": nothing" end
    local out = {}
    for i, t in ipairs(list) do
        local ctype = ""
        pcall(function() ctype = tostring(t.cont:getType()) end)
        local d = math.floor(math.sqrt((t.x - px) * (t.x - px) + (t.y - py) * (t.y - py)) + 0.5)
        out[#out + 1] = string.format("#%d %s %s %d,%d d%d: %s", i, tostring(t.kind), ctype, t.x, t.y, d, countItems(t.cont))
    end
    return "look r" .. r .. " " .. #list .. ": " .. table.concat(out, " | ")
end

function BridgeAround.take(index, wanted)
    if BridgeTask == nil or type(BridgeTask.start) ~= "function" then return "take: not loaded" end
    local i = tonumber(index)
    local t = i and BridgeAround.last[i] or nil
    if t == nil then return "take: run look first" end
    local present = false
    pcall(function() present = t.cont ~= nil and t.cont:getItems():size() > 0 end)
    if not present then return "take #" .. tostring(i) .. ": empty now" end
    local target = { x = t.x, y = t.y, z = t.z, kind = t.kind, cont = t.cont, ref = t.ref, items = t.items }
    if wanted ~= nil and wanted ~= "" then
        local only = {}
        pcall(function()
            local items = t.cont:getItems()
            for j = 0, items:size() - 1 do
                local it = items:get(j)
                if it ~= nil and (it:getFullType() == wanted or it:getType() == wanted) then only[#only + 1] = it end
            end
        end)
        if #only == 0 then return "take #" .. i .. ": no " .. wanted end
        target.only = only
        target.items = #only
    end
    local res = BridgeTask.start("lootArea", { target })
    return "take #" .. i .. (wanted and (" " .. wanted) or "") .. ": " .. tostring(res)
end

function BridgeAround.run(cmd, parts)
    local ok, res = pcall(function()
        if cmd == "look" then return BridgeAround.look(parts[3]) end
        return BridgeAround.take(parts[3], parts[4])
    end)
    if ok then return res end
    return cmd .. " failed: " .. tostring(res)
end
