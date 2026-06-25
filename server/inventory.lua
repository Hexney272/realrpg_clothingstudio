--[[
    RealRPG Clothing Studio - Inventory Integration
    
    ox_inventory:
    - AddItem: nyomtatott ruha hozzáadása metadata-val
    - RegisterUsableItem: item használat (felvétel)
    
    A context menu logikát az ox_inventory metadata image megjeleníti,
    és a 'client.export' rendszerrel kezeljük az item használatot.
    
    ESX/QB fallback is támogatott (metadata nélkül).
]]

Inv = {}

-- ═══════════════════════════════════════════════════════════════
-- ITEM HOZZÁADÁS
-- ═══════════════════════════════════════════════════════════════

function Inv.AddPrintedItem(src, category, metadata)
    local itemName = Config.Printing.items[category]
    if not itemName then return false, 'Nincs item ehhez a kategoriához.' end

    -- Metadata előkészítés ox_inventory-nak
    -- Az ox_inventory automatikusan megjeleníti a metadata.image-et az item tooltip-ben
    local oxMeta = metadata or {}

    -- Image URL vagy base64 - az ox_inventory tooltip-ben jelenik meg
    -- Ha van Discord CDN URL, azt használjuk (kisebb méret)
    if oxMeta.image_url and oxMeta.image_url ~= '' then
        oxMeta.image = oxMeta.image_url
    end

    if Config.Inventory == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        return exports['ox_inventory']:AddItem(src, itemName, 1, oxMeta)
    end

    if RRFW.Name == 'esx' and ServerFW.ESX then
        local xPlayer = ServerFW.ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.addInventoryItem(itemName, 1)
            return true
        end
    elseif RRFW.Name == 'qb' and ServerFW.QB then
        local Player = ServerFW.QB.Functions.GetPlayer(src)
        if Player then
            Player.Functions.AddItem(itemName, 1, false, oxMeta)
            return true
        end
    end

    return false, 'Inventory nem elerheto.'
end

-- ═══════════════════════════════════════════════════════════════
-- OX_INVENTORY USABLE ITEM REGISTRATION
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(1000)
    if Config.Inventory ~= 'ox_inventory' or GetResourceState('ox_inventory') ~= 'started' then return end

    for category, itemName in pairs(Config.Printing.items) do
        exports['ox_inventory']:RegisterUsableItem(itemName, function(source, item)
            local src = source
            local metadata = item and item.metadata or {}
            metadata.category = metadata.category or category

            -- Ellenőrizzük hogy már viseli-e ezt a kategóriát
            -- Ha igen, levesszük (toggle logika)
            TriggerClientEvent('realrpg_clothingstudio:client:useClothingItem', src, {
                action = 'use',
                metadata = metadata,
                slot = item.slot,
                category = category
            })
        end)
    end

    if Config.Debug then
        print('[^2RealRPG Inv^0] ox_inventory usable items registered.')
    end
end)
