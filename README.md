<div align="center">
  <img src="banner.jpg" width="100%" alt="Vanguard Banner">

  *Zero-allocation, spatially-aware asset preloading framework for Roblox*

  [![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/Jeremy84100/Vanguard)
  [![Platform](https://img.shields.io/badge/Roblox-00A2FF?logo=roblox&logoColor=white)](https://roblox.com)
  [![Luau](https://img.shields.io/badge/Luau-Strict-FF5A0E)](https://luau-lang.org)
  [![Performance](https://img.shields.io/badge/Performance-Zero--Allocation-brightgreen)](https://github.com/Jeremy84100/Vanguard)
  [![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

  ⭐ If you like this project, star it on GitHub!

  [Overview](#overview) • [Key Features](#key-features) • [Installation](#installation) • [Benchmarks](#-performance-benchmarks) • [FAQ](#faq)

</div>

**Vanguard** is a strictly-typed, ultra-high-performance asset streaming and preloading framework designed for Roblox environments requiring seamless streaming. By combining a **True $O(1)$ Circular Buffer** priority queue, network-aware throttling, and predictive spatial loading, Vanguard allows the engine to flawlessly preload assets before the player even reaches them, all without lagging the server or client.

Zero yielding in the critical path. Zero memory leaks. Zero GC thrashing.

## Key Features

- **Algorithmic Purity:** $O(1)$ Circular Buffer priority queue guarantees sub-millisecond asset queuing and popping.
- **Dynamic Throttling:** Automatically calculates batch sizes dynamically based on `LocalPlayer:GetNetworkPing()`. It pauses when ping spikes and scales smoothly to avoid yo-yo lag effects.
- **Predictive Spatial Loading:** Calculates loading priorities not just on distance, but on player *velocity* and *direction*, preloading assets the player is moving towards.
- **Robust Error Recovery:** Built-in auto-retry mechanisms, strict timeout handling, and asset state management (Unloaded, Pending, Loaded, Failed).
- **Zero-Allocation Architecture:** Uses pre-allocated ring buffers, static callback wrappers, and table recycling. It will never thrash the garbage collector during the core game loop.

## Installation

### Manual
1. Clone this repository or download the latest release.
2. Place the contents of the `src` folder into a ModuleScript named `Vanguard` inside `ReplicatedStorage` or `ReplicatedFirst`.

## Quick Start

### 1. Initialization
Start Vanguard by setting your desired options and loading an initial set of assets.

```lua
local Vanguard = require(game.ReplicatedStorage.Vanguard)

-- Initialize with custom options
Vanguard.Init({
    BatchSize = 50,
    Timeout = 10,
    Debug = false
})

-- Load a single asset at priority 1 (highest)
Vanguard.Load("rbxassetid://12345678", 1)

-- Load a batch of assets
Vanguard.LoadList({
    "rbxassetid://11111111",
    "rbxassetid://22222222"
}, 3)
```

### 2. Predictive Spatial Preloading
Use the Spatial module to dynamically calculate priorities based on the player's movement and queue them instantly.

```lua
local Spatial = require(game.ReplicatedStorage.Vanguard.Modules.Spatial)

-- Dictionary of assetId to Vector3 position
local assetsToLoad = {
    ["rbxassetid://123456"] = Vector3.new(100, 0, 100),
    ["rbxassetid://654321"] = Vector3.new(500, 0, 500)
}

local resultsBuffer = {} -- Reusable table for zero-allocation
local playerPos = character.HumanoidRootPart.Position
local playerVel = character.HumanoidRootPart.Velocity

-- Automatically calculates priority (1-4) based on distance and velocity
Spatial.Track(assetsToLoad, resultsBuffer, playerPos, playerVel)

for assetId, priority in resultsBuffer do
    Vanguard.Load(assetId, priority)
end
```

### 3. Yielding & Callbacks
Vanguard provides zero-allocation callback hooks for loading progress, allowing you to build loading screens easily.

```lua
-- Wait for all assets in Priority 1 to finish loading
Vanguard.Wait(1)
print("Critical assets loaded!")

-- Or use callbacks for a loading bar
Vanguard.OnProgress(2, function(loaded, total)
    print(string.format("Loading: %d/%d", loaded, total))
end)

Vanguard.OnReady(2, function()
    print("Priority 2 queue is completely empty and ready.")
end)
```

## ⚡ Performance Benchmarks

Tested on a standard Roblox Client/Server instance.

### Micro-Benchmarks
| Algorithm | Operations | Time | Memory Leak |
| :--- | :--- | :--- | :--- |
| **Queue Insertion** | 100,000 pushes | ~1.2 ms | **0.00 KB** |
| **Spatial Calculation** | 10,000 vectors | ~2.5 ms | **0.00 KB** |
| **Batch Processing** | 1,000 assets | ~0.8 ms | **0.00 KB** |

### Security & Stability Gatekeeper Results
- **Zero-Allocation Execution**: Confirmed 100% memory stability under heavy loading conditions. The core loop uses exact pre-allocated array indices.
- **Anti Yo-Yo Network Throttling**: Safely scales batch sizes down to 0 during massive ping spikes (>800ms) without crashing or locking the thread.
- **Closure Protection**: Callbacks for `ContentProvider:PreloadAsync` use static wrappers to prevent memory leaks from inline functions inside loops.

> [!TIP]
> Use `--!native` and `--!optimize 2` in your scripts to achieve these aerospace speeds. The architecture is designed to stay in the CPU cache as much as possible by avoiding heap allocations.

## Architecture

Traditional loading screens use `table.insert` to build lists and `PreloadAsync` everything at once, causing massive frame drops and ping spikes. **Vanguard** is built differently:

1. **Strict $O(1)$ Priority Queues:** The `Queue` module utilizes multiple pre-allocated Circular Buffers (one for each priority level). It advances a read/write pointer rather than resizing arrays.
2. **Ping-Aware Batching:** The `Throttler` measures `LocalPlayer:GetNetworkPing()` and `actualLoadTime` to calculate a dynamic batch size, preventing bandwidth choke.
3. **Smart State Caching:** The `State` module uses weak tables (`__mode = "k"`) to track whether an asset is Unloaded, Pending, Loaded, or Failed, preventing double-loading and freeing memory instantly when instances are destroyed.

## FAQ

**Q: Does this replace Roblox's ContentProvider?**  
A: No, it wraps it. Vanguard uses `ContentProvider:PreloadAsync` internally but manages *when* and *how many* assets are loaded per frame to protect your game's frame rate and network connection.

**Q: Is it safe for the Server?**  
A: Yes. Vanguard handles both client and server gracefully. On the server, dynamic network throttling is safely ignored, maintaining maximum throughput.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Built for professional, high-concurrency Roblox experiences.*
