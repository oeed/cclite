-- Verify configuration
assert(type(_conf.enableAPI_http) == "boolean", "Invalid value for _conf.enableAPI_http")
assert(type(_conf.enableAPI_cclite) == "boolean", "Invalid value for _conf.enableAPI_cclite")
assert(type(_conf.terminal_height) == "number", "Invalid value for _conf.terminal_height")
assert(type(_conf.terminal_width) == "number", "Invalid value for _conf.terminal_width")
assert(type(_conf.terminal_guiScale) == "number", "Invalid value for _conf.terminal_guiScale")
assert(type(_conf.cclite_showFPS) == "boolean", "Invalid value for _conf.cclite_showFPS")
assert(type(_conf.lockfps) == "number", "Invalid value for _conf.lockfps")
assert(type(_conf.compat_faultyClip) == "boolean", "Invalid value for _conf.compat_faultyClip")
assert(type(_conf.useLuaSec) == "boolean", "Invalid value for _conf.useLuaSec")
assert(type(_conf.useCRLF) == "boolean", "Invalid value for _conf.useCRLF")

require("render")

if _conf.compat_loadstringMask ~= nil then
	Screen:message("_conf.compat_loadstringMask is obsolete")
end

-- Test if HTTPS is working
if _conf.useLuaSec then
	local stat, err = pcall(function()
		local trash = require("ssl.https")
	end)
	if stat ~= true then
		_conf.useLuaSec = false
		Screen:message("Could not load HTTPS support")
		if err:find("module 'ssl.core' not found") then
			print("CCLite cannot find ssl.dll or ssl.so\n\n" .. err)
		elseif err:find("The specified procedure could not be found") then
			print("CCLite cannot find ssl.lua\n\n" .. err)
		elseif err:find("module 'ssl.https' not found") then
			print("CCLite cannot find ssl/https.lua\n\n" .. err)
		else
			print(err)
		end
	end
end

demand = love.thread.getChannel("demand")
downlink = love.thread.getChannel("downlink")
uplink = love.thread.getChannel("uplink")
murder = love.thread.getChannel("murder")

api = {}
api.comp = {
	cursorX = 1,
	cursorY = 1,
	bg = 32768,
	fg = 1,
	blink = false,
}
api.term = {}
function api.term.clear()
	for y = 1, _conf.terminal_height do
		for x = 1, _conf.terminal_width do
			Screen.textB[y][x] = " "
			Screen.backgroundColourB[y][x] = api.comp.bg
			Screen.textColourB[y][x] = 1
		end
	end
	Screen.dirty = true
end
function api.term.clearLine()
	if api.comp.cursorY > _conf.terminal_height or api.comp.cursorY < 1 then
		return
	end
	for x = 1, _conf.terminal_width do
		Screen.textB[api.comp.cursorY][x] = " "
		Screen.backgroundColourB[api.comp.cursorY][x] = api.comp.bg
		Screen.textColourB[api.comp.cursorY][x] = 1
	end
	Screen.dirty = true
end
function api.term.getSize()
	return _conf.terminal_width, _conf.terminal_height
end
function api.term.getCursorPos()
	return api.comp.cursorX, api.comp.cursorY
end
function api.term.setCursorPos(x, y)
	api.comp.cursorX = math.floor(x)
	api.comp.cursorY = math.floor(y)
	Screen.dirty = true
end
function api.term.write(text)
	if api.comp.cursorY > _conf.terminal_height or api.comp.cursorY < 1 or api.comp.cursorX > _conf.terminal_width then
		api.comp.cursorX = api.comp.cursorX + #text
		return
	end

	for i = 1, #text do
		local char = text:sub(i, i)
		if api.comp.cursorX + i - 1 >= 1 then
			if api.comp.cursorX + i - 1 > _conf.terminal_width then
				break
			end
			Screen.textB[api.comp.cursorY][api.comp.cursorX + i - 1] = char
			Screen.textColourB[api.comp.cursorY][api.comp.cursorX + i - 1] = api.comp.fg
			Screen.backgroundColourB[api.comp.cursorY][api.comp.cursorX + i - 1] = api.comp.bg
		end
	end
	api.comp.cursorX = api.comp.cursorX + #text
	Screen.dirty = true
end
function api.term.setTextColor(num)
	num = 2^math.floor(math.log(num)/math.log(2))
	api.comp.fg = num
	Screen.dirty = true
end
function api.term.setBackgroundColor(num)
	num = 2^math.floor(math.log(num)/math.log(2))
	api.comp.bg = num
end
function api.term.isColor()
	return true
