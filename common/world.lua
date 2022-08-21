local World = Object:extend()
local Chunk = loex.Chunk
local size = Chunk.size

World.singleton = nil

function World:new()
    self.chunks = {}
    self.entities = {}
end

function World:update(dt)
    local entities = self.entities
    for id, entity in pairs(entities) do
        if not entity.dead then
            entity:update(dt)
        else
            entities[id] = nil
            self:onEntityRemoved(entity)
        end
    end
    self:onUpdated(dt)
end

function World:onUpdated(dt) --[[overload]] end
function World:onChunkAdded(chunk) --[[overload]] end
function World:onEntityAdded(entity) --[[overload]] end
function World:onEntityRemoved(entity) --[[overload]] end
function World:onTileChanged(x, y, z, value) --[[overload]] end

function World:addEntity(entity)
    assert(self.entities[entity.id] == nil)
    self.entities[entity.id] = entity
    self:onEntityAdded(entity)
end

function World:addChunk(chunk)
    assert(self.chunks[chunk.hash] == nil)
    self.chunks[chunk.hash] = chunk
    self:onChunkAdded(chunk)
end

function World:getChunk(x, y, z)
    return self.chunks[Chunk.hashFrom(x, y, z)]
end

function World:getEntity(id)
    return self.entities[id]
end

function World:queryOne(class)
    for _, entity in pairs(self.entities) do
        entity:is(class)
    end
    return nil
end

function World:query(class)
    if class == loex.Entity then
        return self.entities
    end
    local out = {}
    for _, entity in pairs(self.entities) do
        entity:is(class)
    end
    return out
end

function World:getChunkFromWorld(x, y, z)
    local floor = math.floor
    return self:getChunk(floor(x / size), floor(y / size), floor(z / size))
end

function World:getBlockFromWorld(x, y, z)
    local floor = math.floor
    local chunk = self:getChunk(floor(x / size), floor(y / size), floor(z / size))
    if chunk then return chunk:getBlock(x % size, y % size, z % size) end
    return -1
end

function World:setBlockFromWorld(x, y, z, value)
    local floor = math.floor
    local chunk = self:getChunk(floor(x / size), floor(y / size), floor(z / size))
    if chunk then
        local old = chunk:setBlock(x % size, y % size, z % size, value)
        if old ~= value then
            self:onTileChanged(x, y, z, value)
        end
    else
        assert(false)
    end
end

function World:getNeighoursOfChunk(x, y, z)
    return self:getChunk(x+1,y,z),
            self:getChunk(x-1,y,z),
            self:getChunk(x,y+1,z),
            self:getChunk(x,y-1,z),
            self:getChunk(x,y,z+1),
            self:getChunk(x,y,z-1)
end

return World
