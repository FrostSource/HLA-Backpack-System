
-- Early exit on maps that will never have backpack.
-- Maps that change backpack state have embedded logic to handle it
-- if vlua.find({
--     "a1_intro_world",
--     "a5_ending"
-- },GetMapName()) then
--     return
-- end

print("BackpackSystem:", "Campaign extension being enabled...")
require "backpack_system.backpack_system_core"

---Initiating values.
local function init(data)
    BackpackSystem.StorableClasses = {
        ["prop_physics"] = true,
        ["prop_physics_override"] = true,
        ["prop_physics_interactive"] = true,
        ["prop_animinteractable"] = true,
        ["prop_dry_erase_marker"] = true,
        ["item_healthvial"] = true,
        ["item_hlvr_health_station_vial"] = true,
        ["item_hlvr_prop_battery"] = true,
        ["func_physbox"] = true,
    }
    Storage.SaveTable(Player, "BackpackSystem.StorableClasses", BackpackSystem.StorableClasses)

    BackpackSystem.RetrievalClassInventory = {
        ["prop_physics"] = true,
        ["prop_physics_override"] = true,
        ["prop_physics_interactive"] = true,
        ["prop_animinteractable"] = true,
        ["prop_dry_erase_marker"] = true,
        ["item_healthvial"] = true,
        ["item_hlvr_health_station_vial"] = true,
        ["item_hlvr_prop_battery"] = true,
        ["func_physbox"] = true,
    }
    Storage.SaveTable(Player, "BackpackSystem.RetrievalClassInventory", BackpackSystem.RetrievalClassInventory)

    BackpackSystem.PlayerHasRealBackpack = true
    Storage.SaveBoolean(Player, "BackpackSystem.PlayerHasRealBackpack", BackpackSystem.PlayerHasRealBackpack)
    -- Require no weapon because map might start with ammo which cannot be tracked!
    BackpackSystem.RequireNoWeapon = true
    Storage.SaveBoolean(Player, "BackpackSystem.RequireNoWeapon", BackpackSystem.RequireNoWeapon)
    -- Can only retrieve prop when no weapon equipped or no ammo for equipped weapon
    BackpackSystem.RequireNoAmmo = true
    Storage.SaveBoolean(Player, "BackpackSystem.RequireNoAmmo", BackpackSystem.RequireNoAmmo)
    -- battery has large mass, size is more important to limit props
    BackpackSystem.LimitMass = 150
    BackpackSystem.LimitSize = 1000
    BackpackSystem.MaxItems = 50
    Storage.SaveNumber(Player, "BackpackSystem.LimitMass", BackpackSystem.LimitMass)
    Storage.SaveNumber(Player, "BackpackSystem.LimitSize", BackpackSystem.LimitSize)
    Storage.SaveNumber(Player, "BackpackSystem.MaxItems", BackpackSystem.MaxItems)


    -- print("Looking for extension trigger")
    -- ---@type EntityHandle
    -- local extension_transition
    -- for _, transition in ipairs(Entities:FindAllByClassname("trigger_transition")) do
    --     if vlua.find(transition:GetModelName(), "campaign_extension") then
    --         extension_transition = transition
    --         print("Found transition model", transition:GetName(), transition:GetModelName())
    --         break
    --     end
    -- end
    -- for _, transition in ipairs(Entities:FindAllByClassname("trigger_transition")) do
    --     if not vlua.find(transition:GetModelName(), "campaign_extension")
    --         and transition:GetName() == extension_transition:GetName() then
    --         -- extension_transition:SetModel(transition:GetModelName())
    --         -- print("Switched transition model to", transition:GetModelName())
    --         transition:SetAbsScale(5)
    --         print("scaled transition model")
    --         break
    --     end
    -- end
    -- print("Done looking for extension trigger")

    -- Fix for awkward map transition in first level.
    -- Valve apparently did not consider addons too carefully.
    local map = GetMapName()
    if map == "a1_intro_world" then
        local command = Entities:FindByName(nil, "command_change_level")
        if command then
            command:Kill()
            DoEntFire("relay_stun_player", "AddOutput", "OnTrigger>@fix_a1_intro_world_transition>Enable>>1.5>1", 0, Player, Player)
        end
    elseif map == "a5_ending" then
        BackpackSystem:ClearBackpack()
        BackpackSystem:Disable()
    else
        local transition_fix_maps =
        {
            a3_station_street         = "landmark_hotel_street_entrance",
            a3_hotel_lobby_basement   = "landmark_hotel_lobbybasement_pit",
            a3_hotel_underground_pit  = "landmark_pit_hotel_interior",
            a3_hotel_interior_rooftop = "landmark_hotel_to_street",
            a3_hotel_street           = "landmark_hotel_warehouse",
            a3_distillery             = "landmark_tunnel",
            a4_c17_tanker_yard        = "landmark_antlions_3",
            a4_c17_water_tower        = "landmark_antlions_to_strider",
            a4_c17_parking_garage     = "landmark_strider_to_vault",
        }
        if vlua.contains(transition_fix_maps, map) then
            local t = Entities:FindByName(nil, "@transition_name_fix")
            if t then
                print("Fixing "..map.." transition trigger name...")
                t:SetEntityName(transition_fix_maps[map])
            end
        end
    end
    -- elseif map == "a3_station_street" then
    --     local t = Entities:FindByName(nil, "@transition_name_fix")
    --     if t then
    --         print("Fixing a3_station_street transition trigger name...")
    --         t:SetEntityName("landmark_hotel_street_entrance")
    --     end
    -- elseif map == "a3_hotel_lobby_basement" then

    --     local t = Entities:FindByName(nil, "@transition_name_fix")
    --     if t then
    --         print("Fixing a3_hotel_lobby_basement transition trigger name...")
    --         t:SetEntityName("landmark_hotel_lobbybasement_pit")
    --     end
    -- end



end
RegisterPlayerEventCallback("vr_player_ready", init)




