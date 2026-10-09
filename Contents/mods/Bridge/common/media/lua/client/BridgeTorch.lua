


















BridgeTorch = BridgeTorch or {}


BridgeTorch.TEST_ON = false
BridgeTorch.TEST_OFF = false

BridgeTorch.info = "off"
BridgeTorch.lamps = {}
BridgeTorch.sent = {}
BridgeTorch.pending = {}
BridgeTorch.litFlag = {}
BridgeTorch.litAt = {}
BridgeTorch.dbg = {}




BridgeTorch.ambient = {}
BridgeTorch.ambientAt = {}



BridgeTorch.lvl = {}
BridgeTorch.lvlAt = {}
BridgeTorch.probe = {}



BridgeTorch.litStreak = {}
BridgeTorch.probeLitConfirm = 3
BridgeTorch.dayLit = {}
BridgeTorch.reloadSent = {}
BridgeTorch.invDbgAt = {}
BridgeTorch.lastCharge = {}
BridgeTorch.reloadFbAt = {}
BridgeTorch.insertBody = nil
BridgeTorch.insertClearAt = 0
BridgeTorch.stats = { frames = 0, places = 0, releases = 0, adds = 0, removes = 0, at = 0 }



BridgeTorch.SETTLE_MS = 2000

BridgeTorch.INSERT_FRAMES = 90

BridgeTorch.LOW_CHARGE = 0.5

BridgeTorch.DEBUG = false

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeTorch] " .. tostring(text)) end end
local function warn(text) print("[BridgeTorch] " .. tostring(text)) end

local lastTraceMs = 0





local function feedback(body)


    pcall(function()
        if BridgeMoments ~= nil and type(BridgeMoments.say) == "function" then
            BridgeMoments.say("EvTorchDead", 5 * 60, true, "TorchDead")
        end
    end)
end




local function feedbackReload(body)
    local key = BridgeTorchShared.keyOf(body)
    local now = getTimestampMs()
    if now - (BridgeTorch.reloadFbAt[key] or 0) < 4000 then return end
    BridgeTorch.reloadFbAt[key] = now
    log("[TorchInv] reload feedback fired")


    if body ~= nil then
        pcall(function()
            local red = BridgeData.owner()
            if red ~= nil then body:faceLocationF(red:getX(), red:getY()) end
        end)
        pcall(function() body:setBumpType("AttachItem") end)
        BridgeTorch.insertBody = body
        BridgeTorch.insertClearAt = Bridge.time + BridgeTorch.INSERT_FRAMES
    end
    pcall(function()
        if BridgeMoments ~= nil and type(BridgeMoments.say) == "function" then
            BridgeMoments.say("EvTorchReload", 3 * 60, true, "TorchReload")
        end
    end)
end

local function push(body, want, range)
    if body == nil then return end


    if BridgeSound ~= nil and type(BridgeSound.sfx) == "function" then
        pcall(function() BridgeSound.sfx(body, want and "FlashlightOn" or "FlashlightOff") end)
    end




    BridgeTorchShared.apply(body, want, range)
    if Bridge.mp then
        pcall(function()
            sendClientCommand(BridgeData.owner(), "Bridge", "torch", { on = want, range = range })
        end)
    end
end











local function invalidateLights()
    if not (LightingJNI and LightingJNI.doInvalidateGlobalLights) then return end




    local idx = 0
    pcall(function()
        local p = getPlayer()
        if p ~= nil then idx = p:getPlayerNum() or 0 end
    end)
    if idx == 0 and IsoPlayer ~= nil and IsoPlayer.getPlayerIndex ~= nil then
        local ok, v = pcall(IsoPlayer.getPlayerIndex)
        if ok and type(v) == "number" then idx = v end
    end
    pcall(function() LightingJNI.doInvalidateGlobalLights(idx) end)
end
BridgeTorch.invalidateLights = invalidateLights

local function beamSources(key)
    local e = BridgeTorch.lamps[key]
    if e == nil then return nil end
    return e.sources
end

