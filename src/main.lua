require('render')

demand = love.thread.getChannel("demand")
downlink = love.thread.getChannel("downlink")
uplink = love.thread.getChannel("uplink")

-- Needed for term.write
-- This serialzier is bad, it is supposed to be bad. Don't use it.
local function serializeImpl( t, tTracking )	
	local sType = type(t)
	if sType == "table" then
		if tTracking[t] ~= nil then
			return nil
		end
		tTracking[t] = true
		
		local result = "{"
		for k,v in pairs(t) do
			local cache1 = serializeImpl(k, tTracking)
			local cache2 = serializeImpl(v, tTracking)
			if cache1 ~= nil and cache2 ~= nil then
				result = result..cache1.."="..cache2..", "
			end
		end
		if result:sub(-2,-1) == ", " then result = result:sub(1,-3) end
		result = result.."}"
		return result
	elseif sType == "string" then
		return t
	elseif sType == "number" then
		if t == math.huge then
			return "Infinity"
		elseif t == -math.huge then
			return "-Infinity"
		else
			return tostring(t):gsub("^[^e.]+%f[^0-9.]","%1.0"):gsub("e%+","e"):upper()
		end
	elseif sType == "boolean" then
		return tostring(t)
	else
		return nil
	end
end

local function serialize( t )
	local tTracking = {}
	return serializeImpl( t, tTracking ) or ""
end

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
	for y = 1, Screen.height do
		for x = 1, Screen.width do
			Screen.textB[y][x] = " "
			Screen.backgroundColourB[y][x] = api.comp.bg
			Screen.textColourB[y][x] = 1 -- Don't need to bother setting text color
		end
	end
	Screen.dirty = true
end
function api.term.clearLine()
	for x = 1, Screen.width do
		Screen.textB[api.comp.cursorY][x] = " "
		Screen.backgroundColourB[api.comp.cursorY][x] = api.comp.bg
		Screen.textColourB[api.comp.cursorY][x] = 1 -- Don't need to bother setting text color
	end
	Screen.dirty = true
end
function api.term.getSize()
	return Screen.width, Screen.height
end
function api.term.getCursorPos()
	return api.comp.cursorX, api.comp.cursorY
end
function api.term.setCursorPos(x, y)
	api.comp.cursorX = math.floor(x)
	api.comp.cursorY = math.floor(y)
	Screen.dirty = true
end
function api.term.write( text )
	text = serialize(text)
	if api.comp.cursorY > Screen.height
		or api.comp.cursorY < 1 then return end

	for i = 1, #text do
		local char = string.sub( text, i, i )
		if api.comp.cursorX + i - 1 <= Screen.width
			and api.comp.cursorX + i - 1 >= 1 then
			Screen.textB[api.comp.cursorY][api.comp.cursorX + i - 1] = char
			Screen.textColourB[api.comp.cursorY][api.comp.cursorX + i - 1] = api.comp.fg
			Screen.backgroundColourB[api.comp.cursorY][api.comp.cursorX + i - 1] = api.comp.bg
		end
	end
	api.comp.cursorX = api.comp.cursorX + #text
	Screen.dirty = true
end
function api.term.setTextColor( num )
	num = 2^math.floor(math.log(num)/math.log(2))
	api.comp.fg = num
	Screen.dirty = true
end
function api.term.setBackgroundColor( num )
	num = 2^math.floor(math.log(num)/math.log(2))
	api.comp.bg = num
end
function api.term.isColor()
	return true
end
function api.term.setCursorBlink( bool )
	api.comp.blink = bool
	Screen.dirty = true
end
function api.term.scroll( n )
	local textBuffer = {}
	local backgroundColourBuffer = {}
	local textColourBuffer = {}
	for y = 1, Screen.height do
		if y - n > 0 and y - n <= Screen.height then
			textBuffer[y - n] = {}
			backgroundColourBuffer[y - n] = {}
			textColourBuffer[y - n] = {}
			for x = 1, Screen.width do
				textBuffer[y - n][x] = Screen.textB[y][x]
				backgroundColourBuffer[y - n][x] = Screen.backgroundColourB[y][x]
				textColourBuffer[y - n][x] = Screen.textColourB[y][x]
			end
		end
	end
	for y = 1, Screen.height do
		if textBuffer[y] ~= nil then
			for x = 1, Screen.width do
				Screen.textB[y][x] = textBuffer[y][x]
				Screen.backgroundColourB[y][x] = backgroundColourBuffer[y][x]
				Screen.textColourB[y][x] = textColourBuffer[y][x]
			end
		else
			for x = 1, Screen.width do
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
function love.keyboard.isDown( ... )
	local keys = { ... }
	if #keys == 1 and keys[1] == "ctrl" then
		return olkiD("lctrl") or olkiD("rctrl")
	else
		return olkiD(unpack(keys))
	end
