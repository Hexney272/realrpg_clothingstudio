Templates = Templates or {}

-- GTA freemode clothing component ids:
-- 11 = tops, 8 = undershirt, 4 = pants, 6 = shoes
Templates.List = {
    male = {
        tops = {
            { id = 'm_blank_top_000', label = 'Blank Póló #1', component = 11, drawable = 0, texture = 0, runtimeSlot = 1, preview = 'assets/jbib_000_preview.png', uv = 'assets/jbib_000_uv.png' },
            { id = 'm_blank_top_005', label = 'Blank Póló #2', component = 11, drawable = 5, texture = 0, runtimeSlot = 2, preview = 'assets/jbib_005_preview.png', uv = 'assets/jbib_005_uv.png' },
            { id = 'm_blank_top_007', label = 'Blank Póló #3', component = 11, drawable = 7, texture = 0, runtimeSlot = 3, preview = 'assets/jbib_007_preview.png', uv = 'assets/jbib_007_uv.png' },
            { id = 'm_blank_top_013', label = 'Blank Póló #4', component = 11, drawable = 13, texture = 0, runtimeSlot = 4, preview = 'assets/jbib_013_preview.png', uv = 'assets/jbib_013_uv.png' }
        },
        undershirt = {},
        pants = {},
        shoes = {}
    },
    female = {
        tops = {},
        undershirt = {},
        pants = {},
        shoes = {}
    }
}

Templates.Manifest = nil
Templates.ManifestErrors = {}

local function log(msg)
    if Config and Config.Debug then
        print(('^2[RealRPG Clothing Studio]^7 %s'):format(msg))
    end
end

local function ensureList(gender, category)
    Templates.List[gender] = Templates.List[gender] or {}
    Templates.List[gender][category] = Templates.List[gender][category] or {}
    return Templates.List[gender][category]
end

local function ensureSlotList(category)
    Config.RuntimeTextures = Config.RuntimeTextures or {}
    Config.RuntimeTextures.slots = Config.RuntimeTextures.slots or {}
    Config.RuntimeTextures.slots[category] = Config.RuntimeTextures.slots[category] or {}
    return Config.RuntimeTextures.slots[category]
end

local function slotExists(category, slotNumber)
    local slots = ensureSlotList(category)
    for _, slot in ipairs(slots) do
        if tonumber(slot.slot) == tonumber(slotNumber) then return true end
    end
    return false
end

local function templateExists(gender, category, id)
    local list = ensureList(gender, category)
    for _, item in ipairs(list) do
        if item.id == id then return true end
    end
    return false
end

local function addSlot(category, data)
    if not category or type(data) ~= 'table' then return end
    if not data.slot or not data.component or not data.drawable or not data.txd or not data.txn then
        Templates.ManifestErrors[#Templates.ManifestErrors + 1] = ('Invalid slot in category %s'):format(category)
        return
    end

    if slotExists(category, data.slot) then return end

    local slots = ensureSlotList(category)
    slots[#slots + 1] = {
        slot = tonumber(data.slot),
        component = tonumber(data.component),
        drawable = tonumber(data.drawable),
        texture = tonumber(data.texture or 0),
        txd = tostring(data.txd),
        txn = tostring(data.txn),
        pack = data.pack and tostring(data.pack) or nil
    }
end

local function addTemplate(gender, category, data)
    if not gender or not category or type(data) ~= 'table' then return end
    if not data.id or not data.label or not data.component or not data.drawable then
        Templates.ManifestErrors[#Templates.ManifestErrors + 1] = ('Invalid template in %s/%s'):format(gender, category)
        return
    end

    if templateExists(gender, category, data.id) then return end

    local list = ensureList(gender, category)
    list[#list + 1] = {
        id = tostring(data.id),
        label = tostring(data.label),
        component = tonumber(data.component),
        drawable = tonumber(data.drawable),
        texture = tonumber(data.texture or 0),
        runtimeSlot = tonumber(data.runtimeSlot or data.slot),
        preview = data.preview or (category == 'pants' and 'assets/pants.png' or category == 'shoes' and 'assets/shoes.png' or 'assets/tshirt.png'),
        uv = data.uv or (category == 'pants' and 'assets/uv_pants.png' or category == 'shoes' and 'assets/uv_shoes.png' or 'assets/uv_tshirt.png'),
        pack = data.pack and tostring(data.pack) or nil
    }
end

function Templates.LoadPackManifest()
    if not Config or not Config.GarmentPack or not Config.GarmentPack.enabled then return false end

    if Config.GarmentPack.strictMode then
        Config.RuntimeTextures.slots = {}
        Templates.List = { male = { tops = {}, undershirt = {}, pants = {}, shoes = {} }, female = { tops = {}, undershirt = {}, pants = {}, shoes = {} } }
    end

    local manifestPath = Config.GarmentPack.manifest or 'stream/blank_templates/manifest.json'
    local raw = LoadResourceFile(GetCurrentResourceName(), manifestPath)
    if not raw or raw == '' then
        Templates.ManifestErrors[#Templates.ManifestErrors + 1] = ('Manifest not found: %s'):format(manifestPath)
        return false
    end

    local ok, manifest = pcall(json.decode, raw)
    if not ok or type(manifest) ~= 'table' then
        Templates.ManifestErrors[#Templates.ManifestErrors + 1] = ('Manifest JSON invalid: %s'):format(manifestPath)
        return false
    end

    Templates.Manifest = manifest

    for category, slots in pairs(manifest.runtimeSlots or {}) do
        for _, slot in ipairs(slots or {}) do
            addSlot(category, slot)
        end
    end

    for gender, categories in pairs(manifest.templates or {}) do
        for category, list in pairs(categories or {}) do
            for _, template in ipairs(list or {}) do
                addTemplate(gender, category, template)
            end
        end
    end

    log(('Garment manifest loaded: %s'):format(manifest.name or manifestPath))
    return true
end

function Templates.Get(gender, category, id)
    local list = Templates.List[gender] and Templates.List[gender][category]
    if not list then return nil end
    for _, t in ipairs(list) do
        if t.id == id then return t end
    end
    return nil
end

function Templates.GetSlot(category, slotNumber)
    local slots = Config.RuntimeTextures and Config.RuntimeTextures.slots and Config.RuntimeTextures.slots[category]
    if not slots then return nil end
    for _, slot in ipairs(slots) do
        if tonumber(slot.slot) == tonumber(slotNumber) then return slot end
    end
    return nil
end

function Templates.PackReport()
    local report = {
        manifest = Templates.Manifest,
        errors = Templates.ManifestErrors,
        templateCount = 0,
        slotCount = 0,
        categories = {}
    }

    for gender, categories in pairs(Templates.List or {}) do
        for category, list in pairs(categories or {}) do
            report.templateCount = report.templateCount + #list
            report.categories[('%s/%s'):format(gender, category)] = #list
        end
    end

    for _, slots in pairs((Config.RuntimeTextures and Config.RuntimeTextures.slots) or {}) do
        report.slotCount = report.slotCount + #slots
    end

    return report
end

Templates.LoadPackManifest()
