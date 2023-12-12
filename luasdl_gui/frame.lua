local image = require("SDL.image")
local ttf = require("SDL.ttf")
local SDL	= require "SDL"
local core = require("luasdl_gui.core")
local rw = require("luasdl_gui.imagerw")
local PrepareVideo = require("luasdl_gui.video")
local FRAME = {}
local tinsert, tremove = table.insert, table.remove
local formats, ret, err = image.init { image.flags.PNG, image.flags.JPG }

if not formats[image.flags.PNG] then
	error(err,ret)
end

ret, err = ttf.init()
if not ret then
	error(err)
  end


local Frames = setmetatable({},{__mode = "k"})
local Typetable = setmetatable({},{__mode = "k"})



local CommonFunctions, CommonWEvents = {}, {}
local FrameFunctions = {}
local ButtonFunctions, ButtonWEvents = {}, {}
local FontFunctions = {}
local EditBoxFunctions, EditBoxWEvents = {}, {}
local DrawSquareFunctions = {}
local DrawLineFunctions = {}

local HiddenWEvents, UserWEvents = {}, {}

local ButtonTextures = {}
local pointData = {}
local Children = {}


local TextureCache = {}
local function LoadImage(rdr,path)
	local img, err = image.load(path)
	if not img then
		error(err)
	end
	local tex = rdr:createTextureFromSurface(img)
	TextureCache[path] = tex
	return tex
end

local function LoadrawImage(rdr,data)
	rw:write(data)
	local img, err = image.load_RW(rw)
	if not img then
		error(err)
	end
	local tex = rdr:createTextureFromSurface(img)
	TextureCache[data] = tex
	return tex
end

local function CreateTexture(rdr,texturePath,raw)
	if TextureCache[texturePath] then
		return TextureCache[texturePath]
	end
	if raw then
		return LoadrawImage(rdr,texturePath)
	else
		core.CheckFile(texturePath)
		return LoadImage(rdr,texturePath)
	end
end

local function GetParentData(Parent)
	local Data = pointData[Parent]
	local point = Data.point
	--local Basex = Data.Basex or 0
	--local Basey = Data.Basey or 0
	local width = Parent._width
	local height = Parent._height
	local x, y = Parent._x, Parent._y
	--if point == "TOPLEFT" then --Set base x and y depending on the anchor point
		--Is already the correct
	--else
	if point == "TOP" then
		x = x --+ width/2
		y = y
	elseif point == "TOPRIGHT" then
		x = x -- width
		y = y
	elseif point == "RIGHT" then
		x = x -- width
		y = y -- height/2
	elseif point == "BOTTOMRIGHT" then
		x = x -- width
		y = y -- height
	elseif point == "BOTTOM" then
		x = x -- width/2
		y = y -- height
	elseif point == "BOTTOMLEFT" then
		x = x
		y = y -- height
	elseif point == "LEFT" then
		x = x
		y = y -- height/2
	elseif point == "CENTER" then
		x = x -- width/2
		y = y -- height/2
	end
	return x, y, width, height
end

