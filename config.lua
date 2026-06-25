Config = {}

Config.Debug = true
Config.Locale = 'hu'

-- auto / esx / qb / qbox
Config.Framework = 'auto'
Config.Inventory = 'ox_inventory'

Config.OpenCommand = 'clothingstudio'
Config.UseCommand = true
Config.UseTarget = false

Config.Studio = {
    title = 'RealRPG Clothing Studio',
    accent = '#d7ff00',
    maxUploadMB = 4,
    allowedExtensions = { png = true, jpg = true, jpeg = true, webp = true },
    maxDesignLabelLength = 80,
}

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

Config.Printing = {
    enabled = true,
    price = 2500,
    account = 'money', -- money / bank / cash (qb cash map)
    items = {
        tops = 'printed_tshirt',
        undershirt = 'printed_undershirt',
        pants = 'printed_pants',
        shoes = 'printed_shoes'
    }
}

Config.UploadBridge = {
    enabled = false,
    provider = 'discord', -- discord / none
    discordWebhook = '',
    chunkSize = 240000, -- NUI -> client -> server chunk size
    timeoutSeconds = 60,
    maxDataUrlBytes = 6 * 1024 * 1024,
    saveFinalTextureOnly = true,
    failSaveIfUploadFails = false,

    -- v0.7: image layers are uploaded individually so design_json will store URLs instead of huge base64 strings.
    uploadLayerAssets = true,
    failLayerUploadIfUploadFails = false
}

Config.AI = {
    enabled = false,
    provider = 'gemini',
    apiKey = '',
    model = 'gemini-2.5-flash-image',
    -- Az endpoint már nem kell - az ai_bridge.lua az Interactions API-t használja automatikusan
    endpoint = 'https://generativelanguage.googleapis.com/v1beta/interactions',
    cooldownSeconds = 60,
    maxPromptLength = 420,
    maxNegativePromptLength = 240,
    uploadResultToCdn = true,
    failIfUploadFails = false,
    storePromptHistory = true,
    addGeneratedImageAsLayer = true,
    systemPrefix = 'Create a clean transparent clothing print design for a FiveM/GTA roleplay server. Centered 2D apparel graphic, no mockup, no shirt photo, no watermark, high contrast, usable as a 1024x1024 texture layer. Prompt: ',
    blockedWords = { 'nude', 'porn', 'sex', 'swastika', 'nazi', 'hitler' },
    allowedJobs = nil, -- nil = everyone. Example: { burgershot = 2, police = 4 }
}

Config.InteractDistance = 2.0

-- Runtime texture foundation.
-- IMPORTANT: for real per-player custom prints you must stream blank garments whose YTD texture names
-- match the txd/txn values below. Without matching blank templates the script still works as MVP,
-- but cannot visually replace the texture on the ped.
Config.RuntimeTextures = {
    enabled = true,
    width = 1024,
    height = 1024,
    replaceForLocalPlayer = true,
    replaceForRemotePlayers = true,
    requireSlotForPrint = true,
    allowSlotReuseWhenFull = false,

    -- One slot per simultaneously different printed design/drawable.
    -- Replace txd/txn/drawable values with your streamed blank clothing template names.
    slots = {
        tops = {
            { slot = 1, component = 11, drawable = 15, texture = 0, txd = 'realrpg_blank_top_01', txn = 'blank_diffuse' },
            { slot = 2, component = 11, drawable = 16, texture = 0, txd = 'realrpg_blank_top_02', txn = 'blank_diffuse' },
            { slot = 3, component = 11, drawable = 17, texture = 0, txd = 'realrpg_blank_top_03', txn = 'blank_diffuse' },
            { slot = 4, component = 11, drawable = 18, texture = 0, txd = 'realrpg_blank_top_04', txn = 'blank_diffuse' }
        },
        undershirt = {
            { slot = 1, component = 8, drawable = 15, texture = 0, txd = 'realrpg_blank_under_01', txn = 'blank_diffuse' },
            { slot = 2, component = 8, drawable = 16, texture = 0, txd = 'realrpg_blank_under_02', txn = 'blank_diffuse' }
        },
        pants = {
            { slot = 1, component = 4, drawable = 1, texture = 0, txd = 'realrpg_blank_pants_01', txn = 'blank_diffuse' },
            { slot = 2, component = 4, drawable = 2, texture = 0, txd = 'realrpg_blank_pants_02', txn = 'blank_diffuse' }
        },
        shoes = {
            { slot = 1, component = 6, drawable = 1, texture = 0, txd = 'realrpg_blank_shoes_01', txn = 'blank_diffuse' },
            { slot = 2, component = 6, drawable = 2, texture = 0, txd = 'realrpg_blank_shoes_02', txn = 'blank_diffuse' }
        }
    }
}

