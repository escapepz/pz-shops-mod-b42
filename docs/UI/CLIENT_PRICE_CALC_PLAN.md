# Client-Side Price Calculation Implementation Plan

## Overview

Implement client-side price **preview** calculation to reduce network traffic while maintaining server authority. Server sends data-driven price modifier rules once at game start; client uses them for UI preview only. Server recalculates and validates all actual transaction prices.

**Goals:**
- Eliminate per-transaction price request calls for UI preview
- Reduce network packages (1 sync vs N requests)
- Support dynamic hook registration after boot
- **Maintain server as single source of truth for final prices**
- Prevent client-side cheating by re-validating on server

---

## Architecture

```
Server (Authority)
├── Build data-driven price modifier rules from registered hooks
├── Send SyncShopData (items, buy/sell config)
├── Send SyncPriceModifiers (rule descriptors, conditions, overrides)
└── Recalculate & validate all prices during transaction completion

Client (Preview Calculator)
├── Receive and store modifier data
├── Calculate preview prices for UI (using shared calculator)
└── Send transaction request (client price is advisory only)
```

### Data Flow

```
Game Start
  ├─ Client: OnGameStart event
  │  └─ sendClientCommand("Shops", "RequestShopData", {})
  │
  ├─ Server: OnServerCommand received
  │  ├─ Build data-driven modifier rules from hooks (classify client-safe vs server-only)
  │  ├─ sendServerCommand(player, "Shops", "SyncShopData", {...})
  │  └─ sendServerCommand(player, "Shops", "SyncPriceModifiers", {...})
  │
  └─ Client: OnServerCommand received
     ├─ Store Shop.Items, PlayerBuy, PlayerSell
     └─ Store Shop.PriceModifiers for UI preview only

Transaction (Buy/Sell) - MP
  ├─ Client: calcPrice(itemId, player) via shared Calculator
  │  ├─ Shows preview price in UI (no network call)
  │  └─ Sends transaction request with preview price (ignored)
  │
  └─ Server: On transaction completion
     ├─ Recalculate price using same modifier rules
     ├─ Validate price matches acceptable range (with tolerance for hooks)
     ├─ Execute transaction or reject if mismatch

Transaction (Buy/Sell) - SP
  ├─ Client: calcPrice(itemId, player) via shared Calculator
  │  └─ Calculates using local modifiers
  │
  └─ No server validation (single player)
```

---

## Phase 1: Server - Build & Send Modifier Data

### 1.1 Define Modifier Schema & Rule Types

**Modifier Structure (Serializable):**

All modifiers use data-driven descriptors, not executable functions.

```lua
Modifier = {
  id = "unique_id",           -- Unique identifier for this rule
  type = "buy" | "sell",      -- Which transaction type
  priority = 100,             -- Lower = applied first (for consistent ordering)
  condition = {               -- When to apply (data-driven only)
    kind = "always" 
      | "difficulty_ge" 
      | "item_condition_ge"
      | "player_trait"
      | "server_only",        -- Forces server-side calculation
    params = { ... }          -- Rule-specific parameters
  },
  effect = {                  -- What to do (data-driven only)
    kind = "multiply" | "add" | "set",
    value = 0.8,              -- For multiply/add
    -- OR
    valueKind = "item_condition_ratio",  -- For sell (dynamic per item)
  },
  description = "Why this rule exists"
}
```

**Supported Client-Safe Conditions:**

| kind               | params              | Usage                                   |
| ------------------ | ------------------- | --------------------------------------- |
| `always`           | (none)              | Always apply                            |
| `difficulty_ge`    | `level` (1-4)       | Game difficulty >= threshold            |
| `item_condition_ge`| `percent` (0-100)   | Item condition >= threshold             |
| `player_trait`     | `traitName`         | Player has trait (from loaded mods)     |
| `server_only`      | (none)              | Forces server recalculation (fallback)  |

**Supported Effects:**

| kind       | value kind            | Usage                        |
| ---------- | --------------------- | ---------------------------- |
| `multiply` | number (0.5, 1.5)     | Multiply base price          |
| `add`      | number (10, -5)       | Add/subtract from price      |
| `set`      | number (100)          | Override to fixed price      |
| (dynamic)  | `item_condition_ratio`| Multiply by item% condition  |

