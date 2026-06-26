--[[
    RealRPG Clothing Studio - Clothing Pack Export
    
    Allows players/admins to export designs as premade clothing packs.
    Exported packs contain:
    - Design metadata JSON
    - Preview images (base64 or URLs)
    - Generated fxmanifest.lua for standalone resource use
    - Clothing data ready for stream folder deployment
]]

PackExport = PackExport or {}

local exportQueue = {}
local activeExports = {}

local function debugPrint(msg)
    if Config.Debug then print(('[^2RealRPG Pack Export^0] %s'):format(msg)) end
end

local function notify(src, msg, typ)
    TriggerClientEvent('realrpg_clothingstudio:client:notify', src, msg, typ or 'info')
end

-- ═══════════════════════════════════════════════════════════════
-- PACK GENERATION
-- ═══════════════════════════════════════════════════════════════

local function sanitizeFilename(str)
    str = tostring(str or 'unnamed')
    str = str:gsub('[^%w_%-]', '_')
    return str:sub(1, 48):lower()
end

local function generatePackManifest(packData)
    local lines = {
        "fx_version 'cerulean'",
        "game 'gta5'",
        "lua54 'yes'",
        "",
        ("author '%s'"):format(packData.author or 'RealRPG Clothing Studio'),
        ("description 'Clothing Pack: %s - Exported from RealRPG Clothing Studio'"):format(packData.name or 'Custom Pack'),
        ("version '%s'"):format(packData.version or '1.0.0'),
        "",
        "files {",
        "    'stream/**/*'",
        "}",
        "",
        "data_file 'DLC_ITYP_REQUEST' 'stream/**/*.ytyp'",
        "",
    }

    -- Add streaming entries for each design
    if packData.designs and #packData.designs > 0 then
        lines[#lines + 1] = "-- Streamed clothing textures"
        lines[#lines + 1] = "-- Place .ytd files in stream/ folder"
    end

    return table.concat(lines, '\n')
end

local function generateDesignMetadata(design, template)
    return {
        designId = design.design_id,
        label = design.label,
        gender = design.gender,
        category = design.category,
        templateId = design.template_id,
        creator = design.owner_name,
        createdAt = design.created_at,
        isProp = Templates.IsProp(design.category),
        clothing = {
            component = template and template.component or nil,
            prop = template and template.prop or nil,
            drawable = template and template.drawable or nil,
            texture = template and template.texture or nil,
        },
        preview = design.image_url or design.preview_data,
    }
end

local function buildPackData(src, packName, designIds)
    local identifier = ServerFW.GetIdentifier(src)
    local packId = ('pack_%s_%s'):format(os.time(), math.random(1000, 9999))

    local designs = {}
    local errors = {}

    for _, designId in ipairs(designIds) do
        local design = DB.GetDesign(designId)
        if not design then
            errors[#errors + 1] = ('Design nem található: %s'):format(designId)
        else
            -- Permission check: only own designs unless admin
            if design.owner_identifier ~= identifier and not (RRCSAdmin and RRCSAdmin.HasPermission(src)) then
                errors[#errors + 1] = ('Nincs jogod exportálni: %s'):format(designId)
            else
                local template = Templates.Get(design.gender, design.category, design.template_id)
                designs[#designs + 1] = {
                    design = design,
                    template = template,
                    metadata = generateDesignMetadata(design, template),
                }
            end
        end
    end

    return {
        packId = packId,
        name = packName or 'Custom Pack',
        author = ServerFW.GetName(src),
        authorIdentifier = identifier,
        version = '1.0.0',
        designs = designs,
        errors = errors,
        exportedAt = os.date('%Y-%m-%d %H:%M:%S'),
        renderMode = Config.RenderMode,
    }
end

local function generatePackFiles(packData)
    local files = {}

    -- 1) fxmanifest.lua
    if Config.PackExport.generateManifest then
        files['fxmanifest.lua'] = generatePackManifest(packData)
    end

    -- 2) metadata.json
    if Config.PackExport.includeMetadata then
        local metaEntries = {}
        for _, entry in ipairs(packData.designs) do
            metaEntries[#metaEntries + 1] = entry.metadata
        end
        files['metadata.json'] = json.encode({
            packId = packData.packId,
            name = packData.name,
            author = packData.author,
            exportedAt = packData.exportedAt,
            renderMode = packData.renderMode,
            designCount = #packData.designs,
            designs = metaEntries,
        }, { indent = true })
    end

    -- 3) Individual design data files
    for i, entry in ipairs(packData.designs) do
        local safeName = sanitizeFilename(entry.design.label or entry.design.design_id)
        local designFile = ('designs/%s.json'):format(safeName)
        files[designFile] = json.encode({
            designId = entry.design.design_id,
            label = entry.design.label,
            gender = entry.design.gender,
            category = entry.design.category,
            templateId = entry.design.template_id,
            designJson = entry.design.design_json,
            clothing = entry.metadata.clothing,
            isProp = entry.metadata.isProp,
        }, { indent = true })

        -- 4) Preview image reference
        if entry.design.image_url then
            files[('previews/%s.url'):format(safeName)] = entry.design.image_url
        end
    end

    -- 5) stream folder placeholder with README
    files['stream/README.txt'] = table.concat({
        'RealRPG Clothing Studio - Exported Pack',
        '==========================================',
        '',
        'Place your .ytd texture files in this folder.',
        '',
        'For HYBRID mode exports, the YTD files are auto-generated',
        'and will appear here after the first server restart.',
        '',
        'For RUNTIME mode, textures are applied via DUI at runtime',
        'and no YTD files are needed for basic functionality.',
        '',
        ('Pack: %s'):format(packData.name),
        ('Designs: %s'):format(#packData.designs),
        ('Exported: %s'):format(packData.exportedAt),
    }, '\n')

    -- 6) Install instructions
    files['INSTALL.md'] = table.concat({
        '# ' .. (packData.name or 'Clothing Pack'),
        '',
        '## Installation',
        '',
        '1. Place this folder in your server `resources/` directory',
        '2. Add `ensure ' .. sanitizeFilename(packData.name) .. '` to your server.cfg',
        '3. Restart your server',
        '',
        '## Contents',
        '',
        ('- **%d** clothing design(s)'):format(#packData.designs),
        ('- Render Mode: **%s**'):format(packData.renderMode or 'runtime'),
        ('- Exported: %s'):format(packData.exportedAt),
        '',
        '## Designs',
        '',
    }, '\n')

    for _, entry in ipairs(packData.designs) do
        files['INSTALL.md'] = files['INSTALL.md'] .. ('- %s (%s/%s)\n'):format(
            entry.design.label, entry.design.gender, entry.design.category
        )
    end

    return files
end

-- ═══════════════════════════════════════════════════════════════
-- SAVE PACK TO RESOURCE FILES
-- ═══════════════════════════════════════════════════════════════

local function savePackToResource(packData, files)
    local resourceName = GetCurrentResourceName()
    local basePath = Config.PackExport.outputPath or 'exports/'
    local packFolder = basePath .. sanitizeFilename(packData.name) .. '_' .. packData.packId .. '/'

    local savedFiles = {}
    for filename, content in pairs(files) do
        local fullPath = packFolder .. filename
        local ok = SaveResourceFile(resourceName, fullPath, content, #content)
        if ok then
            savedFiles[#savedFiles + 1] = fullPath
        end
    end

    return savedFiles
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════

function PackExport.Export(src, packName, designIds)
    if not Config.PackExport or not Config.PackExport.enabled then
        return false, 'Pack export letiltva.', nil
    end

    if Config.PackExport.requireAdmin and not (RRCSAdmin and RRCSAdmin.HasPermission(src)) then
        return false, 'Admin jogosultság szükséges az exporthoz.', nil
    end

    if #designIds > (Config.PackExport.maxDesignsPerPack or 20) then
        return false, ('Maximum %d design exportálható egyszerre.'):format(Config.PackExport.maxDesignsPerPack or 20), nil
    end

    -- Rate limit check
    if RRCSAdmin and RRCSAdmin.RateLimit then
        if not RRCSAdmin.RateLimit(src, 'pack_export') then
            return false, 'Túl sok export kérés. Várj egy kicsit.', nil
        end
    end

    -- Price check
    if Config.PackExport.price and Config.PackExport.price > 0 then
        local paid = ServerFW.RemoveMoney(src, Config.PackExport.price, 'money')
        if not paid then
            return false, ('Nincs elég pénzed. Ár: $%s'):format(Config.PackExport.price), nil
        end
    end

    -- Build pack
    local packData = buildPackData(src, packName, designIds)

    if #packData.errors > 0 and #packData.designs == 0 then
        return false, table.concat(packData.errors, '\n'), nil
    end

    -- Generate files
    local files = generatePackFiles(packData)

    -- Save to resource
    local savedFiles = savePackToResource(packData, files)

    -- Audit log
    if RRCSAdmin and RRCSAdmin.Audit then
        RRCSAdmin.Audit(src, 'pack_export', {
            design_id = packData.packId,
            details = json.encode({
                name = packData.name,
                designCount = #packData.designs,
                fileCount = #savedFiles,
            })
        })
    end

    debugPrint(('Pack exported: %s (%d designs, %d files)'):format(packData.packId, #packData.designs, #savedFiles))

    return true, nil, {
        packId = packData.packId,
        name = packData.name,
        designCount = #packData.designs,
        fileCount = #savedFiles,
        files = savedFiles,
        errors = packData.errors,
    }
end

-- ═══════════════════════════════════════════════════════════════
-- SERVER EVENTS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:exportPack', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end

    local packName = tostring(payload.name or 'Custom Pack'):sub(1, 64)
    local designIds = payload.designIds

    if type(designIds) ~= 'table' or #designIds == 0 then
        notify(src, 'Válassz legalább egy designt az exporthoz.', 'error')
        return
    end

    local ok, err, result = PackExport.Export(src, packName, designIds)
    if not ok then
        notify(src, err or 'Export sikertelen.', 'error')
        return
    end

    local warnings = ''
    if result.errors and #result.errors > 0 then
        warnings = (' (%d figyelmeztetés)'):format(#result.errors)
    end

    notify(src, ('Pack exportálva: %s - %d design, %d fájl%s'):format(
        result.name, result.designCount, result.fileCount, warnings
    ), 'success')

    TriggerClientEvent('realrpg_clothingstudio:client:packExported', src, {
        packId = result.packId,
        name = result.name,
        designCount = result.designCount,
        fileCount = result.fileCount,
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- ADMIN COMMAND: List exported packs
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('rrcs_packs', function(src)
    if src > 0 and not (RRCSAdmin and RRCSAdmin.HasPermission(src)) then
        notify(src, 'Nincs jogosultságod.', 'error')
        return
    end

    local resourceName = GetCurrentResourceName()
    local basePath = Config.PackExport.outputPath or 'exports/'

    -- We can't list directories in FiveM easily, so just inform
    local msg = ('Pack export mappa: resources/%s/%s'):format(resourceName, basePath)
    if src == 0 then
        print(msg)
    else
        notify(src, msg, 'info')
    end
end, false)
