--for interactive injecting
--dofile("C:/Users/tgudelj/Saved Games/DCS/Missions/havechips/hc/mission.lua")

local targetZone = _DATABASE.OPSZONES["FARPPobeda"]
local attackMission = AUFTRAG:NewCAPTUREZONE(targetZone, coalition.side.BLUE)
HC.BLUE.CHIEF:AddMission(attackMission)


local targetZone = _DATABASE.OPSZONES["FARPPobeda"]
local attackMission = AUFTRAG:NewCASENHANCED(targetZone, nil, nil, 5)
HC.BLUE.CHIEF:AddMission(attackMission)


local targetZone = _DATABASE.ZONES["FARPPobeda"]
local attackMission = AUFTRAG:NewCAS(targetZone, 300, 280, nil,60, 8)
HC.BLUE.CHIEF:AddMission(attackMission)

--local targetZone = _DATABASE.ZONES["FARPPobeda"]
--local attackMission = AUFTRAG:NewCASENHANCED(targetZone, nil, nil, 5)
--HC.BLUE.CHIEF:AddMission(attackMission)