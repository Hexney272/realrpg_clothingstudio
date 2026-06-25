--[[
    RealRPG Clothing Studio - Wearables Manager (DUI Runtime Texture Edition)
    
    Ez a modul felelős a viselt ruhák kezeléséért:
    - Saját ped: DUI runtime texture alkalmazás item használatkor
    - Távoli játékosok: szinkronizált design megjelenítés
    - Persistence: betöltéskor visszaállítja a viselt ruhákat
    - Fallback: ha nincs DUI/blank garment, component swap-ot használ (MVP mód)
    
    A flow:
    1. Játékos használ egy printed itemet (ox_inventory usable)
    2. Server elküldi a metadata-t (designId, garmentId, preview, layers, stb.)
    3. Kliens feloldja a garment slot-ot, alkalmazza a DUI textúrát
    4. Server broadcast-ol minden kliensnek a szinkronhoz
]]

local equipped = {}           -- Saját viselt designek: category -> metadata
local remoteEquipped = {}     -- Távoli játékosok: serverId -> { category -> metadata }
local originalComponents = {} -- Eredeti component adatok visszaállításhoz: category -> { drawable, texture }

-- ═══════════════════════════════════════════════════════════════
-- SAJÁT PED - DESIGN ALKALMAZÁS
-- ═══════════════════════════════════════════════════════════════

--- Design alkalmazása a saját ped-re
---@param metadata table Item metadata (garmentId, preview, layers, category, gender, ...)
local function applyDesignToSelf(metadata)
    if type(metadata) ~= 'table' then return end

    local ped = PlayerPedId()
    local serverId = GetPlayerServerId(PlayerId())
    local category = metadata.category or 'tops'

    -- Garment slot feloldása
    local garmentSlot = RTex.ResolveGarmentSlot(metadata)

    if garmentSlot and Config.DUI.enabled then
        -- ═══ DUI RUNTIME TEXTURE MÓD ═══
        -- Eredeti component mentése (visszaállításhoz)
        if not originalComponents[category] then
            originalComponents[category] = {
                drawable = GetPedDrawableVariation(ped, garmentSlot.component),
                texture = GetPedTextureVariation(ped, garmentSlot.component)
            }
        end

        local key = DUI.MakeKey(serverId, category)

        -- Design data összeállítása
        local designData = {
            preview = metadata.preview or metadata.image,
            layers = metadata.layers,
            background = '#ffffff'
        }

        -- Teljes DUI + texture replace flow
        local success = RTex.ApplyDesignToPed(ped, key, garmentSlot, designData, 100) -- priority 100 = saját ped

        if success then
            if Config.Debug then
                print(('[^2RealRPG Wear^0] DUI design applied to self: %s [%s]'):format(category, metadata.designId or '?'))
            end
        else
            -- DUI sikertelen - fallback component swap-ra
            applyFallback(ped, metadata)
        end
    else
        -- ═══ FALLBACK: COMPONENT SWAP MÓD (MVP) ═══
        applyFallback(ped, metadata)
    end

    -- Tracking
    equipped[category] = metadata
end

--- Fallback: egyszerű component variation swap (ha nincs DUI/blank garment)
---@param ped number
---@param metadata table
function applyFallback(ped, metadata)
    local component = tonumber(metadata.component)
    local drawable = tonumber(metadata.drawable)
    local texture = tonumber(metadata.texture or 0)

    if component and drawable then
        if not originalComponents[metadata.category or 'tops'] then
            originalComponents[metadata.category or 'tops'] = {
                drawable = GetPedDrawableVariation(ped, component),
                texture = GetPedTextureVariation(ped, component)
            }
        end
        SetPedComponentVariation(ped, component, drawable, texture, 2)

        if Config.Debug then
            print(('[^3RealRPG Wear^0] Fallback component swap: comp=%d draw=%d tex=%d'):format(component, drawable, texture))
        end
    end
end

