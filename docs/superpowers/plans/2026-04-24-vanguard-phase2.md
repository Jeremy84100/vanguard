# Vanguard Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Vanguard from a robust preloader into a 2026-compliant Roblox Asset Engine with Multithreading (SharedTables), Spatial Priority, Advanced Throttling, Profiling, and modern DX compliance.

**Architecture:** We will convert core state to `SharedTable` to enable parallel execution. Then, we will create `Spatial` and `Throttler` modules that use 0-allocation patterns to dynamically adjust priorities and batch sizes. Finally, we will update the DX with `task.defer` and strict types.

**Tech Stack:** Luau, Roblox Studio, Jest Roblox, Parallel Luau, SharedTable.

---

### Task 1: Core Migration to SharedTable & Procedural Bypass

**Files:**
- Modify: `src/Core/Queue.luau`
- Modify: `src/Core/State.luau`
- Modify: `src/init.luau`
- Test: `tests/Queue.spec.luau`

- [ ] **Step 1: Write the failing test**

```luau
-- tests/Queue.spec.luau (append)
local SharedTable = require(game.ReplicatedStorage.Vanguard.Core.Queue) -- Assuming it returns SharedTable
describe("SharedTable Integration", function()
	it("should use SharedTable for internal queue", function()
		local Queue = require(game.ReplicatedStorage.Vanguard.Core.Queue)
		-- Since Queue is supposed to be a SharedTable now or hold them
		expect(type(Queue.GetRingBuffer)).toBe("function")
		expect(typeof(Queue.GetRingBuffer(1))).toBe("SharedTable")
	end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `rojo run tests/Queue.spec.luau` (or command bar: `Jest.runCLI(game.ReplicatedStorage.VanguardTests, {verbose = true}, {game.ReplicatedStorage.VanguardTests}):awaitStatus()`)
Expected: FAIL with "function not defined" or "Expected SharedTable"

- [ ] **Step 3: Write minimal implementation**

```luau
-- src/Core/Queue.luau
--!strict
local HttpService = game:GetService("HttpService")
local Queue = {}
local Queues = SharedTable.new()
Queues[1] = SharedTable.new()
Queues[2] = SharedTable.new()
Queues[3] = SharedTable.new()
Queues[4] = SharedTable.new()

local Pointers = SharedTable.new()
for i = 1, 4 do
	local ptr = SharedTable.new()
	ptr.Head = 1
	ptr.Tail = 1
	Pointers[i] = ptr
end

Queue.InstanceRegistry = {} -- Main thread only

function Queue.Push(priority: number, asset: any)
	local p = priority
	local tail = Pointers[p].Tail
	
	local assetKey = asset
	if typeof(asset) == "Instance" then
		assetKey = "inst_" .. HttpService:GenerateGUID(false)
		Queue.InstanceRegistry[assetKey] = asset
	end

	Queues[p][tail] = assetKey
	Pointers[p].Tail = tail + 1
end

function Queue.Pop(priority: number): any?
	local p = priority
	local head = Pointers[p].Head
	if head == Pointers[p].Tail then return nil end
	
	local assetKey = Queues[p][head]
	Queues[p][head] = nil -- Free memory
	Pointers[p].Head = head + 1
	
	if type(assetKey) == "string" and string.sub(assetKey, 1, 5) == "inst_" then
		local instance = Queue.InstanceRegistry[assetKey]
		Queue.InstanceRegistry[assetKey] = nil -- Free registry
		return instance
	end

	return assetKey
end

function Queue.GetRingBuffer(priority: number)
	return Queues[priority]
end

return Queue
```

```luau
-- src/init.luau (Modify FormatAsset to bypass procedural)
local function FormatAsset(asset: any): string?
	if typeof(asset) == "Instance" then
		if asset:IsA("EditableImage") or asset:IsA("EditableMesh") then
			return nil -- Bypass procedural
		end
	end
	return "rbxassetid://" .. tostring(asset)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Jest.runCLI(game.ReplicatedStorage.VanguardTests, {verbose = true}, {game.ReplicatedStorage.VanguardTests}):awaitStatus()`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/Core/Queue.luau src/init.luau tests/Queue.spec.luau
git commit -m "refactor: migrate Queue to SharedTable and bypass procedural assets"
```

