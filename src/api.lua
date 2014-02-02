api = {}
function api.init(Computer)
	--[[
		TODO
		HTTP api may be broken?
		including file handles.
	]]
	-- HELPER FUNCTIONS
	local function lines(str)
		local t = {}
		local function helper(line) table.insert(t, line) return "" end
		helper((str:gsub("(.-)\r?\n", helper)))
		if t[#t] == "" then t[#t] = nil end
		return t
	end

	-- HELPER CLASSES/HANDLES
	-- TODO Make more efficient, use love.filesystem.lines
	local HTTPHandle
	if _conf.enableAPI_http then
		function HTTPHandle(contents, status)
			local closed = false
			local lineIndex = 1
			local handle
			handle = {
				close = function()
					closed = true
				end,
				readLine = function()
					if closed then return end
					local str = contents[lineIndex]
					lineIndex = lineIndex + 1
					return str
				end,
				readAll = function()
					if closed then return end
					if lineIndex == 1 then
						lineIndex = #contents + 1
						return table.concat(contents, '\n')
					else
						local tData = {}
						local data = handle.readLine()
						while data ~= nil do
							table.insert(tData, data)
							data = handle.readLine()
						end
						return table.concat(tData, '\n')
					end
				end,
				getResponseCode = function()
					return status
				end
			}
			return handle
		end
	end

	-- Needed for term.write, (file).write, and (file).writeLine
	-- This serialzier is bad, it is supposed to be bad. Don't use it.
	local function serializeImpl(t, tTracking)	
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

	local function serialize(t)
		local tTracking = {}
		return serializeImpl(t, tTracking) or ""
	end

	local function FileReadHandle(path)
		if not vfs.exists(path) then
			return nil
		end
		local contents = {}
		for line in vfs.lines(path) do
			table.insert(contents, line)
		end
		local closed = false
		local lineIndex = 1
		local handle
		handle = {
			close = function()
				closed = true
			end,
			readLine = function()
				if closed then return end
				local str = contents[lineIndex]
				lineIndex = lineIndex + 1
				return str
			end,
			readAll = function()
				if closed then return end
				if lineIndex == 1 then
					lineIndex = #contents + 1
					return table.concat(contents, '\n')
				else
					local tData = {}
					local data = handle.readLine()
					while data ~= nil do
						table.insert(tData, data)
						data = handle.readLine()
					end
					return table.concat(tData, '\n')
				end
			end
		}
		return handle
	end

	local function FileBinaryReadHandle(path)
		if not vfs.exists(path) then
			return nil
		end
		local closed = false
		local File = vfs.newFile(path, "r")
		if File == nil then return end
		local handle = {
			close = function()
				closed = true
				File:close()
			end,
			read = function()
				if closed or File:eof() then return end
				return File:read(1):byte()
			end
		}
		return handle
	end

	local function FileWriteHandle(path, append)
		local closed = false
		local File = vfs.newFile(path, append and "a" or "w")
		if File == nil then return end
		local handle = {
			close = function()
				closed = true
				File:close()
			end,
			writeLine = function(data)
				if closed then error("Stream closed",2) end
				File:write(serialize(data) .. (_conf.useCRLF and "\r\n" or "\n"))
			end,
			write = function(data)
				if closed then error("Stream closed",2) end
				File:write(serialize(data))
			end,
			flush = function()
				File:flush()
			end
		}
		return handle
	end

	local function FileBinaryWriteHandle(path, append)
		local closed = false
		local File = vfs.newFile(path, append and "a" or "w")
		if File == nil then return end
		local handle = {
			close = function()
				closed = true
				File:close()
			end,
			write = function(data)
				if closed then return end
				if type(data) ~= "number" then return end
				while data < 0 do
					data = data + 256
				end
				File:write(string.char(data % 256))
			end,
			flush = function()
				File:flush()
			end
		}
		return handle
	end

	tmpapi = {}
	function tmpapi.loadstring(str, source)
		source = source or "string"
		if type(str) ~= "string" and type(str) ~= "number" then error("bad argument: string expected, got " .. type(str),2) end
		if type(source) ~= "string" and type(source) ~= "number" then error("bad argument: string expected, got " .. type(str),2) end
		local source2 = tostring(source)
		local sSS = source2:sub(1,1)
		if sSS == "@" or sSS == "=" then
			source2 = source2:sub(2)
		end
		local f, err = loadstring(str, "@" .. source2)
		if f == nil then
			-- Get the normal error message
			local _, err = loadstring(str, source)
			return f, err
		end
		jit.off(f) -- Required for "Too long without yielding"
		setfenv(f, tmpapi.env)
		return f, err
	end

	tmpapi.term = {}
	function tmpapi.term.clear()
		for y = 1, _conf.terminal_height do
			for x = 1, _conf.terminal_width do
				Screen.textB[y][x] = " "
				Screen.backgroundColourB[y][x] = tmpapi.comp.bg
				Screen.textColourB[y][x] = 1
			end
		end
		Screen.dirty = true
	end
	function tmpapi.term.clearLine()
		if tmpapi.comp.cursorY > _conf.terminal_height or tmpapi.comp.cursorY < 1 then
			return
		end
		for x = 1, _conf.terminal_width do
			Screen.textB[tmpapi.comp.cursorY][x] = " "
			Screen.backgroundColourB[tmpapi.comp.cursorY][x] = tmpapi.comp.bg
			Screen.textColourB[tmpapi.comp.cursorY][x] = 1
		end
		Screen.dirty = true
	end
	function tmpapi.term.getSize()
		return _conf.terminal_width, _conf.terminal_height
	end
	function tmpapi.term.getCursorPos()
		return tmpapi.comp.cursorX, tmpapi.comp.cursorY
	end
	function tmpapi.term.setCursorPos(x, y)
		if type(x) ~= "number" or type(y) ~= "number" then error("Expected number, number",2) end
		tmpapi.comp.cursorX = math.floor(x)
		tmpapi.comp.cursorY = math.floor(y)
		Screen.dirty = true
	end
	function tmpapi.term.write(text)
		text = serialize(text)
		if tmpapi.comp.cursorY > _conf.terminal_height or tmpapi.comp.cursorY < 1 or tmpapi.comp.cursorX > _conf.terminal_width then
			tmpapi.comp.cursorX = tmpapi.comp.cursorX + #text
			return
		end

		for i = 1, #text do
			local char = text:sub(i, i)
			if tmpapi.comp.cursorX + i - 1 >= 1 then
				if tmpapi.comp.cursorX + i - 1 > _conf.terminal_width then
					break
				end
				Screen.textB[tmpapi.comp.cursorY][tmpapi.comp.cursorX + i - 1] = char
				Screen.textColourB[tmpapi.comp.cursorY][tmpapi.comp.cursorX + i - 1] = tmpapi.comp.fg
				Screen.backgroundColourB[tmpapi.comp.cursorY][tmpapi.comp.cursorX + i - 1] = tmpapi.comp.bg
			end
		end
		tmpapi.comp.cursorX = tmpapi.comp.cursorX + #text
		Screen.dirty = true
	end
	function tmpapi.term.setTextColor(num)
		if type(num) ~= "number" then error("Expected number",2) end
		if num < 1 or num >= 65536 then
			error("Colour out of range",2)
		end
		num = 2^math.floor(math.log(num)/math.log(2))
		tmpapi.comp.fg = num
		Screen.dirty = true
	end
	function tmpapi.term.setBackgroundColor(num)
		if type(num) ~= "number" then error("Expected number",2) end
		if num < 1 or num >= 65536 then
			error("Colour out of range",2)
		end
		num = 2^math.floor(math.log(num)/math.log(2))
		tmpapi.comp.bg = num
	end
	function tmpapi.term.isColor()
		return true
	end
	function tmpapi.term.setCursorBlink(bool)
		if type(bool) ~= "boolean" then error("Expected boolean",2) end
		tmpapi.comp.blink = bool
		Screen.dirty = true
	end
	function tmpapi.term.scroll(n)
		if type(n) ~= "number" then error("Expected number",2) end
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
					Screen.backgroundColourB[y][x] = tmpapi.comp.bg
					Screen.textColourB[y][x] = 1 -- Don't need to bother setting text color
				end
			end
		end
		Screen.dirty = true
	end

	function tablecopy(orig)
		local orig_type = type(orig)
		local copy
		if orig_type == 'table' then
			copy = {}
			for orig_key, orig_value in pairs(orig) do
				copy[orig_key] = orig_value
			end
		else
			copy = orig
		end
		return copy
	end

	tmpapi.cclite = {}
	tmpapi.cclite.peripherals = {}
	if _conf.enableAPI_cclite then
		function tmpapi.cclite.peripheralAttach(sSide, sType)
			if type(sSide) ~= "string" or type(sType) ~= "string" then
				error("Expected string, string",2)
			end
			if not peripheral.base[sType] then
				error("No virtual peripheral of type " .. sType,2)
			end
			if tmpapi.cclite.peripherals[sSide] then
				error("Peripheral already attached to " .. sSide,2)
			end
			tmpapi.cclite.peripherals[sSide] = peripheral.base[sType](sSide)
			if tmpapi.cclite.peripherals[sSide] ~= nil then
				local methods = tmpapi.cclite.peripherals[sSide].getMethods()
				tmpapi.cclite.peripherals[sSide].cache = {}
				for i = 1,#methods do
					tmpapi.cclite.peripherals[sSide].cache[methods[i]] = true
				end
				local ccliteMethods = tmpapi.cclite.peripherals[sSide].ccliteGetMethods()
				tmpapi.cclite.peripherals[sSide].ccliteCache = {}
				for i = 1,#ccliteMethods do
					tmpapi.cclite.peripherals[sSide].ccliteCache[ccliteMethods[i]] = true
				end
				table.insert(Computer.eventQueue, {"peripheral",sSide})
			else
				error("No peripheral added",2)
			end
		end
		function tmpapi.cclite.peripheralDetach(sSide)
			if type(sSide) ~= "string" then error("Expected string",2) end
			if not tmpapi.cclite.peripherals[sSide] then
				error("No peripheral attached to " .. sSide,2)
			end
			tmpapi.cclite.peripherals[sSide] = nil
			table.insert(Computer.eventQueue, {"peripheral_detach",sSide})
		end
		function tmpapi.cclite.getMethods(sSide)
			if type(sSide) ~= "string" then error("Expected string",2) end
			if tmpapi.cclite.peripherals[sSide] then return tmpapi.cclite.peripherals[sSide].ccliteGetMethods() end
			return
		end
		function tmpapi.cclite.call(sSide, sMethod, ...)
			if type(sSide) ~= "string" then error("Expected string",2) end
			if type(sMethod) ~= "string" then error("Expected string, string",2) end
			if not tmpapi.cclite.peripherals[sSide] then error("No peripheral attached",2) end
			return tmpapi.cclite.peripherals[sSide].ccliteCall(Computer, sMethod, ...)
		end
		function tmpapi.cclite.message(sMessage)
			if type(sMessage) ~= "string" then error("Expected string",2) end
			Screen:message(sMessage)
		end
	end

	if _conf.enableAPI_http then
		tmpapi.http = {}
		function tmpapi.http.request(sUrl, sParams)
			if type(sUrl) ~= "string" then
				error("String expected" .. (sUrl == nil and ", got nil" or ""),2)
			end
			if sUrl:sub(1,5) ~= "http:" and sUrl:sub(1,6) ~= "https:" then
				error("Invalid URL",2)
			end
			local http = HttpRequest.new()
			local method = sParams and "POST" or "GET"

			http.open(method, sUrl, true)

			if method == "POST" then
				http.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
				http.setRequestHeader("Content-Length", sParams:len())
			end

			http.onReadyStateChange = function()
				if http.status == 200 then
					local handle = HTTPHandle(lines(http.responseText), http.status)
					table.insert(Computer.eventQueue, {"http_success", sUrl, handle})
				else
					table.insert(Computer.eventQueue, {"http_failure", sUrl})
				end
			end

			http.send(sParams)
		end
	end

	tmpapi.os = {}
	function tmpapi.os.clock()
		return math.floor(os.clock()*20)/20 - tmpapi.comp.startTime
	end
	function tmpapi.os.time()
		return math.floor((os.clock()*0.02)%24*1000)/1000
	end
	function tmpapi.os.day()
		return math.floor(os.clock()/1200)
	end
	function tmpapi.os.setComputerLabel(label)
		if type(label) ~= "string" and type(label) ~= "nil" then error("Expected string or nil",2) end
		tmpapi.comp.label = label
	end
	function tmpapi.os.getComputerLabel()
		return tmpapi.comp.label
	end
	function tmpapi.os.queueEvent(event, ...)
		if type(event) ~= "string" then error("Expected string",2) end
		table.insert(Computer.eventQueue, {event, ...})
	end
	function tmpapi.os.startTimer(nTimeout)
		if type(nTimeout) ~= "number" then error("Expected number",2) end
		nTimeout = math.ceil(nTimeout*20)/20
		if nTimeout < 0.05 then nTimeout = 0.05 end
		Computer.actions.lastTimer = Computer.actions.lastTimer + 1
		Computer.actions.timers[Computer.actions.lastTimer] = math.floor(love.timer.getTime()*20)/20 + nTimeout
		return Computer.actions.lastTimer
	end
	function tmpapi.os.setAlarm(nTime)
		if type(nTime) ~= "number" then error("Expected number",2) end
		if nTime < 0 or nTime > 24 then
			error("Number out of range: " .. tostring(nTime))
		end
		local alarm = {
			time = nTime,
			day = tmpapi.os.day() + (nTime < tmpapi.os.time() and 1 or 0)
		}
		Computer.actions.lastAlarm = Computer.actions.lastAlarm + 1
		Computer.actions.alarms[Computer.actions.lastAlarm] = alarm
		return Computer.actions.lastAlarm
	end
	function tmpapi.os.shutdown()
		Computer:stop(false)
	end
	function tmpapi.os.reboot()
		Computer:stop(true) -- Reboots on next update/tick
	end

	tmpapi.peripheral = {}
	function tmpapi.peripheral.isPresent(sSide)
		if type(sSide) ~= "string" then error("Expected string",2) end
		return tmpapi.cclite.peripherals[sSide] ~= nil
	end
	function tmpapi.peripheral.getType(sSide)
		if type(sSide) ~= "string" then error("Expected string",2) end
		if tmpapi.cclite.peripherals[sSide] then return peripheral.types[tmpapi.cclite.peripherals[sSide].type] end
		return
	end
	function tmpapi.peripheral.getMethods(sSide)
		if type(sSide) ~= "string" then error("Expected string",2) end
		if tmpapi.cclite.peripherals[sSide] then return tmpapi.cclite.peripherals[sSide].getMethods() end
		return
	end
	function tmpapi.peripheral.call(sSide, sMethod, ...)
		if type(sSide) ~= "string" or type(sMethod) ~= "string" then error("Expected string, string",2) end
		if not tmpapi.cclite.peripherals[sSide] then error("No peripheral attached",2) end
		if not tmpapi.cclite.peripherals[sSide].cache[sMethod] then
			error("No such method " .. sMethod,2)
		end
		return tmpapi.cclite.peripherals[sSide].call(Computer, sMethod, ...)
	end
	function tmpapi.peripheral.getNames()
		local names = {}
		for k,v in pairs(tmpapi.cclite.peripherals) do
			table.insert(names,k)
		end
		return names
	end

	tmpapi.fs = {}
	function tmpapi.fs.combine(basePath, localPath)
		if type(basePath) ~= "string" or type(localPath) ~= "string" then
			error("Expected string, string",2)
		end
		local path = ("/" .. basePath .. "/" .. localPath):gsub("\\", "/")
		
		local cleanName = ""
		for i = 1,#path do
			local c = path:sub(i,i):byte()
			if c >= 32 and c ~= 34 and c ~= 42 and c ~= 58 and c ~= 60 and c ~= 62 and c ~= 63 and c ~= 124 then
				cleanName = cleanName .. string.char(c)
			end
		end
		
		local tPath = {}
		for part in cleanName:gmatch("[^/]+") do
			if part ~= "" and part ~= "." then
				if part == ".." and #tPath > 0 and tPath[1] ~= ".." then
					table.remove(tPath)
				else
					table.insert(tPath, part:sub(1,255))
				end
			end
		end
		return table.concat(tPath, "/")
	end

	local function contains(pathA, pathB)
		pathA = tmpapi.fs.combine(pathA,"")
		pathB = tmpapi.fs.combine(pathB,"")

		if pathB == ".." then
			return false
		elseif pathB:sub(1,3) == "../" then
			return false
		elseif pathB == pathA then
			return true
		elseif #pathA == 0 then
			return true
		else
			return pathB:sub(1,#pathA+1) == pathA .. "/"
		end
	end

	function tmpapi.fs.open(path, mode)
		if type(path) ~= "string" or type(mode) ~= "string" then
			error("Expected string, string",2)
		end
		local testpath = tmpapi.fs.combine("data/", path)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		path = vfs.normalize(path)
		if mode == "r" then
			return FileReadHandle(path)
		elseif mode == "rb" then
			return FileBinaryReadHandle(path)
		elseif mode == "w" or mode == "a" then
			return FileWriteHandle(path,mode == "a")
		elseif mode == "wb" or mode == "ab" then
			return FileBinaryWriteHandle(path,mode == "ab")
		else
			error("Unsupported mode",2)
		end
	end
	function tmpapi.fs.list(path)
		if type(path) ~= "string" then
			error("Expected string",2)
		end
		local testpath = tmpapi.fs.combine("data/", path)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		path = vfs.normalize(path)
		if not vfs.exists(path) or not vfs.isDirectory(path) then
			error("Not a directory",2)
		end
		return vfs.getDirectoryItems(path)
	end
	function tmpapi.fs.exists(path)
		if type(path) ~= "string" then
			error("Expected string",2)
		end
		local testpath = tmpapi.fs.combine("data/", path)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then return false end
		path = vfs.normalize(path)
		return vfs.exists(path)
	end
	function tmpapi.fs.isDir(path)
		if type(path) ~= "string" then
			error("Expected string",2)
		end
		local testpath = tmpapi.fs.combine("data/", path)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then return false end
		path = vfs.normalize(path)
		return vfs.isDirectory(path)
	end
	function tmpapi.fs.isReadOnly(path)
		if type(path) ~= "string" then
			error("Expected string",2)
		end
		path = vfs.normalize(path)
		return path == "/rom" or path:sub(1, 5) == "/rom/"
	end
	function tmpapi.fs.getName(path)
		if type(path) ~= "string" then
			error("Expected string",2)
		end
		path = vfs.normalize(path)
		if path == "/" then
			return "root"
		end
		local fpath, name, ext = path:match("(.-)([^\\/]-%.?([^%.\\/]*))$")
		return name
	end
	function tmpapi.fs.getSize(path)
		if type(path) ~= "string" then
			error("Expected string",2)
		end
		local testpath = tmpapi.fs.combine("data/", path)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		path = vfs.normalize(path)
		if vfs.exists(path) ~= true then
			error("No such file",2)
		end

		if vfs.isDirectory(path) then
			return 0
		end
		
		local size = vfs.getSize(path)
		return math.ceil(size/512)*512
	end

	function tmpapi.fs.getFreeSpace(path)
		if type(path) ~= "string" then
			error("Expected string",2)
		end
		local testpath = tmpapi.fs.combine("data/", path)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		if path == "/rom" or path:sub(1, 5) == "/rom/" then
			return 0
		end
		return math.huge
	end

	function tmpapi.fs.makeDir(path) -- All write functions are within data/
		if type(path) ~= "string" then
			error("Expected string",2)
		end
		local testpath = tmpapi.fs.combine("data/", path)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		path = vfs.normalize(path)
		if path == "/rom" or path:sub(1, 5) == "/rom/" then
			error("Access Denied",2)
		end
		if vfs.exists(path) and not vfs.isDirectory(path) then
			error("File exists",2)
		end
		vfs.createDirectory(path)
	end

	local function deltree(sFolder)
		local tObjects = vfs.getDirectoryItems(sFolder)

		if tObjects then
			for _, sObject in pairs(tObjects) do
				local pObject =  sFolder.."/"..sObject

				if vfs.isDirectory(pObject) then
					deltree(pObject)
				end
				vfs.remove(pObject)
			end
		end
		return vfs.remove(sFolder)
	end

	local function copytree(sFolder, sToFolder)
		if not vfs.isDirectory(sFolder) then
			vfs.write(sToFolder, vfs.read(sFolder))
			return
		end
		vfs.createDirectory(sToFolder)
		local tObjects = vfs.getDirectoryItems(sFolder)

		if tObjects then
			for _, sObject in pairs(tObjects) do
				local pObject =  sFolder.."/"..sObject
				local pToObject = sToFolder.."/"..sObject

				if vfs.isDirectory(pObject) then
					vfs.createDirectory(pToObject)
					copytree(pObject,pToObject)
				else
					vfs.write(pToObject, vfs.read(pObject))
				end
			end
		end
	end

	function tmpapi.fs.move(fromPath, toPath)
		if type(fromPath) ~= "string" or type(toPath) ~= "string" then
			error("Expected string, string",2)
		end
		local testpath = tmpapi.fs.combine("data/", fromPath)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		local testpath = tmpapi.fs.combine("data/", toPath)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		fromPath = vfs.normalize(fromPath)
		toPath = vfs.normalize(toPath)
		if fromPath == "/rom" or fromPath:sub(1, 5) == "/rom/" or 
			toPath == "/rom" or toPath:sub(1, 5) == "/rom/" then
			error("Access Denied",2)
		end
		if vfs.exists(fromPath) ~= true then
			error("No such file",2)
		end
		if vfs.exists(toPath) == true then
			error("File exists",2)
		end
		if contains(fromPath, toPath) then
			error("Can't move a directory inside itself",2)
		end
		copytree(fromPath, toPath)
		deltree(fromPath)
	end

	function tmpapi.fs.copy(fromPath, toPath)
		if type(fromPath) ~= "string" or type(toPath) ~= "string" then
			error("Expected string, string",2)
		end
		local testpath = tmpapi.fs.combine("data/", fromPath)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		local testpath = tmpapi.fs.combine("data/", toPath)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		fromPath = vfs.normalize(fromPath)
		toPath = vfs.normalize(toPath)
		if toPath == "/rom" or toPath:sub(1, 5) == "/rom/" then
			error("Access Denied",2)
		end
		if vfs.exists(fromPath) ~= true then
			error("No such file",2)
		end
		if vfs.exists(toPath) == true then
			error("File exists",2)
		end
		if contains(fromPath, toPath) then
			error("Can't copy a directory inside itself",2)
		end
		copytree(fromPath, toPath)
	end

	function tmpapi.fs.delete(path)
		if type(path) ~= "string" then error("Expected string",2) end
		local testpath = tmpapi.fs.combine("data/", path)
		if testpath:sub(1,5) ~= "data/" and testpath ~= "data" then error("Invalid Path",2) end
		path = vfs.normalize(path)
		if path == "/rom" or path:sub(1, 5) == "/rom/" or vfs.isMountPath(path) then
			error("Access Denied",2)
		end
		deltree(path)
	end

	tmpapi.redstone = {}
	function tmpapi.redstone.getSides()
		return {"top","bottom","left","right","front","back"}
	end
	function tmpapi.redstone.getInput(side)
		if type(side) ~= "string" then
			error("Expected string",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
		return false
	end
	function tmpapi.redstone.setOutput(side, value)
		if type(side) ~= "string" or type(value) ~= "boolean" then
			error("Expected string, boolean",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
	end
	function tmpapi.redstone.getOutput(side)
		if type(side) ~= "string" then
			error("Expected string",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
		return false
	end
	function tmpapi.redstone.getAnalogInput(side)
		if type(side) ~= "string" then
			error("Expected string",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
		return 0
	end
	function tmpapi.redstone.setAnalogOutput(side, strength)
		if type(side) ~= "string" or type(strength) ~= "number" then
			error("Expected string, number",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
	end
	function tmpapi.redstone.getAnalogOutput(side)
		if type(side) ~= "string" then
			error("Expected string",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
		return 0
	end
	function tmpapi.redstone.getBundledInput(side)
		if type(side) ~= "string" then
			error("Expected string",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
		return 0
	end
	function tmpapi.redstone.getBundledOutput(sude)
		if type(side) ~= "string" then
			error("Expected string",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
		return 0
	end
	function tmpapi.redstone.setBundledOutput(side, colors)
		if type(side) ~= "string" or type(colors) ~= "number" then
			error("Expected string, number",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
	end
	function tmpapi.redstone.testBundledInput(side, color)
		if type(side) ~= "string" or type(color) ~= "number" then
			error("Expected string, number",2)
		elseif side~="top" and side~="bottom" and side~="left" and side~="right" and side~="front" and side~="back" then
			error("Invalid side.",2)
		end
		return color == 0
	end

	tmpapi.bit = {}
	function tmpapi.bit.norm(val)
		while val < 0 do val = val + 4294967296 end
		return val
	end
	function tmpapi.bit.blshift(n, bits)
		if (type(n) ~= "number" and type(n) ~= "nil") or (type(bits) ~= "number" and type(bits) ~= "nil") then
			error("number expected",2)
		elseif n == nil or bits == nil then
			error("too few arguments",2)
		end
		return tmpapi.bit.norm(bit.lshift(n, bits))
	end
	function tmpapi.bit.brshift(n, bits)
		if (type(n) ~= "number" and type(n) ~= "nil") or (type(bits) ~= "number" and type(bits) ~= "nil") then
			error("number expected",2)
		elseif n == nil or bits == nil then
			error("too few arguments",2)
		end
		return tmpapi.bit.norm(bit.arshift(n, bits))
	end
	function tmpapi.bit.blogic_rshift(n, bits)
		if (type(n) ~= "number" and type(n) ~= "nil") or (type(bits) ~= "number" and type(bits) ~= "nil") then
			error("number expected",2)
		elseif n == nil or bits == nil then
			error("too few arguments",2)
		end
		return tmpapi.bit.norm(bit.rshift(n, bits))
	end
	function tmpapi.bit.bxor(m, n)
		if (type(m) ~= "number" and type(m) ~= "nil") or (type(n) ~= "number" and type(n) ~= "nil") then
			error("number expected",2)
		elseif m == nil or n == nil then
			error("too few arguments",2)
		end
		return tmpapi.bit.norm(bit.bxor(m, n))
	end
	function tmpapi.bit.bor(m, n)
		if (type(m) ~= "number" and type(m) ~= "nil") or (type(n) ~= "number" and type(n) ~= "nil") then
			error("number expected",2)
		elseif m == nil or n == nil then
			error("too few arguments",2)
		end
		return tmpapi.bit.norm(bit.bor(m, n))
	end
	function tmpapi.bit.band(m, n)
		if (type(m) ~= "number" and type(m) ~= "nil") or (type(n) ~= "number" and type(n) ~= "nil") then
			error("number expected",2)
		elseif m == nil or n == nil then
			error("too few arguments",2)
		end
		return tmpapi.bit.norm(bit.band(m, n))
	end
	function tmpapi.bit.bnot(n)
		if type(n) ~= "number" and type(n) ~= "nil" then
			error("number expected",2)
		elseif n == nil then
			error("too few arguments",2)
		end
		return tmpapi.bit.norm(bit.bnot(n))
	end

	tmpapi.comp = {
		cursorX = 1,
		cursorY = 1,
		bg = 32768,
		fg = 1,
		blink = false,
		label = nil,
		startTime = math.floor(os.clock()*20)/20
	}
	tmpapi.env = {
		_VERSION = "Luaj-jse 2.0.3",
		tostring = tostring,
		tonumber = tonumber,
		unpack = unpack,
		getfenv = getfenv,
		setfenv = setfenv,
		rawequal = rawequal,
		rawset = rawset,
		rawget = rawget,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		next = next,
		type = type,
		select = select,
		assert = assert,
		error = error,
		ipairs = ipairs,
		pairs = pairs,
		pcall = pcall,
		loadstring = tmpapi.loadstring,
		math = tablecopy(math),
		string = tablecopy(string),
		table = tablecopy(table),
		coroutine = tablecopy(coroutine),

		-- CC apis (BIOS completes tmpapi.)
		term = {
			native = {
				clear = tmpapi.term.clear,
				clearLine = tmpapi.term.clearLine,
				getSize = tmpapi.term.getSize,
				getCursorPos = tmpapi.term.getCursorPos,
				setCursorPos = tmpapi.term.setCursorPos,
				setTextColor = tmpapi.term.setTextColor,
				setTextColour = tmpapi.term.setTextColor,
				setBackgroundColor = tmpapi.term.setBackgroundColor,
				setBackgroundColour = tmpapi.term.setBackgroundColor,
				setCursorBlink = tmpapi.term.setCursorBlink,
				scroll = tmpapi.term.scroll,
				write = tmpapi.term.write,
				isColor = tmpapi.term.isColor,
				isColour = tmpapi.term.isColor,
			},
			clear = tmpapi.term.clear,
			clearLine = tmpapi.term.clearLine,
			getSize = tmpapi.term.getSize,
			getCursorPos = tmpapi.term.getCursorPos,
			setCursorPos = tmpapi.term.setCursorPos,
			setTextColor = tmpapi.term.setTextColor,
			setTextColour = tmpapi.term.setTextColor,
			setBackgroundColor = tmpapi.term.setBackgroundColor,
			setBackgroundColour = tmpapi.term.setBackgroundColor,
			setCursorBlink = tmpapi.term.setCursorBlink,
			scroll = tmpapi.term.scroll,
			write = tmpapi.term.write,
			isColor = tmpapi.term.isColor,
			isColour = tmpapi.term.isColor,
		},
		fs = {
			open = tmpapi.fs.open,
			list = tmpapi.fs.list,
			exists = tmpapi.fs.exists,
			isDir = tmpapi.fs.isDir,
			isReadOnly = tmpapi.fs.isReadOnly,
			getName = tmpapi.fs.getName,
			getDrive = function(path) return nil end, -- Dummy function
			getSize = tmpapi.fs.getSize,
			getFreeSpace = tmpapi.fs.getFreeSpace,
			makeDir = tmpapi.fs.makeDir,
			move = tmpapi.fs.move,
			copy = tmpapi.fs.copy,
			delete = tmpapi.fs.delete,
			combine = tmpapi.fs.combine,
		},
		os = {
			clock = tmpapi.os.clock,
			getComputerID = function() return 0 end,
			computerID = function() return 0 end,
			setComputerLabel = tmpapi.os.setComputerLabel,
			getComputerLabel = tmpapi.os.getComputerLabel,
			computerLabel = tmpapi.os.getComputerLabel,
			queueEvent = tmpapi.os.queueEvent,
			startTimer = tmpapi.os.startTimer,
			setAlarm = tmpapi.os.setAlarm,
			time = tmpapi.os.time,
			day = tmpapi.os.day,
			shutdown = tmpapi.os.shutdown,
			reboot = tmpapi.os.reboot,
		},
		peripheral = {
			isPresent = tmpapi.peripheral.isPresent,
			getType = tmpapi.peripheral.getType,
			getMethods = tmpapi.peripheral.getMethods,
			call = tmpapi.peripheral.call,
			getNames = tmpapi.peripheral.getNames,
		},
		redstone = {
			getSides = tmpapi.redstone.getSides,
			getInput = tmpapi.redstone.getInput,
			getOutput = tmpapi.redstone.getOutput,
			getBundledInput = tmpapi.redstone.getBundledInput,
			getBundledOutput = tmpapi.redstone.getBundledOutput,
			getAnalogInput = tmpapi.redstone.getAnalogInput,
			getAnalogOutput = tmpapi.redstone.getAnalogOutput,
			setOutput = tmpapi.redstone.setOutput,
			setBundledOutput = tmpapi.redstone.setBundledOutput,
			setAnalogOutput = tmpapi.redstone.setAnalogOutput,
			testBundledInput = tmpapi.redstone.testBundledInput,
		},
		bit = {
			blshift = tmpapi.bit.blshift,
			brshift = tmpapi.bit.brshift,
			blogic_rshift = tmpapi.bit.blogic_rshift,
			bxor = tmpapi.bit.bxor,
			bor = tmpapi.bit.bor,
			band = tmpapi.bit.band,
			bnot = tmpapi.bit.bnot,
		},
	}
	if _conf.enableAPI_http then
		tmpapi.env.http = {
			request = tmpapi.http.request,
		}
	end
	if _conf.enableAPI_cclite then
		tmpapi.env.cclite = {
			peripheralAttach = tmpapi.cclite.peripheralAttach,
			peripheralDetach = tmpapi.cclite.peripheralDetach,
			getMethods = tmpapi.cclite.getMethods,
			call = tmpapi.cclite.call,
			log = print,
			message = tmpapi.cclite.message,
			traceback = debug.traceback,
		}
	end
	tmpapi.env.redstone.getAnalogueInput = tmpapi.env.redstone.getAnalogInput
	tmpapi.env.redstone.getAnalogueOutput = tmpapi.env.redstone.getAnalogOutput
	tmpapi.env.redstone.setAnalogueOutput = tmpapi.env.redstone.setAnalogOutput
	tmpapi.env.rs = tmpapi.env.redstone
	tmpapi.env.math.mod = nil
	tmpapi.env.string.gfind = nil
	tmpapi.env._G = tmpapi.env
	return tmpapi
end