local function UpdatePoint(self)
	local width = self._width or 0
	local height = self._height or 0
	local Data = pointData[self]
	local point = Data.point
	local Rpoint = Data.relativePoint
	local ofsx = Data.ofsx or 0
	local ofsy = Data.ofsy or 0
	if point == "TOPLEFT" then --Set base x and y depending on the anchor point
		Data.Basex = 0
		Data.Basey = 0
	elseif point == "TOP" then
		Data.Basex = -width/2
		Data.Basey = 0
	elseif point == "TOPRIGHT" then
		Data.Basex = -width
		Data.Basey = 0
	elseif point == "RIGHT" then
		Data.Basex = -width
		Data.Basey = -height/2
	elseif point == "BOTTOMRIGHT" then
		Data.Basex = -width
		Data.Basey = -height
	elseif point == "BOTTOM" then
		Data.Basex = -width/2
		Data.Basey = -height
	elseif point == "BOTTOMLEFT" then
		Data.Basex = 0
		Data.Basey = -height
	elseif point == "LEFT" then
		Data.Basex = 0
		Data.Basey = -height/2
	elseif point == "CENTER" then
		Data.Basex = -width/2
		Data.Basey = -height/2
	else
		error("Invalid point")
	end
	local Px, Py, Pw, Ph
	if Data.relativeTo then --Set base depending on the parent
		Px, Py, Pw, Ph = GetParentData(Data.relativeTo)
	else
		Px, Py, Pw, Ph = 0, 0, self._Win:getSize()
	end
	if Rpoint == "TOPLEFT" then --Set base x and y depending on the anchor point
		Data.Basex = Data.Basex + Px
		Data.Basey = Data.Basey + Py
	elseif Rpoint == "TOP" then
		Data.Basex = Data.Basex + Pw/2 + Px
		Data.Basey = Data.Basey + Py
	elseif Rpoint == "TOPRIGHT" then
		Data.Basex = Data.Basex + Pw + Px
		Data.Basey = Data.Basey + Py
	elseif Rpoint == "RIGHT" then
		Data.Basex = Data.Basex + Pw + Px
		Data.Basey = Data.Basey + Ph/2 + Py
	elseif Rpoint == "BOTTOMRIGHT" then
		Data.Basex = Data.Basex + Pw + Px
		Data.Basey = Data.Basey + Ph + Py
	elseif Rpoint == "BOTTOM" then
		Data.Basex = Data.Basex + Pw/2 + Px
		Data.Basey = Data.Basey + Ph + Py
	elseif Rpoint == "BOTTOMLEFT" then
		Data.Basex = Data.Basex + Px
		Data.Basey = Data.Basey + Ph + Py
	elseif Rpoint == "LEFT" then
		Data.Basex = Data.Basex + Px
		Data.Basey = Data.Basey + Ph/2 + Py
	elseif Rpoint == "CENTER" then
		Data.Basex = Data.Basex + Pw/2 + Px
		Data.Basey = Data.Basey + Ph/2 + Py
	else
		error("Invalid relativeTo point")
	end
	self._x = Data.Basex+ofsx
	self._y = Data.Basey+ofsy
	for _,v in pairs(Children[self]) do
		UpdatePoint(v)
	end
end

-------------Event Shit-----------------------
local function PushEvent(event,frame,...)
	--print("EventPushed",event,Frame)
	if HiddenWEvents[frame][event] then
		HiddenWEvents[frame][event](frame,...)
	end
end

local function PushChar(Win,char)
	if Win._ActiveEditBox then
		if char=="Backspace" then
			Win._ActiveEditBox:Backspace()
		elseif char=="Escape" then
			Win._ActiveEditBox=nil
		else
			Win._ActiveEditBox:AddLetter(char)
		end
	end
end
-------------Common functions-----------------
function CommonFunctions.SetSize(self, width, height)
	self._width = width
	self._height = height
	self._Win._update = true
	if pointData[self].point then
		UpdatePoint(self)
	end
end

function CommonFunctions.GetSize(self)
	return self._width, self._height
end

function CommonFunctions.SetAlpha(self,alpha)
	self._Win._update = true
	if alpha <= 1 then
		alpha = alpha * 255
	end
	self._texture:setAlphaMod(alpha)
end

local function ShowChildren(kids)
	for _,v in pairs(kids) do
		if v._Pshow and not(v._shown) then
			v._shown = true
			PushEvent("OnShow",v)
		end
		if Children[v] and v._Pshow then
			ShowChildren(Children[v])
		end
	end
end

local function HideChildren(kids)
	for _,v in pairs(kids) do
		if v._Pshow and v._shown then
			v._shown = false
			PushEvent("OnHide",v)
		end
		if Children[v] then
			HideChildren(Children[v])
		end
	end
end

