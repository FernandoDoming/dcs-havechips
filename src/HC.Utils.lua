--Write trace message to log
---@param message string message text
function HC:T(message)
    env.info("[HaveChips] "..message)
end

--Write warning message to log
---@param message string message text
function HC:W(message)
    env.warning("[HaveChips] "..message)
end

--Write error message to log
---@param message string message text
function HC:E(message)
    env.error("[HaveChips] "..message)
end

--Returns a list of zones which are inside specified "parent" zone
--Function is used to find pre-determined spawn locations around base perimeter
---@param parent ZONE Parent zone
---@param onlyAvailableForSpawn boolean if true, return only zones not marked as occupied
---@return table #table of child zones
function HC:GetChildZones(parent, onlyAvailableForSpawn)
    onlyAvailableForSpawn = onlyAvailableForSpawn or true
    local chilldZones = {}
    for _, zone in pairs(_DATABASE.ZONES) do
        local childVec3 = zone:GetVec3()
        if (parent:IsVec3InZone(childVec3) 
            and parent:GetName() ~= zone:GetName() --exclude the situation where parent is returned alongside its child zones
            ) then 
            if (onlyAvailableForSpawn) then
                if (not HC.OccupiedSpawnZones[zone:GetName()] and string.sub(zone:GetName(), 1,9) ~= "Warehouse") then
                    table.insert(chilldZones, zone)  
                end
            else
                table.insert(chilldZones, zone)    
            end
        end
    end
    return chilldZones
end    

--Returns a SET_ZONE containing zones which are inside specified "parent" zone
--Function is used to find pre-determined spawn locations around base perimeter
---@param parent ZONE Parent zone
---@param onlyAvailableForSpawn boolean if true, return only zones not marked as occupied
---@return SET_ZONE #Set of child zones
function HC:GetChildZoneSet(parent, onlyAvailableForSpawn)
    onlyAvailableForSpawn = onlyAvailableForSpawn or true
    local childZones = HC:GetChildZones(parent, onlyAvailableForSpawn)
    local zoneSet = SET_ZONE:New()
    for _, zone in pairs(childZones) do
        zoneSet:AddZone(zone)
    end
    return zoneSet
end    

--Gets a random child zone from specified parent
--Function is used to find a pre-determined spawn location around base perimeter
---@param parent ZONE Parent zone
---@param onlyAvailableForSpawn boolean if true, return only zones not marked as occupied
---@return ZONE? #A random child zone for specified parent, nil if zone can't be found
function HC:GetRandomChildZone(parent, onlyAvailableForSpawn)
    onlyAvailableForSpawn = onlyAvailableForSpawn or true
    local cz = HC:GetChildZones(parent, onlyAvailableForSpawn)
    if (#cz > 0) then
        return cz[math.random(#cz)]
    else
        return nil
    end
end    

--Checks if an airbase is close to frontline
---@param airbase AIRBASE Airbase to check
---@return boolean #true if airbase is close to the frontline
function HC:IsFrontlineAirbase(airbase)
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
    local closestEnemyBase = enemyBases:FindNearestAirbaseFromPointVec2(coord)
    local dist = coord:Get2DDistance(closestEnemyBase:GetCoordinate())
    HC:T("Closest enemy base to " ..airbase:GetName().. " is "..closestEnemyBase:GetName().." at distance "..tostring(dist).." m")
    return (dist < HC.FRONTLINE_PROXIMITY_THRESHOLD * 1000)
end

-- Get frontline airbases for a coalition
---@param coalitionName string Coalition name to get frontline airbases for. Either "red" or "blue"
---@return SET_AIRBASE #Set of frontline airbases for specified coalition
function HC:GetFrontlineAirbases(coalitionName)
    local frontlineAirbases = SET_AIRBASE:New()
    local airbases = SET_AIRBASE:New():FilterCoalitions(coalitionName):FilterOnce()
    airbases:ForEachAirbase(
        function(ab)
            if (HC:IsFrontlineAirbase(ab)) then
                frontlineAirbases:AddAirbase(ab)
            end
        end
    )
    return frontlineAirbases
end

-- Get closest enemy airbase to a specified airbase
---@param airbase AIRBASE Airbase to find closest enemy airbase for
---@param airbaseType table? Optional 'array' of airbase types to filter by, e.g. {"helipad"}, {"airdrome", "helipad"}, etc.
---@return AIRBASE? #Closest enemy airbase, nil if no enemy airbase found
function HC:GetClosestEnemyAirbase(airbase, airbaseType)
    local enemySide = nil
    if (airbase:GetCoalition() == coalition.side.RED) then
        enemySide = "blue"
    elseif (airbase:GetCoalition() == coalition.side.BLUE) then
        enemySide = "red"
    else
        -- Neutral airbase, no enemy side
        return nil
    end
    local set = SET_AIRBASE:New():FilterCoalitions(enemySide)
    if airbaseType then
        set:FilterCategories(airbaseType)
    end
    local enemyBases = set:FilterOnce()
    local coord = airbase:GetCoordinate()
    return enemyBases:FindNearestAirbaseFromPointVec2(coord)
end

--Checks if file specified by filename path exists
---@param filename string path to check
---@return boolean #true if file exists, false otherwise
function HC:FileExists(filename)
    --Check io
    if not io then
        HC:E("ERROR: io not desanitized. Can't save current file.")
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
---@param filename string filename path to load from
---@return boolean, table? #true if operation was successful, false otherwise, dataTable - json data as Lua table
function HC:LoadTable(filename)
    --Check io
    if not io then
        HC:E("ERROR: io not desanitized. Can't save current file.")
        return false, nil
    end
    -- Check file name.
    if filename == nil then
        HC:E("Filename must be specified")
        return false, nil
    end
    
    local f = io.open(filename, "rb")
    if(f == nil) then
        HC:E("Could not open file '"..filename.."'")
        return false, nil
    end        
    local content = f:read("*all")
    f:close()
    local tbl = NET.Json2Lua(content)
    UTILS.TableShow(tbl)
    return true, tbl
end

--save lua table to JSON file
---@param table table Lua table to save
---@param filename string File path to save the data to
---@return return boolean true if operation was successful, false otherwise
function HC:SaveTable(table, filename)
    --Check io
    if not io then
        HC:E("ERROR: io not desanitized. Can't save current file.")
        return false
    end
    -- Check file name.
    if filename == nil then
        HC:E("Filename must be specified")
        return false
    end
    if (table == nil) then
        HC:E("Table is nil")
        return false
    end        

    local json = NET.Lua2Json(table)
    local f = assert(io.open(filename, "wb"))
    if (f == nil) then
        HC:E("File open failed on file "..filename)
        return false
    end        
    f:write(json)
    f:close()
    return true
end