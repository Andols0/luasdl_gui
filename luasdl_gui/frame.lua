print("frame ... ",...)
local image = require("SDL.image")
local ttf = require("SDL.ttf")
local PrepareVideo = require("luasdl_gui.video")
tinsert, tremove = table.insert, table.remove
local formats, ret, err = image.init { image.flags.PNG }

if not formats[image.flags.PNG] then
	error(err)
end

local ret, err = ttf.init()

if not ret then
  error(err)
end
local CommonFunctions, CommonWEvents = {}, {}
local FrameFunctions = {}
local ButtonFunctions, ButtonWEvents = {}, {}
local FontFunctions = {}
local EditBoxFunctions, EditBoxWEvents = {}, {}
local DrawSquareFunctions = {}

local HiddenWEvents, UserWEvents = {}, {}

local ButtonTextures = {}
local pointData = {}
local Children = {}

local function LoadImage(rdr,path)
	local img, ret = image.load(path)
	if not img then
		error(err)
	end
	local tex = rdr:createTextureFromSurface(img)
	return tex
end

local function GetParentData(Parent)
	local Data = pointData[Parent]
	local point = Data.point
	local Basex = Data.Basex or 0
	local Basey = Data.Basey or 0
	local width = Parent.width
	local height = Parent.height
	local x, y = Parent.x, Parent.y
	if point == "TOPLEFT" then --Set base x and y depending on the anchor point
		--Is already the correct
	elseif point == "TOP" then
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
	local width = self.width or 0
	local height = self.height or 0
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
		Px, Py, Pw, Ph = 0, 0, self.Win.Win:getSize()
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
	self.x = Data.Basex+ofsx
	self.y = Data.Basey+ofsy
	for _,v in pairs(Children[self]) do
		UpdatePoint(v)
	end
end

-------------Event Shit-----------------------
function PushEvent(event,Frame,...)
	--print("EventPushed",event,Frame)
	if HiddenWEvents[Frame][event] then
		HiddenWEvents[Frame][event](Frame,...)
	end
end

function PushChar(char)
	if ActiveEditBox then
		if char=="Backspace" then
			ActiveEditBox:Backspace()
		elseif char=="Escape" then
			ActiveEditBox=nil
		else
			ActiveEditBox:AddLetter(char)
		end
	end
end
-------------Common functions-----------------
function CommonFunctions.SetSize(self, width, height)
	self.width = width
	self.height = height
	if pointData[self].point then
		UpdatePoint(self)
	end
end

function CommonFunctions.SetAlpha(self,alpha)
	self.texture:setAlphaMod(alpha*255)
end

function CommonFunctions.SetPoint(self, point, arg1, arg2, arg3, arg4)
	local relativeTo, relativePoint, ofsx, ofsy,x,y
	local relto = pointData[self].relativeTo
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
	end
	pointData[self].point=point
	pointData[self].ofsx=ofsx
	pointData[self].ofsy=ofsy
	pointData[self].relativeTo = relativeTo
	pointData[self].relativePoint = relativePoint or point
	UpdatePoint(self)
	return self.x, self.y
end

function ShowChildren(kids)
	for _,v in pairs(kids) do
		if v.Pshow and not(v.shown) then
			v.shown = true
			PushEvent("OnShow",v)
		end
		if Children[v] then
			ShowChildren(Children[v])
		end
	end
end

function HideChildren(kids)
	for _,v in pairs(kids) do
		if v.Pshow and v.shown then
			v.shown = false
			PushEvent("OnHide",v)
		end
		if Children[v] then
			HideChildren(Children[v])
		end
	end
end

function CommonFunctions.Show(self)
	self.shown = true
	self.Pshow = true
	PushEvent("OnShow",self)
	if Children[self] then
		ShowChildren(Children[self])
	end
end

function CommonFunctions.Hide(self)
	self.shown = false
	self.Pshow = false
	PushEvent("OnHide",self)
	if Children[self] then
		HideChildren(Children[self])
	end
end

function CommonFunctions.EnableMouse(self,status)
	self.MouseEnabled = status
end

function CommonFunctions.SetScript(self, Event, Callback)
	if HiddenWEvents[self][Event] then
		UserWEvents[self][Event] = Callback
	else
		error("Invalid event")
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
function DrawSquareFunctions.SetAlpha(self)
	--Can't do this
end

function DrawSquareFunctions.SetPoint(self,...)
	CommonFunctions.SetPoint(self,...)
	self.obj.x = self.x
	self.obj.y = self.y
end

function DrawSquareFunctions.SetSize(self,...)
	CommonFunctions.SetSize(self,...)
	self.obj.w = self.width
	self.obj.h = self.height
	self.obj.x = self.x
	self.obj.y = self.y
end

function DrawSquareFunctions.SetColor(self,color,g,b,a)
	if g then
		a=a or 255
		self.color = {r = color, g = g, b = b, a = a}
	else
		if not color.a then color.a=255 end
		self.color = color
	end
end

