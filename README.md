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

local result, ctx = pipeline:run(1)
print(result)  -- Will process until condition fails
```

### Hooks, Catch, and Finally

```lua
local pipeline = Pipeline.new()
    :hooksFn({
        beforeStage = function(label, val, ctx) print("Before", label, val) end,
        afterStage = function(label, val, ctx) print("After", label, val) end
    })
    :catch(function(err, ctx) print("Error", err) return 0 end)
    :finally(function(result, ctx) print("Pipeline finished with", result) end)
```


### example on how to create Folder to player
```lua
local PlayerData = Pipeline.new()
	:step(function(player, context)
		context.PlayerId = player.UserId
		local leaderstats = Instance.new('Folder')
		leaderstats.Name = 'leaderstats'
		leaderstats.Parent = player
		return leaderstats
	end)
	:step(function(data, context)
		print("Stage result:", data)
		print("Pipeline context:", context)
	end)
	:catch(function(err, ctx)
		warn("Error in PlayerData pipeline:", err)
	end)

Players.PlayerAdded:Connect(function(player)
	local success, ctx
	local ok, result
	ok, result = pcall(function()
		result, ctx = PlayerData:run(player)
	end)
	if not ok then
		warn("PlayerData pipeline error for", player.Name, ":", result)
	end
end)
```
it will print StageResult: leaderstats
context: { PlayerId = id } 
---

## Contributing

1. Fork the repository
2. Implement your improvements
3. Submit a pull request with a detailed description of changes

---

## License

MIT License – Free to use, modify, and distribute.
