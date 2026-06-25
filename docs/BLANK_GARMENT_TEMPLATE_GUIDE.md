# RealRPG Clothing Studio - Blank Garment Template Guide

A v0.4 már kezeli a runtime slotokat, a DUI textúrát, a syncet és a slot pool ellenőrzést.
A tényleges GTA ruhára vetítéshez továbbra is valódi blank `.ydd/.ytd` ruhák kellenek.

## Miért kell külön blank garment?
A FiveM runtime texture csere (`AddReplaceTexture`) csak létező streamelt textúra dictionary/name párost tud lecserélni.
Ezért a blank ruha `.ytd` fájljában lennie kell például ennek:

```txt
TXD / dictionary: realrpg_blank_top_01
TXN / texture:    blank_diffuse
```

A script ezt cseréli runtime erre:

```txt
rrcs_<designId> / print
```

## Ajánlott slot logika
Egy slot = egy különböző aktív design textúra.

Ha ugyanazt a `txd/txn` párost két teljesen különböző design használja, akkor az utoljára alkalmazott runtime textúra nyer.
Ezért a v0.4 alapból nem engedi a slot újrahasználatot, ha betelt a pool.

Config:

```lua
Config.RuntimeTextures = {
    enabled = true,
    requireSlotForPrint = true,
    allowSlotReuseWhenFull = false,
    slots = {
        tops = {
            { slot = 1, component = 11, drawable = 15, texture = 0, txd = 'realrpg_blank_top_01', txn = 'blank_diffuse' },
            { slot = 2, component = 11, drawable = 16, texture = 0, txd = 'realrpg_blank_top_02', txn = 'blank_diffuse' },
        }
    }
}
```

## Hova kell rakni a blank fájlokat?

```txt
realrpg_clothingstudio/
└── stream/
    ├── mp_m_freemode_01_mp_m_realrpgstudio.meta
    ├── mp_f_freemode_01_mp_f_realrpgstudio.meta
    ├── realrpg_blank_top_01.ydd
    ├── realrpg_blank_top_01.ytd
    ├── realrpg_blank_top_02.ydd
    └── realrpg_blank_top_02.ytd
```

## Fontos
Ezt a csomagot nem tudom valódi GTA `.ydd/.ytd` binary model fájlokkal feltölteni, mert azokat OpenIV / Sollumz / Blender / CodeWalker workflow-val kell elkészíteni vagy meglévő blank ruhából kell exportálni.
A script oldali rész viszont már úgy van felépítve, hogy a helyes `txd/txn` nevek megadása után működjön.

## Tesztelés
1. Indítsd a szervert.
2. Futtasd konzolban vagy admin joggal:

```txt
/rrcs_slots
```

3. Kliens F8-ban:

```txt
/rrcs_texdebug
```

4. Ha a ruha felmegy, de a print nem látszik, akkor majdnem biztosan nem egyezik a streamelt ruha `.ytd` textúra dictionary/name párosa a configban lévő `txd/txn` értékkel.
