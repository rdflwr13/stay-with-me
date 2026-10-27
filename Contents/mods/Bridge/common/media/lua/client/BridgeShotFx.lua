BridgeShotFx = BridgeShotFx or {}
local M = BridgeShotFx

M.max = 32
M.cap = 9
M.muzzle = 0.55
M.muzzleTwo = 0.95
M.height = 0.45
M.cone = 7
M.fanJitter = 2.2
M.jitter = 0.4
M.maxMs = 2500
M.headLength = 0
M.streak = 0
M.speedScale = 0.1875
M.minSpeed = 80
M.maxSpeed = 1000
M.pathWidth = 1
M.trailWidth = 1
M.headWidth = 1

local BASE = {
    pr = 1, pg = 0.84, pb = 0.53, pa = 0.912,
    tr = 1, tg = 0.84, tb = 0.61, ta = 0.519,
    pathr = 1, pathg = 1, pathb = 1, patha = 0.101, pathfade = 1.013,
    plen = 0.177, tlen = 0.898, speed = 1205.9,
}

local function cfg(over)
    local out = {}
    for k, v in pairs(BASE) do out[k] = v end
    for k, v in pairs(over or {}) do out[k] = v end
    return out
end

local AMMO = {
    ["base:bullets_9mm"] = cfg({}),
    ["base:bullets_44"] = cfg({ pa = 0.81, ta = 0.282, patha = 0.317, pathfade = 2, plen = 0.236, tlen = 0.898, speed = 1564.06 }),
    ["base:bullets_45"] = cfg({ pa = 0.81, ta = 0.519, patha = 0.122, pathfade = 1.013, plen = 0.157, tlen = 0.898, speed = 842.35 }),
    ["base:bullets_38"] = cfg({ pa = 0.81, ta = 0.526, patha = 0.576, pathfade = 0.86, plen = 0.2475, tlen = 1.584, speed = 863.12 }),
    ["base:bullets_556"] = cfg({ pa = 0.81, ta = 0.283, patha = 0.312, pathfade = 2, plen = 0.236, tlen = 0.898, speed = 3013.23 }),
    ["base:bullets_308"] = cfg({ pa = 0.912, ta = 0.655, patha = 0.338, pathfade = 1.013, plen = 0.349, tlen = 0.898, speed = 2639.3 }),
    ["base:bullets_223"] = cfg({ pa = 0.81, ta = 0.36, patha = 0.44, pathfade = 0.86, plen = 0.2475, tlen = 0.898, speed = 3106.72 }),
    ["base:shotgun_shells"] = cfg({ pa = 0.81, ta = 0.489, patha = 0.345, pathfade = 2, plen = 0.239, tlen = 1.971, speed = 1050.09 }),
}

local live = {}
local warned = {}
local lastAmmo = nil
local spawnLogged = false
local texture = nil
local textureRetryAt = 0
local textureWarned = false
local rendererWarned = false
local screenWarned = false
local drawLogged = false
local muzzleLogged = false
local tickErrors = 0
local renderErrors = 0
local renderHook = "none"

local function log(message)
    print("[BridgeShotFx] " .. tostring(message))
end

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nowMs()
    local value = nil
    pcall(function() value = tonumber(getTimestampMs()) end)
    if value ~= nil then return value end
    return math.floor((os.clock() or 0) * 1000)
end

local function whiteTexture()
    if texture ~= nil then return texture end
    local now = nowMs()
    if now < textureRetryAt then return nil end
    textureRetryAt = now + 5000
    if type(getTexture) ~= "function" then return nil end
    pcall(function() texture = getTexture("media/white.png") end)
    if texture == nil and not textureWarned then
        textureWarned = true
        log("tracer texture unavailable")
    end
    return texture
end

local function screenReady()
    return type(IsoUtils) == "table"
        and type(IsoUtils.XToScreen) == "function"
        and type(IsoUtils.YToScreen) == "function"
        and type(getCameraOffX) == "function"
        and type(getCameraOffY) == "function"
end

