require("love.math")
require("love.data")
local ffi = require("ffi")

local channel, cx, cy, cz, blockdata, size, tids, n1, n2, n3, n4, n5, n6 = ...
local blockdatapointer = ffi.cast("uint8_t *", blockdata:getFFIPointer())
local n1p = n1 and ffi.cast("uint8_t *", n1:getFFIPointer())
local n2p = n2 and ffi.cast("uint8_t *", n2:getFFIPointer())
local n3p = n3 and ffi.cast("uint8_t *", n3:getFFIPointer())
local n4p = n4 and ffi.cast("uint8_t *", n4:getFFIPointer())
local n5p = n5 and ffi.cast("uint8_t *", n5:getFFIPointer())
local n6p = n6 and ffi.cast("uint8_t *", n6:getFFIPointer())

local c1 = 1
local c2 = 0.75
local c3 = 0.5

local function gettile(pointer, x, y, z)
  local i = x + size * y + size * size * z

  -- if this block is outside of the chunk, check the neighboring chunks if they exist
  if x >= size then return n1p and gettile(n1p, x % size, y % size, z % size) or -1 end
  if x < 0 then return n2p and gettile(n2p, x % size, y % size, z % size) or -1 end
  if y >= size then return n3p and gettile(n3p, x % size, y % size, z % size) or -1 end
  if y < 0 then return n4p and gettile(n4p, x % size, y % size, z % size) or -1 end
  if z >= size then return n5p and gettile(n5p, x % size, y % size, z % size) or -1 end
  if z < 0 then return n6p and gettile(n6p, x % size, y % size, z % size) or -1 end

  return pointer[i]
end

local facecount = 0
for x = 0, size - 1 do
  for y = 0, size - 1 do
    for z = 0, size - 1 do
      if gettile(blockdatapointer, x, y, z) ~= 0 then
        if gettile(blockdatapointer, x + 1, y, z) == 0 then facecount = facecount + 1 end
        if gettile(blockdatapointer, x - 1, y, z) == 0 then facecount = facecount + 1 end
        if gettile(blockdatapointer, x, y + 1, z) == 0 then facecount = facecount + 1 end
        if gettile(blockdatapointer, x, y - 1, z) == 0 then facecount = facecount + 1 end
        if gettile(blockdatapointer, x, y, z + 1) == 0 then facecount = facecount + 1 end
        if gettile(blockdatapointer, x, y, z - 1) == 0 then facecount = facecount + 1 end
      end
    end
  end
end

ffi.cdef([[
    struct vertex {
        float x, y, z;
        float u, v;
        float nx, ny, nz;
        uint8_t r, g, b, a;
    }
]])

local count = facecount * 6
if count > 0 then
  local data = love.data.newByteData(count * ffi.sizeof("struct vertex"))
  local datapointer = ffi.cast("struct vertex *", data:getFFIPointer())
  local dataindex = 0

  local function addface(x, y, z, mx, my, mz, u, v, c, invert)
    local start, stop, step
    if invert then
      start, stop, step = 6, 1, -1
    else
      start, stop, step = 1, 6, 1
    end
    for i = start, stop, step do
      local primary = i % 2 == 1
      local secondary = i > 2 and i < 6
      datapointer[dataindex].x = x + (mx == 1 and primary and 1 or 0) + (mx == 2 and secondary and 1 or 0)
      datapointer[dataindex].y = y + (my == 1 and primary and 1 or 0) + (my == 2 and secondary and 1 or 0)
      datapointer[dataindex].z = z + (mz == 1 and primary and 1 or 0) + (mz == 2 and secondary and 1 or 0)
      datapointer[dataindex].u = u + (primary and 1 / 16 or 0)
      datapointer[dataindex].v = (v + 1 / 16) - (secondary and 1 / 16 or 0)
      datapointer[dataindex].nx = 0
      datapointer[dataindex].ny = 1
      datapointer[dataindex].nz = 0
      datapointer[dataindex].r = c * 255
      datapointer[dataindex].g = c * 255
      datapointer[dataindex].b = c * 255
      datapointer[dataindex].a = 255
      dataindex = dataindex + 1
    end
  end

  for x = 0, size - 1 do
    for y = 0, size - 1 do
      for z = 0, size - 1 do
        local id = gettile(blockdatapointer, x, y, z)
        if id ~= 0 then
          assert(tids[id], "Id " .. id .. " does not exist")
          local tile = tids[id]
          if type(tile.tex) == "table" then
            local top, bottom, right, left, front, back = unpack(tile.tex)
            if gettile(blockdatapointer, x - 1, y, z) == 0 then
              addface(x, y, z, 0, 1, 2, (left % 16) / 16, math.floor(left / 16) / 16, c2)
            end
            if gettile(blockdatapointer, x + 1, y, z) == 0 then
              addface(x + 1, y, z, 0, 1, 2, (right % 16) / 16, math.floor(right / 16) / 16, c2, true)
            end
            if gettile(blockdatapointer, x, y - 1, z) == 0 then
              addface(x, y, z, 1, 0, 2, (front % 16) / 16, math.floor(front / 16) / 16, c1, true)
            end
            if gettile(blockdatapointer, x, y + 1, z) == 0 then
              addface(x, y + 1, z, 1, 0, 2, (back % 16) / 16, math.floor(back / 16) / 16, c1)
            end
            if gettile(blockdatapointer, x, y, z - 1) == 0 then
              addface(x, y, z, 1, 2, 0, (bottom % 16) / 16, math.floor(bottom / 16) / 16, c3)
            end
            if gettile(blockdatapointer, x, y, z + 1) == 0 then
              addface(x, y, z + 1, 1, 2, 0, (top % 16) / 16, math.floor(top / 16) / 16, c1, true)
            end
          else
            local u1, v1 = (tile.tex % 16) / 16, math.floor(tile.tex / 16) / 16
            if gettile(blockdatapointer, x - 1, y, z) == 0 then addface(x, y, z, 0, 1, 2, u1, v1, c2) end
            if gettile(blockdatapointer, x + 1, y, z) == 0 then addface(x + 1, y, z, 0, 1, 2, u1, v1, c2, true) end
            if gettile(blockdatapointer, x, y - 1, z) == 0 then addface(x, y, z, 1, 0, 2, u1, v1, c1, true) end
            if gettile(blockdatapointer, x, y + 1, z) == 0 then addface(x, y + 1, z, 1, 0, 2, u1, v1, c1) end
            if gettile(blockdatapointer, x, y, z - 1) == 0 then addface(x, y, z, 1, 2, 0, u1, v1, c3) end
            if gettile(blockdatapointer, x, y, z + 1) == 0 then addface(x, y, z + 1, 1, 2, 0, u1, v1, c1, true) end
          end
        end
      end
    end
  end

  channel:push { cx = cx, cy = cy, cz = cz, data = data, count = count }
else
  channel:push { cx = cx, cy = cy, cz = cz, data = nil, count = count }
end