-- Blank garment pack loader.
-- This lets you add new printable clothing slots from stream/blank_templates/manifest.json
-- without editing shared/templates.lua by hand. Actual .ydd/.ytd files must still be placed in stream.
Config.GarmentPack = {
    enabled = true,
    manifest = 'stream/blank_templates/manifest.json',
    strictMode = false, -- true: only manifest slots are used, false: merge with default Config.RuntimeTextures slots
}

Config.Marketplace = {
    enabled = true,
    minPrice = 1000,
    maxPrice = 250000,
    defaultPrice = 5000,
    sellerCommissionPercent = 70, -- seller gets this percent, rest is server fee
    account = 'bank',
    requireApproval = false, -- true = admin must approve listings manually in DB/admin workflow
    printOnPurchase = true,
    allowOwnPurchase = false,
    maxListingsPerPlayer = 40,
    listingLimit = 100
}

Config.Security = {
    maxLayersPerDesign = 80,
    maxDesignJsonBytes = 900000,
    maxPreviewBytes = 6 * 1024 * 1024,
    rateLimits = {
        saveDesign = { windowSeconds = 10, max = 5 },
        printDesign = { windowSeconds = 15, max = 3 },
        publishDesign = { windowSeconds = 30, max = 5 },
        buyMarketplace = { windowSeconds = 10, max = 4 }
    }
}

Config.Audit = {
    enabled = true,
    discordWebhook = '', -- optional admin log webhook
    logSaveDesign = false,
    logPrintDesign = true,
    logMarketplace = true,
    logAdminActions = true
}


Config.Healthcheck = {
    enabled = true,
    command = 'rrcs_health',
    selfTestCommand = 'rrcs_selftest',
    validateManifest = true,
    validateDatabase = true,
    validateRuntimeSlots = true,
    validateUploadBridge = true,
    validateAI = true,
    validateMarketplace = true,
    printRecommendations = true,
    autoRunOnResourceStart = false,
    warnIfUploadDisabled = true,
    warnIfAIEnabledWithoutUpload = true,
    expectedTables = {
        'realrpg_clothing_designs',
        'realrpg_clothing_equipped',
        'realrpg_clothing_design_slots',
        'realrpg_clothing_ai_history',
        'realrpg_clothing_marketplace',
        'realrpg_clothing_marketplace_sales',
        'realrpg_clothing_marketplace_payouts',
        'realrpg_clothing_audit_log'
    }
}


Config.Cache = {
    enabled = true,
    maxRuntimeHandles = 32,
    maxIdleSeconds = 900,
    autoCleanupIntervalSeconds = 120,
    textureCacheCommand = 'rrcs_texcache',
    clearTextureCacheCommand = 'rrcs_cleartexcache',
    versionCommand = 'rrcs_version'
}

Config.Maintenance = {
    enabled = true,
    command = 'rrcs_maintcheck',
    cleanupCommand = 'rrcs_cleanup_orphans',
    purgeCommand = 'rrcs_purgehistory',
    requireConfirmWord = 'CONFIRM',
    purgeAiHistoryDays = 30,
    purgeAuditLogDays = 90,
    purgeRejectedMarketplaceDays = 30,
    purgeUnpublishedMarketplaceDays = 60,
    dryRunByDefault = true,
    includeLargeBase64Report = true,
    largePreviewWarnBytes = 900000,
    largeDesignJsonWarnBytes = 900000
}

Config.Admin = {
    permission = 'realrpg.clothing.admin', -- add_ace group.admin realrpg.clothing.admin allow
    allowedJobs = { -- optional ingame fallback if ACE is not used
        admin = 0,
        owner = 0
    },
    slotCommand = 'rrcs_slots',
    textureDebugCommand = 'rrcs_texdebug',
    packCheckCommand = 'rrcs_packcheck',
    uploadCheckCommand = 'rrcs_uploadcheck',
    assetCheckCommand = 'rrcs_assetcheck',
    aiCheckCommand = 'rrcs_aicheck',
    marketCheckCommand = 'rrcs_marketcheck',
    claimMarketCommand = 'rrcs_claimmarket',
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
    textureCacheCommand = 'rrcs_texcache',
    clearTextureCacheCommand = 'rrcs_cleartexcache',
    versionCommand = 'rrcs_version'
}


Config.Release = {
    version = '1.3.0',
    build = 'final-integration',
    supportName = 'RealRPG Clothing Studio',
    recommendedFramework = 'esx',
    recommendedInventory = 'ox_inventory'
}
