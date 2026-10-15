
-- BridgeFetch
-- Home auto-fetch: instantly moves a needed item from a container inside the
-- home zone straight into her inventory. No walking, no pathing, no looting
-- animation, no gesture. One item per need.
--
-- Triggered on demand only:
--   * job start that needs a missing tool/resource (chopTree, clearPlants, cleanUp)
--   * auto-heal bandage / disinfectant
--   * auto-torch battery
--
-- Guarded by the "homeResources" option (Home tab), a set home, and her being
-- in or near the home zone. Anything unsatisfied falls back to today's behavior.

BridgeFetch = BridgeFetch or {}

local MARGIN = 6            -- tiles outside the home rect still count as "near home"
local PENDING_TIMEOUT = 240 -- frames a deferred job waits for an MP transfer before giving up

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeFetch] " .. tostring(text)) end end

local function itemType(it)
    local t = nil
    pcall(function() t = it:getType() end)
    return type(t) == "string" and t or nil
end

local function isBroken(it)
    local b = true
    pcall(function() b = it:isBroken() == true end)
    return b
end

local function hasTag(it, tag)
    local ok = false
    pcall(function() ok = it ~= nil and tag ~= nil and it:hasTag(tag) == true end)
    return ok
end

local function tagOk(it, name)
    local tag = nil
    pcall(function() if ItemTag ~= nil then tag = ItemTag[name] end end)
    return hasTag(it, tag)
end

local ASH_TYPES = {
    Broom = true, Broom_Twig = true,
    Shovel = true, Shovel2 = true, SpadeForged = true, SpadeWood = true,
    SnowShovel = true, HandShovel = true, EntrenchingTool = true,
}
local STAIN_TYPES = { Broom = true, Broom_Twig = true, Mop = true, Sponge = true,
                      BathTowel = true, DishCloth = true, GrillBrush = true, ToiletBrush = true }

local function usableAxe(it)
    return it ~= nil and not isBroken(it) and tagOk(it, "CHOP_TREE")
end

local function usableCutTool(it)
    return it ~= nil and not isBroken(it) and tagOk(it, "CUT_PLANT")
end

local function ashToolItem(it)
    if it == nil or isBroken(it) then return false end
    if tagOk(it, "CLEAR_ASHES") then return true end
    return ASH_TYPES[itemType(it) or ""] == true
end

local function cleanStainItem(it)
    if it == nil or isBroken(it) then return false end
    if tagOk(it, "CLEAN_STAINS") then return true end
    return STAIN_TYPES[itemType(it) or ""] == true
end

local function fluidNeed()
    local n = nil
    pcall(function() n = BridgeTask and BridgeTask.CLEAN_FLUID_PER_SQUARE end)
    return tonumber(n) or 0.025
end

local function cleanerFluidAmt(it)
    local amt = 0
    pcall(function()
        local c = it ~= nil and it:getFluidContainer() or nil
        if c == nil then return end
        if c:contains(Fluid.Bleach) or c:contains(Fluid.CleaningLiquid) then
            local a = c:getAmount()
            if a >= fluidNeed() then amt = a end
        end
    end)
    return amt
end

local function petrolAmt(it)
    local amt = 0
    pcall(function()
        local c = it ~= nil and it:getFluidContainer() or nil
        if c == nil then return end
        if c:contains(Fluid.Petrol) then
            local a = c:getAmount()
            if a >= fluidNeed() then amt = a end
        end
    end)
    return amt
end

local function bandageOk(it)
    local p = 0
    pcall(function() p = it:getBandagePower() or 0 end)
    p = tonumber(p) or 0
    return p > 0
end

local function disinfectOk(it)
    local ok = false
    pcall(function()
        local fluid = BridgeCare.fluidAlcohol(it)
        if fluid ~= nil and fluid > 0 then ok = true return end
        ok = it:IsDrainable() == true and it:getAlcoholPower() == 4.0 and it:getCurrentUses() > 0
    end)
    return ok
