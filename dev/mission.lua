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

    local s = StaticObject.getByName("RED_WAREHOUSE_TEMPLATE")
    local ware = Warehouse.getCargoAsWarehouse(s)
    local tbl = ware:getInventory()

    local airbases = AIRBASE.GetAllAirbases()
    for i=1, #(airbases) do
        -- local ab = airbases[i]
        -- local storage = STORAGE:FindByName(ab:GetName())
        -- if(storage) then
        --     local aircraft = storage:GetInventory()
        --     --Clear everything first
        --     for name,_ in pairs(aircraft) do
        --         --storage:SetItem(name,0)
        --     end
        --     --for assetName, _ in pairs(storageTemplate)
        -- end
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
