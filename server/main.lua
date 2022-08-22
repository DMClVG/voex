if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

IS_SERVER = true

common = require "common"
enet = require "enet"

ServerWorld = require "serverworld"
ServerPlayer = require "serverplayer"
packets = require "./packets"

players = {}

banlist = { }
takenUsernames = {}

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
        takenUsernames[user.playerEntity.username] = nil
    end
end

function onPeerReceive(peer, user, data)
    print("Received "..data.type)

    if user.playerEntity == nil then
        if data.type == "Join" then
            
            local err = verifyJoin(data.username)
            if err then
                peer:send(packets.JoinFailed(err))
                peer:disconnect_later()
                return
            end

            local player = ServerPlayer(0, 0, 50)
            player.username = data.username
            player.master = peer
            takenUsernames[player.username] = true
            
            print(player.username.. " joined the game :>")
            
            peer:send(packets.JoinSucceeded(player.id, player.x, player.y, player.z))
            
            world:addEntity(player)
    
            for _, chunk in pairs(world.chunks) do
                peer:send(packets.Chunk(chunk.data, chunk.cx, chunk.cy, chunk.cz), 0, "unsequenced")
            end
    
            for _, entity in pairs(world.entities) do
                peer:send(packets.EntityAdded(entity.id, entity.type, entity.x, entity.y, entity.z, entity:remoteExtras()))
            end
    
            user.playerEntity = player
            table.insert(players, peer)
        end
    else
        user.playerEntity["P"..data.type](user.playerEntity, data)
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

            if e.master then
                local dest = lume.clone(players)
                lume.remove(dest, e.master)
                net:broadcast(packets.EntityMoved(e.id, e.syncX, e.syncY, e.syncZ), 0, "reliable", dest)
            else
                net:broadcast(packets.EntityMoved(e.id, e.syncX, e.syncY, e.syncZ))
            end
        end
    end
end

function verifyJoin(username)
    local validUsername = "^[a-zA-Z_]+$"

    if banlist[username] then
        return "You're banned from this server. Cry about it :-("
    end

    if #username < 3 then
        return "Username too short"
    end

    if #username > 15 then
        return "Username too long"
    end

    if not username:match(validUsername) then
        return ("Invalid username (It has to be good)")
    end

    if takenUsernames[username] then
        return "Username already taken. Try again :)"
    end
end