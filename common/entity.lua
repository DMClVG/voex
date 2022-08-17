local Entity = Object:extend()

function Entity:new(x, y, z)
    self.id = lume.uuid()
    self.x, self.y, self.z = x, y, z
    self.vx, self.vy, self.vz = 0, 0, 0
end

function Entity:update(dt)

end

function Entity:draw()

end

return Entity