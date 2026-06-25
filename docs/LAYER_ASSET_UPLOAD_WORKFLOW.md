# RealRPG Clothing Studio - Layer Asset Upload Workflow

A v0.7 célja, hogy ne a teljes feltöltött képet/base64 adatot tároljuk minden image layerben.
Ha a `Config.UploadBridge.enabled = true` és `Config.UploadBridge.uploadLayerAssets = true`, akkor a NUI minden feltöltött vagy clipboardból beillesztett image layert külön feltölt a szerveren keresztül a Discord webhook/CDN bridge-re.

## Miért fontos?

Base64 layer tárolásnál a `design_json` gyorsan túl nagy lesz. Egy 2-4 MB-os PNG több MB-os JSON-t eredményezhet, több layernél pedig ez már MySQL / NUI / network oldalon is problémás.

A v0.7-ben az image layer mentett formája például ilyen lesz:

```json
{
  "id": "l_xxx",
  "type": "image",
  "name": "Image Layer",
  "x": 512,
  "y": 512,
  "w": 360,
  "h": 220,
  "src": "https://cdn.discordapp.com/attachments/.../layer_asset_1.png",
  "assetUrl": "https://cdn.discordapp.com/attachments/.../layer_asset_1.png",
  "cdn": true,
  "opacity": 1,
  "blend": "source-over",
  "visible": true
}
```

## Bekapcsolás

`config.lua`:

```lua
Config.UploadBridge = {
    enabled = true,
    provider = 'discord',
    discordWebhook = 'IDE_A_WEBHOOK_URL',
    chunkSize = 240000,
    timeoutSeconds = 60,
    maxDataUrlBytes = 6 * 1024 * 1024,
    saveFinalTextureOnly = true,
    failSaveIfUploadFails = false,
    uploadLayerAssets = true,
    failLayerUploadIfUploadFails = false
}
```

## Státuszok a layer panelen

- `local`: a kép még helyi/base64 adat.
- `uploading`: feltöltés folyamatban.
- `cdn`: sikeres upload, a layer URL-t használ.
- `failed`: upload hiba történt.

## Mentési flow

1. Játékos behúz/feltölt/beilleszt egy képet.
2. A NUI létrehozza az image layert.
3. Ha az upload bridge aktív, a layer automatikusan uploadra kerül.
4. Mentéskor a rendszer megvárja a folyamatban lévő layer uploadokat.
5. A `design_json` a CDN URL-t tárolja, nem a teljes base64 képet.
6. A végleges 1024x1024 canvas továbbra is feltölthető külön `design_final` képként.

## Ellenőrzés

```txt
/rrcs_assetcheck
/rrcs_uploadcheck
```

## Fontos megjegyzés

A Discord CDN URL-ek külső képek. A NUI megpróbálja `crossOrigin = 'anonymous'` móddal betölteni őket. Ha egy CDN nem enged canvas exportot CORS miatt, a final canvas export hibázhat. Discord CDN általában működik, de saját CDN esetén érdemes CORS headert adni.
