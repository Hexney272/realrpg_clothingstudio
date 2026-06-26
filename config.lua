Config = {}

-- ═══════════════════════════════════════════════════════════════
-- GENERAL
-- ═══════════════════════════════════════════════════════════════
Config.Debug = true
Config.Locale = 'hu'

-- Framework: 'auto' / 'esx' / 'qb' / 'qbox'
Config.Framework = 'auto'

-- Inventory: 'ox_inventory' / 'codem' / 'qs-inventory'
Config.Inventory = 'ox_inventory'

Config.OpenCommand = 'clothingstudio'
Config.UseCommand = true

-- ═══════════════════════════════════════════════════════════════
-- STUDIO UI
-- ═══════════════════════════════════════════════════════════════
Config.Studio = {
    title = 'RealRPG Clothing Studio',
    accent = '#d7ff00',
    maxUploadMB = 4,
    allowedExtensions = { png = true, jpg = true, jpeg = true, webp = true },
}

-- ═══════════════════════════════════════════════════════════════
-- DESIGNER STATIONS
-- ═══════════════════════════════════════════════════════════════
Config.Stations = {
    {
        label = 'RealRPG Clothing Studio',
        coords = vec3(72.30, -1399.10, 29.38),
        radius = 2.0,
        job = nil,
        grade = 0
    },
    {
        label = 'Burger Shot Designer',
        coords = vec3(-1198.20, -894.40, 13.90),
        radius = 2.0,
        job = 'burgershot',
        grade = 2
    }
}

Config.DrawMarker = true
Config.Marker = {
    type = 2,
    scale = vec3(0.25, 0.25, 0.25),
    color = { r = 215, g = 255, b = 0, a = 180 }
}

Config.InteractDistance = 2.0

-- ═══════════════════════════════════════════════════════════════
-- PRINTING / ITEM CREATION
-- ═══════════════════════════════════════════════════════════════
Config.Printing = {
    enabled = true,
    price = 2500,
    account = 'money', -- money / bank
    items = {
        -- Components
        tops = 'printed_tshirt',
        undershirt = 'printed_undershirt',
        pants = 'printed_pants',
        shoes = 'printed_shoes',
        torso = 'printed_torso',
        bags = 'printed_bag',
        accessories = 'printed_accessory',
        armor = 'printed_armor',
        decals = 'printed_decal',
        -- Props
        hats = 'printed_hat',
        glasses = 'printed_glasses',
        ears = 'printed_earpiece',
        watches = 'printed_watch',
        bracelets = 'printed_bracelet',
    }
}

-- ═══════════════════════════════════════════════════════════════
-- RENDER MODE: 'runtime' or 'hybrid'
--
-- runtime: DUI textúrák futásidőben - ruhák NEM jelennek meg
--          a normál ruha menükben. Csak az item-en keresztül viselhetők.
--
-- hybrid:  DUI textúrák futásidőben + YTD generálás.
--          Szerver újraindítás után a ruha megjelenik a normál
--          öltözködő menükben is, szabadon használható.
-- ═══════════════════════════════════════════════════════════════
Config.RenderMode = 'runtime' -- 'runtime' / 'hybrid'

