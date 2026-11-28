-- Bridge commands for AI agents: per-command replies, help, waiting on a condition,
-- screenshots, the companion profile, giving her items, and world events.
-- BridgeMain calls BridgeAgent.run from Bridge.run, BridgeAgent.result after each command,
-- and BridgeAgent.poll before reading in.txt.

BridgeAgent = BridgeAgent or {}
BridgeAgent.RESULTS_FILE = "bridge/results.txt"
BridgeAgent.WATCH_EVERY = 120
BridgeAgent.ZOMBIE_RADIUS = 8
BridgeAgent.HURT_STEP = 5
BridgeAgent.wait = nil
BridgeAgent.watchAt = -99999
BridgeAgent.seen = {}
BridgeAgent.chatSynced = false

BridgeAgent.USAGE = {
    help = "help [command]",
    status = "status",
    diag = "diag [on|off|full]",
    events = "events on|off",
    verbose = "verbose on|off",
    trace = "trace [ticks]",
    logdump = "logdump",
    wait = "wait [ticks]  (with ticks: pause reading in.txt; without: companion stays)",
    waitfor = "waitfor arrived|idle|done|stuck|near [maxTicks]",
    scenario = "scenario <name>",
    assert = "assert [arrived|moving|stuck|nostuck|clear]",
    shot = "shot [name]",
    profile = "profile",
    sq = "sq <x> <y> [z]",
    doors = "doors [radius]",
    call = "call",
    goodbye = "goodbye",
    despawn = "despawn",
    come = "come",
    go = "go",
    rest = "rest",
    mode = "mode follow|wait|rest|home",
    stop = "stop",
    ["goto"] = "goto <x> <y> [z]",
    target = "target <x> <y> [z]",
    walk = "walk <type>|auto",
    keep = "keep behind",
    far = "far on|off",
    say = "say <text> | say hex:<utf8 hex>",
    voice = "voice [name]",
    quiet = "quiet on|off",
    sit = "sit",
    sleep = "sleep",
    stand = "stand",
    anim = "anim <name> [seconds]",
    name = "name <text>",
    combat = "combat bodyguard|escort|aggressive|backup|stayback",
    wounds = "wounds",
    heal = "heal [stop]",
    kills = "kills",
    look = "look [radius]",
    take = "take <n> [Type]",
    give = "give <Type> [count]",
    wear = "wear <Type>",
    job = "job <kind> <x> <y> [z]",
    chop = "chop",
    task = "task",
    chores = "chores",
    shower = "shower [start|stop]",
    bath = "bath [start|stop]",
    exercise = "exercise [stop]",
    read = "read status|books|start|stop",
    items = "items",
    home = "home [status|set|clear|away <hours>]",
    places = "places",
    rel = "rel",
    gift = "gift",
}

local HANDLED = { help = true, waitfor = true, shot = true, profile = true, give = true, wear = true }

function BridgeAgent.handles(cmd)
    return HANDLED[cmd] == true
end

local function owner()
    local p = nil
    pcall(function() p = BridgeData.owner() end)
    return p
end

local function tick()
    return Bridge ~= nil and (Bridge.tick or 0) or 0
end

local function allowed(cmd)
    local cfg = Bridge ~= nil and Bridge.CFG or nil
    if cfg == nil then return false end
    local dev = BridgeBuild ~= nil and BridgeBuild.test == true
    if dev and not Bridge.mp then return true end
    if dev and Bridge.mp and cfg.DEV_MP_COMMANDS ~= nil and cfg.DEV_MP_COMMANDS[cmd] == true then return true end
    return cfg.SAFE_COMMANDS ~= nil and cfg.SAFE_COMMANDS[cmd] == true
end

function BridgeAgent.result(num, res)
    local w = BridgeAgent.wait
    if w ~= nil and w.num == nil and string.sub(tostring(res), 1, 8) == "waitfor " then w.num = num end
    pcall(function()
        local text = string.gsub(tostring(res), "[\r\n]+", " ")
        local w = getFileWriter(BridgeAgent.RESULTS_FILE, true, true)
        w:write(tostring(num) .. " " .. text .. "\r\n")
        w:close()
    end)
