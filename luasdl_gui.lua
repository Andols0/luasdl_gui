require("socket")
local SDL	= require "SDL"
local Audio = require("luasdl_gui.audio")
local Frames = require("luasdl_gui.frame")
local floor = math.floor
Queue = {}
----Locals
local tinsert, tremove = table.insert, table.remove
local wrap = coroutine.wrap
local CLOSE
local Windows = {}

local Async = {
	Callbacks = {},
	CanWait = {}
}

local ret, err = SDL.init( {
	SDL.flags.Video,
	SDL.flags.Audio
})

if not ret then
	error(err)
end

--Debug function
function pt(t)
	print("Printing table:",t)
	for k,v in pairs(t) do
		print(k,v)
	end
end

function CheckFile(filepath,notblock)
	local file = io.open(filepath)
	if notblock then
		if not file then
			return false
		else
			return true
		end
	else
		assert(file,"Invalid filepath: ",filepath)
	end
	file:close()
	return true
end

local WinInt = {}

local WinMeta = {}
function WinMeta:__tostring()
	return "Window: "..self._Win:getID()
end

function WinMeta:__newindex(key,value)
	if key:sub(1,1)=="_" then
		WinInt[self][key] = value
	else
		rawset(self,key,value)
	end
end


function WinMeta:__index(key)
	if key:sub(1,1) == "_" then
		return WinInt[self][key]
	else
		return nil
	end
end

local WindowFunctions = {}

function WindowFunctions.SetBGColor(self,color,g,b,a)
	if g then
		self._BgColor = {r = color, g=g,b=b,a=a}
	else
		self._BgColor = color
	end
	self._BgColor = color
end

function WindowFunctions.Hide(self)
	self._Win:hide()
	self._shown = false
end

function WindowFunctions.Show(self)
	self._update = true
	self._Win:show()
	if self._shown then
		self._Win:raise()
	end
	self._shown = true
end

function WindowFunctions.OnClose(self,f)
	self._CloseF = f
end

function WindowFunctions.getSize(self)
	return self._Win:getSize()
end

function WindowFunctions.GetMousePos(self)
	return self._Mousex, self._Mousey
end


function CreateWindow(WindowSettings)
	local Window = setmetatable({},WinMeta)
	WinInt[Window] = {}
	Window._Win = SDL.createWindow(WindowSettings)
	Window._Rdr = SDL.createRenderer(Window._Win, -1)
	Window._Layer = {BACKGROUND = {}, LOW = {}, MEDIUM = {}, HIGH = {}}
	Window._BgColor= 0x0a40e0
	Window._Rdr:setDrawColor(Window._BgColor)
	Window._Rdr:setDrawBlendMode(SDL.blendMode.Blend)
	Window._update = true
	Window._shown = true
	Window._CloseF = function() return end
	Windows[Window._Win:getID()]=Window

	for k,v in pairs(WindowFunctions) do
		Window[k] = v
	end
	return Window
end

Threads = {}

function AddToQueue(Time,Callback,...)
	--print(debug.traceback())
	if #Queue>0 then
		for i=1, #Queue do
			if Time < Queue[i].t then
				table.insert(Queue,i,{t=Time,cb = Callback,args=...})
				return
			end
		end
		table.insert(Queue,{t=Time,cb = Callback,args=...})
		return
	else
		table.insert(Queue,{t=Time,cb = Callback,args=...})
	end
	return
end

function OnIdle(f,cr)
	if f and cr then error("Please supply one function OR a coruttine") end
	local coro
	if f then
		coro = wrap(f)
	else
		coro = cr
	end
	table.insert(Async.CanWait,coro)
end
	
