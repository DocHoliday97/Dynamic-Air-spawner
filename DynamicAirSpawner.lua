-- ╔════════════════════════════════════════════════════════════════════════════╗
-- ║          D O C   D Y N A M I C   A I R   S P A W N E R                     ║
-- ║────────────────────────────────────────────────────────────────────────────║
-- ║  Version: 1.0                                                              ║
-- ║  Author : Doc                                                              ║
-- ║                                                                            ║
-- ║  Description:                                                              ║
-- ║   Dynamically spawns OPFOR air threats for airborne BLUE players.          ║
-- ║   Spawns occur inside the configured Frontline zone and use                ║
-- ║   loadout-aware scenario selection from Air_lib.lua.                       ║
-- ║                                                                            ║
-- ║  How to Use:                                                               ║
-- ║   1. In Mission Editor, create one or more trigger zones for spawning      ║
-- ║      and list their names in FRONTLINE_ZONES below.                        ║
-- ║   2. Add a MISSION START trigger with actions in this order:               ║
-- ║        • DO SCRIPT FILE -> Air_lib.lua                                     ║
-- ║        • DO SCRIPT FILE -> DynamicAirSpawner.lua                           ║
-- ║   3. Start the mission and get at least one BLUE player aircraft airborne. ║
-- ║   4. The manager auto-runs and spawns threats on its timer loop.           ║
-- ║                                                                            ║
-- ║  Config Quick Reference:                                                   ║
-- ║   DEBUG_MODE         : Debug text + F10 "Spawn Threat Now" command.        ║
-- ║   FRONTLINE_ZONES    : Trigger zone names used for spawn sampling.         ║
-- ║   SPAWN_COOLDOWN     : Minimum seconds between spawn events.               ║
-- ║   SPAWN_MIN_INTERVAL : Min seconds between manager loop ticks.             ║
-- ║   SPAWN_MAX_INTERVAL : Max seconds between manager loop ticks.             ║
-- ║   MAX_ACTIVE_GROUPS  : Maximum simultaneous spawned threat groups.        ║
-- ║   SPAWN_GROUP_OPTIONS: Possible aircraft counts for each spawned group.   ║
-- ║   MAX_AIRCRAFT_PER_GROUP : Maximum aircraft per spawned group.            ║
-- ║   SPAWN_ALT_MIN_M    : Global minimum spawn altitude clamp (meters).       ║
-- ║   SPAWN_ALT_MAX_M    : Global maximum spawn altitude clamp (meters).       ║
-- ║   FORCE_FIGHTER_BVR  : Forces fighter threats into BVR scenario families.  ║
-- ║   CURRENT_SKILL      : Skill value assigned to spawned units.              ║
-- ║                                                                            ║
-- ║  Notes:                                                                    ║
-- ║   - Group size scales by number of airborne BLUE players.                  ║
-- ║   - Lead and wingmen are corrected to remain in-zone.                      ║
-- ╚════════════════════════════════════════════════════════════════════════════╝

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local DEBUG_MODE = false

local CHECK_INTERVAL = 30
local SPAWN_COOLDOWN = 90
local FRONTLINE_ZONES = {
    "Frontline"
}
local SPAWN_MIN_INTERVAL = 180
local SPAWN_MAX_INTERVAL = 1200
local MAX_ACTIVE_GROUPS = 20
local SPAWN_GROUP_OPTIONS = { 2, 2, 2, 2, 4 }
local MAX_AIRCRAFT_PER_GROUP = 4
local SPAWN_ALT_MIN_M = 1500
local SPAWN_ALT_MAX_M = 8500
local FORCE_FIGHTER_BVR = true

local OPFOR_COUNTRY  = country.id.RUSSIA
local OPFOR_CATEGORY = Group.Category.AIRPLANE
local CURRENT_SKILL   = "HIGH" -- skill used in spawned threats

------------------------------------------------------------
-- DEBUG
------------------------------------------------------------
local function debug(msg)
    if DEBUG_MODE then
        trigger.action.outText("[Dynamic Air Spawner] " .. tostring(msg), 10)
    end
