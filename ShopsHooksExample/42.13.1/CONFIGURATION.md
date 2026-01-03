# ShopsHooksExample — Quick Configuration Reference

All configuration is in `media/lua/server/nshopsb42/ShopsHooksExampleState.lua`.

## Buy Price Configuration

### Apple Buy Multiplier

```lua
State.appleBuyMultiplier = 0.9
```

- **Current**: `0.9` (10% discount)
- **Range**: 0.0 - 2.0 (0% - 200% of base)
- **Effect**: Multiplied with base price and any other modifiers
- **Example**: 
  - `0.5` = 50% discount (half price)
  - `1.0` = no discount
  - `1.5` = 50% markup

### Apple Buy Override

```lua
State.appleOverrideBuyPrice = nil
```

- **Current**: `nil` (disabled)
- **When nil**: Use calculated price (with modifiers)
- **When numeric**: Force apple buy price to this exact value
- **Examples**:
  - `nil` = disabled, use modifiers
  - `5` = force apple buy to 5
  - `10` = force apple buy to 10
  - `0` = apple cannot be bought

When override is enabled, the `appleBuyMultiplier` is ignored.

## Sell Price Configuration

Sell price configuration is **automatic** — determined by item condition:

- **Excellent (75-100)**: 100% of sell price
- **Good (50-74)**: 85% of sell price
- **Fair (25-49)**: 50% of sell price
- **Poor (0-24)**: 50% of sell price

No manual configuration needed for sell prices. Edit `ShopsHooksExampleHooks.lua` to change multipliers.

## Runtime Changes

To change configuration at runtime (e.g., from admin mod):

```lua
-- Update multiplier
SHOPSB42.ShopsHooksExampleState.appleBuyMultiplier = 0.75

-- CRITICAL: Trigger resync
SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()
```

Without calling `onPriceHooksChanged()`, the new value won't be used until server restart.

## Items

### Buy Items
- `Base.Apple` (price: 12)

### Sell Items
- `Base.Apple` (price: 6)
- `Base.BaseballBat` (price: ~20)

To add more items, add a new hook function in `ShopsHooksExampleHooks.lua` and register it in `ShopsHooksExampleInit.lua`.

## Logging

Logging is **always on** and uses `SharedLogger`. Output:

**Server**: `Logs/Server/*_Shops.txt`
**Client**: `Logs/Client/*_Shops.txt`

Hook registration logged on startup. Hook execution logged per transaction.

## Disabling the Mod

To disable the example mod:
1. Disable in mod manager
2. Server restart
3. All prices revert to defaults

To disable just the hooks at runtime (if extended):

```lua
SHOPSB42.ShopsHooksExampleState.enabled = false
SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()
```

(Requires modifying hooks to check an `enabled` flag.)
