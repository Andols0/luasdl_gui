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

local VideoFunctions = {}
asd = 0
function VideoFunctions.Start(self)
	ActiveVideos[self] = self
	print("Starting video")
	if not self._loaded then
		self:Load()
	end
	if not self._started then
		asd=asd+1
		print(string.format("Starting video for the: %d time",asd))
		self:Show()
		self._started=true
		AddToQueue(0,self.GetFrame,self)
		--table.insert(self.Queue,1,{t=0,cb=self.GetFrame,args=self})
	end
end
local function OneAudioCycle(self)
	print("next")
	self._Audio.Dev:pause(true)
end

function VideoFunctions.Stop(self)
	ActiveVideos[self] = nil
	self._NextStop = true
	if self._Audio.Dev then
		print(#self.Queue)
		AddToQueue(socket.gettime()+1, OneAudioCycle,self)
		--table.insert(self.Queue,2,{t=socket.gettime()+1,cb=OneAudioCycle,args = self})
	end
	--self.texture=nil
	self._Stream:close()
	self._Paused = false
	self:Hide()
	self:Reload()
	
end

function VideoFunctions.Pause(self)
	self._Paused = true
	if self._Audio.Dev then
		self._Audio.Dev:pause(true)
	end
end

function VideoFunctions.Resume(self)
	local now = socket.gettime()
	self._Paused = false
	self._Resuming = true
	self._Starttime = now - (self._currentframe*self._frametime)
	--AddToQueue(now,self.GetFrame,self)
	--table.insert(self.Queue,{t=now,cb=self.GetFrame,args=self})
	--if self.Audio.Dev then
		--self.Audio.Dev:pause(false)
	--end
end

function VideoFunctions.GetDuration(self)
	return self._duration
end

function VideoFunctions.GetFrame(self)
	local err, Data
	if self._NextStop or self._Paused then self._NextStop = false return end--Stop it

	if self._currentframe == 0 then
		self._resuming = true
		self._Starttime = socket.gettime()
		if self._Audio.Dev then
			self._Audio.Dev:pause(false)
		end
	end
	self._currentframe = self._currentframe + 1
	--if self.currentframe % 100 == 0 then
		--print("Video memory: ",collectgarbage("count"))
	--end
	if self._currentframe <= self._numframes then
		if self._currentframe > self._framerate+1 and math.floor(self._currentframe*self._frametime) % 20 == 0 then
			if not(send) then
				self._Audio.Channel:push({"Time",self._currentframe*self._frametime})
				print("Video memory: ",collectgarbage("count")/1024)
				send = true
			end
		else
			send = false
		end

		--print("VidTime",math.floor(self.currentframe*self.frametime*100)/100)
		Data = self._Stream:read(self._framesize)
		if Data then 
			self._Win.update = true
			self._texture:lock(Data,self._pitch)
			self._texture:unlock()
		end
	else
		local extradata = self._Stream:read(self._framesize)
		if extradata then
			print("Extra data",#extradata)
		else
			print("Tom")
		end

		ActiveVideos[self]=nil
		self:Hide()
		self._Stream:close()
		if self._Audio.Dev then
			--AddToQueue(self.Queue,socket.gettime()+1,self.AudioDev.close,self.AudioDev)
			print("Stopping audio")
			self._Audio.Dev:pause(true)
		end
		return AddToQueue(socket.gettime()+1,self.Reload,self)
	end
	--self:Pause()
	if self._Resuming then
		if self._Audio.Dev then
			self._Audio.Dev:pause(false)
		end
		self._Resuming = false
	end
	local Nextframe = self._Starttime + (self._currentframe+1)*(1/self._framerate)
	return AddToQueue(Nextframe,self.GetFrame,self)
end

function VideoFunctions.Load(self)
	if not(self._loaded) then
		self._Stream  = io.popen('ffmpeg -i "'..self._filepath..'" -c:v rawvideo -pix_fmt yuv420p -f rawvideo pipe:1 -loglevel warning',"rb")
		self._loaded = true
		self._Audio = CreateAudio(self._audiopath,self._Sample,self._Channels)
		--Prepare Texture
		self._Win.update = true
		self._texture, err = self._Win._Rdr:createTexture(SDL.pixelFormat.IYUV,SDL.textureAccess.Streaming,self._texwidth,self._texheight)
		if not self._texture then
			error(err)
		end
	end
end

function VideoFunctions.Reload(self)
--if true then return end
	print("Reloading")
	self._Stream  = io.popen('ffmpeg -i "'..self._filepath..'" -c:v rawvideo -pix_fmt yuv420p -f rawvideo pipe:1 -loglevel warning',"rb")
	print("Got stream")
	self._Audio.Channel:push("Restart")
	print("Got audio")
	self._currentframe=0
	self._started = false
end

local function PrepareVideo(channel,self,filepath,audiopath)
	assert(self,"Could not index self")
	assert(filepath, "Filepath missing")
	local Video = self
	function Video:Load()
		self._WaitLoad = true
	end
	function Video:Start()
		self._WaitStart = true
	end
	local rdr = self._Win.Rdr
	channel:push({filepath, audiopath}) --Get video meta
	local Data = coroutine.yield()
	for k,v in pairs(Data) do
		Video["_"..k] = v
	end
	if Video._height == 0 then
		Video._height = Video._texheight
	end
	if Video._width == 0 then
		Video._width = Video._texwidth
	end
	--Open Audio--
	audiopath = audiopath or filepath
	Video._filepath = filepath
	Video._audiopath = audiopath
	print("Video.Sample",Video._Sample, Video._Channels)
	--Video.Audio = CreateAudio(audiopath,Video.Sample,Video.Channels)
	--Prepare Texture
	--Video.texture, err = rdr:createTexture(SDL.pixelFormat.IYUV,SDL.textureAccess.Streaming,Video.texwidth,Video.texheight)
	--if not Video.texture then
	--	error(err)
	--end
	--Open video stream
	--Video.Stream  = io.popen('ffmpeg -i "'..filepath..'" -c:v rawvideo -pix_fmt yuv420p -f rawvideo pipe:1 -loglevel warning',"rb")
	--Set stuff
	Video._currentframe=0
	Video._pitch = tonumber(Video._texwidth*1.5)
	Video._framesize = Video._pitch*Video._texheight
	for k,v in pairs(VideoFunctions) do
		Video[k] = v
	end

	Video:UpdatePos()
	if Video._WaitLoad and not Video._WaitStart then
		Video._WaitLoad=nil
		Video:Load()
	end
	if Video._WaitStart then
		Video._WaitStart=nil
		Video:Load()
		Video:Start()
	end
	return
end

local function Out(self,filepath,audiopath)
	CreateCallback("VideoMeta",VideoMeta ,PrepareVideo,nil,self,filepath,audiopath)
end

return Out


