demand = love.thread.getChannel("demand")
_conf = demand:demand()

require("love.filesystem")
require("love.timer")
require("love.mouse")
require("love.keyboard")
require('api')
bit = require("bit")
if _conf.enableAPI_http == true then require('http.HttpRequest') end

downlink = love.thread.getChannel("downlink")
uplink = love.thread.getChannel("uplink")

-- Patch print to hook up to the console.
function print(...)
	uplink:push({"print","[EMU] ",...})
end

-- Load virtual peripherals.
peripheral = {}
local tFiles = love.filesystem.getDirectoryItems("peripheral")
for k,v in pairs(tFiles) do
	require("peripheral." .. v:sub(1,-5))
end

keys = {
	["q"] = 16, ["w"] = 17, ["e"] = 18, ["r"] = 19,
	["t"] = 20, ["y"] = 21, ["u"] = 22, ["i"] = 23,
	["o"] = 24, ["p"] = 25, ["a"] = 30, ["s"] = 31,
	["d"] = 32, ["f"] = 33, ["g"] = 34, ["h"] = 35,
	["j"] = 36, ["k"] = 37, ["l"] = 38, ["z"] = 44,
	["x"] = 45, ["c"] = 46, ["v"] = 47, ["b"] = 48,
	["n"] = 49, ["m"] = 50,
	["1"] = 2, ["2"] = 3, ["3"] = 4, ["4"] = 5, ["5"] = 6,
	["6"] = 7, ["7"] = 8, ["8"] = 9, ["9"] = 10, ["0"] = 11,
	[" "] = 57,

	["'"] = 40, [","] = 51, ["-"] = 12, ["."] = 52, ["/"] = 53,
	[":"] = 146, [";"] = 39, ["="] = 13, ["@"] = 145, ["["] = 26,
	["\\"] = 43, ["]"] = 27, ["^"] = 144, ["_"] = 147, ["`"] = 41,

	["up"] = 200,
	["down"] = 208,
	["right"] = 205,
	["left"] = 203,
	["home"] = 199,
	["end"] = 207,
	["pageup"] = 201,
	["pagedown"] = 209,
	["insert"] = 210,
	["backspace"] = 14,
	["tab"] = 15,
	["return"] = 28,
	["delete"] = 211,

	["rshift"] = 54,
	["lshift"] = 42,
	["rctrl"] = 157,
	["lctrl"] = 29,
	["ralt"] = 184,
	["lalt"] = 56,
}

--[[
-- Fake love.keyboard
love.keyboard = {}
function love.keyboard.isDown(key)
	uplink:push({"isDown",key})
	local msg = demand:demand()
	return msg
end

-- Fake love.mouse
love.mouse = {}
function love.mouse.getX()
	uplink:push({"getX"})
	local msg = demand:demand()
	return msg
end
function love.mouse.getY()
	uplink:push({"getY"})
	local msg = demand:demand()
	return msg
end
function love.mouse.isDown(button)
	uplink:push({"mouseIsDown",button})
	local msg = demand:demand()
	return msg
end
]]

Screen = {
	sWidth = (_conf.terminal_width * 6 * _conf.terminal_guiScale) + (_conf.terminal_guiScale * 2),
	sHeight = (_conf.terminal_height * 9 * _conf.terminal_guiScale) + (_conf.terminal_guiScale * 2),
	pixelWidth = _conf.terminal_guiScale * 6,
	pixelHeight = _conf.terminal_guiScale * 9,
}

Emulator = {
	running = false,
	reboot = false, -- Tells update loop to start Emulator automatically
	actions = { -- Keyboard commands i.e. ctrl + s and timers/alarms
		terminate = nil,
		shutdown = nil,
		reboot = nil,
		timers = {},
		alarms = {},
	},
	eventQueue = {},
	lastUpdateClock = os.clock(),
	minecraft = {
		time = 0,
		day = 0,
	},
	mouse = {
		isPressed = false,
		lastTermX = nil,
		lastTermY = nil,
	}
}

function Emulator:start()
	self.reboot = false
	api.init()
	uplink:push({"initScreen"})

	local fn, err = love.filesystem.load('lua/bios.lua') -- lua/bios.lua
	local tEnv = {}

	if not fn then
		print(err)
		return
	end

	setfenv( fn, api.env )

	self.proc = coroutine.create(fn)
	self.running = true
	uplink:push({"running",self.running})
	self:resume({})
