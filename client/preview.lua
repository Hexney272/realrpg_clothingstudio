--[[
    RealRPG Clothing Studio - Client Preview
    Supports both component variations and prop previews
]]

local previewOriginal = {}
local previewOriginalProps = {}

RegisterNetEvent('realrpg_clothingstudio:client:previewClothing', function(data)
    if type(data) ~= 'table' then return end
    local template = data.template
    if type(template) ~= 'table' then return end
    local ped = PlayerPedId()

    -- Determine if this is a prop or component
    local isProp = template.isProp or (template.prop ~= nil and template.component == nil)

    if isProp then
        -- PROP preview (SetPedPropIndex)
        local propId = tonumber(template.prop)
        if not propId then return end

        -- Save original prop state
        if not previewOriginalProps[propId] then
            previewOriginalProps[propId] = {
                drawable = GetPedPropIndex(ped, propId),
                texture = GetPedPropTextureIndex(ped, propId)
            }
        end

        local drawable = tonumber(template.drawable) or 0
        local texture = tonumber(template.texture) or 0

        if drawable < 0 then
            ClearPedProp(ped, propId)
        else
            SetPedPropIndex(ped, propId, drawable, texture, true)
        end
    else
        -- COMPONENT preview (SetPedComponentVariation)
        local component = tonumber(template.component)
        if not component then return end

        -- Save original component state
        if not previewOriginal[component] then
            previewOriginal[component] = {
                drawable = GetPedDrawableVariation(ped, component),
                texture = GetPedTextureVariation(ped, component)
            }
        end

        SetPedComponentVariation(ped, component, tonumber(template.drawable) or 0, tonumber(template.texture) or 0, 2)
    end
end)

-- Reset preview to original clothing
RegisterNetEvent('realrpg_clothingstudio:client:resetPreview', function()
    local ped = PlayerPedId()

    -- Reset components
    for component, original in pairs(previewOriginal) do
        SetPedComponentVariation(ped, component, original.drawable, original.texture, 2)
    end
    previewOriginal = {}

    -- Reset props
    for propId, original in pairs(previewOriginalProps) do
        if original.drawable < 0 then
            ClearPedProp(ped, propId)
        else
            SetPedPropIndex(ped, propId, original.drawable, original.texture, true)
        end
    end
    previewOriginalProps = {}
end)

-- NUI callback for preview reset
RegisterNUICallback('resetPreview', function(_, cb)
    TriggerEvent('realrpg_clothingstudio:client:resetPreview')
    cb({ ok = true })
end)