end

local function loadOpForAirLib()
    if not OpFor then
        local ok, err = pcall(dofile, [[Air_lib.lua]])
        if not ok then
            debug("Failed to load OpFor air library: " .. tostring(err))
        else
            debug("OpFor air library loaded")
        end
    end
end

local function getThreatPackage(threatType, distance, preferredScenario)
    if not OpFor or not OpFor.getSpawnPackage then
        debug("OpFor library not loaded")
        return nil
    end

    if preferredScenario and OpFor.getSpawnPackageForScenario then
        local pkg = OpFor.getSpawnPackageForScenario(threatType, preferredScenario)
        if pkg then
            return pkg
        end
    end

    return OpFor.getSpawnPackage(threatType, distance)
end

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local activeGroups = {}
local groupCounter = 1
local lastSpawnTime = 0
local lastThreatType = nil

------------------------------------------------------------
-- UTILS
------------------------------------------------------------
local function getZoneYorZ(p)
    if not p then
        return nil
    end
    if p.z ~= nil then
        return p.z
    end
    return p.y
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function getOrderedVertices(vertices)
    local ordered = {}
    for i, v in ipairs(vertices or {}) do
        ordered[i] = v
    end

    if #ordered < 3 then
        return ordered
    end

    local cx = 0
    local cz = 0
    for _, v in ipairs(ordered) do
        cx = cx + (v.x or 0)
        cz = cz + (getZoneYorZ(v) or 0)
    end
    cx = cx / #ordered
    cz = cz / #ordered

    table.sort(ordered, function(a, b)
        local aa = math.atan2((getZoneYorZ(a) or 0) - cz, (a.x or 0) - cx)
        local ab = math.atan2((getZoneYorZ(b) or 0) - cz, (b.x or 0) - cx)
        return aa < ab
    end)

    return ordered
end

local function pointInPolygon(x, z, vertices)
    local inside = false
    local verts = getOrderedVertices(vertices)
    local j = #verts

    for i = 1, #verts do
        local xi = verts[i].x
        local zi = getZoneYorZ(verts[i])
        local xj = verts[j].x
        local zj = getZoneYorZ(verts[j])

        if zi == nil or zj == nil then
            return false
        end

        local denom = (zj - zi)
        if math.abs(denom) < 0.0001 then
            denom = 0.0001
        end

        local intersects = ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / denom + xi)
        if intersects then
            inside = not inside
        end

        j = i
    end

    return inside
end

local function pointInZone(zone, x, z)
    if not zone then
        return false
    end

    if zone.vertices then
        return pointInPolygon(x, z, zone.vertices)
    end

    if zone.radius and zone.point then
        local dx = x - zone.point.x
        local centerZ = getZoneYorZ(zone.point)
        if centerZ == nil then
            return false
        end
        local dz = z - centerZ
        return (dx * dx + dz * dz) <= (zone.radius * zone.radius)
    end

    return false
end

local function getRandomPointInZone(zoneName)
    local zone = trigger.misc.getZone(zoneName)
    if not zone then
        return nil
    end

    -- Handle quad / polygon zones
    if zone.vertices then
        local verts = getOrderedVertices(zone.vertices)
        local minX = math.huge
        local maxX = -math.huge
        local minZ = math.huge
        local maxZ = -math.huge

        for _, v in ipairs(verts) do
            local vz = getZoneYorZ(v)
            if vz == nil then
                return nil
            end
            if v.x < minX then minX = v.x end
            if v.x > maxX then maxX = v.x end
            if vz < minZ then minZ = vz end
            if vz > maxZ then maxZ = vz end
        end

        -- Rejection sampling inside polygon so we do not spawn outside on concave/angled zones.
        for _ = 1, 200 do
            local x = math.random() * (maxX - minX) + minX
            local z = math.random() * (maxZ - minZ) + minZ
            if pointInPolygon(x, z, verts) then
                return {
                    x = x,
                    z = z
                }
            end
        end

        -- Fallback to a likely in-zone centroid for convex quads/polygons.
        if #verts > 0 then
            local cx = 0
            local cz = 0
            for _, v in ipairs(verts) do
                cx = cx + v.x
                cz = cz + (getZoneYorZ(v) or 0)
            end
            return {
                x = cx / #verts,
                z = cz / #verts
            }
        end

        return nil
    end

    -- Handle circular zones
    if zone.radius then
        local angle = math.random() * 2 * math.pi
        local r = math.sqrt(math.random()) * zone.radius
        local centerZ = getZoneYorZ(zone.point)
        if centerZ == nil then
            return nil
        end

        return {
            x = zone.point.x + math.cos(angle) * r,
            z = centerZ + math.sin(angle) * r
        }
    end

    return nil
