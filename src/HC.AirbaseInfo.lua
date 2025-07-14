env.info("Loading HC.AIRBASEINFO")
--This class is primarily used to persist airbase state between server restarts and track some extras required for scenario in runtime (markers etc.)
AIRBASEINFO = {
    WPIndex = 99, --Waypoint index
    Name = nil, --Airbase name
    HP = 100, --HP indicates the base overall operational capacity with 100% being 100% operational
    Coalition = coalition.side.NEUTRAL, --Current coalition
    MarkId = nil --Label MarkId on F10 Map
}

--Gets Data table to be persisted on mission restarts
---@return table #Data table to be persisted on mission restarts
function AIRBASEINFO:GetTable()
    return {
        WPIndex = self.WPIndex,
        Name = self.Name,
        HP = self.HP,
        Coalition = self.Coalition
    }
end

-- Draws airbase or FARP label on F10 map
function AIRBASEINFO:DrawLabel()
    local BLUE_COLOR_FARP = {0.2,0.2,1}
    local BLUE_COLOR_AIRBASE = {0,0,1}
    local RED_COLOR_FARP = {1,0.2,0.2}
    local RED_COLOR_AIRBASE = {0.8,0,0}
    local COLOR_MAIN_BASE_TEXT = {1,1,1}
    local COLOR_FARP_FRONTLINE_TEXT = {1,1,1}
    local colorFill = {1,0,0}
    local fillAlpha = 0.7
    local colorText = {1,1,1}
    local textAlpha = 1
    local textSize = 12
    local ab = AIRBASE:FindByName(self.Name)
    local coord = ab:GetCoordinate()
    if(not self:IsFrontline(ab) and ab:GetCategory() == Airbase.Category.AIRDROME) then
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
        colorText = {0.3,0.3,0.3}
    end
    if(not self:IsFrontline(ab) and ab:GetCategory() == Airbase.Category.AIRDROME) then
        colorText = {1, 1, 0.5}
    end
    if(self.MarkId ~= nil) then
        --env.info("Removing mark "..self.MarkId)
        coord:RemoveMark(self.MarkId)
    end
    local HPIndicator =""
    for i=1, math.floor(self.HP/10) do
        HPIndicator = HPIndicator.."█"
    end
    for i=1, 10 - math.floor(self.HP/10) do
        HPIndicator = HPIndicator.."░"
    end
    local baseTypePrefix = " "
    if (ab:GetCategory() == Airbase.Category.HELIPAD) then
        baseTypePrefix = "FARP"
    end

    --Possibly could be better to use chief.targetqueue
    local enemyChief = nil
    local missionListText = ""
    if (ab:GetCoalition() == coalition.side.RED) then
        enemyChief = HC.BLUE.CHIEF
    elseif (ab:GetCoalition()  == coalition.side.BLUE) then
        enemyChief = HC.RED.CHIEF
    end

    for i=1, #(enemyChief.commander.missionqueue) do
        local mission = enemyChief.commander.missionqueue[i]
        local target = mission.engageTarget
        if (target) then
            local pos = target:GetCoordinate()
            local thisZone = ZONE:FindByName(self.Name)
            if(mission.missionTask ~= "Nothing") then
                if (thisZone:IsVec3InZone(pos)) then
                    missionListText = missionListText..string.format(" AI %s \n", mission.missionTask)
                end                
            end
        end
    end

    self.MarkId = coord:TextToAll(string.format(" %d. %s %s \n %s %.1d %% \n%s", self.WPIndex,baseTypePrefix, ab:GetName(), HPIndicator, self.HP, missionListText), coalition.side.ALL, colorText, textAlpha, colorFill, fillAlpha, textSize, true)
end 

---Constructor, creates AIRBASE info from AIRBASE object
---@param airbase AIRBASE MOOSE AIRBASE object
---@param hp number Airbase overall operational state 0-100 with 100 being 100% operational
---@return AIRBASEINFO
function AIRBASEINFO:NewFromAIRBASE(airbase, hp)
    local o = {}
    WPIndex = 99
    o.Name = airbase:GetName()
    o.HP = hp or 100
    o.Coalition = airbase:GetCoalition()
    o.MarkId = nil
    setmetatable(o, self)
    self.__index = self
    return o
end

---Constructor, creates AIRBASE info from Lua table object
---@param table table #Data table to load from
---@return AIRBASEINFO
function AIRBASEINFO:NewFromTable(table)
    local o = {}
    o.WPIndex = table.WPIndex or 99
    o.Name = table.Name
    o.HP = table.HP
    o.Coalition = table.Coalition
    o.MarkId = nil
    setmetatable(o, self)
    self.__index = self
    return o
end    

--Check if base is close to frontline
---@return boolean #true if base is close to front line
function AIRBASEINFO:IsFrontline()
    local airbase = AIRBASE:FindByName(self.Name)
    return HC:IsFrontlineAirbase(airbase)
end
env.info("HC.AIRBASEINFO loaded")