local function setBeamActive(key, active)
    local srcs = beamSources(key)
    if srcs == nil then return end
    for i = 1, #srcs do
        if srcs[i] ~= nil then pcall(function() srcs[i]:setActive(active) end) end
    end
end
BridgeTorch.setBeamActive = setBeamActive


function BridgeTorch.kickProbe(body, raw)
    if body == nil then return end
    local key = BridgeTorchShared.keyOf(body)
    if BridgeTorch.probe[key] ~= nil then return end
    if beamSources(key) == nil then return end
    setBeamActive(key, false)
    invalidateLights()
    BridgeTorch.probe[key] = { body = body, at = getTimestampMs(), raw = raw }
end


local function probeTick()
    for key, p in pairs(BridgeTorch.probe) do


        if (getTimestampMs() - (p.at or 0)) >= 50 then
            local v = nil
            if p.body ~= nil then
                pcall(function() v = BridgeTorchShared.darkAt(p.body) end)
            end
            v = tonumber(v)
            if v ~= nil then



                local rawAt = tonumber(p.raw)
                local trustworthy = rawAt ~= nil and (rawAt - v) > 0.15
                local lit = v >= BridgeTorchShared.CFG.DARK_HI
                if trustworthy and lit then
                    BridgeTorch.litStreak[key] = (BridgeTorch.litStreak[key] or 0) + 1
                else
                    BridgeTorch.litStreak[key] = 0
                end
                BridgeTorch.ambient[key] = v
                BridgeTorch.ambientAt[key] = getTimestampMs()
            end
            setBeamActive(key, true)
            invalidateLights()
            BridgeTorch.probe[key] = nil
        end
    end
end
Events.OnTick.Add(function() pcall(probeTick) end)


Events.OnTick.Add(function()
    local b = BridgeTorch.insertBody
    if b ~= nil and Bridge.time >= (BridgeTorch.insertClearAt or 0) then
        BridgeTorch.insertBody = nil
        pcall(function()
            if tostring(b:getBumpType()) == "AttachItem" then b:setBumpType("") end
        end)
    end
end)



function BridgeTorch.onServerState(args)
    if args == nil then return end
    local on = args.on == true
    local range = args.range

    local function idMatches(z)
        local ok = false
        pcall(function() ok = (args.id == nil or z:getPersistentOutfitID() == args.id) and not z:isDead() end)
        return ok
    end

    local function stamp(z)
        pcall(function()
            z:setVariable(BridgeTorchShared.VAR, on)
            z:setVariable(BridgeTorchShared.RANGE_VAR, on and tostring(range or "") or "")
        end)
    end





    if args.id ~= nil then
        local key = "p" .. tostring(args.id)
        BridgeTorch.sent[key] = on
        BridgeTorch.pending[key] = nil
    end


    if Bridge.body ~= nil and idMatches(Bridge.body) then stamp(Bridge.body) end


    if args.reload == true and Bridge.body ~= nil and idMatches(Bridge.body) then
        feedbackReload(Bridge.body)
    end


    for z, _ in pairs(Bridge.seen or {}) do
        if idMatches(z) then stamp(z) end
    end
end


