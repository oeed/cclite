local ltn12  = require("ltn12")
local httpRequest = require("socket.http")
local httpResponseBody = {}
local httpResponseText = ""
local httpParams = {}
local httpsSupport, httpsRequest, cChannel

function waitForInstructions(channel,supportHTTPS,httpParamsMsg)
	cChannel = channel

	assert(type(supportHTTPS) == "boolean", "HTTPS support flag invalid.")
	assert(type(httpParamsMsg) == "string", "HTTP parameters invalid.")

	httpsSupport = supportHTTPS
	if supportHTTPS == true then
		httpsRequest = require("ssl.https")
	end
	httpParams = TSerial.unpack(httpParamsMsg)

	httpParams.redirects = 0
	sendRequest()
end

-- ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

function sendRequest()
	httpRequest.TIMEOUT = 21

	-- send request:
	local result  =
	{
		(httpParams.url:sub(1,6) == "https:" and httpsSupport == true and httpsRequest or httpRequest).request
		{
			method = httpParams.method,
			url = httpParams.url,
			headers = httpParams.headers,
			source = ltn12.source.string(httpParams.body),
			sink = ltn12.sink.table(httpResponseBody),
			redirect = false
		}
	}

	if (result[2] == 302 or result[2] == 301) and httpParams.redirects < 19 and httpParams.url ~= result[3].location then -- Infinite loop detection
		httpResponseBody = {}
		httpParams.url = result[3]["location"]
		httpParams.redirects = httpParams.redirects + 1
		return sendRequest()
	end

	-- compile responseText
	for k,v in ipairs(httpResponseBody) do
		httpResponseText = httpResponseText .. tostring(v)
	end

	-- insert responseText in to result table
	table.insert(result, httpResponseText)

	-- send results back to handler
	cChannel:push(TSerial.pack(result))
end

-- ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-- TSerial v1.23, a simple table serializer which turns tables into Lua script
-- by Taehl (SelfMadeSpirit@gmail.com)

-- Usage: table = TSerial.unpack( TSerial.pack(table) )
TSerial = {}
function TSerial.pack(t)
	assert(type(t) == "table", "Can only TSerial.pack tables.")
	local s = "{"
	for k, v in pairs(t) do
		local tk, tv = type(k), type(v)
		if tk == "boolean" then k = k and "[true]" or "[false]"
		elseif tk == "string" then if string.find(k, "[%c%p%s]") then k = '["'..k..'"]' end
		elseif tk == "number" then k = "["..k.."]"
		elseif tk == "table" then k = "["..TSerial.pack(k).."]"
		else error("Attempted to Tserialize a table with an invalid key: "..tostring(k))
		end
		if tv == "boolean" then v = v and "true" or "false"
		elseif tv == "string" then v = string.format("%q", v)
		elseif tv == "number" then  -- no change needed
		elseif tv == "table" then v = TSerial.pack(v)
		else error("Attempted to Tserialize a table with an invalid value: "..tostring(v))
		end
		s = s..k.."="..v..","
	end
	return s.."}"
end

function TSerial.unpack(s)
	assert(type(s) == "string", "TSerial.unpack: string expected, got " .. type(s))
	return assert(loadstring("return "..s))()
end

-- ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

waitForInstructions(...)
