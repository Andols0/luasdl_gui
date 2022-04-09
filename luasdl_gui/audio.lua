local SDL = require("SDL")
local Core = require("luasdl_gui.core")
local Processfile
function AudioMeta()
	local SDL = require("SDL")
	local Datain = SDL.getChannel("AudioMetaout")
	local Dataout = SDL.getChannel("AudioMetain")

	while true do
		local Data = Datain:wait()
		Datain:pop()
		print("AudioMeta has work to do!!")
		local filepath = Data

		local Meta = {}
		local ffprobe = io.popen('ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,duration,channels -of csv=s=x:p=0 "'..filepath..'"')
		local Metastring = ffprobe:read("*all")
		Meta.Sample, Meta.Channels, Meta.Dur = Metastring:match("(%d+)x(%d+)x(%d+%.?%d*)")
		Meta.Sample = tonumber(Meta.Sample)
		Meta.duration = tonumber(Meta.Dur)
		Meta.Channels = tonumber(Meta.Channels)
		ffprobe:close()
		----------
		print("Audiometa",Metastring)
		Dataout:push(Meta)
		Dataout:pop()
	end
end

local AudioFunctions = {}

ActiveAudio = {}

function AudioFunctions.Start(self)
	ActiveAudio[self] = self
	self.Dev:pause(false)
end

function AudioFunctions.Pause(self)
	self.Dev:pause(true)
end

function AudioFunctions.Resume(self)
	self.Dev:pause(false)
end

function AudioFunctions.Stop(self)
	ActiveAudio[self] = nil
	self.Dev:pause(true)
	self.Channel:push("Restart")
end

function AudioFunctions.SetVolume(self,Volume)
	self.Channel:push({"Vol",Volume*128})
end

local MainAudioChannel = SDL.getChannel "Audio"
MainAudioChannel:push("junk")
local AudioChannels = {}
local numaudio = 0

--I don't want to do this =( but i have to, look through package.path to find 
--the lib folder to get a path to the audio-processor
for path in package.path:gmatch("[^;]+") do
	path = path:gsub("?","luasdl_gui")
	path = path:match("(.+)%..-$").."/audio-processor.lua"
	local file = io.open(path)
	if file then
		print("Found it")
		Processfile = path
		file:close()
		break
	end
end

local function PrepareAudio(Sample,filepath,Channels)
--if true then return nil end
	numaudio = numaudio + 1
	--print("Pushnum","Contains:",MainAudioChannel:first())
	MainAudioChannel:push(numaudio)
	---print("Getnumchannel"..numaudio)
	AudioChannels[numaudio] = SDL.getChannel("Audio"..numaudio)



 --Prepare the audio spec we want
 print("Prepare audio sample",Sample, Channels)
	local spec	= {
		callback	= Processfile,
		allowchanges	= true,
		frequency	= Sample,
		format		= SDL.audioFormat.S16LSB,
		samples		= 4096,
		channels	= Channels
	}
	--print("Push")
	AudioChannels[numaudio]:push({path = filepath,Sample = Sample, Channels = Channels})
	--channel:push("Tja")
	--print("GOing to open")
	local dev, err = SDL.openAudioDevice(spec)
	assert(dev,err)
	return dev, AudioChannels[numaudio]
end


local function Create(Channel,Audio,Path,Sample,Channels)
	print("Create",Channel,Audio,Path,Sample,Channels)
	if not(Sample) or not(Channels) then
		Channel:push(Path)
        local Meta = coroutine.yield()
        for k,v in pairs(Meta) do
            Audio[k] = v
        end
    end
	Sample = Sample or Audio.Sample
	Channels = Channels or Audio.Channels
	Audio.Dev, Audio.Channel = PrepareAudio(Sample,Path,Channels)
	for k,v in pairs(AudioFunctions) do
		Audio[k] = v
	end
end

function CreateAudio(Path,Sample,Channels)
	local Audio = {}
	Core.CreateCallback("AudioMeta",AudioMeta,Create,nil,Audio,Path,Sample,Channels)
	return Audio
end
