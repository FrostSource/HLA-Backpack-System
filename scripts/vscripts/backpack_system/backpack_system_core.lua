--[[
    v1.0.0
    Base logic script for the custom backpack System.

    Add 'maps\prefabs\backpack_system\backpack_system_logic.vmap' to your map for this script to initiate on map load.


]]

-- If this script is attached to an entity then it will first require itself into global scope..
-- then add useful entity functions to the private script scope allowing for easier Hammer control.
if thisEntity then

require "util.util"
local src = GetScriptFile()
print("Backpack system is starting in entity scope", thisEntity:GetClassname(), src)
require(src)

--------------------
-- User Functions --
--------------------
--#region

---Enable backpack functionality.
local function EnableBackpack()
    BackpackSystem:Enable()
end

---Disable backpack functionality.
local function DisableBackpack()
    BackpackSystem:Disable()
end

---Disable backpack storage of any item, globally.
local function DisableAllBackpackStorage()
    BackpackSystem:DisableAllStorage()
end

---Enable backpack storage of items. Specific items disabled will stay disabled.
local function EnableAllBackpackStorage()
    BackpackSystem:EnableAllStorage()
end

---Disable retrieval of any item, globally.
local function DisableAllBackpackRetrieval()
    BackpackSystem:DisableAllRetrieval()
end

---Enable retrieval of items. Specific items disabled will stay disabled.
local function EnableAllBackpackRetrieval()
    BackpackSystem:EnableAllRetrieval()
end

---Give the base Alyx backpack to the player.
local function GiveRealBackpack()
    BackpackSystem.PlayerHasRealBackpack = true
    BackpackSystem:EnableRealBackpack()
end

---Remove the base Alyx backpack from the player.
local function RemoveRealBackpack()
    BackpackSystem:DisableRealBackpack()
    BackpackSystem.PlayerHasRealBackpack = false
    Storage.SaveBoolean(Player, "BackpackSystem.PlayerHasRealBackpack", BackpackSystem.PlayerHasRealBackpack)
end

---Set the target entity where stored items will be teleported.
---
---If called using `CallScriptFunction` then the entity that called it is set as the target.
---
---If called using `RunScriptCode` the targetname of the entity must be supplied in single quotes, e.g.
---SetVirtualBackpackTarget('@virtual_backpack_target')
---DO NOT USE DOUBLE QUOTES IN YOUR OUTPUT/OVERRIDE, THIS MAY CORRUPT YOUR VMAP
---@param target string|TypeIOInvoke
local function SetVirtualBackpackTarget(target)
    if type(target) == "table" and target.caller then
        BackpackSystem:SetVirtualBackpackTarget(target.caller:GetName())
    elseif type(target) == 'string' then
        BackpackSystem:SetVirtualBackpackTarget(target)
    else
        Warning("Tried to set virtual backpack target with invalid type! ("..type(target)..")")
    end
end

--#endregion

local function OnBackpackTriggerStartTouch(data)
    BackpackSystem:OnBackpackTriggerTouch(data)
end
local function OnBackpackTriggerEndTouch(data)
    BackpackSystem:OnBackpackTriggerEndTouch(data)
end

-- Add local functions to private script scope to avoid environment pollution.
local _a,_b=1,thisEntity:GetPrivateScriptScope()while true do local _c,_d=debug.getlocal(1,_a)if _c==nil then break end;if type(_d)=='function'then _b[_c]=_d end;_a=1+_a end


-- End of entity scope
else
-- Start of global scope

print('Backpack system is loading into global scope')
require "util.util"
require "util.stack"
require "util.queue"
require "util.storage"
require "util.player"

---@class BackpackSystem
BackpackSystem = {

    -- Storage properties in order of importance.

    ---Items can be put in backpack.
    StorageEnabled = true,
    ---Max items allowed in backpack.
    ---If you want a different max for each class you should control this in a separate script.
    MaxItems = -1,
    ---Maximum mass the object can be for storage. Use -1 to disable.
    LimitMass = -1,
    ---Maximum size/volume of an object (length x width x height). Use -1 to disable.
    LimitSize = -1,
    ---Entity classes that can be put in backpack.
    ---Use false or don't add to exclude a class.
    ---If table is empty then any class can be stored.
    StorableClasses =
    {
        -- ["prop_physics"] = 1,
        -- ["prop_physics_override"] = 1,
        -- ["func_physbox"] = 1,
    },
    ---Entity names that can be put in backpack.
    ---Use false or don't add to exclude a name.
    ---If table is empty then any name can be stored.
    StorableNames =
    {
    },
    ---Entity models that can be put in backpack.
    ---Use false or don't add to exclude a model.
    ---If table is empty then any model can be stored.
    StorableModels =
    {
    },

    -- Retrieval properties in order of importance.
    -- Retrieval tables are used to retrieve generic props instead of specifically designated props.

    ---Items can be taken from backpack.
    RetrievalEnabled = true,
    ---Player must have no weapon equipped to retrieve items.
    RequireNoWeapon = false,
    ---Player's weapon must have no ammo in backpack to retrieve items. Use in conjunction with `RequireNoWeapon`.
    RequireNoAmmo = false,
    ---If true then all items can be retrieved regardless of the retrieval properties set.
    OverrideAllowAllRetrieval = false,
    ---Classes that can be retrieved from the backpack in order of importance.
    RetrievalClassInventory = {},
    ---Names that can be retrieved from the backpack in order of importance.
    RetrievalNameInventory = {},
    ---Models that can be retrieved from the backpack in order of importance.
    RetrievalModelInventory = {},

    -- Other properties

    ---Seconds a prop can attempt to enter backpack after being dropped/thrown.
    DepositWaitTime = 1.0,
    ---Offset from the player head the trigger is attached.
    BackpackTriggerOffset = Vector(3, 0, 0),
    ---Strength of the vibration when a hand is interacting with the backpack.
    ---@type "0"|"1"|"2"
    HapticStrength = 2,
    ---Default sound that plays when storing an entity. Can be overridden by entities.
    SoundStore = "Inventory.Close",--"Inventory.DepositItem",
    ---Default sound that plays when retrieving an entity. Can be overridden by entities.
    SoundRetrieve = "Inventory.Open",--"Inventory.ClipGrab",
    --Seconds between each update function (0 is every frame).
    UpdateInterval = 0,
    ---Disables the real backpack if it exists when retrieving so player won't accidentally grab ammo.
    DisableRealBackpackWhenRetrieving = true,
    ---Player has real backpack equipped. Used for proper enabling/disabling during retrieval.
    PlayerHasRealBackpack = false,

    -- Following members should not be edited unless you know what you are doing!

    ---Items stored in backpack will be pulled out in the opposite order they were stored.
    StorageStack = Stack(),
    ---If the backpack is enabled and will accept prop input.
    Enabled = false,
    ---Trigger entity.
    ---@type CBaseTrigger
    _BackpackTrigger = nil,
    ---Target where stored entities are Teleported.
    ---@type EntityHandle
    _VirtualBackpackTarget = nil,
}
BackpackSystem.__index = BackpackSystem

---------------------------------------------------------------------
-- Entity functions to control what can[not] interact with backpack
---------------------------------------------------------------------
--#region

