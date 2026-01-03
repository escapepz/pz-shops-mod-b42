# ShopsHooksExample — Testing Guide

This guide explains how to test the example mod and verify safe shop configuration patterns work correctly.

## Prerequisites

- Project Zomboid Build 42.13.1+
- Shops mod installed and working
- ShopsHooksExample mod enabled in mod manager

## Quick Start

1. Enable both mods in mod manager
2. Start a new game (server in multiplayer)
3. Find an NPC shop and begin testing
4. Check logs: `Logs/Server/*_Shops.txt` and `Logs/Client/*_Shops.txt`

## What Gets Tested

### Configuration Settings (CONFIGURATION.md Examples)

The example demonstrates these safe shop configurations:

#### 1. Item Registration via Hooks

**Tested Items:**

- `Base.CannedBolognese` (buy: 8)
- `Base.Apple` (buy: 2)
- `Base.AxeSteel` (buy: 25, broken: 5)
- `Base.Hammer` (buy: 15, broken: 3)
- `Base.FirstAidKit` (buy: 45, non-survival mode only)

**How to Test:**

1. Open shop UI
2. Navigate to Food tab → should see Canned Bolognese and Apple
3. Navigate to Weapons tab → should see AxeSteel and Hammer
4. Check stock limits:
   - Apple has 100 stock (buy many, stock decreases)
   - AxeSteel has 10 stock (limited)

**Expected Result:** Items appear in shop with correct prices and stock

---

#### 2. Buy Price Modification (Multiplier Pattern)

**Configuration:** `ShopsHooksExampleState.appleBuyMultiplier = 0.9`

**Hook:** `modifyAppleBuyPrice()` in ShopsHooksExampleHooks.lua

**How to Test:**

1. **Buy Base.Apple from shop**

   - Base price: 2
   - Multiplier: 0.9
   - Expected cost: ~2 (2 × 0.9 = 1.8, rounds to 2)
   - Check log: `Logs/Server/*_Shops.txt`
   - Should see: `[ShopsHooksExample] Applied buy modifier to Base.Apple: multiplier=0.9`

2. **Test multiplier modification at runtime**

   - Edit `ShopsHooksExampleState.lua`
   - Change: `State.appleBuyMultiplier = 0.5`
   - Restart server
   - Buy Apple again: should cost ~1 (2 × 0.5 = 1)

3. **Test various multiplier values**
   - `0.5`: 50% discount (half price)
   - `0.9`: 10% discount (example value)
   - `1.0`: no discount (full price)
   - `1.5`: 50% markup (more expensive)

**Expected Result:** Apple price changes based on multiplier value

---

#### 3. Buy Price Override (Fixed Price Pattern)

**Configuration:** `ShopsHooksExampleState.appleOverrideBuyPrice = nil`

**Hook:** `overrideAppleBuyPrice()` in ShopsHooksExampleHooks.lua

**How to Test:**

1. **Default behavior (override disabled)**

   - Leave `appleOverrideBuyPrice = nil`
   - Buy Apple → costs ~2 (modifier applies)
   - Check log: No override message (only modifier message)

2. **Enable fixed price override**

   - Edit `ShopsHooksExampleState.lua`
   - Change: `State.appleOverrideBuyPrice = 5`
   - Restart server
   - Buy Apple → costs exactly 5 (ignores multiplier)
   - Check log: `Overriding Apple buy price: X -> 5`

3. **Test edge cases**
   - `appleOverrideBuyPrice = 0`: Apple becomes free
   - `appleOverrideBuyPrice = 10`: Apple costs 10 (expensive)
   - `appleOverrideBuyPrice = nil`: Override disabled (back to modifier)

**Expected Result:** Override completely replaces modifier when enabled

---

#### 4. Sell Price Modification (Condition-Based Pattern)

**Configuration:** In `ShopsHooksExampleHooks.modifySellPriceByCondition()`

**Condition Bands:**

- Perfect (75-100%): 1.0x multiplier (full price)
- Good (50-74%): 0.85x multiplier (15% penalty)
- Fair/Poor (0-49%): 0.5x multiplier (50% penalty)

**How to Test:**

1. **Sell items in different conditions**

   - Acquire Apple or BaseballBat in various conditions
   - Sell to shop
   - Check prices:
     - Perfect condition: full sell price
     - Worn condition: 85% of sell price
     - Damaged condition: 50% of sell price

2. **Check logs**

   - `Logs/Server/*_Shops.txt`
   - Should see: `Applied condition modifier to Base.Apple: condition=XX, multiplier=Y`

3. **Test condition ranges**
   - Break items to lower condition
   - Repair items to raise condition
   - Sell at different condition points

**Expected Result:** Sell price adjusts based on item condition

---

#### 5. Sell Mode: Whitelist vs Blacklist

**Configuration:** `ENABLE_WHITELIST_MODE = false` in ShopsHooksExampleItems.lua

**Blacklist Mode (Default):**

**How to Test:**

