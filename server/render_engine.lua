--[[
    RealRPG Clothing Studio - Render Engine (Server-side)
    
    Manages render mode logic:
    - RUNTIME: Textures created at runtime via DUI. Not visible in clothing menus.
               Designs are locked to printed items.
    - HYBRID:  Runtime DUI textures + YTD file generation.
               After server restart, designs appear in normal clothing menus.
    
    The actual DUI rendering happens client-side (texture_runtime.lua).
    This server file manages slot allocation, YTD metadata, and hybrid file tracking.
]]

RenderEngine = RenderEngine or {}

local slotAllocations = {} -- category -> { [slot] = designId }
local hybridQueue = {}     -- queued YTD generation jobs
local hybridGenerated = {} -- designId -> { path, status, generatedAt }

local function debugPrint(msg)
    if Config.Debug then print(('[^2RealRPG Render^0] %s'):format(msg)) end
end

-- ═══════════════════════════════════════════════════════════════
-- RENDER MODE
-- ═══════════════════════════════════════════════════════════════

function RenderEngine.GetMode()
    return Config.RenderMode or 'runtime'
end

function RenderEngine.IsHybrid()
    return RenderEngine.GetMode() == 'hybrid'
end

function RenderEngine.IsRuntime()
    return RenderEngine.GetMode() == 'runtime'
end

-- ═══════════════════════════════════════════════════════════════
-- SLOT ALLOCATION (Runtime texture slots)
-- ═══════════════════════════════════════════════════════════════

function RenderEngine.InitSlots()
    slotAllocations = {}
    local slots = Config.RuntimeTextures and Config.RuntimeTextures.slots or {}
    for category, slotList in pairs(slots) do
        slotAllocations[category] = {}
    end

    -- Load existing allocations from DB
    local rows = DB.GetAllSlotAllocations and DB.GetAllSlotAllocations() or {}
    for _, row in ipairs(rows) do
        if slotAllocations[row.category] then
            slotAllocations[row.category][tonumber(row.runtime_slot)] = row.design_id
        end
    end

    local categoryCount = 0
    for _ in pairs(slotAllocations) do categoryCount = categoryCount + 1 end
    debugPrint(('Slot allocations loaded: %d categories'):format(categoryCount))
end

function RenderEngine.AllocateSlot(category, designId)
    local slots = Config.RuntimeTextures and Config.RuntimeTextures.slots and Config.RuntimeTextures.slots[category]
    if not slots or #slots == 0 then
        return nil, 'Nincs elérhető runtime slot ehhez a kategóriához: ' .. tostring(category)
    end

    -- Check if already allocated
    if slotAllocations[category] then
        for slotNum, existingDesign in pairs(slotAllocations[category]) do
            if existingDesign == designId then
                return slots[slotNum], nil -- Already has a slot
            end
        end
    end

    -- Find a free slot
    slotAllocations[category] = slotAllocations[category] or {}
    for i, slotData in ipairs(slots) do
        if not slotAllocations[category][i] then
            slotAllocations[category][i] = designId
            -- Save to DB
            if DB.AllocateSlot then
                DB.AllocateSlot(designId, category, i)
            end
            debugPrint(('Slot allocated: %s slot %d -> %s'):format(category, i, designId))
            return slotData, nil
        end
    end

    return nil, 'Minden runtime slot foglalt ebben a kategóriában. Szabadíts fel egyet.'
end

function RenderEngine.FreeSlot(designId, category)
    if not slotAllocations[category] then return false end
    for slotNum, existingDesign in pairs(slotAllocations[category]) do
        if existingDesign == designId then
            slotAllocations[category][slotNum] = nil
            if DB.FreeSlot then
                DB.FreeSlot(designId)
            end
            debugPrint(('Slot freed: %s slot %d (was %s)'):format(category, slotNum, designId))
            return true
        end
    end
    return false
end

function RenderEngine.GetSlotForDesign(designId, category)
    if not slotAllocations[category] then return nil end
    local slots = Config.RuntimeTextures and Config.RuntimeTextures.slots and Config.RuntimeTextures.slots[category]
    if not slots then return nil end

    for slotNum, existingDesign in pairs(slotAllocations[category]) do
        if existingDesign == designId then
            return slots[slotNum]
        end
    end
    return nil
end

function RenderEngine.GetSlotStatus()
    local status = {}
    local slots = Config.RuntimeTextures and Config.RuntimeTextures.slots or {}
    for category, slotList in pairs(slots) do
        local total = #slotList
        local used = 0
        if slotAllocations[category] then
            for _ in pairs(slotAllocations[category]) do used = used + 1 end
        end
        status[category] = { total = total, used = used, free = total - used }
    end
    return status
end

-- ═══════════════════════════════════════════════════════════════
-- RUNTIME RENDER DATA (sent to client for DUI application)
-- ═══════════════════════════════════════════════════════════════

function RenderEngine.BuildRuntimeData(design, template)
    if not Config.RuntimeTextures or not Config.RuntimeTextures.enabled then
        return nil
    end

    local slotData = RenderEngine.GetSlotForDesign(design.design_id, design.category)
    if not slotData then
        -- Try to allocate a new slot
        local newSlot, err = RenderEngine.AllocateSlot(design.category, design.design_id)
        if not newSlot then
            return nil, err
        end
        slotData = newSlot
    end

    return {
        mode = RenderEngine.GetMode(),
        slot = slotData.slot,
        txd = slotData.txd,
        txn = slotData.txn,
        width = Config.RuntimeTextures.width or 1024,
        height = Config.RuntimeTextures.height or 1024,
        designId = design.design_id,
        category = design.category,
        isProp = Templates.IsProp(design.category),
    }
