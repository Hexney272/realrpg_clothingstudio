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

-- Item use handler: az inventory rendszer hívja server.export-ként
-- Az item definícióban: server = { export = 'realrpg_clothingstudio.UseClothingItem' }
-- A data tábla tartalmazza: name, slot, count, metadata
function Inv.UseClothingItem(source, data)
    if type(data) ~= 'table' then return end
    local metadata = data.metadata or {}
    TriggerClientEvent('realrpg_clothingstudio:client:wearItem', source, metadata)
end

-- Export regisztráció (a server.export = 'realrpg_clothingstudio.UseClothingItem' használja)
exports('UseClothingItem', Inv.UseClothingItem)
