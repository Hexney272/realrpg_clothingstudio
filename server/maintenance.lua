RRCSMaintenance = RRCSMaintenance or {}

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
        notify(src, 'Maintenance riport kiírva az F8 konzolba.', 'info')
    end
end

local function hasAdmin(src)
    if RRCSAdmin and RRCSAdmin.HasPermission then return RRCSAdmin.HasPermission(src) end
    if src == 0 then return true end
    local ace = Config.Admin and Config.Admin.permission
    return ace and ace ~= '' and IsPlayerAceAllowed(src, ace)
end

local function scalar(query, params)
    local ok, result = pcall(function()
        return MySQL.single.await(query, params or {})
    end)
    if not ok then return nil, result end
    return tonumber(result and (result.c or result.count or result.total)) or 0
end

local function rows(query, params)
    local ok, result = pcall(function()
        return MySQL.query.await(query, params or {})
    end)
    if not ok then return nil, result end
    return result or {}
end

local function update(query, params)
    local ok, result = pcall(function()
        return MySQL.update.await(query, params or {})
    end)
    if not ok then return nil, result end
    return tonumber(result) or 0
end

local function getPurgeDays(key, fallback)
    return tonumber(Config.Maintenance and Config.Maintenance[key]) or fallback
end

function RRCSMaintenance.BuildReport()
    local lines = {}
    lines[#lines + 1] = 'RealRPG Clothing Studio v1.2 Maintenance Report'
    lines[#lines + 1] = ('Resource: %s'):format(GetCurrentResourceName())

    local orphanSlots = scalar([[
        SELECT COUNT(*) AS c
        FROM realrpg_clothing_design_slots s
        LEFT JOIN realrpg_clothing_designs d ON d.design_id = s.design_id
        WHERE d.design_id IS NULL
    ]])
    if orphanSlots == nil then orphanSlots = 'query_error' end
    lines[#lines + 1] = ('Orphan runtime slots: %s'):format(orphanSlots)

    local staleEquipped = scalar([[
        SELECT COUNT(*) AS c
        FROM realrpg_clothing_equipped e
        LEFT JOIN realrpg_clothing_designs d ON d.design_id = e.design_id
        WHERE d.design_id IS NULL
    ]])
    if staleEquipped == nil then staleEquipped = 'query_error' end
    lines[#lines + 1] = ('Stale equipped rows: %s'):format(staleEquipped)

    local largePreview = 0
    local largeJson = 0
    if Config.Maintenance and Config.Maintenance.includeLargeBase64Report then
        largePreview = scalar('SELECT COUNT(*) AS c FROM realrpg_clothing_designs WHERE CHAR_LENGTH(preview_data) > ?', { Config.Maintenance.largePreviewWarnBytes or 900000 }) or 'query_error'
        largeJson = scalar('SELECT COUNT(*) AS c FROM realrpg_clothing_designs WHERE CHAR_LENGTH(design_json) > ?', { Config.Maintenance.largeDesignJsonWarnBytes or 900000 }) or 'query_error'
    end
    lines[#lines + 1] = ('Large preview_data rows: %s'):format(largePreview)
    lines[#lines + 1] = ('Large design_json rows: %s'):format(largeJson)

    local aiDays = getPurgeDays('purgeAiHistoryDays', 30)
    local auditDays = getPurgeDays('purgeAuditLogDays', 90)
    local rejectedDays = getPurgeDays('purgeRejectedMarketplaceDays', 30)
    local unpublishedDays = getPurgeDays('purgeUnpublishedMarketplaceDays', 60)

    lines[#lines + 1] = ('Old AI history > %s days: %s'):format(aiDays, scalar('SELECT COUNT(*) AS c FROM realrpg_clothing_ai_history WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { aiDays }) or 'query_error')
    lines[#lines + 1] = ('Old audit logs > %s days: %s'):format(auditDays, scalar('SELECT COUNT(*) AS c FROM realrpg_clothing_audit_log WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { auditDays }) or 'query_error')
    lines[#lines + 1] = ('Old rejected listings > %s days: %s'):format(rejectedDays, scalar("SELECT COUNT(*) AS c FROM realrpg_clothing_marketplace WHERE status = 'rejected' AND updated_at < DATE_SUB(NOW(), INTERVAL ? DAY)", { rejectedDays }) or 'query_error')
    lines[#lines + 1] = ('Old unpublished listings > %s days: %s'):format(unpublishedDays, scalar("SELECT COUNT(*) AS c FROM realrpg_clothing_marketplace WHERE status = 'unpublished' AND updated_at < DATE_SUB(NOW(), INTERVAL ? DAY)", { unpublishedDays }) or 'query_error')

    local pendingPayoutCount = scalar("SELECT COUNT(*) AS c FROM realrpg_clothing_marketplace_payouts WHERE status = 'pending'") or 'query_error'
    local pendingPayoutTotal = scalar("SELECT COALESCE(SUM(amount), 0) AS total FROM realrpg_clothing_marketplace_payouts WHERE status = 'pending'") or 'query_error'
    lines[#lines + 1] = ('Pending marketplace payouts: %s rows / $%s'):format(pendingPayoutCount, pendingPayoutTotal)

    local newestAudit = rows('SELECT action, actor_name, design_id, created_at FROM realrpg_clothing_audit_log ORDER BY id DESC LIMIT 5')
    if type(newestAudit) == 'table' and #newestAudit > 0 then
        lines[#lines + 1] = 'Recent audit actions:'
        for _, row in ipairs(newestAudit) do
            lines[#lines + 1] = ('  %s | %s | %s | %s'):format(row.created_at or '?', row.action or '?', row.actor_name or '-', row.design_id or '-')
        end
    end

    lines[#lines + 1] = 'Maintenance commands:'
    lines[#lines + 1] = ('  /%s'):format((Config.Admin and Config.Admin.cleanupOrphansCommand) or (Config.Maintenance and Config.Maintenance.cleanupCommand) or 'rrcs_cleanup_orphans')
    lines[#lines + 1] = ('  /%s [days] %s'):format((Config.Admin and Config.Admin.purgeHistoryCommand) or (Config.Maintenance and Config.Maintenance.purgeCommand) or 'rrcs_purgehistory', (Config.Maintenance and Config.Maintenance.requireConfirmWord) or 'CONFIRM')
    lines[#lines + 1] = 'Use CONFIRM for destructive cleanup. Without it, commands run dry-run only.'

    return lines
end

function RRCSMaintenance.CleanupOrphans(confirm)
    local dryRun = confirm ~= ((Config.Maintenance and Config.Maintenance.requireConfirmWord) or 'CONFIRM')
    local lines = { 'RealRPG Clothing Studio orphan cleanup', dryRun and 'Mode: DRY-RUN' or 'Mode: CONFIRMED' }

    local slotCount = scalar([[
        SELECT COUNT(*) AS c
        FROM realrpg_clothing_design_slots s
        LEFT JOIN realrpg_clothing_designs d ON d.design_id = s.design_id
        WHERE d.design_id IS NULL
    ]]) or 0
    local equippedCount = scalar([[
        SELECT COUNT(*) AS c
        FROM realrpg_clothing_equipped e
        LEFT JOIN realrpg_clothing_designs d ON d.design_id = e.design_id
        WHERE d.design_id IS NULL
    ]]) or 0

    lines[#lines + 1] = ('Would remove orphan slots: %s'):format(slotCount)
    lines[#lines + 1] = ('Would remove stale equipped rows: %s'):format(equippedCount)

    if not dryRun then
        local removedSlots = update([[
            DELETE s FROM realrpg_clothing_design_slots s
            LEFT JOIN realrpg_clothing_designs d ON d.design_id = s.design_id
            WHERE d.design_id IS NULL
        ]]) or 0
        local removedEquipped = update([[
            DELETE e FROM realrpg_clothing_equipped e
            LEFT JOIN realrpg_clothing_designs d ON d.design_id = e.design_id
            WHERE d.design_id IS NULL
        ]]) or 0
        lines[#lines + 1] = ('Removed orphan slots: %s'):format(removedSlots)
        lines[#lines + 1] = ('Removed stale equipped rows: %s'):format(removedEquipped)

        if RRCSAdmin and RRCSAdmin.Audit then
            RRCSAdmin.Audit(0, 'maintenance_cleanup_orphans', { details = json.encode({ slots = removedSlots, equipped = removedEquipped }) })
        end
    end

    return lines
end

function RRCSMaintenance.PurgeHistory(days, confirm)
    days = tonumber(days) or getPurgeDays('purgeAiHistoryDays', 30)
    if days < 1 then days = 1 end

    local dryRun = confirm ~= ((Config.Maintenance and Config.Maintenance.requireConfirmWord) or 'CONFIRM')
    local lines = { 'RealRPG Clothing Studio history purge', dryRun and 'Mode: DRY-RUN' or 'Mode: CONFIRMED', ('Days: %s'):format(days) }

    local counts = {
        ai = scalar('SELECT COUNT(*) AS c FROM realrpg_clothing_ai_history WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { days }) or 0,
        audit = scalar('SELECT COUNT(*) AS c FROM realrpg_clothing_audit_log WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { days }) or 0,
        rejected = scalar("SELECT COUNT(*) AS c FROM realrpg_clothing_marketplace WHERE status = 'rejected' AND updated_at < DATE_SUB(NOW(), INTERVAL ? DAY)", { days }) or 0,
        unpublished = scalar("SELECT COUNT(*) AS c FROM realrpg_clothing_marketplace WHERE status = 'unpublished' AND updated_at < DATE_SUB(NOW(), INTERVAL ? DAY)", { days }) or 0
    }

    lines[#lines + 1] = ('Would purge AI history: %s'):format(counts.ai)
    lines[#lines + 1] = ('Would purge audit logs: %s'):format(counts.audit)
    lines[#lines + 1] = ('Would purge rejected marketplace rows: %s'):format(counts.rejected)
    lines[#lines + 1] = ('Would purge unpublished marketplace rows: %s'):format(counts.unpublished)

    if not dryRun then
        local deletedAi = update('DELETE FROM realrpg_clothing_ai_history WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { days }) or 0
        local deletedAudit = update('DELETE FROM realrpg_clothing_audit_log WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { days }) or 0
        local deletedRejected = update("DELETE FROM realrpg_clothing_marketplace WHERE status = 'rejected' AND updated_at < DATE_SUB(NOW(), INTERVAL ? DAY)", { days }) or 0
        local deletedUnpublished = update("DELETE FROM realrpg_clothing_marketplace WHERE status = 'unpublished' AND updated_at < DATE_SUB(NOW(), INTERVAL ? DAY)", { days }) or 0

        lines[#lines + 1] = ('Purged AI history: %s'):format(deletedAi)
        lines[#lines + 1] = ('Purged audit logs: %s'):format(deletedAudit)
        lines[#lines + 1] = ('Purged rejected marketplace rows: %s'):format(deletedRejected)
        lines[#lines + 1] = ('Purged unpublished marketplace rows: %s'):format(deletedUnpublished)
    end

    return lines
end

RegisterCommand((Config.Admin and Config.Admin.maintenanceCommand) or (Config.Maintenance and Config.Maintenance.command) or 'rrcs_maintcheck', function(src)
    if not hasAdmin(src) then
        notify(src, 'Nincs jogosultságod ehhez a parancshoz.', 'error')
        return
    end
    printLines(src, RRCSMaintenance.BuildReport())
end, false)

RegisterCommand((Config.Admin and Config.Admin.cleanupOrphansCommand) or (Config.Maintenance and Config.Maintenance.cleanupCommand) or 'rrcs_cleanup_orphans', function(src, args)
    if not hasAdmin(src) then
        notify(src, 'Nincs jogosultságod ehhez a parancshoz.', 'error')
        return
    end
    printLines(src, RRCSMaintenance.CleanupOrphans(args and args[1]))
end, false)

RegisterCommand((Config.Admin and Config.Admin.purgeHistoryCommand) or (Config.Maintenance and Config.Maintenance.purgeCommand) or 'rrcs_purgehistory', function(src, args)
    if not hasAdmin(src) then
        notify(src, 'Nincs jogosultságod ehhez a parancshoz.', 'error')
        return
    end
    printLines(src, RRCSMaintenance.PurgeHistory(args and args[1], args and args[2]))
end, false)
