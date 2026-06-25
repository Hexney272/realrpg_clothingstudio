--[[
    RealRPG Clothing Studio - Runtime Texture Replace
    
    Ez a modul felelős a GTA V runtime texture csere logikájáért:
    - A streamelt blank garment .ytd textúráját lecseréli a DUI handle-re
    - Kezeli a texture dictionary betöltést/felszabadítást
    - Összeköti a DUI manager-t a ped component rendszerrel
    
    FiveM Runtime Texture natívok:
    - CreateRuntimeTxd(txdName) -> runtimeTxd handle
    - CreateRuntimeTextureFromDuiHandle(runtimeTxd, txnName, duiHandle) -> runtimeTex
    - AddReplaceTexture(origTxd, origTxn, runtimeTxd, runtimeTxn)
    - RemoveReplaceTexture(origTxd, origTxn)
    
    GTA Ped Component natívok:
    - SetPedComponentVariation(ped, componentId, drawableId, textureId, paletteId)
    - GetPedDrawableVariation(ped, componentId) -> int
    - GetPedTextureVariation(ped, componentId) -> int
]]

RTex = {}

-- Aktív runtime texture replacementek: key = DUI key (pl. "ped_123_tops")
-- value = { runtimeTxd, runtimeTxdName, origTxd, origTxn, applied, garmentSlot }
RTex.Active = {}

-- Runtime TXD counter (egyedi nevek generálásához)
RTex._txdCounter = 0

-- ═══════════════════════════════════════════════════════════════
-- CORE: TEXTURE REPLACE
-- ═══════════════════════════════════════════════════════════════

--- Runtime texture replace alkalmazása egy blank garment-re DUI handle-lel
---@param key string DUI key (pl. "ped_123_tops")
---@param garmentSlot table Garments.Slots entry (txd, txn, component, drawable, texture)
---@param duiHandle string A DUI GetDuiHandle() eredménye
---@return boolean success
function RTex.Apply(key, garmentSlot, duiHandle)
    if not key or not garmentSlot or not duiHandle or duiHandle == '' then
        if Config.Debug then
            print('[^1RealRPG RTex^0] Apply failed: missing params')
        end
        return false
    end

    -- Ha már van aktív replace ezen a key-en, először töröljük
    if RTex.Active[key] then
        RTex.Remove(key)
    end

    -- Egyedi runtime TXD név generálása
    RTex._txdCounter = RTex._txdCounter + 1
    local runtimeTxdName = ('rr_rt_%s_%d'):format(key:gsub('[^%w]', ''), RTex._txdCounter)

    -- Runtime TXD létrehozása
    local runtimeTxd = CreateRuntimeTxd(runtimeTxdName)
    if not runtimeTxd then
        print(('[^1RealRPG RTex^0] ERROR: CreateRuntimeTxd failed for %s'):format(runtimeTxdName))
        return false
    end

    -- Runtime texture létrehozása a DUI handle-ből
    local runtimeTxn = garmentSlot.txn .. '_rt'
    local runtimeTex = CreateRuntimeTextureFromDuiHandle(runtimeTxd, runtimeTxn, duiHandle)
    if not runtimeTex then
        print(('[^1RealRPG RTex^0] ERROR: CreateRuntimeTextureFromDuiHandle failed for %s'):format(key))
        return false
    end

    -- Eredeti textúra lecserélése a runtime textúrára
    AddReplaceTexture(garmentSlot.txd, garmentSlot.txn, runtimeTxdName, runtimeTxn)

    -- Tracking
    RTex.Active[key] = {
        runtimeTxd = runtimeTxd,
        runtimeTxdName = runtimeTxdName,
        runtimeTxn = runtimeTxn,
        origTxd = garmentSlot.txd,
        origTxn = garmentSlot.txn,
        garmentSlot = garmentSlot,
        applied = true,
        appliedAt = GetGameTimer()
    }

    if Config.Debug then
        print(('[^3RealRPG RTex^0] Applied texture replace: %s -> %s/%s'):format(
            key, garmentSlot.txd, garmentSlot.txn
        ))
    end

    return true
end

--- Runtime texture replace eltávolítása
---@param key string
function RTex.Remove(key)
    local entry = RTex.Active[key]
    if not entry then return end

    -- Replace eltávolítása
    if entry.applied then
        RemoveReplaceTexture(entry.origTxd, entry.origTxn)
    end

    RTex.Active[key] = nil

    if Config.Debug then
        print(('[^3RealRPG RTex^0] Removed texture replace: %s'):format(key))
    end
end

-- ═══════════════════════════════════════════════════════════════
-- PED COMPONENT MANAGEMENT
-- ═══════════════════════════════════════════════════════════════

--- Blank garment ráadása egy ped-re (component variation beállítás)
---@param ped number Entity handle
---@param garmentSlot table Garments.Slots entry
function RTex.ApplyGarmentToPed(ped, garmentSlot)
    if not ped or ped == 0 or not garmentSlot then return end

    SetPedComponentVariation(
        ped,
        garmentSlot.component,
        garmentSlot.drawable,
        garmentSlot.texture or 0,
        2 -- palette
    )

    if Config.Debug then
        print(('[^3RealRPG RTex^0] Set ped component: comp=%d draw=%d tex=%d'):format(
            garmentSlot.component, garmentSlot.drawable, garmentSlot.texture or 0
        ))
    end
end

