RRCSAdmin = RRCSAdmin or {}


local rateBuckets = {}

function RRCSAdmin.RateLimit(src, key)
    local cfg = Config.Security and Config.Security.rateLimits and Config.Security.rateLimits[key]
    if not cfg or src == 0 then return true end
    local now = os.time()
    local bucketKey = ('%s:%s'):format(src, key)
    local bucket = rateBuckets[bucketKey]
    if not bucket or now - bucket.start >= (tonumber(cfg.windowSeconds) or 10) then
        rateBuckets[bucketKey] = { start = now, count = 1 }
        return true
    end
    bucket.count = bucket.count + 1
    return bucket.count <= (tonumber(cfg.max) or 5)
end

function RRCSAdmin.ValidateDesignPayload(payload)
    if type(payload) ~= 'table' then return false, 'Érvénytelen payload.' end
    local encoded = json.encode(payload.design or {})
    if Config.Security and Config.Security.maxDesignJsonBytes and #encoded > Config.Security.maxDesignJsonBytes then
        return false, 'Túl nagy a design JSON. Töltsd CDN-re a layer asseteket.'
    end
    if Config.Security and Config.Security.maxPreviewBytes and payload.preview and #tostring(payload.preview) > Config.Security.maxPreviewBytes then
        return false, 'Túl nagy a preview kép.'
    end
    local layers = payload.design and payload.design.layers
    if type(layers) == 'table' and Config.Security and Config.Security.maxLayersPerDesign and #layers > Config.Security.maxLayersPerDesign then
        return false, ('Túl sok layer. Maximum: %s'):format(Config.Security.maxLayersPerDesign)
    end
    return true, nil
end