end

local function isBattery(it)
    return itemType(it) == "Battery"
end


BridgeFetch.NEEDS = {
    { id = "axe",            matches = usableAxe },
    { id = "cutTool",        matches = usableCutTool },
    { id = "ashTool",        matches = ashToolItem },
    { id = "cleanImplement", matches = cleanStainItem },
    { id = "cleanerFluid",   fluid = true, matches = cleanerFluidAmt },
    { id = "petrol",         fluid = true, matches = petrolAmt },
    { id = "bandage",        matches = bandageOk },
    { id = "disinfectant",   matches = disinfectOk },
    { id = "battery",        matches = isBattery },
}
BridgeFetch.BY_ID = {}
for _, n in ipairs(BridgeFetch.NEEDS) do BridgeFetch.BY_ID[n.id] = n end


-- Does she already carry one of these? Uses the same predicates the jobs use, so
-- "has" matches the job's own notion of "missing".
function BridgeFetch.has(id)
    local b = Bridge.body
    if b == nil then return false end
    local ok = false
    pcall(function()
        if id == "axe" then ok = BridgeTask.findAxe(b) ~= nil
        elseif id == "cutTool" then ok = BridgeTask.findCutTool(b) ~= nil
        elseif id == "ashTool" then ok = BridgeTask.findAshTool(b) ~= nil
        elseif id == "cleanImplement" then ok = BridgeTask.findCleanStainItem(b) ~= nil
        elseif id == "cleanerFluid" then ok = BridgeTask.findStainCleaner(b) ~= nil
        elseif id == "petrol" then ok = BridgeTask.findPetrol(b) ~= nil
        elseif id == "bandage" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "bandage") == true
        elseif id == "disinfectant" then ok = BridgeHeal.hasFor(b, BridgeData.owner(), "disinfect") == true
        elseif id == "battery" then ok = BridgeTorchShared.findBattery(b) ~= nil
        end
    end)
    return ok == true
end


local function nearHome(b, h)
    if b == nil or h == nil then return false end
    local bx, by, bz = nil, nil, nil
    pcall(function() bx, by, bz = math.floor(b:getX()), math.floor(b:getY()), math.floor(b:getZ()) end)
    if bx == nil then return false end
    if math.abs(bz - h.z) >= 1 then return false end
    return bx >= (h.x - MARGIN) and bx <= (h.x + h.w - 1 + MARGIN)
        and by >= (h.y - MARGIN) and by <= (h.y + h.h - 1 + MARGIN)
end
BridgeFetch.nearHome = nearHome


function BridgeFetch.available()
    if Bridge == nil or Bridge.store == nil or Bridge.body == nil then return false end
    if not BridgeData.optionOf(Bridge.store, "homeResources") then return false end
    local h = nil
    pcall(function() h = BridgeHome ~= nil and BridgeHome.get() or nil end)
    if h == nil then return false end
    return nearHome(Bridge.body, h)
end


-- Client-side selection: nearest matching container; for cleaning fluid, the
-- container holding the most fluid. Respects locked/her-own filters (via
-- BridgeWorkSelect.lootTargets).
function BridgeFetch.findItem(needId)
    local need = BridgeFetch.BY_ID[needId]
    local b = Bridge.body
    if need == nil or b == nil then return nil end
    local h = nil
    pcall(function() h = BridgeHome ~= nil and BridgeHome.get() or nil end)
    if h == nil then return nil end
    local rect = { x1 = h.x, y1 = h.y, x2 = h.x + h.w - 1, y2 = h.y + h.h - 1, z = h.z }
    local targets = nil
    if BridgeWorkSelect ~= nil and type(BridgeWorkSelect.lootTargets) == "function" then
        local ok, res = pcall(BridgeWorkSelect.lootTargets, rect)
        if ok then targets = res end
    end
    if targets == nil then return nil end
    local bx, by = nil, nil
    pcall(function() bx, by = b:getX(), b:getY() end)
    local best, bestScore = nil, nil
    for i = 1, #targets do
        local t = targets[i]
        local c = t.cont
        if c ~= nil then
            local d = 0
            if bx ~= nil and t.x ~= nil then
                local dx, dy = bx - t.x, by - t.y
                d = math.sqrt(dx * dx + dy * dy)
            end
            local list = nil
            pcall(function() list = c:getItems() end)
            if list ~= nil then
                for j = 0, list:size() - 1 do
                    local it = list:get(j)
                    if it ~= nil then
                        local m = nil
                        pcall(function() m = need.matches(it) end)
                        if m then
                            local score = need.fluid and m or -d
                            if bestScore == nil or score > bestScore then best, bestScore = it, score end
                        end
                    end
                end
            end
        end
    end
    return best
