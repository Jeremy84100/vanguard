--!strict
local HttpService = game:GetService("HttpService")
local State = {}
local AssetStatus = SharedTable.new()

State.InstanceRegistry = {}
setmetatable(State.InstanceRegistry, { __mode = "k" })

-- 0: Unloaded, 1: Pending, 2: Loaded, 3: Failed
function State.Get(asset: any): number
	local assetKey = asset
	if typeof(asset) == "Instance" then
		assetKey = State.InstanceRegistry[asset]
		if not assetKey then return 0 end
	end
	return AssetStatus[assetKey] or 0
end

function State.Set(asset: any, status: number)
	local assetKey = asset
	if typeof(asset) == "Instance" then
		assetKey = State.InstanceRegistry[asset]
		if not assetKey then
			assetKey = "inst_" .. HttpService:GenerateGUID(false)
			State.InstanceRegistry[asset] = assetKey
		end
		if status > 1 then
			State.InstanceRegistry[asset] = nil
		end
	end
	AssetStatus[assetKey] = status
end

return State
