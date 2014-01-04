_conf = {
	debugmode = false, -- Set this to true to enable the console and view fps, Default false.
	lockfps = 20,      -- Set this to 0 to disable FPS limiting, Default 20.
	faultyClip = true, -- Emulate CC removing the letter before \n in the clipboard
	useCRLF = false,   -- Use \r\n instead of \n in fs.writeLine
}
function love.conf(t)
    t.title = "ComputerCraft Emulator"
    t.author = "gamax92"
    t.version = "0.9.0"
	t.release = false
	t.console = _conf.debugmode
    t.modules.physics = false
	t.modules.audio = false
	t.modules.image = false
	t.modules.sound = false
end