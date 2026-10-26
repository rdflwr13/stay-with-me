BridgeCompat = BridgeCompat or {}
BridgeCompat.wrapped = nil
BridgeCompat.wrappedVariant = nil
BridgeCompat.ticks = 0
BridgeCompat.missingLogged = false

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeCompat] " .. tostring(text)) end end


local function markedOurs(z)
    if z == nil then return false end
    if Bridge ~= nil and Bridge.body == z then return true end
    local ok, marked = pcall(function() return z:getVariableBoolean("NotAloneBody") end)
    if ok and marked == true then return true end
    local md = nil
    pcall(function() if z:hasModData() then md = z:getModData() end end)
    return type(md) == "table" and md.notAloneBody == true
end


local function modActive(id)
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(id) or mods:contains("\\" .. id))
    end)
    return on
end

function BridgeCompat.isOurBody(z)
    if markedOurs(z) then return true end
    local ours = false
    if BridgeServer ~= nil and type(BridgeServer.isCompanionBody) == "function" then
        pcall(function() ours = BridgeServer.isCompanionBody(z) end)
    end
    return ours
end

function BridgeCompat.isOurId(pid)
    local ours = false
    if BridgeServer ~= nil and type(BridgeServer.isCompanionId) == "function" then
        pcall(function() ours = BridgeServer.isCompanionId(pid) end)
    end
    if ours then return true end
    if pid ~= nil and Bridge ~= nil and Bridge.body ~= nil then
        pcall(function() ours = Bridge.body:getPersistentOutfitID() == pid end)
    end
    return ours
end

function BridgeCompat.install()
    local pzm = rawget(_G, "PZTheMutants")
    local installed = false

    local fo = pzm ~= nil and pzm.ForeignOwnership or nil
    if fo ~= nil and type(fo.isClaimed) == "function" then
        if fo.isClaimed ~= BridgeCompat.wrapped then
            local original = fo.isClaimed
            local wrapper
            wrapper = function(zombie, outfitName)
                local claimed, owner, reason = original(zombie, outfitName)
                if claimed then return claimed, owner, reason end
                if BridgeCompat.isOurBody(zombie) then return true, "Bridge", "companion-marker" end
                return claimed, owner, reason
            end
            BridgeCompat.wrapped = wrapper
            fo.isClaimed = wrapper
            log("PZTheMutants compat guard installed")
        end
        installed = true
    end

    local identity = pzm ~= nil and pzm.Identity or nil
    if identity ~= nil and type(identity.getPersistentVariant) == "function" then
        if identity.getPersistentVariant ~= BridgeCompat.wrappedVariant then
            local originalVariant = identity.getPersistentVariant
            local wrapperVariant = function(persistentOutfitID)
                if BridgeCompat.isOurId(persistentOutfitID) then return nil end
                return originalVariant(persistentOutfitID)
            end
            BridgeCompat.wrappedVariant = wrapperVariant
            identity.getPersistentVariant = wrapperVariant
            log("PZTheMutants variant guard installed")
        end
        installed = true
    end

    if installed then
        BridgeCompat.missingLogged = false
        return true
    end

    if not BridgeCompat.missingLogged then
        BridgeCompat.missingLogged = true
        log("PZTheMutants gate not found; compat guard will keep retrying")
    end
    return false
end

function BridgeCompat.tick()
    if not modActive("PZTheMutants") then return end
    BridgeCompat.ticks = BridgeCompat.ticks + 1
    if BridgeCompat.ticks > 1 and BridgeCompat.ticks % 60 ~= 0 then return end
    BridgeCompat.install()
end

BridgeCompat.survivorsWanted = nil
BridgeCompat.survivorsTicks = 0
BridgeCompat.survivorsOurs = nil

function BridgeCompat.survivorsInstall()
    if BridgeCompat.survivorsWanted == nil then BridgeCompat.survivorsWanted = modActive("ProjectSurvivors") end
    if not BridgeCompat.survivorsWanted then return false end
    local ps = rawget(_G, "ProjectSurvivors")
    local bodies = type(ps) == "table" and ps.Bodies or nil
    if type(bodies) ~= "table" or type(bodies.isOurs) ~= "function" then return false end
    if bodies.isOurs == BridgeCompat.survivorsOurs then return true end
    local original = bodies.isOurs
    BridgeCompat.survivorsOurs = function(zombie)
        if BridgeCompat.isOurBody(zombie) then return true end
        return original(zombie)
    end
    bodies.isOurs = BridgeCompat.survivorsOurs
    log("ProjectSurvivors compat guard installed (her body is left alone)")
    return true
end

function BridgeCompat.survivorsTick()
    if BridgeCompat.survivorsWanted == nil then BridgeCompat.survivorsWanted = modActive("ProjectSurvivors") end
    if not BridgeCompat.survivorsWanted then return end
    BridgeCompat.survivorsTicks = BridgeCompat.survivorsTicks + 1
    if BridgeCompat.survivorsTicks > 1 and BridgeCompat.survivorsTicks % 60 ~= 0 then return end
    BridgeCompat.survivorsInstall()
end

BridgeCompat.divgadgetsWanted = nil
BridgeCompat.divgadgetsTicks = 0
BridgeCompat.divgadgetsWrapped = nil

function BridgeCompat.divgadgetsInstall()
    if BridgeCompat.divgadgetsWanted == nil then BridgeCompat.divgadgetsWanted = modActive("DivisionGadgets") end
    if not BridgeCompat.divgadgetsWanted then return false end
    local original = rawget(_G, "shdIsFriendly")
    if type(original) ~= "function" then return false end
    if original == BridgeCompat.divgadgetsWrapped then return true end
    local wrapper = function(zombie, owner)
        if BridgeCompat.isOurBody(zombie) then return true end
        return original(zombie, owner)
    end
    BridgeCompat.divgadgetsWrapped = wrapper
    rawset(_G, "shdIsFriendly", wrapper)
    log("Division Gadgets turret guard installed (her body is left alone)")
    return true
end

function BridgeCompat.divgadgetsTick()
    if BridgeCompat.divgadgetsWanted == nil then BridgeCompat.divgadgetsWanted = modActive("DivisionGadgets") end
    if not BridgeCompat.divgadgetsWanted then return end
    BridgeCompat.divgadgetsTicks = BridgeCompat.divgadgetsTicks + 1
    if BridgeCompat.divgadgetsTicks > 1 and BridgeCompat.divgadgetsTicks % 60 ~= 0 then return end
    BridgeCompat.divgadgetsInstall()
end

Events.OnTick.Add(function() pcall(BridgeCompat.tick) pcall(BridgeCompat.survivorsTick) pcall(BridgeCompat.divgadgetsTick) end)
Events.OnGameStart.Add(function() BridgeCompat.ticks = 0 BridgeCompat.survivorsTicks = 0 BridgeCompat.divgadgetsTicks = 0 pcall(BridgeCompat.install) pcall(BridgeCompat.survivorsInstall) pcall(BridgeCompat.divgadgetsInstall) end)
Events.OnServerStarted.Add(function() BridgeCompat.ticks = 0 BridgeCompat.survivorsTicks = 0 BridgeCompat.divgadgetsTicks = 0 pcall(BridgeCompat.install) pcall(BridgeCompat.survivorsInstall) pcall(BridgeCompat.divgadgetsInstall) end)