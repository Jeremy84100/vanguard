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

-- Connections are stored as numerical ConnectionIds to ensure zero-allocation subscriptions.
export type VanguardConnectionId = number

Worker.Start()

-- Bypass procedural assets to avoid false-positives during load
local function IsProcedural(asset: any): boolean
	-- Optimize by checking typeof before calling :IsA() to reduce C++ boundary calls
	if typeof(asset) ~= "Instance" then return false end
	
	return asset:IsA("EditableImage") or asset:IsA("EditableMesh")
end

local function FormatAsset(asset: any): (string | Instance)?
	local assetType = type(asset)
	
	if assetType == "number" then
		return "rbxassetid://" .. tostring(asset)
	elseif assetType == "string" then
		-- tonumber naturally ignores whitespace, avoiding string allocations
		if tonumber(asset) ~= nil then
			-- Strip whitespace for the final concatenation only if it's a valid number
			local id = string.match(asset, "%d+")
			if id then
				return "rbxassetid://" .. id
			end
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
	
	if currentState ~= 0 then return end 

	State.Set(formattedAsset, 1)
	if not Queue.Push(prio, formattedAsset) then
		State.Clear(formattedAsset)
	end
end

function Vanguard.Cancel(asset: any)
	if IsProcedural(asset) then return end
	local formatted = FormatAsset(asset)
	if formatted and State.Get(formatted) == 1 then
		State.Clear(formatted)
	end
end

function Vanguard.OnReady(priority: number, callback: () -> ()): VanguardConnectionId
	local prio = math.clamp(priority, 1, 4)
	if Queue.IsEmpty(prio) then
		task.spawn(callback)
		return -1
	end
	return Worker.RegisterOnReady(prio, callback)
end

function Vanguard.DisconnectOnReady(priority: number, connectionId: VanguardConnectionId)
	if not connectionId or connectionId <= 0 then return end
	Worker.UnregisterOnReady(math.clamp(priority, 1, 4), connectionId)
end

function Vanguard.OnProgress(priority: number, callback: (number, number) -> ()): VanguardConnectionId
	return Worker.RegisterOnProgress(math.clamp(priority, 1, 4), callback)
end

function Vanguard.DisconnectOnProgress(priority: number, connectionId: VanguardConnectionId)
	if not connectionId or connectionId <= 0 then return end
	Worker.UnregisterOnProgress(math.clamp(priority, 1, 4), connectionId)
end

function Vanguard.OnFailed(priority: number, callback: () -> ()): VanguardConnectionId
	return Worker.RegisterOnFailed(math.clamp(priority, 1, 4), callback)
end

function Vanguard.DisconnectOnFailed(priority: number, connectionId: VanguardConnectionId)
	if not connectionId or connectionId <= 0 then return end
	Worker.UnregisterOnFailed(math.clamp(priority, 1, 4), connectionId)
end

function Vanguard.Wait(priority: number)
	local prio = math.clamp(priority, 1, 4)
	if Queue.IsEmpty(prio) then return end
	
	local thread = coroutine.running()
	local connectionId = 0
	
	-- Closure allocation is acceptable here because Wait yields the thread
	connectionId = Vanguard.OnReady(prio, function()
		if connectionId and connectionId > 0 then
			Vanguard.DisconnectOnReady(prio, connectionId)
		end
		task.spawn(thread)
	end)
	
	-- Prevent deadlock if OnReady executes the callback synchronously
	if connectionId > 0 then
		coroutine.yield()
	end
end

function Vanguard.GetStatus(asset: any): number
	if IsProcedural(asset) then return 2 end
	local formatted = FormatAsset(asset)
	return formatted and State.Get(formatted) or 0
end

-- Passes the State.Clear reference directly to achieve zero-allocation.
function Vanguard.ClearQueue(priority: number)
	local prio = math.clamp(priority, 1, 4)
	Queue.Clear(prio, State.Clear)
end

function Vanguard.SetBatchSize(size: number)
	Worker.SetBatchSize(size)
end

function Vanguard.Init(options: VanguardOptions)
	if options.BatchSize then Vanguard.SetBatchSize(options.BatchSize) end
	if options.Timeout then Worker.SetTimeout(options.Timeout) end
	if options.Debug ~= nil then Vanguard.SetDebug(options.Debug) end
end

function Vanguard.LoadList(list: { any }, priority: number?)
	local prio = math.clamp(priority or 3, 1, 4)
	for i, asset in list do
		Vanguard.Load(asset, prio)
		if i % 1000 == 0 then task.wait() end
	end
end

function Vanguard.WaitForAsset(asset: any, timeout: number?): boolean
	if IsProcedural(asset) then return true end

	-- FormatAsset already verifies the type, avoiding double checks
	local formatted = FormatAsset(asset)
	if not formatted then return false end

	local status = State.Get(formatted)
	if status == 2 then return true end
	if status == 3 then return false end

	if status == 0 then
		Vanguard.Load(formatted, 1)
	end

	local timeWaited = 0
	local waitStep = 0.1
	local timeoutValue = timeout or math.huge

	while true do
		local s = State.Get(formatted)
		if s == 2 then return true end
		if s == 3 then return false end
		
		if timeWaited >= timeoutValue then
			warn("[Vanguard] WaitForAsset timeout for:", formatted)
			return false
		end
		
		timeWaited += task.wait(waitStep)
	end
end

function Vanguard.Pause() Worker.Pause() end
function Vanguard.Resume() Worker.Resume() end
function Vanguard.SetDebug(value: boolean) Worker.SetDebug(value) end

return Vanguard
