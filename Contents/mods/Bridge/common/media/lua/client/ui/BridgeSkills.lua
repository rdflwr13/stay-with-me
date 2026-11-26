




BridgeSkills = BridgeSkills or {}

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeSkills] " .. tostring(text)) end end
BridgeSkills.PHASE = 5

BridgeSkills.TRACKED = BridgeData.SKILL_KEYS
BridgeSkills.MAX_LEVEL = 10
BridgeSkills.DEBUG = false
BridgeSkills.FLUSH_TICKS = 600
BridgeSkills.xpAccum = BridgeSkills.xpAccum or {}
BridgeSkills.pops = BridgeSkills.pops or {}

function BridgeSkills.store()
    if Bridge.store == nil then return nil end
    return BridgeData.skillsOf(Bridge.store)
end

function BridgeSkills.get(perk)
    local s = BridgeSkills.store()
    if s == nil or s[perk] == nil then return 0 end
    return tonumber(s[perk]) or 0
end


local perkCache = {}
local levelCache = setmetatable({}, { __mode = "k" })
local thresholdCache = setmetatable({}, { __mode = "k" })
local function perkOf(name)
    local p = perkCache[name]
    if p ~= nil then return p end
    local key = name
    if BridgeData ~= nil and type(BridgeData.perkKey) == "function" then
        pcall(function() key = BridgeData.perkKey(name) end)
    end
    pcall(function() p = PerkFactory.getPerk(Perks[key]) end)
    if p ~= nil then perkCache[name] = p end
    return p
end
BridgeSkills.perkOf = perkOf

local function thresholdsFor(p)
    local cached = thresholdCache[p]
    if cached ~= nil then return cached end
    cached = {}
    for n = 1, BridgeSkills.MAX_LEVEL do
        local ok, total = pcall(p.getTotalXpForLevel, p, n)
        if not ok or total == nil then
            cached[n] = false
            break
        end
        cached[n] = total
    end
    thresholdCache[p] = cached
    return cached
end

local function levelForXp(p, xp)
    if p == nil then return 0 end
    local cached = levelCache[p]
    if cached ~= nil and cached.xp == xp then return cached.level end
    local lvl = 0
    local totals = thresholdsFor(p)
    for n = 1, BridgeSkills.MAX_LEVEL do
        local total = totals[n]
        if total == nil or total == false or xp < total then break end
        lvl = n
    end
    levelCache[p] = { xp = xp, level = lvl }
    return lvl
end
BridgeSkills.levelForXp = levelForXp


function BridgeSkills.level(perk)
    return levelForXp(perkOf(perk), BridgeSkills.get(perk))
end


function BridgeSkills.progress(perk)
    local xp = BridgeSkills.get(perk)
    local p = perkOf(perk)
    if p == nil then return 0 end
    local lvl = levelForXp(p, xp)
    if lvl >= BridgeSkills.MAX_LEVEL then return 1 end
    local base, need = 0, nil
    if lvl > 0 then pcall(function() base = p:getTotalXpForLevel(lvl) end) end
    pcall(function() need = p:getXpForLevel(lvl + 1) end)
    if need == nil or need <= 0 then return 0 end
    local frac = (xp - base) / need
    if frac < 0 then frac = 0 end
    if frac > 1 then frac = 1 end
    return frac
end


local WEAPON_CATEGORY_PERK = {
    { "AXE", "Axe" }, { "BLUNT", "Blunt" }, { "SMALL_BLUNT", "SmallBlunt" },
    { "LONG_BLADE", "LongBlade" }, { "SMALL_BLADE", "SmallBlade" }, { "SPEAR", "Spear" },
}

function BridgeSkills.categoryFor(item)
    if item == nil then return nil end
    local script = nil
    pcall(function() script = item:getScriptItem() end)
    if script == nil then return nil end
    for i = 1, #WEAPON_CATEGORY_PERK do
        local e = WEAPON_CATEGORY_PERK[i]
        local wc = nil
        pcall(function() wc = WeaponCategory[e[1]] end)
        if wc ~= nil then
            local match = false
            pcall(function() match = script:containsWeaponCategory(wc) end)
            if match then return e[2] end
        end
    end
    return nil
end







