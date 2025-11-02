local server = {}
local gen = require("server.gen")
local overworld = require("server.gen.overworld")

local floor = math.floor
local tiles = loex.tiles
local size = loex.chunk.size

function server.init(g, socket)
  g.socket = socket

  g.world = loex.world.new()
  g.world.onentityinserted:catch(server.world_onentityinserted, g)
  g.world.onentityremoved:catch(server.world_onentityremoved, g)

  g.genstate = gen.state.new(overworld.layers, 43242)

  g.gravity = 42

  g.onupdate:catch(sever.update)
  g.onquit:catch(sever.quit)

  require("server.services.connection_manager").init(g)
  require("server.services.player").init(g)
  require("server.services.sync").init(g)
  require("common.services.snowball").init(g)
end

function server.update(g, dt)
end

function server.world_onentityinserted(e) print(e.id .. " added") end

function server.world_onentityremoved(e) print(e.id .. " removed") end

function server.quit()
  print("shutting server down...")
end

return server