### 1.2 Create `ShopPriceModifierBuilder.lua` (Shared)

**Path:** `Shops/42.13.1/media/lua/shared/nshopsb42/pricing/ShopPriceModifierBuilder.lua`

**Purpose:** Extract hook callbacks and classify them into client-safe rules or mark as server-only.

```lua
-- ShopPriceModifierBuilder.lua
-- Convert registered price hooks into serializable modifier rules
-- Classifies each hook: client-safe vs server-only
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopPriceModifierBuilder = SHOPSB42.ShopPriceModifierBuilder or {}
local Builder = SHOPSB42.ShopPriceModifierBuilder

-- Build price modifier data from registered hooks
-- Returns {buyModifiers, sellModifiers, buyOverrides, sellOverrides, requiresServer}
function Builder.buildPriceModifiers()
  local Shop = SHOPSB42.Shop
  local ShopPriceEvents = SHOPSB42.ShopPriceEvents
  
  local modifiers = {
    buyModifiers = {},
    sellModifiers = {},
    buyOverrides = {},
    sellOverrides = {},
    requiresServer = false  -- Flag: if true, client should not use cached prices
  }
  
  local buyHookCount = (ShopPriceEvents.OnShopModifyBuyPrice and #ShopPriceEvents.OnShopModifyBuyPrice or 0)
    + (ShopPriceEvents.OnShopOverrideBuyPrice and #ShopPriceEvents.OnShopOverrideBuyPrice or 0)
  local sellHookCount = (ShopPriceEvents.OnShopModifySellPrice and #ShopPriceEvents.OnShopModifySellPrice or 0)
    + (ShopPriceEvents.OnShopOverrideSellPrice and #ShopPriceEvents.OnShopOverrideSellPrice or 0)
  
  SharedLogger.log(
    "Shops",
    "[PriceModifierBuilder] Registered hooks - Buy: " .. buyHookCount .. ", Sell: " .. sellHookCount
  )
  
  -- STUB: Extract and classify hooks into rule descriptors
  -- For each hook:
  --   1. Determine if it can be converted to a client-safe rule (difficulty, traits, etc.)
  --   2. If convertible: add to modifiers.buyModifiers or modifiers.sellModifiers
  --   3. If not convertible: set modifiers.requiresServer = true
  --   4. Log classification for debugging
  -- 
  -- Example (to be implemented):
  -- if hook_is_static_multiplier then
  --   table.insert(modifiers.buyModifiers, {
  --     id = "hook_id",
  --     type = "buy",
  --     priority = 100,
  --     condition = { kind = "always" },
  --     effect = { kind = "multiply", value = 0.8 }
  --   })
  -- else
  --   modifiers.requiresServer = true
  -- end
  
  return modifiers
end

return Builder
```

### 1.3 Update `ShopFinalizeHandlerServer.lua`

**Modifications:**
- Add require for `ShopPriceModifierBuilder`
- After registry finalization, build modifier data
- Store modifiers server-side and send to **specific clients on connect** (not broadcast)
- Guard against double-finalization in SP/MP

