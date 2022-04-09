local socket = require "socket"
local SDL	= require "SDL"
local floor = math.floor
local Queue = {}
----Locals
local core = {}
local Running
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
local function pt(t)
	print("Printing table:",t)
	for k,v in pairs(t) do
		print(k,v)
	end
end
pt({})
-----


function core.CheckFile(filepath,notblock)
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
local CheckFile = core.CheckFile
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

function WindowFunctions.setFullscreen(self,state)
	if state == true then
		self._Win:setFullscreen(SDL.window.Desktop)
	else
		self._Win:setFullscreen(0)
	end
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

function WindowFunctions.SetSize(self,width,height)
	self._update = true
	self._Win:setSize(width,height)
end

function WindowFunctions.SetTitle(self,Title)
	self._Win:setTitle(Title)
end

function WindowFunctions.GetMousePos(self)
	return self._Mousex, self._Mousey
end

function core.AddWinFunction(name,f)
	WindowFunctions[name] = f
end

function core.CreateWindow(WindowSettings)
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

local Threads = {}

function core.AddToQueue(Time,Callback,...)
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

function core.after(delay,...)
	local Time = SDL.getTicks() + delay
	core.AddToQueue(Time,...)
end

function core.OnIdle(f,cr)
	if f and cr then error("Please supply one function OR a coruttine") end
	local coro
	if f then
		coro = wrap(f)
	else
		coro = cr
	end
	table.insert(Async.CanWait,coro)
end

function core.CreateCallback(Name,fu,f,cr,...)
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
		local Frame = Layer[i]
		if Frame._MouseEnabled and Frame._shown then
			if (Frame._x<=x and Frame._y<=y) and (Frame._x+Frame._width >= x and Frame._y+Frame._height >= y) then
				if mouseisover~=Frame then
					if mouseisover then
						Layer.PushEvent("OnLeave",mouseisover)
					end
					mouseisover = Frame
					Layer.PushEvent("OnEnter",Frame)
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
			Win.PushEvent("OnLeave",mouseisover)
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
			Win.PushEvent("OnLeave",mouseisover)
		end
		mouseisover=nil
	end
end

local function Place(Rdr,v)
	if v._shown == true and (v._texture or v._Draw) then
		if v._Draw then
			Rdr:setDrawColor(v._color)
			Rdr[v._Draw](Rdr,v._obj)
		elseif v._angle  ~= 0 or v._flip ~= SDL.rendererFlip.None then
			Rdr:copyEx({
				texture = v._texture,
				source = v._crop,
				destination = {w = v._width, h= v._height, x = v._x, y = v._y},
				angle = v._angle,
				flip = v._flip}
			)
		else
			if v._crop then
				Rdr:copy(v._texture,{w = v._crop.w, h=v._crop.h, x= v._crop.x, y = v._crop.y},{w = v._width, h= v._height, x = v._x, y = v._y})
			else
				Rdr:copy(v._texture,nil,{w = v._width, h= v._height, x = v._x, y = v._y})
			end
		end
	end
end
local lastrender = {}
local function Render(Win)
	if lastrender[Win] and SDL.getTicks() < lastrender[Win] + 10 then --Limit to a 100fps render
		return false
	end
	local Rdr = Win._Rdr
	Rdr:setDrawColor(Win._BgColor)
	Rdr:clear()
	for _,v in ipairs(Win._Layer.BACKGROUND) do
		Place(Rdr,v)
	end
	for _,v in ipairs(Win._Layer.LOW) do
		Place(Rdr,v)
	end
	for _,v in ipairs(Win._Layer.MEDIUM) do
		Place(Rdr,v)
	end
	for _,v in ipairs(Win._Layer.HIGH) do
		Place(Rdr,v)
	end
	Rdr:present()
	--lastrender[Win] = SDL.getTicks()
	return true
end


--[[local filter = SDL.setEventFilter(function(e)
	if e.windowID==1 or e.type == SDL.event.WindowEvent then
		return true
	else
		return false
	end
end)]] --Vad är detta?

