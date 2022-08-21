local ServerWorld = loex.World:extend()

function ServerWorld:new()
    ServerWorld.super.new(self)
end

function ServerWorld:onEntityAdded(entity)
    net:broadcast(packets.EntityAdd(entity.id, entity.type, entity.x, entity.y, entity.z), 0, "reliable", players)
    print(entity.type .. " ".. entity.id .. " added")
end

function ServerWorld:onEntityRemoved(entity)
    net:broadcast(packets.EntityRemove(entity.id), 0, "reliable", players)
    print(entity.type .. " ".. entity.id .. " removed")
end

return ServerWorld