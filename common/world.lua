local chunk = loex.chunk
local size = chunk.size
local floor = math.floor
local spatialhash = loex.hash.spatial
local insert = table.insert
local world = {}
world.__index = world

function world.new()
  local new = {}
  new.chunks = {}
  new.entities = {}

  new.ontilemodified = loex.signal.new()
  new.onentityinserted = loex.signal.new()
  new.onentityremoved = loex.signal.new()
  new.onchunkinserted = loex.signal.new()
  new.onchunkremoved = loex.signal.new()

  setmetatable(new, world)

  return new
end

function world:insert(e)
  assert(not self.entities[e.id])
  self.entities[e.id] = e
  self.onentityinserted:emit(e)
end

function world:remove(e)
  assert(e)
  local id
  if type(e) == "table" then
    id = e.id
  else
    id = e
    e = self.entities[id]
  end
  assert(self.entities[id])
  self.entities[id] = nil
  self.onentityremoved:emit(e)
end

function world:query(...)
  local res = {}
  local tags = { ... }
  for _, e in pairs(self.entities) do
    local hastags = true
    for _, tag in ipairs(tags) do
      hastags = hastags and e:has(tag)
    end
    if hastags then insert(res, e) end
  end
  return res
end

function world:entity(id) return self.entities[id] end
function world:chunk(hash) return self.chunks[hash] end

function world:insertchunk(c)
  assert(not self.chunks[c.hash])
  self.chunks[c.hash] = c
  self.onchunkinserted:emit(c)
end

function world:removechunk(hash)
  local c = self.chunks[hash]
  assert(c)
  self.chunks[hash] = nil
  self.onchunkremoved:emit(c)
  return c
end

function world:tile(x, y, z, t)
  local c = self:chunk(spatialhash(floor(x / size), floor(y / size), floor(z / size)))
  if t then
    assert(c)

    local old = c:set(x % size, y % size, z % size, t)
    if old ~= t then self.ontilemodified:emit(x, y, z, t) end
  else
    if c then return c:get(x % size, y % size, z % size) end
    return -1
  end
end

function world:neighbourhood(x, y, z)
  return self:chunk(spatialhash(x + 1, y, z)),
    self:chunk(spatialhash(x - 1, y, z)),
    self:chunk(spatialhash(x, y + 1, z)),
    self:chunk(spatialhash(x, y - 1, z)),
    self:chunk(spatialhash(x, y, z + 1)),
    self:chunk(spatialhash(x, y, z - 1))
end

function world:destroy() end

return world
