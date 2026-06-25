local onlineEquipped = {}

local function notify(src, msg, typ)
    TriggerClientEvent('realrpg_clothingstudio:client:notify', src, msg, typ or 'info')
end

local function rateLimit(src, key)
    if RRCSAdmin and RRCSAdmin.RateLimit and not RRCSAdmin.RateLimit(src, key) then
        notify(src, 'Túl gyorsan használod ezt a funkciót, várj egy kicsit.', 'error')
        return false
    end
    return true
end

local function audit(src, action, data)
    if RRCSAdmin and RRCSAdmin.Audit then
        RRCSAdmin.Audit(src, action, data or {})
    end
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

local function getRuntimeSlot(category, preferred)
    local slots = Config.RuntimeTextures and Config.RuntimeTextures.slots and Config.RuntimeTextures.slots[category]
    if not slots or #slots == 0 then return nil end

    if preferred then
        for _, slot in ipairs(slots) do
            if tonumber(slot.slot) == tonumber(preferred) then return slot end
        end
    end

    return slots[1]
end

local function ensureRuntimeSlot(design)
    if not Config.RuntimeTextures or not Config.RuntimeTextures.enabled then return nil, 'disabled' end

    local existing = DB.GetSlotForDesign(design.design_id)
    if existing and existing.runtime_slot then
        local slot = getRuntimeSlot(design.category, existing.runtime_slot)
        if slot then return slot end
    end

    local slots = Config.RuntimeTextures.slots and Config.RuntimeTextures.slots[design.category]
    if not slots or #slots == 0 then return nil, 'no_slots_for_category' end

    local usedRows = DB.GetUsedSlots(design.category)
    local used = {}
    for _, row in ipairs(usedRows) do
        used[tonumber(row.runtime_slot)] = true
    end

    local template = Templates.Get(design.gender, design.category, design.template_id)
    local preferred = template and tonumber(template.runtimeSlot) or nil
    local chosen = nil

    if preferred and not used[preferred] then
        chosen = getRuntimeSlot(design.category, preferred)
    end

    if not chosen then
        for _, slot in ipairs(slots) do
            if not used[tonumber(slot.slot)] then
                chosen = slot
                break
            end
        end
    end

    if not chosen and Config.RuntimeTextures.allowSlotReuseWhenFull then
        chosen = slots[1]
    end

    if not chosen then
        return nil, 'pool_full'
    end

    DB.SetSlotForDesign(design.design_id, design.category, chosen.slot)
    return chosen
end


local function buildPrintedMetadata(design, template, runtimeSlot)
    local component = runtimeSlot and runtimeSlot.component or template.component
    local drawable = runtimeSlot and runtimeSlot.drawable or template.drawable
    local texture = runtimeSlot and runtimeSlot.texture or template.texture

    return {
        label = design.label,
        description = ('Egyedi RealRPG ruha: %s'):format(design.label),
        designId = design.design_id,
        gender = design.gender,
        category = design.category,
        templateId = design.template_id,
        component = component,
        drawable = drawable,
        texture = texture,
        runtime = runtimeSlot and {
            slot = runtimeSlot.slot,
            txd = runtimeSlot.txd,
            txn = runtimeSlot.txn,
            width = Config.RuntimeTextures.width,
            height = Config.RuntimeTextures.height
        } or nil,
        preview = design.preview_data,
        image = design.preview_data,
        imageUrl = design.image_url,
        creator = design.owner_name,
        createdAt = design.created_at
    }
end

local function createPrintedItemFromDesign(src, design)
    local template = Templates.Get(design.gender, design.category, design.template_id)
    if not template then
        return false, 'A design sablonja nem található.'
    end

    local runtimeSlot, slotError = ensureRuntimeSlot(design)
    if Config.RuntimeTextures and Config.RuntimeTextures.enabled and Config.RuntimeTextures.requireSlotForPrint and not runtimeSlot then
        if slotError == 'pool_full' then
            return false, 'Beteltek a runtime ruha slotok ennél a kategóriánál. Adj hozzá több blank garment slotot a configban.'
        end
        return false, 'Ehhez a kategóriához nincs érvényes runtime slot konfigurálva.'
    end

    local metadata = buildPrintedMetadata(design, template, runtimeSlot)
    local ok, err = Inv.AddPrintedItem(src, design.category, metadata)
    if not ok then return false, err or 'Nem sikerült létrehozni az itemet.' end
    return true, metadata
