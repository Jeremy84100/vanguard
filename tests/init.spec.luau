local Vanguard = require(game.ReplicatedStorage.Vanguard)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

describe("Vanguard API", function()
	describe("Asset Auto-Formatting", function()
		it("should format raw numbers to rbxassetid", function()
			-- We have to spy or check state to see what it loaded, but wait!
			-- The FormatAsset function is internal. Let's test the side effects using GetStatus.
			Vanguard.Load(12345, 1)
			expect(Vanguard.GetStatus("rbxassetid://12345")).toBe(1)
		end)

		it("should format string numbers to rbxassetid", function()
			Vanguard.Load("67890", 1)
			expect(Vanguard.GetStatus("rbxassetid://67890")).toBe(1)
		end)

		it("should preserve custom URLs", function()
			Vanguard.Load("http://mycustomasset.com/1", 1)
			expect(Vanguard.GetStatus("http://mycustomasset.com/1")).toBe(1)
		end)

		it("should safely ignore bad input", function()
			Vanguard.Load(nil, 1)
			Vanguard.Load(true, 1)
			-- shouldn't crash
		end)
	end)

	describe("Deduplication & Cancellation", function()
		it("should cancel a pending asset", function()
			Vanguard.Load(999, 1)
			expect(Vanguard.GetStatus(999)).toBe(1)
			Vanguard.Cancel(999)
			expect(Vanguard.GetStatus(999)).toBe(0)
		end)
	end)

	describe("Resilience & Edge Cases", function()
		it("should clamp invalid priorities to bounds", function()
			Vanguard.Load(111, 5) -- Should clamp to 4
			expect(Vanguard.GetStatus(111)).toBe(1)
			
			Vanguard.Load(222, -1) -- Should clamp to 1
			expect(Vanguard.GetStatus(222)).toBe(1)
		end)

		it("should register callbacks without crashing", function()
			Vanguard.OnProgress(1, function(loaded, total) end)
			Vanguard.OnReady(1, function() end)
			Vanguard.OnFailed(1, function() end)
		end)

		it("should wait without infinite hanging if queue is empty", function()
			Vanguard.ClearQueue(1)
			Vanguard.Wait(1) -- Should return instantly
		end)
	end)
end)
