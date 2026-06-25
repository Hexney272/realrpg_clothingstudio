--[[
    RealRPG Clothing Studio - DUI Lifecycle Manager
    
    Ez a modul kezeli a DUI (Direct URL Input) objektumokat:
    - Pool rendszer: limitált számú DUI instance újrahasznosítása
    - Lifecycle: create, update (SendDuiMessage), destroy
    - Prioritás: saját karakter > közeli játékosok > távoli játékosok
    
    FiveM DUI natívok:
    - CreateDui(url, width, height) -> duiObj
    - DestroyDui(duiObj)
    - GetDuiHandle(duiObj) -> string (txd handle a runtime texture-höz)
    - SendDuiMessage(duiObj, jsonString)
    - SetDuiUrl(duiObj, url)
    - IsDuiAvailable(duiObj) -> bool
]]

DUI = {}

-- Aktív DUI instance-ok: key = egyedi azonosító (pl. "player_123_tops")
-- value = { duiObj, handle, owner, slot, lastUpdate, priority, resolution }
DUI.Active = {}

-- Pool: szabad, újrahasznosítható DUI objektumok
DUI.Pool = {}

-- DUI render page URL (a resource saját web/dui_render.html-je)
DUI.RenderUrl = nil

-- Statisztika
DUI.Stats = {
    created = 0,
    destroyed = 0,
    reused = 0,
    updates = 0
}

-- ═══════════════════════════════════════════════════════════════
-- INICIALIZÁLÁS
-- ═══════════════════════════════════════════════════════════════

--- DUI rendszer inicializálása
function DUI.Init()
    -- A resource NUI page URL-je: nui://resourceName/web/dui_render.html
    local resourceName = GetCurrentResourceName()
    DUI.RenderUrl = ('nui://%s/web/dui_render.html'):format(resourceName)

    if Config.Debug then
        print(('[^3RealRPG DUI^0] Initialized. Render URL: %s'):format(DUI.RenderUrl))
        print(('[^3RealRPG DUI^0] Pool limit: %d, Max active: %d'):format(
            Config.DUI.poolSize, Config.DUI.maxActive
        ))
    end
end

-- ═══════════════════════════════════════════════════════════════
-- POOL MANAGEMENT
-- ═══════════════════════════════════════════════════════════════

