local nearbyStation = nil

local function notify(msg, typ)
    if lib and lib.notify then
        lib.notify({ description = msg, type = typ or 'info' })
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(msg)
        DrawNotification(false, false)
    end
end

RegisterNetEvent('realrpg_clothingstudio:client:notify', notify)

local function drawText3D(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(215, 255, 0, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        nearbyStation = nil

        for i, station in ipairs(Config.Stations) do
            local dist = #(coords - station.coords)
            if dist < 20.0 then
                sleep = 0
                if Config.DrawMarker then
                    DrawMarker(Config.Marker.type, station.coords.x, station.coords.y, station.coords.z - 0.05, 0,0,0,0,0,0, Config.Marker.scale.x, Config.Marker.scale.y, Config.Marker.scale.z, Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a, false, true, 2, false, nil, nil, false)
                end
                if dist <= Config.InteractDistance then
                    nearbyStation = i
                    drawText3D(station.coords + vec3(0,0,0.35), '[E] ' .. station.label)
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', i)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

if Config.UseCommand then
    RegisterCommand(Config.OpenCommand, function()
        TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', nearbyStation or 1)
    end)
end

AddEventHandler('esx:playerLoaded', function()
    Wait(1500)
    TriggerServerEvent('realrpg_clothingstudio:server:requestEquipped')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    TriggerServerEvent('realrpg_clothingstudio:server:requestEquipped')
end)

CreateThread(function()
    Wait(4000)
    TriggerServerEvent('realrpg_clothingstudio:server:requestEquipped')
end)
