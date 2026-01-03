# ShopsHooksExample — Getting Started

Quick start guide for using item registration and price hooks in ShopsHooksExample.

---

## 5-Minute Overview

ShopsHooksExample demonstrates three main hook types:

### 1. Buy Item Registration

Items players can **purchase** from the shop.

```lua
Shop.RegisterItem("Base.Apple", {
    tab = SHOPSB42.Tab.Food,
    price = 2,
    items = 100  -- Stock
})
```

### 2. Sell Item Registration

Items the shop will **buy** from players.

```lua
-- Accept items (blacklist mode)
Shop.RegisterSellItem("Base.Apple", { price = 1 })

-- Reject items
Shop.RegisterSellItem("Base.Bomb", { blacklisted = true })
```

### 3. Price Hooks

Modify prices dynamically.

```lua
-- Discount multiplier
function modifyBuyPrice(player, itemId, basePrice, context, modifiers)
    table.insert(modifiers, { multiplier = 0.9 })
end

-- Fixed price override
function overrideBuyPrice(player, itemId, price, context)
    return 5  -- Fixed price
end
```

---

## Installation

1. Copy `ShopsHooksExample/` to your mods directory
2. Ensure **Shops** mod is installed (Build 42.13.1+)
3. Enable **ShopsHooksExample** in mod list
4. Load game (server initializes automatically)

---

## First Steps

### Step 1: Understand Current Implementation

Open these files in order:

1. **README.md** - Overview of all hook types
2. **ShopsHooksExampleItems.lua** - Working buy/sell registration
3. **ShopsHooksExampleHooks.lua** - Working price hooks

### Step 2: Review Documentation

**For item registration**:

- Start: ITEM_REGISTRATION_QUICK_REFERENCE.md (2 min)
- Deep dive: ITEM_REGISTRATION_EXAMPLES.md (15 min)

**For price hooks**:

- See: README.md sections on "Modifier Hooks" and "Override Hooks"

### Step 3: Test Current Example

Check server logs:

```bash
tail -f Logs/Server/*_Shops.txt | grep ShopsHooksExample
```

You should see:

```
[ShopsHooksExample] Registered buy items
[ShopsHooksExample] Registered sell items
[ShopsHooksExample] All hooks registered successfully
```

### Step 4: Customize

Edit `ShopsHooksExampleItems.lua`:

- Change item IDs to your items
- Adjust prices
- Modify conditions (whitelist/blacklist)

Or edit `ShopsHooksExampleHooks.lua`:

- Adjust price multipliers
- Add new price conditions

---

## Documentation Map

```
Quick Reference (5 min)
├─ ITEM_REGISTRATION_QUICK_REFERENCE.md
│  └─ Syntax, tabs, common patterns
│
Comprehensive Guides (30 min total)
├─ README.md
│  ├─ Overview of all hooks
│  ├─ Feature explanations
│  └─ Hook semantics
│
├─ ITEM_REGISTRATION_EXAMPLES.md
│  ├─ 7 working code examples
│  ├─ Buy/sell registration
│  ├─ Whitelist/blacklist patterns
│  └─ Integration with price hooks
│
Working Code (reference)
├─ ShopsHooksExampleItems.lua
│  ├─ registerBuyItems()
│  ├─ registerSellItems()
│  ├─ configureListingMode()
│  └─ registerWhitelistSellItems()
│
├─ ShopsHooksExampleHooks.lua
│  ├─ modifyAppleBuyPrice()
│  ├─ overrideAppleBuyPrice()
│  └─ modifySellPriceByCondition()
│
└─ ShopsHooksExampleInit.lua
   └─ Hook registration and initialization
```

---

## Common Tasks

### Add a New Buy Item

**File**: `ShopsHooksExampleItems.lua`, in `registerBuyItems()`

```lua
Shop.RegisterItem("Base.Banana", {
    tab = SHOPSB42.Tab.Food,
    price = 3,
    items = 75,
})
```

### Add a Sell Blacklist Item

**File**: `ShopsHooksExampleItems.lua`, in `registerSellItems()`

```lua
Shop.RegisterSellItem("Base.Radioactive", { blacklisted = true })
```

### Change Whitelist/Blacklist Mode

**File**: `ShopsHooksExampleItems.lua`, at top

```lua
-- false = blacklist mode (default)
-- true = whitelist mode
local ENABLE_WHITELIST_MODE = true
```

### Modify a Buy Price

**File**: `ShopsHooksExampleHooks.lua`, create function

```lua
function Hooks.modifyBananaPrice(player, itemId, basePrice, context, modifiers)
    if itemId ~= "Base.Banana" then return end
    table.insert(modifiers, { multiplier = 0.8, label = "bananaDiscount" })
end
```

