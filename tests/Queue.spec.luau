local Queue = require(game.ReplicatedStorage.Vanguard.Core.Queue)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

describe("Queue Manager", function()
		it("should push and pop without reallocation", function()
			Queue.Push(1, "rbxassetid://A")
			local asset = Queue.Pop(1)
			expect(asset).toBe("rbxassetid://A")
			expect(Queue.Pop(1)).toBeNil()
		end)
	end)
