--!strict
--!native
--!optimize 2
local Profiler = {}
local Records = {}
local RecordIndex = 1
local MAX_RECORDS = 1000

-- Static buffer for GenerateReport to prevent internal allocations
local InternalReportBuffer = {}
for i = 1, MAX_RECORDS do
	Records[i] = {id = "", time = 0}
end

local TotalRecorded = 0

function Profiler.Record(assetId: any, timeTaken: number)
	local record = Records[RecordIndex]
	if typeof(assetId) == "Instance" then
		-- Use .Name instead of :GetFullName() to reduce string allocation
		record.id = assetId.Name
	else
		record.id = tostring(assetId)
	end
	record.time = timeTaken
	RecordIndex = (RecordIndex % MAX_RECORDS) + 1
	if TotalRecorded < MAX_RECORDS then
		TotalRecorded += 1
	end
end

-- Sorts a copy of the buffer to avoid breaking the original Ring Buffer's indexing.
function Profiler.GetTopSlowest(limit: number, resultsBuffer: {any})
	table.clear(resultsBuffer)
	
	if TotalRecorded == 0 then return end
	
	local count = 0
	for i = 1, TotalRecorded do
		local rec = Records[i]
		if rec.time > 0 then
			count += 1
			resultsBuffer[count] = rec
		end
	end
	
	table.sort(resultsBuffer, function(a, b) 
		return a.time > b.time 
	end)
	
	if #resultsBuffer > limit then
		for i = limit + 1, #resultsBuffer do
			resultsBuffer[i] = nil
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
	TotalRecorded = 0
end

return Profiler