function CommonFunctions.SetPoint(self, point, arg1, arg2, arg3, arg4)
	local relativeTo, relativePoint, ofsx, ofsy
	local relto = pointData[self].relativeTo
	self._Win._update = true
	if type(tonumber(arg1))=="number" then
		ofsx = tonumber(arg1) or 0
		ofsy = tonumber(arg2) or 0
		--Remove old relation
		if relto then
			for i,v in pairs(Children[relto]) do
				if v == self then
					tremove(Children[relto],i)
					break
				end
			end
		end
	end
	if type(arg1) == "table" then
		relativeTo = arg1
		--relativePoint = arg2 or point
		tinsert(Children[relativeTo],self)
		if tonumber(arg2) then
			ofsx = tonumber(arg2) or 0
			ofsy = tonumber(arg3) or 0
			relativePoint = point
		else
			relativePoint = arg2
			ofsx = tonumber(arg3) or 0
			ofsy = tonumber(arg4) or 0
		end
		--Remove old relation
		if relto and relto ~= relativeTo then
			for i,v in pairs(Children[relto]) do
				if v == self then
					tremove(Children[relto],i)
					break
				end
			end
		end
		if relativeTo._shown and self._Pshow then
			self._shown = true
			ShowChildren(Children[self])
		else
			self._shown = false
			HideChildren(Children[self])
		end
	end
	pointData[self].point=point
	pointData[self].ofsx=ofsx
	pointData[self].ofsy=ofsy
	pointData[self].relativeTo = relativeTo
	pointData[self].relativePoint = relativePoint or point
	UpdatePoint(self)
	return self._x, self._y
end


-------------------Common functions---------------
function CommonFunctions.Show(self)
	self._Win._update = true
	self._Pshow = true --If parent is changed to shown show this frame
	--Show if there is no parent or if parent is shown
	if not(pointData[self].relativeTo) or (pointData[self].relativeTo and pointData[self].relativeTo._shown) then
		self._shown = true
		PushEvent("OnShow",self)
		if Children[self] then
			ShowChildren(Children[self])
		end
	end
end

function CommonFunctions.Hide(self)
	self._Win._update = true
	self._shown = false
	self._Pshow = false
	PushEvent("OnHide",self)
	if Children[self] then
		HideChildren(Children[self])
	end
end

function CommonFunctions.IsShown(self)
	return self._Pshow == true
end

function CommonFunctions.IsVisible(self)
	return self._shown == true
end

function CommonFunctions.EnableMouse(self,status)
	self._MouseEnabled = status
end

function CommonFunctions.SetScript(self, Event, Callback)
	if HiddenWEvents[self][Event] then
		UserWEvents[self][Event] = Callback
	else
		error("Invalid event")
	end
end

function CommonFunctions.IsMouseOver(self)
	local x, y = self._Win:GetMousePos()
	if (self._x<=x and self._y<=y) and (self._x+self._width >= x and self._y+self._height >= y) then
		return true
	else
		return false
	end
end
------------Common Widget Events---------
function CommonWEvents.OnEnter(self,...)
	if UserWEvents[self].OnEnter then
		return UserWEvents[self].OnEnter(self,...)
	end
end

function CommonWEvents.OnLeave(self,...)
	if UserWEvents[self].OnLeave then
		return UserWEvents[self].OnLeave(self,...)
	end
end

function CommonWEvents.OnShow(self,...)
	if UserWEvents[self].OnShow then
		return UserWEvents[self].OnShow(self,...)
	end
end

function CommonWEvents.OnHide(self,...)
	if UserWEvents[self].OnHide then
		return UserWEvents[self].OnHide(self,...)
	end
end

------------Square Functions-------------
function DrawSquareFunctions.SetAlpha()
	--Can't do this
end

function DrawSquareFunctions.SetPoint(self,...)
	CommonFunctions.SetPoint(self,...)
	self._Win._update = true
	self._obj.x = self._x
	self._obj.y = self._y
end

function DrawSquareFunctions.SetSize(self,...)
	CommonFunctions.SetSize(self,...)
	self._Win._update = true
	self._obj.w = self._width
	self._obj.h = self._height
	self._obj.x = self._x
	self._obj.y = self._y
