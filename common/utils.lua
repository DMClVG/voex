local utils = {}
local floor = math.floor
local abs = math.abs
local sqrt = math.sqrt

function utils.iterb(box)
  local x, y, z = floor(box.x - box.w), floor(box.y - box.d), floor(box.z - box.h)
  local a, b, c = floor(box.x + box.w), floor(box.y + box.d), floor(box.z + box.h)
  assert(x <= a and y <= b and z <= c, "negative box dimensions!")

  local i, j, k = x - 1, y, z
  return function()
    i = i + 1
    if i > a then
      i = x
      j = j + 1
      if j > b then
        j = y
        k = k + 1
        if k > c then return nil end
      end
    end
    return i, j, k
  end
end

function utils.intersectbb(a, b)
  return a.x + a.w > b.x - b.w
    and a.x - a.w < b.x + b.w
    and a.y + a.d > b.y - b.d
    and a.y - a.d < b.y + b.d
    and a.z + a.h > b.z - b.h
    and a.z - a.h < b.z + b.h
end

function utils.expandb(box, dx, dy, dz)
  local hx, hy, hz = dx / 2, dy / 2, dz / 2
  box.x = box.x + hx
  box.y = box.y + hy
  box.z = box.z + hz

  box.w = box.w + abs(hx)
  box.d = box.d + abs(hy)
  box.h = box.h + abs(hz)
  return box
end

function utils.distance3d(ax, ay, az, bx, by, bz, squared)
  local dx, dy, dz = ax - bx, ay - by, az - bz
  local square = dx * dx + dy * dy + dz * dz
  if not squared then
    return sqrt(square)
  else
    return square
  end
end

return utils
