if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

common = require "common"
enet = require "enet"

ServerWorld = require "serverworld"

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
    end
end

function onPeerReceive(peer, user, data)
    print("Received "..data.type)

    if data.type == "break" then
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        world:setBlockFromWorld(x, y, z, loex.Tiles.air.id)
        net:broadcast(("[type=broken;x=%d;y=%d;z=%d;]"):format(x, y, z))

    elseif data.type == "place" then
        local x, y, z, t = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.t)
        world:setBlockFromWorld(x, y, z, t)
        net:broadcast(("[type=placed;x=%d;y=%d;z=%d;t=%d;]"):format(x, y, z, t))

    elseif data.type == "join" then
        local player = loex.entities.Player(0, 0, 50)
        player.username = data.username

        -- TODO: check if username validity
        print(player.username.. " joined the game :>")

        peer:send(("[type=joinSuccess;x=%d;y=%d;z=%d;id=%s;]"):format(player.x, player.y, player.z, player.id))

        for _, chunk in pairs(world.chunks) do
            peer:send(table.concat({ ("[type=chunk;cx=%d;cy=%d;cz=%d;]"):format(chunk.cx, chunk.cy, chunk.cz),
                chunk.data:getString() }), 0, "unsequenced")
        end

        user.playerEntity = player
    else
        assert(false, "Unkown packet type: ".. data.type)

    end
end

function love.update(dt)
    net:service()
    world:update(dt)
end
