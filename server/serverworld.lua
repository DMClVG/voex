local ServerWorld = loex.World:extend()

local dist = loex.Utils.dist3d
local size = loex.Chunk.size
local viewDistance = 6
local Chunk = loex.Chunk
local floor = math.floor
local columnHeight = 8

function ServerWorld:new(net)
    ServerWorld.super.new(self)
    self.net = net
    self.genChunks = {}
end

function ServerWorld:onUpdated(dt)
    for _, player in ipairs(players) do -- generate bubble around every player
        local px, py, pz = math.floor(player.x/size), math.floor(player.y/size), math.floor(player.z/size)
        for i=-viewDistance,viewDistance do
            for j=-viewDistance,viewDistance do
                for k=0,columnHeight-1 do
                    local x, y, z = i+px, j+py, k
                    if lume.distance(px, py, x, y) <= viewDistance then
                        local chunk = self:getChunk(x, y, z)
                        if not chunk then
                            self:generateChunkColumn(x, y)
                            chunk = self:getChunk(x, y, z)
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
                if lume.distance(px, py, chunk.cx, chunk.cy) > viewDistance then
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

function ServerWorld:getOrAddGenColumn(cx, cy) 

end

local log = loex.Tiles.log.id
local leaves = loex.Tiles.leaves.id

local genStages = {
    [0]=nil, -- done
    [1]=function (column, setBlock, _)
        -- generate trees

        function genTree(x, y, z)
            for i=-2,2 do
                for j=-2,2 do
                    for k=0,1 do
                        setBlock(x+i,y+j,z+3+k,leaves)
                    end
                end
            end
            for i=-1,1 do
                for j=-2,2 do
                    setBlock(x+i,y+j,z+5,leaves)
                end
            end
            for i=-2,2 do
                for j=-1,1 do
                    setBlock(x+i,y+j,z+5,leaves)
                end
            end
            for i=-1,1 do
                setBlock(x+i,y,z+6,leaves)
            end
            for j=-1,1 do
                setBlock(x,y+j,z+6,leaves)
            end

            for i=0,4 do
                setBlock(x, y, z+i, log)
            end
        end

        local hm = column.heightmap
        math.randomseed(column.cx + column.cy)
        local treeCount = math.random(0, 4)
        for _=1,treeCount do
            local i, j = floor(math.random()*size), floor(math.random()*size)
            local z = hm[1 + i + j * size] + 1
            genTree(column.x+i, column.y+j, z)
        end
    end,
    [2]=function(column, _, _)
        local hm = {}

        -- generate terrain
        local grass = loex.Tiles.grass.id
        local dirt = loex.Tiles.dirt.id
        local stone = loex.Tiles.stone.id
        local x, y = column.x, column.y
        local f = 0.125/10
        for j=0,size-1 do
            for i=0,size-1 do
                local h = math.max(math.min(floor(love.math.noise((x+i)*f, (y+j)*f)*17)+20, columnHeight*size), 0)
                table.insert(hm, h)
                for _, chunk in ipairs(column) do
                    for k=0, math.min(h-chunk.z,size-1) do
                        if chunk.z+k==h then
                            chunk.datapointer[i+j*size+k*size*size] = grass
                        elseif chunk.z+k>h-5 then
                            chunk.datapointer[i+j*size+k*size*size] = dirt
                        else
                            chunk.datapointer[i+j*size+k*size*size] = stone
                        end
                    end
                end 
            end
        end

        return "heightmap", hm
    end,
    [3]=nil, -- begin,
    done=0,
    begin=3,
}

function ServerWorld:draw()
    local g = love.graphics
    g.translate(g.getWidth()/2, g.getHeight()/2)

    for _, chunk in pairs(self.chunks) do
        if chunk.dead then
            g.setColor(1, 0, 0)
        else
            g.setColor(0, 1, 0)
        end
        g.push()
        g.translate(chunk.cx*16,chunk.cy*16)
        g.rectangle("line", 0, 0, 16, 16)
        g.pop()
    end

    g.setColor(1, 1, 1)
    for _, column in pairs(self.genChunks) do
        if column ~= true then
            g.push()
            g.translate(column.cx*16,column.cy*16)
            g.rectangle("line", 0, 0, 16, 16)
            g.print(tostring(column.stage))
            g.pop()
        end
    end

    g.setColor(0, 0, 1)
    for _, player in ipairs(players) do
        g.setPointSize(5)
        g.points(player.x, player.y)
    end
end

function ServerWorld:generateChunkColumn(cx, cy)

    function getOrAddColumn(cx, cy)
        local hash = Chunk.hashFrom(cx, cy, 0)
        local column = self.genChunks[hash]
        if not column then
            local column = { }
            for k=0,columnHeight-1 do
                table.insert(column, ServerChunk(cx, cy, k))
            end
            column.cx = cx
            column.cy = cy
            column.x = cx * size
            column.y = cy * size
            column.stage = genStages.begin
            self.genChunks[hash] = column
            return column
        else
            return column
        end
    end

    function setBlock(x, y, z, t)
        local cx, cy, cz = floor(x/size), floor(y/size), floor(z/size)
        local column = getOrAddColumn(cx, cy)
        local chunk = column[1+cz]
        chunk:setBlock(x-chunk.x, y-chunk.y, z-chunk.z, t)
    end

    function getBlock(x, y, z)
        assert(false, "todo")
    end

    function genColumn(column, stage)
        local stage = stage or 0
        for i=column.stage-1,stage,-1 do -- gen to stage
            if column.stage == stage then
                assert(false)
            end
            column.stage = i
            if i ~= genStages.done then
                local k, v = genStages[i](column, setBlock, getBlock)
                if k then
                    column[k] = v
                end
            else
                break
            end
        end
        return column
    end

    local column = getOrAddColumn(cx, cy)

    -- generate region around chunk
    for i=-genStages.begin+1,genStages.begin-1 do
        for j=-genStages.begin+1,genStages.begin-1 do
            local column = getOrAddColumn(cx+i, cy+j)
            if column ~= true then
                genColumn(column, math.min(math.max(math.abs(i),math.abs(j))))
            end
        end
    end

    for _, chunk in ipairs(column) do
        self:addChunk(chunk)
    end
    self.genChunks[Chunk.hashFrom(cx, cy, 0)] = true
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