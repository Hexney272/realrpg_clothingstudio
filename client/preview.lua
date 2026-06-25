local previewOriginal = {}

local function snapshotComponent(ped, component)
    if previewOriginal[component] then return end
    previewOriginal[component] = {
        drawable = GetPedDrawableVariation(ped, component),
        texture = GetPedTextureVariation(ped, component)
    }
end

RegisterNetEvent('realrpg_clothingstudio:client:previewClothing', function(data)
    if type(data) ~= 'table' then return end
    local template = data.template
    if type(template) ~= 'table' then return end

    local ped = PlayerPedId()
    local component = tonumber(template.component)
    if not component then return end

    snapshotComponent(ped, component)
    SetPedComponentVariation(ped, component, tonumber(template.drawable) or 0, tonumber(template.texture) or 0, 2)
end)

RegisterNetEvent('realrpg_clothingstudio:client:previewRevert', function()
    local ped = PlayerPedId()
    for component, original in pairs(previewOriginal) do
        SetPedComponentVariation(ped, component, original.drawable or 0, original.texture or 0, 2)
    end
    previewOriginal = {}
end)
