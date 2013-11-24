local typeC = {}
function peripheral.wiredModem()
	local obj = {}
	local remote = {}
	local channels = {}
	function obj.getType() return "modem" end
	function obj.getMethods() return {"open","isOpen","close","closeAll","transmit","isWireless","getNamesRemote","isPresentRemote","getTypeRemote","getMethodsRemote","callRemote"} end
	function obj.call( sMethod, ... )
		local tArgs = { ... }
		if sMethod == "open" then
			local nChannel = unpack(tArgs)
			if type(nChannel) ~= "number" then error("Expected number",2) end
			nChannel = math.floor(nChannel)
			if nChannel < 0 or nChannel > 65535 then error("Expected number in range 0-65535",2) end
			channels[nChannel] = true
		elseif sMethod == "isOpen" then
			local nChannel = unpack(tArgs)
			if type(nChannel) ~= "number" then error("Expected number",2) end
			nChannel = math.floor(nChannel)
			if nChannel < 0 or nChannel > 65535 then error("Expected number in range 0-65535",2) end
			return channels[nChannel] == true
		elseif sMethod == "close" then
			local nChannel = unpack(tArgs)
			if type(nChannel) ~= "number" then error("Expected number",2) end
			nChannel = math.floor(nChannel)
			if nChannel < 0 or nChannel > 65535 then error("Expected number in range 0-65535",2) end
			channels[nChannel] = false
		elseif sMethod == "closeAll" then
			for k,v in pairs(channels) do
				channels[k] = false
			end
		elseif sMethod == "transmit" then
			local nChannel, nReply, oMessage = unpack(tArgs)
			if type(nChannel) ~= "number" or type(nReply) ~= "number" then error("Expected number",2) end
			if oMessage == nil then error("2",2) end
		elseif sMethod == "isWireless" then
			return false
		elseif sMethod == "getNamesRemote" then
			local names = {}
			for k,v in pairs(remote) do
				table.insert(names,k)
			end
			return names
		elseif sMethod == "isPresentRemote" then
			local sSide = unpack(tArgs)
			if type(sSide) ~= "string" then error("Expected string",2) end
			return remote[sSide] ~= nil
		elseif sMethod == "getTypeRemote" then
			local sSide = unpack(tArgs)
			if type(sSide) ~= "string" then error("Expected string",2) end
			if remote[sSide] then return remote[sSide].getType() end
			return
		elseif sMethod == "getMethodsRemote" then
			local sSide = unpack(tArgs)
			if type(sSide) ~= "string" then error("Expected string",2) end
			if remote[sSide] then return remote[sSide].getMethods() end
			return
		elseif sMethod == "callRemote" then
			local sSide, sMethod = unpack(tArgs)
			if type(sSide) ~= "string" then error("Expected string",2) end
			if type(sMethod) ~= "string" then error("Expected string, string",2) end
			if not remote[sSide] then error("No peripheral attached",2) end
			return remote[sSide].call(sMethod, unpack(tArgs,3))
		else
			error("No such method " .. sMethod)
		end
	end
	function obj.ccliteCall( sMethod, ... )
		local tArgs = { ... }
		if sMethod == "peripheralAttach" then
			local sType = unpack(tArgs)
			if type(sType) ~= "string" then
				error("Expected string",2)
			end
			if not peripheral[sType] then
				error("No virtual peripheral of type " .. sType,2)
			end
			local tmpobj = peripheral[sType]()
			typeC[tmpobj.getType()] = (typeC[tmpobj.getType()] or -1) + 1
			remote[tmpobj.getType() .. "_" .. tostring(typeC[tmpobj.getType()])] = tmpobj
			table.insert(Emulator.eventQueue, {"peripheral",tmpobj.getType() .. "_" .. tostring(typeC[tmpobj.getType()])})
		elseif sMethod == "peripheralDetach" then
			local sSide = unpack(tArgs)
			if type(sSide) ~= "string" then error("Expected string",2) end
			if not remote[sSide] then
				error("No peripheral attached to " .. sSide,2)
			end
			remote[sSide] = nil
			table.insert(Emulator.eventQueue, {"peripheral_detach",sSide})
		else
			error("No such method " .. sMethod,2)
		end
	end
	return obj
end