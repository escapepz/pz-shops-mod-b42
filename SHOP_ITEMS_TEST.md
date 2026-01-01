# Shop Items Test Guide

## Current Items Registered

### SurvivalPack (Container Item)
- **File**: `ShopItems/FirstAid.lua`
- **Item ID**: `Shops.SurvivalPack`
- **Tab**: FirstAid
- **Price**: 100 coins
- **Container**: 16 inventory slots, 10kg max weight
- **Contains**:
  - 1x Base.Antibiotics
  - 1x Base.PillsBeta
  - 5x Base.Bandaid
- **Note**: Items inside cannot exceed 10kg total weight

**To Test**:
1. Browse NPC shop → FirstAid tab
2. Buy SurvivalPack (100 coins)
3. Open inventory
4. See SurvivalPack in inventory (container)
5. Right-click SurvivalPack → Browse/Context menu
6. Click Browse button
7. **ContainerViewerUI opens** → Shows items INSIDE the pack:
   - Base.Antibiotics (1x)
   - Base.PillsBeta (1x)
   - Base.Bandaid (5x)
8. Search "Bandaid" → Filter works
9. All 5 bandages shown in the container

---

### Car (Vehicle Item)
- **File**: `ShopItems/Vehicles.lua`
- **Item ID**: `PinkSlip.CarNormal`
- **Tab**: Vehicles
- **Price**: 500 coins

**To Test**:
1. Browse NPC shop → Vehicles tab
2. See Car item listed
3. Click Preview button (camera icon)
4. **PreviewUI opens** → 3D car model appears
5. Click angle buttons (Left, Right, Top, Bottom, Front, Back)
6. Car rotates to selected angle
7. Zoom with mouse wheel (if supported)
8. Close preview window

---

### Bandaid (Simple Item)
- **File**: `ShopItems/FirstAid.lua`
- **Item ID**: `Base.Bandaid`
- **Tab**: FirstAid
- **Price**: 15 coins

**To Test**:
1. Browse NPC shop → FirstAid tab
2. Buy single Bandaid (15 coins)
3. Appears in inventory as single item

---

## Registration Flow

```
1. ShopInitServer.Initialize() called
2. ShopDefaultItems.registerHooks() → registers callbacks
3. ShopFinalizeHandler.finalizeNow() triggered
4. ShopEvents.triggerOnShopRegisterItems() calls all hooks
5. ShopDefaultItems.loadDefaultBuyItems() executes
6. require("nshopsb42/ShopItems/FirstAid") → Shop.RegisterItem calls
7. Shop.RegisterItem("Base.SurvivalPack", {...}) queues item
8. require("nshopsb42/ShopItems/Vehicles") → Shop.RegisterItem calls
9. All items committed to Shop.Items table
10. Shop._locked = true (no more registrations allowed)
```

---

## Verification Commands

**Check if items loaded** (server console):
```lua
print(SHOPSB42.Shop.Items["Shops.SurvivalPack"])
print(SHOPSB42.Shop.Items["PinkSlip.CarNormal"])
print(SHOPSB42.Shop.Items["Base.Bandaid"])
```

**Check if FirstAid tab has items**:
```lua
local count = 0
for id, def in pairs(SHOPSB42.Shop.Items) do
  if def.tab == "FirstAid" then
    count = count + 1
    print("  " .. id .. " - " .. def.price)
  end
end
print("FirstAid items: " .. count)
```

**Check if Vehicles tab has items**:
```lua
local count = 0
for id, def in pairs(SHOPSB42.Shop.Items) do
  if def.tab == "Vehicles" then
    count = count + 1
    print("  " .. id .. " - " .. def.price)
  end
end
print("Vehicles items: " .. count)
```

---

## UI Testing Checklist

- [ ] TransferUI - Right-click wallet → Transfer
- [ ] PreviewUI - Shop vehicle → Preview button → Rotate views
- [ ] ContainerViewerUI - Buy SurvivalPack → Browse contents
- [ ] ShopUI - Browse and buy items
- [ ] SetPriceUI - Player shop → Set prices
- [ ] IncomeUI - Player shop → Check earnings
- [ ] PlayerShopTabUI - All tab shows all items
- [ ] Search/Filter - Works on all list-based UIs
