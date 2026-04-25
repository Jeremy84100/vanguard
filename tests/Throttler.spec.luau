local Throttler = require(game.ReplicatedStorage.Vanguard.Modules.Throttler)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

describe("Dynamic Throttler", function()
	it("should reduce batch size on slow load times with smoothing", function()
		-- Target is 0.5s. If actual is 2.5s, rawRatio is 0.2.
		-- SmoothedRatio should be clamped to 0.5.
		-- 50 * 0.5 = 25.
		local newSize = Throttler.CalculateBatchSize(50, 2.5)
		expect(newSize).toBe(25)
	end)

	it("should increase batch size on fast load times with smoothing", function()
		-- Target is 0.5s. If actual is 0.01s, rawRatio is 50.
		-- SmoothedRatio should be clamped to 1.5.
		-- 50 * 1.5 = 75.
		local newSize = Throttler.CalculateBatchSize(50, 0.01)
		expect(newSize).toBe(75)
	end)

	it("should respect absolute limits (5-100)", function()
		-- Extremely slow: ratio 0.5 -> 5 * 0.5 = 2.5 -> clamped to 5
		expect(Throttler.CalculateBatchSize(5, 5.0)).toBe(5)
		
		-- Extremely fast: ratio 1.5 -> 100 * 1.5 = 150 -> clamped to 100
		expect(Throttler.CalculateBatchSize(100, 0.01)).toBe(100)
	end)
end)
