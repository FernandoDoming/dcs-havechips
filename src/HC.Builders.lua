--[[ 
HC.Builders.lua 

Contains verious methods to generate the scenario, initializes templates, populates airbases, warehouses etc.

]]


--Gets all template group names for side of missionType, see HC.TEMPLATE_CATEGORIES
--HC.TEMPLATE_CATEGORIES {"SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "SAM", "ATTACK_HELI", "TRANSPORT_HELI"}
--@param #string side "RED" or "BLUE"
--@param #string missionType Template zone name part. Pattern is <SIDE>_<missionType>_TEMPLATES, see template zones in mission editor, possible values "SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "SAM", "ATTACK_HELI", "TRANSPORT_HELI"
function HC:GetTemplateGroupNames(side, missionType)    
    local templates = {}
    --convention: use UPPERCASE for template zones
    local zoneName = string.upper(side.."_"..missionType.."_TEMPLATES")
    local templateZone = ZONE:FindByName(zoneName)
    if (templateZone == nil) then
        HC:W("Couldn't find template zone "..zoneName.." no templates for "..side.." "..missionType.." will be available!")
        return {}
    end

    local allGroups = SET_GROUP:New():FilterCoalitions(string.lower(side), false):FilterActive(false):FilterOnce()
    allGroups:ForEachGroup(
        function(g)
            --HC:T(string.format("%s template checking %s ", g:GetName(), templateZone:GetName()))
            --Get first unit in group, if in specified zone then add to templates, not perfect but it works
            if (templateZone:IsVec3InZone(g:GetUnits()[1]:GetVec3())) then
                HC:T(g.GroupName.." added to " ..side.." templates ".. missionType)
                table.insert(templates, g:GetName())
            end    
        end
    )
    return templates
end  

--Initializes the templates structure for Airwings and platoons
function HC:InitGroupTemplates()
    HC:T("Initializing group templates")
    local sides = {"RED", "BLUE"}
    for j=1, #(sides) do        
        for i=1,#(HC.TEMPLATE_CATEGORIES) do
            HC[sides[j]].TEMPLATES[HC.TEMPLATE_CATEGORIES[i]] = HC:GetTemplateGroupNames(sides[j], HC.TEMPLATE_CATEGORIES[i])
        end  
    end
    HC:T("Group templates initialized")
end

--Gets a number of randomly chosen template group names for specified template category (mission type), see HC.TEMPLATE_CATEGORIES
---@param  side string "RED" or "BLUE"
---@param missionType string Template zone name part. Pattern is [SIDE]_[missionType]_TEMPLATES, see template zones in mission editor.
---
--- Possible values "SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "SAM", "ATTACK_HELI", "TRANSPORT_HELI"
---@param templatesCount number Number of template group names to return
---@return table #Template group names (table of strings) that fit the criteria, duplicates are possible
function HC:GetRandomTemplates(side, missionType, templatesCount)
    local templates = HC:GetTemplateGroupNames(side, missionType)
    local result = {}
    for i=1, templatesCount do
        local randomIndex = math.random(#templates)
        table.insert(result, templates[randomIndex])
    end
    return result
end    

--Initializes inventory templates for airbases, frontline airbases and FARPS
--Inventory templates are defined by static cargo objects with names 
--[SIDE]_MAIN_INVENTORY for "major" airbases
--[SIDE]_FRONTLINE_INVENTORY for "frontline" airbases
--[SIDE]_FARP_INVENTORY for FARPS
function HC:InitInventoryTemplates()
    HC:T("Initializing inventory templates")
    HC.RED.INVENTORY_TEMPLATES.MAIN = STATIC:FindByName("RED_MAIN_INVENTORY"):GetStaticStorage()
    HC.RED.INVENTORY_TEMPLATES.FRONTLINE = STATIC:FindByName("RED_FRONTLINE_INVENTORY"):GetStaticStorage()
    HC.RED.INVENTORY_TEMPLATES.FARP = STATIC:FindByName("RED_FARP_INVENTORY"):GetStaticStorage()
    HC.BLUE.INVENTORY_TEMPLATES.MAIN = STATIC:FindByName("BLUE_MAIN_INVENTORY"):GetStaticStorage()
    HC.BLUE.INVENTORY_TEMPLATES.FRONTLINE = STATIC:FindByName("BLUE_FRONTLINE_INVENTORY"):GetStaticStorage()
    HC.BLUE.INVENTORY_TEMPLATES.FARP = STATIC:FindByName("BLUE_FARP_INVENTORY"):GetStaticStorage()
    HC:T("Inventory templates initialized")
end

--Adds static warehouse to airbase (required by MOOSE CHIEF)
---@param airbase AIRBASE MOOSE airbase
function HC:SetupAirbaseStaticWarehouse(airbase)
    local SIDE = string.upper(airbase:GetCoalitionName())
    -- Check if we have an enemy warehouse left over from before
    local enemySide = ""
    if (SIDE == "RED") then
        enemySide = "BLUE"
    else
        enemySide = "RED"
    end
    local enemyWarehouse = STATIC:FindByName(enemySide.."_WAREHOUSE_"..airbase:GetName(), false)
    if (enemyWarehouse) then
        --enemy warehouse exists, destroy it
        enemyWarehouse:Destroy(false)
    end

    local warehouseName = SIDE.."_WAREHOUSE_"..airbase:GetName()
    --Check if we already have a warehouse
    local warehouse = STATIC:FindByName(warehouseName, false)
    if( warehouse) then
        HC:W(string.format("Warehouse %s on %s already exists!", warehouseName, airbase:GetName()))
    else
        local randomZone = airbase.AirbaseZone
        local position = randomZone:GetRandomPointVec2()
        --spawn a warehouse in one of the airbase perimeter child zones which provide safe place for spawning
        local childZoneSet = HC:GetChildZoneSet(airbase.AirbaseZone, true)
        if (childZoneSet:Count() == 0) then
            HC:W(string.format("[%s] Couldn't find child spawn zone for warehouse...will spawn in random place...", airbase:GetName()))          
        else
            randomZone = childZoneSet:GetRandomZone(10)
            position = randomZone:GetPointVec2()
            HC.OccupiedSpawnZones[randomZone:GetName()] = true
            HC:T(string.format("Spawning warehouse on %s in zone %s", airbase:GetName(), randomZone:GetName()))
        end
        local whspawn = SPAWNSTATIC:NewFromStatic(SIDE.."_WAREHOUSE_TEMPLATE")
        warehouse = whspawn:SpawnFromCoordinate(position, nil, warehouseName)
    end

    if(airbase:GetCategory() == Airbase.Category.HELIPAD and #(airbase.runways)==0) then
        HC:SetupFARPSupportUnits(airbase)
    end

    return warehouse
end

--Spawns FARP support units necessary for functional FARP
---@param farp AIRBASE FARP to set up
function HC:SetupFARPSupportUnits(farp)
    local farpStatic = STATIC:FindByName(farp:GetName(), false)
    if (not farpStatic) then
        HC:W(string.format("FARP STATIC not found, Can't spawn FARP support units at %s", farp:GetName()))
        return
    end
    local farpStatic = STATIC:FindByName(farp:GetName(), false)
    local radius = 50
    local spacing = 80
    local farplocation = farpStatic:GetCoordinate()
    -- Support objects to spawn
    local FARPSupportObjects = {
        FUEL = { TypeName = "FARP Fuel Depot", ShapeName = "GSM Rus", Category = "Fortifications", Position = nil},
        AMMO = { TypeName = "FARP Ammo Dump Coating", ShapeName = "SetkaKP", Category = "Fortifications", Position = nil},
        TENT = { TypeName = "FARP Tent", ShapeName = "PalatkaB", Category = "Fortifications", Position = nil},
        WINDSOCK  = { TypeName = "Windsock", ShapeName = "H-Windsock_RW", Category = "Fortifications", Position = nil}
    }
    --calculate FARP support objects positions relative to FARP static
    FARPSupportObjects.FUEL.Position = farplocation:Translate(radius,farpStatic:GetHeading()):Translate(spacing, farpStatic:GetHeading()+90)
    FARPSupportObjects.AMMO.Position = farplocation:Translate(radius,farpStatic:GetHeading())
    FARPSupportObjects.TENT.Position = farplocation:Translate(radius,farpStatic:GetHeading()):Translate(spacing, farpStatic:GetHeading()-90)
    FARPSupportObjects.WINDSOCK.Position = farplocation:Translate(radius + 20,farpStatic:GetHeading())

    local farpName = farp:GetName()
    local spawnCountry = country.UN_PEACEKEEPERS
    if(farp:GetCoalition() == coalition.side.RED) then
        spawnCountry = country.USSR
    elseif (farp:GetCoalition() == coalition.side.BLUE) then
        spawnCountry = country.US
    end

    for k,v in pairs(FARPSupportObjects) do
        local current = STATIC:FindByName(farpName.." "..k, false)
        local spawnObj = nil
        --Object already exists
        if (current) then
            --if coalition is different from FARP
            if(current:GetCoalition() ~= farpStatic:GetCoalition() or not current:IsAlive()) then
            current:Destroy()
            end
        end
        spawnObj = SPAWNSTATIC:NewFromType(v.TypeName,v.Category,spawnCountry)
        --spawnObj:InitShape(_object.ShapeName)
        spawnObj:InitHeading(farpStatic:GetHeading())
        spawnObj:SpawnFromCoordinate(v.Position,farpStatic:GetHeading(),farpName.." "..k)
    end
end

--Sets up airbase inventory, aircraft and weapon availability, this is required to limit airframe availability, note that it applies to AI CHIEF and human players
--
--Inventory is configured by modifying template warehouses RED_WAREHOUSE_TEMPLATE, RED_FARP_WAREHOUSE_TEMPLATE, BLUE_WAREHOUSE_TEMPLATE, BLUE_FARP_WAREHOUSE_TEMPLATE
--NOTE: this should run before assigning units to chief  otherwise you might deny units to chief
---@param airbase AIRBASE Airbase to set up
function HC:SetupAirbaseInventory(airbase)
    --HC:T("------------------ Seting up inventory for "..airbase:GetName().." --------------------")
    local targetStorage = STORAGE:FindByName(airbase:GetName())
    local sourceStorage = nil
    local SIDE = string.upper(airbase:GetCoalitionName())
    if(airbase:GetCategory() == Airbase.Category.HELIPAD and #(airbase.runways) == 0) then
        sourceStorage = HC[SIDE].INVENTORY_TEMPLATES.FARP
    elseif (airbase:GetCategory() == Airbase.Category.AIRDROME or #(airbase.runways) > 0) then
        if(HC:IsFrontlineAirbase(airbase)) then
            sourceStorage = HC[SIDE].INVENTORY_TEMPLATES.FRONTLINE
        else
            sourceStorage = HC[SIDE].INVENTORY_TEMPLATES.MAIN
        end            
    else
        HC:W("Unknown airbase category, can't set up inventory ")
        return
    end
    local sourceAircraft, _, sourceWeapons = sourceStorage:GetInventory()

    if(targetStorage) then
        local aircraft, _, weapons = targetStorage:GetInventory()
        --Clear everything first
        --Clear aircraft
        for name,_ in pairs(aircraft) do
            targetStorage:SetItem(name,0)
        end
        --Clear weapons
        for name,_ in pairs(weapons) do
            targetStorage:SetItem(name,0)
        end
        --Fill storage from source storage template
        for name,v in pairs(sourceAircraft) do
            targetStorage:SetItem(name, v)
        end
        for name,v in pairs(sourceWeapons) do
            targetStorage:SetItem(name, v)
        end        
    end
    --HC:T("------------------ END Seting up inventory for "..airbase:GetName().." --------------------")
end

--Garrisons units to be used by chief
---@param warehouse STATIC static warehouse used by chief
---@param airbase AIRBASE airbase to set up
function HC:SetupAirbaseChiefUnits(warehouse, airbase)
    --Generate units stationed at base and add them to chief 
    local side = string.upper(airbase:GetCoalitionName())
    local templates = HC[side].TEMPLATES
    local chief = HC[side].CHIEF
    local airbaseStorage = STORAGE:FindByName(airbase:GetName())
    --check chief units, remove if legions already exist
    local brigadeName = string.format("%s Brigade %s", side, airbase:GetName())
    local airwingName = string.format("%s Air wing %s", side, airbase:GetName())
    for _, legion in pairs(chief.commander.legions) do
        if (legion:GetName() == brigadeName) then
            HC:W("Removed legion "..legion:GetName())
            chief:RemoveLegion(legion)
            break
        end
    end
    for _, legion in pairs(chief.commander.legions) do
        if (legion:GetName() == airwingName) then
            HC:W("Removed legion "..legion:GetName())
            chief:RemoveLegion(legion)
            break
        end
    end    
    -- Finda a safe spawn zone
    local childZoneSet = HC:GetChildZoneSet(airbase.AirbaseZone, true)
    local randomZone = airbase.AirbaseZone
    if (childZoneSet:Count() == 0) then
        HC:W(string.format("[%s] Couldn't find child spawn zone for brigade...will spawn in random place...", airbase:GetName()))          
    else
        randomZone = childZoneSet:GetRandomZone(10)
        HC:T(string.format("Brigade spawn zone on %s set to %s", airbase:GetName(), randomZone:GetName()))
    end
    --Ground units
    local brigade=BRIGADE:New(warehouse:GetName(), brigadeName)
    for i=1, #(templates.LIGHT_INFANTRY) do
        local platoon = PLATOON:New(templates.LIGHT_INFANTRY[i], 2, string.format("%s Infantry %d %s", side, i, airbase:GetName()))
        platoon:SetGrouping(4)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.ONGURAD}, 70)
        -- platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK,}, 50)
        -- platoon:AddMissionCapability({AUFTRAG.Type.PATROLZONE}, 50)
        platoon:SetAttribute(GROUP.Attribute.GROUND_INFANTRY)
        --platoon:SetMissionRange(5)
        brigade:AddPlatoon(platoon)
    end
    for i=1, #(templates.MECHANIZED) do
        local platoon = PLATOON:New(templates.MECHANIZED[i], 2, string.format("%s Mechanized inf %d %s", side,i, airbase:GetName()))
        platoon:SetGrouping(5)
        platoon:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.PATROLZONE,  AUFTRAG.Type.CAPTUREZONE}, 80)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.CONQUER, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK}, 80)
        platoon:SetAttribute(GROUP.Attribute.GROUND_IFV)
        platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    for i=1, #(templates.TANK) do
        local platoon = PLATOON:New(templates.TANK[i], 2, string.format("%s Tank %d %s", side, i, airbase:GetName()))
        platoon:SetGrouping(6)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.CONQUER, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK,  AUFTRAG.Type.CAPTUREZONE}, 90)
        platoon:AddMissionCapability({AUFTRAG.Type.PATROLZONE}, 40)
        platoon:SetAttribute(GROUP.Attribute.GROUND_TANK)
        platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    --brigade:SetSpawnZone(airbase.AirbaseZone)
    brigade:SetSpawnZone(randomZone)
    HC.OccupiedSpawnZones[randomZone:GetName()] = true
    chief:AddBrigade(brigade)
    
    --Air unit mission type groups
    local FIGHTER_TASKS = {AUFTRAG.Type.CAP, AUFTRAG.Type.ESCORT, AUFTRAG.Type.GCICAP, AUFTRAG.Type.INTERCEPT}
    local STRIKER_TASKS = {AUFTRAG.Type.CAS, AUFTRAG.Type.STRIKE, AUFTRAG.Type.BAI, AUFTRAG.Type.CASENHANCED}
    local HELI_TRANSPORT_TASKS = {AUFTRAG.Type.TROOPTRANSPORT, AUFTRAG.Type.CARGOTRANSPORT, AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.RESCUEHELO, AUFTRAG.Type.CTLD}

    local airwing=AIRWING:New(warehouse:GetName(), airwingName)
    --airwing:SetTakeoffHot()
    airwing:SetTakeoffAir() --For quicker testing to not have to wait for AI to take off
    airwing:SetDespawnAfterHolding(true)
    airwing:SetDespawnAfterLanding(true)
    airwing:SetAirbase(airbase)
    airwing:SetVerbosity(0) --set to 0 to prevent large number of trace messages in log
    airwing:SetRespawnAfterDestroyed(7200) --two hours to respawn if destroyed
    
    for i=1, #(templates.TRANSPORT_HELI) do
            local templateGroupName = templates.TRANSPORT_HELI[i]
            local squadron=SQUADRON:New(templates.TRANSPORT_HELI[i], 4, string.format("%s Helicopter Transport Squadron %d %s", side, i, airbase:GetName())) --Ops.Squadron#SQUADRON
            squadron:SetAttribute(GROUP.Attribute.AIR_TRANSPORTHELO)
            squadron:SetGrouping(1) -- 1 aircraft per group.
            squadron:SetModex(10)  -- Tail number of the sqaud start with 60
            squadron:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT}, 90) -- The missions squadron can perform with performance score for those missions 
            squadron:SetMissionRange(60) -- Squad will be considered for targets within 40 NM of its airwing location.
            --Time to get ready again, time to repair per life point taken
            squadron:SetTurnoverTime(10, 0) --maintenance time, repair time [minutes]
            airwing:AddSquadron(squadron)
            --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
            local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
            airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)
    end
    for i=1, #(templates.ATTACK_HELI) do
            local templateGroupName = templates.ATTACK_HELI[i]
            local squadron=SQUADRON:New(templates.ATTACK_HELI[i], 2, string.format("%s Attack Helicopter Squadron %d %s", side, i, airbase:GetName())) --Ops.Squadron#SQUADRON
            squadron:SetGrouping(2)
            squadron:SetModex(30)
            squadron:AddMissionCapability( {AUFTRAG.Type.CAS, AUFTRAG.Type.CASENHANCED}, 80) -- The missions squadron can perform
            squadron:SetMissionRange(40)
            squadron:SetAttribute(GROUP.Attribute.AIR_ATTACKHELO)
            squadron:SetTurnoverTime(10, 0)
            airwing:NewPayload(GROUP:FindByName(templates.ATTACK_HELI[i]), 20, {AUFTRAG.Type.CAS, AUFTRAG.Type.CASENHANCED}) --20 sets of armament), 20,  {AUFTRAG.Type.CAS}) --20 sets of armament
            airwing:AddSquadron(squadron)
            --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
            local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
            airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)
    end
    --Fixed wing assets only for airfields, FARPS have only helicopters (and possibly VTOLs)
    if(airbase:GetCategory() == Airbase.Category.AIRDROME or #(airbase.runways)>0) then
        for i=1, #(templates.CAP) do
                local templateGroupName = templates.CAP[i]
                local squadron=SQUADRON:New(templates.CAP[i], 2, string.format("%s Fighter Squadron %d %s", side, i, airbase:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2)
                squadron:SetModex(10)
                squadron:AddMissionCapability(FIGHTER_TASKS, 90)
                squadron:SetMissionRange(80)
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.CAP[i]), 20, FIGHTER_TASKS)
                airwing:AddSquadron(squadron)
                --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
                local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
                airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)                
        end
        for i=1, #(templates.CAS) do
                local templateGroupName = templates.CAS[i]
                local squadron=SQUADRON:New(templates.CAS[i], 2, string.format("%s Attack Squadron %d %s", side, i, airbase:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2)
                squadron:SetModex(30)
                squadron:AddMissionCapability(STRIKER_TASKS, 90)
                squadron:SetMissionRange(80)
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.CAS[i]), 20, STRIKER_TASKS)
                airwing:AddSquadron(squadron)
                --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
                local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
                airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)                
        end
        for i=1, #(templates.STRIKE) do
                local templateGroupName = templates.STRIKE[i]
                local squadron=SQUADRON:New(templates.STRIKE[i], 2, string.format("%s Strike Squadron %d %s", side, i, airbase:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2)
                squadron:SetModex(50)
                squadron:AddMissionCapability(STRIKER_TASKS, 90)
                squadron:SetMissionRange(80)
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.STRIKE[i]), 20, STRIKER_TASKS)
                airwing:AddSquadron(squadron)
                --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
                local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
                airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)
        end
            for i=1, #(templates.SEAD) do
                local templateGroupName = templates.SEAD[i]
                local squadron=SQUADRON:New(templates.SEAD[i], 1, string.format("%s SEAD Squadron %d %s", side, i, airbase:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2)
                squadron:SetModex(60)
                squadron:AddMissionCapability({AUFTRAG.Type.SEAD}, 90)
                squadron:SetMissionRange(120)
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.SEAD[i]), 20, {AUFTRAG.Type.SEAD})
                airwing:AddSquadron(squadron)
                --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
                local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
                airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)
        end
    end    
    chief:AddAirwing(airwing) 
