local studioOpen = false

RegisterNetEvent('realrpg_clothingstudio:client:openStudio', function(data)
    studioOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('realrpg_clothingstudio:client:designSaved', function(design)
    SendNUIMessage({ action = 'designSaved', design = design })
end)

RegisterNetEvent('realrpg_clothingstudio:client:loadDesign', function(design)
    SendNUIMessage({ action = 'loadDesign', design = design })
end)

RegisterNUICallback('close', function(_, cb)
    studioOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    TriggerEvent('realrpg_clothingstudio:client:previewRevert')
    cb({ ok = true })
end)

RegisterNUICallback('saveDesign', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:saveDesign', data)
    cb({ ok = true })
end)

RegisterNUICallback('printDesign', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:printDesign', data)
    cb({ ok = true })
end)

RegisterNUICallback('previewClothing', function(data, cb)
    TriggerEvent('realrpg_clothingstudio:client:previewClothing', data)
    cb({ ok = true })
end)

RegisterNUICallback('loadDesign', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:loadDesign', data.designId)
    cb({ ok = true })
end)

RegisterNUICallback('notify', function(data, cb)
    TriggerEvent('realrpg_clothingstudio:client:notify', data.message or 'Info', data.type or 'info')
    cb({ ok = true })
end)

RegisterNUICallback('generateAI', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:generateAI', data)
    cb({ ok = true })
end)


RegisterNUICallback('uploadBegin', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:uploadBegin', data)
    cb({ ok = true })
end)

RegisterNUICallback('uploadChunk', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:uploadChunk', data)
    cb({ ok = true })
end)

RegisterNUICallback('uploadFinish', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:uploadFinish', data)
    cb({ ok = true })
end)

RegisterNetEvent('realrpg_clothingstudio:client:uploadResult', function(result)
    SendNUIMessage({ action = 'uploadResult', result = result })
end)

RegisterNetEvent('realrpg_clothingstudio:client:aiResult', function(result)
    SendNUIMessage({ action = 'aiResult', result = result })
end)

RegisterNetEvent('realrpg_clothingstudio:client:marketplaceData', function(rows)
    SendNUIMessage({ action = 'marketplaceData', marketplace = rows or {} })
end)

RegisterNetEvent('realrpg_clothingstudio:client:marketplaceChanged', function()
    SendNUIMessage({ action = 'marketplaceChanged' })
end)

RegisterNUICallback('refreshMarketplace', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:refreshMarketplace', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('publishDesign', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:publishDesign', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('unpublishDesign', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:unpublishDesign', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('buyMarketplaceDesign', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:buyMarketplaceDesign', data or {})
    cb({ ok = true })
end)
