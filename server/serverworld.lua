local ServerWorld = loex.World:extend()

local dist = loex.Utils.dist3d
local size = loex.Chunk.size
local viewDistance = 6

function ServerWorld:new(net)
    ServerWorld.super.new(self)
    self.net = net
end

function ServerWorld:onUpdated(dt)
    for _, player in ipairs(players) do -- generate bubble around every player
        local px, py, pz = math.floor(player.x/size), math.floor(player.y/size), math.floor(player.z/size)
        for i=-viewDistance,viewDistance do
            for j=-viewDistance,viewDistance do
                for k=-viewDistance,viewDistance do
                    local x, y, z = i+px, j+py, k+pz
                    if dist(px, py, pz, x, y, z) <= viewDistance then
                        local chunk = self:getChunk(x, y, z)
                        if not chunk then -- TODO: proper world generation
                            chunk = ServerChunk(x, y, z)
                            chunk:generate()
                            self:addChunk(chunk)
                        end
                        if not chunk.subscribers[player.id] then
                            player:subscribeToChunk(chunk)
                        end
                    end
                end
            end
        end
    end

    for _, chunk in pairs(self.chunks) do -- unsubscribe players from far away chunks
        for subscriberID in pairs(chunk.subscribers) do
            local subscriber = self:getEntity(subscriberID)
            if not subscriber then
                chunk.subscribers[subscriberID] = nil 
            else 
                local px, py, pz = math.floor(subscriber.x/loex.Chunk.size), math.floor(subscriber.y/loex.Chunk.size), math.floor(subscriber.z/loex.Chunk.size)
                if dist(px, py, pz, chunk.cx, chunk.cy, chunk.cz) > viewDistance then
                    subscriber:unsubscribeFromChunk(chunk)
                    if #chunk.subscribers == 0 then
                        -- chunk:destroy() -- TODO: save to disk
                    end
                end
            end
        end
    end

    synchronizePositions()
end

function synchronizePositions()
    for _, e in pairs(world.entities) do
        if e.syncX == nil or e.x ~= e.syncX or e.y ~= e.syncY or e.z ~= e.syncZ then
            e.syncX = e.x
            e.syncY = e.y
            e.syncZ = e.z

            if e.owner then -- send movements to subscribed
                for subscriberID in pairs(e.owner.subscribers) do
                    if subscriberID ~= e.id then
                        local subscriber = world:getEntity(subscriberID)
                        if subscriber.master then
                            subscriber.master:send(packets.EntityMoved(e.id, e.syncX, e.syncY, e.syncZ), CHANNEL_UPDATES, "unreliable")
                        end
                    end
                end
            end
        end
    end
end

function ServerWorld:onTileChanged(x, y, z, t)
    local chunk = self:getChunkFromWorld(x, y, z)
    for subscriberID in pairs(chunk.subscribers) do
        local subscriber = self:getEntity(subscriberID)
        if subscriber and subscriber.master then
            if t == 0 then
                subscriber.master:send(packets.Broken(x, y, z), CHANNEL_EVENTS, "reliable")
            else
                subscriber.master:send(packets.Placed(x, y, z, t), CHANNEL_EVENTS, "reliable")
            end
        end
    end
end

function ServerWorld:onEntityAdded(entity)
    print(entity.type .. " ".. entity.id .. " added")
end

function ServerWorld:onEntityRemoved(entity)
    print(entity.type .. " ".. entity.id .. " removed")
end

return ServerWorld