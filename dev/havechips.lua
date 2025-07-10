JSON = loadfile(lfs.writedir().."Missions\\havechips\\lib\\json.lua")()

HC = {
    VERSION=0.1,
    RED = { 
        TEMPLATES = {},
        INVENTORY_TEMPLATES = {
            MAIN = nil,
            FRONTLINE = nil,
            FARP = nil
        }
    },
    BLUE = {
        TEMPLATES = {},
        INVENTORY_TEMPLATES = {
            MAIN = nil,
            FRONTLINE = nil,
            FARP = nil
        }
    },
    TEMPLATE_CATEGORIES = {"SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "ATTACK_HELI", "TRANSPORT_HELI", "BASE_SECURITY", "SAM"},
    ActiveAirbases = {},
    RESUPPLY_TIMER = nil,
    AIRBASE_LABELS = {}

}

--Write trace message to log
--@param #string message Message text
function HC:T(message)
    env.info("[HaveChips] "..message)
end

--Write warning message to log
--@param #string message Message text
function HC:W(message)
    env.warning("[HaveChips] "..message)
end

--Write error message to log
--@param #string message Message text
function HC:E(message)
    env.error("[HaveChips] "..message)
end

--Gets all template group names for side of missionType (or unit category), method is used internally
--currently TEMPLATE_CATEGORIES {"SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "SAM", "ATTACK_HELI", "TRANSPORT_HELI"}
--@param #string side "RED" or "BLUE"
--@param #string missionType Template zone name part. Pattern is <SIDE>_<missionType>_TEMPLATES, see template zones in mission editor, possible values "SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "SAM", "ATTACK_HELI", "TRANSPORT_HELI"
function HC:GetTemplateGroupNames(side, missionType)    
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

--Initializes the templates structure for Airwings and platoons
function HC:InitGroupTemplates()
    self:T("Initializing group templates")
    local sides = {"RED", "BLUE"}
    for j=1, #(sides) do        
        for i=1,#(HC.TEMPLATE_CATEGORIES) do
            self[string.upper(sides[j])].TEMPLATES[HC.TEMPLATE_CATEGORIES[i]] = self:GetTemplateGroupNames(sides[j], HC.TEMPLATE_CATEGORIES[i])
        end  
    end
    self:T("Group templates initialized")
end

--Checks if an airbase is close to frontline
--@param airbase #AIRBASE Airbase to check
function HC:IsFrontlineAirbase(airbase)
    local FRONTLINE_DISTANCE = 50000 --distance in meters, if an enemy airbase or farp is at or closer than FRONTLINE_DISTANCE, airbase is considered a frontline airbase
    local coord = airbase:GetCoordinate()
    local enemySide = nil
    if (airbase:GetCoalition() == coalition.side.NEUTRAL) then
        return false
    end        
    if(airbase:GetCoalition() == coalition.side.RED) then
        enemySide = "blue"
    else
        enemySide = "red"
    end
    local enemyBases = SET_AIRBASE:New():FilterCoalitions(enemySide):FilterOnce()
    -- enemyBases:ForEachAirbase(
    --     function(b)
    --         env.info("Base in filtered set "..enemySide.." "..b:GetCoalitionName().." "..b:GetName())
    --     end
    -- )
    local closestEnemyBase = enemyBases:FindNearestAirbaseFromPointVec2(coord) --this just doesn't work
    local dist = coord:Get2DDistance(closestEnemyBase:GetCoordinate())
    return dist <= 50000
end

--Initializes inventory templates for airbases, frontline airbases and FARPS
--Inventory templates are defined by static cargo objects with names 
--<SIDE>_MAIN_INVENTORY for "major" airbases
--<SIDE>_FRONTLINE_INVENTORY for "frontline" airbases
--<SIDE>_FARP_INVENTORY for FARPS
function HC:InitInventoryTemplates()
    self:T("Initializing inventory templates")
    HC.RED.INVENTORY_TEMPLATES.MAIN = STATIC:FindByName("RED_MAIN_INVENTORY"):GetStaticStorage()
    HC.RED.INVENTORY_TEMPLATES.FRONTLINE = STATIC:FindByName("RED_FRONTLINE_INVENTORY"):GetStaticStorage()
    HC.RED.INVENTORY_TEMPLATES.FARP = STATIC:FindByName("RED_FARP_INVENTORY"):GetStaticStorage()
    HC.BLUE.INVENTORY_TEMPLATES.MAIN = STATIC:FindByName("BLUE_MAIN_INVENTORY"):GetStaticStorage()
    HC.BLUE.INVENTORY_TEMPLATES.FRONTLINE = STATIC:FindByName("BLUE_FRONTLINE_INVENTORY"):GetStaticStorage()
    HC.BLUE.INVENTORY_TEMPLATES.FARP = STATIC:FindByName("BLUE_FARP_INVENTORY"):GetStaticStorage()
    self:T("Inventory templates initialized")
end    

--Creates MOOSE CHIEF object
--@param #string side "RED" or "BLUE"
--@param #string alias Chief name (optional)
--@return #CHIEF MOOSE CHIEF object
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
    chief:SetVerbosity(5)
    chief:SetDetectStatics(true)
    function chief:OnAfterZoneLost(from, event, to, opszone)
        HC:W("Zone is now lost")
    end

    function chief:OnAfterZoneCaptured(from, event, to, opszone)
        HC:W("Zone is now captured")
    end

    function chief:OnAfterZoneEmpty(from, event, to, opszone)
        HC:W("Zone is now empty")
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

    --self[string.upper(side)].CHIEF = chief
    return chief
end   
--Returns a list of zones which are inside specified "parent" zone
--Function is used to find a pre-determined spawn locations around bases
--@param #string zone Parent zone name
--@return #table table of child zones
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

--Checks if file specified by filename path exists
--@param filename Filename path
--@return #bool true if file exists
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

--load saved data from file
--@param filename - filename path to load from
---@return bool success (true if operation was successful, false otherwise), table - json file data as Lua table
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
--@return bool true if operation was successful, false otherwise
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

--Sets CHIEF response to strategic zone empty and occupied
--@param #CHIEF chief
--@param #OPSZONE strategic zone
function HC:SetChiefStrategicZoneBehavior(chief, zone)
    --- Create a resource list of mission types and required assets for the case that the zone is OCCUPIED.
    -- local ResourceOccupied, resourcesTanks = chief:CreateResource(AUFTRAG.Type.ONGUARD, 0, 1, GROUP.Attribute.GROUND_TANK)
    -- chief:AddToResource(ResourceOccupied, AUFTRAG.Type.CASENHANCED, 0, 1)
    -- local ResourceEmpty, resourceInf=chief:CreateResource(AUFTRAG.Type.ONGUARD, 1, 1, GROUP.Attribute.GROUND_INFANTRY)
    
    -- -- Add a transport to the infantry resource. We want at least one and up to two transport helicopters.
    -- chief:AddTransportToResource(resourceInf, 1, 4, {GROUP.Attribute.AIR_TRANSPORTHELO})

    -- -- Add stratetic zone with customized reaction.
    -- chief:SetStrategicZoneResourceEmpty(zone, ResourceEmpty)
    -- chief:SetStrategicZoneResourceOccupied(zone, ResourceOccupied)

        --local resourceOccupied, helos = chief:CreateResource(AUFTRAG.Type.CASENHANCED, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
        local resourceOccupied = {}
        local resourceEmpty, emptyInfantry = chief:CreateResource(AUFTRAG.Type.ONGUARD, 1, 2, GROUP.Attribute.GROUND_INFANTRY)
        local transportHelo = chief:AddTransportToResource(emptyInfantry, 2, 4, GROUP.Attribute.AIR_TRANSPORTHELO)
        chief:AddToResource(resourceEmpty, AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_APC)
        chief:SetStrategicZoneResourceEmpty(zone, resourceEmpty)
        chief:SetStrategicZoneResourceOccupied(zone, resourceOccupied)

end    

--This class is used to persist airbase state between server restarts
AIRBASEINFO = {
    Name = nil,
    HP = 100, --HP indicates the base overall operational capacity with 100% being 100% operational
    Coalition = coalition.side.NEUTRAL,
    MarkId = nil
}

function AIRBASEINFO:GetTable()
    return {
        Name = self.Name,
        HP = self.HP,
        Coalition = self.Coalition,
        MarkId = self.MarkId
    }
end

function AIRBASEINFO:DrawLabel()
    local BLUE_COLOR_FARP = {0.2,0.2,1}
    local BLUE_COLOR_AIRBASE = {0,0,1}
    local RED_COLOR_FARP = {1,0.2,0.2}
    local RED_COLOR_AIRBASE = {0.8,0,0}
    local COLOR_MAIN_BASE_TEXT = {1,1,1}
    local COLOR_FARP_FRONTLINE_TEXT = {1,1,1}
    local colorFill = {1,0,0}
    local fillAlpha = 0.85
    local colorText = {1,1,1}
    local textAlpha = 1
    local textSize = 14
    local ab = AIRBASE:FindByName(self.Name)
    local coord = ab:GetCoordinate()
    if(not HC:IsFrontlineAirbase(ab) and ab:GetCategory() == Airbase.Category.AIRDROME) then
        colorText = COLOR_MAIN_BASE_TEXT
    else
        colorText = COLOR_FARP_FRONTLINE_TEXT
    end
    if (ab:GetCoalition() == coalition.side.RED) then
        if(ab:GetCategory() == Airbase.Category.AIRDROME) then
            colorFill = RED_COLOR_AIRBASE
        else
            colorFill = RED_COLOR_FARP
        end
    elseif (self.Coalition == coalition.side.BLUE) then
        if(ab:GetCategory() == Airbase.Category.AIRDROME) then
            colorFill = BLUE_COLOR_AIRBASE
        else
            colorFill = BLUE_COLOR_FARP
        end
    else
        colorFill = {1,1,1}
        colorText = {0.2,0.2,0.2}
    end
    if(not HC:IsFrontlineAirbase(ab) and ab:GetCategory() == Airbase.Category.AIRDROME) then
        colorText = {1, 1,0.5}
    end
    if(self.MarkId ~= nil) then
        --env.info("Removing mark "..self.MarkId)
        coord:RemoveMark(self.MarkId)
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
    self.MarkId = coord:TextToAll(" "..ab:GetName().." \n "..HPIndicator.." \n", coalition.side.ALL, colorText, textAlpha, colorFill, fillAlpha, textSize, true)
end 

--airbase - MOOSE AIRBASE object
--hp - airbase state 0-100 with 100 being 100% operational
function AIRBASEINFO:NewFromAIRBASE(airbase, hp)
    local o = {}
    o.Name = airbase:GetName()
    o.HP = hp or 100
    o.Coalition = airbase:GetCoalition()
    o.MarkId = nil
    setmetatable(o, self)
    self.__index = self
    return o
end

function AIRBASEINFO:NewFromTable(table)
    local o = {}
    o.Name = table.Name
    o.HP = table.HP
    o.Coalition = table.Coalition
    o.MarkId = table.MarkId
    setmetatable(o, self)
    self.__index = self
    return o
end    

--Check if base is close to frontline
--@return #bool true if base is close to front line
function AIRBASEINFO:IsFrontline()
    local ab = AIRBASE:FindByName(self.Name)
    return HC:IsFrontlineAirbase(ab)
end


--Creates army brigade and an airwing at specified base and warehouse and provides them to chief
function HC:PopulateBase(warehouse, ab, hp, isFrontline)
    self:T("Populating base "..ab:GetName())    
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
        :OnSpawnGroup(
            function(grp)
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
        local platoon = PLATOON:New(templates.LIGHT_INFANTRY[i], 4, string.format("%s Infantry %d %s", side, i, ab:GetName()))
        platoon:SetGrouping(4)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.ONGURAD}, 70)
        -- platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK,}, 50)
        -- platoon:AddMissionCapability({AUFTRAG.Type.PATROLZONE}, 50)
        platoon:SetAttribute(GROUP.Attribute.GROUND_INFANTRY)
        --platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    for i=1, #(templates.MECHANIZED) do
        local platoon = PLATOON:New(templates.MECHANIZED[i], 4, string.format("%s Mechanized inf %d %s", side,i, ab:GetName()))
        platoon:SetGrouping(4)
        platoon:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT, AUFTRAG.Type.PATROLZONE,  AUFTRAG.Type.CAPTUREZONE}, 80)
        platoon:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.CONQUER, AUFTRAG.Type.ARMOREDGUARD, AUFTRAG.Type.ARMORATTACK}, 80)
        platoon:SetAttribute(GROUP.Attribute.GROUND_IFV)
        platoon:SetMissionRange(25)
        brigade:AddPlatoon(platoon)
    end
    for i=1, #(templates.TANK) do
        local platoon = PLATOON:New(templates.TANK[i], 4, string.format("%s Tank %d %s", side, i, ab:GetName()))
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
            local squadron=SQUADRON:New(templates.TRANSPORT_HELI[i], 5, string.format("%s Helicopter Transport Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
            squadron:SetAttribute(GROUP.Attribute.AIR_TRANSPORTHELO)
            squadron:SetGrouping(1) -- Two aircraft per group.
            squadron:SetModex(60)  -- Tail number of the sqaud start with 130, 131,..
            squadron:AddMissionCapability({AUFTRAG.Type.OPSTRANSPORT}, 90)
            --squadron:AddMissionCapability( HELI_TRANSPORT_TASKS, 90) -- The missions squadron can perform
            
            --squadron:SetMissionRange(40) -- Squad will be considered for targets within 200 NM of its airwing location.

            
            --Time to get ready again, time to repair per life point taken
            --squadron:SetTurnoverTime(10, 0)
            --airwing:NewPayload(GROUP:FindByName(templates.TRANSPORT_HELI[i]), 20, HELI_TRANSPORT_TASKS) --20 sets of armament
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
    if(ab:GetCategory() == Airbase.Category.AIRDROME) then
        for i=1, #(templates.CAP) do
                local squadron=SQUADRON:New(templates.CAP[i], 3, string.format("%s Fighter Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2) -- Two aircraft per group.
                squadron:SetModex(10)  -- Tail number of the sqaud start with 130, 131,...
                squadron:AddMissionCapability(FIGHTER_TASKS, 90) -- The missions squadron can perform
                squadron:SetMissionRange(80) -- Squad will be considered for targets within 200 NM of its airwing location.
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.CAP[i]), 20, FIGHTER_TASKS) --20 sets of armament
                airwing:AddSquadron(squadron)
        end
        for i=1, #(templates.CAS) do
                local squadron=SQUADRON:New(templates.CAS[i], 3, string.format("%s Attack Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2) -- Two aircraft per group.
                squadron:SetModex(30)  -- Tail number of the sqaud start with 130, 131,...
                squadron:AddMissionCapability(STRIKER_TASKS, 90) -- The missions squadron can perform
                squadron:SetMissionRange(80) -- Squad will be considered for targets within 200 NM of its airwing location.
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.CAS[i]), 20, STRIKER_TASKS) --20 sets of armament
                airwing:AddSquadron(squadron)
        end
        for i=1, #(templates.STRIKE) do
                local squadron=SQUADRON:New(templates.STRIKE[i], 3, string.format("%s Strike Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2) -- Two aircraft per group.
                squadron:SetModex(50)  -- Tail number of the sqaud start with 130, 131,...
                squadron:AddMissionCapability(STRIKER_TASKS, 90) -- The missions squadron can perform
                squadron:SetMissionRange(80) -- Squad will be considered for targets within 200 NM of its airwing location.
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.STRIKE[i]), 20, STRIKER_TASKS) --20 sets of armament
                airwing:AddSquadron(squadron)
        end
            for i=1, #(templates.SEAD) do
                local squadron=SQUADRON:New(templates.SEAD[i], 3, string.format("%s SEAD Squadron %d %s", side, i, ab:GetName())) --Ops.Squadron#SQUADRON
                squadron:SetGrouping(2) -- Two aircraft per group.
                squadron:SetModex(60)  -- Tail number of the sqaud start with 130, 131,...
                squadron:AddMissionCapability({AUFTRAG.Type.SEAD}, 90) -- The missions squadron can perform
                squadron:SetMissionRange(120) -- Squad will be considered for targets within 200 NM of its airwing location.
                squadron:SetTurnoverTime(10, 0)
                airwing:NewPayload(GROUP:FindByName(templates.SEAD[i]), 20, {AUFTRAG.Type.SEAD}) --20 sets of armament
                squadron:SetVerbosity(3)                
                airwing:AddSquadron(squadron)
        end
    end    
    chief:AddAirwing(airwing) 
end

--Adds static warehouse to airbase (required by MOOSE)
--@param #AIRBASE airbase - MOOSE airbase
--@param AIRBASEINFO abInfo - extended airbase info
function HC:SetupStaticWarehouse(airbase)
    --ToDo: clear zone area
    local side = string.upper(airbase:GetCoalitionName())
    local warehouseName = side.."_WAREHOUSE_"..airbase:GetName()
    --Check if we already have a warehouse
    local warehouse = STATIC:FindByName(warehouseName, false)
    if( warehouse) then
        self:W(string.format("Warehouse %s on %s already exists!", warehouseName, airbase:GetName()))
    else
        --spawn a warehouse
        local childZones = self:GetChildZones(airbase.AirbaseZone)
        local childZonesCount = #(childZones)
        local whspawn = SPAWNSTATIC:NewFromStatic(side.."_WAREHOUSE_TEMPLATE")   
        local position = airbase:GetZone():GetRandomPointVec2()
        local whSpawnZone = airbase.AirbaseZone
        if(childZonesCount > 0) then
            whSpawnZone = childZones[math.random(childZonesCount)]
            self:T(string.format("Spawning warehouse on %s in zone %s", airbase:GetName(), whSpawnZone:GetName()))
        else
            self:T(string.format("No defined child spawn zones found, spawning warehouse on %s in AirbaseZone", airbaseab:GetName(), aairbaseb:GetName()))
        end
        position = whSpawnZone:GetPointVec2()
        warehouse = whspawn:SpawnFromCoordinate(position, nil, warehouseName)
    end
    return warehouse
end

--Sets up airbase inventory, aircraft and weapon availability
--Inventory is configured by modifying template warehouses RED_WAREHOUSE_TEMPLATE, RED_FARP_WAREHOUSE_TEMPLATE, BLUE_WAREHOUSE_TEMPLATE, BLUE_FARP_WAREHOUSE_TEMPLATE 
--@param #AIRBASE airbase to set up
function HC:SetupAirbaseInventory(airbase)
    self:T("Seting up inventory for "..airbase:GetName())
    local targetStorage = STORAGE:FindByName(airbase:GetName())
    local sourceStorage = nil
    local SIDE = string.upper(airbase:GetCoalitionName())
    if(airbase:GetCategory() == Airbase.Category.HELIPAD) then
        sourceStorage = HC[SIDE].INVENTORY_TEMPLATES.FARP
    elseif (airbase:GetCategory() == Airbase.Category.AIRDROME) then
        if(self:IsFrontlineAirbase(airbase)) then
            sourceStorage = HC[SIDE].INVENTORY_TEMPLATES.FRONTLINE
        else
            sourceStorage = HC[SIDE].INVENTORY_TEMPLATES.MAIN
        end            
    else
        self:W("Unknown airbase category ")
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
end

function HC:DeleteLabels()
    for i=1, #HC.ActiveAirbases do
        local a = HC.ActiveAirbases[i]
        local ab = AIRBASE:FindByID(a.AirbaseID)
        self:T("Removing marker "..a.MarkId)
        ab:GetCoordinate():RemoveMark(a.MarkId)
    end
end 

--Loads current campaign state and starts ResumeCampaign() when data is ready
--This is the main entry point to HC
function HC:Start()
    --Initialize group templates, we will need them later
    HC:InitGroupTemplates()
    --Create MOOSE CHIEFS, we will need them later
    HC.RED.CHIEF = HC:CreateChief("red", "Zhukov")
    HC.BLUE.CHIEF = HC:CreateChief("blue", "McArthur")
    --Initialize inventory templates, we will need them later
    HC:InitInventoryTemplates()
    HC.ActiveAirbases ={}
    local basePath = lfs.writedir().."Missions\\havechips\\"
    local filename = "airbases.json"
    if(not self:FileExists(basePath..filename)) then
        --First mission in campaign, build a list of POIs (Airbases and FARPs) which have RED/BLUE ownership set
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
    for i=1, #(self.ActiveAirbases) do
        local abi = self.ActiveAirbases[i]
        local ab = AIRBASE:FindByName(abi.Name)
        ab:SetCoalition(abi.Coalition)
        local isFrontline = self:IsFrontlineAirbase(ab)
        local isFARP = ab:GetCategory() == Airbase.Category.HELIPAD
        --setup base available airframes and weapons based on templates
        self:SetupAirbaseInventory(ab)
        local opsZone = OPSZONE:New(ab.AirbaseZone, ab:GetCoalition())
        opsZone:SetMarkZone(false)
        if(ab:GetCoalition() ~= coalition.side.NEUTRAL) then
            opsZone:SetDrawZone(false)
            local staticWarehouse = self:SetupStaticWarehouse(ab)
            HC:PopulateBase(staticWarehouse, ab, abi.HP, isFrontline)
            opsZone:SetObjectCategories({Object.Category.UNIT}) --after populating the zone, we can set that only units can capture zones
            --abi:DrawLabel()
        end
        ab:SetAutoCaptureON()
        HC.RED.CHIEF:AddStrategicZone(opsZone, nil, 2, {},{})
        HC:SetChiefStrategicZoneBehavior(HC.RED.CHIEF, opsZone)
        --HC.BLUE.CHIEF:AddStrategicZone(opsZone, nil, 2, {},{})
        --HC:SetChiefStrategicZoneBehavior(HC.BLUE.CHIEF, opsZone)

        --local resourceOccupied, helos = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.CASENHANCED, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
        --HC.BLUE.CHIEF:AddToResource(resourceOccupied, AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_IFV)
        local resourceOccupied = {}
        local resourceEmpty, emptyInfantry = HC.BLUE.CHIEF:CreateResource(AUFTRAG.Type.ONGUARD, 2, 2, GROUP.Attribute.GROUND_INFANTRY)
        --HC.BLUE.CHIEF:AddToResource(resourceEmpty, AUFTRAG.Type.CAPTUREZONE, 1, 1, GROUP.Attribute.GROUND_IFV)
        HC.BLUE.CHIEF:AddTransportToResource(emptyInfantry, 1, 2, {GROUP.Attribute.AIR_TRANSPORTHELO})
        --local ifvs = HC.BLUE.CHIEF:AddTransportToResource(emptyInfantry, 1, 2, {GROUP.Attribute.GROUND_IFV})
        --HC.BLUE.CHIEF:AddStrategicZone(opsZone, nil, nil, resourceOccupied, resourceEmpty)
        HC.BLUE.CHIEF:AddStrategicZone(opsZone, nil, nil, resourceOccupied, resourceEmpty)
        --opsZone:Start()
    end
    HC.RESUPPLY_TIMER = TIMER:New(HC.ResupplyTick, HC)
    HC.RESUPPLY_TIMER:Start(5,5)
    self:T("Startup completed")
end

function HC:EndMission()
    --ToDo: save state
end

function HC:SaveCampaignState()
    --ToDo: Save active airbases
end    

--Periodic resupply of all airbases and FARPs
function HC:ResupplyTick()
    self:T("Resupply tick triggered")
    for i=1, #(self.ActiveAirbases) do
        local abi = self.ActiveAirbases[i]
        local ab = AIRBASE:FindByName(abi.Name)
        local opsZone = OPSZONE:FindByName(abi.Name)
        --self:T(string.format("%s airbase: %s opszone: %s", abi.Name, ab:GetCoalitionName(), opsZone:GetOwnerName()))
        abi.Coalition = ab:GetCoalition()
        if(abi.HP < 100) then
            abi.HP = abi.HP + 1
        end
        abi:DrawLabel()
    end        
end    



HC:Start()
HC.BLUE.CHIEF:__Start(1)
--HC.RED.CHIEF:__Start(1)
--HC.BLUE.CHIEF:__Start(10)