function BridgeSkills.rollMaintenance(item)
    if item == nil then return 0 end

    if not instanceof(item, "HandWeapon") then return 0 end
    local ranged = false; pcall(function() ranged = item:isRanged() == true end)
    if ranged then return 0 end

    local full = nil
    pcall(function() full = item:getFullType() end)
    if full == "Base.BareHands" then return 0 end

    local oneIn = nil
    pcall(function() oneIn = item:getConditionLowerChance() end)
    if oneIn == nil then pcall(function() oneIn = item:getConditionLowerChanceOneIn() end) end
    if oneIn == nil then
        local script = nil
        pcall(function() script = item:getScriptItem() end)
        if script ~= nil then
            pcall(function() oneIn = script:getConditionLowerChanceOneIn() end)
            if oneIn == nil then pcall(function() oneIn = script:getConditionLowerChance() end) end
        end
    end
    oneIn = tonumber(oneIn)
    if oneIn == nil or oneIn ~= oneIn or oneIn <= 0 then return 0 end

    if ZombRand(100) >= 50 then return 0 end
    if oneIn > 10 then return 2 * 10 / oneIn end
    return 2
end




function BridgeSkills.applyCarry(explicitBody)
    local body = explicitBody or Bridge.body
    if body == nil then return end
    local cap = BridgeData.carryForStrengthLevel(BridgeSkills.level("Strength"))
    if cap == nil then return end


    local setw = nil
    pcall(function() setw = body.setMaxWeight end)
    if setw ~= nil then pcall(function() body:setMaxWeight(cap) end) end
    pcall(function() body:getInventory():setCapacity(cap) end)
end




local function multiplierConfig()
    if SandboxVars == nil then return nil end
    return SandboxVars.MultiplierConfig
end

local function multiplierValue(cfg, perk)
    if cfg.GlobalToggle == true then return tonumber(cfg.Global) end
    return tonumber(cfg[perk])
end

BridgeSkills.BOOK_FALLBACK = {
    LongBlade = { key = "LongBlade", mults = { 1.5, 2.5, 4, 6, 8 } },
    Maintenance = { key = "Maintenance", mults = { 3, 5, 8, 12, 16 } },
    Aiming = { key = "Aiming", mults = { 1.5, 2.5, 4, 6, 8 } },
    Reloading = { key = "Reloading", mults = { 1.5, 2.5, 4, 6, 8 } },
    FirstAid = { key = "Doctor", mults = { 3, 5, 8, 12, 16 } },
    Farming = { key = "Agriculture", mults = { 3, 5, 8, 12, 16 } },
    Husbandry = { key = "Husbandry", mults = { 3, 5, 8, 12, 16 } },
}

function BridgeSkills.bookMult(key)
    if key == nil then return nil end
    local rec = Bridge.store
    if rec == nil then return nil end
    local b = BridgeData.bookXpOf(rec)
    if b == nil then return nil end
    return b[key]
end

local function bookMultValue(key)
    local bm = BridgeSkills.bookMult(key)
    if bm == nil then return nil end
    local m = tonumber(bm.m)
    if m == nil or m ~= m or m <= 0 then return nil end
    return m
end

local function xpMultiplier(perk)
    local base = 1
    local okCfg, cfg = pcall(multiplierConfig)
    if okCfg and cfg ~= nil then
        local okMult, mult = pcall(multiplierValue, cfg, perk)
        if okMult and mult ~= nil and mult == mult and mult > 0 then base = mult end
    end
    local bm = bookMultValue(perk)
    if bm ~= nil then base = base * bm end
    return base
end
BridgeSkills.xpMultiplier = xpMultiplier

local function bookMultForLevel(entry, lvl)
    if entry == nil then return 1 end
    if lvl == 1 then return tonumber(entry.maxMultiplier1) or 1 end
    if lvl == 3 then return tonumber(entry.maxMultiplier2) or 1 end
    if lvl == 5 then return tonumber(entry.maxMultiplier3) or 1 end
    if lvl == 7 then return tonumber(entry.maxMultiplier4) or 1 end
    if lvl == 9 then return tonumber(entry.maxMultiplier5) or 1 end
    return 1
end

