










BridgeSocial = BridgeSocial or {}
BridgeSocial.last = {}
BridgeSocial.nagged = {}
BridgeSocial.nextRemark = nil
BridgeSocial.lastCheck = 0
BridgeSocial.sentAt = -9999
BridgeSocial.info = "none"

local CAP_F = 6
local CAP_R = 3
local COMBAT_KILL_STEP = 5
local COMBAT_DAILY_CAP = 3
local COMBAT_NEAR = 10
local REPEAT_SEC = { Chat = 30, Thanks = 45, Joke = 90, Compliment = 180, Comfort = 180, Flirt = 300, Hug = 300 }

local BUSY_DIST = 8
local AFTER_FIGHT = 1200
local DAY_HOURS = 3

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeSocial] " .. tostring(text)) end end
local function warn(text) print("[BridgeSocial] " .. tostring(text)) end

BridgeSocial.said = BridgeSocial.said or {}
function BridgeSocial.speak(key, fallback, gap)
    if key == nil then return end
    local now = 0
    pcall(function() now = Bridge.time or 0 end)
    if now - (BridgeSocial.said[key] or -99999) < (gap or 120) then return end
    BridgeSocial.said[key] = now
    local text = nil
    pcall(function() text = getTextOrNull("IGUI_NotAlone_Say_" .. tostring(key)) end)
    if text == nil or text == "" then text = fallback end
    pcall(function() if Bridge ~= nil and Bridge.speakText ~= nil then Bridge.speakText(text) end end)
end

local function hours()
    local h = 0
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h
end



local function rel()
    local r = BridgeData.relOf(Bridge.store)
    if Bridge.mp and r ~= nil then Bridge.localRel = r end
    return r
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end


local function popRel(df, dr)
    if BridgeSkills == nil or type(BridgeSkills.popRel) ~= "function" then return end
    if df ~= nil and df ~= 0 then BridgeSkills.popRel("Friend", df) end
    if dr ~= nil and dr ~= 0 then BridgeSkills.popRel("Romance", dr) end
end


BridgeSocial.poolSize = {}
local function lineCount(pool)
    local n = BridgeSocial.poolSize[pool]
    if n ~= nil then return n end
    n = 0
    for i = 1, 30 do
        local key = "IGUI_NotAlone_Soc_" .. pool .. "_" .. i
        local text = nil

        pcall(function() text = getTextOrNull(key, "", "") end)
        if text == nil or text == key or text == "" then break end
        n = i
    end
    BridgeSocial.poolSize[pool] = n
    return n
end




function BridgeSocial.lineKey(pool, i)
    local key = "IGUI_NotAlone_Soc_" .. pool .. "_" .. i
    local male = false
    pcall(function() male = BridgeData.isMale(Bridge.store) end)
    if not male then return key end
    local m = "IGUI_NotAlone_SocM_" .. pool .. "_" .. i
    local t = nil
    pcall(function() t = getTextOrNull(m, "", "") end)
    if t ~= nil and t ~= "" and t ~= m then return m end
    return key
end



