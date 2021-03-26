
--TODO: Save/restore user defined alpha


--================--
-- User variables --
--================--

-- The time in seconds that the item can attempt to find the backpack after being released.
local TimeToStore = 0.8

-- Sound file names for storage/retrieval.
-- See user functions below for in-game changing.
-- Can be set per item for unique storage sounds.
local DefaultRetrieveSound = 'Inventory.BackpackGrabItemResin'
local DefaultStoreSound = 'Inventory.DepositItem'

-- Defines how transparent item is in backpack. 0=invisible, 255=opaque (mostly for debug)
local AlphaOnStore = 0


--==================--
-- System variables --
--==================--

local fInitialStoreTime = 0
local sUniqueString = ''
CacheHealth = CacheHealth or 0


--=======================--
-- User called functions --
--=======================--

-- Places the item in backpack state by code without playing any sound.
-- This can be used to store items that the player should have on level start.
function PutInBackpack()
    thisEntity:SetThink(function() SetInBackpack(true) end, '', 0.05)
    -- User1 is fired when item is in backpack to allow further Hammer response
    DoEntFireByInstanceHandle(thisEntity, 'FireUser1', '', 0, nil, nil)
    DoEntFire('@backpack_system', 'FireUser1', '', 0, nil, nil)
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
        thisEntity:SetContext('RetrieveSound', sound, 0)
    end
end
-- See above function description.
---@param sound string
function SetRetrieveSound(sound)
    if type(sound) == 'string' then
        thisEntity:SetContext('StoreSound', sound, 0)
    end
end


--=============================================--
-- Helper functions, not usually called by I/O --
--=============================================--
--#region

function Spawn(spawnkeys)
    -- Getting custom keys
    local value = nil
    value = spawnkeys:GetValue('StoreSound')
    if value and value ~= '' then
        SetStoreSound(value)
    else
        SetStoreSound(DefaultStoreSound)
    end
    value = spawnkeys:GetValue('RetrieveSound')
    if value and value ~= '' then
        SetRetrieveSound(value)
    else
        SetRetrieveSound(DefaultRetrieveSound)
    end

    local pitch,yaw,roll
    value = spawnkeys:GetValue('GrabAngle')
    if type(value) == 'string' then
        local t = SplitString(value)
        pitch,yaw,roll = tonumber(t[1]), tonumber(t[2]), tonumber(t[3])
    end
    thisEntity:Attribute_SetIntValue('GrabPitch', pitch or 0)
    thisEntity:Attribute_SetIntValue('GrabYaw', yaw or 0)
    thisEntity:Attribute_SetIntValue('GrabRoll', roll or 0)

    local x,y,z
    value = spawnkeys:GetValue('GrabOffset')
    if type(value) == 'string' then
        local t = SplitString(value)
        x,y,z = tonumber(t[1]), tonumber(t[2]), tonumber(t[3])
        --print('custom item with offset:',x,y,z)
    end
    thisEntity:Attribute_SetIntValue('GrabX', x or -3)
    thisEntity:Attribute_SetIntValue('GrabY', y or 3)
    thisEntity:Attribute_SetIntValue('GrabZ', z or -2)

    -- Source seems to save/restore these outputs to they only need to be
    -- added once on spawn.
    thisEntity:RedirectOutput('OnPlayerUse', 'OnPlayerPickup', thisEntity)
    thisEntity:RedirectOutput('OnPhysGunDrop', 'OnPhysGunDrop', thisEntity)
end

function Activate(activateType)
    -- Loading saved attributes to restore backpack state.
    if activateType == 2 then
        if thisEntity:Attribute_GetIntValue('IsInBackpack', 0) == 1 then
            SetInBackpack(true)
        end
    end

    -- Debug text | This can be commented-out or deleted safely.
    --sUniqueString = DoUniqueString('')
    --print('Backpack item loaded ('..GetUniqueName()..'), InBackpack:'..tostring(GetInBackpack())..', CanStore:'..tostring(GetCanStore()))

end