1. Leave `ENABLE_WHITELIST_MODE = false`
2. Try to sell unregistered items (items not in `registerSellItems()`)
3. Expected: Shop accepts unregistered items at default price
4. Check log: `Enabled BLACKLIST mode (all items sellable except blacklisted)`

**Whitelisted Items in Blacklist Mode:**

- CannedBolognese (price: 4)
- Apple (price: 1)
- AxeSteel (price: 12)
- Hammer (price: 7)

**Blacklisted Items (Cannot Sell):**

- Bomb
- C4
- Explosives

**How to Test Blacklist:**

1. Try to sell Bomb to shop → shop refuses (blacklisted)
2. Try to sell random unregistered item → shop accepts at default price
3. Check log: `Enabled BLACKLIST mode`

---

**Whitelist Mode (Restricted):**

**How to Test:**

1. Edit ShopsHooksExampleItems.lua
2. Change: `local ENABLE_WHITELIST_MODE = true`
3. Restart server
4. Try to sell unregistered items → shop refuses
5. Only registered items can be sold:
   - CannedBolognese (price: 4)
   - Apple (price: 1)
   - AxeSteel (price: 12)
   - Hammer (price: 7)
6. Check log: `Enabled WHITELIST mode (only registered items sellable)`

**Expected Result:**

- Blacklist: All except blacklisted items can be sold
- Whitelist: Only registered items can be sold

---

## Log File Locations

### Server Logs

```
Logs/Server/*_Shops.txt
```

Contains:

- Hook registration messages
- Price modification logs
- Item registration logs
- Mode configuration logs

Example:

```
[ShopsHooksExample] Initialized server-only reference example
[ShopsHooksExample] Configured listing mode
[ShopsHooksExample] Registered BUY items: Food (CannedBolognese=8, Apple=2)
[ShopsHooksExample] Applied buy modifier to Base.Apple: multiplier=0.9
[ShopsHooksExample] Sell listing mode: BLACKLIST (permissive)
```

### Client Logs

```
Logs/Client/*_Shops.txt
```

Contains:

- Client-side price display updates
- UI rendering logs

---

## Testing Checklist

- [ ] Shop opens without errors
- [ ] Buy items appear in correct tabs (Food, Weapons, etc.)
- [ ] Stock limits work (limited stock decreases, unlimited stays high)
- [ ] Apple buy price is discounted (~2 with 0.9 multiplier)
- [ ] Apple override works when enabled (costs exact value)
- [ ] Sell prices vary by condition (perfect: full, worn: 85%, damaged: 50%)
- [ ] Blacklist mode: unregistered items sellable at default price
- [ ] Blacklist mode: blacklisted items (Bomb, C4) cannot be sold
- [ ] Whitelist mode: only registered items sellable
- [ ] Server logs show all hook messages
- [ ] Runtime changes work when restarting

---

## Common Issues and Solutions

### Items Not Appearing in Shop

**Problem:** Items registered in hooks don't show up in shop UI

**Solution:**

1. Check server logs for registration errors
2. Verify item IDs are correct (e.g., `Base.Apple` not `apple`)
3. Check tab constants: `SHOPSB42.Tab.Food`, `SHOPSB42.Tab.Weapons`, etc.
4. Ensure hook is registered in `ShopsHooksExampleInit.lua`

### Prices Not Changing

**Problem:** Buy/sell prices don't match expected values

**Solution:**

1. Check server logs for modifier application messages
2. Verify state variables in `ShopsHooksExampleState.lua`
3. If changed state file, restart server (changes don't apply at runtime without calling `onPriceHooksChanged()`)
4. Check logs for "ERROR" messages

### Override Not Working

**Problem:** `appleOverrideBuyPrice` set but price doesn't change

**Solution:**

1. Ensure value is not `nil` (nil disables override)
2. Check server log for "Overriding" message
3. Remember: override requires server restart to take effect
4. Verify override hook is registered in init file

### Sell Items Not Appearing/Working

**Problem:** Can't sell items to shop

**Solution:**

1. Check listing mode: blacklist vs whitelist
2. Verify item is registered in `registerSellItems()` or `registerWhitelistSellItems()`
3. Check if item is blacklisted
4. In whitelist mode: only registered items can be sold
5. Check server logs for registration errors

---

## Next Steps: Extending the Example

Once testing is complete, you can extend the example:

1. **Add more items:** Edit `registerBuyItems()` to add new items
2. **Add custom price hooks:** Create new price modifier functions
3. **Change listing mode:** Toggle `ENABLE_WHITELIST_MODE`
4. **Customize prices:** Adjust values in `ShopsHooksExampleState.lua`
5. **Add conditional logic:** Use context parameters in hooks

For API reference, see: `CONFIGURATION.md` and `SHOPS_HOOKS_REFERENCE.md`

---

## Support

For issues or questions:

1. Check the logs (`Logs/Server/*_Shops.txt`)
2. Review CONFIGURATION.md for settings reference
3. Review code comments in ShopsHooksExample Lua files
4. Refer to SHOPS_HOOKS_REFERENCE.md for full API documentation