local function view()
    local index = 0
    local player = nil
    pcall(function() player = getPlayer() end)
    if player ~= nil then
        pcall(function() index = tonumber(player:getPlayerNum()) or 0 end)
    end
    local zoom = 1
    pcall(function() zoom = tonumber(getCore():getZoom(index)) or 1 end)
    if zoom <= 0 then zoom = 1 end
    local ox, oy = 0, 0
    local count = 1
    pcall(function() count = tonumber(getNumActivePlayers()) or 1 end)
    if count > 1 then
        pcall(function()
            ox = tonumber(getPlayerScreenLeft(index)) or 0
            oy = tonumber(getPlayerScreenTop(index)) or 0
        end)
    end
    return zoom, ox, oy
end

local function toScreen(x, y, z, zoom, ox, oy)
    local sx = IsoUtils.XToScreen(x, y, z, 0) - getCameraOffX()
    local sy = IsoUtils.YToScreen(x, y, z, 0) - getCameraOffY()
    return sx / zoom + ox, sy / zoom + oy
end

local function drawLine(renderer, tex, x1, y1, x2, y2, r, g, b, a, width)
    if a == nil or a <= 0 then return end
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.01 then return end
    width = math.max(1, math.floor(tonumber(width) or 1))
    if width == 1 then
        renderer:renderline(tex, x1, y1, x2, y2, r, g, b, a)
        return
    end
    local nx, ny = -dy / length, dx / length
    local half = (width - 1) / 2
    for i = 0, width - 1 do
        local offset = i - half
        renderer:renderline(tex, x1 + nx * offset, y1 + ny * offset,
            x2 + nx * offset, y2 + ny * offset, r, g, b, a)
    end
end

local function travelSpeed(config)
    return clamp((tonumber(config.speed) or BASE.speed) * M.speedScale, M.minSpeed, M.maxSpeed)
end

local function muzzleOf(body, targetX, targetY)
    if body == nil then return nil end
    local x, y, z = nil, nil, nil
    pcall(function() x, y, z = body:getX(), body:getY(), body:getZ() end)
    if x == nil or y == nil or z == nil then return nil end
    local tX, tY = tonumber(targetX), tonumber(targetY)
    local fX, fY = nil, nil
    if tX ~= nil and tY ~= nil then
        local dx, dy = tX - x, tY - y
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 0.001 then fX, fY = dx / length, dy / length end
    end
    if fX == nil then
        local angle = nil
        pcall(function() angle = tonumber(body:getAnimAngleRadians()) end)
        if angle ~= nil then fX, fY = math.sin(angle), -math.cos(angle) end
    end
    if fX == nil or fY == nil then return nil end
    local forward = M.muzzle
    local weapon = nil
    pcall(function() weapon = body:getPrimaryHandItem() end)
    if weapon ~= nil then
        local twoHanded = false
        pcall(function() twoHanded = weapon:isTwoHandWeapon() == true end)
        if twoHanded then forward = M.muzzleTwo end
    end
    return x + fX * forward, y + fY * forward, z + M.height
end

function M.config(ammoId)
    if type(ammoId) ~= "string" or ammoId == "" then return BASE end
    local config = AMMO[ammoId]
    if config ~= nil then return config end
    if warned[ammoId] ~= true then
        warned[ammoId] = true
        log("tracer default config for " .. tostring(ammoId))
    end
    return BASE
end

