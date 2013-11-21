debugmode = false
function love.conf(t)
    t.title = "ComputerCraft Emulator"
    t.author = "Sorroko"
    t.version = "0.8.0"
	t.release = true
	t.console = debugmode
    t.modules.physics = false
	t.modules.audio = false
	t.modules.image = false
	t.modules.sound = false
end
