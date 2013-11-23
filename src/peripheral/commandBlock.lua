function peripheral.commandBlock()
	local obj = {}
	local cmd = ""
	function obj.getType() return "command" end
	function obj.getMethods() return {"getCommand", "setCommand", "runCommand"} end
	function obj.call( sMethod, ... )
		local tArgs = { ... }
		if sMethod == "getCommand" then
			return cmd
		elseif sMethod == "setCommand" then
			if type(tArgs[1]) ~= "string" then error("Expected string",2) end
			cmd = tArgs[1]
		elseif sMethod == "runCommand" then
		else
			error("No such method " .. sMethod,2)
		end
	end
	return obj
end