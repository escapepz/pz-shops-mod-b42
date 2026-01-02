## Trace: `ShopFinalizeHandler.onPriceHooksChanged()`

```mermaid
graph TD
    onPHC["🔵 onPriceHooksChanged()"] -->|log call| LOG1["SharedLogger.log onPriceHooksChanged called"]

    onPHC -->|check finalization| FINALIZED{"Shop._finalized?"}
    FINALIZED -->|false| ABORT["Return early abort"]
    FINALIZED -->|true| CONTINUE["Continue"]

    CONTINUE -->|check buy prices| SHOULD_BUY{"shouldInvalidateBuyPrices()"}
    SHOULD_BUY -->|has buy hooks| BROAD_BUY["broadcastBuyPrices()"]
    SHOULD_BUY -->|no hooks| SKIP_BUY["Skip"]

    CONTINUE -->|check sell rules| SHOULD_SELL{"shouldInvalidateSellRules()"}
    SHOULD_SELL -->|has sell hooks| BROAD_SELL["broadcastSellRules()"]
    SHOULD_SELL -->|no hooks| SKIP_SELL["Skip"]

    BROAD_BUY -->|rev++| INCREV1["Shop.BuyPriceRevision++"]
    INCREV1 -->|build modifiers| BUILD1["Builder.buildPriceModifiers()"]
    BUILD1 -->|cache| CACHE1["Shop.PriceModifiers = modifiers"]
    CACHE1 -->|calc prices| CALC["buildCalculatedPrices()"]
    CALC -->|find deltas| DELTA["detectPriceChanges()"]
    DELTA -->|update cache| STORE["_previousBuyPrices = newPrices"]
    STORE -->|broadcast to all players| SEND1["SendServerCommandToAll SyncBuyPrices"]
    SEND1 -->|log complete| LOG2["SharedLogger.log BUY prices broadcast"]

    BROAD_SELL -->|rev++| INCREV2["Shop.SellRuleRevision++"]
    INCREV2 -->|build modifiers| BUILD2["Builder.buildPriceModifiers()"]
    BUILD2 -->|extract sell data| EXTRACT["sellModifiers + sellOverrides"]
    EXTRACT -->|compare delta| EQUAL{"ruleSetsEqual?"}
    EQUAL -->|equal| SKIP_SELL_BC["Skip broadcast"]
    EQUAL -->|different| UPDATE["deepCopy & update cache"]
    UPDATE -->|broadcast to all players| SEND2["SendServerCommandToAll SyncSellRules"]
    SEND2 -->|log complete| LOG3["SharedLogger.log SELL rules broadcast"]

    LOG2 --> END["📍 onPriceHooksChanged() END"]
    LOG3 --> END
    SKIP_BUY --> END
    SKIP_SELL --> END
    SKIP_SELL_BC --> END
    ABORT --> END

    style onPHC fill:#0a0e27,stroke:#00ff00,color:#ffffff
    style ABORT fill:#330000,stroke:#ff3300,color:#ffffff
    style BROAD_BUY fill:#003300,stroke:#00ff00,color:#ffffff
    style BROAD_SELL fill:#003300,stroke:#00ff00,color:#ffffff
    style SEND1 fill:#000033,stroke:#0066ff,color:#ffffff
    style SEND2 fill:#000033,stroke:#0066ff,color:#ffffff
    style END fill:#330033,stroke:#ff00ff,color:#ffffff
```

**Purpose**: Handles runtime price hook changes by independently broadcasting buy price updates and sell rule updates to all players (after shop finalization is complete).

**Flow**:

1. **Validation Check** (L182-185)

   - Verifies `Shop._finalized` is true; aborts if shop not finalized yet

2. **Buy Prices Path** (L188-190)

   - `shouldInvalidateBuyPrices()` checks if any buy hooks exist
   - If yes, calls `broadcastBuyPrices()`:
     - Increments `Shop.BuyPriceRevision`
     - Builds price modifiers via `Builder.buildPriceModifiers()`
     - Calculates prices for enabled items
     - Detects changed prices (delta detection)
     - Broadcasts only changed prices via `SendServerCommandToAll("SyncBuyPrices")`

3. **Sell Rules Path** (L191-193)
   - `shouldInvalidateSellRules()` checks if any sell hooks exist
   - If yes, calls `broadcastSellRules()`:
     - Increments `Shop.SellRuleRevision`
     - Extracts sell modifiers & overrides from price modifiers
     - Compares with previous rules (delta detection)
     - Only broadcasts if rules changed
     - Broadcasts via `SendServerCommandToAll("SyncSellRules")`

**Key Features**:

- **Independent paths**: Buy and sell updates don't block each other
- **Delta detection**: Only broadcasts what actually changed
- **Guarded execution**: Only runs after shop is finalized
- **Server-wide sync**: All online players receive updates
