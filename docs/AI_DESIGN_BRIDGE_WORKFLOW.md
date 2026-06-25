# RealRPG Clothing Studio - AI Design Bridge v0.8

## Mit csinál?
Az AI Design Bridge a NUI AI prompt mezőjéből szerver oldalon generál egy képet Gemini API-val, majd az eredményt automatikusan új image layerként küldi vissza az editorba.

## Flow
1. Játékos beír egy promptot az AI DESIGN mezőbe.
2. NUI elküldi a szervernek: `realrpg_clothingstudio:server:generateAI`.
3. `server/ai_bridge.lua` ellenőrzi:
   - AI engedélyezve van-e,
   - API key megvan-e,
   - cooldown lejárt-e,
   - job/grade jogosultság,
   - tiltott szavak.
4. A szerver meghívja a Gemini image generation endpointot.
5. Ha visszajön kép:
   - Discord/CDN upload bridge-re tölti, ha engedélyezve van,
   - vagy data URL-ként küldi vissza NUI-ba.
6. NUI automatikusan új layerként hozzáadja a képet.

## Config
```lua
Config.AI = {
    enabled = true,
    provider = 'gemini',
    apiKey = 'IDE_A_GEMINI_API_KEY',
    model = 'gemini-2.0-flash-preview-image-generation',
    cooldownSeconds = 60,
    maxPromptLength = 420,
    uploadResultToCdn = true,
    failIfUploadFails = false,
    storePromptHistory = true,
    addGeneratedImageAsLayer = true,
    allowedJobs = nil
}
```

### Job lock példa
```lua
Config.AI.allowedJobs = {
    burgershot = 2,
    police = 4
}
```

## Parancs
```txt
/rrcs_aicheck
```

Ez F8 konzolba kiírja:
- AI enabled
- provider
- model
- api key set yes/no
- cooldown
- CDN upload állapot
- prompt history állapot
- allowed jobs

## SQL
A prompt history opcionálisan ebbe a táblába kerül:
```sql
realrpg_clothing_ai_history
```

## Fontos
A webhook / API key soha nem kerül ki NUI-ba. A teljes AI kérés szerver oldalon fut.
