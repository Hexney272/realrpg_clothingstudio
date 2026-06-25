--[[
    RealRPG Clothing Studio - Studio NUI Controller
    
    A NUI megnyitás/bezárás és alapvető callback-ek kezelése.
    A preview logikát a preview.lua kezeli (DUI-val).
]]

local studioOpen = false

function IsStudioOpen()
    return studioOpen
end

exports('IsStudioOpen', IsStudioOpen)

RegisterNetEvent('realrpg_clothingstudio:client:openStudio', function(data)
    studioOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

-- MEGJEGYZÉS: A 'close' NUI callback-et a preview.lua regisztrálja (ő kezeli a DUI cleanup-ot is).
-- A studioOpen state-et event-tel kezeljük:
RegisterNetEvent('realrpg_clothingstudio:client:studioClose', function()
    studioOpen = false
    SetNuiFocus(false, false)
end)

RegisterNUICallback('saveDesign', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:saveDesign', data)
    cb({ ok = true })
end)

RegisterNUICallback('printDesign', function(data, cb)
    TriggerServerEvent('realrpg_clothingstudio:server:printDesign', data)
    cb({ ok = true })
end)

RegisterNetEvent('realrpg_clothingstudio:client:designSaved', function(design)
    SendNUIMessage({ action = 'designSaved', design = design })
end)
