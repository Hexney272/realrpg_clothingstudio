DB = {}

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

function DB.SetEquipped(identifier, category, designId, metadata)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_equipped (identifier, category, design_id, metadata)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE design_id = VALUES(design_id), metadata = VALUES(metadata)
    ]], { identifier, category, designId, json.encode(metadata) })
end

function DB.ClearEquipped(identifier, category)
    if category then
        MySQL.update.await('DELETE FROM realrpg_clothing_equipped WHERE identifier = ? AND category = ?', { identifier, category })
    else
        MySQL.update.await('DELETE FROM realrpg_clothing_equipped WHERE identifier = ?', { identifier })
    end
end

function DB.GetEquipped(identifier)
    return MySQL.query.await('SELECT * FROM realrpg_clothing_equipped WHERE identifier = ?', { identifier }) or {}
end

function DB.GetSlotForDesign(designId)
    return MySQL.single.await('SELECT * FROM realrpg_clothing_design_slots WHERE design_id = ?', { designId })
end

function DB.GetUsedSlots(category)
    return MySQL.query.await('SELECT design_id, category, runtime_slot, created_at FROM realrpg_clothing_design_slots WHERE category = ?', { category }) or {}
end

function DB.GetAllUsedSlots()
    return MySQL.query.await('SELECT design_id, category, runtime_slot, created_at FROM realrpg_clothing_design_slots ORDER BY category, runtime_slot') or {}
end

function DB.SetSlotForDesign(designId, category, runtimeSlot)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_design_slots (design_id, category, runtime_slot)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE category = VALUES(category), runtime_slot = VALUES(runtime_slot)
    ]], { designId, category, runtimeSlot })
end

function DB.ReleaseSlotForDesign(designId)
    MySQL.update.await('DELETE FROM realrpg_clothing_design_slots WHERE design_id = ?', { designId })
end


function DB.SaveAIHistory(identifier, playerName, prompt, negativePrompt, resultUrl, error)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_ai_history
        (identifier, player_name, prompt, negative_prompt, result_url, error)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { identifier, playerName, prompt, negativePrompt, resultUrl, error })
end

function DB.GetAIHistory(identifier, limit)
    return MySQL.query.await([[
        SELECT prompt, negative_prompt, result_url, error, created_at
        FROM realrpg_clothing_ai_history
        WHERE identifier = ?
        ORDER BY id DESC LIMIT ?
    ]], { identifier, tonumber(limit) or 20 }) or {}
end


function DB.GetMarketplaceDesignCount(identifier)
    local row = MySQL.single.await([[SELECT COUNT(*) as count FROM realrpg_clothing_marketplace WHERE owner_identifier = ? AND is_public = 1]], { identifier })
    return tonumber(row and row.count) or 0
end

function DB.PublishMarketplaceDesign(designId, identifier, price, status)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_marketplace (design_id, owner_identifier, price, status, is_public)
        VALUES (?, ?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE price = VALUES(price), status = VALUES(status), is_public = 1, updated_at = CURRENT_TIMESTAMP
    ]], { designId, identifier, price, status })
end

function DB.UnpublishMarketplaceDesign(designId, identifier)
    return MySQL.update.await([[
        UPDATE realrpg_clothing_marketplace
        SET is_public = 0, status = 'unpublished', updated_at = CURRENT_TIMESTAMP
        WHERE design_id = ? AND owner_identifier = ?
    ]], { designId, identifier })
end