end

function DrawSquareFunctions.SetColor(self,color,g,b,a)
	self._Win._update = true
	if g then
		a = a or 255
		self._color = {r = color, g = g, b = b, a = a}
	elseif type(color) == "table" then
		color.a = color.a or 255
		self._color = color
	else
		self._color = color
	end
end

function DrawSquareFunctions.Filled(self, status)
	self._Win._update = true
	if status == true then
		self._Draw = "fillRect"
	else
		self._Draw = "drawRect"
	end
end

------------Line functions---------------

function DrawLineFunctions.SetStartPos(self,...)
	local x, y = CommonFunctions.SetPoint(self,...)
	self._obj.x1 = x
	self._obj.y1 = y
end

function DrawLineFunctions.SetEndPos(self,...)
	local x, y = CommonFunctions.SetPoint(self,...)
	self._obj.x2 = x
	self._obj.y2 = y
end

function DrawLineFunctions.SetColor(self,color,g,b,a)
	self._Win._update = true
	if g then
		a = a or 255
		self._color = {r = color, g = g, b = b, a = a}
	elseif type(color) == "table" then
		color.a = color.a or 255
		self._color = color
	else
		self._color = color
	end
end
------------Frame functions--------------
function FrameFunctions.SetTexture(self,texturePath,raw)
	self._texture = CreateTexture(self._Win._Rdr,texturePath,raw)
	self._angle = 0
	self._flip = SDL.rendererFlip.None
	self._Win._update = true
end

function FrameFunctions.SetRotation(self, angle)
	if self._texture then
		self._angle = angle
		self._Win._update = true
	end
end

function FrameFunctions.SetFlip(self, horizontal, vertical)
	if horizontal and vertical then
		error("Can't flip both vertical and horizontal")
	end
	if self._texture then
		if horizontal then
			self._flip = SDL.rendererFlip.Horizontal
		elseif vertical then
			self._flip = SDL.rendererFlip.Vertical
		else
			self._flip = SDL.rendererFlip.None
		end
		self._Win._update = true
	end
end

------------Button Widget Events---------
function ButtonWEvents.OnClick(self,...)
	local PushedTexture = ButtonTextures[self].PushedTexture
	if PushedTexture then
		self._Win._update = true
		self._texture = PushedTexture
	end
	if UserWEvents[self].OnClick then
		return UserWEvents[self].OnClick(self,...)
	end
end

function ButtonWEvents.OnEnter(self,...)--Overwrite common
	local HighlightTexture = ButtonTextures[self].HighlightTexture
	if HighlightTexture then
		self._Win._update = true
		self._texture = HighlightTexture
	end
	if UserWEvents[self].OnEnter then
		return UserWEvents[self].OnEnter(self,...)
	end
end

function ButtonWEvents.OnLeave(self,...)--Overwrite common
	local NormalTexture = ButtonTextures[self].NormalTexture
	if NormalTexture and not(self._highlock) then
		self._Win._update = true
		self._texture = NormalTexture
	end
	if UserWEvents[self].OnLeave then
		return UserWEvents[self].OnLeave(self,...)
	end
end
------------Button Functions------------


function ButtonFunctions.SetNormalTexture(self,texturePath,raw)
	ButtonTextures[self].NormalTexture = CreateTexture(self._Win._Rdr,texturePath,raw)
	self._Win._update = true
	self._texture = ButtonTextures[self].NormalTexture
end



function ButtonFunctions.SetPushedTexture(self,texturePath,raw)
	ButtonTextures[self].PushedTexture = CreateTexture(self._Win._Rdr,texturePath,raw)
end

function ButtonFunctions.SetHighlightTexture(self,texturePath,raw)
	ButtonTextures[self].HighlightTexture = CreateTexture(self._Win._Rdr,texturePath,raw)
end

function ButtonFunctions.SetDisabledTexture(self,texturePath,raw)
	ButtonTextures[self].DisabledTexture = CreateTexture(self._Win._Rdr,texturePath,raw)