--- Design eltávolítása a saját ped-ről (visszaállítás)
---@param category string
local function removeDesignFromSelf(category)
    local ped = PlayerPedId()
    local serverId = GetPlayerServerId(PlayerId())
    local key = DUI.MakeKey(serverId, category)

    -- DUI + runtime texture eltávolítása
    local original = originalComponents[category]
    RTex.RemoveDesignFromPed(key, ped, original and original.drawable, original and original.texture)

    -- Tracking törlés
    equipped[category] = nil
    originalComponents[category] = nil

    if Config.Debug then
        print(('[^3RealRPG Wear^0] Design removed from self: %s'):format(category))
    end
end

-- ═══════════════════════════════════════════════════════════════
-- TÁVOLI JÁTÉKOSOK - SZINKRONIZÁCIÓ
-- ═══════════════════════════════════════════════════════════════

--- Design alkalmazása egy távoli játékos ped-jére
---@param serverId number
---@param metadata table
local function applyDesignToRemote(serverId, metadata)
    if type(metadata) ~= 'table' then return end
    if serverId == GetPlayerServerId(PlayerId()) then
        -- Saját ped-et nem kezeljük itt
        return
    end

    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return end
    
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 then return end

    local category = metadata.category or 'tops'
    local garmentSlot = RTex.ResolveGarmentSlot(metadata)

    if garmentSlot and Config.DUI.enabled then
        -- DUI runtime texture a távoli ped-re
        local key = DUI.MakeKey(serverId, category)
        local designData = {
            preview = metadata.preview or metadata.image,
            layers = metadata.layers,
            background = '#ffffff'
        }

        -- Alacsonyabb prioritás mint a saját ped
        local priority = 50
        -- Közeli játékosoknak magasabb prioritás
        local myCoords = GetEntityCoords(PlayerPedId())
        local targetCoords = GetEntityCoords(ped)
        local dist = #(myCoords - targetCoords)
        if dist < 15.0 then
            priority = 70
        elseif dist > Config.DUI.renderDistance then
            -- Túl messze - ne foglalkozzunk vele
            return
        end

        RTex.ApplyDesignToPed(ped, key, garmentSlot, designData, priority)
    else
        -- Fallback
        applyFallback(ped, metadata)
    end

    -- Tracking
    if not remoteEquipped[serverId] then
        remoteEquipped[serverId] = {}
    end
    remoteEquipped[serverId][category] = metadata
end

--- Távoli játékos összes design-jének eltávolítása (disconnect/eltávolodás)
---@param serverId number
local function removeRemotePlayer(serverId)
    RTex.RemoveAllForPlayer(serverId)
    remoteEquipped[serverId] = nil
end

-- ═══════════════════════════════════════════════════════════════
-- EVENTS - ITEM HASZNÁLAT
-- ═══════════════════════════════════════════════════════════════

--- Item használatkor triggerelve (ox_inventory RegisterUsableItem -> server -> client)
RegisterNetEvent('realrpg_clothingstudio:client:wearItem', function(metadata)
    if type(metadata) ~= 'table' then return end
    applyDesignToSelf(metadata)
    -- Server-nek is jelezzük az equipped state-et
    TriggerServerEvent('realrpg_clothingstudio:server:setEquipped', metadata)
end)

--- Design levétele
RegisterNetEvent('realrpg_clothingstudio:client:unwearItem', function(category)
    category = category or 'tops'
    removeDesignFromSelf(category)
    TriggerServerEvent('realrpg_clothingstudio:server:removeEquipped', category)
end)

-- ═══════════════════════════════════════════════════════════════
-- EVENTS - PERSISTENCE & SYNC
-- ═══════════════════════════════════════════════════════════════

--- Betöltéskor visszakapjuk a viselt designeket a servertől
RegisterNetEvent('realrpg_clothingstudio:client:loadEquipped', function(data)
    if type(data) ~= 'table' then return end
    equipped = {}

    -- Kis várakozás hogy a ped teljesen betöltődjön
    Wait(500)

    for category, metadata in pairs(data) do
        if type(metadata) == 'table' then
            applyDesignToSelf(metadata)
        end
    end

    if Config.Debug then
        local count = 0
        for _ in pairs(equipped) do count = count + 1 end
        print(('[^2RealRPG Wear^0] Loaded %d equipped designs.'):format(count))
    end
end)

