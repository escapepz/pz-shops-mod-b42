# Phase 2: Client-Side Listing UI (Zero Network) — Implementation Plan

## Overview

Refactor client shop UI to:
1. Load NPC shop catalog directly from shared code (no ModData sync)
2. Calculate preview prices using PricingContract (deterministic)
3. Render item list with preview pricing
4. Remove per-player ModData broadcasts for NPC prices

**Result**: Zero network traffic during shop listing view, targeted packets only for transactions.

---

## Current Architecture (Baseline)

### ModData Synchronization (Per-Player Broadcast)
```
Server:
  - On price change: sendClientCommand(player, "Shop", "SyncBuyPrices", { buyPrices, revision })
  - Broadcasts to EACH PLAYER individually
  - Every frame: can trigger full price recalculation

Client:
  - Receives SyncBuyPrices, stores in Shop.BuyPrices
  - Invalidates UI caches (forces rebuild of all tabs)
  - Renders tabs using Server.Shop.BuyPrices

Traffic: O(n) players × O(m) items = O(n×m) packets per price change
Example: 4 players × 100 items = 400 packets per broadcast
```

### Files Involved (Current)
- **Server**: `ShopFinalizeHandlerServer.lua` — Broadcasts SyncBuyPrices
- **Client**: `ShopSyncClient.lua` — Receives & stores prices
- **Client**: `ShopUI.lua` — Uses Shop.BuyPrices in calcBuyPrice()

---

## Phase 2 Architecture (Target)

### Zero-Network Catalog (Load-Once)
```
Shared:
  - NPCShopCatalog.lua — Static item definitions + base prices
  - PricingContract.lua — Deterministic price calculation

Client:
  - On shop open: Load catalog from NPCShopCatalog.getShopSnapshot()
  - Calculate preview prices using PricingContract.calculateBuyPrice()
  - Render items with preview prices (labeled non-authoritative)
  - Store prices in UI only (not Shop.*)

Server:
  - On transaction: Recompute price using same PricingContract
  - Validate client request (no trust of client price)
  - Return result with FINAL server price

Traffic: 0 during listing, 1 packet per transaction (vs. 400 per broadcast)
```

### Files to Create/Modify

#### New Files
- `pricing/ShopListingNPC.lua` — Client-side NPC listing helper
  - Load catalog
  - Calculate preview prices
  - Handle mismatch tolerance
  
- `client/nshopsb42/ui/ShopListingPreviewer.lua` — UI component
  - Render catalog with preview prices
  - Label prices as non-authoritative
  - Display transaction feedback

#### Modified Files
- `client/nshopsb42/ui/ShopUI.lua` — Remove ModData sync dependency
  - Use PricingContract for preview instead of Shop.BuyPrices
  - Remove call to ShopSyncClient.invalidateUI() on price change
  - Keep server validation intact (Phase 3)

- `client/nshopsb42/sync/ShopSyncClient.lua` — Remove per-player broadcasts
  - Keep handleSyncInitialComplete() for late-join
  - Remove handleSyncBuyPrices() (no longer broadcast)
  - Remove reactive invalidation on price change

- `server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua` — Stop broadcasting
  - Remove sendClientCommand() calls to broadcast SyncBuyPrices
  - Keep targeted transaction responses

---

## Phase 2.1: Refactor Client Shop UI

### 2.1.1 Create ShopListingNPC.lua

**Purpose**: Shared module for deterministic client-side shop listing

**Module**: `Shops/42.13.1/media/lua/shared/nshopsb42/ui/ShopListingNPC.lua`

**Functions**:
```lua
ShopListingNPC.loadShop(shopId)
  -- Load catalog snapshot
  -- Returns: { shopId, name, items = { itemId -> { basePrice, category, ... } } }

ShopListingNPC.getPreviewPrice(itemId, basePrice, playerSnapshot, modifiers)
  -- Calculate preview price using PricingContract
  -- Input: item, base price, immutable player snapshot
  -- Returns: { previewPrice, finalPrice, isFinal }
  -- isFinal = false means server may differ

ShopListingNPC.validateMismatch(itemId, clientPrice, serverPrice)
  -- Check price consistency (development aid)
  -- Logs mismatch if difference > tolerance
```

