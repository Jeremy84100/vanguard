--!strict
--!native
--!optimize 2

local Spatial = {}

-- Declared locally to allow the Luau compiler to inline it inside the loop
local function CalculatePriority(origin: Vector3, target: Vector3, speed: number, velocityUnit: Vector3): number
	local diff = target - origin
	local distance = diff.Magnitude
	
	if speed > 10 and distance > 0.001 then
		-- Optimize by using scalar multiplication instead of vector division
		local invDistance = 1 / distance
		local direction = diff * invDistance 
		
		local dotProduct = velocityUnit:Dot(direction)
		
		if dotProduct > 0.5 then
			local newDistance = distance - (speed * dotProduct)
			distance = if newDistance > 0 then newDistance else 0
		end
	end
	
	if distance < 100 then return 1
	elseif distance < 250 then return 2
	elseif distance < 500 then return 3
	else return 4 end
end

Spatial.CalculatePriority = CalculatePriority

function Spatial.Track(assets: { [any]: Vector3 }, resultsBuffer: { [any]: number }, origin: Vector3, velocity: Vector3)
	table.clear(resultsBuffer) 
	
	local speed = velocity.Magnitude
	local velocityUnit = Vector3.zero
	if speed > 0.001 then
		velocityUnit = velocity * (1 / speed)
	end
	
	for assetId, pos in assets do
		resultsBuffer[assetId] = CalculatePriority(origin, pos, speed, velocityUnit)
	end
end

return Spatial