--- Más játékos design szinkronizációja (broadcast event)
RegisterNetEvent('realrpg_clothingstudio:client:syncWearable', function(serverId, metadata)
    if type(metadata) ~= 'table' then return end
    applyDesignToRemote(serverId, metadata)
end)

--- Más játékos összes viselt design-jének betöltése (amikor közel kerülünk)
RegisterNetEvent('realrpg_clothingstudio:client:syncAllWearables', function(serverId, allMetadata)
    if type(allMetadata) ~= 'table' then return end
    for category, metadata in pairs(allMetadata) do
        if type(metadata) == 'table' then
            metadata.category = metadata.category or category
            applyDesignToRemote(serverId, metadata)
        end
    end
end)

--- Játékos disconnect - cleanup
RegisterNetEvent('realrpg_clothingstudio:client:playerLeft', function(serverId)
    removeRemotePlayer(serverId)
end)

-- ═══════════════════════════════════════════════════════════════
-- PROXIMITY SYNC THREAD
-- ═══════════════════════════════════════════════════════════════

--- Periodikusan ellenőrzi a közeli játékosokat és kéri a design adataikat
CreateThread(function()
    -- Várjunk amíg minden betöltődik
    Wait(5000)

    while true do
        Wait(Config.DUI.syncInterval or 5000)

        if not Config.DUI.enabled then goto continue end

        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local myServerId = GetPlayerServerId(PlayerId())
        local activePlayers = GetActivePlayers()

        for _, playerId in ipairs(activePlayers) do
            local serverId = GetPlayerServerId(playerId)
            if serverId ~= myServerId then
                local targetPed = GetPlayerPed(playerId)
                if targetPed and targetPed ~= 0 then
                    local targetCoords = GetEntityCoords(targetPed)
                    local dist = #(myCoords - targetCoords)

                    if dist <= Config.DUI.renderDistance then
                        -- Közelben van - ha még nincs szinkronizálva, kérjük az adatait
                        if not remoteEquipped[serverId] then
                            TriggerServerEvent('realrpg_clothingstudio:server:requestPlayerEquipped', serverId)
                        end
                    else
                        -- Távol van - takarítunk
                        if remoteEquipped[serverId] then
                            removeRemotePlayer(serverId)
                        end
                    end
                end
            end
        end

        ::continue::
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- PED MODEL CHANGE HANDLING
-- ═══════════════════════════════════════════════════════════════

--- Ha a játékos ped modelje változik, újra kell alkalmazni a textúrákat
CreateThread(function()
    local lastModel = nil
    
    while true do
        Wait(1000)
        
        local ped = PlayerPedId()
        local model = GetEntityModel(ped)
        
        if lastModel and model ~= lastModel then
            -- Model változott - újra alkalmazzuk a viselt designeket
            if Config.Debug then
                print('[^3RealRPG Wear^0] Ped model changed, reapplying designs...')
            end
            
            Wait(500) -- Várjunk hogy a ped teljesen betöltődjön
            
            local serverId = GetPlayerServerId(PlayerId())
            for category, metadata in pairs(equipped) do
                if type(metadata) == 'table' then
                    -- Töröljük a régit és újra alkalmazzuk
                    local key = DUI.MakeKey(serverId, category)
                    RTex.Remove(key)
                    applyDesignToSelf(metadata)
                end
            end
        end
        
        lastModel = model
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- EXPORTS & GETTERS
-- ═══════════════════════════════════════════════════════════════

--- Saját viselt designek lekérése (más resourceok számára)
---@return table equipped
function GetEquippedDesigns()
    return equipped
end

--- Ellenőrzi hogy van-e DUI design egy adott kategóriában
---@param category string
---@return boolean
function HasDUIDesign(category)
    if not equipped[category] then return false end
    local serverId = GetPlayerServerId(PlayerId())
    local key = DUI.MakeKey(serverId, category)
    return DUI.IsActive(key)
end

exports('GetEquippedDesigns', GetEquippedDesigns)
exports('HasDUIDesign', HasDUIDesign)
