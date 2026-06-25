# RealRPG Clothing Studio — Troubleshooting

## Nem nyílik meg a menü

Ellenőrizd:

```txt
ensure realrpg_clothingstudio
/clothingstudio
F8 console error
```

Ha stationnél nem nyílik:

- `Config.Stations` coords jó-e
- `Config.UseTarget` false esetén E gomb működik-e
- job lock nincs-e beállítva

## Nincs item printelés után

Ellenőrizd:

- ox_inventory fut-e
- itemek bent vannak-e `data/items.lua`-ban
- `Config.Printing.items` item nevei egyeznek-e
- van-e elég pénz a játékosnál

Parancs:

```txt
/rrcs_selftest
```

## A print nem látszik a ruhán

Ez a leggyakoribb pont. A script runtime texture része megvan, de kell hozzá valódi blank garment pack.

Ellenőrizd:

```txt
/rrcs_packcheck
/rrcs_texdebug
```

A streamelt `.ytd` textúra neve egyezzen a manifestben lévővel:

```txt
txd = realrpg_pack_top_101
txn = blank_diffuse
```

Ha nincs ilyen streamelt ruhafájl, a ruha component felmegy, de a saját minta nem fog ténylegesen látszani.

## Upload bridge fail

Futtasd:

```txt
/rrcs_uploadcheck
```

Ellenőrizd:

- Discord webhook URL jó-e
- webhook nincs-e törölve
- fájl méret nincs-e limit felett
- `Config.UploadBridge.enabled = true`

## AI nem generál

Futtasd:

```txt
/rrcs_aicheck
```

Ellenőrizd:

- API key jó-e
- cooldown nem aktív-e
- job lock nem tilt-e
- blocked words listában nincs-e a prompt
- upload bridge elérhető-e, ha `uploadResultToCdn = true`

## Marketplace vásárlás nem működik

Futtasd:

```txt
/rrcs_marketcheck
```

Ellenőrizd:

- `Config.Marketplace.enabled = true`
- design approved-e, ha approval mód be van kapcsolva
- a vásárlónak van-e elég pénze
- saját design vásárlás tiltva van-e

## Admin parancs nem működik

server.cfg:

```cfg
add_ace group.admin realrpg.clothing.admin allow
```

Config:

```lua
Config.Admin.permission = 'realrpg.clothing.admin'
```

Teszt:

```txt
/rrcs_admincheck
```

## Adatbázis túl nagy lesz

Kapcsold be az upload bridge-et és layer asset uploadot, így nem base64 kerül a design JSON-ba.

Maintenance:

```txt
/rrcs_maintcheck
/rrcs_purgehistory 30 CONFIRM
```