local function asNumber(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    return value
end

local function notify(src, msg, typ)
    if src == 0 then
        print(('[RealRPG Clothing Studio] %s'):format(msg))
    else
        TriggerClientEvent('realrpg_clothingstudio:client:notify', src, msg, typ or 'info')
    end
end

local function printLines(src, lines)
    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        TriggerClientEvent('realrpg_clothingstudio:client:printLines', src, lines)
        notify(src, 'Admin riport kiírva az F8 konzolba.', 'info')
    end
end

function RRCSAdmin.HasPermission(src)
    if src == 0 then return true end

    local ace = Config.Admin and Config.Admin.permission
    if ace and ace ~= '' and IsPlayerAceAllowed(src, ace) then
        return true
    end

    local allowedJobs = Config.Admin and Config.Admin.allowedJobs
    if allowedJobs then
        local job, grade = ServerFW.GetJob(src)
        local minGrade = job and allowedJobs[job]
        if minGrade ~= nil and grade >= tonumber(minGrade) then return true end
    end

    return false
end

local function sendAuditWebhook(data)
    if not Config.Audit or not Config.Audit.enabled then return end
    local webhook = Config.Audit.discordWebhook
    if not webhook or webhook == '' then return end

    local payload = {
        username = 'RealRPG Clothing Studio',
        embeds = {
            {
                title = data.action or 'Audit',
                color = 14286592,
                fields = {
                    { name = 'Actor', value = tostring(data.actor_name or data.actor_identifier or 'system'), inline = true },
                    { name = 'Target', value = tostring(data.target_identifier or data.design_id or '-'), inline = true },
                    { name = 'Amount', value = tostring(data.amount or '-'), inline = true },
                    { name = 'Details', value = tostring(data.details or '-'):sub(1, 950), inline = false }
                },
                footer = { text = 'realrpg_clothingstudio v1.0' }
            }
        }
    }

    PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

function RRCSAdmin.Audit(src, action, data)
    if not Config.Audit or not Config.Audit.enabled then return end
    data = data or {}
    local actorIdentifier = src and src > 0 and ServerFW.GetIdentifier(src) or (data.actor_identifier or 'console')
    local actorName = src and src > 0 and ServerFW.GetName(src) or (data.actor_name or 'Console')

    local row = {
        actor_identifier = actorIdentifier,
        actor_name = actorName,
        action = tostring(action or 'unknown'):sub(1, 80),
        target_identifier = data.target_identifier,
        design_id = data.design_id,
        amount = data.amount,
        details = type(data.details) == 'table' and json.encode(data.details) or data.details
    }

    if DB and DB.InsertAuditLog then
        DB.InsertAuditLog(row)
    end
    sendAuditWebhook(row)
end

local function requireAdmin(src)
    if RRCSAdmin.HasPermission(src) then return true end
    notify(src, 'Nincs admin jogosultságod a Clothing Studio kezeléséhez.', 'error')
    return false
end

RegisterCommand(Config.Admin.adminCheckCommand or 'rrcs_admincheck', function(src)
    local lines = {
        'RealRPG Clothing Studio admin check',
        ('Admin permission: %s'):format(Config.Admin and Config.Admin.permission or 'nil'),
        ('Has permission: %s'):format(tostring(RRCSAdmin.HasPermission(src))),
        ('Audit enabled: %s'):format(Config.Audit and tostring(Config.Audit.enabled) or 'false'),
        ('Audit webhook set: %s'):format((Config.Audit and Config.Audit.discordWebhook and Config.Audit.discordWebhook ~= '') and 'yes' or 'no'),
        ('Marketplace approval required: %s'):format(Config.Marketplace and tostring(Config.Marketplace.requireApproval) or 'false')
    }
    printLines(src, lines)
end, false)

RegisterCommand(Config.Admin.pendingCommand or 'rrcs_pending', function(src, args)
    if not requireAdmin(src) then return end
    local limit = asNumber(args and args[1], 25)
    local rows = DB.GetPendingMarketplace(limit)
    local lines = { ('RealRPG pending marketplace listings: %s'):format(#rows) }

    for _, row in ipairs(rows) do
        lines[#lines + 1] = ('%s | %s | %s | %s/%s | $%s | owner=%s'):format(
            row.design_id, row.status, row.label, row.gender, row.category, row.price, row.owner_name or row.owner_identifier
        )
    end

    RRCSAdmin.Audit(src, 'admin_pending_list', { details = { count = #rows } })
    printLines(src, lines)
end, false)

RegisterCommand(Config.Admin.approveCommand or 'rrcs_approve', function(src, args)
    if not requireAdmin(src) then return end
    local designId = args and args[1]
    if not designId then
        notify(src, 'Használat: /rrcs_approve designId', 'error')
        return
    end

    local changed = DB.SetMarketplaceStatus(designId, 'approved', true, src > 0 and ServerFW.GetIdentifier(src) or 'console', nil)
    if changed and changed > 0 then
        notify(src, ('Marketplace design jóváhagyva: %s'):format(designId), 'success')
        RRCSAdmin.Audit(src, 'marketplace_approve', { design_id = designId })
    else
        notify(src, 'Nem találtam ilyen marketplace listinget.', 'error')
    end
end, false)

RegisterCommand(Config.Admin.rejectCommand or 'rrcs_reject', function(src, args)
    if not requireAdmin(src) then return end
    local designId = args and args[1]
    if not designId then
        notify(src, 'Használat: /rrcs_reject designId indok', 'error')
        return
    end
    local reason = table.concat(args or {}, ' ', 2)
    if reason == '' then reason = 'Admin rejected' end

    local changed = DB.SetMarketplaceStatus(designId, 'rejected', false, src > 0 and ServerFW.GetIdentifier(src) or 'console', reason)
    if changed and changed > 0 then
        notify(src, ('Marketplace design elutasítva: %s'):format(designId), 'success')
        RRCSAdmin.Audit(src, 'marketplace_reject', { design_id = designId, details = reason })
    else
        notify(src, 'Nem találtam ilyen marketplace listinget.', 'error')
    end
end, false)

RegisterCommand(Config.Admin.takedownCommand or 'rrcs_takedown', function(src, args)
    if not requireAdmin(src) then return end
    local designId = args and args[1]
    if not designId then
        notify(src, 'Használat: /rrcs_takedown designId indok', 'error')
        return
    end
    local reason = table.concat(args or {}, ' ', 2)
    if reason == '' then reason = 'Admin takedown' end

    local changed = DB.SetMarketplaceStatus(designId, 'unpublished', false, src > 0 and ServerFW.GetIdentifier(src) or 'console', reason)
    if changed and changed > 0 then
        notify(src, ('Marketplace design levéve: %s'):format(designId), 'success')
        RRCSAdmin.Audit(src, 'marketplace_takedown', { design_id = designId, details = reason })
    else
        notify(src, 'Nem találtam ilyen marketplace listinget.', 'error')
    end
end, false)

RegisterCommand(Config.Admin.auditCommand or 'rrcs_audit', function(src, args)
    if not requireAdmin(src) then return end
    local limit = math.min(asNumber(args and args[1], 20), 100)
    local rows = DB.GetAuditLogs(limit)
    local lines = { ('RealRPG Clothing Studio audit log last %s'):format(#rows) }

    for _, row in ipairs(rows) do
        lines[#lines + 1] = ('#%s | %s | %s | design=%s | amount=%s | %s'):format(
            row.id, row.created_at, row.action, row.design_id or '-', row.amount or '-', tostring(row.details or '-'):sub(1, 80)
        )
    end

    printLines(src, lines)
end, false)
