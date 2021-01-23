
--================--
-- User variables --
--================--

-- Defines how transparent item is in backpack. 0=invisible, 255=opaque (mostly for debug)
local AlphaOnStore = 0

-- The time in seconds that the item can attempt to find the backpack after being released.
local TimeToStore = 0.8

-- Sound file names for storage/retrieval.
-- See user functions below for in-game changing.
-- Can be set per item for unique storage sounds.
local RetrieveSound = 'Inventory.BackpackGrabItemResin'
local StoreSound = 'Inventory.DepositItem'


--==================--
-- System variables --
--==================--

local fInitialStoreTime = 0
local sUniqueString = ''
local System


--=======================--
-- User called functions --
--=======================--

-- Places the item in backpack state by code without playing any sound.
-- This can be used to store items that the player should have on level start.
function PutInBackpack()
    print(GetUniqueName()..' put in backpack')
    thisEntity:SetThink(function() SetInBackpack(true) end, '', 0.05)
    -- User1 is fired when item is in backpack to allow further Hammer response
    DoEntFireByInstanceHandle(thisEntity, 'FireUser1', '', 0, nil, nil)
end

-- Tells the backpack system that this item may be retrieved from the backpack by the player.
-- Also pushes this item to the top of the stack for retrieval, meaning it will come out first if multiple items are waiting.
-- This will prevent the player from taking ammo from the backpack, but won't prevent putting it in.
-- Should be called with OnStartTouch trigger when the player is in the specific area the item needs to be used.
function EnableBackpackRetrieval()
    --UpdateSystemEntity()
    --System:GetPrivateScriptScope():MoveToTopOfRetrievalStack(thisEntity)
    GetSystemScope():MoveToTopOfRetrievalStack(thisEntity)
end
-- Tells the system to disallow this item from being retrieved.
-- Should be called with OnEndTouch trigger when the player leaves the are the item is used in.
function DisableBackpackRetrieval()
    --UpdateSystemEntity()
    --System:GetPrivateScriptScope():RemoveFromRetrievalStack(thisEntity)
    GetSystemScope():RemoveFromRetrievalStack(thisEntity)
end

-- Allowing/disallowing the item to be stored by putting it over the shoulder.
-- Can be useful for items which have already served their purpose.
function EnableBackpackStorage()
    SetCanStore(true)
end
function DisableBackpackStorage()
    SetCanStore(false)
end

-- Must be called using RunScriptCode with the name of the sound in single quotes, e.g.
-- SetStoreSound('Inventory.DepositItem')
-- DO NOT USE DOUBLE QUOTES IN YOUR OUTPUT/OVERRIDE, THIS MAY CORRUPT YOUR FILE
---@param sound string
function SetStoreSound(sound)
    if type(sound) == 'string' then
        StoreSound = sound
    end
end
-- See above function description.
---@param sound string
function SetRetrieveSound(sound)
    if type(sound) == 'string' then
        RetrieveSound = sound
    end
end


--=============================================--
-- Helper functions, not usually called by I/O --
--=============================================--

function Spawn()
    -- Source seems to save/restore these outputs to they only need to be
    -- added once on spawn.
    thisEntity:RedirectOutput('OnPlayerPickup', 'OnPlayerPickup', thisEntity)
    thisEntity:RedirectOutput('OnPhysGunDrop', 'OnPhysGunDrop', thisEntity)
end

function Activate(activateType)

    -- Finding the global backpack system entity.
    --if UpdateSystemEntity() == nil then return nil end
    --thisEntity:SetThink(function() print('system after short sleep '..tostring(System)) end, '', 2)


    -- Loading saved attributes to restore backpack state.
    if activateType == 2 then
        if thisEntity:Attribute_GetIntValue('IsInBackpack', 0) == 1 then
            SetInBackpack(true)
        end
    end

    -- Debug text | This can be commented-out or deleted safely.
    sUniqueString = DoUniqueString('')
    print('Backpack item loaded ('..GetUniqueName()..'), InBackpack:'..tostring(GetInBackpack())..', CanStore:'..tostring(GetCanStore()))

end