```lua
-- Add at top
local Builder = require("nshopsb42/pricing/ShopPriceModifierBuilder")

-- Modify finalizeNow() function - ensure it only runs once
function ShopFinalizeHandler.finalizeNow()
  if ShopFinalizeHandler._finalizationAttempted then
    return
  end
  ShopFinalizeHandler._finalizationAttempted = true

  if not Shop._locked then
    SharedLogger.log("Shops", "[ShopFinalizeHandler] Finalizing buy registry...")
    Shop.FinalizeRegistry()
  end

  if not Shop._sellLocked then
    SharedLogger.log("Shops", "[ShopFinalizeHandler] Finalizing sell registry...")
    Shop.FinalizeSellRegistry()
  end
  
  -- NEW: Build and cache price modifiers server-side
  SharedLogger.log("Shops", "[ShopFinalizeHandler] Building price modifiers...")
  local priceModifiers = Builder.buildPriceModifiers()
  
  -- Store on server for reuse during transactions
  SHOPSB42.Shop.PriceModifiers = priceModifiers
  
  if priceModifiers.requiresServer then
    SharedLogger.log("Shops", "[ShopFinalizeHandler] WARNING: Some hooks require server-side calculation")
  end
  
  SharedLogger.log("Shops", "[ShopFinalizeHandler] Price modifiers built and cached")
end

-- NEW: Send data to a specific player (called when they connect)
function ShopFinalizeHandler.sendShopDataToPlayer(player)
  if not isServer() then return end
  
  local Shop = SHOPSB42.Shop
  
  -- Send shop items and config
  local shopData = {
    Items = Shop.Items,
    PlayerBuy = Shop.PlayerBuy,
    PlayerSell = Shop.PlayerSell,
    BuyIsWhitelist = Shop.BuyIsWhitelist,
    SellIsWhitelist = Shop.SellIsWhitelist,
  }
  
  sendServerCommandTo(player, "Shops", "SyncShopData", shopData)
  
  -- Send cached price modifiers
  local priceModifiers = Shop.PriceModifiers or {}
  sendServerCommandTo(player, "Shops", "SyncPriceModifiers", priceModifiers)
  
  SharedLogger.log("Shops", "[ShopFinalizeHandler] Synced shop data to " .. player:getUsername())
end
```

---

## Phase 2: Client - Receive & Store Modifier Data

### 2.1 Create `ShopSyncClient.lua` (Client)

**Path:** `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua`

**Purpose:** Handle server commands for shop data sync.

```lua
-- ShopSyncClient.lua
-- Client-side receiver for shop data synchronization
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopSyncClient = SHOPSB42.ShopSyncClient or {}
local ShopSyncClient = SHOPSB42.ShopSyncClient

-- Register server command handlers
function ShopSyncClient.Initialize()
  Events.OnServerCommand.Add(ShopSyncClient.handleServerCommand)
  SharedLogger.log("Shops", "[ShopSyncClient] Initialized")
end

function ShopSyncClient.handleServerCommand(module, command, data)
  if module ~= "Shops" then return end
  
  local Shop = SHOPSB42.Shop
  
  if command == "SyncShopData" then
    SharedLogger.log("Shops", "[ShopSyncClient] Received SyncShopData")
    Shop.Items = data.Items or {}
    Shop.PlayerBuy = data.PlayerBuy or {}
    Shop.PlayerSell = data.PlayerSell or {}
    Shop.BuyIsWhitelist = data.BuyIsWhitelist or false
    Shop.SellIsWhitelist = data.SellIsWhitelist or false
    
    local itemCount = 0
    for _ in pairs(Shop.Items) do itemCount = itemCount + 1 end
    SharedLogger.log("Shops", "[ShopSyncClient] Stored " .. itemCount .. " items")
    
  elseif command == "SyncPriceModifiers" then
    SharedLogger.log("Shops", "[ShopSyncClient] Received SyncPriceModifiers")
    Shop.PriceModifiers = data or {}
    SharedLogger.log("Shops", "[ShopSyncClient] Price modifiers updated")
  end
end

return ShopSyncClient
```

### 2.2 Update `Init.lua` (Client)

**Add require and initialization:**

```lua
-- Add to requires section
require("nshopsb42/sync/ShopSyncClient")

-- Add game start handler
local function onGameStart()
  local ShopSyncClient = SHOPSB42.ShopSyncClient
  ShopSyncClient.Initialize()
  
  -- Request shop data from server
  if isClient() or SHOPSB42.Utilities.IsSinglePlayer() then
    sendClientCommand("Shops", "RequestShopData", {})
    writeLog("Shops", "[Client Init] Requested shop data")
  end
end

Events.OnGameStart.Add(onGameStart)
```

### 2.3 Server Handler for RequestShopData

**Location:** `ShopInitServer.lua` or new handler

```lua
-- Handle client requests for shop data (MP only)
local function onClientCommand(module, command, player, data)
  if module ~= "Shops" or command ~= "RequestShopData" then return end
  
  local ShopFinalizeHandler = require("nshopsb42/transactions/ShopFinalizeHandlerServer")
  
  -- Use cached modifiers from finalization phase
  ShopFinalizeHandler.sendShopDataToPlayer(player)
end

Events.OnClientCommand.Add(onClientCommand)
```

