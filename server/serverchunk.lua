local ServerChunk = common.Chunk:extend()

function ServerChunk:new(x, y, z)
    ServerChunk.super.new(self, x, y ,z)
    self.subscribers = {}
end

function ServerChunk:onEntityEnter(e, prev) 
    for subscriberID, _ in pairs(self.subscribers) do
        if e.id ~= subscriberID then
            if not prev or not prev.subscribers[subscriberID] then
                local subscriber = self.world:getEntity(subscriberID)
                if subscriber.master then
                    subscriber.master:send(packets.EntityAdded(e.id, e.type, e.x, e.y, e.z, e:remoteExtras()), CHANNEL_EVENTS, "reliable")
                end
            end
        end
    end
end

function ServerChunk:onEntityLeave(e, next) 
    for subscriberID, _ in pairs(self.subscribers) do
        if e.id ~= subscriberID then
            if not next or not next.subscribers[subscriberID] then
                local subscriber = self.world:getEntity(subscriberID)
                if subscriber.master then
                    subscriber.master:send(packets.EntityRemoved(e.id), CHANNEL_EVENTS, "reliable")
                end
            end
        end
    end
end

return ServerChunk