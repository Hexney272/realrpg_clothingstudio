Config = {}

Config.Debug = true
Config.Locale = 'hu'

-- auto / esx / qb / qbox
Config.Framework = 'auto'
Config.Inventory = 'ox_inventory'

Config.OpenCommand = 'clothingstudio'
Config.UseCommand = true

Config.Studio = {
    title = 'RealRPG Clothing Studio',
    accent = '#d7ff00',
    maxUploadMB = 4,
    allowedExtensions = { png = true, jpg = true, jpeg = true, webp = true },
}

-- ═══════════════════════════════════════════════════════════════
-- DUI RUNTIME TEXTURE SETTINGS
-- ═══════════════════════════════════════════════════════════════
Config.DUI = {
    -- Master switch: DUI runtime texture rendszer engedélyezése
    -- Ha false, a régi component swap fallback-et használja (MVP mód)
    enabled = true,

    -- Pool méret: ennyi inaktív DUI objektumot tartunk készenlétben újrahasznosításra
    -- Magasabb = gyorsabb újra-alkalmazás, több memória
    poolSize = 4,

    -- Maximum aktív DUI-k száma egyszerre (saját + távoli játékosok összesen)
    -- Ajánlott: 8-16 (1 saját + 7-15 közeli játékos)
    maxActive = 12,

    -- Render distance: ezen a távolságon belüli játékosokra alkalmazunk DUI textúrát
    -- Ezen kívül nem látszik az egyedi design (perf optimalizáció)
    renderDistance = 50.0,

    -- Render delay (ms): ennyi időt várunk a DUI renderelése után mielőtt alkalmazzuk
    -- A DUI-nak idő kell az első frame rendereléshez
    renderDelay = 250,

    -- Cleanup interval (ms): milyen gyakran ellenőrizzük a távoli játékosok távolságát
    cleanupInterval = 10000,

    -- Sync interval (ms): milyen gyakran kérjük a közeli játékosok design adatait
    syncInterval = 5000,

    -- Default textúra felbontás (ha a garment slot nem definiál mást)
    defaultResolution = 1024,

    -- Preview throttle (ms): real-time szerkesztés közben minimum ennyi idő két DUI frissítés között
    -- Alacsonyabb = simább preview, nagyobb CPU terhelés
    previewThrottle = 150,
}

-- ═══════════════════════════════════════════════════════════════
-- DESIGNER STATIONS
-- ═══════════════════════════════════════════════════════════════

-- Designer station access. job = nil means public.
Config.Stations = {
    {
        label = 'RealRPG Clothing Studio',
        coords = vec3(72.30, -1399.10, 29.38),
        radius = 2.0,
        job = nil,
        grade = 0
    },
    {
        label = 'Burger Shot Designer',
        coords = vec3(-1198.20, -894.40, 13.90),
        radius = 2.0,
        job = 'burgershot',
        grade = 2
    }
}

Config.DrawMarker = true
Config.Marker = {
    type = 2,
    scale = vec3(0.25, 0.25, 0.25),
    color = { r = 215, g = 255, b = 0, a = 180 }
}

-- How close the player must be to open station with E.
Config.InteractDistance = 2.0

-- ═══════════════════════════════════════════════════════════════
-- PRINTING (ITEM CREATION)
-- ═══════════════════════════════════════════════════════════════

-- Money/item printing settings
Config.Printing = {
    enabled = true,
    price = 2500,
    account = 'money', -- money/bank depending framework
    items = {
        tops = 'printed_tshirt',
        undershirt = 'printed_undershirt',
        pants = 'printed_pants',
        shoes = 'printed_shoes'
    }
}

-- ═══════════════════════════════════════════════════════════════
-- UPLOAD / CDN
-- ═══════════════════════════════════════════════════════════════

-- Upload bridge placeholder. In this MVP, designs are stored as JSON in DB.
-- For production, use a real upload endpoint/CDN or Discord webhook bridge.
Config.UploadBridge = {
    enabled = false,
    discordWebhook = '',
}

-- ═══════════════════════════════════════════════════════════════
-- AI DESIGN GENERATION
-- ═══════════════════════════════════════════════════════════════

-- AI placeholder. Add your API bridge server-side later.
Config.AI = {
    enabled = false,
    provider = 'gemini',
    apiKey = ''
}