function BackpackSystem:SetClassStorage(class, enabled)
    self.StorableClasses[class] = enabled
    Storage.SaveTable(Player, "BackpackSystem.StorableClasses", self.StorableClasses)
end
function BackpackSystem:SetNameStorage(name, enabled)
    self.StorableNames[name] = enabled
    Storage.SaveTable(Player, "BackpackSystem.StorableNames", self.StorableNames)
end
function BackpackSystem:SetModelStorage(model, enabled)
    self.StorableModels[model] = enabled
    Storage.SaveTable(Player, "BackpackSystem.StorableModels", self.StorableModels)
end
function BackpackSystem:SetClassRetrieval(class, enabled)
    self.RetrievalClassInventory[class] = enabled
    -- print("FIRST THE ACTUAL TABLE:")
    -- util.PrintTable(self.RetrievalClassInventory)
    Storage.SaveTable(Player, "BackpackSystem.RetrievalClassInventory", self.RetrievalClassInventory)
    -- print("RETRIEVAL TABLE SAVED AS:")
    -- util.PrintTable(Storage.LoadTable(Player, "BackpackSystem.RetrievalClassInventory",{}))
    -- print("RETRIEVAL FOR", class, enabled)
end
function BackpackSystem:SetNameRetrieval(name, enabled)
    self.RetrievalNameInventory[name] = enabled
    Storage.SaveTable(Player, "BackpackSystem.RetrievalNameInventory", self.RetrievalNameInventory)
end
function BackpackSystem:SetModelRetrieval(model, enabled)
    self.RetrievalModelInventory[model] = enabled
    Storage.SaveTable(Player, "BackpackSystem.RetrievalModelInventory", self.RetrievalModelInventory)
end

-- Storage

---Add this entity's class to the list of storable classes.
---@param data TypeIOInvoke
function CEntityInstance:EnableClassStorage(data)
    -- if data.caller then
        BackpackSystem:SetClassStorage(self:GetClassname(), true)
        -- BackpackSystem.StorableClasses:Add(data.caller:GetClassname())
    -- end
end
---Remove this entity's class from the list of storable classes.
---@param data TypeIOInvoke
function CEntityInstance:DisableClassStorage(data)
    -- if data.caller then
        BackpackSystem:SetClassStorage(self:GetClassname(), nil)
        -- BackpackSystem.StorableClasses:Remove(data.caller:GetClassname())
    -- end
end

---Add this entity's name to the list of storable names.
---@param data TypeIOInvoke
function CEntityInstance:EnableNameStorage(data)
    -- if data.caller then
        BackpackSystem:SetNameStorage(self:GetName(), true)
        -- BackpackSystem.StorableNames:Add(data.caller:GetName())
    -- end
end
---Remove this entity's name from the list of storable names.
---@param data TypeIOInvoke
function CEntityInstance:DisableNameStorage(data)
    -- if data.caller then
        BackpackSystem:SetNameStorage(self:GetName(), nil)
        -- BackpackSystem.StorableNames:Remove(data.caller:GetName())
    -- end
end

---Add this entity's model to the list of storable models.
---@param data TypeIOInvoke
function CEntityInstance:EnableModelStorage(data)
    -- if data.caller then
        BackpackSystem:SetModelStorage(self:GetModelName(), true)
        -- BackpackSystem.StorableModels:Add(data.caller:GetModelName())
    -- end
end
---Remove this entity's model from the list of storable models.
---@param data TypeIOInvoke
function CEntityInstance:DisableModelStorage(data)
    -- if data.caller then
        BackpackSystem:SetModelStorage(self:GetModelName(), nil)
        -- BackpackSystem.StorableModels:Remove(data.caller:GetModelName())
    -- end
end

---Enable storage for this specific entity.
---@param data TypeIOInvoke
function CEntityInstance:EnableStorage(data)
    -- if data.caller then
        -- self:EnableClassStorage(data)
        -- self:EnableNameStorage(data)
        -- self:EnableModelStorage(data)
        print(self:GetName(), self:GetClassname(), self:GetModelName())
        if self:GetClassname() == "prop_ragdoll" then print("ENABLE STORAGE ON RAGDOLL") end
        self:SaveBoolean("BackpackItem.EnableStorage", true)
    -- end
end
CEntityInstance.EnableBackpackStorage = CEntityInstance.EnableStorage
---Remove this entity's properties from the storable tables as a catch-all.
---@param data TypeIOInvoke
function CEntityInstance:DisableStorage(data)
    -- if data.caller then
        -- self:DisableClassStorage(data)
        -- self:DisableNameStorage(data)
        -- self:DisableModelStorage(data)
        self:SaveBoolean("BackpackItem.DisableStorage", true)
    -- end
end
CEntityInstance.DisableBackpackStorage = CEntityInstance.DisableStorage

-- Retrieval

---Add this entity's class to the list of retrieval classes.
---@param data TypeIOInvoke
function CEntityInstance:EnableClassRetrieval(data)
    -- if data.caller then
        -- BackpackSystem.RetrievalClassInventory:Add(data.caller:GetClassname())
        -- if not BackpackSystem.RetrievalClassStack:PushToTop(data.caller:GetClassname()) then
        --     BackpackSystem.RetrievalClassStack:Push(data.caller:GetClassname())
        -- end
    -- end
    BackpackSystem:SetClassRetrieval(self:GetClassname(), true)
end
---Remove this entity's class from the list of retrieval classes.
---@param data TypeIOInvoke
function CEntityInstance:DisableClassRetrieval(data)
    -- if data.caller then
    --     BackpackSystem.RetrievalClassInventory:Remove(data.caller:GetClassname())
    -- end
    BackpackSystem:SetClassRetrieval(self:GetClassname(), nil)
end

---Add this entity's name to the list of retrieval names.
---@param data TypeIOInvoke
function CEntityInstance:EnableNameRetrieval(data)
    -- if data.caller then
        -- BackpackSystem.RetrievalNameInventory:Add(data.caller:GetName())
        -- if not BackpackSystem.RetrievalNameStack:PushToTop(data.caller:GetName()) then
        --     BackpackSystem.RetrievalNameStack:Push(data.caller:GetName())
        -- end
    -- end
    BackpackSystem:SetNameRetrieval(self:GetName(), true)
end
---Remove this entity's name from the list of retrieval names.
---@param data TypeIOInvoke
function CEntityInstance:DisableNameRetrieval(data)
    -- if data.caller then
    --     BackpackSystem.RetrievalClassInventory:Remove(data.caller:GetName())
    -- end
    BackpackSystem:SetNameRetrieval(self:GetName(), nil)
end

---Add this entity's model to the list of retrieval models.
---@param data TypeIOInvoke
function CEntityInstance:EnableModelRetrieval(data)
    -- if data.caller then
        -- BackpackSystem.RetrievalModelInventory:Add(data.caller:GetModelName())
        -- if not BackpackSystem.RetrievalModelStack:PushToTop(data.caller:GetModelName()) then
        --     BackpackSystem.RetrievalModelStack:Push(data.caller:GetModelName())
        -- end
    -- end
    BackpackSystem:SetModelRetrieval(self:GetModelName(), true)
end
---Remove this entity's model from the list of retrieval models.
---@param data TypeIOInvoke
function CEntityInstance:DisableModelRetrieval(data)
    -- if data.caller then
    --     BackpackSystem.RetrievalModelInventory:Remove(data.caller:GetModelName())
    -- end
    BackpackSystem:SetModelRetrieval(self:GetModelName(), nil)
