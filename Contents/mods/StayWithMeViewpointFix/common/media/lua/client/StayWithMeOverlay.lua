local TAG = "[SWMViewpoint] "

local function projection()
    local direct = rawget(_G, "Projection")
    if type(direct) == "table" and type(direct.project) == "function" then return direct end
    local pkg = rawget(_G, "swmviewpointfix")
    if type(pkg) == "table" then
        local cls = pkg.Projection
        if type(cls) == "table" and type(cls.project) == "function" then return cls end
    end
    return nil
end

local function install()
    if Bridge == nil or type(Bridge.screenPoint) ~= "function" then return false end
    if Bridge.screenProject ~= nil then return true end
    local proj = projection()
    if proj == nil then return false end
    Bridge.screenProject = function(pn, x, y, z, lift)
        local ok, visible = pcall(proj.project, x, y, z, lift or 0)
        if not ok or visible ~= true then return nil end
        local gx, gy = nil, nil
        pcall(function() gx = proj.projectX() end)
        pcall(function() gy = proj.projectY() end)
        if gx == nil or gy == nil then return nil end
        return gx, gy
    end
    print(TAG .. "world-to-screen projection installed")
    return true
end

local tries = 0
local function retry()
    if install() then
        if Events ~= nil and Events.OnTick ~= nil then pcall(function() Events.OnTick.Remove(retry) end) end
        return
    end
    tries = tries + 1
    if tries == 1 then
        print(TAG .. "waiting: Bridge.screenPoint=" .. tostring(Bridge ~= nil and type(Bridge.screenPoint))
            .. " Projection=" .. tostring(projection() ~= nil))
    end
    if tries > 600 then
        print(TAG .. "gave up: Bridge.screenPoint=" .. tostring(Bridge ~= nil and type(Bridge.screenPoint))
            .. " Projection=" .. tostring(projection() ~= nil))
        if Events ~= nil and Events.OnTick ~= nil then pcall(function() Events.OnTick.Remove(retry) end) end
    end
end

if not install() then
    if Events ~= nil and Events.OnGameStart ~= nil then Events.OnGameStart.Add(install) end
    if Events ~= nil and Events.OnTick ~= nil then Events.OnTick.Add(retry) end
end
