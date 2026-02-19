------------------------------------------------------------
-- Dynamic Interceptor v2 (LEAN)
------------------------------------------------------------

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local CHECK_INTERVAL = 60
local SPAWN_DISTANCE = 80000
local SPAWN_ALT = 8000
local SPAWN_SPEED = 250

local OPFOR_COUNTRY  = country.id.RUSSIA
local OPFOR_CATEGORY = Group.Category.AIRPLANE
local OPFOR_TYPE     = "MiG-29A"

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local activeGroupName = nil
local groupCounter = 1

------------------------------------------------------------
-- DEBUG
------------------------------------------------------------
local function debug(msg)
    trigger.action.outText("[DynamicIntercept] " .. msg, 10)
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
-- AI STATE
------------------------------------------------------------
local function isAIAlive()
    if not activeGroupName then return false end
    local g = Group.getByName(activeGroupName)
    return g and g:isExist()
end

------------------------------------------------------------
-- SPAWN
------------------------------------------------------------
local function spawnInterceptor(players)
    if isAIAlive() or #players == 0 then return end

    local tgt = players[1]
    local p = tgt:getPoint()

    local angle = math.random() * 2 * math.pi
    local spawnX = p.x + math.cos(angle) * SPAWN_DISTANCE
    local spawnY = p.z + math.sin(angle) * SPAWN_DISTANCE

    local dx = p.x - spawnX
    local dz = p.z - spawnY
    local dist = math.sqrt(dx * dx + dz * dz)

    local pkg = OpFor.getSpawnPackage(OPFOR_TYPE, dist)
    if not pkg then
        debug("No spawn package found")
        return
    end

    local groupName = "OPFOR_INTERCEPT_" .. groupCounter
    groupCounter = groupCounter + 1

    local groupData = {
        name = groupName,
        task = "CAP",
        route = {
            points = {
                {
                    x = spawnX,
                    y = spawnY,
                    alt = SPAWN_ALT,
                    speed = SPAWN_SPEED,
                    action = "Turning Point",
                    alt_type = "BARO",
                }
            }
        },
        units = {}
    }

    for i = 1, pkg.count do
        groupData.units[i] = {
            type = OPFOR_TYPE,
            skill = "High",
            x = spawnX + (i * 30),
            y = spawnY + (i * 30),
            alt = SPAWN_ALT,
            speed = SPAWN_SPEED,
            heading = angle,
            name = groupName .. "_U" .. i,
            livery_id = pkg.livery,
            onboard_num = tostring(200 + i),
            payload = {
                fuel  = pkg.fuel,
                flare = pkg.flares,
                chaff = pkg.chaff,
                gun   = pkg.gun,
                pylons = pkg.pylons
            }
        }
    end

    coalition.addGroup(OPFOR_COUNTRY, OPFOR_CATEGORY, groupData)
    activeGroupName = groupName
    debug("Spawned interceptor: " .. groupName)
end

------------------------------------------------------------
-- DESPAWN
------------------------------------------------------------
local function despawnInterceptor()
    if not isAIAlive() then return end
    Group.getByName(activeGroupName):destroy()
    activeGroupName = nil
end

------------------------------------------------------------
-- MANAGER
------------------------------------------------------------
local function manager()
    local players = getAirbornePlayers()
    if #players > 0 then
        spawnInterceptor(players)
    else
        despawnInterceptor()
    end
    return timer.getTime() + CHECK_INTERVAL
end

------------------------------------------------------------
-- START
------------------------------------------------------------
debug("Dynamic Interceptor initialized")
timer.scheduleFunction(manager, nil, timer.getTime() + 10)
