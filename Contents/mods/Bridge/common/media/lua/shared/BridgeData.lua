













BridgeData = BridgeData or {}
BridgeData.KEY = "NotAlone"
BridgeData.OLD_KEY = "BridgeRin"
BridgeData.LOCAL = "local"
BridgeData.DEFAULT_NAME = "Rin"
BridgeData.DEFAULT_MALE_NAME = "Ren"
BridgeData.NAME_MAX = 20
BridgeData.MODES = { follow = true, wait = true, rest = true }





function BridgeData.overheadOk(text)
    if text == nil then return false end
    text = tostring(text)
    local plain = true
    for i = 1, #text do
        if string.byte(text, i) > 127 then plain = false break end
    end
    if plain then return true end
    local ok = false
    pcall(function() ok = getTextOrNull("IGUI_NotAlone_OverheadCyrillic") == "1" end)
    return ok
end






function BridgeData.owner()
    local p = nil
    if getSpecificPlayer ~= nil then p = getSpecificPlayer(0) end
    if p == nil then p = getPlayer() end
    return p
end









function BridgeData.dragged(z)
    local yes = false
    pcall(function() yes = z:isReanimatedForGrappleOnly() == true end)
    return yes
end








BridgeData.FRIENDLY_VARS = BridgeData.FRIENDLY_VARS or { "RNPCFriendly" }

function BridgeData.friendlyNpc(z)
    local yes = false
    pcall(function()
        local vars = BridgeData.FRIENDLY_VARS
        for i = 1, #vars do
            if z:getVariableBoolean(vars[i]) then yes = true return end
        end
    end)
    return yes
end








BridgeData.FOREIGN_MODDATA = BridgeData.FOREIGN_MODDATA or { "ProjectALifeOwned", "ProjectALifeActor" }





BridgeData.SURVIVOR_MODDATA = "PS_NPC_ID"

function BridgeData.survivorBody(z)
    local yes = false
    pcall(function()
        if z == nil or z.hasModData == nil or not z:hasModData() then return end
        local data = z:getModData()
        if data == nil then return end
        if data[BridgeData.SURVIVOR_MODDATA] ~= nil then yes = true end
    end)
    return yes
end

local function markedForeign(z)
    if BridgeData.survivorBody(z) then return true end
    local yes = false
    pcall(function()
        local data = z:getModData()
        if data == nil then return end
        local keys = BridgeData.FOREIGN_MODDATA
        for i = 1, #keys do
            if data[keys[i]] == true then yes = true return end
        end
    end)
    return yes
end











function BridgeData.banditBrain(z, deep)
    if type(BanditBrain) ~= "table" or type(BanditBrain.Get) ~= "function" then return false, nil end
    local npc, brain = false, nil
    pcall(function()
        if z:getVariableBoolean("Bandit") then
            npc = true
            brain = BanditBrain.Get(z)
        end
        if type(brain) ~= "table" and (deep or isServer()) and type(GetBanditClusterData) == "function"
            and type(BanditUtils) == "table" and type(BanditUtils.GetZombieID) == "function" then
            local id = BanditUtils.GetZombieID(z)
            local gmd = GetBanditClusterData(id)
            if type(gmd) == "table" and type(gmd[id]) == "table" then
                npc = true
                brain = gmd[id]
            end
        end
    end)
    if type(brain) ~= "table" then brain = nil end
    return npc, brain
end




function BridgeData.bandit(z, deep)
    local npc, brain = BridgeData.banditBrain(z, deep)
    local hostile = nil
    if brain ~= nil then hostile = brain.hostile == true or brain.hostileP == true end
    return npc, hostile
end



function BridgeData.foreign(z)
    if markedForeign(z) then return true end
    local npc = BridgeData.banditBrain(z, true)
    return npc
end









function BridgeData.alifeHostile(z)
    local answer = nil
    pcall(function()
        local mod = ProjectALife
        if type(mod) ~= "table" then return end
        local player = BridgeData.owner()
        local data = z:getModData()
        local uid = data ~= nil and data.ProjectALifeUID or nil
        if type(uid) == "string" and type(mod.ActorRegistry) == "table" and type(mod.Relations) == "table"
            and type(mod.Relations.hostileToPlayer) == "function" then
            local read = mod.ActorRegistry.peek or mod.ActorRegistry.read
            local actor = type(read) == "function" and read(uid) or nil
            if type(actor) == "table" then
                answer = mod.Relations.hostileToPlayer(actor, player) == true
                return
            end
        end
        if type(mod.Reputation) == "table" and type(mod.Reputation.statusFor) == "function" then
            local status = mod.Reputation.statusFor(player, z)
            if type(status) == "string" then answer = status == "hostile" end
        end
    end)
    return answer
