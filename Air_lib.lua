------------------------------------------------------------
-- OpFor Aircraft Library
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
    if distance > 70000 then
        return "BVR_LRE"
    elseif distance > 40000 then
        return "BVR_LR"
    elseif distance > 20000 then
        return "BVR_MR"
    elseif distance > 12000 then
        return "ACM_IR"
    else
        return "ACM"
    end
end

------------------------------------------------------------
-- FINAL SPAWN PACKAGE (MAIN API)
------------------------------------------------------------
local function findAvailableLoadout(unitType, preferredScenario)
    if not OpFor.loadouts[unitType] then
        return nil, nil
    end

    local try = {
        preferredScenario,
        "ACM_IR",
        "ACM",
        "BVR_LR",
        "BVR_MR",
        "BVR_LRE",
        "BVR",
    }

    for _, s in ipairs(try) do
        if s and OpFor.loadouts[unitType][s] then
            return s, OpFor.loadouts[unitType][s]
        end
    end
    return nil, nil
end

function OpFor.getSpawnPackage(unitType, distance)
    local ac = OpFor.aircraft[unitType]
    if not ac then
        return nil
    end

    local scenario = OpFor.pickScenario(distance)
    local pickScenario, pylons = findAvailableLoadout(unitType, scenario)
    if not pylons then
        return nil
    end

    return {
        scenario = pickScenario,
        count    = ac.count,
        fuel     = ac.fuel,
        flares   = ac.flares,
        chaff    = ac.chaff,
        gun      = ac.gun,
        livery   = ac.livery,
        pylons   = pylons
    }
end

OpFor.threatTypeForPlayer = {
    attack = {"Su-27", "Su-30"},
    fighter = {"MiG-31", "MiG-29A"},
    multiRole = {"MiG-29A", "Su-30"},
    groundAttack = {"Su-27", "Ka-50"},
    helicopter = {"Ka-50", "Mi-28N"},
    trainer = {"Su-30", "L-39ZA"},
    legacy = {"MiG-29A", "MiG-31"},
}

local function pickDynamicThreat(list, playerType)
    if #list == 0 then
        return nil
    end
    -- Prefer based on player type unique key
    local key = string.sub(playerType, 1, 2)
    local idx = (string.byte(key, 1) or 0) % #list + 1
    return list[idx]
end

function OpFor.getThreatTypeForPlayer(playerType)
    local pt = (playerType or ""):lower()

    if pt:find("a%-10") or pt:find("su%-25") or pt:find("su%-39") or pt:find("su%-34") or pt:find("su%-24") then
        return pickDynamicThreat(OpFor.threatTypeForPlayer.groundAttack, pt)
    end

    if pt:find("f%-16") or pt:find("f%-18") or pt:find("f%-15") or pt:find("f%-14") or pt:find("f%-22") or pt:find("fa%-18") or pt:find("f%-4") or pt:find("f%-86") then
        return pickDynamicThreat(OpFor.threatTypeForPlayer.fighter, pt)
    end

    if pt:find("f%-") or pt:find("mig%-") or pt:find("su%-") or pt:find("tu%-") then
        return pickDynamicThreat(OpFor.threatTypeForPlayer.multiRole, pt)
    end

    if pt:find("ah%-64") or pt:find("oh%-58") or pt:find("uh%-1") then
        return pickDynamicThreat(OpFor.threatTypeForPlayer.helicopter, pt)
    end

    if pt:find("l%-39") or pt:find("mirage%-f1") then
        return pickDynamicThreat(OpFor.threatTypeForPlayer.trainer, pt)
    end

    -- fallback to a reasonable legacy threat if unknown
    return pickDynamicThreat(OpFor.threatTypeForPlayer.legacy, pt)
end