end
function api.term.setCursorBlink(bool)
	api.comp.blink = bool
	Screen.dirty = true
end
function api.term.scroll(n)
	local textBuffer = {}
	local backgroundColourBuffer = {}
	local textColourBuffer = {}
	for y = 1, _conf.terminal_height do
		if y - n > 0 and y - n <= _conf.terminal_height then
			textBuffer[y - n] = {}
			backgroundColourBuffer[y - n] = {}
			textColourBuffer[y - n] = {}
			for x = 1, _conf.terminal_width do
				textBuffer[y - n][x] = Screen.textB[y][x]
				backgroundColourBuffer[y - n][x] = Screen.backgroundColourB[y][x]
				textColourBuffer[y - n][x] = Screen.textColourB[y][x]
			end
		end
	end
	for y = 1, _conf.terminal_height do
		if textBuffer[y] ~= nil then
			for x = 1, _conf.terminal_width do
				Screen.textB[y][x] = textBuffer[y][x]
				Screen.backgroundColourB[y][x] = backgroundColourBuffer[y][x]
				Screen.textColourB[y][x] = textColourBuffer[y][x]
			end
		else
			for x = 1, _conf.terminal_width do
				Screen.textB[y][x] = " "
				Screen.backgroundColourB[y][x] = api.comp.bg
				Screen.textColourB[y][x] = 1 -- Don't need to bother setting text color
			end
		end
	end
	Screen.dirty = true
end

-- Patch love.keyboard.isDown to make ctrl checking easier
local olkiD = love.keyboard.isDown
function love.keyboard.isDown(...)
	local keys = { ... }
	if #keys == 1 and keys[1] == "ctrl" then
		return olkiD("lctrl") or olkiD("rctrl")
	else
		return olkiD(unpack(keys))
	end
end

Emulator = {
	actions = {
		shutdown = nil,
		reboot = nil,
	},
	reboot = false, -- Tells update loop to start Emulator automatically
	running = false,
	FPS = 0,
	lastFPS = love.timer.getTime(),
}

function Emulator:start()
	if emuThread ~= nil and emuThread:isRunning() then return end
	murder:clear()
	demand:clear()
	self.reboot = false
	self.running = true
	emuThread = love.thread.newThread("emu.lua")
	emuThread:start()
	demand:push(_conf)
end

function Emulator:stop(reboot)
	murder:push(reboot)
	self.reboot = reboot
	self.running = false
	
	-- Reset events/key shortcuts
	self.actions.shutdown = nil
	self.actions.reboot = nil
end

function love.mousereleased(x, y, _button)
	downlink:push({"mousereleased",x, y, _button})
end

function love.mousepressed(x, y, button)
	downlink:push({"mousepressed",x, y, button})
end

function love.textinput(unicode)
	downlink:push({"textinput",unicode})
end

function love.keypressed(key, isrepeat)
	if love.keyboard.isDown("ctrl") and not isrepeat then
		if Emulator.actions.shutdown == nil and key == "s" then
			Emulator.actions.shutdown =  love.timer.getTime()
		elseif Emulator.actions.reboot == nil and key == "r" then
			Emulator.actions.reboot =    love.timer.getTime()
		end
	end
	if Emulator.running == false and not isrepeat then
		Emulator:start()
	elseif isrepeat and love.keyboard.isDown("ctrl") and (key == "s" or key == "r") then
	else
		downlink:push({"keypressed",key,isrepeat})
	end
end

function love.load()
	if love.system.getOS() == "Android" then
		love.keyboard.setTextInput(true)
	end

	if _conf.lockfps > 0 then 
		min_dt = 1/_conf.lockfps
		next_time = love.timer.getTime()
	end
	
	love.filesystem.setIdentity("ccemu")
	
	love.keyboard.setKeyRepeat(true)
	
	Emulator:start()
end

function love.visible(see)
	if see then
		Screen.dirty = true
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

