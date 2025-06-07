local ch1, ch2 = ...

local socket = require("socket").bind("localhost", 8193)
local json = require("common.lib.json")
local inspect = require("common.lib.inspect")
local client = socket:accept()

while true do
    local header = client:receive("*l")

    assert(header:sub(1,16) == "Content-Length: ")

    local content_length = tonumber(header:sub(16,-1))

    local emptyline = client:receive("*l")

    assert(emptyline == "")

    local body = client:receive(content_length)
    local command = json.decode(body)
    ch1:push(command)

    local response = ch2:demand()
    local jsonresponse = json.encode({ result=response, id=command.id, jsonrpc="2.0" })
    client:send("Content-Length: "..tostring(#jsonresponse).."\r\n\r\n"..jsonresponse)
end
