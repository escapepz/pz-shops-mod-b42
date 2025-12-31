## Summary

**ISBuildingObject Server-Side Handling Flow:**

```mermaid
flowchart TD
    A["Client Click Event"] -->|setDrag| B["ISBuildingObject attached to IsoCell"]
    B -->|Events.OnDoTileBuilding2| C["DoTileBuilding called each frame"]

    C --> D{"Key Down Attack/Click?"}
    D -->|Yes| E["Set isLeftDown = true rotateMouse for direction"]
    D -->|No| F{"Was Down?"}
    F -->|Yes| G["Set isLeftDown = false Set build = canBeBuild"]
    F -->|No| H["Just moving cursor"]

    G --> I["Validate & Render"]
    E --> I
    H --> I

    I --> J["draggingItem:isValid checks placement"]
    J --> K["draggingItem:render shows ghost sprite"]

    K --> L{"canBeBuild AND build flag?"}
    L -->|Yes| M["Call tryBuild"]
    L -->|No| N["Continue dragging"]

    M --> O["Create ISBuildAction with buildObject copy"]
    O --> P{"walkTo target or cheat?"}
    P -->|Yes| Q["Setup equipment items"]
    Q --> R["ISTimedActionQueue.add item transfer action"]
    R --> S["ISTimedActionQueue.add grab ground items"]
    S --> T["ISTimedActionQueue.add BUILD ACTION"]

    T --> U["Player performs action ISBuildAction.perform"]
    U --> V["buildObject:create spawns IsoThumpable"]

    V --> W{"dragNilAfterPlace?"}
    W -->|Yes| X["getCell:setDrag nil"]
    W -->|No| Y["dragNilAfterPlace=false draggingItem:reinit"]

    X --> Z["Drag ends Object placed"]
    Y --> AA["Allow placing again"]

    P -->|No| AB["Print error onActionComplete"]

    style B fill:#1a1a1a,stroke:#00ff00,color:#00ff00
    style C fill:#1a1a1a,stroke:#00ff00,color:#00ff00
    style M fill:#1a1a1a,stroke:#ffff00,color:#ffff00
    style O fill:#1a1a1a,stroke:#00ffff,color:#00ffff
    style T fill:#1a1a1a,stroke:#ff00ff,color:#ff00ff
    style U fill:#1a1a1a,stroke:#ff00ff,color:#ff00ff
    style V fill:#1a1a1a,stroke:#ff6600,color:#ff6600
    style X fill:#1a1a1a,stroke:#00ff00,color:#00ff00
```

1. **setDrag Activation** (line 214): Building object attached to IsoCell when player initiates placement

2. **DoTileBuilding Loop** (lines 100-179): Called each frame via `Events.OnDoTileBuilding2`

   - Detects mouse clicks (Attack/Click key)
   - When released: sets `build = true` if valid placement
   - Validates position with `isValid()`
   - Renders ghost sprite preview

3. **tryBuild Trigger** (line 174): When `build=true` AND `canBeBuild=true`

   - Creates **ISBuildAction** early (line 203) with a copy of the building object
   - Validates walkable path via `walkTo()` (line 212)

4. **ISTimedActionQueue Chain** (lines 233-276):

   - **Line 233**: Transfer items if needed (two-hand items)
   - **Lines 251/259**: Grab ground items as materials
   - **Line 276**: Add main **ISBuildAction** to queue
   - Server executes actions sequentially

5. **World Instantiation**: ISBuildAction.perform() calls `buildObject:create()` → spawns IsoThumpable into world

6. **Cleanup** (lines 213-217):
   - If `dragNilAfterPlace=true`: calls `setDrag(nil)` to end drag immediately
   - If `false`: calls `reinit()` to allow placing same object again

The server uses `ISTimedActionQueue` to serialize the build process, ensuring equipment setup and material gathering happens before the actual build action executes.
