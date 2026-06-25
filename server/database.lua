DB = {}

function DB.SaveDesign(data)
    MySQL.insert.await([[
        INSERT INTO realrpg_clothing_designs
        (design_id, owner_identifier, owner_name, label, gender, category, template_id, garment_id, design_json, preview_data, image_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.design_id, data.owner_identifier, data.owner_name, data.label,
        data.gender, data.category, data.template_id, data.garment_id or '',
        data.design_json, data.preview_data, data.image_url
    })
end

function DB.GetDesign(designId)
    return MySQL.single.await('SELECT * FROM realrpg_clothing_designs WHERE design_id = ?', { designId })
end

function DB.GetMyDesigns(identifier)
    return MySQL.query.await([[
        SELECT design_id, label, gender, category, template_id, garment_id, preview_data, image_url, created_at
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

function DB.RemoveEquipped(identifier, category)
    MySQL.query.await([[
        DELETE FROM realrpg_clothing_equipped WHERE identifier = ? AND category = ?
    ]], { identifier, category })
end

function DB.GetEquipped(identifier)
    return MySQL.query.await('SELECT * FROM realrpg_clothing_equipped WHERE identifier = ?', { identifier }) or {}
end
