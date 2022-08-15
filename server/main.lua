package.path = package.path..";../lib/"

local enet = require "enet"
local common = require "../common"

function love.load(args)
    if #args < 1 then
        print("please supply port number to start server on") 
        return love.event.quit(-1)
    end
    port = tonumber(args[1])
    print("starting server on port "..tostring(port).."...")
    
    host = enet.host_create("localhost:8192")
    host:compress_with_range_coder()
end

function love.update(dt)
    event = host:service()
    if event then
        print(event.type)
        if event.type == "connect" then
            event.peer:send("Hello :)")
        end
    end
end