--- Teljes flow: garment ráadás + DUI texture replace
--- Ez a fő entry point amit a wearables.lua hív
---@param ped number Entity handle
---@param key string DUI key
---@param garmentSlot table Garments.Slots entry
---@param designData table { preview, layers, ... }
---@param priority number DUI priority
---@return boolean success
function RTex.ApplyDesignToPed(ped, key, garmentSlot, designData, priority)
    if not ped or ped == 0 then return false end
    if not garmentSlot then return false end
    if not designData then return false end

    -- 1. Blank garment ráadása a ped-re
    RTex.ApplyGarmentToPed(ped, garmentSlot)

    -- 2. DUI regisztrálás/szerzés
    local duiEntry = DUI.Register(key, garmentSlot, priority or 50)
    if not duiEntry then
        if Config.Debug then
            print(('[^1RealRPG RTex^0] Failed to acquire DUI for: %s'):format(key))
        end
        return false
    end

    -- 3. Design renderelés küldése a DUI-nak
    DUI.Update(key, designData)

    -- 4. Kis várakozás hogy a DUI renderelődjön (első frame)
    -- A runtime texture replace-t egy frame késéssel alkalmazzuk
    CreateThread(function()
        Wait(Config.DUI.renderDelay or 200)

        -- Ellenőrizzük hogy még mindig aktív-e
        if not DUI.IsActive(key) then return end

        local handle = DUI.GetHandle(key)
        if not handle or handle == '' then return end

        -- 5. Runtime texture replace alkalmazása
        local success = RTex.Apply(key, garmentSlot, handle)
        if success then
            -- 6. Ped component újra beállítása hogy a textúra frissüljön
            -- (Néha szükséges a GTA-ban hogy a replace érvényesüljön)
            Wait(50)
            RTex.ApplyGarmentToPed(ped, garmentSlot)
        end
    end)

    return true
end

--- Design eltávolítása egy ped-ről (visszaállítás)
---@param key string DUI key
---@param ped number|nil Ped handle (ha meg akarjuk változtatni a component-et is)
---@param originalDrawable number|nil Visszaállítás erre a drawable-re
---@param originalTexture number|nil Visszaállítás erre a texture-re
function RTex.RemoveDesignFromPed(key, ped, originalDrawable, originalTexture)
    local entry = RTex.Active[key]
    
    -- Texture replace eltávolítása
    RTex.Remove(key)
    
    -- DUI felszabadítása
    DUI.Release(key)

    -- Ped component visszaállítása (opcionális)
    if ped and ped ~= 0 and entry and entry.garmentSlot then
        if originalDrawable then
            SetPedComponentVariation(
                ped,
                entry.garmentSlot.component,
                originalDrawable,
                originalTexture or 0,
                2
            )
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- BATCH OPERATIONS
-- ═══════════════════════════════════════════════════════════════

--- Összes aktív texture replace frissítése (pl. ha a ped model változott)
---@param ped number Entity handle  
---@param serverId number
function RTex.RefreshAllForPed(ped, serverId)
    for key, entry in pairs(RTex.Active) do
        if key:find(('ped_%d_'):format(serverId)) then
            -- Garment újra ráadása
            RTex.ApplyGarmentToPed(ped, entry.garmentSlot)
            -- Re-apply texture replace
            local handle = DUI.GetHandle(key)
            if handle and handle ~= '' then
                -- Remove és újra apply
                RemoveReplaceTexture(entry.origTxd, entry.origTxn)
                Wait(0)
                AddReplaceTexture(entry.origTxd, entry.origTxn, entry.runtimeTxdName, entry.runtimeTxn)
            end
        end
    end
end

--- Összes texture replace eltávolítása egy játékosról
---@param serverId number
function RTex.RemoveAllForPlayer(serverId)
    local pattern = ('ped_%d_'):format(serverId)
    local toRemove = {}

    for key in pairs(RTex.Active) do
        if key:find(pattern) then
            toRemove[#toRemove + 1] = key
        end
    end

    for _, key in ipairs(toRemove) do
        RTex.Remove(key)
        DUI.Release(key)
    end

    if Config.Debug and #toRemove > 0 then
        print(('[^3RealRPG RTex^0] Removed %d textures for player %d'):format(#toRemove, serverId))
    end
end

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP
-- ═══════════════════════════════════════════════════════════════

--- Összes runtime texture eltávolítása
function RTex.DestroyAll()
    for key in pairs(RTex.Active) do
        RTex.Remove(key)
    end
    RTex.Active = {}

    if Config.Debug then
        print('[^3RealRPG RTex^0] All runtime textures destroyed.')
    end
end

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RTex.DestroyAll()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- GARMENT SLOT RESOLUTION HELPER
-- ═══════════════════════════════════════════════════════════════

--- Megfelelő garment slot keresése metadata alapján
--- A metadata-ban tárolt garmentId vagy gender+category alapján
---@param metadata table { garmentId, gender, category, ... }
---@return table|nil garmentSlot
function RTex.ResolveGarmentSlot(metadata)
    if not metadata then return nil end

    -- Direkt garment ID alapján
    if metadata.garmentId then
        return Garments.GetById(metadata.garmentId)
    end

    -- Gender + category alapján (első elérhető slot)
    if metadata.gender and metadata.category then
        local slots = Garments.GetByGenderCategory(metadata.gender, metadata.category)
        if slots and #slots > 0 then
            return slots[1]
        end
    end

    return nil
end
