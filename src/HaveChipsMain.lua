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
    BASE_PATH = lfs.writedir().."Missions\\havechips\\", --base filename path
    PERSIST_FILE_NAME = "airbases.json", --file name to save persistence data to
    PASSIVE_RESUPPLY_RATE = 40, --Base HP resupply rate per hour %/hour,
    FRONTLINE_PROXIMITY_THRESHOLD = 50, -- Distance in kilometers, if an airbase is closer than this from nearest enemy airbase it is considered a frontline airbase
    TEMPLATE_CATEGORIES = {"SEAD", "CAP", "STRIKE", "CAS", "SHORAD", "LIGHT_INFANTRY", "MECHANIZED", "TANK", "ATTACK_HELI", "TRANSPORT_HELI", "BASE_SECURITY", "SAM"},
    ActiveAirbases = {},
    SHORT_TICK_TIMER = nil, --reference to timer
    LONG_TICK_TIMER = nil, -- reference to timer
    SHORT_TICK_INTERVAL = 10, --short tick timer interval in seconds 
    LONG_TICK_INTERVAL = 120, --long tick timer interval in seconds 
    OccupiedSpawnZones = {} --keep track of used spawn zones to hopefuly prevent spawning objects on top of each other

}

env.info(string.format("HaveChips %s loading ", HC.VERSION))

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
    HC.ActiveAirbases = {}
    local filename = HC.PERSIST_FILE_NAME
    local wpGroup = GROUP:FindByName("WP_TEMPLATE")
    ----------------------------------------------------------------------------------------------------------
    --                              Initialize campaign state or load progress
    ----------------------------------------------------------------------------------------------------------
    if(not HC:FileExists(HC.BASE_PATH..filename)) then
    --First mission in campaign, build a list of POIs (Airbases and FARPs) which have RED/BLUE ownership set
    --everything else will be ignored
        HC:T("Initializing campaign")
        --we will use a special aircraft group called WP_TEMPLATE to assign waypoint numbers to strategic zones        
        local route = wpGroup:GetTemplateRoutePoints()
        local wpList = {}
        for k, v in pairs(route) do
            table.insert(wpList, k, {x = v.x, y=v.y})
        end
        wpGroup:Destroy() --we don't need it any more, we just wanted waypoints
        --local bases = SET_AIRBASE:New():FilterCoalitions({"red", "blue"}):FilterCategories({Airbase.Category.HELIPAD, Airbase.Category.AIRDROME}):FilterOnce() --get only red and blue, ignore neutral
        local bases = SET_AIRBASE:New():FilterCoalitions({"red", "blue"}):FilterCategories({"helipad", "airdrome"}):FilterOnce() --get only red and blue, ignore neutral
        bases:ForEachAirbase(
            function(b)
                local abi = AIRBASEINFO:NewFromAIRBASE(b, 100)
                for i=1, #wpList do
                    local zone = b.AirbaseZone
                    if (zone:IsVec2InZone(wpList[i])) then
                        abi.WPIndex = i
                        table.insert(HC.ActiveAirbases, abi)
                        HC:T(b:GetName().." assigned index "..tostring(i))
                        break
                    end
                end
            end
        )
        --save to file
        HC:SaveTable(HC.ActiveAirbases, HC.BASE_PATH..filename)
    else
        ----------------------------------------------------------------------------------------------------------------
        --                                Campaign is in progress, we need to load the data
        ----------------------------------------------------------------------------------------------------------------
        wpGroup:Destroy() --we don't need the waypoints template group it anyway, we loaded waypoints from JSON file
        HC:T("Loading campaign progress")
        local success = false
        local data = {}
        success, data = HC:LoadTable(basePath..filename)        
        if(success) then
            HC:T("Table loaded from file "..basePath..filename)
            for i=1, #data do
                --table.insert(HC.ActiveAirbases,AIRBASEINFO:NewFromTable(data[i]))
                HC.ActiveAirbases[data[i].Name] = AIRBASEINFO:NewFromTable(data[i])
            end
        else
            HC:W("Could not load table from file "..basePath..filename)
        end
    end
    ----------------------------------------------------------------------------------------------------------
    --                                      Campaign state loaded
    ----------------------------------------------------------------------------------------------------------
    --Now we have a table of active airbases and we can bring them to life
    --set their coalition and state of combat effectivenes
    for _, abi in pairs(HC.ActiveAirbases) do
        local ab = AIRBASE:FindByName(abi.Name)
        ab:SetCoalition(abi.Coalition)        
        local abZone = ZONE_AIRBASE:New(ab:GetName())
        local opsZone = OPSZONE:New(abZone)   
        opsZone:SetMarkZone(true)
        opsZone:SetDrawZone(true)   
        function opsZone:OnAfterEmpty(From, Event, To)
            HC.OnZoneEmpty(HC, From, Event, To, self)
        end
        local isFrontline = HC:IsFrontlineAirbase(ab)
        local isFARP = ab:GetCategory() == Airbase.Category.HELIPAD
        --setup base available airframes and weapons based on templates
        if(ab:GetCoalition() ~= coalition.side.NEUTRAL) then
            HC:SetupAirbaseInventory(ab)
            --opsZone:SetDrawZone(false)
            -- This is a static object required by MOOSE CHIEF, can be any static )yes, even a cow!)
            local staticWarehouse = HC:SetupAirbaseStaticWarehouse(ab)
            --add AI units to base to be used by CHIEF
            HC:SetupAirbaseChiefUnits(staticWarehouse, ab)
            --spawn base defense units
            HC:SetupAirbaseDefense(ab, abi.HP, isFrontline)
            opsZone:SetObjectCategories({Object.Category.UNIT}) --after populating the zone, we can set that only units can capture zones
            opsZone:SetUnitCategories(Unit.Category.GROUND_UNIT) --and only ground units can capture zone            
            --abi:DrawLabel()
        end
        ab:SetAutoCaptureON()

        --Customize chief's response to strategic zones
        local red_empty, red_occupied = HC:GetChiefZoneResponse(HC.RED.CHIEF)
        HC.RED.CHIEF:AddStrategicZone(opsZone, nil, 2, red_occupied, red_empty)

        local blue_empty, blue_occupied = HC:GetChiefZoneResponse(HC.RED.CHIEF)
        HC.BLUE.CHIEF:AddStrategicZone(opsZone, nil, nil, blue_occupied, blue_empty)
    end

    -- Periodic calls
    HC.SHORT_TICK_TIMER = TIMER:New(HC.OnShortTick, HC)
    HC.SHORT_TICK_TIMER:Start(5,HC.SHORT_TICK_INTERVAL)
    HC.LONG_TICK_TIMER = TIMER:New(HC.OnLongTick, HC)
    HC.LONG_TICK_TIMER:Start(5,HC.LONG_TICK_INTERVAL)
    -- Event handlers
    HC.onKillHandler = EVENTHANDLER:New()
    HC.onKillHandler:HandleEvent( EVENTS.Kill )
    function HC.onKillHandler:OnEventKill(e )
        HC:OnUnitKilled(e)
    end
    HC.BLUE.CHIEF:__Start(1)
    HC:T("Startup completed")
