# Task 3: Undocumented Feature Discovery

## Overview

This document catalogs all features, systems, and subsystems implemented in the Shops mod that are **not mentioned in any checklist file**. For each discovered feature, we assess:

1. **What it does** - Purpose and behavior
2. **Who can trigger it** - Player, admin, server, or automatic
3. **Risk assessment** - MP desync, security, UI breakage
4. **Recommendation** - Document, keep undocumented, or remove

---

## Section 1: Undocumented Event Systems

### 1.1 Shop Lifecycle Event System (ShopEvents.lua)

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/events/ShopEvents.lua`

**Feature**: Custom event dispatcher for shop initialization and item registration.

**Behavior**:
- Allows external mods to hook into shop startup via `OnShopRegisterItems` callback
- Triggered during shop initialization to populate items
- Used by `ShopDefaultItems.lua` to register default shop inventory

**Who Can Trigger**:
- Server-side during initialization
- Any mod that calls `ShopEvents.registerOnShopRegisterItems(callback)`

**Risk Assessment**: 
- ✅ **Low** - Isolated to initialization, no runtime mutations
- ✅ **Documented in code** but not in checklist
- ✅ **Extension point** for modders

**Recommendation**: ✅ **Document in HOOKS_CHECKLIST.md**
- Add section for `OnShopRegisterItems`
- Provide example implementation
- Document parameter signature

### 1.2 Sell Item Registration System (ShopSellEvents.lua)

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/sales/ShopSellEvents.lua`

**Feature**: Custom event system for defining which items players can sell to shops.

**Behavior**:
- Callback-driven system for item sell-back whitelist/pricing
- Triggered during shop setup to populate sellable items
- Used by default items registry

**Who Can Trigger**:
- Server-side during initialization
- Any mod via `ShopSellEvents.registerOnShopRegisterSellItems(callback)`

**Risk Assessment**:
- ✅ **Low** - Isolated initialization
- ✅ **Safe** - No runtime side effects

**Recommendation**: ✅ **Document in HOOKS_CHECKLIST.md**
- Add section for `OnShopRegisterSellItems`
- Document return format

### 1.3 Transaction State Registry (TransactionRegistry.lua)

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/core/TransactionRegistry.lua`

**Feature**: In-memory registry to track transaction IDs and prevent duplicate processing.

**Behavior**:
- `markProcessed(username, txnId)` - Records that a transaction has completed
- `isProcessed(username, txnId)` - Checks if already processed
- Used in ShopBuyAction and ShopSellAction to prevent replay

**State Persistence**: ⚠️ **IN-MEMORY ONLY**
- Lost on server restart
- Exposes replay vulnerability on restart

**Who Can Trigger**:
- Automatically during purchase/sell completion
- Not directly exposed to players

**Risk Assessment**:
- 🔴 **High** - No persistence, replay risk on server restart
- ⚠️ **Medium** - Affects Kiosk and Player Shop purchases/sales
- **Scenario**: Server restarts → Player attempts same purchase with same txnId → Replay succeeds

**Recommendation**: ❌ **Critical: Implement Persistence**
1. Add ModData backend: `ModData.get("ShopTransactions")`
2. Or: Use timestamp-based dedup (transactions older than 24h cannot replay)
3. Or: Integrate with PZ engine transaction log

---

## Section 2: Undocumented Admin/Debug Commands

### 2.1 RemoveShop (Admin Command)

**File**: `ShopCommandDispatcherServer.lua` L51-88

**Feature**: Admin-only command to delete a shop tile from the world.

**Behavior**:
- Permission check: `Utilities.IsPlayerAdmin(player)`
- Resolves shop by grid square coordinates
- Calls `square:transmitRemoveItemFromSquare(obj)`
- Shows halo notification to admin

**Who Can Trigger**: Admin players only (via context menu)

**Risk Assessment**:
- ✅ **Safe** - Permission protected
- ✅ **Correct** - Server-side validation
- ✅ **Documented implicitly** in checklist item B4

**Recommendation**: ✅ **Already Documented**
- Listed in checklist: "Admin can sledgehammer/remove shop"

### 2.2 BalanceRollback (Admin Command)

**File**: `BalanceServer.lua` L657-750

**Feature**: Admin-only command to reverse a currency transfer.

**Behavior**:
- Requires admin status: `if not player:isAdmin()`
- Looks up transfer by `actionId` in audit log
- Handles both online (balance reversal) and offline (mailbox removal) cases
- Logs the rollback action
- Restores balance to sender, deducts from recipient (if online)

**Who Can Trigger**: Admin players only (not exposed in UI checklist)

**Risk Assessment**:
- ✅ **Safe** - Admin-only, audit trail
- ⚠️ **Undocumented** - Not in checklist, no UI mentioned
- ⚠️ **Asymmetric** - Admin can reverse transfers, but no equivalent for purchases

**Recommendation**: ⚠️ **Document as Feature**
1. Add to admin checklist: "Admin can rollback transfers via actionId"
2. Expose in admin UI if not already
3. Add equivalent rollback for purchases (symmetry)

### 2.3 TestPing (Debug Command)

**File**: `ShopCommandDispatcherServer.lua` L20-23

**Feature**: Simple server-side ping/connectivity test.

**Behavior**:
```lua
function Commands.TestPing(player, args)
    SharedLogger.log("Shops", "TEST PING from " .. player:getUsername())
