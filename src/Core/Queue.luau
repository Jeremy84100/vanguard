--!strict
local HttpService = game:GetService("HttpService")
local Queue = {}
local Queues = SharedTable.new()
Queues[1] = SharedTable.new()
Queues[2] = SharedTable.new()
Queues[3] = SharedTable.new()
Queues[4] = SharedTable.new()

local Pointers = SharedTable.new()
for i = 1, 4 do
	local ptr = SharedTable.new()
	ptr.Head = 1
	ptr.Tail = 1
	Pointers[i] = ptr
end

Queue.InstanceRegistry = {} -- Main thread only

local TotalPushed = { 0, 0, 0, 0 }
local TotalLoaded = { 0, 0, 0, 0 }

function Queue.Push(priority: number, asset: any)
	local p = priority
	local tail = Pointers[p].Tail
	
	local assetKey = asset
	if typeof(asset) == "Instance" then
		assetKey = "inst_" .. HttpService:GenerateGUID(false)
		Queue.InstanceRegistry[assetKey] = asset
	end

	Queues[p][tail] = assetKey
	Pointers[p].Tail = tail + 1
	TotalPushed[priority] += 1
end

function Queue.Pop(priority: number): any?
	local p = priority
	local head = Pointers[p].Head
	if head == Pointers[p].Tail then return nil end
	
	local assetKey = Queues[p][head]
	Queues[p][head] = nil -- Free memory
	Pointers[p].Head = head + 1
	
	if type(assetKey) == "string" and string.sub(assetKey, 1, 5) == "inst_" then
		local instance = Queue.InstanceRegistry[assetKey]
		Queue.InstanceRegistry[assetKey] = nil -- Free registry
		return instance
	end

	return assetKey
end

function Queue.IsEmpty(priority: number): boolean
	return Pointers[priority].Head == Pointers[priority].Tail
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
	Pointers[priority].Head = Pointers[priority].Tail
	SharedTable.clear(Queues[priority])
end

function Queue.GetRingBuffer(priority: number)
	return Queues[priority]
end

return Queue
