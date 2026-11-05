BridgeGunTalk = BridgeGunTalk or {}

local BANDED = {
    ReceiveGun = true,
    ReceiveAmmo = true,
    ReceiveGunPart = true,
    LootGun = true,
    LootAmmo = true,
}

local NEUTRAL = {
    ReceiveMeleePart = true,
    ReceiveAmmoParts = true,
    LootAmmoParts = true,
}

local EQUIP_TYPES = { Pistol = true, Shotgun = true, Rifle = true, Other = true }

local EQUIP_FALLBACK = "EquipGun_Other"

BridgeGunTalk.BANDED = BANDED
BridgeGunTalk.NEUTRAL = NEUTRAL

local BANNED = {
    "take it back",
    "i can't use",
    "i can't shoot",
    "i can't aim",
    "i don't use guns",
    "i don't shoot",
    "i'd only hurt",
    "i'd waste",
    "no good to me",
    "why would i want",
    "i'd panic",
    "not yet",
}


local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeGunTalk] " .. tostring(text)) end
end


local function keyText(key)
    local value = nil
    pcall(function() value = getTextOrNull(key, "", "") end)
    if value == nil or value == key or value == "" then return nil end
    return value
end


local function poolText(pool, index)
    return keyText("IGUI_NotAlone_Soc_" .. tostring(pool) .. "_" .. tostring(index))
end


local function poolExists(pool)
    if type(pool) ~= "string" or pool == "" then return false end
    return poolText(pool, 1) ~= nil
end


function BridgeGunTalk.band(level)
    local lvl = level
    if type(lvl) ~= "number" then
        lvl = 0
        pcall(function() lvl = BridgeSkills.level("Aiming") end)
    end
    lvl = tonumber(lvl) or 0
    if lvl >= 6 then return "High" end
    if lvl >= 3 then return "Mid" end
    return "Low"
end


function BridgeGunTalk.group()
    local group = "Far"
    pcall(function() group = BridgeMoments.group() end)
    if group ~= "Far" and group ~= "Near" and group ~= "Close" then group = "Far" end
    return group
end


function BridgeGunTalk.eventFor(base, band)
    return tostring(base) .. "_" .. tostring(band)
end


function BridgeGunTalk.keyName(base, band, group, index)
    return "IGUI_NotAlone_Soc_" .. BridgeGunTalk.eventFor(base, band) .. "_" .. tostring(group) .. "_" .. tostring(index)
end


function BridgeGunTalk.handles(pool)
    return type(pool) == "string" and (BANDED[pool] == true or NEUTRAL[pool] == true)
end


function BridgeGunTalk.has(event)
    if type(event) ~= "string" or event == "" then return false end
    if poolExists(event .. "_" .. BridgeGunTalk.group()) then return true end
    return poolExists(event .. "_Near")
end


local function speakText(pool, cooldown, slot, urgent)
    if BridgeMoments == nil or Bridge.speakText == nil then return false end
    if Bridge.time == nil then return false end
    if not BridgeMoments.ready(slot, urgent or "soft") then return false end
    local n = 0
    for i = 1, 8 do
        if poolText(pool, i) == nil then break end
        n = i
    end
    if n == 0 then return false end
    local text = nil
    for _ = 1, 4 do
        local index = 1 + ZombRand(n)
        pcall(function() index = BridgeSocial.pick(pool, n) end)
        local key = "IGUI_NotAlone_Soc_" .. pool .. "_" .. index
        pcall(function() key = BridgeSocial.lineKey(pool, index) end)
        pcall(function() text = getText(key) end)
        local again = false
        pcall(function() again = BridgeSocial.sameAsLast(text) end)
        if n < 2 or not again then break end
    end
    if text == nil or text == "" then return false end
    BridgeMoments.cool[slot] = Bridge.time + (cooldown or 0)
    BridgeMoments.lastLine = Bridge.time
    local quiet = false
    pcall(function() quiet = Bridge.quiet() end)
    if quiet then
        pcall(function() Bridge.bridgeEvent(pool, text) end)
        BridgeMoments.info = pool .. " quiet"
        log(pool .. " quiet")
        return true
    end
    Bridge.speakText(text)
    BridgeMoments.info = pool
    log(pool .. " " .. BridgeGunTalk.group())
    return true
end


function BridgeGunTalk.sayBanded(base, cooldown, slot, urgent)
    if type(base) ~= "string" or base == "" then return false end
    local event = BridgeGunTalk.eventFor(base, BridgeGunTalk.band())
    if not BridgeGunTalk.has(event) then return false end
    local said = false
    pcall(function() said = BridgeMoments.say(event, cooldown, urgent or "soft", slot) == true end)
    return said
end


function BridgeGunTalk.sayNeutral(pool, cooldown, slot, urgent)
    if type(pool) ~= "string" or pool == "" then return false end
    return speakText(pool, cooldown, slot, urgent)
end


local function descOf(item)
    local desc = nil
    pcall(function()
        if BridgeGunfight ~= nil and BridgeGunfight.gunItem == item then desc = BridgeGunfight.gun end
    end)
    if type(desc) == "table" then return desc end
    if item ~= nil then pcall(function() desc = BridgeGunRules.describe(item) end) end
    if type(desc) ~= "table" then return nil end
    return desc
end


function BridgeGunTalk.equip(item)
    local kind = "Other"
    pcall(function() kind = BridgeGunRules.talkKind(descOf(item)) end)
    if EQUIP_TYPES[kind] ~= true then kind = "Other" end
    local band = BridgeGunTalk.band()
    local event = "EquipGun_" .. kind
    if not BridgeGunTalk.has(BridgeGunTalk.eventFor(event, band)) then
        event = EQUIP_FALLBACK
        if not BridgeGunTalk.has(BridgeGunTalk.eventFor(event, band)) then return false end
    end
    return BridgeGunTalk.sayBanded(event, 0, "EquipGun")