Config.RuntimeTextures = {
    enabled = true,
    width = 1024,
    height = 1024,
    requireSlotForPrint = true,
    -- Slots per category (component-based). Each slot is one "blank" texture the DUI can overwrite.
    slots = {
        tops = {
            { slot = 1, txd = 'mp_m_freemode_01_male_p', txn = 'jbib_diff_011_j_uni' },
            { slot = 2, txd = 'mp_m_freemode_01_male_p', txn = 'jbib_diff_011_k_uni' },
            { slot = 3, txd = 'mp_m_freemode_01_male_p', txn = 'jbib_diff_011_l_uni' },
            { slot = 4, txd = 'mp_m_freemode_01_male_p', txn = 'jbib_diff_011_m_uni' },
        },
        undershirt = {
            { slot = 1, txd = 'mp_m_freemode_01_male_p', txn = 'accs_diff_011_a_uni' },
            { slot = 2, txd = 'mp_m_freemode_01_male_p', txn = 'accs_diff_011_b_uni' },
        },
        pants = {
            { slot = 1, txd = 'mp_m_freemode_01_male_p', txn = 'legs_diff_001_a_uni' },
            { slot = 2, txd = 'mp_m_freemode_01_male_p', txn = 'legs_diff_001_b_uni' },
        },
        shoes = {
            { slot = 1, txd = 'mp_m_freemode_01_male_p', txn = 'feet_diff_001_a_uni' },
        },
        torso = {
            { slot = 1, txd = 'mp_m_freemode_01_male_p', txn = 'uppr_diff_015_a_uni' },
        },
        hats = {
            { slot = 1, txd = 'mp_m_freemode_01_male_p', txn = 'head_diff_001_a_uni' },
        },
        glasses = {
            { slot = 1, txd = 'mp_m_freemode_01_male_p', txn = 'head_diff_002_a_uni' },
        },
    }
}

-- ═══════════════════════════════════════════════════════════════
-- HYBRID MODE: YTD GENERATION
-- ═══════════════════════════════════════════════════════════════
Config.Hybrid = {
    enabled = false, -- auto-enabled when RenderMode == 'hybrid'
    outputPath = 'stream/generated/', -- where generated YTD files are saved
    autoReloadOnRestart = true,
    -- Naming pattern for generated files
    -- Available vars: {designId}, {category}, {gender}, {slot}
    filePattern = 'rrcs_{category}_{designId}',
    -- Max simultaneous YTD generations queued
    maxQueueSize = 50,
    -- Cooldown between generation jobs (ms)
    jobCooldownMs = 500,
}

-- ═══════════════════════════════════════════════════════════════
-- CLOTHING PACK EXPORT
-- ═══════════════════════════════════════════════════════════════
Config.PackExport = {
    enabled = true,
    -- Max designs per export pack
    maxDesignsPerPack = 20,
    -- Output directory for exported packs
    outputPath = 'exports/',
    -- Include metadata JSON in pack
    includeMetadata = true,
    -- Generate fxmanifest for standalone use
    generateManifest = true,
    -- Permission required to export packs
    requireAdmin = false,
    -- Export price (0 = free)
    price = 0,
}

-- ═══════════════════════════════════════════════════════════════
-- UPLOAD BRIDGE (Discord webhook CDN)
-- ═══════════════════════════════════════════════════════════════
Config.UploadBridge = {
    enabled = false,
    provider = 'discord',
    discordWebhook = '',
    maxDataUrlBytes = 6 * 1024 * 1024,
    timeoutSeconds = 60,
    uploadLayerAssets = false,
    failLayerUploadIfUploadFails = false,
}

-- ═══════════════════════════════════════════════════════════════
-- AI DESIGN GENERATION (Placeholder)
-- ═══════════════════════════════════════════════════════════════
Config.AI = {
    enabled = false,
    provider = 'gemini', -- 'gemini' / 'openai' / 'stability'
    apiKey = '',
    cooldownSeconds = 30,
    uploadResultToCdn = false,
}

-- ═══════════════════════════════════════════════════════════════
-- MARKETPLACE
-- ═══════════════════════════════════════════════════════════════
Config.Marketplace = {
    enabled = false,
    requireApproval = true,
    defaultPrice = 5000,
    minPrice = 500,
    maxPrice = 500000,
    -- Server fee percentage (0-100)
    serverFeePercent = 15,
    -- Max listings per player
    maxListingsPerPlayer = 25,
    -- Allow buying own designs
    allowBuyOwn = false,
}

