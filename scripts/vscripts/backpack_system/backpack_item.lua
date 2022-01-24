
--[[
    backpack_system/backpack_item.lua is not required for an entity to stored in the backpack.
    Unlike previous versions of the backpack system, all logic is now handled inside
    backpack_system/backpack_system_core.lua

    This script exists to provide extra functionality to storable items and for backwards compatibility.

    If your entities use custom properties for GrabAngle or GrabOffset, etc, then this script is still
    required to be attached to the entity to capture and save those values.
    These properties can still be set in Hammer on entities that don't have this script attached,
    see 'Property control functions' below for examples of this.

    Entity specific functions are now defined in backpack_system_core.lua but are listed here for help.

    -- These are the functions you'll use most of the time on specific props:

    EnableStorage    - Add this entity's properties to the storable tables as a catch-all.
    DisableStorage   - Remove this entity's properties from the storable tables as a catch-all.
    EnableRetrieval  - Add this entity's properties to the retrieval tables as a catch-all.
    DisableRetrieval - Remove this entity's properties from the retrieval tables as a catch-all.
    PutInBackpack    - Silently puts this entity into the backpack no matter where it is on the map.

    EnableBackpackStorage    - Functionally the same as EnableStorage for backwards compatibility.
    DisableBackpackStorage   - Functionally the same as DisableStorage for backwards compatibility.
    EnableBackpackRetrieval  - Functionally the same as EnableRetrieval for backwards compatibility.
    DisableBackpackRetrieval - Functionally the same as DisableRetrieval for backwards compatibility.

    -- These functions are available for granularity control for specific circumstances as needed:

    EnableClassStorage  - Add this entity's class to the list of storable classes.
    DisableClassStorage - Remove this entity's class from the list of storable classes.
    EnableNameStorage   - Add this entity's name to the list of storable names.
    DisableNameStorage  - Remove this entity's name from the list of storable names.
    EnableModelStorage  - Add this entity's model to the list of storable models.
    DisableModelStorage - Remove this entity's model from the list of storable models.

    EnableClassRetrieval  - Add this entity's class to the list of retrieval classes.
    DisableClassRetrieval - Remove this entity's class from the list of retrieval classes.
    EnableNameRetrieval   - Add this entity's name to the list of retrieval names.
    DisableNameRetrieval  - Remove this entity's name from the list of retrieval names.
    EnableModelRetrieval  - Add this entity's model to the list of retrieval models.
    DisableModelRetrieval - Remove this entity's model from the list of retrieval models.

    -- Property control functions:

    SetStoreSound - Set the sound that plays when this entity is stored.
                    Must be called in the parameter override of RunScriptCode.
        Examples:

        SetStoreSound('Inventory.DepositItem')

    SetRetrieveSound - Set the sound that plays when this entity is retrieved.
                       Must be called in the parameter override of RunScriptCode.
        Examples:

        SetRetrieveSound('Inventory.ClipGrab")

    SetGrabAngle - Set the angle the prop will be rotated to relative to the hand retrieving it.
                   Must be called in the parameter override of RunScriptCode.
                   Can be either a string in 'x y z' format or a QAngle.
        Examples:

        SetGrabAngle('90 180 0')
        SetGrabAngle(Qangle(90, 180, 0))

    SetGrabOffset - Set the offset the item will be positioned relative to the hand retrieving it.
                    Must be called in the parameter override of RunScriptCode.
                    Can be either a string in 'x y z' format or a Vector.
        Examples:

        SetGrabOffset('-1 3.5 0')
        SetGrabOffset(Vector(-1, 3.5, 0))



    --------
    -- I/O
    --------

    These outputs will fire on the entity when interacting with the backpack:

    -- User1 = Entity was put inside backpack.
    -- User2 = Entity was retrieved from backpack.
]]


------------------------------------------------
-- Helper functions, not usually called by I/O
------------------------------------------------
--#region
require "backpack_system.backpack_system_core"

---@type CScriptKeyValues
function Spawn(spawnkeys)
    -- Getting custom keys
    local value = nil
    value = spawnkeys:GetValue("StoreSound")
    if value and value ~= "" then
        thisEntity:SetStoreSound(value)
    end
    value = spawnkeys:GetValue("RetrieveSound")
    if value and value ~= "" then
        thisEntity:SetRetrieveSound(value)
    end
    value = spawnkeys:GetValue("GrabAngle")
    if value and value ~= "" then
        thisEntity:SetGrabAngle(value)
    end
    value = spawnkeys:GetValue("GrabOffset")
    if value and value ~= "" then
        thisEntity:SetGrabOffset(value)
    end

    -- if thisEntity:GetClassname() == "prop_ragdoll" then
    --     print("Checking classes for", thisEntity:GetName(), thisEntity:GetModelName())
    --     print(thisEntity:IsInstance(CBaseEntity))
    --     print(thisEntity:IsInstance(CEntityInstance))
    --     print(thisEntity:IsInstance(CBaseModelEntity))
    --     print(thisEntity:IsInstance(CBasePlayer))
    --     print(thisEntity:IsInstance(CHL2_Player))
    --     print(thisEntity:IsInstance(CBaseAnimating))
    --     print(thisEntity:IsInstance(CBaseFlex))
    --     print(thisEntity:IsInstance(CBaseCombatCharacter))
    --     print(thisEntity:IsInstance(CBodyComponent))
    -- end
end

--#endregion
