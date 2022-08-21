if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

lg = love.graphics
---@diagnostic disable-next-line: missing-parameter
lg.setDefaultFilter "nearest"

io.stdout:setvbuf "no"

g3d = require "lib/g3d"
enet = require "enet"

common = require "common"


require "scenes.gameworld"
require "physics"
packets = require "packets"

local world
local focused = false

function love.load(args)
    if #args < 3 then
        print("Usage: client [address] [port] [username]")
        love.event.quit(-1)
        return
    end

    local address = args[1]..":"..args[2]
    username = args[3]

    net = loex.Network.connect(address)
    net.onPeerConnect = onPeerConnect
    net.onPeerDisconnect = onPeerDisconnect
    net.onPeerReceive = onPeerReceive

end

function onPeerConnect(peer, _)
    print("Connected!")

    net.master = peer

    net.master:send(packets.Join(username))
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
    print("Received ".. data.type)

    if data.type == "joinSuccess" then
        local spawnX, spawnY, spawnZ = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        local playerID = data.id
        local playerEntity = loex.entities.Player(spawnX, spawnY, spawnZ, playerID)
        
        print(("Joined under username ".. username .. " (ID: " .. playerID .. ") at spawn point %d, %d, %d"):format(spawnX, spawnY, spawnZ))

        loex.World.singleton = GameWorld(playerEntity)
        world = loex.World.singleton
    end

    if data.type == "chunk" then
        world:addChunk(loex.Chunk.fromPacket(data))
    elseif data.type == "broken" then
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        local hash = ("%d/%d/%d"):format(x, y, z)
        if not world.breakQueue[hash] then
            world:setBlockAndRemesh(x, y, z, loex.Tiles.air.id, true)
        end
        world.breakQueue[hash] = nil

    elseif data.type == "placed" then
        local x, y, z, t = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.t)
        local hash = ("%d/%d/%d"):format(x, y, z)
        if not world.placeQueue[hash] then
            world:setBlockAndRemesh(x, y, z, t)
        end
        world.placeQueue[hash] = nil

    elseif data.type == "entityMoved" then
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        local entity = world:getEntity(data.id)
        assert(entity)
        entity.x = x
        entity.y = y
        entity.z = z

        

    elseif data.type == "entityAdd" and data.id ~= world.player.id then
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        world:addEntity(loex.entities[data.eType](x, y, z, data.id))
    elseif data.type == "entityRemove" then
        local entity = world:getEntity(data.id)
        entity.dead = true
    end 
end

function love.update(dt)
    net:service()

    if world then
        world:update(dt)
    end
end

function love.draw()
    if world then
        world:draw()
    end
end

function love.mousepressed()
    if not focus then
        focus = true
    end
end

function love.focus(hasFocus)
    focus = hasFocus
end

function love.mousemoved(x, y, dx, dy)
    if world and focus then
        world:mousemoved(x, y, dx, dy)
    end
end

function love.keypressed(k)
    if k == "escape" then
        love.mouse.setRelativeMode(false)
        focus = false
    end
end

function love.resize(w, h)
    g3d.camera.aspectRatio = w / h
    g3d.camera.updateProjectionMatrix()
end

function love.quit()
    if net then
        print("Disconnecting ....")
        net:disconnect()
    end
end