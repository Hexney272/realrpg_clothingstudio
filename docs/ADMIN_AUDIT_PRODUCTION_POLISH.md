# RealRPG Clothing Studio v1.0 - Admin / Audit / Production Polish

## Mi került bele

A v1.0 célja, hogy a marketplace és AI rendszer ne csak látványos legyen, hanem szerver oldalon is jobban kezelhető, naplózható és moderálható legyen.

### Admin jogosultság

Alap ACE permission:

```cfg
add_ace group.admin realrpg.clothing.admin allow
```

Config:

```lua
Config.Admin.permission = 'realrpg.clothing.admin'
```

Opcionális job fallback:

```lua
Config.Admin.allowedJobs = {
    admin = 0,
    owner = 0
}
```

## Új admin parancsok

```txt
/rrcs_admincheck
/rrcs_pending [limit]
/rrcs_approve designId
/rrcs_reject designId indok
/rrcs_takedown designId indok
/rrcs_audit [limit]
```

### Marketplace approval flow

Ha ezt bekapcsolod:

```lua
Config.Marketplace.requireApproval = true
```

akkor a játékos publikálás után csak `pending` státuszt kap. Admin jóváhagyás után kerül ki a MARKET tabba.

```txt
/rrcs_pending
/rrcs_approve rr_123456_1_9999
/rrcs_reject rr_123456_1_9999 Nem megfelelő design
```

### Takedown

Ha egy design már kikerült, de később le kell venni:

```txt
/rrcs_takedown rr_123456_1_9999 Szabályszegő tartalom
```

## Audit log

Új SQL tábla:

```sql
realrpg_clothing_audit_log
```

Naplózott események:

- marketplace publish
- marketplace buy
- marketplace unpublish
- admin approve
- admin reject
- admin takedown
- opcionálisan design save / print

Config:

```lua
Config.Audit = {
    enabled = true,
    discordWebhook = '',
    logSaveDesign = false,
    logPrintDesign = true,
    logMarketplace = true,
    logAdminActions = true
}
```

## Security / rate limits

Config:

```lua
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
```

Ez csökkenti annak esélyét, hogy valaki spameli a mentést, printet vagy marketplace vásárlást.

## Fontos telepítési lépés

A v1.0 SQL részt is futtasd le. Ha régi adatbázisod van, a végén lévő `ALTER TABLE` sorok adják hozzá az új moderation oszlopokat.
