# Currency Feature - Manual Test Checklist

## Loot Coin/Money Script
- [ ] "Loot All Coins" option appears in context menu when right-clicking coin/money items
- [ ] Loot All Coins collects all coins/money from nearby containers
- [ ] Coins are properly transferred to player inventory
- [ ] Make sure no items dup/roll-back after re-login

## Wallet - Linking System
- [ ] Can link a wallet to character via right-click context menu
- [ ] Only 1 wallet can be linked at a time
- [ ] Attempting to link a second wallet unlinks the first (or shows error)
- [ ] Unlinked wallets show as "invalid" state
- [ ] Linked wallet displays character ownership correctly

## Wallet - Context Menu Options
- [ ] **Link** option appears on unlinked wallets ONLY there is no linked wallet in main inventory
- [ ] **Unlink** option appears on linked wallet
- [ ] **Transfer** option opens UI for coin transfers
- [ ] **Move Coins to Account** transfers coins from wallet to account

## Wallet - Linking & Display
- [ ] Wallet tooltip displays current balance when linked
- [ ] Tooltip hides balance when wallet is unlinked/invalid
- [ ] Tooltip updates after balance changes
- [ ] Wallet appears properly in main inventory

## Deposit Method 1: Move Coins to Account
- [ ] Right-click on coins/money shows "Move Coins to Account" option
- [ ] Option only appears if linked wallet is in main inventory
- [ ] Coins are removed from inventory when moved
- [ ] Account balance increases correctly
- [ ] Coins removed are synced to all clients (no duplication on relog)

## Deposit Method 2: Transfer (Player to Player)
- [ ] Transfer UI opens when Transfer option selected on linked wallet
- [ ] Can specify amount of coins to transfer
- [ ] Can specify recipient player username
- [ ] Transfer completes successfully between players
- [ ] Sender's balance decreases, recipient's balance increases
- [ ] Recipient receives notification of transfer
- [ ] Cannot transfer from invalid/unlinked wallets
- [ ] Cannot transfer more than available balance
- [ ] Transfer UI closes after successful transfer

## Death Safety
- [ ] Player dies while carrying wallet with coins
- [ ] Account money persists after respawn
- [ ] Coins in wallet persist or transfer to account as designed

## Edge Cases
- [ ] Dropping linked wallet and picking it up again
- [ ] Transferring coins from wallet with insufficient coins
- [ ] Multiple players attempting to use same wallet
- [ ] Wallet missing from inventory during transaction
