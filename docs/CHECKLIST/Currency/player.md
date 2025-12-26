# MP Manual Test Checklist — B42.13

## A. Currency & Transfer Tests

---

### A1. Player Tests (Non-Admin)

#### Wallet & Account

- [x] Right-click wallet/coins shows **4 options**: `Link`, `Unlink`, `Transfer`, `Move Coins to Account`
- [x] Link wallet successfully to character
- [x] Attempt to link **second wallet** -> should fail / be invalid
- [x] Unlink wallet -> wallet becomes usable by other players
- [x] Wallet tooltip displays **current account balance**
- [x] Wallet **does not physically store coins/money**
- [x] Coins remain safe after **player death**
- [x] Wallet must be in **main inventory** to accept coins

#### Coin Handling

- [x] Right-click coins -> deposit into wallet
- [x] Use **"Move Coins to Account"** -> coins removed, account updated
- [x] Coins disappear from inventory after deposit
- [x] Relog -> balance persists correctly

#### Loot Coins

- [x] Right-click coin/money -> **"Loot All Coins"**
- [x] All nearby containers are scanned
- [x] Only valid coin/money items are collected
- [x] No duplication or missing coins
- [x] MP sync confirmed (other players see correct state)

---

### A2. Transfer Tests (Player -> Player)

#### Transfer UI

- [x] Open **Transfer UI** from wallet
- [x] Search for **recipient** (online or offline)
- [x] Enter amount -> confirm transfer
- [x] Sender balance decreases correctly
- [x] Receiver balance increases correctly (online immediately, offline via Claim Offline Mailbox on login)

#### Notifications

- [x] Receiver gets **transfer notification**
- [x] Notification shows sender + amount
- [x] No notification if receiver is offline

---