end

function ButtonFunctions.LockHighlight(self)
	self._Win._update = true
	self._texture = ButtonTextures[self].HighlightTexture
	self._highlock = true
end

function ButtonFunctions.UnlockHighlight(self)
	if self:IsMouseOver() == false then
		self._Win._update = true
		self._texture = ButtonTextures[self].NormalTexture
	end
	self._highlock = false
end

function ButtonFunctions.GetHighlightlock(self)
	return self._highlock
end

function ButtonFunctions.SetEnabled(self,status)
	self:EnableMouse(status)
	if status == false then
		if ButtonTextures[self].DisabledTexture and not(self._highlock) then
			self._Win._update = true
			self._texture = ButtonTextures[self].DisabledTexture
		end
	elseif status == true then
		if ButtonTextures[self].NormalTexture and not(self._highlock) then
			self._Win._update = true
			self._texture = ButtonTextures[self].NormalTexture
		end
	end
end

function ButtonFunctions.SetText(self,text)
	self._Win._update = true
	if not(self._Text) then
		self._Text = FRAME.CreateFrame(self._Win, "Text", self._Layer)
		self._Text:SetPoint("CENTER",self,"CENTER")
		self._Text:SetText(text)
		self._Text:Show()
	else
		self._Text:SetText(text)
	end
end

function ButtonFunctions.SetTextSize(self,...)
	assert(self._Text, "You need to set a tButtonFunctionsGetext before you can modifiy it")
	self._Text:SetSize(...)
end

function ButtonFunctions.SetTextFont(self,...)
	assert(self._Text, "You need to set a text before you can modifiy it")
	self._Text:SetFont(...)
end

function ButtonFunctions.SetTextColor(self,...)
	assert(self._Text, "You need to set a text before you can modifiy it")
	self._Text:SetColor(...)
end

function ButtonFunctions.SetTextPoint(self,...)
	assert(self._Text, "You need to set a text before you can modifiy it")
	self._Text:SetPoint(...)
end

function ButtonFunctions.GetText(self)
	if self._Text then
		return self._Text:GetText()
	else
		return ""
	end
end
-----------Font functions---------------

local function UpdateFont(self)
	self._Fonttext = self._Fonttext or " "
	if self._Fonttext == "" then self._Fonttext = " " end
	local fw, fh = self._Font:sizeUtf8(self._Fonttext)
	local surface = self._Font:renderUtf8(self._Fonttext,"blended",self._Fontcolor)
	self._Win._update = true
	self._texture = self._Win._Rdr:createTextureFromSurface(surface)
	if not(self._crop) then
		self._width, self._height = fw, fh
	else
		local Crop = self._crop
		if Crop.w < fw then
			self._width = Crop.w
		else
			self._width = fw
		end
		if Crop.h < fh then
			self._height = Crop.h
		else
			self._height = fh
		end
	end
	if pointData[self] then
		UpdatePoint(self)
	end
end

local function RemakeFont(self)
	self._Font = ttf.open(self._Fonttype,self._Fontsize)
	return UpdateFont(self)
end

function FontFunctions.SetFont(self,Type)
	self._Fonttype = Type
	return RemakeFont(self)
end

function FontFunctions.SetColor(self,color,g,b,a)
	if g then
		a = a or 255
		self._Fontcolor = {r = color, g = g, b = b,a = a}
	else
		if type(color)=="table" and not color.a then color.a=255 end
		self._Fontcolor = color
	end
	UpdateFont(self)
end

function FontFunctions.SetSize(self, size,x,y)
	self._Fontsize = size
	if x and y then
		self._crop = {x=0, y=0, w=x,h=y}
	else
		self._crop=nil
	end
	RemakeFont(self)
end

function FontFunctions.SetText(self,text)
	self._Fonttext = text
	UpdateFont(self)
	--UpdatePoint(self)
end

function FontFunctions.GetText(self)
	return self._Fonttext
