--[[
    RealRPG Clothing Studio - Live Preview
    
    A studio editorban real-time mutatja a designt egy dedikált mannequin ped-en:
    1. Sablon kiválasztás → mannequin ped-re felkerül a blank garment (.ydd)
    2. Canvas frissítés → DUI runtime texture real-time cseréli a garment textúráját
    3. Kamera → a mannequin köré forgatható kamera (csak a ruhát látod)
    4. Studio bezárás → mannequin és kamera törlése
    
    A mannequin egy mp_m_freemode_01 ped ami a játékos mögött van elrejtve,
    láthatatlan a többi játékos számára (networked = false).
]]

local previewActive = false
local mannequinPed = nil
local previewDui = nil
local previewDuiHandle = nil
local previewRuntimeTxd = nil
local previewCam = nil
local previewCamAngle = 0.0
local previewCamZoom = 1.2
local previewCurrentSlot = nil
local previewCurrentTemplate = nil

-- ═══════════════════════════════════════════════════════════════
-- MANNEQUIN PED
-- ═══════════════════════════════════════════════════════════════

local function createMannequin()
    if mannequinPed and DoesEntityExist(mannequinPed) then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)

    -- Mannequin pozíció: a játékos előtt 2 méterrel (a kamera fogja mutatni)
    local rad = math.rad(playerHeading)
    local spawnX = playerCoords.x - math.sin(rad) * 2.0
    local spawnY = playerCoords.y - math.cos(rad) * 2.0
    local spawnZ = playerCoords.z - 1.0 -- Kicsit a föld alá hogy ne üsse magát

    -- Freemode male model betöltése
    local model = GetHashKey('mp_m_freemode_01')
    RequestModel(model)
    local timeout = 50
    while not HasModelLoaded(model) and timeout > 0 do
        Wait(100)
        timeout = timeout - 1
    end
    if not HasModelLoaded(model) then
        print('[^1RealRPG Preview^0] Mannequin model betöltés sikertelen!')
        return
    end

    -- Ped létrehozása (NEM networked - csak lokálisan létezik)
    mannequinPed = CreatePed(5, model, spawnX, spawnY, spawnZ, playerHeading + 180.0, false, false)
    SetModelAsNoLongerNeeded(model)

    -- Mannequin beállítások
    FreezeEntityPosition(mannequinPed, true)
    SetEntityInvincible(mannequinPed, true)
    SetBlockingOfNonTemporaryEvents(mannequinPed, true)
    SetPedCanRagdoll(mannequinPed, false)
    SetEntityAlpha(mannequinPed, 255, false)

    -- Állítsd alapértelmezett megjelenésre (nincs haj, nincs extra ruha)
    SetPedDefaultComponentVariation(mannequinPed)
    -- Töröljünk minden nem szükséges component-et (csak a felső marad)
    -- Component 0 = fej, 3 = karok, 4 = lábak, 6 = cipő, 8 = alsó felső
    SetPedComponentVariation(mannequinPed, 0, 0, 0, 2) -- Fej (alap)
    SetPedComponentVariation(mannequinPed, 3, 0, 0, 2) -- Karok (alap)
    SetPedComponentVariation(mannequinPed, 4, 0, 0, 2) -- Nadrág (alap)
    SetPedComponentVariation(mannequinPed, 6, 0, 0, 2) -- Cipő (alap)
    SetPedComponentVariation(mannequinPed, 8, -1, 0, 2) -- Alsó felső (nincs)

    if Config.Debug then
        print(('[^2RealRPG Preview^0] Mannequin ped létrehozva: %d'):format(mannequinPed))
    end
end

local function destroyMannequin()
    if mannequinPed and DoesEntityExist(mannequinPed) then
        DeleteEntity(mannequinPed)
    end
    mannequinPed = nil
end

-- ═══════════════════════════════════════════════════════════════
-- KAMERA (mannequin köré forgatható)
-- ═══════════════════════════════════════════════════════════════

local function createPreviewCam()
    if previewCam then return end
    if not mannequinPed or not DoesEntityExist(mannequinPed) then return end

    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCamPosition()
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 500, true, false)
end

local function destroyPreviewCam()
    if not previewCam then return end
    RenderScriptCams(false, true, 500, true, false)
    DestroyCam(previewCam, false)
    previewCam = nil
end

function updateCamPosition()
    if not previewCam then return end
    if not mannequinPed or not DoesEntityExist(mannequinPed) then return end

    local pedCoords = GetEntityCoords(mannequinPed)

    -- Kamera a mannequin körül forog
    local rad = math.rad(previewCamAngle)
    local camX = pedCoords.x + math.sin(rad) * previewCamZoom
    local camY = pedCoords.y + math.cos(rad) * previewCamZoom
    local camZ = pedCoords.z + 0.5 -- A felső testre fókuszálunk

    SetCamCoord(previewCam, camX, camY, camZ)
    PointCamAtCoord(previewCam, pedCoords.x, pedCoords.y, pedCoords.z + 0.3)
end

-- ═══════════════════════════════════════════════════════════════
-- DUI RUNTIME TEXTURE
-- ═══════════════════════════════════════════════════════════════

local function cleanupDui()
    if previewCurrentSlot and previewCurrentSlot.txd and previewCurrentSlot.txn then
        RemoveReplaceTexture(previewCurrentSlot.txd, previewCurrentSlot.txn)
    end
    if previewDui then
        DestroyDui(previewDui)
        previewDui = nil
        previewDuiHandle = nil
    end
    previewRuntimeTxd = nil
    previewCurrentSlot = nil
end

