--[[
    RealRPG Clothing Studio - 3D Preview Camera System
    
    A stúdió megnyitásakor létrehoz egy kamerát a player ped-re,
    amely a NUI mögött látszik (transparent background).
    Így a ped-en lévő ruha (a stream mappából streamelt YDD) 
    valódi 3D-ben jelenik meg élő preview-ként.
    
    Funkciók:
    - Kamera pozícionálás a ped-re
    - Forgatás (bal/jobb nyilakkal vagy NUI gombokkal)
    - Zoom in/out
    - Különböző nézetek (full body, felső test, alsó test, láb)
]]

local previewCam = nil
local previewActive = false
local camRotation = 0.0     -- Y tengely forgás (körbe)
local camZoom = 1.0         -- 1.0 = alaphelyzet
local camHeight = 0.0       -- Vertikális offset (nézet típus alapján)
local camDistance = 1.6     -- Kamera távolság
local camFov = 35.0         -- Field of View (szűk = kevésbé torzít)

-- Nézet presetjei
local VIEW_PRESETS = {
    full     = { height = 0.0,   distance = 1.8, fov = 35.0 },
    upper    = { height = 0.25,  distance = 1.0, fov = 30.0 },
    lower    = { height = -0.35, distance = 1.2, fov = 30.0 },
    feet     = { height = -0.7,  distance = 0.8, fov = 28.0 },
    head     = { height = 0.55,  distance = 0.7, fov = 28.0 },
}

local currentView = 'full'
local smoothRotationTarget = 0.0
local autoRotate = false

-- ═══════════════════════════════════════════════════════════════
-- CAMERA CREATION / DESTRUCTION
-- ═══════════════════════════════════════════════════════════════

local function createPreviewCamera()
    if previewCam then return end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(previewCam, camFov)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 500, true, false)

    -- Ped-et állítsuk meg, ne mozogjon
    FreezeEntityPosition(ped, true)
    TaskStandStill(ped, -1)

    -- Irányítsuk a ped-et a kamerával szembe
    SetEntityHeading(ped, GetEntityHeading(ped))

    previewActive = true
    updateCameraPosition()
end

local function destroyPreviewCamera()
    if not previewCam then return end

    RenderScriptCams(false, true, 500, true, false)
    DestroyCam(previewCam, false)
    previewCam = nil
    previewActive = false

    -- Ped feloldása
    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasks(PlayerPedId())
end

-- ═══════════════════════════════════════════════════════════════
-- CAMERA POSITIONING
-- ═══════════════════════════════════════════════════════════════

function updateCameraPosition()
    if not previewCam or not previewActive then return end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local pedHeading = GetEntityHeading(ped)

    -- Kamera pozíció kiszámítása (kör mentén a ped körül)
    local angleRad = math.rad(camRotation + pedHeading)
    local dist = camDistance * camZoom

    local camX = pedCoords.x + (math.sin(angleRad) * dist)
    local camY = pedCoords.y + (math.cos(angleRad) * dist)
    local camZ = pedCoords.z + camHeight

    SetCamCoord(previewCam, camX, camY, camZ)

    -- Kamera irány: a ped felé néz (a megfelelő magassággal)
    local lookAtZ = pedCoords.z + camHeight
    PointCamAtCoord(previewCam, pedCoords.x, pedCoords.y, lookAtZ)

    SetCamFov(previewCam, camFov)
end

-- ═══════════════════════════════════════════════════════════════
-- VIEW SWITCHING
-- ═══════════════════════════════════════════════════════════════

local function setView(viewName)
    local preset = VIEW_PRESETS[viewName]
    if not preset then return end

    currentView = viewName
    camHeight = preset.height
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
    camZoom = math.max(0.4, camZoom - 0.15)
    updateCameraPosition()
end

local function zoomOut()
    camZoom = math.min(2.5, camZoom + 0.15)
    updateCameraPosition()
end

local function resetCamera()
    camRotation = 0.0
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

-- Hook into the existing studio open/close events
AddEventHandler('realrpg_clothingstudio:client:openStudio', function()
    -- Kis késleltetés, hogy a NUI felépüljön
    CreateThread(function()
        Wait(300)
        createPreviewCamera()
    end)
end)

-- ═══════════════════════════════════════════════════════════════
-- MAIN THREAD: Auto-rotation + smooth camera + controls
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        if previewActive then
            Wait(0)

            -- Auto-rotation
            if autoRotate then
                camRotation = camRotation + 0.3
                if camRotation >= 360 then camRotation = camRotation - 360 end
                updateCameraPosition()
            end

            -- Keyboard controls (ha a NUI nincs fókuszban)
            -- LEFT ARROW
            if IsControlPressed(0, 174) then
                rotateLeft(1.5)
            end
            -- RIGHT ARROW
            if IsControlPressed(0, 175) then
                rotateRight(1.5)
            end
            -- SCROLL UP (zoom in)
            if IsDisabledControlPressed(0, 241) then
                zoomIn()
            end
            -- SCROLL DOWN (zoom out)
            if IsDisabledControlPressed(0, 242) then
                zoomOut()
            end

            -- Disable player movement while preview is active
            DisableControlAction(0, 30, true)  -- MoveLeftRight
            DisableControlAction(0, 31, true)  -- MoveUpDown
            DisableControlAction(0, 36, true)  -- InputDuck
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Jump
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 37, true)  -- SelectWeapon
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
