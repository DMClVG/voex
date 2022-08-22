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

local focused = false

local netHandler = require "nethandler"

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

    local handle = netHandler[data.type]
    if not handle then
        error("Unkown packet type "..data.type)
    else
        handle(data, net, loex.World.singleton)
    end
end

function love.update(dt)
    net:service()
    local world = loex.World.singleton

    if world then
        world:update(dt)
    end
end

function love.draw()
    local world = loex.World.singleton

    if world then
        world:draw()
    end
end

function love.mousepressed()
    if not focused then
        focused = true
    end
end

function love.focus(hasFocus)
    focused = hasFocus
end

function love.mousemoved(x, y, dx, dy)
    local world = loex.World.singleton

    if world and focused then
        world:mousemoved(x, y, dx, dy)
    end
end

function love.keypressed(k)
    if k == "escape" then
        love.mouse.setRelativeMode(false)
        focused = false
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