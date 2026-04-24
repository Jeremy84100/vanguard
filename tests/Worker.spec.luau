local Worker = require(game.ReplicatedStorage.Vanguard.Core.Worker)

return function()
	describe("Worker Thread", function()
		it("should exist and expose Start", function()
			expect(type(Worker.Start)).to.equal("function")
		end)
	end)
end