---

## Phase 3: Client - Calculate Prices Locally

### 3.1 Create `ShopPriceCalculatorShared.lua` (Shared)

**Path:** `Shops/42.13.1/media/lua/shared/nshopsb42/pricing/ShopPriceCalculatorShared.lua`

**Purpose:** Evaluate data-driven modifier rules consistently on both client (preview) and server (validation).

**This calculator DOES NOT execute arbitrary functions.** It only interprets data-driven rule descriptors.

```lua
-- ShopPriceCalculatorShared.lua
-- Shared price calculation using data-driven modifier rules
-- Safe for both client preview and server validation
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopPriceCalculatorShared = SHOPSB42.ShopPriceCalculatorShared or {}
local Calculator = SHOPSB42.ShopPriceCalculatorShared

-- Evaluate a condition descriptor
-- Returns: boolean (whether condition is met)
local function evaluateCondition(condition, player, item, context)
  if not condition then return true end
  
  local kind = condition.kind
  
  if kind == "always" then
    return true
    
  elseif kind == "difficulty_ge" then
    local level = condition.params and condition.params.level or 1
    return getGameDifficulty() >= level
    
  elseif kind == "item_condition_ge" then
    if not item then return true end
    local percent = condition.params and condition.params.percent or 0
    local ratio = item:getCondition() / item:getMaxCondition()
    return (ratio * 100) >= percent
    
  elseif kind == "player_trait" then
    if not player then return false end
    local traitName = condition.params and condition.params.traitName
    if not traitName then return false end
    return player:HasTrait(traitName)
    
  elseif kind == "server_only" then
    return false  -- Client cannot evaluate; should not reach here
  end
  
  return true
end

-- Evaluate an effect descriptor and return resulting price
-- Returns: number (the modified price)
local function applyEffect(price, effect, item)
  if not effect then return price end
  
  local kind = effect.kind
  
  if kind == "multiply" then
    local value = effect.value or 1
    return price * value
    
  elseif kind == "add" then
    local value = effect.value or 0
    return price + value
    
  elseif kind == "set" then
    local value = effect.value or price
    return value
  end
  
  return price
end

-- Calculate buy price for item using data-driven rules
-- Returns: number (price) or nil if unable to calculate
function Calculator.calcBuyPrice(itemId, player, modifiers)
  modifiers = modifiers or {}
  
  if not SHOPSB42.Shop.Items or not SHOPSB42.Shop.Items[itemId] then
    return nil
  end
  
  -- Return 0 if server-only evaluation required
  if modifiers.requiresServer then
    return nil
  end
  
  local base = SHOPSB42.Shop.Items[itemId].price
  
  -- Check overrides first
  if modifiers.buyOverrides and modifiers.buyOverrides[itemId] then
    return modifiers.buyOverrides[itemId]
  end
  
  local price = base
  
  -- Sort by priority and apply modifiers
  local sortedMods = {}
  if modifiers.buyModifiers then
    for _, mod in ipairs(modifiers.buyModifiers) do
      if mod.type == "buy" or not mod.type then
        table.insert(sortedMods, mod)
      end
    end
  end
  
  -- Sort by priority (lower first)
  table.sort(sortedMods, function(a, b)
    return (a.priority or 100) < (b.priority or 100)
  end)
  
  -- Apply each modifier if condition is met
  for _, mod in ipairs(sortedMods) do
    if evaluateCondition(mod.condition, player, nil, {}) then
      price = applyEffect(price, mod.effect)
    end
  end
  
  return math.floor(math.max(0, price))
end

-- Calculate sell price for item using data-driven rules
-- Returns: number (price) or nil if unable to calculate
function Calculator.calcSellPrice(item, player, modifiers)
  modifiers = modifiers or {}
  
  if not item then return nil end
  
  local itemId = item:getFullType()
  
  -- Return 0 if server-only evaluation required
  if modifiers.requiresServer then
    return nil
  end
  
  if not SHOPSB42.Shop.PlayerSell or not SHOPSB42.Shop.PlayerSell[itemId] then
    return nil
  end
  
  local base = SHOPSB42.Shop.PlayerSell[itemId].price
  
  -- Check overrides first
  if modifiers.sellOverrides and modifiers.sellOverrides[itemId] then
    return modifiers.sellOverrides[itemId]
  end
  
  local price = base
  
  -- Sort by priority and apply modifiers
  local sortedMods = {}
  if modifiers.sellModifiers then
    for _, mod in ipairs(modifiers.sellModifiers) do
      if mod.type == "sell" or not mod.type then
        table.insert(sortedMods, mod)
      end
    end
  end
  
  -- Sort by priority (lower first)
  table.sort(sortedMods, function(a, b)
    return (a.priority or 100) < (b.priority or 100)
  end)
  
  -- Apply each modifier if condition is met
  for _, mod in ipairs(sortedMods) do
    if evaluateCondition(mod.condition, player, item, {}) then
      price = applyEffect(price, mod.effect, item)
    end
  end
  
  return math.floor(math.max(0, price))
end

return Calculator
```