end

--Spawns units to defend an airbase or FARP
--Number and type of units depends on base hp percentage which abstracts overall combat readiness, morale, supply state...
---@param ab AIRBASE target airbase
---@param hp number (0-100) which abstracts overall combat readiness, morale, supply state...
---@param isFrontline boolean? If true, base will be considered as fro
function HC:SetupAirbaseDefense(ab, hp, isFrontline)
    HC:T("Setting up base defense for "..ab:GetName())      

    local side = string.upper(ab:GetCoalitionName())
    local templates = HC[side].TEMPLATES
    local chief = HC[side].CHIEF
    if (isFrontline == nil) then
        isFrontline = HC:IsFrontlineAirbase(ab)
    end


    -- Base defense garrison based on airbase HP
    local garrison = {
        BASE = 1, -- basic security detachment, mix of armor and AAA from <SIDE>_BASE_SECURITY_TEMPLATES
        SHORAD = 0, -- short range air defense groups from <SIDE>_SHORAD_TEMPLATES
        SAM = 0, -- SAM batteries from <SIDE>_SAM_TEMPLATES
        EWR = 0 --Early warning radars
    }

    if (hp <= 20) then
        garrison = { BASE = 1, SHORAD = 0, SAM = 0, EWR = 0 }
    elseif (hp > 20 and hp <= 40) then
        garrison = { BASE = 1, SHORAD = 1, SAM = 0, EWR = 0 }
    elseif (hp > 40 and hp <= 60) then        
        garrison = { BASE = 1, SHORAD = 2, SAM = 0, EWR = 0 }
    elseif (hp > 60 and hp <= 80) then
        garrison = { BASE = 1, SHORAD = 2, SAM = 1, EWR = 1 }
    elseif (hp > 80 and hp <= 90) then
        garrison = { BASE = 1, SHORAD = 2, SAM = 2, EWR = 1 }
    elseif (hp > 90) then
        garrison = { BASE = 1, SHORAD = 3, SAM = 2, EWR = 1 }
    end

    HC:T(string.format("Garrison for %s BASE: %d SHORAD: %d SAM: %d EWR: %d", ab:GetName(), garrison.BASE, garrison.SHORAD, garrison.SAM, garrison.EWR))
    --Add a security detachment to base
    --find a random zone inside airbase zone and spawn base defense
    local childZonesSet = HC:GetChildZoneSet(ab.AirbaseZone, true)

    

    for i=1, garrison.BASE do
        local randomZone = childZonesSet:GetRandomZone(10)
        if (not randomZone) then
            HC:W(string.format("[%s] Couldn't find child spawn zone bor BASE GARRISON", ab:GetName()))
            break
        end
        local unitAlias = string.format("%s D SECURITY %d", ab:GetName(), i)
        local spawn = SPAWN:NewWithAlias(templates.BASE_SECURITY[1], unitAlias)
        :OnSpawnGroup(
            function(grp)
                HC:T(string.format("Spawned %s at [%s] [%s]", grp:GetName(), ab:GetName(), randomZone:GetName()))
            end
        )
        :InitRandomizeTemplate(templates.BASE_SECURITY)
        local group = spawn:SpawnFromCoordinate(randomZone:GetPointVec2())
        group:HandleEvent(EVENTS.UnitLost)
        function group:OnEventUnitLost(e)
            HC:E("One of the units in group was killed?")
        end
        childZonesSet:RemoveZonesByName(randomZone:GetName())
        HC.OccupiedSpawnZones[randomZone:GetName()] = true
        chief:AddAgent(group)
    end

    for i=1, garrison.SHORAD do
        local randomZone = childZonesSet:GetRandomZone(10)
        if (not randomZone) then
            HC:W(string.format("[%s] Couldn't find child spawn zone for SHORAD", ab:GetName()))
            break
        end
        local unitAlias = string.format("%s D SHORAD %d", ab:GetName(), i)
        local spawn = SPAWN:NewWithAlias(templates.SHORAD[1], unitAlias)
        :OnSpawnGroup(
            function(grp)
                HC:T(string.format("Spawned %s at [%s] [%s]", grp:GetName(), ab:GetName(), randomZone:GetName()))
                grp:HandleEvent( EVENTS.UnitLost )
                function grp:OnEventUnitLost(e)
                    HC:T("Group"..self:GetName().." lost a unit")            
                end
            end
        )
        :InitRandomizeTemplate(templates.SHORAD)
        local group = spawn:SpawnFromCoordinate(randomZone:GetPointVec2())
        childZonesSet:RemoveZonesByName(randomZone:GetName())
        HC.OccupiedSpawnZones[randomZone:GetName()] = true
        chief:AddAgent(group)
    end

    for i=1, garrison.SAM do
        local randomZone = childZonesSet:GetRandomZone(10)
        if (not randomZone) then
            HC:W(string.format("[%s] Couldn't find child spawn zone for SAM", ab:GetName()))
            break
        end
        local unitAlias = string.format("%s D SAM %d", ab:GetName(), i)
        local spawn = SPAWN:NewWithAlias(templates.SAM[1], unitAlias)
        :OnSpawnGroup(
            function(grp)
                HC:T(string.format("Spawned %s at [%s] [%s]", grp:GetName(), ab:GetName(), randomZone:GetName()))
                grp:HandleEvent( EVENTS.UnitLost )
                function grp:OnEventUnitLost(e)
                    HC:T("Group"..self:GetName().." lost a unit")            
                end
            end
        )
        :InitRandomizeTemplate(templates.SAM)
        local group = spawn:SpawnFromCoordinate(randomZone:GetPointVec2())
        childZonesSet:RemoveZonesByName(randomZone:GetName())
        HC.OccupiedSpawnZones[randomZone:GetName()] = true
        chief:AddAgent(group)
    end

    for i=1, garrison.EWR do
        HC:T(string.format("[%s] Looking for spaen zone for EWR %d zones in set", ab:GetName(), childZonesSet:Count()))
        local randomZone = childZonesSet:GetRandomZone(10)
        if (not randomZone) then
            HC:W(string.format("[%s] Couldn't find child spawn zone for EWR", ab:GetName()))
            break
        end
        local unitAlias = string.format("EWR %s %s %d", side, ab:GetName(), i)
        local spawn = SPAWN:NewWithAlias(templates.EWR[1], unitAlias)
        :OnSpawnGroup(
            function(grp)
                HC:T(string.format("Spawned %s at [%s] [%s]", grp:GetName(), ab:GetName(), randomZone:GetName()))
                grp:HandleEvent( EVENTS.UnitLost )
                function grp:OnEventUnitLost(e)
                    HC:T("Group"..self:GetName().." lost a unit")            
                end
            end
        )
        :InitRandomizeTemplate(templates.EWR)
        local group = spawn:SpawnFromCoordinate(randomZone:GetPointVec2())
        childZonesSet:RemoveZonesByName(randomZone:GetName())
        HC.OccupiedSpawnZones[randomZone:GetName()] = true
        chief:AddAgent(group)
    end    