function love.update()
	if _conf.lockfps > 0 then next_time = next_time + min_dt end
	local now = love.timer.getTime()
	if emuThread:isRunning() == false and Emulator.running == true then
		local errStr = emuThread:getError()
		print("[EMU] " .. errStr)
		if errStr ~= "emu.lua:1: GOODBYE WORLD" then
			error("[EMU] " .. errStr,math.huge)
		end
		Emulator.reboot = false
		Emulator.running = false
		Emulator.actions.shutdown = nil
		Emulator.actions.reboot = nil
	end
	if uplink:getCount() > 0 then
		print(uplink:getCount())
		for i = 1,uplink:getCount() do
			local msg = uplink:pop()
			print(msg[1])
			if msg[1] == "print" then
				print(unpack(msg,2))
			elseif msg[1] == "dead" then
				Emulator.reboot = msg[2]
				Emulator.running = false
				Emulator.actions.shutdown = nil
				Emulator.actions.reboot = nil
			elseif msg[1] == "initScreen" then
				api.comp = {
					cursorX = 1,
					cursorY = 1,
					bg = 32768,
					fg = 1,
					blink = false,
				}
				for y = 1, _conf.terminal_height do
					local screen_textB = Screen.textB[y]
					local screen_backgroundColourB = Screen.backgroundColourB[y]
					for x = 1, _conf.terminal_width do
						screen_textB[x] = " "
						screen_backgroundColourB[x] = 32768
					end
				end
				Screen.dirty = true
			elseif msg[1] == "dirtyScreen" then
				Screen.dirty = true
			elseif msg[1] == "termClear" then
				api.term.clear()
			elseif msg[1] == "termClearLine" then
				api.term.clearLine()
			elseif msg[1] == "termSetCursorPos" then
				api.term.setCursorPos(msg[2],msg[3])
			elseif msg[1] == "termWrite" then
				api.term.write(msg[2])
			elseif msg[1] == "termSetTextColor" then
				api.term.setTextColor(msg[2])
			elseif msg[1] == "termSetBackgroundColor" then
				api.term.setBackgroundColor(msg[2])
			elseif msg[1] == "termSetCursorBlink" then
				api.term.setCursorBlink(msg[2])
			elseif msg[1] == "termScroll" then
				api.term.scroll(msg[2])
			elseif msg[1] == "isDown" then
				demand:push(love.keyboard.isDown(msg[2]))
			elseif msg[1] == "screenMessage" then
				Screen:message(msg[2])
			else
				print("Unknown data: " .. table.concat(msg,", "))
			end
		end
	end
	updateShortcut("shutdown",  "ctrl", "s", function()
			Emulator:stop(false)
		end)
	updateShortcut("reboot",    "ctrl", "r", function()
			Emulator:stop(true)
		end)
	if Emulator.reboot then Emulator:start() end
	if _conf.cclite_showFPS then
		if now - Emulator.lastFPS >= 1 then
			Emulator.FPS = love.timer.getFPS()
			Emulator.lastFPS = now
			Screen.dirty = true
		end
	end
	if api.comp.blink then
		if Screen.lastCursor == nil then
			Screen.lastCursor = now
		end
		if now - Screen.lastCursor >= 0.25 then
			Screen.showCursor = not Screen.showCursor
			Screen.lastCursor = now
			if api.comp.cursorY >= 1 and api.comp.cursorY <= _conf.terminal_height and api.comp.cursorX >= 1 and api.comp.cursorX <= _conf.terminal_width then
				Screen.dirty = true
			end
		end
	end
	
	-- Messages
	for i = 1, 10 do
		if now - Screen.messages[i][2] > 4 and Screen.messages[i][3] == true then
			Screen.messages[i][3] = false
			Screen.dirty = true
		end
	end
end

function love.draw()
	Screen:draw()
	if _conf.cclite_showFPS then
		love.graphics.setColor({0,0,0})
		love.graphics.print("FPS: " .. tostring(Emulator.FPS), (Screen.sWidth) - (Screen.pixelWidth * 8), 11, 0, _conf.terminal_guiScale, _conf.terminal_guiScale)
		love.graphics.setColor({255,255,255})
		love.graphics.print("FPS: " .. tostring(Emulator.FPS), (Screen.sWidth) - (Screen.pixelWidth * 8) - 1, 10, 0, _conf.terminal_guiScale, _conf.terminal_guiScale)
	end
end

-- Use a more assumptive and non automatic screen clearing version of love.run
local lastDraw = love.timer.getTime()
function love.run()

    math.randomseed(os.time())
    math.random() math.random()

    love.event.pump()

    love.load(arg)

    -- Main loop time.
    while true do
        -- Process events.
        love.event.pump()
        for e,a,b,c,d in love.event.poll() do
            if e == "quit" then
                if not love.quit or not love.quit() then
                    return
                end
            end
            love.handlers[e](a,b,c,d)
        end

        -- Call update and draw
        love.update()
		if not love.window.isVisible() then Screen.dirty = false end

        if love.window.isCreated() and Screen.dirty and love.timer.getTime() - lastDraw >= 0.05 then
			Screen:draw()
			love.graphics.present()
			Screen.dirty = false
			lastDraw = love.timer.getTime()
        end

		love.timer.sleep(0.001)

    end

end