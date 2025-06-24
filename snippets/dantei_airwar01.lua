
AW = {
    Blue = {},
    Red = {},
}

function AW:CreateChiefs()
    self:CreateChief('Blue', coalition.side.BLUE)
    self:CreateChief('Red', coalition.side.RED)
    env.info('[AW] Chiefs created')
end
function AW:CreateChief(color, side)
    env.info('[AW] Create '..color..' Chief for side ' .. tostring(side))
    local agents = SET_GROUP:New():FilterPrefixes('Blue-AWACS'):FilterPrefixes('Blue-AWACS'):FilterOnce()
    env.info('[AW] Found '..tostring(agents:Count())..' agents')
    
    self[color].Agents = SET_GROUP:New():FilterPrefixes(color..'-EWR'):FilterPrefixes(color..'-AWACS'):FilterOnce()
    self[color].Chief = CHIEF:New(side, self[color].Agents)
    self[color].Chief:SetStrategy(CHIEF.Strategy.TOTALWAR)
    self[color].Chief:SetTacticalOverviewOn()
    --local border=ZONE:New("RED_BORDER")
    --RED_CHIEF:AddBorderZone(border)
    self[color].Chief:__Start(1)
    env.info('[AW] '..color..' Chief created with ' .. self[color].Agents:Count() .. ' agent and TOTALWAR strategy')
end

function AW:ImportAllWarehouses()
    local logPrefix = '[AW:ImportAllWarehouses] '
    env.info(logPrefix..'Run ...')
    local warehouses = STATIC:FindAllByMatching('^Warehouse-')
    env.info(logPrefix..'Found ' .. #warehouses .. ' warehouses')
    for i, wh in ipairs(warehouses) do
        local side = wh:GetCoalition()
        local sideName = wh:GetCoalitionName()
        env.info(string.format('%s %3d. Warehouse "%s" (%s)', logPrefix, i, wh:GetName(), sideName))
    end
    env.info(logPrefix..' Done.')
end

function AW:ImportAirbases()
    local logPrefix = '[AW:ImportAirbases] '
    env.info(logPrefix..'Run ...')
    local airbases = AIRBASE.GetAllAirbases()
    env.info(logPrefix..'Found ' .. #airbases .. ' airbases')
    for i, ab in ipairs(airbases) do
        env.info(string.format('%s %3d. Airbsae "%s" (%s)', logPrefix, i, ab:GetName(), ab:GetCoalitionName()))
        local wh = STATIC:FindByName('Warehouse-' .. ab:GetName(), false)
        if wh then
            env.info(string.format('%s      Found warehouse "%s" (%s)', logPrefix, wh:GetName(), wh:GetCoalitionName()))
            if ab:GetCoalition() ~= wh:GetCoalition() then
                ab:SetCoalition(wh:GetCoalition())
                env.info(string.format('%s      Set airbase coalition to %s', logPrefix, ab:GetCoalitionName()))
            end
            self:ImportAirbase(ab, wh)
        end
    end
    env.info(logPrefix..' Done.')
end


function AW:ImportAirbase(airbase, warehouse)
    local logPrefix = '[AW:ImportAirbase|'..tostring(airbase)..'|'..tostring(warehouse)..'] '
    env.info(logPrefix..'Run ...')
    side = airbase:GetCoalition()
    local opsZone = OPSZONE:New(airbase.AirbaseZone, side)
    opsZone:SetDrawZone(true)
    env.info(logPrefix..'OpsZone initialized')
    self.Blue.Chief:AddStrategicZone(opsZone)
    self.Red.Chief:AddStrategicZone(opsZone)
    env.info(logPrefix..'Added zone as strategic zone to both Chiefs')

    local wingName = 'Wing-'..airbase:GetName()
    local brigName = 'Brig-'..airbase:GetName()
    env.info(logPrefix..'Create airbase troops "'..wingName..'" & "'..brigName..'" ...')

    if (side == coalition.side.RED) then
        self:AddBlueAirwing(warehouse:GetName(), wingName, self.Red.Chief)
        self:AddBlueBrigade(warehouse:GetName(), wingName, self.Red.Chief)
    elseif (side == coalition.side.BLUE) then
        self:AddBlueAirwing(warehouse:GetName(), wingName, self.Blue.Chief)
        self:AddBlueBrigade(warehouse:GetName(), wingName, self.Blue.Chief)
    end

    env.info(logPrefix..' Done.')
end


function AW:AddBlueAirwing(warehouseName, wingName, chief)
    env.info(string.format('[AW] Create airwing "%s" for warehouse "%s" ...', wingName, warehouseName))
    local wing = AIRWING:New(warehouseName, wingName)

    local interceptSquad = SQUADRON:New("F-15C Group", 8, wingName..": TF-42 Blue Ballers")
    interceptSquad:AddMissionCapability({AUFTRAG.Type.INTERCEPT})
    env.info(string.format('[AW] Created INTERCEPT squad'))

    local capSquad = SQUADRON:New("F/A-18C Group", 8, wingName..": TF-69 Punslingers")
    capSquad:AddMissionCapability({AUFTRAG.Type.GCICAP})
    env.info(string.format('[AW] Created CAP squad'))

    local casReconSquad = SQUADRON:New("A-10CII Group", 4, wingName..": TF-10 Hoggiteers")
    casReconSquad:AddMissionCapability({AUFTRAG.Type.CAS, AUFTRAG.Type.RECON})
    env.info(string.format('[AW] Created CAS&RECON squad'))

    wing:AddSquadron(interceptSquad)
    wing:AddSquadron(capSquad)
    wing:AddSquadron(casReconSquad)
    env.info(string.format('[AW] Added squdrons to wing'))
    wing:NewPayload(GROUP:FindByName("BLUE_F-15C_120C-1"), 8, {AUFTRAG.Type.INTERCEPT}, 100)
    wing:NewPayload(GROUP:FindByName("BLUE_F/A-18C_120C-1"), 8, {AUFTRAG.Type.GCICAP}, 100)
    wing:NewPayload(GROUP:FindByName("BLUE_A-10CII_Maverick-1"), 8, {AUFTRAG.Type.CAS, AUFTRAG.Type.RECON}, 100)
    env.info(string.format('[AW] Defined payloads'))

    wing:Start()
    env.info(string.format('[AW] Wing started'))
    chief:AddAirwing(wing)
    env.info(string.format('[AW] Wing added to Chief'))
end

function AW:AddBlueBrigade(warehouseName, brigName, chief)
    local logPrefix = '[AW:AddBlueBrigade|'..tostring(warehouseName)..'|'..tostring(brigName)..'|..] '
    local brig = BRIGADE:New(warehouseName, brigName)
    env.info(logPrefix..'Brigade "'..brigName..'" at warehouse "'..warehouseName..'" initialized')

    --brig:SetSpawnZone(ZONE:New(brigName..'-Spawn'))
    --env.info(logPrefix..'Brigade "'..brigName..'"\'s spawn zone set to: '..brigName..'-Spawn')

    local templateName = 'Template-Abrams'
    local mbts = PLATOON:New(templateName, 15*1, brigName..'-Tanks')
    mbts:SetGrouping(3)
    mbts:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.ONGUARD, AUFTRAG.Type.CAPTUREZONE}, 90)
    brig:AddPlatoon(mbts)
    env.info(logPrefix..'Brigade "'..brigName..'"\'s Tank platoon initialized and added (from '..templateName..')')

    chief:AddBrigade(brig)
    env.info(logPrefix..'Brigade "'..brigName..'" added to Chief')
end



AW:CreateChiefs()
AW:ImportAirbases()