-- Function called by this entity on attached output with the same name.
function OnPlayerPickup()
    print(GetUniqueName()..' grabbed')
    if GetInBackpack() then
        print(GetUniqueName()..' taken from backpack')
        SetInBackpack(false)
        thisEntity:SetParent(nil, '')
        StartSoundEventFromPosition(RetrieveSound, thisEntity:GetOrigin())
        DoEntFireByInstanceHandle(thisEntity, 'FireUser2', '', 0, nil, nil)
    end
end
-- Function called by this entity on attached output with the same name.
function OnPhysGunDrop()
    print(GetUniqueName()..' dropped')
    if GetCanStore() then
        -- Item will be put in backpack immediately if touching backpack.
        -- Otherwise we give the item a moment to look for the backpack in case the player missed.
        print('AlphaOnStore '..tostring(AlphaOnStore))
        print('TimeToStore '..tostring(TimeToStore))
        print('RetrieveSound '..tostring(RetrieveSound))
        print('StoreSound '..tostring(StoreSound))
        print('fInitialStoreTime '..tostring(fInitialStoreTime))
        print('sUniqueString '..tostring(sUniqueString))
        --if System:GetPrivateScriptScope():IsTouchingBackpack(thisEntity) then
        if GetSystemScope():IsTouchingBackpack(thisEntity) then
            print(GetUniqueName()..' put in backpack first try')
            StartSoundEventFromPosition(StoreSound, thisEntity:GetOrigin())
            PutInBackpack()
        else
            print(GetUniqueName()..' attempting to put in backpack')
            fInitialStoreTime = Time()
            thisEntity:SetThink(ContinuousStoreAttempt, 'ContinuousStoreAttempt', 0)
        end
    end
end

-- Attempts to collide with the backpack constantly to allow throwing items behind
function ContinuousStoreAttempt()
    if (Time() - fInitialStoreTime) > TimeToStore then
            --print('Ran out of store attempt time')
        return nil
    end

    --if System:GetPrivateScriptScope():IsTouchingBackpack(thisEntity) then
    if GetSystemScope():IsTouchingBackpack(thisEntity) then
        -- Sound plays here so PutInBackpack can force without audio
            --print('Hit backpack, storing')
        StartSoundEventFromPosition(StoreSound, thisEntity:GetOrigin())
        PutInBackpack()
        return nil
    end

    -- Return immediate retry
    return 0
end

-- Puts the item in or out of backpack state and moves it.
---@param inPack boolean
function SetInBackpack(inPack)
    print(GetUniqueName()..' setting in backpack to '..tostring(inPack))
    thisEntity:Attribute_SetIntValue('IsInBackpack', inPack and 1 or 0)
    if inPack then
        --System:GetPrivateScriptScope():MoveItemToVirtualBackpack(thisEntity)
        GetSystemScope():MoveItemToVirtualBackpack(thisEntity)
        thisEntity:SetRenderAlpha(AlphaOnStore)
        local children = thisEntity:GetChildren()
        for k,v in ipairs(children) do
            v:SetRenderAlpha(AlphaOnStore)
        end
    else
        thisEntity:SetRenderAlpha(255)
        local children = thisEntity:GetChildren()
        for k,v in ipairs(children) do
            v:SetRenderAlpha(255)
        end
    end
end
-- Returns if the item is inside the backpack.
function GetInBackpack()
    return thisEntity:Attribute_GetIntValue('IsInBackpack', 0) == 1
end

---@param canStore boolean
function SetCanStore(canStore)
    thisEntity:Attribute_SetIntValue('CanStore', canStore and 1 or 0)
end
function GetCanStore()
    return thisEntity:Attribute_GetIntValue('CanStore', 1) == 1
end

--[[ function UpdateSystemEntity()
    System = Entities:FindByName(nil, '@backpack_system')
    print('Found system '..tostring(System))
    if System == nil then
        print('Failed to find backpack system. Make sure name has not been changed.')
        return nil
    end

    return System
end ]]

function GetSystemScope()
    return Entities:FindByName(nil, '@backpack_system'):GetPrivateScriptScope()
end

-- Returns entity name with sUniqueString on the end if it has one.
function GetUniqueName()
    return thisEntity:GetName()..sUniqueString
end
-- Returns the unique name and the model name.
function DebugString()
    return GetUniqueName()..' , '..thisEntity:GetModelName()
end