local function setupDui()
    if previewDui then return end

    local width = (Config.RuntimeTextures and Config.RuntimeTextures.width) or 1024
    local height = (Config.RuntimeTextures and Config.RuntimeTextures.height) or 1024

    local url = ('nui://%s/web/dui_texture.html'):format(GetCurrentResourceName())
    previewDui = CreateDui(url, width, height)
    if not previewDui then
        print('[^1RealRPG Preview^0] DUI létrehozás sikertelen!')
        return
    end

    previewDuiHandle = GetDuiHandle(previewDui)
    previewRuntimeTxd = CreateRuntimeTxd('rrcs_preview_rt')
    CreateRuntimeTextureFromDuiHandle(previewRuntimeTxd, 'design', previewDuiHandle)

    if Config.Debug then
        print('[^2RealRPG Preview^0] DUI + Runtime TXD létrehozva.')
    end
end

local function applyRuntimeToSlot(slot)
    if not slot or not previewRuntimeTxd then return end

    -- Előző eltávolítása
    if previewCurrentSlot and previewCurrentSlot.txd then
        RemoveReplaceTexture(previewCurrentSlot.txd, previewCurrentSlot.txn)
    end

    -- Új replace
    AddReplaceTexture(slot.txd, slot.txn, 'rrcs_preview_rt', 'design')
    previewCurrentSlot = slot

    if Config.Debug then
        print(('[^2RealRPG Preview^0] Texture replace: %s/%s'):format(slot.txd, slot.txn))
    end
end

local function sendImageToDui(imageBase64)
    if not previewDui then return end
    SendDuiMessage(previewDui, json.encode({
        action = 'setImage',
        image = imageBase64,
        width = (Config.RuntimeTextures and Config.RuntimeTextures.width) or 1024,
        height = (Config.RuntimeTextures and Config.RuntimeTextures.height) or 1024
    }))
end

-- ═══════════════════════════════════════════════════════════════
-- PREVIEW LIFECYCLE
-- ═══════════════════════════════════════════════════════════════

local function startPreview()
    if previewActive then return end
    previewActive = true
    previewCamAngle = 0.0
    previewCamZoom = 1.2

    -- Mannequin létrehozása
    createMannequin()
    Wait(200)

    -- Kamera ráállítása
    createPreviewCam()

    -- Játékos mozgásának tiltása (de ne fagyasszuk be teljesen)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
end

local function stopPreview()
    if not previewActive then return end
    previewActive = false

    -- Kamera törlése
    destroyPreviewCam()

    -- DUI cleanup
    cleanupDui()

    -- Mannequin törlése
    destroyMannequin()

    -- Játékos felszabadítása
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)

    previewCurrentTemplate = nil
end

-- ═══════════════════════════════════════════════════════════════
-- EVENTS & NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════

--- Studio megnyitás → preview indítás
RegisterNetEvent('realrpg_clothingstudio:client:openStudio', function(data)
    startPreview()
end)

--- Sablon kiválasztás → mannequin-re felöltöztetés + DUI
RegisterNetEvent('realrpg_clothingstudio:client:previewClothing', function(data)
    if type(data) ~= 'table' then return end
    local template = data.template
    if type(template) ~= 'table' then return end
    if not mannequinPed or not DoesEntityExist(mannequinPed) then return end

    local component = tonumber(template.component)
    local drawable = tonumber(template.drawable)
    local texture = tonumber(template.texture or 0)
    if not component or drawable == nil then return end

    previewCurrentTemplate = template

    -- Blank garment ráadása a mannequin-re
    SetPedComponentVariation(mannequinPed, component, drawable, texture, 2)

    -- DUI setup
    setupDui()

    -- Runtime slot keresése
    local runtimeSlot = tonumber(template.runtimeSlot)
    if runtimeSlot and Config.RuntimeTextures and Config.RuntimeTextures.slots then
        local category = data.category or 'tops'
        local categorySlots = Config.RuntimeTextures.slots[category] or Config.RuntimeTextures.slots.tops or {}
        for _, slot in ipairs(categorySlots) do
            if tonumber(slot.slot) == runtimeSlot then
                CreateThread(function()
                    Wait(150)
                    applyRuntimeToSlot(slot)
                    Wait(50)
                    -- Garment újra ráadás hogy a replace érvényesüljön
                    if mannequinPed and DoesEntityExist(mannequinPed) then
                        SetPedComponentVariation(mannequinPed, component, drawable, texture, 2)
                    end
                end)
                break
            end
        end
    end

    if Config.Debug then
        print(('[^2RealRPG Preview^0] Mannequin template: comp=%d draw=%d'):format(component, drawable))
    end
end)

--- Canvas frissítés → DUI textúra frissítés (real-time)
RegisterNUICallback('updatePreviewTexture', function(data, cb)
    if type(data) == 'table' and data.image and previewActive then
        sendImageToDui(data.image)
    end
    cb({ ok = true })
end)

--- Kamera vezérlés NUI gombokkal
RegisterNUICallback('previewCam', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = true }) return end

    local action = data.action
    if action == 'rotateLeft' then
        previewCamAngle = previewCamAngle - 30
    elseif action == 'rotateRight' then
        previewCamAngle = previewCamAngle + 30
    elseif action == 'zoomIn' then
        previewCamZoom = math.max(0.6, previewCamZoom - 0.2)
    elseif action == 'zoomOut' then
        previewCamZoom = math.min(3.0, previewCamZoom + 0.2)
    elseif action == 'reset' then
        previewCamAngle = 0
        previewCamZoom = 1.2
    end

    updateCamPosition()
    cb({ ok = true })
end)

--- Studio bezárás → preview leállítás
RegisterNetEvent('realrpg_clothingstudio:client:previewRevert', function()
    stopPreview()
end)

-- ═══════════════════════════════════════════════════════════════
-- RESOURCE CLEANUP
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        stopPreview()
    end
end)
