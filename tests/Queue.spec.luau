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
		-- Priority 1 capacity is 1000
		Queue.Clear(1)
		for i = 1, 1005 do
			Queue.Push(1, "Asset_" .. i)
			-- Constantly pop to keep space? Wait, pushing past 1000 without popping will overwrite unread data!
			-- But let's just push and pop sequentially 1500 times to verify modulo doesn't crash
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

	it("should use SharedTable for internal queue", function()
		-- Since Queue is supposed to be a SharedTable now or hold them
		expect(type(Queue.GetRingBuffer)).toBe("function")
		expect(typeof(Queue.GetRingBuffer(1))).toBe("SharedTable")
	end)
end)
