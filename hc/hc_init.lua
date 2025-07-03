--write info to log
function hcl(message)
    env.info("[HaveChips] "..message)    
end 
--write warning to log
function hcw(message)
    env.warning("[HaveChips] "..message)
end  

HC = {
    RED = { 
        TEMPLATES = {}
    },
    BLUE = {
        TEMPLATES = {}        
    },
    TEMPLATE_CATEGORIES = {"SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "ATTACK_HELI", "TRANSPORT_HELI", "BASE_SECURITY", "SAM"},
    RESOURCES_ZONE_OCCUPIED = {},
    RESOURCES_ZONE_EMPTY = {}
}

--Gets all templates for side of missionType (or unit category)
--currently TEMPLATE_CATEGORIES {"SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "SAM", "ATTACK_HELI", "TRANSPORT_HELI"}
function HC:GetTemplatesForCategory(side, missionType)    
    local templates = {}
    --convention: use UPPERCASE for template zones
    local zoneName = string.upper(side.."_"..missionType.."_TEMPLATES")
    local templateZone = ZONE:FindByName(zoneName)
    if (templateZone == nil) then
        hcw("Couldn't find template zone "..zoneName.." no templates for "..side.." "..missionType.." will be available!")
        return {}
    end

    local allGroups = SET_GROUP:New():FilterCoalitions(string.lower(side), false):FilterActive(false):FilterOnce()
    allGroups:ForEachGroup(
        function(g)
            --Get first unit in group, if in specified zone then add to templates, not perfect but it works
            if (templateZone:IsVec3InZone(g:GetUnits()[1]:GetVec3())) then
                hcl(g.GroupName.." added to " ..side.." templates ".. missionType)
                table.insert(templates, g:GetName())
            end    
        end
    )
    return templates
end  

--Initializes the templates for Airwings and platoons
function HC:InitGroupTemplates()
    hcl("HC:InitGroupTemplates: Initializing group templates")
    local sides = {"RED", "BLUE"}
    for j=1, #(sides) do        
        for i=1,#(HC.TEMPLATE_CATEGORIES) do
            self[string.upper(sides[j])].TEMPLATES[HC.TEMPLATE_CATEGORIES[i]] = self:GetTemplatesForCategory(sides[j], HC.TEMPLATE_CATEGORIES[i])
        end  
    end
    hcl("HC:InitGroupTemplates: done")
end

function HC:CreateChief(side, alias)
    local RADAR_MIN_HEIGHT = 20 --Minimum flight height to be detected, in meters AGL
    local RADAR_THRESH_HEIGHT = 80 --90% chance to not be detected if flying below RADAR_MIN_HEIGHT
    local RADAR_THRESH_BLUR = 90 --Threshold to be detected by the radar overall, defaults to 85%
    local RADAR_CLOSING_IN = 20 --Closing-in in km - the limit of km from which on it becomes increasingly difficult to escape radar detection if flying towards the radar position. Should be about 1/3 of the radar detection radius in kilometers, defaults to 20.
    --https://flightcontrol-master.github.io/MOOSE_DOCS_DEVELOP/Documentation/Ops.Chief.html##(CHIEF).SetRadarBlur
    --chief:SetRadarBlur(RADAR_MIN_HEIGHT, RADAR_THRESH_HEIGHT, RADAR_THRESH_BLUR, RADAR_CLOSING_IN)
    --Add default intel agents and create chief
    local agents = SET_GROUP:New():FilterPrefixes(string.upper(side).." EWR"):FilterPrefixes(string.upper(side).." AWACS"):FilterOnce()
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
    chief:SetLimitMission(2, AUFTRAG.Type.CAPTUREZONE)
    chief:SetLimitMission(2, AUFTRAG.Type.OPSTRANSPORT)
    chief:SetLimitMission(10, "Total")
    chief:SetStrategy(CHIEF.Strategy.TOTALWAR)
    chief:SetTacticalOverviewOn()
    chief:SetVerbosity(1)
    chief:SetDetectStatics(true)
    function chief:OnAfterZoneLost(from, event, to, opszone)
        MESSAGE:New(string.format("Zone lost")):ToAll()
    end

    function chief:OnAfterZoneCaptured(from, event, to, opszone)
        MESSAGE:New(string.format("Zone captured")):ToAll()
    end

    function chief:OnAfterZoneEmpty(from, event, to, opszone)
        MESSAGE:New(string.format("Zone empty")):ToAll()        
        --zone neutralized, send troops to capture it
        --possible scenario
        --find closest friendly airbase to neutralized zone, create OPSTRANSPORT
    end

    function chief:OpsOnMission(group, mission)
        MESSAGE:New(string.format(string.format("Group %s is on a mission %s", group:GetName(), mission:GetType())), 10):ToAll()
        --mission:SetRoe(ENUMS.ROE.)
    end
    self[string.upper(side)].CHIEF = chief
    --return chief
end   

--Creates army brigade and an airwing at specified base and warehouse and provides them to chief
function HC:PopulateBase(warehouse, ab)
    hcl("HC:InitBaseUnits Creating base units")    
    local side = string.upper(ab:GetCoalitionName())
    local templates = self[side].TEMPLATES
    local chief = self[side].CHIEF
    --Add a security detachment to base
    --find a random zone inside airbase zone and spawn base defense
    --todo: track used zones to prevent spawning groups on top of each other
    local childZones = self:GetChildZones(ab.AirbaseZone)
    local childZonesCount = #(childZones)
    if(childZonesCount > 0) then
        local baseSecurity = SPAWN:NewWithAlias(templates.BASE_SECURITY[1], string.format("Base security detachment %s", ab:GetName()))
        :OnSpawnGroup(function(grp)
            hcl(string.format("Spawned base security %s at %s", grp:GetName(), ab:GetName()))
        end
        )        
        :InitRandomizeTemplate(templates.BASE_SECURITY)
        :InitRandomizeZones( childZones )
        local bsGroup = baseSecurity:Spawn()
        chief:AddAgent(bsGroup)
    else
        hcw(string.format("No child spawn zones found at %s , base will not be defended", ab:GetName()))
    end
    --Generate units stationed at base and add them to chief    
    --Ground units
    local brigade=BRIGADE:New(warehouse:GetName(), side.." brigade "..ab:GetName())
    for i=1, #(templates.LIGHT_INFANTRY) do
        local platoon = PLATOON:New(templates.LIGHT_INFANTRY[i], 5, string.format("%s Infantry %d %s", side, i, ab:GetName()))
        platoon:SetGrouping(6)
        platoon:AddMissionCapability({AUFTRAG.Type.CONQUER, AUFTRAG.Type.CAPTUREZONE}, 70)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK,}, 50)
        platoon:AddMissionCapability({AUFTRAG.Type.PATROLZONE}, 50)
        platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    for i=1, #(templates.MECHANIZED) do
        local platoon = PLATOON:New(templates.MECHANIZED[i], 5, string.format("%s Mechanized inf %d %s", side,i, ab:GetName()))
        platoon:SetGrouping(4)
        platoon:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.PATROLZONE,  AUFTRAG.Type.CAPTUREZONE}, 80)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.CONQUER, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK}, 80)
        platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    for i=1, #(templates.TANK) do
        local platoon = PLATOON:New(templates.TANK[i], 5, string.format("%s Tank %d %s", side, i, ab:GetName()))
        platoon:SetGrouping(4)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.CONQUER, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK,  AUFTRAG.Type.CAPTUREZONE}, 90)
        platoon:AddMissionCapability({AUFTRAG.Type.PATROLZONE}, 40)
        platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    chief:AddBrigade(brigade)
    
    --Air units
    local FIGHTER_TASKS = {AUFTRAG.Type.CAP, AUFTRAG.Type.ESCORT, AUFTRAG.Type.GCICAP, AUFTRAG.Type.INTERCEPT}
    local STRIKER_TASKS = {AUFTRAG.Type.CAS, AUFTRAG.Type.STRIKE, AUFTRAG.Type.BAI, AUFTRAG.Type.CASENHANCED}
    local HELI_TRANSPORT_TASKS = {AUFTRAG.Type.TROOPTRANSPORT, AUFTRAG.Type.CARGOTRANSPORT, AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.RESCUEHELO, AUFTRAG.Type.CTLD}

    local airwing=AIRWING:New(warehouse:GetName(), string.format("%s Air wing %s", side, ab:GetName()))
    --airwing:SetTakeoffHot()
    airwing:SetTakeoffAir()
    airwing:SetRespawnAfterDestroyed(7200) --two hours to respawn if destroyed
    for i=1, #(templates.TRANSPORT_HELI) do
            local squadron=SQUADRON:New(templates.TRANSPORT_HELI[i], 3, string.format("%s Helicopter Transport Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
            squadron:SetGrouping(2) -- Two aircraft per group.
            squadron:SetModex(60)  -- Tail number of the sqaud start with 130, 131,...
            squadron:AddMissionCapability( HELI_TRANSPORT_TASKS, 90) -- The missions squadron can perform
            squadron:SetMissionRange(40) -- Squad will be considered for targets within 200 NM of its airwing location.
            airwing:NewPayload(GROUP:FindByName(templates.TRANSPORT_HELI[i]), 20, HELI_TRANSPORT_TASKS) --20 sets of armament
            airwing:AddSquadron(squadron)
    end
        for i=1, #(templates.ATTACK_HELI) do
            local squadron=SQUADRON:New(templates.ATTACK_HELI[i], 3, string.format("%s Attack Helicopter Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
            squadron:SetGrouping(2) -- Two aircraft per group.
            squadron:SetModex(60)  -- Tail number of the sqaud start with 130, 131,...
            squadron:AddMissionCapability( {AUFTRAG.Type.CAS, AUFTRAG.Type.CASENHANCED}, 80) -- The missions squadron can perform
            squadron:SetMissionRange(40) -- Squad will be considered for targets within 200 NM of its airwing location.
            airwing:NewPayload(GROUP:FindByName(templates.ATTACK_HELI[i]), 20,  {AUFTRAG.Type.CAS}) --20 sets of armament
            airwing:AddSquadron(squadron)
    end
    --Fixed wing assets only for airfields, FARPS have only helicopters (and possibly VTOLs)
    if(ab:GetCategory() == Airbase.Category.AIRDROME) then
        for i=1, #(templates.CAP) do
                local squadron=SQUADRON:New(templates.CAP[i], 3, string.format("%s Fighter Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2) -- Two aircraft per group.
                squadron:SetModex(10)  -- Tail number of the sqaud start with 130, 131,...
                squadron:AddMissionCapability(FIGHTER_TASKS, 90) -- The missions squadron can perform
                squadron:SetMissionRange(80) -- Squad will be considered for targets within 200 NM of its airwing location.
                airwing:NewPayload(GROUP:FindByName(templates.CAP[i]), 20, FIGHTER_TASKS) --20 sets of armament
                squadron:SetVerbosity(3)
                airwing:AddSquadron(squadron)
        end
        for i=1, #(templates.CAS) do
                local squadron=SQUADRON:New(templates.CAS[i], 3, string.format("%s Attack Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2) -- Two aircraft per group.
                squadron:SetModex(30)  -- Tail number of the sqaud start with 130, 131,...
                squadron:AddMissionCapability(STRIKER_TASKS, 90) -- The missions squadron can perform
                squadron:SetMissionRange(80) -- Squad will be considered for targets within 200 NM of its airwing location.
                airwing:NewPayload(GROUP:FindByName(templates.CAS[i]), 20, STRIKER_TASKS) --20 sets of armament
                squadron:SetVerbosity(3)
                airwing:AddSquadron(squadron)
        end
        for i=1, #(templates.STRIKE) do
                local squadron=SQUADRON:New(templates.STRIKE[i], 3, string.format("%s Strike Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2) -- Two aircraft per group.
                squadron:SetModex(50)  -- Tail number of the sqaud start with 130, 131,...
                squadron:AddMissionCapability(STRIKER_TASKS, 90) -- The missions squadron can perform
                squadron:SetMissionRange(80) -- Squad will be considered for targets within 200 NM of its airwing location.
                airwing:NewPayload(GROUP:FindByName(templates.STRIKE[i]), 20, STRIKER_TASKS) --20 sets of armament
                squadron:SetVerbosity(3)
                airwing:AddSquadron(squadron)
        end
            for i=1, #(templates.SEAD) do
                local squadron=SQUADRON:New(templates.SEAD[i], 3, string.format("%s SEAD Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2) -- Two aircraft per group.
                squadron:SetModex(60)  -- Tail number of the sqaud start with 130, 131,...
                squadron:AddMissionCapability({AUFTRAG.Type.SEAD}, 90) -- The missions squadron can perform
                squadron:SetMissionRange(120) -- Squad will be considered for targets within 200 NM of its airwing location.
                airwing:NewPayload(GROUP:FindByName(templates.SEAD[i]), 20, {AUFTRAG.Type.SEAD}) --20 sets of armament
                squadron:SetVerbosity(3)                
                airwing:AddSquadron(squadron)
        end
    end    
    chief:AddAirwing(airwing) 

end
--Returns a list of zones which are inside specified "parent" zone
function HC:GetChildZones(parent)
    local chilldZones = {}
    for _, zone in pairs(_DATABASE.ZONES) do
        local childVec3 = zone:GetVec3()
        if (parent:IsVec3InZone(childVec3)) then
            table.insert(chilldZones, zone)
        end
    end
    return chilldZones
end    

function HC:SetChiefStrategicZoneBehavior(chief, zone)
    --- Create a resource list of mission types and required assets for the case that the zone is OCCUPIED.
    --
    -- Here, we create an enhanced CAS mission and employ at least on and at most two asset groups.
    -- NOTE that two objects are returned, the resource list (ResourceOccupied) and the first resource of that list (resourceCAS).
    local ResourceOccupied, resourceCAS=chief:CreateResource(AUFTRAG.Type.CAPTUREZONE, 1, 1)
    -- Add at least one RECON mission that uses UAV type assets.
    --myChief:AddToResource(ResourceOccupied, AUFTRAG.Type.RECON, 1, nil, GROUP.Attribute.AIR_UAV)
    -- Add at least one but at most two BOMBCARPET missions.
    --myChief:AddToResource(ResourceOccupied, AUFTRAG.Type.BOMBCARPET, 1, 2)

    --- Create a resource list of mission types and required assets for the case that the zone is EMPTY.
    -- NOTE that two objects are returned, the resource list (ResourceEmpty) and the first resource of that list (resourceInf).
    -- Here, we create an ONGUARD mission and employ at least on and at most five infantry assets.
    local ResourceEmpty, resourceInf=chief:CreateResource(AUFTRAG.Type.CAPTUREZONE, 1, 1)
    -- Add a transport to the infantry resource. We want at least one and up to two transport helicopters.
    chief:AddTransportToResource(resourceInf, 1, 4, GROUP.Attribute.AIR_TRANSPORTHELO)
    --chief:AddTransportToResource(resourceInf, 1, 1, AUFTRAG.Type.TROOPTRANSPORT)

    -- Add stratetic zone with customized reaction.
    chief:SetStrategicZoneResourceEmpty(zone, ResourceEmpty)
    chief:SetStrategicZoneResourceOccupied(zone, ResourceOccupied)

end    


function HC:InitAirbases()
    hcl("HC:InitAirbases()")
    local airbases = AIRBASE.GetAllAirbases()
    for i=1, #(airbases) do
        local ab = airbases[i]
        local side = string.upper(ab:GetCoalitionName())  
        hcl("Initializing base "..ab:GetName()..", coalition "..ab:GetCoalitionName()..", category "..ab:GetCategoryName())
        local opsZone = OPSZONE:New(ab.AirbaseZone, ab:GetCoalition())
        opsZone:Start()
        --If airbase is not neutral      
        if(ab:GetCoalition() ~= coalition.side.NEUTRAL) then --do not place warehouses on neutral bases
            local side = string.upper(ab:GetCoalitionName())        
            local warehouseName = side.."_WAREHOUSE_"..ab:GetName()
            local chief = self[string.upper(side)].CHIEF
            --Check if we already have a warehouse
            local warehouse = STATIC:FindByName(warehouseName, false)
            opsZone:SetDrawZone(false)
            if( warehouse) then
                hcw(string.format("Warehouse %s on %s already exists!", warehouseName, ab:GetName()))
            else
                local airbaseCategory = ab:GetCategory() --to be used later for disstinct setup Airbase vs FARP
                --spawn a warehouse
                local childZones = self:GetChildZones(ab.AirbaseZone)
                local childZonesCount = #(childZones)
                local whspawn = SPAWNSTATIC:NewFromStatic(side.."_WAREHOUSE_TEMPLATE")   
                local position = ab:GetZone():GetRandomPointVec2()
                local whSpawnZone = ab.AirbaseZone
                if(childZonesCount > 0) then
                    whSpawnZone = childZones[math.random(childZonesCount)]
                    hcl(string.format("Spawning warehouse on %s in zone %s", ab:GetName(), whSpawnZone:GetName()))
                else
                    hcw(string.format("No defined child spawn zones found, spawning warehouse on %s in AirbaseZone", ab:GetName(), ab:GetName()))
                end
                position = whSpawnZone:GetPointVec2()
                warehouse = whspawn:SpawnFromCoordinate(position, nil, warehouseName)
                hcl("Spawning warehouse ")
            end
            self:PopulateBase(warehouse, ab)
            --Add ops zone to both chiefs
            HC.RED.CHIEF:AddStrategicZone(opsZone)
            HC.BLUE.CHIEF:AddStrategicZone(opsZone)
            --customize chief response for strategic zone
            self:SetChiefStrategicZoneBehavior(HC.RED.CHIEF, opsZone)
            self:SetChiefStrategicZoneBehavior(HC.BLUE.CHIEF, opsZone)
        else
            --Neutral airbase
            hcl("Ignoring neutral zone, it will be initialized when captured")
        end
    end
end

HC:InitGroupTemplates()
HC:CreateChief("red", "Zhukov")
HC:CreateChief("blue", "McArthur")
HC:InitAirbases()
HC.RED.CHIEF:Start()
HC.BLUE.CHIEF:Start()

--HC.RED.CHIEF:__Start(1)
--HC.BLUE.CHIEF:__Start(1)
