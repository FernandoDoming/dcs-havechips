--for interactive injecting
--dofile("C:/Users/tgudelj/Saved Games/DCS/Missions/havechips/dev/mission.lua")

-- local targetZone = _DATABASE.OPSZONES["FARPPobeda"]
-- local attackMission = AUFTRAG:NewCAPTUREZONE(targetZone, coalition.side.BLUE)
-- HC.BLUE.CHIEF:AddMission(attackMission)


-- local targetZone = _DATABASE.OPSZONES["FARPPobeda"]
-- local attackMission = AUFTRAG:NewCASENHANCED(targetZone, nil, nil, 5)
-- HC.BLUE.CHIEF:AddMission(attackMission)


-- local targetZone = _DATABASE.ZONES["FARPPobeda"]
-- local attackMission = AUFTRAG:NewCAS(targetZone, 300, 280, nil,60, 8)
-- HC.BLUE.CHIEF:AddMission(attackMission)

--local targetZone = _DATABASE.ZONES["FARPPobeda"]
--local attackMission = AUFTRAG:NewCASENHANCED(targetZone, nil, nil, 5)
--HC.BLUE.CHIEF:AddMission(attackMission)
--local JSON = loadfile("Scripts\\JSON.lua")()

    --local wht = STATIC:FindByName("RED_WAREHOUSE_TEMPLATE")
    --local storageTemplate = wht:GetStaticStorage()
    --local aircraft, liquids, equipment = storageTemplate:GetInventory()

    -- for _, item in ipairs(storageTemplate:GetInventory()) do
    --     env.info(item)
    -- end

    --local wht = Warehouse.getByName("RED_WAREHOUSE_TEMPLATE")

    --local s = StaticObject.getByName("RED_WAREHOUSE_TEMPLATE")
    --local ware = Warehouse.getCargoAsWarehouse(s)
    --local sourceInventory = ware:getInventory()

-- local inventoryTemplates = {
--     RED = {
--         MAIN = nil,
--         FRONTLINE = nil,
--         FARP = nil
--     },
--     BLUE = {
--         MAIN = nil,
--         FRONTLINE = nil,
--         FARP = nil
--     }
-- }
--     inventoryTemplates.RED.MAIN = STATIC:FindByName("RED_MAIN_INVENTORY"):GetStaticStorage()
--     inventoryTemplates.RED.FRONTLINE = STATIC:FindByName("RED_FRONTLINE_INVENTORY"):GetStaticStorage()
--     inventoryTemplates.RED.FARP = STATIC:FindByName("RED_FARP_INVENTORY"):GetStaticStorage()
--     inventoryTemplates.BLUE.MAIN = STATIC:FindByName("BLUE_MAIN_INVENTORY"):GetStaticStorage()
--     inventoryTemplates.BLUE.FRONTLINE = STATIC:FindByName("BLUE_FRONTLINE_INVENTORY"):GetStaticStorage()
--     inventoryTemplates.BLUE.FARP = STATIC:FindByName("BLUE_FARP_INVENTORY"):GetStaticStorage()


--     local sourceAircraft, _, sourceWeapons = sourceStorage:GetInventory()

--     local airbases = AIRBASE.GetAllAirbases(coalition.side.BLUE, Airbase.Category.AIRDROME)
--     for i=1, #(airbases) do
--         local ab = airbases[i]
--         env.info("Setting up inventory for ".. ab:GetName())
--         local targetStorage = STORAGE:FindByName(ab:GetName())
--         --local targetStorage = Warehouse.getByName(ab:GetName())
--         if(targetStorage) then
--             local aircraft, _, weapons = targetStorage:GetInventory()
--             --Clear everything first
--             --Clear aircraft
--             for name,_ in pairs(aircraft) do
--                 targetStorage:SetItem(name,0)
--             end
--             --Clear weapons
--             for name,_ in pairs(weapons) do
--                 targetStorage:SetItem(name,0)
--             end
--             --Set inventory from template
--             for name,v in pairs(sourceAircraft) do
--                 targetStorage:SetItem(name, v)
--             end
--             for name,v in pairs(sourceWeapons) do
--                 targetStorage:SetItem(name, v)
--             end
--         end
--     end



--SearchZone( EvaluateFunction, ObjectCategories )

-- function handleClearRequest(text, coord)
--     local destroyZoneName = string.format("destroy %d", destroyZoneCount)
--     local zoneRadiusToDestroy = ZONE_RADIUS:New(destroyZoneName, coord:GetVec2(), 10000)
--     destroyZoneCount = destroyZoneCount + 1
--     --trigger.action.outText("UNIT(S) on your MAP MARKER succesfully DESTROYED.", 10)
--     local function destroyUnit(unit)
--         unit:Destroy()
--         return true
--     end

--     zoneRadiusToDestroy:SearchZone( destroyUnit , Object.Category.UNIT)
-- end

--dofile("C:/Users/tgudelj/Saved Games/DCS.openbeta/Missions/havechips/dev/havechips.lua")
--dofile("C:/Users/tgudelj/Saved Games/DCS.openbeta/Missions/havechips/dev/mission.lua")
--PERUN:CleanZone("FARP Pobeda")
--PERUN:SpawnInZone("FARP Pobeda", "blue")

PERUN = {
    CurrentSuffix = 1
}
function PERUN:CleanZone(zoneName)
        local z = ZONE:FindByName(zoneName)
        if (not z) then
            env.info("Zone not found "..zoneName)
            return
        end
        local function destroyObject(obj)
            env.info("PERUN: killing "..obj:getName())
            obj:destroy()
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

-- @param #ZONE_RADIUS self
-- @param ObjectCategories A list of categories, which are members of Object.Category
-- @param EvaluateFunction
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
    --UNIT    1
    --WEAPON  2
    --STATIC  3
    --BASE    4
    --SCENERY 5
    --Cargo   6
    local function EvaluateZone( obj, val )
        env.info("Found something!"..obj:getName())
        return EvaluateFunction( obj )
    end
    world.searchObjects( ObjectCategories, SphereSearch, EvaluateZone )
end