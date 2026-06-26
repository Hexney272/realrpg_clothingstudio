# RealRPG Clothing Studio – Telepítési Útmutató

## 1. lépés: Szerverre helyezés

Helyezd a `realrpg_clothingstudio` mappát a szervered `resources/` könyvtárába.

Add hozzá a `server.cfg`-hez, az oxmysql és a framework **után**:

```cfg
ensure oxmysql
ensure es_extended      # vagy qb-core / qbx_core
ensure ox_inventory     # a te custom inventory-d (ox_bridge kompatibilis)
ensure realrpg_clothingstudio
```

A `realrpg_clothingstudio`-nak az oxmysql és a framework **után** kell indulnia.

---

## 2. lépés: Adatbázis

A resource első induláskor **automatikusan létrehozza** az összes szükséges táblát. Csak ellenőrizd, hogy az oxmysql elérhető.

Ha kézzel szeretnéd előre létrehozni a sémát:

```bash
mysql -u YOUR_USER -p YOUR_DB < resources/realrpg_clothingstudio/sql/install.sql
```

---

## 3. lépés: Inventory Item hozzáadása

A nyomtatott ruha itemeket hozzá kell adni az inventory rendszeredhez.

### seerpg_inventory (ox_inventory kompatibilis) – `shared/items.lua`

```lua
['printed_tshirt'] = {
    name = 'printed_tshirt',
    label = 'Nyomtatott Póló',
    weight = 250,
    stack = false,
    close = true,
    usable = true,
    description = 'Egyedi nyomtatott póló a RealRPG Clothing Studio-ból.',
    server = {
        export = 'realrpg_clothingstudio.UseClothingItem'
    }
},

['printed_undershirt'] = {
    name = 'printed_undershirt',
    label = 'Nyomtatott Alsó Felső',
    weight = 250,
    stack = false,
    close = true,
    usable = true,
    description = 'Egyedi nyomtatott alsó felső.',
    server = {
        export = 'realrpg_clothingstudio.UseClothingItem'
    }
},

['printed_pants'] = {
    name = 'printed_pants',
    label = 'Nyomtatott Nadrág',
    weight = 350,
    stack = false,
    close = true,
    usable = true,
    description = 'Egyedi nyomtatott nadrág.',
    server = {
        export = 'realrpg_clothingstudio.UseClothingItem'
    }
},

['printed_shoes'] = {
    name = 'printed_shoes',
    label = 'Nyomtatott Cipő',
    weight = 500,
    stack = false,
    close = true,
    usable = true,
    description = 'Egyedi nyomtatott cipő.',
    server = {
        export = 'realrpg_clothingstudio.UseClothingItem'
    }
},
```

> **Megjegyzés:** A `server.export` mező biztosítja, hogy az item használatakor a clothing studio `UseClothingItem` exportja hívódik meg, ami felveszi a ruhát a karakterre. A `RegisterUsableItem` is működik alternatívaként (az ox_bridge támogatja).

### ESX (ha nem ox_inventory-t használsz) – adatbázis

```sql
INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES
('printed_tshirt', 'Nyomtatott Póló', 1),
('printed_undershirt', 'Nyomtatott Alsó Felső', 1),
('printed_pants', 'Nyomtatott Nadrág', 1),
('printed_shoes', 'Nyomtatott Cipő', 1);
```

Az item név konfigurálható: `config.lua` → `Config.Printing.items`.

---

## 4. lépés: Konfiguráció

### Alap beállítások (`config.lua`)

```lua
Config.Framework = 'auto'          -- auto / esx / qb / qbox
Config.Inventory = 'ox_inventory'  -- a te rendszered ox_bridge-en keresztül
Config.OpenCommand = 'clothingstudio'
Config.UseCommand = true
Config.UseTarget = false           -- true = ox_target használat marker helyett
```

### Designer Statiok & Job Gating

