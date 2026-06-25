# RealRPG Clothing Studio v0.5 - Blank Garment Pack Workflow

This phase adds manifest based blank garment loading.

## What this does

The script can now load new clothing templates and runtime texture slots from:

```txt
stream/blank_templates/manifest.json
```

That means you can add more printable clothing slots without editing `shared/templates.lua` every time.

## What this does not magically create

This resource still cannot generate valid GTA `.ydd` / `.ytd` clothing files by itself. Those files must be created/exported with a proper GTA clothing workflow and then streamed by FiveM.

## Required texture naming

For a runtime print to appear on the clothing item, the `.ytd` must contain a texture with the same source texture name as the manifest.

Example manifest slot:

```json
{
  "slot": 101,
  "component": 11,
  "drawable": 101,
  "texture": 0,
  "txd": "realrpg_pack_top_101",
  "txn": "blank_diffuse"
}
```

The streamed clothing must therefore use:

```txt
TXD: realrpg_pack_top_101
TXN: blank_diffuse
```

The runtime system replaces:

```txt
realrpg_pack_top_101 / blank_diffuse
```

with the player generated design texture.

## Manifest structure

```json
{
  "runtimeSlots": {
    "tops": [
      {
        "slot": 101,
        "component": 11,
        "drawable": 101,
        "texture": 0,
        "txd": "realrpg_pack_top_101",
        "txn": "blank_diffuse"
      }
    ]
  },
  "templates": {
    "male": {
      "tops": [
        {
          "id": "m_pack_top_101",
          "label": "Pack Blank Tee 101",
          "component": 11,
          "drawable": 101,
          "texture": 0,
          "runtimeSlot": 101
        }
      ]
    }
  }
}
```

## Useful commands

```txt
/rrcs_packcheck
/rrcs_slots
/rrcs_texdebug
```

`/rrcs_packcheck` prints the loaded manifest, template count, runtime slot count and every loaded slot to the F8 console.

## Recommended production workflow

1. Create or obtain blank addon clothing `.ydd/.ytd` files.
2. Set each blank texture inside the `.ytd` to a unique texture dictionary/name pair.
3. Add matching entries into `stream/blank_templates/manifest.json`.
4. Restart the resource.
5. Run `/rrcs_packcheck`.
6. Open `/clothingstudio` and verify the new templates appear in the library.
7. Print a design and use `/rrcs_texdebug` to confirm runtime texture replacement.

## Strict mode

In `config.lua`:

```lua
Config.GarmentPack.strictMode = true
```

Strict mode disables the built-in placeholder slots/templates and only uses your manifest entries.
Use this once your real clothing pack is ready.