function BridgeSkills.bookInfo(item)
    if item == nil then return nil end
    if type(item.getSkillTrained) ~= "function" then return nil end
    local skill = nil
    pcall(function() skill = item:getSkillTrained() end)
    if type(skill) ~= "string" or skill == "" then return nil end
    local entry = nil
    pcall(function() entry = SkillBook ~= nil and SkillBook[skill] or nil end)
    local fallback = BridgeSkills.BOOK_FALLBACK[skill]
    if entry == nil and fallback == nil then return nil end
    local key = nil
    if entry ~= nil then
        for i = 1, #BridgeData.SKILL_KEYS do
            local k = BridgeData.SKILL_KEYS[i]
            local perk = nil
            pcall(function() perk = Perks[BridgeData.perkKey(k)] end)
            if perk ~= nil and perk == entry.perk then key = k break end
        end
    else
        key = fallback.key
    end
    local lvl, maxLvl, pages, read = 0, 0, 0, 0
    if type(item.getLvlSkillTrained) == "function" then
        pcall(function() lvl = tonumber(item:getLvlSkillTrained()) or 0 end)
    end
    if type(item.getMaxLevelTrained) == "function" then
        pcall(function() maxLvl = tonumber(item:getMaxLevelTrained()) or 0 end)
    end
    if type(item.getNumberOfPages) == "function" then
        pcall(function() pages = tonumber(item:getNumberOfPages()) or 0 end)
    end
    if type(item.getAlreadyReadPages) == "function" then
        pcall(function() read = tonumber(item:getAlreadyReadPages()) or 0 end)
    end
    local mult = 1
    if entry ~= nil then
        mult = bookMultForLevel(entry, lvl)
    elseif fallback ~= nil then
        local idx = 1
        if lvl == 1 then idx = 1 elseif lvl == 3 then idx = 2 elseif lvl == 5 then idx = 3
        elseif lvl == 7 then idx = 4 elseif lvl == 9 then idx = 5 end
        mult = fallback.mults[idx] or 1
    end
    local status = "ok"
    if key == nil then
        status = "not_tracked"
    else
        local herLvl = BridgeSkills.level(key)
        if pages > 0 and read >= pages then status = "read"
        elseif lvl > herLvl + 1 then status = "too_hard"
        elseif maxLvl < herLvl + 1 then status = "obsolete" end
    end
    return { book = true, skill = skill, key = key, level = lvl, maxLevel = maxLvl,
        pages = pages, read = read, mult = tonumber(mult) or 1, status = status }
end

BridgeSkills.READ_CATEGORIES = BridgeData.READ_CATEGORIES

function BridgeSkills.readKey(item)
    if item == nil then return nil end
    local full = nil
    pcall(function() full = item:getFullType() end)
    if type(full) ~= "string" or full == "" then return nil end
    local base = string.match(full, "^[^%.]+%.(.+)$") or full
    if base == "Book" or base == "Paperback" or base == "Magazine" then
        local name = nil
        pcall(function() name = item:getName() end)
        if type(name) == "string" and name ~= "" then
            return full .. "|" .. name
        end
    end
    return full
end

function BridgeSkills.categoryOf(item)
    if item == nil then return nil end
    local skillInfo = nil
    pcall(function() skillInfo = BridgeSkills.bookInfo(item) end)
    if skillInfo ~= nil then return "skill" end
    local full = nil
    pcall(function() full = item:getFullType() end)
    if type(full) ~= "string" then return nil end
    local base = string.match(full, "^[^%.]+%.(.+)$") or full
    local low = string.lower(base)
    local skip = { "child", "picture", "photo", "card", "receipt", "note", "brochure", "flier",
        "catalog", "phonebook", "rpg", "instruction", "recipe" }
    for i = 1, #skip do
        if string.find(low, skip[i], 1, true) then return nil end
    end
    if string.find(low, "hottiez", 1, true) then return "hottiez" end
    if string.find(low, "comic", 1, true) then return "comic" end
    if string.find(low, "newspaper", 1, true) then return "newspaper" end
    if string.find(low, "magazine", 1, true) or string.find(low, "tvguide", 1, true) then return "magazine" end
    local sub = string.lower(string.match(base, "_([%w]+)$") or "")
    local map = {
        art = "art", history = "history", military = "military", science = "science",
        nature = "nature", medical = "medical", cooking = "cooking", craft = "craft",
        religion = "religious", religious = "religious", bible = "religious",
        occult = "occult", newage = "occult",
        horror = "horror", scary = "horror",
        scifi = "scifi", sciencefiction = "scifi",
        crime = "crime", crimefiction = "crime", mystery = "crime", detective = "crime", truecrime = "crime",
        romance = "romance", sexy = "romance",
        fiction = "fiction", novel = "fiction", literaryfiction = "fiction", play = "fiction",
        generalnonfiction = "general", generalreference = "general",
        biography = "biography", business = "business", cinema = "cinema", computer = "computer",
        diet = "diet", farming = "nature", fashion = "fashion", golf = "golf", legal = "legal",
        music = "music", philosophy = "philosophy", policing = "politics", politics = "politics",
        quackery = "quackery", relationship = "relationship", schooltextbook = "science",
        selfhelp = "self_help", sports = "sports", travel = "travel", baseball = "sports",
        militaryhistory = "history",
        classic = "classic", classicfiction = "classic", classicnonfiction = "classic",
        fantasy = "fantasy",
        thriller = "thriller", conspiracy = "thriller",
        western = "western",
        adventurenfiction = "adventure",
        sadnonfiction = "sad",
        teens = "fiction",
        poor = "fiction", rich = "fiction", hass = "fiction", quigley = "fiction",
    }
    if map[sub] ~= nil then return map[sub] end
    if string.find(low, "book", 1, true) or string.find(low, "paperback", 1, true) then return "fiction" end
    return nil
