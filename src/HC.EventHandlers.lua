function HC:OnShortTick()
    for i=1, #(HC.ActiveAirbases) do
        local abi = HC.ActiveAirbases[i]
        local ab = AIRBASE:FindByName(abi.Name)
        abi.Coalition = ab:GetCoalition()
        abi:DrawLabel()
    end
end

function HC:OnLongTick()
    --This will go in long tick!
    local resupplyPercent = (HC.PASSIVE_RESUPPLY_RATE/3600) * HC.LONG_TICK_INTERVAL
    HC:AirbaseResupply(resupplyPercent) 
end

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
        local BDA = string.format("%s %s destroyed %s %s with %s", UTILS.GetCoalitionName(e.IniCoalition), e.IniTypeName, UTILS.GetCoalitionName(e.TgtCoalition), e.TgtTypeName, e.WeaponName)
        HC:W(BDA)
        MESSAGE:New(BDA, 10):ToAll()

        --if unit is ground unit - damage airbase where it was destroyed
        --if unit is air unit - damage airbase from which it came from
        if(e.TgtObjectCategory == Object.Category.UNIT or e.TgtObjectCategory == Object.Category.STATIC) then
            --Find which airbase and apply damage
            if (e.TgtDCSUnit) then
                local position = e.TgtDCSUnit:getPosition() --x,y,z
                local tgtCoalitionName = UTILS.GetCoalitionName(e.TgtCoalition)
                local friendlyBases = SET_AIRBASE:New():FilterCoalitions(string.lower(tgtCoalitionName)):FilterOnce()
                friendlyBases:ForEachAirbase(
                    function(b)
                        HC:T("Base in filtered set "..b:GetCoalitionName().." "..b:GetName())
                    end
                )
                local coord = COORDINATE:NewFromVec3(position.p)
                local b, dist = coord:GetClosestAirbase()
                if (dist <= 2500 and b:GetCoalition() == e.TgtCoalition) then
                    --Unit killed within friendly airbase/FARP range
                    HC:T(string.format("Unit killed %d from %s, should apply damage to airbase", dist, b:GetName()))
                    local abi = HC.ActiveAirbases[b:GetName()]
                    if (abi) then
                        --placeholder, damage will be calculated based on unit type
                        abi.HP = math.max(0, abi.HP -5)                         
                    end
                end
            end
        end
    end    
end

---@param e EVENTDATA Event data
function HC:OnEventBaseCaptured(e)
    HC:W("HC.EVENT OnEventBaseCaptured")
    return true
end

---@param e EVENTDATA Event data
function HC:OnEventDead(e)
    HC:W("HC.EVENT OnEventDead")
end

---@param e EVENTDATA Event data
function HC:OnEventMissionEnd(e)
    HC:W("HC.EVENT OnEventMissionEnd")
end

---@param e EVENTDATA Event data
function HC:OnEventPilotDead(e)
    HC:W("HC.EVENT OnEventPilotDead")
end

---@param e EVENTDATA Event data
function HC:OnEventShot(e)
    HC:W("HC.EVENT OnEventShot")
end

---@param e EVENTDATA Event data
function HC:OnEventBDA(e)
    HC:W("HC.EVENT OnEventBDA")
end

---@param e EVENTDATA Event data
function HC:OnEventTakeoff(e)
    HC:W("HC.EVENT OnEventTakeoff")
end

---@param e EVENTDATA Event data
function HC:OnEventEjection(e)
    HC:W("HC.EVENT OnEventTakeoff")
end

---@param e EVENTDATA Event data
function HC:OnEventLandingAfterEjection(e)
    HC:W("HC.EVENT OnEventLandingAfterEjection")
    if (not e.IniPlayerName) then
        --that is an AI 
        if (e.IniDCSUnit) then
            e.IniDCSUnit:destroy()
        end
    end
end

---@param e EVENTDATA Event data
function HC:OnEventLand(e)
    HC:W("HC.EVENT OnEventLand")
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
    local airbase = AIRBASE:FindByName(opsZone:GetName())
    local abi = HC.ActiveAirbases[opsZone:GetName()]
    abi.Coalition = opsZone:GetOwner()
    abi.HP = 20
    abi:DrawLabel()
    airbase:SetCoalition(abi.Coalition)
    HC:SetupAirbaseInventory(airbase)
    local staticWarehouse = HC:SetupAirbaseStaticWarehouse(airbase)
    HC:SetupAirbaseChiefUnits(staticWarehouse, airbase)
    HC:SetupAirbaseDefense(airbase, abi.HP)
end

function HC:OnAfterEmpty(From, Event, To, opsZone)
    HC:W("HC.EVENT OPSZONE OnAfterEmpty")
    --to do neutralize
end

function HC:OnAfterAttacked(HC, From, Event, To, AttackerCoalition, self)
    HC:W("HC.EVENT OPSZONE OnAfterAttacked")
end
--#endregion


