# Pickup & Rotation Fix - January 2, 2026

## Problems Fixed

### 1. Cannot Pick Up Player Shop (Silent Failure)
**Root Cause**: Server-side `PlayerShopPickupShop` handler had no logging, so failures were invisible.

**Fix in `ShopCommandDispatcherServer.lua`**:
- Added comprehensive logging at each rejection point:
  - Invalid arguments
  - Square not found
  - Shop object not found (search in getTileObjects)
  - Shop has items
  - Shop has income
  - Successful removal and pickup

**Server Log Expectations**:
```
[ShopCommandDispatcher:PlayerShopPickupShop] SUCCESS - item added to inventory
```

### 2. Rotation Not Changing Angle During Placement
**Root Cause**: Rotation toggle handler lacked error checking and logging; logic was correct but silent.

**Fix in `ShopSpriteCursorUI.lua`**:
- Added validation that sprites table has exactly 2 entries
- Added logging when rotation key is pressed showing new sprite and north value
- More robust sprite index handling

**Client Log Expectations**:
```
[ShopSpriteCursorUI:toggleSprites] Rotated to sprite=playershop_1 north=true
```

## How to Test

### Pickup Test
1. Place a player shop (empty, no income)
2. Right-click shop → "Pickup Player Shop"
3. Check **Logs/Server/2026-01-02_*_Shops.txt** for:
   ```
   [ShopCommandDispatcher:PlayerShopPickupShop] SUCCESS - item added to inventory
   ```
   OR one of the rejection reasons if it fails

### Rotation Test
1. Take a player shop item from inventory
2. Right-click ground → "Add Player Shop"
3. **Before clicking to place**, press **R** multiple times
4. Check **Logs/Client/2026-01-02_*_Shops.txt** for:
   ```
   [ShopSpriteCursorUI:toggleSprites] Rotated to sprite=playershop_X north=true/false
   ```
5. Visual feedback should show shop rotating on screen
6. Click to place and verify orientation matches last rotation

## Technical Details

### Pickup Logic
- Searches `square:getTileObjects()` (where AddTileObject places shops)
- Validates shop is empty (no items, no income)
- Removes from world and adds to player inventory atomically

### Rotation Logic
- Each sign type has 2 sprite variants: even index (west) and odd index (north)
- Press R key to toggle between them
- north=false for index 1, north=true for index 2
- Passed to ISAddPlayerShopAction:new() and used in IsoThumpable.new()

## Logs to Monitor

**Server**: `Logs/Server/*_Shops.txt`
- Watch for pickup success/failure reasons

**Client**: `Logs/Client/*_Shops.txt`
- Watch for rotation toggle messages
- Watch for action queueing messages
