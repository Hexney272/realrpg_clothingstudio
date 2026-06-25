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

local function createTargetZones()
    if not Config.UseTarget then return end
    if GetResourceState('ox_target') ~= 'started' then return end

    for i, station in ipairs(Config.Stations) do
        exports.ox_target:addSphereZone({
            coords = station.coords,
            radius = station.radius or Config.InteractDistance,
            debug = Config.Debug,
            options = {
                {
                    name = ('realrpg_clothingstudio_%s'):format(i),
                    icon = 'fa-solid fa-shirt',
                    label = station.label,
                    onSelect = function()
                        TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', i)
                    end
                }
            }
        })
    end
end

CreateThread(function()
    createTargetZones()

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        nearbyStation = nil

        for i, station in ipairs(Config.Stations) do
            local dist = #(coords - station.coords)
            if dist < 20.0 then
                sleep = 0

                if not Config.UseTarget and Config.DrawMarker then
                    DrawMarker(
                        Config.Marker.type,
                        station.coords.x, station.coords.y, station.coords.z - 0.05,
                        0, 0, 0, 0, 0, 0,
                        Config.Marker.scale.x, Config.Marker.scale.y, Config.Marker.scale.z,
                        Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                        false, true, 2, false, nil, nil, false
                    )
                end

                if not Config.UseTarget and dist <= Config.InteractDistance then
                    nearbyStation = i
                    drawText3D(station.coords + vec3(0, 0, 0.35), ('[E] %s'):format(station.label))
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

local function requestEquipped()
    Wait(1500)
    TriggerServerEvent('realrpg_clothingstudio:server:requestEquipped')
end

AddEventHandler('esx:playerLoaded', requestEquipped)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', requestEquipped)
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(requestEquipped)
end)

exports('OpenStudio', function(stationIndex)
    TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', stationIndex or nearbyStation or 1)
end)
