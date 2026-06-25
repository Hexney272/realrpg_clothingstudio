# RealRPG Clothing Studio v1.3 — Final Install Guide

Ez a csomag a RealRPG Clothing Studio final integration buildje. A script oldalról tartalmazza a clothing designert, layer rendszert, ox_inventory itemeket, runtime texture foundationt, upload bridge-et, AI bridge-et, marketplace-t, admin/audit rendszert, healthchecket és maintenance parancsokat.

## 1. Kötelező resource-ok

```cfg
ensure oxmysql
ensure ox_inventory
ensure realrpg_clothingstudio
```

Framework támogatás:

- ESX Legacy — ajánlott nálad
- QBCore
- Qbox alap detection

## 2. SQL telepítés

Futtasd:

```txt
realrpg_clothingstudio/sql/install.sql
```

Új telepítésnél egyben elég. Ha korábbi verzióról frissítesz, a fájl idempotens táblákat használ, de éles adatbázis előtt mindig készíts mentést.

## 3. ox_inventory itemek

Másold be az `examples/ox_inventory_items.lua` tartalmát az ox_inventory `data/items.lua` fájlba.

## 4. server.cfg példa

Az `examples/server.cfg.example` fájlban van copy-paste blokk ACE joggal együtt.

Minimum:

```cfg
ensure oxmysql
ensure ox_inventory
ensure realrpg_clothingstudio
add_ace group.admin realrpg.clothing.admin allow
```

## 5. Első indítás után

Szerveren vagy F8 konzolban futtasd:

```txt
/rrcs_version
/rrcs_selftest
/rrcs_health
/rrcs_packcheck
/rrcs_uploadcheck
```

Ha a selftest `WARN`, az még nem feltétlen hiba. Például upload bridge vagy AI kikapcsolva lehet production döntés. Ha `FAIL`, nézd meg a health riportot.

## 6. Upload bridge bekapcsolás

Discord webhook esetén a webhook URL csak szerver oldalon legyen a configban.

```lua
Config.UploadBridge.enabled = true
Config.UploadBridge.provider = 'discord'
Config.UploadBridge.discordWebhook = 'IDE_A_WEBHOOK_URL'
Config.UploadBridge.uploadLayerAssets = true
```

## 7. AI bridge bekapcsolás

```lua
Config.AI.enabled = true
Config.AI.apiKey = 'IDE_A_GEMINI_API_KEY'
Config.AI.uploadResultToCdn = true
```

AI használathoz erősen ajánlott az upload bridge is, mert így az AI output URL-ként kerül layerbe.

## 8. Marketplace approval

Ha admin jóváhagyást akarsz:

```lua
Config.Marketplace.requireApproval = true
```

Admin parancsok:

```txt
/rrcs_pending
/rrcs_approve designId
/rrcs_reject designId indok
/rrcs_takedown designId indok
```

## 9. Blank garment pack

A script már fel van készítve a blank garment packre, de a valódi GTA `.ydd/.ytd` ruhafájlokat külön kell streamelni.

A lényeg:

```txt
manifest txd/txn == ytd texture dictionary/name
```

Nézd meg:

```txt
docs/BLANK_GARMENT_TEMPLATE_GUIDE.md
docs/ADDON_CLOTHING_PACK_WORKFLOW.md
stream/blank_templates/manifest.json
```

## 10. Javasolt production indulási sorrend

1. SQL import
2. ox_inventory itemek
3. server.cfg ACE + ensure sorrend
4. config.lua webhook/API kulcsok nélkül első próba
5. `/rrcs_selftest`
6. upload bridge bekapcsolása
7. AI bridge bekapcsolása
8. marketplace approval eldöntése
9. blank garment pack teszt
10. élő szerver restart