end

---Enable retrieval for this entity and make it a priority.
---@param data TypeIOInvoke
function CEntityInstance:EnableRetrieval(data)
    -- if data.caller then
        -- self:EnableClassRetrieval(data)
        -- self:EnableNameRetrieval(data)
        -- self:EnableModelRetrieval(data)
    -- end
    self:SaveBoolean("BackpackItem.EnableRetrieval", true)
    -- Moving to the top means the most recently enabled will be pulled out first
    BackpackSystem:MovePropToTop(self)
end
CEntityInstance.EnableBackpackRetrieval = CEntityInstance.EnableRetrieval
---Remove this entity's properties from the retrieval tables as a catch-all.
---@param data TypeIOInvoke
function CEntityInstance:DisableRetrieval(data)
    -- if data.caller then
    --     self:DisableClassRetrieval(data)
    --     self:DisableNameRetrieval(data)
    --     self:DisableModelRetrieval(data)
    -- end
    self:SaveBoolean("BackpackItem.EnableRetrieval", false)
end
CEntityInstance.DisableBackpackRetrieval = CEntityInstance.DisableRetrieval


---Set the sound that plays when this entity is stored.
---
---To call from Hammer use RunScriptCode with the name of the sound in single quotes, e.g.
---```
---SetStoreSound('Inventory.DepositItem')
---```
---
---@param sound string
function CEntityInstance:SetStoreSound(sound)
    SetStoreSound(self, sound)
end

---Global function for CEntityInstance:SetStoreSound.
---Makes setting in Hammer easier.
---@param handle EntityHandle|string # If a sound event then the handle will be the entity that called this function.
---@param sound? string
function SetStoreSound(handle, sound)
    if type(handle) == "string" then
        local fenv = getfenv(2)
        if not fenv.thisEntity then
            return
        end
        sound = handle
        handle = fenv.thisEntity
    end
    if type(sound) == "string" then
        handle:SaveString("BackpackItem.StoreSound", sound)
    end
end

---Set the sound that plays when this entity is retrieved.
---@param sound string
function CEntityInstance:SetRetrieveSound(sound)
    SetRetrieveSound(self, sound)
end

---Global function for CEntityInstance:SetRetrieveSound.
---Makes setting in Hammer easier.
---@param handle EntityHandle|string # If a sound event then the handle will be the entity that called this function.
---@param sound? string
function SetRetrieveSound(handle, sound)
    if type(handle) == "string" then
        local fenv = getfenv(2)
        if not fenv.thisEntity then
            return
        end
        sound = handle
        handle = fenv.thisEntity
    end
    if type(sound) == 'string' then
        handle:SaveString("BackpackItem.RetrieveSound", sound)
    end
end



---Set the angle the prop will be rotated to relative to the hand retrieving it.
---Format: 'Pitch Yaw Roll' e.g. '90 180 0'
---@param angle QAngle|string
function CEntityInstance:SetGrabAngle(angle)
    if type(angle) == "string" then
        local t = util.SplitString(angle)
        angle = QAngle(tonumber(t[1]) or 0, tonumber(t[2]) or 0, tonumber(t[3]) or 0)
    end
    self:SaveQAngle("BackpackProp.GrabAngle", angle)
end

---Sets the offset the item will be positioned relative to the hand retrieving it.
---Format: 'x y z' e.g. '-1 3.5 0'
---@param offset Vector|string
function CEntityInstance:SetGrabOffset(offset)
    if type(offset) == "string" then
        local t = util.SplitString(offset)
        offset = Vector(tonumber(t[1]) or -3, tonumber(t[2]) or 3, tonumber(t[3]) or -2)
    end
    self:SaveVector("BackpackProp.GrabOffset", offset)
end


function CEntityInstance:GetGrabAngle()
    return self:LoadQAngle("BackpackProp.GrabAngle", QAngle())
end

function CEntityInstance:GetGrabOffset()
    return self:LoadVector("BackpackProp.GrabOffset", Vector())
end

---Put this entity into the backpack.
function CEntityInstance:PutInBackpack()
    BackpackSystem:PutPropInBackpack(self)
end

--#endregion

--------------------------------------------------
-- System functions
--------------------------------------------------
--#region System functions

--#region Local functions

---Entity classes that have 'Use' input.
CLASSES_THAT_CAN_USE =
{
    "prop_physics",
    "prop_physics_override",
    "prop_physics_interactive",
    "prop_animinteractable",
    "prop_dry_erase_marker",
    "item_healthvial",
    "item_hlvr_health_station_vial",
    "item_item_crate",
    "item_hlvr_prop_battery",
    "item_hlvr_crafting_currency_large",
    "item_hlvr_crafting_currency_small",
    "item_hlvr_clip_energygun",
    "item_hlvr_clip_energygun_multiple",
    "item_hlvr_clip_rapidfire",
    "item_hlvr_clip_shotgun_single",
    "item_hlvr_clip_shotgun_multiple",
    "item_hlvr_clip_generic_pistol",
    "item_hlvr_clip_generic_pistol_multiple",
    "prop_russell_headset",
    "func_physbox",
    "item_hlvr_weapon_energygun",
    "item_hlvr_weapon_shotgun",
    "item_hlvr_weapon_rapidfire",
    "item_hlvr_weapon_generic_pistol",
}

---Items that have been released and are trying to be stored in backpack.
local itemsLookingForBackpack = Queue()
---Empty hands waiting in the backpack trigger to grab an item.
---@type table<CPropVRHand,boolean>
local handsToListenForGrab = {}

---@type EntityHandle
local itemWaitingForRetrieval = nil

