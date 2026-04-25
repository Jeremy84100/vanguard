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

				-- Remplissage du lot (Batch) - Sécurisé contre les objets détruits (nil)
				while batchCount < dynamicBatch and not Queue.IsEmpty(priority) do
					local asset = Queue.Pop(priority)
					
					-- Si l'asset a été détruit entre temps (Weak Value dans la Queue), on continue !
					if not asset then continue end

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
					local finalSuccess = false
					local retries = 0
					local batchFailedAssets = {} -- 🔒 On isole les coupables pour éviter la punition collective

					-- Auto-Retry Loop (1 retry max)
					while retries <= 1 and not finalSuccess do
						local isBatchActive = true -- 🔒 Verrou Booléen contre le "Ghost Resume"
						table.clear(batchFailedAssets)
						
						local loadThread = task.spawn(function()
							local pcallSuccess = pcall(function()
								-- Utilisation du callback natif pour traquer les échecs réels (404, modération, etc.)
								ContentProvider:PreloadAsync(exactBatch, function(contentId, fetchStatus)
									if fetchStatus == Enum.AssetFetchStatus.Failure then
										batchFailedAssets[contentId] = true
									end
								end)
							end)
							
							if isBatchActive then
								isBatchActive = false
								-- Le Retry n'est déclenché QUE si le moteur crash (pcall) ou fait un Timeout
								-- Les erreurs de téléchargement (404) sont définitives et ne justifient pas un retry global
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
						finalSuccess = coroutine.yield()

						if finalSuccess then
							LastLoadTime = os.clock() - startClock
							if LastLoadTime < 0.01 then
								LastLoadTime = 0.01
							end
							task.cancel(timeoutThread)
						else
							retries += 1
							if VanguardDebug then
								warn("[Vanguard] Batch operation failed (Timeout/Crash), retrying...")
							end
						end
					end

					-- Mise à jour de l'état final (Justice Individuelle)
					for _, asset in exactBatch do
						if finalSuccess then
							local isSpecificFailure = false
							if type(asset) == "string" and batchFailedAssets[asset] then
								isSpecificFailure = true
							end
							State.Set(asset, isSpecificFailure and 3 or 2)
						else
							-- S'il y a eu un vrai Timeout ou crash global après retries
							State.Set(asset, 3)
						end
					end
					
					Queue.AddLoaded(priority, batchCount)

					-- Trigger des Callbacks de progression
					for _, callback in OnProgressCallbacks[priority] do
						task.defer(callback, Queue.GetProgress(priority))
					end

					-- Si la queue est vide, trigger OnReady
					if Queue.IsEmpty(priority) then
						Queue.ResetTracking(priority)
						for _, callback in OnReadyCallbacks[priority] do
							task.defer(callback)
						end
					end
					
					-- Si échec global après retry, trigger OnFailed
					if not finalSuccess then
						for _, callback in OnFailedCallbacks[priority] do
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
