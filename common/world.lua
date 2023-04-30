local chunk = loex.chunk
local size = chunk.size
local floor = math.floor

local world = {}
world.__index = world

local function chunkhash(x, y, z)
    return table.concat({ x, y, z }, "/")
end

function world.new()
    local new = {}
    new.chunks = {}
    new.entities = {}

    new.ontilemodified = loex.signal.new()
    new.onentityadded = loex.signal.new()
    new.onentityremoved = loex.signal.new()
    new.onchunkadded = loex.signal.new()
    new.onchunkremoved = loex.signal.new()

    setmetatable(new, world)

    return new
end

function world:iterate()
    return pairs(self.entities)
end

function world:insert(e)
    assert(not self.entities[e.id])
    self.entities[e.id] = e
    self.onentityadded:emit(e)
end

function world:remove(e)
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

function world:get(id)
    return self.entities[id]
end

function world:chunk(x, y, z, c)
    local hash = chunkhash(x, y, z)
    if c then
        assert(not self.chunks[hash])
        self.chunks[hash] = c
        self.onchunkadded:emit(c)
    else
        return self.chunks[hash]
    end
end

function world:removechunk(x, y, z)
    local hash = chunkhash(x, y, z)
    local c = self.chunks[hash]
    assert(c)
    self.chunks[hash] = nil
    self.onchunkremoved:emit(c)
    return c
end

function world:tile(x, y, z, t)
    if t then
        local chunk = self:getChunk(floor(x / size), floor(y / size), floor(z / size))
        assert(chunk)

        local old = chunk:set(x % size, y % size, z % size, t)
        if old ~= t then
            self.ontilemodified:emit(x, y, z, t)
        end
    else
        local chunk = self:getChunk(floor(x / size), floor(y / size), floor(z / size))
        if chunk then return chunk:get(x % size, y % size, z % size) end
        return -1
    end
end

function world:neighbourhood(x, y, z)
    return self:chunk(x + 1, y, z),
        self:chunk(x - 1, y, z),
        self:chunk(x, y + 1, z),
        self:chunk(x, y - 1, z),
        self:chunk(x, y, z + 1),
        self:chunk(x, y, z - 1)
end

function world:destroy()

end

return world