function BridgeTorch.update(body)
    if body == nil then return end
    local red = BridgeData.owner()


    local dead = false
    pcall(function() dead = body:getVariableBoolean(BridgeTorchShared.DEAD_VAR) == true end)
    if dead then
        pcall(function() body:setVariable(BridgeTorchShared.DEAD_VAR, false) end)
        feedback(body)
    end

    local key = BridgeTorchShared.keyOf(body)




    if BridgeTorch.sent[key] ~= nil or BridgeTorchShared.isOn(body) then
        local actualOn = BridgeTorchShared.isOn(body)
        if BridgeTorch.sent[key] ~= actualOn then
            BridgeTorch.sent[key] = actualOn
            BridgeTorch.pending[key] = nil
        end
    end

    if BridgeTorch.sent[key] == nil or Bridge.every(60) then







        local raw = BridgeTorchShared.darkAt(body)
        local onNow = BridgeTorchShared.isOn(body)



        local external, why = false, "none"
        if BridgeTorch.externalLight ~= nil then
            local ok, e, w = pcall(BridgeTorch.externalLight, body, red)
            if ok then external, why = (e == true), (w or "?") end
        end
        if not external and BridgeTorch.roomLit ~= nil then
            local ok, rl, rw = pcall(BridgeTorch.roomLit, body)
            if ok and rl == true then external, why = true, (rw or "roomLight") end
        end

        local lvl = raw
        if onNow then
            local nowMs = getTimestampMs()
            local amb = BridgeTorch.ambient[key]
            local ambAge = nowMs - (BridgeTorch.ambientAt[key] or 0)
            if amb == nil or ambAge >= 2000 then
                if BridgeTorch.kickProbe ~= nil then pcall(BridgeTorch.kickProbe, body, raw) end
                amb = BridgeTorch.ambient[key]
                ambAge = getTimestampMs() - (BridgeTorch.ambientAt[key] or 0)
            end


            if amb ~= nil and ambAge <= 2200 and amb < raw - 0.15 then
                if amb >= BridgeTorchShared.CFG.DARK_HI then





                    local streak = BridgeTorch.litStreak[key] or 0
                    if external or streak >= (BridgeTorch.probeLitConfirm or 2) then
                        lvl = amb
                        BridgeTorch.lvl[key] = amb
                        BridgeTorch.lvlAt[key] = nowMs
                    else
                        lvl = nil
                    end
                else
                    lvl = amb
                    BridgeTorch.lvl[key] = amb
                    BridgeTorch.lvlAt[key] = nowMs
                end
            else






                local lat = BridgeTorch.lvlAt[key]
                if lat ~= nil and (nowMs - lat) <= (BridgeTorch.SETTLE_MS - 500) then
                    lvl = BridgeTorch.lvl[key]
                else
                    lvl = nil
                end
            end
        else
            BridgeTorch.litStreak[key] = 0
        end
        local want = BridgeTorchShared.wantOn(body, red, lvl, external, why)
        local mode, hasItem, charge, hasBat = "?", false, nil, false
        pcall(function() mode = BridgeData.torchMode(Bridge.store) end)
        pcall(function()
            local it = BridgeTorchShared.findTorch(body)
            hasItem = it ~= nil
            if it ~= nil then charge = BridgeTorchShared.charge(it) end
        end)
        pcall(function()
            local bat = BridgeTorchShared.findBattery(body)
            hasBat = bat ~= nil
        end)



        local dOut, dDay = false, 0
        pcall(function()
            local sq = body:getCurrentSquare()
            if sq ~= nil then
                pcall(function() dOut = sq:isOutside() == true end)
                local c = getClimateManager()
                if c ~= nil then dDay = tonumber(c:getDayLightStrength()) or 0 end
            end
        end)
        BridgeTorch.dbg[key] = { lvl = lvl, raw = raw, amb = BridgeTorch.ambient[key], want = want, on = BridgeTorch.sent[key], mode = mode, item = hasItem, charge = charge, bat = hasBat, ext = external, why = why, out = dOut, day = dDay, strk = (BridgeTorch.litStreak[key] or 0) }



        if type(charge) == "number" then
            local prevC = BridgeTorch.lastCharge[key]
            if prevC ~= nil and prevC <= 0.0001 and charge > 0.0001 then
                feedbackReload(body)
            end
            BridgeTorch.lastCharge[key] = charge
        end



        if BridgeTorchShared.isOn(body) and type(charge) == "number"
            and charge > 0 and charge < BridgeTorch.LOW_CHARGE then
            if BridgeCallout ~= nil and type(BridgeCallout.sayPriority) == "function" then
                pcall(BridgeCallout.sayPriority, "EvTorchLow")
            end
        end



        if BridgeTorch.DEBUG and (hasItem or hasBat) and (getTimestampMs() - (BridgeTorch.invDbgAt[key] or 0)) > 2000 then
            BridgeTorch.invDbgAt[key] = getTimestampMs()
            local ttype, drainable, canemit = "nil", false, false
            local it = BridgeTorchShared.findTorch(body)
            if it ~= nil then
                pcall(function() ttype = it:getFullType() end)
                pcall(function() drainable = it:IsDrainable() == true end)
                pcall(function() canemit = it:canEmitLight() == true end)
            end
            local btype = "nil"
            pcall(function()
                local b = BridgeTorchShared.findBattery(body)
                if b ~= nil then btype = b:getFullType() end
            end)
            local items = {}
            pcall(function()
                local inv = body:getInventory()
                if inv ~= nil then
                    local list = inv:getAllEvalRecurse(function(it) return true end)
                    if list ~= nil then
                        for i = 0, list:size() - 1 do
                            local o = list:get(i)
                            local ft = nil
                            pcall(function() ft = o:getFullType() end)
                            if ft ~= nil and #items < 16 then items[#items + 1] = ft end
                        end
                    end
                end
            end)
            log(string.format("[TorchInv] mp=%s torch=%s charge=%s drain=%s canEmit=%s bat=%s combat=%s lastAsk=%sms inv=[%s]",
                tostring(Bridge.mp), tostring(ttype), tostring(charge), tostring(drainable), tostring(canemit),
                tostring(btype), tostring(BridgeTorchShared.inCombat(body)),
                tostring(getTimestampMs() - (BridgeTorch.reloadSent[key] or 0)), table.concat(items, ",")))
        end



        if BridgeTorch.sent[key] ~= want then
            local now = getTimestampMs()
            local p = BridgeTorch.pending[key]
            if p == nil or p.want ~= want then
                BridgeTorch.pending[key] = { want = want, since = now }
            elseif (now - p.since) >= BridgeTorch.SETTLE_MS then
                BridgeTorch.pending[key] = nil
                local first = (BridgeTorch.sent[key] == nil)
                BridgeTorch.sent[key] = want
                BridgeTorchShared.remember(body, want)




                if want == true or not first then
                    local range = nil
                    pcall(function()
                        local item = BridgeTorchShared.findTorch(body)
                        if item ~= nil then range = BridgeTorchShared.rangeOf(item) end
                    end)
                    push(body, want, range)
                end
                BridgeTorch.info = want and "on" or "off"
            end
        else
            BridgeTorch.pending[key] = nil
        end
    end


    if not Bridge.mp then
        if BridgeTorchShared.isOn(body) and Bridge.every(60) then
            local empty = BridgeTorchShared.drain(body)
            if empty then
                BridgeTorch.sent[key] = false
                BridgeTorchShared.apply(body, false)
                if BridgeSound ~= nil and type(BridgeSound.sfx) == "function" then
                    pcall(function() BridgeSound.sfx(body, "FlashlightOff") end)
                end
                BridgeTorch.info = "empty"
                feedback(body)
                if not BridgeTorchShared.inCombat(body) then
                    local ok, swapped = pcall(function() return BridgeTorchShared.swapBattery(body) end)
                    if ok and swapped then feedbackReload(body) end
                end
            end
        end




        if Bridge.every(60) then
            local it = BridgeTorchShared.findTorch(body)
            if it ~= nil and BridgeTorchShared.charge(it) <= 0.0001
                and not BridgeTorchShared.inCombat(body) then
                local ok, swapped = pcall(function() return BridgeTorchShared.swapBattery(body) end)
                if ok and swapped then
                    BridgeTorch.info = "reloaded"
                    feedbackReload(body)
                end
            end
        end
    end




    if Bridge.mp and Bridge.every(60) then
        local it = BridgeTorchShared.findTorch(body)
        if it ~= nil and BridgeTorchShared.charge(it) <= 0.0001
            and not BridgeTorchShared.inCombat(body) then
            local now = getTimestampMs()
            if now - (BridgeTorch.reloadSent[key] or 0) > 3000 then
                BridgeTorch.reloadSent[key] = now
                log("[TorchInv] torch empty in MP - asking server to fit a cell")
                pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "reload", {}) end)
            end
        end
    end