function CreateCallback(Name,fu,f,cr,...)
	--f and cr is the function or coroutine that is supposed to be 
	if f and cr then error("Argument 3 or 2 can't both be true") end --One already created coroutine or a function to create one
	local path --Path (function or filepath) to the thread that is supposed to be created
	if not Threads[Name] then --Is this type of thread loaded?
		if type(fu) == "nil" then	--If there is no function look for a file (used?)
			if CheckFile(Name..".lua",true) then
				path = Name..".lua"
			elseif CheckFile(Name.."/"..Name..".lua") then
				path = Name.."/"..Name..".lua"
			else
				error("File does not exist")
			end
		elseif type(fu) == "function" then --If there is a function add that
			path = fu
		else
			error("File or function not found") 
		end
		Threads[Name] = { --Create the thread and channel
			t = SDL.createThread(Name,path),
			co = SDL.getChannel(Name.."out"),
			ci = SDL.getChannel(Name.."in")
		}
	end
	Threads[Name].ci:push("wip") --Can the PR fix this shit?
	local Channel = Threads[Name].co
	local Callbacks = Async.Callbacks
	if not Callbacks[Name] then Callbacks[Name] = {} end
	local Coro
	if f then
		Coro = wrap(f)
	else
		Coro =cr
	end
	tinsert(Callbacks[Name],Coro)
	return Coro(Channel,...)
end

local mouseisover
local function CheckFrames(Layer,x,y)
	for i=#Layer, 1 ,-1 do
		Frame = Layer[i]
		if Frame._MouseEnabled and Frame._shown then
			if (Frame._x<=x and Frame._y<=y) and (Frame._x+Frame._width >= x and Frame._y+Frame._height >= y) then
				if mouseisover~=Frame then
					if mouseisover then
						PushEvent("OnLeave",mouseisover)
					end
					mouseisover = Frame
					PushEvent("OnEnter",Frame)
				end
				return true
			end
		end
	end
	return false
end

local function IsMouseOVer(Win,x,y)
	if x == nil then
		if mouseisover then
			PushEvent("OnLeave",mouseisover)
			mouseisover=nil
		end
		return
	end
	if CheckFrames(Win._Layer.HIGH,x,y) then
		return
	elseif CheckFrames(Win._Layer.MEDIUM,x,y) then
		return
	elseif CheckFrames(Win._Layer.LOW,x,y) then
		return
	elseif CheckFrames(Win._Layer.BACKGROUND,x,y) then
		return
	else
		if mouseisover then
			PushEvent("OnLeave",mouseisover)
		end
		mouseisover=nil
	end
end

local function Place(Rdr,v)
	if v._shown == true and (v._texture or v._Draw) then
		if v._Draw then
			Rdr:setDrawColor(v._color)
			Rdr[v._Draw](Rdr,v._obj)
		elseif v._crop then
			Rdr:copy(v._texture,{w = v._crop.w, h=v._crop.h, x= v._crop.x, y = v._crop.y},{w = v._width, h= v._height, x = v._x, y = v._y})
		else
			Rdr:copy(v._texture,nil,{w = v._width, h= v._height, x = v._x, y = v._y})
		end
	end
end

