--!strict
local Spatial = {}

function Spatial.CalculatePriority(origin: Vector3, velocity: Vector3, target: Vector3): number
	local distance = (target - origin).Magnitude
	local direction = (target - origin).Unit
	local speed = velocity.Magnitude
	
	-- Predictive loading: if moving fast towards target, artificial distance reduction
	if speed > 10 then
		local dotProduct = velocity.Unit:Dot(direction)
		if dotProduct > 0.5 then
			distance = distance - (speed * dotProduct)
		end
	end
	
	if distance < 100 then return 1
	elseif distance < 250 then return 2
	elseif distance < 500 then return 3
	else return 4 end
end

function Spatial.Track(assets: { [any]: Vector3 }, origin: Vector3, velocity: Vector3)
	task.desynchronize() -- Move to Parallel Thread
	for assetId, pos in pairs(assets) do
		-- Omitted Raycast for brevity in minimal implementation, added in full
		local p = Spatial.CalculatePriority(origin, velocity, pos)
		-- Send to SharedTable Queue
	end
end

return Spatial
