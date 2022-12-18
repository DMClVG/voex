local Entity = Object:extend()

function Entity:new(x, y, z, id)
    self.id = id or lume.uuid()
    self.x, self.y, self.z = x, y, z
    self.vx, self.vy, self.vz = 0, 0, 0
    self.dead = false
    self.owner = nil -- chunk
end

function Entity:remoteSpawn(data) end
function Entity:remoteExtras() end
function Entity:update(dt) end
function Entity:draw() end

function Entity:__tostring()
    return Entity.type
end

local floor = math.floor
local size = loex.Chunk.size
function Entity:updateOwner()
    local cx, cy, cz = floor(self.x/size),floor(self.y/size), floor(self.z/size)
    local prev = self.owner
    if not prev or (prev.cx ~= cx or prev.cy ~= cy or prev.cz ~= cz) then
        local next = self.world:getChunk(cx, cy, cz)
        self.owner = next

        if prev then
            prev.entities[self.id] = nil
            prev:onEntityLeave(self, next)
        end

        if next then
            next.entities[self.id] = true
            next:onEntityEnter(self, prev)
        end
    end
end


function Entity:destroy()
    if self.owner then
        self.owner.entities[self.id] = nil
        self.owner:onEntityLeave(self, nil)
    end
end

return Entity