---Initiating values.
local function init(data)
    BackpackSystem:SearchForBackpack()
    -- Search for map trigger after a short amount of time if not immediately found
    if not BackpackSystem._BackpackTrigger then
        print("BackpackSytem:", "Backpack wasn't found, searching after delay...")
        Player:SetContextThink("SearchForBackpack", function()
            BackpackSystem:SearchForBackpack()
        end, 1)
    end

    BackpackSystem._VirtualBackpackTarget = Storage.LoadEntity(Player, "BackpackSystem._VirtualBackpackTarget",
        Entities:FindByName(nil, "@backpack_system_target"))
    if not IsValidEntity(BackpackSystem._VirtualBackpackTarget) then
        BackpackSystem._VirtualBackpackTarget = SpawnEntityFromTableSynchronous("info_target",{
            targetname = "@backpack_system_target_SPAWNED",
            origin = "16000 16000 16000",
        })
    end

    -- Saved variables should probably have unique setting functions to do the saving for users.

    BackpackSystem.MaxItems = Storage.LoadNumber(Player, "BackpackSystem.MaxItems", BackpackSystem.MaxItems)
    BackpackSystem.LimitMass = Storage.LoadNumber(Player, "BackpackSystem.LimitMass", BackpackSystem.LimitMass)
    BackpackSystem.LimitSize = Storage.LoadNumber(Player, "BackpackSystem.LimitSize", BackpackSystem.LimitSize)
    BackpackSystem.DepositWaitTime = Storage.LoadNumber(Player, "BackpackSystem.DepositWaitTime", BackpackSystem.DepositWaitTime)
    BackpackSystem.BackpackTriggerOffset = Storage.LoadVector(Player, "BackpackSystem.BackpackTriggerOffset", BackpackSystem.BackpackTriggerOffset)
    BackpackSystem.SoundStore = Storage.LoadString(Player, "BackpackSystem.SoundStore", BackpackSystem.SoundStore)
    BackpackSystem.SoundRetrieve = Storage.LoadString(Player, "BackpackSystem.SoundRetrieve", BackpackSystem.SoundRetrieve)
    BackpackSystem.DisableRealBackpackWhenRetrieving = Storage.LoadBoolean(Player, "BackpackSystem.DisableRealBackpackWhenRetrieving", BackpackSystem.DisableRealBackpackWhenRetrieving)
    BackpackSystem.PlayerHasRealBackpack = Storage.LoadBoolean(Player, "BackpackSystem.PlayerHasRealBackpack", BackpackSystem.PlayerHasRealBackpack)
    BackpackSystem.UpdateInterval = Storage.LoadNumber(Player, "BackpackSystem.UpdateInterval", BackpackSystem.UpdateInterval)
    BackpackSystem.HapticStrength = Storage.LoadNumber(Player, "BackpackSystem.HapticStrength", BackpackSystem.HapticStrength)
    BackpackSystem.RetrievalEnabled = Storage.LoadBoolean(Player, "BackpackSystem.RetrievalEnabled", BackpackSystem.RetrievalEnabled)
    BackpackSystem.RequireNoWeapon = Storage.LoadBoolean(Player, "BackpackSystem.RequireNoWeapon", BackpackSystem.RequireNoWeapon)
    BackpackSystem.RequireNoAmmo = Storage.LoadBoolean(Player, "BackpackSystem.RequireNoAmmo", BackpackSystem.RequireNoAmmo)

    BackpackSystem.StorableClasses = Storage.LoadTable(Player, "BackpackSystem.StorableClasses", BackpackSystem.StorableClasses)
    BackpackSystem.StorableNames = Storage.LoadTable(Player, "BackpackSystem.StorableNames", BackpackSystem.StorableNames)
    BackpackSystem.StorableModels = Storage.LoadTable(Player, "BackpackSystem.StorableModels", BackpackSystem.StorableModels)

    -- BackpackSystem.RetrievalClassInventory.items = Storage.LoadTable(Player, "BackpackSystem.RetrievalClassStack.items", BackpackSystem.RetrievalClassInventory.items)
    -- BackpackSystem.RetrievalNameInventory.items = Storage.LoadTable(Player, "BackpackSystem.RetrievalNameStack.items", BackpackSystem.RetrievalNameInventory.items)
    -- BackpackSystem.RetrievalModelInventory.items = Storage.LoadTable(Player, "BackpackSystem.RetrievalModelStack.items", BackpackSystem.RetrievalModelInventory.items)
    BackpackSystem.RetrievalClassInventory = Storage.LoadTable(Player, "BackpackSystem.RetrievalClassInventory", BackpackSystem.RetrievalClassInventory)
    BackpackSystem.RetrievalNameInventory = Storage.LoadTable(Player, "BackpackSystem.RetrievalClassInventory", BackpackSystem.RetrievalNameInventory)
    BackpackSystem.RetrievalModelInventory = Storage.LoadTable(Player, "BackpackSystem.RetrievalClassInventory", BackpackSystem.RetrievalModelInventory)

    BackpackSystem.StorageStack.items = Storage.LoadTable(Player, "BackpackSystem.StorageStack.items", BackpackSystem.StorageStack.items)
    BackpackSystem:PrintPropsInBackpack()
    for _, prop in ipairs(BackpackSystem.StorageStack.items) do
        BackpackSystem:MovePropToBackpack(prop)
    end
    -- BackpackSystem:PrintPropsNearBackpackTarget()
    -- ALL STORED PROPS NEED TO BE MOVED TO THE NEW BACKPACK LOCATION SO THEY WILL TRANSITION AGAIN
    BackpackSystem.Enabled = Storage.LoadBoolean(Player, "BackpackSystem.Enabled", BackpackSystem.Enabled)
    if BackpackSystem.Enabled then
        print("BackpackSystem:", "Backpack start enabled")
        BackpackSystem:Enable()
    end

    -- this is debug
    -- BackpackSystem:EnableRealBackpack()

    ---Used as a fix for props not transitioning outside PVS.
    ---This re-enables vis to avoid performance loss.
    if Player:LoadBoolean("EnableVisAfterTransition") then
        -- print("\nEnabling vis after transition\n")
        SendToConsole("vis_enable 1")
        Player:SaveBoolean("EnableVisAfterTransition", false)
    end
end
RegisterPlayerEventCallback("vr_player_ready", init)

---Update function positions backpack behind the player at head height.
---@return number
local function BackpackUpdate()
    -- Consider removing the the StartTouch EndTouch functions and
    -- do all the checking in here to avoid console message pollution.

    -- Early exit
    if not BackpackSystem.Enabled then
        return nil
    end

    -- Positioning the backpack trigger

    local head_forward = Player.HMDAvatar:GetForwardVector()
    local b_forward = Vector(head_forward.x, head_forward.y, 0)
    BackpackSystem._BackpackTrigger:SetForwardVector(b_forward)
    BackpackSystem._BackpackTrigger:SetOrigin(Player.HMDAvatar:GetOrigin() + BackpackSystem.BackpackTriggerOffset)

    -- Grab tracking for retrieval

    for hand, _ in pairs(handsToListenForGrab) do
        if Player:IsDigitalActionOnForHand(hand.Literal, 3) then
            print("BackpackSystem:", "Player gripped for retrieval")
            -- Move item to hand and send 'Use' input.
            -- if BackpackSystem:CanRetrieveProp()
            local retrieval_item = BackpackSystem:RemovePropFromBackpack()
            if retrieval_item then
                StartSoundEventFromPosition(
                    Storage.LoadString(retrieval_item, "BackpackItem.RetrieveSound", BackpackSystem.SoundRetrieve),
                    hand:GetOrigin()
                )
                -- retrieval_item:SetOrigin(hand:GetOrigin())
                -- this might put prop in floor or wall sometimes?
                -- retrieval_item:SetOrigin(BackpackSystem._BackpackTrigger:GetCenter())
                BackpackSystem:MovePropToHand(retrieval_item, hand)
                DoEntFireByInstanceHandle(retrieval_item, "Use", tostring(hand:GetHandID()), 0, Player, Player)
                handsToListenForGrab[hand] = nil
                BackpackSystem:TryEnableRealBackpack()
                -- Send outputs
                DoEntFireByInstanceHandle(retrieval_item, "FireUser2", "", 0, Player, Player)
                DoEntFireByInstanceHandle(BackpackSystem._BackpackTrigger, "FireUser2", "", 0, Player, Player)
            end
        end
    end

    return BackpackSystem.UpdateInterval
end

