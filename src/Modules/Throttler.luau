--!strict
local Players = game:GetService("Players")
local Throttler = {}
local TARGET_TIME = 0.5

-- Safe for server environments via LocalPlayer check
function Throttler.CalculateBatchSize(currentBatchSize: number, actualLoadTime: number): number
	if Players.LocalPlayer then
		local ping = Players.LocalPlayer:GetNetworkPing()
		if ping > 0.8 then
			return 0
		end
	end

	if actualLoadTime <= 0.01 then actualLoadTime = 0.01 end
	
	-- Clamp the ratio to smooth out variations and prevent lag spikes
	local rawRatio = TARGET_TIME / actualLoadTime
	local smoothedRatio = math.clamp(rawRatio, 0.5, 1.5)
	
	local newSize = math.floor(currentBatchSize * smoothedRatio)
	
	return math.clamp(newSize, 5, 100)
end

return Throttler
