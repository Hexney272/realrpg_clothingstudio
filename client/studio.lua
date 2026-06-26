--[[
    RealRPG Clothing Studio - Client Studio NUI Controller
    Handles opening/closing the editor, NUI callbacks, design operations
]]

local studioOpen = false

-- ═══════════════════════════════════════════════════════════════
-- OPEN / CLOSE
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:client:openStudio', function(data)
    if studioOpen then return end -- Prevent double-open
    studioOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
    -- Activate 3D preview camera
    TriggerEvent('realrpg_clothingstudio:client:openStudio3D')
end)

RegisterNUICallback('close', function(_, cb)
    if not studioOpen then cb({ ok = true }) return end
    studioOpen = false
    SetNuiFocus(false, false)
    -- Reset preview on close
    TriggerEvent('realrpg_clothingstudio:client:resetPreview')
    -- Deactivate 3D preview camera
    TriggerEvent('realrpg_clothingstudio:client:closeStudio3D')
    cb({ ok = true })
end)

-- ═══════════════════════════════════════════════════════════════
-- DESIGN OPERATIONS
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('saveDesign', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = false }) return end
    TriggerServerEvent('realrpg_clothingstudio:server:saveDesign', data)
    cb({ ok = true })
end)

RegisterNUICallback('printDesign', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = false }) return end
    TriggerServerEvent('realrpg_clothingstudio:server:printDesign', data)
    cb({ ok = true })
end)

RegisterNUICallback('deleteDesign', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = false }) return end
    TriggerServerEvent('realrpg_clothingstudio:server:deleteDesign', data)
    cb({ ok = true })
end)

-- ═══════════════════════════════════════════════════════════════
-- PREVIEW
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('previewClothing', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = true }) return end
    TriggerEvent('realrpg_clothingstudio:client:previewClothing', data)
    cb({ ok = true })
end)

RegisterNUICallback('resetPreview', function(_, cb)
    TriggerEvent('realrpg_clothingstudio:client:resetPreview')
    cb({ ok = true })
end)

-- ═══════════════════════════════════════════════════════════════
-- SERVER RESPONSES
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:client:designSaved', function(design)
    if not studioOpen then return end
    SendNUIMessage({ action = 'designSaved', design = design })
end)

RegisterNetEvent('realrpg_clothingstudio:client:designDeleted', function(designId)
    if not studioOpen then return end
    SendNUIMessage({ action = 'designDeleted', designId = designId })
end)

RegisterNetEvent('realrpg_clothingstudio:client:uploadResult', function(data)
    if not studioOpen then return end
    SendNUIMessage({ action = 'uploadResult', data = data })
end)

-- ═══════════════════════════════════════════════════════════════
-- ESCAPE KEY HANDLING
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        if studioOpen then
            DisableControlAction(0, 1, true)   -- Look L/R
            DisableControlAction(0, 2, true)   -- Look U/D
            DisableControlAction(0, 142, true) -- MeleeAttackAlternate
            DisableControlAction(0, 106, true) -- VehicleMouseControlOverride

            if IsDisabledControlJustPressed(0, 200) then -- ESC
                studioOpen = false
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'forceClose' })
                TriggerEvent('realrpg_clothingstudio:client:resetPreview')
                TriggerEvent('realrpg_clothingstudio:client:closeStudio3D')
            end
        else
            Wait(500) -- Sleep when studio is closed
        end
    end
end)
