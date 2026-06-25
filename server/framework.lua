ServerFW = {}
ServerFW.ESX = nil
ServerFW.QB = nil

CreateThread(function()
    if RRFW.Name == 'esx' then
        ServerFW.ESX = exports['es_extended']:getSharedObject()
    elseif RRFW.Name == 'qb' then
        ServerFW.QB = exports['qb-core']:GetCoreObject()
    elseif RRFW.Name == 'qbox' then
        -- qbox exports are usually direct through qbx_core / ox_core style wrappers.
    end
end)

function ServerFW.GetIdentifier(src)
    if RRFW.Name == 'esx' and ServerFW.ESX then
        local xPlayer = ServerFW.ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.identifier or ('license:' .. src)
    elseif RRFW.Name == 'qb' and ServerFW.QB then
        local Player = ServerFW.QB.Functions.GetPlayer(src)
        return Player and Player.PlayerData.citizenid or ('license:' .. src)
    end
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find('license:') then return id end
    end
    return tostring(src)
end

function ServerFW.GetName(src)
    local name = GetPlayerName(src) or 'Unknown'
    return name
end

function ServerFW.GetJob(src)
    if RRFW.Name == 'esx' and ServerFW.ESX then
        local xPlayer = ServerFW.ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.job then
            return xPlayer.job.name, tonumber(xPlayer.job.grade) or 0
        end
    elseif RRFW.Name == 'qb' and ServerFW.QB then
        local Player = ServerFW.QB.Functions.GetPlayer(src)
        if Player and Player.PlayerData.job then
            return Player.PlayerData.job.name, tonumber(Player.PlayerData.job.grade.level) or 0
        end
    end
    return nil, 0
end

function ServerFW.RemoveMoney(src, amount, account)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end

    if RRFW.Name == 'esx' and ServerFW.ESX then
        local xPlayer = ServerFW.ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        if account == 'bank' then
            if xPlayer.getAccount('bank').money < amount then return false end
            xPlayer.removeAccountMoney('bank', amount)
        else
            if xPlayer.getMoney() < amount then return false end
            xPlayer.removeMoney(amount)
        end
        return true
    elseif RRFW.Name == 'qb' and ServerFW.QB then
        local Player = ServerFW.QB.Functions.GetPlayer(src)
        if not Player then return false end
        local qbAccount = account == 'bank' and 'bank' or 'cash'
        return Player.Functions.RemoveMoney(qbAccount, amount, 'clothing-studio-print')
    end
    return true
end
