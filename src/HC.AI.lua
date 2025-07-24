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
    chief:SetLimitMission(8, "Total")
    chief:SetStrategy(CHIEF.Strategy.TOTALWAR)

    if (HC.DEBUG) then
        chief:SetTacticalOverviewOn() --for debugging
        chief:SetVerbosity(5)
    else
        chief:SetVerbosity(0)
    end
    
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
    end
    

    function chief:OnAfterMissionAssign(From, Event, To, Mission, Legions)
        --HC:W("OnAfterMissionAssign")
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
        --local resourceEmpty, emptyIFV = chief:CreateResource(AUFTRAG.Type.PATROLZONE, 1, 1, GROUP.Attribute.GROUND_IFV)


        -- local resourceOccupied, armor = chief:CreateResource(AUFTRAG.Type.PATROLZONE, 1, 1, GROUP.Attribute.GROUND_IFV)
        -- chief:AddToResource(resourceOccupied, AUFTRAG.Type.GROUNDESCORT, 1, 1, GROUP.Attribute.AIR_ATTACKHELO)
        -- chief:AddToResource(resourceOccupied, AUFTRAG.Type.CASENHANCED, 1, 1)
        -- local assaultInf = chief:AddToResource(resourceOccupied, AUFTRAG.Type.ONGUARD, 1, 1)
        -- chief:AddTransportToResource(assaultInf, 1, 1, GROUP.Attribute.GROUND_IFV)
        

        --local resourceEmpty, emptyInfantry = chief:CreateResource(AUFTRAG.Type.ONGUARD, 2, 4, GROUP.Attribute.GROUND_INFANTRY)
        local resourceEmpty, emptyInfantry = chief:CreateResource(AUFTRAG.Type.ONGUARD, 1, 1, GROUP.Attribute.GROUND_INFANTRY)
        chief:AddTransportToResource(emptyInfantry, 1, 1, {GROUP.Attribute.AIR_TRANSPORTHELO})

        return resourceEmpty, resourceOccupied
        --return resourceEmpty, {}
end

function DoSEAD(chief, zone)
    local resource = 
    chief:RecruitAssetsForZone(zone, Resource)


    local DCStasks = {}
    local auftragSEAD = AUFTRAG:NewSEAD(zone, 2000)
    auftragSEAD.engageZone:Scan({Object.Category.UNIT},{Unit.Category.GROUND_UNIT})
    local ScanUnitSet = auftragSEAD.engageZone:GetScannedSetUnit()
    local SeadUnitSet = SET_UNIT:New()
    for _,_unit in pairs (ScanUnitSet.Set) do
        local unit = _unit -- Wrapper.Unit#UNTI
        if unit and unit:IsAlive() and unit:HasSEAD() then
            HC:T("Adding UNIT for SEAD: "..unit:GetName())
            local task = 
            CONTROLLABLE.TaskAttackUnit(nil,unit,GroupAttack,AI.Task.WeaponExpend.ALL,1,Direction,self.engageAltitude,ENUMS.WeaponType.Missile.AnyAutonomousMissile)          
            table.insert(DCStasks, task)
            SeadUnitSet:AddUnit(unit)
        end
    end
    auftragSEAD.engageTarget = TARGET:New(SeadUnitSet)

end    

function DoCaptureZone(chief, zone)
        local chief = HC.BLUE.CHIEF
        local zone = OPSZONE:FindByName("Hama")
        local resourceCapture, specops = chief:CreateResource(AUFTRAG.Type.ONGUARD, 1, 1, GROUP.Attribute.GROUND_INFANTRY)
        chief:AddTransportToResource(specops, 1, 1, {GROUP.Attribute.AIR_TRANSPORTHELO})
        local mission = AUFTRAG:NewPATROLZONE(zone, nil, nil)
        local isRecruited, assets, legions = chief.commander:RecruitAssetsForMission(mission)
        --UTILS.PrintTableToLog(assets)
        --UTILS.PrintTableToLog(legions)
        env.info("Do capture")

end