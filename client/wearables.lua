--[[
    RealRPG Clothing Studio - Client Wearables
    Handles equipping/unequipping custom clothing (components + props)
    Integrates with texture_runtime.lua for DUI texture application
]]

local equipped = {}
local remoteEquipped = {}

local function applyClothing(metadata)
    if type(metadata) ~= 'table' then return end
    local ped = PlayerPedId()

    -- Determine if prop or component
    local isProp = metadata.isProp or (metadata.prop ~= nil and metadata.component == nil)

    if isProp then
        -- PROP (hats, glasses, ears, watches, bracelets)
        local propId = tonumber(metadata.prop)
        local drawable = tonumber(metadata.drawable)
        if not propId then return end

        if drawable and drawable >= 0 then
            SetPedPropIndex(ped, propId, drawable, tonumber(metadata.texture or 0), true)
        else
            ClearPedProp(ped, propId)
        end
    else
        -- COMPONENT (tops, pants, shoes, etc.)
        local component = tonumber(metadata.component)
        local drawable = tonumber(metadata.drawable)
        local texture = tonumber(metadata.texture or 0)
        if not component or not drawable then return end

        SetPedComponentVariation(ped, component, drawable, texture, 2)
    end

    -- Apply runtime texture if available
    if metadata.runtime and type(metadata.runtime) == 'table' then
        if ApplyRealRPGRuntimeTexture then
            ApplyRealRPGRuntimeTexture(metadata)
        end
    end
end

local function removeClothing(metadata)
    if type(metadata) ~= 'table' then return end
    local ped = PlayerPedId()

    local isProp = metadata.isProp or (metadata.prop ~= nil and metadata.component == nil)

    if isProp then
        local propId = tonumber(metadata.prop)
        if propId then ClearPedProp(ped, propId) end
    else
        local component = tonumber(metadata.component)
        if component then
            -- Reset to default (drawable 0, texture 0)
            SetPedComponentVariation(ped, component, 0, 0, 2)
        end
    end

    -- Remove runtime texture
    if metadata.runtime and RemoveRealRPGRuntimeTexture then
        RemoveRealRPGRuntimeTexture(metadata)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:client:wearItem', function(metadata)
    if type(metadata) ~= 'table' then return end

    -- Detect prop from category
    local category = metadata.category
    if category and Templates and Templates.IsProp then
        metadata.isProp = Templates.IsProp(category)
        if metadata.isProp and not metadata.prop then
            local catMeta = Templates.Categories and Templates.Categories[category]
            if catMeta then metadata.prop = catMeta.propId end
        end
    end

    applyClothing(metadata)
    equipped[metadata.category or 'unknown'] = metadata
    TriggerServerEvent('realrpg_clothingstudio:server:setEquipped', metadata)
end)

RegisterNetEvent('realrpg_clothingstudio:client:loadEquipped', function(data)
    if type(data) ~= 'table' then return end
    equipped = data

    for category, metadata in pairs(equipped) do
        if type(metadata) == 'table' then
            -- Ensure isProp is set correctly
            if Templates and Templates.IsProp then
                metadata.isProp = Templates.IsProp(category)
                if metadata.isProp and not metadata.prop then
                    local catMeta = Templates.Categories and Templates.Categories[category]
                    if catMeta then metadata.prop = catMeta.propId end
                end
            end
            applyClothing(metadata)
        end
    end
end)

RegisterNetEvent('realrpg_clothingstudio:client:removeWearable', function(category)
    if equipped[category] then
        removeClothing(equipped[category])
        equipped[category] = nil
        TriggerServerEvent('realrpg_clothingstudio:server:removeEquipped', category)
    end
end)

RegisterNetEvent('realrpg_clothingstudio:client:syncWearable', function(serverId, metadata)
    if type(metadata) ~= 'table' then return end
    if serverId == GetPlayerServerId(PlayerId()) then return end -- Skip self

    remoteEquipped[serverId] = remoteEquipped[serverId] or {}
    remoteEquipped[serverId][metadata.category or 'unknown'] = metadata
end)

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP on resource stop
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Clear all runtime textures
    if ClearRealRPGRuntimeTextureCache then
        ClearRealRPGRuntimeTextureCache()
    end
end)
