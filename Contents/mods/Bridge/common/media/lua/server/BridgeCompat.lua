BridgeCompat = BridgeCompat or {}
BridgeCompat.wrapped = nil
BridgeCompat.wrappedVariant = nil
BridgeCompat.ticks = 0
BridgeCompat.missingLogged = false

local function log(text) if BridgeLog ~= nil and BridgeLog.on() then print("[BridgeCompat] " .. tostring(text)) end end

local function modActive(id)
    local on = false
    pcall(function()
        local mods = getActivatedMods()
        on = mods ~= nil and (mods:contains(id) or mods:contains("\\" .. id))
    end)
    return on
end

function BridgeCompat.isOurBody(z)
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






BridgeCompat.alifeWanted = nil
BridgeCompat.alifeTicks = 0
BridgeCompat.alifeMarked = nil
BridgeCompat.alifeCanAttack = nil
BridgeCompat.alifeStrikeZombie = nil

local function alifeOurs(z)
    if z == nil then return false end
    if Bridge ~= nil and Bridge.body == z then return true end
    local ok, marked = pcall(function() return z:getVariableBoolean("NotAloneBody") end)
    if ok and marked == true then return true end
    local md = nil
    pcall(function() if z:hasModData() then md = z:getModData() end end)
    return type(md) == "table" and md.notAloneBody == true
end

function BridgeCompat.alifeInstall()
    if BridgeCompat.alifeWanted == nil then BridgeCompat.alifeWanted = modActive("ProjectALifeNPCs") end
    if not BridgeCompat.alifeWanted then return false end
    local mod = rawget(_G, "ProjectALife")
    if type(mod) ~= "table" then return false end
    local installed = false


    local guard = mod.OrphanGuard
    if type(guard) == "table" and type(guard.markedWith) == "function"
            and guard.markedWith ~= BridgeCompat.alifeMarked then
        local original = guard.markedWith
        BridgeCompat.alifeMarked = function(shell, data)
            if alifeOurs(shell) then return true end
            return original(shell, data)
        end
        guard.markedWith = BridgeCompat.alifeMarked
        installed = true
    end


    local policy = mod.TargetPolicy
    if type(policy) == "table" and type(policy.canAttack) == "function"
            and policy.canAttack ~= BridgeCompat.alifeCanAttack then
        local original = policy.canAttack
        BridgeCompat.alifeCanAttack = function(target, stamp)
            if alifeOurs(target) then return false, "bridge_companion" end
            return original(target, stamp)
        end
        policy.canAttack = BridgeCompat.alifeCanAttack
        installed = true
    end



    local combat = mod.Combat
    if type(combat) == "table" and type(combat.strikeZombie) == "function"
            and combat.strikeZombie ~= BridgeCompat.alifeStrikeZombie then
        local original = combat.strikeZombie
        BridgeCompat.alifeStrikeZombie = function(shell, zombie, weapon, reaction, share)
            if alifeOurs(zombie) then return false end
            return original(shell, zombie, weapon, reaction, share)
        end
        combat.strikeZombie = BridgeCompat.alifeStrikeZombie
        installed = true
    end

    if installed then log("A-Life: her body is left alone (weapons kept, not a target)") end
    return installed
end

function BridgeCompat.alifeTick()
    if BridgeCompat.alifeWanted == nil then BridgeCompat.alifeWanted = modActive("ProjectALifeNPCs") end
    if not BridgeCompat.alifeWanted then return end
    BridgeCompat.alifeTicks = BridgeCompat.alifeTicks + 1
    if BridgeCompat.alifeTicks > 1 and BridgeCompat.alifeTicks % 60 ~= 0 then return end
    BridgeCompat.alifeInstall()
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

Events.OnTick.Add(function() pcall(BridgeCompat.tick) pcall(BridgeCompat.alifeTick) pcall(BridgeCompat.survivorsTick) end)
Events.OnGameStart.Add(function() BridgeCompat.ticks = 0 BridgeCompat.survivorsTicks = 0 pcall(BridgeCompat.install) pcall(BridgeCompat.alifeInstall) pcall(BridgeCompat.survivorsInstall) end)
Events.OnServerStarted.Add(function() BridgeCompat.ticks = 0 BridgeCompat.survivorsTicks = 0 pcall(BridgeCompat.install) pcall(BridgeCompat.alifeInstall) pcall(BridgeCompat.survivorsInstall) end)
