local entity = {}
entity.__index = entity

function entity.new(x, y, z, id)
    local new = {}
    new.id = id or lume.uuid()
    new.x, new.y, new.z = x, y, z
    new.vx, new.vy, new.vz = 0, 0, 0
    new.tags = {}

    setmetatable(new, entity)
    return new
end

function entity:tag(tag)
    self.tags[tag] = true
end

function entity:untag(tag)
    self.tags[tag] = nil
end

function entity:has(tag)
    return self.tags[tag] == true
end

function entity:destroy()
end

function entity:__tostring()
    return entity.type
end

return entity