function M.spawn(sx, sy, sz, ax, ay, az, ammoId, count, spread, kind, muzzle)
    local x0, y0, z0 = tonumber(sx), tonumber(sy), tonumber(sz)
    local x1, y1, z1 = tonumber(ax), tonumber(ay), tonumber(az)
    if x0 == nil or y0 == nil or z0 == nil or x1 == nil or y1 == nil or z1 == nil then return 0 end

    local dx, dy = x1 - x0, y1 - y0
    local horiz = math.sqrt(dx * dx + dy * dy)
    if horiz < 0.001 then return 0 end

    local config = M.config(ammoId)
    local shots = math.floor(tonumber(count) or 1)
    if shots < 1 then shots = 1 end
    if shots > M.cap then shots = M.cap end

    local spreadDeg = shots > 1 and M.cone or 0
    local bearing = math.atan2(dy, dx)
    local muzzleX, muzzleY, muzzleZ = nil, nil, nil
    if muzzle ~= nil then
        muzzleX = tonumber(muzzle.x)
        muzzleY = tonumber(muzzle.y)
        muzzleZ = tonumber(muzzle.z)
    end
    if muzzleX == nil or muzzleY == nil or muzzleZ == nil then
        muzzleX = x0 + math.cos(bearing) * M.muzzle
        muzzleY = y0 + math.sin(bearing) * M.muzzle
        muzzleZ = z0 + M.height
    else
        dx, dy = x1 - muzzleX, y1 - muzzleY
        horiz = math.sqrt(dx * dx + dy * dy)
        if horiz < 0.001 then return 0 end
        bearing = math.atan2(dy, dx)
    end
    local aimZ = z1 + M.height
    if shots > 1 then
        local fanJitter = 0
        pcall(function() fanJitter = ((tonumber(ZombRand(1000)) or 500) / 999 - 0.5) * M.fanJitter end)
        bearing = bearing + fanJitter * math.pi / 180
    end
    local step = spreadDeg / math.max(1, shots - 1)
    local speed = travelSpeed(config)
    local headLen = math.max(config.plen or 0, M.headLength)
    local born = nowMs()
    local made = 0

    for i = 1, shots do
        local jitter = 0
        pcall(function() jitter = ((tonumber(ZombRand(1000)) or 500) / 999 - 0.5) * M.jitter end)
        local offset = (i - (shots + 1) / 2) * step + jitter
        local angle = bearing + offset * math.pi / 180
        local ex = muzzleX + math.cos(angle) * horiz
        local ey = muzzleY + math.sin(angle) * horiz
        local ez = aimZ
        local vx, vy, vz = ex - muzzleX, ey - muzzleY, ez - muzzleZ
        local dist = math.sqrt(vx * vx + vy * vy + vz * vz)
        if dist > 0.001 then
            if #live >= M.max then table.remove(live, 1) end
            live[#live + 1] = {
                sx = muzzleX, sy = muzzleY, sz = muzzleZ,
                dirx = vx / dist, diry = vy / dist, dirz = vz / dist,
                dist = dist, born = born, speed = speed, headLen = headLen,
                config = config, kind = kind,
            }
            made = made + 1
        end
    end

    if made > 0 then
        lastAmmo = ammoId
        if not spawnLogged then
            spawnLogged = true
            log("first shot: ammo=" .. tostring(ammoId) .. " config="
                .. (AMMO[ammoId] ~= nil and "vanilla" or "default") .. " tracers=" .. tostring(made))
        end
    end
    return made
end

function M.shot(body, target, gun, kind)
    if body == nil or target == nil or gun == nil then return false end
    local bx, by, bz = nil, nil, nil
    local tx, ty, tz = nil, nil, nil
    pcall(function() bx, by, bz = body:getX(), body:getY(), body:getZ() end)
    pcall(function() tx, ty, tz = target:getX(), target:getY(), target:getZ() end)
    if bx == nil or tx == nil then return false end
    local mx, my, mz = muzzleOf(body, tx, ty)
    local muzzle = nil
    if mx ~= nil then muzzle = { x = mx, y = my, z = mz } end
    if not muzzleLogged then
        muzzleLogged = true
        log("first muzzle: " .. (muzzle ~= nil and "computed" or "fixed"))
    end
    local made = M.spawn(bx, by, bz, tx, ty, tz, gun.ammoTypeId,
        gun.projectileCount or 1, gun.projectileSpread or 1, kind, muzzle)
    return made > 0
end

function M.shotAt(args)
    if type(args) ~= "table" then return false end
    local muzzle = nil
    if tonumber(args.mx) ~= nil and tonumber(args.my) ~= nil and tonumber(args.mz) ~= nil then
        muzzle = { x = args.mx, y = args.my, z = args.mz }
    end
    local made = M.spawn(args.sx, args.sy, args.sz, args.ax, args.ay, args.az,
        args.ammoTypeId, args.pellets or 1, args.spread or 1, args.kind, muzzle)
    return made > 0
end

function M.tick()
    local n = #live
    if n == 0 then return end
    local now = nowMs()
    for i = n, 1, -1 do
        local entry = live[i]
        if entry == nil then
            table.remove(live, i)
        else
            local age = now - entry.born
            local nose = age / 1000 * entry.speed
            if nose >= entry.dist + entry.headLen or age > M.maxMs then
                table.remove(live, i)
            end
        end
    end
end