end
```

**Who Can Trigger**: Any client that sends command (no permission check visible)

**Risk Assessment**:
- ✅ **Safe** - Read-only, no mutations
- ⚠️ **Undocumented debug tool**
- ⏳ **Should be removed or gated** before release

**Recommendation**: ❌ **Remove or Gate with Debug Flag**
1. Add permission check (admin only)
2. Or: Remove before release (debug-only)
3. Document if kept: "Debug connectivity test, admin-only"

### 2.4 Price Hook Test Commands (TestPriceHooksCommand.lua)

**File**: `Shops/42.13.1/media/lua/server/nshopsb42/TestPriceHooksCommand.lua`

**Feature**: Development tools for testing price hook system live (without restarting server).

**Behavior**:
- `testapple(multiplier)` - Multiply apple buy price by factor
- `testBatSell(multiplier)` - Multiply baseball bat sell price by factor
- `testAppleOverrideBuy(price)` - Override apple buy price to fixed value
- `testBatOverrideSell(price)` - Override baseball bat sell price to fixed value
- `testappleReset()` - Clear test hooks

**Who Can Trigger**:
- Server console directly
- Or via admin commands (if exposed)
- No visible UI exposure in checklist

**Risk Assessment**:
- ⚠️ **Medium** - Development-only tools
- ⚠️ **Should be gated** before release
- ✅ **Safe** - Does not persist to ModData (resets on restart)
- 🟡 **Risk**: If exposed to non-admin, allows price manipulation

**Recommendation**: ⚠️ **Gate with Debug Flag**
1. Wrap all test commands with `if SandboxVars.SHOPSB42_DEBUG_MODE then` check
2. Document in dev guide, not user docs
3. Remove from production builds
4. Or: Add admin-only permission check

### 2.5 ClearShopSpriteDrag (Utility Command)

**File**: `ShopCommandDispatcherServer.lua` L43-49

**Feature**: Force-clears a player's shop placement cursor (if stuck in drag mode).

**Behavior**:
- Sends `ClearShopSpriteDrag` command back to client
- Client clears its drag/placement state

**Who Can Trigger**:
- Server-side (likely for debugging or admin reset)
- Not exposed in UI checklist

**Risk Assessment**:
- ✅ **Safe** - UI-only state
- ⚠️ **Undocumented** - But harmless
- ✅ **Useful for stuck players**

**Recommendation**: ✅ **Document as Utility**
- Add to admin guide: "Clears stuck shop placement cursor"
- Expose via admin UI if player gets stuck

### 2.6 VirtualDeposit (Internal/Admin Command)

**File**: `BalanceServer.lua` L97-145

**Feature**: Server-side balance increase without requiring coin items.

**Behavior**:
- `args.username` - Target player
- `args.coin` / `args.specialCoin` - Amounts to add
- `args.source` - Log source identifier
- No inventory mutation, pure balance add
- Requires linked wallet: `if not account.linkedTo`

**Who Can Trigger**:
- Server scripts or admin commands
- Not exposed in checklist

**Risk Assessment**:
- ✅ **Safe** - Server-side, logged
- ⚠️ **Undocumented** - But useful for admin/quest systems
- 🟡 **Audit trail** - Logged with source identifier

**Recommendation**: ✅ **Document as Admin Feature**
1. Add to admin guide: "Grant coins to player programmatically"
2. Expose via admin command UI
3. Document source codes for audit tracking

---

## Section 3: Undocumented UI Systems

### 3.1 BundleViewerUI (Item Bundle Inspector)

**File**: `client/nshopsb42/ui/BundleViewerUI.lua`

**Feature**: Standalone UI window to inspect contents of virtual bundles before purchase.

**Behavior**:
- Displayed when player clicks "View Contents" on bundle item
- Shows list of items and quantities within bundle
- Read-only display (no purchase/interact from here)
- Can search/filter items in bundle

**Who Can Trigger**: Players browsing shop (when bundles are available)

**Risk Assessment**:
- ✅ **Safe** - Read-only display
- ⏳ **Not mentioned in checklist** but implied by "Pack items display correctly"

**Recommendation**: ✅ **Already Implemented, Needs Documentation**
- Document in checklist under "Shop Features": "Bundle contents viewable before purchase"
- Clarify difference between "virtual bundles" and "pack containers"

### 3.2 ContainerViewerUI (Nested Container Browser)

**File**: `client/nshopsb42/ui/ContainerViewerUI.lua`

**Feature**: Nested container viewer allowing inspection of containers-within-containers.

**Behavior**:
- Allows browsing into bags/boxes/containers from shop UI
- Shows items in nested containers
- Sub-window popup for deep nesting
- Search filter for finding items

**Who Can Trigger**: Players browsing complex pack items

**Risk Assessment**:
- ✅ **Safe** - Read-only inspection
- ⏳ **Partially mentioned** as "Pack items display contents correctly"

**Recommendation**: ✅ **Document in Checklist**
- Clarify that nested containers (bags within boxes) are browsable
- Confirm behavior is working correctly

### 3.3 IncomeUI (Player Shop Income Ledger)

**File**: `client/nshopsb42/ui/IncomeUI.lua`

**Feature**: Management panel for player shop owners showing buyer history and payment breakdown.

**Behavior**:
- Displays list of buyers with payment amounts
- Separates normal coin and special coin income
- "Get Income" button to withdraw all income
- Requires linked wallet to receive income
- Search/filter for specific buyers

**Who Can Trigger**: Player shop owners when managing their shop

**Risk Assessment**:
- ✅ **Safe** - UI displays ModData (read-only until "Get Income")
- ⏳ **Partially mentioned in checklist**: "View Income UI shows buyer + payment"

**Recommendation**: ✅ **Already Documented**
- Checklist item C1.8: "View Income UI shows buyer + payment"
- Verify "Get Income" properly calls server command

### 3.4 TransferUI (P2P Currency Bank)

**File**: `client/nshopsb42/ui/TransferUI.lua` (L3-404)

**Feature**: Full-featured peer-to-peer currency transfer interface (bank-style).

**Behavior**:
- Search/autocomplete for recipient username
- Amount input with decimal support
- Submit button triggers SendTransferAction (timed action)
- Shows transfer progress bar
- Can cancel in-flight transfers (latching mechanism)
- Displays sender balance and recipient online status

**Who Can Trigger**: Any player (via wallet right-click context menu)

**Risk Assessment**:
- ✅ **Safe** - Server-side validation in BalanceServer.Transfer()
- ✅ **Rate-limited** - RATE_LIMIT config prevents spam
- ⏳ **Documented in checklist** but UI details not fully specified

**Recommendation**: ✅ **Already Documented**
- Checklist item A2: "Open Transfer UI from wallet"
- Clarify decimal amount handling and rate limits

### 3.5 PreviewUI (3D Vehicle Previewer)

**File**: `client/nshopsb42/ui/PreviewUI.lua`

**Feature**: 3D scene viewer for previewing vehicles (pinkslips) before purchase.

**Behavior**:
- Renders 3D model of vehicle in UI window
- Multiple camera angles: Top, Front, Side
- Uses `ISUI3DScene` (PZ engine 3D rendering)
- Interactive rotation/zoom (if supported)

**Who Can Trigger**: Players viewing pinkslip items in shop

**Risk Assessment**:
- ⏳ **WIP/Blocked** - Requires pinkslip mod update to B42 (currently not updated)
- ✅ **Safe** - Display-only, no mutations
- ⏳ **Mentioned in checklist**: "Car viewer works (pinkslip only)" - marked as ⏳ WIP

**Recommendation**: ⏳ **Keep as WIP**
- Wait for pinkslip mod to update to B42
- Code is safe, just non-functional dependency

### 3.6 ShopSpriteCursorUI (Building Placement Cursor)

**File**: `client/nshopsb42/transactions/ShopSpriteCursorUI.lua`

**Feature**: Custom cursor for placing player shops (with lazy-loaded engine class).

**Behavior**:
- Derives from ISBuildingObject (PZ engine class) lazily
- Handles rotation via R key
- Communicates with ISAddPlayerShopAction
- Shows preview sprite while dragging

**Who Can Trigger**: Players placing a player shop on ground

**Risk Assessment**:
- ✅ **Safe** - Standard PZ placement UI
- ✅ **Documented in checklist**: "Rotate shop (R key) → both positions valid"

**Recommendation**: ✅ **Already Documented**

---

## Section 4: Undocumented Monkey Patches

### 4.1 ISInventoryPagePatch (Inventory UI Modification)

**File**: `client/nshopsb42/patches/ISInventoryPagePatch.lua`

**Feature**: Patches vanilla inventory UI to hide "Remove" button for shop-owned containers.

**Behavior**:
- Intercepts inventory page rendering
- Checks if container has owner ModData (shop ownership marker)
- Hides remove button if owned

**Who Can Trigger**: Automatically when inventory UI renders

**Risk Assessment**:
- ✅ **Safe** - UI-only, enforced server-side via InventoryTransferValidation
- ✅ **Necessary** - Prevents client-side UI confusion
- ✅ **Documented implicitly** in checklist: "Only owner can remove items"

**Recommendation**: ✅ **Already Documented**

### 4.2 ISTransferActionPatch (Server-Side Transfer Validation)

**File**: `server/nshopsb42/patches/ISTransferActionPatch.lua`

**Feature**: Patches vanilla item transfer (drag/drop) to validate shop ownership.

**Behavior**:
- Server-side patch to transfer action
- Calls InventoryTransferValidation.validateShopOwnership()
- Blocks non-owner transfers from shop containers

**Who Can Trigger**: Automatically on item transfer attempts

**Risk Assessment**:
- ✅ **Safe** - Server-side validation, critical security check
- ✅ **Necessary** - Prevents item theft exploits
- ✅ **Documented implicitly** in checklist: "Only owner can remove items"

**Recommendation**: ✅ **Already Documented**

### 4.3 ISInventoryTransferActionPatch (Client-Side Transfer Validation)

**File**: `client/nshopsb42/patches/ISInventoryTransferActionPatch.lua`

**Feature**: Client-side patch to prevent drag/drop UI actions for shop containers.

**Behavior**:
- Blocks client-side drag/drop from shop containers
- Complementary to server-side validation
- Prevents confusing UI states

**Who Can Trigger**: Automatically on inventory interaction

**Risk Assessment**:
- ✅ **Safe** - UI-only (server validates anyway)
- ✅ **Necessary** - Prevents client-side confusion
- ✅ **Documented implicitly** in checklist

**Recommendation**: ✅ **Already Documented**

### 4.4 ISToolTipInvPatch (Tooltip Enhancement)

**File**: `client/nshopsb42/patches/ISToolTipInvPatch.lua`

**Feature**: Patches inventory item tooltips to display price and wallet balance info.

**Behavior**:
- Intercepts tooltip generation
- Adds item price from ModData
- Adds wallet account balance (if wallet selected)
- Shows special coin indicator

**Who Can Trigger**: Automatically when hovering over items

**Risk Assessment**:
- ✅ **Safe** - Display-only, reads from ModData
- ✅ **UX improvement** - Shows important info in tooltip
- ✅ **Documented implicitly** in checklist: "Wallet tooltip displays current account balance"

**Recommendation**: ✅ **Already Documented**

### 4.5 ISDestroyCursorPatch (Shop Destruction Prevention)

**File**: `server/nshopsb42/patches/ISDestroyCursorPatch.lua`

**Feature**: Prevents players from destroying shop tiles (makes them indestructible).

**Behavior**:
- Server-side patch to destruction action
- Checks if object is a shop sprite
- Blocks destruction for non-admin
- Allows admin to destroy (via separate command)

**Who Can Trigger**: Automatically when player tries to destroy shop

**Risk Assessment**:
- ✅ **Safe** - Server-side, admin-bypassable
- ✅ **Necessary** - Prevents griefing
- ✅ **Documented in checklist**: "Shop tile indestructible for players" + "Admin can sledgehammer/remove shop"

**Recommendation**: ✅ **Already Documented**

---

## Section 5: Undocumented Validation Systems

### 5.1 ShopTransactionValidationServer

**File**: `server/nshopsb42/transactions/ShopTransactionValidationServer.lua`

**Feature**: Server-side validation for shop transactions (purchases/sales).

**Behavior**:
- Validates player has necessary balance
- Validates shop exists
- Validates proximity to shop (distance <= 2)
- Validates sufficient inventory space
- Called before executing timed action completion

**Who Can Trigger**: Automatically during purchase/sale processing

**Risk Assessment**:
- ✅ **Safe** - Server-side validation
- ✅ **Critical security check** - Prevents balance exploit
- ⏳ **Partially documented** - Implicit in timed action flow

**Recommendation**: ✅ **Already Documented**

### 5.2 InventoryTransferValidation (Shop Ownership Check)

**File**: `shared/nshopsb42/validation/InventoryTransferValidation.lua`

**Feature**: Validates that only shop owner can transfer items from shop container.

**Behavior**:
- Checks source and destination containers for owner ModData
- Allows admin override
- Used by ISTransferActionPatch and vanilla transfer logic
- Prevents both removal and addition by non-owners

**Who Can Trigger**: Automatically on any inventory transfer

**Risk Assessment**:
- ✅ **Safe** - Server-side enforcement
- ✅ **Critical** - Prevents item theft
- ✅ **Documented in checklist**: "Only owner can remove items"

**Recommendation**: ✅ **Already Documented**

---

## Section 6: Undocumented Data Structures

### 6.1 ModData Keys

The following ModData keys are used but not fully documented:

| Key | Purpose | Persistence | Notes |
|---|---|---|---|
| `CoinBalance` | User account balances | ✅ Persistent | `{ username: { coin, specialCoin, linkedTo } }` |
| `BalanceMailbox` | Offline transfer queue | ✅ Persistent | Delivered on player login |
| `ShopTransactions` | Transaction state (in-memory) | ❌ Not persistent | **BUG**: Should be ModData-backed |
| Item ModData `.price` | Player shop item price | ✅ Persistent | Set by owner, read by buyer |
| Item ModData `.specialCoin` | Player shop special coin flag | ✅ Persistent | Indicates if price is in special coin |
| Item ModData `.belongsTo` | Wallet ownership | ✅ Persistent | Linked wallet username |
| Item ModData `.linkedTo` | Account link (wallet) | ✅ Persistent | Target account username |
| Container ModData `.owner` | Player shop owner | ✅ Persistent | Username of owner |

**Recommendation**: 
1. Document all ModData keys in a shared reference
2. Fix ShopTransactions persistence
3. Add validation for ModData structure on load

### 6.2 Shop Sprite System

**File**: `shared/nshopsb42/core/Shop.lua`

**Feature**: Defines NPC sprite variants and textures for kiosk shops.

**Behavior**:
- `Shop.sprites` - Maps NPC type codes to sprite definitions
- `Shop.textures` - Maps texture names to image paths
- Used by placement UI to show preview

**Who Can Trigger**: Admin placing shops

**Risk Assessment**:
- ✅ **Safe** - Static definitions
- ⏳ **Partially mentioned** in checklist: "All 4 NPC variations work"

**Recommendation**: ✅ **Document in Admin Guide**
- List available NPC variations
- Show texture options

### 6.3 PlayerShop Theme System

**File**: `shared/nshopsb42/core/PlayerShop.lua`

**Feature**: Maps player shop themes (Medical, Food, etc.) to sprite IDs.

**Behavior**:
- Predefined themes for different shop aesthetics
- Each theme has sprite ID
- Selected during shop placement

**Who Can Trigger**: Players placing player shops

**Risk Assessment**:
- ✅ **Safe** - Static definitions
- ⏳ **Partially mentioned** in checklist: "Change sign → all 10 options available"

**Recommendation**: ✅ **Document in Player Guide**
- List available themes
- Show preview for each

### 6.4 Currency Coin System

**File**: `shared/nshopsb42/core/Currency.lua`

**Feature**: Defines valid coin types and their values.

**Behavior**:
- `Currency.BaseCoin` = "Shops.CopperCoin" (value 1)
- `Currency.SpecialCoin` = "Shops.EventCoin" (special, value 0 for exchange)
- `Currency.Coins` - Coin type registry with textures and values
- Also includes SilverCoin (value 250) and GoldCoin (value 500)

**Who Can Trigger**: All transactions use these definitions

**Risk Assessment**:
- ✅ **Safe** - Static, authoritative definitions
- ⏳ **Partially mentioned** - Checklist mentions "normal + special currency" but not specific coin types

**Recommendation**: ✅ **Document in Player Guide**
- Explain coin hierarchy and values
- Show copper/silver/gold relationships

---

## Section 7: Undocumented Context Menu Actions

### 7.1 World Object Context Menu (ShopContext.lua)

**File**: `client/nshopsb42/context/ShopContext.lua`

**Feature**: Adds shop-related options to world object context menus.

**Behavior**:
- Right-click on shop tile → "View Shop" option
- Right-click on nearby terrain → "View Shop Items" option (if shop in range)
- Applies permission checks (admin only for certain actions)

**Who Can Trigger**: Players right-clicking on shops

**Risk Assessment**:
- ✅ **Safe** - UI-only, server validates
- ✅ **Documented in checklist**: "Right-click shop tile → Shop option appears"

**Recommendation**: ✅ **Already Documented**

### 7.2 Inventory Context Menu (InventoryObjectContextMenuDispatcher.lua)

**File**: `client/nshopsb42/context/InventoryObjectContextMenuDispatcher.lua`

**Feature**: Adds shop-related options to inventory context menus.

**Behavior**:
- Right-click wallet → Link, Unlink, Transfer, Move Coins to Account
- Right-click coins → Deposit, Move to Account, Loot All
- Applies ownership checks

**Who Can Trigger**: Players managing currency

**Risk Assessment**:
- ✅ **Safe** - Server validates
- ✅ **Documented in checklist**: "Right-click wallet shows 4 options"

**Recommendation**: ✅ **Already Documented**

### 7.3 Player Shop Context Menu (PlayerShopContext.lua)

**File**: `client/nshopsb42/context/PlayerShopContext.lua`

**Feature**: Adds player shop management options.

**Behavior**:
- Right-click item in player shop → Set Price, Remove
- Owner-only actions
- Requires Write tag on item for pricing

**Who Can Trigger**: Player shop owners

**Risk Assessment**:
- ✅ **Safe** - Server validates
- ⏳ **Partially documented** in checklist: "Right-click item → Set Price"

**Recommendation**: ✅ **Already Documented**

---

## Section 8: Risk Assessment Summary

### 🔴 Critical Issues Found

| Issue | Severity | File | Recommendation |
|---|---|---|---|
| **TransactionRegistry not persistent** | 🔴 High | TransactionRegistry.lua | Persist to ModData or implement timestamp dedup |
| **sendClientCommand(BalanceWithdraw) handler unclear** | 🔴 High | PlayerShopBuyAction.lua | Verify handler location and execution side |
| **PlayerShop client price trust** | 🔴 High | PlayerShopBuyAction.lua | Add server-side price recomputation |

### ⚠️ Medium-Risk Items

| Issue | Severity | File | Recommendation |
|---|---|---|---|
| **TestPing command exposed** | ⚠️ Medium | ShopCommandDispatcherServer.lua | Gate with admin check or remove |
| **TestPriceHooksCommand exposed** | ⚠️ Medium | TestPriceHooksCommand.lua | Gate with debug flag |
| **BalanceRollback undocumented** | ⚠️ Medium | BalanceServer.lua | Document in admin guide |
| **VirtualDeposit undocumented** | ⚠️ Medium | BalanceServer.lua | Document in admin guide |

### ✅ Items Already Safe/Documented

- All monkey patches (client-side UI / server-side validation pairs)
- All context menu actions
- UI viewers (BundleViewer, ContainerViewer, PreviewUI)
- Hook registration systems
- Static data structures (sprites, themes, coins)

---

## Section 9: Summary Table

### Undocumented Features by Category

| Category | Count | Status | Action |
|---|---|---|---|
| **Event Systems** | 2 | ⏳ Needs doc | Add to HOOKS_CHECKLIST.md |
| **Admin Commands** | 3 | ✅ Safe (1 needs gate) | Document, gate debug tools |
| **Debug Tools** | 2 | ⚠️ Exposed | Gate or remove before release |
| **UI Systems** | 6 | ✅ Safe | Most documented, add details |
| **Monkey Patches** | 5 | ✅ Safe | Already effective |
| **Validation Systems** | 2 | ✅ Safe | Already effective |
| **Data Structures** | 4 | ⚠️ Incomplete | Add to documentation |
| **Context Menus** | 3 | ✅ Safe | Already effective |

---

## Section 10: Recommendations

### Before Release

**Critical** (Must Fix):
1. ✅ **Persist TransactionRegistry** to ModData to prevent replay on server restart
2. ✅ **Clarify sendClientCommand(BalanceWithdraw)** handler location
3. ✅ **Add server-side price validation** for Player Shop purchases

**High Priority** (Should Do):
1. ✅ **Gate debug commands** (TestPing, TestPriceHooksCommand) with admin/debug checks
2. ✅ **Document BalanceRollback** admin feature in admin guide
3. ✅ **Document VirtualDeposit** admin feature in admin guide
4. ✅ **Extend HOOKS_CHECKLIST.md** to include ShopEvents and ShopSellEvents

**Medium Priority** (Nice to Have):
1. ✅ Document all ModData keys in centralized reference
2. ✅ Add admin guide sections for undocumented commands
3. ✅ Clarify bundle/container viewer behavior in checklist

### For Future Documentation

- Create admin operations manual covering rollback, virtual deposit, debug tools
- Document hook system extensions (ShopEvents, ShopSellEvents)
- Create data structure reference (ModData keys, sprites, themes, coins)
- Add troubleshooting guide for stuck placement cursors (ClearShopSpriteDrag)

---

## Section 11: New Checklist Items to Add

### Admin Features Checklist

- [ ] Admin can rollback transfers by actionId
- [ ] Admin can virtuallly deposit coins to player
- [ ] Debug: Can test price multipliers live
- [ ] Debug: Can reset test price hooks
- [ ] Debug: Connectivity test (TestPing) works

### Hook System Checklist

- [ ] OnShopRegisterItems hook triggers during init
- [ ] External mods can register items via hook
- [ ] OnShopRegisterSellItems hook triggers for sell whitelist
- [ ] Multiple hooks can be registered (callback list)

### Data Structure Reference

| Structure | Keys | Type | Notes |
|---|---|---|---|
| CoinBalance | coin, specialCoin, linkedTo | ModData | Per-user account |
| BalanceMailbox | (array of transfers) | ModData | Per-user inbox |
| Item ModData | price, specialCoin, belongsTo, linkedTo | Item | Wallet/item pricing |
| Container ModData | owner | Container | Player shop marker |

---

## Appendix: Feature Maturity Classification

### ✅ Production-Ready
- Currency system (wallet + account + transfers)
- Kiosk shops (placement, purchasing, selling)
- Player shops (ownership, income, locking)
- Admin removal and permissions
- Hook system (prices, registration)
- All validation and security checks
- All UI viewers and panels

### ⏳ Requires Work
- Transaction persistence (in-memory only)
- Debug tool exposure (needs gating)
- Player Shop pricing validation (client-trusted)
- sendClientCommand pattern clarity

### ❌ Blocked by External Dependency
- Vehicle previewer (pinkslip mod not updated)

### 🟡 Undocumented but Working
- BalanceRollback admin command
- VirtualDeposit utility
- Test price hooks
- Nested container viewer
- Bundle inspector

---

## Final Assessment

**Total Undocumented Features**: 30+
- ✅ **Safe/Working**: 25+
- ⚠️ **Needs Documentation**: 5+
- 🔴 **Needs Fixing**: 3+
- ⏳ **Blocked**: 1

**Recommendation**: All features discovered are either working correctly or have clear remediation paths. No unexpected vulnerabilities or broken systems found beyond those identified in Task 2 (Transaction Registry, sendClientCommand clarity, Player Shop pricing trust).
