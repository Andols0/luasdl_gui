--
-- audio-processor.lua -- the callback function
--
print("Hello there!")
local SDL	= require "SDL"
require("socket")

local args	= { ... }
print(...)
local sound	= { }
local channel	= SDL.getChannel "Audio"

channel:pop()
print("Time to get channelnum")
local channelnum = channel:first()
print("Gotnum:",channelnum)
Filechannel = SDL.getChannel("Audio"..channelnum)


--
-- This will be called.
--
local Volume = 128
local Garbage = 0
local TotalBytes = 0

print("Looking for path")

while not Info do
	Info = Filechannel:first()
end
local path = Info.path
local Sample = Info.Sample
local Channels = Info.Channels
local EfSample = Channels*Sample*2
print("Sound meta:", Info.Sample, Info.Channels)

function Load()
	print("Loading audio")
	tid = socket.gettime()
	if open then
		tid2=socket.gettime()
		sound.stream:close()
		print("closing took: "..socket.gettime()-tid2)
	end
	sound.stream = io.popen('ffmpeg -i "'..path..'" -c:a pcm_s16le -f s16le pipe:1 -loglevel warning',"rb")
	stop = false
	open = true
	TotalBytes=0
	print("Loading audio stream took: "..socket.gettime()-tid)
end

Load()


endtime = socket.gettime()
local slowing

return function (length)
	local data = ""
	--print("AudTime: ",math.floor(TotalBytes/(96000*2)*1000)/1000)
	starttime = socket.gettime()
	--print("Time between call: ",socket.gettime()-endtime)
	--print(channelnum,length)
	--Garbage = Garbage + 1
	--if Garbage == 200 then
		--print("Audio memory: ",collectgarbage("count")/1024)
		--Garbage =0
	--end

	local Msg = Filechannel:last()
	if Msg ~="asd" then
		if Msg == "Restart" then
			Load()
			--Filechannel:pop()
		else
			local Cmd, Value = Msg[1], Msg[2]
			if Cmd == "Vol" then
				print("Got new vol: ",Value)
				Volume = math.floor(Value)
			elseif Cmd == "Time" then
				--print("Audio memory: ",collectgarbage("count")/1024)
				--print("At videotime:",Value)
				--print("Audiotime: ",TotalBytes/(EfSample))
				local timediff = Value - TotalBytes/(EfSample)
				--print("Diff in vid and audio: ",timediff)
				if timediff > 0  then
					local newtime = TotalBytes/(EfSample)
					local trashdata = 0
					local num = 0
					while newtime < Value do
						num = num + 1
						newtime = (TotalBytes+length*num)/(EfSample)
					end
					if num >= 2 then
						trashdata = length*(num-1)
						TotalBytes = TotalBytes + trashdata 
						local putitinthetrash = sound.stream:read(trashdata)
						putitinthetrash = nil
						print("CORRECTING: ",num-1, "Samples")
					end
				end
				if timediff < 0 then
					local newtime = TotalBytes/(EfSample)
					local trashdata = 0
					local num = 0
					while newtime > Value do
						num = num + 1
						newtime = (TotalBytes-length*num)/(EfSample)
					end
					if num >= 2 then
						slowing = num *2
						--trashdata = length*(num-1)
						--TotalBytes = TotalBytes + trashdata 
						--local putitinthetrash = sound.stream:read(trashdata)
						--putitinthetrash = nil
						print("Slowing: ",slowing, "Samples")
					end
				end
			end
		end
		Filechannel:push("asd")
	end
	if stop then print("nil") return nil end
	if slowing then
		local Table = {}
		if slowing % 2 == 0 then
			TotalBytes = TotalBytes + length
			slowdata = sound.stream:read(length)
			for i=1, #slowdata/2,2 do
				local sub = slowdata:sub(i,i+1)
				table.insert(Table,sub)
				table.insert(Table,sub)
			end
		else
			--TotalBytes = TotalBytes - length
			if slowdata then
				for i=#slowdata/2+1, #slowdata, 2 do
					local sub = slowdata:sub(i,i+1)
					table.insert(Table,sub)
					table.insert(Table,sub)
				end
			else
				slowing = slowing - 1
				return nil
			end
		end
		slowing = slowing - 1
		--TotalBytes = TotalBytes - length
		if slowing == 0 then
			slowing = nil
		end
		data = table.concat(Table)
	else
		TotalBytes = TotalBytes + length
		data = sound.stream:read(length)
	end
	--for i=1, #data, 4 do
		--table.insert(Table,data:sub(i,i+1))
	--end
	--data = table.concat(Table)

	if not(data) then sound.stream:close() print("EoF") stop = true open = false end
	--if Volume ~=128 then
		data, err = SDL.mixAudioFormat(data,SDL.audioFormat.S16LSB, 6)
	--	assert(data,err)
	--end
	endtime = socket.gettime()
	--print("Lua audio process: ",socket.gettime()-starttime)
	return data
end
