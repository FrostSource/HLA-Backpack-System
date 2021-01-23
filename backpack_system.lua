
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
--local BackpackXOffset = -24
--local BackpackYOffset = 0
--local BackpackZOffset = 52


--==================--
-- System variables --
--==================--

--eEnableBackpack = nil
--eDisableBackpack = nil
--BackpackTrigger = nil
RetrievalStack = {}
HapticReady = true
ItemUpForRetrieval = nil


--================--
-- User functions --
--================--

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

    -- Find or create virtual backpack trigger
    --[[ BackpackTrigger = Entities:FindByName(nil, '@backpack_system_trigger')
    print('BACKPACK '..tostring(BackpackTrigger))
    if BackpackTrigger == nil then
        local w = BackpackWidth/2
        local l = BackpackLength/2
        local h = BackpackHeight/2
        BackpackTrigger = CreateTrigger(Vector(0,0,0), Vector(-w,-l,-h), Vector(w,l,h))
        BackpackTrigger:SetEntityName('@backpack_system_trigger')
    else
        print('System found existing BackpackTrigger')
    end ]]
    -- Parent to player and set offset
    thisEntity:SetThink(function()
        local player = Entities:GetLocalPlayer():GetHMDAvatar()
        local backpack = GetBackpackTrigger()
        print('making '..tostring(backpack)..' follow player')
        --BackpackTrigger:SetOrigin(player:GetOrigin() + (player:GetForwardVector() * BackpackOffset))
        backpack:SetParent(player, '')
        backpack:SetLocalOrigin(BackpackOffset)
        backpack:SetLocalAngles(0,0,0)
        end,
        '',0.1)

    -- Find or create Alyx backpack modifiers
    --[[ eDisableBackpack = Entities:FindByName(nil, '@backpack_system_disable_real_backpack')
    if eDisableBackpack == nil then
        eDisableBackpack = SpawnEntityFromTableSynchronous('info_hlvr_equip_player', {
            targetname = '@backpack_system_disable_backpack',
            equip_on_mapstart = "0",
            backpack_enabled = "0"})
    end
    eEnableBackpack = Entities:FindByName(nil, '@backpack_system_enable_real_backpack')
    if eEnableBackpack == nil then
        eEnableBackpack = SpawnEntityFromTableSynchronous('info_hlvr_equip_player', {
            targetname = '@backpack_system_enable_backpack',
            equip_on_mapstart = "0",
            backpack_enabled = "1"})
    end ]]

    -- Game events
    ListenToGameEvent('item_pickup', OnGlobalPickup, thisEntity)
    ListenToGameEvent('item_released', OnGlobalRelease, thisEntity)
end

-- Kills the trigger when this entity is destroyed.
-- TODO: Does this get called when the game exits?
-- TODO: Does the trigger get saved? This might not be necessary.
--function UpdateOnRemove()
--    BackpackTrigger:Kill()
--end

-- Returns if the given entity is touching the backpack.
---@param ent userdata
function IsTouchingBackpack(_, ent)
    --print('System asked if touching ('..ent:GetName()..'): '..tostring(BackpackTrigger:IsTouching(ent)))
    --print('does backpack exist? '..tostring(IsValidEntity(BackpackTrigger)))
    --return BackpackTrigger:IsTouching(ent)
    print('System asked if touching ('..ent:GetName()..'): '..tostring(GetBackpackTrigger():IsTouching(ent)))
    return GetBackpackTrigger():IsTouching(ent)
end

-- Disables the player backpack, no longer allowing ammo retrieval.
function DisableRealBackpack()    
    --DoEntFireByInstanceHandle(eDisableBackpack, 'EquipNow', '', 0, nil, nil)
    DoEntFire('@backpack_system_disable_real_backpack', 'EquipNow', '', 0, nil, nil)
end
function EnableRealBackpack()    
    --DoEntFireByInstanceHandle(eEnableBackpack, 'EquipNow', '', 0, nil, nil)
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

function GetBackpackTrigger()
    return Entities:FindByName(nil, '@backpack_system_trigger')
end

-- Function called externally by game event "item_pickup".
function OnGlobalPickup(_,event)
    --print('global pickup '..tostring(event.item_name)..' '..tostring(event.vr_tip_attachment))
    -- Sometimes this event is called without attachment
    if event.vr_tip_attachment == nil then return nil end

    -- Keep track of which hand is holding something
    local handId = GetHandIdFromType(event.vr_tip_attachment)
    SetHandHolding(handId, true)
    --print('hand '..handId..' grabbed')
end
-- Function called externally by game event "item_released".
function OnGlobalRelease(_,event)
    --print('global release '..tostring(event.vr_tip_attachment))
    -- Sometimes this event is called without attachment
    if event.vr_tip_attachment == nil then return nil end

    -- Keep track of which hand isn't holding something
    local handId = GetHandIdFromType(event.vr_tip_attachment)
    SetHandHolding(handId, false)
    --print('hand '..handId..' released')
end

