# Project Zomboid Lua File I/O Reference

**Purpose**: Document what file I/O is actually available in PZ Lua  
**Status**: Quick Reference  
**Audience**: ShopsB42 mod developers

---

## Available APIs

### ✅ `getFileWriter(filename, append, doNotMakeDir)`

Write text to a file.

```lua
local writer = getFileWriter("shops/listing_snapshot.lua", true, false)
if writer then
    writer:write("return { ... }")
    writer:close()
end
```

**Parameters**:
- `filename`: Relative to Zomboid user directory
- `append`: If true, append to existing file
- `doNotMakeDir`: If true, fail if directory doesn't exist

**Relative Path**: Files are stored in `Zomboid/` directory (user's local Zomboid folder)

---

### ✅ `getFileReader(filename, doNotMakeDir)`

Read text from a file.

```lua
local reader = getFileReader("shops/listing_snapshot.lua", false)
if reader then
    while reader:ready() do
        local line = reader:readLine()
        -- Process line
    end
    reader:close()
end
```

**Parameters**:
- `filename`: Relative to Zomboid user directory
- `doNotMakeDir`: If true, fail if directory doesn't exist

---

### ✅ `dofile(filename)`

Load and execute a Lua file as Lua source code.

```lua
local ok, result = pcall(function()
    return dofile("shops/listing_snapshot.lua")
end)

if ok and type(result) == "table" then
    snapshot = result
end
```

**Note**: `dofile()` returns the value if file starts with `return`.

**Use `pcall()`**: Wrap in pcall to catch errors (missing file, syntax error, etc.)

---

## NOT Available

### ❌ `require("json")`

There is **no built-in JSON library** in Project Zomboid Lua.

```lua
local json = require("json")  -- ❌ WILL CRASH
```

### ❌ `require("file")` or other standard Lua I/O modules

Standard Lua's `io.open()`, `io.read()`, `io.write()` are **not available**.

Use `getFileWriter()` and `getFileReader()` instead.

### ❌ `os.getenv()` or filesystem manipulation

No access to environment variables or directory listing.

---

## Recommended Pattern: Lua Table Serialization

Since JSON is not available, serialize data as **Lua source code**:

### Write

```lua
local function serializeTable(t, indent)
    indent = indent or ""
    local lines = {}
    table.insert(lines, "{")
    
    for k, v in pairs(t) do
        local key = type(k) == "string" and string.format("[%q]", k) or "[" .. k .. "]"
        local value
        
        if type(v) == "table" then
            value = serializeTable(v, indent .. "  ")
        elseif type(v) == "string" then
            value = string.format("%q", v)  -- Escapes properly
        elseif type(v) == "boolean" then
            value = v and "true" or "false"
        else
            value = tostring(v)
        end
        
        table.insert(lines, indent .. "  " .. key .. " = " .. value .. ",")
    end
    
    table.insert(lines, indent .. "}")
    return table.concat(lines, "\n")
end

local snapshot = {
    revision = 47,
    Items = { ["Base.Apple"] = { basePrice = 150 } },
    defaultPrice = 100,
}

local serialized = "return " .. serializeTable(snapshot)
local writer = getFileWriter("shops/listing.lua", true, false)
writer:write(serialized)
writer:close()
```

### Read

```lua
local ok, snapshot = pcall(function()
    return dofile("shops/listing.lua")
end)

if ok and type(snapshot) == "table" then
    -- snapshot loaded successfully
else
    -- file doesn't exist or is corrupted
end
```

---

## Error Handling

Always use `pcall()` when loading files:

```lua
local function safeDofil(filename)
    local ok, result = pcall(function()
        return dofile(filename)
    end)
    
    if not ok then
        -- Error: File doesn't exist, syntax error, or other issue
        return nil
    end
    
    return result
end
```

---

## File Paths

**Important**: Paths are relative to the Zomboid user directory.

```
File API call: "shops/listing.lua"
Actual location: ~/.../Zomboid/shops/listing.lua

Windows:  %APPDATA%/Zomboid/shops/listing.lua
macOS:    ~/Library/Preferences/Zomboid/shops/listing.lua
Linux:    ~/.local/share/Zomboid/shops/listing.lua
```

**Best Practice**: Use subdirectories to organize cache files

```lua
-- Good organization
"shops/listing_cache_myserver.lua"
"shops/prices_cache.lua"
"shops/user_preferences.lua"

-- Avoid
"listing.lua"  -- Too generic
```

---

## Example: Full Caching System

```lua
local Cache = {}

-- Serialize any table to Lua source
function Cache.serialize(data)
    local function ser(t, indent)
        indent = indent or ""
        local lines = {"{"}
        for k, v in pairs(t) do
            local key = type(k) == "string" and string.format("[%q]", k) or "[" .. k .. "]"
            local val
            if type(v) == "table" then
                val = ser(v, indent .. "  ")
            elseif type(v) == "string" then
                val = string.format("%q", v)
            elseif type(v) == "boolean" then
                val = v and "true" or "false"
            else
                val = tostring(v)
            end
            table.insert(lines, indent .. "  " .. key .. " = " .. val .. ",")
        end
        table.insert(lines, indent .. "}")
        return table.concat(lines, "\n")
    end
    return "return " .. ser(data)
end

-- Save to disk
function Cache.save(filename, data)
    local writer = getFileWriter(filename, false, false)
    if not writer then
        return false
    end
    writer:write(Cache.serialize(data))
    writer:close()
    return true
end

-- Load from disk
function Cache.load(filename)
    local ok, result = pcall(function()
        return dofile(filename)
    end)
    return ok and result or nil
end

return Cache
```

Usage:

```lua
local cache = require("nshopsb42/cache/Cache")

-- Save
cache.save("shops/mydata.lua", { foo = "bar", count = 42 })

-- Load
local data = cache.load("shops/mydata.lua")
```

---

## Summary

| Need | Use | Don't Use |
|------|-----|-----------|
| Write text to file | `getFileWriter()` | `io.open()` (not available) |
| Read text from file | `getFileReader()` or `dofile()` | `io.read()` (not available) |
| Store Lua data | Serialize to Lua table source, save with `getFileWriter()`, load with `dofile()` | JSON (no library) |
| Parse serialized data | `dofile()` with `pcall()` | Custom parser (unnecessary) |
| Check file exists | Try to load with `pcall()`, check result | `os.path.exists()` (not available) |

---

## Resources

- **Official PZ Modding Guide**: https://projectzomboid.com/modding/
- **Kahlua JVM Lua**: PZ uses Kahlua (JVM Lua), not standard Lua
- **Limitations**: No LuaRocks, no external libraries, only PZ-provided APIs
