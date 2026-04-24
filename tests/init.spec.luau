local Vanguard = require(game.ReplicatedStorage.Vanguard)

return function()
    describe("Vanguard API", function()
        it("should parse correctly", function()
            expect(type(Vanguard.Load)).to.equal("function")
        end)
    end)
end
