--for interactive injecting
--dofile("C:/Users/tgudelj/Saved Games/DCS/Missions/havechips/hc/mission.lua")

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
hci("lfs.writedir(): "..lfs.writedir())
local _basePath =  lfs.writedir().."Missions\\havechips\\"   
local JSON = loadfile(_basePath.."hc\\JSON.lua")()

    local activeAirbases = nil
    local savePath = _basePath
    hci(savePath)
    --local success, airbaselist = UTILS.LoadFromFile(savePath, "airbases.txt")
    local f = io.open(savePath.."airbases.txt", "rb")
    local content = f:read("*all")
    f:close()
    activeAirbases = JSON.decode(content)
    --local f = loadstring(airbaselist[1])
    
    if (activeAirbases ~= nil) then
        --Campaign is in progress, we have saved data
        hci("Campaign in progress")
        hci(UTILS.TableShow(activeAirbases))
    else
        --First mission run in campaign, build a list of POIs (Airbases and FARPs) which have RED/BLUE ownership set
        --everything else will be ignorespeed
        hci("Campaign in starting, this is the first mission in campaign")
        local airbases = AIRBASE.GetAllAirbases()
        for i=1, #(airbases) do
            local ab = airbases[i]
            if(ab:GetCoalition() ~= coalition.side.NEUTRAL) then
                --RED and BLUE bases will be considered as strategic zones, everything else will be ignored
                if(ab:GetCategory() == Airbase.Category.AIRDROME) then
                    table.insert(activeAirbases, ab:GetName())
                else
                    table.insert(activeAirbases, ab:GetName())
                end
            end
        end
        UTILS.SaveToFile(savePath,"airbases.txt", JSON.encode(activeAirbases))
    end     