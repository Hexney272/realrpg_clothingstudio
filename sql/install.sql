-- ═══════════════════════════════════════════════════════════════
-- RealRPG Clothing Studio v1.2.0 - Database Schema
-- Run this SQL to manually create tables (auto-migration also runs on boot)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `realrpg_clothing_designs` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_equipped` (
    `identifier` VARCHAR(80) NOT NULL,
    `category` VARCHAR(32) NOT NULL,
    `design_id` VARCHAR(64) NOT NULL,
    `metadata` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`, `category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_design_slots` (
    `design_id` VARCHAR(64) NOT NULL,
    `category` VARCHAR(32) NOT NULL,
    `runtime_slot` INT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`design_id`),
    KEY `category` (`category`),
    KEY `runtime_slot` (`runtime_slot`),
    UNIQUE KEY `category_runtime_slot` (`category`, `runtime_slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_marketplace` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_marketplace_sales` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_marketplace_payouts` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(80) NOT NULL,
    `amount` INT NOT NULL,
    `sale_id` INT DEFAULT NULL,
    `status` ENUM('pending','paid') NOT NULL DEFAULT 'pending',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `identifier_status` (`identifier`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_audit_log` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_ai_history` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(80) NOT NULL,
    `prompt` TEXT NOT NULL,
    `result_url` TEXT DEFAULT NULL,
    `provider` VARCHAR(32) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `identifier` (`identifier`),
    KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
