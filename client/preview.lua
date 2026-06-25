--[[
    RealRPG Clothing Studio - Live Preview (DUI Runtime Texture Edition)
    
    Ez a modul kezeli a studio editorban történő élő előnézetet:
    - Amikor a játékos sablont választ, ráadja a blank garment-et
    - Amikor szerkeszti a designt, a DUI-n keresztül real-time frissíti a textúrát
    - Studio bezárásakor visszaállítja az eredeti ruhát
    
    Flow:
    1. Játékos megnyitja a studiót -> mentjük az aktuális ruha állapotot
    2. Sablon kiválasztás -> blank garment ráadás + DUI texture init
    3. Szerkesztés közben -> NUI küldi a canvas snapshot-ot -> DUI frissítés
    4. Studio bezárás -> visszaállítás VAGY mentés esetén megtartás
]]

local previewActive = false
local previewKey = 'preview_studio'
local previewGarmentSlot = nil
local previewOriginal = {}  -- component -> { drawable, texture }

-- ═══════════════════════════════════════════════════════════════
-- PREVIEW LIFECYCLE
-- ═══════════════════════════════════════════════════════════════

--- Preview indítása - mentjük az aktuális component state-et
local function startPreview()
    previewActive = true
    previewOriginal = {}

    local ped = PlayerPedId()
    -- Minden releváns component mentése
    for _, compId in ipairs({11, 8, 4, 6}) do
        previewOriginal[compId] = {
            drawable = GetPedDrawableVariation(ped, compId),
            texture = GetPedTextureVariation(ped, compId)
        }
    end

    if Config.Debug then
        print('[^3RealRPG Preview^0] Preview started, original components saved.')
    end
end

--- Preview leállítása - visszaállítás
local function stopPreview(keepCurrent)
    if not previewActive then return end
    previewActive = false

    -- DUI cleanup
    if DUI.IsActive(previewKey) then
        RTex.Remove(previewKey)
        DUI.Release(previewKey)
    end

    -- Visszaállítás ha nem tartjuk meg
    if not keepCurrent then
        local ped = PlayerPedId()
        for compId, data in pairs(previewOriginal) do
            SetPedComponentVariation(ped, compId, data.drawable, data.texture, 2)
        end

        if Config.Debug then
            print('[^3RealRPG Preview^0] Preview stopped, original components restored.')
        end
    else
        if Config.Debug then
            print('[^3RealRPG Preview^0] Preview stopped, keeping current state.')
        end
    end

    previewGarmentSlot = nil
    previewOriginal = {}
end

-- ═══════════════════════════════════════════════════════════════
-- SABLON KIVÁLASZTÁS (TEMPLATE SELECT)
-- ═══════════════════════════════════════════════════════════════

--- Sablon előnézet alkalmazása - blank garment + DUI init
---@param data table { template = { id, component, drawable, texture, ... }, garmentId? }
local function applyTemplatePreview(data)
    if type(data) ~= 'table' then return end
    local template = data.template
    if type(template) ~= 'table' then return end

    local ped = PlayerPedId()

    -- Garment slot keresése
    -- Először garmentId alapján, aztán template adatokból
    local garmentSlot = nil

    if data.garmentId then
        garmentSlot = Garments.GetById(data.garmentId)
    end

    if not garmentSlot and template.garmentId then
        garmentSlot = Garments.GetById(template.garmentId)
    end

    -- Ha nincs explicit garment, keresünk gender + category alapján
    if not garmentSlot then
        local gender = data.gender or 'male'
        local category = data.category or 'tops'
        local slots = Garments.GetByGenderCategory(gender, category)
        if slots and #slots > 0 then
            garmentSlot = slots[1]
        end
    end

    if garmentSlot and Config.DUI.enabled then
        -- ═══ DUI MÓD: Blank garment + üres textúra ═══
        previewGarmentSlot = garmentSlot

        -- Blank garment ráadása
        RTex.ApplyGarmentToPed(ped, garmentSlot)

        -- DUI regisztrálás preview-hoz (magas prioritás)
        local entry = DUI.Register(previewKey, garmentSlot, 200)
        if entry then
            -- Üres fehér textúrával indítunk - a szerkesztés majd frissíti
            DUI.SendMessage(entry.duiObj, {
                action = 'clear',
                resolution = garmentSlot.resolution or 1024,
                background = '#ffffff'
            })

            -- Runtime texture apply (kis delay-jel)
            CreateThread(function()
                Wait(Config.DUI.renderDelay or 200)
                if not previewActive then return end
                if not DUI.IsActive(previewKey) then return end

                local handle = DUI.GetHandle(previewKey)
                if handle and handle ~= '' then
                    RTex.Apply(previewKey, garmentSlot, handle)
                    Wait(50)
                    RTex.ApplyGarmentToPed(ped, garmentSlot)
                end
            end)
        end

        if Config.Debug then
            print(('[^3RealRPG Preview^0] DUI template preview: %s (garment: %s)'):format(template.id or '?', garmentSlot.id))
        end
    else
        -- ═══ FALLBACK: Component swap ═══
        local component = tonumber(template.component)
        local drawable = tonumber(template.drawable)
        local texture = tonumber(template.texture or 0)

        if component and drawable then
            SetPedComponentVariation(ped, component, drawable, texture, 2)
        end

        previewGarmentSlot = nil

        if Config.Debug then
            print(('[^3RealRPG Preview^0] Fallback preview: comp=%s draw=%s'):format(tostring(component), tostring(drawable)))
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- REAL-TIME DESIGN FRISSÍTÉS (CANVAS -> DUI)
-- ═══════════════════════════════════════════════════════════════

