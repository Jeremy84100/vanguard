--!strict
--!native
--!optimize 2

local State = {}
local AssetStatus: { [any]: number } = {}
setmetatable(AssetStatus, { __mode = "k" })

-- 0: Unloaded, 1: Pending, 2: Loaded, 3: Failed
function State.Get(asset: any): number
	return AssetStatus[asset] or 0
end

function State.Set(asset: any, status: number)
	-- Free table entries for status 0 to reduce dictionary memory footprint
	if status == 0 then
		AssetStatus[asset] = nil
	else
		AssetStatus[asset] = status
	end
end

function State.Clear(asset: any)
	AssetStatus[asset] = nil
end

return State