function DrawSquareFunctions.Filled(self, status)
	if status == true then
		self.Draw = "fillRect"
	else
		self.Draw = "drawRect"
	end
end

------------Frame functions--------------
function FrameFunctions.SetTexture(self,texturePath)
	CheckFile(texturePath)
	self.texture, err = LoadImage(self.Win.Rdr,texturePath)
end
------------Button Widget Events---------
function ButtonWEvents.OnClick(self,...)
	local PushedTexture = ButtonTextures[self].PushedTexture
	if PushedTexture then
		self.texture = PushedTexture
	end
	if UserWEvents[self].OnClick then
		return UserWEvents[self].OnClick(self,...)
	end
end

function ButtonWEvents.OnEnter(self,...)--Overwrite common
	local HighlightTexture = ButtonTextures[self].HighlightTexture
	if HighlightTexture then
		self.texture = HighlightTexture
	end
	if UserWEvents[self].OnEnter then
		return UserWEvents[self].OnEnter(self,...)
	end
end

function ButtonWEvents.OnLeave(self,...)--Overwrite common
	local NormalTexture = ButtonTextures[self].NormalTexture
	if NormalTexture then
		self.texture = NormalTexture
	end
	if UserWEvents[self].OnLeave then
		return UserWEvents[self].OnLeave(self,...)
	end
end
------------Button Functions------------


function ButtonFunctions.SetNormalTexture(self,texturePath)
	CheckFile(texturePath)
	ButtonTextures[self].NormalTexture = LoadImage(self.Win.Rdr,texturePath)
	self.texture = ButtonTextures[self].NormalTexture
end

function ButtonFunctions.SetPushedTexture(self,texturePath)
	CheckFile(texturePath)
	ButtonTextures[self].PushedTexture = LoadImage(self.Win.Rdr,texturePath)
end

function ButtonFunctions.SetHighlightTexture(self,texturePath)
	CheckFile(texturePath)
	ButtonTextures[self].HighlightTexture = LoadImage(self.Win.Rdr,texturePath)
end

function ButtonFunctions.SetDisabledTexture(self,texturePath)
	CheckFile(texturePath)
	ButtonTextures[self].DisabledTexture = LoadImage(self.Win.Rdr,texturePath)
end

function ButtonFunctions.SetText(self,text)
	if not(self.Text) then
		self.Text = CreateFrame("Text",self.Win, self.Layer)
		self.Text:SetPoint("CENTER",self,"CENTER")
		self.Text:SetText(text)
		self.Text:Show()
	else
		self.Text:SetText(text)
	end
end
-----------Font functions---------------

local function UpdateFont(self)
	self.Fonttext = self.Fonttext or " "
	if self.Fonttext == "" then self.Fonttext = " " end
	local fw, fh = self.Font:sizeUtf8(self.Fonttext)
	local surface = self.Font:renderUtf8(self.Fonttext,"blended",self.Fontcolor)
	self.texture = self.Win.Rdr:createTextureFromSurface(surface)
	if not(self.crop) then
		self.width, self.height = fw, fh
	else
		local Crop = self.crop
		if Crop.w < fw then
			self.width = Crop.w
		else
			self.width = fw
		end
		if Crop.h < fh then
			self.height = Crop.h
		else
			self.height = fh
		end
	end
	if pointData[self] then
		UpdatePoint(self)
	end
end

local function RemakeFont(self)
	self.Font = ttf.open(self.Fonttype,self.Fontsize)
	return UpdateFont(self)
end

function FontFunctions.SetFont(self,Type)
	self.Fonttype = Type
	return RemakeFont(self)
end

function FontFunctions.SetColor(self,color,g,b,a)
	if g then
		a = a or 255
		self.Fontcolor = {r = color, g = g, b = b,a = a}
	else
		if type(color)=="table" and not color.a then color.a=255 end
		self.Fontcolor = color
	end
	UpdateFont(self)
end

function FontFunctions.SetSize(self, size,x,y)
	self.Fontsize = size
	if x and y then
		self.crop = {x=0, y=0, w=x,h=y}
	else
		self.crop=nil
	end
	RemakeFont(self)
end

function FontFunctions.SetText(self,text)
	self.Fonttext = text
	UpdateFont(self)
	--UpdatePoint(self)
end

function FontFunctions.GetText(self)
	return self.Fonttext
end
-----------Edit Box-------
-------Events-------------
function EditBoxWEvents.OnClick(self,...)
	ActiveEditBox=self
	--self:ActivateCursor()--------Todo!!
	if UserWEvents[self].OnClick then
		return UserWEvents[self].OnClick(self,...)
	end
end

--TODO add changing mousepointer when mousing over
-------Functions----------
local function InitText(self,Window,Layer)
	self.Text = CreateFrame("Text",Window,Layer)
	self.Text:SetText("")
	self.Text:Show()
end

function EditBoxFunctions.SetText(self,text)
	self.Text:SetText(text)
end

function EditBoxFunctions.SetInputFilter(self,filter)
	self.InputFilter = filter
end

function EditBoxFunctions.SetTextFormat(self,filter)
	self.TextFormat = filter