---

### Task 2: DX Compliance (task.defer & Type Exports)

**Files:**
- Modify: `src/init.luau`
- Test: `tests/init.spec.luau`

- [ ] **Step 1: Write the failing test**

```luau
-- tests/init.spec.luau (append)
describe("DX Compliance", function()
	it("should expose strict types and use defer", function()
		local Vanguard = require(game.ReplicatedStorage.Vanguard)
		expect(type(Vanguard.Load)).toBe("function")
		-- We can't runtime test type exports, but we can verify event scheduling
		local fired = false
		Vanguard.OnReady(function() fired = true end)
		Vanguard.Load(12345)
		-- If it was task.spawn, it might fire immediately if cached. If task.defer, it fires later.
		expect(fired).toBe(false)
	end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Jest.runCLI(game.ReplicatedStorage.VanguardTests, {verbose = true}, {game.ReplicatedStorage.VanguardTests}):awaitStatus()`
Expected: FAIL (fired is true if spawn was used)

- [ ] **Step 3: Write minimal implementation**

```luau
-- src/init.luau (Add Types and replace task.spawn)
--!strict
export type VanguardPriority = number
export type VanguardAPI = {
	Load: (asset: any, priority: VanguardPriority?) -> (),
	Cancel: (asset: any) -> (),
	SetBatchSize: (size: number) -> (),
	OnReady: (callback: () -> ()) -> (),
	OnProgress: (priority: VanguardPriority, callback: (loaded: number, total: number) -> ()) -> (),
	OnFailed: (callback: (asset: any, err: string) -> ()) -> ()
}

local Vanguard = {} :: VanguardAPI

-- Replace all task.spawn with task.defer in internal event triggers
-- Example:
-- task.defer(callback)
-- (Make sure to replace every task.spawn in the file)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Jest.runCLI(game.ReplicatedStorage.VanguardTests, {verbose = true}, {game.ReplicatedStorage.VanguardTests}):awaitStatus()`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/init.luau tests/init.spec.luau
git commit -m "feat: add Luau strict type exports and convert spawn to defer"
```

---

### Task 3: The Spatial Priority Module (Parallel Luau)

**Files:**
- Create: `src/Modules/Spatial.luau`
- Create: `tests/Spatial.spec.luau`

- [ ] **Step 1: Write the failing test**

```luau
-- tests/Spatial.spec.luau
local Spatial = require(game.ReplicatedStorage.Vanguard.Modules.Spatial)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