end


-- Move one item for a need. SP: instant container -> inventory. MP: ask the
-- server, which moves it and replies through the existing "gave" pipeline.
-- Returns "moved" | "requested" | "have" | "absent" | "noroom" | "unavailable" | "failed".
function BridgeFetch.pull(needId)
    if not BridgeFetch.available() then return "unavailable" end
    if BridgeFetch.has(needId) then return "have" end
    local b = Bridge.body
    local red = BridgeData.owner()
    if b == nil or red == nil then return "unavailable" end
    local item = BridgeFetch.findItem(needId)
    if item == nil then return "absent" end
    local dest = nil
    pcall(function() dest = BridgeInventory.overflowDest(b, red, item, nil) end)
    if dest == nil then return "noroom" end
    if Bridge.mp then
        local id = nil
        pcall(function() id = item:getID() end)
        if id == nil then return "failed" end
        BridgeInventory.pending[id] = { item = item, dest = dest }
        local ok = pcall(function() sendClientCommand(red, "Bridge", "fetchSupply", { id = id, need = needId }) end)
        if not ok then
            BridgeInventory.pending[id] = nil
            return "failed"
        end
        log("requested " .. needId .. " (" .. tostring(itemType(item)) .. ") from a home container")
        return "requested"
    end
    local src = nil
    pcall(function() src = item:getContainer() end)
    if src == nil then return "absent" end
    local moved = false
    pcall(function()
        src:Remove(item)
        dest:AddItem(item)
        moved = item:getContainer() == dest
    end)
    if not moved then
        pcall(function() dest:Remove(item) src:AddItem(item) end)
        return "noroom"
    end
    pcall(function() if Bridge.saveOutfit ~= nil then Bridge.saveOutfit() end end)
    log("took " .. needId .. " (" .. tostring(itemType(item)) .. ") from a home container")
    return "moved"
end


local function jobEnabled(kind)
    local ok = true
    pcall(function()
        if kind == "chopTree" then ok = BridgeTask.TREECUTTING_ENABLED == 1
        elseif kind == "clearPlants" then ok = BridgeTask.CLEARING_ENABLED == 1
        elseif kind == "cleanUp" then ok = BridgeTask.CLEANING_ENABLED == 1
        end
    end)
    return ok == true
end


