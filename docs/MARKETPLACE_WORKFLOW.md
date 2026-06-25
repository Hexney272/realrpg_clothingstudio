# RealRPG Clothing Studio v0.9 Marketplace Workflow

## Mit tud

A v0.9-ben bekerült a shop / marketplace alap rendszer:

- saját design publikálása ár megadásával
- marketplace böngészés NUI-ból
- más játékos designjának megvásárlása
- vásárláskor az item azonnal kinyomtatódik az inventoryba
- eladói jutalék százalékos rendszerrel
- server fee / jutalék logolás
- offline eladói payout queue
- `/rrcs_claimmarket` paranccsal kifizetés felvétele
- `/rrcs_marketcheck` admin/debug parancs

## Config

```lua
Config.Marketplace = {
    enabled = true,
    minPrice = 1000,
    maxPrice = 250000,
    defaultPrice = 5000,
    sellerCommissionPercent = 70,
    account = 'bank',
    requireApproval = false,
    printOnPurchase = true,
    allowOwnPurchase = false,
    maxListingsPerPlayer = 40,
    listingLimit = 100
}
```

## Használat

1. A játékos elkészít egy designt.
2. Elmenti.
3. A **My Designs** tabon kiválasztja.
4. Rányom a **PUBLISH DESIGN** gombra.
5. Megadja az árat.
6. A design megjelenik a **MARKET** tabon.
7. Más játékos kiválasztja, majd **BUY + PRINT**.
8. A buyer fizet, a ruhát megkapja inventoryba.
9. A seller jutaléka payout queue-ba kerül.
10. Seller használja: `/rrcs_claimmarket`.

## SQL

Új táblák:

- `realrpg_clothing_marketplace`
- `realrpg_clothing_marketplace_sales`
- `realrpg_clothing_marketplace_payouts`

## Fontos

A marketplace vásárlás ugyanazt a runtime slot rendszert használja, mint a saját printelés. Ha egy kategória slot poolja betelik, a vásárlás nem engedi összekeverni a designokat.
