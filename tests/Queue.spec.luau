local Queue = require(game.ReplicatedStorage.Vanguard.Core.Queue)

return function()
	describe("Queue Manager", function()
		it("should push and pop without reallocation", function()
			Queue.Push(1, "rbxassetid://A")
			local asset = Queue.Pop(1)
			expect(asset).to.equal("rbxassetid://A")
			expect(Queue.Pop(1)).to.equal(nil)
		end)
	end)
end
