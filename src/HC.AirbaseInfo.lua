env.info("Loading HC.AIRBASEINFO")
--This class is primarily used to persist airbase state between server restarts and track some extras required for scenario in runtime (markers etc.)
---@class AIRBASEINFO
AIRBASEINFO = {
    WPIndex = 99, --Waypoint index
    Name = nil, --Airbase name
    HP = 100, --HP indicates the base overall operational capacity with 100% being 100% operational
    Coalition = coalition.side.NEUTRAL, --Current coalition
    MarkIdFriendly = nil, --Label MarkId on F10 Map for friendly players
    MarkIdEnemy = nil --Label MarkId on F10 Map for enemy players
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

--Sets the HP value and redraws label if necessary
---@param hp number HP amount
function AIRBASEINFO:SetHP(hp)
    if (self.HP ~= hp) then
        self.HP = hp
        self:DrawLabel()
    end
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

    --#region setting up style
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
    local HPIndicator =""
    for i=1, math.floor(self.HP/10) do
        HPIndicator = HPIndicator.."█"
    end
    for i=1, 10 - math.floor(self.HP/10) do
        HPIndicator = HPIndicator.."░"
    end
    local baseTypePrefix = " "
    if (ab:GetCategory() == Airbase.Category.HELIPAD and #(ab.runways) == 0) then
        baseTypePrefix = "FARP"
    end
--#endregion
    
    --remove previous label
    if(self.MarkIdFriendly ~= nil) then
        --env.info("Removing mark "..self.MarkId)
        coord:RemoveMark(self.MarkIdFriendly)
        self.MarkIdFriendly = nil
    end
        if(self.MarkIdEnemy ~= nil) then
        --env.info("Removing mark "..self.MarkId)
        coord:RemoveMark(self.MarkIdEnemy)
        self.MarkIdEnemy = nil
    end
--Possibly could be better to use chief.targetqueue
    local enemyChief = nil
    local enemyCoalition = nil
    local missionListText = ""
    if (ab:GetCoalition() == coalition.side.RED) then
        enemyChief = HC.BLUE.CHIEF
        enemyCoalition = coalition.side.BLUE
    elseif (ab:GetCoalition()  == coalition.side.BLUE) then
        enemyCoalition = coalition.side.RED
        enemyChief = HC.RED.CHIEF
    end

    --Opszone approach
    local friendlyMisionsText = "" --missions by side opposing the current owner
    local enemyMissionsText = "" --missions by current side owner
    local friendlyMissionIds = {}
    local enemyMissionIds = {}
    local oz = OPSZONE:FindByName(self.Name)
    --Missions directly targeting zone
    if(oz) then
        for _, m in pairs(oz.Missions) do
            if (m.Coalition ~= self.Coalition) then
                if (not enemyMissionIds["Anr" ..m.Mission.auftragsnummer]) then
                    enemyMissionsText = enemyMissionsText..string.format(" AI %s [#%s] \n", m.Type, m.Mission.auftragsnummer)
                    enemyMissionIds["Anr" ..m.Mission.auftragsnummer] = true
                end
            else
                if (not friendlyMissionIds["Anr" ..m.Mission.auftragsnummer]) then
                    friendlyMisionsText = friendlyMisionsText..string.format(" AI Friendly %s [#%s] \n", m.Type, m.Mission.auftragsnummer)
                    friendlyMissionIds["Anr" ..m.Mission.auftragsnummer] = true
                end
            end
        end
    end
    --Missions with target in zone
    if (enemyChief) then
        for i=1, #(enemyChief.commander.missionqueue) do
            local m = enemyChief.commander.missionqueue[i]
            local target = m.engageTarget
            if (target) then
                local pos = target:GetCoordinate()
                local thisZone = ZONE:FindByName(self.Name)
                if (not enemyMissionIds["Anr" ..m.auftragsnummer]) then
                    if(m.missionTask ~= "Nothing") then
                        if (thisZone:IsVec3InZone(pos)) then
                            enemyMissionsText = enemyMissionsText..string.format(" AI %s [#%s] \n", m.missionTask, m.auftragsnummer)
                        end
                        enemyMissionIds["Anr" ..m.auftragsnummer] = true
                    end
                end
            end
        end        
    end
    if (enemyCoalition) then
        --friendlies don't get a list of enemy missions targeting the zone
        self.MarkIdFriendly = coord:TextToAll(string.format(" %d. %s %s \n %s %.1f %% \n%s", self.WPIndex,baseTypePrefix, ab:GetName(), HPIndicator, self.HP, friendlyMisionsText), self.Coalition, colorText, textAlpha, colorFill, fillAlpha, textSize, true)
        self.MarkIdEnemy = coord:TextToAll(string.format(" %d. %s %s \n %s %.1f %% \n%s", self.WPIndex,baseTypePrefix, ab:GetName(), HPIndicator, self.HP, enemyMissionsText), enemyCoalition, colorText, textAlpha, colorFill, fillAlpha, textSize, true)        
    else
        --neutral
        self.MarkIdEnemy = coord:TextToAll(string.format(" %d. %s %s \n %s %.1f %% \n%s", self.WPIndex,baseTypePrefix, ab:GetName(), HPIndicator, self.HP, ""), coalition.side.ALL, colorText, textAlpha, colorFill, fillAlpha, textSize, true)        
    end

end 

---Constructor, creates AIRBASE info from AIRBASE object
---@param airbase AIRBASE MOOSE AIRBASE object
---@param hp number Airbase overall operational state 0-100 with 100 being 100% operational
---@return AIRBASEINFO
function AIRBASEINFO:NewFromAIRBASE(airbase, hp)
    local o = {}
    o.WPIndex = 99
    o.Name = airbase:GetName()
    o.HP = hp or 100
    o.Coalition = airbase:GetCoalition()
    o.MarkIdFriendly = nil
    o.MarkIdEnemy = nil
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
    o.MarkIdFriendly = nil
    o.MarkIdEnemy = nil
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

--Apply damage to airbase proportional to "value" of the unit lost
---@param airbaseName string Airbase name
---@unit unit DCSUnit Destroyed unit related to airbase
function AIRBASEINFO.ApplyAirbaseUnitLossPenalty(airbaseName, unit)
    if (not airbaseName or not unit) then
        return
    end
    local damage = HC.CalculateDamageForUnitLost(unit)
    HC:T(string.format("Applying %.1f damage to %s", damage, airbaseName))
    HC:AirbaseResupply(airbaseName, - damage)
end

env.info("HC.AIRBASEINFO loaded")