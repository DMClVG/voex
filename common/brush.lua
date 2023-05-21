local brush = {}
local insert = table.insert
local size = loex.chunk.size
local floor = math.floor
local spatialhash = loex.hash.spatial

function brush.bounded(world, x, y, z, w, h, d)
  local new = {}
  setmetatable(new, { __index = brush })
  new.world = world
  new.chunks = {}

  new.minx = x
  new.miny = y
  new.minz = z
  new.maxx = x + w - 1
  new.maxy = y + h - 1
  new.maxz = z + d - 1
  new.ox = x
  new.oy = y
  new.oz = z
  new.w = w
  new.h = h
  new.d = d
  new.dx = x % size
  new.dy = y % size
  new.dz = z % size
  new.cx = floor(x / size)
  new.cy = floor(y / size)
  new.cz = floor(z / size)
  new.cw = floor((x + w - 1) / size) - new.cx + 1
  new.ch = floor((y + h - 1) / size) - new.cy + 1
  new.cd = floor((z + d - 1) / size) - new.cz + 1

  for i = new.cx, new.cx + new.cw - 1 do
    for j = new.cy, new.cy + new.ch - 1 do
      for k = new.cz, new.cz + new.cd - 1 do
        local c = world:chunk(spatialhash(i, j, k))
        assert(c)
        insert(new.chunks, c)
      end
    end
  end
  -- new:reset()
  return new
end

function brush:reset()
  self.x = self.ox
  self.y = self.oy
  self.z = self.oz
  self.px = self.x % size
  self.py = self.y % size
  self.pz = self.z % size
  self.cx = floor(self.x / size)
  self.cy = floor(self.y / size)
  self.cz = floor(self.z / size)
  self.i = 1
  self:refreshc()
end

function brush:refreshc()
  local c = self.c
  c = self.chunks[self.i]
  c:init()
  assert(c)
end

-- function brush:paint(t) self.c.ptr[self.pz * size * size + self.py * size + self.px] = t end
function brush:paint(x, y, z, t)
  x, y, z = self.dx + x, self.dy + y, self.dz + z
  local locx, locy, locz = (x % size), (y % size), (z % size)
  local c = self.chunks[1 + floor(x / size) * self.ch * self.cd + floor(y / size) * self.cd + floor(z / size)]
  c:init()
  c.ptr[locz * size * size + locy * size + locx] = t
end

function brush:paintonair(x, y, z, t)
  if self:look(x, y, z) == 0 then return self:paint(x, y, z, t) end
end

function brush:look(x, y, z)
  x, y, z = self.dx + x, self.dy + y, self.dz + z
  local locx, locy, locz = (x % size), (y % size), (z % size)
  local c = self.chunks[1 + floor(x / size) * self.ch * self.cd + floor(y / size) * self.cd + floor(z / size)]
  return c:get(locx, locy, locz)
end

function brush:up()
  assert(self.z ~= self.maxz)
  if self.pz == size - 1 then
    self.pz = 0
    self.i = self.i + 1
    self:refreshc()
  else
    self.pz = self.pz + 1
  end
  self.z = self.z + 1
end

function brush:down()
  assert(self.z ~= self.minz)
  if self.pz == 0 then
    self.pz = size - 1
    self.i = self.i - 1
    self:refreshc()
  else
    self.pz = self.pz - 1
  end
  self.z = self.z - 1
end

function brush:move(dx, dy, dz) end

return brush
