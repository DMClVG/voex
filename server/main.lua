package.path = package.path .. ";?/init.lua"
require("common")
inspect = require("common.lib.inspect")

CHANNEL_ONE = 0
CHANNEL_CHUNKS = 1
CHANNEL_EVENTS = 3
CHANNEL_UPDATES = 4

local commands = {}
local client

function commands.list(path)
   print(inspect(_G[path]))
   return "ok :)"
end

function yieldreceive(client, pattern)
   local acc = ""

   while true do
      local packet, err, partial = client:receive(pattern)
      if packet then return acc..packet end

      if err == "timeout" and partial then
	 acc = acc .. partial
	 pattern = pattern - #partial
	 if pattern == 0 then return acc end

	 coroutine.yield()
      elseif err == "timeout" then
	 coroutine.yield()
      else
	 error(err)
	 return nil
      end
   end
end

function read_packet(client)
   while true do
    local header = yieldreceive(client, "*l")
    print(header)

    assert(header:sub(1,16) == "Content-Length: ")

    local content_length = tonumber(header:sub(16,-1))

    local emptyline = yieldreceive(client, "*l")

    assert(emptyline == "")
    print("HHERE")

    local body = yieldreceive(client, content_length)

    print(body)

    local response = commands[message.method](unpack(message.params))
    print("JDJAS")

    local jsonresponse = json.encode({ result=response, id=message.id, jsonrpc="2.0" })
    client:send("Content-Length: "..tostring(#jsonresponse).."\r\n\r\n"..jsonresponse)
    print("OKAKKK")
   end
end

local co

function love.load(args)
  local socket = require("socket").bind("localhost", 8193)
  client = socket:accept()
  client:settimeout(0)
  co = coroutine.create(read_packet)
end

function love.update(dt)
   coroutine.resume(co, client)
end

function love.quit() end