end

local function decodeEquippedRows(rows)
    local equipped = {}
    for _, row in ipairs(rows or {}) do
        equipped[row.category] = json.decode(row.metadata or '{}')
    end
    return equipped
end

local function broadcastEquippedOf(src)
    local data = onlineEquipped[src]
    if not data then return end
    for _, metadata in pairs(data) do
        TriggerClientEvent('realrpg_clothingstudio:client:syncWearable', -1, src, metadata)
    end
end

local function sendOnlineSnapshotTo(src)
    for serverId, categories in pairs(onlineEquipped) do
        if serverId ~= src then
            for _, metadata in pairs(categories) do
                TriggerClientEvent('realrpg_clothingstudio:client:syncWearable', src, serverId, metadata)
            end
        end
    end
end

local function openStudioFor(src, stationIndex)
    if not canUseStation(src, stationIndex) then
        notify(src, 'Nincs jogosultságod ehhez a designer station-höz.', 'error')
        return false
    end

    local identifier = ServerFW.GetIdentifier(src)
    local designs = DB.GetMyDesigns(identifier)
    local marketplace = {}
    if Config.Marketplace and Config.Marketplace.enabled then
        marketplace = DB.GetMarketplace({ gender = nil, category = nil, limit = Config.Marketplace.listingLimit })
    end

    TriggerClientEvent('realrpg_clothingstudio:client:openStudio', src, {
        title = Config.Studio.title,
        accent = Config.Studio.accent,
        templates = Templates.List,
        myDesigns = designs,
        marketplace = marketplace,
        marketplaceEnabled = Config.Marketplace and Config.Marketplace.enabled or false,
        aiEnabled = Config.AI.enabled,
        ai = {
            enabled = Config.AI.enabled,
            cooldownSeconds = Config.AI.cooldownSeconds,
            maxPromptLength = Config.AI.maxPromptLength,
            addGeneratedImageAsLayer = Config.AI.addGeneratedImageAsLayer
        },
        maxUploadMB = Config.Studio.maxUploadMB,
        uploadBridge = {
            enabled = UploadBridge and UploadBridge.IsEnabled and UploadBridge.IsEnabled() or false,
            chunkSize = Config.UploadBridge and Config.UploadBridge.chunkSize or 240000,
            failSaveIfUploadFails = Config.UploadBridge and Config.UploadBridge.failSaveIfUploadFails or false,
            uploadLayerAssets = Config.UploadBridge and Config.UploadBridge.uploadLayerAssets or false,
            failLayerUploadIfUploadFails = Config.UploadBridge and Config.UploadBridge.failLayerUploadIfUploadFails or false
        }
    })

    return true
end

RegisterNetEvent('realrpg_clothingstudio:server:requestOpen', function(stationIndex)
    openStudioFor(source, tonumber(stationIndex) or 1)
end)

exports('OpenStudio', function(src, stationIndex)
    return openStudioFor(src, tonumber(stationIndex) or 1)
end)

RegisterNetEvent('realrpg_clothingstudio:server:saveDesign', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    if not rateLimit(src, 'saveDesign') then return end
    if RRCSAdmin and RRCSAdmin.ValidateDesignPayload then
        local valid, validationError = RRCSAdmin.ValidateDesignPayload(payload)
        if not valid then
            notify(src, validationError or 'Érvénytelen design adat.', 'error')
            return
        end
    end

    local identifier = ServerFW.GetIdentifier(src)
    local designId = makeDesignId(src)
    local label = tostring(payload.label or 'Untitled Design'):sub(1, Config.Studio.maxDesignLabelLength or 80)
    local gender = tostring(payload.gender or 'male')
    local category = tostring(payload.category or 'tops')
    local templateId = tostring(payload.templateId or '')
    local template = Templates.Get(gender, category, templateId)

    if not template then
        notify(src, 'Érvénytelen ruha sablon.', 'error')
        return
    end

    DB.SaveDesign({
        design_id = designId,
        owner_identifier = identifier,
        owner_name = ServerFW.GetName(src),
        label = label,
        gender = gender,
        category = category,
        template_id = templateId,
        design_json = json.encode(payload.design or {}),
        preview_data = payload.preview,
        image_url = payload.imageUrl
    })

    if Config.Audit and Config.Audit.logSaveDesign then
        audit(src, 'design_save', { design_id = designId, details = { label = label, category = category, template = templateId } })
    end
    notify(src, 'Design elmentve.', 'success')
    TriggerClientEvent('realrpg_clothingstudio:client:designSaved', src, {
        design_id = designId,
        label = label,
        gender = gender,
        category = category,
        template_id = templateId,
        preview_data = payload.preview,
        image_url = payload.imageUrl,
        design = payload.design or {}
    })
end)

