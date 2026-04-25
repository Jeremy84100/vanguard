--!strict
local ContentProvider = game:GetService("ContentProvider")
local Queue = require(script.Parent.Queue)
local State = require(script.Parent.State)
local Throttler = require(script.Parent.Parent.Modules.Throttler)

local Worker = {}
local isRunning = false
local isPaused = false
local VanguardDebug = false

local OnReadyCallbacks = { {}, {}, {}, {} }
local OnProgressCallbacks = { {}, {}, {}, {} }
local OnFailedCallbacks = { {}, {}, {}, {} }

local NextCallbackId = 1 -- Unique ID generator for thread-safe callbacks

local BATCH_SIZE = 50
local NextBatchSize = BATCH_SIZE
local BatchArray = table.create(BATCH_SIZE)

local LOAD_TIMEOUT = 10
local LastLoadTime = 0.5 -- Starting estimation

local function ProcessQueue()
	while true do
		if isPaused then
			task.wait(0.1)
			continue
		end

		if NextBatchSize ~= BATCH_SIZE then
			BATCH_SIZE = NextBatchSize
			BatchArray = table.create(BATCH_SIZE)
		end

		local processedAny = false

		for priority = 1, 4 do
			if not Queue.IsEmpty(priority) then
				-- Ping checking via Throttler
				local dynamicBatch = Throttler.CalculateBatchSize(BATCH_SIZE, LastLoadTime)
				if dynamicBatch == 0 then
					task.wait(1) -- Heavy pause to recover ping
					break -- Skip processing this cycle entirely
				end

				processedAny = true
				local batchCount = 0

				while batchCount < dynamicBatch and not Queue.IsEmpty(priority) do
					local asset = Queue.Pop(priority)
					-- Lazy deletion: skip if state is no longer 1 (e.g. cancelled or loaded)
					if asset and State.Get(asset) == 1 then
						batchCount += 1
						BatchArray[batchCount] = asset
					end
				end

				if batchCount == 0 then
					break
				end -- Skip and restart prioritization

				-- Slice array to exact batch size (ContentProvider requires exact array)
				local exactBatch = table.move(BatchArray, 1, batchCount, 1, table.create(batchCount))
				local currentThread = coroutine.running()

				local success = false
				local retries = 0

				-- Auto-Retry Loop (1 retry max)
				while retries <= 1 and not success do
					local loadThread = task.spawn(function()
						debug.profilebegin("Vanguard_BatchLoad")
						local pcallSuccess = pcall(function()
							ContentProvider:PreloadAsync(exactBatch)
						end)
						debug.profileend()
						task.spawn(currentThread, pcallSuccess)
					end)

					local timeoutThread = task.delay(LOAD_TIMEOUT, function()
						if coroutine.status(loadThread) ~= "dead" then
							task.cancel(loadThread)
							task.spawn(currentThread, false)
						end
					end)

					local startClock = os.clock()
					success = coroutine.yield()

					if success then
						LastLoadTime = os.clock() - startClock
						if LastLoadTime < 0.01 then
							LastLoadTime = 0.01
						end
						task.cancel(timeoutThread)
					else
						retries += 1
						if VanguardDebug then
							warn("Vanguard: Timeout on priority " .. priority .. " (Retry " .. retries .. ")")
						end
					end
				end

				if success then
					Queue.AddLoaded(priority, batchCount)
					for i = 1, batchCount do
						State.Set(exactBatch[i], 2)
					end

					local loaded, total = Queue.GetProgress(priority)
					for _, cb in pairs(OnProgressCallbacks[priority]) do
						task.defer(cb, loaded, total)
					end
				else
					if VanguardDebug then
						warn("Vanguard: Abandoning batch on priority " .. priority, exactBatch)
					end
					for i = 1, batchCount do
						State.Set(exactBatch[i], 3)
					end
					for _, cb in pairs(OnFailedCallbacks[priority]) do
						task.defer(cb)
					end
				end

				-- Trigger OnReady if queue is now empty
				if Queue.IsEmpty(priority) then
					for _, callback in pairs(OnReadyCallbacks[priority]) do
						task.defer(callback)
					end
					table.clear(OnReadyCallbacks[priority])
					Queue.ResetTracking(priority)
				end

				break -- Go back to priority 1 to ensure criticals are respected
			end
		end

		if not processedAny then
			task.wait(0.1) -- Idle sleep
		end
	end
end

function Worker.Start()
	if isRunning then
		return
	end
	isRunning = true
	task.defer(ProcessQueue)
end

function Worker.Pause()
	isPaused = true
end
function Worker.Resume()
	isPaused = false
end
function Worker.SetDebug(value: boolean)
	VanguardDebug = value
end

function Worker.SetBatchSize(size: number)
	NextBatchSize = size
end

function Worker.SetTimeout(seconds: number)
	LOAD_TIMEOUT = seconds
end

function Worker.RegisterOnReady(priority: number, callback: () -> ()): number
	local id = NextCallbackId
	NextCallbackId += 1
	OnReadyCallbacks[priority][id] = callback
	return id
end

function Worker.UnregisterOnReady(priority: number, id: number)
	OnReadyCallbacks[priority][id] = nil
end

function Worker.RegisterOnProgress(priority: number, callback: (number, number) -> ()): number
	local id = NextCallbackId
	NextCallbackId += 1
	OnProgressCallbacks[priority][id] = callback
	return id
end

function Worker.UnregisterOnProgress(priority: number, id: number)
	OnProgressCallbacks[priority][id] = nil
end

function Worker.RegisterOnFailed(priority: number, callback: () -> ()): number
	local id = NextCallbackId
	NextCallbackId += 1
	OnFailedCallbacks[priority][id] = callback
	return id
end

function Worker.UnregisterOnFailed(priority: number, id: number)
	OnFailedCallbacks[priority][id] = nil
end

return Worker
