local physics = loex.physics
local lg = love.graphics

local snowball = {}

function snowball.init(g)
	g.onupdate:catch(snowball.onupdate) -- client side prediction also
	if g.master then 
		g.socket.onreceive:catch(snowball.onreceive_client, g) 
		g.ondraw:catch(snowball.ondraw)
	end
end

function snowball.onreceive_client(g, peer, packet)
	if packet.type == "entityadd" and packet.entity_type == "snowball" then
		print("SNOWBALL ADDED")
		snowball.entity(g, packet.id, packet.x, packet.y, packet.z, packet.vx, packet.vy, packet.vz)
	end
end

function snowball.ondraw(g)
	local snowball_model = g.gamescreen.snowball_model
	local camera = g3d.camera.position

  lg.setMeshCullMode("none")
  lg.setColor(1, 1, 1)

  for _, e in pairs(g.world:query("snowball")) do
    if e ~= g.gamescreen.player then
			local dx,dy,dz = e.x-camera[1], e.y-camera[2], e.z-camera[3]
			snowball_model:setTranslation(e.x, e.y, e.z)
			snowball_model:setRotation(0, -math.atan2(dz, math.sqrt(dx*dx+dy*dy)), math.atan2(e.y - camera[2], e.x - camera[1]))
			snowball_model:setScale(0.4, 0.4, 0.4)
			snowball_model:draw()
    end
  end
end

function snowball.onupdate(g, dt)
	for _, e in pairs(g.world:query("snowball")) do
		e.vz = e.vz - g.gravity * dt
		e.x = e.x + e.vx * dt
		e.y = e.y + e.vy * dt
		e.z = e.z + e.vz * dt

		if g.master == nil and physics.intersect_point_world(g.world, e.x, e.y, e.z) then 
			g.world:tag(e, "destroyed")
		end
	end
end

function snowball.entity(g, id, x, y, z, vx, vy, vz)
	local e = {id=id}
	e.x, e.y, e.z = x, y, z
	e.vx, e.vy, e.vz = vx, vy, vz 

	g.world:insert(e)
	g.world:tag(e, "snowball")
	return e
end

return snowball
