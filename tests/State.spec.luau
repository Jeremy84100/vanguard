local State = require(game.ReplicatedStorage.Vanguard.Core.State)
local JestGlobals = require(game.ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

describe("State Manager", function()
	it("should initialize unknown assets to 0", function()
		expect(State.Get("rbxassetid://UNKNOWN")).toBe(0)
	end)

	it("should track asset status accurately", function()
		State.Set("rbxassetid://1", 1)
		expect(State.Get("rbxassetid://1")).toBe(1)
		
		State.Set("rbxassetid://1", 2)
		expect(State.Get("rbxassetid://1")).toBe(2)
	end)

	it("should safely accept Instances as keys (weak map)", function()
		local fakeInstance = Instance.new("Part")
		State.Set(fakeInstance, 1)
		expect(State.Get(fakeInstance)).toBe(1)
	end)

	it("should clear asset status with State.Clear", function()
		State.Set("TestAsset", 2)
		State.Clear("TestAsset")
		expect(State.Get("TestAsset")).toBe(0)
	end)
end)
