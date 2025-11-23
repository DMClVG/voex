-- @module server

local server = {}
server.__index = server

local gen = require("server.gen")
local overworld = require("server.gen.overworld")

function server.init(app, socket)
  local self = {}
  setmetatable(self, server)
  self.socket = socket

  self.world = require("common.world").new()
  self.world.onentityinserted:catch(server.world_onentityinserted, self)
  self.world.onentityremoved:catch(server.world_onentityremoved, self)

  self.genstate = gen.state.new(overworld.layers, 43242)

  self.gravity = 42

  app.onupdate:catch(server.update)
  app.onquit:catch(server.quit)

  require("server.services.connection_manager").init(self)
  require("server.services.player").init(app)
  require("server.services.sync").init(self)
  require("common.services.snowball").init(self)
end

function server:update(g, dt)
end

function server:world_onentityinserted(e) print(e.id .. " added") end

function server:world_onentityremoved(e) print(e.id .. " removed") end

function server:quit()
  print("shutting self down...")
end

return server
