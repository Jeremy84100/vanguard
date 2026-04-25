--!strict
local Spatial = {}

--[=[
	Calcule la priorité d'un asset en fonction de la distance et de la vélocité.
	Plus l'objet est proche ou s'approche rapidement, plus la priorité est haute (1).
]=]
function Spatial.CalculatePriority(origin: Vector3, velocity: Vector3, target: Vector3): number
	local distance = (target - origin).Magnitude
	local direction = (target - origin).Unit
	local speed = velocity.Magnitude
	
	-- Predictive loading: si on fonce vers l'objet, on réduit artificiellement la distance perçue
	if speed > 10 then
		local dotProduct = velocity.Unit:Dot(direction)
		if dotProduct > 0.5 then
			distance = math.max(0, distance - (speed * dotProduct))
		end
	end
	
	if distance < 100 then return 1
	elseif distance < 250 then return 2
	elseif distance < 500 then return 3
	else return 4 end
end

--[=[
	Exemple de traitement spatial en parallèle.
	@param resultsBuffer Une table fournie par l'appelant qui sera recyclée (Zéro-Allocation).
]=]
function Spatial.Track(assets: { [any]: Vector3 }, resultsBuffer: { [any]: number }, origin: Vector3, velocity: Vector3)
	task.desynchronize() -- Passage en mode Parallèle
	
	table.clear(resultsBuffer) -- ♻️ Recyclage de la table fournie
	
	for assetId, pos in assets do
		resultsBuffer[assetId] = Spatial.CalculatePriority(origin, velocity, pos)
	end
	
	task.synchronize() -- Retour en mode Serial
end

return Spatial
