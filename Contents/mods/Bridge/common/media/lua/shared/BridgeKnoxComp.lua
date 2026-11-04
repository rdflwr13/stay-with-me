BridgeKnoxComp = BridgeKnoxComp or {}

local MOD_ID = "KnoxCompanions"
local SENTINEL = "swm_foreign"
local activeCache = false
local marked = setmetatable({}, { __mode = "k" })

function BridgeKnoxComp.active()
    if activeCache then return true end
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(MOD_ID) or mods:contains("\\" .. MOD_ID))
    end)
    if on then activeCache = true end
    return on
end

local function bodyData(z)
    local md = nil
    pcall(function() md = z:getModData() end)
    return md
end

function BridgeKnoxComp.isBody(z)
    if z == nil then return false end
    local zombie = false
    pcall(function() zombie = instanceof(z, "IsoZombie") == true end)
    if not zombie then return false end
    local md = bodyData(z)
    local id = md ~= nil and md.KC_id or nil
    return type(id) == "string" and id ~= "" and id ~= SENTINEL
end

function BridgeKnoxComp.peaceful(z)
    if not BridgeKnoxComp.active() then return false end
    return BridgeKnoxComp.isBody(z)
end

function BridgeKnoxComp.markOurs(z)
    if z == nil then return end
    if Bridge ~= nil and Bridge.mp then return end
    if not BridgeKnoxComp.active() then return end
    if marked[z] then return end
    local md = bodyData(z)
    if md == nil then return end
    if md.KC_id == nil then md.KC_id = SENTINEL end
    marked[z] = true
end

function BridgeKnoxComp.clearOurs(z)
    if z == nil then return end
    marked[z] = nil
    local md = bodyData(z)
    if md ~= nil and md.KC_id == SENTINEL then md.KC_id = nil end
end

function BridgeKnoxComp.selftest()
    local checks, fails = 0, {}
    local function check(name, cond)
        checks = checks + 1
        if not cond then fails[#fails + 1] = name end
    end

    local savedInstanceof = rawget(_G, "instanceof")
    local savedBridge = rawget(_G, "Bridge")
    local savedActive = BridgeKnoxComp.active
    rawset(_G, "instanceof", function(obj, name)
        return type(obj) == "table" and obj.class == name
    end)
    local function stub(md, class)
        return {
            class = class or "IsoZombie",
            md = md or {},
            getModData = function(self) return self.md end,
        }
    end

    local knox = stub({ KC_id = "kc123" })
    local sentinel = stub({ KC_id = SENTINEL })
    local plain = stub({})
    local person = stub({ KC_id = "kc123" }, "IsoPlayer")
    check("knox body recognized", BridgeKnoxComp.isBody(knox) == true)
    check("sentinel is not a Knox body", BridgeKnoxComp.isBody(sentinel) == false)
    check("unmarked body is not Knox", BridgeKnoxComp.isBody(plain) == false)
    check("non-zombie is not Knox", BridgeKnoxComp.isBody(person) == false)

    BridgeKnoxComp.clearOurs(knox)
    check("clear leaves a real Knox id", knox.md.KC_id == "kc123")
    BridgeKnoxComp.clearOurs(sentinel)
    check("clear removes the sentinel", sentinel.md.KC_id == nil)

    BridgeKnoxComp.active = function() return false end
    rawset(_G, "Bridge", { mp = false })
    local idle = stub({})
    BridgeKnoxComp.markOurs(idle)
    check("mark is inert without Knox", idle.md.KC_id == nil)
    check("peaceful is inert without Knox", BridgeKnoxComp.peaceful(knox) == false)

    BridgeKnoxComp.active = function() return true end
    check("peaceful sees a Knox body", BridgeKnoxComp.peaceful(knox) == true)
    BridgeKnoxComp.markOurs(idle)
    check("mark writes the sentinel", idle.md.KC_id == SENTINEL)
    check("marked body is not a Knox body", BridgeKnoxComp.isBody(idle) == false)
    BridgeKnoxComp.clearOurs(idle)
    check("clear removes the written sentinel", idle.md.KC_id == nil)

    BridgeKnoxComp.active = savedActive
    rawset(_G, "instanceof", savedInstanceof)
    rawset(_G, "Bridge", savedBridge)

    if #fails == 0 then return string.format("knoxselftest PASS (%d checks)", checks) end
    return string.format("knoxselftest FAIL (%d of %d): %s", checks, #fails, table.concat(fails, "; "))
end
