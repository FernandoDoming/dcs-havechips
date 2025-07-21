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
    local warehouseName = "WAREHOUSE_"..airbase:GetName()
    --Check if we already have a warehouse
    local warehouse = STATIC:FindByName(warehouseName, false)
    --This is a workaround for MOOSE bug/DCS limitation
    if( warehouse) then
        HC:W(string.format("Warehouse %s on %s already exists!", warehouseName, airbase:GetName()))
        warehouse:Destroy()
    end
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
    if(airbase:GetCategory() == Airbase.Category.HELIPAD and #(airbase.runways)==0) then
        HC:SetupFARPSupportUnits(airbase)
    end
    return warehouse
end

--Cleans up junk around airbase
---@param airbaseName string target airbase to clean up
function HC:AirbaseCleanJunk(airbaseName)
    HC:T("Clearing junk around "..airbaseName)
    local airbase = AIRBASE:FindByName(airbaseName)
    if (not airbase) then    
        return
    end
  local radius = 4000 --should be enough
  local sphere = {
    id = world.VolumeType.SPHERE,
      params = {
      point = airbase:GetCoordinate():GetVec3(),
      radius = radius,
      }
    }
   world.removeJunk(sphere) 
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
    local spawnCountry = country.id.UN_PEACEKEEPERS
    if(farp:GetCoalition() == coalition.side.RED) then
        spawnCountry = country.id.USSR
    elseif (farp:GetCoalition() == coalition.side.BLUE) then
        spawnCountry = country.id.US
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
        spawnObj:SpawnFromCoordinate(v.Position,farpStatic:GetHeading(),farpName.."|| "..k)
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
    local brigade = nil
    local airwing = nil
    for _, legion in pairs(chief.commander.legions) do
        if (not brigade) then
            if (legion:GetName() == brigadeName) then
                brigade = legion
            end
        end
        if(not airwing) then
            if (legion:GetName() == airwingName) then
                airwing = legion
            end
        end
        if (brigade and airwing) then
            break
        end
    end
    if (not brigade) then
        brigade = BRIGADE:New(warehouse:GetName(), brigadeName)
    end
    if (not airwing) then
        airwing = AIRWING:New(warehouse:GetName(), airwingName)
    end

    if (childZoneSet:Count() == 0) then
        HC:W(string.format("[%s] Couldn't find child spawn zone for brigade...will spawn in random place...", airbase:GetName()))          
    else
        randomZone = childZoneSet:GetRandomZone(10)
        HC:T(string.format("Brigade spawn zone on %s set to %s", airbase:GetName(), randomZone:GetName()))
    end
    --Ground units
    for i=1, #(templates.LIGHT_INFANTRY) do
        local cohortName = string.format("%s|| Infantry %s %d", airbase:GetName(), side, i)
        local platoon = nil
        if not UTILS.IsAnyInTable(_COHORTNAMES, cohortName) then
            platoon = PLATOON:New(templates.LIGHT_INFANTRY[i], 2, cohortName)
            platoon:SetGrouping(4)
            platoon:AddMissionCapability({ AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.ONGUARD, AUFTRAG.Type.GROUNDATTACK }, 70)
            platoon:SetAttribute(GROUP.Attribute.GROUND_INFANTRY)
            --platoon:SetMissionRange(5)
            brigade:AddPlatoon(platoon)        
        end
    end
    for i=1, #(templates.MECHANIZED) do
        local cohortName = string.format("%s|| Mechanized infantry %s %d", airbase:GetName(), side, i)
        local platoon = nil
        if not UTILS.IsAnyInTable(_COHORTNAMES, cohortName) then
            platoon = PLATOON:New(templates.MECHANIZED[i], 2, cohortName)
            platoon:SetGrouping(5)
            platoon:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.PATROLZONE,  AUFTRAG.Type.CAPTUREZONE}, 80)
            platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.CONQUER, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK}, 80)
            platoon:SetAttribute(GROUP.Attribute.GROUND_IFV)
            platoon:SetMissionRange(25)
            brigade:AddPlatoon(platoon)            
        end
    end
    for i=1, #(templates.TANK) do
        local cohortName = string.format("%s|| Tank %s %d", airbase:GetName(), side, i)
        local platoon = nil
        if not UTILS.IsAnyInTable(_COHORTNAMES, cohortName) then
            platoon = PLATOON:New(templates.TANK[i], 2, cohortName)
            platoon:SetGrouping(6)
            platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.CONQUER, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK,  AUFTRAG.Type.CAPTUREZONE}, 90)
            platoon:AddMissionCapability({AUFTRAG.Type.PATROLZONE}, 40)
            platoon:SetAttribute(GROUP.Attribute.GROUND_TANK)
            platoon:SetMissionRange(25)
            brigade:AddPlatoon(platoon)            
        end
    end
    brigade.spawnzonemaxdist = 50 --spawn units max 50m from warehouse static
    brigade:SetRespawnAfterDestroyed(HC.WAREHOUSE_RESPAWN_INTERVAL) -- 10 minutes to respawn if destroyed
    chief:AddBrigade(brigade)
    
    --Air unit mission type groups
    local FIGHTER_TASKS = {AUFTRAG.Type.CAP, AUFTRAG.Type.ESCORT, AUFTRAG.Type.GCICAP, AUFTRAG.Type.INTERCEPT}
    local STRIKER_TASKS = {AUFTRAG.Type.CAS, AUFTRAG.Type.STRIKE, AUFTRAG.Type.BAI, AUFTRAG.Type.CASENHANCED}
    local HELI_TRANSPORT_TASKS = {AUFTRAG.Type.TROOPTRANSPORT, AUFTRAG.Type.CARGOTRANSPORT, AUFTRAG.Type.OPSTRANSPORT}

    --airwing:SetTakeoffHot()
    airwing:SetTakeoffAir() --For quicker testing to not have to wait for AI to take off
    airwing:SetDespawnAfterHolding(true)
    airwing:SetDespawnAfterLanding(true)
    airwing:SetAirbase(airbase)
    airwing:SetVerbosity(0) --set to 0 to prevent large number of trace messages in log
    airwing:SetRespawnAfterDestroyed(HC.WAREHOUSE_RESPAWN_INTERVAL) -- 10 minutes to respawn if destroyed
    
    for i=1, #(templates.TRANSPORT_HELI) do
        local templateGroupName = templates.TRANSPORT_HELI[i]
        local cohortName = string.format("%s|| Transport Helicopter %s %d", airbase:GetName(), side, i)
        local squadron = nil
        if not UTILS.IsAnyInTable(_COHORTNAMES, cohortName) then
            squadron=SQUADRON:New(templates.TRANSPORT_HELI[i], 4, cohortName) --Ops.Squadron#SQUADRON
            squadron:AddMissionCapability(HELI_TRANSPORT_TASKS) -- The missions squadron can perform with performance score for those missions 
            squadron:SetAttribute(GROUP.Attribute.AIR_TRANSPORTHELO)
            squadron:SetGrouping(1) -- 1 aircraft per group.
            squadron:SetMissionRange(60) -- Squadron will be considered for targets within 40 NM of its airwing location.
            --Time to get ready again, time to repair per life point taken
            squadron:SetTurnoverTime(10, 0) --maintenance time, repair time [minutes]
            airwing:NewPayload(GROUP:FindByName(templates.TRANSPORT_HELI[i]), 20, HELI_TRANSPORT_TASKS) --20 sets of armament
            airwing:AddSquadron(squadron)
            --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
            local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
            airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)                
        end
    end
    for i=1, #(templates.ATTACK_HELI) do
        local templateGroupName = templates.ATTACK_HELI[i]
        local cohortName = string.format("%s|| Attack Helicopter %s %d", airbase:GetName(), side, i)
        local squadron = nil
        if not UTILS.IsAnyInTable(_COHORTNAMES, cohortName) then
            squadron = SQUADRON:New(templates.ATTACK_HELI[i], 2, cohortName) --Ops.Squadron#SQUADRON
            squadron:AddMissionCapability( {AUFTRAG.Type.CAS, AUFTRAG.Type.CASENHANCED}, 80) -- The missions squadron can perform            
            squadron:SetAttribute(GROUP.Attribute.AIR_ATTACKHELO)            
            squadron:SetGrouping(2)
            squadron:SetMissionRange(40)
            squadron:SetTurnoverTime(10, 0)
            airwing:NewPayload(GROUP:FindByName(templates.ATTACK_HELI[i]), 20, {AUFTRAG.Type.CAS, AUFTRAG.Type.CASENHANCED}) --20 sets of armament), 20,  {AUFTRAG.Type.CAS}) --20 sets of armament
            airwing:AddSquadron(squadron)
            --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
            local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
            airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)
        end
    end
    --Fixed wing assets only for airfields, FARPS have only helicopters (and possibly VTOLs)
    if(airbase:GetCategory() == Airbase.Category.AIRDROME or #(airbase.runways)>0) then
        for i=1, #(templates.CAP) do
            local templateGroupName = templates.CAP[i]
            local cohortName = string.format("%s|| Fighter Sq. %s %d", airbase:GetName(), side, i)
            local squadron = nil
            if not UTILS.IsAnyInTable(_COHORTNAMES, cohortName) then
                squadron = SQUADRON:New(templates.CAP[i], 2, cohortName) --Ops.Squadron#SQUADRON
                squadron:AddMissionCapability(FIGHTER_TASKS, 90)
                squadron:SetGrouping(2)
                squadron:SetMissionRange(80)
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.CAP[i]), 20, FIGHTER_TASKS)
                airwing:AddSquadron(squadron)
                --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
                local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
                airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)                      
            end              
        end
        for i=1, #(templates.CAS) do
            local templateGroupName = templates.CAS[i]
            local cohortName = string.format("%s|| Attack Sq. %s %d", airbase:GetName(), side, i)
            local squadron = nil
            if not UTILS.IsAnyInTable(_COHORTNAMES, cohortName) then
                squadron = SQUADRON:New(templates.CAS[i], 2, cohortName) --Ops.Squadron#SQUADRON
                squadron:AddMissionCapability(STRIKER_TASKS, 90)
                squadron:SetGrouping(2)
                squadron:SetMissionRange(80)
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.CAS[i]), 20, STRIKER_TASKS)
                airwing:AddSquadron(squadron)
                --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
                local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
                airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)                 
            end
        end
        for i=1, #(templates.STRIKE) do
            local templateGroupName = templates.STRIKE[i]
            local cohortName = string.format("%s|| Strike Sq. %s %d", airbase:GetName(), side, i)
            local squadron = nil
            if not UTILS.IsAnyInTable(_COHORTNAMES, cohortName) then
                squadron = SQUADRON:New(templates.STRIKE[i], 2, cohortName) --Ops.Squadron#SQUADRON
                squadron:AddMissionCapability(STRIKER_TASKS, 90)                
                squadron:SetGrouping(2)
                squadron:SetMissionRange(80)
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.STRIKE[i]), 20, STRIKER_TASKS)
                airwing:AddSquadron(squadron)
                --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
                local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
                airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)                
            end
        end
        for i=1, #(templates.SEAD) do
            local templateGroupName = templates.SEAD[i]
            local cohortName = string.format("%s|| SEAD Sq. %s %d", airbase:GetName(), side, i)
            local squadron = nil
            if not UTILS.IsAnyInTable(_COHORTNAMES, cohortName) then
                squadron=SQUADRON:New(templates.SEAD[i], 1, cohortName) --Ops.Squadron#SQUADRON
                squadron:AddMissionCapability({AUFTRAG.Type.SEAD}, 90)                
                squadron:SetGrouping(2)
                squadron:SetMissionRange(120)
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.SEAD[i]), 20, {AUFTRAG.Type.SEAD})
                airwing:AddSquadron(squadron)
                --add airframe to airbase warehouse otherwise chief won't be able to spawn units...confusing bcs we also have mandatory static object as airwing warehouse
                local itemName = GROUP:FindByName(templateGroupName):GetUnit(1):GetTypeName()
                airbaseStorage:AddItem(itemName, squadron.Ngroups * squadron.ngrouping)                    
            end
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
    local MAX_GARRISON_GROUPS_IN_CATEGORY = 5 --should be enough
    local airbaseName = ab:GetName()
    HC:T(string.format("[%s] Setting up base defense",airbaseName))
    local side = string.upper(ab:GetCoalitionName())
    local templates = HC[side].TEMPLATES
    local chief = HC[side].CHIEF

    -- Airbase defense garrison group numbers based on airbase HP
    local garrison = AIRBASEINFO:GetGarrisonForHP(hp)
    -- Garrison group prefixes
    local garissonPrefixes = {
        BASE = string.format("%s|| D BASE ", airbaseName),
        SHORAD = string.format("%s|| D SHORAD ", airbaseName),
        SAM = string.format("%s|| D SAM ", airbaseName),
        EWR = string.format("%s|| D %s EWR ", airbaseName, side),
    }

    

    local groupsOnBase = SET_GROUP:New():FilterPrefixes(string.format("%s|| D ", airbaseName)):FilterOnce()
    --this is the current state of defences, we will use that to determine if there are some groups we need to re)spawn) or destroy
    local aliveGarrisonGroups = { BASE = {}, SHORAD = {}, SAM = {}, EWR = {} }
    local totalAlive = 0
    --categorize defense garrison groups found
    groupsOnBase:ForEachGroup(    
        function(group)
            --HC:T("-- *** --"..group:GetName())
            local name = group:GetName()
            if (not HC:DestroyGroupIfDamaged(group)) then
                if (name:startswith(garissonPrefixes.BASE) and group:IsAlive()) then
                    aliveGarrisonGroups.BASE[name] = group
                    totalAlive = totalAlive + 1
                elseif (name:startswith(garissonPrefixes.SHORAD) and group:IsAlive()) then
                    aliveGarrisonGroups.SHORAD[name] = group
                    totalAlive = totalAlive + 1
                elseif (name:startswith(garissonPrefixes.SAM) and group:IsAlive()) then
                    aliveGarrisonGroups.SAM[name] = group
                    totalAlive = totalAlive + 1
                elseif (name:startswith(garissonPrefixes.EWR) and group:IsAlive()) then
                    aliveGarrisonGroups.EWR[name] = group
                    totalAlive = totalAlive + 1
                end                
            else
                HC:W(string.format("[%s] Destroyed damaged group [%s]", airbaseName, name))
            end
        end
    )
    --at this point we destroyed all damaged groups, 
    -- aliveGarrisonGroups is the structure containing all ALIVE units on base
    -- groupsOnBase is the structure containing all groups on base regardless of status
    HC:T(string.format("[%s] Garrison [HP=%d]\nREQUIRED BASE: %d SHORAD: %d SAM: %d EWR: %d\nCURRENT  BASE: %d SHORAD: %d SAM: %d EWR: %d, total alive units: %d", 
    airbaseName, hp, garrison.BASE, garrison.SHORAD, garrison.SAM, garrison.EWR,  
    TCount(aliveGarrisonGroups.BASE), 
    TCount(aliveGarrisonGroups.SHORAD), 
    TCount(aliveGarrisonGroups.SAM), 
    TCount(aliveGarrisonGroups.EWR),
    totalAlive)
    )

    --early chance to return if we have required garrison units
    local function isGarissonOK()
        local result = true
        for category,required in pairs(garrison) do
            local current = TCount(aliveGarrisonGroups[category])
            if (current ~= required) then
                return false
            end
        end
        return result
    end

    if(isGarissonOK()) then
        HC:T("GARISSON OK")
        return
    end

    local garrisonGroupsToDestroy = {}

    --          make a categorized list of groups we need to destroy
    for category, garCategoryGroups in pairs(aliveGarrisonGroups) do
        local aliveT = aliveGarrisonGroups[category]
        local alive = TCount(aliveGarrisonGroups[category])
        local desired = garrison[category]

        if(alive > desired) then
            HC:T(string.format("Garrison surplus of %s %d/%d", category, alive, desired))
            local destrCount = 0
            HC:T(string.format("List of %s to destroy:", category))
            for name, groupToDestroy in pairs(aliveT) do
                    if (destrCount < alive - desired) then
                        table.insert(garrisonGroupsToDestroy, groupToDestroy)                        
                        --remove them from aliveGarrison units as we will destroy them
                        aliveGarrisonGroups[category][name] = nil
                        HC:T(groupToDestroy:GetName())
                    else
                        break
                    end
                    destrCount = destrCount + 1                    
            end
        elseif (alive < desired) then
            HC:T(string.format("Garrison deficit of %s %d/%d", category, alive, desired))
        end
    end
    --------------------------------------------------------------------------------------

    --                          Destroy surplus groups
    HC:T(string.format("[%s] Destroying surplus groups", airbaseName))
    local destroyedGroupsCount = 0
    for _, g in pairs(garrisonGroupsToDestroy) do
        HC:T(string.format("[%s] %s destroy", airbaseName, g:GetName()))
        g:Destroy()
        HC:T(string.format("[%s] %s destroy DONE", airbaseName, g:GetName()))
        destroyedGroupsCount = destroyedGroupsCount + 1
    end
    HC:T(string.format("[%s] Destroying surplus groups DONE", airbaseName))
    ----------------------------------------------------------------------------------------
    
    --now that we cleared extras and know what to add, calculate which spawn zones are available
    local childZonesSet = HC:CheckFreeSpawnZones(airbaseName)
    HC:T(string.format("[%s] Available spawn zones:", airbaseName))
    childZonesSet:ForEachZone(function(z)
        HC:T(string.format("[%s] %s", airbaseName, z:GetName()))
    end)
    HC:T(string.format("[%s] Spawning defense groups", airbaseName))

    --utility function to find a group with prefix in table
    local function unitExists(prefix, list)
        for k, _ in pairs(list) do
            if (k:startswith(prefix)) then
                HC:W(string.format("Group in alive garrison units, prefix: %s alive: %s", prefix, k))
                return true
            end
        end
        return false
    end

    --keep spawning groups until we have the desired quantity
    local function spawnAsRequired(categoryName, templates)
        categoryName = string.upper(categoryName)
        local spawnedGroups = {}
        local prefix = garissonPrefixes[categoryName]
        local currentNum = TCount(aliveGarrisonGroups[categoryName])
        for i=1, MAX_GARRISON_GROUPS_IN_CATEGORY do
            HC:T(string.format("%s current: %d desired: %d", categoryName, currentNum, garrison[categoryName]))            
            if (currentNum == garrison[categoryName]) then break end --exit when we have sufficient number of units
            local unitAlias = string.format("%s%d", prefix, i)
            if (not unitExists(unitAlias, aliveGarrisonGroups[categoryName])) then
                --alive group doesn't exist with that prefix, we need to (re)spawn it
                local randomZone = childZonesSet:GetRandomZone(10)
                if (not randomZone) then --nowhere to spawn
                    HC:W(string.format("[%s] Couldn't find child spawn zone for %s", airbaseName, categoryName))
                    break
                end
                local spawn = SPAWN:NewWithAlias(templates[1], unitAlias)
                                    :OnSpawnGroup(
                                        function(grp)
                                            HC:T(string.format("Spawned %s at [%s] [%s]", grp:GetName(), airbaseName, randomZone:GetName()))
                                        end
                                    )
                                    :InitRandomizeTemplate(templates)
                HC:T(string.format("[%s] Spawning %s at [%s]", airbaseName, unitAlias,  randomZone:GetName()))
                group:SetProperty("airbaseName", airbaseName)
                local group = spawn:SpawnFromCoordinate(randomZone:GetPointVec2())
                for _, u in pairs(group:GetUnits()) do
                    u:SetProperty("airbaseName", airbaseName)
                end
                childZonesSet:RemoveZonesByName(randomZone:GetName())
                HC.OccupiedSpawnZones[randomZone:GetName()] = true
                chief:AddAgent(group)
                currentNum = currentNum +1
            end            
        end
        return spawnedGroups
    end
    
    local gBASE = spawnAsRequired("BASE", templates.BASE_SECURITY)
    local gSHORAD = spawnAsRequired("SHORAD", templates.SHORAD)
    local gSAM = spawnAsRequired("SAM", templates.SAM)
    local gEWR = spawnAsRequired("EWR", templates.EWR)
    HC:T("Garrison ops complete "..airbaseName)