end

function Emulator:stop( reboot )
	self.proc = nil
	self.running = false
	uplink:push({"running",self.running})
	self.reboot = reboot
	uplink:push({"dirtyScreen"})

	-- Reset events/key shortcuts
	self.actions.terminate = nil
	self.actions.shutdown = nil
	self.actions.reboot = nil
	self.actions.timers = {}
	self.actions.alarms = {}
	self.eventQueue = {}
end

function Emulator:resume( ... )
	if not self.running then return end
	debug.sethook(self.proc,function() error("Too long without yielding",2) end,"",1e9)
	local ok, err = coroutine.resume(self.proc, ...)
	debug.sethook(self.proc)
	if not self.proc then return end -- Emulator:stop could be called within the coroutine resulting in proc being nil
	if coroutine.status(self.proc) == "dead" then -- Which could cause an error here
		Emulator:stop()
	end
	if not ok then
    	print(err) -- Print to debug console, errors are handled in bios.
    end
    return ok, err
end

function love.load()
	jit.off() -- Required for "Too long without yielding"
	next_time = love.timer.getTime()

	local fontObj = love.filesystem.newFile("res/font.txt", "r")
	local fontPack = ""
	for line in fontObj:lines() do
		if line:sub(1,1) ~= "#" then
			fontPack = fontPack .. line
		end
	end
	fontObj:close()
	ChatAllowedCharacters = {}
	for i = 1,#fontPack do
		ChatAllowedCharacters[fontPack:sub(i,i):byte()] = true
	end
	
	if not love.filesystem.exists("data/") then
		love.filesystem.createDirectory("data/") -- Make the user data folder
	end
	
	Emulator:start()
end

function love.mousereleased( x, y, _button )

	if x > 0 and x < Screen.sWidth
		and y > 0 and y < Screen.sHeight then -- Within screen bounds.

		Emulator.mouse.isPressed = false
	end
end

function love.mousepressed(x, y, _button)

	if x > 0 and x < Screen.sWidth
		and y > 0 and y < Screen.sHeight then -- Within screen bounds.

		local termMouseX = math.floor( x / Screen.pixelWidth ) + 1
    	local termMouseY = math.floor( y / Screen.pixelHeight ) + 1

		if not Emulator.mousePressed and _button == "r" or _button == "l" then
			Emulator.mouse.isPressed = true
			local button = _button == "r" and 2 or 1
			table.insert(Emulator.eventQueue, {"mouse_click", button, termMouseX, termMouseY})

		elseif _button == "wu" then -- Scroll up
			table.insert(Emulator.eventQueue, {"mouse_scroll", -1, termMouseX, termMouseX})

		elseif _button == "wd" then -- Scroll down
			table.insert(Emulator.eventQueue, {"mouse_scroll", 1, termMouseX, termMouseY})

		end
	end
end

function love.textinput(unicode)
	local byte = string.byte(unicode)
   	if ChatAllowedCharacters[byte] == true then
    	table.insert(Emulator.eventQueue, {"char", unicode})
    end
end

function love.keypressed(key)
	if Emulator.actions.terminate == nil    and love.keyboard.isDown("ctrl") and key == "t" then
		Emulator.actions.terminate = love.timer.getTime()
	elseif Emulator.actions.shutdown == nil and love.keyboard.isDown("ctrl") and key == "s" then
		Emulator.actions.shutdown =  love.timer.getTime()
	elseif Emulator.actions.reboot == nil   and love.keyboard.isDown("ctrl") and key == "r" then
		Emulator.actions.reboot =    love.timer.getTime()
	else -- Ignore key shortcuts before "press any key" action. TODO: This might be slightly buggy!
		if not Emulator.running then
			Emulator:start()
			return
		end
	end

	if love.keyboard.isDown("ctrl") and key == "v" then
		local cliptext = love.system.getClipboardText()
		cliptext = cliptext:gsub("\r\n","\n")
		local nloc = cliptext:find("\n") or -1
		if nloc > 0 then
			cliptext = cliptext:sub(1, nloc - (_conf.compat_faultyClip == true and 2 or 1))
		end
		cliptext = cliptext:sub(1,128)
		for i = 1,#cliptext do
			love.textinput(cliptext:sub(i,i))
		end
	elseif keys[key] then
   		table.insert(Emulator.eventQueue, {"key", keys[key]})
   	end
