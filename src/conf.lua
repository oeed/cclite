debugmode = false
function love.conf(t)
    t.title = "ComputerCraft Emulator"
    t.author = "Sorroko"
    t.version = "0.8.0"

    t.modules.physics = false

    if debugmode then
   	    t.console = true
        t.release = false
	else
        t.screen = false -- Disable screen, wait for resize in main.lua
        t.console = false
        t.release = true
    end
end
