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
