-- ════════════════════════════════════════════════════════════════
-- ITEM DEFINÍCIÓK a seerpg_inventory / ox_inventory shared/items.lua fájlhoz
-- 
-- A server.export mező biztosítja hogy az item használatakor
-- a realrpg_clothingstudio resource UseClothingItem exportja hívódik meg.
-- ════════════════════════════════════════════════════════════════

['printed_tshirt'] = {
    label = 'Nyomtatott Póló',
    weight = 250,
    stack = false,
    close = true,
    description = 'Egyedi nyomtatott póló',
    server = {
        export = 'realrpg_clothingstudio.UseClothingItem'
    }
},

['printed_undershirt'] = {
    label = 'Nyomtatott Alsó Felső',
    weight = 250,
    stack = false,
    close = true,
    description = 'Egyedi nyomtatott alsó felső',
    server = {
        export = 'realrpg_clothingstudio.UseClothingItem'
    }
},

['printed_pants'] = {
    label = 'Nyomtatott Nadrág',
    weight = 350,
    stack = false,
    close = true,
    description = 'Egyedi nyomtatott nadrág',
    server = {
        export = 'realrpg_clothingstudio.UseClothingItem'
    }
},

['printed_shoes'] = {
    label = 'Nyomtatott Cipő',
    weight = 500,
    stack = false,
    close = true,
    description = 'Egyedi nyomtatott cipő',
    server = {
        export = 'realrpg_clothingstudio.UseClothingItem'
    }
},
