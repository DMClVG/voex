local size = 8
local ffi = require "ffi"

local Chunk = Object:extend()
Chunk.size = size

local floor = math.floor

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
    self.dead = false
    self.entities = {}

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
    local grass = loex.Tiles.grass.id
    local dirt = loex.Tiles.dirt.id
    local stone = loex.Tiles.stone.id
    local datapointer = self.datapointer
    local x, y, z = self.x, self.y, self.z
    -- if false then
        local f = 0.125/10
        for i=0,size-1 do
            for j=0,size-1 do
                local h = floor(love.math.noise((x+i)*f, (y+j)*f)*17)
                for k=0, math.min(h-z,size-1) do
                    if z+k==h then
                        datapointer[i+j*size+k*size*size] = grass
                    elseif z+k>h-5 then
                        datapointer[i+j*size+k*size*size] = dirt
                    else
                        datapointer[i+j*size+k*size*size] = stone
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

    for id, _ in pairs(self.entities) do
        self.world.entities[id].dead = true -- kill all child entities
    end
end

function Chunk:onEntityEnter(e, prev) --[[overload]] end
function Chunk:onEntityLeave(e, next) --[[overload]] end

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