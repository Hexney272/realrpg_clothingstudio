ServerFW = {}
ServerFW.ESX = nil
ServerFW.QB = nil
ServerFW.QBOX = nil

CreateThread(function()
    if RRFW.Name == 'esx' and GetResourceState('es_extended') == 'started' then
        ServerFW.ESX = exports['es_extended']:getSharedObject()
    elseif RRFW.Name == 'qb' and GetResourceState('qb-core') == 'started' then
        ServerFW.QB = exports['qb-core']:GetCoreObject()
    elseif RRFW.Name == 'qbox' and GetResourceState('qbx_core') == 'started' then
        ServerFW.QBOX = exports['qbx_core']
    end
end)

function ServerFW.GetIdentifier(src)
    if RRFW.Name == 'esx' and ServerFW.ESX then
        local xPlayer = ServerFW.ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.identifier or ('license:' .. src)
    elseif RRFW.Name == 'qb' and ServerFW.QB then
        local Player = ServerFW.QB.Functions.GetPlayer(src)
        return Player and Player.PlayerData.citizenid or ('license:' .. src)
    elseif RRFW.Name == 'qbox' then
        local ok, state = pcall(function() return Player(src).state end)
        if ok and state and state.citizenid then return state.citizenid end
    end

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find('license:') then return id end
    end

    return tostring(src)
end

function ServerFW.GetName(src)
    return GetPlayerName(src) or 'Unknown'
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
    elseif RRFW.Name == 'qbox' then
        local ok, state = pcall(function() return Player(src).state end)
        if ok and state and state.job then
            local grade = 0
            if type(state.job.grade) == 'table' then
                grade = tonumber(state.job.grade.level or state.job.grade.grade or state.job.grade) or 0
            else
                grade = tonumber(state.job.grade) or 0
            end
            return state.job.name, grade
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
            local bank = xPlayer.getAccount('bank')
            if not bank or bank.money < amount then return false end
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
    elseif RRFW.Name == 'qbox' then
        -- Add your qbox money bridge here if needed.
        return true
    end

    return true
end

function ServerFW.AddMoney(src, amount, account)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end

    if RRFW.Name == 'esx' and ServerFW.ESX then
        local xPlayer = ServerFW.ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        if account == 'bank' then
            xPlayer.addAccountMoney('bank', amount)
        else
            xPlayer.addMoney(amount)
        end
        return true
    elseif RRFW.Name == 'qb' and ServerFW.QB then
        local Player = ServerFW.QB.Functions.GetPlayer(src)
        if not Player then return false end
        local qbAccount = account == 'bank' and 'bank' or 'cash'
        Player.Functions.AddMoney(qbAccount, amount, 'clothing-studio-marketplace-payout')
        return true
    elseif RRFW.Name == 'qbox' then
        return true
    end

    return true
end
