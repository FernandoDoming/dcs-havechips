function getClosestFriendlyAirbaseInfo(client)
    if not client or not client:IsAlive() then
        BASE:E("Client is nil or not alive.")
        return
    end
    local playerCoord = client:GetCoordinate()
    if not playerCoord then
        MESSAGE:New("Unable to determine player position.", 15, ""):ToUnit(client)
        return
    end
    local clientType = client:GetTypeName()
    local considerCVN72 = (clientType == "FA-18C_hornet")
    local closestZoneName, closestDistance, closestBearing = nil, math.huge, nil
    local closestNormalZoneName, closestNormalDistance, closestNormalBearing = nil, math.huge, nil

    local cvnCoord, cvnDistance, cvnBearing
    if considerCVN72 then
        local cvn
			if IsGroupActive('CVN-73') then
				cvn = UNIT:FindByName("CVN-73")
			elseif IsGroupActive('CVN-72') then
				cvn = UNIT:FindByName("CVN-72")
			end
        if cvn then
            cvnCoord = cvn:GetCoordinate()
            cvnDistance = playerCoord:Get2DDistance(cvnCoord)
            local trueBearingToCVN = playerCoord:HeadingTo(cvnCoord, nil)
            local magneticDeclination = playerCoord:GetMagneticDeclination()
            cvnBearing = (trueBearingToCVN - magneticDeclination + 360) % 360

            if cvnDistance < closestDistance then
                closestZoneName = cvn:GetName()
                closestDistance = cvnDistance
                closestBearing = cvnBearing
            end
        end
    end
    for zoneName, details in pairs(atisZones) do
        local airbase = AIRBASE:FindByName(details.airbaseName)
        if airbase and airbase:GetCoalition() == coalition.side.BLUE then
            local distanceToAirbase = playerCoord:Get2DDistance(airbase:GetCoordinate())
            local trueBearingToAirbase = playerCoord:HeadingTo(airbase:GetCoordinate(), nil)
            local magneticDeclination = playerCoord:GetMagneticDeclination()
            local magneticBearingToAirbase = (trueBearingToAirbase - magneticDeclination + 360) % 360

            if distanceToAirbase < closestDistance then
                closestZoneName = zoneName
                closestDistance = distanceToAirbase
                closestBearing = magneticBearingToAirbase
            end
            if not string.find(zoneName, "Carrier") and distanceToAirbase < closestNormalDistance then
                closestNormalZoneName = zoneName
                closestNormalDistance = distanceToAirbase
                closestNormalBearing = magneticBearingToAirbase
            end
        end
    end
	if closestZoneName == "CVN-72" or closestZoneName == "CVN-73" then
		local brcMessage = getBRC()
		local tacanCode = closestZoneName == "CVN-72" and "72X" or "73X"
		local cvnMessageText = string.format("Carrier: %s\n\nDistance: %.2f NM, Bearing: %03d°\n\nTACAN: %s, %s",
											 closestZoneName, closestDistance * 0.000539957, closestBearing, tacanCode, brcMessage)
		MESSAGE:New(cvnMessageText, 25, ""):ToUnit(client)
	end
    if closestNormalZoneName then
        local distanceInNM = closestNormalDistance * 0.000539957
        local displayName = closestNormalZoneName .. (WaypointList[closestNormalZoneName] or "")
        local windMessage, windDirection = getAirbaseWind(atisZones[closestNormalZoneName] and atisZones[closestNormalZoneName].airbaseName or "")
        local altimeterMessage, runwayInfo = "", ""

        if windMessage ~= "Wind data unavailable" and windMessage ~= "Airbase not found" then
            altimeterMessage = getAltimeter()
            runwayInfo = fetchActiveRunway(closestNormalZoneName, windDirection) or "Runway information not available"
        end
        local normalMessageText = string.format("Closest Friendly Airfield: %s\n\nDistance: %.2f NM, Bearing: %03d°\n\n%s%s%s",
                                                displayName, distanceInNM, closestNormalBearing, windMessage,
                                                altimeterMessage ~= "" and (", " .. altimeterMessage) or "",
                                                runwayInfo ~= "" and ("\n\n" .. runwayInfo) or "")
        MESSAGE:New(normalMessageText, 25, ""):ToUnit(client)
    end
end






