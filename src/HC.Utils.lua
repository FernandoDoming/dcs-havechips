env.info("Loading HC.Utils")
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

--Returns a list of zones which are inside specified "parent" zone
--Function is used to find pre-determined spawn locations around base perimeter
--@param ZONE Parent zone
--@return #table table of child zones
function HC:GetChildZones(parent)
    local chilldZones = {}
    for _, zone in pairs(_DATABASE.ZONES) do
        local childVec3 = zone:GetVec3()
        if (parent:IsVec3InZone(childVec3) 
            and parent:GetName() ~= zone:GetName()) then --exclude the situation where parent is returned alongside its child zones
            table.insert(chilldZones, zone)
        end
    end
    return chilldZones
end    

--Returns a SET_ZONE containing zones which are inside specified "parent" zone
--Function is used to find pre-determined spawn locations around base perimeter
--@param ZONE Parent zone
--@return SET_ZONE of child zones
function HC:GetChildZonesSet(parent)
    local childZones = HC:GetChildZones(parent)
    local zoneSet = SET_ZONE:New()
    for _, zone in pairs(childZones) do
        zoneSet:AddZone(zone)
    end
    return zoneSet
end    

--Gets a random child zone from specified parent
--Function is used to find a pre-determined spawn location around base perimeter
--@param ZONE Parent zone
--@return A random child zone for specified parent
function HC:GetRandomChildZone(parent)
    local cz = HC:GetChildZones(parent)
    if (#cz > 0) then
        return cz[math.random(#cz)]
    else
        return nil
    end
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

--Checks if file specified by filename path exists
--@param filename Filename path
--@return #bool true if file exists
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
--@param filename - filename path to load from
---@return bool success (true if operation was successful, false otherwise), table - json file data as Lua table
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
    --local tbl = assert(JSON.decode(content), "Couldn't decode JSON data from file "..filename)
    local tbl = NET.Json2Lua(content)
    UTILS.TableShow(tbl)
    return true, tbl
end

--save lua table to JSON file
--@return bool true if operation was successful, false otherwise
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
    --local json = assert(JSON.encode(table),"Couldn't encode Lua table")
    local json = NET.Lua2Json(table)
    local f = assert(io.open(filename, "wb"))
    if (f == nil) then
        HC:E("File open failed on file "..filename)
        return false
    end        
    f:write(json)
    f:close()
end
env.info("HC.Utils loaded")