--- Canvas snapshot frissítése a DUI-n (NUI -> client callback -> DUI)
---@param imageBase64 string A canvas toDataURL() eredménye
local function updatePreviewTexture(imageBase64)
    if not previewActive then return end
    if not Config.DUI.enabled then return end
    if not DUI.IsActive(previewKey) then return end

    DUI.UpdateImage(previewKey, imageBase64)

    -- Ha még nincs runtime texture apply, csináljuk meg
    if not RTex.Active[previewKey] and previewGarmentSlot then
        local handle = DUI.GetHandle(previewKey)
        if handle and handle ~= '' then
            RTex.Apply(previewKey, previewGarmentSlot, handle)
            -- Garment újra ráadás
            local ped = PlayerPedId()
            RTex.ApplyGarmentToPed(ped, previewGarmentSlot)
        end
    end
end

--- Layer-alapú renderelés küldése (teljes design JSON)
---@param layers table Layer tömb a canvas editor-ból
local function updatePreviewLayers(layers)
    if not previewActive then return end
    if not Config.DUI.enabled then return end
    if not DUI.IsActive(previewKey) then return end

    DUI.Update(previewKey, {
        layers = layers,
        background = '#ffffff'
    })
end

-- ═══════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════

--- Studio megnyitásakor indítjuk a preview-t
RegisterNetEvent('realrpg_clothingstudio:client:openStudio', function(data)
    -- A studio.lua kezeli a NUI megnyitást, mi csak a preview-t indítjuk
    startPreview()
end)

--- Sablon kiválasztás a NUI-ból
RegisterNetEvent('realrpg_clothingstudio:client:previewClothing', function(data)
    if not previewActive then startPreview() end
    applyTemplatePreview(data)
end)

-- ═══════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════

--- NUI -> Client: Sablon kiválasztás
RegisterNUICallback('previewClothing', function(data, cb)
    if not previewActive then startPreview() end
    applyTemplatePreview(data)
    cb({ ok = true })
end)

--- NUI -> Client: Real-time canvas frissítés (base64 snapshot)
RegisterNUICallback('updatePreviewTexture', function(data, cb)
    if type(data) == 'table' and data.image then
        updatePreviewTexture(data.image)
    end
    cb({ ok = true })
end)

--- NUI -> Client: Layer-alapú frissítés
RegisterNUICallback('updatePreviewLayers', function(data, cb)
    if type(data) == 'table' and data.layers then
        updatePreviewLayers(data.layers)
    end
    cb({ ok = true })
end)

--- NUI -> Client: Studio bezárás
RegisterNUICallback('close', function(_, cb)
    stopPreview(false)
    -- Studio state reset (studio.lua figyeli)
    TriggerEvent('realrpg_clothingstudio:client:studioClose')
    cb({ ok = true })
end)

--- NUI -> Client: Design mentés után (megtartjuk az aktuális state-et)
RegisterNUICallback('previewKeep', function(_, cb)
    stopPreview(true)
    cb({ ok = true })
end)

-- ═══════════════════════════════════════════════════════════════
-- GARMENT SLOT INFO KÜLDÉSE A NUI-NAK
-- ═══════════════════════════════════════════════════════════════

--- NUI kéri az elérhető garment slotokat (template selector bővítés)
RegisterNUICallback('getGarmentSlots', function(data, cb)
    local gender = data and data.gender or 'male'
    local slots = Garments.GetAllForGender(gender)

    -- Csak a NUI-nak releváns mezőket küldjük
    local result = {}
    for _, slot in ipairs(slots) do
        result[#result + 1] = {
            id = slot.id,
            label = slot.label,
            gender = slot.gender,
            category = slot.category,
            component = slot.component,
            drawable = slot.drawable,
            resolution = slot.resolution,
            uvTemplate = slot.uvTemplate
        }
    end

    cb({ slots = result, duiEnabled = Config.DUI.enabled })
end)