local function Render(Win)
	local Rdr = Win._Rdr
	Rdr:setDrawColor(Win._BgColor)
	Rdr:clear()
	for k,v in pairs(Win._Layer.BACKGROUND) do
		Place(Rdr,v)
		--Place(v) Remove the rest when i got the frameshit working again
		--[[if v._shown == true then
			if v.Draw then
				Rdr:setDrawColor(v.color)
				Rdr[v.Draw](Rdr,v.obj)
			elseif v.crop then
				Rdr:copy(v.texture,{w = v.crop.w, h=v.crop.h, x= v.crop.x, y = v.crop.y},{w = v.width, h= v.height, x = v.x, y = v.y})
			else
				Rdr:copy(v.texture,nil,{w = v.width, h= v.height, x = v.x, y = v.y})
			end
		end]]
	end
	for k,v in pairs(Win._Layer.LOW) do
		Place(Rdr,v)
		--[[if v.shown == true then
			if v.Draw then
				Rdr:setDrawColor(v.color)
				Rdr[v.Draw](Rdr,v.obj)
			elseif v.crop then
				Rdr:copy(v.texture,{w = v.crop.w, h=v.crop.h, x= v.crop.x, y = v.crop.y},{w = v.width, h= v.height, x = v.x, y = v.y})
			else
				Rdr:copy(v.texture,nil,{w = v.width, h= v.height, x = v.x, y = v.y})
			end
		end]]
	end
	for k,v in pairs(Win._Layer.MEDIUM) do
		Place(Rdr,v)
		--[[if v.shown == true then
			if v.Draw then
				Rdr:setDrawColor(v.color)
				Rdr[v.Draw](Rdr,v.obj)
			elseif v.crop then
				Rdr:copy(v.texture,{w = v.crop.w, h=v.crop.h, x= v.crop.x, y = v.crop.y},{w = v.width, h= v.height, x = v.x, y = v.y})
			else
				Rdr:copy(v.texture,nil,{w = v.width, h= v.height, x = v.x, y = v.y})
			end
		end]]
	end
	for k,v in pairs(Win._Layer.HIGH) do
		Place(Rdr,v)
		--[[if v.shown == true then
			if v.Draw then
				Rdr:setDrawColor(v.color)
				Rdr[v.Draw](Rdr,v.obj)
			elseif v.crop then
				Rdr:copy(v.texture,{w = v.crop.w, h=v.crop.h, x= v.crop.x, y = v.crop.y},{w = v.width, h= v.height, x = v.x, y = v.y})
			else
				Rdr:copy(v.texture,nil,{w = v.width, h= v.height, x = v.x, y = v.y})
			end
		end]]
	end
	Rdr:present()
end


local filter = SDL.setEventFilter(function(e)
	if e.windowID==1 or e.type == SDL.event.WindowEvent then
		return true
	else
		return false
	end
end)

local function ScreenEvents()
	for e in SDL.pollEvent() do
		if e.type == SDL.event.WindowEvent and e.event==SDL.eventWindow.Close then
			--Windows[e.windowID]:hide()
			Windows[e.windowID]:_CloseF()
			print("Hiding window:",e.windowID)
			return false
		elseif e.type == SDL.event.DropFile then
			print("File dropped!!!")
			for k,v in pairs(e) do
				print(k,v)
			end
		elseif e.type == SDL.event.KeyDown then
			--print(string.format("key down: %d -> %s on screen %d ", e.keysym.sym, SDL.getKeyName(e.keysym.sym),e.windowID))
			local KeyName = SDL.getKeyName(e.keysym.sym)
			if KeyName == "Backspace" or KeyName == "Escape" then
				PushChar(KeyName)
			elseif KeyName == "V" then
				for _,v in pairs(e.keysym.mod) do
					if v==64 then
						local Text = SDL.getClipboardText()
						if type(Text) == "string" then
							PushChar(Text)
						end
					end
				end
			end
		elseif e.type == SDL.event.TextInput then
			PushChar(e.text)
		elseif e.type == SDL.event.MouseWheel then
			--print(string.format("mouse wheel: %d, x=%d, y=%d on screen %d", e.which, e.x, e.y,e.windowID))
		elseif e.type == SDL.event.MouseButtonDown then
			--print(string.format("mouse button down: %d, x=%d, y=%d on screen %d", e.button, e.x, e.y,e.windowID))
			local Button
			if e.button == 1 then
				Button = "Left"
			elseif e.button == 2 then
				Button = "Middle"
			elseif e.button == 3 then
				Button = "Right"
			end
			if mouseisover then
				PushEvent("OnClick",mouseisover,Button)
			end

		elseif e.type == SDL.event.WindowEvent and e.event==SDL.eventWindow.Enter then

		elseif e.type == SDL.event.WindowEvent and e.event==SDL.eventWindow.Leave then
			IsMouseOVer(Windows[e.windowID],nil)
			Windows[e.windowID]._Mousex = -math.huge
			Windows[e.windowID]._Mousey = -math.huge
		elseif e.type == SDL.event.MouseMotion then
			--print(string.format("mouse motion: x=%d, y=%d on screen %d", e.x, e.y,e.windowID))
			Windows[e.windowID]._Mousex = e.x
			Windows[e.windowID]._Mousey = e.y
			IsMouseOVer(Windows[e.windowID],e.x,e.y)
		end
	end
	return true