```lua
Config.Stations = {
    {
        label = 'RealRPG Clothing Studio',
        coords = vec3(72.30, -1399.10, 29.38),
        radius = 2.0,
        job = nil,     -- nil = mindenki használhatja
        grade = 0
    },
    {
        label = 'Burger Shot Designer',
        coords = vec3(-1198.20, -894.40, 13.90),
        radius = 2.0,
        job = 'burgershot',   -- csak burgershot dolgozók
        grade = 2             -- minimum grade
    }
}
```

A `job = nil` bejegyzés mindenki számára elérhetővé teszi a stationt.

### Upload Bridge (Discord CDN)

```lua
Config.UploadBridge = {
    enabled = false,                -- true = Discord CDN-re tölt fel
    provider = 'discord',
    discordWebhook = '',            -- Discord webhook URL ide
    chunkSize = 240000,
    maxDataUrlBytes = 6 * 1024 * 1024,
    uploadLayerAssets = true,       -- képrétegek feltöltése CDN-re
}
```

A Discord webhook nélkül a design preview-k base64-ként tárolódnak az adatbázisban (működik, de nagyobb DB méret).

### Nyomtatás ára

```lua
Config.Printing = {
    enabled = true,
    price = 2500,           -- ár dollárban
    account = 'money',      -- money / bank
    items = {
        tops = 'printed_tshirt',
        undershirt = 'printed_undershirt',
        pants = 'printed_pants',
        shoes = 'printed_shoes'
    }
}
```

---

## 5. lépés: Ruha Sablonok (Blank Garments)

### Fájl elhelyezés

A `.ydd` (modell) és `.ytd` (textúra) fájlokat a `stream/blank_templates/` mappába kell tenni:

```
stream/blank_templates/
├── jbib_000_u.ydd              (Póló #1 modell)
├── jbib_005_u.ydd              (Póló #2 modell)
├── jbib_007_u.ydd              (Póló #3 modell)
├── jbib_013_u.ydd              (Póló #4 modell)
├── jbib_diff_000_a_uni.ytd     (Póló #1 textúra - ezt cseréli a DUI)
├── jbib_diff_005_a_uni.ytd     (Póló #2 textúra)
├── jbib_diff_007_a_uni.ytd     (Póló #3 textúra)
├── jbib_diff_013_a_uni.ytd     (Póló #4 textúra)
└── manifest.json               (slot/template definíciók)
```

### Preview képek a NUI-hoz

A textúrák PNG exportjait a `web/assets/` mappába kell tenni (a NUI csak innen tud olvasni):

```
web/assets/
├── jbib_diff_000_a_uni.png     (OpenIV-vel exportált textúra)
├── jbib_diff_005_a_uni.png
├── jbib_diff_007_a_uni.png
├── jbib_diff_013_a_uni.png
```

Ezek jelennek meg:
- A sablon kiválasztó tile-okon (thumbnail)
- A canvas háttérben (UV guide – erre rajzolsz)
- Az élő előnézet panelben

### Új sablonok hozzáadása

1. Tedd be az új `.ydd` + `.ytd` fájlokat a `stream/blank_templates/`-be
2. Exportáld a textúrát PNG-be → `web/assets/`
3. Szerkeszd a `manifest.json`-t vagy a `config.lua` → `Config.RuntimeTextures.slots` részt
4. Restartold a servert

---

## 6. lépés: Szerver restart

Első indításkor a resource automatikusan:
- Létrehozza az adatbázis táblákat
- Betölti a garment manifest-et
- Regisztrálja a runtime texture slotokat

Két restart szükséges az első alkalommal:
1. Első restart: a resource betöltődik, stream fájlok regisztrálódnak
2. Második restart: a FiveM ténylegesen streameli a `.ydd`/`.ytd` fájlokat

Ezt követően minden boot azonnali.

---

## Jogosultságok (Opcionális)

Az admin parancsok alapból mindenki által futtathatók (read-only). A destruktív parancsokhoz ACE permission kell:

```cfg
add_ace group.admin realrpg.clothing.admin allow
```

Vagy job-alapú hozzáférés a `config.lua`-ban:

```lua
Config.Admin = {
    permission = 'realrpg.clothing.admin',
    allowedJobs = {
        admin = 0,
        owner = 0
    }
}
```

