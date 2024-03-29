local ffi = require("ffi")

local size = 32
local chunk = {}
chunk.size = size

local empty_chunk = {}

function empty_chunk:get(x, y, z)
  if x >= 0 and x < size and y >= 0 and y < size and z >= 0 and z < size then
    return 0
  else
    return -1
  end
end

function empty_chunk:set(x, y, z, t)
  self:init()
  return self:set(x, y, z, t)
end

function empty_chunk:dump(uncompressed) return "" end

function empty_chunk:init(data)
  self.data = data or love.data.newByteData(chunk.size ^ 3)
  self.ptr = ffi.cast("uint8_t *", self.data:getFFIPointer())
  setmetatable(self, { __index = chunk })
end

function empty_chunk:insert(id) return chunk.insert(self, id) end

function empty_chunk:remove(id) return chunk.remove(self, id) end

function empty_chunk:destroy() end

function chunk.new(x, y, z)
  local new = {}
  new.x, new.y, new.z = x, y, z
  new.hash = loex.hash.spatial(x, y, z)
  new = setmetatable(new, { __index = empty_chunk })
  return new
end

function chunk:init() end

function chunk:set(x, y, z, t)
  if x >= 0 and x < size and y >= 0 and y < size and z >= 0 and z < size then
    self.ptr[z * chunk.size * chunk.size + y * chunk.size + x] = t
  else
    error("chunk:set(" .. x .. "," .. y .. "," .. z .. "," .. t .. ") out of bounds")
  end
end

function chunk:get(x, y, z)
  if x >= 0 and x < size and y >= 0 and y < size and z >= 0 and z < size then
    return self.ptr[z * size * size + y * size + x]
  else
    return -1
  end
end

function chunk:insert(id) self.entities[id] = true end

function chunk:remove(id)
  local was_before = self.entities[id]
  self.entities[id] = nil
  return was_before
end

function chunk:destroy() end

function chunk:dump(uncompressed)
  if not uncompressed then
    return love.data.compress("string", "zlib", self.data)
  else
    return self.data:getString()
  end
end

return chunk
