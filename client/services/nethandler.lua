local nethandler = {}

function nethandler.init(g)
	g.socket.onreceive:catch(nethandler.onreceive, g)
end

function nethandler.onreceive(g, peer, d)
	if d.type == "joinsuccess" then return end -- FIXME

	print("received " .. d.type)
	nethandler[d.type](g, d)
end

function nethandler.broken(g, d)
  local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
  local hash = ("%d/%d/%d"):format(x, y, z)
  if not g.gamescreen.breakqueue[hash] then g.world:tile(x, y, z, loex.tiles.air.id, true) end
  g.gamescreen.breakqueue[hash] = nil
end

function nethandler.placed(g, d)
	local gamescreen = require("screens.gamescreen")
  local x, y, z, t = tonumber(d.x), tonumber(d.y), tonumber(d.z), tonumber(d.t)
  local hash = ("%d/%d/%d"):format(x, y, z)
  if not g.gamescreen.placequeue[hash] or g.gamescreen.placequeue[hash].t ~= t then 
		g.world:tile(x, y, z, t) 
		gamescreen.play_place_sound(g, x, y, z)
	end
  g.gamescreen.placequeue[hash] = nil
end

function nethandler.entitymove(g, d)
  assert(false)
  local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
  local entity = g.world:entity(d.id)
  assert(entity)
  entity.x = x
  entity.y = y
  entity.z = z
end

function nethandler.entityadd(g, d)
end

function nethandler.entityremove(g, d) 
	g.world:remove(g.world:entity(d.id)) 
end

function nethandler.entityremoteset(g, d)
  local entity = g.world:entity(d.id)
	for k, v in pairs(d.properties) do
  	if not (entity.id == g.gamescreen.player.id and k:match("[xyz]")) then -- TODO: position correction
  		entity[k] = v
		end
	end
end

function nethandler.chunkadd(g, d)
  local expectedsize = loex.chunk.size ^ 3
  local cx, cy, cz = tonumber(d.cx), tonumber(d.cy), tonumber(d.cz)
  local c = loex.chunk.new(cx, cy, cz)
  if d.bin then
    local data = love.data.decompress("data", "zlib", d.bin)
    assert(
      data:getSize() == expectedsize,
      ("Chunk data of wrong size! Expected %d bytes, got %d bytes"):format(expectedsize, data:getSize())
    )
    c:init(data)
  end
  g.world:insertchunk(c)
end

function nethandler.chunkremove(g, d)
  local cx, cy, cz = tonumber(d.cx), tonumber(d.cy), tonumber(d.cz)
  g.world:removechunk(loex.hash.spatial(cx, cy, cz)):destroy()
end

return nethandler
