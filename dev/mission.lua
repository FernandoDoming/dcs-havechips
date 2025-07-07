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

local ab = AIRBASE:FindByName("Abu al-Duhur")
local coord = ab:GetCoordinate()

local offset = {x=500, y=0, z=500}
local rectWidth = 4000
local rectHeight = 1500

local topLeft = COORDINATE:New(coord.x + offset.x, coord.y + offset.y, coord.z + offset.z)
local bottomRight = COORDINATE:New(topLeft.x + rectHeight, topLeft.y, topLeft.z + rectWidth)

--rgb
local colorBlue = {0, 0, 1}
local colorWhite = {1,1,1}
local markId = topLeft:TextToAll(ab:GetName().."\nSome data\n███░░░░░░Line 3\nSome very long line on number four\n", coalition.side.ALL, colorWhite, 1, colorBlue, 0.5, 14, true)
