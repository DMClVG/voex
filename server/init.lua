local server = {}
local gen = require("server.gen")
local overworld = require("server.gen.overworld")

local floor = math.floor
local tiles = loex.tiles
local size = loex.chunk.size

function server.init(game, socket)
  local server = {}
  server.socket = socket

  server.world = loex.world.new()
  server.world.onentityinserted:catch(server.world_onentityinserted, g)
  server.world.onentityremoved:catch(server.world_onentityremoved, g)

  server.genstate = gen.state.new(overworld.layers, 43242)

  server.gravity = 42

  game.onupdate:catch(sever.update)
  game.onquit:catch(sever.quit)

  require("server.services.connection_manager").init(g)
  require("server.services.player").init(g)
  require("server.services.sync").init(g)
  require("common.services.snowball").init(g)

  game.server = server
end

function server.update(g, dt)
end

function server.world_onentityinserted(e) print(e.id .. " added") end

function server.world_onentityremoved(e) print(e.id .. " removed") end

function server.quit()
  print("shutting server down...")
end

return server
