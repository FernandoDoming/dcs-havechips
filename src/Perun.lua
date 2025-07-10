--dofile("C:/Users/tgudelj/Saved Games/DCS.openbeta/Missions/havechips/dev/PERUN.lua")


PERUN = {
    VERSION = 0.1,
    CurrentSuffix = 1
}
env.info(string.format("PERUN %s loading ", PERUN.VERSION))
function PERUN:CleanZone(zoneName, coalitionName)
        local z = ZONE:FindByName(zoneName)
        if (not z) then
            env.info("Zone not found "..zoneName)
            return
        end
        coalitionName = coalitionName or "ALL"
        coalitionName = string.upper(coalitionName)

        if (coalitionName ~= "ALL" 
            and coalitionName ~= "NEUTRAL"
            and coalitionName ~= "RED"
            and coalitionName ~= "BLUE"
            ) then
                env.info(string.format("Invalid coalition [%s]",coalitionName))
            return
        end
        env.info(string.format("Killing objects belonging to [%s] in [%s]",coalitionName, zoneName))
        local function destroyObject(obj)
            local objCategory = obj:getCategory()            
            env.info("PERUN: killing "..obj:getName())
            if (coalitionName ~= "ALL") then
                local coalitionId = coalition.side[coalitionName]               
                if (objCategory == Object.Category.UNIT 
                    or objCategory == Object.Category.STATIC 
                    or objCategory == Object.Category.CARGO 
                ) then
                    if(obj:getCoalition() == coalitionId) then
                        env.info("PERUN: killing ["..coalitionName.."] "..obj:getName())
                        obj:destroy()   
                    end
                end                  
            else
                env.info("PERUN: killing "..obj:getName())
                obj:destroy()
            end                
            return true
        end
        PERUN:SearchZone(z, destroyObject, {Object.Category.UNIT, Object.Category.STATIC, Object.Category.CARGO})
end

function PERUN:DestroyUnit(unitName)
    local unit = UNIT:FindByName(unitName)
    if (not unit) then
        env.info("Unit "..unitName.." not found")
    end
    unit:Destroy()
end    

function PERUN:DestroyGroup(groupName)
    local group = GROUP:FindByName(groupName)
    if (not group) then
        env.info("Unit "..groupName.." not found")
    end
    group:Destroy(false)
end  


function PERUN:SpawnInZone(zoneName, Coalition)
    local z = ZONE:FindByName(zoneName)
    if(not z) then
        env.info("Zone not found "..zoneName)
        return
    end
    local spawn = SPAWN:NewWithAlias("PERUN_"..string.upper(Coalition), string.format("PERUN-%d", PERUN.CurrentSuffix))
    PERUN.CurrentSuffix = PERUN.CurrentSuffix +1
    spawn:SpawnInZone(z, true)
end    

--@param #ZONE_RADIUS self
--@param ObjectCategories A list of categories, which are members of Object.Category
--@param EvaluateFunction
function PERUN:SearchZone( Zone, EvaluateFunction, ObjectCategories )
  local ZoneCoord = Zone:GetCoordinate()
  local ZoneRadius = Zone:GetRadius()
  local SphereSearch = {
    id = world.VolumeType.SPHERE,
      params = {
      point = ZoneCoord:GetVec3(),
      radius = ZoneRadius,
      }
    }
    local function EvaluateZone( obj, val )
        env.info("Found something "..obj:getName().." radius "..tostring(ZoneRadius))
        return EvaluateFunction( obj )
    end
    world.searchObjects( ObjectCategories, SphereSearch, EvaluateZone )
end
env.info("PERUN loaded")
