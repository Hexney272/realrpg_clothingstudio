--[[
    RealRPG Clothing Studio - Boot / Auto-Migration / Auto-Scan
    
    Ez a fájl a resource indításakor fut le és:
    1. Automatikusan létrehozza/migrálja az adatbázis táblákat
    2. Auto-scan: felismeri a stream/blank_templates/ mappában lévő .ydd fájlokat
    3. Kiírja a boot banner-t a konzolra
]]

local resourceName = GetCurrentResourceName()

-- ═══════════════════════════════════════════════════════════════
-- AUTO-MIGRATE: Adatbázis táblák létrehozása induláskor
-- ═══════════════════════════════════════════════════════════════

local function runMigration()
    local queries = {
        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_designs` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `design_id` VARCHAR(64) NOT NULL,
            `owner_identifier` VARCHAR(80) NOT NULL,
            `owner_name` VARCHAR(80) DEFAULT NULL,
            `label` VARCHAR(80) NOT NULL DEFAULT 'Untitled Design',
            `status` ENUM('draft','published','archived') NOT NULL DEFAULT 'draft',
            `gender` VARCHAR(16) NOT NULL,
            `category` VARCHAR(32) NOT NULL,
            `template_id` VARCHAR(64) NOT NULL,
            `design_json` LONGTEXT NOT NULL,
            `preview_data` LONGTEXT DEFAULT NULL,
            `image_url` TEXT DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `design_id` (`design_id`),
            KEY `owner_identifier` (`owner_identifier`),
            KEY `status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_equipped` (
            `identifier` VARCHAR(80) NOT NULL,
            `category` VARCHAR(32) NOT NULL,
            `design_id` VARCHAR(64) NOT NULL,
            `metadata` LONGTEXT NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`, `category`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_design_slots` (
            `design_id` VARCHAR(64) NOT NULL,
            `category` VARCHAR(32) NOT NULL,
            `runtime_slot` INT NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`design_id`),
            KEY `category` (`category`),
            KEY `runtime_slot` (`runtime_slot`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_marketplace` (
            `design_id` VARCHAR(64) NOT NULL,
            `owner_identifier` VARCHAR(80) NOT NULL,
            `price` INT NOT NULL DEFAULT 5000,
            `status` ENUM('pending','approved','rejected','unpublished') NOT NULL DEFAULT 'approved',
            `is_public` TINYINT(1) NOT NULL DEFAULT 1,
            `sold_count` INT NOT NULL DEFAULT 0,
            `moderated_by` VARCHAR(80) DEFAULT NULL,
            `moderation_reason` TEXT DEFAULT NULL,
            `moderated_at` TIMESTAMP NULL DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`design_id`),
            KEY `owner_identifier` (`owner_identifier`),
            KEY `status_public` (`status`, `is_public`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_marketplace_sales` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `design_id` VARCHAR(64) NOT NULL,
            `seller_identifier` VARCHAR(80) NOT NULL,
            `buyer_identifier` VARCHAR(80) NOT NULL,
            `buyer_name` VARCHAR(80) DEFAULT NULL,
            `price` INT NOT NULL,
            `seller_amount` INT NOT NULL,
            `server_fee` INT NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `design_id` (`design_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_marketplace_payouts` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(80) NOT NULL,
            `amount` INT NOT NULL,
            `sale_id` INT DEFAULT NULL,
            `status` ENUM('pending','paid') NOT NULL DEFAULT 'pending',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `paid_at` TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `identifier_status` (`identifier`, `status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_audit_log` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `actor_identifier` VARCHAR(80) DEFAULT NULL,
            `actor_name` VARCHAR(80) DEFAULT NULL,
            `action` VARCHAR(80) NOT NULL,
            `target_identifier` VARCHAR(80) DEFAULT NULL,
            `design_id` VARCHAR(64) DEFAULT NULL,
            `amount` INT DEFAULT NULL,
            `details` TEXT DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `action` (`action`),
            KEY `created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
    }

    -- Safe migrations (ALTER IF NOT EXISTS nem támogatott minden MySQL verzióban, pcall-al futtatjuk)
    local migrations = {
        "ALTER TABLE `realrpg_clothing_designs` ADD COLUMN `status` ENUM('draft','published','archived') NOT NULL DEFAULT 'draft' AFTER `label`",
        "ALTER TABLE `realrpg_clothing_designs` ADD COLUMN `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`",
        "ALTER TABLE `realrpg_clothing_design_slots` ADD UNIQUE KEY `category_runtime_slot` (`category`, `runtime_slot`)",
    }

    local success = 0
    local errors = 0

    for _, query in ipairs(queries) do
        local ok, err = pcall(MySQL.query.await, query)
        if ok then
            success = success + 1
        else
            errors = errors + 1
            if Config.Debug then
                print(('[^1RealRPG Boot^0] Migration error: %s'):format(tostring(err):sub(1, 200)))
            end
        end
    end

    -- Safe ALTER migrations (hibát ignoráljuk ha a column/key már létezik)
    for _, query in ipairs(migrations) do
        pcall(MySQL.query.await, query)
    end

    return success, errors
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO-SCAN: .ydd fájlok felismerése a stream mappából
-- ═══════════════════════════════════════════════════════════════

local function autoScanTemplates()
    -- A manifest.json-t olvassuk be - az tartalmazza a regisztrált slotokat
    -- Emellett a fxmanifest.lua stream/**/* pattern automatikusan streameli a fájlokat
    
    local scanned = 0
    local manifestPath = (Config.GarmentPack and Config.GarmentPack.manifest) or 'stream/blank_templates/manifest.json'
    local raw = LoadResourceFile(resourceName, manifestPath)
    
    if raw and raw ~= '' then
        local ok, manifest = pcall(json.decode, raw)
        if ok and manifest then
            -- Számoljuk a regisztrált slotokat
            for category, slots in pairs(manifest.runtimeSlots or {}) do
                if type(slots) == 'table' then
                    scanned = scanned + #slots
                end
            end
        end
    end

    -- Ellenőrizzük a Config.RuntimeTextures.slots-ot is
    local configSlots = 0
    if Config.RuntimeTextures and Config.RuntimeTextures.slots then
        for _, slots in pairs(Config.RuntimeTextures.slots) do
            if type(slots) == 'table' then
                configSlots = configSlots + #slots
            end
        end
    end

    return math.max(scanned, configSlots)
end

-- ═══════════════════════════════════════════════════════════════
-- BOOT SEQUENCE
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    -- Várunk hogy az oxmysql teljesen elérhető legyen
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(100)
    end
    Wait(500)

    print('')
    print('^2==========================================================^0')
    print('^2[realrpg_clothingstudio]^0 Booting...')
    print('^2==========================================================^0')

    -- 1) Auto-migrate
    local tableCount, errCount = runMigration()
    if errCount == 0 then
        print(('[^2RealRPG Boot^0] Adatbázis OK (%d tábla ellenőrizve/létrehozva)'):format(tableCount))
    else
        print(('[^1RealRPG Boot^0] Adatbázis: %d OK, %d hiba - ellenőrizd az oxmysql kapcsolatot!'):format(tableCount, errCount))
    end

    -- 2) Auto-scan templates
    local slotCount = autoScanTemplates()
    if slotCount > 0 then
        print(('[^2RealRPG Boot^0] Garment slotok: %d felismert ruha sablon'):format(slotCount))
    else
        print('[^3RealRPG Boot^0] FIGYELEM: Nincs garment slot konfigurálva! Tedd be a .ydd/.ytd fájlokat a stream/blank_templates/ mappába.')
    end

    -- 3) Template manifest betöltés
    if Templates and Templates.LoadPackManifest then
        Templates.LoadPackManifest()
    end

    -- 4) Összegzés
    local version = (Config.Release and Config.Release.version) or GetResourceMetadata(resourceName, 'version', 0) or '?'
    local framework = RRFW and RRFW.Name or 'unknown'
    local inventory = Config.Inventory or 'unknown'
    local marketplace = Config.Marketplace and Config.Marketplace.enabled and 'AKTÍV' or 'KIKAPCSOLVA'
    local upload = (UploadBridge and UploadBridge.IsEnabled and UploadBridge.IsEnabled()) and 'AKTÍV' or 'KIKAPCSOLVA'

    print('')
    print(('[^2RealRPG Boot^0] ═══════════════════════════════════════'))
    print(('[^2RealRPG Boot^0]   RealRPG Clothing Studio v%s'):format(version))
    print(('[^2RealRPG Boot^0]   Framework: %s | Inventory: %s'):format(framework, inventory))
    print(('[^2RealRPG Boot^0]   Marketplace: %s | Upload: %s'):format(marketplace, upload))
    print(('[^2RealRPG Boot^0]   Garment slotok: %d'):format(slotCount))
    print(('[^2RealRPG Boot^0]   Parancs: /%s'):format(Config.OpenCommand or 'clothingstudio'))
    print(('[^2RealRPG Boot^0] ═══════════════════════════════════════'))
    print(('[^2RealRPG Boot^0]   Kész! Használd: /rrcs_selftest'))
    print('^2==========================================================^0')
    print('')
end)
