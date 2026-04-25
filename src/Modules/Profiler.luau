--!strict
local Profiler = {}
local Records = {}
local RecordIndex = 1
local MAX_RECORDS = 1000

-- Buffer statique pour GenerateReport pour éviter les allocations d'usage interne
local InternalReportBuffer = {}

-- Initialisation Zéro-Allocation : on pré-alloue les tables de records
for i = 1, MAX_RECORDS do
	Records[i] = {id = "", time = 0}
end

function Profiler.Record(assetId: any, timeTaken: number)
	local record = Records[RecordIndex]
	record.id = tostring(assetId)
	record.time = timeTaken
	RecordIndex = (RecordIndex % MAX_RECORDS) + 1
end

--[=[
	Récupère les assets les plus lents.
	@param resultsBuffer Une table fournie par l'appelant qui sera recyclée.
]=]
function Profiler.GetTopSlowest(limit: number, resultsBuffer: {any})
	table.clear(resultsBuffer)
	
	-- Note: Le tri alloue un peu de mémoire en interne, mais cette fonction
	-- n'est pas censée être appelée dans une boucle de jeu.
	table.sort(Records, function(a, b) return a.time > b.time end)
	
	local count = 0
	for i = 1, math.min(limit, MAX_RECORDS) do
		if Records[i].time > 0 then
			count += 1
			resultsBuffer[count] = Records[i]
		end
	end
end

function Profiler.GenerateReport()
	Profiler.GetTopSlowest(10, InternalReportBuffer)
	
	print("--- VANGUARD PROFILER REPORT ---")
	for i, record in InternalReportBuffer do
		print(string.format("%d. Asset %s took %.2fs", i, record.id, record.time))
	end
	
	table.clear(InternalReportBuffer)
end

function Profiler.Clear()
	for i = 1, MAX_RECORDS do
		local record = Records[i]
		record.id = ""
		record.time = 0
	end
	RecordIndex = 1
end

return Profiler