local function itemGrabbedFromBackpack(data)
    if itemWaitingForRetrieval == data.item then
        itemWaitingForRetrieval = nil
        -- Detach from hand
        data.item:SetParent(nil, "")

        StartSoundEventFromPosition(
            Storage.LoadString(data.item, "BackpackItem.RetrieveSound", BackpackSystem.SoundRetrieve),
            data.item:GetOrigin()
        )

        -- Send outputs
        DoEntFireByInstanceHandle(data.item, "FireUser2", "", 0, Player, Player)
        DoEntFire("@backpack_system", "FireUser2", "", 0, Player, Player)
    end
end
RegisterPlayerEventCallback("item_pickup", itemGrabbedFromBackpack)

local function itemReleasedForBackpack(data)
    -- print("RELEASED", data.item, data.item_class, BackpackSystem:CanStoreProp(data.item))
    -- if vlua.find(BackpackSystem.StorableClasses, data.item_class) then
    ---@type EntityHandle
    local prop = data.item
    -- THIS IS DEBUG STUFF
    -- print("itemreleased in backpack system")
    if type(data.item) == "string" then print('string was in itemReleasedForBackpack') end
    -- print(BackpackSystem:CanStoreProp(prop))
    if not BackpackSystem:CanStoreProp(prop) then BackpackSystem:PrintCanStoreProp(prop) end
    -- DELETE ABOVE DEBUG
    if BackpackSystem:CanStoreProp(prop) then
        print("BackpackSystem", "item released for backpack", prop:GetModelName())

        -- Put released prop immediately in backpack if touching.
        if BackpackSystem:IsPropTouchingBackpack(prop) then
            -- for some reason this needs to be delayed,
            -- possibly because prop hasn't fully detached from hand yet
            prop:SetContextThink(DoUniqueString(""), function()
                StartSoundEventFromPosition(
                    Storage.LoadString(prop, "BackpackItem.StoreSound", BackpackSystem.SoundStore),
                    prop:GetOrigin()
                )
                -- prop:Drop()
                BackpackSystem:PutPropInBackpack(prop)
                -- print("Immediately put in backpack because touching")
                -- Send outputs
                DoEntFireByInstanceHandle(prop, "FireUser1", "", 0, Player, Player)
                DoEntFireByInstanceHandle(BackpackSystem._BackpackTrigger, "FireUser1", "", 0, Player, Player)
            end, 0)
            return
        end

        -- Otherwise prop is being thrown into backpack...
        itemsLookingForBackpack:Enqueue(prop)
        Player:SetContextThink(DoUniqueString("remove_backpack_wait"),
            function()
                -- print("Removing from wait backpack", data.item_class)
                -- print(itemsLookingForBackpack:Length())
                itemsLookingForBackpack:Dequeue()
                -- print(itemsLookingForBackpack:Length())
                -- for key, value in pairs(itemsLookingForBackpack.items) do
                --     print(value, value:GetClassname(), value:GetModelName())
                -- end
            end
        ,BackpackSystem.DepositWaitTime)

    end
end
RegisterPlayerEventCallback("item_released", itemReleasedForBackpack)

---Used as a fix for props not transitioning outside of PVS.
local function onMapTransition()
    if not Player:LoadBoolean("EnableVisAfterTransition") then
        -- print("\n\nON MAP TRANSITION", IsClient())
        SendToConsole("vis_enable 0")
        Player:SaveBoolean("EnableVisAfterTransition", true)
        -- print("\n\n")
    end
end
ListenToGameEvent("change_level_activated", function() onMapTransition() end, nil)

-- local function listenForGrab()
--     for hand, _ in pairs(handsToListenForGrab) do
--         if Player:IsDigitalActionOnForHand(hand.Literal, 3) then
--             print("BackpackSystem:", "Player gripped for retrieval")
--             -- Move item to hand and send 'Use' input.
--             -- if BackpackSystem:CanRetrieveProp()
--             local retrieval_item = BackpackSystem:RemovePropFromBackpack()
--             StartSoundEventFromPosition(
--                 Storage.LoadString(retrieval_item, "BackpackItem.RetrieveSound", BackpackSystem.SoundRetrieve),
--                 hand:GetOrigin()
--             )
--             -- retrieval_item:SetOrigin(hand:GetOrigin())
--             retrieval_item:SetOrigin(BackpackSystem._BackpackTrigger:GetCenter())
--             DoEntFireByInstanceHandle(retrieval_item, "Use", tostring(hand:GetHandID()), 0, Player, Player)
--             handsToListenForGrab[hand] = nil
--             -- Send outputs
--             DoEntFireByInstanceHandle(retrieval_item, "FireUser2", "", 0, Player, Player)
--             DoEntFire("@backpack_system", "FireUser2", "", 0, Player, Player)
--         end
--     end
--     if util.TableSize(handsToListenForGrab) == 0 then
--         return nil
--     end
--     return 0
-- end

--#endregion Local functions

--#region BackpackSystem class functions

---Enable backpack storage of items. Items that aren't set as allowed will still stay disallowed.
function BackpackSystem:EnableAllStorage()
    self.StorageEnabled = true
    Storage:SaveBoolean('BackpackSystem.StorageEnabled', true)
end

---Disable backpack storage of all items, globally.
function BackpackSystem:DisableAllStorage()
    self.StorageEnabled = false
    Storage:SaveBoolean('BackpackSystem.StorageEnabled', false)
end

---Enable retrieval of items. Specific items disabled will stay disabled.
function BackpackSystem:EnableAllRetrieval()
    self.RetrievalEnabled = true
    Storage:SaveBoolean('BackpackSystem.RetrievalEnabled', true)
end

---Disable retrieval of any item, globally.
function BackpackSystem:DisableAllRetrieval()
    self.RetrievalEnabled = false
    Storage:SaveBoolean('BackpackSystem.RetrievalEnabled', false)
end

---Set the target entity where stored items will be teleported.
---@param targetname string
function BackpackSystem:SetVirtualBackpackTarget(targetname)
    local target = Entities:FindByName(nil, targetname)
    if not target then
        Warning("Could not set backpack virtual target: No entity with name '"..targetname.."' found!")
        return
    end
    self._VirtualBackpackTarget = target
    Storage.SaveEntity(Player, "BackpackSystem._VirtualBackpackTarget", self._VirtualBackpackTarget)
end

