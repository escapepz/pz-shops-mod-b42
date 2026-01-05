# Visual Display Conditions - Buy vs Sell Items

## LISTING VIEW (Left Side - Shop Items)

### BUY TAB (All, Food, Weapons, etc.)

#### Condition 1: Price Increased (Bad for Player)
- **When**: `finalPrice > basePrice`
- **Colors**: Neutral + Gray
- **Layout**: 
  ```
  ItemName (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in NEUTRAL] [basePrice in GRAY below]
  (at X=280)
  ```
- **Code**: Lines 178-199 (ShopTabUI.lua)
- **Semantics**: Player pays MORE - bad deal

#### Condition 2: Price Decreased (Good for Player)  
- **When**: `finalPrice < basePrice`
- **Colors**: Green + Gray + Green percentage
- **Layout**:
  ```
  ItemName (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in GREEN] [basePrice in GRAY below]
  [-X% in GREEN at +48px]
  (at X=280)
  ```
- **Code**: Lines 225-260 (ShopTabUI.lua)
- **Semantics**: Player pays LESS - good deal (+discount shown)

#### Condition 3: No Price Change
- **When**: `finalPrice == basePrice`
- **Colors**: Neutral only
- **Layout**:
  ```
  ItemName (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in NEUTRAL]
  (at X=280)
  ```
- **Code**: Lines 261-267 (ShopTabUI.lua)
- **Semantics**: Normal price - no change

---

### SELL TAB

#### Condition 1: Price Increased (Good for Player - Higher Sell Value)
- **When**: `finalPrice > basePrice`
- **Colors**: Green + Gray + Green percentage
- **Layout**:
  ```
  ItemName (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in GREEN] [basePrice in GRAY below]
  [+X% in GREEN at +48px]
  (at X=280)
  ```
- **Code**: Lines 142-176 (ShopTabUI.lua)
- **Semantics**: Player gets MORE coins - good deal (+markup shown)

#### Condition 2: Price Decreased (Bad for Player - Lower Sell Value)
- **When**: `finalPrice < basePrice`
- **Colors**: Neutral + Gray
- **Layout**:
  ```
  ItemName (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in NEUTRAL] [basePrice in GRAY below]
  (at X=280)
  ```
- **Code**: Lines 202-224 (ShopTabUI.lua)
- **Semantics**: Player gets FEWER coins - bad deal

#### Condition 3: No Price Change
- **When**: `finalPrice == basePrice`
- **Colors**: Neutral only
- **Layout**:
  ```
  ItemName (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in NEUTRAL]
  (at X=280)
  ```
- **Code**: Lines 261-267 (ShopTabUI.lua)
- **Semantics**: Normal price - no change

---

## CART VIEW (Right Side - Shopping Cart)

### BUY TAB

#### Condition 1: Price Decreased (Good for Player)
- **When**: `finalPrice < basePrice`
- **Colors**: Green + Gray + Green percentage
- **Layout**:
  ```
  ItemName (with quantity) (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in GREEN] [basePrice in GRAY below]
  [-X% in GREEN at +48px]
  (at X=280)
  ```
- **Code**: Lines 368-419 (ShopUI.lua)
- **Semantics**: Player pays LESS - good deal (matches listing view)

#### Condition 2: Price Increased (Bad for Player)
- **When**: `finalPrice > basePrice`
- **Colors**: Neutral + Gray
- **Layout**:
  ```
  ItemName (with quantity) (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in NEUTRAL] [basePrice in GRAY below]
  (at X=280)
  ```
- **Code**: Lines 355-365 (ShopUI.lua)
- **Semantics**: Player pays MORE - bad deal (matches listing view)

#### Condition 3: No Price Change
- **When**: `finalPrice == basePrice`
- **Colors**: Neutral only
- **Layout**:
  ```
  ItemName (with quantity) (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in NEUTRAL]
  (at X=280)
  ```
- **Code**: Lines 420-430 (ShopUI.lua)
- **Semantics**: Normal price - no change (matches listing view)

### SELL TAB

#### Condition 1: Price Increased (Good for Player - Higher Sell Value)
- **When**: `finalPrice > basePrice`
- **Colors**: Green + Gray + Green percentage
- **Layout**:
  ```
  ItemName (with quantity) (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in GREEN] [basePrice in GRAY below]
  [+X% in GREEN at +48px]
  (at X=280)
  ```
