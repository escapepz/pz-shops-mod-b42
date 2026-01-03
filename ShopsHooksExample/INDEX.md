# ShopsHooksExample — Complete Documentation Index

## Start Here

👉 **New to ShopsHooksExample?** Start with **GETTING_STARTED.md** (5 minutes)

---

## Documentation Map

### Quick Start (5-15 minutes)

1. **GETTING_STARTED.md** (this directory)

   - 5-minute overview
   - Common tasks
   - Testing tips
   - File locations
   - How to customize

2. **42.13.1/ITEM_REGISTRATION_QUICK_REFERENCE.md**
   - Syntax cheat sheet
   - Available tabs and modes
   - Common patterns
   - Error troubleshooting

### Comprehensive Guides (30-60 minutes)

3. **42.13.1/README.md**

   - Complete overview of all features
   - Detailed hook explanations
   - Price hook semantics
   - Customization guide
   - Testing instructions

4. **42.13.1/ITEM_REGISTRATION_EXAMPLES.md**
   - 7 working code examples
   - Buy item registration
   - Sell item registration
   - Whitelist/blacklist patterns
   - Complex scenarios
   - Dynamic additions
   - Price integration

### Reference (lookups)

5. **ITEM_REGISTRATION_ADDITIONS.md** (this directory)

   - Summary of what was added
   - Hook system overview
   - Design patterns
   - Testing information
   - Lines of code statistics

6. **DELIVERY_SUMMARY.md** (this directory)
   - Complete delivery checklist
   - Feature matrix
   - Integration checklist
   - Usage statistics
   - Quick start paths

### Working Code

7. **42.13.1/media/lua/server/nshopsb42/ShopsHooksExampleItems.lua**

   - Buy item registration function
   - Sell item registration function
   - Listing mode configuration
   - Working implementations
   - Proper error handling

8. **42.13.1/media/lua/server/nshopsb42/ShopsHooksExampleHooks.lua**

   - Price modification hooks
   - Buy price modifiers
   - Buy price overrides
   - Sell price modifiers
   - Condition-based pricing

9. **42.13.1/media/lua/server/nshopsb42/ShopsHooksExampleInit.lua**
   - Hook registration
   - Initialization flow
   - Event dispatcher setup
   - Logging configuration

---

## What's Covered

### Shop Listing Items

- **Buy items**: `Shop.RegisterItem()` - Items players purchase
- **Sell items**: `Shop.RegisterSellItem()` - Items shop buys from players

### Hook Types

- `registerOnShopRegisterItems()` - Register buy items
- `registerOnShopRegisterSellItems()` - Register sell items

### Listing Configuration

- **Whitelist mode**: Only registered items sellable
- **Blacklist mode**: All items sellable except blacklisted
- Toggle: `SHOPSB42.Shop.SellisWhitelist`

### Price Integration

- Combine items with buy/sell price hooks
- Dynamic pricing based on conditions
- Price modifiers and overrides

---

## Quick Navigation

### "I want to..."

**...understand what this is**
→ GETTING_STARTED.md

**...get a quick syntax reference**
→ ITEM_REGISTRATION_QUICK_REFERENCE.md

**...see working code examples**
→ ITEM_REGISTRATION_EXAMPLES.md

**...add a new buy item**
→ GETTING_STARTED.md → "Add a New Buy Item"

**...enable whitelist mode**
→ ITEM_REGISTRATION_QUICK_REFERENCE.md → "Whitelist Mode"

**...blacklist dangerous items**
→ ITEM_REGISTRATION_EXAMPLES.md → "Example 4"

**...combine items with price hooks**
→ ITEM_REGISTRATION_EXAMPLES.md → "Example 6"

**...see the full hook reference**
→ README.md → "Hook Semantics Reference"

**...debug issues**
→ ITEM_REGISTRATION_QUICK_REFERENCE.md → "Errors & Debugging"

**...understand the hook lifecycle**
→ README.md → "Resync Lifecycle"

---

## File Structure