end

local function getRandomSpawnZoneData()
    local validZones = {}

    for _, zoneName in ipairs(FRONTLINE_ZONES or {}) do
        local zone = trigger.misc.getZone(zoneName)
        local point = getRandomPointInZone(zoneName)
        if zone and point then
            validZones[#validZones + 1] = {
                name = zoneName,
                zone = zone,
                point = point,
            }
        else
            debug("Spawn zone unavailable: " .. tostring(zoneName))
        end
    end

    if #validZones == 0 then
        return nil
    end

    return validZones[math.random(1, #validZones)]
end

local function getPlayerType(unit)
    if not unit or not unit.getTypeName then
        return nil
    end
    return unit:getTypeName() or ""
end

local function getSpawnCountForPlayers(playerCount, packageCount)
    local fallbackCount = clamp(math.max(1, packageCount or 1), 1, MAX_AIRCRAFT_PER_GROUP)
    local validOptions = {}

    for _, option in ipairs(SPAWN_GROUP_OPTIONS or {}) do
        local count = tonumber(option)
        if count and count >= 1 then
            validOptions[#validOptions + 1] = clamp(math.floor(count), 1, MAX_AIRCRAFT_PER_GROUP)
        end
    end

    if #validOptions == 0 then
        return fallbackCount
    end

    return validOptions[math.random(1, #validOptions)]
end

local function getThreatTypeForPlayer(playerType)
    if OpFor and OpFor.getThreatTypeForPlayer then
        return OpFor.getThreatTypeForPlayer(playerType)
    end

    local pt = (playerType or ""):lower()
    if pt:find("a%-10") or pt:find("su%-25") or pt:find("su%-39") or pt:find("a%-50") then
        return "Su-27"
    end
    if pt:find("f%-16") or pt:find("f%-18") or pt:find("f%-15") or pt:find("f%-14") or pt:find("f%-22") or pt:find("fa%-18") then
        return "MiG-31"
    end
    if pt:find("mig%-29") or pt:find("su%-30") or pt:find("su%-33") or pt:find("su%-27") or pt:find("f%-4") then
        return "MiG-29A"
    end
    if pt:find("l%-39") or pt:find("tu%-") or pt:find("il%-") or pt:find("an%-") then
        return "Su-30"
    end
    return "MiG-29A"
end

local function getPlayerLoadoutProfile(unit)
    local profile = {
        bvrAam = 0,
        irAam = 0,
        strike = 0,
    }

    if not unit or not unit.getAmmo then
        return profile
    end

    local ammo = unit:getAmmo() or {}
    for _, item in ipairs(ammo) do
        local desc = item.desc
        local count = item.count or 0
        if desc and count > 0 then
            if desc.category == Weapon.Category.MISSILE then
                if desc.missileCategory == Weapon.MissileCategory.AAM then
                    local maxRange = desc.rangeMaxAltMax or desc.rangeMaxAltMin or desc.rangeMax or 0
                    if maxRange >= 25000 then
                        profile.bvrAam = profile.bvrAam + count
                    else
                        profile.irAam = profile.irAam + count
                    end
                else
                    profile.strike = profile.strike + count
                end
            elseif desc.category == Weapon.Category.BOMB
                or desc.category == Weapon.Category.ROCKET
                or desc.category == Weapon.Category.SHELL then
                profile.strike = profile.strike + count
            end
        end
    end

    return profile
end

local function mergeLoadoutProfiles(players)
    local profile = {
        bvrAam = 0,
        irAam = 0,
        strike = 0,
    }

    for _, unit in ipairs(players) do
        local p = getPlayerLoadoutProfile(unit)
        profile.bvrAam = profile.bvrAam + (p.bvrAam or 0)
        profile.irAam = profile.irAam + (p.irAam or 0)
        profile.strike = profile.strike + (p.strike or 0)
    end

    return profile
end

local function pickCounterScenarioFromProfile(profile, distanceToFront)
    if (profile.bvrAam or 0) > 0 then
        if distanceToFront > 70000 then
            return "BVR_LRE"
        elseif distanceToFront > 40000 then
            return "BVR_LR"
        else
            return "BVR_MR"
        end
    end

    if (profile.irAam or 0) > 0 then
        return "ACM_IR"
    end

    if (profile.strike or 0) > 0 then
        return "ACM"
    end

    return nil
end

local function pickCounterScenarioForPlayer(unit, distanceToFront)
    local profile = getPlayerLoadoutProfile(unit)
    return pickCounterScenarioFromProfile(profile, distanceToFront), profile
end

local function addUniqueThreat(threats, threatType)
    if not threatType then
        return
    end
    for _, t in ipairs(threats) do
        if t == threatType then
            return
        end
    end
    table.insert(threats, threatType)
end

local function getThreatRejectReason(threatType, loadoutProfile)
    local bvr = loadoutProfile.bvrAam or 0
    local ir = loadoutProfile.irAam or 0

    if bvr <= 0 and (threatType == "MiG-31" or threatType == "MiG-29S") then
        return "no BVR missiles for high-end BVR threat"
    end

    if bvr <= 0 and ir <= 0 and (threatType == "Su-30" or threatType == "Su-33") then
        return "no AAM capability for advanced fighter threat"
    end

    if bvr <= 0 and ir <= 0 and threatType == "MiG-29A" then
        return "no AAM capability for fighter threat"
    end

    return nil
end

local function isThreatTooHard(threatType, loadoutProfile)
    return getThreatRejectReason(threatType, loadoutProfile) ~= nil
end

local function hasStrikeFocusedPlayers(players)
    for _, unit in ipairs(players) do
        local pt = (getPlayerType(unit) or ""):lower()
        if pt:find("a%-10") or pt:find("su%-25") or pt:find("su%-39") or pt:find("su%-34") or pt:find("su%-24")
            or pt:find("av8") or pt:find("harrier") or pt:find("a%-6") then
            return true
        end
    end
    return false
end

local function isBvrFighterType(threatType)
    return threatType == "MiG-29A"
        or threatType == "MiG-29S"
        or threatType == "MiG-31"
        or threatType == "Su-27"
        or threatType == "Su-30"
        or threatType == "Su-33"
        or threatType == "J-11A"
end

local function scenarioForFighterAtDistance(distanceToFront)
    if distanceToFront > 70000 then
        return "BVR_LRE"
    elseif distanceToFront > 40000 then
        return "BVR_LR"
    end
    return "BVR_MR"
end

local function buildInterceptWaypointTask()
    return {
        id = "ComboTask",
        params = {
            tasks = {
                {
                    number = 1,
                    key = "CAP",
                    auto = true,
                    id = "EngageTargets",
                    enabled = true,
                    params = {
                        targetTypes = {
                            "Air",
                        },
                        priority = 0,
                    }
                },
                {
                    number = 2,
                    auto = true,
                    id = "WrappedAction",
                    enabled = true,
                    params = {
                        action = {
                            id = "Option",
                            params = {
                                value = true,
                                name = 17,
                            }
                        }
                    }
                },
                {
                    number = 3,
                    auto = true,
                    id = "WrappedAction",
                    enabled = true,
                    params = {
                        action = {
                            id = "Option",
                            params = {
                                value = 4,
                                name = 18,
                            }
                        }
                    }
                },
                {
                    number = 4,
                    auto = true,
                    id = "WrappedAction",
                    enabled = true,
                    params = {
                        action = {
                            id = "Option",
                            params = {
                                value = true,
                                name = 19,
                            }
                        }
                    }
                },
                {
                    number = 5,
                    auto = true,
                    id = "WrappedAction",
                    enabled = true,
                    params = {
                        action = {
                            id = "Option",
                            params = {
                                targetTypes = {},
                                name = 21,
                                value = "none;",
                                noTargetTypes = {
                                    "Fighters",
                                    "Multirole fighters",
                                    "Bombers",
                                    "Helicopters",
                                    "UAVs",
                                    "Infantry",
                                    "Fortifications",
                                    "Tanks",
                                    "IFV",
                                    "APC",
                                    "Artillery",
                                    "Unarmed vehicles",
                                    "AAA",
                                    "SR SAM",
                                    "MR SAM",
                                    "LR SAM",
                                    "Aircraft Carriers",
                                    "Cruisers",
                                    "Destroyers",
                                    "Frigates",
                                    "Corvettes",
                                    "Light armed ships",
                                    "Unarmed ships",
                                    "Submarines",
                                    "Cruise missiles",
                                    "Antiship Missiles",
                                    "AA Missiles",
                                    "AG Missiles",
                                    "SA Missiles",
                                },
                            }
                        }
                    }
                },
                {
                    number = 6,
                    auto = true,
                    id = "WrappedAction",
                    enabled = true,
                    params = {
                        action = {
                            id = "Option",
                            params = {
                                value = true,
                                name = 35,
                            }
                        }
                    }
                }
            }
        }
    }
end

local function buildEmptyComboTask()
    return {
        id = "ComboTask",
        params = {
            tasks = {}
        }
    }
end

local function buildThreatPool(players, preferredScenario, loadoutProfile)
    local pool = {}
    local strikeFocused = hasStrikeFocusedPlayers(players)

    -- Seed with player-type counters from all airborne players, not just lead.
    for _, unit in ipairs(players) do
        addUniqueThreat(pool, getThreatTypeForPlayer(getPlayerType(unit)))
    end

    -- Add variety buckets while keeping matchups reasonable for player loadout.
    if strikeFocused and (loadoutProfile.bvrAam or 0) <= 0 then
        addUniqueThreat(pool, "Su-25")
        addUniqueThreat(pool, "Su-25T")
        addUniqueThreat(pool, "L-39ZA")
        addUniqueThreat(pool, "MiG-19P")
        addUniqueThreat(pool, "MiG-21Bis")
    elseif preferredScenario and preferredScenario:find("^BVR") then
        addUniqueThreat(pool, "MiG-29A")
        addUniqueThreat(pool, "Su-27")
        addUniqueThreat(pool, "Su-30")
        if (loadoutProfile.bvrAam or 0) >= 4 then
            addUniqueThreat(pool, "MiG-31")
        end
    elseif preferredScenario == "ACM_IR" then
        addUniqueThreat(pool, "MiG-19P")
        addUniqueThreat(pool, "MiG-21Bis")
        addUniqueThreat(pool, "L-39ZA")
        addUniqueThreat(pool, "Su-25")
        if (loadoutProfile.irAam or 0) >= 4 then
            addUniqueThreat(pool, "MiG-29A")
        end
    else
        addUniqueThreat(pool, "L-39ZA")
        addUniqueThreat(pool, "MiG-19P")
        addUniqueThreat(pool, "MiG-21Bis")
        addUniqueThreat(pool, "Su-25")
        addUniqueThreat(pool, "Su-25T")
    end

    return pool
end

local function chooseThreatType(players, preferredScenario, loadoutProfile, distanceToFront)
    local pool = buildThreatPool(players, preferredScenario, loadoutProfile)
    local valid = {}

    for _, threatType in ipairs(pool) do
        local rejectReason = getThreatRejectReason(threatType, loadoutProfile)
        if rejectReason then
            debug("Threat candidate " .. threatType .. " rejected: " .. rejectReason)
        else
            local scenarioRequest = preferredScenario
            if FORCE_FIGHTER_BVR and isBvrFighterType(threatType) then
                scenarioRequest = scenarioForFighterAtDistance(distanceToFront)
            end

            local pkg = getThreatPackage(threatType, distanceToFront, scenarioRequest)
            if pkg then
                table.insert(valid, threatType)
                debug("Threat candidate " .. threatType .. " accepted with scenario " .. tostring(pkg.scenario or scenarioRequest or "auto"))
            else
                debug("Threat candidate " .. threatType .. " rejected: no matching loadout package")
            end
        end
    end

    if #valid == 0 then
        if (loadoutProfile.bvrAam or 0) <= 0 and (loadoutProfile.irAam or 0) <= 0 then
            valid = {"L-39ZA", "MiG-19P", "Su-25"}
        else
            valid = {"MiG-29A", "Su-27", "L-39ZA"}
        end
    end

    if #valid > 1 and lastThreatType then
        local nonRepeat = {}
        for _, t in ipairs(valid) do
            if t ~= lastThreatType then
                table.insert(nonRepeat, t)
            end
        end
        if #nonRepeat > 0 then
            valid = nonRepeat
        end
    end

    local selected = valid[math.random(1, #valid)]
    debug("Threat selected: " .. tostring(selected) .. " from " .. tostring(#valid) .. " valid candidates")
    lastThreatType = selected
    return selected
end

local function cleanupActiveGroups()
    local alive = {}
    for _, name in ipairs(activeGroups) do
        local g = Group.getByName(name)
        if g and g:isExist() then
            table.insert(alive, name)
        end
    end
    activeGroups = alive
end

local function maxGroupLimitForPlayers(playerCount)
    -- Allow up to 1 group per 3 players, capped by config.
    return math.max(1, math.min(MAX_ACTIVE_GROUPS, math.ceil(playerCount / 3)))
end

local function isGroupLimitReached(playerCount)
    cleanupActiveGroups()
    local limit = maxGroupLimitForPlayers(playerCount)
    return #activeGroups >= limit
end

local function spawnThreatForPlayers(players)
    local spawnZoneData = getRandomSpawnZoneData()
    if not spawnZoneData then
        debug("No valid spawn zones found in FRONTLINE_ZONES")
        return
    end

    local zonePoint = spawnZoneData.point
    local spawnZone = spawnZoneData.zone
    local spawnZoneName = spawnZoneData.name

    if spawnZone then
        debug("Spawn zone " .. tostring(spawnZoneName) .. " sample point x=" .. string.format("%.1f", zonePoint.x) .. " z=" .. string.format("%.1f", zonePoint.z)
            .. " (vertices=" .. tostring(spawnZone.vertices and #spawnZone.vertices or 0)
            .. ", radius=" .. tostring(spawnZone.radius) .. ")")
    end

    if #players == 0 then
        return
    end

    local primary = players[1]
    local playerType = getPlayerType(primary)
    local distanceToFront = math.sqrt((primary:getPoint().x - zonePoint.x)^2 + (primary:getPoint().z - zonePoint.z)^2)
    local loadoutProfile = mergeLoadoutProfiles(players)
    local preferredScenario = pickCounterScenarioFromProfile(loadoutProfile, distanceToFront)
    local threatType = chooseThreatType(players, preferredScenario, loadoutProfile, distanceToFront)
    local scenarioRequest = preferredScenario
    if FORCE_FIGHTER_BVR and isBvrFighterType(threatType) then
        scenarioRequest = scenarioForFighterAtDistance(distanceToFront)
    end
    debug("Player aircraft " .. tostring(playerType) .. " -> spawned threat " .. tostring(threatType))

    local spawnData = OpFor.getSpawnSettings(threatType)
    if not spawnData then
        spawnData = OpFor.getSpawnSettings("default")
    end
    local altMin = clamp(spawnData.alt[1], SPAWN_ALT_MIN_M, SPAWN_ALT_MAX_M)
    local altMax = clamp(spawnData.alt[2], SPAWN_ALT_MIN_M, SPAWN_ALT_MAX_M)
    if altMax < altMin then
        altMin, altMax = altMax, altMin
    end
    local spawnAlt = math.random(altMin, altMax)
    local spawnSpeed = math.random(spawnData.speed[1], spawnData.speed[2])

    -- Force spawn inside the frontline zone (or near it) so players see active threats.
    local spawnX = zonePoint.x
    local spawnZ = zonePoint.z
    local angle = math.random() * 2 * math.pi

    if not pointInZone(spawnZone, spawnX, spawnZ) then
        local fallbackPoint = getRandomPointInZone(spawnZoneName)
        if fallbackPoint then
            spawnX = fallbackPoint.x
            spawnZ = fallbackPoint.z
        end
    end

    -- Final safety net: ensure lead spawn point is always in the trigger zone.
    if not pointInZone(spawnZone, spawnX, spawnZ) then
        spawnX = zonePoint.x
        spawnZ = zonePoint.z
        debug("Lead spawn point corrected to sampled in-zone point")
    end

    local pkg = getThreatPackage(threatType, distanceToFront, scenarioRequest)
    if not pkg then
        debug("No package for " .. threatType .. " at distance " .. tostring(distanceToFront))
        return
    end

    debug("Player loadout profile: BVR=" .. loadoutProfile.bvrAam
        .. ", IR=" .. loadoutProfile.irAam
        .. ", STRIKE=" .. loadoutProfile.strike
        .. " -> scenarioRequested=" .. tostring(scenarioRequest or preferredScenario or "auto")
        .. ", scenarioUsed=" .. tostring(pkg.scenario or "auto"))

    local packageCount = pkg.count or 1
    local spawnCount = getSpawnCountForPlayers(#players, packageCount)

    if spawnCount <= 0 then
        debug("Zero aircraft for spawn package")
        return
    end

    local groupName = "OPFOR_THREAT_" .. groupCounter
    groupCounter = groupCounter + 1

    local playerPos = primary:getPoint()
    local heading = math.atan2(playerPos.z - zonePoint.z, playerPos.x - zonePoint.x) * 180 / math.pi

    local groupData = {
        name = groupName,
        task = "Intercept",
        route = {
            points = {
                {
                    x = spawnX,
                    y = spawnZ,
                    alt = spawnAlt,
                    speed = spawnSpeed,
                    action = "Turning Point",
                    alt_type = "BARO",
                    type = "Turning Point",
                    task = buildInterceptWaypointTask(),
                },
                {
                    x = playerPos.x,
                    y = playerPos.z,
                    alt = spawnAlt,
                    speed = spawnSpeed,
                    action = "Turning Point",
                    alt_type = "BARO",
                    type = "Turning Point",
                    task = buildEmptyComboTask(),
                }
            }
        },
        units = {}
    }

    for i = 1, spawnCount do
        local offset = (i - 1) * 100
        local unitX = spawnX + math.cos(angle + math.pi/2) * offset
        local unitZ= spawnZ + math.sin(angle + math.pi/2) * offset

        if not pointInZone(spawnZone, unitX, unitZ) then
            local fallbackPoint = getRandomPointInZone(spawnZoneName)
            if fallbackPoint then
                unitX = fallbackPoint.x
                unitZ = fallbackPoint.z
                debug("Adjusted unit " .. i .. " to remain in spawn zone " .. tostring(spawnZoneName))
            else
                unitX = spawnX
                unitZ = spawnZ
            end
        end

        if not pointInZone(spawnZone, unitX, unitZ) then
            unitX = spawnX
            unitZ = spawnZ
            debug("Final correction applied: unit " .. i .. " forced to lead in-zone position")
        end

        groupData.units[i] = {
            type = threatType,
            skill = CURRENT_SKILL,
            x = unitX,
            y = unitZ,
            alt = spawnAlt,
            speed = spawnSpeed,
            heading = heading,
            name = groupName .. "_U" .. i,
            livery_id = pkg.livery,
            onboard_num = tostring(200 + i),
            payload = {
                fuel = pkg.fuel or 100,
                flare = pkg.flares or 0,
                chaff = pkg.chaff or 0,
                gun = pkg.gun,
                pylons = pkg.pylons or {},
            }
        }
    end

    groupData.task = "Intercept"

    coalition.addGroup(OPFOR_COUNTRY, OPFOR_CATEGORY, groupData)
    table.insert(activeGroups, groupName)

    local summary = string.format("Spawned %s x%d in zone %s (%s)", threatType, spawnCount, spawnZoneName, playerType or "unknown")
    debug(summary)
    debug("Spawned " .. threatType .. " threat group " .. groupName .. " for " .. playerType .. " (players=" .. #players .. ", packageCount=" .. packageCount .. ", aircraft=" .. spawnCount .. ")")
end

local function groupIsLandedOrDead(groupName)
    local g = Group.getByName(groupName)
    if not g or not g:isExist() then
        return true
    end

    local aliveCount = 0
    for i = 1, g:getSize() do
        local u = g:getUnit(i)
        if u and Unit.isExist(u) then
            aliveCount = aliveCount + 1
            if u:inAir() then
                return false
            end
        end
    end

    return aliveCount == 0
end

local function cleanupLandedGroups()
    local keep = {}
    for _, name in ipairs(activeGroups) do
        if groupIsLandedOrDead(name) then
            local g = Group.getByName(name)
            if g and g:isExist() then
                g:destroy()
            end
            debug("Landed/despawned threat group " .. name)
        else
            table.insert(keep, name)
        end
    end
    activeGroups = keep
end

------------------------------------------------------------
-- PLAYER SCAN
------------------------------------------------------------
local function getAirbornePlayers()
    local result = {}
    local players = coalition.getPlayers(coalition.side.BLUE) or {}
    for _, unit in pairs(players) do
        if Unit.isExist(unit) and unit:inAir() then
            table.insert(result, unit)
        end
    end
    return result
end

------------------------------------------------------------
-- DESPAWN
------------------------------------------------------------
local function despawnAllThreats()
    for _, name in ipairs(activeGroups) do
        local g = Group.getByName(name)
        if g and g:isExist() then
            g:destroy()
            debug(name .. " despawned")
        end
    end
    activeGroups = {}
end

------------------------------------------------------------
-- F10 MENU Functions
------------------------------------------------------------
local function spawnNow()
    if not DEBUG_MODE then
        return
    end
    local players = getAirbornePlayers()
    if #players > 0 then
        spawnThreatForPlayers(players)
    end
end

local function randomSpawnInterval()
    return math.random(SPAWN_MIN_INTERVAL, SPAWN_MAX_INTERVAL)
end

------------------------------------------------------------
-- F10 MENU OPTIONS
------------------------------------------------------------
local dynamicAirSpawnerRoot = missionCommands.addSubMenuForCoalition(
    coalition.side.BLUE,
    "Dynamic Air Spawner"
)

if DEBUG_MODE then
    missionCommands.addCommand(
        "Spawn Threat Now",
        dynamicAirSpawnerRoot,
        spawnNow,
        nil
    )
end

------------------------------------------------------------
-- MANAGER
------------------------------------------------------------
local function manager()
    local players = getAirbornePlayers()
    cleanupActiveGroups()

    if #players == 0 then
        debug("No airborne players: keeping current threats on patrol")
    else
        local limit = maxGroupLimitForPlayers(#players)
        cleanupActiveGroups()
        debug("Players=" .. #players .. ", activeGroups=" .. #activeGroups .. ", maxGroups=" .. limit)
        if not isGroupLimitReached(#players) and timer.getTime() - lastSpawnTime >= SPAWN_COOLDOWN then
            spawnThreatForPlayers(players)
            lastSpawnTime = timer.getTime()
        end
    end

    cleanupLandedGroups()

    local nextInterval = randomSpawnInterval()
    debug("Next manager run in " .. nextInterval .. " seconds")
    return timer.getTime() + nextInterval
end

------------------------------------------------------------
-- START
------------------------------------------------------------
loadOpForAirLib()
debug("airspawn script initialized")
timer.scheduleFunction(manager, nil, timer.getTime() + 10)
