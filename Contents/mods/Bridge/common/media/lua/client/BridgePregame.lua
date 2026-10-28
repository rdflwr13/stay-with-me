if BridgePregame ~= nil and BridgePregame.loaded == true then return end

pcall(function() require "OptionScreens/CharacterCreationMain" end)
pcall(function() require "OptionScreens/CharacterCreationAvatar" end)
require "ISUI/ISPanelJoypad"
require "ISUI/ISTabPanel"
require "ISUI/ISComboBox"
require "ISUI/ISButton"
require "ISUI/ISColorPicker"
require "ISUI/ISTickBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISUI3DModel"

BridgePregame = BridgePregame or {}

BridgePregame.FILE = "stay_with_me_pregame.txt"
BridgePregame.VERSION = 1
BridgePregame.active = false
BridgePregame.finishing = false

BridgePregame.OPTION_BOOLS = { "romance", "startUnarmed", "xpPopups", "fatigueBar", "sitWithRed", "exerciseWithMe" }

local function cleanAimMode(value)
    if type(BridgeData.cleanAimSense) == "function" then return BridgeData.cleanAimSense(value) end
    local n = tonumber(value)
    if n == 0 or n == 0.5 or n == 1 or n == 2 then return n end
    return nil
end

function BridgePregame.defaultOptions()
    return {
        romance = true,
        startUnarmed = false,
        xpPopups = false,
        fatigueBar = false,
        sitWithRed = true,
        exerciseWithMe = false,
        aimSense = BridgeData.DEFAULT_AIM_SENSE or 1,
    }
end

function BridgePregame.cleanOptions(src)
    local out = BridgePregame.defaultOptions()
    if type(src) ~= "table" then return out end
    for _, key in ipairs(BridgePregame.OPTION_BOOLS) do
        if type(src[key]) == "boolean" then out[key] = src[key] end
    end
    local mode = cleanAimMode(src.aimSense)
    if mode ~= nil then out.aimSense = mode end
    return out
end

