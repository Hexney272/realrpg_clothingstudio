--[[
    RealRPG Clothing Studio - Client Main
    
    Station interact háromféleképpen:
    1. ox_target (Config.Target = 'ox_target')
    2. qb-target (Config.Target = 'qb-target')
    3. Marker + E key (Config.Target = false)
    
    + Command regisztráció
    + Framework load events
]]

local nearbyStation = nil

-- ═══════════════════════════════════════════════════════════════
-- NOTIFY HELPER
-- ═══════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════
-- 3D TEXT HELPER (marker mód)
-- ═══════════════════════════════════════════════════════════════

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


-- ═══════════════════════════════════════════════════════════════
-- OX_TARGET REGISZTRÁCIÓ
-- ═══════════════════════════════════════════════════════════════

local function setupOxTarget()
    if GetResourceState('ox_target') ~= 'started' then
        print('[^1RealRPG^0] ox_target not found, falling back to marker mode.')
        return false
    end

    for i, station in ipairs(Config.Stations) do
        local options = {
            {
                name = ('realrpg_studio_%d'):format(i),
                icon = Config.TargetOptions.icon,
                label = station.label or Config.TargetOptions.label,
                distance = Config.TargetOptions.distance or 2.5,
                onSelect = function()
                    TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', i)
                end,
            }
        }

        -- Job ellenőrzés hozzáadása ha van
        if station.job then
            options[1].groups = { [station.job] = station.grade or 0 }
        end

        exports.ox_target:addSphereZone({
            coords = station.coords,
            radius = station.radius or 2.0,
            debug = Config.Debug,
            options = options
        })
    end

    if Config.Debug then
        print(('[^2RealRPG^0] ox_target: %d station(s) registered.'):format(#Config.Stations))
    end
    return true
end


-- ═══════════════════════════════════════════════════════════════
-- QB-TARGET REGISZTRÁCIÓ
-- ═══════════════════════════════════════════════════════════════

local function setupQbTarget()
    if GetResourceState('qb-target') ~= 'started' then
        print('[^1RealRPG^0] qb-target not found, falling back to marker mode.')
        return false
    end

    for i, station in ipairs(Config.Stations) do
        local options = {
            {
                type = 'client',
                event = 'realrpg_clothingstudio:client:targetOpen',
                icon = Config.TargetOptions.icon,
                label = station.label or Config.TargetOptions.label,
                stationIndex = i,
            }
        }

        -- Job ellenőrzés
        if station.job then
            options[1].job = station.job
            options[1].gang = nil
        end

        exports['qb-target']:AddCircleZone(
            ('realrpg_studio_%d'):format(i),
            station.coords,
            station.radius or 2.0,
            {
                name = ('realrpg_studio_%d'):format(i),
                debugPoly = Config.Debug,
                useZ = true
            },
            { options = options, distance = Config.TargetOptions.distance or 2.5 }
        )
    end

    if Config.Debug then
        print(('[^2RealRPG^0] qb-target: %d station(s) registered.'):format(#Config.Stations))
    end
    return true
end

-- QB-target event handler
RegisterNetEvent('realrpg_clothingstudio:client:targetOpen', function(data)
    local stationIndex = data and data.stationIndex or 1
    TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', stationIndex)
end)


-- ═══════════════════════════════════════════════════════════════
-- MARKER + E KEY MÓD (fallback)
-- ═══════════════════════════════════════════════════════════════

local function setupMarkerMode()
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
                        nearbyStation = i
                        drawText3D(station.coords + vec3(0, 0, 0.35), '[E] ' .. station.label)
                        if IsControlJustPressed(0, 38) then
                            TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', i)
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)

    if Config.Debug then
        print(('[^2RealRPG^0] Marker mode: %d station(s) active.'):format(#Config.Stations))
    end
end


-- ═══════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(500)

    local targetSetup = false

    if Config.Target == 'ox_target' then
        targetSetup = setupOxTarget()
    elseif Config.Target == 'qb-target' then
        targetSetup = setupQbTarget()
    end

    -- Ha target nem elérhető vagy nincs konfigurálva, fallback marker módra
    if not targetSetup then
        setupMarkerMode()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- COMMAND REGISZTRÁCIÓ
-- ═══════════════════════════════════════════════════════════════

if Config.UseCommand then
    RegisterCommand(Config.OpenCommand, function()
        TriggerServerEvent('realrpg_clothingstudio:server:requestOpen', nearbyStation or 1)
    end, false)
end

-- ═══════════════════════════════════════════════════════════════
-- FRAMEWORK LOAD EVENTS (equipped ruhák betöltése spawn-kor)
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('esx:playerLoaded', function()
    Wait(1500)
    TriggerServerEvent('realrpg_clothingstudio:server:requestEquipped')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    TriggerServerEvent('realrpg_clothingstudio:server:requestEquipped')
end)

-- Fallback: ha nincs framework event, 4 mp után kérjük
CreateThread(function()
    Wait(4000)
    TriggerServerEvent('realrpg_clothingstudio:server:requestEquipped')
end)
