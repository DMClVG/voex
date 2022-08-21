local size = 12
local ffi = require "ffi"

local Chunk = Object:extend()
Chunk.size = size

function Chunk:new(x,y,z,data)
    self.cx = x
    self.cy = y
    self.cz = z
    self.x = x*size
    self.y = y*size
    self.z = z*size
    self.hash = self.hashFrom(x,y,z)
    self.frames = 0
    self.inRemeshQueue = false
    self.world = loex.World.singleton

    if data then
        self.data = data
    else
        self.data = love.data.newByteData(size*size*size*ffi.sizeof("uint8_t"))
    end
    self.datapointer = ffi.cast("uint8_t *", self.data:getFFIPointer())
end

function Chunk.fromPacket(packet)
    assert(packet.bin:getSize() == Chunk.size^3, "Chunk data of wrong size!")
    local cx = tonumber(packet.cx)
    local cy = tonumber(packet.cy)
    local cz = tonumber(packet.cz)
    return Chunk(cx, cy, cz, packet.bin)
end

function Chunk:generate()
    local planks = loex.Tiles.planks.id
    local datapointer = self.datapointer
    if false then
        local f = 0.125
        for i=0, size*size*size - 1 do
            local x, y, z = i%size + self.x, math.floor(i/size)%size + self.y, math.floor(i/(size*size)) + self.z
            datapointer[i] = love.math.noise(x*f,y*f,z*f) > (z+32)/64 and planks or 0
        end
    else
        if self.cz <= 0 then
            for k = 0, size-1 do
                for i=0, size-1 do
                    for j=0, size-1 do
                        datapointer[i+j*size+k*size*size] = planks
                    end
                end
            end
        end
        if self.cz == 1 then
            for i=0, size-1 do
                for j=0, size-1 do
                    datapointer[i+j*size] = planks
                end
            end
        end
    end
end

function Chunk:getBlock(x,y,z)
    if self.dead then return -1 end

    if x >= 0 and y >= 0 and z >= 0 and x < size and y < size and z < size then
        local i = x + size*y + size*size*z
        return self.datapointer[i]
    end

    local chunk = self.world:getChunkFromWorld(self.x+x,self.y+y,self.z+z)
    if chunk then return chunk:getBlock(x%size,y%size,z%size) end
    return -1
end

function Chunk:setBlock(x,y,z, value)
    if self.dead then return -1 end

    if x >= 0 and y >= 0 and z >= 0 and x < size and y < size and z < size then
        local i = x + size*y + size*size*z
        local oldvalue = self.datapointer[i]
        self.datapointer[i] = value
        return oldvalue
    end

    local chunk = self.world:getChunkFromWorld(self.x+x,self.y+y,self.z+z)
    if chunk then return chunk:setBlock(x%size,y%size,z%size, value) end
end

function Chunk:draw()
    if self.model and not self.dead then
        self.model:draw()
    end
end

function Chunk:destroy()
    if self.model then self.model.mesh:release() end
    self.dead = true
    self.data:release()
    self.world.chunks[self.hash] = nil
end

function Chunk.hashFrom(x, y, z)
    return ("%d/%d/%d"):format(x, y, z)
end

function Chunk.fromHash(hash)
    local n = {}
    local coord = 1
    local coords = {0, 0, 0}
    for i=1,#hash do
        assert(coord < 3)

        if hash[i] == string.byte('/') then
            coords[coord] = tonumber(table.concat(n))
            n = {}
        else
            table.insert(n, string.char(hash[i]))
        end
    end
    return coords[0], coords[1], coords[2]
end

return Chunk