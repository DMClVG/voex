if arg[#arg] == "vsc_debug" then require("lldebugger").start() end
package.path = package.path .. ";?/init.lua"
require("common")

-- IS_SERVER = true

CHANNEL_ONE = 0
CHANNEL_CHUNKS = 1
CHANNEL_EVENTS = 3
CHANNEL_UPDATES = 4

local game

function love.load(args)
  if #args < 1 then
    print("please supply port number to start server on")
    return love.event.quit(-1)
  end

  local port = tonumber(args[1])
  print("starting server on port " .. tostring(port) .. "...")
  local socket = loex.socket.host(port, 64)

  game = require("game").new()
  game:init(socket)
end

function love.update(dt) game:update(dt) end

function love.quit() game:shutdown() end
