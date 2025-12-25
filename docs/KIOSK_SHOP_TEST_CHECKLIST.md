# Kiosk Shop Manual Test Checklist (B42.13 MP)

## Context Menu

- [ ] Left-click on shop tile shows "Shop" context menu option
- [ ] Left-click elsewhere shows "View Shop Items" context menu option
- [ ] Right-click on kiosk shows "Shop" option in context menu
- [ ] Only one context menu option appears at a time

## Shop Access

- [ ] "Shop" option opens purchase window only at kiosk location
- [ ] "View Shop Items" can be accessed from anywhere
- [ ] View Shop Items displays items but cannot purchase from this view
- [ ] Attempting to purchase from View Shop Items fails gracefully
- [ ] Cannot purchase items outside of kiosk location

## Currency System (Virtual Balance Only)

- [ ] Normal currency displays correctly in shop UI
- [ ] Special currency (event type) displays correctly
- [ ] Both currency types show player's current balance
- [ ] Currency prices display for each item
- [ ] Cannot purchase if insufficient normal currency
- [ ] Cannot purchase if insufficient special currency
- [ ] Purchase deducts correct currency amount from player account
- [ ] Account money updates immediately after purchase
- [ ] **[NEW]** No coin items are created or removed from inventory
- [ ] **[NEW]** Balance is stored in ModData (virtual), not physical items

## Inventory Management - Buying

- [ ] Purchased item appears in character inventory
- [ ] Item quantity increases if buying duplicates
- [ ] Player's account money decreases after purchase
- [ ] No wallet item required to make purchase
- [ ] Cannot purchase if inventory is full
- [ ] Cannot purchase if item is too heavy for inventory capacity
- [ ] Error message displays for failed purchases
- [ ] **[NEW]** Cart clears automatically after successful purchase

## Inventory Management - Selling

- [ ] Sell tab is accessible and displays all inventory items
- [ ] Can select items from character inventory
- [ ] Item price displays correctly in Sell tab
- [ ] Selling item removes it from inventory
- [ ] Account money increases after sale
- [ ] Sale price matches advertised sell price
- [ ] Cannot sell quest items (if applicable)
- [ ] Cannot sell equipped items
- [ ] **[NEW]** Cart clears automatically after successful sale

## Shop Tiles (Kiosk)

- [ ] Shop tiles are indestructible by players
- [ ] Shop tiles can only be removed by admin
- [ ] Shop tile displays correctly in world
- [ ] Shop tile with fake NPC displays one of 4 variations
- [ ] Multiple shop tiles can exist in same world
- [ ] Shop tiles can be placed on any floor surface

## Shop Tile Rotation

- [ ] Building rotation key (R) rotates shop tile
- [ ] Shop tile rotates between 2 positions
- [ ] Rotation is smooth and immediate
- [ ] Rotated position persists after reload
- [ ] Players can rotate their own placed tiles (if applicable)
- [ ] Admin can rotate any tile

## Admin Features (Kiosk-Specific)

- [ ] Admin can place shop tiles
- [ ] Admin can rotate shop tiles
- [ ] Admin can remove shop tiles via sledgehammer
- [ ] Non-admin cannot modify shop tiles

## 3D Car Model Viewer (if applicable)

- [ ] Car model displays correctly (if car items exist)
- [ ] Car model rotates and zooms properly
- [ ] CarWanna pinkslip support working
- [ ] Custom patches load correctly
- [ ] Camera controls are responsive

## Multiplayer Safety (B42.13 MP-Specific)

- [ ] **[NEW]** Shop actions work on dedicated servers
- [ ] **[NEW]** No UI objects serialized in network traffic
- [ ] **[NEW]** Transaction IDs prevent duplicate purchases on reconnect
- [ ] **[NEW]** Multiple players can buy/sell simultaneously without conflicts
- [ ] **[NEW]** Server audit log records all transactions
- [ ] **[NEW]** Balance mutations are server-authoritative (no client cheating)
- [ ] **[NEW]** Cart clears properly in multiplayer environments
- [ ] **[NEW]** Inventory changes sync correctly across clients
- [ ] **[NEW]** No double-spend exploits possible

## Edge Cases & Error Handling

- [ ] Shop window closes properly
- [ ] Can reopen shop immediately after closing
- [ ] **[UPDATED]** Network lag doesn't cause duplicate purchases (txnId protection)
- [ ] Items restore if connection drops mid-purchase
- [ ] Invalid data displays error message
- [ ] Game doesn't crash with invalid shop configuration
- [ ] **[NEW]** Server handles missing account gracefully

## Performance

- [ ] Shop UI loads quickly
- [ ] No frame rate drops when opening shop
- [ ] No memory leaks after repeated open/close cycles
- [ ] **[NEW]** Audit log doesn't cause server performance issues

## Audit & Compliance

- [ ] **[NEW]** Server audit log contains all transactions
- [ ] **[NEW]** Audit entries have correct timestamps and player info
- [ ] **[NEW]** Audit log persists across server restarts
- [ ] **[NEW]** Audit log has sane size limits (5000 entries max)
- [ ] **[NEW]** Failed transactions don't appear in audit log
