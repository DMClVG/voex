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
  new.tagtables = {}

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

function world:tag(e, tag)
  local tagtable = self.tagtables[tag]
  if not tagtable then
    tagtable = {}
    self.tagtables[tag] = tagtable
  end
  tagtable[e.id] = e

  return tags
end

function world:untag(e, tag)
  local tagtable = self.tagtables[tag]
  if tagtable then tagtable[e.id] = nil end
end

function world:tagged(e, tag)
  local tagtable = self.tagtables[tag]
  return tagtable and tagtable[e.id]
end

function world:remove(e)
  assert(self.entities[e.id], "entity does not exist")
  local e = self.entities[e.id]
  self.entities[e.id] = nil

  for _, tagtable in pairs(self.tagtables) do
    tagtable[e.id] = nil
  end
  self.onentityremoved:emit(e)
end

local function intersect(a, b)
  local t = {}
  if a == nil or b == nil then return t end

  for k, _ in pairs(a) do
    if b[k] ~= nil then t[k] = true end
  end
  return t
end

function world:query(...)
  local tags = { ... }
  if #tags == 0 then return self.entities end

  local query = self.tagtables[tags[1]]

  for i = 2, #tags do
    query = intersect(query, self.tagtables[tags[i]])
  end
  return query or {}
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