end

function updateShortcut(name, key1, key2, cb)
	if Emulator.actions[name] ~= nil then
		if love.keyboard.isDown(key1) and love.keyboard.isDown(key2) then
			if love.timer.getTime() - Emulator.actions[name] > 1 then
				Emulator.actions[name] = nil
				if cb then cb() end
			end
		else
			Emulator.actions[name] = nil
		end
	end
end

function love.update(dt)
	next_time = next_time + 0.05
	local now = love.timer.getTime()
	if _conf.enableAPI_http == true then HttpRequest.checkRequests() end
	if Emulator.reboot then Emulator:start() end

	updateShortcut("terminate", "ctrl", "t", function()
			table.insert(Emulator.eventQueue, {"terminate"})
		end)
	updateShortcut("shutdown",  "ctrl", "s", function()
			Emulator:stop()
		end)
	updateShortcut("reboot",    "ctrl", "r", function()
			Emulator:stop( true )
		end)
	
	if #Emulator.actions.timers > 0 then
		for k, v in pairs(Emulator.actions.timers) do
			if now > v.expires then
				table.insert(Emulator.eventQueue, {"timer", k})
				Emulator.actions.timers[k] = nil
			end
		end
	end

	if #Emulator.actions.alarms > 0 then
		local currentTime = api.env.os.time()

		for k, v in pairs(Emulator.actions.alarms) do
        	if currentTime >= v.time then
            	table.insert(Emulator.eventQueue, {"alarm", k})
           		Emulator.actions.alarms[k] = nil
        	end
    	end
	end

	--MOUSE
	if Emulator.mouse.isPressed then
    	local mouseX     = love.mouse.getX()
    	local mouseY     = love.mouse.getY()
    	local termMouseX = math.floor( mouseX / Screen.pixelWidth ) + 1
    	local termMouseY = math.floor( mouseY / Screen.pixelHeight ) + 1
    	if (termMouseX ~= Emulator.mouse.lastTermX or termMouseY ~= Emulator.mouse.lastTermY)
			and (mouseX > 0 and mouseX < Screen.sWidth and
				mouseY > 0 and mouseY < Screen.sHeight) then

        	Emulator.mouse.lastTermX = termMouseX
       		Emulator.mouse.lastTermY = termMouseY

        	table.insert (Emulator.eventQueue, { "mouse_drag", love.mouse.isDown( "r" ) and 2 or 1, termMouseX, termMouseY})
    	end
    end

    local currentClock = os.clock()

    -- Update internal Minecraft time.
	Emulator.minecraft.time = (os.clock()*0.02)%24
	Emulator.minecraft.day  = math.floor(os.clock()*0.2/60)

    if #Emulator.eventQueue > 0 then
		for k, v in pairs(Emulator.eventQueue) do
			Emulator:resume(unpack(v))
		end
		Emulator.eventQueue = {}
	end
end

function love.draw()
	local cur_time = love.timer.getTime()
	if next_time <= cur_time then
		next_time = cur_time
		return
	end
	love.timer.sleep(next_time - cur_time)
end

function love.run()

    math.randomseed(os.time())
    math.random() math.random()
	
	love.load(arg)
	
	local dt = 0

	-- Main loop time.
	while true do
		-- Process events.
		if downlink:getCount() > 0 then
			for i = 1,downlink:getCount() do
				local msg = downlink:pop()
				if msg[1] == "mousereleased" then
					love.mousereleased(msg[2],msg[3],msg[4])
				elseif msg[1] == "mousepressed" then
					love.mousepressed(msg[2],msg[3],msg[4])
				elseif msg[1] == "textinput" then
					love.textinput(msg[2])
				elseif msg[1] == "keypressed" then
					love.keypressed(msg[2])
				else
					print("Unknown cmd: " .. msg[1])
				end
			end
		end
		
        -- Update dt, as we'll be passing it to update
        dt = love.timer.getDelta()
		
		-- Call update
        love.update(dt) -- will pass 0 if love.timer is disabled
		love.draw()
		
		if love.timer then love.timer.sleep(0.001) end
	end
	
end

love.run()