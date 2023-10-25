local physics = {}

local tiles = loex.tiles 
local cube = { w = 0.5, h = 0.5, d = 0.5, x = 0, y = 0, z = 0 }
local epsilonx, epsilony, epsilonz = 0.0045, 0.002, 0.005
local utils = loex.utils
local floor, min, max = math.floor, math.min, math.max
local expandb, iterb, intersectbb = utils.expandb, utils.iterb, utils.intersectbb

function physics.intersect_point_world(world, x, y, z) 
	local i,j,k = floor(x), floor(y), floor(z) 
	return world:tile(i, j, k) > 0
end

function physics.moveandcollide(world, e, box, dt)
	local bounce = 0

  local dx, dy, dz = e.vx * dt, e.vy * dt, e.vz * dt
  local x, y, z = e.x, e.y, e.z
  local w, h, d = box.w, box.h, box.d

  local onground = false

	-- Z MOVEMENT
	local collidedz = false
  local boxz = expandb(lume.clone(box), 0, 0, dz)
  boxz.x = boxz.x + x
  boxz.y = boxz.y + y
  boxz.z = boxz.z + z
  for i, j, k in iterb(boxz) do
    local t = world:tile(i, j, k)
    if t > 0 then
      cube.x = i + 0.5
      cube.y = j + 0.5
      cube.z = k + 0.5
      if intersectbb(cube, boxz) then
        if dz < 0 then
          dz = min(max(dz, (k + 1 + epsilonz) - (z - h)), 0)
          onground = true
					bounce = (bounce + (tiles.id[t].bounce or 0)) * 0.5
        else
          dz = max(min(dz, (k - epsilonz) - (z + h)), 0)
        end 
				collidedz = true
      end
    end
  end
	if collidedz then
  	e.vz = -e.vz * bounce
	end

	-- X MOVEMENT
  local boxx = expandb(lume.clone(box), dx, 0, dz)
  boxx.x = boxx.x + x
  boxx.y = boxx.y + y
  boxx.z = boxx.z + z
  for i, j, k in iterb(boxx) do
    local t = world:tile(i, j, k)
    if t > 0 then
      cube.x = i + 0.5
      cube.y = j + 0.5
      cube.z = k + 0.5
      if intersectbb(cube, boxx) then
        if dx < 0 then
          dx = min(max(dx, (i + 1 + epsilonx) - (x - w)), 0)
        else
          dx = max(min(dx, (i - epsilonx) - (x + w)), 0)
        end
        e.vx = 0
      end
    end
  end

	-- Y MOVEMENT
  local boxy = expandb(lume.clone(box), dx, dy, dz)
  boxy.x = boxy.x + x
  boxy.y = boxy.y + y
  boxy.z = boxy.z + z
  for i, j, k in iterb(boxy) do
    local t = world:tile(i, j, k)
    if t > 0 then
      cube.x = i + 0.5
      cube.y = j + 0.5
      cube.z = k + 0.5
      if intersectbb(cube, boxy) then
        if dy < 0 then
          dy = min(max(dy, (j + 1 + epsilony) - (y - d)), 0)
        else
          dy = max(min(dy, (j - epsilony) - (y + d)), 0)
        end
        e.vy = 0
      end
    end
  end

  e.x = e.x + dx
  e.y = e.y + dy
  e.z = e.z + dz

  return onground
end
return physics