RegisterNetEvent('realrpg_clothingstudio:server:loadDesign', function(designId)
    local src = source
    designId = tostring(designId or '')
    if designId == '' then return end

    local identifier = ServerFW.GetIdentifier(src)
    local design = DB.GetDesign(designId)
    if not design then
        notify(src, 'A design nem található.', 'error')
        return
    end

    if design.owner_identifier ~= identifier then
        notify(src, 'Ehhez a designhoz nincs hozzáférésed.', 'error')
        return
    end

    TriggerClientEvent('realrpg_clothingstudio:client:loadDesign', src, {
        design_id = design.design_id,
        label = design.label,
        gender = design.gender,
        category = design.category,
        template_id = design.template_id,
        preview_data = design.preview_data,
        image_url = design.image_url,
        design = json.decode(design.design_json or '{}')
    })
end)

RegisterNetEvent('realrpg_clothingstudio:server:printDesign', function(payload)
    local src = source
    if not Config.Printing.enabled then return end
    if type(payload) ~= 'table' or not payload.designId then return end
    if not rateLimit(src, 'printDesign') then return end

    local identifier = ServerFW.GetIdentifier(src)
    local design = DB.GetDesign(payload.designId)
    if not design then
        notify(src, 'A design nem található.', 'error')
        return
    end

    if design.owner_identifier ~= identifier then
        notify(src, 'Csak a saját designodat tudod kinyomtatni ebben a verzióban. Marketplace vásárláshoz használd a BUY gombot.', 'error')
        return
    end

    local paid = ServerFW.RemoveMoney(src, Config.Printing.price, Config.Printing.account)
    if not paid then
        notify(src, ('Nincs elég pénzed. Ár: $%s'):format(Config.Printing.price), 'error')
        return
    end

    local ok, err = createPrintedItemFromDesign(src, design)
    if not ok then
        ServerFW.AddMoney(src, Config.Printing.price, Config.Printing.account)
        notify(src, err or 'Nem sikerült létrehozni az itemet. A pénzt visszakaptad.', 'error')
        return
    end

    if Config.Audit and Config.Audit.logPrintDesign then
        audit(src, 'design_print', { design_id = design.design_id, amount = Config.Printing.price, details = { label = design.label, category = design.category } })
    end
    notify(src, 'A ruhát kinyomtattad és bekerült az inventorydba.', 'success')
end)


RegisterNetEvent('realrpg_clothingstudio:server:refreshMarketplace', function(filters)
    local src = source
    if not Config.Marketplace or not Config.Marketplace.enabled then return end
    filters = type(filters) == 'table' and filters or {}
    filters.limit = Config.Marketplace.listingLimit
    local rows = DB.GetMarketplace(filters)
    TriggerClientEvent('realrpg_clothingstudio:client:marketplaceData', src, rows)
end)