end

Emulator = {
	running = false,
	FPS = 0,
	lastFPS = love.timer.getTime(),
}

function love.mousereleased(x, y, _button)
	downlink:push({"mousereleased",x, y, _button})
end

function love.mousepressed(x, y, _button)
	downlink:push({"mousepressed",x, y, _button})
end

function love.textinput(unicode)
	downlink:push({"textinput",unicode})
end

function love.keypressed(key)
	downlink:push({"keypressed",key})
end

function love.load()

	if _conf.lockfps > 0 then 
		min_dt = 1/_conf.lockfps
		next_time = love.timer.getTime()
	end
	
	love.filesystem.setIdentity("ccemu")
	
	local glyphs = ""
	for i = 32,126 do
		glyphs = glyphs .. string.char(i)
	end
	font = love.graphics.newImageFont("res/minecraft.png",glyphs)
	font:setFilter("nearest","nearest")
	love.graphics.setFont(font)
	
	love.keyboard.setKeyRepeat( true )
	
	emuThread = love.thread.newThread("emu.lua")
	emuThread:start()
	demand:push(_conf)
end

function love.visible(see)
	if see then
		Screen.dirty = true
	end
end

function love.update()
	if _conf.lockfps > 0 then next_time = next_time + min_dt end
	local now = love.timer.getTime()
	if emuThread:isRunning() == false then
		error("[EMU] " .. emuThread:getError(),math.huge)
	end
	if uplink:getCount() > 0 then
		for i = 1,uplink:getCount() do
			local msg = uplink:pop()
			if msg[1] == "print" then
				print(unpack(msg,2))
			elseif msg[1] == "running" then
				Emulator.running = msg[2]
			elseif msg[1] == "initScreen" then
				api.comp = {
					cursorX = 1,
					cursorY = 1,
					bg = 32768,
					fg = 1,
					blink = false,
				}
				Screen:init()
			elseif msg[1] == "dirtyScreen" then
				Screen.dirty = true
			elseif msg[1] == "termClear" then
				api.term.clear()
			elseif msg[1] == "termClearLine" then
				api.term.clearLine()
			elseif msg[1] == "termGetCursorPos" then
				demand:push({api.term.getCursorPos()})
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
			elseif msg[1] == "getX" then
				demand:push(love.mouse.getX())
			elseif msg[1] == "getY" then
				demand:push(love.mouse.getY())
			elseif msg[1] == "mouseIsDown" then
				demand:push(love.mouse.isDown(msg[2]))
			else
				print("Unknown data: " .. table.concat(msg,", "))
			end
		end
	end
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
			Screen.dirty = true
		end
	end
end

local lastFPS,fps = love.timer.getTime(),love.timer.getFPS()
function love.draw()
	if Screen.dirty then
		Screen:draw()
		if _conf.cclite_showFPS then
			love.graphics.setColor({0,0,0})
			love.graphics.print("FPS: " .. tostring(Emulator.FPS), (Screen.sWidth) - (Screen.pixelWidth * 8), 11, 0, _conf.terminal_guiScale, _conf.terminal_guiScale)
			love.graphics.setColor({255,255,255})
			love.graphics.print("FPS: " .. tostring(Emulator.FPS), (Screen.sWidth) - (Screen.pixelWidth * 8) - 1, 10, 0, _conf.terminal_guiScale, _conf.terminal_guiScale)
		end
	end
	if _conf.lockfps > 0 then 
		local cur_time = love.timer.getTime()
		if next_time <= cur_time then
			next_time = cur_time
			return
		end
		--love.timer.sleep(next_time - cur_time)
	end
end

-- Use a more assumptive and non automatic screen clearing version of love.run
function love.run()

    math.randomseed(os.time())
    math.random() math.random()

    love.event.pump()

    love.load(arg)

    -- We don't want the first frame's dt to include time taken by love.load.
    love.timer.step()

    local dt = 0

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

        -- Update dt, as we'll be passing it to update
        love.timer.step()
        dt = love.timer.getDelta()

        -- Call update and draw
        love.update(dt) -- will pass 0 if love.timer is disabled
		if not love.window.isVisible() then Screen.dirty = false end

        if love.window and love.graphics and love.window.isCreated() then
            love.graphics.origin()
            love.draw()
            if Screen.dirty then love.graphics.present() end
			Screen.dirty = false
        end

        if love.timer then love.timer.sleep(0.001) end
    end

end