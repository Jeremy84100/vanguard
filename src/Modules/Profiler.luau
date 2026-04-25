--!strict
local Profiler = {}
local Records = {}
local RecordIndex = 1
local MAX_RECORDS = 1000

function Profiler.Record(assetId: any, timeTaken: number)
	Records[RecordIndex] = {id = assetId, time = timeTaken}
	RecordIndex = (RecordIndex % MAX_RECORDS) + 1
end

function Profiler.GetTopSlowest(limit: number)
	table.sort(Records, function(a, b) return a.time > b.time end)
	local result = {}
	for i = 1, math.min(limit, #Records) do
		table.insert(result, Records[i])
	end
	return result
end

function Profiler.GenerateReport()
	local top = Profiler.GetTopSlowest(10)
	print("--- VANGUARD PROFILER REPORT ---")
	for i, record in ipairs(top) do
		print(string.format("%d. Asset %s took %.2fs", i, tostring(record.id), record.time))
	end
end

function Profiler.Clear()
	table.clear(Records)
end

return Profiler