**Key Design**:
- No ModData access
- No server calls
- Pure calculation from static data
- Preview prices never LOCK the UI
- Server price is ALWAYS final truth

### 2.1.2 Update ShopUI.lua

**Changes**:
1. On shop open: Call ShopListingNPC.loadShop() instead of waiting for SyncBuyPrices
2. In calcBuyPrice(): Use PricingContract directly, not Shop.BuyPrices
3. Remove dependency on ShopSyncClient.invalidateUI()
4. Add price mismatch handler (Phase 2.3)

**Before** (current):
```lua
function ShopUI:render()
    -- Wait for SyncBuyPrices before rendering
    if not Shop.BuyPrices then
        return  -- Defer until server syncs
    end
    
    -- Use server-provided prices
    local price = Shop.BuyPrices[itemId]
    -- ...
end
```

**After** (Phase 2):
```lua
function ShopUI:render()
    -- Load catalog immediately (no wait)
    local catalog = ShopListingNPC.loadShop("npc_general_store")
    
    -- Calculate preview price locally
    local itemCatalog = catalog.items[itemId]
    local previewPrice = ShopListingNPC.getPreviewPrice(
        itemId, 
        itemCatalog.basePrice,
        getPlayerSnapshot(),
        {}
    )
    
    -- Render with preview (marked non-authoritative)
    drawText("Price (preview): " .. previewPrice, ...)
end
```

### 2.1.3 Remove ModData Sync Dependency

**Current flow**:
1. Client requests shop data
2. Server broadcasts SyncBuyPrices per player
3. Client stores in Shop.BuyPrices
4. UI renders using Shop.BuyPrices

**New flow**:
1. Client loads catalog from shared NPCShopCatalog
2. Client calculates prices using PricingContract
3. UI renders preview prices (labeled non-authoritative)
4. Server validates on transaction (no client price trusted)

**Benefit**:
- Zero per-player broadcasts
- Instant listing (no wait for server)
- Price consistency guaranteed (deterministic calculation)
- Late-join works immediately (catalog is static)

---

## Phase 2.2: Remove Client ModData Syncing

### 2.2.1 Stop Broadcasting SyncBuyPrices (Server-Side)

**File**: `server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`

**Current**:
```lua
function ShopFinalizeHandlerServer.broadcastPricesToAllPlayers(data)
    sendClientCommand(nil, "Shop", "SyncBuyPrices", data)  -- Broadcast to all
end

function ShopFinalizeHandlerServer.broadcastPricesToPlayer(player, data)
    sendClientCommand(player, "Shop", "SyncBuyPrices", data)  -- Per-player
end

-- Called on every price change
Events.OnPriceHooksChanged:Add(broadcastPricesToAllPlayers)
```

**New**:
```lua
-- These functions REMOVED entirely
-- No SyncBuyPrices broadcasts (client calculates deterministically)

-- Late-join sync still handled (Phase 3: targeted handshake only)
```

### 2.2.2 Remove Reactive UI Invalidation (Client-Side)

**File**: `client/nshopsb42/sync/ShopSyncClient.lua`

**Current**:
```lua
function ShopSyncClient.handleSyncBuyPrices(data)
    -- Store prices
    Shop.BuyPrices = data.buyPrices
    
    -- Invalidate UI
    ShopSyncClient.invalidateUI(ShopSyncClient.InvalidateReason.BUY_PRICE_DELTA)
end

-- Registered listener
Events.OnServerCommand:Add(ShopSyncClient.onServerCommand)
```

**New**:
```lua
function ShopSyncClient.handleSyncBuyPrices(data)
    -- REMOVED entirely
    -- Client no longer receives broadcast prices
    -- Client calculates deterministically instead
end

-- Listener no longer needed for this command
```

### 2.2.3 Document Removed Per-Player Sync

