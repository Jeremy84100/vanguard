--!strict
--!native
--!optimize 2

local Queue = {}
local Capacities = { 1000, 2000, 5000, 5000 }
local Queues = {
	[1] = table.create(Capacities[1]),
	[2] = table.create(Capacities[2]),
	[3] = table.create(Capacities[3]),
	[4] = table.create(Capacities[4]),
}

for i = 1, 4 do
	setmetatable(Queues[i], { __mode = "v" })
end

local WriteHeads = { 1, 1, 1, 1 }
local ReadHeads = { 1, 1, 1, 1 }
local TotalPushed = { 0, 0, 0, 0 }
local TotalLoaded = { 0, 0, 0, 0 }

function Queue.Push(priority: number, asset: any)
	local head = WriteHeads[priority]
	local nextHead = (head % Capacities[priority]) + 1
	
	if nextHead == ReadHeads[priority] then
		warn("[Vanguard] Queue Overflow for Priority", priority, "- Asset ignored.")
		return false
	end

	Queues[priority][head] = asset
	WriteHeads[priority] = nextHead
	TotalPushed[priority] += 1
	
	return true
end

function Queue.Pop(priority: number): any?
	local readHead = ReadHeads[priority]
	local writeHead = WriteHeads[priority]
	
	while readHead ~= writeHead do
		local asset = Queues[priority][readHead]
		Queues[priority][readHead] = nil -- Free reference for GC
		readHead = (readHead % Capacities[priority]) + 1
		ReadHeads[priority] = readHead
		
		if asset ~= nil then
			return asset
		end
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

function Queue.Clear(priority: number, onClearAsset: ((any) -> ())?)
	if onClearAsset then
		local readHead = ReadHeads[priority]
		local writeHead = WriteHeads[priority]
		
		while readHead ~= writeHead do
			local asset = Queues[priority][readHead]
			if asset then
				pcall(onClearAsset, asset)
			end
			readHead = (readHead % Capacities[priority]) + 1
		end
	end

	-- Clears the table while keeping the pre-allocated memory intact for zero-allocation
	table.clear(Queues[priority])

	ReadHeads[priority] = 1
	WriteHeads[priority] = 1
	Queue.ResetTracking(priority)
end

return Queue