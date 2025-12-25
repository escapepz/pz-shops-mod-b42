# Currency Feature - Manual Test Checklist

## Loot Coin/Money Script

- [x] "Loot All Coins" option appears in context menu when right-clicking coin/money items
- [x] Loot All Coins collects all coins/money from nearby containers
- [x] Coins are properly transferred to player inventory
- [x] Make sure no items dup/roll-back after re-login

## Wallet - Linking System

- [x] Can link a wallet to character via right-click context menu
- [x] Only 1 wallet can be linked at a time
- [x] Attempting to link a second wallet unlinks the first (or shows error)
- [x] Unlinked wallets show as "invalid" state
- [x] Linked wallet displays character ownership correctly
- [x] Make sure no items dup/roll-back after re-login

## Wallet - Context Menu Options

- [x] **Link** option appears on unlinked wallets ONLY there is no linked wallet in main inventory
- [x] **Unlink** option appears on linked wallet
- [x] **Transfer** option opens UI for coin transfers
- [x] **Move Coins to Account** transfers coins from wallet to account
- [x] Make sure no items dup/roll-back after re-login

## Wallet - Linking & Display

- [x] Wallet tooltip displays current balance when linked
- [x] Tooltip hides balance when wallet is unlinked/invalid
- [x] Tooltip updates after balance changes
- [x] Wallet appears properly in main inventory

## Deposit Method 1: Move Coins to Account

- [x] Right-click on coins/money shows "Move Coins to Account" option
- [x] Option only appears if linked wallet is in main inventory
- [x] Coins are removed from inventory when moved
- [x] Account balance increases correctly
- [x] Make sure no items dup/roll-back after re-login

## Deposit Method 2: Transfer (Player to Player)

- [x] Transfer UI opens when Transfer option selected on linked wallet
- [x] Can specify amount of coins to transfer
- [x] Can specify recipient player username
- [x] Transfer completes successfully between online players (instant credit)
- [x] Sender's balance decreases immediately (before recipient receives)
- [x] Recipient receives notification of transfer (if online)
- [x] Cannot transfer from invalid/unlinked wallets
- [x] Cannot transfer more than available balance
- [x] Rate limiting prevents spam (1.5s min interval, 3/10s window)

## Offline Recipients & Mailbox System

- [x] Transfer to offline players queues to server-side mailbox
- [x] Sender's balance deducted immediately (no loss possible)
- [x] Offline recipient account marked with hasMailbox flag
- [x] Flag synced to client via CoinBalance ModData
- [x] "Claim Offline Mailbox" option appears on linked wallet (only if mailbox has funds)
- [x] Claiming mailbox credits all pending entries atomically
- [x] Mailbox cleared after claiming (no duplication on reclaim)
- [x] Player receives notification when claiming mailbox
- [x] Notification shows total coins and transfer count
- [x] Works correctly after server restart (mailbox persisted)

## Death Safety

- [x] Player dies while carrying wallet with coins
- [x] Account money persists after respawn
- [x] Coins in wallet persist or transfer to account as designed

## Edge Cases

- [x] Dropping linked wallet and picking it up again
- [x] Transferring coins from wallet with insufficient coins
- [x] Multiple players attempting to use same wallet
- [x] Wallet missing from inventory during transaction
