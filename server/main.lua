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

    chunks = {}

    for i = -2,2 do
        for j = -2,2 do
            for k = -2,2 do
                local chunk = common.chunk.Chunk(i, j, k)
                chunk:generate()
                table.insert(chunks, chunk)
            end
        end
    end
end

function love.update(dt)
    event = host:service()
    if event then
        print(event.type)
        if event.type == "connect" then
            for _, chunk in ipairs(chunks) do
                event.peer:send("["..chunk.hash.."]"..chunk.data:getString())
            end
        end
    end
end
