--[[
    RealRPG Clothing Studio - Blank Garment Slot Definitions
    
    Ez a fájl definiálja a streamelt blank garment slotokat,
    amelyekre a DUI runtime texture rávetítés történik.

    Minden slot egy üres/fehér textúrájú .ydd/.ytd fájlpár a stream/ mappában.
    A txd (texture dictionary) és txn (texture name) azonosítja a cserélendő textúrát.

    FONTOS: A tényleges .ydd/.ytd fájlokat külső tool-lal kell elkészíteni
    (OpenIV / CodeWalker / 3DS Max), majd a stream/ mappába helyezni.
    A fájlneveknek meg kell egyezniük az itt definiált txd nevekkel.
]]

Garments = {}

--[[
    Slot struktúra:
    - id: egyedi azonosító
    - label: megjelenítési név
    - gender: 'male' / 'female'
    - category: 'tops' / 'undershirt' / 'pants' / 'shoes'
    - component: GTA ped component id (11=tops, 8=undershirt, 4=pants, 6=shoes)
    - drawable: a blank garment drawable indexe (ezt kell beállítani a streamed .ydd alapján)
    - texture: texture variáció index (általában 0 a blank-nál)
    - txd: texture dictionary név (a .ytd fájlnév kiterjesztés nélkül)
    - txn: texture name a dictionary-n belül (a tényleges textúra slot neve)
    - resolution: textúra felbontás (DUI render mérete)
    - uvTemplate: UV guide kép a web editorhoz (opcionális)
]]

Garments.Slots = {
    -- ═══════════════════════════════════════════
    -- MALE TOPS (Component 11)
    -- ═══════════════════════════════════════════
    {
        id = 'rr_m_top_blank_001',
        label = 'Blank T-Shirt',
        gender = 'male',
        category = 'tops',
        component = 11,
        drawable = 252,         -- Ezt a streamelt .ydd drawable indexre kell állítani
        texture = 0,
        txd = 'rr_m_top_001',  -- stream/rr_m_top_001.ytd
        txn = 'rr_m_top_001_d', -- diffuse texture neve a ytd-ben
        resolution = 1024,
        uvTemplate = 'assets/uv_tshirt.png'
    },
    {
        id = 'rr_m_top_blank_002',
        label = 'Blank Long Sleeve',
        gender = 'male',
        category = 'tops',
        component = 11,
        drawable = 253,
        texture = 0,
        txd = 'rr_m_top_002',
        txn = 'rr_m_top_002_d',
        resolution = 1024,
        uvTemplate = 'assets/uv_tshirt.png'
    },

    -- ═══════════════════════════════════════════
    -- MALE UNDERSHIRT (Component 8)
    -- ═══════════════════════════════════════════
    {
        id = 'rr_m_under_blank_001',
        label = 'Blank Undershirt',
        gender = 'male',
        category = 'undershirt',
        component = 8,
        drawable = 188,
        texture = 0,
        txd = 'rr_m_under_001',
        txn = 'rr_m_under_001_d',
        resolution = 1024,
        uvTemplate = 'assets/uv_tshirt.png'
    },

    -- ═══════════════════════════════════════════
    -- MALE PANTS (Component 4)
    -- ═══════════════════════════════════════════
    {
        id = 'rr_m_pants_blank_001',
        label = 'Blank Pants',
        gender = 'male',
        category = 'pants',
        component = 4,
        drawable = 144,
        texture = 0,
        txd = 'rr_m_pants_001',
        txn = 'rr_m_pants_001_d',
        resolution = 1024,
        uvTemplate = 'assets/uv_pants.png'
    },

    -- ═══════════════════════════════════════════
    -- MALE SHOES (Component 6)
    -- ═══════════════════════════════════════════
    {
        id = 'rr_m_shoes_blank_001',
        label = 'Blank Shoes',
        gender = 'male',
        category = 'shoes',
        component = 6,
        drawable = 100,
        texture = 0,
        txd = 'rr_m_shoes_001',
        txn = 'rr_m_shoes_001_d',
        resolution = 512,
        uvTemplate = 'assets/uv_shoes.png'
    },

    -- ═══════════════════════════════════════════
    -- FEMALE TOPS (Component 11)
    -- ═══════════════════════════════════════════
    {
        id = 'rr_f_top_blank_001',
        label = 'Blank T-Shirt',
        gender = 'female',
        category = 'tops',
        component = 11,
        drawable = 262,
        texture = 0,
        txd = 'rr_f_top_001',
        txn = 'rr_f_top_001_d',
        resolution = 1024,
        uvTemplate = 'assets/uv_tshirt.png'
    },

    -- ═══════════════════════════════════════════
    -- FEMALE PANTS (Component 4)
    -- ═══════════════════════════════════════════
    {
        id = 'rr_f_pants_blank_001',
        label = 'Blank Pants',
        gender = 'female',
        category = 'pants',
        component = 4,
        drawable = 152,
        texture = 0,
        txd = 'rr_f_pants_001',
        txn = 'rr_f_pants_001_d',
        resolution = 1024,
        uvTemplate = 'assets/uv_pants.png'
    },
}

-- ═══════════════════════════════════════════════════════════════
-- LOOKUP HELPERS
-- ═══════════════════════════════════════════════════════════════

-- Cache: id -> slot
Garments._byId = {}
-- Cache: gender.category -> { slot, ... }
Garments._byGenderCat = {}

function Garments.BuildCache()
    Garments._byId = {}
    Garments._byGenderCat = {}
    for _, slot in ipairs(Garments.Slots) do
        Garments._byId[slot.id] = slot
        local key = slot.gender .. '.' .. slot.category
        if not Garments._byGenderCat[key] then
            Garments._byGenderCat[key] = {}
        end
        Garments._byGenderCat[key][#Garments._byGenderCat[key] + 1] = slot
    end
end

--- Garment slot lekérése ID alapján
---@param id string
---@return table|nil
function Garments.GetById(id)
    return Garments._byId[id]
end

--- Garment slotok lekérése gender + category alapján
---@param gender string 'male'|'female'
---@param category string 'tops'|'undershirt'|'pants'|'shoes'
---@return table[]
function Garments.GetByGenderCategory(gender, category)
    return Garments._byGenderCat[gender .. '.' .. category] or {}
end

--- Garment slot keresése txd név alapján (runtime texture replace-hez)
---@param txd string
---@return table|nil
function Garments.GetByTxd(txd)
    for _, slot in ipairs(Garments.Slots) do
        if slot.txd == txd then return slot end
    end
    return nil
end

--- Összes slot lekérése gender alapján (NUI-nak)
---@param gender string
---@return table
function Garments.GetAllForGender(gender)
    local result = {}
    for _, slot in ipairs(Garments.Slots) do
        if slot.gender == gender then
            result[#result + 1] = slot
        end
    end
    return result
end

-- Build cache on load
Garments.BuildCache()
