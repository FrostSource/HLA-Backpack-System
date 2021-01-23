
--================--
-- User variables --
--================--

-- Time in seconds between each retrieval attempt.
-- Less is more accuracy but may bring performance impact.
-- Set to 0 for real time checking.
local RetrievalThinkTime = 0.1

-- Default name of the virtual backpack info_target.
local VirtualBackpackTarget = '@virtual_backpack_target'

-- Dimensions of the backpack attached to the player
local BackpackWidth = 40
local BackpackLength = 32
local BackpackHeight = 40

-- Local offset of attachment to player
local BackpackOffset = Vector(-20, 0, -12)


--==================--
-- System variables --
--==================--

RetrievalStack = {}
HapticReady = true
ItemUpForRetrieval = nil


--================--
-- User functions --
--================--

-- Disabled backpack storage of any item.
function DisableAllBackpackStorage()
    thisEntity:Attribute_SetIntValue('AllBackpackStorageEnabled', 0)
end

-- Enables backpack storage of items. Specific items disabled will stay disabled.
function EnableAllBackpackStorage()
    thisEntity:Attribute_SetIntValue('AllBackpackStorageEnabled', 1)
end

-- Disables retrieval of any item.
function DisableAllBackpackRetrieval()
    thisEntity:Attribute_SetIntValue('AllBackpackRetrievalEnabled', 0)
end

-- Enables retrieval of items. Specific items disabled will stay disabled.
function EnableAllBackpackRetrieval()
    thisEntity:Attribute_SetIntValue('AllBackpackRetrievalEnabled', 1)
end

-- Must be called using RunScriptCode with the targetname of the info_target in single quotes, e.g.
-- SetVirtualBackpackTarget('@virtual_backpack_target')
-- DO NOT USE DOUBLE QUOTES IN YOUR OUTPUT/OVERRIDE, THIS MAY CORRUPT YOUR FILE
---@param target string
function SetVirtualBackpackTarget(target)
    if type(target) == 'string' then
        VirtualBackpackTarget = target
    end
end


--==================--
-- System functions --
--==================--

-- Called externally by game.
function Activate(activateType)

    if activateType == 2 then
        if thisEntity:Attribute_GetIntValue('DoingRetrievalThink', 0) == 1 then
            thisEntity:SetThink(RetrievalThink, 'RetrievalThink', RetrievalThinkTime)
        end
    end

    -- Parent backpack trigger to player and set offset
    thisEntity:SetThink(function()
        local player = Entities:GetLocalPlayer():GetHMDAvatar()
        local backpack = GetBackpackTrigger()
        backpack:SetParent(player, '')
        backpack:SetLocalOrigin(BackpackOffset)
        backpack:SetLocalAngles(0,0,0)
        end,
        '',0.1)

    -- Game events
    ListenToGameEvent('item_pickup', OnGlobalPickup, thisEntity)
    ListenToGameEvent('item_released', OnGlobalRelease, thisEntity)
end

-- Returns if the given entity is touching the backpack.
---@param _ nil
---@param ent userdata
function IsTouchingBackpack(ent)
    return GetBackpackTrigger():IsTouching(ent)
end

-- Go-between function from backpack_item to backpack_system to allow attribute check.
---@param _ nil
---@param ent userdata
function StorageCheck(_, ent)
    if thisEntity:Attribute_GetIntValue('AllBackpackStorageEnabled', 1) then
        return IsTouchingBackpack(ent)
    end
    return false
end

-- Disables the player backpack, no longer allowing ammo retrieval.
function DisableRealBackpack()
    DoEntFire('@backpack_system_disable_real_backpack', 'EquipNow', '', 0, nil, nil)
end
function EnableRealBackpack()
    DoEntFire('@backpack_system_enable_real_backpack', 'EquipNow', '', 0, nil, nil)
end

-- Converts vr_tip_attachment (which gives primary/secondary) to proper hand id.
---@param _type integer | '1' | '2'
function GetHandIdFromType(_type)
    -- 1 = Primary hand
    -- 2 = Off hand
    _type = _type - 1
    -- Swap the hands if left is not primary (if right handed)
    if not Convars:GetBool('hlvr_left_hand_primary') then
        _type = 1 - _type
    end
    return _type
end

--- Fires a haptic pulse on a given hand for one frame. Pass nil as hand to reset.
---@param hand userdata
---@param strength integer | '0' | '1' | '2'
function FireShortHaptic(hand, strength)
    -- strength of 0 seems to do nothing, too low for one frame?
    if hand == nil then
        HapticReady = true
    elseif HapticReady then
        hand:FireHapticPulse(strength)
        HapticReady = false
    end
end

