

BridgeFetch = BridgeFetch or {}

local MARGIN = 6
local PENDING_TIMEOUT = 240

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


function BridgeFetch.availableAmmo()
    if Bridge == nil or Bridge.store == nil or Bridge.body == nil then return false end
    if not BridgeData.optionOf(Bridge.store, "homeAmmo") then return false end
    local h = nil
    pcall(function() h = BridgeHome ~= nil and BridgeHome.get() or nil end)
    if h == nil then return false end
    return nearHome(Bridge.body, h)
end


local function homeTargets(cap)
    local h = nil
    pcall(function() h = BridgeHome ~= nil and BridgeHome.get() or nil end)
    if h == nil then return nil end
    local rect = { x1 = h.x, y1 = h.y, x2 = h.x + h.w - 1, y2 = h.y + h.h - 1, z = h.z }
    local targets = nil
    if BridgeWorkSelect ~= nil and type(BridgeWorkSelect.lootTargets) == "function" then
        local ok, res = pcall(BridgeWorkSelect.lootTargets, rect, cap)
        if ok then targets = res end
    end
    return targets
end


function BridgeFetch.findItem(needId)
    local need = BridgeFetch.BY_ID[needId]
    local b = Bridge.body
    if need == nil or b == nil then return nil end
    local targets = homeTargets()
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


function BridgeFetch.findAmmo(gun, minRounds)
    if gun == nil then return nil end
    minRounds = tonumber(minRounds) or 0
    local targets = homeTargets(100000)
    if targets == nil then return nil end
    local b = Bridge.body
    local bx, by = nil, nil
    if b ~= nil then pcall(function() bx, by = b:getX(), b:getY() end) end
    local useBox = gun.magazineType == nil or BridgeData.optionOf(Bridge.store, "gunMagCare")
    local useLoose = useBox
    local box = gun.ammoBox
    if box == nil and type(gun.ammoTypeKey) == "string" then
        box = BridgeGunRules.resolveItemType(gun.ammoTypeKey .. "Box",
            BridgeGunRules.moduleOf(gun.fullType),
            BridgeGunRules.moduleOf(gun.ammoTypeKey),
            "Base")
    end
    local best, bestKind, bestValue, bestD = nil, nil, nil, nil
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
                        local kind, value = nil, 0
                        pcall(function()
                            local full = it:getFullType()
                            if gun.magazineType ~= nil and full == gun.magazineType then
                                local r = BridgeGunRules.roundsOf(it)
                                if r > minRounds then kind, value = 1, r end
                            elseif useLoose and full == gun.ammoTypeKey then
                                kind, value = 2, BridgeGunRules.itemCount(it)
                            elseif useBox and box ~= nil and full == box then
                                kind, value = 3, 1
                            elseif useBox and box ~= nil then
                                local up = BridgeGunRules.unpackUp(full)
                                if up == box then
                                    kind, value = 4, 1
                                elseif up ~= nil then
                                    local up2 = BridgeGunRules.unpackUp(up)
                                    if up2 == box then kind, value = 5, 1 end
                                end
                            end
                        end)
                        if kind ~= nil then
                            local better = false
                            if best == nil then
                                better = true
                            elseif kind < bestKind then
                                better = true
                            elseif kind == bestKind then
                                if value > bestValue then
                                    better = true
                                elseif value == bestValue and (bestD == nil or d < bestD) then
                                    better = true
                                end
                            end
                            if better then best, bestKind, bestValue, bestD = it, kind, value, d end
                        end
                    end
                end
            end
        end
    end
    return best, bestKind, bestValue
end


function BridgeFetch.hasAmmoStock(gun)
    if not BridgeFetch.availableAmmo() then return false end
    return BridgeFetch.findAmmo(gun) ~= nil
end


