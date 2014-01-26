function crash() error("GOODBYE WORLD") end
demand = love.thread.getChannel("demand")
_conf = demand:demand()

require("love.filesystem")
require("love.timer")
require("love.mouse")
require("love.system")
--require("love.keyboard")
if _conf.enableAPI_http then require("http.HttpRequest") end
bit = require("bit")
require("api")
require("vfs")

downlink = love.thread.getChannel("downlink")
uplink = love.thread.getChannel("uplink")
murder = love.thread.getChannel("murder")

-- Patch print to identify where the message came from.
local _print = print
function print(...)
	_print("[EMU] ",...)
end

local function math_bind(val,lower,upper)
	return math.min(math.max(val,lower),upper)
end

-- Load virtual peripherals
peripheral = {}
peripheral.base = {}
peripheral.types = {}
local tFiles = love.filesystem.getDirectoryItems("peripheral")
for k,v in pairs(tFiles) do
	local stat, err = pcall(require,"peripheral." .. v:sub(1,-5))
	if stat == false then
		uplink:push({"screenMessage", "Could not load peripheral." .. v:sub(1,-5)})
		print(err)
	end
end

-- Conversion table for Love2D keys to LWJGL key codes
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
	["capslock"] = 58,
	["numlock"] = 69,
	["scrolllock"] = 70,

	["f1"] = 59,
	["f2"] = 60,
	["f3"] = 61,
	["f4"] = 62,
	["f5"] = 63,
	["f6"] = 64,
	["f7"] = 65,
	["f8"] = 66,
	["f9"] = 67,
	["f10"] = 68,
	["f12"] = 88,
	["f13"] = 100,
	["f14"] = 101,
	["f15"] = 102,
	["f16"] = 103,
	["f17"] = 104,
	["f18"] = 105,

	["rshift"] = 54,
	["lshift"] = 42,
	["rctrl"] = 157,
	["lctrl"] = 29,
	["ralt"] = 184,
	["lalt"] = 56,
}

-- Fake love.keyboard
_kbdcache = {} -- Cache keyboard events for the current loop.
love.keyboard = {}
function love.keyboard.isDown(key)
	if _kbdcache[key] == nil then
		uplink:push({"isDown",key})
		_kbdcache[key] = demand:demand()
	end
	return _kbdcache[key]
end

Screen = {
	sWidth = (_conf.terminal_width * 6 * _conf.terminal_guiScale) + (_conf.terminal_guiScale * 2),
	sHeight = (_conf.terminal_height * 9 * _conf.terminal_guiScale) + (_conf.terminal_guiScale * 2),
	pixelWidth = _conf.terminal_guiScale * 6,
	pixelHeight = _conf.terminal_guiScale * 9,
}

