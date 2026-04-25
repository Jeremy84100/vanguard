local Worker = require(game.ReplicatedStorage.Vanguard.Core.Worker)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

describe("Worker Thread", function()
	it("should expose Start and Pause APIs", function()
		expect(type(Worker.Start)).toBe("function")
		expect(type(Worker.Pause)).toBe("function")
	end)

	it("should allow configuring batch size and timeout", function()
		expect(type(Worker.SetBatchSize)).toBe("function")
		expect(type(Worker.SetTimeout)).toBe("function")
		
		-- Simple test that they don't crash
		Worker.SetBatchSize(100)
		Worker.SetTimeout(5)
	end)

	it("should register and unregister callbacks with unique incrementing IDs", function()
		local id1 = Worker.RegisterOnReady(1, function() end)
		local id2 = Worker.RegisterOnReady(1, function() end)
		
		expect(id1).toBeDefined()
		expect(id2).toBeGreaterThan(id1)
		
		Worker.UnregisterOnReady(1, id1)
		Worker.UnregisterOnReady(1, id2)
	end)
end)