-- Spawn parameter settings by aircraft type
OpFor.spawnSettings = {
    ["H-6J"]   = {dist={80000,140000}, alt={3000,10000}, speed={180,250}},
    ["Ka-50"]  = {dist={20000,50000}, alt={2000,6000}, speed={150,230}},
    ["L-39ZA"] = {dist={20000,70000}, alt={2000,9000}, speed={180,260}},
    ["Mi-24P"] = {dist={20000,60000}, alt={2000,9000}, speed={150,240}},
    ["Mi-26"]  = {dist={20000,60000}, alt={2000,9000}, speed={120,210}},
    ["Mi-28N"] = {dist={25000,70000}, alt={2000,9000}, speed={170,250}},
    ["Mi-8MT"] = {dist={20000,60000}, alt={2000,9000}, speed={130,210}},
    ["MiG-19P"] = {dist={20000,60000}, alt={3000,12000}, speed={220,280}},
    ["MiG-21Bis"] = {dist={30000,70000}, alt={4000,13000}, speed={220,300}},
    ["MiG-23MLD"] = {dist={30000,80000}, alt={4000,13000}, speed={220,300}},
    ["Mirage-F1CE"] = {dist={30000,85000}, alt={3000,13000}, speed={220,300}},
    ["MiG-29A"] = {dist={40000,100000}, alt={5000,14000}, speed={230,320}},
    ["MiG-29S"] = {dist={40000,100000}, alt={5000,14000}, speed={230,320}},
    ["MiG-31"] = {dist={60000,140000}, alt={8000,17000}, speed={240,340}},
    ["Su-17M4"] = {dist={30000,90000}, alt={4000,12000}, speed={220,290}},
    ["Su-24M"] = {dist={30000,90000}, alt={3000,12000}, speed={220,280}},
    ["Su-25"] = {dist={20000,60000}, alt={2000,9000}, speed={160,240}},
    ["Su-25T"] = {dist={20000,60000}, alt={2000,9000}, speed={160,240}},
    ["Su-27"] = {dist={40000,110000}, alt={6000,14000}, speed={220,310}},
    ["Su-30"] = {dist={40000,110000}, alt={5000,14000}, speed={210,300}},
    ["Su-33"] = {dist={40000,110000}, alt={6000,14000}, speed={220,320}},
    ["Su-34"] = {dist={40000,110000}, alt={3000,12000}, speed={210,280}},
    ["Tu-142"] = {dist={80000,140000}, alt={3000,12000}, speed={220,280}},
    ["Tu-22M3"] = {dist={90000,150000}, alt={3000,12000}, speed={230,290}},
    ["default"] = {dist={40000,100000}, alt={5000,13000}, speed={220,290}},
}

function OpFor.getSpawnSettings(unitType)
    return OpFor.spawnSettings[unitType] or OpFor.spawnSettings.default
end

