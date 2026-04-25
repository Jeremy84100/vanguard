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
