local State = require(game.ReplicatedStorage.Vanguard.Core.State)

return function()
    describe("State Manager", function()
        it("should track asset status", function()
            expect(State.Get("rbxassetid://1")).to.equal(0)
            State.Set("rbxassetid://1", 1)
            expect(State.Get("rbxassetid://1")).to.equal(1)
        end)
    end)
end
