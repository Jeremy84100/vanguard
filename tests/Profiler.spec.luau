local Profiler = require(game.ReplicatedStorage.Vanguard.Modules.Profiler)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

describe("Bottleneck Profiler", function()
	it("should track and report slow assets", function()
		Profiler.Clear()
		Profiler.Record(12345, 1.5)
		Profiler.Record(67890, 0.1)
		
		-- 🛡️ CORRECTION : On fournit un buffer externe (Zéro-Allocation oblige !)
		local buffer = {}
		Profiler.GetTopSlowest(1, buffer)
		
		-- 🛡️ CORRECTION : Profiler convertit les nombres en strings ("12345")
		expect(buffer[1].id).toBe("12345")
	end)

	it("should wrap around the buffer after 1000 items", function()
		Profiler.Clear()
		for i = 1, 1005 do
			Profiler.Record("Asset_" .. i, 0.1)
		end
		
		-- 🛡️ CORRECTION : On demande les 2000 plus lents pour vérifier qu'il en reste bien que 1000
		local buffer = {}
		Profiler.GetTopSlowest(2000, buffer)
		expect(#buffer).toBe(1000)
	end)

	it("should clear properly", function()
		Profiler.Record("Test", 1.0)
		Profiler.Clear()
		
		local buffer = {}
		Profiler.GetTopSlowest(10, buffer)
		
		-- 🛡️ CORRECTION : Vérifie que le buffer est totalement vide
		expect(next(buffer)).toBeNil()
	end)
end)
