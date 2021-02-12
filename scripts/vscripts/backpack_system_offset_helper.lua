
TargetEntity = TargetEntity or nil

function Activate()
end

function SetTargetEntity(_, entity)
    if IsValidEntity(entity) then
        TargetEntity = entity
    else
        print('Target entity', tostring(entity), 'is not valid')
    end
end

function UpdateHand(handid)
    if not IsValidEntity(TargetEntity) then return end

    local hand = Entities:GetLocalPlayer():GetHMDAvatar():GetVRHand(handid)
    local pos = Vector(thisEntity:Attribute_GetIntValue('OffsetX',0),thisEntity:Attribute_GetIntValue('OffsetY',0),thisEntity:Attribute_GetIntValue('OffsetZ',0));
    if handid == 0 then
        local axis = Vector(0, 1, 0)
        pos = pos - 2 * pos:Dot(axis) * axis
    end
    TargetEntity:SetOrigin(hand:TransformPointEntityToWorld(pos))
    local angle = RotateOrientation(hand:GetAngles(), QAngle(thisEntity:Attribute_GetIntValue('Pitch',0),thisEntity:Attribute_GetIntValue('Yaw',0),thisEntity:Attribute_GetIntValue('Roll',0)))
    TargetEntity:SetAngles(angle.x,angle.y,angle.z)
    TargetEntity:SetParent(hand, '')
end

function ChangePitch(amount)
    thisEntity:Attribute_SetIntValue('Pitch',thisEntity:Attribute_GetIntValue('Pitch',0) + amount)
    UpdateDisplay()
end
function ChangeYaw(amount)
    thisEntity:Attribute_SetIntValue('Yaw',thisEntity:Attribute_GetIntValue('Yaw',0) + amount)
    UpdateDisplay()
end
function ChangeRoll(amount)
    thisEntity:Attribute_SetIntValue('Roll',thisEntity:Attribute_GetIntValue('Roll',0) + amount)
    UpdateDisplay()
end

function ChangeOffsetX(amount)
    thisEntity:Attribute_SetIntValue('OffsetX',thisEntity:Attribute_GetIntValue('OffsetX',0) + amount)
    UpdateDisplay()
end
function ChangeOffsetY(amount)
    thisEntity:Attribute_SetIntValue('OffsetY',thisEntity:Attribute_GetIntValue('OffsetY',0) + amount)
    UpdateDisplay()
end
function ChangeOffsetZ(amount)
    thisEntity:Attribute_SetIntValue('OffsetZ',thisEntity:Attribute_GetIntValue('OffsetZ',0) + amount)
    UpdateDisplay()
end

-- Not usable yet
function GetAngleFromHand(handid)
    if not IsValidEntity(TargetEntity) then return end

    local hand = Entities:GetLocalPlayer():GetHMDAvatar():GetVRHand(handid)
    local r = RotateOrientation(hand:GetAngles(), TargetEntity:GetAngles())
    thisEntity:Attribute_SetIntValue('Pitch',r.x)
    thisEntity:Attribute_SetIntValue('Yaw',r.y)
    thisEntity:Attribute_SetIntValue('Roll',r.z)
    UpdateDisplay()
end

-- Not usable yet
function GetOffsetFromHand(handid)
    if not IsValidEntity(TargetEntity) then return end

    local hand = Entities:GetLocalPlayer():GetHMDAvatar():GetVRHand(handid)
    local o = hand:TransformPointWorldToEntity(TargetEntity:GetOrigin())
    thisEntity:Attribute_SetIntValue('OffsetX',o.x)
    thisEntity:Attribute_SetIntValue('OffsetY',o.y)
    thisEntity:Attribute_SetIntValue('OffsetZ',o.z)
    UpdateDisplay()
end

function ResetAngle()
    thisEntity:Attribute_SetIntValue('Pitch',0)
    thisEntity:Attribute_SetIntValue('Yaw',0)
    thisEntity:Attribute_SetIntValue('Roll',0)
    UpdateDisplay()
end

function ResetOffset()
    thisEntity:Attribute_SetIntValue('OffsetX',0)
    thisEntity:Attribute_SetIntValue('OffsetY',0)
    thisEntity:Attribute_SetIntValue('OffsetZ',0)
    UpdateDisplay()
end

function UnparentTargetEntity()
    if not IsValidEntity(TargetEntity) then return end

    TargetEntity:SetParent(nil,'')
end

function UpdateDisplay()
    DoEntFire('offset_text', 'SetMessage', thisEntity:Attribute_GetIntValue('OffsetX',0)..', '..thisEntity:Attribute_GetIntValue('OffsetY',0)..', '..thisEntity:Attribute_GetIntValue('OffsetZ',0), 0, nil, nil)
    DoEntFire('angle_text', 'SetMessage', thisEntity:Attribute_GetIntValue('Pitch',0)..', '..thisEntity:Attribute_GetIntValue('Yaw',0)..', '..thisEntity:Attribute_GetIntValue('Roll',0), 0, nil, nil)
    print('Offset:', thisEntity:Attribute_GetIntValue('OffsetX',0)..', '..thisEntity:Attribute_GetIntValue('OffsetY',0)..', '..thisEntity:Attribute_GetIntValue('OffsetZ',0))
    print('Angle:', thisEntity:Attribute_GetIntValue('Pitch',0)..', '..thisEntity:Attribute_GetIntValue('Yaw',0)..', '..thisEntity:Attribute_GetIntValue('Roll',0))
end
