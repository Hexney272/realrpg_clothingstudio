CREATE TABLE IF NOT EXISTS `realrpg_clothing_designs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `design_id` VARCHAR(64) NOT NULL,
  `owner_identifier` VARCHAR(80) NOT NULL,
  `owner_name` VARCHAR(80) DEFAULT NULL,
  `label` VARCHAR(80) NOT NULL DEFAULT 'Untitled Design',
  `gender` VARCHAR(16) NOT NULL,
  `category` VARCHAR(32) NOT NULL,
  `template_id` VARCHAR(64) NOT NULL,
  `design_json` LONGTEXT NOT NULL,
  `preview_data` LONGTEXT DEFAULT NULL,
  `image_url` TEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `design_id` (`design_id`),
  KEY `owner_identifier` (`owner_identifier`)
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

-- Safe migration helpers for older installs:
-- ALTER TABLE `realrpg_clothing_designs` ADD COLUMN `image_url` TEXT DEFAULT NULL;


-- v0.5 migration helper for older installs. Run manually if your table already exists and lacks the unique key:
-- ALTER TABLE `realrpg_clothing_design_slots` ADD UNIQUE KEY `category_runtime_slot` (`category`, `runtime_slot`);


CREATE TABLE IF NOT EXISTS `realrpg_clothing_ai_history` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(80) NOT NULL,
  `player_name` VARCHAR(80) DEFAULT NULL,
  `prompt` TEXT NOT NULL,
  `negative_prompt` TEXT DEFAULT NULL,
  `result_url` TEXT DEFAULT NULL,
  `error` VARCHAR(120) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `identifier` (`identifier`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- v0.9 marketplace / shop system
CREATE TABLE IF NOT EXISTS `realrpg_clothing_marketplace` (
  `design_id` VARCHAR(64) NOT NULL,
  `owner_identifier` VARCHAR(80) NOT NULL,
  `price` INT NOT NULL DEFAULT 5000,
  `status` ENUM('pending','approved','rejected','unpublished') NOT NULL DEFAULT 'approved',
  `is_public` TINYINT(1) NOT NULL DEFAULT 1,
  `sold_count` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`design_id`),
  KEY `owner_identifier` (`owner_identifier`),
  KEY `status_public` (`status`, `is_public`),
  KEY `price` (`price`)
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
  KEY `design_id` (`design_id`),
  KEY `seller_identifier` (`seller_identifier`),
  KEY `buyer_identifier` (`buyer_identifier`)
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
  KEY `identifier_status` (`identifier`, `status`),
  KEY `sale_id` (`sale_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- v1.0 production polish / admin moderation / audit log
ALTER TABLE `realrpg_clothing_marketplace`
  ADD COLUMN IF NOT EXISTS `moderated_by` VARCHAR(80) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `moderation_reason` TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `moderated_at` TIMESTAMP NULL DEFAULT NULL;

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
  KEY `design_id` (`design_id`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
