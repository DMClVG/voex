if arg[#arg] == "vsc_debug" then require("lldebugger").start() end

lg = love.graphics
lg.setDefaultFilter "nearest"
io.stdout:setvbuf "no"

enet = require "enet"

g3d = require "g3d"
lume = require "lib/lume"
Object = require "lib/classic"
scene = require "scene"

common = require "../common"

require "tiles"
require "scenes/gameworld"
require "physics"
require "box"

function love.load(args)
    scene(GameScene())

    client = enet.host_create()
    client:compress_with_range_coder()
    conn = client:connect("localhost:8192")
end

function love.update(dt)
    local scene = scene()

    local event = client:service()
    if event then
        print(event.type)
        if event.type == "receive" then
            local packet = love.data.newByteData(event.data)
            local chunk = common.chunk.fromPacket(packet)
            scene:addChunk(chunk)
        end
    end

    if scene.update then
        scene:update(dt)
    end
end

function love.draw()
    local scene = scene()
    if scene.draw then
        scene:draw()
    end
end

function love.mousemoved(x, y, dx, dy)
    local scene = scene()
    if scene.mousemoved then
        scene:mousemoved(x, y, dx, dy)
    end
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