-- Returns the backpack trigger handle
function GetBackpackTrigger()
    return Entities:FindByName(nil, '@backpack_system_trigger')
end

-- Called externally by game event "item_pickup".
---@param _ nil
---@param event table
function OnGlobalPickup(_,event)
    -- Sometimes this event is called without attachment
    if event.vr_tip_attachment == nil then return nil end

    -- Keep track of which hand is holding something
    local handId = GetHandIdFromType(event.vr_tip_attachment)
    SetHandHolding(handId, true)
end

-- Called externally by game event "item_released".
---@param _ nil
---@param event table
function OnGlobalRelease(_,event)
    -- Sometimes this event is called without attachment
    if event.vr_tip_attachment == nil then return nil end

    -- Keep track of which hand isn't holding something
    local handId = GetHandIdFromType(event.vr_tip_attachment)
    SetHandHolding(handId, false)
end

-- Gives retrieval precedence to the given entity, ready to be retrieved.
---@param _ nil
---@param ent userdata
function MoveToTopOfRetrievalStack(_, ent)
    -- Remove the ent if it's in the stack first
    RemoveFromRetrievalStack(nil, ent)
    -- Then add it back in at the top
    RetrievalStack[#RetrievalStack+1] = ent
end

-- Removes the given entity from the stack, no longer allowed to be retrieved.
---@param _ nil
---@param ent userdata
function RemoveFromRetrievalStack(_, ent)
    for i,e in ipairs(RetrievalStack) do
        if e == ent then
            table.remove(RetrievalStack, i)
            break
        end
    end
end

-- Starts the retrieval process by attaching the top most item to the hand reaching for it.
-- Called externally in game by the backpack trigger.
---@param data table
function DoBackpackRetrieval(data)
    if thisEntity:Attribute_GetIntValue('AllBackpackRetrievalEnabled', 1) then
        local hand = data.activator
        if hand:GetClassname() == 'hl_prop_vr_hand' then
            for i = #RetrievalStack, 1, -1 do
                if RetrievalStack[i]:GetPrivateScriptScope():GetInBackpack() then
                    MoveItemToRetrievalHand(RetrievalStack[i], hand)
                    DisableRealBackpack()
                    FireShortHaptic(hand, 1)
                    ItemUpForRetrieval = RetrievalStack[i]
                    break
                end
            end
        end
    end
end

-- Stops the retrieval process and places the item that was being reached for back in the virtual backpack.
-- Called externally in game by the backpack trigger.
---@param data table
function EndBackpackRetrieval(data)
    local hand = data.activator
    if hand:GetClassname() == 'hl_prop_vr_hand' and ItemUpForRetrieval ~= nil then
        if ItemUpForRetrieval:GetPrivateScriptScope():GetInBackpack() then
            MoveItemToVirtualBackpack(nil, ItemUpForRetrieval)
            EnableRealBackpack()
            FireShortHaptic(nil)
            ItemUpForRetrieval = nil
        end
    end
end

-- Attach a given entity to a given hand with a predefined offset.
---@param ent userdata
---@param hand userdata
function MoveItemToRetrievalHand(ent, hand)
    local pos = hand:TransformPointEntityToWorld(Vector(-3, 3, -2))
    ent:SetOrigin(pos)
    ent:SetParent(hand, '')
end

-- Moves a given entity to the virtual backpack location in the world.
---@param _ nil
---@param ent userdata
function MoveItemToVirtualBackpack(_, ent)
    ent:SetParent(nil, '')
    local virtual = Entities:FindByName(nil, VirtualBackpackTarget)
    if virtual ~= nil then
        ent:SetOrigin(virtual:GetOrigin())
    else
        ent:SetOrigin(Vector(999999,999999,999999))
    end
end

-- Returns true if the hand with given id is currently holding something.
---@param handId integer | '0' | '1'
function GetHandHolding(handId)
    if handId == 0 then
        return thisEntity:Attribute_GetIntValue('HandHoldingLeft', 0) == 1
    else
        return thisEntity:Attribute_GetIntValue('HandHoldingRight', 0) == 1
    end
end

-- Assigns the hand with the given id to be holding something.
---@param handId integer | '0' | '1'
---@param isHolding boolean
function SetHandHolding(handId, isHolding)
    if handId == 0 then
        thisEntity:Attribute_SetIntValue('HandHoldingLeft', isHolding and 1 or 0)
    else
        thisEntity:Attribute_SetIntValue('HandHoldingRight', isHolding and 1 or 0)
    end
end

-- Prints entities in retrieval stack for debugging.
function PrintRetrievalStack()
    for k,v in ipairs(RetrievalStack) do
        print('\t'..v:GetName())
    end
end

