HttpRequest = {}
HttpRequest.activeRequests = {}

function HttpRequest.new()
    local self = {}

    local httpParams        = {}
    httpParams.headers      = {}

    self.requestThread      = nil
    self.requestChannel     = nil
    self.onReadyStateChange = function() end
    self.responseText       = ""
    self.status             = nil

    self.open = function(pMethod, pUrl)
        httpParams.method   = pMethod or "GET"
        httpParams.url      = pUrl
    end
    ---------------------------------------------------------------------
    self.send = function(pString)
        httpParams.body = pString or ""

        self.requestThread = love.thread.newThread("http/HttpRequest_thread.lua")
        self.requestChannel = love.thread.newChannel()

        self.requestThread:start(self.requestChannel,_conf.useLuaSec,TSerial.pack(httpParams))
    end
    ---------------------------------------------------------------------
    self.setRequestHeader = function(pName, pValue)
        httpParams.headers[pName] = pValue
    end
    ---------------------------------------------------------------------
    self.checkRequest = function()
        -- look for async thread response message
        if self.requestChannel and self.requestChannel:getCount() > 0 then
            --unpack message
            result = TSerial.unpack(self.requestChannel:pop())

            self.requestChannel:clear()

            --set status
            self.status = result[2]
            --set responseText
            self.responseText = result[5]

            --remove request from activeRequests
            for index = 1, #HttpRequest.activeRequests do
                if HttpRequest.activeRequests[index].id == self.id then
                    table.remove(HttpRequest.activeRequests, index)
					break
                end
            end

            --finally call onReadyStateChange callback
            self.onReadyStateChange()
        end
    end
    ---------------------------------------------------------------------

    table.insert(HttpRequest.activeRequests, self)
    return HttpRequest.activeRequests[table.getn(HttpRequest.activeRequests)]
end


function HttpRequest.checkRequests()
    for k, v in ipairs(HttpRequest.activeRequests) do
        if HttpRequest.activeRequests[k] ~= nil then
            HttpRequest.activeRequests[k].checkRequest()
        end
    end
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