-- Function called by this entity on attached output with the same name.
function OnPlayerPickup()
    if GetInBackpack() then
        SetInBackpack(false)
        thisEntity:SetParent(nil, '')
        GetSystemScope():EnableRealBackpack()
        local sound = thisEntity:GetContext('RetrieveSound') or DefaultRetrieveSound
        StartSoundEventFromPosition(sound, thisEntity:GetOrigin())
        DoEntFireByInstanceHandle(thisEntity, 'FireUser2', '', 0, nil, nil)
        DoEntFire('@backpack_system', 'FireUser2', '', 0, nil, nil)
    end
end

-- Function called by this entity on attached output with the same name.
function OnPhysGunDrop()
    if GetCanStore() then
        -- Item will be put in backpack immediately if touching backpack.
        -- Otherwise we give the item a moment to look for the backpack in case the player missed.
        if not AttemptToStore() then
            fInitialStoreTime = Time()
            thisEntity:SetThink(ContinuousStoreAttempt, 'ContinuousStoreAttempt', 0)
        end
    end
end

-- Attempts to collide with the backpack constantly to allow throwing items behind
function ContinuousStoreAttempt()
    if (Time() - fInitialStoreTime) > TimeToStore then
        return nil
    end

    if AttemptToStore() then
        return nil
    end

    -- Return immediate retry
    return 0
end

function AttemptToStore()
    if GetSystemScope():StorageCheck(thisEntity) then
        -- Sound plays here so PutInBackpack can force without audio
        local sound = thisEntity:GetContext('StoreSound') or DefaultStoreSound
        StartSoundEventFromPosition(sound, thisEntity:GetOrigin())
        PutInBackpack()
        return true
    end
    return false
end

-- Returns if the item is inside the backpack.
function GetInBackpack()
    return thisEntity:Attribute_GetIntValue('IsInBackpack', 0) == 1
end

-- Puts the item in or out of backpack state and moves it.
---@param inPack boolean
function SetInBackpack(inPack)
    thisEntity:Attribute_SetIntValue('IsInBackpack', inPack and 1 or 0)
    if inPack then
        thisEntity:Attribute_SetIntValue('CacheHealth', thisEntity:GetHealth())
        thisEntity:SetHealth(99999)
        thisEntity:SetRenderAlpha(AlphaOnStore)
        GetSystemScope():MoveItemToVirtualBackpack(thisEntity)
        local children = thisEntity:GetChildren()
        for _,c in ipairs(children) do
            c:SetRenderAlpha(AlphaOnStore)
        end
        thisEntity:DisableMotion()
    else
        thisEntity:SetHealth(thisEntity:Attribute_GetIntValue('CacheHealth',1))
        thisEntity:SetRenderAlpha(255)
        local children = thisEntity:GetChildren()
        for _,c in ipairs(children) do
            c:SetRenderAlpha(255)
        end
        thisEntity:EnableMotion()
    end
end

-- Returns true if the item is allowed to be stored in the backpack.
function GetCanStore()
    return thisEntity:Attribute_GetIntValue('CanStore', 1) == 1
end

-- Allow backpack to be stored with true or disallow with false.
---@param canStore boolean
function SetCanStore(canStore)
    thisEntity:Attribute_SetIntValue('CanStore', canStore and 1 or 0)
end

function GetSystemScope()
    return Entities:FindByName(nil, '@backpack_system'):GetPrivateScriptScope()
end

function GetGrabAngles()
    return QAngle(
        thisEntity:Attribute_GetIntValue('GrabPitch',0),
        thisEntity:Attribute_GetIntValue('GrabYaw',0),
        thisEntity:Attribute_GetIntValue('GrabRoll',0)
    )
end

function GetGrabOffset()
    return Vector(
        thisEntity:Attribute_GetIntValue('GrabX',-3),
        thisEntity:Attribute_GetIntValue('GrabY',3),
        thisEntity:Attribute_GetIntValue('GrabZ',-2)
    )
end

---https://stackoverflow.com/a/7615129
---@param inputstr string
---@param sep string
---@return table
function SplitString (inputstr, sep)
    if sep == nil then
        sep = '%s'
    end
    local t = {}
    for str in string.gmatch(inputstr, '([^'..sep..']+)') do
        table.insert(t, str)
    end
    return t
end

-- Returns entity name with sUniqueString on the end if it has one.
function GetUniqueName()
    return thisEntity:GetName()..tostring(sUniqueString)
end

-- Returns the unique name and the model name.
function DebugString()
    return GetUniqueName()..' , '..thisEntity:GetModelName()
end

--#endregion