end

local function WorkQueue()
	local Now = socket.gettime()
	--print("Numqueue",#Queue)
	local Pos = Queue[1]
	local Diff
	if Pos then
		if Pos.t<=Now then
			--print("Shortcut")
			local Cb = Pos.cb
			local Args = Pos.args
			tremove(Queue,1)
			Cb(Args)
			
			return
		end
	end
	if Pos then
		Diff = (Pos.t-Now)*1000
		--print("Diff",math.floor(Diff))
		if Diff > 1 then
			SDL.delay(1)
			return
		end
		if Diff<0 then
			local Cb = Pos.cb
			local Args = Pos.args
			tremove(Queue,1)
			Cb(Args)
			return
		else
			
			if Diff>0 then
				SDL.delay(math.floor(Diff))
			else
				while socket.gettime()<Pos.t do print("WASTED") end
				local Cb = Pos.cb
				local Args = Pos.args
				tremove(Queue,1)
				Cb(Args)
				return
			end
		end
	else
		SDL.delay(1)
	end

end

local function HandleAsync()
	for i,f in pairs(Async.CanWait) do
		local done = f()
		if done then
			tremove(Async.CanWait,i)
		end
	end
	for N,v in pairs(Async.Callbacks) do
		local Channel = Threads[N].ci
		local resp = Channel:first()
		if resp and resp~="wip" then
			Channel:pop()
			print(N)
			local a= v[1](resp)
			tremove(v,1)
			if #v == 0 then
				Async.Callbacks[N]=nil
			end
		end
	end
end
local format = string.format
local realdelay = SDL.delay
function SDL.delay(time)
	table.insert(Timetable.Delaying,time/1000)
	realdelay(time)
end
Timetable = {Start = socket.gettime(), Async = {}, Events = {}, Queue = {}, Render = {}, Delaying = {}}
local tid, tid2, tid3, tid4

function Quittime()
	print(format("This sesson was %d seconds",socket.gettime()-Timetable.Start))
	local Num=1
	local tid = 0
	Num=1
	for i,t in pairs(Timetable.Async) do
		tid = tid + t
		Num = i
	end
	print(format("Time spent in Async function %d seconds, with an average of %s ms",tid,floor(tid/Num*100000)/100))
	tid = 0
	Num = 1
	for i,t in pairs(Timetable.Events) do
		tid = tid + t
		Num = i
	end
	print(format("Time spent in Event function %d seconds, with an average of %s ms",tid,floor(tid/Num*100000)/100))
	tid = 0
	Num = 1
	local Delaytime = 0
	for _,t in pairs(Timetable.Delaying) do
		Delaytime = Delaytime + t
	end
	for i,t in pairs(Timetable.Queue) do
		tid = tid + t
		Num = i
	end
	print(format("Time spent in Queue function %d seconds, with an average of %s ms",tid-Delaytime,floor((tid-Delaytime)/Num*100000)/100))
	tid = 0
	Num = 1
	for i,t in pairs(Timetable.Render) do
		tid = tid + t
		Num = i
	end
	print(format("Time spent in Render function %d seconds, with an average of %s ms",tid,floor(tid/Num*100000)/100))
end
running = true

function CloseApp()
	CLOSE = true
end

function Main()
	while running do  --The main looopppp
		tid = socket.gettime()

		HandleAsync()

		tid2= socket.gettime()
		tinsert(Timetable.Async,tid2-tid)

		ScreenEvents()

		tid3 = socket.gettime()
		tinsert(Timetable.Events,tid3-tid2)

		WorkQueue()

		tid4 = socket.gettime()
		tinsert(Timetable.Queue,tid4-tid3)
		running = false
		for _,Win in pairs(Windows) do
			if Win._update then
				--print("Updating win:",_)
				Render(Win)
				Win._update = false
			end
			if Win._shown then
				running = true
			end
		end
		tinsert(Timetable.Render,socket.gettime()-tid4)
		if CLOSE then
			break
		end
	end

	print("Bye!!")
	SDL.audioQuit()
	SDL.quit()
	Quittime()
end