end

--Resupply of all airbases and FARPs
---@param resupplyPercent number - resupply amount in percent
function HC:AirbaseResupply(resupplyPercent)
    HC:T("Passive resupply triggered")
    for _, abi in pairs(HC.ActiveAirbases) do
        local ab = AIRBASE:FindByName(abi.Name)
        abi.Coalition = ab:GetCoalition()
        if(abi.HP + resupplyPercent <= 100) then
            abi.HP = abi.HP + resupplyPercent
        else
            abi.HP = 100
        end
        abi:DrawLabel()
    end        
end  

--Creates MOOSE CHIEF object
---@param side string RED or BLUE
---@param alias string Chief name (optional)
---@return CHIEF #MOOSE CHIEF object
function HC:CreateChief(side, alias)
    local RADAR_MIN_HEIGHT = 20 --Minimum flight height to be detected, in meters AGL
    local RADAR_THRESH_HEIGHT = 80 --90% chance to not be detected if flying below RADAR_MIN_HEIGHT
    local RADAR_THRESH_BLUR = 90 --Threshold to be detected by the radar overall, defaults to 85%
    local RADAR_CLOSING_IN = 20 --Closing-in in km - the limit of km from which on it becomes increasingly difficult to escape radar detection if flying towards the radar position. Should be about 1/3 of the radar detection radius in kilometers, defaults to 20.
    --https://flightcontrol-master.github.io/MOOSE_DOCS_DEVELOP/Documentation/Ops.Chief.html##(CHIEF).SetRadarBlur
    --chief:SetRadarBlur(RADAR_MIN_HEIGHT, RADAR_THRESH_HEIGHT, RADAR_THRESH_BLUR, RADAR_CLOSING_IN)
    --Add default intel agents and create chief
    local agents = SET_GROUP:New():FilterPrefixes("EWR "..string.upper(side)):FilterPrefixes("AWACS "..string.upper(side)):FilterOnce()
    alias = alias or "CHIEF "..string.upper(side)
    local chief = CHIEF:New(string.lower(side), agents, alias)

    --Limit the number of concurrent missions (although it doesn't seem to work in current MOOSE build)
    chief:SetLimitMission(1, AUFTRAG.Type.CAP)
    chief:SetLimitMission(2, AUFTRAG.Type.GROUNDATTACK)
    chief:SetLimitMission(2, AUFTRAG.Type.INTERCEPT)
    chief:SetLimitMission(2, AUFTRAG.Type.CAS)
    chief:SetLimitMission(2, AUFTRAG.Type.BAI)
    chief:SetLimitMission(1, AUFTRAG.Type.STRIKE)
    chief:SetLimitMission(2, AUFTRAG.Type.BOMBRUNWAY)
    chief:SetLimitMission(2, AUFTRAG.Type.CASENHANCED)
    chief:SetLimitMission(1, AUFTRAG.Type.SEAD)
    chief:SetLimitMission(2, AUFTRAG.Type.ARMORATTACK)
    chief:SetLimitMission(2, AUFTRAG.Type.ARMOREDGUARD)
    chief:SetLimitMission(2, AUFTRAG.Type.ONGUARD)
    chief:SetLimitMission(2, AUFTRAG.Type.PATROLZONE)
    chief:SetLimitMission(2, AUFTRAG.Type.CONQUER)
    chief:SetLimitMission(6, AUFTRAG.Type.CAPTUREZONE)
    chief:SetLimitMission(2, AUFTRAG.Type.OPSTRANSPORT)
    chief:SetLimitMission(10, "Total")
    chief:SetStrategy(CHIEF.Strategy.TOTALWAR)
    chief:SetTacticalOverviewOn() --for debugging
    chief:SetVerbosity(0) --set to 5 for debugging
    chief:SetDetectStatics(true)
    function chief:OnAfterZoneLost(from, event, to, opszone)
        HC:W("Zone is now lost")
    end

    function chief:OnAfterZoneCaptured(from, event, to, opszone)
        HC:W("Zone is now captured")
    end

    function chief:OnAfterZoneEmpty(from, event, to, opszone)
        --this eventhandler will be moved to HC main
        HC:W("Zone is now empty")
        local ab = AIRBASE:FindByName(opszone:GetName())
        --zone neutralized, send troops to capture it
        --possible scenario
        --find closest friendly airbase to neutralized zone, create OPSTRANSPORT
    end
    

    function chief:OnAfterMissionAssign(From, Event, To, Mission, Legions)
        HC:W("OnAfterMissionAssign")
        --mission:SetRoe(ENUMS.ROE.)
    end

    function chief:OnAfterOpsOnMission(From, Event, To, OpsGroup, Mission)
        HC:W("OnAfterOpsOnMission")
        --mission:SetRoe(ENUMS.ROE.)
    end
    return chief
end   


--Creates resources for chief assault on empty and occupied zone
---@param chief CHIEF
---@return resourcesEmpty table, resourcesOccupied table Resource tables for empty zone and occupied zone scenarios
function HC:GetChiefZoneResponse(chief)
        local resourceOccupied, helos = chief:CreateResource(AUFTRAG.Type.CASENHANCED, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
        --HC.BLUE.CHIEF:AddToResource(resourceOccupied, AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_IFV)
        --local resourceOccupied, _ = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.ONGUARD, 1, 1, GROUP.Attribute.GROUND_TANK)

        --local resourceEmpty, emptyInfantry = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.ONGUARD, 2, 4, GROUP.Attribute.GROUND_INFANTRY)
        local resourceEmpty, emptyIFV = chief:CreateResource(AUFTRAG.Type.PATROLZONE, 1, 1, GROUP.Attribute.GROUND_IFV)

        --HC.BLUE.CHIEF:AddToResource(resourceEmpty, AUFTRAG.Type.PATROLZONE, 1, 1, GROUP.Attribute.GROUND_IFV)
        --HC.BLUE.CHIEF:AddTransportToResource(emptyInfantry, 1, 1, {GROUP.Attribute.GROUND_APC})
        --HC.BLUE.CHIEF:AddTransportToResource(emptyInfantry, 1, 1, {GROUP.Attribute.GROUND_IFV})
        --HC.BLUE.CHIEF:AddTransportToResource(emptyInfantry, 1, 12, {GROUP.Attribute.AIR_TRANSPORTHELO})
        --local ifvs = HC.BLUE.CHIEF:AddTransportToResource(emptyInfantry, 1, 2, {GROUP.Attribute.GROUND_IFV})
        --HC.BLUE.CHIEF:AddStrategicZone(opsZone, nil, nil, resourceOccupied, resourceEmpty)
        return resourceEmpty, resourceOccupied
end