-- ═══════════════════════════════════════════════════════════════
-- ADMIN
-- ═══════════════════════════════════════════════════════════════
Config.Admin = {
    -- ACE permission required
    permission = 'realrpg.clothingstudio.admin',
    -- Allowed job+grade combos (job = minGrade)
    allowedJobs = {
        -- police = 4,
        -- management = 0,
    },
    -- Command names
    adminCheckCommand = 'rrcs_admincheck',
    pendingCommand = 'rrcs_pending',
    approveCommand = 'rrcs_approve',
    rejectCommand = 'rrcs_reject',
    takedownCommand = 'rrcs_takedown',
    auditCommand = 'rrcs_audit',
    healthCommand = 'rrcs_health',
    selfTestCommand = 'rrcs_selftest',
    maintenanceCommand = 'rrcs_maintcheck',
    cleanupOrphansCommand = 'rrcs_cleanup_orphans',
    purgeHistoryCommand = 'rrcs_purgehistory',
    textureDebugCommand = 'rrcs_texdebug',
    textureCacheCommand = 'rrcs_texcache',
    clearTextureCacheCommand = 'rrcs_cleartexcache',
}

-- ═══════════════════════════════════════════════════════════════
-- AUDIT LOG
-- ═══════════════════════════════════════════════════════════════
Config.Audit = {
    enabled = true,
    discordWebhook = '',
}

-- ═══════════════════════════════════════════════════════════════
-- SECURITY / RATE LIMITS
-- ═══════════════════════════════════════════════════════════════
Config.Security = {
    maxDesignJsonBytes = 2 * 1024 * 1024, -- 2MB max design JSON
    maxPreviewBytes = 1.5 * 1024 * 1024,  -- 1.5MB max preview image
    maxLayersPerDesign = 30,
    rateLimits = {
        save = { max = 5, windowSeconds = 30 },
        print = { max = 3, windowSeconds = 30 },
        upload = { max = 4, windowSeconds = 60 },
        marketplace_list = { max = 3, windowSeconds = 60 },
        pack_export = { max = 2, windowSeconds = 120 },
    }
}

-- ═══════════════════════════════════════════════════════════════
-- CACHE
-- ═══════════════════════════════════════════════════════════════
Config.Cache = {
    enabled = true,
    maxRuntimeHandles = 32,
    maxIdleSeconds = 900, -- 15 min
    autoCleanupIntervalSeconds = 120,
    textureCacheCommand = 'rrcs_texcache',
    clearTextureCacheCommand = 'rrcs_cleartexcache',
}

-- ═══════════════════════════════════════════════════════════════
-- MAINTENANCE
-- ═══════════════════════════════════════════════════════════════
Config.Maintenance = {
    enabled = true,
    requireConfirmWord = 'CONFIRM',
    purgeAiHistoryDays = 30,
    purgeAuditLogDays = 90,
    purgeRejectedMarketplaceDays = 30,
    purgeUnpublishedMarketplaceDays = 60,
    includeLargeBase64Report = true,
    largePreviewWarnBytes = 900000,
    largeDesignJsonWarnBytes = 900000,
    command = 'rrcs_maintcheck',
    cleanupCommand = 'rrcs_cleanup_orphans',
    purgeCommand = 'rrcs_purgehistory',
}

-- ═══════════════════════════════════════════════════════════════
-- HEALTHCHECK
-- ═══════════════════════════════════════════════════════════════
Config.Healthcheck = {
    enabled = true,
    command = 'rrcs_health',
    selfTestCommand = 'rrcs_selftest',
    autoRunOnResourceStart = true,
    validateDatabase = true,
    validateManifest = true,
    validateRuntimeSlots = true,
    validateUploadBridge = true,
    validateMarketplace = true,
    printRecommendations = true,
    expectedTables = {
        'realrpg_clothing_designs',
        'realrpg_clothing_equipped',
        'realrpg_clothing_design_slots',
        'realrpg_clothing_marketplace',
        'realrpg_clothing_marketplace_sales',
        'realrpg_clothing_marketplace_payouts',
        'realrpg_clothing_audit_log',
    }
}

-- ═══════════════════════════════════════════════════════════════
-- GARMENT PACK (stream/blank_templates)
-- ═══════════════════════════════════════════════════════════════
Config.GarmentPack = {
    manifest = 'stream/blank_templates/manifest.json',
    autoScanOnBoot = true,
}

-- ═══════════════════════════════════════════════════════════════
-- RELEASE META
-- ═══════════════════════════════════════════════════════════════
Config.Release = {
    version = '1.2.0',
    channel = 'stable',
}
