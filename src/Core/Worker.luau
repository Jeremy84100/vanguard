--!strict
local ContentProvider = game:GetService("ContentProvider")
local Queue = require(script.Parent.Queue)
local State = require(script.Parent.State)
local Throttler = require(script.Parent.Parent.Modules.Throttler)

local Worker = {}
local BATCH_SIZE = 50
local IS_RUNNING = false
local isPaused = false
local VanguardDebug = false

local OnReadyCallbacks: { [number]: { [number]: () -> () } } = { {}, {}, {}, {} }
local OnProgressCallbacks: { [number]: { [number]: (number, number) -> () } } = { {}, {}, {}, {} }
local OnFailedCallbacks: { [number]: { [number]: () -> () } } = { {}, {}, {}, {} }
local NextCallbackId = 1

local BatchArray = table.create(100)
local ExactBatchArray = {}
local batchFailedAssets = {}

local LOAD_TIMEOUT = 10
local LastLoadTime = 0.5 -- Starting estimation
local NextBatchCounter = 1
local ActiveBatchId = 0
local MAX_BATCH_SIZE = 100
local MAX_PRIORITY = 4

-- Static preload callback prevents closure allocation
local function PreloadCallback(contentId: string, fetchStatus: Enum.AssetFetchStatus)
	if fetchStatus == Enum.AssetFetchStatus.Failure or fetchStatus == Enum.AssetFetchStatus.TimedOut then
		batchFailedAssets[contentId] = true
	end
end

-- Static wrapper for task.spawn prevents closure allocation in loops
local function BatchLoader(currentThread: thread, exactBatch: {any}, batchId: number, debugMode: boolean)
	local success, err = pcall(ContentProvider.PreloadAsync, ContentProvider, exactBatch, PreloadCallback)
	
	if not success and debugMode then
		warn("[Vanguard] ContentProvider Error:", err)
	end
	
	if ActiveBatchId == batchId then
		ActiveBatchId = 0
		task.defer(currentThread, success)
	end
end

-- Static handler for timeouts
local function TimeoutHandler(currentThread: thread, loadThread: thread, batchId: number)
	if ActiveBatchId == batchId then
		ActiveBatchId = 0
		task.cancel(loadThread)
		task.defer(currentThread, false)
	end
end

local function ProcessQueue()
	while true do
		if isPaused then
			task.wait(0.2)
			continue
		end

		local processedAny = false

		for priority = 1, MAX_PRIORITY do
			if not Queue.IsEmpty(priority) then
				local dynamicBatch = Throttler.CalculateBatchSize(BATCH_SIZE, LastLoadTime)
				BATCH_SIZE = math.min(dynamicBatch, MAX_BATCH_SIZE)
				
				if BATCH_SIZE == 0 then
					task.wait(1)
					break
				end

				local batchCount = 0
				table.clear(BatchArray)

				while batchCount < BATCH_SIZE do
					local asset = Queue.Pop(priority)
					
					if not asset then break end

					if State.Get(asset) == 1 then
						batchCount += 1
						BatchArray[batchCount] = asset
					end
				end

				if batchCount > 0 then
					processedAny = true
					
					table.clear(ExactBatchArray)
					local exactBatch = table.move(BatchArray, 1, batchCount, 1, ExactBatchArray)
					
					if VanguardDebug then
						print(string.format("[Vanguard] Loading batch of %d assets (Prio %d)", batchCount, priority))
					end

					local currentThread = coroutine.running()
					local finalSuccess = false
					local retries = 0

					while retries <= 1 and not finalSuccess do
						ActiveBatchId = NextBatchCounter
						NextBatchCounter += 1
						local currentBatchId = ActiveBatchId 
						
						table.clear(batchFailedAssets)
						
						local loadThread = task.spawn(BatchLoader, currentThread, exactBatch, currentBatchId, VanguardDebug)
						local timeoutThread = task.delay(LOAD_TIMEOUT, TimeoutHandler, currentThread, loadThread, currentBatchId)

						local startClock = os.clock()
						finalSuccess = coroutine.yield()

						task.cancel(timeoutThread)

						if finalSuccess then
							LastLoadTime = math.max(0.01, os.clock() - startClock)
						else
							retries += 1
							if VanguardDebug then
								warn("[Vanguard] Batch operation failed (Timeout/Crash), retrying...")
							end
						end
					end

					for _, asset in exactBatch do
						if finalSuccess then
							local isSpecificFailure = false
							
							-- Verify ID match because Roblox modifies the asset string internally
							if type(asset) == "string" then
								local idStr = string.match(asset, "%d+")
								if idStr then
									for failedId, _ in batchFailedAssets do
										if string.find(failedId, idStr, 1, true) then
											isSpecificFailure = true
											break
										end
									end
								end
							end
							
							State.Set(asset, isSpecificFailure and 3 or 2)
						else
							State.Set(asset, 3)
						end
					end
					
					Queue.AddLoaded(priority, batchCount)

					local loaded, total = Queue.GetProgress(priority)
					for _, callback in OnProgressCallbacks[priority] do
						task.spawn(callback, loaded, total)
					end

					if Queue.IsEmpty(priority) then
						Queue.ResetTracking(priority)
						for _, callback in OnReadyCallbacks[priority] do
							task.spawn(callback)
						end
					end
					
					if not finalSuccess then
						for _, callback in OnFailedCallbacks[priority] do
							task.spawn(callback)
						end
					end

					break
				end
			end
		end

		if not processedAny then
			task.wait(0.1)
		end
	end
end

function Worker.Start()
	if IS_RUNNING then return end
	IS_RUNNING = true
	task.spawn(ProcessQueue)
end

function Worker.SetBatchSize(size: number)
	MAX_BATCH_SIZE = math.clamp(size, 1, 100)
end

function Worker.SetTimeout(time: number)
	LOAD_TIMEOUT = math.max(1, time)
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

function Worker.RegisterOnReady(prio: number, cb: () -> ()): number
	local id = NextCallbackId
	NextCallbackId += 1
	OnReadyCallbacks[prio][id] = cb
	return id
end

function Worker.UnregisterOnReady(prio: number, id: number)
	OnReadyCallbacks[prio][id] = nil
end

function Worker.RegisterOnProgress(prio: number, cb: (number, number) -> ()): number
	local id = NextCallbackId
	NextCallbackId += 1
	OnProgressCallbacks[prio][id] = cb
	return id
end

function Worker.UnregisterOnProgress(prio: number, id: number)
	OnProgressCallbacks[prio][id] = nil
end

function Worker.RegisterOnFailed(prio: number, cb: () -> ()): number
	local id = NextCallbackId
	NextCallbackId += 1
	OnFailedCallbacks[prio][id] = cb
	return id
end

function Worker.UnregisterOnFailed(prio: number, id: number)
	OnFailedCallbacks[prio][id] = nil
end

return Worker