end
-----------Edit Box-------
-------Events-------------
function EditBoxWEvents.OnClick(self,...)
	self._Win._ActiveEditBox=self
	--self:ActivateCursor()--------Todo!!
	if UserWEvents[self].OnClick then
		return UserWEvents[self].OnClick(self,...)
	end
end

function EditBoxWEvents.OnValueChanged(self,...)
	if UserWEvents[self].OnValueChanged then
		return UserWEvents[self].OnValueChanged(self,self._Text:GetText(),...)
	end
end

--TODO add changing mousepointer when mousing over
-------Functions----------
local function InitText(self,Window,Layer)
	self._Text = FRAME.CreateFrame(Window, "Text", Layer)
	self._Text:SetText("")
	self._Text:Show()
end

--function EditBoxFunctions.SetText(self,text)
	--self._Text:SetText(text)
	--PushEvent("OnValueChanged",self)
--end

function EditBoxFunctions.SetInputFilter(self,filter)
	self._InputFilter = filter
end

function EditBoxFunctions.SetTextFormat(self,filter)
	self._TextFormat = filter
end

function EditBoxFunctions.GetText(self)
	return self._Text:GetText()
end

function EditBoxFunctions.SetSize(self, width, height)
	self._Win._update = true
	self._width = width
	self._height = height
	if pointData[self].point then
		UpdatePoint(self)
	end
	self._Text.crop = {x = 0, y = 0, w = width, h = height}
end

function EditBoxFunctions.SetTextSize(self,size)
	self._Text:SetSize(size,self._width,self._height)
end

function EditBoxFunctions.SetPoint(self,point,...)
	self._Win._update = true
	CommonFunctions.SetPoint(self,point,...)
	self._Text:SetPoint("LEFT",self,"LEFT", 1)
end

function EditBoxFunctions.SetTexture(self, imgpath)
	core.CheckFile(imgpath)
	self._Win._update = true
	self._texture = CreateTexture(self._Win._Rdr,imgpath,raw)
end

function EditBoxFunctions.SetText(self,text)
	self._Win._update = true
	self._String = tostring(text)
	self._Text:SetText(text)
	PushEvent("OnValueChanged",self)
end

function EditBoxFunctions.SetTranslate(self,A,B)
	self._ChangeChar = self._ChangeChar or {}
	self._ChangeChar[A] = B
end

function EditBoxFunctions.AddLetter(self,Char)
	self._Win._update = true
	if self._ChangeChar then
		if self._ChangeChar[Char] then
			Char = self._ChangeChar[Char]
		end
	end
	if self._InputFilter and not(Char:match("("..self._InputFilter..")")) then
		return
	end

	local newstring = self._String..tostring(Char)
	if self._TextFormat then
		local usefull, trash = newstring:match("^("..self._TextFormat..")(.*)")
		print(newstring,usefull, trash)
		if not(usefull) or trash~="" then
			return
		end
	end
	--[[local len = self.String:len()
	if self.Pos < len then
		self.String = self.String:sub(1,self.Pos)..Char..self.String:sub(self.Pos+1)

	else]]
		self._String = newstring
		self._Text:SetText(self._String)
	--end
end

function EditBoxFunctions.RemoveFocus(self)
	self._Win._update = true
	self._Win._ActiveEditBox=nil
end
local function NumSub(Text)
	for i=#Text, 1, -1 do
		local Byte = Text:sub(i,i):byte()
		if Byte >= 240 then
			return 4
		elseif Byte >= 224 then
			return 3
		elseif Byte >=192 then
			return 2
		end
	end
	return 1
end

function EditBoxFunctions.Backspace(self)
	self._Win._update = true
	local Len = self._String:len()
	local Sub = 1
	if Len >= 2 then
		Sub = NumSub(self._String:sub(-4))
	end
	self._String = self._String:sub(1,Len-Sub)
	if self._String:len() == 0 then
		self._String = ""
	end
	self._Text:SetText(self._String)
end

local Framemeta = {}
function Framemeta:__tostring()
	return Typetable[self]
end