---Get a list of estimated props near the backpack target regardless of their status in the backpack.
---@return EntityHandle[]
function BackpackSystem:GetPropsNearBackpackTarget()
    local props = {}
    for _, prop in ipairs(Entities:FindAllInSphere(self._VirtualBackpackTarget:GetOrigin(), 150)) do
        -- if self:CanStoreProp(prop) then
            props[#props+1] = prop
        -- end
    end
    return props
end

function BackpackSystem:PrintPropsNearBackpackTarget()
    print("Props near backpack:")
    for k, prop in ipairs(self:GetPropsNearBackpackTarget()) do
        print(k, prop, prop:GetClassname(), prop:GetModelName())
    end
end

---Attempt to find an existing backpack trigger in the map.
---Otherwise a new one is created.
function BackpackSystem:SearchForBackpack()
    print("BackpackSystem:", "Backpack triggers found", #Entities:FindAllByName("@backpack_system_trigger"))
    local backpack = Storage.LoadEntity(Player, "BackpackSystem._BackpackTrigger",
        Entities:FindByName(nil, "@backpack_system_trigger"))
    -- Assign newly found backpack if one was found
    if backpack then
        BackpackSystem._BackpackTrigger = backpack
        print("BackpackSystem:", "Found backpack trigger is", BackpackSystem._BackpackTrigger)
        return
    end
    print("BackpackSystem:", "No backpack trigger was found in map...")
    -- if not IsValidEntity(BackpackSystem._BackpackTrigger) then
    --     print("BackpackSystem:", "Creating backpack trigger as last resort, please place trigger in map...")
    --     -- BackpackSystem._BackpackTrigger = CreateTrigger(Vector(), Vector(-21, -14, -16), Vector(21, 14, 16))
    --     -- print(BackpackSystem._BackpackTrigger:GetModelName())
    --     local t = SpawnEntityFromTableSynchronous("trigger_multiple",{
    --         targetname="@backpack_system_trigger",
    --         model="models/items/backpack/backpack_inventory.vmdl",
    --         spawnflags="4105",
    --         vscripts = "backpack_system/backpack_system_core",
    --     })
    --     print(t:GetBoundingMaxs())
    --     DoEntFireByInstanceHandle(t, "AddOutput", "OnStartTouch>!self>CallPrivateScriptFunction>OnBackpackTriggerStartTouch>0>-1", 0, Player, Player)
    --     DoEntFireByInstanceHandle(t, "AddOutput", "OnEndTouch>!self>CallPrivateScriptFunction>OnBackpackTriggerEndTouch>0>-1", 0, Player, Player)
    --     BackpackSystem._BackpackTrigger = t
    -- end
    -- -- print(BackpackSystem._BackpackTrigger:GetMoveParent())
    -- if not IsValidEntity(BackpackSystem._BackpackTrigger:GetMoveParent()) then
    --     -- Player:SetContextThink("sdf", function()
    --         print("BackpackSystem:", "Backpack has no parent, parenting...")
    --         -- BackpackSystem._BackpackTrigger:SetParent(BackpackSystem:GetRealBackpack(), "")
    --         BackpackSystem._BackpackTrigger:SetParent(Player.HMDAvatar, "")
    --         BackpackSystem._BackpackTrigger:SetLocalOrigin(BackpackSystem.BackpackTriggerOffset)
    --         BackpackSystem._BackpackTrigger:SetLocalAngles(0,0,0)
    --         print(BackpackSystem._BackpackTrigger:GetMoveParent())
    --     -- end, 1)
    -- end
end

---Set the default store sound for the backpack.
---@param sound string # Sound event name.
function BackpackSystem:SetStoreSound(sound)
    BackpackSystem.SoundStore = sound
    Storage.SaveString(Player, "BackpackSystem.SoundStore", BackpackSystem.SoundStore)
end

---Set the default retrieve sound for the backpack.
---@param sound string # Sound event name.
function BackpackSystem:SetRetrieveSound(sound)
    BackpackSystem.SoundRetrieve = sound
    Storage.SaveString(Player, "BackpackSystem.SoundRetrieve", BackpackSystem.SoundRetrieve)
end

---Get the real backpack if it exists.
---@return EntityHandle
function BackpackSystem:GetRealBackpack()
    return Entities:FindByClassname(nil, "player_backpack")
end

---Enable base Alyx backpack.
function BackpackSystem:EnableRealBackpack()
    local b = self:GetRealBackpack()
    if b and self.PlayerHasRealBackpack then
        -- print("ENABLING REAL BACKPACK")
        -- b:SetAbsScale(1)
        local e = SpawnEntityFromTableSynchronous("info_hlvr_equip_player",{
            equip_on_mapstart = "0",
            itemholder = Player:HasItemHolder(),
            inventory_enabled = "0",
            backpack_enabled = "1",
        })
        DoEntFireByInstanceHandle(e, "EquipNow", "", 0, Player, Player)
    end
end
---Disable base Alyx backpack.
function BackpackSystem:DisableRealBackpack()
    local b = self:GetRealBackpack()
    if b and self.PlayerHasRealBackpack then
        -- print("DISABLING REAL BACKPACK")
        -- b:SetAbsScale(0.01)
        local e = SpawnEntityFromTableSynchronous("info_hlvr_equip_player",{
            equip_on_mapstart = "0",
            itemholder = Player:HasItemHolder(),
            inventory_enabled = "0",
            backpack_enabled = "0",
        })
        DoEntFireByInstanceHandle(e, "EquipNow", "", 0, Player, Player)
    end
end

---Enable the base Alyx backpack if no hands are touching or no props waiting for retrieval.
function BackpackSystem:TryEnableRealBackpack()
    -- print("TRYING TO ENABLE REAL BACKPACK")
    local touching = 0
    for id = 1, 2 do
        if self:IsPropTouchingBackpack(Player.Hand[id]) then
            touching = touching + 1
        end
    end
    if touching == 0 or not self:GetTopProp() then
        self:EnableRealBackpack()
    end
end

---Enable the backpack to accept prop input and positioning.
function BackpackSystem:Enable()
    Player:SetThink(BackpackUpdate, "BackpackUpdate", 0)
    BackpackSystem.Enabled = true
    Storage.SaveBoolean(Player, "BackpackSystem.Enabled", BackpackSystem.Enabled)
end

---Disable the backpack to stop prop input and positioning.
function BackpackSystem:Disable()
    Player:StopThink("BackpackUpdate")
    BackpackSystem.Enabled = false
    Storage.SaveBoolean(Player, "BackpackSystem.Enabled", BackpackSystem.Enabled)
end

---Print all props in backpack.
function BackpackSystem:PrintPropsInBackpack()
    print("In Backpack:")
    print("{")
    for key, value in pairs(self.StorageStack.items) do
        print("", key, value, value:GetName(), value:GetClassname(), value:GetModelName())
    end
    print("}")
end

---Get a list of supported prop classes.
---@return string[]
function BackpackSystem:GetSupportedProps()
    return vlua.clone(CLASSES_THAT_CAN_USE)
end

function BackpackSystem:PrintCanStoreProp(prop)
    local size = prop:GetBoundingMaxs() - prop:GetBoundingMins()
    -- print("Checking can store for:", prop:GetName(), prop:GetClassname(), prop:GetModelName())
    -- print("self.StorageEnabled", self.StorageEnabled)
    -- print("self.StorageStack:Length() < self.MaxItems or self.MaxItems < 0", self.StorageStack:Length() < self.MaxItems or self.MaxItems < 0)
    -- print('prop:LoadBoolean("BackpackItem.EnableStorage")', prop:LoadBoolean("BackpackItem.EnableStorage"))
    -- print('self.StorableClasses[prop:GetClassname()]', self.StorableClasses[prop:GetClassname()])
    -- print('self.StorableNames[prop:GetName()]', self.StorableNames[prop:GetName()])
    -- print('self.StorableModels[prop:GetModelName()]', self.StorableModels[prop:GetModelName()])
    -- print('self.LimitMass < 0 or prop:GetMass() <= self.LimitMass', self.LimitMass < 0 or prop:GetMass() <= self.LimitMass)
    -- print('self.LimitSize < 0 or (size.x*size.y*size.z) <= self.LimitSize', self.LimitSize < 0 or (size.x*size.y*size.z) <= self.LimitSize)

    local reason = "Unknown reason"
    if not self.StorageEnabled then reason = "Storage disabled"
    elseif self.MaxItems >= 0 and self.StorageStack:Length() >= self.MaxItems then reason = "Backpack full"
    elseif not prop:LoadBoolean("BackpackItem.EnableStorage")
            and not self.StorableClasses[prop:GetClassname()]
            and not self.StorableNames[prop:GetName()]
            and not self.StorableModels[prop:GetModelName()] then reason = "Prop not enabled for storage"
    elseif self.LimitMass >= 0 and prop:GetMass() > self.LimitMass then reason = "Prop is too heavy"
    elseif self.LimitSize >= 0 and (size.x*size.y*size.z) > self.LimitSize then reason = "Prop is too big"
    end
    print("("..prop:GetClassname()..","..prop:GetName()..","..prop:GetModelName()..") can't be stored in backpack because: "..reason)
end

---Get the size of a prop.
---@param prop EntityHandle
---@return number
function BackpackSystem:GetPropSize(prop)
    local size = prop:GetBoundingMaxs() - prop:GetBoundingMins()
    return size.x * size.y * size.z
end

---Check if a prop is able to be stored at this time.
---@param prop EntityHandle
---@return boolean
function BackpackSystem:CanStoreProp(prop)
    if type(prop) == "string" then print(type(prop), prop) end
    if IsValidEntity(prop) then
        -- print(tostring(self.StorageEnabled), tostring((self.StorageStack:Length() < self.MaxItems or self.MaxItems < 0)), tostring(vlua.find(self.StorableClasses, prop:GetClassname())))
        if self.StorageEnabled
        and (self.StorageStack:Length() < self.MaxItems or self.MaxItems < 0)
        and (prop:LoadBoolean("BackpackItem.EnableStorage")
            or self.StorableClasses[prop:GetClassname()]
            or self.StorableNames[prop:GetName()]
            or self.StorableModels[prop:GetModelName()])
        and (self.LimitMass < 0 or prop:GetMass() <= self.LimitMass)
        and (self.LimitSize < 0 or self:GetPropSize(prop) <= self.LimitSize)
        -- and (util.TableSize(self.StorableClasses) == 0 or self.StorableClasses[prop:GetClassname()])
        -- and (util.TableSize(self.StorableNames) == 0 or self.StorableNames[prop:GetName()])
        -- and (util.TableSize(self.StorableModels) == 0 or self.StorableModels[prop:GetModelName()])
        then
            return true
        end
    else
        print("For some reason CanStoreProp got invalid entity", prop)
    end
    return false
end

---Check if a prop is able to be retrieved at this time.
---@param prop EntityHandle
---@return boolean
function BackpackSystem:CanRetrieveProp(prop)
    if self.RetrievalEnabled
    -- and not self.StorageStack:IsEmpty()
    and (not Player:HasWeaponEquipped() or not self.RequireNoWeapon)
    and (Player:GetCurrentWeaponReserves() == 0 or not self.RequireNoAmmo)
    and self.StorageStack:Contains(prop)
    and (self.OverrideAllowAllRetrieval
        or (prop:LoadBoolean("BackpackItem.EnableRetrieval")
            or self.RetrievalClassInventory[prop:GetClassname()]
            or self.RetrievalNameInventory[prop:GetName()]
            or self.RetrievalModelInventory[prop:GetModelName()]))
            -- or self.RetrievalClassInventory:Contains(prop:GetClassname())
            -- or self.RetrievalNameInventory:Contains(prop:GetName())
            -- or self.RetrievalModelInventory:Contains(prop:GetModelName())))
    then
        return true
    end
    return false
