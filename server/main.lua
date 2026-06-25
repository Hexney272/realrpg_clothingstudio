--[[
    RealRPG Clothing Studio - Server Main (DUI Sync Edition)
    
    Server-side logika:
    - Studio megnyitás (jogosultság ellenőrzéssel)
    - Design mentés/betöltés
    - Nyomtatás (item létrehozás)
    - Equipped state kezelés + broadcast minden kliensnek (DUI szinkron)
    - Játékos design adatok kiszolgálása proximity request-re
]]

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════

local function notify(src, msg, typ)
    TriggerClientEvent('realrpg_clothingstudio:client:notify', src, msg, typ or 'info')
end

local function canUseStation(src, stationIndex)
    local station = Config.Stations[stationIndex]
    if not station then return false end
    if not station.job then return true end

    local job, grade = ServerFW.GetJob(src)
    return job == station.job and grade >= (station.grade or 0)
end

local function makeDesignId(src)
    return ('rr_%s_%s_%04d'):format(os.time(), src, math.random(1000, 9999))
end

-- Aktív játékosok equipped cache-je (gyors kiszolgáláshoz)
-- identifier -> { category -> metadata }
local equippedCache = {}
-- serverId -> identifier mapping
local playerIdentifiers = {}

-- ═══════════════════════════════════════════════════════════════
-- STUDIO MEGNYITÁS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:requestOpen', function(stationIndex)
    local src = source
    if not canUseStation(src, stationIndex) then
        notify(src, 'Nincs jogosultságod ehhez a designer station-höz.', 'error')
        return
    end

    local identifier = ServerFW.GetIdentifier(src)
    local designs = DB.GetMyDesigns(identifier)

    -- Garment slot infó küldése a kliensnek (DUI-hoz)
    local garmentSlots = {}
    for _, slot in ipairs(Garments.Slots) do
        garmentSlots[#garmentSlots + 1] = {
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

    TriggerClientEvent('realrpg_clothingstudio:client:openStudio', src, {
        title = Config.Studio.title,
        accent = Config.Studio.accent,
        templates = Templates.List,
        myDesigns = designs,
        aiEnabled = Config.AI.enabled,
        maxUploadMB = Config.Studio.maxUploadMB,
        garmentSlots = garmentSlots,
        duiEnabled = Config.DUI.enabled
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- DESIGN MENTÉS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:saveDesign', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end

    local identifier = ServerFW.GetIdentifier(src)
    local designId = makeDesignId(src)
    local label = tostring(payload.label or 'Untitled Design'):sub(1, 80)
    local gender = tostring(payload.gender or 'male')
    local category = tostring(payload.category or 'tops')
    local templateId = tostring(payload.templateId or '')
    local garmentId = tostring(payload.garmentId or '')
    local template = Templates.Get(gender, category, templateId)

    if not template then
        notify(src, 'Érvénytelen ruha sablon.', 'error')
        return
    end

    local designJson = json.encode(payload.design or {})
    local preview = payload.preview

    DB.SaveDesign({
        design_id = designId,
        owner_identifier = identifier,
        owner_name = ServerFW.GetName(src),
        label = label,
        gender = gender,
        category = category,
        template_id = templateId,
        garment_id = garmentId,
        design_json = designJson,
        preview_data = preview,
        image_url = payload.imageUrl
    })

    notify(src, 'Design elmentve.', 'success')
    TriggerClientEvent('realrpg_clothingstudio:client:designSaved', src, {
        design_id = designId,
        label = label,
        gender = gender,
        category = category,
        template_id = templateId,
        garment_id = garmentId,
        preview_data = preview,
        image_url = payload.imageUrl
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- NYOMTATÁS (PRINT ITEM)
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:printDesign', function(payload)
    local src = source
    if not Config.Printing.enabled then return end
    if type(payload) ~= 'table' or not payload.designId then return end

    local design = DB.GetDesign(payload.designId)
    if not design then
        notify(src, 'A design nem található.', 'error')
        return
    end

    local paid = ServerFW.RemoveMoney(src, Config.Printing.price, Config.Printing.account)
    if not paid then
        notify(src, ('Nincs elég pénzed. Ár: $%s'):format(Config.Printing.price), 'error')
        return
    end

    local template = Templates.Get(design.gender, design.category, design.template_id)
    if not template then
        notify(src, 'A design sablonja nem található.', 'error')
        return
    end

    -- Garment slot meghatározása a DUI rendszerhez
    local garmentId = design.garment_id or ''
    local garmentSlot = nil
    if garmentId ~= '' then
        garmentSlot = Garments.GetById(garmentId)
    end
    if not garmentSlot then
        -- Fallback: gender + category alapján keresünk
        local slots = Garments.GetByGenderCategory(design.gender, design.category)
        if slots and #slots > 0 then
            garmentSlot = slots[1]
            garmentId = garmentSlot.id
        end
    end

    -- Design layers dekódolás (ha JSON-ben van)
    local designData = {}
    if design.design_json and design.design_json ~= '' then
        local decoded = json.decode(design.design_json)
        if decoded then designData = decoded end
    end

    local metadata = {
        label = design.label,
        description = ('Egyedi RealRPG ruha: %s'):format(design.label),
        designId = design.design_id,
        gender = design.gender,
        category = design.category,
        templateId = design.template_id,
        garmentId = garmentId,
        component = template.component,
        drawable = garmentSlot and garmentSlot.drawable or template.drawable,
        texture = garmentSlot and garmentSlot.texture or (template.texture or 0),
        preview = design.preview_data,
        image = design.preview_data,
        layers = designData.layers,
        creator = design.owner_name,
        createdAt = design.created_at
    }

    local ok, err = Inv.AddPrintedItem(src, design.category, metadata)
    if not ok then
        notify(src, err or 'Nem sikerült létrehozni az itemet.', 'error')
        return
    end

    notify(src, 'A ruhát kinyomtattad és bekerült az inventorydba.', 'success')
end)

-- ═══════════════════════════════════════════════════════════════
-- EQUIPPED STATE & BROADCAST (DUI SYNC)
-- ═══════════════════════════════════════════════════════════════

--- Játékos felveszi a designt -> broadcast minden kliensnek
RegisterNetEvent('realrpg_clothingstudio:server:setEquipped', function(metadata)
    local src = source
    if type(metadata) ~= 'table' or not metadata.designId or not metadata.category then return end

    local identifier = ServerFW.GetIdentifier(src)

    -- DB mentés
    DB.SetEquipped(identifier, metadata.category, metadata.designId, metadata)

    -- Cache frissítés
    if not equippedCache[identifier] then
        equippedCache[identifier] = {}
    end
    equippedCache[identifier][metadata.category] = metadata
    playerIdentifiers[src] = identifier

    -- Broadcast MINDEN kliensnek (ők döntik el proximity alapján, hogy alkalmazzák-e)
    TriggerClientEvent('realrpg_clothingstudio:client:syncWearable', -1, src, metadata)

    if Config.Debug then
        print(('[^2RealRPG Server^0] Player %d equipped %s (design: %s)'):format(src, metadata.category, metadata.designId))
    end
end)

--- Játékos leveszi a designt
RegisterNetEvent('realrpg_clothingstudio:server:removeEquipped', function(category)
    local src = source
    if type(category) ~= 'string' then return end

    local identifier = ServerFW.GetIdentifier(src)

    -- DB törlés
    DB.RemoveEquipped(identifier, category)

    -- Cache frissítés
    if equippedCache[identifier] then
        equippedCache[identifier][category] = nil
    end

    -- Broadcast: levette a ruhát
    TriggerClientEvent('realrpg_clothingstudio:client:playerUnequipped', -1, src, category)

    if Config.Debug then
        print(('[^3RealRPG Server^0] Player %d unequipped %s'):format(src, category))
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- PERSISTENCE: BETÖLTÉS SPAWN-KOR
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:requestEquipped', function()
    local src = source
    local identifier = ServerFW.GetIdentifier(src)
    playerIdentifiers[src] = identifier

    local rows = DB.GetEquipped(identifier)
    local equipped = {}
    for _, row in ipairs(rows) do
        local meta = json.decode(row.metadata or '{}')
        meta.category = meta.category or row.category
        equipped[row.category] = meta
    end

    -- Cache feltöltés
    equippedCache[identifier] = equipped

    -- Saját equipped adatok küldése
    TriggerClientEvent('realrpg_clothingstudio:client:loadEquipped', src, equipped)

    -- Broadcast a többi játékosnak hogy ez a player mit visel
    -- (így a már online lévők is látják)
    for category, metadata in pairs(equipped) do
        TriggerClientEvent('realrpg_clothingstudio:client:syncWearable', -1, src, metadata)
    end

    if Config.Debug then
        local count = 0
        for _ in pairs(equipped) do count = count + 1 end
        print(('[^2RealRPG Server^0] Player %d loaded %d equipped items.'):format(src, count))
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- PROXIMITY SYNC: Egy kliens kéri egy másik játékos design adatait
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:requestPlayerEquipped', function(targetServerId)
    local src = source
    if type(targetServerId) ~= 'number' then return end
    if targetServerId == src then return end

    -- Target identifier keresése
    local targetIdentifier = playerIdentifiers[targetServerId]
    if not targetIdentifier then
        targetIdentifier = ServerFW.GetIdentifier(targetServerId)
        if targetIdentifier then
            playerIdentifiers[targetServerId] = targetIdentifier
        end
    end

    if not targetIdentifier then return end

    -- Cache-ből vagy DB-ből
    local equipped = equippedCache[targetIdentifier]
    if not equipped then
        local rows = DB.GetEquipped(targetIdentifier)
        equipped = {}
        for _, row in ipairs(rows) do
            local meta = json.decode(row.metadata or '{}')
            meta.category = meta.category or row.category
            equipped[row.category] = meta
        end
        equippedCache[targetIdentifier] = equipped
    end

    -- Csak a kérőnek küldjük el (nem broadcast)
    if next(equipped) then
        TriggerClientEvent('realrpg_clothingstudio:client:syncAllWearables', src, targetServerId, equipped)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- PLAYER DISCONNECT CLEANUP
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function(reason)
    local src = source

    -- Értesítjük a klienseket hogy a játékos kilépett (DUI cleanup)
    TriggerClientEvent('realrpg_clothingstudio:client:playerLeft', -1, src)

    -- Server-side cache cleanup
    local identifier = playerIdentifiers[src]
    if identifier then
        -- Nem töröljük az equippedCache-t mert visszajelentkezéskor kellhet
        -- De a playerIdentifiers-ből igen
        playerIdentifiers[src] = nil
    end

    if Config.Debug then
        print(('[^3RealRPG Server^0] Player %d disconnected, notified clients.'):format(src))
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- FRAMEWORK LOAD EVENTS
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('esx:playerLoaded', function(playerId)
    -- ESX: a kliens oldal triggereli a requestEquipped-et
end)

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    -- QB: a kliens oldal triggereli a requestEquipped-et
end)