Then register in `ShopsHooksExampleInit.lua`:

```lua
ShopPriceEvents.registerOnShopModifyBuyPrice(
    ShopsHooksExampleHooks.modifyBananaPrice
)
```

---

## Hook Registration Order

The initialization happens in this order:

1. **Listing mode** set (whitelist/blacklist)
2. **Buy items** registered
3. **Sell items** registered
4. **Price hooks** registered

This ensures items exist before prices are calculated.

---

## Testing Tips

### See What Items Are Registered

Check server logs:

```
[ShopsHooksExample] Registered buy items (CannedBolognese, Apple)
[ShopsHooksExample] Registered weapon items (AxeSteel, Hammer)
```

### Check Listing Mode

Logs show the mode:

```
[ShopsHooksExample] Listing mode: BLACKLIST
```

Or query at runtime:

```lua
print(SHOPSB42.Shop.SellisWhitelist)  -- false = blacklist, true = whitelist
```

### Test Prices In-Game

1. Open shop
2. Check item prices
3. If using modifiers, prices should be different from base

### Check Sell Items

1. Open player inventory
2. Try to sell items to shop
3. Blacklisted items should be grayed out

---

## Whitelist vs Blacklist

### Blacklist Mode (Default)

✅ **All items** can be sold  
❌ **Except** those marked `blacklisted = true`

**Use for**: Open shops (normal behavior)

```lua
Shop.RegisterSellItem("Base.Apple", { price = 1 })  -- Sellable
Shop.RegisterSellItem("Base.Bomb", { blacklisted = true })  -- Not sellable
```

### Whitelist Mode

✅ **Only registered items** can be sold  
❌ **Everything else** is rejected

**Use for**: Restricted shops (admin shops, NPC shops)

```lua
SHOPSB42.Shop.SellisWhitelist = true
Shop.RegisterSellItem("Base.Apple", { price = 1 })  -- Sellable
-- Base.Bomb: Automatically rejected (not registered)
```

---

## Common Issues

### Items Don't Show in Shop

**Check**:

1. Is `registerOnShopRegisterItems` hook registered?
2. Is `Shop.RegisterItem()` being called?
3. Do item IDs exist in the game?

**Fix**: Check server logs for registration messages.

### Can't Sell Items

**Check**:

1. Are sell items registered via `registerOnShopRegisterSellItems`?
2. In whitelist mode, is the item registered?
3. In blacklist mode, is the item blacklisted?

**Fix**: Verify `Shop.RegisterSellItem()` calls in logs.

### Price Hooks Don't Work

**Check**:

1. Are price hooks registered?
2. Are item IDs in hooks correct?
3. Are modifiers/overrides correct?

**Fix**: Check server logs for hook registration.

---

## File Locations

| File                                   | Purpose                    |
| -------------------------------------- | -------------------------- |
| `ShopsHooksExampleInit.lua`            | Registration entry point   |
| `ShopsHooksExampleItems.lua`           | Buy/sell item registration |
| `ShopsHooksExampleHooks.lua`           | Price modification hooks   |
| `ShopsHooksExampleState.lua`           | Configuration values       |
| `README.md`                            | Full feature overview      |
| `ITEM_REGISTRATION_QUICK_REFERENCE.md` | Quick lookup               |
| `ITEM_REGISTRATION_EXAMPLES.md`        | 7 detailed examples        |

---

## Next: Deep Dive

Once comfortable with basics:

1. **ITEM_REGISTRATION_EXAMPLES.md** - Learn advanced patterns
2. **README.md** - Understand all hook types
3. **Working code** - Study existing implementations
4. **Customize** - Adapt for your mod

---

## Questions?

- **How do I...?** → Check ITEM_REGISTRATION_QUICK_REFERENCE.md
- **Can you show an example?** → See ITEM_REGISTRATION_EXAMPLES.md
- **Why does this work?** → Read README.md sections
- **How do I debug?** → Check server logs in Logs/Server/\*\_Shops.txt

---

## Key Takeaways

✅ **Item registration** happens via hooks during initialization  
✅ **Buy items** use `Shop.RegisterItem()`  
✅ **Sell items** use `Shop.RegisterSellItem()`  
✅ **Whitelist/Blacklist** toggle via `Shop.SellisWhitelist`  
✅ **Price hooks** modify prices dynamically  
✅ **All code** is in SHOPSB42 namespace (no globals)  
✅ **All logging** uses SharedLogger (no writeLog)  
✅ **Proper order**: Configure mode → Register items → Apply prices

Now, check the documentation and start customizing!
