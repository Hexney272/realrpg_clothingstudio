--[[
    RealRPG Clothing Studio - Inventory Bridge
    Supports: ox_inventory, codem-inventory, qs-inventory, ESX default, QBCore default
]]

Inv = {}

local inventoryReady = false

-- ═══════════════════════════════════════════════════════════════
-- DETECTION
-- ═══════════════════════════════════════════════════════════════

local function detectInventory()
    if Config.Inventory == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        return 'ox_inventory'
    elseif Config.Inventory == 'codem' and GetResourceState('codem-inventory') == 'started' then
        return 'codem'
    elseif Config.Inventory == 'qs-inventory' and GetResourceState('qs-inventory') == 'started' then
        return 'qs-inventory'
    end
    -- Fallback auto-detection
    if GetResourceState('ox_inventory') == 'started' then return 'ox_inventory' end
    if GetResourceState('codem-inventory') == 'started' then return 'codem' end
    if GetResourceState('qs-inventory') == 'started' then return 'qs-inventory' end
    return 'framework' -- fallback to ESX/QB default
end

local activeInventory = nil

-- ═══════════════════════════════════════════════════════════════
-- ADD ITEM
-- ═══════════════════════════════════════════════════════════════

function Inv.AddPrintedItem(src, category, metadata)
    local itemName = Config.Printing.items[category]
    if not itemName then return false, 'Nincs item ehhez a kategóriához: ' .. tostring(category) end

    if not activeInventory then
        activeInventory = detectInventory()
    end

    -- ─── ox_inventory ───
    if activeInventory == 'ox_inventory' then
        local success = exports.ox_inventory:AddItem(src, itemName, 1, metadata)
        if success then
            return true
        end
        return false, 'ox_inventory AddItem sikertelen.'
    end

    -- ─── codem-inventory ───
    if activeInventory == 'codem' then
        local success = exports['codem-inventory']:AddItem(src, itemName, 1, nil, metadata)
        if success then
            return true
        end
        return false, 'codem-inventory AddItem sikertelen.'
    end

    -- ─── qs-inventory (Quasar Advanced Inventory) ───
    if activeInventory == 'qs-inventory' then
        local success = exports['qs-inventory']:AddItem(src, itemName, 1, nil, metadata)
        if success then
            return true
        end
        return false, 'qs-inventory AddItem sikertelen.'
    end

    -- ─── Framework fallback (ESX/QB built-in) ───
    if RRFW.Name == 'esx' and ServerFW.ESX then
        local xPlayer = ServerFW.ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.addInventoryItem(itemName, 1, metadata)
            return true
        end
    elseif (RRFW.Name == 'qb' or RRFW.Name == 'qbox') and ServerFW.QB then
        local Player = ServerFW.QB.Functions.GetPlayer(src)
        if Player then
            Player.Functions.AddItem(itemName, 1, false, metadata)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add')
            return true
        end
    end

    return false, 'Inventory nem elérhető.'
end

-- ═══════════════════════════════════════════════════════════════
-- REMOVE ITEM (for marketplace purchases etc.)
-- ═══════════════════════════════════════════════════════════════

function Inv.RemoveItem(src, itemName, count, metadata)
    count = count or 1
    if not activeInventory then activeInventory = detectInventory() end

    if activeInventory == 'ox_inventory' then
        return exports.ox_inventory:RemoveItem(src, itemName, count, metadata)
    elseif activeInventory == 'codem' then
        return exports['codem-inventory']:RemoveItem(src, itemName, count)
    elseif activeInventory == 'qs-inventory' then
        return exports['qs-inventory']:RemoveItem(src, itemName, count)
    end

    -- Framework fallback
    if RRFW.Name == 'esx' and ServerFW.ESX then
        local xPlayer = ServerFW.ESX.GetPlayerFromId(src)
        if xPlayer then xPlayer.removeInventoryItem(itemName, count); return true end
    elseif (RRFW.Name == 'qb' or RRFW.Name == 'qbox') and ServerFW.QB then
        local Player = ServerFW.QB.Functions.GetPlayer(src)
        if Player then Player.Functions.RemoveItem(itemName, count); return true end
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════
-- USABLE ITEM REGISTRATION
-- ═══════════════════════════════════════════════════════════════

local function onUseClothingItem(src, item)
    local metadata = item and (item.metadata or item.info) or {}
    TriggerClientEvent('realrpg_clothingstudio:client:wearItem', src, metadata)
end

--- Server export for ox_inventory item definitions (server.export = 'realrpg_clothingstudio.UseClothingItem')
function UseClothingItem(event, item, inventory, slot, data)
    local src = inventory
    if type(inventory) == 'table' then
        src = inventory.id or source
    end
    if type(src) ~= 'number' then src = source end

    local metadata = {}
    if type(item) == 'table' then
        metadata = item.metadata or item.info or {}
    elseif type(data) == 'table' then
        metadata = data.metadata or data
    end

    TriggerClientEvent('realrpg_clothingstudio:client:wearItem', src, metadata)
end

-- Make it a proper export
exports('UseClothingItem', UseClothingItem)

CreateThread(function()
    Wait(1500)
    activeInventory = detectInventory()

    if Config.Debug then
        print(('[^2RealRPG Clothing Studio^0] Inventory rendszer: %s'):format(activeInventory))
    end

    -- ─── ox_inventory: RegisterUsableItem ───
    if activeInventory == 'ox_inventory' then
        for category, itemName in pairs(Config.Printing.items) do
            exports.ox_inventory:RegisterUsableItem(itemName, function(source, item)
                onUseClothingItem(source, item)
            end)
        end
        inventoryReady = true
        return
    end

    -- ─── codem-inventory: RegisterUsableItem ───
    if activeInventory == 'codem' then
        for category, itemName in pairs(Config.Printing.items) do
            exports['codem-inventory']:RegisterUsableItem(itemName, function(source, item)
                onUseClothingItem(source, item)
            end)
        end
        inventoryReady = true
        return
    end

    -- ─── qs-inventory: CreateUsableItem ───
    if activeInventory == 'qs-inventory' then
        for category, itemName in pairs(Config.Printing.items) do
            exports['qs-inventory']:CreateUsableItem(itemName, function(source, item)
                onUseClothingItem(source, item)
            end)
        end
        inventoryReady = true
        return
    end

    -- ─── ESX usable item fallback ───
    if RRFW.Name == 'esx' and ServerFW.ESX then
        for category, itemName in pairs(Config.Printing.items) do
            ServerFW.ESX.RegisterUsableItem(itemName, function(playerId)
                onUseClothingItem(playerId, {})
            end)
        end
        inventoryReady = true
        return
    end

    -- ─── QBCore usable item fallback ───
    if (RRFW.Name == 'qb' or RRFW.Name == 'qbox') and ServerFW.QB then
        for category, itemName in pairs(Config.Printing.items) do
            ServerFW.QB.Functions.CreateUseableItem(itemName, function(source, item)
                onUseClothingItem(source, item)
            end)
        end
        inventoryReady = true
        return
    end

    inventoryReady = true
end)

-- ═══════════════════════════════════════════════════════════════
-- STATUS
-- ═══════════════════════════════════════════════════════════════

function Inv.IsReady()
    return inventoryReady
end

function Inv.GetActiveInventory()
    return activeInventory or detectInventory()
end