end







function BridgeData.foreignPeaceful(z)
    local npc, hostile = BridgeData.bandit(z)
    if npc then return hostile ~= true end
    if not markedForeign(z) then return false end
    return BridgeData.alifeHostile(z) ~= true
end





function BridgeData.harmless(z)
    return BridgeData.dragged(z) or BridgeData.friendlyNpc(z) or BridgeData.foreignPeaceful(z)
end


function BridgeData.me()
    if isClient() then
        local p = BridgeData.owner()
        if p == nil then return nil end
        return p:getUsername()
    end
    return BridgeData.LOCAL
end



function BridgeData.cleanName(text)
    if text == nil then return nil end
    text = tostring(text)
    local out = {}
    for i = 1, #text do
        local c = string.byte(text, i)
        if c >= 32 and c ~= 127 then out[#out + 1] = string.sub(text, i, i) end
    end
    text = table.concat(out)
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if #text > BridgeData.NAME_MAX then text = string.sub(text, 1, BridgeData.NAME_MAX) end
    if text == "" then return nil end
    return text
end

function BridgeData.nameOf(rec)
    if type(rec) ~= "table" then return BridgeData.DEFAULT_NAME end
    if BridgeData.isMale(rec) then
        if rec.maleName ~= nil and rec.maleName ~= "" then return rec.maleName end
        return BridgeData.DEFAULT_MALE_NAME
    end
    if rec.name ~= nil and rec.name ~= "" then return rec.name end
    return BridgeData.DEFAULT_NAME
end

function BridgeData.modeOf(rec)
    if rec ~= nil and BridgeData.MODES[rec.mode] then return rec.mode end
    return "follow"
end





BridgeData.KEEP_SIDES = { behind = true, left = true, right = true }











BridgeData.KEEP_SIDES_ON = false






BridgeData.KEEP_ON = true

function BridgeData.keepAllowed(side)
    if side == "behind" then return true end
    return BridgeData.KEEP_SIDES_ON == true and BridgeData.KEEP_SIDES[side] == true
end

function BridgeData.keepOf(rec)
    if BridgeData.KEEP_ON and rec ~= nil and BridgeData.keepAllowed(rec.keep) then return rec.keep end
    return "behind"
end

function BridgeData.farOf(rec)
    return BridgeData.KEEP_ON == true and rec ~= nil and rec.far == true
end


BridgeData.COMBAT_MODES = { bodyguard = true, escort = true, aggressive = true, backup = true, stayback = true }
BridgeData.DEFAULT_COMBAT = "bodyguard"


BridgeData.COMBAT = {
    bodyguard = { rank = "player", engageSelf = 2.5, engageRed = 3.0, targetMax = 6.0, approach = 4.5, leash = 4.0 },
    escort = { rank = "self", engageSelf = 3.0, engageRed = 5.5, targetMax = 9.0, approach = 7.0, leash = 7.0 },
    aggressive = { rank = "self", engageSelf = 4.5, engageRed = 11.0, targetMax = 13.0, approach = 12.0, leash = 12.0 },
    backup = { rank = "player", engageSelf = 2.5, engageRed = 3.0, targetMax = 6.0, approach = 4.5, leash = 4.0, assist = true },
    stayback = { rank = "self", engageSelf = 0, engageRed = 0, targetMax = 0, approach = 0, leash = 99, passive = true },
}

function BridgeData.combatOf(rec)
    if rec ~= nil and BridgeData.COMBAT_MODES[rec.combat] then return rec.combat end
    return BridgeData.DEFAULT_COMBAT
end



















BridgeData.OPTIONS = { autoHeal = true, hitMatters = false, gifts = true, redKit = true, mood = true, xpPopups = false,
    romance = true, fatigueBar = false, torch = "auto", equipScale = 1 }
BridgeData.HAIR_MAX = 40

function BridgeData.optionOf(rec, key)
    if BridgeData.OPTIONS[key] == nil then return false end
    if rec ~= nil and rec[key] ~= nil then return rec[key] == true end
    if key == "romance" then return not BridgeData.sameSex(rec) end
    return BridgeData.OPTIONS[key] == true
end



BridgeData.TORCH_MODES = { off = true, auto = true }
BridgeData.DEFAULT_TORCH = "off"

function BridgeData.cleanTorchMode(value)
    if type(value) == "string" then value = string.lower(value) end
    if BridgeData.TORCH_MODES[value] then return value end
    return nil
end

function BridgeData.torchMode(rec)
    if rec ~= nil then
        local mode = BridgeData.cleanTorchMode(rec.torch)
        if mode ~= nil then return mode end
    end
    local def = BridgeData.cleanTorchMode(BridgeData.OPTIONS.torch)
    return def or BridgeData.DEFAULT_TORCH
end


-- Equipment window scale: a numeric multiplier kept alongside the string torch
-- option (optionOf only understands booleans, so this needs its own getter).
BridgeData.EQUIP_SCALES = { 0.75, 1, 1.25, 1.5, 2 }
BridgeData.DEFAULT_EQUIP_SCALE = 1

function BridgeData.cleanEquipScale(value)
    local n = tonumber(value)
    if n == nil or n ~= n then return nil end
    for _, v in ipairs(BridgeData.EQUIP_SCALES) do
        if math.abs(v - n) < 0.001 then return v end
    end
    return nil
end

function BridgeData.equipScale(rec)
    if rec ~= nil then
        local v = BridgeData.cleanEquipScale(rec.equipScale)
        if v ~= nil then return v end
    end
    local def = BridgeData.cleanEquipScale(BridgeData.OPTIONS.equipScale)
    return def or BridgeData.DEFAULT_EQUIP_SCALE
end


function BridgeData.sameSex(rec)
    local fem = nil
    pcall(function() fem = BridgeData.owner():isFemale() end)
    if fem == nil then return false end
    return fem == BridgeData.isFemale(rec)
end







BridgeData.GENDERS = { female = true, male = true }
BridgeData.DEFAULT_GENDER = "female"

function BridgeData.cleanGender(value)
    if value == "male" then return "male" end
    return "female"
end

function BridgeData.genderOf(rec)
    if type(rec) == "table" and rec.gender == "male" then return "male" end
    return "female"
end

function BridgeData.isFemale(rec)
    return BridgeData.genderOf(rec) == "female"
end

function BridgeData.isMale(rec)
    return BridgeData.genderOf(rec) == "male"
end

function BridgeData.voicePrefix(rec)
    return BridgeData.isMale(rec) and "VoiceMale" or "VoiceFemale"
end




BridgeData.GENDERED_KEYS = {
    Need_Axe = true, Need_CleanImplement = true, Need_Cleaner = true, Need_CleanSupplies = true,
    Talk_Thanks = true, Talk_Comfort = true, Rel_Crush = true, InvAssign = true, LookDefault = true,
    CombatAggressive = true, CombatAggressiveTip = true, CombatGuardTip = true,
    OptAutoHeal = true, OptAutoHealTip = true, OptHitMatters = true, OptGifts = true,
    OptGiftsTip = true, OptRedKitTip = true, OptMoodTip = true, OptXpPopupsTip = true, OptRomanceTip = true,
    OptFatigueBar = true, OptFatigueBarTip = true,
    OptTorchTip = true,
    OptEquipScale = true, OptEquipScaleTip = true,
}

function BridgeData.text(key, a, b)
    local full = key
    if BridgeData.GENDERED_KEYS[key] and type(Bridge) == "table" and BridgeData.isMale(Bridge.store) then
        local alt = nil
        pcall(function() alt = getTextOrNull("IGUI_NotAlone_" .. key .. "Male") end)
        if type(alt) == "string" and alt ~= "" and alt ~= ("IGUI_NotAlone_" .. key .. "Male") then full = key .. "Male" end
    end
    local out = key
    pcall(function()
        if b ~= nil then out = getText("IGUI_NotAlone_" .. full, a, b)
        elseif a ~= nil then out = getText("IGUI_NotAlone_" .. full, a)
        else out = getText("IGUI_NotAlone_" .. full) end
    end)
    return out
end



function BridgeData.appearanceOf(rec)
    if type(rec) ~= "table" then return {} end
    if rec.gender == "male" then
        if type(rec.male) ~= "table" then rec.male = {} end
        return rec.male
    end
    return rec
end


function BridgeData.cleanHair(text)
    if type(text) ~= "string" or text == "" or #text > BridgeData.HAIR_MAX then return nil end
    if string.find(text, "[^%w_]") ~= nil then return nil end
    return text
end

BridgeData.DEFAULT_HAIR = "Grungey02"
BridgeData.DEFAULT_MALE_HAIR = "Bald"

function BridgeData.hairOf(rec)
    local app = BridgeData.appearanceOf(rec)
    local hair = app ~= nil and BridgeData.cleanHair(app.hair) or nil
    if hair ~= nil then return hair end
    return BridgeData.isMale(rec) and BridgeData.DEFAULT_MALE_HAIR or BridgeData.DEFAULT_HAIR
end

BridgeData.DEFAULT_SKIN = "FemaleBody01"
BridgeData.SKINS = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04", "FemaleBody05" }
BridgeData.DEFAULT_MALE_SKIN = "MaleBody01"
BridgeData.MALE_SKINS = { "MaleBody01", "MaleBody02", "MaleBody03", "MaleBody04", "MaleBody05" }
BridgeData.DEFAULT_HAIR_COLOR = { r = 0.55, g = 0.12, b = 0.12 }
BridgeData.DEFAULT_MALE_HAIR_COLOR = { r = 0.16, g = 0.09, b = 0.05 }


function BridgeData.cleanSkinFor(text, gender)
    if type(text) ~= "string" then return nil end
    local list = (gender == "male") and BridgeData.MALE_SKINS or BridgeData.SKINS
    for i = 1, #list do
        if list[i] == text then return text end
    end
    return nil
end


function BridgeData.cleanSkin(text)
    return BridgeData.cleanSkinFor(text, "female") or BridgeData.cleanSkinFor(text, "male")
end

function BridgeData.skinOf(rec)
    local gender = BridgeData.genderOf(rec)
    local app = BridgeData.appearanceOf(rec)
    local skin = app ~= nil and BridgeData.cleanSkinFor(app.skin, gender) or nil
    if skin ~= nil then return skin end
    return gender == "male" and BridgeData.DEFAULT_MALE_SKIN or BridgeData.DEFAULT_SKIN
end

function BridgeData.skinsFor(gender)
    return (gender == "male") and BridgeData.MALE_SKINS or BridgeData.SKINS
end

function BridgeData.cleanHairColor(t)
    if type(t) ~= "table" then return nil end
    local out = {}
    for _, k in ipairs({ "r", "g", "b" }) do
        local v = tonumber(t[k])
        if v == nil or v ~= v then return nil end
        if v < 0 then v = 0 end
        if v > 1 then v = 1 end
        out[k] = v
    end
    return out
end

function BridgeData.hairColorOf(rec)
    local app = BridgeData.appearanceOf(rec)
    local color = app ~= nil and BridgeData.cleanHairColor(app.hairColor) or nil
    if color ~= nil then return color end
    return BridgeData.isMale(rec) and BridgeData.DEFAULT_MALE_HAIR_COLOR or BridgeData.DEFAULT_HAIR_COLOR
end



BridgeData.MUSCLE_MAX = 2


local function spnccData()
    if BridgeData._spnccData ~= nil then return BridgeData._spnccData or nil end
    local ok, mod = pcall(require, "CharacterCustomisation/SPNCC_Data")
    BridgeData._spnccData = (ok and type(mod) == "table") and mod or false
    return BridgeData._spnccData or nil
end


function BridgeData.skinIndex(rec)
    local n = tonumber(string.match(BridgeData.skinOf(rec), "(%d+)$")) or 1
    return n - 1
end


function BridgeData.spnccFaces(gender)
    BridgeData._faces = BridgeData._faces or {}
    local key = (gender == "male") and "male" or (gender == "female") and "female" or "all"
    if BridgeData._faces[key] ~= nil then return BridgeData._faces[key] or nil end
    local d = spnccData()
    local out = {}
    local function add(src)
        if type(src) ~= "table" then return end
        for _, v in pairs(src) do
            if type(v) == "table" and type(v.name) == "string" and v.name ~= "" then out[#out + 1] = v end
        end
    end
    if d ~= nil then
        if gender == "male" then add(d.MaleFaces)
        elseif gender == "female" then add(d.FemaleFaces)
        else add(d.MaleFaces) add(d.FemaleFaces) end
    end
    if #out == 0 then
        BridgeData._faces[key] = false
        return nil
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    BridgeData._faces[key] = out
    return out
end


function BridgeData.spnccDetails(gender)
    BridgeData._details = BridgeData._details or {}
    local key = (gender == "male") and "male" or (gender == "female") and "female" or "all"
    if BridgeData._details[key] ~= nil then return BridgeData._details[key] or nil end
    local d = spnccData()
    if d == nil or type(d.BodyDetails) ~= "table" then
        BridgeData._details[key] = false
        return nil
    end
    local out = {}
    for _, v in pairs(d.BodyDetails) do
        if type(v) == "table" and type(v.name) == "string" and v.name ~= "" then
            local female = (v.female ~= false)
            local male = (v.male ~= false)
            local ok
            if gender == "male" then ok = male
            elseif gender == "female" then ok = female
            else ok = (male or female) end
            if ok then out[#out + 1] = v end
        end
    end
    if #out == 0 then
        BridgeData._details[key] = false
        return nil
    end
    table.sort(out, function(a, b) return (a.sort or "b") .. a.name < (b.sort or "b") .. b.name end)
    BridgeData._details[key] = out
    return out
end


function BridgeData.spnccMuscle(gender)
    local d = spnccData()
    if d == nil or type(d.Muscle) ~= "table" then return nil end
    if gender == "male" then return d.Muscle[1] end
    return d.Muscle[2]
end


function BridgeData.spnccMuscleTypes()
    local d = spnccData()
    if d == nil or type(d.Muscle) ~= "table" then return nil end
    return d.Muscle
end


function BridgeData.spnccOn(gender)
    return BridgeData.spnccFaces(gender) ~= nil or BridgeData.spnccDetails(gender) ~= nil
end


function BridgeData.makeupList()
    if BridgeData._makeup ~= nil then return BridgeData._makeup or nil end
    local defs = rawget(_G, "MakeUpDefinitions")
    if defs == nil or type(defs.makeup) ~= "table" then
        BridgeData._makeup = false
        return nil
    end
    local out = {}
    for _, m in ipairs(defs.makeup) do
        if type(m.item) == "string" and m.item ~= "" then
            out[#out + 1] = { item = m.item, category = m.category or "FullFace", name = m.name }
        end
    end
    if #out == 0 then
        BridgeData._makeup = false
        return nil
    end
    BridgeData._makeup = out
    return out
end


function BridgeData.makeupMeta(itemType)
    for _, m in ipairs(BridgeData.makeupList() or {}) do
        if m.item == itemType then return m end
    end
    return nil
end


local function asList(t)
    if type(t) ~= "table" then return nil end
    local out = {}
    local n = #t
    if n > 0 then
        for i = 1, n do out[i] = t[i] end
        return out
    end
    local i = 1
    while true do
        local v = t[i]
        if v == nil then v = t[tostring(i)] end
        if v == nil then break end
        out[i] = v
        i = i + 1
    end
    return out
end


local function tokenOk(name)
    return type(name) == "string" and name ~= "" and #name <= 64 and string.find(name, "[^%w_]") == nil
end


function BridgeData.cleanMakeup(list)
    list = asList(list)
    if list == nil then return nil end
    local out, seen = {}, {}
    if BridgeData.makeupList() == nil then
        for _, itemType in ipairs(list) do
            if type(itemType) == "string" and string.find(itemType, "^[%w_]+%.[%w_]+$") ~= nil and not seen[itemType] then
                seen[itemType] = true
                out[#out + 1] = itemType
            end
        end
        return out
    end
    for _, itemType in ipairs(list) do
        local m = BridgeData.makeupMeta(itemType)
        if m ~= nil and not seen[m.category] then
            seen[m.category] = true
            out[#out + 1] = itemType
        end
    end
    return out
end


function BridgeData.makeupOf(rec)
    local app = BridgeData.appearanceOf(rec)
    return BridgeData.cleanMakeup(app ~= nil and app.makeup or nil) or {}
end


function BridgeData.spnccTexture(entry, skinIndex)
    if type(entry) ~= "table" then return skinIndex or 0 end
    if type(entry.textures) == "table" then
        if #entry.textures == 1 then return entry.textures[1] end
        if #entry.textures >= 5 then return entry.textures[(skinIndex or 0) + 1] end
    end
    local off = tonumber(entry.textureOffset) or 0
    if off < 0 then off = 0 end
    return (skinIndex or 0) + off
end


function BridgeData.faceEntry(rec)
    local gender = BridgeData.genderOf(rec)
    local app = BridgeData.appearanceOf(rec)
    local name = app ~= nil and app.face or nil
    if type(name) ~= "string" or name == "" then return nil end
    local function findIn(list)
        for _, e in ipairs(list or {}) do
            if e.name == name then return e end
        end
        return nil
    end
    return findIn(BridgeData.spnccFaces(gender)) or findIn(BridgeData.spnccFaces(nil))
end


function BridgeData.detailEntries(rec)
    local out = {}
    local app = BridgeData.appearanceOf(rec)
    local wanted = asList(app ~= nil and app.details or nil) or {}
    for _, e in ipairs(BridgeData.spnccDetails(BridgeData.genderOf(rec)) or {}) do
        for _, n in ipairs(wanted) do
            if n == e.name then out[#out + 1] = e break end
        end
    end
    return out
end


function BridgeData.cleanFace(name, gender)
    if name == nil or name == "" then return nil end
    if type(name) ~= "string" then return nil end
    local faces = BridgeData.spnccFaces(gender)
    if faces == nil then
        if tokenOk(name) then return name end
        return nil
    end
    for _, e in ipairs(faces) do
        if e.name == name then return name end
    end
    if gender ~= nil then
        for _, e in ipairs(BridgeData.spnccFaces(nil) or {}) do
            if e.name == name then return name end
        end
    end
    return nil
end


function BridgeData.cleanDetails(list, gender)
    list = asList(list)
    if list == nil then return nil end
    local catalog = BridgeData.spnccDetails(gender)
    local seen, out = {}, {}
    if catalog == nil then
        for _, n in ipairs(list) do
            if tokenOk(n) and not seen[n] then
                seen[n] = true
                out[#out + 1] = n
            end
        end
        return out
    end
    local ok = {}
    for _, e in ipairs(catalog) do ok[e.name] = true end
    for _, n in ipairs(list) do
        if type(n) == "string" and ok[n] and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
        end
    end
    return out
end


function BridgeData.muscleOf(rec)
    local app = BridgeData.appearanceOf(rec)
    local n = app ~= nil and tonumber(app.muscle) or 0
    if n == nil or n ~= n or n < 0 then n = 0 end
    if n > BridgeData.MUSCLE_MAX then n = BridgeData.MUSCLE_MAX end
    return math.floor(n)
end


BridgeData.DEFAULT_BEARD = ""
BridgeData.DEFAULT_MALE_BEARD = "Full"

function BridgeData.cleanBeard(name)
    if name == nil or name == "" then return "" end
    if type(name) ~= "string" then return nil end
    if not tokenOk(name) then return nil end
    return name
end

function BridgeData.beardOf(rec)
    if BridgeData.isFemale(rec) then return "" end
    local app = BridgeData.appearanceOf(rec)

    if app == nil or app.beard == nil then return BridgeData.DEFAULT_MALE_BEARD end
    local b = BridgeData.cleanBeard(app.beard)
    if b ~= nil then return b end
    return BridgeData.DEFAULT_MALE_BEARD
end



function BridgeData.beardColorOf(rec)
    local app = BridgeData.appearanceOf(rec)
    local c = app ~= nil and BridgeData.cleanHairColor(app.beardColor) or nil
    if c ~= nil then return c end
    return BridgeData.hairColorOf(rec)
end







BridgeData.STARTER = {
    female = {

        { t = "Base.Tshirt_WhiteTINT", tint = { 0.13, 0.10, 0.11 } },
        { t = "Base.Trousers_Denim", tc = 1 },
        { t = "Base.Shoes_CowboyBoots_Black" },

        { t = "Base.Belt2" },
        { t = "Base.Jacket_SheepSkin_Navy", alt = "Base.Jacket_PaddedDOWN", altTint = { 0.10, 0.13, 0.25 }, first = true },
    },
    male = {
        { t = "Base.Shirt_Denim", bt = 1 },
        { t = "Base.Trousers_Denim", tc = 1 },
        { t = "Base.Shoes_WorkBoots", bt = 0 },
        { t = "Base.Glasses_Normal", tc = 0 },
        { t = "Base.Belt2" },
    },
}
BridgeData.STARTER_WEAPON = { female = "Base.WoodAxe", male = "Base.PipeWrench" }



function BridgeData.neverSpawned(rec)
    if type(rec) ~= "table" then return false end
    for _, k in ipairs({ "gender", "outfitGiven", "items", "saved", "bodyId", "oldBodyId", "male", "name", "maleName",
        "skin", "hair", "hairColor", "face", "details", "muscle", "makeup", "beltGiven", "armsSet" }) do
        if rec[k] ~= nil then return false end
    end

    if type(rec.rel) == "table" then
        for _, v in pairs(rec.rel) do
            if type(v) == "number" and v ~= 0 then return false end
        end
    end
    return true
end

local function sameColor(a, b)
    return type(a) == "table" and type(b) == "table" and math.abs((a.r or 0) - (b.r or 0)) < 0.01
        and math.abs((a.g or 0) - (b.g or 0)) < 0.01 and math.abs((a.b or 0) - (b.b or 0)) < 0.01
end


function BridgeData.lookUntouched(rec)
    if type(rec) ~= "table" then return false end
    local male = BridgeData.isMale(rec)
    local app = BridgeData.appearanceOf(rec)
    if BridgeData.skinOf(rec) ~= (male and BridgeData.DEFAULT_MALE_SKIN or BridgeData.DEFAULT_SKIN) then return false end
    if BridgeData.hairOf(rec) ~= (male and BridgeData.DEFAULT_MALE_HAIR or BridgeData.DEFAULT_HAIR) then return false end
    if not sameColor(BridgeData.hairColorOf(rec), male and BridgeData.DEFAULT_MALE_HAIR_COLOR or BridgeData.DEFAULT_HAIR_COLOR) then return false end

    if app.hair ~= nil and BridgeData.cleanHair(app.hair) == nil then return false end
    if male and app.beard ~= nil and BridgeData.cleanBeard(app.beard) == nil then return false end
    if app.face ~= nil and app.face ~= "" then return false end
    if type(app.details) == "table" and #app.details > 0 then return false end
    if BridgeData.muscleOf(rec) ~= 0 then return false end
    if #BridgeData.makeupOf(rec) > 0 then return false end
    if male then
        if BridgeData.beardOf(rec) ~= BridgeData.DEFAULT_MALE_BEARD then return false end
        if not sameColor(BridgeData.beardColorOf(rec), BridgeData.hairColorOf(rec)) then return false end
    end
    return true
end




function BridgeData.itemsUntouched(rec, gender)
    if type(rec) ~= "table" then return false end

    if rec.saved ~= 1 or rec.items == nil then return rec.items == nil and rec.outfitGiven == nil end
    if type(BridgeItems) ~= "table" or type(BridgeItems.decode) ~= "function" then return false end
    local g = (gender == "male" or gender == "female") and gender or BridgeData.genderOf(rec)
    local have = {}
    for _, r in ipairs(BridgeItems.decode(rec.items)) do
        if r.p ~= nil then return false end
        have[r.t] = (have[r.t] or 0) + 1
    end
    local function take(t)
        if t ~= nil and (have[t] or 0) > 0 then have[t] = have[t] - 1 return true end
        return false
    end
    for _, e in ipairs(BridgeData.STARTER[g]) do
        if not e.first and not take(e.t) then return false end
    end

    local extra = 0
    for _, e in ipairs(BridgeData.STARTER[g]) do
        if e.first and (take(e.t) or take(e.alt)) then extra = extra + 1 end
    end
    if take(BridgeData.STARTER_WEAPON[g]) then extra = extra + 1 end
    for _, n in pairs(have) do if n > 0 then return false end end
    local full = 1
    for _, e in ipairs(BridgeData.STARTER[g]) do if e.first then full = full + 1 end end
    return extra == 0 or extra == full
end




function BridgeData.untouched(rec)
    return BridgeData.itemsUntouched(rec) and BridgeData.lookUntouched(rec)
end


function BridgeData.wants(rec)
    return rec ~= nil and rec.want ~= false
end



function BridgeData.world(owner)
    local md = ModData.getOrCreate(BridgeData.KEY)
    if md.players == nil then md.players = {} end

    if not md.migrated and not isClient() then
        md.migrated = true
        pcall(function()
            if not ModData.exists(BridgeData.OLD_KEY) then return end
            local old = ModData.get(BridgeData.OLD_KEY)
            if old == nil then return end
            local who = old.owner or owner
            if who == nil then return end
            local rec = md.players[who] or {}
            if rec.items == nil and old.items ~= nil then
                rec.items = old.items
                rec.saved = old.saved
            end
            if rec.want == nil and old.want ~= nil then rec.want = old.want end
            rec.lastX, rec.lastY, rec.lastZ = old.lastX, old.lastY, old.lastZ

            rec.oldBodyId = old.bodyId
            md.players[who] = rec
        end)
    end
    return md
end


function BridgeData.ownerOf(md, pid)
    if md == nil or md.players == nil or pid == nil then return nil, nil end
    for who, rec in pairs(md.players) do
        if rec.bodyId == pid then return who, rec end
    end
    return nil, nil
end










BridgeData.REL_KEYS = { f = { -100, 100 }, r = { 0, 100 }, days = { 0, 100000 }, hours = { 0, 24 },
    day = { 0, 1000000 }, gainF = { -100, 100 }, gainR = { -100, 100 }, giftAt = { 0, 100000000 },
    seen = { 0, 100000000 }, askAt = { 0, 100000000 }, healAt = { 0, 100000000 },
    valuedAt = { 0, 100000000 },
    dressF = { 0, 100 }, dressR = { 0, 100 } }


function BridgeData.relOf(rec)
    if rec == nil then return nil end
    if type(rec.rel) ~= "table" then rec.rel = {} end
    local rel = rec.rel
    for k, _ in pairs(BridgeData.REL_KEYS) do
        if type(rel[k]) ~= "number" then rel[k] = 0 end
    end
    return rel
end



function BridgeData.cleanRel(t)
    if type(t) ~= "table" then return nil end
    local out = {}
    for k, range in pairs(BridgeData.REL_KEYS) do
        local v = tonumber(t[k])
        if v ~= nil and v == v then
            if v < range[1] then v = range[1] end
            if v > range[2] then v = range[2] end
            out[k] = v
        else
            out[k] = 0
        end
    end
    return out
end


function BridgeData.cleanCount(n)
    n = tonumber(n)
    if n == nil or n ~= n then return 0 end
    n = math.floor(n)
    if n < 0 then n = 0 end
    if n > 1000000000 then n = 1000000000 end
    return n
end


function BridgeData.relTier(rel)
    local f = rel and rel.f or 0
    if f < 0 then return "Cold" end
    if f < 20 then return "Known" end
    if f < 45 then return "Pal" end
    if f < 75 then return "Friend" end
    return "Close"
end

if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeData] loaded") end




BridgeData.SKILL_KEYS = { "Strength", "Axe", "Blunt", "SmallBlunt", "LongBlade", "SmallBlade", "Spear", "Maintenance", "Fitness" }




function BridgeData.skillCap(k)
    local cap = nil
    pcall(function() cap = PerkFactory.getPerk(Perks[k]):getTotalXpForLevel(10) end)
    return tonumber(cap)
end

function BridgeData.cleanSkills(t)
    if type(t) ~= "table" then return nil end
    local out = {}
    for i = 1, #BridgeData.SKILL_KEYS do
        local k = BridgeData.SKILL_KEYS[i]
        local v = tonumber(t[k])
        if v == nil or v ~= v or v < 0 then v = 0 end
        local cap = BridgeData.skillCap(k)
        if cap ~= nil and v > cap then v = cap end
        out[k] = v
    end
    return out
end


function BridgeData.skillsOf(rec)
    if rec == nil then return nil end
    if type(rec.skills) ~= "table" then rec.skills = {} end
    local s = rec.skills
    for i = 1, #BridgeData.SKILL_KEYS do
        local k = BridgeData.SKILL_KEYS[i]
        local v = tonumber(s[k])
        if v == nil or v ~= v or v < 0 then s[k] = 0 end
    end
    return s
end




BridgeData.STRENGTH_CARRY = { 15, 16, 17, 18, 20, 21, 23, 24, 25, 27, 29 }

function BridgeData.carryForStrengthLevel(level)
    level = math.max(0, math.min(10, math.floor(tonumber(level) or 0)))
    return BridgeData.STRENGTH_CARRY[level + 1]
end



function BridgeData.levelFromXp(perkKey, xp)
    local p = nil
    pcall(function() p = PerkFactory.getPerk(Perks[perkKey]) end)
    if p == nil then return 0 end
    xp = tonumber(xp) or 0
    local lvl = 0
    for n = 1, 10 do
        local total = nil
        pcall(function() total = p:getTotalXpForLevel(n) end)
        if total == nil or xp < total then break end
        lvl = n
    end
    return lvl
end