```
ShopsHooksExample/
├── INDEX.md ← You are here
├── GETTING_STARTED.md (new) ← Start here for quick overview
├── DELIVERY_SUMMARY.md (new) ← What was delivered
├── ITEM_REGISTRATION_ADDITIONS.md (new) ← Summary of additions
│
├── 42.13.1/
│   ├── README.md (updated) ← Complete feature overview
│   ├── CONFIGURATION.md ← Price hook configuration
│   ├── GETTING_STARTED.md (new) ← Quick start
│   ├── ITEM_REGISTRATION_QUICK_REFERENCE.md (new) ← Cheat sheet
│   ├── ITEM_REGISTRATION_EXAMPLES.md (new) ← 7 detailed examples
│   ├── IMPLEMENTATION_GUIDE.md
│   ├── mod.info
│   │
│   └── media/lua/server/
│       ├── ShopsHooksExample_init.lua
│       └── nshopsb42/
│           ├── ShopsHooksExampleInit.lua (updated) ← Initialization
│           ├── ShopsHooksExampleHooks.lua ← Price hooks
│           ├── ShopsHooksExampleItems.lua (new) ← Item registration
│           └── ShopsHooksExampleState.lua ← Configuration
│
└── common/
```

**Legend**:

- `(new)` = File created for item registration
- `(updated)` = File modified to add item registration support

---

## Learning Paths

### 5-Minute Path

1. GETTING_STARTED.md (5 min)
2. Run mod, check logs

### 15-Minute Path

1. GETTING_STARTED.md (5 min)
2. ITEM_REGISTRATION_QUICK_REFERENCE.md (5 min)
3. Skim ShopsHooksExampleItems.lua (5 min)

### 30-Minute Path

1. GETTING_STARTED.md (5 min)
2. ITEM_REGISTRATION_QUICK_REFERENCE.md (5 min)
3. Read ShopsHooksExampleItems.lua (10 min)
4. Review 2-3 examples from ITEM_REGISTRATION_EXAMPLES.md (10 min)

### 60-Minute Path (Complete Understanding)

1. GETTING_STARTED.md (5 min)
2. ITEM_REGISTRATION_QUICK_REFERENCE.md (5 min)
3. ITEM_REGISTRATION_EXAMPLES.md (20 min - all 7 examples)
4. ShopsHooksExampleItems.lua (10 min)
5. README.md relevant sections (15 min)
6. ShopsHooksExampleInit.lua (5 min)

---

## Hook Registration Flow

```
Game Startup
    ↓
ShopsHooksExampleInit.lua loads
    ↓
ShopsHooksExample.initialize()
    ↓
[Step 1] configureListingMode()
    └─ Set Shop.SellisWhitelist (whitelist/blacklist)
    ↓
[Step 2] Register item hooks
    ├─ ShopEvents.registerOnShopRegisterItems(registerBuyItems)
    │  └─ Calls: Shop.RegisterItem()
    │
    ├─ ShopSellEvents.registerOnShopRegisterSellItems(registerSellItems)
    │  └─ Calls: Shop.RegisterSellItem() [blacklist mode]
    │
    └─ ShopSellEvents.registerOnShopRegisterSellItems(registerWhitelistSellItems)
       └─ Calls: Shop.RegisterSellItem() [whitelist mode, optional]
    ↓
[Step 3] Register price hooks
    ├─ modifyAppleBuyPrice()
    ├─ overrideAppleBuyPrice()
    └─ modifySellPriceByCondition()
    ↓
Ready for gameplay
```

---

## What Each File Does

### Documentation Files

| File                                 | Purpose                      | Read Time |
| ------------------------------------ | ---------------------------- | --------- |
| INDEX.md                             | This file - Navigation guide | 5 min     |
| GETTING_STARTED.md                   | Quick start and common tasks | 5 min     |
| ITEM_REGISTRATION_QUICK_REFERENCE.md | Syntax cheat sheet           | 5 min     |
| ITEM_REGISTRATION_EXAMPLES.md        | 7 working examples           | 15 min    |
| README.md                            | Complete feature overview    | 20 min    |
| DELIVERY_SUMMARY.md                  | What was delivered           | 10 min    |
| ITEM_REGISTRATION_ADDITIONS.md       | Summary of additions         | 10 min    |

### Code Files

