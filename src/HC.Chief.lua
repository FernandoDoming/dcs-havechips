-- Initializes the strategy for the chief, this includes
-- setting up the strategic zones and their responses.
---@param chief CHIEF Chief object to reset strategy for
function HC:InitStrategy(chief)
    local coalitionName = chief.coalition == coalition.side.RED and "red" or "blue"
    HC:T("Initializing strategy for "..coalitionName.." chief")
    local frontlinAirbases = HC:GetFrontlineAirbases(coalitionName)

    if not frontlinAirbases or frontlinAirbases:Count() <= 0 then
        HC:E("No frontline airbases found for "..coalitionName.." coalition")
        return
    end

    frontlinAirbases:ForEachAirbase(
        function(airbase)
            local nextObjectives = HC:ChiefGetNextObjectiveFromZone(chief, airbase)
            for _, objective in pairs(nextObjectives) do
                HC:ChiefAddStrategicZone(
                    chief,
                    objective
                )
            end
        end
    )
end

----------------------------------------------------------------
-- Function to handle the event when a zone is lost
---@param chief CHIEF Chief object that lost the zone
---@param from string Previous state of the zone
---@param event string Event type
---@param to string New state of the zone
---@param opszone OPSZONE Zone that was lost
---@return nil
function HC:ChiefOnZoneLost(chief, from, event, to, opszone)
    local lostZoneName = opszone:GetName()
    local coalitionName = chief.coalition == coalition.side.RED and "red" or "blue"
    HC:T("Coalition "..coalitionName.." lost zone "..lostZoneName)

    -- Remove the closest enemy zone to the lost zone as a strategic zone
    local airbase = AIRBASE:FindByName(lostZoneName)
    if airbase then
        local nextObjectives = HC:ChiefGetNextObjectiveFromZone(chief, airbase)
        for _, objective in pairs(nextObjectives) do
            HC:ChiefRemoveStrategicZone(
                chief,
                objective
            )
        end
    end
    -- Add the lost zone to the strategic zones to attempt to recapture it
    HC:ChiefAddStrategicZone(
        chief,
        opszone
    )
end

----------------------------------------------------------------
-- Function to handle the event when a zone is captured
---@param chief CHIEF Chief object that captured the zone
---@param from string Previous state of the zone
---@param event string Event type
---@param to string New state of the zone
---@param opszone OPSZONE Zone that was captured
---@return nil
function HC:ChiefOnZoneCaptured(chief, from, event, to, opszone)
    local capturedZoneName = opszone:GetName()
    local coalitionName = chief.coalition == coalition.side.RED and "red" or "blue"
    HC:T("Coalition "..coalitionName.." captured zone "..capturedZoneName)

    -- Remove the captured zone from the strategic zones
    HC:ChiefRemoveStrategicZone(chief, opszone)

    local airbase = AIRBASE:FindByName(capturedZoneName)
    local nextObjectives = HC:ChiefGetNextObjectiveFromZone(chief, airbase)
    for _, objective in pairs(nextObjectives) do
        HC:ChiefAddStrategicZone(
            chief,
            objective
        )
    end

end

----------------------------------------------------------------
-- Function to handle the event when a zone becomes empty
---@param chief CHIEF Chief object that has the zone empty
---@param from string Previous state of the zone
---@param event string Event type
---@param to string New state of the zone
---@param opszone OPSZONE Zone that became empty
---@return nil
function HC:ChiefOnZoneEmpty(chief, from, event, to, opszone)
    --this eventhandler will be moved to HC main
    HC:W("Zone is now empty")
    local ab = AIRBASE:FindByName(opszone:GetName())
    --zone neutralized, send troops to capture it
    --possible scenario
    --find closest friendly airbase to neutralized zone, create OPSTRANSPORT
end