function ZoneCommander:MakeZoneBlue()
	if not self.active or self.wasBlue then return
	end
    if self.active and not self.wasBlue then
        BASE:I("Making this zone Blue: " .. self.zone)
        local unitsInZone = coalition.getGroups(1)
        for _, group in ipairs(unitsInZone) do
            local groupUnits = group:getUnits()
            for _, unit in ipairs(groupUnits) do
                if Utils.isInZone(unit, self.zone) then
                    unit:destroy()
                end
            end
        end
        timer.scheduleFunction(function()
            self:capture(2,true)
            BASE:I("Zone captured by Blue: " .. self.zone)
			self.wasBlue = true
        end, nil, timer.getTime() + 12)
    else
        BASE:I("Zone is either inactive or not controlled by the blue side, no action taken.")
    end
end


function refreshPlayers()
    local b = coalition.getPlayers(coalition.side.BLUE)
    local current = {}
    for _, unit in ipairs(b) do
        local nm = unit:getPlayerName()
        if nm then
            local desc = unit:getDesc()
            if desc and desc.category == Unit.Category.AIRPLANE then
				if unit:getTypeName() ~= "A-10C_2" and unit:getTypeName() ~= "Hercules" and unit:getTypeName() ~= "A-10A" and unit:getTypeName() ~= "AV8BNA" then
					current[nm] = true
				end
            end
        end
    end
    for storedName in pairs(playerList) do
        if not current[storedName] then
            playerList[storedName] = nil
        end
    end
    for newName in pairs(current) do
        playerList[newName] = true
    end
end






    local auftragstatic = AUFTRAG:NewBAI(setStatic, 25000)
	auftrag:SetWeaponExpend(AI.Task.WeaponExpend.ONE)
	auftragstatic:SetEngageAsGroup(false)
	auftragstatic:SetMissionSpeed(600)
	casGroup:AddMission(auftragstatic)
	function auftragstatic:OnAfterExecuting(From, Event, To)
		casGroup:SwitchROE(2)
		auftragstatic:SetFormation(131075)
		auftragstatic:SetMissionSpeed(380)


            if unit:HasAttribute("SAM TR") or unit:HasAttribute("SAM SR") or unit:HasAttribute("SR SAM") then
                    decoyTargets:AddUnit(unit)
                end
            end


--react to chat??
     trigger.action.addOtherEvent(function(event)
        if event.id == world.event.S_EVENT_PLAYER_CHAT and event.text and event.text == "-clearmap" then
            logInfo("Manual cleaning command received via chat")
            trigger.action.outText("[MAP CLEANER] Running manual map cleaning!", 10)
            MapCleaner.performCleanup()
        end
    end)           


    --check out MOOSE functions
    UTILS.SpawnMASHStatics
    COORDINATE:GetSimpleZones
    --Check if commander limits now work, there seems to be typo correction in current dev


    -- ## Example 14: Strategic Bombing

-- This example shows how to employ strategic bombers in a mission. Three B-52s are launched at Kobuleti with the assignment to wipe out the enemy warehouse at Sukhumi.
-- The bombers will get a flight path and make their approach from the South at an altitude of 5000 m ASL. After their bombing run, they will return to Kobuleti and
-- added back to stock.

    -- Start warehouses
    warehouse.Kobuleti:Start()
    warehouse.Sukhumi:Start()

    -- Add a strategic bomber assets
    warehouse.Kobuleti:AddAsset("B-52H", 3)

    -- Request bombers for specific task of bombing Sukhumi warehouse.
    warehouse.Kobuleti:AddRequest(warehouse.Kobuleti, WAREHOUSE.Descriptor.ATTRIBUTE, WAREHOUSE.Attribute.AIR_BOMBER, WAREHOUSE.Quantity.ALL, nil, nil, nil, "Bomb Sukhumi")

    -- Specify assignment after bombers have been spawned.
    function warehouse.Kobuleti:OnAfterSelfRequest(From, Event, To, groupset, request)
      local groupset=groupset --Core.Set#SET_GROUP

      -- Get assignment of this request.
      local assignment=warehouse.Kobuleti:GetAssignment(request)

      if assignment=="Bomb Sukhumi" then

        for _,_group in pairs(groupset:GetSet()) do
          local group=_group --Wrapper.Group#GROUP

          -- Start uncontrolled aircraft.
          group:StartUncontrolled()

          -- Target coordinate!
          local ToCoord=warehouse.Sukhumi:GetCoordinate():SetAltitude(5000)

          -- Home coordinate.
          local HomeCoord=warehouse.Kobuleti:GetCoordinate():SetAltitude(3000)

          -- Task bomb Sukhumi warehouse using all bombs (2032) from direction 180 at altitude 5000 m.
          local task=group:TaskBombing(warehouse.Sukhumi:GetCoordinate():GetVec2(), false, "All", nil , 180, 5000, 2032)

          -- Define waypoints.
          local WayPoints={}

          -- Take off position.
          WayPoints[1]=warehouse.Kobuleti:GetCoordinate():WaypointAirTakeOffParking()
          -- Begin bombing run 20 km south of target.
          WayPoints[2]=ToCoord:Translate(20*1000, 180):WaypointAirTurningPoint(nil, 600, {task}, "Bombing Run")
          -- Return to base.
          WayPoints[3]=HomeCoord:WaypointAirTurningPoint()
          -- Land at homebase. Bombers are added back to stock and can be employed in later assignments.
          WayPoints[4]=warehouse.Kobuleti:GetCoordinate():WaypointAirLanding()

          -- Route bombers.
          group:Route(WayPoints)
        end

      end
    end

