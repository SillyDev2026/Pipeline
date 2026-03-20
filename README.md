# Lua Pipeline Module

A fully-featured, type-safe, and chainable **Pipeline implementation for Roblox/Lua**, designed to manage sequential and conditional processing of data with full context support.

---

## Features

* **Sequential `.step()` stages** for processing input
* **Parallel execution `.parallel()`** with optional merge function
* **Conditional branching `.branch()`** based on stage output
* **Filtering stages `.filter()`** to selectively continue processing
* **Repeating stages `.repeatStage()`** with condition-based loops
* **Hooks support**: `beforeStage` and `afterStage` for logging or side effects
* **Error handling**: `.catch()` with context-aware handling
* **Completion handling**: `.finally()` for cleanup or final processing
* Fully **type-safe** with Luau generics and context propagation

---

## Installation

Place the `Pipeline` module in `ReplicatedStorage` or any other shared directory:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pipeline = require(ReplicatedStorage.Pipeline)
```

---

## Basic Usage

### Creating a Pipeline

```lua
local pipeline = Pipeline.new()
    :step(function(input, ctx)
        return input + 1
    end, "Increment")
    :step(function(input, ctx)
        return input * 2
    end, "Double")

local result, context = pipeline:run(5)
print(result)  -- Output: 12
```

### Parallel Stages

```lua
local pipeline = Pipeline.new()
    :parallel({
        function(input) return input + 1 end,
        function(input) return input + 2 end
    }, "ParallelAdd")
    :merge(function(results)
        return results[1] + results[2]
    end)

local result, ctx = pipeline:run(5)
print(result) -- Output: 13
```

### Conditional Branching

```lua
local branchPipeline = Pipeline.new()
    :step(function(input) return input * 2 end)

local pipeline = Pipeline.new()
    :branch(function(val)
        return val > 10 and "high" or "low"
    end, {
        high = branchPipeline,
        low = Pipeline.new():step(function(val) return val end)
    })

local result, ctx = pipeline:run(6)
print(result)  -- Output based on branch
```

### Filter and Repeat

```lua
local pipeline = Pipeline.new()
    :filter(function(val) return val % 2 == 0 end)
    :repeatStage(function(val) return val + 2 end, function(val) return val < 10 end)

loca
```