- **Code**: Lines 368-407 (ShopUI.lua)
- **Semantics**: Player gets MORE coins - good deal (matches listing view)

#### Condition 2: Price Decreased (Bad for Player - Lower Sell Value)
- **When**: `finalPrice < basePrice`
- **Colors**: Neutral + Gray
- **Layout**:
  ```
  ItemName (with quantity) (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in NEUTRAL] [basePrice in GRAY below]
  (at X=280)
  ```
- **Code**: Lines 408-419 (ShopUI.lua)
- **Semantics**: Player gets FEWER coins - bad deal (matches listing view)

#### Condition 3: No Price Change
- **When**: `finalPrice == basePrice`
- **Colors**: Neutral only
- **Layout**:
  ```
  ItemName (with quantity) (at X=40)
  [Coin Icon] (at X=260)
  [finalPrice in NEUTRAL]
  (at X=280)
  ```
- **Code**: Lines 420-430 (ShopUI.lua)
- **Semantics**: Normal price - no change (matches listing view)

---

## COLOR REFERENCE

| Color | RGB Value | Usage |
|-------|-----------|-------|
| NEUTRAL | (0.85, 0.85, 0.85) | Buy: price increase, Sell: price decrease, Cart: normal price |
| GREEN (Good) | Game's good color (default ~0,1,0) | Buy: discount, Sell: markup, Both: savings |
| GRAY (Base) | (0.3, 0.3, 0.3) | Previous/base price reference |
| WHITE (Normal) | (1, 1, 1) | Cart normal price |
| DIMMED | (0.7, 0.7, 0.7) | Cart approximate price |

---

## KEY VISUAL DIFFERENCES

### Listing (Tab) vs Cart - Now Unified
**As of the latest update, cart items now use identical visual logic to listing view.**

The cart display mirrors the listing view exactly:
- Same color semantics (Green for good deals, Neutral for bad deals)
- Same percentage display (+X% for markup in Sell tab, -X% for discount in Buy tab)
- Same basePrice display (gray below finalPrice when different)
- Color inversion is respected (Buy tab logic vs Sell tab logic)

This ensures players see consistent pricing feedback between browsing items and reviewing their cart before checkout.

### Buy Tab Logic (Listing = Cart)
| Scenario | Color | Display |
|----------|-------|---------|
| Price < basePrice (Discount) | GREEN finalPrice | GREEN finalPrice + GRAY basePrice below + -X% |
| Price > basePrice (Increase) | NEUTRAL finalPrice | NEUTRAL finalPrice + GRAY basePrice below |
| Price == basePrice | NEUTRAL finalPrice | NEUTRAL finalPrice |

### Sell Tab Logic (Listing = Cart)
| Scenario | Color | Display |
|----------|-------|---------|
| Price > basePrice (Markup) | GREEN finalPrice | GREEN finalPrice + GRAY basePrice below + +X% |
| Price < basePrice (Decrease) | NEUTRAL finalPrice | NEUTRAL finalPrice + GRAY basePrice below |
| Price == basePrice | NEUTRAL finalPrice | NEUTRAL finalPrice |

---

## DEFENSIVE PROTECTIONS

### Pre-Render Initialization
- **Location**: ShopTabUI.doDrawShopItem lines 44-50
- **Purpose**: Ensure every item has basePrice before rendering
- **Code**:
  ```lua
  if item and item.item and item.item.price and not item.item.basePrice then
      item.item.basePrice = item.item.price
  end
  ```

- **Location**: ShopUI.doDrawCartItem lines 310-314
- **Purpose**: Same - prevent nil errors in cart rendering

### Nil/Zero Checks
- **Location**: ShopTabUI.doDrawShopItem lines 118-120
- **Purpose**: Fallback if basePrice is nil or zero
- **Code**:
  ```lua
  if not basePrice or basePrice == 0 then
      basePrice = finalPrice
  end
  ```

- **Location**: ShopUI.doDrawCartItem lines 351
- **Purpose**: Fallback for cart items
- **Code**:
  ```lua
  local basePrice = item.item.basePrice or item.item.price
  ```

---

## REFRESH BEHAVIOR

When prices change (live update):
1. ✅ Cart is cleared via `clearCartOnPriceChange()`
2. ✅ Cache is invalidated
3. ✅ When items are re-added from fresh cache, they have correct basePrice
4. ✅ Colors display correctly because basePrice/price relationship is fresh
