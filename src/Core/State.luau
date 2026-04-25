--!strict
local HttpService = game:GetService("HttpService")
local State = {}
local AssetStatus = SharedTable.new()

State.InstanceRegistry = {}
-- Les Clés Faibles (__mode = "k") s'occupent du nettoyage de la mémoire automatiquement
-- quand l'Instance est détruite par le jeu. On ne doit pas le faire manuellement.
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
	end
	
	-- Optimisation RAM : Si le statut est 0 (Annulé/Unloaded), on libère la SharedTable
	if status == 0 then
		AssetStatus[assetKey] = nil
	else
		AssetStatus[assetKey] = status
	end
end

return State
