local ID = 1
local function baseobj( sType )
	local obj = {}
	local myID = ID
	ID = ID + 1
	function obj.getType() return sType end
	function obj.getMethods() return {"turnOn", "shutdown", "reboot", "getID"} end
	function obj.call( sMethod )
		if sMethod == "turnOn" then
		elseif sMethod == "shutdown" then
		elseif sMethod == "reboot" then
		elseif sMethod == "getID" then
			return myID
		else
			error("No such method " .. sMethod,2)
		end
	end
	return obj
end

function peripheral.computer() return baseobj("computer") end
function peripheral.turtle() return baseobj("turtle") end