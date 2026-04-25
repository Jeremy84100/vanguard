--!strict
local Queue = {}
local Queues = { {}, {}, {}, {} } -- Tables normales pour une vitesse maximale (Serial Mode)

local MAX_QUEUE_SIZE = 100000
local NextInstanceId = 1 -- Compteur d'ID numérique (Zéro-Allocation RAM)

local Pointers = {}
for i = 1, 4 do
	Pointers[i] = {
		Head = 1,
		Tail = 1
	}
end

Queue.InstanceRegistry = {} -- Main thread only: number -> Instance
setmetatable(Queue.InstanceRegistry, { __mode = "v" }) -- Weak values: allow GC if instance is destroyed

local TotalPushed = { 0, 0, 0, 0 }
local TotalLoaded = { 0, 0, 0, 0 }

function Queue.Push(priority: number, asset: any)
	local p = priority
	local tail = Pointers[p].Tail
	
	local assetKey = asset
	if typeof(asset) == "Instance" then
		assetKey = NextInstanceId
		NextInstanceId += 1
		Queue.InstanceRegistry[assetKey] = asset
	end

	Queues[p][tail] = assetKey
	Pointers[p].Tail = (tail % MAX_QUEUE_SIZE) + 1
	TotalPushed[priority] += 1
end

function Queue.Pop(priority: number): any?
	local p = priority
	local head = Pointers[p].Head
	if head == Pointers[p].Tail then return nil end
	
	local assetKey = Queues[p][head]
	Queues[p][head] = nil -- Free memory
	Pointers[p].Head = (head % MAX_QUEUE_SIZE) + 1
	
	if type(assetKey) == "number" then
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

function Queue.Clear(priority: number, onClearAsset: ((any) -> ())?)
	local p = priority
	-- Clean up InstanceRegistry to avoid memory leaks
	local head = Pointers[p].Head
	local tail = Pointers[p].Tail
	
	local current = head
	while current ~= tail do
		local assetKey = Queues[p][current]
		if type(assetKey) == "number" then
			Queue.InstanceRegistry[assetKey] = nil
		end
		
		if onClearAsset then
			onClearAsset(assetKey)
		end
		
		current = (current % MAX_QUEUE_SIZE) + 1
	end

	Pointers[p].Head = 1
	Pointers[p].Tail = 1
	table.clear(Queues[p])
end

function Queue.GetRingBuffer(priority: number)
	return Queues[priority]
end

return Queue