### 3.2 Update UI Components (Client)

**Update `ShopUI.lua`, `PlayerShopUI.lua`, transaction handlers**

Replace server price requests with shared calculator for **UI preview only**:

```lua
-- OLD (remove):
-- sendClientCommand("Shops", "GetBuyPrice", {itemId, player})

-- NEW (use for UI preview):
local Calculator = require("nshopsb42/pricing/ShopPriceCalculatorShared")
local Shop = SHOPSB42.Shop
local player = getPlayer()
local price = Calculator.calcBuyPrice(itemId, player, Shop.PriceModifiers or {})

-- Fallback to base price if client calc returns nil (server-only)
if not price then
  price = (Shop.Items[itemId] and Shop.Items[itemId].price) or 0
end

-- Display in UI
self.priceLabel:setText("Price: $" .. price)
```

### 3.3 Add Server-Side Transaction Validation

**Location:** `ShopTransactionHandler.lua` or equivalent server transaction code

The server must **recalculate and validate** the price when transaction completes:

```lua
-- In transaction completion (server-side)
local function onTransactionComplete(player, itemId, quantity, clientPrice)
  local Shop = SHOPSB42.Shop
  local Calculator = require("nshopsb42/pricing/ShopPriceCalculatorShared")
  
  -- Recalculate server price using same rules
  local serverPrice = Calculator.calcBuyPrice(itemId, player, Shop.PriceModifiers or {})
  
  -- If server-only calculation, serverPrice will be nil
  -- In that case, fall back to original price logic (hooks, etc.)
  if not serverPrice then
    -- TODO: Implement fallback server-only price calculation
    serverPrice = (Shop.Items[itemId] and Shop.Items[itemId].price) or 0
  end
  
  -- Validate: allow small tolerance for rounding
  local diff = math.abs(serverPrice - clientPrice)
  if diff > 1 then
    -- Price mismatch - reject transaction
    SharedLogger.log("Shops", "[SECURITY] Price mismatch for " .. player:getUsername()
      .. ": client=" .. clientPrice .. " server=" .. serverPrice)
    return false  -- Reject transaction
  end
  
  -- Prices match, proceed with transaction
  return true
end
```

---

## Phase 4: Integration

### 4.1 Single-Player Compatibility

**In `Init.lua` (Server-side or Server code in SP context):**

```lua
-- SP: Trigger finalization and build modifiers on server context
local function onGameStartServer()
  if isServer() then
    local ShopFinalizeHandler = require("nshopsb42/transactions/ShopFinalizeHandlerServer")
    ShopFinalizeHandler.finalizeNow()
    
    -- Modifiers are cached by finalizeNow()
    if SHOPSB42.Shop.PriceModifiers then
      SharedLogger.log("Shops", "[Init] Price modifiers built and cached")
    end
  end
end

Events.OnGameStart.Add(onGameStartServer)
```

**In `Init.lua` (Client-side or Client code in SP context):**

```lua
-- SP: Client side also needs to build modifiers for calculation
-- In SP, client and server both exist, so sync still happens
local function onGameStartClient()
  if isClient() or SHOPSB42.Utilities.IsSinglePlayer() then
    local ShopSyncClient = require("nshopsb42/sync/ShopSyncClient")
    ShopSyncClient.Initialize()
    
    -- Request shop data (in SP, this will trigger server to send sync)
    sendClientCommand("Shops", "RequestShopData", {})
    SharedLogger.log("Shops", "[Init] Client requested shop data")
  end
end

Events.OnGameStart.Add(onGameStartClient)
```