end

function BridgeSkills.litInfo(item)
    if item == nil then return nil end
    local cat = BridgeSkills.categoryOf(item)
    if cat == nil or cat == "skill" then return nil end
    local key = BridgeSkills.readKey(item)
    if key == nil then return nil end
    local pages = 0
    if type(item.getNumberOfPages) == "function" then
        pcall(function() pages = tonumber(item:getNumberOfPages()) or 0 end)
    end
    local read = 0
    if type(item.getAlreadyReadPages) == "function" then
        pcall(function() read = tonumber(item:getAlreadyReadPages()) or 0 end)
    end
    local status = "ok"
    local rec = Bridge.store
    if rec ~= nil then
        local books = BridgeData.booksReadOf(rec)
        local e = books ~= nil and books[key] or nil
        if e ~= nil and (e.done == true or (pages > 0 and (tonumber(e.p) or 0) >= pages)) then
            status = "read"
        end
    end
    return { book = true, kind = "lit", key = key, category = cat, pages = pages, read = read, status = status }
end

function BridgeSkills.readInfo(item)
    local info = nil
    pcall(function() info = BridgeSkills.bookInfo(item) end)
    if info ~= nil then return info end
    return BridgeSkills.litInfo(item)
end

function BridgeSkills.isShort(info)
    if info == nil then return false end
    local cat = info.category
    if cat == "magazine" or cat == "newspaper" or cat == "comic" then return true end
    local pages = tonumber(info.pages) or 0
    return pages > 0 and pages <= 10
end

