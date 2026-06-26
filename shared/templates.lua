Templates = {}

--[[
    GTA V Freemode Ped Component IDs:
    0  = Head
    1  = Beard/Mask
    2  = Hair
    3  = Torso (arms/upper body shape)
    4  = Legs (pants)
    5  = Bags/Parachute
    6  = Shoes
    7  = Accessories (necklaces, ties, scarves)
    8  = Undershirt
    9  = Body Armor
    10 = Decals/Badges
    11 = Tops (jackets, shirts)

    GTA V Freemode Ped Prop IDs:
    0  = Hats/Helmets
    1  = Glasses
    2  = Ears (earpieces)
    6  = Watches
    7  = Bracelets
]]

-- ═══════════════════════════════════════════════════════════════
-- COMPONENTS (SetPedComponentVariation)
-- ═══════════════════════════════════════════════════════════════
Templates.List = {
    male = {
        tops = {
            { id = 'm_top_basic_001', label = 'Basic T-Shirt', component = 11, drawable = 15, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_top_basic_002', label = 'V-Neck T-Shirt', component = 11, drawable = 16, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_top_polo_001', label = 'Polo Shirt', component = 11, drawable = 4, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_top_hoodie_001', label = 'Hoodie', component = 11, drawable = 57, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_top_jacket_001', label = 'Varsity Jacket', component = 11, drawable = 58, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_top_longsleeve_001', label = 'Long Sleeve Tee', component = 11, drawable = 59, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_top_tanktop_001', label = 'Tank Top', component = 11, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_top_staff_001', label = 'Staff Shirt', component = 11, drawable = 16, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        undershirt = {
            { id = 'm_under_basic_001', label = 'Basic Undershirt', component = 8, drawable = 15, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_under_tanktop_001', label = 'Tank Top Under', component = 8, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_under_turtleneck_001', label = 'Turtleneck Under', component = 8, drawable = 24, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        pants = {
            { id = 'm_pants_basic_001', label = 'Basic Jeans', component = 4, drawable = 1, texture = 0, preview = 'assets/pants.png', uv = 'assets/uv_pants.png' },
            { id = 'm_pants_cargo_001', label = 'Cargo Pants', component = 4, drawable = 5, texture = 0, preview = 'assets/pants.png', uv = 'assets/uv_pants.png' },
            { id = 'm_pants_jogger_001', label = 'Jogger Pants', component = 4, drawable = 4, texture = 0, preview = 'assets/pants.png', uv = 'assets/uv_pants.png' },
            { id = 'm_pants_shorts_001', label = 'Shorts', component = 4, drawable = 6, texture = 0, preview = 'assets/pants.png', uv = 'assets/uv_pants.png' },
            { id = 'm_pants_skinny_001', label = 'Skinny Jeans', component = 4, drawable = 3, texture = 0, preview = 'assets/pants.png', uv = 'assets/uv_pants.png' },
        },
        shoes = {
            { id = 'm_shoes_basic_001', label = 'Sneakers', component = 6, drawable = 1, texture = 0, preview = 'assets/shoes.png', uv = 'assets/uv_shoes.png' },
            { id = 'm_shoes_boots_001', label = 'Boots', component = 6, drawable = 5, texture = 0, preview = 'assets/shoes.png', uv = 'assets/uv_shoes.png' },
            { id = 'm_shoes_hightop_001', label = 'High Tops', component = 6, drawable = 7, texture = 0, preview = 'assets/shoes.png', uv = 'assets/uv_shoes.png' },
            { id = 'm_shoes_loafer_001', label = 'Loafers', component = 6, drawable = 10, texture = 0, preview = 'assets/shoes.png', uv = 'assets/uv_shoes.png' },
        },
        torso = {
            { id = 'm_torso_basic_001', label = 'Default Torso', component = 3, drawable = 0, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_torso_fitted_001', label = 'Fitted Torso', component = 3, drawable = 4, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_torso_muscular_001', label = 'Muscular Torso', component = 3, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        bags = {
            { id = 'm_bag_backpack_001', label = 'Backpack', component = 5, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_bag_duffel_001', label = 'Duffel Bag', component = 5, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        accessories = {
            { id = 'm_acc_chain_001', label = 'Gold Chain', component = 7, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_acc_tie_001', label = 'Necktie', component = 7, drawable = 4, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_acc_scarf_001', label = 'Scarf', component = 7, drawable = 8, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        armor = {
            { id = 'm_armor_basic_001', label = 'Basic Vest', component = 9, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_armor_heavy_001', label = 'Heavy Vest', component = 9, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        decals = {
            { id = 'm_decal_basic_001', label = 'Basic Badge', component = 10, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_decal_logo_001', label = 'Logo Patch', component = 10, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
    },
    female = {
        tops = {
            { id = 'f_top_basic_001', label = 'Basic T-Shirt', component = 11, drawable = 15, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_top_crop_001', label = 'Crop Top', component = 11, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_top_vneck_001', label = 'V-Neck Tee', component = 11, drawable = 16, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_top_hoodie_001', label = 'Hoodie', component = 11, drawable = 57, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_top_tanktop_001', label = 'Tank Top', component = 11, drawable = 3, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_top_jacket_001', label = 'Jacket', component = 11, drawable = 58, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        undershirt = {
            { id = 'f_under_basic_001', label = 'Basic Undershirt', component = 8, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_under_bralette_001', label = 'Bralette', component = 8, drawable = 14, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        pants = {
            { id = 'f_pants_basic_001', label = 'Basic Jeans', component = 4, drawable = 1, texture = 0, preview = 'assets/pants.png', uv = 'assets/uv_pants.png' },
            { id = 'f_pants_leggings_001', label = 'Leggings', component = 4, drawable = 3, texture = 0, preview = 'assets/pants.png', uv = 'assets/uv_pants.png' },
            { id = 'f_pants_skirt_001', label = 'Skirt', component = 4, drawable = 7, texture = 0, preview = 'assets/pants.png', uv = 'assets/uv_pants.png' },
            { id = 'f_pants_shorts_001', label = 'Shorts', component = 4, drawable = 6, texture = 0, preview = 'assets/pants.png', uv = 'assets/uv_pants.png' },
        },
        shoes = {
            { id = 'f_shoes_basic_001', label = 'Sneakers', component = 6, drawable = 1, texture = 0, preview = 'assets/shoes.png', uv = 'assets/uv_shoes.png' },
            { id = 'f_shoes_heels_001', label = 'Heels', component = 6, drawable = 3, texture = 0, preview = 'assets/shoes.png', uv = 'assets/uv_shoes.png' },
            { id = 'f_shoes_boots_001', label = 'Boots', component = 6, drawable = 5, texture = 0, preview = 'assets/shoes.png', uv = 'assets/uv_shoes.png' },
        },
        torso = {
            { id = 'f_torso_basic_001', label = 'Default Torso', component = 3, drawable = 0, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_torso_fitted_001', label = 'Fitted Torso', component = 3, drawable = 3, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        bags = {
            { id = 'f_bag_backpack_001', label = 'Backpack', component = 5, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_bag_purse_001', label = 'Purse', component = 5, drawable = 3, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        accessories = {
            { id = 'f_acc_necklace_001', label = 'Necklace', component = 7, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_acc_scarf_001', label = 'Scarf', component = 7, drawable = 6, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        armor = {
            { id = 'f_armor_basic_001', label = 'Basic Vest', component = 9, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        decals = {
            { id = 'f_decal_basic_001', label = 'Basic Badge', component = 10, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
    }
}

-- ═══════════════════════════════════════════════════════════════
-- PROPS (SetPedPropIndex)
-- These use a different native than components!
-- ═══════════════════════════════════════════════════════════════
Templates.Props = {
    male = {
        hats = {
            { id = 'm_hat_cap_001', label = 'Baseball Cap', prop = 0, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_hat_beanie_001', label = 'Beanie', prop = 0, drawable = 13, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_hat_bucket_001', label = 'Bucket Hat', prop = 0, drawable = 38, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_hat_snapback_001', label = 'Snapback', prop = 0, drawable = 5, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_hat_fedora_001', label = 'Fedora', prop = 0, drawable = 24, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        glasses = {
            { id = 'm_glass_aviator_001', label = 'Aviator Sunglasses', prop = 1, drawable = 3, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_glass_sport_001', label = 'Sport Glasses', prop = 1, drawable = 7, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_glass_retro_001', label = 'Retro Frames', prop = 1, drawable = 14, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        ears = {
            { id = 'm_ear_piece_001', label = 'Earpiece', prop = 2, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_ear_buds_001', label = 'Earbuds', prop = 2, drawable = 3, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        watches = {
            { id = 'm_watch_digital_001', label = 'Digital Watch', prop = 6, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_watch_luxury_001', label = 'Luxury Watch', prop = 6, drawable = 5, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_watch_sport_001', label = 'Sport Watch', prop = 6, drawable = 3, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        bracelets = {
            { id = 'm_brace_basic_001', label = 'Basic Bracelet', prop = 7, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'm_brace_chain_001', label = 'Chain Bracelet', prop = 7, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
    },
    female = {
        hats = {
            { id = 'f_hat_cap_001', label = 'Baseball Cap', prop = 0, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_hat_beanie_001', label = 'Beanie', prop = 0, drawable = 13, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_hat_sunhat_001', label = 'Sun Hat', prop = 0, drawable = 40, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_hat_beret_001', label = 'Beret', prop = 0, drawable = 30, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        glasses = {
            { id = 'f_glass_cat_001', label = 'Cat-Eye Glasses', prop = 1, drawable = 5, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_glass_round_001', label = 'Round Glasses', prop = 1, drawable = 10, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_glass_aviator_001', label = 'Aviator Sunglasses', prop = 1, drawable = 3, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        ears = {
            { id = 'f_ear_piece_001', label = 'Earpiece', prop = 2, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_ear_buds_001', label = 'Earbuds', prop = 2, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        watches = {
            { id = 'f_watch_elegant_001', label = 'Elegant Watch', prop = 6, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_watch_sport_001', label = 'Sport Watch', prop = 6, drawable = 3, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
        bracelets = {
            { id = 'f_brace_basic_001', label = 'Basic Bracelet', prop = 7, drawable = 1, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
            { id = 'f_brace_bangles_001', label = 'Bangles', prop = 7, drawable = 2, texture = 0, preview = 'assets/tshirt.png', uv = 'assets/uv_tshirt.png' },
        },
    }
}

-- ═══════════════════════════════════════════════════════════════
-- CATEGORY METADATA
-- Used to determine if a category is a component or prop
-- ═══════════════════════════════════════════════════════════════
Templates.Categories = {
    -- Components (SetPedComponentVariation)
    tops        = { type = 'component', componentId = 11, label = 'Tops' },
    undershirt  = { type = 'component', componentId = 8,  label = 'Undershirt' },
    pants       = { type = 'component', componentId = 4,  label = 'Pants' },
    shoes       = { type = 'component', componentId = 6,  label = 'Shoes' },
    torso       = { type = 'component', componentId = 3,  label = 'Torso' },
    bags        = { type = 'component', componentId = 5,  label = 'Bags' },
    accessories = { type = 'component', componentId = 7,  label = 'Accessories' },
    armor       = { type = 'component', componentId = 9,  label = 'Armor' },
    decals      = { type = 'component', componentId = 10, label = 'Decals' },
    -- Props (SetPedPropIndex)
    hats        = { type = 'prop', propId = 0, label = 'Hats' },
    glasses     = { type = 'prop', propId = 1, label = 'Glasses' },
    ears        = { type = 'prop', propId = 2, label = 'Ears' },
    watches     = { type = 'prop', propId = 6, label = 'Watches' },
    bracelets   = { type = 'prop', propId = 7, label = 'Bracelets' },
}

-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

--- Get a template by gender, category, and id (works for both components and props)
---@param gender string 'male'|'female'
---@param category string
---@param id string
---@return table|nil
function Templates.Get(gender, category, id)
    -- Check component list first
    local list = Templates.List[gender] and Templates.List[gender][category]
    if list then
        for _, t in ipairs(list) do
            if t.id == id then return t end
        end
    end
    -- Check props list
    local propList = Templates.Props[gender] and Templates.Props[gender][category]
    if propList then
        for _, t in ipairs(propList) do
            if t.id == id then return t end
        end
    end
    return nil
end

--- Get all templates for a gender+category (components + props merged)
---@param gender string
---@param category string
---@return table
function Templates.GetCategory(gender, category)
    local result = {}
    local list = Templates.List[gender] and Templates.List[gender][category]
    if list then
        for _, t in ipairs(list) do result[#result + 1] = t end
    end
    local propList = Templates.Props[gender] and Templates.Props[gender][category]
    if propList then
        for _, t in ipairs(propList) do result[#result + 1] = t end
    end
    return result
end

--- Check if a category is a prop type
---@param category string
---@return boolean
function Templates.IsProp(category)
    local meta = Templates.Categories[category]
    return meta and meta.type == 'prop' or false
end

--- Get the combined list for NUI (components + props organized)
---@return table
function Templates.GetAllForNUI()
    local result = { male = {}, female = {} }
    for gender, cats in pairs(Templates.List) do
        for category, list in pairs(cats) do
            result[gender][category] = result[gender][category] or {}
            for _, t in ipairs(list) do
                local entry = {}
                for k, v in pairs(t) do entry[k] = v end
                entry.isProp = false
                result[gender][category][#result[gender][category] + 1] = entry
            end
        end
    end
    for gender, cats in pairs(Templates.Props) do
        for category, list in pairs(cats) do
            result[gender][category] = result[gender][category] or {}
            for _, t in ipairs(list) do
                local entry = {}
                for k, v in pairs(t) do entry[k] = v end
                entry.isProp = true
                result[gender][category][#result[gender][category] + 1] = entry
            end
        end
    end
    return result
end

--- Count total templates
---@return number
function Templates.Count()
    local total = 0
    for _, cats in pairs(Templates.List) do
        for _, list in pairs(cats) do total = total + #list end
    end
    for _, cats in pairs(Templates.Props) do
        for _, list in pairs(cats) do total = total + #list end
    end
    return total
end
