--[[
    RealRPG Clothing Studio - 3D Preview Camera System
    
    A stúdió megnyitásakor létrehoz egy kamerát a player ped-re,
    amely a NUI mögött látszik (transparent background).
    Így a ped-en lévő ruha (a stream mappából streamelt YDD) 
    valódi 3D-ben jelenik meg élő preview-ként.
]]

local previewCam = nil
local previewActive = false
local camRotation = 180.0   -- Elölről nézzük a pedet (szemben áll velünk)
local camZoom = 1.0
local camDistance = 1.8
local camFov = 32.0
local camHeightOffset = 0.0 -- Extra height offset from view preset

-- A ped mellkasának magassága (a ped z koordinátája a talp)
local PED_CENTER_HEIGHT = 0.5  -- ~mellkas magasság

-- Nézet presetjei (height = a nézet célpontja a pedhez képest)
local VIEW_PRESETS = {
    full     = { targetHeight = 0.4,  distance = 1.8, fov = 32.0 },
    upper    = { targetHeight = 0.6,  distance = 1.2, fov = 28.0 },
    lower    = { targetHeight = -0.1, distance = 1.3, fov = 28.0 },
    feet     = { targetHeight = -0.4, distance = 0.9, fov = 25.0 },
    head     = { targetHeight = 0.75, distance = 0.8, fov = 25.0 },
}

local currentView = 'full'
local autoRotate = false
local pedHeadingOnOpen = 0.0

-- ═══════════════════════════════════════════════════════════════
-- CAMERA CREATION / DESTRUCTION
-- ═══════════════════════════════════════════════════════════════

local function createPreviewCamera()
    if previewCam then return end

    local ped = PlayerPedId()

    -- Mentjük a ped irányát és szembefordítjuk a kamerával
    pedHeadingOnOpen = GetEntityHeading(ped)

    -- Ped-et megállítjuk
    FreezeEntityPosition(ped, true)
    TaskStandStill(ped, -1)

    -- Kamera létrehozás
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 800, true, false)

    -- Alapértelmezett nézet beállítás
    camRotation = 180.0
    camZoom = 1.0
    camHeightOffset = VIEW_PRESETS.full.targetHeight
    camDistance = VIEW_PRESETS.full.distance
    camFov = VIEW_PRESETS.full.fov
    currentView = 'full'
    autoRotate = false

    previewActive = true
    updateCameraPosition()
end

local function destroyPreviewCamera()
    if not previewCam then return end

    RenderScriptCams(false, true, 800, true, false)
    SetCamActive(previewCam, false)
    DestroyCam(previewCam, false)
    previewCam = nil
    previewActive = false
    autoRotate = false

    -- Ped feloldása
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
end

-- ═══════════════════════════════════════════════════════════════
-- CAMERA POSITIONING
-- ═══════════════════════════════════════════════════════════════

function updateCameraPosition()
    if not previewCam or not previewActive then return end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- A kamera a ped körül kering
    -- camRotation = 180 = a ped előtt (szemből látjuk)
    local angleRad = math.rad(heading + camRotation)
    local dist = camDistance * camZoom

    local camX = pedCoords.x - (math.sin(angleRad) * dist)
    local camY = pedCoords.y + (math.cos(angleRad) * dist)
    -- Kamera magasság: ped talp + offset (a preset alapján)
    local camZ = pedCoords.z + camHeightOffset

    SetCamCoord(previewCam, camX, camY, camZ)

    -- Kamera célpont: a ped mellkasa/célpontja
    local lookAtX = pedCoords.x
    local lookAtY = pedCoords.y
    local lookAtZ = pedCoords.z + camHeightOffset

    PointCamAtCoord(previewCam, lookAtX, lookAtY, lookAtZ)
    SetCamFov(previewCam, camFov)
end

-- ═══════════════════════════════════════════════════════════════
-- VIEW SWITCHING
-- ═══════════════════════════════════════════════════════════════

local function setView(viewName)
    local preset = VIEW_PRESETS[viewName]
    if not preset then return end

    currentView = viewName
    camHeightOffset = preset.targetHeight
    camDistance = preset.distance
    camFov = preset.fov
    updateCameraPosition()
end

-- ═══════════════════════════════════════════════════════════════
-- ROTATION / ZOOM CONTROLS
-- ═══════════════════════════════════════════════════════════════

local function rotateLeft(amount)
    camRotation = camRotation - (amount or 15.0)
    if camRotation < 0 then camRotation = camRotation + 360.0 end
    updateCameraPosition()
end

local function rotateRight(amount)
    camRotation = camRotation + (amount or 15.0)
    if camRotation >= 360 then camRotation = camRotation - 360.0 end
    updateCameraPosition()
end

local function zoomIn()
    camZoom = math.max(0.5, camZoom - 0.1)
    updateCameraPosition()
end

local function zoomOut()
    camZoom = math.min(2.0, camZoom + 0.1)
    updateCameraPosition()
end

local function resetCamera()
    camRotation = 180.0
    camZoom = 1.0
    autoRotate = false
    setView('full')
end

-- ═══════════════════════════════════════════════════════════════
-- NUI CALLBACKS (from web UI buttons)
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('preview3d_rotate', function(data, cb)
    if not previewActive then cb({ ok = false }) return end
    local direction = data.direction or 'right'
    local amount = tonumber(data.amount) or 30.0

    if direction == 'left' then
        rotateLeft(amount)
    else
        rotateRight(amount)
    end
    cb({ ok = true, rotation = camRotation })
end)

RegisterNUICallback('preview3d_zoom', function(data, cb)
    if not previewActive then cb({ ok = false }) return end
    local direction = data.direction or 'in'

    if direction == 'in' then
        zoomIn()
    else
        zoomOut()
    end
    cb({ ok = true, zoom = camZoom })
end)

RegisterNUICallback('preview3d_view', function(data, cb)
    if not previewActive then cb({ ok = false }) return end
    local viewName = data.view or 'full'
    setView(viewName)
    cb({ ok = true, view = currentView })
end)

RegisterNUICallback('preview3d_autoRotate', function(data, cb)
    autoRotate = not autoRotate
    cb({ ok = true, autoRotate = autoRotate })
end)

RegisterNUICallback('preview3d_reset', function(_, cb)
    resetCamera()
    cb({ ok = true })
end)

-- ═══════════════════════════════════════════════════════════════
-- STUDIO OPEN/CLOSE HOOKS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:client:openStudio3D', function()
    createPreviewCamera()
end)

RegisterNetEvent('realrpg_clothingstudio:client:closeStudio3D', function()
    destroyPreviewCamera()
end)

-- ═══════════════════════════════════════════════════════════════
-- MAIN THREAD: Auto-rotation + controls
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        if previewActive then
            Wait(0)

            -- Auto-rotation
            if autoRotate then
                camRotation = camRotation + 0.25
                if camRotation >= 360 then camRotation = camRotation - 360 end
                updateCameraPosition()
            end

            -- Disable player movement while preview is active
            DisableControlAction(0, 1, true)   -- LookLeftRight
            DisableControlAction(0, 2, true)   -- LookUpDown
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 30, true)  -- MoveLeftRight
            DisableControlAction(0, 31, true)  -- MoveUpDown
            DisableControlAction(0, 36, true)  -- InputDuck
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Jump
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 37, true)  -- SelectWeapon
            DisableControlAction(0, 44, true)  -- Cover
        else
            Wait(500)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    destroyPreviewCamera()
end)
