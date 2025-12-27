# New Hooks Implementation Checklist

## Overview
This checklist tracks the implementation status of all custom hooks in the Shops mod. Hooks allow external mods to register callbacks and customize shop behavior.

---

## Buy Price Hooks

### ✅ OnShopModifyBuyPrice
- **File**: `Shops/42.13.1/media/lua/shared/ShopPriceEvents.lua` (lines 9-25)
- **Purpose**: Allows mods to modify buy prices by adding multipliers/modifiers
- **Registration Function**: `ShopPriceEvents.registerOnShopModifyBuyPrice(callback)`
- **Trigger Function**: `ShopPriceEvents.triggerOnShopModifyBuyPrice(player, itemId, base, context, modifiers)`
- **Parameters**:
  - `player`: The customer
  - `itemId`: Item being purchased
  - `base`: Base price
  - `context`: Purchase context
  - `modifiers`: Table of price modifiers
- **Usage Location**: `ShopPriceBuy.lua` (Phase 1)
- **Status**: ✅ Implemented and integrated

### ✅ OnShopOverrideBuyPrice
- **File**: `Shops/42.13.1/media/lua/shared/ShopPriceEvents.lua` (lines 27-48)
- **Purpose**: Allows mods to completely override buy prices
- **Registration Function**: `ShopPriceEvents.registerOnShopOverrideBuyPrice(callback)`
- **Trigger Function**: `ShopPriceEvents.triggerOnShopOverrideBuyPrice(player, itemId, price, context)`
- **Parameters**:
  - `player`: The customer
  - `itemId`: Item being purchased
  - `price`: Calculated price
  - `context`: Purchase context
- **Return Value**: Override price or `nil` to use calculated price
- **Usage Location**: `ShopPriceBuy.lua` (Phase 2)
- **Status**: ✅ Implemented and integrated

---

## Sell Price Hooks

### ✅ OnShopModifySellPrice
- **File**: `Shops/42.13.1/media/lua/shared/ShopPriceEvents.lua` (lines 50-66)
- **Purpose**: Allows mods to modify sell prices by adding multipliers/modifiers
- **Registration Function**: `ShopPriceEvents.registerOnShopModifySellPrice(callback)`
- **Trigger Function**: `ShopPriceEvents.triggerOnShopModifySellPrice(player, item, base, context, modifiers)`
- **Parameters**:
  - `player`: The seller
  - `item`: Item being sold
  - `base`: Base price
  - `context`: Sale context
  - `modifiers`: Table of price modifiers
- **Usage Location**: `ShopPriceSell.lua` (Phase 1)
- **Status**: ✅ Implemented and integrated

### ✅ OnShopOverrideSellPrice
- **File**: `Shops/42.13.1/media/lua/shared/ShopPriceEvents.lua` (lines 68-89)
- **Purpose**: Allows mods to completely override sell prices
- **Registration Function**: `ShopPriceEvents.registerOnShopOverrideSellPrice(callback)`
- **Trigger Function**: `ShopPriceEvents.triggerOnShopOverrideSellPrice(player, item, price, context)`
- **Parameters**:
  - `player`: The seller
  - `item`: Item being sold
  - `price`: Calculated price
  - `context`: Sale context
- **Return Value**: Override price or `nil` to use calculated price
- **Usage Location**: `ShopPriceSell.lua` (Phase 2)
- **Status**: ✅ Implemented and integrated

---

## Item Registration Hooks

### ✅ Shop Item Registration System
- **File**: `Shops/42.13.1/media/lua/shared/ShopRegistry.lua`
- **Purpose**: Hook-based item registration system for Project Zomboid shops
- **Status**: ✅ Implemented

---

## Documentation Requirements

- [ ] Add hook documentation to `docs/B42.13_MP_Project_Zomboid_API_for_Inventory_Items.md`
- [ ] Create example implementations for external mods
- [ ] Document hook parameter types and expected behavior
- [ ] Document hook execution order and phases
- [ ] Add troubleshooting section for common hook issues

---

## Testing Checklist

- [ ] Test OnShopModifyBuyPrice with multiple modifiers
- [ ] Test OnShopOverrideBuyPrice with price override
- [ ] Test OnShopModifySellPrice with multiple modifiers
- [ ] Test OnShopOverrideSellPrice with price override
- [ ] Test hook execution order when multiple hooks registered
- [ ] Test hook error handling and validation
- [ ] Test item registration hooks
- [ ] Performance test with large number of hooks

---

## Integration Status

| Hook | Registration | Trigger | Phase | Tested |
|------|--------------|---------|-------|--------|
| OnShopModifyBuyPrice | ✅ | ✅ | 1 | ⏳ |
| OnShopOverrideBuyPrice | ✅ | ✅ | 2 | ⏳ |
| OnShopModifySellPrice | ✅ | ✅ | 1 | ⏳ |
| OnShopOverrideSellPrice | ✅ | ✅ | 2 | ⏳ |

---

## Notes

- All hooks follow B42.13+ PZ API conventions
- Hooks are Lua callback dispatchers, not engine events
- Hooks are triggered during price calculation, not as global events
- Error checking is implemented for callback registration
