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

export type VanguardConnection = {
	Disconnect: (self: VanguardConnection) -> ()
}

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

function Vanguard.OnReady(priority: number, callback: () -> ()): VanguardConnection
	local prio = math.clamp(priority, 1, 4)
	if Queue.IsEmpty(prio) then
		task.defer(callback)
		-- Allocation minimale pour la compatibilité API
		return { Disconnect = function() end }
	else
		local id = Worker.RegisterOnReady(prio, callback)
		return {
			Disconnect = function()
				Worker.UnregisterOnReady(prio, id)
			end
		}
	end
end

function Vanguard.OnProgress(priority: number, callback: (number, number) -> ()): VanguardConnection
	local prio = math.clamp(priority, 1, 4)
	local id = Worker.RegisterOnProgress(prio, callback)
	return {
		Disconnect = function()
			Worker.UnregisterOnProgress(prio, id)
		end
	}
end

function Vanguard.OnFailed(priority: number, callback: () -> ()): VanguardConnection
	local prio = math.clamp(priority, 1, 4)
	local id = Worker.RegisterOnFailed(prio, callback)
	return {
		Disconnect = function()
			Worker.UnregisterOnFailed(prio, id)
		end
	}
end

--[=[
	Attend que la queue d'une priorité donnée soit vide.
]=]
function Vanguard.Wait(priority: number)
	local prio = math.clamp(priority, 1, 4)
	if Queue.IsEmpty(prio) then return end
	
	local thread = coroutine.running()
	local connection: VanguardConnection
	
	-- Note: Une closure est créée ici, mais Wait() étant une fonction bloquante,
	-- elle ne peut pas être appelée dans une boucle serrée de type 60 FPS sans bloquer le thread.
	connection = Vanguard.OnReady(prio, function()
		if connection then connection:Disconnect() end
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