Emulator = {
	running = false,
	killself = 0,
	actions = { -- Keyboard commands i.e. ctrl + s and timers/alarms
		lastTimer = 0,
		lastAlarm = 0,
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
	uplink:push({"initScreen"})
	api.init()

	local fn, err = loadstring(love.filesystem.read("lua/bios.lua"),"@bios")

	if not fn then
		print(err)
		return
	end

	setfenv( fn, api.env )

	self.proc = coroutine.create(fn)
	self.running = true
	self:resume({})
end

function Emulator:stop( reboot )
	self.proc = nil
	self.running = false
	uplink:push({"dead",reboot})
	uplink:push({"dirtyScreen"})

	-- Reset events/key shortcuts
	self.actions.terminate = nil
	self.actions.lastTimer = 0
	self.actions.lastAlarm = 0
	self.actions.timers = {}
	self.actions.alarms = {}
	self.eventQueue = {}
	crash()
end

function Emulator:resume( ... )
	if not self.running then return end
	debug.sethook(self.proc,function() error("Too long without yielding",2) end,"",9e7)
	debug.sethook(self.proc,function() local a = murder:pop() if a ~= nil then api.os[a == true and "reboot" or "shutdown"]() end end,"",100)
	local ok, err = coroutine.resume(self.proc, ...)
	debug.sethook(self.proc)
	if Emulator.killself ~= 0 then Emulator:stop(Emulator.killself == 2) end
	_kbdcache = {}
	if not self.proc then return end -- Emulator:stop could be called within the coroutine resulting in proc being nil
	if coroutine.status(self.proc) == "dead" then -- Which could cause an error here
		Emulator:stop()
	end
	if not ok then
    	error(err,math.huge) -- Bios was unable to handle error, crash CCLite
    end
    return ok, err
end

function love.load()
	if _conf.lockfps > 0 then 
		min_dt = 1/_conf.lockfps
		next_time = love.timer.getTime()
	end
	
	local fontPack = {131,161,163,166,170,171,172,174,186,187,188,189,191,196,197,198,199,201,209,214,215,216,220,224,225,226,228,229,230,231,232,233,234,235,236,237,238,239,241,242,243,244,246,248,249,250,251,252,255}
	ChatAllowedCharacters = {}
	for i = 32,126 do
		ChatAllowedCharacters[i] = true
	end
	for i = 1,#fontPack do
		ChatAllowedCharacters[fontPack[i]] = true
	end
	ChatAllowedCharacters[96] = nil
	
	if not love.filesystem.exists("data/") then
		love.filesystem.createDirectory("data/") -- Make the user data folder
	end
	
	vfs.mount("/data","/")
	vfs.mount("/lua/rom","/rom")
	
	Emulator:start()
end

function love.mousereleased( x, y, _button )
	if x > 0 and x < Screen.sWidth and y > 0 and y < Screen.sHeight then -- Within screen bounds.
		Emulator.mouse.isPressed = false
	end
end

function love.mousepressed(x, y, button)
	if x > 0 and x < Screen.sWidth and y > 0 and y < Screen.sHeight then -- Within screen bounds.
		local termMouseX = math_bind(math.floor((x - _conf.terminal_guiScale) / Screen.pixelWidth) + 1,1,_conf.terminal_width)
		local termMouseY = math_bind(math.floor((y - _conf.terminal_guiScale) / Screen.pixelHeight) + 1,1,_conf.terminal_height)

		if button == "l" or button == "m" or button == "r" then
			Emulator.mouse.isPressed = true
			Emulator.mouse.lastTermX = termMouseX
			Emulator.mouse.lastTermY = termMouseY
			if button == "l" then button = 1
			elseif button == "m" then button = 3
			elseif button == "r" then button = 2
			end
			table.insert(Emulator.eventQueue, {"mouse_click", button, termMouseX, termMouseY})
		elseif button == "wu" then -- Scroll up
			table.insert(Emulator.eventQueue, {"mouse_scroll", -1, termMouseX, termMouseX})
		elseif button == "wd" then -- Scroll down
			table.insert(Emulator.eventQueue, {"mouse_scroll", 1, termMouseX, termMouseY})
		end
	end
end

function love.textinput(unicode)
		-- Hack to get around android bug
		if love.system.getOS() == "Android" and keys[unicode] ~= nil then
			table.insert(Emulator.eventQueue, {"key", keys[unicode]})
		end
		if ChatAllowedCharacters[unicode:byte()] then
			table.insert(Emulator.eventQueue, {"char", unicode})
		end
end

function love.keypressed(key, isrepeat)
	if Emulator.actions.terminate == nil and love.keyboard.isDown("ctrl") and not isrepeat and key == "t" then
		Emulator.actions.terminate = love.timer.getTime()
	end

	if love.keyboard.isDown("ctrl") and key == "v" then
		local cliptext = love.system.getClipboardText()
		cliptext = cliptext:gsub("\r\n","\n")
		local nloc = cliptext:find("\n") or -1
		if nloc > 0 then
			cliptext = cliptext:sub(1, nloc - (_conf.compat_faultyClip and 2 or 1))
		end
		cliptext = cliptext:sub(1,127)
		for i = 1,#cliptext do
			love.textinput(cliptext:sub(i,i))
		end
	elseif isrepeat and love.keyboard.isDown("ctrl") and key == "t" then
	elseif keys[key] then
   		table.insert(Emulator.eventQueue, {"key", keys[key]})
		-- Hack to get around android bug
		if love.system.getOS() == "Android" and #key == 1 and ChatAllowedCharacters[key:byte()] then
			table.insert(Emulator.eventQueue, {"char", key})
		end
   	end
end

local function updateShortcut(name, key1, key2, cb)
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

function Emulator:update(dt)
	if _conf.lockfps > 0 then next_time = next_time + min_dt end
	local now = love.timer.getTime()
	if murder:pop() ~= nil then crash() end
	if _conf.enableAPI_http then HttpRequest.checkRequests() end

	updateShortcut("terminate", "ctrl", "t", function()
			table.insert(self.eventQueue, {"terminate"})
		end)
	
	for k, v in pairs(self.actions.timers) do
		if now >= v then
			table.insert(self.eventQueue, {"timer", k})
			self.actions.timers[k] = nil
		end
	end

	for k, v in pairs(self.actions.alarms) do
		if v.day <= api.os.day() and v.time <= api.env.os.time() then
			table.insert(self.eventQueue, {"alarm", k})
			self.actions.alarms[k] = nil
		end
	end

	-- Mouse
	if self.mouse.isPressed then
    	local mouseX     = love.mouse.getX()
    	local mouseY     = love.mouse.getY()
    	local termMouseX = math_bind(math.floor( (mouseX - _conf.terminal_guiScale) / Screen.pixelWidth ) + 1,1,_conf.terminal_width)
    	local termMouseY = math_bind(math.floor( (mouseY - _conf.terminal_guiScale) / Screen.pixelHeight ) + 1,1,_conf.terminal_width)
    	if (termMouseX ~= self.mouse.lastTermX or termMouseY ~= self.mouse.lastTermY)
			and (mouseX > 0 and mouseX < Screen.sWidth and
				mouseY > 0 and mouseY < Screen.sHeight) then

        	self.mouse.lastTermX = termMouseX
       		self.mouse.lastTermY = termMouseY

        	table.insert (self.eventQueue, { "mouse_drag", love.mouse.isDown( "r" ) and 2 or 1, termMouseX, termMouseY})
    	end
    end

    if #self.eventQueue > 0 then
		for k, v in pairs(self.eventQueue) do
			self:resume(unpack(v))
		end
		self.eventQueue = {}
	end
end

function love.run()

    math.randomseed(os.time())
    math.random() math.random()
	
	love.load(arg)
	
	love.timer.step()

	-- Main loop time.
	while true do
		-- Process events.
		if downlink:getCount() > 0 then
			for i = 1,downlink:getCount() do
				local msg = downlink:pop()
				if msg == nil then
				elseif msg[1] == "mousereleased" then
					love.mousereleased(msg[2],msg[3],msg[4])
				elseif msg[1] == "mousepressed" then
					love.mousepressed(msg[2],msg[3],msg[4])
				elseif msg[1] == "textinput" then
					love.textinput(msg[2])
				elseif msg[1] == "keypressed" then
					love.keypressed(msg[2],msg[3])
				else
					print("Unknown cmd: " .. msg[1])
				end
			end
		end
		
        -- Update the FPS counter
		love.timer.step()

		-- Call update
        Emulator:update()
		
		local cur_time = love.timer.getTime()
		if next_time <= cur_time then
			next_time = cur_time
		else
			love.timer.sleep(next_time - cur_time)
		end
		_kbdcache = {}
		
		love.timer.sleep(0.001)
		
	end
	
end

love.run()