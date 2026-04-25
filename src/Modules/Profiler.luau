--!strict
local Profiler = {}
local Records = {}
local RecordIndex = 1
local MAX_RECORDS = 1000

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

function Profiler.GetTopSlowest(limit: number)
	-- Note: Le tri alloue un peu de mémoire en interne, mais cette fonction
	-- n'est pas censée être appelée dans une boucle de jeu.
	table.sort(Records, function(a, b) return a.time > b.time end)
	
	local result = {}
	for i = 1, math.min(limit, MAX_RECORDS) do
		if Records[i].time > 0 then
			table.insert(result, Records[i])
		end
	end
	return result
end

function Profiler.GenerateReport()
	local top = Profiler.GetTopSlowest(10)
	print("--- VANGUARD PROFILER REPORT ---")
	for i, record in top do
		print(string.format("%d. Asset %s took %.2fs", i, record.id, record.time))
	end
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
