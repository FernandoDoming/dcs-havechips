JSON = loadfile(lfs.writedir().."Missions\\havechips\\lib\\json.lua")()
HC = {
    RED = { 
        TEMPLATES = {}
    },
    BLUE = {
        TEMPLATES = {}        
    },
    TEMPLATE_CATEGORIES = {"SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "ATTACK_HELI", "TRANSPORT_HELI", "BASE_SECURITY", "SAM"},
    ActiveAirbases = {}
}

--Write trace message to log
function HC:T(message)
    env.info("[HaveChips] "..message)
end

--Write warning message to log
function HC:W(message)
    env.warning("[HaveChips] "..message)
end

--Write error message to log
function HC:E(message)
    env.error("[HaveChips] "..message)
end

--Gets all templates for side of missionType (or unit category)
--currently TEMPLATE_CATEGORIES {"SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "SAM", "ATTACK_HELI", "TRANSPORT_HELI"}
function HC:GetTemplatesForCategory(side, missionType)    
    local templates = {}
    --convention: use UPPERCASE for template zones
    local zoneName = string.upper(side.."_"..missionType.."_TEMPLATES")
    local templateZone = ZONE:FindByName(zoneName)
    if (templateZone == nil) then
        self:W("Couldn't find template zone "..zoneName.." no templates for "..side.." "..missionType.." will be available!")
        return {}
    end

    local allGroups = SET_GROUP:New():FilterCoalitions(string.lower(side), false):FilterActive(false):FilterOnce()
    allGroups:ForEachGroup(
        function(g)
            --Get first unit in group, if in specified zone then add to templates, not perfect but it works
            if (templateZone:IsVec3InZone(g:GetUnits()[1]:GetVec3())) then
                self:T(g.GroupName.." added to " ..side.." templates ".. missionType)
                table.insert(templates, g:GetName())
            end    
        end
    )
    return templates
end  

--Initializes the templates for Airwings and platoons
function HC:InitGroupTemplates()
    self:T("HC:InitGroupTemplates: Initializing group templates")
    local sides = {"RED", "BLUE"}
    for j=1, #(sides) do        
        for i=1,#(HC.TEMPLATE_CATEGORIES) do
            self[string.upper(sides[j])].TEMPLATES[HC.TEMPLATE_CATEGORIES[i]] = self:GetTemplatesForCategory(sides[j], HC.TEMPLATE_CATEGORIES[i])
        end  
    end
    self:T("HC:InitGroupTemplates: done")
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
    chief:SetLimitMission(6, AUFTRAG.Type.CAPTUREZONE)
    chief:SetLimitMission(2, AUFTRAG.Type.OPSTRANSPORT)
    chief:SetLimitMission(10, "Total")
    chief:SetStrategy(CHIEF.Strategy.TOTALWAR)
    chief:SetTacticalOverviewOn()
    chief:SetVerbosity(4)
    chief:SetDetectStatics(true)
    function chief:OnAfterZoneLost(from, event, to, opszone)
        self:T("Zone lost")
    end

    function chief:OnAfterZoneCaptured(from, event, to, opszone)
        self:T("Zone captured")
    end

    function chief:OnAfterZoneEmpty(from, event, to, opszone)
        self:T("Zone empty")
        --zone neutralized, send troops to capture it
        --possible scenario
        --find closest friendly airbase to neutralized zone, create OPSTRANSPORT
    end
    

    function chief:OnAfterMissionAssign(From, Event, To, Mission, Legions)
        self:T("OnAfterMissionAssign")
        --mission:SetRoe(ENUMS.ROE.)
    end

    function chief:OnAfterOpsOnMission(From, Event, To, OpsGroup, Mission)
        self:T("OnAfterOpsOnMission")
        --mission:SetRoe(ENUMS.ROE.)
    end

    self[string.upper(side)].CHIEF = chief
    --return chief
end   

--Creates army brigade and an airwing at specified base and warehouse and provides them to chief
function HC:PopulateBase(warehouse, ab)
    self:T("HC:InitBaseUnits Creating base units")    
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
            self:T(string.format("Spawned base security %s at %s", grp:GetName(), ab:GetName()))
        end
        )
        :InitRandomizeTemplate(templates.BASE_SECURITY)
        :InitRandomizeZones( childZones )
        local bsGroup = baseSecurity:Spawn()
        chief:AddAgent(bsGroup)
    else
        self:W(string.format("No child spawn zones found at %s , base will not be defended", ab:GetName()))
    end
    --Generate units stationed at base and add them to chief    
    --Ground units
    local brigade=BRIGADE:New(warehouse:GetName(), side.." brigade "..ab:GetName())
    for i=1, #(templates.LIGHT_INFANTRY) do
        local platoon = PLATOON:New(templates.LIGHT_INFANTRY[i], 5, string.format("%s Infantry %d %s", side, i, ab:GetName()))
        platoon:SetGrouping(4)
        platoon:AddMissionCapability({AUFTRAG.Type.CONQUER, AUFTRAG.Type.CAPTUREZONE, AUFTRAG.Type.ONGURAD}, 70)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK,}, 50)
        platoon:AddMissionCapability({AUFTRAG.Type.PATROLZONE}, 50)
        platoon:SetAttribute(GROUP.Attribute.GROUND_INFANTRY)
        platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    for i=1, #(templates.MECHANIZED) do
        local platoon = PLATOON:New(templates.MECHANIZED[i], 5, string.format("%s Mechanized inf %d %s", side,i, ab:GetName()))
        platoon:SetGrouping(4)
        platoon:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.PATROLZONE,  AUFTRAG.Type.CAPTUREZONE}, 80)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.CONQUER, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK}, 80)
        platoon:SetAttribute(GROUP.Attribute.GROUND_IFV)
        platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    for i=1, #(templates.TANK) do
        local platoon = PLATOON:New(templates.TANK[i], 5, string.format("%s Tank %d %s", side, i, ab:GetName()))
        platoon:SetGrouping(4)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.CONQUER, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK,  AUFTRAG.Type.CAPTUREZONE}, 90)
        platoon:AddMissionCapability({AUFTRAG.Type.PATROLZONE}, 40)
        platoon:SetAttribute(GROUP.Attribute.GROUND_TANK)
        platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    brigade:SetSpawnZone(ab.AirbaseZone)
    chief:AddBrigade(brigade)
    
    --Air units
    local FIGHTER_TASKS = {AUFTRAG.Type.CAP, AUFTRAG.Type.ESCORT, AUFTRAG.Type.GCICAP, AUFTRAG.Type.INTERCEPT}
    local STRIKER_TASKS = {AUFTRAG.Type.CAS, AUFTRAG.Type.STRIKE, AUFTRAG.Type.BAI, AUFTRAG.Type.CASENHANCED}
    local HELI_TRANSPORT_TASKS = {AUFTRAG.Type.TROOPTRANSPORT, AUFTRAG.Type.CARGOTRANSPORT, AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.RESCUEHELO, AUFTRAG.Type.CTLD}

    local airwing=AIRWING:New(warehouse:GetName(), string.format("%s Air wing %s", side, ab:GetName()))
    --airwing:SetTakeoffHot()
    airwing:SetTakeoffAir()
    airwing:SetDespawnAfterHolding(true)
    airwing:SetAirbase(ab)
    airwing:SetRespawnAfterDestroyed(7200) --two hours to respawn if destroyed
    for i=1, #(templates.TRANSPORT_HELI) do
            local squadron=SQUADRON:New(templates.TRANSPORT_HELI[i], 3, string.format("%s Helicopter Transport Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
            squadron:SetGrouping(2) -- Two aircraft per group.
            squadron:SetModex(60)  -- Tail number of the sqaud start with 130, 131,...
            squadron:AddMissionCapability( HELI_TRANSPORT_TASKS, 90) -- The missions squadron can perform
            squadron:SetMissionRange(40) -- Squad will be considered for targets within 200 NM of its airwing location.
            squadron:SetAttribute(GROUP.Attribute.AIR_TRANSPORTHELO)
            --Time to get ready again, time to repair per life point taken
            squadron:SetTurnoverTime(10, 0)
            airwing:NewPayload(GROUP:FindByName(templates.TRANSPORT_HELI[i]), 20, HELI_TRANSPORT_TASKS) --20 sets of armament
            airwing:AddSquadron(squadron)
    end
        for i=1, #(templates.ATTACK_HELI) do
            local squadron=SQUADRON:New(templates.ATTACK_HELI[i], 3, string.format("%s Attack Helicopter Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
            squadron:SetGrouping(2) -- Two aircraft per group.
            squadron:SetModex(60)  -- Tail number of the sqaud start with 130, 131,...
            squadron:AddMissionCapability( {AUFTRAG.Type.CAS, AUFTRAG.Type.CASENHANCED}, 80) -- The missions squadron can perform
            squadron:SetMissionRange(40) -- Squad will be considered for targets within 200 NM of its airwing location.
            squadron:SetAttribute(GROUP.Attribute.AIR_ATTACKHELO)
            squadron:SetTurnoverTime(10, 0)
            airwing:NewPayload(GROUP:FindByName(templates.ATTACK_HELI[i]), 20, {AUFTRAG.Type.CAS, AUFTRAG.Type.CASENHANCED}) --20 sets of armament), 20,  {AUFTRAG.Type.CAS}) --20 sets of armament
            airwing:AddSquadron(squadron)
    end
    --Fixed wing assets only for airfields, FARPS have only helicopters (and possibly VTOLs)
    -- if(ab:GetCategory() == Airbase.Category.AIRDROME) then
    --     for i=1, #(templates.CAP) do
    --             local squadron=SQUADRON:New(templates.CAP[i], 3, string.format("%s Fighter Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
    --             squadron:SetGrouping(2) -- Two aircraft per group.
    --             squadron:SetModex(10)  -- Tail number of the sqaud start with 130, 131,...
    --             squadron:AddMissionCapability(FIGHTER_TASKS, 90) -- The missions squadron can perform
    --             squadron:SetMissionRange(80) -- Squad will be considered for targets within 200 NM of its airwing location.
    --             squadron:SetTurnoverTime(10, 0)
    --             airwing:NewPayload(GROUP:FindByName(templates.CAP[i]), 20, FIGHTER_TASKS) --20 sets of armament
    --             airwing:AddSquadron(squadron)
    --     end
    --     for i=1, #(templates.CAS) do
    --             local squadron=SQUADRON:New(templates.CAS[i], 3, string.format("%s Attack Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
    --             squadron:SetGrouping(2) -- Two aircraft per group.
    --             squadron:SetModex(30)  -- Tail number of the sqaud start with 130, 131,...
    --             squadron:AddMissionCapability(STRIKER_TASKS, 90) -- The missions squadron can perform
    --             squadron:SetMissionRange(80) -- Squad will be considered for targets within 200 NM of its airwing location.
    --             squadron:SetTurnoverTime(10, 0)
    --             airwing:NewPayload(GROUP:FindByName(templates.CAS[i]), 20, STRIKER_TASKS) --20 sets of armament
    --             airwing:AddSquadron(squadron)
    --     end
    --     for i=1, #(templates.STRIKE) do
    --             local squadron=SQUADRON:New(templates.STRIKE[i], 3, string.format("%s Strike Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
    --             squadron:SetGrouping(2) -- Two aircraft per group.
    --             squadron:SetModex(50)  -- Tail number of the sqaud start with 130, 131,...
    --             squadron:AddMissionCapability(STRIKER_TASKS, 90) -- The missions squadron can perform
    --             squadron:SetMissionRange(80) -- Squad will be considered for targets within 200 NM of its airwing location.
    --             squadron:SetTurnoverTime(10, 0)
    --             airwing:NewPayload(GROUP:FindByName(templates.STRIKE[i]), 20, STRIKER_TASKS) --20 sets of armament
    --             airwing:AddSquadron(squadron)
    --     end
    --         for i=1, #(templates.SEAD) do
    --             local squadron=SQUADRON:New(templates.SEAD[i], 3, string.format("%s SEAD Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
    --             squadron:SetGrouping(2) -- Two aircraft per group.
    --             squadron:SetModex(60)  -- Tail number of the sqaud start with 130, 131,...
    --             squadron:AddMissionCapability({AUFTRAG.Type.SEAD}, 90) -- The missions squadron can perform
    --             squadron:SetMissionRange(120) -- Squad will be considered for targets within 200 NM of its airwing location.
    --             squadron:SetTurnoverTime(10, 0)
    --             airwing:NewPayload(GROUP:FindByName(templates.SEAD[i]), 20, {AUFTRAG.Type.SEAD}) --20 sets of armament
    --             squadron:SetVerbosity(3)                
    --             airwing:AddSquadron(squadron)
    --     end
    --end    
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
    local ResourceOccupied, resourcesTanks = chief:CreateResource(AUFTRAG.Type.ONGUARD, 0, 1, GROUP.Attribute.GROUND_TANK)
    chief:AddToResource(ResourceOccupied, AUFTRAG.Type.CASENHANCED, 0, 1)
    local ResourceEmpty, resourceInf=chief:CreateResource(AUFTRAG.Type.ONGUARD, 1, 1, GROUP.Attribute.GROUND_INFANTRY)
    
    -- Add a transport to the infantry resource. We want at least one and up to two transport helicopters.
    chief:AddTransportToResource(resourceInf, 1, 4, {GROUP.Attribute.AIR_TRANSPORTHELO})
    --chief:AddTransportToResource(resourceInf, 1, 1, AUFTRAG.Type.TROOPTRANSPORT)

    -- Add stratetic zone with customized reaction.
    chief:SetStrategicZoneResourceEmpty(zone, ResourceEmpty)
    chief:SetStrategicZoneResourceOccupied(zone, ResourceOccupied)
end    


function HC:InitAirbases()
    self:T("HC:InitAirbases()")
    local airbases = AIRBASE.GetAllAirbases()
    for i=1, #(airbases) do
        local ab = airbases[i]
        local side = string.upper(ab:GetCoalitionName())  
        self:T("Initializing base "..ab:GetName()..", coalition "..ab:GetCoalitionName()..", category "..ab:GetCategoryName())
        local opsZone = OPSZONE:New(ab.AirbaseZone, ab:GetCoalition())
        --opsZone:Start()
        --If airbase is not neutral      
        if(ab:GetCoalition() ~= coalition.side.NEUTRAL) then --do not place warehouses on neutral bases
            local side = string.upper(ab:GetCoalitionName())        
            local warehouseName = side.."_WAREHOUSE_"..ab:GetName()
            --Check if we already have a warehouse
            local warehouse = STATIC:FindByName(warehouseName, false)
            opsZone:SetDrawZone(false)
            if( warehouse) then
                self:W(string.format("Warehouse %s on %s already exists!", warehouseName, ab:GetName()))
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
                    self:T(string.format("Spawning warehouse on %s in zone %s", ab:GetName(), whSpawnZone:GetName()))
                else
                    self:T(string.format("No defined child spawn zones found, spawning warehouse on %s in AirbaseZone", ab:GetName(), ab:GetName()))
                end
                position = whSpawnZone:GetPointVec2()
                warehouse = whspawn:SpawnFromCoordinate(position, nil, warehouseName)
            end
            self:PopulateBase(warehouse, ab)
            --after spawning units set capture only by units?
            --opsZone:SetObjectCategories({Object.Category.UNIT, Object.Category.STATIC})
            opsZone:SetObjectCategories({Object.Category.UNIT})
            HC.RED.CHIEF:AddStrategicZone(opsZone, nil, 2, {},{})
            self:SetChiefStrategicZoneBehavior(HC.RED.CHIEF, opsZone)            

            -- TESTING --
            -- local resourceOccupied, resourceTank = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_TANK)
            -- local attackHelos = HC.BLUE.CHIEF:AddToResource(resourceOccupied, AUFTRAG.Type.CASENHANCED, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
            -- local infantry = HC.BLUE.CHIEF:AddToResource(resourceOccupied, AUFTRAG.Type.ONGUARD, 1, 2, GROUP.Attribute.GROUND_INFANTRY)
            -- HC.BLUE.CHIEF:AddTransportToResource(infantry, 1, 2, {GROUP.Attribute.AIR_TRANSPORTHELO})

            local resourceOccupied, helos = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.CASENHANCED, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
            --local attackMission = helos.mission --AUFTRAG
            --attackMission:SetMissionAltitude(1000)

            local resourceEmpty, emptyInfantry = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.ONGUARD, 1, 2, GROUP.Attribute.GROUND_INFANTRY)
            local transportHelo = HC.BLUE.CHIEF:AddTransportToResource(emptyInfantry, 2, 4, {GROUP.Attribute.AIR_TRANSPORTHELO})
            --local transportMision = transportHelo.mission
            --transportMision:SetAltitude(1000)
            HC.BLUE.CHIEF:AddStrategicZone(opsZone, nil, nil, resourceOccupied, resourceEmpty)
        end

    end
end

--load saved data
--returns bool success (true if operation was successful, false otherwise), table - json file data as Lua table
function HC:LoadTable(filename)
    --Check io
    if not io then
        self:E("ERROR: io not desanitized. Can't save current file.")
        return false, nil
    end
    -- Check file name.
    if filename == nil then
        self:E("Filename must be specified")
        return false, nil
    end
    
    local f = io.open(filename, "rb")
    if(f == nil) then
        self:E("Could not open file '"..filename.."'")
        return false, nil
    end        
    local content = f:read("*all")
    f:close()
    local tbl = assert(JSON.decode(content), "Couldn't decode JSON data from file "..filename)
    UTILS.TableShow(tbl)
    return true, tbl
end

--save lua table to JSON file
--returns bool true if successful, false otherwise
function HC:SaveTable(table, filename)
    --Check io
    if not io then
        self:E("ERROR: io not desanitized. Can't save current file.")
        return false
    end
    -- Check file name.
    if filename == nil then
        self:E("Filename must be specified")
        return false
    end
    if (table == nil) then
        self:E("Table is nil")
        return false
    end        
    local json = assert(JSON.encode(table),"Couldn't encode Lua table")
    local f = assert(io.open(filename, "wb"))
    if (f == nil) then
        self:E("File open failed on file "..filename)
        return false
    end        
    f:write(json)
    f:close()
end

--Checks if file FileExists
--returns true if file exists
function HC:FileExists(filename)
    --Check io
    if not io then
        self:E("ERROR: io not desanitized. Can't save current file.")
        return false
    end
    local f=io.open(filename, "r")
    if f~=nil then
      io.close(f)
      return true
    else
      return false
    end
end

AIRBASEINFO = {
    AirbaseID = nil,
    Name = nil,
    HP = 100,
    Coalition = coalition.side.NEUTRAL,
    MarkId = nil
}
--airbase - MOOSE AIRBASE object
--hp - airbase state 0-100 with 100 being 100% operational
function AIRBASEINFO:NewFromAIRBASE(airbase, hp)
    self.AirbaseID = airbase.AirbaseID
    self.Name = airbase:GetName()
    self.HP = hp or 100
    self.Coalition = airbase:GetCoalition()
    self.MarkId = nil
    return self
end

function AIRBASEINFO:NewFromTable(table)
    self.AirbaseID = table.AirbaseID
    self.Name = table.Name
    self.HP = table.HP
    self.Coalition = table.Coalition
    self.MarkId = nil --Markers are dynamic, created in runtime
    return self
end   

function AIRBASEINFO:GetTable()
    return {
        AirbaseID = self.AirbaseID,
        Name = self.Name,
        HP = self.HP,
        Coalition = self.Coalition,
        MarkId = self.MarkId
    }
end

function AIRBASEINFO:DrawInfo()
    local colorFill = {1,0,0}
    local fillAlpha = 0.5
    local colorText = {1,1,1}
    local textAlpha = 1
    local textSize = 14
    local ab = AIRBASE:FindByID(self.AirbaseID)
    local coord = ab:GetCoordinate()
    if (self.Coalition == coalition.side.RED) then
        colorFill = {1,0,0}
    elseif (self.Coalition == coalition.side.BLUE) then
        colorFill = {0,0,1}
    else
        colorFill = {1,1,1}
        colorText = {0.2,0.2,0.2}
    end
    if(self.MarkId ~= nil) then
        --env.info("Removing mark "..self.MarkId)
        --coord:RemoveMark(self.MarkId)
    end
    local HPIndicator =""
    for i=1, math.floor(self.HP/10) do
        HPIndicator = HPIndicator.."█"
        --HPIndicator = HPIndicator.."+"
    end
    for i=1, 10 - math.floor(self.HP/10) do
        HPIndicator = HPIndicator.."░"
        --HPIndicator = HPIndicator.."_"
    end
    HPIndicator = HPIndicator.." "..tostring(self.HP).." %"
    env.info(HPIndicator.. " " ..tostring(self.HP))
    self.MarkId = coord:TextToAll(" "..ab:GetName().." \n "..HPIndicator.." \n", coalition.side.ALL, colorText, textAlpha, colorFill, fillAlpha, textSize, true)
end    

function HC:InitCampaignState()
    self:T("InitCampaignState")
    for i=1, #(self.ActiveAirbases) do
        local abInfo = self.ActiveAirbases[i]
        local ab = AIRBASE:FindByID(abInfo.AirbaseID)
        ab:SetCoalition(abInfo.Coalition)
        local side = string.upper(ab:GetCoalitionName())  
        self:T("Initializing base "..ab:GetName()..", coalition "..ab:GetCoalitionName()..", category "..ab:GetCategoryName())
        abInfo:DrawInfo()
        --local opsZone = OPSZONE:New(ab.AirbaseZone, ab:GetCoalition())
        --opsZone:Start()
        --If airbase is not neutral      
        -- if(ab:GetCoalition() ~= coalition.side.NEUTRAL) then --do not place warehouses on neutral bases
        --     local side = string.upper(ab:GetCoalitionName())        
        --     local warehouseName = side.."_WAREHOUSE_"..ab:GetName()
        --     --Check if we already have a warehouse
        --     local warehouse = STATIC:FindByName(warehouseName, false)
        --     opsZone:SetDrawZone(false)
        --     if( warehouse) then
        --         self:W(string.format("Warehouse %s on %s already exists!", warehouseName, ab:GetName()))
        --     else
        --         local airbaseCategory = ab:GetCategory() --to be used later for disstinct setup Airbase vs FARP
        --         --spawn a warehouse
        --         local childZones = self:GetChildZones(ab.AirbaseZone)
        --         local childZonesCount = #(childZones)
        --         local whspawn = SPAWNSTATIC:NewFromStatic(side.."_WAREHOUSE_TEMPLATE")   
        --         local position = ab:GetZone():GetRandomPointVec2()
        --         local whSpawnZone = ab.AirbaseZone
        --         if(childZonesCount > 0) then
        --             whSpawnZone = childZones[math.random(childZonesCount)]
        --             self:T(string.format("Spawning warehouse on %s in zone %s", ab:GetName(), whSpawnZone:GetName()))
        --         else
        --             self:T(string.format("No defined child spawn zones found, spawning warehouse on %s in AirbaseZone", ab:GetName(), ab:GetName()))
        --         end
        --         position = whSpawnZone:GetPointVec2()
        --         warehouse = whspawn:SpawnFromCoordinate(position, nil, warehouseName)
        --     end
        --     self:PopulateBase(warehouse, ab)
        --     --after spawning units set capture only by units?
        --     --opsZone:SetObjectCategories({Object.Category.UNIT, Object.Category.STATIC})
        --     opsZone:SetObjectCategories({Object.Category.UNIT})
        --     HC.RED.CHIEF:AddStrategicZone(opsZone, nil, 2, {},{})
        --     self:SetChiefStrategicZoneBehavior(HC.RED.CHIEF, opsZone)            

        --     -- TESTING --
        --     -- local resourceOccupied, resourceTank = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_TANK)
        --     -- local attackHelos = HC.BLUE.CHIEF:AddToResource(resourceOccupied, AUFTRAG.Type.CASENHANCED, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
        --     -- local infantry = HC.BLUE.CHIEF:AddToResource(resourceOccupied, AUFTRAG.Type.ONGUARD, 1, 2, GROUP.Attribute.GROUND_INFANTRY)
        --     -- HC.BLUE.CHIEF:AddTransportToResource(infantry, 1, 2, {GROUP.Attribute.AIR_TRANSPORTHELO})

        --     local resourceOccupied, helos = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.CASENHANCED, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
        --     --local attackMission = helos.mission --AUFTRAG
        --     --attackMission:SetMissionAltitude(1000)

        --     local resourceEmpty, emptyInfantry = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.ONGUARD, 1, 2, GROUP.Attribute.GROUND_INFANTRY)
        --     local transportHelo = HC.BLUE.CHIEF:AddTransportToResource(emptyInfantry, 2, 4, {GROUP.Attribute.AIR_TRANSPORTHELO})
        --     --local transportMision = transportHelo.mission
        --     --transportMision:SetAltitude(1000)
        --     HC.BLUE.CHIEF:AddStrategicZone(opsZone, nil, nil, resourceOccupied, resourceEmpty)
        --end

    end
end

function HC:DeleteLabels()
    for i=1, #HC.ActiveAirbases do
        local a = HC.ActiveAirbases[i]
        local ab = AIRBASE:FindByID(a.AirbaseID)
        self:T("Removing marker "..a.MarkId)
        ab:GetCoordinate():RemoveMark(a.MarkId)
    end
end 

function HC:Start()
    local basePath = lfs.writedir().."Missions\\havechips\\"
    local filename = "airbases.json"
    if(not self:FileExists(basePath..filename)) then
        --First mission run in campaign, build a list of POIs (Airbases and FARPs) which have RED/BLUE ownership set
        --everything else will be ignored
        self:T("Initializing campaign")
        local airbases = AIRBASE.GetAllAirbases()
        for i=1, #(airbases) do
            local ab = airbases[i]
            if(ab:GetCoalition() ~= coalition.side.NEUTRAL) then
                --RED and BLUE bases will be considered as strategic zones, everything else will be ignored
                local abi = AIRBASEINFO:NewFromAIRBASE(ab, 100)
                table.insert(self.ActiveAirbases, abi)
            end
        end
        --save to file
        HC:SaveTable(self.ActiveAirbases, basePath..filename)
    else
        --Campaign is in progress, we have saved data
        self:T("Loading campaign progress")
        local success = false
        local data = {}
        success, data = HC:LoadTable(basePath..filename)        
        if(success) then
            self:T("Table loaded from file "..basePath..filename)
            for i=1, #data do
                table.insert(self.ActiveAirbases, AIRBASEINFO:NewFromTable(data[i]))
            end
        else
            self:W("Could not load table from file "..basePath..filename)
        end
    end
    --Now we have a table of active airbases, we can now populate those airbases
    --set their coalition and state of combat effectivenes
    self:InitCampaignState()
end

function HC:EndMission()
    --ToDo: save state
end

HC:InitGroupTemplates()
HC:CreateChief("red", "Zhukov")
HC:CreateChief("blue", "McArthur")
--HC:Start()

--HC:InitAirbases()
--HC.RED.CHIEF:__Start(1)
--HC.BLUE.CHIEF:__Start(1)
