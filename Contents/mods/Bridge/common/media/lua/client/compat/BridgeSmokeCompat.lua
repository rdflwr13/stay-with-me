BridgeSmokeCompat = BridgeSmokeCompat or {}
local B = BridgeSmokeCompat

B.particles = {}
B.MAX_PARTICLES = 14
B.FRAMES = 8
B.FAMILIES = 3

local function log(text)
    if BridgeLog ~= nil and type(BridgeLog.on) == "function" and BridgeLog.on() then
        print("[BridgeSmoke] " .. tostring(text))
    end
end

function B.ready()
    if CigaretteSmoke == nil then return false end
    if CigaretteSmoke.initialized ~= true then return false end
    if type(CigaretteSmoke.mouthSpawnPos) ~= "function" then return false end
    if type(CigaretteSmoke.textures) ~= "table" then return false end
    if CigaretteSmoke.textures[1] == nil or CigaretteSmoke.textures[1][1] == nil then return false end
    return true
end

local function wind()
    local wx, wy = 0, 0
    pcall(function()
        local c = getClimateManager()
        if c == nil then return end
        local angle = c:getWindAngleRadians() or 0
        local speed = c:getWindSpeedMovement() or 0
        wx = -math.cos(angle) * speed
        wy = -math.sin(angle) * speed
    end)
    return wx, wy
end

function B.puff(body)
    if not B.ready() then return false end
    if body == nil then return false end
    local x, y, z, facingAway, steepAway, sitting, dir = CigaretteSmoke.mouthSpawnPos(body)
    if x == nil or dir == nil then return false end
    local count = CigaretteSmoke.PARTICLES_PER_PUFF or 2
    for _ = 1, count do
        if #B.particles >= B.MAX_PARTICLES then break end
        local side = 0
        pcall(function() side = ZombRandFloat(-CigaretteSmoke.MOUTH_SIDE_JITTER, CigaretteSmoke.MOUTH_SIDE_JITTER) end)
        local px = x + (-dir:getY()) * side
        local py = y + dir:getX() * side
        local push = CigaretteSmoke.EXHALE_PUSH or 0.65
        pcall(function() push = push * ZombRandFloat(0.75, 1.25) end)
        local life = 2.0
        pcall(function() life = ZombRandFloat(CigaretteSmoke.PARTICLE_LIFE_MIN, CigaretteSmoke.PARTICLE_LIFE_MAX) end)
        local family = 1
        pcall(function() family = ZombRand(1, B.FAMILIES + 1) end)
        local baseSize = CigaretteSmoke.BASE_SIZE or 34.0
        pcall(function() baseSize = baseSize * ZombRandFloat(0.82, 1.15) end)
        local outside = false
        pcall(function() outside = body:isOutside() == true end)
        local phase = 0
        pcall(function() phase = ZombRandFloat(0, math.pi * 2) end)
        B.particles[#B.particles + 1] = {
            x = px,
            y = py,
            z = z,
            vx = dir:getX() * push,
            vy = dir:getY() * push,
            age = 0,
            life = life,
            family = family,
            frame = 1,
            frameTimer = 0,
            frameStep = 0.12,
            baseSize = baseSize,
            phase = phase,
            outside = outside,
            facingAway = facingAway == true,
        }
    end
    return true
end

function B.tick()
    if not B.ready() then
        if #B.particles > 0 then B.particles = {} end
        return
    end
    if #B.particles == 0 then return end
    local dt = 0.033
    pcall(function() dt = getGameTime():getRealworldSecondsSinceLastUpdate() end)
    dt = tonumber(dt) or 0.033
    if dt < 0 then dt = 0 elseif dt > 0.30 then dt = 0.30 end
    local wx, wy = wind()
    local drag = CigaretteSmoke.DRAG_PER_SEC or 0.45
    local rise = CigaretteSmoke.RISE_SPEED or 0.12
    local backRise = CigaretteSmoke.BACK_RISE_SPEED or 0.05
    local windInf = CigaretteSmoke.WIND_INFLUENCE or 0.42
    local i = #B.particles
    while i >= 1 do
        local p = B.particles[i]
        p.age = p.age + dt
        local keep = drag ^ dt
        local px, py = 0, 0
        if p.outside then px, py = wx, wy end
        p.vx = p.vx * keep + px * windInf * (1 - keep)
        p.vy = p.vy * keep + py * windInf * (1 - keep)
        local drift = math.sin(p.age * 2.1 + p.phase) * 0.010
        local drift2 = math.cos(p.age * 1.7 + p.phase * 1.3) * 0.010
        p.x = p.x + (p.vx + drift) * dt
        p.y = p.y + (p.vy + drift2) * dt
        local r = p.facingAway and backRise or rise
        local climb = p.age / 0.6
        if climb < 0.15 then climb = 0.15 elseif climb > 1.0 then climb = 1.0 end
        p.z = p.z + r * climb * dt
        p.frameTimer = p.frameTimer + dt
        if p.frameTimer >= p.frameStep and p.frame < B.FRAMES then
            p.frameTimer = 0
            p.frame = p.frame + 1
        end
        if p.age >= p.life then
            table.remove(B.particles, i)
        end
        i = i - 1
    end
end

local function smoothstep(t)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return t * t * (3 - 2 * t)
end

local function alphaOf(p)
    local t = p.age / p.life
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    if t < 0.12 then return smoothstep(t / 0.12) end
    return 1.0 - smoothstep((t - 0.12) / 0.88)
end

function B.render()
    if not B.ready() then return end
    if #B.particles == 0 then return end
    local viewer = nil
    pcall(function() viewer = getSpecificPlayer(0) end)
    if viewer == nil then return end
    local viewDist = CigaretteSmoke.VIEW_DISTANCE or 16.0
    local peak = CigaretteSmoke.PEAK_ALPHA or 0.75
    for i = 1, #B.particles do
        local p = B.particles[i]
        local tex = CigaretteSmoke.textures[p.family] and CigaretteSmoke.textures[p.family][p.frame]
        if tex ~= nil then
            local dx = p.x - viewer:getX()
            local dy = p.y - viewer:getY()
            if dx * dx + dy * dy <= viewDist * viewDist then
                local t = p.age / p.life
                if t < 0 then t = 0 elseif t > 1 then t = 1 end
                local size = p.baseSize * (0.70 + 0.55 * smoothstep(t))
                local alpha = alphaOf(p) * peak
                if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
                pcall(function()
                    IsoSprite.renderTextureWithDepth(tex, size, size, 1, 1, 1, alpha,
                        p.x, p.y, p.z - (size * 0.5) / (96.0 * Core.getTileScale()))
                end)
            end
        end
    end
end

if Events ~= nil and not B._hooked then
    B._hooked = true
    if Events.OnTick ~= nil then Events.OnTick.Add(B.tick) end
    if Events.OnPostRender ~= nil then Events.OnPostRender.Add(B.render) end
end