end













BridgeTorch.BEAM_MS = 500

local function releaseEntry(cell, key)
    local e = BridgeTorch.lamps[key]
    if e == nil then return end
    for i = 1, #e.sources do
        local src = e.sources[i]
        pcall(function() src:setActive(false) end)
        pcall(function() cell:removeLamppost(src) end)
        BridgeTorch.stats.removes = BridgeTorch.stats.removes + 1
    end
    BridgeTorch.stats.releases = BridgeTorch.stats.releases + 1
    BridgeTorch.lamps[key] = nil
end

function BridgeTorch.clearAll()
    local cell = getCell()
    if cell ~= nil then
        for key, _ in pairs(BridgeTorch.lamps) do releaseEntry(cell, key) end
    end
    BridgeTorch.lamps = {}
end


local function quantize(a)
    return math.floor((a + 22.5) / 45) * 45
end





local function blockedTo(cell, fromX, fromY, zz, tx, ty)
    if LosUtil ~= nil and type(LosUtil.lineClear) == "function" then
        local res, ok = nil, false
        ok = pcall(function()
            res = LosUtil.lineClear(cell, fromX, fromY, zz, tx, ty, zz, false)
        end)
        if ok and res ~= nil then
            local blocked = nil
            pcall(function()
                if LosUtil.TestResults ~= nil then blocked = LosUtil.TestResults.Blocked end
            end)
            if blocked ~= nil then return res == blocked end
            return tostring(res) == "Blocked"
        end
    end
    local sq, solid, solidtrans = nil, false, false
    pcall(function() sq = cell:getGridSquare(tx, ty, zz) end)
    if sq == nil then return true end
    pcall(function() solid = sq:isSolid() == true end)
    pcall(function() solidtrans = sq:isSolidTrans() == true end)
    return solid or solidtrans
