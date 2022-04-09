local luasdl_gui = require("luasdl_gui.core")

local Frame = require("luasdl_gui.frame")

luasdl_gui.AddWinFunction("CreateFrame",Frame)

--for k,v in pairs(Frame) do
	--luasdl_gui[k] = v
--end

function luasdl_gui.initAudio()
	luasdl_gui.Audio = require("luasdl_gui.audio")
end


return luasdl_gui