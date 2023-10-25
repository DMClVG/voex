local overworld = require("gen.overworld")
local packets = require("packets")
local socket = loex.socket

local size = loex.chunk.size
local entity = loex.entity
local floor = math.floor

local player = {}

function player.init(g)
	assert(g.master == nil)
	g.onupdate:catch(player.update)
	g.socket.onreceive:catch(player.socket_onreceive, g)
  g.world.ontilemodified:catch(player.world_ontilemodified, g)
  g.world.onentityremoved:catch(player.world_onentityremoved, g)
end

function player.view_onchunkinserted(g, p, c) 
	p.master:send(packets.chunkadd(c:dump(), c.x, c.y, c.z)) 
end

function player.view_onchunkremoved(g, p, c) 
	p.master:send(packets.chunkremove(c.x, c.y, c.z)) 
end

function player.view_onentityinserted(g, p, e) 
	if g.world:tagged(p, "player") then
		p.master:send(socket.encode { -- TODO
			type="entityadd",
			id=e.id,
			x=p.x,y=p.y,z=p.z,
			username=p.username,
			entity_type="player"
		})
	end
end

function player.view_onentityremoved(g, p, e)
	p.master:send(packets.entityremove(e.id)) 
end

function player.entity(g, w, id, x, y, z, username, master)
	local e = {id=id}

	e.last_throw = os.time()
	e.x, e.y, e.z = x, y, z
	e.vx, e.vy, e.vz = 0, 0, 0
	e.box = {
		x = 0,
		y = 0,
		z = 0,
		w = 0.3,
		d = 0.3,
		h = 0.9,
	}
  e.username = username
  e.master = master

  e.view = loex.world.new()
  e.view.onchunkinserted:catch(player.view_onchunkinserted, g, e)
  e.view.onchunkremoved:catch(player.view_onchunkremoved, g, e)
  e.view.onentityinserted:catch(player.view_onentityinserted, g, e)
  e.view.onentityremoved:catch(player.view_onentityremoved, g, e)

	e.remote = {}

	w:insert(e)
	w:tag(e, "box")
  w:tag(e, "player")

  return e
end

function player.inview(e, x, y, z)
  local range = 12 -- chunks
  x, y, z = floor(x / size), floor(y / size), floor(z / size)
  local px, py, pz = floor(e.x / size), floor(e.y / size), floor(e.z / size)
  return loex.utils.distance3d(px, py, 0, x, y, 0, true) <= range * range
end

function player.socket_onreceive(g, peer, d)
	if d.type == "join" then return end -- FIXME
	local p = g.socket:peerdata(peer).playerentity
	if not p then return end

	local world = g.world

  local handles = {
    ["move"] = function(p, d)
      local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
      p.x = x
      p.y = y
      p.z = z
    end,
    ["place"] = function(p, d)
      local x, y, z, t = tonumber(d.x), tonumber(d.y), tonumber(d.z), tonumber(d.t)
      world:tile(x, y, z, t)
    end,
    ["breaktile"] = function(p, d)
      local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
      world:tile(x, y, z, loex.tiles.air.id)
    end,
  }
  handles[d.type](p, d)
end

function player.world_onentityremoved(g, e)
	local world = g.world
  for _, p in pairs(world:query("player")) do
    if p.view:entity(e) then p.view:remove(e) end
  end
end

function player.world_ontilemodified(g, x, y, z, t)
	local world = g.world
  local packet
  if t == loex.tiles.air.id then
    packet = packets.broken(x, y, z)
  else
    packet = packets.placed(x, y, z, t)
  end

  for _, p in pairs(world:query("player")) do
    if p.view:tile(x, y, z) >= 0 then 
			p.master:send(packet) 
		end
  end
end

function player.update(g, dt)
	local world = g.world
	local genstate = g.genstate
  local gendistance = 5

	for _, e in pairs(g.world:query("player")) do

		-- generate world
		for i = -gendistance + floor(e.x / size), gendistance + floor(e.x / size) do
			for j = -gendistance + floor(e.y / size), gendistance + floor(e.y / size) do
				for k = 0, overworld.columnheight - 1 do
					if not world:chunk(loex.hash.spatial(i, j, k)) then
						local c = overworld:generate(genstate, i, j, k)
						world:insertchunk(c)
					end
				end
			end
		end
		
		-- throw snowballs
		--if os.time() - e.last_throw > 2 then
		--	local new_snowball = snowball.entity(g:next_id(), e.x, e.y, e.z)
		--	world:insert(new_snowball)
		--	e.last_throw = os.time()
		--end

		-- compute chunks in player view
		for _, c in pairs(world.chunks) do
			if not player.inview(e, c.x * size, c.y * size, c.z * size) then
				if e.view.chunks[c.hash] then e.view:removechunk(c.hash) end
			else
				if not e.view.chunks[c.hash] then e.view:insertchunk(c) end
			end
		end

		-- compute entities in player view
		for _, entity in pairs(world.entities) do
			if entity ~= e then 
				if not player.inview(e, entity.x, entity.y, entity.z) then
					if e.view:entity(entity.id) then e.view:remove(entity) end
				else
					if not e.view:entity(entity.id) then 
						e.view:insert(entity) 
					else
						if not (entity.remote.x == entity.x and entity.remote.y == entity.y and entity.remote.z == entity.z) then
							e.master:send(socket.encode {
								type="entityremoteset",
								id=entity.id,
								properties={x=entity.x,y=entity.y,z=entity.z},
							})
							entity.remote.x, entity.remote.y, entity.remote.z = entity.x, entity.y, entity.z
						end
					end
				end
			end
		end
	end
end

return player
