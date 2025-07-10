--This class is used to persist airbase state between server restarts
AIRBASEINFO = {
    Name = nil,
    HP = 100, --HP indicates the base overall operational capacity with 100% being 100% operational
    Coalition = coalition.side.NEUTRAL,
    MarkId = nil
}

function AIRBASEINFO:GetTable()
    return {
        Name = self.Name,
        HP = self.HP,
        Coalition = self.Coalition,
        MarkId = self.MarkId
    }
end

function AIRBASEINFO:DrawLabel()
    local BLUE_COLOR_FARP = {0.2,0.2,1}
    local BLUE_COLOR_AIRBASE = {0,0,1}
    local RED_COLOR_FARP = {1,0.2,0.2}
    local RED_COLOR_AIRBASE = {0.8,0,0}
    local COLOR_MAIN_BASE_TEXT = {1,1,1}
    local COLOR_FARP_FRONTLINE_TEXT = {1,1,1}
    local colorFill = {1,0,0}
    local fillAlpha = 0.85
    local colorText = {1,1,1}
    local textAlpha = 1
    local textSize = 14
    local ab = AIRBASE:FindByName(self.Name)
    local coord = ab:GetCoordinate()
    if(not HC:IsFrontlineAirbase(ab) and ab:GetCategory() == Airbase.Category.AIRDROME) then
        colorText = COLOR_MAIN_BASE_TEXT
    else
        colorText = COLOR_FARP_FRONTLINE_TEXT
    end
    if (ab:GetCoalition() == coalition.side.RED) then
        if(ab:GetCategory() == Airbase.Category.AIRDROME) then
            colorFill = RED_COLOR_AIRBASE
        else
            colorFill = RED_COLOR_FARP
        end
    elseif (self.Coalition == coalition.side.BLUE) then
        if(ab:GetCategory() == Airbase.Category.AIRDROME) then
            colorFill = BLUE_COLOR_AIRBASE
        else
            colorFill = BLUE_COLOR_FARP
        end
    else
        colorFill = {1,1,1}
        colorText = {0.2,0.2,0.2}
    end
    if(not HC:IsFrontlineAirbase(ab) and ab:GetCategory() == Airbase.Category.AIRDROME) then
        colorText = {1, 1,0.5}
    end
    if(self.MarkId ~= nil) then
        --env.info("Removing mark "..self.MarkId)
        coord:RemoveMark(self.MarkId)
    end
    local HPIndicator =""
    for i=1, math.floor(self.HP/10) do
        HPIndicator = HPIndicator.."█"
        --HPIndicator = HPIndicator.."+"
    end
    for i=1, 10 - math.floor(self.HP/10) do
        HPIndicator = HPIndicator.."░"
        --HPIndicator = HPIndicator.."_"
    end
    HPIndicator = HPIndicator.." "..tostring(self.HP).." %"
    self.MarkId = coord:TextToAll(" "..ab:GetName().." \n "..HPIndicator.." \n", coalition.side.ALL, colorText, textAlpha, colorFill, fillAlpha, textSize, true)
end 

--airbase - MOOSE AIRBASE object
--hp - airbase state 0-100 with 100 being 100% operational
function AIRBASEINFO:NewFromAIRBASE(airbase, hp)
    local o = {}
    o.Name = airbase:GetName()
    o.HP = hp or 100
    o.Coalition = airbase:GetCoalition()
    o.MarkId = nil
    setmetatable(o, self)
    self.__index = self
    return o
end

function AIRBASEINFO:NewFromTable(table)
    local o = {}
    o.Name = table.Name
    o.HP = table.HP
    o.Coalition = table.Coalition
    o.MarkId = table.MarkId
    setmetatable(o, self)
    self.__index = self
    return o
end    

--Check if base is close to frontline
--@return #bool true if base is close to front line
function AIRBASEINFO:IsFrontline()
    local airbase = AIRBASE:FindByName(self.Name)
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
    local closestEnemyBase = enemyBases:FindNearestAirbaseFromPointVec2(coord) --this just doesn't work
    local dist = coord:Get2DDistance(closestEnemyBase:GetCoordinate())
    return dist <= 50000
end