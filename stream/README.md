# RealRPG Clothing Studio - Stream Assets

Ez a mappa tartalmazza a **blank garment** `.ydd` (model) és `.ytd` (texture dictionary) fájlokat,
amelyekre a DUI runtime texture rávetítés történik.

## Szükséges fájlok

Minden garment slot-hoz (lásd `shared/garments.lua`) szükség van egy `.ytd` fájlra.
A `.ydd` opcionális - ha custom mesh-t is szeretnél, azt is ide kell helyezni.

### Male Tops (Component 11)

| Fájlnév | Garment ID | Leírás |
|---------|-----------|--------|
| `rr_m_top_001.ytd` | rr_m_top_blank_001 | Blank T-Shirt textúra (1024x1024 fehér diffuse) |
| `rr_m_top_002.ytd` | rr_m_top_blank_002 | Blank Long Sleeve textúra |
| `rr_m_top_001.ydd` | - | Opcionális custom mesh (ha vanilla drawable nem megfelelő) |
| `rr_m_top_002.ydd` | - | Opcionális custom mesh |

### Male Undershirt (Component 8)

| Fájlnév | Garment ID | Leírás |
|---------|-----------|--------|
| `rr_m_under_001.ytd` | rr_m_under_blank_001 | Blank Undershirt textúra |

### Male Pants (Component 4)

| Fájlnév | Garment ID | Leírás |
|---------|-----------|--------|
| `rr_m_pants_001.ytd` | rr_m_pants_blank_001 | Blank Pants textúra (1024x1024) |

### Male Shoes (Component 6)

| Fájlnév | Garment ID | Leírás |
|---------|-----------|--------|
| `rr_m_shoes_001.ytd` | rr_m_shoes_blank_001 | Blank Shoes textúra (512x512) |

### Female Tops (Component 11)

| Fájlnév | Garment ID | Leírás |
|---------|-----------|--------|
| `rr_f_top_001.ytd` | rr_f_top_blank_001 | Blank T-Shirt textúra (female) |

### Female Pants (Component 4)

| Fájlnév | Garment ID | Leírás |
|---------|-----------|--------|
| `rr_f_pants_001.ytd` | rr_f_pants_blank_001 | Blank Pants textúra (female) |

## Hogyan készítsünk blank garment-et?

### Szükséges toolok
- **OpenIV** - GTA V fájlkezelő, YTD/YDD export/import
- **CodeWalker** - Alternatív GTA V asset tool
- **3DS Max / Blender** - Ha custom mesh kell (opcionális)
- **Photoshop / GIMP** - Textúra szerkesztés

### Lépések (YTD készítés)

1. **Nyisd meg OpenIV-vel** a megfelelő vanilla clothing `.ytd` fájlt
   - Male tops: `mp_m_freemode_01_male_comp_11.ytd` (vagy hasonló)
   - A pontos fájlnév a target drawable index-től függ

2. **Exportáld a textúrát** (PNG/DDS)

3. **Készíts egy üres/fehér verziót** azonos méretben (1024x1024 vagy 512x512)
   - A textúra neve legyen a `txn` ami a `garments.lua`-ban van definiálva
   - Pl.: `rr_m_top_001_d` (diffuse)

4. **Hozz létre új .ytd-t** OpenIV-ben:
   - File -> New -> Texture Dictionary
   - Importáld az üres textúrát a megfelelő névvel
   - Mentsd el a `stream/` mappába a `garments.lua`-ban megadott txd névvel

5. **YDD (opcionális)**: Ha custom mesh-t szeretnél:
   - Exportáld a vanilla `.ydd`-t OpenIV-vel
   - Módosítsd 3DS Max / Blender-ben
   - UV map legyen clean és jól kiterített
   - Importáld vissza és mentsd a `stream/` mappába

### Fontos technikai részletek

- A `.ytd` fájlnévnek **pontosan** meg kell egyeznie a `garments.lua` `txd` mezőjével
- A textúra név a `.ytd`-n belül meg kell egyezzen a `txn` mezővel
- A textúra méretének meg kell egyeznie a `resolution` mezővel (1024 vagy 512)
- A textúra formátum: DXT5 (ha alpha kell) vagy DXT1 (ha nem)
- A drawable index-et a `fivem-resource.cfg` / `fxmanifest.lua`-ban konfigurált
  streaming határozza meg - ellenőrizd hogy a megfelelő component slot-ra kerül

### Tesztelés

1. Helyezd a `.ytd` (és opcionálisan `.ydd`) fájlokat ebbe a mappába
2. Indítsd el a servert
3. Ellenőrizd a kliens konzolt - ha `Config.Debug = true`, látni fogod:
   ```
   [RealRPG DUI] Initialized. Render URL: nui://realrpg_clothingstudio/web/dui_render.html
   [RealRPG RTex] Applied texture replace: preview_studio -> rr_m_top_001/rr_m_top_001_d
   ```
4. Ha a textúra nem jelenik meg, ellenőrizd:
   - A txd/txn nevek egyeznek-e a `garments.lua`-val
   - A drawable index helyes-e (a blank garment a várt component-en jelenik meg)
   - A textúra méret megfelelő-e

## Mappastruktúra (példa a kész állapotra)

```
stream/
├── rr_m_top_001.ytd       (Male Blank T-Shirt txd)
├── rr_m_top_002.ytd       (Male Blank Long Sleeve txd)
├── rr_m_under_001.ytd     (Male Blank Undershirt txd)
├── rr_m_pants_001.ytd     (Male Blank Pants txd)
├── rr_m_shoes_001.ytd     (Male Blank Shoes txd)
├── rr_f_top_001.ytd       (Female Blank T-Shirt txd)
├── rr_f_pants_001.ytd     (Female Blank Pants txd)
└── README.md              (Ez a fájl)
```

## Megjegyzések

- **A DUI rendszer .ytd nélkül is működik fallback módban** (component swap), de a
  valódi egyedi textúra csak a blank garment + runtime texture replace-szel jelenik meg.
- Ha még nincs kész blank garment, állítsd `Config.DUI.enabled = false`-ra a `config.lua`-ban.
- A fxmanifest.lua `stream/**/*` pattern automatikusan beolvassa az ide helyezett fájlokat.