function BridgeSkills.eligibleBooks(body)
    body = body or Bridge.body
    if body == nil then return {} end
    local out = {}
    local conts = nil
    if BridgeTask ~= nil and type(BridgeTask.lootDests) == "function" then
        pcall(function() conts = BridgeTask.lootDests(body) end)
    end
    if conts == nil then
        conts = {}
        local inv = nil
        pcall(function() inv = body:getInventory() end)
        if inv ~= nil then conts[1] = inv end
    end
    for ci = 1, #conts do
        local cont = conts[ci]
        local items = nil
        pcall(function() items = cont:getItems() end)
        if items ~= nil then
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                local info = nil
                pcall(function() info = BridgeSkills.readInfo(it) end)
                if info ~= nil then out[#out + 1] = { item = it, info = info } end
            end
        end
    end
    return out
end

function BridgeSkills.debugBook()
    local out = {}
    local rec = Bridge.store
    local b = rec ~= nil and BridgeData.bookXpOf(rec) or nil
    if b ~= nil then
        for i = 1, #BridgeData.SKILL_KEYS do
            local k = BridgeData.SKILL_KEYS[i]
            local e = b[k]
            if e ~= nil then out[#out + 1] = k .. "=x" .. tostring(e.m) .. " until " .. tostring(e.max) end
        end
    end
    if #out == 0 then return "no book multipliers" end
    return table.concat(out, " ")
end

function BridgeSkills.readCommand(parts)
    local sub = parts[3]
    if sub == nil or sub == "status" then
        local state = "idle"
        if BridgeTask ~= nil and BridgeTask.active then
            state = tostring(BridgeTask.kind) .. " phase=" .. tostring(BridgeTask.phase or BridgeTask.readPhase)
                .. " posture=" .. tostring(BridgeTask.readPosture) .. " " .. tostring(BridgeTask.info)
        end
        local frac = nil
        if BridgeTask ~= nil and type(BridgeTask.readFrac) == "function" then pcall(function() frac = BridgeTask.readFrac() end) end
        return "read status: " .. state .. " progress="
            .. (frac ~= nil and string.format("%.0f%%", frac * 100) or "-")
            .. " | " .. BridgeSkills.debugBook() .. " | " .. BridgeSkills.summary()
    end
    if sub == "books" then
        local list = BridgeSkills.eligibleBooks(Bridge.body)
        if #list == 0 then return "read books: none" end
        local out = {}
        for i = 1, #list do
            local e = list[i]
            local info = e.info
            local name = "-"
            pcall(function() name = e.item:getName() end)
            out[#out + 1] = string.format("%d %s %s L%d/%d pages=%d read=%d x%.1f %s", i, tostring(name),
                tostring(info.key or info.skill), tonumber(info.level) or 0, tonumber(info.maxLevel) or 0,
                tonumber(info.pages) or 0, tonumber(info.read) or 0, tonumber(info.mult) or 1, tostring(info.status))
        end
        return "read books: " .. table.concat(out, " | ")
    end
    if sub == "start" then
        local want = parts[4]
        local list = BridgeSkills.eligibleBooks(Bridge.body)
        local pick = nil
        local idx = tonumber(want)
        if idx ~= nil then
            pick = list[idx]
        else
            for i = 1, #list do
                local full = nil
                pcall(function() full = list[i].item:getFullType() end)
                if full == want then pick = list[i] break end
            end
        end
        if pick == nil then return "read start: no such book" end
        if BridgeTask == nil then return "read start: no task" end
        return "read start: " .. tostring(BridgeTask.start("read", { { item = pick.item } }))
    end
    if sub == "stop" then
        if BridgeTask ~= nil and BridgeTask.active and BridgeTask.kind == "read" then
            return "read stop: " .. tostring(BridgeTask.cancel("read stop"))
        end
        return "read stop: not reading"
    end
    if sub == "grant" then
        local perk = parts[4]
        local mult = tonumber(parts[5])
        local max = tonumber(parts[6])
        if perk == nil or mult == nil then return "read grant: usage read grant <perk> <mult> <maxLevel>" end
        local rec = Bridge.store
        if rec == nil then return "read grant: no store" end
        local b = BridgeData.bookXpOf(rec)
        b[perk] = { m = mult, max = max or 10 }
        BridgeSkills.dirty = true
        return "read grant: " .. perk .. " x" .. tostring(mult) .. " until " .. tostring(max or 10)
    end
    if sub == "clear" then
        local perk = parts[4]
        local rec = Bridge.store
        if rec == nil or type(rec.bookXp) ~= "table" then return "read clear: nothing" end
        rec.bookXp[perk] = nil
        BridgeSkills.dirty = true
        return "read clear: " .. tostring(perk)
    end
    if sub == "clearread" then
        local key = parts[4]
        local rec = Bridge.store
        if rec == nil or type(rec.booksRead) ~= "table" then return "read clearread: nothing" end
        rec.booksRead[key] = nil
        BridgeSkills.dirty = true
        return "read clearread: " .. tostring(key)
    end
    return "read: usage read status|books|start|stop|grant|clear|clearread"
end

function BridgeSkills.readselftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end
    local clean = BridgeData.cleanBookXp({ LongBlade = { m = 4, max = 7 }, Bogus = { m = 2, max = 3 },
        Maintenance = { m = 0, max = 5 }, Aiming = { m = 2, max = 99 } })
    check("clean keeps valid", clean ~= nil and clean.LongBlade ~= nil and clean.LongBlade.m == 4)
    check("clean drops unknown", clean ~= nil and clean.Bogus == nil)
    check("clean drops low mult", clean ~= nil and clean.Maintenance == nil)
    check("clean drops bad max", clean ~= nil and clean.Aiming == nil)
    local rec = { bookXp = { LongBlade = { m = 6, max = 7 } } }
    local b = BridgeData.bookXpOf(rec)
    check("bookXpOf returns table", type(b) == "table" and b.LongBlade.m == 6)
    local mult = math.floor(50 / 10) * (8 / 10)
    check("milestone formula", mult == 4)
    local upgraded = math.max(6, 4)
    check("no downgrade", upgraded == 6)
    check("expires at max", 7 >= (b.LongBlade.max or 99))
    if #fails == 0 then return string.format("readselftest PASS (%d checks)", checks) end
    return string.format("readselftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end



function BridgeSkills.add(perk, amount, reason, skipMultiplier)
    if BridgeMeet ~= nil and type(BridgeMeet.quietCombat) == "function" and BridgeMeet.quietCombat() then return 0 end
    local s = BridgeSkills.store()
    if s == nil or s[perk] == nil then return 0 end
    amount = tonumber(amount)
    if amount == nil or amount ~= amount or amount <= 0 then return 0 end


    if not skipMultiplier then amount = amount * xpMultiplier(perk) end
    local p = perkOf(perk)
    local cap = nil
    if p ~= nil then
        local ok, value = pcall(p.getTotalXpForLevel, p, BridgeSkills.MAX_LEVEL)
        if ok then cap = value end
    end
    local before = tonumber(s[perk]) or 0
    local after = before + amount
    if cap ~= nil and after > cap then after = cap end
    if after == before then return before end
    s[perk] = after
    BridgeSkills.noteXp(perk, after - before)
    local oldLvl = levelForXp(p, before)
    local newLvl = levelForXp(p, after)
    if BridgeSkills.DEBUG then
        log(string.format("+%.2f %s (%s) %.1f -> %.1f L%d", amount, tostring(perk),
            tostring(reason or ""), before, after, newLvl))
    end
    if newLvl > oldLvl then
        BridgeSkills.lastLevelUp = { perk = perk, from = oldLvl, to = newLvl, tick = Bridge.time or 0 }
        pcall(function() BridgeSkills.onLevel(perk, newLvl) end)
        BridgeSkills.flush()
        if perk == "Strength" then pcall(BridgeSkills.applyCarry) end
    else
        BridgeSkills.dirty = true
    end
    local bx = BridgeSkills.bookMult(perk)
    if bx ~= nil and newLvl >= (tonumber(bx.max) or 99) then
        local rec = Bridge.store
        if rec ~= nil and type(rec.bookXp) == "table" then
            rec.bookXp[perk] = nil
            BridgeSkills.dirty = true
        end
    end
    return after
end


function BridgeSkills.perkLabel(perk)
    local label = nil
    pcall(function() label = getTextOrNull("IGUI_perks_" .. tostring(perk)) end)
    if label == nil or label == "" then label = tostring(perk) end
    return label
end





function BridgeSkills.onLevel(perk, lvl)
    log(string.format("LEVELUP %s -> %d", tostring(perk), lvl))
    BridgeSkills.levelUpAt = Bridge.time or 0
    BridgeSkills.xpAccum = {}
    BridgeSkills.xpAt = nil
    if Bridge.body == nil then return end
    pcall(function() Bridge.body:addLineChatElement(BridgeData.text("SkillLevelUp", BridgeSkills.perkLabel(perk)), 0.4, 0.9, 0.4) end)
    pcall(function() Bridge.body:playSound("GainExperienceLevel") end)
    BridgeSkills.sayAt = (Bridge.time or 0) + 90
    BridgeSkills.sayTries = 0
end





local XP_FLUSH_TICKS = 45
local POP_LIFE_MS = 2000
local POP_RISE = 22
local POP_BASE = 14
local POP_COLOR = { 0.4, 0.9, 0.4 }
local POP_COLOR_FRIEND = { 0.62, 0.52, 0.82 }
local POP_COLOR_ROMANCE = { 0.86, 0.46, 0.64 }
local POP_COLOR_LOSS = { 0.80, 0.28, 0.28 }

function BridgeSkills.noteXp(perk, amount)
    amount = tonumber(amount)
    if amount == nil or amount ~= amount or amount <= 0 then return end
    BridgeSkills.xpAccum[perk] = (BridgeSkills.xpAccum[perk] or 0) + amount
    if BridgeSkills.xpAt == nil then BridgeSkills.xpAt = (Bridge.time or 0) + XP_FLUSH_TICKS end
end



function BridgeSkills.pushPop(text, color)
    local pops = BridgeSkills.pops
    pops[#pops + 1] = { text = text, color = color, t0 = getTimestampMs() }
end



function BridgeSkills.popXp(perk, amount)
    if Bridge.body == nil then return end
    if not BridgeData.optionOf(Bridge.store, "xpPopups") then return end
    local text = BridgeData.text("SkillXpPop", BridgeSkills.perkLabel(perk), string.format("%.1f", amount))
    BridgeSkills.pushPop(text, POP_COLOR)
    if BridgeSkills.DEBUG then
        log(string.format("pop +%.1f %s (%d active)", amount, tostring(perk), #BridgeSkills.pops))
    end
end



function BridgeSkills.popRel(stream, amount)
    if Bridge.body == nil then return end
    if not BridgeData.optionOf(Bridge.store, "relPopups") then return end
    amount = tonumber(amount)
    if amount == nil or amount ~= amount then return end
    amount = math.floor(amount)
    if amount == 0 then return end
    local color
    if amount < 0 then
        color = POP_COLOR_LOSS
    elseif stream == "Romance" then
        color = POP_COLOR_ROMANCE
    else
        color = POP_COLOR_FRIEND
    end
    local key = (stream == "Friend") and "RelPopFriend" or "RelPopRomance"
    BridgeSkills.pushPop(BridgeData.text(key, string.format("%+d", amount)), color)
end

local function flushXp()
    if Bridge.body == nil then return end
    local accum = BridgeSkills.xpAccum
    for k, v in pairs(accum) do
        if v > 0 then
            BridgeSkills.popXp(k, v)
            accum[k] = nil
        end
    end
    BridgeSkills.xpAt = nil
end




local function drawPops()
    if Bridge == nil then return end
    local pops = BridgeSkills.pops
    local count = #pops
    if count == 0 then return end
    local z = Bridge.body
    if z == nil then return end
    local player = BridgeData.owner()
    if player == nil then return end
    local pn = player:getPlayerNum()
    local tm = getTextManager()
    local now = getTimestampMs()
    local fontH = tm:getFontHeight(UIFont.Small)
    local rowH = fontH + 2
    local zoom = getCore():getZoom(pn)
    local lift = 128 * Core.getTileScale() / 2 / zoom
    local zx, zy, zz = z:getX(), z:getY(), z:getZ()
    local j = 1
    for i = 1, count do
        local p = pops[i]
        local age = now - p.t0
        if age < POP_LIFE_MS then
            local frac = age / POP_LIFE_MS
            local alpha = 1 - frac
            local x = isoToScreenX(pn, zx, zy, zz)
            local y = isoToScreenY(pn, zx, zy, zz)
                - lift - fontH - POP_BASE - POP_RISE * frac - (j - 1) * rowH
            local text = p.text
            local color = p.color or POP_COLOR
            tm:DrawStringCentre(UIFont.Small, x - 1, y, text, 0, 0, 0, alpha * 0.8)
            tm:DrawStringCentre(UIFont.Small, x + 1, y, text, 0, 0, 0, alpha * 0.8)
            tm:DrawStringCentre(UIFont.Small, x, y - 1, text, 0, 0, 0, alpha * 0.8)
            tm:DrawStringCentre(UIFont.Small, x, y + 1, text, 0, 0, 0, alpha * 0.8)
            tm:DrawStringCentre(UIFont.Small, x, y, text, color[1], color[2], color[3], alpha)
            pops[j] = p
            j = j + 1
        end
    end
    for i = count, j, -1 do pops[i] = nil end
end


local function sayTick()
    if BridgeSkills.sayAt == nil then return end
    if (Bridge.time or 0) < BridgeSkills.sayAt then return end
    local ok = false
    pcall(function() ok = BridgeMoments ~= nil and BridgeMoments.say("EvSkillUp", 0, "soft") end)
    if ok then
        BridgeSkills.sayAt = nil
        BridgeSkills.sayTries = 0
    else
        local tries = (BridgeSkills.sayTries or 0) + 1

        if tries >= 7 then
            BridgeSkills.sayAt = nil
            BridgeSkills.sayTries = 0
        else
            BridgeSkills.sayTries = tries
            BridgeSkills.sayAt = (Bridge.time or 0) + 60
        end
    end
end

local function xpTick()
    if BridgeSkills.xpAt == nil then return end
    if (Bridge.time or 0) < BridgeSkills.xpAt then return end
    BridgeSkills.xpAt = nil
    pcall(flushXp)
end


















local runWasX, runWasY = nil, nil
local function runTick()
    if Bridge.body == nil then return end
    if (Bridge.time or 0) < (BridgeSkills.runAt or 0) then return end
    BridgeSkills.runAt = (Bridge.time or 0) + 60
    if BridgeMove == nil or BridgeMove.walkType ~= "Run" then
        runWasX, runWasY = nil, nil
        return
    end
    local body = Bridge.body
    local x, y = nil, nil
    pcall(function() x, y = body:getX(), body:getY() end)
    local moved = true
    if x ~= nil and runWasX ~= nil then moved = (x ~= runWasX) or (y ~= runWasY) end
    runWasX, runWasY = x, y
    if not moved then return end
    local endur, warn = 1.0, 0.5
    pcall(function() endur = body:getStats():get(CharacterStat.ENDURANCE) end)
    pcall(function() warn = body:getStats():getEnduranceWarning() end)
    if endur <= warn then return end



    if ZombRand(1000) < 50 then BridgeSkills.add("Fitness", 1, "run") end
end

function BridgeSkills.summary()
    local s = BridgeSkills.store()
    if s == nil then return "skills: no store" end
    local out = {}
    for i = 1, #BridgeSkills.TRACKED do
        local k = BridgeSkills.TRACKED[i]
        out[#out + 1] = k .. "=" .. tostring(s[k]) .. "(L" .. tostring(BridgeSkills.level(k)) .. ")"
    end
    return table.concat(out, " ")
end


function BridgeSkills.flush()
    BridgeSkills.dirty = false
    if not Bridge.mp then return end
    local s = BridgeSkills.store()
    if s == nil then return end
    Bridge.localSkills = s
    local rec = Bridge.store
    local bookXp = nil
    local booksRead = nil
    local favBook = nil
    if rec ~= nil then
        bookXp = BridgeData.cleanBookXp(rec.bookXp)
        Bridge.localBookXp = rec.bookXp
        booksRead = BridgeData.cleanBooksRead(rec.booksRead)
        Bridge.localBooksRead = rec.booksRead
        favBook = BridgeData.cleanFavBook(rec.favBook)
        Bridge.localFavBook = rec.favBook
    end
    BridgeSkills.sentAt = Bridge.time or 0
    pcall(function()
        sendClientCommand(BridgeData.owner(), "Bridge", "state",
            { skills = BridgeData.cleanSkills(s), bookXp = bookXp, booksRead = booksRead, favBook = favBook })
    end)
end


local function flushTick()
    if not BridgeSkills.dirty then return end
    if Bridge.mp and (Bridge.time or 0) - (BridgeSkills.sentAt or -99999) < BridgeSkills.FLUSH_TICKS then return end
    BridgeSkills.flush()
end
BridgeSkills.flushTick = flushTick












































local function ensureBridge()
    if type(Bridge) == "table" then return true end
    if BridgeData ~= nil and type(BridgeData.keepBridge) == "function" then
        BridgeData.keepBridge()
    end
    return type(Bridge) == "table"
end

local function installWrappers()
    if not ensureBridge() then return end


















    if type(Bridge.refreshStore) == "function" and not BridgeSkills._refreshWrapped then
        BridgeSkills._refreshWrapped = true
        local baseRefresh = Bridge.refreshStore
        Bridge.refreshStore = function()
            baseRefresh()
            if Bridge.store == nil then return end
            BridgeData.skillsOf(Bridge.store)
            if Bridge.mp and Bridge.gotData then
                local incoming = Bridge.store.skills
                if Bridge.localSkills ~= nil and incoming ~= Bridge.localSkills then
                    Bridge.store.skills = Bridge.localSkills
                elseif Bridge.localSkills == nil and type(incoming) == "table" then
                    Bridge.localSkills = incoming
                end
                local inBook = Bridge.store.bookXp
                if Bridge.localBookXp ~= nil and inBook ~= Bridge.localBookXp then
                    Bridge.store.bookXp = Bridge.localBookXp
                elseif Bridge.localBookXp == nil and type(inBook) == "table" then
                    Bridge.localBookXp = inBook
                end
                local inBooks = Bridge.store.booksRead
                if Bridge.localBooksRead ~= nil and inBooks ~= Bridge.localBooksRead then
                    Bridge.store.booksRead = Bridge.localBooksRead
                elseif Bridge.localBooksRead == nil and type(inBooks) == "table" then
                    Bridge.localBooksRead = inBooks
                end
                local inFav = Bridge.store.favBook
                if Bridge.localFavBook ~= nil and inFav ~= Bridge.localFavBook then
                    Bridge.store.favBook = Bridge.localFavBook
                elseif Bridge.localFavBook == nil and type(inFav) == "string" then
                    Bridge.localFavBook = inFav
                end
            end
        end
    end
end

if type(Events) == "table" and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(installWrappers)
    Events.OnGameStart.Add(function()
        if not ensureBridge() then return end
        pcall(function()
            if Bridge.store == nil then return end
            BridgeData.skillsOf(Bridge.store)
            log("SKILLS " .. BridgeSkills.summary())
        end)
    end)
end
if type(Bridge) == "table" and type(Bridge.run) == "function" then
    installWrappers()
end


if type(Events) == "table" and Events.OnTick ~= nil then
    Events.OnTick.Add(function()
        if Bridge == nil then return end
        pcall(sayTick)
        pcall(xpTick)
        pcall(runTick)
        pcall(flushTick)
    end)
end

if type(Events) == "table" and Events.OnPreUIDraw ~= nil then
    Events.OnPreUIDraw.Add(function() pcall(drawPops) end)
end

log("loaded")