end



function HC:OnZoneEmpty(From, Event, To, opsZone)
    HC:W("*************** ZONE ".."".." IS EMPTY ******************")
    --destroy all statics and set zone to neutral? Maybe?
    --local previousCoalitionName = string.upper(opsZone:GetCoalitionName())
    --opsZone:Captured(coalition.side.NEUTRAL)
    --AIRBASE:FindByName(opsZone:GetName()):SetCoalition(coalition.side.NEUTRAL)
end

function HC:OnUnitKilled(e)
--   Unit.Category
--   AIRPLANE      = 0,
--   HELICOPTER    = 1,
--   GROUND_UNIT   = 2,
--   SHIP          = 3,
--   STRUCTURE     = 4

--Object.Category
--  UNIT    1
--  WEAPON  2
--  STATIC  3
--  BASE    4
--  SCENERY 5
--  Cargo   6

    if (e and e.IniCategory and e.IniCoalition and e.IniTypeName and e.IniObjectCategory
            and e.TgtCategory and e.TgtCoalition and e.TgtTypeName and e.TgtObjectCategory
            and e.WeaponName) then
        local BDA = string.format("%s %s destroyed %s %s with %s", UTILS.GetCoalitionName(e.IniCoalition), e.IniTypeName, UTILS.GetCoalitionName(e.TgtCoalition), e.TgtTypeName, e.WeaponName)
        HC:W(BDA)
        MESSAGE:New(BDA, 10):ToAll()

        --if unit is ground unit - damage airbase where it was destroyed
        --if unit is air unit - damage airbase from which it came from
        if(e.TgtObjectCategory == Object.Category.UNIT or e.TgtObjectCategory == Object.Category.STATIC) then
            --Find which airbase and apply damage
            if (e.TgtDCSUnit) then
                local position = e.TgtDCSUnit:getPosition() --x,y,z
                local tgtCoalitionName = UTILS.GetCoalitionName(e.TgtCoalition)
                local friendlyBases = SET_AIRBASE:New():FilterCoalitions(string.lower(tgtCoalitionName)):FilterOnce()
                friendlyBases:ForEachAirbase(
                    function(b)
                        HC:T("Base in filtered set "..b:GetCoalitionName().." "..b:GetName())
                    end
                )
                local coord = COORDINATE:NewFromVec3(position.p)
                local b, dist = coord:GetClosestAirbase()
                if (dist <= 2500 and b:GetCoalition() == e.TgtCoalition) then
                    --Unit killed within friendly airbase/FARP range
                    HC:T(string.format("Unit killed %d from %s, should apply damage to airbase", dist, b:GetName()))
                    local abi = HC.ActiveAirbases[b:GetName()]
                    if (abi) then
                        --placeholder, damage will be calculated based on unit type
                        abi.HP = abi.HP -5
                    end
                end
            end
        end
    end
end  

function HC:EndMission()
    --ToDo: save state
    
end

function HC:OnShortTick()
    for i=1, #(HC.ActiveAirbases) do
        local abi = HC.ActiveAirbases[i]
        local ab = AIRBASE:FindByName(abi.Name)
        abi.Coalition = ab:GetCoalition()
        abi:DrawLabel()
    end
end

function HC:OnLongTick()
    --This will go in long tick!
    local resupplyPercent = (HC.PASSIVE_RESUPPLY_RATE/3600) * HC.LONG_TICK_INTERVAL
    HC:AirbaseResupply(resupplyPercent) 
end

--Saves scenario state to file
function HC:SaveCampaignState()
    local filename = HC.PERSIST_FILE_NAME
    for _, abi in pairs(HC.ActiveAirbases) do
        local ab = AIRBASE:FindByName(abi.Name)
        abi.Coalition = ab:GetCoalition() --ensure coalition is up to date
        HC:SaveTable(HC.ActiveAirbases, HC.BASE_PATH..filename)
    end
end      

env.info(string.format("HaveChips main loaded ", HC.VERSION))
