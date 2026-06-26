--[[
    RealRPG Clothing Studio - Server Main
    Core server logic: open, save, print, equip, delete
    Integrates with RenderEngine for runtime/hybrid texture management
]]

local function notify(src, msg, typ)
    TriggerClientEvent('realrpg_clothingstudio:client:notify', src, msg, typ or 'info')
end

local function canUseStation(src, stationIndex)
    local station = Config.Stations[stationIndex]
    if not station then return false end
    if not station.job then return true end

    local job, grade = ServerFW.GetJob(src)
    return job == station.job and grade >= (station.grade or 0)
end

local function makeDesignId(src)
    return ('rr_%s_%s_%04d'):format(os.time(), src, math.random(1000, 9999))
end

-- ═══════════════════════════════════════════════════════════════
-- OPEN STUDIO
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:requestOpen', function(stationIndex)
    local src = source
    stationIndex = tonumber(stationIndex) or 1

    if not canUseStation(src, stationIndex) then
        notify(src, 'Nincs jogosultságod ehhez a designer station-höz.', 'error')
        return
    end

    local identifier = ServerFW.GetIdentifier(src)
    local designs = DB.GetMyDesigns(identifier)

    -- Send all template data including props
    local allTemplates = Templates.GetAllForNUI and Templates.GetAllForNUI() or Templates.List

    TriggerClientEvent('realrpg_clothingstudio:client:openStudio', src, {
        title = Config.Studio.title,
        accent = Config.Studio.accent,
        templates = allTemplates,
        categories = Templates.Categories,
        myDesigns = designs,
        aiEnabled = Config.AI.enabled,
        maxUploadMB = Config.Studio.maxUploadMB,
        renderMode = Config.RenderMode,
        packExportEnabled = Config.PackExport and Config.PackExport.enabled or false,
        marketplaceEnabled = Config.Marketplace and Config.Marketplace.enabled or false,
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- SAVE DESIGN
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:saveDesign', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end

    -- Rate limit
    if RRCSAdmin and RRCSAdmin.RateLimit and not RRCSAdmin.RateLimit(src, 'save') then
        notify(src, 'Túl gyors mentés. Várj egy kicsit.', 'error')
        return
    end

    -- Validate payload
    if RRCSAdmin and RRCSAdmin.ValidateDesignPayload then
        local valid, err = RRCSAdmin.ValidateDesignPayload(payload)
        if not valid then
            notify(src, err or 'Érvénytelen design adat.', 'error')
            return
        end
    end

    local identifier = ServerFW.GetIdentifier(src)
    local designId = makeDesignId(src)
    local label = tostring(payload.label or 'Untitled Design'):sub(1, 80)
    local gender = tostring(payload.gender or 'male')
    local category = tostring(payload.category or 'tops')
    local templateId = tostring(payload.templateId or '')
    local template = Templates.Get(gender, category, templateId)

    if not template then
        notify(src, 'Érvénytelen ruha sablon.', 'error')
        return
    end

    local designJson = json.encode(payload.design or {})
    local preview = payload.preview
    local imageUrl = payload.imageUrl

    -- Upload preview via bridge if enabled
    if UploadBridge and UploadBridge.IsEnabled and UploadBridge.IsEnabled() and preview and not imageUrl then
        UploadBridge.UploadDataUrl(src, preview, 'design', function(ok, url)
            if ok and url then
                imageUrl = url
            end
        end)
        Wait(3000) -- Give upload time
    end

    DB.SaveDesign({
        design_id = designId,
        owner_identifier = identifier,
        owner_name = ServerFW.GetName(src),
        label = label,
        gender = gender,
        category = category,
        template_id = templateId,
        design_json = designJson,
        preview_data = preview,
        image_url = imageUrl
    })

    -- Audit
    if RRCSAdmin and RRCSAdmin.Audit then
        RRCSAdmin.Audit(src, 'design_save', { design_id = designId })
    end

    notify(src, 'Design elmentve: ' .. label, 'success')
    TriggerClientEvent('realrpg_clothingstudio:client:designSaved', src, {
        design_id = designId,
        label = label,
        gender = gender,
        category = category,
        template_id = templateId,
        preview_data = preview,
        image_url = imageUrl
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- PRINT DESIGN (create wearable item)
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:printDesign', function(payload)
    local src = source
    if not Config.Printing.enabled then
        notify(src, 'Nyomtatás nem elérhető.', 'error')
        return
    end
    if type(payload) ~= 'table' or not payload.designId then return end

    -- Rate limit
    if RRCSAdmin and RRCSAdmin.RateLimit and not RRCSAdmin.RateLimit(src, 'print') then
        notify(src, 'Túl gyors nyomtatás. Várj egy kicsit.', 'error')
        return
    end

    local design = DB.GetDesign(payload.designId)
    if not design then
        notify(src, 'A design nem található.', 'error')
        return
    end

    -- Verify ownership
    local identifier = ServerFW.GetIdentifier(src)
    if design.owner_identifier ~= identifier and not (RRCSAdmin and RRCSAdmin.HasPermission(src)) then
        notify(src, 'Csak saját designt nyomtathatsz.', 'error')
        return
    end

    -- Payment
    local paid = ServerFW.RemoveMoney(src, Config.Printing.price, Config.Printing.account)
    if not paid then
        notify(src, ('Nincs elég pénzed. Ár: $%s'):format(Config.Printing.price), 'error')
        return
    end

    local template = Templates.Get(design.gender, design.category, design.template_id)
    if not template then
        notify(src, 'A design sablonja nem található.', 'error')
        -- Refund
        -- ServerFW.AddMoney would need to be implemented for proper refund
        return
    end

    -- Allocate runtime texture slot
    local runtimeData = nil
    if RenderEngine and RenderEngine.BuildRuntimeData then
        local rtData, rtErr = RenderEngine.BuildRuntimeData(design, template)
        if rtData then
            runtimeData = rtData
        elseif rtErr and Config.RuntimeTextures and Config.RuntimeTextures.requireSlotForPrint then
            notify(src, rtErr, 'error')
            return
        end
    end

    -- Determine if prop
    local isProp = Templates.IsProp(design.category)

    -- Build item metadata
    local metadata = {
        label = design.label,
        description = ('Egyedi RealRPG ruha: %s'):format(design.label),
        designId = design.design_id,
        gender = design.gender,
        category = design.category,
        templateId = design.template_id,
        isProp = isProp,
        component = not isProp and template.component or nil,
        prop = isProp and template.prop or nil,
        drawable = template.drawable,
        texture = template.texture,
        preview = design.preview_data,
        image = design.image_url or design.preview_data,
        creator = design.owner_name,
        createdAt = design.created_at,
        runtime = runtimeData,
    }

    local ok, err = Inv.AddPrintedItem(src, design.category, metadata)
    if not ok then
        notify(src, err or 'Nem sikerült létrehozni az itemet.', 'error')
        return
    end

    -- Queue hybrid YTD generation if enabled
    if RenderEngine and RenderEngine.IsHybrid() and RenderEngine.QueueHybridGeneration then
        RenderEngine.QueueHybridGeneration(design, template, design.preview_data or design.image_url)
    end

    -- Audit
    if RRCSAdmin and RRCSAdmin.Audit then
        RRCSAdmin.Audit(src, 'design_print', {
            design_id = design.design_id,
            amount = Config.Printing.price,
        })
    end

    notify(src, 'A ruhát kinyomtattad és bekerült az inventorydba!', 'success')
end)

-- ═══════════════════════════════════════════════════════════════
-- DELETE DESIGN
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:deleteDesign', function(payload)
    local src = source
    if type(payload) ~= 'table' or not payload.designId then return end

    local design = DB.GetDesign(payload.designId)
    if not design then
        notify(src, 'Design nem található.', 'error')
        return
    end

    local identifier = ServerFW.GetIdentifier(src)
    if design.owner_identifier ~= identifier and not (RRCSAdmin and RRCSAdmin.HasPermission(src)) then
        notify(src, 'Csak saját designt törölhetsz.', 'error')
        return
    end

    -- Free runtime slot if allocated
    if RenderEngine and RenderEngine.FreeSlot then
        RenderEngine.FreeSlot(design.design_id, design.category)
    end

    DB.DeleteDesign(payload.designId)

    if RRCSAdmin and RRCSAdmin.Audit then
        RRCSAdmin.Audit(src, 'design_delete', { design_id = payload.designId })
    end

    notify(src, 'Design törölve.', 'success')
    TriggerClientEvent('realrpg_clothingstudio:client:designDeleted', src, payload.designId)
end)

-- ═══════════════════════════════════════════════════════════════
-- EQUIP / UNEQUIP
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:setEquipped', function(metadata)
    local src = source
    if type(metadata) ~= 'table' or not metadata.designId or not metadata.category then return end
    local identifier = ServerFW.GetIdentifier(src)
    DB.SetEquipped(identifier, metadata.category, metadata.designId, metadata)
    TriggerClientEvent('realrpg_clothingstudio:client:syncWearable', -1, src, metadata)
end)

RegisterNetEvent('realrpg_clothingstudio:server:removeEquipped', function(category)
    local src = source
    if type(category) ~= 'string' then return end
    local identifier = ServerFW.GetIdentifier(src)
    DB.RemoveEquipped(identifier, category)
end)

-- ═══════════════════════════════════════════════════════════════
-- LOAD EQUIPPED ON JOIN
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('realrpg_clothingstudio:server:requestEquipped', function()
    local src = source
    local identifier = ServerFW.GetIdentifier(src)
    local rows = DB.GetEquipped(identifier)
    local equipped = {}

    for _, row in ipairs(rows) do
        local meta = json.decode(row.metadata or '{}')
        if meta and meta.category then
            -- Re-build runtime data for the slot
            if RenderEngine and RenderEngine.GetSlotForDesign and meta.designId then
                local slotData = RenderEngine.GetSlotForDesign(meta.designId, meta.category)
                if slotData then
                    meta.runtime = {
                        mode = Config.RenderMode,
                        slot = slotData.slot,
                        txd = slotData.txd,
                        txn = slotData.txn,
                        width = Config.RuntimeTextures and Config.RuntimeTextures.width or 1024,
                        height = Config.RuntimeTextures and Config.RuntimeTextures.height or 1024,
                        designId = meta.designId,
                        category = meta.category,
                    }
                end
            end
            equipped[meta.category] = meta
        else
            equipped[row.category] = meta
        end
    end

    TriggerClientEvent('realrpg_clothingstudio:client:loadEquipped', src, equipped)
end)

-- ═══════════════════════════════════════════════════════════════
-- PLAYER DROP CLEANUP
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function()
    -- Cleanup handled by upload_bridge and other modules
end)
