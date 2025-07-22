--Write trace message to log
---@param message string message text
function HC:T(message)
    if (HC.TRACE) then
        env.info("[HaveChips] "..message)        
    end
end

--Write info message to log
---@param message string message text
function HC:I(message)
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

function string:startswith(start)
    return self:sub(1, #start) == start
end

function string:endswith(ending)
    return ending == "" or self:sub(-#ending) == ending
end

function TCount(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

--If group is present and is damaged, function will destroy it
---@param alias GROUP Group
---@return boolean $true if group was destroyed or didn't exist
function HC:DestroyGroupIfDamaged(group)    
    if(group) then
        --Group already exists
        if (group:GetInitialSize() ~= group:GetSize()) then
            --group was damaged, we will replace it with a new one
            group:Destroy()
            return true
        end
        if (not group:IsAlive()) then
            return true --group was already desreoyed
        end
        return false
    else
        --Group didn't exist anyway
        return true
    end
end

--Returns a list of zones which are inside specified "parent" zone
--Function is used to find pre-determined spawn locations around base perimeter
---@param parent ZONE Parent zone
---@param onlyAvailableForSpawn boolean if true, return only zones not marked as occupied
---@return table #table of child zones
function HC:GetChildZones(parent, onlyAvailableForSpawn)
    if (onlyAvailableForSpawn == nil) then onlyAvailableForSpawn = true end
    local chilldZones = {}
    for _, zone in pairs(_DATABASE.ZONES) do
        local childVec3 = zone:GetVec3()
        if (parent:IsVec3InZone(childVec3) and parent:GetName() ~= zone:GetName()) then --exclude the situation where parent is returned alongside its child zones
            if (onlyAvailableForSpawn == true) then
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
    if (onlyAvailableForSpawn == nil) then onlyAvailableForSpawn = true end
    local cz = HC:GetChildZones(parent, onlyAvailableForSpawn)
    if (#cz > 0) then
        return cz[math.random(#cz)]
    else
        return nil
    end
end    

--Checks if an airbase is close to frontline
---@param airbase AIRBASE Airbase to check
---@return boolean, boolean #isFrontline - true if airbase is close to the frontline, isRearArea - true if airbase is far away from frontline
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
    return (dist < HC.FRONTLINE_PROXIMITY_THRESHOLD * 1000), (dist > HC.REAR_AREA_DISTANCE_THRESHOLD * 1000)
end

---Finds closest unit to specified point
---@param origin Coordinate Point to search from
---@param side string Coalition side to search in, "red" or "blue"
function HC:DistanceToClosestUnit(origin, side)
    local units = SET_UNIT:New():FilterCoalitions(side):FilterOnce()
    local closestDistance = math.huge
    units:ForEachUnit(
        function(unit)
            local dist = origin:Get2DDistance(unit:GetCoordinate())
            if (dist < closestDistance) then
                closestDistance = dist
            end
        end
    )
    return closestDistance
end    

--goes through all airbase spawn zones and checks if they are empty
--if the zone is empty, remove it from OccupiedZones list 
---@param airbaseName string Airbase name
---@return SET_ZONE #Set of zones which should be safe to spawn in
function HC:CheckFreeSpawnZones(airbaseName)
    local zone = ZONE:FindByName(airbaseName)
    local childZones =  HC:GetChildZoneSet(zone, false)
    local safeSpawnZones = SET_ZONE:New()
    childZones:ForEachZone(
        function(spawnZone)
            if(airbaseName ~= spawnZone:GetName() and string.sub(spawnZone:GetName(), 1,9) ~= "Warehouse") then
                if (not HC.OccupiedSpawnZones[spawnZone:GetName()]) then
                    --HC:T(string.format(" Safe spawn zone %s [%s]", airbaseName, spawnZone:GetName()))
                    safeSpawnZones:AddZone(spawnZone)
                else
                    spawnZone:Scan({Object.Category.UNIT, Object.Category.STATIC},{Unit.Category.GROUND_UNIT, Unit.Category.STRUCTURE})
                    local isEmpty = spawnZone:IsNoneInZone()
                    HC.OccupiedSpawnZones[spawnZone:GetName()] = not isEmpty
                    if(isEmpty) then
                        --HC:T(string.format("Safe spawn zone %s [%s]", airbaseName, spawnZone:GetName()))
                        safeSpawnZones:AddZone(spawnZone)
                    end                    
                end
            else
                --HC:T(string.format("%s [%s] is not a valid spawn zone", airbaseName, spawnZone:GetName()))
            end
        end
    )
    return safeSpawnZones
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

--#region DCS attributes enum

 --["plane_carrier"] = {},
 --["no_tail_trail"] = {},
 --["cord"] = {},
 --["ski_jump"] = {},
 --["catapult"] = {},
 --["low_reflection_vessel"] = {},
 --["AA_flak"] = {},
 --["AA_missile"] = {},
 --["Cruise missiles"] = { "Missiles", },
 --["Anti-Ship missiles"] = { "Missiles", },
 --["Missiles"] = { "Planes", },
 --["Fighters"] = { "Planes", "Battle airplanes", },
 --["Interceptors"] = { "Planes", "Battle airplanes", },
 --["Multirole fighters"] = { "Planes", "Battle airplanes", },
 --["Bombers"] = { "Planes", "Battle airplanes", },
 --["Battleplanes"] = { "Planes", "Battle airplanes", },
 --["AWACS"] = { "Planes", },
 --["Tankers"] = { "Planes", },
 --["Aux"] = { "Planes", },
 --["Transports"] = { "Planes", },
 --["Strategic bombers"] = { "Bombers", },
 --["UAVs"] = { "Planes", },
 --["Attack helicopters"] = {"Helicopters", },
 --["Transport helicopters"]   = {"Helicopters", },
 --["Planes"] = {"Air",},
 --["Helicopters"] = {"Air",},
 --["Cars"] = {"Unarmed vehicles",},
 --["Trucks"] = {"Unarmed vehicles",},
 --["Infantry"] = {"Armed ground units", "NonArmoredUnits"},
 --["Tanks"] = {"Armored vehicles","Armed vehicles","AntiAir Armed Vehicles","HeavyArmoredUnits",},
 --["Artillery"] = {"Armed vehicles","Indirect fire","LightArmoredUnits",},
 --["MLRS"] = {"Artillery",},
 --["IFV"] = {"Infantry carriers","Armored vehicles","Armed vehicles","AntiAir Armed Vehicles","LightArmoredUnits",},
 --["APC"] = {"Infantry carriers","Armored vehicles","Armed vehicles","AntiAir Armed Vehicles","LightArmoredUnits",},
 --["Fortifications"] = {"Armed ground units","AntiAir Armed Vehicles","HeavyArmoredUnits",},
 --["Armed vehicles"] = {"Armed ground units","Ground vehicles",},
 --["Static AAA"] = {"AAA", "Ground vehicles",},
 --["Mobile AAA"] = {"AAA", "Ground vehicles",},
 --["SAM SR"] = {"SAM elements",}, -- Search Radar
 --["SAM TR"] = {"SAM elements"}, -- Track Radar
 --["SAM LL"] = {"SAM elements","Armed Air Defence"},  -- Launcher
 --["SAM CC"] = {"SAM elements",}, -- Command Center
 --["SAM AUX"] = {"SAM elements",}, -- Auxilary Elements (not included in dependencies)
 --["SR SAM"] = {}, -- short range
 --["MR SAM"] = {}, -- medium range
 --["LR SAM"] = {}, -- long range
 --["SAM elements"] = {"Ground vehicles", "SAM related"}, --elements of composite SAM site
 --["IR Guided SAM"] = {"SAM"},
 --["SAM"] = {"SAM related", "Armed Air Defence", "Ground vehicles"}, --autonomous SAM unit (surveillance + guidance + launcher(s))
 --["SAM related"] = {"Air Defence"}, --all units those related to SAM
 --["AAA"] = {"Air Defence", "Armed Air Defence", "Rocket Attack Valid AirDefence",},
 --["EWR"] = {"Air Defence vehicles",},
 --["Air Defence vehicles"] = {"Air Defence","Ground vehicles",},
 --["MANPADS"] = {"IR Guided SAM","Infantry","Rocket Attack Valid AirDefence",},
 --["MANPADS AUX"] = {"Infantry","Rocket Attack Valid AirDefence","SAM AUX"},
 --["Unarmed vehicles"] = {"Ground vehicles","Ground Units Non Airdefence","NonArmoredUnits",},
 --["Armed ground units"] = {"Ground Units","Ground Units Non Airdefence",},
 --["Armed Air Defence"] = {}, --air-defence units those have weapon onboard (SAM or AAA)
 --["Air Defence"] = {"NonArmoredUnits"},
 --["Aircraft Carriers"] = {"Heavy armed ships",},
 --["Cruisers"] = {"Heavy armed ships",},
 --["Destroyers"] = {"Heavy armed ships",},
 --["Frigates"] = {"Heavy armed ships",},
 --["Corvettes"] = {"Heavy armed ships",},
 --["Heavy armed ships"] = {"Armed ships", "Armed Air Defence", "HeavyArmoredUnits",},
 --["Light armed ships"] = {"Armed ships","NonArmoredUnits"},
 --["Armed ships"] = {"Ships"},
 --["Unarmed ships"] = {"Ships","HeavyArmoredUnits",},
 --["Air"] = {"All","NonArmoredUnits",},
 --["Ground vehicles"] = {"Ground Units", "Vehicles"},
 --["Ships"] = {"All",},
 --["Buildings"] = {"HeavyArmoredUnits",},
 --["HeavyArmoredUnits"] = {},
 --["ATGM"] = {},
 --["Old Tanks"] = {},
 --["Modern Tanks"] = {},
 --["LightArmoredUnits"] = {"NonAndLightArmoredUnits",},
 --["Rocket Attack Valid AirDefence"] = {},
 --["Battle airplanes"] = {},
 --["All"] = {},
 --["Infantry carriers"] = {},
 --["Vehicles"] = {},
 --["Ground Units"] = {"All",},
 --["Ground Units Non Airdefence"] = {},
 --["Armored vehicles"] = {},
 --["AntiAir Armed Vehicles"] = {}, --ground vehicles those capable of effective fire at aircrafts
 --["Airfields"] = {},
 --["Heliports"] = {},
 --["Grass Airfields"] = {},
 --["Point"] = {},
 --["NonArmoredUnits"] = {"NonAndLightArmoredUnits",},
 --["NonAndLightArmoredUnits"] = {},
 --["human_vehicle"] = {}, -- player controlable vehicle
 --["RADAR_BAND1_FOR_ARM"] = {},
 --["RADAR_BAND2_FOR_ARM"] = {},
 --["Prone"] = {},
 --["DetectionByAWACS"] = {}, -- for navy\ground units with external target detection
 --["Datalink"] = {}, -- for air\navy\ground units with on-board datalink station
 --["CustomAimPoint"] = {}, -- unit has custom aiming point
 --["Indirect fire"] = {},
 --["Refuelable"] = {},
 --["Weapon"] = {"Shell", "Rocket", "Bomb", "Missile"},
--#endregion

--#region DCS unit classification
---@param unit DCSUnit DCS unit to check
---@return boolean #true if unit is AAA
function HC.IsAAA(unit)
    local attr = unit:getDesc().attributes
    if attr["AAA"] then
        return true
    end
    return false
end    

---@param unit DCSUnit DCS unit to check
---@return boolean #true if unit is SAM
function HC.IsSAM(unit)
    local attr = unit:getDesc().attributes
    if attr["SAM"] or attr["SAM related"] then
        return true
    end
    return false
end  

---@param unit DCSUnit DCS unit to check
---@return boolean #true if unit is fixed wing aircraft
function HC.IsPlane(unit)
    local attr = unit:getDesc().attributes
    if attr["Planes"] or attr["Battle airplanes"] then
        return true
    end
    return false
end

---@param unit DCSUnit DCS unit to check
---@return boolean #true if unit is a helicopter
function HC.IsHelicopter(unit)
    local attr = unit:getDesc().attributes
    if attr["Helicopters"] then
        return true
    end
    return false
end

---@param unit DCSUnit DCS unit to check
---@return boolean #true if unit is a helicopter
function HC.IsTank(unit)
    local attr = unit:getDesc().attributes
    if attr["Tanks"] and (attr["Old Tanks"] or attr["Modern Tanks"]) then
        return true
    end
    return false
end

---@param unit DCSUnit DCS unit to check
---@return boolean #true if unit is a early warning radar
function HC.IsEWR(unit)
    local attr = unit:getDesc().attributes
    if (attr["EWR"]) then
        return true
    end
    return false
end

--#endregion
--Calculates the damage to inflict to airbase when related unit is destroyed
---@param unit DCSUnit DCS unit to check
---@return number #Damage in %
function HC.CalculateDamageForUnitLost(unit)
    if (unit.Category == Object.Category.STATIC) then
        local static = STATIC:FindByName(unit:getName(), false) 
        if(static) then
            local damage = static:GetProperty("damageWhenLost")
            if (damage) then
                return damage
            else
                return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.STATIC
            end
        else 
            return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.STATIC        
        end  
    end
    if (Unit.getPlayerName(unit)) then
        return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.PLAYER
    elseif (HC.IsPlane(unit)) then
        return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.AIRCRAFT
    elseif(HC.IsHelicopter(unit)) then
        return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.HELICOPTER
    elseif(HC.IsAAA(unit)) then    
        return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.AAA
    elseif(HC.IsSAM(unit)) then 
        return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.SAM
    elseif(HC.IsEWR(unit)) then 
        return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.EWR
    elseif(HC.IsTank(unit)) then             
        return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.TANK
    else
        return HC.AIRBASE_DAMAGE_PER_UNIT_TYPE_LOST.DEFAULT
    end
end
    

--@param zone #ZONE_RADIUS
--@param ObjectCategories A list of categories, which are members of Object.Category
--@param EvaluateFunction
function HC:SearchZone( zone, EvaluateFunction, ObjectCategories )
  local zoneCoord = zone:GetCoordinate()
  local zoneRadius = zone:GetRadius()
  local sphereSearch = {
    id = world.VolumeType.SPHERE,
      params = {
      point = zoneCoord:GetVec3(),
      radius = zoneRadius,
      }
    }
    local function EvaluateZone( obj, val )
        env.info("Found something "..obj:getName().." radius "..tostring(zoneRadius))
        return EvaluateFunction( obj )
    end
    world.searchObjects( ObjectCategories, sphereSearch, EvaluateZone )
end