-- AUTO-GENERATED loadouts from loadout.lua
OpFor.addScenario({ name = "ACM", range = "ACM" })
OpFor.addScenario({ name = "ACM_IR", range = "ACM" })
OpFor.addScenario({ name = "ACM_IR_AA", range = "ACM" })
OpFor.addScenario({ name = "ACM_IR_RA", range = "ACM" })
OpFor.addScenario({ name = "BVR", range = "BVR" })
OpFor.addScenario({ name = "BVR_LR", range = "BVR" })
OpFor.addScenario({ name = "BVR_LRE", range = "BVR" })
OpFor.addScenario({ name = "BVR_MR", range = "BVR" })
OpFor.addAircraft({ ut = "H-6J", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Ka-50", fu = 2500, fl = 30, ch = 30, li = "Air Force Standard", ct = 3 })
OpFor.addAircraft({ ut = "L-39ZA", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Mi-24P", fu = 2500, fl = 30, ch = 30, li = "Air Force Standard", ct = 3 })
OpFor.addAircraft({ ut = "Mi-26", fu = 2500, fl = 30, ch = 30, li = "Air Force Standard", ct = 3 })
OpFor.addAircraft({ ut = "Mi-28N", fu = 2500, fl = 30, ch = 30, li = "Air Force Standard", ct = 3 })
OpFor.addAircraft({ ut = "Mi-8MT", fu = 2500, fl = 30, ch = 30, li = "Air Force Standard", ct = 3 })
OpFor.addAircraft({ ut = "MiG-29A", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "MiG-29S", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "MiG-31", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Su-17M4", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Su-24M", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Su-25", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Su-25T", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Su-27", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Su-30", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Su-33", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Su-34", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Tu-142", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Tu-22M3", fu = 3000, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "MiG-19P", fu = 2500, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "MiG-21Bis", fu = 2500, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "MiG-23MLD", fu = 2500, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addAircraft({ ut = "Mirage-F1CE", fu = 2500, fl = 30, ch = 30, li = "Air Force Standard", ct = 2 })
OpFor.addLoadout("H-6J", "ACM", {
    [1] = { CLSID = "DIS_H6_250_2_N24" },
})
OpFor.addLoadout("Ka-50", "ACM", {
    [1] = { CLSID = "{A6FD14D3-6D30-4C85-88A7-8D17BEE120E2}" },
    [2] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [3] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [4] = { CLSID = "{A6FD14D3-6D30-4C85-88A7-8D17BEE120E2}" },
})
OpFor.addLoadout("L-39ZA", "ACM", {
})
OpFor.addLoadout("L-39ZA", "ACM_IR_AA", {
    [1] = { CLSID = "{APU-60-1_R_60M}" },
    [2] = { CLSID = "{APU-60-1_R_60M}" },
})
OpFor.addLoadout("L-39ZA", "ACM_IR_RA", {
    [1] = { CLSID = "{R-3S}" },
    [2] = { CLSID = "{R-3S}" },
})
OpFor.addLoadout("L-39ZA", "BVR", {
    [1] = { CLSID = "{APU-60-1_R_60M}" },
    [2] = { CLSID = "{PK-3}" },
    [3] = { CLSID = "{PK-3}" },
    [4] = { CLSID = "{APU-60-1_R_60M}" },
})
OpFor.addLoadout("Mi-24P", "ACM", {
    [1] = { CLSID = "{2x9M120_Ataka_V}" },
    [2] = { CLSID = "{2x9M120_Ataka_V}" },
    [3] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [4] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [5] = { CLSID = "{2x9M120_Ataka_V}" },
    [6] = { CLSID = "{2x9M120_Ataka_V}" },
})
OpFor.addLoadout("Mi-24P", "ACM_IR", {
    [1] = { CLSID = "{2x9M120_Ataka_V}" },
    [2] = { CLSID = "{B0DBC591-0F52-4F7D-AD7B-51E67725FB81}" },
    [3] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [4] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [5] = { CLSID = "{275A2855-4A79-4B2D-B082-91EA2ADF4691}" },
    [6] = { CLSID = "{2x9M120_Ataka_V}" },
})
OpFor.addLoadout("Mi-26", "ACM", {
})
OpFor.addLoadout("Mi-28N", "ACM", {
    [1] = { CLSID = "{57232979-8B0F-4db7-8D9A-55197E06B0F5}" },
    [2] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [3] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [4] = { CLSID = "{57232979-8B0F-4db7-8D9A-55197E06B0F5}" },
})
OpFor.addLoadout("Mi-8MT", "ACM", {
    [1] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [2] = { CLSID = "GUV_YakB_GSHP" },
    [3] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [4] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [5] = { CLSID = "GUV_YakB_GSHP" },
    [6] = { CLSID = "{6A4B9E69-64FE-439a-9163-3A87FB6A4D81}" },
    [7] = { CLSID = "KORD_12_7" },
    [8] = { CLSID = "PKT_7_62" },
})
OpFor.addLoadout("MiG-29A", "ACM", {
})
OpFor.addLoadout("MiG-29A", "ACM_IR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [4] = { CLSID = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}" },
    [5] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [6] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [7] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("MiG-29A", "BVR_LR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [4] = { CLSID = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}" },
    [5] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [6] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [7] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("MiG-29A", "BVR_MR", {
    [1] = { CLSID = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [4] = { CLSID = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}" },
    [5] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [6] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [7] = { CLSID = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
})
OpFor.addLoadout("MiG-29S", "BVR_LR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [3] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [4] = { CLSID = "{2BEC576B-CDF5-4B7F-961F-B0FA4312B841}" },
    [5] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [6] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [7] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("MiG-31", "ACM", {
})
OpFor.addLoadout("MiG-31", "ACM_IR", {
    [1] = { CLSID = "{B0DBC591-0F52-4F7D-AD7B-51E67725FB81}" },
    [2] = { CLSID = "{275A2855-4A79-4B2D-B082-91EA2ADF4691}" },
})
OpFor.addLoadout("MiG-31", "BVR", {
    [1] = { CLSID = "{5F26DBC2-FB43-4153-92DE-6BBCE26CB0FF}" },
    [2] = { CLSID = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}" },
    [3] = { CLSID = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}" },
    [4] = { CLSID = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}" },
    [5] = { CLSID = "{F1243568-8EF0-49D4-9CB5-4DA90D92BC1D}" },
    [6] = { CLSID = "{5F26DBC2-FB43-4153-92DE-6BBCE26CB0FF}" },
})
OpFor.addLoadout("Su-17M4", "ACM", {
})
OpFor.addLoadout("Su-17M4", "ACM_IR", {
    [1] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
    [2] = { CLSID = "{APU-60-1_R_60M}" },
    [3] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
    [4] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
    [5] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
    [6] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
    [7] = { CLSID = "{APU-60-1_R_60M}" },
    [8] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
})
OpFor.addLoadout("Su-24M", "ACM", {
    [1] = { CLSID = "{6DADF342-D4BA-4D8A-B081-BA928C4AF86D}" },
    [2] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
    [3] = { CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
    [4] = { CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
    [5] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
    [6] = { CLSID = "{6DADF342-D4BA-4D8A-B081-BA928C4AF86D}" },
})
OpFor.addLoadout("Su-24M", "ACM_IR", {
    [1] = { CLSID = "{APU-60-1_R_60M}" },
    [2] = { CLSID = "{6DADF342-D4BA-4D8A-B081-BA928C4AF86D}" },
    [3] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
    [4] = { CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
    [5] = { CLSID = "{3C612111-C7AD-476E-8A8E-2485812F4E5C}" },
    [6] = { CLSID = "{37DCC01E-9E02-432F-B61D-10C166CA2798}" },
    [7] = { CLSID = "{6DADF342-D4BA-4D8A-B081-BA928C4AF86D}" },
    [8] = { CLSID = "{APU-60-1_R_60M}" },
})
OpFor.addLoadout("Su-25", "ACM", {
})
OpFor.addLoadout("Su-25", "ACM_IR", {
    [1] = { CLSID = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
    [2] = { CLSID = "{F72F47E5-C83A-4B85-96ED-D3E46671EE9A}" },
    [3] = { CLSID = "{F72F47E5-C83A-4B85-96ED-D3E46671EE9A}" },
    [4] = { CLSID = "{4203753F-8198-4E85-9924-6F8FF679F9FF}" },
    [5] = { CLSID = "{E8D4652F-FD48-45B7-BA5B-2AE05BB5A9CF}" },
    [6] = { CLSID = "{E8D4652F-FD48-45B7-BA5B-2AE05BB5A9CF}" },
    [7] = { CLSID = "{4203753F-8198-4E85-9924-6F8FF679F9FF}" },
    [8] = { CLSID = "{F72F47E5-C83A-4B85-96ED-D3E46671EE9A}" },
    [9] = { CLSID = "{F72F47E5-C83A-4B85-96ED-D3E46671EE9A}" },
    [10] = { CLSID = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
})
OpFor.addLoadout("Su-25T", "ACM", {
})
OpFor.addLoadout("Su-25T", "ACM_IR", {
    [1] = { CLSID = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
    [2] = { CLSID = "{CBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
    [4] = { CLSID = "{F789E86A-EE2E-4E6B-B81E-D5E5F903B6ED}" },
    [5] = { CLSID = "{601C99F7-9AF3-4ed7-A565-F8B8EC0D7AAC}" },
    [6] = { CLSID = "{601C99F7-9AF3-4ed7-A565-F8B8EC0D7AAC}" },
    [7] = { CLSID = "{F789E86A-EE2E-4E6B-B81E-D5E5F903B6ED}" },
    [8] = { CLSID = "{79D73885-0801-45a9-917F-C90FE1CE3DFC}" },
    [9] = { CLSID = "{CBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [10] = { CLSID = "{682A481F-0CB5-4693-A382-D00DD4A156D7}" },
})
OpFor.addLoadout("Su-27", "ACM", {
})
OpFor.addLoadout("Su-27", "ACM_IR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [4] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [5] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [6] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("Su-27", "BVR_LR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}" },
    [4] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [5] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [6] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [7] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [8] = { CLSID = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}" },
    [9] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [10] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("Su-27", "BVR_MR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{88DAC840-9F75-4531-8689-B46E64E42E53}" },
    [4] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [5] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [6] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [7] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [8] = { CLSID = "{88DAC840-9F75-4531-8689-B46E64E42E53}" },
    [9] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [10] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("Su-30", "ACM", {
})
OpFor.addLoadout("Su-30", "ACM_IR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [4] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [5] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [6] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("Su-30", "BVR_LR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [4] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [5] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [6] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [7] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [8] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [9] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [10] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("Su-30", "BVR_LRE", {
    [1] = { CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82F}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [4] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [5] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [6] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [7] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [8] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [9] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [10] = { CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82A}" },
})
OpFor.addLoadout("Su-33", "ACM", {
})
OpFor.addLoadout("Su-33", "ACM_IR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [4] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [5] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [6] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("Su-33", "BVR_LR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}" },
    [4] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [5] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [6] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [7] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [8] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [9] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [10] = { CLSID = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}" },
    [11] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [12] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("Su-33", "BVR_LRE", {
    [1] = { CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82F}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}" },
    [4] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [5] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [6] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [7] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [8] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [9] = { CLSID = "{E8069896-8435-4B90-95C0-01A03AE6E400}" },
    [10] = { CLSID = "{B79C379A-9E87-4E50-A1EE-7F7E29C2E87A}" },
    [11] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [12] = { CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82A}" },
})
OpFor.addLoadout("Su-33", "BVR_MR", {
    [1] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{88DAC840-9F75-4531-8689-B46E64E42E53}" },
    [4] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [5] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [6] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [7] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [8] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [9] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [10] = { CLSID = "{88DAC840-9F75-4531-8689-B46E64E42E53}" },
    [11] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [12] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
})
OpFor.addLoadout("Su-34", "ACM", {
})
OpFor.addLoadout("Su-34", "ACM_IR", {
    [1] = { CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82F}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [4] = { CLSID = "{X-29T}" },
    [5] = { CLSID = "{X-29T}" },
    [6] = { CLSID = "{X-29T}" },
    [7] = { CLSID = "{X-29T}" },
    [8] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [9] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [10] = { CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82A}" },
})
OpFor.addLoadout("Su-34", "BVR", {
    [1] = { CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82F}" },
    [2] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [3] = { CLSID = "{X-29T}" },
    [4] = { CLSID = "{X-29T}" },
    [5] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [6] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [7] = { CLSID = "{9B25D316-0434-4954-868F-D51DB1A38DF0}" },
    [8] = { CLSID = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}" },
    [9] = { CLSID = "{X-29T}" },
    [10] = { CLSID = "{X-29T}" },
    [11] = { CLSID = "{FBC29BFE-3D24-4C64-B81D-941239D12249}" },
    [12] = { CLSID = "{44EE8698-89F9-48EE-AF36-5FD31896A82A}" },
})
OpFor.addLoadout("Tu-142", "ACM", {
    [1] = { CLSID = "{C42EE4C3-355C-4B83-8B22-B39430B8F4AE}" },
})
OpFor.addLoadout("Tu-22M3", "ACM", {
    [1] = { CLSID = "{BDAD04AA-4D4A-4E51-B958-180A89F963CF}" },
})

trigger.action.outText("[OpFor] Air doctrine library loaded", 5)
