--[[
    RealRPG Clothing Studio - Database Layer
    All MySQL operations through oxmysql
]]

DB = {}

-- ═══════════════════════════════════════════════════════════════
-- DESIGNS
-- ═══════════════════════════════════════════════════════════════

function DB.SaveDesign(data)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_designs
        (design_id, owner_identifier, owner_name, label, gender, category, template_id, design_json, preview_data, image_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.design_id, data.owner_identifier, data.owner_name, data.label,
        data.gender, data.category, data.template_id, data.design_json,
        data.preview_data, data.image_url
    })
end

function DB.GetDesign(designId)
    return MySQL.single.await('SELECT * FROM realrpg_clothing_designs WHERE design_id = ?', { designId })
end

function DB.GetMyDesigns(identifier)
    return MySQL.query.await([[
        SELECT design_id, label, gender, category, template_id, preview_data, image_url, created_at
        FROM realrpg_clothing_designs
        WHERE owner_identifier = ?
        ORDER BY id DESC LIMIT 80
    ]], { identifier }) or {}
end

function DB.UpdateDesign(designId, data)
    MySQL.update.await([[
        UPDATE realrpg_clothing_designs
        SET label = ?, design_json = ?, preview_data = ?, image_url = ?, updated_at = NOW()
        WHERE design_id = ?
    ]], { data.label, data.design_json, data.preview_data, data.image_url, designId })
end

function DB.DeleteDesign(designId)
    return MySQL.update.await('DELETE FROM realrpg_clothing_designs WHERE design_id = ?', { designId })
end

function DB.GetDesignsByIds(designIds)
    if not designIds or #designIds == 0 then return {} end
    local placeholders = {}
    for i = 1, #designIds do placeholders[i] = '?' end
    local query = ('SELECT * FROM realrpg_clothing_designs WHERE design_id IN (%s)'):format(table.concat(placeholders, ','))
    return MySQL.query.await(query, designIds) or {}
end

-- ═══════════════════════════════════════════════════════════════
-- EQUIPPED
-- ═══════════════════════════════════════════════════════════════

function DB.SetEquipped(identifier, category, designId, metadata)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_equipped (identifier, category, design_id, metadata)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE design_id = VALUES(design_id), metadata = VALUES(metadata)
    ]], { identifier, category, designId, json.encode(metadata) })
end

function DB.GetEquipped(identifier)
    return MySQL.query.await('SELECT * FROM realrpg_clothing_equipped WHERE identifier = ?', { identifier }) or {}
end

function DB.RemoveEquipped(identifier, category)
    return MySQL.update.await('DELETE FROM realrpg_clothing_equipped WHERE identifier = ? AND category = ?', { identifier, category })
end

-- ═══════════════════════════════════════════════════════════════
-- RUNTIME TEXTURE SLOTS
-- ═══════════════════════════════════════════════════════════════

function DB.AllocateSlot(designId, category, slotNum)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_design_slots (design_id, category, runtime_slot)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE category = VALUES(category), runtime_slot = VALUES(runtime_slot)
    ]], { designId, category, slotNum })
end

function DB.FreeSlot(designId)
    return MySQL.update.await('DELETE FROM realrpg_clothing_design_slots WHERE design_id = ?', { designId })
end

function DB.GetAllSlotAllocations()
    return MySQL.query.await('SELECT design_id, category, runtime_slot FROM realrpg_clothing_design_slots') or {}
end

function DB.GetSlotAllocation(designId)
    return MySQL.single.await('SELECT * FROM realrpg_clothing_design_slots WHERE design_id = ?', { designId })
end

-- ═══════════════════════════════════════════════════════════════
-- MARKETPLACE
-- ═══════════════════════════════════════════════════════════════

function DB.CreateMarketplaceListing(data)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_marketplace
        (design_id, owner_identifier, price, status, is_public)
        VALUES (?, ?, ?, ?, ?)
    ]], { data.design_id, data.owner_identifier, data.price, data.status or 'pending', data.is_public and 1 or 0 })
end

function DB.GetMarketplaceListing(designId)
    return MySQL.single.await('SELECT * FROM realrpg_clothing_marketplace WHERE design_id = ?', { designId })
end

function DB.GetPendingMarketplace(limit)
    limit = tonumber(limit) or 25
    return MySQL.query.await([[
        SELECT m.*, d.label, d.gender, d.category, d.owner_name, d.preview_data
        FROM realrpg_clothing_marketplace m
        JOIN realrpg_clothing_designs d ON d.design_id = m.design_id
        WHERE m.status = 'pending'
        ORDER BY m.created_at ASC
        LIMIT ?
    ]], { limit }) or {}
end

