local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DevPackages = ReplicatedStorage:WaitForChild("DevPackages")
local VanguardTests = ReplicatedStorage:WaitForChild("VanguardTests")

local Jest = require(DevPackages.Jest)

print("🚀 Démarrage des tests Jest...")

Jest.runCLI(VanguardTests, {
	verbose = true,
	ci = false,
}, { VanguardTests }):awaitStatus()
