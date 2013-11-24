local ID = 1
function peripheral.diskDrive( sSide )
	-- DiskDrive is in progress, usage disabled
	if true then return end
	local obj = {}
	local content = {type = ""}
	local side = sSide
	function obj.getType() return "drive" end
	function obj.getMethods() return {"isDiskPresent","getDiskLabel","setDiskLabel","hasData","getMountPath","hasAudio","getAudioTitle","playAudio","stopAudio","ejectDisk","getDiskID"} end
	function obj.call( sMethod, ... )
		local tArgs = { ... }
		if sMethod == "isDiskPresent" then
			return content.type ~= ""
		elseif sMethod == "getDiskLabel" then
			return content.label
		elseif sMethod == "setDiskLabel" then
			sLabel = unpack(tArgs)
			if type(sLabel) ~= "string" and type(sLabel) ~= "nil" then
				error("Expected string",2)
			end
			if content.type == "data" then
				content.label = sLabel
			end
		elseif sMethod == "hasData" then
			return content.type == "data"
		elseif sMethod == "getMountPath" then
			-- How to handle this, emulator has no mounting system currently.
		elseif sMethod == "hasAudio" then
			return content.type == "audio"
		elseif sMethod == "getAudioTitle" then
			return content.title
		elseif sMethod == "playAudio" then
		elseif sMethod == "stopAudio" then
		elseif sMethod == "ejectDisk" then
			if content.type == "data" then table.insert(Emulator.eventQueue, {"disk_eject", side}) end
			content = {type = ""}
		elseif sMethod == "getDiskID" then
		else
			error("No such method " .. sMethod,2)
		end
	end
	function obj.ccliteCall( sMethod, ... )
		local tArgs = { ... }
		if sMethod == "diskLoad" then
			local sType, sLabel = unpack(tArgs)
			if type(sType) ~= "string" then error("Expected string",2) end
			if content.type ~= "" then error("Item already in disk drive",2) end
			if sType == "data" then
				if type(sLabel) ~= "string" and type(sLabel) ~= "nil" then error("Expected string, string or nil",2) end
				content = {type = "data", label = sLabel}
				table.insert(Emulator.eventQueue, {"disk", side})
			elseif sType == "audio" then
				if type(sLabel) ~= "string" then error("Expected string, string",2) end
				content = {type = "audio", title = sLabel}
			else
				error("Invalid type " .. sType,2)
			end
		else
			error("No such method " .. sMethod,2)
		end
	end
	return obj
end