--- Új DUI objektum létrehozása vagy pool-ból kiemelése
---@param resolution number Textúra felbontás (pl. 1024)
---@return table|nil duiData { duiObj, handle, resolution }
function DUI.Acquire(resolution)
    resolution = resolution or 1024

    -- Először próbáljunk a pool-ból venni (azonos resolution)
    for i, pooled in ipairs(DUI.Pool) do
        if pooled.resolution == resolution then
            table.remove(DUI.Pool, i)
            DUI.Stats.reused = DUI.Stats.reused + 1
            if Config.Debug then
                print(('[^3RealRPG DUI^0] Reused from pool (res: %d). Pool size: %d'):format(resolution, #DUI.Pool))
            end
            return pooled
        end
    end

    -- Ellenőrizzük a limitet
    local activeCount = 0
    for _ in pairs(DUI.Active) do activeCount = activeCount + 1 end
    
    if activeCount + #DUI.Pool >= Config.DUI.maxActive then
        -- Limit elérve - próbáljunk felszabadítani alacsony prioritásút
        local freed = DUI.EvictLowestPriority()
        if not freed then
            if Config.Debug then
                print('[^1RealRPG DUI^0] Max active limit reached, cannot acquire new DUI.')
            end
            return nil
        end
    end

    -- Új DUI létrehozása
    local duiObj = CreateDui(DUI.RenderUrl, resolution, resolution)
    if not duiObj then
        print('[^1RealRPG DUI^0] ERROR: CreateDui failed!')
        return nil
    end

    -- Várjunk amíg elérhető lesz a handle
    local handle = nil
    local attempts = 0
    while not handle or handle == '' do
        Wait(0)
        handle = GetDuiHandle(duiObj)
        attempts = attempts + 1
        if attempts > 100 then
            print('[^1RealRPG DUI^0] ERROR: GetDuiHandle timeout!')
            DestroyDui(duiObj)
            return nil
        end
    end

    DUI.Stats.created = DUI.Stats.created + 1
    if Config.Debug then
        print(('[^3RealRPG DUI^0] Created new DUI (res: %d). Handle: %s'):format(resolution, handle))
    end

    return {
        duiObj = duiObj,
        handle = handle,
        resolution = resolution
    }
end

--- DUI objektum visszaadása a pool-ba (nem töröljük, hanem újrahasznosítjuk)
---@param key string Az aktív DUI azonosítója
function DUI.Release(key)
    local entry = DUI.Active[key]
    if not entry then return end

    -- Töröljük a canvas tartalmát
    DUI.SendMessage(entry.duiObj, { action = 'clear' })

    -- Pool-ba tesszük ha van hely
    if #DUI.Pool < Config.DUI.poolSize then
        DUI.Pool[#DUI.Pool + 1] = {
            duiObj = entry.duiObj,
            handle = entry.handle,
            resolution = entry.resolution
        }
    else
        -- Pool tele - megsemmisítjük
        DestroyDui(entry.duiObj)
        DUI.Stats.destroyed = DUI.Stats.destroyed + 1
    end

    DUI.Active[key] = nil

    if Config.Debug then
        print(('[^3RealRPG DUI^0] Released: %s. Pool: %d'):format(key, #DUI.Pool))
    end
end

--- Legalacsonyabb prioritású aktív DUI felszabadítása
---@return boolean success
function DUI.EvictLowestPriority()
    local lowestKey = nil
    local lowestPriority = math.huge

    for key, entry in pairs(DUI.Active) do
        if entry.priority < lowestPriority then
            lowestPriority = entry.priority
            lowestKey = key
        end
    end

    if lowestKey then
        DUI.Release(lowestKey)
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- AKTÍV DUI KEZELÉS
-- ═══════════════════════════════════════════════════════════════

--- DUI regisztrálása egy játékos + slot kombóhoz
---@param key string Egyedi azonosító (pl. "ped_123_tops")
---@param garmentSlot table Garments.Slots entry
---@param priority number Magasabb = fontosabb (saját ped = 100, közeli = 50, távoli = 10)
---@return table|nil entry A teljes aktív entry { duiObj, handle, ... }
function DUI.Register(key, garmentSlot, priority)
    -- Ha már létezik, visszaadjuk
    if DUI.Active[key] then
        DUI.Active[key].priority = math.max(DUI.Active[key].priority, priority)
        return DUI.Active[key]
    end

    local resolution = garmentSlot.resolution or 1024
    local acquired = DUI.Acquire(resolution)
    if not acquired then return nil end

    local entry = {
        duiObj = acquired.duiObj,
        handle = acquired.handle,
        resolution = resolution,
        key = key,
        slot = garmentSlot,
        priority = priority,
        lastUpdate = GetGameTimer(),
        designData = nil
    }

    DUI.Active[key] = entry
    return entry
end

--- DUI tartalom frissítése (design renderelés küldése)
---@param key string
---@param designData table { layers, preview, background, ... }
function DUI.Update(key, designData)
    local entry = DUI.Active[key]
    if not entry then return false end

    entry.lastUpdate = GetGameTimer()
    entry.designData = designData

    -- Ha van kész preview kép (base64), azt használjuk - gyorsabb
    if designData.preview and designData.preview ~= '' then
        DUI.SendMessage(entry.duiObj, {
            action = 'renderImage',
            resolution = entry.resolution,
            src = designData.preview
        })
    elseif designData.layers then
        -- Layer-alapú renderelés
        DUI.SendMessage(entry.duiObj, {
            action = 'render',
            resolution = entry.resolution,
            layers = designData.layers,
            background = designData.background or '#ffffff'
        })
    end

    DUI.Stats.updates = DUI.Stats.updates + 1
    return true
end

--- Egyszerű preview kép küldése egy DUI-nak
---@param key string
---@param imageBase64 string
function DUI.UpdateImage(key, imageBase64)
    local entry = DUI.Active[key]
    if not entry then return false end

    entry.lastUpdate = GetGameTimer()
    DUI.SendMessage(entry.duiObj, {
        action = 'renderImage',
        resolution = entry.resolution,
        src = imageBase64
    })

    DUI.Stats.updates = DUI.Stats.updates + 1
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════════════════════════════

--- JSON üzenet küldése egy DUI objektumnak
---@param duiObj any
---@param data table
function DUI.SendMessage(duiObj, data)
    if not duiObj then return end
    SendDuiMessage(duiObj, json.encode(data))
end

--- DUI handle lekérése key alapján (runtime texture-höz kell)
---@param key string
---@return string|nil
function DUI.GetHandle(key)
    local entry = DUI.Active[key]
    return entry and entry.handle or nil
end

--- Aktív DUI entry lekérése
---@param key string
---@return table|nil
function DUI.GetEntry(key)
    return DUI.Active[key]
end

--- Ellenőrzi hogy egy key-hez van-e aktív DUI
---@param key string
---@return boolean
function DUI.IsActive(key)
    return DUI.Active[key] ~= nil
end

--- Key generálása serverId + category alapján
---@param serverId number
---@param category string
---@return string
function DUI.MakeKey(serverId, category)
    return ('ped_%d_%s'):format(serverId, category)
end

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP / LIFECYCLE
-- ═══════════════════════════════════════════════════════════════

--- Összes DUI felszabadítása (resource stop / disconnect)
function DUI.DestroyAll()
    for key, entry in pairs(DUI.Active) do
        if entry.duiObj then
            DestroyDui(entry.duiObj)
            DUI.Stats.destroyed = DUI.Stats.destroyed + 1
        end
    end
    DUI.Active = {}

    for _, pooled in ipairs(DUI.Pool) do
        if pooled.duiObj then
            DestroyDui(pooled.duiObj)
            DUI.Stats.destroyed = DUI.Stats.destroyed + 1
        end
    end
    DUI.Pool = {}

    if Config.Debug then
        print('[^3RealRPG DUI^0] All DUIs destroyed.')
    end
end

--- Távoli játékosok DUI-jainak tisztítása (ha eltávolodtak)
---@param myCoords vector3
---@param maxDistance number
function DUI.CleanupDistant(myCoords, maxDistance)
    local myServerId = GetPlayerServerId(PlayerId())

    for key, entry in pairs(DUI.Active) do
        -- Saját ped-et soha nem töröljük
        if entry.priority >= 100 then goto continue end

        -- Ellenőrizzük az owner távolságát
        -- A key formátum: "ped_SERVERID_CATEGORY"
        local serverId = tonumber(key:match('ped_(%d+)_'))
        if serverId and serverId ~= myServerId then
            local targetPed = GetPlayerPed(GetPlayerFromServerId(serverId))
            if targetPed and targetPed ~= 0 then
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(myCoords - targetCoords)
                if dist > maxDistance then
                    DUI.Release(key)
                end
            else
                -- Játékos nincs a közelben / nem látható
                DUI.Release(key)
            end
        end

        ::continue::
    end
end

--- Periodikus pool karbantartás (túl régi idle DUI-k törlése)
function DUI.MaintainPool()
    -- Ha a pool nagyobb mint a fele a limitnek, töröljünk párat
    local targetSize = math.floor(Config.DUI.poolSize * 0.5)
    while #DUI.Pool > targetSize do
        local entry = table.remove(DUI.Pool)
        if entry and entry.duiObj then
            DestroyDui(entry.duiObj)
            DUI.Stats.destroyed = DUI.Stats.destroyed + 1
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- DEBUG
-- ═══════════════════════════════════════════════════════════════

function DUI.GetStats()
    local activeCount = 0
    for _ in pairs(DUI.Active) do activeCount = activeCount + 1 end
    return {
        active = activeCount,
        pooled = #DUI.Pool,
        created = DUI.Stats.created,
        destroyed = DUI.Stats.destroyed,
        reused = DUI.Stats.reused,
        updates = DUI.Stats.updates
    }
end

-- ═══════════════════════════════════════════════════════════════
-- THREADS
-- ═══════════════════════════════════════════════════════════════

-- Inicializálás
CreateThread(function()
    Wait(500)
    DUI.Init()
end)

-- Periodikus cleanup (távoli játékosok + pool maintenance)
CreateThread(function()
    while true do
        Wait(Config.DUI.cleanupInterval or 10000)

        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            DUI.CleanupDistant(coords, Config.DUI.renderDistance or 50.0)
        end

        DUI.MaintainPool()
    end
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DUI.DestroyAll()
    end
end)
