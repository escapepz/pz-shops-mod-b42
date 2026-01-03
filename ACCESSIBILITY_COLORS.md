# Accessibility Colors Update

## Summary
Updated ShopTabUI to use game's built-in accessibility colors instead of hardcoded RGB values.

## Changes Made

### File: `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopTabUI.lua`

**Lines 19-24** - Color initialization:
```lua
-- Get game's accessibility colors (respects user settings)
local goodColor = getCore():getGoodHighlitedColor()
local neutralColor = getCore():getNeutralHighlitedColor()
-- Use gray for base price reference
local grayColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }
```

**Lines 122-160** - Price rendering:
- Replaced hardcoded `0.2, 1, 0.2` (green) with `goodColor.r, goodColor.g, goodColor.b`
- Replaced hardcoded `1, 1, 1` (white) with `neutralColor.r, neutralColor.g, neutralColor.b`
- Replaced hardcoded `0.3, 0.3, 0.3` (gray) with `grayColor.r, grayColor.g, grayColor.b`

## Benefits

1. **Respects User Settings**: Colors now adapt to user's accessibility preferences in game settings
2. **High Contrast Support**: If user enables high contrast mode, colors automatically adjust
3. **Colorblind Support**: Game provides appropriate color schemes for different types of color blindness
4. **Consistency**: Matches game's standard UI color scheme
5. **Future-Proof**: If game updates color definitions, mod automatically inherits them

## Color Sources

- **Good Color**: `getCore():getGoodHighlitedColor()` - Positive/discount color from game settings
- **Neutral Color**: `getCore():getNeutralHighlitedColor()` - Neutral/bad color from game settings
- **Gray Color**: Custom `{ r = 0.3, g = 0.3, b = 0.3, a = 1 }` - Reference/background color

## UI Behavior (Unchanged)

### Buy Tab
- **Price decrease** (discount): Good color + discount percentage
- **Price increase** (bad): Neutral color
- **No change**: Neutral color

### Sell Tab
- **Price increase** (good): Good color + gain percentage
- **Price decrease** (bad): Neutral color
- **No change**: Neutral color

### All Tabs
- **Base price**: Always gray (reference only)

## Testing

To verify colors are being read correctly:
1. Start game
2. Go to Options → Accessibility Settings
3. Try different color schemes
4. Open shop UI
5. Prices should reflect selected color scheme

## Notes

This change only affects ShopTabUI. Similar updates should be applied to ShopUI.lua if it has custom color rendering for cart items.
