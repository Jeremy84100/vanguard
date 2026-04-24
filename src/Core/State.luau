--!strict
local State = {}
local AssetStatus: { [any]: number } = {}
setmetatable(AssetStatus, { __mode = "k" }) -- Anti-Memory Leak for Instances

-- 0: Unloaded, 1: Pending, 2: Loaded, 3: Failed
function State.Get(asset: any): number
	return AssetStatus[asset] or 0
end

function State.Set(asset: any, status: number)
	AssetStatus[asset] = status
end

return State
