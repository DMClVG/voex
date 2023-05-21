local player = {}
local floor = math.floor
local size = loex.chunk.size
local remote = require("remote")

function player.entity(x, y, z, id, username, master)
  local new = remote(x, y, z, id)
  new:tag("player")
  new.username = username
  new.master = master
  new.view = loex.world.new()
  return new
end

function player.inview(e, x, y, z)
  local range = 2 -- chunks
  x, y, z = floor(x / size), floor(y / size), floor(z / size)
  local px, py, pz = floor(e.x / size), floor(e.y / size), floor(e.z / size)
  return loex.utils.distance3d(px, py, 0, x, y, 0, true) <= range * range
end

return player