function DB.GetMarketplace(filters)
    filters = filters or {}
    local params = {}
    local where = { "m.is_public = 1", "m.status = 'approved'" }

    if filters.gender and filters.gender ~= '' then
        where[#where + 1] = 'd.gender = ?'
        params[#params + 1] = filters.gender
    end
    if filters.category and filters.category ~= '' then
        where[#where + 1] = 'd.category = ?'
        params[#params + 1] = filters.category
    end
    if filters.search and filters.search ~= '' then
        where[#where + 1] = '(d.label LIKE ? OR d.owner_name LIKE ? OR d.design_id LIKE ?)'
        local q = '%' .. filters.search .. '%'
        params[#params + 1] = q
        params[#params + 1] = q
        params[#params + 1] = q
    end

    params[#params + 1] = tonumber(filters.limit) or (Config.Marketplace and Config.Marketplace.listingLimit) or 100

    return MySQL.query.await(([[
        SELECT
            m.design_id, m.price, m.status, m.sold_count, m.created_at, m.updated_at,
            d.owner_identifier, d.owner_name, d.label, d.gender, d.category, d.template_id, d.preview_data, d.image_url
        FROM realrpg_clothing_marketplace m
        INNER JOIN realrpg_clothing_designs d ON d.design_id = m.design_id
        WHERE %s
        ORDER BY m.updated_at DESC
        LIMIT ?
    ]]):format(table.concat(where, ' AND ')), params) or {}
end

function DB.GetMarketplaceListing(designId)
    return MySQL.single.await([[
        SELECT
            m.design_id, m.price, m.status, m.is_public, m.sold_count,
            d.owner_identifier, d.owner_name, d.label, d.gender, d.category, d.template_id, d.preview_data, d.image_url, d.design_json, d.created_at
        FROM realrpg_clothing_marketplace m
        INNER JOIN realrpg_clothing_designs d ON d.design_id = m.design_id
        WHERE m.design_id = ?
    ]], { designId })
end

function DB.IncrementMarketplaceSold(designId)
    MySQL.update.await('UPDATE realrpg_clothing_marketplace SET sold_count = sold_count + 1, updated_at = CURRENT_TIMESTAMP WHERE design_id = ?', { designId })
end

function DB.LogMarketplaceSale(data)
    return MySQL.insert.await([[
        INSERT INTO realrpg_clothing_marketplace_sales
        (design_id, seller_identifier, buyer_identifier, buyer_name, price, seller_amount, server_fee)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { data.design_id, data.seller_identifier, data.buyer_identifier, data.buyer_name, data.price, data.seller_amount, data.server_fee })
end

function DB.AddMarketplacePayout(identifier, amount, saleId)
    if tonumber(amount) <= 0 then return end
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_marketplace_payouts (identifier, amount, sale_id, status)
        VALUES (?, ?, ?, 'pending')
    ]], { identifier, amount, saleId })
end

function DB.GetPendingMarketplacePayouts(identifier)
    return MySQL.query.await([[
        SELECT id, amount, sale_id, created_at
        FROM realrpg_clothing_marketplace_payouts
        WHERE identifier = ? AND status = 'pending'
        ORDER BY id ASC LIMIT 50
    ]], { identifier }) or {}
end

function DB.MarkMarketplacePayoutsPaid(ids)
    if not ids or #ids == 0 then return 0 end
    local placeholders = {}
    local params = {}
    for _, id in ipairs(ids) do
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = id
    end
    return MySQL.update.await(('UPDATE realrpg_clothing_marketplace_payouts SET status = \'paid\', paid_at = CURRENT_TIMESTAMP WHERE id IN (%s)'):format(table.concat(placeholders, ',')), params)
end

-- v1.0 admin / audit helpers
function DB.GetPendingMarketplace(limit)
    return MySQL.query.await([[
        SELECT
            m.design_id, m.price, m.status, m.is_public, m.sold_count, m.created_at, m.updated_at,
            d.owner_identifier, d.owner_name, d.label, d.gender, d.category, d.template_id, d.preview_data, d.image_url
        FROM realrpg_clothing_marketplace m
        INNER JOIN realrpg_clothing_designs d ON d.design_id = m.design_id
        WHERE m.status = 'pending' AND m.is_public = 1
        ORDER BY m.created_at ASC
        LIMIT ?
    ]], { tonumber(limit) or 25 }) or {}
end

function DB.SetMarketplaceStatus(designId, status, isPublic, moderatorIdentifier, reason)
    return MySQL.update.await([[
        UPDATE realrpg_clothing_marketplace
        SET status = ?, is_public = ?, moderated_by = ?, moderation_reason = ?, moderated_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE design_id = ?
    ]], { status, isPublic and 1 or 0, moderatorIdentifier, reason, designId })
end

function DB.InsertAuditLog(data)
    return MySQL.insert.await([[
        INSERT INTO realrpg_clothing_audit_log
        (actor_identifier, actor_name, action, target_identifier, design_id, amount, details)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.actor_identifier,
        data.actor_name,
        data.action,
        data.target_identifier,
        data.design_id,
        data.amount,
        data.details
    })
end

function DB.GetAuditLogs(limit)
    return MySQL.query.await([[
        SELECT id, actor_identifier, actor_name, action, target_identifier, design_id, amount, details, created_at
        FROM realrpg_clothing_audit_log
        ORDER BY id DESC LIMIT ?
    ]], { tonumber(limit) or 20 }) or {}
end
