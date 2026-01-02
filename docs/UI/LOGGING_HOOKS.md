# Timed Action Execution Logging Hooks

## Overview

Comprehensive logging has been added to all timed actions to verify proper server/client execution split in B42 MP.

## Actions Instrumented

### 1. ISAddPlayerShopAction
**Purpose:** Place player shops (with inventory item consumption)

**Logs:**
- `[perform]` - Entry on CLIENT or SP, logs timer remaining
- `[complete] ENTRY` - Entry on CLIENT or SERVER, logs sprite
- `[complete] [CLIENT] MP - exiting early` - Client in MP exits early
- `[complete] [SERVER] SUCCESS` - Server successfully places shop

**Expected Flow (MP):**
```
Client: [perform] [CLIENT]
Client: [complete] [ENTRY] [CLIENT] - exiting early
Server: [complete] [ENTRY] [SERVER] - sprite=...
Server: [complete] [SERVER] SUCCESS - shop placed, inventory consumed
```

---

### 2. ISAddShopAction
**Purpose:** Place admin shops (no inventory consumption)

**Logs:**
- `[perform]` - Entry on CLIENT or SP
- `[complete] ENTRY` - Entry on CLIENT or SERVER
- `[complete] [CLIENT] MP - exiting early` - Client in MP exits early
- `[complete] [SERVER] SUCCESS` - Server successfully places admin shop

**Expected Flow (MP):**
```
Client: [perform] [CLIENT]
Client: [complete] [ENTRY] [CLIENT] - exiting early
Server: [complete] [ENTRY] [SERVER] - sprite=...
Server: [complete] [SERVER] SUCCESS - admin shop placed
```

---

### 3. ShopBuyAction
**Purpose:** Buy items from a shop (transaction processing)

**Logs:**
- `[perform]` - Entry on CLIENT or SP, logs timer
- `[complete] ENTRY` - Entry on CLIENT or SERVER, logs txnId
- `[complete] [CLIENT] MP - exiting early` - Client in MP exits early
- `[complete] [SERVER] SUCCESS` - Server successfully processes purchase

**Expected Flow (MP):**
```
Client: [perform] [CLIENT]
Client: [complete] [ENTRY] [CLIENT] - exiting early
Server: [complete] [ENTRY] [SERVER] - txnId=...
Server: [complete] [SERVER] SUCCESS - purchase transaction processed
```

---

### 4. PlayerShopBuyAction
**Purpose:** Buy items from a player-owned shop

**Logs:**
- `[perform]` - Entry on CLIENT or SP
- `[complete] ENTRY` - Entry on CLIENT or SERVER
- `[complete] [CLIENT] MP - exiting early` - Client in MP exits early
- `[complete] [SERVER] SUCCESS` - Server successfully processes transaction

**Expected Flow (MP):**
```
Client: [perform] [CLIENT]
Client: [complete] [ENTRY] [CLIENT] - exiting early
Server: [complete] [ENTRY] [SERVER]
Server: [complete] [SERVER] SUCCESS - transaction complete, items transferred
```

---

### 5. ShopSellAction
**Purpose:** Sell items to a shop (transaction processing)

**Logs:**
- `[perform]` - Entry on CLIENT or SP, logs timer
- `[complete] ENTRY` - Entry on CLIENT or SERVER, logs txnId
- `[complete] [CLIENT] MP - exiting early` - Client in MP exits early
- `[complete] [SERVER] SUCCESS` - Server successfully processes sale

**Expected Flow (MP):**
```
Client: [perform] [CLIENT]
Client: [complete] [ENTRY] [CLIENT] - exiting early
Server: [complete] [ENTRY] [SERVER] - txnId=...
Server: [complete] [SERVER] SUCCESS - sell transaction processed
```

---

### 6. SendTransferAction
**Purpose:** Transfer currency between players

**Logs:**
- `[perform]` - Entry on CLIENT or SP, logs timer
- `[complete] ENTRY` - Entry on CLIENT or SERVER, logs recipient
- `[complete] SUCCESS` - Transfer command sent

**Expected Flow (MP):**
```
Client: [perform] [CLIENT]
Client: [complete] [ENTRY] [CLIENT] - recipient=...
Client: [complete] SUCCESS - transfer command sent
```

---

## How to Interpret Logs

### Context Codes
- `[CLIENT]` - Running on client in MP
- `[SERVER]` - Running on server in MP
- `[SP]` - Running in single-player mode

### Key Indicators

**Bugged Action Signs:**
- ✗ `[complete]` never appears for `[SERVER]` - action not reaching server
- ✗ `[SERVER]` performs mutation without complete() being called
- ✗ Complete returns `false` unexpectedly
- ✗ Complete logs appear but with `nil` values

**Healthy Action Signs:**
- ✓ `[perform]` appears on client
- ✓ `[complete] [CLIENT] MP - exiting early` appears after perform
- ✓ `[complete] [SERVER]` appears later on server logs
- ✓ `[complete] [SERVER] SUCCESS` appears at the end
- ✓ All parameters logged (sprite, txnId, recipient) are non-nil

---

## Code Changes Summary

### Fixed Constructor Bug
Two timed actions had incorrect constructor signatures:
- `ISAddPlayerShopAction:new()` - changed `ISBaseTimedAction.new(self, ...)` to `ISBaseTimedAction.new(ISAddPlayerShopAction, ...)`
- `ISAddShopAction:new()` - changed `ISBaseTimedAction.new(self, ...)` to `ISBaseTimedAction.new(ISAddShopAction, ...)`

This ensures proper B42 network serialization and deserialization.

### Fixed Require Path
- `ISAddShopAction.lua` - updated `require("nshopsb42/HelperFunction/Utilities")` to `require("nshopsb42/utils/Utilities")`

---

## Testing Protocol

To verify execution flow:

1. **Single-Player Test:**
   - Expect all `[SP]` context logs
   - Both `[perform]` and `[complete]` should appear in same console
   - Should see SUCCESS logs

2. **Multiplayer Test (Client Perspective):**
   - Watch client console
   - Expect `[CLIENT]` context for perform and complete entry
   - Should see "exiting early" message for transaction-based actions
   - Server logs are separate

3. **Multiplayer Test (Server Perspective):**
   - Watch server console
   - Should see `[SERVER]` context for complete entry and execution
   - Should see SUCCESS messages
   - If never see `[SERVER]` complete entry = action not reaching server (BUG)

---

## Log Output Example (MP - Player Shop Buy)

**Client Console:**
```
[PlayerShopBuyAction:perform] [CLIENT] time remaining=50
[PlayerShopBuyAction:complete] [CLIENT] ENTRY
[PlayerShopBuyAction:complete] [CLIENT] MP - exiting early
```

**Server Console:**
```
[PlayerShopBuyAction:complete] [SERVER] ENTRY
[PlayerShopBuyAction:complete] [SERVER] SUCCESS - transaction complete, items transferred
```

---

## Timestamp Correlation

Logs use `writeLog()` which includes timestamps. When diagnosing:
- Client action starts first (lower timestamp)
- Server action completes later (higher timestamp)
- Gap between client and server is network serialization + server processing time
