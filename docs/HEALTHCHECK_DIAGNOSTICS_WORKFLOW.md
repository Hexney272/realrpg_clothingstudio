# RealRPG Clothing Studio v1.1 - Healthcheck / Diagnostics

## Új parancsok

```txt
/rrcs_health
/rrcs_selftest
```

A `/rrcs_health` teljes riportot ad F8 konzolba. Ellenőrzi:

- resource állapotok: `oxmysql`, `ox_inventory`
- framework detection
- kötelező fájlok
- SQL táblák
- garment manifest JSON
- template count
- runtime texture slotok
- duplicate slot ellenőrzés
- upload bridge állapot
- layer asset upload állapot
- AI bridge config
- marketplace/admin/audit állapot

A `/rrcs_selftest` ugyanennek egy gyors production check változata, a végén `SELFTEST_RESULT` sorral.

## Bekapcsolható automatikus start check

```lua
Config.Healthcheck.autoRunOnResourceStart = true
```

Production szerveren általában elég kézzel futtatni, hogy ne szemetelje a konzolt minden restartnál.

## Tipikus figyelmeztetések

`Upload bridge disabled` nem hiba, de éles szerveren ajánlott bekapcsolni, hogy ne kerüljön nagy base64 adat az adatbázisba.

`AI api key missing` csak akkor hiba, ha `Config.AI.enabled = true`.

`garment manifest missing` akkor gond, ha manifest alapú blank garment packot használsz. A script működhet default slot configgal is.

## Admin jog

A healthcheck admin parancs. Példa:

```cfg
add_ace group.admin realrpg.clothing.admin allow
```
