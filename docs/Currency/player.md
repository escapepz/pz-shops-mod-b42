# MP Manual Test Checklist — B42.13

## A. Currency & Transfer Tests

---

### A1. Player Tests (Non-Admin)

#### Wallet & Account

- [ ] Right-click wallet shows **4 options**: `Link`, `Unlink`, `Transfer`, `Move Coins to Account`
- [ ] Link wallet successfully to character
- [ ] Attempt to link **second wallet** → should fail / be invalid
- [ ] Unlink wallet → wallet becomes usable by other players
- [ ] Wallet tooltip displays **current account balance**
- [ ] Wallet **does not physically store coins/money**
- [ ] Coins remain safe after **player death**
- [ ] Wallet must be in **main inventory** to accept coins

#### Coin Handling

- [ ] Right-click coins → deposit into wallet
- [ ] Use **“Move Coins to Account”** → coins removed, account updated
- [ ] Coins disappear from inventory after deposit
- [ ] Relog → balance persists correctly

#### Loot Coins

- [ ] Right-click coin/money → **“Loot All Coins”**
- [ ] All nearby containers are scanned
- [ ] Only valid coin/money items are collected
- [ ] No duplication or missing coins
- [ ] MP sync confirmed (other players see correct state)

---

### A2. Transfer Tests (Player → Player)

#### Transfer UI

- [ ] Open **Transfer UI** from wallet
- [ ] Search for another **online survivor**
- [ ] Cannot search for offline players
- [ ] Enter amount → confirm transfer
- [ ] Sender balance decreases correctly
- [ ] Receiver balance increases correctly

#### Notifications

- [ ] Receiver gets **transfer notification**
- [ ] Notification shows sender + amount
- [ ] No notification if receiver is offline

---
