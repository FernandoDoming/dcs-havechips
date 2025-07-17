--#region ------------------- Timer events -------------------
function HC:OnBaseRepairTick()
HC:E("BASE REPAIR TICK START")
    for name, abi in pairs(HC.ActiveAirbases) do
        local ab = AIRBASE:FindByName(name)
        abi.Coalition = ab:GetCoalition()
        abi:DrawLabel()
        HC:SetupAirbaseDefense(ab, abi.HP, nil)
    end
HC:E("BASE REPAIR TICK END")
end

function HC:OnLongTick()
    local resupplyPercent = (HC.PASSIVE_RESUPPLY_RATE/3600) * HC.LONG_TICK_INTERVAL
    HC:AirbaseResupplyAll(resupplyPercent)
end

function HC:OnShortTick()    
    for _, abi in pairs(HC.ActiveAirbases) do
        abi:DrawLabel()
    end
end
--#endregion

--#region ------------------- DCS events -------------------

---@param e EVENTDATA Event data
function HC:OnEventKill(e)
    HC:W("HC.EVENT OnEventKill")
    --   Unit.Category
    --   AIRPLANE      = 0,
    --   HELICOPTER    = 1,
    --   GROUND_UNIT   = 2,
    --   SHIP          = 3,
    --   STRUCTURE     = 4
    
    --Object.Category
    --  UNIT    1
    --  WEAPON  2
    --  STATIC  3
    --  BASE    4
    --  SCENERY 5
    --  Cargo   6
    
    if (e and e.IniCategory and e.IniCoalition and e.IniTypeName and e.IniObjectCategory
        and e.TgtCategory and e.TgtCoalition and e.TgtTypeName and e.TgtObjectCategory
        and e.WeaponName) then
        local BDA = string.format("%s %s destroyed %s %s with %s", UTILS.GetCoalitionName(e.IniCoalition), e.IniUnit:GetDesc().displayName, UTILS.GetCoalitionName(e.TgtCoalition), e.TgtDCSUnit:getDesc().displayName, e.weapon:getDesc().displayName)
        MESSAGE:New(BDA, 10):ToAll() --for debugging purposes
        HC:T(BDA)        
    end
end

---@param e EVENTDATA Event data
function HC:OnEventUnitLost(e)
    HC:W("HC.EVENT OnEventUnitLost")
    if (e.IniPlayerName) then
        --Handle player OnEventDead
        return
    end
    if (e.IniObjectCategory == Object.Category.UNIT) then
        local baseName = string.match(e.IniDCSUnitName, '.-||')
        if (not baseName) then
            return
        end
        baseName = string.sub(baseName, 1, string.len(baseName) - 2)
        AIRBASEINFO.ApplyAirbaseUnitLossPenalty(baseName, e.IniDCSUnit)
        HC:T(string.format("Unit %s %s belonging to %s got destroyed", e.IniDCSUnit:getDesc().typeName, e.IniUnitName, baseName))
    elseif(e.IniObjectCategory == Object.Category.STATIC) then
        local baseName = string.match(e.IniDCSUnitName, '.-||')
        if (not baseName) then
            return
        end
        baseName = string.sub(baseName, 1, string.len(baseName) - 2)
        AIRBASEINFO:ApplyAirbaseUnitLossPenalty(baseName, e.IniDCSUnit)
        HC:T(string.format("Static %s % belonging to %s got destroyed", e.IniDCSUnit:getDesc().typeName, e.IniUnitName, baseName))
    end
    return true
end

---@param e EVENTDATA Event data
function HC:OnEventBaseCaptured(e)
    HC:W("HC.EVENT OnEventBaseCaptured")
    return true
end

---@param e EVENTDATA Event data
function HC:OnEventDead(e)
    --HC:W("HC.EVENT OnEventDead")
end

---@param e EVENTDATA Event data
function HC:OnEventMissionEnd(e)
    --HC:W("HC.EVENT OnEventMissionEnd")
end

---@param e EVENTDATA Event data
function HC:OnEventPilotDead(e)
    --HC:W("HC.EVENT OnEventPilotDead")
end

---@param e EVENTDATA Event data
function HC:OnEventShot(e)
    --HC:W("HC.EVENT OnEventShot")
end

---@param e EVENTDATA Event data
function HC:OnEventBDA(e)
    --HC:W("HC.EVENT OnEventBDA")
end

---@param e EVENTDATA Event data
function HC:OnEventTakeoff(e)
    --HC:W("HC.EVENT OnEventTakeoff")
end

---@param e EVENTDATA Event data
function HC:OnEventEjection(e)
    HC:W("HC.EVENT OnEventTakeoff")
end

---@param e EVENTDATA Event data
function HC:OnEventLandingAfterEjection(e)
    -- HC:W("HC.EVENT OnEventLandingAfterEjection")
    -- if (not e.IniPlayerName) then
    --     --that is an AI 
    --     if (e.IniDCSUnit) then
    --         e.IniDCSUnit:destroy()
    --     end
    -- end
end

---@param e EVENTDATA Event data
function HC:OnEventLand(e)
    --HC:W("HC.EVENT OnEventLand")
end

---@param e EVENTDATA Event data
function HC:OnEventDiscardChairAfterEjection(e)
    HC:W("HC.EVENT OnEventDiscardChairAfterEjection")
    if (not e.IniPlayerName) then
        --that is an AI 
        if (e.target) then
            e.target:destroy()
        end
        if(e.IniDCSUnit) then
            Unit.destroy(e.IniDCSUnit)
        end
    end
end


--#endregion

--#region ---------------- OpsZone FSM events --------------
function HC:OnAfterCaptured(From, Event, To, opsZone)
    HC:W("HC.EVENT OPSZONE OnAfterCaptured")
    HC:T("Zone"..opsZone:GetName().." was captured by "..opsZone:GetOwnerName())
    local airbase = AIRBASE:FindByName(opsZone:GetName())
    HC:T("Airbase"..airbase:GetName().." is owned by "..airbase:GetCoalitionName())
    ----------------------------------------------------------------------------------------
    local zoneCoalition = opsZone:GetOwner()
    local airbase = AIRBASE:FindByName(opsZone:GetName())
    local abi = HC.ActiveAirbases[opsZone:GetName()]
    abi.Coalition = zoneCoalition
    abi.HP = 20
    abi:DrawLabel()
    --airbase:SetCoalition(abi.Coalition)
    if (zoneCoalition ~= coalition.side.RED and zoneCoalition ~= coalition.side.BLUE) then
         opsZone:SetDrawZone(true)
         return
    end
    opsZone:SetDrawZone(false)
    HC:AirbaseCleanJunk(airbase:GetName())
    HC:SetupAirbaseInventory(airbase)
    local staticWarehouse = HC:SetupAirbaseStaticWarehouse(airbase)
    HC:SetupAirbaseChiefUnits(staticWarehouse, airbase)
    HC:SetupAirbaseDefense(airbase, abi.HP)
end

function HC:OnAfterEmpty(From, Event, To, opsZone)
    HC:W("HC.EVENT OPSZONE OnAfterEmpty")
    --to do neutralize
end

function HC:OnAfterAttacked(From, Event, To, AttackerCoalition, opsZone)
    HC:W("HC.EVENT OPSZONE OnAfterAttacked")
end
--#endregion