function DB.GetPublicMarketplace(limit, offset, category, gender)
    limit = tonumber(limit) or 30
    offset = tonumber(offset) or 0
    local conditions = { "m.status = 'approved'", "m.is_public = 1" }
    local params = {}

    if category and category ~= '' then
        conditions[#conditions + 1] = "d.category = ?"
        params[#params + 1] = category
    end
    if gender and gender ~= '' then
        conditions[#conditions + 1] = "d.gender = ?"
        params[#params + 1] = gender
    end

    params[#params + 1] = limit
    params[#params + 1] = offset

    local query = ([[
        SELECT m.*, d.label, d.gender, d.category, d.owner_name, d.preview_data, d.image_url
        FROM realrpg_clothing_marketplace m
        JOIN realrpg_clothing_designs d ON d.design_id = m.design_id
        WHERE %s
        ORDER BY m.sold_count DESC, m.created_at DESC
        LIMIT ? OFFSET ?
    ]]):format(table.concat(conditions, ' AND '))

    return MySQL.query.await(query, params) or {}
end

function DB.SetMarketplaceStatus(designId, status, isPublic, moderatedBy, reason)
    return MySQL.update.await([[
        UPDATE realrpg_clothing_marketplace
        SET status = ?, is_public = ?, moderated_by = ?, moderation_reason = ?, moderated_at = NOW(), updated_at = NOW()
        WHERE design_id = ?
    ]], { status, isPublic and 1 or 0, moderatedBy, reason, designId })
end

function DB.IncrementSoldCount(designId)
    MySQL.update.await('UPDATE realrpg_clothing_marketplace SET sold_count = sold_count + 1 WHERE design_id = ?', { designId })
end

function DB.RecordSale(data)
    return MySQL.insert.await([[
        INSERT INTO realrpg_clothing_marketplace_sales
        (design_id, seller_identifier, buyer_identifier, buyer_name, price, seller_amount, server_fee)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { data.design_id, data.seller_identifier, data.buyer_identifier, data.buyer_name, data.price, data.seller_amount, data.server_fee })
end

function DB.CreatePayout(identifier, amount, saleId)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_marketplace_payouts (identifier, amount, sale_id, status)
        VALUES (?, ?, ?, 'pending')
    ]], { identifier, amount, saleId })
end

function DB.GetPendingPayouts(identifier)
    return MySQL.query.await([[
        SELECT * FROM realrpg_clothing_marketplace_payouts
        WHERE identifier = ? AND status = 'pending'
        ORDER BY created_at ASC
    ]], { identifier }) or {}
end

function DB.MarkPayoutPaid(payoutId)
    MySQL.update.await([[
        UPDATE realrpg_clothing_marketplace_payouts SET status = 'paid', paid_at = NOW() WHERE id = ?
    ]], { payoutId })
end

-- ═══════════════════════════════════════════════════════════════
-- AUDIT LOG
-- ═══════════════════════════════════════════════════════════════

function DB.InsertAuditLog(data)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_audit_log
        (actor_identifier, actor_name, action, target_identifier, design_id, amount, details)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.actor_identifier, data.actor_name, data.action,
        data.target_identifier, data.design_id, data.amount, data.details
    })
end

function DB.GetAuditLogs(limit)
    limit = math.min(tonumber(limit) or 20, 200)
    return MySQL.query.await([[
        SELECT * FROM realrpg_clothing_audit_log ORDER BY id DESC LIMIT ?
    ]], { limit }) or {}
end

function DB.GetAuditLogsForDesign(designId)
    return MySQL.query.await([[
        SELECT * FROM realrpg_clothing_audit_log WHERE design_id = ? ORDER BY id DESC LIMIT 50
    ]], { designId }) or {}
end

-- ═══════════════════════════════════════════════════════════════
-- HYBRID YTD GENERATION TRACKING
-- ═══════════════════════════════════════════════════════════════

function DB.SaveHybridJob(designId, category, status)
    -- Uses design_slots table with a status field approach
    -- For simplicity we track hybrid status in the slot allocation
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_design_slots (design_id, category, runtime_slot)
        VALUES (?, ?, -1)
        ON DUPLICATE KEY UPDATE category = VALUES(category)
    ]], { designId, category })
end

-- ═══════════════════════════════════════════════════════════════
-- AI HISTORY (for maintenance/purge)
-- ═══════════════════════════════════════════════════════════════

function DB.SaveAiHistory(data)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_ai_history (identifier, prompt, result_url, provider)
        VALUES (?, ?, ?, ?)
    ]], { data.identifier, data.prompt, data.result_url, data.provider })
end

-- ═══════════════════════════════════════════════════════════════
-- STATS / HELPERS
-- ═══════════════════════════════════════════════════════════════

function DB.GetDesignCount(identifier)
    local result = MySQL.single.await('SELECT COUNT(*) AS c FROM realrpg_clothing_designs WHERE owner_identifier = ?', { identifier })
    return tonumber(result and result.c) or 0
end

function DB.GetMarketplaceListingCount(identifier)
    local result = MySQL.single.await("SELECT COUNT(*) AS c FROM realrpg_clothing_marketplace WHERE owner_identifier = ? AND status IN ('pending','approved')", { identifier })
    return tonumber(result and result.c) or 0
end