end

--Spawns units to defend an airbase or FARP
--Number and type of units depends on base hp percentage which abstracts overall combat readiness, morale, supply state...
---@param ab AIRBASE target airbase
---@param hp number (0-100) which abstracts overall combat readiness, morale, supply state...
---@param isFrontline boolean? If true, base will be considered as fro
function HC:SetupAirbaseStatics(airbaseName)
    local abi = HC.ActiveAirbases[airbaseName]
    local airbase = AIRBASE:FindByName(airbaseName)
    HC:T(string.format("[%s] Setting up base statics",airbaseName))
    local side = string.upper(ab:GetCoalitionName())
    local owner = country.id.US
    local enemySide = ""
    if (side == "BLUE") then
        owner = country.id.US
        enemySide = "RED"
    elseif(side == "RED") then
        owner = country.id.USSR
        enemySide = "BLUE"
    else
        HC:W(string.format("[%s] SeatupAirbaseStatics: base is neither red nor blue, skipping statics"))
        return
    end

    local staticsRequired = abi:GetRequiredStatics()
    --destroy all dead statics, do I have to do that, should I?
    SET_STATIC:New():FilterZones(airbase.AirbaseZone):FilterPrefixes(string.format("%s|| S ", airbaseName)):FilterOnce()
            :ForEachStatic(
                function(s)
                    if (not s:IsAlive()) then
                        s:Destroy()
                    end
                end)
    --destroy all enemy statics if any are left over after base was captured
        SET_STATIC:New():FilterZones(airbase.AirbaseZone):FilterCoalitions({string.lower(enemySide)}):FilterOnce()
            :ForEachStatic(
                function(s)
                    s:Destroy()
                end)
    --utility function to find a static with prefix in table
    local function findStaticByPrefix(prefix, list)
        for k, v in pairs(list) do
            if (k:startswith(prefix)) then
                HC:W(string.format("Static in alive garrison statics, prefix: %s alive: %s", prefix, k))
                return v
            end
        end
        return nil
    end
        
    local aliveStatics = SET_STATIC:New():FilterZones(airbase.AirbaseZone):FilterPrefixes(string.format("%s|| S ", airbaseName)):FilterOnce()
    --first destroy all static we do not need to free up spawn zones
    for name, required in pairs(staticsRequired) do
        local prefix = string.format("%s|| S %s", airbaseName, name)
        if (not required) then
            --destroy
            local static = findStaticByPrefix(prefix, aliveStatics)
            if(static) then
                static:Destroy()
            end
        end
    end
    local childZonesSet = HC:CheckFreeSpawnZones(airbaseName)
    --now spawn those we need
    for name, required in pairs(staticsRequired) do
        local prefix = string.format("%s|| S %s", airbaseName, name)
        if (required) then
            --spawn
            local static = findStaticByPrefix(prefix, aliveStatics)
            if (not static) then
                local spawn = SPAWNSTATIC:NewFromStatic(name.."_TEMPLATE", owner)
                local randomZone = HC:GetRandomChildZone(ab.AirbaseZone, true)
                if (not randomZone) then
                    HC:W(string.format("[%s] Couldn't find spawn zone for airbase static %s", airbaseName, name))
                    break
                end
                childZonesSet:RemoveZonesByName(randomZone:GetName())
                HC.OccupiedSpawnZones[randomZone:GetName()] = true
                local newStatic = spawn:SpawnFromCoordinate(randomZone:GetPointVec2(), nil, prefix)
                newStatic:SetProperty("airbaseName", airbaseName)
                newStatic:SetProperty("damageWhenLost", HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST[name] or 1)
            end            
        end
    end

end
