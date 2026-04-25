--!strict
local Players = game:GetService("Players")
local Throttler = {}
local TARGET_TIME = 0.5

function Throttler.CalculateBatchSize(currentBatchSize: number, actualLoadTime: number): number
	if Players.LocalPlayer then
		local ping = Players.LocalPlayer:GetNetworkPing()
		if ping > 0.8 then -- 800 ms threshold
			return 0 -- Instructs Vanguard to pause/skip
		end
	end

	if actualLoadTime <= 0.01 then actualLoadTime = 0.01 end
	local ratio = TARGET_TIME / actualLoadTime
	local newSize = math.floor(currentBatchSize * ratio)
	return math.clamp(newSize, 5, 100)
end

function Throttler.GetAssetWeight(asset: any): number
	if typeof(asset) == "Instance" then
		if asset:IsA("MeshPart") then return 10 end
		if asset:IsA("ImageLabel") then return 2 end
	end
	return 1
end

return Throttler
