--[[
    RealRPG Clothing Studio - Templates
    
    Ruha sablonok a NUI editorhoz. Ezek jelennek meg a "LIBRARY" panelben.
    Minden sablon egy GTA ped component variációra mutat.

    A DUI rendszerrel a garmentId mező köti össze a sablont a blank garment slot-tal.
    Ha garmentId meg van adva, a DUI runtime texture rendszer azt a slotot használja.
    Ha nincs (régi/fallback sablonok), a component/drawable alapú swap-ot használja.

    GTA freemode clothing component ids:
    - 11 = tops (jacket/shirt)
    - 8 = undershirt
    - 4 = pants/legs
    - 6 = shoes/feet
]]

Templates = {}

Templates.List = {
    male = {
        tops = {
            {
                id = 'm_top_basic_001',
                label = 'Blank T-Shirt (DUI)',
                component = 11,
                drawable = 252,     -- Blank garment drawable (streamelt)
                texture = 0,
                garmentId = 'rr_m_top_blank_001',  -- -> Garments.Slots link
                preview = 'assets/tshirt.png',
                uv = 'assets/uv_tshirt.png',
                dui = true          -- Jelzi hogy DUI-kompatibilis sablon
            },
            {
                id = 'm_top_longsleeve_001',
                label = 'Blank Long Sleeve (DUI)',
                component = 11,
                drawable = 253,
                texture = 0,
                garmentId = 'rr_m_top_blank_002',
                preview = 'assets/tshirt.png',
                uv = 'assets/uv_tshirt.png',
                dui = true
            },
            -- Fallback sablonok (régi component swap mód, DUI nélkül)
            {
                id = 'm_top_vanilla_015',
                label = 'Vanilla T-Shirt #15',
                component = 11,
                drawable = 15,
                texture = 0,
                garmentId = nil,    -- Nincs DUI, component swap fallback
                preview = 'assets/tshirt.png',
                uv = 'assets/uv_tshirt.png',
                dui = false
            },
            {
                id = 'm_top_vanilla_016',
                label = 'Staff Shirt #16',
                component = 11,
                drawable = 16,
                texture = 0,
                garmentId = nil,
                preview = 'assets/tshirt.png',
                uv = 'assets/uv_tshirt.png',
                dui = false
            },
        },

        undershirt = {
            {
                id = 'm_under_basic_001',
                label = 'Blank Undershirt (DUI)',
                component = 8,
                drawable = 188,
                texture = 0,
                garmentId = 'rr_m_under_blank_001',
                preview = 'assets/tshirt.png',
                uv = 'assets/uv_tshirt.png',
                dui = true
            },
            {
                id = 'm_under_vanilla_015',
                label = 'Vanilla Undershirt #15',
                component = 8,
                drawable = 15,
                texture = 0,
                garmentId = nil,
                preview = 'assets/tshirt.png',
                uv = 'assets/uv_tshirt.png',
                dui = false
            },
        },

        pants = {
            {
                id = 'm_pants_basic_001',
                label = 'Blank Pants (DUI)',
                component = 4,
                drawable = 144,
                texture = 0,
                garmentId = 'rr_m_pants_blank_001',
                preview = 'assets/pants.png',
                uv = 'assets/uv_pants.png',
                dui = true
            },
            {
                id = 'm_pants_vanilla_001',
                label = 'Vanilla Pants #1',
                component = 4,
                drawable = 1,
                texture = 0,
                garmentId = nil,
                preview = 'assets/pants.png',
                uv = 'assets/uv_pants.png',
                dui = false
            },
        },

        shoes = {
            {
                id = 'm_shoes_basic_001',
                label = 'Blank Shoes (DUI)',
                component = 6,
                drawable = 100,
                texture = 0,
                garmentId = 'rr_m_shoes_blank_001',
                preview = 'assets/shoes.png',
                uv = 'assets/uv_shoes.png',
                dui = true
            },
            {
                id = 'm_shoes_vanilla_001',
                label = 'Vanilla Shoes #1',
                component = 6,
                drawable = 1,
                texture = 0,
                garmentId = nil,
                preview = 'assets/shoes.png',
                uv = 'assets/uv_shoes.png',
                dui = false
            },
        }
    },

    female = {
        tops = {
            {
                id = 'f_top_basic_001',
                label = 'Blank T-Shirt (DUI)',
                component = 11,
                drawable = 262,
                texture = 0,
                garmentId = 'rr_f_top_blank_001',
                preview = 'assets/tshirt.png',
                uv = 'assets/uv_tshirt.png',
                dui = true
            },
            {
                id = 'f_top_vanilla_015',
                label = 'Vanilla T-Shirt #15',
                component = 11,
                drawable = 15,
                texture = 0,
                garmentId = nil,
                preview = 'assets/tshirt.png',
                uv = 'assets/uv_tshirt.png',
                dui = false
            },
        },

        undershirt = {
            {
                id = 'f_under_vanilla_001',
                label = 'Vanilla Undershirt',
                component = 8,
                drawable = 2,
                texture = 0,
                garmentId = nil,
                preview = 'assets/tshirt.png',
                uv = 'assets/uv_tshirt.png',
                dui = false
            },
        },

        pants = {
            {
                id = 'f_pants_basic_001',
                label = 'Blank Pants (DUI)',
                component = 4,
                drawable = 152,
                texture = 0,
                garmentId = 'rr_f_pants_blank_001',
                preview = 'assets/pants.png',
                uv = 'assets/uv_pants.png',
                dui = true
            },
        },

        shoes = {
            {
                id = 'f_shoes_vanilla_001',
                label = 'Vanilla Shoes',
                component = 6,
                drawable = 1,
                texture = 0,
                garmentId = nil,
                preview = 'assets/shoes.png',
                uv = 'assets/uv_shoes.png',
                dui = false
            },
        }
    }
}

-- ═══════════════════════════════════════════════════════════════
-- LOOKUP HELPERS
-- ═══════════════════════════════════════════════════════════════

--- Template keresése gender + category + id alapján
---@param gender string 'male'|'female'
---@param category string 'tops'|'undershirt'|'pants'|'shoes'
---@param id string Template id
---@return table|nil
function Templates.Get(gender, category, id)
    local list = Templates.List[gender] and Templates.List[gender][category]
    if not list then return nil end
    for _, t in ipairs(list) do
        if t.id == id then return t end
    end
    return nil
end

--- Összes DUI-kompatibilis template lekérése egy kategóriából
---@param gender string
---@param category string
---@return table[]
function Templates.GetDUI(gender, category)
    local list = Templates.List[gender] and Templates.List[gender][category]
    if not list then return {} end
    local result = {}
    for _, t in ipairs(list) do
        if t.dui and t.garmentId then
            result[#result + 1] = t
        end
    end
    return result
end

--- Template keresése garmentId alapján (reverse lookup)
---@param garmentId string
---@return table|nil template, string|nil gender, string|nil category
function Templates.GetByGarmentId(garmentId)
    for gender, categories in pairs(Templates.List) do
        for category, list in pairs(categories) do
            for _, t in ipairs(list) do
                if t.garmentId == garmentId then
                    return t, gender, category
                end
            end
        end
    end
    return nil
end
