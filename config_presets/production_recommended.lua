-- Recommended production switches once your webhook/API/garment pack is ready.

Config.Debug = false

Config.UploadBridge.enabled = true
Config.UploadBridge.provider = 'discord'
Config.UploadBridge.discordWebhook = 'PUT_YOUR_WEBHOOK_HERE'
Config.UploadBridge.uploadLayerAssets = true
Config.UploadBridge.failLayerUploadIfUploadFails = false

Config.AI.enabled = false -- turn true only after API key is configured
Config.AI.uploadResultToCdn = true
Config.AI.cooldownSeconds = 60

Config.Marketplace.enabled = true
Config.Marketplace.requireApproval = true

Config.Admin.auditDiscordWebhook = 'PUT_ADMIN_AUDIT_WEBHOOK_HERE'

Config.Cache.enabled = true
Config.Maintenance.enabled = true
Config.Healthcheck.enabled = true