-- Gives retrieval precedence to the given entity, ready to be retrieved.
---@param _ nil
---@param ent userdata
function MoveToTopOfRetrievalStack(_, ent)
    -- Remove the ent if it's in the stack first
    RemoveFromRetrievalStack(nil, ent)
    -- Then add it back in at the top (end)
    RetrievalStack[#RetrievalStack+1] = ent
    --print('System moved top of stack '..tostring(ent:GetName()))
    -- Start retrieval think
    --StartRetrieving()
end
-- Removes the given entity from the stack, no longer allowed to be retrieved.
---@param _ nil
---@param ent userdata
function RemoveFromRetrievalStack(_, ent)
    for i,e in ipairs(RetrievalStack) do
        if e == ent then
            table.remove(RetrievalStack, i)
            --print('System removed from stack '..tostring(ent:GetName()))
            break
        end
    end
    -- Can stop thinking if nothing else to take out
    --if #RetrievalStack == 0 then
        --StopRetrieving()
    --end
end
-- Allows the player to start retrieving items if not already.
function StartRetrieving()
    -- Make sure it's not running first
    if thisEntity:Attribute_GetIntValue('DoingRetrievalThink', 0) == 0 then
        --print('System started retrieving with '..#RetrievalStack..' in retrieval stack')
        PrintRetrievalStack()
        thisEntity:SetThink(RetrievalThink, 'RetrievalThink', RetrievalThinkTime)
        thisEntity:Attribute_SetIntValue('DoingRetrievalThink', 1)
    end
end
-- Disallows the player from retrieving items if they're allowed.
function StopRetrieving()
    if thisEntity:Attribute_GetIntValue('DoingRetrievalThink', 0) == 1 then
        --print('System stopped retrieving')
        thisEntity:StopThink('RetrievalThink')
        EnableRealBackpack()
        thisEntity:Attribute_SetIntValue('DoingRetrievalThink', 0)
    end
end
-- Main think function for getting items from the backpack.
-- Also handles dynamically enabling/disabling backpack if the player is trying to store ammo.
--[[ function RetrievalThink()
    local hmd = Entities:GetLocalPlayer():GetHMDAvatar()

    
    local handsTouchingBackpack = 0
    for h = 0, 1 do
        -- Make sure nothing being held (trying to store ammo)
        if not GetHandHolding(h) then
            -- Search the whole stack for first item inside backpack
            for i = #RetrievalStack, 1, -1 do
                if RetrievalStack[i]:GetPrivateScriptScope():GetInBackpack() then
                    local hand = hmd:GetVRHand(h)
                    --print('checking hand touching bp '..tostring(BackpackTrigger:IsTouching(hand)))
                    if BackpackTrigger:IsTouching(hand) then
                        --print('hand is touching and reaching!')
                        MoveItemToRetrievalHand(RetrievalStack[#RetrievalStack], hand)
                        DisableRealBackpack()
                        FireShortHaptic(hand, 1)
                        handsTouchingBackpack = handsTouchingBackpack + 1
                    else
                        --MoveItemToVirtualBackpack(nil, RetrievalStack[#RetrievalStack])
                    end
                end
            end
        end
    end

    -- If no hands are reaching back for an item then we can enable again
    if handsTouchingBackpack == 0 then
        EnableRealBackpack()
        FireShortHaptic(nil)
    end

    return RetrievalThinkTime
end ]]

function DoBackpackRetrieval(data)
    local hand = data.activator
    if hand:GetClassname() == 'hl_prop_vr_hand' then
        for i = #RetrievalStack, 1, -1 do
            if RetrievalStack[i]:GetPrivateScriptScope():GetInBackpack() then
                print(RetrievalStack[i]:GetPrivateScriptScope():GetUniqueName()..' in backpack and moving to hand')
                MoveItemToRetrievalHand(RetrievalStack[i], hand)
                DisableRealBackpack()
                FireShortHaptic(hand, 1)
                ItemUpForRetrieval = RetrievalStack[i]
                break
            end
        end
    end
end

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

-- test this separately
function MoveItemToRetrievalHand(ent, hand)
    local pos = hand:TransformPointEntityToWorld(Vector(-3, 3, -2))
    --local pos = hand:TransformPointEntityToWorld(Vector(0, 0, -3))
    ent:SetOrigin(pos)
    ent:SetParent(hand, '')
end
---@param _ nil
function MoveItemToVirtualBackpack(_, ent)
    ent:SetParent(nil, '')
    local virtual = Entities:FindByName(nil, VirtualBackpackTarget)
    if virtual ~= nil then
        --print('Found virtual backpack')
        ent:SetOrigin(virtual:GetOrigin())
    else
        --print('Didnt find virtual backpack')
        ent:SetOrigin(Vector(999999,999999,999999))
    end
end

function GetHandHolding(handId)
    if handId == 0 then
        return thisEntity:Attribute_GetIntValue('HandHoldingLeft', 0) == 1
    else
        return thisEntity:Attribute_GetIntValue('HandHoldingRight', 0) == 1
    end
end
function PrintRetrievalStack()
    for k,v in ipairs(RetrievalStack) do
        print('\t'..v:GetName())
    end
end
function SetHandHolding(handId, isHolding)
    if handId == 0 then
        thisEntity:Attribute_SetIntValue('HandHoldingLeft', isHolding and 1 or 0)
    else
        thisEntity:Attribute_SetIntValue('HandHoldingRight', isHolding and 1 or 0)
    end
end



--[[ function OnPickup(event)
    -- Sometimes this event is called without attachment
    if event.vr_tip_attachment == nil then return nil end
    -- Backpack system doesn't allow items with no name
    if event.item_name == '' then return nil end

    local handId = GetHandIdFromType(event.vr_tip_attachment)
    local hand = Entities:GetLocalPlayer():GetHMDAvatar():GetVRHand(handId)

    local nearest = Entities:FindByNameNearest(event.item_name, hand:GetOrigin(), 100)

end ]]