-- Which curated need ids is this job missing right now?
function BridgeFetch.jobMissing(kind, targets)
    local out = {}
    local b = Bridge.body
    if b == nil or type(targets) ~= "table" or not jobEnabled(kind) then return out end
    pcall(function()
        if kind == "chopTree" then
            if BridgeTask.findAxe(b) == nil then out[#out + 1] = "axe" end
        elseif kind == "clearPlants" then
            local needCut = false
            local haveCut = BridgeTask.findCutTool(b) ~= nil
            if not haveCut then
                for i = 1, #targets do
                    local t = targets[i]
                    local sq = getCell():getGridSquare(t.x, t.y, t.z)
                    if sq ~= nil and BridgePlants ~= nil and BridgePlants.squareBush(sq) then needCut = true break end
                end
            end
            if needCut then out[#out + 1] = "cutTool" end
        elseif kind == "cleanUp" then
            local need = {}
            for i = 1, #targets do
                local t = targets[i]
                local sq = getCell():getGridSquare(t.x, t.y, t.z)
                if sq ~= nil then
                    local kinds = BridgeTask.squareCleanKinds(sq)
                    for k = 1, #kinds do
                        local kk = kinds[k]
                        local tool, cleaner, canDo = BridgeTask.cleanKindTool(b, kk)
                        if not canDo then
                            if kk == "blood" or kk == "grime" then
                                if tool == nil then need.implement = true end
                                if cleaner == nil then need.fluid = true end
                            elseif kk == "graffiti" then
                                if tool == nil then need.implement = true end
                                if cleaner == nil then need.petrol = true end
                            elseif kk == "ashes" then
                                if tool == nil then need.ash = true end
                            elseif kk == "vine" then
                                if tool == nil then need.cut = true end
                            end
                        end
                    end
                end
            end
            if need.implement then out[#out + 1] = "cleanImplement" end
            if need.fluid then out[#out + 1] = "cleanerFluid" end
            if need.petrol then out[#out + 1] = "petrol" end
            if need.ash then out[#out + 1] = "ashTool" end
            if need.cut then out[#out + 1] = "cutTool" end
        end
    end)
    return out
end


-- Pre-phase for BridgeTask.start. Returns:
--   "skip"    -- nothing to do (option off / away / already supplied); continue normally
--   "ok"      -- item(s) pulled (SP) or already satisfied; continue normally
--   "pending" -- MP request(s) in flight; defer the job
--   "blocked" -- a need could not be satisfied; fall back to the normal missing path
function BridgeFetch.primeJob(kind, targets)
    if not BridgeFetch.available() then return "skip" end
    local missing = BridgeFetch.jobMissing(kind, targets)
    if #missing == 0 then return "skip" end
    log("job " .. tostring(kind) .. " missing home supplies: " .. table.concat(missing, ","))
    local requested = 0
    for i = 1, #missing do
        local res = BridgeFetch.pull(missing[i])
        if res == "requested" then requested = requested + 1 end
        log("  " .. missing[i] .. " -> " .. tostring(res))
    end
    local remaining = 0
    for i = 1, #missing do
        if not BridgeFetch.has(missing[i]) then remaining = remaining + 1 end
    end
    if remaining == 0 then return "ok" end
    if requested > 0 then return "pending" end
    return "blocked"
end


function BridgeFetch.tick()
    local ps = nil
    pcall(function() ps = BridgeTask and BridgeTask.pendingStart or nil end)
    if ps == nil then return end
    local now = 0
    pcall(function() now = tonumber(Bridge.time) or 0 end)
    if (now - (ps.since or now)) > PENDING_TIMEOUT then
        BridgeTask.pendingStart = nil
        log("home fetch timed out for " .. tostring(ps.kind))
        pcall(function() BridgeTask.speakMissing(ps.kind) end)
        return
    end
    local danger = false
    pcall(function() danger = BridgeTask.dangerNear ~= nil and BridgeTask.dangerNear(Bridge.body) end)
    if danger then
        BridgeTask.pendingStart = nil
        log("home fetch aborted (danger) for " .. tostring(ps.kind))
        return
    end
    local still = BridgeFetch.jobMissing(ps.kind, ps.targets)
    if #still == 0 then
        BridgeTask.pendingStart = nil
        log("home supplies arrived, starting " .. tostring(ps.kind))
        pcall(function() BridgeTask.start(ps.kind, ps.targets, ps.corpseDest) end)
    end
end


if not BridgeFetch._hooked then
    BridgeFetch._hooked = true
    Events.OnTick.Add(function() pcall(BridgeFetch.tick) end)
end

log("loaded")
