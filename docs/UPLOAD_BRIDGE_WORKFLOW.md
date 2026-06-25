# RealRPG Clothing Studio - Upload Bridge Workflow

A v0.6 build célja, hogy a végleges ruhatextúra ne base64-ként maradjon a MySQL `preview_data` mezőben, hanem külső URL-ként legyen tárolva. Ez különösen fontos nagyobb képeknél, ox_inventory thumbnailnél és runtime DUI textúráknál.

## Mit csinál a bridge?

1. A NUI a végleges 1024x1024 canvas képet PNG data URL-ként előállítja.
2. A képet kisebb chunkokra bontja.
3. A chunkok kliensen keresztül szerverre mennek.
4. A szerver összerakja a képet.
5. A szerver Discord webhookra feltölti multipart/form-data requesttel.
6. A Discord CDN URL visszakerül a NUI-ba.
7. A design mentés már ezt az URL-t menti `preview_data` és `image_url` mezőbe.

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
    failSaveIfUploadFails = false
}
```

## Ellenőrzés

Szerver konzolból vagy játékból:

```txt
/rrcs_uploadcheck
```

Kiírja:
- bridge engedélyezve van-e,
- provider,
- webhook be van-e állítva,
- chunk size,
- max data URL size.

## Fontos biztonsági megjegyzés

A webhook URL soha nem kerül ki NUI-ba. A feltöltést a szerver végzi, így a játékosok nem látják a webhook linket.

## Jelenlegi limitáció

A v0.6 a végleges canvas textúrát tölti fel. Ha a design rétegei között feltöltött képek vannak, a `design_json` még tartalmazhat data URL-t az editálhatóság miatt. A következő nagyobb verzióban érdemes minden image layert külön assetként is feltölteni és a layer JSON-ban már csak URL-t tárolni.
