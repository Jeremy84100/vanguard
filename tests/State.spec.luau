local State = require(game.ReplicatedStorage.Vanguard.Core.State)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

return function()
	describe("State Manager", function()
		it("should track asset status", function()
			expect(State.Get("rbxassetid://1")).toBe(0)
			State.Set("rbxassetid://1", 1)
			expect(State.Get("rbxassetid://1")).toBe(1)
		end)
	end)
end