function BridgePregame.optionsText(src)
    local opts = BridgePregame.cleanOptions(src)
    local parts = {}
    for _, key in ipairs(BridgePregame.OPTION_BOOLS) do
        parts[#parts + 1] = key .. "=" .. (opts[key] and "1" or "0")
    end
    parts[#parts + 1] = "aimSense=" .. tostring(opts.aimSense)
    return table.concat(parts, ",")
end

function BridgePregame.optionsFromText(text)
    local out = BridgePregame.defaultOptions()
    if type(text) ~= "string" or text == "" then return out end
    for part in string.gmatch(text, "[^,]+") do
        local key, value = string.match(part, "^([%a_]+)=(.*)$")
        if key ~= nil then
            if key == "aimSense" then
                local mode = cleanAimMode(value)
                if mode ~= nil then out.aimSense = mode end
            else
                for _, name in ipairs(BridgePregame.OPTION_BOOLS) do
                    if name == key then out[key] = (value == "1" or value == "true") break end
                end
            end
        end
    end
    return out
end

local PAD = 12
local UI_BORDER_SPACING = 10
local JOYPAD_TEX_SIZE = 32

local FONT_S, FONT_M, BTN_H = 0, 0, 0
local function refreshFonts()
    FONT_S = getTextManager():getFontHeight(UIFont.Small)
    FONT_M = getTextManager():getFontHeight(UIFont.Medium)
    BTN_H = FONT_S + 6
end
refreshFonts()

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgePregame] " .. tostring(text)) end
end

local function warn(text) print("[BridgePregame] " .. tostring(text)) end

local function textW(font, text)
    local w = 0
    pcall(function() w = getTextManager():MeasureStringX(font, tostring(text or "")) end)
    return w or 0
end

local function fitText(font, text, maxW)
    local value = tostring(text or "")
    if maxW == nil or maxW <= 0 or textW(font, value) <= maxW then return value end
    while #value > 0 and textW(font, value .. "...") > maxW do
        value = string.sub(value, 1, #value - 1)
    end
    return value .. "..."
end

local function tr(key, fallback, a)
    local text = fallback
    local full = "IGUI_NotAlone_" .. tostring(key)
    pcall(function()
        if a ~= nil then text = getText(full, a) else text = getText(full) end
    end)
    if type(text) ~= "string" or text == "" or text == full then return fallback end
    return text
end

local function vanillaText(key, fallback)
    if type(getTextOrNull) ~= "function" then return fallback end
    local text = getTextOrNull(key)
    if type(text) ~= "string" or text == "" or text == key then return fallback end
    return text
end

local function gameText(key, fallback)
    local text = nil
    pcall(function() text = getText(key) end)
    if type(text) ~= "string" or text == "" or text == key then return fallback end
    return text
end

local function esc(text)
    if BridgeLooks ~= nil and type(BridgeLooks.escape) == "function" then return BridgeLooks.escape(text) end
    return tostring(text or "")
end

local function unesc(text)
    if BridgeLooks == nil or type(BridgeLooks.unescape) ~= "function" then return nil end
    return BridgeLooks.unescape(text)
end

local function worldTag()
    local world, map, mode = "", "", ""
    pcall(function()
        if type(getWorld) ~= "function" then return end
        local w = getWorld()
        if w == nil then return end
        world = tostring(w:getWorld() or "")
        map = tostring(w:getMap() or "")
        mode = tostring(w:getGameMode() or "")
    end)
    return world, map, mode
end

local function showCreation()
    local ms = MainScreen.instance
    if ms == nil or ms.charCreationMain == nil then return end
    local joypad = nil
    pcall(function() joypad = JoypadState.getMainMenuJoypad() end)
    if joypad == nil then
        pcall(function() joypad = CoopCharacterCreation.getJoypad() end)
    end
    pcall(ms.charCreationMain.setVisible, ms.charCreationMain, true, joypad)
end

local function hideCreation()
    local ms = MainScreen.instance
    if ms == nil or ms.charCreationMain == nil then return end
    pcall(ms.charCreationMain.setVisible, ms.charCreationMain, false)
end

local function removeDraftFile()
    if type(getFileWriter) ~= "function" then return end
    local writer = nil
    pcall(function() writer = getFileWriter(BridgePregame.FILE, true, false) end)
    if writer == nil then return end
    pcall(function() writer:write("") end)
    pcall(function() writer:close() end)
end

BridgePregame.removeDraftFile = removeDraftFile

local function lookFrom(text)
    if type(text) ~= "string" or text == "" then return nil end
    if BridgeLooks == nil or type(BridgeLooks.parse) ~= "function" then return nil end
    local look = nil
    pcall(function() look = BridgeLooks.parse(text) end)
    return look
end

function BridgePregame.readDraft()
    if type(getFileReader) ~= "function" then return nil end
    local reader = nil
    pcall(function() reader = getFileReader(BridgePregame.FILE, false) end)
    if reader == nil or type(reader.readLine) ~= "function" then
        pcall(function() if reader ~= nil then reader:close() end end)
        return nil
    end
    local fields, guard, bad, seen = {}, 0, false, false
    while guard < 40 do
        guard = guard + 1
        local line = nil
        pcall(function() line = reader:readLine() end)
        if line == nil or type(line) ~= "string" then break end
        if string.sub(line, -1) == "\r" then line = string.sub(line, 1, -2) end
        if line ~= "" then
            seen = true
            if #line > 8000 then bad = true break end
            local key, value = string.match(line, "^([A-Z_]+)=(.*)$")
            if key == nil then bad = true break end
            local plain = unesc(value)
            if plain == nil then bad = true break end
            fields[key] = plain
        end
    end
    pcall(function() reader:close() end)
    local function reject(reason)
        if seen and BridgePregame.badLogged ~= true then
            BridgePregame.badLogged = true
            log("draft ignored: " .. tostring(reason))
        end
        return nil
    end
    if bad then return reject("malformed file") end
    if fields.VERSION ~= tostring(BridgePregame.VERSION) then return reject("unsupported version") end
    local gender = fields.GENDER
    if gender ~= "male" and gender ~= "female" then return reject("bad gender") end
    if type(fields.WORLD) ~= "string" or type(fields.MAP) ~= "string" or type(fields.MODE) ~= "string" then
        return reject("missing world binding")
    end
    local draft = {
        world = fields.WORLD,
        map = fields.MAP,
        mode = fields.MODE,
        gender = gender,
        name = fields.NAME or "",
        maleName = fields.MALENAME or "",
        femaleLook = lookFrom(fields.LOOK_F),
        maleLook = lookFrom(fields.LOOK_M),
        options = BridgePregame.optionsFromText(fields.OPTIONS),
    }
    draft.store = { gender = gender }
    local voiceF, voiceM = nil, nil
    local speciesF, speciesM = nil, nil
    local clothF, clothM = nil, nil
    if type(BridgeAppearance) == "table" then
        if type(BridgeAppearance.voiceFromToken) == "function" then
            pcall(function() voiceF = BridgeAppearance.voiceFromToken(fields.VOICE_F, "female") end)
            pcall(function() voiceM = BridgeAppearance.voiceFromToken(fields.VOICE_M, "male") end)
        end
        if type(BridgeAppearance.speciesName) == "function" then
            pcall(function() speciesF = BridgeAppearance.speciesName(fields.SPECIES_F) end)
            pcall(function() speciesM = BridgeAppearance.speciesName(fields.SPECIES_M) end)
        end
        if type(BridgeAppearance.clothFromToken) == "function" then
            pcall(function() clothF = BridgeAppearance.clothFromToken(fields.CLOTH_F) end)
            pcall(function() clothM = BridgeAppearance.clothFromToken(fields.CLOTH_M) end)
        end
    end
    draft.voiceFemale = voiceF or BridgeData.defaultVoice("female")
    draft.voiceMale = voiceM or BridgeData.defaultVoice("male")
    draft.speciesFemale = speciesF or "Hooman"
    draft.speciesMale = speciesM or "Hooman"
    draft.clothFemale = clothF or BridgePregame.starterClothing("female")
    draft.clothMale = clothM or BridgePregame.starterClothing("male")
    return draft
end

function BridgePregame.writeDraft(draft)
    if type(draft) ~= "table" then return false end
    if type(getFileWriter) ~= "function" then return false end
    local femaleLook, maleLook = "", ""
    if draft.femaleLook ~= nil and BridgeLooks ~= nil and type(BridgeLooks.encodeLook) == "function" then
        pcall(function() femaleLook = BridgeLooks.encodeLook(draft.femaleLook) or "" end)
    end
    if draft.maleLook ~= nil and BridgeLooks ~= nil and type(BridgeLooks.encodeLook) == "function" then
        pcall(function() maleLook = BridgeLooks.encodeLook(draft.maleLook) or "" end)
    end
    local voiceF, voiceM, speciesF, speciesM, clothF, clothM = "", "", "", "", "", ""
    if type(BridgeAppearance) == "table" then
        if type(BridgeAppearance.voiceToken) == "function" then
            pcall(function() voiceF = BridgeAppearance.voiceToken(draft.voiceFemale, "female") or "" end)
            pcall(function() voiceM = BridgeAppearance.voiceToken(draft.voiceMale, "male") or "" end)
        end
        if type(BridgeAppearance.clothToken) == "function" then
            pcall(function() clothF = BridgeAppearance.clothToken(draft.clothFemale) end)
            pcall(function() clothM = BridgeAppearance.clothToken(draft.clothMale) end)
        end
    end
    if type(draft.speciesFemale) == "string" then speciesF = draft.speciesFemale end
    if type(draft.speciesMale) == "string" then speciesM = draft.speciesMale end
    local lines = {
        "VERSION=" .. tostring(BridgePregame.VERSION),
        "WORLD=" .. esc(draft.world),
        "MAP=" .. esc(draft.map),
        "MODE=" .. esc(draft.mode),
        "GENDER=" .. esc(draft.gender),
        "NAME=" .. esc(draft.name),
        "MALENAME=" .. esc(draft.maleName),
        "LOOK_F=" .. esc(femaleLook),
        "LOOK_M=" .. esc(maleLook),
        "VOICE_F=" .. esc(voiceF),
        "VOICE_M=" .. esc(voiceM),
        "SPECIES_F=" .. esc(speciesF),
        "SPECIES_M=" .. esc(speciesM),
        "CLOTH_F=" .. esc(clothF),
        "CLOTH_M=" .. esc(clothM),
        "OPTIONS=" .. esc(BridgePregame.optionsText(draft.options)),
    }
    local writer = nil
    pcall(function() writer = getFileWriter(BridgePregame.FILE, true, false) end)
    if writer == nil or type(writer.write) ~= "function" then return false end
    local ok = pcall(function() writer:write(table.concat(lines, "\n") .. "\n") end)
    pcall(function() writer:close() end)
    return ok
end

local STARTER_LOC = {
    ["Base.Tshirt_WhiteTINT"] = "Tshirt",
    ["Base.Trousers_Denim"] = "Pants",
    ["Base.Shoes_CowboyBoots_Black"] = "Shoes",
    ["Base.Shoes_WorkBoots"] = "Shoes",
    ["Base.Belt2"] = "Belt",
    ["Base.Jacket_SheepSkin_Navy"] = "Jacket",
    ["Base.Jacket_PaddedDOWN"] = "Jacket",
    ["Base.Shirt_Denim"] = "Shirt",
    ["Base.Glasses_Normal"] = "Eyes",
}

BridgePregame.clothTintCache = BridgePregame.clothTintCache or {}

function BridgePregame.defaultClothTint(entry)
    if type(entry) ~= "table" or type(entry.t) ~= "string" then return nil end
    local key = tostring(entry.t) .. "|" .. tostring(entry.tc) .. "|" .. tostring(entry.bt)
    local cached = BridgePregame.clothTintCache[key]
    if cached ~= nil then return cached or nil end
    local item = nil
    pcall(function() item = instanceItem(entry.t) end)
    if item == nil and type(entry.alt) == "string" then
        pcall(function() item = instanceItem(entry.alt) end)
    end
    if item == nil then return nil end
    local color = nil
    pcall(function() color = item:getVisual():getTint(item:getClothingItem()) end)
    local tint = nil
    if color ~= nil then
        tint = { color:getRedFloat(), color:getGreenFloat(), color:getBlueFloat() }
        BridgePregame.clothTintCache[key] = tint
    else
        BridgePregame.clothTintCache[key] = false
    end
    return tint
end

function BridgePregame.captureClothTint(list)
    for _, entry in ipairs(list or {}) do
        if type(entry) == "table" and entry.tint == nil then
            local tint = BridgePregame.defaultClothTint(entry)
            if tint ~= nil then entry.tint = tint end
        end
    end
end

function BridgePregame.starterClothing(gender)
    local out, seen = {}, {}
    local list = nil
    if type(BridgeData.STARTER) == "table" then list = BridgeData.STARTER[gender] end
    for _, e in ipairs(list or {}) do
        if type(e) == "table" and type(e.t) == "string" then
            local item = nil
            pcall(function() item = instanceItem(e.t) end)
            if item == nil and type(e.alt) == "string" then
                pcall(function() item = instanceItem(e.alt) end)
            end
            local loc = nil
            if item ~= nil then
                pcall(function()
                    if item:IsClothing() then loc = item:getBodyLocation() end
                    if loc == nil then loc = item:canBeEquipped() end
                end)
            end
            if type(loc) ~= "string" or loc == "" then
                loc = STARTER_LOC[e.t] or (type(e.alt) == "string" and STARTER_LOC[e.alt] or nil)
            end
            if type(loc) == "string" and loc ~= "" and not seen[loc] then
                seen[loc] = true
                out[#out + 1] = {
                    loc = loc,
                    t = e.t,
                    alt = e.alt,
                    tc = e.tc,
                    bt = e.bt,
                    tint = e.tint,
                    altTint = e.altTint,
                }
            end
        end
    end
    BridgePregame.captureClothTint(out)
    return out
end

function BridgePregame.activeVoice(draft)
    if type(draft) ~= "table" then return nil end
    if draft.gender == "male" then return draft.voiceMale end
    return draft.voiceFemale
end

function BridgePregame.activeSpecies(draft)
    if type(draft) ~= "table" then return nil end
    if draft.gender == "male" then return draft.speciesMale end
    return draft.speciesFemale
end

function BridgePregame.activeClothing(draft)
    if type(draft) ~= "table" then return nil end
    if draft.gender == "male" then return draft.clothMale end
    return draft.clothFemale
end

function BridgePregame.setActiveVoice(draft, voice)
    if type(draft) ~= "table" then return end
    if draft.gender == "male" then draft.voiceMale = voice else draft.voiceFemale = voice end
end

function BridgePregame.setActiveSpecies(draft, species)
    if type(draft) ~= "table" then return end
    if draft.gender == "male" then draft.speciesMale = species else draft.speciesFemale = species end
end

function BridgePregame.setActiveClothing(draft, clothing)
    if type(draft) ~= "table" then return end
    if draft.gender == "male" then draft.clothMale = clothing else draft.clothFemale = clothing end
end

function BridgePregame.newDraft()
    local world, map, mode = worldTag()
    local companion = "female"
    pcall(function()
        local desc = MainScreen.instance ~= nil and MainScreen.instance.desc or nil
        if desc ~= nil and desc:isFemale() then companion = "male" end
    end)
    return {
        world = world,
        map = map,
        mode = mode,
        gender = companion,
        name = BridgeData.DEFAULT_NAME,
        maleName = BridgeData.DEFAULT_MALE_NAME,
        femaleLook = nil,
        maleLook = nil,
        voiceFemale = BridgeData.defaultVoice("female"),
        voiceMale = BridgeData.defaultVoice("male"),
        speciesFemale = "Hooman",
        speciesMale = "Hooman",
        clothFemale = BridgePregame.starterClothing("female"),
        clothMale = BridgePregame.starterClothing("male"),
        options = BridgePregame.defaultOptions(),
        store = { gender = companion },
    }
end

local function draftMatchesWorld(draft)
    if type(draft) ~= "table" then return false end
    local world, map, mode = worldTag()
    return draft.world == world and draft.map == map and draft.mode == mode
end

function BridgePregame.ensureDraft()
    local draft = BridgePregame.draft
    if draft ~= nil and draftMatchesWorld(draft) then return draft end
    draft = BridgePregame.newDraft()
    BridgePregame.draft = draft
    return draft
end

function BridgePregame.consumeInto(store)
    if type(store) ~= "table" then return false end
    if type(Bridge) ~= "table" or Bridge.mp then return false end
    if Bridge.gotData ~= true then return false end
    local draft = BridgePregame.readDraft()
    if draft == nil then return false end
    local world, map, mode = worldTag()
    if draft.world ~= world or draft.map ~= map or draft.mode ~= mode then
        log("draft rejected: world mismatch")
        removeDraftFile()
        return false
    end
    if type(BridgeData.neverSpawned) ~= "function" or not BridgeData.neverSpawned(store) then
        log("draft rejected: companion already spawned")
        removeDraftFile()
        return false
    end
    if BridgeAppearance == nil or type(BridgeAppearance.defaultCandidate) ~= "function" then return false end
    local gender = draft.gender
    local candidate = BridgeAppearance.defaultCandidate(gender)
    local look = nil
    if gender == "male" then look = draft.maleLook else look = draft.femaleLook end
    if look ~= nil and BridgeLooks ~= nil and type(BridgeLooks.applyTo) == "function" then
        local ok, err = pcall(BridgeLooks.applyTo, look, candidate, gender)
        if not ok then warn("draft look rejected: " .. tostring(err)) end
    end
    store.gender = gender
    if gender == "male" then
        store.maleName = BridgeData.cleanName(draft.maleName) or BridgeData.DEFAULT_MALE_NAME
    else
        store.name = BridgeData.cleanName(draft.name) or BridgeData.DEFAULT_NAME
    end
    BridgeAppearance.applyToRecord(store, candidate, gender)
    local voice = BridgeData.cleanVoice((gender == "male") and draft.voiceMale or draft.voiceFemale, gender)
    if voice ~= nil then
        local app = BridgeData.appearanceOf(store)
        if type(app) == "table" then app.voice = voice end
    end
    local clothing = (gender == "male") and draft.clothMale or draft.clothFemale
    if type(clothing) == "table" then store.pregameOutfit = BridgeAppearance.copyClothing(clothing) end
    local species = (gender == "male") and draft.speciesMale or draft.speciesFemale
    if type(species) == "string" and species ~= "" and species ~= "Hooman" then
        store.pregameFur = species
    end
    local opts = BridgePregame.cleanOptions(draft.options)
    for _, key in ipairs(BridgePregame.OPTION_BOOLS) do store[key] = opts[key] end
    store.aimSense = opts.aimSense
    removeDraftFile()
    BridgePregame.draft = nil
    log("draft applied: gender=" .. tostring(gender) .. " look=" .. tostring(look ~= nil)
        .. " cloth=" .. tostring(type(clothing) == "table" and #clothing or 0))
    return true
end

BridgePregameScreen = ISPanelJoypad:derive("BridgePregameScreen")

local CLOTH_FIXED = { "Belt", "Hat", "Eyes", "TankTop", "Shirt", "Tshirt", "Jacket", "Pants", "Skirt", "Dress", "Socks", "Shoes", "Necklace" }

local function itemExists(itemType)
    if type(itemType) ~= "string" or itemType == "" then return false end
    local script = nil
    pcall(function() script = ScriptManager.instance:FindItem(itemType) end)
    return script ~= nil
end

local function itemLabel(itemType)
    local label = nil
    pcall(function()
        local script = ScriptManager.instance:FindItem(itemType)
        if script ~= nil then label = script:getDisplayName() end
    end)
    if type(label) ~= "string" or label == "" then return tostring(itemType) end
    return label
end

local function textureLabel(index)
    local text = nil
    pcall(function() text = getText("UI_ClothingTextureType", index) end)
    if type(text) ~= "string" or text == "" or text == "UI_ClothingTextureType" then
        return "Texture " .. tostring(index)
    end
    return text
end

local function readableText(color)
    local r, g, b = tonumber(color and color.r) or 0, tonumber(color and color.g) or 0, tonumber(color and color.b) or 0
    if r * 0.299 + g * 0.587 + b * 0.114 > 0.55 then return 0.05, 0.05, 0.05 end
    return 1, 1, 1
end

local BEHAVIOR_DEFS = {
    { key = "romance", label = "OptRomance", tip = "OptRomanceTip" },
    { key = "startUnarmed", label = "OptStartUnarmed", tip = "OptStartUnarmedTip" },
    { key = "xpPopups", label = "OptXpPopups", tip = "OptXpPopupsTip" },
    { key = "fatigueBar", label = "OptFatigueBar", tip = "OptFatigueBarTip" },
    { key = "sitWithRed", label = "OptSitWithRed", tip = "OptSitWithRedTip" },
    { key = "exerciseWithMe", label = "OptExerciseWithMe", tip = "OptExerciseWithMeTip" },
}

local function genderedText(key, fallback, gender)
    if gender == "male" then
        local male = tr(tostring(key) .. "Male", nil)
        if type(male) == "string" and male ~= "" then return male end
    end
    return tr(key, fallback)
end

local SKIN_COLORS = {
    { r = 1, g = 0.91, b = 0.72 },
    { r = 0.98, g = 0.79, b = 0.49 },
    { r = 0.8, g = 0.65, b = 0.45 },
    { r = 0.54, g = 0.38, b = 0.25 },
    { r = 0.36, g = 0.25, b = 0.14 },
}

local function paintButton(button, color)
    if button == nil or type(color) ~= "table" then return end
    button.backgroundColor = { r = color.r, g = color.g, b = color.b, a = 1 }
    local tr, tg, tb = readableText(color)
    button.textColor = { r = tr, g = tg, b = tb, a = 1 }
end

local function comboReset(combo)
    if combo == nil then return end
    combo.options = {}
    combo.selected = 0
    combo.__hoverIndex = nil
end

local function comboAdd(combo, label, data)
    if combo == nil then return end
    combo:addOptionWithData(tostring(label), data)
end

local function comboSelect(combo, data)
    if combo == nil or type(combo.options) ~= "table" then return end
    combo.selected = 0
    for i = 1, #combo.options do
        if combo:getOptionData(i) == data then combo.selected = i return end
    end
end

local function comboSameText(combo, text)
    if combo == nil or type(combo.options) ~= "table" then return nil end
    for i = 1, #combo.options do
        if combo.options[i] == text then return i end
    end
    return nil
end

local function clothingItemFor(entry)
    if type(entry) ~= "table" or type(entry.t) ~= "string" then return nil end
    local item = nil
    pcall(function() item = instanceItem(entry.t) end)
    if item == nil and type(entry.alt) == "string" then
        pcall(function() item = instanceItem(entry.alt) end)
    end
    return item
end

local function textureInfo(entry)
    local item = clothingItemFor(entry)
    if item == nil then return nil end
    local ci = nil
    pcall(function() ci = item:getClothingItem() end)
    if ci == nil then return nil end
    local hasModel = false
    pcall(function() hasModel = ci:hasModel() == true end)
    local choices = nil
    pcall(function() choices = hasModel and ci:getTextureChoices() or ci:getBaseTextures() end)
    if choices == nil then return nil end
    local count = 0
    pcall(function() count = choices:size() end)
    if count <= 1 then return nil end
    local kind = hasModel and "tc" or "bt"
    local current = tonumber(entry[kind]) or 0
    if current < 0 then current = 0 end
    if current > count - 1 then current = count - 1 end
    return { kind = kind, count = count, current = current }
end

local function allowsTint(entry)
    local item = clothingItemFor(entry)
    if item == nil then return false end
    local ok = false
    pcall(function() ok = item:getClothingItem():getAllowRandomTint() == true end)
    return ok
end

local function entryTint(entry)
    if type(entry.tint) == "table" then
        return { r = tonumber(entry.tint[1]) or 1, g = tonumber(entry.tint[2]) or 1, b = tonumber(entry.tint[3]) or 1 }
    end
    local item = clothingItemFor(entry)
    local color = nil
    pcall(function() color = item:getVisual():getTint(item:getClothingItem()) end)
    if color ~= nil then
        return { r = color:getRedFloat(), g = color:getGreenFloat(), b = color:getBlueFloat() }
    end
    return { r = 1, g = 1, b = 1 }
end

function BridgePregameScreen:definition(loc, gender)
    local def = nil
    pcall(function()
        local list = ClothingSelectionDefinitions.default
        local side = (gender == "male") and list.Male or list.Female
        def = side and side[loc] or nil
    end)
    return def
end

function BridgePregameScreen:availableLocations(gender)
    local set = {}
    local def = nil
    pcall(function()
        local list = ClothingSelectionDefinitions.default
        def = (gender == "male") and list.Male or list.Female
    end)
    for loc in pairs(def or {}) do set[loc] = true end
    local starters = self.starterByGender[gender] or {}
    for _, e in ipairs(starters) do set[e.loc] = true end
    return set
end

function BridgePregameScreen:clothOptions(loc, gender)
    local out, seen = {}, {}
    local def = self:definition(loc, gender)
    for _, itemType in ipairs(def and def.items or {}) do
        if itemExists(itemType) and not seen[itemType] then
            seen[itemType] = true
            out[#out + 1] = { t = itemType, label = itemLabel(itemType) }
        end
    end
    local starters = self.starterByGender[gender] or {}
    for _, e in ipairs(starters) do
        if e.loc == loc then
            if itemExists(e.t) and not seen[e.t] then
                seen[e.t] = true
                out[#out + 1] = { t = e.t, label = itemLabel(e.t) }
            end
            if itemExists(e.alt) and not seen[e.alt] then
                seen[e.alt] = true
                out[#out + 1] = { t = e.alt, label = itemLabel(e.alt) }
            end
        end
    end
    return out
end

function BridgePregameScreen:buildClothOrder()
    local set = {}
    local function addDef(gender)
        local def = nil
        pcall(function()
            local list = ClothingSelectionDefinitions.default
            def = (gender == "male") and list.Male or list.Female
        end)
        for loc in pairs(def or {}) do set[loc] = true end
    end
    addDef("female")
    addDef("male")
    self.starterByGender = {
        female = BridgePregame.starterClothing("female"),
        male = BridgePregame.starterClothing("male"),
    }
    for _, list in pairs(self.starterByGender) do
        for _, e in ipairs(list) do set[e.loc] = true end
    end
    local order, used, extras = {}, {}, {}
    for _, loc in ipairs(CLOTH_FIXED) do
        if set[loc] then order[#order + 1] = loc used[loc] = true end
    end
    for loc in pairs(set) do if not used[loc] then extras[#extras + 1] = loc end end
    table.sort(extras)
    for _, loc in ipairs(extras) do order[#order + 1] = loc end
    self.clothOrder = order
end

function BridgePregameScreen:createChildren()
    ISPanelJoypad.createChildren(self)
    refreshFonts()

    self.brandText = tr("PregameBrand", "Stay With Me")
    self.titleText = tr("PregameTitle", "Companion")
    self.genderText = tr("Gender", "Gender")
    self.nameText = tr("PregameName", "Name")
    self.lookText = tr("PregameLook", "Saved look")
    self.backText = vanillaText("UI_btn_back", "Back")
    self.startText = vanillaText("UI_btn_play", tr("PregameStart", "Play"))
    self.randomText = vanillaText("UI_characreation_random", "Random")
    self.saveText = vanillaText("UI_characreation_BuildSave", "Save")
    self.delText = vanillaText("UI_characreation_BuildDel", "Del")
    self.addText = tr("PregameAdd", "Add")
    self.removeText = tr("PregameRemove", "Remove")
    self.clearText = tr("PregameClear", "Clear")
    self.noneText = tr("AppearanceNone", "None")

    self.avatar = CharacterCreationAvatar:new(0, 0, 120, 240)
    self.avatar:initialise()
    self.avatar:instantiate()
    self:addChild(self.avatar)
    self.preview = self.avatar.avatarPanel

    self.randomBtn = ISButton:new(0, 0, 10, BTN_H, self.randomText, self, BridgePregameScreen.onRandom)
    self.randomBtn:initialise()
    self.randomBtn:instantiate()
    self:addChild(self.randomBtn)

    self.genderCombo = ISComboBox:new(0, 0, 120, BTN_H, self, BridgePregameScreen.onGender)
    self.genderCombo:initialise()
    self.genderCombo:addOptionWithData(tr("GenderFemale", "Female"), "female")
    self.genderCombo:addOptionWithData(tr("GenderMale", "Male"), "male")
    self:addChild(self.genderCombo)

    self.nameEntry = ISTextEntryBox:new("", 0, 0, 120, BTN_H)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    pcall(function() self.nameEntry:setMaxTextLength(BridgeData.NAME_MAX) end)
    self:addChild(self.nameEntry)

    self.skinColorBtn = ISButton:new(0, 0, BTN_H, BTN_H, "", self, BridgePregameScreen.onSkinColor)
    self.skinColorBtn:initialise()
    self.skinColorBtn:instantiate()
    self:addChild(self.skinColorBtn)

    self.skinPicker = ISColorPicker:new(0, 0, nil)
    self.skinPicker:initialise()
    self.skinPicker.keepOnScreen = true
    self.skinPicker.pickedTarget = self
    self.skinPicker.resetFocusTo = self
    self.skinPicker:setColors(SKIN_COLORS, #SKIN_COLORS, 1)
    self.skinPicker:setPickedFunc(BridgePregameScreen.onSkinColorPicked)

    self.muscleCombo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onMuscle)
    self.muscleCombo:initialise()
    self:addChild(self.muscleCombo)

    self.speciesCombo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onSpecies)
    self.speciesCombo:initialise()
    self:addChild(self.speciesCombo)

    self.voiceCombo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onVoice)
    self.voiceCombo:initialise()
    self:addChild(self.voiceCombo)

    self.voiceDemoBtn = ISButton:new(0, 0, 10, BTN_H, vanillaText("UI_characreation_playdemovoice", "Voice Preview"), self, BridgePregameScreen.onVoiceDemo)
    self.voiceDemoBtn:initialise()
    self.voiceDemoBtn:instantiate()
    self:addChild(self.voiceDemoBtn)

    self.hairCombo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onHair)
    self.hairCombo:initialise()
    self:addChild(self.hairCombo)

    self.hairColorBtn = ISButton:new(0, 0, 10, BTN_H, "", self, BridgePregameScreen.onHairColor)
    self.hairColorBtn:initialise()
    self.hairColorBtn:instantiate()
    self:addChild(self.hairColorBtn)

    self.beardCombo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onBeard)
    self.beardCombo:initialise()
    self:addChild(self.beardCombo)

    self.beardColorBtn = ISButton:new(0, 0, 10, BTN_H, "", self, BridgePregameScreen.onBeardColor)
    self.beardColorBtn:initialise()
    self.beardColorBtn:instantiate()
    self:addChild(self.beardColorBtn)

    self.faceCombo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onFace)
    self.faceCombo:initialise()
    self:addChild(self.faceCombo)

    self.detailCombo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onDetailPick)
    self.detailCombo:initialise()
    self:addChild(self.detailCombo)

    self.detailBtn = ISButton:new(0, 0, 10, BTN_H, self.addText, self, BridgePregameScreen.onDetailToggle)
    self.detailBtn:initialise()
    self.detailBtn:instantiate()
    self:addChild(self.detailBtn)

    self.detailClearBtn = ISButton:new(0, 0, 10, BTN_H, self.clearText, self, BridgePregameScreen.onDetailClear)
    self.detailClearBtn:initialise()
    self.detailClearBtn:instantiate()
    self:addChild(self.detailClearBtn)

    local behaviorGender = self.draft ~= nil and self.draft.gender or "female"
    self.behaviorTitle = tr("PregameBehavior", "Companion behavior")
    self.behaviorTicks = {}
    for i, def in ipairs(BEHAVIOR_DEFS) do
        local tick = ISTickBox:new(0, 0, 10, BTN_H, "", self, BridgePregameScreen.onBehaviorTick, def.key)
        tick:initialise()
        tick:instantiate()
        tick:addOption(genderedText(def.label, def.label, behaviorGender))
        tick.tooltip = genderedText(def.tip, def.tip, behaviorGender)
        self:addChild(tick)
        self.behaviorTicks[i] = tick
    end

    self.aimCombo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onAimSense)
    self.aimCombo:initialise()
    for _, lvl in ipairs(BridgeData.AIM_LEVELS or {}) do
        self.aimCombo:addOptionWithData(tr(lvl.label, lvl.label), lvl.value, tr(lvl.tip, lvl.tip))
    end
    self:addChild(self.aimCombo)

    self.makeupCombos = {}
    self.makeupOrder = {}
    local defs = rawget(_G, "MakeUpDefinitions")
    local cats = { "FullFace", "Eyes", "EyesShadow", "Lips" }
    for _, cat in ipairs(cats) do
        local info = defs ~= nil and defs.categories ~= nil and defs.categories[cat] or nil
        if info ~= nil then
            local combo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onMakeup)
            combo:initialise()
            combo.category = cat
            self:addChild(combo)
            self.makeupCombos[cat] = combo
            self.makeupOrder[#self.makeupOrder + 1] = cat
        end
    end

    self:buildClothOrder()
    self.clothRows = {}
    for _, loc in ipairs(self.clothOrder) do
        local combo = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onClothType)
        combo:initialise()
        combo.loc = loc
        self:addChild(combo)
        local color = ISButton:new(0, 0, BTN_H, BTN_H, "", self, BridgePregameScreen.onClothColor)
        color:initialise()
        color:instantiate()
        color.loc = loc
        self:addChild(color)
        local tex = ISComboBox:new(0, 0, 10, BTN_H, self, BridgePregameScreen.onClothTexture)
        tex:initialise()
        tex.loc = loc
        self:addChild(tex)
        self.clothRows[loc] = { combo = combo, color = color, tex = tex }
    end

    self.lookCombo = ISComboBox:new(0, 0, 120, BTN_H, self, BridgePregameScreen.onLook)
    self.lookCombo:initialise()
    self.lookCombo.openUpwards = true
    self.lookCombo.noSelectionText = vanillaText("UI_characreation_SelectToLoad", "[--Select to load--]")
    self:addChild(self.lookCombo)

    self.saveBtn = ISButton:new(0, 0, 10, BTN_H, self.saveText, self, BridgePregameScreen.onSave)
    self.saveBtn:initialise()
    self.saveBtn:instantiate()
    self.saveBtn:enableAcceptColor()
    self:addChild(self.saveBtn)

    self.deleteBtn = ISButton:new(0, 0, 10, BTN_H, self.delText, self, BridgePregameScreen.onDelete)
    self.deleteBtn:initialise()
    self.deleteBtn:instantiate()
    self.deleteBtn:enableCancelColor()
    self.deleteBtn:setEnable(false)
    self:addChild(self.deleteBtn)

    self.backBtn = ISButton:new(0, 0, 10, BTN_H, self.backText, self, BridgePregameScreen.onBack)
    self.backBtn:initialise()
    self.backBtn:instantiate()
    self.backBtn:enableCancelColor()
    self:addChild(self.backBtn)

    self.startBtn = ISButton:new(0, 0, 10, BTN_H, self.startText, self, BridgePregameScreen.onStart)
    self.startBtn:initialise()
    self.startBtn:instantiate()
    self.startBtn:setEnable(true)
    self.startBtn:setSound("activate", "UIActivatePlayButton")
    self.startBtn:enableAcceptColor()
    self:addChild(self.startBtn)

    BridgeAppearance.onClothingColor = function(loc, color)
        local screen = BridgePregame.screen
        if screen ~= nil then screen:setClothTint(loc, color) end
    end

    self:installHoverPreviews()
    self:rebuildControls()
end

function BridgePregameScreen:applyTabVisibility()
    self:refresh()
    self:layout()
end

function BridgePregameScreen:rebuildControls()
    local draft = self.draft
    if draft == nil then return end
    local gender = draft.gender
    self.filling = true

    comboReset(self.muscleCombo)
    local muscle = nil
    pcall(function() muscle = BridgeData.spnccMuscle(gender) end)
    self.muscleVisible = muscle ~= nil
    if self.muscleVisible then
        for level = 0, BridgeData.MUSCLE_MAX do
            comboAdd(self.muscleCombo, tr("Muscle_" .. tostring(level)), level)
        end
    end

    comboReset(self.speciesCombo)
    self.speciesVisible = BridgeAppearance.furOn() == true
    if self.speciesVisible then
        comboAdd(self.speciesCombo, vanillaText("IGUI_NotAlone_AppearanceHuman", "Human"), "Hooman")
        local fur = {}
        pcall(function() fur = BridgeAppearance.Catalog.furEntries() end)
        for _, e in ipairs(fur) do
            comboAdd(self.speciesCombo, tostring(e.label), e.name)
        end
    end

    comboReset(self.voiceCombo)
    local styles = {}
    if BridgeVoice ~= nil and type(BridgeVoice.stylesFor) == "function" then
        pcall(function() styles = BridgeVoice.stylesFor(gender) end)
    end
    if type(styles) ~= "table" or #styles == 0 then styles = { BridgeData.defaultVoice(gender) } end
    for i = 1, #styles do
        local style = styles[i]
        comboAdd(self.voiceCombo, vanillaText("IGUI_Voice_" .. tostring(style.name), tostring(style.name)), style)
    end

    comboReset(self.hairCombo)
    local hair = {}
    pcall(function()
        if BridgeWindow ~= nil and type(BridgeWindow.hairStyles) == "function" then
            hair = BridgeWindow.hairStyles(gender) or {}
        end
    end)
    for _, e in ipairs(hair) do comboAdd(self.hairCombo, tostring(e.label), e.id) end

    comboReset(self.beardCombo)
    self.beardVisible = gender == "male"
    if self.beardVisible then
        local beards = {}
        pcall(function()
            if BridgeWindow ~= nil and type(BridgeWindow.beardStyles) == "function" then
                beards = BridgeWindow.beardStyles() or {}
            end
        end)
        for _, e in ipairs(beards) do comboAdd(self.beardCombo, tostring(e.label), e.id) end
        if #beards == 0 then self.beardVisible = false end
    end

    comboReset(self.faceCombo)
    local faces = {}
    pcall(function() faces = BridgeData.spnccFaces(gender) or {} end)
    self.faceVisible = #faces > 0
    if self.faceVisible then
        local entries = {}
        pcall(function() entries = BridgeAppearance.Catalog.faceEntries() end)
        for _, e in ipairs(entries) do comboAdd(self.faceCombo, tostring(e.label), e.name) end
    end

    comboReset(self.detailCombo)
    local details = {}
    pcall(function() details = BridgeAppearance.Catalog.detailEntries() end)
    self.detailsVisible = #details > 0
    for _, e in ipairs(details) do comboAdd(self.detailCombo, tostring(e.label), e.name) end

    for _, cat in ipairs(self.makeupOrder) do
        local combo = self.makeupCombos[cat]
        comboReset(combo)
        comboAdd(combo, self.noneText, nil)
        local defs = rawget(_G, "MakeUpDefinitions")
        if defs ~= nil and type(defs.makeup) == "table" then
            for _, m in ipairs(defs.makeup) do
                if m.category == cat then
                    comboAdd(combo, gameText("MakeUpType_" .. tostring(m.name), tostring(m.name)), m.item)
                end
            end
        end
    end

    self:rebuildClothing(gender)
    self.missingVoiceKey = nil
    self.filling = false
    self:refresh()
end

function BridgePregameScreen:rebuildClothing(gender)
    self.clothAvailable = self:availableLocations(gender)
    for _, loc in ipairs(self.clothOrder) do
        local row = self.clothRows[loc]
        if self.clothAvailable[loc] then
            comboReset(row.combo)
            comboAdd(row.combo, self.noneText, nil)
            for _, option in ipairs(self:clothOptions(loc, gender)) do
                comboAdd(row.combo, option.label, option.t)
            end
        else
            row.combo:setVisible(false)
            row.color:setVisible(false)
            row.tex:setVisible(false)
        end
    end
end

function BridgePregameScreen:refreshClothing()
    local draft = self.draft
    if draft == nil then return end
    local clothing = BridgePregame.activeClothing(draft) or {}
    local allowed = self.clothAvailable or {}
    for _, loc in ipairs(self.clothOrder) do
        local row = self.clothRows[loc]
        if allowed[loc] then
            row.combo:setVisible(true)
            local entry = BridgeAppearance.clothingAt(clothing, loc)
            if entry ~= nil then
                comboSelect(row.combo, entry.t)
                local info = textureInfo(entry)
                if info ~= nil then
                    row.tex:setVisible(true)
                    comboReset(row.tex)
                    for i = 0, info.count - 1 do
                        comboAdd(row.tex, textureLabel(i + 1), i)
                    end
                    comboSelect(row.tex, info.current)
                else
                    row.tex:setVisible(false)
                end
                if allowsTint(entry) then
                    row.color:setVisible(true)
                    paintButton(row.color, entryTint(entry))
                else
                    row.color:setVisible(false)
                end
            else
                row.combo.selected = 1
                row.tex:setVisible(false)
                row.color:setVisible(false)
            end
        else
            row.combo:setVisible(false)
            row.color:setVisible(false)
            row.tex:setVisible(false)
        end
    end
end

function BridgePregameScreen:refreshDetailButtons()
    local name = nil
    if self.detailCombo ~= nil and type(self.detailCombo.options) == "table"
        and type(self.detailCombo.selected) == "number" and self.detailCombo.selected > 0 then
        name = self.detailCombo:getOptionData(self.detailCombo.selected)
    end
    local has = name ~= nil and BridgeAppearance.hasDetail(name)
    if self.detailBtn ~= nil then
        self.detailBtn:setTitle(has and self.removeText or self.addText)
        self.detailBtn:setEnable(name ~= nil)
    end
    if self.detailClearBtn ~= nil then
        self.detailClearBtn:setEnable(#(BridgeAppearance.candidate.details or {}) > 0)
    end
end

function BridgePregameScreen:refresh()
    local draft = self.draft
    local c = BridgeAppearance.candidate
    if draft == nil or c == nil then return end

    pcall(function() BridgePregame.captureClothTint(BridgePregame.activeClothing(draft)) end)
    BridgeAppearance.previewOverride = nil
    self.hoverCloth = nil
    self.filling = true
    comboSelect(self.genderCombo, draft.gender)
    local skinIndex = 1
    local skins = BridgeData.skinsFor(draft.gender) or {}
    for i = 1, #skins do
        if skins[i] == c.skin then skinIndex = i break end
    end
    paintButton(self.skinColorBtn, SKIN_COLORS[skinIndex] or SKIN_COLORS[1])
    if self.skinColorBtn ~= nil then self.skinColorBtn:setTitle("") end
    if self.muscleVisible then comboSelect(self.muscleCombo, c.muscle) end
    if self.speciesVisible then comboSelect(self.speciesCombo, c.fur or "Hooman") end
    comboSelect(self.hairCombo, c.hair)
    if self.beardVisible then comboSelect(self.beardCombo, c.beard) end
    if self.faceVisible then
        comboSelect(self.faceCombo, c.face or "")
        if (self.faceCombo.selected or 0) == 0 then
            c.face = nil
            self.faceCombo.selected = 1
        end
    end

    comboSelect(self.voiceCombo, nil)
    local voiceMatched = false
    if type(c.voice) == "table" and type(self.voiceCombo.options) == "table" then
        for i = 1, #self.voiceCombo.options do
            local style = self.voiceCombo:getOptionData(i)
            if type(style) == "table" and style.name == c.voice.name and style.prefix == c.voice.prefix
                and tonumber(style.type) == tonumber(c.voice.type) then
                self.voiceCombo.selected = i
                voiceMatched = true
                break
            end
        end
        if not voiceMatched then
            local key = tostring(c.voice.prefix) .. ":" .. tostring(c.voice.type) .. ":" .. tostring(c.voice.name)
            if self.missingVoiceKey ~= key then
                self.missingVoiceKey = key
                comboAdd(self.voiceCombo, tostring(c.voice.name or c.voice.prefix), {
                    name = c.voice.name,
                    prefix = c.voice.prefix,
                    type = tonumber(c.voice.type) or 0,
                    pitch = tonumber(c.voice.pitch) or 0,
                    bodyType = 0,
                })
            end
            self.voiceCombo.selected = #self.voiceCombo.options
        end
    end

    for _, cat in ipairs(self.makeupOrder) do
        local current = nil
        for _, itemType in ipairs(c.makeup or {}) do
            local meta = nil
            pcall(function() meta = BridgeData.makeupMeta(itemType) end)
            if meta ~= nil and meta.category == cat then current = itemType break end
        end
        comboSelect(self.makeupCombos[cat], current)
    end

    if self.detailsVisible and type(self.detailCombo.options) == "table" then
        local selected = nil
        if type(self.detailCombo.selected) == "number" and self.detailCombo.selected > 0 then
            selected = self.detailCombo:getOptionData(self.detailCombo.selected)
        end
        local keep = nil
        if selected ~= nil then
            for i = 1, #self.detailCombo.options do
                if self.detailCombo:getOptionData(i) == selected then keep = i break end
            end
        end
        self.detailCombo.selected = keep or 0
    end

    local opts = BridgePregame.cleanOptions(draft.options)
    draft.options = opts
    for i, def in ipairs(BEHAVIOR_DEFS) do
        local tick = self.behaviorTicks ~= nil and self.behaviorTicks[i] or nil
        if tick ~= nil then
            local label = genderedText(def.label, def.label, draft.gender)
            if type(tick.options) == "table" then tick.options[1] = label end
            if type(tick.optionsIndex) == "table" then tick.optionsIndex[1] = label end
            tick.tooltip = genderedText(def.tip, def.tip, draft.gender)
            tick:setSelected(1, opts[def.key] == true)
        end
    end
    if self.aimCombo ~= nil then self.aimCombo:selectData(opts.aimSense) end

    paintButton(self.hairColorBtn, c.hairColor)
    if self.hairColorBtn ~= nil then self.hairColorBtn:setTitle("") end
    paintButton(self.beardColorBtn, c.beardColor or c.hairColor)
    if self.beardColorBtn ~= nil then self.beardColorBtn:setTitle("") end

    self.filling = false
    BridgeAppearance.previewClothing = BridgePregame.activeClothing(draft)
    self:refreshClothing()
    self:refreshDetailButtons()
    self.detailsSummaryText = self:detailSummary()
    self:refreshLookButtons()
    self:layout()
end

function BridgePregameScreen:refreshControls()
    self:refresh()
end

function BridgePregameScreen:detailSummary()
    local labels = {}
    local entries = {}
    pcall(function() entries = BridgeAppearance.Catalog.detailEntries() end)
    for _, name in ipairs(BridgeAppearance.candidate.details or {}) do
        for _, e in ipairs(entries) do
            if e.name == name then labels[#labels + 1] = tostring(e.label) break end
        end
    end
    if #labels == 0 then return self.noneText end
    return table.concat(labels, ", ")
end

function BridgePregameScreen:layoutLeft()
    local x, y = self.leftX, self.contentTop
    local labelW = 74
    local controlW = self.leftW - labelW
    if controlW < 80 then controlW = 80 end
    self.leftRender = {}
    self.summaryY = nil

    local controls = {
        self.nameEntry, self.genderCombo, self.skinColorBtn, self.muscleCombo, self.speciesCombo,
        self.voiceCombo, self.hairCombo, self.hairColorBtn, self.beardCombo, self.beardColorBtn,
        self.faceCombo, self.detailCombo, self.detailBtn, self.detailClearBtn,
    }
    for _, control in ipairs(controls) do
        if control ~= nil then control:setVisible(false) end
    end
    for _, cat in ipairs(self.makeupOrder) do self.makeupCombos[cat]:setVisible(false) end

    local function heading(text)
        self.leftRender[#self.leftRender + 1] = { kind = "heading", text = text, x = x, y = y }
        y = y + FONT_S + 3
        self.leftRender[#self.leftRender + 1] = { kind = "divider", x = x, y = y, w = self.leftW }
        y = y + 6
    end

    local function row(label, control, width)
        if control == nil then return end
        control:setVisible(true)
        control:setX(x + labelW)
        control:setY(y)
        control:setWidth(width or controlW)
        control:setHeight(BTN_H)
        self.leftRender[#self.leftRender + 1] = { kind = "label", text = label, x = x, y = y + 3 }
        y = y + BTN_H + 3
    end

    heading(tr("PregameIdentity", "Identity"))
    row(self.nameText, self.nameEntry)
    row(self.genderText, self.genderCombo)

    heading(tr("AppearanceBody", "Body"))
    row(vanillaText("UI_SkinColor", "Skin Color"), self.skinColorBtn, BTN_H)
    if self.muscleVisible then row(tr("PregameMuscle", "Muscle"), self.muscleCombo) end
    if self.speciesVisible then row(tr("AppearanceFur", "Species"), self.speciesCombo) end
    row(vanillaText("UI_characreation_voicetype", "Voice Type"), self.voiceCombo)
    row("", self.voiceDemoBtn)

    heading(tr("AppearanceHair", "Hair"))
    row(tr("PregameStyle", "Style"), self.hairCombo)
    row(tr("PregameColor", "Color"), self.hairColorBtn, 48)

    if self.beardVisible then
        heading(tr("AppearanceBeard", "Beard"))
        row(tr("PregameStyle", "Style"), self.beardCombo)
        row(tr("PregameColor", "Color"), self.beardColorBtn, 48)
    end

    if self.faceVisible then
        heading(tr("PregameHead", "Head"))
        row(tr("AppearanceFace", "Face"), self.faceCombo)
    end

    if self.detailsVisible then
        heading(tr("AppearanceDetails", "Details"))
        row(tr("PregameDetail", "Detail"), self.detailCombo)
        local bw = math.floor((controlW - 4) / 2)
        self.detailBtn:setVisible(true)
        self.detailBtn:setX(x + labelW)
        self.detailBtn:setY(y)
        self.detailBtn:setWidth(bw)
        self.detailBtn:setHeight(BTN_H)
        self.detailClearBtn:setVisible(true)
        self.detailClearBtn:setX(x + labelW + bw + 4)
        self.detailClearBtn:setY(y)
        self.detailClearBtn:setWidth(bw)
        self.detailClearBtn:setHeight(BTN_H)
        y = y + BTN_H + 3
        self.summaryY = y
        y = y + FONT_S + 4
    end

    if #self.makeupOrder > 0 then
        heading(tr("AppearanceMakeup", "Make-up"))
        local defs = rawget(_G, "MakeUpDefinitions")
        for _, cat in ipairs(self.makeupOrder) do
            local info = defs ~= nil and defs.categories ~= nil and defs.categories[cat] or nil
            local label = cat
            if info ~= nil then label = gameText("MakeUpCategory_" .. tostring(info.name), cat) end
            row(label, self.makeupCombos[cat])
        end
    end
    self.leftBottom = y
end

function BridgePregameScreen:layoutRight()
    local x, y = self.rightX, self.contentTop
    local labelW = 64
    self.clothHeadingY = y
    y = y + FONT_S + 6
    self.clothDividerY = y
    y = y + 5
    local w = self.rightW
    local allowed = self.clothAvailable or {}
    for _, loc in ipairs(self.clothOrder) do
        local row = self.clothRows[loc]
        row.visible = allowed[loc] == true
        if allowed[loc] then
            local comboW = math.floor((w - labelW) * 0.40)
            if comboW < 70 then comboW = 70 end
            local colorW = BTN_H
            local texW = w - labelW - comboW - colorW - 8
            if texW < 60 then texW = 60 end
            row.labelY = y + 3
            row.combo:setX(x + labelW)
            row.combo:setY(y)
            row.combo:setWidth(comboW)
            row.combo:setHeight(BTN_H)
            row.color:setX(x + labelW + comboW + 4)
            row.color:setY(y)
            row.color:setWidth(colorW)
            row.color:setHeight(BTN_H)
            row.tex:setX(x + labelW + comboW + 4 + colorW + 4)
            row.tex:setY(y)
            row.tex:setWidth(texW)
            row.tex:setHeight(BTN_H)
            y = y + BTN_H + 3
        else
            row.combo:setVisible(false)
            row.color:setVisible(false)
            row.tex:setVisible(false)
        end
    end
    self.clothBottom = y

    local by = y + PAD
    self.behaviorHeadingY = by
    by = by + FONT_S + 6
    self.behaviorDividerY = by
    by = by + 5
    for i, tick in ipairs(self.behaviorTicks or {}) do
        tick:setVisible(true)
        tick:setX(x)
        tick:setY(by)
        tick:setWidth(w)
        by = by + math.max(BTN_H, tick:getHeight()) + 2
    end
    local aimLabelW = textW(UIFont.Small, tr("OptAimSense", "Line-of-fire caution")) + 8
    if aimLabelW < 90 then aimLabelW = 90 end
    if aimLabelW > math.floor(w * 0.55) then aimLabelW = math.floor(w * 0.55) end
    local aimW = w - aimLabelW
    if aimW < 60 then aimW = 60 end
    self.aimLabelY = by + 3
    self.aimCombo:setVisible(true)
    self.aimCombo:setX(x + aimLabelW)
    self.aimCombo:setY(by)
    self.aimCombo:setWidth(aimW)
    self.aimCombo:setHeight(BTN_H)
    self.behaviorBottom = by + BTN_H
end

function BridgePregameScreen:layout()
    local w, h = self.width, self.height
    if w == nil or h == nil then return end
    local footerH = BTN_H + UI_BORDER_SPACING * 2 + 2
    local contentBottom = h - footerH - 4
    local frameW = math.min(1120, w - PAD * 2)
    local frameX = math.floor((w - frameW) / 2)
    local leftW = math.floor(math.min(300, math.max(250, frameW * 0.27)))
    local rightW = math.floor(math.min(330, math.max(290, frameW * 0.30)))
    local centerX = frameX + leftW + PAD
    local rightX = frameX + frameW - rightW
    local centerW = rightX - centerX - PAD
    if centerW < 180 then
        centerW = 180
        rightX = centerX + centerW + PAD
        rightW = frameX + frameW - rightX
    end
    self.leftX, self.leftW = frameX, leftW
    self.rightX, self.rightW = rightX, rightW

    self.brandY = 8
    self.subY = self.brandY + FONT_M + 2
    self.contentTop = self.subY + FONT_S + 10
    self.contentBottom = contentBottom

    local contentH = contentBottom - self.contentTop
    local avatarW = math.floor((contentH - UI_BORDER_SPACING - BTN_H) / 2)
    if avatarW < 160 then avatarW = 160 end
    centerX = math.floor((w - avatarW) / 2)
    self.leftX = centerX - PAD - leftW
    self.rightX = centerX + avatarW + PAD
    self.rightW = math.min(rightW, w - PAD - self.rightX)
    if self.leftX < PAD or self.rightW < 80 then
        self.leftX = frameX
        self.rightX = frameX + frameW - rightW
        self.rightW = rightW
        avatarW = math.min(avatarW, self.rightX - self.leftX - leftW - PAD * 2)
    end
    self.avatar:setX(centerX)
    self.avatar:setY(self.contentTop)
    self.avatar:setWidth(avatarW)
    self.avatar:setHeight(contentH)
    pcall(function() self.avatar:rescaleAvatarViewer() end)

    local randomW = textW(UIFont.Small, self.randomText) + PAD * 2
    self.randomW = randomW
    self.randomBtn:setWidth(randomW)
    self.randomBtn:setHeight(BTN_H)

    local by = h - UI_BORDER_SPACING - BTN_H - 1
    local btnPad = JOYPAD_TEX_SIZE + UI_BORDER_SPACING * 2
    local backW = btnPad + textW(UIFont.Small, self.backText)
    local startW = btnPad + textW(UIFont.Small, self.startText)
    local saveW = math.max(46, textW(UIFont.Small, self.saveText) + PAD * 2)
    local delW = math.max(40, textW(UIFont.Small, self.delText) + PAD * 2)
    local backX = UI_BORDER_SPACING + 1
    local startX = w - startW - UI_BORDER_SPACING - 1
    self.backBtn:setWidth(backW)
    self.backBtn:setHeight(BTN_H)
    self.backBtn:setX(backX)
    self.backBtn:setY(by)
    self.startBtn:setWidth(startW)
    self.startBtn:setHeight(BTN_H)
    self.startBtn:setX(startX)
    self.startBtn:setY(by)
    self.randomBtn:setX(startX - PAD - randomW)
    self.randomBtn:setY(by)

    local lookX = backX + backW + PAD
    local lookW = 170
    local saveX = lookX + lookW + PAD
    if saveX + saveW + PAD + delW > startX - PAD then
        lookW = math.max(80, startX - PAD - delW - PAD - saveW - PAD - lookX)
        saveX = lookX + lookW + PAD
    end
    self.lookCombo:setX(lookX)
    self.lookCombo:setY(by)
    self.lookCombo:setWidth(lookW)
    self.lookCombo:setHeight(BTN_H)
    self.saveBtn:setX(saveX)
    self.saveBtn:setY(by)
    self.saveBtn:setWidth(saveW)
    self.saveBtn:setHeight(BTN_H)
    self.deleteBtn:setX(saveX + saveW + PAD)
    self.deleteBtn:setY(by)
    self.deleteBtn:setWidth(delW)
    self.deleteBtn:setHeight(BTN_H)

    self:layoutLeft()
    self:layoutRight()
end

function BridgePregameScreen:prerender()
    ISPanelJoypad.prerender(self)
end

function BridgePregameScreen:render()
    ISPanelJoypad.render(self)
    local brandW = textW(UIFont.Medium, self.brandText)
    self:drawText(self.brandText, math.floor((self.width - brandW) / 2), self.brandY, 1, 1, 1, 1, UIFont.Medium)
    local titleW = textW(UIFont.Small, self.titleText)
    self:drawText(self.titleText, math.floor((self.width - titleW) / 2), self.subY, 0.8, 0.8, 0.8, 1, UIFont.Small)

    for _, entry in ipairs(self.leftRender or {}) do
        if entry.kind == "heading" then
            self:drawText(entry.text, entry.x, entry.y, 0.95, 0.95, 0.95, 1, UIFont.Small)
        elseif entry.kind == "label" then
            self:drawText(entry.text, entry.x, entry.y, 0.82, 0.82, 0.82, 1, UIFont.Small)
        elseif entry.kind == "divider" then
            self:drawRect(entry.x, entry.y, entry.w, 1, 0.45, 0.55, 0.55, 0.55)
        end
    end
    if self.summaryY ~= nil then
        local text = self.detailsSummaryText
        if text == nil or text == "" then text = self.noneText end
        local prefix = tr("PregameSelected", "Selected") .. ": "
        local line = fitText(UIFont.Small, prefix .. text, self.leftW)
        self:drawText(line, self.leftX, self.summaryY, 0.75, 0.75, 0.75, 1, UIFont.Small)
    end

    if self.clothHeadingY ~= nil then
        self:drawText(vanillaText("UI_characreation_clothing", "Clothing"), self.rightX, self.clothHeadingY, 0.95, 0.95, 0.95, 1, UIFont.Small)
        self:drawRect(self.rightX, self.clothDividerY, self.rightW, 1, 0.45, 0.55, 0.55, 0.55)
    end
    for _, loc in ipairs(self.clothOrder or {}) do
        local row = self.clothRows[loc]
        if row ~= nil and row.visible == true and row.labelY ~= nil then
            local label = vanillaText("UI_ClothingType_" .. loc, loc)
            self:drawText(label, self.rightX, row.labelY, 0.82, 0.82, 0.82, 1, UIFont.Small)
        end
    end
    if self.behaviorHeadingY ~= nil then
        self:drawText(self.behaviorTitle or tr("PregameBehavior", "Companion behavior"), self.rightX, self.behaviorHeadingY, 0.95, 0.95, 0.95, 1, UIFont.Small)
        self:drawRect(self.rightX, self.behaviorDividerY, self.rightW, 1, 0.45, 0.55, 0.55, 0.55)
    end
    if self.aimLabelY ~= nil then
        local label = tr("OptAimSense", "Line-of-fire caution")
        self:drawText(label, self.rightX, self.aimLabelY, 0.82, 0.82, 0.82, 1, UIFont.Small)
    end
end

function BridgePregameScreen:update()
    ISPanelJoypad.update(self)
    local ms = MainScreen.instance
    if ms ~= nil and (self.width ~= ms:getWidth() or self.height ~= ms:getHeight()) then
        self:setWidth(ms:getWidth())
        self:setHeight(ms:getHeight())
        self:layout()
    end
    if self.lookCombo ~= nil then self:refreshLookButtons() end
end

function BridgePregameScreen:captureName()
    local draft = self.draft
    if draft == nil or self.nameEntry == nil then return end
    local text = tostring(self.nameEntry:getText() or "")
    if draft.gender == "male" then draft.maleName = text else draft.name = text end
end

function BridgePregameScreen:refreshName()
    local draft = self.draft
    if draft == nil or self.nameEntry == nil then return end
    local text = draft.name or ""
    if draft.gender == "male" then text = draft.maleName or "" end
    self.nameEntry:setText(tostring(text))
end

function BridgePregameScreen:refreshLookButtons()
    local combo = self.lookCombo
    local name = self:selectedLook()
    local del = self.deleteBtn
    if del ~= nil and del.setEnable ~= nil then
        local ok = type(name) == "string" and BridgeLooks ~= nil and BridgeLooks.canDelete(name) == true
        del:setEnable(ok)
    end
    local save = self.saveBtn
    if save ~= nil and save.setEnable ~= nil then
        save:setEnable(BridgeLooks ~= nil and BridgeLooks.locked ~= nil and BridgeLooks.locked() ~= true)
    end
end

function BridgePregameScreen:refreshLooks()
    local combo = self.lookCombo
    if combo == nil or BridgeLooks == nil or type(combo.addOption) ~= "function" then return end
    local keep = nil
    if type(combo.options) == "table" and type(combo.selected) == "number" then
        keep = combo.options[combo.selected]
    end
    self.fillingLooks = true
    combo.options = {}
    combo.selected = 0
    local list = BridgeLooks.all()
    local gender = BridgeData.genderOf(self.draft ~= nil and self.draft.store or nil)
    if type(list) == "table" then
        for i = 1, #list do
            local look = list[i]
            if type(look) == "table" and type(look.name) == "string"
                and BridgeLooks.genderOf(look) == gender then
                combo:addOption(look.name)
            end
        end
    end
    combo.selected = 0
    if type(keep) == "string" and type(combo.options) == "table" then
        for i = 1, #combo.options do
            if combo.options[i] == keep then combo.selected = i break end
        end
    end
    self.fillingLooks = false
    self:refreshLookButtons()
end

function BridgePregameScreen:selectedLook()
    local combo = self.lookCombo
    if combo == nil or type(combo.options) ~= "table" or type(combo.selected) ~= "number" then return nil end
    local name = combo.options[combo.selected]
    if type(name) ~= "string" then return nil end
    return name
end

function BridgePregameScreen:selectLook(name)
    local combo = self.lookCombo
    if combo == nil or type(combo.options) ~= "table" then return end
    combo.selected = 0
    if type(name) ~= "string" then return end
    for i = 1, #combo.options do
        if combo.options[i] == name then combo.selected = i return end
    end
end

function BridgePregameScreen:syncLook()
    if BridgeLooks == nil or self.lookCombo == nil or self.draft == nil then return end
    local name = nil
    pcall(function() name = BridgeLooks.matchName(BridgeAppearance.candidate) end)
    if name == nil then name = BridgeLooks.defaultName(self.draft.gender) end
    self:selectLook(name)
    self:refreshLookButtons()
end

function BridgePregameScreen:syncUI()
    local draft = self.draft
    if draft == nil then return end
    self.filling = true
    if self.genderCombo ~= nil then self.genderCombo:selectData(draft.gender) end
    self.filling = false
    self:refreshName()
    self:refreshLooks()
    self:syncLook()
    BridgeAppearance.previewClothing = BridgePregame.activeClothing(draft)
    BridgeAppearance.refreshPreview()
    self:refresh()
    self:layout()
end

function BridgePregameScreen:onGender(combo)
    if self.filling then return end
    local gender = combo:getSelectedData()
    if gender ~= "male" then gender = "female" end
    local draft = self.draft
    if draft == nil or gender == draft.gender then return end
    self:captureName()
    BridgeAppearance.snapshotCandidate(draft)
    draft.gender = gender
    draft.store.gender = gender
    BridgeAppearance.loadCandidate(draft)
    self:rebuildControls()
    self:refreshName()
    self:refreshLooks()
    self:syncLook()
    BridgeAppearance.previewClothing = BridgePregame.activeClothing(draft)
    BridgeAppearance.refreshPreview()
    self:refresh()
end

local function copyColor(color)
    if type(color) ~= "table" then return nil end
    return { r = color.r, g = color.g, b = color.b }
end

local function copyArray(list)
    local out = {}
    if type(list) == "table" then
        for i = 1, #list do out[i] = list[i] end
    end
    return out
end

local function copyCandidateForPreview(c)
    return {
        skin = c.skin,
        hair = c.hair,
        hairColor = copyColor(c.hairColor),
        face = c.face,
        details = copyArray(c.details),
        muscle = c.muscle,
        makeup = copyArray(c.makeup),
        beard = c.beard,
        beardColor = copyColor(c.beardColor),
        fur = c.fur,
        voice = c.voice,
    }
end

function BridgePregameScreen:restoreHoverState()
    if BridgeAppearance.previewOverride == nil and self.hoverCloth == nil then return end
    BridgeAppearance.previewOverride = nil
    self.hoverCloth = nil
    BridgeAppearance.previewClothing = BridgeAppearance.copyClothing(BridgePregame.activeClothing(self.draft) or {})
    BridgeAppearance.refreshPreview()
end

function BridgePregameScreen:applyHover(mutator)
    local c = copyCandidateForPreview(BridgeAppearance.candidate)
    if type(mutator) == "function" then mutator(c) end
    BridgeAppearance.previewOverride = c
    BridgeAppearance.previewClothing = BridgeAppearance.copyClothing(BridgePregame.activeClothing(self.draft) or {})
    BridgeAppearance.refreshPreview()
end

function BridgePregameScreen:applyClothingHover(loc, itemType, textureIndex)
    BridgeAppearance.previewOverride = nil
    local list = BridgeAppearance.copyClothing(BridgePregame.activeClothing(self.draft) or {})
    local entry, index = BridgeAppearance.clothingAt(list, loc)
    if itemType == nil then
        if index ~= nil then table.remove(list, index) end
    else
        if entry == nil then
            entry = { loc = loc, t = itemType }
            list[#list + 1] = entry
        elseif entry.t ~= itemType then
            entry.t = itemType
            entry.alt = nil
            entry.tc = nil
            entry.bt = nil
            entry.tint = nil
        end
        if textureIndex ~= nil then
            local info = textureInfo(entry)
            if info ~= nil then
                entry[info.kind] = textureIndex
                if info.kind == "tc" then entry.bt = nil else entry.tc = nil end
            end
        end
    end
    BridgePregame.captureClothTint(list)
    self.hoverCloth = list
    BridgeAppearance.previewClothing = BridgeAppearance.copyClothing(list)
    BridgeAppearance.refreshPreview()
end

function BridgePregameScreen:bindHover(combo, mutator)
    if combo == nil then return end
    combo.pointOnItem = function(_combo, index)
        if self.filling or _combo.__hoverIndex == index then return end
        _combo.__hoverIndex = index
        local data = _combo:getOptionData(index)
        self:applyHover(function(c) mutator(c, data, index) end)
    end
    combo.onMouseMoveOutside = function(_combo)
        _combo.__hoverIndex = nil
        self:restoreHoverState()
    end
end

function BridgePregameScreen:bindClothingHover(combo)
    if combo == nil then return end
    local loc = combo.loc
    combo.pointOnItem = function(_combo, index)
        if self.filling or _combo.__hoverIndex == index then return end
        _combo.__hoverIndex = index
        local data = _combo:getOptionData(index)
        self:applyClothingHover(loc, data, nil)
    end
    combo.onMouseMoveOutside = function(_combo)
        _combo.__hoverIndex = nil
        self:restoreHoverState()
    end
end

function BridgePregameScreen:bindTextureHover(combo)
    if combo == nil then return end
    local loc = combo.loc
    combo.pointOnItem = function(_combo, index)
        if self.filling or _combo.__hoverIndex == index then return end
        _combo.__hoverIndex = index
        local list = BridgePregame.activeClothing(self.draft) or {}
        local entry = BridgeAppearance.clothingAt(list, loc)
        if entry == nil then return end
        local data = _combo:getOptionData(index)
        if type(data) ~= "number" then return end
        self:applyClothingHover(loc, entry.t, data)
    end
    combo.onMouseMoveOutside = function(_combo)
        _combo.__hoverIndex = nil
        self:restoreHoverState()
    end
end

function BridgePregameScreen:installHoverPreviews()
    self:bindHover(self.muscleCombo, function(c, data) c.muscle = tonumber(data) or 0 end)
    self:bindHover(self.speciesCombo, function(c, data) c.fur = (data ~= "Hooman") and data or nil end)
    self:bindHover(self.hairCombo, function(c, data) c.hair = data end)
    self:bindHover(self.beardCombo, function(c, data) c.beard = data end)
    self:bindHover(self.faceCombo, function(c, data) c.face = data end)
    self:bindHover(self.detailCombo, function(c, data)
        local out = copyArray(c.details)
        if data ~= nil then
            local present = false
            for _, name in ipairs(out) do if name == data then present = true break end end
            if not present then out[#out + 1] = data end
        end
        c.details = out
    end)
    for _, cat in ipairs(self.makeupOrder) do
        local combo = self.makeupCombos[cat]
        local category = cat
        self:bindHover(combo, function(c, data)
            local out = {}
            for _, itemType in ipairs(c.makeup or {}) do
                local meta = nil
                pcall(function() meta = BridgeData.makeupMeta(itemType) end)
                if meta == nil or meta.category ~= category then out[#out + 1] = itemType end
            end
            if data ~= nil then out[#out + 1] = data end
            c.makeup = out
        end)
    end
    for _, loc in ipairs(self.clothOrder) do
        local row = self.clothRows[loc]
        self:bindClothingHover(row.combo)
        self:bindTextureHover(row.tex)
    end
end
function BridgePregameScreen:onSkinColor(button)
    BridgeAppearance.previewOverride = nil
    self.hoverCloth = nil
    self.skinPicker:setX(button:getAbsoluteX())
    self.skinPicker:setY(button:getAbsoluteY() + button:getHeight())
    local c = button.backgroundColor or SKIN_COLORS[1]
    self.skinPicker:setInitialColor(ColorInfo.new(c.r, c.g, c.b, 1))
    local ms = (type(MainScreen) == "table") and MainScreen.instance or nil
    if ms ~= nil and type(ms.addChild) == "function" then
        pcall(function() ms:removeChild(self.skinPicker) end)
        ms:addChild(self.skinPicker)
        self.skinPicker:setCapture(true)
    else
        self.skinPicker:removeFromUIManager()
        self.skinPicker:addToUIManager()
        self.skinPicker:setCapture(true)
    end
end

function BridgePregameScreen:onSkinColorPicked(color, mouseUp)
    local index = self.skinPicker.index or 1
    local skins = BridgeData.skinsFor(self.draft.gender) or {}
    local id = skins[index]
    if id ~= nil then
        BridgeAppearance.setSkin(id)
        self:refresh()
    end
end

function BridgePregameScreen:onMuscle(combo)
    if self.filling then return end
    BridgeAppearance.setMuscle(combo:getSelectedData())
end

function BridgePregameScreen:onSpecies(combo)
    if self.filling then return end
    BridgeAppearance.previewOverride = nil
    self.hoverCloth = nil
    local species = combo:getSelectedData() or "Hooman"
    BridgeAppearance.candidate.fur = (species ~= "Hooman") and species or nil
    BridgePregame.setActiveSpecies(self.draft, species)
    BridgeAppearance.refreshPreview()
end

function BridgePregameScreen:onVoice(combo)
    if self.filling then return end
    BridgeAppearance.previewOverride = nil
    self.hoverCloth = nil
    local style = combo:getSelectedData()
    if type(style) ~= "table" then return end
    local voice = {
        name = tostring(style.name),
        prefix = tostring(style.prefix),
        type = tonumber(style.type) or 0,
        pitch = math.floor((tonumber(style.pitch) or 0) + 0.5),
    }
    BridgeAppearance.candidate.voice = voice
    BridgePregame.setActiveVoice(self.draft, voice)
    self:playVoice(voice)
end

function BridgePregameScreen:playVoice(voice)
    if type(voice) ~= "table" or type(voice.prefix) ~= "string" then return end
    pcall(function()
        if self.voiceSound ~= nil then
            getSoundManager():stopUISound(self.voiceSound)
            self.voiceSound = nil
        end
        getSoundManager():setMusicState("InGame")
        getSoundManager():resumeSoundAndMusic()
        self.voiceSound = getSoundManager():playUISound(tostring(voice.prefix) .. "ShoutHey")
    end)
end

function BridgePregameScreen:onVoiceDemo()
    local voice = BridgePregame.activeVoice(self.draft)
    if type(voice) == "table" then self:playVoice(voice) end
end

function BridgePregameScreen:onHair(combo)
    if self.filling then return end
    BridgeAppearance.setHair(combo:getSelectedData())
end

function BridgePregameScreen:onHairColor(button)
    BridgeAppearance.openColorPicker(button, "hair")
end

function BridgePregameScreen:onBeard(combo)
    if self.filling then return end
    BridgeAppearance.setBeard(combo:getSelectedData())
end

function BridgePregameScreen:onBeardColor(button)
    BridgeAppearance.openColorPicker(button, "beard")
end

function BridgePregameScreen:onFace(combo)
    if self.filling then return end
    BridgeAppearance.setFace(combo:getSelectedData())
end

function BridgePregameScreen:onDetailPick(combo)
    self:refreshDetailButtons()
end

function BridgePregameScreen:onDetailToggle()
    local name = nil
    if self.detailCombo ~= nil and type(self.detailCombo.selected) == "number" and self.detailCombo.selected > 0 then
        name = self.detailCombo:getOptionData(self.detailCombo.selected)
    end
    if name == nil then return end
    BridgeAppearance.toggleDetail(name)
    self:refresh()
end

function BridgePregameScreen:onDetailClear()
    BridgeAppearance.candidate.details = {}
    BridgeAppearance.refreshPreview()
    BridgeAppearance.refreshViews()
    self:refresh()
end

function BridgePregameScreen:onBehaviorTick(index, selected, key)
    if self.filling or self.draft == nil or key == nil then return end
    local opts = BridgePregame.cleanOptions(self.draft.options)
    opts[key] = selected == true
    self.draft.options = opts
end

function BridgePregameScreen:onAimSense(combo)
    if self.filling or self.draft == nil then return end
    local opts = BridgePregame.cleanOptions(self.draft.options)
    local mode = cleanAimMode(combo:getSelectedData())
    if mode ~= nil then opts.aimSense = mode end
    self.draft.options = opts
end

function BridgePregameScreen:onMakeup(combo)
    if self.filling then return end
    BridgeAppearance.setMakeup(combo.category, combo:getSelectedData())
end

function BridgePregameScreen:onClothType(combo)
    if self.filling then return end
    local loc = combo.loc
    local itemType = combo:getSelectedData()
    local draft = self.draft
    local list = BridgePregame.activeClothing(draft) or {}
    local entry, index = BridgeAppearance.clothingAt(list, loc)
    if itemType == nil then
        if index ~= nil then table.remove(list, index) end
    elseif entry == nil then
        list[#list + 1] = { loc = loc, t = itemType }
    elseif entry.t ~= itemType then
        entry.t = itemType
        entry.alt = nil
        entry.tc = nil
        entry.bt = nil
        entry.tint = nil
    end
    BridgePregame.captureClothTint(list)
    BridgePregame.setActiveClothing(draft, list)
    BridgeAppearance.previewClothing = list
    BridgeAppearance.refreshPreview()
    self:refresh()
end

function BridgePregameScreen:onClothTexture(combo)
    if self.filling then return end
    local draft = self.draft
    local list = BridgePregame.activeClothing(draft) or {}
    local entry = BridgeAppearance.clothingAt(list, combo.loc)
    if entry == nil then return end
    local index = combo:getSelectedData()
    if type(index) ~= "number" then return end
    local info = textureInfo(entry)
    if info == nil then return end
    entry[info.kind] = index
    if info.kind == "tc" then entry.bt = nil else entry.tc = nil end
    BridgeAppearance.previewClothing = list
    BridgeAppearance.refreshPreview()
    self:refresh()
end

function BridgePregameScreen:setClothTint(loc, color)
    local draft = self.draft
    if draft == nil or type(color) ~= "table" then return end
    local list = BridgePregame.activeClothing(draft) or {}
    local entry = BridgeAppearance.clothingAt(list, loc)
    if entry == nil then return end
    entry.tint = { tonumber(color.r) or 1, tonumber(color.g) or 1, tonumber(color.b) or 1 }
    BridgeAppearance.previewClothing = list
    BridgeAppearance.refreshPreview()
    self:refresh()
end

function BridgePregameScreen:onClothColor(button)
    local loc = button.loc
    local list = BridgePregame.activeClothing(self.draft) or {}
    local entry = BridgeAppearance.clothingAt(list, loc)
    if entry == nil then return end
    BridgeAppearance.openColorPicker(button, "cloth", loc, entryTint(entry))
end

local function randomEntry(list)
    if type(list) ~= "table" or #list == 0 then return nil end
    return list[ZombRand(#list) + 1]
end

local function safeList(fn)
    local out = {}
    pcall(function() out = fn() or {} end)
    return out
end

function BridgePregameScreen:randomize()
    local draft = self.draft
    if draft == nil then return end
    self:captureName()
    BridgeAppearance.snapshotCandidate(draft)

    local gender = (ZombRand(2) == 0) and "female" or "male"
    if gender ~= draft.gender then
        draft.gender = gender
        draft.store.gender = gender
        BridgeAppearance.loadCandidate(draft)
    end
    local c = BridgeAppearance.candidate

    local name = nil
    pcall(function()
        local desc = SurvivorFactory.CreateSurvivor()
        SurvivorFactory.randomName(desc)
        name = desc:getForename()
    end)
    name = BridgeData.cleanName(name)
    if name == nil then name = (gender == "male") and BridgeData.DEFAULT_MALE_NAME or BridgeData.DEFAULT_NAME end
    if gender == "male" then draft.maleName = name else draft.name = name end

    local skin = randomEntry(safeList(function() return BridgeData.skinsFor(gender) end))
    if skin ~= nil then c.skin = skin end
    local hair = randomEntry(safeList(function() return BridgeAppearance.Catalog.hairEntries() end))
    if hair ~= nil then c.hair = hair.name end
    local colors = safeList(function() return BridgeAppearance.Catalog.hairColorPresets() end)
    local color = randomEntry(colors)
    if color ~= nil then c.hairColor = { r = color.r, g = color.g, b = color.b } end
    local face = randomEntry(safeList(function() return BridgeAppearance.Catalog.faceEntries() end))
    if face ~= nil then c.face = face.name end

    local details = safeList(function() return BridgeAppearance.Catalog.detailEntries() end)
    c.details = {}
    local wanted = ZombRand(3)
    for i = 1, wanted do
        local pick = randomEntry(details)
        if pick ~= nil then
            local dup = false
            for _, n in ipairs(c.details) do if n == pick.name then dup = true break end end
            if not dup then c.details[#c.details + 1] = pick.name end
        end
    end

    c.makeup = {}
    for _, cat in ipairs(self.makeupOrder) do
        if ZombRand(2) == 0 then
            local options = {}
            local defs = rawget(_G, "MakeUpDefinitions")
            if defs ~= nil and type(defs.makeup) == "table" then
                for _, m in ipairs(defs.makeup) do
                    if m.category == cat then options[#options + 1] = m.item end
                end
            end
            local pick = randomEntry(options)
            if pick ~= nil then c.makeup[#c.makeup + 1] = pick end
        end
    end

    if BridgeData.spnccMuscle(gender) ~= nil then
        c.muscle = ZombRand(BridgeData.MUSCLE_MAX + 1)
    end
    if gender == "male" then
        local beards = (BridgeWindow ~= nil and type(BridgeWindow.beardStyles) == "function")
            and BridgeWindow.beardStyles() or {}
        local beard = randomEntry(beards)
        if beard ~= nil then c.beard = beard.id end
        local hc = c.hairColor or BridgeData.DEFAULT_HAIR_COLOR
        c.beardColor = { r = hc.r, g = hc.g, b = hc.b }
    else
        c.beard = ""
        c.beardColor = nil
    end

    local styles = {}
    if BridgeVoice ~= nil and type(BridgeVoice.stylesFor) == "function" then
        pcall(function() styles = BridgeVoice.stylesFor(gender) end)
    end
    local style = randomEntry(styles)
    if style ~= nil then
        c.voice = {
            name = tostring(style.name),
            prefix = tostring(style.prefix),
            type = tonumber(style.type) or 0,
            pitch = math.floor((tonumber(style.pitch) or 0) + 0.5),
        }
    else
        c.voice = BridgeData.defaultVoice(gender)
    end
    BridgePregame.setActiveVoice(draft, c.voice)

    local species = "Hooman"
    if BridgeAppearance.furOn() == true and ZombRand(100) >= 75 then
        local fur = randomEntry(safeList(function() return BridgeAppearance.Catalog.furEntries() end))
        if fur ~= nil then species = fur.name end
    end
    c.fur = (species ~= "Hooman") and species or nil
    BridgePregame.setActiveSpecies(draft, species)

    local clothing = {}
    local allowed = self:availableLocations(gender)
    for _, loc in ipairs(self.clothOrder) do
        if allowed[loc] then
            local def = self:definition(loc, gender)
            local chance = def and def.chance
            if chance == nil or ZombRand(100) < chance then
                local options = self:clothOptions(loc, gender)
                local option = randomEntry(options)
                if option ~= nil then
                    local entry = { loc = loc, t = option.t }
                    local info = textureInfo(entry)
                    if info ~= nil then
                        entry[info.kind] = ZombRand(info.count)
                    end
                    if allowsTint(entry) then
                        entry.tint = { ZombRand(1000) / 1000, ZombRand(1000) / 1000, ZombRand(1000) / 1000 }
                    end
                    clothing[#clothing + 1] = entry
                end
            end
        end
    end
    BridgePregame.captureClothTint(clothing)
    BridgePregame.setActiveClothing(draft, clothing)

    BridgeAppearance.previewClothing = clothing
    BridgeAppearance.refreshPreview()
    self:refreshName()
    self:rebuildControls()
    self:refreshLooks()
    self:syncLook()
end

function BridgePregameScreen:onRandom()
    self:randomize()
end

function BridgePregameScreen:lookExtras()
    local draft = self.draft
    if draft == nil then return nil end
    return {
        voice = BridgeAppearance.voiceToken(BridgePregame.activeVoice(draft), draft.gender),
        species = BridgePregame.activeSpecies(draft) or "Hooman",
        clothing = BridgeAppearance.clothToken(BridgePregame.activeClothing(draft) or {}),
    }
end

function BridgePregameScreen:applyLookExtras(look)
    local draft = self.draft
    if draft == nil or type(look) ~= "table" or type(look.raw) ~= "table" then return end
    if look.has.voice and type(look.raw.voice) == "string" then
        local voice = BridgeAppearance.voiceFromToken(look.raw.voice, draft.gender)
        if voice ~= nil then
            BridgeAppearance.candidate.voice = voice
            BridgePregame.setActiveVoice(draft, voice)
        end
    end
    if look.has.species and type(look.raw.species) == "string" then
        local species = BridgeAppearance.speciesName(look.raw.species)
        if species ~= nil then
            BridgePregame.setActiveSpecies(draft, species)
            BridgeAppearance.candidate.fur = (species ~= "Hooman") and species or nil
        end
    end
    if look.has.clothing then
        local clothing = BridgeAppearance.clothFromToken(look.raw.clothing)
        if clothing ~= nil then BridgePregame.setActiveClothing(draft, clothing) end
    end
    BridgeAppearance.previewClothing = BridgePregame.activeClothing(draft)
end

function BridgePregameScreen:onLook(combo)
    BridgeAppearance.Window.onLook(self, combo)
    local name = self:selectedLook()
    if name ~= nil and BridgeLooks ~= nil then
        local look = nil
        pcall(function() look = BridgeLooks.find(name) end)
        if look ~= nil then self:applyLookExtras(look) end
    end
    BridgeAppearance.refreshPreview()
    self:refresh()
end

function BridgePregameScreen:onSave()
    BridgeAppearance.Window.onSave(self)
end

function BridgePregameScreen:onSaveDone(button)
    BridgeAppearance.Window.onSaveDone(self, button)
end

function BridgePregameScreen:onDelete()
    BridgeAppearance.Window.onDelete(self)
end

function BridgePregameScreen:onDeleteDone(button)
    BridgeAppearance.Window.onDeleteDone(self, button)
end

function BridgePregameScreen:onBack()
    BridgePregame.back()
end

function BridgePregameScreen:onStart()
    BridgePregame.start()
end

function BridgePregameScreen:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    if self.startBtn ~= nil then self:setISButtonForA(self.startBtn) end
    if self.backBtn ~= nil then self:setISButtonForB(self.backBtn) end
end

function BridgePregameScreen:onLoseJoypadFocus(joypadData)
    if self.startBtn ~= nil then self.startBtn:clearJoypadButton() end
    if self.backBtn ~= nil then self.backBtn:clearJoypadButton() end
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
end

function BridgePregameScreen:close()
    BridgePregame.back()
end

function BridgePregameScreen:new(x, y, width, height)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0.03, g = 0.03, b = 0.04, a = 0.94 }
    o.borderColor = { r = 0.35, g = 0.35, b = 0.35, a = 1 }
    o.anchorLeft = true
    o.anchorRight = true
    o.anchorTop = true
    o.anchorBottom = true
    o.moveWithMouse = false
    return o
end

function BridgePregame.randomizeActive()
    local screen = BridgePregame.screen
    if screen ~= nil and type(screen.randomize) == "function" then screen:randomize() end
end

function BridgePregame.hideScreen()
    local screen = BridgePregame.screen
    if screen ~= nil then
        pcall(screen.setVisible, screen, false)
        if screen.startBtn ~= nil then pcall(function() screen.startBtn:clearJoypadButton() end) end
        if screen.backBtn ~= nil then pcall(function() screen.backBtn:clearJoypadButton() end) end
    end
    if BridgeAppearance ~= nil then
        if BridgeAppearance.instance == screen then BridgeAppearance.instance = nil end
        BridgeAppearance.draftStore = nil
        BridgeAppearance.previewStarter = nil
        BridgeAppearance.previewClothing = nil
        BridgeAppearance.previewOverride = nil
        local candidate = BridgeAppearance.candidate
        if type(candidate) == "table" then
            candidate.gender = nil
            candidate.male = nil
        end
    end
    BridgePregame.active = false
end

function BridgePregame.destroyScreen()
    BridgePregame.hideScreen()
    local screen = BridgePregame.screen
    BridgePregame.screen = nil
    if screen == nil then return end
    pcall(screen.setVisible, screen, false)
    local ms = MainScreen.instance
    if ms ~= nil then pcall(function() ms:removeChild(screen) end) end
end

function BridgePregame.show()
    local ms = MainScreen.instance
    if ms == nil or ms.charCreationMain == nil then return false end
    local draft = BridgePregame.ensureDraft()
    if draft == nil or BridgeAppearance == nil then return false end
    draft.store = draft.store or { gender = draft.gender }
    draft.store.gender = draft.gender
    BridgeAppearance.draftStore = draft.store
    BridgeAppearance.previewStarter = nil
    BridgeAppearance.previewOverride = nil
    BridgeAppearance.loadCandidate(draft)
    BridgeAppearance.previewClothing = BridgePregame.activeClothing(draft)
    local screen = BridgePregame.screen
    if screen == nil then
        screen = BridgePregameScreen:new(0, 0, ms:getWidth(), ms:getHeight())
        screen.draft = draft
        screen:initialise()
        ms:addChild(screen)
        BridgePregame.screen = screen
    end
    screen.draft = draft
    BridgeAppearance.instance = screen
    BridgePregame.active = true
    screen:setX(0)
    screen:setY(0)
    screen:setWidth(ms:getWidth())
    screen:setHeight(ms:getHeight())
    screen:layout()
    screen:syncUI()
    local joypad = nil
    pcall(function() joypad = JoypadState.getMainMenuJoypad() end)
    screen:setVisible(true, joypad)
    pcall(function() screen:bringToTop() end)
    if joypad ~= nil then
        pcall(function() screen:setJoypadFocusTopLeft(joypad) end)
    end
    return true
end

function BridgePregame.back()
    local screen = BridgePregame.screen
    if screen ~= nil and screen.draft ~= nil then
        screen:captureName()
        BridgeAppearance.snapshotCandidate(screen.draft)
    end
    BridgePregame.hideScreen()
    showCreation()
end

function BridgePregame.start()
    local screen = BridgePregame.screen
    if screen == nil or screen.draft == nil then return end
    local draft = screen.draft
    screen:captureName()
    draft.name = BridgeData.cleanName(draft.name) or BridgeData.DEFAULT_NAME
    draft.maleName = BridgeData.cleanName(draft.maleName) or BridgeData.DEFAULT_MALE_NAME
    BridgeAppearance.snapshotCandidate(draft)
    if not BridgePregame.writeDraft(draft) then
        warn("draft write failed")
        return
    end
    BridgePregame.destroyScreen()
    showCreation()
    BridgePregame.finishPending()
end

function BridgePregame.restoreAfterFailure()
    hideCreation()
    if BridgePregame.draft ~= nil then
        BridgePregame.show()
    else
        showCreation()
    end
end

function BridgePregame.finishPending()
    local pending = BridgePregame.pending
    BridgePregame.pending = nil
    if pending == nil or type(BridgePregame.original) ~= "function" then return end
    local button = pending.button
    if type(button) ~= "table" or button.internal ~= "NEXT" then
        button = pending.self ~= nil and pending.self.playButton or button
    end
    local chain = nil
    if type(CharacterCreationMain) == "table" then chain = CharacterCreationMain.onOptionMouseDown end
    if type(chain) ~= "function" then chain = BridgePregame.original end
    BridgePregame.finishing = true
    local ok, err = pcall(chain, pending.self, button, pending.x, pending.y)
    BridgePregame.finishing = false
    if not ok then
        warn("character creation NEXT failed: " .. tostring(err))
        removeDraftFile()
        BridgePregame.restoreAfterFailure()
    end
end

function BridgePregame.eligible()
    if type(isClient) == "function" and isClient() then return false end
    local ms = MainScreen.instance
    if ms == nil or ms.createWorld ~= true then return false end
    local core = nil
    pcall(function() core = getCore() end)
    if core ~= nil then
        local challenge = false
        pcall(function() challenge = core:isChallenge() == true end)
        if challenge then return false end
        local mode = ""
        pcall(function() mode = tostring(core:getGameMode() or "") end)
        if mode == "LastStand" then return false end
    end
    return true
end

function BridgePregame.intercept(owner, button, x, y)
    if type(button) ~= "table" or button.internal ~= "NEXT" then return false end
    if BridgePregame.active then return true end
    if BridgePregame.finishing then return false end
    if not BridgePregame.eligible() then return false end
    BridgePregame.pending = { self = owner, button = button, x = x, y = y }
    local shownOk, shown = pcall(BridgePregame.show)
    if not shownOk then
        warn("screen failed: " .. tostring(shown))
        shown = false
    end
    if not shown then
        BridgePregame.pending = nil
        showCreation()
        return true
    end
    hideCreation()
    pcall(function()
        local joypad = JoypadState.getMainMenuJoypad()
        if joypad ~= nil and BridgePregame.screen ~= nil then
            BridgePregame.screen:setJoypadFocusTopLeft(joypad)
        end
    end)
    return true
end

function BridgePregame.updatePlayButton(owner)
    if owner == nil or owner.playButton == nil then return end
    local button = owner.playButton
    if owner.__bridgePlayButton ~= button then
        owner.__bridgePlayButton = button
        owner.__bridgePlayToken = nil
        button.__bridgeOnClick = nil
    end
    local eligible = BridgePregame.eligible() and not BridgePregame.active
    local token = eligible and "next" or "play"
    local key = eligible and "UI_btn_next" or "UI_btn_play"
    local label = nil
    pcall(function() label = getText(key) end)
    if type(label) ~= "string" or label == "" or label == key then label = nil end
    if eligible then
        if label ~= nil and button.title ~= label then
            pcall(function() button:setTitle(label) end)
        end
    elseif owner.__bridgePlayToken ~= token then
        if label ~= nil then pcall(function() button:setTitle(label) end) end
    end
    owner.__bridgePlayToken = token
    if eligible then
        if button.__bridgeOnClick == nil then
            if button.onclick ~= BridgePregame.onPlayClicked then
                button.__bridgeOnClick = button.onclick
            else
                button.__bridgeOnClick = BridgePregame.original
            end
        end
        if button.onclick ~= BridgePregame.onPlayClicked then
            button.onclick = BridgePregame.onPlayClicked
        end
    elseif button.__bridgeOnClick ~= nil and button.onclick == BridgePregame.onPlayClicked then
        button.onclick = button.__bridgeOnClick
    end
end

function BridgePregame.onPlayClicked(owner, button)
    if type(owner) ~= "table" then
        local ms = MainScreen.instance
        owner = nil
        if ms ~= nil then owner = ms.charCreationMain end
    end
    if owner == nil then return end
    if BridgePregame.active or BridgePregame.finishing then return end
    local target = button
    if type(target) ~= "table" then target = owner.playButton end
    if BridgePregame.intercept(owner, target, 0, 0) then return end
    local original = nil
    if type(target) == "table" then original = target.__bridgeOnClick end
    if type(original) == "function" then return original(owner, target) end
    if type(BridgePregame.original) == "function" then
        return BridgePregame.original(owner, target, 0, 0)
    end
end

function BridgePregame.wrapCharacterCreation()
    if type(CharacterCreationMain) ~= "table" then return false end
    if type(CharacterCreationMain.onOptionMouseDown) ~= "function" then return false end
    if not CharacterCreationMain.__bridgeWrapMouse then
        CharacterCreationMain.__bridgeWrapMouse = true
        BridgePregame.original = CharacterCreationMain.onOptionMouseDown
        local original = BridgePregame.original
        CharacterCreationMain.onOptionMouseDown = function(self, button, x, y)
            if BridgePregame.intercept(self, button, x, y) then return end
            return original(self, button, x, y)
        end
    end
    if not CharacterCreationMain.__bridgeWrapPrerender then
        CharacterCreationMain.__bridgeWrapPrerender = true
        local originalPrerender = CharacterCreationMain.prerender
        CharacterCreationMain.prerender = function(self)
            if type(originalPrerender) == "function" then originalPrerender(self) end
            BridgePregame.updatePlayButton(self)
        end
    end
    if not CharacterCreationMain.__bridgeWrapCreate then
        CharacterCreationMain.__bridgeWrapCreate = true
        local originalCreate = CharacterCreationMain.create
        CharacterCreationMain.create = function(self)
            if type(originalCreate) == "function" then originalCreate(self) end
            BridgePregame.updatePlayButton(self)
        end
    end
    return true
end

function BridgePregame.install()
    if BridgePregame.installed then
        BridgePregame.wrapCharacterCreation()
        return
    end
    if not BridgePregame.wrapCharacterCreation() then return end
    BridgePregame.installed = true
    if type(MainScreen) == "table" and type(MainScreen.onKeyRelease) == "function" then
        local originalKey = MainScreen.onKeyRelease
        MainScreen.onKeyRelease = function(self, key)
            local modal = false
            pcall(function() modal = UIManager.isModalVisible() == true end)
            if BridgePregame.active and not modal and key == Keyboard.KEY_ESCAPE then
                BridgePregame.back()
                return
            end
            return originalKey(self, key)
        end
    end
    log("installed")
    print("[BridgePregame] installed")
end

BridgePregame.loaded = true
BridgePregame.install()
if type(Events) == "table" then
    local names = { "OnGameBoot", "OnMainMenuEnter", "OnGameStart" }
    for i = 1, #names do
        local event = Events[names[i]]
        if event ~= nil and type(event.Add) == "function" then event.Add(BridgePregame.install) end
    end
end

print("[BridgePregame] loaded")