end

---Move a prop to the top of the storage stack if it exists in backpack.
---@param prop EntityHandle
function BackpackSystem:MovePropToTop(prop)
    self.StorageStack:MoveToTop(prop)
end

---Fired by hammer on trigger touch.
---@param data TypeIOInvoke
function BackpackSystem:OnBackpackTriggerTouch(data)
    local activator = data.activator
    local class = activator:GetClassname()

    -- Hand touching backpack.
    if class == "hl_prop_vr_hand" then
        -- print("BackpackSystem:", "hand touched backpack")
        local hand = activator
        if hand:IsHoldingItem() then
            print("BackpackSystem:", "hand is holding")
            -- If item held on backpack is storable then prompt player with vibrate.
            if type(hand.ItemHeld) == "string" then print('string was in OnBackpackTriggerTouch') end
            if self:CanStoreProp(hand.ItemHeld) then
                print("BackpackSystem:", "hand touched backpack while holding")
                hand:FireHapticPulse(self.HapticStrength)
            end
        else
            -- -- If allowed to retrieve and backpack has at least 1 prop...
            -- if self.RetrievalEnabled and not self.StorageStack:IsEmpty()
            -- and (not Player:HasWeaponEquipped() or not self.RequireNoWeapon)
            -- and (Player:GetCurrentWeaponReserves() == 0 or not self.RequireNoAmmo)
            -- then
                -- Make sure at least 1 prop is allowed to be retrieved...
                local retrieval_item = self:GetTopProp()
                if retrieval_item then
                    print("BackpackSystem:", "hand touched backpack while empty")
                    hand:FireHapticPulse(self.HapticStrength)
                    if self.DisableRealBackpackWhenRetrieving then
                        self:DisableRealBackpack()
                    end
                    if vlua.find(CLASSES_THAT_CAN_USE, retrieval_item:GetClassname()) then
                        -- print("found retrieval item and listening for grab", retrieval_item:GetModelName())
                        handsToListenForGrab[hand] = true
                        --listen code is moved to BackpackUpdate
                        -- Player:SetThink(listenForGrab, "listenForGrab", 0)
                    else
                        -- Item can't 'use' so must be parented to hand for grab
                        -- print("found retrieval item and parenting to hand")
                        self:MovePropToHand(retrieval_item, hand, true)
                        itemWaitingForRetrieval = retrieval_item
                    end
                end
            -- end
        end
        return
    end

    -- If item is waiting to go into backpack, put it in.
    -- local i = vlua.find(itemsLookingForBackpack, activator)
    -- util.PrintTable(itemsLookingForBackpack)
    -- print("activator i", i)
    -- print("Looking backpack size", itemsLookingForBackpack:Length())
    -- print("Looking backpack contains", itemsLookingForBackpack:Contains(activator))
    if itemsLookingForBackpack:Contains(activator) then
        -- print("BackpackSystem:", class.." touched backpack")
        StartSoundEventFromPosition(
            Storage.LoadString(activator, "BackpackItem.StoreSound", self.SoundStore),
            activator:GetOrigin()
        )
        self:PutPropInBackpack(activator)
        -- Send outputs
        DoEntFireByInstanceHandle(activator, "FireUser1", "", 0, Player, Player)
        DoEntFireByInstanceHandle(self._BackpackTrigger, "FireUser1", "", 0, Player, Player)
        -- should remove think from activator or let it expire?
        return
    end
end

---Fired by hammer on trigger end touch.
---@param data TypeIOInvoke
function BackpackSystem:OnBackpackTriggerEndTouch(data)
    -- print("BackpackSystem:OnBackpackTriggerEndTouch")
    local activator = data.activator
    local class = activator:GetClassname()

    if class == "hl_prop_vr_hand" then
        local hand = activator
        handsToListenForGrab[hand] = nil
        if IsValidEntity(itemWaitingForRetrieval) then
            self:PutPropInBackpack(itemWaitingForRetrieval)
            itemWaitingForRetrieval = nil
        end
        BackpackSystem:TryEnableRealBackpack()
    end
