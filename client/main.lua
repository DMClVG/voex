if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

lg = love.graphics
---@diagnostic disable-next-line: missing-parameter
lg.setDefaultFilter "nearest"

io.stdout:setvbuf "no"

common = require "common"
enet = require "enet"

g3d = require "lib/g3d"

require "scenes.gameworld"
require "physics"
require "box"
require "packets"

local world

function love.load(args)
    loex.World.singleton = GameWorld()

    net = loex.Network.connect("localhost:8192")
    net.onPeerConnect = onPeerConnect
    net.onPeerDisconnect = onPeerDisconnect
    net.onPeerReceive = onPeerReceive

    world = loex.World.singleton
end

function onPeerConnect(peer, _)
    print("Connected!")
end

function onPeerDisconnect(peer, _)
    print("Disconnected!")
end

function onPeerReceive(peer, _, data)
    -- for k, v in pairs(data) do
    --     if k ~= "bin" then
    --         print(k, v)
    --     else
    --         print(k, v:getSize())
    --     end
    -- end

    if data.type == "chunk" then
        world:addChunk(loex.Chunk.fromPacket(data))
    elseif data.type == "broken" then
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        local chunk = world:getChunkFromWorld(x, y, z)
        assert(chunk)

        local size = chunk.size
        local lx, ly, lz = x%size, y%size, z%size
        local cx, cy, cz = chunk.cx, chunk.cy, chunk.cz
        chunk:setBlock(lx, ly, lz, loex.Tiles.air.id)

        world:requestRemesh(chunk, true)
        if lx >= size-1 then world:requestRemesh(world:getChunk(cx+1,cy,cz), true) end
        if lx <= 0      then world:requestRemesh(world:getChunk(cx-1,cy,cz), true) end
        if ly >= size-1 then world:requestRemesh(world:getChunk(cx,cy+1,cz), true) end
        if ly <= 0      then world:requestRemesh(world:getChunk(cx,cy-1,cz), true) end
        if lz >= size-1 then world:requestRemesh(world:getChunk(cx,cy,cz+1), true) end
        if lz <= 0      then world:requestRemesh(world:getChunk(cx,cy,cz-1), true) end
    elseif data.type == "placed" then
        local x, y, z, t = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.t)
        local chunk = world:getChunkFromWorld(x, y, z)
        assert(chunk)

        local size = chunk.size
        local lx, ly, lz = x%size, y%size, z%size
        local cx, cy, cz = chunk.cx, chunk.cy, chunk.cz
        chunk:setBlock(lx, ly, lz,t)

        if lx >= size-1 then world:requestRemesh(world:getChunk(cx+1,cy,cz), true) end
        if lx <= 0      then world:requestRemesh(world:getChunk(cx-1,cy,cz), true) end
        if ly >= size-1 then world:requestRemesh(world:getChunk(cx,cy+1,cz), true) end
        if ly <= 0      then world:requestRemesh(world:getChunk(cx,cy-1,cz), true) end
        if lz >= size-1 then world:requestRemesh(world:getChunk(cx,cy,cz+1), true) end
        if lz <= 0      then world:requestRemesh(world:getChunk(cx,cy,cz-1), true) end
        world:requestRemesh(chunk, true)
    end

    print("Received!")
end

function love.update(dt)
    net:service()

    world:update(dt)
end

function love.draw()
    world:draw()
end

function love.mousemoved(x, y, dx, dy)
    world:mousemoved(x, y, dx, dy)
end

function love.keypressed(k)
    if k == "escape" then
        love.event.push "quit"
    end
end

function love.resize(w, h)
    g3d.camera.aspectRatio = w / h
    g3d.camera.updateProjectionMatrix()
end

function love.quit()
    net:disconnect()
end