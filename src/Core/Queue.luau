--!strict
--!native
--!optimize 2

local Queue = {}
local Capacities = { 1000, 2000, 5000, 5000 }
local Queues = {
	[1] = table.create(Capacities[1]), -- Critical
	[2] = table.create(Capacities[2]), -- High
	[3] = table.create(Capacities[3]), -- Normal
	[4] = table.create(Capacities[4]), -- Background
}

local WriteHeads = { 1, 1, 1, 1 }
local ReadHeads = { 1, 1, 1, 1 }
local TotalPushed = { 0, 0, 0, 0 }
local TotalLoaded = { 0, 0, 0, 0 }

function Queue.Push(priority: number, asset: any)
	local head = WriteHeads[priority]
	Queues[priority][head] = asset
	-- Modulo wrap-around for true Ring Buffer (1-based index)
	WriteHeads[priority] = (head % Capacities[priority]) + 1
	TotalPushed[priority] += 1
end

function Queue.Pop(priority: number): any
	local readHead = ReadHeads[priority]
	local writeHead = WriteHeads[priority]

	if readHead ~= writeHead then
		local asset = Queues[priority][readHead]
		Queues[priority][readHead] = nil -- Free reference for GC (Memory Leak prevention)
		ReadHeads[priority] = (readHead % Capacities[priority]) + 1
		return asset
	end
	return nil
end

function Queue.IsEmpty(priority: number): boolean
	return ReadHeads[priority] == WriteHeads[priority]
end

function Queue.AddLoaded(priority: number, count: number)
	TotalLoaded[priority] += count
end

function Queue.GetProgress(priority: number): (number, number)
	return TotalLoaded[priority], TotalPushed[priority]
end

function Queue.ResetTracking(priority: number)
	TotalPushed[priority] = 0
	TotalLoaded[priority] = 0
end

function Queue.Clear(priority: number)
	ReadHeads[priority] = WriteHeads[priority]
	table.clear(Queues[priority])
end

return Queue