local function homeLoose(gun, want)
    local b = Bridge.body
    local full = type(gun) == "table" and gun.ammoTypeKey or nil
    if b == nil or full == nil then return {}, 0 end
    local targets = homeTargets(100000)
    if targets == nil then return {}, 0 end
    local bx, by = nil, nil
    pcall(function() bx, by = b:getX(), b:getY() end)
    local order = {}
    for i = 1, #targets do
        local t = targets[i]
        if t.cont ~= nil then
            local d = 0
            if bx ~= nil and t.x ~= nil then
                local dx, dy = bx - t.x, by - t.y
                d = dx * dx + dy * dy
            end
            order[#order + 1] = { cont = t.cont, d = d }
        end
    end
    table.sort(order, function(a, b2) return a.d < b2.d end)
    local need = math.floor(tonumber(want) or 0)
    if need <= 0 then need = 1 end
    local items, total = {}, 0
    for i = 1, #order do
        if total >= need then break end
        local list = nil
        pcall(function() list = order[i].cont:getItems() end)
        if list ~= nil then
            local arr = {}
            for j = 0, list:size() - 1 do arr[#arr + 1] = list:get(j) end
            for j = 1, #arr do
                if total >= need then break end
                local it = arr[j]
                local t = nil
                pcall(function() t = it:getFullType() end)
                if t == full then
                    local n = BridgeGunRules.itemCount(it)
                    if n > 0 then
                        items[#items + 1] = it
                        total = total + n
                    end
                end
            end
        end
    end
    return items, total
end


function BridgeFetch.pullLoose(gun, want)
    local b = Bridge.body
    local red = BridgeData.owner()
    local full = type(gun) == "table" and gun.ammoTypeKey or nil
    if b == nil or red == nil or full == nil then return "unavailable" end
    local n = math.floor(tonumber(want) or 0)
    if n <= 0 then n = 1 end
    if Bridge.mp then
        local ok = pcall(function()
            sendClientCommand(red, "Bridge", "fetchSupply", { loose = full, take = n })
        end)
        if not ok then return "failed" end
        log(string.format("home ammo: requested %d loose %s from a home container", n, tostring(full)))
        return "requested"
    end
    local items, total = homeLoose(gun, n)
    if total <= 0 then return "absent" end
    local left = math.min(n, total)
    local moved = 0
    for i = 1, #items do
        if left <= 0 then break end
        local item = items[i]
        local have = BridgeGunRules.itemCount(item)
        local use = math.min(have, left)
        local src = nil
        pcall(function() src = item:getContainer() end)
        if src ~= nil then
            local dest = nil
            pcall(function() dest = BridgeInventory.overflowDest(b, red, item, nil) end)
            if dest ~= nil then
                local okMove = false
                pcall(function()
                    local made = {}
                    local function addSingles(count)
                        for _ = 1, count do
                            local one = instanceItem(full)
                            if one == nil then break end
                            local put = nil
                            pcall(function() put = dest:AddItem(one) end)
                            if put == nil then break end
                            made[#made + 1] = (type(put) == "table") and put or one
                        end
                        return #made
                    end
                    local function undo()
                        for i = #made, 1, -1 do pcall(function() dest:Remove(made[i]) end) end
                    end
                    if use >= have then
                        if addSingles(use) == use then
                            src:Remove(item)
                            okMove = true
                        else
                            undo()
                        end
                    elseif BridgeGunRules.setItemCount(item, have - use) then
                        if addSingles(use) == use then
                            okMove = true
                        else
                            undo()
                            pcall(function() item:setCount(have) end)
                        end
                    end
                end)
                if okMove then
                    moved = moved + use
                    left = left - use
                end
            end
        end
    end
    if moved <= 0 then return "noroom" end
    pcall(function() if Bridge.saveOutfit ~= nil then Bridge.saveOutfit() end end)
    log(string.format("home ammo: pulled %d loose %s from home (need %d, had %d)",
        moved, tostring(full), n, total))
    return "moved"
end


function BridgeFetch.pull(needId)
    if not BridgeFetch.available() then return "unavailable" end
    if BridgeFetch.has(needId) then return "have" end
    local item = BridgeFetch.findItem(needId)
    if item == nil then return "absent" end
    return BridgeFetch.pullItem(item, needId)
end


function BridgeFetch.pullItem(item, label, opts)
    local b = Bridge.body
    local red = BridgeData.owner()
    if item == nil then return "absent" end
    if b == nil or red == nil then return "unavailable" end
    local dest = nil
    pcall(function() dest = BridgeInventory.overflowDest(b, red, item, nil) end)
    if dest == nil then return "noroom" end
    local breakCarton = type(opts) == "table" and opts.breakCarton == true
    if Bridge.mp then
        local id = nil
        pcall(function() id = item:getID() end)
        if id == nil then return "failed" end
        if not breakCarton then
            BridgeInventory.pending[id] = { item = item, dest = dest }
        end
        local payload = { id = id, need = label or "item" }
        if breakCarton then payload.breakCarton = true end
        local ok = pcall(function() sendClientCommand(red, "Bridge", "fetchSupply", payload) end)
        if not ok then
            if not breakCarton then BridgeInventory.pending[id] = nil end
            return "failed"
        end
        log("requested " .. tostring(label) .. " (" .. tostring(itemType(item)) .. ") from a home container")
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
    log("took " .. tostring(label) .. " (" .. tostring(itemType(item)) .. ") from a home container")
    return "moved"
end


function BridgeFetch.pullAmmo(gun, minRounds, need)
    if not BridgeFetch.availableAmmo() then return "unavailable" end
    local item, kind = BridgeFetch.findAmmo(gun, minRounds)
    if item == nil then return "absent" end
    local function clearBorrow()
        if BridgeGunfight ~= nil then BridgeGunfight.ammoBorrow = nil end
    end
    if kind == 2 then
        clearBorrow()
        return BridgeFetch.pullLoose(gun, need)
    end
    if kind ~= 4 then
        clearBorrow()
        return BridgeFetch.pullItem(item, "ammo")
    end
    local full = nil
    pcall(function() full = item:getFullType() end)
    local breakdown, why, spec = nil, nil, nil
    pcall(function() breakdown, why, spec = BridgeGunRules.cartonBreakdown(full) end)
    local outputs = (spec ~= nil and type(spec.out) == "table") and #spec.out or 0
    if breakdown == nil or (gun ~= nil and gun.ammoBox ~= nil and breakdown.out ~= gun.ammoBox) then
        log(string.format("home ammo: carton %s has unsupported breakdown recipe (%s, out=%d, amount=%s); left in storage",
            tostring(full), tostring(why or "box type mismatch"), outputs,
            tostring(spec ~= nil and spec.amount or "?")))
        return "unsupported"
    end
    local boxType = breakdown.out
    local count = breakdown.amount - 1
    if Bridge.mp then
        return BridgeFetch.pullItem(item, "ammo", { breakCarton = true })
    end
    local src, itemId = nil, nil
    pcall(function()
        src = item:getContainer()
        itemId = item:getID()
    end)
    if src == nil then return "absent" end
    if BridgeGunfight ~= nil then
        BridgeGunfight.ammoBorrow = {
            src = src,
            itemId = itemId,
            cartonType = full,
            boxType = boxType,
            count = count,
        }
    end
    log(string.format("home ammo: carton %s selected from %s, will keep 1 and return %d",
        tostring(full), tostring(src), count))
    local res = BridgeFetch.pullItem(item, "ammo")
    if res ~= "moved" then clearBorrow() end
    if res == "moved" then
        log(string.format("home ammo: carton %s pulled from %s id=%s",
            tostring(full), tostring(src), tostring(itemId)))
    end
    return res
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
