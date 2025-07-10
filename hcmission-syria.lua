--Initialization script
env.info("Loading script "..lfs.writedir().."Missions/havechips/src/HaveChipsMain.lua")
dofile(lfs.writedir().."Missions/havechips/src/HaveChipsMain.lua")
env.info("Running mission")


-- MESSAGE:New("Spawning red SEAD at Kutaisi",  20):ToAll()

-- --Spawn a red SEAD group using a random template
-- --once spawned, assign a mission to destroy a specific radar unit

-- local redSEAD = SPAWN:New(HC.TEMPLATES.RED.SEAD[1])
-- :OnSpawnGroup(function(grp)
--     MESSAGE:New("Red SEAD at Kutaisi spawned",  20):ToAll()
--     local Target = TARGET:New(GROUP:FindByName("bs_a1"))
--     local auftrag = AUFTRAG:NewSEAD(Target, 4000)
--     auftrag:SetMissionSpeed(500)
--     env.info("[HaveChips] Adding mission to Red SEAD "..grp.GroupName)
--     local flightGroup = FLIGHTGROUP:New(grp)   
--     flightGroup:AddMission(auftrag)
-- end
-- )
-- :InitRandomizeTemplate(HC.TEMPLATES.RED.SEAD)
-- :SpawnAtAirbase( AIRBASE:FindByName( AIRBASE.Caucasus.Kutaisi ), SPAWN.Takeoff.Runway )

-- --Spawn red SHORAD in randomized air defense zone
-- --Each airbase and FARP should have AD spawn zones defined to avoid random spawns in forrests, cities etc...
-- MESSAGE:New("Spawning red SHORAD at Kutaisi",  20):ToAll()
-- local spawnZones = {ZONE:FindByName("AD_SPAWN_ZONE_1"), ZONE:FindByName("AD_SPAWN_ZONE_2")}
-- local redSHORAD = SPAWN:New(HC.TEMPLATES.RED.SHORAD[1])
-- :OnSpawnGroup(function(grp)
--     env.info("[HaveChips] Red SHORAD at Kutaisi spawned")
--     MESSAGE:New("Red SHORAD at Kutaisi spawned",  20):ToAll()
-- end
-- )
-- :InitRandomizeTemplate(HC.TEMPLATES.RED.SHORAD)
-- :InitRandomizeZones( spawnZones )
-- redSHORAD:Spawn()


