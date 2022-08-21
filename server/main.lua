if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

IS_SERVER = true

common = require "common"
enet = require "enet"

ServerWorld = require "serverworld"
packets = require "./packets"

players = {}

function love.load(args)
    if #args < 1 then
        print("please supply port number to start server on")
        return love.event.quit(-1)
    end

    port = tonumber(args[1])
    print("starting server on port " .. tostring(port) .. "...")

    net = loex.Network.host(port)
    net.onPeerConnect = onPeerConnect
    net.onPeerDisconnect = onPeerDisconnect
    net.onPeerReceive = onPeerReceive

    world = ServerWorld(net)

    for i = -3, 3 do
        for j = -3, 3 do
            for k = -3, 3 do
                local chunk = common.Chunk(i, j, k)
                chunk:generate()
                world:addChunk(chunk)
            end
        end
    end
end

function onPeerConnect(peer, user)
    print("Connected!")
end

function onPeerDisconnect(peer, user)
    if not user.playerEntity then
        print("Peer disconnected!")
    else
        print(user.playerEntity.username.. " left the game :<")
        user.playerEntity.dead = true
        lume.remove(players, peer)
    end
end

function onPeerReceive(peer, user, data)
    print("Received "..data.type)

    if data.type == "move" then
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        user.playerEntity.x = x
        user.playerEntity.y = y
        user.playerEntity.z = z
    elseif data.type == "break" then
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        world:setBlockFromWorld(x, y, z, loex.Tiles.air.id)
        net:broadcast(packets.Broken(x, y, z))

    elseif data.type == "place" then
        local x, y, z, t = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.t)
        world:setBlockFromWorld(x, y, z, t)
        net:broadcast(packets.Placed(x, y, z, t))

    elseif data.type == "join" then
        local player = loex.entities.Player(0, 0, 50)
        player.username = data.username
        
        -- TODO: check if username valid
        print(player.username.. " joined the game :>")
        
        peer:send(packets.JoinSuccess(player.id, player.x, player.y, player.z))
        
        world:addEntity(player)

        for _, chunk in pairs(world.chunks) do
            peer:send(packets.Chunk(chunk.data, chunk.cx, chunk.cy, chunk.cz), 0, "unsequenced")
        end

        for _, entity in pairs(world.entities) do
            peer:send(packets.EntityAdd(entity.id, entity.type, entity.x, entity.y, entity.z))
        end

        user.playerEntity = player
        table.insert(players, peer)
    else
        assert(false, "Unkown packet type: ".. data.type)

    end
end

function love.update(dt)
    net:service()
    world:update(dt)
    synchronizePositions()
end

function synchronizePositions()
    local entities = world.entities
    for _, e in pairs(entities) do
        if e.syncX == nil or e.x ~= e.syncX or e.y ~= e.syncY or e.z ~= e.syncZ then
            e.syncX = e.x
            e.syncY = e.y
            e.syncZ = e.z
            net:broadcast(packets.EntityMoved(e.id, e.syncX, e.syncY, e.syncZ))
        end
    end
end