------------------------------------------------------------
-- OpFor Air Doctrine Library
-- DATA + DECISION LOGIC (DCS SAFE)
------------------------------------------------------------

OpFor = {}  -- GLOBAL ON PURPOSE

------------------------------------------------------------
-- INTERNAL TABLES
------------------------------------------------------------
OpFor.aircraft  = {}
OpFor.scenarios = {}
OpFor.loadouts  = {}

------------------------------------------------------------
-- AIRCRAFT DEFINITION
------------------------------------------------------------
function OpFor.addAircraft(def)
    OpFor.aircraft[def.ut] = {
        unitType = def.ut,
        fuel     = def.fu,
        flares   = def.fl,
        chaff    = def.ch,
        gun      = def.gn or 100,
        livery   = def.li,
        count    = def.ct or 2
    }
end

------------------------------------------------------------
-- SCENARIO DEFINITION
------------------------------------------------------------
function OpFor.addScenario(def)
    OpFor.scenarios[def.name] = {
        name  = def.name,
        range = def.range -- "BVR" or "ACM"
    }
end

------------------------------------------------------------
-- LOADOUT DEFINITION
------------------------------------------------------------
function OpFor.addLoadout(unitType, scenario, pylons)
    OpFor.loadouts[unitType] = OpFor.loadouts[unitType] or {}
    OpFor.loadouts[unitType][scenario] = pylons
end

------------------------------------------------------------
-- SCENARIO SELECTION LOGIC
------------------------------------------------------------
function OpFor.pickScenario(distance)
    if distance > 30000 then
        return "BVR_LR"
    else
        return "ACM"
    end
end

------------------------------------------------------------
-- FINAL SPAWN PACKAGE (MAIN API)
------------------------------------------------------------
function OpFor.getSpawnPackage(unitType, distance)
    local ac = OpFor.aircraft[unitType]
    if not ac then
        return nil
    end

    local scenario = OpFor.pickScenario(distance)

    local pylons =
        (OpFor.loadouts[unitType] and OpFor.loadouts[unitType][scenario])
        or
        (OpFor.loadouts[unitType] and OpFor.loadouts[unitType]["BVR_LR"])

    if not pylons then
        return nil
    end

    return {
        scenario = scenario,
        count    = ac.count,
        fuel     = ac.fuel,
        flares   = ac.flares,
        chaff    = ac.chaff,
        gun      = ac.gun,
        livery   = ac.livery,
        pylons   = pylons
    }
end

------------------------------------------------------------
-- DATA : MiG-29A
------------------------------------------------------------

OpFor.addAircraft({
    ut = "MiG-29A",
    fu = 3376,
    fl = 30,
    ch = 30,
    li = "Air Force Standard",
    ct = 2
})

OpFor.addScenario({ name = "BVR_LR", range = "BVR" })
OpFor.addScenario({ name = "ACM",    range = "ACM" })

OpFor.addLoadout("MiG-29A", "BVR_LR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [4] = { CLSID = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}" },
    [5] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [6] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [7] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})

trigger.action.outText("[OpFor] Air doctrine library loaded", 5)
