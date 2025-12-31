Below is a precise, end-to-end explanation of how **buildable world objects** are implemented in **Project Zomboid B42** for **Singleplayer (SP)** and **Multiplayer (MP)**—starting from a **custom tile**, through **drag placement**, and finally **authoritative construction in the world**.

---

## Project Zomboid — Building Object Pipeline (B42)

![Image](https://static0.thegamerimages.com/wordpress/wp-content/uploads/2023/09/post-office-riverside.jpg?dpr=1.5&fit=crop&q=50&w=825)

![Image](https://theindiestone.com/forums/uploads/monthly_2021_01/2.jpg.ffd6a63760f801ab8c7d6bbcab940a22.jpg)

![Image](https://i.gyazo.com/a22e8ad1ca02906f3309fc263b83bf3e.png)

![Image](https://www.exitlag.com/blog/wp-content/uploads/2025/08/project-zomboid-build-42-1024x576.png)

---

## 1. Custom Tile & Sprite Definition (Data Layer)

### Tile / Sprite

- Defined in **tilesets (.tiles / .pack)** and referenced by **sprite name**
- Sprite name is the canonical identifier used by Lua and Java

```lua
local sprite = "myMod_01_0"
```

### Object Class Choice

Most buildables are one of:

- `IsoObject` (static)
- `IsoThumpable` (doors, containers, destroyable)
- `IsoLightSource`, `IsoGenerator`, etc.

This choice determines destruction rules, interaction hooks, and sync behavior.

---

## 2. Drag Placement (Client-Side Only)

Placement preview is **always client-side**, even in MP.

### SetDrag Object

Typically implemented using:

- `ISBuildingObject`
- `ISPlaceable`
- Custom drag classes

```lua
local obj = ISBuildingObject:new(player, sprite)
getCell():setDrag(obj, player)
```

### What Happens Here

- Ghost sprite follows mouse
- Square validity checks:

  - `isFree()`
  - `isSolid()`
  - custom rules (ownership, distance, etc.)

- **No world mutation**
- **No server calls**

This phase is **visual + validation only**.

![Image](https://theindiestone.com/forums/uploads/monthly_2021_01/2.jpg.ffd6a63760f801ab8c7d6bbcab940a22.jpg)

![Image](https://images.steamusercontent.com/ugc/1769323681090781873/8C8ADD53F046DCE2E00D10F68DC43395C6F5F2D4/?ima=fit&imcolor=%23000000&imh=268&impolicy=Letterbox&imw=268&letterbox=true)

![Image](https://theindiestone.com/forums/uploads/monthly_2022_12/1694953293_SplitTiles.PNG.cff70ed0f39997e0d93137b8573f2bdc.PNG)

---

## 3. Confirm Placement → Timed Action

When the player clicks to build:

### A Timed Action is Queued

Examples:

- `ISBuildAction`
- `ISPlaceTrap`
- `ISAddFuelAction` (pattern reference)

**Critical B42 Rule:**

> Any action that creates or mutates world objects must complete on the **server** in MP.

---

## 4. Timed Action Execution Model (SP vs MP)

| Phase        | SP  | MP Client | MP Server |
| ------------ | --- | --------- | --------- |
| `perform()`  | ✔   | ✔         | ✖         |
| `complete()` | ✔   | ✖         | ✔         |

### Responsibilities

**`perform()`**

- Animation
- Sounds
- Progress UI
- NO object creation

**`complete()`**

- Create `IsoObject`
- Add to square
- Transmit to clients
- Consume items

---

## 5. World Object Creation (Authoritative Step)

### Server-Side (MP) / Local (SP)

```lua
local square = getCell():getGridSquare(x, y, z)
local obj = IsoObject.new(square, sprite, "MyObject")
square:AddTileObject(obj)
obj:transmitCompleteItemToClients()
```

### Why This Matters

- Server is the **only authority** in MP
- Client-side creation is discarded or rolled back
- Prevents ghost objects and dupes

![Image](https://i.gyazo.com/a22e8ad1ca02906f3309fc263b83bf3e.png)

![Image](https://images.steamusercontent.com/ugc/2002466871391126502/EF973DD2ED498D3151C1DA9A7FDAE3FA0D1AD68F/?ima=fit&imcolor=%23000000&imh=358&impolicy=Letterbox&imw=637&letterbox=true)

![Image](https://images.steamusercontent.com/ugc/1754734980975995998/2CB97F08D0C13760F8369A80014F5BC14BAE643F/?ima=fit&imcolor=%23000000&imh=358&impolicy=Letterbox&imw=637&letterbox=true)

---

## 6. Inventory Consumption & Sync

Also performed in `complete()`:

```lua
player:getInventory():Remove(item)
sendRemoveItemFromContainer(player:getInventory(), item)
```

Failure to sync inventory changes will cause:

- Item reappearing
- Silent rollback
- Desync after relog

---

## 7. Object Synchronisation Rules (MP)

After placement, at least one of the following must be called:

- `transmitCompleteItemToClients()` → new object
- `sync()` → state change
- `transmitUpdatedSpriteToClients()` → sprite swap
- `transmitRemoveItemFromSquare()` → deletion

No transmit = no persistence.

---

## 8. Key Differences: SP vs MP (Summary)

| Aspect             | SP       | MP              |
| ------------------ | -------- | --------------- |
| Drag preview       | Client   | Client          |
| Build validation   | Local    | Client + Server |
| Object creation    | Local    | **Server only** |
| Inventory mutation | Local    | **Server only** |
| Sync needed        | Implicit | **Explicit**    |

---

## 9. Common Modding Mistakes (B42)

1. Creating `IsoObject` in `perform()`
2. Creating objects on client in MP
3. Forgetting `transmitCompleteItemToClients()`
4. Mutating inventory without sync calls
5. Passing client-created objects to server timed actions

All five result in rollback or invisible objects.

---

## 10. Mental Model (Use This)

> **Drag = preview** > **Timed Action = permission & delay** > **Complete() = authority** > **Transmit = reality**

If you want, I can next:

- Map this directly onto your **Player Shop / Kiosk** objects
- Provide a **minimal B42-correct build template**
- Review an existing build script for MP safety
