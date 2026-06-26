--[[
    RealRPG Clothing Studio - Client Pack Export
    Handles NUI callbacks for the export feature
]]

RegisterNUICallback('exportPack', function(data, cb)
    if type(data) ~= 'table' then
        cb({ ok = false, error = 'invalid_data' })
        return
    end

    TriggerServerEvent('realrpg_clothingstudio:server:exportPack', {
        name = data.name,
        designIds = data.designIds,
    })
    cb({ ok = true })
end)

RegisterNetEvent('realrpg_clothingstudio:client:packExported', function(result)
    if type(result) ~= 'table' then return end
    SendNUIMessage({
        action = 'packExported',
        data = result
    })
end)
