------------------------------------------------------------
-- Dynamic Airspawner for DCS
-- Spawns OPFOR aircraft in the frontline zone based on player presence and type.
------------------------------------------------------------

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local DEBUG_MODE = true

local CHECK_INTERVAL = 30
local SPAWN_COOLDOWN = 90
local FRONTLINE_ZONE = "Frontline"
local SPAWN_MIN_INTERVAL = 180
local SPAWN_MAX_INTERVAL = 1800

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

local function getThreatPackage(threatType, distance)
    if not OpFor or not OpFor.getSpawnPackage then
        debug("OpFor library not loaded")
        return nil
    end
    return OpFor.getSpawnPackage(threatType, distance)
end

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local activeGroups = {}
local groupCounter = 1
local lastSpawnTime = 0

------------------------------------------------------------
-- UTILS
------------------------------------------------------------
local function getRandomPointInZone(zoneName)
    local z = trigger.misc.getZone(zoneName)
    if not z or not z.point then
        return nil
    end

    local radius = z.radius or 10000
    local angle = math.random() * 2 * math.pi
    local r = math.sqrt(math.random()) * radius
    local x = z.point.x + math.cos(angle) * r
    local y = z.point.y + math.sin(angle) * r
    return { x = x, y = y }
end

local function getPlayerType(unit)
    if not unit or not unit.getTypeName then
        return nil
    end
    return unit:getTypeName() or ""
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

local function chooseThreatType(players)
    local count = {}
    for _, unit in ipairs(players) do
        local t = getPlayerType(unit)
        local threat = getThreatTypeForPlayer(t)
        count[threat] = (count[threat] or 0) + 1
    end

    local best = nil
    local bestCount = 0
    for threat, c in pairs(count) do
        if c > bestCount then
            best = threat
            bestCount = c
        end
    end
    return best or "MiG-29A"
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
    -- Allow up to 1 group per 3 players, clamped 1..4
    return math.max(1, math.min(4, math.ceil(playerCount / 3)))
end

local function isGroupLimitReached(playerCount)
    cleanupActiveGroups()
    local limit = maxGroupLimitForPlayers(playerCount)
    return #activeGroups >= limit
end

local function spawnThreatForPlayers(players)
    local zonePoint = getRandomPointInZone(FRONTLINE_ZONE)
    if not zonePoint then
        debug("Frontline zone not found: FRONTLINE_ZONE")
        return
    end

    if #players == 0 then
        return
    end

    local threatType = chooseThreatType(players)
    local primary = players[1]
    local playerType = getPlayerType(primary)
    debug("Player aircraft " .. tostring(playerType) .. " -> spawned threat " .. tostring(threatType))
    local distanceToFront = math.sqrt((primary:getPoint().x - zonePoint.x)^2 + (primary:getPoint().z - zonePoint.y)^2)

    local spawnData = OpFor.getSpawnSettings(threatType)
    if not spawnData then
        spawnData = OpFor.getSpawnSettings("default")
    end
    local spawnAlt = math.random(spawnData.alt[1], spawnData.alt[2])
    local spawnSpeed = math.random(spawnData.speed[1], spawnData.speed[2])

    -- Force spawn inside the frontline zone (or near it) so players see active threats.
    local spawnX = zonePoint.x
    local spawnY = zonePoint.y
    local angle = math.random() * 2 * math.pi

    local pkg = getThreatPackage(threatType, distanceToFront)
    if not pkg then
        debug("No package for " .. threatType .. " at distance " .. tostring(distanceToFront))
        return
    end

    local desiredCount = math.min(#players, 3)
    if #players <= 2 then
        desiredCount = math.min(2, #players)
    end
    local packageCount = pkg.count or 1
    local spawnCount = math.min(desiredCount, packageCount)

    if spawnCount <= 0 then
        debug("Zero aircraft for spawn package")
        return
    end

    local groupName = "OPFOR_THREAT_" .. groupCounter
    groupCounter = groupCounter + 1

    local playerPos = primary:getPoint()
    local heading = math.atan2(playerPos.z - zonePoint.y, playerPos.x - zonePoint.x) * 180 / math.pi

    local groupData = {
        name = groupName,
        task = "CAP",
        route = {
            points = {
                {
                    x = spawnX,
                    y = spawnY,
                    alt = spawnAlt,
                    speed = spawnSpeed,
                    action = "Turning Point",
                    alt_type = "BARO",
                },
                {
                    x = playerPos.x,
                    y = playerPos.z,
                    alt = spawnAlt,
                    speed = spawnSpeed,
                    action = "Turning Point",
                    alt_type = "BARO",
                }
            }
        },
        units = {}
    }

    for i = 1, spawnCount do
        local offset = (i - 1) * 100
        local unitX = spawnX + math.cos(angle + math.pi/2) * offset
        local unitY = spawnY + math.sin(angle + math.pi/2) * offset
        groupData.units[i] = {
            type = threatType,
            skill = CURRENT_SKILL,
            x = unitX,
            y = unitY,
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

    coalition.addGroup(OPFOR_COUNTRY, OPFOR_CATEGORY, groupData)
    table.insert(activeGroups, groupName)

    local spawnedGroup = Group.getByName(groupName)
    if spawnedGroup and spawnedGroup:isExist() then
        local ctrl = spawnedGroup:getController()
        if ctrl then
            local route = spawnedGroup:getRoute()
            if route then
                ctrl:setTask({ id = 'PATROL', params = { route = route } })
            end
        end
    end

    local summary = string.format("Spawned %s x%d in Frontline zone (%s)", threatType, spawnCount, playerType or "unknown")
    trigger.action.outText("[Dynamic Air Spawner] " .. summary, 8)
    debug("Spawned " .. threatType .. " threat group " .. groupName .. " for " .. playerType .. " (players=" .. #players .. ", aircraft=" .. spawnCount .. ")")
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
