--[[
    RealRPG Clothing Studio - Client Main
    Optimized marker loop, interaction handling, props support
]]

local nearbyStation = nil
local stationCooldown = 0

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

RegisterNetEvent('realrpg_clothingstudio:client:printLines', function(lines)
    if type(lines) ~= 'table' then return end
    for _, line in ipairs(lines) do
        print(line)
    end
end)

local function drawText3D(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(215, 255, 0, 230)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- ═══════════════════════════════════════════════════════════════
-- OPTIMIZED STATION LOOP
-- Uses distance-based sleep optimization to reduce CPU usage
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    local stations = Config.Stations
    if not stations or #stations == 0 then return end

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        nearbyStation = nil

        local closestDist = math.huge
        local closestIdx = nil
        local closestStation = nil

        -- Find closest station
        for i, station in ipairs(stations) do
            local dist = #(coords - station.coords)
            if dist < closestDist then
                closestDist = dist
                closestIdx = i
                closestStation = station
            end
        end

        -- Distance-based optimization
        if closestDist > 100.0 then
            sleep = 2000 -- Very far, check rarely
        elseif closestDist > 50.0 then
            sleep = 1000 -- Moderate distance
        elseif closestDist > 20.0 then
            sleep = 500  -- Getting closer
        else
            sleep = 0 -- Nearby, full speed for smooth markers

            -- Draw marker if enabled
            if Config.DrawMarker and closestStation then
                DrawMarker(
                    Config.Marker.type,
                    closestStation.coords.x, closestStation.coords.y, closestStation.coords.z - 0.05,
                    0, 0, 0, 0, 0, 0,
                    Config.Marker.scale.x, Config.Marker.scale.y, Config.Marker.scale.z,
                    Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                    false, true, 2, false, nil, nil, false
                )
            end

            -- Check interaction distance
            if closestDist <= Config.InteractDistance and closestStation then
                nearbyStation = closestIdx
                drawText3D(closestStation.coords + vec3(0, 0, 0.35), '[E] ' .. closestStation.label)

                -- Interaction with cooldown to prevent spam
                if IsControlJustPressed(0, 38) and GetGameTimer() > stationCooldown then
                    stationCooldown = GetGameTimer() + 1000
                    TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', closestIdx)
                end
            end

            -- Check other nearby stations for markers
            for i, station in ipairs(stations) do
                if i ~= closestIdx then
                    local dist = #(coords - station.coords)
                    if dist < 20.0 and Config.DrawMarker then
                        DrawMarker(
                            Config.Marker.type,
                            station.coords.x, station.coords.y, station.coords.z - 0.05,
                            0, 0, 0, 0, 0, 0,
                            Config.Marker.scale.x, Config.Marker.scale.y, Config.Marker.scale.z,
                            Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                            false, true, 2, false, nil, nil, false
                        )
                    end
                    if dist <= Config.InteractDistance then
                        drawText3D(station.coords + vec3(0, 0, 0.35), '[E] ' .. station.label)
                        if IsControlJustPressed(0, 38) and GetGameTimer() > stationCooldown then
                            stationCooldown = GetGameTimer() + 1000
                            TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', i)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- COMMAND
-- ═══════════════════════════════════════════════════════════════

if Config.UseCommand then
    RegisterCommand(Config.OpenCommand, function()
        TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', nearbyStation or 1)
    end, false)
end

-- ═══════════════════════════════════════════════════════════════
-- FRAMEWORK LOAD HANDLERS
-- ═══════════════════════════════════════════════════════════════

local function onPlayerReady()
    Wait(1500)
    TriggerServerEvent('realrpg_clothingstudio:server:requestEquipped')
end

AddEventHandler('esx:playerLoaded', onPlayerReady)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', onPlayerReady)

-- Fallback for already-loaded players
CreateThread(function()
    Wait(4000)
    TriggerServerEvent('realrpg_clothingstudio:server:requestEquipped')
end)
