# RealRPG Clothing Studio v1.3

Premium ingame clothing creator for FiveM with ESX/QBCore/Qbox foundation support and ox_inventory integration.

## Main features

- Fullscreen clothing studio UI
- Layer editor: images, text, shapes, brush, paste/upload
- My Designs library
- Printed clothing items with metadata
- Runtime texture foundation
- Runtime slot management
- Garment pack manifest workflow
- Discord/CDN upload bridge
- Layer asset upload
- Gemini AI design bridge
- Marketplace / shop system
- Seller commission and payout queue
- Admin approval / reject / takedown
- Audit log and optional Discord audit webhook
- Healthcheck / selftest
- Maintenance and texture cache cleanup

## Install

Read first:

```txt
INSTALL.md
TROUBLESHOOTING.md
RELEASE_NOTES.md
```

Quick start:

```cfg
ensure oxmysql
ensure ox_inventory
ensure realrpg_clothingstudio
add_ace group.admin realrpg.clothing.admin allow
```

Run SQL:

```txt
sql/install.sql
```

Add ox_inventory items:

```txt
examples/ox_inventory_items.lua
```

First server check:

```txt
/rrcs_version
/rrcs_selftest
/rrcs_health
```

## Important

The script-side system is production close. For the actual custom print to visibly appear on GTA clothing, you still need a streamed blank garment pack with matching `.ydd/.ytd` texture names.

See:

```txt
docs/BLANK_GARMENT_TEMPLATE_GUIDE.md
docs/ADDON_CLOTHING_PACK_WORKFLOW.md
stream/blank_templates/manifest.json
```
