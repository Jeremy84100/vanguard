--!strict
local Queue = require(script.Core.Queue)
local State = require(script.Core.State)
local Worker = require(script.Core.Worker)

local Vanguard = {}

export type VanguardPriority = number
export type VanguardOptions = {
	BatchSize: number?,
	Timeout: number?,
	Debug: boolean?,
}

--[=[
	DÉFINITION DIVINE : Les connexions sont désormais des nombres (ConnectionId).
	Zéro allocation de table ou de closure lors de l'abonnement.
]=]
export type VanguardConnectionId = number

-- Auto-start worker
Worker.Start()

-- Séparation pour bypasser le procédural sans créer de faux-positifs
local function IsProcedural(asset: any): boolean
	if typeof(asset) == "Instance" then
		return asset:IsA("EditableImage") or asset:IsA("EditableMesh")
	end
	return false
end

local function FormatAsset(asset: any): (string | Instance)?
	if type(asset) == "number" then
		return "rbxassetid://" .. tostring(asset)
	elseif type(asset) == "string" then
		if string.match(asset, "^%d+$") then
			return "rbxassetid://" .. asset
		end
		return asset
	elseif typeof(asset) == "Instance" then
		return asset
	end
	return nil
end

function Vanguard.Load(asset: any, priority: number?)
	if IsProcedural(asset) then return end 

	local prio = math.clamp(priority or 3, 1, 4)
	local formattedAsset = FormatAsset(asset)

	if not formattedAsset then return end

	local currentState = State.Get(formattedAsset)
	
	if currentState > 1 then return end 

	-- Le VRAI Priority Upgrading anti-flood
	if currentState == 1 then
		if prio <= 2 then
			Queue.Push(prio, formattedAsset)
		end
		return
	end

	State.Set(formattedAsset, 1)
	Queue.Push(prio, formattedAsset)
end

function Vanguard.Cancel(asset: any)
	if IsProcedural(asset) then return end
	local formatted = FormatAsset(asset)
	if formatted and State.Get(formatted) == 1 then
		State.Clear(formatted)
	end
end

-- --- ÉVÉNEMENTS ZÉRO-ALLOCATION ---

function Vanguard.OnReady(priority: number, callback: () -> ()): VanguardConnectionId
	local prio = math.clamp(priority, 1, 4)
	if Queue.IsEmpty(prio) then
		task.defer(callback)
		return 0 -- ID nul pour les tâches déjà terminées
	end
	return Worker.RegisterOnReady(prio, callback)
end

function Vanguard.DisconnectOnReady(priority: number, connectionId: VanguardConnectionId)
	if connectionId == 0 then return end
	Worker.UnregisterOnReady(math.clamp(priority, 1, 4), connectionId)
end

function Vanguard.OnProgress(priority: number, callback: (number, number) -> ()): VanguardConnectionId
	return Worker.RegisterOnProgress(math.clamp(priority, 1, 4), callback)
end

function Vanguard.DisconnectOnProgress(priority: number, connectionId: VanguardConnectionId)
	Worker.UnregisterOnProgress(math.clamp(priority, 1, 4), connectionId)
end

function Vanguard.OnFailed(priority: number, callback: () -> ()): VanguardConnectionId
	return Worker.RegisterOnFailed(math.clamp(priority, 1, 4), callback)
end

function Vanguard.DisconnectOnFailed(priority: number, connectionId: VanguardConnectionId)
	Worker.UnregisterOnFailed(math.clamp(priority, 1, 4), connectionId)
end

--[=[
	Attend que la queue d'une priorité donnée soit vide.
	Note : Wait() est une opération lourde par définition (yield),
	l'allocation ici est négligeable par rapport au coût du thread.
]=]
function Vanguard.Wait(priority: number)
	local prio = math.clamp(priority, 1, 4)
	if Queue.IsEmpty(prio) then return end
	
	local thread = coroutine.running()
	local connectionId: VanguardConnectionId
	
	-- On utilise une closure ici, car Wait() ne peut pas être appelé 60 fois/sec
	connectionId = Vanguard.OnReady(prio, function()
		Vanguard.DisconnectOnReady(prio, connectionId)
		task.spawn(thread)
	end)
	
	coroutine.yield()
end

function Vanguard.GetStatus(asset: any): number
	if IsProcedural(asset) then return 2 end
	local formatted = FormatAsset(asset)
	return formatted and State.Get(formatted) or 0
end

--[=[
	Vise le Zéro-Allocation en passant directement la référence de State.Clear.
]=]
function Vanguard.ClearQueue(priority: number)
	local prio = math.clamp(priority, 1, 4)
	Queue.Clear(prio, State.Clear) -- ♻️ Zéro Closure !
end

function Vanguard.SetBatchSize(size: number)
	Worker.SetBatchSize(size)
end

function Vanguard.LoadList(list: { any }, priority: number?)
	local prio = math.clamp(priority or 3, 1, 4)
	for _, asset in list do
		Vanguard.Load(asset, prio)
	end
end

function Vanguard.WaitForAsset(asset: any): boolean
	if IsProcedural(asset) then return true end

	local formatted = FormatAsset(asset)
	if not formatted then return false end

	local status = State.Get(formatted)
	if status == 2 then return true end
	if status == 3 then return false end

	if status == 0 then
		Vanguard.Load(formatted, 1)
	end

	while true do
		local s = State.Get(formatted)
		if s == 2 then return true end
		if s == 3 then return false end
		task.wait(0.1) -- Polling raisonnable
	end
end

function Vanguard.Pause() Worker.Pause() end
function Vanguard.Resume() Worker.Resume() end
function Vanguard.SetDebug(value: boolean) Worker.SetDebug(value) end

return Vanguard