--find it in auftrag, this is the part of function that creates mission waypoint
waypointcoord=coord:GetIntermediateCoordinate(self:GetTargetCoordinate(), self.missionFraction)

BASE:TraceOn()
BASE:TraceLevel(2)
BASE:TraceClass("LEGION")
BASE:TraceClass("COMMANDER")
BASE:TraceClass("COHORT")



-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local BombMission = AUFTRAG:NewCASENHANCED(targetZone,25000,550,15,nil,{"Helicopters","Ground Units","Air Defence"})
--local BombMission = AUFTRAG:NewBAI(BomberTargets,25000)
    BomberGroup:AddMission(BombMission)
    BombMission.missionFraction=0.65
    BombMission:SetWeaponExpend(AI.Task.WeaponExpend.ALL)
    BombMission:SetMissionSpeed(550)
    BombMission:SetMissionAltitude(25000)
    
    function BombMission:OnAfterExecuting(From, Event, To)
    BombMission:SetROE(1)
    BombMission:SetEngageDetected(15)
    BombMission:SetEngageAsGroup(false)
    BombMission:SetMissionSpeed(450)
    end
    function BombMission:OnAfterSuccess(From, Event, To)
        if setStaticBomber:Count() < 0 then
        Trigger.action.outTextForCoalition(2, "Bomber Group has successfully completed its mission", 15)
        end
    end
    if setStaticBomber:Count() > 0 then
        local auftragstatic = AUFTRAG:NewBAI(setStaticBomber, 25000)
        auftragstatic:SetWeaponExpend(AI.Task.WeaponExpend.ONE)
        auftragstatic:SetEngageAsGroup(false)
        auftragstatic:SetMissionSpeed(600)
        BomberGroup:AddMission(auftragstatic)
        function auftragstatic:OnAfterExecuting(From, Event, To)
        BomberGroup:SwitchROE(1)
        auftragstatic:SetFormation(131075)
        auftragstatic:SetMissionSpeed(380)
        end
        function auftragstatic:OnAfterSuccess(From, Event, To)
            if setStaticBomber:Count() > 0 then
            Trigger.action.outTextForCoalition(2, "Bomber Group has successfully completed its mission", 15)
            end
        end
    end

    function BomberGroup:OnAfterLanded(From, Event, To)
        self:ScheduleOnce(5, function() self:Destroy() end)
    end
    function BomberGroup:OnAfterOutOfMissilesAG(From, Event, To)
        trigger.action.outTextForCoalition(2, "Bomber Group is now RTB", 15)
    end
    function BomberGroup:OnAfterDead(From, Event, To)
        local landed = (From=="Landed") or (From=="Arrived")
        _DATABASE.FLIGHTGROUPS[BomberGroup.groupname] = nil
        BomberGroup  = nil
        bomberActive = false
        buildCapControlMenu()
        if landed then
            trigger.action.outTextForCoalition(2, "Bomber Group have landed", 15)
        else
            trigger.action.outTextForCoalition(2, "Bomber Group have been killed", 15)
        end
    end
    trigger.action.outTextForCoalition(2, "Bomber flight launched from " .. zoneName .. " to attack " .. targetZoneName, 15)
  end, g, timer.getTime() + 1)
    bomberActive = true
    buildCapControlMenu()
    bombSpawnIndex = bombSpawnIndex + 1
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
