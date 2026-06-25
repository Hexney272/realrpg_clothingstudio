CREATE TABLE IF NOT EXISTS `realrpg_clothing_designs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `design_id` VARCHAR(64) NOT NULL,
  `owner_identifier` VARCHAR(80) NOT NULL,
  `owner_name` VARCHAR(80) DEFAULT NULL,
  `label` VARCHAR(80) NOT NULL DEFAULT 'Untitled Design',
  `gender` VARCHAR(16) NOT NULL,
  `category` VARCHAR(32) NOT NULL,
  `template_id` VARCHAR(64) NOT NULL,
  `garment_id` VARCHAR(64) DEFAULT '',
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

-- Migration: ha már létezik a tábla garment_id nélkül
-- ALTER TABLE `realrpg_clothing_designs` ADD COLUMN `garment_id` VARCHAR(64) DEFAULT '' AFTER `template_id`;
