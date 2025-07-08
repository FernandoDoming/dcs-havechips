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

local inventoryTemplates = {
    RED = {
        MAIN = nil,
        FRONTLINE = nil,
        FARP = nil
    },
    BLUE = {
        MAIN = nil,
        FRONTLINE = nil,
        FARP = nil
    }
}
    inventoryTemplates.RED.MAIN = STATIC:FindByName("RED_MAIN_INVENTORY"):GetStaticStorage()
    inventoryTemplates.RED.FRONTLINE = STATIC:FindByName("RED_FRONTLINE_INVENTORY"):GetStaticStorage()
    inventoryTemplates.RED.FARP = STATIC:FindByName("RED_FARP_INVENTORY"):GetStaticStorage()
    inventoryTemplates.BLUE.MAIN = STATIC:FindByName("BLUE_MAIN_INVENTORY"):GetStaticStorage()
    inventoryTemplates.BLUE.FRONTLINE = STATIC:FindByName("BLUE_FRONTLINE_INVENTORY"):GetStaticStorage()
    inventoryTemplates.BLUE.FARP = STATIC:FindByName("BLUE_FARP_INVENTORY"):GetStaticStorage()


    local sourceAircraft, _, sourceWeapons = sourceStorage:GetInventory()

    local airbases = AIRBASE.GetAllAirbases(coalition.side.BLUE, Airbase.Category.AIRDROME)
    for i=1, #(airbases) do
        local ab = airbases[i]
        env.info("Setting up inventory for ".. ab:GetName())
        local targetStorage = STORAGE:FindByName(ab:GetName())
        --local targetStorage = Warehouse.getByName(ab:GetName())
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
            --Set inventory from template
            for name,v in pairs(sourceAircraft) do
                targetStorage:SetItem(name, v)
            end
            for name,v in pairs(sourceWeapons) do
                targetStorage:SetItem(name, v)
            end
        end
    end



        -- for _, airbaseName in ipairs(airbaseList) do
        -- local storage = STORAGE:FindByName(airbaseName)
        -- if storage then
        --     local aircraft = storage:GetInventory()
        --     for name,_ in pairs(aircraft) do
        --     storage:SetItem(name,0)
        --     end
        --     for _,plane in ipairs(allowedPlanes) do
        --     storage:SetItem(plane,1000)
        --     end
        --     for _,weapon in ipairs(restrictedWeapons) do
        --     local amount = storage:GetItemAmount(weapon)
        --     if amount > 0 then
        --         storage:RemoveItem(weapon,amount)
        --     end
        --     end
        -- end
        -- end
