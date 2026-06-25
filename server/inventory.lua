Inv = {}

function Inv.AddPrintedItem(src, category, metadata)
    local itemName = Config.Printing.items[category]
    if not itemName then return false, 'Nincs item ehhez a kategóriához.' end

    if Config.Inventory == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
        return exports['ox_inventory']:AddItem(src, itemName, 1, metadata)
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
            Player.Functions.AddItem(itemName, 1, false, metadata)
            return true
        end
    end

    return false, 'Inventory nem elérhető.'
end

-- ox_inventory usable item registration
CreateThread(function()
    Wait(1000)
    if Config.Inventory ~= 'ox_inventory' or GetResourceState('ox_inventory') ~= 'started' then return end

    for category, itemName in pairs(Config.Printing.items) do
        exports['ox_inventory']:RegisterUsableItem(itemName, function(source, item)
            local metadata = item and item.metadata or {}
            TriggerClientEvent('realrpg_clothingstudio:client:wearItem', source, metadata)
        end)
    end
end)
