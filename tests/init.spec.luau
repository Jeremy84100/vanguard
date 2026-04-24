local Vanguard = require(game.ReplicatedStorage.Vanguard)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

return function()
	describe("Vanguard API", function()
		it("should parse correctly", function()
			expect(type(Vanguard.Load)).toBe("function")
		end)
	end)
end