end








local function foreignLightNear(body)
    local cell = getCell()
    if cell == nil then return false end
    local bx, by, bz = nil, nil, nil
    pcall(function() bx, by, bz = math.floor(body:getX() + 0.5), math.floor(body:getY() + 0.5), body:getZ() end)
    if bx == nil then return false end

    local ours = {}
    for _, e in pairs(BridgeTorch.lamps) do
        for i = 1, #e.sources do ours[e.sources[i]] = true end
    end

    local found, bestD, bestR, bestBri = false, nil, nil, nil
    local nearD, nearR, nearBri = nil, nil, nil
    pcall(function()
        local positions = cell:getLamppostPositions()
        if positions == nil then return end
        for i = 0, positions:size() - 1 do
            local s = positions:get(i)
            if s ~= nil and not ours[s] then
                local active = false
                pcall(function() active = s:isActive() == true end)
                if active then
                    local sx, sy, sz, rr, bri = nil, nil, nil, 0, 0
                    pcall(function()
                        sx, sy, sz = s:getX(), s:getY(), s:getZ()
                        rr = tonumber(s:getRadius()) or 0
                        local cr = tonumber(s:getR()) or 0
                        local cg = tonumber(s:getG()) or 0
                        local cb = tonumber(s:getB()) or 0
                        bri = math.max(cr, math.max(cg, cb))
                    end)
                    if sx ~= nil and sz == bz then
                        local dx, dy = sx - bx, sy - by
                        local d2 = dx * dx + dy * dy
                        local dist = math.sqrt(d2)


                        if nearD == nil or dist < nearD then
                            nearD, nearR, nearBri = dist, rr, bri
                        end
                        if rr >= 2 and bri >= BridgeTorchShared.CFG.EXTERNAL_MIN_BRI then
                            local reach = math.min(rr, BridgeTorchShared.CFG.EXTERNAL_NEAR)
                            if d2 <= reach * reach then
                                if not blockedTo(cell, sx, sy, sz, bx, by) then
                                    if bestD == nil or dist < bestD then
                                        found, bestD, bestR, bestBri = true, dist, rr, bri
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    return found, bestD, bestR, bestBri, nearD, nearR, nearBri
end




local function vcall(obj, method, ...)
    if obj == nil then return nil end
    local fn = nil
    local ok = pcall(function() fn = obj[method] end)
    if not ok or fn == nil then return nil end
    local ok2, value = pcall(fn, obj, ...)
    if not ok2 then return nil end
    return value
end








local function vehicleLightNear(body)
    local cell = getCell()
    if cell == nil then return false, nil end
    local bx, by, bz = vcall(body, "getX"), vcall(body, "getY"), vcall(body, "getZ")
    if bx == nil or by == nil or bz == nil then return false, nil end
    bx, by, bz = math.floor(bx + 0.5), math.floor(by + 0.5), math.floor(bz)

    local list = vcall(cell, "getVehicles")
    if list == nil then return false, nil end

    local near = BridgeTorchShared.CFG.EXTERNAL_NEAR
    local found, bestD = false, nil
    local count = tonumber(vcall(list, "size")) or 0
    for i = 0, count - 1 do
        local v = vcall(list, "get", i)
        if v ~= nil then
            local lit = vcall(v, "hasHeadlights") == true and vcall(v, "getHeadlightsOn") == true
            if lit then


                local can = vcall(v, "getHeadlightCanEmmitLight")
                if can ~= nil then lit = can ~= false end
            end
            if lit then
                local vx, vy, vz = vcall(v, "getX"), vcall(v, "getY"), vcall(v, "getZ")
                if vx ~= nil and vy ~= nil and vz ~= nil and math.floor(vz) == bz then
                    local dx, dy = vx - bx, vy - by
                    local d2 = dx * dx + dy * dy
                    if d2 <= near * near
                        and not blockedTo(cell, math.floor(vx + 0.5), math.floor(vy + 0.5), bz, bx, by) then
                        local dist = math.sqrt(d2)
                        if bestD == nil or dist < bestD then found, bestD = true, dist end
                    end
                end
            end
        end
    end
    return found, bestD
end







function BridgeTorch.roomLit(body)
    if body == nil then return false, "nobody" end
    local sq = nil
    pcall(function() sq = body:getCurrentSquare() end)
    if sq == nil then return false, "nosq" end
    local room = nil
    pcall(function() room = sq:getRoom() end)
    if room == nil then return false, "outdoor" end
    local x1, x2, y1, y2 = nil, nil, nil, nil
    pcall(function()
        local rd = room:getRoomDef()
        if rd ~= nil then
            x1, x2, y1, y2 = rd:getX(), rd:getX2(), rd:getY(), rd:getY2()
        end
    end)
    if x1 == nil then return false, "nodef" end
    local z = nil
    pcall(function() z = sq:getZ() end)
    if z == nil then return false, "noz" end


    local herRid = nil
    do
        local fn = sq.getRoomID
        if type(fn) == "function" then pcall(function() herRid = fn(sq) end) end
    end

    local cell = getCell()
    if cell == nil then return false, "nocell" end
    local lit, switchOn = false, false
    pcall(function()
        for x = x1 - 1, x2 + 1 do
            for y = y1 - 1, y2 + 1 do
                local s = cell:getGridSquare(x, y, z)
                if s ~= nil then
                    local objs = s:getObjects()
                    if objs ~= nil then
                        for i = 0, objs:size() - 1 do
                            local o = objs:get(i)
                            if o ~= nil and instanceof(o, "IsoLightSwitch") then
                                local act, can = false, false
                                pcall(function() act = o:isActivated() == true end)




                                pcall(function() can = o:canSwitchLight() == true end)
                                local sameRoom = true
                                if herRid ~= nil then
                                    local rid = nil
                                    local fn = s.getRoomID
                                    if type(fn) == "function" then pcall(function() rid = fn(s) end) end
                                    if rid == nil then
                                        local ofn = o.getRoomID
                                        if type(ofn) == "function" then pcall(function() rid = ofn(o) end) end
                                    end
                                    if rid ~= nil and rid ~= herRid then sameRoom = false end
                                end
                                if sameRoom then
                                    if act then switchOn = true end
                                    if act and can then lit = true break end
                                end
                            end
                        end
                    end
                end
                if lit then break end
            end
            if lit then break end
        end
    end)
    if lit then return true, "roomLight" end
    if switchOn then return false, "switchOnNoPower" end
    return false, "roomLightOff"
end




function BridgeTorch.externalLight(body, red)
    local day = false
    local key = BridgeTorchShared.keyOf(body)
    pcall(function()
        local sq = body:getCurrentSquare()
        if sq ~= nil then



            local outside, gotOutside = false, false
            pcall(function() outside = sq:isOutside() == true; gotOutside = true end)
            if not gotOutside then
                local room = nil
                pcall(function() room = sq:getRoom() end)
                outside = (room == nil)
            end
            if outside then
                local c = getClimateManager()
                local ds = 0
                if c ~= nil then ds = tonumber(c:getDayLightStrength()) or 0 end



                local wasDay = BridgeTorch.dayLit[key] == true
                local onThr = BridgeTorchShared.CFG.DAY_OFF
                local offThr = onThr - BridgeTorchShared.CFG.DAY_HYST
                local isDay = (wasDay and ds > offThr) or (ds > onThr)
                BridgeTorch.dayLit[key] = isDay
                if isDay then day = true end
            else

                BridgeTorch.dayLit[key] = false
            end
        end
    end)
    if day then return true, "daylight" end

    local found, dist, rr, bri, nd, nr, nb = foreignLightNear(body)
    if found then
        return true, string.format("foreignLight d=%.1f r=%s b=%.2f", dist or -1, tostring(rr), bri or -1)
    end
    local vfound, vdist = vehicleLightNear(body)
    if vfound then




        local key = BridgeTorchShared.keyOf(body)
        local at = BridgeTorch.lvlAt[key]
        local confirmed = (at ~= nil and (getTimestampMs() - at) <= 2500) and BridgeTorch.lvl[key] or nil
        if confirmed ~= nil and confirmed >= BridgeTorchShared.CFG.DARK_LO then
            return true, string.format("vehicleLight d=%.1f", vdist or -1)
        end
    end

    if nd ~= nil then
        return false, string.format("none near d=%.1f r=%s b=%.2f", nd, tostring(nr), nb or -1)
    end
    return false, "none"
end





local function placeBeam(cell, z, key, px, py, zz, dir, now)
    local range = nil
    pcall(function() range = tonumber(z:getVariableString(BridgeTorchShared.RANGE_VAR)) end)
    local reach, radius = BridgeTorchShared.beamPoint(range)
    local col = BridgeTorchShared.CFG.color

    local rad = math.rad(dir)
    local cx, cy = math.cos(rad), math.sin(rad)

    local bx, by = px, py
    local steps = math.max(1, math.floor(reach + 0.5))
    for d = 1, steps do
        local tx = math.floor(px + cx * d + 0.5)
        local ty = math.floor(py + cy * d + 0.5)
        if blockedTo(cell, px, py, zz, tx, ty) then break end
        bx, by = tx, ty
    end

    local sources = {}
    local src = nil
    pcall(function()



        src = IsoLightSource.new(bx, by, zz, col[1], col[2], col[3], radius)
    end)
    if src ~= nil then
        pcall(function() src:setActive(true) end)
        pcall(function() cell:addLamppost(src) end)
        sources[1] = src
        BridgeTorch.stats.adds = BridgeTorch.stats.adds + 1
    end
    BridgeTorch.stats.places = BridgeTorch.stats.places + 1
    BridgeTorch.lamps[key] = { x = px, y = py, z = zz, dir = dir, at = now, bx = bx, by = by, sources = sources }
end

function BridgeTorch.renderFrame()
    BridgeTorch.stats.frames = BridgeTorch.stats.frames + 1
    local cell = getCell()
    if cell == nil then return end
    local now = getTimestampMs()

    local live = {}
    local markedN, litN = 0, 0
    pcall(function()
        local list = cell:getZombieList()
        if list == nil then return end
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil then
                local marked, on = false, false
                pcall(function() marked = z:getVariableBoolean("NotAloneBody") == true end)
                if marked then
                    markedN = markedN + 1
                    pcall(function() on = z:getVariableBoolean(BridgeTorchShared.VAR) == true end)
                    if on then litN = litN + 1 end
                end
                if marked and on then
                    local key = BridgeTorchShared.keyOf(z)
                    live[key] = true

                    local px, py, zz = nil, nil, nil
                    pcall(function() px, py, zz = math.floor(z:getX()), math.floor(z:getY()), math.floor(z:getZ()) end)
                    if px ~= nil then
                        local dir = 0
                        pcall(function() dir = quantize(z:getDirectionAngle()) end)

                        local e = BridgeTorch.lamps[key]


                        if BridgeTorch.probe[key] == nil and (e == nil or (now - (e.at or 0)) >= BridgeTorch.BEAM_MS) then
                            releaseEntry(cell, key)
                            placeBeam(cell, z, key, px, py, zz, dir, now)

                            if Bridge ~= nil and Bridge.verbose and now - lastTraceMs > 2000 then
                                lastTraceMs = now
                                local red = BridgeData.owner()
                                local rx, ry = -1, -1
                                if red ~= nil then rx, ry = math.floor(red:getX()), math.floor(red:getY()) end
                                log(string.format("beam tile=%d,%d z=%s dir=%d | player tile=%d,%d", px, py, tostring(zz), dir, rx, ry))
                            end
                        end
                    end
                end
            end
        end
    end)

    for key, _ in pairs(BridgeTorch.lamps) do
        if not live[key] then releaseEntry(cell, key) end
    end

    BridgeTorch.stats.marked = markedN
    BridgeTorch.stats.lit = litN
    BridgeTorch.report()
end





function BridgeTorch.report()
    if not BridgeTorch.DEBUG and not (BridgeLog ~= nil and BridgeLog.on()) then
        BridgeTorch.stats.frames = 0
        BridgeTorch.stats.at = 0
        return
    end
    local st = BridgeTorch.stats
    local now = getTimestampMs()
    if st.at == 0 then st.at = now return end
    local ms = now - st.at
    if ms < 1000 then return end

    local size = -1
    pcall(function() size = getCell():getLamppostPositions():size() end)
    local lamps = 0
    for _ in pairs(BridgeTorch.lamps) do lamps = lamps + 1 end
    local d = nil
    for _, v in pairs(BridgeTorch.dbg) do d = v break end
    local function fmtN(v) if type(v) == "number" then return string.format("%.2f", v) end return "-" end

    log(string.format(
        "[TorchDbg] fps=%.0f place/s=%.1f add/s=%.1f rm/s=%.1f lampposts=%d lamps=%d marked=%d lit=%d | lvl=%s raw=%s amb=%s want=%s on=%s mode=%s item=%s charge=%s bat=%s ext=%s why=%s out=%s day=%s strk=%s",
        st.frames * 1000 / ms, st.places * 1000 / ms, st.adds * 1000 / ms, st.removes * 1000 / ms, size, lamps,
        st.marked or 0, st.lit or 0,
        d and fmtN(d.lvl) or "-",
        d and fmtN(d.raw) or "-",
        d and fmtN(d.amb) or "-",
        d and tostring(d.want) or "-", d and tostring(d.on) or "-",
        d and tostring(d.mode) or "-", d and tostring(d.item) or "-",
        d and (d.charge and string.format("%.3f", d.charge) or "-") or "-",
        d and tostring(d.bat) or "-",
        d and tostring(d.ext) or "-", d and tostring(d.why) or "-",
        d and tostring(d.out) or "-", d and fmtN(d.day) or "-", d and tostring(d.strk) or "-"))

    st.frames, st.places, st.releases, st.adds, st.removes, st.at = 0, 0, 0, 0, 0, now
    st.marked, st.lit = 0, 0
end





Events.OnPlayerUpdate.Add(function() pcall(BridgeTorch.renderFrame) end)
Events.OnGameStart.Add(function() pcall(BridgeTorch.clearAll) end)
Events.OnResetLua.Add(function() pcall(BridgeTorch.clearAll) end)
Events.OnPlayerDeath.Add(function() pcall(BridgeTorch.clearAll) end)

log("loaded")
