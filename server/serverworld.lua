local ServerWorld = loex.World:extend()

function ServerWorld:new(nethandler)
    ServerWorld.super.new(self)
end

function ServerWorld:onEntityAdded(entity)

end

return ServerWorld