end

function EditBoxFunctions.GetText(self)
	return self.Text:GetText()
end

function EditBoxFunctions.SetSize(self, width, height)
	self.width = width
	self.height = height
	if pointData[self].point then
		UpdatePoint(self)
	end
	self.Text.crop = {x = 0, y = 0, w = width, h = height}
end

function EditBoxFunctions.SetTextSize(self,size)
	self.Text:SetSize(size,self.width,self.height)
end

function EditBoxFunctions.SetPoint(self,point,...)
	local x, y = CommonFunctions.SetPoint(self,point,...)
	self.Text:SetPoint("LEFT",self,"LEFT", 1)
end

function EditBoxFunctions.SetTexture(self, imgpath)
	CheckFile(imgpath)
	self.texture = LoadImage(self.Win.Rdr,imgpath)
end

function EditBoxFunctions.SetText(self,text)
	self.String = tostring(text)
	self.Text:SetText(text)
end

function EditBoxFunctions.SetTranslate(self,A,B)
	self.ChangeChar = self.ChangeChar or {}
	self.ChangeChar[A] = B
end

function EditBoxFunctions.AddLetter(self,Char)
	if self.ChangeChar then
		if self.ChangeChar[Char] then
			Char = self.ChangeChar[Char]
		end
	end
	if self.InputFilter and not(Char:match("("..self.InputFilter..")")) then
		return
	end

	local newstring = self.String..tostring(Char)
	if self.TextFormat then
		local usefull, trash = newstring:match("^("..self.TextFormat..")(.*)")
		print(newstring,usefull, trash)
		if not(usefull) or trash~="" then
			return
		end
	end
	--[[local len = self.String:len()
	if self.Pos < len then
		self.String = self.String:sub(1,self.Pos)..Char..self.String:sub(self.Pos+1)

	else]]
		self.String = newstring
		self.Text:SetText(self.String)
	--end
end

function EditBoxFunctions.RemoveFocus()
	ActiveEditBox=nil
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
	local Len = self.String:len()
	local Sub = 1
	if Len >= 2 then
		Sub = NumSub(self.String:sub(-4))
	end
	self.String = self.String:sub(1,Len-Sub)
	if self.String:len() == 0 then
		self.String = ""
	end
	self.Text:SetText(self.String)
end

-----------"Public"-------
function CreateFrame(Type, Window, Layer)
	assert(Type,"Argument #1 missing")
	assert(Window, "Argument #2 Window, missing")
	assert(Window.Layer[Layer], "Invalid layer")
	local Frame = {width=0,height=0,x=0,y=0,Type=Type}
	if Queue then Frame.Queue = Queue end
	--Populate Hidden events and common functions--
	HiddenWEvents[Frame] = {}
	for k,v in pairs(CommonWEvents) do
		HiddenWEvents[Frame][k] = v
	end
	for k,v in pairs(CommonFunctions) do
		Frame[k]=v
	end
	--Put in the window
	Frame.Layer = Layer
	Frame.Win = Window
	table.insert(Frame.Win.Layer[Frame.Layer],Frame)
	----Frame specific stuff
	if Type == "Frame" then
		for k,v in pairs(FrameFunctions) do
			Frame[k] = v
		end
	elseif Type == "Button" then
			Frame.MouseEnabled = true
		for k,v in pairs(ButtonFunctions) do
			Frame[k]=v
		end
		for k,v in pairs(ButtonWEvents) do
			HiddenWEvents[Frame][k] = v
		end
		ButtonTextures[Frame] = {}
	elseif Type == "Video" then
		Frame.UpdatePos = UpdatePoint
		Frame.Preload = PrepareVideo
	elseif Type == "Text" then
		Frame.Fonttype = "Fonts/DejaVuSans.ttf"
		Frame.Fontsize = 10
		Frame.Fontcolour = 0x000000
		Frame.Fonttext = " "
		Frame.Font = ttf.open("Fonts/DejaVuSans.ttf",10)
		for k,v in pairs(FontFunctions) do
			Frame[k] =v
		end
		UpdateFont(Frame)
	elseif Type == "EditBox" then
		Frame.MouseEnabled = true
		Frame.String = ""
		for k,v in pairs(EditBoxFunctions) do
			Frame[k] =v
		end
		for k,v in pairs(EditBoxWEvents) do
			HiddenWEvents[Frame][k] = v
		end
		Frame:SetTexture("Textures/EditBox.png")
		InitText(Frame, Window, Layer)
	elseif Type == "Square" then
		Frame.Draw = "drawRect"
		Frame.color = 0x000000FF
		Frame.obj = { w = 0, h = 0, x = 0, y = 0}
		for k,v in pairs(DrawSquareFunctions) do
			Frame[k] = v
		end
	end

	--Some Locals
	Children[Frame] = {}
	pointData[Frame] = {point="CENTER",ofsx=0,ofsy=0, relativePoint="CENTER"}
	UpdatePoint(Frame)
	UserWEvents[Frame] = {}
	return Frame
end

return Queue
