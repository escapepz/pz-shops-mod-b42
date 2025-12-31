**Suggested workflow for client-server authority + performance:**

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. CLIENT AUTHORITY (UI Layer - Optimistic)                     │
│    • Client calculates/shows preview immediately                 │
│    • Fast response (no server round-trip)                        │
│    • Used for: price preview, cart total display                │
│                                                                   │
│    For NPC shops: call resolvePlayerSellPrice() on addToCart    │
│    For Player shops: use static price (already in item)          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. TRANSACTION REQUEST (Send to Server)                          │
│    • Bundle: txnId + items + client-calculated prices           │
│    • Minimal data transfer                                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. SERVER AUTHORITY (Validation Layer)                          │
│    • Re-calculate price from scratch (authoritatively)           │
│    • Check anti-cheat: TransactionRegistry (txnId)              │
│    • Verify inventory items still exist                          │
│    • Accept or reject based on server state                      │
│                                                                   │
│    For NPC shops: recalculate resolvePlayerSellPrice()          │
│    For Player shops: fetch price from shop ModData               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. PERFORMANCE OPTIMIZATIONS                                    │
│    • Cache: Don't recalculate same item twice per transaction   │
│    • Lazy-load: Only compute prices for items in cart           │
│    • Async: Server calculations don't block client UI           │
│    • Delta: Only transmit changes (ModData.transmit)            │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle:** Client = **Optimistic UI**, Server = **Authoritative Truth**

- Client shows what _should_ happen (fast, responsive)
- Server validates it _can_ happen (cheating prevention)
- If mismatch: server result wins, client UI updates from server response