end


function BridgeGunTalk.receive(pool, item)
    if NEUTRAL[pool] == true then return BridgeGunTalk.sayNeutral(pool, 5 * 60, pool) end
    if BANDED[pool] == true then return BridgeGunTalk.sayBanded(pool, 5 * 60, pool) end
    return nil
end


function BridgeGunTalk.loot(pool)
    if pool == "ReceiveGun" then return BridgeGunTalk.sayBanded("LootGun", BridgeTask.LOOT_SAY_COOLDOWN, "Loot", true) end
    if pool == "ReceiveAmmo" then return BridgeGunTalk.sayBanded("LootAmmo", BridgeTask.LOOT_SAY_COOLDOWN, "Loot", true) end
    if pool == "ReceiveAmmoParts" then return BridgeGunTalk.sayNeutral("LootAmmoParts", BridgeTask.LOOT_SAY_COOLDOWN, "Loot", true) end
    return nil
end


function BridgeGunTalk.audit()
    local missing, banned, checked = {}, {}, 0
    local function scan(pool)
        for i = 1, 3 do
            checked = checked + 1
            local text = poolText(pool, i)
            if text == nil then
                missing[#missing + 1] = pool .. "_" .. i
            else
                local low = string.lower(text)
                for _, phrase in ipairs(BANNED) do
                    if string.find(low, phrase, 1, true) ~= nil then
                        banned[#banned + 1] = pool .. "_" .. i .. ":" .. phrase
                        break
                    end
                end
            end
        end
    end
    local banded = { "ReceiveGun", "ReceiveAmmo", "ReceiveGunPart", "LootGun", "LootAmmo",
        "EquipGun_Pistol", "EquipGun_Shotgun", "EquipGun_Rifle", "EquipGun_Other" }
    for _, base in ipairs(banded) do
        for _, band in ipairs({ "Low", "Mid", "High" }) do
            for _, group in ipairs({ "Far", "Near", "Close" }) do
                scan(BridgeGunTalk.eventFor(base, band) .. "_" .. group)
            end
        end
    end
    for _, pool in ipairs({ "ReceiveMeleePart", "ReceiveAmmoParts", "LootAmmoParts" }) do scan(pool) end
    if #missing == 0 and #banned == 0 then
        return string.format("guntalk audit PASS (%d strings)", checked)
    end
    local parts = {}
    if #missing > 0 then parts[#parts + 1] = "missing " .. table.concat(missing, ",") end
    if #banned > 0 then parts[#parts + 1] = "banned " .. table.concat(banned, ",") end
    return "guntalk audit FAIL: " .. table.concat(parts, "; ")
end


function BridgeGunTalk.selftest()
    local checks, fails = 0, {}
    local function check(name, got, want)
        checks = checks + 1
        if got ~= want then
            fails[#fails + 1] = string.format("%s got=%s want=%s", name, tostring(got), tostring(want))
        end
    end

    check("band 0", BridgeGunTalk.band(0), "Low")
    check("band 2", BridgeGunTalk.band(2), "Low")
    check("band 3", BridgeGunTalk.band(3), "Mid")
    check("band 5", BridgeGunTalk.band(5), "Mid")
    check("band 6", BridgeGunTalk.band(6), "High")
    check("band 10", BridgeGunTalk.band(10), "High")

    check("event ReceiveGun Mid", BridgeGunTalk.eventFor("ReceiveGun", "Mid"), "ReceiveGun_Mid")
    check("event EquipGun_Pistol Low", BridgeGunTalk.eventFor("EquipGun_Pistol", "Low"), "EquipGun_Pistol_Low")
    check("key ReceiveGun Low Far 2", BridgeGunTalk.keyName("ReceiveGun", "Low", "Far", 2),
        "IGUI_NotAlone_Soc_ReceiveGun_Low_Far_2")
    check("key EquipGun_Rifle High Close 3", BridgeGunTalk.keyName("EquipGun_Rifle", "High", "Close", 3),
        "IGUI_NotAlone_Soc_EquipGun_Rifle_High_Close_3")

    check("talkKind pistol", BridgeGunRules.talkKind(
        { kind = "Handgun", reloadFamily = "handgun", projectileCount = 1 }), "Pistol")
    check("talkKind revolver", BridgeGunRules.talkKind(
        { kind = "Handgun", reloadFamily = "revolver", projectileCount = 1 }), "Pistol")
    check("talkKind sawed-off", BridgeGunRules.talkKind(
        { kind = "Handgun", reloadFamily = "handgun", projectileCount = 8 }), "Shotgun")
    check("talkKind rifle", BridgeGunRules.talkKind(
        { kind = "Rifle", reloadFamily = "rifle", projectileCount = 1 }), "Rifle")
    check("talkKind unknown", BridgeGunRules.talkKind({}), "Other")
    check("talkKind nil", BridgeGunRules.talkKind(nil), "Other")

    check("has ReceiveGun Mid", BridgeGunTalk.has("ReceiveGun_Mid"), true)
    check("has EquipGun_Other Low", BridgeGunTalk.has("EquipGun_Other_Low"), true)
    check("fallback missing type", BridgeGunTalk.has("EquipGun_NoSuchType_Low"), false)

    local audit = BridgeGunTalk.audit()
    checks = checks + 1
    if string.find(audit, "PASS", 1, true) == nil then fails[#fails + 1] = audit end

    if #fails == 0 then return string.format("guntalk selftest PASS (%d checks)", checks) end
    return string.format("guntalk selftest FAIL (%d of %d): %s", #fails, checks, table.concat(fails, "; "))
end


log("loaded")
