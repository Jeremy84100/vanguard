local Spatial = require(game.ReplicatedStorage.Vanguard.Modules.Spatial)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

describe("Spatial Module", function()
	it("should calculate priority based on distance and velocity", function()
		local origin = Vector3.new(0, 0, 0)
		local target = Vector3.new(0, 0, 100)
		local speed = 50
		local velocityUnit = Vector3.new(0, 0, 1)
		
		local priority = Spatial.CalculatePriority(origin, target, speed, velocityUnit)
		expect(priority).toBe(1)
	end)

	it("should handle Vector3.zero and zero distance safely (NaN protection)", function()
		local origin = Vector3.new(0, 0, 0)
		local target = Vector3.new(0, 0, 0) -- distance = 0
		local speed = 0 -- speed = 0
		local velocityUnit = Vector3.new(0, 0, 0) -- unit = 0
		
		-- Should not crash and return priority 1 (distance 0 < 100)
		local priority = Spatial.CalculatePriority(origin, target, speed, velocityUnit)
		expect(priority).toBe(1)
	end)
end)