---

## Hibaelhárítás

| Probléma | Megoldás |
|----------|---------|
| Nem jelenik meg a studio | Ellenőrizd hogy a `Config.Stations` koordinátáknál vagy, vagy írd be: `/clothingstudio` |
| Nincs sablon a listában | Ellenőrizd a `stream/blank_templates/manifest.json` fájlt és a `.ydd` fájlokat |
| A textúra nem jelenik meg a canvason | A PNG-k a `web/assets/` mappában kell legyenek, NEM a `stream/`-ben! Restartold a resourcet. |
| Item nem adható hozzá | Ellenőrizd a `shared/items.lua`-ban az item definíciót és hogy az inventory elindul-e a clothing studio előtt |
| Nincs jogosultság admin parancsokhoz | Add hozzá: `add_ace group.admin realrpg.clothing.admin allow` |
| Runtime textúra nem jelenik meg a karakteren | Két restart kell az első alkalommal. Ellenőrizd a `txd`/`txn` neveket a config-ban. |
| Marketplace nem működik | `Config.Marketplace.enabled = true` és futtasd le az `sql/install.sql`-t |

---

## Admin Parancsok

| Parancs | Leírás |
|---------|--------|
| `/rrcs_selftest` | Teljes rendszer ellenőrzés (bárki futtathatja) |
| `/rrcs_health` | Részletes healthcheck riport |
| `/rrcs_version` | Verzió és build info |
| `/rrcs_slots` | Runtime slot foglaltság kiírása |
| `/rrcs_texdebug` | Aktív DUI texture handle-ek listázása |
| `/rrcs_packcheck` | Garment pack manifest ellenőrzés |
| `/rrcs_pending` | Jóváhagyásra váró marketplace listingek |
| `/rrcs_approve [designId]` | Marketplace design jóváhagyása |
| `/rrcs_reject [designId] [indok]` | Marketplace design elutasítása |
| `/rrcs_takedown [designId] [indok]` | Aktív listing levétele |
| `/rrcs_maintcheck` | Karbantartási riport |
| `/rrcs_cleanup_orphans [CONFIRM]` | Árva slotok/equipped sorok törlése |
| `/rrcs_purgehistory [napok] [CONFIRM]` | Régi audit/history törlése |
| `/rrcs_unwear [category\|all]` | Saját viselt ruha levétele |

---

## API & Exports

### Client Export

```lua
-- Studio megnyitása (station/job check nélkül)
exports['realrpg_clothingstudio']:OpenStudio(stationIndex)
```

### Server Export

```lua
-- Nyomtatott ruha item adása egy játékosnak
-- Használat: quest reward, admin tool, shop integráció
exports['realrpg_clothingstudio']:OpenStudio(source, stationIndex)
```

### Viselt ruha törlése (más resource-ból)

```lua
-- Egy kategória törlése
TriggerServerEvent('realrpg_clothingstudio:server:clearEquipped', 'tops')

-- Összes kategória törlése
TriggerServerEvent('realrpg_clothingstudio:server:clearEquipped', nil)
```

---

## Adatbázis Táblák

| Tábla | Tartalom |
|-------|----------|
| `realrpg_clothing_designs` | Mentett designok (JSON, preview, owner) |
| `realrpg_clothing_equipped` | Mit visel jelenleg minden játékos |
| `realrpg_clothing_design_slots` | Runtime texture slot foglalások |
| `realrpg_clothing_marketplace` | Piactéri hirdetések |
| `realrpg_clothing_marketplace_sales` | Értékesítési napló |
| `realrpg_clothing_marketplace_payouts` | Eladói kifizetések |
| `realrpg_clothing_audit_log` | Admin audit napló |

---

## Támogatás

- **Resource:** `realrpg_clothingstudio`
- **Verzió:** 1.3.0
- **Framework:** ESX / QBCore / Qbox (auto-detect)
- **Inventory:** ox_inventory kompatibilis (seerpg_inventory + ox_bridge)
- **Szerver:** RealRPG