function M.render()
    local n = #live
    if n == 0 then return end
    if type(isServer) == "function" and isServer() then return end
    if type(isIngameState) == "function" and not isIngameState() then return end
    local tex = whiteTexture()
    if tex == nil then return end
    local renderer = nil
    pcall(function() renderer = getRenderer() end)
    if renderer == nil or renderer.renderline == nil then
        if not rendererWarned then
            rendererWarned = true
            log("tracer renderer unavailable")
        end
        return
    end
    if not screenReady() then
        if not screenWarned then
            screenWarned = true
            log("tracer screen projection unavailable")
        end
        return
    end

    if not drawLogged then
        drawLogged = true
        log("first draw: tracers=" .. tostring(n))
    end

    local zoom, ox, oy = view()
    local now = nowMs()
    for i = 1, n do
        local entry = live[i]
        if entry ~= nil then
            local config = entry.config
            local age = math.max(0, now - entry.born) / 1000
            local nose = math.min(entry.dist, age * entry.speed)
            local progress = entry.dist > 0 and nose / entry.dist or 1

            local pathA = clamp((config.patha or 0) * (1 - progress * (config.pathfade or 0)), 0, 1)
            if pathA > 0 then
                local ax, ay = toScreen(entry.sx, entry.sy, entry.sz, zoom, ox, oy)
                local bx, by = toScreen(entry.sx + entry.dirx * nose, entry.sy + entry.diry * nose,
                    entry.sz + entry.dirz * nose, zoom, ox, oy)
                drawLine(renderer, tex, ax, ay, bx, by,
                    config.pathr, config.pathg, config.pathb, pathA, M.pathWidth)
            end

            local streak = math.max(config.tlen or 0, M.streak)
            local tail = math.max(0, nose - streak)
            local trailA = clamp((config.ta or 0) * (1 - progress), 0, 1)
            if trailA > 0 and nose > tail then
                local ax, ay = toScreen(entry.sx + entry.dirx * tail, entry.sy + entry.diry * tail,
                    entry.sz + entry.dirz * tail, zoom, ox, oy)
                local bx, by = toScreen(entry.sx + entry.dirx * nose, entry.sy + entry.diry * nose,
                    entry.sz + entry.dirz * nose, zoom, ox, oy)
                drawLine(renderer, tex, ax, ay, bx, by,
                    config.tr, config.tg, config.tb, trailA, M.trailWidth)
            end

            local tip = math.min(entry.dist, nose + entry.headLen)
            local headA = clamp((config.pa or 0) * (1 - progress * (config.pfade or 0)), 0, 1)
            if headA > 0 and tip > nose then
                local ax, ay = toScreen(entry.sx + entry.dirx * nose, entry.sy + entry.diry * nose,
                    entry.sz + entry.dirz * nose, zoom, ox, oy)
                local bx, by = toScreen(entry.sx + entry.dirx * tip, entry.sy + entry.diry * tip,
                    entry.sz + entry.dirz * tip, zoom, ox, oy)
                drawLine(renderer, tex, ax, ay, bx, by,
                    config.pr, config.pg, config.pb, headA, M.headWidth)
            end
        end
    end
end

function M.selftest()
    local hook = renderHook
    local rendererReady = false
    pcall(function() rendererReady = type(getRenderer) == "function" and getRenderer() ~= nil end)
    return {
        hook = hook,
        renderer = rendererReady,
        texture = whiteTexture() ~= nil,
        screen = screenReady(),
        live = #live,
        lastAmmo = lastAmmo,
        config = lastAmmo ~= nil and AMMO[lastAmmo] ~= nil and "vanilla" or "default",
    }
end

local function onTick()
    local ok, err = pcall(M.tick)
    if not ok and tickErrors < 3 then
        tickErrors = tickErrors + 1
        log("tick error: " .. tostring(err))
    end
end

local function onRender()
    local ok, err = pcall(M.render)
    if not ok and renderErrors < 3 then
        renderErrors = renderErrors + 1
        log("render error: " .. tostring(err))
    end
end

if Events ~= nil and Events.OnPreUIDraw ~= nil then
    Events.OnPreUIDraw.Add(onRender)
    renderHook = "OnPreUIDraw"
elseif Events ~= nil and Events.OnPostRender ~= nil then
    Events.OnPostRender.Add(onRender)
    renderHook = "OnPostRender"
else
    log("no render hook available")
end

if Events ~= nil and Events.OnTick ~= nil then
    Events.OnTick.Add(onTick)
end

log("ready: hook=" .. tostring(renderHook))
