local overworld = require("gen.overworld")
local packets = require("packets")
local snowball = require("common.services.snowball")

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
 	-- TODO: need abstraction for this
	if g.world:tagged(e, "player") then
		p.master:send(socket.encode {
			type="entityadd",
			id=e.id,
			x=e.x,y=e.y,z=e.z,
			username=e.username,
			entity_type="player"
		})
	elseif g.world:tagged(e, "snowball") then
		p.master:send(socket.encode {
			type="entityadd",
			id=e.id,
			x=e.x,y=e.y,z=e.z,
			vx=e.vx,vy=e.vy,vz=e.vz,
			entity_type="snowball",
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
		["snowball_throw"] = function(p, d)
			-- throw snowballs
			--if os.time() - p.last_throw > 0.05 then
				print("thrown snowball")
				p.last_throw = os.time()

				local e = snowball.entity(g, lume.uuid(), d.x, d.y, d.z, d.vx, d.vy, d.vz)
				e.remote = {}
			--end
		end
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

	for _, p in pairs(g.world:query("player")) do

		-- generate world
		for i = -gendistance + floor(p.x / size), gendistance + floor(p.x / size) do
			for j = -gendistance + floor(p.y / size), gendistance + floor(p.y / size) do
				for k = 0, overworld.columnheight - 1 do
					if not world:chunk(loex.hash.spatial(i, j, k)) then
						local c = overworld:generate(genstate, i, j, k)
						world:insertchunk(c)
					end
				end
			end
		end
		

		-- compute chunks in player view
		for _, c in pairs(world.chunks) do
			if not player.inview(p, c.x * size, c.y * size, c.z * size) then
				if p.view.chunks[c.hash] then p.view:removechunk(c.hash) end
			else
				if not p.view.chunks[c.hash] then p.view:insertchunk(c) end
			end
		end

		-- compute entities in player view
		for _, e in pairs(world.entities) do
			if e ~= p then 
				if not player.inview(p, e.x, e.y, e.z) then
					if p.view:entity(e.id) then p.view:remove(e) end
				else
					if not p.view:entity(e.id) then 
						p.view:insert(e) 
					else
						-- TODO: this is bad, really bad
						if not (e.remote.x == e.x and e.remote.y == e.y and e.remote.z == e.z) then
							p.master:send(socket.encode {
								type="entityremoteset",
								id=e.id,
								properties={x=e.x,y=e.y,z=e.z},
							})
						end
					end
				end
			end
		end
	end
	for _, e in pairs(world.entities) do
		if e.remote then e.remote.x, e.remote.y, e.remote.z = e.x, e.y, e.z end
	end
end

return player