BridgeSocial.recent = {}
function BridgeSocial.pick(pool, n)
    local recent = BridgeSocial.recent[pool] or {}
    BridgeSocial.recent[pool] = recent
    local keep = math.min(n - 1, math.floor(n * 0.6))
    local free = {}
    for i = 1, n do
        local used = false
        for _, j in ipairs(recent) do if j == i then used = true end end
        if not used then free[#free + 1] = i end
    end
    if #free == 0 then free = { 1 + ZombRand(n) } end
    local i = free[1 + ZombRand(#free)]
    recent[#recent + 1] = i
    while #recent > keep do table.remove(recent, 1) end
    return i
end



function BridgeSocial.sameAsLast(text)
    local last = Bridge ~= nil and Bridge.lastSpokeText or nil
    if text == nil or last == nil then return false end
    local function norm(s) return (string.lower(tostring(s)):gsub("[%.!%?]+$", "")) end
    return norm(text) == norm(last)
end

function BridgeSocial.line(pool)
    local n = lineCount(pool)
    if n == 0 then return nil end
    local text = nil
    for _ = 1, 4 do
        local i = BridgeSocial.pick(pool, n)
        pcall(function() text = getText(BridgeSocial.lineKey(pool, i), BridgeData.owner():getDisplayName()) end)
        if n < 2 or not BridgeSocial.sameAsLast(text) then break end
    end
    return text
end

local function say(pool)
    local text = BridgeSocial.line(pool)
    if text ~= nil then Bridge.speakText(text) end
    return text
end


local function gesture(anim, raw, force)
    if anim == nil or not Bridge.drivable() then return end
    local body = Bridge.body
    if BridgeMove.onPath() or Bridge.pose ~= nil then return end

    if BridgeFastForward ~= nil and BridgeFastForward.active() then return end

    local busy = false
    pcall(function() busy = BridgeHeal.active or BridgeWash.state ~= "idle" or BridgeWeapon.isOut(body) end)

    pcall(function() if #BridgeInventory.gestures > 0 or BridgeWeapon.busy() then busy = true end end)

    pcall(function() if not force and BridgeCar ~= nil and BridgeCar.holdsBody() then busy = true end end)
    if busy then return end
    pcall(function()
        local red = BridgeData.owner()
        body:faceLocationF(red:getX(), red:getY())
        body:setBumpType(raw and anim or ("Emote" .. anim))
    end)
end




function BridgeSocial.emote(anim, raw, force)
    gesture(anim, raw, force)
end




BridgeSocial.sentSign = nil
local function sign(r)
    return string.format("%d|%d|%d|%d|%d|%d|%.1f|%.1f|%.1f|%.1f|%d|%d", r.f, r.r, r.days, r.day, r.gainF, r.gainR,
        r.giftAt, r.askAt, r.healAt or 0, r.valuedAt or 0, r.giftF or 0, r.giftR or 0)
end
function BridgeSocial.save(now)
    if not Bridge.mp then return end
    local r = rel()
    if r == nil then return end
    local sg = sign(r)
    local important = sg ~= BridgeSocial.sentSign
    if not important and (Bridge.time - BridgeSocial.sentAt) < 18000 then return end
    BridgeSocial.sentSign = sg
    BridgeSocial.sentAt = Bridge.time
    pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "state", { rel = BridgeData.cleanRel(r) }) end)
end


local function rollDay(r)
    local day = math.floor(hours() / 24)
    if r.day == day then return end
    if r.seen > 0 and r.hours >= DAY_HOURS then
        r.days = r.days + 1
        r.f = clamp(r.f + 1, -100, 100)
    end
    r.day = day
    r.hours = 0
    r.gainF = 0
    r.gainR = 0
    r.combatKills = 0
    r.combatF = 0
    r.dressF = 0
    r.dressR = 0
    r.giftF = 0
    r.giftR = 0
    BridgeSocial.save(true)
end


local function tierBonus(r)
    local tier = nil
    pcall(function() tier = BridgeData.relTier(r) end)
    if tier == "Close" then return 3 end
    if tier == "Friend" then return 2 end
    if tier == "Pal" then return 1 end
    return 0
end

local GIFT_CAP_F, GIFT_CAP_R = 3, 1

local function capF(r, relaxed)
    return CAP_F + tierBonus(r) + ((relaxed == true) and 2 or 0)
end

local function capR(r, relaxed)
    return CAP_R + tierBonus(r) + ((relaxed == true) and 2 or 0)
end

local function gain(r, df, dr, relaxed)
    rollDay(r)
    if df > 0 then
        local room = capF(r, relaxed) - r.gainF
        if room <= 0 then df = 0 elseif df > room then df = room end
        r.gainF = r.gainF + df
    end
    if dr > 0 and not BridgeSocial.romanceOn() then dr = 0 end
    if dr > 0 then
        local room = capR(r, relaxed) - r.gainR
        if room <= 0 then dr = 0 elseif dr > room then dr = room end
        r.gainR = r.gainR + dr
    end
    r.f = clamp(r.f + df, -100, 100)
    r.r = clamp(r.r + dr, 0, 100)
    popRel(df, dr)

    BridgeSocial.save(true)
end


function BridgeSocial.deed(kind)
    local r = rel()
    if r == nil then return end
    if kind == "heal" then

        local now = hours()
        if now < (r.healAt or 0) then return end
        r.healAt = now + 6
        r.f = clamp(r.f + 2, -100, 100)
        popRel(2, 0)
    elseif kind == "hit" then
        r.f = clamp(r.f - 8, -100, 100)
        r.r = clamp(r.r - 5, 0, 100)
        popRel(-8, -5)
    end
    BridgeSocial.save(true)
end


function BridgeSocial.relCommand(sub, a, b)
    local r = rel()
    if r == nil then return "no rel" end
    if sub == nil or sub == "show" or sub == "status" then
        return string.format("rel f=%d r=%d days=%d hours=%.1f gain=%d/%d gift=%d/%d combat=%d/%d",
            r.f, r.r, r.days, r.hours, r.gainF, r.gainR, r.giftF or 0, r.giftR or 0, r.combatKills or 0, r.combatF or 0)
    end
    if sub == "reset" then
        r.f, r.r = 0, 0
        r.days, r.hours = 0, 0
        r.gainF, r.gainR = 0, 0
        r.giftF, r.giftR = 0, 0
        r.combatKills, r.combatF = 0, 0
        BridgeSocial.save(true)
        return "rel reset f=0 r=0"
    end
    if sub == "add" or sub == "remove" then
        local df = tonumber(a)
        if df == nil then return "rel " .. sub .. " needs a number: rel " .. sub .. " <friendly> [romance]" end
        local dr = tonumber(b) or 0
        if sub == "remove" then df, dr = -df, -dr end
        local bf, br = r.f, r.r
        r.f = clamp(r.f + df, -100, 100)
        r.r = clamp(r.r + dr, 0, 100)
        popRel(r.f - bf, r.r - br)
        BridgeSocial.save(true)
        return string.format("rel f=%d r=%d", r.f, r.r)
    end
    if sub == "set" then
        local f = tonumber(a)
        if f == nil then return "rel set needs a number: rel set <friendly> [romance]" end
        local bf, br = r.f, r.r
        r.f = clamp(f, -100, 100)
        local rr = tonumber(b)
        if rr ~= nil then r.r = clamp(rr, 0, 100) end
        popRel(r.f - bf, r.r - br)
        BridgeSocial.save(true)
        return string.format("rel f=%d r=%d", r.f, r.r)
    end
    if sub == "gift" or sub == "gifts" then return BridgeSocial.giftCommand("show") end
    if sub == "giftreset" then return BridgeSocial.giftCommand("reset") end
    if sub == "cooldown" or sub == "cooldowns" then return BridgeSocial.giftCommand("cooldown") end
    if sub == "nextday" or sub == "newday" then return BridgeSocial.giftCommand("nextday") end
    if sub == "forget" then return BridgeSocial.giftCommand("forget", a) end
    if sub == "list" then return BridgeSocial.giftCommand("list") end
    if sub == "preview" then return BridgeSocial.giftCommand("preview", a) end
    return "rel [show | add <f> [r] | remove <f> [r] | set <f> [r] | reset | giftreset | cooldown | nextday | forget [type] | list | preview [type]]"
end



function BridgeSocial.romanceOn()
    local on = true
    pcall(function() on = BridgeData.optionOf(Bridge.store, "romance") end)
    return on
end

function BridgeSocial.romanceOpen(r)
    return r ~= nil and r.f >= 30 and r.days >= 2 and BridgeSocial.romanceOn()
end










BridgeSocial.DRESS = {
    jewel = { f = 3, r = 1, pool = "DressJewel" },
    cloth = { f = 1, r = 0, pool = "DressCloth" },
}






BridgeSocial.MALE_DRESS = {
    DressWatch = { f = 3, r = 1, types = { "WristWatch_" } },
    DressTags = { f = 3, r = 1, types = { "Necklace_DogTag" } },
    DressShades = { f = 1, r = 0, types = { "Glasses_Sun", "Glasses_Aviators" } },
    DressJewel = { f = 1, r = 0 },
}
BridgeSocial.MALE_RECEIVE = {
    { pool = "ReceiveSmokes", f = 2, r = 0, types = { "CigarettePack", "CigaretteCarton", "CigaretteSingle",
        "CigaretteRolled", "Cigar", "Cigarillo", "SmokingPipe", "TobaccoLoose", "TobaccoChewing", "TobaccoDried" },
        skip = { "CigarBox", "CigaretteRollingPapers" } },
    { pool = "ReceiveTool", f = 2, r = 0, types = { "Hammer", "Screwdriver", "Wrench", "PipeWrench", "Pliers", "Saw",
        "Multitool", "Toolbox", "Lighter", "Lighter_Battery" }, exact = { Hammer = true, Saw = true, Lighter = true } },
    { pool = "ReceiveGame", f = 2, r = 1, types = { "CardDeck", "Dice", "PokerChips", "ChessBlack", "ChessWhite",
        "Harmonica", "GuitarAcoustic", "GuitarElectric", "Baseball", "Football" },
        exact = { Football = true, Baseball = true } },
    { pool = "ReceiveRead", f = 1, r = 0, types = { "ComicBook", "Magazine", "Book" },
        skip = { "MagazineCrossword", "MagazineWordsearch", "Magazine_Childs", "Magazine_Teens", "Book_Childs" } },
}
BridgeSocial.MALE_BOOZE = { f = 1, r = 0 }

local function isMale()
    local m = false
    pcall(function() m = BridgeData.isMale(Bridge.store) end)
    return m
end
BridgeSocial.isMale = isMale

local function typeHas(t, list, exact)
    for _, pre in ipairs(list or {}) do
        if exact ~= nil and exact[pre] then
            if t == pre then return true end
        elseif string.sub(t, 1, #pre) == pre then
            return true
        end
    end
    return false
end


function BridgeSocial.maleDressPool(item)
    local t = ""
    pcall(function() t = tostring(item:getType()) end)
    for _, pool in ipairs({ "DressWatch", "DressTags", "DressShades" }) do
        if typeHas(t, BridgeSocial.MALE_DRESS[pool].types) then return pool end
    end
    return nil
end


function BridgeSocial.maleReceive(item)
    local t = ""
    pcall(function() t = tostring(item:getType()) end)
    for _, g in ipairs(BridgeSocial.MALE_RECEIVE) do
        if typeHas(t, g.types, g.exact) and not typeHas(t, g.skip) then return g end
    end
    return nil
end


BridgeSocial.DRESS_ENABLED = 1


BridgeSocial.DRESS_ON = {
    JEWEL  = 1,
    CLOTH  = 1,
    HAT    = 1,
    JACKET = 1,
    SHOES  = 1,
    BAG    = 1,
    SUIT   = 1,
    RUINED = 1,
}

local DRESS_CAP_F = 4
local DRESS_CAP_R = 1
local JEWEL_PLACES = { "RIGHT_MIDDLE_FINGER", "LEFT_MIDDLE_FINGER", "LEFT_RING_FINGER", "RIGHT_RING_FINGER",
                       "EARS", "EAR_TOP", "NOSE", "NECKLACE", "NECKLACE_LONG", "LEFT_WRIST", "RIGHT_WRIST",
                       "BELLY_BUTTON" }




local function isJewel(item)
    local loc, cat = nil, nil
    pcall(function() loc = item:getBodyLocation() end)
    pcall(function() cat = item:getDisplayCategory() end)
    if loc == nil or ItemBodyLocation == nil or cat ~= "Accessory" then return false end
    for _, name in ipairs(JEWEL_PLACES) do
        if ItemBodyLocation[name] ~= nil and loc == ItemBodyLocation[name] then return true end
    end
    return false
end



local function presentable(item)
    local ok = true
    pcall(function() if item:isBroken() then ok = false end end)
    if ok and item.isBloody ~= nil then pcall(function() if item:isBloody() then ok = false end end) end
    if ok and item.isDirty ~= nil then pcall(function() if item:isDirty() then ok = false end end) end
    if ok and item.getHolesNumber ~= nil then pcall(function() if item:getHolesNumber() > 0 then ok = false end end) end
    return ok
end




function BridgeSocial.dressPool(item)
    if not presentable(item) then
        local broken = false
        pcall(function()
            broken = item:isBroken() or (item.getHolesNumber ~= nil and item:getHolesNumber() > 0)
        end)
        return broken and "DressBroken" or "DressDirty"
    end
    if isMale() then
        local mp = BridgeSocial.maleDressPool(item)
        if mp ~= nil then return mp end
    end
    if isJewel(item) then return "DressJewel" end
    local loc = nil
    pcall(function() loc = item:getBodyLocation() end)
    if loc ~= nil and ItemBodyLocation ~= nil then
        if loc == ItemBodyLocation.HAT or loc == ItemBodyLocation.FULL_HAT then return "DressHat" end
        if loc == ItemBodyLocation.JACKET or loc == ItemBodyLocation.JACKET_HAT
            or loc == ItemBodyLocation.SWEATER_HAT then return "DressJacket" end
        if loc == ItemBodyLocation.SHOES or loc == ItemBodyLocation.SOCKS then return "DressShoes" end
        if loc == ItemBodyLocation.BACK or loc == ItemBodyLocation.BAG then return "DressBag" end
        if loc == ItemBodyLocation.FULL then return "DressSuit" end
    end
    local bag = false
    pcall(function() bag = item:IsInventoryContainer() end)
    if bag then return "DressBag" end
    return "DressCloth"
end



local DRESS_CAT = {
    DressJewel = "JEWEL", DressCloth = "CLOTH", DressHat = "HAT", DressJacket = "JACKET",
    DressShoes = "SHOES", DressBag = "BAG", DressSuit = "SUIT",
    DressDirty = "RUINED", DressBroken = "RUINED",
    DressWatch = "JEWEL", DressTags = "JEWEL", DressShades = "CLOTH",
}

function BridgeSocial.dressOn(pool)
    if BridgeSocial.DRESS_ENABLED == 0 then return false end
    local cat = DRESS_CAT[pool]
    if cat ~= nil and BridgeSocial.DRESS_ON[cat] ~= 1 then return false end
    return true
end




function BridgeSocial.dressSay(pool)
    if pool == nil then return false end
    if not BridgeSocial.dressOn(pool) then return false end
    local fight = false
    pcall(function() fight = BridgeFight ~= nil and (BridgeFight.target ~= nil or BridgeFight.state == "swing") end)
    if fight then return false end
    local said = false


    pcall(function() said = BridgeMoments.say(pool, 5 * 60, "soft", "Dress") == true end)
    return said
end


function BridgeSocial.markGiven(item)
    pcall(function() item:getModData().bridgeGiven = true end)
end





function BridgeSocial.wornMemory()
    local st = Bridge.store
    if st == nil then return nil end
    if type(st.worn) ~= "table" then st.worn = {} end
    return st.worn
end


function BridgeSocial.wornBefore(item)
    local mem = BridgeSocial.wornMemory()
    if mem == nil or item == nil then return false end
    local t = nil
    pcall(function() t = tostring(item:getType()) end)
    return t ~= nil and mem[t] == true
end


function BridgeSocial.markWorn(item)
    local mem = BridgeSocial.wornMemory()
    if mem == nil or item == nil then return end
    pcall(function() mem[tostring(item:getType())] = true end)
end



function BridgeSocial.forget(item)
    if item == nil then return end
    pcall(function()
        local md = item:getModData()
        md.bridgeGiven = nil
        md.bridgeReceived = nil
        md.bridgeRecvPool = nil
    end)
end



BridgeSocial.RECEIVE_ENABLED = 1



local function mcall(obj, name)
    if obj == nil then return nil end
    local fn = nil
    pcall(function() fn = obj[name] end)
    if fn == nil then return nil end
    local ok, v = pcall(fn, obj)
    if ok then return v end
    return nil
end


local function itemTypeName(item)
    return tostring(mcall(item, "getType") or "")
end


local function nameHas(item, ...)
    local n = itemTypeName(item)
    for _, s in ipairs({ ... }) do
        if n:find(s, 1, true) ~= nil then return true end
    end
    return false
end




local STAIN_TYPES = { Broom = true, Broom_Twig = true, Mop = true, Sponge = true,
                      BathTowel = true, DishCloth = true, GrillBrush = true, ToiletBrush = true }
local function itemCleanStain(item)
    local ok = false
    pcall(function()
        ok = item ~= nil and ItemTag ~= nil and ItemTag.CLEAN_STAINS ~= nil
            and item:hasTag(ItemTag.CLEAN_STAINS) == true
    end)
    if ok then return true end
    return STAIN_TYPES[itemTypeName(item)] == true
end



local function fluidHas(item, fluid)
    local ok = false
    pcall(function()
        if item == nil or fluid == nil then return end
        local c = item:getFluidContainer()
        if c == nil then return end
        ok = c:contains(fluid) == true
    end)
    return ok
end






local function fluidName(item)
    local s = nil
    pcall(function()
        if item == nil then return end
        local c = item:getFluidContainer()
        if c == nil or c:isEmpty() == true then return end
        local p = c:getPrimaryFluid()
        if p ~= nil then s = p:getFluidTypeString() end
    end)
    return s
end

local FUEL_FLUIDS = { Petrol = true, Gasoline = true }
local CLEAN_FLUIDS = { Bleach = true, CleaningLiquid = true }




function BridgeSocial.recvMemory()
    local st = Bridge.store
    if st == nil then return nil end
    if type(st.recv) ~= "table" then st.recv = {} end
    return st.recv
end


function BridgeSocial.recvBefore(item)
    local mem = BridgeSocial.recvMemory()
    if mem == nil or item == nil then return false end
    local t = nil
    pcall(function() t = tostring(item:getType()) end)
    return t ~= nil and mem[t] == true
end


function BridgeSocial.markRecv(item)
    local mem = BridgeSocial.recvMemory()
    if mem == nil or item == nil then return end
    pcall(function() mem[tostring(item:getType())] = true end)
end


BridgeSocial.overSaid = false



function BridgeSocial.dropped(item)
    if BridgeSocial.RECEIVE_ENABLED == 0 then return false end
    local said = false
    pcall(function() said = BridgeMoments.say("CarryDrop", 5 * 60, "soft", "CarryDrop") == true end)
    return said
end



local function itemRotten(item)
    local r = mcall(item, "isRotten")
    if r ~= nil then return r == true end
    local food = mcall(item, "getFood")
    if food ~= nil then
        local fr = mcall(food, "isRotten")
        if fr ~= nil then return fr == true end
        local age = mcall(food, "getAge")
        local off = mcall(food, "getOffAge")
        if type(age) == "number" and type(off) == "number" and age > off then return true end
    end
    return false
end





local RECEIVE_CAT = {
    Ammo = "ReceiveAmmo",
    FirstAid = "ReceiveMeds", Bandage = "ReceiveMeds", Wound = "ReceiveMeds", Medical = "ReceiveMeds",
    Junk = "ReceiveJunk", Money = "ReceiveJunk",
    Tool = "ReceiveTool",
    Material = "ReceiveMaterial", RecipeResource = "ReceiveMaterial",
    FireSource = "ReceiveFireSource",
    LightSource = "ReceiveTorch",
    Electronics = "ReceiveElectronics",
    Communications = "ReceiveComms",
    Literature = "ReceiveRead", SkillBook = "ReceiveRead",
    Cartography = "ReceiveMap",
    Entertainment = "ReceiveFun",
    Sports = "ReceiveSports",
    Instrument = "ReceiveInstrument",
    Teddy = "ReceiveTeddy",
    Memento = "ReceiveMemento",
    Cooking = "ReceiveCooking",
    Gardening = "ReceiveGardening",
    Fishing = "ReceiveFishing",
    Trapping = "ReceiveTrapping",
    VehicleMaintenance = "ReceiveVehiclePart",
    Camping = "ReceiveCamping",
    Container = "ReceiveContainer",
    Furniture = "ReceiveFurniture",
    Paint = "ReceivePaint",
    Security = "ReceiveSecurity",
    WeaponPart = "ReceiveWeaponPart",
    Appearance = "ReceiveMakeup", MakeUp = "ReceiveMakeup",
    AnimalPart = "ReceiveAnimalPart", Ears = "ReceiveAnimalPart", Eye = "ReceiveAnimalPart", Tail = "ReceiveAnimalPart",
    Animal = "ReceiveAnimal", Bug = "ReceiveAnimal", Frog = "ReceiveAnimal", Bunny = "ReceiveAnimal",
    Fox = "ReceiveAnimal", Raccoon = "ReceiveAnimal", Duck = "ReceiveAnimal", Mole = "ReceiveAnimal",
    Goblin = "ReceiveAnimal", Spider = "ReceiveAnimal", Hedgehog = "ReceiveAnimal", Dog = "ReceiveAnimal",
    Beaver = "ReceiveAnimal", Badger = "ReceiveAnimal", Bear = "ReceiveAnimal", Squirrel = "ReceiveAnimal",
    Corpse = "ReceiveCorpse",
    Household = "ReceiveHousehold",

    Explosives = "ReceiveWeapon", BrokenWeapon = "ReceiveWeapon",
    ProtectiveGear = "ReceiveCloth", Accessory = "ReceiveItem",

    Cont = "ReceiveContainer", Bag = "ReceiveContainer", WaterContainer = "ReceiveContainer",
    Med = "ReceiveMeds", Drugs = "ReceiveCigs",
    Cook = "ReceiveCooking", Furn = "ReceiveFurniture", Mech = "ReceiveVehiclePart",
    Appear = "ReceiveMakeup", Collect = "ReceiveTeddy", Clean = "ReceiveCleaning", Fuel = "ReceiveFuel",
    Craft = "ReceiveMaterial", CraftCarp = "ReceiveMaterial", CraftMetal = "ReceiveMaterial", CraftTailor = "ReceiveMaterial",
    CraftElec = "ReceiveElectronics", Elec = "ReceiveElectronics",
    MediaA = "ReceiveFun", MediaV = "ReceiveFun",
    LitC = "ReceiveMap", LitE = "ReceiveRead", LitR = "ReceiveRead", LitS = "ReceiveRead", LitW = "ReceiveHousehold",
    SurCamp = "ReceiveCamping", SurFish = "ReceiveFishing", SurTrap = "ReceiveTrapping", SurBait = "ReceiveBait",
    Farm = "ReceiveGardening", FarmSeed = "ReceiveGardening",
    WepPart = "ReceiveWeaponPart", WepAmmoMag = "ReceiveAmmo",
    AnimalPartWeapon = "ReceiveAnimalPart",
    Key = "ReceiveItem", Misc = "ReceiveItem",
    WepMelee = "ReceiveWeapon", WepBomb = "ReceiveWeapon",
    WeapBlunt = "ReceiveWeapon", WeapBluntLong = "ReceiveWeapon",
    WeapBlade = "ReceiveWeapon", WeapBladeLong = "ReceiveWeapon", WeapSpear = "ReceiveWeapon",
    WepRange = "ReceiveGun",

    AppearC = "ReceiveMakeup", CookB = "ReceiveCooking", MediaG = "ReceiveFun", SurFarm = "ReceiveGardening",
    CraftAmmo = "ReceiveAmmo", CraftMas = "ReceiveMaterial",
    WepAmmo = "ReceiveAmmo", WepAmmoMagF = "ReceiveAmmo", WepMag = "ReceiveAmmo",
    WepBow = "ReceiveWeapon", WepShield = "ReceiveWeapon",
    Cloth = "ReceiveCloth", ClothA = "ReceiveCloth", ClothB = "ReceiveCloth", ClothM = "ReceiveCloth",
    ClothMisc = "ReceiveCloth", ClothAcc = "ReceiveCloth", ClothArm = "ReceiveCloth", ClothBody = "ReceiveCloth",
    ClothFeet = "ReceiveCloth", ClothHead = "ReceiveCloth", ClothJew = "ReceiveCloth", ClothLeg = "ReceiveCloth",
    ClothUnder = "ReceiveCloth", ClothBack = "ReceiveContainer", ClothBag = "ReceiveContainer",
    Casings = "ReceiveAmmo", WeaponMagazine = "ReceiveAmmo", GunMag = "ReceiveAmmo", FixedMag = "ReceiveAmmo",
    ReloadingTool = "ReceiveWeaponPart", GunClean = "ReceiveWeaponPart", Components = "ReceiveWeaponPart",
    WeaponConversion = "ReceiveWeaponPart",
    Devices = "ReceiveElectronics", PowerPlantParts = "ReceiveElectronics",
    Tuning = "ReceiveVehiclePart", TuningService = "ReceiveVehiclePart", VehicleMantenance = "ReceiveVehiclePart",
    Bulldog = "ReceiveVehiclePart", Cars = "ReceiveVehiclePart",
    CoolerBackpack = "ReceiveContainer", Moveable = "ReceiveFurniture",
    Tiles = "ReceivePaint", Wallpaper = "ReceivePaint", WoodStain = "ReceivePaint", Art = "ReceivePaint",
    Toy = "ReceiveFun", Curio = "ReceiveMemento", TTPlushie = "ReceiveTeddy",
    Tonic = "ReceiveMeds", TTTonic = "ReceiveMeds", FeminineHygiene = "ReceiveHousehold",
    Transmog = "ReceiveItem", TransmogHide = "ReceiveItem", SurvivalGear = "ReceiveItem",
    Box = "ReceiveItem", Mail = "ReceiveItem", TTMail = "ReceiveItem", Item = "ReceiveItem",
    TEST = "ReceiveItem", Horse = "ReceiveItem", Magic = "ReceiveItem", ZD = "ReceiveItem",
    VFXDistribution = "ReceiveItem",
}

local RECEIVE_GESTURE = {
    ReceiveRotten = "NoThankYou", ReceiveTreat = "Yes",
    ReceiveMeds = "Yes", ReceiveComms = "Yes", ReceiveInstrument = "Yes", ReceiveTeddy = "Yes",
    ReceiveMemento = "Yes", ReceiveGardening = "Yes", ReceiveAnimal = "Yes",
    ReceiveBattery = "Yes",
    ReceiveFun = "Clap", ReceiveSports = "Clap", ReceiveFishing = "Clap", ReceiveMakeup = "Clap",
    ReceiveWeaponPart = "NoThankYou", ReceiveCorpse = "NoThankYou",
    ReceiveCigs = "NoThankYou",
}

local VALUED = { ReceiveMeds = true, ReceiveMemento = true, ReceiveTeddy = true,
    ReceiveGardening = true, ReceiveInstrument = true }


local FIRE_TYPES = { MagnesiumFirestarter = true, DryFirestarterBlock = true, Flint = true,
    SteelAndFlint = true, Lighter = true, Lighter_Battery = true, Matches = true, Matchbox = true }

local function itemStartsFire(item)
    local t = itemTypeName(item)
    if FIRE_TYPES[t] then return true end
    return t:find("Firestarter", 1, true) ~= nil
end

local function itemIsBone(item)
    return nameHas(item, "AnimalBone", "Animal_Brain")
end

local function isUnderwear(item)
    local loc = nil
    pcall(function() loc = item:getBodyLocation() end)
    if loc == nil then return false end
    return string.lower(tostring(loc)):find("underwear", 1, true) ~= nil
end

local TOBACCO_TYPES = { CigarettePack = true, CigaretteCarton = true, CigaretteSingle = true,
    CigaretteRolled = true, Cigar = true, Cigarillo = true, Tobacco = true, TobaccoLoose = true,
    TobaccoChewing = true, TobaccoDried = true, SmokingPipe = true, SmokingPipe_Tobacco = true, Cigarettes = true }

local function isTobacco(item)
    if TOBACCO_TYPES[itemTypeName(item)] then return true end
    return tostring(mcall(item, "getDisplayCategory") or "") == "Drugs"
end

local BAIT_TYPES = { Worm = true, Cricket = true, Grasshopper = true, Cockroach = true, Maggots = true,
    Pillbug = true, Slug = true, Snail = true, Centipede = true, Millipede = true, Caterpillar = true,
    SawflyLarva = true, Termites = true, Leech = true, Leeches = true, Tadpole = true, BaitFish = true }

local function isBait(item)
    if BAIT_TYPES[itemTypeName(item)] then return true end
    if tostring(mcall(item, "getDisplayCategory") or "") == "SurBait" then return true end
    return nameHas(item, "Caterpillar", "Centipede", "Millipede")
end

local function itemIsTypeFlag(item, name)
    local yes = false
    pcall(function()
        yes = item ~= nil and item.isItemType ~= nil and ItemType ~= nil and ItemType[name] ~= nil
            and item:isItemType(ItemType[name]) == true
    end)
    return yes
end


-- Gift recognition is id + category based, not display-category only: mods such
-- as Better Containers rewrite an item's DisplayCategory (TweakItem), which would
-- otherwise defeat receivePool. Each receive pool is owned by exactly one gain
-- path: GIFT (here), MALE_RECEIVE (maleGift), or VALUED.
BridgeSocial.GIFT = {
    ReceiveTreat   = { f = 2, r = 0 },
    ReceiveFun     = { f = 2, r = 0 },
    ReceiveTeddy   = { f = 3, r = 1 },
    ReceiveMemento = { f = 3, r = 0 },
    ReceiveJewelry = { f = 3, r = 1 },
}
local GIFT_POOLS = {}
for giftPool in pairs(BridgeSocial.GIFT) do GIFT_POOLS[giftPool] = true end
BridgeSocial.GIFT_POOLS = GIFT_POOLS

-- Pools a male companion already gains from via maleGift (never also a gift).
local GIFT_MALE_OWNED = { ReceiveSmokes = true, ReceiveTool = true, ReceiveGame = true,
    ReceiveRead = true, ReceiveBooze = true }

-- Male dress pools own these worn items; keep them out of the carried-gift pool.
local JEWEL_SKIP = { "WristWatch_", "Necklace_DogTag", "Glasses_" }

local function itemCat(item)
    return string.lower(tostring(mcall(item, "getDisplayCategory") or ""))
end

local function catHas(cat, list)
    for _, s in ipairs(list) do
        if cat == s or string.find(cat, s, 1, true) ~= nil then return true end
    end
    return false
end

-- getTags() may be a Java collection with only some accessors exposed (some builds
-- expose size()/contains() but not get(int)), so probe defensively and never call a
-- missing method -- a bare nil call still logs an ERROR even inside pcall.
local function hasTagLike(item, needle)
    local yes = false
    local lower = string.lower(needle)
    pcall(function()
        if type(item.getTags) ~= "function" then return end
        local list = item:getTags()
        if list == nil then return end
        if type(list.contains) == "function" then
            local ok, hit = pcall(function() return list:contains(needle) end)
            if ok and hit == true then yes = true return end
            ok, hit = pcall(function() return list:contains(lower) end)
            if ok and hit == true then yes = true return end
            ok, hit = pcall(function() return list:contains("base:" .. lower) end)
            if ok and hit == true then yes = true return end
        end
        if type(list) == "table" and type(list.size) ~= "function" then
            for _, v in ipairs(list) do
                if string.find(string.lower(tostring(v)), lower, 1, true) ~= nil then yes = true return end
            end
            return
        end
        if type(list.size) == "function" and type(list.get) == "function" then
            local n = 0
            pcall(function() n = tonumber(list:size()) or 0 end)
            for i = 0, n - 1 do
                local s = nil
                pcall(function() s = list:get(i) end)
                if s ~= nil and string.find(string.lower(tostring(s)), lower, 1, true) ~= nil then
                    yes = true return
                end
            end
            return
        end
        local text = nil
        pcall(function() text = tostring(list) end)
        if text ~= nil and string.find(string.lower(text), lower, 1, true) ~= nil then yes = true end
    end)
    return yes
end

-- Jewelry is normally DisplayCategory "Accessory"; Better Containers moves it to
-- "ClothJew". Match on body location plus either category, with an id fallback.
local function isJewelGift(item)
    if typeHas(itemTypeName(item), JEWEL_SKIP) then return false end
    local loc = nil
    pcall(function() loc = item:getBodyLocation() end)
    if loc == nil or ItemBodyLocation == nil then return false end
    local place = false
    for _, name in ipairs(JEWEL_PLACES) do
        if ItemBodyLocation[name] ~= nil and loc == ItemBodyLocation[name] then place = true break end
    end
    if not place then return false end
    local cat = itemCat(item)
    if cat == "accessory" or cat == "clothjew" then return true end
    local t = string.lower(itemTypeName(item))
    return string.find(t, "jewel", 1, true) ~= nil or string.find(t, "earring", 1, true) ~= nil
        or string.find(t, "necklace", 1, true) ~= nil or string.find(t, "bracelet", 1, true) ~= nil
        or string.find(t, "pendant", 1, true) ~= nil or string.find(t, "choker", 1, true) ~= nil
end

-- Category names cover vanilla and Better Containers keys; type ids cover vanilla
-- and common mod items. Teddy is checked before memento because plushies carry the
-- memento tag too.
local TEDDY_CATS = { "teddy", "plush" }
local TEDDY_TYPES = { "ToyBear", "Teddy", "Plush" }
local MEMENTO_CATS = { "memento", "curio" }
local MEMENTO_TYPES = { "Memento", "Curio", "Keepsake", "Souvenir" }
local TOY_CATS = { "entertainment", "toy" }
local TOY_TYPES = { "CardDeck", "Dice", "PokerChips", "Chess", "BackgammonBoard", "CheckerBoard",
    "GamePiece", "Yoyo", "CatToy", "Bricktoys", "Doll", "Rubberducky", "PoolBall", "Basketball",
    "SoccerBall", "TennisBall", "GolfBall", "Baseball", "Football", "Dart", "Cube" }
local TOY_EXACT = { Dice = true, Cube = true, Dart = true, Baseball = true, Football = true,
    Basketball = true, SoccerBall = true, TennisBall = true, GolfBall = true, PoolBall = true,
    Yoyo = true, Doll = true }

-- Resolve the gift class for an item. Ids/categories win over the derived pool so a
-- recategorized item still gets the right class (and next day's first gift).
function BridgeSocial.giftPool(item, pool)
    if item == nil then return nil end
    if isMale() and BridgeSocial.maleReceive(item) ~= nil then return nil end
    if pool ~= nil and GIFT_MALE_OWNED[pool] then return nil end
    if isJewelGift(item) then return "ReceiveJewelry" end
    local t, cat = itemTypeName(item), itemCat(item)
    if typeHas(t, TEDDY_TYPES) or catHas(cat, TEDDY_CATS) then return "ReceiveTeddy" end
    if typeHas(t, MEMENTO_TYPES) or catHas(cat, MEMENTO_CATS) or hasTagLike(item, "memento") then
        return "ReceiveMemento"
    end
    if pool ~= nil and GIFT_POOLS[pool] then return pool end
    if typeHas(t, TOY_TYPES, TOY_EXACT) or catHas(cat, TOY_CATS) then return "ReceiveFun" end
    return nil
end

-- First gift only, per-day capped in giftF/giftR, scaled by relationship tier.
-- Returns "paid" when it granted affection, "full" when today's gift budget is
-- spent (the item is deliberately left unmarked so it can pay out later), "done"
-- when the item was already gifted, or nil for a non-gift.
function BridgeSocial.gift(item, pool)
    if item == nil or pool == nil or BridgeSocial.GIFT[pool] == nil then return nil end
    local r = rel()
    if r == nil then return nil end
    local given = false
    pcall(function() given = item:getModData().bridgeGiven == true end)
    if given then return "done" end
    rollDay(r)
    local g = BridgeSocial.GIFT[pool]
    local df = math.max(0, math.min(g.f, (GIFT_CAP_F + tierBonus(r)) - (r.giftF or 0)))
    local dr = 0
    if g.r > 0 and BridgeSocial.romanceOpen(r) then
        dr = math.max(0, math.min(g.r, (GIFT_CAP_R + tierBonus(r)) - (r.giftR or 0)))
    end
    if df <= 0 and dr <= 0 then
        log(string.format("gift %s held (budget full) f=%d r=%d", pool, r.f, r.r))
        return "full"
    end
    BridgeSocial.markGiven(item)
    r.giftF = (r.giftF or 0) + df
    r.giftR = (r.giftR or 0) + dr
    gain(r, df, dr)
    BridgeSocial.giftVersion = (BridgeSocial.giftVersion or 0) + 1
    log(string.format("gift %s +%d/+%d f=%d r=%d", pool, df, dr, r.f, r.r))
    return "paid"
end

-- What gifting this item would do right now, for the inventory tooltip.
-- nil when the item is not a gift. f/r are the base class values; effF/effR are
-- what is still left today after the daily cap; given = already gifted once;
-- capped = nothing left for it today.
function BridgeSocial.giftPreview(item)
    if item == nil or BridgeSocial.GIFT == nil then return nil end
    local r = rel()
    if r == nil then return nil end
    local pool = nil
    pcall(function()
        pool = BridgeSocial.giftPool(item, BridgeSocial.receivePool(item))
    end)
    if pool == nil or BridgeSocial.GIFT[pool] == nil then return nil end
    local g = BridgeSocial.GIFT[pool]
    rollDay(r)
    local given = false
    pcall(function() given = item:getModData().bridgeGiven == true end)
    local bonus = tierBonus(r)
    local effF = math.max(0, math.min(g.f, (GIFT_CAP_F + bonus) - (r.giftF or 0)))
    local effR = 0
    if g.r > 0 and BridgeSocial.romanceOpen(r) then
        effR = math.max(0, math.min(g.r, (GIFT_CAP_R + bonus) - (r.giftR or 0)))
    end
    local romanceOn = false
    pcall(function() romanceOn = BridgeSocial.romanceOn() == true end)
    return { pool = pool, f = g.f, r = g.r, effF = effF, effR = effR,
        given = given, capped = (not given) and effF <= 0 and effR <= 0, romanceOn = romanceOn }
end

-- Dev/test helpers for the gift system (rel/gift commands in in.txt).
local function eachInvItem(inv, fn)
    if inv == nil then return end
    pcall(function()
        local items = inv:getItems()
        if items == nil then return end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it ~= nil then fn(it) end
        end
    end)
end

local function giftInventories()
    local out = {}
    pcall(function()
        local red = BridgeData.owner()
        if red ~= nil then out[#out + 1] = red:getInventory() end
    end)
    pcall(function()
        if Bridge ~= nil and Bridge.alive() and Bridge.kind == "zombie" and Bridge.body ~= nil then
            out[#out + 1] = Bridge.body:getInventory()
        end
    end)
    return out
end

function BridgeSocial.giftCommand(sub, a, b)
    local r = rel()
    if r == nil then return "no rel" end
    sub = sub or "show"
    if sub == "show" or sub == "status" then
        rollDay(r)
        local bonus = tierBonus(r)
        local tier = "?"
        pcall(function() tier = BridgeData.relTier(r) end)
        return string.format("gift giftF=%d/%d giftR=%d/%d tier=%s day=%d",
            r.giftF or 0, GIFT_CAP_F + bonus, r.giftR or 0, GIFT_CAP_R + bonus, tostring(tier), r.day or 0)
    end
    if sub == "reset" or sub == "giftreset" then
        rollDay(r)
        r.giftF, r.giftR = 0, 0
        BridgeSocial.giftFullDay = nil
        BridgeSocial.save(true)
        return string.format("gift budget reset (giftF=0 giftR=0)")
    end
    if sub == "cooldown" or sub == "cooldowns" then
        BridgeSocial.last = {}
        BridgeSocial.nagged = {}
        BridgeSocial.talkFullDay = nil
        BridgeSocial.giftFullDay = nil
        return "talk/gift cooldowns cleared"
    end
    if sub == "nextday" or sub == "newday" then
        rollDay(r)
        r.gainF, r.gainR = 0, 0
        r.dressF, r.dressR = 0, 0
        r.giftF, r.giftR = 0, 0
        r.days = (r.days or 0) + 1
        BridgeSocial.talkFullDay = nil
        BridgeSocial.giftFullDay = nil
        BridgeSocial.save(true)
        return string.format("next day: days=%d, daily counters reset", r.days)
    end
    if sub == "forget" then
        local filter = a
        local lower = filter ~= nil and string.lower(filter) or nil
        local n = 0
        for _, inv in ipairs(giftInventories()) do
            eachInvItem(inv, function(it)
                local match = true
                if lower ~= nil then
                    local t = ""
                    pcall(function() t = string.lower(tostring(it:getType())) end)
                    match = string.find(t, lower, 1, true) ~= nil
                else
                    local flagged = false
                    pcall(function()
                        local md = it:getModData()
                        flagged = md.bridgeGiven == true or md.bridgeReceived == true
                    end)
                    match = flagged
                end
                if match then
                    pcall(BridgeSocial.forget, it)
                    n = n + 1
                end
            end)
        end
        local what = lower ~= nil and ("matching '" .. tostring(filter) .. "'") or "flagged"
        return "forgot " .. tostring(n) .. " " .. what .. " item(s)"
    end
    if sub == "list" or sub == "preview" then
        local want = (sub == "preview") and a or nil
        local lower = want ~= nil and string.lower(want) or nil
        local lines, n = {}, 0
        for _, inv in ipairs(giftInventories()) do
            eachInvItem(inv, function(it)
                if n < 12 then
                    local info = nil
                    pcall(function() info = BridgeSocial.giftPreview(it) end)
                    if info ~= nil then
                        local t = ""
                        pcall(function() t = tostring(it:getType()) end)
                        if lower == nil or string.find(string.lower(t), lower, 1, true) ~= nil then
                            local val = "+" .. tostring(info.f)
                            if info.r > 0 and info.romanceOn then val = val .. "/+" .. tostring(info.r) end
                            if info.given then val = val .. "(given)"
                            elseif info.capped then val = val .. "(full)" end
                            lines[#lines + 1] = t .. " " .. tostring(info.pool) .. " " .. val
                            n = n + 1
                        end
                    end
                end
            end)
        end
        if #lines == 0 then return "no gift items found" end
        return table.concat(lines, ", ")
    end
    return "gift [show | reset | cooldown | nextday | forget [type] | list | preview [type]]"
end


function BridgeSocial.receivePool(item)
    if item == nil then return "ReceiveItem" end

    if isMale() then
        local g = BridgeSocial.maleReceive(item)
        if g ~= nil then return g.pool end
    end

    if mcall(item, "getType") == "Battery" then return "ReceiveBattery" end



    if BridgeTorchShared ~= nil and BridgeTorchShared.isFlashlight ~= nil
        and BridgeTorchShared.isFlashlight(item) then
        local c = 1
        pcall(function() c = BridgeTorchShared.charge(item) end)
        if type(c) == "number" and c <= 0.0001 then return "ReceiveTorchEmpty" end
        return "ReceiveTorch"
    end

    if itemStartsFire(item) then return "ReceiveFireSource" end

    if itemIsBone(item) then return "ReceiveAnimalPart" end



    if itemCleanStain(item) then
        local weapon = false
        pcall(function() weapon = BridgeWeapon ~= nil and BridgeWeapon.isMelee ~= nil and BridgeWeapon.isMelee(item) end)
        return weapon and "ReceiveCleanWeapon" or "ReceiveCleaning"
    end



    local fname = fluidName(item)
    if (Fluid ~= nil and fluidHas(item, Fluid.Petrol)) or FUEL_FLUIDS[fname] then return "ReceiveFuel" end
    if (Fluid ~= nil and (fluidHas(item, Fluid.Bleach) or fluidHas(item, Fluid.CleaningLiquid)))
        or CLEAN_FLUIDS[fname] then
        return "ReceiveCleaner"
    end

    local gun = false
    pcall(function() gun = BridgeInventory ~= nil and BridgeInventory.isGun ~= nil and BridgeInventory.isGun(item) end)
    if gun then return "ReceiveGun" end

    local weapon = false
    pcall(function() weapon = BridgeWeapon ~= nil and BridgeWeapon.isMelee ~= nil and BridgeWeapon.isMelee(item) end)
    if weapon then return "ReceiveWeapon" end

    if not isMale() and isTobacco(item) then return "ReceiveCigs" end
    if isBait(item) then return "ReceiveBait" end

    local food = mcall(item, "IsFood") == true
    if food and itemRotten(item) then return "ReceiveRotten" end

    if mcall(item, "isWaterSource") == true then
        if mcall(item, "isTaintedWater") == true then return "ReceiveTainted" end
        return "ReceiveWater"
    end

    if food then
        if mcall(item, "isAlcoholic") == true then return "ReceiveBooze" end
        if nameHas(item, "Canned", "Jar", "Pickled") then return "ReceiveCanned" end
        if nameHas(item, "Candy", "Chocolate", "Crisps", "Granola", "Gum", "Cookie", "Coffee", "Cigarette", "Snack") then
            return "ReceiveTreat"
        end
        if mcall(item, "isCooked") == false
            and nameHas(item, "Meat", "Fish", "Chicken", "Beef", "Pork", "Venison", "Rabbit") then
            return "ReceiveRaw"
        end
        return "ReceiveFood"
    end

    if isJewelGift(item) then return "ReceiveJewelry" end

    if mcall(item, "IsClothing") == true then
        if not presentable(item) then
            local broken = false
            pcall(function()
                broken = item:isBroken() or (item.getHolesNumber ~= nil and item:getHolesNumber() > 0)
            end)
            return broken and "DressBroken" or "DressDirty"
        end
        if not isMale() and isUnderwear(item) then return "ReceiveUndies" end
        return "ReceiveCloth"
    end

    if nameHas(item, "Corpse") then return "ReceiveCorpse" end

    local cat = tostring(mcall(item, "getDisplayCategory") or "")
    if isMale() and cat == "Drugs" then return "ReceiveSmokes" end
    local pool = RECEIVE_CAT[cat]
    if pool ~= nil then return pool end

    if itemIsTypeFlag(item, "MEDICAL") then return "ReceiveMeds" end
    if itemIsTypeFlag(item, "CONTAINER") then return "ReceiveContainer" end
    if itemIsTypeFlag(item, "LITERATURE") then return "ReceiveRead" end
    if itemIsTypeFlag(item, "AMMO") then return "ReceiveAmmo" end
    if itemIsTypeFlag(item, "KEY") then return "ReceiveItem" end

    local w = mcall(item, "getActualWeight")
    if type(w) == "number" and w > 5 then return "ReceiveHeavy" end

    return "ReceiveItem"
end



function BridgeSocial.received(item)
    if item == nil then return false end


    local pool = BridgeSocial.receivePool(item)



    local got, lastPool = false, nil
    pcall(function()
        got = item:getModData().bridgeReceived == true
        lastPool = item:getModData().bridgeRecvPool
    end)
    if got and lastPool == pool then return false end

    -- Resolve the gift class and pay it before remembering the item. A gift that
    -- cannot pay because today's gift budget is spent is left unremembered so a
    -- later hand-over can still earn affection instead of being silently lost.
    local gift, giftStatus = nil, nil
    pcall(function() gift = BridgeSocial.giftPool(item, pool) end)
    if gift ~= nil then pcall(function() giftStatus = BridgeSocial.gift(item, gift) end) end
    local maleStatus = nil
    if isMale() then pcall(function() maleStatus = BridgeSocial.maleGift(item, pool) end) end
    local pendingGift = (giftStatus == "full") or (maleStatus == "full")

    if not pendingGift then
        pcall(function()
            item:getModData().bridgeReceived = true
            item:getModData().bridgeRecvPool = pool
        end)
    end

    if VALUED[pool] and not GIFT_POOLS[pool] then
        local r = rel()
        if r ~= nil then
            local now = hours()
            if now - (r.valuedAt or 0) >= 24 then
                r.valuedAt = now
                gain(r, 1, 0)
            end
        end
    end

    if not pendingGift then
        if pool ~= "ReceiveRotten" and pool ~= "ReceiveGun" and pool ~= "ReceiveWeapon"
            and pool ~= "ReceiveCleanWeapon"
            and pool ~= "ReceiveFuel" and pool ~= "ReceiveCleaner"
            and pool ~= "ReceiveAmmo" and pool ~= "ReceiveMeds"
            and pool ~= "ReceiveBattery"
            and BridgeSocial.recvBefore(item) then
            pool = "ReceiveAgain"
        end
        BridgeSocial.markRecv(item)
    end
    local over = false
    pcall(function() over = BridgeInventory ~= nil and BridgeInventory.carryOver ~= nil and BridgeInventory.carryOver(Bridge.body) end)
    if over and not BridgeSocial.overSaid then
        BridgeSocial.overSaid = true
        pool = "CarryFull"
    elseif not over then
        BridgeSocial.overSaid = false
    end
    if pendingGift then
        -- Today's gift budget is spent; the item stays unremembered so it can pay
        -- out later. Tell the player at most once a day so it never spams.
        local r = rel()
        local day = r ~= nil and r.day or -1
        if BridgeSocial.giftFullDay ~= day then
            BridgeSocial.giftFullDay = day
            say("GiftFull")
        end
    else
        -- A gift keeps its own reaction line even when another mod recategorized it.
        if gift ~= nil and pool ~= "ReceiveAgain" and pool ~= "CarryFull" then pool = gift end
        BridgeSocial.receiveSay(pool)
    end

    if pool == "ReceiveGun" then
        BridgeSocial.gunNervous()
    else
        local anim = RECEIVE_GESTURE[pool]
        if anim ~= nil then gesture(anim) end
    end
    BridgeSocial.info = "received " .. pool
    log(BridgeSocial.info)
    return true
end



function BridgeSocial.maleGift(item, pool)
    local g = nil
    for _, e in ipairs(BridgeSocial.MALE_RECEIVE) do if e.pool == pool then g = e end end
    if pool == "ReceiveBooze" then g = BridgeSocial.MALE_BOOZE end
    if g == nil then return nil end
    local r = rel()
    if r == nil then return nil end
    local given = false
    pcall(function() given = item:getModData().bridgeGiven == true end)
    if given then return "done" end
    rollDay(r)
    local df = math.max(0, math.min(g.f, DRESS_CAP_F - (r.dressF or 0)))
    local dr = 0
    if g.r > 0 and BridgeSocial.romanceOpen(r) then dr = math.max(0, math.min(g.r, DRESS_CAP_R - (r.dressR or 0))) end
    if df <= 0 and dr <= 0 then
        log(string.format("male gift %s held (budget full) f=%d r=%d", pool, r.f, r.r))
        return "full"
    end
    BridgeSocial.markGiven(item)
    r.dressF = (r.dressF or 0) + df
    r.dressR = (r.dressR or 0) + dr
    r.f = clamp(r.f + df, -100, 100)
    r.r = clamp(r.r + dr, 0, 100)
    popRel(df, dr)
    BridgeSocial.save(true)
    BridgeSocial.giftVersion = (BridgeSocial.giftVersion or 0) + 1
    log(string.format("male gift %s +%d/+%d f=%d r=%d", pool, df, dr, r.f, r.r))
    return "paid"
end


function BridgeSocial.gunNervous()
    gesture("PullAtCollar", true)
end



function BridgeSocial.receiveSay(pool)
    if pool == nil then return false end
    if BridgeSocial.RECEIVE_ENABLED == 0 then return false end
    local fight = false
    pcall(function() fight = BridgeFight ~= nil and (BridgeFight.target ~= nil or BridgeFight.state == "swing") end)
    if fight then return false end
    local said = false



    pcall(function() said = BridgeMoments.say(pool, 5 * 60, "soft", pool) == true end)
    return said
end


function BridgeSocial.dressed(item)
    local r = rel()
    if r == nil or item == nil then return "no rel" end
    local given = false
    pcall(function() given = item:getModData().bridgeGiven == true end)
    if given then return "already given" end
    BridgeSocial.markGiven(item)

    rollDay(r)



    local pool = BridgeSocial.dressPool(item)
    if pool ~= "DressDirty" and pool ~= "DressBroken" and BridgeSocial.wornBefore(item) then
        pool = "DressAgain"
    end
    BridgeSocial.dressSay(pool)

    if not presentable(item) then
        BridgeSocial.info = "dressed: ruined (" .. tostring(pool) .. ")"
        log(BridgeSocial.info)
        return BridgeSocial.info
    end
    BridgeSocial.markWorn(item)

    local kind = isJewel(item) and BridgeSocial.DRESS.jewel or BridgeSocial.DRESS.cloth
    if isMale() then
        kind = BridgeSocial.MALE_DRESS[pool] or (isJewel(item) and BridgeSocial.MALE_DRESS.DressJewel) or BridgeSocial.DRESS.cloth
    end
    local df = math.max(0, math.min(kind.f, DRESS_CAP_F - (r.dressF or 0)))
    local dr = 0
    if kind.r > 0 and BridgeSocial.romanceOpen(r) then dr = math.max(0, math.min(kind.r, DRESS_CAP_R - (r.dressR or 0))) end
    if df > 0 or dr > 0 then
        r.dressF = (r.dressF or 0) + df
        r.dressR = (r.dressR or 0) + dr
        r.f = clamp(r.f + df, -100, 100)
        r.r = clamp(r.r + dr, 0, 100)
        popRel(df, dr)
        BridgeSocial.save(true)
    end
    BridgeSocial.info = string.format("dressed %s +%d/+%d f=%d r=%d", pool, df, dr, r.f, r.r)
    log(BridgeSocial.info)
    return BridgeSocial.info
end


local function zombiesNear(dist)
    local near = false
    pcall(function()
        local red = BridgeData.owner()
        local body = Bridge.body
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if z ~= nil and z ~= body and not z:getVariableBoolean(Bridge.BODY_VAR) and z:isAlive()
                and not BridgeData.harmless(z) then
                local close = false
                for _, who in ipairs({ red, body }) do
                    if who ~= nil then
                        local dx, dy = z:getX() - who:getX(), z:getY() - who:getY()
                        if dx * dx + dy * dy < dist * dist and math.abs(z:getZ() - who:getZ()) < 1 then close = true end
                    end
                end
                if close then
                    local seen = true
                    pcall(function() seen = red:CanSee(z) end)
                    if seen then near = true break end
                end
            end
        end
    end)
    return near
end

local function recentFight()
    local last = -9999
    pcall(function() last = BridgeWeapon.lastFight end)

    return (Bridge.time - last) < AFTER_FIGHT
end


-- Calm (no zombies close, not fighting) and at home / settled indoors. Grows the
-- talk budget and shortens repeat cooldowns while it holds.
function BridgeSocial.relaxed(r)
    local calm = false
    pcall(function()
        calm = not zombiesNear(12) and not recentFight() and BridgeFight ~= nil and BridgeFight.state == "idle"
    end)
    if not calm then return false end
    local home = false
    local fallback = false
    pcall(function()
        local red = BridgeData.owner()
        local sq = red ~= nil and red:getCurrentSquare() or nil
        local h = BridgeData.homeOf(Bridge.store)
        if sq ~= nil and type(h) == "table" then
            local x, y, z = sq:getX(), sq:getY(), sq:getZ()
            if z == h.z and x >= h.x and x <= (h.x + h.w) and y >= h.y and y <= (h.y + h.h) then
                home = true
            end
        end
        if not home and sq ~= nil then fallback = sq:isInARoom() == true end
        if not home and not fallback then
            fallback = Bridge.mode == "rest"
                or (BridgeInventory ~= nil and BridgeInventory.seated ~= nil
                    and BridgeInventory.seated(Bridge.body) == true)
        end
    end)
    return calm and (home or fallback)
end


function BridgeSocial.repeatSec(id, r, relaxed)
    local s = REPEAT_SEC[id] or 60
    if relaxed == nil then relaxed = BridgeSocial.relaxed(r) end
    if relaxed then s = s * 0.4 end
    if r ~= nil and (r.f or 0) >= 45 then s = s * 0.7 end
    return s
end


local function engaged()
    if BridgeCar ~= nil and BridgeCar.holdsBody() then return false end
    if Bridge.mode == "rest" then return false end
    local red = BridgeData.owner()
    local asleep = false
    pcall(function() asleep = red ~= nil and red:isAsleep() end)
    if asleep then return false end
    return (BridgeFight ~= nil and BridgeFight.target ~= nil) or recentFight()
end


function BridgeSocial.onCombatKill(z)
    local body = Bridge.body
    if z == nil or body == nil or z == body then return end
    if not engaged() then return end
    local near = false
    pcall(function()
        local dx, dy = z:getX() - body:getX(), z:getY() - body:getY()
        near = dx * dx + dy * dy < COMBAT_NEAR * COMBAT_NEAR and math.abs(z:getZ() - body:getZ()) < 1
    end)
    if not near then return end
    local r = rel()
    if r == nil then return end
    rollDay(r)
    if (r.combatF or 0) >= COMBAT_DAILY_CAP then return end
    r.combatKills = (r.combatKills or 0) + 1
    if r.combatKills % COMBAT_KILL_STEP == 0 then
        r.combatF = (r.combatF or 0) + 1
        gain(r, 1, 0)
    end
end



BridgeSocial.ACTIONS = {
    { id = "Chat", gate = function(r) return true end, tiered = true,
      chance = function(r) return 0.75 + r.f / 400 end, good = { 2, 0 }, bad = { 0, 0 }, anim = { "Yes", "Shrug" } },
    { id = "Joke", gate = function(r) return true end, tiered = true,
      chance = function(r) return 0.45 + r.f / 200 end, good = { 3, 0 }, bad = { 0, 0 }, anim = { "Clap", "Undecided" } },
    { id = "Compliment", gate = function(r) return r.f >= 10 end, tiered = true,
      chance = function(r) return 0.55 + r.f / 250 end, good = { 2, 1 }, bad = { 0, 0 }, anim = { "ThankYou", "NoThankYou" } },
    { id = "Thanks", gate = function(r) return true end,
      chance = function(r) return 0.9 end, good = { 1, 0 }, bad = { 0, 0 }, anim = { "Yes", "Shrug" } },
    { id = "Comfort", gate = function(r) return r.f >= 20 end, tiered = true,
      chance = function(r) return 0.5 + r.f / 200 end, good = { 3, 0 }, bad = { 0, 0 }, anim = { "Yes", "No" } },
    { id = "Flirt", gate = function(r) return BridgeSocial.romanceOpen(r) end, romantic = true, tiered = true,
      chance = function(r) return 0.2 + (r.f - 30) / 150 + r.r / 150 end, good = { 1, 3 }, bad = { -1, -2 }, anim = { "WaveHi", "No" } },
    { id = "Hug", gate = function(r) return r.f >= 45 and r.r >= 15 and r.days >= 4 and BridgeSocial.romanceOn() end, romantic = true,
      chance = function(r) return 0.3 + r.r / 120 end, good = { 2, 3 }, bad = { -2, -3 }, anim = { "ComeHere", "No" } },
}

local function actionById(id)
    for _, a in ipairs(BridgeSocial.ACTIONS) do
        if a.id == id then return a end
    end
    return nil
end


-- Reason a talk action is unavailable right now, or nil. Mirrors talk()'s own
-- refusals (busy / after fight / repeat window / daily budget) so the menu can grey
-- the exact action and explain why. Busy covers every action; the rest are per action.
function BridgeSocial.talkBlock(id, r, calm, busy)
    if busy then return "Busy" end
    local a = actionById(id)
    if a ~= nil and a.romantic and recentFight() then return "AfterFight" end
    local since = Bridge.time - (BridgeSocial.last[id] or -999999)
    if since < BridgeSocial.repeatSec(id, r, calm) * 60 then return "Repeat" end
    if a ~= nil then
        local df, dr = a.good[1], a.good[2]
        if df > 0 or dr > 0 then
            local fullF = (df <= 0) or ((capF(r, calm) - (r.gainF or 0)) <= 0)
            local fullR = (dr <= 0) or (not BridgeSocial.romanceOn()) or ((capR(r, calm) - (r.gainR or 0)) <= 0)
            if fullF and fullR then return "Full" end
        end
    end
    return nil
end


function BridgeSocial.talk(id)
    local a = actionById(id)
    local r = rel()
    if a == nil or r == nil then return "unknown action" end

    local inCar = BridgeCar ~= nil and BridgeCar.withRed(BridgeData.owner())
    if not Bridge.alive() and not Bridge.drivable() and not inCar then return "no companion" end
    rollDay(r)
    if not a.gate(r) then return "locked" end
    if zombiesNear(BUSY_DIST) then
        say("Busy")
        gesture("No")
        log(id .. " refused: zombies near")
        return "busy"
    end
    if a.romantic and recentFight() then
        say("AfterFight")
        gesture("Shrug")
        log(id .. " refused: after fight")
        return "after fight"
    end


    local calm = BridgeSocial.relaxed(r)

    local since = Bridge.time - (BridgeSocial.last[id] or -999999)
    if since < BridgeSocial.repeatSec(id, r, calm) * 60 then


        BridgeSocial.nagged[id] = (tonumber(BridgeSocial.nagged[id]) or 0) + 1
        if BridgeSocial.nagged[id] <= 2 then
            say("Repeat")
            gesture("Undecided")
            log(id .. " repeat: nagged")
            return "repeat"
        end
        gesture("Shrug")
        log(id .. " repeat: shrug")
        return "repeat: shrug"
    end
    BridgeSocial.last[id] = Bridge.time
    BridgeSocial.nagged[id] = nil
    local chance = clamp(a.chance(r), 0.05, 0.95)
    local roll = ZombRand(1000) / 1000
    local ok = roll < chance
    local shift = ok and a.good or a.bad
    local df, dr = shift[1], shift[2]
    if not ok and calm then
        if df < 0 then df = math.max(-1, math.floor(df * 0.5)) end
        if dr < 0 then dr = math.max(-1, math.floor(dr * 0.5)) end
    end
    if ok and (df > 0 or dr > 0) then
        local fullF = (df <= 0) or ((capF(r, calm) - (r.gainF or 0)) <= 0)
        local fullR = (dr <= 0) or (not BridgeSocial.romanceOn()) or ((capR(r, calm) - (r.gainR or 0)) <= 0)
        if fullF and fullR then
            if BridgeSocial.talkFullDay ~= r.day then
                BridgeSocial.talkFullDay = r.day
                say("TalkFull")
            end
            gesture("Shrug")
            BridgeSocial.info = id .. " talk full"
            log(BridgeSocial.info)
            return BridgeSocial.info
        end
    end
    gain(r, df, dr, calm)
    local pool = id .. (ok and "_Good" or "_Bad")
    if a.tiered then
        local group = "Far"
        pcall(function() group = BridgeMoments.group() end)
        local tiered = id .. (ok and "_Good_" or "_Bad_") .. group
        if lineCount(tiered) > 0 then pool = tiered end
    end
    say(pool)
    gesture(ok and a.anim[1] or a.anim[2])

    if ok and BridgeMood ~= nil then
        local okMood, mood = pcall(BridgeMood.talked, id)
        log(id .. " mood: " .. tostring(okMood and mood or ("error " .. tostring(mood))))
    end
    BridgeSocial.info = string.format("%s %s f=%d r=%d", id, ok and "good" or "bad", r.f, r.r)
    log(BridgeSocial.info)
    return BridgeSocial.info
end



local SNACKS = { "Base.GranolaBar", "Base.Crisps", "Base.BeefJerky", "Base.Chocolate_Candy" }


function BridgeSocial.pickGift(red)
    local thirst, hunger, nicotine, smoker = 0, 0, 0, false
    pcall(function() thirst = red:getStats():get(CharacterStat.THIRST) end)
    pcall(function() hunger = red:getStats():get(CharacterStat.HUNGER) end)
    pcall(function() nicotine = red:getStats():get(CharacterStat.NICOTINE_WITHDRAWAL) end)
    pcall(function() smoker = red:hasTrait(CharacterTrait.SMOKER) end)
    if thirst > 0.2 then return "Base.WaterBottle" end
    if smoker and nicotine > 0.2 then return "Base.CigarettePack" end
    if hunger > 0.2 then return SNACKS[1 + ZombRand(#SNACKS)] end
    local pool = { "Base.WaterBottle", "Base.LighterDisposable", "Base.Gum", SNACKS[1 + ZombRand(#SNACKS)] }
    if smoker then pool[#pool + 1] = "Base.CigarettePack" end
    return pool[1 + ZombRand(#pool)]
end

local function giftDone(item)
    local key = ({ ["Base.WaterBottle"] = "GiftWater", ["Base.CigarettePack"] = "GiftSmokes",
        ["Base.LighterDisposable"] = "GiftLighter" })[item] or "GiftFood"
    say(key)
    gesture("Yes")
    log("gift " .. tostring(item))
end



function BridgeSocial.give(item, fromAsk)
    local r = rel()
    if r == nil then return "no store" end
    local now = hours()
    if now < r.giftAt then return "gift not ready" end
    if Bridge.mp then
        if BridgeSocial.pendingGift ~= nil and Bridge.time - BridgeSocial.pendingGift.tick < 600 then return "gift pending" end
        BridgeSocial.pendingGift = { item = item, tick = Bridge.time, fromAsk = fromAsk }
        pcall(function() sendClientCommand(BridgeData.owner(), "Bridge", "gift", { item = item }) end)
        return "gift asked"
    end
    local ok = false
    pcall(function() ok = BridgeData.owner():getInventory():AddItem(item) ~= nil end)
    if not ok then return "gift failed" end
    r.giftAt = now + 36 + ZombRand(24)
    giftDone(item)
    return "gift " .. item
end


function BridgeSocial.onGifted(args)
    local pending = BridgeSocial.pendingGift
    BridgeSocial.pendingGift = nil
    local r = rel()
    if args and tonumber(args.giftAt) ~= nil and r ~= nil then r.giftAt = math.max(r.giftAt, tonumber(args.giftAt)) end
    if args and args.ok then
        giftDone(args.item or (pending and pending.item))
    elseif pending ~= nil and pending.fromAsk then
        say("AskNothing")
    end
    BridgeSocial.save(true)
end



function BridgeSocial.ask()
    local r = rel()
    if r == nil or r.f < 20 then return "locked" end
    if zombiesNear(BUSY_DIST) then
        say("Busy")
        return "busy"
    end
    local now = hours()
    if now < r.askAt then
        say("AskAgain")
        gesture("No")
        return "asked recently"
    end
    r.askAt = now + 6
    BridgeSocial.save(true)
    if r.f >= 35 and now >= r.giftAt then
        return BridgeSocial.give(BridgeSocial.pickGift(BridgeData.owner()), true)
    end
    say("AskNothing")
    gesture("Shrug")
    return "nothing to give"
end



local function remarkPool(r, red)
    local hurt = false
    pcall(function() hurt = red:getBodyDamage():getNumPartsBleeding() > 0 end)

    local recent = false
    pcall(function() recent = BridgeMoments.recent(4 * 3600) end)
    if hurt and not recent then return "RemarkHurt" end
    if recentFight() then return "RemarkAfterFight" end
    local hour = 12
    pcall(function() hour = getGameTime():getHour() end)
    if (hour >= 22 or hour < 5) and ZombRand(3) == 0 then return "RemarkNight" end
    if BridgeSocial.romanceOn() and r.r >= 50 and ZombRand(2) == 0 then return "RemarkLove" end
    return "Remark" .. BridgeData.relTier(r)
end


function BridgeSocial.update(body)
    if Bridge.time - BridgeSocial.lastCheck < 60 then return end
    BridgeSocial.lastCheck = Bridge.time
    local r = rel()
    local red = BridgeData.owner()
    if r == nil or red == nil then return end
    rollDay(r)
    local together = false
    pcall(function()
        local dx, dy = red:getX() - body:getX(), red:getY() - body:getY()
        together = dx * dx + dy * dy < 100 and math.abs(red:getZ() - body:getZ()) < 1
    end)
    local now = hours()
    if together then

        if r.seen > 0 and now - r.seen > 72 then
            local lost = math.floor((now - r.seen - 72) / 24) + 1
            r.f = math.max(math.min(r.f, 0), r.f - lost)
            r.r = math.max(0, r.r - lost)
            log("apart " .. string.format("%.0f", now - r.seen) .. "h, cooled by " .. lost)
        end


        local step = now - r.seen
        if r.seen > 0 and step > 0 and step <= 0.25 then r.hours = math.min(24, r.hours + step) end
        if now > r.seen then r.seen = now end
    end
    BridgeSocial.save()
    if not together or Bridge.mode == "rest" then return end
    local asleep = false
    pcall(function() asleep = red:isAsleep() end)
    if asleep then return end

    local calm = BridgeFight.state == "idle" and BridgeFight.target == nil and BridgeWash.state == "idle"
        and not BridgeHeal.active and not zombiesNear(12)


    if BridgeSocial.nextRemark == nil then BridgeSocial.nextRemark = Bridge.time + 7200 + ZombRand(7200) end
    local justSpoke = false
    pcall(function() justSpoke = BridgeMoments.recent(3600) end)
    local quiet = false
    pcall(function() quiet = Bridge.quiet() end)
    local chatter = not (BridgeTask ~= nil and BridgeTask.idleChatBlocked ~= nil and BridgeTask.idleChatBlocked())
    if calm and not justSpoke and not chatter and Bridge.time >= BridgeSocial.nextRemark then
        BridgeSocial.nextRemark = Bridge.time + 5400 + ZombRand(9000)

        if not quiet then
            local pool = remarkPool(r, red)
            if say(pool) == nil then say("Remark" .. BridgeData.relTier(r)) end
            BridgeSocial.lastRemark = Bridge.time
        end
    end



    if calm and not quiet and not chatter and r.f >= 35 and now >= r.giftAt and BridgeData.optionOf(Bridge.store, "gifts")
        and ZombRand(900) == 0 then
        BridgeSocial.give(BridgeSocial.pickGift(red), false)
    end
end


function BridgeSocial.label()
    local r = rel()
    if r == nil then return "" end
    local text = ""
    pcall(function()
        text = getText("IGUI_NotAlone_Rel_" .. BridgeData.relTier(r))
        local romance = BridgeSocial.romanceOn()
        if romance and r.r >= 50 then text = getText("IGUI_NotAlone_Rel_Love")
        elseif romance and r.r >= 25 then
            local crush = nil
            if BridgeData ~= nil and type(BridgeData.text) == "function" then crush = BridgeData.text("Rel_Crush") end
            if crush == nil then pcall(function() crush = getText("IGUI_NotAlone_Rel_Crush") end) end
            text = text .. ", " .. tostring(crush)
        end
    end)
    return text
end


local function menuTip(option, text)
    if option == nil or text == nil then return end
    pcall(function()
        local t = ISInventoryPaneContextMenu.addToolTip()
        t.description = text
        option.toolTip = t
    end)
end


function BridgeSocial.fillMenu(context, tr)
    local r = rel()
    if r == nil then return end
    rollDay(r)
    local option = context:addOption(tr("Talk"))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    local busy = zombiesNear(BUSY_DIST)
    local calm = BridgeSocial.relaxed(r)
    local romantic = nil
    for _, a in ipairs(BridgeSocial.ACTIONS) do
        if a.gate(r) then
            local target = sub
            if a.romantic then
                if romantic == nil then
                    local ro = sub:addOption(tr("Romance"))
                    romantic = ISContextMenu:getNew(sub)
                    sub:addSubMenu(ro, romantic)
                end
                target = romantic
            end
            local opt = target:addOption(tr("Talk_" .. a.id), a.id, BridgeSocial.talk)
            local reason = BridgeSocial.talkBlock(a.id, r, calm, busy)
            if reason ~= nil then
                opt.notAvailable = true
                menuTip(opt, tr("TalkCant" .. reason))
            end
        end
    end
    if r.f >= 20 then
        local ask = sub:addOption(tr("Talk_Ask"), nil, BridgeSocial.ask)
        if busy then
            ask.notAvailable = true
            menuTip(ask, tr("TalkCantBusy"))
        end
    end
end

if type(Events) == "table" and Events.OnZombieDead ~= nil then
    Events.OnZombieDead.Add(function(z) pcall(BridgeSocial.onCombatKill, z) end)
end

log("loaded")
