local player = {}
local floor = math.floor
local size = loex.chunk.size
local remote = require("remote")

function player.view_onchunkinserted(e, c) e.master:send(packets.chunkadd(c:dump(), c.x, c.y, c.z)) end

function player.view_onchunkremoved(e, c) e.master:send(packets.chunkremove(c.x, c.y, c.z)) end

function player.view_onentityinserted(p, e) p.master:send(packets.entityadd(e.id, e.x, e.y, e.z)) end

function player.view_onentityremoved(p, e) p.master:send(packets.entityremove(e.id)) end

function player.entity(x, y, z, id, username, master)
  local new = remote(x, y, z, id)
  new:tag("player")
  new.username = username
  new.master = master
  new.view = loex.world.new()
  new.view.onchunkinserted:catch(player.view_onchunkinserted, new)
  new.view.onchunkremoved:catch(player.view_onchunkremoved, new)
  new.view.onentityinserted:catch(player.view_onentityinserted, new)
  new.view.onentityremoved:catch(player.view_onentityremoved, new)
  return new
end

function player.inview(e, x, y, z)
  local range = 12 -- chunks
  x, y, z = floor(x / size), floor(y / size), floor(z / size)
  local px, py, pz = floor(e.x / size), floor(e.y / size), floor(e.z / size)
  return loex.utils.distance3d(px, py, 0, x, y, 0, true) <= range * range
end

return player
