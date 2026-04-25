local Queue = require(game.ReplicatedStorage.Vanguard.Core.Queue)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

describe("Queue Manager", function()
	it("should independently manage 4 priorities", function()
		Queue.Push(1, "Critical")
		Queue.Push(4, "Background")

		expect(Queue.IsEmpty(1)).toBe(false)
		expect(Queue.IsEmpty(4)).toBe(false)
		expect(Queue.IsEmpty(2)).toBe(true)
		expect(Queue.IsEmpty(3)).toBe(true)

		expect(Queue.Pop(1)).toBe("Critical")
		expect(Queue.Pop(4)).toBe("Background")
	end)

	it("should wrap around the Ring Buffer correctly", function()
		Queue.Clear(1)
		for i = 1, 1005 do
			Queue.Push(1, "Asset_" .. i)
			local asset = Queue.Pop(1)
			expect(asset).toBe("Asset_" .. i)
		end
		expect(Queue.IsEmpty(1)).toBe(true)
	end)

	it("should calculate progress accurately", function()
		Queue.ResetTracking(1)
		Queue.Push(1, "A")
		Queue.Push(1, "B")
		Queue.AddLoaded(1, 1)

		local loaded, total = Queue.GetProgress(1)
		expect(loaded).toBe(1)
		expect(total).toBe(2)
	end)

	it("should clear properly", function()
		Queue.Push(1, "Z")
		Queue.Clear(1)
		expect(Queue.IsEmpty(1)).toBe(true)
		expect(Queue.Pop(1)).toBeNil()
	end)

	it("should return false on overflow", function()
		Queue.Clear(1)
		for i = 1, 999 do
			expect(Queue.Push(1, "Asset_" .. i)).toBe(true)
		end
		expect(Queue.Push(1, "Asset_Overflow")).toBe(false)
	end)

	it("should execute callback during Clear", function()
		-- 🛡️ CORRECTION : On nettoie les déchets du test d'Overflow précédent !
		Queue.Clear(1) 
		
		local cleared = {}
		Queue.Push(1, "Asset_ToClear")
		
		Queue.Clear(1, function(asset)
			table.insert(cleared, asset)
		end)
		
		expect(#cleared).toBe(1)
		expect(cleared[1]).toBe("Asset_ToClear")
	end)
end)
