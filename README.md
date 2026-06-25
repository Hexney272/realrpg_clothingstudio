# RealRPG Clothing Studio v0.2.0

Ingame clothing creator/designer FiveM resource with **DUI runtime texture projection**.

ESX / QBCore / Qbox auto-detection + ox_inventory support.

## Features

- **NUI Canvas Editor** – Layer-based design editor (images, text, shapes, undo/redo)
- **DUI Runtime Texture** – Egyedi textúra rávetítés blank garment slotokra, minden játékosnál látható
- **Live Preview** – Szerkesztés közben real-time előnézet a karakter ruháján
- **Proximity Sync** – Közeli játékosok automatikusan látják egymás egyedi ruháit
- **ox_inventory** – Nyomtatott ruha item metadata-val (felvehető, levetkőztethető)
- **Persistence** – Viselt ruhák mentése/visszaállítása spawn-kor
- **Multi-framework** – ESX, QBCore, Qbox automatikus felismerés
- **Fallback mód** – DUI nélkül is működik (component swap)

## Architektúra

```
┌─────────────────────────────────────────────────────────────┐
│  NUI Canvas Editor (web/app.js)                             │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │ Layer Editor │───▶│ Canvas Render│───▶│ base64 export │  │
│  └─────────────┘    └──────────────┘    └───────┬───────┘  │
└─────────────────────────────────────────────────│───────────┘
                                                  │ NUI Callback
┌─────────────────────────────────────────────────▼───────────┐
│  Client (Lua)                                               │
│  ┌──────────┐    ┌─────────────────┐    ┌────────────────┐  │
│  │ DUI.lua  │───▶│ dui_render.html │───▶│ DUI Handle     │  │
│  └──────────┘    └─────────────────┘    └───────┬────────┘  │
│  ┌──────────────────┐                           │            │
│  │runtime_texture.lua│◀──────────────────────────┘            │
│  │ CreateRuntimeTxd  │                                       │
│  │ AddReplaceTexture │──▶ Blank Garment textúra lecserélve   │
│  └──────────────────┘                                       │
│  ┌──────────────┐                                           │
│  │ wearables.lua │ ← Kezeli saját + távoli ped-ek           │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
                         │ Server Events (broadcast)
┌────────────────────────▼────────────────────────────────────┐
│  Server                                                     │
│  - equippedCache (memória)                                  │
│  - DB persistence                                           │
│  - Broadcast syncWearable to all clients                    │
└─────────────────────────────────────────────────────────────┘
```

## Telepítés

1. Másold a `realrpg_clothingstudio` mappát a resources mappába.

2. Futtasd az `sql/install.sql` fájlt az adatbázisban.

3. Add hozzá a server.cfg-hez:
   ```cfg
   ensure oxmysql
   ensure ox_inventory
   ensure realrpg_clothingstudio
   ```

4. ox_inventory `data/items.lua` példa:
   ```lua
   ['printed_tshirt'] = {
       label = 'Printed T-Shirt',
       weight = 250,
       stack = false,
       close = true,
       description = 'Egyedi nyomtatott póló'
   },
   ['printed_undershirt'] = {
       label = 'Printed Undershirt',
       weight = 250,
       stack = false,
       close = true
   },
   ['printed_pants'] = {
       label = 'Printed Pants',
       weight = 350,
       stack = false,
       close = true
   },
   ['printed_shoes'] = {
       label = 'Printed Shoes',
       weight = 500,
       stack = false,
       close = true
   },
   ```

5. **Blank garment fájlok**: Helyezd a `.ytd` fájlokat a `stream/` mappába.
   Részletes útmutató: `stream/README.md`

6. Parancs: `/clothingstudio`, vagy menj a `Config.Stations` koordinátához és nyomj E-t.

## Konfiguráció

Lásd `config.lua` – főbb beállítások:

| Beállítás | Leírás | Alapértelmezett |
|-----------|--------|-----------------|
| `Config.DUI.enabled` | DUI runtime texture engedélyezés | `true` |
| `Config.DUI.maxActive` | Max párhuzamos DUI textúra | `12` |
| `Config.DUI.renderDistance` | Meddig lássák mások a designt | `50.0` |
| `Config.DUI.poolSize` | Újrahasznosítható DUI pool | `4` |
| `Config.Printing.price` | Nyomtatás ára | `2500` |
| `Config.Framework` | auto / esx / qb / qbox | `'auto'` |

## DUI nélküli mód (Fallback)

Ha még nincs kész blank garment `.ytd`:
- Állítsd `Config.DUI.enabled = false`-ra
- A rendszer component swap-ot használ (vanilla drawable cserével)
- Minden más funkció (editor, mentés, item, inventory) teljesen működik

## Fájlstruktúra

```
realrpg_clothingstudio/
├── client/
│   ├── dui.lua              DUI lifecycle manager (pool, create/destroy)
│   ├── runtime_texture.lua  Runtime texture replace (AddReplaceTexture)
│   ├── main.lua             Station interact, marker, command
│   ├── studio.lua           NUI open/close controller
│   ├── wearables.lua        Item equip, DUI apply, sync
│   └── preview.lua          Live preview DUI a stúdióban
├── server/
│   ├── main.lua             Requests, save, print, broadcast sync
│   ├── database.lua         MySQL queries
│   ├── framework.lua        ESX/QB/Qbox helpers
│   └── inventory.lua        ox_inventory integration
├── shared/
│   ├── garments.lua         Blank garment slot definitions (txd/txn)
│   ├── templates.lua        Ruha sablonok (garmentId linkkel)
│   └── framework.lua        Auto-detect ESX/QB/Qbox
├── web/
│   ├── index.html           NUI editor layout
│   ├── style.css            Editor stílusok
│   ├── app.js               Canvas editor, layers, NUI messaging
│   ├── dui_render.html      DUI textúra renderelő (standalone page)
│   └── assets/              Preview + UV placeholder képek
├── sql/install.sql           Adatbázis séma
├── stream/                   Blank garment .ytd/.ydd fájlok (kézzel kell elkészíteni)
├── config.lua                Teljes konfiguráció
└── fxmanifest.lua            Resource manifest
```

## Következő fejlesztési lépések

- [ ] Valódi blank garment `.ytd` fájlok elkészítése (OpenIV/CodeWalker)
- [ ] Discord webhook / CDN upload bridge nagy preview képekhez
- [ ] Gemini AI server-side design generálás
- [ ] My Designs panel teljes betöltés/megnyitás a NUI-ban
- [ ] ox_target támogatás designer station-höz
- [ ] NUI throttled preview (canvas -> DUI debounce optimalizáció)
- [ ] Több garment slot (kalapok, kesztyűk, kiegészítők)