----------------------------------------------------------------
-- Gets the next objective to target from a strategic zone
---@param chief CHIEF Chief object to get the next objective for
---@param zone AIRBASE Source airbase to get the next objective from
---@return table An 'array' of OPSZONE objective zones
function HC:ChiefGetNextObjectiveFromZone(chief, zone)
    local nextObjectives = {}
    local srcZoneName = zone:GetName()
    local airbase = AIRBASE:FindByName(srcZoneName)

    -- Check the closest farp and airdrome, if they are similar in distance, return both
    -- else return the closest one
    local closestEnemyAirdrome = HC:GetClosestEnemyAirbase(airbase, {"airdrome"})
    local closestEnemyFarp     = HC:GetClosestEnemyAirbase(airbase, {"helipad"})

    local farpDist = math.huge
    if closestEnemyFarp then
        farpDist = airbase:GetCoordinate():Get2DDistance(closestEnemyFarp:GetCoordinate())
    end
    local airdromeDist = math.huge
    if closestEnemyAirdrome then
        airdromeDist = airbase:GetCoordinate():Get2DDistance(closestEnemyAirdrome:GetCoordinate())
    end

    -- If both distances are similar, return both objectives
    -- comparison is done in meters
    if math.abs(farpDist - airdromeDist) < 15000 then
        table.insert(
            nextObjectives,
            OPSZONE:New(ZONE_AIRBASE:New(closestEnemyAirdrome:GetName()))
        )
        table.insert(
            nextObjectives,
            OPSZONE:New(ZONE_AIRBASE:New(closestEnemyFarp:GetName()))
        )
    elseif farpDist < airdromeDist then
        table.insert(
            nextObjectives,
            OPSZONE:New(ZONE_AIRBASE:New(closestEnemyFarp:GetName()))
        )
    else
        table.insert(
            nextObjectives,
            OPSZONE:New(ZONE_AIRBASE:New(closestEnemyAirdrome:GetName()))
        )
    end

    return nextObjectives
end

----------------------------------------------------------------
-- Adds a strategic zone to the chief's strategy
---@param chief CHIEF Chief object to add the strategic zone to
---@param opszone OPSZONE Zone to add as a strategic zone
---@return nil
function HC:ChiefAddStrategicZone(chief, opszone)
    local zoneName = opszone:GetName()
    local coalitionName = chief.coalition == coalition.side.RED and "red" or "blue"

    if #chief.StrategicZones >= HC.MAX_STRATEGIC_ZONES then
        HC:W("Maximum number of strategic zones reached for "..coalitionName.." chief, skipping "..zoneName)
        return
    elseif chief.StrategicZones[zoneName] then
        HC:W("Strategic zone "..zoneName.." already added for "..coalitionName.." chief")
        return
    end

    local resEmpty, resOccupied = HC:GetChiefZoneResponse(chief)
    chief:AddStrategicZone(
        opszone,       -- The strategic zone to add
        nil,           -- Importance, nil means default
        2,             -- Priority, higher means more important
        resOccupied,   -- Response when the zone is occupied
        resEmpty       -- Response when the zone is empty
    )

    chief.StrategicZones[zoneName] = true
    HC:T("Added strategic zone "..zoneName.." for "..coalitionName.." chief")
end

----------------------------------------------------------------
-- Removes a strategic zone from the chief's strategy
---@param chief CHIEF Chief object to remove the strategic zone from
---@param opszone OPSZONE Zone to remove from the strategic zones
---@return nil
function HC:ChiefRemoveStrategicZone(chief, opszone)
    local zoneName = opszone:GetName()
    local coalitionName = chief.coalition == coalition.side.RED and "red" or "blue"

    if not chief.StrategicZones[zoneName] then
        HC:W(
            "Strategic zone "..zoneName.." not found for "..coalitionName..
            " chief while attempting to remove it"
        )
        return
    end

    chief:RemoveStrategicZone(opszone)
    chief.StrategicZones[zoneName] = nil
    HC:T("Removed strategic zone "..zoneName.." for "..coalitionName.." chief")
end