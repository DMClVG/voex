local Entity = Object:extend()

function Entity:new(x, y, z, id)
    self.id = id or lume.uuid()
    self.x, self.y, self.z = x, y, z
    self.vx, self.vy, self.vz = 0, 0, 0
    self.dead = false
end

function Entity:update(dt)

end

function Entity:draw()

end

function Entity:__tostring()
    return Entity.type
end

return Entity