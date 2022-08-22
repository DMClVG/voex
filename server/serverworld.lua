local ServerWorld = loex.World:extend()

function ServerWorld:new(net)
    ServerWorld.super.new(self)
    self.net = net
end

function ServerWorld:onEntityAdded(entity)
    net:broadcast(packets.EntityAdded(entity.id, entity.type, entity.x, entity.y, entity.z), 0, "reliable", players)
    print(entity.type .. " ".. entity.id .. " added")
end

function ServerWorld:onEntityRemoved(entity)
    net:broadcast(packets.EntityRemoved(entity.id), 0, "reliable", players)
    print(entity.type .. " ".. entity.id .. " removed")
end

return ServerWorld