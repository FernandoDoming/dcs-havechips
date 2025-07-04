Red.Brigade.Base1 = BRIGADE:New("WH_Red_Base1", "Red Base 1")
Red.Brigade.Base1:SetSpawnZone(ZoneRedBase1Spawn)
Red.Brigade.Base1:Start()

Red.Platoon.Platoon1MechanizedRedBase1 = PLATOON:New("RMECH1", 2, "Mechanized Platoon 1 Base 1")
Red.Platoon.Platoon1MechanizedRedBase1:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.ONGUARD, AUFTRAG.Type.CAPTUREZONE, AUFTRAG.Type.ARMORATTACK, AUFTRAG.Type.ARMOREDGUARD})
Red.Platoon.Platoon1MechanizedRedBase1:SetSkill(AI.Skill.EXCELLENT)

Red.Platoon.Platoon2MechanizedRedBase1 = PLATOON:New("RMECH2", 2, "Mechanized Platoon 2 Base 1")
Red.Platoon.Platoon2MechanizedRedBase1:AddMissionCapability({AUFTRAG.Type.GROUNDATTACK, AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.ONGUARD, AUFTRAG.Type.CAPTUREZONE, AUFTRAG.Type.ARMORATTACK, AUFTRAG.Type.ARMOREDGUARD})
Red.Platoon.Platoon2MechanizedRedBase1:SetSkill(AI.Skill.EXCELLENT)

Red.Platoon.Platoon1TransportRedBase1 = PLATOON:New("RTRANS1", 60, "RTRANS1-APC")
Red.Platoon.Platoon1TransportRedBase1:SetAttribute(GROUP.Attribute.GROUND_APC)
-- ser(Red.Platoon.Platoon1TransportRedBase1:GetAttribute())
Red.Platoon.Platoon1TransportRedBase1:AddMissionCapability({AUFTRAG.Type.TROOPTRANSPORT, AUFTRAG.Type.OPSTRANSPORT})
Red.Platoon.Platoon1TransportRedBase1:SetSkill(AI.Skill.EXCELLENT)

Red.Platoon.Platoon1IFVRedBase1 = PLATOON:New("RTRANS1", 60, "RTRANS1-IFV")
Red.Platoon.Platoon1IFVRedBase1:SetAttribute(GROUP.Attribute.GROUND_IFV)
-- ser(Red.Platoon.Platoon1IFVRedBase1:GetAttribute())
Red.Platoon.Platoon1IFVRedBase1:AddMissionCapability({AUFTRAG.Type.TROOPTRANSPORT, AUFTRAG.Type.OPSTRANSPORT})
Red.Platoon.Platoon1IFVRedBase1:SetSkill(AI.Skill.EXCELLENT)


Red.Platoon.Platoon1InfantryRedBase1 = PLATOON:New("RINF1", 30, "Infantry Platoon 1 Base 1")
Red.Platoon.Platoon1InfantryRedBase1:AddMissionCapability({AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.ONGUARD, AUFTRAG.Type.CAPTUREZONE})
Red.Platoon.Platoon1InfantryRedBase1:SetAttribute(GROUP.Attribute.GROUND_INFANTRY)
Red.Platoon.Platoon1InfantryRedBase1:SetSkill(AI.Skill.EXCELLENT)

Red.Platoon.Platoon2InfantryRedBase1 = PLATOON:New("RINF2", 30, "Infantry Platoon 2 Base 1")
Red.Platoon.Platoon2InfantryRedBase1:AddMissionCapability({AUFTRAG.Type.PATROLZONE, AUFTRAG.Type.ONGUARD, AUFTRAG.Type.CAPTUREZONE})
Red.Platoon.Platoon2InfantryRedBase1:SetAttribute(GROUP.Attribute.GROUND_INFANTRY)
Red.Platoon.Platoon2InfantryRedBase1:SetSkill(AI.Skill.EXCELLENT)


Red.Brigade.Base1:AddPlatoon(Red.Platoon.Platoon1TransportRedBase1)
Red.Brigade.Base1:AddPlatoon(Red.Platoon.Platoon1IFVRedBase1)
Red.Brigade.Base1:AddPlatoon(Red.Platoon.Platoon1MechanizedRedBase1)
Red.Brigade.Base1:AddPlatoon(Red.Platoon.Platoon2MechanizedRedBase1)
Red.Brigade.Base1:AddPlatoon(Red.Platoon.Platoon1InfantryRedBase1)
Red.Brigade.Base1:AddPlatoon(Red.Platoon.Platoon2InfantryRedBase1)









function RedTransport()
  env.info("#### Red transpor t  start...")
  RedResourceEmpty, RedResourceInfantry = RedChief:CreateResource(AUFTRAG.Type.ONGUARD, 1, 2, GROUP.Attribute.GROUND_INFANTRY)
  RedResourceOccupied, RedResourceAttackInfantry = RedChief:CreateResource(AUFTRAG.Type.ONGUARD, 3, 8, GROUP.Attribute.GROUND_INFANTRY)

  RedChief:AllowGroundTransport()
  RedChief:AddTransportToResource(RedResourceAttackInfantry, 1, 4, GROUP.Attribute.GROUND_IFV)
  RedChief:AddTransportToResource(RedResourceInfantry, 1, 4, GROUP.Attribute.GROUND_APC)
  RedChief:AddTransportToResource(RedResourceAttackInfantry, 4, 4, GROUP.Attribute.AIR_TRANSPORTHELO)
  RedChief:AddTransportToResource(RedResourceInfantry, 4, 4, GROUP.Attribute.AIR_TRANSPORTHELO)
  env.info("#### Red transport started.")
end
RedTransport()









