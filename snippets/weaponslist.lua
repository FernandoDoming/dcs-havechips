if Era == 'Coldwar' then
  env.info('Cold war is on')
 
 local restrictedWeapons = {
    "weapons.missiles.AIM_120C",
    "weapons.missiles.AIM_120",
    "weapons.missiles.AGM_154",
    "weapons.missiles.AIM_54C_Mk47",
    "weapons.missiles.AIM_54C_Mk60",
    "weapons.missiles.AIM_9X",
    "weapons.bombs.GBU_31_V_4B",
    --"weapons.missiles.AGM_65F",
    "weapons.bombs.CBU_105",
    "weapons.bombs.CBU_103",
    "weapons.bombs.CBU_97",
    "weapons.bombs.GBU_28",
    "weapons.bombs.GBU_31",
    "weapons.bombs.GBU_31_V_2B",
    "weapons.bombs.GBU_31_V_3B",
    "weapons.bombs.GBU_32_V_2B",
    "weapons.bombs.GBU_38",
    "weapons.bombs.GBU_39",
    "weapons.bombs.GBU_54_V_1B",
    "weapons.bombs.KAB_500S",
    "weapons.bombs.KAB_1500LG",
    "weapons.bombs.KAB_1500T",
    "weapons.bombs.LS_6_100",
    "weapons.bombs.GBU-43/B(MOAB)",
    "weapons.missiles.ADM_141A",
    "weapons.missiles.ADM_141B",
    "weapons.missiles.AGM_119",
    "weapons.missiles.AGM_130",
    "weapons.missiles.AGM_154A",
    "weapons.missiles.AGM_154B",
    "weapons.missiles.AGM_65G",
    "weapons.missiles.AGM_65H",
    "weapons.missiles.AGM_65K",
    "weapons.missiles.AGM_65L",
    "weapons.missiles.AGM_84E",
    "weapons.missiles.AGM_84H",
    "weapons.missiles.AGM_86C",
    "weapons.missiles.ALARM",
    "weapons.missiles.Ataka_9M120",
    "weapons.missiles.Ataka_9M120F",
    "weapons.missiles.Ataka_9M220",
    "weapons.missiles.Vikhr_M",
    "weapons.missiles.BK90_MJ1",
    "weapons.missiles.BK90_MJ2",
    "weapons.missiles.BK90_MJ1_MJ2",
    "weapons.missiles.BRM-1_90MM",
    "weapons.missiles.C_701T",
    "weapons.missiles.C_802AK",
    "weapons.missiles.CM-400AKG",
    "weapons.missiles.CM-802AKG",
    "weapons.missiles.DWS39_MJ1",
    "weapons.missiles.DWS39_MJ2",
    "weapons.missiles.DWS39_MJ1_MJ2",
    "weapons.missiles.GB-6",
    "weapons.missiles.GB-6-HE",
    "weapons.missiles.GB-6-SFW",
    "weapons.missiles.HJ-12",
    "weapons.missiles.HOT3_MBDA",
    "weapons.missiles.KD_20",
    "weapons.missiles.KD_63",
    "weapons.missiles.KD_63B",
    "weapons.missiles.LD-10",
    "weapons.missiles.LS_6",
    "weapons.missiles.LS_6_500",
    "weapons.missiles.MICA_R",
    "weapons.missiles.MICA_T",
    "weapons.missiles.Mistral",
    "weapons.missiles.PL-12",
    "weapons.missiles.PL-5EII",
    "weapons.missiles.PL-8B",
    "weapons.missiles.S_25L",
    "weapons.missiles.SD-10",
    "weapons.missiles.SPIKE_ER",
    "weapons.missiles.SPIKE_ER2",
    "weapons.missiles.TGM_65G",
    "weapons.missiles.TGM_65H",
    "weapons.missiles.X_35",
    "weapons.missiles.X_41",
    "weapons.missiles.X_59M",
    "weapons.missiles.YJ-12",
    "weapons.missiles.YJ-83",
    "weapons.containers.ALQ-184",
    "weapons.containers.alq-184long",
    --"weapons.containers.AN_ASQ_228",
     "weapons.missiles.AGM_114",
     "weapons.missiles.AGM_114K",
}