### 4.2 File Structure

**New files:**
- `Shops/42.13.1/media/lua/shared/nshopsb42/pricing/ShopPriceModifierBuilder.lua`
- `Shops/42.13.1/media/lua/shared/nshopsb42/pricing/ShopPriceCalculatorShared.lua`
- `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua`

**Modified files:**
- `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua` - add modifier sync
- `Shops/42.13.1/media/lua/server/nshopsb42/ShopInitServer.lua` - add RequestShopData handler
- `Shops/42.13.1/media/lua/client/nshopsb42/Init.lua` - require ShopSyncClient, request data on game start
- `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopTransactionHandler.lua` - add server price validation
- All UI and transaction files that display prices - replace with shared calculator for preview only

---

## Phase 5: Testing Strategy

### 5.1 Unit Tests

- [ ] Price modifier builder classifies hooks correctly (client-safe vs server-only)
- [ ] Shared calculator evaluates all supported conditions
- [ ] Shared calculator applies all supported effects
- [ ] Overrides take precedence over modifiers
- [ ] Conditions short-circuit properly (return nil if not evaluable)
- [ ] Modifiers sort and apply in priority order
- [ ] Rounding behavior is consistent

### 5.2 Integration Tests (MP)

- [ ] Server finalizes exactly once (no double-finalization)
- [ ] Server builds and caches modifiers during finalization
- [ ] Client requests shop data on game start
- [ ] Server sends shop data and modifiers to requesting player
- [ ] Client stores data correctly
- [ ] Client can calculate preview prices
- [ ] Server recalculates on transaction completion
- [ ] Server validates client price vs server price (with tolerance)
- [ ] Transaction rejected if price mismatch > tolerance
- [ ] Logs show classification of hooks (client-safe vs server-only)

### 5.3 Integration Tests (SP)

- [ ] Server finalizes on game start
- [ ] Client receives synced modifiers from server
- [ ] Client can calculate prices using shared calculator
- [ ] No transaction validation needed (SP is trusted)
- [ ] No double-finalization occurs

### 5.4 Live Tests

- [ ] Buy prices display instantly in UI (no network lag)
- [ ] Sell prices display instantly (no network lag)
- [ ] Prices are accurate when modifier rules are applied
- [ ] Server rejects transactions with tampered prices
- [ ] Logs indicate when server-only fallback is used
- [ ] Multiple players can trade simultaneously without price desync

---

## Data Structure Reference

### SyncShopData Command

```lua
{
  Items = {
    ["Canned_Soup"] = {
      tab = Shop.Tab.Food,
      price = 15,
      items = {{item = "Base.CannedSoup", count = 1}}
    },
    -- ...
  },
  PlayerBuy = {
    ["Canned_Soup"] = {enabled = true},
    ["Expensive_Item"] = {enabled = false}
  },
  PlayerSell = {
    ["Canned_Soup"] = {enabled = true},
    ["Base.Newspaper"] = {enabled = false}
  },
  BuyIsWhitelist = true,
  SellIsWhitelist = false
}
```

### SyncPriceModifiers Command

**Data-driven, no executable functions:**

```lua
{
  buyModifiers = {
    {
      id = "hard_mode_discount",
      type = "buy",
      priority = 10,
      condition = {
        kind = "difficulty_ge",
        params = { level = 3 }
      },
      effect = {
        kind = "multiply",
        value = 0.8
      },
      description = "Hard difficulty discount (20% off)"
    },
    {
      id = "expert_trait_bonus",
      type = "buy",
      priority = 20,
      condition = {
        kind = "player_trait",
        params = { traitName = "Expert" }
      },
      effect = {
        kind = "multiply",
        value = 0.9
      },
      description = "Experts get additional discount"
    },
    -- ...
  },
  sellModifiers = {
    {
      id = "item_condition_payout",
      type = "sell",
      priority = 50,
      condition = {
        kind = "always"
      },
      effect = {
        kind = "multiply",
        valueKind = "item_condition_ratio"
      },
      description = "Sell price multiplied by item condition %"
    },
    -- ...
  },
  buyOverrides = {
    ["Special_Rare_Item"] = 9999
  },
  sellOverrides = {
    ["Worthless_Junk"] = 0
  },
  requiresServer = false  -- Set to true if any hooks cannot be converted
}
```

