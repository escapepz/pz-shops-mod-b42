# Critical Fix Applied

## Issue
Runtime error on mod load:
```
attempted index: derive of non-table: null
```

## Root Cause
Both new action files were inheriting from `ISBuildAction` which doesn't exist in Project Zomboid's base classes.

The correct base class is `ISBaseTimedAction` (used by all existing timed actions like ShopBuyAction).

## Fix Applied

### ISAddPlayerShopAction.lua
- Changed `require("TimedActions/ISBuildAction")` → `require("TimedActions/ISBaseTimedAction")`
- Changed `ISBuildAction:derive(...)` → `ISBaseTimedAction:derive(...)`
- Updated `ISBuildAction.perform()` → `ISBaseTimedAction.perform()`
- Updated `ISBuildAction.complete()` → `ISBaseTimedAction.complete()`
- Updated `ISBuildAction.new()` → `ISBaseTimedAction.new()`

### ISAddShopAction.lua
- Applied identical changes as above

## Verification
✅ ISAddPlayerShopAction.lua - No diagnostics errors
✅ ISAddShopAction.lua - No diagnostics errors

## Status
Ready to test in Project Zomboid
