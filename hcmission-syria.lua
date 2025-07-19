--Initialization script
env.info("Loading script "..lfs.writedir().."Missions/havechips/src/HC.AirbaseInfo.lua")
dofile(lfs.writedir().."Missions/havechips/src/HC.AirbaseInfo.lua")

env.info("Loading script "..lfs.writedir().."Missions/havechips/src/HaveChipsMain.lua")
dofile(lfs.writedir().."Missions/havechips/src/HaveChipsMain.lua")

env.info("Loading script "..lfs.writedir().."Missions/havechips/src/HC.Utils.lua")
dofile(lfs.writedir().."Missions/havechips/src/HC.Utils.lua")

env.info("Loading script "..lfs.writedir().."Missions/havechips/src/HC.Builders.lua")
dofile(lfs.writedir().."Missions/havechips/src/HC.Builders.lua")

env.info("Loading script "..lfs.writedir().."Missions/havechips/src/HC.EventHandlers.lua")
dofile(lfs.writedir().."Missions/havechips/src/HC.EventHandlers.lua")

env.info("Loading script "..lfs.writedir().."Missions/havechips/src/HC.Chief.lua")
dofile(lfs.writedir().."Missions/havechips/src/HC.Chief.lua")

env.info("Starting HaveChips mission")
HC:Start()