RegisterNetEvent('realrpg_clothingstudio:server:publishDesign', function(payload)
    local src = source
    if not Config.Marketplace or not Config.Marketplace.enabled then
        notify(src, 'A marketplace jelenleg ki van kapcsolva.', 'error')
        return
    end
    if type(payload) ~= 'table' or not payload.designId then return end
    if not rateLimit(src, 'publishDesign') then return end

    local identifier = ServerFW.GetIdentifier(src)
    local design = DB.GetDesign(payload.designId)
    if not design or design.owner_identifier ~= identifier then
        notify(src, 'Csak a saját designodat tudod publikálni.', 'error')
        return
    end

    local price = math.floor(tonumber(payload.price) or Config.Marketplace.defaultPrice or 5000)
    price = math.max(tonumber(Config.Marketplace.minPrice) or 1, math.min(price, tonumber(Config.Marketplace.maxPrice) or 1000000))

    local activeCount = DB.GetMarketplaceDesignCount(identifier)
    if activeCount >= (Config.Marketplace.maxListingsPerPlayer or 40) then
        notify(src, 'Elérted a maximális marketplace listing számot.', 'error')
        return
    end

    local status = Config.Marketplace.requireApproval and 'pending' or 'approved'
    DB.PublishMarketplaceDesign(design.design_id, identifier, price, status)
    if Config.Audit and Config.Audit.logMarketplace then
        audit(src, 'marketplace_publish', { design_id = design.design_id, amount = price, details = { status = status, label = design.label } })
    end
    notify(src, status == 'approved' and 'Design publikálva a marketplace-re.' or 'Design beküldve jóváhagyásra.', 'success')
    TriggerClientEvent('realrpg_clothingstudio:client:marketplaceChanged', src)
end)

RegisterNetEvent('realrpg_clothingstudio:server:unpublishDesign', function(payload)
    local src = source
    if not Config.Marketplace or not Config.Marketplace.enabled then return end
    if type(payload) ~= 'table' or not payload.designId then return end

    local identifier = ServerFW.GetIdentifier(src)
    local changed = DB.UnpublishMarketplaceDesign(payload.designId, identifier)
    if changed and changed > 0 then
        if Config.Audit and Config.Audit.logMarketplace then
            audit(src, 'marketplace_unpublish', { design_id = payload.designId })
        end
        notify(src, 'Design levéve a marketplace-ről.', 'success')
        TriggerClientEvent('realrpg_clothingstudio:client:marketplaceChanged', src)
    else
        notify(src, 'Nem sikerült levenni a marketplace-ről.', 'error')
    end
end)

RegisterNetEvent('realrpg_clothingstudio:server:buyMarketplaceDesign', function(payload)
    local src = source
    if not Config.Marketplace or not Config.Marketplace.enabled then
        notify(src, 'A marketplace jelenleg ki van kapcsolva.', 'error')
        return
    end
    if not Config.Printing.enabled then return end
    if type(payload) ~= 'table' or not payload.designId then return end
    if not rateLimit(src, 'buyMarketplace') then return end

    local buyerIdentifier = ServerFW.GetIdentifier(src)
    local listing = DB.GetMarketplaceListing(payload.designId)
    if not listing or listing.is_public ~= 1 or listing.status ~= 'approved' then
        notify(src, 'Ez a listing nem elérhető.', 'error')
        return
    end

    if not Config.Marketplace.allowOwnPurchase and listing.owner_identifier == buyerIdentifier then
        notify(src, 'A saját marketplace designodat nem kell megvenned.', 'error')
        return
    end

    local price = tonumber(listing.price) or 0
    if price <= 0 then
        notify(src, 'Érvénytelen marketplace ár.', 'error')
        return
    end

    local paid = ServerFW.RemoveMoney(src, price, Config.Marketplace.account or Config.Printing.account)
    if not paid then
        notify(src, ('Nincs elég pénzed. Ár: $%s'):format(price), 'error')
        return
    end

    local ok, err = createPrintedItemFromDesign(src, listing)
    if not ok then
        ServerFW.AddMoney(src, price, Config.Marketplace.account or Config.Printing.account)
        notify(src, err or 'Nem sikerült létrehozni a marketplace ruhát. A pénzt visszakaptad.', 'error')
        return
    end

    local sellerPercent = tonumber(Config.Marketplace.sellerCommissionPercent) or 70
    local sellerAmount = math.floor(price * sellerPercent / 100)
    local serverFee = price - sellerAmount
    local saleId = DB.LogMarketplaceSale({
        design_id = listing.design_id,
        seller_identifier = listing.owner_identifier,
        buyer_identifier = buyerIdentifier,
        buyer_name = ServerFW.GetName(src),
        price = price,
        seller_amount = sellerAmount,
        server_fee = serverFee
    })

    DB.IncrementMarketplaceSold(listing.design_id)
    DB.AddMarketplacePayout(listing.owner_identifier, sellerAmount, saleId)
    if Config.Audit and Config.Audit.logMarketplace then
        audit(src, 'marketplace_buy', { design_id = listing.design_id, target_identifier = listing.owner_identifier, amount = price, details = { seller_amount = sellerAmount, server_fee = serverFee } })
    end

    notify(src, ('Megvetted és kinyomtattad: %s ($%s)'):format(listing.label, price), 'success')
end)

