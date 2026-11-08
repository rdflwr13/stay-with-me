BridgeSpeech = BridgeSpeech or {}

BridgeSpeech.LANGS = { "EN", "DE", "ES", "FR", "IT", "PTBR", "RU" }
BridgeSpeech.MIN_INDEX = 1
BridgeSpeech.MAX_INDEX = 9
BridgeSpeech.AUTO_INDEX = 9
BridgeSpeech.AUTO_LANGS = { "CN", "CH", "ZH", "ZHCN", "CHS", "TW", "ZHTW", "JP", "KR" }
BridgeSpeech.tables = {}
BridgeSpeech.state = {}
BridgeSpeech.auto = nil
BridgeSpeech.autoDone = false
BridgeSpeech.status = "idle"

local function log(text)
    if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeSpeech] " .. tostring(text)) end
end

local function tableSize(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function BridgeSpeech.index()
    local v = BridgeSpeech.MIN_INDEX
    pcall(function()
        v = BridgeData.sandboxNumber("SpeechLanguage", BridgeSpeech.MIN_INDEX, BridgeSpeech.MIN_INDEX, BridgeSpeech.MAX_INDEX)
    end)
    v = tonumber(v) or BridgeSpeech.MIN_INDEX
    if v < BridgeSpeech.MIN_INDEX then v = BridgeSpeech.MIN_INDEX end
    if v > BridgeSpeech.MAX_INDEX then v = BridgeSpeech.MAX_INDEX end
    return math.floor(v)
end

function BridgeSpeech.locale()
    local i = BridgeSpeech.index()
    if i <= BridgeSpeech.MIN_INDEX then return nil end
    if i == BridgeSpeech.AUTO_INDEX then return "AUTO" end
    return BridgeSpeech.LANGS[i - 1]
end

local function normalize(name)
    if type(name) ~= "string" then return nil end
    local out = string.upper(name)
    out = string.gsub(out, "[^%w]", "")
    if out == "" then return nil end
    return out
end

local function gameLanguage()
    local name = nil
    pcall(function() name = Translator.getLanguage():name() end)
    return normalize(name)
end

local function localeIsGameLanguage(locale)
    local game = gameLanguage()
    if game == nil then return false end
    return normalize(locale) == game
end

local function decode(value)
    local out = value
    out = string.gsub(out, "\\n", "\n")
    out = string.gsub(out, "\\t", "\t")
    out = string.gsub(out, '\\"', '"')
    out = string.gsub(out, "\\/", "/")
    out = string.gsub(out, "\\\\", "\\")
    return out
end

local function cacheKey(mod, lang)
    return tostring(mod) .. "|" .. tostring(lang)
end

local function readLocale(mod, lang)
    local key = cacheKey(mod, lang)
    if BridgeSpeech.tables[key] ~= nil then return BridgeSpeech.tables[key] end
    if BridgeSpeech.state[key] == "failed" then return nil end
    local sep = "/"
    pcall(function() sep = getFileSeparator() end)
    local rel = "media" .. sep .. "lua" .. sep .. "shared" .. sep .. "Translate" .. sep .. lang .. sep .. "IG_UI.json"
    local candidates = { rel, "common" .. sep .. rel }
    for i = 1, #candidates do
        local reader = nil
        pcall(function() reader = getModFileReader(mod, candidates[i], false) end)
        if reader ~= nil then
            local lines = {}
            local ok = pcall(function()
                local guard = 0
                while guard < 60000 do
                    guard = guard + 1
                    local line = reader:readLine()
                    if line == nil then break end
                    lines[#lines + 1] = tostring(line)
                end
            end)
            pcall(function() reader:close() end)
            if ok and #lines > 0 then
                local map = {}
                local count = 0
                local bad = 0
                for i = 1, #lines do
                    local k, value = string.match(lines[i], '^%s*"([^"]+)"%s*:%s*"(.*)"%s*,?%s*$')
                    if k ~= nil then
                        map[k] = decode(value)
                        count = count + 1
                    elseif string.find(lines[i], '"', 1, true) ~= nil then
                        bad = bad + 1
                    end
                end
                if count > 0 then
                    BridgeSpeech.tables[key] = map
                    BridgeSpeech.state[key] = "ok"
                    if mod == "Bridge" then
                        BridgeSpeech.status = string.format("locale=%s keys=%d loaded=yes", lang, count)
                        if bad > 0 then
                            log(BridgeSpeech.status .. " unmatched=" .. tostring(bad))
                        else
                            log(BridgeSpeech.status)
                        end
                    end
                    return map
                end
            end
        end
    end
    BridgeSpeech.state[key] = "failed"
    return nil
end

local function candidateLangs()
    local out, seen = {}, {}
    local function add(v)
        local n = normalize(v)
        if n ~= nil and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
        end
    end
    add(gameLanguage())
    for i = 1, #BridgeSpeech.AUTO_LANGS do add(BridgeSpeech.AUTO_LANGS[i]) end
    return out
end

local function probeLocale(mod, lang, probeKey)
    local sep = "/"
    pcall(function() sep = getFileSeparator() end)
    local rel = "media" .. sep .. "lua" .. sep .. "shared" .. sep .. "Translate" .. sep .. lang .. sep .. "IG_UI.json"
    local candidates = { rel, "common" .. sep .. rel }
    for i = 1, #candidates do
        local reader = nil
        pcall(function() reader = getModFileReader(mod, candidates[i], false) end)
        if reader ~= nil then
            local found = false
            local ok = pcall(function()
                local guard = 0
                while guard < 60000 do
                    guard = guard + 1
                    local line = reader:readLine()
                    if line == nil then break end
                    if string.find(line, probeKey, 1, true) ~= nil then
                        found = true
                        break
                    end
                end
            end)
            pcall(function() reader:close() end)
            if ok then return found end
        end
    end
    return false
end

local function detectAuto()
    if BridgeSpeech.autoDone then return BridgeSpeech.auto end
    BridgeSpeech.autoDone = true
    local mods = nil
    pcall(function() mods = getActivatedMods() end)
    if mods == nil then return nil end
    local count = 0
    pcall(function() count = mods:size() end)
    if count == nil or count <= 0 then return nil end
    local langs = candidateLangs()
    local probe = '"IGUI_NotAlone_Talk_Chat"'
    for mi = 0, count - 1 do
        local id = nil
        pcall(function() id = tostring(mods:get(mi)) end)
        if id ~= nil and id ~= "" and id ~= "Bridge" then
            for li = 1, #langs do
                if probeLocale(id, langs[li], probe) then
                    local map = readLocale(id, langs[li])
                    if map ~= nil and map["IGUI_NotAlone_Talk_Chat"] ~= nil then
                        BridgeSpeech.auto = { mod = id, lang = langs[li] }
                        BridgeSpeech.status = "auto mod=" .. id .. " locale=" .. langs[li]
                        log(BridgeSpeech.status)
                        return BridgeSpeech.auto
                    end
                end
            end
        end
    end
    log("auto none")
    return nil
end

local function formatValue(value, a, b)
    if type(value) ~= "string" then return value end
    local args = { a, b }
    local out = string.gsub(value, "%%(%d)", function(n)
        local v = args[tonumber(n)]
        if v == nil then return "%" .. n end
        return tostring(v)
    end)
    out = string.gsub(out, "%%%%", function() return "%" end)
    return out
end

local function sourceTable()
    local lang = BridgeSpeech.locale()
    if lang == nil then return nil end
    if lang == "AUTO" then
        local hit = detectAuto()
        if hit == nil then return nil end
        return readLocale(hit.mod, hit.lang)
    end
    if localeIsGameLanguage(lang) then return nil end
    return readLocale("Bridge", lang)
end

local function localizedValue(key)
    local lang = BridgeSpeech.locale()
    if lang == nil then return nil, false end
    local map = sourceTable()
    if map == nil then
        if lang == "AUTO" then return nil, false end
        return nil, true
    end
    if map[key] ~= nil then return map[key], true end
    local en = readLocale("Bridge", "EN")
    if en ~= nil and en[key] ~= nil then return en[key], true end
    return nil, true
end

local function resolve(key, a, b)
    if type(key) ~= "string" then return nil end
    local value = nil
    local ok = false
    local called = false
    pcall(function()
        called = true
        value, ok = localizedValue(key)
    end)
    if not called or not ok or value == nil then return nil end
    return formatValue(value, a, b)
end

function BridgeSpeech.exists(key)
    if type(key) ~= "string" then return false end
    local hit = nil
    pcall(function()
        local value = localizedValue(key)
        if value ~= nil then hit = value end
    end)
    if hit ~= nil then return true end
    local out = nil
    pcall(function() out = getTextOrNull(key) end)
    if type(out) ~= "string" or out == "" or out == key then return false end
    return true
end

function BridgeSpeech.getOrNull(key, a, b)
    if type(key) ~= "string" then return nil end
    local text = nil
    pcall(function() text = resolve(key, a, b) end)
    if text ~= nil then return text end
    local out = nil
    pcall(function()
        if b ~= nil then out = getTextOrNull(key, a, b)
        elseif a ~= nil then out = getTextOrNull(key, a)
        else out = getTextOrNull(key) end
    end)
    if type(out) ~= "string" or out == "" or out == key then return nil end
    return out
end

function BridgeSpeech.get(key, a, b)
    local text = nil
    if type(key) == "string" then
        pcall(function() text = resolve(key, a, b) end)
    end
    if text ~= nil then return text end
    local out = key
    pcall(function()
        if b ~= nil then out = getText(key, a, b)
        elseif a ~= nil then out = getText(key, a)
        else out = getText(key) end
    end)
    return out
end

function BridgeSpeech.sayKey(suffix)
    local base = "IGUI_NotAlone_Say_" .. tostring(suffix)
    local male = false
    pcall(function() male = BridgeData.isMale(Bridge.store) == true end)
    if not male then return base end
    local alt = "IGUI_NotAlone_SayM_" .. tostring(suffix)
    if BridgeSpeech.exists(alt) then return alt end
    return base
end

function BridgeSpeech.getSay(suffix, a, b)
    return BridgeSpeech.get(BridgeSpeech.sayKey(suffix), a, b)
end

function BridgeSpeech.info()
    local lang = BridgeSpeech.locale()
    if lang == nil then return "locale=game keys=0 loaded=no" end
    if lang == "AUTO" then
        local hit = detectAuto()
        if hit == nil then return "locale=game keys=0 loaded=no auto=none" end
        local map = BridgeSpeech.tables[cacheKey(hit.mod, hit.lang)]
        local n = map ~= nil and tableSize(map) or 0
        return string.format("locale=%s mod=%s keys=%d loaded=yes", hit.lang, hit.mod, n)
    end
    local map = BridgeSpeech.tables[cacheKey("Bridge", lang)]
    local loaded = map ~= nil and "yes" or "no"
    local n = map ~= nil and tableSize(map) or 0
    return string.format("locale=%s keys=%d loaded=%s", lang, n, loaded)
end
