local gen = require("gen")
local overworld = require("gen.overworld")

local floor = math.floor
local tiles = loex.tiles
local size = loex.chunk.size

local game = {}

function game.new()
	local new = {}
	setmetatable(new, { __index = game })
	return new
end

function game:init(socket)
	self.socket = socket

  self.world = loex.world.new()
  self.world.onentityinserted:catch(self.world_onentityinserted, self)
  self.world.onentityremoved:catch(self.world_onentityremoved, self)

  self.genstate = gen.state.new(overworld.layers, 43242)

	self.gravity = 42

	self.onupdate = loex.signal.new()
	self.onshutdown = loex.signal.new()

	require("services.connection_manager").init(self)
	require("services.player").init(self)
	require("services.sync").init(self)
	require("common.services.snowball").init(self)
end

function game:update(dt)
  self.socket:service()

	self.onupdate:emit(self, dt)
end

function game:world_onentityinserted(e) 
	print(e.id .. " added") 
end

function game:world_onentityremoved(e)
  print(e.id .. " removed")
end

function game:shutdown()
	print("shutting down...")
	self.socket:disconnect()
	self.onshutdown:emit(self)
end

return game
