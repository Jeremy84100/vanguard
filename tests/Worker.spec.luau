local Worker = require(game.ReplicatedStorage.Vanguard.Core.Worker)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

return function()
	describe("Worker Thread", function()
		it("should exist and expose Start", function()
			expect(type(Worker.Start)).toBe("function")
		end)
	end)
end
