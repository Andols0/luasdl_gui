local socket = require("socket")
local SDL = require("SDL")

local function VideoMeta()
	local SDL = require("SDL")
	local Datain = SDL.getChannel("VideoMetaout")
	local Dataout = SDL.getChannel("VideoMetain")
	while true do
		local Data = Datain:wait()
		Datain:pop()
		local filepath = Data[1]
		local audiopath = Data[2]

		local Meta = {}
		local framestring, numstring, err
		--Get framerate and size of the video.
		local ffprobe=io.popen('ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,duration -of csv=s=x:p=0 "'..filepath..'"')
		local width, height, framestring = ffprobe:read("*all"):match("(%d+)x(%d+)x(%d+/%d+)")
		Meta.texwidth, Meta.texheight = tonumber(width), tonumber(height)
		ffprobe:close()
		local A,B = framestring:match("(%d+)/(%d+)")
		Meta.framerate = A/B
		Meta.frametime = 1/Meta.framerate
		--Get the duration
		---har ändrat stream till format på raden nedan OBS!!
		ffprobe = io.popen('ffprobe -v error -show_entries format=duration -of csv=s=x:p=0 "'..filepath..'"')
		local durdone, duration = false , 0
		while not(durdone) do
			local Line = ffprobe:read()
			if Line then
				newdur = tonumber(Line)
				if newdur and newdur > duration then
					duration = newdur
				end
			else
				durdone = true
			end		
		end
		ffprobe:close()
		Meta.duration = duration
		--Number of frames
		ffprobe = io.popen('ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nokey=1:noprint_wrappers=1 "'..filepath..'"')

		numstring = ffprobe:read("*all")
		ffprobe:close()
		print("NUMSTRING: ",numstring)
		if numstring:match("N/A") then
			print("Framerate 2")
			Meta.numframes = Meta.duration*Meta.framerate+1
		else
			Meta.numframes = tonumber(numstring)+1
		end
		--Audio sample rate.
		audiopath = audiopath or filepath
		ffprobe = io.popen('ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels -of csv=s=x:p=0 "'..audiopath..'"')
		local Sample, Channels = ffprobe:read("*all"):match("(%d+)x(%d+)")
		Meta.Sample , Meta.Channels = tonumber(Sample), tonumber(Channels)
		print("V meta A channels: ", Channels)
		ffprobe:close()
		----------
		print("Video meta done")
		Dataout:push(Meta)
		Dataout:pop()

	end
end

ActiveVideos = {}

asd = 0
local function Start(self)
	ActiveVideos[self] = self
	print("Starting video")
	if not self.loaded then
		self:Load()
	end
	if not self.started then
		asd=asd+1
		print(string.format("Starting video for the: %d time",asd))
		self:Show()
		self.started=true
		AddToQueue(0,self.GetFrame,self)
		--table.insert(self.Queue,1,{t=0,cb=self.GetFrame,args=self})
	end
end
local function OneAudioCycle(self)
	print("next")
	self.Audio.Dev:pause(true)
end

