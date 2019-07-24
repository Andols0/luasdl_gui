print("start",...)
require("socket")
local SDL	= require "SDL"
local Audio = require("luasdl_gui.audio")
require("luasdl_gui.frame")
local floor = math.floor
Queue = {}
----Locals
local tinsert, tremove = table.insert, table.remove
local wrap = coroutine.wrap
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

local function SetBGColor(self,color,g,b,a)
	if g then
		self.BgColor = {r = color, g=g,b=b,a=a}
	else
		self.BgColor = color
	end
	self.BgColor = color
end

function CreateWindow(WindowSettings)
	local Window = {}
	Window.Win = SDL.createWindow(WindowSettings)
	Window.Rdr = SDL.createRenderer(Window.Win, -1)
	Window.Layer = {BACKGROUND = {}, LOW = {}, MEDIUM = {}, HIGH = {}}
	Window.BgColor= 0x0a40e0
	Window.Rdr:setDrawColor(Window.BgColor)
	Window.Rdr:setDrawBlendMode(SDL.blendMode.Blend)
	Window.SetBGColor = SetBGColor
	Windows[Window.Win:getID()]=Window
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

function CreateCallback(Name,fu,f,cr,...)
	if f and cr then error("Argument 3 or 4 needs to be nil") end
	local path
	print(type(fu))
	if not Threads[Name] then
		if type(fu) == "nil" then
			if CheckFile(Name..".lua",true) then
				path = Name..".lua"
			elseif CheckFile(Name.."/"..Name..".lua") then
				path = Name.."/"..Name..".lua"
			else
				error("File does not exist")
			end
		elseif type(fu) == "function" then
			path = fu
		else
			error("File or function not found") 
		end
		Threads[Name] = {
			t = SDL.createThread(Name,path),
			co = SDL.getChannel(Name.."out"),
			ci = SDL.getChannel(Name.."in")
		}
		print(Threads[Name].t)
	end
	Threads[Name].ci:push("wip")
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
		if Frame.MouseEnabled and Frame.shown then
			if (Frame.x<=x and Frame.y<=y) and (Frame.x+Frame.width >= x and Frame.y+Frame.height >= y) then
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
	if CheckFrames(Win.Layer.HIGH,x,y) then
		return
	elseif CheckFrames(Win.Layer.MEDIUM,x,y) then
		return
	elseif CheckFrames(Win.Layer.LOW,x,y) then
		return
	elseif CheckFrames(Win.Layer.BACKGROUND,x,y) then
		return
	else
		if mouseisover then
			PushEvent("OnLeave",mouseisover)
		end
		mouseisover=nil
	end
end


local function Render(Win)
	local Rdr = Win.Rdr
	Rdr:setDrawColor(Win.BgColor)
	Rdr:clear()
	for k,v in pairs(Win.Layer.BACKGROUND) do
		if v.shown == true then
			if v.Draw then
				Rdr:setDrawColor(v.color)
				Rdr[v.Draw](Rdr,v.obj)
			elseif v.crop then
				Rdr:copy(v.texture,{w = v.crop.w, h=v.crop.h, x= v.crop.x, y = v.crop.y},{w = v.width, h= v.height, x = v.x, y = v.y})
			else
				Rdr:copy(v.texture,nil,{w = v.width, h= v.height, x = v.x, y = v.y})
			end
		end
	end
	for k,v in pairs(Win.Layer.LOW) do
		if v.shown == true then
			if v.Draw then
				Rdr:setDrawColor(v.color)
				Rdr[v.Draw](Rdr,v.obj)
			elseif v.crop then
				Rdr:copy(v.texture,{w = v.crop.w, h=v.crop.h, x= v.crop.x, y = v.crop.y},{w = v.width, h= v.height, x = v.x, y = v.y})
			else
				Rdr:copy(v.texture,nil,{w = v.width, h= v.height, x = v.x, y = v.y})
			end
		end
	end
	for k,v in pairs(Win.Layer.MEDIUM) do
		if v.shown == true then
			if v.Draw then
				Rdr:setDrawColor(v.color)
				Rdr[v.Draw](Rdr,v.obj)
			elseif v.crop then
				Rdr:copy(v.texture,{w = v.crop.w, h=v.crop.h, x= v.crop.x, y = v.crop.y},{w = v.width, h= v.height, x = v.x, y = v.y})
			else
				Rdr:copy(v.texture,nil,{w = v.width, h= v.height, x = v.x, y = v.y})
			end
		end
	end
	for k,v in pairs(Win.Layer.HIGH) do
		if v.shown == true then
			if v.Draw then
				Rdr:setDrawColor(v.color)
				Rdr[v.Draw](Rdr,v.obj)
			elseif v.crop then
				Rdr:copy(v.texture,{w = v.crop.w, h=v.crop.h, x= v.crop.x, y = v.crop.y},{w = v.width, h= v.height, x = v.x, y = v.y})
			else
				Rdr:copy(v.texture,nil,{w = v.width, h= v.height, x = v.x, y = v.y})
			end
		end
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
			print("Quit")
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
		elseif e.type == SDL.event.MouseMotion then
			--print(string.format("mouse motion: x=%d, y=%d on screen %d", e.x, e.y,e.windowID))
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
		if Diff > 10 then
			SDL.delay(10)
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
		SDL.delay(10)
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
			local a= v[1](resp)
			tremove(v,1)
			if #v == 0 then
				Async.Callbacks[N]=nil
			end
		end
	end
end
local format = string.format
Timetable = {Async = {}, Events = {}, Queue = {}, Render = {}}
local tid, tid2, tid3, tid4

function Quittime()
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
	for i,t in pairs(Timetable.Queue) do
		tid = tid + t
		Num = i
	end
	print(format("Time spent in Queue function %d seconds, with an average of %s ms",tid,floor(tid/Num*100000)/100))
	tid = 0
	Num = 1
	for i,t in pairs(Timetable.Render) do
		tid = tid + t
		Num = i
	end
	print(format("Time spent in Render function %d seconds, with an average of %s ms",tid,floor(tid/Num*100000)/100))
end
running = true

function Main()
	while running do  --The main looopppp
		tid = socket.gettime()

		HandleAsync()

		tid2= socket.gettime()
		tinsert(Timetable.Async,tid2-tid)

		running = ScreenEvents()

		tid3 = socket.gettime()
		tinsert(Timetable.Events,tid3-tid2)

		WorkQueue()

		tid4 = socket.gettime()
		tinsert(Timetable.Queue,tid4-tid3-0.01)

		for _,Win in pairs(Windows) do
			Render(Win)
		end

		tinsert(Timetable.Render,socket.gettime()-tid4)
	end

	print("Bye!!")
	SDL.audioQuit()
	SDL.quit()
	Quittime()
end