**Create document**: `docs/PHASE_2_SYNC_REMOVAL.md`

Explains:
- Why per-player broadcasts are removed
- What code paths are affected
- Backward compatibility notes
- Migration guide for existing mods

---

## Phase 2.3: Add Client Price Mismatch Handler

### 2.3.1 Tolerance & Validation

**Purpose**: Detect and handle server price ≠ client preview price

**Cases**:
1. **Expected**: Modifiers applied server-side only
2. **Expected**: Server validates/sanitizes price
3. **Warning**: Mods have non-deterministic hooks
4. **Error**: Game desync bug

**Handler**:
```lua
function ShopUI.validateTransactionPrice(itemId, clientPreview, serverFinal)
    local tolerance = 1  -- Allow ±1 coin variation
    
    if math.abs(clientPreview - serverFinal) <= tolerance then
        return true  -- Match within tolerance
    end
    
    -- Log mismatch (development aid)
    PricingContract.validatePriceConsistency(itemId, clientPreview, serverFinal)
    
    -- UI silently updates to server price (no resync triggered)
    return true
end
```

### 2.3.2 Transaction Result Handling

**On transaction success**:
```lua
function ShopBuyAction.onTransactionResult(data)
    local itemId = data.itemId
    local clientPrice = ui.lastPreviewPrice[itemId]
    local serverPrice = data.finalPrice
    
    -- Validate (logs mismatch silently)
    ShopUI.validateTransactionPrice(itemId, clientPrice, serverPrice)
    
    -- Update UI silently (no rebuild)
    Shop.BuyPrices[itemId] = serverPrice
    
    -- Show feedback to user
    displayMessage("Transaction successful!")
    
    -- Do NOT trigger full shop rebuild
end
```

### 2.3.3 Insufficient Funds (No Resync)

**Current behavior** (WRONG):
```lua
if not player:hasMoneyTo(finalPrice) then
    broadcastSyncToPlayer(player)  -- Full resync ← BAD
end
```

**New behavior** (CORRECT):
```lua
if not player:hasMoneyTo(finalPrice) then
    sendServerCommand(player, "Shop", "TransactionFailed", {
        reason = "insufficient_funds",
        itemId = itemId,
        needed = finalPrice,
        current = player:getMoney()
    })
    -- No resync, no broadcast
    -- User sees error, can add more money, try again
end
```

---

## Success Criteria (Phase 2)

### 2.1: Client UI Refactoring
- [x] ShopListingNPC.lua created with preview pricing functions
- [x] ShopUI.lua updated to use PricingContract instead of Shop.BuyPrices
- [x] Shop catalog loads on open (no wait for server)
- [x] Preview prices labeled non-authoritative internally
- [x] Logging shows zero SyncBuyPrices on listing

### 2.2: Sync Removal
- [x] SyncBuyPrices broadcasts removed from ShopFinalizeHandlerServer
- [x] Reactive invalidation removed from ShopSyncClient
- [x] No per-player ModData.transmit() in transaction handlers
- [x] Verified: 0 broadcasts during listing, 1 packet per transaction

### 2.3: Mismatch Handler
- [x] validateTransactionPrice() handles client ≠ server
- [x] Mismatch logged silently (development aid)
- [x] UI updates without full rebuild
- [x] Insufficient funds returns error (no resync)

---

## Network Traffic Baseline (Testing)

**Before Phase 2**:
- 4 players, 100 items
- 1 price change broadcast
- Result: 400 packets + 4 broadcasts = 404 packets

**After Phase 2**:
- 4 players, 100 items
- 1 shop view + 1 transaction
- Result: 0 broadcasts + 1 targeted response = 1 packet
- **Reduction: 99.75%**

---

## Integration Notes

- **Backward Compatibility**: Player shops still use ModData (Phase 4 will optimize)
- **NPC Shops**: Full deterministic model (no server dependence)
- **Late-Join**: Handled by separate sync (Phase 3)
- **Price Changes**: Server price computed on-demand (no broadcast)