| File                       | Purpose                            | Lines |
| -------------------------- | ---------------------------------- | ----- |
| ShopsHooksExampleInit.lua  | Initialization & hook registration | ~175  |
| ShopsHooksExampleItems.lua | Buy/sell item registration         | ~200  |
| ShopsHooksExampleHooks.lua | Price modification hooks           | ~130  |
| ShopsHooksExampleState.lua | Configuration values               | ~20   |

---

## Key Concepts

### Buy Items

Items **players can purchase** from the shop.

```lua
Shop.RegisterItem("Base.Apple", {
    tab = SHOPSB42.Tab.Food,
    price = 2,
    items = 100
})
```

### Sell Items

Items **shop can buy** from players.

```lua
Shop.RegisterSellItem("Base.Apple", { price = 1 })
Shop.RegisterSellItem("Base.Bomb", { blacklisted = true })
```

### Whitelist Mode

Only **explicitly registered items** can be sold.

```lua
SHOPSB42.Shop.SellisWhitelist = true
```

### Blacklist Mode

**All items** can be sold except those marked blacklisted.

```lua
SHOPSB42.Shop.SellisWhitelist = false
```

---

## Common Tasks

| Task                    | File                       | Section                      |
| ----------------------- | -------------------------- | ---------------------------- |
| Add buy item            | ShopsHooksExampleItems.lua | registerBuyItems()           |
| Add sell item           | ShopsHooksExampleItems.lua | registerSellItems()          |
| Enable whitelist        | ShopsHooksExampleItems.lua | configureListingMode()       |
| Modify buy price        | ShopsHooksExampleHooks.lua | modifyAppleBuyPrice()        |
| Fix sell price          | ShopsHooksExampleHooks.lua | modifySellPriceByCondition() |
| Change price at runtime | ShopsHooksExampleState.lua | appleBuyMultiplier           |

---

## Support

### Having Issues?

1. **Check server logs**: `Logs/Server/*_Shops.txt`
2. **Verify registration**: Look for `[ShopsHooksExample]` messages
3. **Review examples**: ITEM_REGISTRATION_EXAMPLES.md
4. **Check syntax**: ITEM_REGISTRATION_QUICK_REFERENCE.md
5. **Read guides**: README.md or GETTING_STARTED.md

### Common Problems

| Problem            | Solution                                                     |
| ------------------ | ------------------------------------------------------------ |
| Items don't appear | Check registerBuyItems() hook is registered                  |
| Can't sell items   | Verify registerSellItems() hook and whitelist/blacklist mode |
| Wrong prices       | Check price hook is registered and applied                   |
| Logs not showing   | Verify SharedLogger is being used                            |
| Mod doesn't load   | Check Shops mod is installed and enabled                     |

---

## Version Info

- **ShopsHooksExample**: For Project Zomboid Build 42.13.1
- **Shops Mod**: Required (B42.13.1+)
- **Lua**: Uses Project Zomboid Lua API
- **Last Updated**: January 2026

---

## Quick Links

- **Home**: ShopsHooksExample/ (this directory)
- **Main README**: 42.13.1/README.md
- **Quick Start**: 42.13.1/GETTING_STARTED.md
- **Code**: 42.13.1/media/lua/server/nshopsb42/
- **Logs**: Logs/Server/\*\_Shops.txt

---

## Recommended Reading Order

**For beginners**:

1. This index (what you're reading)
2. GETTING_STARTED.md
3. ITEM_REGISTRATION_QUICK_REFERENCE.md
4. ShopsHooksExampleItems.lua (working code)

**For intermediate**:

1. Above, plus:
2. ITEM_REGISTRATION_EXAMPLES.md (all 7 examples)
3. README.md sections on hooks

**For advanced**:

1. All above, plus:
2. ShopsHooksExampleInit.lua (initialization flow)
3. ShopsHooksExampleHooks.lua (price hooks)
4. README.md complete reference

---

## What's Next?

1. **Read** GETTING_STARTED.md (5 min)
2. **Install** the mod
3. **Check** server logs for registration
4. **Customize** ShopsHooksExampleItems.lua for your items
5. **Test** in-game
6. **Refer to** documentation as needed

Happy modding! 🎮