describe("Spatial Module", function()
	it("should calculate priority based on distance and velocity", function()
		local origin = Vector3.new(0, 0, 0)
		local velocity = Vector3.new(0, 0, 50) -- Moving towards Z
		local target = Vector3.new(0, 0, 100)
		local priority = Spatial.CalculatePriority(origin, velocity, target)
		expect(priority).toBe(1)
	end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `rojo run tests/Spatial.spec.luau`
Expected: FAIL (Module not found)

- [ ] **Step 3: Write minimal implementation**

```luau
-- src/Modules/Spatial.luau
--!strict
local Spatial = {}

function Spatial.CalculatePriority(origin: Vector3, velocity: Vector3, target: Vector3): number
	local distance = (target - origin).Magnitude
	local direction = (target - origin).Unit
	local speed = velocity.Magnitude
	
	-- Predictive loading: if moving fast towards target, artificial distance reduction
	if speed > 10 then
		local dotProduct = velocity.Unit:Dot(direction)
		if dotProduct > 0.5 then
			distance = distance - (speed * dotProduct)
		end
	end
	
	if distance < 100 then return 1
	elseif distance < 250 then return 2
	elseif distance < 500 then return 3
	else return 4 end
end

function Spatial.Track(assets: { [any]: Vector3 }, origin: Vector3, velocity: Vector3)
	task.desynchronize() -- Move to Parallel Thread
	for assetId, pos in pairs(assets) do
		-- Omitted Raycast for brevity in minimal implementation, added in full
		local p = Spatial.CalculatePriority(origin, velocity, pos)
		-- Send to SharedTable Queue
	end
end

return Spatial
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Jest.runCLI(game.ReplicatedStorage.VanguardTests, {verbose = true}, {game.ReplicatedStorage.VanguardTests}):awaitStatus()`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/Modules/Spatial.luau tests/Spatial.spec.luau
git commit -m "feat: implement Spatial priority with predictive velocity in Parallel Luau"
```

---

### Task 4: The Advanced Network Throttler

**Files:**
- Create: `src/Modules/Throttler.luau`
- Create: `tests/Throttler.spec.luau`

- [ ] **Step 1: Write the failing test**

```luau
-- tests/Throttler.spec.luau
local Throttler = require(game.ReplicatedStorage.Vanguard.Modules.Throttler)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

describe("Dynamic Throttler", function()
	it("should reduce batch size on slow load times", function()
		local newSize = Throttler.CalculateBatchSize(50, 2.5) -- 2.5s is too long
		expect(newSize).toBeLessThan(50)
	end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Jest.runCLI(game.ReplicatedStorage.VanguardTests, {verbose = true}, {game.ReplicatedStorage.VanguardTests}):awaitStatus()`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```luau
-- src/Modules/Throttler.luau
--!strict
local Throttler = {}
local TARGET_TIME = 0.5

function Throttler.CalculateBatchSize(currentBatchSize: number, actualLoadTime: number): number
	if actualLoadTime <= 0.01 then actualLoadTime = 0.01 end
	local ratio = TARGET_TIME / actualLoadTime
	local newSize = math.floor(currentBatchSize * ratio)
	return math.clamp(newSize, 5, 100)
end

function Throttler.GetAssetWeight(asset: any): number
	if typeof(asset) == "Instance" then
		if asset:IsA("MeshPart") then return 10 end
		if asset:IsA("ImageLabel") then return 2 end
	end
	return 1
end

return Throttler
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Jest.runCLI(game.ReplicatedStorage.VanguardTests, {verbose = true}, {game.ReplicatedStorage.VanguardTests}):awaitStatus()`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/Modules/Throttler.luau tests/Throttler.spec.luau
git commit -m "feat: implement Throttler with load time calculations and asset weighting"
```

---

### Task 5: The Bottleneck Profiler

**Files:**
- Create: `src/Modules/Profiler.luau`
- Test: `tests/Profiler.spec.luau`

- [ ] **Step 1: Write the failing test**

```luau
-- tests/Profiler.spec.luau
local Profiler = require(game.ReplicatedStorage.Vanguard.Modules.Profiler)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

describe("Bottleneck Profiler", function()
	it("should track and report slow assets", function()
		Profiler.Record(12345, 1.5)
		Profiler.Record(67890, 0.1)
		local top = Profiler.GetTopSlowest(1)
		expect(top[1].id).toBe(12345)
	end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Jest.runCLI(game.ReplicatedStorage.VanguardTests, {verbose = true}, {game.ReplicatedStorage.VanguardTests}):awaitStatus()`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```luau
-- src/Modules/Profiler.luau
--!strict
local Profiler = {}
local Records = {}

function Profiler.Record(assetId: any, timeTaken: number)
	table.insert(Records, {id = assetId, time = timeTaken})
	-- Prevent memory leak: keep only the top 1000 records
	if #Records > 1000 then
		table.remove(Records, 1)
	end
end

function Profiler.GetTopSlowest(limit: number)
	table.sort(Records, function(a, b) return a.time > b.time end)
	local result = {}
	for i = 1, math.min(limit, #Records) do
		table.insert(result, Records[i])
	end
	return result
end

function Profiler.GenerateReport()
	local top = Profiler.GetTopSlowest(10)
	print("--- VANGUARD PROFILER REPORT ---")
	for i, record in ipairs(top) do
		print(string.format("%d. Asset %s took %.2fs", i, tostring(record.id), record.time))
	end
end

function Profiler.Clear()
	table.clear(Records)
end

return Profiler
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Jest.runCLI(game.ReplicatedStorage.VanguardTests, {verbose = true}, {game.ReplicatedStorage.VanguardTests}):awaitStatus()`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/Modules/Profiler.luau tests/Profiler.spec.luau
git commit -m "feat: implement Bottleneck Profiler"
```
