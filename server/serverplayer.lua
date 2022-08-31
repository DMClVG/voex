local ServerPlayer = loex.entities.Player:extend()

function ServerPlayer:PMove(data)
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)

    local dx, dy, dz = x - self.x, y - self.y, z - self.z
    if self.world:intersectWithWorld(loex.Utils.expand(self:getBox(), dx, dy, 0)) and self.world:intersectWithWorld(loex.Utils.expand(self:getBox(), 0, 0, dz)) then
        self.master:send(packets.EntityMoved(self.id, self.x, self.y, self.z), CHANNEL_UPDATES, "reliable") -- correct movement
    else
        self.x = x
        self.y = y
        self.z = z
    end
end

function ServerPlayer:PBreak(data)
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    self.world:setBlockFromWorld(x, y, z, loex.Tiles.air.id)
    net:broadcast(packets.Broken(x, y, z), CHANNEL_EVENTS, "reliable")
end

function ServerPlayer:PPlace(data)
    local x, y, z, t = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.t)

    local collided = false
    local intersect = loex.Utils.intersectBoxAndBox
    for _, e in pairs(self.world:query(loex.entities.Player)) do
        if intersect(e:getBox(), {x=x+0.5, y=y+0.5, z=z+0.5, w=0.5, h=0.5, d=0.5 }) then
            collided = true
            break
        end
    end
    if not collided then
        self.world:setBlockFromWorld(x, y, z, t)
        net:broadcast(packets.Placed(x, y, z, t), CHANNEL_EVENTS, "reliable")
    else
        -- invalid placement
    end
end

return ServerPlayer