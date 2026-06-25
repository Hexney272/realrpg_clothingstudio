# RealRPG Clothing Studio v1.2 - Maintenance & Texture Cache

This phase adds production maintenance commands and a safer client runtime texture cache.

## New server maintenance commands

```txt
/rrcs_maintcheck
/rrcs_cleanup_orphans
/rrcs_cleanup_orphans CONFIRM
/rrcs_purgehistory 30
/rrcs_purgehistory 30 CONFIRM
```

### `/rrcs_maintcheck`
Prints a production maintenance report into F8:

- orphan runtime slots
- stale equipped rows
- large `preview_data` rows
- large `design_json` rows
- old AI prompt history rows
- old audit log rows
- old rejected/unpublished marketplace rows
- pending marketplace payout count and total
- recent audit actions

### `/rrcs_cleanup_orphans`
Dry-run by default. It shows how many rows would be removed.

### `/rrcs_cleanup_orphans CONFIRM`
Deletes:

- rows in `realrpg_clothing_design_slots` where the design no longer exists
- rows in `realrpg_clothing_equipped` where the design no longer exists

### `/rrcs_purgehistory 30`
Dry-run by default. Shows how many rows older than 30 days would be purged.

### `/rrcs_purgehistory 30 CONFIRM`
Deletes old:

- AI prompt history
- audit logs
- rejected marketplace rows
- unpublished marketplace rows

## New client texture cache commands

```txt
/rrcs_texcache
/rrcs_cleartexcache
```

### `/rrcs_texcache`
Prints the current DUI/runtime texture cache state.

### `/rrcs_cleartexcache`
Destroys every active DUI handle and removes every texture replacement.
Useful while testing blank garment packs or after heavy marketplace browsing.

## New config

```lua
Config.Cache = {
    enabled = true,
    maxRuntimeHandles = 32,
    maxIdleSeconds = 900,
    autoCleanupIntervalSeconds = 120,
    textureCacheCommand = 'rrcs_texcache',
    clearTextureCacheCommand = 'rrcs_cleartexcache'
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
```

## Recommended production routine

- Run `/rrcs_selftest` after every restart.
- Run `/rrcs_maintcheck` weekly.
- Use `/rrcs_cleanup_orphans CONFIRM` after deleting old designs manually.
- Use `/rrcs_purgehistory 60 CONFIRM` monthly if you do not need old AI/audit data.
- Use `/rrcs_texcache` while testing runtime texture issues.