local allowedPlanes = {
  "L-39ZA","MiG-19P","I-16","Su-17M4","Mirage-F1AD","F/A-18A","C5_Galaxy","Su-24MR","F-4E-45MC","MiG-23MLD","P-47D-40","Mirage-F1CR","SA342Mistral",
  "Mi-24V","F-15E","F-117A","SH-60B","AJS37","Tornado IDS","UH-1H","A-20G","MiG-25RBT","SH-3W","MB-339A","RQ-1A Predator","MiG-25PD","F-14A-135-GR",
  "C-101EB","F-15C","F-16A MLU","Mirage-F1BD","P3C_Orion","Mirage-F1M-EE","An-30M","AH-64A","MQ-9 Reaper","F-5E-3_FC","Mirage-F1EQ","A-10A","FW-190D9",
  "Mirage-F1M-CE","Mirage-F1ED","C-17A","Tornado GR3","Ka-27","E-2C","UH-60A","Mirage-F1C","Mirage-F1CE","AH-1W","MiG-21Bis","A400M_Atlas","Mirage-F1BE",
  "MB-339APAN","An-26B","Hercules","Su-25","Falcon_Gyrocopter","CH-47D","SA342M","Mirage-F1EDA","WingLoong-I","OH58D","MiG-15bis_FC","Mirage-F1CZ",
  "Mirage-F1BQ","Mirage-F1B","Yak-52","Mirage-F1C-200","Mirage-F1DDA","MiG-15bis","CH-53E","Mirage-F1CJ","FW-190A8","Mirage-F1CK","Mirage-F1AZ",
  "P-47D-30","Mirage-F1CT","A-10C","TF-51D","Hawk","P-51D","M-2000C","Mirage-F1EH","Mirage-F1CH","MosquitoFBMkVI","SA342Minigun","MiG-29A",
  "Mirage-F1CG","C-130","F-5E-3","E-3A","F-86F Sabre","Christen Eagle II","F-14A","SpitfireLFMkIX","KJ-2000","L-39C","C-101CC","SA342L","C2A_Greyhound",
  "Mi-8MT","Yak-40","P-51D-30-NA","SpitfireLFMkIXCW","Bf-109K-4","Mirage-F1EE","Mi-28N","MiG-27K","Mi-26","Mi-24P","CH-47Fbl1","FA-18C_hornet","F-16C_50"
} 

  local airbaseList,seen={},{}
  for _,zone in pairs(zones) do
    local n=zone.airbaseName
    if n and not seen[n] then seen[n]=true airbaseList[#airbaseList+1]=n end
  end
  for _,n in ipairs({"CVN-72","CVN-73","Tarawa"}) do
    if not seen[n] then seen[n]=true airbaseList[#airbaseList+1]=n end
  end
  



for _, airbaseName in ipairs(airbaseList) do
  local storage = STORAGE:FindByName(airbaseName)
  if storage then
    local aircraft = storage:GetInventory()
    for name,_ in pairs(aircraft) do
      storage:SetItem(name,0)
    end
    for _,plane in ipairs(allowedPlanes) do
      storage:SetItem(plane,1000)
    end
    for _,weapon in ipairs(restrictedWeapons) do
      local amount = storage:GetItemAmount(weapon)
      if amount > 0 then
        storage:RemoveItem(weapon,amount)
      end
    end
  end
end


--[[ 
local restrictedPlanes = {
    "F-15ESE",
    "AV8BNA",
    "AH-64D_BLK_II",
    "F-16C_50",
    "F-14B",
    "FA-18C_hornet",
    "A-10C_2",
    "Su-25T",
    "Su-25TM",
    "Su-27",
    "Su-33",
    "Su-30",
    "Su-34",
    "J-11A",
    "MiG-29G",
    "MiG-29S",
    "MiG-31",
    "Mi-24P",
    "Ka-50",
    "Ka-50_3",
    "Mirage 2000-5",
    "JF-17",
}

for _, airbaseName in ipairs(airbaseList) do
    local storage = STORAGE:FindByName(airbaseName)

    if storage then
        -- weapons
        for _, weapon in ipairs(restrictedWeapons) do
            local amount = storage:GetItemAmount(weapon)
            if amount > 0 then
                storage:RemoveItem(weapon, amount)
                --env.info(string.format("Removed %d of %s from %s", amount, weapon, airbaseName))
            else
                --env.info(string.format("No %s found at %s", weapon, airbaseName))
            end
        end
        -- planes & helicopters
        for _, plane in ipairs(restrictedPlanes) do
            local amount = storage:GetItemAmount(plane)
            if amount > 0 then
                storage:RemoveItem(plane, amount)
                --env.info(string.format("Removed %d of %s from %s", amount, plane, airbaseName))
            else
                --env.info(string.format("No %s found at %s", plane, airbaseName))
            end
        end
    else
        --env.info("Storage not found for airbase: " .. airbaseName)
    end
end
 ]]
end