function Framemeta:__newindex(key,value)
	if key:sub(1,1)=="_" then
		Frames[self][key] = value
	else
		rawset(self,key,value)
	end
end


function Framemeta:__index(key)
	if key:sub(1,1) == "_" then
		return Frames[self][key]
	else
		return nil
	end
end

local Types = {
	Frame = true,
	Button = true,
	Video = true,
	Text = true,
	EditBox = true,
	Square = true,
	Line = true
}

-----------"Public"-------
function FRAME.CreateFrame(Window,Type, Layer, extra)
	assert(Type,"Argument #1 missing")
	assert(Types[Type],"Invalid typen in #1")
	--assert(Window, "Argument #2 Window, missing")
	assert(Window._Layer[Layer], "Invalid layer")
	Window.PushEvent = PushEvent
	Window._Layer[Layer].PushEvent = PushEvent
	Window.PushChar = PushChar
	Window._Layer[Layer].PushChar = PushChar
	local Frame = setmetatable({},Framemeta)
	Frames[Frame] = {}
	Frame._width = 0
	Frame._height = 0
	Frame._x = 0
	Frame._y = 0
	Frame._Type = Type
	Frame._MouseEnabled = false
	Typetable[Frame] = Type
	--Populate Hidden events and common functions--
	HiddenWEvents[Frame] = {}
	for k,v in pairs(CommonWEvents) do
		HiddenWEvents[Frame][k] = v
	end
	for k,v in pairs(CommonFunctions) do
		Frame[k]=v
	end
	--Put in the window
	Frame._Layer = Layer
	Frame._Win = Window
	table.insert(Frame._Win._Layer[Frame._Layer],Frame)
	----Frame specific stuff
	if Type == "Frame" then
		for k,v in pairs(FrameFunctions) do
			Frame[k] = v
		end
	elseif Type == "Button" then
			Frame._MouseEnabled = true
		for k,v in pairs(ButtonFunctions) do
			Frame[k]=v
		end
		for k,v in pairs(ButtonWEvents) do
			HiddenWEvents[Frame][k] = v
		end
		ButtonTextures[Frame] = {}
	elseif Type == "Video" then
		Frame._UpdatePos = UpdatePoint
		Frame.Preload = PrepareVideo
	elseif Type == "Text" then
		Frame._Fonttype = "Fonts/DejaVuSans.ttf"
		Frame._Fontsize = 10
		Frame._Fontcolor = 0x000000
		Frame._Fonttext = " "
		Frame._Font = ttf.open(Frame._Fonttype,10)
		for k,v in pairs(FontFunctions) do
			Frame[k] =v
		end
		UpdateFont(Frame)
	elseif Type == "EditBox" then
		Frame._MouseEnabled = true
		Frame._String = ""
		for k,v in pairs(EditBoxFunctions) do
			Frame[k] =v
		end
		for k,v in pairs(EditBoxWEvents) do
			HiddenWEvents[Frame][k] = v
		end
		if extra then
			Frame:SetTexture(extra)
		end
		InitText(Frame, Window, Layer)
	elseif Type == "Square" then
		Frame._Draw = "drawRect"
		Frame._color = {r=0,g=0,b=0,a=255}
		Frame._obj = { w = 0, h = 0, x = 0, y = 0}
		for k,v in pairs(DrawSquareFunctions) do
			Frame[k] = v
		end
	elseif Type == "Line" then
		Frame._Draw = "drawLine"
		Frame._color = {r=0,g=0,b=0,a=255}
		Frame._obj = {x1 = 0, x2 = 0, y1 = 0, y2 = 0 }
		for k,v in pairs(DrawLineFunctions) do
			Frame[k] = v
		end
	end

	--Some Locals
	Children[Frame] = {}
	pointData[Frame] = {point="CENTER",ofsx=0,ofsy=0, relativePoint="CENTER"}
	UpdatePoint(Frame)
	UserWEvents[Frame] = {}
	--print("CF",Frame)
	return Frame
end

return FRAME.CreateFrame