end

function BridgeAgent.help(what)
    if what ~= nil and what ~= "" then
        if not allowed(what) then return "help: " .. what .. " is not available in this build" end
        return "usage: " .. (BridgeAgent.USAGE[what] or what)
    end
    local list = {}
    local cfg = Bridge ~= nil and Bridge.CFG or nil
    if cfg ~= nil and cfg.SAFE_COMMANDS ~= nil then
        for k in pairs(cfg.SAFE_COMMANDS) do
            if allowed(k) and BridgeAgent.USAGE[k] ~= nil then list[#list + 1] = k end
        end
    end
    table.sort(list)
    return "commands: " .. table.concat(list, " ") .. " | help <command> for usage"
end

local function bodyDistToOwner()
    local b, p = Bridge.body, owner()
    if b == nil or p == nil then return nil end
    local dx, dy = b:getX() - p:getX(), b:getY() - p:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function check(cond)
    if cond == "arrived" then
        return string.find(tostring(Bridge.run("0 assert arrived")), "PASS", 1, true) ~= nil
    elseif cond == "idle" then
        return string.find(tostring(Bridge.run("0 assert clear")), "PASS", 1, true) ~= nil
    elseif cond == "stuck" then
        return string.find(tostring(Bridge.run("0 assert stuck")), "PASS", 1, true) ~= nil
    elseif cond == "done" then
        return BridgeTask == nil or BridgeTask.active ~= true
    elseif cond == "near" then
        local d = bodyDistToOwner()
        return d ~= nil and d <= 3
    end
    return true
end

local CONDS = { arrived = true, idle = true, done = true, stuck = true, near = true }

function BridgeAgent.waitfor(cond, maxTicks)
    if cond == nil or not CONDS[cond] then return "usage: " .. BridgeAgent.USAGE.waitfor end
    local n = math.max(1, math.floor(tonumber(maxTicks) or 3600))
    BridgeAgent.wait = { cond = cond, start = tick(), num = nil }
    Bridge.cmdWaitUntil = tick() + n
    return "waitfor " .. cond .. " up to " .. n .. " ticks"
end

function BridgeAgent.pollWait()
    local w = BridgeAgent.wait
    if w == nil then return end
    local okCheck, met = pcall(check, w.cond)
    local took = tick() - w.start
    if okCheck and met == true then
        BridgeAgent.wait = nil
        Bridge.cmdWaitUntil = 0
        local text = "waitfor " .. w.cond .. " met after " .. took .. " ticks"
        Bridge.result = tostring(w.num or 0) .. ": " .. text
        BridgeAgent.result(w.num or 0, text)
    elseif Bridge.cmdWaitUntil == nil or tick() >= Bridge.cmdWaitUntil then
        BridgeAgent.wait = nil
        local text = "waitfor " .. w.cond .. " timeout after " .. took .. " ticks"
        Bridge.result = tostring(w.num or 0) .. ": " .. text
        BridgeAgent.result(w.num or 0, text)
    end
end

function BridgeAgent.shot(name)
    if type(takeScreenshot) ~= "function" then return "shot: not available in this game version" end
    local base = tostring(name or "")
    base = string.gsub(base, "[^%w_%-]", "")
    if base == "" then base = "swm-" .. tostring(tick()) end
    base = string.sub(base, 1, 48)
    local file = base .. ".png"
    local ok, err = pcall(function() takeScreenshot(file) end)
    if not ok then return "shot failed: " .. tostring(err) end
    return "shot: Zomboid/Screenshots/" .. file .. " (written on the next frame)"
end

function BridgeAgent.profile()
    local out = {}
    local function put(k, v) out[#out + 1] = k .. "=" .. tostring(v) end
    local function hex(v)
        local h = tostring(v)
        pcall(function() h = BridgeChat.toHex(tostring(v)) end)
        return "hex:" .. h
    end
    local name, gender = "?", "?"
    pcall(function() name = Bridge.companionName() end)
    pcall(function() gender = BridgeData.isMale(Bridge.store) and "male" or "female" end)
    put("companion", hex(name))
    put("gender", gender)
    local p = owner()
    local pname = "?"
    pcall(function() pname = p:getDisplayName() end)
    put("player", hex(pname))
    local pgender = "?"
    pcall(function() pgender = p:isFemale() and "female" or "male" end)
    put("player_gender", pgender)
    local lang = "?"
    pcall(function() lang = tostring(Translator.getLanguage()) end)
    put("language", lang)
    put("multiplayer", Bridge.mp == true)
    put("build", (BridgeBuild ~= nil and BridgeBuild.test == true) and "test" or "public")
    local ver = "?"
    pcall(function()
        local info = getModInfoByID("Bridge")
        if info ~= nil then ver = tostring(info:getModVersion()) end
    end)
    put("mod_version", ver)
    put("alive", Bridge.alive ~= nil and Bridge.alive() == true)
    return table.concat(out, " ")
end

local function matches(item, wanted)
    local ok, yes = pcall(function() return item:getFullType() == wanted or item:getType() == wanted end)
    return ok and yes == true
end

local function freeItems(inv, wanted, limit, player)
    local found = {}
    pcall(function()
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it ~= nil and matches(it, wanted) then
                local busy = false
                pcall(function() busy = it:isEquipped() == true end)
                if not busy and player ~= nil then
                    pcall(function() busy = player:isEquipped(it) == true or player:isEquippedClothing(it) == true end)
                end
                if not busy then
                    found[#found + 1] = it
                    if #found >= limit then break end
                end
            end
        end
    end)
    return found
end

function BridgeAgent.give(wanted, count)
    if wanted == nil or wanted == "" then return "usage: " .. BridgeAgent.USAGE.give end
    if not Bridge.alive() or Bridge.body == nil then return "give: no body" end
    local p = owner()
    if p == nil then return "give: no player" end
    local n = math.max(1, math.floor(tonumber(count) or 1))
    local list = freeItems(p:getInventory(), wanted, n, p)
    if #list == 0 then return "give: no free " .. wanted .. " in the player's main inventory" end
    local inv = Bridge.body:getInventory()
    local queued = 0
    for i = 1, #list do
        local it = list[i]
        local ok = pcall(function()
            ISTimedActionQueue.add(ISInventoryTransferAction:new(p, it, it:getContainer(), inv))
        end)
        if ok then queued = queued + 1 end
    end
    return "give: queued " .. queued .. " " .. wanted
end

function BridgeAgent.wear(wanted)
    if wanted == nil or wanted == "" then return "usage: " .. BridgeAgent.USAGE.wear end
    if not Bridge.alive() or Bridge.body == nil then return "wear: no body" end
    if BridgeInventory == nil or type(BridgeInventory.wearOnHer) ~= "function" then return "wear: not loaded" end
    local p = owner()
    if p == nil then return "wear: no player" end
    local list = freeItems(Bridge.body:getInventory(), wanted, 1, nil)
    if #list == 0 then list = freeItems(p:getInventory(), wanted, 1, p) end
    if #list == 0 then return "wear: no " .. wanted .. " with her or in the player's main inventory" end
    local ok, res = pcall(function() return BridgeInventory.wearOnHer(p, list[1], nil) end)
    if not ok then return "wear failed: " .. tostring(res) end
    return "wear: " .. (res == true and "started " or "refused ") .. wanted
end

function BridgeAgent.run(cmd, parts, line)
    if cmd == "help" then return BridgeAgent.help(parts[3]) end
    if cmd == "waitfor" then return BridgeAgent.waitfor(parts[3], parts[4]) end
    if cmd == "shot" then return BridgeAgent.shot(parts[3]) end
    if cmd == "profile" then return BridgeAgent.profile() end
    if cmd == "give" then return BridgeAgent.give(parts[3], parts[4]) end
    if cmd == "wear" then return BridgeAgent.wear(parts[3]) end
    return cmd .. ": unknown"
end

local function event(kind, text)
    if Bridge ~= nil and type(Bridge.bridgeEvent) == "function" then Bridge.bridgeEvent(kind, text) end
end

local function zombiesNear(p)
    local n = 0
    pcall(function()
        local list = getCell():getZombieList()
        local px, py, pz = p:getX(), p:getY(), math.floor(p:getZ())
        local r2 = BridgeAgent.ZOMBIE_RADIUS * BridgeAgent.ZOMBIE_RADIUS
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= Bridge.body and math.floor(z:getZ()) == pz then
                local dx, dy = z:getX() - px, z:getY() - py
                if dx * dx + dy * dy <= r2 and not z:isDead() then
                    local ours = false
                    pcall(function() ours = BridgeInventory.isMarked(z) == true end)
                    if not ours then pcall(function() ours = BridgeData.foreign(z) == true end) end
                    if not ours then n = n + 1 end
                end
            end
        end
    end)
    return n
end

function BridgeAgent.watch()
    if Bridge == nil or not Bridge.eventsOn then return end
    local s = BridgeAgent.seen
    local p = owner()
    if p == nil then return end

    local dead = false
    pcall(function() dead = p:isDead() == true end)
    if dead and not s.dead then event("world.player_dead", "") end
    s.dead = dead
    if dead then return end

    local hp = nil
    pcall(function() hp = p:getBodyDamage():getOverallBodyHealth() end)
    if hp ~= nil then
        if s.hp ~= nil and hp <= s.hp - BridgeAgent.HURT_STEP then
            event("world.player_hurt", string.format("%.0f", hp))
            s.hp = hp
        elseif s.hp == nil or hp > s.hp then
            s.hp = hp
        end
    end

    local car = false
    pcall(function() car = p:getVehicle() ~= nil end)
    if s.car ~= nil and car ~= s.car then event(car and "world.car_in" or "world.car_out", "") end
    s.car = car

    local alive = (Bridge.alive ~= nil and Bridge.alive() == true) or Bridge.parked == true
    if s.alive ~= nil and alive ~= s.alive then event(alive and "world.companion_here" or "world.companion_gone", "") end
    s.alive = alive

    local active = BridgeTask ~= nil and BridgeTask.active == true
    local kind = BridgeTask ~= nil and BridgeTask.kind or nil
    if s.task and not active then
        event("world.task_end", tostring(s.taskKind) .. " " .. tostring(BridgeTask ~= nil and BridgeTask.info or ""))
    elseif active and (not s.task or kind ~= s.taskKind) then
        event("world.task_start", tostring(kind))
    end
    s.task, s.taskKind = active, kind

    local zn = zombiesNear(p)
    if (s.zombies or 0) == 0 and zn > 0 then
        event("world.zombies_near", tostring(zn))
    elseif (s.zombies or 0) > 0 and zn == 0 then
        event("world.zombies_clear", "")
    end
    s.zombies = zn
end

function BridgeAgent.syncChat()
    if BridgeAgent.chatSynced or BridgeChat == nil then return end
    BridgeAgent.chatSynced = true
    local last = 0
    pcall(function()
        local r = getFileReader(BridgeChat.file, false)
        if r == nil then return end
        while true do
            local l = r:readLine()
            if l == nil then break end
            local n = tonumber(string.match(l, "^(%d+)"))
            if n ~= nil and n > last then last = n end
        end
        r:close()
    end)
    if last > (BridgeChat.seq or 0) then BridgeChat.seq = last end
end

function BridgeAgent.poll()
    BridgeAgent.syncChat()
    BridgeAgent.pollWait()
    if tick() - BridgeAgent.watchAt >= BridgeAgent.WATCH_EVERY then
        BridgeAgent.watchAt = tick()
        pcall(BridgeAgent.watch)
    end
end

Events.OnGameStart.Add(function() pcall(BridgeAgent.syncChat) end)
