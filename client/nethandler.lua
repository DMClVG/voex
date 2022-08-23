local netHandler = {}

function netHandler.JoinSucceeded(data, net, world)
    local spawnX, spawnY, spawnZ = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    local playerID = data.id
    local playerEntity = loex.entities.Player(spawnX, spawnY, spawnZ, playerID)
    playerEntity.username = username

    print(("Joined under username ".. username .. " (ID: " .. playerID .. ") at spawn point %d, %d, %d"):format(spawnX, spawnY, spawnZ))

    loex.World.singleton = GameWorld(playerEntity)
    scene(loex.World.singleton)
end

function netHandler.JoinFailed(data, net, world)
    scene(require("scenes/joinFailedScreen"), data.cause)
end

function netHandler.Chunk(data, net, world)
    world:addChunk(loex.Chunk.fromPacket(data))
end

function netHandler.Broken(data, net, world)
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    local hash = ("%d/%d/%d"):format(x, y, z)
    if not world.breakQueue[hash] then
        world:setBlockAndRemesh(x, y, z, loex.Tiles.air.id, true)
    end
    world.breakQueue[hash] = nil
end

function netHandler.Placed(data, net, world)
    local x, y, z, t = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.t)
    local hash = ("%d/%d/%d"):format(x, y, z)
    if not world.placeQueue[hash] or world.placeQueue[hash].placed ~= t then
        world:setBlockAndRemesh(x, y, z, t)
    end
    world.placeQueue[hash] = nil
end

function netHandler.EntityMoved(data, net, world)
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    local entity = world:getEntity(data.id)
    assert(entity)
    entity.x = x
    entity.y = y
    entity.z = z
end

function netHandler.EntityAdded(data, net, world)
    if data.id == world.player.id then return end

    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    local entity = loex.entities[data.eType](x, y, z, data.id)
    entity:remoteSpawn(data)
    world:addEntity(entity)
end

function netHandler.EntityRemoved(data, net, world)
    local entity = world:getEntity(data.id)
    entity.dead = true
end

return netHandler