local function claimMarketplacePayout(src)
    local identifier = ServerFW.GetIdentifier(src)
    local rows = DB.GetPendingMarketplacePayouts(identifier)
    if not rows or #rows == 0 then
        notify(src, 'Nincs függő marketplace kifizetésed.', 'info')
        return
    end

    local total = 0
    local ids = {}
    for _, row in ipairs(rows) do
        total = total + (tonumber(row.amount) or 0)
        ids[#ids + 1] = row.id
    end

    if total <= 0 then return end
    if not ServerFW.AddMoney(src, total, Config.Marketplace.account or 'bank') then
        notify(src, 'Nem sikerült jóváírni a marketplace kifizetést.', 'error')
        return
    end

    DB.MarkMarketplacePayoutsPaid(ids)
    notify(src, ('Marketplace kifizetés jóváírva: $%s'):format(total), 'success')
end

RegisterCommand(Config.Admin.claimMarketCommand or 'rrcs_claimmarket', function(src)
    if src == 0 then
        print('This command can only be used ingame.')
        return
    end
    claimMarketplacePayout(src)
end, false)

RegisterCommand(Config.Admin.marketCheckCommand or 'rrcs_marketcheck', function(src)
    local rows = DB.GetMarketplace({ limit = 20 })
    local lines = {
        'RealRPG Clothing Studio marketplace check',
        ('Enabled: %s'):format(Config.Marketplace and tostring(Config.Marketplace.enabled) or 'false'),
        ('Listings loaded: %s'):format(#rows),
        ('Price range: %s - %s'):format(Config.Marketplace and Config.Marketplace.minPrice or 'nil', Config.Marketplace and Config.Marketplace.maxPrice or 'nil'),
        ('Seller commission: %s%%'):format(Config.Marketplace and Config.Marketplace.sellerCommissionPercent or 'nil'),
        ('Approval required: %s'):format(Config.Marketplace and tostring(Config.Marketplace.requireApproval) or 'false')
    }

    for _, row in ipairs(rows) do
        lines[#lines + 1] = ('  %s | %s | %s/%s | $%s | sold=%s'):format(row.design_id, row.label, row.gender, row.category, row.price, row.sold_count or 0)
    end

    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        notify(src, 'Marketplace ellenőrzés kiírva az F8 konzolba.', 'info')
        TriggerClientEvent('realrpg_clothingstudio:client:printLines', src, lines)
    end
end, false)

RegisterNetEvent('realrpg_clothingstudio:server:setEquipped', function(metadata)
    local src = source
    if type(metadata) ~= 'table' or not metadata.designId or not metadata.category then return end

    local identifier = ServerFW.GetIdentifier(src)
    onlineEquipped[src] = onlineEquipped[src] or {}
    onlineEquipped[src][metadata.category] = metadata

    DB.SetEquipped(identifier, metadata.category, metadata.designId, metadata)
    TriggerClientEvent('realrpg_clothingstudio:client:syncWearable', -1, src, metadata)
end)

RegisterNetEvent('realrpg_clothingstudio:server:clearEquipped', function(category)
    local src = source
    local identifier = ServerFW.GetIdentifier(src)
    category = category and tostring(category) or nil

    DB.ClearEquipped(identifier, category)

    if category and onlineEquipped[src] then
        onlineEquipped[src][category] = nil
    elseif not category then
        onlineEquipped[src] = {}
    end

    TriggerClientEvent('realrpg_clothingstudio:client:clearRemoteWearable', -1, src, category)
    notify(src, category and ('Levetted: %s'):format(category) or 'Minden RealRPG printelt ruhát levettél.', 'success')
end)

RegisterNetEvent('realrpg_clothingstudio:server:requestEquipped', function()
    local src = source
    local identifier = ServerFW.GetIdentifier(src)
    local equipped = decodeEquippedRows(DB.GetEquipped(identifier))

    onlineEquipped[src] = equipped
    TriggerClientEvent('realrpg_clothingstudio:client:loadEquipped', src, equipped)
    sendOnlineSnapshotTo(src)
    broadcastEquippedOf(src)
end)

RegisterNetEvent('realrpg_clothingstudio:server:generateAI', function(payload)
    local src = source
    if not AIBridge or not AIBridge.Generate then
        notify(src, 'AI bridge nem töltődött be.', 'error')
        return
    end

    AIBridge.Generate(src, payload or {})
end)


RegisterCommand(Config.Admin.aiCheckCommand or 'rrcs_aicheck', function(src)
    local allowedJobs = 'everyone'
    if Config.AI and Config.AI.allowedJobs then
        local parts = {}
        for job, grade in pairs(Config.AI.allowedJobs) do
            parts[#parts + 1] = ('%s:%s'):format(job, grade)
        end
        allowedJobs = table.concat(parts, ', ')
    end

    local lines = {
        'RealRPG Clothing Studio AI bridge check',
        ('Enabled: %s'):format(Config.AI and tostring(Config.AI.enabled) or 'false'),
        ('Provider: %s'):format(Config.AI and Config.AI.provider or 'none'),
        ('Model: %s'):format(Config.AI and Config.AI.model or 'nil'),
        ('API key set: %s'):format((Config.AI and Config.AI.apiKey and Config.AI.apiKey ~= '') and 'yes' or 'no'),
        ('Cooldown: %s sec'):format(Config.AI and Config.AI.cooldownSeconds or 'nil'),
        ('Upload result to CDN: %s'):format(Config.AI and tostring(Config.AI.uploadResultToCdn) or 'false'),
        ('Upload bridge enabled: %s'):format(UploadBridge and UploadBridge.IsEnabled and tostring(UploadBridge.IsEnabled()) or 'false'),
        ('Prompt history: %s'):format(Config.AI and tostring(Config.AI.storePromptHistory) or 'false'),
        ('Allowed jobs: %s'):format(allowedJobs),
    }

    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        notify(src, 'AI bridge ellenőrzés kiírva az F8 konzolba.', 'info')
        TriggerClientEvent('realrpg_clothingstudio:client:printLines', src, lines)
    end
end, false)

RegisterCommand(Config.Admin.slotCommand or 'rrcs_slots', function(src)
    local rows = DB.GetAllUsedSlots()
    local lines = {}

    for category, slots in pairs((Config.RuntimeTextures and Config.RuntimeTextures.slots) or {}) do
        local used = {}
        for _, row in ipairs(rows) do
            if row.category == category then used[tonumber(row.runtime_slot)] = row.design_id end
        end

        lines[#lines + 1] = ('%s:'):format(category)
        for _, slot in ipairs(slots) do
            local designId = used[tonumber(slot.slot)]
            lines[#lines + 1] = ('  slot %s drawable %s txd=%s -> %s'):format(slot.slot, slot.drawable, slot.txd, designId or 'FREE')
        end
    end

    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        notify(src, 'Runtime slot állapot kiírva az F8 konzolba.', 'info')
        TriggerClientEvent('realrpg_clothingstudio:client:printLines', src, lines)
    end
end, false)


RegisterCommand(Config.Admin.packCheckCommand or 'rrcs_packcheck', function(src)
    local report = Templates.PackReport and Templates.PackReport() or { errors = {}, templateCount = 0, slotCount = 0, categories = {} }
    local lines = {}

    lines[#lines + 1] = 'RealRPG Clothing Studio garment pack check'
    lines[#lines + 1] = ('Manifest: %s'):format(report.manifest and (report.manifest.name or 'loaded') or 'NOT LOADED')
    lines[#lines + 1] = ('Templates: %s'):format(report.templateCount or 0)
    lines[#lines + 1] = ('Runtime slots: %s'):format(report.slotCount or 0)

    for category, count in pairs(report.categories or {}) do
        lines[#lines + 1] = ('  %s -> %s templates'):format(category, count)
    end

    if report.errors and #report.errors > 0 then
        lines[#lines + 1] = 'Errors:'
        for _, err in ipairs(report.errors) do
            lines[#lines + 1] = ('  - %s'):format(err)
        end
    else
        lines[#lines + 1] = 'Errors: none'
    end

    for category, slots in pairs((Config.RuntimeTextures and Config.RuntimeTextures.slots) or {}) do
        lines[#lines + 1] = ('Slot pool %s:'):format(category)
        for _, slot in ipairs(slots) do
            lines[#lines + 1] = ('  slot=%s component=%s drawable=%s texture=%s txd=%s txn=%s pack=%s'):format(
                slot.slot, slot.component, slot.drawable, slot.texture or 0, slot.txd or 'nil', slot.txn or 'nil', slot.pack or 'default'
            )
        end
    end

    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        notify(src, 'Garment pack ellenőrzés kiírva az F8 konzolba.', 'info')
        TriggerClientEvent('realrpg_clothingstudio:client:printLines', src, lines)
    end
end, false)


RegisterCommand(Config.Admin.uploadCheckCommand or 'rrcs_uploadcheck', function(src)
    local lines = {
        'RealRPG Clothing Studio upload bridge check',
        ('Enabled: %s'):format(UploadBridge and UploadBridge.IsEnabled and tostring(UploadBridge.IsEnabled()) or 'false'),
        ('Provider: %s'):format(Config.UploadBridge and Config.UploadBridge.provider or 'none'),
        ('Discord webhook set: %s'):format((Config.UploadBridge and Config.UploadBridge.discordWebhook and Config.UploadBridge.discordWebhook ~= '') and 'yes' or 'no'),
        ('Chunk size: %s'):format(Config.UploadBridge and Config.UploadBridge.chunkSize or 'nil'),
        ('Max data URL bytes: %s'):format(Config.UploadBridge and Config.UploadBridge.maxDataUrlBytes or 'nil'),
        ('Upload layer assets: %s'):format(Config.UploadBridge and tostring(Config.UploadBridge.uploadLayerAssets) or 'false'),
        ('Fail if layer upload fails: %s'):format(Config.UploadBridge and tostring(Config.UploadBridge.failLayerUploadIfUploadFails) or 'false'),
    }

    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        notify(src, 'Upload bridge ellenőrzés kiírva az F8 konzolba.', 'info')
        TriggerClientEvent('realrpg_clothingstudio:client:printLines', src, lines)
    end
end, false)

RegisterCommand(Config.Admin.assetCheckCommand or 'rrcs_assetcheck', function(src)
    local lines = {
        'RealRPG Clothing Studio layer asset upload check',
        ('Upload bridge enabled: %s'):format(UploadBridge and UploadBridge.IsEnabled and tostring(UploadBridge.IsEnabled()) or 'false'),
        ('Layer asset upload: %s'):format(Config.UploadBridge and tostring(Config.UploadBridge.uploadLayerAssets) or 'false'),
        ('Fail save on layer upload failure: %s'):format(Config.UploadBridge and tostring(Config.UploadBridge.failLayerUploadIfUploadFails) or 'false'),
        ('Chunk size: %s'):format(Config.UploadBridge and Config.UploadBridge.chunkSize or 'nil'),
        ('Max data URL bytes: %s'):format(Config.UploadBridge and Config.UploadBridge.maxDataUrlBytes or 'nil'),
        'Design JSON rule: image layers should store assetUrl/src URL when bridge is enabled.',
    }

    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        notify(src, 'Layer asset upload ellenőrzés kiírva az F8 konzolba.', 'info')
        TriggerClientEvent('realrpg_clothingstudio:client:printLines', src, lines)
    end
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    onlineEquipped[src] = nil
    TriggerClientEvent('realrpg_clothingstudio:client:clearRemoteWearable', -1, src, nil)
end)


RegisterCommand((Config.Admin and Config.Admin.versionCommand) or 'rrcs_version', function(src)
    local lines = {
        'RealRPG Clothing Studio',
        ('Version: %s'):format((Config.Release and Config.Release.version) or GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'),
        ('Build: %s'):format((Config.Release and Config.Release.build) or 'unknown'),
        ('Framework: %s'):format(RRFW and RRFW.Name or 'unknown'),
        ('Inventory: %s'):format(Config.Inventory or 'unknown'),
        'Recommended first run: /rrcs_selftest then /rrcs_health'
    }

    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        notify(src, 'Version info kiírva az F8 konzolba.', 'info')
        TriggerClientEvent('realrpg_clothingstudio:client:printLines', src, lines)
    end
end, false)