end

-- ═══════════════════════════════════════════════════════════════
-- HYBRID MODE: YTD GENERATION QUEUE
-- ═══════════════════════════════════════════════════════════════

function RenderEngine.QueueHybridGeneration(design, template, imageData)
    if not RenderEngine.IsHybrid() then return false, 'Nem hybrid módban van a szerver.' end
    if not Config.Hybrid or not Config.Hybrid.enabled then return false, 'Hybrid mód nincs engedélyezve a configban.' end

    local maxQueue = Config.Hybrid.maxQueueSize or 50
    if #hybridQueue >= maxQueue then
        return false, 'A YTD generálási sor megtelt. Próbáld újra később.'
    end

    -- Build job data
    local job = {
        designId = design.design_id,
        category = design.category,
        gender = design.gender,
        templateId = design.template_id,
        label = design.label,
        imageData = imageData, -- base64 preview
        template = template,
        queuedAt = os.time(),
        status = 'pending', -- pending / processing / done / failed
    }

    hybridQueue[#hybridQueue + 1] = job
    debugPrint(('Hybrid YTD queued: %s (%s/%s) - queue size: %d'):format(
        design.design_id, design.gender, design.category, #hybridQueue
    ))

    -- Save generation record to DB
    if DB.SaveHybridJob then
        DB.SaveHybridJob(design.design_id, design.category, 'pending')
    end

    return true
end

function RenderEngine.ProcessHybridQueue()
    if #hybridQueue == 0 then return end

    local job = hybridQueue[1]
    if not job or job.status ~= 'pending' then
        table.remove(hybridQueue, 1)
        return
    end

    job.status = 'processing'

    -- In FiveM, we can't directly generate YTD binary files from Lua.
    -- The hybrid approach works by:
    -- 1. Saving the design image data to a known file location
    -- 2. Recording the metadata so an external tool or restart script can compile the YTD
    -- 3. On next restart, FiveM streams the pre-generated YTD files

    local resourceName = GetCurrentResourceName()
    local outputPath = Config.Hybrid.outputPath or 'stream/generated/'

    -- Generate filename using pattern
    local pattern = Config.Hybrid.filePattern or 'rrcs_{category}_{designId}'
    local filename = pattern
        :gsub('{designId}', tostring(job.designId):gsub('[^%w_]', '_'):sub(1, 24))
        :gsub('{category}', tostring(job.category))
        :gsub('{gender}', tostring(job.gender))
        :gsub('{slot}', tostring(job.template and job.template.drawable or 0))

    -- Save the design image as a raw file that can be compiled to YTD
    local imagePath = outputPath .. filename .. '.png.b64'
    if job.imageData then
        -- Strip data URL prefix if present
        local raw = job.imageData:gsub('^data:[^;]+;base64,', '')
        SaveResourceFile(resourceName, imagePath, raw, #raw)
    end

    -- Save metadata for the compilation step
    local metaPath = outputPath .. filename .. '.meta.json'
    local meta = json.encode({
        designId = job.designId,
        category = job.category,
        gender = job.gender,
        templateId = job.templateId,
        label = job.label,
        component = job.template and job.template.component,
        prop = job.template and job.template.prop,
        drawable = job.template and job.template.drawable,
        texture = job.template and job.template.texture,
        isProp = Templates.IsProp(job.category),
        generatedAt = os.date('%Y-%m-%d %H:%M:%S'),
        filename = filename,
    })
    SaveResourceFile(resourceName, metaPath, meta, #meta)

    -- Mark as done
    job.status = 'done'
    hybridGenerated[job.designId] = {
        path = outputPath .. filename,
        status = 'generated',
        generatedAt = os.time(),
    }

    if DB.SaveHybridJob then
        DB.SaveHybridJob(job.designId, job.category, 'done')
    end

    debugPrint(('Hybrid YTD generated metadata: %s -> %s'):format(job.designId, filename))
    table.remove(hybridQueue, 1)
end

-- ═══════════════════════════════════════════════════════════════
-- HYBRID QUEUE PROCESSOR (background thread)
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    -- Wait for boot
    Wait(5000)

    if not RenderEngine.IsHybrid() then
        debugPrint('Render mode: RUNTIME (hybrid queue disabled)')
        return
    end

    debugPrint('Render mode: HYBRID (YTD generation queue active)')

    -- Auto-enable hybrid config
    if Config.Hybrid then Config.Hybrid.enabled = true end

    while true do
        local cooldown = Config.Hybrid and Config.Hybrid.jobCooldownMs or 500
        Wait(cooldown)
        RenderEngine.ProcessHybridQueue()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- BOOT: Initialize slot allocations
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(3000)
    RenderEngine.InitSlots()
    debugPrint(('Render engine initialized. Mode: %s'):format(RenderEngine.GetMode()))
end)

-- ═══════════════════════════════════════════════════════════════
-- STATUS COMMANDS
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('rrcs_rendermode', function(src)
    local mode = RenderEngine.GetMode()
    local status = RenderEngine.GetSlotStatus()
    local lines = {
        ('RealRPG Render Engine - Mode: %s'):format(mode:upper()),
        ('Hybrid queue size: %d'):format(#hybridQueue),
    }

    for category, info in pairs(status) do
        lines[#lines + 1] = ('  %s: %d/%d used (%d free)'):format(category, info.used, info.total, info.free)
    end

    if src == 0 then
        print(table.concat(lines, '\n'))
    else
        TriggerClientEvent('realrpg_clothingstudio:client:notify', src, table.concat(lines, ' | '), 'info')
    end
end, false)