end

---Get the top item waiting to be retrieved.
---Takes into account valid classes and orders and any retrieval properties set.
---Will remove any encountered invalid props.
---
---Can be used instead of CanRetrieveProp for greater safety.
---@return EntityHandle
function BackpackSystem:GetTopProp()
    -- First find a valid prop, some might be deleted
    -- local prop = self.StorageStack:Peek()
    -- while not IsValidEntity(prop) and self.StorageStack:Length() > 0 do
    --     self.StorageStack:Pop()
    --     prop = self.StorageStack:Peek()
    -- end
    -- local topprop = nil
    local best_prop,best_score = nil,0
    local markedForDeletion = {}
    -- Now take into account allowed retrieval properties
    ----@type EntityHandle
    -- for _, prop in ipairs(self.StorageStack.items) do
    -- Loop backwards so top items (last in, first out) get priority
    -- for i = #self.StorageStack.items, 1, -1 do
    for i = 1, #self.StorageStack.items do
        local prop = self.StorageStack.items[i]
        --  Invalid props need to be removed after finding the best one
        if not IsValidEntity(prop) then
            markedForDeletion[#markedForDeletion+1] = prop
        else
            if self:CanRetrieveProp(prop) then
                best_prop = prop
                break
            end
            -- Weight the props based on priority
            -- local score = 0
            -- score = score + self.RetrievalClassInventory:Get(prop:GetClassname())
            -- score = score + self.RetrievalNameInventory:Get(prop:GetName())
            -- score = score + self.RetrievalModelInventory:Get(prop:GetModelName())
            -- If at least one property is marked for retrieval
            -- if score > 0 and score >= best_score and self:CanRetrieveProp(prop) then
            --     best_score = score
            --     best_prop = prop
            -- end
            -- if (self.RetrievalClassStack:IsEmpty() or self.RetrievalClassStack:Contains(prop))
            -- and (self.RetrievalNameStack:IsEmpty() or self.RetrievalNameStack:Contains(prop))
            -- and (self.RetrievalModelStack:IsEmpty() or self.RetrievalModelStack:Contains(prop))
            -- then
            --     topprop = prop
            --     break
            -- end
        end
    end

    -- Delete any encountered invalid props.
    for _, prop in ipairs(markedForDeletion) do
        self.StorageStack:Remove(prop)
    end

    return best_prop
end

function BackpackSystem:MovePropToBackpack(prop)
    prop:SetOrigin(self._VirtualBackpackTarget:GetOrigin())
    -- print("Moved", prop:GetModelName(), prop:GetOrigin())
    prop:SetParent(nil, "")
end

---Put a prop in the backpack.
---If it already exists in the backpack then it is just warped back to the virtual target.
---@param prop EntityHandle
function BackpackSystem:PutPropInBackpack(prop)
    -- prop:SetParent(self._VirtualBackpackTarget, "")
    -- prop:SetLocalOrigin(Vector())
    -- prop:SetParent(Player, "")
    -- prop:SetLocalOrigin(Vector(128,0,64))
    -- prop:SetAbsScale(0)
    if not self.StorageStack:Contains(prop) then
        -- THIS IS DEBUG REMOVE!!
        if prop:GetName() == "" then
            prop:SetEntityName("prop_stored_in_backpack")
        end
        self:MovePropToBackpack(prop)
        self:SetPropProperties(prop, true)
        for _, child in ipairs(prop:GetChildren()) do
            self:SetPropProperties(child, true)
        end
        self.StorageStack:Push(prop)
        Storage.SaveTable(Player, "BackpackSystem.StorageStack.items", self.StorageStack.items)
        self:PrintPropsInBackpack()
    end
end

---Remove a prop from the backpack, or the top prop.
---@param prop? EntityHandle
---@return EntityHandle
function BackpackSystem:RemovePropFromBackpack(prop)
    -- print("Removing prop from backpack")
    if prop then
        local i = vlua.find(self.StorageStack.items, prop)
        if i then
            table.remove(self.StorageStack.items, i)
        end
    else
        prop = self:GetTopProp()
        self.StorageStack:Pop()
    end
    if prop then
        -- print("Prop that is being removed is", prop, prop:GetModelName())
        prop:SetParent(nil, "")
        self:SetPropProperties(prop, false)
        for _, child in ipairs(prop:GetChildren()) do
            self:SetPropProperties(child, false)
        end
        Storage.SaveTable(Player, "BackpackSystem.StorageStack.items", self.StorageStack.items)
        return prop
    end
    return nil
end

---Set the properties of a prop for in or out of backpack.
---@param prop EntityHandle
---@param inBackpack boolean
function BackpackSystem:SetPropProperties(prop, inBackpack)
    if inBackpack then
        -- print('set inside', prop:GetModelName())
        -- if prop.SetRenderAlpha then prop:SaveNumber("BackpackItem.SavedAlpha", prop:GetRenderAlpha()) prop:SetRenderAlpha(0) end
        if prop.SetHealth then prop:SaveNumber("BackpackItem.SavedHealth", prop:GetHealth()) prop:SetHealth(99999) end
        -- if prop.DisableMotion then prop:DisableMotion() end
    else
        -- print('set outside', prop:GetModelName())
        -- if prop.SetRenderAlpha then prop:SetRenderAlpha(prop:LoadNumber("BackpackItem.SavedAlpha", 255)) end
        if prop.SetHealth then prop:SetHealth(prop:LoadNumber("BackpackItem.SavedHealth", prop:GetMaxHealth())) end
        -- if prop.EnableMotion then prop:EnableMotion() end
    end
end

-- Returns if the given entity is touching the backpack.
---@param prop EntityHandle
function BackpackSystem:IsPropTouchingBackpack(prop)
    return self._BackpackTrigger:IsTouching(prop)
end

-- Attach a given entity to a given hand with a predefined offset.
---@param prop EntityHandle # The prop to move.
---@param hand CPropVRHand # The hand to move to.
---@param attach? boolean # If the prop should also be parented.
function BackpackSystem:MovePropToHand(prop, hand, attach)
    local side = hand:GetHandID()
    local offset = prop:LoadVector("BackpackItem.GrabOffset", Vector())
    -- Mirror offset if it's left hand
    if side == 0 then
        local axis = Vector(0, 1, 0)
        offset = offset - 2 * offset:Dot(axis) * axis
    end
    prop:SetOrigin(hand:TransformPointEntityToWorld(offset))
    -- Rotate hand angle by grab angle to keep angle consistent every time
    -- Angle is not mirrored to the left hand like offset above, how can this be done?
    local angle = RotateOrientation(hand:GetAngles(), prop:LoadQAngle("BackpackItem.GrabAngle", QAngle()))
    prop:SetAngles(angle.x,angle.y,angle.z)
    if attach then
        prop:SetParent(hand, "")
    end
end

---Destroys all props in backpack.
function BackpackSystem:ClearBackpack()
    for _, prop in ipairs(self.StorageStack.items) do
        prop:Kill()
    end
    self.StorageStack.items = {}
end

--#endregion BackpackSystem class functions

--#endregion System functions

-- End of global scope
end