---

## Implementation Checklist

### Core Infrastructure
- [ ] Define Modifier schema and rule types in documentation
- [ ] Create `ShopPriceModifierBuilder.lua` with hook classification logic
- [ ] Create `ShopPriceCalculatorShared.lua` with data-driven rule evaluation
- [ ] Test builder and calculator in isolation

### Server Integration
- [ ] Update `ShopFinalizeHandlerServer.lua`
  - [ ] Add modifier caching after finalization
  - [ ] Guard against double-finalization
  - [ ] Add `sendShopDataToPlayer()` method
- [ ] Update `ShopInitServer.lua` with RequestShopData handler
- [ ] Create/update `ShopTransactionHandler.lua`
  - [ ] Add server-side price recalculation on transaction completion
  - [ ] Add price validation with tolerance check
  - [ ] Add transaction rejection for price mismatches

### Client Integration
- [ ] Create `ShopSyncClient.lua` to receive and store sync data
- [ ] Update client `Init.lua`
  - [ ] Require `ShopSyncClient`
  - [ ] Initialize on game start
  - [ ] Request shop data on game start
- [ ] Update all UI components that display prices
  - [ ] Replace server requests with shared calculator calls
  - [ ] Use calculator for preview only
  - [ ] Add fallback to base prices if calculation returns nil

### Testing
- [ ] Unit test: Builder classifies hooks correctly
- [ ] Unit test: Calculator evaluates all condition types
- [ ] Unit test: Calculator applies all effect types
- [ ] Unit test: Rounding is consistent
- [ ] Integration test (MP): Finalization, sync, calculation, validation
- [ ] Integration test (SP): Finalization and sync without double-run
- [ ] Live test: Multiple players trade without price desync
- [ ] Live test: Server rejects tampered prices
- [ ] Live test: No UI lag from price calculation

### Documentation & Polish
- [ ] Document Modifier schema as public API
- [ ] Document supported conditions and effects
- [ ] Document how to handle server-only hooks
- [ ] Document price validation tolerance
- [ ] Add examples for mod authors
- [ ] Update AGENTS.md with new architecture

---

## Security & Authorization Model

### Client Trust

- **UI/Preview**: ✅ Safe - calculation is data-driven
- **Transaction Price**: ❌ **Never trust** - always validate on server
- **Exploit Risk**: Client could submit tampered prices

### Server Validation

- Recalculate price using identical modifier rules
- Compare with client-submitted price (tolerance: ±1)
- Reject transaction if mismatch exceeds tolerance
- Log all mismatches for audit trail

### Fallback for Non-Convertible Hooks

- If a hook cannot be converted to a rule: `requiresServer = true`
- Client cannot calculate → falls back to base price in UI
- Server recalculates using hook logic
- Server price is authoritative

---

## Extensibility for Mods

**Mod authors can register hooks as before:**

```lua
SHOPSB42.ShopPriceEvents.OnShopModifyBuyPrice:Add(function(item, player)
  return 0.9  -- 10% discount
end)
```

**The builder will:**

1. Detect the hook
2. Classify it: can it be converted to a rule, or is it server-only?
3. If convertible: convert to a rule descriptor (e.g., `{ kind = "multiply", value = 0.9 }`)
4. If not: set `requiresServer = true`

**The shared calculator handles both:**

- Supports all standard rule types automatically
- Returns `nil` if `requiresServer = true` (falls back to base or server calc)

---

## Notes on Implementation

- **No executable functions in sync packets** - only data descriptors
- **Modifier builder must classify every hook** - this is the core complexity
- **Shared calculator is the single source of truth** for rule evaluation
- **Server always recalculates** - client calculation is preview only
- **Guarding finalization** - prevent double-runs in SP/MP transitions
- **Caching on server** - reuse modifiers across all player requests
- **Tolerance in validation** - account for floating-point rounding differences
