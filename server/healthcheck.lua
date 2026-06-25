RRCSHealth = RRCSHealth or {}

local function statusLine(status, label, details)
    return ('[%s] %s%s'):format(status, label, details and details ~= '' and (' - ' .. details) or '')
end

local function printLines(src, lines)
    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        TriggerClientEvent('realrpg_clothingstudio:client:printLines', src, lines)
        TriggerClientEvent('realrpg_clothingstudio:client:notify', src, 'Healthcheck riport kiírva az F8 konzolba.', 'info')
    end
end

local function hasAdmin(src)
    if RRCSAdmin and RRCSAdmin.HasPermission then return RRCSAdmin.HasPermission(src) end
    if src == 0 then return true end
    local ace = Config.Admin and Config.Admin.permission
    return ace and ace ~= '' and IsPlayerAceAllowed(src, ace)
end

local function fileExists(path)
    local data = LoadResourceFile(GetCurrentResourceName(), path)
    return data ~= nil, data
end

local function countSlots()
    local counts = {}
    local duplicates = {}
    local seen = {}
    for category, slots in pairs((Config.RuntimeTextures and Config.RuntimeTextures.slots) or {}) do
        counts[category] = #slots
        for _, slot in ipairs(slots) do
            local key = ('%s:%s'):format(category, slot.slot)
            if seen[key] then duplicates[#duplicates + 1] = key end
            seen[key] = true
        end
    end
    return counts, duplicates
end

local function countTemplates()
    local total = 0
    local byCategory = {}
    for gender, cats in pairs((Templates and Templates.List) or {}) do
        for category, list in pairs(cats) do
            local key = ('%s/%s'):format(gender, category)
            byCategory[key] = #list
            total = total + #list
        end
    end
    return total, byCategory
end

local function dbTableExists(tableName)
    local ok, result = pcall(function()
        return MySQL.single.await([[SELECT COUNT(*) AS c FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { tableName })
    end)
    if not ok then return false, 'query_error' end
    return (tonumber(result and result.c) or 0) > 0
end

local function dbCount(query, params)
    local ok, result = pcall(function()
        return MySQL.single.await(query, params or {})
    end)
    if not ok then return nil, 'query_error' end
    return tonumber(result and (result.c or result.count)) or 0
end

function RRCSHealth.BuildReport(mode)
    local lines = {}
    local okCount, warnCount, failCount = 0, 0, 0

    local function ok(label, details)
        okCount = okCount + 1
        lines[#lines + 1] = statusLine('OK', label, details)
    end
    local function warn(label, details)
        warnCount = warnCount + 1
        lines[#lines + 1] = statusLine('WARN', label, details)
    end
    local function fail(label, details)
        failCount = failCount + 1
        lines[#lines + 1] = statusLine('FAIL', label, details)
    end

    lines[#lines + 1] = 'RealRPG Clothing Studio v1.1 Healthcheck'
    lines[#lines + 1] = ('Mode: %s | Resource: %s'):format(mode or 'full', GetCurrentResourceName())

    if GetResourceState('oxmysql') == 'started' then ok('oxmysql', 'started') else fail('oxmysql', GetResourceState('oxmysql')) end
    if Config.Inventory == 'ox_inventory' then
        if GetResourceState('ox_inventory') == 'started' then ok('ox_inventory', 'started') else warn('ox_inventory', GetResourceState('ox_inventory')) end
    end

    if RRFW and RRFW.Name then ok('framework detection', RRFW.Name) else warn('framework detection', 'RRFW.Name missing') end

    local requiredFiles = {
        'web/index.html',
        'web/app.js',
        'web/style.css',
        'web/dui_texture.html',
        'server/upload_bridge.lua',
        'server/ai_bridge.lua',
        'server/admin.lua',
        'server/healthcheck.lua',
        'stream/blank_templates/manifest.json'
    }
    for _, path in ipairs(requiredFiles) do
        local exists = fileExists(path)
        if exists then ok('file', path) else warn('file missing', path) end
    end

    if Config.Healthcheck and Config.Healthcheck.validateDatabase then
        for _, tableName in ipairs(Config.Healthcheck.expectedTables or {}) do
            local exists, err = dbTableExists(tableName)
            if exists then ok('db table', tableName) else fail('db table missing', tableName .. (err and (' / ' .. err) or '')) end
        end

        local designs = dbCount('SELECT COUNT(*) AS c FROM realrpg_clothing_designs')
        if designs ~= nil then ok('db designs count', tostring(designs)) end
        local slots = dbCount('SELECT COUNT(*) AS c FROM realrpg_clothing_design_slots')
        if slots ~= nil then ok('db used runtime slots', tostring(slots)) end
    end

    if Config.Healthcheck and Config.Healthcheck.validateManifest then
        local exists, manifest = fileExists((Config.GarmentPack and Config.GarmentPack.manifest) or 'stream/blank_templates/manifest.json')
        if exists then
            local parsed = json.decode(manifest or '{}')
            if parsed and type(parsed) == 'table' then
                ok('garment manifest', ('pack=%s'):format(parsed.name or 'unnamed'))
                local slotTotal = 0
                for _, slot in ipairs(parsed.runtimeSlots or {}) do slotTotal = slotTotal + 1 end
                ok('manifest runtime slots', tostring(slotTotal))
            else
                fail('garment manifest', 'invalid json')
            end
        else
            warn('garment manifest', 'not found')
        end
    end

    if Config.Healthcheck and Config.Healthcheck.validateRuntimeSlots then
        local counts, duplicates = countSlots()
        for category, count in pairs(counts) do
            if count > 0 then ok('runtime slots ' .. category, tostring(count)) else warn('runtime slots ' .. category, 'empty') end
        end
        if #duplicates > 0 then fail('runtime duplicate slots', table.concat(duplicates, ', ')) else ok('runtime duplicate slots', 'none') end

        local totalTemplates = countTemplates()
        if totalTemplates > 0 then ok('templates loaded', tostring(totalTemplates)) else fail('templates loaded', '0') end
    end

    if Config.Healthcheck and Config.Healthcheck.validateUploadBridge then
        local uploadEnabled = UploadBridge and UploadBridge.IsEnabled and UploadBridge.IsEnabled()
        if uploadEnabled then ok('upload bridge', Config.UploadBridge.provider or 'enabled') else warn('upload bridge', 'disabled') end
        if Config.UploadBridge and Config.UploadBridge.enabled and (not Config.UploadBridge.discordWebhook or Config.UploadBridge.discordWebhook == '') then
            fail('upload webhook', 'Config.UploadBridge.discordWebhook empty')
        elseif Config.UploadBridge and Config.UploadBridge.enabled then
            ok('upload webhook', 'set')
        end
        if Config.UploadBridge and Config.UploadBridge.uploadLayerAssets then ok('layer asset upload', 'enabled') else warn('layer asset upload', 'disabled') end
    end

    if Config.Healthcheck and Config.Healthcheck.validateAI then
        if Config.AI and Config.AI.enabled then
            if Config.AI.apiKey and Config.AI.apiKey ~= '' then ok('AI api key', 'set') else fail('AI api key', 'missing') end
            ok('AI model', Config.AI.model or 'nil')
            if Config.AI.uploadResultToCdn and not (UploadBridge and UploadBridge.IsEnabled and UploadBridge.IsEnabled()) then
                warn('AI CDN upload', 'AI upload enabled but upload bridge disabled')
            end
        else
            warn('AI bridge', 'disabled')
        end
    end

    if Config.Healthcheck and Config.Healthcheck.validateMarketplace then
        if Config.Marketplace and Config.Marketplace.enabled then ok('marketplace', 'enabled') else warn('marketplace', 'disabled') end
        if Config.Admin and Config.Admin.permission and Config.Admin.permission ~= '' then ok('admin ACE', Config.Admin.permission) else warn('admin ACE', 'missing') end
        if Config.Audit and Config.Audit.enabled then ok('audit log', 'enabled') else warn('audit log', 'disabled') end
    end

    if Config.Healthcheck and Config.Healthcheck.printRecommendations then
        lines[#lines + 1] = 'Recommendations:'
        if Config.RuntimeTextures and Config.RuntimeTextures.enabled and Config.RuntimeTextures.requireSlotForPrint then
            lines[#lines + 1] = '- Keep one unique runtime slot per simultaneously used blank garment design.'
        end
        if Config.UploadBridge and not Config.UploadBridge.enabled then
            lines[#lines + 1] = '- Enable UploadBridge before production to avoid large base64 data in DB.'
        end
        if Config.Marketplace and Config.Marketplace.requireApproval then
            lines[#lines + 1] = '- Use /rrcs_pending regularly to moderate new marketplace listings.'
        end
    end

    lines[#lines + 1] = ('Summary: %s OK / %s WARN / %s FAIL'):format(okCount, warnCount, failCount)
    return lines, { ok = okCount, warn = warnCount, fail = failCount }
end

RegisterCommand((Config.Healthcheck and Config.Healthcheck.command) or (Config.Admin and Config.Admin.healthCommand) or 'rrcs_health', function(src)
    if not hasAdmin(src) then
        TriggerClientEvent('realrpg_clothingstudio:client:notify', src, 'Nincs jogosultságod ehhez a parancshoz.', 'error')
        return
    end
    local lines = RRCSHealth.BuildReport('full')
    printLines(src, lines)
end, false)

RegisterCommand((Config.Healthcheck and Config.Healthcheck.selfTestCommand) or (Config.Admin and Config.Admin.selfTestCommand) or 'rrcs_selftest', function(src)
    if not hasAdmin(src) then
        TriggerClientEvent('realrpg_clothingstudio:client:notify', src, 'Nincs jogosultságod ehhez a parancshoz.', 'error')
        return
    end
    local lines, summary = RRCSHealth.BuildReport('selftest')
    if summary.fail > 0 then
        lines[#lines + 1] = 'SELFTEST_RESULT: FAIL'
    elseif summary.warn > 0 then
        lines[#lines + 1] = 'SELFTEST_RESULT: WARN'
    else
        lines[#lines + 1] = 'SELFTEST_RESULT: OK'
    end
    printLines(src, lines)
end, false)

CreateThread(function()
    Wait(2500)
    if Config.Healthcheck and Config.Healthcheck.autoRunOnResourceStart then
        local lines = RRCSHealth.BuildReport('auto-start')
        print(table.concat(lines, '\n'))
    end
end)
