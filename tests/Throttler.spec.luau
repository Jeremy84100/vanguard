local Throttler = require(game.ReplicatedStorage.Vanguard.Modules.Throttler)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

describe("Dynamic Throttler", function()
	it("should reduce batch size on slow load times", function()
		local newSize = Throttler.CalculateBatchSize(50, 2.5) -- 2.5s is too long
		expect(newSize).toBeLessThan(50)
	end)
end)
