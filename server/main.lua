if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

IS_SERVER = true

common = require "../common"
enet = require "enet"

ServerWorld = require "serverworld"
ServerPlayer = require "serverplayer"
ServerChunk = require "serverchunk"
packets = require "./packets"

players = { peers = {} }

banlist = { }
takenUsernames = {}

CHANNEL_ONE = 0
CHANNEL_CHUNKS = 1
CHANNEL_EVENTS = 3
CHANNEL_UPDATES = 4

function love.load(args)
    if #args < 1 then
        print("please supply port number to start server on")
        return love.event.quit(-1)
    end

    port = tonumber(args[1])
    print("starting server on port " .. tostring(port) .. "...")

    net = loex.Network.host(port, 64)
    net.onPeerConnect = onPeerConnect
    net.onPeerDisconnect = onPeerDisconnect
    net.onPeerReceive = onPeerReceive

    world = ServerWorld(net)
    loex.World.singleton = world
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
        lume.remove(players.peers, peer)
        lume.remove(players, user.playerEntity)
        takenUsernames[user.playerEntity.username] = nil
    end
end

function onPeerReceive(peer, user, data)
    -- print("Received "..data.type)

    if user.playerEntity == nil then
        if data.type == "Join" then
            
            local err = verifyJoin(data.username)
            if err then
                peer:send(packets.JoinFailed(err), CHANNEL_ONE)
                peer:disconnect_later()
                return
            end

            local player = ServerPlayer(0, 0, 50)
            player.username = data.username
            player.master = peer
            takenUsernames[player.username] = true
            
            print(player.username.. " joined the game :>")

            peer:send(packets.JoinSucceeded(player.id, player.x, player.y, player.z), CHANNEL_ONE)
            
            world:addEntity(player)
    
            user.playerEntity = player
            table.insert(players.peers, peer)
            table.insert(players, player)
        end
    else
        user.playerEntity["P"..data.type](user.playerEntity, data)
    end
end

function love.update(dt)
    net:service()
    world:update(dt)
end

function love.draw()
    world:draw()
end

function love.quit()
    if net then
        net:disconnect()
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