local ID = 1
function peripheral.computer()
	local obj = {}
	local myID = ID
	ID = ID + 1
	function obj.getType() return "computer" end
	function obj.getMethods() return {"turnOn", "shutdown", "reboot", "getID"} end
	function obj.call( sMethod )
		if sMethod == "getID" then
			return myID
		end
	end
	return obj
end

function peripheral.turtle()
	local obj = {}
	local myID = ID
	ID = ID + 1
	function obj.getType() return "turtle" end
	function obj.getMethods() return {"turnOn", "shutdown", "reboot", "getID"} end
	function obj.call( sMethod )
		if sMethod == "getID" then
			return myID
		end
	end
	return obj
end