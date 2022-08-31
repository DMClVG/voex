local ServerWorld = loex.World:extend()

function ServerWorld:new(net)
    ServerWorld.super.new(self)
    self.net = net
end

function ServerWorld:onEntityAdded(entity)
    net:broadcast(packets.EntityAdded(entity.id, entity.type, entity.x, entity.y, entity.z, entity:remoteExtras()), CHANNEL_EVENTS, "reliable", players)
    print(entity.type .. " ".. entity.id .. " added")
end

function ServerWorld:onEntityRemoved(entity)
    net:broadcast(packets.EntityRemoved(entity.id), CHANNEL_EVENTS, "reliable", players)
    print(entity.type .. " ".. entity.id .. " removed")
end

return ServerWorld