local function Stop(self)
	ActiveVideos[self] = nil
	self.NextStop = true
	if self.Audio.Dev then
		print(#self.Queue)
		AddToQueue(socket.gettime()+1, OneAudioCycle,self)
		--table.insert(self.Queue,2,{t=socket.gettime()+1,cb=OneAudioCycle,args = self})
	end
	--self.texture=nil
	self.Stream:close()
	self.Paused = false
	self:Hide()
	self:Reload()
	
end

local function Pause(self)
	self.Paused = true
	if self.Audio.Dev then
		self.Audio.Dev:pause(true)
	end
end

local function Resume(self)
	local now = socket.gettime()
	self.Paused = false
	self.Resuming = true
	self.Starttime = now - (self.currentframe*self.frametime)
	--AddToQueue(now,self.GetFrame,self)
	--table.insert(self.Queue,{t=now,cb=self.GetFrame,args=self})
	--if self.Audio.Dev then
		--self.Audio.Dev:pause(false)
	--end
end

local function GetFrame(self)
	local err, Data
	if self.NextStop or self.Paused then self.NextStop = false return end--Stop it

	if self.currentframe == 0 then
		self.resuming = true
		self.Starttime = socket.gettime()
		if self.Audio.Dev then
			self.Audio.Dev:pause(false)
		end
	end
	self.currentframe = self.currentframe + 1
	--if self.currentframe % 100 == 0 then
		--print("Video memory: ",collectgarbage("count"))
	--end
	if self.currentframe <= self.numframes then
		if self.currentframe > self.framerate+1 and math.floor(self.currentframe*self.frametime) % 20 == 0 then
			if not(send) then
				self.Audio.Channel:push({"Time",self.currentframe*self.frametime})
				print("Video memory: ",collectgarbage("count")/1024)
				send = true
			end
		else
			send = false
		end

		--print("VidTime",math.floor(self.currentframe*self.frametime*100)/100)
		Data = self.Stream:read(self.framesize)
		if Data then 
			self.texture:lock(Data,self.pitch)
			self.texture:unlock()
		end
	else
		local extradata = self.Stream:read(self.framesize)
		if extradata then
			print("Extra data",#extradata)
		else
			print("Tom")
		end

		ActiveVideos[self]=nil
		self:Hide()
		self.Stream:close()
		if self.Audio.Dev then
			--AddToQueue(self.Queue,socket.gettime()+1,self.AudioDev.close,self.AudioDev)
			print("Stopping audio")
			self.Audio.Dev:pause(true)
		end
		return AddToQueue(socket.gettime()+1,self.Reload,self)
	end
	--self:Pause()
	if self.Resuming then
		if self.Audio.Dev then
			self.Audio.Dev:pause(false)
		end
		self.Resuming = false
	end
	local Nextframe = self.Starttime + (self.currentframe+1)*(1/self.framerate)
	return AddToQueue(Nextframe,self.GetFrame,self)
end

local function Load(self)
	if not(self.loaded) then
		self.Stream  = io.popen('ffmpeg -i "'..self.filepath..'" -c:v rawvideo -pix_fmt yuv420p -f rawvideo pipe:1 -loglevel warning',"rb")
		self.loaded = true
		self.Audio = CreateAudio(self.audiopath,self.Sample,self.Channels)
		--Prepare Texture
		self.texture, err = self.Win.Rdr:createTexture(SDL.pixelFormat.IYUV,SDL.textureAccess.Streaming,self.texwidth,self.texheight)
		if not self.texture then
			error(err)
		end
	end
end

local function Reload(self)
--if true then return end
	print("Reloading")
	self.Stream  = io.popen('ffmpeg -i "'..self.filepath..'" -c:v rawvideo -pix_fmt yuv420p -f rawvideo pipe:1 -loglevel warning',"rb")
	print("Got stream")
	self.Audio.Channel:push("Restart")
	print("Got audio")
	self.currentframe=0
	self.started = false
end

local function PrepareVideo(channel,self,filepath,audiopath)
	assert(self,"Could not index self")
	assert(filepath, "Filepath missing")
	local Video = self
	function Video:Load()
		self.WaitLoad = true
	end
	function Video:Start()
		self.WaitStart = true
	end
	local rdr = self.Win.Rdr
	channel:push({filepath, audiopath})
	local Data = coroutine.yield()
	for k,v in pairs(Data) do
		Video[k] = v
	end
	if Video.height == 0 then
		Video.height = Video.texheight
	end
	if Video.width == 0 then
		Video.width = Video.texwidth
	end
	--Open Audio--
	audiopath = audiopath or filepath
	Video.filepath = filepath
	Video.audiopath = audiopath
	print("Video.Sample",Video.Sample, Video.Channels)
	--Video.Audio = CreateAudio(audiopath,Video.Sample,Video.Channels)
	--Prepare Texture
	--Video.texture, err = rdr:createTexture(SDL.pixelFormat.IYUV,SDL.textureAccess.Streaming,Video.texwidth,Video.texheight)
	--if not Video.texture then
	--	error(err)
	--end
	--Open video stream
	--Video.Stream  = io.popen('ffmpeg -i "'..filepath..'" -c:v rawvideo -pix_fmt yuv420p -f rawvideo pipe:1 -loglevel warning',"rb")
	--Set stuff
	Video.currentframe=0
	Video.pitch = tonumber(Video.texwidth*1.5)
	Video.framesize = Video.pitch*Video.texheight
	Video.GetFrame = GetFrame
	Video.Start = Start
	Video.Stop = Stop
	Video.Pause = Pause
	Video.Resume = Resume
	Video.Reload  = Reload
	Video.Load = Load
	Video:UpdatePos()
	if Video.WaitLoad and not Video.WaitStart then
		Video.WaitLoad=nil
		Video:Load()
	end
	if Video.WaitStart then
		Video.WaitStart=nil
		Video:Load()
		Video:Start()
	end
	return
end

local function Out(self,filepath,audiopath)
	CreateCallback("VideoMeta",VideoMeta ,PrepareVideo,nil,self,filepath,audiopath)
end

return Out


