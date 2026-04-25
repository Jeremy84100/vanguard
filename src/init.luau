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

-- Auto-start worker
Worker.Start()

local function FormatAsset(asset: any): any
	if type(asset) == "number" then
		return "rbxassetid://" .. tostring(asset)
	elseif type(asset) == "string" then
		if string.match(asset, "^%d+$") then
			return "rbxassetid://" .. asset
		end
		return asset
	elseif typeof(asset) == "Instance" then
		if asset:IsA("EditableImage") or asset:IsA("EditableMesh") then
			return nil
		end
		return asset
	end
	return nil
end

function Vanguard.Load(asset: any, priority: number?)
	local prio = math.clamp(priority or 3, 1, 4)
	local formattedAsset = FormatAsset(asset)

	-- Anti-Crash & Silent Skip
	if not formattedAsset then
		return
	end

	local currentState = State.Get(formattedAsset)
	if currentState > 1 then
		return
	end -- Already Loaded(2) or Failed(3)

	-- Priority Upgrading & Initial Push (Lazy Deletion handles duplicates)
	State.Set(formattedAsset, 1) -- Set Pending
	Queue.Push(prio, formattedAsset)
end

function Vanguard.Cancel(asset: any)
	local formatted = FormatAsset(asset)
	if formatted and State.Get(formatted) == 1 then
		State.Set(formatted, 0)
	end
end

function Vanguard.OnReady(priority: number, callback: () -> ())
	local prio = math.clamp(priority, 1, 4)
	if Queue.IsEmpty(prio) then
		task.defer(callback)
	else
		Worker.RegisterOnReady(prio, callback)
	end
end

function Vanguard.OnProgress(priority: number, callback: (number, number) -> ())
	Worker.RegisterOnProgress(math.clamp(priority, 1, 4), callback)
end

function Vanguard.OnFailed(priority: number, callback: () -> ())
	Worker.RegisterOnFailed(math.clamp(priority, 1, 4), callback)
end

function Vanguard.Wait(priority: number)
	local prio = math.clamp(priority, 1, 4)
	if Queue.IsEmpty(prio) then
		return
	end
	local thread = coroutine.running()
	Vanguard.OnReady(prio, function()
		task.defer(thread)
	end)
	coroutine.yield()
end

function Vanguard.GetStatus(asset: any): number
	local formatted = FormatAsset(asset)
	return formatted and State.Get(formatted) or 0
end

function Vanguard.ClearQueue(priority: number)
	Queue.Clear(math.clamp(priority, 1, 4))
end

function Vanguard.SetBatchSize(size: number)
	Worker.SetBatchSize(size)
end

function Vanguard.LoadList(list: { any }, priority: number?)
	local prio = math.clamp(priority or 3, 1, 4)
	for _, asset in ipairs(list) do
		Vanguard.Load(asset, prio)
	end
end

function Vanguard.WaitForAsset(asset: any): boolean
	local formatted = FormatAsset(asset)
	if not formatted then
		return false
	end

	local status = State.Get(formatted)
	if status == 2 then
		return true
	end
	if status == 3 then
		return false
	end

	if status == 0 then
		Vanguard.Load(formatted, 1)
	end

	while true do
		local s = State.Get(formatted)
		if s == 2 then
			return true
		end
		if s == 3 then
			return false
		end
		task.wait()
	end
end

function Vanguard.Pause()
	Worker.Pause()
end
function Vanguard.Resume()
	Worker.Resume()
end
function Vanguard.SetDebug(value: boolean)
	Worker.SetDebug(value)
end

return Vanguard