local function ScreenEvents()
    for e in SDL.pollEvent() do
        local CurrentWindow = Windows[e.windowID]
		if e.type == SDL.event.WindowEvent and e.event==SDL.eventWindow.Close then
			CurrentWindow:Hide()
            CurrentWindow:_CloseF()
            --Windows[e.windowID]:_CloseF()
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
				CurrentWindow:PushChar(KeyName)
			elseif KeyName == "V" then
				for _,v in pairs(e.keysym.mod) do
					if v==64 then
						local Text = SDL.getClipboardText()
						if type(Text) == "string" then
							CurrentWindow:PushChar(Text)
						end
					end
				end
			end
		elseif e.type == SDL.event.TextInput then
			CurrentWindow:PushChar(e.text)
		--elseif e.type == SDL.event.MouseWheel then
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
				CurrentWindow.PushEvent("OnClick",mouseisover,Button)
			end

		--elseif e.type == SDL.event.WindowEvent and e.event==SDL.eventWindow.Enter then

		elseif e.type == SDL.event.WindowEvent and e.event==SDL.eventWindow.Leave then
			--IsMouseOVer(Windows[e.windowID],nil)
			--Windows[e.windowID]._Mousex = -math.huge
            --Windows[e.windowID]._Mousey = -math.huge
            IsMouseOVer(CurrentWindow,nil)
            CurrentWindow._Mousex = -math.huge
            CurrentWindow._Mousey = -math.huge
		elseif e.type == SDL.event.MouseMotion then
			--print(string.format("mouse motion: x=%d, y=%d on screen %d", e.x, e.y,e.windowID))
            CurrentWindow._Mousex = e.x
            CurrentWindow._Mousey = e.y
            IsMouseOVer(CurrentWindow,e.x,e.y)
            --Windows[e.windowID]._Mousex = e.x
			--Windows[e.windowID]._Mousey = e.y
			--IsMouseOVer(Windows[e.windowID],e.x,e.y)
		end
	end
	return true
end

local function WorkQueue()
	local Now = SDL.getTicks()
	--print("Numqueue",#Queue)
    while Queue[1] and Queue[1].t <=Now do
	--if Queue[1] and Queue[1].t <=Now then
        local Pos = Queue[1]
        local Cb = Pos.cb
        local Args = Pos.args
        tremove(Queue,1)
        Cb(Args)
    end
	--print(#Queue)
end

local function HandleAsync()
	local HaveIdle = false
	for i,f in pairs(Async.CanWait) do
        --print(socket.gettime())
        HaveIdle = true
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
			v[1](resp)
			tremove(v,1)
			if #v == 0 then
				Async.Callbacks[N]=nil
			end
		end
	end
	return HaveIdle
end
local format = string.format
local Timetable = {Start = socket.gettime(), Async = {}, Events = {}, Queue = {}, Render = {}, Delaying = {}}
local tid

local Garbageshit = {
	Async = {},
	Events = {},
	Queue = {},
	Render = {}
}

local function Quittime()
	print(format("This sesson was %d seconds",socket.gettime()-Timetable.Start))
	local Num, gar
	tid = 0
	Num=1
	for i,t in pairs(Timetable.Async) do
		tid = tid + t
		Num = i
	end

	gar	= 0
	for _,g in pairs(Garbageshit.Async) do
		gar = gar + g
	end
	print(format("Time spent in Async function %d seconds, with an average of %s ms\nWith a total garbage of %d",tid,floor(tid/Num*100000)/100,gar))
	tid = 0
	Num = 1
	for i,t in pairs(Timetable.Events) do
		tid = tid + t
		Num = i
	end

	gar	= 0
	for _,g in pairs(Garbageshit.Events) do
		gar = gar + g
	end

	print(format("Time spent in Event function %d seconds, with an average of %s ms\nWith a total garbage of %d",tid,floor(tid/Num*100000)/100,gar))
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


	gar	= 0
	for _,g in pairs(Garbageshit.Queue) do
		gar = gar + g
	end
	print(format("Time spent in Queue function %d seconds, with an average of %s ms\nWith a total garbage of %d",tid-Delaytime,floor((tid-Delaytime)/Num*100000)/100,gar))
	tid = 0
	Num = 1
	for i,t in pairs(Timetable.Render) do
		tid = tid + t
		Num = i
	end


	gar	= 0
	for _,g in pairs(Garbageshit.Render) do
		gar = gar + g
	end
	print(format("Time spent in Render function %d seconds, with an average of %s ms\nWith a total garbage of %d",tid,floor(tid/Num*100000)/100,gar))
end

function core.CloseApp()
	CLOSE = true
end


function core.Main(Step)
    Running = true
    local HaveIdle
	while Running do  --The main looopppp
		HaveIdle = HandleAsync()
		ScreenEvents()
		WorkQueue()
        Running = false --Closes if all the windows are hidden
        for _,Win in pairs(Windows) do
            if Win._update then
                --print("Updating win:",_)
                if Render(Win) then
					Win._update = false
				end
            end
            if Win._shown then
                Running = true
            end
        end
        if CLOSE then
			break
		end
        if Running == false then
            CLOSE = true
            break
        elseif Step then
            break
        end
        if not HaveIdle then
            SDL.delay(1)
        end
    end
    if CLOSE then
        core.Quit()

    end
end

function core.Step()
	core.Main(true)
end

function core.Quit()
    print("Bye!!")
	SDL.audioQuit()
    SDL.quit()
    --Quittime() Är inte aktiv och är trasig.
end

return core