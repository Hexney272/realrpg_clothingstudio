local equipped = {}
local remoteEquipped = {}
local originalComponents = {}

local function snapshotOriginal(category, component)
    if originalComponents[category] then return end
    local ped = PlayerPedId()
    originalComponents[category] = {
        component = component,
        drawable = GetPedDrawableVariation(ped, component),
        texture = GetPedTextureVariation(ped, component)
    }
end

local function applyClothingToPed(ped, metadata)
    if not DoesEntityExist(ped) or type(metadata) ~= 'table' then return end

    local component = tonumber(metadata.component)
    local drawable = tonumber(metadata.drawable)
    local texture = tonumber(metadata.texture or 0)
    if not component or drawable == nil then return end

    if ApplyRealRPGRuntimeTexture then
        ApplyRealRPGRuntimeTexture(metadata)
    end

    SetPedComponentVariation(ped, component, drawable, texture, 2)
end

local function clearLocal(category)
    local ped = PlayerPedId()
    if category then
        local original = originalComponents[category]
        if original then
            SetPedComponentVariation(ped, original.component, original.drawable or 0, original.texture or 0, 2)
            originalComponents[category] = nil
        end
        equipped[category] = nil
    else
        for cat, original in pairs(originalComponents) do
            SetPedComponentVariation(ped, original.component, original.drawable or 0, original.texture or 0, 2)
            equipped[cat] = nil
        end
        originalComponents = {}
    end
end

RegisterNetEvent('realrpg_clothingstudio:client:wearItem', function(metadata)
    if type(metadata) ~= 'table' then return end

    local category = metadata.category or 'tops'
    local component = tonumber(metadata.component)
    if component then snapshotOriginal(category, component) end

    local ped = PlayerPedId()
    applyClothingToPed(ped, metadata)
    equipped[category] = metadata
    TriggerServerEvent('realrpg_clothingstudio:server:setEquipped', metadata)
    TriggerEvent('realrpg_clothingstudio:client:previewRevert')
end)

RegisterNetEvent('realrpg_clothingstudio:client:loadEquipped', function(data)
    equipped = data or {}
    local ped = PlayerPedId()

    for category, metadata in pairs(equipped) do
        if metadata.component then snapshotOriginal(category, tonumber(metadata.component)) end
        applyClothingToPed(ped, metadata)
    end
end)

RegisterNetEvent('realrpg_clothingstudio:client:syncWearable', function(serverId, metadata)
    if type(metadata) ~= 'table' or not serverId then return end

    remoteEquipped[serverId] = remoteEquipped[serverId] or {}
    remoteEquipped[serverId][metadata.category or 'tops'] = metadata

    local player = GetPlayerFromServerId(serverId)
    if player ~= -1 then
        local ped = GetPlayerPed(player)
        if ped ~= 0 and ped ~= PlayerPedId() then
            applyClothingToPed(ped, metadata)
        end
    end
end)

RegisterNetEvent('realrpg_clothingstudio:client:clearRemoteWearable', function(serverId, category)
    if not serverId then return end
    if serverId == GetPlayerServerId(PlayerId()) then
        clearLocal(category)
        return
    end

    if not remoteEquipped[serverId] then return end
    if category then
        remoteEquipped[serverId][category] = nil
    else
        remoteEquipped[serverId] = nil
    end
end)

RegisterNetEvent('realrpg_clothingstudio:client:printLines', function(lines)
    print('^2[RealRPG Clothing Studio]^7 Runtime slot status:')
    for _, line in ipairs(lines or {}) do print(line) end
end)

RegisterCommand('rrcs_unwear', function(_, args)
    local category = args and args[1]
    if category == 'all' then category = nil end
    TriggerServerEvent('realrpg_clothingstudio:server:clearEquipped', category)
end)

CreateThread(function()
    while true do
        Wait(5000)
        for serverId, categories in pairs(remoteEquipped) do
            local player = GetPlayerFromServerId(serverId)
            if player ~= -1 then
                local ped = GetPlayerPed(player)
                if ped ~= 0 and ped ~= PlayerPedId() then
                    for _, metadata in pairs(categories) do
                        applyClothingToPed(ped, metadata)
                    end
                end
            end
        end
    end
end)
