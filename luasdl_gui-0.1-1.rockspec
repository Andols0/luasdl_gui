package = "luasdl_gui"
version = "0.1-1"

source = {
    url = "git://github.com/Andols0/luasdl_gui",
    tag = "master" 
}

build = {
    type = "builtin",
    modules = {
        ["luasdl_gui"] = "luasdl_gui.lua",
        ["luasdl_gui.audio-processor"] = "luasdl_gui/audio-processor.lua",
        ["luasdl_gui.audio"] = "luasdl_gui/audio.lua",
        ["luasdl_gui.frame"] = "luasdl_gui/frame.lua",
        ["luasdl_gui.video"] = "luasdl_gui/video.lua"
    }

}

dependencies = {
	"lua >= 5.1",
    "luasocket",
}