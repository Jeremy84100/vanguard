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

local OnReadyCallbacks = { {}, {}, {}, {} }
local OnProgressCallbacks = { {}, {}, {}, {} }
local OnFailedCallbacks = { {}, {}, {}, {} }
local NextCallbackId = 1

local BatchArray = table.create(BATCH_SIZE)

local LOAD_TIMEOUT = 10
local LastLoadTime = 0.5 -- Starting estimation

local function ProcessQueue()
	while true do
		if isPaused then
			task.wait(0.2)
			continue
		end

		local processedAny = false

		-- On parcourt par priorité (1 est le plus urgent)
		for priority = 1, 4 do
			if not Queue.IsEmpty(priority) then
				-- Ping checking via Throttler
				local dynamicBatch = Throttler.CalculateBatchSize(BATCH_SIZE, LastLoadTime)
				if dynamicBatch == 0 then
					task.wait(1) -- Heavy pause to recover ping
					break -- Skip processing this cycle entirely
				end

				local batchCount = 0
				table.clear(BatchArray)

				-- Remplissage du lot (Batch)
				while batchCount < dynamicBatch do
					local asset = Queue.Pop(priority)
					if not asset then break end

					-- On vérifie si l'asset est toujours valide (pas annulé entre temps)
					if State.Get(asset) == 1 then
						batchCount += 1
						BatchArray[batchCount] = asset
					end
				end

				if batchCount > 0 then
					processedAny = true
					local exactBatch = table.move(BatchArray, 1, batchCount, 1, table.create(batchCount))
					
					if VanguardDebug then
						print(string.format("[Vanguard] Loading batch of %d assets (Prio %d)", batchCount, priority))
					end

					local currentThread = coroutine.running()
					local success = false
					local retries = 0

					-- Auto-Retry Loop (1 retry max)
					while retries <= 1 and not success do
						local isBatchActive = true -- 🔒 Verrou Booléen contre le "Ghost Resume"
						
						local loadThread = task.spawn(function()
							-- debug.profilebegin supprimé : on ne profile pas de fonctions qui yield !
							local pcallSuccess = pcall(function()
								ContentProvider:PreloadAsync(exactBatch)
							end)
							
							if isBatchActive then
								isBatchActive = false
								task.spawn(currentThread, pcallSuccess)
							end
						end)

						local timeoutThread = task.delay(LOAD_TIMEOUT, function()
							if isBatchActive then
								isBatchActive = false
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
								warn("[Vanguard] Batch failed, retrying...")
							end
						end
					end

					-- Mise à jour de l'état final
					for _, asset in ipairs(exactBatch) do
						State.Set(asset, success and 2 or 3)
					end
					
					Queue.AddLoaded(priority, batchCount)

					-- Trigger des Callbacks de progression
					for _, callback in pairs(OnProgressCallbacks[priority]) do
						task.defer(callback, Queue.GetProgress(priority))
					end

					-- Si la queue est vide, trigger OnReady
					if Queue.IsEmpty(priority) then
						for _, callback in pairs(OnReadyCallbacks[priority]) do
							task.defer(callback)
						end
					end
					
					-- Si échec après retry, trigger OnFailed
					if not success then
						for _, callback in pairs(OnFailedCallbacks[priority]) do
							task.defer(callback)
						end
					end
				end
			end
		end

		if not processedAny then
			task.wait(0.1) -- Attente si rien à traiter
		end
	end
end

function Worker.Start()
	if IS_RUNNING then return end
	IS_RUNNING = true
	task.spawn(ProcessQueue)
end

function Worker.SetBatchSize(size: number)
	BATCH_SIZE = math.clamp(size, 1, 100)
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

-- Callbacks Registration
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
