if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
package.path = package.path .. ";?/init.lua"

lg = love.graphics
---@diagnostic disable-next-line: missing-parameter
lg.setDefaultFilter("nearest")

io.stdout:setvbuf("no")

CHANNEL_ONE = 0
CHANNEL_EVENTS = 1
CHANNEL_UPDATES = 2

g3d = require("lib/g3d")
scene = require("lib/scene")
enet = require("enet")

require("common")

require("scenes/gameworld")
require("physics")

packets = require("packets")
local nethandler = require("nethandler")

local focused = false

local socket
_G.master = nil

function love.load(args)
  if #args < 3 then
    print("Usage: client [address] [port] [username]")
    love.event.quit(-1)
    return
  end

  local address = args[1] .. ":" .. args[2]
  username = args[3]

  socket = loex.socket.connect(address)
  socket.onconnect:catch(onconnect)
  socket.ondisconnect:catch(ondisconnect)
  socket.onreceive:catch(onreceive)

  font = love.graphics.newFont(50)
  love.graphics.setFont(font)

  scene(require("scenes/joinscreen"))
end

function onconnect(peer)
  print("Connected!")

  master = peer
  master:send(packets.join(username), CHANNEL_ONE)
end

function ondisconnect(_) scene(require("scenes/errorscreen"), "disconnected :(") end

function onreceive(_, packet)
  print("Received " .. packet.type)

  local handle = nethandler[packet.type]
  if not handle then
    error("Unknown packet type " .. packet.type)
  else
    handle(scene(), packet)
  end
end

function love.update(dt)
  socket:service()

  local scene = scene()
  if scene and scene.update then scene:update(dt) end
end

function love.draw()
  local scene = scene()
  if scene and scene.draw then scene:draw() end
end

function love.mousepressed()
  if not focused then focused = true end
end

function love.focus(hasFocus) focused = hasFocus end

function love.mousemoved(x, y, dx, dy)
  local scene = scene()
  if scene and focused and scene.mousemoved then scene:mousemoved(x, y, dx, dy) end
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
  if socket then
    print("Disconnecting ....")
    socket:disconnect()
  end
end
