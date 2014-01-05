_conf = {
	-- Enable the "http" API on Computers
	enableAPI_http = true,
	
	-- Enable the "cclite" API on Computers
	enableAPI_cclite = true,
	
	-- The height of Computer screens, in characters
	terminal_height = 19,
	
	-- The width of Computer screens, in characters
	terminal_width = 51,
	
	-- The GUI scale of Computer screens
	terminal_guiScale = 2,

	-- Enable Love2D console and display current FPS
	debugmode = false,
	
	-- The FPS to lock CCLite to
	lockfps = 20,
	
	-- Enable emulation of buggy Clipboard handling
	faultyClip = true,
	
	-- Enable usage of Carrage Return for fs.writeLine
	useCRLF = false,
}
function love.conf(t)
	t.identify = "ccemu"
	t.console = _conf.debugmode
    t.window.title = "ComputerCraft Emulator"
	t.window.icon = "res/icon.png"
	t.window.width = (_conf.terminal_width * 6 * _conf.terminal_guiScale) + (_conf.terminal_guiScale * 2)
	t.window.height = (_conf.terminal_height * 9 * _conf.terminal_guiScale) + (_conf.terminal_guiScale * 2)
	t.window.vsync = false
    t.modules.audio = false
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.sound = false
    t.modules.math = false
end
