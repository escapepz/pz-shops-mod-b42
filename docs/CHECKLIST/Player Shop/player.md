# MP Manual Test Checklist — B42.13

---

## C. Player Shop Tests

---

### C1. Player Tests (Owner)

#### Placement

- [ ] Craft Player Shop (Carpentry tab)
- [x] Place via **world context menu**, not item
- [x] Rotate shop (R key) -> both positions valid

#### Pricing & Selling

- [ ] Item with `Write` tag required to set price
- [ ] Right-click item -> **Set Price**
- [ ] UI allows normal + special currency
- [ ] Highest currency value used as sale price
- [ ] Item must be transferred to shop container
- [ ] Item appears in Player Shop UI only after price set

#### Container Rules

- [ ] Container size = 100 units
- [ ] Traits (Organized / Disorganized) affect capacity
- [ ] Only owner can remove items
- [ ] Lock container hides contents from others
- [ ] Unlock reveals contents

#### Manage Shop Menu

- [ ] Lock shop container
- [ ] Unlock shop container
- [ ] View Income UI shows buyer + payment
- [ ] Get Income -> sent to linked account
- [ ] Pick up shop only if empty + no income
- [ ] Change sign -> all 10 options available

#### Concurrency & Safety

- [ ] Only one player can use shop at a time
- [ ] Second player blocked until shop is free
- [ ] CTD / disconnect triggers **10-minute protection lock**
- [ ] No duplication after crash/reconnect

---

### C2. Player Tests (Customer)

- [ ] Can browse Player Shop UI
- [ ] Cannot remove items from container
- [ ] Purchase updates seller income
- [ ] Purchase updates buyer inventory
- [ ] Relog -> purchases persist

---
